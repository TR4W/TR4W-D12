unit uExternalLoggerFactory;
{$I tr4w.inc}

{
  External Logger Factory Pattern Implementation

  Purpose: Centralized creation of external logger instances based on logger type

  Usage:
    var logger: TExternalLoggerService;
    logger := TExternalLoggerFactory.CreateLogger(lt_DXKeeper, 'localhost', 52001, @MyProcessMsg);
}

interface

uses
   uExternalLoggerBase, uExternalLoggerService, uExternalLogger,
   uExternalLoggerConfig, SysUtils;

type
   TExternalLoggerFactory = class
   private
      class function LoggerTypeToString(loggerType: ExternalLoggerType): string;
   public
      class function CreateLogger(loggerType: ExternalLoggerType;
                                   address: string;
                                   port: integer;
                                   msgCallback: TProcessMsgRef): TExternalLoggerService; overload;
      class function CreateLogger(const aDefinition: TExternalLoggerDefinition;
         aComputerId: AnsiChar): TExternalLoggerService; overload;
      class function GetSupportedLoggers: string;
      class function IsLoggerSupported(loggerType: ExternalLoggerType): boolean;
      (* THE CONFIG-FILE TOKEN FOR A TYPE, AND BACK.

        The settings model holds a STRING and knows nothing about what logger
        programs exist -- see ExternalLogger.LoggerType. This is where the two
        meet, and it is the only place: ExternalLoggerTypeSA is the same array
        the config parser used to match against.

        An unknown token answers lt_NoExternalLogger rather than raising: a
        settings file from a later build naming a logger this one does not
        have should leave the feature off, not stop the program. *)
      class function TokenToLoggerType(const aToken: string): ExternalLoggerType;
      class function LoggerTypeToToken(loggerType: ExternalLoggerType): string;
   end;

(*
  START THE EXTERNAL LOGGER, IF THE OPERATOR ASKED FOR ONE.

  THE CALLER SAYS NOTHING ABOUT LOGGER TYPES. NY4I, 2026-09-13: the main code
  should "just call the external logger and if the factory is not set, it would
  simply return" -- so this reads the setting, and a token of NONE, an unknown
  token or a disabled logger all mean the same thing here: return, quietly.

  It is a plain procedure rather than another class function because there is
  nothing to choose: the answer is in the settings.
*)
   EExternalLoggerFactoryException = class(Exception);

procedure StartExternalLoggerFromSettings;

(* APPLY A SAVED CONFIGURATION TO THE RUNNING LOGGERS (issue 233), main thread,
   called by Preferences after the file is written. Switches each running
   destination on or off and sets the delivery order (TExternalLoggers.
   ApplyConfiguration), then starts the delivery of any destination just
   switched on so its pending outbox resumes now rather than at the next QSO.
   Returns how many definitions still need a restart (new, or connection
   settings changed); 0 when no service is running. *)
function ApplyExternalLoggerConfiguration(const aConfig: TExternalLoggerConfig): integer;

implementation

uses
   Log4D, uWRLExternalLogger, uClubLogExternalLogger, uCloudlogExternalLogger,
   uACLogExternalLogger, uLogStore,
   uExternalLoggerRegistry, uExternalLoggers, uExternalLoggerMigration,
   uRadioConfigStore, uTR4WConfigFile,
   MainUnit,          (* externalLogger -- the process-wide instance *)
   uSettingsModel;    (* Settings.ExternalLogger, and the vocabulary *)

var
   logger: TLogLogger;

class function TExternalLoggerFactory.CreateLogger(
   const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
begin
   Result := CreateExternalLogger(aDefinition, aComputerId);
end;

class function TExternalLoggerFactory.CreateLogger(loggerType: ExternalLoggerType;
                                                    address: string;
                                                    port: integer;
                                                    msgCallback: TProcessMsgRef): TExternalLoggerService;
var
   definition: TExternalLoggerDefinition;
begin
   definition := TExternalLoggerDefinition.Create;
   try
      definition.ProviderId := LoggerTypeToToken(loggerType);
      definition.Name := LoggerTypeToString(loggerType);
      definition.Address := address;
      definition.Port := port;
      Result := CreateExternalLogger(definition, Settings.Computer.Id);
   finally
      definition.Free;
   end;
end;

class function TExternalLoggerFactory.LoggerTypeToString(loggerType: ExternalLoggerType): string;
begin
   case loggerType of
      lt_NoExternalLogger:  Result := 'None';
      lt_DXKeeper:          Result := 'DXKeeper';
      lt_ACLog:             Result := 'ACLog';
      lt_HRD:               Result := 'Ham Radio Deluxe';
      lt_WRL:               Result := 'World Radio League';
   else
      Result := 'Unknown';
   end;
end;

class function TExternalLoggerFactory.TokenToLoggerType(
   const aToken: string): ExternalLoggerType;
var
   t: ExternalLoggerType;
   wanted: string;
begin
   Result := lt_NoExternalLogger;
   wanted := UpperCase(Trim(aToken));
   for t := Low(ExternalLoggerType) to High(ExternalLoggerType) do
      begin
      if wanted = UpperCase(ExternalLoggerTypeSA[t]) then
         begin
         Result := t;
         Exit;
         end;
      end;
end;

class function TExternalLoggerFactory.LoggerTypeToToken(
   loggerType: ExternalLoggerType): string;
begin
   Result := ExternalLoggerTypeSA[loggerType];
end;

class function TExternalLoggerFactory.GetSupportedLoggers: string;
var
   i: integer;
begin
   Result := 'Supported external loggers:';
   for i := 0 to ExternalLoggerProviderCount - 1 do
      begin
      Result := Result + #13#10 + '  - ' + ExternalLoggerRegistration(i).DisplayName;
      end;
end;

class function TExternalLoggerFactory.IsLoggerSupported(loggerType: ExternalLoggerType): boolean;
var
   registration: TExternalLoggerRegistration;
begin
   Result := FindExternalLoggerRegistration(LoggerTypeToToken(loggerType), registration);
end;

procedure StartExternalLoggerFromSettings;
var
   store: TRadioConfigStore;
   definition: TExternalLoggerDefinition;
   manager: TExternalLoggers;
   id: AnsiString;
   error: string;
   procedure AddDefinition(aDefinition: TExternalLoggerDefinition; aActive: boolean);
   begin
      try
         manager.Add(aDefinition.DeliveryId,
            TExternalLoggerFactory.CreateLogger(aDefinition, Settings.Computer.Id), aActive,
            aDefinition.SettingsStamp);
      except
         on E: Exception do
            begin
            logger.Error('External logger %s could not start (%s)',
               [aDefinition.Name, E.ClassName]);
            end;
      end;
   end;

begin
   if externalLogger <> nil then
      begin
      Exit;
      end;
   store := TRadioConfigStore.Create;
   manager := TExternalLoggers.Create;
   try
      if FileExists(TR4WConfigFileName) and
         not store.LoadFromFile(TR4WConfigFileName, error) then
         begin
         logger.Error('External logger settings could not be loaded; delivery is disabled');
         Exit;
         end;
      if store.ExternalLoggers.Error <> '' then
         begin
         logger.Error('External logger settings are invalid; delivery is disabled');
         Exit;
         end;
      if SeedExternalLoggers(store.ExternalLoggers, Settings.ExternalLogger) then
         begin
         SaveConfig(TR4WConfigFileName, store, nil);
         end;
      for id in store.ExternalLoggers.ActiveIds do
         begin
         definition := store.ExternalLoggers.Find(string(id));
         AddDefinition(definition, True);
         end;
      for definition in store.ExternalLoggers.Definitions do
         begin
         if store.ExternalLoggers.ActiveIds.IndexOf(AnsiString(definition.Id)) < 0 then
            begin
            AddDefinition(definition, False);
            end;
         end;
      externalLogger := manager;
      manager := nil;
   finally
      manager.Free;
      store.Free;
   end;
end;

function ApplyExternalLoggerConfiguration(const aConfig: TExternalLoggerConfig): integer;
begin
   Result := 0;
   if externalLogger = nil then
      begin
      Exit;
      end;
   Result := externalLogger.ApplyConfiguration(aConfig);
   LogStoreStartExternalDelivery;
end;

(* The vocabulary the settings model offers and refuses by -- the subsystem's
  own array, passed BY NAME.

  By name rather than built here, because Lint-SpellingTables finds a table
  through the identifier at the registration. A list assembled in a loop is a
  list that lint cannot check, and building one cost four spellings their
  guard before this was written the other way. *)
procedure PublishLoggerVocabulary;
begin
   RegisterSettingAllowedValues('ExternalLogger.LoggerType',
                                ExternalLoggerTypeSA);
end;

initialization
   logger := TLogLogger.GetLogger('uExternalLoggerFactory');
   logger.Info('External Logger Factory initialized');
   PublishLoggerVocabulary;

finalization
   logger.Info('External Logger Factory finalized');

end.
