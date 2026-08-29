# What is still here only because Delphi used to build this

**A survey, taken 2026-08-29. Nothing in it has been changed.**

It was taken straight after the `{$IFDEF FPC}` guards came out, on the grounds
that the guards were the visible half of the problem and the units they guarded
are the other half. NY4I: *"identify (but don't yet change) remaining Delphi
shims."*

**Delphi cannot build this tree.** `FullBuild-D12-deprecated.ps1` stopped working
when the FMX twins were deleted on 2026-08-17, because it needs units that no
longer exist. Everything below is therefore dead weight, a shim whose second half
is unreachable, or a name that describes a world that ended — not a portability
asset.

Ordered by what to do first: cheapest and safest at the top.

---

## 1. Confirmed dead weight — deletion, no behaviour change

### `jedi.inc` — 83 KB, preprocessed into all 426 units, defining nothing anyone reads

The chain is:

```
tr4w.inc  ->  Defines.inc  ->  jedi.inc
```

`Defines.inc` is a Log4D file whose entire content is that include, some
commented-out defines, and the line *"In the moment there are no special defines
for Log4D."* `tr4w.inc` is included by every unit, so JEDI's Delphi
compiler-version detection is preprocessed 426 times per build.

**Checked both ways before calling it dead.** No `{$IFDEF DELPHI…}`,
`COMPILER…`, `SUPPORTS_…`, `RTL…_UP`, `CONDITIONALEXPRESSIONS` or any other
JEDI-produced define is referenced anywhere in the tree — Log4D itself included.
A name-by-name search for the usual suspects (`DELPHI2009_UP`, `DELPHIXE_UP`,
`COMPILER6_UP`, `COMPILER12_UP`, `SUPPORTS_INLINE`, `SUPPORTS_UNICODE_STRING`,
`RTL200_UP`, `HAS_UNIT_ANSISTRINGS`) found no consumer either.

Removing it means removing the `{$I jedi.inc}` line from `Defines.inc`, and
probably `Defines.inc` with it.

### Delphi-era build artefacts — about 95 KB

| file | size | status |
|---|---|---|
| `tr4w/tr4w.dproj` | 23 KB | msbuild project; CLAUDE.md already says editing it does nothing |
| `tr4w/tr4w.dof` | 8.7 KB | D7 options file, same |
| `tr4w/BatchCompile.cmd` | 499 B | retired D7 recipe |
| `tr4w/FullBuild-D12-deprecated.ps1` | 63 KB | kept for reference; **does not work** |

The argument for keeping `FullBuild-D12-deprecated.ps1` was that it records how
the Delphi build was wired. Git history records that too, and a script that
cannot run is the more misleading of the two.

---

## 2. Real shims — each needs a judgement, not a sweep

These bridge two RTLs. Only the FPC half has been compiled since August.

| unit | bridges | note |
|---|---|---|
| **`utils/uJSON.pas`** | Delphi `System.JSON` ⟷ FPC `fcl-json` | **the big one.** Class helpers teaching FPC the spellings the code already used, so ~175 call sites in the four config units did not have to change. That was the right call at the time; half of it is now unreachable |
| `uInet.pas` | `EncdDecd.EncodeString` ⟷ `base64.EncodeStringBase64` | one call site |
| `utils/uRegex.pas` | `PerlRegEx` ⟷ `RegExpr` | |
| `uCRC32.pas` | `System.ZLib` ⟷ `crc` | |
| `utils/uWin32Compat.pas` | declares what FPC's `windows` unit lacks | **genuinely still needed.** Its header argues for keeping the gap in one readable place, and that argument still holds |
| `uGradient.pas` | `GRADIENT_RECT`, `msimg32` | same — a real gap in FPC's `windows`, not a difference |
| `utils/uAnsiStr.pas`, `utils/uFileText.pas` | string and file boundaries | their headers say they **own** the behaviour rather than shim around it. Probably keep; read before touching |

### `ui/lcl/uLCLCoexist.pas` — live, but its premise ended

`InitLCLApplication` and `RunLCLApplication` are called from `uProgramMain`, so
the unit is not dead. It was written so LCL forms could coexist with TR4W's
hand-rolled `GetMessage` loop — and that loop is gone; `Application.Run` has
owned the program since 2026-08-23. The code is real, the **name and the premise**
are historical.

---

## 3. Needs measuring, not assuming

### `src/MMSystem.pas` — 187 KB of Borland's RTL, vendored into our source

The only Borland-copyright file in the tree. Listed in `tr4w.lpr`, and used by
`MainUnit`, `trdos/LogCW`, `trdos/LOGDVP`, `trdos/LOGK1EA` and `trdos/LOGSUBS2`.

**FPC ships its own** — `winunits-base/mmsystem.ppu`, present for i386-win32. So
our copy shadows a perfectly good RTL unit.

Whether FPC's has everything those five units need is a compile experiment, not
a guess: drop the local unit, let the RTL one resolve, and see what fails. Do it
that way round rather than diffing 187 KB by eye.

---

## 4. Looked like shims, are not

Worth recording so the next survey does not re-raise them:

- **`System.UITypes`** — named in five LCL forms' uses clauses. It is **FPC's
  own**, from the `rtl-objpas` package (`system.uitypes.pp`). A keyword search
  for `System.*` flags it as Delphi RTL; it is not.
- **`System.Move`** — four units. That is FPC's `System` unit, qualified.

---

## 5. Not a shim, but it distorts every survey

`tr4w/src/graphify-out/` is untracked local tooling output sitting **inside** the
source tree. It inflated three separate searches while this survey was being
taken — cache JSON containing source filenames matches almost any grep for a unit
name. Move it out of `src/` or exclude it.

---

## Suggested order

1. `jedi.inc` + `Defines.inc` — pure deletion, zero behaviour, largest reduction
   in per-build preprocessing
2. the four Delphi build artefacts
3. `MMSystem` — as an experiment, guarded by a full build and the corpus
4. `uJSON` — the only one with real work in it, and the only one where getting it
   wrong would corrupt a config file

Everything above is reversible except (4), which touches the code path that
writes `settings/tr4w.json`. Treat that one as a change, not a clean-up.
