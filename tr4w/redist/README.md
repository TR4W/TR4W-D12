# `tr4w/redist/` — third-party runtime binaries (64-bit only)

Created 2026-09-14, when NY4I supplied the first x86_64 runtime DLL. **Windows TR4W is
x86_64-win64 only** (NY4I, 2026-11-12: "I have no plans to ever support 32 bit Windows OS"), so
this holds one directory, `x86_64-win64/`. The 32-bit set that used to sit beside it
(`i386-win32/`, with `libgcc_s_dw2-1.dll`) was deleted that day; it is in git history if anyone
ever needs the bytes.

## The rule

**A DLL here must be 64-bit, and the machine word is read from its PE header, never trusted
from a name.** `sqlite3.dll` and `libhamlib-4.dll` have identical file names in both bitnesses,
so a wrong-bitness copy is indistinguishable by name.

That matters more than it sounds. Windows reports a 32/64-bit mismatch as
*"the specified module could not be found"* — naming a file that is sitting
right there — and `docs/UPDATING_RUNTIME_DLLS.md` records that this has
already cost people afternoons. `src/domain/uLogDatabase.pas` reads the PE
machine word and says which architecture it actually found
(`DescribePEArchitecture`, `DiagnoseSQLiteLoad`) precisely because the
operating system's own message points the wrong way.

## What is here

| directory | holds | PE machine |
|---|---|---|
| `x86_64-win64/` | `libeay32`, `ssleay32` (OpenSSL 1.0.2), `sqlite3` (3.53.4) + `sqlite3.def`, `libhamlib-4`, `libusb-1.0`, `libwinpthread-1`, `libgcc_s_seh-1` (the x64 unwinder) | `0x8664` |

**`tr4w/target/` holds a COPY of this set**, so the program runs from the tree and `full.nsi`
finds the DLLs where it always did. It is NOT a source: `Build-App.ps1` and `Build-Tests.ps1`
stage from `redist\x86_64-win64\`. After updating a DLL here, copy it to `target\` too.

`Lint-ArchStaging` PE-checks every DLL in `target\` and in EVERY directory under `redist\`
(floor 12), so a 32-bit set added here again is read and refused, not skipped, and it refuses
a stray `libhamlib*` copy under `target\`. A 32-bit HamLib found anywhere else is passed over by
`uHamLibDirect.ResolveHamLibPath`, which never loads a copy of the other bitness.

## What consumes this

`Build-App.ps1` copies this directory beside the exe it links; it requires the six fixed names
plus one `libgcc_s_*.dll`, and validates every PE machine word **before** staging any of them
(`Get-Tr4wWrongArchDlls` in `build\Get-StagingDir.ps1`; a rejected DLL is never left beside the
binary). `Build-Tests.ps1` does the same for the unit-test exe in `test\unit\` and then scans
every `*.dll` there, so a leftover 32-bit DLL from an old build is named and fails the build —
delete it. `full.nsi` builds the installer from `target\`.

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
2. **Match the version.** Changing a library's version and its source in one
   step means a failure has two candidate causes.

`*.dll` is gitignored tree-wide, so these are added with `git add -f`, the same
way `tr4w/target/`'s are.
