# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Scope note.** This is the **single** guide for the repository — a former second copy at
> `tr4w/CLAUDE.md` was folded in here on 2026-08-04, because two files that both described the build
> and the radio architecture drifted apart. Don't reintroduce one. This file is a map; where it
> summarizes a design, the document listed under [Documentation map](#documentation-map) is
> authoritative.

## MANDATORY: Project guardrails live in the repo

`.claude/settings.json` and `.claude/hooks/` are **tracked**. They carry the hooks every clone needs:
the begin/end lint, the CRLF check, and **`block-stdin-readers.py`** (2026-10-15), which BLOCKS a
Bash command that would wait on standard input — a heredoc, or a `cat` with no file. A
background shell running `cat > /dev/null; python - <<'EOF'` waited for **1 day 0 h 21 m** and
held up the agent that owned it; a background shell has no timeout, so the only control is to
refuse the shape. NY4I: *"That should never be allowed to happen."* Write files with the Write
tool and pass scripts as files.

**`.claude/settings.local.json` is gitignored and is yours alone** — permission allow-lists, machine
paths, anything you would not ask another developer to adopt. It wins over `settings.json` where they
overlap. `CLAUDE.local.md` is ignored for the same reason: personal notes, not project instruction.

Hooks that exist on one clone only are worse than none, because they are believed
(`.claude/` was ignored wholesale until 2026-08-29, so every hook above existed on one machine).

**Hook commands must use `$CLAUDE_PROJECT_DIR`, never an absolute path.** The clones are not in the
same place — `C:\tr4w-d12` here, `C:\projects\TR4W-D12` elsewhere — and a hardcoded path is a hook
that silently does not run.

## MANDATORY: Never force-push `main`

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

## MANDATORY: IF YOU TOUCH IT, IT LEAVES NATIVE

NY4I, 2026-09-10, after a week of Win32 artifacts surfacing one at a time on
Linux:

> *"The simple rule from now on is as follows: if you touch a piece of code,
> validate if the code is doing things as a native LCL app would do it. If not,
> change it to such. Use whatever technique you need to enforce that rule. The
> way the program did it before is immaterial and any references to handles
> require immediate evaluation."*

### What this means in practice

| if you find                                              | write instead                                                             |
| -------------------------------------------------------- | ------------------------------------------------------------------------- |
| an owner-draw handler                                    | the control's own drawing, plus the LCL's colour hook (`OnPrepareCanvas`) |
| a control holding empty items, with the data in a global | the data IN the control -- `Cells` , `Items` , `Caption`                  |
| a shadow counter beside a control                        | ask the control                                                           |
| a forced `Invalidate` after a data change                | put the data in the control; it invalidates itself                        |
| `Objects[]` or a pointer carrying an identity            | a typed field the view owns                                               |
| a `Handle` , an `HWND` , or a `SendMessage`              | the property or method the LCL provides                                   |
| a procedure variable passed a `TCanvas` between units    | the event the control already raises                                      |

NY4I, 2026-09-18:

> *"I also want to ensure you know that if an issue or feature touches one of the
> sub agent areas, to involve that agent."*

**This is a routing rule, not a suggestion.** `.claude/agents/` holds sixteen
subsystem specialists, each scoped to a real seam in this tree. Before working an
issue or a feature, identify which areas it touches and involve those agents —
**plural is the normal case**, because almost nothing here lives in one subsystem.

| agent              | area                                                                  |
| ------------------ | --------------------------------------------------------------------- |
| `radio-factory`    | `src/radioFactory/` , the registry, capabilities, polling, SO2R       |
| `cw-keying`        | the keyer factory, `LogCW` , framing, prosigns, element timing        |
| `tci-interface`    | TCI protocol, `TTCIRadio` , the TCI server, WebSocket transport       |
| `serial-port-io`   | port enumeration and identity, the serial transport, `SERIAL n`       |
| `contest-factory`  | `src/contestFactory/` — the contest classes and registry              |
| `contest-scoring`  | the TRDOS engine: exchange parsing, mults, dupes, points              |
| `file-formats`     | ADIF, Cabrillo, CTY.DAT, TRMASTER, binary-log import                  |
| `log-database`     | the SQLite contest log, schema, repository, integrity                 |
| `dx-cluster`       | Telnet, spot parsing, the spot store, ageing, the band map            |
| `multi-op-network` | `tr4wserver` , the client link, the packet protocol                   |
| `integrations`     | WSJT-X, MMTTY, the external logger factory                            |
| `settings-config`  | `uSettingsModel` , the JSON stores, the command vocabulary            |
| `lcl-ui`           | `src/ui/lcl/` , `MainUnit` , display, colours, Win32-artifact removal |
| `i18n`             | resourcestrings, the `.po` catalogues, caption visibility             |
| `build-release`    | the build scripts, lints, CI runners, installer, releases             |
| `gui-test`         | `tools/gui_test`, the Windows test VM, running cases against a built exe |

**Why it pays here specifically.** Each definition carries the traps of its area
that no compiler and no lint can catch — the ones this file records at length: a
base class asking which radio model it is, `pas2po` destroying 2,203 translations
on a clean exit, a corpus reporting `24 passed` while every export crashed, a
converted window silently losing its captions. Those are the findings that cost a
day each. Routing the work to the file that holds them is how they stop being
rediscovered.

**Keep them current the same way you keep this file current.** When you learn
something durable about an area — or delete the thing an agent describes — fix
that agent's file **in the same commit**. The rule against stale counts and
survivor lists applies to them in full: an agent definition that describes a road
removed last month is worse than none, for exactly the reason a stale CLAUDE.md
is.

## MANDATORY: Development Philosophy

## Overview

TR4W is a free amateur radio contest logging application, written in Object Pascal (FreePascal +
the Lazarus LCL). **Unit and line counts are not stated here on purpose**: they drift, and a
stale count is believed. Measure.

**Repository:** `TR4W/TR4W-D12`, and **`d12` is the only remote** (there is no `origin`). The D7
*tree* on disk at `C:\TR4W` is still the authority on old behaviour -- see note 7 below.

**Branch:** **`main`**. `d12/master` is `457bc14d` (2026-07-03) and is `main`'s own ancestor, simply
stale; it is not D7 heritage and pushing to it would not reach another project.

**Toolchain:** **FreePascal 3.2.2 + the Lazarus LCL.** Delphi was left behind on 2026-08-13 and
every Delphi file was deleted 2026-08-31;
a Delphi build can only be reproduced by checking out a commit before 2026-08-17.

**Version:** `tr4w/src/Version.pas` (`TR4W_CURRENTVERSION_NUMBER`) is the single source of truth --
`FullBuild.ps1` derives the installer version from it and then checks the linked binary reports it.
**No version number is written here**: this file once said `5.0.2` for four weeks while the tree
moved twenty-one releases on. Releases are published to the **GitHub release page**;
`gh release list` is the answer to "what is out there".
**Website:** https://tr4w.net — **serves D7 (4.x) ONLY.** 5.x is not distributed there yet, so
"published" above means the GitHub release page and nothing more. An operator who downloads TR4W
from the website today gets 4.x, and that is deliberate until the bench block below closes.

## Build System

`tr4w/FullBuild.ps1` is the **single packaging path** (`-SkipServer` leaves `tr4wserver` out of the
build, so do not ship one; `-BuildInstaller` adds the NSIS installer): lints, then unit tests, then
the app -- in that order, so a failing test stops the build *before* it produces a binary anyone
could ship. It derives the version from `src/Version.pas` and **fails** (rather than defaulting to
0.0.0) if it cannot parse it, then checks the linked `tr4w.exe` actually reports that version.
`full.nsi` refuses to build without `/DTR4WVERSION`.

### Iterating

`.\build\Build-App.ps1` (full rebuild, the safe default; `-Incremental` for seconds instead of
minutes), `.\build\Build-Tests.ps1 -Run`, `.\build\Build-Server.ps1`.

- **`-Incremental` for chasing one defect; a full build before believing any result.** FPC's mtime
  rule cannot see a changed compiler switch, `.inc`, or define flip. A designed form is *two* files
  and FPC only watches the `.pas`, so the script touches a `.pas` whose `.lfm` is newer.
- Intermediate output goes to `build-out/` at the repo root (gitignored): a plain
  `Build-App.ps1` writes `build-out\app-x86_64-win64\tr4w_fpc.exe`. `FullBuild.ps1` puts the
  binaries where they ship: `target/tr4w.exe` and `tr4wserver/tr4wserver.exe`. **The corpus, the
  ADIF round trip and the contest matrix take their exe path from ONE file,
  `tr4w/test/app-exe.sh`**; the GUI suite's default is `tools/gui_test/stage_main_build.DEFAULT_EXE`.
- **The unit-test exe must live in `tr4w/test/unit/`** — several suites resolve their data from
  `ParamStr(0)`, not the working directory.

**No hardcoded toolchain.** `build/Find-Toolchain.ps1` discovers FPC and Lazarus (honouring
`FPC_HOME` / `LAZARUS_DIR`); `fpc.exe` is only a driver, the backend is `ppc386`/`ppcross386`.

**The unit search paths are defined once**, in `build/Get-SearchPaths.ps1`, for three targets that
genuinely differ (App / Tests / Server). The server gets the LCL paths too, because `uServerForm`
lives there.


**SO THERE IS NO GUARD ON THE CONSOLE/LCL BOUNDARY, AND NOTHING REPLACED IT** (stated plainly
2026-09-28). The `Forms`-in-a-console-program story under
[Multi-user networking](#6-multi-user-networking) is still worth reading for how the boundary
broke — but the search path that caught it is gone, so **a unit that quietly grows a `Forms`
dependency is now caught by nothing at all.** That is a real gap, not a thing to route around:
do not invent a substitute guard in passing, and do not repeat the retracted claim that
`-SkipServer` skips one.

### Building off Windows

**THREE PLATFORMS BUILD FROM THIS TREE**, as of 2026-09-08 — Windows, Linux x86_64 and macOS
aarch64. **Windows is x86_64-win64 ONLY, and 32-bit Windows is not supported and never will be**
(issue 299; NY4I, 2026-11-12: *"I have no plans to ever support 32 bit Windows OS"*): the build
scripts take no `-Cpu`/`-Os`, there is no i386 build, and `tr4w\target` holds the 64-bit DLL set.
The 32-bit build existed as a safety net behind `-Cpu i386` from the 2026-11-12 flip until that
ruling, then was deleted. The 64-bit installer refuses a 32-bit Windows with a message sending
those users to TR4W 4.x (tr4w.net); it still migrates a 32-bit 5.0.x install on a 64-bit Windows.
The target is named once, in `build\Get-StagingDir.ps1`. Anything in this file or in `docs/` that says the port "has not been attempted", or that a
Linux compile is blocked on `VC.pas`, is stale: `VC.pas` uses `LCLType`, not `Windows`.

**TO VERIFY A PLATFORM, RUN THE WORKFLOW. DO NOT SSH IN AND BUILD BY HAND.**

```powershell
gh workflow run release.yml          # all three platforms, in parallel, NO release created
```

The commands below are what that workflow runs. Reach for them when you are already ON one of those
machines and diagnosing something — not as the way to answer "does this build on Linux". See
[Lints gate the build](#lints-gate-the-build--from-one-place) for why, and for how to watch the run.

```sh
sh tr4w/build/build-unix.sh            # every stage; build-linux.sh / build-mac.sh wrap it
sh tr4w/build/build-unix.sh --list     # what the stages are, and stop
./tools/compile-native.sh --tree       # just the compile, in seconds
```

```powershell
.\tools\Compile-Linux.ps1 <unit>.pas   # cross-compile ONE unit from Windows
```

- **One implementation, two wrappers.** `build-unix.sh` is the Unix counterpart of `FullBuild.ps1`;
  `build-linux.sh` and `build-mac.sh` are one-line `exec`s into it. The platforms differ in four
  places — target name, widget set, where Lazarus lives, and what a distributable artifact IS
  (a tarball, versus a `TR4W.app` bundle). **Do not add behaviour to a wrapper.**
- **Linux produces the app, `tr4wserver` and a tarball. macOS produces the app, the server and an
  `.app` bundle** — the bundle is not decoration: Cocoa decides an app is an app by finding an
  `Info.plist`, and a bare Mach-O launched from Finder gets no Dock icon and no menu bar. It is
  **signed and notarized since 5.0.13** (2026-09-20) — `tr4wserver`, the app binary and the
  bundle are signed inside-out with the hardened runtime, the bundle and the `.dmg` are each
  notarized and stapled, and NY4I confirmed a downloaded `.dmg` opens with no Gatekeeper
  warning. Do not tell an operator to strip quarantine (`xattr -dr com.apple.quarantine`) from a
  notarized build.
- **LINUX IS RUN, AS OF 2026-09-20.** NY4I ran the
  **AppImage on Linux Mint 22.3** — a machine that did not build it — reached the UI, and
  **connected to an Elecraft K4 over Ethernet**. That is the first functional proof off
  Windows: the gtk2 UI works from the bundle, and a network radio links. **macOS remains
  unrun.** Building is still not running, and this is not a contest: **CW element timing off
  Windows is a plain `Sleep` placeholder and will not key** (see
  `docs/PLATFORM_CLOCK_ABSTRACTION.md` part 2), serial ports are not selectable there yet
  (`docs/PORT_IDENTITY_PLAN.md` step 5), and no QSO has been logged. `README.md`'s *"Where
  this actually stands"* is the honest status; keep it there rather than duplicating it here.
- **`build-unix.sh` does NOT stop at the first failing stage**, unlike `FullBuild.ps1` — every stage
  reports its own first error so the summary is a ranked worklist. Its own header still describes an
  era when nothing linked; read the README, not the header.
- **The lints and the Edit-QSO round-trip are PowerShell and do not run there.** They are reported
  as not-run, never as passed.

### Lints gate the build — from one place

`tr4w/build/Run-Lints.ps1` runs them all -- read the array in that script for the current set, and
add a lint by editing that one array.

**A WINDOWS GATE IS A GUESS UNTIL A COMPILER DISAGREES**, and the compiler that
settles it is a NATIVE one. **RUN THE WORKFLOW -- DO NOT SSH IN TO BUILD.**

```powershell
gh workflow run release.yml          # all three platforms, no release created
gh run list --workflow release.yml --limit 1
gh run watch <run-id>
```

NY4I, 2026-09-28: *"audit any info about building and ensure all agents are aware of ci GH
process."* The workflow reaches the machines in parallel, in the environment a release actually
uses; a hand-build over ssh is slower and proves less.

**A `workflow_dispatch` run DELIBERATELY CREATES NO RELEASE** -- the release
job's `if:` requires `github.event_name == 'push'`, and `release.yml` says so in
terms. So dispatching it has no side effect; there is nothing to clean up and
nothing to un-publish.

**NEVER pre-flight a native build immediately before tagging.** The tag does
exactly that, on the same runners. Twenty minutes were wasted that way on
2026-09-28, minutes before the tag.

**ssh to `linux-ci-build` / `mac-ci` IS STILL RIGHT FOR DIAGNOSIS** -- reading a
log, probing hardware, an interactive or destructive experiment, anything that
needs a machine rather than a build. That is not the routine check, and the
distinction is sharp: the Icom band work and the keychain investigation both
required a real session and neither was a build.

**AND NOTHING BUILDS ON AN ORDINARY PUSH TO `main`.** `release.yml` triggers on a
`v[0-9]*.*.*` tag and on `workflow_dispatch`, nothing else; `version-guard.yml`
runs on every push and PR and **builds nothing** -- its one job parses
`Version.pas`. So a dispatch is not a convenience over CI, it IS the CI build for
work that is not being tagged.

`Lint-LFMProperties` is the odd one out: it compiles a small FPC helper (`build/lintlfm/`) that links
the LCL and asks the same RTTI the streaming loader uses, because "does this class publish this
property, and is this a legal value" cannot be answered by grepping a `published` block. It fails
closed if FPC or the LCL is missing.

**What was deliberately NOT deleted, because the names invite it:**

| kept                                                       | why                                                                                                       |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| the ~200 `.dpk` /`.dproj`/`.bdsproj` under `tr4w/include/` | the **vendored Indy 10.6.3.3** tree, kept on purpose                                                      |
| the ~90 `.obj` files under `tr4w/include/`                 | **linked by the build**: `{$LINK pcre\pcre_compile.obj}` in `pcre.pas` . Deleting them breaks compilation |
| `tr4w/test/corpus/export-d12-corpus.sh`                    | the **live golden-corpus oracle**. "d12" is its name, not its toolchain                                   |
| `tr4w/tr4w.res`                                            | linked by `{$R *.res}` ; Lazarus writes it from the `.lpi`                                                |
| `docs/D12_*.md` , `tr4w/docs/D12_*.md`                     | historical reasoning, still linked from the [Documentation map](#documentation-map)                       |

### Lazarus

Open **`tr4w/tr4w.lpi`** with `C:\Lazarus`, not the fpcupdeluxe shortcut (it was refused while the
app was 32-bit; whether it pairs with the x86_64-win64 target has not been checked). The project
targets x86_64-win64 and finds its compiler and RTL units through the `$(LazarusDir)` macro; that
wiring is **unverified in the IDE** (the build scripts, not Lazarus, are what is gated).

### Language variants — being replaced, don't extend

`FullBuild.ps1` builds **ENG only** (`-dLANG_ENG -dVERSIONINFO_RES`). The compile-time mechanism
(`{$IFDEF LANG_RUS}` in `VC.pas`, `src/lang/tr4w_consts_<LANG>.pas`, `res/tr4w_<lang>.res`) is still
in the source, but nothing builds those variants. The replacement is `resourcestring` + `.po`
catalogues + one binary per platform; resource DLLs are out (no macOS/Linux equivalent).

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

Run with `.\tr4w\build\Build-Tests.ps1 -Run`. `FullBuild.ps1` runs them too, **before** it builds
the app. The exe must land in `tr4w/test/unit/` (several suites resolve data from `ParamStr(0)`).
They build for x86_64 and **stage the DLLs beside the
exe themselves** (from `redist\`, failing closed on a missing or non-64-bit one); a hand-swapped
`sqlite3.dll` is no longer needed or wanted.

**`System.Val` IS NOT RANGE-CHECKED ON WIN64.** `Val('99999999999', longintVar, code)` gives
`Code = 0` and a truncated value there and `Code = 10` on i386 (FPC's `ValSInt` is Int64 on Win64);
Byte/Word/SmallInt/ShortInt were never checked on either. **Every text-to-number conversion with a
code goes through `utils_text.ValChecked`**, and `Lint-BareVal` fails the build on a bare `Val(`.
The RTL's `StrToInt`/`StrToIntDef`/`TryStrToInt` have the SAME hole on Win64 and are not wrapped
yet -- see `docs/64_BIT_TASKLIST.md` before trusting one with untrusted digits.

The test `.lpr` uses `MainUnit`, and the contest pins link `FCONTEST`, `LOGSTUFF`, `PostUnit` and
`LogEdit`: every contest's parse dispatch, export columns, field list and exchange rules are pinned
per contest and station. What is NOT unit-covered is the engine run end to end --
`ProcessExchange`, scoring and dupe over a booted session -- which is the contest matrix's and the
corpus's job.

**1b. Checked unit tests: `-gt` + heaptrc** (2026-10-14). The same suite, compiled so undefined
behaviour is wrong *every* run instead of right by luck:

```powershell
.\tr4w\build\Build-Tests.ps1 -Checked -Run    # ~2 min; -Lines adds source lines, to DIAGNOSE only
```

`-gt` fills every local with garbage on entry (an unassigned managed function result is NOT `''`
in FPC); `-gh` reports overwritten, double-freed and wrong-size blocks at exit. It fails on a
non-zero exit, on **any** heaptrc corruption line, on a missing heaptrc summary, and on unfreed
blocks above `$LEAK_CEILING` in the script, which **ratchets down only**. `FullBuild.ps1` runs it
after the normal suite. It exists because an intermittent `0xC0000005` in the unit tests was a
`FillChar(x, SizeOf(x))` on an old-style object with virtuals — `SizeOf` of an instance goes
through the VMT, so **always write `SizeOf(TYPE)`** — and a plain run only crashed sometimes.

**2. Golden-master corpus** — the regression oracle for the contest engine.
`bash tr4w/test/corpus/export-d12-corpus.sh` runs the app's headless export mode
(`tr4w.exe "<contest>.db" /EXPORT`, `src/uProgramMain.pas`) over 13 real contest logs and
byte-diffs both artifacts — ADIF and Cabrillo — against frozen D7 references (13 sets × 2 = 26
comparisons).

- **WHAT IT ASSERTS: A GIVEN LOG PRODUCES THE EXPECTED ADIF AND CABRILLO.** The tracked fixture is
  a `log.db` — a TR4W SQLite contest log, which is what a contest IS in this program. The
  references stay **D7-produced and are NEVER regenerated**; that is the independent half of the
  oracle, and regenerating one would make it a tautology.

- **THE D7 INPUT FORMATS WERE DROPPED BY DECISION ON 2026-09-24, NOT BY DISCOVERY.** Every set used
  to track a `log.trw` that the run imported. NY4I: *"I don't dispute its value to validating our
  processing today is functionally the same as D7. My point was we are so far past validating that
  fact, that we do not need that step anymore. Instead, the corpus can adopt the testing
  methodology of comparing a given `.db` file produces an expected ADIF and Cabrillo file."* This
  file argued the opposite until that day (*"that independence is the whole value of the oracle"*),
  so the next reader will otherwise re-derive the old argument and try to put the `.trw` files back.
  **Don't.**

- **BINARY-LOG IMPORT IS COVERED BY A UNIT TEST NOW, AND ONLY THERE.** NY4I, same day: *"Yes I
  agree it's remnant allow us to validate .Trw conversion but that becomes a unit test and not the
corpus."* `uTestLogBinaryFile`, `uTestLogImport` and `uTestLogRepository` read the D7 logs in
  `tr4w/test/unit/fixtures/binarylog/`, each of which carries an assertion no other log can.

- **GREEN = `0 failed` and every known-divergence is a recorded pin** (`known-divergences.txt`,
  or a per-artifact `<set>/known.<kind>.diff` that excuses EXACTLY its lines -- a stale pin
  fails), **and every export run exits 0.** The pass counts move with each ruling: take the
  current line from the newest commit message.
- **THE EXIT CODE IS PART OF THE RESULT, since 2026-09-06.** The corpus used to discard it, and
  for at least two days all THIRTEEN `/EXPORT` runs were dying with an `EAccessViolation` while it
  reported `24 passed, 0 failed` — the artifacts are written before the exit, so the byte
  comparison could not see it. A non-zero exit now fails the run and names the code (`217` is
  FPC's unhandled exception; `3221225477` is an access violation).
- **Rebuild the app first**, and **guard that TR4W is not running** (`Get-Process -Name tr4w`) — a
  running instance collides on `target/` and every set reports a false FAIL.
- Run the corpus, **read the result, then commit**. Never chain the corpus run and `git commit` in
  one shell block.

**2b. ADIF validator** (2026-10-23) — `tr4w/test/adif-validate/validate-adif-outputs.sh` runs
K1MU's independent ADIF validator (`tools/adifvalidator/`, **vendored** -- see its `VENDORED.md` for
origin, commit and the local patches) over the ADIF the corpus, the ADIF round trip and the contest
matrix write, and each of those three scripts calls it as its last step. A byte-diff against a frozen
reference proves "same as before"; it cannot prove "valid ADIF" -- the D7 refs themselves carry
`<MODE:4>DATA`, which the standard does not have. **Any `Compliance error` fails the run;
`Consistency error` findings (zones, state-versus-DXCC) are counted and reported, never a verdict.**
A finding is excused only by an exact line in `tr4w/test/adif-validate/known-findings-<source>.txt`
(synthetic matrix input only), and a pin that matches nothing fails -- the corpus's `known.*.diff` rule.
It fails closed: no python, no validator, zero files, or a validator crash each exit 1. It is
vendored because the gate must run on a clean clone with no network; it is Python with tabs, so
leave its indentation alone and record any patch in `VENDORED.md`. `uTestADIF` also pins every tag
TR4W writes against ADIF 3.1.6's field list (`ADIF_SPEC_VERSION` in `uADIF`).

**3. Integration / bench** -- `tr4w/test/integration/` drives real serial radios (or
`tools/radiosim`) via `run-bench.ps1`. `tr4w/test/bench/` holds the **measuring instruments**
(`bench_*.lpr`, built by `tr4w/build/Build-Bench.ps1`): programs that ask a real radio a question
and print what it says. **`FullBuild.ps1` BUILDS them all after the unit tests** (build only, never
run; `bench_callsign` failed to link for weeks before that because nothing compiled it);
`build-unix.sh` has no bench stage. `tr4w/test/logdump/` and
`tr4w/test/python/verify_adif_export.py` cross-check ADIF export against the canonical
`ContestExchange`.

**Lint scripts** in `tr4w/build/`. `Lint-PCharAnsi.ps1`, `Lint-RadioRegistry.ps1` and
`Lint-PollRadioState.ps1` are in `Run-Lints.ps1` and GATE THE BUILD. `Lint-PascalBeginEnd.ps1` and
`Lint-ChangedPascal.ps1` are NOT — the first runs as the `PostToolUse` hook
`.claude/hooks/pascal-lint-hook.ps1`, which warns after the edit and never blocks; the second is
run by hand. The style itself is written down under
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
   existing globals first, prove the seam on hardware, then delete the legacy path.
4. **The contest factory** -- `tr4w/src/contestFactory/`, built to the same model
   (`uContestBase`, `uContestRegistry`, `uContestFactory`, one unit per contest). Read
   [`docs/ADDING_A_CONTEST.md`](docs/ADDING_A_CONTEST.md) before adding to it.
5. **The contest log is SQLite** — `src/domain/uLogDatabase.pas`, `uLogSchema.pas`,
   `src/uLogRepository.pas`, `src/uLogSource.pas` (**no source selection: it reads the
   database, and since 2026-09-24 there is no other option to read**). The binary `.TRW` is
   **import-only**: `tAddQSOToLog` writes to the database and nowhere else. See
   [`docs/SQLITE_MIGRATION_TASKS.md`](docs/SQLITE_MIGRATION_TASKS.md).

### Framework

**THE UI IS LCL FORMS, and every tool window is a designed form.** The program runs
`Application.Run`; the hand-rolled message loop is gone. VCL is an abandoned path (the coexistence
technique is in
[`docs/migration_interim_artifacts/VCL_WIN32_COEXISTENCE.md`](docs/migration_interim_artifacts/VCL_WIN32_COEXISTENCE.md)).
State is held in **global variables** and Pascal **records**, with manual resource management.

### Key entry points

**`tr4w/src/uProgramMain.pas`** — the startup sequence: single-instance mutex, logger, optional
WSJT-X and external-logger servers, `CreateMainWindow`, WinKeyer thread, then `Application.Run`.
Grep for the step you need; the order above is what matters, not the offsets.

**Startup lives in a unit, not the program file**: a program file is invisible to a search of
`src/`. The `.lpr` is the uses clause, the resource directives, and `begin RunTR4W; end.` -- and
**nothing else**.

**The uses clause stays in the `.lpr`**, so "which units are compiled" and "who references this"
are still `.lpr` questions. `uProgramMain`'s own uses clause is a copy of it in the same order:
this program relies on use-order for name resolution (`SysUtils.SysErrorMessage` vs `TF`'s), so do
not tidy it as a side effect of something else.

Two facts about that sequence that grep will not tell you: **headless `/EXPORT` mode boots the
contest, writes the files and `Halt(0)`s before any GUI or network init**, and config load
(INI → CFG → common messages) plus CTY.DAT load happen before the main window.

**`tr4w/src/MainUnit.pas`** — main window creation, keyboard/mouse input, display coordination, and
the process-wide globals `wsjtx: TWSJTXServer`, `externalLogger: TExternalLogger` and
`logger: TLogLogger`, declared together in its `var` block (grep the names; the line numbers
written here drifted by 110 between August and 2026-09-28). **Any standalone EXE that links app
units must assign `logger`** or it will AV on the first log call.

## Core Subsystems


### Type system (`src/VC.pas`, `src/TF.pas`)

**`VC.pas` is the source of truth** for types: 120+ `ContestType` values, band and mode enums, the
~60-element `TMainWindowElement`, colour schemes, and the compile-time switches — `tDebugMode`, and
the `LANG_xxx` block, which you find by grepping `_LANG_SET`.

**`TF.pas`** holds UI helpers, dialog utilities, and format/conversion functions. Note: TF's
hand-rolled `IntToStr`/`StrToInt`-style shims are legacy weight — prefer the RTL and delete the shim
when you touch a call site (`TF.StrToInt` is lenient and silently returns 0; the faithful replacement
is `StrToIntDef(s, 0)`).

### Configuration (`src/uCFG.pas`, `src/trdos/CFGCMD.pas`)

Settings live in `settings/tr4w.json`, owned by `uSettingsModel` (below). `settings/tr4w.ini` is
**not a startup source since 2026-09-19** -- it is `tr4wconvert`'s input. NY4I: *"We switched to
all json a while ago. Except for the contest.cfg file we should not be writing ini files."*


### Where a setting actually lives

The **stores** -- radios, keyers, profiles, window layout, UDP -- are all JSON
in `settings/tr4w.json` and have been since August. **`tr4w.ini` STORES
NOTHING**; the file on NY4I's station is 67 bytes of sentinel text. It and the
contest `.cfg` are **read-once-and-convert import formats** (NY4I, 2026-09-11):
read once, converted, never consulted again. The `.cfg`'s contest parameters go
to the **contest SQLite database**, not to JSON.

**AND STARTUP NO LONGER READS `tr4w.ini` AT ALL (2026-09-19).** NY4I: *"calling
`ReadInConfigFile(cfgINI)` that does nothing is pointless and should be removed."*
The call is gone, `cfgINI` is no longer a member of `TCFGType`, and the ini is the
**converter's input**: `tr4w/tools/tr4wconvert --ini <path>`. One information line in
the log still names the file present or absent (`ReportConfigurationSources`), and
that is all -- **there is deliberately no in-program detector telling an operator to
convert.** One was written and withdrawn the same day (NY4I: *"it frankly kept
getting in the way and causing confusion"*); that message belongs to **SETUP**, and
the installer line is separate work.

### THE DESTINATION IS `uSettingsModel`, AND IT IS NOT A REGISTRY EITHER

`src/uSettingsModel.pas` holds `TPersistent` classes with **published
properties**, streamed by `fpjsonrtti`. NY4I's standing question -- *what would
we do if we were doing this from scratch in an FPC app* -- has one answer here,
and it is neither a table of pointers nor a registry of closures:

```pascal
published property Port: integer read FPort write FPort;
```



**`CheckCommand` RESOLVES NAMES THE SETTINGS OBJECT OWNS, AND THAT IS THE ONLY
WAY A SETTING IS RESOLVED.** It used to be one of two, and that was the whole
shape of the migration: a migrated name and an unmigrated one were disjoint
sets, each resolving in exactly one place. There is one place now. What remains
beside it in `CheckCommand` is the pattern families (`COLUMN WIDTH <name>`, the
window colours), `TryApplyCommandAction` for the four commands that DO something
rather than set something, and two lists that accept-and-ignore -- a withdrawn
name (`RETIRED_COMMANDS`) and a name a store owns (`OWNED_BY_A_STORE`).

**`RegisterLegacySetting` is gone with the last row.** Preferences goes through
`uSettingsModelBinding`. `uSettingsLegacy` still exists and is **not legacy**: `TStoredSetting`
writes `settings/tr4w.json` through the radio configuration store, which is where the radio,
keyer, cluster and profile libraries live.

**`Lint-ConfigArrays.ps1` IS INVERTED, NOT RETIRED.** Every ceiling is 0 and
zero is the pass; **any** occurrence fails, anywhere in the tree. The shape it
forbids is a const table holding the ADDRESS of a global so something can write
through it.

A setting is a published property: its bounds are its type, its side effect is its setter, and
whether it is read-only is stated at registration. The reasoning behind the move, and where each of
the row's twenty fields went, is in
[`docs/migration_interim_artifacts/CFG_ARRAY_ELIMINATION.md`](docs/migration_interim_artifacts/CFG_ARRAY_ELIMINATION.md);
the per-unit ini-to-JSON detail is in
[`docs/migration_interim_artifacts/CFG_MIGRATION_PLAN.md`](docs/migration_interim_artifacts/CFG_MIGRATION_PLAN.md).
Both are archived.

### 4. Contest flow

1. Callsign typed → `CallWindowChange`
2. Super Check Partial → `logscp.pas` (TRMASTER.DTA)
3. Dupe check → `logdupe.pas`
4. Country/multiplier → `uctydat.pas` (CTY.DAT), `uMults.pas`
5. Exchange parsing → `logstuff.pas` `ProcessExchange()` → the contest's
   `ParseReceivedExchange` (M5b; design doc §8.2g)
6. Validation → `ContestExchange` record
7. Network broadcast → `uNet.pas`
8. Display update → `logwind.pas`

### 5. Radio control — the factory

**All radios go through the factory.** `src/radioFactory/` holds one unit per family base and one per
model. Registrations are `RegisterRadio` (enum-keyed), covering every selectable
`InterfacedRadioType` except `NoInterfacedRadio`, plus `RegisterRadioById` for a **string-id**
radio that has no enum member (there is more than one; do not write the number). Ask instead:

```bash
grep -rn "RegisterRadioById(" tr4w/src/radioFactory/*.pas    # the call sites, not the declaration
```

A string-id radio is the case that silently breaks model-keyed code — see the CW-by-CAT repoint
below, where the old model-keyed capability gate could not see TCI at all.

**The count is not written here**; `.\build\Run-Lints.ps1` prints the true one on every build.

- **Base class:** `src/radioFactory/uFactoryRadioBase.pas` (`TFactoryRadioBase`).
- **Registry:** `uRadioRegistry.pas` is the single source of truth; each unit self-registers from its
  `initialization` section. It owns the per-model data that used to live in parallel arrays — CI-V
  address, HamLib `rig_model`, startup command, network metadata.
- **Capabilities are owned by the radio object** — a `TRadioCapabilities` set plus a
  `DefineCapabilities` virtual (an Icom-family virtual; **every other** driver sets
  `FCapabilities.Flags` in its constructor). Not a global table.

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

**Legacy radio code: DELETED, not deprecated** (Track E, 2026-08-02, `1c820091`). The
`case rig^.RadioModel of` dispatch and every per-model poller in `uRadioPolling.pas`, and every
model dispatch and Icom quirk typeset in `logradio.pas`, are gone -- reachability was *computed* by
a call-graph walk, not assumed. **LOGRADIO now holds no per-model radio knowledge.**

Both enum-indexed radio tables, `RadioParametersArray` and `InterfacedRadioTypeSA`, were deleted
2026-08-28. "Unreferenced" was true of the running program and missed the point: they were
`array[InterfacedRadioType]`, so the *compiler* demanded a row for every radio anyone added, and the
unit tests then compared the new radio against a row someone had just invented for it. That is a
second definition of what a radio is, and it had already drifted -- the name table was missing
`TS140` and carried a `TS530` the enum never had, so **a config saying `TS440` selected the TS-140
driver** and `TS140` could not be selected at all. Four Kenwoods, silently, for years.

The factory owns per-model data now; `uRadioRegistry.RadioTypeToken` derives the config-file
spelling from the enum itself, so that drift is unrepresentable rather than merely fixed.
**`Lint-NoRadioTables` fails the build if a hand-typed table indexed by a radio enum comes back.**
- The `is TIcomRadio` / `is TKenwoodLAN` credential casts became virtuals on `TFactoryRadioBase`
  (`ApplyNetworkCredentials`, `ApplyDataModeID` — named for the *concept*, not the vendor).

Read the D7 tree as the authority on what the old program did — never mirror a fix back into it.

**`src/uCAT.pas`** is not a dialog (`CATDlgProc` has no caller). It is the machinery the Preferences
form uses: port enumeration, the filtered/greyed COM drop-down (item data, never index arithmetic),
string-id factory radios in the type combo, and `CloseCATAndKeyerForThisRadio`. Do not delete the
unit, and do not change radio configuration in `CATDlgProc`.

**There is no `RestartPollingThread`** (checked 2026-09-24; no such identifier, or
`RestartPolling`/`StartPollingThread`, anywhere in `tr4w/src`).
**The polling thread is not restarted; the RADIO IS REBUILT, and the thread comes with it.**
`RadioObject.CheckAndInitializePorts_ForThisRadio` (`src/trdos/logradio.pas`) calls
`SetUpRadioInterface`, which calls `ShutDownRadioInterface` first — stop the poller, wait for it,
free the factory object — then constructs a new radio and starts a new thread. Its two drivers are
`uRadioConfigApply.ApplyProfile` and `MainUnit.ResetRadioPorts`. `uCAT` contributes the teardown
half, `CloseCATAndKeyerForThisRadio`.

That matters beyond the name: **there is no way to hand new settings to a live radio**, so every
configuration change is a teardown and rebuild, and anything that does not go through one leaves the
running radio holding what it was given at startup. See the stale-credential defect recorded under
[Radio control](#5-radio-control--the-factory).

**A SAVED SETTING THAT NEVER REACHES THE RADIO IS THE DEFECT TO WATCH FOR HERE.** The only route
from the radio library into the running program is `uRadioConfigApply.ApplyRadioToSlot`, and until
2026-09-24 it ran at startup and from the **Activate** button only. Saving an edit therefore changed
the library and nothing else: NY4I corrected an IC-9700's LAN password, saved, and every
reconnection for the rest of the session sent the blank one — while `ApplyNetworkCredentials`
faithfully logged `network credentials set` a second before each attempt, and Reset Radio Ports did
the same. Restarting TR4W fixed it, which is what had made it look intermittent for months. Saving
now re-applies the profile when a radio in an **active slot** has changed
(`ActiveRadioSettingsChanged`, pinned by `TAppliedRadioSnapshot` tests), and the credential log lines
report the password's **length** so a stale or blank value names itself.

**SO2R:** `src/uRadio12.pas` manages Radio 1 / Radio 2, automatic switching on focus, independent VFO
control.

**Threading:** each radio instance runs its own reading thread with exponential-backoff reconnection
(1s → 30s). An open COM port is *not* a working link — serial radios need a real close/reopen
(`MaintainSerialLink`, on the radio, not in the poller). And a radio can answer CAT before it is
ready: gate post-connect sends on link *stability*, not presence.

### 6. Multi-user networking

**TR4WServer** (`tr4w/tr4wserver/`, its own `.lpr`) is the TCP/IP server for multi-op stations:
centralised log, multipliers, dupe checking, serial-number lockout. (Time sync -- one station setting the others' clocks -- was REMOVED 2026-11-03: a permissions question. Its message id 1070 is still framed and skipped for older stations.) Binary packet
protocol with CRC32 (`src/utils/networkmessageutils.pas`). Client side: `src/uNetClient.pas`,
`src/uNet.pas`, `src/trdos/lognet.pas`, `src/uGetServerLog.pas`.

**The design and its traps live in `.claude/agents/multi-op-network.md` -- involve that agent and
read it before touching any of this.** The rules worth knowing from here:

- **There is no log comparison.** A station catches up from the server's log (insert-only, by
  `(ceQSOID1, ceQSOID2)`, after a backup) and pushes the QSOs the server lacks (`NET_OFFLINEQSO_ID`,
  stored but not relayed). Offline work resends from SQLite rows (`sent_to_server`,
  `server_dirty`). Detail: `uNetCatchUp.pas`, `uNet.ResendOfflineWork`, `tools/netprobe`.
- **The link belongs to the program, not the Network window** (`uNet`, `uNetLink`; Net menu
  Connect/Disconnect/Reconnect; `NETWORK AUTO CONNECT`). The window is only a view.
- **The link is Indy** (`TNetClient`), not Winsock. **Writes never run on the caller's thread**
  (`uNetSendQueue`: one FIFO writer thread). Parsing runs on the main thread via
  `Application.QueueAsyncCall`; an unrecognised message id must NOT be kept in the buffer, or the
  same bytes re-parse forever and the link wedges silently.
- **`tr4wserver` is an LCL program, not a console program** (since 2026-09-06). Nothing guards a
  unit growing a `Forms` dependency -- see Build System.

#### Crash reporting (`uCrashLog`)

- **`uCrashLog` is split by widget set.** It keeps the RTL reporter (`LogCaughtException`,
  `EarlyTrace`, `OnMainThread`, the `ExceptProc` hook) and links anywhere; the statements needing
  a widget set (`Application.OnException`, `ShowException`) are `src/ui/lcl/uCrashLogLCL.pas`.
  **A program with an LCL -- the app AND `tr4wserver` -- calls `InstallCrashLogLCL`, not
  `InstallCrashLog`**, because the LCL never lets a fault in its own event handlers reach
  `ExceptProc`. An `{$IFDEF FPC}` cannot make this split: it asks which *compiler*, not which
  *program* has a widget set. Only the unit graph can.
- **`RegisterCrashContext`** lets a subsystem add to a crash record (the DX cluster's last 200
  lines) without `uCrashLog` naming it.
- **A report names its build.** Windows has NO CodeView `RSDS` record (the PE debug directory is
  empty because FPC emits DWARF/stabs); the linker writes a **`.gnu_debuglink`** section: the
  `.dbg` name plus a **CRC32** of its contents. `ReportSymbolState` logs it at startup; use it to
  pick the right `tr4w-<version>.dbg` before sending one to an operator. It is read from the file
  with `TFileStream` because a long section name's string table lies in no mapped section.
- `InstallCrashLog` sets its own log subtree's level, so a crash report is not silenced by
  `DEBUG LOG LEVEL`. A server crash goes to `tr4wserver.log` (the root logger's appender).
- **Placement in `tr4wserver`: in the program body, after the single-instance lock and before
  `Application.Initialize`** -- after the lock so a second instance does not open the shared log,
  before `Initialize` because `ServerStartUp` has already exited twice with no window and no log.
- **`Lint-CrashLogInstalled` gates it** (a live install call per shipping program; fails closed on
  a missing `.lpr`, a missing `uCrashLog.pas` or an unclassified `.lpr`). **The unit-test binary
  must install it too:** `InstallCrashLog` records the main thread id, so without it
  `OnMainThread` is false everywhere and `SetElementText` / `SetStatusText` silently do nothing.

### 7. External logger integration

The architecture and setup contract are documented in **[docs/EXTERNAL_LOGGERS_DESIGN.md](docs/EXTERNAL_LOGGERS_DESIGN.md)**.

Named definitions and an ordered active list live in the existing settings JSON.
`TExternalLoggerFactory.CreateLogger(definition, computerId)` constructs through
`uExternalLoggerRegistry`; DXKeeper, WRL and Club Log register their constructors.
The process-wide `externalLogger: TExternalLoggerService` is a composite
(`uExternalLoggers`), not one selected provider. ACLog/HRD remain unimplemented.

The main thread builds immutable contact values and the existing QSO dispatcher
hands them to independent destination queues. WRL and Club Log share durable
capture/lifecycle and worker code; HTTP never spans a database transaction.
New contacts, changes and deletes are required for every implemented provider.
Club Log replacements delete the last confirmed remote identity before creating
the edited contact; uncertain creates/replacements are not blindly replayed.
**Save applies the Enabled flag and the delivery order live, with no restart**
(issue 233); anything else waits for one, so queued work is never retargeted
underneath a running worker. Every saved definition gets a service at start-up
(an inactive one owns no worker) and the set of services is FIXED for the
session, so the dispatcher thread reads a list that never changes;
`TExternalLoggers.ApplyConfiguration` (main thread, called by Preferences after
the file is written) flips each service's switch and reorders. Off always
applies (it stops NEW handoffs; queued work stays); on applies only to a service
whose settings are what it was started with. A definition added since start, or
whose connection settings (anything its provider reads, secrets included, by
`SettingsStamp`) changed, runs as started until restart and its row says so.

### 8. Digital mode integration

- **WSJT-X** (`uWSJTX.pas`) — UDP; sends colorization hints, receives decodes/QSOs.
  Enabled with `WSJT-X ENABLE = TRUE`.
- **MMTTY** (`uMMTTY.pas`) -- RTTY engine. (The `MMTTYMODE` compile-time switch was deleted
  2026-08-18; NY4I: "the boolean controls it now".)

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
  **THE CONSOLE IS CAPPED AND ITS TRAFFIC IS NEVER WRITTEN TO DISK** (2026-09-24). `TELNET CONSOLE
  LINES` bounds what the window holds, and `uTelnetTrace.pas` keeps the last 200 lines in a ring
  that reaches the log **only when something has gone wrong** -- a crash, or a site in `uTelnet`
  that has already decided the session is broken. ~~`DXCluster\dxcluster <date> <time>.txt`~~ is
  **gone**; the deliberate full-capture path is still the `log all telnet traffic` setting, and it
  is what produces a capture for the corpus -- a ring of 200 lines cannot, and the code says so.
- **Country database** (`uctydat.pas`) — CTY.DAT parsing, callsign → country/zone/continent.

### 10. CW keying — the keyer factory

**The CW keyer factory is BUILT.** Phases A and B and the CAT repoint are complete; see
[`docs/CW_Keyer_Factory_Plan.md`](docs/CW_Keyer_Factory_Plan.md) (its status header is current and
records the commits).

TR4W has four mutually exclusive ways to key CW. Each is now a `TCWKeyer` strategy adapter, and
**no consumer outside the factory branches on keyer type any more**:

| Adapter          | Unit                     | Device                                                   |
| ---------------- | ------------------------ | -------------------------------------------------------- |
| `TCWKeyerCAT`    | `src/uCWKeyerCAT.pas`    | CW-by-CAT over the radio link                            |
| `TCWKeyerWinKey` | `src/uCWKeyerWinKey.pas` | WinKeyer (own thread, `uWinKey.pas` )                    |
| `TCWKeyerYCCC`   | `src/uCWKeyerYCCC.pas`   | YCCC SO2R+ box                                           |
| `TCWKeyerCPU`    | `src/uCWKeyerCPU.pas`    | DTR/RTS keying (`LOGK1EA`) — ~~LPT~~, removed 2026-09-13 |

Base and selection live in `src/uCWKeyerBase.pas`; `src/trdos/LogCW.pas` is the facade. Per-keyer
capabilities (`ckTune`, `ckDeleteLastChar`, `ckMessageChaining`) let the UI grey what the chosen
interface cannot do. `logdvp.pas` handles voice.

**The CAT repoint (done 2026-08-03) in three steps:** the send moved out of
`RadioObject.SendCW` (deleted) into `uCWKeyerCAT.CWByCATSend`, which takes the radio *explicitly*
rather than assuming `ActiveRadioPtr`, because SO2R (`KeyersSwapped`) and the interlock nominate a
radio; the capability gates repointed to `RadioObject.HasCapability` (the old model-keyed form
could not see a string-id radio, so TCI silently got no CW at all); and the *data* moved onto the
radio -- the frame rule and prosign dialect are `TRadioCapabilities.CWFrame` / `.CWProsignDialect`,
and the `KY <text>;` command lives on a real base class:

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

Log4D (`tr4w/include/Log4D.pas` — **not** under `src/`), global `logger: TLogLogger`, rolling file appender to `tr4w.log`, level from
`Settings.Log.DebugLevel` in `settings/tr4w.json` (`NONE`…`TRACE`) -- ~~`tr4w.ini`~~, which
startup has not read since 2026-09-19. Any standalone EXE that links app units must assign
the `MainUnit` global `logger` or it will AV.

## Documentation map

The full topic-to-document table is **[`docs/DOCUMENTATION_MAP.md`](docs/DOCUMENTATION_MAP.md)**.
Read the specific doc before acting in its area; this file is only a summary. The ones needed most:

- Build environment: `tr4w/docs/BUILD.md`
- What is waiting for a real run (a LIVING list): [`docs/BENCH_QUEUE.md`](docs/BENCH_QUEUE.md) -- add to it
  when you finish work only hardware can judge; NY4I removes items when he confirms them
- Adding a contest: [`docs/ADDING_A_CONTEST.md`](docs/ADDING_A_CONTEST.md); a radio: `docs/ADDING_A_RADIO.md`;
  a setting: [`docs/ADDING_A_SETTING.md`](docs/ADDING_A_SETTING.md)
- The live task list: [`docs/MODERNIZATION_ROADMAP.md`](docs/MODERNIZATION_ROADMAP.md)

## Runtime Dependencies

**Required in `target/`:** `CTY.DAT` (essential), `TRMASTER.DTA` (SCP, optional but recommended),
`dom/` (~126 domestic contest configs), and `help/help_<code>.po` (the Preferences tooltips, read by
`uCommandHelp`; English is the fallback). **`commands_help_*.ini` is NOT read at run time** -- NY4I,
2026-11-02: the ini files are historical reference, used only to seed the `help_*.po` catalogues, and
`tools/i18n/ini2po.py` must never modify them.

**BUT `CTY.DAT` AND `TRMASTER.DTA` NOW HAVE TWO LOCATIONS WITH A PRECEDENCE BETWEEN THEM**
(2026-09-24). A file TR4W **downloads** -- Alt-O for the country file, the Help menu for
TRMASTER.DTA and the POTA park list -- is written to the **writable data directory** and never
over the shipped copy, and the lookup prefers it:

```
uAppPaths.DownloadedDataDir  ->  the settings directory: target\settings\ on Windows,
                                 ~/Library/Application Support/TR4W on macOS,
                                 $XDG_CONFIG_HOME/tr4w on Linux
```

`FCONTEST.SetUpFileNames` searches **downloaded -> the contest directory -> shipped**, and logs
which tier answered (`[FCONTEST] Country file: <path> (<tier>)`). The download had to move
because `DataDir` is wrong on every platform for a different reason: on Windows it is the working
directory, which on a developer's machine **is this repository** and the tracked
`tr4w/target/cty.dat` was being overwritten; on macOS it is `Contents/Resources` **inside a
signed, notarized bundle**; on Linux an AppImage mounts read-only.

**`--settings <path>` MOVES THE WRITABLE DIRECTORY WITH IT, AND THAT IS WHAT KEEPS THE GOLDEN
CORPUS DETERMINISTIC** -- the corpus points the program at its own tracked fixture, which holds no
country file, so the lookup falls through to the tracked shipped copy no matter what the developer
has downloaded. Do not make the corpus read a location a developer can write to.

**The installer still ships `target/cty.dat` and `target/TRMASTER.DTA`** and `full.nsi` is
unchanged: those are the shipped tier.

**DLLs:** `libhamlib-4.dll` (+ the MinGW unwinder `libgcc_s_seh-1.dll`, `libusb-1.0.dll`,
`libwinpthread-1.dll`), `libeay32.dll` / `ssleay32.dll` (OpenSSL), and **`sqlite3.dll` (THE
CONTEST LOG — the installer ships it; FPC binds SQLite dynamically, so a missing DLL is a
run-time failure, not a link error)**. (`inpout32.dll` is not a dependency: the parallel port
was removed 2026-09-13. `rigctld.exe` is not shipped.)
See [`docs/UPDATING_RUNTIME_DLLS.md`](docs/UPDATING_RUNTIME_DLLS.md).

**THE DLL SET LIVES IN `tr4w/redist/x86_64-win64/`** and is 64-bit only (the 32-bit set was
deleted 2026-11-12; it is in history). `tr4w\target` holds a COPY so the program runs from the
tree; the build scripts and `Build-Tests.ps1` stage from `redist\`, never from `target\`, and
fail on a DLL whose PE machine word is not 0x8664 (`Get-Tr4wWrongArchDlls`, one definition).
Windows reports a wrong-bitness DLL as "module not found". `Lint-ArchStaging` PE-checks every
DLL under `target\` and every `redist\` directory.

**Created at runtime:** `settings/tr4w.json` (the legacy `settings/tr4w.ini` is neither created
nor read — it is `tr4wconvert`'s input, see
[Configuration](#configuration-srcucfgpas-srctrdoscfgcmdpas)), `settings/tr4w.pos`, contest
`.cfg`, and **the SQLite contest log**. Those paths are relative to the running binary, which in
this tree means `tr4w/target/`.

## Common Development Tasks

### Add a contest
Follow **Part A of [`docs/ADDING_A_CONTEST.md`](docs/ADDING_A_CONTEST.md)** top to bottom:
files and the `.dom` format (A1), the base class (A2), exactly which virtuals to override (A3),
every place outside the class that names the contest (A4), its tests (A5), and the gates in
order (A6). The worked examples are `uContestGeorgiaQP` (a state QSO party) and
`uContestURCDXRTTY` (any other contest). The legacy enum-model guide is archived at
`docs/migration_interim_artifacts/ADDING_A_NEW_CONTEST.md` (2026-10-23) -- history, not a checklist.

**The `ContestType` enum is FROZEN** (`Lint-FrozenContestNumbers`, since Q108 S3): a new contest
registers by its string id (`RegisterContestById`) with **no `VC.pas` entry**. It is refused on
the multi-op network and its UDP `<contestnr>` is derived from its id; its class writes neither.

**For a new contest, the unit tests are the only statement that it is correct.** The corpus has
no log of it, and the matrix record is frozen from its own first run.

**A NEW CONTEST IS ITS SQLITE FILE AND NOTHING ELSE. NO `.cfg`.** NY4I, 2026-10-15: *"the
standard going forward is we absolutely open a contest database file without a CFG file. CFG
file is purely a historical artifact if I want to import an external contest. If you have cfg
files still for a brand new contest (as opposed to simply the contest sqlite file), something
is wrong in our design."* The New Contest dialog writes none (since `66ac1ebe`): it queues its
values (`uNewContestCommands`) and they are applied into the new log's database. A `.cfg` is
only ever READ, as an import of an old or external contest.
**There is no metadata row**: `ContestsArray`, `ContestsBooleanArray` and `QSOParties` were deleted
at M10 S8 (2026-10-14). Then verify exchange parsing, multiplier tracking, scoring, and Cabrillo
export — and run the corpus, the factory check and the contest matrix.

### Modify UI
`TMainWindowElement` in `VC.pas` → `CreateMainWindow()` in `MainUnit.pas` → display routines in
`logwind.pas` → colours in `VC.pas` (`tr4wColors`).

`DEBUG LOG LEVEL = DEBUG` -- set it in Preferences, which writes `settings/tr4w.json`. Output to
`tr4w.log`.

## Important Conventions

### Code style — Pascal and Python

**Stated here, not only enforced:** `.claude/hooks/pascal-lint-hook.ps1` is a warn-only
`PostToolUse` hook that inspects `.pas`/`.dpr` only, so it speaks after the wrong edit is written.

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

**PREFER A CLASS TO A RECORD.** NY4I, 2026-09-08: *"I prefer objects to
records unless we are going to bring all of the 80-s back..."* — and, when the
first version of this rule listed four exemptions: *"Records that MUST stay
records will require convincing me unless they are interface parameters."*

**SO THERE IS EXACTLY ONE AUTOMATIC EXEMPTION: A LAYOUT DEFINED BY SOMETHING
OUTSIDE THIS CODE, AT THE BOUNDARY WHERE IT IS PASSED.** A Win32 API struct
(`TCharFormatA` — the OS names the fields and their order), a C library's
parameter block, a byte layout another program reads. There the record IS the
interface, and changing it would be changing the contract.

**"IT GOES OVER THE WIRE" IS NOT AN EXEMPTION.** NY4I, 2026-09-08: *"I can
persist a TContestExchange over the wire in multiple ways. No record
required."* He is right, and it is the sharper form of the rule:

**THE CONTRACT IS THE ENCODING, NOT THE TYPE.** A record is one way to produce
an encoding — the DOS/Win32 way, where the in-memory layout WAS the
serialization because you wrote the struct straight to a file or a socket.
Given a serializer, the in-memory type is free to be whatever suits the
program, and a class suits it better.

So `ContestExchange` and the protocol records are NOT exempt. What is real
about them is a separate question: the ENCODING has deployed readers — existing
binary `.dat` logs and older TR4W versions on a multi-op network — so changing
the BYTES is a compatibility decision. Changing the TYPE behind them is not.
Keeping those two questions apart is the whole point; the SQLite log work is
where the encoding one gets answered.

A flags or capability set passed by value is likewise a convenience, not a
contract.

**EVERY BLOCK COMMENT USES `(* *)`. NEVER `{ }`.** Not only commented-out code --
**every one**, including the ordinary explanatory comment above a routine.

A brace comment ends at the FIRST `}` it meets, and this tree is full of things
that contain one: `{$IFDEF ...}`, the resource directive in every designed form,
and ordinary explanatory brace comments inside the very code being commented out.
The comment closes early, the remainder becomes code, and the compiler reports a
syntax error somewhere that looks unrelated to what you did.

**AND IT IS GATED NOW, because saying it three ways was not enough.**
`build/Lint-BraceComments.ps1` fails the build when a `{$DIRECTIVE}` sits inside
a `{ }` comment AND closes on the same line -- the shape that broke the build on
2026-09-16, in a paragraph being written ABOUT platform gates. The compiler does
catch it, eventually, with a message that names neither the comment nor the
directive; the lint names the file, the line and the directive.

**It deliberately allows one shape: vendored Indy's.** Indy comments out
directive-bearing code by STRIPPING the closing braces --
`{$IFDEF STRING_IS_ANSI, ADestEncoding{$ENDIF` -- so the enclosing comment
survives and the unit compiles. Three such sites were the lint's first report
and all three were working code, which is why the rule is "closes on the same
line" rather than "appears at all".

**WIDENED 2026-09-01** from "comment a block of CODE out with `(* *)`", because the mechanism is a
property of every brace comment. Three failures in one day, all ordinary documentation, each cost a
build: `{ today }` in a table of two API shapes, `{$MODE DELPHI}` quoted in a design note, and a `}`
in an ASCII diagram. NY4I: *"Please make sure you use `(*` and `*)` around all your block comments
to avoid this problem."* Every `{$IFDEF WINDOWS}` / `{$IFDEF DARWIN}` pair adds another closing
brace a brace comment cannot survive.

### THE ONE THING THAT CLOSES A `(* *)` COMMENT: SQL `COUNT(*)`

This file claimed "nothing in this tree writes `*)`" until 2026-09-04, and that
was wrong the moment anyone documented a query. **`COUNT(*)` ends with a star
and a close paren**, so a comment explaining what a count costs terminates in
the middle of its own sentence and the remainder becomes code. Three of them in
one commit -- `uLogRepository`, `uLogSource`, `uLogGrid`.

Write **"a row count"**, or `COUNT( * )`, or name the column. The same applies
to any prose that ends a parenthesis with a star: a glob such as `src/*` inside
brackets does it too.

**AND DO NOT FIX IT WITH A BLANKET REPLACE.** Search-and-replacing that text
across those files also rewrote four LIVE SQL STRINGS -- `SELECT COUNT(*) FROM
qso` became `SELECT a row count FROM qso`. That compiles, and it is a broken
query inside a green build. The comment and the statement are the same
characters and only the context differs, so change them by hand and read the
diff before committing.

Python (`tools/`, `.claude/hooks/`) takes the same three-space indent — which is
NOT PEP 8, so an agent will default to four and nothing in this tree will catch
it. Readability over brevity everywhere: no minimising of lines, and comments on
the reasoning rather than the mechanics.

### Naming
- `u*.pas` — modern units; `Log*.pas` — core logging subsystem; `T` prefix — types/classes;
  `mwe` prefix — main window elements. Lowercase filenames in `trdos/`, MixedCase in `src/`.
- **EVERY PASCAL FILE HAS A LOWERCASE EXTENSION, AND THIS IS LOAD-BEARING**
  (2026-09-07). FPC resolves a unit by trying `<AsWritten>.pas`,
  `<lowercase>.pas` and `<UPPERCASE>.PAS` — and it matches those ITSELF against
  a directory listing rather than asking the operating system, so it is
  **case-sensitive even on a case-insensitive volume**. A mixed-case base with
  an uppercase extension (`uCTYDAT.PAS`) therefore matches NONE of the three and
  is invisible to every `uses` that names it.

  It only bites when the unit is a DEPENDENCY — passed on the command line the
  name is used verbatim — which is why `uCTYDAT.PAS` compiled alone and failed
  the moment `uCallSignRoutines` asked for it. **And the Windows-hosted Linux
  cross-compile cannot see it**, because that compiler inherits case-insensitive
  lookup from its host: ~~`Lint-LinuxCompile`~~ (RETIRED 2026-09-11) passed throughout. It took a NATIVE
  Unix host to surface. `Lint-UnitFileNames` is the guard on this machine.

  A MixedCase *base* name is fine (`uCallSignRoutines.pas`) — the first spelling
  matches. That is a weaker guarantee than lowercase, and it breaks the day
  someone writes `uses uCallsignRoutines`; finding those wants a native Unix
  compile of the whole tree, which is not possible yet.
- **Pascal identifier search is case-insensitive.** Always `grep -i` for Delphi symbols — TR4W spells
  the same identifier differently at declaration, assignment and use, and a case-sensitive grep has
  already produced a false "dead code" conclusion.
- **A LINE REGEX CANNOT PARSE PASCAL, AND `rg` DOES NOT CHANGE THAT.** `grep -i` answers WHERE AN
  IDENTIFIER APPEARS. It does not answer a STRUCTURAL question -- how many `case` arms exist, which
  ones are live, how many call sites a routine has -- and the failure is quiet rather than empty:
  you get a plausible number that is wrong. Measured in one session, 2026-09-29, three causes:

| the wrong answer                       | why                                                                                                                 |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| a contest scoring arm reported MISSING | the arm spells it `VAQSOPOINTMETHOD` , the search did not                                                           |
| 188 `case` arms counted where 91 exist | the regex matched the arms of NESTED cases too                                                                      |
| a second arm reported MISSING          | its label is `RadioVHFFDQSOPointMethod {, Championship...}:` -- a BRACE COMMENT SITS BETWEEN THE NAME AND THE COLON |

  The first was nearly reported to NY4I as a port regression, with the D7 arm quoted as proof of
  what had been lost. Nothing had been lost.

  **`tr4w/build/PascalSource.psm1` reads Pascal the way the COMPILER sees it** -- comments and
  string literals stripped, block-comment state carried across lines, `{$IFDEF}` treated as live
  code. Every lint that counts something is built on it, and `Count-LivePChar.ps1` /
  `Count-LiveAsm.ps1` exist because a raw grep over-reports those by 10x and 2x. Use it, or an
  `rg -i` for ONE named identifier, and do not invent a regex for the shape of the language.

  `rg` IS the right search tool here, and is what NY4I asks for: `rg -oNI -r '$1' 'QP:(\w+)'`
  replaces a `grep -o | sed` pair exactly, verified identical. It is faster and shorter. It is
  not more correct, and reaching for it does not make a text search into a parse.

### File encodings and line endings
Two silent-corruption traps live here, and neither produces a compiler diagnostic.

- **`src/lang/*.pas` are UTF-8 *with a BOM*** -- see [Language variants](#language-variants--being-replaced-dont-extend).
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
  time, `logstuff.pas` and `VC.pas` among them). Fix with
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

**THE DESTINATION IS NATIVE FPC/LAZARUS STRING HANDLING, WITH NO WIN32 ARTIFACTS LEFT** (NY4I,
2026-09-01): no `PChar`, string pointers or `s[1]` tricks. It is a destination, not a rule to apply
blindly today -- `ShortString` is still the TRDOS core's currency and `PAnsiChar` is still correct
at a real C boundary. For new code:

| instead of                            | write                                                                             |
| ------------------------------------- | --------------------------------------------------------------------------------- |
| `procedure F(var buf; size: integer)` | `procedure F(var buf: array of AnsiChar)` -- an open array carries its own bounds |
| `PAnsiChar(@buf)` and pointer walking | index the open array; `Low` /`High` are real                                      |
| `Move(src[1], dst[1], n)`             | plain assignment. `aRec.Name := someAnsiString` converts and truncates correctly  |
| `AnsiString(aFixedCharArray)`         | a NUL-aware helper. The cast takes the padding too                                |

**THE `ShortString()` CAST IS A CONVERSION** (an earlier version of this file said it was a pointer
reinterpretation; that was false and led to a bogus defect report). Measured on FPC 3.2.2 /
i386-win32 in this tree's mode (`{$MODE Delphi}` + `{$MODESWITCH UnicodeStrings}`):
`ShortString(s)` and `short := s` emit the same conversion with byte-identical results, pinned by
`tr4w/test/unit/uTestShortStringConversion.pas`. The only difference is a WARNING: the assignment
raises "Implicit string type conversion with potential data loss", the cast suppresses it, and
that count is a ratcheted build gate -- so rewriting casts as assignments RAISES the narrowing
number while changing no behaviour. The rules that hold are about width and termination:

- a `ShortString` has **no NUL terminator** -- never hand `@s[1]` to a `PAnsiChar` parameter (that
  is what corrupted a function-key memory in `uEditMessageForm`);
- it truncates at its declared width **silently, in both spellings** -- check the width, not the cast;
- an `openstring` parameter's `High()` is 255 in Delphi mode, so it can write 255 bytes into a
  `string[3]`;
- the genuine exceptions are the Win32 `...A` entry points and byte-exact serial I/O. Those are
  transports; everything above them passes strings.

### THE RULE: PREFER THE FPC/LAZARUS CLASS. A RAW CALL CARRIES ITS JUSTIFICATION.

NY4I, 2026-09-01: *"You have to justify every raw call, as that thinking can cause cross-platform
issues. You want to use the FPC/Laz classes and justify why if you cannot."* and *"You are also
going to have to justify every PAnsiChar or PChar in use when this is all done."*

A raw call quietly assumes Windows: a hardcoded `'sqlite3.dll'` names a file that cannot exist on
macOS or Linux, and `Windows.ReadFile` has no counterpart at all. **Reach for the FPC or LCL class
first; if you cannot, the reason goes in the code beside the call.** "It was quicker" is not one.
Worked examples, each of which started as a raw call and did not need to be:

| reached for                      | what was already there                                                                                                                |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| ` sqlite3_ex                     | `TSQLite3Connection.execsql` -- native `string` , transaction-free, owns the error text. `TSQLConnection.ExecuteDirect` is the WRONG  |
|                                  | method                                                                                                                                |
| ec` for pragmas                  | (`sqldb.pp:1492` starts a transaction unconditionally); `execsql` is `protected` , so a descendant reaches it                         |
| `Windows.Re adFile` for the      | `TFileStream`                                                                                                                         |
| binary log                       |                                                                                                                                       |
| a hardcoded `'sqlite3.d ll'`     | FPC's own `{$IFDEF WINDOWS}` / `'libsqlite3.' + SharedSuffix` (`sqlite3.inc:28-30`)                                                   |

**Before reaching for a C call, check whether the wrapper already has a method that does it.**

### AND NO NEW DIRECT CALLS INTO A DLL

NY4I, 2026-09-01: *"there should be no new direct calls to DLL files."* The sweep of existing
bindings waits for the cross-platform work; the RULE starts now, because the cost of a new binding
is paid later by whoever does that work. **A new `external '<something>.dll'`, or a new
`LoadLibrary` / `GetProcAddress` pair, needs a reason in the code and is a decision, not a
detail.** Ask first whether FPC, the LCL or an existing wrapper already does it.

What the existing bindings are, by kind (**no counts here -- a naive `grep external` over-reports
badly, so count properly or do not quote a number**):

- `winmm`: CW element timing (`LOGK1EA.tCWSleep`) and DVP WAV playback, all behind
  `{$IFDEF WINDOWS}`. **Off Windows the CW half falls back to plain `Sleep` and will not key a
  contest** -- a stated placeholder; see `docs/PLATFORM_CLOCK_ABSTRACTION.md` part 2.
- `libhamlib`: all bindings go through one three-arm constant (`uHamLibDirect.pas`, `HAMLIB_LIB`).
  **What is open is the other half:** HamLib is `dlopen`'d and its OWN dependencies resolve by the
  loader's normal search, so bundling it needs its dependency tree collected.
  `build-appimage.sh` collects `ldd` for the EXECUTABLE only, so HamLib is absent from the AppImage
  and **every HamLib-backed radio is non-functional there**.
- `user32`, `comdlg32` (the LCL has dialogs for all of it), `setupapi`, `hid`, `kernel32`,
  `comctl32`, `ws2_32`, `shlwapi`, `msvcrt`: Win32 API, where the port replaces the FUNCTION.
- The parallel port and `InpOut32` are gone (2026-09-13); BAND DECODER OUTPUT lapses until OTRSP AUX
  is wired on a YCCC box.

**The generalisation, when the sweep happens:** one unit that owns the NAME of every shipped
library -- HamLib, SQLite, OpenSSL -- per platform, the way FPC's own `sqlite3.inc` does.

**THE PChar AUDIT: COUNT IT, DO NOT QUOTE IT.**

```powershell
.\tr4w\build\Count-LivePChar.ps1      # comment-aware; a raw grep over-reports by ~10x
```

Each remaining one is either a genuine transport boundary that keeps its `PChar` and gains a
comment saying why, or a habit to remove. The five log units (`uLogSchema`, `uLogDatabase`,
`uLogBinaryFile`, `uLogRepository`, `uLogImport`) have **none of either**: the standard for new code.

- **The program passes `string`s.** Pointers, lengths, `ZeroMemory` and `s[1]` belong *inside* the
  transport where the bytes are actually written. Prefer `Foo(const s: string)` over
  `Foo(p: PAnsiChar; len: DWORD)`.
- **Generic Win32 names bind to the `W` variants.** A bare `@AnsiChar` buffer is an untyped
  `Pointer`, so it compiles silently *even with warnings on*. Call the `...A` variant explicitly.
  `GetPrivateProfileString` bound to `W`, wrote UTF-16 into an `AnsiChar` buffer, and **TR4WServer
  rejected every client** (`1bea7af4`). Neither W1057 nor the linters can see this class of bug:
  find it by reading. Winsock signatures also moved in both directions between D7 and D12
  (`bind` pointer → `var`, `accept` `var` → pointer); check each call.
- `tr4w/build/Lint-PCharAnsi.ps1` **gates the build** and understands Pascal (block-comment state,
  `{$IFDEF}` as live code, braces and `//` inside strings). A linter that fires on commented-out
  code gets ignored, so if you extend it, extend the fixture too.
- **Serial binary I/O must be byte-exact** -- `WriteBytes`/`ReadBytes`, never `WriteString`/
  `ReadString`. A CI-V or Yaesu-binary frame corrupted by string conversion fails silently.
- The done-criterion is "no `PAnsiChar(AnsiString(...))` double-casts except at genuine boundaries."

### Threading
Radio threads (one per radio), external logger threads (`TReadingThread` / `TSenderThread`), WinKey
thread, network threads, CW/DVP playback. The event objects (`tCW_Event`, `tCWPaddle_Event`,
`tDVP_Event`, `tNet_Event`) are created in `src/uProgramMain.pas`.

Threads hand results back through `TProcessMsgRef` callbacks — synchronize before touching UI state.
Radio disconnection is handled via the `radioWasDisconnected` flag rather than by tearing the object
down. **Open design observation (NY4I, not written up in any doc and not scheduled work):** the
`rig.CurrentStatus` / `rig.PreviousStatus` pair in `uRadioPolling.pas` does change-detection
*and* torn-read protection, and does neither cleanly — it is compared by raw byte scan over
`RadioStatusRecord`. The comparison is `RadioStatusDiffers(rig.CurrentStatus, rig.PreviousStatus)`;
grep that rather than the line numbers this file used to carry, which drifted. A seqlock, or an
immutable snapshot published by the driver at a coherent batch boundary, is the likely replacement.

### Error handling
Log4D throughout. Custom exceptions: `ERadioFactoryException`
(`src/radioFactory/uRadioFactory.pas`), `EExternalLoggerFactoryException`
(`src/uExternalLoggerFactory.pas`) -- grep the name for the line.
User-facing failures go through `ShowMessage`/`MessageBox`.
Prefer a *reported* error over a silent fallback — several defects on this branch were silent
downgrades (a string-id radio skipped in total silence, a WinKeyer that failed to open dropping to
DTR/RTS keying).

### Known compile snags
- `Undeclared identifier: 'EIdConnClosedGracefully'` / `'EIdSocketError'` → add `IdException, IdStack`
  to the uses clause.
- Missing Indy units -> the vendored search path is in `build/Get-SearchPaths.ps1`.
- **Vendored Indy 10.6.3.3 is kept deliberately.** D12 ships Indy as DCUs only
  (`Studio\23.0\source\Indy` holds just the IPPeer abstraction), so swapping is plausibly a
  *downgrade* and would lose source-level debuggability of the SSL path. Decided 2026-08-04 — don't
  re-propose it.

### Conditional compilation
`tDebugMode` and the `LANG_xxx` block live in `VC.pas`. Use `{$IF cond}...{$IFEND}`.

## Critical Notes for AI Assistants

1. **Respect the TRDOS boundary — but it no longer excludes the LCL** (rescinded 2026-08-23, NY4I).
   `src/trdos/` is proven contest logic and new behaviour still belongs in `src/`; a TRDOS unit
   reaching a converted control through the LCL seam is now ordinary.
2. **The two factories are the exception to "no OOP here."** `src/radioFactory/` and the CW keyer
   are real inheritance with real invariants — hold them to that standard. Everywhere else, expect
   procedural Pascal.
3. **The legacy radio path is gone, not deprecated.** Don't reach for `logradio.pas` or
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
