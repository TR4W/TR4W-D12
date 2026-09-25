# Accelerators: moving dispatch off the global key hook

**Status: PLANNED, not started. Written 2026-09-15**, when NY4I asked for the
work he had deferred on 2026-09-07 *"close to last of the hwnd references"*.

**The precondition he set is met, measured rather than assumed:** live `HWND`
mentions are **9 across 4 units** (comment-stripped count over `tr4w/src`), down
from the 19 that stood on the day he deferred this.

This extends [`ACCELERATOR_AUDIT.md`](migration_interim_artifacts/ACCELERATOR_AUDIT.md), which is the
authority on WHAT the table binds. This document is about WHERE the table is
answered, and nothing here changes a single binding.

---

## The complaint, in NY4I's words

> *"on many dialogs, CTRL-C, CTRL-V, CTRL-Z do not work. Those are standard
> windows commands. But they are also main window accelerators. When not in the
> main window, I would like these commands to work."*

He also named the risk himself: *"I can see there might be a muscle-memory issue
for some ops"*, and asked for an option rather than a silent change.

## What actually happens today

**Written when all 94 rows were answered here. Since 2026-09-25, 20 are** --
the other 74 are `TMenuItem.ShortCut` and the widget set answers them. The
guards below are exactly why those 20 stayed. The rest of this section is
unchanged and still describes them.

`ACCELERATORS: array[0..93]` is read from
`uAppInputHooks.InstallTR4WInputHooks`:

```pascal
Application.AddOnKeyDownBeforeHandler(gHooks.KeyDownBefore, True);   // AsFirst
```

`KeyDownBefore` runs before any control sees the key and consumes what it
matches (`Key := VK_UNKNOWN`). Because it is application-wide, it must carry its
own exclusions, and it has grown four:

| guard | why it is there |
|---|---|
| `Key = VK_F10` | Windows would activate the menu bar mid-QSO |
| keypad `VK_NUMPAD0..9` | CW memories must fire wherever focus is |
| `if TelnetHasFocus then Exit` | Ctrl+C in the cluster window cleared the mult sheet |
| `fsModal` on the active form | ESC and TAB reached the main window INSTEAD of the dialog |
| bare Tab/Escape on any non-main form | the radio editor is not modal, and Tab closed it |

**THE EXCLUSION LIST IS THE DEFECT**, not any one entry. Every new form that
needs an ordinary editing key has to be added to a list in a unit that has
nothing to do with it -- the shape
[`event-handler-pattern`] forbids, and the thing NY4I objected to on
2026-09-07: *"If I look at the telnet form in Lazarus, if I want to see what
actions happen, I look at the events for that form."*

### Which windows lose the editing keys, and which do not

| | how it is shown | Ctrl+C / Ctrl+V |
|---|---|---|
| most dialogs | `ShowModalOverWin32Parent` -> `ShowModal` | **work** -- the `fsModal` guard exits first |
| Preferences | `gPrefsForm.Show` | **eaten** |
| Log Search | `frmLogSearch.Show` | **eaten** |
| every tool window | `ShowWithoutTakingFocus` -> `aForm.Show` | **eaten** |
| Telnet | non-modal | works, via the hard-coded `TelnetHasFocus` exclusion |

The three keys an operator expects, and what they do instead:

| key | id | command |
|---|---|---|
| Ctrl+A | 10400 | `menu_ctrl_sendkeyboardinput` |
| Ctrl+C | 10424 | `menu_ctrl_clearmultsheet` |
| Ctrl+V | 10426 | `menu_ctrl_execute_config` |

**Ctrl+Z IS NOT AN ACCELERATOR AT ALL.** Only Alt+Z is (10318,
`menu_alt_initialexhange`), and nothing in `tr4w/src` handles `VK_Z`. When no row
matches, the hook exits WITHOUT consuming -- so Ctrl+Z reaching a control and
doing nothing has a different cause, and must be diagnosed on the specific
dialog rather than lumped in here. **Do not "fix" Ctrl+Z as part of this work.**

## The LCL's key order, measured in the Lazarus source

`TWinControl.DoKeyDownBeforeInterface` (wincontrol.inc), `TCustomForm.IsShortcut`
(customform.inc) and `TApplication.IsShortcut` (application.inc):

1. `Application.NotifyKeyDownBeforeHandler`  <- **TR4W's table is here today**
2. the focused control's `PopupMenu`
3. **each parent form: its `OnShortCut`, then its `Menu`, then ActionLists**
4. `Application.OnShortCut`, then the active (or modal) form's `IsShortcut`
5. parent forms with `KeyPreview` -> `OnKeyDown`
6. the focused control's `OnKeyDown`

## The change: step 1 becomes step 4

Register `Application.OnShortCut` instead of `AddOnKeyDownBeforeHandler`. Then:

* a form claims the keys it wants in **its own** `OnShortCut` (step 3), visible
  in the designer, on that form;
* anything no form claims still reaches the table at step 4.

**THE FALL-THROUGH IS PRESERVED, AND IT IS THE POINT.** NY4I's own test case:
*"if I am in the radio1 window but I press ALT-O, the accelerator to download the
latest CTY.DAT file runs. That is because the Radio 1 window does not use ALT-O.
Is it possible for us to still send the accelerator key to the main window if not
otherwise handled?"* -- yes: Radio 1 claims nothing, so Alt+O reaches step 4.

**Logging is not at risk.** Enter (id 10651), the F-keys and the keypad CW
memories are claimed by no form, so they keep firing from wherever focus is. That
was his stated reason for pausing: *"let me think about any potential
ramifications to this as it concerns logging contacts during the contest."*

**An earlier version of this proposal was worse.** It suggested
`TMenuItem.ShortCut` on the main menu. Those resolve at step 3 by walking up from
the FOCUSED control, so they fire only when focus is already on the main form --
Alt+O from the Radio 1 window would have stopped working. Use
`Application.OnShortCut`.

> **THAT REASON IS WRONG, MEASURED 2026-09-25, and the right one is stronger.**
> `TApplication.IsShortcut` does not stop at the active form: when the active
> form does not claim the key it asks **the MAIN FORM's menu**
> (`application.inc:2157-2162`). So Alt+O from the Radio 1 window works
> perfectly well as a `TMenuItem.ShortCut`, and 74 rows are one since that date.
>
> What a `ShortCut` genuinely cannot do is be **declined for one window**, and
> that is exactly what this document's guards are: Ctrl+A/C/V/X in the cluster
> window and on dialogs, and bare Tab/Escape on a non-main form. Those keystrokes
> therefore stay with the hook -- all five have menu rows, so a naive conversion
> would have reopened Issue #23 and the 2026-09-09 radio-editor defect in one
> commit. The split is `uMenu.AcceleratorRowBelongsToTheMenu`.
>
> **The move below is still open and still worth doing.** It is what would let a
> form claim a key in its own `OnShortCut`, which is the only thing that could
> bring those last rows across.

### What the move does NOT fix by itself

Step 4 is still ahead of the focused control's `OnKeyDown` at step 6. **An edit
control does not get Ctrl+C merely by being focused.** A form must claim the key
explicitly. So the move is the mechanism; the option below is the policy.

### "CLAIM THE KEY" MEANS "DO THE WORK YOURSELF" -- measured 2026-09-25

This is the sharp edge, and it decides whether the last five menu items can ever
show their keystroke in the shortcut column.

`TShortCutEvent` gives a handler one bit, and **neither value means what is
wanted here**:

| | |
|---|---|
| `Handled := True` | the key is **consumed** -- `wincontrol.inc:5888` does `if IsShortCut then Exit` with `Result := True`, so the focused edit never sees it |
| `Handled := False` | processing continues **into the menu**, and a `TMenuItem.ShortCut` fires |

There is no third value, and blanking `Message.CharCode` is not one either: the
record is passed by reference from `CNKeyDown`, so the control loses the key too
— and a `CharCode` of 0 with no modifier computes to `scNone`, which
`TMenu.FindItem` happily matches against **every unbound item** (`menu.inc:217`).

So a key held by a menu item can only be declined by **consuming it and
performing the control's action by hand** -- `CopyToClipboard`, `PasteFromClipboard`,
`SelectAll`, `SelectNext` for Tab, `ModalResult := mrCancel` for Escape. That is
a real design and Delphi applications do it; it is also reimplementing behaviour
the widget already has, and it **fails open**: anything not covered goes to the
accelerator, so a missed case clears the operator's mult sheet rather than
copying a callsign.

**That is the price of putting Ctrl+A/C/V/X, Tab and Escape in the shortcut
column, and it is a decision about a contest keyboard rather than a rendering
fix.** It is NY4I's to make. Until then those five items show their keystroke in
the caption, inline, and `uMenu` says why beside the rule.

## The option

`Operating.StandardEditKeysOutsideMainWindow` (working name), default **False**
-- today's behaviour, because muscle memory is the stated risk and a silent
change to a contest keyboard is not acceptable.

When True, and the focused control is an edit-like control on a form that is not
the main window, the standard editing keys are left to that control instead of
being dispatched: **Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+A, Ctrl+Z**.

Two places, per [`ADDING_A_SETTING.md`](ADDING_A_SETTING.md):

```pascal
(* 1. uSettingsModel.pas, in TOperatingSettings *)
property StandardEditKeysOutsideMainWindow: boolean
   read FStandardEditKeysOutsideMainWindow
   write FStandardEditKeysOutsideMainWindow;
```

```pascal
(* 2. uSettingsDeclarations.pas, so Preferences shows it *)
RegisterModelSetting('operating.standardEditKeysOutsideMainWindow', ...);
```

The name derives from the property path, and
`test/unit/uTestSettingsModel.pas` freezes the command vocabulary -- **the new
name will fail that test until it is added deliberately**, which is what makes
an invented command visible.

## macOS: a decision, not a port

**There is no Command-key handling anywhere in the tree** -- no `ssMeta` in the
input hook, the accelerators or the menu. `TAcceleratorRow` has exactly three
modifier slots:

```pascal
acCtrl: boolean;  acAlt: boolean;  acShift: boolean;
```

`uAutoCQForm` already records the consequence: *"on macOS ssCtrl is Control and
Command arrives as ssMeta, and TR4W's encoding has only Ctrl and Alt slots"*.

So on a Mac today **Cmd+C reaches nothing**, and the option above could not
express itself either. Three ways out, and this is NY4I's call:

1. **A fourth slot** (`acMeta`) plus a per-platform rule that Ctrl-rows answer
   Command on Cocoa. Truthful to the platform; every row keeps one spelling.
2. **Translate at the boundary** -- map `ssMeta` to `ssCtrl` on Darwin before
   lookup. One line, and it makes Ctrl+C and Cmd+C the same keystroke, which is
   wrong for a Mac operator who expects both to differ.
3. **Leave it.** Accelerators stay Ctrl/Alt on every platform, and a Mac
   operator uses Control. Honest, and it will read as a bug to every Mac user.

**Nothing here should be built on a guess about what a Mac operator expects.**
The GUI has never been run on macOS (see `README.md`), so this waits for a
decision and, ideally, one session on the hardware.

## Order of work

**THE ORDER CHANGED AFTER THIS DOCUMENT WAS WRITTEN, and step 3 landed first.**
Reading the LCL source settled it: `Application.OnShortCut` answers at step 4,
which is still AHEAD of the focused control's `OnKeyDown` at step 6 -- so the
move on its own would not make one editing key work, while reordering dispatch
for every key at once puts F10, the keypad CW memories, Enter/logging, the
Telnet exclusion and the modal ordering in play together. The option needs none
of that: it is one guard, and it does what was asked. So the option shipped
first and the move is still open.

1. **This document.** No code.
2. **The move**: `AddOnKeyDownBeforeHandler` -> `Application.OnShortCut`, with
   `KeyDownBefore` reshaped to the `TLMKey` signature
   (`TShortCutEvent = procedure(var Msg: TLMKey; var Handled: Boolean) of
   object`, forms.pp:509). **The Telnet exclusion becomes `TfrmTelnet`'s own
   handler** -- it already has `KeyPreview` and an `OnKeyDown`, so this is where
   its Ctrl+C belongs.

   **THE `fsModal` AND Tab/Escape GUARDS STAY.** An earlier draft of this
   document said they could go, on the reasoning that a modal form claims its
   own keys at step 3. **That is wrong, and the LCL source says so**
   (`wincontrol.inc:5809-5831`): the step-3 walk consults a parent form's
   `IsShortcut`, which does something only if that form has an `OnShortCut`, a
   `Menu` or an ActionList (`customform.inc:2615`). A plain dialog has none of
   the three, so it claims NOTHING -- and `Application.IsShortcut` then runs the
   application handler BEFORE the modal form gets a look
   (`application.inc:2137-2147`). Escape and Tab would be consumed by the table
   at step 4, BEFORE the dialog is consulted at all -- which is the defect the
   guard was written for: on 2026-08-24 ESC did not close the dialog and the
   main window acted on it, and Tab turned the exchange field green. Removing
   those guards would reintroduce it.
3. **The option**, defaulting to today's behaviour. **DONE** --
   `OPERATING STANDARD EDIT KEYS`, off by default, guarding Ctrl+C/V/X/A when
   the focused control is an edit or combo box on a form that is not the main
   window. It carries NO alias: every Operating setting before it is aliased to
   a flat legacy spelling, and a command introduced today has no history to be
   compatible with, so it is the first `OPERATING <thing>` name in the
   vocabulary. Ctrl+Z is not in it, for the reason given above.
4. **macOS**, only after a ruling.

## What no oracle can tell us

The unit tests (`test/unit/uTestAccelerators.pas`) pin the TABLE -- not empty,
no duplicate keystroke, display text matches the binding, every row has a key
and a command, lookup finds and misses, display-only rows are not installed.
**They do not test dispatch**, and cannot: which handler answers a keystroke is a
UI behaviour with a widget set under it.

So every step above needs a bench pass, and these are the cases:

* Enter still logs a QSO, from the main window AND from a tool window;
* F-keys and keypad CW memories still send, wherever focus is;
* Alt+O from the Radio 1 window still fetches CTY.DAT (the fall-through);
* Tab and Escape still belong to the focused dialog;
* Ctrl+C in the cluster window still does NOT clear the mult sheet;
* with the option ON: Ctrl+C/V in Preferences copy and paste;
* with the option OFF: Ctrl+C in Preferences still clears the mult sheet,
  exactly as today.
