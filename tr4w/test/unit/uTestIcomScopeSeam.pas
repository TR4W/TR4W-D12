unit uTestIcomScopeSeam;
{$I ..\..\src\tr4w.inc}

{
  Where the Icom bandscope meets TFactoryRadioBase's spectrum seam.

  SEPARATE FROM uTestIcomScope, which is pure -- bytes in, frames out, no radio
  object anywhere.  This suite constructs real driver instances through the
  registry, so it is the half that can catch a per-model DECLARATION being
  wrong, as opposed to the decoding being wrong.

  ---------------------------------------------------------------------------
  WHY THE EXHAUSTIVE TEST IS THE POINT OF THIS FILE
  ---------------------------------------------------------------------------
  CLAUDE.md's rule 9: "a silently-defaulted field reads as a legal zero", and
  "when you move data onto a type, write the exhaustive pin test in the same
  commit".  This family has already been bitten twice by exactly that -- the
  TS-850 declaring rcCWByCAT with no frame rule, and all fourteen keying Icoms
  inheriting an uninitialised maxLen of 0 that read as "no limit".  Neither
  produced a compiler diagnostic and neither was visible by reading.

  Scope geometry is the same shape of hazard and worse, because it is TWO
  numbers and either can be silently zero.  A radio that declares rcSpectrum
  and forgets DeclareScopeGeometry has Points = 0, which decodes every sweep
  into no bins at all: the window opens, the link comes up, frames arrive, and
  nothing is ever drawn.  So:

    * Test_EveryScopeRadioDeclaresGeometry walks EVERY registered model and
      fails if the two ever disagree, in either direction;
    * SCOPE_PINS freezes the actual numbers, so changing one is a deliberate
      act rather than a typo -- and the 689/200 models exist precisely so that
      someone "tidying" them to match the rest is caught.

  ---------------------------------------------------------------------------
  WHAT THESE TESTS DO NOT ESTABLISH
  ---------------------------------------------------------------------------
  That any of the pinned numbers is RIGHT.  They are frozen from the sources
  named in each driver's own comment, and their standing varies by model --
  from the IC-7300MK2 (confirmed against Icom's own CI-V guide) down to the
  IC-7760 (no source anywhere; a provisional guess that a bench session is
  expected to replace).  A pin test protects a number from drifting; it says
  nothing about where the number came from.
}

interface

uses
   SysUtils, uTR4WTestFramework, VC, uSpectrumTypes, uIcomScope,
   uFactoryRadioBase, uRadioRegistry, uRadioIcomBase;

type
   TIcomScopeSeamTests = class(TTestCase)
   protected
      function MakeNetworkIcom(model: InterfacedRadioType): TIcomRadio;

      procedure Test_EveryScopeRadioDeclaresGeometry;
      procedure Test_PinnedGeometriesHaveNotDrifted;
      procedure Test_PinsAreNotStale;
      procedure Test_TwoGeometriesExistAndDiffer;
      procedure Test_SerialIcomHasNoSpectrum;
      procedure Test_NetworkIcomHasSpectrum;
      procedure Test_GeometrylessIcomIsRefused;
      procedure Test_SourceIdMatchesWhatTheDecoderStamps;
      procedure Test_StopWithoutStartIsSafe;
      procedure Test_SpanIsUnknownUntilTheRadioSaysSo;
      procedure Test_SpanLadderStepsAndClamps;
      procedure Test_SpanLadderAnchorsOffLadderValues;
      procedure Test_HalfAndTotalWidthsRoundTrip;

   public
      procedure RunAllTests; override;
   end;

implementation

type
   TScopePin = record
      model: InterfacedRadioType;
      name: string;
      points: Integer;
      maxLevel: Integer;
   end;

const
   { THE FROZEN GEOMETRIES.  Each driver carries its own provenance comment;
     this table exists so the NUMBERS cannot move without someone meaning it.

     Note the two clusters, which is the whole reason this is per-model data:
     475/160 and 689/200.  A future model is expected to be one of those two
     until a capture says otherwise -- but "expected" is not "guaranteed", and
     the IC-7610 row is here to stop anyone folding the table into a constant. }
   SCOPE_PINS: array[0 .. 7] of TScopePin =
      ((model: IC705;     name: 'IC-705';     points: 475; maxLevel: 160),
       (model: IC7300MK2; name: 'IC-7300MK2'; points: 475; maxLevel: 160),
       (model: IC9700;    name: 'IC-9700';    points: 475; maxLevel: 160),
       (model: IC905;     name: 'IC-905';     points: 475; maxLevel: 160),
       (model: IC7760;    name: 'IC-7760';    points: 689; maxLevel: 200),
       (model: IC7610;    name: 'IC-7610';    points: 689; maxLevel: 200),
       (model: IC7850;    name: 'IC-7850';    points: 689; maxLevel: 200),
       (model: IC7851;    name: 'IC-7851';    points: 689; maxLevel: 200));

   // Any routable-looking values will do: SpectrumAvailable asks only that a
   // network link was configured, not that anything is listening.
   TEST_HOST = '192.0.2.10';       // TEST-NET-1, guaranteed unroutable
   TEST_PORT = 50001;

function TIcomScopeSeamTests.MakeNetworkIcom(model: InterfacedRadioType): TIcomRadio;
var
   r: TFactoryRadioBase;
begin
   Result := nil;
   r := uRadioRegistry.CreateInstanceForLink(model, rlNetwork);

   if r = nil then
      begin
      Exit;
      end;

   if not (r is TIcomRadio) then
      begin
      r.Free;
      Exit;
      end;

   { THE FACTORY ASSIGNS THESE AFTER CONSTRUCTION, which is exactly why
     SpectrumAvailable cannot be a constructor-time decision -- the same
     argument docs/PANADAPTER_LCL_DESIGN.md section 3.1 makes for the K4.
     NoPort is portType's zero value, so a freshly built instance already looks
     like a network one until a serial port is written into it. }
   r.radioAddress := TEST_HOST;
   r.radioPort := TEST_PORT;

   Result := TIcomRadio(r);
end;

// ---------------------------------------------------------------------------
// The exhaustive guard
// ---------------------------------------------------------------------------

procedure TIcomScopeSeamTests.Test_EveryScopeRadioDeclaresGeometry;
var
   m: InterfacedRadioType;
   r: TFactoryRadioBase;
   claims: Boolean;
   hasGeometry: Boolean;
begin
   BeginTest('no Icom can declare rcSpectrum without a usable scope geometry');

   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if (m = NoInterfacedRadio) or (not uRadioRegistry.IsRegistered(m)) then
         begin
         Continue;
         end;

      r := uRadioRegistry.CreateInstanceForLink(m, rlNetwork);

      if r = nil then
         begin
         Continue;
         end;

      try
         if not (r is TIcomRadio) then
            begin
            // The K4 and the Flex declare rcSpectrum too and carry no Icom
            // geometry, which is correct: geometry is an Icom fact, and a
            // cross-vendor assertion here would be inventing a requirement.
            Continue;
            end;

         claims := r.Supports(rcSpectrum);
         hasGeometry := IcomScopeGeometryIsValid(TIcomRadio(r).ScopeGeometry);

         if claims then
            begin
            CheckTrue(hasGeometry,
                      uRadioRegistry.ModelId(m) +
                      ' declares rcSpectrum but has no scope geometry -- call ' +
                      'DeclareScopeGeometry in its constructor.  Points = 0 is ' +
                      'legal, silent, and decodes every sweep to nothing.');
            end
         else
            begin
            { THE CONVERSE MATTERS TOO.  A geometry declared without rcSpectrum
              is a driver that decodes sweeps nobody can ask for: the Spectrum
              button never appears, and the reason is one missing enum member in
              a line the reader's eye slides over. }
            CheckFalse(hasGeometry,
                       uRadioRegistry.ModelId(m) +
                       ' declares a scope geometry but not rcSpectrum -- one of ' +
                       'the two is wrong');
            end;
      finally
         r.Free;
      end;
      end;
end;

procedure TIcomScopeSeamTests.Test_PinnedGeometriesHaveNotDrifted;
var
   i: Integer;
   radio: TIcomRadio;
   g: TIcomScopeGeometry;
begin
   BeginTest('every pinned model still reports the geometry it was pinned at');

   for i := Low(SCOPE_PINS) to High(SCOPE_PINS) do
      begin
      radio := MakeNetworkIcom(SCOPE_PINS[i].model);
      CheckTrue(radio <> nil, SCOPE_PINS[i].name + ' should be registered as a network Icom');

      if radio = nil then
         begin
         Continue;
         end;

      try
         g := radio.ScopeGeometry;

         CheckEquals(SCOPE_PINS[i].points, g.Points,
                     SCOPE_PINS[i].name + ' scope points');
         CheckEquals(SCOPE_PINS[i].maxLevel, g.MaxLevel,
                     SCOPE_PINS[i].name + ' scope level range');

         // FreqBytes is five on every model here.  Pinned because the IC-905
         // is the one radio expected to change it, and a change made silently
         // would misalign that model's scope header by two bytes above 10 GHz
         // and yield a plausible wrong centre frequency.
         CheckEquals(5, g.FreqBytes, SCOPE_PINS[i].name + ' frequency bytes');
      finally
         radio.Free;
      end;
      end;
end;

procedure TIcomScopeSeamTests.Test_PinsAreNotStale;
var
   i: Integer;
   radio: TIcomRadio;
begin
   { THE TABLE MUST NOT OUTLIVE THE DECLARATION.  A model whose rcSpectrum was
     removed but whose row stayed would leave this suite asserting a geometry
     nothing reads -- green, and meaningless. }
   BeginTest('a pinned model still claims rcSpectrum');

   for i := Low(SCOPE_PINS) to High(SCOPE_PINS) do
      begin
      radio := MakeNetworkIcom(SCOPE_PINS[i].model);

      if radio = nil then
         begin
         Continue;
         end;

      try
         CheckTrue(radio.Supports(rcSpectrum),
                   SCOPE_PINS[i].name + ' is pinned, so it must still claim rcSpectrum');
      finally
         radio.Free;
      end;
      end;
end;

procedure TIcomScopeSeamTests.Test_TwoGeometriesExistAndDiffer;
var
   small, large: TIcomRadio;
   gs, gl: TIcomScopeGeometry;
begin
   { THE ASSERTION THAT STOPS THE TABLE BECOMING A CONSTANT.  If someone
     "simplifies" the geometry to one pair of numbers, every test above still
     passes as long as the table is edited to match -- this one does not.

     The IC-7610 really is 689/200 and the IC-7300 family really is 475/160,
     from two independent sources, and the difference is why TIcomScopeGeometry
     is a record the model fills in rather than a constant in uIcomScope. }
   BeginTest('the family carries more than one scope geometry');

   small := MakeNetworkIcom(IC9700);
   large := MakeNetworkIcom(IC7610);

   CheckTrue((small <> nil) and (large <> nil), 'both models should construct');

   if (small = nil) or (large = nil) then
      begin
      if small <> nil then small.Free;
      if large <> nil then large.Free;
      Exit;
      end;

   try
      gs := small.ScopeGeometry;
      gl := large.ScopeGeometry;

      CheckTrue(gs.Points <> gl.Points,
                'the IC-9700 and IC-7610 must not share a point count');
      CheckTrue(gs.MaxLevel <> gl.MaxLevel,
                'the IC-9700 and IC-7610 must not share a level range');
   finally
      small.Free;
      large.Free;
   end;
end;

// ---------------------------------------------------------------------------
// The three gates
// ---------------------------------------------------------------------------

procedure TIcomScopeSeamTests.Test_SerialIcomHasNoSpectrum;
var
   r: TFactoryRadioBase;
begin
   { LAN ONLY, FOR NOW, AND THIS IS A DECISION RATHER THAN A LIMIT.  Unlike the
     K4 -- whose stream lives on a TCP port and therefore cannot exist on a
     serial link at all -- an Icom really does push $27 down plain CI-V, and
     uIcomScope decodes the divided serial form with tests for it.  What has not
     happened is anyone watching it work on a wire.  So the gate is shut and the
     decoder is ready; opening it is one line behind a bench session. }
   BeginTest('a serial-linked Icom reports no spectrum');

   r := uRadioRegistry.CreateInstanceForLink(IC7610, rlSerial);
   CheckTrue(r <> nil, 'the IC-7610 should construct for a serial link');

   if r = nil then
      begin
      Exit;
      end;

   try
      r.serialPort := Serial1;
      CheckTrue(r.Supports(rcSpectrum), 'the MODEL still has a scope');
      CheckFalse(r.SpectrumAvailable, 'but THIS connection cannot deliver it');
   finally
      r.Free;
   end;
end;

procedure TIcomScopeSeamTests.Test_NetworkIcomHasSpectrum;
var
   radio: TIcomRadio;
begin
   BeginTest('a network-linked Icom with a geometry reports spectrum');

   radio := MakeNetworkIcom(IC7610);
   CheckTrue(radio <> nil, 'the IC-7610 should construct for a network link');

   if radio = nil then
      begin
      Exit;
      end;

   try
      CheckTrue(radio.SpectrumAvailable, 'all three gates are open');

      // And the streaming/link pair start closed, which is what a window reads
      // to say "Connecting..." rather than "Connected".
      CheckFalse(radio.SpectrumStreaming, 'nothing is streaming before StartSpectrum');
      CheckFalse(radio.SpectrumLinkUp, 'and no link is up');
   finally
      radio.Free;
   end;
end;

procedure TIcomScopeSeamTests.Test_GeometrylessIcomIsRefused;
var
   r: TFactoryRadioBase;
begin
   { AN ICOM WITH NO SCOPE AT ALL.  The IC-7600 has a spectrum display on its
     own panel and does NOT stream one over CI-V -- no source lists spectrum
     caps for it, and $27 $00 arrived with the IC-7300 generation.  Declaring it
     would put a Spectrum button on a radio that answers nothing, which is the
     silent empty window this seam is most able to produce.

     Pinned so that "it has a scope on the front, surely it streams" cannot be
     acted on without someone deleting this test and saying why. }
   BeginTest('an Icom with no CI-V bandscope offers no spectrum');

   r := uRadioRegistry.CreateInstanceForLink(IC7600, rlNetwork);
   CheckTrue(r <> nil, 'the IC-7600 should construct');

   if r = nil then
      begin
      Exit;
      end;

   try
      r.radioAddress := TEST_HOST;
      r.radioPort := TEST_PORT;

      CheckFalse(r.Supports(rcSpectrum), 'the IC-7600 does not claim a CI-V bandscope');
      CheckFalse(r.SpectrumAvailable, 'so no connection can deliver one');
      CheckEquals('', r.PrimarySpectrumSourceId,
                  'and it names no source -- an empty string, not a guess at one');
   finally
      r.Free;
   end;
end;

procedure TIcomScopeSeamTests.Test_SourceIdMatchesWhatTheDecoderStamps;
var
   radio: TIcomRadio;
begin
   { THE FILTER AND THE STAMP MUST AGREE, and nothing validates that they do.
     uPanadapterForm compares TSpectrumFrame.SourceId to what it was opened
     with, by string equality; a mismatch is not an error anywhere, it is a
     window that receives every frame and draws none of them.

     This is the failure the old hardcoded 'A' in uRadioPanelForm would have
     produced on the first Icom, so it gets an assertion rather than a comment. }
   BeginTest('the radio''s primary source id is what the decoder stamps');

   radio := MakeNetworkIcom(IC9700);
   CheckTrue(radio <> nil, 'the IC-9700 should construct');

   if radio = nil then
      begin
      Exit;
      end;

   try
      CheckEquals(IcomScopeSourceId(radio.ScopeIdToFollow),
                  radio.PrimarySpectrumSourceId,
                  'the window''s filter matches the decoder''s stamp');

      // NOT the K4's spelling.  Worth asserting explicitly: 'A' is what the
      // call site used to hand every radio regardless of make.
      CheckTrue(radio.PrimarySpectrumSourceId <> 'A',
                'an Icom does not name its scope the way a K4 names its pans');
   finally
      radio.Free;
   end;
end;

procedure TIcomScopeSeamTests.Test_StopWithoutStartIsSafe;
var
   radio: TIcomRadio;
begin
   { IDEMPOTENT BY CONTRACT, and load-bearing rather than tidy: TIcomRadio's
     DESTRUCTOR calls StopSpectrum, so every Icom ever freed goes through this
     path -- including the 90-odd that have no scope and the ones freed before
     they ever connected. }
   BeginTest('stopping a spectrum that never started is safe');

   radio := MakeNetworkIcom(IC7610);

   if radio = nil then
      begin
      Exit;
      end;

   try
      radio.StopSpectrum;
      radio.StopSpectrum;
      CheckFalse(radio.SpectrumStreaming, 'still not streaming');
   finally
      radio.Free;   // and again, from the destructor
   end;

   Check(True, 'no exception');
end;

procedure TIcomScopeSeamTests.Test_SpanIsUnknownUntilTheRadioSaysSo;
var
   radio: TIcomRadio;
begin
   { ZERO MEANS "THE RIG HAS NOT SAID", and the window shows that as
     "Span: radio has not reported one" rather than stepping from a made-up
     number.  StartSpectrum asks ($27 $15) at connect for exactly this reason:
     the radio pushes the span when the operator changes it but not when we
     arrive. }
   BeginTest('span is unknown until the radio reports it');

   radio := MakeNetworkIcom(IC7610);

   if radio = nil then
      begin
      Exit;
      end;

   try
      CheckEquals(0, radio.SpectrumSpanHz, 'no span before the radio answers');

      // And a step with nothing to step from must not invent one.
      radio.StepSpectrumSpan(1);
      CheckEquals(0, radio.SpectrumSpanHz, 'a step changed nothing');
   finally
      radio.Free;
   end;
end;

// ---------------------------------------------------------------------------
// The span ladder
// ---------------------------------------------------------------------------

procedure TIcomScopeSeamTests.Test_SpanLadderStepsAndClamps;
begin
   { THE REASON StepSpectrumSpan EXISTS.  An Icom snaps a span request to one of
     eight rungs, and the rungs are spaced by ratios of 2 and 2.5 -- so the K4's
     one-kHz trim never crosses a midpoint and the rig hands back the span it
     already had.  AetherSDR measured that as zoom-out inert at all eight spans
     and zoom-in working at seven, an asymmetry that reads as "zoom is broken". }
   BeginTest('one press moves exactly one rung');

   CheckEquals(200000, IcomScopeAdjacentSpanHz(100000, 1), '100 kHz widens to 200');
   CheckEquals(50000, IcomScopeAdjacentSpanHz(100000, -1), '100 kHz narrows to 50');
   CheckEquals(100000, IcomScopeAdjacentSpanHz(100000, 0), 'no direction, no move');

   { CLAMPS AT BOTH ENDS RATHER THAN WRAPPING.  A press at the widest span that
     jumped to the narrowest would be far worse than one that did nothing --
     the operator would lose the whole band with no way to tell what happened. }
   CheckEquals(5000, IcomScopeAdjacentSpanHz(5000, -1),
               'the narrowest span stays put, it does not wrap to the widest');
   CheckEquals(1000000, IcomScopeAdjacentSpanHz(1000000, 1),
               'the widest span stays put');

   // And the ladder itself, walked end to end -- these are TOTAL widths, twice
   // Icom's own +/-2.5k .. +/-500k.
   CheckEquals(5000, IcomScopeSpanHz(0), 'rung 0');
   CheckEquals(1000000, IcomScopeSpanHz(7), 'rung 7');
   CheckEquals(5000, IcomScopeSpanHz(-3), 'an index below the ladder clamps');
   CheckEquals(1000000, IcomScopeSpanHz(99), 'an index above it clamps');
end;

procedure TIcomScopeSeamTests.Test_SpanLadderAnchorsOffLadderValues;
begin
   { ANCHOR FIRST, THEN STEP.  The "current" span comes from the radio, and a
     value a few Hz off a rung -- or from a rig whose ladder differs slightly --
     must not fall through the search and land back at the bottom.  That is a
     press that appears to jump to 5 kHz from nowhere. }
   BeginTest('an off-ladder span anchors on the nearest rung before stepping');

   CheckEquals(100000, IcomScopeNearestSpanHz(99000), '99 kHz snaps to 100');
   CheckEquals(100000, IcomScopeNearestSpanHz(101000), '101 kHz snaps to 100');
   CheckEquals(5000, IcomScopeNearestSpanHz(1), 'below the ladder snaps to the bottom');
   CheckEquals(1000000, IcomScopeNearestSpanHz(99000000), 'above it snaps to the top');

   CheckEquals(200000, IcomScopeAdjacentSpanHz(99000, 1),
               'a near-miss still widens by one rung, not to the bottom');
   CheckEquals(50000, IcomScopeAdjacentSpanHz(101000, -1),
               'and narrows by one rung');
end;

procedure TIcomScopeSeamTests.Test_HalfAndTotalWidthsRoundTrip;
var
   i: Integer;
   total: Integer;
begin
   { THE FACTOR OF TWO, PINNED.  Icom's wire carries the HALF-width the front
     panel shows ("+/-100k"); TSpectrumFrame.SpanHz and SpectrumSpanHz are
     TOTALS.  Both references warn that reversing this is the error people
     actually make, and it produces a display right about its centre and wrong
     by 2x about its extent -- signals at half or double their true offset,
     which reads as a tuning fault rather than a geometry one. }
   BeginTest('half-width and total-width conversions round-trip on every rung');

   CheckEquals(100000, IcomScopeTotalToHalfHz(200000), '200 kHz total is +/-100 kHz');
   CheckEquals(200000, IcomScopeHalfToTotalHz(100000), 'and back again');

   for i := 0 to 7 do
      begin
      total := IcomScopeSpanHz(i);
      CheckEquals(total, IcomScopeHalfToTotalHz(IcomScopeTotalToHalfHz(total)),
                  'rung ' + IntToStr(i) + ' survives the round trip');
      end;
end;

// ---------------------------------------------------------------------------

procedure TIcomScopeSeamTests.RunAllTests;
begin
   Test_EveryScopeRadioDeclaresGeometry;
   Test_PinnedGeometriesHaveNotDrifted;
   Test_PinsAreNotStale;
   Test_TwoGeometriesExistAndDiffer;

   Test_SerialIcomHasNoSpectrum;
   Test_NetworkIcomHasSpectrum;
   Test_GeometrylessIcomIsRefused;
   Test_SourceIdMatchesWhatTheDecoderStamps;
   Test_StopWithoutStartIsSafe;
   Test_SpanIsUnknownUntilTheRadioSaysSo;

   Test_SpanLadderStepsAndClamps;
   Test_SpanLadderAnchorsOffLadderValues;
   Test_HalfAndTotalWidthsRoundTrip;
end;

end.
