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
      procedure Test_AStoreOwnedCommandIsAcceptedAndIsNotRetired;
      procedure Test_ARangeIsPartOfTheType;
      procedure Test_AStoredValueOutOfRangeIsClamped;
      procedure Test_TheReadPathAndTheWritePathAgree;
      procedure Test_AContestParameterNeverReachesTheJson;
      procedure Test_EveryCommandNameIsTheOneAConfigFileUses;
      procedure Test_AStaleIniCannotOverrideTheStore;
      procedure Test_AContestFileStillOverridesForItsContest;
      procedure Test_MessageDefaultsAreTheOnesInitializeStringsSeeded;
      procedure Test_EveryMessageCommandReachesItsOwnProperty;
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

      (* THE FOUR CW ALIASES, named individually because they are the group
        where the derivation and the legacy names disagree most. Each of these
        would be silently absent if its Alias line were dropped, and the count
        below would still pass -- the derived name would simply take its
        place. *)
      CheckTrue(s.OwnsCommand('ALL CW MESSAGES CHAINABLE'), 'CW prefix in the middle');
      CheckTrue(s.OwnsCommand('KEYPAD CW MEMORIES'),        'CW prefix in the middle');
      CheckTrue(s.OwnsCommand('SEND COMPLETE FOUR LETTER CALL'), 'no CW prefix at all');
      CheckTrue(s.OwnsCommand('TUNE WITH DITS'),            'no CW prefix at all');
      (* And the one that derives exactly, so the aliases above are the
        exception rather than the rule for this group. *)
      CheckTrue(s.OwnsCommand('CW SPEED FROM DATABASE'), 'derives with no alias');

      (* THE DERIVED NAMES THE ALIASES REPLACED MUST BE GONE. Leaving both
        would put commands TR4W has never had into CommandNames, where
        Preferences would offer them and a peer sync would accept them. *)
      CheckFalse(s.OwnsCommand('CW ALL MESSAGES CHAINABLE'), 'the invented name is not offered');
      CheckFalse(s.OwnsCommand('CW TUNE WITH DITS'),         'nor this one');

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
         CheckEquals(233, names.Count,
                     'one name per migrated setting, plus the ten that'
                     + ' answer to more than one -- MY STATE/MY QTH, the'
                     + ' eight mode-less message spellings, and QUICK QSL'
                     + ' MESSAGE 1, which has three');
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
      (* THE EXAMPLE HAS TO BE A COMMAND THAT HAS NOT MIGRATED, so it
        changes as the migration proceeds -- this was MY CALL until that
        moved on 2026-09-12. MY CONTINENT is still a CFGCA row and is
        deliberately staying there for now: it has 71 references in the
        scoring code and the contest factory has to review it. *)
      CheckFalse(s.OwnsCommand('MY CONTINENT'), 'a setting that has not migrated');
      CheckFalse(s.TrySetByCommand('MY CONTINENT', 'NA'), 'setting it is refused');
      CheckFalse(s.TryGetByCommand('MY CONTINENT', value), 'reading it is refused');
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

procedure TSettingsModelTests.Test_AStoreOwnedCommandIsAcceptedAndIsNotRetired;
begin
   (* THE THIRD ANSWER A COMMAND NAME CAN GET, and it needed to exist.

     A name is live (the array or the settings model applies it), withdrawn
     (accepted and ignored because the feature is gone), or -- since the UDP
     rows left -- OWNED BY A STORE: the setting still works, and something
     other than the config array reads it. Calling that third case "withdrawn"
     would tell the next reader that UDP broadcasting had been removed. *)
   BeginTest('a setting a store owns is accepted, and is not withdrawn');

   CheckTrue(CommandIsOwnedByAStore('UDP BROADCAST SCORE'), 'a stream flag');
   CheckTrue(CommandIsOwnedByAStore('UDP BROADCAST ADDRESS'), 'the address');
   CheckTrue(CommandIsOwnedByAStore('UDP BROADCAST ROTOR PORT'), 'a port');

   (* Case-folded for the same reason as the withdrawn list: a config file is
     read upper-cased and a hand edit is not. *)
   CheckTrue(CommandIsOwnedByAStore('udp broadcast score'), 'lower case');

   (* And it must not accept everything, or the modal that protects a genuine
     typo would never fire. *)
   CheckFalse(CommandIsOwnedByAStore('UDP BROADCAST SCORF'), 'a typo');
   CheckFalse(CommandIsOwnedByAStore(''), 'an empty command');

   (* THE TWO LISTS MUST NOT OVERLAP. UDP BROADCAST PORT is the instructive
     case: it is genuinely withdrawn -- the code beside it said "no longer
     used" for years -- while the thirteen names around it are not. *)
   CheckTrue(CommandIsRetired('UDP BROADCAST PORT'),
             'UDP BROADCAST PORT really is withdrawn');
   CheckFalse(CommandIsOwnedByAStore('UDP BROADCAST PORT'),
              'and so it is not on the store list as well');
   CheckFalse(CommandIsRetired('UDP BROADCAST SCORE'),
              'a setting that still works is not withdrawn');

   (* A ratchet, as the withdrawn list has. A fall means names were dropped
     without being listed, and the failure is a modal dialog on somebody
     else's machine. *)
   CheckTrue(StoreOwnedCommandCount >= 14, 'the store list has not shrunk');
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

procedure TSettingsModelTests.Test_TheReadPathAndTheWritePathAgree;
var
   wasEnabled: boolean;
   wasPort: integer;
begin
   (* THE DEFECT THIS PINS, IN THE ORDER IT HAPPENED TO AN OPERATOR.

     uPrefsForm has seven HAND-WIRED controls that reach their setting by
     command NAME rather than through the settings registry -- external
     logger address, enabled and port; MMTTY engine; radio TCP server port;
     spot collector enabled; YCCC SO2R enable.  They READ with
     CFGCommandValueAsString and WRITE with SetCFGCommandValue.

     Every one of those settings had moved to uSettingsModel.  CheckCommand
     resolved the name for writing; CFGCommandValueAsString did not resolve it
     for reading, and returned ''.

     So: open the Preferences page, and the checkbox shows UNCHECKED however
     the setting is actually set.  Press OK, and the write path faithfully
     stores what the control was showing.  A setting the operator never
     touched is turned off by looking at the page it lives on, and nothing
     reports it.

     A ONE-DIRECTIONAL TEST WOULD NOT HAVE CAUGHT IT.  Reading alone or
     writing alone both looked fine; only the ROUND TRIP through the two
     different entry points shows the disagreement.  So this asserts through
     the same two calls the UI makes, not through the settings object. *)
   BeginTest('a migrated setting reads back through the CFG layer, not blank');

   wasEnabled := Settings.ExternalLogger.Enabled;
   wasPort    := Settings.ExternalLogger.Port;
   try
      Settings.ExternalLogger.Enabled := True;
      Settings.ExternalLogger.Port    := 52077;

      (* The renderer the hand-wired controls call.  Before the fix this was
        '' for every migrated name. *)
      CheckEquals('TRUE', UpperCase(Trim(
                     CFGCommandValueAsString('EXTERNAL LOGGER ENABLED'))),
                  'a boolean reads back, not blank');
      CheckEquals('52077', Trim(CFGCommandValueAsString('EXTERNAL LOGGER PORT')),
                  'an integer reads back, not blank');

      Settings.ExternalLogger.Enabled := False;
      CheckEquals('FALSE', UpperCase(Trim(
                     CFGCommandValueAsString('EXTERNAL LOGGER ENABLED'))),
                  'and it tracks a change');

      (* AND A COMMAND THAT NEVER MOVED STILL READS FROM ITS ROW, which is
        what proves the new arm narrows rather than intercepts. *)
      CheckTrue(CFGCommandValueAsString('BAND MAP DECAY TIME') <> '',
                'an unmigrated command still renders from its row');
   finally
      Settings.ExternalLogger.Enabled := wasEnabled;
      Settings.ExternalLogger.Port    := wasPort;
   end;
end;

(* ---------------------------------------------------------------------
  WHO IS ALLOWED TO WRITE A MIGRATED SETTING.

  These two exist because a REVIEW found a defect that every other test in
  this file was blind to (Codex, 2026-09-11). The model tests call
  TrySetByCommand directly, so they never reproduce the startup ORDER --
  settings\tr4w.json is loaded and asserted as the source of record, and then
  ReadInConfigFile(cfgINI) runs a dozen lines later.

  The arm that resolves a migrated name in CheckCommand had no
  aApplyJSONOwned guard, so a stale ini line overwrote the stored value on
  every launch and a Preferences change would not survive a restart. The
  csJSON rows those settings CAME FROM are guarded against exactly that.

  So these assert through CheckCommand with the flag both ways, which is the
  distinction that was missing, rather than through the settings object.
  --------------------------------------------------------------------- *)

(* ---------------------------------------------------------------------
  THE WHOLE VOCABULARY, FROZEN.

  A COUNT IS NOT ENOUGH, and that is the defect this replaces. The test
  above asserts how MANY command names the model owns, which catches a name
  appearing from nowhere. It cannot catch a name CHANGING: drop an Alias
  line and the derived name silently takes its place, one name goes out and
  one comes in, and the count is still right. The setting then stops
  answering to the name in every .cfg an operator has, and nothing says so.

  THE STARTUP CROSS-CHECK COVERS ONLY PART OF THIS. TModelSetting.Create
  raises when the model does not own the command it names, which is loud and
  which is what caught the CW batch -- but only 20 of these names have a
  Preferences registration behind them. The rest had nothing pinning them at
  all.

  SO THE LIST IS SPELLED OUT. It is deliberately the maintenance cost it
  looks like: adding a setting means adding its name here, and that is the
  moment to ask whether the derived name is the one TR4W has always used.
  A rename that reaches this list by being pasted from the failure message
  is a rename somebody looked at.

  ORDERED AND JOINED rather than compared element by element, so a failure
  prints both vocabularies whole and the difference can be read directly.
  --------------------------------------------------------------------- *)

(* ---------------------------------------------------------------------
  A CONTEST PARAMETER IS NOT A STATION SETTING AND MUST NOT BE SAVED AS ONE.

  THE DEFECT THIS PINS, found while migrating a neighbouring group: the band
  enables are assigned by FCONTEST the moment a contest loads -- TBandSettings'
  own constructor comment said so -- yet they were published properties, so
  they were streamed into settings\tr4w.json like any preference. Preferences
  saves the WHOLE settings object on every applied change, so loading a
  contest that enables WARC and then changing any unrelated setting made that
  contest's choice the station's default, permanently. In the old world the
  global was re-set per contest every time and nothing stuck.

  NY4I, 2026-09-11: a contest parameter belongs in the contest config in the
  database and never in the json file.

  THE PROPERTY IS STILL PUBLISHED and that is deliberate: the RTTI walk that
  derives command names reads published properties, so un-publishing would
  remove HF BAND ENABLE from the vocabulary as well as from the file. What
  changes is where the VALUE lives, not whether the command exists -- which is
  why this asserts BOTH halves.
  --------------------------------------------------------------------- *)

procedure TSettingsModelTests.Test_AContestParameterNeverReachesTheJson;
var
   s: TR4WSettings;
   doc: TJSONObject;
   text: string;
begin
   BeginTest('a contest parameter is excluded from the settings file');

   s := TR4WSettings.Create;
   try
      (* Set them to something a station would notice being carried over. *)
      s.Bands.WarcEnabled := True;
      s.Bands.VhfEnabled  := True;

      doc := s.ToJSON;
      try
         text := string(doc.AsJSON);
      finally
         doc.Free;
      end;

      (* THE QUOTES ARE PART OF THE NEEDLE. Searching for a bare Bands matches
        "AllBands" inside the band map group and fails a passing
        implementation -- which it did, on the first run of this test. *)
      CheckTrue(Pos('"Bands"', text) = 0,
                'the Bands group is absent from the json: ' + text);

      (* AND A STATION SETTING IS STILL THERE, so a passing result cannot mean
        the streamer simply produced nothing. *)
      CheckTrue(Pos('"Ptt"', text) > 0,
                'a station group is still written');

      (* THE COMMANDS STILL EXIST. Excluding the value must not withdraw the
        vocabulary -- a config file naming HF BAND ENABLE still has to be
        understood, and the contest database is what stores the answer. *)
      CheckTrue(s.OwnsCommand('HF BAND ENABLE'),  'the command still resolves');
      CheckTrue(s.CommandIsContestScoped('HF BAND ENABLE'),
                'and it is marked as the contest''s');
      CheckTrue(s.CommandIsContestScoped('WARC BAND ENABLE'), 'so is WARC');
      CheckTrue(s.CommandIsContestScoped('VHF BAND ENABLE'),  'so is VHF');

      (* THE CONTEST'S OWN RULES AND SCORING, which are the same claim about
        four more groups. One name from each, chosen so that a group left
        without the override would fail here rather than in a contest. *)
      CheckTrue(s.CommandIsContestScoped('MULT BY BAND'),  'multipliers');
      CheckTrue(s.CommandIsContestScoped('QSO BY BAND'),   'QSO counting');
      CheckTrue(s.CommandIsContestScoped('QSO POINTS DOMESTIC CW'),
                'and what a QSO is worth');
      CheckTrue(s.CommandIsContestScoped('QTC ENABLE'),    'QTCs');
      CheckTrue(s.CommandIsContestScoped('AUTO DUPE ENABLE S AND P'),
                'automatic dupe checking');
      CheckTrue(s.CommandIsContestScoped('SPRINT QSY RULE'),
                'and the rest of the contest rules');

      (*
        THE TWO NY4I CORRECTED BY HAND, 2026-09-12, reviewing the settings
        inventory. Both were filed on the wrong side and nothing would have
        noticed if they drifted back, because a scope is a class function on
        a group and moving a property between groups changes it silently.

        HAMSCORE ENABLE is the CONTEST'S: whether live scores are posted is
        a decision per contest. Where they are posted and as whom are not,
        and those stay with the station -- which is why the group had to be
        split rather than re-scoped whole.
      *)
      CheckTrue(s.CommandIsContestScoped('HAMSCORE ENABLE'),
                'posting scores is a per-contest decision');
      CheckFalse(s.CommandIsContestScoped('HAMSCORE URL'),
                 'but the server address is the station''s');
      CheckFalse(s.CommandIsContestScoped('HAMSCORE SEND CONTACT INFO'),
                 'and so is what is sent');

      (*
        CALLSIGN UPDATE ENABLE went the other way, from the contest to the
        station. It was contest-scoped because the contest definitions set
        it for Sweepstakes alone -- and an operator who wants the behaviour
        wants it everywhere, so it is a station preference that now defaults
        TRUE and that no contest is allowed to write.
      *)
      CheckFalse(s.CommandIsContestScoped('CALLSIGN UPDATE ENABLE'),
                 'taking a corrected call from the exchange is the operator''s');
      CheckTrue(s.CallWindow.CallsignUpdateEnable,
                'and it defaults on, which it did not before');

      (* AND THEY ARE ABSENT FROM THE FILE, the half that matters: streaming
        one would make the last contest loaded the station's default. The
        quotes are the needle again -- a bare Mult matches MultsOnly in the
        band map group. *)
      CheckTrue(Pos('"Mult"', text) = 0, 'no Mult group in the json: ' + text);
      CheckTrue(Pos('"Qso"', text) = 0,  'no Qso group in the json: ' + text);
      CheckTrue(Pos('"Qtc"', text) = 0,  'no Qtc group in the json: ' + text);
      CheckTrue(Pos('"AutoDupe"', text) = 0, 'no AutoDupe group: ' + text);
      CheckTrue(Pos('"Contest"', text) = 0,  'no Contest group: ' + text);

      (* A STATION SETTING IS NOT, which is the other direction of the same
        claim -- a marker that answered True for everything would pass every
        assertion above and be useless. *)
      CheckFalse(s.CommandIsContestScoped('PTT ENABLE'),
                 'a station setting is not contest-scoped');
      CheckFalse(s.CommandIsContestScoped('NO SUCH COMMAND'),
                 'and an unknown name is simply False, not an error');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_EveryCommandNameIsTheOneAConfigFileUses;
const
   (* ONE NAME PER LINE, on purpose: a vocabulary change has to be
     readable in a diff, and a single 900-character line is not. *)
   EXPECTED = ''
      + '"ALL CW MESSAGES CHAINABLE",'
      + '"ALLOW AUTO UPDATE",'
      + '"ALT-D BUFFER ENABLE",'
      + '"ALT-D CQ ENABLE",'
      + '"ALWAYS CALL BLIND CQ",'
      + '"ASK FOR FREQUENCIES",'
      + '"AUTO CALL TERMINATE",'
      + '"AUTO DISPLAY DUPE QSO",'
      + '"AUTO DUPE ENABLE CQ",'
      + '"AUTO DUPE ENABLE S AND P",'
      + '"AUTO QSO NUMBER DECREMENT",'
      + '"AUTO RETURN TO CQ MODE",'
      + '"AUTO S&P ENABLE",'
      + '"AUTO S&P ENABLE SENSITIVITY",'
      + '"AUTO TIME INCREMENT",'
      + '"AUTO-CQ DELAY TIME",'
      + '"BACKUP LOG FREQUENCY",'
      + '"BAND MAP ALL BANDS",'
      + '"BAND MAP ALL MODES",'
      + '"BAND MAP CALL WINDOW ENABLE",'
      + '"BAND MAP DECAY TIME",'
      + '"BAND MAP DISPLAY CQ",'
      + '"BAND MAP DISPLAY GHZ",'
      + '"BAND MAP DISPLAY LIMIT",'
      + '"BAND MAP DUPE DISPLAY",'
      + '"BAND MAP GUARD BAND",'
      + '"BAND MAP ITEM HEIGHT",'
      + '"BAND MAP ITEM WIDTH",'
      + '"BAND MAP MULTS ONLY",'
      + '"BAND MAP SIZE",'
      + '"BAND MAP SO2R DISPLAY",'
      + '"BEEP ENABLE",'
      + '"BEEP EVERY 10 QSOS",'
      + '"BOLD FONT",'
      + '"BROADCAST ALL PACKET DATA",'
      + '"CALL OK NOW CW MESSAGE",'
      + '"CALL OK NOW MESSAGE",'
      + '"CALL OK NOW SSB MESSAGE",'
      + '"CALL WINDOW SHOW ALL SPOTS",'
      + '"CALLSIGN UPDATE ENABLE",'
      + '"CHECK LOG FILE SIZE",'
      + '"COLUMN AUTOSIZE",'
      + '"COMPLETE CALLSIGN MASK",'
      + '"COMPUTER ID",'
      + '"COMPUTER NAME",'
      + '"CONFIRM EDIT CHANGES",'
      + '"CONNECTION AT STARTUP",'
      + '"CONTACTS PER PAGE",'
      + '"COUNT DOMESTIC COUNTRIES",'
      + '"COUNTRY INFORMATION FILE",'
      + '"CQ CW EXCHANGE",'
      + '"CQ CW EXCHANGE NAME KNOWN",'
      + '"CQ EXCHANGE",'
      + '"CQ EXCHANGE NAME KNOWN",'
      + '"CQ SSB EXCHANGE",'
      + '"CQ SSB EXCHANGE NAME KNOWN",'
      + '"CTY UPDATE CHECK ON STARTUP",'
      + '"CUSTOM INITIAL EXCHANGE STRING",'
      + '"CUSTOM USER STRING",'
      + '"CW SPEED FROM DATABASE",'
      + '"DE ENABLE",'
      + '"DIGITAL MODE ENABLE",'
      + '"DOMESTIC FILENAME",'
      + '"DUPE SHEET AUTO RESET",'
      + '"DVK LOCALIZED MESSAGES ENABLE",'
      + '"ESCAPE EXITS SEARCH AND POUNCE",'
      + '"EXCHANGE MEMORY ENABLE",'
      + '"EXTERNAL LOGGER ADDRESS",'
      + '"EXTERNAL LOGGER ENABLED",'
      + '"EXTERNAL LOGGER PORT",'
      + '"FONT SIZE",'
      + '"FREQUENCY MEMORY ENABLE",'
      + '"FREQUENCY POLL RATE",'
      + '"GRID MAP CENTER",'
      + '"HAMSCORE ENABLE",'
      + '"HAMSCORE SEND CONTACT INFO",'
      + '"HAMSCORE URL",'
      + '"HAND LOG MODE",'
      + '"HF BAND ENABLE",'
      + '"IE SWITCH",'
      + '"IN BAND LOCKOUT",'
      + '"INCLUDE F-KEY NUMBER",'
      + '"INCREMENT TIME ENABLE",'
      + '"INITIAL EXCHANGE OVERWRITE",'
      + '"INSERT MODE",'
      + '"INTERCOM FILE ENABLE",'
      + '"KEYPAD CW MEMORIES",'
      + '"LEADING ZERO CHARACTER",'
      + '"LEAVE CURSOR IN CALL WINDOW",'
      + '"LITERAL DOMESTIC QTH",'
      + '"LOG FREQUENCY ENABLE",'
      + '"LOG RS SENT",'
      + '"LOG RST SENT",'
      + '"LOG SUB TITLE",'
      + '"LOG WITH SINGLE ENTER",'
      + '"LOOK FOR RST SENT",'
      + '"MAIN CALLSIGN",'
      + '"MAIN FONT",'
      + '"MESSAGE ENABLE",'
      + '"MINITOUR DURATION",'
      + '"MISSINGCALLSIGNS FILE ENABLE",'
      + '"MMTTY ENGINE",'
      + '"MP3 RECORDER ENABLE",'
      + '"MULT BY BAND",'
      + '"MULT BY MODE",'
      + '"MULT SHEET AUTO RESET",'
      + '"MULTI MULTS ONLY",'
      + '"MULTIPLE BANDS",'
      + '"MULTIPLE MODES",'
      + '"MY CALL",'
      + '"MY CHECK",'
      + '"MY COUNTRY",'
      + '"MY FD CLASS",'
      + '"MY FOC NUMBER",'
      + '"MY GRID",'
      + '"MY IOTA",'
      + '"MY ITU ZONE",'
      + '"MY NAME",'
      + '"MY PARK",'
      + '"MY POSTAL CODE",'
      + '"MY PREC",'
      + '"MY QTH",'
      + '"MY SECTION",'
      + '"MY STATE",'
      + '"MY ZONE",'
      + '"NAME FLAG ENABLE",'
      + '"NET STATUS UPDATE INTERVAL",'
      + '"NO BORDER",'
      + '"NO CAPTION",'
      + '"NO COLUMN HEADER",'
      + '"NO LOG",'
      + '"NO POLL DURING PTT",'
      + '"PADDLE MONITOR TONE",'
      + '"PADDLE PTT HOLD COUNT",'
      + '"PADDLE SPEED",'
      + '"PARTIAL CALL ENABLE",'
      + '"POSSIBLE CALL ACCEPT KEY",'
      + '"POSSIBLE CALL LEFT KEY",'
      + '"POSSIBLE CALL RIGHT KEY",'
      + '"POSSIBLE CALLS",'
      + '"PSTROTATOR IP ADDRESS",'
      + '"PSTROTATOR UDP PORT",'
      + '"PTT ENABLE",'
      + '"PTT LOCKOUT",'
      + '"PTT TURN ON DELAY",'
      + '"PTT VIA COMMANDS",'
      + '"QSL CW MESSAGE",'
      + '"QSL MESSAGE",'
      + '"QSL SSB MESSAGE",'
      + '"QSO BEFORE CW MESSAGE",'
      + '"QSO BEFORE MESSAGE",'
      + '"QSO BEFORE SSB MESSAGE",'
      + '"QSO BY BAND",'
      + '"QSO BY MODE",'
      + '"QSO NUMBER BY BAND",'
      + '"QSO POINTS DOMESTIC CW",'
      + '"QSO POINTS DOMESTIC PHONE",'
      + '"QSO POINTS DX CW",'
      + '"QSO POINTS DX PHONE",'
      + '"QSX ENABLE",'
      + '"QSY INACTIVE RADIO",'
      + '"QTC ENABLE",'
      + '"QTC EXTRA SPACE",'
      + '"QTC MINUTES",'
      + '"QTC QRS",'
      + '"QUESTION MARK CHAR",'
      + '"QUICK QSL CW MESSAGE",'
      + '"QUICK QSL CW MESSAGE1",'
      + '"QUICK QSL KEY 1",'
      + '"QUICK QSL KEY 2",'
      + '"QUICK QSL MESSAGE 1",'
      + '"QUICK QSL MESSAGE 2",'
      + '"QUICK QSL SSB MESSAGE",'
      + '"QZB RANDOM OFFSET ENABLE",'
      + '"RADIO TCP SERVER PORT",'
      + '"RADIUS OF EARTH",'
      + '"RANDOM CQ MODE",'
      + '"REPEAT S&P CW EXCHANGE",'
      + '"REPEAT S&P EXCHANGE",'
      + '"REPEAT S&P SSB EXCHANGE",'
      + '"REVERSE INITIAL EX",'
      + '"S&P CW EXCHANGE",'
      + '"S&P EXCHANGE",'
      + '"S&P SSB EXCHANGE",'
      + '"SAY HI ENABLE",'
      + '"SAY HI RATE CUTOFF",'
      + '"SCORE POSTING URL",'
      + '"SCORE READING URL",'
      + '"SEND COMPLETE FOUR LETTER CALL",'
      + '"SERVER ADDRESS",'
      + '"SERVER AUTO SYNCHRONIZE LOG ON CONNECT",'
      + '"SERVER PORT",'
      + '"SHIFT KEY ENABLE",'
      + '"SHORT 0",'
      + '"SHORT 1",'
      + '"SHORT 2",'
      + '"SHORT 9",'
      + '"SHORT INTEGERS",'
      + '"SHOW ALL SERIAL PORTS",'
      + '"SHOW DOMESTIC MULTIPLIER NAME",'
      + '"SHOW FREQUENCY IN LOG",'
      + '"SHOW GRIDLINES",'
      + '"SHOW TYPED CALLSIGN",'
      + '"SKIP ACTIVE BAND",'
      + '"SLASH MARK CHAR",'
      + '"SPACE BAR DUPE CHECK ENABLE",'
      + '"SPOT COLLECTOR ENABLED",'
      + '"SPRINT QSY RULE",'
      + '"START SENDING NOW KEY",'
      + '"STATIONS CALLSIGNS MASK",'
      + '"SWAP PACKET SPOT RADIOS",'
      + '"SWAP PADDLES",'
      + '"SWAP RADIO RELAY SENSE",'
      + '"TELNET SERVER",'
      + '"TUNE ALT-D ENABLE",'
      + '"TUNE WITH DITS",'
      + '"TWO RADIO MODE",'
      + '"UNKNOWN COUNTRY FILE ENABLE",'
      + '"UNKNOWN COUNTRY FILE NAME",'
      + '"UPDATE RESTART FILE ENABLE",'
      + '"USE CONTROL PORT",'
      + '"USE RECORDED SIGNS",'
      + '"VHF BAND ENABLE",'
      + '"WAIT FOR STRENGTH",'
      + '"WAKE UP TIME OUT",'
      + '"WARC BAND ENABLE",'
      + '"WILDCARD PARTIALS",'
      + '"WSJT-X BROADCAST PORT",'
      + '"WSJT-X ENABLED",'
      + '"WSJT-X MULTICAST GROUP",'
      + '"WSJT-X RADIO CONTROL ENABLED",'
      + '"WSJT-X SEND HIGHLIGHTS",'
      + '"YCCC SO2R ENABLE"';
var
   s: TR4WSettings;
   names: TStringList;
begin
   BeginTest('the command names are exactly the ones TR4W has always accepted');

   s := TR4WSettings.Create;
   try
      names := s.CommandNames;
      try
         names.Sort;
         CheckEquals(EXPECTED, string(names.CommaText),
                     'the settings vocabulary changed -- if that is intended, '
                     + 'paste the actual list here AFTER checking each new name '
                     + 'is one a config file would really contain');
      finally
         names.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_AStaleIniCannotOverrideTheStore;
var
   cmd: ShortString;
   val: ShortString;
   was: boolean;
begin
   BeginTest('an untrusted caller cannot apply a migrated setting');

   was := Settings.BandMap.MultsOnly;
   try
      Settings.BandMap.MultsOnly := False;

      cmd := ShortString(AnsiString('BAND MAP MULTS ONLY'));
      val := ShortString(AnsiString('TRUE'));

      (* THE INI LOADER'S CALL: aApplyJSONOwned defaults to False. *)
      CheckTrue(CheckCommand(@cmd, val),
                'the line is ACCEPTED -- no "invalid statement" dialog');
      CheckFalse(Settings.BandMap.MultsOnly,
                 'but NOT APPLIED: the store is the source of record');

      (* A TRUSTED CALLER -- Preferences, a multi-op peer, a contest .cfg --
        passes True and the value goes in. *)
      CheckTrue(CheckCommand(@cmd, val, True), 'a trusted caller is accepted');
      CheckTrue(Settings.BandMap.MultsOnly, 'and applied');
   finally
      Settings.BandMap.MultsOnly := was;
   end;
end;

procedure TSettingsModelTests.Test_AContestFileStillOverridesForItsContest;
begin
   (* THE OTHER HALF OF THE FIX, and the half that is easy to miss.

     LogCfg decides whether a contest .cfg line may be applied by asking
     CommandIsJSONOwned, and passes aApplyJSONOwned = True only when the
     answer is yes. That function scanned CFGCA alone, so a MIGRATED setting
     -- whose row is deleted -- answered False, and the guard above would then
     have muted the contest file too.

     A contest .cfg is the one source that is SUPPOSED to win while its
     contest is loaded. Without this the guard would have fixed the ini
     problem by breaking that. *)
   BeginTest('a migrated setting still counts as JSON-owned for a contest .cfg');

   CheckTrue(CommandIsJSONOwned('BAND MAP MULTS ONLY'),
             'a migrated setting is JSON-owned');
   CheckTrue(CommandIsJSONOwned('PTT ENABLE'),
             'so is one that left the Config record');

   (* And a command that never moved still answers from its row. *)
   (* BAND MAP DECAY TIME HAS SINCE MIGRATED TOO, so this no longer proves
     what it was written to prove -- it now takes the Settings.OwnsCommand
     arm like the two above it. Kept because the ANSWER still has to be True:
     the contest .cfg is the one source that must still win, and it decides by
     asking this. *)
   CheckTrue(CommandIsJSONOwned('BAND MAP DECAY TIME'),
             'still JSON-owned now that it is a property');
end;

procedure TSettingsModelTests.Test_MessageDefaultsAreTheOnesInitializeStringsSeeded;
var
   s: TR4WSettings;
begin
   (* THE DECLARATIONS ARE NOT THE DEFAULTS, and this is the test that would
     have caught believing they were.

     All seventeen globals were declared in LogCW.pas with their initialisers
     COMMENTED OUT, and every line cfgdef.pas had for them is commented out
     too -- so reading either file says "these start empty". Thirteen of them
     do not: uCFG.InitializeStrings seeded them from a table of pointers at
     startup, BEFORE any configuration file was read, and that is what an
     operator who has configured nothing actually gets.

     A blank default here is not a build failure and not a test failure
     anywhere else. It is a station that answers a call by keying nothing. *)
   BeginTest('the message templates default to what InitializeStrings seeded');
   s := TR4WSettings.Create;
   try
      CheckEquals('} OK %',      s.Messages.CallOkNowCw,  'CorrectedCallMessage');
      CheckEquals('CORCALL.WAV', s.Messages.CallOkNowSsb, 'CorrectedCallPhoneMessage');

      CheckEquals('CQEXCHNG.WAV', s.Messages.CqExchangeSsb,
                  'CQPhoneExchange');
      CheckEquals('CQEXNAME.WAV', s.Messages.CqExchangeSsbNameKnown,
                  'CQPhoneExchangeNameKnown');

      CheckEquals('TU \ TEST', s.Messages.QslCw,  'QSLMessage');
      CheckEquals('QSL.WAV',   s.Messages.QslSsb, 'QSLPhoneMessage');

      CheckEquals(' SRI QSO B4 TU \ TEST', s.Messages.QsoBeforeCw,
                  'QSOBeforeMessage');
      CheckEquals('QSOB4.WAV', s.Messages.QsoBeforeSsb,
                  'QSOBeforePhoneMessage');

      CheckEquals('TU',           s.Messages.QuickQslCw1, 'QuickQSLMessage1');
      CheckEquals('TU',           s.Messages.QuickQslCw2, 'QuickQSLMessage2');
      CheckEquals('QUICKQSL.WAV', s.Messages.QuickQslSsb, 'QuickQSLPhoneMessage');

      CheckEquals('RPTSPEX.WAV',  s.Messages.RepeatSpExchangeSsb,
                  'RepeatSearchAndPouncePhoneExchange');
      CheckEquals('SAPEXCHG.WAV', s.Messages.SpExchangeSsb,
                  'SearchAndPouncePhoneExchange');

      (* AND THE FOUR THAT REALLY ARE EMPTY. Empty is load-bearing for these:
        LogCfg.tSetupExchangeNumbers fills each one ONLY IF it is still empty,
        so a helpful-looking default here would suppress the contest's own
        exchange for every contest. *)
      CheckEquals('', s.Messages.CqExchangeCw,          'CQExchange');
      CheckEquals('', s.Messages.CqExchangeCwNameKnown, 'CQExchangeNameKnown');
      CheckEquals('', s.Messages.SpExchangeCw,          'SearchAndPounceExchange');
      CheckEquals('', s.Messages.RepeatSpExchangeCw,
                  'RepeatSearchAndPounceExchange');

      (* THE CUT NUMBERS, which went to Cw rather than here. cfgdef.pas
        assigned '0', '1' and '9' at every startup over LogCW's declared T, A
        and N, so the digits are the live defaults and the letters were dead
        text. Short2 was in neither list and was declared '2' already. *)
      CheckEquals('0', s.Cw.Short0, 'Short0');
      CheckEquals('1', s.Cw.Short1, 'Short1');
      CheckEquals('2', s.Cw.Short2, 'Short2');
      CheckEquals('9', s.Cw.Short9, 'Short9');
   finally
      s.Free;
   end;
end;

procedure TSettingsModelTests.Test_EveryMessageCommandReachesItsOwnProperty;
var
   s: TR4WSettings;

   procedure Accepts(const aCommand, aValue: string);
   begin
      CheckTrue(s.TrySetByCommand(aCommand, aValue), aCommand + ' is accepted');
   end;

begin
   (* THIRTY COMMAND NAMES OVER SEVENTEEN PROPERTIES, every one of them
     reached through an Alias or an AlsoKnownAs, because not one of these
     legacy spellings derives from a property path.

     WHAT THIS CATCHES THAT THE VOCABULARY TEST CANNOT: that test checks the
     NAMES exist. A TRANSPOSED alias -- CQ SSB EXCHANGE pointing at the CW
     property -- leaves the name list identical and silently makes TR4W key
     the wrong message in one mode. Nothing else in this tree would notice:
     the golden corpus exercises ADIF and Cabrillo export and never sends a
     character of CW.

     EVERY VALUE IS DISTINCT, so a crossed pair cannot coincide, and the
     writes all happen before any of the reads -- an assertion that read a
     property as an argument would be evaluating it BEFORE the setter ran.
     Where three names share one property the LAST write is the one to
     expect. *)
   BeginTest('every message command reaches its own property');
   s := TR4WSettings.Create;
   try
      Accepts('CALL OK NOW CW MESSAGE',  'okc');
      Accepts('CALL OK NOW MESSAGE',     'okc2');
      Accepts('CALL OK NOW SSB MESSAGE', 'oks');

      Accepts('CQ CW EXCHANGE',             'cqc');
      Accepts('CQ EXCHANGE',                'cqc2');
      Accepts('CQ CW EXCHANGE NAME KNOWN',  'cqnc');
      Accepts('CQ EXCHANGE NAME KNOWN',     'cqn2');
      Accepts('CQ SSB EXCHANGE',            'cqs');
      Accepts('CQ SSB EXCHANGE NAME KNOWN', 'cqns');

      Accepts('QSL CW MESSAGE',  'qslc');
      Accepts('QSL MESSAGE',     'qslc2');
      Accepts('QSL SSB MESSAGE', 'qsls');

      Accepts('QSO BEFORE CW MESSAGE',  'b4c');
      Accepts('QSO BEFORE MESSAGE',     'b4c2');
      Accepts('QSO BEFORE SSB MESSAGE', 'b4s');

      (* THREE NAMES, ONE PROPERTY -- they were three CFGCA rows sharing a
        crAddress, and QUICK QSL CW MESSAGE1 has no space before its digit
        while QUICK QSL MESSAGE 1 does. *)
      Accepts('QUICK QSL CW MESSAGE',  'qq1');
      Accepts('QUICK QSL CW MESSAGE1', 'qq1b');
      Accepts('QUICK QSL MESSAGE 1',   'qq1c');
      Accepts('QUICK QSL MESSAGE 2',   'qq2');
      Accepts('QUICK QSL SSB MESSAGE', 'qqs');

      Accepts('REPEAT S&P CW EXCHANGE',  'rspc');
      Accepts('REPEAT S&P EXCHANGE',     'rspc2');
      Accepts('REPEAT S&P SSB EXCHANGE', 'rsps');

      Accepts('S&P CW EXCHANGE',  'spc');
      Accepts('S&P EXCHANGE',     'spc2');
      Accepts('S&P SSB EXCHANGE', 'sps');

      (* ONE CHARACTER, AND NOT TRIMMED: a space is a legal cut character, so
        trimming would turn a configured space bar into a refusal. *)
      Accepts('SHORT 0', 'T');
      Accepts('SHORT 1', 'A');
      Accepts('SHORT 2', 'U');
      Accepts('SHORT 9', 'N');

      CheckEquals('okc2', s.Messages.CallOkNowCw,  'CALL OK NOW MESSAGE, written last');
      CheckEquals('oks',  s.Messages.CallOkNowSsb, 'CALL OK NOW SSB MESSAGE');

      CheckEquals('cqc2', s.Messages.CqExchangeCw,           'CQ EXCHANGE, written last');
      CheckEquals('cqn2', s.Messages.CqExchangeCwNameKnown,  'CQ EXCHANGE NAME KNOWN');
      CheckEquals('cqs',  s.Messages.CqExchangeSsb,          'CQ SSB EXCHANGE');
      CheckEquals('cqns', s.Messages.CqExchangeSsbNameKnown, 'CQ SSB EXCHANGE NAME KNOWN');

      CheckEquals('qslc2', s.Messages.QslCw,  'QSL MESSAGE, written last');
      CheckEquals('qsls',  s.Messages.QslSsb, 'QSL SSB MESSAGE');

      CheckEquals('b4c2', s.Messages.QsoBeforeCw,  'QSO BEFORE MESSAGE, written last');
      CheckEquals('b4s',  s.Messages.QsoBeforeSsb, 'QSO BEFORE SSB MESSAGE');

      CheckEquals('qq1c', s.Messages.QuickQslCw1, 'QUICK QSL MESSAGE 1, written last of three');
      CheckEquals('qq2',  s.Messages.QuickQslCw2, 'QUICK QSL MESSAGE 2');
      CheckEquals('qqs',  s.Messages.QuickQslSsb, 'QUICK QSL SSB MESSAGE');

      CheckEquals('rspc2', s.Messages.RepeatSpExchangeCw,  'REPEAT S&P EXCHANGE, written last');
      CheckEquals('rsps',  s.Messages.RepeatSpExchangeSsb, 'REPEAT S&P SSB EXCHANGE');

      CheckEquals('spc2', s.Messages.SpExchangeCw,  'S&P EXCHANGE, written last');
      CheckEquals('sps',  s.Messages.SpExchangeSsb, 'S&P SSB EXCHANGE');

      CheckEquals('T', s.Cw.Short0, 'SHORT 0');
      CheckEquals('A', s.Cw.Short1, 'SHORT 1');
      CheckEquals('U', s.Cw.Short2, 'SHORT 2');
      CheckEquals('N', s.Cw.Short9, 'SHORT 9');

      (* THE MESSAGES ARE THE CONTEST'S, so they never reach tr4w.json. The
        cut numbers are the OPERATOR'S, and do. *)
      CheckTrue(s.CommandIsContestScoped('CQ CW EXCHANGE'),
                'an exchange is a contest parameter');
      CheckTrue(s.CommandIsContestScoped('QUICK QSL SSB MESSAGE'),
                'so is a quick QSL');
      CheckFalse(s.CommandIsContestScoped('SHORT 0'),
                 'a cut number is how this operator sends a digit');
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
   Test_AStoreOwnedCommandIsAcceptedAndIsNotRetired;
   Test_ARangeIsPartOfTheType;
   Test_AStoredValueOutOfRangeIsClamped;
   Test_TheReadPathAndTheWritePathAgree;
   Test_AContestParameterNeverReachesTheJson;
   Test_EveryCommandNameIsTheOneAConfigFileUses;
   Test_AStaleIniCannotOverrideTheStore;
   Test_AContestFileStillOverridesForItsContest;
   Test_MessageDefaultsAreTheOnesInitializeStringsSeeded;
   Test_EveryMessageCommandReachesItsOwnProperty;
end;

end.
