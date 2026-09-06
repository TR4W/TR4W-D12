# Compiling TR4W for Linux from a Windows machine

**Why this exists.** TR4W has to be able to compile on macOS and Linux (NY4I,
2026-09-06: *"this is not optional"*), and until 2026-09-06 there was no way to
check that on the machine where the work happens. Windows-only code was going
behind `{$IFDEF WINDOWS}` with an `{$ELSE}` branch that **nobody could compile
even once** — which is the same class of mistake as writing an unverified
library file name, and CLAUDE.md already records one of those.

This is the inner loop that makes those branches real. It uses only what is
already on the machine: no downloads, no `sudo`, and it does not touch the
working Win32 toolchain.

---

## What it is made of

| piece | where it comes from |
|---|---|
| `ppcrossx64.exe` — the compiler, targeting x86_64-linux | built from `C:\fpcupdeluxe\fpcsrc` with the native Win32 FPC |
| the Linux RTL and packages | built by the same `make` run |
| `as` and `ld` for x86_64-linux | **Ubuntu under WSL**, which already has binutils |
| the glue | `tools/wsl-binutils/` — see below |

**The assembler is the only genuinely missing piece, and it was already
installed.** FPC builds the cross compiler from source in a couple of minutes
with nothing but the Windows compiler; where it stops is `prt0.as`, a
hand-written GNU-assembler startup stub that has to go through a real `as` for
the target. Ubuntu under WSL ships `/usr/bin/as` and `/usr/bin/ld` — those *are*
x86_64-linux binutils, and reaching them needs no password, unlike
`apt install`.

### `tools/wsl-binutils/`

`wslbinutil.lpr` builds one small executable that is copied to
`x86_64-linux-as.exe` and `x86_64-linux-ld.exe`. It decides which tool to run
from **its own file name**, rewrites Windows paths in the arguments to their
`/mnt` form (`C:/x/y` → `/mnt/c/x/y`), and hands the rest to
`wsl.exe -d Ubuntu -- <tool>`. The exit code is passed straight back, so a real
failure is a real failure to `make`.

**It is an `.exe` and not a `.cmd` on purpose:** FPC's makefiles invoke these
names through `CreateProcess`, which does not launch batch files.

The distro comes from `TR4W_WSL_DISTRO`, defaulting to `Ubuntu`.

---

## Building it

```powershell
# 1. the shim (once)
cd C:\tr4w-d12\tools\wsl-binutils
C:\FPC\3.2.2\bin\i386-Win32\fpc.exe -O2 wslbinutil.lpr
copy wslbinutil.exe x86_64-linux-as.exe
copy wslbinutil.exe x86_64-linux-ld.exe

# 2. the cross compiler, the Linux RTL and packages
$env:PATH = "C:\tr4w-d12\tools\wsl-binutils;C:\FPC\3.2.2\bin\i386-Win32;$env:PATH"
cd C:\fpcupdeluxe\fpcsrc
make crossall CPU_TARGET=x86_64 OS_TARGET=linux `
     FPC=C:/FPC/3.2.2/bin/i386-Win32/fpc.exe
```

The built exes are gitignored; the source is tracked so the next machine can
rebuild them.

---

## What this DOES and DOES NOT prove

**Does:** that a unit's non-Windows branch parses, resolves its identifiers and
generates code for a real target. That is the whole point — an `{$ELSE}` nobody
has compiled is a guess.

**Does not:** that TR4W *runs* on Linux, or that it links. Most of the tree is
still saturated with Win32 calls; `MainUnit`, `uMainWindowProc` and the entire
main-window message procedure are Windows code with no gate at all yet. Getting
a link needs the LCL built for Linux as well, and that is a separate step.

**So use it the way a linter is used**: point it at the units you have just
gated and read the errors. The first ones will be genuine and useful — they name
exactly which types and units still bind a unit to Windows.

---

## Known first blockers

These are the ones already written down in the source rather than guessed at:

- **`uMMTTY`'s interface** — `uses Windows, Messages` for `HWND`, `UINT`,
  `WPARAM`/`LPARAM`, `TColorRef`, `LF_FACESIZE` and `WM_USER`. `LCLType`
  declares the handle and message types for every widget set and is the likely
  answer; `EM_SETCHARFORMAT` is `WM_USER + 68` and can simply be the number.
  Its implementation is already gated.
- **`MMTTYObject`'s `HWND` fields**, which about twenty other units read.

---

## The other half: a Linux VM or WSL for actually running it

Compiling is not running. When there is something worth running, WSL can host a
native FPC and Lazarus (`apt install fpc lazarus`) — but that needs a password
and is a much larger install, so it is deliberately not part of this recipe.
