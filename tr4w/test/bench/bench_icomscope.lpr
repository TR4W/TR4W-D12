program bench_icomscope;

{
  END-TO-END bench: an Icom's CI-V bandscope against a real networked radio.

  ---------------------------------------------------------------------------
  THIS IS A MEASURING INSTRUMENT FIRST AND A TEST SECOND
  ---------------------------------------------------------------------------
  The K4's equivalent (bench_k4spectrum) exists to prove a stream works,
  because the K4's wire format had already been MEASURED by tools/k4panwatch.py
  and frozen into a fixture before a line of Pascal was written.  Nothing
  equivalent exists for Icom, and the gap is not small:

    * HamLib publishes scope geometry for the IC-7300 family, the IC-7610, the
      IC-785x and the IC-R8600 -- and for NONE of the IC-9700, IC-705 or
      IC-7760.
    * AetherSDR's table verifies exactly one model against Icom's own CI-V
      guide (the IC-7300MK2, with the IC-705 close behind), records the IC-9700
      from a live capture, marks the rest unverified, and does not list the
      IC-7760 at all.

  So the IC-7760's point count and level range are, as far as this work could
  determine, PUBLISHED NOWHERE.  Its driver declares 475/160 as a provisional
  guess and says so.  This program is how that guess gets replaced by a fact.

  ---------------------------------------------------------------------------
  WHAT IT REPORTS, AND HOW MUCH EACH IS WORTH
  ---------------------------------------------------------------------------
  MEASURED POINTS -- strong.  The number of level bytes a sweep actually
  carried, taken BEFORE the decoder truncates to the declared geometry.  Over
  LAN a sweep arrives whole, so this is the radio's point count directly.  If
  it disagrees with the declaration, the declaration is wrong.

  SCOPE IDS SEEN -- strong.  Which values the rig puts in payload byte [0].
  HamLib says 0 = Main and 1 = Sub; AetherSDR says the byte is a fixed zero.
  A dual-scope rig settles that argument by emitting more than one.

  HIGHEST LEVEL -- WEAK, and labelled so.  A lower bound on the range, reached
  only if something in the passband was strong during the run.  It can prove a
  radio is NOT 0..160; it cannot prove one is.

  CENTRE AND SPAN -- cross-check.  If they match where the rig is tuned and
  what its display shows, the mode handling and the half-width doubling are
  both right.  If the span is out by exactly 2x, the doubling is inverted --
  the single most likely error in this decoder and the one both references warn
  about by name.

  ---------------------------------------------------------------------------
  THE FIXTURE
  ---------------------------------------------------------------------------
  With -capture <file> it writes raw $27 $00 payloads, length-prefixed, to a
  file that becomes a regression fixture the way k4pan-sample.bin did.

  CAPTURED UPSTREAM OF THE DECODER (TIcomRadio.OnScopePayload), so the fixture
  is evidence about the RADIO rather than a record of what this decoder made of
  it -- a fixture taken downstream would bake in any decode bug and then be
  used to prove that decoder correct.

  Format: for each payload, a 2-byte little-endian length then that many bytes.
  Deliberately trivial, and deliberately NOT the CI-V frame: the preamble,
  addresses and terminator are the transport's business and are already covered
  by the CI-V tests.

  ---------------------------------------------------------------------------
  WHAT A GREEN RUN DOES NOT PROVE
  ---------------------------------------------------------------------------
  Nothing about rendering, and nothing about the dB axis.  uIcomScope maps
  levels to dB at an ESTIMATED 0.5 dB per unit, and no amount of watching
  frames arrive can check that -- it needs a known signal source and an
  S-meter reading to compare against.  Until someone does that, the axis is
  relative and must not be labelled dBm.

  It also proves nothing about the SERIAL path.  Over a serial link the sweep
  is divided into 11 or 15 segments and reassembled; uIcomScope implements and
  unit-tests that, SpectrumAvailable refuses it, and this program cannot reach
  it because it connects over the network.

  ---------------------------------------------------------------------------
  USAGE
  ---------------------------------------------------------------------------
     bench_icomscope <model> <host> <user> <password> [seconds] [-capture <file>]
     bench_icomscope IC9700 192.168.1.50 ny4i secret 30 -capture ic9700-scope.bin

  <model> is the REGISTRY ID, not a display name -- IC9700, IC7760, IC7610,
  IC705.  It is an argument rather than a discovery step because the CI-V
  address that identifies a model is only readable AFTER a connection, and the
  connection needs a driver already chosen.

  With too few arguments it SKIPS cleanly (exit 0), so a script on a machine
  with no radio is safe.  Exit 1 means it ran and something was wrong.

  UNLIKE THE K4 BENCH, THIS ONE OPENS THE CAT LINK -- it has to, because the
  scope rides CI-V and there is no side channel to listen to.  It therefore
  touches the radio: it sends $27 $10 and $27 $11 to enable the scope and its
  data output, and turns the data output back off on the way out.  The scope
  itself is left as it was found, because that is the operator's setting and
  not this program's.
}

{$I ..\..\src\tr4w.inc}
{$APPTYPE CONSOLE}

(* THE INCLUDE ABOVE IS LOAD-BEARING, AND ITS ABSENCE COST A BENCH RUN.

   tr4w.inc turns on the UnicodeStrings modeswitch, so every unit under src
   compiles with a UTF-16 `string`.  A harness WITHOUT it compiles with an
   8-bit one -- and no harness in this tree had it: not the unit tests, not
   bench_k4spectrum, not this file until now.

   For a test that passes ASCII around, the difference is invisible.  For one
   that hands raw protocol bytes to a driver it is not: this program built
   probe frames with Char($FE), which under an 8-bit Char is the byte $FE, and
   handing that to SendToRadio converted it to UTF-16 through
   DefaultSystemCodePage (65001, UTF-8), where a lone byte >= $80 is invalid.
   Every probe frame went on the wire as FFFD FFFD FFFD FFFD 27 12 FFFD and the
   radio ignored all of them -- which reads exactly like a radio that does not
   support the command.

   So a bench for a BINARY protocol must compile under the same string regime
   as the code it is exercising, or it is testing a different program. *)

uses
   // Interfaces FIRST, exactly as tr4w_unit_tests.lpr does -- linking MainUnit
   // drags in the LCL, whose widgetset registration lives here.  Nothing here
   // opens a window; this is a link-time requirement, not a UI one.
   Interfaces,
   Classes, SysUtils, SyncObjs, Log4D, uLogConfig, MainUnit, VC,
   uSpectrumTypes, uFactoryRadioBase, uIcomScope, uRadioIcomBase,
   uRadioRegistry;

const
   MAX_SOURCES = 8;
   DEFAULT_SECONDS = 30;
   { Consecutive dead seconds that turn a truncated run into a FAILURE.
     Generous: a healthy LAN link delivers several sweeps a second. }
   STALL_LIMIT_SECONDS = 5;

type
   TSourceTally = record
      Id: string;
      Count: Integer;
      CentreHz: Int64;
      SpanHz: Int64;
      NoiseFloorDb: Single;
      MinDb: Single;
      MaxDb: Single;
      BinCount: Integer;
   end;

   { Subscriber and capturer.

     THE CALLBACKS ARRIVE ON THE CI-V RECEIVE THREAD, not the main one -- which
     is the contract TSpectrumFrameProc already states and the reason every
     touch of shared state below is inside the lock.  Nothing keeps a reference
     to AFrame.Bins past the call: the scalars are copied and the array is
     summarised on the spot. }
   TScopeCollector = class(TObject)
   private
      FLock: TCriticalSection;
      FTotal: Integer;
      FSources: array[0 .. MAX_SOURCES - 1] of TSourceTally;
      FSourceCount: Integer;
      FCapture: TFileStream;
      FCaptured: Integer;
      function IndexOf(const AId: string): Integer;
   public
      constructor Create(const ACapturePath: string);
      destructor Destroy; override;

      procedure OnFrame(const AFrame: TSpectrumFrame);
      procedure OnPayload(const APayload: TBytes);

      function Total: Integer;
      function Captured: Integer;
      procedure Report;
   end;

constructor TScopeCollector.Create(const ACapturePath: string);
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FTotal := 0;
   FSourceCount := 0;
   FCaptured := 0;
   FCapture := nil;

   if ACapturePath <> '' then
      begin
      FCapture := TFileStream.Create(ACapturePath, fmCreate);
      end;
end;

destructor TScopeCollector.Destroy;
begin
   FreeAndNil(FCapture);
   FreeAndNil(FLock);
   inherited Destroy;
end;

function TScopeCollector.IndexOf(const AId: string): Integer;
var
   i: Integer;
begin
   Result := -1;

   for i := 0 to FSourceCount - 1 do
      begin
      if FSources[i].Id = AId then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TScopeCollector.OnPayload(const APayload: TBytes);
var
   len: Word;
begin
   if (FCapture = nil) or (Length(APayload) = 0) then
      begin
      Exit;
      end;

   FLock.Acquire;

   try
      // Length-prefixed so the reader needs no knowledge of the format it is
      // about to hold -- which is the point of freezing it before anything has
      // been decided about how to parse it.
      len := Word(Length(APayload));
      FCapture.WriteBuffer(len, SizeOf(len));
      FCapture.WriteBuffer(APayload[0], Length(APayload));
      Inc(FCaptured);
   finally
      FLock.Release;
   end;
end;

procedure TScopeCollector.OnFrame(const AFrame: TSpectrumFrame);
var
   ix: Integer;
   i: Integer;
   lo, hi: Single;
begin
   if AFrame.BinCount <= 0 then
      begin
      Exit;
      end;

   lo := AFrame.Bins[0];
   hi := AFrame.Bins[0];

   for i := 1 to AFrame.BinCount - 1 do
      begin
      if AFrame.Bins[i] < lo then
         begin
         lo := AFrame.Bins[i];
         end;

      if AFrame.Bins[i] > hi then
         begin
         hi := AFrame.Bins[i];
         end;
      end;

   FLock.Acquire;

   try
      Inc(FTotal);
      ix := IndexOf(AFrame.SourceId);

      if (ix < 0) and (FSourceCount < MAX_SOURCES) then
         begin
         ix := FSourceCount;
         Inc(FSourceCount);
         FSources[ix].Id := AFrame.SourceId;
         FSources[ix].Count := 0;
         end;

      if ix < 0 then
         begin
         Exit;
         end;

      Inc(FSources[ix].Count);
      FSources[ix].CentreHz := AFrame.CentreHz;
      FSources[ix].SpanHz := AFrame.SpanHz;
      FSources[ix].NoiseFloorDb := AFrame.NoiseFloorDb;
      FSources[ix].BinCount := AFrame.BinCount;
      FSources[ix].MinDb := lo;
      FSources[ix].MaxDb := hi;
   finally
      FLock.Release;
   end;
end;

function TScopeCollector.Total: Integer;
begin
   FLock.Acquire;

   try
      Result := FTotal;
   finally
      FLock.Release;
   end;
end;

function TScopeCollector.Captured: Integer;
begin
   FLock.Acquire;

   try
      Result := FCaptured;
   finally
      FLock.Release;
   end;
end;

procedure TScopeCollector.Report;
var
   i: Integer;
begin
   FLock.Acquire;

   try
      WriteLn;
      WriteLn('  sweeps decoded : ', FTotal);
      WriteLn('  scopes seen    : ', FSourceCount);

      for i := 0 to FSourceCount - 1 do
         begin
         WriteLn;
         WriteLn(Format('  scope %-2s  sweeps %-5d  bins %d',
                        [FSources[i].Id, FSources[i].Count, FSources[i].BinCount]));
         WriteLn(Format('            centre %d Hz   span %d Hz (total width)',
                        [FSources[i].CentreHz, FSources[i].SpanHz]));
         WriteLn(Format('            floor %.1f dB(rel)   bins %.1f .. %.1f',
                        [FSources[i].NoiseFloorDb, FSources[i].MinDb, FSources[i].MaxDb]));
         end;
   finally
      FLock.Release;
   end;
end;

// ---------------------------------------------------------------------------


(* ASK THE RADIO WHAT ITS SCOPE IS SET TO -- AND IN WHICH SHAPE.

   Every $27 sub-command has a READ form: the same sub-command with no value.
   What is NOT agreed is whether that read carries a scope-SELECTOR byte:

     * HamLib puts the selector first on every scope sub-command it implements
       ($14 mode, $15 span, $19 reference), on READ as well as SET;
     * AetherSDR omits it on $10 and $11 (it targets the single-scope IC-705)
       and includes it on $15, where it warns that leaving it out makes the
       radio ignore the frame outright -- no NG, no error, nothing changes.

   So each sub-command is asked BOTH WAYS and the log shows which form the
   radio answers.  A reply is proof the form is right; silence is proof it is
   not, and silence is the whole difficulty -- it is indistinguishable from a
   radio that simply has nothing to say.

   BUT "BOTH WAYS" IS NOT SAFE FOR EVERY SUB-COMMAND, AND ASKING IT THAT WAY
   BROKE A MEASUREMENT.  The trailing byte does not mean the same thing across
   the $27 family:

     * on the GLOBAL sub-commands the setting exists once for the radio, the
       bare form IS the read, and a trailing byte is the VALUE.  `27 10 00` is
       not "read scope 0" -- it is SCOPE OFF.
     * only on the PER-SCOPE sub-commands is a trailing byte a selector.

   Measured on an IC-7760 on 2026-08-28: the old unconditional "with selector"
   pass sent `27 10 00` and `27 11 00`, which switched the scope and the wave
   output off 132 ms after the last sweep.  The run then measured nothing for
   its remaining 28 seconds and still printed PASS.  So the selector pass is
   now restricted to the sub-commands where that byte is actually a selector.

   Frames are built with Char() typecasts, never Chr() -- see the CivChr note
   in uRadioIcomBase for what that costs. *)
procedure ProbeScopeSettings(ARadio: TIcomRadio; AWithSelector: Boolean);
const
   { GLOBAL -- one setting for the whole radio.  A TRAILING BYTE IS THE VALUE,
     so these are probed BARE ONLY and must never be sent a selector. }
   GLOBAL_SUBS: array[0 .. 4] of Byte =
      ($10,   // scope on/off          -- trailing byte = ON/OFF VALUE
       $11,   // CI-V wave data output -- trailing byte = ON/OFF VALUE
       $12,   // main/sub setting      -- trailing byte = VALUE
       $13,   // single/dual scope     -- trailing byte = VALUE
       $1B);  // scope during TX       -- trailing byte = VALUE

   { PER-SCOPE -- the setting exists once per scope, so the read has to name
     one.  Measured on the IC-7760: each of these answers NG ($FA) when sent
     bare and answers normally with a trailing scope byte.  These are the only
     sub-commands for which the selector form is a READ and not a SET. }
   SCOPE_SUBS: array[0 .. 4] of Byte =
      ($14,   // centre/fixed mode
       $15,   // span
       $17,   // hold
       $19,   // reference level
       $1A);  // sweep speed

   procedure SendProbe(ASub: Byte; AIncludeSelector: Boolean);
   var
      frame: string;
      payload: string;
   begin
      if AIncludeSelector then
         begin
         payload := Char($27) + Char(ASub) + Char(ARadio.ScopeIdToFollow);
         end
      else
         begin
         payload := Char($27) + Char(ASub);
         end;

      frame := Char($FE) + Char($FE) +
               Char(ARadio.RadioAddress) + Char(ARadio.ControllerAddress) +
               payload + Char($FD);
      ARadio.SendToRadio(frame);
   end;

var
   i: Integer;
begin
   if AWithSelector then
      begin
      { ONLY the per-scope sub-commands.  A trailing byte on a global one is a
        SET and would switch the scope off in the middle of the measurement. }
      for i := Low(SCOPE_SUBS) to High(SCOPE_SUBS) do
         begin
         SendProbe(SCOPE_SUBS[i], True);
         end;
      end
   else
      begin
      // Bare is safe for both groups: a read for the globals, an NG for the
      // per-scope ones -- and that NG is itself the evidence we are after.
      for i := Low(GLOBAL_SUBS) to High(GLOBAL_SUBS) do
         begin
         SendProbe(GLOBAL_SUBS[i], False);
         end;

      for i := Low(SCOPE_SUBS) to High(SCOPE_SUBS) do
         begin
         SendProbe(SCOPE_SUBS[i], False);
         end;
      end;
end;

function FindModel(const aName: string; out aModel: InterfacedRadioType): Boolean;
var
   m: InterfacedRadioType;
begin
   Result := False;
   aModel := NoInterfacedRadio;

   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if (m = NoInterfacedRadio) or (not uRadioRegistry.IsRegistered(m)) then
         begin
         Continue;
         end;

      if SameText(uRadioRegistry.ModelId(m), aName) then
         begin
         aModel := m;
         Result := True;
         Exit;
         end;
      end;
end;

var
   host: string;
   user: string;
   pass: string;
   modelName: string;
   capturePath: string;
   seconds: Integer;
   model: InterfacedRadioType;
   base: TFactoryRadioBase;
   radio: TIcomRadio;
   collector: TScopeCollector;
   started: TDateTime;
   elapsed: Double;
   lastTotal, nowTotal: Integer;
   stalledFor, worstStall: Integer;
   failed: Boolean;
   i: Integer;
   appender: TLogRollingFileAppender;

begin
   if ParamCount < 4 then
      begin
      WriteLn('bench_icomscope: not enough arguments -- SKIPPED');
      WriteLn('  usage: bench_icomscope <model> <host> <user> <password> [seconds] [-capture <file>]');
      WriteLn('  e.g.:  bench_icomscope IC9700 192.168.1.50 ny4i secret 30 -capture ic9700-scope.bin');
      Halt(0);
      end;

   modelName := ParamStr(1);
   host := ParamStr(2);
   user := ParamStr(3);
   pass := ParamStr(4);
   seconds := StrToIntDef(ParamStr(5), DEFAULT_SECONDS);
   capturePath := '';

   for i := 5 to ParamCount do
      begin
      if SameText(ParamStr(i), '-capture') and (i < ParamCount) then
         begin
         capturePath := ParamStr(i + 1);
         end;
      end;

   // The radio factory logs through MainUnit's global `logger`, which only
   // tr4w.lpr's startup assigns.  A standalone EXE that links app units must
   // assign it or the first call that logs dies with an access violation.
   { A REAL LOG, not just the console tally.

     The first run against an IC-9700 decoded nothing and the console could not
     say why -- "no sweeps" is the same output whether the handshake never
     finished, the enables were dropped, or the radio simply had its scope off.
     The transport and the driver both log that distinction in detail and there
     was no appender to receive it, so the evidence existed and went nowhere.

     TRACE, deliberately: at this level every CI-V frame is hex-dumped, which is
     the difference between "the radio is silent" and "the radio is answering
     and we are misreading it".  A bench run is minutes long and nobody is
     contesting on it, so the cost that would matter in the app does not. }
   appender := TLogRollingFileAppender.Create('bench', 'bench_icomscope.log');
   appender.Layout := CreateTR4WLogLayout;
   TLogBasicConfigurator.Configure(appender);
   TLogLogger.GetRootLogger.Level := Trace;
   logger := TLogLogger.GetLogger('IcomScopeBench');
   logger.Info('---- bench_icomscope starting ----');

   if not FindModel(modelName, model) then
      begin
      WriteLn('FAIL: no registered radio named "', modelName, '"');
      Halt(1);
      end;

   base := uRadioRegistry.CreateInstanceForLink(model, rlNetwork);

   if base = nil then
      begin
      WriteLn('FAIL: ', modelName, ' has no network driver');
      Halt(1);
      end;

   if not (base is TIcomRadio) then
      begin
      WriteLn('FAIL: ', modelName, ' is not an Icom');
      base.Free;
      Halt(1);
      end;

   radio := TIcomRadio(base);
   failed := False;
   collector := TScopeCollector.Create(capturePath);

   try
      { THROUGH THE BASE, DELIBERATELY.  TIcomRadio publishes RadioAddress as the
        CI-V ADDRESS (a Byte) and it shadows TFactoryRadioBase.radioAddress, the
        host string -- assigning a host to the unqualified name is a type error
        here, and would have been a SILENT one had the two types matched.  The
        driver casts the same way for the same reason. }
      TFactoryRadioBase(radio).radioAddress := host;
      radio.radioPort := uRadioRegistry.RegisteredNetworkPort(model);
      radio.ApplyNetworkCredentials(user, pass);

      WriteLn(Format('Icom scope bench -- %s at %s:%d', [modelName, host, radio.radioPort]));
      WriteLn(Format('  declared geometry : %d points, levels 0..%d',
                     [radio.ScopeGeometryPoints, radio.ScopeGeometryMaxLevel]));
      WriteLn(Format('  rcSpectrum        : %s', [BoolToStr(radio.Supports(rcSpectrum), True)]));
      WriteLn(Format('  SpectrumAvailable : %s', [BoolToStr(radio.SpectrumAvailable, True)]));

      if not radio.SpectrumAvailable then
         begin
         WriteLn('FAIL: a network Icom with a geometry should report spectrum available');
         Halt(1);
         end;

      // THE CAT LINK IS REQUIRED HERE, unlike the K4 bench: the scope rides
      // CI-V, so without a connection there is nothing to listen to.
      WriteLn('Connecting ...');

      if radio.Connect <> 0 then
         begin
         WriteLn('FAIL: could not start the connection');
         Halt(1);
         end;

      { CONNECT ONLY STARTS THE HANDSHAKE.  Saying "connected" on the strength
        of its return value is how a run against a powered-off radio got all
        the way to "no sweeps decoded" and then blamed $27 $11 -- the rig had
        never answered the first packet.  Ask the strict signal instead. }
      if not radio.WaitForOperational(CONNECT_TIMEOUT_MS) then
         begin
         WriteLn('FAIL: the radio never completed its handshake.');
         WriteLn('  Connect started, but the link never became operational.');
         WriteLn('  Check the radio is powered on, on the network, and at the');
         WriteLn('  address given -- the bench log records the last transport state.');
         Halt(1);
         end;

      radio.OnSpectrumFrame := collector.OnFrame;
      radio.OnScopePayload := collector.OnPayload;
      radio.StartSpectrum;

      if not radio.SpectrumStreaming then
         begin
         WriteLn('FAIL: StartSpectrum did not start');
         Halt(1);
         end;

      WriteLn(Format('Streaming for %d s ...', [seconds]));

      if capturePath <> '' then
         begin
         WriteLn('Capturing raw payloads to ', capturePath);
         end;

      WriteLn;

      // A moment for the enables to land, then ask the rig to describe itself.
      Sleep(750);
      WriteLn('Probing scope settings, BARE form (no selector) ...');
      ProbeScopeSettings(radio, False);
      Sleep(1500);
      WriteLn('Probing scope settings, WITH selector ...');
      ProbeScopeSettings(radio, True);

      started := Now;
      lastTotal := 0;
      stalledFor := 0;
      worstStall := 0;

      repeat
         Sleep(1000);
         nowTotal := collector.Total;
         elapsed := (Now - started) * 24 * 60 * 60;

         { A STALL IS A RESULT, NOT A GAP.  `collector.Total = 0` below is
           the only other guard, and a run that streams briefly and then
           stops sails past it -- which is exactly how the 2026-08-28 run
           reported PASS on nine sweeps and 28 dead seconds. }
         if (nowTotal > lastTotal) or (nowTotal = 0) then
            begin
            stalledFor := 0;
            end
         else
            begin
            Inc(stalledFor);

            if stalledFor > worstStall then
               begin
               worstStall := stalledFor;
               end;
            end;

         WriteLn(Format('  t=%4.0f s   link %-5s   sweeps %-6d  (+%d/s)   span %d Hz',
                        [elapsed, BoolToStr(radio.SpectrumLinkUp, True),
                         nowTotal, nowTotal - lastTotal, radio.SpectrumSpanHz]));

         lastTotal := nowTotal;
      until elapsed >= seconds;

      collector.Report;

      { THE MEASUREMENT, which is the reason this program exists.  Printed
        separately from the tallies above because it is the part that gets
        written back into a driver. }
      WriteLn;
      WriteLn('---- MEASURED GEOMETRY -------------------------------------------');
      WriteLn(Format('  points carried by the last sweep : %d   (declared %d)',
                     [radio.ScopeMeasuredPoints, radio.ScopeGeometryPoints]));
      WriteLn(Format('  highest level seen               : %d   (declared max %d)',
                     [radio.ScopeMeasuredMaxLevel, radio.ScopeGeometryMaxLevel]));
      WriteLn('  NOTE: the level is a LOWER BOUND -- it only reaches the true');
      WriteLn('        maximum if something strong was in the passband.  The');
      WriteLn('        point count is exact over a LAN link.');

      if (radio.ScopeMeasuredPoints > 0) and
         (radio.ScopeMeasuredPoints <> radio.ScopeGeometryPoints) then
         begin
         WriteLn;
         WriteLn(Format('  *** THE DECLARATION IS WRONG: this radio sends %d points, not %d.',
                        [radio.ScopeMeasuredPoints, radio.ScopeGeometryPoints]));
         WriteLn('  *** Fix DeclareScopeGeometry in the driver and the row in');
         WriteLn('  *** test/unit/uTestIcomScopeSeam.pas SCOPE_PINS.');

         // A MISMATCH IS A FAILURE.  Reporting it and exiting 0 would let a
         // wrong declaration survive a bench session that had already found it.
         failed := True;
         end;

      if capturePath <> '' then
         begin
         WriteLn;
         WriteLn(Format('  captured %d raw payloads to %s',
                        [collector.Captured, capturePath]));
         end;

      // A run that connected and decoded nothing is a FAILURE, not a quiet
      // pass -- this is the whole point of the exercise, so it must not be
      // possible to report green with no evidence.
      if (collector.Total > 0) and (worstStall >= STALL_LIMIT_SECONDS) then
         begin
         WriteLn;
         WriteLn(Format('FAIL: the stream stalled -- %d consecutive seconds with no sweep.',
                        [worstStall]));
         WriteLn('  The radio streamed and then stopped.  Check whether anything this');
         WriteLn('  program sent switched the scope off: on the $27 family a trailing');
         WriteLn('  byte is a VALUE for the global sub-commands ($10 $11 $12 $13 $1B),');
         WriteLn('  so `27 10 00` means SCOPE OFF, not "read scope 0".');
         failed := True;
         end;

      if collector.Total = 0 then
         begin
         WriteLn;
         WriteLn('FAIL: no sweeps decoded.');
         WriteLn('  The link was operational, so this is not a connection problem.');
         WriteLn('  The usual cause is that only $27 $10 took effect and not $27 $11:');
         WriteLn('  the scope lights up on the radio''s own screen and nothing is sent.');
         failed := True;
         end;

      radio.StopSpectrum;

      if radio.SpectrumStreaming then
         begin
         WriteLn('FAIL: StopSpectrum left the stream running');
         failed := True;
         end;

      radio.Disconnect;
   finally
      radio.Free;
      collector.Free;
   end;

   WriteLn;

   if failed then
      begin
      WriteLn('RESULT: FAIL');
      Halt(1);
      end;

   WriteLn('RESULT: PASS');
   Halt(0);
end.
