unit uExternalLoggerRegistry;
{$I tr4w.inc}
interface
uses SysUtils, uExternalLoggerConfig, uExternalLoggerService;
type
   TLoggerConfigField = (lcfAddress, lcfPort, lcfURL, lcfAccount, lcfLogbook,
      lcfApiKey, lcfPassword);
   TLoggerConfigFields = set of TLoggerConfigField;
   TExternalLoggerConstructor = function(const aDefinition: TExternalLoggerDefinition;
      aComputerId: AnsiChar): TExternalLoggerService;
   TExternalLoggerRegistration = record
      Id, DisplayName: string;
      Construct: TExternalLoggerConstructor;
      Fields: TLoggerConfigFields;
   end;
procedure RegisterExternalLogger(const aId, aDisplayName: string;
   aConstructor: TExternalLoggerConstructor; aFields: TLoggerConfigFields = []);
function FindExternalLoggerRegistration(const aId: string;
   out aRegistration: TExternalLoggerRegistration): boolean;
function ExternalLoggerRegistration(aIndex: integer): TExternalLoggerRegistration;
function ExternalLoggerProviderCount: integer;
function ExternalLoggerDefinitionError(const aDefinition: TExternalLoggerDefinition): string;
function CreateExternalLogger(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
implementation
var
   Providers: array of TExternalLoggerRegistration;
procedure RegisterExternalLogger(const aId, aDisplayName: string;
   aConstructor: TExternalLoggerConstructor; aFields: TLoggerConfigFields = []);
var
   i: integer;
begin
   if (aId = '') or not Assigned(aConstructor) then
      begin
      raise EArgumentException.Create('External logger registration is incomplete');
      end;
   for i := 0 to High(Providers) do
      begin
      if Providers[i].Id = UpperCase(aId) then
         begin
         raise EArgumentException.Create(UTF8Encode('Duplicate external logger provider: ' + aId));
         end;
      end;
   i := Length(Providers);
   SetLength(Providers, i + 1);
   Providers[i].Id := UpperCase(aId);
   Providers[i].DisplayName := aDisplayName;
   Providers[i].Construct := aConstructor;
   Providers[i].Fields := aFields;
end;
function FindExternalLoggerRegistration(const aId: string;
   out aRegistration: TExternalLoggerRegistration): boolean;
var
   i: integer;
begin
   Result := False;
   aRegistration := Default(TExternalLoggerRegistration);
   for i := 0 to High(Providers) do
      begin
      if Providers[i].Id = aId then
         begin
         aRegistration := Providers[i];
         Result := True;
         Exit;
         end;
      end;
end;
function ExternalLoggerProviderCount: integer;
begin
   Result := Length(Providers);
end;
function ExternalLoggerRegistration(aIndex: integer): TExternalLoggerRegistration;
begin
   Result := Providers[aIndex];
end;
function CreateExternalLogger(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
var
   i: integer;
   error: string;
begin
   error := ExternalLoggerDefinitionError(aDefinition);
   if error <> '' then
      begin
      raise EArgumentException.Create(UTF8Encode(error));
      end;
   for i := 0 to High(Providers) do
      begin
      if Providers[i].Id = aDefinition.ProviderId then
         begin
         Result := Providers[i].Construct(aDefinition, aComputerId);
         Result.DisplayName := aDefinition.Name;
         Exit;
         end;
      end;
   raise EArgumentException.Create(UTF8Encode('Unsupported external logger: ' + aDefinition.ProviderId));
end;
function ExternalLoggerDefinitionError(const aDefinition: TExternalLoggerDefinition): string;
var
   registration: TExternalLoggerRegistration;
begin
   Result := '';
   if not FindExternalLoggerRegistration(aDefinition.ProviderId, registration) then
      begin
      Result := 'Unsupported external logger: ' + aDefinition.ProviderId;
      end
   else if (lcfAddress in registration.Fields) and (Trim(aDefinition.Address) = '') then
      begin
      Result := 'Enter the external logger host or IP address';
      end
   else if (lcfPort in registration.Fields) and
      ((aDefinition.Port < 1) or (aDefinition.Port > 65535)) then
      begin
      Result := 'External logger port must be between 1 and 65535';
      end
   else if (lcfAccount in registration.Fields) and (Trim(aDefinition.Account) = '') then
      begin
      Result := 'Enter the external logger email or account ID';
      end
   else if (lcfLogbook in registration.Fields) and (Trim(aDefinition.Logbook) = '') then
      begin
      Result := 'Enter the external logger callsign or logbook ID';
      end;
end;
end.
