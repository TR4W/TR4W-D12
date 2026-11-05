unit uWRLExternalLogger;
{$I tr4w.inc}
interface
uses uLogDatabase, VC, uDurableExternalLogger, uExternalDeliveryWorker, uQsoMyFacts;
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
implementation
uses uExternalDelivery, uExternalLoggerRegistry, uExternalLoggerConfig, uExternalLoggerService, uWRLWorker, uWRLContact, PostUnit;
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
initialization
   RegisterExternalLogger('WRL', 'World Radio League', CreateWRL,
      [lcfAccount, lcfLogbook, lcfApiKey]);
end.
