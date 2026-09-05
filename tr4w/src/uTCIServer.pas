{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
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
unit uTCIServer;
{$I tr4w.inc}

{
  TR4W AS A TCI SERVER -- the bridge between TCI clients and our radio.

  WHY.  Only one program can hold a serial port.  TR4W holds it, so anything
  else that needs the radio -- WSJT-X, JTDX, a skimmer -- has to come through
  us.  TR4W already does this for WSJT-X by impersonating DXLab Commander in
  uWSJTX.pas, but that is a single-client, protocol-by-accident bridge with a
  documented lie in it (the KLUDGESECONDSV block reports COMMANDED transmit
  state for two seconds, because WSJT-X drops the link if a PTT command is not
  reflected within about a second and TR4W only learns the truth on the next
  poll).  TCI is the right shape for the job: published, multi-client, and
  state-broadcast rather than polled.

  THE KLUDGE DOES NOT COME WITH US, AND THIS IS WHY.  TCI's contract is that
  the SERVER confirms: it answers the command, and then broadcasts the truth
  when the radio reconciles.  So a client learns the real state from the
  broadcast instead of being told a timed lie.  That is a protocol property,
  not a trick -- see ApplyPTT.

  THIS UNIT KNOWS TCI AND RADIOS.  It knows nothing about WebSocket framing
  (uWebSocketServer) or TCI grammar (uTCIProtocol).

  ------------------------------------------------------------------------
  THREADING.  Three threads meet here and the rules are not symmetric.

  1. INDY CONNECTION THREADS raise OnTextMessage.  They may READ radio state
     -- via ReadRadioStatus, which is a seqlock and safe from any thread --
     but they must NEVER call the radio.  RadioObject.SetRadioFreq writes
     globals (tCommandedQSYFreq, the auto-S&P hook) and the display routines
     around it are main-thread things.  So every write is marshalled onto the
     main thread by POSTING WM_TCI_APPLY to TR4W's own message loop.  It was
     TThread.Queue until 2026-08-14, which is a race: a connection thread that
     queues an apply and then exits purges its own callback.  See WM_TCI_APPLY
     for why neither Synchronize nor QueueAsyncCall can replace it here.

  2. THE RADIO POLLING THREAD calls PublishRadioState through the
     RadioStatusPublished hook.  It must not be blocked: a slow observer
     delays the next poll of that radio.  Everything on that path only
     enqueues -- TWSServerSession.SendText never touches a socket.

  3. THE MAIN THREAD runs the queued applies.

  Broadcast state (what we last told clients) is guarded by one critical
  section.  It is small and never held across a socket write.
  ------------------------------------------------------------------------

  RECEIVER MAPPING.  trx 0 = Radio 1, trx 1 = Radio 2.  Split is expressed
  the clean way -- split_enable:<trx>,<b> plus vfo:<trx>,1,<hz> -- and NOT as
  AetherSDR's second-receiver-with-tx_enable idiom, which only makes sense
  for an SDR with many slices.

  NOT IMPLEMENTED, DELIBERATELY: audio and IQ streams.  TR4W bridges a rig
  and has no audio to offer; clients keep their soundcard.  The commands are
  acknowledged, because a client that gets silence there concludes the server
  is broken, but no binary frame is ever emitted.
}

interface

uses
   Windows, SysUtils, Classes, SyncObjs,
   VC, LOGRADIO,
   uWebSocketServer, uTCIProtocol,
   uMainThread;   (* RunOnMainThread -- an apply runs on the main thread *)

const
   TCI_SERVER_DEFAULT_PORT = 50001;

   { Posted by a TCI connection thread to hand an apply to the main thread.
     lParam carries the command object; the handler in tr4w.lpr calls
     TCIRunQueuedApply, which takes ownership.

     WHY A WINDOW MESSAGE AND NOT TThread.Queue -- the reason is specific and was
     paid for elsewhere in this program on 2026-08-14.

     TThread.Queue stamps every entry with the CALLING thread's id, even when the
     thread argument is nil (FPC 3.2.2 classes.inc:562). TThread.Destroy later
     purges by that id (classes.inc:603), so a thread that queues and then exits
     DELETES ITS OWN PENDING CALLBACK. Radio discovery lost its results to
     exactly that and looked like a hang. Here the queueing threads are Indy
     connection threads, so the window is narrower -- but a client that sets a
     frequency and immediately disconnects is an ordinary thing for WSJT-X to do,
     and losing a PTT or a split is not an ordinary consequence.

     TThread.Synchronize is immune to the purge but CANNOT be used here: it
     blocks the connection thread until the main thread runs the method, and
     TTCIServer.Stop -- on the main thread -- takes the Indy server down, which
     waits for those same connection threads. That is a deadlock, not a
     trade-off.

     Application.QueueAsyncCall is lifetime-independent and non-blocking, but the
     LCL only drains it from Application.Idle / ProcessMessages / HandleMessage,
     and TR4W runs its own GetMessage loop rather than Application.Run. It would
     never be delivered.

     A posted message has none of those problems: it does not block the sender,
     it is not tied to any thread's lifetime, and it is drained by TR4W's OWN
     message loop, which is the one mechanism here that is not borrowed. It is
     also already the house pattern -- uPOTAParks hands a parsed list over the
     same way (WM_POTA_LOAD_DONE). }
   WM_TCI_APPLY = WM_APP + 220;   // 200/201 POTA, 210/211 CTY

{ Runs an apply posted with WM_TCI_APPLY and frees it. aData is the command
  object. Exposed because the message is handled in tr4w.lpr, which has no
  business knowing the command classes -- they stay in the implementation. }
procedure TCIRunQueuedApply(aData: PtrInt);

type
   { Per-connection TCI state.  Owned by the TWSServerSession that carries it
     as its Tag, and freed with it. }
   TTCIClientState = class(TObject)
   public
      Framer:  TTCIFramer;
      Started: boolean;    // the client sent start;
      OwnsPTT: boolean;    // this client holds the transmit session
      constructor Create;
      destructor  Destroy; override;
   end;

   TTCIServer = class;

   { Bounds a TCI-keyed transmission.

     WHY IT HAS ITS OWN THREAD.  This is a safety interlock, so it must not
     share a fate with anything it is protecting against.  The poll loop would
     have been free, but a stuck transmitter and a stalled poll loop are not
     independent events -- if polling has died, that is exactly when we most
     need this to still run.  One thread, asleep on an event for all but a
     few microseconds a second, is the right price.

     WHAT IT DOES NOT DO: touch a transmission the OPERATOR started.  It fires
     only while a TCI client holds the transmit session. }
   TTCIWatchdogThread = class(TThread)
   private
      FOwner:  TTCIServer;
      FWakeUp: TEvent;
   protected
      procedure Execute; override;
   public
      constructor Create(AOwner: TTCIServer);
      destructor  Destroy; override;
      procedure Stop;
   end;

   TTCIServer = class(TObject)
   private
      FWS:      TWebSocketServer;
      FPort:    integer;
      FBindAll: boolean;

      FLock:     TCriticalSection;
      FLast:     array[RadioOne..RadioTwo] of RadioStatusRecord;
      FHave:     array[RadioOne..RadioTwo] of boolean;

      // A mode we have commanded but the poll has not yet confirmed.
      //
      // WHY THIS EXISTS.  SetRadioFreq sets FREQUENCY AND MODE TOGETHER --
      // there is no frequency-only setter on the legacy facade.  So a QSY has
      // to name a mode, and the obvious source, the status snapshot, is stale
      // for up to a poll interval.  WSJT-X sends modulation and vfo THREE
      // MILLISECONDS apart, so the vfo re-asserted the old mode and undid the
      // mode change that had just been made.  Observed on the wire, not
      // theorised: 13:30:44.948 modulation:0,digu then 13:30:44.951
      // vfo:0,0,50313000, and the radio ended up on the new frequency in the
      // old mode.
      //
      // Cleared as soon as the radio reports the mode we asked for, so a mode
      // set on the radio's own front panel is not fought forever.
      FPendingMode: array[RadioOne..RadioTwo] of record
         Active:   boolean;
         Mode:     ModeType;
         Extended: ExtendedModeType;
      end;

      // At most one client may key the transmitter at a time.  Guarded by
      // FLock; the session pointer is only ever compared, never dereferenced
      // outside a handler that already owns the session.
      FPTTOwner: TWSServerSession;
      // GetTickCount at the moment a TCI client keyed.  Guarded by FLock.
      FPTTKeyedAt: cardinal;
      FWatchdog: TTCIWatchdogThread;

      (* THE OUTSTANDING QUEUED APPLIES, so this server can detach them.

        A queued apply holds a raw pointer to the server and is run LATER, by
        the main thread.  Nothing tied the two lifetimes, so a server destroyed
        while an apply was still in the LCL's async queue left the command
        pointing at freed memory -- and the queue is drained rather than
        discarded, by TApplication.Destroy, so the command RUNS.

        Measured, on the unit-test binary: every test that drives a TCI command
        queues an apply, the suite never turns the LCL loop, and at shutdown
        TApplication.Destroy ran them all against a server freed in TearDown --
        FServer.FLock.Enter on recycled heap, SIGSEGV, exit 217 AFTER
        'All tests passed'.  The app has the same race on any teardown that
        overlaps a queued apply; it survives only because its loop turns often
        enough that the window is small.

        A separate lock from FLock on purpose: a command's Execute takes FLock,
        so guarding this with FLock too would nest the two and impose an
        ordering nothing else needs.  Nothing takes FCmdLock while holding
        FLock -- ApplyModulation releases FLock before it posts. *)
      FCmdLock:  TCriticalSection;
      FCommands: TFPList;

      (* TObject rather than TTCIApplyCommand because the command classes are
        implementation-only; the bodies cast.  Private is enough -- the
        commands live in this unit, and a unit is its own friend. *)
      procedure AttachCommand(aCmd: TObject);
      procedure DetachCommand(aCmd: TObject);
      procedure DetachAllCommands;

      procedure SessionOpened(Session: TWSServerSession);
      procedure SessionClosed(Session: TWSServerSession);
      procedure TextArrived(Session: TWSServerSession; const Text: string);

      // THE ONE PLACE ANYTHING GOES OUT.  Every reply, confirmation and
      // broadcast goes through these two, so 'TCI DEBUG = TRUE' shows the
      // whole conversation in tr4w.log instead of only the inbound half.
      // Before this, outbound was not logged AT ALL and diagnosing a refused
      // PTT needed a Wireshark capture.
      procedure Send(Session: TWSServerSession; const Msg: string);
      procedure SendAll(const Msg: string);
      procedure SendInitBurst(Session: TWSServerSession);
      procedure Dispatch(Session: TWSServerSession; const Raw: string);

      procedure HandleGet(Session: TWSServerSession; const Cmd: TTCICommand);
      procedure HandleSet(Session: TWSServerSession; const Cmd: TTCICommand);

      procedure ApplyFrequency(Trx, Channel, Hz: integer; Session: TWSServerSession);
      procedure ApplyModulation(Trx: integer; const Modulation: string;
                                Session: TWSServerSession);
      procedure ApplySplit(Trx: integer; TurnOn: boolean);
      procedure ApplyPTT(Session: TWSServerSession; Trx: integer; KeyDown: boolean);

      procedure BroadcastRadio(Trx: integer; const Cur, Was: RadioStatusRecord;
                               First: boolean);
      function  SlotOf(Trx: integer): RadioType;
      // Called about once a second from the watchdog thread.
      procedure CheckTransmitTimeout;
   public
      constructor Create;
      destructor  Destroy; override;

      function  Start(APort: integer = TCI_SERVER_DEFAULT_PORT;
                      ABindAll: boolean = False): boolean;
      procedure Stop;
      function  Active: boolean;
      function  ClientCount: integer;
      // Why the last Start failed -- the operator cannot diagnose silence,
      // and "port already in use" is the common case.
      function  LastError: string;

      // Called from the radio POLLING thread via the RadioStatusPublished
      // hook, immediately after a coherent status is published.
      procedure PublishRadioState(rig: RadioPtr);

      // Releases the transmitter if this client was holding it.  Public so a
      // disconnect and a Stop can both fail closed through one path.
      procedure ReleasePTT(Session: TWSServerSession);
      // Drops the transmit session without unkeying -- for a key that was
      // refused before it reached the radio.
      procedure ReleasePTTOwnership(Session: TWSServerSession);

      (* HOW MANY APPLIES ARE QUEUED AND NOT YET RUN.

        Exposed for the tests, and it is the only part of the register that can
        be OBSERVED rather than inferred.  The failure this guards against is a
        use-after-free at shutdown, and a use-after-free cannot be pinned by
        watching for a fault: whether it faults depends on whether the heap has
        been recycled yet.  Measured -- draining the queue from a test ran a
        command against a freed server and did not crash, so a test written
        that way PASSES with the fix reverted.

        So the assertion is structural instead: while an apply is pending it is
        registered with its server, and that is what Destroy relies on. *)
      function OutstandingApplyCount: integer;
   end;

var
   // The one instance.  A plain procedure hook cannot carry Self, and there
   // is exactly one server, so a singleton is honest rather than a shortcut.
   TCIServer: TTCIServer = nil;

// Maps between TR4W's mode pair and TCI's modulation names.  Exposed for the
// unit tests: the mapping is a wire contract, not an implementation detail.
function TR4WModeToTCI(Mode: ModeType; Extended: ExtendedModeType;
                       FreqHz: integer): string;
function TCIToTR4WMode(const Modulation: string; out Mode: ModeType;
                       out Extended: ExtendedModeType): boolean;

// trx <-> radio.  Returns nil / -1 when the receiver is not configured; a
// caller must NEVER fall back to radio 0 when a client names a receiver.
function TrxToRadio(Trx: integer): RadioPtr;
function RadioToTrx(rig: RadioPtr): integer;
function ConfiguredRadioCount: integer;

implementation

uses
   MainUnit,          // logger
   tree,              // CodeSpeed
   LOGK1EA,           // Config.PTTViaCommand
   uConfigValues,     // Config.NoPollDuringPTT -- named in the refusal
   uRadioPolling,     // RadioStatusPublished
   uFactoryRadioBase;

{ ------------------------------------------------- the queued applies -- }

// WHY THESE ARE OBJECTS AND NOT ANONYMOUS METHODS.
//
// Each apply below runs on the MAIN thread -- posted there with WM_TCI_APPLY --
// because SetRadioFreq and friends write program globals and touch the display.
// The values they act on are read on the CLIENT's thread, so they have to
// travel, and an object that NAMES what it carries is what travels.
//
// A closure captured them implicitly.  That reads well and costs two things,
// and rotatorFactory\uRotatorBase.pas:62 already wrote down both: it needs a
// compiler with closures (FPC 3.2.2 stable has none), and it HIDES WHO OWNS THE
// STATE BEING CAPTURED.  The second matters more here than portability -- these
// are transmit commands, and "which radio, at what frequency, keyed by whom"
// is exactly the state that must not be ambiguous.
//
// So each apply is a small command object that NAMES what it carries, and Run
// is a plain `procedure of object` that both compilers accept.  The command
// owns itself and frees in Run's finally, so a raising Execute cannot leak it.
//
// Lifetime note, CORRECTED.  This said a command queued but never drained was
// LEAKED.  It is not: TApplication.Destroy drains the async queue on its way
// out rather than discarding it, so the command runs -- and if the server died
// first, it runs against freed memory.  A leak would have been the harmless
// outcome; what actually happened was a use-after-free at shutdown.
//
// So every command REGISTERS with its server for as long as it is pending, and
// TTCIServer.Destroy cancels whatever is still outstanding.  A cancelled
// command still runs and still frees itself -- it just does nothing.

type
   TTCIApplyCommand = class abstract
   protected
      FServer: TTCIServer;
      FRig:    RadioPtr;
      procedure Execute; virtual; abstract;
   public
      constructor Create(aServer: TTCIServer; aRig: RadioPtr);
      (* THE SERVER IS GOING AWAY AND THIS COMMAND MUST NOT TOUCH IT.  Called
        only by TTCIServer.DetachAllCommands.  Run still frees the command. *)
      procedure Cancel;
      procedure Run;
   end;

   TTCIApplyFreq = class(TTCIApplyCommand)
   private
      FTrx:     integer;
      FChannel: integer;
      FHz:      integer;
   protected
      procedure Execute; override;
   public
      constructor Create(aServer: TTCIServer; aRig: RadioPtr;
                         aTrx, aChannel, aHz: integer);
   end;

   TTCIApplyMode = class(TTCIApplyCommand)
   private
      FMode:     ModeType;
      FExtended: ExtendedModeType;
   protected
      procedure Execute; override;
   public
      constructor Create(aServer: TTCIServer; aRig: RadioPtr;
                         aMode: ModeType; aExtended: ExtendedModeType);
   end;

   TTCIApplySplit = class(TTCIApplyCommand)
   private
      FTurnOn: boolean;
   protected
      procedure Execute; override;
   public
      constructor Create(aServer: TTCIServer; aRig: RadioPtr; aTurnOn: boolean);
   end;

   TTCIApplyPTT = class(TTCIApplyCommand)
   private
      FTrx:     integer;
      FKeyDown: boolean;
      FSession: TWSServerSession;
   protected
      procedure Execute; override;
   public
      constructor Create(aServer: TTCIServer; aRig: RadioPtr; aTrx: integer;
                         aKeyDown: boolean; aSession: TWSServerSession);
   end;

{ ------------------------------------------------- the queued applies -- }

constructor TTCIApplyCommand.Create(aServer: TTCIServer; aRig: RadioPtr);
begin
   inherited Create;
   FServer := aServer;
   FRig    := aRig;

   (* REGISTERED WHILE PENDING.  Attaching in the constructor rather than in
     PostTCIApply keeps the register honest for a command that is built and
     then never posted: it is still attached, so a Destroy in between cancels
     it instead of leaving the caller holding a command that outlived its
     server. *)
   if FServer <> nil then
      begin
      FServer.AttachCommand(Self);
      end;
end;

procedure TTCIApplyCommand.Cancel;
begin
   FServer := nil;
end;

procedure TTCIApplyCommand.Run;
begin
   // Frees in the finally so a raising Execute cannot leak the command.  After
   // this returns nothing may touch Self.
   try
      (* DETACH BEFORE EXECUTE, not after: Execute may raise, and the finally
        below frees the command either way.  Detaching afterwards would leave a
        freed pointer in the server's register for DetachAllCommands to call
        Cancel on.

        A nil FServer means Cancel got here first -- the server is gone, and
        every Execute below reads it.  Doing nothing is the whole point.

        THE INVARIANT THIS RELIES ON: a command runs on the main thread (the
        LCL drains the async queue there) and TTCIServer.Destroy is called on
        the main thread too -- MainUnit.pas shutdown, and the tests' TearDown.
        So a detach cannot interleave with an Execute already past its check.
        Destroying the server from a background thread would break that, which
        is why it is written down rather than assumed. *)
      if FServer <> nil then
         begin
         FServer.DetachCommand(Self);
         Execute;
         end;
   finally
      Free;
   end;
end;

{ Hands a finished command to the main thread. See WM_TCI_APPLY for why this is
  a posted message rather than TThread.Queue or Synchronize.

  NEVER LEAKS ON FAILURE. If there is no main window yet, or during shutdown, or
  the thread's message queue refuses the post, the command is freed here. The
  alternative -- posting and hoping -- is how a transmit command becomes a slow
  leak nobody attributes to TCI. }
procedure PostTCIApply(aCmd: TTCIApplyCommand);
begin
   if aCmd = nil then
      begin
      Exit;
      end;

   (* ONTO THE MAIN THREAD, and the handoff cannot be refused.

     This posted WM_TCI_APPLY to the main window, which needed a window to
     exist and could fail -- and on failure the command was freed and the
     apply silently lost. RunOnMainThread has neither problem, and there is no
     main-window check left to make because there is no window in it.

     A posted message rather than TThread.Queue because a queueing thread that
     exits purges its own callback, and rather than Synchronize because that
     would block an Indy connection thread against TTCIServer.Stop.
     QueueAsyncCall has neither behaviour: it is not tied to the calling
     thread lifetime and it does not wait. *)
   RunOnMainThread(TCIRunQueuedApply, PtrInt(aCmd));
end;

procedure TCIRunQueuedApply(aData: PtrInt);
begin
   if aData = 0 then
      begin
      Exit;
      end;

   // Run frees the command, including when Execute raises.
   TTCIApplyCommand(aData).Run;
end;

constructor TTCIApplyFreq.Create(aServer: TTCIServer; aRig: RadioPtr;
                                 aTrx, aChannel, aHz: integer);
begin
   inherited Create(aServer, aRig);
   FTrx     := aTrx;
   FChannel := aChannel;
   FHz      := aHz;
end;

procedure TTCIApplyFreq.Execute;
var
   snap:     RadioStatusRecord;
   mode:     ModeType;
   extended: ExtendedModeType;
   slot:     RadioType;
   ch:       char;
begin
   try
      // SetRadioFreq sets frequency AND MODE -- there is no frequency-only
      // setter -- so a QSY must name a mode.  Prefer a mode we have COMMANDED
      // and the poll has not confirmed yet; the snapshot lags by up to a poll
      // interval, and using it here re-asserted the old mode 3 ms after a
      // modulation command and silently undid it.
      snap := ReadRadioStatus(FRig);
      mode := snap.VFO[VFOA].Mode;
      extended := snap.VFO[VFOA].ExtendedMode;
      slot := FServer.SlotOf(FTrx);
      FServer.FLock.Enter;
      try
         if FServer.FPendingMode[slot].Active then
            begin
            mode := FServer.FPendingMode[slot].Mode;
            extended := FServer.FPendingMode[slot].Extended;
            end;
      finally
         FServer.FLock.Leave;
      end;

      if FChannel = 0 then
         begin
         ch := 'A';
         end
      else
         begin
         ch := 'B';
         end;
      FRig^.SetRadioFreq(FHz, mode, ch, extended);
   except
      on E: Exception do
         begin
         logger.Error('[TCI-SRV] tune to %d Hz failed: %s', [FHz, E.Message]);
         end;
   end;
end;

constructor TTCIApplyMode.Create(aServer: TTCIServer; aRig: RadioPtr;
                                 aMode: ModeType; aExtended: ExtendedModeType);
begin
   inherited Create(aServer, aRig);
   FMode     := aMode;
   FExtended := aExtended;
end;

procedure TTCIApplyMode.Execute;
var
   snap: RadioStatusRecord;
begin
   try
      // Setting the mode means retuning to where we already are with a new
      // mode: that is the only mode setter the legacy facade has.
      snap := ReadRadioStatus(FRig);
      if snap.VFO[VFOA].Frequency > 0 then
         begin
         FRig^.SetRadioFreq(snap.VFO[VFOA].Frequency, FMode, 'A', FExtended);
         end;
   except
      on E: Exception do
         begin
         logger.Error('[TCI-SRV] mode change failed: %s', [E.Message]);
         end;
   end;
end;

constructor TTCIApplySplit.Create(aServer: TTCIServer; aRig: RadioPtr; aTurnOn: boolean);
begin
   inherited Create(aServer, aRig);
   FTurnOn := aTurnOn;
end;

procedure TTCIApplySplit.Execute;
begin
   try
      if FTurnOn then
         begin
         FRig^.PutRadioIntoSplit;
         end
      else
         begin
         FRig^.PutRadioOutOfSplit;
         end;
   except
      on E: Exception do
         begin
         logger.Error('[TCI-SRV] split change failed: %s', [E.Message]);
         end;
   end;
end;

constructor TTCIApplyPTT.Create(aServer: TTCIServer; aRig: RadioPtr; aTrx: integer;
                                aKeyDown: boolean; aSession: TWSServerSession);
begin
   inherited Create(aServer, aRig);
   FTrx     := aTrx;
   FKeyDown := aKeyDown;
   FSession := aSession;
end;

procedure TTCIApplyPTT.Execute;
var
   sent: boolean;
begin
   sent := False;
   try
      // THE RADIO THE CLIENT ADDRESSED, not whichever is active.  trx:1,true
      // means radio 2, and tPTTVIACAT keys ActiveRadio -- so a client working
      // the second radio keyed the first.
      sent := tPTTVIACATForRadio(FRig, FKeyDown);
   except
      on E: Exception do
         begin
         logger.Error('[TCI-SRV] PTT %s failed: %s',
                      [BoolToStr(FKeyDown, True), E.Message]);
         end;
   end;

   if not sent then
      begin
      // Named explicitly, because the operator has to change a setting and
      // "it did not transmit" gives them nothing to act on.
      if not Config.PTTViaCommand then
         begin
         logger.Warn('[TCI-SRV] PTT refused: "PTT VIA COMMANDS" is FALSE, ' +
                     'so no transmit command is sent to the radio');
         end
      else if Config.NoPollDuringPTT then
         begin
         logger.Warn('[TCI-SRV] PTT refused: NO POLL DURING PTT is set');
         end
      else
         begin
         logger.Warn('[TCI-SRV] PTT refused: no radio driver');
         end;
      // Give the transmit session back -- we do not hold a transmitter we
      // never keyed.
      FServer.ReleasePTTOwnership(FSession);
      end;

   // Sent LAST and from what actually happened.  If the radio then disagrees,
   // the next publish broadcasts the truth to everyone -- which is what
   // replaces uWSJTX's KLUDGESECONDSV, a commanded state reported as fact for
   // two seconds.
   FServer.Send(FSession, TCIMsg('trx', TCIInt(FTrx), TCIBool(FKeyDown and sent)));
end;

{ ------------------------------------------------------------- mapping -- }

function TrxToRadio(Trx: integer): RadioPtr;
begin
   case Trx of
      0: Result := @Radio1;
      1: Result := @Radio2;
   else
      Result := nil;
   end;
end;

function RadioToTrx(rig: RadioPtr): integer;
begin
   if rig = @Radio1 then
      begin
      Result := 0;
      end
   else if rig = @Radio2 then
      begin
      Result := 1;
      end
   else
      begin
      Result := -1;
      end;
end;

function ConfiguredRadioCount: integer;
begin
   // The test is "does a factory radio object exist", NOT
   // "RadioModel <> NoInterfacedRadio".  A string-id factory radio -- TCI
   // itself is one -- has RadioModel = NoInterfacedRadio by design, so the
   // model-keyed form reports a configured radio as absent.  That exact
   // shape has already cost this project a silently missing radio twice.
   if Radio2.tFactoryObject <> nil then
      begin
      Result := 2;
      end
   else
      begin
      Result := 1;
      end;
end;

function TR4WModeToTCI(Mode: ModeType; Extended: ExtendedModeType;
                       FreqHz: integer): string;
begin
   // The extended mode is the precise one; consult it first.
   case Extended of
      eCW:                Result := 'cw';
      eCW_R:              Result := 'cwr';
      eUSB:               Result := 'usb';
      eLSB:               Result := 'lsb';
      eAM, eAM_N:         Result := 'am';
      eFM, eFM_N, eWFM:   Result := 'fm';
      eRTTY:              Result := 'rtty';
      eRTTY_R:            Result := 'rtty';
      eData, eData_FM:    Result := 'digu';
      eData_R:            Result := 'digl';
   else
      // No extended mode: fall back on the coarse one.  For phone that means
      // choosing a sideband, and the only sane rule is the operating
      // convention -- LSB below 10 MHz, USB above.  Guessing 'usb' on 40 m
      // would make a client show the wrong sideband on every QSY.
      case Mode of
         CW:      Result := 'cw';
         Digital: Result := 'digu';
         FM:      Result := 'fm';
         Phone:
            begin
            if (FreqHz > 0) and (FreqHz < 10000000) then
               begin
               Result := 'lsb';
               end
            else
               begin
               Result := 'usb';
               end;
            end;
      else
         Result := 'usb';
      end;
   end;
end;

function TCIToTR4WMode(const Modulation: string; out Mode: ModeType;
                       out Extended: ExtendedModeType): boolean;
var
   m: string;
begin
   m := LowerCase(Trim(Modulation));
   Result := True;
   if m = 'cw' then
      begin
      Mode := CW;       Extended := eCW;
      end
   else if m = 'cwr' then
      begin
      Mode := CW;       Extended := eCW_R;
      end
   else if m = 'usb' then
      begin
      Mode := Phone;    Extended := eUSB;
      end
   else if m = 'lsb' then
      begin
      Mode := Phone;    Extended := eLSB;
      end
   else if m = 'am' then
      begin
      Mode := Phone;    Extended := eAM;
      end
   else if m = 'fm' then
      begin
      Mode := FM;       Extended := eFM;
      end
   else if m = 'rtty' then
      begin
      Mode := Digital;  Extended := eRTTY;
      end
   else if m = 'digu' then
      begin
      Mode := Digital;  Extended := eData;
      end
   else if m = 'digl' then
      begin
      Mode := Digital;  Extended := eData_R;
      end
   else
      begin
      // A mode we never advertised.  The reference server silently coerces
      // anything unknown to USB, which puts a radio in the wrong mode
      // without telling anyone -- refuse instead and answer with silence.
      Mode := NoMode;   Extended := eNoMode;
      Result := False;
      end;
end;

{ ------------------------------------------------------ TTCIClientState -- }

constructor TTCIClientState.Create;
begin
   inherited Create;
   Framer := TTCIFramer.Create;
   Started := False;
   OwnsPTT := False;
end;

destructor TTCIClientState.Destroy;
begin
   FreeAndNil(Framer);
   inherited Destroy;
end;

{ ---------------------------------------------------- TTCIWatchdogThread -- }

constructor TTCIWatchdogThread.Create(AOwner: TTCIServer);
begin
   FOwner := AOwner;
   FWakeUp := TEvent.Create(nil, False, False, '');
   FreeOnTerminate := False;
   inherited Create(False);
end;

destructor TTCIWatchdogThread.Destroy;
begin
   FreeAndNil(FWakeUp);
   inherited Destroy;
end;

procedure TTCIWatchdogThread.Stop;
begin
   Terminate;
   FWakeUp.SetEvent;   // do not make shutdown wait out the poll interval
end;

procedure TTCIWatchdogThread.Execute;
begin
   while not Terminated do
      begin
      FWakeUp.WaitFor(1000);
      if Terminated then
         begin
         Break;
         end;
      try
         FOwner.CheckTransmitTimeout;
      except
         on E: Exception do
            begin
            // Must never die: it is the last thing standing between a wedged
            // client and a transmitter that stays keyed.
            logger.Error('[TCI-SRV] watchdog: %s - %s', [E.ClassName, E.Message]);
            end;
      end;
      end;
end;

{ ------------------------------------------------- the publish-side hook -- }

// A plain procedure, because the hook in uRadioPolling is a plain procedure
// type -- see the note there on why it is not a method pointer.
procedure TCIStatusPublished(rig: RadioPtr);
begin
   if TCIServer <> nil then
      begin
      TCIServer.PublishRadioState(rig);
      end;
end;

{ ----------------------------------------------------------- TTCIServer -- }

constructor TTCIServer.Create;
var
   r: RadioType;
begin
   inherited Create;
   FLock := TCriticalSection.Create;

   (* Before FWS and the watchdog: both can reach code that builds an apply,
     and an unbuilt register would be the first thing it touched. *)
   FCmdLock  := TCriticalSection.Create;
   FCommands := TFPList.Create;

   FPort := TCI_SERVER_DEFAULT_PORT;
   FPTTOwner := nil;
   FPTTKeyedAt := 0;
   for r := RadioOne to RadioTwo do
      begin
      FHave[r] := False;
      FPendingMode[r].Active := False;
      end;

   FWS := TWebSocketServer.Create;
   FWS.OnSessionOpened := SessionOpened;
   FWS.OnSessionClosed := SessionClosed;
   FWS.OnTextMessage := TextArrived;

   // Always running, even with the server stopped: it costs one sleeping
   // thread, and a safety interlock that is only armed some of the time is
   // one more thing to reason about.
   FWatchdog := TTCIWatchdogThread.Create(Self);
end;

(* THE OUTSTANDING-APPLY REGISTER.  See the field declaration for why it
  exists and why it has its own lock. *)

procedure TTCIServer.AttachCommand(aCmd: TObject);
begin
   FCmdLock.Enter;
   try
      FCommands.Add(aCmd);
   finally
      FCmdLock.Leave;
   end;
end;

procedure TTCIServer.DetachCommand(aCmd: TObject);
begin
   FCmdLock.Enter;
   try
      FCommands.Remove(aCmd);
   finally
      FCmdLock.Leave;
   end;
end;

function TTCIServer.OutstandingApplyCount: integer;
begin
   FCmdLock.Enter;
   try
      Result := FCommands.Count;
   finally
      FCmdLock.Leave;
   end;
end;

(* Cancels every apply still pending.  The commands are NOT freed here: each
  one is owned by the queue entry that will run it, and Run frees it there.
  Freeing them now would leave the LCL's async queue holding freed pointers --
  the same defect, moved. *)
procedure TTCIServer.DetachAllCommands;
var
   i: integer;
begin
   FCmdLock.Enter;
   try
      for i := 0 to FCommands.Count - 1 do
         begin
         TTCIApplyCommand(FCommands[i]).Cancel;
         end;
      FCommands.Clear;
   finally
      FCmdLock.Leave;
   end;
end;

destructor TTCIServer.Destroy;
begin
   Stop;
   if Assigned(FWatchdog) then
      begin
      FWatchdog.Stop;
      FWatchdog.WaitFor;
      FreeAndNil(FWatchdog);
      end;
   FreeAndNil(FWS);

   (* AFTER FWS AND THE WATCHDOG, BEFORE FLock.  The client threads are gone by
     here, so nothing can attach a new command behind this call; and every
     command that is still queued must be cancelled before the lock it would
     enter is freed on the next line. *)
   DetachAllCommands;

   FreeAndNil(FLock);
   FreeAndNil(FCommands);
   FreeAndNil(FCmdLock);
   inherited Destroy;
end;

function TTCIServer.Active: boolean;
begin
   Result := (FWS <> nil) and FWS.Active;
end;

function TTCIServer.LastError: string;
begin
   if FWS = nil then
      begin
      Result := '';
      end
   else
      begin
      Result := FWS.LastError;
      end;
end;

function TTCIServer.ClientCount: integer;
begin
   if FWS = nil then
      begin
      Result := 0;
      end
   else
      begin
      Result := FWS.SessionCount;
      end;
end;

function TTCIServer.Start(APort: integer; ABindAll: boolean): boolean;
var
   r: RadioType;
begin
   FPort := APort;
   FBindAll := ABindAll;

   // Forget what we believe clients know.  A fresh listener has no clients,
   // so the first publish must send a full picture rather than a diff
   // against state from the previous run.
   FLock.Enter;
   try
      for r := RadioOne to RadioTwo do
         begin
         FHave[r] := False;
         end;
   finally
      FLock.Leave;
   end;

   Result := FWS.Start(APort, ABindAll);
   if Result then
      begin
      RadioStatusPublished := TCIStatusPublished;
      logger.Info('[TCI-SRV] TCI server offering %d radio(s) on port %d',
                  [ConfiguredRadioCount, APort]);
      end;
end;

procedure TTCIServer.Stop;
begin
   // Detach the hook FIRST, so the polling thread cannot enter a server that
   // is tearing its sessions down.
   RadioStatusPublished := nil;
   if FWS <> nil then
      begin
      FWS.Stop;
      end;
   FLock.Enter;
   try
      FPTTOwner := nil;
      FPTTKeyedAt := 0;
   finally
      FLock.Leave;
   end;
end;

{ ------------------------------------------------------------- sessions -- }

procedure TTCIServer.SessionOpened(Session: TWSServerSession);
begin
   Session.Tag := TTCIClientState.Create;
   SendInitBurst(Session);
end;

procedure TTCIServer.SessionClosed(Session: TWSServerSession);
begin
   // FAIL CLOSED.  A client that dropped while holding the transmitter must
   // not leave a rig keyed with nobody holding it.  This is the single most
   // important line in the unit.
   ReleasePTT(Session);
end;

// Gives up the transmit session WITHOUT unkeying.  Used when a key was
// refused: there is nothing to unkey, and sending an unkey would be a command
// to the radio that no client asked for.
procedure TTCIServer.ReleasePTTOwnership(Session: TWSServerSession);
begin
   FLock.Enter;
   try
      if FPTTOwner = Session then
         begin
         FPTTOwner := nil;
         FPTTKeyedAt := 0;
         end;
   finally
      FLock.Leave;
   end;
end;

procedure TTCIServer.ReleasePTT(Session: TWSServerSession);
var
   wasOwner: boolean;
begin
   wasOwner := False;
   FLock.Enter;
   try
      if (FPTTOwner <> nil) and (FPTTOwner = Session) then
         begin
         FPTTOwner := nil;
         FPTTKeyedAt := 0;
         wasOwner := True;
         end;
   finally
      FLock.Leave;
   end;

   if wasOwner then
      begin
      logger.Warn('[TCI-SRV] client %d dropped while holding PTT - unkeying',
                  [Session.Id]);
      // DIRECTLY, NOT QUEUED.  This used to marshal to the main thread like
      // every other radio command here, and that is wrong for the same reason
      // it is wrong in the watchdog: the cases where a client vanishes
      // mid-transmission include TR4W SHUTTING DOWN, and by then the message
      // loop is tearing down and the queue never drains -- so the unkey never
      // ran and NY4I's K3 was left transmitting after he quit.
      //
      // Safe because the transport is the thread-safe part: SendToRadio takes
      // SocketLock, and uWSJTX already calls tPTTVIACAT from its Indy thread.
      try
         // Both radios: the dropped client may have been holding either, and
         // this path exists to fail closed.
         tPTTVIACATForRadio(@Radio1, False);
         tPTTVIACATForRadio(@Radio2, False);
      except
         on E: Exception do
            begin
            logger.Error('[TCI-SRV] unkey on disconnect failed: %s', [E.Message]);
            end;
      end;
      end;
end;

{ --------------------------------------------------------------- output -- }

procedure TTCIServer.Send(Session: TWSServerSession; const Msg: string);
begin
   if Session = nil then
      begin
      Exit;
      end;
   if TR4W_TCI_DEBUG then
      begin
      logger.Info('[TCI TX %d] %s', [Session.Id, Msg]);
      end
   else
      begin
      logger.Trace('[TCI TX %d] %s', [Session.Id, Msg]);
      end;
   Session.SendText(Msg);
end;

procedure TTCIServer.SendAll(const Msg: string);
begin
   if FWS = nil then
      begin
      Exit;
      end;
   if TR4W_TCI_DEBUG then
      begin
      logger.Info('[TCI TX *] %s', [Msg]);
      end
   else
      begin
      logger.Trace('[TCI TX *] %s', [Msg]);
      end;
   FWS.Broadcast(Msg);
end;

{ ----------------------------------------------------------- init burst -- }

procedure TTCIServer.SendInitBurst(Session: TWSServerSession);
var
   trx:   integer;
   count: integer;
   rig:   RadioPtr;
   snap:  RadioStatusRecord;
   txHz:  integer;
begin
   count := ConfiguredRadioCount;

   // ORDER IS THE CONTRACT.  Identity, then per-receiver state, then the
   // global transmit state, then ready; and start; last.  SDC and CW Skimmer
   // latch their cached settings the moment ready; arrives, so anything sent
   // after it is not seen.
   Send(Session, TCIMsg('vfo_limits', TCIInt(TCI_VFO_LIMIT_LOW), TCIInt(TCI_VFO_LIMIT_HIGH)));
   Send(Session, TCIMsg('if_limits', TCIInt(TCI_IF_LIMIT_LOW), TCIInt(TCI_IF_LIMIT_HIGH)));
   Send(Session, TCIMsg('trx_count', TCIInt(count)));
   Send(Session, TCIMsg('channels_count', TCIInt(TCI_CHANNELS_COUNT)));
   Send(Session, TCIMsg('device', TCI_DEVICE_NAME));
   Send(Session, TCIMsg('receive_only', TCIBool(False)));
   // NOT TCIMsg for these two.  TCIMsg scrubs ',' out of every argument,
   // which is right for a value but wrong here: modulations_list IS a
   // comma-separated list, and 'ExpertSDR3,1.5' is a two-field value.
   // Scrubbing them produced 'expertsdr3_1.5', which is exactly the string
   // WSJT-X fails to match before it halves transmit amplitude.
   Send(Session, TCIMsgFreeText('modulations_list', TCI_MODULATIONS));
   Send(Session, TCIMsgFreeText('protocol', TCI_PROTOCOL_ID));

   for trx := 0 to count - 1 do
      begin
      rig := TrxToRadio(trx);
      if rig = nil then
         begin
         Continue;
         end;
      snap := ReadRadioStatus(rig);

      // Channel 1 is the transmit VFO.  With split off it must still report
      // something coherent -- the receive frequency -- rather than the 0 a
      // blank VFO B holds, which a client would try to tune to.
      if snap.Split and (snap.VFO[VFOB].Frequency > 0) then
         begin
         txHz := snap.VFO[VFOB].Frequency;
         end
      else
         begin
         txHz := snap.VFO[VFOA].Frequency;
         end;

      Send(Session, TCIMsg('vfo', TCIInt(trx), '0', TCIInt(snap.VFO[VFOA].Frequency)));
      Send(Session, TCIMsg('vfo', TCIInt(trx), '1', TCIInt(txHz)));
      Send(Session, TCIMsg('modulation', TCIInt(trx),
                              TR4WModeToTCI(snap.VFO[VFOA].Mode,
                                            snap.VFO[VFOA].ExtendedMode,
                                            snap.VFO[VFOA].Frequency)));
      Send(Session, TCIMsg('rx_enable', TCIInt(trx), TCIBool(True)));
      Send(Session, TCIMsg('rit_enable', TCIInt(trx), TCIBool(snap.RIT)));
      Send(Session, TCIMsg('xit_enable', TCIInt(trx), TCIBool(snap.XIT)));
      Send(Session, TCIMsg('rit_offset', TCIInt(trx), TCIInt(snap.RITFreq)));
      Send(Session, TCIMsg('xit_offset', TCIInt(trx), TCIInt(snap.RITFreq)));

      // split_enable is not decoration.  The RF2K-S amplifier client uses
      // split_enable:0,false as its signal that VFO 0 is the active VFO;
      // without ever receiving it, its current position stays unset and it
      // reports "No TCI available" no matter how many vfo: events arrive.
      Send(Session, TCIMsg('split_enable', TCIInt(trx), TCIBool(snap.Split)));
      Send(Session, TCIMsg('tx_enable', TCIInt(trx),
                              TCIBool(rig = ActiveRadioPtr)));
      end;

   // drive/tune_drive ALWAYS carry <trx>,<power>.  ESDR3-mode WSJT-X and
   // JTDX index args[1] unconditionally, and a one-field 'drive:0;' crashes
   // them.  We do not control rig power, so a constant 100 is the honest
   // answer: "we are not attenuating anything".
   trx := RadioToTrx(ActiveRadioPtr);
   if trx < 0 then
      begin
      trx := 0;
      end;
   Send(Session, TCIMsg('drive', TCIInt(trx), '100'));
   Send(Session, TCIMsg('tune_drive', TCIInt(trx), '100'));
   Send(Session, TCIMsg('trx', TCIInt(trx), TCIBool(False)));

   // ready; LAST, after every setting.  start; is a device-state
   // notification and follows it.  Note what is NOT here: no audio_start and
   // no iq_start.  Those are client-owned, and a server-sent primer wedged
   // SDC before it processed start;.
   Send(Session, TCIMsg('ready'));
   Send(Session, TCIMsg('start'));

   logger.Info('[TCI-SRV] init burst sent to client %d (%d receivers)',
               [Session.Id, count]);
end;

{ -------------------------------------------------------------- inbound -- }

procedure TTCIServer.TextArrived(Session: TWSServerSession; const Text: string);
var
   state: TTCIClientState;
   cmd:   string;
begin
   state := TTCIClientState(Session.Tag);
   if state = nil then
      begin
      Exit;
      end;

   state.Framer.Append(Text);
   if state.Framer.Overflowed then
      begin
      logger.Warn('[TCI-SRV] client %d sent an unterminated flood - closing', [Session.Id]);
      Session.Close;
      Exit;
      end;

   while state.Framer.NextCommand(cmd) do
      begin
      try
         Dispatch(Session, cmd);
      except
         on E: Exception do
            begin
            // One bad command must not kill the connection or the thread.
            logger.Error('[TCI-SRV] client %d: "%s" raised %s - %s',
                         [Session.Id, cmd, E.ClassName, E.Message]);
            end;
      end;
      end;
end;

procedure TTCIServer.Dispatch(Session: TWSServerSession; const Raw: string);
var
   cmd:   TTCICommand;
   state: TTCIClientState;
begin
   if Raw = '' then
      begin
      Exit;
      end;

   // 'split_enable:false' -- the global one-argument form WSJT-X really
   // sends -- becomes 'split_enable:0,false' here, so there is one shape
   // downstream.  Without this it read as a GET for receiver -1 and was
   // answered with silence.
   cmd := TCIExpandGlobalForm(TCIParse(Raw));
   state := TTCIClientState(Session.Tag);

   if TR4W_TCI_DEBUG then
      begin
      logger.Info('[TCI RX %d] %s;', [Session.Id, Raw]);
      end
   else
      begin
      logger.Trace('[TCI RX %d] %s', [Session.Id, Raw]);
      end;

   case TCIClassify(cmd) of
      tcrGet:
         begin
         if cmd.Name = 'start' then
            begin
            state.Started := True;
            end
         else if cmd.Name = 'stop' then
            begin
            state.Started := False;
            end
         else
            begin
            HandleGet(Session, cmd);
            end;
         end;

      tcrSet:
         begin
         HandleSet(Session, cmd);
         end;

      tcrIgnored:
         begin
         // Recognised, server-to-client only.  Mutates nothing, answers
         // nothing -- and is NOT logged as a problem, because a client
         // echoing tx_enable back at us is doing nothing wrong.
         end;
   else
      // Unknown or malformed: SILENCE.  That is what the protocol says and
      // what clients expect; an error reply would be parsed as a command.
      logger.Debug('[TCI-SRV] client %d: ignoring "%s"', [Session.Id, Raw]);
   end;
end;

procedure TTCIServer.HandleGet(Session: TWSServerSession; const Cmd: TTCICommand);
var
   trx:  integer;
   rig:  RadioPtr;
   snap: RadioStatusRecord;
begin
   // The identity commands answer from constants and need no radio.
   if Cmd.Name = 'vfo_limits' then
      begin
      Send(Session, TCIMsg('vfo_limits', TCIInt(TCI_VFO_LIMIT_LOW), TCIInt(TCI_VFO_LIMIT_HIGH)));
      Exit;
      end;
   if Cmd.Name = 'if_limits' then
      begin
      Send(Session, TCIMsg('if_limits', TCIInt(TCI_IF_LIMIT_LOW), TCIInt(TCI_IF_LIMIT_HIGH)));
      Exit;
      end;

   // Stream commands are ECHOED verbatim.  We never send audio, but a client
   // that gets silence here concludes the server is broken and gives up.
   if (Cmd.Name = 'audio_start') or (Cmd.Name = 'audio_stop') or
      (Cmd.Name = 'iq_start') or (Cmd.Name = 'iq_stop') then
      begin
      Send(Session, Cmd.Raw + ';');
      Exit;
      end;

   if (Cmd.Name = 'rx_sensors_enable') or (Cmd.Name = 'tx_sensors_enable') then
      begin
      Send(Session, TCIMsg(Cmd.Name, TCIBool(False)));
      Exit;
      end;

   if Cmd.Name = 'cw_macros_speed' then
      begin
      Send(Session, TCIMsg('cw_macros_speed', TCIInt(CodeSpeed)));
      Exit;
      end;

   // drive/tune_drive: the bare form addresses the active radio.  The REPLY
   // always carries both fields regardless of which form was asked.
   if (Cmd.Name = 'drive') or (Cmd.Name = 'tune_drive') then
      begin
      trx := Cmd.ArgInt(0, RadioToTrx(ActiveRadioPtr));
      if trx < 0 then
         begin
         trx := 0;
         end;
      Send(Session, TCIMsg(Cmd.Name, TCIInt(trx), '100'));
      Exit;
      end;

   // Everything below addresses a receiver, and the receiver is argument 0.
   trx := Cmd.ArgInt(0, -1);
   rig := TrxToRadio(trx);
   if (rig = nil) or (trx >= ConfiguredRadioCount) then
      begin
      // NEVER fall back to radio 0.  A client that asked about receiver 1
      // and got receiver 0's frequency would act on the wrong radio.
      logger.Debug('[TCI-SRV] client %d asked about receiver %d, which is not configured',
                   [Session.Id, trx]);
      Exit;
      end;

   snap := ReadRadioStatus(rig);

   if Cmd.Name = 'vfo' then
      begin
      case Cmd.ArgInt(1, -1) of
         0:
            begin
            Send(Session, TCIMsg('vfo', TCIInt(trx), '0', TCIInt(snap.VFO[VFOA].Frequency)));
            end;
         1:
            begin
            Send(Session, TCIMsg('vfo', TCIInt(trx), '1', TCIInt(snap.VFO[VFOB].Frequency)));
            end;
      else
         // Out of range.  Answering channel 0 would be worse than silence:
         // the client would believe its bad request succeeded.
         logger.Debug('[TCI-SRV] vfo channel %d out of range', [Cmd.ArgInt(1, -1)]);
      end;
      end
   else if Cmd.Name = 'modulation' then
      begin
      Send(Session, TCIMsg('modulation', TCIInt(trx),
                              TR4WModeToTCI(snap.VFO[VFOA].Mode,
                                            snap.VFO[VFOA].ExtendedMode,
                                            snap.VFO[VFOA].Frequency)));
      end
   else if Cmd.Name = 'trx' then
      begin
      Send(Session, TCIMsg('trx', TCIInt(trx), TCIBool(snap.TXOn)));
      end
   else if Cmd.Name = 'tune' then
      begin
      Send(Session, TCIMsg('tune', TCIInt(trx), TCIBool(False)));
      end
   else if Cmd.Name = 'split_enable' then
      begin
      Send(Session, TCIMsg('split_enable', TCIInt(trx), TCIBool(snap.Split)));
      end
   else if Cmd.Name = 'rit_enable' then
      begin
      Send(Session, TCIMsg('rit_enable', TCIInt(trx), TCIBool(snap.RIT)));
      end
   else if Cmd.Name = 'xit_enable' then
      begin
      Send(Session, TCIMsg('xit_enable', TCIInt(trx), TCIBool(snap.XIT)));
      end
   else if Cmd.Name = 'rit_offset' then
      begin
      Send(Session, TCIMsg('rit_offset', TCIInt(trx), TCIInt(snap.RITFreq)));
      end
   else if Cmd.Name = 'xit_offset' then
      begin
      Send(Session, TCIMsg('xit_offset', TCIInt(trx), TCIInt(snap.RITFreq)));
      end
   else if Cmd.Name = 'dds' then
      begin
      // No panadapter: the centre is the receive frequency.
      Send(Session, TCIMsg('dds', TCIInt(trx), TCIInt(snap.VFO[VFOA].Frequency)));
      end
   else if Cmd.Name = 'rx_filter_band' then
      begin
      // We do not read filter edges from the rig.  Report a plausible SSB
      // passband rather than nothing: a client that gets silence here waits.
      Send(Session, TCIMsg('rx_filter_band', TCIInt(trx), '-2700', '-300'));
      end;
end;

procedure TTCIServer.HandleSet(Session: TWSServerSession; const Cmd: TTCICommand);
var
   trx: integer;
   b:   boolean;
   hz:  integer;
begin
   if Cmd.Name = 'cw_msg' then
      begin
      // Accepted and dropped, for now.  Sending arbitrary CW from a network
      // client while the operator is running a contest is a decision, not a
      // detail -- it interleaves with the keyer's own sending and with the
      // interlock.  Silence is the protocol's answer either way.
      logger.Info('[TCI-SRV] client %d sent cw_msg (not implemented): %s',
                  [Session.Id, Cmd.Raw]);
      Exit;
      end;

   if Cmd.Name = 'cw_macros_speed' then
      begin
      logger.Info('[TCI-SRV] client %d asked for %d WPM (not implemented)',
                  [Session.Id, Cmd.ArgInt(0, 0)]);
      Exit;
      end;

   if (Cmd.Name = 'rx_sensors_enable') or (Cmd.Name = 'tx_sensors_enable') then
      begin
      // Acknowledged; we publish no sensor telemetry.
      Send(Session, TCIMsg(Cmd.Name, TCIBool(False)));
      Exit;
      end;

   if (Cmd.Name = 'drive') or (Cmd.Name = 'tune_drive') then
      begin
      // We do not control rig power.  Confirm with what is actually in
      // force, so a client is not left waiting on an acknowledgement.
      trx := Cmd.ArgInt(0, 0);
      Send(Session, TCIMsg(Cmd.Name, TCIInt(trx), '100'));
      Exit;
      end;

   trx := Cmd.ArgInt(0, -1);
   if (TrxToRadio(trx) = nil) or (trx >= ConfiguredRadioCount) then
      begin
      if Cmd.Name = 'trx' then
         begin
         // A REFUSED PTT MUST BE ANSWERED.  Refusing in silence is what
         // WSJT-X surfaces as "TCI failed to set ptt" with no cause.
         Send(Session, TCIMsg('trx', TCIInt(Cmd.ArgInt(0, 0)), TCIBool(False)));
         end;
      logger.Debug('[TCI-SRV] client %d addressed receiver %d, which is not configured',
                   [Session.Id, trx]);
      Exit;
      end;

   if Cmd.Name = 'vfo' then
      begin
      hz := Cmd.ArgInt(2, -1);
      if hz <= 0 then
         begin
         Exit;
         end;
      ApplyFrequency(trx, Cmd.ArgInt(1, -1), hz, Session);
      end
   else if Cmd.Name = 'modulation' then
      begin
      ApplyModulation(trx, Cmd.Arg(1), Session);
      end
   else if Cmd.Name = 'trx' then
      begin
      if not Cmd.ArgBool(1, b) then
         begin
         // Not a boolean.  Do not guess -- but this is PTT, so say no.
         Send(Session, TCIMsg('trx', TCIInt(trx), TCIBool(False)));
         Exit;
         end;
      ApplyPTT(Session, trx, b);
      end
   else if Cmd.Name = 'split_enable' then
      begin
      if Cmd.ArgBool(1, b) then
         begin
         ApplySplit(trx, b);
         end;
      end
   else if Cmd.Name = 'tune' then
      begin
      // Tune (carrier for an ATU) is not offered.  Confirm off rather than
      // leave the client waiting for an acknowledgement it will not get.
      Send(Session, TCIMsg('tune', TCIInt(trx), TCIBool(False)));
      end;

   // rit/xit offsets and rx_filter_band SETs are accepted into silence for
   // now: the factory exposes no setter for them that is safe to drive from
   // a network client mid-contest.  Adding one is a separate change.
end;

{ ------------------------------------------------------------ the applies -- }

procedure TTCIServer.ApplyFrequency(Trx, Channel, Hz: integer;
                                    Session: TWSServerSession);
var
   rig: RadioPtr;
begin
   // Range-check the channel.  'vfo:0,2,...' must produce no request at all
   // rather than being treated as channel 0.
   if (Channel <> 0) and (Channel <> 1) then
      begin
      logger.Debug('[TCI-SRV] vfo channel %d out of range - ignored', [Channel]);
      Exit;
      end;
   if (Hz < TCI_VFO_LIMIT_LOW) or (Hz > TCI_VFO_LIMIT_HIGH) then
      begin
      logger.Debug('[TCI-SRV] %d Hz is outside the announced limits - ignored', [Hz]);
      Exit;
      end;

   rig := TrxToRadio(Trx);
   if rig = nil then
      begin
      Exit;
      end;

   // Marshalled: SetRadioFreq writes program globals and the display
   // routines around it belong to the main thread.
   PostTCIApply(TTCIApplyFreq.Create(Self, rig, Trx, Channel, Hz));

   // CONFIRM IMMEDIATELY, AND CONFIRM WHAT WE ACCEPTED.  WSJT-X's
   // do_frequency() waits about two seconds for this echo and then reports
   // rig-control failure and drops the socket -- and a stale echo is worse
   // than none, because it reports a frequency the radio has already left.
   // The poll that follows will broadcast the truth if the radio disagreed,
   // which is the whole confirm-then-reconcile contract.
   Send(Session, TCIMsg('vfo', TCIInt(Trx), TCIInt(Channel), TCIInt(Hz)));
end;

procedure TTCIServer.ApplyModulation(Trx: integer; const Modulation: string;
                                     Session: TWSServerSession);
var
   rig:      RadioPtr;
   mode:     ModeType;
   extended: ExtendedModeType;
   slot:     RadioType;
begin
   if not TCIToTR4WMode(Modulation, mode, extended) then
      begin
      logger.Debug('[TCI-SRV] unknown modulation "%s" - ignored', [Modulation]);
      Exit;
      end;
   rig := TrxToRadio(Trx);
   if rig = nil then
      begin
      Exit;
      end;

   // Recorded BEFORE the queue, so a vfo command arriving microseconds later
   // -- which is exactly what WSJT-X does -- carries this mode rather than
   // the stale one from the last poll.
   slot := SlotOf(Trx);
   FLock.Enter;
   try
      FPendingMode[slot].Active := True;
      FPendingMode[slot].Mode := mode;
      FPendingMode[slot].Extended := extended;
   finally
      FLock.Leave;
   end;

   PostTCIApply(TTCIApplyMode.Create(Self, rig, mode, extended));

   // CONFIRM, exactly as a tune is confirmed.  WSJT-X's do_mode() waits on
   // this echo and reports "TCI failed set mode" and drops the socket without
   // it -- observed: modulation:0,digu accepted at 13:30:44.948, no reply,
   // client gone at 13:30:46.151.  The echo is what we ACCEPTED; the poll
   // broadcasts the truth afterwards if the radio disagreed.
   if Session <> nil then
      begin
      Send(Session, TCIMsg('modulation', TCIInt(Trx), LowerCase(Trim(Modulation))));
      end;
end;

procedure TTCIServer.ApplySplit(Trx: integer; TurnOn: boolean);
var
   rig:  RadioPtr;
   snap: RadioStatusRecord;
begin
   rig := TrxToRadio(Trx);
   if rig = nil then
      begin
      Exit;
      end;

   snap := ReadRadioStatus(rig);

   // A STEADY false IS NOT AN EDGE.  WSJT-X sends split_enable:<n>,false as
   // part of its normal sequence BEFORE programming channel 1, and acting on
   // it every time would tear down a split the operator had just set up.
   // Only a real transition does anything.
   if snap.Split = TurnOn then
      begin
      Exit;
      end;

   PostTCIApply(TTCIApplySplit.Create(Self, rig, TurnOn));
end;

procedure TTCIServer.ApplyPTT(Session: TWSServerSession; Trx: integer;
                              KeyDown: boolean);
var
   rig:      RadioPtr;
   state:    TTCIClientState;
   accepted: boolean;
   snap:     RadioStatusRecord;
begin
   rig := TrxToRadio(Trx);
   state := TTCIClientState(Session.Tag);
   if (rig = nil) or (state = nil) then
      begin
      Send(Session, TCIMsg('trx', TCIInt(Trx), TCIBool(False)));
      Exit;
      end;

   accepted := False;
   FLock.Enter;
   try
      if KeyDown then
         begin
         // One owner at a time.  A second client's key is refused while the
         // first holds it -- and refused OUT LOUD, because a silent refusal
         // is what WSJT-X reports as "TCI failed to set ptt" with no cause.
         if (FPTTOwner = nil) or (FPTTOwner = Session) then
            begin
            FPTTOwner := Session;
            // Stamped only on a fresh key, so a client that re-sends
            // trx:<n>,true during a transmission cannot keep pushing the
            // watchdog deadline out for ever.
            if FPTTKeyedAt = 0 then
               begin
               FPTTKeyedAt := GetTickCount;
               end;
            state.OwnsPTT := True;
            accepted := True;
            end;
         end
      else
         begin
         // A client may only release a session it owns.  An unowned
         // trx:<n>,false must NEVER unkey the operator, or VOX, or another
         // client -- it reports the actual state instead.
         if FPTTOwner = Session then
            begin
            FPTTOwner := nil;
            FPTTKeyedAt := 0;
            state.OwnsPTT := False;
            accepted := True;
            end;
         end;
   finally
      FLock.Leave;
   end;

   if not accepted then
      begin
      if KeyDown then
         begin
         logger.Warn('[TCI-SRV] client %d asked to key while another client holds PTT',
                     [Session.Id]);
         Send(Session, TCIMsg('trx', TCIInt(Trx), TCIBool(False)));
         end
      else
         begin
         snap := ReadRadioStatus(rig);
         Send(Session, TCIMsg('trx', TCIInt(Trx), TCIBool(snap.TXOn)));
         end;
      Exit;
      end;

   // CONFIRMED FROM THE RESULT, NOT FROM HAVING ASKED.
   //
   // tPTTVIACAT has THREE gates before anything reaches the radio, and two of
   // them exit in near-silence (LOGRADIO.PAS:3037):
   //   1. 'PTT VIA COMMANDS' false  -> one DEBUG line, nothing sent
   //   2. Config.NoPollDuringPTT           -> no log at all, nothing sent
   //   3. it keys ActiveRadio, NOT the receiver the client addressed
   // It returns False in the first two cases and every caller in the program
   // ignores that.  Confirming trx:<n>,true after one of them fires tells the
   // client it is transmitting while the rig sits there -- the exact class of
   // silent downgrade this project keeps paying for, and worse here because
   // the subject is a transmitter.
   //
   // So the queued apply reports back, and the confirmation is sent from the
   // MAIN thread once the answer is known.  A refused key still gets an
   // explicit trx:<n>,false -- silence is what WSJT-X surfaces as "TCI failed
   // to set ptt" with no cause.
   PostTCIApply(TTCIApplyPTT.Create(Self, rig, Trx, KeyDown, Session));
end;

{ ------------------------------------------------------------ broadcast -- }

procedure TTCIServer.CheckTransmitTimeout;
var
   owner:   TWSServerSession;
   keyedAt: cardinal;
   elapsed: cardinal;
   limit:   cardinal;
begin
   if TR4W_TCI_MAX_TX_SECONDS <= 0 then
      begin
      Exit;      // deliberately disabled
      end;
   limit := cardinal(TR4W_TCI_MAX_TX_SECONDS) * 1000;

   FLock.Enter;
   try
      owner := FPTTOwner;
      keyedAt := FPTTKeyedAt;
   finally
      FLock.Leave;
   end;

   // No TCI client is holding the transmitter.  In particular this is how a
   // transmission the OPERATOR started is left alone -- the watchdog has no
   // business unkeying something it did not key.
   if (owner = nil) or (keyedAt = 0) then
      begin
      Exit;
      end;

   // Unsigned subtraction, so the 49.7-day GetTickCount wrap is handled
   // rather than producing an enormous elapsed and an instant false trip.
   elapsed := GetTickCount - keyedAt;
   if elapsed < limit then
      begin
      Exit;
      end;

   logger.Error('[TCI-SRV] WATCHDOG: client %d has held the transmitter for %d s ' +
                '(limit %d s) - unkeying',
                [owner.Id, elapsed div 1000, TR4W_TCI_MAX_TX_SECONDS]);

   FLock.Enter;
   try
      FPTTOwner := nil;
      FPTTKeyedAt := 0;
   finally
      FLock.Leave;
   end;

   // CALLED DIRECTLY, NOT VIA TThread.Queue.  Everywhere else in this unit a
   // radio command is marshalled to the main thread, and that is right for a
   // tune: SetRadioFreq writes program globals.  It is WRONG here.  A stalled
   // main thread is one of the things that could have produced a stuck
   // transmitter in the first place, so a safety unkey must not queue behind
   // it.  This is safe because the transport is the thread-safe part --
   // SendToRadio takes SocketLock, and uWSJTX already calls tPTTVIACAT from
   // its Indy connection thread.
   try
      // Both radios, for the same reason as the disconnect path: a
      // watchdog that unkeys only the active radio is not a watchdog.
      if (not tPTTVIACATForRadio(@Radio1, False)) and
         (not tPTTVIACATForRadio(@Radio2, False)) then
         begin
         logger.Error('[TCI-SRV] WATCHDOG: the unkey was REFUSED -- ' +
                      'check "PTT VIA COMMANDS" and NO POLL DURING PTT');
         end;
   except
      on E: Exception do
         begin
         logger.Error('[TCI-SRV] WATCHDOG: unkey failed: %s', [E.Message]);
         end;
   end;

   // Tell every client, including the one that was holding it: its next
   // trx:<n>,false would otherwise be refused as unowned and it would never
   // learn the session was taken away.
   SendAll(TCIMsg('trx', TCIInt(RadioToTrx(ActiveRadioPtr)), TCIBool(False)));
end;

function TTCIServer.SlotOf(Trx: integer): RadioType;
begin
   if Trx = 1 then
      begin
      Result := RadioTwo;
      end
   else
      begin
      Result := RadioOne;
      end;
end;

procedure TTCIServer.PublishRadioState(rig: RadioPtr);
var
   trx:  integer;
   r:    RadioType;
   snap: RadioStatusRecord;
   prev: RadioStatusRecord;
   first: boolean;
begin
   if (FWS = nil) or (not FWS.Active) or (FWS.SessionCount = 0) then
      begin
      Exit;
      end;

   trx := RadioToTrx(rig);
   if trx < 0 then
      begin
      Exit;
      end;
   if trx = 0 then
      begin
      r := RadioOne;
      end
   else
      begin
      r := RadioTwo;
      end;

   // Coherent by construction: the poll loop calls us AFTER EndStatusPublish,
   // so this copy is taken from a settled seqlock on the first attempt.
   snap := ReadRadioStatus(rig);

   // TRANSMIT STATE COMES FROM THE LIVE STATUS, NOT THE FILTERED ONE.
   //
   // ReadRadioStatus returns FilteredStatus, which UpdateStatus debounces by
   // a poll cycle.  That debounce exists to stop the DISPLAY flickering on
   // frequency jitter, and it is right for frequency.  It is wrong for PTT:
   // transmit state is binary, it does not jitter, and it is the one value
   // where being late is the whole problem.  Measured on NY4I's bench
   // 2026-08-09: RX; reached the K3 2 ms after the request, but the
   // trx:0,false broadcast telling other clients about it came 725 ms later,
   // purely because of the debounce.
   snap.TXOn := ReadRadioCurrentStatus(rig).TXOn;

   FLock.Enter;
   try
      first := not FHave[r];
      prev := FLast[r];
      FLast[r] := snap;
      FHave[r] := True;

      // The radio has caught up: stop overriding the snapshot, so a mode the
      // operator sets on the front panel is not fought on the next QSY.
      if FPendingMode[r].Active and
         (snap.VFO[VFOA].Mode = FPendingMode[r].Mode) then
         begin
         FPendingMode[r].Active := False;
         end;
   finally
      FLock.Leave;
   end;

   // Single writer (the poll loop for this radio), so the diff is race-free
   // without holding the lock across the broadcast.
   BroadcastRadio(trx, snap, prev, first);
end;

procedure TTCIServer.BroadcastRadio(Trx: integer; const Cur, Was: RadioStatusRecord;
                                    First: boolean);
var
   txNow, txPrev: integer;
begin
   // Only what CHANGED goes on the wire.  A poll cycle runs several times a
   // second per radio; re-sending an unchanged picture to every client would
   // be pure noise, and a broadcast protocol's whole point is that clients
   // can trust a message to mean something moved.
   if First or (Cur.VFO[VFOA].Frequency <> Was.VFO[VFOA].Frequency) then
      begin
      SendAll(TCIMsg('vfo', TCIInt(Trx), '0', TCIInt(Cur.VFO[VFOA].Frequency)));
      end;

   // Channel 1 follows VFO B while split is on, and the receive frequency
   // otherwise -- never the 0 a blank VFO B holds, which a client would try
   // to tune to.
   if Cur.Split and (Cur.VFO[VFOB].Frequency > 0) then
      begin
      txNow := Cur.VFO[VFOB].Frequency;
      end
   else
      begin
      txNow := Cur.VFO[VFOA].Frequency;
      end;
   if Was.Split and (Was.VFO[VFOB].Frequency > 0) then
      begin
      txPrev := Was.VFO[VFOB].Frequency;
      end
   else
      begin
      txPrev := Was.VFO[VFOA].Frequency;
      end;
   if First or (txNow <> txPrev) then
      begin
      SendAll(TCIMsg('vfo', TCIInt(Trx), '1', TCIInt(txNow)));
      end;

   if First or (Cur.VFO[VFOA].Mode <> Was.VFO[VFOA].Mode) or
      (Cur.VFO[VFOA].ExtendedMode <> Was.VFO[VFOA].ExtendedMode) then
      begin
      SendAll(TCIMsg('modulation', TCIInt(Trx),
                           TR4WModeToTCI(Cur.VFO[VFOA].Mode,
                                         Cur.VFO[VFOA].ExtendedMode,
                                         Cur.VFO[VFOA].Frequency)));
      end;

   if First or (Cur.Split <> Was.Split) then
      begin
      SendAll(TCIMsg('split_enable', TCIInt(Trx), TCIBool(Cur.Split)));
      end;

   if First or (Cur.RIT <> Was.RIT) then
      begin
      SendAll(TCIMsg('rit_enable', TCIInt(Trx), TCIBool(Cur.RIT)));
      end;

   if First or (Cur.XIT <> Was.XIT) then
      begin
      SendAll(TCIMsg('xit_enable', TCIInt(Trx), TCIBool(Cur.XIT)));
      end;

   if First or (Cur.RITFreq <> Was.RITFreq) then
      begin
      SendAll(TCIMsg('rit_offset', TCIInt(Trx), TCIInt(Cur.RITFreq)));
      end;

   // Transmit state last, and unconditionally on change: this is the message
   // that corrects an optimistic PTT confirmation, so it must never be
   // filtered out by a cleverer diff.
   if First or (Cur.TXOn <> Was.TXOn) then
      begin
      SendAll(TCIMsg('trx', TCIInt(Trx), TCIBool(Cur.TXOn)));
      end;
end;

end.
