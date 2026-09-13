unit uExternalLoggerFactory;
{$I tr4w.inc}

{
  External Logger Factory Pattern Implementation

  Purpose: Centralized creation of external logger instances based on logger type

  Usage:
    var logger: TExternalLoggerBase;
    logger := TExternalLoggerFactory.CreateLogger(lt_DXKeeper, 'localhost', 52001, @MyProcessMsg);
    logger.Connect;
}

interface

uses
   uExternalLoggerBase, uExternalLogger, SysUtils;

type
   TExternalLoggerFactory = class
   private
      class function LoggerTypeToString(loggerType: ExternalLoggerType): string;
   public
      class function CreateLogger(loggerType: ExternalLoggerType;
                                   address: string;
                                   port: integer;
                                   msgCallback: TProcessMsgRef): TExternalLoggerBase;
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

implementation

uses
   Log4D,
   MainUnit,          (* externalLogger -- the process-wide instance *)
   uSettingsModel;    (* Settings.ExternalLogger, and the vocabulary *)

var
   logger: TLogLogger;

class function TExternalLoggerFactory.CreateLogger(loggerType: ExternalLoggerType;
                                                    address: string;
                                                    port: integer;
                                                    msgCallback: TProcessMsgRef): TExternalLoggerBase;
var
   extLogger: TExternalLogger;
begin
   Result := nil;

   logger.Info('[ExternalLoggerFactory] Creating logger: Type=%s, Address=%s, Port=%d',
               [LoggerTypeToString(loggerType), address, port]);

   case loggerType of
      lt_NoExternalLogger:
         begin
         raise EExternalLoggerFactoryException.Create('Cannot create logger of type NoExternalLogger');
         end;

      lt_DXKeeper:
         begin
         extLogger := TExternalLogger.Create(loggerType);
         extLogger.loggerAddress := address;
         extLogger.loggerPort := port;
         extLogger.loggerID := 'DXKeeper';
         Result := extLogger;
         logger.Info('[ExternalLoggerFactory] Created DXKeeper logger instance');
         end;

      lt_ACLog:
         begin
         extLogger := TExternalLogger.Create(loggerType);
         extLogger.loggerAddress := address;
         extLogger.loggerPort := port;
         extLogger.loggerID := 'ACLog';
         Result := extLogger;
         logger.Info('[ExternalLoggerFactory] Created ACLog logger instance');
         logger.Warn('[ExternalLoggerFactory] ACLog implementation is incomplete');
         end;

      lt_HRD:
         begin
         extLogger := TExternalLogger.Create(loggerType);
         extLogger.loggerAddress := address;
         extLogger.loggerPort := port;
         extLogger.loggerID := 'HRD';
         Result := extLogger;
         logger.Info('[ExternalLoggerFactory] Created HRD logger instance');
         logger.Warn('[ExternalLoggerFactory] HRD implementation is incomplete');
         end;

      else
         begin
         raise EExternalLoggerFactoryException.CreateFmt('Unknown logger type: %d', [Ord(loggerType)]);
         end;
   end;
end;

class function TExternalLoggerFactory.LoggerTypeToString(loggerType: ExternalLoggerType): string;
begin
   case loggerType of
      lt_NoExternalLogger:  Result := 'None';
      lt_DXKeeper:          Result := 'DXKeeper';
      lt_ACLog:             Result := 'ACLog';
      lt_HRD:               Result := 'Ham Radio Deluxe';
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
begin
   Result := 'Supported external loggers:'#13#10 +
             '  - DXKeeper (implemented)'#13#10 +
             '  - ACLog (planned)'#13#10 +
             '  - Ham Radio Deluxe / HRD (planned)';
end;

class function TExternalLoggerFactory.IsLoggerSupported(loggerType: ExternalLoggerType): boolean;
begin
   // Currently only DXKeeper is fully implemented
   Result := (loggerType = lt_DXKeeper);
end;

procedure StartExternalLoggerFromSettings;
var
   chosen: ExternalLoggerType;
begin
   chosen := TExternalLoggerFactory.TokenToLoggerType(
                Settings.ExternalLogger.LoggerType);
   if chosen = lt_NoExternalLogger then
      begin
      Exit;
      end;

   externalLogger := TExternalLogger.Create(chosen);
   externalLogger.loggerPort    := Settings.ExternalLogger.Port;
   externalLogger.loggerAddress := Settings.ExternalLogger.Address;
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
