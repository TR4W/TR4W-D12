unit uNetClient;

{
  THE MULTI-OP LINK TO TR4WSERVER, OVER INDY.

  One class, one job: hold a TCP connection to TR4WServer and hand the bytes
  that arrive to whoever asked.  It knows the HANDSHAKE, because that is part of
  establishing the link, and nothing else about the protocol -- the packet
  framing and every message arm stay in uNet.

  WHAT THIS REPLACES.  uNet drove a raw Winsock socket and asked Windows to tell
  it about socket events by POSTING A WINDOW MESSAGE:

      WSAAsyncSelect(NetSocket, tr4w_WindowsArray[tw_NETWINDOW_INDEX].WndHandle,
                     WM_SOCK_NET, FD_READ or FD_CLOSE);

  So the network window was not merely a VIEW of the connection -- it WAS the
  socket's event delivery mechanism, and the dialog procedure called recv().
  That is why the window could not become a form while the transport stood.

  WHY INDY RATHER THAN A DIFFERENT WINDOW.  The decision was already taken and
  applied four times in this tree -- network radios, the DX cluster, the
  external loggers and everything HTTP.  The DX cluster is the exact precedent:
  it used to be a raw `TelnetSock` and is now TDXClusterClient, and this class
  is deliberately the same shape so there is one pattern to learn.

  THREADING.  OnData and OnDisconnected fire on the READER THREAD.  Marshal
  before touching anything the UI or the log owns; uNet does.

  BYTES, NOT LINES.  The DX cluster speaks text and reads with ReadLn.  This
  protocol is binary records with CRC32, so the reader hands over whatever has
  arrived and lets uNet's framing decide where messages end.  It deliberately
  does NOT try to deliver whole messages: that is uNetFraming's job and it
  already handles a short tail.
}

{$I tr4w.inc}

interface

uses
   Classes, SysUtils, IdTCPClient, IdGlobal, IdException, IdExceptionCore,
   IdStack,
   IdStackConsts;   { Id_IPPROTO_TCP, Id_TCP_NODELAY }

type
   { Raw bytes as they arrived.  Fires on the READER THREAD. }
   { A PLAIN procedure type, not `of object`: uNet handles these with
     unit-level routines and has no object to hang them on. }
   TNetDataEvent = procedure(const aData: TIdBytes);

   { Text for the log; fires on the reader thread when the link drops. }
   TNetErrorEvent = procedure(const aText: string);

   TNetClient = class;

   { Blocking reads live here so no caller's thread ever blocks.  The thread
     owns NOTHING: it reads and raises events, and the client owns the socket. }
   TNetReader = class(TThread)
   private
      FOwner: TNetClient;
   protected
      procedure Execute; override;
   public
      constructor Create(AOwner: TNetClient);
   end;

   TNetClient = class
   private
      FTCP:      TIdTCPClient;
      FReader:   TNetReader;
      FStopping: boolean;
      FOnData:         TNetDataEvent;
      FOnDisconnected: TNetErrorEvent;
      function GetIsConnected: boolean;
   public
      constructor Create;
      destructor Destroy; override;

      { Blocking connect INCLUDING the password handshake, because a socket
        that has not been acknowledged is not a usable link.

        Returns False and reports the reason through aError rather than raising:
        every caller wants the message, and an exception crossing back out of
        here would land on the connect thread.

        aWrongPassword distinguishes the server's 'PASS' rejection from every
        other failure, which the caller shows differently. }
      function Connect(const aHost: string; const aPort: word;
                       const aPassword: AnsiString;
                       out aError: string;
                       out aWrongPassword: boolean): boolean;

      { Safe when not connected, and safe from the UI thread while the reader is
        blocked in a read -- disconnecting the IOHandler is what unblocks it. }
      procedure Disconnect;

      { Byte-exact.  Returns the count written, or 0 when there is no link. }
      function Send(var aBuf; const aLen: integer): integer;

      property IsConnected: boolean read GetIsConnected;

      { BOTH FIRE ON THE READER THREAD. }
      property OnData: TNetDataEvent read FOnData write FOnData;
      property OnDisconnected: TNetErrorEvent read FOnDisconnected write FOnDisconnected;
   end;

implementation

uses
   MainUnit;   // logger

const
   { How long a read waits before looking at Terminated again.  The same reason
     TDXClusterClient has one: without a timeout an idle link would never notice
     it had been asked to stop. }
   READ_POLL_MS = 250;

   { The server's answers to the password, as they arrive on the wire.  These
     were bare magic numbers compared against an integer in uNet
     ($53534150 and $57345254); spelled here so the next reader does not have to
     decode ASCII by hand. }
   ACK_OK   = $57345254;   // 'TR4W'
   ACK_PASS = $53534150;   // 'PASS' -- the password was refused

   HANDSHAKE_TIMEOUT_MS = 5000;

{ ------------------------------------------------------------ TNetReader -- }

constructor TNetReader.Create(AOwner: TNetClient);
begin
   FOwner := AOwner;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TNetReader.Execute;
var
   data: TIdBytes;
   available: integer;
   closeText: string;
begin
   closeText := 'Network connection closed';
   try
      while not Terminated do
         begin
         try
            // Wait for something to arrive, then take ALL of it.  The framing
            // in uNet copes with a short tail, so there is no reason to try to
            // deliver whole messages from here.
            FOwner.FTCP.IOHandler.CheckForDataOnSource(READ_POLL_MS);
            FOwner.FTCP.IOHandler.CheckForDisconnect(True, True);

            available := FOwner.FTCP.IOHandler.InputBuffer.Size;
            if available <= 0 then
               begin
               Continue;
               end;

            SetLength(data, 0);
            FOwner.FTCP.IOHandler.ReadBytes(data, available, False);

            if Assigned(FOwner.FOnData) and (Length(data) > 0) then
               begin
               FOwner.FOnData(data);
               end;
         except
            // A Disconnect from another thread closes the IOHandler under us.
            // That is an orderly stop, not a failure worth reporting.
            on E: Exception do
               begin
               if not FOwner.FStopping then
                  begin
                  closeText := E.Message;
                  end;
               Break;
               end;
            end;
         end;
   finally
      if (not FOwner.FStopping) and Assigned(FOwner.FOnDisconnected) then
         begin
         FOwner.FOnDisconnected(closeText);
         end;
   end;
end;

{ ------------------------------------------------------------ TNetClient -- }

constructor TNetClient.Create;
begin
   inherited Create;
   FTCP := TIdTCPClient.Create(nil);
end;

destructor TNetClient.Destroy;
begin
   Disconnect;
   FreeAndNil(FTCP);
   inherited Destroy;
end;

function TNetClient.GetIsConnected: boolean;
begin
   Result := (FTCP <> nil) and FTCP.Connected;
end;

function TNetClient.Connect(const aHost: string; const aPort: word;
                            const aPassword: AnsiString;
                            out aError: string;
                            out aWrongPassword: boolean): boolean;
var
   ack: longword;
   pass: TIdBytes;
begin
   Result := False;
   aError := '';
   aWrongPassword := False;

   Disconnect;
   FStopping := False;

   try
      FTCP.Host := aHost;
      FTCP.Port := aPort;
      FTCP.ConnectTimeout := HANDSHAKE_TIMEOUT_MS;
      FTCP.ReadTimeout := HANDSHAKE_TIMEOUT_MS;
      FTCP.Connect;
   except
      on E: Exception do
         begin
         aError := E.Message;
         Exit;
         end;
      end;

   try
      // NAGLE OFF, as the Winsock path did with TCP_NODELAY.  This protocol
      // sends small records and waits for them; coalescing adds latency to
      // every one.
      FTCP.Socket.Binding.SetSockOpt(Id_IPPROTO_TCP, Id_TCP_NODELAY, 1);

      // THE PASSWORD IS TEN BYTES, unconditionally.  uNet sent
      // SendToNet(ServerPassword[1], 10) -- ten bytes from a ShortString's
      // first character, whatever its declared length -- and the server reads
      // exactly ten.  Reproduced byte for byte rather than "improved" to
      // Length(): the far end is a shipped program.
      SetLength(pass, 10);
      FillChar(pass[0], 10, 0);
      if Length(aPassword) > 0 then
         begin
         if Length(aPassword) < 10 then
            begin
            Move(aPassword[1], pass[0], Length(aPassword));
            end
         else
            begin
            Move(aPassword[1], pass[0], 10);
            end;
         end;
      FTCP.IOHandler.Write(pass);

      // The Sleep(200) that used to sit here is gone: it was waiting for an
      // answer that a blocking read waits for properly.
      ack := 0;
      FTCP.IOHandler.ReadBytes(pass, SizeOf(ack), False);
      if Length(pass) >= SizeOf(ack) then
         begin
         Move(pass[0], ack, SizeOf(ack));
         end;

      if ack = ACK_PASS then
         begin
         aWrongPassword := True;
         aError := 'the server refused the password';
         Disconnect;
         Exit;
         end;

      if ack <> ACK_OK then
         begin
         aError := SysUtils.Format('unexpected server greeting ($%.8x)', [ack]);
         Disconnect;
         Exit;
         end;
   except
      on E: Exception do
         begin
         aError := E.Message;
         Disconnect;
         Exit;
         end;
      end;

   // The handshake is done, so reads from here on are the protocol's.  No
   // timeout: the reader polls with CheckForDataOnSource instead.
   FTCP.ReadTimeout := IdTimeoutInfinite;

   FReader := TNetReader.Create(Self);
   Result := True;
end;

procedure TNetClient.Disconnect;
begin
   FStopping := True;
   try
      if (FTCP <> nil) and FTCP.Connected then
         begin
         FTCP.Disconnect;
         end;
      // Closing the IOHandler is what unblocks a reader sitting in a read.
      if (FTCP <> nil) and (FTCP.IOHandler <> nil) then
         begin
         FTCP.IOHandler.CloseGracefully;
         end;
   except
      on E: Exception do
         begin
         logger.Debug('[NetClient] Disconnect: %s', [E.Message]);
         end;
      end;

   if FReader <> nil then
      begin
      FReader.Terminate;
      FReader.WaitFor;
      FreeAndNil(FReader);
      end;
end;

function TNetClient.Send(var aBuf; const aLen: integer): integer;
var
   bytes: TIdBytes;
begin
   Result := 0;
   if (aLen <= 0) or (not IsConnected) then
      begin
      Exit;
      end;

   try
      SetLength(bytes, aLen);
      Move(aBuf, bytes[0], aLen);
      FTCP.IOHandler.Write(bytes);
      Result := aLen;
   except
      on E: Exception do
         begin
         logger.Warn('[NetClient] send failed: %s', [E.Message]);
         Result := 0;
         end;
      end;
end;

end.
