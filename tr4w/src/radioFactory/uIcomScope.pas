unit uIcomScope;
{$I ..\tr4w.inc}

{
  Decoding Icom's CI-V bandscope ($27 $00) into vendor-neutral TSpectrumFrame
  records.

  This unit is PURE: bytes in, frames out.  No socket, no thread, no UI, no
  radio object, no globals -- the same contract uK4Spectrum keeps, and for the
  same reason: it makes the wire format testable with no radio on the bench.

  ---------------------------------------------------------------------------
  WHERE THIS DIFFERS FROM THE K4, AND WHY IT MATTERS
  ---------------------------------------------------------------------------
  The K4 opens a SECOND TCP SOCKET and streams absolute dB with its own noise
  floor in every packet.  Icom does neither.  Three consequences shape this
  unit:

  1. THE DATA RIDES THE ORDINARY CI-V LINK.  There is no side channel; $27 $00
     frames arrive interleaved with frequency and mode traffic on the same
     connection.  So there is no reading thread here -- TIcomRadio feeds this
     decoder from the CI-V frames it already receives (uRadioIcomBase has had
     a $27 arm since long before this work; it discarded them).

  2. THE LEVELS ARE UNCALIBRATED DISPLAY UNITS, NOT dB.  0..160 on most models,
     0..200 on the IC-7610 and IC-785x.  Icom publishes no mapping to absolute
     power, so anything presenting these as dBm is inventing a measurement.
     See the dB section below for what this unit does instead.

  3. THE SWEEP IS SPLIT OVER THE SERIAL LINK.  Over LAN the whole sweep arrives
     in one frame; over USB/serial the radio divides it, and the divisions have
     to be reassembled.  Both paths are implemented here because they share
     every line but one offset -- a decoder that only works over one transport
     is what makes adding the other expensive later.

  ---------------------------------------------------------------------------
  THE FRAME -- WHICH LAYER THIS IS, AND WHICH SOURCES THEREFORE APPLY
  ---------------------------------------------------------------------------
  A NETWORKED ICOM IS TWO PROTOCOLS STACKED, and this unit is the second one
  only:

    RS-BA1 UDP transport   the session handshake, login, token renewal,
                           retransmit and ports 50001/50002/50003.  That is
                           uIcomNetworkTransport, it is OUR OWN, and nothing
                           in this unit touches it.
    CI-V command plane     FE FE <to> <from> <cmd> ... FD.  THIS unit.

  The $27 $00 payload is BYTE-IDENTICAL on both transports -- the RS-BA1 stream
  is a pipe that carries CI-V, not a different protocol -- which is the only
  reason a serial-only reference can say anything useful here.

  HAMLIB IS CITED BELOW FOR THE PAYLOAD AND FOR NOTHING ELSE.  Its Icom
  backends are RIG_PORT_SERIAL; it has no RS-BA1 code and does not know ports
  50001/50002/50003 exist (checked, not assumed).  It reaches an Icom down a
  cable.  Where it is quoted here it is quoting the RADIO'S SCOPE -- the frame
  layout and the per-model geometry -- which is a fact about the rig and not
  about how the bytes arrived.  It has NO bearing on TR4W's network transport
  and must never be used as evidence about it.
  (NY4I, 2026-08-26, on an earlier draft that did not draw this line: "This has
  nothing to do with hamlib.  It is our direct connection to the UDP side.")

  Offsets below are into the CI-V DATA PAYLOAD AFTER the command and
  sub-command bytes -- what follows `$27 $00` and precedes the terminating $FD.

     [0]        scope id            -- SEE BELOW.  Not a fixed zero.
     [1]        division index      -- BCD, 01..max
     [2]        division maximum    -- BCD; 01 over LAN, 11 or 15 over USB
   when the division index is 1 (the header division) and only then:
     [3]        scope mode          -- 00 centre, 01 fixed, 02 scrollC, 03 scrollF
     [4..8]     frequency A         -- centre (centre mode) or LOWER edge
     [9..13]    frequency B         -- span   (centre mode) or UPPER edge
     [14]       out-of-range flag
     [15..]     waveform, when this frame is also the LAST division (the LAN case)
   for every division after the first:
     [3..]      waveform

  The 15-byte header is not a magic number: 3 + 1 + 5*2 + 1 = 15, and the
  IC-7300MK2's CI-V Reference Guide independently states the LAN data length as
  490 bytes, which is 15 + 475.  Two derivations agreeing is the reason to
  trust it.

  THE SCOPE ID IS REAL, AND THIS IS THE ONE PLACE THE REFERENCES DISAGREE.
  HamLib reads byte [0] as a scope/VFO selector -- "0 = Main, 1 = Sub"
  (rigs/icom/icom.c, icom_parse_spectrum_frame) -- and indexes a per-scope
  cache with it.  AetherSDR's decoder calls the same byte "0x00, fixed" and
  ignores it entirely (src/core/backends/icom/IcomScope.cpp).  On a
  single-scope radio the two are indistinguishable.  On a DUAL-scope radio --
  the IC-9700, IC-7610 and IC-7760 all have one -- ignoring it splices Main and
  Sub sweeps into a single trace, and the failure looks like corrupt spectrum
  rather than a decode bug.  HamLib is followed here, and the id is carried
  outward as TSpectrumFrame.SourceId, which is exactly what that field is for:
  the K4 puts 'A'/'B'/'Y' in it and streams all of them down one socket too.

  UNVERIFIED, AND FLAGGED AS SUCH: WHICH id is Main.  HamLib says 0.  Nothing
  here depends on that being right, because SourceId is opaque to the window
  and the bench harness reports which ids a rig actually emits.

  ---------------------------------------------------------------------------
  BCD, AND THE TWO TRAPS IN IT
  ---------------------------------------------------------------------------
  THE DIVISION COUNTERS ARE BCD, NOT BINARY.  Division 11 arrives as $11, not
  $0B.  Reading them as plain bytes works for 1..9 and then breaks -- and over
  LAN the maximum is 1, so the bug would never fire on the transport most
  operators use and would ship.  HamLib decodes them with from_bcd and
  AetherSDR calls this out by name; both are followed.

  A SCOPE EDGE CAN BE NEGATIVE.  The IC-7300MK2's guide documents $F in the
  1 GHz digit -- the high nibble of the last frequency byte -- as a sign flag,
  set when a wide span sits near the bottom of the tuning range so the display
  extends below 0 Hz.  uIcomCIV.IcomBCDToFreq deliberately REFUSES that byte
  and returns FREQ_INVALID, which is correct for its job: an operating
  frequency is never negative, and a fabricated one still retunes the radio --
  on transmit, out of band.  So this unit carries its own signed variant rather
  than loosening the strict one every tuning path depends on.  (HamLib uses
  plain unsigned from_bcd here and would mis-decode that case; AetherSDR
  handles it.  AetherSDR is followed.)

  ---------------------------------------------------------------------------
  dB: WHAT IS MEASURED AND WHAT IS ESTIMATED
  ---------------------------------------------------------------------------
  The panadapter window scales everything relative to TSpectrumFrame's
  NoiseFloorDb (see uSpectrumTypes), because the K4's stream carries a floor
  the radio computes for it.  Icom carries no such field, so this unit must
  produce one, and the two halves of that have very different standing:

  THE VERTICAL STRETCH IS AN ESTIMATE.  Levels are converted at a fixed
  dB-per-unit.  0.5 is not invented: HamLib publishes a signal-strength range
  per model and every published one reduces to exactly that --

      IC-7300 family   475 points   0..160    -80..0 dBm   -> 0.5 dB/unit
      IC-7610          689 points   0..200   -100..0 dBm   -> 0.5 dB/unit
      IC-785x          689 points   0..200   -100..0 dBm   -> 0.5 dB/unit

  (The IC-R8600 is the lone exception at 0.625, and HamLib itself marks that
  row "TODO: signal strength to be confirmed".)  It is still an ESTIMATE: no
  bench measurement against a known source backs it, which is why it is a
  FIELD of TIcomScopeGeometry and not a constant.

  AND IT IS THE ONE HAMLIB NUMBER HERE THAT NOTHING LOCAL CORROBORATES.  The
  689-point class was confirmed by measuring an IC-7760, the scope selector by
  an IC-9700's own $27 $15 reply, the half-width by a centre/span cross-check
  against the rig -- all on 2026-08-26.  This one has not been, and it comes
  from a project that only ever reads these radios over a serial cable.  Treat
  it as the weakest claim in this unit.

  THE FLOOR IS MEASURED, FROM THE SWEEP ITSELF.  NoiseFloorDb is a low
  percentile of the frame's own levels rather than a fixed reference.  That is
  the same job the K4's AutoRef does on the radio's side, done here instead,
  and it needs no CAT query -- so a band change, an attenuator, or a different
  model simply moves the floor and the display follows.

  THE TWO INTERACT WELL, WHICH IS THE POINT.  Because the reference is measured
  and only the stretch is estimated, an error in dB-per-unit shows up as a
  display that is too flat or too contrasty.  It can never park the trace
  off-scale -- which is precisely the failure a fixed dB window produced on the
  K4 (docs/PANADAPTER_LCL_DESIGN.md section 2.3: every pan-A sample fell below
  TR4QT's hard-coded floor and the waterfall was solid black).

  THE AXIS IS THEREFORE RELATIVE, AND MUST NOT BE LABELLED dBm.
}

interface

uses
   SysUtils, uSpectrumTypes;

const
   // CI-V command and sub-command this unit decodes.  Named so a caller cannot
   // spell them itself and drift.
   ICOM_SCOPE_CMD          = $27;
   ICOM_SCOPE_SUB_WAVEDATA = $00;

   { The three sub-commands the driver actually sends.

     BOTH OF THE FIRST TWO MUST BE ON.  Enabling only $10 turns the scope on
     the RADIO'S OWN SCREEN and sends nothing down CI-V -- AetherSDR names this
     as the number-one "my panadapter is black" cause, and it is a failure with
     no error anywhere: the rig looks right, the link is up, and no frames
     arrive.

     AND THEY TAKE NO SCOPE SELECTOR, WHILE $15 DOES.  That asymmetry is real
     and is the other silent-failure trap here: HamLib puts the selector byte
     first on every scope sub-command it implements ($14 mode, $15 span, $19
     reference) on READ as well as SET, while $10 and $11 are whole-function
     switches that take only 00 or 01.  AetherSDR reports that omitting the
     selector where it IS required makes the rig ignore the frame outright --
     no NG, no error, the setting simply does not change. }
   ICOM_SCOPE_SUB_ONOFF      = $10;   // scope function on/off      -- NO selector
   ICOM_SCOPE_SUB_DATAOUTPUT = $11;   // CI-V wave output on/off    -- NO selector
   ICOM_SCOPE_SUB_SPAN       = $15;   // span, centre mode only     -- SELECTOR + 5-byte BCD

   // Payload offsets, after the command and sub-command bytes.
   ICOM_SCOPE_OFF_SCOPEID      = 0;
   ICOM_SCOPE_OFF_DIVISION     = 1;
   ICOM_SCOPE_OFF_DIVISION_MAX = 2;
   ICOM_SCOPE_OFF_MODE         = 3;
   ICOM_SCOPE_OFF_FREQ_A       = 4;
   // Where a CONTINUATION division's waveform starts: straight after the three
   // bytes every division carries.
   ICOM_SCOPE_OFF_CONTINUATION = 3;

   // Frequency width in bytes.  Five on every current model; the IC-905 uses
   // six above 10 GHz, which is why TIcomScopeGeometry carries it as a field.
   // A decoder written against a hard-coded 5 misaligns by two bytes there and
   // produces a plausible-looking wrong frequency.
   ICOM_SCOPE_FREQ_BYTES = 5;

   // The published geometries.  Seeds for TIcomScopeGeometry, NOT a model
   // table: which numbers a given radio uses is that radio's own declaration
   // (see TRadioCapabilities), never a case statement in a shared unit.
   ICOM_SCOPE_POINTS_475 = 475;   // IC-705, IC-7300 family, IC-9700, IC-905
   ICOM_SCOPE_POINTS_689 = 689;   // IC-7610, IC-785x
   ICOM_SCOPE_LEVEL_160  = 160;
   ICOM_SCOPE_LEVEL_200  = 200;

   // See the dB section in the unit header.  An ESTIMATE, and deliberately one
   // number rather than a per-model floor/span pair: HamLib's published ranges
   // all reduce to this, and expressing it PER UNIT is what lets the 160-level
   // and 200-level radios share one rule instead of needing two tables.
   ICOM_SCOPE_DB_PER_UNIT = 0.5;

   // Level 0 maps here.  Only the SPACING of the axis affects the picture,
   // because the reference is measured from the sweep -- so this constant sets
   // where the numbers sit, not how the display looks.  Chosen to put a
   // 160-level radio's full range at -80..0, which is what HamLib publishes for
   // the IC-7300.
   ICOM_SCOPE_ZERO_DB = -80.0;

   // Which percentile of a sweep is taken as its noise floor.  Low enough to
   // sit in the noise rather than on the signals, high enough that a handful of
   // dead bins at the edge of a sweep cannot drag it to the bottom of the
   // scale.
   ICOM_SCOPE_FLOOR_PERCENTILE = 10;

   { THE EIGHT SPANS AN ICOM SCOPE OFFERS, as TOTAL widths in Hz.

     STATED AS TOTALS, NOT AS THE RIG'S OWN NUMBERS, and that is the whole
     reason this table exists rather than a copy of Icom's.  The front panel
     reads "+/-100k" and CI-V carries that same HALF-width, while
     TSpectrumFrame.SpanHz and TFactoryRadioBase.SpectrumSpanHz are both total
     widths.  Mixing the two gives a display right about its centre and wrong
     by 2x about its extent -- signals at half or double their true offset,
     which an operator reads as a tuning fault.  Converting once, here, means
     no other line in TR4W has to remember which convention it is holding.

     A LADDER, NOT A RANGE, and that is why StepSpectrumSpan exists.  The rig
     SNAPS a request to the nearest rung, and the rungs are spaced by ratios of
     2 and 2.5 -- so a fine trim of a kHz never crosses a midpoint and the rig
     hands back the span it already had.  AetherSDR measured that as zoom-out
     inert at all eight spans.

     ONE LADDER FOR THE FAMILY.  If a capture ever shows a model with different
     rungs, that model overrides StepSpectrumSpan -- it does not edit this
     table, which would move every other radio's rungs with it. }
   ICOM_SCOPE_SPAN_COUNT = 8;

   // How many scopes one radio may stream at once.  Two today (Main and Sub);
   // the cap exists so a corrupt id cannot index off the end of the assembly
   // array, not because a third is expected.
   ICOM_SCOPE_MAX_SCOPES = 4;

type
   { The radio's own scope mode, from payload byte [3].

     GEOMETRICALLY THERE ARE ONLY TWO CASES, not four: centre mode reports
     centre and span, and the other three all report the edges directly.  The
     scroll modes are kept as distinct values anyway because they are distinct
     radio states an operator can see on the rig, and collapsing them here
     would mean a log line could not say which one is running. }
   TIcomScopeMode = (ismCentre, ismFixed, ismScrollCentre, ismScrollFixed);

   { What one radio's scope looks like.  DECLARED BY THE RADIO -- see the unit
     header.  Every field is a per-model hardware fact and none may be inferred
     from another: the IC-7610 differs from the IC-7300 in BOTH point count and
     level range, which is exactly why this is a record and not a pair of
     constants. }
   TIcomScopeGeometry = record
      Points: Integer;        // bins in a complete sweep (475 / 689)
      MaxLevel: Integer;      // top of the level range (160 / 200)
      DbPerUnit: Single;      // an ESTIMATE -- see the unit header
      FreqBytes: Integer;     // 5, or 6 on an IC-905 above 10 GHz
   end;

   TIcomScopeStatus = (
      issComplete,        // a whole sweep came out; ASweep is valid
      issAssembling,      // this division was consumed, the sweep is not done
      issTooShort,        // fewer bytes than even the common three-byte prefix
      issBadDivision,     // division counters nonsense, or arrived out of order
      issBadField,        // a BCD frequency would not parse
      issBadScopeId,      // an id at or past ICOM_SCOPE_MAX_SCOPES
      issBadGeometry);    // the geometry in force is not usable

   { One assembled sweep, still in the radio's own units.

     KEPT SEPARATE FROM TSpectrumFrame on purpose.  The conversion to dB
     involves an estimate (see the unit header) and a measured percentile; both
     are worth being able to test -- and to LOOK AT on the bench -- without the
     other.  It is the same split AetherSDR draws between ScopeFrame and
     toDbm(). }
   TIcomScopeSweep = record
      ScopeId: Byte;          // payload byte [0] -- Main/Sub; see the unit header
      Mode: TIcomScopeMode;
      // Edges in Hz, already normalised out of whichever representation the
      // radio used.  SIGNED, and StartHz genuinely can be negative -- see the
      // BCD section of the unit header.
      StartHz: Int64;
      EndHz: Int64;
      // The radio is saying the scope cannot show this range.  It then OMITS
      // the waveform entirely, so the frame is short.  A sweep is still
      // produced (floor-filled) rather than dropped: a waterfall that stops
      // scrolling reads as a hung program, while one that goes flat reads as
      // "nothing here", which is what the radio is actually saying.
      OutOfRange: Boolean;
      Levels: TBytes;         // Geometry.Points entries, 0..Geometry.MaxLevel
      Sequence: Integer;      // synthesised per scope; wraps at 256
   end;

// A geometry with the estimated dB-per-unit and the usual five-byte
// frequencies filled in, so a caller states only the two facts that actually
// differ between models.
function IcomScopeGeometry(APoints, AMaxLevel: Integer): TIcomScopeGeometry;

// True when a geometry can drive a decode at all.  Separated out so the
// decoder and the radio's own declaration are checked by the same rule.
function IcomScopeGeometryIsValid(const AGeom: TIcomScopeGeometry): Boolean;

{ A scope EDGE frequency: N BCD bytes, least-significant pair first, with $F in
  the 1 GHz digit meaning negative.

  NOT a replacement for uIcomCIV.IcomBCDToFreq, and must not become one.  That
  function is strict because an operating frequency is never negative.  Only a
  scope edge may be, so only this decoder relaxes the rule -- and it relaxes it
  for exactly one nibble in exactly one position. }
function IcomScopeDecodeEdgeHz(const AData: TBytes; AOffset, ACount: Integer;
                               out AHz: Int64): Boolean;

// One BCD byte, 00..99, or -1 when either nibble is not a decimal digit.
// Returns a refusal rather than a value because a division counter read out of
// a corrupt byte is how one sweep gets assembled out of two.
function IcomScopeDecodeBcdByte(AByte: Byte): Integer;

{ Convert an assembled sweep into the neutral frame the panadapter draws.

  Pure, and separated from the decoder so the estimate and the measured floor
  can each be pinned on their own.  ASourceId is what the window filters on;
  the caller supplies it so this unit never has to decide how a scope id is
  spelled. }
function IcomSweepToSpectrumFrame(const ASweep: TIcomScopeSweep;
                                  const AGeom: TIcomScopeGeometry;
                                  const ASourceId: string): TSpectrumFrame;

{ The span ladder, as TOTAL widths -- see ICOM_SCOPE_SPAN_COUNT.

  IcomScopeSpanHz(i) is rung i; IcomScopeNearestSpanHz snaps an arbitrary width
  to a rung; IcomScopeAdjacentSpanHz walks ONE rung in a direction and CLAMPS
  at the ends rather than wrapping (a widest-span press must not silently jump
  to the narrowest). }
function IcomScopeSpanHz(AIndex: Integer): Integer;
function IcomScopeNearestSpanHz(ATotalHz: Integer): Integer;
function IcomScopeAdjacentSpanHz(ATotalHz, ADirection: Integer): Integer;

// The rig carries a HALF-width; TR4W carries totals.  Named rather than
// spelled `div 2` at the call site so the factor of two is visible where it
// happens -- both references warn that this is the error people actually make.
function IcomScopeTotalToHalfHz(ATotalHz: Integer): Integer;
function IcomScopeHalfToTotalHz(AHalfHz: Integer): Integer;

// How a scope id is spelled as a TSpectrumFrame.SourceId.  ONE function, so a
// producer and a consumer cannot spell it differently -- the window filters on
// string equality and nothing validates the spelling.
function IcomScopeSourceId(AScopeId: Byte): string;

// The percentile of a sweep's levels.  Exposed for the pin tests and the bench
// harness: "what floor did this sweep report" is the number that decides
// whether the display is usable, so it must be checkable on its own.
function IcomScopeLevelPercentile(const ALevels: TBytes; ACount, APercentile: Integer): Integer;

type
   { CI-V payloads in, complete sweeps out.

     ONE DECODER PER RADIO, not per scope.  A dual-scope rig interleaves Main
     and Sub down the same link, so assembly state is held per scope id and the
     caller does not have to demultiplex before it gets here.

     Fed rather than pulled (the opposite of TK4SpectrumFramer) because the
     framing has already been done: TIcomRadio hands over one complete CI-V
     frame's payload at a time, so there is no byte stream to resynchronise and
     no partial-frame state to keep. }
   TIcomScopeDecoder = class(TObject)
   private
      FGeometry: TIcomScopeGeometry;
      FPartial: array[0 .. ICOM_SCOPE_MAX_SCOPES - 1] of TIcomScopeSweep;
      FFilled: array[0 .. ICOM_SCOPE_MAX_SCOPES - 1] of Integer;      // level bytes written
      FAssembling: array[0 .. ICOM_SCOPE_MAX_SCOPES - 1] of Boolean;
      FExpectedDivision: array[0 .. ICOM_SCOPE_MAX_SCOPES - 1] of Integer;
      FSequence: array[0 .. ICOM_SCOPE_MAX_SCOPES - 1] of Integer;
      FPendingLevelBytes: array[0 .. ICOM_SCOPE_MAX_SCOPES - 1] of Integer;

      FSweepsOut: Int64;
      FRejected: Int64;
      FAbandoned: Int64;
      FLastSweepLevelBytes: Integer;
      FMaxLevelSeen: Integer;

      procedure SetGeometry(const AValue: TIcomScopeGeometry);
      function BeginSweep(AScopeId: Integer; const AData: TBytes;
                          ACount: Integer): TIcomScopeStatus;
      procedure AppendLevels(AScopeId: Integer; const AData: TBytes;
                             AFrom, ACount: Integer);
      function FinishSweep(AScopeId: Integer; out ASweep: TIcomScopeSweep): TIcomScopeStatus;
   public
      constructor Create(const AGeom: TIcomScopeGeometry);

      { Feed one $27 $00 payload -- the bytes AFTER the command and
        sub-command and before the terminating $FD.  ACount says how many of
        AData are live, so a caller may reuse one buffer. }
      function Feed(const AData: TBytes; ACount: Integer;
                    out ASweep: TIcomScopeSweep): TIcomScopeStatus;

      procedure Reset;

      property Geometry: TIcomScopeGeometry read FGeometry write SetGeometry;

      // Diagnostics, as counters rather than log lines: at 30 sweeps a second
      // a per-event log during a bad patch would be the loudest thing in
      // tr4w.log and would say less than one number.
      property SweepsOut: Int64 read FSweepsOut;
      property Rejected: Int64 read FRejected;      // payloads refused outright
      property Abandoned: Int64 read FAbandoned;    // sweeps dropped on a division gap

      { MEASUREMENT, not diagnostics -- these exist so a rig can be asked what
        its geometry actually is.

        LastSweepLevelBytes is how many level bytes the last completed sweep
        CARRIED, before any truncation to Geometry.Points.  It is the only way
        to discover a point count: the sweep handed out is always Points long,
        because short ones are floor-padded and long ones truncated, so the
        delivered array cannot answer the question.

        THAT IS NOT A HYPOTHETICAL NEED.  The IC-7760's geometry is published
        nowhere -- not by HamLib, not by AetherSDR -- so its declaration is a
        provisional guess, and this counter is how it gets replaced by a
        measurement.  tr4w/test/bench/bench_icomscope.lpr reports it.

        MaxLevelSeen is the highest level byte in any sweep so far.  WEAKER
        EVIDENCE, and honestly so: it is a lower bound on the range, reached
        only if something in the passband was strong enough during the capture.
        It distinguishes a 0..160 radio from a 0..200 one only when a signal
        actually exceeded 160. }
      property LastSweepLevelBytes: Integer read FLastSweepLevelBytes;
      property MaxLevelSeen: Integer read FMaxLevelSeen;
   end;

implementation

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

function IcomScopeGeometry(APoints, AMaxLevel: Integer): TIcomScopeGeometry;
begin
   Result.Points := APoints;
   Result.MaxLevel := AMaxLevel;
   Result.DbPerUnit := ICOM_SCOPE_DB_PER_UNIT;
   Result.FreqBytes := ICOM_SCOPE_FREQ_BYTES;
end;

function IcomScopeGeometryIsValid(const AGeom: TIcomScopeGeometry): Boolean;
begin
   Result := (AGeom.Points > 0) and
             (AGeom.MaxLevel > 0) and
             (AGeom.DbPerUnit > 0) and
             (AGeom.FreqBytes > 0);
end;

// ---------------------------------------------------------------------------
// The span ladder
// ---------------------------------------------------------------------------

const
   // TOTAL widths.  Icom's own list is the half-widths +/-2.5k .. +/-500k; each
   // entry here is twice one of those.  See ICOM_SCOPE_SPAN_COUNT.
   SPAN_LADDER: array[0 .. ICOM_SCOPE_SPAN_COUNT - 1] of Integer =
      (5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000);

function IcomScopeSpanHz(AIndex: Integer): Integer;
begin
   if AIndex < 0 then
      begin
      AIndex := 0;
      end;

   if AIndex > (ICOM_SCOPE_SPAN_COUNT - 1) then
      begin
      AIndex := ICOM_SCOPE_SPAN_COUNT - 1;
      end;

   Result := SPAN_LADDER[AIndex];
end;

function IcomScopeTotalToHalfHz(ATotalHz: Integer): Integer;
begin
   Result := ATotalHz div 2;
end;

function IcomScopeHalfToTotalHz(AHalfHz: Integer): Integer;
begin
   Result := AHalfHz * 2;
end;

function IcomScopeNearestSpanHz(ATotalHz: Integer): Integer;
var
   i: Integer;
   err: Int64;
   bestErr: Int64;
begin
   Result := SPAN_LADDER[0];
   bestErr := Abs(Int64(ATotalHz) - Result);

   for i := 1 to ICOM_SCOPE_SPAN_COUNT - 1 do
      begin
      err := Abs(Int64(ATotalHz) - SPAN_LADDER[i]);

      if err < bestErr then
         begin
         bestErr := err;
         Result := SPAN_LADDER[i];
         end;
      end;
end;

function IcomScopeAdjacentSpanHz(ATotalHz, ADirection: Integer): Integer;
var
   i: Integer;
   current: Integer;
begin
   // ANCHOR ON A RUNG FIRST.  The caller's "current" comes from the radio, and
   // a value a few Hz off a rung must not fall through the search and land back
   // at the bottom of the ladder.
   current := IcomScopeNearestSpanHz(ATotalHz);
   Result := current;

   if ADirection = 0 then
      begin
      Exit;
      end;

   for i := 0 to ICOM_SCOPE_SPAN_COUNT - 1 do
      begin
      if SPAN_LADDER[i] <> current then
         begin
         Continue;
         end;

      if ADirection < 0 then
         begin
         // CLAMP, do not wrap.  A press at the narrowest span that jumped to
         // the widest would be worse than one that did nothing.
         if i > 0 then
            begin
            Result := SPAN_LADDER[i - 1];
            end;

         Exit;
         end;

      if i < (ICOM_SCOPE_SPAN_COUNT - 1) then
         begin
         Result := SPAN_LADDER[i + 1];
         end;

      Exit;
      end;
end;

// ---------------------------------------------------------------------------
// BCD
// ---------------------------------------------------------------------------

function IcomScopeDecodeBcdByte(AByte: Byte): Integer;
var
   hi, lo: Byte;
begin
   hi := (AByte shr 4) and $0F;
   lo := AByte and $0F;

   if (hi > 9) or (lo > 9) then
      begin
      Result := -1;
      Exit;
      end;

   Result := (hi * 10) + lo;
end;

function IcomScopeDecodeEdgeHz(const AData: TBytes; AOffset, ACount: Integer;
                               out AHz: Int64): Boolean;
var
   i: Integer;
   b: Byte;
   hi, lo: Byte;
   scale: Int64;
   value: Int64;
   negative: Boolean;
begin
   AHz := 0;
   Result := False;

   if (ACount <= 0) or (AOffset < 0) or (AOffset + ACount > Length(AData)) then
      begin
      Exit;
      end;

   negative := False;
   value := 0;
   scale := 1;

   for i := 0 to ACount - 1 do
      begin
      b := AData[AOffset + i];
      hi := (b shr 4) and $0F;
      lo := b and $0F;

      // THE SIGN LIVES IN EXACTLY ONE NIBBLE: the high nibble of the LAST byte,
      // which is the 1 GHz digit (the bytes run least-significant pair first).
      // Anywhere else a nibble of $F is corruption and the decode is refused --
      // relaxing it generally would hand back the fabricated-frequency
      // behaviour uIcomCIV exists to prevent.
      if (i = (ACount - 1)) and (hi = $0F) then
         begin
         negative := True;
         hi := 0;
         end;

      if (hi > 9) or (lo > 9) then
         begin
         Exit;
         end;

      value := value + (Int64(lo) * scale);
      scale := scale * 10;
      value := value + (Int64(hi) * scale);
      scale := scale * 10;
      end;

   if negative then
      begin
      value := -value;
      end;

   AHz := value;
   Result := True;
end;

// ---------------------------------------------------------------------------
// Sweep -> TSpectrumFrame
// ---------------------------------------------------------------------------

function IcomScopeSourceId(AScopeId: Byte): string;
begin
   // Decimal, and opaque.  NOT 'Main'/'Sub': which id is which is HamLib's
   // claim and has not been confirmed on a rig here, so spelling it out would
   // put an unverified assertion in front of the operator.  The bench harness
   // reports the raw ids a radio actually emits.
   Result := IntToStr(AScopeId);
end;

function IcomScopeLevelPercentile(const ALevels: TBytes; ACount, APercentile: Integer): Integer;
var
   hist: array[0 .. 255] of Integer;
   i: Integer;
   target: Integer;
   running: Integer;
begin
   Result := 0;

   if (ACount <= 0) or (ACount > Length(ALevels)) then
      begin
      Exit;
      end;

   for i := 0 to 255 do
      begin
      hist[i] := 0;
      end;

   // A 256-bin histogram rather than a sort.  O(n) with no allocation, which
   // matters at 30 sweeps a second on the shared CI-V path -- and it is EXACT,
   // not an approximation: a level IS a byte, so the histogram is the
   // distribution rather than a sampling of it.
   for i := 0 to ACount - 1 do
      begin
      Inc(hist[ALevels[i]]);
      end;

   // Rounded UP, so a percentile of a small sweep still names a real sample
   // instead of falling through to index zero.
   target := ((ACount * APercentile) + 99) div 100;

   if target < 1 then
      begin
      target := 1;
      end;

   running := 0;

   for i := 0 to 255 do
      begin
      Inc(running, hist[i]);

      if running >= target then
         begin
         Result := i;
         Exit;
         end;
      end;

   Result := 255;
end;

function IcomSweepToSpectrumFrame(const ASweep: TIcomScopeSweep;
                                  const AGeom: TIcomScopeGeometry;
                                  const ASourceId: string): TSpectrumFrame;
var
   i: Integer;
   count: Integer;
   level: Integer;
   floorLevel: Integer;
begin
   Result := Default(TSpectrumFrame);

   Result.SourceId := ASourceId;
   Result.Sequence := ASweep.Sequence;

   // The neutral frame is centre-and-span; the sweep is edges.  ONE conversion,
   // here, so nothing downstream has to know Icom reports edges (or, in centre
   // mode, a HALF-width that was already folded out during decode).
   Result.CentreHz := (ASweep.StartHz + ASweep.EndHz) div 2;

   if ASweep.EndHz > ASweep.StartHz then
      begin
      Result.SpanHz := ASweep.EndHz - ASweep.StartHz;
      end
   else
      begin
      Result.SpanHz := 0;
      end;

   count := Length(ASweep.Levels);
   Result.BinCount := count;

   if count <= 0 then
      begin
      // No bins means no floor to measure.  Report the bottom of the axis
      // rather than a plausible zero: a frame with no data must not look like
      // a frame with a floor of 0 dB.
      Result.NoiseFloorDb := ICOM_SCOPE_ZERO_DB;
      Exit;
      end;

   SetLength(Result.Bins, count);

   for i := 0 to count - 1 do
      begin
      level := ASweep.Levels[i];

      // CLAMP RATHER THAN TRUST.  The published range is 0..MaxLevel but the
      // field is a whole byte, so a value above the range would project above
      // the top of the scale and drag the display's contrast with it.
      if level > AGeom.MaxLevel then
         begin
         level := AGeom.MaxLevel;
         end;

      Result.Bins[i] := ICOM_SCOPE_ZERO_DB + (level * AGeom.DbPerUnit);
      end;

   // MEASURED, not assumed -- see the dB section of the unit header.  Taken
   // from the same clamped axis the bins use, so the floor and the bins cannot
   // drift apart.
   floorLevel := IcomScopeLevelPercentile(ASweep.Levels, count,
                                          ICOM_SCOPE_FLOOR_PERCENTILE);

   if floorLevel > AGeom.MaxLevel then
      begin
      floorLevel := AGeom.MaxLevel;
      end;

   Result.NoiseFloorDb := ICOM_SCOPE_ZERO_DB + (floorLevel * AGeom.DbPerUnit);
end;

// ---------------------------------------------------------------------------
// TIcomScopeDecoder
// ---------------------------------------------------------------------------

constructor TIcomScopeDecoder.Create(const AGeom: TIcomScopeGeometry);
begin
   inherited Create;
   FGeometry := AGeom;
   Reset;
end;

procedure TIcomScopeDecoder.SetGeometry(const AValue: TIcomScopeGeometry);
begin
   FGeometry := AValue;

   // A geometry change invalidates every partly-assembled sweep: the level
   // buffers are sized from Points, so keeping them would splice a sweep of one
   // width onto a sweep of another.
   Reset;
end;

procedure TIcomScopeDecoder.Reset;
var
   i: Integer;
begin
   for i := 0 to ICOM_SCOPE_MAX_SCOPES - 1 do
      begin
      FPartial[i] := Default(TIcomScopeSweep);
      FFilled[i] := 0;
      FAssembling[i] := False;
      FExpectedDivision[i] := 0;
      FSequence[i] := 0;
      FPendingLevelBytes[i] := 0;
      end;

   FSweepsOut := 0;
   FRejected := 0;
   FAbandoned := 0;
   FLastSweepLevelBytes := 0;
   FMaxLevelSeen := 0;
end;

function TIcomScopeDecoder.BeginSweep(AScopeId: Integer; const AData: TBytes;
                                      ACount: Integer): TIcomScopeStatus;
var
   header: Integer;
   modeByte: Byte;
   freqA, freqB: Int64;
begin
   // The header division's fixed part: mode + two frequencies + the
   // out-of-range flag.  Derived from FreqBytes rather than written as 15, so
   // an IC-905 above 10 GHz does not silently misalign by two.
   header := ICOM_SCOPE_OFF_MODE + 1 + (FGeometry.FreqBytes * 2) + 1;

   if ACount < header then
      begin
      Result := issTooShort;
      Exit;
      end;

   modeByte := AData[ICOM_SCOPE_OFF_MODE];

   if modeByte > Ord(High(TIcomScopeMode)) then
      begin
      // An unknown mode is NOT decoded as fixed.  Both AetherSDR and HamLib
      // reach for a default here; the difference matters because the geometry
      // depends entirely on which mode this is -- centre mode's second field is
      // a half-width and every other mode's is an absolute edge.  Guessing
      // wrong yields a sweep that is confidently placed at the wrong frequency,
      // which is worse than one that never appears.
      Result := issBadField;
      Exit;
      end;

   if not IcomScopeDecodeEdgeHz(AData, ICOM_SCOPE_OFF_FREQ_A,
                                FGeometry.FreqBytes, freqA) then
      begin
      Result := issBadField;
      Exit;
      end;

   if not IcomScopeDecodeEdgeHz(AData, ICOM_SCOPE_OFF_FREQ_A + FGeometry.FreqBytes,
                                FGeometry.FreqBytes, freqB) then
      begin
      Result := issBadField;
      Exit;
      end;

   FPartial[AScopeId] := Default(TIcomScopeSweep);
   FPartial[AScopeId].ScopeId := Byte(AScopeId);
   FPartial[AScopeId].Mode := TIcomScopeMode(modeByte);

   if FPartial[AScopeId].Mode = ismCentre then
      begin
      // CENTRE MODE REPORTS CENTRE AND SPAN, AND ICOM'S SPAN IS A HALF-WIDTH.
      // The front panel reads "+/-100k" and the display covers 200 kHz, so the
      // edges are centre -/+ span, NOT centre -/+ span/2.  Getting this
      // backwards gives a sweep that is right about its centre and wrong by 2x
      // about its extent -- signals appear at half or double their true offset,
      // which reads as a tuning bug rather than a geometry bug.  HamLib
      // (spectrum_span_freq = from_bcd(...) * 2) and AetherSDR agree, and both
      // call it out by name.
      FPartial[AScopeId].StartHz := freqA - freqB;
      FPartial[AScopeId].EndHz := freqA + freqB;
      end
   else
      begin
      // Fixed and both scroll modes report the edges directly.  That is why
      // there is no separate branch for the scroll modes: geometrically they
      // ARE fixed mode, and only the label differs.
      FPartial[AScopeId].StartHz := freqA;
      FPartial[AScopeId].EndHz := freqB;
      end;

   FPartial[AScopeId].OutOfRange := AData[header - 1] <> $00;

   SetLength(FPartial[AScopeId].Levels, FGeometry.Points);
   FillChar(FPartial[AScopeId].Levels[0], FGeometry.Points, 0);
   FFilled[AScopeId] := 0;
   FPendingLevelBytes[AScopeId] := 0;
   FAssembling[AScopeId] := True;

   if ACount > header then
      begin
      AppendLevels(AScopeId, AData, header, ACount - header);
      end;

   Result := issAssembling;
end;

procedure TIcomScopeDecoder.AppendLevels(AScopeId: Integer; const AData: TBytes;
                                         AFrom, ACount: Integer);
var
   room: Integer;
   i: Integer;
begin
   if ACount <= 0 then
      begin
      Exit;
      end;

   { COUNTED BEFORE TRUNCATION, and that ordering is the whole value of the
     counter: a 689-point rig declared as 475 delivers 475 either way, so a
     count taken after the clamp could never reveal the mismatch it exists to
     find. }
   Inc(FPendingLevelBytes[AScopeId], ACount);

   for i := AFrom to (AFrom + ACount - 1) do
      begin
      if AData[i] > FMaxLevelSeen then
         begin
         FMaxLevelSeen := AData[i];
         end;
      end;

   room := FGeometry.Points - FFilled[AScopeId];

   if ACount > room then
      begin
      // TRUNCATE RATHER THAN OVERRUN.  A radio sending more points than the
      // declared geometry means the geometry is wrong for this model, which is
      // a configuration fault and not a reason to write past the buffer.  The
      // sweep still completes, so the operator sees a display and the
      // divergence is visible on the bench rather than as an access violation.
      ACount := room;
      end;

   if ACount <= 0 then
      begin
      Exit;
      end;

   Move(AData[AFrom], FPartial[AScopeId].Levels[FFilled[AScopeId]], ACount);
   Inc(FFilled[AScopeId], ACount);
end;

function TIcomScopeDecoder.FinishSweep(AScopeId: Integer;
                                       out ASweep: TIcomScopeSweep): TIcomScopeStatus;
begin
   FAssembling[AScopeId] := False;

   // Sequence is SYNTHESISED: Icom sends none.  Wrapped at 256 to match the
   // contract TSpectrumFrame.Sequence already carries for the K4, whose
   // counter is a byte -- one meaning for the field rather than two.
   FSequence[AScopeId] := (FSequence[AScopeId] + 1) mod 256;
   FPartial[AScopeId].Sequence := FSequence[AScopeId];

   FLastSweepLevelBytes := FPendingLevelBytes[AScopeId];

   ASweep := FPartial[AScopeId];
   Inc(FSweepsOut);
   Result := issComplete;
end;

function TIcomScopeDecoder.Feed(const AData: TBytes; ACount: Integer;
                                out ASweep: TIcomScopeSweep): TIcomScopeStatus;
var
   scopeId: Integer;
   division: Integer;
   divisionMax: Integer;
begin
   ASweep := Default(TIcomScopeSweep);

   if not IcomScopeGeometryIsValid(FGeometry) then
      begin
      Inc(FRejected);
      Result := issBadGeometry;
      Exit;
      end;

   if (ACount <= ICOM_SCOPE_OFF_DIVISION_MAX) or (ACount > Length(AData)) then
      begin
      Inc(FRejected);
      Result := issTooShort;
      Exit;
      end;

   scopeId := AData[ICOM_SCOPE_OFF_SCOPEID];

   if scopeId >= ICOM_SCOPE_MAX_SCOPES then
      begin
      Inc(FRejected);
      Result := issBadScopeId;
      Exit;
      end;

   // BCD, NOT BINARY -- see the unit header.  Division 11 is $11.
   division := IcomScopeDecodeBcdByte(AData[ICOM_SCOPE_OFF_DIVISION]);
   divisionMax := IcomScopeDecodeBcdByte(AData[ICOM_SCOPE_OFF_DIVISION_MAX]);

   if (division < 1) or (divisionMax < 1) or (division > divisionMax) then
      begin
      Inc(FRejected);
      Result := issBadDivision;
      Exit;
      end;

   if division = 1 then
      begin
      // A first division restarts assembly UNCONDITIONALLY.  If a previous
      // sweep was left half-built by a lost packet, this is where it is
      // discarded -- keeping it would splice two sweeps into one trace.
      Result := BeginSweep(scopeId, AData, ACount);

      if Result <> issAssembling then
         begin
         FAssembling[scopeId] := False;
         Inc(FRejected);
         Exit;
         end;

      FExpectedDivision[scopeId] := 1;

      if FPartial[scopeId].OutOfRange then
         begin
         // The radio omits the waveform entirely when out of range, so there is
         // nothing to accumulate and nothing further to wait for.  Emit the
         // floor-filled sweep now rather than stalling -- see the field's own
         // comment for why a flat display beats a frozen one.
         Result := FinishSweep(scopeId, ASweep);
         Exit;
         end;

      if division = divisionMax then
         begin
         // The LAN case: one frame, whole sweep.  This is the path every
         // network Icom runs, which is why the division machinery below never
         // executes over Ethernet.
         Result := FinishSweep(scopeId, ASweep);
         end;

      Exit;
      end;

   // Continuation divisions -- the serial/USB transport only.
   if not FAssembling[scopeId] then
      begin
      // A mid-sweep frame with no header division.  Normal right after a
      // connect, and not worth counting as a rejection every time.
      Result := issBadDivision;
      Exit;
      end;

   if division <> (FExpectedDivision[scopeId] + 1) then
      begin
      // A GAP MAKES THE SWEEP UNRECOVERABLE.  The waveform is positional and
      // carries no per-division index inside the payload, so there is nothing
      // to re-align against; concatenating what follows would draw a shifted
      // trace that looks like real data.  Abandon instead.
      FAssembling[scopeId] := False;
      Inc(FAbandoned);
      Result := issBadDivision;
      Exit;
      end;

   FExpectedDivision[scopeId] := division;

   if ACount > ICOM_SCOPE_OFF_CONTINUATION then
      begin
      AppendLevels(scopeId, AData, ICOM_SCOPE_OFF_CONTINUATION,
                   ACount - ICOM_SCOPE_OFF_CONTINUATION);
      end;

   if division = divisionMax then
      begin
      Result := FinishSweep(scopeId, ASweep);
      Exit;
      end;

   Result := issAssembling;
end;

end.
