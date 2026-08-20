# TR4W Build & Release Workflow

> ## ⚠ PARTLY SUPERSEDED 2026-08-13 — read this box before anything below
>
> Most of this document was written for the **Delphi 7** era and was already stale before the
> FreePascal move. What is true **now**:
>
> | | Then (below) | Now |
> |---|---|---|
> | Toolchain | ~~Delphi 7, DCC32, UPX~~ | **FPC 3.2.2 + Lazarus LCL** |
> | Repository | ~~`TR4W/TR4W`~~ | **`TR4W/TR4W-D12`**, remote `d12` |
> | Branch | ~~`master`~~ | **`fpc`** (default since 2026-08-13) |
> | Languages | ~~ENG + 8, `-all` tags~~ | **One English build.** `-all` is tolerated, does nothing |
> | Local build | ~~`Build.cmd` → DCC32~~ | `utils\Build.cmd` → `FullBuild.ps1` (FPC) |
> | Installer | ~~`BuildAllInstallers.cmd`~~ | `utils\BuildEnglishInstaller.cmd` |
>
> **Sections 1-4 (prerequisites, PR review, building, smoke testing): use
> [`tr4w/docs/BUILD.md`](../tr4w/docs/BUILD.md) instead.** It is current.
>
> **Sections 5-8 (version policy, tagging, the GitHub release flow) are still broadly right** —
> the one rule below has not changed, and `TagIt.cmd` now derives the remote and branch from the
> current branch's upstream rather than assuming `origin master`. Read `master` as `fpc` and
> `origin` as `d12` throughout.
>
> **`utils\MonthlyBuild.cmd` / `tr4w\build\Invoke-Release.ps1` have NOT been ported.** They still
> require branch `master`, fetch `origin/master`, and default to an `-all` tag. They fail fast on
> `fpc` rather than doing damage, but they will not run until someone updates them.

## TL;DR — the caveman version

**Interim release** — bump, tag, let CI build:

```
:: 1. bump Version.pas (number + date) -- on fpc, locally or via the GitHub web UI
:: 2. tag it:
utils\TagIt.cmd 5.0.1
```

`TagIt` derives the remote and branch from the current branch's upstream (`d12/fpc`),
fast-forwards to it so it never tags a stale checkout, refuses to proceed if `Version.pas` is
uncommitted or if local HEAD is ahead of the remote, checks the tag matches the **committed**
`Version.pas`, then creates and pushes the tag. CI builds the installer once a `win-ci` runner is
attached.

~~**Monthly release** — refreshes CTY.DAT + TRMASTER.DTA, bumps `Version.pas`, builds, commits,
pushes, tags all languages:~~

```
utils\MonthlyBuild.cmd 4.148.0            :: NOT PORTED -- requires branch 'master'
utils\MonthlyBuild.cmd 4.148.0 -DryRun
```

**The one rule, unchanged:** the tag number must equal `TR4W_CURRENTVERSION_NUMBER` in
`Version.pas`. `TagIt` *checks* it for you. (On 2026-06-01 a hand `git tag` landed on a stale
pre-bump commit and CI rejected it — exactly what that check prevents.)

---

End-to-end guide covering: reviewing a PR, building locally, smoke-testing, tagging for the CI
build, and promoting to an installer release.

---

## 0. Audience and assumptions

- You have **write access** to ~~`TR4W/TR4W`~~ **`TR4W/TR4W-D12`** on GitHub.
- You're on Windows with the toolchain installed (~~Delphi 7, Indy, NSIS, UPX~~ **FPC + Lazarus
  with i386 LCL units, NSIS**; Indy is vendored — see
  [`tr4w/docs/BUILD.md`](../tr4w/docs/BUILD.md)).
- You're working from a clone of the repo (any location — the build derives its own paths).
- You have `gh` (GitHub CLI) authenticated, or you'll use the GitHub web UI for PR
  review and tagging.

---

## 1. Prerequisites (one-time setup)

> **Rewritten 2026-08-13.** The Delphi 7 / DCC32 / UPX checklist that stood here is gone. The
> authoritative version of this section is [`tr4w/docs/BUILD.md`](../tr4w/docs/BUILD.md); the
> summary below is enough to get a release out.

- [ ] **FPC able to target i386-win32** — `fpc.exe` plus a `ppc386`/`ppcross386` backend and an
      i386-win32 RTL. `fpc.exe` is only a driver; an x86_64-only install cannot build TR4W.
- [ ] **Lazarus carrying LCL units for i386-win32** (`<lazarus>\lcl\units\i386-win32`).
      **An x86_64-only install — the fpcupdeluxe default — will not do.**
- [ ] **NSIS** — only for `-BuildInstaller`.
- [ ] **Indy 10.6.3.3** — **vendored** in `tr4w\include`. Nothing to install, and no `INDY_ROOT`.
- [ ] **PowerShell** and **Git** — built in / already present.
- [ ] ~~**Delphi 7**, **UPX**~~ — no longer used by anything.

### 1a. Non-default tool locations

Locations are **discovered**, not configured — `tr4w\build\Find-Toolchain.ps1` searches PATH and
the usual roots, and prints every path it tried when it fails. Set these only to pin a specific
install (which is what you want on CI):

- [ ] `FPC_HOME` — the directory holding `fpc.exe` (or the install root).
- [ ] `LAZARUS_DIR` — the Lazarus directory.
- [ ] `NSIS_BIN` — the directory holding `makensis.exe`.
- [ ] `VIRUS_TOTAL_API_KEY` — VT public API key. **Optional**; CI is the authoritative gate.
      Free key at https://www.virustotal.com/gui/my-apikey
- [ ] ~~`DELPHI7_BIN`, `INDY_ROOT`, `UPX_BIN`~~ — read by nothing now.

**A pin is authoritative.** If `FPC_HOME`/`LAZARUS_DIR` names something that cannot build TR4W, the
build **fails** naming what was rejected rather than quietly falling back to another install — so a
runner cannot silently ship from a toolchain nobody configured.

Set permanently:

```
Win+R -> sysdm.cpl -> Advanced -> Environment Variables -> User variables -> New
Variable name:  FPC_HOME (or LAZARUS_DIR, or NSIS_BIN)
Variable value: <your path>
```

Close any open terminal so it picks up the new value.

Or, override per-invocation:

```
powershell -File tr4w\FullBuild.ps1 -Fpc "D:\FPC\3.2.2" -Laz "E:\Lazarus" -NsisBin "E:\NSIS"
```

There is no `-ProjectRoot`: every script derives the repo root from its own location, so a clone
works from anywhere with no arguments. That is verified rather than assumed — see
`tr4w\build\Test-FreshClone.ps1`.

---

## 2. Reviewing an incoming PR

Day-to-day flow when someone opens a PR (or you opened one from a branch and want
to verify before merging).

1. **Read the PR on GitHub first.**
   - Skim the description, the file list, and the diff.
   - If the PR touches `Version.pas` AND other files, that's the normal case (one
     PR bundles the feature change + version bump).
   - If the PR is `Version.pas`-only, it's the narrow carve-out for version bumps;
     those can also land direct to the default branch without a PR -- but if it
     arrived as a PR anyway, just merge it.

2. **Check out the branch locally.**
   ```
   git fetch d12
   git checkout <branch-name>
   git pull
   ```
   Or with `gh`:
   ```
   gh pr checkout <PR-number>
   ```

3. **Build locally** (see [section 3](#3-building-locally)).

4. **Smoke test** (see [section 4](#4-smoke-testing)).

5. **Approve / request changes** via the GitHub UI.

6. **Merge.** Use the GitHub merge UI. Default is "Create a merge commit" for TR4W.

7. **Back to the default branch.**
   ```
   git checkout fpc
   git pull
   ```

---

## 3. Building locally

> **Rewritten 2026-08-13.** Everything that stood here — the `Build.cmd`/`BuildAll.cmd` table, the
> DCU-cache incremental notes, the per-language build, the DCC32 troubleshooting and the local UPX
> and VirusTotal steps — described the Delphi 7 build. It is replaced by
> [`tr4w/docs/BUILD.md`](../tr4w/docs/BUILD.md), which is the single current source and is kept
> alongside the build scripts it documents.

```bat
utils\Build.cmd                    :: lints -> unit tests -> app -> tr4wserver
utils\BuildEnglishInstaller.cmd    :: the above + the NSIS installer
```

Both work from any directory and take no configuration. What matters for a release:

- **A failing unit test aborts the build before any binary exists.** That ordering is the reason
  `FullBuild.ps1` exists; do not work around it with `-SkipTests` for anything you intend to ship.
- **The version is checked, not assumed.** It comes from `tr4w\src\Version.pas`, the build fails
  rather than defaulting if it cannot be parsed, and the linked `tr4w.exe` is then verified to
  report it — so a version resource that failed to link cannot ship silently.
- **Artifacts land where they ship**: `tr4w\target\tr4w.exe`, `tr4w\tr4wserver\tr4wserver.exe`,
  `tr4w\build\release\tr4w_setup_<version>.exe`. Intermediates go to `build-out\` (gitignored).
- **Before shipping to testers, prove a clone builds it**, not just your working tree:
  `.\tr4w\build\Test-FreshClone.ps1 -WithInstaller`. It diffs binary sizes against your tree and
  has already caught an untracked file being linked into the shipping server binary.

~~`BuildAll.cmd` / `BuildAllInstallers.cmd`~~ are retired — they built the eight non-English
variants. Running either now prints a signpost and exits non-zero.

Local VirusTotal scanning is no longer wired into the local build; CI remains the authoritative
gate (`.github/scripts/Invoke-VirusTotalScan.ps1`, threshold in `release.yml`).


## 4. Smoke testing

After a local build, before approving the PR or tagging a release, run the
program and at least verify:

- [ ] **Launches.** Double-click `tr4w\target\tr4w.exe`. Title bar shows
  `TR4W v.<version>`.
- [ ] **Language is right.** Default English build: menus in English. Per-language
  build: spot-check the title / menus are in the expected language.
- [ ] **The feature in the PR works.** Read the PR description and exercise the
  code path it touches.
- [ ] **Nothing obvious regressed.** Open a contest, log a test QSO, verify the
  basics.
- [ ] **For radio-touching PRs:** connect to whatever hardware you have on hand
  and confirm the radio still polls (band/freq/mode display updates).

If the change is hardware- or contest-specific and you can't test it (e.g., a
TS-890 fix when you don't have a TS-890), say so explicitly in your PR review
rather than approving on faith. Hand the build to whoever does have the hardware.

---

## 5. When to update `Version.pas`

`src/Version.pas` is the single source of truth for the version string. The CI
release workflow extracts `TR4W_CURRENTVERSION_NUMBER` and refuses to build if it
doesn't match the tag (with the `-all` suffix stripped). So getting the timing
right matters.

There are two patterns. Pick the one that fits the situation:

### Pattern A: Bundled with the feature PR (preferred when possible)

Use this when the feature PR is intended to be the next release.

1. On the feature branch, as part of the PR's commits, bump
   `TR4W_CURRENTVERSION_NUMBER` and `TR4W_CURRENTVERSIONDATE`.
2. PR gets reviewed + merged to master normally.
3. After merge, **immediately** tag master (see [section 6](#6-tagging-for-an-english-only-release)).
   The bumped version is already on master; no separate bump step.

Pro: one PR, atomic. The version-bump diff and the changes that justify it travel
together; reviewer sees both.

Con: requires deciding the version number when the PR opens. If multiple PRs are
in flight, only one of them can carry the bump -- the others need rebasing or
will conflict.

### Pattern B: Standalone bump on master, no PR

Use this when:

- Several PRs have already merged since the last release and none of them carried
  a bump, OR
- You're cutting a release at a point not aligned with any single PR (e.g.,
  monthly cadence), OR
- A `-all` tag follows an English `vX.Y.Z` release: bump version, push, tag.

Steps -- runs **directly on the default branch**, no branch, no PR:

```
git checkout fpc
git pull
# edit tr4w\src\Version.pas: bump TR4W_CURRENTVERSION_NUMBER and _DATE
git add tr4w\src\Version.pas
git commit -m "Bump Version.pas to 5.0.1"
git push d12 fpc
```

> **The remote is `d12`, not `origin`.** In this clone `origin` is `TR4W/TR4W` — the Delphi 7
> heritage repository. `git push origin ...` would push into the wrong project. This is not
> hypothetical: `TagIt.ps1` hardcoded `origin master` until 2026-08-13 and would have pushed a v5
> tag there.

This is the narrow exception to the "no direct commits on the default branch" rule. It
applies **only** to `Version.pas`-only diffs whose review value is essentially
zero. Comment-only changes, typo fixes, and everything else still go through a
branch + PR.

### What NOT to do

- **Don't tag without bumping first.** The CI's tag-vs-`Version.pas` validation
  will fail, the build won't run, and you'll have to delete the tag and re-push.
- **Don't bump and then forget to tag.** A bumped `Version.pas` on master with no
  matching tag means the EXE built locally claims version N+1 but there's no
  corresponding release artifact anywhere.
- **Don't reuse a version.** Once `v4.147.18` is tagged and published, the next
  release is `v4.147.19` or `v4.148.0` -- not a re-tag of `v4.147.18`. Bump it
  again.

### Version-number conventions

- **Patch bumps** (`4.147.17` -> `4.147.18`): bug fixes, small features, the
  default for most releases.
- **Minor bumps** (`4.147.x` -> `4.148.0`): notable feature additions, new radio
  support, new contest additions.
- **Major bumps** (`4.x.y` -> `5.0.0`): reserved; not currently planned.
- **Date** (`TR4W_CURRENTVERSIONDATE`): update to the current "Month, Year" of the
  release.

---

## 6. Tagging for an English-only release

This is the **normal** release path. Use it for the vast majority of releases.

**Precondition:** `Version.pas` on the default branch reflects the version you're
about to tag. If not, do [section 5](#5-when-to-update-versionpas) first.

1. **Make sure the branch is clean and you're on it.**
   ```
   git checkout fpc
   git pull
   git status   # should be clean
   ```

2. **Confirm the version.**
   ```
   git -C . show HEAD:tr4w/src/Version.pas | findstr CURRENTVERSION_NUMBER
   ```
   You should see exactly the version you're about to tag, e.g.
   `TR4W_CURRENTVERSION_NUMBER = '4.147.18'`.

3. **Create the tag and push it.**

   Annotated tag (recommended -- carries a message and a tagger date):
   ```
   git tag -a v4.147.18 -m "TR4W v4.147.18"
   git push d12 v4.147.18
   ```

   Lightweight tag (also works, no message):
   ```
   git tag v4.147.18
   git push d12 v4.147.18
   ```

   To push **all** local tags at once (rarely needed):
   ```
   git push d12 --tags
   ```

4. **CI fires.** `.github/workflows/release.yml` matches `v4.*.*` and runs three
   jobs in sequence:
   - **build** (Windows runner): compiles, UPX-compresses, runs `makensis`,
     uploads `tr4w_setup_4.147.18.exe` as a workflow artifact.
   - **virustotal-scan** (Linux runner): downloads the installer, uploads it to
     VirusTotal, polls for completion, generates `virustotal-report.md`. Fails
     the pipeline if any installer hits the threshold
     (`VT_MALICIOUS_THRESHOLD = 8`), which blocks the release job. An emergency
     `skip_virustotal` input is available on the `workflow_dispatch` trigger.
   - **release** (Linux runner): only runs on tag push. Downloads both
     artifacts, creates a **draft** GitHub Release with auto-generated
     changelog, the installer, AND the VT report attached.

5. **Watch the run.** GitHub Actions tab, or:
   ```
   gh run watch
   ```
   English-only build is ~3-5 min.

6. **Review and publish the draft release.**
   - Open the draft on GitHub.
   - Edit the auto-generated notes -- highlight headline changes, call out radio
     additions, breaking changes, contest additions.
   - Verify the installer is attached.
   - **Publish.** This emails watchers and makes the release public.

### Fixing a mis-tag

If you tagged the wrong commit (or tagged before bumping `Version.pas`):

```
git push --delete d12 v4.147.18    # remove tag from remote
git tag -d v4.147.18                  # remove tag locally
# fix the underlying issue (bump Version.pas, push, etc.)
git tag v4.147.18
git push d12 v4.147.18
```

This is safe as long as the draft release hasn't been published yet. Once
published, prefer cutting a new version instead of force-retagging.

---

## ~~7. Tagging for an all-languages release (major releases only)~~

> **RETIRED 2026-08-13.** There is no all-languages build. TR4W ships ONE English binary and
> translation is moving to `resourcestring`; `-AllLanguages` no longer exists as a switch, the
> per-language installers are gone, and `utils\BuildAllInstallers.cmd` is a signpost that exits
> non-zero.
>
> A `vX.Y.Z-all` tag is still *tolerated* — the suffix is stripped before the version comparison,
> so an old-habit tag releases rather than failing obscurely — but it produces exactly the same
> single build as `vX.Y.Z`. Prefer the plain form.
>
> The original procedure is struck through below for reference only.


~~Use this for major releases where you want shippable installers for every~~
~~language. It's slower (~25 min) and the per-language installers are mostly~~
~~appreciated by international contesters who don't want to muddle through English~~
~~menus.~~

~~Same as [section 6](#6-tagging-for-an-english-only-release) except:~~

~~- **Tag with `-all` suffix:** `v4.147.18-all` instead of `v4.147.18`.~~
~~- CI detects the `-all` suffix and runs `FullBuild.ps1 -AllLanguages~~
~~  -BuildInstallers`.~~
~~- The draft release gets all 8 installers attached (`tr4w_setup_4.147.18.exe`~~
~~  plus 7 per-language `_rus`, `_ser`, `_mng`, `_cze`, `_rom`, `_ger`, `_ukr`).~~
~~- Release title in the draft includes "(all languages)".~~

~~The tag matching strips `-all` before comparing to `Version.pas`, so both~~
~~`v4.147.18` and `v4.147.18-all` validate against `Version.pas = 4.147.18`. You~~
~~can use either on the same version; you cannot use both with two separate tag~~
~~events without an intermediate version bump.~~

~~**Typical cadence:** ship English-only on point releases; ship all-languages on~~
~~the first release of a quarter, or whenever language files have meaningfully~~
~~changed.~~

~~---~~

## 8. Ad-hoc full builds without a release

If you want to produce all-language installers for testing without creating a
GitHub Release (e.g., to give Howie a build of the current master to validate
language files):

- GitHub Actions tab -> "Release Build" workflow -> **Run workflow** button.
- Check "Build all language installers".
- Pick the branch (usually `master`).
- Run.

This runs the same `FullBuild.ps1 -AllLanguages -BuildInstallers` chain and
uploads the installers as a workflow artifact, but **does not** create a draft
release. The artifact lives for 90 days; download it from the run's summary page.

---

## 9. Quick reference

| Goal                                  | Command / action                                                  |
|---------------------------------------|-------------------------------------------------------------------|
| Build English locally                 | `utils\Build.cmd`                                                 |
| Build every language locally          | `utils\BuildAll.cmd`                                              |
| Build every language + installers     | `utils\BuildAllInstallers.cmd`                                    |
| Interim English release               | Bump `Version.pas`, then `utils\TagIt.cmd X.Y.Z`                  |
| Interim all-languages release         | Bump `Version.pas`, then `utils\TagIt.cmd X.Y.Z-all`              |
| Monthly release (CTY + TRMASTER refresh, all langs) | `utils\MonthlyBuild.cmd X.Y.Z`                      |
| Rehearse a monthly release            | `utils\MonthlyBuild.cmd X.Y.Z -DryRun`                            |
| Ad-hoc all-langs build, no release    | Actions tab -> Release Build -> Run workflow -> check the box     |
| Check the CI runner has the right tools | Repo Settings -> Variables -> Actions: `DELPHI7_BIN`, `NSIS_BIN`, `INDY_ROOT` |

---

## 10. Related files

- `.github/workflows/release.yml` -- the CI workflow itself
- `tr4w/FullBuild.ps1` -- the build script
- `tr4w/build/full.nsi` -- NSIS installer script
- `tr4w/src/Version.pas` -- single source of truth for the version string
- `utils/Build.cmd`, `utils/BuildAll.cmd`, `utils/BuildAllInstallers.cmd`,
  `utils/BuildEnglishInstaller.cmd` -- thin wrappers around `FullBuild.ps1`
- `tr4w/build/Invoke-Release.ps1` -- full **monthly** release orchestrator
  (refresh CTY.DAT + TRMASTER.DTA -> bump `Version.pas` -> local build -> commit ->
  push -> tag `-all`)
- `utils/MonthlyBuild.cmd` -- caveman wrapper around `Invoke-Release.ps1`
- `utils/TagIt.cmd`, `utils/TagIt.ps1` -- guarded **interim** tagger (ff-pull origin
  + verify tag == `Version.pas`, then tag + push)
