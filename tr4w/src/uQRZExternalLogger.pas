unit uQRZExternalLogger;
{$I tr4w.inc}
(* THE QRZ LOGBOOK PROVIDER (issue 310). Real-time delivery of each QSO to a QRZ
   logbook through its Logbook API (uQRZLogbookClient). Definition fields: the
   logbook's callsign (Logbook, the way Club Log keeps its callsign there; a QRZ
   logbook serves exactly one callsign, so one definition per callsign) and the
   API access key (ApiKey, in the OS vault like every secret, never logged). The
   callsign is also in DestinationFingerprint, so changing it parks the old
   backlog. New, changed and deleted contacts are all delivered. *)
interface
uses VC, uQsoMyFacts, uDurableExternalLogger, uExternalDeliveryWorker,
   uExternalDeliveryClient, uExternalLoggerConfig;
type
   TQRZWorker = class(TExternalDeliveryWorker)
   private
      FCall, FApiKey: string;
   protected
      function NewClient: TExternalDeliveryClient; override;
   public
      constructor Create(const aFileName, aLoggerId, aCall, aApiKey: string);
   end;
   TQRZExternalLogger = class(TDurableExternalLogger)
   protected
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
         const aSent: AnsiString): string; override;
      function CreateWorker: TExternalDeliveryWorker; override;
   public
      constructor Create(const aDefinition: TExternalLoggerDefinition; aComputerId: AnsiChar);
   end;
implementation
uses PostUnit, uQRZLogbookClient, uExternalLoggerRegistry, uExternalLoggerService,
   uAppStrings;
const
   QRZ_ACCOUNT = 'QRZ';
constructor TQRZWorker.Create(const aFileName, aLoggerId, aCall, aApiKey: string);
begin
   inherited Create(aFileName, QRZ_ACCOUNT, aLoggerId);
   FCall := aCall;
   FApiKey := aApiKey;
end;
function TQRZWorker.NewClient: TExternalDeliveryClient;
begin
   Result := TQRZLogbookClient.Create(FCall, FApiKey);
end;
constructor TQRZExternalLogger.Create(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar);
begin
   inherited Create(aDefinition.DeliveryId, QRZ_ACCOUNT, aDefinition.Logbook,
      aDefinition.ApiKey, aComputerId, True);
end;
function TQRZExternalLogger.BuildPayload(const aRecord: ContestExchange;
   const aFacts: TQsoMyFacts; const aSent: AnsiString): string;
begin
   Result := string(ADIFContactForExternal(aRecord, aFacts, aSent));
end;
function TQRZExternalLogger.CreateWorker: TExternalDeliveryWorker;
begin
   Result := TQRZWorker.Create(FFileName, FLoggerId, FLogbook, FApiKey);
end;
function CreateQRZ(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
begin
   Result := TQRZExternalLogger.Create(aDefinition, aComputerId);
end;
(* The logbook's callsign is stored in the definition's Logbook. *)
procedure DeclareQRZFields(const aFields: TLoggerFieldList);
begin
   aFields.AddText(LF_LOGBOOK, SLoggerFieldQRZCall, True);
   aFields.AddSecret(LF_API_KEY, SLoggerFieldQRZKey, False);
   aFields.AddVerifyServer;
end;
initialization
   RegisterExternalLogger('QRZ', 'QRZ Logbook', CreateQRZ, DeclareQRZFields);
end.
