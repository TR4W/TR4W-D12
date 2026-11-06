unit uTestOpenLogRelaunch;

(* FILE > OPEN LOG... (issue 218, S0): the parts that decide without a screen.

   The menu click, the picker, the shutdown and the relaunch itself are only
   provable by a running program -- docs/BENCH_QUEUE.md carries that. What is
   pinned here is what would otherwise be wrong silently: a child started on
   the wrong settings, a pid mistaken for the contest file, a path split at a
   space, a refusal that lets a keyed radio be dropped. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TOpenLogRelaunchTests = class(TTestCase)
   protected
      procedure TestRefusal;
      procedure TestSameFile;
      procedure TestArgumentsPlain;
      procedure TestArgumentsCarrySettingsAndLanguage;
      procedure TestArgumentsDropWhatDoesNotCarry;
      procedure TestWaitSwitchParse;
      procedure TestTheChildReadsWhatTheParentWrote;
      procedure TestExecutable;
      procedure TestRequestIsOneShot;
      (* Issue 228: the New Contest dialog in place of the picker. *)
      procedure TestTheActionRulesInOrder;
      procedure TestEachAnswerPlansItsRelaunch;
      procedure TestCancelPlansNothing;
      procedure TestTheHandOffSwitch;
      procedure TestTheHandOffFileRoundTrips;
      procedure TestABadHandOffFileQueuesNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   Classes,
   uContestFileKind,     (* TContestFileKind -- what PlanOpenLog is told *)
   uNewContestForm,      (* TNewContestChoice -- the dialog's answer *)
   uNewContest,          (* NewContestResultFile -- the answer as a file *)
   uNewContestCommands,  (* the queue and its hand-off file *)
   uOpenLogRelaunch;

function Joined(const aArgs: TRelaunchArgs): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(aArgs) do
      begin
      if i > 0 then
         begin
         Result := Result + '|';
         end;
      Result := Result + aArgs[i];
      end;
end;

procedure TOpenLogRelaunchTests.TestRefusal;
begin
   BeginTest('TestRefusal');
   CheckTrue(OpenLogRefusal(False, False) = olrNone, 'quiet: go ahead');
   CheckTrue(OpenLogRefusal(True, False) = olrTransmitting, 'keyed radio refuses');
   CheckTrue(OpenLogRefusal(False, True) = olrSendingCW, 'CW being sent refuses');
   CheckTrue(OpenLogRefusal(True, True) = olrTransmitting,
             'keyed AND sending reports the keyed radio, the wider statement');
end;

procedure TOpenLogRelaunchTests.TestSameFile;
var
   dir: string;
begin
   BeginTest('TestSameFile');
   dir := IncludeTrailingPathDelimiter(GetTempDir);
   CheckTrue(IsSameLogFile(dir + 'contest.db', dir + 'contest.db'), 'identical');
   CheckFalse(IsSameLogFile(dir + 'a.db', dir + 'b.db'), 'different files');
   CheckFalse(IsSameLogFile('', dir + 'a.db'), 'nothing chosen is never the same');
   CheckFalse(IsSameLogFile(dir + 'a.db', ''), 'nothing open is never the same');
   CheckTrue(IsSameLogFile(dir + 'sub' + PathDelim + '..' + PathDelim + 'a.db',
                           dir + 'a.db'),
             'expanded before comparing');
   if FileNameCaseSensitive then
      begin
      CheckFalse(IsSameLogFile(dir + 'A.DB', dir + 'a.db'),
                 'case matters where the file system says so');
      end
   else
      begin
      CheckTrue(IsSameLogFile(dir + 'A.DB', dir + 'a.db'),
                'case does not matter where the file system says so');
      end;
end;

procedure TOpenLogRelaunchTests.TestArgumentsPlain;
var
   args: TRelaunchArgs;
begin
   BeginTest('TestArgumentsPlain');
   args := BuildRelaunchArguments([], 'C:\My Logs\CQ WW CW.db', 4242);
   CheckEquals(2, Length(args), 'the file and the wait switch');
   CheckEquals('C:\My Logs\CQ WW CW.db', args[0],
               'a path with spaces is ONE element, unquoted -- TProcess quotes it');
   CheckEquals('--wait-for-instance=4242', args[1], 'the wait switch carries the pid');
end;

procedure TOpenLogRelaunchTests.TestArgumentsCarrySettingsAndLanguage;
begin
   BeginTest('TestArgumentsCarrySettingsAndLanguage');
   CheckEquals('new.db|--settings|D:\st 1\tr4w.json|--lang|es|--wait-for-instance=7',
               Joined(BuildRelaunchArguments(
                  ['old.db', '--settings', 'D:\st 1\tr4w.json', '--lang', 'es'],
                  'new.db', 7)),
               'the spaced forms carry both halves');
   CheckEquals('new.db|--settings=x.json|--lang=de|--wait-for-instance=7',
               Joined(BuildRelaunchArguments(
                  ['--settings=x.json', 'old.cfg', '--lang=de'], 'new.db', 7)),
               'the joined forms carry as they are');
   CheckEquals('new.db|-l|fr|--wait-for-instance=7',
               Joined(BuildRelaunchArguments(['-l', 'fr'], 'new.db', 7)),
               '-l is --lang');
   CheckEquals('new.db|--wait-for-instance=7',
               Joined(BuildRelaunchArguments(['old.db', '--settings'], 'new.db', 7)),
               'a switch with no value after it is dropped');
end;

procedure TOpenLogRelaunchTests.TestArgumentsDropWhatDoesNotCarry;
begin
   BeginTest('TestArgumentsDropWhatDoesNotCarry');
   CheckEquals('new.db|--wait-for-instance=9',
               Joined(BuildRelaunchArguments(
                  ['old.db', '/EXPORT', '/RESCORE', '--wait-for-instance=3'],
                  'new.db', 9)),
               'the old file, headless switches and an inherited wait switch go');
end;

procedure TOpenLogRelaunchTests.TestWaitSwitchParse;
var
   pid: cardinal;
begin
   BeginTest('TestWaitSwitchParse');
   CheckFalse(WaitForInstanceRequested([], pid), 'no arguments');
   CheckFalse(WaitForInstanceRequested(['contest.db', '--lang=es'], pid), 'not present');
   CheckTrue(WaitForInstanceRequested(['contest.db', '--wait-for-instance=1234'], pid),
             'present');
   CheckEquals(1234, integer(pid), 'the pid is read');
   CheckTrue(WaitForInstanceRequested(['--WAIT-FOR-INSTANCE=5'], pid),
             'case-insensitive, like every other switch');
   CheckEquals(5, integer(pid), 'and its value');
   CheckFalse(WaitForInstanceRequested(['--wait-for-instance='], pid), 'empty value');
   CheckFalse(WaitForInstanceRequested(['--wait-for-instance=12a'], pid), 'not a number');
   CheckFalse(WaitForInstanceRequested(['--wait-for-instance=$10'], pid), 'no hex');
   CheckFalse(WaitForInstanceRequested(['--wait-for-instance=-1'], pid), 'no sign');
   CheckFalse(WaitForInstanceRequested(['--wait-for-instance=4294967296'], pid),
              'too large for a pid');
   CheckTrue(WaitForInstanceRequested(['--wait-for-instance=4294967295'], pid),
             'the largest');
   CheckFalse(WaitForInstanceRequested(['--wait-for-instance', '12'], pid),
              'the spaced form is not accepted -- the value would read as a contest file');
end;

procedure TOpenLogRelaunchTests.TestTheChildReadsWhatTheParentWrote;
var
   pid: cardinal;
begin
   BeginTest('TestTheChildReadsWhatTheParentWrote');
   CheckTrue(WaitForInstanceRequested(
                BuildRelaunchArguments(['--lang', 'it'], 'x.db', 31337), pid),
             'the round trip');
   CheckEquals(31337, integer(pid), 'the pid survives it');
end;

procedure TOpenLogRelaunchTests.TestExecutable;
begin
   BeginTest('TestExecutable');
   CheckEquals('C:\TR4W\tr4w.exe', RelaunchExecutable('C:\TR4W\tr4w.exe', ''),
               'no AppImage: the running binary');
   CheckEquals('/home/op/TR4W.AppImage',
               RelaunchExecutable('/tmp/.mount_TR4WxYz/usr/bin/tr4w',
                                  '/home/op/TR4W.AppImage'),
               'inside an AppImage: the .AppImage, not the mount that goes away');
end;

procedure TOpenLogRelaunchTests.TestRequestIsOneShot;
var
   exe:  string;
   args: TRelaunchArgs;
begin
   BeginTest('TestRequestIsOneShot');
   CheckFalse(TakeRelaunchRequest(exe, args), 'no request yet');
   RequestRelaunch('tr4w.exe', BuildRelaunchArguments([], 'b.db', 1));
   CheckTrue(TakeRelaunchRequest(exe, args), 'the request is there');
   CheckEquals('tr4w.exe', exe, 'its executable');
   CheckEquals('b.db|--wait-for-instance=1', Joined(args), 'its arguments');
   CheckFalse(TakeRelaunchRequest(exe, args), 'and it is taken once');
   CheckEquals('', exe, 'nothing to start the second time');
end;

(* THE ORDER IS THE RULE: Cancel before anything, the open contest before
  "new" (a new contest named like the running one is the running one), and a
  new contest before the file's kind (its log does not exist yet). *)
procedure TOpenLogRelaunchTests.TestTheActionRulesInOrder;
begin
   BeginTest('TestTheActionRulesInOrder');
   CheckTrue(OpenLogAction('', False, False, cfkTR4WDatabase) = olaNothing,
             'nothing chosen is Cancel');
   CheckTrue(OpenLogAction('', True, True, cfkMissing) = olaNothing,
             'nothing chosen is Cancel whatever else is said');
   CheckTrue(OpenLogAction('a.db', False, True, cfkTR4WDatabase) = olaAlreadyOpen,
             'the open contest is already open');
   CheckTrue(OpenLogAction('a.db', True, True, cfkMissing) = olaAlreadyOpen,
             'a new contest whose log is the open one is already open');
   CheckTrue(OpenLogAction('n.db', True, False, cfkMissing) = olaRelaunchNew,
             'a new contest relaunches although its log does not exist yet');
   CheckTrue(OpenLogAction('b.db', False, False, cfkTR4WDatabase) = olaRelaunch,
             'another TR4W log relaunches');
   CheckTrue(OpenLogAction('old.cfg', False, False, cfkTextConfig) = olaRelaunch,
             'a text .cfg relaunches: the dialog lists one as the migration path');
   CheckTrue(OpenLogAction('x.db', False, False, cfkForeignDatabase) = olaNotAContestLog,
             'a foreign database is refused before anything closes');
   CheckTrue(OpenLogAction('x.png', False, False, cfkUnrecognised) = olaNotAContestLog,
             'an unrecognised file is refused');
   CheckTrue(OpenLogAction('gone.db', False, False, cfkMissing) = olaNotAContestLog,
             'an existing contest that is missing is refused');
end;

(* EACH OF THE DIALOG'S THREE ANSWERS, AS THE MENU ARM RUNS IT: the file
  uNewContest says the answer means, then the plan for it. *)
procedure TOpenLogRelaunchTests.TestEachAnswerPlansItsRelaunch;
var
   args:   TRelaunchArgs;
   chosen: string;
begin
   BeginTest('TestEachAnswerPlansItsRelaunch');

   chosen := NewContestResultFile(nccOpenSelected, 'C:\L\b.db', 'C:\L\last.db', 'C:\L\new.db');
   CheckEquals('C:\L\b.db', chosen, 'an existing contest is the selected file');
   CheckTrue(PlanOpenLog(chosen, False, False, cfkTR4WDatabase, ['--lang', 'de'],
                         11, 'C:\S\h.txt', args) = olaRelaunch,
             'an existing contest relaunches');
   CheckEquals('C:\L\b.db|--lang|de|--wait-for-instance=11', Joined(args),
               'an existing contest carries no hand-off, even when one is named');

   chosen := NewContestResultFile(nccLatest, 'C:\L\b.db', 'C:\L\last.db', 'C:\L\new.db');
   CheckEquals('C:\L\last.db', chosen, 'Last Contest is the last contest');
   CheckTrue(PlanOpenLog(chosen, False, False, cfkTR4WDatabase, [], 11, '', args) =
             olaRelaunch, 'Last Contest relaunches');
   CheckEquals('C:\L\last.db|--wait-for-instance=11', Joined(args),
               'Last Contest restarts on it');

   chosen := NewContestResultFile(nccCreate, 'C:\L\b.db', 'C:\L\last.db', 'C:\L\new.db');
   CheckEquals('C:\L\new.db', chosen, 'a new contest is its new log');
   CheckTrue(PlanOpenLog(chosen, True, False, cfkMissing, ['--settings=s.json'],
                         11, 'C:\S\h.txt', args) = olaRelaunchNew,
             'a new contest relaunches with its choices');
   CheckEquals('C:\L\new.db|--settings=s.json|--new-contest-from=C:\S\h.txt|' +
               '--wait-for-instance=11', Joined(args),
               'a new contest names its hand-off, with the settings carried');

   CheckTrue(PlanOpenLog('C:\L\a.db', False, True, cfkTR4WDatabase, [], 11, '', args) =
             olaAlreadyOpen, 'the open contest plans nothing');
   CheckEquals(0, Length(args), 'and starts nothing');
end;

procedure TOpenLogRelaunchTests.TestCancelPlansNothing;
var
   args:      TRelaunchArgs;
   chosenExe: string;
begin
   BeginTest('TestCancelPlansNothing');
   CheckEquals('', NewContestResultFile(nccNone, 'C:\L\b.db', 'C:\L\last.db', 'C:\L\new.db'),
               'Cancel means no file, whatever the form holds');
   CheckTrue(PlanOpenLog('', False, False, cfkMissing, ['--lang', 'es'], 3, '', args) =
             olaNothing, 'Cancel is nothing to do');
   CheckEquals(0, Length(args), 'Cancel starts nothing');
   CheckFalse(TakeRelaunchRequest(chosenExe, args), 'and requests no relaunch');
end;

procedure TOpenLogRelaunchTests.TestTheHandOffSwitch;
var
   handOff: string;
begin
   BeginTest('TestTheHandOffSwitch');
   CheckTrue(NewContestHandOffRequested(
                BuildRelaunchArguments([], 'n.db', 5, 'C:\My Settings\h 5.txt'), handOff),
             'the child finds the hand-off the parent wrote');
   CheckEquals('C:\My Settings\h 5.txt', handOff, 'a path with spaces survives');
   CheckFalse(NewContestHandOffRequested(['n.db', '--wait-for-instance=5'], handOff),
              'no hand-off switch, no hand-off');
   CheckFalse(NewContestHandOffRequested(['--new-contest-from='], handOff),
              'an empty value is no hand-off');
   CheckEquals('n.db|--wait-for-instance=6',
               Joined(BuildRelaunchArguments(['old.db', '--new-contest-from=C:\h.txt'],
                                             'n.db', 6)),
               'an inherited hand-off switch is dropped -- it was for one start');
   CheckEquals(IncludeTrailingPathDelimiter('dir') + 'open-log-new-contest-77.txt',
               NewContestHandOffFileName('dir', 77),
               'the hand-off file is named for the parent');
end;

procedure TOpenLogRelaunchTests.TestTheHandOffFileRoundTrips;
var
   path: string;
begin
   BeginTest('TestTheHandOffFileRoundTrips');
   path := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w-handoff-test.txt';
   ClearNewContestChoices;
   SetNewContestMainCallsign('W4TA');
   QueueNewContestCommand('MY CALL', 'W4TA');
   QueueNewContestCommand('MY STATE', 'FL = x');
   QueueNewContestCommand('CATEGORY-POWER', '');
   QueueNewContestCommand('CONTEST', 'ARRL-FD');
   try
      CheckTrue(SaveNewContestChoices(path), 'the hand-off is written');
      ClearNewContestChoices;
      CheckFalse(HasNewContestChoices, 'the parent forgets it');

      CheckTrue(LoadNewContestChoices(path), 'the child reads it');
      CheckTrue(HasNewContestChoices, 'and it is queued');
      CheckEquals('W4TA', QueuedNewContestValue('MY CALL'), 'MY CALL');
      CheckEquals('FL = x', QueuedNewContestValue('MY STATE'),
                  'a value holding "=" comes back whole');
      CheckEquals('ARRL-FD', QueuedNewContestValue('CONTEST'), 'CONTEST');
   finally
      ClearNewContestChoices;
      SysUtils.DeleteFile(path);
   end;
end;

procedure TOpenLogRelaunchTests.TestABadHandOffFileQueuesNothing;
var
   path:  string;
   lines: TStringList;
begin
   BeginTest('TestABadHandOffFileQueuesNothing');
   path := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w-handoff-bad.txt';
   SysUtils.DeleteFile(path);
   QueueNewContestCommand('CONTEST', 'LEFTOVER');
   CheckFalse(LoadNewContestChoices(path), 'a missing file is not a hand-off');
   CheckFalse(HasNewContestChoices, 'and leaves nothing queued');

   lines := TStringList.Create;
   try
      lines.Add('CONTEST=CQ-WW-CW');
      lines.SaveToFile(RawByteString(path));
   finally
      lines.Free;
   end;
   try
      CheckFalse(LoadNewContestChoices(path), 'a file without the header is not ours');
      CheckFalse(HasNewContestChoices, 'and queues nothing');
   finally
      SysUtils.DeleteFile(path);
   end;
end;

procedure TOpenLogRelaunchTests.RunAllTests;
begin
   TestRefusal;
   TestSameFile;
   TestArgumentsPlain;
   TestArgumentsCarrySettingsAndLanguage;
   TestArgumentsDropWhatDoesNotCarry;
   TestWaitSwitchParse;
   TestTheChildReadsWhatTheParentWrote;
   TestExecutable;
   TestRequestIsOneShot;
   TestTheActionRulesInOrder;
   TestEachAnswerPlansItsRelaunch;
   TestCancelPlansNothing;
   TestTheHandOffSwitch;
   TestTheHandOffFileRoundTrips;
   TestABadHandOffFileQueuesNothing;
end;

end.
