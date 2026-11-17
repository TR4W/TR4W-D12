unit uContestDates;

(* CALENDAR ARITHMETIC AND DATE ORDERING -- no contest-specific data.

   HOW A CALLER USES IT. The New Contest dialog's "Upcoming contests first"
   is built on this (uContestChoices.SoonestFirstOrder, through
   uContestSchedule); the steps below are the general recipe.
   The contest CLASS supplies TContestDateRule values. This unit knows no
   contest names, registry, controls, globals, operating periods or sponsors.
   Rules are typed; display descriptions are never parsed.

   Example: fourth full weekend of June:
      rule.Kind := cdkFullWeekend;
      rule.Month := 6;
      rule.Ordinal := cdoFourth;
      rule.Weekday := cdwSaturday; // ignored for full weekends
      rule.Day := 0;              // used only for fixed dates
      entry.HasDate := TryNextContestDate(rule, UTCNow, entry.DateUTC);
      entry.Tag := index;         // YOUR index/identifier, never dereferenced

   UTCNow is the existing uSpotAge.UTCNow, supplied by the CALLER. Every input
   and output is UTC by contract: TDateTime itself has no timezone. Results
   are midnight UTC dates, not contest start times. A reference time is reduced
   to its UTC date; TODAY IS INCLUDED, unlike TR4QT's strictly-future lookup.
   Classes supply start times, durations, exceptions and multiple occurrences.
   For several rules, call TryNextContestDate for each and retain the earliest
   successful result. This helper cannot decide whether a contest is running.

   Build TContestDateEntries, one per dropdown item, then call
      SortContestDates(entries);         // ascending, soonest first
      SortContestDates(entries, False);  // descending
   Rebuild the dropdown using each entry.Tag to find the caller's own item.
   Equal dates retain input order (e.g. the caller's alphabetical order).
   HasDate=False entries stay at the END in either direction, retaining order.
   HasDate=True requires a valid, finite UTC TDateTime supplied by the caller.
   Sorting is in place; copy the array first if the original order is needed.
   Tags are values, carry no ownership, and need not be unique.

   cdoLast + cdkWeekday + cdwSaturday means the LAST SATURDAY, even if Sunday
   is next month. cdoLast + cdkFullWeekend requires BOTH days in the month.
   Fourth and last full weekends can differ in a month with five full weekends.
   An absent fifth occurrence or invalid date returns False and clears output;
   next-occurrence lookup skips years without the date (including Feb 29).
   Tests: uTestContestDates. Architecture: docs/CONTEST_DATES.md.

   THE SCHEDULE STRING a contest class states (TContestBase.Schedule) is
   parsed and resolved by uContestSchedule, which calls this unit for every
   calendar question. Its grammar is docs/CONTEST_SCHEDULES_README.md.
*)

{$I tr4w.inc}

interface

type
   TContestDateKind = (cdkFixedDate, cdkWeekday, cdkFullWeekend);
   TContestDateOrdinal = (cdoFirst, cdoSecond, cdoThird, cdoFourth,
                         cdoFifth, cdoLast);
   TContestDateWeekday = (cdwMonday, cdwTuesday, cdwWednesday, cdwThursday,
                         cdwFriday, cdwSaturday, cdwSunday);
   TContestDateRule = record
      Kind: TContestDateKind;
      Month: integer;                  // 1..12
      Day: integer;                    // fixed date only
      Ordinal: TContestDateOrdinal;    // weekday / full weekend only
      Weekday: TContestDateWeekday;    // weekday only
   end;

   TContestDateEntry = record
      DateUTC: TDateTime;
      HasDate: boolean;
      Tag: NativeInt;
   end;
   TContestDateEntries = array of TContestDateEntry;

function TryContestDate(const aRule: TContestDateRule; aYear: integer;
                        out aDateUTC: TDateTime): boolean;
function TryNextContestDate(const aRule: TContestDateRule;
                            const aFromUTC: TDateTime;
                            out aDateUTC: TDateTime): boolean;
procedure SortContestDates(var aEntries: TContestDateEntries;
                            aAscending: boolean = True);

implementation

uses
   SysUtils, DateUtils, Math;

function RuleIsValid(const aRule: TContestDateRule): boolean;
var
   date: TDateTime;
begin
   Result := False;
   if (aRule.Month < 1) or (aRule.Month > 12) then
      begin
      Exit;
      end;
   case aRule.Kind of
      cdkFixedDate:
         begin
         (* Leap year accepts Feb 29 while rejecting impossible annual dates. *)
         Result := (aRule.Day >= 1) and (aRule.Day <= 31) and
                   TryEncodeDate(2000, aRule.Month, aRule.Day, date);
         end;
      cdkWeekday:
         begin
         Result := (aRule.Ordinal >= Low(TContestDateOrdinal)) and
                   (aRule.Ordinal <= High(TContestDateOrdinal)) and
                   (aRule.Weekday >= Low(TContestDateWeekday)) and
                   (aRule.Weekday <= High(TContestDateWeekday));
         end;
      cdkFullWeekend:
         begin
         Result := (aRule.Ordinal >= Low(TContestDateOrdinal)) and
                   (aRule.Ordinal <= High(TContestDateOrdinal));
         end;
   end;
end;

function TryContestDate(const aRule: TContestDateRule; aYear: integer;
                        out aDateUTC: TDateTime): boolean;
var
   first, candidate: TDateTime;
   lastDay, targetWeekday, day: integer;
begin
   Result := False;
   aDateUTC := 0;
   if not RuleIsValid(aRule) or (aYear < 1) or (aYear > 9999) then
      begin
      Exit;
      end;
   if aRule.Kind = cdkFixedDate then
      begin
      Result := TryEncodeDate(aYear, aRule.Month, aRule.Day, aDateUTC);
      Exit;
      end;

   first := EncodeDate(aYear, aRule.Month, 1);
   lastDay := DaysInAMonth(aYear, aRule.Month);
   if aRule.Kind = cdkFullWeekend then
      begin
      targetWeekday := 6; // DateUtils.DayOfTheWeek: Monday=1
      Dec(lastDay);      // latest Saturday must leave room for Sunday
      end
   else
      begin
      targetWeekday := Ord(aRule.Weekday) + 1;
      end;

   if aRule.Ordinal = cdoLast then
      begin
      candidate := first + lastDay - 1;
      day := lastDay - (DayOfTheWeek(candidate) - targetWeekday + 7) mod 7;
      end
   else
      begin
      day := 1 + (targetWeekday - DayOfTheWeek(first) + 7) mod 7 +
             7 * Ord(aRule.Ordinal);
      end;
   if day > lastDay then
      begin
      Exit;
      end;
   aDateUTC := first + day - 1;
   Result := True;
end;

function TryNextContestDate(const aRule: TContestDateRule;
                            const aFromUTC: TDateTime;
                            out aDateUTC: TDateTime): boolean;
var
   year, month, day: word;
   candidate, fromDate: TDateTime;
   candidateYear, finalYear: integer;
begin
   Result := False;
   aDateUTC := 0;
   if not RuleIsValid(aRule) or IsNan(aFromUTC) or IsInfinite(aFromUTC) then
      begin
      Exit;
      end;
   if (aFromUTC < EncodeDate(1, 1, 1)) or
      (aFromUTC >= EncodeDate(9999, 12, 31) + 1) then
      begin
      Exit;
      end;
   DecodeDate(aFromUTC, year, month, day);
   fromDate := EncodeDate(year, month, day);
   (* A Gregorian cycle covers every valid annual rule, including a fifth
      weekday and leap day. Stop at the representable calendar boundary. *)
   finalYear := year + 400;
   if finalYear > 9999 then
      begin
      finalYear := 9999;
      end;
   for candidateYear := year to finalYear do
      begin
      if TryContestDate(aRule, candidateYear, candidate) then
         begin
         if candidate >= fromDate then
            begin
            aDateUTC := candidate;
            Result := True;
            Exit;
            end;
         end;
      end;
end;

procedure SortContestDates(var aEntries: TContestDateEntries;
                            aAscending: boolean);
var
   scratch: TContestDateEntries;

   function LeftFirst(const aLeft, aRight: TContestDateEntry): boolean;
   begin
      if aLeft.HasDate <> aRight.HasDate then
         begin
         Result := aLeft.HasDate;
         end
      else if not aLeft.HasDate then
         begin
         Result := True;
         end
      else if aAscending then
         begin
         Result := aLeft.DateUTC <= aRight.DateUTC;
         end
      else
         begin
         Result := aLeft.DateUTC >= aRight.DateUTC;
         end;
   end;

   procedure MergeSort(aFirst, aLast: integer);
   var
      middle, left, right, dest: integer;
   begin
      if aFirst >= aLast then
         begin
         Exit;
         end;
      middle := aFirst + (aLast - aFirst) div 2;
      MergeSort(aFirst, middle);
      MergeSort(middle + 1, aLast);
      left := aFirst;
      right := middle + 1;
      for dest := aFirst to aLast do
         begin
         if (left <= middle) and
            ((right > aLast) or LeftFirst(aEntries[left], aEntries[right])) then
            begin
            scratch[dest] := aEntries[left];
            Inc(left);
            end
         else
            begin
            scratch[dest] := aEntries[right];
            Inc(right);
            end;
         end;
      for dest := aFirst to aLast do
         begin
         aEntries[dest] := scratch[dest];
         end;
   end;

begin
   if Length(aEntries) < 2 then
      begin
      Exit;
      end;
   SetLength(scratch, Length(aEntries));
   MergeSort(0, High(aEntries));
end;

end.
