# TR4W — Delphi 12 Migration Roadmap (what remains)

**Date:** 2026-08-02 (updated overnight: **Track A complete except the CI runner**; C-1 closed) · **Branch:** `delphi12` · **Purpose:** one place that answers
"what is left before we call the D12 migration *done*".

This document does not restate designs. It reconciles the existing plans —
[`tr4w-migration-strategy.md`](tr4w-migration-strategy.md),
[`D12_RELEASE_READINESS.md`](../tr4w/docs/D12_RELEASE_READINESS.md),
[`D12_STRING_MODERNIZATION_PLAN.md`](../tr4w/docs/D12_STRING_MODERNIZATION_PLAN.md),
[`PHASE_INVENTORIES.md`](PHASE_INVENTORIES.md),
[`LEGACY_DEPENDENCY_AUDIT.md`](LEGACY_DEPENDENCY_AUDIT.md),
[`RADIO_BENCH_STATUS.md`](RADIO_BENCH_STATUS.md),
[`BENCH_TEST_PLAN_2026-08-01.md`](BENCH_TEST_PLAN_2026-08-01.md),
[`D12_HARDWARE_TEST_PLAN.md`](../tr4w/docs/D12_HARDWARE_TEST_PLAN.md) — into a single
ordered picture, and separates *migration* work from *post-migration* work that
several documents mention in the same breath.

---

## 0. Definition of done

**The D12 migration is done when a Win32 D12 build replaces the Delphi 7 release
and no part of the release pipeline still needs Delphi 7.**

That is the scope line already set in `D12_RELEASE_READINESS.md`. It deliberately
excludes 64-bit, VCL/FMX, SQLite, and the contest factory — see §7.

Three conditions, all of which have open items today:

1. **Nothing in the build or release path requires D7.** (One dependency left: the server.)
2. **Every surface the ASCII-only golden corpus cannot see has been verified live** —
   non-English text, network/SSL, CW timing, radios, mixed-version wire.
3. **The evidence is written down** — bench table filled in, known divergences filed,
   stale docs corrected.

---

## 1. Where the phases actually stand

| Phase (from `tr4w-analysis` / `tr4w-migration-strategy`) | Status |
|---|---|
| **Phase 1 — compile under D12, Win32** | ✅ Complete. Builds via `msbuild tr4w.dproj`; golden corpus 22 pass / 0 fail / 4 known-divergence. |
| **Phase 2 — Unicode / string correctness** | 🟡 Substantially done. Leaf interiors flipped, Win32 display chain on W-APIs, ListView A→W, CI-V byte paths byte-faithful. Four intentional deferrals remain (§5). |
| **Phase 3 — 64-bit** | ⛔ Not started, and **out of scope for this migration** (§7). `asm` inventory cataloged; convertible blocks already removed; the hardware/RTL tail is parked. |
| **Phase 4 — modernization (VCL/FMX, contest factory, DUnitX)** | ⛔ Not started as a phase — but two pieces were **pulled forward** and executed under the strangler pattern: the **radio factory** (complete, 99 registered radios) and the **CW keyer factory** (Phases A and B complete, plus the CAT repoint in `edc9cbf`). |

The consequence worth stating plainly: **the largest remaining piece of work on the
branch right now — deleting the legacy radio path — is not migration work.** It is
Phase-4 modernization that happens to be in flight. It can be finished after a D12
release ships, and §6 treats it as its own track.

---

## 2. Track A — Release mechanics (the only true build blockers)

| # | Item | Evidence | Status |
|---|---|---|---|
| A-1 | **`tr4wserver.exe` under D12** — was the last Delphi 7 dependency in the project. | `16412f1`, `1bea7af` | ✅ **DONE 2026-08-02.** Builds via msbuild, 0 errors / 0 warnings with hints+warnings ON; NY4I connected a client and logged a record. The two copies were a **two-way fork**, not a stale copy — see the note below. |
| A-2 | **Installer packaging.** | `e610aa2` | DONE 2026-08-02. `FullBuild.ps1 -BuildInstallers` runs end to end: 1489 tests -> app -> **step 2b tr4wserver** -> 116 source files verified -> `tr4w_setup_4.149.0.exe` (6,883,849 bytes) -> VirusTotal 5/71, below the CI threshold. First complete installer producible since the migration began. **Payload caveat:** those are DEBUG binaries with UPX skipped -- packaging is proven, the artifact is not shippable until built Release + `-UseUpx`. |
| A-3 | **`release.yml` on msbuild.** | `e1c1f48` | DONE 2026-08-02. `DELPHI7_BIN` -> `STUDIO_BIN`, the DCC32.EXE presence check -> `rsvars.bat`, both `-Delphi7Bin` arguments dropped, runner docs updated. `FullBuild.ps1` also lost the dead `$DCC32` / `$PROJECT` / `$LIB`. **Still needs RAD Studio installed on the self-hosted runner** -- that is now the only prerequisite. |
| A-4 | **`BuildServer.ps1`** repointed to msbuild; `FullBuild.ps1` calls `Invoke-MSBuild` on the `.dproj` directly and no longer treats a server failure as expected breakage. The DCC32 existence check is gone from `-BuildInstallers`, so **`FullBuild.ps1` is D7-free end to end**. | `76de84c` | ✅ **DONE 2026-08-02** |
| A-5 | **Packaging/doc staleness.** | `e610aa2` | Partly done 2026-08-02. Version skew fixed at the root: `full.nsi` no longer carries a hardcoded fallback (it had drifted to 4.148.1 vs Version.pas 4.149.0) and now `!error`s if `/DTR4WVERSION` is absent; the dead `make_setup_file.bat` (pointing at a non-existent `D:\...\NSIS`) is now a shim onto FullBuild. **`pota_parks.csv` was a FALSE ALARM** -- `uPOTAParks` downloads it on demand from pota.app, so shipping a 9 MB stale copy would be wrong. **Doc staleness CLOSED 2026-08-04:** `tr4w/CLAUDE.md` was corrected (`cf287c4d`) and then folded into the root `CLAUDE.md`, which was itself still the D7 port. There is now one CLAUDE.md. |


### A-1 postscript — the two copies were a two-way fork

Worth recording because the obvious reading was wrong and nearly cost us a feature.
`tr4w\src\tr4wserverUnit.pas` (`a3b4da1`, Jul 10) had the `AnsiChar` wire conversion but
**not** the server logging. `tr4w\tr4wserver\src\...` (`60620b2`, Apr 16, *"TR4WServer
logging"*) had `InitServerLogger`, the `logger` global, bind-failure and `sRecv` tracing,
the GPL header and `Version` — but D7 `Char` buffers. Each side had work the other lacked,
so it needed a **merge**: deleting either copy silently dropped something. The `.dpr` called
`InitServerLogger`, which existed only in the copy nobody was compiling. The fork is now
deleted; `tr4w\src\` is the single source of truth.

Three D7→D12 gaps found, all worth remembering:

1. **Winsock signatures moved in BOTH directions.** `bind` went pointer → `var`; `accept`
   went `var` → pointer. There is no blanket rule — check each call.
2. **`TF_DISCONNECT`** came from the vendored `WinSock2.pas`; the RTL's `Winapi.WinSock2`
   declares no MSWSOCK extensions.
3. **`GetPrivateProfileString` bound to the W variant** and wrote UTF-16 into an `AnsiChar`
   buffer, so the server rejected **every** client (`1bea7af`). It compiled silently *with
   warnings on*, because `@buffer` is an untyped `Pointer` and there is nothing for the
   compiler to check. **W1057 cannot see this class of bug and neither can the linters** —
   any remaining `@buffer` passed to a *generic* Win32 name must be found by reading.

### C-1 postscript — the cluster did not use Indy (it does now)

> **Superseded 2026-08-04.** The finding below was accurate when written and is
> kept because it explains what was there. `uTelnet` has since been moved to
> `TIdTCPClient` with line-based reads (`99ef30fb`, `bce1262e`) — not for D12
> correctness, which was fine, but because the raw-Winsock reader dropped any DX
> line split across two TCP segments. Re-verified live on AR-Cluster.


The roadmap ranked C-1 top risk on the grounds of vendored Indy 10.6.3.3. That reasoning
does not apply: `uTelnet.pas` uses **no Indy at all**. It is raw Winsock with `AnsiChar`
buffers, and every text-carrying Win32 call already uses the explicit A variant
(`SendMessageA`, `GetMenuStringA`, `AppendMenuA`, `SetWindowTextA`, `lstrcpynA`). The
tooltip path looks wrong at a glance — an `AnsiChar` buffer assigned to `TOOLINFO.lpszText`,
whose RTL definition is `LPWSTR` — but `uTelnet` uses a project-local `uCommctrl` where
`TOOLINFO.lpszText: PAnsiChar` and `TTM_* = TTM_*A`, and `TTM_*` are `WM_USER+n` messages
that `SendMessageW` does not translate. Self-consistent, and correct.

Indy is used by `uCTYUpdate`, `uGetScores`, `uHamScore` (`IdHTTP` + `IdSSLOpenSSL`),
`uExternalLoggerBase` (`IdTCPClient`), `uCFG` / `LogCfg` (`IdUDPClient`) and `MainUnit`
(`IdHTTP`). The CTY.DAT download proves the `IdHTTP`+SSL path; **score posting and HamScore
remain the untested SSL surface**.
**Already done, do not redo:** `FullBuild.ps1` fully on msbuild including all 8 language
variants and the parallel-worktree path (C-1); `-$A8`/`-$Z1` pinned in the `.dproj` and
verified wired (C-3); stale D7 `tr4w.cfg` removed.

---

## 3. Track B — Text and language (the P0 surface)

| # | Item | Status |
|---|---|---|
| B-1 | **Source-literal encoding.** All 10 tractable lang files transcoded to UTF-8 + BOM from their *true per-language* codepage (1251 rus/ukr/mng, 1250 pol/cze/rom/ser, 1252 esp/ger/eng). `{$CODEPAGE}` is FreePascal-only — Delphi rejects it (`E1030`); the BOM is the mechanism. | ✅ Applied (`8dd9ef8`, `1ff2053`) |
| B-2 | **Rendered-UI eyeball for each language.** The 8 non-ENG variants *build* green; nothing has confirmed they *render* correctly. The golden corpus cannot see this — every fixture is pure ASCII. | 🔴 Open — needs a human, 8 exes |
| B-3 | **POL** — known-bad mixed-encoding file, excluded from the build (issue #925). | ✅ **Decided 2026-08-02: skipped.** Stays excluded from the build; not a release gate. |
| B-4 | **CHN** — pre-existing data corruption, not a directive gap: ~196 bytes invalid even under GB18030. Needs a Chinese-literate maintainer. | ✅ **Decided 2026-08-02: skipped.** Parked until a Chinese-literate maintainer recovers intent. Do not ship. |
| B-5 | **Non-ASCII regression coverage (P1-5).** Either add non-ASCII fixtures (config parsing, CTY.DAT names, UI strings) or explicitly accept the gap in writing. | 🟢 Open |

**Recommendation stands from the readiness doc:** ship **English-only first**, then
release languages one at a time as each UI is eyeballed. B-2 does not block an English
release, and with B-3/B-4 decided the language matrix for this migration is **ENG + 8**
(RUS, SER, MNG, CZE, ROM, GER, UKR, ESP) — POL and CHN are out.

---

## 4. Track C — Live/bench verification (the largest open block)

Nothing here is provable by code review. All of it needs hardware or a second station.

| # | Item | Plan reference | Status |
|---|---|---|---|
| C-1 | **Telnet / DX cluster / SSL** on the D12 binary. | P1-6 · **Group F** | ✅ **DONE 2026-08-02.** Cluster connects and logs in; CTY.DAT downloads over HTTPS (so vendored Indy + the bundled OpenSSL DLLs are proven); `{TOKEN}` expansion verified. Code audit found **no** defect — see the note below. **Re-verified 2026-08-04** after the Indy move: spots decode from a real AR-Cluster node, and auto-reconnect after a node drop is confirmed working (NY4I). Remaining SSL surface: score posting, HamScore. |
| C-2 | ~~**Two-station D7 ↔ D12 wire test**~~ **RETIRED as written** — all stations run the same build by convention (NY4I). `ContestExchange` has zero plain `Char` fields and the corpus reads D7-written binaries, so the shared record is byte-stable. Replaced by a **two-client** test of the server's own `AnsiChar` paths — see §9. | — | 🟡 Rescoped 2026-08-02 |
| C-3 | **CW / WinKeyer / DVK / DVP timing.** | P1-8 · **Group D** | 🟡 Partly done — WinKeyer latency + startup verified on the K3 (383 ms → 25 ms; 1978 ms → 0.4 ms) |
| C-4 | **CW-by-CAT send, every radio.** `SendCW` now has one path for all families and three drivers emit `KY` for the first time. Highest-risk item on the branch. | `BENCH_TEST_PLAN_2026-08-01` §1–2 | 🟡 K3/K4 verified, and **K3S over USB serial re-verified 2026-08-04** for both CW-by-CAT and CW speed sync after the capability/framing rework (`a9e77155`, `4a7f9833`) — the K3 pad-to-22 quirk survived the move onto `TElecraftSerial`. Still untested: **K2, KX3, Kenwood, Flex-on-COM, Icom long-message split, TCI** |
| C-5 | **Ten-Tec Orion CW** — never worked (`#13` inside a quoted string is three literal chars). Fix is unverified; NY4I sourcing a radio. | §3 | 🔴 Blocked on hardware |
| C-6 | **Freq / mode / split / DVK on every radio** after ~900 lines of legacy `SetRadioFreq` encoders were deleted. No fallback remains to mask a failure. | §6 | 🔴 Open |
| C-7 | **SO2R** — YCCC box (Group C) and the two-radio CW-by-CAT interlock (asymmetric 500 ms sleep). N4AF owns validating the interlock. | Group C · §"Known NOT covered" | 🔴 Open |
| C-8 | **Digital modes** (WSJT-X `htonl`), **rotator** (Group E/E2). | Groups E, E2 | 🔴 Open |
| C-9 | **Bench coverage table.** 5 of 99 registered radios have a report (K3, K4, Flex, IC-718, TS-570, plus the IC-706 family divergences with no date/tester). This table **is the gate** on legacy deletion. | `RADIO_BENCH_STATUS.md` | 🟡 5/99 |

> C-9 deserves a realistic policy. 99 radios will never all be bench-tested by one
> station. The practical gate is **one verified radio per protocol family** — Elecraft
> serial ✅, Elecraft network ✅, Kenwood serial ✅, Icom serial ✅, Flex CAT ✅,
> Icom LAN ❌, Yaesu binary ❌, Yaesu ASCII ❌, HamLib ❌ — plus a tester program for the rest.
> Four families unproven is the honest number, not ninety-four radios.

---

## 5. Track D — String modernization tail (Phase 2 remainder)

All four are **deliberate deferrals**, and none blocks a D12 release. Listed so they
are not mistaken for oversights.

| # | Item | Why deferred | Blocks release? |
|---|---|---|---|
| D-1 | **MainUnit editable-log renderer** (`tAddContestExchangeToLog`) stays on the A-path | Entangled with ~15 ANSI `ContestExchange` DTO reads; converts *with* the SQLite work. Keeps a few `inttopchar` consumers alive. | No — renders correctly today |
| D-2 | **Telnet socket I/O centralization** (one decode after `recv`, one encode before send) | A parser rewrite (byte-offset DX-spot matching), not a cast tweak | 🟢 **Largely done 2026-08-04** — transport on Indy (`99ef30fb`), session/reconnect fixed (`63158d61`, `82718ef3`), decoder split out and under test (`uDXSpotParse`, 27 fixtures). See below |
| D-3 | **Vendored Indy + `src\MMSystem.pas`** replaced by D12's RTL | — | ✅ **Decided 2026-08-04: NO.** See below |
| D-4 | **Low-value shims** — `StrComp_JOH_IA32_6`, `BooleanToStr`, `RealToStr2`, `tCreateEditWindow`, `CopyFileA`/`FileExists` | Cost/benefit | No — not attempted |
| D-5 | **Lint enforcement** (`Lint-PCharAnsi.ps1`) wired into the build so a new unmarked `PAnsiChar` in the logic layer fails | — | ✅ **Done (`fb3459e5`)** |

### D-5 postscript — the lint could not just be switched on

It reported 5 violations and **all 5 were false**: four inside a `{ … }` block
comment (it stripped only *trailing* single-line comments), one genuinely wide
(`array of Char` IS WideChar under D12). A linter that fires on commented-out
code gets ignored, so it was taught to read Pascal — block-comment state carried
across lines, `{$IFDEF}` correctly treated as live code, braces and `//` inside
string literals ignored. Verified against a fixture: 7 true positives caught, 3
negatives suppressed. Now gates the build: *"Lint-PCharAnsi: 296 source files
checked, no D12 PChar hazards."*

### D-3 postscript — the premise had expired

Do **not** execute this as written. `WinSock2.pas` is already retired
(`.d7-shadow`), so the project is on RTL Winsock already. The vendored Indy is
**10.6.3.3**, while D12 ships Indy as **DCUs only** — `Studio\23.0\source\Indy`
contains just the IPPeer abstraction. Swapping is plausibly a *downgrade* and
loses source-level debuggability of the SSL path C-1 just verified. What is left
worth removing is `src\MMSystem.pas` and the `.d7-shadow` leftovers, not Indy.

### D-2 postscript — transport moved, parser deliberately left

`99ef30fb` extracted the cluster socket into `TDXClusterClient`
(`src\uDXClusterClient.pas`): `TIdTCPClient`, a reader thread, three events, no
UI and no globals — constructible in a test EXE. `TelnetSock` is deleted (it was
a connected-flag in four places); callers use `uTelnet.TelnetIsConnected`.

**It fixed a real defect found by reading:** the old reader posted whatever one
`recv()` returned and the parser restarted its line scan per chunk with no
carry-over, so **a DX line split across two TCP segments was cut in half and
both halves discarded** — the spot lost silently, since neither fragment matches
`"DX de "`. Indy buffers to the terminator.

`ProcessDX` — 494 lines of fixed-column byte-offset decoding tuned against real
nodes' padding — is **untouched on purpose**. Each whole line is handed to the
existing parser with its CR restored (it scans for `<= #13` to end a line). Get
it under test first, rewrite second.

**Fixture test landed (`a93cbec8`)** — `test/unit/uTestDXClusterClient.pas`, an
in-process `TIdTCPServer` on loopback serving a known call/frequency table. The
segment-split test carries a **negative control**: it looks during the 150 ms
gap between the two half-line writes and requires zero lines, so it cannot pass
by the two writes coalescing. Plus a 200-spot ordering burst. No external
process; `mockDXCluster` stays unmodified and is not required to run it.

**LIVE-VERIFIED 2026-08-04 (NY4I): spots decode correctly from a real
AR-Cluster node, and the unified `UP n` handling works.** That re-runs C-1 for
the Indy move and covers the parser end-to-end on a node whose software is
*not* DXSpider — worth stating, because the decoder's fixed column offsets are
exactly the thing that varies between cluster softwares.

Still unproven on a live node: the segment-split path (not observable from the
outside — it is the fixture test's job) and a long session.

### D-2 postscript (2) — what live use found that 1,704 green tests did not

Two defects surfaced within a minute of NY4I running the Indy build against a
real node. Both were in the *session* layer, which the fixture test does not
model, and both are now fixed:

- **`63158d61` — a peer close left the toolbar showing a live session and
  blocked reconnect.** The guard was `IsConnected`, which is the socket's
  opinion, not the session's. It is now `TelnetSessionActive`, set and cleared
  where the session begins and ends.
- **`82718ef3` — auto-reconnect.** Gated on `CONNECTION AT STARTUP`, 5 s
  doubling to a 60 s cap, retrying forever; cancel-then-disconnect ordering on
  the button so the operator's disconnect is not immediately undone by a pending
  retry. **NY4I confirmed 2026-08-04: "the new reconnect change works well."**

**Known gap, deliberate:** a *send* failure tears the session down without
arming a retry — `SendViaTelnetSocket` calls `Disconnect` directly, clearing
`TelnetSessionActive` before the reader's `TELNET_CLOSED` arrives. **Owed test:**
a fixture case where the *server* closes, asserting the reconnect. That is the
case that would have caught `63158d61`.

### D-2 postscript (3) — the decoder is now split, and under test

**Done 2026-08-04.** `ProcessDX` decoded *and* applied in one function: in the
same 313 lines it read the columns and then called `VisibleLog.CallIsADupe`,
`VisibleLog.DetermineIfNewMult`, `SpotsList.AddSpot`, `QuickDisplay` and
`SendMessageA` on the alert list box. That mixture — not the byte arithmetic —
is why the decoder had no test: linking it meant linking `MainUnit`, the bandmap
and the window layer.

- **`src\uDXSpotParse.pas` (new)** — `ParseDXSpotLine(const Line; out Spot)` and
  `ParseDXSpotTimeUTC`. Pure functions of the line: no globals, no I/O, no window
  handles. `TokenAt` moved with them.
- **`uTelnet.ProcessDX` keeps the apply half** — dupe, multiplier, band map,
  alert list, display — and calls the parser. The `goto`/`label` is gone with it.
- **The column arithmetic is unchanged, deliberately.** It is tuned against what
  real nodes emit; it moved without being touched, and behaviour was pinned
  first.
- **`test/unit/uTestDXSpotParse.pas`** — 27 tests, fixtures taken byte-for-byte
  from the captured sessions in `D7-LogFilesForTesting/dxcluster` (265 files,
  198,979 `DX de` lines). Suite total is now **1,765 green**.

That corpus also settled what the mysterious `Offset` logic is *for*. 198,977 of
the 198,979 captured lines put the frequency's decimal point on **column 22** —
the field is right-justified, so the columns are genuinely fixed. `Offset`
compensates for the one case that breaks it: a spotter callsign too long for its
field, e.g. `DX de 3V/KF5EYY-#:14007.0  PA3DZM …`, which shoves the frequency and
the DX call one column right. That single line is now a fixture, and it is the
only coverage the `Offset` branches have.

**Three defects found while pinning, all pre-existing (verified against the D7
tree), pinned first and then fixed in the follow-up commit described in
postscript (4):**

1. **`FSourceCall`'s length byte is usually never written.** `SetLength` is
   guarded by "the next column is not a space" while the character copy is not,
   so on the *ordinary* blank-padded line the spotter's characters are present
   but the ShortString reads as length 0. It has never shown because every
   consumer reads `@FSourceCall[1]`, i.e. as a C string. Anything treating it as
   a Pascal string silently gets `''`.
2. **A truncated line decodes as SUCCESS.** The call-scan loop simply never
   matches, so `GoodCallSyntax` is never reached and `ProcessDX` goes on to
   dupe-check and band-map a spot with an empty call and a zero frequency. One
   real line in the 198,979 is cut off like this.
3. **`UP n` does not validate the result.** The `QSX` branch runs its frequency
   through `CalculateBandMode` and discards an out-of-band answer; the `UP`
   branch does not. A real capture contains `UP 200-205`, which lands 200 kHz up
   and outside the band.

**D12-specific trap worth remembering** (cost a debugging cycle, now recorded in
the test): a ShortString passed **by `const`** is copied only up to its *length
byte*. A field whose length byte lies — see (1) — can therefore only be read
through a pointer to the field itself; `const S: CallString` + `@S[1]` reads
stack garbage.

### D-2 postscript (4) — the split/QSX grammar, and what 198,979 real lines taught it

**Done 2026-08-04.** With the decoder under test, the two defects above were
fixed and the comment parser was rewritten. What made this tractable is that the
capture in `D7-LogFilesForTesting/dxcluster` is big enough to be evidence: a
throwaway probe ran the **committed decoder and the new one side by side over all
198,979 lines** and diffed every field. Final state of that diff:

| | |
|---|---|
| callsign differs | **0** |
| frequency differs | **0** |
| newly rejected | **1** — the one truncated line, which is the point |
| source-call length fixed | **198,759** |
| QSX found (old → new) | 814 → 951, **236 differing, each one read** |

**The two defects, fixed:**

1. `FSourceCall`'s length byte is now always written. It had been set only when
   the spotter field was unpadded — i.e. almost never — so the field held the
   right characters and reported length 0. Both readings now agree.
2. A line with no callsign in the call columns is **rejected**. It used to decode
   as a success and be band-mapped with an empty call.

**The grammar (`ParseSplitHint`, exported and separately tested).** One
tokenizer over the comment replaced two hand-rolled scans for `"QSX "` and
`"UP"`. It reads `QSX`, `LISTENING`/`LISTENS`/`LISTEN`/`LSTN`/`LSN`, `RX`,
`SPLIT`/`SPLT`/`SPL`, `UP`, `DOWN`/`DWN`; kHz, MHz (`14.030`) and dotted-MHz
(`21.290.000`) frequencies; prefix (`UP 5`), postfix (`5 UP`, `5UP`) and
fractional (`UP 1.5`) offsets; ranges by their low end; and a spelled-out `MHZ`
unit. Case-insensitive. The old third defect — `UP` skipping the band check that
`QSX` performed — is gone: **one band check applies to every form.**

**AUTO SPLIT (NY4I, 2026-08-04).** A bare `UP`, `DOWN` or `SPLIT` is no longer
treated as unusable: it means **1 kHz on CW, 5 kHz on phone**, the convention the
radios implement under that name. The mode comes from the comment when it states
one (`CW` appears 57,296 times in the capture, `USB` 21,658) and from the band
plan otherwise; on digital, or with no mode at all, nothing is guessed. That
single rule accounts for most of the 137 newly-found QSXs.

**Four false-positive classes the corpus caught — none of which reading the code
would have found:**

- **`DN` is never "down".** All of its occurrences are Maidenhead grid squares
  (DN70, DN27, …), because letters and digits tokenize separately. It was a
  synonym for one probe run, during which ordinary 6 m grid comments decoded as
  "70 kHz down". Dropped.
- **Grids ending in `UP`** — `DM33UP`, `FN32DR<>JN87UP`. A keyword may follow a
  number only when that number starts the word, which keeps the real `5UP`.
- **`PILE UP` / `WHATS UP`** — ordinary English that ends in the word, and which
  the AUTO SPLIT default would otherwise turn into a QSX. Also `NOT SPLIT`.
- **Signal reports in the postfix position** — `59 TU 73 UP`. Offsets are capped
  at 50 kHz, so the `73` is refused while the bare `UP` still gets its default.
  The same cap refuses `UP 200-205`, which the old decoder turned into 14395 kHz,
  outside the band.

**`R` was asked for and deliberately not implemented.** Every `R` and `RX` in
the capture is an FT8 report (`R-17`), `RX ONLY`, or an initial. `RX` is accepted
because the band check makes it harmless; a bare `R` would turn every FT8 report
into a confident wrong frequency.

Suite is now **1,940 green** (37 tests on the grammar alone, half of them
rejection cases).

**Next in this seam:** `ProcessTelnetLine` and the `TelnetStringType`
colourisation still sit in `uTelnet`; the apply half is now small enough to read
in one screen, which is what makes the remaining decisions visible.

**Issue #83 (multiplier hints in the comment — `DN40`, `UT`, `WCF`) is adjacent
but deliberately not done here.** Its prerequisite is the same extraction this
seam has been doing: `LooksLikeAGrid`, `LooksLikeAState` and `LooksLikeASection`
live in `trdos/tree.pas`, which cannot link into the test EXE — exactly why
`CalculateBandMode` was lifted into `uBandLookup`. It also produces a different
output (a multiplier, not a receive frequency), so it wants its own function and
its own field rather than a branch inside the split grammar. The tokenizer and
the corpus method built here are what it should be written on top of.

---

## 6. Track E — Legacy radio deletion (Phase 4, in flight — *not* migration)

> **Owned elsewhere.** As of 2026-08-02 this track is being finished by a separate
> agent session. It is recorded here for completeness and for its one hazard (E-1);
> **do not work it from this roadmap** — coordinate first, or the two efforts will
> collide in `uRadioPolling.pas` and `LOGRADIO.PAS`.

The factory is complete; the legacy path is scheduled for **deletion, not maintenance**.
Still on disk as of this writing: `uRadioPolling.pas` (4,621 lines) and `LOGRADIO.PAS`
(3,160 lines).

**Must land before deletion** — from `LEGACY_DEPENDENCY_AUDIT.md`, in its order:

1. ~~**E-1 Port settings into the class constructors.**~~ **ALREADY DONE — this hazard no
   longer exists.** The roadmap claimed `LOGRADIO.PAS:1571-1578` was the only thing setting
   1 stop bit for `[IC78..IC9700, FT100, Orion]`, and that deleting the legacy would give
   every Icom 2 stop bits. That typeset was replaced by `RadioObject.ResolveSerialFrameSettings`
   (`LOGRADIO.PAS:1562-1606`, commits `8d2880b` / `282d2e9` / `ab4b308`), which resolves
   `RADIO n SERIAL FORMAT` → `uRadioRegistry.SerialParamsFor` → 8-N-2. **Verified 2026-08-02
   by reading the registry, not the compile:** all 40 Icom units, FT-100 and Orion register
   1 stop bit. The old test also had the Omni VI wrong (outside the range, forced to 2
   against its manual); the registry now gives it the documented 1. Note the shipped design
   is NOT the CFGDEF-sentinel one `LEGACY_DEPENDENCY_AUDIT.md:132-147` proposed — that
   document is stale here too.
2. **E-2 Icom / TS-890 credentials off the `is`-casts** (`LOGRADIO:3139-3160`) onto a
   virtual `ApplyCredentials` or construction-time config.
3. **E-3 The remaining `InitRadios` capability sets.**
4. **E-4 Then delete** — which also retires those files' rows from the Phase-2/3
   inventories (`uRadioPolling`, `LOGRADIO`, part of `LOGK1EA`).

Gate: **C-9's per-family coverage**, not per-radio.

Also on this track: `SendCW`'s CW-by-CAT orchestration has now moved into `uCWKeyerCAT`
(`edc9cbf`, bench-verified `75b9425`), closing the "still to do" item in the 08-01 bench
plan. The CW keyer factory's remaining trajectory — `uCWKeyerCPU` absorbing LOGK1EA's
dit/dah engine, `uCWKeyerWinKey` absorbing the WinKeyer protocol, LogCW shrinking to a
facade — is future work, not planned in the current phase.

---

## 7. Explicitly NOT part of "migration done"

These appear in the docs and are real work, but gating the migration on them would
mean the migration never finishes. Each is a **post-D12 project**.

| Item | Where it lives | Note |
|---|---|---|
| **64-bit (Phase 3)** | `PHASE_INVENTORIES.md` | The convertible `asm` is already gone; the remainder is a hardware/RTL/decision tail (`BeepUnit` port I/O, `LPTIO`/`DLPortIO`, `MainUnit` RDTSC + LPT IOCTL, `uCRC32` — which must stay byte-identical to on-disk log CRCs). Separate target platform. |
| **VCL / FMX forms (Phase 4)** | `VCL_WIN32_COEXISTENCE.md`, `dialog_analysis.md`, `FMX Migration Discussion.md` | Technique proven on branch `Add-VCL-to-Program` (`67785ae`). First FMX form is deliberately the **WinKeyer settings dialog** as a toolchain pathfinder — not dialog 66, which is where the value is but the worst place to debug FMX. The Mac/Linux ports-and-adapters sketch is a direction, not a plan. |
| **`ContestExchange` → object + SQLite (Phase 5)** | string plan §5 | v1.7 binary is the frozen DTO until then. Pulls D-1 with it. |
| **Contest factory** | strategy doc §Phase 4 | Genuinely Phase 4 — needs stable class hierarchies + the SQLite log. |
| **New Contest dialog redesign** | `NEW_CONTEST_DIALOG_DESIGN_BRIEF.md` | A **new feature**, not migration. Its own text says "awaiting implementation after TR4W port". Tier 1 needs a modern UI framework (so it follows the FMX/VCL decision); Tier 2 needs the contest factory. |
| **Native TCI radio driver** | `TCI_Radio_Implementation_Plan.md` | Design only, no code. New feature; the HamLib bridge covers TCI today. |
| **TRDOS extraction + unit tests** | strategy doc items 5–9 | `uCabrilloFormat` extracted ✅ (item 6). Scoring, exchange parsing, and dupe-check extraction remain — the dupe spike concluded `DupeAndMultSheet` is not testable without an M–L extraction. The golden corpus covers all of it at the *output* level, which is why this is not a migration gate. |
| **DUnitX runner** | strategy doc | Trivial when wanted; the current framework is deliberately DUnit-compatible. |

---

## 8. Evidence debt (small, do before sign-off)

- ~~**P2-9** — the IARU golden fixture passes purely by list membership, and `is_known`
  overrides `GOLDEN_STRICT`, so an aborted export is masked identically to a known
  divergence. Regenerate `iaru_hf_2026_ny4i` so the divergence is *demonstrated*.~~
  **DONE 2026-08-13.** Two separate defects were behind this, not one:

  1. `iaru_hf_2026_ny4i` sat in `export-d12-corpus.sh`'s `SKIP` list ("pops an
     interactive dialog"), and that listing had gone **stale** — the set exports
     cleanly today (exit 0, both artifacts, no dialog). While it was skipped its
     divergence was asserted by `known-divergences.txt` and never once shown. It
     now exports and the diff is real: the sent zone falls back to MY STATE
     (`59  8` → `59  FL`) while the received zones (8, 27) read correctly —
     exactly what the file claims. `SKIP` is now empty.
  2. `is_known` excused a **missing candidate**, so "exports and differs for a
     tracked reason" and "produced nothing at all" were the same result — on the
     oracle every other check in this tree leans on. A missing candidate is now a
     strict FAIL for **every** set, with no exemption. Verified by hiding a known
     set's candidate: it reported `KNOWN` before and `FAIL` after.

  Corpus after the fix, on **both** compilers: 22 passed, 0 failed, 4
  known-divergence — the same headline as before, with every row now backed by a
  diff instead of by list membership.
- **P2-10** — file the 4 benign golden divergences (2 contests × 2 formats; sent
  exchange rebuilt from the `MyZone` session global) as a tracked issue. Pre-existing
  D7 quirk, not introduced by D12. **Documented in full** at the foot of
  `tr4w/test/corpus/known-divergences.txt` (2026-08-13), including the demonstrated
  diff and the fix direction — store the sent exchange with the QSO instead of
  rebuilding it from session globals at export time. **Tracked as TR4W-D12 issue
  #2** ("Event sourcing issue in log record creation"), where the four diffs are
  attached as its concrete instances — the issue predates this item and is the
  same defect, so no second issue was opened. **DONE 2026-08-13.**
- **A-5** — the doc/version staleness above.

---

## 9. Critical path

*Updated 2026-08-02 (late): **Track A is complete except the runner**. A-1/A-2/A-3/A-4 and C-1 done; C-2 rescoped.*

```
   A-1 tr4wserver on D12       DONE (16412f1, 1bea7af)
   A-2 installer packaging     DONE (e610aa2)  tr4w_setup_4.149.0.exe builds end to end
   A-3 release.yml on msbuild  DONE (e1c1f48)  -- needs RAD Studio on the runner
   A-4 build scripts           DONE (76de84c)  -- no DCC32 anywhere
   C-1 telnet/cluster/SSL      DONE
                                                    |
   C-3..C-8 CW + radios (one verified radio per family)  ==>  ENGLISH D12 RELEASE
   A-5 CLAUDE.md staleness      DONE (2026-08-04)        ==>
                                                    |
   B-2 per-language UI eyeball  ==>  LANGUAGE RELEASES (8)

   E-1 DONE  >  E-2 credentials  >  E-3 Icom quirk sets  >  E-4 delete legacy
```

**C-2 is retired as written.** Per NY4I, all stations on a network run the same build by
convention, so there is no D7↔D12 wire to defend. The residual question — whether a shared
record widened — is answered: `ContestExchange` has **zero** plain `Char` fields (`ceClass`
is a `string[3]`, and a `ShortString` stays `AnsiChar`), and the golden corpus reads real
**D7-written** binary logs (2021/2024 fixtures) at 22 passed / 0 failed / 4 known-divergence.
That also means a `serverlog.trw` from a D7 server stays readable by the D12 server.

What replaces it is narrower: client and server compile the *same* `VC.pas`, so a shared-record
mistake would be symmetric and self-cancelling. The real exposure is only where the server has
its **own** declarations that must match bytes the client sends — exactly where `1bea7af` was.
The remaining test is therefore **two clients at once**: watch the client list render both
names and IPs, drop one, confirm the other is told cleanly. That exercises every server-local
`AnsiChar` path (`AddSocketToArray`→`clIPAdr`/`clName`, `SetComputerID`→`clID`,
`SendDisconnectMessage`, `DisplayClients`) in one pass.

**Shortest honest path to "migration done" from here:**

1. **Provision RAD Studio on the self-hosted CI runner.** This is now the *only* thing
   standing between the tree and an automated D12 release, and it is procurement/setup
   lead time rather than engineering. Everything else in Track A is done.
2. **C-4 / C-6** — one verified radio per protocol family. Four unproven: Icom LAN,
   Yaesu binary, Yaesu ASCII, HamLib. Calendar-bound, not effort-bound.
3. ~~**A-5 remainder** — rewrite `tr4w/CLAUDE.md`.~~ **DONE 2026-08-04.** `tr4w/CLAUDE.md` was
   corrected for D12 (`cf287c4d`) and has now been **folded into the root `CLAUDE.md`**, which was
   itself still the D7 port (DCC32 recipe, 117 units, "no OOP framework", `LOGRADIO` as the radio
   layer). One file now; do not reintroduce a second.
4. **Build a Release-configuration installer** (`-UseUpx`) and confirm the payload, not
   just the packaging.

Item 4 needs no hardware. Item 2 is the long pole; item 1 is the blocker.

---

## Track F — Radio configuration as a library (branch `vcl-removal` → `fmx-coexistence-spike`)

Started 2026-08-05 at NY4I's direction, from an observation made while bench-testing the
Icom work: TR4W has exactly two radio slots and the configuration **is** those slots, so
describing a radio and activating it are the same act. An operator with four rigs retypes a
whole slot every time they change which one is connected. TR4QT separates the two ideas;
this track does the same.

The layering is deliberate, because the top of it may not survive the gate:

| Unit | Depends on | Testable? | State |
|---|---|---|---|
| `uRadioConfigStore` | RTL only | yes — 156 assertions | **done** `e36bbf8b` |
| `uRadioConfigLegacyMap` | the store | yes — 17 tests | **done** `e8002ad2` |
| `uRadioConfigApply` | uCFG, uCAT, LOGRADIO, … | no, by construction | **built** `b85220bc`, bench owed |
| FMX preferences UI | the above | — | **gated** on the spike |

**F-1 VCL eviction — DONE (`0be4603e`).** TR4W has no VCL user interface, yet linked four VCL
packages for one `TTimer`, one file-open dialog, `Vcl.Consts` inside a logging library, and
seven `uses` entries that were never referenced. Removed so that the FMX question is a
two-way one, not three. `uWinTimer` (`9e05572a`) replaces `ExtCtrls.TTimer` and is documented
as a stepping stone to `FMX.Types.TTimer`.

**F-2 store + renderer — DONE.** Radios and profiles persist to `settings\tr4wradios.ini`,
kept separate from `tr4w.ini` because `GroupRadioIniKeys` rewrites the legacy `[Radio]`
section wholesale. `SeedFromLegacyIni` builds definitions from an existing station's
configuration read-only. The renderer emits the **complete** CFGCA key set every time; a
partial write leaves keys from the previously configured radio, which reads as a radio fault
rather than a configuration fault. A pin test compares the emitted set against a hand-typed
golden list from CFGCA.

**F-3 apply — BUILT, BENCH OWED (`b85220bc`).** Writes the keys, `CheckCommand`s each, closes
**both** slots before writing **any** key (swapping two radios on one COM port is the ordinary
case), re-initialises the keyer once at the end, and does **not** `TerminateThread` the way
the legacy dialog does. Startup needs nothing from it: the keys were written at the last
apply, so `ReadInConfigFile` loads them exactly as before.

**F-4 FMX coexistence spike — HARD GATE, built and awaiting the bench (`77d82600`).**
See **[`tr4w/docs/FMX_WIN32_COEXISTENCE.md`](../tr4w/docs/FMX_WIN32_COEXISTENCE.md)** for the checklist. Verified on
the dev machine: builds, starts, corpus 22/0/4, FMX costs 4.8 MB of code. Everything about
keyboard isolation, thread marshalling and stability needs NY4I's station. If the gate fails,
the fallback is a native Win32 dialog on the same F-2/F-3 layers — which is why they were
written UI-agnostic.
