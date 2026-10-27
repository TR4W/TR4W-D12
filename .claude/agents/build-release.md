---
name: build-release
description: Build, lint, test infrastructure and releases — FullBuild.ps1, the build and lint scripts, the three-platform builds, the self-hosted CI runners, the NSIS installer, versioning and GitHub releases. Use for build failures, toolchain problems, adding or changing a lint, CI workflow work, or cutting a release.
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
---

You own the machinery that turns this tree into something an operator can run.

## Toolchain

**FreePascal 3.2.2 + the Lazarus LCL.** Delphi 12 is gone — **every Delphi
project file was deleted 2026-08-31** and there is nothing left to run. `tr4w.lpr`
is the program source; all twelve program files are `.lpr`.

**There is no `-O` flag anywhere in the build.** Whether the program should
compile with one is an **open question, not a decision** — do not add it.

Open `tr4w/tr4w.lpi` with `C:\Lazarus`, **not** the fpcupdeluxe shortcut (x86_64
only, cannot build a Win32 target).

## Commands

```powershell
.\FullBuild.ps1                  # lints, then unit tests, then app, then server
.\FullBuild.ps1 -BuildInstaller  # + NSIS
.\build\Build-App.ps1            # full rebuild (-B), the safe default
.\build\Build-App.ps1 -Incremental
.\build\Build-Tests.ps1 -Run
.\build\Build-Tests.ps1 -Checked -Run   # -gt -gh; FullBuild.ps1 runs it too
.\build\Build-Bench.ps1          # builds EVERY test/bench/bench_*.lpr (floor 5); FullBuild.ps1
                                 # runs it after the tests, build only, skipped by -SkipTests.
                                 # -Program <name> for one; -Run needs a single -Program
.\build\Build-Server.ps1
.\build\Run-Lints.ps1
```

```sh
sh tr4w/build/build-unix.sh      # Linux and macOS; build-linux.sh / build-mac.sh are one-line execs
./tools/compile-native.sh --tree # MainUnit and its entire dependency graph
```

- **`-Incremental` for chasing one defect; a full build before believing any
  result.** FPC's mtime rule cannot see a changed switch, `.inc` or define flip. A
  designed form is *two* files and FPC only watches the `.pas`.
- **NEVER `-SkipServer`.** That build is the only guard on the console/LCL
  boundary. It hid a break for nine days.
- **Do not add behaviour to a Unix wrapper** — one implementation, two wrappers.
  The platforms differ in exactly four places.
- `build-unix.sh` does **not** stop at the first failing stage, unlike
  `FullBuild.ps1` — its summary is a ranked worklist.
- **The lints and the Edit-QSO round-trip are PowerShell and do not run on Unix.**
  Report them as **not-run**, never as passed.

## The CHECKED unit-test build

`Build-Tests.ps1 -Checked` compiles the same suite with `-gt` (trash locals) and
`-gh` (heaptrc) into `build-out/tests-checked-<cpu>-<os>/` and
`test/unit/tr4w_unit_tests_checked.exe` -- never the normal build's paths. It
fails on a test failure or crash, on heaptrc **corruption** lines ("Wrong
signature", "Marked memory at ... invalid", "Wrong size", "freed again at"...),
and on a **missing heaptrc summary** (fail closed). Unfreed blocks are a
ratchet: `$LEAK_CEILING` in the script, printed every run, lower it when it drops.

- **Do not add `-gl` to the default run.** heaptrc symbolises every unfreed block
  at exit; with ~13,500 of them that is 9+ minutes under DWARF and effectively
  forever under stabs. `-Lines` exists to diagnose a corruption report.
- **Do not add `HEAPTRC=keepreleased=1`.** The suite allocates ~1 GB cumulatively;
  a 32-bit process never reuses it and dies, and the heap-growth test fails.
- **`-CR` stays out:** it does not compile vendored `Log4D.pas`.
- It exists because commit 0ec5d43d's crash (an instance-sized `FillChar` over an
  old-style object with virtuals; an unassigned managed result) was invisible in
  a normal build and deterministic here.
- **heaptrc has a FALSE "freed again" (2026-10-14, found at M10 S2).** Under its
  default `usecrc` a live block's `sig` is a CRC-32 of size + 16 return
  addresses + tail, and "released" is the constant `$AAAAAAAA` in the SAME
  field, tested FIRST. A live block whose CRC is `$AAAAAAAA` is reported
  "Marked memory at ... released / freed again at" on its first free. The CRC
  has no heap address in it, so the collision is **fixed per binary** and moves
  with ANY code change (S2's two new tests triggered it in SettingsFreshInstall
  before either ran; `-Lines` hid it). **Without `keepreleased` the "was
  released at" lines are calls[9..16] of the ALLOCATION trace, not a release
  trace** -- do not chase them.
  - `HeaptrcReport.ps1` recomputes the signature from the printed size and
    addresses and excuses a report ONLY if it is `$AAAAAAAA`; it self-checks
    against the S2 block every run and fails closed.
  - The checked run sets `HEAPTRC=nohalt`, because heaptrc's `haltonerror`
    otherwise ENDS the run on the false positive (exit 1, later suites never
    run, unfreed count drops). heaptrc then exits 203; the gate accepts 203
    only with 0 failed tests and every report excused.
  - **Never "fix" it with `usecrc := false`:** the tail-overrun check exists
    only inside the CRC.
  - Ruled out on the way, with instruments in a scratch memory-manager spy:
    no overrun of any live block, no long-lived thread, no stale or double
    free within a 400k-free quarantine.

## The language resource is a build input (2026-10-16)

`tr4w/res/tr4w_languages.res` is tracked and linked by the app and the tests.
`Build-App.ps1` (incremental too) and `Build-Tests.ps1` call
`Sync-Tr4wLanguageRes` (`build/LanguageResStamp.ps1`): sha256 of every
`i18n/tr4w_*.po` plus `Make-LanguageRes.ps1` and the helper itself, compared with
`res/tr4w_languages.res.inputs`; mismatch regenerates (~3 s, byte-identical for
identical inputs), failure fails the build. **Content, not mtime** -- git sets
mtimes at checkout. A dirty `.res` + `.inputs` after a build means commit both.
Linux/macOS cannot run the generator, so `build-unix.sh` stage `languages` runs
`build/check-language-res.sh` and records FAIL on a stale pair; the release job
still publishes (it ignores that exit), so READ the summary. Keep the two hash
definitions (PowerShell and sh) identical. The Lazarus `lclstrconsts` catalogues
embedded in the `.res` are deliberately not hashed.

## The ceilings, and the rule about them

`Build-App.ps1` enforces them. **Split a string in ShortString rather than raising
a ratchet** — that is the standing answer when a change pushes a count up.

**Give every lint a floor.** A lint reporting "0 found" and PASSING is a guard
that fails open; that has happened here.

Add a lint by editing the array in `Run-Lints.ps1` — **one place**. The list
previously lived only in `tr4w.dproj`'s PreBuildEvent, so it gated msbuild and
nothing else.

**`Lint-ContestNameTests` is a per-file ratchet** (`$CEILINGS` table in the
script; `-List` prints the lines, `-Emit` the table, `-SelfTest` the fixture).
It counts any `ContestType` member (read from `VC.pas`, `DUMMYCONTEST` excepted;
fails closed under 150 names) used inside a body as a `=`/`<>` operand **whatever the
other operand is** (`exch.ceContest`, `rec.liContest`, `Contest`...), in an `in [...]`
set (one per test), or as a label of a **`case` arm (one per arm)** — all outside
`src\contestFactory\`. It is a token walk with a block stack, not a line regex. When a
file's count drops, lower its
ceiling — the script names the files that are below theirs.

**`Lint-NoContestTables` allows ONE table since M10 S8 (2026-10-14):
`ContestTypeSA`.** `ContestsArray` and `ContestsBooleanArray` left its
allow-list with their deletion; an allow-listed table not found fails it, so
the list cannot outlive what it names. **`Lint-DomCoverage` reads the party
classes now** (each `GetInStateDomesticFileName` literal, floor 22, fails on a
statement it cannot read) instead of `VC.pas`'s deleted `QSOParties`, and **it
is in `Run-Lints.ps1` since M10 S8**. It gated FullBuild's installer path from
2026-08-13 and was LOST, not dropped, when FullBuild was rewritten for FPC the
same night (`724d53d0` kept it only in the D12 script, deleted later with the
Delphi files) -- so for two months nothing ran it. That is the general
lesson: **a rewrite of a build script must carry every gate across, and the
place to put one is the `Run-Lints.ps1` array**, never a step inline in a
build script, where it can be lost with the script.

**Two pointer gates (pointer audit P1/P2, 2026-10-16), both over all of
`tr4w`, both with a fixture and floors:** `Lint-PointerTruncation` fails on a
cast to a 32-bit-or-narrower integer of `@x`, `Pointer(...)`, `Self`, or a
name the same file declares with a pointer type -- the narrowing direction
`64_BIT_TASKLIST`'s old scan could not see, and the x86_64 compiler accepts.
`Lint-TypedCodePointers` fails on `tCreateThread(@X` and `caAddress: @X`:
**in Delphi mode `@Routine` is an untyped pointer and FPC 3.2.2 does not
check it against a procedural parameter** (measured, with or without `{$T+}`),
so a typed slot is only checked while callers name the routine bare. Add a
slot to its `$Slots` table when another procedural type is introduced for
the same reason.

**`Lint-PascalBeginEnd` and `Lint-ChangedPascal` do NOT gate the build.** The
first runs as a warn-only `PostToolUse` hook; the second is run by hand.

**The `Count-Live*.ps1` scripts are measurements, not gates** — `Count-LiveAsm`,
`Count-LivePChar`, and `Count-LivePointers` (2026-10-16, the
22-category table that measures every `docs/POINTER_AUDIT.md` packet). They
are not in `Run-Lints` and have no ceiling. **The exception is
`Count-LiveMove`** (P15, 2026-10-17): `-Gate` makes it a ratchet
(`$MOVE_CEILING` in the script, lower it when the count drops, never raise it)
and `Run-Lints.ps1` runs it that way. **Never quote a raw grep in their
place**: this tree documents its conversions in comments, so a raw count is
wrong, and by a lot. All four read
through `PascalSource.psm1`, never a local regex. A new one takes
`Get-PascalCodeOnlyText -BlankStrings` when it counts CALLS, since a string
literal is not a call. It also runs a built-in fixture before it reports a
tree number, so it cannot fail open.

## Platforms

Windows i386, Linux x86_64 (app + server + tarball), macOS aarch64 (app + server +
`.app` bundle). x86_64-win64 **compiles and links** — 0 errors, same ceilings —
and **does not run; nobody has tried.** Compiling is not running.

**We do not cross-compile to check**, and a Windows gate is a guess until a
**native** compiler disagrees — `Lint-LinuxCompile` was retired for exactly that
reason: it inherited case-insensitive unit lookup from its host, so
`uCTYDAT.PAS` passed it and still broke on a real Unix box.

### RUN THE WORKFLOW. DO NOT SSH IN TO BUILD.

```powershell
gh workflow run release.yml                      # all three platforms, NO release created
gh run list --workflow release.yml --limit 1     # get the run id
gh run watch <run-id>                            # follow it
gh run view <run-id> --log-failed                # only what failed
```

NY4I, **2026-09-28**: *"that was before self-hosted running system and github ci
builds were used. audit any info about building and ensure all agents are aware
of ci GH process."*

~~*"we use ssh linux-build-ci and mac-ci to build on a native system"*~~
(**2026-09-11**) is **superseded, not wrong**: it was correct when he said it, and
the reason behind it — only a native compiler settles a platform question — is
the half that did not change. What changed is **who answers it**. Those same
machines are CI runners now, so the workflow reaches all three in parallel, in
the environment a release actually uses.

**A `workflow_dispatch` RUN CREATES NO RELEASE.** The release job's `if:`
requires `github.event_name == 'push'` and `release.yml` says so in terms. So a
dispatch has no side effect — nothing to clean up, nothing to un-publish — which
is what makes it the cheap routine check.

**NEVER pre-flight a native build immediately before tagging.** The tag does
exactly that. Twenty minutes went that way on 2026-09-28, minutes before a tag
that built all three platforms by itself.

**NOTHING BUILDS ON AN ORDINARY PUSH TO `main`**, which is why this matters:
`release.yml` fires on a `v[0-9]*.*.*` tag and on `workflow_dispatch` and nothing
else, and `version-guard.yml` — which does run on every push and PR — **builds
nothing**, its one job parses `Version.pas`. A dispatch is therefore not a
shortcut around CI; for untagged work it IS the CI build.

**ssh REMAINS RIGHT FOR DIAGNOSIS**, and keep that line sharp because the
machines are genuinely needed: reading a log, probing hardware, an interactive or
destructive experiment, a keychain or signing-identity question — anything that
needs a machine rather than a build. `portprobe` against a real FTDI adapter on
`linux-ci-build` and the Developer ID investigation on `mac-ci` are both correct
uses. "Does this compile on Linux" is not.

**The macOS artifacts are SIGNED AND NOTARIZED since 5.0.13** (2026-09-20), by
`tr4w/build/mac-sign.sh` called from `build-unix.sh`'s packaging stage. Facts worth
keeping:

- **The Developer ID key lives in `mac-ci`'s keychain, not in a secret**, and must
  stay that way — the worst a bad workflow can then do is ask that machine to sign.
  The repo secrets are the notary API key only (`APPLE_API_KEY_P8`, `APPLE_API_KEY_ID`,
  `APPLE_API_ISSUER_ID`).
- **Signing sits BETWEEN staging and archiving**, so a failure leaves no tarball and
  no `.dmg`: an unsigned build is an ABSENT build, not one a cleanup step is trusted
  to delete.
- **`notarytool --wait` can exit 0 on a rejected submission.** Gate on the parsed
  `status: Accepted`, then `stapler validate` and `spctl` on the app, the `.dmg` and
  the tarball's extracted app. Never on the exit code.
- **A pipeline hides an exit status**: `stapler validate … | tail -3` returns 0 while
  printing failure. Capture the command's own status.
- ~~`xattr -dr com.apple.quarantine`~~ is history. Do not put it in a release body.

## The ADIF validator is a gate step (2026-10-23)

`tr4w/test/adif-validate/validate-adif-outputs.sh` is called at the END of `export-d12-corpus.sh`,
`test-adif-roundtrip.sh` and `run-contest-matrix.sh` (each has its own output only then), and runs
the vendored `tools/adifvalidator/` (see its `VENDORED.md`). It needs python on PATH and fails
closed without it, without the validator, with no files, or on a validator crash -- a runner that
runs those scripts must have python. Any `Compliance error` fails the run; `Consistency error`
findings are reported and counted only.

## The runners are disposable

NY4I, verbatim: *"i do not work on the runners. I consider it the same as a
c:\temp folder. Subject to removal at any time with no regard for consequences."*
And: *"any discoveries made on the runner should be documented on this PC and not
the runner."*

So: **never stash or preserve files on a runner as though they were someone's
work.** If a tool proves useful there, move it up to the repo and remove it from
the runner. Pending changes on a runner mean either an un-gitignored artifact or
something has gone wrong.

`windows11-ci-d12` (`win-ci`), `linux-ci-build-tr4w` (`linux-ci`), `mac-ci-tr4w`
(`mac-ci`). **One Windows runner, so queue time looks like slow runs** — a job
reported at 19m57s ran in ~18s. Check queue time before diagnosing a hang.

**But a job QUEUED while a matching runner shows online and IDLE is not queue
time** (2026-10-14). The job's `runner_name` stays empty and the runner's
`_diag/Runner_*.log` shows it listening with no job message. Look for
`SelfUpdater` failures there: GitHub stops dispatching to a runner that cannot
update itself, without marking it offline. On win-ci the D12 service ran as
NETWORK SERVICE and could not write its update marker into system32; it runs
as LocalSystem now. Recipe in `docs/CI_RUNNER_SETUP.md`, third trap.
**Keeping the runners working is part of the job** (NY4I, 2026-10-14:
*"Maintaining the runners is an integral task"*) -- diagnose and fix, then
document here and in that file, not on the runner.

Apple secrets are **per-repository**. Do not copy credentials from another repo's
runner.

## "MUST NOT BLOCK" IS NOT "MUST NOT WAIT"

`needs:` is the only thing in Actions that makes a job **wait**. Keeping
`build-linux`/`build-macos` out of the release job's `needs:` — so a Unix
failure could never withhold the Windows installer — also meant the release
never waited for them, and the download steps are `continue-on-error`, so a
late artifact was **silently absent**.

**Measured, v5.0.14 (run 35531435287):** every job reported success and the
release carried NO macOS artifacts. The `.dmg` was built, signed, notarized and
uploaded; the release job downloaded at 19:17:33 and the macOS job finished at
19:17:45. Linux made it by **two seconds**. Every release before that had been
racing; v5.0.13 happened to win.

The shape that satisfies both rules: the optional jobs **are** in `needs:`, and
the `if:` never consults their result — `!cancelled()` (not `always()`, which
also releases a cancelled run) plus the event gate and explicit success
requirements for the jobs that genuinely are prerequisites. Any status-check
function switches off the implicit success gate, so those have to be restated.
**Do not lean on `continue-on-error` masking a result** — that is a second,
invisible reason the condition holds.

A release also now warns, per expected artifact, when one is absent, with the
producing job's result beside it. The failure above was invisible in the UI and
took five API queries to find.

## Releases

Version lives in `tr4w/src/Version.pas` (`TR4W_CURRENTVERSION_NUMBER`,
`TR4W_CURRENTVERSIONDATE`). `FullBuild.ps1` derives the version from it and
**fails rather than defaulting to 0.0.0**; `full.nsi` refuses to build without
`/DTR4WVERSION`. A tag push drives `release.yml`.

**Versions are cheap** (NY4I) — bump and re-tag rather than fighting a rerun.

**A green pipeline is a BUILD-AND-PUBLISH result, not a distribution channel.**
tr4w.net still serves 4.x. Never report a green run as "5.x is shipping to
operators".

`docs/RELEASE_WORKFLOW.md` sections 5–8 (1–4 are superseded by `BUILD.md`).

## Non-negotiable git rules

- **Never force-push `main`** — no `--force`, no `--force-with-lease`, no
  delete-and-recreate. Enforced server-side by the `protect-main` ruleset with no
  bypass actors. A previous rewrite produced 200+ conflicts across the whole tree
  and cost a day. When a push is rejected, **rebase or merge onto `d12/main`** —
  do not work around it.
- **No `Claude-Session:` trailer in any commit message or PR body.** This
  repository is **public** and that trailer links a private transcript.
  `Co-Authored-By` is fine. If one reaches the remote the fix is **forward-only**.
- **`d12` is the only remote.** There is no `origin`.

## The Linux unit-test stage is judged, and a crash is never forgiven (issue #141, 2026-10-27)

The Linux job printed `FAIL unit tests (run)` and stayed green for weeks, and the
printout was `head -10` of the `[FAIL]` lines, so nine more failures were never
shown. Worse, the suite **CRASHED** part-way (`CRASHED: EGridException` in
`NewContestForm`), so every suite after it had never run on Linux, and the only
trace was a paragraph in a 25 MB log. Three things now stand:

- **`build-unix.sh` `judge_test_failures`** prints every `[FAIL]` line, treats
  `CRASHED:` as a FAIL (never pinnable), and judges the rest against
  `tr4w/test/unit/known-failures-<os>.txt` (extended regexes, one per line, each
  naming its issue). A line matching no pin is a FAIL; **a pin matching no line is
  STALE and a FAIL** (the list only shrinks). The file is read through `tr -d '\r'`
  because `.gitattributes` gives every text file CRLF on checkout.
- **`release.yml` `build-linux` ends in `Gate -- the unit tests must have
  passed`**, unmasked, reading **`$RUNNER_TEMP/linux-stage-results.tsv`**, the
  copy the Build step saves right after `build-unix.sh` (both are deleted before
  the build so a stale row cannot pass). NOT `build-out/stage-results.tsv`
  itself: every `build-unix.sh` invocation rewrites that file with its own rows
  only, and the later `--symbols` step leaves just the symbols row there (run
  40495951500 read "no row"). It runs AFTER the uploads, so it reddens the
  job and withholds no artifact; the job stays `continue-on-error`, so the
  **workflow run still reads success -- read the job, not the run.**
- **macOS still SKIPs the suite** (no display). To run it: a logged-in GUI
  session on `mac-ci` with the runner started in it (a launchd agent, not a
  daemon), or a headless widgetset (`nogui`/`customdrawn` for the tests only; the
  tests drive real `TForm`s, so that is a port, not a flag). Neither is small.

`Lint-DomFileCase` (in `Run-Lints.ps1`) holds every `.dom` a contest class names,
and every `INCLUDE FILE` line, to the file's EXACT case; 10 class names and 95
INCLUDE lines are upper case against lower-case files, pinned and ratcheted
(`$LegacyNames`, `$INCLUDE_CEILING`). Windows cannot see this class of bug.

## Coordinate with

Every agent — you are the gate they all pass through.
