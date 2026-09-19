unit uTestNewContestCommands;

(* THE NEW CONTEST DIALOG'S VALUES MUST SURVIVE THE STATION LOAD.

  NY4I, macOS, 2026-09-19: New Contest, callsign NY4I, ARRL-FD, class 3A,
  section WCF -> OK -> "No callsign specified!!". The dialog applied its values
  into the settings object, and LoadSettingsForStartup then loaded
  settings\tr4w.json over them. See uNewContestCommands for the history.

  IT WAS INVISIBLE ON A CONFIGURED WINDOWS STATION, which is how it survived,
  so these tests build the station file themselves rather than trusting
  whatever the machine running them holds. Three stations:

    FIRST RUN    no settings file at all -- what every new installation meets,
                 and how NY4I reproduced it with a blanked tr4w.json.
    FRESH        the stored MY CALL, MY FD CLASS and MY SECTION are empty.
    CONFIGURED   the station is NY4I, class 1D, section NFL -- and the
                 operator runs this one contest as the club call W4TA, 3A,
                 WCF. The contest's values must win.

  THE STARTUP ORDER IS DRIVEN FOR REAL, in the order uProgramMain runs it:
  the dialog queues; LoadSettingsForStartup reads the station file; the
  contest tracker is reset, exactly as ReadInConfigFile(cfgCFG) resets it for
  a log that does not exist yet; ApplyNewContestChoices applies. What is
  asserted afterwards is what uLogStore.CaptureConfiguration reads when it
  creates the log: the value through CFGCommandValueAsString, and whether
  CommandCameFromContestCFG marks it as the contest's.

  "NOT LOADED YET" IS MODELLED, NOT ASSUMED. At dialog time the settings
  object holds its constructor defaults, because nothing has read the file.
  The fields these tests look at are put back to those defaults before the
  dialog runs, which is the state the dialog really meets.

  A STATION SENTINEL (MY GRID) proves the station file is not overwritten:
  the dialog used to save the settings object before it had been loaded,
  which wrote the defaults over every station setting. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TNewContestCommandsTests = class(TTestCase)
   private
      FFile: string;
      procedure WriteStation(const aCall, aFdClass, aSection,
                             aMainCallsign: string);
      procedure ForgetStationAsBeforeTheLoad;
      procedure RunNewContest(const aCall, aFdClass, aSection: string);
      procedure CheckCaptured(const aCommand, aExpected: string);
   protected
      procedure TestFreshStationKeepsTheDialogValues;
      procedure TestConfiguredStationDoesNotOverrideAClubCall;
      procedure TestFirstRunWithNoSettingsFile;
      procedure TestNothingQueuedDoesNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, fpjson,
   uCFG, uSettingsModel, uTR4WConfigFile, uNewContestCommands;

const
   GRID_SENTINEL = 'EL98';

(* The station's settings file, as a previous run left it. Written through
  the real SaveSettings so the file has exactly the program's shape. *)
procedure TNewContestCommandsTests.WriteStation(const aCall, aFdClass,
   aSection, aMainCallsign: string);
begin
   FFile := IncludeTrailingPathDelimiter(GetTempDir) +
            Format('tr4w-newcontest-%d.json', [Random(1000000000)]);
   Settings.My.Call         := aCall;
   Settings.My.FdClass      := aFdClass;
   Settings.My.Section      := aSection;
   Settings.My.MainCallsign := aMainCallsign;
   Settings.My.Grid         := GRID_SENTINEL;
   SaveSettings(FFile, Settings);
end;

procedure TNewContestCommandsTests.ForgetStationAsBeforeTheLoad;
begin
   (* The constructor's values -- TMySettings.Create sets every one of these
     to ''. *)
   Settings.My.Call         := '';
   Settings.My.FdClass      := '';
   Settings.My.Section      := '';
   Settings.My.MainCallsign := '';
   Settings.My.Grid         := '';
end;

(* What happens between OK in the dialog and the log being created. *)
procedure TNewContestCommandsTests.RunNewContest(const aCall, aFdClass,
   aSection: string);
begin
   ForgetStationAsBeforeTheLoad;

   (* SaveNewContest. CONTEST is not queued here: its effect is FoundContest,
     which needs the booted contest engine this binary does not have. *)
   ClearNewContestChoices;
   SetNewContestMainCallsign(aCall);
   QueueNewContestCommand('MY CALL', aCall);
   QueueNewContestCommand('MY FD CLASS', aFdClass);
   QueueNewContestCommand('MY SECTION', aSection);

   (* uProgramMain, in its order -- including the first-run branch, which
     saves the freshly seeded object when the file had no settings section. *)
   if not LoadSettingsForStartup(FFile, Settings) then
      begin
      SaveSettings(FFile, Settings);
      end;
   ClearContestCFGCommands;
   CheckEquals(3, ApplyNewContestChoices(FFile), 'all three are accepted');
end;

procedure TNewContestCommandsTests.CheckCaptured(const aCommand,
   aExpected: string);
begin
   CheckEquals(aExpected, CFGCommandValueAsString(aCommand),
               aCommand + ' holds the value chosen in New Contest');
   CheckTrue(CommandCameFromContestCFG(aCommand),
             aCommand + ' is marked as the CONTEST''S, so the log captures ' +
             'it with source = contest');
end;

procedure TNewContestCommandsTests.TestFreshStationKeepsTheDialogValues;
var
   onDisk: TR4WSettings;
begin
   BeginTest('a fresh station: the dialog''s call, class and section survive ' +
             'the station load');

   WriteStation('', '', '', '');
   RunNewContest('NY4I', '3A', 'WCF');

   CheckCaptured('MY CALL', 'NY4I');
   CheckCaptured('MY FD CLASS', '3A');
   CheckCaptured('MY SECTION', 'WCF');
   CheckEquals('NY4I', Settings.My.Call,
               'My.Call -- what ConfigurationOkay checks -- holds the call');
   CheckEquals(GRID_SENTINEL, Settings.My.Grid,
               'the station''s own settings are still loaded');

   onDisk := TR4WSettings.Create;
   try
      LoadSettingsForStartup(FFile, onDisk);
      CheckEquals('NY4I', onDisk.My.MainCallsign,
                  'the first callsign is remembered as the station''s own');
      CheckEquals(GRID_SENTINEL, onDisk.My.Grid,
                  'saving it did not overwrite the station file with defaults');
      CheckEquals('', onDisk.My.Call,
                  'the contest''s values are not written into the station file');
      CheckEquals('', onDisk.My.FdClass, 'nor its class');
   finally
      onDisk.Free;
   end;
end;

procedure TNewContestCommandsTests.TestConfiguredStationDoesNotOverrideAClubCall;
var
   onDisk: TR4WSettings;
begin
   BeginTest('a configured station: the club call chosen for this contest ' +
             'beats the stored station call');

   WriteStation('NY4I', '1D', 'NFL', 'NY4I');
   RunNewContest('W4TA', '3A', 'WCF');

   CheckCaptured('MY CALL', 'W4TA');
   CheckCaptured('MY FD CLASS', '3A');
   CheckCaptured('MY SECTION', 'WCF');

   (* THE PROPERTIES THEMSELVES, not only through the command name -- a
     CFGCommandValueAsString check would pass just as well if MY CALL had
     resolved to MainCallsign. ConfigurationOkay reads My.Call. *)
   CheckEquals('W4TA', Settings.My.Call, 'MY CALL is My.Call');
   CheckEquals('NY4I', Settings.My.MainCallsign,
               'and NOT My.MainCallsign, which still holds the station''s call');
   CheckEquals('3A', Settings.My.FdClass, 'MY FD CLASS is My.FdClass');
   CheckEquals('WCF', Settings.My.Section, 'MY SECTION is My.Section');

   onDisk := TR4WSettings.Create;
   try
      LoadSettingsForStartup(FFile, onDisk);
      CheckEquals('NY4I', onDisk.My.MainCallsign,
                  'the station''s own callsign is not replaced by a club call');
      CheckEquals('NY4I', onDisk.My.Call,
                  'the station default is untouched by this contest');
      CheckEquals('1D', onDisk.My.FdClass, 'and so is its class');
      CheckEquals(GRID_SENTINEL, onDisk.My.Grid,
                  'and every other station setting');
   finally
      onDisk.Free;
   end;
end;

procedure TNewContestCommandsTests.TestFirstRunWithNoSettingsFile;
var
   onDisk: TR4WSettings;
begin
   BeginTest('a new installation with no settings file: the dialog''s values ' +
             'survive, and the file gets the station callsign only');

   (* NY4I blanked tr4w.json and reproduced it: the log then said the file
     "already holds a settings section" -- written during that run, by the
     dialog, from a settings object nothing had loaded. *)
   FFile := IncludeTrailingPathDelimiter(GetTempDir) +
            Format('tr4w-newcontest-first-%d.json', [Random(1000000000)]);
   CheckFalse(FileExists(FFile), 'there is no settings file');

   RunNewContest('NY4I', '3A', 'WCF');

   CheckCaptured('MY CALL', 'NY4I');
   CheckCaptured('MY FD CLASS', '3A');
   CheckCaptured('MY SECTION', 'WCF');
   CheckEquals('NY4I', Settings.My.Call,
               'My.Call -- what ConfigurationOkay checks -- holds the call');

   onDisk := TR4WSettings.Create;
   try
      CheckTrue(LoadSettingsForStartup(FFile, onDisk),
                'the settings file now has a settings section');
      CheckEquals('NY4I', onDisk.My.MainCallsign,
                  'holding the station''s callsign');
      CheckEquals('', onDisk.My.Call,
                  'and not the contest''s values, which live in the log');
   finally
      onDisk.Free;
   end;
end;

procedure TNewContestCommandsTests.TestNothingQueuedDoesNothing;
begin
   BeginTest('opening an existing contest, a command-line file or a headless ' +
             'run queues nothing, and nothing is applied or written');

   FFile := IncludeTrailingPathDelimiter(GetTempDir) +
            Format('tr4w-newcontest-none-%d.json', [Random(1000000000)]);
   ClearNewContestChoices;
   ClearContestCFGCommands;

   CheckFalse(HasNewContestChoices, 'nothing is queued');
   CheckEquals(0, ApplyNewContestChoices(FFile), 'nothing is applied');
   CheckFalse(FileExists(FFile), 'and no settings file is written');
   CheckFalse(CommandCameFromContestCFG('MY CALL'),
              'and nothing is marked as the contest''s');
end;

procedure TNewContestCommandsTests.RunAllTests;
var
   snapshot: TJSONObject;

   procedure Scrub;
   begin
      if (FFile <> '') and FileExists(FFile) then
         begin
         DeleteFile(FFile);
         end;
      FFile := '';
   end;

begin
   Randomize;
   (* The GLOBAL settings object is the one CheckCommand writes, so these tests
     have to use it -- and put it back exactly as they found it. *)
   snapshot := Settings.ToJSON;
   try
      try
         TestFreshStationKeepsTheDialogValues;
      finally
         Scrub;
      end;
      try
         TestConfiguredStationDoesNotOverrideAClubCall;
      finally
         Scrub;
      end;
      try
         TestFirstRunWithNoSettingsFile;
      finally
         Scrub;
      end;
      try
         TestNothingQueuedDoesNothing;
      finally
         Scrub;
      end;
   finally
      Settings.FromJSON(snapshot);
      snapshot.Free;
      ClearContestCFGCommands;
      ClearNewContestChoices;
   end;
end;

end.
