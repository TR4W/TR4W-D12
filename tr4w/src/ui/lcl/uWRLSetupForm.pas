unit uWRLSetupForm;
{$I ..\..\tr4w.inc}

interface

function ConfigureWRL(var aApiKey, aAccountId, aLogbookId: string): boolean;
(* The same dialog, also returning the chosen logbook's NAME. *)
function ConfigureWRLLogbook(var aApiKey, aAccountId, aLogbookId,
   aLogbookName: string): boolean;

implementation

uses
   SysUtils, Classes, SyncObjs, Forms, Controls, StdCtrls, ExtCtrls,
   uWRLClient, uExternalDelivery, uAppStrings, uPasswordReveal,
   uExternalLoggerConfig, uWRLExternalLogger;

type
   TWRLSetupTask = class(TThread)
   private
      FKey, FNewName: string;
      function StopRequested: boolean;
   protected
      procedure Execute; override;
   public
      Done: TEvent;
      Books: TWRLLogbookList;
      AccountId, CreatedId, ErrorCode: string;
      Uncertain: boolean;
      constructor Create(const aKey, aNewName: string);
      destructor Destroy; override;
   end;

   TWRLSetupForm = class(TForm)
   published
      FKey, FNewName: TEdit;
      FBooks: TComboBox;
      FStatus: TLabel;
      FValidate, FCreate, FUse: TButton;
      btnCancel: TButton;
      lblApiKey, lblLogbook, lblNewName: TLabel;
      FTimer: TTimer;
      procedure ValidateClick(Sender: TObject);
      procedure CreateClick(Sender: TObject);
      procedure UseClick(Sender: TObject);
      procedure KeyChanged(Sender: TObject);
      procedure Tick(Sender: TObject);
      procedure CanClose(Sender: TObject; var aCanClose: boolean);
   private
      FTask: TWRLSetupTask;
      FAccountId, FChosenId, FChosenName: string;
      FBookIds: array of string;
      FCancelRequested: boolean;
      FQuiet: boolean;
      procedure StartTask(const aNewName: string; aQuiet: boolean = False);
      procedure SetBusy(aBusy: boolean);
      procedure ClearBooks;
   public
      procedure LoadStoredKey;
      constructor Create(aOwner: TComponent); override;
      destructor Destroy; override;
   end;

{$R *.lfm}

constructor TWRLSetupTask.Create(const aKey, aNewName: string);
begin
   inherited Create(True);
   FKey := aKey;
   FNewName := aNewName;
   Books := TWRLLogbookList.Create(True);
   Done := TEvent.Create(nil, True, False, '');
end;

destructor TWRLSetupTask.Destroy;
begin
   Terminate;
   if not Suspended then
      begin
      WaitFor;
      end;
   inherited Destroy;
   Done.Free;
   Books.Free;
end;

function TWRLSetupTask.StopRequested: boolean;
begin
   Result := Terminated;
end;

procedure TWRLSetupTask.Execute;
var
   client: TWRLClient;
   answer: TWRLResult;
   creating: boolean;
begin
   creating := False;
   client := TWRLClient.Create(FKey);
   try
      try
         if not WRLReadAccountId(client, AccountId, ErrorCode) then
            begin
            Exit;
            end;
         if Terminated then
            begin
            Exit;
            end;
         if FNewName <> '' then
            begin
            creating := True;
            answer := client.CreateLogbook(FNewName);
            creating := False;
            if answer.Outcome <> doConfirmed then
               begin
               Uncertain := answer.Outcome = doUncertain;
               ErrorCode := answer.ErrorCode;
               Exit;
               end;
            CreatedId := answer.RemoteId;
            end;
         WRLReadLogbooks(client, Books, ErrorCode, StopRequested);
      except
         on E: Exception do
            begin
            ErrorCode := 'INVALID_RESPONSE';
            Uncertain := creating;
            end;
      end;
   finally
      client.Free;
      Done.SetEvent;
   end;
end;

constructor TWRLSetupForm.Create(aOwner: TComponent);
begin
   inherited Create(aOwner);
   Caption := SWRLTitle;
   lblApiKey.Caption := SWRLApiKey;
   lblLogbook.Caption := SWRLLogbook;
   lblNewName.Caption := SWRLNewLogbook;
   AttachPasswordReveal(FKey);
   FValidate.Caption := SWRLValidate;
   FCreate.Caption := SWRLCreate;
   FUse.Caption := SWRLUse;
   btnCancel.Caption := SWRLCancel;
end;

destructor TWRLSetupForm.Destroy;
begin
   if FTimer <> nil then
      begin
      FTimer.Enabled := False;
      end;
   FTask.Free;
   inherited Destroy;
end;

procedure TWRLSetupForm.SetBusy(aBusy: boolean);
begin
   FKey.Enabled := not aBusy;
   FValidate.Enabled := not aBusy;
   FNewName.Enabled := not aBusy;
   FCreate.Enabled := not aBusy and (FAccountId <> '');
   FBooks.Enabled := not aBusy;
   FUse.Enabled := not aBusy and (FAccountId <> '') and (Length(FBookIds) > 0);
   FTimer.Enabled := aBusy;
end;

(* The list belongs to the key it was loaded with: a different key must
   not offer the old key's logbooks. *)
procedure TWRLSetupForm.ClearBooks;
begin
   FBooks.Items.Clear;
   FBooks.ItemIndex := -1;
   SetLength(FBookIds, 0);
   FUse.Enabled := False;
end;

procedure TWRLSetupForm.KeyChanged(Sender: TObject);
begin
   FAccountId := '';
   ClearBooks;
   FCreate.Enabled := False;
end;

(* Called once by ConfigureWRL after the stored key is in the edit. The same
   task as the Validate button, but a failure is silent: no status text, an
   empty list. The form's CanClose / destructor already wait for the task. *)
procedure TWRLSetupForm.LoadStoredKey;
begin
   StartTask('', True);
end;

procedure TWRLSetupForm.StartTask(const aNewName: string; aQuiet: boolean);
begin
   if (FTask <> nil) or (Trim(FKey.Text) = '') then
      begin
      Exit;
      end;
   FQuiet := aQuiet;
   FTask := TWRLSetupTask.Create(Trim(UTF8Decode(FKey.Text)), aNewName);
   FStatus.Caption := SWRLWorking;
   SetBusy(True);
   FTask.Start;
end;

procedure TWRLSetupForm.ValidateClick(Sender: TObject);
begin
   StartTask('');
end;

procedure TWRLSetupForm.CreateClick(Sender: TObject);
begin
   if Trim(FNewName.Text) <> '' then
      begin
      StartTask(Trim(UTF8Decode(FNewName.Text)));
      end;
end;

procedure TWRLSetupForm.UseClick(Sender: TObject);
begin
   if FBooks.ItemIndex >= 0 then
      begin
      FChosenId := FBookIds[FBooks.ItemIndex];
      FChosenName := UTF8Decode(FBooks.Items[FBooks.ItemIndex]);
      ModalResult := mrOK;
      end;
end;

procedure TWRLSetupForm.Tick(Sender: TObject);
var
   i, selected: integer;
begin
   if (FTask = nil) or (FTask.Done.WaitFor(0) <> wrSignaled) then
      begin
      Exit;
      end;
   FTimer.Enabled := False;
   if FTask.ErrorCode <> '' then
      begin
      if FQuiet then
         begin
         FStatus.Caption := '';
         end
      else
         begin
         FStatus.Caption := Format(SWRLFailure, [UTF8Encode(FTask.ErrorCode)]);
         if FTask.Uncertain then
            begin
            FStatus.Caption := SWRLUncertain;
            end;
         end;
      FAccountId := '';
      ClearBooks;
      end
   else
      begin
      FAccountId := FTask.AccountId;
      FBooks.Items.Clear;
      SetLength(FBookIds, FTask.Books.Count);
      selected := -1;
      for i := 0 to FTask.Books.Count - 1 do
         begin
         FBooks.Items.Add(UTF8Encode(FTask.Books[i].Name));
         FBookIds[i] := FTask.Books[i].Id;
         if (FBookIds[i] = FChosenId) or (FBookIds[i] = FTask.CreatedId) then
            begin
            selected := i;
            end;
         end;
      if (selected < 0) and (FBooks.Items.Count > 0) then
         begin
         selected := 0;
         end;
      FBooks.ItemIndex := selected;
      FStatus.Caption := SWRLReady;
      end;
   FreeAndNil(FTask);
   SetBusy(False);
   if FCancelRequested then
      begin
      ModalResult := mrCancel;
      end;
end;

procedure TWRLSetupForm.CanClose(Sender: TObject; var aCanClose: boolean);
begin
   aCanClose := FTask = nil;
   if FTask <> nil then
      begin
      FCancelRequested := True;
      FTask.Terminate;
      end;
end;

function ConfigureWRLLogbook(var aApiKey, aAccountId, aLogbookId,
   aLogbookName: string): boolean;
var
   dialog: TWRLSetupForm;
begin
   dialog := TWRLSetupForm.Create(Application.MainForm);
   try
      dialog.FKey.Text := UTF8Encode(aApiKey);
      dialog.FChosenId := aLogbookId;
      dialog.LoadStoredKey;
      Result := dialog.ShowModal = mrOK;
      if Result then
         begin
         aApiKey := Trim(UTF8Decode(dialog.FKey.Text));
         aAccountId := dialog.FAccountId;
         aLogbookId := dialog.FChosenId;
         aLogbookName := dialog.FChosenName;
         end;
   finally
      dialog.Free;
   end;
end;

function ConfigureWRL(var aApiKey, aAccountId, aLogbookId: string): boolean;
var
   name: string;
begin
   (* The old Preferences page has no place for the name. *)
   name := '';
   Result := ConfigureWRLLogbook(aApiKey, aAccountId, aLogbookId, name);
end;

function WRLSetupForDefinition(const aWork: TExternalLoggerDefinition): boolean;
var
   key, account, book, name: string;
begin
   key := aWork.ApiKey;
   account := aWork.Account;
   book := aWork.Logbook;
   name := aWork.LogbookName;
   Result := ConfigureWRLLogbook(key, account, book, name);
   if Result then
      begin
      aWork.ApiKey := key;
      aWork.Account := account;
      aWork.Logbook := book;
      aWork.LogbookName := name;
      end;
end;

initialization
   (* The WRL provider is declared without any LCL dependency; the dialog is
      attached here, by the unit that owns it. *)
   WRLSetupAction := WRLSetupForDefinition;

end.
