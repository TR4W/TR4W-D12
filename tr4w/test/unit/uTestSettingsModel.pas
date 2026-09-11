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
   SysUtils, Classes, uTR4WTestFramework, uJSON, uSettingsModel,
   uCFG;   // CommandIsRetired -- the 91 names that replaced the csRem rows

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
      procedure Test_BandDefaultsAreTheOnesTheGlobalsHad;
      procedure Test_TheElevenRetiredRowsStillResolveByName;
      procedure Test_TheDerivedNameAnExceptionReplacedIsGone;
      procedure Test_ASetterRaisesTheChange;
      procedure Test_AssigningTheSameValueRaisesNothing;
      procedure Test_AWithdrawnCommandIsStillAccepted;
      procedure Test_NoRetiredNameIsAlsoLiveOrOwned;
      procedure Test_ARangeIsPartOfTheType;
      procedure Test_AStoredValueOutOfRangeIsClamped;
   public
      procedure RunAllTests; override;
   end;

implementation

(* THE CHANGE RECORDER.

  A unit-level variable and a plain procedure, because TSettingChanged is a
  plain procedure type -- the same shape uBandMapView uses for the band map's
  own seam.  A method would need an object that exists only to hold it. *)
var
   GChangedPaths: TStringList = nil;

procedure RecordChange(const aPath: string);
begin
   if GChangedPaths <> nil then
      begin
      GChangedPaths.Add(aPath);
      end;
end;


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

      (* AND THE GROUPING IS CONSTRAINED BY THESE NAMES, which is the thing to
        know before adding a setting.  The property PATH derives the command,
        so SpotCollector.Enabled is not a free choice of grouping -- it is what
        yields the name an existing config file already uses.  Radio.TcpServerPort
        likewise, and note it is the server TR4W RUNS, not a radio port. *)
      CheckTrue(s.OwnsCommand('SPOT COLLECTOR ENABLED'), 'the DXLab bridge');
      CheckTrue(s.OwnsCommand('RADIO TCP SERVER PORT'),  'the radio TCP server');
      CheckTrue(s.OwnsCommand('YCCC SO2R ENABLE'), 'the YCCC SO2R+ box');
      CheckTrue(s.OwnsCommand('MMTTY ENGINE'),     'the RTTY engine path');

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
         (* A RATCHET, AND IT HAS ALREADY EARNED ITS KEEP: it failed the
           moment two settings were added, which is exactly what it is for --
           a derived name that invents a command TR4W never had would start
           claiming a multi-op peer message. *)
         CheckEquals(31, names.Count, 'one name per migrated setting, no more');
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

(* ---------------------------------------------------------------------
  THE BAND MAP AND BAND CLASS GROUPS, 2026-09-11.

  Eleven CFGCA rows were DELETED for these -- not retired to csRem, deleted --
  so there is no table left to read if one of them stops working.  These are
  the tests that stand in its place.
  --------------------------------------------------------------------- *)

procedure TSettingsModelTests.Test_BandDefaultsAreTheOnesTheGlobalsHad;
var
   s: TR4WSettings;
begin
   (* THE DEFAULTS ARE NOT UNIFORM AND THAT IS THE POINT.  The globals were
     declared in three different units and five of the eleven defaulted True:

       logstuff.pas   BandMapCallWindowEnable: boolean = True;
       logwind.pas    BandMapDisplayCQ:        boolean = True;
       logwind.pas    BandMapDupeDisplay:      boolean = True;
       logdupe.pas    HFBandEnable:            boolean = True;
       (the other seven were plain `: boolean`, so False)

     Getting one of these backwards does not fail a build and does not fail a
     contest either -- it quietly hides dupes, or refuses a band change -- so
     the pin test is the only thing that can catch it. *)
   BeginTest('the band settings default to what the globals carried');
   s := TR4WSettings.Create;
   try
      CheckFalse(s.BandMap.AllBands,         'BandMapAllBands');
      CheckFalse(s.BandMap.AllModes,         'BandMapAllModes');
      CheckTrue (s.BandMap.CallWindowEnable, 'BandMapCallWindowEnable');
      CheckTrue (s.BandMap.DisplayCQ,        'BandMapDisplayCQ');
      CheckFalse(s.BandMap.DisplayGhz,       'BandMapDisplayGhz');
      CheckTrue (s.BandMap.DupeDisplay,      'BandMapDupeDisplay');
      CheckFalse(s.BandMap.MultsOnly,        'BandMapMultsOnly');
      CheckFalse(s.BandMap.So2rDisplay,      'BandMapSO2RDisplay');

      CheckTrue (s.Bands.HfEnabled,          'HFBandEnable');
      CheckFalse(s.Bands.VhfEnabled,         'VHFBandsEnabled');
      CheckFalse(s.Bands.WarcEnabled,        'WARCBandsEnabled');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_TheElevenRetiredRowsStillResolveByName;
var
   s: TR4WSettings;
   i: integer;
const
   (* EXACTLY THE ELEVEN crCommand SPELLINGS THAT WERE DELETED FROM CFGCA.

     If one of these stops resolving, the failure is not a compile error and
     not a crash.  An operator upgrading from an older version opens their
     contest .cfg, LogCfg.pas reports "invalid statement in config file" in a
     modal dialog, and the setting is silently lost -- against a config file
     that was working the day before. *)
   RETIRED: array[0..10] of string = (
      'BAND MAP ALL BANDS',
      'BAND MAP ALL MODES',
      'BAND MAP CALL WINDOW ENABLE',
      'BAND MAP DISPLAY CQ',
      'BAND MAP DISPLAY GHZ',
      'BAND MAP DUPE DISPLAY',
      'BAND MAP MULTS ONLY',
      'BAND MAP SO2R DISPLAY',
      'HF BAND ENABLE',
      'VHF BAND ENABLE',
      'WARC BAND ENABLE');
begin
   BeginTest('every deleted CFGCA row still answers to its command name');
   s := TR4WSettings.Create;
   try
      for i := Low(RETIRED) to High(RETIRED) do
         begin
         CheckTrue(s.OwnsCommand(RETIRED[i]), RETIRED[i] + ' is owned');
         // Owning a name and being able to APPLY it are different claims.
         CheckTrue(s.TrySetByCommand(RETIRED[i], 'TRUE'),
                   RETIRED[i] + ' accepts a value');
         end;
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_TheDerivedNameAnExceptionReplacedIsGone;
var
   s: TR4WSettings;
begin
   (* THE OVERRIDE MUST REMOVE, NOT ONLY ADD.

     'WARC BAND ENABLE' leads with the band class, so the three Bands
     properties carry explicit exceptions.  The derivation had already put
     'BANDS WARC ENABLED' into the map, and leaving it would publish a command
     TR4W has never had -- offered by the Preferences list and accepted from a
     multi-op peer, under a name no other station would ever send. *)
   BeginTest('an exception removes the name the derivation invented');
   s := TR4WSettings.Create;
   try
      CheckTrue (s.OwnsCommand('WARC BAND ENABLE'),  'the legacy name resolves');
      CheckFalse(s.OwnsCommand('BANDS WARC ENABLED'), 'the derived name does not');
      CheckFalse(s.OwnsCommand('BANDS HF ENABLED'),   'nor the HF one');
      CheckFalse(s.OwnsCommand('BANDS VHF ENABLED'),  'nor the VHF one');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_ASetterRaisesTheChange;
var
   s: TR4WSettings;
begin
   (* THIS IS THE crP REPLACEMENT, AND NOTHING ELSE IN THE TREE TESTS IT.

     A hook index only fired when CheckCommand applied a row, so a menu toggle
     repainted only because the band map form remembered to ask.  The whole
     claim of this design is that the SETTER fires however the value was set.
     An ordinary Pascal assignment is the case that used to do nothing. *)
   BeginTest('assigning a property raises the change, naming its path');
   GChangedPaths := TStringList.Create;
   s := TR4WSettings.Create;
   try
      s.OnChanged := @RecordChange;

      s.BandMap.AllBands := True;
      CheckEquals(1, GChangedPaths.Count, 'one change raised');
      CheckEquals('BandMap.AllBands', GChangedPaths[0], 'the path');

      s.Bands.WarcEnabled := True;
      CheckEquals(2, GChangedPaths.Count, 'a second change');
      CheckEquals('Bands.WarcEnabled', GChangedPaths[1], 'the path');

      (* AND THROUGH THE COMMAND NAME TOO -- the multi-op path.  A peer's
        change arrives as text, and it must repaint the same way a local menu
        toggle does. *)
      CheckTrue(s.TrySetByCommand('BAND MAP DUPE DISPLAY', 'FALSE'), 'applied');
      CheckEquals(3, GChangedPaths.Count, 'the command name raised it too');
      CheckEquals('BandMap.DupeDisplay', GChangedPaths[2], 'the path');
   finally
      s.Free;
      FreeAndNil(GChangedPaths);
   end;
end;

procedure TSettingsModelTests.Test_AssigningTheSameValueRaisesNothing;
var
   s: TR4WSettings;
begin
   (* Every JSON load and every peer sync writes EVERY property it carries.
     A setter that notified unconditionally would repaint the band map eleven
     times at startup, and the guard against that is one comparison -- easy to
     drop, and invisible when it is gone. *)
   BeginTest('assigning the value a property already holds raises nothing');
   GChangedPaths := TStringList.Create;
   s := TR4WSettings.Create;
   try
      s.OnChanged := @RecordChange;

      // DupeDisplay defaults True, so this is a no-op assignment.
      s.BandMap.DupeDisplay := True;
      CheckEquals(0, GChangedPaths.Count, 'no change for the same value');

      s.BandMap.DupeDisplay := False;
      CheckEquals(1, GChangedPaths.Count, 'but a real change still raises');
   finally
      s.Free;
      FreeAndNil(GChangedPaths);
   end;
end;

(* ---------------------------------------------------------------------
  THE WITHDRAWN COMMANDS, 2026-09-11.

  91 csRem rows were replaced by 91 NAMES in uCFG.RETIRED_COMMANDS.  Those
  rows were the only record that these had ever been TR4W commands, so these
  two tests are what stands behind them now.
  --------------------------------------------------------------------- *)

procedure TSettingsModelTests.Test_AWithdrawnCommandIsStillAccepted;
begin
   (* WHY ACCEPTING MATTERS.  LogCfg.pas:1262 puts a MODAL "invalid statement
     in config file" in front of the operator for a line CheckCommand refuses.
     A station whose tr4w.ini still names a feature withdrawn two versions ago
     would get one dialog per stale line, about a configuration that worked
     the day before. *)
   BeginTest('a withdrawn command is still recognised, so an old config loads');

   // Withdrawn 2026-08-22 (NY4I): "if the window is opened, it is enabled".
   CheckTrue(CommandIsRetired('BAND MAP ENABLE'), 'BAND MAP ENABLE');
   // The DOS-era serial multi link, and two more withdrawn features.
   CheckTrue(CommandIsRetired('MULTI PORT'), 'MULTI PORT');
   CheckTrue(CommandIsRetired('MOUSE ENABLE'), 'MOUSE ENABLE');
   CheckTrue(CommandIsRetired('DUPE SHEET ENABLE'), 'DUPE SHEET ENABLE');

   (* NOT K1EA NETWORK ENABLE, and the first draft of this test asserted that
     it was -- which is the distinction worth keeping.

     A COMMENTED-OUT ROW AND A csRem ROW ARE DIFFERENT SETS.  K1EA NETWORK
     ENABLE is commented out in CFGCA, so CheckCommand has never accepted it:
     an old config naming it ALREADY got the dialog, long before this change.
     Only the csRem rows were accepted-and-ignored, and only those became
     names on the list.  Adding the commented-out ones would not be tidying,
     it would be changing behaviour. *)
   CheckFalse(CommandIsRetired('K1EA NETWORK ENABLE'),
              'commented out is not the same as csRem');

   // Case-folded: a config file is read upper-cased, a hand edit is not.
   CheckTrue(CommandIsRetired('band map enable'), 'lower case');

   // And it must not accept everything -- a typo has to stay a typo, or the
   // dialog this list protects would never fire for a real mistake.
   CheckFalse(CommandIsRetired('BAND MAP ENABLF'), 'a typo is not retired');
   CheckFalse(CommandIsRetired(''), 'nor is an empty command');

   (* A RATCHET. The list only ever grows, as the last step of removing a
     feature. A fall means rows were dropped without being listed, which is
     silent: the failure is a dialog on someone else's machine. *)
   CheckTrue(RetiredCommandCount >= 91, 'the retired list has not shrunk');
end;

procedure TSettingsModelTests.Test_NoRetiredNameIsAlsoLiveOrOwned;
var
   s: TR4WSettings;
   names: TStringList;
   i: integer;
begin
   (* TWO CONTRADICTIONS THIS CATCHES, and neither would fail a build.

     A name both RETIRED and LIVE in CFGCA would be a command that still does
     something while being documented as withdrawn.  It could not shadow the
     live row -- the retired check runs last, after every handler has declined
     -- so the damage is not a wrong value, it is a wrong belief: the next
     person to read the list would delete working code.

     A name both RETIRED and OWNED BY THE SETTINGS MODEL is the sharper one.
     Seven of the 98 csRem rows were settings that had MOVED, not features
     that had gone, and they were deliberately left off the list because the
     model resolves them for real.  Putting one on it would be claiming a
     setting is gone while it is sitting in tr4w.json being used. *)
   BeginTest('no withdrawn name is also a live command or a live setting');
   s := TR4WSettings.Create;
   try
      names := s.CommandNames;
      try
         for i := 0 to names.Count - 1 do
            begin
            CheckFalse(CommandIsRetired(names[i]),
                       names[i] + ' is owned by the model, so it is not retired');
            end;
      finally
         names.Free;
      end;

      // The seven that moved rather than went, named literally.
      CheckFalse(CommandIsRetired('EXTERNAL LOGGER PORT'), 'moved, not withdrawn');
      CheckFalse(CommandIsRetired('MMTTY ENGINE'),         'moved, not withdrawn');
      CheckFalse(CommandIsRetired('YCCC SO2R ENABLE'),     'moved, not withdrawn');
   finally
      s.Free;
   end;
end;

(* ---------------------------------------------------------------------
  BOUNDED INTEGERS, 2026-09-11.

  crMin and crMax became SUBRANGE TYPES on the properties.  Nothing in
  TrySetByCommand names a setting or a bound -- it reads MinValue and MaxValue
  out of the property's own RTTI -- so these tests are what prove the bounds
  are actually reaching it.
  --------------------------------------------------------------------- *)

procedure TSettingsModelTests.Test_ARangeIsPartOfTheType;
var
   s: TR4WSettings;
begin
   (* WHAT A LOST BOUND WOULD COST.  CheckCommand refused an out-of-range
     value and left the setting alone.  If that enforcement did not survive
     the move, a contest .cfg could set BAND MAP ITEM HEIGHT to 0 and the band
     map would divide by it while laying out its grid. *)
   BeginTest('an out-of-range value is refused and the property is unchanged');
   s := TR4WSettings.Create;
   try
      // crMin:12, crMax:50 -- now TBandMapItemHeight.
      CheckEquals(14, s.BandMap.ItemHeight, 'the default to start from');

      CheckFalse(s.TrySetByCommand('BAND MAP ITEM HEIGHT', '51'), 'above the max');
      CheckEquals(14, s.BandMap.ItemHeight, 'and it did not move');

      CheckFalse(s.TrySetByCommand('BAND MAP ITEM HEIGHT', '11'), 'below the min');
      CheckEquals(14, s.BandMap.ItemHeight, 'and it did not move');

      CheckFalse(s.TrySetByCommand('BAND MAP ITEM HEIGHT', '0'), 'the zero that divides');
      CheckEquals(14, s.BandMap.ItemHeight, 'and it did not move');

      // THE BOUNDARIES THEMSELVES ARE LEGAL -- an off-by-one in the type
      // declaration would otherwise pass every test above.
      CheckTrue(s.TrySetByCommand('BAND MAP ITEM HEIGHT', '12'), 'the minimum');
      CheckEquals(12, s.BandMap.ItemHeight, 'applied');
      CheckTrue(s.TrySetByCommand('BAND MAP ITEM HEIGHT', '50'), 'the maximum');
      CheckEquals(50, s.BandMap.ItemHeight, 'applied');

      // And the other three carry their own, different, ranges.
      CheckFalse(s.TrySetByCommand('BAND MAP ITEM WIDTH', '99'),  'width min 100');
      CheckTrue (s.TrySetByCommand('BAND MAP ITEM WIDTH', '200'), 'width max 200');
      CheckFalse(s.TrySetByCommand('BAND MAP SIZE', '9'),         'size max 8');
      CheckTrue (s.TrySetByCommand('BAND MAP SIZE', '0'),         'size min 0');
      CheckFalse(s.TrySetByCommand('BAND MAP DISPLAY LIMIT', '29'),   'limit min 30');
      CheckTrue (s.TrySetByCommand('BAND MAP DISPLAY LIMIT', '1000'), 'limit max 1000');

      (* AND AN UNBOUNDED PROPERTY IS STILL UNBOUNDED.  The range check reads
        the type's RTTI with no list of which settings are bounded, so a plain
        Integer property must keep accepting ordinary values -- if this fails,
        the check is reading the wrong thing. *)
      CheckTrue(s.TrySetByCommand('EXTERNAL LOGGER PORT', '52099'), 'a plain integer');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_AStoredValueOutOfRangeIsClamped;
var
   s: TR4WSettings;
   obj: TJSONObject;
begin
   (* THE STREAMER IS THE ONE PATH THAT BYPASSES THE CHECK ABOVE.  fpjsonrtti
     writes whatever ordinal the file carries, so a hand-edited tr4w.json can
     put 0 into a 12..50 property and every reader downstream believes the
     type.  FromJSON clamps, for every bounded property at once.

     CLAMPED, NOT REFUSED, unlike a config line -- there is nobody at the
     keyboard at startup to tell, and leaving the property at a default is no
     closer to the operator's intent than the nearest legal value. *)
   BeginTest('a stored value outside its range is pulled back in on load');
   s := TR4WSettings.Create;
   try
      (* 250 RATHER THAN SOMETHING ABSURD, and the reason is worth knowing.

        A subrange type bounds the STORAGE as well as the value: FPC gives
        TBandMapItemWidth (100..200) a single byte, so a stored 9999 does not
        arrive as 9999 to be clamped down -- it has already wrapped to 15 by
        the time anything can look at it, and then clamps UP to 100.

        The invariant that actually holds is "the property ends up inside its
        range", which is what protects the division downstream, and it holds
        either way.  The first version of this test asserted the DIRECTION of
        the clamp and was wrong about the mechanism; 250 fits the byte and so
        exercises the over-maximum path for real. *)
      obj := TJSONObject(TJSONObject.ParseJSONValue(
         '{"BandMap":{"ItemHeight":0,"ItemWidth":250,"Size":3}}'));
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;

      CheckEquals(12, s.BandMap.ItemHeight, 'zero clamped up to the minimum');
      CheckEquals(200, s.BandMap.ItemWidth, 'above the maximum clamped down');
      CheckEquals(3, s.BandMap.Size, 'a legal value is left exactly alone');

      (* AND AN ABSURD ONE STILL LANDS SOMEWHERE LEGAL, whichever way the
        storage wrapped it -- that is the property the band map's grid
        arithmetic actually depends on. *)
      obj := TJSONObject(TJSONObject.ParseJSONValue(
         '{"BandMap":{"ItemHeight":99999,"ItemWidth":-4000}}'));
      CheckTrue(obj <> nil, 'the second fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;

      CheckTrue((s.BandMap.ItemHeight >= Low(TBandMapItemHeight)) and
                (s.BandMap.ItemHeight <= High(TBandMapItemHeight)),
                'item height is inside its range whatever was stored');
      CheckTrue((s.BandMap.ItemWidth >= Low(TBandMapItemWidth)) and
                (s.BandMap.ItemWidth <= High(TBandMapItemWidth)),
                'item width is inside its range whatever was stored');
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
   Test_BandDefaultsAreTheOnesTheGlobalsHad;
   Test_TheElevenRetiredRowsStillResolveByName;
   Test_TheDerivedNameAnExceptionReplacedIsGone;
   Test_ASetterRaisesTheChange;
   Test_AssigningTheSameValueRaisesNothing;
   Test_AWithdrawnCommandIsStillAccepted;
   Test_NoRetiredNameIsAlsoLiveOrOwned;
   Test_ARangeIsPartOfTheType;
   Test_AStoredValueOutOfRangeIsClamped;
end;

end.
