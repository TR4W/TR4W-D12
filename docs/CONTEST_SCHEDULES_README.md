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
