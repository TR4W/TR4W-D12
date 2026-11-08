unit uExternalLoggerRegistry;
(* Providers register themselves here, and DECLARE the settings they need.

   A provider does not name controls and the editor does not know providers:
   the provider hands the editor an ordered list of field descriptors (key,
   caption, kind) and the editor builds one row per descriptor. A value the
   operator cannot sensibly type -- WRL's account id and logbook id -- is not
   a field at all: a CHOICE field lists names, stores the id behind the name
   and may derive the rest from the same lookup.

   The list is built by a declarer procedure each time it is asked for, not
   once at registration: the captions are resourcestrings, and a string copied
   at start-up would never be translated. *)
{$I tr4w.inc}
interface
uses SysUtils, Generics.Collections, uExternalLoggerConfig, uExternalLoggerService;
type
   TLoggerFieldKind = (lfkText, lfkPort, lfkSecret, lfkChoice);

   (* The values a choice field offers: what the operator sees (Display) and
      what is stored (Value). *)
   TLoggerChoices = class
   private
      FValues, FDisplays: array of string;
      function GetCount: integer;
      function GetValue(aIndex: integer): string;
      function GetDisplay(aIndex: integer): string;
   public
      procedure Add(const aValue, aDisplay: string);
      procedure Clear;
      function IndexOfValue(const aValue: string): integer;
      property Count: integer read GetCount;
      property Value[aIndex: integer]: string read GetValue;
      property Display[aIndex: integer]: string read GetDisplay;
   end;

   (* Fills aChoices from the provider. RUNS ON A WORKER THREAD: it may read
      aWork (a private copy of the definition being edited) and nothing else
      shared, must not touch the UI, and may set aWork.Account when the lookup
      reveals it. Returns '' on success, else an error code to show. *)
   TLoggerChoiceLoader = function(const aWork: TExternalLoggerDefinition;
      const aChoices: TLoggerChoices): string;

   TLoggerFieldDescriptor = class
   public
      (* The LF_ key of the definition value this field edits. *)
      Key: string;
      (* A choice only: the key that receives the chosen NAME. *)
      DisplayKey: string;
      Caption: string;
      Kind: TLoggerFieldKind;
      Required: boolean;
      Loader: TLoggerChoiceLoader;
   end;

   TLoggerFieldList = class(TObjectList<TLoggerFieldDescriptor>)
   public
      function AddText(const aKey, aCaption: string; aRequired: boolean): TLoggerFieldDescriptor;
      function AddPort(const aKey, aCaption: string): TLoggerFieldDescriptor;
      function AddSecret(const aKey, aCaption: string; aRequired: boolean): TLoggerFieldDescriptor;
      function AddChoice(const aKey, aDisplayKey, aCaption: string;
         aLoader: TLoggerChoiceLoader): TLoggerFieldDescriptor;
      function Find(const aKey: string): TLoggerFieldDescriptor;
   end;

   TLoggerFieldDeclarer = procedure(const aFields: TLoggerFieldList);

   TExternalLoggerConstructor = function(const aDefinition: TExternalLoggerDefinition;
      aComputerId: AnsiChar): TExternalLoggerService;

   TExternalLoggerRegistration = class
   public
      Id, DisplayName: string;
      Construct: TExternalLoggerConstructor;
      Declare: TLoggerFieldDeclarer;
      (* The port a new definition of this provider starts with; 0 = none. *)
      DefaultPort: integer;
      (* A fresh list the caller frees; empty when the provider declares none. *)
      function CreateFields: TLoggerFieldList;
   end;
procedure RegisterExternalLogger(const aId, aDisplayName: string;
   aConstructor: TExternalLoggerConstructor; aDeclarer: TLoggerFieldDeclarer = nil;
   aDefaultPort: integer = 0);
(* nil when aId is not registered. The registry owns the result. *)
function FindExternalLoggerRegistration(const aId: string;
   out aRegistration: TExternalLoggerRegistration): boolean;
function ExternalLoggerRegistration(aIndex: integer): TExternalLoggerRegistration;
function ExternalLoggerProviderCount: integer;
function ExternalLoggerDefinitionError(const aDefinition: TExternalLoggerDefinition): string;
function CreateExternalLogger(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
implementation
uses uAppStrings;
var
   Providers: TObjectList<TExternalLoggerRegistration>;

function TLoggerChoices.GetCount: integer;
begin
   Result := Length(FValues);
end;
function TLoggerChoices.GetValue(aIndex: integer): string;
begin
   Result := FValues[aIndex];
end;
function TLoggerChoices.GetDisplay(aIndex: integer): string;
begin
   Result := FDisplays[aIndex];
end;
procedure TLoggerChoices.Add(const aValue, aDisplay: string);
var
   n: integer;
begin
   n := Length(FValues);
   SetLength(FValues, n + 1);
   SetLength(FDisplays, n + 1);
   FValues[n] := aValue;
   FDisplays[n] := aDisplay;
end;
procedure TLoggerChoices.Clear;
begin
   SetLength(FValues, 0);
   SetLength(FDisplays, 0);
end;
function TLoggerChoices.IndexOfValue(const aValue: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(FValues) do
      begin
      if FValues[i] = aValue then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function TLoggerFieldList.AddText(const aKey, aCaption: string;
   aRequired: boolean): TLoggerFieldDescriptor;
begin
   Result := TLoggerFieldDescriptor.Create;
   Result.Key := aKey;
   Result.Caption := aCaption;
   Result.Kind := lfkText;
   Result.Required := aRequired;
   Add(Result);
end;
function TLoggerFieldList.AddPort(const aKey, aCaption: string): TLoggerFieldDescriptor;
begin
   Result := AddText(aKey, aCaption, True);
   Result.Kind := lfkPort;
end;
function TLoggerFieldList.AddSecret(const aKey, aCaption: string;
   aRequired: boolean): TLoggerFieldDescriptor;
begin
   Result := AddText(aKey, aCaption, aRequired);
   Result.Kind := lfkSecret;
end;
function TLoggerFieldList.AddChoice(const aKey, aDisplayKey, aCaption: string;
   aLoader: TLoggerChoiceLoader): TLoggerFieldDescriptor;
begin
   Result := AddText(aKey, aCaption, True);
   Result.Kind := lfkChoice;
   Result.DisplayKey := aDisplayKey;
   Result.Loader := aLoader;
end;
function TLoggerFieldList.Find(const aKey: string): TLoggerFieldDescriptor;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to Count - 1 do
      begin
      if Items[i].Key = aKey then
         begin
         Result := Items[i];
         Exit;
         end;
      end;
end;

function TExternalLoggerRegistration.CreateFields: TLoggerFieldList;
begin
   Result := TLoggerFieldList.Create(True);
   if Assigned(Declare) then
      begin
      Declare(Result);
      end;
end;

procedure RegisterExternalLogger(const aId, aDisplayName: string;
   aConstructor: TExternalLoggerConstructor; aDeclarer: TLoggerFieldDeclarer;
   aDefaultPort: integer);
var
   i: integer;
   registration: TExternalLoggerRegistration;
begin
   if (aId = '') or not Assigned(aConstructor) then
      begin
      raise EArgumentException.Create('External logger registration is incomplete');
      end;
   for i := 0 to Providers.Count - 1 do
      begin
      if Providers[i].Id = UpperCase(aId) then
         begin
         raise EArgumentException.Create(UTF8Encode('Duplicate external logger provider: ' + aId));
         end;
      end;
   registration := TExternalLoggerRegistration.Create;
   registration.Id := UpperCase(aId);
   registration.DisplayName := aDisplayName;
   registration.Construct := aConstructor;
   registration.Declare := aDeclarer;
   registration.DefaultPort := aDefaultPort;
   Providers.Add(registration);
end;
function FindExternalLoggerRegistration(const aId: string;
   out aRegistration: TExternalLoggerRegistration): boolean;
var
   i: integer;
begin
   Result := False;
   aRegistration := nil;
   for i := 0 to Providers.Count - 1 do
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
   Result := Providers.Count;
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
   for i := 0 to Providers.Count - 1 do
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

(* The checks a definition must pass to be started, read from the provider's
   own declaration. They are the checks the flag set made before, in the same
   order: a stored definition that started yesterday starts today. In
   particular a secret is NOT required (a locked vault leaves it empty), and
   a choice needs both its value and the account that came with it. *)
function ExternalLoggerDefinitionError(const aDefinition: TExternalLoggerDefinition): string;
var
   registration: TExternalLoggerRegistration;
   fields: TLoggerFieldList;
   field: TLoggerFieldDescriptor;
   port: integer;
begin
   Result := '';
   if not FindExternalLoggerRegistration(aDefinition.ProviderId, registration) then
      begin
      Result := 'Unsupported external logger: ' + aDefinition.ProviderId;
      Exit;
      end;
   fields := registration.CreateFields;
   try
      for field in fields do
         begin
         if field.Kind = lfkPort then
            begin
            port := StrToIntDef(AnsiString(aDefinition.FieldText(field.Key)), 0);
            if (port < 1) or (port > 65535) then
               begin
               Result := SLoggerPortRange;
               Exit;
               end;
            end
         else if field.Kind = lfkChoice then
            begin
            if Trim(aDefinition.Account) = '' then
               begin
               Result := UnicodeFormat(SLoggerChoiceNeedsKey, [field.Caption]);
               Exit;
               end;
            if Trim(aDefinition.FieldText(field.Key)) = '' then
               begin
               Result := UnicodeFormat(SLoggerChoiceRequired, [field.Caption]);
               Exit;
               end;
            end
         else if field.Required and (Trim(aDefinition.FieldText(field.Key)) = '') then
            begin
            Result := UnicodeFormat(SLoggerFieldRequired, [field.Caption]);
            Exit;
            end;
         end;
   finally
      fields.Free;
   end;
end;
initialization
   Providers := TObjectList<TExternalLoggerRegistration>.Create(True);
finalization
   Providers.Free;
end.
