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
- **Cluster login is prompt-driven** and needs no prompt matching (memory:
  `cluster-login-needs-no-prompt-matching`).

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
