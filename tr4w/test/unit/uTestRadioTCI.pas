unit uTestRadioTCI;
{$I ..\..\src\tr4w.inc}

{
  THE NINE METHODS THAT USED TO CRASH.

  TFactoryRadioBase declares 29 methods Virtual; Abstract. TTCIRadio implemented
  20 of them. The other nine -- ToggleMode, SetBand, ToggleBand, SetFilter,
  MemoryKeyer, RITBumpUp/Down, VFOBumpUp/Down -- were left abstract, so a key
  press that reached any of them was an access violation on a radio that was
  otherwise working.

  The compiler DOES report this, as nine W1020 "Constructing instance of
  TTCIRadio containing abstract method" warnings -- but only on a full /t:Build.
  An incremental /t:Make skips the unit that constructs the object and the
  warnings never appear, which is exactly how they went unnoticed. A warning you
  only see on a build nobody runs before committing is not a safety net; this
  test is.

  THE PRIMARY ASSERTION IS "DOES NOT FAULT". Every one of the nine is called.
  Before the fix each of those calls access-violated; a test that only checked
  the emitted text would have failed for the wrong reason and told us less.

  NO TRANSPORT: the probe overrides SendToRadio to capture the wire, so this
  runs in CI and proves what the DRIVER emits, never what a server accepts.
  Same shape as uTestKenwoodSerial.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioBand, uRadioTCI, VC;

type
   TRadioTCITests = class(TTestCase)
   protected
      procedure Test_NoneOfTheNineFault;
      procedure Test_ToggleModeCyclesAndSends;
      procedure Test_ToggleModeWrapsAtTheEnd;
      procedure Test_SetBandTunesToTheBandFrequency;
      procedure Test_ToggleBandCyclesAndWraps;
      procedure Test_SetFilterSendsSymmetricEdges;
      procedure Test_MemoryKeyerRefusesAndSendsNothing;
      procedure Test_RelativeTuneSendsNothing;
      (* CW over TCI. All three pin something that failed SILENTLY on a real
        K4 until 2026-09-17 -- no keying, no error, no reply -- so each is a
        regression pin rather than a style check. *)
      procedure Test_CWSendsTheReceiverIndex;
      procedure Test_CWProsignsUseTheTCISpellings;
      procedure Test_CWEscapesReservedCharacters;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TTCIProbe = class(TTCIRadio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
      procedure Clear;
   end;

procedure TTCIProbe.SendToRadio(s: string);
begin
   // Appended, not replaced: a method that emits two commands must not be able
   // to hide the first one behind the second.
   sent := sent + s;
end;

procedure TTCIProbe.Clear;
begin
   sent := '';
end;

{ ------------------------------------------------------------------------- }

// The regression itself. Every one of the nine is exercised; before the fix
// this test could not even run to completion.
procedure TRadioTCITests.Test_NoneOfTheNineFault;
var
   r: TTCIProbe;
begin
   BeginTest('Test_NoneOfTheNineFault');
   r := TTCIProbe.Create;
   try
      r.ToggleMode(nrVFOA);
      r.SetBand(rb20m, nrVFOA);
      r.ToggleBand(nrVFOA);
      r.SetFilter(rfNarrow, nrVFOA);
      r.MemoryKeyer(1);
      r.RITBumpUp;
      r.RITBumpDown;
      r.VFOBumpUp(nrVFOA);
      r.VFOBumpDown(nrVFOA);

      // Reaching this line IS the assertion -- every call above was an abstract
      // method, and an abstract call raises rather than returning.
      Check(True, 'all nine formerly-abstract methods are callable');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_ToggleModeCyclesAndSends;
var
   r: TTCIProbe;
begin
   BeginTest('Test_ToggleModeCyclesAndSends');
   r := TTCIProbe.Create;
   try
      r.vfo[nrVFOA].mode := rmUSB;
      r.Clear;

      CheckEquals(Ord(rmCW), Ord(r.ToggleMode(nrVFOA)),
                  'USB toggles to CW, matching the Icom family order');
      Check(Pos('modulation:', r.sent) > 0,
            'a mode change must actually reach the wire, not only the cache');
   finally
      r.Free;
   end;
end;

// The wrap is the arm that a case statement most often gets wrong, and getting
// it wrong strands the operator on the last mode with the key doing nothing.
procedure TRadioTCITests.Test_ToggleModeWrapsAtTheEnd;
var
   r: TTCIProbe;
begin
   BeginTest('Test_ToggleModeWrapsAtTheEnd');
   r := TTCIProbe.Create;
   try
      r.vfo[nrVFOA].mode := rmFM;
      CheckEquals(Ord(rmLSB), Ord(r.ToggleMode(nrVFOA)), 'FM wraps round to LSB');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_SetBandTunesToTheBandFrequency;
var
   r: TTCIProbe;
begin
   BeginTest('Test_SetBandTunesToTheBandFrequency');
   r := TTCIProbe.Create;
   try
      r.Clear;
      r.SetBand(rb20m, nrVFOA);

      // TCI has no band command, so a band change MUST appear as a tune. If this
      // ever emits nothing, the band keys silently stop working.
      Check(Pos('vfo:', r.sent) > 0,
            'SetBand reaches the radio as a vfo: tune');
      Check(Pos(IntToStr(r.BandToFreq(rb20m)), r.sent) > 0,
            'and tunes to the base table frequency, not a second copy of it');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_ToggleBandCyclesAndWraps;
var
   r: TTCIProbe;
begin
   BeginTest('Test_ToggleBandCyclesAndWraps');
   r := TTCIProbe.Create;
   try
      r.vfo[nrVFOA].band := rb20m;
      CheckEquals(Ord(rb15m), Ord(r.ToggleBand(nrVFOA)), '20m steps up to 15m');

      r.vfo[nrVFOA].band := rb10m;
      CheckEquals(Ord(rb160m), Ord(r.ToggleBand(nrVFOA)),
                  '10m wraps round to 160m');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_SetFilterSendsSymmetricEdges;
var
   r: TTCIProbe;
begin
   BeginTest('Test_SetFilterSendsSymmetricEdges');
   r := TTCIProbe.Create;
   try
      r.Clear;
      r.SetFilter(rfNarrow, nrVFOA);

      // TCI takes EDGES relative to the carrier, not a width -- a driver that
      // sent the width would give a filter twice as wide as asked for.
      Check(Pos('rx_filter_band:0,-250,250;', r.sent) > 0,
            'narrow = 500 Hz wide, sent as -250/+250 edges');

      r.Clear;
      r.SetFilter(rfWide, nrVFOA);
      Check(Pos('rx_filter_band:0,-1350,1350;', r.sent) > 0,
            'wide = 2700 Hz wide, sent as -1350/+1350 edges');
   finally
      r.Free;
   end;
end;

// True means ERROR/UNSUPPORTED for this method -- the house convention, and it
// fails closed. A driver returning False here would tell the caller a memory
// was played when nothing happened.
procedure TRadioTCITests.Test_MemoryKeyerRefusesAndSendsNothing;
var
   r: TTCIProbe;
begin
   BeginTest('Test_MemoryKeyerRefusesAndSendsNothing');
   r := TTCIProbe.Create;
   try
      r.Clear;
      Check(r.MemoryKeyer(1), 'MemoryKeyer reports unsupported (True = error)');
      CheckEquals('', r.sent, 'and puts nothing on the wire');
   finally
      r.Free;
   end;
end;

// Pinned deliberately: these four REFUSE by design, because TCI is an absolute
// protocol and a step size would have to be invented -- moving a TCI radio by a
// different amount than the radio beside it on the same key. If someone later
// implements them against a configured step, this test should be updated WITH
// that change, not deleted by it.
procedure TRadioTCITests.Test_RelativeTuneSendsNothing;
var
   r: TTCIProbe;
begin
   BeginTest('Test_RelativeTuneSendsNothing');
   r := TTCIProbe.Create;
   try
      r.Clear;
      r.RITBumpUp;
      r.RITBumpDown;
      r.VFOBumpUp(nrVFOA);
      r.VFOBumpDown(nrVFOA);

      CheckEquals('', r.sent,
                  'no relative-tune command exists in TCI, so nothing is sent');
   finally
      r.Free;
   end;
end;

{ --------------------------------------------------------------- CW over TCI }

(* ALL THREE OF THESE WERE BROKEN AT ONCE, AND ALL THREE FAILED IN SILENCE.
  Bench session of 2026-09-17, TR4W driving QK4 driving a real K4: the missing
  receiver index produced no KY command, no log line and no reply, and nothing
  anywhere said so. These pin the wire, because the wire is the only place the
  defect was visible. *)

procedure TRadioTCITests.Test_CWSendsTheReceiverIndex;
var
   r: TTCIProbe;
begin
   BeginTest('Test_CWSendsTheReceiverIndex');
   r := TTCIProbe.Create;
   try
      r.Clear;
      r.BufferCW('TEST');
      r.SendCW;
      (* The index is part of the grammar -- cw_macros:<trx>,<text>; -- and 0
        because TR4W drives receiver 0 only. A second receiver is a second
        TR4W radio slot, not a second index here. *)
      CheckEquals('cw_macros:0,TEST;', r.sent,
                  'the receiver index is required; without it a conforming ' +
                  'server keys nothing and reports nothing');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_CWProsignsUseTheTCISpellings;
var
   r:  TTCIProbe;
   ps: TCWProsign;
begin
   BeginTest('Test_CWProsignsUseTheTCISpellings');
   r := TTCIProbe.Create;
   try
      (* handled is asserted as well as text: a declared-but-empty spelling and
        an undeclared grammar are DIFFERENT answers, and the whole defect this
        fixes was the undeclared case falling through to literal text. *)
      ps := r.CWProsign('+');
      CheckTrue(ps.handled, 'AR is handled over TCI');
      CheckEquals('|AR|', ps.text, 'AR is |AR|, which the K4 keys as +');

      ps := r.CWProsign('<');
      CheckTrue(ps.handled, 'SK is handled over TCI');
      CheckEquals('|SK|', ps.text, 'SK is |SK|; the server maps it to * AFTER '
                                 + 'unescaping, so a client never sees that');

      ps := r.CWProsign('=');
      CheckTrue(ps.handled, 'BT is handled over TCI');
      CheckEquals('|BT|', ps.text, 'BT is |BT|, which the K4 keys as =');

      (* NOT '^'. TCI escapes ':' as '^' and decodes it unconditionally before
        any prosign handling, so a half space sent as '^' keys a colon. *)
      ps := r.CWProsign('^');
      CheckTrue(ps.handled, 'the half space is handled over TCI');
      CheckEquals(' ', ps.text, 'the half space is a PLAIN SPACE -- ^ would '
                              + 'be decoded to a literal colon');

      (* Consumed, as on Elecraft: |SN| is not in the K4 table and QK4 keys an
        unknown prosign as bare letters, so emitting it would key S-N. *)
      ps := r.CWProsign('!');
      CheckTrue(ps.handled, 'SN is CONSUMED, not passed through as a literal');
      CheckEquals('', ps.text, 'SN has no TCI spelling, so it keys nothing');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_CWEscapesReservedCharacters;
var
   r: TTCIProbe;
begin
   BeginTest('Test_CWEscapesReservedCharacters');
   r := TTCIProbe.Create;
   try
      (* A comma ENDS THE ARGUMENT unescaped, so a function key holding
        "TNX, 73" was truncated at the comma. Verified on the wire: the
        escaped form round-trips and the K4 keys "TNX, 73". *)
      r.Clear;
      r.BufferCW('TNX, 73');
      r.SendCW;
      CheckEquals('cw_macros:0,TNX~ 73;', r.sent,
                  'a comma is escaped as ~ or it terminates the argument');

      r.Clear;
      r.BufferCW('A:B');
      r.SendCW;
      CheckEquals('cw_macros:0,A^B;', r.sent, 'a colon is escaped as ^');

      r.Clear;
      r.BufferCW('A;B');
      r.SendCW;
      CheckEquals('cw_macros:0,A*B;', r.sent, 'a semicolon is escaped as *');

      (* THE SPEED MARKERS PASS THROUGH UNTOUCHED, and that is deliberate.
        '<' and '>' are the server's speed markers -- bench-verified on a K4,
        cw_macros:0,A<B; keys KYWA; KS015; KYWB; KS020; -- but neither can
        reach this transport carrying operator intent: '>' is RITClear and
        SendCrypticMessage deletes it upstream, and '<' is the SK token that
        CWProsign turns into |SK|. Escaping or dropping them here would be a
        second copy of a rule that already lives a layer up. *)
      r.Clear;
      r.BufferCW('A<B');
      r.SendCW;
      CheckEquals('cw_macros:0,A<B;', r.sent,
                  'the transport does not second-guess the layer above it');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.RunAllTests;
begin
   Test_NoneOfTheNineFault;
   Test_ToggleModeCyclesAndSends;
   Test_ToggleModeWrapsAtTheEnd;
   Test_SetBandTunesToTheBandFrequency;
   Test_ToggleBandCyclesAndWraps;
   Test_SetFilterSendsSymmetricEdges;
   Test_MemoryKeyerRefusesAndSendsNothing;
   Test_RelativeTuneSendsNothing;
   Test_CWSendsTheReceiverIndex;
   Test_CWProsignsUseTheTCISpellings;
   Test_CWEscapesReservedCharacters;
end;

end.
