{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 }
unit uRadioPolling;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  uConfigValues,
   //FmtBcd,
   LogDupe,
   VC,
   TF,
   uSpots,
   uNet,
   Tree,
   LogRadio,
   LogEdit,
   uDupeSheet, // 4.53.7
   uFunctionKeys,
   utils_file,
   MainUnit,
   Messages,
   SysUtils,
   LogWind,
   LogStuff,
   LogK1EA,
   idUDPClient, // ny4i 4.44.9
   idGlobal, // ny4i 4.44.9
   Windows,
   StrUtils,
   Math,
   DateUtils,
   uFactoryRadioBase,
   uRadioElecraftK4,
   uRadioHamLibDirect,
  uTR4WStrings;

type
   DebugFileMessagetype = (dfmTX, dfmRX, dfmError);

function ReadFromSerialPort(BytesToRead: Cardinal; rig: RadioPtr): boolean;
function ReadFromCOMPort(b: Cardinal; rig: RadioPtr): boolean;
function ReadFromCOMPortRaw(b: Cardinal; rig: RadioPtr): boolean;
procedure SetSerialRadioAlertState(rig: RadioPtr; alertOn: boolean);
procedure MarkSerialRead(rig: RadioPtr; success: boolean);
procedure pFactoryRadio(rig: RadioPtr);
function ArrayToString(const a: array of AnsiChar): string;

procedure UpdateStatus(rig: RadioPtr);
procedure ClearRadioPanel(rig: RadioPtr);
procedure ClearRadioStatus(rig: RadioPtr);

procedure BeginPolling(rig: RadioPtr); stdcall;
procedure DisplayCurrentStatus(rig: RadioPtr);
procedure ProcessFilteredStatus(rig: RadioPtr);
procedure PTTStatusChanged;
procedure SendRadioInfoToUDP(rig: RadioPtr);

type
   // What UpdateStatus decided on one poll cycle.  These are the only three
   // outcomes it has, and they are what the consumers downstream actually see.
   TRadioStatusEvent = (
      rseChanged,      // CurrentStatus differs from PreviousStatus -> display repainted
      rsePeriodic,     // unchanged, but the 10s UDP heartbeat forced a publish
      rseFiltered      // the settle cycle after a change -> FilteredStatus adopted it
      );

   // Observer for the status pipeline.  nil in the running program; assigned by
   // test/integration/tr4w_status_trace.lpr, which records the sequence of
   // events and dumps it as JSONL so two builds can be diffed.
   //
   // WHY A HOOK AND NOT A COPY OF UpdateStatus IN THE HARNESS.  The whole point
   // is to pin the behaviour of THIS routine across a refactor.  A harness that
   // reimplemented the byte-compare and the one-cycle debounce would pin its own
   // copy and pass even if this one changed -- which is the failure it exists to
   // prevent.  The cost in the shipping program is one nil test per poll cycle.
   TRadioStatusTraceProc = procedure(rig: RadioPtr; aEvent: TRadioStatusEvent);

   // Observer for "a coherent status has just been published".  nil in a
   // program with no state-broadcast consumer; assigned by the TCI server,
   // which diffs against what it last told its clients and broadcasts only
   // what changed.
   //
   // WHY A HOOK RATHER THAN THE CONSUMER POLLING.  A consumer that sampled on
   // its own timer would either lag the radio or re-read it needlessly, and it
   // would have no way to know whether two reads spanned a poll cycle.  The
   // poll loop already knows exactly when a coherent state exists; saying so
   // costs one nil test per cycle, the same price RadioStatusTrace pays.
   //
   // CONTRACT.  Called on the POLLING THREAD, and deliberately AFTER
   // EndStatusPublish -- see the batch boundary in pFactoryRadio.  An observer
   // must therefore (a) take its copy with ReadRadioStatus rather than reading
   // fields directly, and (b) never block: a slow observer delays the next
   // poll of that radio.  The TCI server satisfies (b) by only enqueueing.
   TRadioStatusPublishedProc = procedure(rig: RadioPtr);

var
   RadioStatusTrace: TRadioStatusTraceProc = nil;
   RadioStatusPublished: TRadioStatusPublishedProc = nil;

var
   saveVFOAFreq: integer;
   dtLastUDPRadio: TDateTime;
const
   POLLINGDEBUG = False;
   ICOM_DEBUG = False;

implementation

uses
  uRadioRegistry,   // RadioTypeToken -- the model name, from the factory
   uPanelUpdate,    // cross-thread panel writes -- the seam and why, in that unit
   uRadioState,     // PTT as STATE. This unit runs on the polling thread and
                    // must not name a control -- see the note in PTTStatusChanged
   uMainThreadWork; // the UI work below runs on the MAIN thread -- see MarshalledJobs

{ ===========================================================================
  THE UI WORK THAT USED TO RUN ON THIS THREAD.

  ProcessFilteredStatus runs on a radio's reading thread.  Two of the things it
  did from there are UI, and both are now requested rather than performed: the
  bodies below execute on the main thread, coalesced, via uMainThreadWork.

  A THIRD ONE IS DELIBERATELY NOT HERE.  The bandmap cursor block further down
  already does this correctly -- it sets a repaint token that the bandmap's own
  250 ms timer drains -- and it is the precedent both of these follow rather
  than something left undone.

  WHAT IS STILL WRONG, SO THAT NOBODY READS THIS AS FINISHED: this thread still
  writes ActiveBand, ActiveMode, BandMapCursorFrequency and rig.tPTTStatus
  directly and unsynchronised, and the main thread reads them.  Marshalling the
  DISPLAY calls does not address that, it is a separate defect, and it predates
  this change.
  =========================================================================== }

{ AUTO S&P -- the operator tuned the dial far enough to leave CQ mode.  One job
  rather than four requests because the steps are a sequence: the focus move at
  the end is only correct after the QSO has been reinitialised. }
procedure RunSwitchToSearchAndPounce;
begin
   SetOpMode(SearchAndPounceOpMode);
   tClearDupeInfoCall;
   ClearAltD; // 4.53.7
   initializeQSO; // 4.53.5
   Second := False;
      // n4af 4.46.7  first esc d/n clear call
   switchnext := False; // n4af issue  230
   tCallWindowSetFocus;  // 4.139.1
end;

{ The active radio changed band or mode.  Pure display refresh: ActiveBand and
  ActiveMode are already set by the time this runs, deliberately -- they are
  model state and moving them here would change WHEN the rest of the program
  sees a band change, which is not what this is for. }
procedure RunBandModeDisplay;
begin
   DisplayBandMode(ActiveBand, ActiveMode, False);

   DisplayCodeSpeed;
   DisplayAutoSendCharacterCount;
   VisibleLog.ShowRemainingMultipliers; //wli

   if QSONumberByBand then
      begin
      DisplayNextQSONumber;
      end;

   ShowFMessages(0);
end;

procedure pFactoryRadio(rig: RadioPtr); // Network classes (K4 network, Flex 6000 series network, etc)
var
   ro: TFactoryRadioBase;
   wasConnected: Boolean;
   loggedNoConnInfo: Boolean;   // Issue #968 -- log the "no IP/port" skip once, not every cycle
   reconnectDelay: Integer;
   sleepRemaining: Integer;
   lastPollTick: LongWord;
   lastHeartbeatTick: LongWord;
   lastRITXITTick: LongWord;
   authErrBuf: array[0..127] of AnsiChar;
   handshakeStuckSinceTick: LongWord;  // GetTickCount when we first noticed IsConnected but not IsOperational; 0 = not tracking
   actVFO: TVFO;                       // active (RX) VFO for the aggregate main-window status (ro.GetActiveVFO)
const
   RECONNECT_INITIAL_DELAY = 1000;    // 1 second initial delay
   RECONNECT_MAX_DELAY = 30000;       // 30 seconds max delay
   HANDSHAKE_STUCK_MS = 8000;         // Force a Disconnect+Connect cycle if the transport has been mid-handshake (IsConnected but not IsOperational) for this long.  Covers the "radio was off when Connect() fired, the initial AYH packet was lost, no further AYH retries are sent" failure mode -- without this the polling thread spins forever in the connected branch sending CI-V commands that fail with "stream not open".

   // SetRadioAlertState � set or clear RadioDisconnected flag and repaint freq/name
   // windows only on a state transition (guarded by current flag value).
   procedure SetRadioAlertState(alertOn: boolean);
   begin
      if alertOn = rig^.RadioDisconnected then
         begin
         Exit;   // No change � do not call InvalidateRect unnecessarily
         end;
      rig^.RadioDisconnected := alertOn;
      if alertOn then
         begin
         logger.Info('[pFactoryRadio] %s � alert color ON', [rig^.RadioName])
         end
      else
         begin
         logger.Info('[pFactoryRadio] %s � alert color OFF', [rig^.RadioName]);
         end;
      RequestMainThreadJob(mtMainWindowElementColors);
   end;

begin

   { Unlike the other polling procedures, all we have to do here is grab the
     radio parameters we need from network classes. We do not need to send any
     commands as the network class keeps up to date when anything on the radio
     changes. This is at least the way the K4 works. If other future network
     interfaces do not work that way, then the network class should poll on a
     timer so the net effect it appears that the network class just "has" the info.
     NY4I 27-Nov-2021
   }
   logger.Trace('[pFactoryRadio] Entering polling procedure');
   ro := rig^.tFactoryObject;
   wasConnected := False;
   lastPollTick := 0;
   lastHeartbeatTick := 0;
   lastRITXITTick := 0;
   reconnectDelay := RECONNECT_INITIAL_DELAY;
   handshakeStuckSinceTick := 0;
   loggedNoConnInfo := False;

   // Keep polling thread alive until stop is requested (e.g. on Reset Radio Ports)
   while not rig^.PollingStopRequested do
      begin
      try
         if ro.IsConnected then
            begin
            // Stuck-handshake detector: IsConnected is the loose "transport is doing
            // something" check that stays True throughout the multi-step Icom
            // handshake (WaitingForHere/WaitingForReady/WaitingForLogin/etc.).
            // If we sit in that limbo too long -- e.g. the radio was off when our
            // initial AYH packet was sent, and the transport doesn't auto-retry --
            // force a Disconnect so the else-branch fires Connect() again with
            // a fresh handshake.  Without this, the polling thread spins forever
            // in the connected branch sending CI-V commands that fail with
            // "stream not open" until the operator manually intervenes.
            //
            // Gated on CanRecycleOnStuckHandshake so we only force-recycle for
            // radios where it actually fixes things.  Flex returns False because
            // its IsOperational drops when SmartSDR closes (TCP is fine, slice
            // is gone) -- recycling TCP wouldn't help and would just churn.
            if (not ro.IsOperational) and ro.CanRecycleOnStuckHandshake then
               begin
               if handshakeStuckSinceTick = 0 then
                  begin
                  handshakeStuckSinceTick := GetTickCount
                  end
               else if (GetTickCount - handshakeStuckSinceTick) > HANDSHAKE_STUCK_MS then
                  begin
                  logger.Warn('[pFactoryRadio] %s handshake stuck (IsConnected but not IsOperational) for >%d ms; forcing Disconnect for retry',
                     [rig^.RadioName, HANDSHAKE_STUCK_MS]);
                  handshakeStuckSinceTick := 0;
                  try
                     ro.Disconnect;
                  except
                     on E: Exception do
                        begin
                        logger.Debug('[pFactoryRadio] Forced Disconnect raised: %s - %s', [E.ClassName, E.Message]);
                        end;
                  end;
                  // Brief sleep so the next iteration sees the new state cleanly,
                  // then loop -- the else-branch will reset wasConnected and
                  // schedule the reconnect via the existing backoff path.
                  Sleep(100);
                  Continue;
                  end;
               end
            else
               begin
               handshakeStuckSinceTick := 0;  // operational, or this radio doesn't recycle on stuck
               end;

            // Radio is connected - poll status
            if not wasConnected then
               begin
               logger.trace('[pFactoryRadio] Radio connected � querying initial freq/mode/state');
               wasConnected := True;
               reconnectDelay := RECONNECT_INITIAL_DELAY;  // Reset backoff on successful connection
               // Don't unconditionally clear the alert here -- IsConnected is
               // the loose "transport is doing something" check that stays True
               // throughout the multi-step Icom handshake (WaitingForHere etc.).
               // The IsOperational query below (and the per-iteration check at
               // line ~944) is the strict "fully connected" gate that drives
               // the alert color; clearing here would briefly turn the alert
               // off during reconnect even when the radio is unreachable.
               SetRadioAlertState(not ro.IsOperational);

               // For serial radios that poll frequency directly (K4/K3-style), honour the
               // user-configurable FREQUENCY POLL RATE (FreqPollRate, default 10ms, range
               // 10-1000ms). NOT for the Icom (honorsFreqPollRate=False): its PollRadioState
               // is a heavy multi-command CI-V state query (RIT/XIT/split/TX) and frequency
               // arrives via CI-V transceive, so a 10ms cadence enqueues ~500 CI-V cmds/sec
               // and permanently floods the rate-limited send queue (25ms/command) -- keep
               // the Icom's own 1s pollingInterval.
               if ro.requiresPolling and (ro.serialPort <> NoPort) and ro.honorsFreqPollRate then
                  begin
                  ro.pollingInterval := FreqPollRate;
                  logger.Debug('[pFactoryRadio] Serial polling interval set to %dms (FREQUENCY POLL RATE)',
                               [ro.pollingInterval]);
                  end;

               // Query freq and mode directly from the polling thread.
               // The OnInitialPollSeeding timer window is created on this thread, which has
               // no Win32 message pump (it only calls Sleep), so WM_TIMER is never dispatched
               // and the timer callback never fires. Querying here guarantees the display
               // updates on every connect/reconnect without the user needing to touch the VFO.
               if Assigned(ro) then
                  begin
                  logger.Debug('[pFactoryRadio] Querying initial freq/mode');
                  ro.QueryActiveVFO;      // $07 $D2 � must be first so FActiveVFO is set before mode routing
                  ro.QueryVFOAFrequency;
                  ro.QueryVFOBFrequency;
                  ro.QueryMode;           // $04 � active VFO mode ? routed to FActiveVFO slot
                  ro.QueryVFOAMode;       // $26 $00 � inactive VFO A mode (when VFO B is active)
                  ro.QueryVFOBMode;       // $26 $01 � VFO B mode + data mode
                  end;

               // Poll the remaining states that transceive does not push
               if Assigned(ro) and ro.requiresPolling then
                  begin
                  logger.Debug('[pFactoryRadio] Querying initial RIT/XIT/split/TX');
                  ro.PollRadioState;
                  end;

               // CW speed on initial connection:
               // - CWSpeedSync OFF: program is master � push CodeSpeed to radio so they agree.
               // - CWSpeedSync ON:  radio is master � do NOT push; leave the radio's speed alone.
               //   The $14 $0C query sent during connect will return ro.CWSpeed, and the
               //   polling loop below (ro.CWSpeed -> CodeSpeed sync) will apply it on the
               //   first cycle that sees a valid response.
               if not rig^.CWSpeedSync and (CodeSpeed >= 6) and Assigned(ro) then
                  begin
                  logger.Debug('[pFactoryRadio] CWSpeedSync off � pushing program speed %d WPM to radio', [CodeSpeed]);
                  ro.SetCWSpeed(CodeSpeed);
                  end;

               // StartupCommand: configured per-radio in the .cfg file, handed to
               // the radio object at construction and sent ONCE, here, because
               // this is where a network radio is first known to be connected --
               // its Connect returns before the link is up.  The once-only guard
               // now lives on the RADIO (TFactoryRadioBase.FStartupCommandSent),
               // not on the legacy RadioObject, so both transports share one
               // implementation and Reset Radio Ports still re-arms it by
               // rebuilding the radio.  Issue #436.
               end;

            // Deliberately OUTSIDE the "not wasConnected" block above.  The radio
            // holds the command for STARTUP_COMMAND_SETTLE_MS after the link comes
            // up, because a just-powered-on rig answers CAT before it is ready to
            // act on anything (bench-proven on a K3, 2026-08-01: sent at the first
            // good response and silently dropped, accepted on a Reset Radio Ports
            // seconds later).  That settle can only elapse if we keep asking, so
            // this runs every poll cycle.  SendStartupCommand self-guards, so it
            // is one boolean test once the command has gone out.
            if Assigned(ro) then
               begin
               ro.SendStartupCommand;
               end;

            // HamLib Direct: short sleep so FNeedsPoll is checked promptly when
            // an async callback fires. Legacy serial radios use FreqPollRate.
            if Assigned(ro) and (ro is THamLibDirect) then
               begin
               Sleep(50)
               end
            else
               begin
               Sleep(FreqPollRate);
               end;

            // Auth failure may happen asynchronously during handshake.
            // IsConnected can still be True if Disconnect couldn't complete
            // (Indy self-deadlock), so check AuthFailed explicitly.
            if Assigned(ro) and ro.AuthFailed then
               begin
               logger.Warn('[pFactoryRadio] Auth failed for %s - stopping', [rig^.RadioName]);
               StrPCopy(authErrBuf, rig^.RadioName + ': Auth failed - check credentials');
               QuickDisplayError(authErrBuf);
               if rig^.tRadioInterfaceWndHandle <> 0 then
                  begin
                  PostPanelText(rig^.tRadioInterfaceWndHandle, 130, 'AUTH FAILED');
                  end;
               Break;
               end;

            // HamLib Direct: drain user commands first on every cycle (max 50ms latency),
            // then poll when an async callback fired or the heartbeat interval elapsed.
            // Set HAMLIB ASYNC ONLY = TRUE in cfg to disable the heartbeat and only
            // poll on async callbacks � useful for testing whether transceive is working.
            if Assigned(ro) and (ro is THamLibDirect) then
               begin
               THamLibDirect(ro).DrainUrgentQueue;

               if InterlockedExchange(THamLibDirect(ro).FNeedsPoll, 0) <> 0 then
                  begin
                  if TR4W_HAMLIB_DEBUG then
                     begin
                     logger.Info('[pFactoryRadio] HamLib poll triggered by ASYNC callback');
                     end;
                  THamLibDirect(ro).SendPollRequests;
                  lastHeartbeatTick := GetTickCount;
                  end
               else if not TR4W_HAMLIB_ASYNC_ONLY and
                       (GetTickCount - lastHeartbeatTick >= LongWord(ro.pollingInterval)) then
                  begin
                  if TR4W_HAMLIB_DEBUG then
                     begin
                     logger.Info('[pFactoryRadio] HamLib poll triggered by HEARTBEAT (%dms)',
                                 [ro.pollingInterval]);
                     end;
                  THamLibDirect(ro).SendPollRequests;
                  lastHeartbeatTick := GetTickCount;
                  end;

               // RIT/XIT slow poll � every 5000ms independently of the main heartbeat.
               // rig_get_rit/xit trigger $07 D0 side-effects in HamLib's Icom driver
               // which dismiss front-panel menus; polling infrequently keeps them usable.
               if GetTickCount - lastRITXITTick >= 5000 then
                  begin
                  THamLibDirect(ro).SendRITXITPoll;
                  lastRITXITTick := GetTickCount;
                  end;
               end
            // For radios that require active polling (Icom, etc.), call PollRadioState
            // Throttled by pollingInterval (e.g. 500ms for network Icom)
            else if Assigned(ro) and ro.requiresPolling then
               begin
               if (GetTickCount - lastPollTick >= LongWord(ro.pollingInterval)) then
                  begin
                  // MEASURED, K3S over serial at 38400, 2026-08-09, with a
                  // standalone harness (tools/k3watch.py) so TR4W was not in
                  // the path.  Command -> the radio REPORTING the new state:
                  //
                  //   poll during TX          TX; ->tx    RX; ->rx
                  //   IF; only, paced         125-146 ms   88-124 ms
                  //   4 commands, paced*      406 ms       672 ms
                  //   4 commands, waiting
                  //     for EVERY reply       282 ms       609 ms
                  //   (*released on the first reply -- what the gate below does)
                  //
                  // Read the last two rows together: waiting for every reply
                  // instead of the first buys 63 ms.  The 500 ms between row 1
                  // and row 3 is the radio's own CAT processing, and the only
                  // variable is how many commands it was asked for -- roughly
                  // 125 ms per command WHILE TRANSMITTING.  An unkey waits
                  // behind whatever is already in the radio's buffer, and no
                  // amount of pacing changes what is already there.
                  //
                  // So this gate is worth having and worth NOT extending: it
                  // stops backlog growing without bound, which is what turned a
                  // 100 ms unkey into 1200 ms.  Making it wait for the last
                  // reply of a multi-command poll was measured and rejected --
                  // 63 ms, in exchange for every driver having to declare how
                  // many replies its poll expects, which Icom CI-V and the
                  // binary Yaesus cannot cleanly answer.
                  //
                  // The lever that DOES work is asking for less while
                  // transmitting, and that is a question about what the
                  // operator can change mid-transmission, not a tuning knob.
                  // Reducing the Elecraft poll to 'IF;' was tried and reverted:
                  // the operator can move VFO B while the radio is transmitting
                  // (NY4I), so a poll that cannot see it shows a frequency the
                  // radio is not on.
                  //
                  // ONE OUTSTANDING POLL AT A TIME.  This loop used to fire every
                  // pollingInterval regardless of whether the radio had answered
                  // the last one, so a radio slower than the interval piled up
                  // backlog in its OWN CAT input buffer -- and a radio gets
                  // slower exactly when it is transmitting.  A K3S measured on
                  // the bench unkeyed in 99 ms when paced and 820 ms when flooded
                  // at this loop's rate: the RX; was queued behind poll commands
                  // we had already sent.  See TFactoryRadioBase.PollOutstanding.
                  if ro.PollOutstanding then
                     begin
                     // Skip this cycle.  Deliberately WITHOUT touching
                     // lastPollTick, so the next poll goes the instant the radio
                     // answers rather than waiting out another whole interval.
                     end
                  else
                     begin
                     ro.MarkPollSent;
                     ro.PollRadioState;
                     lastPollTick := GetTickCount;
                     end;
                  end;
               end;

            // Aggregate "main window" status follows the active (RX/operating) VFO.
            // Swap-model radios (K4) return nrVFOA from GetActiveVFO -- unchanged
            // from before. Selectable-model radios (Kenwood FR, Flex) return the
            // receiving VFO, so the main window tracks A/B selection on the radio.
            actVFO := ro.GetActiveVFO;

            // THE BATCH BOUNDARY.  Everything from here to EndStatusPublish below
            // -- the whole CurrentStatus fill and the FilteredStatus copy inside
            // UpdateStatus -- is one coherent update as far as a reader is
            // concerned.  Bracketing only the fill would publish a CurrentStatus
            // that FilteredStatus had not caught up with yet, which is precisely
            // the mismatch a snapshot is supposed to make impossible.
            // try/finally is load-bearing, not defensive habit.  Everything below
            // reads properties off a live radio object and calls the logger; if any
            // of that raised, the version would be left ODD permanently and every
            // reader would spin its full retry budget on every call, for the rest
            // of the session.  An unbalanced seqlock does not fail loudly -- it
            // quietly degrades to "always contended".
            BeginStatusPublish(rig);
            try
            rig^.CurrentStatus.Freq := ro.frequency[actVFO];
            rig^.CurrentStatus.Band := GetTR4WBandFromNetworkBand(ro.band[actVFO]);
            GetTRModeAndExtendedModeFromNetworkMode(ro.mode[actVFO],rig^.CurrentStatus.Mode,rig^.CurrentStatus.ExtendedMode);
            rig^.CurrentStatus.RITFreq :=  ro.RITOffset[actVFO];
            rig^.CurrentStatus.Split := ro.IsSplitEnabled;
            rig^.CurrentStatus.RIT := ro.IsRITOn[actVFO];
            rig^.CurrentStatus.XIT := ro.IsXITOn[actVFO];
            rig^.CurrentStatus.TXOn := ro.IsTransmitting;
            if actVFO = nrVFOB then
               begin
               rig^.CurrentStatus.VFOStatus := VFOB
               end
            else
               begin
               rig^.CurrentStatus.VFOStatus := VFOA;
               end;

            // VFO A
            rig.CurrentStatus.VFO[VFOA].Frequency := ro.frequency[nrVFOA];
            GetTRModeAndExtendedModeFromNetworkMode(ro.mode[nrVFOA],rig.CurrentStatus.VFO[VFOA].Mode,rig.CurrentStatus.VFO[VFOA].ExtendedMode);
            rig.CurrentStatus.VFO[VFOA].RIT := ro.IsRITOn[nrVFOA];
            rig.CurrentStatus.VFO[VFOA].XIT := ro.IsXITOn[nrVFOA];
            rig.CurrentStatus.VFO[VFOA].RITFreq := ro.RITOffset[nrVFOA];
            rig.CurrentStatus.VFO[VFOA].Band := GetTR4WBandFromNetworkBand(ro.band[nrVFOA]);
            rig.CurrentStatus.Band := GetTR4WBandFromNetworkBand(ro.band[actVFO]);  // aggregate band follows active VFO

            // VFO B
            rig.CurrentStatus.VFO[VFOB].Frequency := ro.frequency[nrVFOB];
            GetTRModeAndExtendedModeFromNetworkMode(ro.mode[nrVFOB],rig.CurrentStatus.VFO[VFOB].Mode,rig.CurrentStatus.VFO[VFOB].ExtendedMode);
            rig.CurrentStatus.VFO[VFOB].RIT := ro.IsRITOn[nrVFOB];
            rig.CurrentStatus.VFO[VFOB].XIT := ro.IsXITOn[nrVFOB];
            rig.CurrentStatus.VFO[VFOB].RITFreq := ro.RITOffset[nrVFOB];
            rig.CurrentStatus.VFO[VFOB].Band := GetTR4WBandFromNetworkBand(ro.band[nrVFOB]);

            // Sync CW speed from radio ? program (active radio only, when CWSpeedSync enabled)
            // Only the active radio should update CodeSpeed � in SO2R, the inactive radio
            // may have a different speed and would otherwise fight the active radio.
            if rig^.CWSpeedSync and (ro.CWSpeed > 0) and (ro.CWSpeed <> CodeSpeed)
               and (rig = ActiveRadioPtr) then
               begin
               logger.Info('[pFactoryRadio] CWSpeedSync: radio speed %d WPM -> CodeSpeed', [ro.CWSpeed]);
               CodeSpeed := ro.CWSpeed;
               DisplayCodeSpeed;  // Refreshes display and persists to SpeedMemory
               end;

            // HamLib Direct skips this � SendPollRequests already logs individual values.
            if TR4W_HAMLIB_DEBUG and not (ro is THamLibDirect) then
               begin
               logger.Info('[pFactoryRadio:%s] pre-UpdateStatus: VFOA=%d VFOB=%d split=%s VFOStatus=%d',
                  [rig^.RadioName,
                   rig.CurrentStatus.VFO[VFOA].Frequency,
                   rig.CurrentStatus.VFO[VFOB].Frequency,
                   BoolToStr(rig.CurrentStatus.Split, True),
                   Ord(rig.CurrentStatus.VFOStatus)]);
               end;

            // Check operational state (e.g. Flex slice 0 validity).
            // TCP may be up while slices are gone (SmartSDR closed); alert in that case too.
            SetRadioAlertState(not ro.IsOperational);

            UpdateStatus(rig);
            finally
            EndStatusPublish(rig);
            end;

            // Announce the freshly-published state to any state-broadcast
            // consumer.  OUTSIDE the seqlock on purpose: an observer calls
            // ReadRadioStatus, and inside the window the version is odd, so it
            // would spin its whole retry budget and then hand back a copy it
            // knows may be torn.
            if Assigned(RadioStatusPublished) then
               begin
               RadioStatusPublished(rig);
               end;
            end
      else
         begin
         // Radio disconnected - attempt reconnection
         SetRadioAlertState(True);  // TCP disconnected
         if wasConnected then
            begin
            logger.Info('[pFactoryRadio] Radio disconnected, will attempt reconnection');
            wasConnected := False;
            // Re-arm the startup command.  The reconnect below comes back
            // through the `if not wasConnected` transition, which calls
            // SendStartupCommand -- and that self-guards, so without this the
            // command would never be re-sent for the life of the radio object.
            //
            // Re-armed HERE, at the drop, rather than at the reconnect: this is
            // the one place both transports agree the link went away, and doing
            // it here cannot double-send at startup, where there is no prior
            // drop to react to.
            if Assigned(ro) then
               begin
               ro.RearmStartupCommand;
               end;
            // Zero freq in both Current and Previous status.
            // Current: so the display shows blank, not a stale reading.
            // Previous: so UpdateStatus detects a real change when reconnect brings the
            //           actual frequency back (if only Current were zeroed, a reconnect
            //           at the same frequency would produce no StatusChanged event).
            rig.CurrentStatus.Freq := 0;
            rig.CurrentStatus.VFO[VFOA].Frequency := 0;
            rig.CurrentStatus.VFO[VFOB].Frequency := 0;
            rig.PreviousStatus.Freq := 0;
            rig.PreviousStatus.VFO[VFOA].Frequency := 0;
            rig.PreviousStatus.VFO[VFOB].Frequency := 0;
            // Blank the frequency display immediately. FreqToPChar(0) shows "0.000"
            // which is as misleading as the stale value, so write '' directly.
            PostElementText(rig^.FreqElement, '');
            if rig^.tRadioInterfaceWndHandle <> 0 then
               begin
               PostPanelText(rig^.tRadioInterfaceWndHandle, 102, '');
               PostPanelText(rig^.tRadioInterfaceWndHandle, 104, '');
               end;
            reconnectDelay := RECONNECT_INITIAL_DELAY;  // Reset backoff on new disconnect
            end;

         // Serial radio recovery.  A serial radio "disconnects" because it stopped
         // answering (powered off, cable bump).  Keep the keep-alive poll running
         // -- it lives in the connected branch above, so without this the radio
         // window would stay "lost" forever -- and when the radio replies the
         // reading thread re-stamps liveness and the next iteration clears the
         // alert.  This restores what the legacy serial path had (MarkSerialRead).
         //
         // BUT polling alone is not enough, and the original comment here claimed
         // it was: "the COM port is still open, so there is nothing to reconnect".
         // Bench-disproven on the FT-1000MP (2026-07-27) -- power-cycle the radio
         // and the port stays perfectly healthy (no read exception, every write
         // accepted, polls going out) while the radio answers NOTHING, because a
         // CAT interface that lost power with the radio is only re-initialised
         // when the port is OPENED.  So after a spell of silence, reopen it.
         // Throttled with a backoff: a radio that is simply switched off must not
         // cause the port to be hammered open and closed.
         // Network radios (serialPort = NoPort) fall through to the reconnect path.
         if Assigned(ro) and (ro.serialPort <> NoPort) then
            begin
            if ro.requiresPolling and
               (GetTickCount - lastPollTick >= LongWord(ro.pollingInterval)) then
               begin
               ro.PollRadioState;
               lastPollTick := GetTickCount;
               end;

            // The RADIO owns its link recovery -- throttle, backoff and the
            // decision to reopen all live in TFactoryRadioBase.MaintainSerialLink.
            // This loop only ticks it, so no recovery state leaks into the legacy
            // polling unit.
            ro.MaintainSerialLink;

            Sleep(100);   // cadence + CPU-friendly; recovery seen on next IsConnected check
            Continue;
            end;

         // If auth failed, show error and stop reconnecting
         if Assigned(ro) and ro.AuthFailed then
            begin
            logger.Warn('[pFactoryRadio] Authentication failed for %s - not retrying', [rig^.RadioName]);
            StrPCopy(authErrBuf, rig^.RadioName + ': Auth failed - check credentials');
            QuickDisplayError(authErrBuf);
            if rig^.tRadioInterfaceWndHandle <> 0 then
               begin
               PostPanelText(rig^.tRadioInterfaceWndHandle, 130, 'AUTH FAILED');
               end;
            Break;
            end;

         // Attempt to reconnect with exponential backoff.
         // Sleep in short intervals so PollingStopRequested is checked promptly
         // during shutdown (otherwise a 30s sleep blocks ExitProgram).
         sleepRemaining := reconnectDelay;
         while (sleepRemaining > 0) and (not rig^.PollingStopRequested) do
            begin
            if sleepRemaining > 250 then
               begin
               Sleep(250);
               end
            else
               begin
               Sleep(sleepRemaining);
               end;
            Dec(sleepRemaining, 250);
            end;
         if rig^.PollingStopRequested then
            begin
            Break;
            end;

         // Issue #968 -- a network radio with no IP address or a 0 TCP port has
         // nothing to connect to.  ro.Connect would just return -1 every cycle
         // (the port=0 / address=0 guards in TFactoryRadioBase.Connect) and flood the
         // log once per second.  Idle quietly until the operator supplies the
         // connection info; log the reason once so it is still discoverable.
         if (rig^.RadioTCPPort = 0) or (Length(rig^.IPAddress) = 0) then
            begin
            if not loggedNoConnInfo then
               begin
               logger.Warn('[pFactoryRadio] %s has no IP address/TCP port configured -- not attempting to connect until set',
                  [rig^.RadioName]);
               loggedNoConnInfo := True;
               end;
            Continue;
            end;
         loggedNoConnInfo := False;

         try
            logger.Info('[pFactoryRadio] Reconnection attempt (delay: %dms)', [reconnectDelay]);
            ro.Connect;

            // Connect only initiates the handshake (sends AYH for Icom, opens TCP for K4).
            // IsConnected will be True on the next loop iteration once the handshake completes.
            // The connected branch (above) handles initial polling and CW speed sync at that point.
         except
            on E: Exception do
               begin
               logger.Debug('[pFactoryRadio] Reconnection failed: %s - %s', [E.ClassName, E.Message]);
               // Exponential backoff: double the delay, cap at max
               reconnectDelay := reconnectDelay * 2;
               if reconnectDelay > RECONNECT_MAX_DELAY then
                  begin
                  reconnectDelay := RECONNECT_MAX_DELAY;
                  end;
               end;
         end;
         end;
      except
         on E: EAbstractError do
            begin
            logger.Error('[pFactoryRadio] ABSTRACT ERROR: %s at address %p', [E.Message, ExceptAddr]);
            logger.Error('[pFactoryRadio] This indicates a missing method implementation in the radio class');
            raise;  // Re-raise so user sees the dialog
            end;
         on E: Exception do
            begin
            logger.Error('[pFactoryRadio] Exception in polling loop: %s - %s', [E.ClassName, E.Message]);
            Sleep(1000);  // Avoid tight loop on repeated errors
            end;
      end;  // end of try-except
      end;  // end of while True loop iteration

end;

function ReadFromSerialPort(BytesToRead: Cardinal; rig: RadioPtr): boolean;
var
   BytesRead: Cardinal;
  // s: string;
begin
   Result := False;
   if BytesToRead > SizeOf(rig^.tBuf) then
      begin
      Exit;
      end;

   if Windows.ReadFile(rig.tCATPortHandle, rig^.tBuf, BytesToRead, BytesRead, nil
      {rig^.pOver}) then
      if BytesToRead = BytesRead then
         begin
         Result := True;
         end;
   if logger.IsTraceEnabled then
      begin
      logger.trace('[ReadFromSerialPort] Read %s from serial port',[String2Hex(AnsiLeftStr(ArrayToString(rig^.tBuf),BytesRead))]);
      end;

end;

{ Blank a radio panel that no longer has a radio behind it.

  ZEROING THE STATUS IS NOT ENOUGH, and the reason is the flicker guard.
  DisplayCurrentStatus only writes a field when its value DIFFERS from the
  previous one -- which is right, and is why the panel does not flicker at ten
  updates a second. But ClearRadioStatus zeroes CURRENT and PREVIOUS together,
  so the painter sees no change, writes nothing, and the panel keeps the
  departed radio's frequencies for ever.

  NY4I saw exactly that on 2026-08-31: a profile whose Radio 2 is (none), a
  panel correctly re-titled "Radio 2", and 14022.54 still sitting in VFO A.

  The ids are the same five DisplayCurrentStatus writes. Blanking a field it
  does not write would leave one this routine empties and nothing refills. }
procedure ClearRadioPanel(rig: RadioPtr);
begin
   { The handle is read from the radio each time rather than held in an HWND
     local. Lint-Win32Dialogs counts the TYPE, and this routine adds no Win32
     surface -- the same PostPanelText the painter already uses. A baseline
     raised for a variable is a baseline raised for nothing. }
   if rig.tRadioInterfaceWndHandle <> 0 then
      begin
      PostPanelText(rig.tRadioInterfaceWndHandle, 102, '');   // VFO A
      PostPanelText(rig.tRadioInterfaceWndHandle, 104, '');   // VFO B
      PostPanelText(rig.tRadioInterfaceWndHandle, 105, '');
      PostPanelText(rig.tRadioInterfaceWndHandle, 106, '');
      PostPanelText(rig.tRadioInterfaceWndHandle, 120, '');   // RIT
      end;

   { The main window's frequency row -- HANDED OVER, not written, because this
     is reachable from the polling thread. See uPanelUpdate. }
   PostElementText(rig^.FreqElement, '');
end;

procedure ClearRadioStatus(rig: RadioPtr);
begin
   logger.debug('Entered ClearRadioStatus');
   {
     if rig.FilteredStatus.TXOn then
     begin
       tPTTStatus := PTT_OFF;
       PTTStatusChanged;
     end;
   }
   Windows.ZeroMemory(@rig^.CurrentStatus, SizeOf(rig^.CurrentStatus));
   Windows.ZeroMemory(@rig^.FilteredStatus, SizeOf(rig^.FilteredStatus));
   rig.CurrentStatus.Mode := NoMode;
   rig.FilteredStatus.Mode := NoMode;
   rig.LastDisplayedFreq := 0;
end;

procedure UpdateStatus(rig: RadioPtr);
var
   StatusChanged: boolean;
begin
  //  logger.Trace('UpdateStatus called for %s', [rig.RadioName]);
   // Was a byte scan over SizeOf(RadioStatusRecord), which also compared the
   // record's alignment padding -- memory no field owns.  It happened to work,
   // and it is one managed field away from reporting a change on every poll
   // forever.  LogRadio.RadioStatusDiffers compares named fields; the reasoning
   // is on its declaration and test/unit/uTestRadioStatus.pas pins it.
   //
   // Equivalence was not assumed: test/integration/run-status-trace.ps1 records
   // every decision this routine makes, and the trace is byte-identical across
   // the swap.
   StatusChanged := RadioStatusDiffers(rig.CurrentStatus, rig.PreviousStatus);

   //if StatusChanged = True then
   if (StatusChanged) or
      ((UDPBroadcastRadio) and (SecondsBetween(Now, dtLastUDPRadio) > 10) ) then
      begin
      if Assigned(RadioStatusTrace) then
         begin
         // Distinguish the two reasons for taking this branch: a real state
         // change, versus the 10-second UDP heartbeat republishing an
         // unchanged status.  A trace that conflated them would look
         // different every run purely because of wall-clock timing.
         if StatusChanged then
            begin
            RadioStatusTrace(rig, rseChanged);
            end
         else
            begin
            RadioStatusTrace(rig, rsePeriodic);
            end;
         end;
      DisplayCurrentStatus(rig); // Update the Radio Window only
      rig.FilteredStatusChanged := True;
      end
   else
      begin
      if rig.FilteredStatusChanged then
         begin
         rig.FilteredStatus := rig.CurrentStatus;
         if Assigned(RadioStatusTrace) then
            begin
            RadioStatusTrace(rig, rseFiltered);
            end;
         ProcessFilteredStatus(rig);
         rig.FilteredStatusChanged := False;
         end;
      end;
   rig.PreviousStatus := rig.CurrentStatus;
end;

procedure ProcessFilteredStatus(rig: RadioPtr);
var
   dif: integer;
begin
   if rig.CurrentStatus.Mode = CW then
      if IsCWByCATActive(rig) then
         begin
         // Latch that the radio really is transmitting.  Without this, the
         // TX-off test below races the rig: the keyer abort TR4W sends before
         // a message is 'KY <abort>;RX;', which puts the radio in RECEIVE, and
         // the message follows within milliseconds -- so a poll arriving
         // before the rig keys up reports TX off and the message is declared
         // finished before it began.  Bench, NY4I 2026-08-01: an F4 armed a
         // 4622 ms window at 38.298 and the poll thread cleared it at 38.466,
         // 168 ms later, firing tStartAutoCQ and resuming polling straight
         // into the keying.  The operator heard no CW.
         if rig.FilteredStatus.TXOn then
            begin
            rig.CWByCAT_SawTX := True;
            end;
         // Only believe "TX off means done" once we have SEEN it transmit.
         // A radio that cannot report TX status never sets the latch and is
         // ended by tmrCWByCAT instead -- which is what it already relied on.
         if (not rig.FilteredStatus.TXOn) and rig.CWByCAT_SawTX then
            begin
            if rig.CWByCAT_Sending then
               // ny4i Moved under this If to only perform when we are sending
               begin
               logger.trace('rig.CWByCAT_Sending set to FALSE - %s (%s)',
                        [rig.RadioName, RadioTypeToken(rig.RadioModel)]);
                     rig.tmrCWByCAT.Enabled := false;
                        // ny4i Issue 153 Disable timer so we do not fire if we get the this event here
                     //BackToInactiveRadioAfterQSO; // Moved to Timer event // ny4i Issue 153 We have to try here as WK and Serial do it in their threads when not busy
                     rig.CWByCAT_Sending := false;
                     if rig.CheckAutoCallTerminate then
                        begin
                        DebugMsg('rig.CheckAutoCallTerminate is true - Enter ReturnInCQMode');
                        ReturnInCQOpMode;
                        end;
               end;
            end;
         end;
   // move location of variable dif assignment so it is used for both active and inactive radios K0TI 12/19/2020
   dif := Abs(rig.FilteredStatus.Freq - rig.LastDisplayedFreq);
   if rig = ActiveRadioPtr then
      begin
      if rig.LastDisplayedFreq <> 0 then
         if dif > AutoSAPEnableRate then
            if dif <= 10000 then
               if AutoSAPEnable and
                  // Issue #795 vs bandmap: #795 made a MANUAL dial QSY clear
                  // the call/exchange in S&P.  But a COMMANDED QSY (bandmap
                  // double-click, spot click, typed freq) also moves the VFO
                  // and may have just placed a call -- don't clobber it.
                  // SetRadioFreq records the commanded VFO-A freq; treat this
                  // as a manual tune (and clear) only if we landed FAR from
                  // the last commanded freq.
                  (Abs(rig.FilteredStatus.Freq - rig.tCommandedQSYFreq) > AutoSAPEnableRate) then // n4af 4.44.10
                 // if OpMode = CQOpMode then    // 4.139.3
                  begin
                  // Was seven statements inline on THIS thread.  See
                  // RunSwitchToSearchAndPounce at the top of the
                  // implementation for what they are and why they moved.
                  RequestMainThreadJob(mtSwitchToSearchAndPounce);
                  end;
      if rig.CurrentStatus.TxOn then
         begin
         rig.tPTTStatus := PTT_ON;
         end
      else
         begin
         rig.tPTTStatus := PTT_OFF;
         end;
      pTTStatusChanged;
      if rig.FilteredStatus.Freq = 0 then
         begin
         Exit;
         end;
      if rig.FilteredStatus.Band = NoBand then
         begin
         logger.debug('ProcessFilteredStatus:Radio %s] rig.FilteredStatus.Band = NoBand', [rig.RadioName]);
         logger.debug('ProcessFilteredStatus:Radio %s] rig.FilteredStatus.freq = %d', [rig.RadioName,rig.FilteredStatus.Freq]);
         end;
      logger.Trace('[ProcessFilteredStatus] rig=%s, ' +
                   'BandMemory=%d, FS.Band=%d, ' +
                   'ModeMemory=%d, FS.Mode=%d, ' +
                   'FS.Freq=%d, ActiveBand(before)=%d, ActiveMode(before)=%d',
                   [rig.RadioName, Ord(rig.BandMemory), Ord(rig.FilteredStatus.Band),
                    Ord(rig.ModeMemory), Ord(rig.FilteredStatus.Mode),
                    rig.FilteredStatus.Freq, Ord(ActiveBand), Ord(ActiveMode)]);
      // Guard: NoBand/NoMode are sentinels meaning "not yet reported by radio".
      // Never propagate them into ActiveBand/ActiveMode; they would corrupt the
      // bandmap, dupe sheet, and multiplier displays until the next valid poll.
      if (rig.FilteredStatus.Band <> NoBand) and
         (rig.FilteredStatus.Mode <> NoMode) and
         ((rig.BandMemory <> rig.FilteredStatus.Band) or
          (rig.ModeMemory <> rig.FilteredStatus.Mode)) then
         begin
         // INFO, not trace: this is the ONE place the main window's band
         // and mode change, and when the display jumps the first question
         // is always "which radio said so, and off what frequency".  A
         // trace-level line does not answer it, because nobody is running
         // at trace when the glitch happens (NY4I, 2026-08-08: a corrupt
         // CI-V frame moved the band mid-QSO and only the raw hex dump
         // could explain it afterwards).
         logger.Info('[Band/Mode] %s -> band %d->%d, mode %d->%d, at %d Hz',
                     [rig.RadioName,
                      Ord(ActiveBand), Ord(rig.FilteredStatus.Band),
                      Ord(ActiveMode), Ord(rig.FilteredStatus.Mode),
                      rig.FilteredStatus.Freq]);
         ActiveBand := rig.FilteredStatus.Band;
         ActiveMode := rig.FilteredStatus.Mode;
         VisibleDupeSheetChanged := True;

         // The six display calls that were here run on the main thread now --
         // see RunBandModeDisplay.  The two assignments above stay put: they
         // are model state, not display, and deferring them would change when
         // the rest of the program sees the band change.
         RequestMainThreadJob(mtBandModeDisplay);
         end;

      if ((dif > 0) and ((rig.FilteredStatus.Freq <> BandMapCursorFrequency)
         or (BandMapMode <> ActiveMode)) and (rig.FilteredStatus.Freq <> 0)) then
         // Gav 4.47.4 #015
         begin
         SpotsList.DisplayCallsignOnThisFreq(rig.FilteredStatus.Freq);
         BandMapCursorFrequency := rig.FilteredStatus.Freq;
         BandMapBand := ActiveBand;
         BandMapMode := ActiveMode;
         SpotsList.RequestRepaint; // the VFO moved -- a VIEW change, not a list change; coalesced via the 250ms timer � avoids flash on every VFO poll
         end;
      end
   else
      begin // Inactive Radio Processing

      if TuneDupeCheckEnable then
         begin
         SpotsList.TuneDupeCheck(rig.FilteredStatus.Freq);
         end;

      if (rig.BandMemory <> rig.FilteredStatus.Band) or (rig.ModeMemory <>
         rig.FilteredStatus.Mode) then
         begin
         InActiveRadioPtr.UpdateBandOutputInfo(rig.FilteredStatus.Band,
            rig.FilteredStatus.Mode);
         end;

      //GAV added this section. Changes BandmapBand & Bandmap Mode to follow inactive radio when inactive radio is tuned

      // Issue #908: gate the "follow inactive radio" feature on Config.TwoRadioMode.
      // The legacy LOGWIND.PAS path checked TwoRadioState <> TwoRadiosDisabled;
      // this Gav-added polling path forgot the SO2R gate, so an inactive radio
      // could mutate the bandmap even with TWO RADIO MODE=FALSE.
      //
      // Guard: also skip if the inactive radio has not yet reported real
      // band/mode (NoBand/NoMode are uninitialized sentinels), which would
      // otherwise blank the active radio's bandmap on first poll.
      if Config.TwoRadioMode and
         (rig.FilteredStatus.Band <> NoBand) and
         (rig.FilteredStatus.Mode <> NoMode) and
         (dif > 0) and
         ((rig.FilteredStatus.Freq <> BandMapCursorFrequency) or
          (BandMapMode <> ActiveMode)) and
         (rig.FilteredStatus.Freq <> 0) then
         // Gav 4.47.4 #015
         begin
         BandmapBand := rig.FilteredStatus.Band;
         BandMapMode := rig.FilteredStatus.Mode;
         VisibleDupeSheetChanged := True;
         BandMapCursorFrequency := rig.FilteredStatus.Freq;
         SpotsList.RequestRepaint; // the VFO moved -- a VIEW change, not a list change; coalesced via the 250ms timer � avoids flash on every VFO poll
         end;

      //GAV End of added

      end;
{$IF tDebugMode}
   {
     if boolean(tPTTStatus) <> rig.FilteredStatus.TXOn then
     begin
       tPTTStatus := PTTStatusType(rig.FilteredStatus.TXOn);
       PTTStatusChanged;
     end;
   }
{$IFEND}
   rig.BandMemory := rig.FilteredStatus.Band;
   rig.ModeMemory := rig.FilteredStatus.Mode;
   rig.LastDisplayedFreq := rig.FilteredStatus.Freq;

end;

procedure DisplayCurrentStatus(rig: RadioPtr);
var
   h: HWND;
   //fa: integer;
begin
   //logger.Debug('Entering DisplayCurrentStatus');
   if rig = ActiveRadioPtr then
      begin
      SendStationStatus(sstBandModeFreq);
      end;
   if UDPBroadcastRadio then
      begin
      SendRadioInfoToUDP(rig); // ny4i 4.44.9 // Broadcast Radio Info if set
      end;
   //Windows.SetWindowTextA(rig^.FreqWindowHandle, FreqToPChar(rig.CurrentStatus.Freq));
   h := rig.tRadioInterfaceWndHandle;
   //if h = 0 then Exit;
   //tSetWindowRedraw(h,false);
   if rig.CurrentStatus.VFO[VFOA].Frequency <>
      rig.CurrentStatus.previousVFO[VFOA].Frequency then
      begin
      if TR4W_HAMLIB_DEBUG then
         begin
         logger.Info('[DisplayCurrentStatus:%s] VFOA display update: %d ? %d',
            [rig^.RadioName,
             rig.CurrentStatus.previousVFO[VFOA].Frequency,
             rig.CurrentStatus.VFO[VFOA].Frequency]);
         end;
      if h <> 0 then
         begin
         PostPanelText(h, 102,
            string(FreqToPChar(rig.CurrentStatus.VFO[VFOA].Frequency)));
         end;
      // HANDED OVER, NOT WRITTEN.  This runs on the polling thread and the
      // frequency row is an LCL control; see uPanelUpdate.puElement.
      PostElementText(rig^.FreqElement, string(FreqToPChar(rig.CurrentStatus.Freq)));
      end
   else
      begin
      rig.CurrentStatus.previousVFO[VFOA].Frequency :=
         rig.CurrentStatus.VFO[VFOA].Frequency;
      end;
   (*fa := rig.CurrentStatus.VFO[VFOA].Frequency;    // This is so pointless updates do not flicker.
   if fa <> saveVFOAFreq then                      // We need a changed flag so we can check them all.
      begin
      if h <> 0 then
         begin
         SetDlgItemTextA(h, 102, FreqToPChar(fa));
         end;
      PostElementText(rig^.FreqElement, string(FreqToPChar(rig.CurrentStatus.Freq)));
      end
   else
      begin
      saveVFOAFreq := fa;
      end;
      *)
   if rig.CurrentStatus.VFO[VFOB].Frequency <>
      rig.CurrentStatus.previousVFO[VFOB].Frequency then
      begin
      if TR4W_HAMLIB_DEBUG then
         begin
         logger.Info('[DisplayCurrentStatus:%s] VFOB display update: %d ? %d',
            [rig^.RadioName,
             rig.CurrentStatus.previousVFO[VFOB].Frequency,
             rig.CurrentStatus.VFO[VFOB].Frequency]);
         end;
      if h <> 0 then
         begin
         PostPanelText(h, 104,
            string(FreqToPChar(rig.CurrentStatus.VFO[VFOB].Frequency)));
         end;
      //Windows.SetWindowTextA(rig^.FreqWindowHandle, FreqToPChar(rig.CurrentStatus.Freq));
      end
   else
      begin
      rig.CurrentStatus.previousVFO[VFOB].Frequency :=
         rig.CurrentStatus.VFO[VFOB].Frequency;
      end;
   //tSetWindowRedraw(h,true);
   //UpdateWindow(h);
  // ActiveRadioPtr.tPTTStatus :=
   if rig.CurrentStatus.TXOn then
      begin
      ActiveRadioPtr.tPTTStatus := PTT_ON;
      end
   else
      begin
      ActiveRadioPtr.tPTTStatus := PTT_OFF;
      end;

   if rig.CurrentStatus.PrevRITFreq <> rig.CurrentStatus.RITFreq then
      begin
      { $ R A NGECHECKS OFF}
          //SetDlgItemInt(h, 120, Cardinal(rig.CurrentStatus.RITFreq), rig.CurrentStatus.RITFreq < 0);
      if h <> 0 then
         begin
         PostPanelText(h, 120, string(RITFreqToPchar(rig.CurrentStatus.RITFreq)));
         end;
      { $ R A NGECHECKS ON}
      rig.CurrentStatus.PrevRITFreq := rig.CurrentStatus.RITFreq;
      end;

   if rig.CurrentStatus.PrevVFOStatus <> rig.CurrentStatus.VFOStatus then
      begin
      if TR4W_HAMLIB_DEBUG then
         begin
         logger.Info('[DisplayCurrentStatus:%s] VFOStatus change: %d ? %d',
            [rig^.RadioName,
             Ord(rig.CurrentStatus.PrevVFOStatus),
             Ord(rig.CurrentStatus.VFOStatus)]);
         end;
      if rig.CurrentStatus.VFOStatus = VFOA then
         begin
         PostPanelEnable(h, 102, True);
         PostPanelEnable(h, 104, False);
         end;
      if rig.CurrentStatus.VFOStatus = VFOB then
         begin
         PostPanelEnable(h, 104, True);
         PostPanelEnable(h, 102, False);
         end;
      if rig.CurrentStatus.VFOStatus = vfoUnknown then
         begin
         PostPanelEnable(h, 104, True);
         PostPanelEnable(h, 102, True);
         end;
      rig.CurrentStatus.PrevVFOStatus := rig.CurrentStatus.VFOStatus;
      end;

   // THESE RUN ON EVERY POLL -- rates go down to 10 ms -- and they were three
   // unconditional cross-thread EnableWindow calls, each of which blocked this
   // radio thread until the UI serviced it. PostPanelEnable coalesces: a value
   // equal to the last one posted is dropped, so a steady state costs nothing
   // and only a real RIT/XIT/SPLIT change reaches the main thread.
   //
   // BY CONTROL ID (121/122/123), not by the handles in rig.RITWndHandle and
   // friends: the panel is an LCL form and its labels have no window handle to
   // pass.  Same three controls, addressed the way the text updates already
   // were.
   if h <> 0 then
      begin
      PostPanelEnable(h, 121, rig.CurrentStatus.RIT);
      PostPanelEnable(h, 122, rig.CurrentStatus.XIT);
      PostPanelEnable(h, 123, rig.CurrentStatus.Split);
      end;

   // Drive the split warning from confirmed radio state, not from CallWindowChange.
   // CallWindowChange fires before CurrentStatus.Split is updated, causing the
   // warning to flicker or appear/disappear at the wrong time in both directions.
   if (rig = ActiveRadioPtr) and
      (rig.PreviousStatus.Split <> rig.CurrentStatus.Split) then
      begin
      if rig.CurrentStatus.Split then
         begin
         QuickDisplay(TC_SPLIT_WARN)
         end
      else
         begin
         QuickDisplay('');
         end;
      end;

   // Update VFO A mode label when mode changes (Issue #566)
   if (rig.ModeVFOAWndHandle <> 0) and
      (rig.CurrentStatus.VFO[VFOA].ExtendedMode <>
       rig.CurrentStatus.previousVFO[VFOA].ExtendedMode) then
      begin
      // BY CONTROL ID, NOT BY HANDLE.  ModeVFOAWndHandle is GetDlgItem(h, 105)
      // (MainUnit), so naming the id says the same thing and goes through the
      // one seam.  The ANSI-versus-wide note this replaces is moot now: the
      // text is a string and uPanelUpdate owns how it reaches the control.
      PostPanelText(h, 105,
         string(ExtendedModeStringArray[rig.CurrentStatus.VFO[VFOA].ExtendedMode]));
      rig.CurrentStatus.previousVFO[VFOA].ExtendedMode :=
         rig.CurrentStatus.VFO[VFOA].ExtendedMode;
      end;

   // Update VFO B mode label when mode changes (Issue #566)
   if (rig.ModeVFOBWndHandle <> 0) and
      (rig.CurrentStatus.VFO[VFOB].ExtendedMode <>
       rig.CurrentStatus.previousVFO[VFOB].ExtendedMode) then
      begin
      // See the VFO A label above -- GetDlgItem(h, 106) here.
      PostPanelText(h, 106,
         string(ExtendedModeStringArray[rig.CurrentStatus.VFO[VFOB].ExtendedMode]));
      rig.CurrentStatus.previousVFO[VFOB].ExtendedMode :=
         rig.CurrentStatus.VFO[VFOB].ExtendedMode;
      end;

end;

// Serial liveness indicator: set/clear RadioDisconnected for a serial radio and
// repaint the freq/name windows, only on a state transition.  Deliberately
// mirrors the network-side SetRadioAlertState nested in pFactoryRadio -- kept
// separate so this change does not touch the (battle-tested) network polling
// path; unifying the two is a post-Field-Day cleanup.
procedure SetSerialRadioAlertState(rig: RadioPtr; alertOn: boolean);
begin
   if alertOn = rig^.RadioDisconnected then Exit;   // no change -> do not repaint unnecessarily
   rig^.RadioDisconnected := alertOn;
   if alertOn then
      begin
      logger.Info('[SerialLiveness] %s -> alert color ON', [rig^.RadioName]);
      end
   else
      begin
      logger.Info('[SerialLiveness] %s -> alert color OFF', [rig^.RadioName]);
      end;
   RequestMainThreadJob(mtMainWindowElementColors);
end;

// Update the serial liveness indicator from one read attempt.  Shared by the
// ReadFromCOMPort wrapper and pKenwood2's inline read loop so the logic lives
// in one place.  A good read re-stamps the last-good time and clears the alert;
// a sustained silence (no good read within the timeout) raises it.
procedure MarkSerialRead(rig: RadioPtr; success: boolean);
const
   SERIAL_LIVENESS_TIMEOUT_MS = 3000;   // declare the serial radio "lost" after this much silence
begin
   if success then
      begin
      rig^.tLastValidResponse := GetTickCount;
      SetSerialRadioAlertState(rig, False);
      end
   else if (GetTickCount - rig^.tLastValidResponse) > SERIAL_LIVENESS_TIMEOUT_MS then
      begin
      SetSerialRadioAlertState(rig, True);
      end;
end;

const
   // Local, verbatim copy of the retired global KenwoodRadios taxonomy set
   // (LOGRADIO.InitRadios, deleted 2026-07-30).  This legacy polling path is
   // slated for deletion with the rest of the pre-factory driver code, so it
   // keeps its exact historical membership rather than a registry-derived
   // approximation: the ';' frame-resync check below deliberately covered the
   // Kenwood-CAT TS models plus the FLEX and NOT the Elecrafts, and a protocol
   // (rt = rtKenwood) test would silently add K2/K3/KX3/K4 to it.
   KenwoodRadios: InterfacedRadioTypeSet =
      [TS140, TS440, TS450, TS480, TS570, TS590, TS690, TS850,
       TS870, TS890, TS940, TS950, TS990, TS2000, FLEX];

function ReadFromCOMPortRaw(b: Cardinal; rig: RadioPtr): boolean;
label
   1;
var
   stat: TComStat;
   Errs: DWORD;
   c: Cardinal;
   SleepMs: Cardinal;
begin
{$IF MASKEVENT}
   if rig^.RadioModel in KenwoodRadios then
      begin
      Result := ReadFromCOMPortOnEvent(b, rig);
      Exit;
      end;
{$IFEND}

   //  if Config.NoPollDuringPTT then while rig.tPTTStatus = PTT_ON do Sleep(100);
   Result := False;
   c := 0;
   stat.cbInQue := 0;

   if rig^.RadioModel in [IC78..IC9700, OMNI6] then
      begin
      SleepMs := IcomResponseTimeout
      end
   else
      begin
      if b < 5 then
         begin
         SleepMs := 100
         end
      else
         begin
         SleepMs := 50 {+50};
         end;
      if rig^.RadioModel = Orion then
         begin
         SleepMs := 100;
         end;
      end;

   while stat.cbInQue < {<>}b do
      begin
      Sleep(SleepMs);
      if rig^.tPollCount < 0 then
         begin
         Exit;
         end;
      if not ClearCommError(rig^.tCATPortHandle, Errs, @stat) then

         begin
         ShowSysErrorMessage('READ');
         end;

      inc(c);
      if c >= b then
         begin
         1:

         {To view data in Portmon}
         if Errs = 0 then
            begin
            if stat.cbInQue <> 0 then
               begin
               ReadFromSerialPort(stat.cbInQue, rig);
               end;
            end
         else
            begin
            logger.Error('In ReadFromCOMPort, Errs <> 0 %d', [Errs]);
            Sleep(100);
            end;

         PurgeComm(rig^.tCATPortHandle, PURGE_RXCLEAR or PURGE_RXABORT);
         ClearCommError(rig^.tCATPortHandle, Errs, @stat);
         Result := False;
         Exit;
         end;
      end;
   rig.tBuf[b + 1] := #0;
   Result := ReadFromSerialPort(b, rig);

   if rig^.RadioModel in [Orion] then
      begin
      if rig.tBuf[1] <> '@' then
         begin
         goto 1;
         end;
      if rig.tBuf[b] <> #$0D then
         begin
         goto 1;
         end;
      end;

   if rig^.RadioModel in KenwoodRadios then
      if rig.tBuf[b] <> ';' then
         begin
         goto 1;
         end;

   if rig^.RadioModel in [IC706..OMNI6] then
      begin
      if (PWORD(@rig.tBuf[1])^ <> $FEFE) then
         begin
         goto 1;
         end;

      if rig.tBuf[3] = #0 then
         if not rig.tDisableCIVTransceive then
            begin
            rig.tDisableCIVTransceive := True;
            showwarning(TC_DISBALE_CIV);
            end;

      if (rig.tBuf[b] <> ICOM_END_OF_MESSAGE_CODE) or
         (rig.tBuf[4] <> ICOM_CONTROLLER_ADDRESS) then
         begin
         goto 1;
         end;
      end;

end;

function ReadFromCOMPort(b: Cardinal; rig: RadioPtr): boolean;
begin
   Result := ReadFromCOMPortRaw(b, rig);
   // Serial liveness decorator (shared with pKenwood2's inline loop via
   // MarkSerialRead): a good read keeps the indicator green; sustained silence
   // turns it red.  Decorator only -- reconnect is handled elsewhere.
   MarkSerialRead(rig, Result);
end;

procedure BeginPolling(rig: RadioPtr); stdcall;
begin
   logger.debug('Entered BeginPolling');
   ClearRadioStatus(rig);
   rig^.tLastValidResponse := GetTickCount;   // baseline so the liveness timer can't fire before the first poll
   Sleep(100);  // The polling thread did not start after reset?

   { If the radio is a network interface, we do not care what type of radio as
     the same class gets all the information from the derived radio class type.
     This BeginPolling procedure is fired up as a thread so it may cause some
     strange issues since we have a thread in the network class. TBD
   }
   if rig.tFactoryObject <> nil then
      begin
      pFactoryRadio(rig);
      Exit;   // Nothing else is done here so exit
      end;

   // The rest is for direct (non-hamlib) serial radio interfaces

   PurgeComm(rig^.tCATPortHandle, PURGE_RXCLEAR or PURGE_RXABORT);

   Windows.ZeroMemory(@rig.tBuf, SizeOf(rig.tBuf));


   // The per-model legacy dispatch that used to live here is GONE.
   // Reaching this point now means tFactoryObject was nil, which after
   // b047988e can no longer happen for a radio that actually connected.
end;

procedure PTTStatusChanged;
begin
   if ActiveRadioPtr.tPTTStatus = PTT_ON then
      begin
      tr4w_PTTStartTime := GetTickCount;
      // PTT ON is a genuine transmit sighting -- latch it, so the PTT-OFF
      // arm below can tell "the message finished" from "the radio has not
      // keyed up yet".  Same latch ProcessFilteredStatus uses; both doors
      // into "CW is over" must agree or the race just moves to the other one
      // (it did: 08d6eb2 fixed only ProcessFilteredStatus and the failure
      // reappeared here -- NY4I, 2026-08-01 16:54).
      ActiveRadioPtr.CWByCAT_SawTX := True;
      end
   else //n4af 04.30.3
      begin
      if ActiveRadioPtr.CurrentStatus.Mode = CW then
         // Only believe PTT-OFF means "done" once the radio has actually been
         // SEEN transmitting this message.  The keyer abort TR4W sends ahead
         // of every interrupting message is 'KY <abort>;RX;' -- the RX drops
         // the rig out of transmit -- and the message follows within
         // milliseconds.  A PTT-off observed in that window ended a message
         // that had not started: an F9 armed an 800 ms window at 15.876 and
         // this cleared it 272 ms later, firing tStartAutoCQ.  The operator
         // heard no CW.
         if IsCWByCATActive and ActiveRadioPtr.CWByCAT_SawTX then
            begin
            ActiveRadioPtr.CWByCAT_Sending := false;
               // If we were sending but the PTT goes off, now reset this.
            BackToInactiveRadioAfterQSO; // ny4i Issue 153 We have to try here as WK and Serial do it in their threads when not busy
            logger.trace('[Active] CWByCAT_Sending set to FALSE - %s (%s)',
               [ActiveRadioPtr.RadioName, RadioTypeToken(ActiveRadioPtr.RadioModel)]);
            tStartAutoCQ; // this is totally bizzare but the way autocqresume works is you call this and it checks.
            end;
      if tr4w_PTTStartTime <> 0 then
         begin
         tRestartInfo.riPTTOnTotalTime := tRestartInfo.riPTTOnTotalTime +
            GetTickCount - tr4w_PTTStartTime;
         end;
      end;

   (* THE MAIN THREAD DRAWS IT, not this one. tDispalyOnAirTime writes a
     main-window element, and this is the radio polling thread -- see
     mtOnAirTime. *)
   RequestMainThreadJob(mtOnAirTime);

   // STATE, NOT A WIDGET. This ran
   //
   //     SetMainWindowText(mwePTTStatus, PTTStatusString[...tPTTStatus]);
   //
   // and it is reached from ProcessFilteredStatus, on the RADIO POLLING THREAD
   // -- a serial reader assigning a control's caption. Now it records the fact
   // and src\ui\lcl\uStateBridge.pas decides what the main window shows, on the
   // main thread. See docs\DISPLAY_STATE_MODEL_PLAN.md.
   //
   // Setting it to what it already is notifies nobody, so the poller re-reading
   // status on every pass costs nothing.
   if RadioState <> nil then
      begin
      RadioState.PTTOn := ActiveRadioPtr.tPTTStatus = PTT_ON;
      end;

   SendStationStatus(sstPTT);
end;

procedure SendRadioInfoToUDP(rig: RadioPtr);
var
   sBuf: AnsiString;
   sMode: AnsiString;
   // msg   : TIdBytes;
   freq: integer;
   txFreq: integer;
begin

   { Example of message from N1MM
   <RadioInfo>
           <RadioNr>1</RadioNr>
           <Freq>1809738</Freq>
           <TXFreq>1809738</TXFreq>
           <Mode>USB</Mode>
           <OpCall>NY4I</OpCall>
           <IsRunning>False</IsRunning>
           <FocusEntry>1389988</FocusEntry>
           <Antenna>-1</Antenna>
           <Rotors>-1</Rotors>
           <FocusRadioNr>1</FocusRadioNr>
   </RadioInfo>
   }
   if rig.CurrentStatus.Split then
      begin
      txFreq := rig.CurrentStatus.VFO[VFOB].Frequency;
      freq := rig.CurrentStatus.Freq;
      end
   else
      begin
      txFreq := rig.CurrentStatus.Freq;
      freq := rig.CurrentStatus.Freq;
      end;

   case rig.CurrentStatus.Mode of
      CW: sMode := 'CW';
      Phone:
         if freq < 10000000 then
            // It seems like this should be in the radio object instead of us guessing // ny4i
            begin
            sMode := 'LSB';
            if (freq > 5300000) and (freq < 5400000) then
               begin
               sMode := 'USB';
               end;
            end
         else
            begin
            sMode := 'USB';
            end;
      Digital: sMode := 'RTTY';
      else
         sMode := ' ';
   end; // of case
   sMode := ExtendedModeStringArray[rig.currentStatus.ExtendedMode];
   sBuf := '<?xml version="1.0" encoding="utf-8"?>' + sLineBreak +
      '<RadioInfo>' + sLineBreak +
      #9 + '<app>TR4W</app>' + sLineBreak +
      #9 + '<StationName>' +  GetLocalComputerName + '</StationName>' + sLineBreak +
      // Per N1MM RadioInfo spec: RadioNr identifies the packet's subject
      // radio (1 or 2), not whichever radio is currently active.  In SO2R,
      // each radio emits its own packet with its own number.
      #9 + '<RadioNr>' + Format('%d',[Math.IfThen(rig = @Radio1,1,2)]) + '</RadioNr>' + sLineBreak +
      #9 + '<Freq>' + Format('%d', [freq div 10]) + '</Freq>' + sLineBreak +
      #9 + '<TXFreq>' + Format('%d', [txFreq div 10]) + '</TXFreq>' + sLineBreak +
      #9 + '<Mode>' + sMode + '</Mode>' +  sLineBreak +
      #9 + '<OpCall>' + CurrentOperator + '</OpCall>' +  sLineBreak +
      #9 + '<IsRunning>' + StrUtils.IfThen(OpMode = SearchAndPounceOpMode,'False','True') + '</IsRunning>' + sLineBreak +
      #9 + '<FocusEntry>0</FocusEntry>' + sLineBreak +
      #9 + '<EntryWindowHwnd>' + '0' + '</EntryWindowHwnd>' + sLineBreak +
      #9 + '<Antenna>-1</Antenna>' + sLineBreak +
      #9 + '<Rotors>-1</Rotors>' + sLineBreak +
      // FocusRadioNr / ActiveRadioNr: which radio has operator focus right now.
      // TR4W tracks this as the global ActiveRadio; both fields reflect it.
      #9 + '<FocusRadioNr>' + Format('%d',[Math.IfThen(ActiveRadio = RadioOne,1,2)]) + '</FocusRadioNr>' + sLineBreak +
      #9 + '<IsStereo>' + 'False' + '</IsStereo>' + sLineBreak +
      #9 + '<IsSplit>' + StrUtils.IfThen(rig.CurrentStatus.Split,'True','False') + '</IsSplit>' + sLineBreak +
      #9 + '<ActiveRadioNr>' + Format('%d',[Math.IfThen(ActiveRadio = RadioOne,1,2)]) + '</ActiveRadioNr>' + sLineBreak +
      #9 + '<IsTransmitting>' + StrUtils.IfThen(rig.CurrentStatus.TXOn,'True','False') + '</IsTransmitting>' + sLineBreak +
      #9 + '<FunctionKeyCaption>' + '' + '</FunctionKeyCaption>' + sLineBreak +
      #9 + '<RadioName>' + rig.RadioName + '</RadioName>' + sLineBreak +
      // N1MM RadioInfo IsConnected (Issue #917).  Source: rig.RadioDisconnected,
      // which is maintained by pFactoryRadio's SetRadioAlertState for network
      // radios (Icom CI-V/IP, K4 TCP, FlexRadio, HamLib Direct, TS-890 LAN).
      // The legacy serial polling threads (pYaesu/pIcom/pKenwood/pK3/etc.)
      // do not currently update RadioDisconnected, so this reports True for
      // serial-attached radios whenever one is configured -- real serial
      // CAT-port liveness detection is a separate follow-up.
      #9 + '<IsConnected>' + StrUtils.IfThen(rig.RadioDisconnected,'False','True') + '</IsConnected>' + sLineBreak +
      '</RadioInfo>';

   //SetLength(msg,Length(sBuf));
   //msg := RawToBytes(sBuf[1], Length(sBuf));
   try
      udp.BroadcastEnabled := true;
      udp.Send(UDPBroadcastAddress, UDPBroadcastPortRadio, sBuf); // ny4i 4.44.9
      logger.trace('[SendRadioInfoToUDP] %s', [sBuf]);
      dtLastUDPRadio := Now;
   except
      on E: Exception do
         // ShowMessage(PChar('Exception in SendRadioInfoToUDP. Message = '));
   end;
end; // SendRadioInfoToUDP;

function ArrayToString(const a: array of AnsiChar): string;
begin
  if Length(a)>0 then
     begin
     SetString(Result, PAnsiChar(@a[0]), Length(a))
     end
  else
     begin
     Result := '';
     end;
end;

initialization
   { The two pieces of UI work this unit used to do on a radio thread. }
   RegisterMainThreadJob(mtSwitchToSearchAndPounce, @RunSwitchToSearchAndPounce);
   RegisterMainThreadJob(mtBandModeDisplay, @RunBandModeDisplay);
   RegisterMainThreadJob(mtMainWindowElementColors, @RefreshMainWindowElementColors);
   RegisterMainThreadJob(mtOnAirTime, @tDispalyOnAirTime);

end.
