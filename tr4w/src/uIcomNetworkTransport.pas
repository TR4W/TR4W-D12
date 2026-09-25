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
unit uIcomNetworkTransport;
{$I tr4w.inc}

{
  Icom Network Transport Layer

  Implements the Icom proprietary UDP network protocol for controlling
  Icom radios over Ethernet/WiFi. Manages the full connection lifecycle:
  handshake, authentication, CI-V data framing, keepalives, and retransmit.

  Architecture:
    - Two TIdUDPServer instances (control + CI-V) with threaded OnUDPRead callbacks
    - ONE OWNED TIMER THREAD for the six protocol deadlines -- see TIcomTimerThread
    - Critical section protects all socket sends
    - CI-V data extracted from UDP packets and forwarded via OnCivData callback

  Protocol flow matches wfview/SDR-Control reference implementations:
    - All auth packets (login, token, stream request) route through
      SendTrackedPacket with the unified FSendSeq counter
    - Idle keepalive on control socket only (not CI-V)
    - Ping + idle timers start at "I Am Here" (during handshake)
    - Token timer starts at login response
    - CI-V handshake happens within Connected state
    - Packet dispatch by PktType, with length-based disambiguation for
      type=0x00 control socket packets (login/token/status/capabilities/conninfo).
    - No RX sequence tracking (wfview doesn't use it either)

  Reference: docs/ICOM_NETWORK_DELPHI_REFERENCE.md
}

interface

uses
  (* Windows and Messages are gone with the WinSock send path (2026-09-08).
    What is left of them: GetTickCount64 and Sleep are SysUtils', the thread
    wait is the RTL's WaitForThreadTerminate, and nothing here handles a
    window message.

    AND ExtCtrls IS GONE TOO (2026-09-24).  The six protocol timers were LCL
    TTimers and NOT ONE OF THEM EVER FIRED -- see TIcomTimerThread for the
    measurement and the mechanism.  This unit owns a plain TThread now and
    needs no widget set at all. *)
  SysUtils, Classes, SyncObjs, StrUtils,
  IdUDPServer, IdSocketHandle, IdGlobal, IdComponent,
  IdStackConsts,   (* Id_SOL_SOCKET / Id_SO_RCVBUF / Id_SOCK_DGRAM -- Indy's
                     names for what WinSock's SOL_SOCKET, SO_RCVBUF and
                     SOCK_DGRAM used to supply here. *)
  uIcomNetworkTypes, uFactoryRadioBase, Log4D,
  utils_text;

(* THE ws2_32.dll IMPORT IS GONE (2026-09-08). See SendRawPacket for what
  replaced it and why the instrumentation around it is shaped as it is.

  NY4I: "On the icom, we have to switch back to indy and we will bench test to
  determine the issue. Using WinSock is no longer an option." *)

const
  (* A UDP send to a radio on the LAN is sub-millisecond. Anything past this is
    contention worth a log line -- the survivable form of the deadlock this
    instrumentation exists to catch. Deliberately low; noise here is the point. *)
  SEND_SLOW_MS = 20;

  (* WAIT_TIMEOUT's value ($102), named locally because it came from the
    Windows unit and this unit no longer uses it. WaitForThreadTerminate
    returns WaitForSingleObject's result unchanged on Windows. *)
  WAIT_TIMEOUT_RESULT = $00000102;

type
  TIcomNetworkTransport = class(TObject)
  private
    // State
    FState: TIcomConnectionState;
    FRadioAddress: string;           // IP address of radio
    FControlPort: Word;              // Default 50001
    FCivPort: Word;                  // Learned from radio during handshake
    FUsername: string;
    FPassword: string;
    FClientName: string;             // "TR4W"

    // IDs
    FMyId: LongWord;                 // Calculated from local IP/port
    FCivMyId: LongWord;              // Calculated from CI-V local IP/port
    FRemoteId: LongWord;             // Radio's control socket ID
    FCivRemoteId: LongWord;          // Radio's CI-V socket ID (DIFFERENT!)
    FToken: LongWord;               // Auth token from login response
    FAuthStartId: Word;             // From login response
    FTokRequest: Word;              // Random token request ID

    // Sockets
    FControlSocket: TIdUDPServer;    // Control/auth socket
    FCivSocket: TIdUDPServer;        // CI-V data socket

    // Sequence counters (matches wfview exactly)
    FSendSeq: Word;                  // Control socket outer sequence (starts at 1)
    FCivSeq: Word;                   // CI-V socket outer sequence (starts at 1)
    FCivInnerSeq: Word;              // CI-V stream inner sequence (starts at 0)
    FAuthSeq: Word;                  // Auth inner payload sequence (big-endian, starts at $30)
    FPingSendSeq: Word;              // Ping sequence (untracked)

    (* HOW MANY SENDS ARE INSIDE INDY RIGHT NOW -- instrumentation for the
      ws2_32 -> Indy switch, see SendRawPacket. Interlocked, NOT under
      FSendLock: the lock is what a deadlock would be waiting on, so this has
      to be readable without taking it. *)
    FSendInFlight: LongInt;

    // Capabilities
    FRadioName: string;              // From capabilities packet
    FCivAddress: Byte;               // CI-V address from capabilities
    FMacAddress: array[0..5] of Byte;
    FCommonCap: Word;

    (* WHICH TRANSPORT OBJECT WROTE THIS LINE.

      Every log line this unit writes carries it, and the reason is a defect
      that could not be diagnosed without it: on 2026-09-24 three transports
      existed at once, two of them FREED, and their abandoned Indy listener
      threads went on logging "Received packet ... state=..." against dead
      memory.  The state values in those lines were garbage -- Unknown,
      WaitingForReady and Disconnected from the same thread seconds apart --
      and read as a state machine misbehaving rather than as a use-after-free,
      because nothing in the line said WHICH object.

      FRadioName alone cannot serve: it is empty until capabilities arrive, so
      every transport that fails during the handshake logs under the same
      name -- and a handshake failure is exactly when several exist at once. *)
    FInstanceId: LongInt;

    (* THE SIX PROTOCOL DEADLINES, still addressed by the ICOM_TIMER_* id the
      protocol code has always used, so every call site reads as it did.
      FTimerEvery[id] = 0 means that timer is off; otherwise FTimerDue[id] is
      the TickCount32 at which it next fires.  Index 5004 is unassigned and is
      simply never armed.

      BOTH ARRAYS ARE WRITTEN FROM THE INDY READER THREADS and read from the
      timer thread, so FTimerLock covers every access to either. *)
    FTimerEvery: array[ICOM_TIMER_PING..ICOM_TIMER_LOGIN] of LongWord;
    FTimerDue:   array[ICOM_TIMER_PING..ICOM_TIMER_LOGIN] of LongWord;
    FTimerLock:  TCriticalSection;
    FTimerThread: TThread;
    (* What FTimerWnd <> 0 used to mean at six guard sites: the connection is
      up and its timers may run.  It was standing in for this. *)
    FTimersLive: boolean;
    FLastCivData: LongWord;          // TickCount32 of last CI-V data
    FLastPingReceived: LongWord;     // TickCount32 of last ping request from radio (0 = never)
    (* TickCount32 of the last TRACKED send on either socket.  A tracked send
      IS a keepalive, so the idle timer skips its turn when one is recent.
      This REPLACES restarting the idle timer from inside SendTrackedPacket:
      that ran on the CI-V send thread and mutated the widget set's timer list
      from there.  A LongWord store is atomic on every target we build for, so
      this needs no lock. *)
    FLastTrackedSend: LongWord;
    (* Set by a reader thread when the radio says this session has no owner;
      acted on by the timer thread.  IT IS NOT ACTED ON INLINE, because the
      response is Disconnect, and Disconnect frees the very TIdUDPServer whose
      listener thread would be running the handler.  See HandleConnInfoPacket. *)
    FSessionRevoked: Boolean;
    FStartTick: LongWord;            // TickCount32 at connect start
    FAYTRetryCount: Integer;         // Are You There retry counter
    FAYTInterval: Integer;           // Current AYT retry interval (backoff)
    FLoginRetryCount: Integer;       // Login retry counter (for stale-session recovery)

    // CI-V stream state (handshake within Connected state)
    FCivStreamOpen: Boolean;         // True after CI-V Open sent
    FAuthFailed: Boolean;            // True if auth was rejected (bad credentials)

    // TX buffer: stores sent packets for responding to radio's retransmit requests
    FControlTxBuf: TList;            // List of PSeqBufEntry (control socket)
    FCivTxBuf: TList;                // List of PSeqBufEntry (CI-V socket)

    // Thread safety
    FSendLock: TCriticalSection;
    (* CONNECT AND DISCONNECT, ONE AT A TIME.

      Disconnect frees the sockets and Connect builds them, so the two must
      never overlap -- that is a use-after-free on FControlSocket, not a
      subtlety.  They have always been reachable from more than one thread
      (the polling thread, the main thread, and the Indy reader thread, which
      calls Disconnect when the radio sends $0005 or a stream request fails),
      but the collision was rare enough never to have been reported.

      IT IS NOT RARE ANY MORE: the timer thread now actually runs, and three
      of its handlers end in Disconnect.  Making those paths reachable without
      serialising them would be shipping a race.

      RECURSIVE ON PURPOSE -- Connect calls Disconnect on the same thread when
      it is asked to connect an already-open transport, and a TCriticalSection
      is re-entrant for its owning thread on every target we build for. *)
    FLifecycleLock: TCriticalSection;

    // Callbacks
    FOnCivData: TProcessMsgRef;
    FOnStateChange: TNotifyEvent;

    // Internal - packet building and sending
    procedure SendControlPacket(PktType: Word; Socket: TIdUDPServer;
      RemoteId: LongWord; TargetAddr: string; TargetPort: Word;
      Seq: Word);
    procedure SendPingResponse(const Data: array of Byte; DataLen: Integer;
      Socket: TIdUDPServer; TargetAddr: string; TargetPort: Word);
    procedure SendPing;
    procedure SendLoginPacket;
    procedure SendTokenAck;
    procedure SendTokenRenew;
    procedure SendStreamRequest;
    procedure SendCivOpen;
    procedure SendCivClose;
    procedure SendIdlePacket;
    procedure SendRawPacket(Socket: TIdUDPServer; const Data; DataLen: Integer;
      TargetAddr: string; TargetPort: Word);

    // Internal - packet handling
    procedure HandleControlUDPRead(AThread: TIdUDPListenerThread;
      const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure HandleCivUDPRead(AThread: TIdUDPListenerThread;
      const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure HandleReceivedPacket(const Data: array of Byte; DataLen: Integer;
      FromCivSocket: Boolean; PeerIP: string; PeerPort: Word);
    procedure HandleControlResponse(const Data: array of Byte; DataLen: Integer;
      FromCivSocket: Boolean);
    procedure HandlePingPacket(const Data: array of Byte; DataLen: Integer;
      FromCivSocket: Boolean; PeerIP: string; PeerPort: Word);
    procedure HandleLoginResponse(const Data: array of Byte; DataLen: Integer);
    procedure HandleCapabilities(const Data: array of Byte; DataLen: Integer);
    procedure HandleStatusPacket(const Data: array of Byte; DataLen: Integer);
    procedure HandleConnInfoPacket(const Data: array of Byte; DataLen: Integer);
    procedure HandleTokenResponse(const Data: array of Byte; DataLen: Integer);
    procedure HandleDataPacket(const Data: array of Byte; DataLen: Integer);
    procedure ExtractCivFrames(const Data: array of Byte; DataLen: Integer);

    (* The prefix on every log line this unit writes: instance, then radio
      name once one is known.  See FInstanceId. *)
    function LogPrefix: string;

    // Internal - state management
    procedure SetState(NewState: TIcomConnectionState);
    function GetIsConnected: Boolean;
    function GetCivDataFresh: Boolean;

    // Internal - timer callbacks
    procedure TimerTick;                             // the timer thread's whole job
    procedure DispatchTimer(const aId: integer);
    procedure StartTimer(const aId: integer; const aMs: integer);
    procedure StopTimer(const aId: integer);
    procedure StopAllTimers;
    procedure StopTimers;
    procedure OnPingTimer;
    procedure OnIdleTimer;
    procedure OnTokenRenewalTimer;
    procedure OnCivWatchdogTimer;
    procedure OnAYTTimer;
    procedure OnLoginTimer;

    // Internal - tracked send (central path for all sequenced sends)
    procedure SendTrackedPacket(Socket: TIdUDPServer; const Data: AnsiString;
      TargetAddr: string; TargetPort: Word; var SeqCounter: Word);

    // Internal - buffer management
    procedure AddToTxBuffer(BufList: TList; Seq: Word; const Data: AnsiString);
    function FindInTxBuffer(BufList: TList; Seq: Word): AnsiString;
    procedure ClearTxBuffer(BufList: TList);
    procedure ClearAllBuffers;

    // Internal - retransmit (respond to radio's requests)
    procedure HandleRetransmitRequest(const Data: array of Byte; DataLen: Integer;
      FromCivSocket: Boolean);

    // Internal - socket setup
    procedure CreateSockets;
    procedure DestroySockets;

    // Internal - ID calculation
    function GetLocalIPForRoute: string;
    function CalculateMyIdFromSocket(Socket: TIdUDPServer): LongWord;

  public
    constructor Create;
    destructor Destroy; override;

    // Connection lifecycle
    function Connect(Address: string; Port: Word;
      Username, Password: string): Integer;
    procedure Disconnect;

    // CI-V data send
    procedure SendCivData(const CivFrame: string);

    // Properties
    property State: TIcomConnectionState read FState;
    property IsConnected: Boolean read GetIsConnected;
    // True while inbound CI-V data has been seen recently (the radio is actually
    // answering).  Goes False when the radio stops responding -- the liveness
    // signal the connectionless UDP transport otherwise lacks.  Issue #1062.
    property CivDataFresh: Boolean read GetCivDataFresh;
    property RadioName: string read FRadioName write FRadioName;
    property CivAddress: Byte read FCivAddress;
    property OnCivData: TProcessMsgRef read FOnCivData write FOnCivData;
    property OnStateChange: TNotifyEvent read FOnStateChange write FOnStateChange;
    property AuthFailed: Boolean read FAuthFailed;
  end;

implementation

(* NO `uses WinSock` ANY MORE (2026-09-08). Everything it supplied -- sendto,
  socket, connect, getsockname, inet_addr, inet_ntoa, htons, closesocket and
  setsockopt -- now goes through Indy, which is already this unit's transport
  for receiving. *)

var
  logger: TLogLogger;

(* A 32-BIT MILLISECOND TICK, WHICH IS WHAT THIS PROTOCOL IS BUILT ON.

  Was Windows.GetTickCount. The RTL's GetTickCount64 is the portable clock,
  but the width here is NOT free to change: FStartTick, FLastCivData and
  FLastPingReceived are LongWord, and TIcomPingPacket.Time is a LongWord
  ON THE WIRE -- "$11 - Uptime in ms", read by the radio. So this truncates
  deliberately, and every comparison in this unit is a DIFFERENCE of two of
  these values, which stays correct across the 49.7-day wrap. *)
function TickCount32: LongWord; inline;
begin
   Result := LongWord(GetTickCount64);
end;

function BytesToHexStr(const Data; DataLen: Integer): string; forward;

(* THE SIX PROTOCOL TIMERS, AS ONE OWNED THREAD.

  THEY WERE LCL TTimers, AND NOT ONE OF THEM EVER FIRED.  That is measured,
  not suspected.  Bench capture of an IC-7760 over LAN, 2026-09-24, 663
  seconds and 60,719 packets:

    - self-initiated pings           0   (our ping count equalled the radio's
                                          EXACTLY -- we only ever replied)
    - idle keepalives we sent        0   (the radio sent us 6,295)
    - token renewals we sent         0   (across sessions of 70 to 83 s,
                                          against a 60 s renewal interval)

  THE MECHANISM.  Every StartTimer call site here is reached from an Indy UDP
  reader thread -- HandleLoginResponse, HandleControlResponse and
  HandleCapabilities all run there, and this unit's own log line says so
  beside each one ("thread=16096 mainthread=False").  The LCL's Win32 TTimer
  is win32object.inc:628, Windows.SetTimer(0, 0, Interval, @TimerCallBackProc):
  a NULL window means WM_TIMER is posted to the CALLING THREAD'S queue.  An
  Indy reader thread has no message pump, so the callback is never dispatched.

  The comment that stood here predicted exactly this -- "if a bench run shows
  a keepalive being delayed behind UI work, the answer is a threaded timer,
  not a window" -- and was wrong only about how bad it was.  The keepalives
  were not delayed.  They did not happen.

  WHAT IT COST.  The token was never renewed, so the radio expired the session
  ~90.6 s after each login and stopped answering CI-V -- thirteen times in the
  capture, each costing 12.3 s to recover.  The probe that proved it (renewal
  driven off the radio's inbound pings) ran the first Icom LAN session in this
  program's history past 91 seconds, then eight minutes on one unchanged
  token.  THE PROBE IS NOT KEPT: a keepalive that depends on the radio talking
  to us is the wrong shape, and two mechanisms doing one job drift.  This
  thread is the one that has to work.

  ADDRESSED BY THE SAME IDS, deliberately, so no protocol call site changed.

  AND IT NEEDS NO WIDGET SET, which matters past this defect: a TTimer needs
  an LCL, and a transport should not. *)
type
   TIcomTimerThread = class(TThread)
   private
      FOwner: TIcomNetworkTransport;
      FWake:  TSimpleEvent;          // so Stop does not wait out a whole tick
   protected
      procedure Execute; override;
   public
      constructor Create(const aOwner: TIcomNetworkTransport);
      destructor Destroy; override;
      procedure Stop;
   end;

constructor TIcomTimerThread.Create(const aOwner: TIcomNetworkTransport);
begin
   FOwner := aOwner;
   FWake  := TSimpleEvent.Create;
   inherited Create(False);
end;

destructor TIcomTimerThread.Destroy;
begin
   inherited Destroy;
   FreeAndNil(FWake);
end;

procedure TIcomTimerThread.Stop;
begin
   Terminate;
   FWake.SetEvent;
end;

procedure TIcomTimerThread.Execute;
begin
   while not Terminated do
      begin
      (* AN EXCEPTION HERE MUST NOT KILL THE THREAD.  If it did, every
        keepalive would stop and the only symptom would be the radio dropping
        us a minute later -- which is the exact failure this thread exists to
        end.  DispatchTimer guards each handler; this is the backstop for
        anything the tick itself raises. *)
      try
         FOwner.TimerTick;
      except
         on E: Exception do
            begin
            logger.Error(FOwner.LogPrefix + ' Timer thread caught %s: %s', [E.ClassName, E.Message]);
            end;
      end;

      FWake.WaitFor(ICOM_TIMER_TICK_MS);
      FWake.ResetEvent;
      end;
end;

(* ONE PASS OVER THE SIX DEADLINES.

  The due set is decided and the next deadlines written UNDER THE LOCK; the
  handlers then run OUTSIDE it, because a handler sends packets and may call
  Disconnect, and holding a lock across either is how a transport deadlocks.

  "Due" is a wrapping comparison: LongWord(Now - Due) < $80000000 means "Now
  is at or past Due" and stays correct across the 49.7-day TickCount32 wrap --
  the same rule every other comparison in this unit uses. *)
procedure TIcomNetworkTransport.TimerTick;
var
   id:   integer;
   nowT: LongWord;
   due:  array[ICOM_TIMER_PING..ICOM_TIMER_LOGIN] of boolean;
begin
   (* THE RADIO SAID THE SESSION IS GONE.  Acted on here rather than in the
     reader thread that saw it, because the response is Disconnect and
     Disconnect frees that thread's own socket.  See HandleConnInfoPacket. *)
   if FSessionRevoked then
      begin
      FSessionRevoked := False;
      if FState = icsConnected then
         begin
         logger.Warn(LogPrefix + ' Radio reports this ' +
                     'session has no owner -- session revoked; disconnecting so ' +
                     'the polling thread reconnects');
         Disconnect;
         end;
      end;

   nowT := TickCount32;

   FTimerLock.Enter;
   try
      for id := Low(due) to High(due) do
         begin
         due[id] := (FTimerEvery[id] > 0) and
                    (LongWord(nowT - FTimerDue[id]) < $80000000);
         if due[id] then
            begin
            FTimerDue[id] := nowT + FTimerEvery[id];
            end;
         end;
   finally
      FTimerLock.Leave;
   end;

   for id := Low(due) to High(due) do
      begin
      if due[id] then
         begin
         DispatchTimer(id);
         end;
      end;
end;

procedure TIcomNetworkTransport.DispatchTimer(const aId: integer);
begin
   (* A handler running after Disconnect would send on a freed socket.  This
     closes the window between StopTimers and a tick already in flight. *)
   if not FTimersLive then
      begin
      Exit;
      end;

   try
      case aId of
        ICOM_TIMER_PING:          OnPingTimer;
        ICOM_TIMER_IDLE:          OnIdleTimer;
        ICOM_TIMER_TOKEN:         OnTokenRenewalTimer;
        ICOM_TIMER_CIV_WATCHDOG:  OnCivWatchdogTimer;
        ICOM_TIMER_AYT:           OnAYTTimer;
        ICOM_TIMER_LOGIN:         OnLoginTimer;
      end;
   except
      on E: Exception do
         begin
         logger.Error(LogPrefix + ' Timer %d raised %s: %s', [aId, E.ClassName, E.Message]);
         end;
   end;
end;

(* ARMING IS A DEADLINE, NOT AN OBJECT.  Nothing to create on first use and
  nothing to free, which was most of what the TTimer version did. *)
procedure TIcomNetworkTransport.StartTimer(const aId: integer;
                                           const aMs: integer);
begin
   FTimerLock.Enter;
   try
      FTimerEvery[aId] := LongWord(aMs);
      FTimerDue[aId]   := TickCount32 + LongWord(aMs);
   finally
      FTimerLock.Leave;
   end;
end;

procedure TIcomNetworkTransport.StopTimer(const aId: integer);
begin
   FTimerLock.Enter;
   try
      FTimerEvery[aId] := 0;
   finally
      FTimerLock.Leave;
   end;
end;

procedure TIcomNetworkTransport.StopAllTimers;
var
   i: integer;
begin
   FTimerLock.Enter;
   try
      for i := Low(FTimerEvery) to High(FTimerEvery) do
         begin
         FTimerEvery[i] := 0;
         end;
   finally
      FTimerLock.Leave;
   end;
end;

// ============================================================================
// Constructor / Destructor
// ============================================================================

(* HOW MANY TRANSPORTS THIS PROCESS HAS EVER BUILT.  Only ever incremented,
  and only for the log prefix -- a monotonic number is what makes two lines
  comparable, so it must not be a reused slot. *)
var
  IcomTransportInstances: LongInt = 0;

function TIcomNetworkTransport.LogPrefix: string;
begin
  Result := '[IcomTransport#' + IntToStr(FInstanceId) + ':' + FRadioName + ']';
end;

constructor TIcomNetworkTransport.Create;
begin
  inherited Create;

  FInstanceId := InterlockedIncrement(IcomTransportInstances);

  FState := icsDisconnected;
  FClientName := ICOM_CLIENT_NAME;
  FControlPort := ICOM_DEFAULT_CONTROL_PORT;
  FSendLock := TCriticalSection.Create;
  FTimerLock := TCriticalSection.Create;
  FLifecycleLock := TCriticalSection.Create;

  // Create TX buffer lists
  FControlTxBuf := TList.Create;
  FCivTxBuf := TList.Create;

  (* LAST, because it starts running immediately and its first act is to take
    FTimerLock.  It lives for the object, not for a session: the deadlines are
    armed and disarmed, the thread is not. *)
  FTimerThread := TIcomTimerThread.Create(Self);
end;

destructor TIcomNetworkTransport.Destroy;
begin
  (* THE TIMER THREAD GOES FIRST, AND IS JOINED.  It can call Disconnect on
    its own (OnPingTimer does, and so does a revoked session), so it must be
    stopped and finished before anything it touches is freed.  The cast is
    because the field is typed TThread in the interface -- TIcomTimerThread is
    an implementation detail and stays one. *)
  if FTimerThread <> nil then
     begin
     TIcomTimerThread(FTimerThread).Stop;
     FTimerThread.WaitFor;
     FreeAndNil(FTimerThread);
     end;

  (* UNCONDITIONALLY.  This used to be guarded by FState <> icsDisconnected,
    which is the same wrong test Disconnect itself carried -- and it is wrong
    in the same way: the auth-failure path parks the state at Disconnected
    while the sockets are still open, so the guard skipped the teardown of a
    transport that very much still owned a bound UDP socket and a running
    listener thread.  Disconnect is self-guarding now; let it decide. *)
  Disconnect;

  ClearAllBuffers;
  FreeAndNil(FControlTxBuf);
  FreeAndNil(FCivTxBuf);
  FreeAndNil(FSendLock);
  FreeAndNil(FTimerLock);
  FreeAndNil(FLifecycleLock);

  inherited Destroy;
end;

// ============================================================================
// Public API
// ============================================================================

function TIcomNetworkTransport.Connect(Address: string; Port: Word;
  Username, Password: string): Integer;
begin
  Result := 0;

  FLifecycleLock.Enter;
  try

  if FState <> icsDisconnected then
     begin
     logger.Warn(LogPrefix + ' Connect called while in state %s',
                 [IcomStateToString(FState)]);
     end;

  (* ALWAYS, not only when the state says so.  A transport whose login was
    rejected sits at Disconnected holding a live socket; connecting it again
    without this leaks that socket and its listener thread. *)
  Disconnect;

  FRadioAddress := Address;
  FControlPort := Port;
  FUsername := Username;
  FPassword := Password;

  // Reset sequence counters (matches wfview constructor)
  FSendSeq := 1;                     // wfview: m_sendSeq = 1
  FCivSeq := 1;                      // wfview: m_civSeq = 1 (reset again in initCivSocket)
  FCivInnerSeq := 0;                 // wfview: m_civInnerSeq = 0
  FAuthSeq := ICOM_AUTH_SEQ_START;   // wfview: m_authSeq = 0x30
  FPingSendSeq := 0;                 // wfview: m_pingSendSeq = 0
  FToken := 0;
  FRemoteId := 0;
  FCivRemoteId := 0;
  FRadioName := '';
  FCivAddress := 0;
  FAYTRetryCount := 0;
  FAYTInterval := ICOM_AYT_INITIAL_INTERVAL;
  FStartTick := TickCount32;
  FLastCivData := TickCount32;
  FLastTrackedSend := TickCount32;
  FSessionRevoked := False;
  FCivStreamOpen := False;

  (* AN ATTEMPT IS NOT FAILED UNTIL IT FAILS.

    FAuthFailed was assigned in exactly ONE place -- HandleLoginResponse, on
    ICOM_AUTH_FAILED -- and cleared in none, so the flag outlived the attempt
    that set it and condemned the transport object for the rest of its life.
    The polling thread reads it through TIcomRadio.GetAuthFailed and stops
    reconnecting, which meant a corrected password could never be tried: the
    first thing the retry did was report the PREVIOUS failure.

    Cleared HERE rather than in CreateSockets because Connect is what a fresh
    attempt IS -- it is the single entry point, it already resets every other
    per-session latch (token, sequence counters, FSessionRevoked) under
    FLifecycleLock, and it has an early path that never reaches CreateSockets
    at all. *)
  FAuthFailed := False;

  ClearAllBuffers;

  (* The password LENGTH, never the password.  This is the last place the
    credentials can be observed before IcomPasscode obfuscates them into the
    login packet, so it is the one line that can prove which copy was actually
    sent -- see the note on TIcomRadio.ApplyNetworkCredentials. *)
  logger.Info(LogPrefix + ' Connecting to %s:%d user=%s password %d chars',
              [Address, Port, Username, Length(Password)]);

  try
    // Create sockets
    CreateSockets;

    FTimersLive := True;

    // Calculate our ID from the control socket's local port
    FMyId := CalculateMyIdFromSocket(FControlSocket);
    logger.Debug(LogPrefix + ' My control ID: $%.8x', [FMyId]);

    // Send "Are You There" to start handshake
    // AYT uses Seq=0 (untracked, like wfview), FSendSeq stays at 1
    SendControlPacket(ICOM_PKT_ARE_YOU_THERE, FControlSocket,
      0, FRadioAddress, FControlPort, 0);
    SetState(icsWaitingForHere);

    // Start AYT retry timer
    StartTimer(ICOM_TIMER_AYT, FAYTInterval);

  except
    on E: Exception do
       begin
       logger.Error(LogPrefix + ' Exception during connect: %s', [E.Message]);
       DestroySockets;
       StopAllTimers;
       FTimersLive := False;
       Result := -1;
       end;
  end;

  finally
     FLifecycleLock.Leave;
  end;
end;

procedure TIcomNetworkTransport.Disconnect;
begin
  FLifecycleLock.Enter;
  try

  logger.Debug(LogPrefix + ' Disconnect called from state %s',
              [IcomStateToString(FState)]);

  (* IDEMPOTENT ON RESOURCES, NOT ON STATE.  This guard used to be
    "if FState = icsDisconnected then Exit", and that single line is the
    2026-09-24 IC-9700 defect.

    HandleLoginResponse cannot call Disconnect when the radio rejects the
    credentials -- it runs on the control socket's own Indy listener thread,
    and Disconnect frees that very TIdUDPServer -- so it sets the state to
    Disconnected and leaves the teardown to the polling thread.  The polling
    thread then called Disconnect, this guard saw icsDisconnected, and
    RETURNED WITHOUT FREEING ANYTHING.  TIcomRadio.Disconnect went straight on
    to FreeAndNil the transport.

    The consequences were both halves of the bench report:

      * the TIdUDPServer and its listener thread outlived the object, so an
        abandoned thread kept calling HandleReceivedPacket on freed memory --
        which is why arriving packets logged state=Disconnected (and Unknown,
        and WaitingForReady) while the LIVE transport was in WaitingForHere.
        Two such zombies were running by 21:06, one per earlier auth failure;

      * the radio was never told.  The disconnect send below is reached only
        when Disconnect actually runs, and after a rejected login FRemoteId IS
        set -- so this is precisely the case where we could have released the
        radio's session and did not.  Measured over that whole log: 14
        Disconnect calls, 2 early-exits here, and exactly ONE $0005 ever sent.
        The radio went on servicing sessions we had abandoned, and refused the
        next handshake until its own ~90 s expiry ran out.

    So: there is nothing to do only when there is nothing LEFT.  State alone
    cannot answer that. *)
  if (FState = icsDisconnected) and
     (FControlSocket = nil)     and
     (FCivSocket = nil)         then
     begin
     Exit;
     end;

  // Stop all timers first
  logger.Debug(LogPrefix + ' Disconnect: StopTimers');
  StopTimers;

  // Send CI-V Close if stream was open
  if FCivStreamOpen and (FCivSocket <> nil) and (FCivRemoteId <> 0) then
     begin
     try
        logger.Debug(LogPrefix + ' Disconnect: SendCivClose');
        SendCivClose;
        SendControlPacket(ICOM_PKT_DISCONNECT, FCivSocket,
           FCivRemoteId, FRadioAddress, FCivPort, FCivSeq);
     except
        on E: Exception do
           begin
           logger.Debug(LogPrefix + ' Exception during CI-V disconnect: %s', [E.Message]);
           end;
     end;
     end;

  // Send disconnect on control socket
  if (FControlSocket <> nil) and (FRemoteId <> 0) then
     begin
     try
        logger.Debug(LogPrefix + ' Disconnect: SendControlDisconnect');
        SendControlPacket(ICOM_PKT_DISCONNECT, FControlSocket,
           FRemoteId, FRadioAddress, FControlPort, FSendSeq);
     except
        on E: Exception do
           begin
           logger.Debug(LogPrefix + ' Exception during control disconnect: %s', [E.Message]);
           end;
     end;
     end;

  logger.Debug(LogPrefix + ' Disconnect: Sleep(100)');
  Sleep(100);

  logger.Debug(LogPrefix + ' Disconnect: DestroySockets');
  DestroySockets;
  logger.Debug(LogPrefix + ' Disconnect: DestroySockets done');
  ClearAllBuffers;

  StopAllTimers;
  FTimersLive := False;

  FCivStreamOpen := False;
  SetState(icsDisconnected);
  logger.Debug(LogPrefix + ' Disconnect: complete');

  finally
     FLifecycleLock.Leave;
  end;
end;

procedure TIcomNetworkTransport.SendCivData(const CivFrame: string);
var
  Pkt: TDataPacket;
  FullPacket: AnsiString;
  i: Integer;
begin
  if not FCivStreamOpen then
     begin
     logger.Warn(LogPrefix + ' SendCivData called while CI-V stream not open (state=%s)',
                 [IcomStateToString(FState)]);
     Exit;
     end;

  // Build data packet header — Seq will be patched by SendTrackedPacket
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_DATA_HDR_SIZE + Length(CivFrame);
  Pkt.PktType := ICOM_PKT_DATA;
  Pkt.Seq := 0;  // Placeholder — SendTrackedPacket patches bytes [6..7]
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FCivRemoteId;
  Pkt.Reply := ICOM_DATA_REPLY_MARKER;
  Pkt.DataLen := Length(CivFrame);  // Little-endian (no swap) — matches wfview
  Pkt.SendSeq := SwapWord(FCivInnerSeq);
  Inc(FCivInnerSeq);

  // Combine header + CI-V data into one byte-exact packet. CivFrame is a string
  // of faithful codepoints (each Char 0..255 == one CI-V byte). Copy the header
  // record verbatim, then the payload byte-faithfully (Ord -> byte). Never Move
  // the string (that would copy UTF-16 code units, not the CI-V bytes).
  SetLength(FullPacket, SizeOf(Pkt) + Length(CivFrame));
  Move(Pkt, FullPacket[1], SizeOf(Pkt));
  for i := 1 to Length(CivFrame) do
     begin
     FullPacket[SizeOf(Pkt) + i] := AnsiChar(Ord(CivFrame[i]));
     end;

  SendTrackedPacket(FCivSocket, FullPacket, FRadioAddress, FCivPort, FCivSeq);

  logger.Trace(LogPrefix + ' Sent CI-V data, outer seq=%d, inner seq=%d, len=%d',
               [FCivSeq - 1, FCivInnerSeq - 1, Length(CivFrame)]);
end;

// ============================================================================
// Socket Creation / Destruction
// ============================================================================

procedure TIcomNetworkTransport.CreateSockets;

  procedure SetupSocket(var Socket: TIdUDPServer;
    OnRead: TUDPReadEvent; BindPort: Word);
  var
    Binding: TIdSocketHandle;
    RcvBufSize: Integer;
  begin
    Socket := TIdUDPServer.Create(nil);
    Socket.ThreadedEvent := True;
    Socket.OnUDPRead := OnRead;

    // Bind to any available port (or specific port for CI-V)
    Binding := Socket.Bindings.Add;
    Binding.IP := '0.0.0.0';
    Binding.Port := BindPort;

    Socket.Active := True;

    (* Increase the UDP receive buffer to 256KB to reduce packet loss under
      load. Through Indy's own socket handle rather than WinSock.setsockopt:
      TIdSocketHandle.SetSockOpt takes an Integer and works on every stack
      Indy supports. *)
    RcvBufSize := 256 * 1024;
    Binding.SetSockOpt(Id_SOL_SOCKET, Id_SO_RCVBUF, RcvBufSize);

    logger.Debug(LogPrefix + ' Socket bound to port %d', [Binding.Port]);
  end;

begin
  // Control socket - bind to any port
  SetupSocket(FControlSocket, HandleControlUDPRead, 0);

  // CI-V socket will be created after we learn the CI-V port from the radio
  FCivSocket := nil;
end;

// Thread function for freeing an Indy socket with a timeout.
// The TIdUDPServer destructor can hang when the listener thread's socket
// was in an error state (e.g. after a failed auth handshake).
function FreeObjectThread(Obj: Pointer): Integer;
begin
  TObject(Obj).Free;
  Result := 0;
end;

procedure TIcomNetworkTransport.DestroySockets;

   procedure SafeFreeSocket(var Socket: TIdUDPServer; const Name: string);
   var
      FreeThread: TThreadID;
      ThreadId: TThreadID;
      WaitResult: DWord;
   begin
      if Socket = nil then
         begin
         Exit;
         end;

      // Step 1: Deactivate (stops listener thread, closes socket)
      try
         logger.Debug(LogPrefix + ' DestroySockets: ' + Name + ' Active:=False');
         Socket.Active := False;
         logger.Debug(LogPrefix + ' DestroySockets: ' + Name + ' Active:=False done');
      except
         on E: Exception do
            begin
            logger.Debug(LogPrefix + ' Exception deactivating ' + Name + ': %s', [E.Message]);
            end;
      end;

      // Step 2: Free the object on a background thread with timeout.
      // If the Indy destructor hangs, we abandon it — ExitProcess cleans up.
      logger.Debug(LogPrefix + ' DestroySockets: Freeing ' + Name);
      FreeThread := BeginThread(nil, 0, @FreeObjectThread, Pointer(Socket), 0, ThreadId);
      (* PtrUInt, NOT 0. TThreadID is a POINTER on the BSD/macOS RTL and an
        integer on Windows and Linux, so comparing it to an ordinal is a type
        error there ("Operator is not overloaded: TThreadID = ShortInt").
        BeginThread returns a zero/nil id on failure either way, and comparing
        at pointer width says exactly that on every target. *)
      if PtrUInt(FreeThread) <> 0 then
         begin
         (* THE RTL's PAIR, because BeginThread above returns a TThreadID and
           not a Win32 HANDLE. On Windows WaitForThreadTerminate IS
           WaitForSingleObject (rtl\win\systhrd.inc), so the timeout and the
           return value are unchanged here.

           OFF WINDOWS THE TIMEOUT IS NOT HONOURED: cthreads implements this
           as pthread_join, which waits for ever. That matters, because the
           500 ms is the whole point of this code -- abandoning an Indy
           destructor that hangs -- so on a non-Windows build a hung destructor
           would hang the shutdown instead. Recorded rather than papered over;
           it needs a real answer when this program actually runs there. *)
         WaitResult := WaitForThreadTerminate(FreeThread, 500);
         CloseThread(FreeThread);
         if WaitResult = WAIT_TIMEOUT_RESULT then
            begin
            logger.Warn(LogPrefix + ' DestroySockets: ' + Name + ' Free timed out, abandoning');
            end
         else
            begin
            logger.Debug(LogPrefix + ' DestroySockets: ' + Name + ' freed OK');
            end;
         end
      else
         begin
         // Couldn't create thread — try direct free as fallback
         try
            Socket.Free;
         except
         end;
         end;
      Socket := nil;
   end;

begin
  SafeFreeSocket(FControlSocket, 'Control');
  SafeFreeSocket(FCivSocket, 'CIV');
  logger.Debug(LogPrefix + ' DestroySockets: complete');
end;

(* WHICH LOCAL INTERFACE ROUTES TO THE RADIO.

  The UDP "connect" trick, unchanged in substance: connecting a datagram
  socket sends nothing but does make the OS choose a route, and getsockname
  then reports the local address it picked. TR4W needs that address because
  the Icom protocol's session id is derived from it.

  THROUGH INDY NOW, not raw WinSock (2026-09-08) -- socket(), inet_addr(),
  htons(), connect(), getsockname(), inet_ntoa() and closesocket() were seven
  Windows-only calls for a question Indy answers with four method calls.
  TIdSocketHandle.UpdateBindingLocal IS getsockname; the IP property is where
  it puts the answer. *)
function TIcomNetworkTransport.GetLocalIPForRoute: string;
var
  Sock: TIdSocketHandle;
begin
  Result := '';
  try
    Sock := TIdSocketHandle.Create(nil);
    try
      Sock.AllocateSocket(Id_SOCK_DGRAM);
      try
        (* AnsiString EXPLICITLY: Indy's host parameter is AnsiString and this
          tree's `string` is UnicodeString, so the conversion happens either
          way -- stated here rather than left implicit. It is lossless: an IPv4
          dotted quad is ASCII, which is why the WinSock version that stood
          here could hand it to inet_addr as a PAnsiChar. *)
        Sock.SetPeer(AnsiString(FRadioAddress), FControlPort);
        Sock.Connect;
        Sock.UpdateBindingLocal;
        Result := Sock.IP;
      finally
        Sock.CloseSocket;
      end;
    finally
      Sock.Free;
    end;
  except
    on E: Exception do
       begin
       (* REPORTED, not swallowed. The bare `except Result := ''` that stood
         here hid the one failure that matters: without a local IP the session
         id is wrong and the radio rejects the login, which looks like a
         password problem. *)
       logger.Error('[IcomTransport:%s] GetLocalIPForRoute failed for %s:%d -- '
                    + '%s: %s. The session id derived from it will be wrong.',
                    [FRadioName, FRadioAddress, FControlPort,
                     E.ClassName, E.Message]);
       Result := '';
       end;
  end;
end;

function TIcomNetworkTransport.CalculateMyIdFromSocket(Socket: TIdUDPServer): LongWord;
var
  LocalIP: LongWord;
  LocalPort: Word;
  IPParts: array[0..3] of Byte;
  IPStr: string;
  DotPos: Integer;
  I: Integer;
  Part: string;
begin
  // Get the local port from the socket binding
  if Socket.Bindings.Count > 0 then
     begin
     LocalPort := Socket.Bindings[0].Port
     end
  else
     begin
     LocalPort := 0;
     end;

  // Get local IP - use the binding's IP, or use routing trick to detect it
  IPStr := Socket.Bindings[0].IP;
  if (IPStr = '') or (IPStr = '0.0.0.0') then
     begin
     IPStr := GetLocalIPForRoute;
     if IPStr = '' then
        begin
        IPStr := '127.0.0.1';  // Last-resort fallback
        end;
     logger.Debug(LogPrefix + ' Detected local routing IP: %s', [IPStr]);
     end;

  // Parse IP string to bytes
  FillChar(IPParts, SizeOf(IPParts), 0);
  I := 0;
  while (Length(IPStr) > 0) and (I < 4) do
     begin
     DotPos := Pos('.', IPStr);
     if DotPos = 0 then
        begin
        IPParts[I] := StrToIntDef(IPStr, 0);
        IPStr := '';
        end
     else
        begin
        Part := Copy(IPStr, 1, DotPos - 1);
        IPParts[I] := StrToIntDef(Part, 0);
        Delete(IPStr, 1, DotPos);
        end;
     Inc(I);
     end;

  // Build host-order IP (e.g., 192.168.1.100 = $C0A80164)
  LocalIP := (LongWord(IPParts[0]) shl 24) or
             (LongWord(IPParts[1]) shl 16) or
             (LongWord(IPParts[2]) shl 8) or
             LongWord(IPParts[3]);

  Result := CalculateMyId(LocalIP, LocalPort);
end;

// ============================================================================
// Hex dump helper (for debug logging)
// ============================================================================

function BytesToHexStr(const Data; DataLen: Integer): string;
var
  Bytes: array[0..1023] of Byte absolute Data;
  I: Integer;
begin
  Result := '';
  for I := 0 to DataLen - 1 do
     begin
     if I > 0 then
        begin
        Result := Result + ' ';
        end;
     Result := Result + IntToHex(Bytes[I], 2);
     end;
end;

// ============================================================================
// UDP Read Handlers (called from Indy listener threads)
// ============================================================================

procedure TIcomNetworkTransport.HandleControlUDPRead(
  AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
var
  RawData: array of Byte;
begin
  if Length(AData) < SizeOf(TControlPacket) then Exit;

  SetLength(RawData, Length(AData));
  Move(AData[0], RawData[0], Length(AData));

  HandleReceivedPacket(RawData, Length(RawData), False,
    ABinding.PeerIP, ABinding.PeerPort);
end;

procedure TIcomNetworkTransport.HandleCivUDPRead(
  AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
var
  RawData: array of Byte;
begin
  if Length(AData) < SizeOf(TControlPacket) then Exit;

  SetLength(RawData, Length(AData));
  Move(AData[0], RawData[0], Length(AData));

  HandleReceivedPacket(RawData, Length(RawData), True,
    ABinding.PeerIP, ABinding.PeerPort);
end;

// ============================================================================
// Packet Dispatch — by packet LENGTH (matches wfview processControlPacket)
// ============================================================================

procedure TIcomNetworkTransport.HandleReceivedPacket(
  const Data: array of Byte; DataLen: Integer;
  FromCivSocket: Boolean; PeerIP: string; PeerPort: Word);
var
  Pkt: TControlPacket;
  PktType: Word;
begin
  if DataLen < SizeOf(TControlPacket) then Exit;

  Move(Data[0], Pkt, SizeOf(TControlPacket));
  PktType := Pkt.PktType;

  logger.Trace(LogPrefix + ' Received packet: type=$%.4x len=%d fromCIV=%s state=%s peer=%s:%d',
               [PktType, DataLen, BoolToStr(FromCivSocket, True),
                IcomStateToString(FState), PeerIP, PeerPort]);

  (* Dispatch by PktType first for control/ping packets.  Length is used only
    to disambiguate the large control-socket packets -- login, token, status,
    capabilities, conninfo -- which all share type=$0000.

    THE "RADIOS PAD 16-BYTE CONTROL PACKETS TO 18 BYTES" NOTE THAT STOOD HERE
    IS NOT TRUE OF THIS RADIO, and it is worth saying so rather than deleting
    it, because it was the stated reason for dispatching on PktType.  Measured
    on the 2026-09-24 IC-7760 LAN capture, every datagram length the radio
    sent in 663 seconds: 16, 21, 27, 28, 29, 30, 31, 32, 33, 38, 40, 80, 96,
    144, 168, 732.  NOT ONE 18-BYTE PACKET.  Control packets are exactly 16
    and pings exactly 21.

    Dispatching on PktType is still right -- it is what the field is for --
    but nobody should carry forward a padding rule this radio does not
    follow.  If another model does pad, measure it and say which. *)

  case PktType of
    ICOM_PKT_I_AM_HERE,
    ICOM_PKT_DISCONNECT,
    ICOM_PKT_ARE_YOU_READY:
      HandleControlResponse(Data, DataLen, FromCivSocket);

    ICOM_PKT_AUTH:  // type=$0001 = retransmit request
      HandleRetransmitRequest(Data, DataLen, FromCivSocket);

    ICOM_PKT_PING:  // type=$0007
      HandlePingPacket(Data, DataLen, FromCivSocket, PeerIP, PeerPort);

    ICOM_PKT_DATA:  // type=$0000 — idle, auth response, or CI-V data
      begin
        if FromCivSocket then
           begin
           // CI-V socket: small = idle keepalive, large = CI-V data
           if DataLen >= ICOM_DATA_HDR_SIZE then
              begin
              HandleDataPacket(Data, DataLen);
              end;
           // else: radio idle keepalive (18 bytes), safe to ignore
           end
        else
           begin
           // Control socket: disambiguate by length
           case DataLen of
             ICOM_TOKEN_PKT_SIZE:    HandleTokenResponse(Data, DataLen);   // 64
             ICOM_STATUS_PKT_SIZE:   HandleStatusPacket(Data, DataLen);    // 80
             ICOM_LOGIN_RESP_SIZE:   HandleLoginResponse(Data, DataLen);   // 96
             (* 144 -- WAS FALLING INTO HandleCapabilities.  SizeOf a
               TCapabilitiesPacket is only 66, so a 144-byte ConnInfo cleared
               the ">= capabilities header" test below and was saved from being
               misparsed only by that handler's state guard.  53 of them in the
               2026-09-24 capture, silently discarded -- and 13 of those were
               the radio telling us the session had been revoked. *)
             ICOM_CONNINFO_PKT_SIZE: HandleConnInfoPacket(Data, DataLen);  // 144
           else
             if DataLen >= SizeOf(TCapabilitiesPacket) then
                begin
                HandleCapabilities(Data, DataLen);
                end;
             // else: control idle keepalive (18 bytes), safe to ignore
           end;
           end;
      end;
  else
    logger.Debug(LogPrefix + ' Unknown packet type=$%.4x len=%d', [PktType, DataLen]);
  end;
end;

// ============================================================================
// Control Packet Handling (Are You Here/Ready, Disconnect)
// ============================================================================

procedure TIcomNetworkTransport.HandleControlResponse(
  const Data: array of Byte; DataLen: Integer; FromCivSocket: Boolean);
var
  Pkt: TControlPacket;
begin
  Move(Data[0], Pkt, SizeOf(TControlPacket));

  case Pkt.PktType of
    ICOM_PKT_I_AM_HERE:
      begin
        if FromCivSocket then
           begin
           // CI-V socket handshake (within Connected state, like wfview)
           if (FState = icsConnected) and (FCivRemoteId = 0) then
              begin
              FCivRemoteId := Pkt.SentID;
              logger.Debug(LogPrefix + ' CI-V I Am Here received, remoteId=$%.8x',
                          [FCivRemoteId]);

              // Send "Are You Ready" on CI-V socket (seq=1, untracked, like wfview)
              SendControlPacket(ICOM_PKT_ARE_YOU_READY, FCivSocket,
                FCivRemoteId, FRadioAddress, FCivPort, FCivSeq);
              end;
           end
        else
           begin
           // Control socket handshake
           if FState = icsWaitingForHere then
              begin
              FRemoteId := Pkt.SentID;
              logger.Debug(LogPrefix + ' Control I Am Here received, remoteId=$%.8x',
                          [FRemoteId]);

              // Kill AYT timer
              StopTimer(ICOM_TIMER_AYT);

              // Start Ping + Idle timers HERE (matches wfview lines 610-611)
              // These run during the entire handshake, not just after full connect
              StartTimer(ICOM_TIMER_PING, ICOM_PING_INTERVAL);
              StartTimer(ICOM_TIMER_IDLE, ICOM_IDLE_INTERVAL);

              // Send "Are You Ready" (seq=1, untracked, like wfview)
              SendControlPacket(ICOM_PKT_ARE_YOU_READY, FControlSocket,
                FRemoteId, FRadioAddress, FControlPort, 1);
              SetState(icsWaitingForReady);
              end;
           end;
      end;

    ICOM_PKT_ARE_YOU_READY:
      begin
        if FromCivSocket then
           begin
           // CI-V I Am Ready (within Connected state)
           if (FState = icsConnected) and (FCivRemoteId <> 0) and (not FCivStreamOpen) then
              begin
              logger.Debug(LogPrefix + ' CI-V I Am Ready received');

              // Send CI-V Open
              SendCivOpen;
              FCivStreamOpen := True;

              // Start watchdog timer for CI-V data
              StartTimer(ICOM_TIMER_CIV_WATCHDOG, ICOM_CIV_WATCHDOG_INTERVAL);

              FLastCivData := TickCount32;
              logger.Info(LogPrefix + ' Fully connected to %s, CI-V stream open', [FRadioName]);

              // Notify state change listeners (radio can now send CI-V commands)
              if Assigned(FOnStateChange) then
                 begin
                 try
                   FOnStateChange(Self);
                 except
                   on E: Exception do
                      begin
                      logger.Error(LogPrefix + ' Exception in state change callback: %s', [E.Message]);
                      end;
                 end;
                 end;
              end;
           end
        else
           begin
           if FState = icsWaitingForReady then
              begin
              logger.Debug(LogPrefix + ' Control I Am Ready received');

              // Send Login
              SendLoginPacket;
              SetState(icsWaitingForLogin);
              end;
           end;
      end;

    ICOM_PKT_DISCONNECT:
      begin
        logger.Warn(LogPrefix + ' Disconnect received from radio');
        Disconnect;
      end;
  end;
end;

// ============================================================================
// Ping Handling
// ============================================================================

procedure TIcomNetworkTransport.HandlePingPacket(
  const Data: array of Byte; DataLen: Integer;
  FromCivSocket: Boolean; PeerIP: string; PeerPort: Word);
var
  Pkt: TPingPacket;
  ExpectedId: LongWord;
begin
  if DataLen < SizeOf(TPingPacket) then Exit;
  Move(Data[0], Pkt, SizeOf(TPingPacket));

  if Pkt.Reply = 0 then
     begin
     // Only respond to pings addressed to our own session.
     ExpectedId := FMyId;

     if (ExpectedId <> 0) and (Pkt.RcvdID <> ExpectedId) then
        begin
        logger.Debug(LogPrefix + ' Ignoring ping to stale session $%.8x (ours: $%.8x)',
                     [Pkt.RcvdID, ExpectedId]);
        Exit;
        end;

     // Ping request addressed to us — radio is alive
     FLastPingReceived := TickCount32;

     // Send response
     if FromCivSocket then
        begin
        SendPingResponse(Data, DataLen, FCivSocket, PeerIP, PeerPort)
        end
     else
        begin
        SendPingResponse(Data, DataLen, FControlSocket, PeerIP, PeerPort);
        end;
     end;
  // Ping response - ignore (just keepalive confirmation)
end;

// ============================================================================
// Login Response
// ============================================================================

procedure TIcomNetworkTransport.HandleLoginResponse(
  const Data: array of Byte; DataLen: Integer);
var
  Pkt: TLoginResponsePacket;
begin
  if DataLen < SizeOf(TLoginResponsePacket) then Exit;
  if FState <> icsWaitingForLogin then Exit;

  Move(Data[0], Pkt, SizeOf(TLoginResponsePacket));

  (* Check for auth failure.

    Do NOT call Disconnect here -- we are on the Indy listener thread, and
    Disconnect -> DestroySockets -> Active := False would self-deadlock.  Set
    the flag and the state; the polling thread does the teardown.

    THAT HAND-OFF WAS BROKEN FOR AS LONG AS IT EXISTED, and the break was not
    here: parking the state at Disconnected made the polling thread's
    Disconnect a no-op, because its guard tested the state.  Every rejected
    login therefore leaked a bound socket and a listener thread, and told the
    radio nothing.  See the guard at the top of Disconnect. *)
  if Pkt.Error = ICOM_AUTH_FAILED then
     begin
     logger.Error(LogPrefix + ' Authentication failed - check username/password');
     FAuthFailed := True;
     StopTimers;
     SetState(icsDisconnected);
     Exit;
     end;

  // Save token and auth start ID
  FToken := Pkt.Token;
  FAuthStartId := Pkt.AuthStartID;
  logger.Info(LogPrefix + ' Login successful, token=$%.8x, authStartId=$%.4x',
              [FToken, FAuthStartId]);

  // Start token renewal timer (matches wfview line 706)
  StartTimer(ICOM_TIMER_TOKEN, ICOM_TOKEN_RENEWAL_INTERVAL);

  // Send Token Acknowledgment
  SendTokenAck;
  SetState(icsAuthenticated);
end;

// ============================================================================
// Token Renewal Response
// ============================================================================

procedure TIcomNetworkTransport.HandleTokenResponse(
  const Data: array of Byte; DataLen: Integer);
var
  Pkt: TTokenPacket;
begin
  if DataLen < SizeOf(TTokenPacket) then Exit;
  Move(Data[0], Pkt, SizeOf(TTokenPacket));

  // Token renewal response from radio - just log it
  logger.Trace(LogPrefix + ' Token response received, response=$%.8x', [Pkt.Response]);
end;

// ============================================================================
// Capabilities
// ============================================================================

procedure TIcomNetworkTransport.HandleCapabilities(
  const Data: array of Byte; DataLen: Integer);
var
  CapHdr: TCapabilitiesPacket;
  NumRadios: Word;
  RadioCap: TRadioCapPacket;
  Offset: Integer;
  I: Integer;
  NameStr: string;
  RcvBufSize: Integer;
begin
  if DataLen < SizeOf(TCapabilitiesPacket) then Exit;
  if FState <> icsAuthenticated then Exit;

  Move(Data[0], CapHdr, SizeOf(TCapabilitiesPacket));

  NumRadios := SwapWord(CapHdr.NumRadios);
  logger.Info(LogPrefix + ' Capabilities received, %d radio(s)', [NumRadios]);

  // Parse first radio entry (we only care about the first one)
  Offset := SizeOf(TCapabilitiesPacket);
  if (NumRadios > 0) and (DataLen >= Offset + SizeOf(TRadioCapPacket)) then
     begin
     Move(Data[Offset], RadioCap, SizeOf(TRadioCapPacket));

     // Extract radio name (null-terminated ASCII) byte-faithfully -- building it
     // Char-by-Char, not Move-ing raw bytes into a UTF-16 buffer (which garbled it
     // to "???0").
     NameStr := '';
     for I := 0 to 31 do
        begin
        if RadioCap.RadioName[I] = 0 then Break;
        NameStr := NameStr + Char(RadioCap.RadioName[I]);
        end;
     FRadioName := Trim(NameStr);

     // Save CI-V address and MAC
     FCivAddress := RadioCap.CivAddress;
     Move(RadioCap.MacAddress, FMacAddress, 6);
     FCommonCap := RadioCap.CommonCap;

     logger.Info(LogPrefix + ' Radio: %s, CI-V address=$%.2x, CommonCap=$%.4x',
                 [FRadioName, FCivAddress, FCommonCap]);
     end;

  // Create CI-V socket now so we can tell the radio our local CI-V port in the stream request
  if FCivSocket = nil then
     begin
     FCivSocket := TIdUDPServer.Create(nil);
     FCivSocket.ThreadedEvent := True;
     FCivSocket.OnUDPRead := HandleCivUDPRead;
     FCivSocket.Bindings.Add;  // Let OS pick any available port
     FCivSocket.Active := True;

     // Increase UDP receive buffer to 256KB to reduce packet loss under load
     RcvBufSize := 256 * 1024;
     FCivSocket.Bindings[0].SetSockOpt(Id_SOL_SOCKET, Id_SO_RCVBUF, RcvBufSize);

     logger.Debug(LogPrefix + ' CI-V socket pre-bound to port %d',
                  [FCivSocket.Bindings[0].Port]);
     end;

  // Send Stream Request (includes our local CI-V port so radio knows where to connect)
  SendStreamRequest;
  SetState(icsStreamRequested);
end;

(* CONNINFO FROM THE RADIO: WHO, IF ANYONE, OWNS THIS SESSION.

  The radio sends one of these during the handshake and again once we reach
  Connected.  It also sends one UNBIDDEN when it has decided the session has
  no owner any more -- and that is the signal this exists to catch, because
  CI-V stops within half a second of it.

  THE DISCRIMINATOR IS THREE-PART, and all three parts are needed.  Checked
  against every one of the 53 ConnInfo packets in the 2026-09-24 IC-7760
  capture, in both directions:

    empty owner block alone            26 hits -- 13 of them FALSE, because
                                       the handshake's own ConnInfo is also
                                       unowned
    + our token                        still 26
    + FState = icsConnected            13 hits, and they are exactly the 13
                                       CI-V stalls.  No misses, no false
                                       positives.

  The handshake copy is what the state guard removes: it arrives at
  StreamRequested, never at Connected.  The two that DO arrive at Connected
  during a handshake both carry an owner, so the owner test removes those.

  WHY A FLAG AND NOT A Disconnect RIGHT HERE.  This runs on the control
  socket's Indy listener thread, and Disconnect frees that very TIdUDPServer.
  The timer thread acts on the flag instead; see TimerTick.

  WHAT IT BUYS.  Before this, a revoked session was discovered by INFERENCE --
  CI-V goes quiet, CivDataFresh ages out at 3 s, the polling supervisor gives
  it 8 s more, then forces a reconnect: 12.3 s, measured, thirteen times.  This
  is the radio REPORTING it, ~0.4 s early, which is the house preference and
  about 1.5 s instead.

  IT SHOULD NOW BE UNREACHABLE.  The session is revoked because the token was
  never renewed, and the timer thread renews it.  This is the belt to that
  braces, and if it ever fires the log line says so plainly. *)
procedure TIcomNetworkTransport.HandleConnInfoPacket(
  const Data: array of Byte; DataLen: Integer);
var
  Pkt: TConnInfoPacket;
  i: Integer;
  Owned: Boolean;
begin
  if DataLen < SizeOf(TConnInfoPacket) then
     begin
     Exit;
     end;

  Move(Data[0], Pkt, SizeOf(TConnInfoPacket));

  // Only a live session can be revoked, and only ours concerns us.
  if FState <> icsConnected then
     begin
     Exit;
     end;

  if Pkt.Token <> FToken then
     begin
     Exit;
     end;

  Owned := False;
  for i := Low(Pkt.Username) to High(Pkt.Username) do
     begin
     if Pkt.Username[i] <> 0 then
        begin
        Owned := True;
        Break;
        end;
     end;

  if Owned then
     begin
     Exit;
     end;

  logger.Warn(LogPrefix + ' ConnInfo says this session ' +
              'has no owner (token=$%.8x) -- the radio has revoked it; ' +
              'reconnecting', [FToken]);
  FSessionRevoked := True;
end;

// ============================================================================
// Status Packet (CI-V port info) — transitions to Connected
// ============================================================================

procedure TIcomNetworkTransport.HandleStatusPacket(
  const Data: array of Byte; DataLen: Integer);
var
  Pkt: TStatusPacket;
begin
  if DataLen < SizeOf(TStatusPacket) then Exit;
  if FState <> icsStreamRequested then Exit;

  Move(Data[0], Pkt, SizeOf(TStatusPacket));

  // Check for connection error
  if Pkt.Error = $FFFFFFFF then
     begin
     logger.Error(LogPrefix + ' Stream request failed (error=$FFFFFFFF)');
     Disconnect;
     Exit;
     end;

  // Extract CI-V port (big-endian)
  FCivPort := SwapWord(Pkt.CivPort);
  if FCivPort = 0 then
     begin
     FCivPort := ICOM_DEFAULT_CIV_PORT;  // Fallback
     end;

  logger.Debug(LogPrefix + ' Status received, CI-V port=%d', [FCivPort]);

  // CI-V socket was already created in HandleCapabilities
  FCivMyId := CalculateMyIdFromSocket(FCivSocket);
  logger.Debug(LogPrefix + ' My CI-V ID: $%.8x', [FCivMyId]);

  // Transition to Connected — CI-V handshake happens within this state (like wfview)
  SetState(icsConnected);

  // Reset CI-V counters (matches wfview initCivSocket)
  FCivSeq := 1;
  FCivInnerSeq := 0;
  FCivRemoteId := 0;
  FCivStreamOpen := False;

  // Send "Are You There" on CI-V socket — Seq=0 (probe, rcvdId=0)
  logger.Debug(LogPrefix + ' Sending CI-V AYT: localPort=%d -> %s:%d myId=$%.8x',
    [FCivSocket.Bindings[0].Port, FRadioAddress, FCivPort, FMyId]);
  SendControlPacket(ICOM_PKT_ARE_YOU_THERE, FCivSocket,
    0, FRadioAddress, FCivPort, 0);
end;

// ============================================================================
// CI-V Data Packet Handling
// ============================================================================

procedure TIcomNetworkTransport.HandleDataPacket(
  const Data: array of Byte; DataLen: Integer);
begin
  if DataLen < ICOM_DATA_HDR_SIZE then Exit;

  FLastCivData := TickCount32;

  // Extract CI-V frames from the data
  ExtractCivFrames(Data, DataLen);
end;

procedure TIcomNetworkTransport.ExtractCivFrames(
  const Data: array of Byte; DataLen: Integer);
var
  I, J, FrameStart, FrameEnd: Integer;
  Frame: string;
begin
  // Search for FE FE ... FD patterns in raw packet data
  I := 0;
  while I < DataLen - 1 do
     begin
     // Look for preamble FE FE
     if (Data[I] = CIV_PREAMBLE) and (Data[I + 1] = CIV_PREAMBLE) then
        begin
        FrameStart := I;

        // Find matching FD
        FrameEnd := -1;
        I := I + 2;
        while I < DataLen do
           begin
           if Data[I] = CIV_EOM then
              begin
              FrameEnd := I;
              Break;
              end;
           Inc(I);
           end;

        if FrameEnd > FrameStart then
           begin
           // Extract frame (FE FE ... FD inclusive) as a faithful-codepoint string:
           // each Char's codepoint IS the CI-V byte. Build it byte-faithfully -- never
           // Move raw bytes into a UTF-16 string buffer.
           SetLength(Frame, FrameEnd - FrameStart + 1);
           for J := 1 to Length(Frame) do
              begin
              Frame[J] := Char(Data[FrameStart + J - 1]);
              end;

           if logger.IsTraceEnabled then
              begin
              logger.Trace(LogPrefix + ' CIV RX: %s', [BytesToHexStr(Data[FrameStart], FrameEnd - FrameStart + 1)]);
              end;

           // Forward to callback
           if Assigned(FOnCivData) then
              begin
              try
                FOnCivData(Frame);
              except
                on E: Exception do
                   begin
                   logger.Error(LogPrefix + ' Exception in CI-V callback: %s', [E.Message]);
                   end;
              end;
              end;
           end;
        end;

     Inc(I);
     end;
end;

// ============================================================================
// Packet Building and Sending
// ============================================================================

procedure TIcomNetworkTransport.SendControlPacket(PktType: Word;
  Socket: TIdUDPServer; RemoteId: LongWord;
  TargetAddr: string; TargetPort: Word; Seq: Word);
var
  Pkt: TControlPacket;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_CONTROL_PKT_SIZE;
  Pkt.PktType := PktType;
  Pkt.Seq := Seq;
  Pkt.SentID := FMyId;  // FMyId for all packets on both sockets
  Pkt.RcvdID := RemoteId;

  FSendLock.Enter;
  try
    SendRawPacket(Socket, Pkt, SizeOf(Pkt), TargetAddr, TargetPort);
  finally
    FSendLock.Leave;
  end;

  logger.Trace(LogPrefix + ' Sent control packet: type=$%.4x seq=%d myId=$%.8x rcvdId=$%.8x',
               [PktType, Seq, FMyId, RemoteId]);
end;

procedure TIcomNetworkTransport.SendPingResponse(
  const Data: array of Byte; DataLen: Integer;
  Socket: TIdUDPServer; TargetAddr: string; TargetPort: Word);
var
  Pkt: TPingPacket;
begin
  if DataLen < SizeOf(TPingPacket) then Exit;
  Move(Data[0], Pkt, SizeOf(TPingPacket));

  // Swap sender/receiver and set reply flag
  Pkt.RcvdID := Pkt.SentID;
  Pkt.SentID := FMyId;
  Pkt.Reply := 1;
  Inc(FPingSendSeq);
  Pkt.Seq := FPingSendSeq;

  FSendLock.Enter;
  try
    SendRawPacket(Socket, Pkt, SizeOf(Pkt), TargetAddr, TargetPort);
  finally
    FSendLock.Leave;
  end;
end;

procedure TIcomNetworkTransport.SendPing;
var
  Pkt: TPingPacket;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_PING_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_PING;
  Inc(FPingSendSeq);
  Pkt.Seq := FPingSendSeq;
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FRemoteId;
  Pkt.Reply := 0;
  Pkt.Time := TickCount32 - FStartTick;

  FSendLock.Enter;
  try
    SendRawPacket(FControlSocket, Pkt, SizeOf(Pkt),
      FRadioAddress, FControlPort);
  finally
    FSendLock.Leave;
  end;
end;

procedure TIcomNetworkTransport.SendLoginPacket;
var
  Pkt: TLoginPacket;
  I: Integer;
  PktStr: AnsiString;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_LOGIN_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_DATA;  // Auth packets use PktType=0 (same as DATA)
  Pkt.Seq := 0;  // Placeholder — SendTrackedPacket patches bytes [6..7]
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FRemoteId;
  Pkt.PayloadSize := SwapLongWord(ICOM_LOGIN_PKT_SIZE - $10);
  Pkt.RequestReply := $01;
  Pkt.RequestType := $00;
  Pkt.InnerSeq := SwapWord(FAuthSeq);
  Inc(FAuthSeq);

  // Random token request
  Randomize;
  FTokRequest := Word(Random($FFFF));
  Pkt.TokRequest := FTokRequest;
  Pkt.Token := 0;  // No token yet

  // Encode username and password
  IcomPasscode(FUsername, Pkt.Username);
  IcomPasscode(FPassword, Pkt.Password);

  // Client name (ASCII, null-padded)
  for I := 1 to Length(FClientName) do
     begin
     if I > 16 then Break;
     Pkt.ClientName[I - 1] := Byte(FClientName[I]);
     end;

  // Send via SendTrackedPacket (uses FSendSeq, stored in TX buffer)
  SetLength(PktStr, SizeOf(Pkt));
  Move(Pkt, PktStr[1], SizeOf(Pkt));
  SendTrackedPacket(FControlSocket, PktStr, FRadioAddress, FControlPort, FSendSeq);

  logger.Debug(LogPrefix + ' Sent login packet, authSeq=$%.4x, outerSeq=%d',
               [FAuthSeq, FSendSeq - 1]);
end;

procedure TIcomNetworkTransport.SendTokenAck;
var
  Pkt: TTokenPacket;
  PktStr: AnsiString;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_TOKEN_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_DATA;  // Auth packets use PktType=0 (same as DATA)
  Pkt.Seq := 0;  // Placeholder — SendTrackedPacket patches bytes [6..7]
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FRemoteId;
  Pkt.PayloadSize := SwapLongWord(ICOM_TOKEN_PKT_SIZE - $10);
  Pkt.RequestReply := $01;
  Pkt.RequestType := ICOM_TOKEN_ACK;
  Pkt.InnerSeq := SwapWord(FAuthSeq);
  Inc(FAuthSeq);
  Pkt.TokRequest := FTokRequest;
  Pkt.Token := FToken;
  Pkt.AuthStartID := FAuthStartId;
  Pkt.ResetCap := SwapWord(ICOM_RESET_CAP);
  Pkt.CommonCap := FCommonCap;
  Move(FMacAddress, Pkt.MacAddress, 6);

  // Send via SendTrackedPacket (uses FSendSeq, stored in TX buffer)
  SetLength(PktStr, SizeOf(Pkt));
  Move(Pkt, PktStr[1], SizeOf(Pkt));
  SendTrackedPacket(FControlSocket, PktStr, FRadioAddress, FControlPort, FSendSeq);

  logger.Debug(LogPrefix + ' Sent token ack, token=$%.8x, outerSeq=%d',
               [FToken, FSendSeq - 1]);
end;

procedure TIcomNetworkTransport.SendTokenRenew;
var
  Pkt: TTokenPacket;
  PktStr: AnsiString;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_TOKEN_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_DATA;  // Auth packets use PktType=0 (same as DATA)
  Pkt.Seq := 0;  // Placeholder — SendTrackedPacket patches bytes [6..7]
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FRemoteId;
  Pkt.PayloadSize := SwapLongWord(ICOM_TOKEN_PKT_SIZE - $10);
  Pkt.RequestReply := $01;
  Pkt.RequestType := ICOM_TOKEN_RENEW;
  Inc(FAuthSeq);
  Pkt.InnerSeq := SwapWord(FAuthSeq);
  Pkt.TokRequest := FTokRequest;
  Pkt.Token := FToken;
  Pkt.AuthStartID := FAuthStartId;
  Pkt.ResetCap := SwapWord(ICOM_RESET_CAP);
  Pkt.CommonCap := FCommonCap;
  Move(FMacAddress, Pkt.MacAddress, 6);

  // Send via SendTrackedPacket (uses FSendSeq, stored in TX buffer)
  SetLength(PktStr, SizeOf(Pkt));
  Move(Pkt, PktStr[1], SizeOf(Pkt));
  SendTrackedPacket(FControlSocket, PktStr, FRadioAddress, FControlPort, FSendSeq);

  logger.Trace(LogPrefix + ' Sent token renewal, outerSeq=%d', [FSendSeq - 1]);
end;

procedure TIcomNetworkTransport.SendStreamRequest;
var
  Pkt: TConnInfoPacket;
  I: Integer;
  NameBytes: string;
  PktStr: AnsiString;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_CONNINFO_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_DATA;  // Auth packets use PktType=0 (same as DATA)
  Pkt.Seq := 0;  // Placeholder — SendTrackedPacket patches bytes [6..7]
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FRemoteId;
  Pkt.PayloadSize := SwapLongWord(ICOM_CONNINFO_PKT_SIZE - $10);
  Pkt.RequestReply := $01;
  Pkt.RequestType := ICOM_CONNINFO_REQUEST;
  Pkt.InnerSeq := SwapWord(FAuthSeq);
  Inc(FAuthSeq);
  Pkt.TokRequest := FTokRequest;
  Pkt.Token := FToken;

  (* THE IDENTITY BLOCK.  A radio whose capabilities carry $8010 is identified
    by its MAC, packed into the same sixteen bytes.

    THE OTHER BRANCH IS DELETED, NOT LEFT UNREACHED (2026-09-24).  It read
    "Move(FGUID, Pkt.GUID, 16)" against an FGUID that was declared, never
    assigned anywhere in this unit, and therefore always sixteen zero bytes.
    It was not a defect waiting for the right radio; it was a path that could
    not work, sitting here looking supported.

    AND IT CANNOT SIMPLY BE FILLED IN.  The value that belongs there is the
    RADIO's own GUID, echoed back -- rigplane reads it out of a received
    ConnInfo packet at offset $20, sixteen bytes
    (src/rigplane/runtime/_control_phase.py:898) and passes it to its conninfo
    builder (:924).  This transport receives ConnInfo packets too, but the
    ordering measured on the 2026-09-24 IC-9700 log is against us: the first
    144-byte packet the radio sends arrives AFTER our stream request, never
    before it, so at this point in our handshake there is no GUID to echo.
    Harvesting one would mean restructuring the handshake to wait for a packet
    this radio does not send unprompted.

    So the honest statement is that this transport supports MAC-identified
    radios and no others, and it says so in the log rather than sending
    sixteen zeroes and letting the session request fail without explanation.
    Both radios on the bench report CommonCap=$8010. *)
  if (FCommonCap and $8010) = $8010 then
     begin
     Move(FMacAddress, Pkt.GUID[10], 6);  // MAC at offset $0A within GUID field
     Pkt.GUID[7] := Hi(FCommonCap);
     Pkt.GUID[8] := Lo(FCommonCap);
     end
  else
     begin
     logger.Error(LogPrefix + ' Radio reports CommonCap=$%.4x, which does not ' +
                  'carry the $8010 MAC-identity bits.  This transport has no ' +
                  'other way to identify the client, so the stream request is ' +
                  'being sent with an empty identity block and the radio will ' +
                  'very likely reject it.', [FCommonCap]);
     end;

  // Radio name
  NameBytes := FRadioName;
  for I := 1 to Length(NameBytes) do
     begin
     if I > 32 then Break;
     Pkt.RadioName[I - 1] := Byte(NameBytes[I]);
     end;

  // Encoded username
  IcomPasscode(FUsername, Pkt.Username);

  // Stream parameters (CI-V control only, no audio)
  Pkt.RxEnable := 1;
  Pkt.TxEnable := 0;
  Pkt.RxCodec := $04;  // LPCM
  Pkt.TxCodec := 0;
  Pkt.RxSample := SwapLongWord(8000);
  Pkt.TxSample := 0;

  // Tell radio our local CI-V port so it knows where to send CI-V data
  if (FCivSocket <> nil) and (FCivSocket.Bindings.Count > 0) then
     begin
     Pkt.CivPort := SwapLongWord(FCivSocket.Bindings[0].Port)
     end
  else
     begin
     Pkt.CivPort := 0;
     end;
  Pkt.AudioPort := 0;
  Pkt.TxBuffer := 0;
  Pkt.Convert := 1;

  // Send via SendTrackedPacket (uses FSendSeq, stored in TX buffer)
  SetLength(PktStr, SizeOf(Pkt));
  Move(Pkt, PktStr[1], SizeOf(Pkt));
  SendTrackedPacket(FControlSocket, PktStr, FRadioAddress, FControlPort, FSendSeq);

  logger.Debug(LogPrefix + ' Sent stream request for radio %s, outerSeq=%d',
    [FRadioName, FSendSeq - 1]);
end;

procedure TIcomNetworkTransport.SendCivOpen;
var
  Pkt: TOpenClosePacket;
  PktStr: AnsiString;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_OPENCLOSE_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_DATA;
  Pkt.Seq := 0;  // Placeholder — SendTrackedPacket patches bytes [6..7]
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FCivRemoteId;
  Pkt.Data := ICOM_OPENCLOSE_DATA;
  Pkt.SendSeq := SwapWord(FCivInnerSeq);
  Inc(FCivInnerSeq);
  Pkt.Magic := ICOM_MAGIC_OPEN;

  SetLength(PktStr, SizeOf(Pkt));
  Move(Pkt, PktStr[1], SizeOf(Pkt));
  SendTrackedPacket(FCivSocket, PktStr, FRadioAddress, FCivPort, FCivSeq);

  logger.Debug(LogPrefix + ' Sent CI-V Open (seq=%d)', [FCivSeq - 1]);
end;

procedure TIcomNetworkTransport.SendCivClose;
var
  Pkt: TOpenClosePacket;
  PktStr: AnsiString;
begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_OPENCLOSE_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_DATA;
  Pkt.Seq := 0;  // Placeholder — SendTrackedPacket patches bytes [6..7]
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FCivRemoteId;
  Pkt.Data := ICOM_OPENCLOSE_DATA;
  Pkt.SendSeq := SwapWord(FCivInnerSeq);
  Inc(FCivInnerSeq);
  Pkt.Magic := ICOM_MAGIC_CLOSE;

  SetLength(PktStr, SizeOf(Pkt));
  Move(Pkt, PktStr[1], SizeOf(Pkt));
  SendTrackedPacket(FCivSocket, PktStr, FRadioAddress, FCivPort, FCivSeq);

  logger.Debug(LogPrefix + ' Sent CI-V Close (seq=%d)', [FCivSeq - 1]);
end;

procedure TIcomNetworkTransport.SendIdlePacket;
var
  Pkt: TControlPacket;
  PktStr: AnsiString;
begin
  // Send idle (type=0, 16-byte) on CONTROL SOCKET ONLY (matches wfview)
  if FControlSocket = nil then Exit;

  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Len := ICOM_CONTROL_PKT_SIZE;
  Pkt.PktType := ICOM_PKT_DATA;
  Pkt.Seq := 0;  // Placeholder — patched by SendTrackedPacket
  Pkt.SentID := FMyId;
  Pkt.RcvdID := FRemoteId;

  SetLength(PktStr, SizeOf(Pkt));
  Move(Pkt, PktStr[1], SizeOf(Pkt));
  SendTrackedPacket(FControlSocket, PktStr, FRadioAddress, FControlPort, FSendSeq);
end;

(* SEND ONE UDP PACKET -- THROUGH INDY, AND LOUDLY.

  WHAT WAS HERE, AND WHY IT IS NOT ANY MORE. This called sendto() imported
  straight from ws2_32.dll, with a hand-built sockaddr_in, and said why:

      Use direct WinSock sendto() to avoid TIdUDPServer.SendBuffer deadlock
      when called from the main thread while Indy read threads are active.

  So the bypass was a real fix for a real hang. It is also Windows-only, and
  NY4I's call (2026-09-08) is that WinSock is no longer an option: back to
  Indy, and bench-test to find out what the deadlock actually was.

  WHICH IS WHY EVERY LINE BELOW IS INSTRUMENTED THE WAY IT IS. A deadlock does
  not come back to report itself -- the send never returns, so anything logged
  AFTER it is lost. The "about to send" line therefore carries EVERYTHING
  needed to identify the hang: which socket, which thread and whether it is the
  main one, how many sends are already in flight, the target, and the length.
  If tr4w.log ends on an ENTER line with no matching EXIT, that line names the
  conditions.

  What to look for on the bench:

    * an ENTER with no EXIT -- the deadlock, and the line says which thread and
      what was in flight;
    * `inflight=` greater than 1 -- two threads inside Indy's send at once,
      which is the shape the original comment suspected;
    * `mainthread=True` on the stuck one -- the specific case it named;
    * a `SLOW SEND` warning -- Indy blocking for tens of ms without deadlocking
      is the same contention, survived.

  FSendInFlight is bumped with the RTL's interlocked increment rather than
  under FSendLock, deliberately: the lock is what a deadlock would be waiting
  ON, so the counter has to be readable without taking it. *)
procedure TIcomNetworkTransport.SendRawPacket(Socket: TIdUDPServer;
  const Data; DataLen: Integer; TargetAddr: string; TargetPort: Word);
var
  Bytes:    TIdBytes;
  Started:  QWord;
  Elapsed:  QWord;
  InFlight: LongInt;
  IsMain:   boolean;
begin
  if Socket = nil then
     begin
     logger.Error(LogPrefix + ' SendRawPacket: socket is nil');
     Exit;
     end;

  if Socket.Bindings.Count = 0 then
     begin
     logger.Error(LogPrefix + ' SendRawPacket: no socket binding');
     Exit;
     end;

  (* Compared at pointer width -- see the note on FreeThread above. The two
    sides do not even agree in declared type on macOS. *)
  IsMain   := PtrUInt(GetCurrentThreadId) = PtrUInt(MainThreadID);
  InFlight := System.InterLockedIncrement(FSendInFlight);
  try
     (* THE LINE THAT SURVIVES A HANG. Everything a diagnosis needs is here,
       because if Indy blocks there will be no second line. *)
     logger.Debug('[IcomTransport:%s] SEND ENTER port=%d -> %s:%d len=%d '
                  + 'thread=%u mainthread=%s inflight=%d active=%s',
                  [FRadioName, Socket.Bindings[0].Port, TargetAddr, TargetPort,
                   DataLen, GetCurrentThreadId, BoolToStr(IsMain, True),
                   InFlight, BoolToStr(Socket.Active, True)]);

     if InFlight > 1 then
        begin
        (* Two threads inside the send at once. Not fatal in itself, and
          exactly the condition the old ws2_32 comment blamed -- so it is
          worth a line of its own whether or not anything hangs. *)
        logger.Warn('[IcomTransport:%s] SEND OVERLAP: %d sends in flight '
                    + '(this one on thread %u, mainthread=%s)',
                    [FRadioName, InFlight, GetCurrentThreadId,
                     BoolToStr(IsMain, True)]);
        end;

     SetLength(Bytes, 0);
     Bytes   := RawToBytes(Data, DataLen);
     Started := GetTickCount64;
     try
        (* AnsiString explicitly -- Indy's host parameter, same reason as in
          GetLocalIPForRoute: an IPv4 dotted quad is ASCII. *)
        Socket.SendBuffer(AnsiString(TargetAddr), TargetPort, Bytes);
     except
        on E: Exception do
           begin
           logger.Error('[IcomTransport:%s] SEND FAILED after %d ms -> %s:%d '
                        + 'len=%d thread=%u: %s: %s',
                        [FRadioName, GetTickCount64 - Started, TargetAddr,
                         TargetPort, DataLen, GetCurrentThreadId,
                         E.ClassName, E.Message]);
           Exit;
           end;
     end;
     Elapsed := GetTickCount64 - Started;

     if Elapsed >= SEND_SLOW_MS then
        begin
        (* Survived, but blocked. The same contention as the deadlock, and the
          only version of it a bench run can see WITHOUT the program stopping,
          so it is the more likely thing to catch. *)
        logger.Warn('[IcomTransport:%s] SLOW SEND: %d ms for %d byte(s) -> %s:%d '
                    + '(thread=%u mainthread=%s inflight=%d)',
                    [FRadioName, Elapsed, DataLen, TargetAddr, TargetPort,
                     GetCurrentThreadId, BoolToStr(IsMain, True), InFlight]);
        end
     else
        begin
        logger.Debug('[IcomTransport:%s] SEND EXIT  %d ms',
                     [FRadioName, Elapsed]);
        end;
  finally
     System.InterLockedDecrement(FSendInFlight);
  end;
end;

// ============================================================================
// State Management
// ============================================================================

procedure TIcomNetworkTransport.SetState(NewState: TIcomConnectionState);
begin
  if FState <> NewState then
     begin
     logger.Debug(LogPrefix + ' State: %s -> %s',
                 [IcomStateToString(FState), IcomStateToString(NewState)]);
     FState := NewState;

     // Manage the login retry timer
     if (NewState = icsWaitingForLogin) and FTimersLive then
        begin
        FLoginRetryCount := 0;
        StartTimer(ICOM_TIMER_LOGIN, ICOM_LOGIN_TIMEOUT);
        end
     else if FTimersLive then
        begin
        StopTimer(ICOM_TIMER_LOGIN);
        end;

     if Assigned(FOnStateChange) then
        begin
        try
          FOnStateChange(Self);
        except
          on E: Exception do
             begin
             logger.Error(LogPrefix + ' Exception in state change callback: %s', [E.Message]);
             end;
        end;
        end;
     end;
end;

function TIcomNetworkTransport.GetIsConnected: Boolean;
begin
  Result := (FState = icsConnected) and FCivStreamOpen;
end;

// CI-V data is the heartbeat for "the radio is actually answering".  FLastCivData
// is stamped only by real CI-V data frames (HandleDataPacket), not by pings or
// keepalives, so it goes stale the moment the radio stops responding (e.g. powered
// off) even though the connectionless UDP session lingers in icsConnected.  Read
// from the polling thread; FLastCivData is a LongWord written by the RX thread --
// an aligned 32-bit read/write is atomic on x86, so no lock is needed.  Unsigned
// subtraction handles TickCount32 wraparound.  Issue #1062.
function TIcomNetworkTransport.GetCivDataFresh: Boolean;
begin
  Result := (TickCount32 - FLastCivData) < ICOM_CIV_OPERATIONAL_TIMEOUT_MS;
end;

// ============================================================================
// Timer Management
// ============================================================================

procedure TIcomNetworkTransport.StopTimers;
begin
  if not FTimersLive then Exit;

  StopTimer(ICOM_TIMER_PING);
  StopTimer(ICOM_TIMER_IDLE);
  StopTimer(ICOM_TIMER_TOKEN);
  StopTimer(ICOM_TIMER_CIV_WATCHDOG);
  StopTimer(ICOM_TIMER_AYT);
  StopTimer(ICOM_TIMER_LOGIN);

  logger.Debug(LogPrefix + ' All timers stopped');
end;

procedure TIcomNetworkTransport.OnPingTimer;
begin
  // Ping runs from I Am Here onward (control socket keepalive)
  if FState = icsDisconnected then
     begin
     Exit;
     end;

  SendPing;

  // Dead-radio detection: if we are fully connected and the radio has not sent us
  // a ping in ICOM_PING_DEAD_TIMEOUT_MS, the WiFi/network link is gone.
  // UDP is connectionless so we only discover this via absence of inbound pings.
  // Disconnect here; the polling thread will attempt to reconnect.
  if (FState = icsConnected) and (FLastPingReceived <> 0) then
     begin
     if TickCount32 - FLastPingReceived > ICOM_PING_DEAD_TIMEOUT_MS then
        begin
        logger.Warn(LogPrefix + ' No ping from radio for %d ms — network link lost, disconnecting',
                    [TickCount32 - FLastPingReceived]);
        Disconnect;
        end;
     end;
end;

procedure TIcomNetworkTransport.OnIdleTimer;
begin
  // Idle runs from I Am Here onward (control socket keepalive)
  if FState = icsDisconnected then
     begin
     Exit;
     end;

  (* A TRACKED SEND IS ITSELF A KEEPALIVE, so skip this turn if one is recent.
    Same intent as before -- "only fire idle if no tracked packet was sent for
    100 ms" -- but read from a timestamp here rather than by re-arming this
    timer from inside SendTrackedPacket, which ran on the CI-V send thread. *)
  if TickCount32 - FLastTrackedSend < ICOM_IDLE_INTERVAL then
     begin
     Exit;
     end;

  SendIdlePacket;
end;

procedure TIcomNetworkTransport.OnTokenRenewalTimer;
begin
  // Token renewal only while connected (state >= Authenticated)
  if FState >= icsAuthenticated then
     begin
     SendTokenRenew;
     end;
end;

procedure TIcomNetworkTransport.OnCivWatchdogTimer;
var
  Elapsed: LongWord;
begin
  if not FCivStreamOpen then Exit;

  Elapsed := TickCount32 - FLastCivData;
  if Elapsed > ICOM_CIV_TIMEOUT_THRESHOLD then
     begin
     // Matches wfview watchdogTimeout(): if stale 2s, send one CivOpen.
     logger.Warn(LogPrefix + ' CI-V data timeout (%d ms), sending CivOpen',
                 [Elapsed]);
     SendCivOpen;
     end;
end;

procedure TIcomNetworkTransport.OnAYTTimer;
begin
  if FState <> icsWaitingForHere then
     begin
     StopTimer(ICOM_TIMER_AYT);
     Exit;
     end;

  Inc(FAYTRetryCount);
  if FAYTRetryCount > ICOM_AYT_MAX_RETRIES then
     begin
     logger.Error(LogPrefix + ' Radio not found at %s:%d after %d retries',
                  [FRadioAddress, FControlPort, ICOM_AYT_MAX_RETRIES]);
     StopTimer(ICOM_TIMER_AYT);
     Disconnect;
     Exit;
     end;

  // Exponential backoff
  FAYTInterval := FAYTInterval * 2;
  if FAYTInterval > ICOM_AYT_MAX_INTERVAL then
     begin
     FAYTInterval := ICOM_AYT_MAX_INTERVAL;
     end;

  // Resend "Are You There" — AYT always uses Seq=0
  SendControlPacket(ICOM_PKT_ARE_YOU_THERE, FControlSocket,
    0, FRadioAddress, FControlPort, 0);

  // Update timer interval
  StopTimer(ICOM_TIMER_AYT);
  StartTimer(ICOM_TIMER_AYT, FAYTInterval);

  logger.Debug(LogPrefix + ' AYT retry %d/%d, interval=%dms',
               [FAYTRetryCount, ICOM_AYT_MAX_RETRIES, FAYTInterval]);
end;

procedure TIcomNetworkTransport.OnLoginTimer;
begin
  if FState <> icsWaitingForLogin then
     begin
     StopTimer(ICOM_TIMER_LOGIN);
     Exit;
     end;

  Inc(FLoginRetryCount);
  if FLoginRetryCount > ICOM_LOGIN_MAX_RETRIES then
     begin
     logger.Error(LogPrefix + ' No login response after %d retries - giving up',
                  [ICOM_LOGIN_MAX_RETRIES]);
     StopTimer(ICOM_TIMER_LOGIN);
     Disconnect;
     Exit;
     end;

  // Resend login packet. The radio may have been busy or a stale session
  // (from a previous run) may still be active on the radio.
  logger.Debug(LogPrefix + ' Login timeout - resending login packet (retry %d/%d)',
               [FLoginRetryCount, ICOM_LOGIN_MAX_RETRIES]);
  SendLoginPacket;
end;

// ============================================================================
// SendTrackedPacket — central path for all sequenced sends
// ============================================================================

procedure TIcomNetworkTransport.SendTrackedPacket(Socket: TIdUDPServer;
  const Data: AnsiString; TargetAddr: string; TargetPort: Word;
  var SeqCounter: Word);
var
  Packet: AnsiString;
  TxBuf: TList;
begin
  Packet := Data;

  // Patch bytes [7..8] (1-indexed string) = offset 6..7 with current SeqCounter (LE)
  if Length(Packet) >= 8 then
     begin
     Packet[7] := AnsiChar(SeqCounter and $FF);
     Packet[8] := AnsiChar((SeqCounter shr 8) and $FF);
     end;

  // Store in TX buffer for radio's retransmit requests
  if Socket = FControlSocket then
     begin
     TxBuf := FControlTxBuf
     end
  else
     begin
     TxBuf := FCivTxBuf;
     end;

  // seq=0 resets the buffer (sequence wrap or initial connect)
  if SeqCounter = 0 then
     begin
     ClearTxBuffer(TxBuf);
     end;

  AddToTxBuffer(TxBuf, SeqCounter, Packet);

  // Send
  FSendLock.Enter;
  try
    SendRawPacket(Socket, Packet[1], Length(Packet), TargetAddr, TargetPort);
  finally
    FSendLock.Leave;
  end;

  // Increment sequence counter (caller's variable updated by reference)
  Inc(SeqCounter);

  (* DEFER THE IDLE KEEPALIVE -- a tracked send has just served that purpose.

    This used to stop and restart the idle TTimer from here.  THIS ROUTINE RUNS
    ON THE CI-V SEND THREAD, so that was toggling Enabled on a widget-set timer
    from a worker -- which on Win32 means KillTimer/SetTimer against whatever
    thread happened to own it, plus an unsynchronised mutation of the widget
    set's own timer list.  A timestamp the idle handler reads is the whole
    mechanism now; see OnIdleTimer. *)
  FLastTrackedSend := TickCount32;
end;

// ============================================================================
// TX Buffer Management
// ============================================================================

procedure TIcomNetworkTransport.AddToTxBuffer(BufList: TList; Seq: Word; const Data: AnsiString);
var
  Entry: PSeqBufEntry;
begin
  New(Entry);
  Entry^.Seq := Seq;
  Entry^.Data := Data;
  Entry^.SendTime := TickCount32;
  Entry^.RetransmitCount := 0;
  BufList.Add(Entry);

  // Evict oldest if over BUFSIZE
  while BufList.Count > ICOM_BUFSIZE do
     begin
     Dispose(PSeqBufEntry(BufList[0]));
     BufList.Delete(0);
     end;
end;

function TIcomNetworkTransport.FindInTxBuffer(BufList: TList; Seq: Word): AnsiString;
var
  I: Integer;
  Entry: PSeqBufEntry;
begin
  Result := '';
  for I := BufList.Count - 1 downto 0 do
     begin
     Entry := PSeqBufEntry(BufList[I]);
     if Entry^.Seq = Seq then
        begin
        Result := Entry^.Data;
        Exit;
        end;
     end;
end;

procedure TIcomNetworkTransport.ClearTxBuffer(BufList: TList);
var
  I: Integer;
begin
  if BufList = nil then
     begin
     Exit;
     end;
  for I := BufList.Count - 1 downto 0 do
     begin
     Dispose(PSeqBufEntry(BufList[I]));
     end;
  BufList.Clear;
end;

procedure TIcomNetworkTransport.ClearAllBuffers;
begin
  ClearTxBuffer(FControlTxBuf);
  ClearTxBuffer(FCivTxBuf);
end;

// ============================================================================
// Handle Incoming Retransmit Requests from Radio
// ============================================================================

procedure TIcomNetworkTransport.HandleRetransmitRequest(
  const Data: array of Byte; DataLen: Integer; FromCivSocket: Boolean);
var
  Pkt: TControlPacket;
  TxBuf: TList;
  StoredPkt: AnsiString;
  Socket: TIdUDPServer;
  TargetAddr: string;
  TargetPort: Word;
  Offset: Integer;
  ReqSeq: Word;
begin
  if DataLen < SizeOf(TControlPacket) then Exit;
  Move(Data[0], Pkt, SizeOf(TControlPacket));

  if FromCivSocket then
     begin
     TxBuf := FCivTxBuf;
     Socket := FCivSocket;
     TargetAddr := FRadioAddress;
     TargetPort := FCivPort;
     end
  else
     begin
     TxBuf := FControlTxBuf;
     Socket := FControlSocket;
     TargetAddr := FRadioAddress;
     TargetPort := FControlPort;
     end;

  if Socket = nil then Exit;

  if DataLen = ICOM_CONTROL_PKT_SIZE then
     begin
     // Single retransmit request — Pkt.Seq is the seq they want
     StoredPkt := FindInTxBuffer(TxBuf, Pkt.Seq);
     if Length(StoredPkt) > 0 then
        begin
        FSendLock.Enter;
        try
          SendRawPacket(Socket, StoredPkt[1], Length(StoredPkt), TargetAddr, TargetPort);
        finally
          FSendLock.Leave;
        end;
        logger.Debug(LogPrefix + ' Retransmitted seq %d (single request)', [Pkt.Seq]);
        end
     else
        begin
        logger.Debug(LogPrefix + ' Retransmit request for seq %d - not in buffer', [Pkt.Seq]);
        end;
     end
  else if DataLen > ICOM_CONTROL_PKT_SIZE then
     begin
     // Multi retransmit request — seq list follows header
     Offset := ICOM_CONTROL_PKT_SIZE;
     while Offset + 1 < DataLen do
        begin
        ReqSeq := Word(Data[Offset]) or (Word(Data[Offset + 1]) shl 8);
        StoredPkt := FindInTxBuffer(TxBuf, ReqSeq);
        if Length(StoredPkt) > 0 then
           begin
           FSendLock.Enter;
           try
             SendRawPacket(Socket, StoredPkt[1], Length(StoredPkt), TargetAddr, TargetPort);
           finally
             FSendLock.Leave;
           end;
           logger.Debug(LogPrefix + ' Retransmitted seq %d (multi request)', [ReqSeq]);
           end;
        Inc(Offset, 2);
        end;
     end;
end;

// ============================================================================
// Initialization
// ============================================================================

initialization
  logger := TLogLogger.GetLogger('uIcomNetworkTransport');

end.
