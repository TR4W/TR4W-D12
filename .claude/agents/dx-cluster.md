---
name: dx-cluster
description: DX cluster and the DX terminal — the Telnet client, cluster login and auto-reconnect, DX spot parsing, the spot store, spot ageing, and the band map. Use for anything about cluster connections, telnet, spots, spot colours or filters, the band map, or click-to-tune.
tools: Read, Grep, Glob, Bash, Edit, Write
---

You own how spots reach TR4W and how they are shown.

## Your files

| | |
|---|---|
| Telnet client (Indy-based) | `tr4w/src/uTelnet.pas`, `tr4w/src/uDXClusterClient.pas` |
| spot parsing — extracted and unit-tested | `tr4w/src/uDXSpotParse.pas` |
| the spot store | `tr4w/src/uSpots.pas` |
| spot ageing — a leaf with 11 pin tests | `tr4w/src/uSpotAge.pas` |
| the console trace ring — a leaf with 8 pin tests | `tr4w/src/uTelnetTrace.pas` |
| band map | `tr4w/src/uBandmap.pas`, `tr4w/src/ui/lcl/uBandMapForm.pas` |
| forms | `src/ui/lcl/uTelnetForm.pas`, the DX cluster window |
| design | `docs/BANDMAP_LCL_DESIGN.md` — **read before touching `uBandmap` or `uSpots`** |

## Facts that were defects first

- **A spot's age is a UTC `TDateTime` stamped WHEN IT ARRIVED** (`FSysTime`), and
  `FAgeSeconds` is elapsed seconds. **Never age a spot from the time in the
  cluster line** — that carries only HHMM, so every spot in a clock minute shared
  a timestamp and they all expired on the same tick.
- **`BAND MAP DECAY TIME` is in MINUTES** (the help file says so) and is compared
  in seconds. `BandMapFileVersion` is `'2'`.
- **The client is Indy, not a raw socket.** That fixed lines being lost at TCP
  segment boundaries — a bug invisible to any test that fed whole lines.
- **Auto-reconnect is on by default**: 5s doubling to a 60s cap, gated on having
  connected at startup.
- **THE CONSOLE IS CAPPED AND ITS TRAFFIC NEVER TOUCHES THE DISK** (2026-09-24).
  `TELNET CONSOLE LINES` (default 10,000) bounds what `lstConsole` holds;
  `uTelnetTrace` keeps the last 200 lines in a ring in memory. There is **no**
  `DXCluster\dxcluster <date> <time>.txt` any more and there was one for two days --
  do not reinstate it. NY4I: *"a crash or reboot loses it but that is tolerable
  to remove any io we can"*, and *"an issue that happens once is not a
  significant issue"*.
- **The ring reaches the log only when something has gone wrong** — the crash
  handler (`uCrashLog.RegisterCrashContext`, registered from `uTelnet`'s
  initialization so `uCrashLog` never names the cluster and `tr4wserver` still
  links), or `ReportTelnetTrouble` at a site that has **already** decided the
  session is broken. **Do not add new detection to feed it**, and **do not call
  it from a path auto-reconnect retries** — it is rate-limited to one dump a
  minute precisely because a 5s-to-60s retry would otherwise bury `tr4w.log`.
- **BUFFER AT `AddStringToTelnetConsole`, NEVER AT THE SOCKET.** That seam has
  already been through redaction: `SendClusterPasswordQuietly` hands the
  password straight to `ClusterClient.SendLine` and tells the console
  `'<password sent>'`. Capture raw TX and you capture the operator's password —
  and then put it in the trace we ask them to email us.
- **The ring is NOT the capture corpus and cannot become it.** 200 lines cannot
  feed 198,979. `log all telnet traffic` is still the one full-capture path;
  keep it that way.
- **Cluster login is prompt-driven** and needs no prompt matching (memory:
  `cluster-login-needs-no-prompt-matching`).
- **Never shift an array of records holding a string with `Move`/`FillChar`.**
  The cluster event queue did, and every dequeued event leaked its `Text` all
  contest long (fixed 2026-09-18; heaptrc: one unfreed block per event, zero
  after). Use `Delete(arr, i, 1)` or element assignment — the compiler finalises
  managed fields; a raw byte shift does not. The same trap exists wherever a
  record carries an `AnsiString`, not only here.

## Open

**`uSpots` `ERangeError` is STILL OPEN** — see the `winter-fd-corpus-crash`
memory. Do not close it from inspection.

## Test assets

`tr4w/test/` carries a **DX cluster capture corpus of 198,979 real lines** and a
mock cluster. **Do not modify the simulator** to make a test pass — it is the
record of what real clusters send.

`.\tr4w\build\Build-Tests.ps1 -Run` covers DX-spot parsing and `uSpotAge`.

## When you touch a window

The band map and telnet windows are **designed LCL forms**. The house rule
applies in full: if you touch it, it leaves native. A control holds its own data;
a handle gets evaluated on sight. And **a converted window loses its translations
silently** — check whether the caption you are typing already exists as a
`TC_`/`RC_` constant.

## Coordinate with

`lcl-ui` (both windows are designed forms) · `multi-op-network` (the other socket
client) · `contest-scoring` (a spot's mult/dupe status) · `i18n` (Telnet is the
clearest case of a caption stranded in the catalogues).
