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
script and `docs/UPDATING_RUNTIME_DLLS.md` for no benefit until a second
architecture actually builds. **When the x64 toolchain lands, move them and
give each build target a manifest** — that is the moment the split pays, and
doing it before then is churn.

## Nothing consumes this yet

There is **no x86_64-win64 build target**, so nothing copies this file
anywhere. It is staged so that the DLL is already in the tree, at a known
version, when the toolchain arrives — not because a build reads it today. Do
not add a copy step that silently stages an x64 DLL into an i386 `target/`.

## Adding to it

Follow `docs/UPDATING_RUNTIME_DLLS.md`. Two extra obligations here:

1. **State the architecture by measuring the PE header**, not by trusting the
   download's name — `rigctld.exe` sat in `target/` as x86_64 while the docs
   called it 32-bit, and it could never have run.
2. **Match the version across architectures.** Changing version and bitness in
   one step means a failure has two candidate causes.

`*.dll` is gitignored tree-wide, so these are added with `git add -f`, the same
way `tr4w/target/`'s are.
