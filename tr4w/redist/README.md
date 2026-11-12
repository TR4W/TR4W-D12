# `tr4w/redist/` — third-party runtime binaries, **per architecture**

Created 2026-09-14, when NY4I supplied the first x86_64 runtime DLL. It exists
for one reason, and the 64-bit task list states it as a requirement:

> Architecture-specific output directories — `build-out/app-x86_64-win64` must
> share no `.ppu`, `.o` or **staged DLL** with `app-i386-win32`.

## The rule

**A DLL here is named by the architecture it is FOR, never by the one that is
current.** `sqlite3.dll` and `libhamlib-4.dll` have identical file names in
both bitnesses, so two copies in one directory are indistinguishable and the
only thing that can keep them apart is the directory.

That matters more than it sounds. Windows reports a 32/64-bit mismatch as
*"the specified module could not be found"* — naming a file that is sitting
right there — and `docs/UPDATING_RUNTIME_DLLS.md` records that this has
already cost people afternoons. `src/domain/uLogDatabase.pas` reads the PE
machine word and says which architecture it actually found
(`DescribePEArchitecture`, `DiagnoseSQLiteLoad`) precisely because the
operating system's own message points the wrong way.

## What is here (2026-11-12: the default flipped to 64-bit, issue 299)

| directory | holds | PE machine |
|---|---|---|
| `x86_64-win64/` | `libeay32`, `ssleay32` (OpenSSL 1.0.2), `sqlite3` (3.53.4) + `sqlite3.def`, `libhamlib-4`, `libusb-1.0`, `libwinpthread-1`, **`libgcc_s_seh-1`** (the x64 unwinder) | `0x8664` |
| `i386-win32/` | the same set with **`libgcc_s_dw2-1`** in place of the seh unwinder. Moved here from `tr4w/target/` on the flip; byte-identical to what `target/` held (sha256 checked) | `0x014C` |

**`tr4w/target/` holds a COPY of the shipping (x86_64) set**, so the program runs from the
tree and `full.nsi` finds the DLLs where it always did. It is NOT a source: every build script
and `Build-Tests.ps1` stage from the architecture's own `redist\` directory, and
`Lint-ArchStaging` PE-checks every DLL in `target\` and both `redist\` directories against the
directory's architecture (floor 12). After updating a DLL here, copy the x64 one to `target\`
too.

**HamLib 32-bit copies.** The 32-bit `libhamlib-4.dll` is `i386-win32/libhamlib-4.dll` now (it
had been renamed `libhamlib-4.dll.w32` in `target\` by NY4I's approval). A 64-bit exe must not
be able to pick up a 32-bit HamLib: `uHamLibDirect.ResolveHamLibPath` already passes over a
copy of the other bitness, and the lint refuses a stray `libhamlib*` under `target\`. Any
32-bit HamLib found elsewhere is renamed `.w32` or kept under `i386-win32\`.

## What consumes this

`Build-App.ps1` copies the target architecture's directory beside the exe it links; it
requires the six fixed names plus one `libgcc_s_*.dll`, validates every PE machine word
**before** staging any of them (a rejected DLL is never left beside the binary), and removes a
`libgcc_s_*.dll` of the other bitness already sitting there. `Build-Tests.ps1` does the same
for the unit-test exe in `test\unit\` and then scans every `*.dll` there. The shipping
architecture's exe stages into `tr4w\target`; the 32-bit build (`-Cpu i386`) stages under
`build-out\dist\i386-win32\`, never in `target`: `build\Get-StagingDir.ps1` holds the rule and
`Assert-Tr4wShippingPathOnly` refuses a 32-bit build pointed at `tr4w\target` or
`tr4w\tr4wserver`; `Lint-ArchStaging` pins it. `full.nsi` (no define) builds the 64-bit
installer from `target\`; `/DTR4WARCH=i386 /DTR4WSTAGE=<dir>` builds the 32-bit one from a stage.

## How the program finds them at run time (2026-11-12)

**Beside the running exe first, whatever the working directory is.** SQLite
and OpenSSL are loaded by bare name, and Windows searches the application
directory before anything else. HamLib is located by TR4W itself
(`uHamLibDirect.HamLibCandidates`): beside the exe, then the shipped-data
location (the working directory on Windows), then PATH -- and a copy of the
**other** bitness is passed over, never loaded. HamLib's own dependents
(`libgcc_s_*`, `libusb-1.0`, `libwinpthread-1`) resolve the same way, from the
exe's directory, so they must be staged there with it -- which `Build-App.ps1`
does.

## Adding to it

Follow `docs/UPDATING_RUNTIME_DLLS.md`. Two extra obligations here:

1. **State the architecture by measuring the PE header**, not by trusting the
   download's name — `rigctld.exe` sat in `target/` as x86_64 while the docs
   called it 32-bit, and it could never have run.
2. **Match the version across architectures.** Changing version and bitness in
   one step means a failure has two candidate causes.

`*.dll` is gitignored tree-wide, so these are added with `git add -f`, the same
way `tr4w/target/`'s are (`git add -f tr4w/redist/i386-win32` after the move).
