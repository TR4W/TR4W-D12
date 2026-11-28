# Per-contest export test (issue 390)

For each case: a new contest log in its own folder, one contact entered as Enter
enters it, a second run that exports Cabrillo from the log on disk, and a check
of the whole `QSO:` line, field by field and in order.

```
.\tr4w\build\Build-App.ps1
python tr4w/test/export-test/run-export-test.py [NAME ...]
```

Make sure TR4W is not running. Each run writes a new folder under
`build-out/export-test/` and deletes nothing.

## The safeguards

1. **Expected fields are written from the sponsor's documents by someone who has
   not seen this program's code or output.** When agents prepare cases, they are
   given only `docs/ContestRules` and told to read nothing under `tr4w/`. The
   runner of the test reviews their cases and does not edit expected fields to
   match output.
2. **Setup is realistic.** `station` may hold only what New Contest asks this
   contest (the program says: `/NEWCONTESTPROMPTS`); anything else fails the
   case and belongs in `station_settings`.
3. **Every contest has a status.** A full run writes
   `build-out/export-test/status.md`: each contest pass, fail, or unverified
   with a reason from `unverified.json` (else "no case written yet").

A failure is investigated against the sponsor's text before it is called a
defect: several have been the case's own mistake.

**DXLog.net's definition files confirm, they do not decide** (NY4I,
2026-11-27): `C:\Program Files (x86)\DXLog.net\Contest\*.txt` -- county codes
(`CFG_MULT_RGX_CHECK`), the column order (`CABRILLO_LINE`) and the contest name
(`CABRILLO_CONTEST_NAME`). It is another logger's reading of the rules: the
sponsor wins, and a disagreement is recorded. It has codes, not county names,
which is all a case needs.

## ADIF, and an entry that must be refused

Each case's ADIF is checked too. A sponsor defines Cabrillo, not ADIF, so the
expected `STX_STRING` and `SRX_STRING` are **derived from the case's own
sent and received fields**. Where ADIF rightly differs, the case says so under
`adif` (`sent`, `received` or `records`) with a `why`, and a case without one
fails. Never fill it from output. A county line is one contact in ADIF, so its
received fields are not compared.

A case with `refused` (the text of the refusal) passes only when the entry is
refused with it.

## The one rule

**The expected fields come from the sponsor, and `source` says where.** Never
copy them from this program's output. Issue 361 (ALL JA with no signal reports)
passed every other check because their expectations had been taken from it. A
case without a `source` fails. A contest with no sponsor format to be found has
no case; it is unverified, not passed.

## A case (`cases.json`)

| field | meaning |
|---|---|
| `contest` | the contest's id, as the log records it |
| `station` | the commands New Contest would queue; `MY CALL` is required. The command for the CQ zone is `MY ZONE` |
| `i_am_in` | true when the case ticks the dialog's "I am in ..." box, which asks further rows |
| `station_settings` | optional: what Preferences > Station holds (`State`, ...). **Not the same as `station`:** a value in `station` is the contest's own statement. IARU shipped sending the everyday state in place of the zone because the two were one thing to the test |
| `worked`, `typed` | the call window and the exchange window |
| `band`, `mode` | as TR4W shows them (`80`, `SSB`; the mode is `CW`, `SSB` or `DIGI`, not `RTTY`). With no radio the program starts on 160 m CW, and a contact the contest refuses is exported as `X-QSO`, so the case finds no `QSO:` line |
| `sent`, `received` | the fields expected after my call, and after the worked call. All-digit fields compare as numbers (`1` is `001`) |
| `lines` | instead of `sent` and `received` when one typed contact makes several QSO lines (a county line): a list of `{sent, received}`; the lines may come in either order |
| `source` | the sponsor's rule or sample behind `sent` and `received` |

## How it drives the program

`tr4w.exe <new.db> /ENTERQSO <call> <exchange> <band> <mode> --new-contest-from=<file>`
creates the log the way File > New does and calls `MainUnit.TryLogContact`
(exit 0 saved, 6 refused). Then `tr4w.exe <new.db> /EXPORT`. The runner starts
the program itself rather than through `Run-Headless.ps1`, because PowerShell
splits `--new-contest-from=C:\...` at the colon.

It does not drive the entry window. `tools/gui_test` does that.

**It cannot yet operate FROM a county line.** The operator keeps the home
county in MY STATE and sets the line with the ROVER command, which
`/ENTERQSO` does not do. Putting `AAA/BBB` in MY STATE is not the same: the
station is then not recognized as in state. Working a station ON a line is
covered (`lines`).

A setting the program refuses is only a warning in `tr4w.log`; the runner reads
the lines its own run added and fails the case.

Shown to fail on the ALL JA code from before issue 361, and to pass on the fix
(2026-11-26). Nothing runs it automatically yet.
