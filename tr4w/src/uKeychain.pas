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
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)
unit uKeychain;
{$I tr4w.inc}

(*
  WHERE A PASSWORD LIVES: IN THE OPERATING SYSTEM'S VAULT, AND NOWHERE ELSE.

  ------------------------------------------------------------------------
  THE ONE RULE
  ------------------------------------------------------------------------

  THE SETTINGS FILE HOLDS A REFERENCE, NEVER A SECRET. A file that is
  screen-shared, synced to cloud backup, attached to a bug report or copied
  to another machine carries no password -- not in the clear, and not
  enciphered either.

  Copying a configuration to a second machine therefore yields "the secret is
  not available here, ask the operator" rather than handing the password over
  with it. That is the correct outcome and not a shortcoming.

  ------------------------------------------------------------------------
  AND NO WEAKER FALLBACK. THIS UNIT USED TO HAVE ONE.
  ------------------------------------------------------------------------

  It kept a cipher and a per-installation key file for platforms with no
  vault. That is deleted, on NY4I's design advice, and the advice was right
  twice over:

    * A store that is unavailable is a REASON TO SAY SO, not a reason to
      write the password somewhere weaker. An operator whose keyring is
      locked should be told, not quietly downgraded.

    * It was not free. The key had to be hashed, and FPC 3.2.2's HMACSHA1
      corrupts the heap for a key longer than 64 bytes -- a defect that cost
      most of a session to find because the damage surfaced far from its
      cause. Deleting the fallback deletes the exposure to it.

  So where there is no vault, a password is simply not persisted and the
  operator is asked once per session. An encrypted file with a passphrase the
  OPERATOR supplies is a possible later feature; it is a different thing from
  a key we hide on their behalf, and it needs its own decision.

  ------------------------------------------------------------------------
  THE BACKENDS
  ------------------------------------------------------------------------

  Windows   Credential Manager           uKeychainWindows   -- built
  macOS     Keychain Services            uKeychainMac       -- not yet
  Linux     Secret Service / libsecret   uKeychainLinux     -- not yet

  A backend is installed by BEING LISTED in the program's unit list. Nothing
  selects one at run time, so a platform that has none gets the honest answer
  from KeychainAvailable rather than a silent substitute.

  The tests install an in-memory backend, so a test run never reads or writes
  the machine's real vault.

  ------------------------------------------------------------------------
  WHAT THIS DOES NOT PROTECT AGAINST
  ------------------------------------------------------------------------

  A vault protects a secret at rest and between user accounts. It does not
  protect against something already running as the logged-on user, which can
  simply ask the vault as we do. Saying so here keeps anyone from assuming
  more than is true.
*)

interface

uses
   SysUtils;

const
   (* The stored form names its own scheme, so a value written by one build
     is still READ by a build that prefers a different one -- changing the
     mechanism later costs a re-save, not a migration of everyone's file.

     Written out rather than derived, so renaming anything in code cannot
     orphan values already stored under the old name. *)
   KEYCHAIN_SCHEME_PLAIN = 'plain';

type
   (*
     WHAT HAPPENED, rather than whether it worked. The four want four
     different responses: a secret that is simply absent means ask the
     operator; a locked or missing vault means do NOT overwrite anything;
     a refusal means this account cannot reach the store.
   *)
   TKeychainStatus = (
      ksOk,             (* stored, fetched or removed as asked *)
      ksNotFound,       (* no such secret -- an ordinary first run *)
      ksUnavailable,    (* no vault on this platform, or it is locked *)
      ksAccessDenied,   (* the vault is there and said no *)
      ksError           (* anything else, and it is reported *)
   );

   (*
     ONE VAULT.

     aName IDENTIFIES THE SETTING, not the value -- a stable key such as the
     property path. It is what an operator sees when they go to revoke a
     password, which is why it is a readable path and not an opaque id.
   *)
   TKeychainBackend = class(TObject)
   public
      (* The tag this backend writes into the settings file. *)
      function Scheme: string; virtual; abstract;
      (* Is the vault reachable right now? A locked keyring answers False. *)
      function Available: boolean; virtual; abstract;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         virtual; abstract;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; virtual; abstract;
      (* REMOVING MATTERS AS MUCH AS STORING. Clearing a password must not
        leave the old one in the vault for an operator to find later. *)
      function DeleteSecret(const aName: string): TKeychainStatus;
         virtual; abstract;
   end;

   (*
     TOLD, NOT GUESSED AT. Assigned by the application to its logger.

     NEVER PASS THE VALUE TO IT. The message names the SETTING and what went
     wrong. Nothing here puts a secret in a message, an exception or a
     command line -- a log ends up in bug reports.
   *)
   TKeychainNotice = procedure(const aName, aMessage: string);

(* Install the vault this build uses. The last one installed wins, which is
  what lets a platform unit take over simply by being listed. *)
procedure RegisterKeychainBackend(const aBackend: TKeychainBackend);

(* Where this unit reports a failure. See TKeychainNotice. *)
procedure SetKeychainNotice(const aNotice: TKeychainNotice);

(* IS THERE A VAULT AT ALL? False on a platform with no backend and on one
  whose keyring is locked or absent. A caller that needs to explain why a
  password cannot be saved asks this. *)
function KeychainAvailable: boolean;

(* The scheme that will be written, for the startup log line and for the
  test that pins which one a platform gets. *)
function ActiveKeychainScheme: string;

(*
  TURN A PASSWORD INTO WHAT GOES IN THE SETTINGS FILE.

  An EMPTY secret REMOVES it: there is nothing to keep, the file gets an
  empty string, and the vault entry goes with it rather than lingering.

  IF THERE IS NO VAULT the value is NOT persisted and the caller is told.
  The result is empty, which reads back as "ask the operator".
*)
function ProtectSecret(const aName, aPlain: string): string;

(*
  AND BACK AGAIN. False means the value could not be read -- an absent or
  revoked credential, a settings file from another machine, no vault here --
  and aPlain is empty. It must never quietly substitute anything.
*)
function UnprotectSecret(const aName, aStored: string;
                         out aPlain: string): boolean;

(* Does this look like a reference to a stored secret rather than a bare
  password? Used by the lint that keeps secrets out of the repository, and by
  the import that tells a legacy plaintext value from a converted one. *)
function IsProtectedSecret(const aStored: string): boolean;

(* The scheme tag on a stored value, or '' when it carries none. *)
function SecretSchemeOf(const aStored: string): string;

(* FOR TESTS ONLY. Installs an in-memory vault, so a suite can pin the round
  trip, the removal and the not-found case without touching the machine's
  real one. *)
procedure InstallTestKeychain;

implementation

uses
   Classes;

type
   TBackendList = array of TKeychainBackend;

var
   GBackends: TBackendList;
   GActive: TKeychainBackend = nil;
   GNotice: TKeychainNotice = nil;

procedure SetKeychainNotice(const aNotice: TKeychainNotice);
begin
   GNotice := aNotice;
end;

procedure Report(const aName, aMessage: string);
begin
   if Assigned(GNotice) then
      begin
      GNotice(aName, aMessage);
      end;
end;

(* For the notice text. Not translated: it goes to the log, not the screen. *)
function StatusText(const aStatus: TKeychainStatus): string;
begin
   case aStatus of
      ksOk:           Result := 'succeeded';
      ksNotFound:     Result := 'holds no such secret';
      ksUnavailable:  Result := 'is unavailable or locked';
      ksAccessDenied: Result := 'refused access';
   else
      Result := 'failed';
   end;
end;

procedure RegisterKeychainBackend(const aBackend: TKeychainBackend);
var
   i: integer;
begin
   if aBackend = nil then
      begin
      Exit;
      end;

   (* REGISTERING A SCHEME TWICE REPLACES IT, so a unit that re-registers
     cannot leave two objects claiming one tag. *)
   for i := 0 to High(GBackends) do
      begin
      if GBackends[i].Scheme = aBackend.Scheme then
         begin
         GBackends[i].Free;
         GBackends[i] := aBackend;
         GActive := aBackend;
         Exit;
         end;
      end;

   SetLength(GBackends, Length(GBackends) + 1);
   GBackends[High(GBackends)] := aBackend;
   GActive := aBackend;
end;

function KeychainAvailable: boolean;
begin
   Result := (GActive <> nil) and GActive.Available;
end;

function ActiveKeychainScheme: string;
begin
   if GActive = nil then
      begin
      Result := KEYCHAIN_SCHEME_PLAIN;
      end
   else
      begin
      Result := GActive.Scheme;
      end;
end;

function SecretSchemeOf(const aStored: string): string;
var
   colon: integer;
   i: integer;
begin
   Result := '';
   colon := Pos(':', aStored);
   if colon < 2 then
      begin
      Exit;
      end;

   Result := Copy(aStored, 1, colon - 1);
   if UnicodeSameText(Result, KEYCHAIN_SCHEME_PLAIN) then
      begin
      Exit;
      end;
   for i := 0 to High(GBackends) do
      begin
      if UnicodeSameText(GBackends[i].Scheme, Result) then
         begin
         Exit;
         end;
      end;

   (* A COLON IS NOT A TAG. A password may contain one, and a legacy value
     that looks like 'http://x' must not be taken for a scheme nobody has
     ever written. *)
   Result := '';
end;

function IsProtectedSecret(const aStored: string): boolean;
var
   scheme: string;
begin
   scheme := SecretSchemeOf(aStored);
   Result := (scheme <> '') and
             (not UnicodeSameText(scheme, KEYCHAIN_SCHEME_PLAIN));
end;

function ProtectSecret(const aName, aPlain: string): string;
var
   status: TKeychainStatus;
begin
   Result := '';

   if aPlain = '' then
      begin
      (* CLEARED MEANS REMOVED. Leaving the old value in the vault would let
        an operator who deleted a password still find it there. A vault that
        does not have it is not an error. *)
      if GActive <> nil then
         begin
         status := GActive.DeleteSecret(aName);
         if not (status in [ksOk, ksNotFound]) then
            begin
            Report(aName, 'could not be removed: the secret store '
                          + StatusText(status) + '.');
            end;
         end;
      Exit;
      end;

   if GActive = nil then
      begin
      (* NO VAULT ON THIS PLATFORM YET -- macOS and Linux, today. NOT written
        anywhere weaker: see the unit header. *)
      Report(aName, 'cannot be saved: this build has no secret store for '
                    + 'this platform, so the value is kept for this session '
                    + 'only and will be asked for again.');
      Exit;
      end;

   status := GActive.WriteSecret(aName, aPlain);
   if status = ksOk then
      begin
      (* THE FILE GETS A REFERENCE, NOT A SECRET. *)
      Result := GActive.Scheme + ':' + aName;
      Exit;
      end;

   Report(aName, 'cannot be saved: the secret store ' + StatusText(status)
                 + '. The value is kept for this session only and will be '
                 + 'asked for again.');
end;

function UnprotectSecret(const aName, aStored: string;
                         out aPlain: string): boolean;
var
   scheme: string;
   reference: string;
   status: TKeychainStatus;
   i: integer;
begin
   aPlain := '';
   if aStored = '' then
      begin
      Result := True;
      Exit;
      end;

   scheme := SecretSchemeOf(aStored);
   if scheme = '' then
      begin
      (* AN UNTAGGED VALUE IS A PASSWORD FROM BEFORE ANY OF THIS, and reading
        it as itself is what keeps an existing settings file working. It is
        moved into the vault by the next save. *)
      aPlain := aStored;
      Result := True;
      Exit;
      end;

   reference := Copy(aStored, Length(scheme) + 2, Length(aStored));

   if UnicodeSameText(scheme, KEYCHAIN_SCHEME_PLAIN) then
      begin
      aPlain := reference;
      Result := True;
      Exit;
      end;

   (* EVERY REGISTERED SCHEME IS TRIED, not just the active one -- which is
     what makes changing the writing scheme a re-save and not a migration. *)
   for i := 0 to High(GBackends) do
      begin
      if UnicodeSameText(GBackends[i].Scheme, scheme) then
         begin
         (* THE REFERENCE IS THE NAME IT WAS FILED UNDER, used in preference
           to aName so a setting renamed in code still finds its secret. *)
         status := GBackends[i].ReadSecret(reference, aPlain);
         Result := status = ksOk;
         if not Result then
            begin
            aPlain := '';
            Report(aName, 'could not be read back: the secret store '
                          + StatusText(status)
                          + '. The setting reads empty and the value will '
                          + 'have to be entered again.');
            end;
         Exit;
         end;
      end;

   (* A SCHEME THIS BUILD DOES NOT HAVE -- a settings file from a newer
     build, or from a platform whose vault is not linked here. *)
   Report(aName, 'was stored by a scheme this build does not have ("'
                 + scheme + '"), so it cannot be read here.');
   Result := False;
end;

(* ===================================================================== *)
(* THE TEST VAULT                                                        *)
(* ===================================================================== *)

type
   (*
     AN IN-MEMORY VAULT, FOR TESTS ONLY.

     A suite that touched the machine's real credential store would depend on
     the developer's machine and could leave entries behind on it -- the same
     reason the UDP broadcaster takes its transport by injection.
   *)
   TMemoryKeychain = class(TKeychainBackend)
   private
      FItems: TStringList;
   public
      constructor Create;
      destructor Destroy; override;
      function Scheme: string; override;
      function Available: boolean; override;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         override;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; override;
      function DeleteSecret(const aName: string): TKeychainStatus; override;
   end;

constructor TMemoryKeychain.Create;
begin
   inherited Create;
   FItems := TStringList.Create;
   (* Names are property paths, and Pascal does not distinguish their case --
     so neither does this, which is also how the Windows vault behaves. *)
   FItems.CaseSensitive := False;
end;

destructor TMemoryKeychain.Destroy;
begin
   FItems.Free;
   inherited Destroy;
end;

function TMemoryKeychain.Scheme: string;
begin
   Result := 'memory1';
end;

function TMemoryKeychain.Available: boolean;
begin
   Result := True;
end;

function TMemoryKeychain.WriteSecret(const aName,
                                     aValue: string): TKeychainStatus;
begin
   FItems.Values[AnsiString(aName)] := AnsiString(aValue);
   Result := ksOk;
end;

function TMemoryKeychain.ReadSecret(const aName: string;
                                    out aValue: string): TKeychainStatus;
var
   idx: integer;
begin
   aValue := '';
   idx := FItems.IndexOfName(AnsiString(aName));
   if idx < 0 then
      begin
      Result := ksNotFound;
      Exit;
      end;
   aValue := string(FItems.ValueFromIndex[idx]);
   Result := ksOk;
end;

function TMemoryKeychain.DeleteSecret(const aName: string): TKeychainStatus;
var
   idx: integer;
begin
   idx := FItems.IndexOfName(AnsiString(aName));
   if idx < 0 then
      begin
      Result := ksNotFound;
      Exit;
      end;
   FItems.Delete(idx);
   Result := ksOk;
end;

procedure InstallTestKeychain;
begin
   RegisterKeychainBackend(TMemoryKeychain.Create);
end;

end.
