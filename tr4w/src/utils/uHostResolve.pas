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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uHostResolve;
{$I ..\tr4w.inc}

(* ONE PLACE TURNS A HOST NAME THE OPERATOR TYPED INTO AN ADDRESS FOR INDY.

  Issue 148.  The vendored Indy resolves a name on Unix with FPC's netdb: the
  hosts file, then a DNS client of its own that asks whatever /etc/resolv.conf
  names.  It never calls the C library, so it knows nothing of
  /etc/nsswitch.conf and therefore nothing of mDNS.  Measured on Linux Mint:
  `getent hosts pi400.local` (glibc, through avahi) answers, `resolvectl query
  pi400.local` (the systemd-resolved stub that resolv.conf points at) does not,
  and so a server, radio or cluster named pi400.local could not be used while
  its IP address could.

  WINDOWS IS NOT TOUCHED.  Winsock's own resolver already does what the machine
  is configured to do, so on Windows every function here returns the name
  exactly as given and calls nothing.

  ON UNIX the C library is asked, because the platform resolver is the only one
  that knows what this machine is configured with (hosts, DNS, mDNS, NIS, a
  corporate search domain).  Which binding:

    Linux   FPC ships one: the cnetdb unit (fcl-net) declares the libc
            gethostbyname.  Nothing is declared here.
    macOS   cnetdb is NOT built for Darwin (fcl-net/fpmake.pp:76 lists
            linux, freebsd, solaris, android).  So the one function is
            declared below, with the record it returns.

  gethostbyname and not getaddrinfo, on purpose: the hostent record has the
  same layout on glibc and on Darwin, while addrinfo orders ai_addr and
  ai_canonname differently on the two (cnetdb has to carry a define for it), and
  getaddrinfo wants a hints record besides.  It is IPv4-only by definition,
  which is what this program connects with: Indy's default IP version, and
  uDXClusterClient states the same.  A name that has ONLY an IPv6 record fails
  here with a message that says so, which is what Indy's IPv4 connect would
  have done with it.

  WHAT IS NOT RESOLVED: an empty name (passed through for the caller's own
  empty check), an IPv4 literal and anything containing a colon (an IPv6
  literal; a host name cannot contain one).  Those never reach the C library.

  THREADS.  gethostbyname can block for seconds (a dead DNS server, mDNS
  timing out), so CALL THIS ONLY FROM A THREAD THAT MAY WAIT: a connect or
  worker thread, never the main thread.  Each site's thread is recorded in
  .claude/agents/multi-op-network.md.  It is serialised by a lock, because the
  C function returns a pointer to storage the next call may overwrite.

  This unit has no logger and no dependency on MainUnit.  A failure comes back
  as text that NAMES the host; the caller logs it. *)

interface

uses
   SysUtils;

type
   (* Raised by ResolveHostForConnect.  The message names the host. *)
   EHostResolveError = class(Exception);

   (* The platform lookup, as a type so everything around it is testable on a
     machine whose own arm does nothing.  False sets aWhy to the reason only;
     TryResolveHost adds the name. *)
   THostLookup = function(const aName: string; out aIPv4: string;
                          out aWhy: string): Boolean;

(* A dotted-quad IPv4 address (four decimal parts, each 0..255) or anything
  containing a colon.  Such a string is already an address. *)
function HostIsAddressLiteral(const aHost: string): Boolean;

(* THE LOGIC, with the lookup handed in.  An empty name and a literal come back
  unchanged with True and the lookup is not called.  Otherwise the lookup's
  IPv4 address, or False with aWhy = "could not resolve 'name': reason" and
  aAddress = aHost. *)
function ResolveHostWith(const aHost: string; aLookup: THostLookup;
                         out aAddress: string; out aWhy: string): Boolean;

(* THE PLATFORM'S ANSWER.  Windows: aAddress = aHost, True, nothing called.
  Unix: ResolveHostWith over the C library. *)
function TryResolveHost(const aHost: string; out aAddress: string;
                        out aWhy: string): Boolean;

(* The same, for a site that already has an except handler around its connect:
  the address, or EHostResolveError whose message names the host. *)
function ResolveHostForConnect(const aHost: string): string;

implementation

{$IFDEF UNIX}
uses
   SyncObjs,
   Sockets,       (* AF_INET *)
{$IFDEF LINUX}
   cnetdb;        (* gethostbyname, PHostEnt -- FPC's own binding, see above *)
{$ELSE}
   ctypes, initc; (* cint, clib *)
{$ENDIF}
{$ENDIF}

function HostIsAddressLiteral(const aHost: string): Boolean;
var
   i:     Integer;
   parts: Integer;
   value: Integer;
   digits: Integer;
begin
   Result := False;
   if aHost = '' then
      begin
      Exit;
      end;

   if Pos(':', aHost) > 0 then
      begin
      Result := True;
      Exit;
      end;

   parts  := 1;
   value  := 0;
   digits := 0;
   for i := 1 to Length(aHost) do
      begin
      if (aHost[i] >= '0') and (aHost[i] <= '9') then
         begin
         value := (value * 10) + (Ord(aHost[i]) - Ord('0'));
         Inc(digits);
         if (digits > 3) or (value > 255) then
            begin
            Exit;
            end;
         end
      else if aHost[i] = '.' then
         begin
         if digits = 0 then
            begin
            Exit;
            end;
         Inc(parts);
         value  := 0;
         digits := 0;
         end
      else
         begin
         Exit;
         end;
      end;

   Result := (parts = 4) and (digits > 0);
end;

function ResolveHostWith(const aHost: string; aLookup: THostLookup;
                         out aAddress: string; out aWhy: string): Boolean;
var
   name:   string;
   ip:     string;
   reason: string;
begin
   aAddress := aHost;
   aWhy     := '';
   Result   := True;

   name := Trim(aHost);
   if (name = '') or HostIsAddressLiteral(name) then
      begin
      Exit;
      end;

   ip     := '';
   reason := '';
   if aLookup(name, ip, reason) then
      begin
      aAddress := ip;
      Exit;
      end;

   Result := False;
   aWhy   := 'could not resolve ''' + aHost + ''': ' + reason;
end;

{$IFDEF UNIX}

{$IFNDEF LINUX}
(* macOS: the same record and function cnetdb declares for Linux.  The layout
  is the BSD hostent; it is identical on glibc.  clib is initc's name for the C
  library ('c'). *)
type
   hostent = record
      h_name:      PAnsiChar;
      h_aliases:   PPAnsiChar;
      h_addrtype:  cint;
      h_length:    cint;
      h_addr_list: PPAnsiChar;
   end;
   PHostEnt = ^hostent;

function gethostbyname(name: PAnsiChar): PHostEnt; cdecl; external clib name 'gethostbyname';
{$ENDIF}

var
   GLookupLock: TCriticalSection;

function LibcLookup(const aName: string; out aIPv4: string;
                    out aWhy: string): Boolean;
var
   cname: RawByteString;
   ent:   PHostEnt;
   addr:  PByteArray;
begin
   Result := False;
   aIPv4  := '';
   aWhy   := '';

   (* THE C BOUNDARY: gethostbyname takes a NUL-terminated byte string, so the
     name is encoded to UTF-8 bytes and held in a local that outlives the call.
     A RawByteString is NUL-terminated by the RTL. *)
   cname := UTF8Encode(aName);

   GLookupLock.Enter;
   try
      ent := gethostbyname(PAnsiChar(cname));
      if ent = nil then
         begin
         aWhy := 'the system resolver has no IPv4 address for it ' +
                 '(no such name, or only an IPv6 address)';
         end
      else if (ent^.h_addrtype <> AF_INET) or (ent^.h_length <> 4) or
              (ent^.h_addr_list = nil) or (ent^.h_addr_list^ = nil) then
         begin
         aWhy := 'the system resolver returned no IPv4 address';
         end
      else
         begin
         (* Copied out before the lock is left: the record is the C library's. *)
         addr   := PByteArray(ent^.h_addr_list^);
         aIPv4  := IntToStr(addr^[0]) + '.' + IntToStr(addr^[1]) + '.' +
                   IntToStr(addr^[2]) + '.' + IntToStr(addr^[3]);
         Result := True;
         end;
   finally
      GLookupLock.Leave;
   end;
end;

function TryResolveHost(const aHost: string; out aAddress: string;
                        out aWhy: string): Boolean;
begin
   Result := ResolveHostWith(aHost, LibcLookup, aAddress, aWhy);
end;

{$ELSE}

function TryResolveHost(const aHost: string; out aAddress: string;
                        out aWhy: string): Boolean;
begin
   (* WINDOWS: Winsock resolves the name exactly as it always did. *)
   aAddress := aHost;
   aWhy     := '';
   Result   := True;
end;

{$ENDIF}

function ResolveHostForConnect(const aHost: string): string;
var
   why: string;
begin
   if not TryResolveHost(aHost, Result, why) then
      begin
      raise EHostResolveError.Create(AnsiString(why));
      end;
end;

{$IFDEF UNIX}
initialization
   GLookupLock := TCriticalSection.Create;

finalization
   GLookupLock.Free;
{$ENDIF}

end.
