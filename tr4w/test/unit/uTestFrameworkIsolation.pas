(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* THE FRAMEWORK'S OWN SELF-TEST (issue 140): an exception that escapes one
  suite is a failure of that suite, and the next suite still runs.

  The fixtures here are NOT registered -- a deliberate crash in the real list
  would fail the run. They are run through RunSuite with Quiet set, so the
  planted exception does not put a CRASHED line in the log either. *)
unit uTestFrameworkIsolation;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TFrameworkIsolationTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ACrashIsOneFailedTest;
      procedure Test_ACrashStillRunsTheTearDown;
      procedure Test_TheSuiteAfterACrashStillRuns;
      procedure Test_ACrashCountsAgainstTheRunTotal;
   end;

implementation

uses
   SysUtils;

type
   (* Raises from inside its first test, as any real test might. *)
   TCrashingFixture = class(TTestCase)
   public
      TearDownCalls: Integer;
      procedure RunAllTests; override;
   protected
      procedure TearDown; override;
   end;

   (* Passes one check; stands for "a suite later in the list". *)
   TPassingFixture = class(TTestCase)
   public
      procedure RunAllTests; override;
   end;

procedure TCrashingFixture.RunAllTests;
begin
   BeginTest('Test_Raises');
   raise Exception.Create('planted by the framework self-test');
end;

procedure TCrashingFixture.TearDown;
begin
   Inc(TearDownCalls);
end;

procedure TPassingFixture.RunAllTests;
begin
   BeginTest('Test_Passes');
   Check(True);
end;

procedure TFrameworkIsolationTests.Test_ACrashIsOneFailedTest;
var
   Crashing: TCrashingFixture;
   Failed:   Integer;
   Passed:   Integer;
begin
   BeginTest('Test_ACrashIsOneFailedTest');
   Crashing := TCrashingFixture.Create('Crashing');
   try
      RunSuite(Crashing, True);
      Failed := Crashing.FailCount;
      Passed := Crashing.PassCount;
   finally
      Crashing.Free;
   end;
   CheckEquals(10, Failed * 10 + Passed,
      'one failure and no pass (failures x 10 + passes = 10)');
end;

procedure TFrameworkIsolationTests.Test_ACrashStillRunsTheTearDown;
var
   Crashing: TCrashingFixture;
   Calls:    Integer;
begin
   BeginTest('Test_ACrashStillRunsTheTearDown');
   Crashing := TCrashingFixture.Create('Crashing');
   try
      RunSuite(Crashing, True);
      Calls := Crashing.TearDownCalls;
   finally
      Crashing.Free;
   end;
   CheckEquals(1, Calls, 'TearDown runs once for the test that raised');
end;

procedure TFrameworkIsolationTests.Test_TheSuiteAfterACrashStillRuns;
var
   Crashing: TCrashingFixture;
   After:    TPassingFixture;
   Passed:   Integer;
begin
   BeginTest('Test_TheSuiteAfterACrashStillRuns');
   Crashing := TCrashingFixture.Create('Crashing');
   After    := TPassingFixture.Create('After');
   try
      RunSuite(Crashing, True);
      RunSuite(After, True);
      Passed := After.PassCount;
   finally
      After.Free;
      Crashing.Free;
   end;
   CheckEquals(1, Passed, 'the suite run after the crash recorded its pass');
end;

procedure TFrameworkIsolationTests.Test_ACrashCountsAgainstTheRunTotal;
var
   Crashing: TCrashingFixture;
   After:    TPassingFixture;
   Failed:   Integer;
begin
   BeginTest('Test_ACrashCountsAgainstTheRunTotal');
   Crashing := TCrashingFixture.Create('Crashing');
   After    := TPassingFixture.Create('After');
   try
      RunSuite(Crashing, True);
      RunSuite(After, True);
      (* RunAllSuites sums FailCount and returns False when it is not zero, so
        a non-zero sum here is the non-zero exit code. *)
      Failed := Crashing.FailCount + After.FailCount;
   finally
      After.Free;
      Crashing.Free;
   end;
   CheckTrue(Failed > 0, 'the crash must count as a failure');
end;

procedure TFrameworkIsolationTests.RunAllTests;
begin
   Test_ACrashIsOneFailedTest;
   Test_ACrashStillRunsTheTearDown;
   Test_TheSuiteAfterACrashStillRuns;
   Test_ACrashCountsAgainstTheRunTotal;
end;

end.
