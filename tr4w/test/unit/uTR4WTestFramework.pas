unit uTR4WTestFramework;
{$I ..\..\src\tr4w.inc}

{
  Minimal unit test framework for TR4W.
  Delphi 7 compatible — no external dependencies.

  DUnit/DUnitX migration path (Phase 4 — Delphi 12):
    1. Replace this unit's uses clause with TestFramework (DUnit)
       or DUnitX.TestFramework.
    2. Add [TestFixture] attribute above each TTestCase subclass.
    3. Add [Test] attribute above each published test method.
    4. Remove the explicit RunAllTests override and test method calls.
    5. Replace RegisterSuite/RunAllSuites with DUnitX runner call.
    The test classes and all Check* logic need no changes.
}

interface

uses
   SysUtils;

type
   ETestFailed = class(Exception);

   // Base class for a group of related tests.
   // Subclasses override RunAllTests to call each test method in turn.
   TTestCase = class
   private
      FName      : string;
      FPassCount : Integer;
      FFailCount : Integer;

      procedure RecordPass(const TestMethod: string);
      procedure RecordFail(const TestMethod, Msg: string);

   protected
      // Current test method name — set by BeginTest before each call.
      FCurrentMethod: string;

      procedure SetUp; virtual;
      procedure TearDown; virtual;

      // Assertion helpers — same names as DUnit/DUnitX.
      procedure Check(Condition: Boolean; const Msg: string = '');
      procedure CheckTrue(Condition: Boolean; const Msg: string = '');
      procedure CheckFalse(Condition: Boolean; const Msg: string = '');
      procedure CheckEquals(Expected, Actual: Integer;       const Msg: string = ''); overload;
      procedure CheckEquals(const Expected, Actual: string;  const Msg: string = ''); overload;

      // Call this at the top of each test method.
      procedure BeginTest(const MethodName: string);

   public
      constructor Create(const AName: string); virtual;

      // Override to call each TestXxx method in sequence.
      procedure RunAllTests; virtual; abstract;

      property Name      : string  read FName;
      property PassCount : Integer read FPassCount;
      property FailCount : Integer read FFailCount;
   end;

// ---------------------------------------------------------------------------
// Suite registry — collect suites, then run them all.
// ---------------------------------------------------------------------------

procedure RegisterSuite(Suite: TTestCase);
function  RunAllSuites: Boolean;  // Returns True if every test passes.

(* RUNS ONE SUITE, AND AN EXCEPTION THAT ESCAPES IT IS A FAILURE OF THAT SUITE,
   NOT THE END OF THE RUN (issue 140). The exception is recorded as one failed
   test (suite, the test that was running, exception class and message), a
   'CRASHED:' line is written for the Unix gate, and the caller goes on to the
   next suite. Granularity is the suite: RunAllTests calls its methods in turn,
   so the tests AFTER the one that raised, in that same suite, do not run --
   the CRASHED line says so. Quiet suppresses the output only; it exists for
   the framework's own self-test, whose deliberate crash must not look like a
   real one in the log. *)
procedure RunSuite(Suite: TTestCase; Quiet: Boolean = False);

(* A temp file name no OTHER test process can be handed. FPC's GetTempFileName
   only picks the first <prefix>NNNNN.tmp that does not exist yet, so two suites
   running at once both got ...00000.tmp (issue 212). The process id in the
   prefix makes the name per-process. The file is not created. *)
function  UniqueTempFileName(const aPrefix: string): string;

implementation

var
   { A DYNAMIC ARRAY, because the fixed one SILENTLY DISCARDED suites.

     This was `array[0..63]`, and RegisterSuite's guard read

        if GSuiteCount < Length(GSuites) then ...   -- and NO else

     so the 65th suite registered was dropped with no error, no warning and no
     change to the exit code -- the run simply reported a smaller number and
     still said "All tests passed".  A test suite that quietly stops running is
     the worst possible failure mode for a regression net: it is trusted exactly
     as much as before while covering less, and the headline count is the only
     evidence, which nobody reads as an absolute.

     Found 2026-08-25 when adding a suite made the total FALL by 276. }
   GSuites     : array of TTestCase;
   GSuiteCount : Integer = 0;
   (* True only while RunSuite is run Quiet; read by RecordPass/RecordFail. *)
   GQuiet      : Boolean = False;

// ---------------------------------------------------------------------------
// TTestCase
// ---------------------------------------------------------------------------

constructor TTestCase.Create(const AName: string);
begin
   inherited Create;
   FName      := AName;
   FPassCount := 0;
   FFailCount := 0;
end;

procedure TTestCase.SetUp;
begin
   // Default: nothing
end;

procedure TTestCase.TearDown;
begin
   // Default: nothing
end;

procedure TTestCase.BeginTest(const MethodName: string);
begin
   FCurrentMethod := MethodName;
   SetUp;
end;

procedure TTestCase.RecordPass(const TestMethod: string);
begin
   Inc(FPassCount);
   if not GQuiet then
      begin
      WriteLn('[PASS] ', FName, ': ', TestMethod);
      end;
end;

procedure TTestCase.RecordFail(const TestMethod, Msg: string);
begin
   Inc(FFailCount);
   if not GQuiet then
      begin
      WriteLn('[FAIL] ', FName, ': ', TestMethod, ' — ', Msg);
      end;
end;

procedure TTestCase.Check(Condition: Boolean; const Msg: string);
begin
   if Condition then
      RecordPass(FCurrentMethod)
   else
      begin
      if Msg <> '' then
         RecordFail(FCurrentMethod, Msg)
      else
         RecordFail(FCurrentMethod, 'Condition was False');
      end;
   TearDown;
end;

procedure TTestCase.CheckTrue(Condition: Boolean; const Msg: string);
begin
   Check(Condition, Msg);
end;

procedure TTestCase.CheckFalse(Condition: Boolean; const Msg: string);
begin
   Check(not Condition, Msg);
end;

procedure TTestCase.CheckEquals(Expected, Actual: Integer; const Msg: string);
var
   M: string;
begin
   if Expected = Actual then
      RecordPass(FCurrentMethod)
   else
      begin
      M := Format('Expected %d but got %d', [Expected, Actual]);
      if Msg <> '' then M := Msg + ' (' + M + ')';
      RecordFail(FCurrentMethod, M);
      end;
   TearDown;
end;

procedure TTestCase.CheckEquals(const Expected, Actual: string; const Msg: string);
var
   M: string;
begin
   if Expected = Actual then
      RecordPass(FCurrentMethod)
   else
      begin
      M := Format('Expected "%s" but got "%s"', [Expected, Actual]);
      if Msg <> '' then M := Msg + ' (' + M + ')';
      RecordFail(FCurrentMethod, M);
      end;
   TearDown;
end;

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

function UniqueTempFileName(const aPrefix: string): string;
begin
   Result := GetTempFileName(GetTempDir, aPrefix + IntToStr(GetProcessID) + '_');
end;

procedure RegisterSuite(Suite: TTestCase);
begin
   { Grows to fit.  There is deliberately no capacity to exceed and therefore no
     silent-drop branch to get wrong again. }
   SetLength(GSuites, GSuiteCount + 1);
   GSuites[GSuiteCount] := Suite;
   Inc(GSuiteCount);
end;

procedure RunSuite(Suite: TTestCase; Quiet: Boolean);
var
   RunningTest : string;
   WasQuiet    : Boolean;
begin
   WasQuiet := GQuiet;
   GQuiet   := Quiet;
   try
      try
         Suite.RunAllTests;
      except
         on E: Exception do
            begin
            RunningTest := Suite.FCurrentMethod;
            Suite.RecordFail(RunningTest,
               'CRASHED: ' + E.ClassName + ': ' + E.Message);
            if not Quiet then
               begin
               WriteLn('CRASHED: ', Suite.Name, ': ', RunningTest, ' raised ',
                  E.ClassName, ': ', E.Message);
               WriteLn('  The tests after it in this suite did not run.');
               end;
            (* The raising test never reached its own TearDown. It is run here,
               and an exception from it is dropped: the crash is already
               recorded and a second report would only hide the first. *)
            try
               Suite.TearDown;
            except
               on Exception do
                  begin
                  end;
            end;
            end;
      end;
   finally
      GQuiet := WasQuiet;
   end;
end;

(* PER-SUITE WALL-CLOCK TIME, printed ranked before the PASSED line. It measures
   and reports only: nothing here touches a suite's result, and no line of it
   contains 'PASSED:' or '[FAIL]', the two strings Build-Tests.ps1 and the Unix
   gate search for. GetTickCount64 is SysUtils' monotonic millisecond clock on
   Windows, Linux and macOS (granularity 10-16 ms on Windows, so a suite that
   runs faster than that reads 0.00). *)
const
   TIMING_ROWS = 25;

type
   TSuiteTiming = record
      Name    : string;
      Millis  : QWord;
      Asserts : Integer;
   end;

procedure PrintTimingTable(var Timings: array of TSuiteTiming);
var
   i, j      : Integer;
   Swap      : TSuiteTiming;
   TotalMs   : QWord;
   TotalAsrt : Integer;
   Shown     : Integer;
   Share     : Double;
begin
   TotalMs   := 0;
   TotalAsrt := 0;
   for i := 0 to High(Timings) do
      begin
      Inc(TotalMs, Timings[i].Millis);
      Inc(TotalAsrt, Timings[i].Asserts);
      end;

   (* Insertion sort, slowest first: a few hundred rows, run once. *)
   for i := 1 to High(Timings) do
      begin
      Swap := Timings[i];
      j := i - 1;
      while (j >= 0) and (Timings[j].Millis < Swap.Millis) do
         begin
         Timings[j + 1] := Timings[j];
         Dec(j);
         end;
      Timings[j + 1] := Swap;
      end;

   Shown := Length(Timings);
   if Shown > TIMING_ROWS then
      begin
      Shown := TIMING_ROWS;
      end;

   WriteLn('TIMING BY SUITE (wall clock, slowest ', Shown, ' of ', Length(Timings), '):');
   WriteLn('TIMING   seconds   share  assertions  suite');
   for i := 0 to Shown - 1 do
      begin
      if TotalMs > 0 then
         begin
         Share := 100.0 * Timings[i].Millis / TotalMs;
         end
      else
         begin
         Share := 0.0;
         end;
      WriteLn(Format('TIMING %8.2f  %5.1f%%  %10d  %s',
         [Timings[i].Millis / 1000.0, Share, Timings[i].Asserts, Timings[i].Name]));
      end;
   WriteLn(Format('TIMING TOTAL %.2f s over %d suites, %d assertions',
      [TotalMs / 1000.0, Length(Timings), TotalAsrt]));
end;

function RunAllSuites: Boolean;
var
   i          : Integer;
   totalPass  : Integer;
   totalFail  : Integer;
   suite      : TTestCase;
   timings    : array of TSuiteTiming;
   startMs    : QWord;
begin
   totalPass := 0;
   totalFail := 0;
   SetLength(timings, GSuiteCount);

   for i := 0 to GSuiteCount - 1 do
      begin
      suite := GSuites[i];
      WriteLn('--- ', suite.Name, ' ---');
      startMs := GetTickCount64;
      RunSuite(suite);
      timings[i].Millis  := GetTickCount64 - startMs;
      timings[i].Name    := suite.Name;
      timings[i].Asserts := suite.PassCount + suite.FailCount;
      Inc(totalPass, suite.PassCount);
      Inc(totalFail, suite.FailCount);
      suite.Free;
      end;

   WriteLn('');
   PrintTimingTable(timings);
   WriteLn('');
   { The suite count is REPORTED, so a suite that stops being registered is
     visible in the build log instead of hiding inside a total that only ever
     goes up. }
   WriteLn('SUITES: ', GSuiteCount);
   WriteLn('PASSED: ', totalPass, '  FAILED: ', totalFail);
   Result := (totalFail = 0);
end;

end.
