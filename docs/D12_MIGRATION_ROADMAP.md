# TR4W — Delphi 12 Migration Roadmap (what remains)

**Date:** 2026-08-02 (updated late 2026-08-02: Track A-1/A-4 and C-1 closed) · **Branch:** `delphi12` · **Purpose:** one place that answers
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
| A-2 | **Installer packaging.** `full.nsi:154` hard-requires `tr4wserver.exe`. Then verify the packaged exe carries `Embarcadero` markers and all runtime deps ship. | readiness checklist item 2 | 🟢 **UNBLOCKED** — A-1 done, and the EXE already lands exactly where `full.nsi` expects it. Not yet run. |
| A-3 | **`release.yml` still references Delphi 7** — `DELPHI7_BIN` at 25-26/70, a DCC32.EXE *existence check* at 153, and `-Delphi7Bin` passed at 182 and 201. **Nothing it invokes needs D7 any more**, so this is now pure cleanup: drop the check and the two arguments. Still needs RAD Studio on the runner. | `.github/workflows/release.yml` | 🟢 **UNBLOCKED** by `76de84c` |
| A-4 | **`BuildServer.ps1`** repointed to msbuild; `FullBuild.ps1` calls `Invoke-MSBuild` on the `.dproj` directly and no longer treats a server failure as expected breakage. The DCC32 existence check is gone from `-BuildInstallers`, so **`FullBuild.ps1` is D7-free end to end**. | `76de84c` | ✅ **DONE 2026-08-02** |
| A-5 | **Packaging/doc staleness.** `pota_parks.csv` (9 MB, live feature data) is not referenced in `full.nsi`; `full.nsi:5` default version `4.148.1` vs `Version.pas` `4.149.0`; **`tr4w/CLAUDE.md` still describes Delphi 7 / `BatchCompile.cmd` / v4.143.2** and the pre-factory radio architecture — confirmed still stale today. | P2-11 | 🟢 Open, cheap |


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

### C-1 postscript — the cluster does not use Indy

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
| C-1 | **Telnet / DX cluster / SSL** on the D12 binary. | P1-6 · **Group F** | ✅ **DONE 2026-08-02.** Cluster connects and logs in; CTY.DAT downloads over HTTPS (so vendored Indy + the bundled OpenSSL DLLs are proven); `{TOKEN}` expansion verified. Code audit found **no** defect — see the note below. Remaining SSL surface: score posting, HamScore. |
| C-2 | ~~**Two-station D7 ↔ D12 wire test**~~ **RETIRED as written** — all stations run the same build by convention (NY4I). `ContestExchange` has zero plain `Char` fields and the corpus reads D7-written binaries, so the shared record is byte-stable. Replaced by a **two-client** test of the server's own `AnsiChar` paths — see §9. | — | 🟡 Rescoped 2026-08-02 |
| C-3 | **CW / WinKeyer / DVK / DVP timing.** | P1-8 · **Group D** | 🟡 Partly done — WinKeyer latency + startup verified on the K3 (383 ms → 25 ms; 1978 ms → 0.4 ms) |
| C-4 | **CW-by-CAT send, every radio.** `SendCW` now has one path for all families and three drivers emit `KY` for the first time. Highest-risk item on the branch. | `BENCH_TEST_PLAN_2026-08-01` §1–2 | 🟡 K3/K4 verified; **K2, KX3, Kenwood, Flex-on-COM, Icom long-message fix untested** |
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
| D-2 | **Telnet socket I/O centralization** (one decode after `recv`, one encode before send) | A parser rewrite (byte-offset DX-spot matching), not a cast tweak | No |
| D-3 | **Vendored Indy + `src\MMSystem.pas`** replaced by D12's RTL | Needs live network/SSL testing to swap — i.e. gated on **C-1** | No, but see C-1 |
| D-4 | **Low-value shims** — `StrComp_JOH_IA32_6`, `BooleanToStr`, `RealToStr2`, `tCreateEditWindow`, `CopyFileA`/`FileExists` | Cost/benefit | No |
| D-5 | **Lint enforcement** (`Lint-PCharAnsi.ps1`) wired into the build so a new unmarked `PAnsiChar` in the logic layer fails | Never wired | No — but it is what keeps Phase 2 from regressing |

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

- **P2-9** — the IARU golden fixture passes purely by list membership, and `is_known`
  overrides `GOLDEN_STRICT`, so an aborted export is masked identically to a known
  divergence. Regenerate `iaru_hf_2026_ny4i` so the divergence is *demonstrated*.
- **P2-10** — file the 4 benign golden divergences (2 contests × 2 formats; sent
  exchange rebuilt from the `MyZone` session global) as a tracked issue. Pre-existing
  D7 quirk, not introduced by D12.
- **A-5** — the doc/version staleness above.

---

## 9. Critical path

*Updated 2026-08-02: A-1, A-4 and C-1 are done; C-2's premise changed.*

```
   A-1 tr4wserver on D12  ✅ ──►  A-2 installer  ──────────────►┐
   A-3 release.yml on msbuild (now pure cleanup) ──────────────►├──►  ENGLISH D12 RELEASE
   C-1 telnet/cluster/SSL  ✅ ─────────────────────────────────►│
   C-3..C-8 CW + radios (one verified radio per family) ───────►┘
                                                                │
   B-2 per-language UI eyeball ─────────────────────────────────►├──►  LANGUAGE RELEASES (8)
                                                                │
   E-1 ✅ (already done)  ►  E-2 credentials  ►  E-3 caps  ►  E-4 delete legacy
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

1. **A-2** — installer packaging. Unblocked, and the EXE already lands where `full.nsi` wants it.
2. **A-3** — release.yml cleanup. Now just dropping a DCC32 check and two `-Delphi7Bin`
   arguments; still gated on RAD Studio being available on the runner, which is lead time.
3. **C-4 / C-6** — one verified radio per protocol family. Four families unproven
   (Icom LAN, Yaesu binary, Yaesu ASCII, HamLib). This is calendar-bound, not effort-bound.
4. **A-5** — version/doc staleness, including `tr4w/CLAUDE.md`, which still describes D7.

Everything above except item 3 can proceed with no hardware at all.
