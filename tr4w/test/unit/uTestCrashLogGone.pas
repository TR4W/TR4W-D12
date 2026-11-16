unit uTestCrashLogGone;

(* A CRASH AFTER THE LOG IS GONE (review M14).

  Interfaces is listed first in tr4w.lpr, so the LCL is torn down LAST: after
  Log4D's finalization has freed every logger, uCrashLog's cached one among
  them, while the RTL and LCL hooks are still installed. uCrashLog's own
  finalization (which runs before Log4D's) now calls MarkCrashLogGone, and from
  then on a report writes one line to tr4w-early.log instead of the logger.

  These drive that state by hand -- MarkCrashLogGone, a caught exception, an
  off-main-thread report -- and put it back with ReopenCrashLog, so the rest of
  the suite keeps its crash logging. What they cannot reach is the real
  shutdown order of a running program; that is the GUI suite's exit check. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCrashLogGoneTests = class(TTestCase)
   protected
      procedure TestAReportAfterTheLogIsGoneGoesToTheEarlyLog;
      procedure TestAnOffThreadReportAfterTheLogIsGoneIsDropped;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, uCrashLog, uAppPaths;

(* The last line of tr4w-early.log, or '' when there is none. *)
function LastEarlyLine: string;
var
   lines: TStringList;
   fn: string;
begin
   Result := '';
   fn := LogFilePath('tr4w-early.log');
   if not FileExists(fn) then
      begin
      Exit;
      end;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(fn);
      if lines.Count > 0 then
         begin
         Result := lines[lines.Count - 1];
         end;
   finally
      lines.Free;
   end;
end;

procedure TCrashLogGoneTests.TestAReportAfterTheLogIsGoneGoesToTheEarlyLog;
const
   PROBE = 'unit-test probe: a fault after the log closed';
var
   raised: boolean;
   line: string;
begin
   BeginTest('TestAReportAfterTheLogIsGoneGoesToTheEarlyLog');
   raised := False;
   MarkCrashLogGone;
   try
      try
         try
            raise Exception.Create(PROBE);
         except
            on E: Exception do
               begin
               LogCaughtException('CrashLogGoneTest', E);
               end;
         end;
      except
         raised := True;
      end;
      line := LastEarlyLine;
   finally
      ReopenCrashLog;
   end;

   CheckFalse(raised, 'reporting after the log is gone raises nothing');
   CheckTrue(Pos(PROBE, line) > 0,
             'the report is the last line of tr4w-early.log: "' + line + '"');
   CheckTrue(Pos('after the log closed', line) > 0,
             'and says the log had closed');
end;

procedure TCrashLogGoneTests.TestAnOffThreadReportAfterTheLogIsGoneIsDropped;
var
   before: LongInt;
begin
   BeginTest('TestAnOffThreadReportAfterTheLogIsGoneIsDropped');
   before := OffMainThreadReportCount;
   MarkCrashLogGone;
   try
      ReportOffMainThread('CrashLogGoneTest', nil);
   finally
      ReopenCrashLog;
   end;
   CheckEquals(before, OffMainThreadReportCount,
               'dropped before the count, the lock and the logger');
end;

procedure TCrashLogGoneTests.RunAllTests;
begin
   TestAReportAfterTheLogIsGoneGoesToTheEarlyLog;
   TestAnOffThreadReportAfterTheLogIsGoneIsDropped;
end;

end.
