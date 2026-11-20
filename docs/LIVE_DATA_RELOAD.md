# Live reload of TRMASTER.DTA and the call history file

NY4I, 2026-11-20: after a download the running program must use the new data
**in place**, with no restart, even mid-contest with a QSO being entered. Before
this, the TRMASTER download said "restart TR4W to use it" and a call history
download took effect at the next contest open.

## The shape: build privately, swap whole, free the old

Both files follow one rule. The new file is read and checked into a complete
object nothing else can see; then, on the main thread, the reference the lookups
use is replaced in one step; then the old object is freed. A file that does not
load changes nothing and is reported. Everything that reads either store runs on
the main thread (verified: `CD.*`, `NameInOperatorSet` and `CallsignsList` are
reached only from the entry-window, spot and display code; the network and
download threads hand results back through `Synchronize` / `QueueAsyncCall`),
and the download-finished handlers run on the main thread too, so there is no
lock and no half-built state to see.

## TRMASTER.DTA (Super Check Partial) -- `logscp.pas`

| piece | what it is |
|-------|------------|
| `TTRMasterSnapshot` | the whole file as bytes, its 37x37 index, its end address, its path. Never edited after it is built. |
| `LoadTRMasterSnapshot(file, why)` | reads the file, closes it, and CHECKS it (size holds the index; every address and the end address lie inside the file). nil + a reason otherwise. |
| `CD.InstallTRMasterSnapshot` | puts a snapshot in service: `CD.Snapshot`, the mirrored `SCPIndexArray` / `SCPEndOfFile` / `DTAFileSize`, the flags `TRMasterFileOpen` / `IndexArrayAllocated` / `MasterFileExists`, and clears every cache holding the old file (`CellBuffer`, `LastCallRecord`, `LastPartialCall`, `InitialPartialCall`). Frees the snapshot it replaces. The lazy first load uses it too. |
| `CD.ReplaceTRMasterFile(file, why)` | the live reload: load + check, build `OperatorNameSet` from the NEW file when a contest asked for one (`OperatorNamesWanted`, or the set already exists), then flip set and snapshot together. On failure nothing changes. Sets `ActiveFilename` to the new file. |

**The file is not held open.** The old code kept a handle (`fmShareDenyNone`, no
`FILE_SHARE_DELETE`) from the first lookup to exit, so on Windows a download
could not replace a TRMASTER.DTA SCP had already used. The snapshot is a few
megabytes of memory instead, and the file is free.

The handler is `uMainWindowProc.TRMasterDownloadFinished`; the file it loads is
`BackgroundEvents.TRMasterTarget`, set by the menu arm from
`TRMasterDownloadTarget`.

## Call history -- `uCallsigns.pas`, `uCallHistory.pas`, `logdupe.pas`

`CallsignsList` is the station list; each entry has TWO exchange layers:

| layer | field | written by |
|-------|-------|------------|
| the overlay: what the log or INITIAL.EX stated | `InExchange` + `OwnStated` | `AddIniitialExchange` (even an empty exchange) |
| the call history file | `HistoryExchange` | `AddCallHistoryExchange`, `ReplaceCallHistory` |

**Lookup order, in one place (`TCallsignsList.ExchangeOf`): the overlay if it was
stated, else the call history layer.** That is what "a recent QSO's exchange
trumps call history" now means -- an ordering of the lookup, not of the load. The
callers (`GetIniitialExchange`, `...ByIndex`, `InitialExchangeIsFromCallHistory`,
`FindNumber`, the INITIAL.EX flush) all go through it. (TRMASTER is below both:
the entry window asks `CallsignsList` first and SCP's `CD.GetEntry` after.)

`LogDupe.LoadCallHistoryFile` reads the file into a `TCallHistorySnapshot` (the
reader's store is `AddCallHistoryToSnapshot`), and `TCallsignsList.ReplaceCallHistory`
swaps the layer: every entry's history text is dropped (an entry that existed
only for the old file -- no QSO, never stated -- is deleted), then the snapshot is
stored with `AddCallHistoryExchange`'s rules, in one call. QSO counts, dupe bits,
logged zones and the overlay are untouched, so nothing the log knows can be lost
by a swap. The same routine runs at contest open (the layer is empty then) and
from `CallHistoryDownloadFinished` after a `chdUpdated` download of the file in
use.

A file that cannot be read, or holds no usable row, leaves the layer alone. A
contest or `USE CALL HISTORY FILE` that wants none drops it.

## Pinned by

`uTestLiveDataSwap` (swap while QSOs are logged, visibility at once, failed
loads, lookup/swap/lookup, the name set), `uTestLogSCP` (SCP over the matrix
fixture), `uTestCallsignsList`, `uTestCallHistory`.
