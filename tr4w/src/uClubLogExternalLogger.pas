unit uClubLogExternalLogger;
{$I tr4w.inc}
interface
uses VC, uQsoMyFacts, uDurableExternalLogger, uExternalDeliveryWorker,
   uExternalDeliveryClient, uExternalLoggerConfig;
type
   TClubLogWorker = class(TExternalDeliveryWorker)
   private
      FCall, FApiKey: string;
   protected
      function NewClient: TExternalDeliveryClient; override;
   public
      constructor Create(const aFileName, aLoggerId, aCall,
         aApiKey: string);
   end;
   TClubLogExternalLogger = class(TDurableExternalLogger)
   protected
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
         const aSent: AnsiString): string; override;
      function CreateWorker: TExternalDeliveryWorker; override;
   public
      constructor Create(const aDefinition: TExternalLoggerDefinition; aComputerId: AnsiChar);
   end;
implementation
uses PostUnit, uClubLogClient, uExternalLoggerRegistry, uExternalLoggerService,
   uAppStrings;
constructor TClubLogWorker.Create(const aFileName, aLoggerId, aCall,
   aApiKey: string);
begin
   inherited Create(aFileName, 'ClubLog', aLoggerId);
   FCall := aCall;
   FApiKey := aApiKey;
end;
function TClubLogWorker.NewClient: TExternalDeliveryClient;
begin
   Result := TClubLogClient.Create(FCall, FApiKey);
end;
constructor TClubLogExternalLogger.Create(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar);
begin
   inherited Create(aDefinition.DeliveryId, 'ClubLog', aDefinition.Logbook,
      aDefinition.ApiKey, aComputerId, True);
end;
function TClubLogExternalLogger.BuildPayload(const aRecord: ContestExchange;
   const aFacts: TQsoMyFacts; const aSent: AnsiString): string;
begin
   Result := string(ADIFContactForExternal(aRecord, aFacts, aSent));
end;
function TClubLogExternalLogger.CreateWorker: TExternalDeliveryWorker;
begin
   Result := TClubLogWorker.Create(FFileName, FLoggerId, FLogbook,
      FApiKey);
end;
function CreateClubLog(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
begin
   Result := TClubLogExternalLogger.Create(aDefinition, aComputerId);
end;
(* The destination callsign is stored in the definition's Logbook. *)
procedure DeclareClubLogFields(const aFields: TLoggerFieldList);
begin
   aFields.AddText(LF_LOGBOOK, SLoggerFieldClubLogCall, True);
   aFields.AddSecret(LF_API_KEY, SLoggerFieldClubLogToken, False);
end;
initialization
   RegisterExternalLogger('CLUBLOG', 'Club Log', CreateClubLog, DeclareClubLogFields);
end.
