program bench_icombands;

{
  ASK A RADIO WHICH BANDS IT HAS, AND PRINT WHAT IT SAYS.

  ---------------------------------------------------------------------------
  WHY THIS IS A PERMANENT TOOL AND NOT A THROWAWAY
  ---------------------------------------------------------------------------
  TR4W's band up/down and the drivers' band stepping both filter on transmit
  coverage, and coverage is supposed to come FROM THE RADIO.  Whether a given
  radio can actually answer that question is not decidable by reading code:
  the CI-V guides disagree, some models NAK the command, and what $1E returns
  on one rig is not what it returns on another.

  This program settles it in eight seconds, and has already earned its keep
  three times over on 2026-09-24:

    * It decided a DESIGN.  "Can the radio tell us its bands, or must each
      driver declare them?" had been an open question answered by reading; the
      IC-9700 answered it directly, and the band-stepping rewrite rests on the
      measurement rather than on an argument.

    * It produced docs/ICOM_BAND_ENUMERATION.md -- the only capture anyone
      here has of an IC-9700 describing itself.

    * It found a DEFECT NO GATE COULD HAVE FOUND.  A deliberately-NAKed probe
      frame set FTXBandsUnsupported and logged, at INFO, that the radio
      rejects $1E -- thirty milliseconds before that radio delivered all three
      of its bands.  No compiler, lint, unit test or corpus run can see that,
      because seeing it requires a radio that answers.

  docs/RADIO_BENCH_STATUS.md records that bench findings arrive only from a
  session with real hardware.  This shortens that loop.

  ---------------------------------------------------------------------------
  IT IS READ-ONLY.  THAT IS A GUARANTEE, NOT AN INTENTION.
  ---------------------------------------------------------------------------
  It opens the CAT link and lets the driver's normal connect burst run.  It
  sends NOTHING of its own: no PTT, no tune, no CW, no frequency change, no
  mode change, no setting written.  Every frame it causes to be put on the
  wire is a read.  It is safe to run against a live station with an antenna
  connected.

  (Contrast bench_icomscope, which DOES touch the radio -- it enables the
  scope data output.  That is why this is a separate program rather than a
  switch on that one.)

  ---------------------------------------------------------------------------
  IT DISCONNECTS CLEANLY, AND THAT MATTERS MORE THAN ANYTHING ELSE HERE
  ---------------------------------------------------------------------------
  A networked Icom NEVER ACKNOWLEDGES A DISCONNECT and runs its own session
  expiry -- measured at ~90.6 s on an IC-7760 (see docs/RADIO_BENCH_STATUS.md).
  A probe that exits without tearing its session down therefore LOCKS THE
  OPERATOR OUT OF THEIR OWN RADIO for a minute and a half, and the rig gives
  no sign of why.

  So this program always disconnects, always waits for the teardown to go out,
  and always SAYS on the console what it did.  If you extend it, keep that
  property: an early Halt that skips the disconnect is a defect, not a
  shortcut.  Check for a running TR4W before you start -- a second client is
  a second session.

  ---------------------------------------------------------------------------
  WHAT IT REPORTS
  ---------------------------------------------------------------------------
  RAW AND DECODED, BOTH.  The console shows the answer -- how many transmit
  ranges the radio reported and which of TR4W's bands fall inside them.  The
  log shows the evidence: every $1E and $02 payload as hex, next to the
  driver's decode of it, at INFO.  A tool that printed only a conclusion would
  be no use the day the conclusion is wrong.

  READ THE LOG for the $02 COMPARISON, which comes free with every run.  The
  driver asks $02 as well as $1E, and the two are not equivalent: on an
  IC-9700, $02 returned one pair -- the edges of the band the VFO happened to
  be on -- and NAKed every argument form, while $1E enumerated all three
  bands.  If a future model behaves differently, that difference is already in
  the log of a run you have done.

  ---------------------------------------------------------------------------
  SCOPE: ICOM, AND DELIBERATELY NO WIDER
  ---------------------------------------------------------------------------
  "Ask any radio a diagnostic question" is a framework, and there is nothing
  to build it out of: no other family here has a band-enumeration command at
  all.  Kenwood, Yaesu, Elecraft and Flex would each need a different
  question, not a different argument to this one.

  Extending it is cheap when there IS something to ask: the reporting below
  reads the base class's coverage table, which every driver has, so a family
  that gains a coverage source needs only its registry id passed in and the
  `is TIcomRadio` check relaxed.  Until such a family exists, widening this
  would add generality that nothing exercises.

  ---------------------------------------------------------------------------
  BUILDING AND RUNNING
  ---------------------------------------------------------------------------
     powershell -File tr4w\build\Build-Bench.ps1 -Program bench_icombands
     bench_icombands <registryId> <host> <user> <password> [seconds]
     bench_icombands IC9700 192.168.0.10 YOURCALL YOURPASSWORD 10

  <registryId> is the REGISTRY ID, not a display name -- IC9700, IC7610,
  IC705, IC7760.

  CREDENTIALS COME FROM THE COMMAND LINE AND FROM NOWHERE ELSE.  This
  repository is public: there is no default, no example with a real value, and
  no commented-out line holding one.  The placeholders above are placeholders.

  With too few arguments it SKIPS cleanly (exit 0), so a script on a machine
  with no radio is safe.  Exit 1 means it ran and something was wrong.

  NOTE: NOTHING BUILDS THIS AUTOMATICALLY.  Build-Bench.ps1 is not called by
  FullBuild.ps1 or by any CI workflow, so a change that breaks this program
  will not fail anyone's build.  Build it by hand after touching the radio
  factory.
}

{$I ..\..\src\tr4w.inc}
{$APPTYPE CONSOLE}

(* THE INCLUDE ABOVE IS LOAD-BEARING -- see the long note in bench_icomscope.
  tr4w.inc turns on the UnicodeStrings modeswitch, and a bench for a BINARY
  protocol must compile under the same string regime as the code it exercises
  or it is testing a different program. *)

uses
   // Interfaces FIRST, exactly as tr4w_unit_tests.lpr does -- linking MainUnit
   // drags in the LCL, whose widgetset registration lives here.  Nothing here
   // opens a window; this is a link-time requirement, not a UI one.
   Interfaces,
   Classes, SysUtils, Log4D, uLogConfig, MainUnit, VC,
   uFactoryRadioBase, uRadioBand, uRadioIcomBase, uRadioRegistry;

const
   CONNECT_TIMEOUT_MS = 15000;
   DEFAULT_SECONDS    = 15;
   LOG_FILE           = 'bench_icombands.log';

var
   appender: TLogRollingFileAppender;
   base: TFactoryRadioBase;
   radio: TIcomRadio;
   model: InterfacedRadioType;
   modelName, host, user, pass: string;
   seconds, waited, covered: integer;
   b: TRadioBand;
   hz: LongInt;

function FindModel(const id: string; out m: InterfacedRadioType): boolean;
var
   t: InterfacedRadioType;
begin
   Result := False;

   for t := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if SameText(uRadioRegistry.RadioTypeToken(t), id) then
         begin
         m := t;
         Result := True;
         Exit;
         end;
      end;
end;

(* A READABLE BAND NAME where TR4W has one.  Two of the factory's bands have
  no BandType -- 60 m is commented out of that enum and 4 m (70 MHz) is
  Region 1 only -- so they are named here rather than printed as a bare
  ordinal, which tells a bench operator nothing. *)
function BandLabel(band: TRadioBand): string;
var
   bt: BandType;
begin
   bt := GetBandTypeFromRadioBand(band);

   if bt <> NoBand then
      begin
      Result := Trim(BandStringsArray[bt]);
      end
   else if band = rb60m then
      begin
      Result := '60M';
      end
   else if band = rb4m then
      begin
      Result := '4M';
      end
   else
      begin
      Result := Format('band %d', [Ord(band)]);
      end;
end;

(* ONE EXIT PATH, because the disconnect must not be skippable.  Everything
  that ends this program goes through here. *)
procedure Finish(radioToClose: TIcomRadio; code: integer);
begin
   if radioToClose <> nil then
      begin
      if radioToClose.IsConnected then
         begin
         WriteLn;
         WriteLn('Disconnecting ...');
         radioToClose.Disconnect;

         (* A networked Icom never acknowledges this, so there is nothing to
           wait FOR -- only time for the teardown to reach the rig before the
           process goes away.  Without it the radio holds the session open to
           its own expiry and the operator cannot reconnect. *)
         Sleep(1500);
         WriteLn('Disconnected -- the session was torn down, not abandoned.');
         end
      else
         begin
         WriteLn;
         WriteLn('Not connected -- no session to tear down.');
         end;

      radioToClose.Free;
      end;

   WriteLn;
   WriteLn('Raw payloads and the driver''s decode of them: ', LOG_FILE);
   Halt(code);
end;

begin
   if ParamCount < 4 then
      begin
      WriteLn('usage: bench_icombands <registryId> <host> <user> <password> [seconds]');
      WriteLn('       bench_icombands IC9700 192.168.0.10 YOURCALL YOURPASSWORD 10');
      WriteLn;
      WriteLn('Read-only: it asks the radio which bands it has and changes nothing.');
      Halt(0);
      end;

   modelName := ParamStr(1);
   host      := ParamStr(2);
   user      := ParamStr(3);
   pass      := ParamStr(4);
   seconds   := StrToIntDef(ParamStr(5), DEFAULT_SECONDS);

   { A REAL LOG, because the console carries the ANSWER and the log carries the
     EVIDENCE.  TRACE deliberately: at this level every CI-V frame is hex-dumped,
     which is the difference between "the radio is silent" and "the radio is
     answering and we are misreading it".

     The radio factory logs through MainUnit's global `logger`, which only
     tr4w.lpr's startup assigns.  A standalone EXE that links app units must
     assign it or the first call that logs dies with an access violation. }
   appender := TLogRollingFileAppender.Create('bench', LOG_FILE);
   appender.Layout := CreateTR4WLogLayout;
   TLogBasicConfigurator.Configure(appender);
   TLogLogger.GetRootLogger.Level := Trace;
   logger := TLogLogger.GetLogger('IcomBandsBench');
   logger.Info('---- bench_icombands starting ----');

   radio := nil;

   if not FindModel(modelName, model) then
      begin
      WriteLn('FAIL: no registered radio named "', modelName, '"');
      Finish(nil, 1);
      end;

   base := uRadioRegistry.CreateInstanceForLink(model, rlNetwork);

   if base = nil then
      begin
      WriteLn('FAIL: ', modelName, ' has no network driver');
      Finish(nil, 1);
      end;

   if not (base is TIcomRadio) then
      begin
      (* See the SCOPE note in the header: no other family has a band
        enumeration command, so there is nothing to ask a non-Icom. *)
      WriteLn('FAIL: ', modelName, ' is not an Icom -- no family else has a band query');
      base.Free;
      Finish(nil, 1);
      end;

   radio := TIcomRadio(base);

   { THROUGH THE BASE, DELIBERATELY.  TIcomRadio publishes RadioAddress as the
     CI-V ADDRESS (a Byte) and it shadows TFactoryRadioBase.radioAddress, the
     host string -- assigning a host to the unqualified name is a type error
     here, and would have been a SILENT one had the two types matched. }
   TFactoryRadioBase(radio).radioAddress := host;
   radio.radioPort := uRadioRegistry.RegisteredNetworkPort(model);
   radio.ApplyNetworkCredentials(user, pass);

   WriteLn(Format('Icom band-coverage probe -- %s at %s:%d',
                  [modelName, host, radio.radioPort]));
   WriteLn('READ-ONLY: this sends no command of its own and changes nothing.');
   WriteLn;
   WriteLn('Connecting ...');

   if radio.Connect <> 0 then
      begin
      WriteLn('FAIL: could not start the connection');
      Finish(radio, 1);
      end;

   { CONNECT ONLY STARTS THE HANDSHAKE.  Saying "connected" on the strength of
     its return value is how a run against a powered-off radio reaches a
     confident wrong conclusion.  Ask the strict signal instead. }
   if not radio.WaitForOperational(CONNECT_TIMEOUT_MS) then
      begin
      WriteLn('FAIL: the radio never completed its handshake.');
      WriteLn('  Check it is powered on, on the network, at the address given,');
      WriteLn('  and that TR4W is not already holding a session.');
      Finish(radio, 1);
      end;

   WriteLn('Link operational.  Waiting for the band query to answer ...');

   (* The driver's one-shot probe fires on the first $04/$26 the radio pushes,
     and $1E $00's count then queues one $1E $01 <n> per band.  Poll rather
     than sleep blind, so the console shows the ranges arriving. *)
   waited := 0;

   while waited < seconds do
      begin
      Sleep(1000);
      Inc(waited);
      WriteLn(Format('  t=%2d s   ranges reported: %d',
                     [waited, radio.CoverageRangeCount]));
      end;

   WriteLn;
   WriteLn('---- RESULT ------------------------------------------------------');
   WriteLn(Format('  transmit ranges reported by the radio : %d',
                  [radio.CoverageRangeCount]));

   if radio.CoverageRangeCount = 0 then
      begin
      WriteLn;
      WriteLn('  THIS RADIO DID NOT ENUMERATE ITS BANDS.');
      WriteLn('  That is a real answer, not a failure: the driver treats an empty');
      WriteLn('  coverage table as NO OPINION, so every band stays available.');
      WriteLn('  The log says which of $1E / $02 was NAKed and which went');
      WriteLn('  unanswered -- those are different findings.');
      end
   else
      begin
      WriteLn('  which of TR4W''s bands fall inside them:');
      covered := 0;

      for b := Succ(Low(TRadioBand)) to High(TRadioBand) do
         begin
         hz := RadioBandToFreq(b);

         if radio.CoversFrequency(hz) then
            begin
            Inc(covered);
            WriteLn(Format('    %-7s %13d Hz   YES', [BandLabel(b), hz]));
            end
         else
            begin
            WriteLn(Format('    %-7s %13d Hz   no', [BandLabel(b), hz]));
            end;
         end;

      WriteLn;
      WriteLn(Format('  %d band(s) of %d are workable on this radio.',
                     [covered, Ord(High(TRadioBand))]));
      WriteLn('  Band up/down and the driver''s band stepping both follow exactly');
      WriteLn('  this list -- see uRadioBand''s band-stepping block.');
      end;

   Finish(radio, 0);
end.
