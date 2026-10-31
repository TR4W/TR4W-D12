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
unit uKeychainLinux;
{$I tr4w.inc}

(*
  THE FREEDESKTOP SECRET SERVICE AS TR4W'S SECRET STORE ON LINUX.

  ------------------------------------------------------------------------
  WHAT IT TALKS TO
  ------------------------------------------------------------------------

  The Secret Service is a D-Bus API, served by GNOME Keyring, KeePassXC,
  KWallet (5.97 and later) and others. libsecret is its client library.
  Entries appear in the desktop's password manager (Seahorse, "Passwords
  and Keys") under the label TR4W/<setting>, which is where an operator would
  look to revoke one, and carry two attributes:

      service = TR4W/v1                 the same namespace as Windows
      account = <SETTING NAME, UPPER>   folded the way Windows folds it

  ------------------------------------------------------------------------
  WHY A RAW BINDING, AND WHY IT IS LOADED AT RUN TIME
  ------------------------------------------------------------------------

  CLAUDE.md asks every raw call to carry its justification. This one's:

    * FPC SHIPS NO BINDING for libsecret or the Secret Service, and the LCL
      has no credential store. There is no FPC class to prefer.

    * IT IS LOADED WITH dynlibs, NOT LINKED. A link-time dependency would
      make the whole program refuse to START on a machine without libsecret
      -- a minimal install, a server, a container -- to protect one feature.
      Loaded at run time, a missing library is one log line and the old
      behaviour: the password is kept for the session and asked for again.

    * IT IS LOADED LAZILY, on the first secret operation, not in the
      initialization section. A run that never touches a password -- a
      headless export, a CI job -- never touches D-Bus.

    * THE "v" ENTRY POINTS, NOT THE CONVENIENT ONES.
      secret_password_store_sync and its siblings are C VARARGS (attribute
      name/value pairs ended by NULL), and a varargs call from Pascal is the
      kind of thing that works on one ABI and corrupts the stack on another.
      secret_password_storev_sync / lookupv_sync / clearv_sync take the
      attributes as a GHashTable instead, which is an ordinary fixed
      signature. The table is built with three glib calls from
      libglib-2.0.so.0, which is already in the process (gtk2 links it), so
      loading it by name hands back the instance that is there.

  THE LIBRARY NAMES ARE OWNED BY THE CONST BLOCK BELOW AND NOWHERE ELSE, so
  the packaging can find what it has to carry or document.

  ------------------------------------------------------------------------
  WHAT EACH FAILURE MEANS
  ------------------------------------------------------------------------

    library missing            ksUnavailable, reported once with the name
    no session bus / no
      secret service running   ksUnavailable (a GDBus or GIO error)
    collection locked          ksLocked      (SECRET_ERROR_IS_LOCKED)
    unlock prompt dismissed    ksLocked      (G_IO_ERROR_CANCELLED)
    no such entry              ksNotFound

  NOTHING IS WRITTEN ANYWHERE WEAKER in any of these. See uKeychain.

  ------------------------------------------------------------------------
  WHAT IS NOT VERIFIED, AND IS ON THE BENCH QUEUE
  ------------------------------------------------------------------------

  This unit is compiled only for Linux and no Windows build can run it. The
  record layout of SecretSchema (592 bytes on x86_64), the error codes and
  the behaviour of a DISMISSED prompt are taken from libsecret's headers
  and documentation, not measured. In particular a lookup whose unlock
  prompt is dismissed MAY come back as "nothing, and no error", which this
  unit cannot tell apart from "no such entry". docs/BENCH_QUEUE.md has the
  real-run checks.

  THREADING: libsecret's _sync calls run their own main context and block
  the caller. They are made from wherever uKeychain is called, which is the
  settings load and save on the main thread. The lazy load is not guarded
  for concurrent first use for the same reason.
*)

interface

(* Nothing. The initialization section is the unit. *)

implementation

{$IFDEF LINUX}
uses
   SysUtils,
   ctypes,
   dynlibs,
   uKeychain;

(* THE C LAYOUT, for SecretSchema and GError. Local to this unit. *)
{$PACKRECORDS C}

const
   (* ------------------------------------------------------------------
     THE SHIPPED-OR-REQUIRED LIBRARY NAMES FOR THIS PLATFORM'S VAULT.
     Owned here and nowhere else; the AppImage build reads this list.
     ------------------------------------------------------------------ *)
   SECRET_LIB = 'libsecret-1.so.0';
   GLIB_LIB   = 'libglib-2.0.so.0';

   (* The tag uKeychain reports as the active scheme. *)
   BACKEND_NAME = 'libsecret1';

   (* libsecret's own values, from secret-schema.h and secret-types.h. *)
   SECRET_SCHEMA_NONE             = 0;
   SECRET_SCHEMA_ATTRIBUTE_STRING = 0;
   SECRET_ERROR_IS_LOCKED         = 2;
   SECRET_ERROR_NO_SUCH_OBJECT    = 3;

   (* gio's, from gioenums.h. Compared by number because gio is not loaded:
     its error domain is found by NAME through g_quark_try_string. *)
   G_IO_ERROR_PERMISSION_DENIED = 14;
   G_IO_ERROR_CANCELLED         = 19;

   (* The C strings the schema and the attribute table point at. Typed
     constants, so they live for the life of the process. *)
   SCHEMA_NAME:     PAnsiChar = 'net.tr4w.Secret';
   ATTR_SERVICE:    PAnsiChar = 'service';
   ATTR_ACCOUNT:    PAnsiChar = 'account';
   SERVICE_VALUE:   PAnsiChar = 'TR4W/v1';
   QUARK_GIO:       PAnsiChar = 'g-io-error-quark';
   QUARK_GDBUS:     PAnsiChar = 'g-dbus-error-quark';

   (* The label shown in the desktop's password manager is this plus the
     setting's own spelling. *)
   LABEL_PREFIX = 'TR4W/';

type
   (* gboolean is a C int, NOT a Pascal Boolean. *)
   gboolean = cint;
   GQuark   = cuint32;

   PGError  = ^TGError;
   PPGError = ^PGError;
   TGError = record
      domain:  GQuark;
      code:    cint;
      message: PAnsiChar;
   end;

   TSecretSchemaAttribute = record
      name:     PAnsiChar;
      attrType: cint;
   end;

   (* secret-schema.h. 32 attribute slots, ended by the first nil name, and
     after them reserved space the library owns. *)
   PSecretSchema = ^TSecretSchema;
   TSecretSchema = record
      name:       PAnsiChar;
      flags:      cint;
      attributes: array[0..31] of TSecretSchemaAttribute;
      reserved:   cint;
      reserved1:  Pointer;
      reserved2:  Pointer;
      reserved3:  Pointer;
      reserved4:  Pointer;
      reserved5:  Pointer;
      reserved6:  Pointer;
      reserved7:  Pointer;
   end;

   (* THE RAW BINDINGS. Each is justified in the unit header: no FPC
     binding exists, and the varargs-free "v" forms are the ones callable
     with a fixed signature. All cdecl. *)
   TSecretPasswordStorevSync = function(aSchema: PSecretSchema;
                                        aAttributes: Pointer;
                                        aCollection: PAnsiChar;
                                        aLabel: PAnsiChar;
                                        aPassword: PAnsiChar;
                                        aCancellable: Pointer;
                                        aError: PPGError): gboolean; cdecl;
   TSecretPasswordLookupvSync = function(aSchema: PSecretSchema;
                                         aAttributes: Pointer;
                                         aCancellable: Pointer;
                                         aError: PPGError): PAnsiChar; cdecl;
   TSecretPasswordClearvSync = function(aSchema: PSecretSchema;
                                        aAttributes: Pointer;
                                        aCancellable: Pointer;
                                        aError: PPGError): gboolean; cdecl;
   TSecretPasswordFree = procedure(aPassword: PAnsiChar); cdecl;

   TGHashTableNew = function(aHashFunc: Pointer;
                             aEqualFunc: Pointer): Pointer; cdecl;
   (* Returns a gboolean since glib 2.40 and nothing before it; the result
     is not read, so declaring it a procedure is right for both. *)
   TGHashTableInsert = procedure(aTable: Pointer;
                                 aKey: Pointer;
                                 aValue: Pointer); cdecl;
   TGHashTableUnref = procedure(aTable: Pointer); cdecl;
   TGErrorFree = procedure(aError: PGError); cdecl;
   TGQuarkTryString = function(aName: PAnsiChar): GQuark; cdecl;
   (* libsecret's own error domain, asked of libsecret rather than guessed
     from the string it happens to register it under. *)
   TSecretErrorGetQuark = function: GQuark; cdecl;

   TLinuxKeychain = class(TKeychainBackend)
   public
      function Name: string; override;
      function Available: boolean; override;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         override;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; override;
      function DeleteSecret(const aName: string): TKeychainStatus; override;
   end;

var
   GLoadTried: boolean = False;
   GLoaded:    boolean = False;
   GSecretLib: TLibHandle = NilHandle;
   GGlibLib:   TLibHandle = NilHandle;
   GSchema:    TSecretSchema;

   secret_password_storev_sync:  TSecretPasswordStorevSync = nil;
   secret_password_lookupv_sync: TSecretPasswordLookupvSync = nil;
   secret_password_clearv_sync:  TSecretPasswordClearvSync = nil;
   secret_password_free:         TSecretPasswordFree = nil;
   g_hash_table_new:             TGHashTableNew = nil;
   g_hash_table_insert:          TGHashTableInsert = nil;
   g_hash_table_unref:           TGHashTableUnref = nil;
   g_error_free:                 TGErrorFree = nil;
   g_quark_try_string:           TGQuarkTryString = nil;
   secret_error_get_quark:       TSecretErrorGetQuark = nil;
   (* Not called by us: handed to g_hash_table_new as the table's own hash
     and equality functions, so only their addresses are needed. *)
   g_str_hash_address:           Pointer = nil;
   g_str_equal_address:          Pointer = nil;

(* One symbol, or its name added to the list of what is missing. *)
function Resolve(const aLib: TLibHandle;
                 const aSymbol: AnsiString;
                 var aMissing: string): Pointer;
begin
   Result := GetProcedureAddress(aLib, aSymbol);
   if Result = nil then
      begin
      if aMissing <> '' then
         begin
         aMissing := aMissing + ', ';
         end;
      aMissing := aMissing + string(aSymbol);
      end;
end;

procedure InitSchema;
begin
   GSchema := Default(TSecretSchema);
   GSchema.name := SCHEMA_NAME;
   GSchema.flags := SECRET_SCHEMA_NONE;
   GSchema.attributes[0].name := ATTR_SERVICE;
   GSchema.attributes[0].attrType := SECRET_SCHEMA_ATTRIBUTE_STRING;
   GSchema.attributes[1].name := ATTR_ACCOUNT;
   GSchema.attributes[1].attrType := SECRET_SCHEMA_ATTRIBUTE_STRING;
   (* attributes[2].name is nil from the FillChar, which ends the list. *)
end;

(*
  LOAD BOTH LIBRARIES AND EVERY SYMBOL, ALL OR NOTHING, ONCE.

  No D-Bus round trip happens here: whether a secret service is RUNNING is
  learnt from the first real call, which is where the operator's desktop may
  also put up an unlock prompt.

  NEVER UNLOADED. glib is shared with the widget set, and libsecret holds
  D-Bus state; the process exit is the only safe time.
*)
function EnsureLoaded: boolean;
var
   missing: string;
begin
   if GLoadTried then
      begin
      Result := GLoaded;
      Exit;
      end;
   GLoadTried := True;
   Result := False;

   GSecretLib := LoadLibrary(UnicodeString(SECRET_LIB));
   if GSecretLib = NilHandle then
      begin
      ReportKeychainDetail('',
         'the Secret Service library ' + SECRET_LIB + ' could not be loaded, '
         + 'so no password can be kept on this machine between sessions. '
         + 'Install libsecret (package libsecret-1-0) and a secret service '
         + 'such as GNOME Keyring or KeePassXC.');
      Exit;
      end;

   GGlibLib := LoadLibrary(UnicodeString(GLIB_LIB));
   if GGlibLib = NilHandle then
      begin
      ReportKeychainDetail('',
         GLIB_LIB + ' could not be loaded, so the Secret Service cannot be '
         + 'used and no password can be kept between sessions.');
      Exit;
      end;

   missing := '';
   @secret_password_storev_sync :=
      Resolve(GSecretLib, 'secret_password_storev_sync', missing);
   @secret_password_lookupv_sync :=
      Resolve(GSecretLib, 'secret_password_lookupv_sync', missing);
   @secret_password_clearv_sync :=
      Resolve(GSecretLib, 'secret_password_clearv_sync', missing);
   @secret_password_free :=
      Resolve(GSecretLib, 'secret_password_free', missing);
   @secret_error_get_quark :=
      Resolve(GSecretLib, 'secret_error_get_quark', missing);
   @g_hash_table_new :=
      Resolve(GGlibLib, 'g_hash_table_new', missing);
   @g_hash_table_insert :=
      Resolve(GGlibLib, 'g_hash_table_insert', missing);
   @g_hash_table_unref :=
      Resolve(GGlibLib, 'g_hash_table_unref', missing);
   @g_error_free :=
      Resolve(GGlibLib, 'g_error_free', missing);
   @g_quark_try_string :=
      Resolve(GGlibLib, 'g_quark_try_string', missing);
   g_str_hash_address := Resolve(GGlibLib, 'g_str_hash', missing);
   g_str_equal_address := Resolve(GGlibLib, 'g_str_equal', missing);

   if missing <> '' then
      begin
      ReportKeychainDetail('',
         'the Secret Service library loaded but lacks ' + missing
         + ', so it is not used and no password can be kept between '
         + 'sessions.');
      Exit;
      end;

   InitSchema;
   GLoaded := True;
   Result := True;
end;

(* The account attribute: the setting's name folded to upper case, exactly
  as uKeychainWindows folds its target name. *)
function AccountFor(const aName: string): UTF8String;
begin
   Result := UTF8Encode(UpperCase(aName));
end;

(* The two attributes, as the GHashTable the "v" calls take. The STRINGS
  ARE NOT COPIED: aAccount must outlive the table, which the callers
  guarantee by holding it in a local until after g_hash_table_unref. *)
function NewAttributes(const aAccount: UTF8String): Pointer;
begin
   Result := g_hash_table_new(g_str_hash_address, g_str_equal_address);
   g_hash_table_insert(Result, ATTR_SERVICE, SERVICE_VALUE);
   g_hash_table_insert(Result, ATTR_ACCOUNT, PAnsiChar(aAccount));
end;

function TextOf(const aUtf8: PAnsiChar): string;
var
   raw: RawByteString;
begin
   raw := aUtf8;
   Result := UTF8Decode(raw);
end;

(* A domain quark, or 0 when that domain has never been registered in this
  process -- in which case no error can be in it. *)
function DomainIs(const aError: PGError; const aDomainName: PAnsiChar): boolean;
var
   quark: GQuark;
begin
   quark := g_quark_try_string(aDomainName);
   Result := (quark <> 0) and (aError^.domain = quark);
end;

(*
  WHICH FAILURE, AND SAY WHAT THE STORE SAID. The message is the Secret
  Service's or D-Bus's own text, which names a problem and never carries the
  value. The error is freed here.
*)
function StatusFromError(const aName: string;
                         var aError: PGError): TKeychainStatus;
begin
   if aError = nil then
      begin
      Result := ksError;
      Exit;
      end;

   if aError^.domain = secret_error_get_quark() then
      begin
      case aError^.code of
         SECRET_ERROR_IS_LOCKED:
            begin
            Result := ksLocked;
            end;
         SECRET_ERROR_NO_SUCH_OBJECT:
            begin
            Result := ksNotFound;
            end;
      else
         Result := ksError;
      end;
      end
   else if DomainIs(aError, QUARK_GIO) then
      begin
      case aError^.code of
         G_IO_ERROR_CANCELLED:
            begin
            (* The operator dismissed the unlock prompt. *)
            Result := ksLocked;
            end;
         G_IO_ERROR_PERMISSION_DENIED:
            begin
            Result := ksAccessDenied;
            end;
      else
         (* No session bus, or one that cannot be autolaunched -- a
           headless session. *)
         Result := ksUnavailable;
      end;
      end
   else if DomainIs(aError, QUARK_GDBUS) then
      begin
      (* The bus is there and nothing on it serves org.freedesktop.secrets. *)
      Result := ksUnavailable;
      end
   else
      begin
      Result := ksError;
      end;

   if aError^.message <> nil then
      begin
      ReportKeychainDetail(aName, 'Secret Service: ' + TextOf(aError^.message));
      end;
   g_error_free(aError);
   aError := nil;
end;

function TLinuxKeychain.Name: string;
begin
   Result := BACKEND_NAME;
end;

function TLinuxKeychain.Available: boolean;
begin
   (* WHETHER THE LIBRARY IS THERE, not whether a service is running or the
     collection is unlocked: those are learnt from a real call, which may
     put up a prompt, and asking "is it there" must never do that. *)
   Result := EnsureLoaded;
end;

function TLinuxKeychain.WriteSecret(const aName,
                                    aValue: string): TKeychainStatus;
var
   account: UTF8String;
   labelText: UTF8String;
   secret: UTF8String;
   attributes: Pointer;
   err: PGError;
   stored: gboolean;
begin
   if not EnsureLoaded then
      begin
      Result := ksUnavailable;
      Exit;
      end;

   account := AccountFor(aName);
   labelText := UTF8Encode(LABEL_PREFIX + aName);
   secret := UTF8Encode(aValue);
   err := nil;

   attributes := NewAttributes(account);
   try
      (* A nil collection is the default one ("login" on GNOME). Storing
        with the same attributes REPLACES the entry, which is how CredWriteW
        behaves on Windows. *)
      stored := secret_password_storev_sync(@GSchema, attributes, nil,
                                            PAnsiChar(labelText),
                                            PAnsiChar(secret), nil, @err);
   finally
      g_hash_table_unref(attributes);
   end;

   if stored <> 0 then
      begin
      Result := ksOk;
      Exit;
      end;

   if err = nil then
      begin
      (* FALSE WITH NO ERROR is what a dismissed prompt is believed to give
        -- not verified, see the unit header. Locked is the honest reading:
        nothing was stored, and it is not a missing service. *)
      Result := ksLocked;
      Exit;
      end;

   Result := StatusFromError(aName, err);
end;

function TLinuxKeychain.ReadSecret(const aName: string;
                                   out aValue: string): TKeychainStatus;
var
   account: UTF8String;
   attributes: Pointer;
   err: PGError;
   found: PAnsiChar;
begin
   aValue := '';
   if not EnsureLoaded then
      begin
      Result := ksUnavailable;
      Exit;
      end;

   account := AccountFor(aName);
   err := nil;

   attributes := NewAttributes(account);
   try
      found := secret_password_lookupv_sync(@GSchema, attributes, nil, @err);
   finally
      g_hash_table_unref(attributes);
   end;

   if found <> nil then
      begin
      try
         aValue := TextOf(found);
      finally
         (* secret_password_free wipes the buffer before freeing it. *)
         secret_password_free(found);
      end;
      Result := ksOk;
      Exit;
      end;

   if err = nil then
      begin
      (* NOTHING AND NO ERROR is libsecret's "no such entry". *)
      Result := ksNotFound;
      Exit;
      end;

   Result := StatusFromError(aName, err);
end;

function TLinuxKeychain.DeleteSecret(const aName: string): TKeychainStatus;
var
   account: UTF8String;
   attributes: Pointer;
   err: PGError;
   removed: gboolean;
begin
   if not EnsureLoaded then
      begin
      Result := ksUnavailable;
      Exit;
      end;

   account := AccountFor(aName);
   err := nil;

   attributes := NewAttributes(account);
   try
      removed := secret_password_clearv_sync(@GSchema, attributes, nil, @err);
   finally
      g_hash_table_unref(attributes);
   end;

   if removed <> 0 then
      begin
      Result := ksOk;
      Exit;
      end;

   if err = nil then
      begin
      (* FALSE AND NO ERROR means there was nothing to remove. *)
      Result := ksNotFound;
      Exit;
      end;

   Result := StatusFromError(aName, err);
end;

{$ENDIF}

{$IFDEF LINUX}
initialization
   (* REGISTERING LOADS NOTHING. The library is opened on the first secret
     operation -- see EnsureLoaded. *)
   RegisterKeychainBackend(TLinuxKeychain.Create);
{$ENDIF}

end.
