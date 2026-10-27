unit uExternalLoggerBase;
{$I tr4w.inc}

interface

uses
   IdTCPClient, IdComponent, IdTCPConnection,IdThreadComponent, IdExceptionCore, SysUtils,
   Classes, StrUtils, Log4D, VC, Tree, IdException, IdStack, SyncObjs;

Type TProcessMsgRef = procedure (sMessage: string) of Object;

   // Issue #957 -- outbound operation queue.
   // External loggers receive commands off the main thread: the main thread only
   // ENQUEUES an operation (a cheap locked append) and returns; a dedicated sender
   // thread connects, sends, and retries.  DXKeeper closes the TCP connection after
   // each command (by design, confirmed with AA6YQ), so the sender does one
   // connect->send->close per command (see TExternalLogger.DeliverCommand).
   //
   // A Replace (the QSO-edit path) is ONE atomic operation: the re-log is sent only
   // if the delete succeeded.  Order is forced -- the QSO identity is
   // CALL+QSO_DATE+TIME_ON, unchanged by a mode edit, so a relog-first-then-delete
   // would delete both records.  DXKeeper has no atomic replace, so a
   // delete-succeeded / relog-failed window is unavoidable; it is logged loudly
   // (anti-silent-loss) rather than swallowed.  A replayable persistent queue is
   // deferred to the Delphi 12 conversion (SQLite global state).
Type
   TExternalLogOpKind = (eloSingle, eloReplace);

   TExternalLogOp = class(TObject)
   public
      Kind: TExternalLogOpKind;
      Cmd1: string;          // single command, or the delete (for eloReplace)
      Cmd2: string;          // the re-log (for eloReplace); unused for eloSingle
      Description: string;   // human-readable, for logging
   end;


Type TSimpleEventProc = procedure(const aStrParam:string) of object;

(* The reading thread's way back into the owner's connect: it takes the owner's
  connect lock and RAISES on failure, so the thread's back-off still sees the
  exception.  See TExternalLoggerBase.ReconnectFromReader. *)
Type TReconnectProc = procedure of object;

Type TReadingThread = class(TThread)
  protected
    readTerminator: string;
    FConn: TIdTCPConnection;
    msgHandler: TProcessMsgRef;
    FReconnect: TReconnectProc;
    procedure Execute; override;
    procedure DoTerminate; override;
  public
    constructor Create(AConn: TIdTCPConnection; proc: TProcessMsgRef; AReconnect: TReconnectProc); reintroduce;
  end;

function BoolToString(b: boolean): string;

// Add telnet client to this base class
// Add property for IP address, port, type (tcp or udp but just implement tcp right now).
// Add a connect and disconnect method

Type ExternalLoggerType = (lt_NoExternalLogger, lt_DXKeeper, lt_ACLog, lt_HRD);

(* THE CONFIG-FILE TOKEN FOR EACH LOGGER, IN ORDINAL ORDER.

  string, NOT PAnsiChar, since 2026-09-13: nothing indexes it through a
  pointer any more. uCFG used to, through ListParamArray; the setting holds
  the token itself now and this array is what the factory maps with and what
  the settings model is told to accept.

  IT IS REGISTERED BY NAME so Lint-SpellingTables can still check it -- a
  duplicate or blank here would make a logger unreachable by name, which is
  exactly what that lint is for. *)
const ExternalLoggerTypeSA                     : array[ExternalLoggerType] of string = ('NONE', 'DXKEEPER', 'ACLOG', 'HRD');

   // Reconnection configuration
   RECONNECT_INITIAL_DELAY = 1000;    // 1 second initial delay
   RECONNECT_MAX_DELAY = 30000;       // 30 seconds max delay
   RECONNECT_BACKOFF_MULTIPLIER = 2;  // Double delay each retry

const
   // Issue #957 -- bounded outbound-send retry (we do not try very hard; a
   // replayable persistent queue is deferred to the D12/SQLite work).
   SEND_MAX_ATTEMPTS         = 3;       // attempts per command before giving up
   SEND_RETRY_BASE_DELAY     = 500;     // ms; backoff delay = attempt * this
   SHUTDOWN_DRAIN_TIMEOUT_MS = 3000;    // bounded wait to flush the queue at shutdown

Type
   TExternalLoggerBase = class;   // forward, for TSenderThread.FOwner

   // Drains the outbound operation queue off the main thread.  One sender thread
   // per logger instance; it is the sole owner of the send path.
   TSenderThread = class(TThread)
   private
      FOwner: TExternalLoggerBase;
   protected
      procedure Execute; override;
   public
      constructor Create(AOwner: TExternalLoggerBase);
   end;

   TExternalLoggerBase = class(TObject)
   private
      //socket: TIdTCPClient;
      //idThreadComponent   : TIdThreadComponent;
      localAddress: string;
      localPort: integer;
      localLoggerID: string;
      rt: TReadingThread;
      baseProcMsg: TProcessMsgRef;

      // Issue #957 -- outbound operation queue + its sender thread.
      FOpQueue: TList;              // of TExternalLogOp (owned; freed after processing)
      FQueueLock: SyncObjs.TCriticalSection; // guards FOpQueue
      FQueueEvent: SyncObjs.TEvent;          // signalled when an op is enqueued
      FSenderThread: TSenderThread;
      FShuttingDown: boolean;

      (* ONE CONNECT AT A TIME, AND RECONNECTION IS THE READING THREAD'S JOB.
        The main thread's Connect and the reading thread's reconnect used to
        run on the one socket at once: EIdAlreadyConnected, or two connections
        and double reader state (issue #102).  Every connect goes through
        ConnectGuarded, which holds this lock, returns at once if the link is
        already open, and refuses a non-reader caller while a reading thread
        exists. *)
      FConnectLock: SyncObjs.TCriticalSection;

      function ConnectGuarded(aRaiseOnFailure: boolean): integer;
      procedure ReconnectFromReader;
      procedure InitOutboundQueue;
      procedure ProcessOp(op: TExternalLogOp);
      function DequeueOp: TExternalLogOp;
      function DeliverWithRetry(const cmd: string): boolean;
      function SenderTerminating: boolean;

      function GetLoggerPort: integer;
      procedure SetLoggerPort(Value: Integer);
      function GetLoggerID: string;
      procedure SetLoggerID (Value: string);
      function GetLoggerAddress: string;
      procedure SetLoggerAddress(Value: string);
      function GetIsConnected: boolean;
      procedure OnLoggerConnected(Sender:TObject);
      procedure OnLoggerDisconnected(Sender: TObject);
      procedure OnLoggerStatus(Sender: TObject; const Status: TIdStatus; const AStatusText: TIdText);

   protected
      readTerminator: string;
      socket: TIdTCPClient;
      procRef: TProcessMsgRef;
      logTypeSet: boolean;
      logType: ExternalLoggerType;

      // Transport strategy: deliver one command and return True on success.
      // The base default uses the persistent socket (for future ACLog/HRD);
      // DXKeeper overrides it with a connect-per-command transport (Issue #957).
      function DeliverCommand(const cmd: string): boolean; virtual;

      (* The one place the socket's Connect is called (issue #102).  A seam so
        a test can count attempts; ConnectGuarded holds FConnectLock around it. *)
      procedure DoSocketConnect; virtual;

   public
      constructor Create(ProcRef: TProcessMsgRef); overload;
      constructor Create(address: string; port: integer;ProcRef: TProcessMsgRef); overload;
      (* override, NOT overload; virtual: that spelling declared a NEW slot that
        hid TObject.Destroy, so FreeAndNil(externalLogger) ran NO destructor --
        no ShutdownDrain, so QSOs still queued at exit were never flushed or
        even reported. *)
      Destructor Destroy; override;

      // Issue #957 -- enqueue from the main thread (cheap; returns immediately).
      procedure QueueSingleCommand(const cmd, description: string);
      procedure QueueReplace(const deleteCmd, relogCmd, description: string);
      procedure ShutdownDrain(timeoutMs: integer);

      procedure SendToLogger(s: string); overload;
      property loggerPort: integer read GetLoggerPort write SetLoggerPort;
      property loggerAddress: string read GetLoggerAddress write SetLoggerAddress;
      property loggerID: string read GetLoggerID write SetLoggerID;
      property IsConnected: boolean read GetIsConnected;
      function Connect: integer; overload;
      function Connect (address: string; port: integer): integer; overload;

      procedure Disconnect; overload;


   public

      procedure ProcessMsg(msg: string); Virtual; Abstract;

end;

(* elLogType MOVED to Settings.ExternalLogger.LoggerType, 2026-09-13 -- as a
  TOKEN. The enum stays here because it is what CreateLogger takes. *)
implementation

Uses MainUnit,
     uIndyLink;         (* IndyLinkIsOpen and IndyLinkOwnHandler -- see its header *)

(* THE RULE FOR THE PERSISTENT SOCKET (ACLog / HRD; DXKeeper does not use it).

  ONLY THE READING THREAD (TReadingThread) MAY CALL socket.Connected, and a
  bare socket.Disconnect is Disconnect(True), which calls Connected first.
  Indy's Connected READS the socket -- a zero-timeout select and then a
  blocking recv into the InputBuffer the reader is consuming -- so from the
  main thread or the sender thread it can block for ever or steal the reader's
  bytes (the network-radio hang of 2026-10-25, commit a4866344).  Everything
  else asks IndyLinkIsOpen (fields only) and calls Disconnect(False).

  DXKeeper never reaches this: TExternalLogger.DeliverCommand opens a client of
  its own per command on the sender thread, and that thread is the only one that
  ever touches it, so its Connected is a read by the owner. *)


Constructor TExternalLoggerBase.Create(ProcRef: TProcessMsgRef);
begin
   baseProcMsg := ProcRef;

   FConnectLock := SyncObjs.TCriticalSection.Create;
   socket := TIdTCPClient.Create();
   socket.ConnectTimeout := INDY_LINK_CONNECT_TIMEOUT_MS;
   socket.OnDisconnected := Self.OnLoggerDisconnected;
   socket.OnConnected := Self.OnLoggerConnected;
   socket.OnStatus := Self.OnLoggerStatus;

   InitOutboundQueue;
end;

{Constructor TExternalLoggerBase.Create(ProcRef: TProcessMsgRef);
begin
   baseProcMsg := ProcRef;
   inherited Create;
end;}

Constructor TExternalLoggerBase.Create(address: string; port: integer; ProcRef: TProcessMsgRef);
begin
   Self.loggerAddress := address;
   Self.loggerPort := port;
   Self.Create(ProcRef);
end;

Destructor TExternalLoggerBase.Destroy;
begin
   // Issue #957 -- flush and stop the outbound sender before tearing anything else
   // down (the sender owns the send path).  ShutdownDrain logs anything undelivered.
   ShutdownDrain(SHUTDOWN_DRAIN_TIMEOUT_MS);
   if FOpQueue <> nil then
      begin
      while FOpQueue.Count > 0 do
         begin
         TExternalLogOp(FOpQueue[0]).Free;
         FOpQueue.Delete(0);
         end;
      FreeAndNil(FOpQueue);
      end;
   FreeAndNil(FQueueLock);
   FreeAndNil(FQueueEvent);

   (* Order matters.  Close the socket first (that pulls the reading thread off
     ReadLn and, through OnDisconnected, stops it).  Make sure the reading
     thread is gone.  Only then free the socket: the thread dereferences it,
     so freeing it earlier left a reader in its reconnect loop calling Connect
     on freed memory. *)
   if socket <> nil then
      begin
      try
         if IndyLinkIsOpen(socket) then
            begin
            socket.Disconnect(False);
            end;
      except
         on E: Exception do
            begin
            logger.Debug('[TExternalLoggerBase.Destroy] Exception during disconnect: %s', [E.Message]);
            end;
      end;
      end;

   if assigned(rt) then
      begin
      FreeAndNil(rt);
      end;

   FreeAndNil(socket);
   FreeAndNil(FConnectLock);
   inherited Destroy;
end;

// Events

procedure TExternalLoggerBase.OnLoggerConnected(Sender: TObject);
begin
   logger.Info('External logger connected');
   // Only create reading thread if one doesn't already exist
   // (the thread creates itself during reconnection)
   if rt = nil then
      begin
      rt := TReadingThread.Create(socket, baseProcMsg, Self.ReconnectFromReader);
      rt.readTerminator := Self.readTerminator;
      logger.Info('Created new reading thread');
      end
   else
      begin
      logger.Info('Reading thread already exists, no need to create new one');
      end;
end;

procedure TExternalLoggerBase.OnLoggerDisconnected(Sender: TObject);
begin
   logger.Info('<<<<<<<<<<<<<< External logger disconnected');
   if rt <> nil then
      begin
      rt.Terminate;
      rt.WaitFor;
      FreeAndNil(rt);
      end;
end;

procedure TExternalLoggerBase.OnLoggerStatus(Sender: TObject; const Status: TIdStatus; const AStatusText: TIdText);
begin
   logger.trace('Received text from external logger: [%s]',[AStatusText]);
end;

function TExternalLoggerBase.GetLoggerPort: integer;
begin
   Result := Self.localPort;
end;

procedure TExternalLoggerBase.SetLoggerID(Value: string);
begin
  Self.localLoggerID := Value;
end;

function TExternalLoggerBase.GetLoggerID: string;
begin
  result := Self.localLoggerID;
end;

procedure TExternalLoggerBase.SetLoggerPort(Value: Integer);
begin
   Self.localPort := Value;
   // Since the port was changed, disconnect? Or just wait until next time?

end;

function TExternalLoggerBase.GetLoggerAddress: string;
begin
   Result := Self.localAddress;
end;

procedure TExternalLoggerBase.SetLoggerAddress(Value: string);
begin
  Self.localAddress := Value;
end;

function TExternalLoggerBase.Connect: integer;
begin

   logger.Info('[TExternalLoggerBase.Connect] Connecting to external logger at address %s, port = %d',[Self.loggerAddress,Self.loggerPort]);
    if Self.loggerPort = 0 then
       begin
       logger.Error('[TExternalLoggerBase.Connect] Called connect with port = 0. result = -1');
       Result := -1;
       Exit;
       end;

    if length(Self.loggerAddress) = 0 then
       begin
       logger.Error('[TExternalLoggerBase.Connect] Called connect with address = 0. result = -2');
       Result := -2;
       Exit;
       end;
    if not Assigned(socket) then
       begin
       logger.fatal('In TExternalLoggerBase.Connect, socket is NUL');
       Result := -3;
       Exit;
       end;

    Result := Self.ConnectGuarded(False);
end;

procedure TExternalLoggerBase.DoSocketConnect;
begin
   socket.Connect;
end;

(* 0 = connected (now, or already); -3 = the attempt failed; -4 = not attempted
  because a reading thread exists and the caller is not it.

  The reading thread passes aRaiseOnFailure so its exponential back-off can
  tell a timeout from a refusal; every other caller gets a logged -3. *)
function TExternalLoggerBase.ConnectGuarded(aRaiseOnFailure: boolean): integer;
begin
   Result := 0;
   FConnectLock.Enter;
   try
      if IndyLinkIsOpen(socket) then
         begin
         logger.Debug('[TExternalLoggerBase.Connect] already connected; nothing to do');
         Exit;
         end;

      (* Once a reading thread exists, reconnecting is ITS job (it backs off
        and retries for ever).  A second connector would race it.
        The thread OBJECT is compared, not its id: on macOS a TThreadID is a
        pointer, and comparing it with GetCurrentThreadId does not compile. *)
      if (not aRaiseOnFailure) and (rt <> nil) and (TThread.CurrentThread <> rt) then
         begin
         logger.Debug('[TExternalLoggerBase.Connect] link is down; the reading thread is reconnecting it');
         Result := -4;
         Exit;
         end;

      socket.Port := Self.loggerPort;
      socket.Host := Self.loggerAddress;
      socket.ConnectTimeout := INDY_LINK_CONNECT_TIMEOUT_MS;

      (* An IOHandler of our own, so a failed Connect cannot free it under the
        reading thread or a sender -- see uIndyLink. *)
      IndyLinkOwnHandler(socket, Self.OnLoggerStatus);

      try
         Self.DoSocketConnect;
         logger.Info('[TExternalLoggerBase.Connect] Connected successfully to external logger');
      except
         on E: Exception do
            begin
            Result := -3;
            logger.Error('[TExternalLoggerBase.Connect] Exception when connecting to external logger (%s:%d]: %s', [socket.Host, socket.Port, E.Message]);
            if aRaiseOnFailure then
               begin
               raise;
               end;
            end;
      end;
   finally
      FConnectLock.Leave;
   end;
end;

procedure TExternalLoggerBase.ReconnectFromReader;
begin
   Self.ConnectGuarded(True);
end;

function TExternalLoggerBase.Connect(address: string; port: integer): integer;
begin
   Self.loggerAddress := address;
   Self.loggerPort := port;
   Result := Self.Connect;
end;

procedure TExternalLoggerBase.Disconnect;
begin
   if IndyLinkIsOpen(socket) then
      begin
      try
         logger.debug('Calling Disconnect - user request');
         // Disconnect the socket to pull it off the ReadLn so the thread in Execute sees that it is Terminated.
         // Disconnect(False): the bare form asks Connected, which reads the socket the reader owns.
         socket.Disconnect(False);
         if rt <> nil then
            begin
            rt.Terminate;
            rt.WaitFor;
            FreeAndNil(rt);
            end;
      except
         on E: Exception do
            begin
            logger.Error('Exception when disconnecting from radio: %s', [E.Message]);
            end;
      end;
      end;
end;

procedure TExternalLoggerBase.SendToLogger(s: string);
var nLen: integer;
begin
   try
      if not IndyLinkIsOpen(socket) then
         begin
         Self.Connect;
         end;
      if IndyLinkIsOpen(socket) then
         begin
         logger.Trace('[%s SendToLogger] Sending to radio: (%s) Hex:[%s]',[Self.loggerID,s, String2Hex(s)]);
         //nLen := length(s);
         socket.IOHandler.WriteLn(s);
         //socket.IOHandler.Write(s,nLen,0);
         end
      else
         begin
         logger.error('[SendToLogger] Cannot send command (%s) to logger as not connected',[s]);
         end;
   except
      on E: Exception do
         begin
         logger.error('Exception caught on TExternalLoggerBase.SendToLogger - Command was (%s) - Exception: %s - %s',[s, E.ClassName, E.Message]);
         end;
   end;

end;

function TExternalLoggerBase.GetIsConnected: boolean;
begin
   if Assigned(Self.socket) then
      begin
      Result := IndyLinkIsOpen(socket);
      end
   else
      begin
      logger.debug('In TExternalLoggerBase.GetIsConnected, socket is nil');
      Result := false;
      end;
end;
constructor TReadingThread.Create(AConn: TIdTCPConnection; proc: TProcessMsgRef; AReconnect: TReconnectProc);
begin
  logger.debug('************* DEBUG: TExternalLoggerBase.TReadingThread.Create');
  FConn := AConn;
  FReconnect := AReconnect;

  msgHandler := proc;
  logger.Info('Created ExternalLogger::TReadingTYhreadthread with id %u',[PtrUInt(Self.ThreadID)]);

  inherited Create(False);
end;

procedure TReadingThread.Execute;
var
   cmd: string;
   reconnectDelay: integer;
   consecutiveFailures: integer;
   wasConnected: boolean;
begin
   logger.trace('DEBUG: TExternalLoggerBase.TReadingThread.Execute');
   logger.info('In TExternalLoggerBase.ReadingThread.Execute, readTerminator is [%s]',[Self.readTerminator]);

   reconnectDelay := RECONNECT_INITIAL_DELAY;
   consecutiveFailures := 0;
   wasConnected := False;

   while not Terminated do
      begin
      try
         (* FConn.Connected is correct HERE and only here: this is the reading
           thread, the one party allowed to read the socket. *)
         if FConn.Connected then
            begin
            // Reset retry logic on successful connection
            if not wasConnected then
               begin
               logger.Info('[TExternalLoggerBase.TReadingThread] External logger connected successfully');
               reconnectDelay := RECONNECT_INITIAL_DELAY;
               consecutiveFailures := 0;
               wasConnected := True;
               end;

            // Read data from external logger
            try
               cmd := FConn.IOHandler.ReadLn(Self.readTerminator);
               logger.trace('[TExternalLoggerBase.TReadingThread.Execute] Cmd received: (%s)',[cmd]);

               // Call message handler with exception protection
               try
                  Self.msgHandler(cmd);
               except
                  on E: Exception do
                     begin
                     logger.Error('[TExternalLoggerBase.TReadingThread] Exception in message handler: %s - %s', [E.ClassName, E.Message]);
                     // Continue reading despite handler error
                     end;
               end;
            except
               on EIdNotConnected do
                  begin
                  logger.Warn('[TExternalLoggerBase.TReadingThread] Lost connection while reading');
                  wasConnected := False;
                  end;
               on EIdConnClosedGracefully do
                  begin
                  logger.Info('[TExternalLoggerBase.TReadingThread] Logger closed connection gracefully');
                  wasConnected := False;
                  end;
               on E: Exception do
                  begin
                  logger.Debug('[TExternalLoggerBase.TReadingThread] Exception during read: %s - %s', [E.ClassName, E.Message]);
                  wasConnected := False;
                  end;
            end;
            end
         else
            begin
            // Not connected - attempt reconnection with exponential backoff
            if wasConnected then
               begin
               logger.Warn('[TExternalLoggerBase.TReadingThread] Logger disconnected, entering reconnection mode');
               wasConnected := False;
               end;

            Inc(consecutiveFailures);
            logger.Info('[TExternalLoggerBase.TReadingThread] Reconnection attempt %d after %d ms delay',
                        [consecutiveFailures, reconnectDelay]);

            // Wait before retry (with termination check)
            if not Terminated then
               begin
               Sleep(reconnectDelay);
               end;

            // Attempt to reconnect
            if not Terminated then
               begin
               try
                  logger.Debug('[TExternalLoggerBase.TReadingThread] Attempting to reconnect');
                  (* Through the owner's guarded connect, so this and a
                    main-thread Connect can never run at once (issue #102). *)
                  FReconnect;

                  if FConn.Connected then
                     begin
                     logger.Info('[TExternalLoggerBase.TReadingThread] Reconnection successful');
                     end;
               except
                  on EIdConnectTimeout do
                     begin
                     logger.Debug('[TExternalLoggerBase.TReadingThread] Connection timeout during reconnect attempt');
                     // Increase delay with exponential backoff
                     reconnectDelay := reconnectDelay * RECONNECT_BACKOFF_MULTIPLIER;
                     if reconnectDelay > RECONNECT_MAX_DELAY then
                        begin
                        reconnectDelay := RECONNECT_MAX_DELAY;
                        end;
                     end;
                  on EIdSocketError do
                     begin
                     logger.Debug('[TExternalLoggerBase.TReadingThread] Socket error during reconnect attempt');
                     reconnectDelay := reconnectDelay * RECONNECT_BACKOFF_MULTIPLIER;
                     if reconnectDelay > RECONNECT_MAX_DELAY then
                        begin
                        reconnectDelay := RECONNECT_MAX_DELAY;
                        end;
                     end;
                  on E: Exception do
                     begin
                     logger.Debug('[TExternalLoggerBase.TReadingThread] Exception during reconnect: %s - %s',
                                  [E.ClassName, E.Message]);
                     reconnectDelay := reconnectDelay * RECONNECT_BACKOFF_MULTIPLIER;
                     if reconnectDelay > RECONNECT_MAX_DELAY then
                        begin
                        reconnectDelay := RECONNECT_MAX_DELAY;
                        end;
                     end;
               end;
               end;
            end;
      except
         on E: Exception do
            begin
            logger.Error('[TExternalLoggerBase.TReadingThread] Unexpected exception in main loop: %s - %s',
                         [E.ClassName, E.Message]);
            Sleep(1000);  // Brief pause before continuing
            end;
      end;
      end;

   logger.info('<<<<<<<<<<<< Leaving TExternalLoggerBase.TReadingThread.Execute >>>>>>>>>>>>>>>>>>');
end;

procedure TReadingThread.DoTerminate;
begin
  logger.debug('DEBUG: TExternalLoggerBase.TReadingThread.DoTerminate');
  inherited;
end;

// ============================================================================
// Issue #957 -- outbound operation queue + sender thread
// ============================================================================

procedure TExternalLoggerBase.InitOutboundQueue;
begin
   FShuttingDown := False;
   FOpQueue := TList.Create;
   FQueueLock := SyncObjs.TCriticalSection.Create;
   FQueueEvent := SyncObjs.TEvent.Create(nil, False, False, '');   // auto-reset, initially clear
   FSenderThread := TSenderThread.Create(Self);           // starts immediately
end;

procedure TExternalLoggerBase.QueueSingleCommand(const cmd, description: string);
var op: TExternalLogOp;
begin
   if FShuttingDown then
      begin
      logger.Warn('[ExternalLogger] Shutting down -- dropping queued command: %s', [description]);
      Exit;
      end;
   op := TExternalLogOp.Create;
   op.Kind := eloSingle;
   op.Cmd1 := cmd;
   op.Description := description;
   FQueueLock.Enter;
   try
      FOpQueue.Add(op);
   finally
      FQueueLock.Leave;
   end;
   FQueueEvent.SetEvent;
   logger.Debug('[ExternalLogger] Queued: %s', [description]);
end;

procedure TExternalLoggerBase.QueueReplace(const deleteCmd, relogCmd, description: string);
var op: TExternalLogOp;
begin
   if FShuttingDown then
      begin
      logger.Warn('[ExternalLogger] Shutting down -- dropping queued replace: %s', [description]);
      Exit;
      end;
   op := TExternalLogOp.Create;
   op.Kind := eloReplace;
   op.Cmd1 := deleteCmd;
   op.Cmd2 := relogCmd;
   op.Description := description;
   FQueueLock.Enter;
   try
      FOpQueue.Add(op);
   finally
      FQueueLock.Leave;
   end;
   FQueueEvent.SetEvent;
   logger.Debug('[ExternalLogger] Queued (replace): %s', [description]);
end;

function TExternalLoggerBase.DequeueOp: TExternalLogOp;
begin
   FQueueLock.Enter;
   try
      if FOpQueue.Count > 0 then
         begin
         Result := TExternalLogOp(FOpQueue[0]);
         FOpQueue.Delete(0);
         end
      else
         begin
         Result := nil;
         end;
   finally
      FQueueLock.Leave;
   end;
end;

function TExternalLoggerBase.SenderTerminating: boolean;
begin
   Result := (FSenderThread <> nil) and FSenderThread.Terminated;
end;

function TExternalLoggerBase.DeliverWithRetry(const cmd: string): boolean;
var
   attempt: integer;
   slept, target: integer;
begin
   Result := False;
   for attempt := 1 to SEND_MAX_ATTEMPTS do
      begin
      if SenderTerminating then
         begin
         Exit;
         end;
      if DeliverCommand(cmd) then
         begin
         Result := True;
         Exit;
         end;
      if attempt < SEND_MAX_ATTEMPTS then
         begin
         logger.Warn('[ExternalLogger] Send attempt %d/%d failed; retrying', [attempt, SEND_MAX_ATTEMPTS]);
         // Interruptible backoff so shutdown stays responsive.
         target := attempt * SEND_RETRY_BASE_DELAY;
         slept := 0;
         while (slept < target) and not SenderTerminating do
            begin
            Sleep(50);
            Inc(slept, 50);
            end;
         end;
      end;
end;

procedure TExternalLoggerBase.ProcessOp(op: TExternalLogOp);
begin
   case op.Kind of
      eloSingle:
         begin
         if not DeliverWithRetry(op.Cmd1) then
            begin
            logger.Error('[ExternalLogger] FAILED to deliver to external log after %d attempts: %s',
                         [SEND_MAX_ATTEMPTS, op.Description]);
            end;
         end;
      eloReplace:
         begin
         // Atomic: re-log only if the delete went through.  Delete must be first
         // (the QSO identity is unchanged by the edit, so relog-first would let
         // the delete remove both records).
         if not DeliverWithRetry(op.Cmd1) then
            begin
            logger.Error('[ExternalLogger] Replace ABORTED -- delete failed, re-log NOT sent (%s). '
                         + 'The external log may still hold the ORIGINAL QSO.', [op.Description]);
            end
         else if not DeliverWithRetry(op.Cmd2) then
            begin
            logger.Error('[ExternalLogger] Replace HALF-DONE -- delete succeeded but re-log FAILED (%s). '
                         + 'The QSO is now MISSING from the external log and must be re-entered there.', [op.Description]);
            end;
         end;
   end;
end;

function TExternalLoggerBase.DeliverCommand(const cmd: string): boolean;
begin
   // Default transport: persistent socket (for future ACLog/HRD).  DXKeeper
   // overrides this with a connect-per-command transport (Issue #957).
   Result := False;
   try
      if not IndyLinkIsOpen(socket) then
         begin
         Self.Connect;
         end;
      if IndyLinkIsOpen(socket) then
         begin
         socket.IOHandler.WriteLn(cmd);
         Result := True;
         end
      else
         begin
         logger.Error('[DeliverCommand] not connected; cannot send (%s)', [cmd]);
         end;
   except
      on E: Exception do
         begin
         logger.Error('[DeliverCommand] %s - %s', [E.ClassName, E.Message]);
         end;
   end;
end;

procedure TExternalLoggerBase.ShutdownDrain(timeoutMs: integer);
var
   deadline: QWord;
   pending: integer;
begin
   if FShuttingDown then
      begin
      Exit;   // idempotent
      end;
   FShuttingDown := True;

   FQueueLock.Enter;
   try
      pending := FOpQueue.Count;
   finally
      FQueueLock.Leave;
   end;
   if pending > 0 then
      begin
      logger.Info('[ExternalLogger] Shutdown: draining %d queued external-log operation(s) (up to %d ms)',
                  [pending, timeoutMs]);
      end;

   // Let the sender finish what is queued, bounded.
   if FQueueEvent <> nil then
      begin
      FQueueEvent.SetEvent;
      end;
   (* GetTickCount64 INTO A QWord, AND THIS FIXES A DEFECT rather than just
     moving off Windows.

     The old line was `deadline := GetTickCount + Cardinal(timeoutMs)` with
     `deadline: Cardinal`, compared with `<`. Within timeoutMs of the 49.7-day
     wrap, the addition wraps to a small number, `GetTickCount < deadline` is
     false immediately, and the drain returns WITHOUT WAITING -- silently, on
     a queue it was supposed to flush. A 64-bit deadline cannot wrap in any
     uptime this program will see. *)
   deadline := GetTickCount64 + QWord(timeoutMs);
   while GetTickCount64 < deadline do
      begin
      FQueueLock.Enter;
      try
         pending := FOpQueue.Count;
      finally
         FQueueLock.Leave;
      end;
      if pending = 0 then
         begin
         Break;
         end;
      Sleep(50);
      end;

   // Stop the sender thread (its current op bails promptly via SenderTerminating).
   if FSenderThread <> nil then
      begin
      FSenderThread.Terminate;
      if FQueueEvent <> nil then
         begin
         FQueueEvent.SetEvent;
         end;
      FSenderThread.WaitFor;
      FreeAndNil(FSenderThread);
      end;

   FQueueLock.Enter;
   try
      pending := FOpQueue.Count;
   finally
      FQueueLock.Leave;
   end;
   if pending > 0 then
      begin
      logger.Error('[ExternalLogger] Shutdown: %d external-log operation(s) were NOT delivered '
                   + '(in-memory queue; persistent replay is a Delphi 12 item).', [pending]);
      end;
end;

constructor TSenderThread.Create(AOwner: TExternalLoggerBase);
begin
   FOwner := AOwner;
   inherited Create(False);   // start running
end;

procedure TSenderThread.Execute;
var op: TExternalLogOp;
begin
   while not Terminated do
      begin
      // Wake on enqueue, or every 250 ms to re-check Terminated.
      FOwner.FQueueEvent.WaitFor(250);
      while not Terminated do
         begin
         op := FOwner.DequeueOp;
         if op = nil then
            begin
            Break;
            end;
         try
            try
               FOwner.ProcessOp(op);
            except
               on E: Exception do
                  begin
                  logger.Error('[ExternalLogger.Sender] Exception processing %s: %s - %s',
                               [op.Description, E.ClassName, E.Message]);
                  end;
            end;
         finally
            op.Free;
         end;
         end;
      end;
end;

function BoolToString(b: boolean): string;
begin
   Result := IfThen(b,'True','False');
end;

end.


 