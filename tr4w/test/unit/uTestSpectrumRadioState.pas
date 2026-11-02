unit uTestSpectrumRadioState;
{$I ..\..\src\tr4w.inc}

(*
  THE RADIO OWNS WHAT IT REPORTS ABOUT ITS OWN DISPLAY -- stage 2 of the K4
  display-state work.

  TFactoryRadioBase.SpectrumRadioState(sourceId) answers what the radio last
  said its reference, scale, AutoRef, waterfall share, averaging and colour
  range are.  The base answers "nothing known"; the K4 records its '#' reports
  on the reading thread and returns them by value from under its own lock.
  Nothing above the factory reads it yet -- these tests are its only reader.

  What is pinned, without a transport (the connect-time questions need a
  socket and live in uTestRadioSocketNoRead, beside #SPN; and TS;):
  - a K4 that has heard nothing knows nothing, on every source;
  - its reports reach the right source: pan A is main (#REF), pan B is sub
    (#REF$), and nothing is claimed for the Y mini-pan;
  - a first report equal to the default still counts as known, and every
    report -- a repeat included -- moves Generation;
  - a new link (Connect) forgets the last session;
  - a K4 that does not declare rcSpectrum answers nothing whatever it hears;
  - over the WHOLE REGISTRY, a freshly built radio knows nothing, and the
    Icoms -- which have spectrum but report no such settings -- inherit the
    base's answer.
*)

interface

uses
   uTR4WTestFramework;

type
   TSpectrumRadioStateTests = class(TTestCase)
   protected
      procedure Test_K4_NoReports_KnowsNothing;
      procedure Test_K4_MainAndSubAreSeparate;
      procedure Test_K4_FirstReportEqualToDefault_IsKnown;
      procedure Test_K4_ReconnectForgetsTheLastSession;
      procedure Test_K4WithoutSpectrum_AnswersNothing;
      procedure Test_IC9700_InheritsTheBaseAnswer;
      procedure Test_EveryRegisteredRadio_FreshKnowsNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uSpectrumTypes, uFactoryRadioBase, uRadioRegistry, uRadioElecraftK4, VC;

type
   (* A K4 that does not declare rcSpectrum.  Its parser still runs, so this
      is the shape of a capability withdrawn in the constructor while the
      driver keeps listening. *)
   TK4WithoutSpectrum = class(TK4Radio)
   public
      constructor Create;
   end;

constructor TK4WithoutSpectrum.Create;
begin
   inherited Create;
   FCapabilities.Flags := FCapabilities.Flags - [rcSpectrum];
end;

function NewK4: TFactoryRadioBase;
begin
   Result := uRadioRegistry.CreateInstance(K4);
end;

function Describe(const AState: TSpectrumRadioState): string;
begin
   Result := Format('ref %s/%d scale %s/%d autoref %s/%s wf %s/%d avg %s/%d clr %s/%d gen %d',
                    [BoolToStr(AState.HasRef, True), AState.RefDb,
                     BoolToStr(AState.HasScale, True), AState.ScaleDb,
                     BoolToStr(AState.HasAutoRef, True), BoolToStr(AState.AutoRef, True),
                     BoolToStr(AState.HasWaterfallFraction, True), AState.WaterfallPercent,
                     BoolToStr(AState.HasAvg, True), AState.AvgFrames,
                     BoolToStr(AState.HasColourRange, True), AState.ColourRange,
                     AState.Generation]);
end;

(* Nothing known AND never reported: what a radio that has heard nothing says. *)
function IsPristine(const AState: TSpectrumRadioState): Boolean;
begin
   Result := SpectrumRadioStateKnowsNothing(AState) and (AState.Generation = 0);
end;

procedure TSpectrumRadioStateTests.Test_K4_NoReports_KnowsNothing;
var
   r: TFactoryRadioBase;
begin
   BeginTest('K4: a radio that has heard nothing knows nothing, on every source');
   r := NewK4;
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      CheckTrue(IsPristine(r.SpectrumRadioState('A')), 'pan A: ' + Describe(r.SpectrumRadioState('A')));
      CheckTrue(IsPristine(r.SpectrumRadioState('B')), 'pan B: ' + Describe(r.SpectrumRadioState('B')));
      CheckTrue(IsPristine(r.SpectrumRadioState('Y')), 'Y mini-pan');
      CheckTrue(IsPristine(r.SpectrumRadioState('')), 'an empty source id');

      (* A message that is not a display report changes nothing. *)
      r.ProcessMsg('FA00014025000');
      r.ProcessMsg('#SPN100000');
      CheckTrue(IsPristine(r.SpectrumRadioState('A')), 'FA and #SPN are not display reports');
   finally
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_K4_MainAndSubAreSeparate;
var
   r: TFactoryRadioBase;
   a, b: TSpectrumRadioState;
begin
   BeginTest('K4: #REF reaches pan A, #REF$ reaches pan B, the globals reach both, Y gets nothing');
   r := NewK4;
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      (* As the reading thread hands them over: terminator consumed. *)
      r.ProcessMsg('#REF-126');
      r.ProcessMsg('#REF$-125');
      r.ProcessMsg('#SCL080');
      r.ProcessMsg('#AR1201+041');

      a := r.SpectrumRadioState('A');
      b := r.SpectrumRadioState('B');

      CheckTrue(a.HasRef, 'pan A knows its REF: ' + Describe(a));
      CheckEquals(-126, a.RefDb, 'pan A REF is the main receiver''s');
      CheckTrue(b.HasRef, 'pan B knows its REF: ' + Describe(b));
      CheckEquals(-125, b.RefDb, 'pan B REF is the sub receiver''s');

      CheckEquals(80, a.ScaleDb, 'pan A scale');
      CheckEquals(80, b.ScaleDb, 'pan B scale -- one value for both');
      CheckTrue(a.AutoRef and b.AutoRef, 'AutoRef is on for both');
      CheckEquals(4, b.AutoRefOffsetDb, 'with its offset');

      CheckTrue(IsPristine(r.SpectrumRadioState('Y')),
                'nothing is claimed for the Y mini-pan');

      (* PrimarySpectrumSourceId is the source the window shows by default, and
         it must be the main receiver's. *)
      CheckEquals(-126, r.SpectrumRadioState(r.PrimarySpectrumSourceId).RefDb,
                  'the primary source answers the main receiver');
   finally
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_K4_FirstReportEqualToDefault_IsKnown;
var
   r: TFactoryRadioBase;
   a: TSpectrumRadioState;
   gen: Integer;
begin
   BeginTest('K4: a first report equal to the default still marks it known and moves Generation');
   r := NewK4;
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      (* 0 percent and 0 dB: equal to the all-zero record, and real settings. *)
      r.ProcessMsg('#WFH000');
      r.ProcessMsg('#REF0');
      a := r.SpectrumRadioState('A');
      CheckTrue(a.HasWaterfallFraction, '#WFH000 is known: ' + Describe(a));
      CheckEquals(0, a.WaterfallPercent, 'and is 0');
      CheckTrue(a.HasRef, '#REF0 is known');
      CheckEquals(2, a.Generation, 'each report moved Generation');

      gen := a.Generation;
      r.ProcessMsg('#REF0');
      CheckEquals(gen + 1, r.SpectrumRadioState('A').Generation,
                  'a repeated value is still the radio speaking');
   finally
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_K4_ReconnectForgetsTheLastSession;
var
   r: TFactoryRadioBase;
   before, after: TSpectrumRadioState;
begin
   BeginTest('K4: a new link forgets the last session''s display reports');
   r := NewK4;
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      r.ProcessMsg('#REF-126');
      r.ProcessMsg('#REF$-125');
      r.ProcessMsg('#SCL80');
      before := r.SpectrumRadioState('A');
      CheckTrue(before.HasRef and before.HasScale, 'precondition: known');

      (* No address: the attempt goes nowhere, but it is a new session -- the
         same shape as uTestTXInhibit.Test_ConnectForgetsTheLastSession. *)
      r.Connect;

      after := r.SpectrumRadioState('A');
      CheckTrue(SpectrumRadioStateKnowsNothing(after),
                'pan A knows nothing after a reconnect: ' + Describe(after));
      CheckTrue(SpectrumRadioStateKnowsNothing(r.SpectrumRadioState('B')),
                'nor does pan B');
      CheckTrue(after.Generation <> before.Generation,
                'Generation moved, so a reader that applied the old values sees they are gone');
      CheckTrue(after.Generation <> 0, 'and did not go back to 0');
   finally
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_K4WithoutSpectrum_AnswersNothing;
var
   r: TK4WithoutSpectrum;
begin
   BeginTest('A K4 without rcSpectrum answers nothing, whatever it hears');
   r := TK4WithoutSpectrum.Create;
   try
      CheckFalse(r.Supports(rcSpectrum), 'precondition: the trait is withdrawn');
      r.ProcessMsg('#REF-126');
      r.ProcessMsg('#SCL80');
      CheckTrue(IsPristine(r.SpectrumRadioState('A')),
                'gated on the capability, as SpectrumDisplayDefaults is');
   finally
      r.Free;
   end;
end;

(* The registry walk would pass on any one radio; this names an Icom with a
   panadapter directly, so the family is seen to inherit the base answer. *)
procedure TSpectrumRadioStateTests.Test_IC9700_InheritsTheBaseAnswer;
var
   r: TFactoryRadioBase;
begin
   BeginTest('IC-9700: has a spectrum, reports no display settings, answers nothing');
   r := uRadioRegistry.CreateInstance(IC9700);
   CheckTrue(r <> nil, 'the registry built no IC-9700');

   if r = nil then
      begin
      Exit;
      end;

   try
      CheckTrue(r.Supports(rcSpectrum), 'precondition: the IC-9700 declares rcSpectrum');
      CheckTrue(IsPristine(r.SpectrumRadioState(r.PrimarySpectrumSourceId)), 'its primary source');
      CheckTrue(IsPristine(r.SpectrumRadioState('A')), 'and a K4 spelling means nothing to it');
   finally
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_EveryRegisteredRadio_FreshKnowsNothing;
var
   ids: TArray<string>;
   id: string;
   r: TFactoryRadioBase;
   bad: string;
   checked: Integer;

   procedure Expect(const ASource: string);
   var
      st: TSpectrumRadioState;
   begin
      st := r.SpectrumRadioState(ASource);

      if not IsPristine(st) then
         begin
         bad := bad + uRadioRegistry.DisplayNameId(id) + ' source [' + ASource + '] ' +
                Describe(st) + '; ';
         end;
   end;

begin
   BeginTest('Registry: every radio, freshly built, knows nothing about its display');
   bad := '';
   checked := 0;
   ids := uRadioRegistry.RegisteredIds;

   for id in ids do
      begin
      r := uRadioRegistry.CreateInstanceId(id);

      if r = nil then
         begin
         Continue;
         end;

      try
         Inc(checked);
         Expect(r.PrimarySpectrumSourceId);
         Expect('A');
         Expect('B');
      finally
         r.Free;
      end;
      end;

   CheckTrue(checked > 0, 'the registry produced no radios to check');
   CheckEquals('', bad, 'radios that claim display state before hearing anything');
end;

procedure TSpectrumRadioStateTests.RunAllTests;
begin
   Test_K4_NoReports_KnowsNothing;
   Test_K4_MainAndSubAreSeparate;
   Test_K4_FirstReportEqualToDefault_IsKnown;
   Test_K4_ReconnectForgetsTheLastSession;
   Test_K4WithoutSpectrum_AnswersNothing;
   Test_IC9700_InheritsTheBaseAnswer;
   Test_EveryRegisteredRadio_FreshKnowsNothing;
end;

end.
