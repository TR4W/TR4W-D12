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
   uExternalDeliveryClient, uExternalLoggerConfig, uExternalLoggerRegistry;
type
   TCloudlogWorker = class(TExternalDeliveryWorker)
   private
      FBaseUrl, FProfileId, FApiKey: string;
      FAllowInsecure: boolean;
   protected
      function NewClient: TExternalDeliveryClient; override;
   public
      constructor Create(const aFileName, aLoggerId, aBaseUrl, aProfileId,
         aApiKey: string);
      (* The definition's "Allow insecure (plain http)" box, handed to every
         client this worker makes. *)
      property AllowInsecure: boolean read FAllowInsecure write FAllowInsecure;
   end;
   TCloudlogExternalLogger = class(TDurableExternalLogger)
   private
      FBaseUrl: string;
      FAllowInsecure: boolean;
   protected
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
         const aSent: AnsiString): string; override;
      function CreateWorker: TExternalDeliveryWorker; override;
      (* No edit call exists: 'resend all' must not create a delivered contact a second time. *)
      function CanUpdateDelivered: boolean; override;
   public
      constructor Create(const aDefinition: TExternalLoggerDefinition; aComputerId: AnsiChar);
   end;
(* The Station profile's "Find..." (TLoggerFieldDescriptor.Finder). Worker-thread
   safe; a public name so a test can run it against a fake transport. '' = the
   list is filled, else the sentence to show. *)
function LoadCloudlogStations(const aWork: TExternalLoggerDefinition;
   const aChoices: TLoggerChoices): string;
implementation
uses PostUnit, uCloudlogClient, uExternalLoggerService,
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
   Result.AllowInsecure := FAllowInsecure;
end;
function TCloudlogExternalLogger.CanUpdateDelivered: boolean;
begin
   Result := False;
end;
constructor TCloudlogExternalLogger.Create(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar);
begin
   inherited Create(aDefinition.DeliveryId, CLOUDLOG_ACCOUNT, aDefinition.Logbook,
      aDefinition.ApiKey, aComputerId, True);
   FBaseUrl := aDefinition.URL;
   FAllowInsecure := aDefinition.AllowInsecure;
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
   TCloudlogWorker(Result).AllowInsecure := FAllowInsecure;
end;
function CreateCloudlog(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
begin
   Result := TCloudlogExternalLogger.Create(aDefinition, aComputerId);
end;
function LoadCloudlogStations(const aWork: TExternalLoggerDefinition;
   const aChoices: TLoggerChoices): string;
var
   client: TCloudlogClient;
begin
   (* The editor's unsaved address, key and Allow insecure / certificate
      choices, exactly what a delivery would use. One read; nothing is sent
      that is not a read. *)
   client := TCloudlogClient.Create(aWork.URL, '', aWork.ApiKey);
   try
      client.VerifyServer := aWork.VerifyServer;
      client.Destination := aWork.Name;
      client.AllowInsecure := aWork.AllowInsecure;
      Result := client.ReadStations(aChoices);
   finally
      client.Free;
   end;
end;

(* The station profile id is stored in the definition's Logbook. *)
procedure DeclareCloudlogFields(const aFields: TLoggerFieldList);
begin
   aFields.AddText(LF_URL, SLoggerFieldCloudlogUrl, True);
   aFields.AddSecret(LF_API_KEY, SLoggerFieldCloudlogKey, False);
   (* A plain text row with a Find... button: the id is the station location's
      NUMBER and the editor can list them (issue: NY4I 2026-11-24). *)
   aFields.AddText(LF_LOGBOOK, SLoggerFieldCloudlogProfile, True).Finder :=
      LoadCloudlogStations;
   aFields.AddVerifyServer;
   (* NY4I, 2026-11-24: a Cloudlog / Wavelog on a home network is often plain
      http. Refused unless this box is ticked; the editor says why. *)
   aFields.AddAllowInsecure;
end;
initialization
   RegisterExternalLogger('CLOUDLOG', 'Cloudlog / Wavelog', CreateCloudlog,
      DeclareCloudlogFields);
end.
