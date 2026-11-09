unit uTestContestTimeLeft;

(* THE TIME LEFT IN A CONTEST -- issue 243, uContestTimeLeft.

  Every boundary is pinned: before the start, exactly at it, during, one
  second before the end, exactly at it, after it, and a window that is not
  known. The window used is ARRL Sweepstakes CW's shape -- 2100Z Saturday to
  0259Z Monday, 30 hours on the calendar -- so the hours are pinned NOT to
  wrap at 24. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestTimeLeftTests = class(TTestCase)
   protected
      procedure Test_ANoWindowIsItsOwnPhaseAndShowsNothingLeft;
      procedure Test_BeforeTheStartCountsDownToTheStart;
      procedure Test_AtTheStartTheContestIsRunning;
      procedure Test_DuringTheContestCountsDownToTheEnd;
      procedure Test_ThePartMinuteLeftRoundsUp;
      procedure Test_AtTheEndTheContestHasEnded;
      procedure Test_AfterTheEndNothingIsLeft;
      procedure Test_HoursDoNotWrapAtADay;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, DateUtils, uContestTimeLeft;

(* 2026-11-07 2100Z to 2026-11-09 0300Z: 30 hours. *)
function SSStart: TDateTime;
begin
   Result := EncodeDateTime(2026, 11, 7, 21, 0, 0, 0);
end;

function SSEnd: TDateTime;
begin
   Result := EncodeDateTime(2026, 11, 9, 3, 0, 0, 0);
end;

procedure TContestTimeLeftTests.Test_ANoWindowIsItsOwnPhaseAndShowsNothingLeft;
var
   now_: TDateTime;
begin
   BeginTest('ANoWindowIsItsOwnPhaseAndShowsNothingLeft');
   now_ := EncodeDateTime(2026, 11, 8, 12, 0, 0, 0);

   Check(ContestPhaseAt(now_, 0, 0) = cpNoWindow, 'no start and no end');
   Check(ContestPhaseAt(now_, 0, SSEnd) = cpNoWindow, 'no start');
   Check(ContestPhaseAt(now_, SSStart, 0) = cpNoWindow, 'no end');
   Check(ContestPhaseAt(now_, SSEnd, SSStart) = cpNoWindow, 'an end before the start');
   Check(ContestPhaseAt(now_, SSStart, SSStart) = cpNoWindow, 'an end equal to the start');
   CheckEquals(0, ContestMinutesLeft(now_, 0, 0), 'no window: nothing left');
end;

procedure TContestTimeLeftTests.Test_BeforeTheStartCountsDownToTheStart;
var
   now_: TDateTime;
begin
   BeginTest('BeforeTheStartCountsDownToTheStart');
   now_ := EncodeDateTime(2026, 11, 7, 19, 30, 0, 0);

   Check(ContestPhaseAt(now_, SSStart, SSEnd) = cpNotStarted, 'before 2100Z: not started');
   CheckEquals(90, ContestMinutesLeft(now_, SSStart, SSEnd), '1 h 30 min to the start');
   CheckEquals('1:30', FormatHoursMinutes(ContestMinutesLeft(now_, SSStart, SSEnd)),
               'formatted');
end;

procedure TContestTimeLeftTests.Test_AtTheStartTheContestIsRunning;
begin
   BeginTest('AtTheStartTheContestIsRunning');
   Check(ContestPhaseAt(SSStart, SSStart, SSEnd) = cpRunning, 'the start instant is inside');
   CheckEquals(30 * 60, ContestMinutesLeft(SSStart, SSStart, SSEnd),
               'at the start, the whole 30 hours are left');
end;

procedure TContestTimeLeftTests.Test_DuringTheContestCountsDownToTheEnd;
var
   now_: TDateTime;
begin
   BeginTest('DuringTheContestCountsDownToTheEnd');
   now_ := EncodeDateTime(2026, 11, 8, 23, 15, 0, 0);

   Check(ContestPhaseAt(now_, SSStart, SSEnd) = cpRunning, 'Sunday 2315Z: running');
   CheckEquals(3 * 60 + 45, ContestMinutesLeft(now_, SSStart, SSEnd), '3 h 45 min left');
   CheckEquals('3:45', FormatHoursMinutes(ContestMinutesLeft(now_, SSStart, SSEnd)),
               'formatted');
end;

procedure TContestTimeLeftTests.Test_ThePartMinuteLeftRoundsUp;
var
   now_: TDateTime;
begin
   BeginTest('ThePartMinuteLeftRoundsUp');
   now_ := IncSecond(SSEnd, -1);
   Check(ContestPhaseAt(now_, SSStart, SSEnd) = cpRunning, 'one second before the end: running');
   CheckEquals(1, ContestMinutesLeft(now_, SSStart, SSEnd),
               'one second left reads one minute, never 0:00 while running');

   now_ := IncMilliSecond(SSEnd, -400);
   Check(ContestPhaseAt(now_, SSStart, SSEnd) = cpRunning, '0.4 s before the end: running');
   CheckEquals(1, ContestMinutesLeft(now_, SSStart, SSEnd),
               'under half a second left still reads one minute');

   now_ := IncSecond(SSEnd, -61);
   CheckEquals(2, ContestMinutesLeft(now_, SSStart, SSEnd), '61 seconds left reads two minutes');
end;

procedure TContestTimeLeftTests.Test_AtTheEndTheContestHasEnded;
begin
   BeginTest('AtTheEndTheContestHasEnded');
   Check(ContestPhaseAt(SSEnd, SSStart, SSEnd) = cpEnded, 'the end instant is outside');
   CheckEquals(0, ContestMinutesLeft(SSEnd, SSStart, SSEnd), 'nothing left at the end');
end;

procedure TContestTimeLeftTests.Test_AfterTheEndNothingIsLeft;
var
   now_: TDateTime;
begin
   BeginTest('AfterTheEndNothingIsLeft');
   now_ := EncodeDateTime(2026, 11, 9, 4, 0, 0, 0);
   Check(ContestPhaseAt(now_, SSStart, SSEnd) = cpEnded, 'an hour after: ended');
   CheckEquals(0, ContestMinutesLeft(now_, SSStart, SSEnd), 'nothing left after the end');
   CheckEquals('0:00', FormatHoursMinutes(-5), 'a negative count formats as 0:00');
end;

procedure TContestTimeLeftTests.Test_HoursDoNotWrapAtADay;
var
   now_: TDateTime;
begin
   BeginTest('HoursDoNotWrapAtADay');
   now_ := EncodeDateTime(2026, 11, 7, 21, 55, 0, 0);
   CheckEquals(29 * 60 + 5, ContestMinutesLeft(now_, SSStart, SSEnd), '29 h 05 min left');
   CheckEquals('29:05', FormatHoursMinutes(ContestMinutesLeft(now_, SSStart, SSEnd)),
               'the hours run past 24, they do not wrap');
   CheckEquals('0:07', FormatHoursMinutes(7), 'minutes are two digits');
end;

procedure TContestTimeLeftTests.RunAllTests;
begin
   Test_ANoWindowIsItsOwnPhaseAndShowsNothingLeft;
   Test_BeforeTheStartCountsDownToTheStart;
   Test_AtTheStartTheContestIsRunning;
   Test_DuringTheContestCountsDownToTheEnd;
   Test_ThePartMinuteLeftRoundsUp;
   Test_AtTheEndTheContestHasEnded;
   Test_AfterTheEndNothingIsLeft;
   Test_HoursDoNotWrapAtADay;
end;

end.
