# Vendored third-party code under `tr4w/include/`

Code in here is somebody else's, kept in the tree on purpose. **Record every local
change to it here, in the same commit that makes it**, and mark the change inline
with `TR4W` so a diff against upstream can find it. (The `tools/adifvalidator/`
note, `tools/adifvalidator/VENDORED.md`, is the model for a standalone tool.)

## Indy 10.6.3.3 (`include/Indy*`, `include/Core`, `include/Protocols`, `include/System`)

Kept deliberately: D12 shipped Indy as DCUs only, so swapping it was plausibly a
downgrade; decided 2026-08-04 (CLAUDE.md, "Known compile snags"). No local change
is recorded here. If you make one, add it below.

## `Log4D.pas` (Keith Wood's Log4D, MPL 1.1)

Origin: the Log4D 1.2.12 line (header of the file; contributors adasen, mhoenemann,
aweber, ahesse, michaelJustin, svenHarazim -- those changes are upstream's and are
listed in the unit's own header). Added to this repository 2020-07-27 (`5fba8dd8`)
and moved from `src/` to `include/` in `e3e44888`.

TR4W's own changes, each marked `TR4W` in the source:

| change | where | why |
|---|---|---|
| The unit no longer uses the VCL; the five encoding names `SANSIEncoding` .. are copied from `Vcl.Consts` | the `const` block near `SANSIEncoding` | the VCL was unlinked from the application (`8cc1b59d`, 2026-08-05); the names are the vocabulary of existing Log4D configuration files |
| Off Windows, `TRTLCriticalSection` is no longer declared as the `SyncObjs` CLASS `TCriticalSection` (a shadow of the RTL record) | `3f505004` | portability (Unix); see its commit message for the reasoning |
| Unix: "whether Windows" rather than "which Unix" | `d5d77a1d` | portability |
| `GetCurrentThreadID` returns the real thread id (qualified `System.GetCurrentThreadID`) | the non-Windows shim near the end of the unit | it returned 0, so the `%t` pattern was useless off Windows |
| A failed WRITE is counted, not raised: `WriteFailures`, `LastWriteError` on the stream appender; the file is trimmed back to the last whole line | the stream appender (`ed126e42`) | issue 312: a full disk made every logger call raise `EWriteError` from wherever it was made |
| A failed OPEN is recorded, not raised, and retried: `TLogFileAppender.OpenError`, `ReopenInterval` | the file appender | `e5e19428` (2026-09-15): a log file TR4W cannot open must not end the program |
| A rolling appender counts only what was written (`DoAppend`) | `TLogRollingFileAppender.DoAppend` | while the file could not be opened the size kept growing, so the first append after a reopen rolled a nearly empty file over `tr4w.log.1`, destroying the log from before the failure |

The last three changes (write failure, open failure, rolling size) were marked
inline but recorded nowhere else until 2026-11-16 (review finding, "Vendored
code"). When Log4D is next updated from upstream, re-apply these: the new properties
are read by `uProgramMain`, `tr4wserverUnit` and `uSerialDiagnosis` and pinned by
`test/unit/uTestLog4DFileAppender.pas`, so dropping them breaks the build.
