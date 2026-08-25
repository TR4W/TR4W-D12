unit uK4SpectrumThread;
{$I ..\tr4w.inc}

{
  The reading thread for the Elecraft K4's panadapter socket.

  SEPARATE FROM THE CAT LINK ON PURPOSE.  The K4 serves its spectrum on a
  second TCP port (CAT port + 1) and this thread owns that socket alone.  The
  radio's CAT connection, its TReadingThread and its polling are untouched.

  WHY NOT REUSE TReadingThread.  It advertises exactly the right feature --
  `fixedFrameLength` plus a `frameValidator` that drops one byte and re-aligns
  (uFactoryRadioBase.pas:226-227) -- but reading the implementation rather than
  the declaration shows it is SERIAL-ONLY: the whole fixed-frame block lives
  inside the `if FSerialPort <> nil` branch and works on FSerialBuffer, and the
  network branch is a single `FConn.IOHandler.ReadLn(readTerminator)`.  ReadLn
  on binary spectrum data would split frames on whatever byte matched the
  terminator and mangle the rest.

  Extending that class was the alternative, and it was rejected: every one of
  the 100 radios depends on it for its CAT link, and a regression there to
  serve one radio's side-channel is a bad trade.  The two jobs also want
  different things -- CAT is low-rate terminated text handed over as a
  `string`, while this is ~150 KB/s of binary frames where a per-frame string
  copy is the wrong container.

  NO KEEPALIVE.  Measured, not assumed: 75 seconds of complete silence on this
  port with zero stalls (docs/PANADAPTER_LCL_DESIGN.md section 1).  That is the
  opposite of the CAT port, which drops silent clients after 10 s and is why
  TK4Radio.Connect polls PING; every second.  TR4QT sends a 4-byte "PING" here
  and it is unnecessary, so nothing in this thread ever writes to the socket.

  THREADING.  Frames are handed out ON THIS THREAD via the callback supplied at
  construction; see TSpectrumFrameProc.  Subscribers marshal -- with
  Synchronize, never TThread.Queue, which purges its own callback under FPC.
  The callback is TK4Radio's own method, so unsubscribing takes effect on the
  very next frame rather than being latched here at construction.
}

interface

uses
   Classes, SysUtils, IdTCPClient, IdGlobal, Log4D,
   uSpectrumTypes, uK4Spectrum;

const
   // The stream is served on the CAT port plus one.  9200 -> 9201 by default.
   K4_SPECTRUM_PORT_OFFSET = 1;

type
   TK4SpectrumThread = class(TThread)
   private
      FHost: string;
      FPort: Integer;
      FRadioName: string;
      FLogger: TLogLogger;
      FOnFrame: TSpectrumFrameProc;

      FClient: TIdTCPClient;
      FFramer: TK4SpectrumFramer;
      FChunk: TBytes;              // reused read buffer; never reallocated per read
      FLinkUp: Boolean;
      FReconnectDelay: Integer;

      procedure OpenLink;
      procedure CloseLink;
      procedure ReadAvailable;
      procedure DrainFrames;
      procedure WaitInterruptibly(AMilliseconds: Integer);
      procedure GrowBackoff;
   protected
      procedure Execute; override;
   public
      constructor Create(const AHost: string; APort: Integer;
                         AOnFrame: TSpectrumFrameProc;
                         ALogger: TLogLogger; const ARadioName: string);
      destructor Destroy; override;

      property LinkUp: Boolean read FLinkUp;
   end;

implementation

const
   CONNECT_TIMEOUT_MS = 5000;

   // How long a read blocks before the loop looks at Terminated again.  Short
   // enough that shutdown is prompt, long enough that an idle link is not a
   // busy loop.  At ~36 frames a second there is normally data every 28 ms, so
   // this timeout is only reached when the radio has gone quiet.
   READ_POLL_MS = 200;

   // Matches the reconnection profile the rest of the factory uses.
   RECONNECT_INITIAL_MS = 1000;
   RECONNECT_MAX_MS = 30000;
   RECONNECT_MULTIPLIER = 2;

   WAIT_SLICE_MS = 100;

constructor TK4SpectrumThread.Create(const AHost: string; APort: Integer;
                                     AOnFrame: TSpectrumFrameProc;
                                     ALogger: TLogLogger; const ARadioName: string);
begin
   FHost := AHost;
   FPort := APort;
   FOnFrame := AOnFrame;
   FLogger := ALogger;
   FRadioName := ARadioName;

   FFramer := TK4SpectrumFramer.Create;
   FClient := TIdTCPClient.Create(nil);
   SetLength(FChunk, 65536);
   FLinkUp := False;
   FReconnectDelay := RECONNECT_INITIAL_MS;

   // Suspended := False.  Nothing else has to be set up after construction, and
   // a thread left suspended that someone forgets to start is a silent failure.
   inherited Create(False);
end;

destructor TK4SpectrumThread.Destroy;
begin
   Terminate;

   // Break a read that is parked in CheckForDataOnSource so WaitFor does not
   // have to sit out the full poll interval.  Disconnecting a socket the thread
   // may still be reading is deliberate: it is what makes the read return.
   try
      if FClient.Connected then
         begin
         FClient.Disconnect(False);
         end;
   except
      // Shutting down; a failure to disconnect is not worth propagating.
   end;

   inherited Destroy;   // Terminate + WaitFor: Execute has finished below here

   FreeAndNil(FFramer);
   FreeAndNil(FClient);
end;

procedure TK4SpectrumThread.WaitInterruptibly(AMilliseconds: Integer);
var
   waited: Integer;
begin
   waited := 0;

   // Sliced, so a 30-second backoff does not make shutdown take 30 seconds.
   while (waited < AMilliseconds) and (not Terminated) do
      begin
      Sleep(WAIT_SLICE_MS);
      Inc(waited, WAIT_SLICE_MS);
      end;
end;

procedure TK4SpectrumThread.GrowBackoff;
begin
   FReconnectDelay := FReconnectDelay * RECONNECT_MULTIPLIER;

   if FReconnectDelay > RECONNECT_MAX_MS then
      begin
      FReconnectDelay := RECONNECT_MAX_MS;
      end;
end;

procedure TK4SpectrumThread.OpenLink;
begin
   FClient.Host := FHost;
   FClient.Port := FPort;
   FClient.ConnectTimeout := CONNECT_TIMEOUT_MS;
   FClient.Connect;

   // A new link means a new stream: anything half-framed from the old one is
   // meaningless, and keeping it would only cost a resync.
   FFramer.Reset;

   FLinkUp := True;
   FReconnectDelay := RECONNECT_INITIAL_MS;

   if Assigned(FLogger) then
      begin
      FLogger.Info('[%s spectrum] connected to %s:%d', [FRadioName, FHost, FPort]);
      end;
end;

procedure TK4SpectrumThread.CloseLink;
begin
   FLinkUp := False;

   try
      if FClient.Connected then
         begin
         FClient.Disconnect(False);
         end;
   except
      // Already gone; nothing to report that the caller does not know.
   end;
end;

procedure TK4SpectrumThread.ReadAvailable;
var
   available: Integer;
   idbuf: TIdBytes;
begin
   // Blocks up to READ_POLL_MS waiting for bytes, then returns whether or not
   // any arrived -- that is what keeps this loop responsive to Terminate.
   FClient.IOHandler.CheckForDataOnSource(READ_POLL_MS);
   FClient.IOHandler.CheckForDisconnect(True, True);

   available := FClient.IOHandler.InputBuffer.Size;

   if available <= 0 then
      begin
      Exit;
      end;

   SetLength(idbuf, 0);
   FClient.IOHandler.ReadBytes(idbuf, available, False);

   if Length(idbuf) = 0 then
      begin
      Exit;
      end;

   // TIdBytes and TBytes are both `array of Byte` but they are DISTINCT named
   // types, so this is a copy rather than a cast.  One memcpy per socket read
   // at 150 KB/s is not measurable, and a hard cast between two dynamic array
   // types is the kind of thing that works until a compiler decides otherwise.
   if Length(FChunk) < Length(idbuf) then
      begin
      SetLength(FChunk, Length(idbuf));
      end;

   Move(idbuf[0], FChunk[0], Length(idbuf));
   FFramer.Feed(FChunk, Length(idbuf));

   DrainFrames;
end;

procedure TK4SpectrumThread.DrainFrames;
var
   frame: TSpectrumFrame;
begin
   // Terminated is checked per frame: one read can carry several, and a
   // shutdown should not have to wait for the whole batch to be delivered.
   while (not Terminated) and FFramer.NextFrame(frame) do
      begin
      if Assigned(FOnFrame) then
         begin
         FOnFrame(frame);
         end;
      end;
end;

procedure TK4SpectrumThread.Execute;
begin
   while not Terminated do
      begin
      try
         if FLinkUp then
            begin
            ReadAvailable;
            end
         else
            begin
            OpenLink;
            end;
      except
         on E: Exception do
            begin
            // One handler for both connect and read failures, because the
            // response is the same: drop the link and back off.  A radio that
            // is switched off looks exactly like one that was never there.
            if Assigned(FLogger) and FLinkUp then
               begin
               // Logged only on the transition.  A rig that stays off would
               // otherwise write a line every backoff interval for as long as
               // the window is open.
               FLogger.Warn('[%s spectrum] link lost: %s', [FRadioName, E.Message]);
               end;

            CloseLink;
            WaitInterruptibly(FReconnectDelay);
            GrowBackoff;
            end;
      end;
      end;

   CloseLink;
end;

end.
