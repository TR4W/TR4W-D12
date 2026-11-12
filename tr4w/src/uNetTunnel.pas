(*
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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
*)
unit uNetTunnel;
{$I tr4w.inc}

(* THE MULTI-OP LINK'S ONE TAILCAT TUNNEL: who owns it and when it exists.

  Issue 293.  With SERVER USE TAILCAT on, the link does not connect to SERVER
  ADDRESS.  It connects to 127.0.0.1 at a port this unit answers, and
  uTailcatForwarder carries the bytes through the tunnel SERVER TAILCAT
  ADDRESS names.  The server's two ports travel together: the link's
  (SERVER PORT) and the catch-up download's (SERVER PORT + 1).

  WHAT THIS UNIT ADDS TO THE FORWARDER is the lifetime, and nothing else:

    * ONE tunnel for the process, made by the connect thread on its first
      attempt and KEPT across a dropped link, so a reconnect is a new stream
      through a tunnel that is already up, not a new registration with the
      relays.
    * It is closed when the operator disconnects, when the program exits, and
      when a connect through it FAILS -- so the next attempt builds a new one
      and pings the server again, which is the only step that can say why.
    * A changed address or port makes a new one (the forwarder compares; this
      unit never keeps the address itself).

  THREADS.  NetTunnelOpen BLOCKS (the library is loaded, the relays are
  reached, the server is pinged: up to PING_TIMEOUT_MS) and is for the connect
  thread only.  NetTunnelSyncPort and NetTunnelClose do not wait on the
  network and are safe on the main thread; the lock guards one pointer and is
  never held across a blocking call.

  NOTHING HERE LOGS THE ADDRESS, and the reasons it returns do not hold it. *)

interface

uses
   SysUtils, uTailcatForwarder;

const
   (* Where the link connects while a tunnel is open. *)
   NET_TUNNEL_HOST = '127.0.0.1';

var
   (* Where this unit's own lines go. uNet installs it; nil is silence, which
     is what a unit test wants. *)
   NetTunnelLog: TTailcatLogProc = nil;

(* OPEN THE TUNNEL FOR THIS ADDRESS AND SERVER PORT, or keep the one already
  open for exactly them. aLocalPort is where the link connects (the catch-up's
  port comes from NetTunnelSyncPort). False: nothing is open and aWhy says why
  in words an operator can act on. CONNECT THREAD ONLY -- it blocks. *)
function NetTunnelOpen(const aAddress: string; const aServerPort: word;
                       out aLocalPort: word; out aWhy: string): boolean;

(* The local port standing for the server's port + 1, when a tunnel is open.
  Does not wait. *)
function NetTunnelSyncPort(out aLocalPort: word): boolean;

function NetTunnelIsOpen: boolean;

(* Close the tunnel if there is one. Waits for its connection threads, which
  end as soon as their streams are closed; it does not wait on the network. *)
procedure NetTunnelClose;

implementation

uses
   SyncObjs, uTailcatLib, uAppPaths;

const
   (* The first ping includes registering with a relay; measured at 0.2 s on a
     home connection and 81 ms through one. Fifteen seconds is the patience of
     a bad hotel network, on a thread that has nothing else to do. *)
   PING_TIMEOUT_MS = 15000;

var
   GLock:      TCriticalSection = nil;
   GForwarder: TTailcatForwarder = nil;

procedure Say(const aLevel: TTailcatLogLevel; const aText: string);
begin
   if Assigned(NetTunnelLog) then
      begin
      NetTunnelLog(aLevel, aText);
      end;
end;

(* The forwarder that is open, taken OUT of the global under the lock, so the
  caller can stop it without holding anything. *)
function TakeForwarder: TTailcatForwarder;
begin
   GLock.Acquire;
   try
      Result := GForwarder;
      GForwarder := nil;
   finally
      GLock.Release;
   end;
end;

function NetTunnelIsOpen: boolean;
begin
   GLock.Acquire;
   try
      Result := GForwarder <> nil;
   finally
      GLock.Release;
   end;
end;

function NetTunnelSyncPort(out aLocalPort: word): boolean;
begin
   aLocalPort := 0;
   GLock.Acquire;
   try
      if GForwarder <> nil then
         begin
         aLocalPort := GForwarder.LocalPort(1);
         end;
   finally
      GLock.Release;
   end;
   Result := aLocalPort <> 0;
end;

procedure NetTunnelClose;
var
   old: TTailcatForwarder;
begin
   old := TakeForwarder;
   if old <> nil then
      begin
      old.Free;
      Say(tllInfo, 'the Tailcat tunnel is closed');
      end;
end;

function NetTunnelOpen(const aAddress: string; const aServerPort: word;
                       out aLocalPort: word; out aWhy: string): boolean;
var
   fresh: TTailcatForwarder;
   old:   TTailcatForwarder;
   same:  boolean;
begin
   Result := False;
   aLocalPort := 0;
   aWhy := '';

   if aAddress = '' then
      begin
      aWhy := 'Use Tailcat is ticked and the Tailcat address is empty';
      NetTunnelClose;
      Exit;
      end;

   (* The sync port is the server port plus one, so the top of the range has
     no room for it. TServerPort already stops one short; this is for a caller
     that is not the settings object. *)
   if aServerPort = High(word) then
      begin
      aWhy := 'the server port leaves no room for the synchronize port';
      Exit;
      end;

   GLock.Acquire;
   try
      same := (GForwarder <> nil)
              and GForwarder.IsFor(aAddress, [aServerPort, aServerPort + 1]);
      if same then
         begin
         aLocalPort := GForwarder.LocalPort(0);
         end;
   finally
      GLock.Release;
   end;
   if same then
      begin
      Result := True;
      Exit;
      end;

   (* A NEW ONE, built with no lock held. Only the connect thread comes here
     and there is one of it at a time (uNet's NetThreadID), so two builds
     cannot race; the main thread can only take the old one away. *)
   NetTunnelClose;

   if not TailcatLoad(IncludeTrailingPathDelimiter(PrivateLibraryDir)
                      + TAILCAT_LIB, aWhy) then
      begin
      Exit;
      end;

   fresh := TTailcatForwarder.Create(aAddress, [aServerPort, aServerPort + 1],
                                     NetTunnelLog);
   if not fresh.Start(PING_TIMEOUT_MS, aWhy) then
      begin
      fresh.Free;
      Exit;
      end;

   aLocalPort := fresh.LocalPort(0);
   Say(tllInfo, UnicodeFormat('the Tailcat tunnel is up: the server answered in'
                              + ' %d ms', [fresh.PingMs]));

   GLock.Acquire;
   try
      old := GForwarder;
      GForwarder := fresh;
   finally
      GLock.Release;
   end;
   (* Cannot normally be set: it was taken above. Freed, not leaked, if a
     second caller ever appears. *)
   old.Free;
   Result := True;
end;

initialization
   GLock := TCriticalSection.Create;

finalization
   (* uNet.NetLinkShutdown has closed the tunnel long before this. A forwarder
     still here means the program ended while a connect was in flight; it is
     left to the process end, because stopping it waits on threads and this is
     unit finalization. *)
   FreeAndNil(GLock);

end.
