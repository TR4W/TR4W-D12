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
unit uDXClusterClient;

{
  THE DX CLUSTER CONNECTION, WITH NO UI ATTACHED.

  One class, one job: hold a TCP connection to a cluster node and hand the
  caller COMPLETE LINES.  It knows nothing about windows, list boxes, spots,
  bandmaps or globals -- which is what makes it constructible in a test EXE
  (test/integration/uTestDXClusterClient.pas drives it against a fixture server
  on loopback).

  WHY IT EXISTS -- two defects in the raw-Winsock version it replaces:

  1. LINES WERE LOST AT SEGMENT BOUNDARIES.  The old reader posted whatever one
     recv() returned -- an arbitrary chunk -- and the parser restarted its
     line scan on every chunk with no carry-over.  A DX line split across two
     TCP segments was therefore cut in half and BOTH halves discarded (neither
     matches "DX de "), silently losing the spot.  Rare on a quiet node, routine
     on a busy one, and invisible in the log because the console shows the two
     fragments as separate lines.  Indy buffers until the terminator, so a line
     arrives whole no matter how the network chopped it up.

  2. IPv4 ONLY.  utils_net.GetConnection resolves with gethostbyname into a
     sockaddr_in.  TIdTCPClient resolves per the stack and works with either
     family.  (GetConnection is untouched -- five other callers still use it.)

  ENCODING.  Cluster text is 8-bit, not UTF-8: callsign comments carry accented
  characters in whatever codepage the spotter's node used, and the parser
  downstream is byte-oriented and column-sensitive.  Every read and write pins
  IndyTextEncoding_8Bit so one byte maps to one character and column offsets
  survive.  Letting Indy default to UTF-8 would silently re-length any line
  containing a byte >= $80 and shift every field after it.

  THREADING.  OnLine / OnConnected / OnDisconnected fire on the READER THREAD.
  Callers must marshal to the UI thread themselves -- uTelnet does it by
  PostMessage, exactly as it did with the old chunk reader.  Nothing here
  touches the VCL or a window handle.
}

interface

uses
   Classes, SysUtils, IdTCPClient, IdGlobal, IdException, IdExceptionCore,
   IdStack,
   IdBuffer;   // TIdBuffer -- the non-destructive PeekByte in ReportPendingText

type
   // A complete line, CR/LF stripped.  AnsiString, not string: the parser
   // downstream is byte-oriented and column-sensitive (see ENCODING above).
   TDXClusterLineEvent = procedure(const Line: AnsiString) of object;

   // Text is for the log/console; Code is the socket error where one is known
   // (0 when the peer simply closed).
   TDXClusterErrorEvent = procedure(const Text: string; Code: Integer) of object;

   TDXClusterNotifyEvent = procedure of object;

   TDXClusterClient = class;

   // Blocking reads live here so the caller's thread never blocks.  The thread
   // owns NOTHING: it reads and raises events, and the client owns the socket.
   TDXClusterReader = class(TThread)
   private
      FOwner: TDXClusterClient;
   protected
      procedure Execute; override;
   public
      constructor Create(AOwner: TDXClusterClient);
   end;

   TDXClusterClient = class
   private
      FTCP:      TIdTCPClient;
      FReader:   TDXClusterReader;
      FStopping: Boolean;
      FOnLine:         TDXClusterLineEvent;
      FOnPendingText:  TDXClusterLineEvent;
      FOnConnected:    TDXClusterNotifyEvent;
      FOnDisconnected: TDXClusterErrorEvent;
      // What was last reported as pending, so an unchanged buffer is not
      // re-announced on every poll.  Reader thread only.
      FLastPending:    AnsiString;
      function GetIsConnected: Boolean;
      procedure ReportPendingText;
   public
      constructor Create;
      destructor Destroy; override;

      // Blocking connect.  Raises nothing: returns False and reports the reason
      // through OnDisconnected, because every caller wants the message rather
      // than an exception crossing a thread boundary.
      function Connect(const Host: string; Port: Word): Boolean;

      // Safe to call when not connected, and safe to call from the UI thread
      // while the reader is blocked in a read -- disconnecting the IOHandler is
      // what unblocks it.
      procedure Disconnect;

      // Appends CRLF.  Cluster commands are line-oriented and every node wants
      // the pair; the old code appended #13#10 by hand for the same reason.
      procedure SendLine(const S: AnsiString);

      property IsConnected: Boolean read GetIsConnected;

      // All of these fire on the READER THREAD -- marshal before touching UI.
      property OnLine: TDXClusterLineEvent read FOnLine write FOnLine;

      // TEXT THAT HAS ARRIVED BUT HAS NO LINE TERMINATOR YET.
      //
      // A cluster's login prompts are sent WITHOUT a terminator -- `login: ` and
      // `password: ` are exactly that -- and the node then waits for an answer.
      // Because this reader only ever raised OnLine, that text sat in Indy's
      // input buffer forever: the node waited for us, we waited for an LF, and
      // neither moved.  Proven by packet capture against HamAlert, 2026-08-12:
      // the server sent `password: ` and TR4W never replied.
      //
      // In the capture corpus the same prompts DO eventually appear -- smeared
      // onto the front of a later line (`login: nected to VE7CC-1:`) -- which is
      // exactly why the defect stayed hidden: it only bites when the node has
      // nothing more to say until we answer, which is precisely the login.
      //
      // NON-DESTRUCTIVE: the bytes are peeked, never consumed, so when the rest
      // of the line does arrive OnLine still delivers it whole. Fires only when
      // the pending text CHANGES, not on every poll.
      property OnPendingText: TDXClusterLineEvent read FOnPendingText write FOnPendingText;
      property OnConnected: TDXClusterNotifyEvent read FOnConnected write FOnConnected;
      property OnDisconnected: TDXClusterErrorEvent read FOnDisconnected write FOnDisconnected;
   end;

implementation

const
   // Most a prompt could sensibly be. Bounds the peek so a node streaming
   // without terminators cannot make the reader walk the whole buffer per poll.
   MAX_PENDING_PEEK = 512;

   // How long a read waits before coming up for air to re-check Terminated.
   // Only affects shutdown latency -- a cluster can be idle for minutes and
   // that is not an error, so a timeout is never reported as one.
   READ_POLL_MS = 250;

{ TDXClusterReader }

constructor TDXClusterReader.Create(AOwner: TDXClusterClient);
begin
   FOwner := AOwner;
   FreeOnTerminate := False;   // the client joins and frees it in Disconnect
   inherited Create(False);
end;

procedure TDXClusterReader.Execute;
var
   line: string;
   closeText: string;
   closeCode: Integer;
begin
   closeText := 'Cluster connection closed';
   closeCode := 0;
   try
      while not Terminated do
         begin
         try
            // 8-bit encoding pinned: see the unit header.  The explicit timeout
            // is what lets Terminated be honoured on an idle connection.
            line := FOwner.FTCP.IOHandler.ReadLn(LF, READ_POLL_MS, -1,
                                                 IndyTextEncoding_8Bit);
            if FOwner.FTCP.IOHandler.ReadLnTimedout then
               begin
               // Idle, not an error -- but "idle" is also exactly the state a
               // node leaves us in when it has sent an unterminated prompt and
               // is waiting for the answer.  Look before looping.
               FOwner.ReportPendingText;
               Continue;
               end;
            // ReadLn splits on LF; a CRLF node leaves the CR behind.
            if (line <> '') and (line[Length(line)] = #13) then
               begin
               SetLength(line, Length(line) - 1);
               end;
            // A completed line consumes whatever was pending, so the next
            // partial starts from nothing.
            FOwner.FLastPending := '';
            if Assigned(FOwner.FOnLine) then
               begin
               FOwner.FOnLine(AnsiString(line));
               end;
         except
            // A disconnect requested from another thread closes the IOHandler
            // under us; that is an orderly stop, not a failure to report.
            on E: Exception do
               begin
               if not (Terminated or FOwner.FStopping) then
                  begin
                  closeText := E.Message;
                  if E is EIdSocketError then
                     begin
                     closeCode := EIdSocketError(E).LastError;
                     end;
                  end;
               Break;
               end;
         end;
         end;
   finally
      if not FOwner.FStopping then
         begin
         if Assigned(FOwner.FOnDisconnected) then
            begin
            FOwner.FOnDisconnected(closeText, closeCode);
            end;
         end;
   end;
end;

{ TDXClusterClient }

constructor TDXClusterClient.Create;
begin
   inherited Create;
   FTCP := TIdTCPClient.Create(nil);
   FTCP.ConnectTimeout := 10000;
   FTCP.ReadTimeout    := READ_POLL_MS;
end;

destructor TDXClusterClient.Destroy;
begin
   Disconnect;
   FTCP.Free;
   inherited Destroy;
end;

// Peek at whatever has arrived without a terminator and announce it once.
//
// PEEK, NEVER EXTRACT.  Consuming here would steal the front of the line that
// OnLine is going to deliver when the rest arrives -- turning a login prompt
// into a truncated spot.  PeekByte is the only non-destructive read TIdBuffer
// offers, so the bytes are copied out one at a time; the buffer is a prompt-
// sized handful at this point, and the cap makes the worst case bounded anyway.
procedure TDXClusterClient.ReportPendingText;
var
   buf: TIdBuffer;
   n: Integer;
   i: Integer;
   s: AnsiString;
begin
   if not Assigned(FOnPendingText) then
      begin
      Exit;
      end;

   // Any of these can be nil or raise on a link that is going down; a partial
   // line is never worth an exception crossing the reader loop.
   try
      if (FTCP = nil) or (FTCP.IOHandler = nil) then
         begin
         Exit;
         end;
      buf := FTCP.IOHandler.InputBuffer;
      if buf = nil then
         begin
         Exit;
         end;
      n := buf.Size;
   except
      Exit;
   end;

   if n <= 0 then
      begin
      // Nothing pending. Clear, so that a prompt arriving later is seen as new
      // even if it is textually identical to the previous one -- two successive
      // `password: ` prompts after a bad password are a real case.
      FLastPending := '';
      Exit;
      end;

   if n > MAX_PENDING_PEEK then
      begin
      // A very long unterminated run is not a prompt. Bounded so a node that
      // streams without terminators cannot make this walk megabytes per poll.
      n := MAX_PENDING_PEEK;
      end;

   SetLength(s, n);
   try
      for i := 0 to n - 1 do
         begin
         s[i + 1] := AnsiChar(buf.PeekByte(i));
         end;
   except
      // The buffer can be drained by the socket layer between Size and PeekByte.
      Exit;
   end;

   if s = FLastPending then
      begin
      Exit;   // already announced; do not re-fire every poll
      end;

   FLastPending := s;
   FOnPendingText(s);
end;

function TDXClusterClient.GetIsConnected: Boolean;
begin
   // Indy raises if the IOHandler has gone; a dead link is simply "not
   // connected" to every caller here.
   try
      Result := (FTCP <> nil) and FTCP.Connected;
   except
      Result := False;
   end;
end;

function TDXClusterClient.Connect(const Host: string; Port: Word): Boolean;
begin
   Result := False;
   if IsConnected then
      begin
      // ALREADY CONNECTED IS NOT A CONNECT FAILURE, and returning a bare False
      // made it indistinguishable from one.  The caller reported it as
      // "WinSock 0: The operation completed successfully" -- a failure message
      // that says nothing failed -- because no error code was ever set
      // (NY4I, 2026-08-12, switching from HamAlert to NC7J).
      //
      // Reported through the same channel as a real failure so the reason
      // reaches the operator, and named plainly so the log says what to do.
      if Assigned(FOnDisconnected) then
         begin
         FOnDisconnected('Already connected to a cluster -- disconnect first', 0);
         end;
      Exit;
      end;
   FStopping := False;
   try
      FTCP.Host := Host;
      FTCP.Port := Port;
      FTCP.Connect;
      Result := True;
   except
      on E: Exception do
         begin
         if Assigned(FOnDisconnected) then
            begin
            if E is EIdSocketError then
               begin
               FOnDisconnected(E.Message, EIdSocketError(E).LastError);
               end
            else
               begin
               FOnDisconnected(E.Message, 0);
               end;
            end;
         Exit;
         end;
   end;

   FReader := TDXClusterReader.Create(Self);
   if Assigned(FOnConnected) then
      begin
      FOnConnected;
      end;
end;

procedure TDXClusterClient.Disconnect;
begin
   // FStopping suppresses the OnDisconnected the reader would otherwise raise
   // for a close WE performed -- the caller already knows.
   FStopping := True;
   try
      if FReader <> nil then
         begin
         FReader.Terminate;
         end;
      try
         if FTCP.Connected then
            begin
            FTCP.Disconnect;
            end;
      except
         // already gone; nothing to report
      end;
      // Close the IOHandler too: Disconnect alone can leave the reader blocked
      // inside ReadLn until its timeout expires.
      if FTCP.IOHandler <> nil then
         begin
         FTCP.IOHandler.CloseGracefully;
         end;
      if FReader <> nil then
         begin
         FReader.WaitFor;
         FreeAndNil(FReader);
         end;
   finally
      FStopping := False;
   end;
end;

procedure TDXClusterClient.SendLine(const S: AnsiString);
begin
   if not IsConnected then
      begin
      Exit;
      end;
   FTCP.IOHandler.Write(string(S) + #13#10, IndyTextEncoding_8Bit);
end;

end.
