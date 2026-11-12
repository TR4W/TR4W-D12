# Updating Bundled Runtime DLLs

TR4W ships several third-party DLLs in `tr4w/target/` so that the NSIS
installer can bundle them and so that the program works out-of-the-box on
machines without the libraries pre-installed. This document is for
maintainers who need to update those DLLs to a newer upstream version.

For most contributors this doc is irrelevant — a routine `git pull` brings
the current DLLs in automatically. Read on only if you intend to **replace**
a bundled DLL with a newer copy.

---

## STATUS 2026-11-12 -- EVERY DLL IS 64-BIT, AND THERE IS NO 32-BIT SET (issue 299)

Windows TR4W is x86_64-win64 only (NY4I: "I have no plans to ever support 32 bit Windows OS").
The 32-bit set (`tr4w/redist/i386-win32/`, with `libgcc_s_dw2-1.dll`) was deleted that day; it is
in git history. The DLLs live in `tr4w/redist/x86_64-win64/` and `tr4w/target/` holds a COPY.
The unwinder is `libgcc_s_seh-1.dll`. **To update a DLL: replace it in
`redist\x86_64-win64\`, then copy it into `target\` (same name), measure the PE machine word
(`0x8664`) and run `build\Lint-ArchStaging.ps1`, which checks every DLL.** `rigctld.exe` is not
shipped. The build scripts and the unit-test build stage from `redist\`, never from `target\`.
See `tr4w/redist/README.md`.

## Bundled runtime files at a glance

All are **64-bit** (PE machine `0x8664`).

| File | Source | Purpose |
|---|---|---|
| `libhamlib-4.dll` | [HamLib](https://hamlib.github.io/) Windows 64-bit build (`hamlib-w64-X.Y.Z.zip`) | Radio control via the HamLib library (used by `uRadioHamLibDirect.pas`). **The version is read out of the DLL itself** -- it carries NO Windows version resource, so Explorer and `Get-ChildItem .VersionInfo` both show blank. |
| `libgcc_s_seh-1.dll` | Ships in the HamLib Windows zip | MinGW runtime — required by `libhamlib-4.dll` |
| `libusb-1.0.dll` | Ships in the HamLib Windows zip | USB transport — required by `libhamlib-4.dll` for USB-attached radios |
| `libwinpthread-1.dll` | Ships in the HamLib Windows zip | POSIX-threads runtime — required by `libhamlib-4.dll` |
| `libeay32.dll` | OpenSSL 1.0.2 (legacy series) | Used by Indy for HTTPS (HamScore RTC, TR4WSERVER TLS) |
| `ssleay32.dll` | OpenSSL 1.0.2 (legacy series) | SSL/TLS layer — required by `libeay32.dll` |
| `sqlite3.dll` | [sqlite.org](https://sqlite.org/download.html) `sqlite-dll-win-x64-*` | **The contest log.** Currently 3.53.4. Bound at RUN TIME, not link time — see the note below |
| `libtailcat.dll` | the Tailcat tunnel library (issue 293) | Loaded only when Use Tailcat is ticked; installed `/nonfatal` |
| `rigctld.exe` | HamLib Windows build | **DEPRECATED.** Replaced by direct-DLL mode (`uRadioHamLibDirect.pas`). Tracked but not shipped by the installer; planned for removal. |

`inpout32.dll` is not a dependency: the parallel port was removed 2026-09-13.

### `sqlite3.dll` — the one that fails differently

Every other DLL in the table above is a **load-time** import: Windows resolves it
before a line of TR4W runs, and a missing one gives `STATUS_DLL_NOT_FOUND` and no
window at all. Obvious, if brutal.

**SQLite is bound at run time.** FPC's `sqlite3.inc` declares
`Sqlite3Lib = 'sqlite3.dll'` and resolves through `LoadLibrary`, so TR4W starts
perfectly and then fails the moment it opens a log — which looks like a corrupt
log rather than a missing file.

**And the architecture mismatch is worse than the missing file.** Windows reports
a 32/64-bit DLL mismatch as *"the specified module could not be found"*, naming a
file that is sitting right there in the install directory. That message has cost
people afternoons.

So `src\domain\uLogDatabase.pas` reads the PE machine word out of the file it
found and says which architecture it is (`DescribePEArchitecture`,
`DiagnoseSQLiteLoad`). A 32-bit `sqlite3.dll` on the path is the mismatch it
will name.

The 64-bit copy is `tr4w/redist/x86_64-win64/sqlite3.dll` (SQLite 3.53.4,
verified `0x8664` from its PE header). **A DLL update has two homes:**
`tr4w/redist/x86_64-win64/` (what the builds stage from) and `tr4w/target/`
(what the installer packs) -- update both, same version. See
`tr4w/redist/README.md`.

The DLL is also copied beside the unit-test binary by `build\Build-Tests.ps1`,
because the `LogDatabase` suite opens real databases.


> ⚠️ **A DLL must be 64-bit.** Since 2026-11-12 the program is 64-bit only.
> A DLL of the other bitness fails to load, reported by Windows as "module not
> found" -- see the status block at the top. `Get-Tr4wWrongArchDlls` (build
> scripts) and `Lint-ArchStaging` refuse one.

---

## Why the gitignore actively blocks accidental updates

The repo root `.gitignore` contains:

```
*.dll
tr4w/target/*
```

Both rules would normally prevent any DLL from being committed. The bundled
DLLs are tracked anyway because they were `git add`'d **before** the rules
were added — once a file is tracked, gitignore stops applying to it.

The net effect is deliberately protective:

- ✅ `git pull` updates the tracked DLLs from upstream commits normally.
- ✅ `git status` shows tracked DLLs as modified if you replace them locally.
- ❌ `git add tr4w/target/libhamlib-4.dll` after replacing it silently does
  nothing — the file is ignored.
- ✅ `git add -f tr4w/target/libhamlib-4.dll` works.

This is intentional. The `-f` requirement is a speed bump against the most
common mistake: dropping a newer or wrong-bitness DLL into `tr4w/target/`
during local debugging and unintentionally committing it to the repo. If
you really mean to update the bundled copy, `-f` says so.

---

## Procedure: updating the HamLib DLLs

The four HamLib DLLs (`libhamlib-4.dll`, `libgcc_s_seh-1.dll`,
`libusb-1.0.dll`, `libwinpthread-1.dll`) ship as a set in the upstream
HamLib Windows zip. Update them together so the runtime is internally
consistent.

1. **Download the upstream zip.** Go to
   <https://github.com/Hamlib/Hamlib/releases> and grab the latest
   **`hamlib-w64-X.Y.Z.zip`** — the 64-bit build. Do **not** download
   `hamlib-w32-X.Y.Z.zip` (or the older `hamlib-win32-` name); 32-bit
   Windows is not supported.
2. **Extract** to a scratch directory. The four DLLs live in the zip's
   `bin/`.
3. **Verify bitness** before copying. From a PowerShell prompt:
   ```
   $bytes = [System.IO.File]::ReadAllBytes("path\to\libhamlib-4.dll")
   $peOffset = [System.BitConverter]::ToInt32($bytes, 60)
   $machine  = [System.BitConverter]::ToUInt16($bytes, $peOffset + 4)
   # 0x8664 = 64-bit (x64); 0x14c = 32-bit and WRONG
   "0x{0:x}" -f $machine
   ```
   Confirm the output is `0x8664` for all four DLLs.
4. **Replace** the four files in `tr4w/redist/x86_64-win64/`, then copy them
   into `tr4w/target/`.
5. **Test build** — run `Build.cmd` then launch `tr4w/target/tr4w.exe` and
   confirm a HamLib-controlled radio still connects.
   `build\Lint-ArchStaging.ps1` reads every DLL's PE header and refuses a
   wrong-bitness one; a smoke test still matters for the rest.
6. **Stage with `-f`** and commit:
   ```
   git add -f tr4w/redist/x86_64-win64/libhamlib-4.dll tr4w/target/libhamlib-4.dll
   git add -f tr4w/redist/x86_64-win64/libgcc_s_seh-1.dll tr4w/target/libgcc_s_seh-1.dll
   git add -f tr4w/redist/x86_64-win64/libusb-1.0.dll tr4w/target/libusb-1.0.dll
   git add -f tr4w/redist/x86_64-win64/libwinpthread-1.dll tr4w/target/libwinpthread-1.dll
   git commit -m "Bump bundled HamLib to X.Y.Z (64-bit)"
   ```
7. **Open a PR** even though it's an infra change — the upstream version
   bump is worth a review.

---

## Procedure: updating OpenSSL (libeay32 + ssleay32)

TR4W tracks the **legacy OpenSSL 1.0.2** series. Indy 10.6.3.3 (the version
TR4W bundles) does **not** support OpenSSL 1.1.x or 3.x — the DLL exports
and API shape changed incompatibly. Do not drop a 1.1.x or 3.x build of
`libeay32.dll`/`ssleay32.dll` into `tr4w/target/`; HTTPS connections will
fail at runtime with cryptic SSL handshake errors.

Indy-compatible 1.0.2 binaries are no longer published by OpenSSL itself
(end-of-life since 2019). Reliable mirrors used historically:

- <https://indy.fulgan.com/SSL/> — built specifically for Indy
- <https://wiki.openssl.org/index.php/Binaries> — pointers to community
  mirrors

Pick a 64-bit OpenSSL 1.0.2u (or latest 1.0.2-series) build, then follow
the same steps as HamLib above:

1. Download the 64-bit 1.0.2-series build.
2. Verify bitness (same PE-header check; `0x8664`).
3. Replace `libeay32.dll` and `ssleay32.dll` in `tr4w/redist/x86_64-win64/`
   and `tr4w/target/`.
4. Test — log a QSO into a HamScore-enabled contest and confirm HTTPS POST
   succeeds (check `tr4w.log` for `[HamScore] POST ... -> 200`).
5. `git add -f` both files, commit, PR.

> 🔒 **The right long-term fix is to refresh Indy** so we can use OpenSSL
> 3.x. Tracked under [Indy refresh with Delphi 12 port](../) in the
> maintainer memory; out of scope for a routine OpenSSL DLL refresh.

---

## inpout32 (gone)

`inpout32.dll` is not a dependency any more: the parallel port was removed
2026-09-13, and it was a 32-bit-only DLL that could not be loaded by the
64-bit program in any case.

---

## `rigctld.exe` (deprecated)

`tr4w/target/rigctld.exe` is tracked but **not** referenced by `full.nsi`
(so the installer doesn't ship it) and **not** invoked by TR4W's code
(replaced by direct-DLL mode in `uRadioHamLibDirect.pas` — see
`uRadioFactory.pas` line 214: `"Direct DLL mode - no rigctld process
needed"`).

**AND IT COULD NEVER HAVE RUN FROM THAT DIRECTORY.** Measured 2026-09-14:
`rigctld.exe` is **x86_64** and imports `libhamlib-4.dll`, which is i386.
A 64-bit process cannot load a 32-bit DLL, so it dies before `main` --
`rigctld.exe --version` produces no output and exits 127. Harmless only
because nothing launches it. (Issue 299, 2026-11-12: the 64-bit installer does
not ship it either, so "rigctld bitness" is moot until it is wanted; if it ever
is, the x64 build is the one that matches an x64 `libhamlib-4.dll`.)

**Don't update it.** The right move is to remove it entirely on a future
cleanup pass. Tracked separately as a TODO.

---

## Common pitfalls

| Pitfall | What goes wrong | How to spot |
|---|---|---|
| Dropping a 64-bit DLL | Runtime "wrong-architecture" load failure or silent skip | TR4W can't connect to the radio; `tr4w.log` shows DLL load error. Verify with the PE-header check above. |
| `git add` without `-f` | Update appears to succeed locally but the new bytes aren't staged | `git diff --cached` shows the file as unchanged. Always re-check with `git status` before committing. |
| OpenSSL 1.1.x / 3.x against Indy 10.6.3.3 | HTTPS POSTs fail with handshake errors | HamScore log shows network errors; works in browser but not from TR4W. |
| HamLib DLLs from mixed versions | Random radio-control failures, missing rig support | Update all 4 HamLib DLLs together from a single upstream zip. |
| Replacing a tracked DLL but forgetting to commit | Locally works, but the next CI build (or another developer's clone) uses the old version | Run `git status tr4w/target/` after replacement to confirm the diff is staged. |

---

## Verification after any DLL update

Before pushing:

1. `Build.cmd` — verifies the build still compiles.
2. `BuildAllInstallers.cmd` — exercises the new pre-flight dep check (the
   replaced DLL must still satisfy the `File` directives in `full.nsi`).
3. Launch the produced `tr4w.exe` and exercise the relevant feature
   (radio connect / HTTPS upload / LPT keying), depending on which DLL
   changed.
4. `git status` to confirm only the intended files are staged.

---

## Related files

- `tr4w/build/full.nsi` — installer manifest that bundles the DLLs into the
  setup.
- `tr4w/FullBuild.ps1` — build script with the `Test-InstallerDependencies`
  pre-flight that ensures every `File` directive in `full.nsi` resolves to
  an existing file before NSIS runs.
- `tr4w/src/uRadioHamLibDirect.pas` — direct-DLL HamLib client, supersedes
  the old `rigctld` daemon path.
- `.gitignore` (repo root) — the rules that block accidental DLL commits.
