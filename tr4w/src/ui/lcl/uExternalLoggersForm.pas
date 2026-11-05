unit uExternalLoggersForm;
{$I ..\..\tr4w.inc}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, uExternalLoggerConfig;
type
   TExternalLoggersForm = class(TForm)
   published
      lstLoggers: TListBox;
      edtName, edtAddress, edtPort, edtURL, edtAccount, edtLogbook: TEdit;
      edtApiKey, edtPassword: TEdit;
      cbProvider: TComboBox;
      chkActive: TCheckBox;
      btnAdd, btnRemove, btnUp, btnDown, btnWRL, btnOK, btnCancel: TButton;
      lblName, lblProvider, lblAddress, lblPort, lblURL, lblAccount: TLabel;
      lblLogbook, lblApiKey, lblPassword, lblNote, lblOrder: TLabel;
      lblStatus: TLabel;
      procedure SelectLogger(Sender: TObject);
      procedure AddLogger(Sender: TObject);
      procedure RemoveLogger(Sender: TObject);
      procedure MoveLogger(Sender: TObject);
      procedure ProviderChanged(Sender: TObject);
      procedure ConfigureWRLClick(Sender: TObject);
      procedure Accept(Sender: TObject);
   private
      FConfig: TExternalLoggerConfig;
      FIndex: integer;
      FLoading: boolean;
      procedure Capture;
      procedure RefreshList;
      procedure ShowDefinition;
   public
      constructor Create(aOwner: TComponent); override;
      destructor Destroy; override;
   end;
function EditExternalLoggers(const aConfig: TExternalLoggerConfig): boolean;
implementation
uses uExternalLoggerRegistry, uWRLSetupForm, uLCLTranslate, uPasswordReveal,
   uExternalDelivery, uLogStore;
{$R *.lfm}
constructor TExternalLoggersForm.Create(aOwner: TComponent);
var
   i: integer;
begin
   inherited Create(aOwner);
   FConfig := TExternalLoggerConfig.Create;
   FIndex := -1;
   for i := 0 to ExternalLoggerProviderCount - 1 do
      begin
      cbProvider.Items.Add(AnsiString(ExternalLoggerRegistration(i).Id));
      end;
   AttachPasswordReveal(edtApiKey);
   AttachPasswordReveal(edtPassword);
   TranslateForm(Self);
end;
destructor TExternalLoggersForm.Destroy;
begin
   FConfig.Free;
   inherited Destroy;
end;
procedure TExternalLoggersForm.Capture;
var
   definition: TExternalLoggerDefinition;
   index: integer;
begin
   if (FIndex < 0) or (FIndex >= FConfig.Definitions.Count) then
      begin
      Exit;
      end;
   definition := FConfig.Definitions[FIndex];
   definition.Name := Trim(UTF8Decode(edtName.Text));
   definition.ProviderId := UTF8Decode(cbProvider.Text);
   definition.Address := Trim(UTF8Decode(edtAddress.Text));
   definition.Port := StrToIntDef(edtPort.Text, 0);
   definition.URL := Trim(UTF8Decode(edtURL.Text));
   definition.Account := Trim(UTF8Decode(edtAccount.Text));
   definition.Logbook := Trim(UTF8Decode(edtLogbook.Text));
   if definition.ApiKey <> UTF8Decode(edtApiKey.Text) then
      begin
      definition.LegacySecretPending := False;
      end;
   definition.ApiKey := UTF8Decode(edtApiKey.Text);
   definition.Password := UTF8Decode(edtPassword.Text);
   index := FConfig.ActiveIds.IndexOf(AnsiString(definition.Id));
   if index >= 0 then
      begin
      FConfig.ActiveIds.Delete(index);
      end;
   if chkActive.Checked then
      begin
      FConfig.ActiveIds.Add(AnsiString(definition.Id));
      end;
end;
procedure TExternalLoggersForm.RefreshList;
var
   definition: TExternalLoggerDefinition;
   prefix: string;
begin
   lstLoggers.Items.Clear;
   for definition in FConfig.Definitions do
      begin
      prefix := '';
      if FConfig.ActiveIds.IndexOf(AnsiString(definition.Id)) >= 0 then
         begin
         prefix := '* ';
         end;
      lstLoggers.Items.Add(UTF8Encode(prefix + definition.Name));
      end;
   lstLoggers.ItemIndex := FIndex;
end;
procedure TExternalLoggersForm.ShowDefinition;
var
   definition: TExternalLoggerDefinition;
   counts: TDeliveryCounts;
begin
   FLoading := True;
   try
      edtName.Enabled := FIndex >= 0;
      cbProvider.Enabled := FIndex >= 0;
      chkActive.Enabled := FIndex >= 0;
      btnRemove.Enabled := FIndex >= 0;
      btnUp.Enabled := FIndex > 0;
      btnDown.Enabled := (FIndex >= 0) and (FIndex < FConfig.Definitions.Count - 1);
      if (FIndex < 0) or (FIndex >= FConfig.Definitions.Count) then
         begin
         edtName.Clear;
         cbProvider.ItemIndex := -1;
         ProviderChanged(nil);
         lblStatus.Caption := '';
         Exit;
         end;
      definition := FConfig.Definitions[FIndex];
      edtName.Text := UTF8Encode(definition.Name);
      cbProvider.ItemIndex := cbProvider.Items.IndexOf(AnsiString(definition.ProviderId));
      edtAddress.Text := UTF8Encode(definition.Address);
      edtPort.Text := AnsiString(IntToStr(definition.Port));
      edtURL.Text := UTF8Encode(definition.URL);
      edtAccount.Text := UTF8Encode(definition.Account);
      edtLogbook.Text := UTF8Encode(definition.Logbook);
      edtApiKey.Text := UTF8Encode(definition.ApiKey);
      edtPassword.Text := UTF8Encode(definition.Password);
      chkActive.Checked := FConfig.ActiveIds.IndexOf(AnsiString(definition.Id)) >= 0;
      ProviderChanged(nil);
      lblStatus.Caption := 'No contest log is open.';
      if LogStoreRepository <> nil then
         begin
         try
            counts := ExternalDeliveryCounts(LogStoreRepository.Database.FileName, definition.DeliveryId);
            lblStatus.Caption := Format('Pending %d | Sending %d | Synced %d | Uncertain %d | Failed %d',
               [counts.Pending, counts.InFlight, counts.Synced, counts.Uncertain, counts.Failed]);
         except
            on E: Exception do
               begin
               lblStatus.Caption := 'Delivery status unavailable';
               end;
         end;
         end;
   finally
      FLoading := False;
   end;
end;
procedure TExternalLoggersForm.SelectLogger(Sender: TObject);
var
   selected: integer;
begin
   selected := lstLoggers.ItemIndex;
   Capture;
   FIndex := selected;
   RefreshList;
   ShowDefinition;
end;
procedure TExternalLoggersForm.AddLogger(Sender: TObject);
var
   definition: TExternalLoggerDefinition;
begin
   Capture;
   definition := TExternalLoggerDefinition.Create;
   definition.Name := 'Logger ' + string(IntToStr(FConfig.Definitions.Count + 1));
   definition.ProviderId := 'DXKEEPER';
   definition.Address := '127.0.0.1';
   definition.Port := 52001;
   FConfig.Definitions.Add(definition);
   FIndex := FConfig.Definitions.Count - 1;
   RefreshList;
   ShowDefinition;
end;
procedure TExternalLoggersForm.RemoveLogger(Sender: TObject);
var
   active: integer;
begin
   if FIndex < 0 then
      begin
      Exit;
      end;
   if MessageDlg('Remove logger definition? Pending deliveries stay in the contest log ' +
      'and will not be redirected to another definition.', mtConfirmation,
      [mbYes, mbNo], 0) <> mrYes then
      begin
      Exit;
      end;
   active := FConfig.ActiveIds.IndexOf(AnsiString(FConfig.Definitions[FIndex].Id));
   if active >= 0 then
      begin
      FConfig.ActiveIds.Delete(active);
      end;
   FConfig.Definitions.Delete(FIndex);
   FIndex := FConfig.Definitions.Count - 1;
   RefreshList;
   ShowDefinition;
end;
procedure TExternalLoggersForm.MoveLogger(Sender: TObject);
var
   target: integer;
begin
   Capture;
   target := FIndex - 1;
   if Sender = btnDown then
      begin
      target := FIndex + 1;
      end;
   if (FIndex < 0) or (target < 0) or (target >= FConfig.Definitions.Count) then
      begin
      Exit;
      end;
   FConfig.Definitions.Exchange(FIndex, target);
   FIndex := target;
   RefreshList;
   ShowDefinition;
end;
procedure TExternalLoggersForm.ProviderChanged(Sender: TObject);
var
   registration: TExternalLoggerRegistration;
begin
   if (Sender <> nil) and not FLoading then
      begin
      edtApiKey.Clear;
      edtPassword.Clear;
      edtAccount.Clear;
      edtLogbook.Clear;
      edtURL.Clear;
      if FIndex >= 0 then
         begin
         FConfig.Definitions[FIndex].LegacySecretPending := False;
         FConfig.Definitions[FIndex].LegacyWRL := False;
         end;
      end;
   FindExternalLoggerRegistration(UTF8Decode(cbProvider.Text), registration);
   lblLogbook.Caption := 'Callsign / logbook ID';
   lblApiKey.Caption := 'API token';
   if UTF8Decode(cbProvider.Text) = 'CLUBLOG' then
      begin
      lblLogbook.Caption := 'Club Log callsign';
      lblApiKey.Caption := 'Club Log API token';
      end;
   edtAddress.Enabled := lcfAddress in registration.Fields;
   edtPort.Enabled := lcfPort in registration.Fields;
   edtURL.Enabled := lcfURL in registration.Fields;
   edtAccount.Enabled := lcfAccount in registration.Fields;
   edtLogbook.Enabled := lcfLogbook in registration.Fields;
   edtApiKey.Enabled := lcfApiKey in registration.Fields;
   edtPassword.Enabled := lcfPassword in registration.Fields;
   btnWRL.Enabled := UTF8Decode(cbProvider.Text) = 'WRL';
   edtAddress.Visible := edtAddress.Enabled;
   lblAddress.Visible := edtAddress.Enabled;
   edtPort.Visible := edtPort.Enabled;
   lblPort.Visible := edtPort.Enabled;
   edtURL.Visible := edtURL.Enabled;
   lblURL.Visible := edtURL.Enabled;
   edtAccount.Visible := edtAccount.Enabled;
   lblAccount.Visible := edtAccount.Enabled;
   edtLogbook.Visible := edtLogbook.Enabled;
   lblLogbook.Visible := edtLogbook.Enabled;
   edtApiKey.Visible := edtApiKey.Enabled;
   lblApiKey.Visible := edtApiKey.Enabled;
   edtPassword.Visible := edtPassword.Enabled;
   lblPassword.Visible := edtPassword.Enabled;
   btnWRL.Visible := btnWRL.Enabled;
end;
procedure TExternalLoggersForm.ConfigureWRLClick(Sender: TObject);
var
   key, account, book: string;
begin
   key := UTF8Decode(edtApiKey.Text);
   account := UTF8Decode(edtAccount.Text);
   book := UTF8Decode(edtLogbook.Text);
   if ConfigureWRL(key, account, book) then
      begin
      edtApiKey.Text := UTF8Encode(key);
      edtAccount.Text := UTF8Encode(account);
      edtLogbook.Text := UTF8Encode(book);
      end;
end;
procedure TExternalLoggersForm.Accept(Sender: TObject);
var
   active: TStringList;
   definition: TExternalLoggerDefinition;
   error: string;
   i, j: integer;
begin
   Capture;
   active := TStringList.Create;
   try
      for definition in FConfig.Definitions do
         begin
         if FConfig.ActiveIds.IndexOf(AnsiString(definition.Id)) >= 0 then
            begin
            error := ExternalLoggerDefinitionError(definition);
            if error <> '' then
               begin
               ShowMessage(UTF8Encode(definition.Name + ': ' + error));
               Exit;
               end;
            active.Add(AnsiString(definition.Id));
            end;
         end;
      FConfig.ActiveIds.Assign(active);
   finally
      active.Free;
   end;
   if not FConfig.Validate(error) then
      begin
      ShowMessage(UTF8Encode(error));
      Exit;
      end;
   for i := 0 to FConfig.ActiveIds.Count - 1 do
      begin
      definition := FConfig.Find(string(FConfig.ActiveIds[i]));
      for j := 0 to i - 1 do
         begin
         if (definition.ProviderId = FConfig.Find(string(FConfig.ActiveIds[j])).ProviderId) and
            (definition.DestinationFingerprint =
               FConfig.Find(string(FConfig.ActiveIds[j])).DestinationFingerprint) then
            begin
            if QuestionDlg('TR4W', UTF8Encode('The active loggers "' + definition.Name +
               '" and "' + FConfig.Find(string(FConfig.ActiveIds[j])).Name +
               '" point to the same destination. Send each contact twice?'),
               mtWarning, [mrYes, mrNo, 'IsDefault'], 0) <> mrYes then
               begin
               Exit;
               end;
            end;
         end;
      end;
   FConfig.Present := True;
   ModalResult := mrOK;
end;
function EditExternalLoggers(const aConfig: TExternalLoggerConfig): boolean;
var
   dialog: TExternalLoggersForm;
   i, index: integer;
begin
   if aConfig.Error <> '' then
      begin
      ShowMessage(UTF8Encode('External logger settings could not be read: ' + aConfig.Error));
      Result := False;
      Exit;
      end;
   dialog := TExternalLoggersForm.Create(nil);
   try
      dialog.FConfig.Assign(aConfig);
      for i := 0 to dialog.FConfig.ActiveIds.Count - 1 do
         begin
         index := dialog.FConfig.Definitions.IndexOf(
            dialog.FConfig.Find(string(dialog.FConfig.ActiveIds[i])));
         if index >= 0 then
            begin
            dialog.FConfig.Definitions.Exchange(i, index);
            end;
         end;
      dialog.RefreshList;
      dialog.ShowDefinition;
      Result := dialog.ShowModal = mrOK;
      if Result then
         begin
         aConfig.Assign(dialog.FConfig);
         end;
   finally
      dialog.Free;
   end;
end;
end.
