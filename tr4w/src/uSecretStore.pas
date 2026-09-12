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
unit uSecretStore;
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
            better is installed -- see TSecretProtector below.

  tr4w1     Blowfish from the FPC RTL, a per-installation key, Base64 for
            JSON. The portable scheme: identical code on all three targets,
            no new library binding, and no key compiled into the program.

  wincred1  The Windows Credential Manager holds the secret and the settings
            file holds only a reference to it. Installed by uSecretStoreWin
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
   SECRET_SCHEME_PLAIN = 'plain';
   SECRET_SCHEME_BLOWFISH = 'tr4w1';

type
   (*
     ONE SCHEME. A descendant knows how to write its own form and read it
     back, and nothing else about it is public.

     Protect MAY REFUSE by returning False -- a credential manager can be
     unavailable, a key file unwritable -- and the caller then falls back to
     the next scheme rather than losing the operator's password. Losing a
     typed password because a store was busy is worse than storing it
     plainly, and the operator is told which happened.
   *)
   TSecretProtector = class(TObject)
   public
      (* The tag this protector writes. *)
      function Scheme: string; virtual; abstract;
      (* aName identifies the SETTING, not the value -- a stable key such as
        the property path. A store that keeps secrets outside the file needs
        something to file them under; one that encrypts in place ignores it. *)
      function Protect(const aName, aPlain: string;
                       out aStored: string): boolean; virtual; abstract;
      function Unprotect(const aName, aPayload: string;
                         out aPlain: string): boolean; virtual; abstract;
   end;

(* Install the protector this build writes with. The LAST one installed wins,
  which is what lets uSecretStoreWin take over on Windows simply by being in
  the program's unit list. Reading is unaffected: every scheme ever
  registered is still tried on the way in. *)
procedure RegisterSecretProtector(const aProtector: TSecretProtector);

(* The scheme that will be WRITTEN, for the log line at startup and for the
  test that pins which one a platform gets. *)
function ActiveSecretScheme: string;

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
procedure InstallFixedKeyProtectorForTesting(const aKey: string);

type
   TSecretPathFunc = function: string;

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
procedure SetSecretKeyPathProvider(const aProvider: TSecretPathFunc);

(* The file the portable scheme keys itself from. NEVER COMMIT ONE -- and
  Lint-NoSecrets fails the build rather than trusting that sentence. *)
function SecretKeyFileName: string;

implementation

uses
   Classes,
   StrUtils,   (* PosEx -- splitting our own payload *)
   uFileText,  (* whole-file read/write -- see the note in CurrentKey *)
   uAppPaths,  (* SettingsFilePath -- see SecretKeyFileName *)
   BlowFish,   (* fcl-base -- the RTL's own cipher, no binding to anything *)
   Base64,     (* fcl-base -- JSON holds text, the cipher makes bytes *)
   HMAC;       (* the hash package -- tells a wrong key from a right one *)

type
   TProtectorList = array of TSecretProtector;

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
   GActive: TSecretProtector = nil;

procedure RegisterSecretProtector(const aProtector: TSecretProtector);
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

function ActiveSecretScheme: string;
begin
   if GActive = nil then
      begin
      Result := SECRET_SCHEME_PLAIN;
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
   if UnicodeSameText(Result, SECRET_SCHEME_PLAIN) then
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
   Result := (scheme <> '') and (not UnicodeSameText(scheme, SECRET_SCHEME_PLAIN));
end;

function ProtectSecret(const aName, aPlain: string): string;
begin
   if aPlain = '' then
      begin
      Result := '';
      Exit;
      end;

   if (GActive <> nil) and GActive.Protect(aName, aPlain, Result) then
      begin
      Result := GActive.Scheme + ':' + Result;
      Exit;
      end;

   (* NO PROTECTOR, OR ONE THAT REFUSED. The password is kept, tagged for
     what it is, so the next save with a working store converts it and the
     lint can see that an unprotected secret exists. *)
   Result := SECRET_SCHEME_PLAIN + ':' + aPlain;
end;

function UnprotectSecret(const aName, aStored: string;
                         out aPlain: string): boolean;
var
   scheme: string;
   payload: string;
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

   if UnicodeSameText(scheme, SECRET_SCHEME_PLAIN) then
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
         Result := GProtectors[i].Unprotect(aName, payload, aPlain);
         if not Result then
            begin
            aPlain := '';
            end;
         Exit;
         end;
      end;

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
   TBlowfishProtector = class(TSecretProtector)
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
                       out aStored: string): boolean; override;
      function Unprotect(const aName, aPayload: string;
                         out aPlain: string): boolean; override;
   end;

var
   GKeyPathProvider: TSecretPathFunc = nil;

procedure SetSecretKeyPathProvider(const aProvider: TSecretPathFunc);
begin
   GKeyPathProvider := aProvider;
end;

function SecretKeyFileName: string;
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

  SysUtils.CreateGUID is the most random thing the RTL offers on every
  target this program builds for, and four of them is far more material than
  Blowfish's key schedule consumes. This is not a cryptographic RNG and the
  scheme's honest description above does not claim it is. *)
function NewKeyMaterial: string;
var
   g: TGUID;
   i: integer;
begin
   Result := '';
   for i := 1 to 4 do
      begin
      CreateGUID(g);
      Result := Result + GUIDToString(g);
      end;
   Result := StringReplace(Result, '{', '', [rfReplaceAll]);
   Result := StringReplace(Result, '}', '', [rfReplaceAll]);
   Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

constructor TBlowfishProtector.Create;
begin
   inherited Create;
   FKey := '';
   FKeyIsFixed := False;
end;

constructor TBlowfishProtector.Create(const aFixedKey: string);
begin
   inherited Create;
   FKey := aFixedKey;
   FKeyIsFixed := True;
end;

function TBlowfishProtector.Scheme: string;
begin
   Result := SECRET_SCHEME_BLOWFISH;
end;

function TBlowfishProtector.CurrentKey: string;
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
   if FileTextExists(SecretKeyFileName) then
      begin
      FKey := Trim(ReadAllTextUTF8(SecretKeyFileName));
      end;

   if FKey = '' then
      begin
      FKey := NewKeyMaterial;
      ForceDirectories(ExtractFilePath(SecretKeyFileName));
      WriteAllTextUTF8(SecretKeyFileName, FKey);
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
begin
   (* BOTH ARGUMENTS ARE BYTES TO HMAC, so they are narrowed EXPLICITLY and
     the plaintext goes through UTF-8 first -- a password with a non-ASCII
     character must hash the same on every machine, which an implicit
     conversion through the local codepage would not guarantee. *)
   digest := HMACSHA1(AnsiString(aKey), UTF8Encode(aPlain));
   Result := string(Copy(digest, 1, 16));
end;

function TBlowfishProtector.Protect(const aName, aPlain: string;
                                    out aStored: string): boolean;
var
   ms: TBytesStream;
   enc: TBlowFishEncryptStream;
   bytes: TBytes;
   key: string;
begin
   Result := False;
   aStored := '';
   try
      key := CurrentKey;
      if key = '' then
         begin
         Exit;
         end;

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
      Result := True;
   except
      (* A KEY FILE THAT CANNOT BE WRITTEN IS NOT FATAL. ProtectSecret falls
        back to storing the password plainly and tagged, which the operator
        can see and the lint can find. *)
      on E: Exception do
         begin
         Result := False;
         end;
   end;
end;

function TBlowfishProtector.Unprotect(const aName, aPayload: string;
                                      out aPlain: string): boolean;
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
   Result := False;
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
         Exit;
         end;

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
         aPlain := '';
         Exit;
         end;

      Result := True;
   except
      on E: Exception do
         begin
         aPlain := '';
         Result := False;
         end;
   end;
end;

procedure InstallFixedKeyProtectorForTesting(const aKey: string);
begin
   RegisterSecretProtector(TBlowfishProtector.Create(aKey));
end;

initialization
   (* THE PORTABLE SCHEME IS ALWAYS AVAILABLE, and is the one that writes
     unless a platform unit registers something better. uSecretStoreWin does
     exactly that on Windows. *)
   RegisterSecretProtector(TBlowfishProtector.Create);

end.
