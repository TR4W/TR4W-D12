# listboxprobe — what an LCL list box does when its row height changes

```
xvfb-run -a ./listboxprobe        # Linux; it needs a display
listboxprobe.exe                  # Windows
```

Prints what it measured and exits 0. It asserts nothing.

## Why it exists

NY4I resized the DX cluster window on macOS (5.0.16, signed build) and got two
recovered access violations. The first carried a program counter of
`$00730074006F0070` — **not an address**: that is the UTF-16 for `s` `t` `o`
`p`. Text executed as code means a call through a pointer read out of memory
that now holds something else. The build before it logged `EBusError` from the
same window, which on aarch64 is a misaligned pointer. Both are the signature
of a message to a **freed object**.

The suspect was `uTelnetForm.ApplyConsoleScale`, which does two things to the
console when a drag settles:

```pascal
lstConsole.Items.BeginUpdate / Font.Size := n / Items.EndUpdate
lstConsole.ItemHeight := measuredRowHeight
```

A crash needs the right machine. **This asks the cheaper and more decisive
question: does either assignment replace the control's handle and its `Items`
object?**

## What it measured — 2026-09-21

60 rescales of a 7,000-line owner-drawn list, then the same again with the
candidate replacement.

| | gtk2 (x86_64-linux) | Win32 (i386) |
|---|---|---|
| `Font.Size :=` | handle kept, `Items` kept | handle kept, `Items` kept |
| `ItemHeight :=` | **handle RECREATED** | **handle RECREATED** |
| 60 cycles of today's code | 54 recreates, no crash | recreates, no crash |
| `lbOwnerDrawVariable`, no `ItemHeight` | **0 recreates**, rows followed the font (asked 31/25/20/16 → on screen 33/27/22/18) | **0 recreates**, rows **did not follow** — 30 px for all 60 cycles |

Two findings came out of that, and both shaped the fix:

1. **The font change does not recreate anything**, so the `BeginUpdate` /
   `EndUpdate` pair in `ApplyConsoleScale` does not straddle a recreate. That
   was the other suspect and it is cleared.
2. **`ItemHeight` recreates the handle every time** — `TCustomListBox.SetItemHeight`
   calls `RecreateWnd` unconditionally (`customlistbox.inc:484-492`, carrying
   the LCL's own `// TODO: remove RecreateWnd`).

**Neither widget set crashes.** The fault is Cocoa-only, and the reason is in
the Cocoa widget set rather than in TR4W: `FinalizeWnd` frees the strings
object through the base `FreeStrings` (`wsstdctrls.pp:352-356` — the Cocoa list
box does not override it) while `TLCLListBoxCallback.strings` goes on pointing
at it (`cocoawslistbox.pas:29`, `:161`), and the callback is still installed on
an NSTableView that is destroyed only afterwards. Everything Cocoa asks in that
window dereferences a freed Pascal object — `ItemsCount` → `strings.Count`
(`:173`), `GetItemTextAt` → `strings[ARow]` (`:185`), and the selection
handler's `Assigned(lclcb.strings) and lclcb.strings.isClearing` (`:329`),
where `Assigned` is true of a dangling pointer.

**And the Win32 row of that table is why the fix is not the same everywhere.**
A Win32 list box measures an item when it is *inserted* and never again, so
switching every platform to `lbOwnerDrawVariable` would have traded a macOS
crash for clipped text on the platform most operators are on. It is done on
Darwin only, and `uTelnetForm.ApplyRowHeight` carries the argument.

## Building it

No build stage — it is a tool. It links only the LCL, so there are no TR4W
search paths to assemble.

```sh
# Linux
LAZ=/usr/lib/lazarus/3.0
fpc -Mdelphi -Sc -gl -O1 -FUout -olistboxprobe \
    -Fu$LAZ/lcl/units/x86_64-linux \
    -Fu$LAZ/lcl/units/x86_64-linux/gtk2 \
    -Fu$LAZ/components/lazutils/lib/x86_64-linux \
    -Fu$LAZ/packager/units/x86_64-linux listboxprobe.lpr
```

```powershell
# Windows
fpc -Mdelphi -Sc -Twin32 -Pi386 -gl -O1 -FUout -olistboxprobe.exe `
    -FuC:\Lazarus\lcl\units\i386-win32 `
    -FuC:\Lazarus\lcl\units\i386-win32\win32 `
    -FuC:\Lazarus\components\lazutils\lib\i386-win32 `
    -FuC:\Lazarus\packager\units\i386-win32 listboxprobe.lpr
```

It has not been built on macOS, which is the platform it is about. That is not
an oversight — the measurement it makes there would be interesting, but the
crash it is chasing is already accounted for by reading the Cocoa widget set,
and a probe that crashes proves less than a probe that measures.

## What a green run does NOT mean

Running it on gtk2 or Win32 and seeing no crash says exactly one thing: those
widget sets survive a handle recreate. It says nothing about Cocoa, and the
program prints that line itself so a pasted transcript carries the caveat with
it.
