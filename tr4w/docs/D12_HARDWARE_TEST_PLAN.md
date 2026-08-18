# TR4W Delphi 12 — Hardware / Bench Test Plan

> ## ~~PARTLY SUPERSEDED 2026-08-13 — the toolchain changed, the radios did not~~
>
> The **test plan is still valid**: one verified rig per protocol family remains the gate, and the
> per-radio procedures here are unchanged by the compiler.
>
> What is obsolete is the framing — this was written to qualify a **Delphi 12** build. Bench
> results must now be obtained against the **FreePascal** binary, which is what ships. Anything
> verified only under Delphi 12 should be treated as needing re-confirmation.


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

## Your station — device matrix & priority (NY4I)

Your gear falls onto TR4W's two radio-control paths. The **serial CAT** path
(legacy `LOGRADIO.PAS`, or a native Icom driver run over a COM/USB-serial port)
is the one the `8e0bb61` byte-write fix touched and is the **least validated** —
it also covers the most of your radios, so it's the priority. The **network**
path splits into Icom LAN CI-V (`df0017a`, only the 7760 was proven) and non-Icom
TCP CAT (K4, Flex, TS-890 — all unproven).

| # (priority) | Device | Transport you use | TR4W driver | Risk it covers |
|---|---|---|---|---|
| **0 — baseline** | **IC-7760** | LAN | native (factory) | the one path already proven — run it first to confirm no regression |
| **1** | **IC-7100** | serial CI-V (USB) — *serial-only radio* | native, serial | `8e0bb61` serial write + CI-V BCD |
| **1** | **IC-718** | serial CI-V | legacy CI-V (`LOGRADIO`) | `8e0bb61`, older CI-V |
| **1** | **Elecraft K3** | serial CAT | legacy (Kenwood-type) | `8e0bb61` serial |
| **1** | **Kenwood TS-570** | serial CAT | legacy (Kenwood-type) | `8e0bb61` serial |
| **1** | **Yaesu FT1000MP** | serial CAT | legacy Yaesu **5-byte binary** | `8e0bb61` + the binary Yaesu path (most exotic — high value) |
| **1** | **WinKeyer 3** | serial (COM) | `uWinKey` | `8e0bb61` on the keyer, CW timing |
| **2** | **IC-7610** | LAN (or USB CI-V) | native | `df0017a` LAN CI-V on a non-7760 |
| **2** | **IC-9700** | LAN (or USB CI-V) | native | `df0017a` LAN + VHF/UHF/1296 high BCD bytes |
| **2** | **IC-705** | WiFi/USB CI-V | native | `df0017a` LAN CI-V, addr $A4 |
| **3** | **Elecraft K4** | network | native `uRadioElecraftK4` | non-Icom TCP CAT under D12 |
| **3** | **FlexRadio 6300** | SmartSDR TCP | native `uRadioFlexAPI` | non-Icom TCP CAT (Flex 6000-series) |
| **3** | **Kenwood TS-890** | **TCP over VPN** (N2SKH) | native, `##CN`/`##ID` auth | TCP CAT + auth + VPN latency — bonus network stress |
| **4** | **YCCC SO2R box** | USB HID / **OTRSP** | `uYCCCSO2R` | SO2R switch + OTRSP CW buffer (string→bytes) |
| **4** | **Green Heron RT-21** | via **PSTRotator over UDP** | `PSTROTATOR IP/UDP` (#732) | TR4W sends beam heading as UDP text |

Notes:
- **Radios you can connect two ways** (705/7610/9700 LAN-or-USB; K4/Flex native-or-serial): test the
  transport you actually contest on. If you use USB CI-V for any Icom, that moves it into priority 1
  (serial path) as well.
- **FT1000MP is the highest-value single serial test** — it's the only Yaesu-style 5-byte binary CAT
  path in your kit, the most different from everything else, and completely unexercised under D12.
- The YCCC box is **USB HID**, not a COM port, so it's off the `8e0bb61` serial path — but its OTRSP
  **CW buffer** (`YCCCAddCWMessageToBuffer`) is a string→byte path, so watch the keyed text.

**Recommended order:** 0 (confirm 7760) → the whole priority-1 serial sweep (this is where a D12
byte bug is most likely and least tested) → priority 2 Icom LAN → priority 3 network CAT → 4 SO2R +
rotator → then the mode/network groups E–G below.

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

**Your priority-1 radios (serial/COM):** IC-7100 (serial-only), IC-718, Elecraft
K3, Kenwood TS-570, **Yaesu FT1000MP** (do this one carefully — 5-byte binary CAT),
plus any Icom you drive over USB CI-V instead of LAN. This is the single
highest-value group: the serial-write fix touches all of them and none have been
hardware-checked under D12.

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
- **A6b — POWER CYCLE, unattended recovery.** With TR4W running and connected,
  **switch the radio off**, wait ~30 seconds, then **switch it back on** and
  leave TR4W alone.

  - The radio's name in the main window turns **magenta** when it goes off —
    that is correct, it means "not answering".
  - Within about 30 seconds of switching back on, the magenta must **clear by
    itself** and the frequency must start tracking again.
  - **Do NOT touch Reset Radio Ports.** Needing it is the failure, not the fix.

  *Why this step exists, and why it needs doing on every radio rather than
  once:* an FT-1000MP would reopen its port on the 1s..30s backoff and still
  never come back, because a stale `Disconnecting` flag made TR4W drop every
  poll it tried to send — the port was fine and nothing was allowed to talk to
  it (NY4I, 2026-08-11; fixed same day).
  
  A radio that **volunteers data** on power-up hides this entirely: an Elecraft
  in AI2 or an Icom in transceive starts talking on its own, so TR4W hears it
  without having to ask and recovers regardless. A **strictly polled** radio --
  the Yaesu binary set -- says nothing until asked and never recovers. So this
  step is worth most on a Yaesu, and on **any radio with auto-info turned off**:
  a K3 set to AI0 reproduced the failure exactly, which is how the diagnosis was
  confirmed before the fix.
- **A7 — FT1000MP only.** It uses a Yaesu 5-byte binary CAT protocol (its own path
  in `LOGRADIO.PAS`, with a `FT1000MPCWReverse` quirk). Verify freq/mode set+read
  *and* that CW normal/reverse is correct — this is the byte path most unlike the
  rest of your kit, so it's the most likely to surface a D12 boundary bug.

**Pass:** every set/read is byte-accurate and stable over the soak.
**On any FAIL:** capture the `tr4w.log` hex and (if possible) the serial-sniffer
bytes — that pins whether it's the write path, the read path, or framing.

## Group B — Icom CI-V over LAN, non-7760  (P1-8 · risk: `df0017a`, `2089924`)

The **IC-7760 over LAN** is the one path already validated — run it first (step 0)
to confirm no regression. Then re-run A1–A6 over **LAN** for your other network
Icoms: **IC-7610, IC-9700, IC-705**.

- **B0 — IC-7760 baseline.** Confirm login completes and freq/mode/RIT/XIT/split
  all work — the known-good reference.
- **B1 — Serial CI-V.** Any Icom you run over **serial/USB** CI-V (IC-7100 is
  serial-only; 705/7610/9700 if you use USB rather than LAN). Covered in Group A;
  listed here because CI-V BCD is where high bytes (≥ $80) live.
  This path is completely unvalidated under D12. Watch especially frequencies
  above a byte boundary — CI-V BCD encodes digits in bytes ≥ $80, exactly what
  corrupted before.
- **B2 — Network CI-V (LAN) on a non-7760 Icom.** Login must complete (not hang at
  "WaitingForLogin" — that was the exact `df0017a` login-packet bug), then A1–A6.
- **B3 — Edge frequencies.** Tune to values that exercise high BCD bytes, e.g.
  1.999.999 kHz boundaries, 29.999 MHz, 1296 MHz on a 9700/905. Read back exact.

**Pass:** serial and LAN CI-V both byte-accurate on every Icom you use.

## Group C — SO2R via the YCCC SO2R box  (P1-8 · `uYCCCSO2R`, OTRSP over USB HID)

Your YCCC SO2R+ box is native (`YCCC SO2R ENABLE = TRUE`), driven by **OTRSP over
USB HID** — so it's *off* the serial-byte path, but its OTRSP command and CW
buffers are string→byte paths worth watching.

- **C1 — Two radios up.** Radio 1 and Radio 2 each read/set frequency independently
  (repeat A1/A2 per radio).
- **C2 — Focus switching.** TX focus + CW route to the correct radio via the box;
  no cross-talk (a command/CW meant for R1 never lands on R2).
- **C3 — RX audio routing.** RX1 / RX2 / stereo (both ears) switch correctly from
  TR4W (`YCCCSetRxMode`/`YCCCSetStereo`).
- **C4 — OTRSP CW through the box.** Send CW routed through the YCCC box's keyer
  (`YCCCAddCWMessageToBuffer`); verify the keyed text is correct and speed changes
  take effect — this is the string→byte path in the OTRSP driver.
- **C5 — Soak.** A few minutes of realistic SO2R switching; no stuck focus, no
  dropped commands, `tr4w.log` clean.

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

## Group E2 — Rotator (Green Heron RT-21 via PSTRotator)  (control/UDP path)

TR4W drives your rotator by sending the beam heading to **PSTRotator over UDP**
(`PSTROTATOR IP ADDRESS` / `PSTROTATOR UDP PORT`, Issue #732), which relays to the
Green Heron RT-21. The heading is sent as text over UDP, so a string-boundary bug
would send a wrong/garbled azimuth.

- **E2a — Turn to a callsign/spot.** Trigger "turn rotator" for a DX call or a
  band-map spot; PSTRotator receives the **correct azimuth** and the RT-21 turns
  there. Confirm the degrees match the beam heading TR4W shows.
- **E2b — A few different headings** across 0–360° (including one past 180° and one
  near 0/360 wrap) to be sure no value is corrupted.

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

## Known anomalies (tracked, NOT release blockers)

Behaviors found during bench testing that are pre-existing (present in the D7
build too) and therefore not D12 regressions. Logged so they aren't re-diagnosed
as migration bugs. *(NY4I to fill in specifics — radio settings, exact values,
D7 vs D12 comparison, severity.)*

- **A-1 — IC-7100, split mode: VFO B display goes stale.** In split, the program's
  VFO B (Radio 2 / VFO B) shows the frequency VFO B held **at connect**, not the
  current VFO B frequency; changing VFO B on the radio does not update the display.
  Confirmed present in **D7 as well** (2026-07-19, NY4I) → pre-existing, not a D12
  regression. Root cause: the IC-7100 has no `$07 $D2` active-VFO query, so TR4W
  tracks only the **active** VFO (A) — its frequency arrives via CI-V `$00`
  transceive pushes — while VFO B is read only once at connect and never re-polled
  (`PollRadioState` polls RIT/XIT/split/TX, not frequency). Potential fix if
  revisited: add a ~1 s poll of the inactive VFO's frequency (`$25 $01`) to
  `PollRadioState`, gated on `FDirectFreqRoute`. *(details: )*

## Phase 3c: entry-field key bindings -- ALL PASSED on the bench (2026-08-18)

The callsign and exchange fields' keyboard handling moved off the hand-rolled
GetMessage loop and onto the LCL controls in `89b91cdd`. NY4I bench-tested the
whole list the same day. **Everything passed, including all four items that
needed a radio.**

Checked without hardware: typing, `?` / `/` substitution, space and right-arrow
between the fields, arrow tabbing, Up-on-empty-callsign opening the last QSO,
PgUp/PgDn CW speed, Alt and Ctrl showing the function-key row.

Checked with a radio:

| binding | result | why it was at risk |
|---|---|---|
| **F1-F12**, and F4 leaking no character | PASS | the F-key arm and the F4 consume are separate `if`s in the moved code; a wrong order shows only as a stray character |
| **Ctrl+=** repeat last CW message | PASS | `'='` alone is QUICK QSL KEY 2, so the Ctrl test is what keeps them apart |
| **Apostrophe** start-sending | PASS | the only surviving arm of the loop's `WM_KEYUP` block -- the single check that `CallKeyUp` is reached at all |
| **Left / right Shift** RIT bump down / up | PASS | **the one binding that is not a copy.** The loop read the scan code from `Msg.lParam` (42 left, 54 right); an LCL `OnKeyDown` has no `lParam` and the win32 widgetset does not split `VK_SHIFT`, so it is re-expressed as `GetKeyState(VK_LSHIFT/VK_RSHIFT)` -- a different mechanism answering the same question |

The Shift pair remains the one genuinely Windows-only line in `TTR4WEntryEvents`:
no LCL cross-platform API distinguishes the two shift keys, so it needs a
per-platform answer whenever a macOS or Linux build is attempted. Passing here
does not change that.

## ShortString display overruns -- ALL PASSED on the bench (2026-08-18)

`56a8ae97` and `c523ac6b` fixed six main-window fields that read a `ShortString`
through `PAnsiChar(@X[1])` -- past the length byte, into stale bytes from a
longer previous value. NY4I found it as **"K3Sio 2" for a radio named K3S**
("K3S" + the "io 2" left behind by "Radio 2").

Confirmed clean: **radio names, beam heading, user info, grid/locator.** The WAE
QTC callsign field (`LOGWAE:453`) is the same fix and was not staged -- it shows
only in WAE contests.

Grid/locator is worth a note for whoever checks it next: it is written only from
`DisplayBeamHeading` (`LOGWIND.PAS:1421`), needs `MyGrid` set and the callsign to
resolve to a grid, and `tBeamHeadingPrevState` suppresses a redraw when the grid
has not changed -- so it takes a call from a different country to force one.

## Reporting

For each group, note PASS / FAIL / N-A and, on any FAIL, attach the relevant
`tr4w.log` excerpt (with `DEBUG LOG LEVEL = DEBUG`) and any serial-sniffer capture.
A FAIL in Group A or B most likely points back at a byte-boundary path the port
touched; the log hex is what pins it.
