unit uContestSchedule;

(* A CONTEST'S SCHEDULE STRING -- PARSED ONCE, RESOLVED AGAINST ONE "NOW".

   A LEAF. It knows no contest, registry, control, global or clock. A contest
   class states its schedule as a string (TContestBase.Schedule); the caller
   parses it here once and resolves it against ONE UTC instant it captured
   itself (uSpotAge.UTCNow, once per list), so a midnight or a period boundary
   can never split a list across two reference times.

   THE GRAMMAR (docs/CONTEST_SCHEDULES_README.md is the operator's statement,
   and uTestContestSchedule parses every example in it):

      schedule := 'unscheduled' | clause { ';' clause }
      clause   := anchor [ '+' N 'd' ] [ 'at' HH:MM 'UTC' 'for' DURATION ]
      anchor   := ORDINAL WEEKDAY ('of'|'in') MONTH
                | ORDINAL 'full' 'weekend' ('of'|'in') MONTH
                | ORDINAL WEEKDAY ('of'|'in') 'every' 'month'
                | ORDINAL 'full' 'weekend' ('of'|'in') 'every' 'month'
                | 'every' WEEKDAY
                | 'every' 'day'
                | MM-DD                    (every year)
                | YYYY-MM-DD               (that date only; a list runs out)
      ORDINAL  := 1st..5th | first..fifth | last
      DURATION := N 'h' | N 'm'

   Keywords and English month and day names are case-insensitive. Parsing is
   STRICT: one bad clause rejects the whole string, and the diagnostic names
   the clause (its number and its text). An empty string, a blank clause and
   'unscheduled' beside a clause are errors -- 'unscheduled' is a deliberate
   whole-string statement, never what a missing value falls back to.

   '+Nd' MOVES THE PERIOD N DAYS AFTER THE SAME ANCHOR DATE. "4th Saturday of
   April +1d" is the Sunday after that Saturday -- never an independent
   "4th Sunday", which is a week earlier when April starts on a Sunday (2029).

   A CLAUSE WITHOUT 'at ... for ...' IS A DATE-ONLY HINT covering its whole
   UTC day, as uContestDates does. A timed clause is the period
   [start, start + duration). Each clause is a separate period: a QSO party's
   Saturday and Sunday are two clauses, and nothing here joins them.

   THE SORT KEY (TryScheduleSortKey): over every clause, the earliest period
   that is RUNNING at "now" or still to come. A running period's key is "now"
   itself, so a contest on the air sorts first; in a QSO party's overnight gap
   the key is the next period's start; after the last period of a finite
   date list there is no key (undated, sorted last by SortContestDates).

   ARITHMETIC: every calendar question goes to uContestDates (TryContestDate,
   TryNextContestDate); this unit adds only offsets, clock times and the
   weekly and daily walks, which uContestDates has no form for. Instants are
   built as a date plus EncodeTime, so they equal EncodeDateTime exactly and
   the [start, end) boundaries compare without floating-point drift.

   RECORDS, NOT CLASSES, ON PURPOSE: these are values the caller copies into
   its own list beside its own metadata -- no owner, nothing to free -- the
   shape uContestDates' TContestDateRule and TContestDateEntry already have. *)

{$I tr4w.inc}

interface

uses
   uContestDates;

const
   (* THE WHOLE-STRING STATEMENT "THIS CONTEST HAS NO CALENDAR" (General QSO,
      POTA). Matched case-insensitively, after trimming. *)
   SCHEDULE_UNSCHEDULED = 'unscheduled';

type
   TScheduleAnchorKind = (
      sakAnnual,     (* nth weekday / full weekend of a month, or MM-DD *)
      sakMonthly,    (* nth weekday / full weekend of every month *)
      sakWeekly,     (* every <weekday> *)
      sakDaily,      (* every day *)
      sakDate);      (* one ISO date *)

   TScheduleClause = record
      Text: string;                 (* the clause as written, for diagnostics *)
      Anchor: TScheduleAnchorKind;
      Rule: TContestDateRule;       (* sakAnnual, sakMonthly (Month ignored) *)
      Weekday: TContestDateWeekday; (* sakWeekly *)
      Date: TDateTime;              (* sakDate, midnight UTC *)
      DayOffset: integer;           (* the '+Nd', 0 when absent *)
      HasWindow: boolean;           (* False: a date-only hint, the whole day *)
      StartMinute: integer;         (* minutes after 00:00 UTC *)
      DurationMinutes: integer;
   end;
   TScheduleClauses = array of TScheduleClause;

   TContestSchedule = record
      Unscheduled: boolean;         (* the deliberate 'unscheduled' *)
      Clauses: TScheduleClauses;    (* empty when Unscheduled *)
   end;

(* ONE STRING -> TYPED CLAUSES. False with aError naming the clause. *)
function TryParseContestSchedule(const aText: string;
                                 out aSchedule: TContestSchedule;
                                 out aError: string): boolean;

(* THE CLAUSE'S FIRST PERIOD WHOSE END IS AFTER aNowUTC -- running or to
   come. False when it has none (a past ISO date). *)
function TryNextSchedulePeriod(const aClause: TScheduleClause;
                               const aNowUTC: TDateTime;
                               out aStartUTC, aEndUTC: TDateTime): boolean;

(* THE SORT KEY: aNowUTC when a period is running, else the soonest start.
   False when no clause has a period to come (undated). *)
function TryScheduleSortKey(const aSchedule: TContestSchedule;
                            const aNowUTC: TDateTime;
                            out aKeyUTC: TDateTime): boolean;

(* THE PERIOD THE SORT KEY CAME FROM, for a caller that SHOWS it (the New
   Contest dialog's "Upcoming contests first" hint). False exactly when
   TryScheduleSortKey is. aRunning: the period has begun at aNowUTC.
   aTimed: the winning clause states 'at ... for ...'; a date-only hint
   starts at midnight UTC by construction, and that midnight is not a start
   time anyone should be shown. The key is aNowUTC when aRunning, else
   aStartUTC -- TryScheduleSortKey is this, reduced to the key. *)
function TryScheduleNextPeriod(const aSchedule: TContestSchedule;
                               const aNowUTC: TDateTime;
                               out aStartUTC: TDateTime;
                               out aRunning, aTimed: boolean): boolean;

(* THE ENTRY uContestDates.SortContestDates orders, carrying the caller's tag. *)
function ScheduleDateEntry(const aSchedule: TContestSchedule;
                           const aNowUTC: TDateTime;
                           aTag: NativeInt): TContestDateEntry;

implementation

uses
   SysUtils, DateUtils, Math;

type
   (* Not Types.TStringArray: its elements are AnsiString, so every word stored
     in it narrowed from this unit's UnicodeString (the build's ratcheted
     narrowing count caught four). *)
   TScheduleWords = array of string;

const
   MAX_DAY_OFFSET = 31;
   MAX_DURATION_MINUTES = 7 * 24 * 60;
   MINUTES_PER_DAY = 24 * 60;

   MONTH_NAMES: array[1..12] of string = (
      'january', 'february', 'march', 'april', 'may', 'june', 'july',
      'august', 'september', 'october', 'november', 'december');

   WEEKDAY_NAMES: array[TContestDateWeekday] of string = (
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
      'sunday');

   NUMERIC_ORDINALS: array[cdoFirst..cdoFifth] of string = (
      '1st', '2nd', '3rd', '4th', '5th');

   WORD_ORDINALS: array[cdoFirst..cdoFifth] of string = (
      'first', 'second', 'third', 'fourth', 'fifth');

(* ------------------------------------------------------------------------ *)
(* Tokens *)

(* Whitespace-separated words, lower-cased. *)
function SplitWords(const aText: string): TScheduleWords;
var
   i: integer;
   word: string;
   count: integer;
begin
   Result := nil;
   count := 0;
   word := '';
   for i := 1 to Length(aText) + 1 do
      begin
      if (i > Length(aText)) or (aText[i] <= ' ') then
         begin
         if word <> '' then
            begin
            SetLength(Result, count + 1);
            Result[count] := UnicodeLowerCase(word);
            Inc(count);
            word := '';
            end;
         end
      else
         begin
         word := word + aText[i];
         end;
      end;
end;

(* The ';'-separated pieces, untrimmed; 'a;' gives 'a' and '' -- a trailing
   separator is a blank clause, which the caller refuses. *)
function SplitOnSemicolons(const aText: string): TScheduleWords;
var
   i: integer;
   start: integer;
   count: integer;
begin
   Result := nil;
   count := 0;
   start := 1;
   for i := 1 to Length(aText) + 1 do
      begin
      if (i > Length(aText)) or (aText[i] = ';') then
         begin
         SetLength(Result, count + 1);
         Result[count] := Copy(aText, start, i - start);
         Inc(count);
         start := i + 1;
         end;
      end;
end;

(* EXACTLY aLength ASCII DIGITS (aLength 0: one to four). No sign, no blank,
   no hex -- what TryStrToInt would also accept is refused here. *)
function TryDigits(const aText: string; aLength: integer; out aValue: integer): boolean;
var
   i: integer;
begin
   Result := False;
   aValue := 0;
   if aText = '' then
      begin
      Exit;
      end;
   if (aLength > 0) and (Length(aText) <> aLength) then
      begin
      Exit;
      end;
   if (aLength = 0) and (Length(aText) > 4) then
      begin
      Exit;
      end;
   for i := 1 to Length(aText) do
      begin
      if (aText[i] < '0') or (aText[i] > '9') then
         begin
         aValue := 0;
         Exit;
         end;
      aValue := aValue * 10 + (Ord(aText[i]) - Ord('0'));
      end;
   Result := True;
end;

function TryOrdinal(const aWord: string; out aOrdinal: TContestDateOrdinal): boolean;
var
   o: TContestDateOrdinal;
begin
   Result := True;
   if aWord = 'last' then
      begin
      aOrdinal := cdoLast;
      Exit;
      end;
   for o := cdoFirst to cdoFifth do
      begin
      if (aWord = NUMERIC_ORDINALS[o]) or (aWord = WORD_ORDINALS[o]) then
         begin
         aOrdinal := o;
         Exit;
         end;
      end;
   aOrdinal := cdoFirst;
   Result := False;
end;

function TryWeekday(const aWord: string; out aWeekday: TContestDateWeekday): boolean;
var
   w: TContestDateWeekday;
begin
   for w := Low(TContestDateWeekday) to High(TContestDateWeekday) do
      begin
      if aWord = WEEKDAY_NAMES[w] then
         begin
         aWeekday := w;
         Result := True;
         Exit;
         end;
      end;
   aWeekday := cdwMonday;
   Result := False;
end;

function TryMonth(const aWord: string; out aMonth: integer): boolean;
var
   m: integer;
begin
   for m := 1 to 12 do
      begin
      if aWord = MONTH_NAMES[m] then
         begin
         aMonth := m;
         Result := True;
         Exit;
         end;
      end;
   aMonth := 0;
   Result := False;
end;

(* ------------------------------------------------------------------------ *)
(* One clause *)

function TryParseClause(const aText: string; out aClause: TScheduleClause;
                        out aReason: string): boolean;
var
   words: TScheduleWords;
   p: integer;
   n: integer;
   year, month, day: integer;
   hh, mm: integer;
   check: TDateTime;
   w: string;

   function More: boolean;
   begin
      Result := p <= High(words);
   end;

   function Next: string;
   begin
      if More then
         begin
         Result := words[p];
         Inc(p);
         end
      else
         begin
         Result := '';
         end;
   end;

   (* 'of' or 'in', then a month name or 'every month'. *)
   function ParseMonthPart: boolean;
   begin
      Result := False;
      w := Next;
      if (w <> 'of') and (w <> 'in') then
         begin
         aReason := 'expected "of" or "in", found "' + w + '"';
         Exit;
         end;
      w := Next;
      if w = 'every' then
         begin
         w := Next;
         if w <> 'month' then
            begin
            aReason := 'expected "every month", found "every ' + w + '"';
            Exit;
            end;
         aClause.Anchor := sakMonthly;
         aClause.Rule.Month := 1;
         Result := True;
         Exit;
         end;
      if not TryMonth(w, aClause.Rule.Month) then
         begin
         aReason := 'unknown month "' + w + '"';
         Exit;
         end;
      aClause.Anchor := sakAnnual;
      Result := True;
   end;

begin
   Result := False;
   aReason := '';
   aClause := Default(TScheduleClause);
   aClause.Text := aText;
   aClause.Rule.Day := 0;
   aClause.Rule.Weekday := cdwSaturday;
   words := SplitWords(aText);
   p := 0;
   if Length(words) = 0 then
      begin
      aReason := 'empty clause';
      Exit;
      end;

   (* THE ANCHOR *)
   w := Next;
   if w = 'every' then
      begin
      w := Next;
      if w = 'day' then
         begin
         aClause.Anchor := sakDaily;
         end
      else if TryWeekday(w, aClause.Weekday) then
         begin
         aClause.Anchor := sakWeekly;
         end
      else
         begin
         aReason := 'expected a weekday or "day" after "every", found "' + w + '"';
         Exit;
         end;
      end
   else if TryOrdinal(w, aClause.Rule.Ordinal) then
      begin
      w := Next;
      if w = 'full' then
         begin
         w := Next;
         if w <> 'weekend' then
            begin
            aReason := 'expected "full weekend", found "full ' + w + '"';
            Exit;
            end;
         aClause.Rule.Kind := cdkFullWeekend;
         end
      else if TryWeekday(w, aClause.Rule.Weekday) then
         begin
         aClause.Rule.Kind := cdkWeekday;
         end
      else
         begin
         aReason := 'expected a weekday or "full weekend" after the ordinal, found "' + w + '"';
         Exit;
         end;
      if not ParseMonthPart then
         begin
         Exit;
         end;
      end
   else if (Length(w) = 10) and (w[5] = '-') and (w[8] = '-') then
      begin
      if not (TryDigits(Copy(w, 1, 4), 4, year) and
              TryDigits(Copy(w, 6, 2), 2, month) and
              TryDigits(Copy(w, 9, 2), 2, day)) or
         (year < 1) or
         not TryEncodeDate(year, month, day, aClause.Date) then
         begin
         aReason := 'not a valid YYYY-MM-DD date "' + w + '"';
         Exit;
         end;
      aClause.Anchor := sakDate;
      end
   else if (Length(w) = 5) and (w[3] = '-') then
      begin
      aClause.Anchor := sakAnnual;
      aClause.Rule.Kind := cdkFixedDate;
      (* A LEAP YEAR, so 02-29 is a real annual date; TryContestDate is the
         one judge of what a fixed date may be. *)
      if not (TryDigits(Copy(w, 1, 2), 2, aClause.Rule.Month) and
              TryDigits(Copy(w, 4, 2), 2, aClause.Rule.Day)) or
         not TryContestDate(aClause.Rule, 2000, check) then
         begin
         aReason := 'not a valid MM-DD date "' + w + '"';
         Exit;
         end;
      end
   else
      begin
      aReason := 'expected an ordinal, "every", MM-DD or YYYY-MM-DD, found "' + w + '"';
      Exit;
      end;

   (* THE OFFSET *)
   if More and (Length(words[p]) >= 3) and (words[p][1] = '+') and
      (words[p][Length(words[p])] = 'd') then
      begin
      w := Next;
      if not TryDigits(Copy(w, 2, Length(w) - 2), 0, n) or
         (n < 1) or (n > MAX_DAY_OFFSET) then
         begin
         aReason := 'day offset "' + w + '" must be +1d to +' + IntToStr(MAX_DAY_OFFSET) + 'd';
         Exit;
         end;
      aClause.DayOffset := n;
      end;

   (* THE WINDOW *)
   if More then
      begin
      w := Next;
      if w <> 'at' then
         begin
         aReason := 'expected "at HH:MM UTC for ..." or the end of the clause, found "' + w + '"';
         Exit;
         end;
      w := Next;
      if not ((Length(w) = 5) and (w[3] = ':') and
              TryDigits(Copy(w, 1, 2), 2, hh) and
              TryDigits(Copy(w, 4, 2), 2, mm) and
              (hh <= 23) and (mm <= 59)) then
         begin
         aReason := 'not a valid HH:MM time "' + w + '"';
         Exit;
         end;
      aClause.StartMinute := hh * 60 + mm;
      w := Next;
      if w <> 'utc' then
         begin
         aReason := 'expected "UTC" after the time, found "' + w + '"';
         Exit;
         end;
      w := Next;
      if w <> 'for' then
         begin
         aReason := 'expected "for" and a duration, found "' + w + '"';
         Exit;
         end;
      w := Next;
      if (Length(w) >= 2) and
         ((w[Length(w)] = 'h') or (w[Length(w)] = 'm')) and
         TryDigits(Copy(w, 1, Length(w) - 1), 0, n) then
         begin
         if w[Length(w)] = 'h' then
            begin
            n := n * 60;
            end;
         end
      else
         begin
         aReason := 'not a valid duration "' + w + '" (Nh or Nm)';
         Exit;
         end;
      if (n < 1) or (n > MAX_DURATION_MINUTES) then
         begin
         aReason := 'duration "' + w + '" must be more than zero and at most 168h';
         Exit;
         end;
      aClause.DurationMinutes := n;
      aClause.HasWindow := True;
      if More then
         begin
         aReason := 'unexpected "' + words[p] + '" after the duration';
         Exit;
         end;
      end;
   Result := True;
end;

function TryParseContestSchedule(const aText: string;
                                 out aSchedule: TContestSchedule;
                                 out aError: string): boolean;
var
   parts: TScheduleWords;
   i: integer;
   clauseText: string;
   reason: string;
begin
   Result := False;
   aError := '';
   aSchedule.Unscheduled := False;
   aSchedule.Clauses := nil;
   if Trim(aText) = '' then
      begin
      aError := 'empty schedule (nothing stated)';
      Exit;
      end;
   if UnicodeLowerCase(Trim(aText)) = SCHEDULE_UNSCHEDULED then
      begin
      aSchedule.Unscheduled := True;
      Result := True;
      Exit;
      end;
   parts := SplitOnSemicolons(aText);
   SetLength(aSchedule.Clauses, Length(parts));
   for i := 0 to High(parts) do
      begin
      clauseText := Trim(parts[i]);
      reason := '';
      if UnicodeLowerCase(clauseText) = SCHEDULE_UNSCHEDULED then
         begin
         reason := '"unscheduled" is a whole-string statement, not a clause';
         end
      else if (not TryParseClause(clauseText, aSchedule.Clauses[i], reason)) and
              (reason = '') then
         begin
         reason := 'not a valid clause';
         end;
      if reason <> '' then
         begin
         aError := Format('clause %d "%s": %s', [i + 1, clauseText, reason]);
         aSchedule.Clauses := nil;
         Exit;
         end;
      end;
   Result := True;
end;

(* ------------------------------------------------------------------------ *)
(* Resolution *)

(* THE PERIOD WHOSE ANCHOR DATE IS aAnchorDay (midnight UTC). *)
procedure PeriodOf(const aClause: TScheduleClause; aAnchorDay: TDateTime;
                   out aStartUTC, aEndUTC: TDateTime);
var
   endMinute: integer;
   day: TDateTime;
begin
   day := aAnchorDay + aClause.DayOffset;
   if not aClause.HasWindow then
      begin
      aStartUTC := day;
      aEndUTC := day + 1;
      Exit;
      end;
   aStartUTC := day + EncodeTime(aClause.StartMinute div 60, aClause.StartMinute mod 60, 0, 0);
   endMinute := aClause.StartMinute + aClause.DurationMinutes;
   aEndUTC := day + (endMinute div MINUTES_PER_DAY) +
              EncodeTime((endMinute mod MINUTES_PER_DAY) div 60, endMinute mod 60, 0, 0);
end;

(* HOW MANY DAYS BEFORE "NOW" AN ANCHOR CAN LIE AND ITS PERIOD STILL RUN. *)
function LookbackDays(const aClause: TScheduleClause): integer;
var
   minutes: integer;
begin
   minutes := MINUTES_PER_DAY;
   if aClause.HasWindow then
      begin
      minutes := aClause.StartMinute + aClause.DurationMinutes;
      end;
   Result := aClause.DayOffset + minutes div MINUTES_PER_DAY + 2;
end;

function TryNextSchedulePeriod(const aClause: TScheduleClause;
                               const aNowUTC: TDateTime;
                               out aStartUTC, aEndUTC: TDateTime): boolean;
var
   from: TDateTime;
   anchor: TDateTime;
   lookback: integer;
   k: integer;
   year, month, day: word;
   y, m: integer;
   rule: TContestDateRule;
   guard: integer;
begin
   Result := False;
   aStartUTC := 0;
   aEndUTC := 0;
   if IsNan(aNowUTC) or IsInfinite(aNowUTC) or
      (aNowUTC < EncodeDate(1, 1, 1) + 40) or (aNowUTC >= EncodeDate(9999, 1, 1)) then
      begin
      Exit;
      end;
   lookback := LookbackDays(aClause);
   from := Trunc(aNowUTC) - lookback;
   case aClause.Anchor of
      sakDate:
         begin
         PeriodOf(aClause, aClause.Date, aStartUTC, aEndUTC);
         Result := aEndUTC > aNowUTC;
         end;

      sakAnnual:
         begin
         (* ONE OCCURRENCE AT A TIME, FROM FAR ENOUGH BACK THAT A PERIOD
            WHICH BEGAN BEFORE TODAY (Sunday of a 48h weekend, a +1d
            period) IS STILL SEEN RUNNING. *)
         guard := 0;
         while (guard < 1000) and TryNextContestDate(aClause.Rule, from, anchor) do
            begin
            PeriodOf(aClause, anchor, aStartUTC, aEndUTC);
            if aEndUTC > aNowUTC then
               begin
               Result := True;
               Exit;
               end;
            from := anchor + 1;
            Inc(guard);
            end;
         end;

      sakMonthly:
         begin
         DecodeDate(from, year, month, day);
         y := year;
         m := month;
         rule := aClause.Rule;
         (* A FIFTH WEEKDAY IS ABSENT FROM MOST MONTHS; ten years of months
            always holds one. *)
         for guard := 0 to 12 * 10 do
            begin
            rule.Month := m;
            if TryContestDate(rule, y, anchor) then
               begin
               PeriodOf(aClause, anchor, aStartUTC, aEndUTC);
               if aEndUTC > aNowUTC then
                  begin
                  Result := True;
                  Exit;
                  end;
               end;
            Inc(m);
            if m > 12 then
               begin
               m := 1;
               Inc(y);
               end;
            end;
         end;

      sakWeekly, sakDaily:
         begin
         for k := 0 to lookback + 8 do
            begin
            anchor := from + k;
            if (aClause.Anchor = sakDaily) or
               (DayOfTheWeek(anchor) = Ord(aClause.Weekday) + 1) then
               begin
               PeriodOf(aClause, anchor, aStartUTC, aEndUTC);
               if aEndUTC > aNowUTC then
                  begin
                  Result := True;
                  Exit;
                  end;
               end;
            end;
         end;
   end;
   if not Result then
      begin
      aStartUTC := 0;
      aEndUTC := 0;
      end;
end;

function TryScheduleNextPeriod(const aSchedule: TContestSchedule;
                               const aNowUTC: TDateTime;
                               out aStartUTC: TDateTime;
                               out aRunning, aTimed: boolean): boolean;
var
   i: integer;
   startUTC, endUTC: TDateTime;
   key, bestKey: TDateTime;
begin
   Result := False;
   aStartUTC := 0;
   aRunning := False;
   aTimed := False;
   bestKey := 0;
   if aSchedule.Unscheduled then
      begin
      Exit;
      end;
   for i := 0 to High(aSchedule.Clauses) do
      begin
      if TryNextSchedulePeriod(aSchedule.Clauses[i], aNowUTC, startUTC, endUTC) then
         begin
         if startUTC <= aNowUTC then
            begin
            key := aNowUTC;
            end
         else
            begin
            key := startUTC;
            end;
         (* STRICTLY EARLIER: on a tie the first clause stated wins, as it
            always has. *)
         if (not Result) or (key < bestKey) then
            begin
            bestKey := key;
            aStartUTC := startUTC;
            aRunning := startUTC <= aNowUTC;
            aTimed := aSchedule.Clauses[i].HasWindow;
            Result := True;
            end;
         end;
      end;
end;

function TryScheduleSortKey(const aSchedule: TContestSchedule;
                            const aNowUTC: TDateTime;
                            out aKeyUTC: TDateTime): boolean;
var
   startUTC: TDateTime;
   running, timed: boolean;
begin
   aKeyUTC := 0;
   Result := TryScheduleNextPeriod(aSchedule, aNowUTC, startUTC, running, timed);
   if Result then
      begin
      if running then
         begin
         aKeyUTC := aNowUTC;
         end
      else
         begin
         aKeyUTC := startUTC;
         end;
      end;
end;

function ScheduleDateEntry(const aSchedule: TContestSchedule;
                           const aNowUTC: TDateTime;
                           aTag: NativeInt): TContestDateEntry;
begin
   Result.Tag := aTag;
   Result.HasDate := TryScheduleSortKey(aSchedule, aNowUTC, Result.DateUTC);
end;

end.
