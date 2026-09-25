# Asking an Icom which bands it has

**What this is:** a capture of what an IC-9700 actually answers when TR4W asks
it to describe its bands, taken over LAN from NY4I's radio on 2026-09-24. It is
evidence, not a summary — the payload bytes are reproduced so a future reader can
re-decode them rather than trust this page.

**Why it matters:** TR4W's band up/down and the drivers' band stepping both need
to know which bands a radio has. Until this capture, that knowledge lived in
hand-typed `case` ladders inside driver classes. The capture settles that it does
not have to.

## The answer, first

**An Icom enumerates its transmit bands, and `$1E` is the command that does it.**
`$02` does not — it bounds only the band the radio is on.

| command | what came back | use |
|---|---|---|
| `$1E $00` | a BCD count of transmit bands | how many times to ask |
| `$1E $01 <n>` | edge number, then low edge, `$2D`, high edge | the band list |
| `$1E $01` (no `n`) | **NG** | nothing — do not send it |
| `$02` (bare) | one pair: the CURRENT band's edges | bounds, not a band plan |
| `$02 $00`, `$02 $01`, `$02 $02` | **NG** | `$02` takes no argument |

## The capture

Raw CI-V payloads, as logged by `TIcomRadio.LogBandEdgePayload`. Bytes are the
payload after the command echo, in the order they arrived.

```
$02   raw (11 bytes): 00 00 00 40 12 2D 00 00 00 00 13
$1E   raw  (2 bytes): 00 03
$1E   raw (13 bytes): 01 01 00 00 00 44 01 2D 00 00 00 48 01
$1E   raw (13 bytes): 01 02 00 00 00 30 04 2D 00 00 00 50 04
$1E   raw (13 bytes): 01 03 00 00 00 40 12 2D 00 00 00 00 13
```

Decoded — frequencies are 5-byte little-endian BCD, the same encoding `$03` and
`$05` use, and `$2D` separates the pair:

| frame | meaning |
|---|---|
| `00 03` | sub-command `$00` echoed, then **3** transmit bands — and the count is **BCD**, not hex |
| `01 01 …` | sub-command `$01`, **edge 1**: 144.000000 – 148.000000 MHz (2 m) |
| `01 02 …` | edge 2: 430.000000 – 450.000000 MHz (70 cm) |
| `01 03 …` | edge 3: 1240.000000 – 1300.000000 MHz (23 cm) |
| `$02` bare | 1240.000000 – 1300.000000 MHz — the radio was tuned to 23 cm at the time |

That last row is the whole case against `$02`. It returned the 23 cm edges
because the VFO was on 23 cm; it says nothing about the other two bands the rig
plainly has.

## Notes a future reader will want

**The count is BCD.** `$13` from an IC-7100 is thirteen bands, not nineteen.
Reading it as hex was a real bug here on 2026-08-05.

**`$1E $01` is 13 bytes, not 12.** The manual's layout is
`[edge no.][5 lower][2D][5 upper]` = 12, and the sub-command echo `$01` in front
makes 13. `$02` omits the edge number, hence 11.

**The bare `$1E $01` NAK is expected and is no longer sent.** It was a probe, and
the NAK handler could not tell it from a radio with no `$1E` at all: it set
`FTXBandsUnsupported` and logged, at INFO, that the radio rejected `$1E` —
thirty milliseconds before the same radio delivered all three of its bands. The
enumeration survived only because the send queue serialises and the count
happened to arrive first. Removed 2026-09-24.

**This is one radio.** It proves an IC-9700 enumerates; it does not prove every
Icom does, and it says nothing at all about Kenwood, Yaesu or Elecraft, none of
which have an equivalent question. Everything downstream therefore treats an
empty coverage table as *no opinion* rather than *no bands*.

## Reproducing it

**The capture above came from `tr4w/test/bench/bench_icombands.lpr`**, which
exists for exactly this. Do not trust this page where you can re-run the tool:

```powershell
powershell -File tr4w\build\Build-Bench.ps1 -Program bench_icombands
tr4w\test\bench\bench_icombands.exe IC9700 <host> <user> <password> 10
```

It is **read-only** — it sends no command of its own — and it tears its session
down on the way out, which matters because a networked Icom never acknowledges a
disconnect and holds an abandoned session for ~90 s. The console prints which of
TR4W's bands the radio can work; the log beside it holds every `$1E` and `$02`
payload as hex next to the driver's decode. Read its header before running it
against a live station.

Nothing builds it automatically — `Build-Bench.ps1` is called by neither
`FullBuild.ps1` nor CI — so build it by hand after touching the radio factory.

The machinery it drives is ordinary driver code, so the same lines appear in
`tr4w.log` during a normal session: `tr4w/src/radioFactory/uRadioIcomBase.pas`
— `QueryBandEdgesOnce` sends the queries on the first mode response of a
connection, `LogBandEdgePayload` logs each payload raw and decoded, and
`AddCoverageRange` turns the result into the radio's transmit coverage. Run
TR4W with `DEBUG LOG LEVEL = INFO` or finer and they appear within a second of a
networked Icom coming up.
