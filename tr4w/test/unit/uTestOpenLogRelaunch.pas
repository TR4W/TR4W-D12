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
      procedure TestRequestIsOneShot;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
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

procedure TOpenLogRelaunchTests.RunAllTests;
begin
   TestRefusal;
   TestSameFile;
   TestArgumentsPlain;
   TestArgumentsCarrySettingsAndLanguage;
   TestArgumentsDropWhatDoesNotCarry;
   TestWaitSwitchParse;
   TestTheChildReadsWhatTheParentWrote;
   TestRequestIsOneShot;
end;

end.
