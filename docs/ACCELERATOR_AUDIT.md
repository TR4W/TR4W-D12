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
| real disagreement | **2** — 1 resolved, 1 open |
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

Neither was changed unilaterally: a disagreement means one of the two has been lying to
operators, and only NY4I knows which behaviour was intended. **One is answered below; one
is still open.**

| id | menu says | actually bound | question |
|---|---|---|---|
| 10317 `menu_alt_p` | **Alt+P** | **Ctrl+Alt+W** | **ANSWERED 2026-08-17 (NY4I): "menu alt p should be alt-p"** — the caption is right and the BINDING follows it. Consequence, stated because it is not optional: `Alt+P` is bound to **10101 `menu_messages`** ("Program messages") in all eleven `.RES` files, so 10101 must give it up — two commands cannot both answer one keystroke. 10317 is "Open Fkeys" (`OpenListOfMessages`). **This lands when the Pascal table replaces `LoadAccelerators`**; the binary `.RES` is not being edited. |
| ~~10411 `menu_ctrl_splitoff`~~ | ~~**-**~~ | **Ctrl+-** | **ANSWERED 2026-08-17 (NY4I): "add the ctrl modifier to split menu."** `RC_SPLITOFF_HK` is now `#9'Ctrl+-'`, so the caption states the binding that was there all along. The BINDING did not change — only what the menu claims. |

## The 4 that show a key with no accelerator entry

Three are fine, one is not:

| id | menu says | what is really true |
|---|---|---|
| 10337 `menu_alt_x` | Alt+X | **Benign.** Alt+X is bound to 10002 `menu_exit`, and both arms call `ExitProgram(True)` — pressing Alt+X does exit. Two ids, one behaviour. |
| 10503 `menu_cwspeedup` | PgUp | **Handled in the message loop**, `tr4w.dpr:1589`. Truthful today. |
| 10504 `menu_cwspeeddown` | PgDn | **Handled in the message loop**, `tr4w.dpr:1590`. Truthful today. |
| 10320 `menu_alt_toogleautosend` | **Alt+-** | **DEFECT, and now explained.** No accelerator entry in English and no handler in the message loop — but `ger` and `ukr` DO bind it. The binding was added to two language files and never to English. See the divergence section. |

### The Phase 3 hazard this exposes

**PgUp and PgDn are bound by the message loop, not by the accelerator table.** They are
therefore invisible to any tool that reads the `.RES`, and they **die with the loop** in
Phase 3 unless they are carried into the unified table first. The plan did not name them.
Expect others of this shape: the loop's `WM_KEYDOWN` arms are a third place a keystroke can
be defined, alongside the accelerator table and the caption constants.

## The eleven `.RES` files have diverged from each other (measured 2026-08-17)

NY4I's hypothesis when the Alt+P disagreement was reported: *"that is the code base
diverging perhaps by the accelerators in the I18n res files list of accelerators."*
Right in general, and worth the check — every language `.RES` carries its **own** copy of
the accelerator table, so there are **eleven** tables to keep in step and nothing keeping
them.

| file | bindings | differs from `eng` |
|---|---|---|
| `eng`, `ger`, `ukr` | 97 | — |
| `chn` | 96 | 3 |
| `cze`, `esp`, `mng`, `pol`, `rom`, `rus`, `ser` | 96 | 1 |

What the differences actually are:

* **`Ctrl+T` (10608, POTA repeat) exists ONLY in English.** Ten languages never got it.
* **`Alt+-` (10320, toggle autosend) is bound in `ger` and `ukr` — and in no other file.**
  This *explains the defect reported above*: English advertises Alt+- on the menu and has
  no binding for it, because the binding was added to two language files and never to
  English. It is a divergence, not a missing feature.
* **`Alt+O` moved id and the move did not land everywhere.** `eng` binds it to 10603;
  `chn`, `ger` and `ukr` still bind the old 10311. That is commit `344ddea9`, "update Alt+O
  accelerator ID to 10603 in **all** language files" — it reached eight of eleven.
* **`ger` and `ukr` bind 10310 to `VK_SUBTRACT`** (numpad minus) where English binds
  `Alt+N`.

**This is the strongest argument for what Phase 2 does**: one Pascal table replaces eleven
binary ones, and a drift of this kind becomes impossible rather than merely unlikely.

### But Alt+P is NOT one of these

All **eleven** files agree that `Alt+P` belongs to **10101 `menu_messages`**. So the
disagreement at 10317 is a caption error in `uMenu.pas`, not a per-language divergence —
the hypothesis was worth testing, and for this case the test says no.

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
