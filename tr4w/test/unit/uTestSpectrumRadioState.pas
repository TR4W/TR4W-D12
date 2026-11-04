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
  - a new link (Connect) HOLDS the last session's values until the radio
    reports new ones (NY4I, 2026-11-03), and a fresh report replaces them;
  - a K4 that does not declare rcSpectrum answers nothing whatever it hears;
  - over the WHOLE REGISTRY, a freshly built radio knows nothing, and the
    Icoms -- which have spectrum but report no such settings -- inherit the
    base's answer;
  - the window: the palette table (pure), the vertical reference (pure), and
    on a real TfrmPanadapter -- a first report equal to the default palette
    still takes effect, a reconnect keeps the picture and a fresh report
    replaces it, and a radio switch inherits no radio-chosen palette while
    the operator's own choice stands;
  - the SCALE (NY4I, option (b)): the slider policy (pure), the K4 refusing
    an out-of-range #SCL, and on a real TfrmPanadapter -- a changed #SCL moves
    the slider, the operator's drag stands through a repeat, a first report
    equal to the default applies, a reconnect holds, a radio switch inherits
    nothing, the window clamps, and the Y mini-pan is the operator's alone.
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
      procedure Test_K4_ReconnectHoldsTheLastSession;
      procedure Test_K4WithoutSpectrum_AnswersNothing;
      procedure Test_IC9700_InheritsTheBaseAnswer;
      procedure Test_EveryRegisteredRadio_FreshKnowsNothing;
      procedure Test_K4_LiveDisplay_FollowsTheLCDOnly;
      procedure Test_UnknownLive_ResolvesToTodaysDefaults;
      procedure Test_PaletteForTone;
      procedure Test_PaletteTable_BlueTone;
      procedure Test_VerticalReference_RadioOrNoiseFloor;
      procedure Test_Window_FirstReportEqualToDefault_TakesEffect;
      procedure Test_Window_ReconnectHolds_FreshReportReplaces;
      procedure Test_Window_RadioSwitch_InheritsNoRadioPalette;
      procedure Test_ScalePolicy_Pure;
      procedure Test_K4_OutOfRangeScale_IsNotClaimed;
      procedure Test_Window_RadioScale_AppliedOnChange_OperatorStands;
      procedure Test_Window_RadioScale_FirstReportEqualToDefault_TakesEffect;
      procedure Test_Window_RadioScale_ReconnectHolds_SwitchInheritsNothing;
      procedure Test_Window_RadioScale_ClampedAtTheSlider;
      procedure Test_Window_RadioScale_YMiniPanUntouched;
      procedure CheckScaleShown(AForm: TObject; AScaleDb: Integer; const AWhat: string);
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

type
   (* A K4 whose live display claims whatever scale the test sets, legal or
      not.  A real K4 cannot hand the window an out-of-range #SCL --
      uK4DisplayReport refuses it -- so this is the only way to reach the
      window's own clamp. *)
   TK4WithStatedScale = class(TK4Radio)
   public
      StatedScaleDb: Integer;
      function SpectrumLiveDisplay(const ASourceId: string): TSpectrumLiveDisplay; override;
   end;

function TK4WithStatedScale.SpectrumLiveDisplay(const ASourceId: string): TSpectrumLiveDisplay;
begin
   Result := SpectrumLiveDisplayUnknown;
   Result.HasScale := True;
   Result.ScaleDb := StatedScaleDb;
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

procedure TSpectrumRadioStateTests.Test_K4_ReconnectHoldsTheLastSession;
var
   r: TFactoryRadioBase;
   before, after: TSpectrumRadioState;
begin
   BeginTest('K4: a new link HOLDS the last session''s display reports until the radio says otherwise');
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
      CheckTrue(after.HasRef and (after.RefDb = -126),
                'pan A still holds its REF after a reconnect: ' + Describe(after));
      CheckTrue(after.HasScale and (after.ScaleDb = 80), 'and its scale');
      CheckTrue(r.SpectrumRadioState('B').HasRef, 'pan B holds its REF too');
      CheckEquals(before.Generation, after.Generation,
                  'a reconnect is not a report: Generation did not move');

      (* The radio's next answer replaces the held value. *)
      r.ProcessMsg('#REF-110');
      CheckEquals(-110, r.SpectrumRadioState('A').RefDb, 'a fresh report replaces it');
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

      (* A new link HOLDS them, so the window keeps its picture. *)
      r.Connect;
      a := r.SpectrumLiveDisplay('A');
      CheckTrue(a.HasWaterfallShare and Near(a.WaterfallShare, 0.3),
                'a reconnect keeps the share');
      CheckTrue(a.HasPalette and (a.Palette = sptTeal), 'and the palette');
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
   CheckEquals(PALETTE_BLUE, PanadapterPaletteForTone(sptBlue), 'blue');
   CheckEquals(PALETTE_SEPIA, PanadapterPaletteForTone(sptSepia), 'sepia');
end;

function LutRed(AColour: LongWord): Integer;
begin
   Result := (AColour shr 16) and $FF;
end;

function LutGreen(AColour: LongWord): Integer;
begin
   Result := (AColour shr 8) and $FF;
end;

function LutBlue(AColour: LongWord): Integer;
begin
   Result := AColour and $FF;
end;

(* The table is $00RRGGBB (the bitmap's layout), not a TColor. *)
procedure TSpectrumRadioStateTests.Test_PaletteTable_BlueTone;
var
   p, i: Integer;
   c, prev: LongWord;
   tone: TSpectrumPaletteTone;
   bad: string;
begin
   BeginTest('Palette table: every palette starts at black; Blue is blue-led and never darkens; no tone is Fire-Ice');
   bad := '';

   for p := 0 to PALETTE_COUNT - 1 do
      begin
      if PanadapterPaletteColour(p, 0) <> 0 then
         begin
         bad := bad + 'palette ' + IntToStr(p) + ' entry 0 is not black; ';
         end;
      end;

   CheckEquals('', bad, 'the noise floor must not flood the waterfall');

   prev := PanadapterPaletteColour(PALETTE_BLUE, 0);

   for i := 1 to 255 do
      begin
      c := PanadapterPaletteColour(PALETTE_BLUE, i);

      if (LutBlue(c) < LutGreen(c)) or (LutBlue(c) < LutRed(c)) then
         begin
         bad := bad + 'entry ' + IntToStr(i) + ' is not blue-led; ';
         end;

      if (LutRed(c) < LutRed(prev)) or (LutGreen(c) < LutGreen(prev)) or (LutBlue(c) < LutBlue(prev)) then
         begin
         bad := bad + 'entry ' + IntToStr(i) + ' is darker than the one below; ';
         end;

      prev := c;
      end;

   CheckEquals('', bad, 'the Blue tone');

   c := PanadapterPaletteColour(PALETTE_BLUE, 255);
   CheckEquals(150, LutRed(c), 'top of Blue: red 150');
   CheckEquals(250, LutGreen(c), 'top of Blue: green 250');
   CheckEquals(255, LutBlue(c), 'top of Blue: blue 255 -- a pale blue-white');

   (* A dark run, as every palette here has: a quarter of the way up is still
      dark, so the noise floor is not already bright. *)
   c := PanadapterPaletteColour(PALETTE_BLUE, 64);
   CheckTrue(LutBlue(c) <= 80, 'a quarter of the way up is still dark blue');

   (* Fire-Ice is the operator's own; the radio never selects it. *)
   for tone := Low(TSpectrumPaletteTone) to High(TSpectrumPaletteTone) do
      begin
      if PanadapterPaletteForTone(tone) = PALETTE_FIREICE then
         begin
         bad := bad + 'tone ' + IntToStr(Ord(tone)) + ' maps to Fire-Ice; ';
         end;
      end;

   CheckEquals('', bad, 'no radio tone selects Fire-Ice');
end;

(* QK4: minDb = REF, maxDb = REF + SCALE, no margin.  Unknown: the window's
   own model, exactly. *)
procedure TSpectrumRadioStateTests.Test_VerticalReference_RadioOrNoiseFloor;
var
   d: TSpectrumDisplayDefaults;
   live: TSpectrumLiveDisplay;
begin
   BeginTest('Vertical reference: the radio''s REF when stated, else the frame''s noise floor');
   d := MakeSpectrumDisplayDefaults(80, 10, 150, 10.0, 0.5, True);
   live := SpectrumLiveDisplayUnknown;

   CheckTrue(SpectrumReferenceDb(live, -125.5) = -125.5,
             'unknown: a row is stored against the frame''s noise floor');
   CheckTrue(SpectrumTraceFloorDb(d, live, -125.5) = -135.5,
             'unknown: the trace starts RefMarginDb below the noise floor, as always');

   live.HasRef := True;
   live.RefDb := -110;
   CheckTrue(SpectrumReferenceDb(live, -125.5) = -110, 'known: a row is stored against REF');
   CheckTrue(SpectrumTraceFloorDb(d, live, -125.5) = -110,
             'known: the trace starts AT REF, no margin (QK4)');
   CheckFalse(SpectrumLiveDisplayKnowsNothing(live), 'a REF is something known');

   live := SpectrumLiveDisplayUnknown;
   live.HasScale := True;
   live.ScaleDb := 50;
   CheckFalse(SpectrumLiveDisplayKnowsNothing(live), 'so is a scale');
end;

(* Attach a radio to a real, unshown panadapter.  The refresh tick is called
   directly: it is the path that applies the radio's live display. *)
procedure Tick(AForm: TfrmPanadapter);
begin
   AForm.HandleRefreshTimer(nil);
end;

procedure OperatorPicks(AForm: TfrmPanadapter; APalette: Integer);
begin
   AForm.cboPalette.ItemIndex := APalette;
   AForm.HandlePaletteChange(nil);
end;

procedure TSpectrumRadioStateTests.Test_Window_FirstReportEqualToDefault_TakesEffect;
var
   form: TfrmPanadapter;
   r: TFactoryRadioBase;
begin
   BeginTest('Panadapter: the first #WFC, even one naming the default palette, replaces the operator''s pick');
   r := NewK4;
   form := TfrmPanadapter.Create(nil);

   try
      CheckEquals(PALETTE_COUNT, form.cboPalette.Items.Count, 'the combo holds every palette');
      CheckEquals('Blue', form.cboPalette.Items[PALETTE_BLUE], 'Blue is appended last');

      form.AttachRadio(r, r.PrimarySpectrumSourceId);
      OperatorPicks(form, PALETTE_GRAYSCALE);
      Tick(form);
      CheckEquals(PALETTE_GRAYSCALE, form.cboPalette.ItemIndex,
                  'nothing reported: the operator''s pick stands');

      (* #WFC1 is colour, which is the window's own default palette. *)
      r.ProcessMsg('#WFC1');
      Tick(form);
      CheckEquals(PALETTE_HEATMAP, form.cboPalette.ItemIndex,
                  'the first report applies, though it equals the default');

      r.ProcessMsg('#WFC3');
      Tick(form);
      CheckEquals(PALETTE_BLUE, form.cboPalette.ItemIndex, '#WFC3 is the Blue palette');
   finally
      form.Free;
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_Window_ReconnectHolds_FreshReportReplaces;
var
   form: TfrmPanadapter;
   r: TFactoryRadioBase;
begin
   BeginTest('Panadapter: a K4 reconnect keeps the picture; the radio''s next report replaces it');
   r := NewK4;
   form := TfrmPanadapter.Create(nil);

   try
      form.AttachRadio(r, r.PrimarySpectrumSourceId);
      r.ProcessMsg('#WFC0');
      Tick(form);
      CheckEquals(PALETTE_GRAYSCALE, form.cboPalette.ItemIndex, 'precondition: gray');

      (* No address: the attempt goes nowhere, but it is a new link. *)
      r.Connect;
      Tick(form);
      CheckEquals(PALETTE_GRAYSCALE, form.cboPalette.ItemIndex,
                  'after the reconnect the window still draws gray');

      (* Close and reopen: the radio holds, so a re-attach gets it back. *)
      form.DetachRadio;
      form.AttachRadio(r, r.PrimarySpectrumSourceId);
      Tick(form);
      CheckEquals(PALETTE_GRAYSCALE, form.cboPalette.ItemIndex,
                  'and after a re-attach to the same radio');

      r.ProcessMsg('#WFC4');
      Tick(form);
      CheckEquals(PALETTE_SEPIA, form.cboPalette.ItemIndex, 'a fresh report replaces it');
   finally
      form.Free;
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_Window_RadioSwitch_InheritsNoRadioPalette;
var
   form: TfrmPanadapter;
   first, second, icom: TFactoryRadioBase;
begin
   BeginTest('Panadapter: a radio switch inherits no radio-chosen palette; the operator''s choice stands');
   first := NewK4;
   second := NewK4;
   icom := uRadioRegistry.CreateInstance(IC9700);
   form := TfrmPanadapter.Create(nil);

   try
      CheckTrue(icom <> nil, 'the registry built no IC-9700');

      if icom = nil then
         begin
         Exit;
         end;

      form.AttachRadio(first, first.PrimarySpectrumSourceId);
      first.ProcessMsg('#WFC4');
      Tick(form);
      CheckEquals(PALETTE_SEPIA, form.cboPalette.ItemIndex, 'precondition: the first K4 chose sepia');

      (* A different K4 -- a profile switch builds a new object -- that has
         reported nothing. *)
      form.DetachRadio;
      form.AttachRadio(second, second.PrimarySpectrumSourceId);
      CheckEquals(PALETTE_DEFAULT, form.cboPalette.ItemIndex,
                  'the first radio''s sepia is not inherited');
      Tick(form);
      CheckEquals(PALETTE_DEFAULT, form.cboPalette.ItemIndex,
                  'and the new radio, knowing nothing, leaves the default');

      (* The operator's own choice is not a radio's, and survives a switch. *)
      OperatorPicks(form, PALETTE_FIREICE);
      form.DetachRadio;
      form.AttachRadio(icom, icom.PrimarySpectrumSourceId);
      Tick(form);
      CheckEquals(PALETTE_FIREICE, form.cboPalette.ItemIndex,
                  'the operator''s Fire-Ice stands across a switch');
   finally
      form.Free;
      first.Free;
      second.Free;
      icom.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE SCALE SLIDER FOLLOWS THE RADIO'S #SCL WHEN IT CHANGES (NY4I, option (b),
   2026-11-03).  No write: nothing on these paths sends, and
   uTestRadioSocketNoRead pins what the K4 asks at connect -- reads only.
   --------------------------------------------------------------------------- *)

function LiveWithScale(AScaleDb: Integer): TSpectrumLiveDisplay;
begin
   Result := SpectrumLiveDisplayUnknown;
   Result.HasScale := True;
   Result.ScaleDb := AScaleDb;
end;

(* The operator's drag: Position raises OnChange, as the widget does. *)
procedure OperatorDragsScale(AForm: TfrmPanadapter; AScaleDb: Integer);
begin
   AForm.trkScale.Position := AScaleDb;
end;

(* AForm is a TfrmPanadapter; TObject in the declaration only because the
   interface section does not use uPanadapterForm. *)
procedure TSpectrumRadioStateTests.CheckScaleShown(AForm: TObject; AScaleDb: Integer;
                                                   const AWhat: string);
var
   form: TfrmPanadapter;
begin
   form := AForm as TfrmPanadapter;
   CheckEquals(AScaleDb, form.trkScale.Position, AWhat + ' (slider)');
   CheckEquals(IntToStr(AScaleDb) + ' dB', form.lblScale.Caption, AWhat + ' (caption)');
end;

procedure TSpectrumRadioStateTests.Test_ScalePolicy_Pure;
var
   d: TSpectrumDisplayDefaults;
   none: TSpectrumLiveDisplay;
begin
   BeginTest('Scale policy: the radio''s scale applies when it CHANGES, clamped; otherwise the slider stands');
   d := MakeSpectrumDisplayDefaults(80, 10, 150, 10.0, 0.5, True);
   none := SpectrumLiveDisplayUnknown;

   CheckEquals(10, SpectrumClampScaleDb(d, 5), 'below the range: the minimum');
   CheckEquals(150, SpectrumClampScaleDb(d, 200), 'above the range: the maximum');
   CheckEquals(40, SpectrumClampScaleDb(d, 40), 'inside: unchanged');
   CheckEquals(1, SpectrumClampScaleDb(SpectrumDisplayDefaultsNone, 0),
               'never below 1, whatever the defaults -- the waterfall divides by it');

   CheckFalse(SpectrumRadioScaleChanged(none, none), 'no report: nothing to apply');
   CheckTrue(SpectrumRadioScaleChanged(none, LiveWithScale(80)),
             'a first report applies, even one equal to the default');
   CheckFalse(SpectrumRadioScaleChanged(LiveWithScale(40), LiveWithScale(40)),
              'a repeat is not a change');
   CheckTrue(SpectrumRadioScaleChanged(LiveWithScale(40), LiveWithScale(50)),
             'a different value is');
   CheckFalse(SpectrumRadioScaleChanged(LiveWithScale(40), none),
              'a radio that stops saying leaves the slider where it is');

   CheckEquals(60, SpectrumScaleAfterReport(d, LiveWithScale(40), LiveWithScale(40), 60),
               'the operator''s 60 stands while the radio repeats 40');
   CheckEquals(50, SpectrumScaleAfterReport(d, LiveWithScale(40), LiveWithScale(50), 60),
               'the radio''s new 50 replaces it');
   CheckEquals(150, SpectrumScaleAfterReport(d, none, LiveWithScale(200), 60),
               'a changed value out of range is clamped');
   CheckEquals(60, SpectrumScaleAfterReport(d, none, none, 60), 'unknown: the slider stands');
end;

procedure TSpectrumRadioStateTests.Test_K4_OutOfRangeScale_IsNotClaimed;
var
   r: TFactoryRadioBase;
begin
   BeginTest('K4: an #SCL outside 10..150 never reaches the window');
   r := NewK4;
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      r.ProcessMsg('#SCL200');
      CheckFalse(r.SpectrumLiveDisplay('A').HasScale, '#SCL200 is refused');
      r.ProcessMsg('#SCL005');
      CheckFalse(r.SpectrumLiveDisplay('A').HasScale, '#SCL005 is refused');
      r.ProcessMsg('#SCL150');
      CheckTrue(r.SpectrumLiveDisplay('A').HasScale and (r.SpectrumLiveDisplay('A').ScaleDb = 150),
                '#SCL150, the top of the range, is accepted');
   finally
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_Window_RadioScale_AppliedOnChange_OperatorStands;
var
   form: TfrmPanadapter;
   r: TFactoryRadioBase;
begin
   BeginTest('Panadapter: a changed #SCL moves the slider; the operator''s drag stands until the radio says something different');
   r := NewK4;
   form := TfrmPanadapter.Create(nil);

   try
      form.AttachRadio(r, r.PrimarySpectrumSourceId);
      CheckEquals(10, form.trkScale.Min, 'the slider holds the K4''s whole range: min');
      CheckEquals(150, form.trkScale.Max, 'and max');
      Tick(form);
      CheckScaleShown(form, 80, 'nothing reported: the default');

      r.ProcessMsg('#SCL040');
      Tick(form);
      CheckScaleShown(form, 40, 'the radio''s #SCL 40 moves the slider');

      OperatorDragsScale(form, 60);
      CheckScaleShown(form, 60, 'the operator drags to 60');
      Tick(form);
      CheckScaleShown(form, 60, 'the next tick keeps the operator''s 60');

      r.ProcessMsg('#SCL040');   // the radio repeats itself
      Tick(form);
      CheckScaleShown(form, 60, 'a repeated #SCL 40 does not undo the drag');

      r.ProcessMsg('#SCL050');
      Tick(form);
      CheckScaleShown(form, 50, 'a DIFFERENT #SCL replaces the operator''s value');
   finally
      form.Free;
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_Window_RadioScale_FirstReportEqualToDefault_TakesEffect;
var
   form: TfrmPanadapter;
   r: TFactoryRadioBase;
begin
   BeginTest('Panadapter: a first #SCL equal to the slider''s default still takes effect after an attach');
   r := NewK4;
   form := TfrmPanadapter.Create(nil);

   try
      form.AttachRadio(r, r.PrimarySpectrumSourceId);
      OperatorDragsScale(form, 60);
      Tick(form);
      CheckScaleShown(form, 60, 'nothing reported: the operator''s 60 stands');

      r.ProcessMsg('#SCL080');
      Tick(form);
      CheckScaleShown(form, 80, '#SCL 80 -- the default -- is a report, and it applies');
   finally
      form.Free;
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_Window_RadioScale_ReconnectHolds_SwitchInheritsNothing;
var
   form: TfrmPanadapter;
   first, second, icom: TFactoryRadioBase;
begin
   BeginTest('Panadapter: a reconnect holds the radio''s scale; a radio switch inherits none; the operator''s stands');
   first := NewK4;
   second := NewK4;
   icom := uRadioRegistry.CreateInstance(IC9700);
   form := TfrmPanadapter.Create(nil);

   try
      CheckTrue(icom <> nil, 'the registry built no IC-9700');

      if icom = nil then
         begin
         Exit;
         end;

      form.AttachRadio(first, first.PrimarySpectrumSourceId);
      first.ProcessMsg('#SCL040');
      Tick(form);
      CheckScaleShown(form, 40, 'precondition: the radio set 40');

      first.Connect;   // no address: goes nowhere, but a new link
      Tick(form);
      CheckScaleShown(form, 40, 'a reconnect holds it');

      form.DetachRadio;
      form.AttachRadio(first, first.PrimarySpectrumSourceId);
      Tick(form);
      CheckScaleShown(form, 40, 'a re-attach to the same radio gets it back');

      (* A different K4, which has reported nothing. *)
      form.DetachRadio;
      form.AttachRadio(second, second.PrimarySpectrumSourceId);
      CheckScaleShown(form, 80, 'the first radio''s 40 is not inherited');
      Tick(form);
      CheckScaleShown(form, 80, 'and the new radio, knowing nothing, leaves the default');

      (* The operator's own scale is not a radio's, and survives a switch to a
         radio with the same range. *)
      OperatorDragsScale(form, 60);
      form.DetachRadio;
      form.AttachRadio(icom, icom.PrimarySpectrumSourceId);
      Tick(form);
      CheckScaleShown(form, 60, 'the operator''s 60 stands across a switch to an Icom');
   finally
      form.Free;
      first.Free;
      second.Free;
      icom.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_Window_RadioScale_ClampedAtTheSlider;
var
   form: TfrmPanadapter;
   r: TK4WithStatedScale;
begin
   BeginTest('Panadapter: a radio scale outside the slider''s range is held to it');
   r := TK4WithStatedScale.Create;
   form := TfrmPanadapter.Create(nil);

   try
      r.StatedScaleDb := 200;
      form.AttachRadio(r, r.PrimarySpectrumSourceId);
      Tick(form);
      CheckScaleShown(form, 150, '200 is held to the top, 150');

      r.StatedScaleDb := 5;
      Tick(form);
      CheckScaleShown(form, 10, '5 is held to the bottom, 10');
   finally
      form.Free;
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.Test_Window_RadioScale_YMiniPanUntouched;
var
   form: TfrmPanadapter;
   r: TFactoryRadioBase;
begin
   BeginTest('Panadapter: the Y mini-pan has no radio scale; the slider is the operator''s alone');
   r := NewK4;
   form := TfrmPanadapter.Create(nil);

   try
      form.AttachRadio(r, 'Y');
      r.ProcessMsg('#SCL040');
      Tick(form);
      CheckScaleShown(form, 80, '#SCL reaches pans A and B, not Y');

      OperatorDragsScale(form, 60);
      Tick(form);
      CheckScaleShown(form, 60, 'the operator''s drag works as always');
   finally
      form.Free;
      r.Free;
   end;
end;

procedure TSpectrumRadioStateTests.RunAllTests;
begin
   Test_K4_NoReports_KnowsNothing;
   Test_K4_MainAndSubAreSeparate;
   Test_K4_FirstReportEqualToDefault_IsKnown;
   Test_K4_ReconnectHoldsTheLastSession;
   Test_K4WithoutSpectrum_AnswersNothing;
   Test_IC9700_InheritsTheBaseAnswer;
   Test_EveryRegisteredRadio_FreshKnowsNothing;
   Test_K4_LiveDisplay_FollowsTheLCDOnly;
   Test_UnknownLive_ResolvesToTodaysDefaults;
   Test_PaletteForTone;
   Test_PaletteTable_BlueTone;
   Test_VerticalReference_RadioOrNoiseFloor;
   Test_Window_FirstReportEqualToDefault_TakesEffect;
   Test_Window_ReconnectHolds_FreshReportReplaces;
   Test_Window_RadioSwitch_InheritsNoRadioPalette;
   Test_ScalePolicy_Pure;
   Test_K4_OutOfRangeScale_IsNotClaimed;
   Test_Window_RadioScale_AppliedOnChange_OperatorStands;
   Test_Window_RadioScale_FirstReportEqualToDefault_TakesEffect;
   Test_Window_RadioScale_ReconnectHolds_SwitchInheritsNothing;
   Test_Window_RadioScale_ClampedAtTheSlider;
   Test_Window_RadioScale_YMiniPanUntouched;
end;

end.
