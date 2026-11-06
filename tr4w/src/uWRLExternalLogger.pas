unit uWRLExternalLogger;
{$I tr4w.inc}
interface
uses uLogDatabase, VC, uDurableExternalLogger, uExternalDeliveryWorker, uQsoMyFacts,
   uExternalLoggerConfig, uExternalLoggerRegistry;
type
   TWRLExternalLogger = class(TDurableExternalLogger)
   private
      FImportLegacyWRL: boolean;
      FImportedFile: string;
   protected
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
                            const aSent: AnsiString): string; override;
      function CreateWorker: TExternalDeliveryWorker; override;
   public
      property ImportLegacyWRL: boolean read FImportLegacyWRL write FImportLegacyWRL;
      procedure AfterLogCommit(aDatabase: TLogDatabase); override;
      constructor Create(const aAccount, aLogbook, aApiKey: string;
                         aComputerId: AnsiChar; aEnabled: boolean;
                         const aLoggerId: string = 'WRL');
   end;
(* Reads the key's account and its logbooks. Worker-thread safe (see
   TLoggerChoiceLoader); a public name so a test can run it against a fake
   transport. *)
function LoadWRLLogbookChoices(const aWork: TExternalLoggerDefinition;
   const aChoices: TLoggerChoices): string;
implementation
uses uExternalDelivery, uExternalLoggerService, uWRLWorker, uWRLContact, PostUnit,
   uWRLClient, uAppStrings;
constructor TWRLExternalLogger.Create(const aAccount, aLogbook, aApiKey: string;
   aComputerId: AnsiChar; aEnabled: boolean; const aLoggerId: string);
begin
   inherited Create(aLoggerId, aAccount, aLogbook, aApiKey, aComputerId, aEnabled);
end;
procedure TWRLExternalLogger.AfterLogCommit(aDatabase: TLogDatabase);
var
   delivery: TExternalDelivery;
begin
   if FImportLegacyWRL and (FImportedFile <> aDatabase.FileName) then
      begin
      aDatabase.EndTransaction;
      delivery := TExternalDelivery.Create(aDatabase);
      try
         try
            delivery.MigrateLogger('WRL', FLoggerId, FAccount, FLogbook);
            aDatabase.EndTransaction;
            FImportedFile := aDatabase.FileName;
         except
            aDatabase.Rollback;
            raise;
         end;
      finally
         delivery.Free;
      end;
      end;
   inherited AfterLogCommit(aDatabase);
end;

function TWRLExternalLogger.BuildPayload(const aRecord: ContestExchange;
   const aFacts: TQsoMyFacts; const aSent: AnsiString): string;
begin
   Result := WRLContactFromADIF(ADIFContactForExternal(aRecord, aFacts, aSent),
                               UTF8Decode(aFacts.Call));
end;
function TWRLExternalLogger.CreateWorker: TExternalDeliveryWorker;
begin
   Result := TWRLWorker.Create(FFileName, FAccount, FApiKey, FLoggerId);
end;
function CreateWRL(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
var
   service: TWRLExternalLogger;
begin
   service := TWRLExternalLogger.Create(aDefinition.Account, aDefinition.Logbook,
      aDefinition.ApiKey, aComputerId, True, aDefinition.DeliveryId);
   service.ImportLegacyWRL := aDefinition.LegacyWRL;
   Result := service;
end;
function LoadWRLLogbookChoices(const aWork: TExternalLoggerDefinition;
   const aChoices: TLoggerChoices): string;
var
   client: TWRLClient;
   books: TWRLLogbookList;
   account, code: string;
   i: integer;
begin
   Result := '';
   client := TWRLClient.Create(aWork.ApiKey);
   books := TWRLLogbookList.Create(True);
   try
      if not WRLReadAccountId(client, account, code) then
         begin
         Result := code;
         Exit;
         end;
      if not WRLReadLogbooks(client, books, code) then
         begin
         Result := code;
         Exit;
         end;
      (* The account id is the key's own uid: derived here, never typed. *)
      aWork.Account := account;
      for i := 0 to books.Count - 1 do
         begin
         aChoices.Add(books[i].Id, books[i].Name);
         end;
   finally
      books.Free;
      client.Free;
   end;
end;
procedure DeclareWRLFields(const aFields: TLoggerFieldList);
begin
   aFields.AddSecret(LF_API_KEY, SLoggerFieldWRLKey, False);
   aFields.AddChoice(LF_LOGBOOK, LF_LOGBOOK_NAME, SLoggerFieldWRLLogbook,
      LoadWRLLogbookChoices);
   (* The id of the account and of the logbook are never fields. TR4W does not
      create logbooks: the operator makes one on the WRL website or app and
      picks it here. *)
end;
initialization
   RegisterExternalLogger('WRL', 'World Radio League', CreateWRL, DeclareWRLFields);
end.
