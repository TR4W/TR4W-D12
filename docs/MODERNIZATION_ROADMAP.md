# TR4W modernization roadmap

**One document. It replaces eleven.** Everything that was tracking the port —
`ROADMAP.md`, `D12_MIGRATION_ROADMAP.md`, `PHASE_INVENTORIES.md`, the two
radio-factory design notes, the CFG-array set, the toolchain SWOT, the spike
log — is either finished or superseded, and is now in
[`migration_interim_artifacts/`](migration_interim_artifacts/). This file is the
task list; those are the reasoning.

**Scope:** four weeks of work, phased. Written 2026-09-17 against `main` at
`c1051ae4`.

---

## 0. How to read this

**EVERY NUMBER HERE IS DATED AND CARRIES ITS COMMAND.** That is not ceremony.
This tree has repeatedly cost NY4I time by stating a count that was true last
month, and a stale *reason* is worse than a stale count because a count invites
a re-measurement and a reason invites agreement. Re-measure before citing.

**The oracles, all of which must be green before a commit:**

```powershell
.\tr4w\build\Run-Lints.ps1                # the lint set, incl. the ratchets
.\tr4w\build\Build-Tests.ps1 -Run         # unit tests; zero failures is baseline
.\tr4w\FullBuild.ps1                      # lints + tests + app + tr4wserver
.\tr4w\build\Build-App.ps1 -Cpu x86_64 -Os win64   # the x64 target
```

```bash
bash tr4w/test/corpus/export-d12-corpus.sh        # 24/0/2 AND exit 0
bash tr4w/test/corpus/test-contest-factory.sh     # factory vs legacy rescore
sh  tr4w/build/build-unix.sh                      # on linux-ci / mac-ci
```

**Three things no oracle can prove**, and they gate more of this roadmap than
any code does: that a radio keys, that a spot decodes, and that an operator can
run a contest. Those arrive only from a bench session. They are called out per
phase rather than pooled at the end.

---

## 1. Where this actually stands — measured 2026-09-17

| | measured | command |
|---|---:|---|
| Live `PChar`/`PAnsiChar`/`PWideChar` | **69** tree-wide, 17 units | `build/Count-LivePChar.ps1` |
| Live `asm` blocks | **0** | `build/Count-LiveAsm.ps1` |
| Win32 **UI** call sites | **14** | `build/Lint-Win32Dialogs.ps1 -Group ui` |
| Win32 **non-UI platform** call sites | **33** | `build/Lint-Win32Dialogs.ps1 -Group platform` |
| `Move`/`FillChar`/`ZeroMemory` | **~376** raw (over-reports; comments included) | grep — a comment-aware counter is owed |
| `wsprintfBuffer` mentions | **62** | grep |
| Units naming `Windows` | **165** | grep |
| `{$IFDEF WINDOWS}` gates | **128** | grep |
| Radio registrations | **101**, no collisions | `build/Lint-RadioRegistry.ps1` |
| Radios with any bench report | **~6 of 101** | `docs/RADIO_BENCH_STATUS.md` |
| Contest factory units | **23** (≈19 contest classes + base/registry/factory) | `ls tr4w/src/contestFactory` |
| `ContestType` enum members | **189** | `VC.pas` |
| **Contest-identity branches outside the factory** | **92** across 12 units | see §5.3 |
| `BENCH_QUEUE.md` | **176 open**, 121 done, 6 open sections | `grep -c '^- \[ \]'` |
| Open issues | **75** D12 (68 inherited, **7** `Modern Delphi`) · **68** TR4W | `gh issue list` |
| Recent velocity | **1,117** non-merge commits / 28 days | `git log --since` |

**What is DONE and must not be reopened:** the FPC/Lazarus toolchain choice,
`asm` eradication, the CFG array (415 rows → 0), the display-state model, the
LCL conversion of every designed window, SQLite as the log, the parallel port
(deleted, not ported), the Win32 message loop, and three-platform builds
(Windows i386 + x64 compile, Linux x86_64, macOS aarch64) published from a tag
by CI.

**Two stale items that keep getting reopened, killed here:**

- *"An x64 toolchain must be provisioned."* **False.** It was installed twice
  already; the real defect was `Find-Toolchain.ps1` pairing FPC and Lazarus
  independently, which is fixed. The x64 app compiles and links.
- *"Replace the Win64 LPT loader with a verified InpOut x64."* **Moot.** The
  parallel port was deleted entirely on 2026-09-13.

---

## 2. The four phases at a glance

| week | theme | why it is in this slot |
|---|---|---|
| **1** | Correctness, durability, and the cross-platform prerequisites | These gate everything else and several are one-afternoon fixes with outsized risk |
| **2** | Finish 64-bit; finish the pointer and Win32-idiom removal | Mechanical, testable, and the highest-volume remaining debt |
| **3** | The contest factory | The one genuinely large architectural block left |
| **4** | First-run wizard, menus/actions, i18n cutover, release | Operator-facing; depends on the three phases above being stable |

**Bench and NY4I decisions run across all four weeks** — §7 and §8. They are not
a phase because they are not ours to schedule.

---

## 3. Week 1 — correctness, durability, cross-platform prerequisites

### 3.1 Close the durability loop (highest value, mostly already done)

The 2026-09-11 codex review called two things release-blocking. **Both are
fixed, verified against the tree on 2026-09-17** — `LogStoreAppendQSO` is now
`function ... : boolean` and honoured at both call sites, `CheckIntegrity` has
callers through `uVerificationChecks`, and the backup path calls
`LogStoreBackup` with a report instead of copying the obsolete `.TRW`. What
remains is the proof:

- [ ] **Tests for `LogStoreBackup`'s orchestration** — staging to `.new`,
      `StagedBackupIsSound` rejecting a corrupt snapshot, `.bak` displacement,
      publish-by-rename, and cleanup on exception. **Nothing in `test/`
      references it.** The obstacle is real: `uLogStore` is not in the
      unit-test `.lpr`, though `MainUnit` already is, so linking it is
      plausible rather than blocked.
- [ ] Fault-injection tests for the QSO acknowledgement contract: disk full,
      read-only DB, locked DB. **A QSO must never be acknowledged unwritten.**
- [x] ~~Integrity check on database open~~ — **ALREADY DONE.** `EnsureOpen`
      calls `GDatabase.CheckIntegrity` and fail-closes through `Disable`; the
      snapshot primitive is covered by three tests in `uTestLogDatabase`.
- [x] ~~End-to-end test for `SaveLogFileToFloppy`~~ — **MOOT.** No such routine
      survives; the periodic backup in `logstuff.pas` calls `LogStoreBackup`
      and reports success or failure by name.

### 3.2 ~~The corpus is environment-dependent~~ — DONE, verified 2026-09-17

**`CORPUS_FRESH_CLONE_DEFECT.md` is stale and belongs in the archive.** All
three of its fixes shipped: `tr4w/test/corpus/settings/tr4w.json` is a
**tracked, corpus-owned** fixture carrying `_LOCATION: WCF`, the harness
pre-checks it and fails with a named reason, and the app reads it through
`--settings` so the operator's live configuration is never touched. The
LOCATION guard itself was correctly left alone.

### 3.3 ~~Before TR4W leaves Windows~~ — DONE, verified 2026-09-17

**`OWED_BEFORE_CROSS_PLATFORM.md` is stale and belongs in the archive.** Every
item in it shipped, and the lints prove it rather than a doc asserting it:

- [x] The three path accessors exist in `src/uAppPaths.pas` — `DataFilePath`,
      `SettingsFilePath`, `LogFilePath`, their three directory forms, **and a
      fourth root** for files the operator creates, which the doc never asked
      for and which was a real defect (contest files were being composed from a
      read-only root).
- [x] `Lint-AppPaths.ps1`: *"447 files scanned, 5 path rules in
      uAppPaths/uProgramMain where they belong; no raw path resolution
      elsewhere."*
- [x] `Lint-SearchIndex.ps1`: *"163 designed controls across 25 section panels,
      every one is bound or indexed."* That is both the registration work and
      the lint the doc asked for.
- [x] `LoadClusterServerList` logs a warning naming the path it searched and
      why the picker is empty.
- [x] `Lint-OneConfigWriter.ps1` also closes the codex review's
      concurrent-config-writer finding: *"tr4w.json has one writer."*

**Still genuinely open from that doc:** the ~230 searchable captions that are
plain Pascal literals rather than `resourcestring`, so they are untranslated
and unsearchable in any other language. That belongs with the i18n work in
week 4, not here.

### 3.4 Triage the uninitialised-locals audit

**FINDING 1 IS ANSWERED, AND THE ANSWER IS THE BAD ONE — measured 2026-09-17.**
The audit said the single question deciding "latent freeze or no-op" was whether
`-O` eliminates the empty loop. It does not, because **there is no `-O`**: the
build passes `-Mdelphi -P<cpu> -T<os> -Sc -WG -gl -gw2 -Xg` and nothing else,
in `Build-App.ps1`, `FullBuild.ps1`, the Unix scripts and the `.lpi` alike.

Disassembling the shipping build's own `logdupe.o` shows the loop emitted in
full — entry guard `cmp -0x14(%ebp),%edx / jge`, an increment at `0x250`, and a
back-edge `jmp 0x250` at `0x25e` — over two stack slots never written. Both
empty loops in the routine survive compilation.

- [ ] **Decide the fix** (NY4I — this is live TRDOS contest code with three
      callers on the typing path). Exposure is narrower than it first looks:
      `WildcardPartials` defaults to **True**, and the garbage-bounds loop is
      in the `else` branch, so it bites only operators who turn
      `WILDCARD PARTIALS` off.
- [ ] Separately: **the whole program is compiled unoptimised.** That is worth
      a deliberate decision rather than remaining an accident.
- [ ] Decide dead-or-fix on `logsubs1.pas:1198` and `logstuff.pas:5737-5739`.
- [ ] Clear the 23 compiler-flagged Part-A sites.

### 3.5 ~~Unblock the x64 binary~~ — DONE, verified 2026-09-17

- [x] x86_64 `libeay32.dll` and `ssleay32.dll` are staged in
      `tr4w/redist/x86_64-win64/` and both read PE machine **`8664`** (against
      `014c` for the i386 pair in `target/`). `Build-App.ps1` already fails the
      build when a target's redist DLLs are missing or the wrong architecture.
- [x] The PE-machine assertion exists as a test:
      `TestPEArchitectureOfTheSQLiteDLL`, plus the not-a-PE and missing-file
      cases, in `uTestLogDatabase`.
- [ ] **What is actually left: run it.** Compiling and linking is not running,
      and nobody has launched the x64 binary.

**Week 1 exit, restated 2026-09-17 after measuring.** Most of what this phase
listed was already done — §3.2, §3.3 and §3.5 were written from docs dated
2026-08-25 and 2026-08-30 and were stale when this roadmap was committed. What
remains is genuinely three things:

1. A ruling on the `logdupe` empty loops (§3.4), and the fix.
2. `LogStoreBackup` under test — the one careful, load-bearing routine in the
   durability path with no coverage at all.
3. The x64 binary **launched**, not merely linked.

**THE LESSON IS THE ONE THIS FILE OPENS WITH.** §0 says re-measure before
citing, and this phase was assembled without doing that. A roadmap is a
document like any other: it goes stale, and it is most dangerous when it is
new enough to be trusted.

---

## 4. Week 2 — 64-bit completion, pointers, Win32 idioms

**Keep these two axes apart.** NY4I scoped them separately on 2026-09-08 and the
reason holds: *"does it compile off Windows"* and *"is this how an FPC/LCL app
would have been written"* are different questions, and mixing them produces a
diff nobody can review.

### 4.1 Portability axis

- [ ] `Move`/`FillChar`/`ZeroMemory`: triage all sites into (a) record/buffer
      clear → field initialisation, (b) string copy → plain assignment,
      (c) genuine byte framing → `TBytes`. NY4I's rule: byte I/O stays byte
      I/O, but `Move` is not how to express it. **Write the comment-aware
      counter first** — the raw grep over-reports.
- [ ] Hold the PChar floor at 69. Every survivor is a real boundary and carries
      a comment saying why; any new one fails review.
- [ ] Wire and persisted layout widths across 32/64-bit: assert field widths and
      offsets for `ContestExchange`, `TLogHeader`, `uNetFraming`.
- [ ] A **scope-aware** lint for handles stored in narrower-than-pointer
      variables. A name-matching scan produces false positives and must not
      ship as a lint — this class of bug has no pointer cast to grep for.
- [ ] `uSimProcess.pas` — still an ungated `uses Windows` with three `THandle`
      fields (bench harness only, low priority, but it is the last one).
- [ ] HamLib: `$ORIGIN` rpath on the Linux executable so the dlopen'd library
      resolves its own dependencies; verify with `ldd` on the shipped tree.

### 4.2 Idiom axis — `WIN32_ARTIFACT_SWEEP.md`

- [ ] Typed class for the packed-integer grid tag (`TRemainingMult` via
      `TStringList.Objects`, `OwnsObjects := True`), plus the two other abused
      `TFlowGrid` tag uses in `uCallsigns` and `uMaster`.
- [ ] `wsprintfBuffer` — 62 mentions of a shared global text buffer.
- [ ] RICHED32 in `uMMTTYForm` — needs a per-character-colour control; base LCL
      has none, so this is a package choice, not a swap.
- [ ] Separate `Config.CWTone` into two concepts; it is currently a dead
      parameter posing as a CW-enabled flag.
- [ ] **`TLVItem` is already down to a type declaration in `w.pas` and three
      comments** — the `BuildLogRow` conversion landed. The doc's claim that it
      blocks the Linux compile is stale; Linux builds in CI.

### 4.3 The clock abstraction — this one is load-bearing

`PLATFORM_CLOCK_ABSTRACTION.md`, open and not started. **Off Windows, CW element
timing falls back to plain `Sleep` and will not key a contest.** That is stated
in the code as a placeholder, and it means the Linux and macOS builds cannot be
used on the air regardless of how green they are.

- [ ] `uHPTimer.pas` measurement half first (`HPTicks`, `HPTicksPerSecond`,
      `HPElapsedMicroseconds`) — usable immediately.
- [ ] Then the delay half (`HPSleepMicroseconds`) — what `tCWSleep` becomes.
- [ ] Per platform: `QueryPerformanceCounter`; `clock_gettime(CLOCK_MONOTONIC_RAW)`;
      `mach_absolute_time()` + `mach_timebase_info()`. **Do not hardcode the
      timebase ratio** — Intel reports 1/1, Apple Silicon does not.
- [ ] `uPlatformClock.pas` for the wall clock, and fix `uNet.pas:390-393`, whose
      nested nil-checks accept month 0, day 0 and 31 February and never check
      minutes or seconds.

**Week 2 exit:** x64 and all three platforms build and pass tests; `Move` sweep
triaged with a real counter; HPTimer measurement half merged with tests.

---

## 5. Week 3 — the contest factory

This is the largest remaining architectural block and the one with a live
GitHub issue: **TR4W-D12 #10, "Rework the way new contests are implemented."**

### 5.1 Use codex's sequencing

The `codex/contest-factory-roadmap` branch is **one commit, one file, no code** —
a sequenced §6 added to `ADDING_A_CONTEST.md`. That sequencing is the valuable
part and is adopted here. It does not conflict with the main tree's
architecture; it makes the "not built yet" inventory into an ordered plan.

Order, each phase gated by proof before the next:

1. **Exchange contract** — replace `ExchangeKind` with a contest-owned
   structured description (fields, order, required/optional, alternatives).
   Add a factory parse operation returning UI-agnostic errors. Move
   `LOGDUPE.SetUpExchangeInformation` (prompts and labels) behind the same
   contract. Storage stays in `ContestExchange` columns.
2. **Scoring and multiplier ownership** — multiplier definitions and candidate
   values, dupe identity and key, inhibit rules, score aggregation. Contest
   classes stay pure and deterministic; the app owns persistence and iteration.
3. **Exports end-to-end** — replace the all-or-nothing `FormatsExchange`
   boolean with typed operations for Cabrillo headers and columns and for ADIF
   sent/received. **Golden byte-level fixtures first** — widths and spacing.
4. **Setup and metadata last** — `FCONTEST`'s `case Contest` setup and
   `ActiveExchange` mutation move into the class layer; those two globals become
   compatibility-only projections.

**Per-capability loop:** characterize the legacy arm with tests → add the
factory op → dispatch factory-first with legacy fallback → differential-test
factory against legacy → byte-level export fixtures → delete the legacy switch
only once every selectable contest has the capability.

### 5.2 The completion gate, and it is measurable

> Outside the factory and a named, shrinking compatibility adapter, no
> production code may branch on `Contest`, `ActiveExchange`, or
> `ActiveQSOPointMethod` to choose a rule.

- [ ] Build the lint with an allowlist that must shrink on every migration.

### 5.3 What that gate costs today — measured 2026-09-17

**92 contest-identity branches across 12 units** outside the factory
(17 `case ... of`, 75 `if Contest = / in [...]`):

| unit | branches |
|---|---:|
| `trdos/logstuff.pas` | 15 |
| `trdos/logedit.pas` | 14 |
| `uCabrilloExchange.pas` | 13 |
| `trdos/postunit.pas` | 12 |
| `MainUnit.pas` | 9 |
| `trdos/logdupe.pas` | 8 |
| `trdos/fcontest.pas` | 6 |
| `uADIFExchange.pas` | 5 |
| `uTotal.pas` | 4 |
| `logsubs2`, `LogCfg`, `logddx` | 5 |

Coverage is ~19 contest classes against 189 `ContestType` members. **That ratio
is not the work** — most enum members share a handful of rules, which is what
`TContestFixedPoints` already demonstrates — but the 92 branches are, and they
are the honest progress metric.

### 5.4 The blind spot that matters

**The golden corpus is blind to scoring.** It reads QSO points already stored in
the log and never recomputes them. `test-contest-factory.sh` (factory vs legacy
`/NOFACTORY` rescore) is the only thing that catches a scoring regression, and
**exchange validation and Cabrillo headers are caught by nothing.** Extend the
golden comparison to headers as part of step 3 — do not treat a green corpus as
completion.

**Week 3 exit:** exchange contract and scoring ownership migrated with
differential tests; the branch lint in place with a shrinking allowlist;
`test-contest-factory.sh` still 13 identical, 0 differing.

---

## 6. Week 4 — operator-facing, and the release

### 6.1 The first-run setup wizard — build it

**`SETUP_WIZARD_DESIGN.md` is a complete, agreed spec with nothing built.** Page
shape settled with NY4I 2026-09-11; all three of its open questions closed; 14
acceptance criteria written. There is no design work left, only implementation.

- [ ] The form: `TPageControl` with hidden tabs. Station page (required) →
      one checklist page → only the ticked pages, in canonical order →
      commit/result page. A new operator who just wants to log sees **two pages**.
- [ ] Staged session, one commit: `Editing` / `Committing` / `Completed` /
      `Cancelled`. Station identity commits first, hardware last, each ticked
      item independently — one failure must not discard the callsign.
- [ ] `WizardShown` persisted flag, written **before** the form is shown,
      mirroring `GridPromptShown`.
- [ ] The gate is **not** "does a settings file exist" — the file is written at
      startup six lines after the first-run test. It is: first run **and**
      `MyCall` still empty after the config reads. An operator upgrading from
      4.x has a `.cfg` with a callsign and must never see the wizard.
- [ ] Derive continent/zones/state/country from the callsign, debounced, marked
      as derived, and never overwrite a field the operator has edited.
- [ ] The commit page is a **result** page. Partial outcomes are legitimate and
      must be stated, not hidden behind "Finish".
- [ ] All 14 acceptance criteria in §10 of the design, including the headless
      case (`/EXPORT` must create no UI and block on nothing).
- [ ] i18n: `.lfm` captions for design-time, `resourcestring` for anything built
      in code. **Never run `pas2po`** — it destroyed 2,203 translations in one
      run. `po_merge --pot` is the only additive tool.

### 6.2 Menus and actions

`MENU_ACTIONLIST_PLAN.md`, nothing started, and it should land **before** the
i18n `resourcestring` cutover.

- [ ] Phase 0 first: `Dump-Menu.ps1` and `Lint-MenuDispatch.ps1` — the oracle
      before touching menu code.
- [ ] `TMainMenu` from `T_MENU_ARRAY`; diff against the Phase 0 dump; delete
      `HMENU`/`SetMenu`.
- [ ] Break the three id-couplings (window caption, checked state,
      enable/visible/caption).
- [ ] `TActionList`, one `TAction` per row. Do **not** split `ProcessMenu`.
- [ ] Convert the last two Win32 popups to `TPopupMenu`.

### 6.3 i18n

- [ ] Cut `VC.pas` over to `uTR4WStrings` (383 `TC_` strings) as **one
      deliberate commit** that removes the legacy `{$INCLUDE}` — both currently
      declare the same constants.
- [ ] Language selection as a TR4W setting, not just OS locale.
- [ ] A lint preventing new hardcoded English (three incidents this month).
- [ ] Send the Polish catalogue; ask BA4WI for his original file — 144 Chinese
      strings are unrecoverable without it.

### 6.4 Accelerators

- [ ] `AddOnKeyDownBeforeHandler` → `Application.OnShortCut`. **Keep the
      `fsModal` and Tab/Escape guards** — they are not incidental.

**Week 4 exit:** a new operator with an empty directory can configure TR4W and
log a QSO without editing a file by hand.

---

## 7. Bench — runs across all four weeks, and is the real gate

**176 open items in `BENCH_QUEUE.md`.** Nothing in this section is provable by
code review, and bench findings have repeatedly been the only thing to catch a
whole class of defect — the FT-1000MP frame decoding broke entirely under FPC
from a `Chr()` vs `Char()` codepage change that no build could have caught.

**Highest value, in order:**

1. **Radio families verified only under Delphi.** Only the K3S, K4 and
   FT-1000MP have been re-confirmed against the FPC binary. Every other
   Delphi-era result carries the same unstated risk.
2. **Unproven families entirely:** Yaesu ASCII, HamLib bridge, Icom LAN (on
   every model, not just one), Kenwood beyond the TS-570, Ten-Tec.
3. **The Kenwood driver-mapping fix** changes which driver ships for four models
   on upgrade — needs before/after on real hardware.
4. **Create a new contest** — flagged highest-risk, zero automated coverage.
5. **Multi-op PTT and paddle settings sync** — safety-relevant: amp keying and
   hot-switching.
6. **Linux/macOS GUI has never been run by anyone.** Building is not running.

**Owed to named people, not to us:** the WAE QTC windows go to N4AF (both
windows converted with no harness and no operator who can judge them; three of
its items are decisions, not checks). The Chinese catalogue needs BA4WI.

---

## 8. Decisions owed from NY4I

These block work and none can be resolved by reading code.

| # | decision | blocks |
|---|---|---|
| 1 | May a Win32 and a Win64 peer talk to each other on a multi-op network? | wire-layout work, §4.1 |
| 2 | `ExitProcess` vs `Halt` in `MainUnit` shutdown — does anything rely on finalization not running? | §4.2 |
| 3 | Does `tr4wserver` move to SQLite, or does the new protocol speak to a binary-log server? | multi-op protocol |
| 4 | Multi-op digest definition (columns, order, normalization) and mixed 4.x/5.x compatibility | log comparison, currently refusing rather than guessing |
| 5 | In ARRL DX, should TR4W refuse to log W/VE-working-W/VE, or keep logging at zero points? | contest factory rule |
| 6 | `Tr4w.rc`'s 1503-line dead `T MENU` resource — delete, keep as heritage, or diff first? | §6.2 |
| 7 | macOS Cmd-key handling: add an `acMeta` slot, translate at the boundary, or Ctrl/Alt only? | §6.4 |
| 8 | Password/token storage (HamScore, control channel) | i18n-adjacent settings work |
| 9 | Which colours stay operator-configurable in the grid restyle | `GRID_RESTYLE_PLAN.md` |
| 10 | `BAND MAP GUARD BAND` default 0 contradicts its declared minimum 100 | settings |
| 11 | `PADDLE MONITOR TONE` has a row, translations, and no code that reads it | settings |
| 12 | Does backup restore attempt to merge surviving rows? | restore path, unbuilt |

---

## 9. Explicitly NOT in these four weeks

Named so they are decisions rather than drift:

- **`GRID_RESTYLE_PLAN.md`** — parked pending the window conversions, which are
  now done, so it is *ready* to start. It is deferred on priority, not blocked.
- **`COLOR_ROLES_DESIGN.md`** — design note, nothing built; three real palette
  defects in it, but no operator is blocked.
- **`CONTROL_CHANNEL_DESIGN.md`** — design, nothing built, four open decisions.
- **`uCAT.pas`'s `CATDlgProc`** — unreachable code, ~20 Win32 dialog-item calls.
  Deleting it is cheap but the surrounding helpers are live; do it deliberately.
- **The 68 inherited feature issues** on TR4W-D12 and the 68 on TR4W — contest
  rules, new radios, scoring changes. Product backlog, not modernization.

---

## 10. Where the reasoning went

| topic | live document |
|---|---|
| Adding a contest, and the factory's sequenced completion | `ADDING_A_CONTEST.md` |
| Adding a radio / a setting / a language | `ADDING_A_RADIO.md`, `ADDING_A_SETTING.md`, `ADDING_A_LANGUAGE.md` |
| 64-bit task list | `64_BIT_TASKLIST.md` |
| Win32 idiom sweep | `WIN32_ARTIFACT_SWEEP.md` |
| Clock and CW timing | `PLATFORM_CLOCK_ABSTRACTION.md` |
| Port identity | `PORT_IDENTITY_PLAN.md` |
| SQLite log | `SQLITE_MIGRATION_TASKS.md` |
| Domain layer order | `DOMAIN_LAYER_SEQUENCE.md` |
| First-run wizard | `SETUP_WIZARD_DESIGN.md` |
| Menus and actions | `MENU_ACTIONLIST_PLAN.md` |
| i18n | `I18N_PLAN.md`, `I18N_TOOLS.md`, `TRANSLATION_HANDOFF.md` |
| Bench | `BENCH_QUEUE.md`, `RADIO_BENCH_STATUS.md`, `QTC_BENCH_HANDOFF.md` |
| Build | `tr4w/docs/BUILD.md`, `CI_RUNNER_SETUP.md`, `RELEASE_WORKFLOW.md` |

Finished and superseded work is in
[`migration_interim_artifacts/`](migration_interim_artifacts/), with a README
saying why each one is there. **Read those for why something is shaped as it is,
never for status.**
