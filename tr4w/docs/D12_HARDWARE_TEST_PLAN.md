# TR4W Delphi 12 — Hardware / Bench Test Plan

Bench-verification gates for the D12 cutover (readiness items **P1-6, P1-7, P1-8**).
These paths touch real bytes on wires the golden-master corpus cannot exercise —
it only validates the scoring engine on ASCII log data. The D12 compiler moved
`Char`/`string` from 1-byte ANSI to 2-byte UTF-16, so **every place TR4W puts
bytes on a serial line, a socket, or a parallel port is a suspect** until a human
watches real hardware respond.

## Why these specifically — the D12 risk map

The port already found and fixed three byte-boundary bugs of exactly this kind.
The fixes are in, but only one path was validated on hardware. Re-test around them:

| Fix (commit) | What broke under D12 | Hardware validated? |
|---|---|---|
| `8e0bb61` serial I/O writes **bytes, not UTF-16 code units** | every serial-connected radio got `F`,`00`,`A`,`00`… instead of `FA…` | **No** — needs a serial radio |
| `df0017a` Icom **network** CI-V byte corruption (login + freq/mode/RIT/split) | LAN CI-V frames carried in UTF-16 buffers corrupted any byte ≥ $80 | **Only IC-7760 over LAN** |
| `2089924` Icom CI-V **BCD** read as AnsiString | BCD freq bytes mangled | unit-test only |
| WSJT-X `htonl` range-check (`87c3c12`) | UDP packet length/byte-order | **No** — needs WSJT-X |

So the untested surface is: **serial CAT (all radios), Icom CI-V over serial,
every non-Icom-7760 radio, CW/keyer/DVK, WSJT-X UDP, live telnet/SSL, and the
two-station D7↔D12 wire.**

## Setup (do once)

1. **Confirm you are testing the D12 binary.** Right-click `tr4w.exe` → Properties
   → Details; or in TR4W the About box. The build is `Embarcadero`/D12, not Borland.
2. **Turn on debug logging.** `settings\tr4w.ini`:
   ```
   [COMMANDS]
   DEBUG LOG LEVEL = DEBUG
   ```
   Watch `tr4w.log` in the program directory during each test — CAT/CI-V/keyer
   traffic is logged there, so a byte-corruption bug shows up as garbled hex even
   if the radio "sort of" responds.
3. **Have a serial sniffer handy for the hard cases** (com0com + a terminal, or a
   hardware line monitor). For the serial and CI-V tests, the definitive pass is
   *the exact bytes on the wire*, not just "the radio moved."
4. Where a **D7 build** is called for (P1-7), keep a known-good D7 `tr4w.exe` on a
   second machine.

Record each result as **PASS / FAIL / N-A (don't own the device)**. N-A is a fine
answer — only test what your station actually uses.

---

## Group A — Serial CAT radio control  (P1-8 · risk: `8e0bb61`)

Do this for **every radio you connect over a serial/USB-serial port** (Icom via
CI-V serial, Kenwood TS-890, Elecraft K4, anything through HamLib on a COM port).
This is the single highest-value group: the serial-write fix touches all of them
and none have been hardware-checked.

For each radio:

- **A1 — Frequency read.** Spin the VFO on the rig. TR4W's displayed frequency
  must track it exactly (to the Hz the rig reports), continuously, with no freezes
  or jumps. *(A byte-corrupted read shows as wrong/garbage frequency or a stuck
  display.)*
- **A2 — Frequency set.** Click a band-map spot or type a frequency and send it to
  the rig. The rig must land on the **exact** frequency, not off by a digit.
- **A3 — Mode set + read.** Change mode (CW / SSB / RTTY / FM) from TR4W and from
  the rig. Both must agree each way.
- **A4 — PTT / T-R.** Key TR4W (e.g. F-key CW message, or manual PTT). Rig goes to
  transmit and back cleanly; no stuck PTT.
- **A5 — Split + RIT/XIT.** Set split, set an RIT/XIT offset from TR4W. Rig shows
  the right split and offset. *(RIT/XIT was in the `df0017a` corruption set.)*
- **A6 — Soak.** Leave it connected 15+ minutes with the VFO moving. No drift into
  garbage, no disconnect, `tr4w.log` shows clean CAT exchanges throughout.

**Pass:** every set/read is byte-accurate and stable over the soak.
**On any FAIL:** capture the `tr4w.log` hex and (if possible) the serial-sniffer
bytes — that pins whether it's the write path, the read path, or framing.

## Group B — Icom CI-V, both transports  (P1-8 · risk: `df0017a`, `2089924`)

Only the **IC-7760 over LAN** was validated. Re-run A1–A6 above for **each Icom
you own** (705, 7100, 7300, 7300MK2, 7600, 7610, 7760, 7850, 905, 9700), and:

- **B1 — Serial CI-V.** Every Icom on a **serial/USB** CI-V connection (not LAN).
  This path is completely unvalidated under D12. Watch especially frequencies
  above a byte boundary — CI-V BCD encodes digits in bytes ≥ $80, exactly what
  corrupted before.
- **B2 — Network CI-V (LAN) on a non-7760 Icom.** Login must complete (not hang at
  "WaitingForLogin" — that was the exact `df0017a` login-packet bug), then A1–A6.
- **B3 — Edge frequencies.** Tune to values that exercise high BCD bytes, e.g.
  1.999.999 kHz boundaries, 29.999 MHz, 1296 MHz on a 9700/905. Read back exact.

**Pass:** serial and LAN CI-V both byte-accurate on every Icom you use.

## Group C — SO2R / dual radio  (P1-8 · `uRadio12`)

If you run SO2R:

- **C1 —** Both radios connected simultaneously; confirm Radio 1 and Radio 2 each
  read/set frequency independently (repeat A1/A2 per radio).
- **C2 —** Focus switching moves CAT + CW to the correct radio; no cross-talk
  (a command meant for R1 never lands on R2).
- **C3 —** Transmit on one while the other is receiving; no interference in CAT.

## Group D — CW, keyer, and voice keyer  (P1-8)

- **D1 — WinKey (serial keyer).** Send CW from every F-key memory and by paddle.
  Verify: correct characters, correct speed, **speed changes take effect**, and
  timing is clean (no stutter/gaps) — WinKey is a serial device, so it rides the
  same `8e0bb61` byte path. Sidetone and weighting as configured.
- **D2 — LPT / parallel-port keying** (`inpout32.dll`, if you key via LPT). Keying
  is clean at your normal WPM; PTT-via-LPT asserts and releases.
- **D3 — Paddle input.** Iambic behavior and speed as expected.
- **D4 — CW message memories with substitutions.** Send messages containing the
  serial number, call, and exchange macros; confirm the sent text is correct
  (this is where a string-boundary bug would corrupt the keyed text).
- **D5 — DVK / DVP (voice keyer).** Play each voice memory; audio is correct, PTT
  timing correct, no truncation.
- **D6 — CW timing under load.** Send long messages while CAT polling and the band
  map are active; timing must stay clean (the risk register flags CW/DVK timing
  regressions specifically).

## Group E — Digital modes  (P1-6/P1-8 · WSJT-X `htonl`)

- **E1 — WSJT-X (FT8/FT4).** Start WSJT-X with UDP enabled to TR4W. Confirm:
  decodes appear in TR4W, colorization is correct (dupe vs mult vs needed),
  a completed FT8 QSO logs into TR4W with the right call/grid/exchange, and the
  UDP link survives a full contest-length session. *(The `htonl`/length fix is on
  this UDP path.)*
- **E2 — RTTY via MMTTY** (if used). RX text decodes, TX sends the right text,
  QSO logs correctly.
- **E3 — MixW** (if used). Same: RX/TX/log.

## Group F — Telnet / DX cluster / SSL  (P1-6)

The whole cluster/SSL stack rides the **vendored Indy 10.6.3.3** now compiled
under D12 — untested live.

- **F1 — Plain telnet cluster.** Connect to a DX cluster over telnet. Login
  prompt, commands you type, and incoming spots all render correctly (no garbled
  text — this is a string-boundary surface).
- **F2 — Spot flow → band map.** Spots populate the band map at the right
  frequencies with correct call/color (dupe/mult/needed). Click-to-tune sends the
  rig to the spot (ties back to A2).
- **F3 — SSL / secure cluster.** Connect to a cluster that requires SSL/TLS
  (`libeay32`/`ssleay32`). Handshake succeeds, spots flow. *(This is the specific
  "swap the vendored Indy" risk.)*
- **F4 — Disconnect / reconnect.** Drop the connection (or the network) and let it
  reconnect; confirm the reconnection logic recovers and spots resume.
- **F5 — Soak.** Leave the cluster connected for a long session; no memory growth
  or hang, spots keep flowing.

## Group G — Two-station D7 ↔ D12 wire  (P1-7)

The reassuring evidence: `ContestExchange` is all fixed-width types and the D12
exe reads D7 `.dat` files, so **disk** layout matches. The gap is the **live
network** between a D7 station and a D12 station mid-contest. Run one machine on
the **D7** `tr4w.exe` and one on the **D12** build, both joined to the same
`tr4wserver`:

- **G1 — QSO broadcast both directions.** Log a QSO on the D7 station; it appears
  intact on the D12 station (call, exchange, band, mode, serial) and vice-versa.
  No garbled fields.
- **G2 — Dupe/mult consistency.** After exchanging several QSOs, the dupe sheet and
  multiplier state **match on both stations**. A wire-layout mismatch shows up as
  a dupe seen on one station but not the other, or divergent mult counts.
- **G3 — DX spots across versions.** A spot originated on D7 reaches the D12 band
  map correctly, and vice-versa.
- **G4 — Time sync.** Confirm time synchronization across the two versions keeps
  clocks aligned (serial-number lockout / time-sync packets are part of the wire
  protocol).
- **G5 — Serial-number lockout.** With lockout enabled on the server, confirm the
  D7 and D12 stations don't hand out duplicate serials.
- **G6 — Mixed-version stress.** Run a realistic burst (both stations logging
  quickly) for 15+ minutes; no corruption, no desync, no server disconnects.

**Pass:** a D12 station is indistinguishable on the wire from a D7 station —
every field round-trips and both stations agree on dupe/mult/serial state.

---

## Also worth doing while at the bench — non-ASCII surface (P1-5)

The corpus is ASCII-only, so the UTF-16/ANSI work is unproven on real non-English
data. If you build/run a non-English variant (RUS/SER/MNG/CZE/ROM/GER/UKR/ESP):

- **H1 —** Menus, prompts, and messages render with correct accented/Cyrillic
  characters (no mojibake).
- **H2 — CTY.DAT country names** with non-ASCII characters display correctly in
  the country/mult windows.
- **H3 — Config parsing** of a `.cfg` containing non-ASCII exchange/message text
  round-trips correctly (edit, save, reload).

## Reporting

For each group, note PASS / FAIL / N-A and, on any FAIL, attach the relevant
`tr4w.log` excerpt (with `DEBUG LOG LEVEL = DEBUG`) and any serial-sniffer capture.
A FAIL in Group A or B most likely points back at a byte-boundary path the port
touched; the log hex is what pins it.
