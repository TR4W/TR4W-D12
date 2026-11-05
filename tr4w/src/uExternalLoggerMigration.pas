unit uExternalLoggerMigration;
{$I tr4w.inc}
interface
uses uExternalLoggerConfig, uSettingsModel;
function SeedExternalLoggers(const aConfig: TExternalLoggerConfig;
   const aLegacy: TExternalLoggerSettings): boolean;
implementation
uses SysUtils;
function SeedExternalLoggers(const aConfig: TExternalLoggerConfig;
   const aLegacy: TExternalLoggerSettings): boolean;
var
   definition: TExternalLoggerDefinition;
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
