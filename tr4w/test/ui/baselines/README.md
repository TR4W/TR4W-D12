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

The pre-migration state, for Phase 3 to be measured against. Captured at TR4W
**5.0.1** with the corpus config `cqww_ssb_2025_ny4i`.

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
