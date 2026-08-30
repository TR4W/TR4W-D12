# TR4W — Roadmap

**Updated 2026-08-14.** Supersedes `D12_MIGRATION_ROADMAP.md`, which tracked the migration to
Delphi 12 — a migration that succeeded and was then left behind. Named for the *job* rather than the
toolchain, because the last two roadmaps went stale the moment the compiler changed.

Everything struck through below is **done**. Everything else is ranked by what actually blocks the
next thing.

---

## 0. Where we are

TR4W builds with **FreePascal 3.2.2 + the Lazarus LCL**, English, one binary, from a clean clone at
any path on any machine with the toolchain installed. Version 5.0.0.

Measured 2026-08-23, not recalled -- rerun before trusting any of it.

| | |
|---|---|
| Unit tests | **9803 / 0** |
| Phase | **3c done** -- the pivot is behind us |
| Golden corpus | **22 passed, 0 failed, 4 known-divergence** |
| Lints | **21**, gating every build |
| `tw_` tool windows converted | **2 of 17** -- function keys, band map |
| **`HWND` in TR4W's own code** | **644** -- the number that has to reach zero, and the honest measure of this phase |
| Win32 UI call sites (lint baseline) | **234** |
| Win32 non-UI platform call sites | **119** |
| **TR4W's own message loop** | **GONE** -- `Application.Run` since 2026-08-23 |
| Designed LCL forms | **24** |
| Installer | `tr4w_setup_5.0.0.exe`, built from a clean clone |

---

## 1. ~~Migration~~ — done

~~**Phase 1 — compile.**~~ Done, and then done again on a second compiler. The app, `tr4wserver`
and the unit tests all build under FPC; the Delphi 12 path survives only as
`FullBuild-D12-deprecated.ps1`.

~~**Build system.**~~ `FullBuild.ps1` runs lints → unit tests → app → server → installer, in that
order, so a failing test stops the build before it produces a shippable binary. Toolchain is
discovered (`Find-Toolchain.ps1`), search paths defined once (`Get-SearchPaths.ps1`), and
`Test-FreshClone.ps1` re-proves the clone-and-build guarantee on demand.

~~**Lints gate the FPC path.**~~ All nine previously lived only in `tr4w.lproj`'s PreBuildEvent —
msbuild ran them and nothing else did. Now `Run-Lints.ps1`, plus a tenth (`Lint-LFMProperties`).

~~**CI.**~~ `release.yml` and `version-guard.yml` ported. The guard had **stopped firing entirely**
(it triggered on `master`, a frozen fork point). Both release scripts would have pushed into the
**Delphi 7 repository**; branch and remote are now derived from the branch's upstream.

~~**Radio factory.**~~ 100 registrations, one unit per model, capabilities owned by the radio.

~~**CW keyer factory.**~~ Four strategy adapters; no consumer branches on keyer type.

~~**Legacy radio deletion (Track E).**~~ `uRadioPolling` 4,621 → 1,336 lines; `LOGRADIO` holds no
per-model knowledge.

~~**Cluster on Indy.**~~ `TDXClusterClient`, spot parsing extracted and unit-tested, auto-reconnect,
prompt-driven login.

~~**Inline asm.**~~ 600 blocks → **2** (both in `uWinKey.pas`, and both compile at 64-bit).

~~**The four designed forms ported FMX → LCL.**~~ Preferences, radio editor, keyer editor, UDP
destination editor. All four stream clean and are validated by `Lint-LFMProperties`.

~~**`spike/` retired.**~~ It answered "can FPC do this"; the answer was yes.

---

## 2. Win32 dialog replacement — the largest remaining piece

**Why it matters:** TR4W creates its windows from raw `DLGTEMPLATE` structures and `DialogBox`
resource IDs. That is the last part of the program that cannot be edited in a designer, cannot be
laid out by anyone but its author, and blocks any future platform move.

### Phase status — THE tick list, and the only one (2026-08-22)

**Status lives here, not in the plan document.** The plan
(`~/.claude/plans/this-project-has-windows-binary-hammock.md`) is REASONING and is
append-only: it records why the main window cannot be a designed `.lfm`, why 3c must follow
3b, and — its most valuable content — the dated corrections where measurement beat
assumption (*"it is EIGHT handles, not four, and the list was wrong"*, then *"six of those
eight are DEAD CODE"*). Rewriting those to match today would destroy the point of keeping it.

It also **is not in this repository**. It cannot be reviewed in a PR, does not exist on
another machine, and disappears if that directory is cleared. So a tick mark there is not
a record of anything.

**What forced this split:** on 2026-08-22 the plan's Phase 3 body still read as future
work and still carried a blocker marked *"needs NY4I's answer before 3a runs"* — when 3a
was already done and half of 3b with it. Fifteen `STATUS` / `DONE` / `CORRECTED` markers
had accreted through the file. The state was found by grepping the source, which is the
only thing that was actually true.

| Phase | What it is | State |
|---|---|---|
| 0 | Ground truth and guards | **done** |
| 1 | One `ShowXxx` seam per form | **done** — `26f12d7e` |
| 2 | Menus and shortcuts | **done** — menus built in code, shortcuts carried |
| 3a | Main window is a `TForm`; `tr4whandle` = `TMainForm.Handle` | **done** — `uMainForm.pas` |
| 3b | The four input-bearing controls become LCL | **3 of 4** — call + exchange `TEdit` (`89b91cdd`), possible-call `TListBox` (2026-08-22, designed). The editable log is **deliberately not** converted — see below |
| 3c | `Application.Run` replaces the loop | **DONE** — 2026-08-23, `57c278fd`. `tr4w.lpr` lost 220 lines and has no `GetMessage` at all. **Bench queue section 30 is the gate and is unrun.** |
| 4 | The ~25 modal forms | **21 designed** (About converted 2026-08-22). **Three Win32 dialogs left**, all entangled — see below |
| 5 | The three real resource dialogs | not started |
| 6 | The 21 child panels | not started |
| 7 | Retire the scaffolding | not started |
| 8 | The rest of Win32 (non-UI) | not started |

**WHERE THE 644 HWNDs ARE**, because the call counts do not say it and this is
what the next batch should be chosen against: `MainUnit` 96, `TF` 91, `uCAT` 36,
`VC` 33, `uDialogs` 29, `uTelnet` 17, then a long tail over 94 files.
`uCommctrl.pas` and `MMSystem.pas` are excluded from the count and always will
be -- they are translations of commctrl.h and mmsystem.h, where an HWND appears
because Windows says so, and they disappear whole when their last consumer does.

**`tw_` tool windows: 2 of 17 converted** — function keys (2026-08-22) and the
band map (2026-08-23). Measured by counting `WndProcAdr := @` in `MainUnit.pas`:
**15 remain**, sharing 11 dialog procs — dupe sheet ×2, master, telnet, net,
intercom, post-scores, HamScore, stations, remaining-mults ×4, MP3 recorder,
MMTTY. 23 designed forms exist in `src/ui/lcl`.

**3c IS DONE (2026-08-23).** `Application.Run` drives the program; `tr4w.lpr` has no
`GetMessage` at all and lost 220 lines. What the loop carried is in
`src/ui/lcl/uAppInputHooks.pas` — read that unit's header before touching any of it.

**What looked like the blocker, and was not.** LCL's Win32 pump has no message-filter hook,
so `TranslateAccelerator` can never run under `Application.Run`. The obvious conclusion is
that the ~181-item Win32 `HMENU` and its 101 accelerators must become a `TMainMenu` with LCL
`ShortCut`s first. They need not:
`TWinControl.DoKeyDownBeforeInterface` calls `Application.NotifyKeyDownBeforeHandler` for
every control, before focus and before `KeyPreview`, and `VK_UNKNOWN` swallows the key —
which is what an accelerator table *is*. The same `ACCELERATORS` table now drives the menu
captions and the bindings, so **the Win32 menu converts on its own schedule** instead of
being dragged into the pivot.

| the loop carried | now |
|---|---|
| `TranslateAccelerator` | `AddOnKeyDownBeforeHandler` over `ACCELERATORS` |
| keypad CW memories, F10 swallow | the same handler |
| `ShowFMessages` on modifier release | `AddOnUserInputHandler` |
| fault recovery, 10-per-minute | `AddOnExceptionHandler` |
| QuickQSL (`WM_CHAR`) | `TTR4WEntryEvents.EntryKeyPress` |
| `MessageIsForHostedWindow` | nothing — it routed around a loop that is gone |

**Two consequences worth carrying forward:**

* **`uHostedFormWindows` is now WRITE-ONLY.** Eighteen forms still register and unregister
  their handle and nothing reads it. It should be retired; it is left standing only so the
  pivot commit stayed readable.
* **`TelnetWantsClipboardKey` survived**, as a focus test inside the new key handler rather
  than a message test. It is still a raw-HWND dependency and still goes with the telnet
  window.

The historical note is worth keeping: those arms appeared in the loop's `case` only because
the loop collected every message for the thread — they were never main-window work, and
`WM_PARENTNOTIFY` was not an escape (it carries a cursor point, not the child handle, and is
not sent for `WM_RBUTTONDBLCLK` at all).

### OPEN QUESTION for NY4I: should the main window have a `.lfm`?

**The rule (NY4I, 2026-08-22):** *"Your task is not to create LCL forms via code.
It is to create LCL forms via editor file which allows someone to manually edit a
form in the future."* `Lint-DesignedForms` enforces it.

**Measured: 20 `TForm` descendants, 19 designed, one built in code** —
`TTR4WMainForm`. So the rule already holds everywhere except the single place the
plan argued an exception, and it is now a named exception in the lint rather than
a silence.

**The plan's reason is real and still stands:** the main window's 50 elements are
placed at `TWindows[e].mweiX * ws`, where `ws` comes from the operator's font-size
setting and the vertical origin is *measured at run time* from the log's height.
Freezing 50 positions into a designed form would be a regression, not a
modernisation.

**But that argues against designing the CHILDREN, not against the form having a
`.lfm`.** Those are separable, and conflating them is what produced a code-built
form:

| | designed `.lfm` | built in code |
|---|---|---|
| the form's own properties, menu, events | can be edited by anyone | Pascal only |
| the 50 table-driven elements | would be wrong to freeze | correct as-is |
| a NEW control (the possible-call list) | could be designed and repositioned at run time | Pascal only |

A `.lfm` carrying only the form itself would give the main window an editable
identity, let future controls be added in the designer, and leave the placement
loop owning exactly what the table owns. **That looks like the answer, but it
changes Phase 3a's shape and is NY4I's call, not mine.**

**Blocked on this:** the rest of Phase 3b. Converting the possible-call list and
the editable-log ListView means creating two controls — and whether they are born
in the designer or in code depends on this answer. An attempt at the possible-call
list was made in code on 2026-08-22 and reverted unbuilt for exactly that reason.


### Phase 3b's fourth control: the editable log should NOT be a `TListView` yet

**Measured 2026-08-22, before attempting it.** Three of the four input-bearing
controls are LCL: the callsign and exchange `TEdit`s, and now the possible-call
`TListBox`. The fourth — the editable-log ListView — is different in kind, and
converting it the same way would risk the operator's log.

**The reason is the ITEM CACHE.** `TEdit` holds no copy of its text, so TR4W
setting it with `WM_SETTEXT` is invisible and harmless. **`TListView` keeps its
rows in a `TListItems` collection**, and TR4W does not use it — it inserts and
updates rows with raw `LVM_INSERTITEM` / `LVM_SETITEM`. Measured: **~150
`ListView_*` call sites in the tree, 19 of them directly on the editable log.**

So the control would show hundreds of rows while the LCL believed it had none.
That is survivable right up until **anything recreates the window handle** — a
font change, a style change, a re-parent, an explicit `RecreateWnd` — because the
LCL then rebuilds the control **from its cache**. An empty cache means a blank
log, mid-contest, with no error.

**Converting it properly means moving those call sites to the `Items` API**, which
is a large job with a bad failure mode, not a widget swap. It should be its own
piece of work with the log-dump harness (`tr4w/test/logdump/`) verifying rows
survive, not an evening's change.

**The same latent risk exists on the possible-call `TListBox` just converted, and
is tolerable there for a specific reason:** TR4W fills it with `LB_ADDSTRING` and
the LCL's `Items` are likewise empty — but `uCallsigns` and `LOGEDIT` **clear and
refill that list on every keystroke** (`tLB_RESETCONTENT` then re-add). A blank
after a handle recreation would be corrected by the next character typed. The log
has no such refresh: it is the data.

Nothing recreates either handle today — after creation TR4W only sends messages
and uses the raw `tWM_SETFONT`, never the LCL `Font` property. **Worth a bench
eye: if the possible-call list ever goes blank and comes back on the next
keystroke, this is why.**


### The three Win32 dialogs that remain, and why none is a quick win (2026-08-22)

`tDialogBox` had five call sites. One (`SelectFileDlgProc`, 77) is inside a
COMMENTED-OUT procedure and is not a dialog at all. Of the rest:

| dialog | unit | why it is not an evening's work |
|---|---|---|
| **CAT / radio config** (66) | `uCAT.pas`, 2570 lines | The largest dialog in the program and, unlike the others, ACTIVELY MAINTAINED — port enumeration, the filtered COM drop-down, string-id factory radios, `RestartPollingThread`. Converting it is a project, and it wants doing when nobody is mid-change in it. |
| **Missing mults report** (74) | `uMissingMults.pas`, 58 lines | The unit is tiny and misleading: it delegates to `EditableLog.ShowMissingMultiplierReport`, which BUILDS A GRID OF CHILD WINDOWS at run time — 25 rows of coloured cells created into the dialog. The conversion is that grid, not the 58 lines. |
| **Get server log** (73) | `uGetServerLog.pas`, 309 lines | Embeds `CreateEditableLog` — **the very ListView that must not become a `TListView` yet**, for the item-cache reason above. Blocked on the same work. |

**So the next Win32 UI work is not another dialog.** It is either the editable-log
ListView conversion (which unblocks Get server log as well and is the fourth
control of Phase 3b), or `uCAT` as a deliberate project. The band map and the
function-keys window — Phases 6/7, and what actually gates `Application.Run` —
are the other front.


### DECIDED 2026-08-22: the editable-log form waits for the SQLite log

**NY4I asked the right question -- "does it make sense to do the edit log form
after the log is converted to sqlite3?" -- and the answer is yes, for a reason
stronger than convenience.**

**The ListView is currently the MODEL, not a view.** Three sites read QSO data
back OUT of the control:

```
LOGEDIT.PAS:1380   ListView_GetItemText(wh[mweEditableLog], Entry, ...)
LOGEDIT.PAS:1449   ListView_GetItemText(wh[mweEditableLog], Index, Ord(logColCall...
uQuickEdit.pas:68  ListView_GetItemText(wh[mweEditableLog], 1, ColumnsArray[...]
```

The rows live in the widget. That is the whole problem, in three lines.

**Converting before SQLite is the expensive order, twice.** Porting the ~150
`ListView_*` call sites to the LCL `Items` API is the SAME control-as-model
shape, respelled: it keeps the cache-desync hazard (the LCL's `Items` become the
store), it is a large mechanical change with a bad failure mode, and the SQLite
move would then throw all of it away.

**Converting after SQLite produces a different and better result.** The natural
LCL shape becomes a VIRTUAL list -- `OwnerData := True` plus `OnData` -- which
holds no rows at all and asks for row N on demand. That:

* **deletes the item-cache problem by construction.** No cache, so the blank-log
  failure mode cannot occur;
* **deletes the three read-back sites**, because there is finally somewhere real
  to read a callsign from;
* handles a 5,000-QSO log without inserting 5,000 items into a widget.

`OwnerData` appears NOWHERE in this tree today, so the pattern is unexplored
either way. Better to explore it once, against a real model.

**What deferring costs, measured rather than assumed:**

* **`Application.Run` is NOT blocked.** Phase 3c is gated on the band map and the
  function-keys window. The log has nothing to do with it.
* **Only `Get Server Log` (dialog 73) is blocked**, because it embeds the same
  control.
* Phase 7's no-HWND end state needs it eventually, and Phase 7 is last anyway.

**Consequence for the SQLite log itself:** section 7 listed it as "decided
direction, not scheduled". Still unscheduled -- but no longer OPTIONAL, because
two pieces of the LCL migration now queue behind it.

**So the order is:**

1. **Band map + function-keys window** -- these gate `Application.Run`, the pivot
   the whole plan turns on.
2. **`uCAT`**, as a deliberate project, when nobody is mid-change in it.
3. **Editable log + Get Server Log, after the log is SQLite**, as one piece of
   work built on a virtual list.


### The function-keys window: the FIRST `tw_` conversion, and the pattern for ~20 (designed 2026-08-22)

**Why this one first:** it owns two of the three loop arms that gate
`Application.Run` (`WM_RBUTTONDBLCLK` -> `GetButtonByRDblClick`,
`WM_RBUTTONDOWN` -> `ShowFunctionKeyContextMenu`, both in `tr4w.lpr` ~1319).
The band map owns the third. Nothing else about Phase 3c is outstanding.

**Why it needs a design note rather than just doing it:** no `tw_` tool window
has been converted yet. `OpenTR4WWindow` creates all twenty the same way, from
`tr4w_WindowsArray[ID].WndProcAdr` via `CreateDialogParam`. The seam chosen here
is the seam nineteen more windows will use. And this window sends CW: a mistake
in it is F1 not answering a CQ, mid-contest.

**The good news, measured: the owner-draw maps to plain LCL properties.** The
`WM_DRAWITEM` body (`uFunctionKeys.pas:120`) does three things — `DrawEdge` with
`EDGE_SUNKEN` or `EDGE_ETCHED`, a `GradientRect` with the SAME colour at both
ends (so a flat fill), and centred text. That is a `TPanel`:

| today | becomes |
|---|---|
| `BS_OWNERDRAW` button + `WM_DRAWITEM` | `TPanel` |
| `GradientRect(..., TempColor, TempColor, ...)` | `Color := ButtonsColor[i]` |
| `DrawEdge(EDGE_SUNKEN / EDGE_ETCHED)` | `BevelOuter := bvLowered / bvRaised` |
| `ButtonsText[i]` + `DrawText` | `Caption` |
| `WM_COMMAND` / `BN_CLICKED` | `OnClick` |
| loop arm `WM_RBUTTONDBLCLK` | `OnMouseDown` with `mbRight` and `ssDouble in Shift` |
| loop arm `WM_RBUTTONDOWN` | `OnMouseDown` with `mbRight` |
| `ResolveFunctionKeyRow(h)` scanning `KeysHandles[112..123]` | `Sender.Tag` |

**No custom painting survives.** That is the whole point: porting the GDI would
carry Win32 into the replacement.

**The seam for `OpenTR4WWindow`.** One `if ID = tw_FUNCTIONKEYSWINDOW_INDEX`
before the `CreateDialogParam`, returning the LCL form's `Handle` — the same
strangler shape `CreateTR4WMainForm` used for the main window in Phase 3a, and
the same shape the next nineteen get. `tr4w_WindowsArray[ID].WndHandle`,
`WndVisible` and `WndRect` keep working because they only ever held a handle and
a rectangle.

**What must NOT change, and each is a trap:**

1. **`ButtonsText[i]` keeps its doubled `&`.** `ShowFMessages` inserts a second
   ampersand (`uFunctionKeys.pas:312`) so the owner-draw shows one. A `TPanel`
   caption treats `&` the same way, so the doubling stays correct -- removing it
   because "the LCL is different" would eat every ampersand in a CW message.
2. **The layout is runtime, not designed.** `WM_SIZE` spreads the twelve buttons
   across the width with a 10px gap after F4 and F8. Declare the panels in the
   `.lfm`, position them in code -- the same rule the main window settled on.
3. **`OpMode2` vs `OpMode`.** `ShowFMessages` reads `OpMode2` for the CQ/S&P
   bank; the resolver reads `OpMode`. That difference is deliberate and
   pre-existing. Do not "tidy" it.
4. **The bank is read from the LIVE modifier state** at right-click time and must
   be captured BEFORE the menu pops, because the operator releases Ctrl/Alt to
   click it (Issue #1001, already commented in the source).

**Verification available:** none of this is provable by build. `Lint-AppMessages`
will show the two arms gone; the rest is bench -- F1..F12 send, Ctrl/Alt banks
show the right text, right-click opens the editor on the right row, and the
window still docks where it was.


### The band map: DONE (2026-08-23), and what it cost to find out

**It is an LCL form** -- `src/ui/lcl/uBandMapForm.pas` + `.lfm`, a `TDrawGrid`
with a `TStatusBar` and a designed `TPopupMenu`. `uBandmap.pas` went 830 -> 237
lines and holds `TuneRadioToSpot` and three settings. The design, and the
reasoning behind every decision in it, is
[`BANDMAP_LCL_DESIGN.md`](BANDMAP_LCL_DESIGN.md) -- read that before touching
either file.

**Two things this conversion should be remembered for:**

**1. It was a redesign, not a port, and the first plan was wrong twice.** The
first draft said "keep the owner-draw list box, port `WM_DRAWITEM` to
`OnDrawItem`". Reading the ingest path afterwards found seven defects that a
port would have carried across -- spots silently DISCARDED while the window had
focus, a row payload that was an index into an array that shifts under it, a
parsed QSX frequency displayed nowhere, a multiplier recomputation on the paint
path. The second draft then laid the spots out as a TABLE of field columns. It
is a **newspaper layout** -- the Win32 control was a MULTI-COLUMN list box, so
widening the window shows MORE SPOTS, not wider ones. Fifty-odd at once on a
1280px window against the eight a table would show. **NY4I's screenshot is what
caught it**, after two rounds of reading code.

**2. The bench found five defects that no lint or test could.** A `.lfm`
declaring four status panels against code indexing six -- which threw from
`OnCreate`, so the CONSTRUCTOR never completed and the symptom was a dead window
rather than a wrong status bar. A form shown by raw `SWP_SHOWWINDOW` whose
`TForm.Visible` therefore stayed False, so its refresh timer skipped every tick
and the LCL never showed its children. That one **had already been found once**,
for the main window -- the note is on `ShowTR4WMainForm`. `OpenTR4WWindow` now
tells the LCL for whichever form the seam built, so the next conversion inherits
it.

**The lesson for the remaining fifteen:** the seam and the mechanics are proven
twice over now, but *what the Win32 control actually does* is not learnable by
reading the drawing code. Ask for a screenshot before designing the replacement.

### The numbers, and why they are quoted from the lints

Prose status decays; a ratchet does not. These come from `Run-Lints` on every build, so a
stale figure here sits visibly beside a fresh one:

```
Lint-Win32Dialogs[ui]:       236 Win32 UI call site(s) across 435 file(s)
Lint-Win32Dialogs[platform]: 120 non-UI Win32 platform call site(s)
Lint-SettingsMigration:      227 stored, 3 still on the ini (ceiling 3), 252 seeded
Lint-IniUsage:               11 known site(s), all one-time seeding
```

The UI mass is the main window, not the dialogs: `SetMainWindowText` 66,
`tCreateStaticWindow` 27, `TF.CreateStatic` 24, `CreateWindowEx` 22, `TF.CreateButton` 22 —
343 of the 356 total sites are those five kinds plus the platform top four.


### TODO: 1,427 narrowing string conversions, and a ratchet holding the line (2026-08-28)

NY4I asked whether the `AnsiString` event-signature trap was a general issue. **It is**, and this
is its size. `tr4w.inc` makes `string` UnicodeString for all 426 units, while the TRDOS core still
declares bounded ShortStrings and the LCL and the Win32 boundary speak `AnsiString`. Every
assignment across that line converts, and the compiler names the ones that can lose something:

| direction | count | what goes wrong |
|---|---:|---|
| widening — Ansi/Short/CallString to Unicode | ~2,530 | nothing; noise |
| **narrowing to a bounded ShortString** | **401** | **truncates** past the declared length |
| **narrowing to AnsiString / TTranslateString** | **999** | non-ASCII goes through the ANSI codepage |

The second row is the mojibake class already fixed twice by hand — `WinAnsi` (`9f388029`) and the
log-grid headers (`45dc430c`). The third is how `ceOperator` became `N` (`1e53f410`).

**Where they are:** `uRadioConfigStore` 147, `uPrefsForm` 124, `MainUnit` 68, `FCONTEST` 54,
`uRadioConfigApply` 43, then a long tail. Truncation risk concentrates in TRDOS (`FCONTEST`,
`LOGSTUFF`, `LogCW`, `LOGEDIT`, `tree`); codepage risk in the config and UI units.

**There is no single idiom to fix.** Measured by reading the source line behind every warning:
`SameText` 213 (15%), `Format` 36, `Pos` 35, `IndexOf` 25, `Trim` 19 — and **1,096 (77%) are
assorted assignments**. So this is a pass over ~1,100 sites, not a clever one-liner.

**The cheapest first cut is `SameText`.** FPC 3.2.2's `SysUtils.SameText` has NO UnicodeString
overload — reproduced in a nine-line program — so every call from a UnicodeStrings unit narrows
both arguments. One `inline` overload in a unit everything already uses would fix 213 sites with no
call-site edits, but it resolves by USES ORDER, and this program already depends on use-order for
name resolution (see the note on `uProgramMain`'s uses clause). That makes it a deliberate change
with a test, not a drive-by.

**Held at 1,427 by `Build-App.ps1`** (`$NARROW_CEILING`), the same bargain the Win32 baselines make:
the number cannot grow, and every fix lowers it. NY4I, 2026-08-28: *"I am all for getting to zero
warnings."* That is the target; the ratchet is what makes progress toward it visible instead of
theoretical.

---

### TODO: one pattern for remembering what the operator resized (NY4I, 2026-08-28)

> *"If a user resizes something (grids included) saving it and restoring it drastically increases
> usability of a program."*

**Not a feature request for one grid — a rule the program does not yet have.** Today the answer
differs everywhere it is asked:

| What the operator resizes | What happens next time |
|---|---|
| Editable-log columns | **Remembered** — `SaveColumnWidthToConfig`, `EnsureListViewColumnVisible` |
| Tool-window position and size | **Remembered** — `settings/tr4w.json`, restored by `RestoreToolWindows` |
| Preferences colours grid columns | **Forgotten** — measured once per open (`SizeColorColumns`, `33281dc3`) |
| Band plan grid, dupe sheets, stations, the other converted grids | **Forgotten** |
| Preferences window itself | **Forgotten** |

The first two prove the appetite and the mechanism; the rest were simply never done, and each new
converted window adds another. So the work is a PATTERN, not a pass: one helper that a form can
call to say "these are my resizable things", storing under a key derived from the form and control
name, in the store the window layout already uses.

**Three things to get right, learned from the two that exist:**

* **Restore must not fight the LCL.** Positions are set through `lclForm.BoundsRect`, never
  `SetWindowPos` — the LCL holds its own bounds and pushes the designed ones back down, which
  silently undid a restored position until 2026-08-25.
* **A restore is a refill, and a refill must not look like an edit.** Writing widths back into a
  grid raises the same events an operator would, and this form answers those by writing the model
  (`ca1eb59a`, and the three failed attempts before it).
* **A saved width must survive a font-size change.** Widths measured for one `FONT SIZE` are wrong
  at another, so a stored number needs either a scale or a "measured at" record — otherwise
  remembering is worse than measuring.

Sequence it AFTER the conversions: every window still to convert would otherwise need retro-fitting
twice. `docs/GRID_RESTYLE_PLAN.md` is parked for the same reason and is the natural place for this
to land with it.

---

### The end state, stated plainly (NY4I, 2026-08-20)

> *"Given that we would never write a new Lazarus app this way, this is our goal. We want to get
> completely away from the non-Lazarus way, as that will give us the greatest chance at
> cross-platform capability."*

**That is the criterion, and it is stronger than style.** `WM_*`, `HWND`, `PostMessage`,
`SendMessage`, `CallWindowProc`, `WNDPROC`, `DLGTEMPLATE` — **none of these exist on GTK or
Cocoa.** Every one is a hard portability blocker, not a preference. A file that still speaks them
is a file that cannot compile off Windows, however green it is here.

So the target is the code a person would write if they started this app in Lazarus today, which
means **no window procedure of our own at all** — the LCL owns it, and behaviour hangs off form
and control events:

| What the tree does today | What it becomes |
|---|---|
| `WindowProc` + `TR4WFormSubclassProc` + `IsTR4WsOwnMessage` | nothing — deleted; the LCL's own proc is the only one |
| `WM_COMMAND` → `EN_CHANGE` / `BN_CLICKED` routing | `OnChange`, `OnClick`, `OnEnter` on the control |
| `WM_DRAWITEM` / `WM_MEASUREITEM` | `Style := lbOwnerDrawFixed` + `OnDrawItem`; `ItemHeight` |
| `WM_CTLCOLORSTATIC` / `…EDIT` / `…LISTBOX` | `Control.Color`, `Font.Color` |
| `wh[]` of `HWND`s, `SetDlgItemText`, `GetDlgItem` | control references; `Caption :=` / `Text :=` |
| `PostMessage(tr4whandle, WM_APP+n)` from a worker | `Application.QueueAsyncCall` |
| `SendMessage` for the one case that must block | `TThread.Synchronize` |
| `GetMessage` / `TranslateMessage` / `DispatchMessage` | `Application.Run` |
| `TranslateAccelerator` + the accelerator table | `TMenuItem.ShortCut` |
| `DLGTEMPLATE` + `DialogBox` | designed `.lfm` forms |

**Where a Windows message is genuinely unavoidable** — a shell notification, a device-change
broadcast — the LCL idiom is a *message method on the form*
(`procedure WMFoo(var Msg: TMessage); message WM_FOO;`) inside `{$IFDEF WINDOWS}`. Never a
subclass, and never a shared allow-list two units have to agree about.

**This revises something said earlier in this file.** The eight private thread→UI messages were
described as likely to *survive* Phase 7, on the grounds that cross-thread marshalling is
orthogonal to who pumps messages. The requirement is orthogonal; **the mechanism is not, and it
is the mechanism that is unportable.** They should become `Application.QueueAsyncCall`. The
reason `TThread.Queue` was rejected still stands and still needs checking against the
replacement — `TThread.Destroy` purges a queued callback by thread id, and radio threads are torn
down on every reconnect, which is exactly when a status update matters. `QueueAsyncCall` is not
tied to a thread's lifetime in the same way, which makes it the candidate; **that needs verifying
against the LCL source before anything is built on it**, not assuming.

**The inventory is already done** — `docs/dialog_analysis.md`. Restating its counts against what has
since landed:

| Group | Count | State |
|---|---|---|
| ~~Designed settings forms~~ | ~~4~~ | ~~**Done** — Preferences, radio editor, keyer editor, UDP destination~~ |
| `tw_` modeless tool windows | 20 | Band map, dupe sheets ×2, function keys, master, rem-mults ×5, radio ×2, telnet, net, MMTTY, intercom, post-scores, stations, MP3 |
| Modal / utility dialogs | ~25 | About, edit QSO, log search, sync time, beacons, window control, send spot, QTC send/receive, LPT, WinKeyer settings, auto-CQ, sync log, log diff, select file, … |
| **Main window** | 1 | `MAINTR4WDLGTEMPLATE` — a binary `DLGTEMPLATE` record hardcoded in `VC.pas`, no `.RES` entry anywhere |

**Two things in `dialog_analysis.md` need re-reading now that the toolchain changed:**

1. It says *"extract from Russian/Spanish `.RES` → generate `.dfm` skeletons"*. Under FPC the target
   is **`.lfm`**, and there is no `.dfm` importer. The four forms already ported went FMX → LCL by
   hand with a converter; the same shape of work applies, but the *source* is a Win32 dialog
   template rather than an FMX form.
2. Its central insight still holds and is worth restating: **the English `.RES` is missing almost
   every template** (only Edit QSO 46, Radio/CAT 66 and Sync Log 73 are present). The other ~38 live
   in the non-English `.RES` files. So the layouts *do* exist — just not where you would look first.

**Suggested order** (cheapest proof first, riskiest last):

1. **A small modal with an English template** — Edit QSO (46) or Sync Log (73). Proves the
   Win32-dialog → `.lfm` path end to end against a dialog whose layout is already in the English
   resource. One form, one `DlgProc`, no cross-window state.
2. **The remaining modals**, in ~5-dialog batches. These are self-contained: show, collect, close.
3. **The `tw_` tool windows.** Harder — they are modeless, persist across the contest, and their
   positions are saved (`EnsureRect`, `tr4w.pos`). The window manager (`uWinManager`) and the
   coexistence layer (`uLCLCoexist`) both have to keep working.
4. **The main window, last and on its own.** It is not a dialog in any meaningful sense — it is the
   contest UI, it is what `LOGWIND` paints into, and `TMainWindowElement` (~60 elements) addresses
   it by index. Nothing else should be in flight when this moves.

**Before any of it:** the LCL coexistence layer is proven for *modal-ish settings dialogs* only.
A `tw_` tool window that must live alongside TR4W's own `GetMessage` loop for a whole contest is a
different claim, and worth proving with one window before committing to twenty.

**AND A HARDER PREREQUISITE, MEASURED 2026-08-19: the tool windows are written from WORKER
THREADS, and LCL controls are not thread-safe.**

This is not a guess about one window; it turned up independently in two of them while scoping:

- **RadioInterface 1 & 2** — `uRadioPolling.pas` calls `SetDlgItemTextA(rig^.tRadioInterfaceWndHandle, ...)`
  at `:351`, `:593`, `:594`, `:643` and around `:1034`. Each radio runs its own reading thread
  (`tRadioInterfaceThreadHandle`), so those writes are cross-thread.
- **Sync log (dialog 73)** — `uGetServerLog.RunSyncThread` writes the byte, record and QSO counters
  and fills the list view directly, from the download thread. The unit's own Issue #912 comment
  already says Win32 controls need their creating thread and marshals the *replace* step for that
  reason; the progress updates were never marshalled.

Win32 lets this pass because `SendMessage` marshals across threads for you. **The LCL does not.**
A converted panel poked from a radio thread will corrupt or crash, and it will do so
intermittently and under contest load rather than on the bench.

So the real next piece of work is **one marshalling seam** — a small "update this panel's field"
call that is safe to make from any thread and lands on the main one — shared by the panels a worker
writes DIRECTLY. Build it once, prove it with RadioInterface (the smallest panel, 63 lines), and
dialog 73 and Telnet's status writes stop being blocked. Converting a panel first and discovering
the threading afterwards is the expensive order.

**THE MECHANISM IS A POSTED MESSAGE, NOT `Synchronize` AND NOT `Queue`**, and this codebase has
already paid for that answer twice:

- Nothing in TR4W calls `CheckSynchronize`. `TThread.Queue` works at all only because `Forms` hooks
  `WakeMainThread` and that message reaches the LCL through the hand-rolled loop's fall-through
  `DispatchMessage` (`uRadioEditForm.pas:1216`). That is load-bearing on the very loop Phase 3/7
  deletes — a poor thing to add twenty new dependencies on.
- **A queueing thread that exits purges its own callback** (`uMainWindowProc.pas:617`). Radio
  threads are torn down on every reconnect, which is exactly when an update would vanish silently.
- `Synchronize` blocks the worker until the main thread services it — a latency and deadlock risk on
  a poll thread, and the reason the TCI path rejected it (it would block an Indy connection thread
  against `TTCIServer.Stop`).

`PostMessage(tr4whandle, WM_..., ...)` is what the TCI apply path already does, and `SendMessage` is
used for the one case that must block (`uGetServerLog`'s replace). The seam should follow them.

**THE BANDMAP IS NOT IN THE BLOCKED SET — IT IS THE MODEL.** Correcting what this section said when
first written: worker threads never touch the bandmap's controls. `uRadioPolling` and `uTelnet` only
set `BandMapNeedsRefresh := True`, and `BandMapRefreshTimerProc` (`MainUnit.pas:2203`) repaints on
the MAIN thread from a 250 ms `SetTimer` callback (`tr4w.lpr:1038`). Converting it to a `TListBox`
changes none of that.

So no — a bandmap update does not marshal per spot, and it must not start. A dirty flag plus one
coalesced repaint at 4 Hz is bounded work however many spots arrive, blocks no worker, and floods no
queue. Every panel converted from here should copy that shape rather than marshalling each field
write; the seam is only for the panels that have no such flag today.

(Separate and still unaudited: whether the SPOT DATA shared between the cluster thread and the main
thread is itself handed over safely. That is a data-race question, not an LCL one.)

**A SEARCH HAZARD THAT PRODUCED THE ERRORS ABOVE, worth knowing before trusting any count in this
section.** `grep -r --include='*.pas'` matches the FILE NAME case-sensitively, and `src/trdos/` uses
UPPERCASE extensions — 27 `.PAS` files against 334 `.pas`. So that glob silently skips the entire
contest engine. It is how `tAddContestExchangeToLog` was undercounted, and on 2026-08-20 it nearly
produced a much worse claim: that `SaveTR4WPOSFILE` had no callers and window positions were never
saved. It is called from `LOGSUBS2.PAS:728` in `ExitProgram`, exactly as in D7.

Use `--include='*.[pP][aA][sS]'` or no glob at all. `.dpr`, `.inc`, `.dpk` and `.lpr` are uniformly
lowercase in this tree and in `C:\TR4W`, so only `.pas` varies today — but the failure is silent, so
do not rely on that.

Re-audited under the correct glob on 2026-08-20, the rest of this section holds: `CreateEditableLog`
really does have four callers, nothing in trdos calls `CheckSynchronize`, and the cluster path really
does only set `BandMapNeedsRefresh` rather than repainting (`uTelnet.pas:1771`, with a comment saying
why). One addition for the panel conversion: `SwapRadios` (`LOGSUBS1.PAS:668-674`) calls
`InvalidateRect` on both radio panels. That is the OPERATOR's thread, so it needs no marshalling — but
it is a raw-HWND call site that becomes the form's `Invalidate`.

**Related scoping note (same date):** dialog 73 also should NOT be converted before the shared
editable-log control is. `CreateEditableLog` has four callers — the main window's editable log,
Log Edit, Log Search and the sync-log dialog — and `tAddContestExchangeToLog` has **seven**, not the
five first written here: `LOGSTUFF.PAS:6213` also renders into `tPreviousDupeQSOsWndHandle`, an
EIGHTH window this section did not list, and `LOGSUBS2.PAS:2953` into the main editable log.
(Corrected 2026-08-20 — the original count came from a `grep --include=*.pas`, which is blind to the
27 UPPERCASE `.PAS` files in `src/trdos`. See the note at the end of this section.) Converting
73 alone would create a second, LCL implementation of the QSO list beside the Win32 one, which is
the copies-drift failure `CLAUDE.md` warns about, on the code that renders the log.

---

## 3. 64-bit — much closer than the old roadmap says

The D12 roadmap called this *"⛔ Not started"*. **Measured 2026-08-14, that is no longer true.**

Building the full application for `x86_64-win64` with the Lazarus-bundled compiler:

```
450 units compiled cleanly
  2 blocking errors
```

| Error | Site | Nature |
|---|---|---|
| `Typecast has different size (4 -> 8)` | `MainUnit.pas:7861` | `lp: integer` holding a pointer — wants `LPARAM` |
| `Call by var ... Got "QWord" expected "LongWord"` | `uSynTime.pas:344` | word-size mismatch on a by-var argument |

Both are one-line fixes. **The asm is not a blocker** — the two surviving blocks are in
`uWinKey.pas`, which compiled at 64-bit without complaint.

The real work is the tier below the errors, which the compiler reports as warnings:

| Count | Warning | Meaning |
|---|---|---|
| 116 | *Conversion between ordinals and pointers is not portable* | the pointer-in-integer surface |
| 36 | `GetTickCount` deprecated, use `GetTickCount64` | mechanical |
| 4 | *Converting pointers to signed integers may result in wrong comparison* | genuine truncation hazards |
| 2 | range-check error on a constant (`2914831322`) | a 32-bit constant that no longer fits |

Plus, statically: **29** `SetWindowLong`/`GetWindowLong` calls that need the `...Ptr` forms (3 already
converted), and **14** `lParam`/`wParam` parameters declared `Integer`.

**Honest reading:** the *compile* is two fixes away. The *correctness* is roughly 120 pointer-width
sites to audit, of which most are probably benign and a few are real. That is a bounded, mechanical
job — days, not months — and it is now a decision about when, not whether.

**Two caveats, one of them now MEASURED AND RETIRED:**

- `uCRC32` must stay byte-identical to the CRCs already written into on-disk logs. **Still owed.**
- ~~Extended-precision float layout differs on x64; anything reading a binary `.dat` written by a
  32-bit build has to be checked.~~ **Checked 2026-08-29 for the log record, and it is safe.**

### The log record is architecture-stable — measured, not assumed

This mattered more than it reads, because `ContestExchange` is a plain `record` — **not `packed`** —
and `SizeOf(ContestExchange)` is used directly as a **file-offset multiplier**
(`MainUnit.pas:7082`, `:7086`, `:7531`). One byte of drift and every existing `.trw` is unreadable
and the golden corpus fixtures stop parsing.

Compiled the same probe against `VC.pas` for both targets:

| | `i386-win32` | `x86_64-win64` |
|---|---:|---:|
| `SizeOf(ContestExchange)` | **376** | **376** |
| `SizeOf(QTHRecord)` | 32 | 32 |
| `SizeOf(TLogHeader)` | 376 | 376 |
| offset `Band` / `Frequency` / `Callsign` | 6 / 16 / 44 | 6 / 16 / 44 |
| offset `QTH` / `NumberSent` / `RSTSent` | 114 / 204 / 208 | 114 / 204 / 208 |
| offset `id` / `sReserved` | 290 / 324 | 290 / 324 |

Identical. The record holds no float and no pointer — enums, ShortStrings and scalars of four bytes
or fewer — so the hand-packing (the `ZERO_nn: DummyByte` fillers) lands the same way on both. The
acceptance test is already written: **run the golden corpus against a 64-bit build.** If those 22
byte-diffs still pass, the on-disk format is proven rather than argued.

**This number has a shelf life — a long one.** NY4I, 2026-08-29: *"ContestExchange is really going
to be completely redone because it's ultimately gonna be in the database"*, and then, correcting the
optimism in that: *"let's not make light of the fact that ContestExchange is everywhere in the
contest logic. Changing that is a pretty significant undertaking, and that of anything is probably a
candidate for a shim more than anything else."*

Measured: **430 references across 34 units** — `LOGSTUFF.PAS` 94, `MainUnit` 60, `LOGSUBS2` 36,
`LOGDUPE` 34, and the ADIF, server, external-logger and HamScore paths behind them. This record is
not a data structure the log happens to use; it is the currency the whole contest engine is written
in. So it is persisted, not replaced — see `SQLITE_LOG_SCHEMA_PLAN.md` §4d.

What the measurement buys is not permanence. It is that **a 64-bit build can read the logs that
already exist**, which is required whether or not the record survives: the SQLite importer has to
read years of operator `.trw` files and the corpus fixtures, and it may well be a 64-bit build doing
it. The last consumer of this binary format is the importer, and this says the importer can be
64-bit.

### Consequence for sequencing: 64-bit and SQLite do NOT depend on each other

The only real coupling between them was this record. Had the layout moved, the honest order would
have been **SQLite first** — because moving the log out of a packed binary format removes the whole
class of problem, and doing the 64-bit binary-format audit first would then be work thrown away.

It did not move, so they are independent and the order is a scheduling choice:

- **64-bit is the smaller and better-defined job** — two compile errors and roughly 120 pointer-width
  sites, "days, not months" — and it is not gated on anything above.
- **SQLite is preceded by the display-state model** (`DOMAIN_LAYER_SEQUENCE.md`), so it has a longer
  runway before it starts.
- The 64-bit DLL set grows by one when SQLite lands (`sqlite3.dll`, alongside HamLib and OpenSSL).
  If 64-bit goes first, ship the 64-bit SQLite from the start and that cost disappears.

---

## 4. Bench re-verification — the block no test can retire

Every radio in `RADIO_BENCH_STATUS.md` was verified **under Delphi**. Since the FPC move, only two
have been re-confirmed:

| Radio | Path | Re-verified under FPC |
|---|---|---|
| Elecraft K4 | network | ✅ 2026-08-13 — connect, AI5, query burst, PONG keep-alives |
| Elecraft K3S | serial COM15 | ✅ 2026-08-13 — polling throughout a session |
| Everything else | — | ❌ Delphi-era evidence only |

Still **unproven on any toolchain**: Icom LAN, Yaesu ASCII, HamLib.

The gate remains **one verified rig per protocol family**, not 100 rigs. Nothing here is provable by
code review, and it is the reason the FMX twins should not be deleted yet.

---

## 5. Smaller, well-defined items

- **The unit tests link the LCL**, transitively via `uCAT` → `uPrefsForm`. A test binary should not
  depend on a UI toolkit; the cut belongs at the `uCAT` seam.
- **`tr4wserver.exe` has no version resource.** `tr4w.exe` gets one from `Version.pas`.
- **`tr4w/tr4wserver/BuildServer.ps1`** is a Delphi-era leftover — delete, or make it call
  `Build-Server.ps1`.
- **Delete the FMX twins** (`src/ui/fmx/`) and `FullBuild-D12-deprecated.ps1` — *after* §4, not
  before.
- **Totals grid is 4 rows** and WFD+digital needs 5; widening overruns the log area. Owed to the
  main-window work in §2.
- **`ActiveCWKeyer` precedence** (CAT → WinKeyer → YCCC → CPU) is an artifact of if/else ordering,
  not a decision. An explicit `CW INTERFACE` config command would make it a lookup.
- **Move the body of `tr4w.lpr` into units, AFTER Phase 3/7** (NY4I raised it, 2026-08-20).
  Measured that day: the file is **1382 lines** -- a 388-line uses clause (338 entries carrying
  an explicit `in '...'` path), one routine (`EnsureCountryFile`), and **~826 lines of program
  body** in a single `begin...end.`: the startup sequence, `/EXPORT`, `/FIELDCHECK` and the
  `GetMessage` loop.

  **The `.dpr` itself does not go away** -- FPC and Lazarus still need a program file, and
  `tr4w.lpi` already names `tr4w.lpr` directly, so renaming it `.lpr` buys nothing. What the
  split buys is four things, none of them cosmetic:

  1. **It is invisible to `src/`-scoped search.** `tr4w.lpr` sits at `tr4w/`, so every
     `grep -rn ... src/` skips the file that lists every unit. That is how a reachability
     question gets the right answer for the wrong reason -- the `unit Help` proof on
     2026-08-20 turned entirely on "it is in none of the 8 `.dpr`/`.lpr` files".
  2. **It cannot be unit-tested.** The startup sequence and both headless modes live in a
     program file; the test binary cannot link one. None of the 9558 tests reach them.
  3. **The message loop is scheduled for deletion** (Phase 3/7, `Application.Run`). In
     `src/uMessageLoop.pas` that is a unit swap; in the program file it is surgery on the one
     source both toolchains share. Hence *after* -- moving code that is about to be deleted is
     wasted motion.
  4. **Two parallel unit inventories.** The `.dpr` uses clause and the `.lpi` `<Units>` list
     are kept in step by hand and nothing checks they agree; adding `uWindowLayoutStore` on
     2026-08-20 meant editing both. A lint comparing the two is small and independent of this
     item's schedule.

  End state: a `.dpr` that reads about `begin RunTR4W; end.`, with the body in
  `src/uStartup.pas` and `src/uMessageLoop.pas` -- at which point the extension stops
  mattering at all.
- **Delete `src/uTrayBalloon.pas` — DECIDED, not inferred** (NY4I, 2026-08-20).
  *"I have thought about that feature but the taskbar is sufficient, and a tray icon is easily
  missed as some do not remember to look in the tray."* So the notification-area icon is not
  wanted, and this stops being a judgement call about unreferenced code.

  State of it, measured the same day: the unit is **compiled and linked** (`tr4w.lpr:373`) but
  **nothing calls it**. Every `uses uTrayBalloon` in the tree is commented out — `LOGSUBS2`,
  `LOGWIND`, `uNet`, `uTelnet` — and there is no live call to any of its four exported routines,
  so the tray icon is never registered. `WM_TRAYBALLON`'s handler in `uMainWindowProc.pas:385` is
  an empty `begin end`, which is why nobody ever noticed: clicking a tray icon that does not
  exist, to reach a handler that does nothing.

  **This one the compiler CAN vouch for**, unlike `HELP.PAS`. That unit is in no program's uses
  clause, so deleting it proved nothing and it was kept. This one is linked, so removing it from
  `tr4w.lpr` and getting a green `FullBuild` is real evidence. Take the `WM_TRAYBALLON` case
  label and its `VC.pas` constant with it, and `Lint-AppMessages` will confirm the allow-list
  entry goes too.

- **Retire the selectable editable-log row count in favour of a resizable log window** (NY4I,
  2026-08-20). Today the number of visible QSOs is a config value picked from a list —
  `ROW_COUNT_ARRAY` in `uCFG.pas`, 5 to 15, into `LinesInEditableLog`. The intent is to drop the
  setting entirely and let the operator **drag the log panel taller**, keeping the fixed-aspect
  regions above and below it as they are. Belongs to the main-window work in §2, because that is
  when the log stops being a hand-placed Win32 child and gains a layout that can express "this one
  grows". Worth noting while there: `NumberEditableLines = 5` in `LOGWIND.PAS` is a **constant**
  that bounds `LogEntryArray`, so it is a separate thing from the selectable count despite the
  similar name — a resizable log has to reconcile the two.

---

## 6. Incoming from elsewhere

- **I18N** — `resourcestring` + one binary per platform, arriving from a separate worktree once
  English is stable. **Do not reintroduce the compile-time language matrix.**

  **It also retires an entire class of encoding bug, which is worth stating because it is not
  what I18N is usually argued for** (NY4I, 2026-08-20). Under `resourcestring` the *default*
  text stays in the Pascal source and every TRANSLATION lives in a `.po` file, outside the
  source tree. If no string literal in `src` carries a byte above 127, the codepage the compiler
  happens to use stops mattering — and the UTF-8 BOM question, which needed a whole lint
  (`Lint-BOM`) and cost six silent losses in a single session, has nothing left to get wrong in
  source.

  The rule that follows is **"no non-ASCII in source"**, not "no need to care":

  * comments may still hold an em-dash and that is harmless — 44 files do it today and compile
    perfectly, because a comment never reaches the binary;
  * genuinely non-ASCII DATA (a degree sign, a protocol byte) should be written as a Pascal
    escape — `#176`, `#$B0` — so the file stays ASCII and the intent is explicit;
  * the `.po` files inherit the discipline instead: UTF-8, no BOM, the same rule the JSON
    settings file already follows. One clear rule in one place, rather than per-file state
    spread across 435 files.

  **Then `Lint-BOM` can gain the rule it could not have on day one.** "Non-ASCII in a string
  literal, in a file without a BOM" was measured on 2026-08-20 and rejected as a gate: 13 files
  violate it *today*, and a gate that cannot pass when it is written cannot be wired into the
  build. The I18N migration is what clears those 13, at which point the rule becomes a hard error
  and the guarantee is provable rather than hoped for.

  **A concrete instance of the damage, already realised and already shipped.**
  `src/uCbrSum.pas:230` hardcodes a RUSSIAN button caption — the Ermak-spec Operators button —
  directly in a general unit rather than through `TC_`/`RC_`. Its bytes are now `EF BF BD` seven
  times over: U+FFFD, the replacement character. The Cyrillic was destroyed when the file was
  read in the wrong codepage and saved, and no decoding recovers it. The D7 tree holds the
  identical byte sequence at `uCbrSum.pas:205`, so the loss happened upstream, before this port.
  `src/uErmak.pas` carries 16 more non-ASCII literals in a file with no BOM and should be checked
  in the same pass.
- **`win-ci` runner** — being set up. Start with `version-guard.yml`: no toolchain, so it proves the
  runner connection by itself.

---

## 7. Explicitly not on this roadmap

- **SQLite log storage.** Decided direction, not scheduled -- but **no longer optional**, and it
  has moved from "someday" to "a dependency". Reconfirmed by NY4I 2026-08-22, and section 2 now
  queues **the editable-log form and Get Server Log behind it**: converting that ListView before
  the log has a real model would mean porting ~150 call sites to a shape SQLite then discards.
  Binary `.dat` compatibility is a one-time converter, but the corpus reads 13 such fixtures and
  would have to move with it.
- **The contest factory.** The radio and CW keyer factories are the model for how it should be built
  (strangler pattern, prove the seam, then delete the legacy path). Not started.
- **macOS / Linux / ARM.** Native builds per platform on NY4I's own runners; no cross-toolchain. The
  LCL makes this reachable in a way FMX did not, but nothing has been attempted.

---

## 8. Suggested order

**Revised 2026-08-24**, after the window conversions.  The ORDER of the three
big architectural pieces is decided and lives in
[`DOMAIN_LAYER_SEQUENCE.md`](DOMAIN_LAYER_SEQUENCE.md); it is not restated here,
so there is one place to change it.

1. **BENCH WHAT IS ALREADY IN.**  Queue sections 27-38 are unrun, and 37 -- the
   main window's forty-two elements -- is the largest visible change the program
   has had.  Nothing else should start before this.
2. **The network window**, which is a TRANSPORT job before it is a UI one: its
   HWND is the `WSAAsyncSelect` target (`uNet:745`), it carries the reconnect
   timer, and it subclasses itself for custom draw.  The socket comes off
   `WSAAsyncSelect` first; the window converts afterwards and is then trivial.
3. **The domain layer, in the order that document sets out** -- display state,
   then SQLite, then the contest factory.  Started 2026-08-24.
4. **`Lint-DomainPurity`** ships with the first domain unit, not after it.
5. **Editable log + Get Server Log**, which fall out of the SQLite step as a
   virtual list rather than being a project of their own.
6. **`win-ci` runner** -- unblocks automated release; small, and still not done.
7. **`uCAT`**, as a deliberate project, when nobody is mid-change in it.
8. **64-bit, when wanted** (§3) -- a decision now, not a project.

**No longer on this list:** the tool windows (done -- function keys, band map,
stations, both dupe sheets, SCP, all five remaining-multiplier windows) and the
main window itself (done 2026-08-24).  `uHostedFormWindows` went with them.
