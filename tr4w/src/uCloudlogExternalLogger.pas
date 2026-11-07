unit uCloudlogExternalLogger;
{$I tr4w.inc}
(* THE CLOUDLOG / WAVELOG PROVIDER (issue 204). One provider for both programs:
   they share one API (uCloudlogClient). Definition fields: the site address
   (URL), the API key (ApiKey, in the vault like every secret) and the station
   profile id (Logbook, the way Club Log keeps its callsign there). The address
   and the profile are in DestinationFingerprint, so changing either parks the
   old backlog instead of sending it to a different log.

   NEW CONTACTS ONLY, BY NECESSITY: neither server has an edit or delete call.
   See uCloudlogClient and docs/EXTERNAL_LOGGERS_DESIGN.md. *)
interface
uses VC, uQsoMyFacts, uDurableExternalLogger, uExternalDeliveryWorker,
   uExternalDeliveryClient, uExternalLoggerConfig;
type
   TCloudlogWorker = class(TExternalDeliveryWorker)
   private
      FBaseUrl, FProfileId, FApiKey: string;
   protected
      function NewClient: TExternalDeliveryClient; override;
   public
      constructor Create(const aFileName, aLoggerId, aBaseUrl, aProfileId,
         aApiKey: string);
   end;
   TCloudlogExternalLogger = class(TDurableExternalLogger)
   private
      FBaseUrl: string;
   protected
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
         const aSent: AnsiString): string; override;
      function CreateWorker: TExternalDeliveryWorker; override;
   public
      constructor Create(const aDefinition: TExternalLoggerDefinition; aComputerId: AnsiChar);
   end;
implementation
uses PostUnit, uCloudlogClient, uExternalLoggerRegistry, uExternalLoggerService,
   uAppStrings;
const
   (* The durable account label; the destination is told apart by the logger id
      (which carries the address and profile fingerprint). *)
   CLOUDLOG_ACCOUNT = 'Cloudlog';
constructor TCloudlogWorker.Create(const aFileName, aLoggerId, aBaseUrl,
   aProfileId, aApiKey: string);
begin
   inherited Create(aFileName, CLOUDLOG_ACCOUNT, aLoggerId);
   FBaseUrl := aBaseUrl;
   FProfileId := aProfileId;
   FApiKey := aApiKey;
end;
function TCloudlogWorker.NewClient: TExternalDeliveryClient;
begin
   Result := TCloudlogClient.Create(FBaseUrl, FProfileId, FApiKey);
end;
constructor TCloudlogExternalLogger.Create(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar);
begin
   inherited Create(aDefinition.DeliveryId, CLOUDLOG_ACCOUNT, aDefinition.Logbook,
      aDefinition.ApiKey, aComputerId, True);
   FBaseUrl := aDefinition.URL;
end;
function TCloudlogExternalLogger.BuildPayload(const aRecord: ContestExchange;
   const aFacts: TQsoMyFacts; const aSent: AnsiString): string;
begin
   Result := string(ADIFContactForExternal(aRecord, aFacts, aSent));
end;
function TCloudlogExternalLogger.CreateWorker: TExternalDeliveryWorker;
begin
   Result := TCloudlogWorker.Create(FFileName, FLoggerId, FBaseUrl, FLogbook,
      FApiKey);
end;
function CreateCloudlog(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
begin
   Result := TCloudlogExternalLogger.Create(aDefinition, aComputerId);
end;
(* The station profile id is stored in the definition's Logbook. *)
procedure DeclareCloudlogFields(const aFields: TLoggerFieldList);
begin
   aFields.AddText(LF_URL, SLoggerFieldCloudlogUrl, True);
   aFields.AddSecret(LF_API_KEY, SLoggerFieldCloudlogKey, False);
   aFields.AddText(LF_LOGBOOK, SLoggerFieldCloudlogProfile, True);
end;
initialization
   RegisterExternalLogger('CLOUDLOG', 'Cloudlog / Wavelog', CreateCloudlog,
      DeclareCloudlogFields);
end.
