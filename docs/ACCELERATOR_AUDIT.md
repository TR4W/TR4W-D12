# The accelerator table vs the menu: what they actually say

**Measured 2026-08-17**, Phase 2 of the Win32-to-LCL migration. Regenerate with
`tr4w/test/ui/Dump-Accelerators.ps1`; the comparison method is described at the end.

## Why this exists

A command's keystroke is currently stated **twice**, with no generator keeping them in
step:

* the **`'T'` ACCELERATORS resource** inside `tr4w_eng.RES`, loaded at `tr4w.dpr:1056` and
  applied by `TranslateAccelerator` — this is what actually fires;
* a **caption constant** in `uMenu.pas` (`RC_EXIT_HK = #9'Alt+X'`) concatenated onto the
  menu text — this is what the operator *reads*.

`344ddea9` ("update Alt+O accelerator ID to 10603 in all language files") is what a drift
between them costs. Phase 2 collapses both into one Pascal table carrying id, modifier, key
**and** display text, because `TranslateAccelerator` dies with the message loop and
`TMenuItem.ShortCut` has to be carrying every binding before that happens.

## The numbers

| | |
|---|---|
| accelerator bindings in the binary | **97** |
| menu rows carrying a `_HK` display | 77 |
| exact agreement | **59** |
| same keys, display order differs | 12 |
| real disagreement | **2** |
| menu shows a key with no accelerator | 4 |
| **accelerators no menu row displays** | **25** |

**The 25 is the headline.** Seeding the new table by transcribing the `_HK` constants would
silently lose a quarter of the program's keyboard bindings — `Ctrl+Alt+B` Cabrillo,
`Ctrl+W` WinKeyer, `Alt+0`..`Alt+9` time increment, `Ctrl+O` missing-mults, `Ctrl+T` POTA
repeat, and `Enter` (id 10651, which has no `menu_` constant at all). The plan already knew
about one of these; there are 25.

**So: seed from the dump.** The `_HK` constants are the thing under suspicion and cannot
also be the oracle.

## The 12 that differ only in display order

`menu_windows_*` (ids 10200-10216) spell it `Shift+Ctrl+N`; the table's canonical order is
`Ctrl+Shift+N`. Same binding, and no operator is misled. The unified table should pick one
order and render it consistently rather than preserving both spellings.

## The 2 real disagreements — OPEN QUESTIONS FOR NY4I

Neither is being changed unilaterally: a disagreement means one of the two has been lying
to operators, and only NY4I knows which behaviour was intended.

| id | menu says | actually bound | question |
|---|---|---|---|
| 10317 `menu_alt_p` | **Alt+P** | **Ctrl+Alt+W** | The menu advertises Alt+P, but Alt+P is bound to 10101 (`menu_messages`). Should 10317's caption become Ctrl+Alt+W, or should the binding become Alt+P and 10101 change? |
| 10411 `menu_ctrl_splitoff` | **-** | **Ctrl+-** | The caption omits the modifier, so the menu reads as a bare `-`. Presumably just a caption fix — confirm. |

## The 4 that show a key with no accelerator entry

Three are fine, one is not:

| id | menu says | what is really true |
|---|---|---|
| 10337 `menu_alt_x` | Alt+X | **Benign.** Alt+X is bound to 10002 `menu_exit`, and both arms call `ExitProgram(True)` — pressing Alt+X does exit. Two ids, one behaviour. |
| 10503 `menu_cwspeedup` | PgUp | **Handled in the message loop**, `tr4w.dpr:1589`. Truthful today. |
| 10504 `menu_cwspeeddown` | PgDn | **Handled in the message loop**, `tr4w.dpr:1590`. Truthful today. |
| 10320 `menu_alt_toogleautosend` | **Alt+-** | **DEFECT.** No accelerator entry, no handler in the message loop, nothing else fires 10320. The menu advertises a keystroke that does nothing. The menu item still works when clicked. |

### The Phase 3 hazard this exposes

**PgUp and PgDn are bound by the message loop, not by the accelerator table.** They are
therefore invisible to any tool that reads the `.RES`, and they **die with the loop** in
Phase 3 unless they are carried into the unified table first. The plan did not name them.
Expect others of this shape: the loop's `WM_KEYDOWN` arms are a third place a keystroke can
be defined, alongside the accelerator table and the caption constants.

## Method

`Dump-Accelerators.ps1` maps `tr4w.exe` with `LOAD_LIBRARY_AS_DATAFILE` (it runs nothing),
calls `LoadAccelerators` + `CopyAcceleratorTable`, and decodes `fVirt`. The comparison
parses `menu_* = <id>` from `VC.pas` and the `mrText: RC_X + RC_X_HK; mrId: menu_y` rows
from `uMenu.pas`, with comments and string literals stripped the way the compiler sees them.

Two traps, both of which produced wrong answers on the first pass and are worth knowing:

* **comments.** Reading the raw text counted commented-out rows — `RC_TRANSFREQ_HK` is
  commented out at `uMenu.pas:102` and appeared as a missing constant;
* **case.** `RC_WKmode_HK` is spelled with a lowercase `m`. A case-sensitive search
  reported it as undefined and its binding as unclaimed. Pascal identifiers are
  case-insensitive; always search that way.
