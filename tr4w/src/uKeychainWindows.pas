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
unit uKeychainWindows;
{$I tr4w.inc}

(*
  THE WINDOWS CREDENTIAL MANAGER AS TR4W'S SECRET STORE.

  ------------------------------------------------------------------------
  WHY THIS IS A SEPARATE UNIT
  ------------------------------------------------------------------------

  The same reason uCrashLogLCL is separate from uCrashLog: the question is
  not which COMPILER is building, it is which PLATFORM the program is for,
  and a unit graph answers that where a conditional inside one unit only
  pretends to. uKeychain stays RTL-only and links anywhere -- the unit
  tests, tr4wserver, a Linux build -- and this one is in the Windows
  program's unit list and nowhere else.

  Its whole public surface is an initialization section. Being LISTED is
  what installs it.

  ------------------------------------------------------------------------
  WHY IT IS PREFERRED WHERE IT EXISTS
  ------------------------------------------------------------------------

  THERE IS NO KEY. The portable scheme has to keep one somewhere the program
  can read, which means somewhere an attacker on that account can read; this
  has the operating system hold the secret for the logged-on user and hands
  us nothing to store, ship, hide or lose. The settings file keeps only a
  NAME, so a file that is screen-shared, synced or attached to a bug report
  carries no password at all -- not even a protected one.

  It is also the answer to "make sure the key is not in the repository"
  (NY4I, 2026-09-12), because on Windows there is no key file to leak.

  ------------------------------------------------------------------------
  IT IS NOT A THIRD-PARTY DEPENDENCY
  ------------------------------------------------------------------------

  JwaWinCred ships INSIDE FPC, in winunits-jedi -- checked, not assumed. So
  this adds no vendored library and no new file to the installer; it is a
  Win32 API boundary of exactly the kind CLAUDE.md keeps a handle for, and
  the justification is this comment.

  ------------------------------------------------------------------------
  THE TRAP, MEASURED BEFORE THIS UNIT WAS WRITTEN
  ------------------------------------------------------------------------

  TARGET NAMES ARE CASE-INSENSITIVE. A probe wrote one credential and read
  it back with a lower-cased target name; the read SUCCEEDED. So two settings
  whose names differ only in case would silently share one credential and
  overwrite each other.

  Property paths cannot collide that way -- they are Pascal identifiers, and
  Pascal does not distinguish their case either -- but relying on that
  quietly is how the bug gets in later. The target is upper-cased on the way
  in, so two spellings of one path are the same target ON PURPOSE rather
  than by luck.

  ------------------------------------------------------------------------
  WHAT AN OPERATOR SEES
  ------------------------------------------------------------------------

  The entries appear in Control Panel -> Credential Manager -> Windows
  Credentials as TR4W/<setting>, which is where someone would look to
  revoke one. Deleting an entry there is a supported thing to do: the read
  fails, the setting reads empty, and TR4W asks for the password again
  rather than using anything stale.
*)

(*
  ------------------------------------------------------------------------
  AND THE GUARD HAS TO BE HERE, BECAUSE THERE IS ONLY ONE PROGRAM FILE
  ------------------------------------------------------------------------

  The note above says this unit is "in the Windows program's unit list and
  nowhere else", and that a unit graph answers the platform question where a
  conditional inside one unit only pretends to. THAT DESCRIBES A TREE WITH A
  PROGRAM FILE PER PLATFORM, AND THIS TREE HAS ONE `tr4w.lpr` -- Windows,
  Linux and macOS all build from it. So the unit graph cannot answer it, and
  the Linux build died on `Can't find unit Windows used by uKeychainWindows`
  from 2026-09-12, when this unit was added to that list, until 2026-09-14.
  Nobody built Linux in between.

  SO THE CONDITIONAL IS REAL HERE, not a pretence: on Windows this unit is
  exactly what it was, and everywhere else it is an empty unit that registers
  nothing -- which leaves uKeychain's portable scheme as the only backend,
  which is precisely the behaviour the note above promises.

  THE ALTERNATIVE IS A PROGRAM FILE PER PLATFORM, and that is a bigger
  decision than a credential store: `tr4w.lpr` is where "which units are
  compiled" is answered for this tree, and splitting it means three copies of
  a 400-line list that would drift. If that ever happens, this guard comes
  out and the note above becomes true as written.
*)

interface

(* Nothing. The initialization section is the unit. *)

implementation

{$IFDEF WINDOWS}
uses
   SysUtils,
   Windows,
   JwaWinCred,
   uKeychain;

const
   (* The tag written into settings\tr4w.json. Versioned, so a later change
     to what the payload means is a new tag rather than a silent
     reinterpretation of values already on operators' machines. *)
   BACKEND_NAME = 'wincred1';

   (* The prefix every entry carries in Credential Manager, so an operator
     can find and revoke TR4W's credentials as a group. *)
   TARGET_PREFIX = 'TR4W/v1/';

   (* ERROR_NOT_FOUND IS NOT IN THE RTL's Windows UNIT, so it is declared
     here with its documented value rather than left to a unit that does not
     have it. 1168 is winerror.h's ERROR_NOT_FOUND, which CredReadW returns
     when the target does not exist. *)
   ERROR_NOT_FOUND = 1168;

type
   TWindowsKeychain = class(TKeychainBackend)
   public
      function Name: string; override;
      function Available: boolean; override;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         override;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; override;
      function DeleteSecret(const aName: string): TKeychainStatus; override;
   end;

(*
  THE TARGET NAME.

  IT CARRIES A VERSION -- TR4W/v1/<setting>. That costs nothing now and buys
  a clean namespace if what is stored ever changes meaning, so a later format
  cannot collide with entries an older build left behind.

  UPPER-CASED DELIBERATELY. Target names are CASE-INSENSITIVE, measured
  before this unit was written: a probe wrote one credential and read it back
  under a lower-cased name, successfully. Property paths cannot collide that
  way -- Pascal does not distinguish their case either -- but relying on that
  quietly is how the bug gets in later.
*)
function TargetFor(const aName: string): UnicodeString;
begin
   Result := UnicodeString(UpperCase(TARGET_PREFIX + aName));
end;

(* WHICH FAILURE IT WAS, because they mean different things to the caller.
  GetLastError is read IMMEDIATELY after the failing call -- anything in
  between, a logging call included, overwrites it. *)
function StatusFromLastError: TKeychainStatus;
begin
   case GetLastError of
      ERROR_NOT_FOUND:
         begin
         Result := ksNotFound;
         end;
      ERROR_ACCESS_DENIED, ERROR_PRIVILEGE_NOT_HELD:
         begin
         Result := ksAccessDenied;
         end;
      ERROR_NO_SUCH_LOGON_SESSION:
         begin
         Result := ksUnavailable;
         end;
   else
      Result := ksError;
   end;
end;

function TWindowsKeychain.Name: string;
begin
   Result := BACKEND_NAME;
end;

function TWindowsKeychain.Available: boolean;
begin
   (* THE VAULT IS PART OF THE LOGON SESSION and exists whenever there is
     one. There is no locked state to test as a Linux keyring has, so the
     honest answer on Windows is yes. *)
   Result := True;
end;

function TWindowsKeychain.WriteSecret(const aName,
                                      aValue: string): TKeychainStatus;
var
   cred: CREDENTIALW;
   target: UnicodeString;
   user: UnicodeString;
   blob: UnicodeString;
begin
   target := TargetFor(aName);
   blob := UnicodeString(aValue);
   (* The user name is not the secret; it is what Credential Manager shows
     beside the entry. Naming the setting there is what makes the list
     readable to an operator looking for what to revoke. *)
   user := UnicodeString(aName);

   FillChar(cred, SizeOf(cred), 0);
   cred.Type_ := CRED_TYPE_GENERIC;
   cred.TargetName := PWideChar(target);
   cred.UserName := PWideChar(user);
   cred.CredentialBlobSize := Length(blob) * SizeOf(WideChar);
   if Length(blob) > 0 then
      begin
      cred.CredentialBlob := PByte(PWideChar(blob));
      end;
   (* LOCAL_MACHINE, NOT ENTERPRISE. Enterprise persistence roams the
     credential with the profile, which would put the password back on every
     machine the operator logs in to -- the opposite of the point. *)
   cred.Persist := CRED_PERSIST_LOCAL_MACHINE;

   if CredWriteW(@cred, 0) then
      begin
      Result := ksOk;
      Exit;
      end;

   Result := StatusFromLastError;
end;

function TWindowsKeychain.ReadSecret(const aName: string;
                                     out aValue: string): TKeychainStatus;
var
   p: PCREDENTIALW;
   chars: integer;
begin
   aValue := '';

   if not CredReadW(PWideChar(TargetFor(aName)), CRED_TYPE_GENERIC, 0, p) then
      begin
      (* AN ABSENT CREDENTIAL IS NOT A FAULT. The operator may have revoked
        it in Control Panel, or the settings file may have come from another
        machine. NOT FOUND says exactly that, where a bare failure would read
        as something being broken. *)
      Result := StatusFromLastError;
      Exit;
      end;

   try
      chars := p^.CredentialBlobSize div SizeOf(WideChar);
      SetLength(aValue, chars);
      if chars > 0 then
         begin
         Move(p^.CredentialBlob^, aValue[1], chars * SizeOf(WideChar));
         end;
      Result := ksOk;
   finally
      CredFree(p);
   end;
end;

function TWindowsKeychain.DeleteSecret(const aName: string): TKeychainStatus;
begin
   (* CLEARING A PASSWORD HAS TO REMOVE IT, not merely stop referring to it.
     Without this, an operator who deleted a password would still find it in
     Control Panel afterwards. *)
   if CredDeleteW(PWideChar(TargetFor(aName)), CRED_TYPE_GENERIC, 0) then
      begin
      Result := ksOk;
      Exit;
      end;

   Result := StatusFromLastError;
end;

{$ENDIF}

{$IFDEF WINDOWS}
initialization
   (* LAST ONE INSTALLED WINS THE WRITING, and uKeychain's own portable
     scheme is still registered -- so a settings file written before this
     existed, or on another platform, still reads. *)
   RegisterKeychainBackend(TWindowsKeychain.Create);
{$ENDIF}

end.
