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
  WHERE A STORED PASSWORD GOES, AND WHAT COMES BACK.

  ------------------------------------------------------------------------
  THERE IS NO FPC OR LAZARUS CREDENTIAL STORE
  ------------------------------------------------------------------------

  Neither the RTL nor the LCL has one, and Lazarus ships no crypto component
  at all -- measured 2026-09-12 against this machine's FPC 3.2.2 and Lazarus
  install, not assumed. So this is not a wrapper over a framework facility;
  it is the facility, and everything below is the reasoning for its shape.

  ------------------------------------------------------------------------
  THE STORED FORM IS SELF-DESCRIBING, AND THAT IS THE WHOLE POINT
  ------------------------------------------------------------------------

      <scheme>:<payload>

  NY4I's reason for settling this before the file format froze was that
  choosing a mechanism afterwards means migrating operators' files twice.
  A scheme tag removes that: a value written by any scheme is still READ by
  the build that prefers a different one, so changing our mind later costs a
  re-save and not a migration. Every scheme this unit has ever written stays
  readable; only the WRITING side moves.

  A value with no recognised tag is a plain password from before any of this
  existed and is read as itself. That is not a fallback to be tidied away --
  it is how an existing tr4w.json keeps working.

  ------------------------------------------------------------------------
  THE SCHEMES
  ------------------------------------------------------------------------

  plain     The value, as it always was. READ, and written only when nothing
            better is installed -- see TKeychainBackend below.

  tr4w1     Blowfish from the FPC RTL, a per-installation key, Base64 for
            JSON. The portable scheme: identical code on all three targets,
            no new library binding, and no key compiled into the program.

  wincred1  The Windows Credential Manager holds the secret and the settings
            file holds only a reference to it. Installed by uKeychainWindows
            on Windows, where it is preferred because there is then NO KEY
            FILE AT ALL. See that unit.

  ------------------------------------------------------------------------
  WHAT tr4w1 PROTECTS AGAINST, STATED HONESTLY
  ------------------------------------------------------------------------

  A settings file that is screen-shared, synced to cloud backup, attached to
  a bug report or copied to another machine does not hand over the operator's
  passwords. That is a real and ordinary exposure and it is what this buys.

  IT DOES NOT PROTECT AGAINST ANYONE WITH ACCESS TO THE ACCOUNT, because the
  key sits in a file that account can read. Saying so here is deliberate: a
  scheme described as "encrypted" invites more trust than it earns.

  ------------------------------------------------------------------------
  TWO THINGS THE RTL CIPHER DOES NOT DO, BOTH MEASURED
  ------------------------------------------------------------------------

  IT CANNOT TELL YOU THE KEY WAS WRONG. Decrypting with the wrong key returns
  bytes, not an error -- proven with a probe before this unit was written. So
  the payload carries a MAC of the plaintext and Unprotect REFUSES rather than
  returning rubbish. Without it, a copied settings file would have TR4W
  logging in to a score server with a garbage password.

  IT HAS NO PADDING SCHEME, so the ciphertext is rounded up to the block size
  and the true length has to travel with it.

  Hence the payload:  tr4w1:<length>:<mac>:<base64 ciphertext>

  ------------------------------------------------------------------------
  NOTHING HERE TOUCHES A REAL STORE DURING A TEST
  ------------------------------------------------------------------------

  The protector is an injectable object. The unit tests install one that
  holds a fixed key in memory, so a test run cannot read, write or depend on
  the developer's key file or credential manager -- which is the same reason
  the UDP broadcaster takes its transport by injection.
*)

interface

uses
   SysUtils;

const
   (* The tags. Written out rather than derived, so renaming anything in code
     cannot silently orphan every value already stored under the old name --
     the same rule the UDP stream names follow. *)
   KEYCHAIN_SCHEME_PLAIN = 'plain';
   KEYCHAIN_SCHEME_LOCALFILE = 'tr4w1';

   (*
     THE LONGEST KEY THIS MAY HAND TO THE RUNTIME LIBRARY, AND IT IS A BUG
     BARRIER RATHER THAN A DESIGN CHOICE.

     FPC 3.2.2's HMACSHA1 CORRUPTS THE HEAP FOR A KEY LONGER THAN 64 BYTES.
     Measured, then read in the source (packages/hash/src/hmac.pp,
     HMACSHA1Digest): it pads two working buffers to the SHA-1 block size of
     64 bytes, then runs its mixing loop Length(AKey) times -- so a longer
     key writes past the end of both. A 128-byte key overran two blocks by 64
     bytes each.

     IT COST MOST OF A SESSION TO FIND, because the damage surfaces nowhere
     near its cause: the call returns, the value is correct, and the program
     dies later in unrelated code -- inside the JSON streamer, as it
     happened, which sent the whole investigation to the wrong unit. It was
     invisible until the probe was built with -gh.

     Blowfish takes at most 56 key bytes anyway (TBlowFishKey is
     array[0..55]), so nothing above that ever contributed to the cipher
     either. Both limits are respected by staying at 56.
   *)
   KEYCHAIN_MAX_KEY_BYTES = 56;

type
   (*
     WHAT HAPPENED, RATHER THAN WHETHER IT WORKED.

     A boolean cannot tell the four apart, and they want four different
     responses: a credential that is simply not there means ask the operator
     for it; a keyring that is locked or absent means do NOT overwrite
     anything and say so; a refusal means the account cannot reach the store.
     The first version of this unit returned a boolean and would have
     silently downgraded a locked keyring to a weaker scheme.
   *)
   TKeychainStatus = (
      ksOk,             (* stored, or fetched, as asked *)
      ksNotFound,       (* no such secret -- an ordinary first run *)
      ksUnavailable,    (* no store on this platform, or it is locked *)
      ksAccessDenied,   (* the store is there and said no *)
      ksError           (* anything else, and it is reported *)
   );

   (*
     ONE BACKEND. It knows how to write its own form and read it back, and
     nothing else about it is public.

     IT MAY REFUSE, and the refusal is a STATUS so the caller can tell a
     locked keyring from an empty one. Nothing downgrades silently: see
     ProtectSecret.
   *)
   TKeychainBackend = class(TObject)
   public
      (* The tag this backend writes. *)
      function Scheme: string; virtual; abstract;
      (* aName identifies the SETTING, not the value -- a stable key such as
        the property path.

        THE PATH AND NOT AN OPAQUE ID, deliberately. A random reference
        survives a rename, but it is what an operator sees in Credential
        Manager when they go to revoke a password, and 'secret:2f0c9a...'
        tells them nothing. A rename is handled instead by keeping the name
        in the stored payload, so the old entry is still found. *)
      function Protect(const aName, aPlain: string;
                       out aStored: string): TKeychainStatus; virtual; abstract;
      function Unprotect(const aName, aPayload: string;
                         out aPlain: string): TKeychainStatus; virtual; abstract;
   end;

   (*
     TOLD, NOT GUESSED AT. Assigned by the application to its logger.

     THE UNIT CANNOT LOG FOR ITSELF and should not: it is a leaf that the
     test binary links, and reaching for the logger would drag the logging
     framework into it. More to the point, a store this low in the tree must
     never decide what an operator is told.

     NEVER PASS THE VALUE TO IT. The reason string names the SETTING and what
     went wrong, and nothing here ever puts a secret in a message, an
     exception or a command line.
   *)
   TKeychainNotice = procedure(const aName, aMessage: string);

(* Where this unit reports a downgrade or a failure. See TKeychainNotice. *)
procedure SetKeychainNotice(const aNotice: TKeychainNotice);

(* Install the backend this build writes with. The LAST one installed wins,
  which is what lets uKeychainWindows take over on Windows simply by being in
  the program's unit list. Reading is unaffected: every scheme ever
  registered is still tried on the way in. *)
procedure RegisterKeychainBackend(const aProtector: TKeychainBackend);

(* The scheme that will be WRITTEN, for the log line at startup and for the
  test that pins which one a platform gets. *)
function ActiveKeychainScheme: string;

(*
  TURN A PASSWORD INTO WHAT GOES IN THE FILE.

  An EMPTY secret is stored as an empty string with no tag at all. There is
  nothing to protect, and an operator who has cleared a password should see
  the field empty rather than a blob that decodes to nothing -- and on a
  store that keeps secrets elsewhere, it must not leave an entry behind.
*)
function ProtectSecret(const aName, aPlain: string): string;

(*
  AND BACK AGAIN. False means the value could not be read -- a foreign key, a
  tampered payload, a credential that has been removed -- and aPlain is empty.
  The caller reports it; it must never quietly substitute rubbish.
*)
function UnprotectSecret(const aName, aStored: string;
                         out aPlain: string): boolean;

(* Does this look like a protected value rather than a bare password? Used by
  the lint that keeps protected blobs out of the repository, and by the
  import that has to tell a legacy plaintext value from a converted one. *)
function IsProtectedSecret(const aStored: string): boolean;

(* The scheme tag on a stored value, or '' when it carries none. *)
function SecretSchemeOf(const aStored: string): string;

(* FOR TESTS ONLY. Installs the portable scheme with a KNOWN key, so a suite
  can pin the round trip, the tamper check and the wrong-key refusal without
  a key file existing anywhere on the machine running it. *)
procedure InstallTestKeychain(const aKey: string);

type
   TKeychainPathFunc = function: string;

(*
  WHERE THE PORTABLE SCHEME'S KEY FILE LIVES.

  A HOOK RATHER THAN A DEPENDENCY, and the direction is the point. The honest
  answer is "beside whatever settings file this run is using", which only
  uTR4WConfigFile knows -- and asking it would drag the JSON reader, and
  everything under it, into a unit that is otherwise pure RTL. This unit has
  to stay linkable by the test binary and by a build with no settings layer
  at all, so it ANSWERS THE QUESTION ITSELF by default and lets the unit that
  really knows install a better answer.

  uTR4WConfigFile installs one in its own initialization, so a station using
  --settings keeps its key beside the file it names.
*)
procedure SetKeychainKeyPathProvider(const aProvider: TKeychainPathFunc);

(* The file the portable scheme keys itself from. NEVER COMMIT ONE -- and
  Lint-NoSecrets fails the build rather than trusting that sentence. *)
function KeychainKeyFileName: string;

implementation

uses
   Classes,
   StrUtils,   (* PosEx -- splitting our own payload *)
   uFileText,  (* whole-file read/write -- see the note in CurrentKey *)
   uAppPaths,  (* SettingsFilePath -- see KeychainKeyFileName *)
   BlowFish,   (* fcl-base -- the RTL's own cipher, no binding to anything *)
   Base64,     (* fcl-base -- JSON holds text, the cipher makes bytes *)
   HMAC;       (* the hash package -- tells a wrong key from a right one *)

type
   TProtectorList = array of TKeychainBackend;

(*
  BYTES TO A STRING AND BACK, BYTE FOR BYTE.

  NOT TEncoding.ANSI. That is a CODEPAGE CONVERSION: it maps every byte above
  127 through the machine's ANSI codepage, which is lossy and machine
  dependent -- and a ciphertext is uniformly distributed bytes, so most of it
  is above 127. A settings file written on one machine would then fail to
  decrypt on another, or on the same machine after a locale change, and the
  failure would look like a corrupted password rather than a bad conversion.

  Base64 wants an AnsiString because it is a byte-oriented codec; these two
  move the bytes into and out of one without reinterpreting any of them.
*)
function BytesToRaw(const aBytes: TBytes): AnsiString;
begin
   SetLength(Result, Length(aBytes));
   if Length(aBytes) > 0 then
      begin
      Move(aBytes[0], Result[1], Length(aBytes));
      end;
end;

function RawToBytes(const aRaw: AnsiString): TBytes;
begin
   Result := nil;
   SetLength(Result, Length(aRaw));
   if Length(aRaw) > 0 then
      begin
      Move(aRaw[1], Result[0], Length(aRaw));
      end;
end;

(* The payload's three fields. A hand split rather than TStringHelper.Split,
  which needs a mode switch this unit does not otherwise want, and which
  would hide that a password containing a colon must never reach here
  unencoded -- it cannot, because the only thing split is OUR payload. *)
function SplitPayload(const aPayload: string;
                      out aLen, aMac, aData: string): boolean;
var
   first: integer;
   second: integer;
begin
   Result := False;
   aLen := '';
   aMac := '';
   aData := '';

   first := Pos(':', aPayload);
   if first < 2 then
      begin
      Exit;
      end;
   second := PosEx(':', aPayload, first + 1);
   if second <= first + 1 then
      begin
      Exit;
      end;

   aLen  := Copy(aPayload, 1, first - 1);
   aMac  := Copy(aPayload, first + 1, second - first - 1);
   aData := Copy(aPayload, second + 1, Length(aPayload));
   Result := aData <> '';
end;

var
   GProtectors: TProtectorList;
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

procedure RegisterKeychainBackend(const aProtector: TKeychainBackend);
var
   i: integer;
begin
   if aProtector = nil then
      begin
      Exit;
      end;

   (* REGISTERING A SCHEME TWICE REPLACES IT, so a unit that re-registers
     after a reload cannot leave two objects claiming one tag. *)
   for i := 0 to High(GProtectors) do
      begin
      if GProtectors[i].Scheme = aProtector.Scheme then
         begin
         GProtectors[i].Free;
         GProtectors[i] := aProtector;
         GActive := aProtector;
         Exit;
         end;
      end;

   SetLength(GProtectors, Length(GProtectors) + 1);
   GProtectors[High(GProtectors)] := aProtector;
   GActive := aProtector;
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
   for i := 0 to High(GProtectors) do
      begin
      if UnicodeSameText(GProtectors[i].Scheme, Result) then
         begin
         Exit;
         end;
      end;

   (* A COLON IS NOT A TAG. A password may legitimately contain one, and a
     legacy plaintext value that happens to look like 'http://x' must not be
     mistaken for a scheme nobody has ever written. *)
   Result := '';
end;

function IsProtectedSecret(const aStored: string): boolean;
var
   scheme: string;
begin
   scheme := SecretSchemeOf(aStored);
   Result := (scheme <> '') and (not UnicodeSameText(scheme, KEYCHAIN_SCHEME_PLAIN));
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

function ProtectSecret(const aName, aPlain: string): string;
var
   status: TKeychainStatus;
begin
   if aPlain = '' then
      begin
      Result := '';
      Exit;
      end;

   if GActive <> nil then
      begin
      status := GActive.Protect(aName, aPlain, Result);
      if status = ksOk then
         begin
         Result := GActive.Scheme + ':' + Result;
         Exit;
         end;
      end
   else
      begin
      status := ksUnavailable;
      end;

   (*
     A DOWNGRADE IS REPORTED, NEVER SILENT.

     The first version of this simply wrote the weaker form and said nothing,
     which is the failure mode CLAUDE.md names outright: prefer a reported
     error to a silent fallback. An operator whose keyring was locked would
     have had their password written in a weaker form, on disk, with nothing
     anywhere saying so.

     THE VALUE IS STILL KEPT. Refusing to store it would lose a password the
     operator has just typed, which is worse than storing it less well -- so
     it is kept, tagged for exactly what it is, and said out loud. The tag is
     also what lets the next save with a working store convert it, and what
     Lint-NoSecrets looks for.
   *)
   Report(aName, 'the secret store ' + StatusText(status)
                 + ' -- this value is being written in a WEAKER form '
                 + '(scheme "' + KEYCHAIN_SCHEME_PLAIN + '"). It will be '
                 + 'upgraded on the next save once the store is reachable.');
   Result := KEYCHAIN_SCHEME_PLAIN + ':' + aPlain;
end;

function UnprotectSecret(const aName, aStored: string;
                         out aPlain: string): boolean;
var
   scheme: string;
   payload: string;
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
        it as itself is what keeps an existing settings file working. *)
      aPlain := aStored;
      Result := True;
      Exit;
      end;

   payload := Copy(aStored, Length(scheme) + 2, Length(aStored));

   if UnicodeSameText(scheme, KEYCHAIN_SCHEME_PLAIN) then
      begin
      aPlain := payload;
      Result := True;
      Exit;
      end;

   (* EVERY REGISTERED SCHEME IS TRIED ON THE WAY IN, not just the active one.
     That is what makes changing the writing scheme a re-save rather than a
     migration. *)
   for i := 0 to High(GProtectors) do
      begin
      if UnicodeSameText(GProtectors[i].Scheme, scheme) then
         begin
         status := GProtectors[i].Unprotect(aName, payload, aPlain);
         Result := status = ksOk;
         if not Result then
            begin
            (* NOTHING PLAUSIBLE IS HANDED BACK. A wrong key decrypts to
              bytes and a revoked credential reads as absent; either way the
              caller gets nothing and the operator is asked again, rather
              than TR4W logging in somewhere with rubbish. *)
            aPlain := '';
            Report(aName, 'could not be read back: the store '
                          + StatusText(status)
                          + '. The setting reads empty and the value will '
                          + 'have to be entered again.');
            end;
         Exit;
         end;
      end;

   (* A SCHEME THIS BUILD DOES NOT KNOW. A settings file from a newer build,
     or from a platform whose store is not linked here. *)
   Report(aName, 'was stored by a scheme this build does not have ("'
                 + scheme + '"), so it cannot be read here.');
   Result := False;
end;

(* ===================================================================== *)
(* THE PORTABLE SCHEME                                                   *)
(* ===================================================================== *)

type
   (*
     BLOWFISH FROM THE RTL, KEYED BY A FILE MADE ONCE PER INSTALLATION.

     THE KEY IS NOT IN THE PROGRAM AND MUST NEVER BE IN THE REPOSITORY.
     It is generated on first use, written beside the settings file, and
     nothing else knows it. Lint-NoSecrets fails the build if a key file or a
     protected blob is ever tracked by git.
   *)
   TLocalFileBackend = class(TKeychainBackend)
   private
      FKey: string;
      FKeyIsFixed: boolean;
      function CurrentKey: string;
   public
      constructor Create; overload;
      (* A FIXED KEY, FOR TESTS ONLY. With one of these installed nothing
        reads or writes the key file, so a test run cannot depend on the
        developer's machine or leave anything behind on it. *)
      constructor Create(const aFixedKey: string); overload;
      function Scheme: string; override;
      function Protect(const aName, aPlain: string;
                       out aStored: string): TKeychainStatus; override;
      function Unprotect(const aName, aPayload: string;
                         out aPlain: string): TKeychainStatus; override;
   end;

var
   GKeyPathProvider: TKeychainPathFunc = nil;

procedure SetKeychainKeyPathProvider(const aProvider: TKeychainPathFunc);
begin
   GKeyPathProvider := aProvider;
end;

function KeychainKeyFileName: string;
begin
   if Assigned(GKeyPathProvider) then
      begin
      Result := GKeyPathProvider();
      Exit;
      end;

   (* uAppPaths.SettingsFilePath, NOT a hand-built path from ParamStr(0).
     The first version of this line built its own and Lint-AppPaths caught
     it, which is the lint doing exactly its job: the three app directories
     are the SAME one on Windows and three DIFFERENT ones on Unix, so a
     hand-built path is correct on the platform it was written on and wrong
     on the two this scheme exists to serve.

     A key is per-operator and writable, so it is a settings file by kind. *)
   Result := SettingsFilePath('tr4w.key');
end;

(* A PRINTABLE KEY, MADE FROM GUIDs.

  SysUtils.CreateGUID is the most random thing the RTL offers on every target
  this program builds for. Two of them give 64 hex characters, of which the
  first 56 are kept -- see KEYCHAIN_MAX_KEY_BYTES for why the length is a
  hard limit and not a preference.

  This is not a cryptographic random number generator and the scheme's
  honest description above does not claim it is. *)
function NewKeyMaterial: string;
var
   g: TGUID;
   i: integer;
begin
   Result := '';
   for i := 1 to 2 do
      begin
      CreateGUID(g);
      Result := Result + GUIDToString(g);
      end;
   Result := StringReplace(Result, '{', '', [rfReplaceAll]);
   Result := StringReplace(Result, '}', '', [rfReplaceAll]);
   Result := StringReplace(Result, '-', '', [rfReplaceAll]);
   Result := Copy(Result, 1, KEYCHAIN_MAX_KEY_BYTES);
end;

constructor TLocalFileBackend.Create;
begin
   inherited Create;
   FKey := '';
   FKeyIsFixed := False;
end;

constructor TLocalFileBackend.Create(const aFixedKey: string);
begin
   inherited Create;
   FKey := aFixedKey;
   FKeyIsFixed := True;
end;

function TLocalFileBackend.Scheme: string;
begin
   Result := KEYCHAIN_SCHEME_LOCALFILE;
end;

function TLocalFileBackend.CurrentKey: string;
begin
   if FKey <> '' then
      begin
      Result := FKey;
      Exit;
      end;

   (* uFileText, NOT TStringList. That class is AnsiString-based, so loading,
     indexing and saving through it narrowed the key and the file name at
     four separate points -- four conversions the build counts, on a value
     where a lost character means an undecryptable password. uFileText reads
     and writes a whole file as a native string, which is what this is. *)
   if FileTextExists(KeychainKeyFileName) then
      begin
      FKey := Trim(ReadAllTextUTF8(KeychainKeyFileName));
      end;

   if FKey = '' then
      begin
      FKey := NewKeyMaterial;
      ForceDirectories(ExtractFilePath(KeychainKeyFileName));
      WriteAllTextUTF8(KeychainKeyFileName, FKey);
      end;

   Result := FKey;
end;

(* The tamper check. HMAC-SHA1 of the plaintext under the same key, and only
  the first bytes of it: this answers "did this decrypt correctly", which
  needs far less than a full signature, and a shorter tag keeps the stored
  value readable in a settings file. *)
function MacOf(const aKey, aPlain: string): string;
var
   digest: AnsiString;
   safeKey: AnsiString;
begin
   (* THE KEY IS BOUNDED HERE AND NOT ONLY WHERE IT IS GENERATED, because a
     key FILE written by an earlier build can be longer, and handing that to
     HMACSHA1 corrupts the heap -- see KEYCHAIN_MAX_KEY_BYTES. A bound that
     only holds for keys this build made is not a bound. *)
   safeKey := AnsiString(aKey);
   if Length(safeKey) > KEYCHAIN_MAX_KEY_BYTES then
      begin
      SetLength(safeKey, KEYCHAIN_MAX_KEY_BYTES);
      end;

   (* BOTH ARGUMENTS ARE BYTES TO HMAC, so they are narrowed EXPLICITLY and
     the plaintext goes through UTF-8 first -- a password with a non-ASCII
     character must hash the same on every machine, which an implicit
     conversion through the local codepage would not guarantee. *)
   digest := HMACSHA1(safeKey, UTF8Encode(aPlain));
   Result := string(Copy(digest, 1, 16));
end;

function TLocalFileBackend.Protect(const aName, aPlain: string;
                                  out aStored: string): TKeychainStatus;
var
   ms: TBytesStream;
   enc: TBlowFishEncryptStream;
   bytes: TBytes;
   key: string;
begin
   Result := ksError;
   aStored := '';
   try
      key := CurrentKey;
      if key = '' then
         begin
         (* THE KEY FILE COULD NOT BE READ OR MADE -- a read-only install
           directory, most likely. Unavailable, not an error: nothing is
           broken, there is just nowhere to keep a key. *)
         Result := ksUnavailable;
         Exit;
         end;
      key := Copy(key, 1, KEYCHAIN_MAX_KEY_BYTES);

      ms := TBytesStream.Create(nil);
      try
         enc := TBlowFishEncryptStream.Create(AnsiString(key), ms);
         try
            bytes := TEncoding.UTF8.GetBytes(aPlain);
            if Length(bytes) > 0 then
               begin
               enc.Write(bytes[0], Length(bytes));
               end;
         finally
            (* FREEING IS WHAT FLUSHES THE LAST BLOCK. Reading ms before this
              gives a truncated ciphertext, silently. *)
            enc.Free;
         end;

         SetLength(bytes, ms.Size);
         if ms.Size > 0 then
            begin
            Move(ms.Bytes[0], bytes[0], ms.Size);
            end;
      finally
         ms.Free;
      end;

      aStored := IntToStr(Length(TEncoding.UTF8.GetBytes(aPlain))) + ':'
                 + MacOf(key, aPlain) + ':'
                 + string(EncodeStringBase64(BytesToRaw(bytes)));
      Result := ksOk;
   except
      (* A KEY FILE THAT CANNOT BE WRITTEN IS NOT FATAL, and it is not
        silent either: ProtectSecret reports the downgrade. The exception is
        deliberately not carried into the message -- its text can name a
        path but must never be allowed to grow to carry a value. *)
      on E: Exception do
         begin
         Result := ksError;
         end;
   end;
end;

function TLocalFileBackend.Unprotect(const aName, aPayload: string;
                                    out aPlain: string): TKeychainStatus;
var
   ms: TBytesStream;
   dec: TBlowFishDecryptStream;
   raw: AnsiString;
   bytes: TBytes;
   lenText: string;
   code: integer;
   mac: string;
   data: string;
   wanted: integer;
   got: integer;
   key: string;
begin
   Result := ksError;
   aPlain := '';

   if not SplitPayload(aPayload, lenText, mac, data) then
      begin
      Exit;
      end;

   (* Val, NOT StrToIntDef. That one takes an AnsiString, so the native
     string narrows at the call -- one of the conversions the build counts,
     for a field this unit wrote itself and knows is digits. *)
   Val(lenText, wanted, code);
   if code <> 0 then
      begin
      Exit;
      end;
   if wanted < 0 then
      begin
      Exit;
      end;

   try
      key := CurrentKey;
      if key = '' then
         begin
         Result := ksUnavailable;
         Exit;
         end;
      key := Copy(key, 1, KEYCHAIN_MAX_KEY_BYTES);

      raw := DecodeStringBase64(AnsiString(data));
      bytes := RawToBytes(raw);

      ms := TBytesStream.Create(bytes);
      try
         dec := TBlowFishDecryptStream.Create(AnsiString(key), ms);
         try
            SetLength(bytes, wanted);
            if wanted > 0 then
               begin
               got := dec.Read(bytes[0], wanted);
               end
            else
               begin
               got := 0;
               end;
            SetLength(bytes, got);
            aPlain := TEncoding.UTF8.GetString(bytes);
         finally
            dec.Free;
         end;
      finally
         ms.Free;
      end;

      (* THE WRONG KEY PRODUCES BYTES, NOT AN ERROR -- so this comparison is
        the only thing standing between a copied settings file and TR4W
        logging in somewhere with rubbish. *)
      if MacOf(key, aPlain) <> mac then
         begin
         (* THE KEY IS NOT THE ONE THIS WAS WRITTEN WITH -- a settings file
           copied from another installation, which is the case this scheme
           is designed to fail on rather than decode. *)
         aPlain := '';
         Result := ksAccessDenied;
         Exit;
         end;

      Result := ksOk;
   except
      on E: Exception do
         begin
         aPlain := '';
         Result := ksError;
         end;
   end;
end;

procedure InstallTestKeychain(const aKey: string);
begin
   RegisterKeychainBackend(TLocalFileBackend.Create(aKey));
end;

initialization
   (* THE PORTABLE SCHEME IS ALWAYS AVAILABLE, and is the one that writes
     unless a platform unit registers something better. uKeychainWindows does
     exactly that on Windows. *)
   RegisterKeychainBackend(TLocalFileBackend.Create);

end.
