# TR4W — Delphi 12 Release Readiness

Status: **v2 — cutover in progress** (updated 2026-07-18). Branch: `delphi12`.
Since v1: the committed build script (`FullBuild.ps1`) is fully migrated from Delphi 7 DCC32 to D12
`msbuild` (**C-1 done** for the local build), the record/enum wire layout is pinned in the `.dproj`
(**C-3 done**), the stale D7 `tr4w.cfg` is removed, and an ADIF date/time parsing regression from the
string sweep was fixed. A default build is now **Delphi-7-free** and stays golden-master **22/22**.
Hardware/bench gates are captured in [`D12_HARDWARE_TEST_PLAN.md`](D12_HARDWARE_TEST_PLAN.md).
Companion to [`D12_STRING_MODERNIZATION_PLAN.md`](D12_STRING_MODERNIZATION_PLAN.md). That plan tracks
the *string/Unicode conversion*; this document tracks what stands between the current tree and a
**shippable D12 build that replaces the Delphi 7 release**.

---

## Bottom line up front

The D12 **build already works**: `tr4w.dproj` compiles the modernized source and the resulting
`target\tr4w.exe` passes the scoring golden-master **22/22**. Standing up the release therefore is
**not** a build-system problem — it is (1) **expected cutover mechanics** you already plan to do
(install D12 on the runner, repoint the committed CI scripts from DCC32 to the `.dproj`), plus (2) the
things that actually need attention: the **non-English text path** and every **runtime surface the
ASCII-only oracle cannot see** (network/SSL, CW timing, live radios, mixed-version wire).

Recommended path: **ship an English-only D12 release first** (repoint CI + bench-verify
network/radio/CW), then bring the other 10 languages as a fast follow once the CP1251 fix is applied
and each UI is eyeballed.

## Scope

- **In scope:** a **Win32** D12 build to replace the D7 build.
- **Out of scope:** 64-bit. The ~48 inline-`asm` blocks and pointer-width (`Integer`→`NativeInt`)
  work are a *separate future target platform*, not a D12-Win32 release concern. See the 64-bit
  discussion thread; do not let it bleed into this release.

## How to read the gates

- **🔴 P0** — a release artifact cannot be produced (or is knowingly broken) until this is fixed.
- **🟡 P1** — not provable by code review; needs live/bench verification before the release is trusted.
- **🟢 P2** — evidence gaps and staleness; resolve before sign-off but not a gate on building.

Each item: **evidence** (file:line where known) → **fix** → **verification**. Check the box when the
verification — not just the code change — is done.

---

## Expected cutover work (mechanical — the known "move to D12" chores)

These are not defects or surprises; they are the wiring you already intend to do once D12 is on the
runner. Listed so nothing is forgotten, not because anything is wrong. The `tr4w.dproj` build is proven
(it produced the passing `target\tr4w.exe`).

- [x] **C-1 — Repoint the committed CI/build scripts from DCC32 to the `.dproj`.** DONE for
  **`FullBuild.ps1`** (2026-07-18): unit tests, ENG app, all 8 language variants (serial **and**
  `-ParallelLanguages` worktree paths), and the ENG relink now build via `msbuild tr4w.dproj` through a
  new `Invoke-MSBuild` helper (`call rsvars.bat && msbuild`). Language define is injected via a new
  `$(ExtraDefines)` slot in the `.dproj` (`/p:ExtraDefines=LANG_x` — note the plan's
  `/p:DCC_Define=LANG_x` idea is a trap: MSBuild global props drop the config's `DEBUG`); per-language
  DCU isolation via `/p:DCC_DcuOutput`. brcc32 repointed to the Studio bin. **Still open:** `release.yml`
  (CI — also needs RAD Studio on the runner, and is entangled with C-2 since it builds installers) and
  `tr4wserver\BuildServer.ps1` (see C-2).
- [ ] **C-2 — Build `tr4wserver.exe` under D12.** DEFERRED (owner decision, 2026-07-18). The server
  project is **broken independently of the migration**: its `.dpr` uses stale `..\tr4w\src\` paths (it
  was moved under `tr4w\` and never re-pathed), it has **no `.dproj`**, there are **two divergent
  `tr4wserverUnit.pas`** copies (`tr4w\src\` D12-modernized w/ `AnsiChar`; `tr4wserver\src\` older w/
  `Char` — a likely **wide-char wire bug**), and it pulls in `VC.pas` → the UTF-8+BOM lang files D7
  can't read. `full.nsi:154` hard-requires the exe, so installer packaging still aborts until it's
  built. Interim: `FullBuild.ps1` Step 2b is now **gated on `-BuildInstallers` + warn-not-fail**, so a
  non-installer build isn't blocked. This is the **only remaining Delphi 7 dependency**.
- [x] **C-3 — Carry `-$A8` / `-$Z1` in the `.dproj` (log/wire layout).** DONE (2026-07-18). The removed
  `tr4w.cfg` held these; the `.dproj` now sets `<DCC_Alignment>8</DCC_Alignment>` /
  `<DCC_MinimumEnumSize>1</DCC_MinimumEnumSize>` explicitly (verified wired: a `2`/`4` probe emitted
  `-$A2`/`-$Z4`; at `8`/`1` the switch is omitted as the current default but re-emits if the default
  moves). Byte-compatible: ENG build unchanged at 4,456,448 B, corpus 22/0. Live mixed-version wire is
  still P1-7.

## 🔴 P0 — Genuine blocker (source fix applied; visual verification + CHN still open)

- [~] **P0-1 — Source-literal codepage pinned per file (2026-07-10).** DONE for 10 of 11 languages;
  CHN still open; **rendered-UI verification pending** (you must eyeball each — the oracle is ASCII-only,
  P1-5).
  - **Critical correction to the plan:** the files are **NOT all CP1251.** That blanket assumption would
    have corrupted 6 of 10 languages (byte `0xF1` is `ñ` in 1252 but Cyrillic `с` in 1251). True codepage
    was determined per file from the actual bytes (clean strict-decode + Unicode-block check):

    | Codepage | Files |
    |---|---|
    | **1251** (Cyrillic) | rus, ukr, mng |
    | **1250** (Central Eur.) | pol (ł), cze (řě), rom (ăî), ser (š) |
    | **1252** (Western) | esp (ñ¿), ger (punct), eng (2 punct) |

  - **Applied (CORRECTED 2026-07-11, supersedes the `{$CODEPAGE}` plan):** the files were **transcoded
    to UTF-8 with a BOM** (commit `8dd9ef8`), each decoded from its true legacy codepage in the table
    above and re-encoded losslessly. **`{$CODEPAGE nnnn}` does NOT work in Delphi** — it is a
    FreePascal-only directive and Delphi rejects it with `E1030`; the earlier `{$CODEPAGE}` attempt was
    reverted. A BOM is Delphi's real per-file encoding mechanism: the D12 compiler reads it and decodes
    the file correctly on any build machine (a no-BOM file would be decoded with the *build machine's*
    ANSI codepage and silently corrupt the literals). The files are `{$INCLUDE}` fragments
    (`VC.pas:174-184`). SER is Serbian **Latin** → cp1250 (fixed in `1ff2053`, not the Cyrillic 1251).
  - **CHN deferred — pre-existing data corruption, not a directive gap.** `tr4w_consts_chn.pas` is
    mixed-encoding: mostly GBK/CP936, but **~196 bytes are invalid even under GB18030** (two `0x97`
    CP1252 em-dashes in English strings, plus many in the `RC_*` right-click-menu strings). It cannot be
    tagged with one clean codepage until a Chinese-literate maintainer recovers intent. Likely already
    rendered partly garbled under D7. **Do not ship CHN until fixed.**
  - **The `CodePage=1251` lines in `FullBuild.ps1:217-224`** set VERSIONINFO metadata only — never a
    mitigation for source transcoding.
  - **Build coverage:** `FullBuild.ps1 -AllLanguages` builds ENG + 8 (`$otherLangs`, line 808: RUS,
    SER, MNG, CZE, ROM, GER, UKR, ESP). **POL and CHN are intentionally excluded** — POL is a known-bad
    mixed-encoding file (excluded from the build, issue #925), CHN is corrupt GBK (below).
    So P0-1 verification = eyeball those 9 exes; POL/CHN out of scope for this release.
  - Verify: build each language under D12 and **visually confirm** the UI renders correctly (all 8
    non-ENG variants already build GREEN; rendering is what's unverified). The UTF-8+BOM transcode is
    lossless and round-trip-verified, but only a human eyeball on each running UI closes P0-1. Bench
    steps H1–H3 in [`D12_HARDWARE_TEST_PLAN.md`](D12_HARDWARE_TEST_PLAN.md).

---

## 🟡 P1 — Require live/bench verification before the release is trusted

- [ ] **P1-5 — The text/Unicode surface is unverified by the golden-master.**
  - Evidence: `test\corpus\` passes 22/22, but per `corpus\README.md` **every fixture exports pure
    ASCII** (even the Russian Arktika fixture has 0 non-ASCII bytes). The oracle validates the *scoring
    engine*, not the UTF-16/ANSI boundary work — the whole point of the D12 change. Uncovered:
    non-English config parsing, CTY.DAT names, UI strings.
  - Verify: add non-ASCII fixtures/coverage, or explicitly accept the gap with a manual pass over
    non-English config + CTY + UI.

- [ ] **P1-6 — Network/SSL/telnet/cluster runs on vendored Indy 10.6.3.3.**
  - Evidence: vendored Indy under `include\{Core,System,Protocols}` (`IdVers.inc`: 10.6.3.3) is on the
    D12 search path (`tr4w.dproj:67`) and shadows D12's bundled Indy. `src\MMSystem.pas` shadows
    `Winapi.MMSystem`. Plan flags this "needs live network/SSL testing to swap."
  - Verify: bench-test live telnet, DX cluster, and SSL against the D12 binary (connect, spot flow,
    disconnect/reconnect).

- [ ] **P1-7 — D7↔D12 wire compatibility (mixed-version network).**
  - Evidence (reassuring for disk): `ContestExchange` (`VC.pas:1541`) is entirely fixed-width types —
    no `string`/`Pointer`/`NativeInt`; the passing D12 exe reads real D7-written `.dat` corpora, so
    `tr4w.dproj` already carries compatible `-$A8`/`-$Z1` (matching `tr4w.cfg.d7leftover:1,26`).
  - Gap: the **live wire path** (a D12 station networked to a D7 station mid-contest) is exercised by
    no test.
  - Verify: two-station bench run (one D7, one D12) — exchange QSOs, spots, time-sync; confirm no
    corruption and matching dupe/mult state.

- [ ] **P1-8 — CW/keyer/DVK timing and non-CI-V radios have no test coverage.**
  - Evidence: plan risk register ("CW/keyer/DVK timing regression … no test coverage"); only Icom CI-V
    is hardware-validated.
  - Verify: bench-verify CW keying timing, DVK/DVP, WinKey, and each radio/mode you claim to support.

---

## 🟢 P2 — Evidence gaps & staleness (resolve before sign-off; not build gates)

- [ ] **P2-9 — IARU golden fixture has no candidate export.** It passes purely by list membership, and
  `is_known` overrides `GOLDEN_STRICT` (`run-golden-diff.sh`) — an aborted export is masked identically.
  Fix: regenerate `iaru_hf_2026_ny4i` candidate so the divergence is demonstrated, not assumed.
- [ ] **P2-10 — The 4 golden divergences are benign; file as a tracked issue.** They are 2 contests ×
  2 formats, one pre-existing D7 quirk (sent exchange rebuilt from the `MyZone` session global → falls
  back to MY STATE when unset). Score, multipliers, points, and all *received* fields are byte-identical.
  Not a release gate; not introduced by D12.
- [ ] **P2-11 — Packaging/doc staleness.** `pota_parks.csv` (live feature data, 9 MB in `target\`) is
  not referenced in `full.nsi`; `full.nsi:5` default version `4.148.1` vs `Version.pas` `4.149.0`;
  `tr4w\CLAUDE.md` still says "Delphi 7 / BatchCompile.cmd / v4.143.2". *(RESOLVED: the `tr4w.cfg`
  deletion now has its `.dproj` replacement — see C-3 — and the deletion is committed.)*

---

## Recommended release strategy

**Phase A — English-only D12 release.** Do the cutover chores C-1/2/3, bench-verify P1-6/7/8. Ship to
the largest user base to de-risk the cutover. CP1251 (P0-1) and per-language verification (P1-5) do
**not** block this.

**Phase B — Non-English fast follow.** Apply P0-1, then work the language-verification matrix (P1-5):
build each of the 10 non-English targets and eyeball the UI. Ship per-language as each is verified.

Rationale: this decouples a mechanical toolchain cutover from an 11-language verification burden the
existing (ASCII-only) test harness cannot cover.

## Must-pass checklist before shipping Phase A

1. [~] Local `FullBuild.ps1` builds app + all languages under D12 msbuild (**C-1 done**; C-3 done).
   Still open: `release.yml` (CI + RAD Studio on the runner) and the `tr4wserver` build (**C-2**).
2. [ ] Installer packages the **D12** exe (verified `Embarcadero` markers), all runtime deps present.
   *(Blocked on C-2 — `full.nsi` requires `tr4wserver.exe`.)*
3. [x] Golden-master 22/0 green on the local D12 exe (P1-5 caveat noted). CP1251/UTF-8+BOM applied for
   non-ENG (P0-1) — rendering still needs an eyeball.
4. [ ] Live telnet + DX cluster + SSL on the D12 binary (P1-6) — `D12_HARDWARE_TEST_PLAN.md` **Group F**.
5. [ ] Two-station D7↔D12 wire test clean (P1-7) — **Group G**.
6. [ ] CW/DVK/WinKey + each supported radio bench-verified (P1-8) — **Groups A–E**.
7. [ ] IARU candidate regenerated (P2-9); version/doc staleness fixed (P2-11).

## What is already proven (do not re-litigate)

- Scoring/multiplier/points engine is byte-faithful under D12 across 11 candidate contests
  (`CLAIMED-SCORE` exact on all: cqww_ssb 30912, arrl_ss 30192, winter_fd 42364, cqwpx 78, …).
- `.dat` on-disk log layout is preserved (D12 exe reads D7 corpora; `ContestExchange` fixed-width;
  `-$A8`/`-$Z1` carried by `tr4w.dproj`).
- Runtime payload in `target\` is complete (OpenSSL, HamLib, `rigctld.exe`, CTY.DAT, TRMASTER.DTA,
  `dom\*.dom`); no new D12 runtime DLL required (RTL linked statically, no BPLs); `inpout32.dll`
  omission is intentional.
- String/Unicode conversion is substantially done (see the modernization plan); remaining items are
  intentional deferrals coupled to the SQLite / `ContestExchange`-as-object work.
