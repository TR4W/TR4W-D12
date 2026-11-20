(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

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

(* A CONTEST'S SCHEDULE -- Q99 step A, 2026-11-16.

  Four layers, each against an explicit UTC "now" (nothing here reads a
  clock):
  - the GRAMMAR (uContestSchedule.TryParseContestSchedule): every clause
    shape the CSV uses, the monthly and daily forms, and the bad inputs, each
    diagnostic naming its clause;
  - the RESOLVER: before a period, inside it, its exact [start, end)
    boundaries, a QSO party's overnight gap, after the last period, an
    exhausted date list, leap and year rollover, sessions on one UTC day;
  - every VERIFIED class's known dates, read from the class's RETURNED
    string -- never a copy in this file -- and the ordering of real contests
    through uContestDates.SortContestDates;
  - the REGISTRY: every contest states its schedule on its own class, the
    string parses, and the contests still pending are a visible list that
    only shrinks (SCHEDULE_NOT_YET_STATED). And every class-form example in
    docs/CONTEST_SCHEDULES_README.md parses, so the doc cannot drift. *)
unit uTestContestSchedule;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestScheduleTests = class(TTestCase)
   private
      procedure Test_ParsesEveryClauseShape;
      procedure Test_RefusesBadInputNamingTheClause;
      procedure Test_ResolverBeforeInsideAndAfter;
      procedure Test_ResolverOverMultiplePeriods;
      procedure Test_ResolverRepeatingForms;
      procedure Test_ResolverExhaustedListLeapAndRollover;
      procedure Test_VerifiedClassesKnownDates;
      procedure Test_TheWeekdayBeforeAnAnchor;
      procedure Test_ARRLClassesAgreeWithTheARRLCalendar;
      procedure Test_OrderingOfRealContests;
      procedure Test_EveryContestStatesItsSchedule;
      procedure Test_ReadmeExamplesParse;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes,
   SysUtils,
   DateUtils,
   VC,
   uContestDates,
   uContestSchedule,
   uContestBase,
   uContestRegistry,
   uTestRegisteredContests;

const
   (* THE SCHEDULE RATCHET -- Q99, 2026-11-16. The contests whose class does
      not state a schedule yet, by id, LITERALLY. Test_EveryContestStatesItsSchedule
      fails a contest outside this list that states nothing (so a NEW contest
      states its own from its first commit -- 'unscheduled' when it has no
      calendar) AND a contest inside it that now states one (a stale entry:
      take it out in the commit that states it). Generated once from the
      contests docs/CONTEST_SCHEDULES.csv had no verified or candidate row
      for (pending and hold rows); edited by hand from then on, only ever
      DOWN. *)
   SCHEDULE_NOT_YET_STATED: array[0..31] of string = (
      'AP-SPRINT', 'ARKTIKA-SPRING', 'AS-CHAMP', 'BATAVIA-FT8',
      'BLACK SEA CUP', 'CIS', 'EU-SPRINT-SPRING-CW', 'EU-SPRINT-SPRING-SSB',
      'EUROPEAN VHF', 'INTERNET SPRINT', 'JA LONG PREFECT', 'KVP',
      'MONGOLIAN DX', 'OZCHR', 'OZCHR-TEAMS', 'OZHCR-VHF',
      'R4W-CHAMP', 'R9W-UW9WK-MEMORIAL', 'RADIO-MEMORY', 'RADIO-YOC',
      'RF-CHAMP-CW', 'RF-CHAMP-SSB', 'RF-VHF-FD', 'SOUTH AMERICAN WW',
      'SRR-JR', 'TEN TEN', 'TOEC', 'UCG',
      'UKEI', 'WRTC', 'WWL', 'XMAS'
      );

type
   (* THE PROTECTED GETTER, REACHED THE WAY A DESCENDANT REACHES IT. *)
   TScheduleCracker = class(TContestBase);
   TScheduleGetter = function: string of object;

function ScheduleCode(aObj: TContestBase): CodePointer;
var
   m: TScheduleGetter;
begin
   m := TScheduleCracker(aObj).GetSchedule;
   Result := TMethod(m).Code;
end;

function IdIsIn(const aId: string; const aSet: array of string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(aSet) to High(aSet) do
      begin
      if aSet[i] = aId then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function Stamp(const aValue: TDateTime): string;
begin
   Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', aValue);
end;

function At(aYear, aMonth, aDay, aHour, aMinute: word): TDateTime;
begin
   Result := EncodeDateTime(aYear, aMonth, aDay, aHour, aMinute, 0, 0);
end;

(* THE CLASS'S OWN STRING, by id -- by-id contests included. *)
function ScheduleOf(const aId: string): string;
var
   h: TContestHandle;
begin
   Result := '';
   if FindContestById(aId, h) then
      begin
      Result := ContestIdentity(h).Schedule;
      end;
end;

(* A MARKDOWN TABLE ROW'S CELLS: '| a | b |' gives 'a', 'b'. *)
function TableCells(const aLine: string): TStringArray;
var
   text: string;
   i: integer;
   start: integer;
   count: integer;
begin
   Result := nil;
   text := Trim(aLine);
   if (Length(text) < 2) or (text[1] <> '|') or (text[Length(text)] <> '|') then
      begin
      Exit;
      end;
   count := 0;
   start := 2;
   for i := 2 to Length(text) do
      begin
      if text[i] = '|' then
         begin
         SetLength(Result, count + 1);
         Result[count] := Trim(Copy(text, start, i - start));
         Inc(count);
         start := i + 1;
         end;
      end;
end;

function Parsed(const aText: string): TContestSchedule;
var
   err: string;
begin
   if not TryParseContestSchedule(aText, Result, err) then
      begin
      raise Exception.Create('test schedule does not parse: ' + err);
      end;
end;

(* ------------------------------------------------------------------------ *)

procedure TContestScheduleTests.Test_ParsesEveryClauseShape;
const
   GOOD: array[0..21] of string = (
      '4th full weekend of June at 18:00 UTC for 27h',
      'last full weekend of March at 00:00 UTC for 48h',
      'Second full weekend of December at 00:00 UTC for 48h',
      'First full weekend in December at 22:00 UTC for 42h',
      '4th Saturday of April',
      'last Saturday of February at 18:00 UTC for 12h',
      '4th Saturday of April at 16:00 UTC for 10h; 4th Saturday of April +1d at 12:00 UTC for 10h',
      '2nd full weekend of April +1d at 14:00 UTC for 10h',
      'every Wednesday at 02:30 UTC for 30m',
      'every Wednesday at 13:00 UTC for 1h; every Wednesday at 19:00 UTC for 1h; every Thursday at 03:00 UTC for 1h',
      '06-27 at 12:00 UTC for 2h',
      '02-29',
      '2026-11-01 at 00:00 UTC for 4h; 2027-03-21 at 00:00 UTC for 4h',
      'unscheduled',
      '  UNSCHEDULED  ',
      '1st Sunday of every month at 18:00 UTC for 2h',
      'last full weekend of every month',
      'every day at 12:00 UTC for 1h',
      'FIFTH SATURDAY OF AUGUST at 00:00 utc FOR 90M',
      'every Saturday +1d at 01:00 UTC for 1h',
      '3rd Friday of April at 16:00 UTC for 4h',
      '1st Thursday of January at 17:00 UTC for 1h; 3rd Wednesday of March at 20:00 UTC for 1h'
      );
var
   i: integer;
   s: TContestSchedule;
   err: string;
begin
   BeginTest('Test_ParsesEveryClauseShape');
   for i := Low(GOOD) to High(GOOD) do
      begin
      CheckTrue(TryParseContestSchedule(GOOD[i], s, err), GOOD[i] + ' parses (' + err + ')');
      end;

   s := Parsed('4th Saturday of April at 16:00 UTC for 10h; 4th Saturday of April +1d at 12:00 UTC for 10h');
   CheckEquals(2, Length(s.Clauses), 'two clauses');
   CheckTrue(s.Clauses[1].Anchor = sakAnnual, 'annual anchor');
   CheckTrue(s.Clauses[1].Rule.Kind = cdkWeekday, 'a weekday rule');
   CheckEquals(1, s.Clauses[1].DayOffset, '+1d on a weekday anchor');
   CheckEquals(12 * 60, s.Clauses[1].StartMinute, 'start minute');
   CheckEquals(10 * 60, s.Clauses[1].DurationMinutes, 'duration');
   CheckEquals('4th Saturday of April +1d at 12:00 UTC for 10h', s.Clauses[1].Text, 'clause text kept');

   s := Parsed('every Wednesday at 02:30 UTC for 30m');
   CheckEquals(30, s.Clauses[0].DurationMinutes, 'minutes');
   CheckTrue(s.Clauses[0].Anchor = sakWeekly, 'weekly');

   s := Parsed('4th Saturday of April');
   CheckFalse(s.Clauses[0].HasWindow, 'a date-only hint');

   s := Parsed('unscheduled');
   CheckTrue(s.Unscheduled, 'unscheduled');
   CheckEquals(0, Length(s.Clauses), 'no clause');

   s := Parsed('1st Sunday of every month at 18:00 UTC for 2h');
   CheckTrue(s.Clauses[0].Anchor = sakMonthly, 'monthly');
   s := Parsed('every day');
   CheckTrue(s.Clauses[0].Anchor = sakDaily, 'daily');
   s := Parsed('2027-03-21 at 00:00 UTC for 4h');
   CheckTrue(s.Clauses[0].Anchor = sakDate, 'one date');
   CheckTrue(s.Clauses[0].Date = EncodeDate(2027, 3, 21), 'its date');
end;

procedure TContestScheduleTests.Test_RefusesBadInputNamingTheClause;
const
   PREFIX = '1st Saturday of May at 13:00 UTC for 18h; ';
   BAD: array[0..27] of string = (
      'Juen 4th',
      '4th Saturday of Juen',
      '6th Saturday of April',
      '4th Funday of April',
      '4th full week of April',
      '4th Saturday April',
      '4th Saturday of every year',
      'every Funday',
      'every',
      '4th Saturday of April at 24:00 UTC for 1h',
      '4th Saturday of April at 16:60 UTC for 1h',
      '4th Saturday of April at 4:00 UTC for 1h',
      '4th Saturday of April at 16:00 for 10h',
      '4th Saturday of April at 16:00 UTC 10h',
      '4th Saturday of April at 16:00 UTC for 0h',
      '4th Saturday of April at 16:00 UTC for 169h',
      '4th Saturday of April at 16:00 UTC for 10',
      '4th Saturday of April at 16:00 UTC for 10h now',
      '4th Saturday of April at 16:00 UTC until 02:00 UTC',
      '4th Saturday of April +0d',
      '4th Saturday of April +32d',
      '4th Saturday of April -1d',
      '02-30',
      '13-01',
      '2026-02-29',
      '2026-13-01 at 00:00 UTC for 1h',
      'unscheduled',
      ''
      );
var
   i: integer;
   s: TContestSchedule;
   err: string;
   clause: string;
begin
   BeginTest('Test_RefusesBadInputNamingTheClause');
   for i := Low(BAD) to High(BAD) do
      begin
      CheckFalse(TryParseContestSchedule(PREFIX + BAD[i], s, err), BAD[i] + ' is refused');
      clause := 'clause 2 "' + BAD[i] + '"';
      CheckTrue(Pos(clause, err) = 1, 'the message names ' + clause + ': ' + err);
      CheckEquals(0, Length(s.Clauses), 'a refused string leaves no clause');
      end;
   CheckFalse(TryParseContestSchedule('', s, err), 'empty');
   CheckTrue(err <> '', 'empty has a message');
   CheckFalse(TryParseContestSchedule('   ', s, err), 'blank');
   CheckFalse(TryParseContestSchedule(';;', s, err), 'blank clauses');
   CheckFalse(TryParseContestSchedule('4th Saturday of April;', s, err), 'trailing ;');
   CheckTrue(Pos('clause 2', err) = 1, 'the trailing blank clause is named: ' + err);
   CheckFalse(TryParseContestSchedule('unscheduled; 4th Saturday of April', s, err),
              'unscheduled beside a clause');
   CheckFalse(s.Unscheduled, 'and is not taken as unscheduled');
end;

procedure TContestScheduleTests.Test_ResolverBeforeInsideAndAfter;
var
   s: TContestSchedule;
   startUTC, endUTC, key: TDateTime;
begin
   BeginTest('Test_ResolverBeforeInsideAndAfter');
   (* CQ WPX SSB, the class's own string. 2030: LAST full weekend is March
      30-31; a 4th Saturday rule would give March 23. *)
   s := Parsed(ScheduleOf('CQ-WPX-SSB'));
   CheckTrue(TryNextSchedulePeriod(s.Clauses[0], At(2030, 1, 1, 0, 0), startUTC, endUTC), '2030 period');
   CheckEquals(Stamp(At(2030, 3, 30, 0, 0)), Stamp(startUTC), 'CQ WPX SSB 2030 starts March 30');
   CheckEquals(Stamp(At(2030, 4, 1, 0, 0)), Stamp(endUTC), 'and ends 48h later');

   (* RUNNING ON THE SUNDAY: the anchor (Saturday) is yesterday. *)
   CheckTrue(TryScheduleSortKey(s, At(2030, 3, 31, 12, 0), key), 'running');
   CheckEquals(Stamp(At(2030, 3, 31, 12, 0)), Stamp(key), 'a running contest keys on now');

   (* [start, end): at the start it runs; at the end it is next year's. *)
   CheckTrue(TryScheduleSortKey(s, At(2030, 3, 30, 0, 0), key), 'at the start');
   CheckEquals(Stamp(At(2030, 3, 30, 0, 0)), Stamp(key), 'the start is inside');
   CheckTrue(TryScheduleSortKey(s, At(2030, 3, 31, 23, 59), key), 'last minute');
   CheckEquals(Stamp(At(2030, 3, 31, 23, 59)), Stamp(key), 'the last minute is inside');
   CheckTrue(TryScheduleSortKey(s, At(2030, 4, 1, 0, 0), key), 'at the end');
   CheckEquals(Stamp(At(2031, 3, 29, 0, 0)), Stamp(key), 'the end is outside: 2031');

   (* A DATE-ONLY HINT COVERS ITS WHOLE UTC DAY. *)
   s := Parsed('4th Saturday of April');
   CheckTrue(TryScheduleSortKey(s, At(2026, 4, 25, 23, 59), key), 'hint day');
   CheckEquals(Stamp(At(2026, 4, 25, 23, 59)), Stamp(key), 'the hint day runs all day');
   CheckTrue(TryScheduleSortKey(s, At(2026, 4, 26, 0, 0), key), 'after the hint day');
   CheckEquals(Stamp(At(2027, 4, 24, 0, 0)), Stamp(key), 'next year''s hint day');

   s := Parsed('unscheduled');
   CheckFalse(TryScheduleSortKey(s, At(2026, 4, 26, 0, 0), key), 'unscheduled has no key');
end;

procedure TContestScheduleTests.Test_ResolverOverMultiplePeriods;
var
   s: TContestSchedule;
   key: TDateTime;
   entry: TContestDateEntry;
begin
   BeginTest('Test_ResolverOverMultiplePeriods');
   (* FLORIDA: Saturday 1600-0200, Sunday 1200-2200 -- two periods. *)
   s := Parsed(ScheduleOf('FLORIDA QSO PARTY'));
   CheckTrue(TryScheduleSortKey(s, At(2026, 4, 1, 0, 0), key), 'before');
   CheckEquals(Stamp(At(2026, 4, 25, 16, 0)), Stamp(key), 'before: the first start');
   CheckTrue(TryScheduleSortKey(s, At(2026, 4, 26, 1, 0), key), 'first period');
   CheckEquals(Stamp(At(2026, 4, 26, 1, 0)), Stamp(key), 'inside the first period: now');
   CheckTrue(TryScheduleSortKey(s, At(2026, 4, 26, 2, 0), key), 'overnight gap');
   CheckEquals(Stamp(At(2026, 4, 26, 12, 0)), Stamp(key), 'in the gap: the Sunday start, not next year');
   CheckTrue(TryScheduleSortKey(s, At(2026, 4, 26, 21, 59), key), 'second period');
   CheckEquals(Stamp(At(2026, 4, 26, 21, 59)), Stamp(key), 'inside the second period: now');
   CheckTrue(TryScheduleSortKey(s, At(2026, 4, 26, 22, 0), key), 'after the last period');
   CheckEquals(Stamp(At(2027, 4, 24, 16, 0)), Stamp(key), 'after the last period: next year');

   (* +1d IS THE DAY AFTER THE SAME ANCHOR. April 2029 starts on a Sunday:
      the 4th Saturday is the 28th, so the Sunday period is the 29th -- an
      independent "4th Sunday" would be the 22nd. *)
   CheckTrue(TryScheduleSortKey(s, At(2029, 4, 23, 0, 0), key), '2029');
   CheckEquals(Stamp(At(2029, 4, 28, 16, 0)), Stamp(key), '2029 Saturday period');
   CheckTrue(TryScheduleSortKey(s, At(2029, 4, 29, 3, 0), key), '2029 gap');
   CheckEquals(Stamp(At(2029, 4, 29, 12, 0)), Stamp(key), '2029 Sunday period is the 29th');

   (* ONE ENTRY PER CONTEST, whatever its clause count. *)
   entry := ScheduleDateEntry(s, At(2026, 4, 26, 2, 0), 7);
   CheckTrue(entry.HasDate, 'the entry is dated');
   CheckEquals(7, integer(entry.Tag), 'the caller''s tag');
   CheckEquals(Stamp(At(2026, 4, 26, 12, 0)), Stamp(entry.DateUTC), 'the entry carries the key');

   (* THREE PERIODS -- the Makrothen class's string. 2026: Oct 10-11. *)
   s := Parsed(ScheduleOf('MAKROTHEN-RTTY'));
   CheckTrue(TryScheduleSortKey(s, At(2026, 10, 10, 8, 0), key), 'Makrothen gap 1');
   CheckEquals(Stamp(At(2026, 10, 10, 16, 0)), Stamp(key), 'second period');
   CheckTrue(TryScheduleSortKey(s, At(2026, 10, 11, 0, 0), key), 'Makrothen gap 2');
   CheckEquals(Stamp(At(2026, 10, 11, 8, 0)), Stamp(key), 'third period');
end;

procedure TContestScheduleTests.Test_ResolverRepeatingForms;
var
   s: TContestSchedule;
   key: TDateTime;
begin
   BeginTest('Test_ResolverRepeatingForms');
   (* SESSIONS ON ONE UTC DAY -- the CWT class's string. 2026-11-18 is a
      Wednesday: 1300 and 1900. *)
   s := Parsed(ScheduleOf('CWOPS'));
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 18, 12, 0), key), 'before 1300');
   CheckEquals(Stamp(At(2026, 11, 18, 13, 0)), Stamp(key), 'the 1300 session');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 18, 14, 0), key), 'after 1300');
   CheckEquals(Stamp(At(2026, 11, 18, 19, 0)), Stamp(key), 'the 1900 session the same day');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 18, 19, 30), key), 'inside 1900');
   CheckEquals(Stamp(At(2026, 11, 18, 19, 30)), Stamp(key), 'running');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 19, 7, 0), key), 'Thursday 0700');
   CheckEquals(Stamp(At(2026, 11, 19, 7, 0)), Stamp(key), 'the Thursday 0700 session');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 19, 8, 0), key), 'after the week');
   CheckEquals(Stamp(At(2026, 11, 25, 13, 0)), Stamp(key), 'next Wednesday');

   (* A WEEKLY PERIOD THAT CROSSES MIDNIGHT, through +1d. *)
   s := Parsed('every Saturday +1d at 23:00 UTC for 2h');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 23, 0, 30), key), 'Monday 0030');
   CheckEquals(Stamp(At(2026, 11, 23, 0, 30)), Stamp(key), 'running into Monday');

   (* EVERY DAY. *)
   s := Parsed('every day at 12:00 UTC for 1h');
   CheckTrue(TryScheduleSortKey(s, At(2026, 12, 31, 12, 30), key), 'daily running');
   CheckEquals(Stamp(At(2026, 12, 31, 12, 30)), Stamp(key), 'daily running is now');
   CheckTrue(TryScheduleSortKey(s, At(2026, 12, 31, 13, 0), key), 'daily after');
   CheckEquals(Stamp(At(2027, 1, 1, 12, 0)), Stamp(key), 'tomorrow, across the year');

   (* MONTHLY. *)
   s := Parsed('1st Sunday of every month at 18:00 UTC for 2h');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 16, 0, 0), key), 'monthly');
   CheckEquals(Stamp(At(2026, 12, 6, 18, 0)), Stamp(key), 'the first Sunday of December');
   s := Parsed('last Thursday of every month at 19:00 UTC for 90m');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 1, 0, 0), key), 'monthly last');
   CheckEquals(Stamp(At(2026, 11, 26, 19, 0)), Stamp(key), 'the last Thursday of November');
   (* A FIFTH SATURDAY: none in November or December 2026; January 30 2027. *)
   s := Parsed('5th Saturday of every month');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 1, 0, 0), key), 'monthly fifth');
   CheckEquals(Stamp(At(2027, 1, 30, 0, 0)), Stamp(key), 'skips months without one');
end;

procedure TContestScheduleTests.Test_ResolverExhaustedListLeapAndRollover;
var
   s: TContestSchedule;
   key: TDateTime;
begin
   BeginTest('Test_ResolverExhaustedListLeapAndRollover');
   (* THE SSB SPRINT'S PUBLISHED DATES -- the class's string. *)
   s := Parsed(ScheduleOf('SSB-SPRINT'));
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 1, 3, 59), key), 'first date running');
   CheckEquals(Stamp(At(2026, 11, 1, 3, 59)), Stamp(key), 'running');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 1, 4, 0), key), 'between dates');
   CheckEquals(Stamp(At(2027, 3, 21, 0, 0)), Stamp(key), 'the next published date');
   CheckFalse(TryScheduleSortKey(s, At(2027, 3, 21, 4, 0), key), 'an exhausted list has no date');
   CheckFalse(TryScheduleSortKey(s, At(2030, 1, 1, 0, 0), key), 'and never repeats');

   (* LEAP DAY, FROM A NON-LEAP YEAR. *)
   s := Parsed('02-29 at 12:00 UTC for 1h');
   CheckTrue(TryScheduleSortKey(s, At(2026, 3, 1, 0, 0), key), 'leap');
   CheckEquals(Stamp(At(2028, 2, 29, 12, 0)), Stamp(key), 'the next February 29');

   (* A PERIOD THAT CROSSES THE YEAR. *)
   s := Parsed('12-31 at 22:00 UTC for 4h');
   CheckTrue(TryScheduleSortKey(s, At(2027, 1, 1, 1, 0), key), 'rollover');
   CheckEquals(Stamp(At(2027, 1, 1, 1, 0)), Stamp(key), 'still running on January 1');
   CheckTrue(TryScheduleSortKey(s, At(2027, 1, 1, 2, 0), key), 'rollover end');
   CheckEquals(Stamp(At(2027, 12, 31, 22, 0)), Stamp(key), 'then next December 31');

   (* THE EARLIEST CLAUSE WINS, IN ANY ORDER. *)
   s := Parsed('2nd Saturday of August; 2nd Saturday of January');
   CheckTrue(TryScheduleSortKey(s, At(2026, 11, 16, 0, 0), key), 'two occurrences');
   CheckEquals(Stamp(At(2027, 1, 9, 0, 0)), Stamp(key), 'January comes first');
end;

(* EVERY VERIFIED ROW, from the CLASS's string: the 2027 first period (now =
   2027-01-01), and for a two-period party the second period from its gap. *)
procedure TContestScheduleTests.Test_VerifiedClassesKnownDates;
type
   TKnown = record
      Id: string;
      Now: TDateTime;
      Key: TDateTime;
   end;
var
   known: array of TKnown;
   i: integer;
   s: TContestSchedule;
   err: string;
   key: TDateTime;

   procedure Add(const aId: string; const aNow, aKey: TDateTime);
   begin
      SetLength(known, Length(known) + 1);
      known[High(known)].Id := aId;
      known[High(known)].Now := aNow;
      known[High(known)].Key := aKey;
   end;

begin
   BeginTest('Test_VerifiedClassesKnownDates');
   known := nil;
   Add('7QP', At(2027, 1, 1, 0, 0), At(2027, 5, 1, 13, 0));
   (* The sponsor's rules V 26.0.1: "First Sunday of June each year", 1400Z
      Sunday to 0100Z Monday. 2027's is June 6; 2028's June 4. *)
   Add('AC-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 6, 6, 14, 0));
   Add('AC-QSO-PARTY', At(2027, 6, 7, 0, 59), At(2027, 6, 7, 0, 59));
   Add('AC-QSO-PARTY', At(2027, 6, 7, 1, 30), At(2028, 6, 4, 14, 0));
   Add('ARIZONA QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 10, 9, 15, 0));
   Add('CALIFORNIA QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 10, 2, 16, 0));
   Add('CALIFORNIA QSO PARTY', At(2027, 10, 3, 22, 0), At(2028, 10, 7, 16, 0));
   Add('COLORADO QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 9, 11, 14, 0));
   (* The sponsor's rules page (last update March 8, 2026): 1700 UTC May 9 to
      0300 UTC May 10, 2026, the date alone (no recurrence stated). *)
   Add('CP-QSO-PARTY', At(2026, 1, 1, 0, 0), At(2026, 5, 9, 17, 0));
   Add('CP-QSO-PARTY', At(2026, 5, 10, 2, 59), At(2026, 5, 10, 2, 59));
   Add('CQ-WPX-SSB', At(2027, 1, 1, 0, 0), At(2027, 3, 27, 0, 0));
   Add('CQ-WPX-SSB', At(2030, 1, 1, 0, 0), At(2030, 3, 30, 0, 0));
   Add('GA-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 4, 10, 18, 0));
   Add('GA-QSO-PARTY', At(2027, 4, 11, 5, 0), At(2027, 4, 11, 14, 0));
   (* The sponsor's 2026 announcement: 1700 UTC October 18 to 0100 UTC
      October 19; NY4I (issue 119): the third full weekend of October, so
      the Sunday of it. 2028 opens on a Sunday: its third full weekend is the
      21st-22nd, not the third Sunday (the 15th). *)
   Add('IL-QSO-PARTY', At(2026, 1, 1, 0, 0), At(2026, 10, 18, 17, 0));
   Add('IL-QSO-PARTY', At(2026, 10, 19, 0, 59), At(2026, 10, 19, 0, 59));
   Add('IL-QSO-PARTY', At(2026, 10, 19, 1, 0), At(2027, 10, 17, 17, 0));
   Add('IL-QSO-PARTY', At(2028, 1, 1, 0, 0), At(2028, 10, 22, 17, 0));
   Add('IN QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 5, 1, 15, 0));
   Add('KY-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 6, 5, 13, 0));
   (* The sponsor's rules, revised February 18, 2026: 14:00 UTC April 4 to
      02:00 UTC April 5, 2026; NY4I (issue 122, 2026-11-18): "first weekend
      of April". 2029 opens April on a Sunday: the 7th, not March 31. *)
   Add('LA-QSO-PARTY', At(2026, 1, 1, 0, 0), At(2026, 4, 4, 14, 0));
   Add('LA-QSO-PARTY', At(2026, 4, 5, 1, 59), At(2026, 4, 5, 1, 59));
   Add('LA-QSO-PARTY', At(2026, 4, 5, 2, 0), At(2027, 4, 3, 14, 0));
   Add('LA-QSO-PARTY', At(2029, 1, 1, 0, 0), At(2029, 4, 7, 14, 0));
   Add('MICHIGAN QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 4, 17, 16, 0));
   (* The sponsor's 2026 rules: 1400z April 4 to 0200z April 5, 2026; NY4I
      (issue 123): the first weekend of April -- 2027's is April 3. *)
   Add('MS-QSO-PARTY', At(2026, 1, 1, 0, 0), At(2026, 4, 4, 14, 0));
   Add('MS-QSO-PARTY', At(2026, 4, 5, 1, 59), At(2026, 4, 5, 1, 59));
   Add('MS-QSO-PARTY', At(2026, 4, 5, 2, 0), At(2027, 4, 3, 14, 0));
   Add('NC QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 2, 28, 15, 0));
   Add('NEWEQP', At(2027, 1, 1, 0, 0), At(2027, 5, 1, 20, 0));
   Add('NEWEQP', At(2027, 5, 2, 6, 0), At(2027, 5, 2, 13, 0));
   (* The sponsor's 2026 rules v1.1: the third Saturday of October, October
      17 2026 from 14:00 UTC through 01:59 UTC. 2027's is October 16. *)
   Add('NY-QSO-PARTY', At(2026, 1, 1, 0, 0), At(2026, 10, 17, 14, 0));
   (* Missouri, NY4I 2026-11-20: "MOQP is April 3 and 4, 2027" -- the FIRST
      full weekend of April (2026 alone moved to April 11-12 for Easter).
      Saturday 1400 UTC opens it; its Sunday session resumes at 1400. *)
   Add('MISSOURI QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 4, 3, 14, 0));
   Add('MISSOURI QSO PARTY', At(2027, 4, 4, 5, 0), At(2027, 4, 4, 14, 0));
   Add('NY-QSO-PARTY', At(2026, 10, 18, 1, 59), At(2026, 10, 18, 1, 59));
   Add('NY-QSO-PARTY', At(2026, 10, 18, 2, 0), At(2027, 10, 16, 14, 0));
   Add('ON-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 4, 17, 18, 0));
   Add('ON-QSO-PARTY', At(2027, 4, 18, 4, 0), At(2027, 4, 18, 12, 0));
   Add('PA QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 10, 9, 16, 0));
   Add('PA QSO PARTY', At(2027, 10, 10, 5, 0), At(2027, 10, 10, 13, 0));
   Add('SALMON RUN', At(2027, 1, 1, 0, 0), At(2027, 9, 18, 16, 0));
   Add('SALMON RUN', At(2027, 9, 19, 8, 0), At(2027, 9, 19, 16, 0));
   Add('SC-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 2, 27, 15, 0));
   (* The sponsor's 2027 page: October 9-10, 1800z to 1800z. 2028 opens on a
      Sunday, so its 2nd full weekend is the 14th-15th. *)
   Add('SD-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 10, 9, 18, 0));
   Add('SD-QSO-PARTY', At(2027, 10, 10, 18, 30), At(2028, 10, 14, 18, 0));
   Add('TEXAS QSO PARTY', At(2027, 1, 1, 0, 0), At(2027, 9, 18, 14, 0));
   Add('TEXAS QSO PARTY', At(2027, 9, 19, 3, 0), At(2027, 9, 19, 14, 0));
   Add('VT-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 2, 6, 0, 0));
   Add('WV-QSO-PARTY', At(2027, 1, 1, 0, 0), At(2027, 6, 19, 16, 0));

   for i := 0 to High(known) do
      begin
      CheckTrue(TryParseContestSchedule(ScheduleOf(known[i].Id), s, err),
                known[i].Id + '''s schedule parses (' + err + ')');
      CheckTrue(TryScheduleSortKey(s, known[i].Now, key), known[i].Id + ' has a date');
      CheckEquals(Stamp(known[i].Key), Stamp(key),
                  known[i].Id + ' from ' + Stamp(known[i].Now));
      end;

   (* PUBLISHED DATES RUN OUT: West Virginia and North Carolina state 2026
      and 2027 only. *)
   s := Parsed(ScheduleOf('WV-QSO-PARTY'));
   CheckFalse(TryScheduleSortKey(s, At(2027, 6, 20, 4, 0), key), 'WV after 2027 is undated');
   s := Parsed(ScheduleOf('NC QSO PARTY'));
   CheckFalse(TryScheduleSortKey(s, At(2028, 1, 1, 0, 0), key), 'NC after 2027 is undated');
   (* The Canadian Prairies states its 2026 date only, so it is undated today. *)
   s := Parsed(ScheduleOf('CP-QSO-PARTY'));
   CheckFalse(TryScheduleSortKey(s, At(2026, 5, 10, 3, 0), key), 'CP after 0300 UTC 2026-05-10 is undated');
end;

(* THE NEW CONTEST LIST'S ORDER, through uContestDates.SortContestDates:
   real contests, fed in alphabetical order, one "now". *)
procedure TContestScheduleTests.Test_OrderingOfRealContests;
const
   IDS: array[0..6] of string = (
      'AP-SPRINT', 'CQ-WPX-SSB', 'CWOPS', 'GA-QSO-PARTY', 'GENERAL QSO',
      'MICHIGAN QSO PARTY', 'MISSOURI QSO PARTY');
var
   entries: TContestDateEntries;
   s: TContestSchedule;
   err: string;

   procedure Build(const aNow: TDateTime);
   var
      n: integer;
   begin
      SetLength(entries, Length(IDS));
      for n := 0 to High(IDS) do
         begin
         if TryParseContestSchedule(ScheduleOf(IDS[n]), s, err) then
            begin
            entries[n] := ScheduleDateEntry(s, aNow, n);
            end
         else
            begin
            (* NOT YET STATED: undated. *)
            entries[n].Tag := n;
            entries[n].HasDate := False;
            entries[n].DateUTC := 0;
            end;
         end;
      SortContestDates(entries);
   end;

   function Order: string;
   var
      n: integer;
   begin
      Result := '';
      for n := 0 to High(entries) do
         begin
         if Result <> '' then
            begin
            Result := Result + ' | ';
            end;
         Result := Result + IDS[entries[n].Tag];
         end;
   end;

begin
   BeginTest('Test_OrderingOfRealContests');
   (* SUNDAY 2027-04-11 0500: Georgia is in its overnight gap and resumes at
      1400. Missouri ran April 3-4 (NY4I: "MOQP is April 3 and 4, 2027"), so
      its next is April 1, 2028, after CQ WPX SSB's March 2028. The CWT is
      next Wednesday, Michigan the next Saturday; General QSO (unscheduled)
      and AP-SPRINT (not yet stated) last, alphabetical. *)
   Build(At(2027, 4, 11, 5, 0));
   CheckEquals('GA-QSO-PARTY | CWOPS | MICHIGAN QSO PARTY | CQ-WPX-SSB | ' +
               'MISSOURI QSO PARTY | AP-SPRINT | GENERAL QSO', Order, 'in the gap');
   CheckEquals(Length(IDS), Length(entries), 'one entry per contest');

   (* SATURDAY 2027-04-10 2000: Georgia is ON THE AIR (since 1800) and sorts
      first; Missouri has already run (April 3-4). *)
   Build(At(2027, 4, 10, 20, 0));
   CheckEquals('GA-QSO-PARTY | CWOPS | MICHIGAN QSO PARTY | CQ-WPX-SSB | ' +
               'MISSOURI QSO PARTY | AP-SPRINT | GENERAL QSO', Order, 'Georgia running');
   CheckEquals(Stamp(At(2027, 4, 10, 20, 0)), Stamp(entries[0].DateUTC), 'the running key is now');

   (* WEDNESDAY 2027-04-14 1330: the CWT is on the air. *)
   Build(At(2027, 4, 14, 13, 30));
   CheckEquals('CWOPS', IDS[entries[0].Tag], 'a running CWT sorts first');
end;

(* THE REGISTRY: see SCHEDULE_NOT_YET_STATED. *)
procedure TContestScheduleTests.Test_EveryContestStatesItsSchedule;
var
   contests: TContestIdentityList;
   k: integer;
   i: integer;
   id: string;
   states: boolean;
   found: boolean;
   s: TContestSchedule;
   err: string;
   base: TContestBase;
begin
   BeginTest('Test_EveryContestStatesItsSchedule');
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      id := ContestId(HandleOf(contests[k]));
      (* ITS OWN CLASS, never a family base: a schedule on a family base would
         hand a held sibling (CQ WW SSB) its neighbour's dates. *)
      states := ClassStatesItself(contests[k], ScheduleCode);
      if IdIsIn(id, SCHEDULE_NOT_YET_STATED) then
         begin
         CheckFalse(ClassOverridesTheBase(contests[k], ScheduleCode),
                    ContestWho(contests[k]) + ' states its schedule -- take it out of SCHEDULE_NOT_YET_STATED');
         CheckEquals('', contests[k].Schedule, ContestWho(contests[k]) + ' is still pending');
         end
      else
         begin
         CheckTrue(states, ContestWho(contests[k]) +
                   ' states its schedule (GetSchedule) on its own class -- a new contest states it from its first commit');
         CheckTrue(TryParseContestSchedule(contests[k].Schedule, s, err),
                   id + ': ' + err);
         end;
      end;

   (* NO STALE ENTRY: every id in the list is a registered contest. *)
   for i := Low(SCHEDULE_NOT_YET_STATED) to High(SCHEDULE_NOT_YET_STATED) do
      begin
      found := False;
      for k := 0 to High(contests) do
         begin
         if ContestId(HandleOf(contests[k])) = SCHEDULE_NOT_YET_STATED[i] then
            begin
            found := True;
            Break;
            end;
         end;
      CheckTrue(found, 'SCHEDULE_NOT_YET_STATED names ' + SCHEDULE_NOT_YET_STATED[i] +
                ', which is no registered contest');
      end;

   (* THE CHECK CAN FAIL BOTH WAYS. *)
   base := TContestBase.Create(NoContest);
   try
      CheckFalse(ClassOverridesTheBase(base, ScheduleCode), 'the base states no schedule');
      CheckEquals('', base.Schedule, 'the base answers not yet stated');
      CheckFalse(TryParseContestSchedule(base.Schedule, s, err), 'which never parses as unscheduled');
   finally
      base.Free;
      end;
   CheckTrue(ClassStatesItself(ContestIdentity(ContestHandleOf(CQWPXSSB)), ScheduleCode),
             'CQ WPX SSB states its own');
   CheckEquals('unscheduled', ScheduleOf('GENERAL QSO'), 'General QSO is deliberately unscheduled');
end;

(* EVERY CLASS-FORM EXAMPLE IN THE README's "How do I enter..." TABLE PARSES. *)
procedure TContestScheduleTests.Test_ReadmeExamplesParse;
var
   path: string;
   lines: TStringList;
   i: integer;
   inside: boolean;
   cells: TStringArray;
   cell: string;
   s: TContestSchedule;
   err: string;
   count: integer;
begin
   BeginTest('Test_ReadmeExamplesParse');
   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
                          '..' + PathDelim + 'docs' + PathDelim + 'CONTEST_SCHEDULES_README.md');
   CheckTrue(FileExists(path), 'the README is found: ' + path);
   if not FileExists(path) then
      begin
      Exit;
      end;
   count := 0;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(path);
      inside := False;
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('<!-- schedule-examples-begin -->', lines[i]) > 0 then
            begin
            inside := True;
            end
         else if Pos('<!-- schedule-examples-end -->', lines[i]) > 0 then
            begin
            inside := False;
            end
         else if inside then
            begin
            (* '| a | b | c |': the class form is the third cell. *)
            cells := TableCells(lines[i]);
            if Length(cells) = 3 then
               begin
               cell := Trim(cells[2]);
               if (Length(cell) >= 2) and (cell[1] = '`') and (cell[Length(cell)] = '`') then
                  begin
                  cell := Copy(cell, 2, Length(cell) - 2);
                  CheckTrue(TryParseContestSchedule(cell, s, err),
                            'README example "' + cell + '" parses (' + err + ')');
                  Inc(count);
                  end;
               end;
            end;
         end;
   finally
      lines.Free;
      end;
   CheckTrue(count >= 10, 'the README table was read (' + IntToStr(count) + ' examples)');
end;

(* 'the <weekday> before <anchor>' -- NY4I, 2026-11-17: the last such weekday
   STRICTLY before the anchor's date. ARRL 160's start dates are NY4I's, read
   from the class's RETURNED string; the others were computed independently
   (Python's calendar). *)
procedure TContestScheduleTests.Test_TheWeekdayBeforeAnAnchor;
const
   (* ARRL 160: Friday 2200Z, the Friday before the first full weekend of
      December; 2029 starts in NOVEMBER (that weekend is Dec 1-2). *)
   ARRL160_YEAR: array[0..5] of word = (2026, 2027, 2028, 2029, 2030, 2031);
   ARRL160_MONTH: array[0..5] of word = (12, 12, 12, 11, 12, 12);
   ARRL160_DAY: array[0..5] of word = (4, 3, 1, 30, 6, 5);
var
   s: TContestSchedule;
   startUTC, endUTC: TDateTime;
   err: string;
   i: integer;
begin
   BeginTest('Test_TheWeekdayBeforeAnAnchor');
   s := Parsed(ScheduleOf('ARRL-160'));
   CheckEquals(1, Length(s.Clauses), 'ARRL 160 states one period');
   for i := 0 to High(ARRL160_YEAR) do
      begin
      CheckTrue(TryNextSchedulePeriod(s.Clauses[0], At(ARRL160_YEAR[i], 1, 1, 0, 0),
                                      startUTC, endUTC),
                'ARRL 160 has a period in ' + IntToStr(ARRL160_YEAR[i]));
      CheckEquals(Stamp(At(ARRL160_YEAR[i], ARRL160_MONTH[i], ARRL160_DAY[i], 22, 0)),
                  Stamp(startUTC), 'ARRL 160 starts Friday 2200Z');
      CheckEquals(Stamp(At(ARRL160_YEAR[i], ARRL160_MONTH[i], ARRL160_DAY[i], 22, 0) + 42 / 24),
                  Stamp(endUTC), 'and ends Sunday 1600Z, 42 hours on');
      end;

   (* STRICTLY BEFORE: June 20 2026 is a Saturday, so the Saturday before it
      is June 13; the Saturday before June 21 2026 (a Sunday) is June 20 --
      West Virginia's "the Saturday on or before June 20". *)
   s := Parsed('the Saturday before 06-20');
   CheckTrue(TryNextSchedulePeriod(s.Clauses[0], At(2026, 1, 1, 0, 0), startUTC, endUTC), '06-20');
   CheckEquals(Stamp(At(2026, 6, 13, 0, 0)), Stamp(startUTC), 'strictly before: never the anchor day itself');
   s := Parsed('the Saturday before 06-21');
   CheckTrue(TryNextSchedulePeriod(s.Clauses[0], At(2026, 1, 1, 0, 0), startUTC, endUTC), '06-21 2026');
   CheckEquals(Stamp(At(2026, 6, 20, 0, 0)), Stamp(startUTC), 'June 21 2026 is a Sunday: Sat June 20');
   CheckTrue(TryNextSchedulePeriod(s.Clauses[0], At(2027, 1, 1, 0, 0), startUTC, endUTC), '06-21 2027');
   CheckEquals(Stamp(At(2027, 6, 19, 0, 0)), Stamp(startUTC), 'June 21 2027 is a Monday: Sat June 19');

   (* '+Nd' COUNTS FROM THE MOVED DAY: the Sunday after that Saturday. *)
   s := Parsed('the Saturday before the 4th Sunday of August +1d at 12:00 UTC for 1h');
   CheckTrue(TryNextSchedulePeriod(s.Clauses[0], At(2027, 1, 1, 0, 0), startUTC, endUTC), '+1d');
   CheckEquals(Stamp(At(2027, 8, 22, 12, 0)), Stamp(startUTC), 'Sat Aug 21 2027 +1d is Sun Aug 22');

   (* A PERIOD RUNNING ACROSS ITS ANCHOR is still found running: ARRL 160 at
      Saturday noon of the 2029 weekend, after its Friday Nov 30 start. *)
   s := Parsed(ScheduleOf('ARRL-160'));
   CheckTrue(TryNextSchedulePeriod(s.Clauses[0], At(2029, 12, 1, 12, 0), startUTC, endUTC), 'running');
   CheckEquals(Stamp(At(2029, 11, 30, 22, 0)), Stamp(startUTC), 'the running period is the Nov 30 one');

   (* THE FORM IS STRICT. *)
   CheckFalse(TryParseContestSchedule('the Funday before the 4th Sunday of August', s, err),
              'an unknown weekday is refused');
   CheckTrue(Pos('weekday', err) > 0, 'naming what was expected: ' + err);
   CheckFalse(TryParseContestSchedule('the Friday after the first full weekend of December', s, err),
              '"after" is no form');
   CheckFalse(TryParseContestSchedule('the Friday before', s, err), 'an anchor is needed');
   CheckFalse(TryParseContestSchedule('the Friday before the', s, err), 'still no anchor');
   CheckTrue(TryParseContestSchedule('THE friday BEFORE first full weekend of December', s, err),
             'case-insensitive, and the second "the" is optional (' + err + ')');
end;

(* EVERY ARRL CLASS THAT STATES A SCHEDULE, AGAINST THE ARRL'S OWN CALENDAR
   for 2026-2031 (docs/ContestRules/ARRL/arrl-calendar-2026-2031.md, NY4I
   2026-11-17 -- a sponsor source). Each class's RETURNED string through the
   real parser: the start DATE of the clause's period in that year must be
   the calendar cell's first date. Contests with no class (Rookie Roundup,
   School Club Roundup, 222 MHz, 10 GHz, EME, Straight Key Night) are not
   here. *)
type
   TARRLCalendarRow = record
      Id: string;
      Clause: integer;
      Months: array[0..5] of word;
      Days: array[0..5] of word;
   end;

const
   ARRL_CALENDAR: array[0..14] of TARRLCalendarRow = (
      (Id: 'ARRL-10';      Clause: 0; Months: (12, 12, 12, 12, 12, 12); Days: (12, 11, 9, 8, 14, 13)),
      (Id: 'ARRL-160';     Clause: 0; Months: (12, 12, 12, 11, 12, 12); Days: (4, 3, 1, 30, 6, 5)),
      (Id: 'ARRL-DIGI';    Clause: 0; Months: (6, 6, 6, 6, 6, 6);       Days: (6, 5, 3, 2, 1, 7)),
      (Id: 'ARRL-DX-CW';   Clause: 0; Months: (2, 2, 2, 2, 2, 2);       Days: (21, 20, 19, 17, 16, 15)),
      (Id: 'ARRL-DX-SSB';  Clause: 0; Months: (3, 3, 3, 3, 3, 3);       Days: (7, 6, 4, 3, 2, 1)),
      (Id: 'ARRL-FD';      Clause: 0; Months: (6, 6, 6, 6, 6, 6);       Days: (27, 26, 24, 23, 22, 28)),
      (Id: 'IARU-HF';      Clause: 0; Months: (7, 7, 7, 7, 7, 7);       Days: (11, 10, 8, 14, 13, 12)),
      (Id: 'ARRL-VHF-JAN'; Clause: 0; Months: (1, 1, 1, 1, 1, 1);       Days: (17, 16, 15, 20, 19, 18)),
      (Id: 'ARRL-VHF-JUN'; Clause: 0; Months: (6, 6, 6, 6, 6, 6);       Days: (13, 12, 10, 9, 8, 14)),
      (Id: 'ARRL-VHF-SEP'; Clause: 0; Months: (9, 9, 9, 9, 9, 9);       Days: (12, 11, 9, 8, 14, 13)),
      (Id: 'KIDS DAY';     Clause: 0; Months: (1, 1, 1, 1, 1, 1);       Days: (3, 2, 8, 6, 5, 4)),
      (Id: 'KIDS DAY';     Clause: 1; Months: (6, 6, 6, 6, 6, 6);       Days: (20, 19, 17, 16, 15, 21)),
      (Id: 'ARRL-RTTY';    Clause: 0; Months: (1, 1, 1, 1, 1, 1);       Days: (3, 2, 8, 6, 5, 4)),
      (Id: 'ARRL-SS-CW';   Clause: 0; Months: (11, 11, 11, 11, 11, 11); Days: (7, 6, 4, 3, 2, 1)),
      (Id: 'ARRL-SS-SSB';  Clause: 0; Months: (11, 11, 11, 11, 11, 11); Days: (21, 20, 18, 17, 16, 15))
      );

procedure TContestScheduleTests.Test_ARRLClassesAgreeWithTheARRLCalendar;
var
   i, k: integer;
   s: TContestSchedule;
   startUTC, endUTC: TDateTime;
   year: word;
begin
   BeginTest('Test_ARRLClassesAgreeWithTheARRLCalendar');
   for i := 0 to High(ARRL_CALENDAR) do
      begin
      s := Parsed(ScheduleOf(ARRL_CALENDAR[i].Id));
      CheckTrue(ARRL_CALENDAR[i].Clause <= High(s.Clauses),
                ARRL_CALENDAR[i].Id + ' states the clause');
      for k := 0 to 5 do
         begin
         year := 2026 + k;
         CheckTrue(TryNextSchedulePeriod(s.Clauses[ARRL_CALENDAR[i].Clause],
                                         At(year, 1, 1, 0, 0), startUTC, endUTC),
                   ARRL_CALENDAR[i].Id + ' has a period in ' + IntToStr(year));
         CheckEquals(FormatDateTime('yyyy-mm-dd',
                        EncodeDate(year, ARRL_CALENDAR[i].Months[k], ARRL_CALENDAR[i].Days[k])),
                     FormatDateTime('yyyy-mm-dd', startUTC),
                     ARRL_CALENDAR[i].Id + ' ' + IntToStr(year) + ' starts on the ARRL calendar''s date');
         end;
      end;
end;

procedure TContestScheduleTests.RunAllTests;
begin
   Test_ParsesEveryClauseShape;
   Test_RefusesBadInputNamingTheClause;
   Test_ResolverBeforeInsideAndAfter;
   Test_ResolverOverMultiplePeriods;
   Test_ResolverRepeatingForms;
   Test_ResolverExhaustedListLeapAndRollover;
   Test_VerifiedClassesKnownDates;
   Test_TheWeekdayBeforeAnAnchor;
   Test_ARRLClassesAgreeWithTheARRLCalendar;
   Test_OrderingOfRealContests;
   Test_EveryContestStatesItsSchedule;
   Test_ReadmeExamplesParse;
end;

end.
