unit uTestContestDates;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestDatesTests = class(TTestCase)
   private
      procedure Test_WeekendBoundaries;
      procedure Test_FullGregorianCycle;
      procedure Test_WeekdaysAndFixedDates;
      procedure Test_NextDateUsesUTCDateInclusively;
      procedure Test_InvalidAndMissingDates;
      procedure Test_StableOrdering;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, DateUtils, Math, uContestDates;

function WeekendRule(aMonth: integer;
                      aOrdinal: TContestDateOrdinal): TContestDateRule;
begin
   Result.Kind := cdkFullWeekend;
   Result.Month := aMonth;
   Result.Day := 0;
   Result.Ordinal := aOrdinal;
   Result.Weekday := cdwSaturday;
end;

procedure TContestDatesTests.Test_WeekendBoundaries;
var
   rule: TContestDateRule;
   date: TDateTime;
begin
   BeginTest('WeekendBoundaries');
   rule := WeekendRule(8, cdoFourth);
   Check(TryContestDate(rule, 2026, date) and (date = EncodeDate(2026, 8, 22)),
         'fourth differs from last when there are five full weekends');
   rule.Ordinal := cdoLast;
   Check(TryContestDate(rule, 2026, date) and (date = EncodeDate(2026, 8, 29)),
         'last full weekend');
   rule.Month := 10; // October 2026 ends Saturday
   Check(TryContestDate(rule, 2026, date) and (date = EncodeDate(2026, 10, 24)),
         'last full weekend excludes Saturday October 31');
   rule.Kind := cdkWeekday;
   Check(TryContestDate(rule, 2026, date) and (date = EncodeDate(2026, 10, 31)),
         'last Saturday may have its Sunday next month');
   rule := WeekendRule(6, cdoFourth);
   Check(TryContestDate(rule, 2026, date) and (date = EncodeDate(2026, 6, 27)),
         'fourth full weekend in June');
end;

procedure TContestDatesTests.Test_FullGregorianCycle;
var
   year, month, day, count, index, failures: integer;
   weekends: array[0..4] of TDateTime;
   rule: TContestDateRule;
   ordinal: TContestDateOrdinal;
   expected, actual, candidate: TDateTime;
   found: boolean;
begin
   BeginTest('FullGregorianCycle');
   failures := 0;
   (* Independent oracle: enumerate actual Saturday/Sunday pairs, rather
      than repeating the implementation's weekday-offset arithmetic. *)
   for year := 2000 to 2399 do
      begin
      for month := 1 to 12 do
         begin
         count := 0;
         for day := 1 to DaysInAMonth(year, month) - 1 do
            begin
            candidate := EncodeDate(year, month, day);
            if DayOfTheWeek(candidate) = 6 then
               begin
               weekends[count] := candidate;
               Inc(count);
               end;
            end;
         for ordinal := cdoFirst to cdoLast do
            begin
            rule := WeekendRule(month, ordinal);
            index := Ord(ordinal);
            if ordinal = cdoLast then
               begin
               index := count - 1;
               end;
            expected := 0;
            if index < count then
               begin
               expected := weekends[index];
               end;
            found := TryContestDate(rule, year, actual);
            if (found <> (index < count)) or (actual <> expected) then
               begin
               Inc(failures);
               end;
            end;
         end;
      end;
   CheckEquals(0, failures, 'all months and full-weekend ordinals over 400 years');
end;

procedure TContestDatesTests.Test_WeekdaysAndFixedDates;
var
   rule: TContestDateRule;
   date: TDateTime;
   weekday: TContestDateWeekday;
begin
   BeginTest('WeekdaysAndFixedDates');
   rule := WeekendRule(6, cdoFirst);
   rule.Kind := cdkWeekday;
   for weekday := cdwMonday to cdwSunday do
      begin
      rule.Weekday := weekday;
      Check(TryContestDate(rule, 2026, date) and
            (date = EncodeDate(2026, 6, Ord(weekday) + 1)),
            'June 2026 begins Monday; verify every weekday numbering');
      end;
   rule.Ordinal := cdoSecond;
   rule.Weekday := cdwSaturday;
   Check(TryContestDate(rule, 2026, date) and (date = EncodeDate(2026, 6, 13)),
         'second Saturday');
   rule.Kind := cdkFixedDate;
   rule.Month := 2;
   rule.Day := 29;
   Check(TryContestDate(rule, 2028, date) and (date = EncodeDate(2028, 2, 29)),
         'leap day');
   Check(not TryContestDate(rule, 2100, date), 'century without leap day');
   Check(date = 0, 'failure clears output');
   Check(TryNextContestDate(rule, EncodeDate(2097, 1, 1), date) and
         (date = EncodeDate(2104, 2, 29)), 'skip nonleap century');
end;

procedure TContestDatesTests.Test_NextDateUsesUTCDateInclusively;
var
   rule: TContestDateRule;
   date: TDateTime;
begin
   BeginTest('NextDateUsesUTCDateInclusively');
   rule := WeekendRule(6, cdoFourth);
   Check(TryNextContestDate(rule, EncodeDateTime(2026, 6, 27, 23, 59, 59, 0), date)
         and (date = EncodeDate(2026, 6, 27)), 'today remains listed all UTC day');
   Check(TryNextContestDate(rule, EncodeDate(2026, 6, 28), date) and
         (date = EncodeDate(2027, 6, 26)), 'roll over after UTC date');
   rule.Kind := cdkFixedDate;
   rule.Month := 1;
   rule.Day := 1;
   Check(TryNextContestDate(rule, EncodeDateTime(2026, 12, 31, 23, 59, 59, 0), date)
         and (date = EncodeDate(2027, 1, 1)), 'explicit UTC reference at year end');
   Check(TryNextContestDate(rule, EncodeDate(2027, 1, 1), date) and
         (date = EncodeDate(2027, 1, 1)), 'exact midnight included');
end;

procedure TContestDatesTests.Test_InvalidAndMissingDates;
var
   rule: TContestDateRule;
   date: TDateTime;
begin
   BeginTest('InvalidAndMissingDates');
   rule := WeekendRule(2, cdoFifth);
   Check(not TryContestDate(rule, 2026, date), 'absent fifth is not fourth');
   Check(date = 0, 'absent occurrence clears output');
   rule := WeekendRule(8, cdoFifth);
   Check(TryNextContestDate(rule, EncodeDate(2027, 1, 1), date) and
         (date = EncodeDate(2031, 8, 30)), 'skip years without fifth full weekend');
   rule.Month := 0;
   Check(not TryNextContestDate(rule, EncodeDate(2026, 1, 1), date), 'bad month');
   rule.Kind := cdkFixedDate;
   rule.Month := 4;
   rule.Day := 31;
   Check(not TryNextContestDate(rule, EncodeDate(2026, 1, 1), date), 'impossible date');
   rule.Day := 1;
   Check(not TryContestDate(rule, 0, date), 'year zero');
   Check(not TryContestDate(rule, 10000, date), 'year exceeds calendar');
   Check(not TryNextContestDate(rule, NaN, date), 'NaN reference');
   Check(not TryNextContestDate(rule, Infinity, date), 'infinite reference');
   Check(not TryNextContestDate(rule, EncodeDate(9999, 12, 31), date),
         'no representable future occurrence');
end;

procedure TContestDatesTests.Test_StableOrdering;
var
   entries: TContestDateEntries;
   index: integer;
begin
   BeginTest('StableOrdering');
   entries := nil;
   SortContestDates(entries);
   CheckEquals(0, Length(entries), 'empty input');
   SetLength(entries, 6);
   for index := 0 to High(entries) do
      begin
      entries[index].Tag := index;
      entries[index].HasDate := True;
      end;
   entries[0].HasDate := False;
   entries[1].DateUTC := EncodeDate(2027, 1, 1);
   entries[2].DateUTC := EncodeDate(2026, 12, 31);
   entries[3].DateUTC := entries[1].DateUTC;
   entries[4].HasDate := False;
   entries[5].DateUTC := entries[2].DateUTC + EncodeTime(12, 0, 0, 0);
   SortContestDates(entries);
   CheckEquals(2, entries[0].Tag, 'ascending earliest');
   CheckEquals(5, entries[1].Tag, 'time of day participates');
   CheckEquals(1, entries[2].Tag, 'equal dates retain order, first');
   CheckEquals(3, entries[3].Tag, 'equal dates retain order, second');
   CheckEquals(0, entries[4].Tag, 'undated last, first');
   CheckEquals(4, entries[5].Tag, 'undated last, second');
   SortContestDates(entries, False);
   CheckEquals(1, entries[0].Tag, 'descending latest, stable first');
   CheckEquals(3, entries[1].Tag, 'descending tie, stable second');
   CheckEquals(5, entries[2].Tag, 'descending middle');
   CheckEquals(2, entries[3].Tag, 'descending earliest');
   CheckEquals(0, entries[4].Tag, 'undated still last');
   CheckEquals(4, entries[5].Tag, 'undated still stable');
   SetLength(entries, 1);
   SortContestDates(entries);
   CheckEquals(1, entries[0].Tag, 'single entry unchanged');
end;

procedure TContestDatesTests.RunAllTests;
begin
   Test_WeekendBoundaries;
   Test_FullGregorianCycle;
   Test_WeekdaysAndFixedDates;
   Test_NextDateUsesUTCDateInclusively;
   Test_InvalidAndMissingDates;
   Test_StableOrdering;
end;

end.
