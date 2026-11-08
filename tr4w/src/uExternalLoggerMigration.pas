unit uExternalLoggerMigration;
{$I tr4w.inc}
interface
uses uExternalLoggerConfig, uSettingsModel;
function SeedExternalLoggers(const aConfig: TExternalLoggerConfig;
   const aLegacy: TExternalLoggerSettings): boolean;
implementation
uses SysUtils, uExternalLoggerRegistry;
const
   (* What the legacy single-logger setting held when nobody had typed a port:
      DXKeeper's. A legacy token for another provider that still has it never
      had a port chosen, so that provider's own default applies. *)
   LEGACY_UNSET_PORT = DXKEEPER_DEFAULT_PORT;
function SeedExternalLoggers(const aConfig: TExternalLoggerConfig;
   const aLegacy: TExternalLoggerSettings): boolean;
var
   definition: TExternalLoggerDefinition;
   registration: TExternalLoggerRegistration;
begin
   Result := not aConfig.Present;
   if not Result then
      begin
      Exit;
      end;
   aConfig.Present := True;
   if (aLegacy.LoggerType = 'NONE') or (aLegacy.LoggerType = '') then
      begin
      Exit;
      end;
   definition := TExternalLoggerDefinition.Create;
   definition.Name := aLegacy.LoggerType;
   definition.ProviderId := UpperCase(aLegacy.LoggerType);
   definition.Address := aLegacy.Address;
   definition.Port := aLegacy.Port;
   if (aLegacy.Port = LEGACY_UNSET_PORT) and
      FindExternalLoggerRegistration(definition.ProviderId, registration) and
      (registration.DefaultPort <> 0) then
      begin
      definition.Port := registration.DefaultPort;
      end;
   definition.ApiKey := aLegacy.ApiKey;
   definition.Account := aLegacy.AccountId;
   definition.Logbook := aLegacy.LogbookId;
   definition.LegacyWRL := definition.ProviderId = 'WRL';
   definition.LegacySecretPending := definition.LegacyWRL and (definition.ApiKey = '');
   aConfig.Definitions.Add(definition);
   if aLegacy.Enabled then
      begin
      aConfig.ActiveIds.Add(AnsiString(definition.Id));
      end;
end;
end.
