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
unit uKeychainMac;
{$I tr4w.inc}
(* DELPHI MODE DOES NOT ACCEPT AN EXTERNAL VARIABLE without this switch --
  `var x: T; external name '_x'` is a syntax error there, measured with
  FPC 3.2.2. The kSec* keys below are external variables. A mode switch has
  to come before any uses clause, so it is here and not inside the
  platform guard; it changes nothing on the other two platforms. *)
{$MODESWITCH CVAR}

(*
  THE macOS KEYCHAIN AS TR4W'S SECRET STORE.

  ------------------------------------------------------------------------
  WHAT IT WRITES
  ------------------------------------------------------------------------

  One GENERIC PASSWORD item per secret in the operator's login keychain:

      service (kSecAttrService)  TR4W/v1                  the namespace
      account (kSecAttrAccount)  <SETTING NAME, UPPER>    folded as Windows
      label   (kSecAttrLabel)    TR4W/<setting>           what Keychain
                                                          Access shows

  Keychain Access -> login -> Passwords lists them under that label, which
  is where an operator would look to revoke one. Deleting one there is
  supported: the read answers "not found" and TR4W asks again.

  ------------------------------------------------------------------------
  WHY A RAW BINDING
  ------------------------------------------------------------------------

  CLAUDE.md asks every raw call to carry its justification. This one's:

    * FPC 3.2.2's univint, which binds CoreFoundation and much of Security,
      has NO SecItem functions and none of the kSec* attribute keys --
      checked against packages/univint/src, not assumed. The LCL has no
      credential store. So the four SecItem functions and the keys are
      declared here, with the framework linked by directive.

    * THE NAMES ARE SPELLED TWO WAYS, AND THAT IS NOT A TYPO. A cdecl
      function's external name gets Darwin's C prefix '_' from FPC itself,
      so it is written WITHOUT one ('SecItemAdd' links as _SecItemAdd). An
      external VARIABLE gets no prefix, so it is written WITH one
      ('_kSecClass'). univint writes '_' on its functions too, but it is
      compiled under {$calling mwpascal}, which adds no prefix -- copying
      its spelling onto a cdecl declaration gave __SecItemAdd and an
      undefined-symbol link failure (FPC 3.2.2 aarch64-darwin, CI run
      41243138359). Both spellings were then measured on mac-ci with a
      probe that linked, ran, and read every key back as its framework
      string (kSecClass = "class", kSecAttrService = "svce", ...).

    * EVERYTHING ELSE IS univint's. Dictionaries, strings, data and
      CFRelease come from MacOSAll, which the Cocoa widget set already
      links, rather than being re-bound by hand.

    * IT IS A SYSTEM FRAMEWORK. Security.framework is part of every macOS
      install, so linking it costs nothing to bundle, and a link-time
      binding is right here where a run-time one is right on Linux.

  ------------------------------------------------------------------------
  THE LOGIN KEYCHAIN, DELIBERATELY NOT THE DATA PROTECTION KEYCHAIN
  ------------------------------------------------------------------------

  kSecUseDataProtectionKeychain is NOT set. The data protection keychain
  needs a keychain-access-groups entitlement and, outside the App Store, a
  provisioning profile; the hardened-runtime Developer ID signing this tree
  uses has neither, and every call would fail with errSecMissingEntitlement.
  The login keychain needs no entitlement.

  ITS ACCESS IS TIED TO THE CODE SIGNATURE. An item created by one signed
  build is readable without a prompt by a later build with the same
  Developer ID. A build signed differently -- an ad-hoc local build -- gets
  macOS's own "wants to use your confidential information" prompt. That is
  the operating system asking the operator, and it is correct.

  ------------------------------------------------------------------------
  WHAT IS NOT VERIFIED
  ------------------------------------------------------------------------

  Compiled only for macOS; nothing on Windows can build or run it. The
  OSStatus mapping below follows SecBase.h; which status a LOCKED keychain
  gives when its prompt is dismissed is on docs/BENCH_QUEUE.md.
*)

interface

(* Nothing. The initialization section is the unit. *)

implementation

{$IFDEF DARWIN}
uses
   MacOSAll,
   SysUtils,
   uKeychain;

(* THE ONE LIBRARY THIS PLATFORM'S VAULT NEEDS, named here and nowhere
  else. A system framework: nothing to bundle. *)
{$linkframework Security}

const
   (* The tag uKeychain reports as the active scheme. *)
   BACKEND_NAME = 'keychain1';

   (* The same namespace uKeychainWindows writes as its target prefix. *)
   SERVICE_NAME = 'TR4W/v1';
   LABEL_PREFIX = 'TR4W/';

   (* SecBase.h's errSecMissingEntitlement. Newer than FPC 3.2.2's univint,
     so declared here with its documented value. *)
   ERR_SEC_MISSING_ENTITLEMENT = -34018;

(* THE RAW BINDINGS -- see the unit header for why each is here. The keys
  are CFStringRef constants exported by Security.framework. *)
var kSecClass: CFStringRef; external name '_kSecClass';
var kSecClassGenericPassword: CFStringRef; external name '_kSecClassGenericPassword';
var kSecAttrService: CFStringRef; external name '_kSecAttrService';
var kSecAttrAccount: CFStringRef; external name '_kSecAttrAccount';
var kSecAttrLabel: CFStringRef; external name '_kSecAttrLabel';
var kSecValueData: CFStringRef; external name '_kSecValueData';
var kSecReturnData: CFStringRef; external name '_kSecReturnData';
var kSecMatchLimit: CFStringRef; external name '_kSecMatchLimit';
var kSecMatchLimitOne: CFStringRef; external name '_kSecMatchLimitOne';

(* No leading '_' on these four: cdecl adds it. See the unit header. *)
function SecItemAdd(aAttributes: CFDictionaryRef;
                    aResult: Pointer): OSStatus;
   cdecl; external name 'SecItemAdd';
function SecItemCopyMatching(aQuery: CFDictionaryRef;
                             aResult: Pointer): OSStatus;
   cdecl; external name 'SecItemCopyMatching';
function SecItemUpdate(aQuery: CFDictionaryRef;
                       aAttributesToUpdate: CFDictionaryRef): OSStatus;
   cdecl; external name 'SecItemUpdate';
function SecItemDelete(aQuery: CFDictionaryRef): OSStatus;
   cdecl; external name 'SecItemDelete';

type
   TMacKeychain = class(TKeychainBackend)
   public
      function Name: string; override;
      function Available: boolean; override;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         override;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; override;
      function DeleteSecret(const aName: string): TKeychainStatus; override;
   end;

(* A CFString from a native string, through UTF-8. The caller releases it. *)
function NewCFString(const aText: string): CFStringRef;
var
   utf8: UTF8String;
begin
   utf8 := UTF8Encode(aText);
   Result := CFStringCreateWithBytes(kCFAllocatorDefault, PAnsiChar(utf8),
                                     Length(utf8), kCFStringEncodingUTF8,
                                     False);
end;

(* The secret as CFData, UTF-8. The caller releases it. *)
function NewCFData(const aText: string): CFDataRef;
var
   utf8: UTF8String;
begin
   utf8 := UTF8Encode(aText);
   Result := CFDataCreate(kCFAllocatorDefault, PAnsiChar(utf8), Length(utf8));
end;

function NewDictionary: CFMutableDictionaryRef;
begin
   Result := CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                       @kCFTypeDictionaryKeyCallBacks,
                                       @kCFTypeDictionaryValueCallBacks);
end;

(* Set one entry from a native string. The dictionary RETAINS the value, so
  the string made for it is released at once. *)
procedure SetText(const aDict: CFMutableDictionaryRef;
                  const aKey: CFStringRef;
                  const aText: string);
var
   value: CFStringRef;
begin
   value := NewCFString(aText);
   try
      CFDictionarySetValue(aDict, aKey, value);
   finally
      CFRelease(value);
   end;
end;

(*
  THE QUERY THAT NAMES ONE ITEM: class, service, account. The account is
  the setting's name UPPER-CASED, exactly as uKeychainWindows folds its
  target name -- the keychain itself is case-sensitive, and without this
  two spellings of one path would be two items. The caller releases it.
*)
function NewQuery(const aName: string): CFMutableDictionaryRef;
begin
   Result := NewDictionary;
   CFDictionarySetValue(Result, kSecClass, kSecClassGenericPassword);
   SetText(Result, kSecAttrService, SERVICE_NAME);
   SetText(Result, kSecAttrAccount, UpperCase(aName));
end;

(* WHICH FAILURE IT WAS. The number is logged for anything that is not an
  ordinary answer, because it is what Apple's documentation is indexed by;
  it never carries the value. *)
function StatusFromOSStatus(const aName: string;
                            const aStatus: OSStatus): TKeychainStatus;
begin
   case aStatus of
      errSecSuccess:
         begin
         Result := ksOk;
         end;
      errSecItemNotFound:
         begin
         Result := ksNotFound;
         end;
      errSecInteractionNotAllowed, errSecUserCanceled, errSecAuthFailed:
         begin
         (* The keychain is locked and could not be unlocked: no UI was
           allowed, the operator dismissed the prompt, or the password typed
           into it was wrong. *)
         Result := ksLocked;
         end;
      errSecNotAvailable, errSecNoSuchKeychain:
         begin
         Result := ksUnavailable;
         end;
      ERR_SEC_MISSING_ENTITLEMENT:
         begin
         Result := ksAccessDenied;
         end;
   else
      Result := ksError;
   end;

   if not (Result in [ksOk, ksNotFound]) then
      begin
      ReportKeychainDetail(aName, 'macOS keychain status '
                                  + string(IntToStr(aStatus)) + '.');
      end;
end;

function TMacKeychain.Name: string;
begin
   Result := BACKEND_NAME;
end;

function TMacKeychain.Available: boolean;
begin
   (* SECURITY.FRAMEWORK IS ALWAYS THERE. Whether the keychain is UNLOCKED
     is learnt from a real call, which may put up macOS's own unlock prompt,
     and asking "is there a vault" must never do that. *)
   Result := True;
end;

function TMacKeychain.WriteSecret(const aName,
                                  aValue: string): TKeychainStatus;
var
   query: CFMutableDictionaryRef;
   changes: CFMutableDictionaryRef;
   data: CFDataRef;
   status: OSStatus;
begin
   query := NewQuery(aName);
   data := NewCFData(aValue);
   try
      (* UPDATE FIRST, ADD IF ABSENT: an existing entry is replaced, which is
        what CredWriteW does on Windows. Adding first would answer
        errSecDuplicateItem for every second save. *)
      changes := NewDictionary;
      try
         CFDictionarySetValue(changes, kSecValueData, data);
         status := SecItemUpdate(query, changes);
      finally
         CFRelease(changes);
      end;

      if status = errSecItemNotFound then
         begin
         SetText(query, kSecAttrLabel, LABEL_PREFIX + aName);
         CFDictionarySetValue(query, kSecValueData, data);
         status := SecItemAdd(query, nil);
         end;
   finally
      CFRelease(data);
      CFRelease(query);
   end;

   Result := StatusFromOSStatus(aName, status);
end;

function TMacKeychain.ReadSecret(const aName: string;
                                 out aValue: string): TKeychainStatus;
var
   query: CFMutableDictionaryRef;
   found: CFTypeRef;
   status: OSStatus;
   len: CFIndex;
   i: CFIndex;
   source: PByte;
   utf8: RawByteString;
begin
   aValue := '';
   found := nil;

   query := NewQuery(aName);
   try
      CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
      CFDictionarySetValue(query, kSecMatchLimit, kSecMatchLimitOne);
      status := SecItemCopyMatching(query, @found);
   finally
      CFRelease(query);
   end;

   Result := StatusFromOSStatus(aName, status);
   if (Result <> ksOk) or (found = nil) then
      begin
      if Result = ksOk then
         begin
         Result := ksNotFound;
         end;
      Exit;
      end;

   try
      (* THE BYTE COPY IS THE C BOUNDARY: CFData hands back a pointer and a
        length, and this is where they become a string. *)
      len := CFDataGetLength(CFDataRef(found));
      utf8 := '';
      if len > 0 then
         begin
         source := PByte(CFDataGetBytePtr(CFDataRef(found)));
         SetLength(utf8, len);
         for i := 1 to len do
            begin
            utf8[i] := AnsiChar(source^);
            inc(source);
            end;
         end;
      aValue := UTF8Decode(utf8);
   finally
      CFRelease(found);
   end;
end;

function TMacKeychain.DeleteSecret(const aName: string): TKeychainStatus;
var
   query: CFMutableDictionaryRef;
   status: OSStatus;
begin
   (* CLEARING A PASSWORD HAS TO REMOVE IT, not merely stop referring to it,
     or the operator who deleted it would still find it in Keychain Access. *)
   query := NewQuery(aName);
   try
      status := SecItemDelete(query);
   finally
      CFRelease(query);
   end;

   Result := StatusFromOSStatus(aName, status);
end;

{$ENDIF}

{$IFDEF DARWIN}
initialization
   RegisterKeychainBackend(TMacKeychain.Create);
{$ENDIF}

end.
