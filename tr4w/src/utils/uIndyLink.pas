unit uIndyLink;
{$I ..\tr4w.inc}

(* TWO RULES FOR AN INDY TCP CLIENT THAT MORE THAN ONE THREAD TOUCHES.

  Both come from the 2026-10-25 network-radio hang (commit a4866344) and its
  follow-up, and every Indy link in the program -- the radios, the DX cluster,
  the external loggers -- follows them through this one unit, so the rule
  cannot drift between copies.

  1. ASK "IS IT OPEN" WITHOUT READING THE SOCKET: IndyLinkIsOpen.

     TIdTCPConnection.Connected, and TIdIOHandlerStack.Connected beneath it,
     READ: ReadFromSource(False, 0, False) is a zero-timeout select followed by
     a blocking recv into the InputBuffer.  The link's reading thread reads the
     same socket with no lock, so a Connected from any other thread either
     blocks for ever in recv (the reader took the bytes first -- the band-map
     tune hang) or moves the reader's bytes into the buffer.  A bare Disconnect
     probes Connected too; call Disconnect(False).  IndyLinkIsOpen reads fields
     only, none of which reads, selects or checks for disconnect.

     Only the link's own reading thread may call Connected.

  2. GIVE THE CLIENT AN IOHANDLER IT OWNS, BEFORE ITS FIRST CONNECT:
     IndyLinkOwnHandler.

     Left to itself, TIdTCPClientCustom.Connect makes an IMPLICIT handler and
     marks it ManagedIOHandler (include/Core/IdTCPClient.pas:288-290); when the
     connect FAILS its except arm sets IOHandler := nil (:338-342), which FREES
     it (IdTCPConnection.pas, SetIOHandler).  Another thread holding
     IOHandler (a sender, a status probe, the reading thread) is left
     holding freed memory.  TIdIOHandler.Open also sets Opened BEFORE the
     socket connects (IdIOHandler.pas:866), so IndyLinkIsOpen answers True for
     the whole connect timeout, and a sender can be inside WriteLn on the very
     handler the failure is about to free.

     An explicitly assigned handler is NOT managed (SetIOHandler clears the
     flag): a failed Connect only Closes it and the pointer is stable for the
     client's life, so the race is gone rather than narrowed.  Reuse across
     connects is not new -- a link that came up and dropped has always
     reconnected on the same handler, since Disconnect only Closes.  The client
     component owns it, so freeing the client frees it.

  Pinned by test/unit/uTestRadioSocketNoRead, uTestClusterSocketNoRead and
  uTestExternalLoggerSocket. *)

interface

uses
   IdTCPConnection, IdTCPClient, IdComponent;

const
   (* The connect timeout for a persistent Indy link, in MILLISECONDS (Indy's
     ConnectTimeout is milliseconds -- the external logger passed 10 and gave
     up after 10 ms).  5000 is what TFactoryRadioBase.Connect uses, raised from
     the same mistake on 2026-05-31.  The radio base still carries its own
     literal; repoint it here when that file is next open. *)
   INDY_LINK_CONNECT_TIMEOUT_MS = 5000;

(* True when the link is open, from fields only -- never Connected.  False for
  a nil client, a client with no handler yet, or a handler that is not
  socket-based. *)
function IndyLinkIsOpen(conn: TIdTCPConnection): boolean;

(* Make the client's IOHandler if it has none.  aOnStatus is forwarded because
  Indy hands OnStatus only to an implicit handler (IdTCPClient.pas:293); nil
  leaves it unset.  Does nothing when a handler already exists, so it is safe
  to call before every Connect. *)
procedure IndyLinkOwnHandler(client: TIdTCPClient; aOnStatus: TIdStatusEvent);

implementation

uses
   IdIOHandler, IdIOHandlerSocket;

function IndyLinkIsOpen(conn: TIdTCPConnection): boolean;
var
   io: TIdIOHandler;
   sockHandler: TIdIOHandlerSocket;
begin
   Result := False;

   if conn = nil then
      begin
      Exit;
      end;

   io := conn.IOHandler;
   if io = nil then
      begin
      Exit;      // never connected: IndyLinkOwnHandler makes it on first use
      end;

   sockHandler := conn.Socket;   // nil when the IOHandler is not socket-based
   if sockHandler = nil then
      begin
      Exit;
      end;

   Result := io.Opened and
             (not io.ClosedGracefully) and
             sockHandler.BindingAllocated;
end;

procedure IndyLinkOwnHandler(client: TIdTCPClient; aOnStatus: TIdStatusEvent);
var
   ownedHandler: TIdIOHandler;
begin
   if (client = nil) or (client.IOHandler <> nil) then
      begin
      Exit;
      end;

   (* Built in a local and published last: SetIOHandler assigns FSocket before
     FIOHandler, so a reader that sees the handler also sees its Socket. *)
   ownedHandler := TIdIOHandler.MakeDefaultIOHandler(client);
   if Assigned(aOnStatus) then
      begin
      ownedHandler.OnStatus := aOnStatus;
      end;
   client.IOHandler := ownedHandler;
end;

end.
