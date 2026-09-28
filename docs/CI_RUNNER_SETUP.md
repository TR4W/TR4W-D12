# Setting up a self-hosted CI runner

**Written 2026-08-14**, from actually doing it on `win-ci`. **Corrected 2026-09-28: there are now
THREE runners, and this document described only the first.**

TR4W's workflows run on **self-hosted runners** — one per platform — because the build needs a
32-bit FreePascal + Lazarus toolchain that no GitHub-hosted image carries, and because the macOS
signing identity lives in a machine's keychain rather than in a secret. This is the whole setup.

| runner | label | builds |
|---|---|---|
| `windows11-ci-d12` | `win-ci` | the app, `tr4wserver`, the NSIS installer, the VirusTotal scan, the release |
| `linux-ci-build-tr4w` | `linux-ci` | the app, the server, the tarball and the AppImage |
| `mac-ci-tr4w` | `mac-ci` | the app, the server, the `.dmg`, the `.pkg`, the `.dSYM`s — and signs and notarizes them |

**ONE WINDOWS RUNNER, so queue time reads as slow runs.** A job reported at 19m57s once ran in ~18s.
Check queue time before diagnosing a hang.

For the toolchain itself, [`tr4w/docs/BUILD.md`](../tr4w/docs/BUILD.md) is authoritative — a runner
needs exactly what a developer's PC needs and nothing extra. Don't duplicate it here.

## What the workflows expect

| workflow | fires on | needs a toolchain? | what it does |
|---|---|---|---|
| `version-guard.yml` | every push to `main`, every PR | **no** | asserts `tr4w/src/Version.pas` exists and parses. **It builds NOTHING** |
| `release.yml` | a `v[0-9]*.*.*` tag, or `workflow_dispatch` | yes | lints, tests, app, server, installer on `win-ci`; the Unix artifacts on `linux-ci` and `mac-ci`; a draft release **on a tag only** |

**SO NOTHING BUILDS ON AN ORDINARY PUSH TO `main`.** That is worth knowing before concluding a
change is verified because CI was green: on a push, the only thing that ran was the version guard.

**A `workflow_dispatch` RUN BUILDS ALL THREE PLATFORMS AND CREATES NO RELEASE** — the release job's
`if:` requires `github.event_name == 'push'`. That makes it the routine way to verify a platform:

```powershell
gh workflow run release.yml
gh run list --workflow release.yml --limit 1
gh run watch <run-id>
```

**Prefer it to an ssh session.** Hand-building over ssh takes longer, runs on one platform at a
time, and does not exercise the packaging, signing and upload path a release takes. ssh is for
*diagnosis* — a log, hardware, an interactive experiment. (NY4I, 2026-09-28: *"that was before
self-hosted running system and github ci builds were used."*)

**Each job's `runs-on:` label must exist on its runner** — `win-ci`, `linux-ci`, `mac-ci`. A missing
or misspelled label is the single most common way to end up with a job queued forever against a
healthy runner.

## Order of work, and why this order

**Register the runner first, before installing anything.** `version-guard` needs no FPC, no Lazarus
and no NSIS — only checkout and PowerShell. So it proves the runner, its labels, and the repo wiring
*in isolation*, while there is nothing else that could be at fault. Install the toolchain second and
let `release.yml` exercise it.

### 1. Register the runner

Get a registration token from **Settings → Actions → Runners → New self-hosted runner** on the
repository, then, on the runner box:

```powershell
cd C:\actions-runner-d12
.\config.cmd --url https://github.com/TR4W/TR4W-D12 --token <REG_TOKEN> `
             --name windows11-ci-d12 --labels win-ci --work _work --runasservice
```

One runner directory serves one repository. A box can host several — `win-ci` already runs separate
services for `n4af/TR4W`, `ny4i/TR4QT` and `ny4i/QK4` — so give each its own directory, its own
`--name`, and its own service.

### 2. Install the toolchain

Per [`BUILD.md`](../tr4w/docs/BUILD.md): the **32-bit** Lazarus, which carries the i386 FPC, the
i386 RTL and the i386 LCL units in one package. Silent, for an unattended box:

```powershell
lazarus-4.8-fpc-3.2.2-win32.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=C:\Lazarus
```

Plus **NSIS** (`makensis.exe`) for the installer step, and **git**.

### 3. Repo variables (optional)

`release.yml` reads three, each falling back to discovery or a sane default:

| variable | default | set it when |
|---|---|---|
| `FPC_HOME` | *(empty — discover)* | FPC is somewhere `Find-Toolchain` does not search |
| `LAZARUS_DIR` | *(empty — discover)* | same, for Lazarus |
| `NSIS_BIN` | `C:\Program Files (x86)\NSIS` | NSIS is installed elsewhere |

With a default-path install, **set none of them.** A pin is authoritative: if it names something
that cannot build TR4W the build fails naming what it rejected, rather than silently falling back to
another install — which on a runner would mean shipping from a toolchain nobody configured.

### 4. Prove it

```powershell
. C:\path\to\clone\tr4w\build\Find-Toolchain.ps1 ; Find-Tr4wToolchain
C:\path\to\clone\tr4w\FullBuild.ps1 -BuildInstaller
```

Expect every lint to pass, zero unit-test failures, and `tr4w.exe`, `tr4wserver.exe` and
`tr4w_setup_<version>.exe`. **The lint and test COUNTS are deliberately not written here** — they
grow every week and a stale number reads as a regression. Take them from the run's own output.

On a Unix runner the equivalent is `sh tr4w/build/build-unix.sh`, but prove a fresh runner with a
`workflow_dispatch` run instead where you can: it checks the labels, the toolchain and the artifact
upload in one pass, which is what you actually want to know.

## Known state of `win-ci` (2026-08-14)

Windows 11 Pro, on Proxmox. Runner user `runner`. Already present: git, NSIS at the default path,
Python 3.14, and several unpacked runner packages (2.322 → 2.336) under `C:\actions-runner*`.

**Lazarus 4.8 / FPC 3.2.2 (32-bit) is installed at `C:\Lazarus`** and a full build was verified
there: 10 lints, 3978/0, `tr4w_setup_5.0.0.exe` in **160 s** — against ~142 s on the development
workstation, so the VM is not a meaningful bottleneck.

**Not yet done: no runner is registered for `TR4W/TR4W-D12`.** The three configured runners serve
other repositories. That registration, and the token it needs, is the remaining step.

## Two traps this setup surfaced

Both are fixed in the build scripts now, but they are worth knowing because they are the shape of
failure a runner produces:

- **A hardcoded toolchain path in one lint** meant a correctly-installed machine failed the build
  while every other check passed. Anything that locates a tool must go through `Find-Toolchain`.
- **The unit-test exe would not start**, exiting `-1073741515` (`STATUS_DLL_NOT_FOUND`) before
  printing anything, because `libhamlib-4.dll` is a *load-time* import and the DLLs ship in
  `target\` while the exe must live in `test\unit\`. It worked on the development machine only
  because an unrelated HamLib checkout sat on `PATH`.

The general lesson: **a fresh clone is not a fresh machine.** `Test-FreshClone.ps1` re-clones and
rebuilds on the same PC, so anything the developer's environment supplies by accident stays hidden.
A runner is the first honest test of the setup instructions.
