unit uExternalLoggerConfig;
{$I tr4w.inc}

interface

uses
   Classes, SysUtils, Generics.Collections, uJSON;

type
   TExternalLoggerDefinition = class
   public
      Id, Name, ProviderId: string;
      Address, URL, Account, Logbook: string;
      ApiKey, Password: string;
      Port: integer;
      LegacyWRL: boolean;
      LegacySecretPending: boolean;
      ApiKeyProtected, PasswordProtected: boolean;
      constructor Create;
      procedure Assign(const aOther: TExternalLoggerDefinition);
      function DeliveryId: string;
      function DestinationFingerprint: string;
      function ToJSON: TJSONObject;
      procedure LoadJSON(const aObject: TJSONObject);
   end;

   TExternalLoggerConfig = class
   private
      FDefinitions: TObjectList<TExternalLoggerDefinition>;
      FActive: TStringList;
      FPresent: boolean;
      FError: string;
      procedure ReadJSON(const aRoot: TJSONObject);
   public
      constructor Create;
      destructor Destroy; override;
      procedure Clear;
      procedure Assign(const aOther: TExternalLoggerConfig);
      function Find(const aId: string): TExternalLoggerDefinition;
      function Validate(out aError: string): boolean;
      procedure LoadJSON(const aRoot: TJSONObject);
      procedure SaveJSON(const aRoot: TJSONObject);
      property Definitions: TObjectList<TExternalLoggerDefinition> read FDefinitions;
      property ActiveIds: TStringList read FActive;
      property Present: boolean read FPresent write FPresent;
      property Error: string read FError;
   end;

implementation

uses
   uKeychain, uKeychainJSON, uSHA256, uDefinitionId;

function SecretName(const aId, aField: string): string;
begin
   Result := 'ExternalLoggers/' + aId + '/' + aField;
end;

constructor TExternalLoggerDefinition.Create;
begin
   inherited Create;
   Id := NewDefinitionId;
end;

function TExternalLoggerDefinition.DeliveryId: string;
begin
   (* Credentials/name/order are not destination identity. Changing an endpoint
      leaves its old outbox parked rather than replaying it to another server. *)
   Result := ProviderId + '/' + Id + '/' + DestinationFingerprint;
end;

function TExternalLoggerDefinition.DestinationFingerprint: string;
begin
   Result := string(SHA256OfBytes(UTF8Encode(URL + #0 + LowerCase(Trim(Address)) +
      #0 + string(IntToStr(Port)) + #0 + Account + #0 + Logbook)));
end;

procedure TExternalLoggerDefinition.Assign(const aOther: TExternalLoggerDefinition);
begin
   Id := aOther.Id;
   Name := aOther.Name;
   ProviderId := aOther.ProviderId;
   Address := aOther.Address;
   Port := aOther.Port;
   URL := aOther.URL;
   Account := aOther.Account;
   Logbook := aOther.Logbook;
   ApiKey := aOther.ApiKey;
   Password := aOther.Password;
   LegacyWRL := aOther.LegacyWRL;
   LegacySecretPending := aOther.LegacySecretPending;
   ApiKeyProtected := aOther.ApiKeyProtected;
   PasswordProtected := aOther.PasswordProtected;
end;

function TExternalLoggerDefinition.ToJSON: TJSONObject;
begin
   Result := TJSONObject.Create;
   Result.AddPair('id', Id);
   Result.AddPair('name', Name);
   Result.AddPair('provider', ProviderId);
   Result.AddPair('address', Address);
   Result.AddPair('port', TJSONNumber.Create(Port));
   Result.AddPair('url', URL);
   Result.AddPair('account', Account);
   Result.AddPair('logbook', Logbook);
   Result.AddPair('legacyWRL', TJSONBool.Create(LegacyWRL));
   if (ApiKey <> '') or ApiKeyProtected then
      begin
      AddProtectedPassword(Result, 'apiKey', SecretName(Id, 'ApiKey'), ApiKey, ApiKeyProtected);
      end;
   if (Password <> '') or PasswordProtected then
      begin
      AddProtectedPassword(Result, 'password', SecretName(Id, 'Password'), Password, PasswordProtected);
      end;
   ApiKeyProtected := Result.GetValue('apiKey' + KEYCHAIN_REF_SUFFIX) <> nil;
   PasswordProtected := Result.GetValue('password' + KEYCHAIN_REF_SUFFIX) <> nil;
   if ApiKeyProtected then
      begin
      LegacySecretPending := False;
      end;
   if LegacySecretPending and (Result.GetValue('apiKey' + KEYCHAIN_REF_SUFFIX) = nil) then
      begin
      Result.AddPair('legacySecretPending', TJSONBool.Create(True));
      end;
end;

procedure TExternalLoggerDefinition.LoadJSON(const aObject: TJSONObject);
begin
   Id := JSONGetStr(aObject, 'id', '');
   Name := JSONGetStr(aObject, 'name', '');
   ProviderId := UpperCase(JSONGetStr(aObject, 'provider', ''));
   Address := JSONGetStr(aObject, 'address', '');
   Port := JSONGetInt(aObject, 'port', 0);
   URL := JSONGetStr(aObject, 'url', '');
   Account := JSONGetStr(aObject, 'account', '');
   Logbook := JSONGetStr(aObject, 'logbook', '');
   LegacyWRL := (aObject.GetValue('legacyWRL') <> nil) and
      aObject.GetValue('legacyWRL').AsBoolean;
   ApiKey := ReadProtectedPassword(aObject, 'apiKey', SecretName(Id, 'ApiKey'));
   Password := ReadProtectedPassword(aObject, 'password', SecretName(Id, 'Password'));
   ApiKeyProtected := aObject.GetValue('apiKey' + KEYCHAIN_REF_SUFFIX) <> nil;
   PasswordProtected := aObject.GetValue('password' + KEYCHAIN_REF_SUFFIX) <> nil;
   LegacySecretPending := (aObject.GetValue('legacySecretPending') <> nil) and
      aObject.GetValue('legacySecretPending').AsBoolean;
   if LegacySecretPending and (ApiKey = '') then
      begin
      (* A locked legacy vault must not lose its only reference during upgrade. *)
      FetchSecret('ExternalLogger.ApiKey', ApiKey);
      end;
end;

constructor TExternalLoggerConfig.Create;
begin
   inherited Create;
   FDefinitions := TObjectList<TExternalLoggerDefinition>.Create(True);
   FActive := TStringList.Create;
   FActive.CaseSensitive := True;
end;

destructor TExternalLoggerConfig.Destroy;
begin
   FActive.Free;
   FDefinitions.Free;
   inherited Destroy;
end;

procedure TExternalLoggerConfig.Clear;
begin
   FDefinitions.Clear;
   FActive.Clear;
   FPresent := False;
   FError := '';
end;

function TExternalLoggerConfig.Find(const aId: string): TExternalLoggerDefinition;
var
   definition: TExternalLoggerDefinition;
begin
   Result := nil;
   for definition in FDefinitions do
      begin
      if definition.Id = aId then
         begin
         Result := definition;
         Exit;
         end;
      end;
end;

procedure TExternalLoggerConfig.Assign(const aOther: TExternalLoggerConfig);
var
   definition, copy: TExternalLoggerDefinition;
begin
   Clear;
   FPresent := aOther.Present;
   FError := aOther.Error;
   for definition in aOther.Definitions do
      begin
      copy := TExternalLoggerDefinition.Create;
      copy.Assign(definition);
      FDefinitions.Add(copy);
      end;
   FActive.Assign(aOther.ActiveIds);
end;

function TExternalLoggerConfig.Validate(out aError: string): boolean;
var
   i, j: integer;
begin
   Result := False;
   aError := '';
   if FError <> '' then
      begin
      aError := FError;
      Exit;
      end;
   for i := 0 to FDefinitions.Count - 1 do
      begin
      if (Trim(FDefinitions[i].Id) = '') or
         (Trim(FDefinitions[i].Name) = '') or
         (Trim(FDefinitions[i].ProviderId) = '') then
         begin
         aError := 'Every external logger needs an ID, name and provider';
         Exit;
         end;
      for j := 0 to i - 1 do
         begin
         if (FDefinitions[j].Id = FDefinitions[i].Id) or
            UnicodeSameText(FDefinitions[j].Name, FDefinitions[i].Name) then
            begin
            aError := 'External logger IDs and names must be unique';
            Exit;
            end;
         end;
      end;
   for i := 0 to FActive.Count - 1 do
      begin
      if (Find(string(FActive[i])) = nil) or (FActive.IndexOf(FActive[i]) <> i) then
         begin
         aError := 'Active external loggers must name distinct existing definitions';
         Exit;
         end;
      end;
   Result := True;
end;

procedure TExternalLoggerConfig.LoadJSON(const aRoot: TJSONObject);
begin
   try
      ReadJSON(aRoot);
   except
      on E: Exception do
         begin
         Clear;
         FPresent := True;
         FError := UTF8Decode(E.Message);
         end;
   end;
end;

procedure TExternalLoggerConfig.ReadJSON(const aRoot: TJSONObject);
var
   value: TJSONValue;
   definitions, active: TJSONArray;
   definition: TExternalLoggerDefinition;
   i: integer;
   error: string;
begin
   Clear;
   value := aRoot.GetValue('externalLoggers');
   FPresent := value <> nil;
   if not FPresent then
      begin
      Exit;
      end;
   if not (value is TJSONArray) then
      begin
      raise EConvertError.Create('externalLoggers must be an array');
      end;
   definitions := TJSONArray(value);
   for i := 0 to definitions.Count - 1 do
      begin
      if not (definitions.Items[i] is TJSONObject) then
         begin
         raise EConvertError.Create('External logger definition must be an object');
         end;
      definition := TExternalLoggerDefinition.Create;
      FDefinitions.Add(definition);
      definition.LoadJSON(TJSONObject(definitions.Items[i]));
      end;
   value := aRoot.GetValue('activeExternalLoggerIds');
   if (value <> nil) and not (value is TJSONArray) then
      begin
      raise EConvertError.Create('activeExternalLoggerIds must be an array');
      end;
   if value is TJSONArray then
      begin
      active := TJSONArray(value);
      for i := 0 to active.Count - 1 do
         begin
         FActive.Add(AnsiString(JSONText(active.Items[i])));
         end;
      end;
   if not Validate(error) then
      begin
      raise EConvertError.Create(UTF8Encode(error));
      end;
end;

procedure TExternalLoggerConfig.SaveJSON(const aRoot: TJSONObject);
var
   definitions, active: TJSONArray;
   definition: TExternalLoggerDefinition;
   id: AnsiString;
begin
   (* SaveConfig overlays only emitted sections, preserving an invalid section
      on disk while other libraries remain editable and local logging works. *)
   if not FPresent or (FError <> '') then
      begin
      Exit;
      end;
   definitions := TJSONArray.Create;
   active := TJSONArray.Create;
   for definition in FDefinitions do
      begin
      definitions.AddElement(definition.ToJSON);
      end;
   for id in FActive do
      begin
      active.AddElement(TJSONString.Create(string(id)));
      end;
   aRoot.AddPair('externalLoggers', definitions);
   aRoot.AddPair('activeExternalLoggerIds', active);
end;

end.
