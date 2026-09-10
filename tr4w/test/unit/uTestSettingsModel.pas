unit uTestSettingsModel;
{$I ..\..\src\tr4w.inc}
(*
  The settings object -- published properties streamed by RTTI.

  WHAT THESE PIN, and why each one is worth a test rather than an assumption:

    * A ROUND TRIP.  The whole point of the shape is that the property name is
      the key and the property type is the type.  If that breaks, a setting is
      silently lost on the next save rather than reported.

    * AN ABSENT KEY LEAVES THE PROPERTY ALONE.  This is the entire
      forward-compatibility story: a settings file written by an older build
      must not reset a property that build had never heard of.  It is a
      behaviour of fpjsonrtti, not of TR4W, which is exactly why it is pinned
      here -- a library behaviour nobody verified is a library behaviour that
      changes under you.

    * DEFAULTS COME FROM Create.  A `default` directive tells the STREAMER it
      may omit a value; it initialises nothing.  These are the values the typed
      constants in logstuff.pas carried, and getting them wrong means a port
      number of zero rather than an absent setting.

    * THE LEGACY IMPORT READS THE OLD SPELLINGS.  It runs exactly once per
      installation, so a mistake in it is not self-correcting: it silently
      resets a station to defaults on the one start that mattered.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uJSON, uSettingsModel;

type
   TSettingsModelTests = class(TTestCase)
   protected
      procedure Test_DefaultsAreTheOnesTheGlobalsHad;
      procedure Test_RoundTripsThroughJSON;
      procedure Test_AnAbsentKeyLeavesThePropertyAlone;
      procedure Test_LegacyImportReadsTheOldCommandSpellings;
      procedure Test_LegacyImportKeepsWhatItCannotRead;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TSettingsModelTests.Test_DefaultsAreTheOnesTheGlobalsHad;
var
   s: TR4WSettings;
begin
   (* logstuff.pas declared these as typed constants:
        ExternalLoggerAddress: string[255] = '127.0.0.1';
        ExternalLoggerEnabled: boolean = false;
        ExternalLoggerPort: integer = 52001;
     A migration that changed any of them would move a working station. *)
   BeginTest('a new settings object carries the defaults the globals had');
   s := TR4WSettings.Create;
   try
      CheckEquals('127.0.0.1', s.ExternalLogger.Address, 'address');
      CheckEquals(52001, s.ExternalLogger.Port, 'port');
      CheckFalse(s.ExternalLogger.Enabled, 'enabled');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_RoundTripsThroughJSON;
var
   a, b: TR4WSettings;
   obj: TJSONObject;
begin
   BeginTest('every property survives a save and a load');
   a := TR4WSettings.Create;
   b := TR4WSettings.Create;
   try
      a.ExternalLogger.Address := '10.0.0.7';
      a.ExternalLogger.Port    := 52002;
      a.ExternalLogger.Enabled := True;

      obj := a.ToJSON;
      try
         (* NESTED, not flat. The group is a child object, which is what makes
           the file readable without a key list beside it. *)
         CheckTrue(obj.FindPath('ExternalLogger') <> nil,
                   'the group must appear as its own object');
         b.FromJSON(obj);
      finally
         obj.Free;
      end;

      CheckEquals('10.0.0.7', b.ExternalLogger.Address, 'address');
      CheckEquals(52002, b.ExternalLogger.Port, 'port');
      CheckTrue(b.ExternalLogger.Enabled, 'enabled');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TSettingsModelTests.Test_AnAbsentKeyLeavesThePropertyAlone;
var
   s: TR4WSettings;
   obj: TJSONObject;
begin
   (* THE FORWARD-COMPATIBILITY PIN. A file written by a build that never had
     a property must not reset it. Without this, every setting added would
     silently wipe itself on the first start against an older file. *)
   BeginTest('a key the file does not carry does not disturb the property');
   s := TR4WSettings.Create;
   try
      s.ExternalLogger.Address := '10.0.0.7';
      s.ExternalLogger.Port    := 52002;

      obj := TJSONObject(TJSONObject.ParseJSONValue(
                '{"ExternalLogger":{"Port":52099}}'));
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;

      CheckEquals(52099, s.ExternalLogger.Port, 'the key that WAS there applies');
      CheckEquals('10.0.0.7', s.ExternalLogger.Address,
                  'the key that was NOT there must not have been reset');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_LegacyImportReadsTheOldCommandSpellings;
var
   s: TR4WSettings;
   commands: TJSONObject;
begin
   (* The legacy section stores every value as TEXT whatever its type, because
     it is a rendering of config-file lines. This runs ONCE per installation,
     so a mistake here is not self-correcting. *)
   BeginTest('the one-time import reads the old command keys');
   s := TR4WSettings.Create;
   try
      commands := TJSONObject(TJSONObject.ParseJSONValue(
         '{"EXTERNAL LOGGER ADDRESS":"192.168.1.50",' +
         ' "EXTERNAL LOGGER PORT":"52010",' +
         ' "EXTERNAL LOGGER ENABLED":"TRUE"}'));
      CheckTrue(commands <> nil, 'the fixture must parse');
      try
         s.ImportLegacyCommands(commands);
      finally
         commands.Free;
      end;

      CheckEquals('192.168.1.50', s.ExternalLogger.Address, 'address');
      CheckEquals(52010, s.ExternalLogger.Port, 'a numeric value arrives as text');
      CheckTrue(s.ExternalLogger.Enabled, 'a boolean value arrives as text');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_LegacyImportKeepsWhatItCannotRead;
var
   s: TR4WSettings;
   commands: TJSONObject;
begin
   (* AN UNREADABLE VALUE IS NOT EVIDENCE THE OPERATOR MEANT THE DEFAULT, and
     a one-time import gets no second chance to ask. A word this code does not
     recognise must leave the setting where it was, not read as False or 0. *)
   BeginTest('the import keeps its current value rather than guessing');
   s := TR4WSettings.Create;
   try
      s.ExternalLogger.Address := 'keep.me';
      s.ExternalLogger.Port    := 52055;
      s.ExternalLogger.Enabled := True;

      commands := TJSONObject(TJSONObject.ParseJSONValue(
         '{"EXTERNAL LOGGER PORT":"not a number",' +
         ' "EXTERNAL LOGGER ENABLED":"perhaps"}'));
      CheckTrue(commands <> nil, 'the fixture must parse');
      try
         s.ImportLegacyCommands(commands);
      finally
         commands.Free;
      end;

      CheckEquals(52055, s.ExternalLogger.Port, 'an unparseable number');
      CheckTrue(s.ExternalLogger.Enabled, 'an unrecognised boolean word');
      CheckEquals('keep.me', s.ExternalLogger.Address,
                  'a key absent from the section entirely');
   finally
      s.Free;
   end;

   (* EXACTLY THE SPELLINGS THE OLD PARSER TOOK, AND NOTHING MORE.  Its
     ctBoolean arm tested `CustomCMD[1] in ['T','F']` and rejected everything
     else outright, so 'ON' and 'YES' and '1' never turned anything on.  A
     first draft of the import accepted all three; this is the test that
     refused it, and the reason it matters is that the import runs ONCE -- an
     invented acceptance would turn a value TR4W had always ignored into one
     that reconfigures a station on the single start where it counts. *)
   BeginTest('the import takes T and F, and refuses what the old parser refused');
   s := TR4WSettings.Create;
   try
      commands := TJSONObject(TJSONObject.ParseJSONValue(
         '{"EXTERNAL LOGGER ENABLED":"FALSE"}'));
      try
         s.ExternalLogger.Enabled := True;
         s.ImportLegacyCommands(commands);
      finally
         commands.Free;
      end;
      CheckFalse(s.ExternalLogger.Enabled, 'FALSE turns it off');
   finally
      s.Free;
   end;

   s := TR4WSettings.Create;
   try
      commands := TJSONObject(TJSONObject.ParseJSONValue(
         '{"EXTERNAL LOGGER ENABLED":"on"}'));
      try
         s.ImportLegacyCommands(commands);
      finally
         commands.Free;
      end;
      CheckFalse(s.ExternalLogger.Enabled,
                 'ON was never accepted and must not start being');
   finally
      s.Free;
   end;

   // Case is folded, because the value was written as TRUE or FALSE anyway.
   s := TR4WSettings.Create;
   try
      commands := TJSONObject(TJSONObject.ParseJSONValue(
         '{"EXTERNAL LOGGER ENABLED":"true"}'));
      try
         s.ImportLegacyCommands(commands);
      finally
         commands.Free;
      end;
      CheckTrue(s.ExternalLogger.Enabled, 'true, lower case');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.RunAllTests;
begin
   Test_DefaultsAreTheOnesTheGlobalsHad;
   Test_RoundTripsThroughJSON;
   Test_AnAbsentKeyLeavesThePropertyAlone;
   Test_LegacyImportReadsTheOldCommandSpellings;
   Test_LegacyImportKeepsWhatItCannotRead;
end;

end.
