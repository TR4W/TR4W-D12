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
unit uTailcatLib;
{$I ..\tr4w.inc}

(* THE BINDING TO libtailcat, AND THE ONLY UNIT THAT NAMES ITS FUNCTIONS.

  Issue 293.  Tailcat is Tailscale's library for one TCP service reached from
  another network by pasting an address: WireGuard inside, their relays
  outside, no account.  Upstream ships a C ABI for it (cmd/libtailcat,
  tailcat.h, ABI version 1), built from Go.  This unit binds to that header and
  hands the rest of the program strings, handles and status codes.

  WHY THIS IS A RAW LIBRARY BINDING, which this tree asks every one to justify:
  there is no FPC or LCL class for it and there cannot be one -- the protocol
  is the library.  The alternatives were a helper executable beside TR4W (the
  retired docs/CONTEST_LINK_DESIGN.md) and the stock tailcat command line the
  operator runs by hand; NY4I chose in-process, 2026-11-12.

  WHY IT IS LOADED AT RUN TIME AND NOT LINKED: the library is OPTIONAL.  A
  station on the server's own network never needs it, the 32-bit Windows build
  cannot load it at all (upstream builds 64-bit only), and plain TCP must work
  on a machine that does not have the file.  A static `external` would make a
  missing file a start-up failure of the whole program.

  IT IS NEVER UNLOADED.  The library embeds a Go runtime, and tailcat.h says so
  in terms: "Keep it loaded for the process lifetime".  There is deliberately
  no unload routine here; do not add one.

  SECRETS.  A Tailcat address holds a pre-shared key.  Nothing in this unit
  logs, and an error text that came back from the library has the address cut
  out of it before it is returned (TailcatClientNew), so a caller may log the
  reason it is given.

  THREADS.  Every call is synchronous.  Different handles may be used from
  different threads at once, and ONE reader plus ONE writer may share a
  connection; that is the header's rule and uTailcatForwarder relies on it.
  Closing a handle from another thread interrupts a call blocked on it.

  FLOATING-POINT EXCEPTIONS.  FPC unmasks them on its threads; C and Go code
  expects them masked, and a Go routine that runs on the CALLING thread would
  otherwise turn an ordinary NaN into a crash inside the library.  Every call
  below runs with all of them masked and puts the caller's mask back.  This is
  the same precaution the LCL takes around GTK.  It is a precaution: no crash
  was observed without it, because it was never run without it. *)

interface

uses
   SysUtils;

type
   (* tc_handle: opaque, nonzero, never reused in a process. 0 is "none". *)
   TTailcatHandle = QWord;

const
   TAILCAT_NO_HANDLE = TTailcatHandle(0);

   (* The TC_* status codes of tailcat.h, ABI 1. Branch on these, never on the
     error text. *)
   TC_OK               = 0;
   TC_INVALID_ARGUMENT = 1;
   TC_CLOSED           = 2;
   TC_TIMEOUT          = 3;
   TC_CANCELLED        = 4;
   TC_FAILURE          = 5;
   TC_EOF              = 6;
   (* NOT A LIBRARY CODE: the library is not loaded. Returned by every wrapper
     so a caller needs no separate "is it loaded" branch. *)
   TC_NOT_LOADED       = -1;

   (* The one ABI this binding was written against. A library reporting another
     is refused rather than called with the wrong signatures. *)
   TAILCAT_ABI_VERSION = 1;

{$IF DEFINED(WINDOWS)}
   TAILCAT_LIB = 'libtailcat.dll';
{$ELSEIF DEFINED(DARWIN)}
   TAILCAT_LIB = 'libtailcat.dylib';
{$ELSE}
   TAILCAT_LIB = 'libtailcat.so';
{$IFEND}

(* LOAD THE LIBRARY FROM aPath (a full path), once. True when it is loaded and
  speaks ABI 1 -- now or from an earlier call. False leaves aWhy saying what
  failed in words an operator can act on. Safe from any thread. A failed load
  may be tried again (the operator may have copied the file in). *)
function TailcatLoad(const aPath: string; out aWhy: string): boolean;

function TailcatLoaded: boolean;

(* A CLIENT FOR ONE SERVER ADDRESS. No network traffic yet: the library starts
  on the first ping or dial. aWhy never contains the address. *)
function TailcatClientNew(const aAddress: string; out aClient: TTailcatHandle;
                          out aWhy: string): integer;

(* START THE CLIENT IF NEEDED AND PING THE SERVER through the relay, waiting at
  most aTimeoutMs. TC_OK and a round-trip time, or the reason. This is the one
  call that separates "the tunnel reaches the server" from "the server's TCP
  port answered". *)
function TailcatClientPing(const aClient: TTailcatHandle;
                           const aTimeoutMs: integer; out aPingMs: integer;
                           out aWhy: string): integer;

(* OPEN A TCP STREAM to aPort on the server, waiting at most aTimeoutMs. *)
function TailcatDial(const aClient: TTailcatHandle; const aPort: word;
                     const aTimeoutMs: integer; out aConn: TTailcatHandle;
                     out aWhy: string): integer;

(* READ up to aCapacity bytes. aCount is set EVEN ON FAILURE: use the bytes
  first, the status second. TC_EOF is the far end's orderly close. Blocks
  until data, the end, or a close of the handle from another thread. *)
function TailcatRead(const aConn: TTailcatHandle; aBuffer: Pointer;
                     const aCapacity: PtrUInt; out aCount: PtrUInt): integer;

(* WRITE ALL aLength bytes (the library may write short; this loops). *)
function TailcatWriteAll(const aConn: TTailcatHandle; aBuffer: Pointer;
                         const aLength: PtrUInt): integer;

(* Send the end-of-stream and keep reading. *)
function TailcatCloseWrite(const aConn: TTailcatHandle): integer;

(* RETIRE ANY HANDLE. On a client it closes its connections too, interrupts
  calls blocked on them and WAITS for those calls to return. 0 is ignored. *)
procedure TailcatClose(const aHandle: TTailcatHandle);

(* What the status codes are called, for a log line. *)
function TailcatStatusName(const aStatus: integer): string;

implementation

uses
   (* DynLibs: FPC's own loader -- LoadLibrary on Windows, dlopen elsewhere. *)
   DynLibs, Math, SyncObjs, fpjson;

type
   (* tailcat.h, verbatim in order and width. cdecl is what the header means on
     every platform this builds for; on x86-64 there is only one convention. *)
   PPAnsiChar = ^PAnsiChar;
   Ttc_abi_version = function: LongWord; cdecl;
   Ttc_free = procedure(aAllocation: Pointer); cdecl;
   Ttc_close = function(aResource: TTailcatHandle; aError: PPAnsiChar): LongInt; cdecl;
   Ttc_token_new = function(aTimeoutNs: Int64; aOut: PQWord; aError: PPAnsiChar): LongInt; cdecl;
   Ttc_client_new = function(aConfigJson: PAnsiChar; aOut: PQWord; aError: PPAnsiChar): LongInt; cdecl;
   Ttc_client_ping = function(aClient, aToken: TTailcatHandle; aPingMs: PLongInt; aError: PPAnsiChar): LongInt; cdecl;
   Ttc_client_dial = function(aClient, aToken: TTailcatHandle; aPort: Word; aNetwork: LongInt; aOut: PQWord; aError: PPAnsiChar): LongInt; cdecl;
   Ttc_conn_read = function(aConn, aToken: TTailcatHandle; aBuffer: Pointer; aCapacity: PtrUInt; aCount: PPtrUInt; aError: PPAnsiChar): LongInt; cdecl;
   Ttc_conn_write = function(aConn, aToken: TTailcatHandle; aBuffer: Pointer; aLength: PtrUInt; aCount: PPtrUInt; aError: PPAnsiChar): LongInt; cdecl;
   Ttc_conn_close_write = function(aConn, aToken: TTailcatHandle; aError: PPAnsiChar): LongInt; cdecl;

const
   TC_NO_CANCEL = TTailcatHandle(0);
   TC_TCP       = 1;
   ALL_FPU_EXCEPTIONS = [exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
                         exUnderflow, exPrecision];

var
   GLock:    TCriticalSection = nil;
   GModule:  TLibHandle = NilHandle;
   GReady:   boolean = False;
   tc_abi_version:      Ttc_abi_version = nil;
   tc_free:             Ttc_free = nil;
   tc_close:            Ttc_close = nil;
   tc_token_new:        Ttc_token_new = nil;
   tc_client_new:       Ttc_client_new = nil;
   tc_client_ping:      Ttc_client_ping = nil;
   tc_client_dial:      Ttc_client_dial = nil;
   tc_conn_read:        Ttc_conn_read = nil;
   tc_conn_write:       Ttc_conn_write = nil;
   tc_conn_close_write: Ttc_conn_close_write = nil;

function TailcatStatusName(const aStatus: integer): string;
begin
   case aStatus of
      TC_OK:               Result := 'ok';
      TC_INVALID_ARGUMENT: Result := 'invalid argument';
      TC_CLOSED:           Result := 'closed';
      TC_TIMEOUT:          Result := 'timed out';
      TC_CANCELLED:        Result := 'cancelled';
      TC_FAILURE:          Result := 'failed';
      TC_EOF:              Result := 'end of stream';
      TC_NOT_LOADED:       Result := 'library not loaded';
   else
      Result := 'status ' + IntToStr(aStatus);
   end;
end;

(* The library's error text as a string, and its allocation released. The text
  is UTF-8 by the header's statement. *)
function TakeError(var aError: PAnsiChar): string;
begin
   Result := '';
   if aError <> nil then
      begin
      Result := UTF8Decode(UTF8String(aError));
      tc_free(aError);
      aError := nil;
      end;
end;

(* "timed out: <text>", or the bare name when the library said nothing. *)
function Reason(const aStatus: integer; const aText: string): string;
begin
   Result := TailcatStatusName(aStatus);
   if aText <> '' then
      begin
      Result := Result + ': ' + aText;
      end;
end;

function TailcatLoaded: boolean;
begin
   Result := GReady;
end;

function Bind(const aName: AnsiString; out aMissing: string): Pointer;
begin
   Result := GetProcedureAddress(GModule, aName);
   if Result = nil then
      begin
      aMissing := UnicodeString(aName);
      end;
end;

function TailcatLoad(const aPath: string; out aWhy: string): boolean;
var
   missing: string;
   abi: LongWord;
   saved: TFPUExceptionMask;
begin
   aWhy := '';
   GLock.Acquire;
   try
      if GReady then
         begin
         Result := True;
         Exit;
         end;
      Result := False;

      if GModule = NilHandle then
         begin
         if not FileExists(aPath) then
            begin
            aWhy := 'the Tailcat library is not installed (' + aPath + ')';
            Exit;
            end;
         GModule := LoadLibrary(aPath);
         if GModule = NilHandle then
            begin
            {$IFDEF CPU64}
            aWhy := 'the Tailcat library could not be loaded (' + aPath + ')';
            {$ELSE}
            aWhy := 'this is the 32-bit TR4W and the Tailcat library is 64-bit;'
                    + ' the link through Tailcat needs the 64-bit TR4W';
            {$ENDIF}
            Exit;
            end;
         end;

      missing := '';
      tc_abi_version      := Ttc_abi_version(Bind('tc_abi_version', missing));
      tc_free             := Ttc_free(Bind('tc_free', missing));
      tc_close            := Ttc_close(Bind('tc_close', missing));
      tc_token_new        := Ttc_token_new(Bind('tc_token_new', missing));
      tc_client_new       := Ttc_client_new(Bind('tc_client_new', missing));
      tc_client_ping      := Ttc_client_ping(Bind('tc_client_ping', missing));
      tc_client_dial      := Ttc_client_dial(Bind('tc_client_dial', missing));
      tc_conn_read        := Ttc_conn_read(Bind('tc_conn_read', missing));
      tc_conn_write       := Ttc_conn_write(Bind('tc_conn_write', missing));
      tc_conn_close_write := Ttc_conn_close_write(Bind('tc_conn_close_write', missing));
      if missing <> '' then
         begin
         aWhy := 'the Tailcat library has no ' + missing + ' (' + aPath + ')';
         Exit;
         end;

      saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
      try
         abi := tc_abi_version();
      finally
         SetExceptionMask(saved);
      end;
      if abi <> TAILCAT_ABI_VERSION then
         begin
         aWhy := 'the Tailcat library speaks ABI ' + IntToStr(abi)
                 + ' and this TR4W was written for ABI '
                 + IntToStr(TAILCAT_ABI_VERSION);
         Exit;
         end;

      GReady := True;
      Result := True;
   finally
      GLock.Release;
   end;
end;

(* A deadline token, or TC_NO_CANCEL when one cannot be made. The call is left
  to the library's own internal timeouts in that case. *)
function NewDeadline(const aTimeoutMs: integer): TTailcatHandle;
var
   err: PAnsiChar;
begin
   Result := TC_NO_CANCEL;
   err := nil;
   if tc_token_new(Int64(aTimeoutMs) * 1000000, @Result, @err) <> TC_OK then
      begin
      Result := TC_NO_CANCEL;
      end;
   TakeError(err);
end;

procedure DropDeadline(const aToken: TTailcatHandle);
var
   err: PAnsiChar;
begin
   if aToken <> TC_NO_CANCEL then
      begin
      err := nil;
      tc_close(aToken, @err);
      TakeError(err);
      end;
end;

function TailcatClientNew(const aAddress: string; out aClient: TTailcatHandle;
                          out aWhy: string): integer;
var
   config: TJSONObject;
   json: UTF8String;
   err: PAnsiChar;
   saved: TFPUExceptionMask;
begin
   aClient := TAILCAT_NO_HANDLE;
   aWhy := '';
   if not GReady then
      begin
      Result := TC_NOT_LOADED;
      aWhy := TailcatStatusName(Result);
      Exit;
      end;

   (* fpjson, so an address holding a quote or a backslash is still one JSON
     string and cannot add a field of its own. *)
   config := TJSONObject.Create;
   try
      config.Add('address', UTF8Encode(aAddress));
      json := config.AsJSON;
   finally
      config.Free;
   end;

   err := nil;
   saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
   try
      Result := tc_client_new(PAnsiChar(json), @aClient, @err);
   finally
      SetExceptionMask(saved);
   end;
   aWhy := TakeError(err);
   if Result <> TC_OK then
      begin
      (* THE ADDRESS IS A SECRET and this text may be logged. *)
      aWhy := Reason(Result, UnicodeStringReplace(aWhy, aAddress, '<address>',
                                           [rfReplaceAll]));
      end;
end;

function TailcatClientPing(const aClient: TTailcatHandle;
                           const aTimeoutMs: integer; out aPingMs: integer;
                           out aWhy: string): integer;
var
   token: TTailcatHandle;
   err: PAnsiChar;
   ms: LongInt;
   saved: TFPUExceptionMask;
begin
   aPingMs := 0;
   aWhy := '';
   if not GReady then
      begin
      Result := TC_NOT_LOADED;
      aWhy := TailcatStatusName(Result);
      Exit;
      end;

   err := nil;
   ms := 0;
   saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
   try
      token := NewDeadline(aTimeoutMs);
      try
         Result := tc_client_ping(aClient, token, @ms, @err);
      finally
         DropDeadline(token);
      end;
   finally
      SetExceptionMask(saved);
   end;
   aPingMs := ms;
   aWhy := TakeError(err);
   if Result <> TC_OK then
      begin
      aWhy := Reason(Result, aWhy);
      end;
end;

function TailcatDial(const aClient: TTailcatHandle; const aPort: word;
                     const aTimeoutMs: integer; out aConn: TTailcatHandle;
                     out aWhy: string): integer;
var
   token: TTailcatHandle;
   err: PAnsiChar;
   saved: TFPUExceptionMask;
begin
   aConn := TAILCAT_NO_HANDLE;
   aWhy := '';
   if not GReady then
      begin
      Result := TC_NOT_LOADED;
      aWhy := TailcatStatusName(Result);
      Exit;
      end;

   err := nil;
   saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
   try
      token := NewDeadline(aTimeoutMs);
      try
         Result := tc_client_dial(aClient, token, aPort, TC_TCP, @aConn, @err);
      finally
         DropDeadline(token);
      end;
   finally
      SetExceptionMask(saved);
   end;
   aWhy := TakeError(err);
   if Result <> TC_OK then
      begin
      aWhy := Reason(Result, aWhy);
      end;
end;

function TailcatRead(const aConn: TTailcatHandle; aBuffer: Pointer;
                     const aCapacity: PtrUInt; out aCount: PtrUInt): integer;
var
   err: PAnsiChar;
   saved: TFPUExceptionMask;
begin
   aCount := 0;
   if not GReady then
      begin
      Result := TC_NOT_LOADED;
      Exit;
      end;
   err := nil;
   saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
   try
      Result := tc_conn_read(aConn, TC_NO_CANCEL, aBuffer, aCapacity, @aCount, @err);
   finally
      SetExceptionMask(saved);
   end;
   TakeError(err);
end;

function TailcatWriteAll(const aConn: TTailcatHandle; aBuffer: Pointer;
                         const aLength: PtrUInt): integer;
var
   err: PAnsiChar;
   done, count: PtrUInt;
   saved: TFPUExceptionMask;
begin
   if not GReady then
      begin
      Result := TC_NOT_LOADED;
      Exit;
      end;
   Result := TC_OK;
   done := 0;
   saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
   try
      while (Result = TC_OK) and (done < aLength) do
         begin
         err := nil;
         count := 0;
         Result := tc_conn_write(aConn, TC_NO_CANCEL, PByte(aBuffer) + done,
                                 aLength - done, @count, @err);
         TakeError(err);
         done := done + count;
         (* A write that reports success and moves nothing would spin here. *)
         if (Result = TC_OK) and (count = 0) then
            begin
            Result := TC_FAILURE;
            end;
         end;
   finally
      SetExceptionMask(saved);
   end;
end;

function TailcatCloseWrite(const aConn: TTailcatHandle): integer;
var
   err: PAnsiChar;
   saved: TFPUExceptionMask;
begin
   if not GReady then
      begin
      Result := TC_NOT_LOADED;
      Exit;
      end;
   err := nil;
   saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
   try
      Result := tc_conn_close_write(aConn, TC_NO_CANCEL, @err);
   finally
      SetExceptionMask(saved);
   end;
   TakeError(err);
end;

procedure TailcatClose(const aHandle: TTailcatHandle);
var
   err: PAnsiChar;
   saved: TFPUExceptionMask;
begin
   if (not GReady) or (aHandle = TAILCAT_NO_HANDLE) then
      begin
      Exit;
      end;
   err := nil;
   saved := SetExceptionMask(ALL_FPU_EXCEPTIONS);
   try
      tc_close(aHandle, @err);
   finally
      SetExceptionMask(saved);
   end;
   TakeError(err);
end;

initialization
   GLock := TCriticalSection.Create;

finalization
   (* The lock only. The library stays loaded: see the unit header. *)
   FreeAndNil(GLock);

end.
