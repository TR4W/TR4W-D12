# CONTEST_SCHEDULES.csv -- schedule intake for agents

`CONTEST_SCHEDULES.csv` is an **intake file only**. NY4I edits it in a
spreadsheet to hand contest schedule updates to agents. The contest classes keep
owning the schedule string (`GetSchedule`, see the schedule-helper handoff);
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

## Grammar (still "awaiting approval" in the harvest)

- One string per row; `;` separates independent occurrences.
- Date: `4th full weekend of June`, `last Saturday of February`, `every Wednesday`, `06-27`, `2027-03-21`; `+1d` after a full weekend anchors Sunday.
- Optional window: `at HH:MM UTC for Nh` (or `for Nm`); without it the clause is a date-only hint.
- Ordinals `1st`-`5th` (or `first`-`fifth`) and `last`; keywords and English names are case insensitive.
- Parsing is strict: one bad clause rejects the whole string. Example: `last full weekend of March at 00:00 UTC for 48h`.

The authoritative statement is `CONTEST_SCHEDULE_HARVEST.md` ("Proposed grammar").

## Editing it in a spreadsheet

1. Open the CSV in Excel or LibreOffice; change `schedule`, `status`, `rules_url`, `rules_year`, `notes`.
2. Keep the header row and the `contest_id` values exactly as they are.
3. Save as **CSV UTF-8 (comma delimited)**. A cell holding a comma or a semicolon is quoted automatically.

## What agents do with it

Agents apply `verified` rows to the classes' `GetSchedule` overrides, with the
rules URL, year and section beside each declaration. The CSV is then regenerated
from the classes, or retired once every class states its schedule.

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

## Multiple operating periods: handoff to the contest agent

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

This is 20 operating hours across a 30-hour envelope. It must not become a
30-hour continuous period. `+1d` refers to the day AFTER THE SAME anchor date;
do not calculate an independent fourth Sunday, which can land a week earlier
when the month starts Sunday. Some rows therefore need the parser to accept
day offsets on weekday anchors as well as full-weekend anchors. This extends
the proposed grammar; it is not implemented in the current typed helper.

Where sponsors say an end is 0159Z or 2359Z, the last minute is included:
normalize the exclusive end to 0200Z or next-day 0000Z. Do not subtract a minute
from the advertised duration. Imported calendar boundaries ending in :59 were
normalized as candidates and explicitly flagged for rules review in the notes.

### What the implementation still needs

- A contest running needs a list of UTC operating periods, not only one
  `start/end`. Keep `[start,end)` per period. Its overall calendar envelope
  may be useful for display, but membership in that envelope does NOT mean a
  QSO falls within an operating period. Existing `uContestTimeLeft` represents
  only one window and cannot describe a multi-period event on its own.
- Preserve ONE contest/dropdown entry for a multi-period QSO party. During
  its overnight gap, retain the same running and find its next period instead
  of jumping to next year's contest. Distinguish "between periods" from
  "currently operating" and "finished"; the final end determines when that
  running is over. A countdown must target the next start during the gap.
- Semicolons currently separate windows in the intake; they do not encode
  whether the windows belong to one log. A QSO party's Saturday and Sunday
  periods belong to the same running; CWT's same-day sessions are separate
  runnings. NAQP's seasonal dates are also separate runnings. Add an explicit
  grouping contract in the string/parsed model or class metadata before
  integration. Do not infer grouping merely from the separator or proximity.
- Makrothen's three periods, and other non-QSO-party candidates harvested
  from multiple API periods, must retain their offsets and grouping too.
  Treat explicit published-date lists as finite data; never repeat them next
  year automatically. A missing week in a weekly series may be intentional.
- `IN7QPNE` is a separate combined-entry candidate. Its 35-hour envelope is
  derived from the union of 7QP, Indiana, New England and Delaware windows,
  which overlap to cover Sat 1300Z-Sun 2400Z. Confirm that class's combined
  semantics; it does not replace any constituent contest's own periods.
- North Carolina and West Virginia illustrate recurrence grammar limits.
  North Carolina is the Sunday after February's fourth Saturday, sometimes
  March 1. West Virginia is Saturday ON OR BEFORE June 20, not always June's
  third Saturday. Their rows use explicit 2026/2027 dates with the true rule
  in notes until the helper can express those rules correctly.
- Add tests for the first end, the overnight gap, the second start, the final
  end, month/year crossings and multiple sessions on the same UTC day.
  Test that grouping and sorting never create a new operating window or
  duplicate a multi-period contest in the dropdown. Schedule display must
  continue to permit historical logging; QSO rejection was not authorized.
