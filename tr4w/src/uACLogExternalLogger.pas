unit uACLogExternalLogger;
{$I tr4w.inc}
(* THE AC LOG (N3FJP) PROVIDER (issue 33). Definition fields: the host AC Log
   runs on and its TCP API port (default 1100), the same two rows DXKeeper has.
   There is no key, account or logbook to enter. The durable owner still wants
   a destination name and a non-empty credential slot, so the destination is
   "host:port" (the address and port are in DestinationFingerprint, so changing
   either parks the old backlog instead of sending it to another machine) and
   the credential slot holds a fixed placeholder that is never sent anywhere.

   NEW CONTACTS ONLY, BY NECESSITY: the AC Log API has no edit or delete call.
   See uACLogClient and docs/EXTERNAL_LOGGERS_DESIGN.md. *)
interface
uses VC, uQsoMyFacts, uDurableExternalLogger, uExternalDeliveryWorker,
   uExternalDeliveryClient, uExternalLoggerConfig;
const
   ACLOG_DEFAULT_PORT = 1100;
type
   TACLogWorker = class(TExternalDeliveryWorker)
   private
      FHost: string;
      FPort: integer;
   protected
      function NewClient: TExternalDeliveryClient; override;
   public
      constructor Create(const aFileName, aLoggerId, aHost: string; aPort: integer);
   end;
   TACLogExternalLogger = class(TDurableExternalLogger)
   private
      FHost: string;
      FPort: integer;
   protected
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
         const aSent: AnsiString): string; override;
      function CreateWorker: TExternalDeliveryWorker; override;
   public
      constructor Create(const aDefinition: TExternalLoggerDefinition; aComputerId: AnsiChar);
   end;
implementation
uses SysUtils, PostUnit, uACLogClient, uExternalLoggerRegistry, uExternalLoggerService,
   uAppStrings;
const
   ACLOG_ACCOUNT = 'ACLog';
   (* TDurableExternalLogger starts no worker without a credential. AC Log has
      none; this is only that slot's non-empty value. *)
   ACLOG_NO_CREDENTIAL = 'none';
constructor TACLogWorker.Create(const aFileName, aLoggerId, aHost: string; aPort: integer);
begin
   inherited Create(aFileName, ACLOG_ACCOUNT, aLoggerId);
   FHost := aHost;
   FPort := aPort;
end;
function TACLogWorker.NewClient: TExternalDeliveryClient;
begin
   Result := TACLogClient.Create(FHost, FPort);
end;
constructor TACLogExternalLogger.Create(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar);
begin
   inherited Create(aDefinition.DeliveryId, ACLOG_ACCOUNT,
      Trim(aDefinition.Address) + ':' + string(IntToStr(aDefinition.Port)),
      ACLOG_NO_CREDENTIAL, aComputerId, True);
   FHost := Trim(aDefinition.Address);
   FPort := aDefinition.Port;
end;
function TACLogExternalLogger.BuildPayload(const aRecord: ContestExchange;
   const aFacts: TQsoMyFacts; const aSent: AnsiString): string;
begin
   Result := string(ADIFContactForExternal(aRecord, aFacts, aSent));
end;
function TACLogExternalLogger.CreateWorker: TExternalDeliveryWorker;
begin
   Result := TACLogWorker.Create(FFileName, FLoggerId, FHost, FPort);
end;
function CreateACLog(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
begin
   Result := TACLogExternalLogger.Create(aDefinition, aComputerId);
end;
procedure DeclareACLogFields(const aFields: TLoggerFieldList);
begin
   aFields.AddText(LF_ADDRESS, SLoggerFieldHost, True);
   aFields.AddPort(LF_PORT, SLoggerFieldPort);
end;
initialization
   RegisterExternalLogger('ACLOG', 'ACLog', CreateACLog, DeclareACLogFields,
      ACLOG_DEFAULT_PORT);
end.
