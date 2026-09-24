unit uTestTelnetTrace;

(* THE DX CLUSTER TRACE RING.

  WHY THIS EXISTS AS A UNIT TEST AND THE CONSOLE CAP BESIDE IT DOES NOT: the
  cap lives in uTelnetForm, which pulls in MainUnit and cannot link into the
  test binary at all, so it can only be reviewed. The ring was deliberately
  put in a leaf with no LCL and no logger precisely so this file could exist.

  EVERY CASE HERE IS SOMETHING A WRAPPING BUFFER GETS WRONG. Index arithmetic
  that is right before the first wrap and off by the ring size after it is the
  classic one, and it presents as a crash report full of the WRONG lines --
  which is worse than no report, because it is believed.
*)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTelnetTraceTests = class(TTestCase)
   protected
      procedure TestEmptyRingHoldsNothing;
      procedure TestOrderIsOldestFirst;
      procedure TestFillingExactlyToCapacityKeepsEverything;
      procedure TestOnePastCapacityDropsTheOldest;
      procedure TestWrappingSeveralTimesKeepsTheLastN;
      procedure TestTotalCountsWhatWasDropped;
      procedure TestOutOfRangeIsEmptyNotAnError;
      procedure TestResetEmptiesIt;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uTelnetTrace;

{ Offer aCount lines named '1'..'aCount', starting from an empty ring. }
procedure FillWithNumbers(const aCount: integer);
var
   i: integer;
begin
   TelnetTraceReset;
   for i := 1 to aCount do
      begin
      TelnetTraceAdd(IntToStr(i));
      end;
end;

procedure TTelnetTraceTests.TestEmptyRingHoldsNothing;
begin
   BeginTest('TestEmptyRingHoldsNothing');
   TelnetTraceReset;
   CheckEquals(0, TelnetTraceCount, 'a fresh ring holds nothing');
   CheckEquals(0, TelnetTraceTotal, 'and has seen nothing');
   CheckEquals('', TelnetTraceLine(0), 'reading it is empty, not a fault');
end;

procedure TTelnetTraceTests.TestOrderIsOldestFirst;
begin
   BeginTest('TestOrderIsOldestFirst');
   FillWithNumbers(3);
   CheckEquals(3, TelnetTraceCount, 'three lines held');
   CheckEquals('1', TelnetTraceLine(0), 'index 0 is the OLDEST');
   CheckEquals('2', TelnetTraceLine(1), 'then the next');
   CheckEquals('3', TelnetTraceLine(2), 'and the last is the newest');
end;

procedure TTelnetTraceTests.TestFillingExactlyToCapacityKeepsEverything;
begin
   (* THE BOUNDARY THAT LOOKS RIGHT EITHER WAY. At exactly capacity the write
     pointer has just wrapped to 0 while nothing has been overwritten, so an
     implementation that confuses "wrapped" with "lost something" reports the
     ring rotated by one and every line is wrong by one position. *)
   BeginTest('TestFillingExactlyToCapacityKeepsEverything');
   FillWithNumbers(TELNET_TRACE_LINES);
   CheckEquals(TELNET_TRACE_LINES, TelnetTraceCount, 'full, and nothing lost');
   CheckEquals('1', TelnetTraceLine(0), 'the first line is still the oldest');
   CheckEquals(IntToStr(TELNET_TRACE_LINES),
               TelnetTraceLine(TELNET_TRACE_LINES - 1), 'and the last is last');
end;

procedure TTelnetTraceTests.TestOnePastCapacityDropsTheOldest;
begin
   BeginTest('TestOnePastCapacityDropsTheOldest');
   FillWithNumbers(TELNET_TRACE_LINES + 1);
   CheckEquals(TELNET_TRACE_LINES, TelnetTraceCount, 'it never grows');
   CheckEquals('2', TelnetTraceLine(0), 'line 1 is the one that went');
   CheckEquals(IntToStr(TELNET_TRACE_LINES + 1),
               TelnetTraceLine(TELNET_TRACE_LINES - 1), 'the newest is newest');
end;

procedure TTelnetTraceTests.TestWrappingSeveralTimesKeepsTheLastN;
var
   offered, i: integer;
begin
   (* A CONTEST SESSION, SCALED DOWN. The ring is asked to hold a fraction of
     what passes through it, which is the only state it is ever really in. *)
   BeginTest('TestWrappingSeveralTimesKeepsTheLastN');
   offered := (TELNET_TRACE_LINES * 3) + 7;
   FillWithNumbers(offered);

   CheckEquals(TELNET_TRACE_LINES, TelnetTraceCount, 'still exactly full');

   (* EVERY position checked, not just the ends: an off-by-one in the modulo
     shows at one end and an inverted subtraction shows in the middle. *)
   for i := 0 to TELNET_TRACE_LINES - 1 do
      begin
      CheckEquals(IntToStr(offered - TELNET_TRACE_LINES + 1 + i),
                  TelnetTraceLine(i),
                  'position ' + IntToStr(i) + ' after three wraps');
      end;
end;

procedure TTelnetTraceTests.TestTotalCountsWhatWasDropped;
begin
   (* THE DUMP SAYS "last N of M", and M is what tells a reader the ring
     wrapped. If the total stopped at the capacity, the report would claim
     nothing had been lost on every long session. *)
   BeginTest('TestTotalCountsWhatWasDropped');
   FillWithNumbers(TELNET_TRACE_LINES + 50);
   CheckEquals(TELNET_TRACE_LINES, TelnetTraceCount, 'held');
   CheckEquals(TELNET_TRACE_LINES + 50, TelnetTraceTotal, 'offered');
end;

procedure TTelnetTraceTests.TestOutOfRangeIsEmptyNotAnError;
begin
   (* THE ONE CALLER READS THIS WHILE THE PROGRAM IS DYING, so a bad index
     must not raise -- a diagnostic that faults inside the fault handler
     destroys the report it exists to produce. *)
   BeginTest('TestOutOfRangeIsEmptyNotAnError');
   FillWithNumbers(5);
   CheckEquals('', TelnetTraceLine(-1), 'below the bottom');
   CheckEquals('', TelnetTraceLine(5), 'one past the top');
   CheckEquals('', TelnetTraceLine(TELNET_TRACE_LINES * 10), 'far past it');
end;

procedure TTelnetTraceTests.TestResetEmptiesIt;
begin
   BeginTest('TestResetEmptiesIt');
   FillWithNumbers(TELNET_TRACE_LINES + 20);
   TelnetTraceReset;
   CheckEquals(0, TelnetTraceCount, 'nothing held');
   CheckEquals(0, TelnetTraceTotal, 'and the total starts again');

   (* AND IT IS USABLE AFTERWARDS -- a reset that left the write pointer part
     way round would put the next line in the middle of an empty ring. *)
   TelnetTraceAdd('after');
   CheckEquals(1, TelnetTraceCount, 'one line');
   CheckEquals('after', TelnetTraceLine(0), 'and it reads back');
end;

procedure TTelnetTraceTests.RunAllTests;
begin
   TestEmptyRingHoldsNothing;
   TestOrderIsOldestFirst;
   TestFillingExactlyToCapacityKeepsEverything;
   TestOnePastCapacityDropsTheOldest;
   TestWrappingSeveralTimesKeepsTheLastN;
   TestTotalCountsWhatWasDropped;
   TestOutOfRangeIsEmptyNotAnError;
   TestResetEmptiesIt;

   (* LEFT EMPTY.  Suites share a process and the next thing to read this ring
     would otherwise see three hundred lines of test numbers. *)
   TelnetTraceReset;
end;

end.
