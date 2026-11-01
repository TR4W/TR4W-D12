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
  THE REFERENCE IS ITS OWN MEMBER, AND THAT REMOVES AN AMBIGUITY
  ------------------------------------------------------------------------

  A password that has been stored writes `<Setting>Ref`, and the value member
  is not written at all:

      "Password"    absent
      "PasswordRef" "Hamscore.Password"

  AN EARLIER VERSION PUT A TAG INSIDE THE VALUE -- scheme:reference -- and
  NY4I rejected the shape: it reads like web basic authentication, and it
  cannot be told apart from a password that simply contains a colon. There
  was a whole test explaining which way that coin was flipped.

  A SEPARATE MEMBER NAME HAS NO SUCH PROBLEM. A value under `Password` is a
  plaintext password from before this existed, and is moved into the vault on
  the next save. A value under `PasswordRef` is a reference. Nothing has to
  be guessed from the text.

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

  Windows   Credential Manager           uKeychainWindows   JwaWinCred (FPC)
  macOS     Keychain Services (SecItem)  uKeychainMac       Security.framework
  Linux     Secret Service / libsecret   uKeychainLinux     libsecret-1.so.0,
                                                            loaded at run time

  A backend is installed by BEING LISTED in the program's unit list. All
  three are listed in tr4w.lpr, and each is an empty unit on the other two
  platforms, because this tree has one program file for all of them. Nothing
  selects one at run time, so a platform that has none gets the honest answer
  from KeychainAvailable rather than a silent substitute.

  EVERY BACKEND KEYS AN ENTRY THE SAME WAY: the 'TR4W/v1' namespace plus the
  setting's name UPPER-CASED. Windows folds case itself (measured, see
  uKeychainWindows); the macOS keychain and the Secret Service do not, so
  those two fold it on the way in to keep the three identical.

  A LOCKED VAULT IS ITS OWN ANSWER, ksLocked, so the log can say "locked"
  rather than "unavailable" -- an operator can fix the first and not the
  second. Either way nothing is written anywhere weaker.

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
   (* The suffix that marks a settings member as a REFERENCE to a stored
     secret rather than a value. Spelled once, here. *)
   KEYCHAIN_REF_SUFFIX = 'Ref';

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
      ksUnavailable,    (* no vault on this platform, or it cannot be reached *)
      ksLocked,         (* the vault is there but locked, or the operator
                          dismissed the unlock prompt *)
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
      function Name: string; virtual; abstract;
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

(* FOR A BACKEND: report a detail only the backend knows -- a library that
  would not load, a platform error number, the store's own error text. It
  goes to the same notice. The same rule binds it: NEVER the value. *)
procedure ReportKeychainDetail(const aName, aMessage: string);

(* IS THERE A VAULT AT ALL? False on a platform with no backend and on one
  whose keyring is locked or absent. A caller that needs to explain why a
  password cannot be saved asks this. *)
function KeychainAvailable: boolean;

(* The scheme that will be written, for the startup log line and for the
  test that pins which one a platform gets. *)
function ActiveKeychainName: string;

(*
  PUT A PASSWORD IN THE VAULT.

  True means it is there and the caller may write the reference. False means
  it is not, and the caller must write NOTHING -- the password is kept for
  this session and asked for again. The reason is reported.

  AN EMPTY SECRET REMOVES IT. There is nothing to keep, and leaving the old
  value behind would let an operator who deleted a password still find it.
  It answers False, because nothing is stored and no reference is wanted.

  EXCEPT WHEN THIS SESSION COULD NOT READ IT. If FetchSecret failed for this
  name with anything but "not found" -- a vault locked at startup, a
  dismissed unlock prompt, an error -- the empty value is what the failed
  read left behind, not what the operator chose. Deleting would destroy a
  key nobody asked to remove. So the entry is LEFT ALONE, the fact is
  reported, and the answer is True: the entry is still there and the caller
  must keep writing its reference, or a store that looks a secret up only
  through its reference (the radio library) would never find it again.

  The cost, stated: an operator who deliberately clears such a field in the
  same session keeps the old value in the vault; the notice says so. A
  successful read of the name, a non-empty store, or ForgetSecret ends the
  exception.
*)
function StoreSecret(const aName, aPlain: string): boolean;

(*
  AND BACK OUT OF IT. False means it could not be read -- absent, revoked, a
  settings file from another machine, no vault here -- and aPlain is empty.
  It must never quietly substitute anything.
*)
function FetchSecret(const aName: string; out aPlain: string): boolean;

(* Remove one, without storing anything. For a setting being cleared by
  something other than a save -- a radio or cluster definition deleted from
  its library. It removes the entry even when this session could not read
  it: deleting the definition is an explicit instruction. *)
function ForgetSecret(const aName: string): boolean;

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

   (*
     THE NAMES THIS SESSION FAILED TO READ, for any reason but "not found".
     See StoreSecret in the interface for why they matter.

     HELD UPPER-CASED, which is how every backend keys an entry (see the unit
     header), so a name built by the saver and the same name read from the
     settings file match whatever their spelling.

     MAIN THREAD ONLY, and not locked. The only callers are the settings
     object's load and save and the radio configuration store, all on the
     main thread; a caller on another thread would need a lock here first.
   *)
   GUnreadable: TStringList = nil;

function UnreadableIndex(const aName: string): integer;
begin
   if GUnreadable = nil then
      begin
      Result := -1;
      Exit;
      end;
   Result := GUnreadable.IndexOf(AnsiString(UpperCase(aName)));
end;

procedure RememberUnreadable(const aName: string);
begin
   if UnreadableIndex(aName) >= 0 then
      begin
      Exit;
      end;
   if GUnreadable = nil then
      begin
      GUnreadable := TStringList.Create;
      end;
   GUnreadable.Add(AnsiString(UpperCase(aName)));
end;

procedure ForgetUnreadable(const aName: string);
var
   idx: integer;
begin
   idx := UnreadableIndex(aName);
   if idx >= 0 then
      begin
      GUnreadable.Delete(idx);
      end;
end;

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

procedure ReportKeychainDetail(const aName, aMessage: string);
begin
   Report(aName, aMessage);
end;

(* For the notice text. Not translated: it goes to the log, not the screen. *)
function StatusText(const aStatus: TKeychainStatus): string;
begin
   case aStatus of
      ksOk:           Result := 'succeeded';
      ksNotFound:     Result := 'holds no such secret';
      ksUnavailable:  Result := 'is unavailable';
      ksLocked:       Result := 'is locked';
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

   (* A NEW VAULT MAKES THE OLD READ FAILURES MEANINGLESS -- they were about
     a different store. In the program this runs before any read; in the
     tests it keeps one test's failures out of the next. *)
   if GUnreadable <> nil then
      begin
      GUnreadable.Clear;
      end;

   (* REGISTERING A SCHEME TWICE REPLACES IT, so a unit that re-registers
     cannot leave two objects claiming one tag. *)
   for i := 0 to High(GBackends) do
      begin
      if GBackends[i].Name = aBackend.Name then
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

function ActiveKeychainName: string;
begin
   if GActive = nil then
      begin
      Result := chr(39) + chr(39);
      end
   else
      begin
      Result := GActive.Name;
      end;
end;

function StoreSecret(const aName, aPlain: string): boolean;
var
   status: TKeychainStatus;
begin
   Result := False;

   if aPlain = '' then
      begin
      (* CLEARED MEANS REMOVED, and a vault that does not have it is not an
        error -- clearing something already absent is a no-op, not a fault. *)
      if (GActive <> nil) and (UnreadableIndex(aName) >= 0) then
         begin
         (* BUT NOT WHEN THE EMPTY VALUE IS ONLY WHAT A FAILED READ LEFT.
           See the interface comment. The entry is kept and so is its
           reference. *)
         Report(aName, 'was not removed: it could not be read this session, '
                       + 'so the empty value may be the failed read rather '
                       + 'than a choice. The stored entry is kept. To remove '
                       + 'it, clear the field again after a session in which '
                       + 'the secret store is unlocked.');
         Result := True;
         Exit;
         end;
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
      (* NO BACKEND IN THIS BUILD -- a platform none of the three units
        covers. The value is NOT written anywhere weaker: see the unit
        header. A backend that is listed but cannot reach its vault answers
        ksUnavailable below instead. *)
      Report(aName, 'cannot be saved: this build has no secret store for '
                    + 'this platform, so the value is kept for this session '
                    + 'only and will be asked for again.');
      Exit;
      end;

   status := GActive.WriteSecret(aName, aPlain);
   if status = ksOk then
      begin
      (* The operator's new value replaced whatever could not be read, so
        an empty store from here on is a real removal again. *)
      ForgetUnreadable(aName);
      Result := True;
      Exit;
      end;

   Report(aName, 'cannot be saved: the secret store ' + StatusText(status)
                 + '. The value is kept for this session only and will be '
                 + 'asked for again.');
end;

function FetchSecret(const aName: string; out aPlain: string): boolean;
var
   status: TKeychainStatus;
begin
   aPlain := '';

   if GActive = nil then
      begin
      Report(aName, 'cannot be read: this build has no secret store for this '
                    + 'platform. The setting reads empty.');
      Result := False;
      Exit;
      end;

   status := GActive.ReadSecret(aName, aPlain);
   Result := status = ksOk;

   (* WHETHER AN EMPTY SAVE MAY DELETE THIS NAME LATER. A read that worked,
     or a vault that positively has no such entry, leaves nothing to
     protect. Anything else -- locked, refused, an error -- may be hiding a
     real entry, so remember it. *)
   if status in [ksOk, ksNotFound] then
      begin
      ForgetUnreadable(aName);
      end
   else
      begin
      RememberUnreadable(aName);
      end;

   if not Result then
      begin
      (* NOTHING PLAUSIBLE IS HANDED BACK. A revoked credential and a file
        from another machine both read as absent; either way the operator is
        asked again rather than TR4W logging in somewhere with rubbish. *)
      aPlain := '';
      Report(aName, 'could not be read back: the secret store '
                    + StatusText(status)
                    + '. The setting reads empty and the value will have to '
                    + 'be entered again.');
      end;
end;

function ForgetSecret(const aName: string): boolean;
var
   status: TKeychainStatus;
begin
   if GActive = nil then
      begin
      Result := False;
      Exit;
      end;
   status := GActive.DeleteSecret(aName);
   Result := status in [ksOk, ksNotFound];
   if Result then
      begin
      ForgetUnreadable(aName);
      end;
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
      function Name: string; override;
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

function TMemoryKeychain.Name: string;
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

finalization
   GUnreadable.Free;
   GUnreadable := nil;

end.
