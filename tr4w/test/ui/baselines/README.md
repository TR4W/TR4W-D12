# Window-tree baselines

Captured with `..\Dump-WindowTree.ps1 -NoHandles`, and committed so a form
conversion can be diffed against what it replaced.

## How to use one

```powershell
# before converting a form
.\Dump-WindowTree.ps1 -Command <menu id> -NoHandles -Out .\baselines\<form>.json
# after
.\Dump-WindowTree.ps1 -Command <menu id> -NoHandles -Out $env:TEMP\after.json
```

Then diff. **Diff captions and geometry, not ids.** A converted form's control
ids will not match the Win32 dialog's and are not expected to; what has to
survive a conversion is what the operator sees and where it is.

`-NoHandles` is not optional for anything committed here: HWNDs differ on every
run, so a baseline carrying them diffs as "everything changed".

## What is in `main-window.json`

The main window as it stands, for later phases to be measured against. Captured at
TR4W **5.0.1** with the corpus config `cqww_ssb_2025_ny4i`.

**Re-captured 2026-08-17 after Phase 3a**, which made the main window an LCL `TForm`:
its Win32 class changed from `TR4W` to `Window` and nothing else did. The pre-3a
capture and this one differ in exactly that one field plus the clock/date statics --
same 1012x656, same 103 children, same positions to the pixel. That diff IS the
evidence 3a was behaviour-neutral, and it is in the commit history if wanted again.

The four windows that matter are the `TR4W` main window (103 children), and the
three `#32770` tool windows TR4W opens with it — Radio 1, Radio 2 and Function
keys.

**Three sources of noise to expect when diffing, none of them defects:**

* the main window's caption carries the **version and the contest name**, so a
  release or a different `.cfg` changes it;
* `tooltips_class32`, `DDEMLEvent`, `DDEMLMom`, `MSCTFIME UI` and `IME` are
  created by Windows and the DDE/IME machinery, not by TR4W. They come and go;
* the window layout is **a table times a runtime scale factor** derived from the
  operator's font-size setting, and the log height is measured at run time — so
  geometry is only comparable between captures made with the same settings.
  See the plan's Phase 3 for why the main window will NOT become a designed
  `.lfm`.

## What the baseline does and does not compare (2026-08-18)

`Dump-WindowTree.ps1 -NoHandles` NORMALIZES before writing, and the switch now
means "this is going into a committed baseline", not merely "drop the handles".

The first committed baseline diffed **472 lines against a healthy build**: 466
were absolute screen coordinates, which move whenever the window does
(`tr4w.pos` records its position), and the rest were the wall clock. A baseline
that can never match is not a weak gate, it is an ignored one -- the same
failure as a lint that reports "0 found" and passes.

Normalized away, recursively (the first attempt walked one level and a clock at
depth 3 still flapped):

| field | treatment | why |
|---|---|---|
| `Handle` | blanked | different every run by definition |
| `Left` / `Top` | made relative to the top-level window | keeps *where a control sits in the layout*, drops *where the user last dragged the window* |
| `Text` | `HH:MM` / `HH:MM:SS` masked to `<time>`, and `dd-MM-yy` to `<date>` | clocks only; masking broadly would hide the captions this dump exists to notice |

The DATE mask was added 2026-08-19 for the same reason as the time mask and was
missed the first time: the main window shows `dd-MM-yy`, so a baseline that
masked only clock times still drifted -- just once a day rather than once a
second, which is exactly why it took longer to notice.

`Width` and `Height` are absolute sizes and are left alone.

### The one known flap, deliberately NOT masked

Control **id 104** in the radio-interface window -- the VFO B frequency display
(`MainUnit.pas:5228`) -- flips `Enabled` between runs. Its state tracks radio
connection, and the harness attaches no radio, so the polling thread's
reconnect backoff decides what it looks like at dump time.

It is left unmasked because `Enabled` is real signal everywhere else, and
hiding it would cost more than the two-line diff it produces. **A diff confined
to that one field on that one control is expected; anything else is not.**

### How to compare

There is no `-Compare` switch. Dump and diff:

```powershell
.\Dump-WindowTree.ps1 -NoHandles -Out $env:TEMP	ree-now.json
Compare-Object (Get-Content .aselines\main-window.json) (Get-Content $env:TEMP	ree-now.json)
```

### What still varies, and why the baseline is for STRUCTURE

Some `Text` values reflect the operator's session rather than the program's
shape: band and mode, code speed, the callsign in the entry field, the QSO and
CQ counters. They are deterministic for a given staged config -- two consecutive
runs are byte-identical, which is the check that matters -- but they will differ
against a baseline captured under different conditions.

So when this diffs, **read what changed before assuming a regression**. A
control that moved, resized, vanished or changed `Visible` is the signal. A
counter that went from 1 to 21 is the operator having used the program.

## Comparing against a baseline (2026-08-27)

Reading two JSON files side by side works once and gets skipped by the fifth
window, so the diff is a script now:

```powershell
# YOU start TR4W (see below -- this matters), then:
..\Compare-WindowTree.ps1 -Baseline .\main-window.json -ProcessId (Get-Process tr4w_fpc).Id
```

It exits non-zero on any difference and sorts them into four kinds. **CAPTION**
rows a conversion is allowed to produce; **MISSING**, **ADDED**, **GEOMETRY**
and **STATE** mean a control was lost, gained, moved or greyed, and each one
has to be explained before the commit. `-IgnoreText` compares placement only,
which is what a translated build needs. `-Tolerance <px>` allows for a capture
made at a different font-size setting.

Nodes are keyed by class, control id and sibling ordinal -- deliberately **not**
by caption, because the caption is the thing under test. Keying on it would
report a renamed button as one control removed and another added.

### TR4W has to be started INTERACTIVELY, and the harness attaches to it

Measured 2026-08-27, twice, with a control experiment: a process started from a
non-interactive agent shell gets `MainWindowHandle = 0` and never acquires a
visible window, even after three seconds, while a process the logged-on user
started in the **same session and window station** enumerates fine from that
same shell. So an agent, a service-mode CI runner, or anything else without a
real desktop can RUN the comparer but cannot LAUNCH the subject. Start TR4W by
hand (or from a logon-triggered task) and pass `-ProcessId`.

That is a property of the desktop, not of TR4W, and it is why the window-tree
gate cannot simply be bolted onto the existing `win-ci` job as it stands.

### What it does not catch

Colour, font, z-order, and anything drawn rather than placed in a window. A
converted grid that renders its own cells is a single node here. A pass means
the controls survived, not that the window looks right.
