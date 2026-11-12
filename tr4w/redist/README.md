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

## What is here

| | |
|---|---|
| `x86_64-win64/sqlite3.dll` | SQLite **3.53.4**, x86_64. The SAME VERSION as the 32-bit copy in `tr4w/target/` — deliberately, so the eventual 64-bit build changes bitness and nothing else |
| `x86_64-win64/sqlite3.def` | shipped beside it in sqlite.org's zip; kept with it |

## What is NOT here, and why

**The seven 32-bit runtime DLLs still live in `tr4w/target/`**, which is the
i386 program directory as well as the staging area. They are not moved here,
because moving them would touch `full.nsi`, `Build-Tests.ps1`, the AppImage
script and `docs/UPDATING_RUNTIME_DLLS.md`. The x64 build now exists (see
below), and the i386 build was deliberately left reading `target\` so the
installer for it is byte-for-byte what it was. **Move them when the default
flips to 64-bit and 32-bit is retired** -- then `target\` stops being an
architecture's private directory.

## What consumes this (issue 299, 2026-11-12)

`Build-App.ps1 -Cpu x86_64 -Os win64` copies this directory's DLLs beside the
exe it links. **That exe is staged under `build-out\dist\x86_64-win64\`, never
in `tr4w\target`**: `build\Get-StagingDir.ps1` holds the rule and
`Assert-Tr4wNotI386Path` refuses an x64 build pointed at `tr4w\target` or
`tr4w\tr4wserver`; `Lint-ArchStaging` pins it. `FullBuild.ps1 -Cpu x86_64`
stages the app, `tr4wserver.exe` and `tr4wconvert.exe` there too, and
`full.nsi /DTR4WARCH=x86_64` (via `build\Build-Installer.ps1`) builds the
64-bit installer from that stage -- which is why the x64 DLL set, with
`libgcc_s_seh-1.dll` in place of `libgcc_s_dw2-1.dll`, must be complete here.
Do not add a copy step that stages an x64 DLL into an i386 `target/`.

## Adding to it

Follow `docs/UPDATING_RUNTIME_DLLS.md`. Two extra obligations here:

1. **State the architecture by measuring the PE header**, not by trusting the
   download's name — `rigctld.exe` sat in `target/` as x86_64 while the docs
   called it 32-bit, and it could never have run.
2. **Match the version across architectures.** Changing version and bitness in
   one step means a failure has two candidate causes.

`*.dll` is gitignored tree-wide, so these are added with `git add -f`, the same
way `tr4w/target/`'s are.
