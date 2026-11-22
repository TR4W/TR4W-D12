unit uN1MMLogListener;
{$I tr4w.inc}

(* The N1MM "Log" listener (issue 45): a QSO from JTDX (TCP 52001) or JTAlert /
  WSJT-X (UDP 2333), sent as N1MM's byte-counted envelope, becomes a QSO in this
  log.  The framing is uN1MMLogEnvelope; the ADIF-to-QSO step is uInboundQso,
  the one path WSJT-X's own logged-ADIF message takes.  This unit owns the two
  sockets and the hand-off between them.

  NY4I's rulings (issue 45, 2026-11-22):
  - OFF unless the operator turns it on (ENABLE N1MM LOG LISTENER), and bound to
    N1MM LISTEN ADDRESS, 127.0.0.1 by default.  A LAN address is an explicit
    change; nothing here says anything about firewalls (the documentation does).
  - Both transports.  Ports are N1MM's: TCP 52001, UDP 2333.
  - Receive-only: nothing is ever written back to the sender.
  - A resend is a dupe, flagged by the normal dupe sheet and logged; it is not
    refused here (a refusal over UDP would only hide the problem).
  - Both settings apply LIVE (uSettingsEffects -> N1MMLogListenerApply).  A save
    that leaves them as they were touches nothing, so a Preferences save does
    not drop a connected sender.

  THREADS.  Indy calls the handlers below on its own threads.  They parse and
  copy and nothing else: the ADIF text is put on a locked list and ONE
  Application.QueueAsyncCall per record asks the main thread to log it
  (uInboundQso reads and writes the dupe sheet, the contest and the log store,
  none of which tolerate a second thread).  FIFO, so records are logged in the
  order they arrived.

  A LOGGED QSO IS NEVER DROPPED.  Stop (main thread, sockets already down)
  logs every record still on the list before it returns, as uWSJTX does.  The
  last resort -- Stop off the main thread, or a record that will not log -- is a
  LOST QSO error carrying the ADIF text.

  UNIT-TESTED WITHOUT A SOCKET: HandleDatagram and HandleStreamBytes are the
  whole of what a socket handler does, and RecordHook replaces the hand-off. *)

interface

uses
   SysUtils, Classes,
   IdUDPServer, IdTCPServer, IdContext, IdSocketHandle, IdGlobal, IdIOHandler,
   uN1MMLogEnvelope;

const
   N1MM_LISTEN_UDP_PORT = 2333;
   N1MM_LISTEN_TCP_PORT = 52001;
   N1MM_LISTEN_DEFAULT_ADDRESS = '127.0.0.1';
   N1MM_LISTEN_MAX_CONNECTIONS = 8;

type
   (* Called, on whatever thread read the bytes, with ONE record's ADIF text.
     The program's hook queues it for the main thread; a test collects it. *)
   TN1MMRecordHook = procedure(const aAdif: string) of object;

   TN1MMLogListener = class(TObject)
   private
      FUdp: TIdUDPServer;
      FTcp: TIdTCPServer;
      FRunning: boolean;
      FBoundAddress: string;
      FLock: TRTLCriticalSection;
      FPending: TStringList;
      FRecordHook: TN1MMRecordHook;
      FReceived: integer;
      FRejected: integer;
      procedure OnUdpRead(AThread: TIdUDPListenerThread; const AData: TIdBytes;
                          ABinding: TIdSocketHandle);
      procedure OnTcpConnect(AContext: TIdContext);
      procedure OnTcpDisconnect(AContext: TIdContext);
      procedure OnTcpExecute(AContext: TIdContext);
      procedure PostRecord(const aAdif: string);
      procedure RunOne(Data: PtrInt);
      procedure Evaluate(const aAdif: string);
      procedure DrainPending;
      function  PendingCount: integer;
   public
      constructor Create;
      (* override: without it Free never reaches this destructor. *)
      destructor Destroy; override;
      (* Binds UDP and TCP to aAddress.  A bind that fails is reported (log and
        the status line, never a dialog) and the other transport still runs. *)
      procedure Start(const aAddress: string);
      (* Main thread: stops listening, then logs what is still queued. *)
      procedure Stop;
      (* What a UDP handler does with one datagram: one envelope, one record. *)
      procedure HandleDatagram(const aBytes: RawByteString;
                               const aFrom: string);
      (* What a TCP handler does with the bytes one read returned.  False when
        the framer's buffer limit was passed (the caller drops the
        connection). *)
      function  HandleStreamBytes(aFramer: TN1MMLogFramer;
                                  const aBytes: RawByteString;
                                  const aFrom: string): boolean;
      property Running: boolean read FRunning;
      property BoundAddress: string read FBoundAddress;
      (* Records handed on, and refused, since the object was made. *)
      property Received: integer read FReceived;
      property Rejected: integer read FRejected;
      property RecordHook: TN1MMRecordHook read FRecordHook write FRecordHook;
   end;

(* The address the settings ask for: trimmed, the default when blank. *)
function N1MMListenAddressFromSetting(const aSetting: string): string;

(* TIdBytes to the byte string the framing reads.  Bytes, not characters: the
  envelope's lengths are byte counts. *)
function N1MMBytesToRaw(const aBytes: TIdBytes): RawByteString;

(* The program's one listener.  Startup is called once, after the main window
  exists (uProgramMain); Apply is the settings effect and does nothing before
  that; Shutdown is tr4w_ShutDown's, before the log closes. *)
procedure N1MMLogListenerStartup;
procedure N1MMLogListenerApply;
procedure N1MMLogListenerShutdown;

implementation

uses
   Forms,              // Application.QueueAsyncCall
   uSettingsModel,     // Settings
   VC,                 // ContestExchange
   uCrashLog,          // OnMainThread
   MainUnit,           // logger
   LOGWIND,            // QuickDisplay
   uInboundQso;

var
   GListener: TN1MMLogListener = nil;

function N1MMListenAddressFromSetting(const aSetting: string): string;
begin
   Result := Trim(aSetting);
   if Result = '' then
      begin
      Result := N1MM_LISTEN_DEFAULT_ADDRESS;
      end;
end;

function N1MMBytesToRaw(const aBytes: TIdBytes): RawByteString;
var
   i: integer;
begin
   Result := '';
   if Length(aBytes) > 0 then
      begin
      (* A genuine byte boundary: the socket hands bytes, the envelope parser
        reads bytes. A loop, not Move: Count-LiveMove gates new Move calls. *)
      SetLength(Result, Length(aBytes));
      for i := 0 to High(aBytes) do
         begin
         Result[i + 1] := AnsiChar(aBytes[i]);
         end;
      end;
end;

constructor TN1MMLogListener.Create;
begin
   inherited Create;
   InitCriticalSection(FLock);
   FPending := TStringList.Create;
   FRecordHook := Self.PostRecord;

   FUdp := TIdUDPServer.Create(nil);
   FUdp.OnUDPRead := Self.OnUdpRead;

   FTcp := TIdTCPServer.Create(nil);
   FTcp.MaxConnections := N1MM_LISTEN_MAX_CONNECTIONS;
   FTcp.OnConnect := Self.OnTcpConnect;
   FTcp.OnDisconnect := Self.OnTcpDisconnect;
   FTcp.OnExecute := Self.OnTcpExecute;
end;

destructor TN1MMLogListener.Destroy;
begin
   Stop;
   FreeAndNil(FUdp);
   FreeAndNil(FTcp);
   (* No queued call may reach a freed object. *)
   if Application <> nil then
      begin
      Application.RemoveAsyncCalls(Self);
      end;
   FreeAndNil(FPending);
   DoneCriticalSection(FLock);
   inherited Destroy;
end;

procedure TN1MMLogListener.Start(const aAddress: string);
var
   binding: TIdSocketHandle;
   bound: integer;
begin
   if FRunning then
      begin
      Exit;
      end;

   bound := 0;
   FBoundAddress := aAddress;

   (* ReuseSocket is left at its default on purpose: an N1MM already holding
     2333 or 52001 on this machine is reported as a bind error, not silently
     shared. *)
   try
      FUdp.Bindings.Clear;
      binding := FUdp.Bindings.Add;
      binding.IP := AnsiString(aAddress);
      binding.Port := N1MM_LISTEN_UDP_PORT;
      FUdp.Active := True;
      Inc(bound);
      logger.Info('[N1MM listener] UDP listening on %s:%d',
                  [aAddress, N1MM_LISTEN_UDP_PORT]);
   except
      on E: Exception do
         begin
         logger.Error('[N1MM listener] could not bind UDP %s:%d: %s',
                      [aAddress, N1MM_LISTEN_UDP_PORT, E.Message]);
         QuickDisplay('N1MM log listener: UDP ' + aAddress + ':' +
                      IntToStr(N1MM_LISTEN_UDP_PORT) + ' - ' + E.Message);
         end;
   end;

   try
      FTcp.Bindings.Clear;
      binding := FTcp.Bindings.Add;
      binding.IP := AnsiString(aAddress);
      binding.Port := N1MM_LISTEN_TCP_PORT;
      FTcp.Active := True;
      Inc(bound);
      logger.Info('[N1MM listener] TCP listening on %s:%d',
                  [aAddress, N1MM_LISTEN_TCP_PORT]);
   except
      on E: Exception do
         begin
         logger.Error('[N1MM listener] could not bind TCP %s:%d: %s',
                      [aAddress, N1MM_LISTEN_TCP_PORT, E.Message]);
         QuickDisplay('N1MM log listener: TCP ' + aAddress + ':' +
                      IntToStr(N1MM_LISTEN_TCP_PORT) + ' - ' + E.Message);
         end;
   end;

   FRunning := bound > 0;
end;

procedure TN1MMLogListener.Stop;
begin
   (* Sockets first, so nothing can be added behind the drain. *)
   try
      if FUdp.Active then
         begin
         FUdp.Active := False;
         end;
      if FTcp.Active then
         begin
         if FTcp.IOHandler <> nil then
            begin
            FTcp.IOHandler.Shutdown;
            end;
         FTcp.Active := False;
         end;
   except
      on E: Exception do
         begin
         logger.Warn('[N1MM listener] closing the sockets: %s', [E.Message]);
         end;
   end;

   if FRunning then
      begin
      logger.Info('[N1MM listener] stopped');
      end;
   FRunning := False;
   DrainPending;
end;

procedure TN1MMLogListener.HandleDatagram(const aBytes: RawByteString;
                                          const aFrom: string);
var
   adif: string;
   why: string;
begin
   if N1MMParseDatagram(aBytes, adif, why) then
      begin
      Inc(FReceived);
      FRecordHook(adif);
      end
   else
      begin
      Inc(FRejected);
      logger.Warn('[N1MM listener] UDP datagram from %s refused: %s',
                  [aFrom, why]);
      end;
end;

function TN1MMLogListener.HandleStreamBytes(aFramer: TN1MMLogFramer;
                                            const aBytes: RawByteString;
                                            const aFrom: string): boolean;
var
   adif: string;
   why: string;
   status: TN1MMEnvelopeStatus;
begin
   Result := aFramer.Feed(aBytes);
   if not Result then
      begin
      Inc(FRejected);
      logger.Warn('[N1MM listener] TCP stream from %s passed the buffer limit; ' +
                  'dropping the connection', [aFrom]);
      Exit;
      end;

   repeat
      status := aFramer.Next(adif, why);
      case status of
         esLog:
            begin
            Inc(FReceived);
            FRecordHook(adif);
            end;
         esIgnored:
            begin
            logger.Debug('[N1MM listener] TCP from %s: %s', [aFrom, why]);
            end;
         esMalformed:
            begin
            Inc(FRejected);
            logger.Warn('[N1MM listener] TCP stream from %s refused: %s',
                        [aFrom, why]);
            end;
      end;
   until status = esNeedMore;
end;

procedure TN1MMLogListener.OnUdpRead(AThread: TIdUDPListenerThread;
                                     const AData: TIdBytes;
                                     ABinding: TIdSocketHandle);
begin
   (* Indy's UDP listener thread: copy and hand off, nothing else. *)
   HandleDatagram(N1MMBytesToRaw(AData), ABinding.PeerIP);
end;

procedure TN1MMLogListener.OnTcpConnect(AContext: TIdContext);
begin
   AContext.Data := TN1MMLogFramer.Create;
   logger.Debug('[N1MM listener] TCP connection from %s',
                [AContext.Binding.PeerIP]);
end;

procedure TN1MMLogListener.OnTcpDisconnect(AContext: TIdContext);
begin
   AContext.Data.Free;
   AContext.Data := nil;
end;

procedure TN1MMLogListener.OnTcpExecute(AContext: TIdContext);
var
   bytes: TIdBytes;
   handler: TIdIOHandler;
begin
   (* Called again by Indy for as long as the connection lasts.  NEVER
     Synchronize from here: Stop deactivates the server from the main thread and
     would wait for this thread. *)
   handler := AContext.Connection.IOHandler;
   if not handler.CheckForDataOnSource(200) then
      begin
      handler.CheckForDisconnect(True, True);
      Exit;
      end;
   if handler.InputBufferIsEmpty then
      begin
      Exit;
      end;

   SetLength(bytes, 0);
   handler.InputBuffer.ExtractToBytes(bytes);
   if not HandleStreamBytes(TN1MMLogFramer(AContext.Data), N1MMBytesToRaw(bytes),
                            AContext.Binding.PeerIP) then
      begin
      AContext.Connection.Disconnect;
      end;
end;

procedure TN1MMLogListener.PostRecord(const aAdif: string);
begin
   EnterCriticalSection(FLock);
   try
      FPending.Add(AnsiString(aAdif));
   finally
      LeaveCriticalSection(FLock);
   end;

   (* QueueAsyncCall RAISES on a shut-down queue rather than returning False. *)
   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;
   try
      Application.QueueAsyncCall(Self.RunOne, 0);
   except
      on E: Exception do
         begin
         (* Left on the list: Stop logs it. *)
         logger.Error('[N1MM listener] could not queue a record for the main ' +
                      'thread: %s', [E.Message]);
         end;
   end;
end;

function TN1MMLogListener.PendingCount: integer;
begin
   EnterCriticalSection(FLock);
   try
      Result := FPending.Count;
   finally
      LeaveCriticalSection(FLock);
   end;
end;

(* One queued call pops one record, so the queue's FIFO order is the order the
  records arrived in.  Main thread. *)
procedure TN1MMLogListener.RunOne(Data: PtrInt);
var
   adif: string;
begin
   adif := '';
   EnterCriticalSection(FLock);
   try
      if FPending.Count > 0 then
         begin
         adif := FPending[0];
         FPending.Delete(0);
         end;
   finally
      LeaveCriticalSection(FLock);
   end;

   if adif <> '' then
      begin
      Evaluate(adif);
      end;
end;

(* Log one record.  Main thread only. *)
procedure TN1MMLogListener.Evaluate(const aAdif: string);
var
   rec: ContestExchange;
   outcome: TInboundQsoResult;
begin
   if not OnMainThread then
      begin
      logger.Error('[N1MM listener] LOST QSO: a record reached Evaluate off the ' +
                   'main thread and was NOT logged: ' + aAdif);
      Exit;
      end;

   try
      if not ParseInboundADIF(aAdif, rec) then
         begin
         logger.Warn('[N1MM listener] the ADIF held no record: ' + aAdif);
         Exit;
         end;
      outcome := LogParsedInboundQso(rec, 'N1MM listener');
      if outcome = iqLogged then
         begin
         logger.Info('[N1MM listener] QSO logged');
         end
      else
         begin
         logger.Warn('[N1MM listener] record not logged (%d): %s',
                     [Ord(outcome), aAdif]);
         end;
   except
      on E: Exception do
         begin
         logger.Error('[N1MM listener] LOST QSO: logging a record failed (' +
                      E.Message + '): ' + aAdif);
         end;
   end;
end;

(* Stop's drain: log what is still queued, oldest first.  Off the main thread
  nothing can be logged, so each record is reported with its text instead. *)
procedure TN1MMLogListener.DrainPending;
var
   taken: TStringList;
   i: integer;
begin
   taken := TStringList.Create;
   try
      EnterCriticalSection(FLock);
      try
         taken.AddStrings(FPending);
         FPending.Clear;
      finally
         LeaveCriticalSection(FLock);
      end;

      for i := 0 to taken.Count - 1 do
         begin
         Evaluate(taken[i]);
         end;
   finally
      taken.Free;
   end;
end;

procedure N1MMLogListenerStartup;
begin
   if GListener = nil then
      begin
      GListener := TN1MMLogListener.Create;
      end;
   N1MMLogListenerApply;
end;

procedure N1MMLogListenerApply;
var
   address: string;
begin
   (* Settings are applied while they load, before the program is ready: with
     no listener yet there is nothing to start. *)
   if GListener = nil then
      begin
      Exit;
      end;

   address := N1MMListenAddressFromSetting(Settings.Wsjtx.N1mmListenAddress);
   if Settings.Wsjtx.N1mmListenerEnabled then
      begin
      if GListener.Running and (address = GListener.BoundAddress) then
         begin
         Exit;
         end;
      GListener.Stop;
      GListener.Start(address);
      end
   else
      begin
      if GListener.Running then
         begin
         GListener.Stop;
         end;
      end;
end;

procedure N1MMLogListenerShutdown;
begin
   FreeAndNil(GListener);
end;

end.
