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
| `station_settings` | optional: what Preferences > Station holds (`State`, ...). **Not the same as `station`:** a value in `station` is the contest's own statement. IARU shipped sending the everyday state in place of the zone because the two were one thing to the test |
| `worked`, `typed` | the call window and the exchange window |
| `band`, `mode` | as TR4W shows them (`80`, `SSB`). With no radio the program starts on 160 m CW, and a contact the contest refuses is exported as `X-QSO`, so the case finds no `QSO:` line |
| `sent`, `received` | the fields expected after my call, and after the worked call. All-digit fields compare as numbers (`1` is `001`) |
| `source` | the sponsor's rule or sample behind `sent` and `received` |

## How it drives the program

`tr4w.exe <new.db> /ENTERQSO <call> <exchange> <band> <mode> --new-contest-from=<file>`
creates the log the way File > New does and calls `MainUnit.TryLogContact`
(exit 0 saved, 6 refused). Then `tr4w.exe <new.db> /EXPORT`. The runner starts
the program itself rather than through `Run-Headless.ps1`, because PowerShell
splits `--new-contest-from=C:\...` at the colon.

It does not drive the entry window. `tools/gui_test` does that.

A setting the program refuses is only a warning in `tr4w.log`; the runner reads
the lines its own run added and fails the case.

Shown to fail on the ALL JA code from before issue 361, and to pass on the fix
(2026-11-26). Nothing runs it automatically yet.
