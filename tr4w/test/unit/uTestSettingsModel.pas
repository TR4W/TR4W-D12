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
   SysUtils, Classes, uTR4WTestFramework, uJSON, uSettingsModel;

type
   TSettingsModelTests = class(TTestCase)
   protected
      procedure Test_DefaultsAreTheOnesTheGlobalsHad;
      procedure Test_RoundTripsThroughJSON;
      procedure Test_AnAbsentKeyLeavesThePropertyAlone;
      procedure Test_LegacyImportReadsTheOldCommandSpellings;
      procedure Test_LegacyImportKeepsWhatItCannotRead;
      procedure Test_CommandNamesDeriveFromThePropertyPaths;
      procedure Test_SetAndGetByCommandName;
      procedure Test_AnUnknownCommandIsRefused;
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

procedure TSettingsModelTests.Test_CommandNamesDeriveFromThePropertyPaths;
var
   s: TR4WSettings;
   names: TStringList;
begin
   (* THE DERIVATION IS THE WHOLE MAPPING, so it is the thing to pin.

     Every setting that moves here has to keep answering to the name a config
     file, a contest .cfg and a multi-op peer already use.  There is no table
     to review -- the name comes from the property path -- so this test IS the
     review, and it must name the legacy spellings literally rather than
     recomputing them, or it would agree with any rule at all. *)
   BeginTest('each property answers to the legacy command name');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.OwnsCommand('EXTERNAL LOGGER ADDRESS'), 'address');
      CheckTrue(s.OwnsCommand('EXTERNAL LOGGER PORT'),    'port');
      CheckTrue(s.OwnsCommand('EXTERNAL LOGGER ENABLED'), 'enabled');

      // Case-folded, because a config file is read upper-cased and a hand
      // edit is not.
      CheckTrue(s.OwnsCommand('external logger port'), 'lower case');
      CheckTrue(s.OwnsCommand('  EXTERNAL LOGGER PORT  '), 'surrounding blanks');

      (* AND THE LIST IS EXACTLY THE MIGRATED SETTINGS.  A name appearing that
        nothing migrated would mean the derivation invented a command TR4W
        never had, which is worse than missing one: it would start claiming a
        peer's message. *)
      names := s.CommandNames;
      try
         CheckEquals(3, names.Count, 'one name per migrated setting, no more');
      finally
         names.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_SetAndGetByCommandName;
var
   s: TR4WSettings;
   value: string;
begin
   (* THIS IS WHAT MULTI-OP PEER SYNC NEEDS.  A change made at one position
     travels as command TEXT plus a value; the receiving position applies it by
     name. A setting that moved here and could not be reached by name would
     leave the other position silently stale, which is the failure uNet already
     had for seventeen rows. *)
   BeginTest('a setting can be set and read back by its command name');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('EXTERNAL LOGGER PORT', '52020'), 'set a number');
      CheckEquals(52020, s.ExternalLogger.Port, 'the property took it');

      CheckTrue(s.TrySetByCommand('EXTERNAL LOGGER ENABLED', 'TRUE'), 'set a boolean');
      CheckTrue(s.ExternalLogger.Enabled, 'the property took it');

      CheckTrue(s.TrySetByCommand('EXTERNAL LOGGER ADDRESS', '10.1.2.3'), 'set a string');
      CheckEquals('10.1.2.3', s.ExternalLogger.Address, 'the property took it');

      // Rendered back in the spelling BA uses, so what a peer receives is what
      // the old parser would have accepted.
      CheckTrue(s.TryGetByCommand('EXTERNAL LOGGER PORT', value), 'read a number');
      CheckEquals('52020', value, 'number');
      CheckTrue(s.TryGetByCommand('EXTERNAL LOGGER ENABLED', value), 'read a boolean');
      CheckEquals('TRUE', value, 'boolean renders as TRUE, not -1 or 1');
      CheckTrue(s.TryGetByCommand('EXTERNAL LOGGER ADDRESS', value), 'read a string');
      CheckEquals('10.1.2.3', value, 'string');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_AnUnknownCommandIsRefused;
var
   s: TR4WSettings;
   value: string;
begin
   (* REFUSED, NOT SILENTLY IGNORED.  The caller uses the answer to decide
     whether some OTHER mechanism still owns the command -- CFGCA, for the
     hundreds that have not moved -- so a settings object that swallowed an
     unknown name would make those settings stop working with no diagnostic. *)
   BeginTest('a command this object does not own is refused');
   s := TR4WSettings.Create;
   try
      CheckFalse(s.OwnsCommand('MY CALL'), 'a setting that has not migrated');
      CheckFalse(s.TrySetByCommand('MY CALL', 'NY4I'), 'setting it is refused');
      CheckFalse(s.TryGetByCommand('MY CALL', value), 'reading it is refused');
      CheckEquals('', value, 'and yields nothing to send');

      CheckFalse(s.OwnsCommand(''), 'an empty command name');

      (* A VALUE THE TYPE CANNOT TAKE IS REFUSED AND CHANGES NOTHING -- the
        rule CheckCommand had, and it matters more here because the one-time
        import gets no second chance to ask. *)
      s.ExternalLogger.Port := 52001;
      CheckFalse(s.TrySetByCommand('EXTERNAL LOGGER PORT', 'not a number'),
                 'an unparseable number is refused');
      CheckEquals(52001, s.ExternalLogger.Port, 'and the property is untouched');

      s.ExternalLogger.Enabled := True;
      CheckFalse(s.TrySetByCommand('EXTERNAL LOGGER ENABLED', 'perhaps'),
                 'a word that is neither T nor F is refused');
      CheckTrue(s.ExternalLogger.Enabled, 'and the property is untouched');
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
   Test_CommandNamesDeriveFromThePropertyPaths;
   Test_SetAndGetByCommandName;
   Test_AnUnknownCommandIsRefused;
end;

end.
