# Rotator bench-test status

What has actually been exercised against a real rotator, by whom, and when — the
same standard `RADIO_BENCH_STATUS.md` applies to radios. Hand-maintained: there
are five drivers, not a hundred, so a generator would cost more than it saves.

`Tested` is a date (YYYY-MM-DD); `-` means untested. Put what was **actually
exercised** in Notes — "connects" and "turns, and survives a power cycle" are
very different claims.

| Rotator | Registry id | Tested | By | Notes |
|---|---|---|---|---|
| Hy-Gain DCU-1 | `DCU1` | 2026-08-16 | NY4I | Turns on SERIAL 3 at **4800 baud**. Controller powered off mid-session and back on: the failed write closed the port and the next command reopened and turned it, with no restart and no dialog. |
| Yaesu | `YAESU` | - | - | |
| Orion | `ORION` | - | - | |
| Alfa SPID | `ALFA SPID` | - | - | |
| PstRotator (UDP) | `PSTROTATOR` | - | - | Endpoint now comes from the rotator definition rather than two globals (2026-08-15). Untested on the wire. |

## What the DCU-1 run settled

**The baud rate.** `TRotatorBase.PreferredBaudRate` returned 9600, its comment
cited `LogCfg` as the source, and `uTestRotatorFactory` asserted 9600 — all three
were wrong. `LogCfg` opens at **1200** for every type except the DCU-1, which
wants 4800, and the D7 heritage agrees (`C:\TR4W .../LogCfg.pas:268`). Nothing
consumed the function until `OpenRotatorPorts` started asking, so the wrong value
cost nothing until the moment it would have cost everything.

**The library's ports actually open.** Until 2026-08-15 `LogCfg` opened exactly
one port — the legacy `ActiveRotatorPort` — while sends went to the port named by
the *definition*. A rotator on any other port silently never turned, and a second
rotator could not work at all. `2 rotator(s) live` in that log is the first time
that path has been exercised on hardware.

**Recovery is not just "open at startup".** Three distinct cases, all now
covered:

| case | behaviour |
|---|---|
| absent at startup, powered on later | opens on the first turn command |
| configured in Preferences | opens on the first turn command, not at save time |
| open, then powered off | write fails → port closed → next command reopens |

The third was found by NY4I asking which of the first two "on demand" meant. It
had not been covered, and it is the one his own operating hits.

## Still owed

* Any rotator other than the DCU-1.
* **Two rotators at once**, band-split — the case `ServesBand` exists for. It has
  never worked before, so there is no "it used to be fine" baseline.
* PstRotator over UDP, including two definitions pointing at different hosts,
  which a pair of globals could not express.
* `TRotatorDefinition.BaudRate` when set explicitly rather than left 0.
