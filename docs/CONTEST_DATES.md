# Contest date calculation and ordering

`tr4w/src/uContestDates.pas` is a leaf unit for calendar arithmetic and stable
date ordering. It contains no contest identities, schedule tables, registry or
UI dependencies. Contest classes own their schedules; the caller supplies the
rules and an explicit UTC reference. This is the calendar half of design Q99.

The schedule layer above it is `tr4w/src/uContestSchedule.pas`, also a leaf:
it parses the string a contest class states (`TContestBase.Schedule`, a
`GetSchedule` override) into typed clauses and resolves them against one UTC
"now". The grammar is in [CONTEST_SCHEDULES_README.md](CONTEST_SCHEDULES_README.md);
how a new contest states its schedule is in
[ADDING_A_CONTEST.md](ADDING_A_CONTEST.md).

## Data flow

1. A contest class states its schedule string. `uContestSchedule.TryParseContestSchedule`
   turns it into `TScheduleClause` values once; an annual clause carries a
   `TContestDateRule` (fixed month/day, nth weekday, or nth full weekend).
2. `TryContestDate` resolves a rule in a specified year. `TryNextContestDate`
   resolves the earliest occurrence on or after the reference UTC date.
   `uContestSchedule` calls both; it never repeats their arithmetic.
3. The caller captures `uSpotAge.UTCNow` ONCE for the whole list and asks
   `uContestSchedule.ScheduleDateEntry` for each contest: the key is "now" for a
   contest whose period is running, else the soonest period start, else no date.
4. `SortContestDates(entries)` sorts in place ascending; pass `False` for
   descending. Equal dates retain input order, preserving alphabetical ties
   when that is the input order. Undated entries remain last in both directions.
5. The dialog follows the sorted tags to recover its own labels and objects.

## The New Contest dialog's "Upcoming contests first" (Q99 step B)

`uContestChoices.SoonestFirstOrder` is steps 3 and 4 for the New Contest
list, and stays pure (no LCL). `TContestChoices.Create` passes it every contest's
schedule string, in the list's alphabetical order. It reads `UTCNow` once, and a
test can pass a fixed "now" instead. A contest that cannot be started (inactive)
is never dated, so it stays last. Each string is parsed once:

- `''` (not yet stated), `'unscheduled'` and a run-out date list are undated,
  silently.
- A string that does not parse is undated, and its error comes back per entry.
  The form logs each one once, as a `logger.Warn` naming the contest id.

`uContestSchedule.TryScheduleNextPeriod` is the sort key's period with two
flags: whether it is running, and whether its clause is timed. The hint text
comes from those flags (`ContestDateHint`):

- `running now` (a resourcestring) for a running contest.
- Otherwise `YYYY-MM-DD HH:MM UTC`.
- Just `YYYY-MM-DD` for a date-only clause, whose midnight is not a start
  time.

The hint is built from the numbers, so it reads the same in every locale. It
is added to the row text only (`ContestChoiceDisplay`). The search still
matches the caption, and the row's identity is still `TfrmNewContest.FShown`.
The tick is remembered for the session (`uNewContestForm.GSoonestFirst`), not
stored. The dialog runs before the settings load, so a stored setting would
need its own read and write path before that load. Tests:
`uTestNewContestForm`, `Test_SoonestFirst*` and `Test_TheUpcomingBox*`.

## Contracts and boundaries

- `TDateTime` carries no timezone: every date/time passed here must already
  represent UTC. Calculated dates are midnight UTC. Neither unit reads a clock
  nor applies the machine's local timezone.
- Today is included for the entire UTC day. This intentionally differs from
  TR4QT's strictly-future date lookup. Operating periods, and whether a contest
  is still running after midnight, are `uContestSchedule`'s `[start, end)`
  periods.
- First through fifth and last occurrences are supported. Full weekends
  require both Saturday and Sunday within the month. Last Saturday can instead
  be stated as a weekday rule, allowing Sunday in the next month.
- A missing fifth occurrence fails for that year; it never falls back to the
  fourth. Next-date lookup skips years where the occurrence is absent. Feb 29
  also skips nonleap years, including nonleap centuries.
- Invalid rules or reference values return `False` and clear the output date.
  Supported years are 1 through 9999. Lookup is bounded by a Gregorian cycle
  and by year 9999. A date of zero is not a failure sentinel: use the Boolean.
- Sorting requires finite valid dates for `HasDate=True`. Undated entries'
  date fields are ignored. Sorting compares the full timestamp, so callers
  supplying actual UTC starts can order contests within a day as well.
- Stable merge sort takes O(n log n) comparisons, O(n) temporary storage and
  O(log n) recursion. It uses one temporary array and reads no application state.
  Work on separate arrays is independent; callers synchronize shared mutation.
- No schedule restricts opening a contest or logging a QSO.

`uTestContestDates` covers the full Gregorian 400-year cycle for weekend rules,
individual weekday numbering, UTC date boundaries, leap-day lookup,
invalid/missing dates, and stable ordering. `uTestContestSchedule` covers the
grammar, the resolver, every class's stated schedule and the ordering.
