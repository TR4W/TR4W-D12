# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Scope note.** This is the **single** guide for the repository — a former second copy at
> `tr4w/CLAUDE.md` was folded in here on 2026-08-04, because two files that both described the build
> and the radio architecture drifted apart. Don't reintroduce one. This file is a map; where it
> summarizes a design, the document listed under [Documentation map](#documentation-map) is
> authoritative.

## MANDATORY: Git command form

Run **every** git command as `git -C /c/tr4w-d12 <subcommand>` (e.g. `git -C /c/tr4w-d12 commit ...`,
`git -C /c/tr4w-d12 push d12 main`). **NEVER** prepend `cd /c/tr4w-d12` (or any `cd`) as the first
command in a shell block. A `cd` to the already-current directory triggers a permission prompt every
time — the `-C` flag targets the repo explicitly with no `cd` and no prompt. (A PreToolUse hook in
`.claude/settings.json` enforces this; if it warns you, fix the command — don't work around it.)
Substitute your own clone's path: the hook derives it from `$CLAUDE_PROJECT_DIR` and will tell you
what it expects.

## MANDATORY: Project guardrails live in the repo

`.claude/settings.json` and `.claude/hooks/` are **tracked**. They carry the hooks every clone needs:
the `git -C` rule, the case-insensitive Pascal glob rule, the begin/end lint, and the CRLF check.

**`.claude/settings.local.json` is gitignored and is yours alone** — permission allow-lists, machine
paths, anything you would not ask another developer to adopt. It wins over `settings.json` where they
overlap. `CLAUDE.local.md` is ignored for the same reason: personal notes, not project instruction.

This split was made on 2026-08-29 and it fixed a real gap. `.claude/` had been ignored wholesale, so
every hook above existed on exactly one machine, and this file had been claiming since August that
`.claude/settings.json` enforced the `git -C` rule — a file that was not in the repository. A control
that is real on one clone and absent on the next is worse than no control, because it is believed.

**Hook commands must use `$CLAUDE_PROJECT_DIR`, never an absolute path.** The clones are not in the
same place — `C:\tr4w-d12` here, `C:\projects\TR4W-D12` elsewhere — and a hardcoded path is a hook
that silently does not run.

## MANDATORY: Never force-push `main`

> **The branch was `fpc` until 2026-08-29.** That name marked an open question — whether FreePascal
> was the toolchain — and the question closed months ago, so the marker had outlived its purpose
> (NY4I). Renamed, not rebuilt: `master` was `fpc`'s own ancestor (merge-base `457bc14d`), nothing
> had diverged, and a rename preserves every SHA. `fpc` no longer exists on the remote.

`main` is shared across at least three clones. **Never rewrite its history** — no `push --force`, no
`--force-with-lease`, no delete-and-recreate. A rewrite invalidates every other clone, and this is
measured, not hypothetical: the merge base moved back to `0913dec7` (2026-07-06), so a `git pull` on
another PC tried to merge 560 commits against 1054 rewritten twins of the same work and produced
**200+ conflicts across the whole tree**. The trees were identical; the only difference was that the
rewrite had stripped the SSH signatures, giving every commit a new SHA.

This is now enforced server-side — ruleset `protect-main` blocks `non_fast_forward` and `deletion`
with **no bypass actors**, so the push is simply **rejected**. When that happens, **do not work
around it**: rebase or merge onto `d12/main` and push normally. If history genuinely needs rewriting,
push it to a new branch and ask NY4I.

### The one rewrite, and the one thing not to do about it

History was rewritten once, 2026-08-19, by a `filter-branch` that stripped
`Claude-Session:` trailers (backup branch `backup-pre-trailer-strip-2026-08-19`).
Signatures were collateral damage: commits on or before that day are unsigned,
later ones signed.

**DO NOT "TIDY" THAT.** Re-signing or re-stripping means another force-push and
another round of broken clones, against a ruleset that will reject it. The
unsigned commits broke nothing; rewriting did.

Forensics and the reset recipe for a stale clone: **`git-history-recovery` skill**.

## MANDATORY: No `Claude-Session:` trailer in commit messages

**TR4W/TR4W-D12 IS PUBLIC.** A `Claude-Session: https://claude.ai/code/session_…` trailer is a link
to a private transcript. Do not put one in a commit message or a PR body. `Co-Authored-By` is fine.

This rule is new on 2026-08-29 and **it is the whole fix.** Until today CLAUDE.md said nothing about
it — zero mentions — so the trailer was not being added against a rule, it was being added in the
absence of one. Agents follow this file; that is what it is for.

If one still reaches the remote, the fix is **forward-only**: stop emitting it, and leave the
published commit alone. Removing it means rewriting published history, which is the thing that cost
a day. Rotate the session if the link matters.

### Optional belt-and-braces

`.githooks/commit-msg` is tracked and strips the trailer if one appears, reporting what it removed.
It is **not** required and nothing depends on it:

```powershell
git -C /c/tr4w-d12 config core.hooksPath .githooks    # opt-in, once per clone
```

`core.hooksPath` is per-clone local config and does not travel, so an uninstalled hook is inert —
which is why the rule above, not the hook, is the control. `.gitattributes` pins `.githooks/*` to
**LF**: a CRLF shebang gives `bad interpreter: /bin/sh^M` and a hook that silently never runs, the
one place in this tree where CRLF is the wrong answer.

## MANDATORY: Development Philosophy

This is a port. We want to do this once. Refactoring is not as important a factor as getting the
object model correct. For example, the radio factory should be a classic factory pattern with proper
inheritance.

## Overview

TR4W is a free amateur radio contest logging application for Windows, written in Object Pascal.
It supports 120+ contests with multi-user networking, extensive radio control, and digital mode
integration. A large tree — `tr4w/src`, with `src/trdos`, `src/radioFactory`, `src/utils` and
`src/lang` beneath it. **Unit and line counts are not stated here on purpose**: they drift, and a
stale count is believed. Measure.

**Repository:** `TR4W/TR4W-D12`, and **`d12` is the only remote.** ~~Note `origin` is a *different*
repo — `TR4W/TR4W`, the Delphi 7 heritage — so `git push origin ...` pushes to the wrong project.~~
**That warning is retired: there is no `origin` remote** (checked 2026-08-29). The D7 relationship is
severed. The D7 *tree* on disk at `C:\TR4W` is unaffected and is still the authority on old
behaviour — see note 7 below.

**Branch:** **`main`** — the active line and the default. ~~`fpc`~~ was renamed to it on 2026-08-29;
`delphi12` is its predecessor and is fully contained in it.
~~`master` means the D7 heritage on both remotes.~~ **Also wrong:** `d12/master` is `457bc14d`
(2026-07-03, *"Pre-migration…"*) and is **`main`'s own ancestor** — the point this line branched
from, inside this repository. It is not D7 heritage and pushing to it would not reach another
project. It is simply stale.
**Toolchain:** **FreePascal 3.2.2 + the Lazarus LCL.** ~~Delphi 12 Athens~~ was left behind on
2026-08-13 once FPC passed the unit tests, the golden corpus (22/0/4) and shipped the
installer. `tr4w/FullBuild-D12-deprecated.ps1` still exists but **no longer works**: deleting the
FMX twins on 2026-08-17 removed units its uses clause needs, so a Delphi build can only be
reproduced by checking out a commit before that. **DCC32 was retired earlier and is long gone.**
**Version:** see `tr4w/src/Version.pas` (`TR4W_CURRENTVERSION_NUMBER`) — `5.0.2`, published as
a **GitHub release** on 2026-08-30.
**Website:** https://tr4w.net — **serves D7 (4.x) ONLY.** 5.x is not distributed there yet, so
"published" above means the GitHub release page and nothing more. An operator who downloads TR4W
from the website today gets 4.x, and that is deliberate until the bench block below closes.

## Where the FPC migration stands

**Definition of done (NY4I):** clone from GitHub onto any PC with FPC and Lazarus installed, run
`FullBuild.ps1`, get the setup `.exe`. **That passes**, and is re-verifiable with
`tr4w/build/Test-FreshClone.ps1`. Out of scope, unchanged: 64-bit, SQLite, the contest factory.

Done: the build system, the lints, the unit tests (10,211/0), the golden corpus (22/0/4), the LCL
port of all four designed forms, `tr4wserver` (**the 2026-08-23 regression is fixed** — see
[Multi-user networking](#6-multi-user-networking)), the NSIS installer, and `release.yml`.

**~~Next in line: attaching a `win-ci` runner.~~ DONE, and PROVEN END TO END on 2026-08-30.**
`windows11-ci-d12` (`[self-hosted, win-ci]`) built, scanned and published **v5.0.2** from a
`v5.0.2` tag push in **5½ minutes** — build 3:00, VirusTotal 2:01, release 0:32, against a
30-minute budget. So the definition of done above is no longer only *re-verifiable* on this
machine; it has been demonstrated on a different one, from a clean checkout, by something that is
not a developer.

**That is a BUILD-AND-PUBLISH pipeline, not a distribution channel.** The installer reaches the
GitHub release page; it does not reach tr4w.net, which still serves 4.x. Do not read a green
pipeline as "5.x is shipping to operators".

**The largest open block is live/bench verification, and nothing in it is provable by code
review.** That is what CI cannot buy: the runner proves the tree BUILDS, not that a radio keys or
a spot decodes. Bench findings still arrive only from a session with real hardware — four defects
on 2026-08-29/30 came that way and none would have failed a build.

**The FMX twins are gone (2026-08-17)** — deleted at the start of the Win32-to-LCL migration
rather than after bench-exercising the LCL forms, because FPC cannot compile FMX at all: they
were units no build compiled, and they had already drifted. See the plan at
`~/.claude/plans/this-project-has-windows-binary-hammock.md`, Phase 0.

~~Per-area D12 status lives in `docs/D12_MIGRATION_ROADMAP.md`~~ — that roadmap is **superseded**;
read it for *why* things are shaped as they are, not for status.

The honest gate on radios is **one verified rig per protocol family**, not 100 rigs. Verified:
Elecraft serial, Elecraft network, Kenwood serial, Icom serial, Flex CAT, Yaesu binary (FT-1000MP,
2026-08-09 — first proof of that family). **Unproven: Icom LAN, Yaesu ASCII, HamLib.** Track that in
[`docs/RADIO_BENCH_STATUS.md`](docs/RADIO_BENCH_STATUS.md). **Those results were obtained under
Delphi**; the Elecraft K4 (network), K3S (serial) and **Yaesu FT-1000MP (binary, 2026-08-31)** have since been re-confirmed against the FPC
binary, the rest have not.

**One English build.** ~~ENG + 8 (RUS/SER/MNG/CZE/ROM/GER/UKR/ESP)~~ — the compile-time language
matrix is no longer built by anything. Translation moves to `resourcestring`, arriving from a
separate worktree. ~~POL and CHN were already decided-out.~~ **That restriction was rescinded
on 2026-08-28 (NY4I) now that catalogues, not compile-time tables, carry the translations.**
Polish already had a catalogue. Chinese did not, and the reason is worth knowing before anyone
"fixes" it: `tr4w/src/lang/tr4w_consts_chn.pas` holds a real translation by Li Jia Wei BA4WI
whose bytes are damaged at the BIT level -- it decodes as neither UTF-8 nor GBK nor Big5, so
`pas2po` flags it `lossy` and refuses to harvest it. `tools/i18n/salvage_lossy.py` recovers the
110 literals that come back as well-formed UTF-8 and writes them into `i18n/tr4w_zh_CN.po` as
**fuzzy suggestions**, because the inversion guesses wrong often enough to matter and a wrong
hanzi looks exactly like a right one. 144 strings are unrecoverable and need his original file.
**Never bulk-defuzz that catalogue** -- fuzzy is the only thing keeping unverified text out of a
build.

## Build System

**The toolchain is FreePascal 3.2.2 + the Lazarus LCL.** Delphi 12 is behind us (2026-08-13): the
FPC build passes the unit tests and the golden corpus (22/0/4), runs the LCL UI, and is what
`FullBuild.ps1` ships. The Delphi script is kept as `FullBuild-D12-deprecated.ps1` for reference —
**don't run both**, they write the same file names from different compilers.

### Everything at once

```powershell
.\FullBuild.ps1                    # lints + unit tests + app + tr4wserver
.\FullBuild.ps1 -SkipServer        # DON'T: the server build is the only guard on the
                                   # console/LCL boundary -- see Multi-user networking
.\FullBuild.ps1 -BuildInstaller    # + the NSIS installer
```

`tr4w/FullBuild.ps1` is the **single packaging path**: lints, then unit tests, then the app — in that
order, so a failing test stops the build *before* it produces a binary anyone could ship. It derives
the version from `src/Version.pas` and **fails** (rather than defaulting to 0.0.0) if it cannot parse
it, then checks the linked `tr4w.exe` actually reports that version. `full.nsi` refuses to build
without `/DTR4WVERSION`.

**One build, English only.** The nine per-language variants are gone; I18N is moving to
`resourcestring` + one binary (NY4I, 2026-08-13), and that work arrives from a separate worktree.
Don't reintroduce a language loop.

### Iterating

```powershell
.\build\Build-App.ps1                 # full rebuild (-B), the safe default
.\build\Build-App.ps1 -Incremental    # seconds instead of minutes
.\build\Build-Tests.ps1 -Run          # the unit-test binary, then run it
.\build\Build-Server.ps1              # tr4wserver
```

- **`-Incremental` for chasing one defect; a full build before believing any result.** FPC's mtime
  rule cannot see a changed compiler switch, `.inc`, or define flip. A designed form is *two* files
  and FPC only watches the `.pas`, so the script touches a `.pas` whose `.lfm` is newer.
- Intermediate output goes to `build-out/` at the repo root (gitignored). `FullBuild.ps1` puts the
  binaries where they ship: `target/tr4w.exe` and `tr4wserver/tr4wserver.exe`.
- **The unit-test exe must live in `tr4w/test/unit/`** — several suites resolve their data from
  `ParamStr(0)`, not the working directory.

**No hardcoded toolchain.** `build/Find-Toolchain.ps1` discovers FPC and Lazarus (honouring
`FPC_HOME` / `LAZARUS_DIR`), and checks what actually matters: a compiler that can *target*
i386-win32 — `fpc.exe` is only a driver, the backend is `ppc386`/`ppcross386` — an i386 RTL, and LCL
units for i386. It lists every location it tried when it fails.

**The unit search paths are defined once**, in `build/Get-SearchPaths.ps1`, for three targets that
genuinely differ (App / Tests / Server). They previously existed in three copies and had already
drifted. `Server` deliberately gets no LCL: `tr4wserver` is a console program. **That exclusion is
also the only thing guarding the boundary**, which is why a unit that quietly grew a `Forms`
dependency broke the server build and nothing else noticed — see [Multi-user
networking](#6-multi-user-networking).

**`spike/` is gone** (2026-08-13). It answered "can FPC do this", the answer was yes, and its probes
are in git history. UI harnesses live in `tr4w/test/ui/`.

### Lints gate the build — from one place

`tr4w/build/Run-Lints.ps1` runs all ten. The list previously lived **only** in `tr4w.dproj`'s
PreBuildEvent, so it gated msbuild and nothing else; an FPC build saw none of them. Add a lint by
editing that one array.

`Lint-LFMProperties` is the odd one out: it compiles a small FPC helper (`build/lintlfm/`) that links
the LCL and asks the same RTTI the streaming loader uses, because "does this class publish this
property, and is this a legal value" cannot be answered by grepping a `published` block. It fails
closed if FPC or the LCL is missing.

### ~~Delphi 12~~ - GONE, and there is nothing left to run

**Every Delphi project file was deleted on 2026-08-31** (NY4I: *"all the d12 specific
files can be removed. D12 is never coming back here"*): `tr4w.dproj`, both
`tr4wserver.dproj`/`.dof`, the unit-test and status-trace `.dproj`,
`FullBuild-D12-deprecated.ps1`, the stray `.cfp`/`.gex`/`.obj`/`.dof`, and the D7
leftovers `tr4w.cfg` and `BatchCompile.cmd`. The msbuild recipe that stood here is
in git history if it is ever wanted; it had not worked since the FMX twins were
deleted in August, so it was a recipe that could not be run.

**`tr4w.lpr` is the program source** (renamed 2026-08-29, `adaa30dd`). **No `.dpr`
remains anywhere in this tree** - all twelve program files are `.lpr`.

**What was deliberately NOT deleted, because the names invite it:**

| kept | why |
|---|---|
| the ~200 `.dpk`/`.dproj`/`.bdsproj` under `tr4w/include/` | the **vendored Indy 10.6.3.3** tree, kept on purpose |
| the ~90 `.obj` files under `tr4w/include/` | **linked by the build**: `{$LINK pcre\pcre_compile.obj}` in `pcre.pas`. Deleting them breaks compilation |
| `tr4w/test/corpus/export-d12-corpus.sh` | the **live golden-corpus oracle**. "d12" is its name, not its toolchain |
| `tr4w/tr4w.res` | linked by `{$R *.res}`; Lazarus writes it from the `.lpi` |
| `docs/D12_*.md`, `tr4w/docs/D12_*.md` | historical reasoning, still linked from the [Documentation map](#documentation-map) |

### Lazarus

Open **`tr4w/tr4w.lpi`** with `C:\Lazarus` — **not** the fpcupdeluxe shortcut, which is x86_64-only
and cannot build a Win32 target at all. The project pins the i386 compiler, since the IDE defaults to
its own x86_64 one.

### Language variants — being replaced, don't extend

`FullBuild.ps1` builds **ENG only** and passes `-dLANG_ENG -dVERSIONINFO_RES`. The compile-time
language mechanism still exists in the source (`{$IFDEF LANG_RUS} LANG = 'RUS';{$ENDIF}` in `VC.pas`,
per-language `src/lang/tr4w_consts_<LANG>.pas` and `res/tr4w_<lang>.res`), but **nothing builds those
variants any more** and no new work should assume they will.

The replacement is `resourcestring` + one binary per platform (NY4I, 2026-08-13), arriving from a
separate worktree once the FPC migration is done and English builds clean. Resource DLLs are out —
they have no FMX/macOS/Linux equivalent.

Until that lands, the old constraint still governs the files that are still there: **`src/lang/*.pas`
are UTF-8 *with a BOM*** and must stay that way — a no-BOM file is decoded with the build machine's
ANSI codepage and silently corrupts the non-ASCII literals. The historical codepages were
per-language (1251 rus/ukr/mng, **1250 cze/rom/ser** — Serbian is *Latin* — 1252 ger/esp/eng), which
is why a blanket conversion was wrong. Background:
[`tr4w/docs/D12_STRING_MODERNIZATION_PLAN.md`](tr4w/docs/D12_STRING_MODERNIZATION_PLAN.md).

## Testing

Three layers, all real and all expected to be green before a commit.

**1. Unit tests** — `tr4w/test/unit/tr4w_unit_tests.lpr`, a minimal DUnit-compatible framework
(`uTR4WTestFramework.pas`, no external deps). **Zero failures is the baseline**; the count is not
stated here because it grows every commit. Take it from the newest commit message.

```powershell
.\tr4w\build\Build-Tests.ps1 -Run
```

`FullBuild.ps1` runs them too, **before** it builds the app, so a failing test stops the build before
it produces a shippable binary. **The exe must land in `tr4w/test/unit/`** — several suites resolve
their data from `ParamStr(0)`, not the working directory.

Covers ADIF, Cabrillo, callsign routines, multipliers, CTY.DAT, band lookup, CRC32, grid/distance,
text/file/math utils, DX-spot parsing, CW framing/keyer, and the radio factory (Icom CI-V, Kenwood,
Yaesu ASCII/binary, Elecraft IF, Flex, HamLib IDs, registry taxonomy, capability pinning).
It links only leaf `src` units, so **the TRDOS contest engine is not unit-covered** —
`ProcessExchange`, scoring and dupe need the app's globals booted.

**2. Golden-master corpus** — the regression oracle for the contest engine.
`bash tr4w/test/corpus/export-d12-corpus.sh` runs the app's headless export mode
(`tr4w.exe "<contest>.CFG" /EXPORT`, `src/uProgramMain.pas`) over 13 real D7-written binary logs and
byte-diffs both artifacts — ADIF and Cabrillo — against frozen D7 references (13 sets × 2 = 26
comparisons).

- **Baseline: `22 passed, 0 failed, 4 known-divergence, 0 awaiting-candidate` = GREEN.**
- **Rebuild the app first**, and **guard that TR4W is not running** (`Get-Process -Name tr4w`) — a
  running instance collides on `target/` and every set reports a false FAIL.
- Run the corpus, **read the result, then commit**. Never chain the corpus run and `git commit` in
  one shell block.

**3. Integration / bench** — `tr4w/test/integration/` drives real serial radios (or `tools/radiosim`)
via `run-bench.ps1`. `tr4w/test/logdump/` dumps binary `.dat` logs to JSONL through the canonical
`ContestExchange`; `tr4w/test/python/verify_adif_export.py` cross-checks ADIF export against it.

**Lint scripts** in `tr4w/build/`. `Lint-PCharAnsi.ps1`, `Lint-RadioRegistry.ps1` and
`Lint-PollRadioState.ps1` are in `Run-Lints.ps1` and GATE THE BUILD. `Lint-PascalBeginEnd.ps1` and
`Lint-ChangedPascal.ps1` are NOT — the first runs as the `PostToolUse` hook
`.claude/hooks/pascal-lint-hook.ps1`, which warns after the edit and never blocks; the second is
run by hand. This sentence used to list all five as though they gated the build (corrected
2026-08-31), which is why the style itself is now written down under
[Code style](#code-style--pascal-and-python) rather than left to a linter.

Scoring, multiplier and exchange-parsing changes still deserve real-contest testing — the corpus is a
strong net, not a proof.

## Architecture Overview

### Hybrid: legacy core + modern Windows layer

1. **TRDOS layer** (`tr4w/src/trdos/`) — the largest single subsystem, and the DOS-era engine
   ported to Windows. Stable, battle-tested, procedural.
2. **Windows layer** (`tr4w/src/`) — Win32 UI, networking, integrations.
3. **Modern factories** — `tr4w/src/radioFactory/` (one unit per radio; `Lint-RadioRegistry`
   counts them on every build) and the CW keyer factory
   (`src/uCWKeyer*.pas`) are genuine OOP subsystems: proper base classes, virtuals, capability sets,
   and self-registration. Both were built with the **strangler pattern** — thin adapters over the
   existing globals first, prove the seam on hardware, then delete the legacy path. That is the
   model for how the next subsystem (contest factory) should be built.

### Framework

**THE UI IS LCL FORMS. ~~Direct Win32 API, no VCL forms~~ — that was true until
2026-08 and is not now.** The program runs `Application.Run`; the hand-rolled
`GetMessage` / `TranslateMessage` / `DispatchMessage` loop is gone.

**EVERY tool window is a designed form.** Converted 2026-08-24/25: function keys,
band map, stations, SCP/master, both dupe sheets, the five remaining-multiplier
windows, PostScores, HamScore, Intercom, MP3 Recorder, both radio panels, and
Network — then **Telnet and MMTTY**, which this file listed as the last two
holdouts until 2026-08-26. `uTelnetForm` and `uMMTTYForm` are in `tr4w.lpr`;
the DX cluster window landed in `00e9a987`. `Lint-Win32Dialogs[ui]` is at 748.

**AND SO IS EVERY DIALOG THAT USED `tDialogBox` (2026-08-29) — WHICH IS NOT
EVERY DIALOG.** Corrected 2026-08-31: that claim tracked one creation path and
missed `CreateModalDialog` (in `TF.pas`), through which **eight hand-built Win32
dialogs are still live**: `uAltP`, `uCbrSum`, `uErmak`, `uFileView`, `uLogEdit`,
`uLogSearch`, `uQTCR`, `uQTCS`. `uQTCR` also subclasses its edit controls with
`SetWindowLong(GWL_WNDPROC)`, which makes it the heaviest of them.

All five that set a title did it with `PWideChar(<resourcestring>)` — a POINTER
CAST, not a conversion — so every one showed a garbled caption ("????????" on
Alt-P, NY4I 2026-08-31, being 16 caption bytes read as 8 UTF-16 units). Fixed;
the conversions themselves are still owed.

The last `tDialogBox` template in use was **73**, the server-log synchronize
window; it is
`src/ui/lcl/uServerLogForm.pas`. `tDialogBox` has no live caller left. Two
things that conversion is worth remembering for: a control id can be written by
`SetDlgItemInt` from **any** unit holding the window handle — the 'sent records'
field looked dead from `uGetServerLog` and its writer was in `uNet` — and a
worker thread that used to poke dialog items must now marshal, which
`uGetServerLog.ReportSyncProgress` does by `SendMessage` so the handler runs on
the main thread.

**A CONVERTED WINDOW LOSES ITS TRANSLATIONS, SILENTLY, AND EVERY CONVERSION UP
TO 2026-08-29 DID.** `uServerLogForm` is the pattern to copy instead: its `.lfm`
text is an explicit designer placeholder and `HandleShow` assigns every caption
from the constant. The `RC_` names it uses had never been translatable at all —
their text reached the screen from the compiled `.RES`, so `pas2res` left them
out on purpose — and **naming them from Pascal is what promotes them**, because
the generator emits every `RC_` a source file references. Run `pas2res` and then
`po_merge` after a conversion.

**NEVER run `pas2po` to pick up new strings.** It rebuilds a catalogue from the
`TC_`/`RC_` tables alone and drops every `.lfm` and resourcestring key the
Lazarus harvest contributed — measured 2026-08-29: **2,203 real translations
destroyed across ten catalogues in one run**, with no warning and a clean exit.
`po_merge --pot` is the additive tool and the only safe one; `pas2po` is for
creating a *new* language.

The underlying trap: the Win32 code assigned captions from `TC_`/`RC_`
constants, which are what the 16 `.po` catalogues translate. A designed form carries its caption
in the `.lfm`, and every conversion has re-typed the English there and left the
constant behind. Telnet is the clearest case: the `.lfm` says
`Caption = 'Connect'` while `TC_TELNET_CONNECT` sits in the catalogues with
`es='Conectar'`, translated by a native speaker and now unreachable.

Measured 2026-08-26: **469 `.lfm` captions ship as English and only 45 of 545
are assigned at run time.** Nothing warns; nothing fails; the English simply
shows in every language. When you convert a window, check whether the text you
are typing already exists as a `TC_`/`RC_` constant — see
[`docs/I18N_TS_EVALUATION.md`](../tr4w-i18n/docs/I18N_TS_EVALUATION.md) and the
tooling in `c:/tr4w-i18n/tools/i18n`.

The seam is `OpenTR4WWindow` (`MainUnit.pas`): an arm returning the form's
`Handle` and setting `lclForm`, and that window's `WndProcAdr` line deleted. A
form is positioned through `lclForm.BoundsRect`, **never** `SetWindowPos` — the
LCL holds its own bounds and pushes the designed ones back down when it shows,
which silently undid a restored position until 2026-08-25.

Read [`docs/BANDMAP_LCL_DESIGN.md`](docs/BANDMAP_LCL_DESIGN.md) and the notes at
the top of any `src/ui/lcl/` unit before converting another window; several
record traps that no compiler catches (colour used as state, a `TLabel` having
no window handle, a `TPanel` caption not wrapping).

- A **proof-of-concept** for hosting VCL forms alongside the Win32 loop exists on branch
  `Add-VCL-to-Program`; the technique is preserved in
  [`docs/VCL_WIN32_COEXISTENCE.md`](docs/VCL_WIN32_COEXISTENCE.md). Historical now that the
  conversion is nearly done.
- Heavy use of **global variables** for state; Pascal **records** for most data structures; manual
  resource management.

### Key entry points

**`tr4w/src/uProgramMain.pas`** — the startup sequence: single-instance mutex, logger, optional
WSJT-X and external-logger servers, `CreateMainWindow`, WinKeyer thread, then `Application.Run`.
Grep for the step you need; the order above is what matters, not the offsets.

**It moved out of the program file on 2026-08-25 and that was the point of the exercise.** A program file is
invisible to a search of `src/`, so the most order-sensitive code in the program lived in the one
file nobody greps — and "where does X happen at startup" had the answer "in no unit at all". The
`.lpr` is now 441 lines: the uses clause, the resource directives, and `begin RunTR4W; end.`

**The uses clause stays in the `.lpr`**, so "which units are compiled" and "who references this" are
still `.lpr` questions — that is what the `enforce-pascal-glob` hook is warning about, and it is
still right. `uProgramMain`'s own uses clause is a copy of it in the same order: this program relies
on use-order for name resolution (`SysUtils.SysErrorMessage` vs `TF`'s), so do not tidy it as a side
effect of something else.

Two facts about that sequence that grep will not tell you: **headless `/EXPORT` mode boots the
contest, writes the files and `Halt(0)`s before any GUI or network init**, and config load
(INI → CFG → common messages) plus CTY.DAT load happen before the main window.

**`tr4w/src/MainUnit.pas`** — main window creation, keyboard/mouse input, display coordination, and
the process-wide globals: `wsjtx: TWSJTXServer` (171), `externalLogger: TExternalLogger` (172),
`logger: TLogLogger` (175). **Any standalone EXE that links app units must assign `logger`** or it
will AV on the first log call.

**UI support:** `uWinManager.pas` (window manager), `uDialogs.pas` (dialog utilities),
`uBandmap.pas`, `uCAT.pas` (the radio config dialog).

## Core Subsystems

### 1. TRDOS subsystem (`src/trdos/`)

Stable, proven contest logic. **Avoid modifying unless necessary** — prefer new units in `src/`.

**The no-LCL half of that boundary was RESCINDED on 2026-08-23 (NY4I).** Until then no unit under
`src/trdos/` referenced the widget set at all, and the rule was read as forbidding it — which would
have meant building a forwarding facade just so `LOGWIND` could clear a text box. TRDOS units may now
use the LCL directly, and `LOGWIND`/`LOGEDIT` are the first that do. The rest of the rule stands:
this is proven contest logic, so new *behaviour* still belongs in `src/`.

The Lines column is gone (2026-08-31): `wc -l` answers it, and six of eight figures had drifted.
The Role column is what this table is for.

| File | Role |
|------|------|
| `LOGSTUFF.PAS` | Contest logging, exchange parsing, QSO validation -- the biggest unit here |
| `tree.pas` | Utility library |
| `LOGWIND.PAS` | Window management and display |
| `PostUnit.PAS` | Post-contest processing, Cabrillo export |
| `HELP.PAS` | Help text |
| `LOGSCP.PAS` | Super Check Partial |
| `LOGRADIO.PAS` | **Legacy** radio control — see the radio section below |
| `LOGSUBS2.PAS` | Core logging subroutines |
| `LogCW.pas` | CW message memories/function keys; the **facade** over the keyer factory |
| `LogDupe.pas` | Duplicate checking |
| `FCONTEST.PAS` | Contest type definitions and defaults |
| `CFGDEF.PAS` | Configuration parameter defaults |

Contest-specific modules: `LOGWAE.PAS` (WAE), `LOGDOM.PAS` (domestic/QSO parties), `LOGK1EA.PAS`
(also the CPU keyer), `LOGGRID.PAS`, `LOGEDIT.PAS`.

(Files like `LOGRADIO.$$$`, `LOGSUBS2~.PAS`, `PostUnit.PAS.bak` are editor debris, not units.)

### 2. Type system (`src/VC.pas`, `src/TF.pas`)

**`VC.pas` is the source of truth** for types: 120+ `ContestType` values, band and mode enums, the
~60-element `TMainWindowElement`, colour schemes, and the compile-time switches (`tDebugMode`,
the `LANG_xxx` block near line 223).  ~~`MMTTYMODE`~~ was deleted 2026-08-18.

**`TF.pas`** holds UI helpers, dialog utilities, and format/conversion functions. Note: TF's
hand-rolled `IntToStr`/`StrToInt`-style shims are legacy weight — prefer the RTL and delete the shim
when you touch a call site (`TF.StrToInt` is lenient and silently returns 0; the faithful replacement
is `StrToIntDef(s, 0)`).

### 3. Configuration (`src/uCFG.pas`, `src/trdos/CFGCMD.pas`)

Loaded from `settings/tr4w.ini`, contest `.cfg` files, and common messages. The parser handles
`MY CALL = N6TR`-style commands via `CFGRecord` structures (command text → variable address → type →
range). Supports network synchronisation for multi-station setups.

**THE DESTINATION IS JSON, NOT `TIniFile`** — this said "slated for a rewrite onto Delphi's native
`TIniFile`" until 2026-08-21, which had been wrong for months. NY4I: *"We switched to all json a
while ago. Except for the contest.cfg file we should not be writing ini files."*

**Where it actually stands, measured 2026-08-21** (rerun rather than trusting this):

| | |
|---|---|
| The **stores** — radios, keyers, profiles, window layout, UDP | **all JSON**, in `settings/tr4w.json` |
| Settings graduated to JSON (`csJSON` + `RegisterStoredSetting`) | **77** |
| Settings still writing `tr4w.ini` (`RegisterLegacySetting`) | **153** |
| Remaining Win32 ini API call sites outside `tr4wserver` | **26** |

So the stores moved wholesale; the settings move **one at a time**, and `tr4w.ini` is still read
at startup for the 153 that have not. The two halves of each move — `crS: csJSON` and
`RegisterStoredSetting` — **must land in the same commit**, and were verified in sync for all 230
on 2026-08-21. Flip one without the other and the setting appears to save and is gone on restart.

**`csOwned` IS A UI MARKER, NOT A STORAGE ONE** — the single most confusing thing here, and
it confused NY4I and me on 2026-08-21. `VC.pas:891`: *"STILL APPLIED, but hidden from Options
because another dialog owns it."* Commit `79d4b6f0` moved **173 settings into Preferences** by
marking them `csOwned` — that moved their EDITING. Their STORAGE is still `tr4w.ini`. Only
`csJSON` moves storage.

| status | rows | edited in | stored in |
|---|---:|---|---|
| `csOld`/`csNew` | 6 | Ctrl-J | `tr4w.ini` |
| `csOwned` | 247 | **Preferences** | **`tr4w.ini`** |
| `csJSON` | 166 | Preferences | `settings\tr4w.json` |
| `csRem` | 89 | — withdrawn | — |

So a setting can appear in the new Preferences UI and still not persist on a station whose
`tr4w.ini` is read-only or absent. `SetCFGCommandValue` reports that now instead of losing it
silently, and `Lint-SettingsMigration.ps1` fails the build if the three halves of a migration
(`csJSON`, `RegisterStoredSetting`, `MIGRATED_COMMANDS`) ever disagree.

**The contest `.cfg` is deliberately exempt**: it is going to an SQLite3 contest file, not to JSON
(NY4I, 2026-08-21). `tr4wserver.ini` belongs to a different program and is out of scope.

`CommandsArray` *is* the ini parser, so every key is an editable "command" — there is no read-only
attribute, no cross-key invariant, and no value validation. Park config design defects against the
JSON move rather than patching piecemeal. The full state, the per-unit table and the rule for
moving a setting are in [`docs/CFG_MIGRATION_PLAN.md`](docs/CFG_MIGRATION_PLAN.md).

### 4. Contest flow

1. Callsign typed → `CallWindowChange`
2. Super Check Partial → `LogSCP.pas` (TRMASTER.DTA)
3. Dupe check → `LogDupe.pas`
4. Country/multiplier → `uCTYDAT.pas` (CTY.DAT), `uMults.pas`
5. Exchange parsing → `LOGSTUFF.PAS` `ProcessExchange()`
6. Validation → `ContestExchange` record
7. Network broadcast → `uNet.pas`
8. Display update → `LOGWIND.PAS`

### 5. Radio control — the factory

**All radios go through the factory.** `src/radioFactory/` holds one unit per family base and one per
model. **100 registrations** — 99 `RegisterRadio` (enum-keyed) plus one `RegisterRadioById` (TCI, a
string-id radio with no enum member) — covering every selectable `InterfacedRadioType` except
`NoInterfacedRadio`.

- **Base class:** `src/radioFactory/uFactoryRadioBase.pas` (`TFactoryRadioBase`).
  `uNetRadioBase.pas` is gone; `uRadioFactory.pas` moved into `src/radioFactory/`.
- **Registry:** `uRadioRegistry.pas` is the single source of truth; each unit self-registers from its
  `initialization` section. It owns the per-model data that used to live in parallel arrays — CI-V
  address, HamLib `rig_model`, startup command, network metadata.
- **Families:** Icom (CI-V, `uRadioIcomBase` + legacy/modern/read-limited tiers), Kenwood (serial +
  LAN), Yaesu (ASCII, ASCII-legacy, binary), Elecraft (K2/K3/K4/KX3), Ten-Tec, FlexRadio (CAT and
  the 4992 Ethernet API), HamLib, TCI.
- **Capabilities are owned by the radio object** — a `TRadioCapabilities` set plus a
  `DefineCapabilities` virtual (an Icom-family virtual; the other 68 drivers set
  `FCapabilities.Flags` in the constructor). Not a global table.

**Two hard rules:**

1. **A base class must NEVER ask which radio model it is.** The subclass declares a trait; the base
   guards on the trait. Three real defects in one afternoon had exactly the shape
   `if RadioModel in [FT857, FT897]`.
2. **One `RegisterRadio` per unit.** One model, one file, one registration — and every model an
   operator can buy gets its own entry and display name even when models share a class (FT-817/818,
   IC-7850/7851). A duplicate display name makes a model invisible in the radio list.

**Adding a radio** should touch only its own unit(s), `tr4w.lpr`, and the unit-test `.lpr` — verified
2026-08-02 by adding TCI (a WebSocket radio) with no change to any shared file. Read
[`docs/ADDING_A_RADIO.md`](docs/ADDING_A_RADIO.md).

**Legacy radio code: DELETED, not deprecated.** Track E completed 2026-08-02 (`1c820091`).

- `uRadioPolling.pas` went **4,621 → 1,336 lines** (`a84266bd`): the `case rig^.RadioModel of`
  dispatch and all 37 per-model pollers are gone. Its public surface dropped from 50 exported
  routines to 14. Reachability was *computed* by a call-graph walk, not assumed.
- `LOGRADIO.PAS` went **4,416 → 3,165 lines** with 11 model dispatches → 0. All seven Icom quirk
  typesets (`IcomRadiosThatSupportRIT`, VFOB, PSKMode, SplitSetOnly, ModeSetNoFilter,
  TXStatusUnreadable, 6to60WPMKeyer) and the last three `RadioSupports*` typesets are deleted;
  ~~`RadioParametersArray` is unreferenced.~~ **Both enum-indexed radio tables are DELETED
  (2026-08-28) — `RadioParametersArray` and `InterfacedRadioTypeSA`.** "Unreferenced" was true of
  the running program and missed the point: they were `array[InterfacedRadioType]`, so the
  *compiler* demanded a row for every radio anyone added, and the unit tests then compared the new
  radio against a row someone had just invented for it. That is a second definition of what a radio
  is, and it had already drifted — the name table was missing `TS140` and carried a `TS530` the enum
  never had, so **a config saying `TS440` selected the TS-140 driver** and `TS140` could not be
  selected at all. Four Kenwoods, silently, for years.

  The factory owns per-model data now; `uRadioRegistry.RadioTypeToken` derives the config-file
  spelling from the enum itself, so that drift is unrepresentable rather than merely fixed.
  **`Lint-NoRadioTables` fails the build if a hand-typed table indexed by a radio enum comes back.**
  **LOGRADIO now holds no per-model radio knowledge.**
- The `is TIcomRadio` / `is TKenwoodLAN` credential casts became virtuals on `TFactoryRadioBase`
  (`ApplyNetworkCredentials`, `ApplyDataModeID` — named for the *concept*, not the vendor).

Read the D7 tree as the authority on what the old program did — never mirror a fix back into it.

**`src/uCAT.pas` — the DIALOG IS DEAD, the HELPERS ARE NOT.** This said `CATDlgProc` was "the
live radio configuration dialog … actively maintained" until 2026-08-31, and that is wrong:
**`CATDlgProc` has no caller.** Every `tDialogBox`/`DialogBoxParam` in `MainUnit` is commented out
and the proc now appears only in comments — `uMenu.pas` calls it "the legacy per-slot dialog". Its
~20 Win32 dialog-item calls are unreachable code.

What IS still live in that unit is the surrounding machinery the Preferences form uses: port
enumeration, the filtered/greyed COM drop-down (item data, never index arithmetic), string-id
factory radios in the type combo, and `RestartPollingThread`. Do not delete the unit; do not treat
`CATDlgProc` as the place to change radio configuration.

**SO2R:** `src/uRadio12.pas` manages Radio 1 / Radio 2, automatic switching on focus, independent VFO
control.

**Threading:** each radio instance runs its own reading thread with exponential-backoff reconnection
(1s → 30s). An open COM port is *not* a working link — serial radios need a real close/reopen
(`MaintainSerialLink`, on the radio, not in the poller). And a radio can answer CAT before it is
ready: gate post-connect sends on link *stability*, not presence.

### 6. Multi-user networking

**TR4WServer** (`tr4w/tr4wserver/`, its own `.lpr`) is the TCP/IP server for multi-op stations:
centralised log, multipliers, dupe checking, serial-number lockout, time sync. Binary packet
protocol with CRC32 (`src/utils/networkmessageutils.pas`).

**It is built by `FullBuild.ps1` as a normal step again (2026-08-29).** It had not compiled since
2026-08-23: `a3c671cc` added a `TF` → `uCrashLog` edge so a fault on a worker thread would not be
silent, and `uCrashLog` used `Forms`, so the chain

    tr4wserver.lpr → tr4wserverUnit → TF → uCrashLog → Forms

dragged the LCL into a console program whose search paths deliberately exclude it. **Nothing
surfaced it for three days**, because that search path is the only guard on the boundary and it
fires only on a full build — then `-SkipServer` kept it hidden for six more.

**There was no LCL conversion to wait for.** `uCrashLog` is split instead: it keeps the RTL
reporter (`LogCaughtException`, `EarlyTrace`, `OnMainThread`, the `ExceptProc` hook) and links
anywhere, and the two statements that need a widget set — `Application.OnException` and
`Application.ShowException` — are `src/ui/lcl/uCrashLogLCL.pas`. A program with an LCL calls
`InstallCrashLogLCL`, which installs both; `tr4wserver` calls `InstallCrashLog` and now gets crash
logging, which it never had.

The `{$IFDEF FPC}` that used to guard the LCL half was on the **wrong axis** and could not have
helped: it asks which *compiler*, when the question is which *program* has a widget set. Both are
FPC. No conditional can answer that — only the unit graph can, which is why the answer is a second
unit. **`-SkipServer` now also warns that you have skipped the only guard on that boundary.**

Client side: `src/uNetClient.pas`, `src/uNet.pas`, `src/trdos/LogNet.pas`,
`src/uGetServerLog.pas`.

**THE CLIENT LINK IS INDY, NOT WINSOCK (2026-08-25).** `uNet` used to drive a raw
socket and have Windows deliver its events as a WINDOW MESSAGE —
`WSAAsyncSelect(NetSocket, <network window HWND>, WM_SOCK_NET, ...)` — so the
network window *was* part of the transport and could not become a form.
`TNetClient` (`src/uNetClient.pas`) owns the socket and the password handshake,
modelled on `TDXClusterClient` but byte-oriented. `NetSocket` is gone; ask
`NetIsConnected`.

Parsing still runs on the **main thread**: the reader appends bytes under a lock
and `Application.QueueAsyncCall`s a drain, so every message arm is unchanged. The
short tail is now KEPT between reads — which is why an unrecognised message id
must **not** be, or the same bytes re-parse forever and the link wedges in
silence. `ConsumeNetBuffer` reports that case and the drainer resynchronises
loudly.

### 7. External logger integration

`src/uExternalLoggerFactory.pas` creates loggers; `uExternalLoggerBase.pas` (`TExternalLoggerBase`) is
the abstract base; `uExternalLogger.pas` and `uExternalLoggerManager.pas` carry the implementation.
Each logger runs its own reading/sender thread pair.

| Type | Status |
|---|---|
| `lt_DXKeeper` | Complete |
| `lt_ACLog` | **Incomplete** — the factory logs a warning on creation |
| `lt_HRD` (Ham Radio Deluxe) | **Incomplete** — same |

Note this is the **older factory shape**: a `case` in one class function
(`TExternalLoggerFactory.CreateLogger`) raising `EExternalLoggerFactoryException`, not the radio
factory's self-registration registry. If it grows, move it toward the registry pattern rather than
extending the `case`.

### 8. Digital mode integration

- **WSJT-X** (`uWSJTX.pas`) — UDP; sends colorization hints, receives decodes/QSOs.
  Enabled with `WSJT-X ENABLE = TRUE`.
- **MMTTY** (`uMMTTY.pas`) — RTTY engine.  ~~Gated on `MMTTYMODE` in `VC.pas`~~ — that
  compile-time switch was deleted 2026-08-18 (NY4I: "the boolean controls it now").  It
  had been `= True` for the life of this tree, so all 20 of its `{$IF}` blocks always
  compiled; one `{$IF NOT MMTTYMODE}` block and one `{$ELSE}` arm never did.
- **MixW** (`uMixW.pas`).

### 9. DX tools

- **Band map** (`uBandmap.pas`, `src/ui/lcl/uBandMapForm.pas`) — spots by frequency,
  click-to-tune, colour-coded, filterable. **A spot's age is a UTC `TDateTime`
  stamped WHEN IT ARRIVED** (`FSysTime`), and `FAgeSeconds` is elapsed seconds;
  the arithmetic is `src/uSpotAge.pas`, a leaf with 11 pin tests. Never age a
  spot from the time in the cluster line — that carries only HHMM, so every spot
  of a clock minute shared a timestamp and they all expired on the same tick.
  `BAND MAP DECAY TIME` is in **minutes** (the help file says so) and is compared
  in seconds. `BandMapFileVersion` is `'2'`.
- **DX cluster** (`uTelnet.pas`, `uDXClusterClient.pas`, `uDXSpotParse.pas`, `uSpots.pas`) — the
  Telnet client is now Indy-based (`TDXClusterClient`, fixing lines lost at TCP segment boundaries),
  spot parsing is extracted and unit-tested, and auto-reconnect is on by default (5s doubling to a
  60s cap, gated on having connected at startup).
- **Country database** (`uCTYDAT.pas`) — CTY.DAT parsing, callsign → country/zone/continent.

### 10. CW keying — the keyer factory

**The CW keyer factory is BUILT.** Phases A and B and the CAT repoint are complete; see
[`docs/CW_Keyer_Factory_Plan.md`](docs/CW_Keyer_Factory_Plan.md) (its status header is current and
records the commits).

TR4W has four mutually exclusive ways to key CW. Each is now a `TCWKeyer` strategy adapter, and
**no consumer outside the factory branches on keyer type any more**:

| Adapter | Unit | Device |
|---|---|---|
| `TCWKeyerCAT` | `src/uCWKeyerCAT.pas` | CW-by-CAT over the radio link |
| `TCWKeyerWinKey` | `src/uCWKeyerWinKey.pas` | WinKeyer (own thread, `uWinKey.pas`) |
| `TCWKeyerYCCC` | `src/uCWKeyerYCCC.pas` | YCCC SO2R+ box |
| `TCWKeyerCPU` | `src/uCWKeyerCPU.pas` | DTR/RTS/LPT keying (`LOGK1EA`) |

Base and selection live in `src/uCWKeyerBase.pas`; `src/trdos/LogCW.pas` is the facade. Per-keyer
capabilities (`ckTune`, `ckDeleteLastChar`, `ckMessageChaining`) let the UI grey what the chosen
interface cannot do. `LOGDVP.PAS` handles voice.

**The CAT repoint (done 2026-08-03) ran in three steps and is worth understanding:**

1. `edc9cbf2` — the send moved out of `RadioObject.SendCW` into `uCWKeyerCAT.CWByCATSend`, and
   **`RadioObject.SendCW` was deleted**. `CWByCATSend` takes the radio *explicitly* rather than
   assuming `ActiveRadioPtr`, because SO2R (`KeyersSwapped`) and the interlock nominate a radio.
2. `a9e77155` — the capability gates repointed to `RadioObject.HasCapability`. The old model-keyed
   form could not see a string-id radio, so TCI silently got no CW at all.
3. `4a7f9833` + `55f4f5ed` — the *data* moved onto the radio. The frame rule and prosign dialect are
   `TRadioCapabilities.CWFrame` / `.CWProsignDialect`, and the `KY <text>;` command lives on a real
   base class:

```
TFactoryRadioBase
├── TKYRadio                    'KY <text>;' -- the command, once
│   ├── TElecraftRadio          + * =, no SN
│   │   ├── TElecraftSerial (K2/K3/KX3)
│   │   └── TK4Radio
│   └── TKenwoodProtocolRadio   % _ > [
│       ├── TKenwoodSerial
│       ├── TKenwoodLAN
│       └── TFlexCAT            speaks the Kenwood CAT set by design
├── TIcomRadio                  ^SN ^AR ^SK ^BT
├── TTenTecOrionRadio           NOT a KY radio -- keys '/<char><CR>' one char at a time
└── TFlexAPI                    NOT a KY radio -- SmartSDR cwx, #127 for a word space
```

Orion and FlexAPI are **deliberately not** under the Kenwood base: their Kenwood-looking spellings
came from LOGRADIO copying its Kenwood arm, not from the protocol. Inheriting to save five lines
would silently apply every future Kenwood-base behaviour to a radio that is not a Kenwood.

`src/radioFactory/uCWFraming.pas` is now **chunking and padding and nothing else** — it cannot name a
vendor, a command or a protocol. Prosigns are declared via `DeclareCWProsigns`, a **virtual** called
from the base constructor (not a constructor per family base — `TFactoryRadioBase.Create` is
overloaded, and a `constructor Create; reintroduce` in between hides both overloads and breaks every
`inherited Create(ProcessMessage)` below it).

**Two traps this work surfaced, neither visible to the compiler:** the TS-850 declared `rcCWByCAT`
but was missing from the frame table (uninitialised `maxLen`), and Icom values written into
`DefineCapabilities` were wiped by every Icom subclass that replaces it wholesale — leaving all
fourteen keying Icoms with "no limit". `test/unit/uTestCWFraming.pas` now **fails if any radio
declares `rcCWByCAT` without stating its frame rule.** Write the exhaustive pin test *with* the move.

**Decided, not open:** Yaesu CW-by-CAT is out of scope (NY4I). Yaesu's `KY <n>;` plays a preset
memory slot, not free text, so it cannot serve contest CW.

**Genuinely open (NY4I, design not refactor):** `ActiveCWKeyer`'s precedence chain
(CAT → WinKeyer → YCCC → CPU) is an *artifact* of the original if/else ordering, not a decision. An
explicit "CW INTERFACE" config command would make it a lookup, delete `WarnIfKeyerConfigsConflict`,
and turn today's silent WinKeyer-failed-to-open downgrade into a reported error. TR4QT is the likely
reference.

### 11. Logging framework

Log4D (`src/Log4D.pas`), global `logger: TLogLogger`, rolling file appender to `tr4w.log`, level from
`DEBUG LOG LEVEL` in `tr4w.ini` (`NONE`…`TRACE`). Any standalone EXE that links app units must assign
the `MainUnit` global `logger` or it will AV.

## Documentation map

Read the specific doc before acting in its area — these are current and this file is only a summary.

| Topic | Document |
|-------|----------|
| Build & test recipe | `tr4w/docs/BUILD.md` |
| **Setting up a build environment** | **`tr4w/docs/BUILD.md`** — one installer; verified from scratch 2026-08-14 |
| CI runner setup | `docs/CI_RUNNER_SETUP.md` |
| Adding a radio | `docs/ADDING_A_RADIO.md` |
| Radio factory design | `docs/RADIO_FACTORY_README.md`, `docs/NETWORK_RADIO_FACTORY_ANALYSIS.md` |
| Radio bench status | `docs/RADIO_BENCH_STATUS.md`, `docs/BENCH_TEST_PLAN_2026-08-01.md` |
| Legacy removal plan | `docs/LEGACY_DEPENDENCY_AUDIT.md`, `docs/PHASE_INVENTORIES.md` |
| CW keyer factory | `docs/CW_Keyer_Factory_Plan.md` |
| Adding a contest | `docs/ADDING_A_NEW_CONTEST.md` |
| **Roadmap (what's next)** | **`docs/ROADMAP.md`** |
| **The order the three big pieces go in** | **`docs/DOMAIN_LAYER_SEQUENCE.md`** |
| **Band map -> LCL (read before touching `uBandmap`/`uSpots`)** | **`docs/BANDMAP_LCL_DESIGN.md`** |
| **I18N: resourcestrings, .po and where every string lives** | **`docs/I18N_PLAN.md`** |
| **Which `.lfm` captions actually reach the screen** | **`docs/CAPTION_REVIEW.md`** — every design-time caption in `src/ui/lcl`, marked `wired` (assigned at run time, so the `.lfm` text is a placeholder) or `SHIPS` (the English in the `.lfm` is what an operator sees). This is the measurement behind "469 captions ship as English" |
| **Adding a language (recipe; step 6 is a known gap)** | **`docs/ADDING_A_LANGUAGE.md`** |
| **Running the i18n scripts** | **`docs/I18N_TOOLS.md`** |
| **Sending a language to a translator / taking it back** | **`docs/TRANSLATION_HANDOFF.md`** |
| **What the translator receives** | `docs/TRANSLATOR_GUIDE.md` |
| **Panadapter / spectrum seam** | **`docs/PANADAPTER_LCL_DESIGN.md`** |
| **Colour roles / theming (read before restyling ANY window)** | **`docs/COLOR_ROLES_DESIGN.md`** -- the palette names COLOURS, not roles, which is what blocks theming; and the radio panel's cyan IS its active-radio indicator, so removing it deletes a state signal |
| **Restyling the converted grids (PARKED until conversions finish)** | **`docs/GRID_RESTYLE_PLAN.md`** |
| **Display state as a model (PARKED; successor to the conversions)** | **`docs/DISPLAY_STATE_MODEL_PLAN.md`** |
| ~~D12 migration roadmap~~ | ~~`docs/D12_MIGRATION_ROADMAP.md`, `tr4w/docs/D12_RELEASE_READINESS.md`~~ — superseded, read for *why* not *status* |
| String/ShortString work | `tr4w/docs/D12_STRING_MODERNIZATION_PLAN.md`, `docs/SHORTSTRING_BOUNDARY_AUDIT.md` |
| VCL coexistence / FMX | `docs/VCL_WIN32_COEXISTENCE.md`, `docs/FMX Migration Discussion.md` |
| **What is still here only for Delphi (survey, nothing changed)** | **`docs/DELPHI_SHIM_INVENTORY.md`** |
| Icom network protocol | `docs/ICOM_NETWORK_SPEC.md`, `docs/ICOM_NETWORK_PROTOCOL_GUIDE.md` |
| **Icom bandscope -> panadapter (read before touching `$27`)** | **`docs/ICOM_SPECTRUM_DESIGN.md`** |
| Icom scope findings for upstream (pasteable, cites no third project) | `docs/AETHERSDR_ICOM_SCOPE_REPORT.md` |
| **Multi-user networking: the protocol, and where its analysis is wrong** | **`docs/TR4W_NETWORKING_ANALYSIS.md`** — TR4QT's analysis, copied whole. **Read the provenance block at the top before believing any V1 claim**: three were checked against this tree and do not hold, and the V2 design in it is TR4QT's, not a plan for this repo |
| TCI server | `docs/TCI_SERVER_DESIGN.md` — and `docs/TCIServPlanning.txt`, its **superseded** precursor, kept for the reasoning only |
| Release process | `docs/RELEASE_WORKFLOW.md` (sections 5-8; 1-4 superseded by BUILD.md), `docs/FORK_PROCESS.md` |
| **WAE QTC windows: the bench script nobody has run** | **`docs/QTC_BENCH_HANDOFF.md`** — for N4AF. Both QTC windows converted with no harness and no operator who can judge them; three items in it are decisions, not checks |
| Hardware test plan | `tr4w/docs/D12_HARDWARE_TEST_PLAN.md` |

## Runtime Dependencies

**Required in `target/`:** `CTY.DAT` (essential), `TRMASTER.DTA` (SCP, optional but recommended),
`dom/` (~126 domestic contest configs), `commands_help_*.ini`.

**DLLs:** `libhamlib-4.dll` (+ `libgcc_s_dw2-1.dll`, `libusb-1.0.dll`, `libwinpthread-1.dll`),
`libeay32.dll` / `ssleay32.dll` (OpenSSL), `inpout32.dll` (LPT keying), `rigctld.exe`.
See [`docs/UPDATING_RUNTIME_DLLS.md`](docs/UPDATING_RUNTIME_DLLS.md).

**Created at runtime:** `settings/tr4w.ini`, `settings/tr4w.pos`, contest `.cfg`, binary `.dat` logs.

## Common Development Tasks

### Add a radio
Read [`docs/ADDING_A_RADIO.md`](docs/ADDING_A_RADIO.md). In short: one new unit in
`src/radioFactory/` inheriting the right family base, one `RegisterRadio` in its `initialization`,
capability flags set in the constructor, added to `tr4w.lpr` and the unit-test `.lpr`. **Never** add
a model check to a base class. **Never** add it to `LOGRADIO.PAS`.

### Add a contest
Read [`docs/ADDING_A_NEW_CONTEST.md`](docs/ADDING_A_NEW_CONTEST.md). New `ContestType` in `VC.pas`,
initialisation in `FCONTEST.PAS`, `.cfg` in `target/dom/`. Then verify exchange parsing, multiplier
tracking, scoring, and Cabrillo export — and run the corpus.

### Modify UI
`TMainWindowElement` in `VC.pas` → `CreateMainWindow()` in `MainUnit.pas` → display routines in
`LOGWIND.PAS` → colours in `VC.pas` (`tr4wColors`).

### Debug
`DEBUG LOG LEVEL = DEBUG` under `[COMMANDS]` in `settings/tr4w.ini`; output to `tr4w.log`.
Build with `/p:Config=Debug` (the default recipe above).

## Important Conventions

### Code style — Pascal and Python

**STATED HERE, NOT ONLY ENFORCED.** This was for a long time only in NY4I's
personal `~/.claude/CLAUDE.md`, which no contributor and no agent on another
machine can see. `.claude/hooks/pascal-lint-hook.ps1` does NOT make up for that:
it is a `PostToolUse` hook, so the edit has already happened by the time it
speaks; it is warn-only by its own header ("it never blocks the tool"); and it
inspects `.pas`/`.dpr` only. A rule that exists solely as a linter is one an
agent has to discover by being told off, after writing the wrong thing.

**Three spaces per indent level, in every language. Spaces, never tabs.**

Pascal blocks:

- **Always `begin`/`end`**, even around a single statement.
- **`begin` on its own line**, indented three from the control statement.
- **The block's code sits at the SAME level as its `begin`/`end`**, not indented
  past them.
- **No single-line `if`.**

```pascal
   if SomeCondition then
      begin
      DoSomething;
      DoSomethingElse;
      end
   else
      begin
      DoAlternative;
      end;

   for I := 0 to Count - 1 do
      begin
      ProcessItem(I);
      end;

   if (SomeCondition)      and
      (SomeOtherCondition) then
      begin
      DoSomething;
      end;
```

Wrong, and all four are common:

```pascal
   if Condition then DoSomething;        // single-line if
   if Condition then                     // no begin/end
      DoSomething;
   if Condition then begin               // begin on the same line
      DoSomething;
   end;
   if Condition then
      begin
         DoSomething;                    // code indented past begin/end
      end;
```

**COMMENT A BLOCK OF CODE OUT WITH `(* *)`, NEVER `{ }`.** A brace comment ends at
the FIRST `}` it meets, and this tree is full of things that contain one:
`{$IFDEF ...}`, the resource directive in every designed form, and ordinary
explanatory brace comments inside the very code being commented out. The comment
closes early, the remainder of the block becomes code, and the compiler reports a
syntax error somewhere that looks unrelated to what you did.

It gets worse as the cross-platform work lands (NY4I, 2026-08-31): every
`{$IFDEF WINDOWS}` / `{$IFDEF DARWIN}` pair adds another closing brace a brace
comment cannot survive. `(* *)` has no such collision — nothing in this tree
writes `*)`.

The rule applies to the EXPLANATORY comment above a commented-out block too. That
one was written as a brace comment while quoting brace characters in its own prose,
which closed it on the spot — 2026-08-31, commenting out ERMAK.

Python (`tools/`, `.claude/hooks/`) takes the same three-space indent — which is
NOT PEP 8, so an agent will default to four and nothing in this tree will catch
it. Readability over brevity everywhere: no minimising of lines, and comments on
the reasoning rather than the mechanics.

### Naming
- `u*.pas` — modern units; `Log*.pas` — core logging subsystem; `T` prefix — types/classes;
  `mwe` prefix — main window elements. Lowercase filenames in `trdos/`, MixedCase in `src/`.
- **Pascal identifier search is case-insensitive.** Always `grep -i` for Delphi symbols — TR4W spells
  the same identifier differently at declaration, assignment and use, and a case-sensitive grep has
  already produced a false "dead code" conclusion.

### File encodings and line endings
Two silent-corruption traps live here, and neither produces a compiler diagnostic.

- **`src/lang/*.pas` are UTF-8 *with a BOM*** — see [Language variants](#language-variants).
- **Source files must be CRLF.** Governed by `.gitattributes` and enforced by
  `tr4w/build/Lint-LineEndings.ps1`, which gates the build. This is not cosmetic: the RAD Studio
  form designer **inserts code by byte offset**, so against an LF file a new event handler is
  spliced into the middle of an identifier —

  ```pascal
      procedure btnCloseClick(Sende
    procedure FormCreate(Sender: TObject);r: TObject);
  ```

  Nothing is deleted; it reads like file corruption and is not. Converting to CRLF and repeating
  the same designer action inserts perfectly (2026-08-06; 148 tracked `.pas` files were LF at the
  time, `LOGSTUFF.PAS` and `VC.pas` among them). Fix with
  `powershell -File tr4w\build\Lint-LineEndings.ps1 -SourceDir tr4w -Fix`.

  **EDIT SOURCE THROUGH `tools/srcfile.py`.** The obvious Python idiom silently converts the file:
  reading with `encoding=` gives universal newlines (`\r\n` → `\n`) and writing with `newline=''`
  puts back `\n`. `srcfile.read`/`write` round-trip the file's own BOM and newline instead —
  verified byte-identical on BOM and non-BOM files. This is not hypothetical: on 2026-08-29 that
  idiom LF-ified 97 files in one command, and twice more the same day one file at a time.
  A `PostToolUse` hook on **Bash** (`.claude/hooks/check-line-endings.py`) now reports it
  immediately — the pre-existing hook is driven by `tool_input.file_path`, so it only ever saw
  `Edit`/`Write` and never the scripts that did the damage.
- **The corpus fixtures are `-text` and must stay that way.** `ref.adi` / `ref.cbr` are
  **byte-diffed**, and git was previously EOL-converting them — they were stored LF and checked out
  CRLF, surviving only because of one machine's `core.autocrlf`. A differently-configured clone
  would see corpus failures that are purely a git artifact, on the regression oracle itself.
- **`.gitattributes` alone is not enough**, which is why the lint exists: attributes govern what git
  writes on checkout and stores on commit, but nothing stops a tool from writing an LF file straight
  into the working tree, and git will not rewrite it afterwards because the content already
  normalises to the same blob. Check the endings of any file you *create*.

### Strings and buffers
- **The program passes `string`s.** Pointers, lengths, `ZeroMemory` and `s[1]` belong *inside* the
  transport where the bytes are actually written. Prefer `Foo(const s: string)` over
  `Foo(p: PAnsiChar; len: DWORD)`.
- **D12 binds generic Win32 names to the `W` variants.** A bare `@AnsiChar` buffer is an untyped
  `Pointer`, so it compiles silently *even with warnings on*. Call the `...A` variant explicitly.
  This is not theoretical: `GetPrivateProfileString` bound to `W`, wrote UTF-16 into an `AnsiChar`
  buffer, and **TR4WServer rejected every client** (`1bea7af4`). **W1057 cannot see this class of
  bug and neither can the linters** — any remaining `@buffer` passed to a *generic* Win32 name has to
  be found by reading. Related: **Winsock signatures moved in both directions** between D7 and D12 —
  `bind` went pointer → `var`, `accept` went `var` → pointer. There is no blanket rule; check each call.
- `tr4w/build/Lint-PCharAnsi.ps1` **gates the build** and understands Pascal (block-comment state,
  `{$IFDEF}` as live code, braces and `//` inside string literals). Its first run reported 5
  violations of which all 5 were false — a linter that fires on commented-out code gets ignored, so
  if you extend it, extend the fixture too.
- **Serial binary I/O must be byte-exact** — `WriteBytes`/`ReadBytes`, never `WriteString`/
  `ReadString`. A CI-V or Yaesu-binary frame corrupted by string conversion fails silently.
- `ShortString` remains in the TRDOS core; `PChar`/`PAnsiChar` at real Win32 and binary boundaries is
  fine. The done-criterion is "no `PAnsiChar(AnsiString(...))` double-casts except at genuine
  boundaries."

### Threading
Radio threads (one per radio), external logger threads (`TReadingThread` / `TSenderThread`), WinKey
thread, network threads, CW/DVP playback. The event objects (`tCW_Event`, `tCWPaddle_Event`,
`tDVP_Event`, `tNet_Event`) are created in `src/uProgramMain.pas` — plain `CreateEvent` calls now, not
the inline assembly this used to describe.

Threads hand results back through `TProcessMsgRef` callbacks — synchronize before touching UI state.
Radio disconnection is handled via the `radioWasDisconnected` flag rather than by tearing the object
down. **Open design observation (NY4I, not written up in any doc and not scheduled work):** the
`rig.CurrentStatus` / `rig.PreviousStatus` pair (`uRadioPolling.pas` ~426, ~607) does change-detection
*and* torn-read protection, and does neither cleanly — it is compared by raw byte scan over
`RadioStatusRecord`. A seqlock, or an immutable snapshot published by the driver at a coherent batch
boundary, is the likely replacement.

### Error handling
Log4D throughout. Custom exceptions: `ERadioFactoryException`
(`src/radioFactory/uRadioFactory.pas:83`), `EExternalLoggerFactoryException`
(`src/uExternalLoggerFactory.pas:32`). User-facing failures go through `ShowMessage`/`MessageBox`.
Prefer a *reported* error over a silent fallback — several defects on this branch were silent
downgrades (a string-id radio skipped in total silence, a WinKeyer that failed to open dropping to
DTR/RTS keying).

### Known compile snags
- `Undeclared identifier: 'EIdConnClosedGracefully'` / `'EIdSocketError'` → add `IdException, IdStack`
  to the uses clause.
- Missing Indy units → the vendored search path is in `build/Get-SearchPaths.ps1`. ~~`DCC_UnitSearchPath` in `tr4w.dproj`~~ is gone with the Delphi project files, not in any
  batch file.
- **Vendored Indy 10.6.3.3 is kept deliberately.** D12 ships Indy as DCUs only
  (`Studio\23.0\source\Indy` holds just the IPPeer abstraction), so swapping is plausibly a
  *downgrade* and would lose source-level debuggability of the SSL path. Decided 2026-08-04 — don't
  re-propose it.

### Conditional compilation
`tDebugMode` and the `LANG_xxx` block live in `VC.pas`. Use `{$IF cond}...{$IFEND}`.

## Critical Notes for AI Assistants

1. **Respect the TRDOS boundary — but it no longer excludes the LCL** (rescinded 2026-08-23, NY4I).
   `src/trdos/` is proven contest logic and new behaviour still belongs in `src/`; a TRDOS unit
   reaching a converted control through the LCL seam is now ordinary. See [TRDOS subsystem](#1-trdos-subsystem-srctrdos).
2. **The two factories are the exception to "no OOP here."** `src/radioFactory/` and the CW keyer
   are real inheritance with real invariants — hold them to that standard. Everywhere else, expect
   procedural Pascal.
3. **The legacy radio path is gone, not deprecated.** Don't reach for `LOGRADIO.PAS` or
   `uRadioPolling.pas` to fix radio behaviour — the per-model code was deleted 2026-08-02. Read the
   D7 tree at `C:\TR4W` as the authority on old behaviour; fix the factory. (`uCAT.pas` is the live
   config dialog, not legacy.)
4. **Global state is everywhere.** Changes to globals have wide, non-local effects.
5. **Circular `uses` dependencies are normal here** and handled by interface/implementation split.
   Be careful adding cross-unit references.
6. **`VC.pas` is the source of truth** for types, constants and enums.
7. **Validate, don't assume.** If a log, capture, corpus reference, or the D7 tree at `C:\TR4W` can
   answer the question, read it. `C:\TR4W` is the D7 source this tree was copied from — check it
   before calling anything "new in D12" or "a port regression."
8. **Prove equivalence before a "behaviour-preserving" swap; the first check often says no.**
   Replacing `IcomRadiosThatSupportRIT` with `HasCapability(rcReadRIT)` looked trivial — but no Icom
   *model* unit declares `rcReadRIT` (it is set once on the family base), so the naive substitution
   would have silently disabled RIT clear for every Icom. The swap was only made after comparing the
   two sets **in both directions** and getting 13 vs 13 with an empty difference. Likewise, "the
   legacy poller is dead" was established by a call-graph walk from the five externally-referenced
   symbols, not by inspection.
9. **A silently-defaulted field reads as a legal zero.** An undeclared capability record field, an
   uninitialised `maxLen`, a `DefineCapabilities` override that replaces its parent wholesale — none
   of these produce a compiler diagnostic. When you move data onto a type, write the **exhaustive pin
   test in the same commit**; that is what caught the TS-850 and all fourteen keying Icoms.
8. **`tools/radiosim` proves things about TR4W, not about radios.** When a driver and the simulator
   disagree, suspect the simulator first. `C:\Users\toms\projects\Hamlib` (`rigs/` backends, *not*
   `simulators/`) is a useful independent reference.
10. **Version management:** update `tr4w/src/Version.pas` for releases
   (`TR4W_CURRENTVERSION_NUMBER`, `TR4W_CURRENTVERSIONDATE`).
