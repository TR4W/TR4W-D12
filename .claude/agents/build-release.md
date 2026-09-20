---
name: build-release
description: Build, lint, test infrastructure and releases — FullBuild.ps1, the build and lint scripts, the three-platform builds, the self-hosted CI runners, the NSIS installer, versioning and GitHub releases. Use for build failures, toolchain problems, adding or changing a lint, CI workflow work, or cutting a release.
tools: Read, Grep, Glob, Bash, Edit, Write
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

## The ceilings, and the rule about them

`Build-App.ps1` enforces them. **Split a string in ShortString rather than raising
a ratchet** — that is the standing answer when a change pushes a count up.

**Give every lint a floor.** A lint reporting "0 found" and PASSING is a guard
that fails open; that has happened here.

Add a lint by editing the array in `Run-Lints.ps1` — **one place**. The list
previously lived only in `tr4w.dproj`'s PreBuildEvent, so it gated msbuild and
nothing else.

**`Lint-PascalBeginEnd` and `Lint-ChangedPascal` do NOT gate the build.** The
first runs as a warn-only `PostToolUse` hook; the second is run by hand.

**The `Count-Live*.ps1` scripts are measurements, not gates** — `Count-LiveAsm`,
`Count-LivePChar`, `Count-LiveMove`. They are not in `Run-Lints` and have no
ceiling. **Never quote a raw grep in their place**: this tree documents its
conversions in comments, so a raw count is wrong, and by a lot. All three read
through `PascalSource.psm1`, never a local regex. A new one takes
`Get-PascalCodeOnlyText -BlankStrings` when it counts CALLS, since a string
literal is not a call. It also runs a built-in fixture before it reports a
tree number, so it cannot fail open.

## Platforms

Windows i386, Linux x86_64 (app + server + tarball), macOS aarch64 (app + server +
`.app` bundle). x86_64-win64 **compiles and links** — 0 errors, same ceilings —
and **does not run; nobody has tried.** Compiling is not running.

**We do not cross-compile to check.** NY4I: *"we use ssh linux-build-ci and mac-ci
to build on a native system."* A Windows gate is a guess until a **native**
compiler disagrees — `Lint-LinuxCompile` was retired for exactly that reason: it
inherited case-insensitive unit lookup from its host, so `uCTYDAT.PAS` passed it
and still broke on a real Unix box.

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

Apple secrets are **per-repository**. Do not copy credentials from another repo's
runner.

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

## Coordinate with

Every agent — you are the gate they all pass through.
