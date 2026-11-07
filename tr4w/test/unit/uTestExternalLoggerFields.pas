unit uTestExternalLoggerFields;
{$I ..\..\src\tr4w.inc}

(*
  THE EXTERNAL LOGGER EDITOR BUILDS ITS ROWS FROM THE PROVIDER (issue 227).

  What is pinned here:

  - the field descriptors each provider declares, and that WRL declares no
    account or logbook-id text field at all;
  - the start-up check (ExternalLoggerDefinitionError) still says what the
    old flag set said, so a stored definition that started yesterday starts
    today;
  - a definition's JSON with and without the logbook NAME, an old definition
    without it, and the delivery id staying exactly where it was (a literal
    computed before the change);
  - the editor, on a streamed form that is never shown: the right controls
    per provider, an old WRL definition opening and saving byte-identical, a
    list load that fills NAMES and writes the derived account only when the
    operator picks, a failed load that keeps the saved choice, an edited key
    that drops it, a provider change, and no provider setup step.
  - WRL's own loader against a scripted transport.

  NOT covered here, and bench-only (docs/BENCH_QUEUE.md): the real drop-down
  against api.worldradioleague.com, and the look of the rows.
*)

interface

uses
   uTR4WTestFramework;

type
   TExternalLoggerFieldsTests = class(TTestCase)
   protected
      procedure Test_Descriptors_PerProvider;
      procedure Test_Descriptors_WRLHasNoAccountOrLogbookIdText;
      procedure Test_Descriptors_AtMostTheProviderFieldLimit;
      procedure Test_DefinitionError_KeepsTheOldChecks;
      procedure Test_Json_LogbookNameRoundTripsAndOldLoads;
      procedure Test_Json_DeliveryIdIsPinned;
      procedure Test_Editor_BuildsTheDeclaredControls;
      procedure Test_Editor_OldWRLDefinitionSavesUnchanged;
      procedure Test_Editor_LoadFillsNamesAndAccountOnlyOnAPick;
      procedure Test_Editor_AFailedLoadKeepsTheSavedChoice;
      procedure Test_Editor_EditingTheKeyDropsTheChoice;
      procedure Test_Editor_ProviderChangeKeepsHostDropsCredentials;
      procedure Test_Editor_NoProviderHasASetupButton;
      procedure Test_WRL_LoaderReadsAccountAndSkipsLockedBooks;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Forms, StdCtrls, uJSON, uKeychain, uAppStrings,
   uExternalLoggerConfig, uExternalLoggerRegistry, uExternalLoggersForm,
   uWRLExternalLogger, uClubLogExternalLogger,
   uSettingsRegistry, uSettingsDeclarations, uHttpTransport, uHTTPDownload,
   uTestFakeTransport;

var
   (* 0 = the loader answers; 1 = it fails. Read on the worker thread. *)
   GLoadMode: integer;

type
   (* Answers /me and /logbooks the way the WRL API does. *)
   TWRLScriptTransport = class(TFakeHttpTransport)
   public
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); override;
   end;

procedure TWRLScriptTransport.Execute(aRequest: THttpWireRequest; aSink: TStream;
   aResult: THttpWireResult);
begin
   ScriptStatus := 200;
   if Pos('/logbooks', aRequest.URL) > 0 then
      begin
      ScriptBody := '{"data":[{"id":"b1","name":"Alpha","isLocked":false},' +
         '{"id":"b2","name":"Locked","isLocked":true},' +
         '{"id":"b3","name":"Gamma"}],"error":null,"meta":{}}';
      end
   else
      begin
      ScriptBody := '{"data":{"uid":"uid-9"},"error":null}';
      end;
   inherited Execute(aRequest, aSink, aResult);
end;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

function FakeLoader(const aWork: TExternalLoggerDefinition;
   const aChoices: TLoggerChoices): string;
begin
   if GLoadMode = 1 then
      begin
      Result := 'NET_DOWN';
      Exit;
      end;
   aChoices.Add('id-a', 'Alpha');
   aChoices.Add('id-b', 'Bravo');
   aWork.Account := 'derived-acct';
   Result := '';
end;

function FakeFields: TLoggerFieldList;
begin
   Result := TLoggerFieldList.Create(True);
   Result.AddSecret(LF_API_KEY, 'Key', False);
   Result.AddChoice(LF_LOGBOOK, LF_LOGBOOK_NAME, 'Book', FakeLoader);
end;

function FieldsOf(const aProvider: string): TLoggerFieldList;
var
   registration: TExternalLoggerRegistration;
begin
   Result := nil;
   if FindExternalLoggerRegistration(aProvider, registration) then
      begin
      Result := registration.CreateFields;
      end;
end;

(* The keys, in order, as one string: 'address,port'. *)
function KeysOf(const aFields: TLoggerFieldList): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to aFields.Count - 1 do
      begin
      if Result <> '' then
         begin
         Result := Result + ',';
         end;
      Result := Result + aFields[i].Key;
      end;
end;

function WRLDefinition(const aConfig: TExternalLoggerConfig): TExternalLoggerDefinition;
begin
   Result := TExternalLoggerDefinition.Create;
   Result.Id := 'def-1';
   Result.Name := 'WRL one';
   Result.ProviderId := 'WRL';
   Result.Account := 'acct-1';
   Result.Logbook := 'book-1';
   Result.ApiKey := 'key-1';
   aConfig.Definitions.Add(Result);
   aConfig.Present := True;
end;

function WaitLoad(const aForm: TExternalLoggersForm): boolean;
var
   waited: integer;
begin
   waited := 0;
   while aForm.LoadRunning and (waited < 5000) do
      begin
      Sleep(5);
      Inc(waited, 5);
      aForm.PollLoad(nil);
      end;
   Result := not aForm.LoadRunning;
end;

procedure DeclareVerifyOn;
var
   setting: TSettingBase;
begin
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   if setting is TBoolSetting then
      begin
      TBoolSetting(setting).SetValue(True);
      end;
end;

procedure TExternalLoggerFieldsTests.Test_Descriptors_PerProvider;
var
   fields: TLoggerFieldList;
begin
   BeginTest('Descriptors: DXKeeper declares host and port');
   fields := FieldsOf('DXKEEPER');
   try
      CheckEquals('address,port', KeysOf(fields));
      CheckTrue(fields[0].Kind = lfkText, 'host is text');
      CheckTrue(fields[1].Kind = lfkPort, 'port is a port');
   finally
      fields.Free;
   end;
   BeginTest('Descriptors: Club Log declares the callsign (stored as the logbook) and a secret token');
   fields := FieldsOf('CLUBLOG');
   try
      CheckEquals('logbook,apiKey', KeysOf(fields));
      CheckTrue(fields[0].Kind = lfkText);
      CheckEquals(SLoggerFieldClubLogCall, fields[0].Caption);
      CheckTrue(fields[0].Required, 'the callsign is required');
      CheckTrue(fields[1].Kind = lfkSecret);
      CheckFalse(fields[1].Required, 'a locked vault leaves the token empty and must still start');
   finally
      fields.Free;
   end;
   BeginTest('Descriptors: WRL declares a secret key and a logbook CHOICE keyed to a name');
   fields := FieldsOf('WRL');
   try
      CheckEquals('apiKey,logbook', KeysOf(fields));
      CheckTrue(fields[0].Kind = lfkSecret);
      CheckTrue(fields[1].Kind = lfkChoice);
      CheckEquals(LF_LOGBOOK_NAME, fields[1].DisplayKey);
      CheckTrue(Assigned(fields[1].Loader), 'it can obtain its choices');
   finally
      fields.Free;
   end;
   BeginTest('Descriptors: an unknown provider has no registration');
   CheckTrue(FieldsOf('NOSUCH') = nil);
end;

procedure TExternalLoggerFieldsTests.Test_Descriptors_WRLHasNoAccountOrLogbookIdText;
var
   fields: TLoggerFieldList;
   i: integer;
begin
   BeginTest('Descriptors: WRL has no account field and no text field for the logbook id');
   fields := FieldsOf('WRL');
   try
      CheckTrue(fields.Find(LF_ACCOUNT) = nil, 'the account id is never a field');
      CheckTrue(fields.Find(LF_LOGBOOK) <> nil);
      CheckTrue(fields.Find(LF_LOGBOOK).Kind = lfkChoice, 'the logbook is a choice, not text');
      for i := 0 to fields.Count - 1 do
         begin
         if (fields[i].Key = LF_LOGBOOK) or (fields[i].Key = LF_ACCOUNT) then
            begin
            CheckTrue(fields[i].Kind = lfkChoice, 'only the choice may carry the logbook');
            end;
         end;
   finally
      fields.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Descriptors_AtMostTheProviderFieldLimit;
var
   i: integer;
   fields: TLoggerFieldList;
begin
   BeginTest('Descriptors: no provider declares more than EXTERNAL_LOGGER_MAX_FIELDS rows');
   for i := 0 to ExternalLoggerProviderCount - 1 do
      begin
      fields := ExternalLoggerRegistration(i).CreateFields;
      try
         CheckTrue(fields.Count <= EXTERNAL_LOGGER_MAX_FIELDS,
            ExternalLoggerRegistration(i).Id + ' declares ' + IntToStr(fields.Count));
      finally
         fields.Free;
      end;
      end;
end;

procedure TExternalLoggerFieldsTests.Test_DefinitionError_KeepsTheOldChecks;
var
   d: TExternalLoggerDefinition;
begin
   d := TExternalLoggerDefinition.Create;
   try
      BeginTest('DefinitionError: DXKeeper needs a host, then a port in range');
      d.ProviderId := 'DXKEEPER';
      d.Port := 52001;
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'no host');
      d.Address := '127.0.0.1';
      CheckEquals('', ExternalLoggerDefinitionError(d));
      d.Port := 0;
      CheckEquals(SLoggerPortRange, ExternalLoggerDefinitionError(d));
      d.Port := 65536;
      CheckEquals(SLoggerPortRange, ExternalLoggerDefinitionError(d));

      BeginTest('DefinitionError: Club Log needs the callsign and NOT the token');
      d.ProviderId := 'CLUBLOG';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'no callsign');
      d.Logbook := 'NY4I';
      CheckEquals('', ExternalLoggerDefinitionError(d), 'an empty token still starts');

      BeginTest('DefinitionError: WRL needs the logbook and the account that came with it, not the key');
      d.ProviderId := 'WRL';
      d.Logbook := '';
      d.Account := '';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'nothing chosen');
      d.Logbook := 'book-1';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'a logbook without its account');
      d.Account := 'acct-1';
      CheckEquals('', ExternalLoggerDefinitionError(d), 'an old definition with an empty key starts');
      d.Logbook := '';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'an account without a logbook');

      BeginTest('DefinitionError: an unregistered provider is refused');
      d.ProviderId := 'NOSUCH';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '');
   finally
      d.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Json_LogbookNameRoundTripsAndOldLoads;
var
   source, loaded, assigned: TExternalLoggerDefinition;
   json: TJSONObject;
begin
   InstallTestKeychain;
   source := TExternalLoggerDefinition.Create;
   loaded := TExternalLoggerDefinition.Create;
   assigned := TExternalLoggerDefinition.Create;
   try
      source.Id := 'def-1';
      source.Name := 'WRL one';
      source.ProviderId := 'WRL';
      source.Account := 'acct-1';
      source.Logbook := 'book-1';
      BeginTest('Json: a logbook name round-trips and Assign copies it');
      source.LogbookName := 'Contest Station';
      json := source.ToJSON;
      try
         loaded.LoadJSON(json);
      finally
         json.Free;
      end;
      CheckEquals('Contest Station', loaded.LogbookName);
      CheckEquals('book-1', loaded.Logbook);
      assigned.Assign(loaded);
      CheckEquals('Contest Station', assigned.LogbookName);

      BeginTest('Json: a definition without a name writes no name and an old blob loads to an empty one');
      source.LogbookName := '';
      json := source.ToJSON;
      try
         CheckTrue(json.GetValue('logbookName') = nil, 'nothing written for an unknown name');
         loaded.LogbookName := 'stale';
         loaded.LoadJSON(json);
      finally
         json.Free;
      end;
      CheckEquals('', loaded.LogbookName);
      CheckEquals('acct-1', loaded.Account);
      CheckEquals('book-1', loaded.Logbook);

      BeginTest('Json: the name is display only, so it never moves the delivery id');
      source.LogbookName := 'One';
      loaded.Assign(source);
      loaded.LogbookName := 'Renamed on the server';
      CheckEquals(source.DeliveryId, loaded.DeliveryId);
   finally
      assigned.Free;
      loaded.Free;
      source.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Json_DeliveryIdIsPinned;
var
   d: TExternalLoggerDefinition;
begin
   BeginTest('Json: an existing WRL definition keeps the delivery id it had before issue 227');
   d := TExternalLoggerDefinition.Create;
   try
      d.Id := 'def-1';
      d.ProviderId := 'WRL';
      d.Account := 'acct-1';
      d.Logbook := 'book-1';
      (* Computed with hashlib over the fingerprint text before this change. *)
      CheckEquals('WRL/def-1/19333b5fad189fa9a9ab145362647697b2a38cad2f89e4af8038ce8cc30790c3',
         d.DeliveryId);
   finally
      d.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Editor_BuildsTheDeclaredControls;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
begin
   InitWidgetSet;
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      BeginTest('Editor: DXKeeper shows host and port and nothing else');
      d := TExternalLoggerDefinition.Create;
      d.ProviderId := 'DXKEEPER';
      d.Address := '10.0.0.5';
      d.Port := 52001;
      form.Config.Definitions.Add(d);
      form.BeginEdit(d);
      CheckEquals(2, form.RowCount);
      CheckEquals('10.0.0.5', UTF8Decode(form.FieldEdit(LF_ADDRESS).Text));
      CheckEquals('52001', UTF8Decode(form.FieldEdit(LF_PORT).Text));
      CheckTrue(form.FieldEdit(LF_API_KEY) = nil);
      CheckTrue(form.FieldCombo(LF_LOGBOOK) = nil);

      BeginTest('Editor: Club Log shows the callsign as text and the token masked');
      form.cbProvider.ItemIndex := form.cbProvider.Items.IndexOf('CLUBLOG');
      form.ProviderChanged(form.cbProvider);
      CheckEquals(2, form.RowCount);
      CheckTrue(form.FieldEdit(LF_LOGBOOK) <> nil);
      CheckTrue(form.FieldEdit(LF_LOGBOOK).PasswordChar = #0, 'a callsign is not a secret');
      CheckTrue(form.FieldEdit(LF_API_KEY).PasswordChar <> #0, 'the token is masked');
      CheckTrue(form.FieldEdit(LF_ADDRESS) = nil);
      CheckTrue(form.FieldEdit(LF_ACCOUNT) = nil);

      BeginTest('Editor: WRL shows the key and a logbook drop-down, and no account or id text box');
      form.cbProvider.ItemIndex := form.cbProvider.Items.IndexOf('WRL');
      form.ProviderChanged(form.cbProvider);
      CheckEquals(2, form.RowCount);
      CheckTrue(form.FieldEdit(LF_API_KEY).PasswordChar <> #0);
      CheckTrue(form.FieldCombo(LF_LOGBOOK) <> nil, 'the logbook is a drop-down');
      CheckTrue(form.FieldEdit(LF_LOGBOOK) = nil, 'and not a text box');
      CheckTrue(form.FieldEdit(LF_ACCOUNT) = nil, 'the account id is not shown');
      CheckTrue(form.FieldRefreshButton(LF_LOGBOOK) <> nil, 'it can be refreshed');
   finally
      form.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Editor_OldWRLDefinitionSavesUnchanged;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
   combo: TComboBox;
begin
   InitWidgetSet;
   BeginTest('Editor: an old WRL definition (no name) opens on a placeholder and saves byte-identical');
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      d := WRLDefinition(form.Config);
      form.BeginEdit(d);
      combo := form.FieldCombo(LF_LOGBOOK);
      CheckEquals(1, combo.Items.Count);
      CheckEquals(0, combo.ItemIndex, 'the saved choice is selected');
      CheckEquals(SLoggerChoiceSaved, UTF8Decode(combo.Items[0]));
      CheckEquals('key-1', UTF8Decode(form.FieldEdit(LF_API_KEY).Text));
      form.Capture;
      CheckEquals('acct-1', d.Account, 'the account is not rewritten');
      CheckEquals('book-1', d.Logbook);
      CheckEquals('', d.LogbookName, 'a name never recorded stays unrecorded');
      CheckEquals('key-1', d.ApiKey);
      CheckEquals('WRL', d.ProviderId);
      CheckEquals('WRL one', d.Name);
      CheckEquals(0, d.Port);
      CheckEquals('', d.Address);
      CheckEquals('WRL/def-1/19333b5fad189fa9a9ab145362647697b2a38cad2f89e4af8038ce8cc30790c3',
         d.DeliveryId, 'and the queue it owns is the same queue');
   finally
      form.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Editor_LoadFillsNamesAndAccountOnlyOnAPick;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
   combo: TComboBox;
begin
   InitWidgetSet;
   BeginTest('Editor: a load lists NAMES, keeps the saved pick, and writes the derived account only after a pick');
   GLoadMode := 0;
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      d := WRLDefinition(form.Config);
      d.Account := 'old-acct';
      d.Logbook := 'id-b';
      d.LogbookName := '';
      form.BeginEdit(d);
      form.RebuildRows(FakeFields);
      combo := form.FieldCombo(LF_LOGBOOK);
      form.FieldRefreshButton(LF_LOGBOOK).Click;
      CheckTrue(form.LoadRunning, 'the load runs on its own thread');
      CheckTrue(WaitLoad(form), 'the load finished');
      CheckEquals(2, combo.Items.Count);
      CheckEquals('Alpha', UTF8Decode(combo.Items[0]));
      CheckEquals('Bravo', UTF8Decode(combo.Items[1]));
      CheckEquals(1, combo.ItemIndex, 'the saved logbook (id-b) is still the selected one');
      form.Capture;
      CheckEquals('old-acct', d.Account, 'refreshing a list does not rewrite the account');
      CheckEquals('id-b', d.Logbook);
      CheckEquals('Bravo', d.LogbookName, 'the name is refreshed by the load');
      combo.ItemIndex := 0;
      combo.OnChange(combo);
      form.Capture;
      CheckEquals('id-a', d.Logbook, 'a pick stores the id behind the name');
      CheckEquals('Alpha', d.LogbookName);
      CheckEquals('derived-acct', d.Account, 'and brings the account the lookup revealed');
   finally
      form.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Editor_AFailedLoadKeepsTheSavedChoice;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
   combo: TComboBox;
begin
   InitWidgetSet;
   BeginTest('Editor: with no network the saved name stays selectable and the definition is unchanged');
   GLoadMode := 1;
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      d := WRLDefinition(form.Config);
      d.Logbook := 'id-b';
      d.LogbookName := 'Bravo';
      form.BeginEdit(d);
      form.RebuildRows(FakeFields);
      combo := form.FieldCombo(LF_LOGBOOK);
      form.FieldRefreshButton(LF_LOGBOOK).Click;
      CheckTrue(WaitLoad(form), 'the load finished');
      CheckEquals(1, combo.Items.Count);
      CheckEquals('Bravo', UTF8Decode(combo.Items[0]));
      CheckEquals(0, combo.ItemIndex);
      CheckTrue(Pos('NET_DOWN', string(UTF8Decode(form.lblFieldStatus.Caption))) > 0,
         'the failure is reported: ' + string(UTF8Decode(form.lblFieldStatus.Caption)));
      form.Capture;
      CheckEquals('id-b', d.Logbook);
      CheckEquals('Bravo', d.LogbookName);
      CheckEquals('acct-1', d.Account);
   finally
      GLoadMode := 0;
      form.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Editor_EditingTheKeyDropsTheChoice;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
begin
   InitWidgetSet;
   BeginTest('Editor: a different key invalidates the list, the choice and the account');
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      d := WRLDefinition(form.Config);
      d.LogbookName := 'Bravo';
      form.BeginEdit(d);
      CheckEquals(1, form.FieldCombo(LF_LOGBOOK).Items.Count);
      form.FieldEdit(LF_API_KEY).Text := 'another-key';
      CheckEquals(0, form.FieldCombo(LF_LOGBOOK).Items.Count, 'the old key''s logbooks are gone');
      form.Capture;
      CheckEquals('another-key', d.ApiKey);
      CheckEquals('', d.Logbook, 'a logbook of the old account is not kept');
      CheckEquals('', d.LogbookName);
      CheckEquals('', d.Account);
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'so it must be chosen again');
   finally
      form.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Editor_ProviderChangeKeepsHostDropsCredentials;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
begin
   InitWidgetSet;
   BeginTest('Editor: changing provider keeps host and port, drops credentials and the logbook');
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      d := TExternalLoggerDefinition.Create;
      d.Name := 'Logger 1';
      d.ProviderId := 'DXKEEPER';
      d.Address := '10.0.0.5';
      d.Port := 52001;
      form.Config.Definitions.Add(d);
      form.BeginEdit(d);
      form.cbProvider.ItemIndex := form.cbProvider.Items.IndexOf('CLUBLOG');
      form.ProviderChanged(form.cbProvider);
      form.FieldEdit(LF_LOGBOOK).Text := 'NY4I';
      form.FieldEdit(LF_API_KEY).Text := 'token';
      form.cbProvider.ItemIndex := form.cbProvider.Items.IndexOf('WRL');
      form.ProviderChanged(form.cbProvider);
      CheckEquals('', UTF8Decode(form.FieldEdit(LF_API_KEY).Text), 'the token did not follow');
      CheckEquals(0, form.FieldCombo(LF_LOGBOOK).Items.Count, 'nor the callsign as a logbook');
      form.cbProvider.ItemIndex := form.cbProvider.Items.IndexOf('DXKEEPER');
      form.ProviderChanged(form.cbProvider);
      CheckEquals('10.0.0.5', UTF8Decode(form.FieldEdit(LF_ADDRESS).Text));
      CheckEquals('52001', UTF8Decode(form.FieldEdit(LF_PORT).Text));
   finally
      form.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_Editor_NoProviderHasASetupButton;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
   i: integer;
begin
   InitWidgetSet;
   BeginTest('Editor: no provider has a setup step, and a WRL key typed with no network still saves');
   GLoadMode := 1;
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      for i := 0 to form.ControlCount - 1 do
         begin
         CheckTrue(form.Controls[i].Name <> 'btnSetup', 'the editor has no Setup button');
         end;
      d := WRLDefinition(form.Config);
      d.ApiKey := '';
      d.Account := '';
      d.Logbook := '';
      form.BeginEdit(d);
      form.FieldEdit(LF_API_KEY).Text := 'typed-key';
      form.Capture;
      CheckEquals('typed-key', d.ApiKey, 'the key is saved without a lookup');
      CheckEquals('', d.Logbook, 'and no logbook is invented');
      CheckEquals('', d.Account);
   finally
      GLoadMode := 0;
      form.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.Test_WRL_LoaderReadsAccountAndSkipsLockedBooks;
var
   fake: TWRLScriptTransport;
   work: TExternalLoggerDefinition;
   choices: TLoggerChoices;
begin
   BeginTest('WRL loader: derives the account from the key, lists unlocked logbooks by name');
   DeclareVerifyOn;
   fake := TWRLScriptTransport.Create;
   SetHttpTransportForTest(fake);
   work := TExternalLoggerDefinition.Create;
   choices := TLoggerChoices.Create;
   try
      work.ApiKey := 'fixture-wrl-key';
      CheckEquals('', LoadWRLLogbookChoices(work, choices));
      CheckEquals('uid-9', work.Account, 'the uid of the key');
      CheckEquals(2, choices.Count, 'the locked logbook is not offered');
      CheckEquals('b1', choices.Value[0]);
      CheckEquals('Alpha', choices.Display[0]);
      CheckEquals('b3', choices.Value[1]);
      CheckEquals('fixture-wrl-key', fake.Last.BearerToken, 'it asked with the key it was given');
      work.ApiKey := '';
      choices.Clear;
      CheckEquals('API_KEY_REQUIRED', LoadWRLLogbookChoices(work, choices));
      CheckEquals(0, choices.Count);
   finally
      choices.Free;
      work.Free;
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure TExternalLoggerFieldsTests.RunAllTests;
begin
   Test_Descriptors_PerProvider;
   Test_Descriptors_WRLHasNoAccountOrLogbookIdText;
   Test_Descriptors_AtMostTheProviderFieldLimit;
   Test_DefinitionError_KeepsTheOldChecks;
   Test_Json_LogbookNameRoundTripsAndOldLoads;
   Test_Json_DeliveryIdIsPinned;
   Test_Editor_BuildsTheDeclaredControls;
   Test_Editor_OldWRLDefinitionSavesUnchanged;
   Test_Editor_LoadFillsNamesAndAccountOnlyOnAPick;
   Test_Editor_AFailedLoadKeepsTheSavedChoice;
   Test_Editor_EditingTheKeyDropsTheChoice;
   Test_Editor_ProviderChangeKeepsHostDropsCredentials;
   Test_Editor_NoProviderHasASetupButton;
   Test_WRL_LoaderReadsAccountAndSkipsLockedBooks;
end;

end.
