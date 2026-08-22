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

| | |
|---|---|
| Unit tests | **3978 / 0** |
| Golden corpus | **22 passed, 0 failed, 4 known-divergence** |
| Lints | **10**, gating every build |
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

~~**Lints gate the FPC path.**~~ All nine previously lived only in `tr4w.dproj`'s PreBuildEvent —
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
| 3c | `Application.Run` replaces the loop | **blocked** — see below |
| 4 | The ~25 modal forms | **21 designed** (About converted 2026-08-22). **Three Win32 dialogs left**, all entangled — see below |
| 5 | The three real resource dialogs | not started |
| 6 | The 21 child panels | not started |
| 7 | Retire the scaffolding | not started |
| 8 | The rest of Win32 (non-UI) | not started |

**3c is gated on Phases 6/7, not on the main form.** Measured 2026-08-18: what still forces
the hand-rolled loop is the **band map list box** and the **function-keys window's
owner-draw buttons**. They appear in the main loop's `case` only because the loop collects
every message for the thread — they are not main-window work, and `WM_PARENTNOTIFY` is not
an escape (it carries a cursor point, not the child handle, and is not sent for
`WM_RBUTTONDBLCLK` at all).

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
the MAIN thread from a 250 ms `SetTimer` callback (`tr4w.dpr:1038`). Converting it to a `TListBox`
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

**Two caveats that have not gone away:**

- `uCRC32` must stay byte-identical to the CRCs already written into on-disk logs.
- Extended-precision float layout differs on x64; anything reading a binary `.dat` written by a
  32-bit build has to be checked. (The corpus fixtures are exactly such files.)

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
- **Move the body of `tr4w.dpr` into units, AFTER Phase 3/7** (NY4I raised it, 2026-08-20).
  Measured that day: the file is **1382 lines** -- a 388-line uses clause (338 entries carrying
  an explicit `in '...'` path), one routine (`EnsureCountryFile`), and **~826 lines of program
  body** in a single `begin...end.`: the startup sequence, `/EXPORT`, `/FIELDCHECK` and the
  `GetMessage` loop.

  **The `.dpr` itself does not go away** -- FPC and Lazarus still need a program file, and
  `tr4w.lpi` already names `tr4w.dpr` directly, so renaming it `.lpr` buys nothing. What the
  split buys is four things, none of them cosmetic:

  1. **It is invisible to `src/`-scoped search.** `tr4w.dpr` sits at `tr4w/`, so every
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

  State of it, measured the same day: the unit is **compiled and linked** (`tr4w.dpr:373`) but
  **nothing calls it**. Every `uses uTrayBalloon` in the tree is commented out — `LOGSUBS2`,
  `LOGWIND`, `uNet`, `uTelnet` — and there is no live call to any of its four exported routines,
  so the tray icon is never registered. `WM_TRAYBALLON`'s handler in `uMainWindowProc.pas:385` is
  an empty `begin end`, which is why nobody ever noticed: clicking a tray icon that does not
  exist, to reach a handler that does nothing.

  **This one the compiler CAN vouch for**, unlike `HELP.PAS`. That unit is in no program's uses
  clause, so deleting it proved nothing and it was kept. This one is linked, so removing it from
  `tr4w.dpr` and getting a green `FullBuild` is real evidence. Take the `WM_TRAYBALLON` case
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

- **SQLite log storage.** Decided direction, not scheduled. Binary `.dat` compatibility is a
  one-time converter, but the corpus reads 13 such fixtures and would have to move with it.
- **The contest factory.** The radio and CW keyer factories are the model for how it should be built
  (strangler pattern, prove the seam, then delete the legacy path). Not started.
- **macOS / Linux / ARM.** Native builds per platform on NY4I's own runners; no cross-toolchain. The
  LCL makes this reachable in a way FMX did not, but nothing has been attempted.

---

## 8. Suggested order

1. **`win-ci` runner** — unblocks automated release; smallest effort, in flight.
2. **Bench re-verification** (§4) — gates deleting the FMX twins, and gates trusting the release.
3. **One dialog, end to end** (§2 step 1) — proves the Win32 → `.lfm` path before committing to ~45
   of them.
4. **64-bit, when wanted** (§3) — genuinely a decision now, not a project. Two errors and a bounded
   pointer audit.
5. **The main window** (§2 step 4) — last, alone, and only once the tool windows have proven the
   coexistence layer holds for the length of a contest.
