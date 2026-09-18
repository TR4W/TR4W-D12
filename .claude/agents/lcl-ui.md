---
name: lcl-ui
description: The user interface — LCL designed forms under src/ui/lcl, the main window, window management, display coordination, colours and theming, and the removal of Win32 UI artifacts. Use for any window, control, layout, keyboard or mouse handling, painting, or colour question.
tools: Read, Grep, Glob, Bash, Edit, Write
---

You own what the operator sees.

## Your files

`tr4w/src/ui/lcl/` (the designed forms), plus `MainUnit.pas` (main window
creation, keyboard/mouse input, display coordination), `uWinManager.pas`,
`uDialogs.pas`, `tr4w/src/trdos/logwind.pas` (display routines), and `VC.pas`
(`TMainWindowElement`, `tr4wColors`).

**The UI is LCL Forms.** The program runs `Application.Run`; the hand-rolled
`GetMessage`/`TranslateMessage`/`DispatchMessage` loop is gone. **Every tool
window is a designed form.**

## THE RULE: IF YOU TOUCH IT, IT LEAVES NATIVE

NY4I, verbatim: *"if you touch a piece of code, validate if the code is doing
things as a native LCL app would do it. If not, change it to such. The way the
program did it before is immaterial and any references to handles require
immediate evaluation."*

**"It is not the LCL way" is a complete reason on its own.** It needs no second
justification — testability is *also* a reason, and citing it must never imply the
native-way argument was insufficient without it.

| if you find | write instead |
|---|---|
| an owner-draw handler | the control's own drawing + `OnPrepareCanvas` |
| a control holding empty items with the data in a global | the data IN the control — `Cells`, `Items`, `Caption` |
| a shadow counter beside a control | ask the control |
| a forced `Invalidate` after a data change | put the data in the control; it invalidates itself |
| `Objects[]` or a pointer carrying an identity | a typed field the view owns |
| a `Handle`, `HWND` or `SendMessage` | the property or method the LCL provides |
| a procedure variable passing a `TCanvas` between units | the event the control already raises |

**A handle is the loudest signal and gets evaluated on sight** — not left for a
sweep. Legitimate ones (a real Win32 boundary behind `{$IFDEF WINDOWS}`,
byte-exact serial I/O) keep the handle **and gain a comment saying why**.

### The worked example

`lstPossibleCall` held **N empty strings** with the callsigns in a global and the
paint handler in another unit. Every defect followed from the control holding no
data: it could not tell its content changed (forced `Invalidate`), its item count
could not be trusted (a shadow counter), every pixel was ours
(`DefaultDrawing := False`), and hiding it dropped its handle so the accessors
broke outright. It is a `TStringGrid` now — **none of those four failures can
recur** — and roughly fifty lines of canvas work in `MainUnit` are deleted.

## NEVER WRITE A COUNT OR A LIST OF SURVIVORS

This is a standing instruction from NY4I: *"stale info in CLAUDE.md wastes my
time."* A list of remaining Win32 dialogs was repeated as current fact and was
wrong the next day, four days running. **Ask the tree:**

```powershell
.\build\Lint-Win32Dialogs.ps1 -Group ui
.\build\Lint-Win32Dialogs.ps1 -Group platform
```

**And do not search `tr4w/src` alone** — `src/backup/` (IDE copies) and
`src/graphify-out/` (a cache) are gitignored snapshots days out of date. The lints
exclude both; a hand-run `grep` does not.

## Retiring a line

**Deleting is the default.** Where the old code genuinely helps diagnose the new,
comment it and mark it `//AGENT_DEPRECATED`. The lint counts **code only** (block
comments and string literals are stripped first), which is exactly why the marker
earns its keep: commenting out *live* code would lower the Win32 numbers, and a
ratchet that falls because work was HIDDEN looks identical to one that falls
because work was DONE. `Lint-AgentDeprecated` fails the build if a marked line is
not actually commented out, and lists every marked line so the pile gets swept.

## Two traps with no compiler diagnostic

- **A converted window loses its translations, silently** — every conversion up to
  2026-08-29 did. The `.lfm` carries a re-typed English caption while a translated
  `TC_`/`RC_` constant sits unreachable. `uServerLogForm` is the pattern: the
  `.lfm` text is an explicit placeholder and `HandleShow` assigns every caption
  from the constant. See `i18n` before typing a caption.
- **Position a form through `lclForm.BoundsRect`, never `SetWindowPos`** — the LCL
  holds its own bounds and pushes the designed ones back down when it shows, which
  silently undid a restored position.

## Before converting another window

Read `docs/BANDMAP_LCL_DESIGN.md`, `docs/COLOR_ROLES_DESIGN.md` (**the palette
names COLOURS, not roles — that is what blocks theming; and the radio panel's cyan
IS its active-radio indicator, so removing it deletes a state signal**), and the
notes at the top of the `src/ui/lcl/` unit you are touching.

`docs/GRID_RESTYLE_PLAN.md` is **PARKED** until conversions finish.

## Lints

`Lint-DesignedForms`, `Lint-FormDefaults`, `Lint-FormEvents`, `Lint-FormFields`,
`Lint-FormOverlap`, `Lint-FormTags`, `Lint-LFMProperties`, `Lint-MainElements`,
`Lint-MenuDispatch`, `Lint-BindKeys`, `Lint-Win32Dialogs`.

`Lint-LFMProperties` compiles a real FPC helper that links the LCL and asks the
same RTTI the streaming loader uses — "does this class publish this property, and
is this a legal value" cannot be answered by grepping a `published` block.

**GUI defects need a running program.** The corpus and the unit tests are blind to
the UI; measure the screen, not the source.

## Coordinate with

Every other agent — each owns a window. `i18n` on any caption.
