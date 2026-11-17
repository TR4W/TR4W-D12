# CONTEST_SCHEDULES.csv -- schedule intake for agents

## How do I enter...

Type the left-hand form into the `schedule` cell -- start and end the way the
sponsor's page shows them. An agent converts it
(`tools/contest-schedules/convert_sponsor_times.py`) into the right-hand form,
which is what the contest class carries. Where the two are the same, type
either. `;` ALWAYS means "another period": each period is listed on its own,
and the New Contest sort uses the soonest one that is running or still to
come. Nothing here stops a contest being opened or a QSO being logged.

The table is checked by the unit tests (`uTestContestSchedule` parses every
right-hand cell) and by `tools/contest-schedules/test_convert_sponsor_times.py`
(every left-hand cell must convert to its right-hand cell), so it cannot drift
from the grammar.

<!-- schedule-examples-begin -->
| I want to enter | Type this (sponsor style) | The class carries |
|---|---|---|
| one period on one weekend (California) | `1st full weekend of October at 16:00 UTC until Sunday 21:59 UTC` | `1st full weekend of October at 16:00 UTC for 30h` |
| a 48-hour weekend (CQ WPX SSB) | `last full weekend of March at 00:00 UTC until Sunday 23:59 UTC` | `last full weekend of March at 00:00 UTC for 48h` |
| two periods in one weekend (Florida) | `4th Saturday of April at 16:00 UTC until Sunday 01:59 UTC; 4th Saturday of April +1d at 12:00 UTC until 21:59 UTC` | `4th Saturday of April at 16:00 UTC for 10h; 4th Saturday of April +1d at 12:00 UTC for 10h` |
| two periods, full-weekend anchor (Georgia) | `2nd full weekend of April at 18:00 UTC until Sunday 03:59 UTC; 2nd full weekend of April +1d at 14:00 UTC until 23:59 UTC` | `2nd full weekend of April at 18:00 UTC for 10h; 2nd full weekend of April +1d at 14:00 UTC for 10h` |
| three periods (Makrothen) | `2nd Saturday of October at 00:00 UTC until 07:59 UTC; 2nd Saturday of October at 16:00 UTC until 23:59 UTC; 2nd Saturday of October +1d at 08:00 UTC until 15:59 UTC` | `2nd Saturday of October at 00:00 UTC for 8h; 2nd Saturday of October at 16:00 UTC for 8h; 2nd Saturday of October +1d at 08:00 UTC for 8h` |
| the same contest twice a year (NAQP SSB) | `3rd full weekend of January at 18:00 UTC until 05:59 UTC; 3rd full weekend of August at 18:00 UTC until 05:59 UTC` | `3rd full weekend of January at 18:00 UTC for 12h; 3rd full weekend of August at 18:00 UTC for 12h` |
| weekly, on one day | `every Wednesday at 02:30 UTC until 03:00 UTC` | `every Wednesday at 02:30 UTC for 30m` |
| several sessions a week, two on one day (CWT) | `every Wednesday at 13:00 UTC until 14:00 UTC; every Wednesday at 19:00 UTC until 20:00 UTC; every Thursday at 03:00 UTC until 04:00 UTC; every Thursday at 07:00 UTC until 08:00 UTC` | `every Wednesday at 13:00 UTC for 1h; every Wednesday at 19:00 UTC for 1h; every Thursday at 03:00 UTC for 1h; every Thursday at 07:00 UTC for 1h` |
| monthly (no contest in the CSV uses it yet) | `1st Sunday of every month at 18:00 UTC until 19:59 UTC` | `1st Sunday of every month at 18:00 UTC for 2h` |
| monthly, the last one | `last Thursday of every month at 19:00 UTC until 20:30 UTC` | `last Thursday of every month at 19:00 UTC for 90m` |
| every day (none in the CSV yet) | `every day at 12:00 UTC until 13:00 UTC` | `every day at 12:00 UTC for 1h` |
| the same calendar date every year (Canada Day) | `07-01 at 00:00 UTC until 23:59 UTC` | `07-01 at 00:00 UTC for 24h` |
| published dates with no rule (SSB Sprint) | `2026-11-01 at 00:00 UTC until 03:59 UTC; 2027-03-21 at 00:00 UTC until 03:59 UTC` | `2026-11-01 at 00:00 UTC for 4h; 2027-03-21 at 00:00 UTC for 4h` |
| only the date is known, not the times | `4th Saturday of April` | `4th Saturday of April` |
| no schedule at all (General QSO, POTA) | `unscheduled` | `unscheduled` |
| I do not know yet | leave `schedule` empty; status `pending` or `hold` | (nothing: the class states no schedule) |
<!-- schedule-examples-end -->

Notes on the table:

- **`+1d` is the day after the SAME anchor.** `4th Saturday of April +1d` is the
  Sunday after that Saturday -- in 2029 that is April 29, while "4th Sunday of
  April" would be April 22. Use `+2d` for a third day. Write each period as its
  own clause; never one long period across the overnight break.
- **A `:59` end is the last included minute.** Type what the sponsor shows:
  `until 01:59 UTC` means the period ends at 02:00, `until Sunday 23:59 UTC`
  at Monday 00:00.
- **The end** is the first moment after the start that matches `until`. With
  no weekday it is the next time the clock reads that time (16:00 until 02:00
  crosses midnight). With a weekday it is that weekday on or after the start
  day. A weekday end needs an anchor that fixes the start's weekday, so
  `07-01` and `every day` take only the plain `until HH:MM UTC`.
- **Published dates run out.** An ISO-date list (`2026-11-01 ...`) is never
  repeated: after its last date the contest has no upcoming date and sorts
  last until someone adds the next year's dates.
- Without `at ...` a clause is a date-only hint: the whole UTC day.

### Not supported yet

Say so in `notes` and leave the row `pending` rather than bending a rule to
fit. None of these has syntax today:

- every other week, or "the 1st and 3rd Wednesday" (write two monthly clauses
  for the second: `1st Wednesday of every month ...; 3rd Wednesday of every
  month ...`);
- a weekday relative to a fixed date: "the Saturday on or before June 20"
  (West Virginia; today ISO dates). (North Carolina's "Sunday after
  February's 4th Saturday" IS expressible: `4th Saturday of February +1d`.);
- a day BEFORE the anchor: "the Friday before the first full weekend" (ARRL
  160, 2200Z Friday) -- there is `+Nd` but no `-Nd`. ARRL-160's row keeps
  `First full weekend in December at 22:00 UTC for 42h`, which reads from
  SATURDAY 2200Z; its notes say so;
- a date range or season ("all of January", "every Monday from October to
  March", a contest that runs all month);
- "third or fourth" or any other either-or rule (ARRL January VHF);
- a weekly series with known gaps (a cancelled week is still listed).

`CONTEST_SCHEDULES.csv` is an **intake file only**. NY4I edits it in a
spreadsheet to hand contest schedule updates to agents. The contest classes keep
owning the schedule string (`GetSchedule`; the parser is `tr4w/src/uContestSchedule.pas`,
the class step is `docs/ADDING_A_CONTEST.md` A3);
nothing reads the CSV at run time and it is not shipped.

## Columns

| column | meaning |
|---|---|
| `contest_id` | the registry id (`ContestTypeSA` spelling, or the `RegisterContestById` id) |
| `contest_name` | the display name the New Contest dialog shows |
| `mode_variant` | CW / SSB / Phone / RTTY / DIG / mixed; one row per mode when one class covers runnings on different dates (Region 1 Field Day) |
| `schedule` | the schedule string, in the grammar below; empty for `pending` and `hold` |
| `status` | see below |
| `rules_url` | the sponsor rules page the schedule was checked against |
| `rules_year` | the rule year checked |
| `notes` | source of a candidate, the disagreement behind a hold, anything else |

Rows are sorted by `contest_id`.

## Status values

- `verified` -- confirmed by NY4I or against the sponsor's rules; apply it.
- `candidate` -- copied from another program's source (`notes` names it); not yet confirmed.
- `hold` -- sources disagree or a question is open; `schedule` is empty and `notes` carries the candidates and the disagreement.
- `pending` -- no data yet.
- `unscheduled` -- deliberately undated (General QSO, POTA); `schedule` says `unscheduled`. Never use it for an unresearched contest.

## Grammar

The program's parser is `tr4w/src/uContestSchedule.pas`; its header is the
authoritative statement. In short:

- One string per row; `;` separates periods (clauses).
- Date anchor: `4th full weekend of June`, `last Saturday of February`
  (`of` or `in`), `1st Sunday of every month`, `last full weekend of every
  month`, `every Wednesday`, `every day`, `06-27` (every year), `2027-03-21`
  (that day only).
- `+Nd` after ANY anchor (1 to 31): N days after that same anchor date.
- Optional window, in the class: `at HH:MM UTC for Nh` or `for Nm` (at most
  168h); without it the clause is a date-only hint covering the UTC day. In
  the CSV cell you may instead type `at HH:MM UTC until [Weekday] HH:MM UTC`
  (sponsor style, see the table above); the converter turns it into `for`.
- Ordinals `1st`-`5th` (or `first`-`fifth`) and `last`; keywords and English
  month and day names are case insensitive, written in full.
- `unscheduled` is a whole-string value (no other clause beside it).
- Parsing is strict: one bad clause rejects the whole string, and the message
  names the clause.

## Converting sponsor-style cells

```
python -I tools/contest-schedules/convert_sponsor_times.py --check
python -I tools/contest-schedules/convert_sponsor_times.py --write
```

`--check` lists every row whose cell holds `until`, with its converted form or
an error naming the contest id and clause; `--write` rewrites those cells in
place (BOM, CRLF and the 8 columns kept). A cell with no `until` is never
changed. The classes always carry the converted form.

## Editing it in a spreadsheet

1. Open the CSV in Excel or LibreOffice; change `schedule`, `status`, `rules_url`, `rules_year`, `notes`.
2. Keep the header row and the `contest_id` values exactly as they are.
3. Save as **CSV UTF-8 (comma delimited)**. A cell holding a comma or a semicolon is quoted automatically.

## What agents do with it

Agents convert any `until` cell first (above), then apply `verified` and
`candidate` rows (and `unscheduled`) to the classes' `GetSchedule` overrides,
with the status, rules URL and rules year beside each declaration; a
candidate's comment says it is a calendar date not yet checked against the
sponsor's rules. `pending` and `hold` rows are not applied, even when their
cell holds text. The contests still pending are listed, by id, in
`tr4w/test/unit/uTestContestSchedule.pas` (`SCHEDULE_NOT_YET_STATED`), which
only shrinks. The CSV is then regenerated from the classes, or retired once
every class states its schedule.

## Harvest performed 2026-11-16

The intake was updated directly in main after re-reading NY4I's saved copy.
All 205 original rows, identifiers, names and mode variants were retained.
Unrelated rows were preserved, including existing manually entered schedules.
Florida and Virginia were intentionally normalized into separate operating
periods; their prior schedule text remains in the row notes.

Sources:

- `https://qsoparty.eqth.net/index.html` supplied the state/province calendar
  and sponsor links. It supplies dates rather than UTC operating windows.
- Sponsor rules supplied verified UTC windows and, where stated, recurring
  date rules. A dated calendar entry alone cannot distinguish fourth from last.
- Scraping `https://hamradiocontestcalendar.com/` revealed the public endpoints
  its own scripts use: `/api/v1/editions/years`,
  `/api/v1/editions?year=2026`, `/api/v1/editions?year=2027`, and
  `/api/v1/editions/<public_id>/briefing`. They returned 2,156 editions for
  2026 and 1,975 for 2027, including operating periods and rules links.
- The site's `calendar.ics` was only an October-December 2026 slice, with
  613 event periods and no RRULEs. It was not used as a complete annual source.

Only unambiguous name matches were harvested automatically; similar names are
not enough to map an unrelated contest. Dates inferred from the calendar are
`candidate`, not `verified`. Rules URLs reported by the calendar are retained
as provenance but do not imply that the sponsor page was checked. Single-year
or inconsistent patterns retain explicit dated clauses when a recurring rule
cannot safely be inferred. All generated relative patterns need sponsor review.

The source is useful but not authoritative: Ohio's sponsor lists Aug 28, 2027,
where the site's API gives Aug 21. Its DARC Christmas briefing says Boxing Day
but its 2027 date is Dec 25; that row is on hold. Nebraska and New Jersey dates
also differed between the eqth list and their sponsors. Row notes record these
findings and the source used. Oklahoma remains on hold because UTC starts
disagree. Do not clear holds merely because another calendar has a date.

Credit and terms: some candidate dates come from Ham Radio Contest Calendar
(hamradiocontestcalendar.com, DL2NBY), whose terms allow individual contest
facts (names, dates, times, modes, bands) to be shared and used elsewhere, with a
link back appreciated, while the compilation stays protected. The organizer's
rules take precedence over it. This was a ONE-TIME harvest: see
`tools/contest-schedule-harvest/WARNING.md`, which forbids any automatic lookup
of that site.

## Multiple operating periods

### What was changed in the intake

Several calendar API entries provided a single envelope from the first start
to the final end, silently including an overnight off period. Those envelopes
were NOT treated as uninterrupted operating windows. The following rows now
contain separate clauses for their actual periods:

| Contest | UTC periods encoded | Hours on air / intervening break |
|---|---|---|
| British Columbia | Sat 1600-Sun 0400; Sun 1600-2400 | 12 + 8 / 12 |
| Florida | Sat 1600-Sun 0200; Sun 1200-2200 | 10 + 10 / 10 |
| Georgia | Sat 1800-Sun 0400; Sun 1400-2400 | 10 + 10 / 10 |
| Idaho (candidate) | Sat 1600-Sun 0400; Sun 1400-Mon 0200 | 12 + 12 / 10 |
| Kansas | Sat 1400-Sun 0200; Sun 1400-2000 | 12 + 6 / 12 |
| Missouri (candidate) | Sat 1400-Sun 0400; Sun 1400-2000 | 14 + 6 / 10 |
| New England | Sat 2000-Sun 0500; Sun 1300-2400 | 9 + 11 / 8 |
| New Hampshire (candidate) | Sat 1600-Sun 0400; Sun 1200-2200 | 12 + 10 / 8 |
| Ontario | Sat 1800-Sun 0300; Sun 1200-2000 | 9 + 8 / 9 |
| Pennsylvania | Sat 1600-Sun 0400; Sun 1300-2200 | 12 + 9 / 9 |
| Washington Salmon Run | Sat 1600-Sun 0700; Sun 1600-2400 | 15 + 8 / 9 |
| Texas | Sat 1400-Sun 0200; Sun 1400-2000 | 12 + 6 / 12 |
| Virginia (candidate) | Sat 1400-Sun 0400; Sun 1200-2400 | 14 + 12 / 8 |

The CSV `status` governs readiness: this table describes the representation,
not blanket verification. Candidate rows explain which parts still need review.
For example, Idaho's sponsor text mixes dates/years and leaves a UTC start
placeholder, so its two-window candidate must be checked before adoption.

Florida's example is:

```text
4th Saturday of April at 16:00 UTC for 10h; 4th Saturday of April +1d at 12:00 UTC for 10h
```

This is 20 operating hours across a 30-hour envelope, and it stays two
periods. `+1d` is the day AFTER THE SAME anchor date (built: the parser takes
`+Nd` after any anchor), never an independent fourth Sunday, which lands a
week earlier when the month starts on a Sunday (2029).

Where sponsors say an end is 0159Z or 2359Z, the last minute is included:
normalize the exclusive end to 0200Z or next-day 0000Z. Do not subtract a minute
from the advertised duration. Imported calendar boundaries ending in :59 were
normalized as candidates and explicitly flagged for rules review in the notes.

### Settled by the implementation (2026-11-16, step A)

- **No grouping model** (NY4I): each clause is a UTC period `[start, end)`,
  and a contest is ONE dropdown entry. Its sort key is its earliest period
  that is running now (key = now) or still to come (key = its start); in a
  QSO party's overnight gap that is the Sunday start, not next year's; after
  the last period of a published-date list there is no date (sorted last).
  `uContestSchedule` does this; `uTestContestSchedule` tests the first end,
  the gap, the second start, the final end, month/year crossings and sessions
  on one UTC day.
- Published-date lists are finite: never repeated next year. A missing week in
  a weekly series is not representable (see "Not supported yet").
- Nothing restricts opening a contest or logging a QSO by its schedule.
- Still open: Idaho's candidate windows need the sponsor's correction;
  `IN7QPNE`'s 35-hour envelope is the union of the 7QP, Indiana, New England
  and Delaware periods (they overlap to Sat 1300Z-Sun 2400Z) and was applied as
  a candidate; West Virginia ("the Saturday on or before June 20") is still
  ISO dates. North Carolina's rule ("the Sunday after February's 4th
  Saturday") is `4th Saturday of February +1d`, which parses now; its row
  keeps the 2026/2027 ISO dates until NY4I moves it to that form.
