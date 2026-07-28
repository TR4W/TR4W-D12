program tr4w_radio_bench;

{
  END-TO-END bench test: a real factory radio driver, over a real serial port,
  against the tools/radiosim simulator on the other half of a virtual pair.

  ---------------------------------------------------------------------------
  WHY THIS EXISTS SEPARATELY FROM THE UNIT TESTS
  ---------------------------------------------------------------------------
  test/unit exercises the protocol layer with no transport at all -- it calls
  ProcessMessage directly and captures SendToRadio.  That covers parsing and
  command formatting, and it is where most Yaesu/Kenwood/Icom bugs live.

  It cannot cover the layer BELOW that, which is where a different class of bug
  lives entirely:

    - the reading thread, and whether frames are assembled correctly from
      arbitrary chunk boundaries
    - terminator stripping (the driver never sees the ';')
    - the poll cycle actually reaching the radio and the answer coming back
    - LIVENESS AND RECOVERY: an open COM port is NOT a working link.  A rig
      powered off mid-contest leaves the port open and the driver happy; the
      only honest signal is "no valid response for N seconds".  That bug was
      real (the FT-1000MP would not reconnect after a power cycle) and no
      amount of transport-free testing would have found it.

  This target needs a virtual serial pair, so it CANNOT run on CI and is not
  part of the normal test run.  With no ports configured it SKIPS cleanly.

  ---------------------------------------------------------------------------
  WHAT A GREEN RUN PROVES -- and what it does not
  ---------------------------------------------------------------------------
  The far end is a simulator written to match this driver.  Agreement therefore
  proves the two are SELF-CONSISTENT and that the plumbing between them works.
  It does NOT prove the driver is right about a real radio; only hardware, the
  manufacturer's CAT manual, or an independent implementation can do that.  This
  project has already been bitten by treating a simulator as an authority --
  a disagreement led to "fixing" a TS-890 path that worked on real hardware.

  So: use this to catch regressions in the transport and recovery layers, and to
  shake out a new driver before hardware is available.  Never to conclude that a
  driver is correct.

  ---------------------------------------------------------------------------
  USAGE
  ---------------------------------------------------------------------------
  Create a virtual COM pair (VSPMGR or com0com), then:

      set TR4W_TEST_PORT=36        REM the half TR4W opens
      set TR4W_SIM_PORT=COM37      REM the half the simulator opens
      set TR4W_SIM_MODEL=FT991     REM optional, default FT991
      set TR4W_SIM_BAUD=4800       REM optional, default 4800
      set TR4W_TOOLS_DIR=C:\tr4w-d12\tools   REM optional if layout is standard
      tr4w_radio_bench.exe

  The two ports must be the two ENDS OF THE SAME PAIR, and they must be
  different from each other -- see the guard in Main, which is there because
  pointing both at one port produces a baffling silent hang.
}

{$APPTYPE CONSOLE}

uses
   Windows,
   SysUtils,
   Log4D,
   MainUnit,
   VC,
   uFactoryRadioBase,
   uRadioYaesuASCII,
   uRadioYaesuFTDX10,
   uRadioYaesuFT991,
   uSimProcess in 'uSimProcess.pas';

type
   // TFactoryRadioBase.vfo is PROTECTED and GetVFO is PRIVATE, so a plain
   // TFactoryRadioBase reference cannot read the radio's state.  Declaring a
   // descendant HERE makes the protected members visible to this unit, and a
   // cast through it reads them without touching production visibility for the
   // sake of a test.  Safe because it is only ever applied to instances that
   // really are TYaesuSerial descendants -- see MakeRadio, which is the only
   // place a radio is constructed.
   TSerialAccess = class(TYaesuSerial);

var
   GPass: integer = 0;
   GFail: integer = 0;

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

procedure Pass(const What: string);
begin
   Inc(GPass);
   WriteLn('[PASS] ', What);
end;

procedure Fail(const What, Detail: string);
begin
   Inc(GFail);
   WriteLn('[FAIL] ', What, ' -- ', Detail);
end;

procedure Skipped(const What, Why: string);
begin
   // NOT counted as a pass OR a failure.  A check that never really ran must not
   // be reported as either -- see the note on false passes in Abort.
   WriteLn('[SKIP] ', What, ' -- ', Why);
end;

procedure Abort(const Why: string);
begin
   WriteLn('');
   WriteLn('ABORTING the remaining checks: ', Why);
   WriteLn('Running them against a dead link would produce FALSE PASSES, not');
   WriteLn('failures: several assertions here are negatives -- "split is off",');
   WriteLn('"the link is up" -- and a radio that never answers satisfies them');
   WriteLn('trivially.  The first run of this harness did exactly that and');
   WriteLn('reported 3 passes while the simulator had never started.');
   WriteLn('');
end;

procedure CheckTrue(Condition: boolean; const What, Detail: string);
begin
   if Condition then
      begin
      Pass(What);
      end
   else
      begin
      Fail(What, Detail);
      end;
end;

// ---------------------------------------------------------------------------
// Waiting
//
// Every assertion here is about something that happens ASYNCHRONOUSLY -- the
// reading thread has to receive a frame and the driver has to parse it.  A fixed
// Sleep would be both slower and flakier than polling for the condition, so
// everything waits on a predicate with a timeout and returns as soon as it is
// satisfied.  PollRadioState is re-sent each time round because nothing else is
// driving the poll loop in this harness (in the app, uRadioPolling does it).
// ---------------------------------------------------------------------------

type
   TPredicate = function(radio: TFactoryRadioBase): boolean;

function WaitFor(radio: TFactoryRadioBase; pred: TPredicate;
                 timeoutMs: integer; poll: boolean = True): boolean;
var
   deadline: LongWord;
begin
   deadline := GetTickCount + LongWord(timeoutMs);
   repeat
      if pred(radio) then
         begin
         Result := True;
         Exit;
         end;
      if poll then
         begin
         radio.PollRadioState;
         end;
      Sleep(100);
   until GetTickCount > deadline;
   Result := pred(radio);
end;

function FreqA(radio: TFactoryRadioBase): integer;
begin
   Result := TSerialAccess(radio).vfo[nrVFOA].frequency;
end;

function FreqB(radio: TFactoryRadioBase): integer;
begin
   Result := TSerialAccess(radio).vfo[nrVFOB].frequency;
end;

// Predicates -------------------------------------------------------------

function FreqIs14025000(radio: TFactoryRadioBase): boolean;
begin
   Result := FreqA(radio) = 14025000;
end;

function FreqIs14200000(radio: TFactoryRadioBase): boolean;
begin
   Result := FreqA(radio) = 14200000;
end;

function FreqIs14150000(radio: TFactoryRadioBase): boolean;
begin
   Result := FreqA(radio) = 14150000;
end;

function VFOBIsSet(radio: TFactoryRadioBase): boolean;
begin
   Result := FreqB(radio) > 0;
end;

function ModeIsCW(radio: TFactoryRadioBase): boolean;
begin
   Result := TSerialAccess(radio).vfo[nrVFOA].mode = rmCW;
end;

function SplitIsOn(radio: TFactoryRadioBase): boolean;
begin
   Result := radio.IsSplitEnabled;
end;

function SplitIsOff(radio: TFactoryRadioBase): boolean;
begin
   Result := not radio.IsSplitEnabled;
end;

function LinkIsDown(radio: TFactoryRadioBase): boolean;
begin
   Result := not radio.IsConnected;
end;

function LinkIsUp(radio: TFactoryRadioBase): boolean;
begin
   Result := radio.IsConnected;
end;

// ---------------------------------------------------------------------------

function EnvOr(const Name, Default: string): string;
var
   buf: array[0..1023] of Char;
   n: DWORD;
begin
   n := GetEnvironmentVariable(PChar(Name), buf, Length(buf));
   if (n = 0) or (n >= DWORD(Length(buf))) then
      begin
      Result := Default;
      end
   else
      begin
      Result := Copy(buf, 1, n);
      end;
end;

function DefaultToolsDir: string;
begin
   // <repo>\tr4w\test\integration\<exe>  ->  <repo>\tools
   Result := ExpandFileName(
      IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + '..\..\..\tools');
end;

// ---------------------------------------------------------------------------

// The DRIVER must match the model the simulator is impersonating, or the test
// silently compares two different radios.  They differ on the mode character
// 'E' (C4FM vs PSK31), which is precisely the kind of mismatch that would look
// like a driver bug.  Unknown model -> nil, and the caller reports it.
function MakeRadio(const Model: string): TFactoryRadioBase;
begin
   if SameText(Model, 'FT991') then
      begin
      Result := TYaesuFT991Radio.Create;
      end
   else if SameText(Model, 'FTDX10') then
      begin
      Result := TFTDX10Radio.Create;
      end
   else
      begin
      Result := nil;
      end;
end;

procedure RunBench(const TestPort, SimPort, Model, ToolsDir: string; Baud: integer);
var
   radio: TFactoryRadioBase;
   sim: TSimProcess;
   why: string;
   rc: integer;
begin
   sim := TSimProcess.Create;
   radio := nil;
   try
      WriteLn(Format('Starting %s simulator on %s (%d baud) from %s',
                     [Model, SimPort, Baud, ToolsDir]));
      if not sim.Start(ToolsDir, Model, SimPort, Baud, why) then
         begin
         Fail('start the simulator', why);
         Exit;
         end;

      // Give Python time to import and open the port.  If TR4W opens its half
      // first and the simulator is not listening, the first poll is simply lost;
      // harmless, but it makes the transcript confusing.
      Sleep(2500);

      // By far the most common failure is the simulator exiting immediately
      // because its half of the pair is ALREADY OPEN -- a previous run, or an
      // interactive session someone left up.  Catch it here and say so, rather
      // than letting it surface as eight unexplained protocol failures.
      if not sim.IsAlive then
         begin
         Fail('the simulator stays running',
              'it exited during startup -- the Python traceback above says why.  ' +
              'Usually ' + SimPort + ' either does not exist (check the pair was ' +
              'created, and that this is the OTHER half from TR4W_TEST_PORT) or ' +
              'is already open by another simulator, a terminal, or a previous run.');
         Abort('the simulator is not running');
         Exit;
         end;

      radio := MakeRadio(Model);
      if radio = nil then
         begin
         Fail('build a driver for the simulated model',
              Format('no bench driver for "%s" (known: FT991, FTDX10)', [Model]));
         Exit;
         end;
      radio.serialPort := PortType(StrToInt(TestPort));
      radio.serialBaudRate := Baud;

      rc := radio.Connect;
      CheckTrue(rc = 0, 'Connect returns success', Format('Connect returned %d', [rc]));

      // --- the reading thread, framing and parse, over a real port ----------
      // This is the gate for everything after it: if the radio never answers,
      // no later assertion means anything.
      if not WaitFor(radio, FreqIs14025000, 10000) then
         begin
         Fail('VFO A reaches the simulator default via IF;',
              Format('frequency is %d, expected 14025000 -- no valid response ' +
                     'arrived, so the port opened but nothing is talking',
                     [FreqA(radio)]));
         Abort('the radio never answered');
         Exit;
         end;
      Pass('VFO A reaches the simulator default via IF;');

      CheckTrue(WaitFor(radio, ModeIsCW, 5000),
                'mode is decoded from the IF; response',
                'mode never became CW');

      // VFO B needs its own OI; -- if the poll cycle were truncated, or OI; were
      // routed to VFO A, this stays zero while everything else looks healthy.
      CheckTrue(WaitFor(radio, VFOBIsSet, 5000),
                'VFO B is populated by OI;',
                'VFO B frequency stayed 0');

      // --- the radio changing under us --------------------------------------
      sim.Send('f 14200000');
      CheckTrue(WaitFor(radio, FreqIs14200000, 8000),
                'a frequency change at the radio reaches TR4W',
                Format('frequency is %d, expected 14200000', [FreqA(radio)]));

      sim.Send('s');
      if WaitFor(radio, SplitIsOn, 8000) then
         begin
         Pass('split engaged at the radio is seen via FT;');

         // Only meaningful once split was actually ON.  Checked cold it passes
         // no matter what, because split starts off.
         sim.Send('s');
         CheckTrue(WaitFor(radio, SplitIsOff, 8000),
                   'split cleared at the radio is seen via FT;',
                   'split never went back to false');
         end
      else
         begin
         Fail('split engaged at the radio is seen via FT;', 'split never became true');
         Skipped('split cleared at the radio is seen via FT;',
                 'split never turned on, so clearing it proves nothing');
         end;

      // --- round trip: our command must actually reach the far end ----------
      // Asserted by reading it BACK through the poll, not by trusting the write.
      radio.SetFrequency(14150000, nrVFOA, rmNone);
      CheckTrue(WaitFor(radio, FreqIs14150000, 8000),
                'SetFrequency reaches the radio and reads back',
                Format('frequency is %d, expected 14150000', [FreqA(radio)]));

      // --- liveness and recovery --------------------------------------------
      // The simulator stops answering while KEEPING THE PORT OPEN, which is
      // exactly what a rig switched off at the front panel looks like.  An open
      // handle proves nothing; only the response timeout does.
      sim.Send('d');
      if WaitFor(radio, LinkIsDown, 15000) then
         begin
         Pass('a radio that stops answering is detected as disconnected');

         // Same trap as split: "the link is up" is true of a link that was
         // never down, so this only counts after a real drop was observed.
         sim.Send('u');
         CheckTrue(WaitFor(radio, LinkIsUp, 15000),
                   'the link recovers when the radio answers again',
                   'IsConnected never returned to true');
         end
      else
         begin
         Fail('a radio that stops answering is detected as disconnected',
              'IsConnected stayed true past the response timeout');
         Skipped('the link recovers when the radio answers again',
                 'the link was never seen to drop, so recovery proves nothing');
         end;

   finally
      if radio <> nil then
         begin
         try
            radio.Disconnect;
         except
            on E: Exception do
               begin
               WriteLn('  (Disconnect raised ', E.ClassName, ': ', E.Message, ')');
               end;
         end;
         radio.Free;
         end;
      sim.Stop;
      sim.Free;
   end;
end;

// ---------------------------------------------------------------------------

var
   testPort, simPort, model, toolsDir: string;
   baud: integer;

begin
   // The radio classes log through MainUnit's global `logger`, which tr4w.dpr
   // assigns at startup.  Without this every received frame faults -- see the
   // same note in the unit-test project.
   logger := TLogLogger.GetLogger('TR4WRadioBench');

   WriteLn('=== TR4W radio bench (driver <-> simulator over a real serial pair) ===');
   WriteLn('');

   testPort := EnvOr('TR4W_TEST_PORT', '');
   simPort  := EnvOr('TR4W_SIM_PORT',  '');
   model    := EnvOr('TR4W_SIM_MODEL', 'FT991');
   toolsDir := EnvOr('TR4W_TOOLS_DIR', DefaultToolsDir);
   baud     := StrToIntDef(EnvOr('TR4W_SIM_BAUD', '4800'), 4800);

   if (testPort = '') or (simPort = '') then
      begin
      WriteLn('SKIPPED: needs a virtual COM pair.');
      WriteLn('  set TR4W_TEST_PORT=36        (number only -- the half TR4W opens)');
      WriteLn('  set TR4W_SIM_PORT=COM37      (the other half, for the simulator)');
      WriteLn('  optional: TR4W_SIM_MODEL (default FT991), TR4W_SIM_BAUD (4800),');
      WriteLn('            TR4W_TOOLS_DIR (default ', DefaultToolsDir, ')');
      WriteLn('');
      WriteLn('Not a failure: this target cannot run without the pair.');
      ExitCode := 0;
      Exit;
      end;

   // Both halves pointing at one port produces a silent hang that looks like a
   // driver fault.  Say so instead.
   if SameText('COM' + testPort, simPort) or SameText(testPort, simPort) then
      begin
      WriteLn('ERROR: TR4W_TEST_PORT and TR4W_SIM_PORT are the same port.');
      WriteLn('       They must be the two ENDS of one virtual pair.');
      ExitCode := 2;
      Exit;
      end;

   if StrToIntDef(testPort, -1) < 0 then
      begin
      WriteLn('ERROR: TR4W_TEST_PORT must be a NUMBER (36), not a name (COM36).');
      ExitCode := 2;
      Exit;
      end;

   try
      RunBench(testPort, simPort, model, toolsDir, baud);
   except
      on E: Exception do
         begin
         Fail('bench run', E.ClassName + ': ' + E.Message);
         end;
   end;

   WriteLn('');
   WriteLn(Format('PASSED: %d  FAILED: %d', [GPass, GFail]));
   if GFail > 0 then
      begin
      WriteLn('FAILURES detected -- see above.');
      ExitCode := 1;
      end
   else
      begin
      WriteLn('All bench checks passed.');
      ExitCode := 0;
      end;
end.
