unit uCallbookRegistry;
{$I tr4w.inc}

(* CALLBOOK PROVIDERS REGISTER HERE (issue 321).

   Each provider unit calls RegisterCallbookProvider from its initialization
   section, so adding one touches its own unit and the uses clauses, and no
   shared file.  The registry owns the registrations; a provider DECLARES an id,
   a display name and whether it needs a login, and the factory function below
   constructs it by id.  There are no settings here on purpose: a provider that
   needs credentials gets them when one exists to need them. *)

interface

uses
   SysUtils, Generics.Collections, uCallbookBase;

type
   TCallbookProviderClass = class of TCallbookProvider;

   TCallbookRegistration = class
   public
      Id:            string;
      DisplayName:   string;
      NeedsLogin:    boolean;
      ProviderClass: TCallbookProviderClass;
   end;

procedure RegisterCallbookProvider(const aId, aDisplayName: string;
   aNeedsLogin: boolean; aClass: TCallbookProviderClass);

(* False when aId is not registered.  The registry owns aRegistration. *)
function FindCallbookRegistration(const aId: string;
   out aRegistration: TCallbookRegistration): boolean;

function CallbookProviderCount: integer;
function CallbookRegistration(aIndex: integer): TCallbookRegistration;

(* A new provider the caller frees.  Raises EArgumentException for an id that is
   not registered. *)
function CreateCallbookProvider(const aId: string): TCallbookProvider;

implementation

var
   Providers: TObjectList<TCallbookRegistration>;

procedure RegisterCallbookProvider(const aId, aDisplayName: string;
   aNeedsLogin: boolean; aClass: TCallbookProviderClass);
var
   registration: TCallbookRegistration;
   existing:     TCallbookRegistration;
begin
   if (aId = '') or (aClass = nil) then
      begin
      raise EArgumentException.Create('Callbook provider registration is incomplete');
      end;
   if FindCallbookRegistration(aId, existing) then
      begin
      raise EArgumentException.Create(UTF8Encode('Duplicate callbook provider: ' + aId));
      end;
   registration := TCallbookRegistration.Create;
   registration.Id            := LowerCase(aId);
   registration.DisplayName   := aDisplayName;
   registration.NeedsLogin    := aNeedsLogin;
   registration.ProviderClass := aClass;
   Providers.Add(registration);
end;

function FindCallbookRegistration(const aId: string;
   out aRegistration: TCallbookRegistration): boolean;
var
   i: integer;
begin
   Result := False;
   aRegistration := nil;
   for i := 0 to Providers.Count - 1 do
      begin
      if Providers[i].Id = LowerCase(aId) then
         begin
         aRegistration := Providers[i];
         Result := True;
         Exit;
         end;
      end;
end;

function CallbookProviderCount: integer;
begin
   Result := Providers.Count;
end;

function CallbookRegistration(aIndex: integer): TCallbookRegistration;
begin
   Result := Providers[aIndex];
end;

function CreateCallbookProvider(const aId: string): TCallbookProvider;
var
   registration: TCallbookRegistration;
begin
   if not FindCallbookRegistration(aId, registration) then
      begin
      raise EArgumentException.Create(UTF8Encode('Unsupported callbook provider: ' + aId));
      end;
   Result := registration.ProviderClass.Create;
   Result.Id          := registration.Id;
   Result.DisplayName := registration.DisplayName;
end;

initialization
   Providers := TObjectList<TCallbookRegistration>.Create(True);
finalization
   Providers.Free;
end.
