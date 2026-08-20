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

---

## 6. Incoming from elsewhere

- **I18N** — `resourcestring` + one binary per platform, arriving from a separate worktree once
  English is stable. **Do not reintroduce the compile-time language matrix.**
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
