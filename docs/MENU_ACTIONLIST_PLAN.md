# Menus and shortcuts -> `TMainMenu` + `TActionList`

**Status: PLAN, awaiting NY4I's verification. Nothing started.**
Written 2026-08-26, after Telnet and MMTTY became LCL forms and unblocked it.

## 1. Half of this is already done

`uAccelerators.pas` was built as the prerequisite and says so in its header.
`uAppInputHooks.pas` now drives all ~101 bindings from the `ACCELERATORS` table
through `AddOnKeyDownBeforeHandler`, which is an application-wide key hook with
a veto -- *"which is exactly what an accelerator table is"*. `TranslateAccelerator`
and the message loop are gone, and the keyboard did not go with them.

That is why this is a contained job rather than a rewrite:
**the same table already feeds both the bindings and the menu captions, so the
menu converts on its own schedule.** ROADMAP section 2 records the same
conclusion.

## 2. What actually remains, measured

| | |
|---|---:|
| `uMenu.pas` -- `T_MENU_ARRAY` + `CreateTR4WMenu` | 447 lines |
| `uAccelerators.pas` -- stays, feeds `ShortCut` | 254 lines |
| `ProcessMenu`, one `case menuID of` (`MainUnit.pas` 4415-5335) | **920 lines** |
| `menu_*` id constants in `VC.pas` | 180 |
| Win32 menu API call sites | ~40 |
| menu rows | ~181 |

`CreateTR4WMenu` walks `T_MENU_ARRAY` and calls `AppendMenuW`, using three
sentinel ids for structure: `MAXWORD` opens a top-level popup, `MAXWORD-1` a
submenu, `MAXWORD-2` closes back to the parent.

## 3. The part that is not a rewrite: three id-arithmetic couplings

These are the reason this needs a plan. **A tool window's identity is currently
carried by its menu item's numeric id.**

```
CheckMenuItem  (tr4w_main_menu, 10199 + Ord(ID), MF_CHECKED)     -- on open
CheckMenuItem  (tr4w_main_menu, 10199 + Ord(ID), MF_UNCHECKED)   -- on close
GetMenuStringW (tr4w_main_menu, 10199 + Ord(ID), ...)            -- THE WINDOW'S CAPTION
```

The third is the sharp one: **a window's title is read back out of its menu
item**, tab character onward trimmed. That is why the panadapter cannot become
a `tw_` window today -- a `tw_` entry with no menu row is titled empty -- and
why fixing it here also unblocks giving the panadapter a Windows-menu entry and
an accelerator (`project_next_session_pickup` item 4).

Plus the conditional items: `EnableMenuItem` x11, `DeleteMenu` x5,
`ModifyMenuA/W` (QRZ.ru and WA7BNM calendars, POTA parks, Cabrillo, QTC).
Each becomes a `TAction.Enabled` / `.Visible` / `.Caption` assignment.

## 4. Phases, each ending green and committable

### Phase 0 -- pin today's behaviour first (no product change)

`test/ui/Dump-Accelerators.ps1` is the precedent and it earned its keep: it
found that 25 of 97 bindings were displayed by no menu row. Do the same for
menus before touching one — **and read the rest of its story first**
(`docs/ACCELERATOR_AUDIT.md`, the note at the top). It was deleted 2026-08-29,
because once `uAccelerators` began building the table at run time the tool went
on reading a PE resource that was no longer the live table, and nothing said so.
A dump tool has to be retired, or repointed, by whatever replaces the thing it
reads.

1. `Dump-Menu.ps1` -- walk the live `HMENU` and record every item: id, caption,
   parent path, shortcut text, enabled and checked state at start-up. **This is
   the oracle for every later phase.**
2. `Lint-MenuDispatch.ps1` -- assert that every id in `T_MENU_ARRAY` has a
   `ProcessMenu` arm and every arm has a row. Run it now, before the move: any
   disagreement it reports is a defect that exists **today**, and finding those
   afterwards would look like conversion damage.

*Commit.*

### Phase 1 -- build a `TMainMenu` from the same table

`T_MENU_ARRAY` stays the single source. A second builder emits `TMenuItem`s
instead of `AppendMenuW`, the three sentinels becoming parent/child nesting.
`ShortCut` comes from the same `ACCELERATORS` row that supplies the caption's
shortcut text, so the two still cannot disagree.

Attach it to the main form; delete the `HMENU` path and `SetMenu`. Diff against
the Phase 0 dump: same items, same order, same shortcuts.

*Commit.* At this point the menu is LCL and nothing else has changed.

### Phase 2 -- break the three id couplings

- **Caption.** Stop reading `GetMenuStringW`. A window's caption belongs to the
  window: a `WindowCaption(ID)` sourced from the same `RC_` constant the menu
  row uses. This is the change that unblocks the panadapter.
- **Checked.** `TMenuItem.Checked` through an id lookup, not `CheckMenuItem`.
- **Enabled / Visible / Caption.** The `EnableMenuItem` / `DeleteMenu` /
  `ModifyMenu` sites become property assignments.

*Commit.*

### Phase 3 -- `TActionList`

Every row with a real command gets a `TAction`; the menu item points at it.

**`ProcessMenu` is NOT shredded.** Each `TAction.OnExecute` calls
`ProcessMenu(id)`, exactly as `WM_COMMAND` did. The 920-line `case` is untouched
and the diff stays reviewable. Splitting it into per-action handlers is a
separate, later, *optional* job -- and on its own merits, not as a side effect
of this one.

What `TActionList` buys immediately: enable and check state stop being scattered
Win32 calls, and a toolbar or context menu can reuse an action instead of
duplicating a dispatch.

*Commit.*

### Phase 4 -- the remaining popups, and the sweep

Two Win32 popups are left: `uFunctionKeys.pas:488` (right-click on a function
key) and `MainUnit.pas:10284`. Both become `TPopupMenu` -- the Telnet form
already shows the shape. Then delete `CreateTR4WMenu` and the Win32 menu
imports, and drop the `Lint-Win32Dialogs[ui]` baseline by what this removed.

*Commit.*

## 5. Explicitly NOT in scope

- **Splitting `ProcessMenu`.** See Phase 3.
- **Issue #1004** (Alt enters Windows menu mode and swallows Ctrl, so the
  Alt/Ctrl bank labels misbehave). A `TMainMenu` has the same behaviour -- it is
  a Windows menu either way. Do not expect this to fix it; **do** check it has
  not got worse.
- **`.rc` / `.res` edits.** NY4I's rule: those are done by hand, by NY4I. See
  the open question below.
- **I18N.** Captions stay the `RC_` constants they are today. The
  `resourcestring` move is a separate worktree.

## 6. Traps

- **A number is not a name.** 180 numeric ids, and the compiler checks none of
  them -- the exact class that shipped a broken Telnet window this month
  (`GetDlgItem(hwnd, 102)` against a form with no control 102). Phase 0's lint
  exists for this.
- **`mrText` must stay a `string`.** `uMenu.pas` carries a long note: folded
  into a `PAnsiChar` typed constant, FPC pointed the field at the string
  *descriptor*, so 77 accelerator rows produced four bytes of length and
  refcount as their caption -- and the window titles read back from those items
  came out as garbage, with no warning from either compiler.
- **The captions are the thing under test**, so they cannot also be the oracle.
  Phase 0 dumps from the live binary for that reason.
- **PgUp/PgDn** were bound by the message loop, not by any table. They are
  recorded in `ACCELERATORS` as display-only precisely so they are not
  invisible. Confirm they still work after Phase 1.

## 7. Open question for NY4I

**`Tr4w.rc` contains a complete `T MENU` resource -- 1503 lines -- and nothing
loads it.** `uProgramMain.pas:961` has
`//tr4w_main_menu := LoadMenu(hInstance, 'T');` commented out; the live menu is
`T_MENU_ARRAY` in code. So there are two copies of the menu and only one is
real. The dead one has certainly drifted.

That is a `.rc` file, so it is yours by hand. Options: delete the resource,
leave it as heritage, or diff it first to see whether it records anything the
code copy has lost. **I have not touched it and will not without a decision.**

## 8. Interaction with the `resourcestring` / I18N work

That work is coming from a separate worktree and it lands on **the same
captions**, so the two have to be sequenced deliberately rather than merged
after the fact.

**The collision is not the merge -- it is `T_MENU_ARRAY` being a TYPED
CONSTANT**, whose rows are initialised at COMPILE time from the `RC_`
constants.

Measured 2026-08-26, on FPC 3.2.2 i386:

- A `resourcestring` **does** compile in a typed-constant initializer. I
  expected it to be rejected; it is not.
- **Whether a runtime translation reaches it is UNRESOLVED.** I could not get
  `SetResourceStringValue` / `ResourceStringTableCount` to resolve in a probe in
  this configuration, so I did not prove it either way.

The reasoning says it does not, and the reasoning is strong: a typed constant is
*initialised data in the binary*, so the compiler must fold the constant to its
bytes at compile time; runtime translation replaces the entry in the
resource-string **table**, which only a use-site reference reads. The typed
constant holds a copy of the original. If that is right, then after the I18N
move **every other string in TR4W would translate and the menu would silently
stay English** -- no error, no warning, from either compiler.

**This is the single most important thing for the I18N worktree to verify**, and
the experiment is ten minutes: one `resourcestring`, one typed constant
initialised from it, translate the table at run time through whatever mechanism
that work actually adopts (`gettext.TranslateResourceStrings` is the likely
one), print both.

**If it is confirmed, the ordering follows.** The menu has to stop being a typed
constant and be populated at run time -- which is *precisely* what Phases 1-3
do, because a `TAction` gets its `Caption` assigned. So:

- Do the menu conversion **first**. I18N then finds the menu already in a shape
  that can be translated.
- Do them the other way round and the I18N worktree hits this wall itself and
  has to restructure the menu as a side effect of a translation change -- the
  worst place for it, and with no menu oracle to check against.

Either way, **tell that worktree before it starts.** The two projects share
`src/lang` and `VC.pas`, and Phases 1-3 deliberately do not rename or retype a
single `RC_` constant, exactly so the eventual merge stays small.

## 9. Rough size

Phases 0-2 carry the risk and are perhaps two sessions. Phase 3 is mechanical
once 2 lands. Phase 4 is small. Every phase ends green -- lints, unit tests,
corpus -- and is committed before the next begins, which is the lesson from
Telnet: that conversion failed twice from being attempted in one pass.
