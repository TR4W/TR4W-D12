unit uExternalLoggersForm;
(* The editor for ONE external logger definition. The list, its order, the
   Send new QSOs flag and removal live in the Preferences grid
   (uExternalLoggerGrid, issue 220); this form is opened from there for Add
   and Edit. It works on a private copy of the whole configuration so the
   validation (unique names, shared destinations) sees the other loggers, and
   hands the copy back only on OK. *)
{$I ..\..\tr4w.inc}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, uExternalLoggerConfig;
type
   TExternalLoggersForm = class(TForm)
   published
      edtName, edtAddress, edtPort, edtURL, edtAccount, edtLogbook: TEdit;
      edtApiKey, edtPassword: TEdit;
      cbProvider: TComboBox;
      chkActive: TCheckBox;
      btnWRL, btnOK, btnCancel: TButton;
      lblName, lblProvider, lblAddress, lblPort, lblURL, lblAccount: TLabel;
      lblLogbook, lblApiKey, lblPassword, lblNote: TLabel;
      lblStatus: TLabel;
      procedure ProviderChanged(Sender: TObject);
      procedure ConfigureWRLClick(Sender: TObject);
      procedure Accept(Sender: TObject);
   private
      FConfig: TExternalLoggerConfig;
      FDefinition: TExternalLoggerDefinition;
      FLoading: boolean;
      procedure Capture;
      procedure ShowDefinition;
   public
      constructor Create(aOwner: TComponent); override;
      destructor Destroy; override;
   end;

(* Add (aId = '') or edit one definition of aConfig. True when the operator
   accepted; aConfig then holds the change. *)
function EditExternalLoggerDefinition(const aConfig: TExternalLoggerConfig;
   const aId: string): boolean;

(* The checks the editor's OK button makes, shared with the grid's Send new
   QSOs toggle so neither can switch on a logger the other would refuse. They
   speak to the operator; False means a message was shown. *)
function ExternalLoggerConfigAcceptable(const aConfig: TExternalLoggerConfig): boolean;

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
begin
   if FDefinition = nil then
      begin
      Exit;
      end;
   FDefinition.Name := Trim(UTF8Decode(edtName.Text));
   FDefinition.ProviderId := UTF8Decode(cbProvider.Text);
   FDefinition.Address := Trim(UTF8Decode(edtAddress.Text));
   FDefinition.Port := StrToIntDef(edtPort.Text, 0);
   FDefinition.URL := Trim(UTF8Decode(edtURL.Text));
   FDefinition.Account := Trim(UTF8Decode(edtAccount.Text));
   FDefinition.Logbook := Trim(UTF8Decode(edtLogbook.Text));
   if FDefinition.ApiKey <> UTF8Decode(edtApiKey.Text) then
      begin
      FDefinition.LegacySecretPending := False;
      end;
   FDefinition.ApiKey := UTF8Decode(edtApiKey.Text);
   FDefinition.Password := UTF8Decode(edtPassword.Text);
   FConfig.SetActive(FDefinition.Id, chkActive.Checked);
end;
procedure TExternalLoggersForm.ShowDefinition;
var
   counts: TDeliveryCounts;
begin
   FLoading := True;
   try
      edtName.Text := UTF8Encode(FDefinition.Name);
      cbProvider.ItemIndex := cbProvider.Items.IndexOf(AnsiString(FDefinition.ProviderId));
      edtAddress.Text := UTF8Encode(FDefinition.Address);
      edtPort.Text := AnsiString(IntToStr(FDefinition.Port));
      edtURL.Text := UTF8Encode(FDefinition.URL);
      edtAccount.Text := UTF8Encode(FDefinition.Account);
      edtLogbook.Text := UTF8Encode(FDefinition.Logbook);
      edtApiKey.Text := UTF8Encode(FDefinition.ApiKey);
      edtPassword.Text := UTF8Encode(FDefinition.Password);
      chkActive.Checked := FConfig.ActivePosition(FDefinition.Id) > 0;
      ProviderChanged(nil);
      lblStatus.Caption := 'No contest log is open.';
      if LogStoreRepository <> nil then
         begin
         try
            counts := ExternalDeliveryCounts(LogStoreRepository.Database.FileName, FDefinition.DeliveryId);
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
      if FDefinition <> nil then
         begin
         FDefinition.LegacySecretPending := False;
         FDefinition.LegacyWRL := False;
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

function ExternalLoggerConfigAcceptable(const aConfig: TExternalLoggerConfig): boolean;
var
   definition, earlier: TExternalLoggerDefinition;
   error: string;
   i, j: integer;
begin
   Result := False;
   for i := 0 to aConfig.ActiveIds.Count - 1 do
      begin
      definition := aConfig.Find(string(aConfig.ActiveIds[i]));
      if definition <> nil then
         begin
         error := ExternalLoggerDefinitionError(definition);
         if error <> '' then
            begin
            ShowMessage(UTF8Encode(definition.Name + ': ' + error));
            Exit;
            end;
         end;
      end;
   if not aConfig.Validate(error) then
      begin
      ShowMessage(UTF8Encode(error));
      Exit;
      end;
   for i := 0 to aConfig.ActiveIds.Count - 1 do
      begin
      definition := aConfig.Find(string(aConfig.ActiveIds[i]));
      for j := 0 to i - 1 do
         begin
         earlier := aConfig.Find(string(aConfig.ActiveIds[j]));
         if (definition.ProviderId = earlier.ProviderId) and
            (definition.DestinationFingerprint = earlier.DestinationFingerprint) then
            begin
            if QuestionDlg('TR4W', UTF8Encode('The active loggers "' + definition.Name +
               '" and "' + earlier.Name +
               '" point to the same destination. Send each contact twice?'),
               mtWarning, [mrYes, mrNo, 'IsDefault'], 0) <> mrYes then
               begin
               Exit;
               end;
            end;
         end;
      end;
   Result := True;
end;

procedure TExternalLoggersForm.Accept(Sender: TObject);
begin
   Capture;
   if not ExternalLoggerConfigAcceptable(FConfig) then
      begin
      Exit;
      end;
   FConfig.Present := True;
   ModalResult := mrOK;
end;

function EditExternalLoggerDefinition(const aConfig: TExternalLoggerConfig;
   const aId: string): boolean;
var
   dialog: TExternalLoggersForm;
   definition: TExternalLoggerDefinition;
begin
   Result := False;
   if aConfig.Error <> '' then
      begin
      ShowMessage(UTF8Encode('External logger settings could not be read: ' + aConfig.Error));
      Exit;
      end;
   dialog := TExternalLoggersForm.Create(nil);
   try
      dialog.FConfig.Assign(aConfig);
      if aId = '' then
         begin
         (* A new definition starts inactive: the operator chooses to send. *)
         definition := TExternalLoggerDefinition.Create;
         definition.Name := dialog.FConfig.NewDefinitionName;
         definition.ProviderId := 'DXKEEPER';
         definition.Address := '127.0.0.1';
         definition.Port := 52001;
         dialog.FConfig.Definitions.Add(definition);
         end
      else
         begin
         definition := dialog.FConfig.Find(aId);
         end;
      if definition = nil then
         begin
         Exit;
         end;
      dialog.FDefinition := definition;
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
