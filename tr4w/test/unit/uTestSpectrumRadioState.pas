unit uTestSpectrumRadioState;
{$I ..\..\src\tr4w.inc}

(*
  THE RADIO OWNS WHAT IT REPORTS ABOUT ITS OWN DISPLAY -- stage 2 of the K4
  display-state work.

  TFactoryRadioBase.SpectrumRadioState(sourceId) answers what the radio last
  said its reference, scale, AutoRef, waterfall share, averaging and colour
  range are.  The base answers "nothing known"; the K4 records its '#' reports
  on the reading thread and returns them by value from under its own lock.
  The window does not read it: it reads SpectrumLiveDisplay, the radio's
  translation of it into neutral units, which is pinned here too.

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
      procedure Test_K4_LiveDisplay_FollowsTheLCDOnly;
      procedure Test_UnknownLive_ResolvesToTodaysDefaults;
      procedure Test_PaletteForTone;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uSpectrumTypes, uFactoryRadioBase, uRadioRegistry, uRadioElecraftK4, VC,
   uPanadapterForm;   // PanadapterPaletteForTone and the palette indices

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
   Result := Format('ref %s/%d scale %s/%d autoref %s/%s wf %s/%d avg %s/%d clr %s/%d mode %s/%d gen %d',
                    [BoolToStr(AState.HasRef, True), AState.RefDb,
                     BoolToStr(AState.HasScale, True), AState.ScaleDb,
                     BoolToStr(AState.HasAutoRef, True), BoolToStr(AState.AutoRef, True),
                     BoolToStr(AState.HasWaterfallFraction, True), AState.WaterfallPercent,
                     BoolToStr(AState.HasAvg, True), AState.AvgFrames,
                     BoolToStr(AState.HasColourRange, True), AState.ColourRange,
                     BoolToStr(AState.HasColourMode, True), AState.ColourMode,
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

      (* And nothing for the window to follow, so every radio draws with its
         defaults until it reports otherwise. *)
      if not SpectrumLiveDisplayKnowsNothing(r.SpectrumLiveDisplay(ASource)) then
         begin
         bad := bad + uRadioRegistry.DisplayNameId(id) + ' source [' + ASource +
                '] claims a live display; ';
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

function Near(A, B: Single): Boolean;
begin
   Result := Abs(A - B) < 1.0e-5;
end;

(* NY4I, 2026-11-03: the window follows the LCD's #WFH, #WBS and #WFC, never
   the external monitor's #HWFH, #HWBS or #HWFC. *)
procedure TSpectrumRadioStateTests.Test_K4_LiveDisplay_FollowsTheLCDOnly;
var
   r: TFactoryRadioBase;
   a, b: TSpectrumLiveDisplay;
begin
   BeginTest('K4 live display: follows the LCD''s #WFH/#WBS/#WFC on pans A and B, never the external monitor''s');
   r := NewK4;
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      r.ProcessMsg('#HWFH070');
      r.ProcessMsg('#HWBS20');
      r.ProcessMsg('#HWFC3');
      CheckTrue(SpectrumLiveDisplayKnowsNothing(r.SpectrumLiveDisplay('A')),
                'the external monitor''s settings give pan A nothing to follow');
      CheckTrue(SpectrumLiveDisplayKnowsNothing(r.SpectrumLiveDisplay('B')),
                'nor pan B');

      r.ProcessMsg('#WFH030');
      r.ProcessMsg('#WBS14');
      r.ProcessMsg('#WFC2');
      a := r.SpectrumLiveDisplay('A');
      b := r.SpectrumLiveDisplay('B');

      CheckTrue(a.HasWaterfallShare and Near(a.WaterfallShare, 0.3), 'pan A share is #WFH 30');
      CheckTrue(a.HasColourFloor and Near(a.ColourFloorOfScale, 0.35), 'pan A colour floor is #WBS 14 / 40');
      CheckTrue(a.HasPalette and (a.Palette = sptTeal), 'pan A palette is #WFC 2, teal');
      CheckTrue(b.HasWaterfallShare and Near(b.WaterfallShare, 0.3), 'pan B follows the same LCD values');
      CheckTrue(b.HasPalette and (b.Palette = sptTeal), 'pan B palette');

      CheckTrue(SpectrumLiveDisplayKnowsNothing(r.SpectrumLiveDisplay('Y')),
                'the Y mini-pan keeps the defaults');

      (* A new link forgets them, so the window falls back to its defaults. *)
      r.Connect;
      CheckTrue(SpectrumLiveDisplayKnowsNothing(r.SpectrumLiveDisplay('A')),
                'a reconnect leaves nothing to follow until the radio answers');
   finally
      r.Free;
   end;
end;

(* "Not yet known" must draw EXACTLY as the window always has: the K4's own
   0.5 share and 10 dB margin.  And the mapping's one anchor: #WBS 5 at the
   80 dB default scale is that same 10 dB. *)
procedure TSpectrumRadioStateTests.Test_UnknownLive_ResolvesToTodaysDefaults;
var
   r: TFactoryRadioBase;
   d: TSpectrumDisplayDefaults;
   live: TSpectrumLiveDisplay;
begin
   BeginTest('Live display: unknown resolves to the radio''s defaults exactly; known resolves to the radio');
   r := NewK4;
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      d := r.SpectrumDisplayDefaults('A');
      live := SpectrumLiveDisplayUnknown;

      CheckTrue(SpectrumWaterfallShare(d, live) = d.WaterfallFraction,
                'unknown share is the defaults'' fraction, to the bit');
      CheckTrue(SpectrumWaterfallColourMarginDb(d, live, 80) = d.RefMarginDb,
                'unknown colour margin is RefMarginDb');
      CheckTrue(SpectrumWaterfallColourMarginDb(d, live, 150) = d.RefMarginDb,
                'whatever the scale');

      r.ProcessMsg('#WBS5');
      live := r.SpectrumLiveDisplay('A');
      CheckTrue(Near(SpectrumWaterfallColourMarginDb(d, live, 80), 10.0),
                '#WBS 5 at 80 dB is 10 dB -- today''s margin');
      r.ProcessMsg('#WBS14');
      live := r.SpectrumLiveDisplay('A');
      CheckTrue(Near(SpectrumWaterfallColourMarginDb(d, live, 80), 28.0),
                '#WBS 14 at 80 dB is 28 dB');
      CheckTrue(Near(SpectrumWaterfallColourMarginDb(d, live, 40), 14.0),
                'and it moves with the scale: 14 dB at 40 dB');

      r.ProcessMsg('#WFH000');
      CheckTrue(SpectrumWaterfallShare(d, r.SpectrumLiveDisplay('A')) = 0,
                '#WFH 0: trace only');
      r.ProcessMsg('#WFH100');
      CheckTrue(SpectrumWaterfallShare(d, r.SpectrumLiveDisplay('A')) = 1,
                '#WFH 100: waterfall only');

      (* A share out of 0..1 from a wrong driver is held to it. *)
      live := SpectrumLiveDisplayUnknown;
      live.HasWaterfallShare := True;
      live.WaterfallShare := 1.5;
      CheckTrue(SpectrumWaterfallShare(d, live) = 1, 'a share above 1 is held to 1');
      live.WaterfallShare := -0.5;
      CheckTrue(SpectrumWaterfallShare(d, live) = 0, 'a share below 0 is held to 0');
   finally
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_PaletteForTone;
begin
   BeginTest('Panadapter: each colour tone names the matching palette');
   CheckEquals(PALETTE_GRAYSCALE, PanadapterPaletteForTone(sptGray), 'gray');
   CheckEquals(PALETTE_HEATMAP, PanadapterPaletteForTone(sptColour), 'colour');
   CheckEquals(PALETTE_BLUEGREEN, PanadapterPaletteForTone(sptTeal), 'teal');
   CheckEquals(PALETTE_FIREICE, PanadapterPaletteForTone(sptBlue),
               'blue -- PROVISIONAL, see docs/PANADAPTER_LCL_DESIGN.md 10.5');
   CheckEquals(PALETTE_SEPIA, PanadapterPaletteForTone(sptSepia), 'sepia');
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
   Test_K4_LiveDisplay_FollowsTheLCDOnly;
   Test_UnknownLive_ResolvesToTodaysDefaults;
   Test_PaletteForTone;
end;

end.
