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
unit uSecretStoreWin;
{$I tr4w.inc}

(*
  THE WINDOWS CREDENTIAL MANAGER AS TR4W'S SECRET STORE.

  ------------------------------------------------------------------------
  WHY THIS IS A SEPARATE UNIT
  ------------------------------------------------------------------------

  The same reason uCrashLogLCL is separate from uCrashLog: the question is
  not which COMPILER is building, it is which PLATFORM the program is for,
  and a unit graph answers that where a conditional inside one unit only
  pretends to. uSecretStore stays RTL-only and links anywhere -- the unit
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

interface

(* Nothing. The initialization section is the unit. *)

implementation

uses
   SysUtils,
   Windows,
   JwaWinCred,
   uSecretStore;

const
   (* The tag written into settings\tr4w.json. Versioned, so a later change
     to what the payload means is a new tag rather than a silent
     reinterpretation of values already on operators' machines. *)
   SCHEME_WINCRED = 'wincred1';

   (* The prefix every entry carries in Credential Manager, so an operator
     can find and revoke TR4W's credentials as a group. *)
   TARGET_PREFIX = 'TR4W/';

type
   TWinCredProtector = class(TSecretProtector)
   public
      function Scheme: string; override;
      function Protect(const aName, aPlain: string;
                       out aStored: string): boolean; override;
      function Unprotect(const aName, aPayload: string;
                         out aPlain: string): boolean; override;
   end;

(* UPPER-CASED DELIBERATELY -- see the note on case at the top. *)
function TargetFor(const aName: string): UnicodeString;
begin
   Result := UnicodeString(UpperCase(TARGET_PREFIX + aName));
end;

function TWinCredProtector.Scheme: string;
begin
   Result := SCHEME_WINCRED;
end;

function TWinCredProtector.Protect(const aName, aPlain: string;
                                   out aStored: string): boolean;
var
   cred: CREDENTIALW;
   target: UnicodeString;
   user: UnicodeString;
   blob: UnicodeString;
begin
   aStored := '';
   Result := False;

   target := TargetFor(aName);
   blob := UnicodeString(aPlain);
   (* The user name is not a secret and is not what we are storing; it is
     what Credential Manager shows beside the entry. Naming the setting
     there is what makes the list readable to an operator. *)
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
     machine the operator logs in to -- the opposite of what storing it
     locally is for. *)
   cred.Persist := CRED_PERSIST_LOCAL_MACHINE;

   if CredWriteW(@cred, 0) then
      begin
      (* THE FILE GETS A NAME, NOT A SECRET. *)
      aStored := aName;
      Result := True;
      end;
end;

function TWinCredProtector.Unprotect(const aName, aPayload: string;
                                     out aPlain: string): boolean;
var
   p: PCREDENTIALW;
   target: UnicodeString;
   chars: integer;
begin
   aPlain := '';
   Result := False;

   (* THE PAYLOAD IS THE NAME THE VALUE WAS FILED UNDER, and it is used in
     preference to aName so that a setting renamed in code can still find a
     credential stored under the old path. *)
   if aPayload <> '' then
      begin
      target := TargetFor(aPayload);
      end
   else
      begin
      target := TargetFor(aName);
      end;

   if not CredReadW(PWideChar(target), CRED_TYPE_GENERIC, 0, p) then
      begin
      (* AN ABSENT CREDENTIAL IS NOT A CRASH AND NOT A GUESS. The operator
        may have revoked it in Control Panel, or the settings file may have
        come from another machine. Either way the setting reads empty and is
        asked for again. *)
      Exit;
      end;

   try
      chars := p^.CredentialBlobSize div SizeOf(WideChar);
      SetLength(aPlain, chars);
      if chars > 0 then
         begin
         Move(p^.CredentialBlob^, aPlain[1], chars * SizeOf(WideChar));
         end;
      Result := True;
   finally
      CredFree(p);
   end;
end;

initialization
   (* LAST ONE INSTALLED WINS THE WRITING, and uSecretStore's own portable
     scheme is still registered -- so a settings file written before this
     existed, or on another platform, still reads. *)
   RegisterSecretProtector(TWinCredProtector.Create);

end.
