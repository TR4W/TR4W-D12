# FMX inside TR4W's Win32 message loop

**Status: built, compiles, starts — NOT yet bench-verified.** This document is
written *before* the bench session so the session has a checklist. Every claim
below marked **[VERIFIED]** was checked on this machine; everything marked
**[BENCH]** is an open question that only NY4I's station can answer.

Branch: `fmx-coexistence-spike` (stacked on `vcl-removal`).

## Why this spike exists

The radio-configuration work needs a real settings UI — a list of defined
radios, a profile picker, a dozen fields per radio. TR4W has no framework: every
window is raw Win32, built by hand. Writing that dialog in Win32 would be a
large amount of tedious, fragile code that we would then throw away, because the
stated direction is that TR4W moves to FMX and away from the Win32 API.

So the question is not "should the settings dialog be FMX" but "**can** an FMX
window live inside TR4W's message loop at all". If the answer is no, the plan
changes: the settings UI becomes a native Win32 dialog on the same store/apply
layers, which are UI-agnostic by design (see `uRadioConfigStore.pas`).

This is a **hard gate**. Nothing else in the FMX plan proceeds until the bench
checklist below is green.

## The actual problem

`tr4w.dpr` owns a hand-written `GetMessage` loop that inspects nearly every
message before dispatching it:

- it runs the accelerator table,
- it routes `WM_CHAR` into the callsign window,
- it treats function keys as CW memories,
- it treats the numeric keypad as CW memories (when KEYPAD CW MEMORIES is on),
- it gives `'`, `=` and various Ctrl-keys contest-specific meanings.

All of that is correct for the contest UI and catastrophic for a text box in
another window. Type `K4` into an FMX edit and — without a fix — the characters
land in TR4W's Call window; press F1 and TR4W sends CQ.

Note the loop cannot simply ask "does a control have focus". The loop sees
messages for **every window in the process**, and TR4W's own windows are not FMX
windows. The test has to be about which window the message is *for*.

## The fix

`src\ui\fmx\uFMXCoexist.pas`. An FMX form registers its window handle while it
is open; the loop asks, as its **first** question:

```pascal
if MessageIsForFMXWindow(Msg) then
   begin
   goto TransMess;   // plain Translate + Dispatch; skips accelerators AND every case arm
   end;
```

`MessageIsForFMXWindow` walks `GetAncestor(Msg.hwnd, GA_ROOT)` and compares
against the registered handles. The `GA_ROOT` step matters: a message arrives
addressed to the specific child window with focus, and drop-downs and menus get
their **own top-level windows**. Walking to the owning root means one
registration covers the whole widget tree, including a combo box's list.

One test, in one place, closes every leak listed above at once.

## What was built

| File | Durable? | Purpose |
|---|---|---|
| `src\ui\fmx\uFMXCoexist.pas` | **yes** | the message-loop gate |
| `src\ui\fmx\uFMXSpikeForm.pas` | no — throwaway | the test instrument |
| `tr4w.dpr` uses + `Application.Initialize` + loop gate | **yes** | wiring |
| `tr4w.dproj` — `fmx` package, `FMX` namespace, search path | **yes** | wiring |
| `MainUnit` `FMXTEST` command | no — throwaway | opens the spike form |

### Startup

`FMX.Forms.Application.Initialize` is called once, near the top of the main
block, right after `IsMultiThread := True`. It registers the platform services
an FMX form needs in order to create its window. It does **not** start a message
loop and does **not** create a main form.

`Application.Run` is never called. `Application.CreateForm` appears nowhere.
The loop stays TR4W's.

### The spike form has no `.fmx`

It builds its controls in code. A designer form would answer two questions at
once — "does FMX coexist" and "does FMX form streaming work under this project's
settings" — and a failure would not say which. Whether the IDE designer
round-trips a `.fmx` cleanly is worth testing, but separately and after this
passes.

## What is already known

**[VERIFIED] It compiles and links.** Full rebuild green, 460,904 lines, all
three pre-build lints pass.

**[VERIFIED] TR4W still starts.** The main window comes up with its normal title
and the program is alive and idle after 12 seconds. This was the specific worry
about `Application.Initialize` racing the single-instance mutex; it does not.

**[VERIFIED] The golden-master corpus is unchanged** at 22 passed / 0 failed /
4 known-divergence. Linking FMX does not alter any exported log.

**[VERIFIED] The binary grows a lot.** Code size goes from **3,082,700** to
**7,860,748** bytes — FMX costs about **4.8 MB**. For comparison, removing the
VCL first (commit `0be4603e`) is what makes this a one-framework binary rather
than a two-framework one. Worth a decision if installer size matters; it is not
a correctness issue.

## Bench checklist — the gate

Run TR4W normally, **with a radio connected and the cluster up**, then type
`FMXTEST` in the callsign window.

### Does it appear at all
- [ ] The form opens, paints, and is readable at your DPI
- [ ] It can be moved, resized and closed

### Keyboard isolation — this is the whole ballgame
Type into the FMX **Edit** and confirm each stays in the Edit, with TR4W's Call
window unaffected:
- [ ] ordinary callsign characters
- [ ] the QuickQSL character
- [ ] numeric keypad digits, **with KEYPAD CW MEMORIES enabled**
- [ ] `'` and `=`
- [ ] F-keys (must do nothing — must **not** send CW)
- [ ] Ctrl-key combinations
- [ ] repeated Alt-Tab away and back, both directions, then retest

### The contest UI is untouched
- [ ] With the form open, type a call into TR4W's Call window normally
- [ ] F1 sends CQ as usual

### FMX's own machinery
- [ ] Tab / Shift-Tab / arrows / Enter navigate the FMX controls
- [ ] The timer label increments once a second
- [ ] **Queue test** updates its label. *If this one fails, stop* — it means the
      main thread's synchronisation queue is not being drained, so any
      radio/cluster callback marshalling to the UI would hang silently. That is
      the worst failure mode available here, because nothing errors.
- [ ] The combo box drop-down opens and selects (this is the `GA_ROOT` case)
- [ ] Space toggles the check box

### Modal
- [ ] **Show modal child** — observe once and record what happens. `ShowModal`
      runs FMX's own loop, so TR4W's loop is not running while it is up. The
      policy for the real preferences window is **modeless** regardless of the
      outcome; this is for information.

### Stability
- [ ] Open and close the form ten times
- [ ] Exit TR4W with the form open — clean, no AV in `tr4w.log`, no hang
- [ ] Radio frequency updates and cluster spots keep flowing throughout
- [ ] CW sending is unaffected with the form open but unfocused

## Exit criteria

**All green** → FMX is viable; write up the results here and proceed to the FMX
preferences UI. Delete the spike form and the `FMXTEST` command; keep
`uFMXCoexist` and the wiring.

**Any red that cannot be fixed** → stop and reassess. The fallback is a native
Win32 preferences dialog built on the same `uRadioConfigStore` /
`uRadioConfigApply` layers, which were written UI-agnostic precisely so that
this gate failing costs the UI and nothing else.

## Open questions for the bench session

1. Does the **IDE designer** round-trip a `.fmx` under `FrameworkType=None`, and
   does the `.dproj` survive an IDE save with the pinned `DCC_Alignment=8`,
   `DCC_MinimumEnumSize=1` and the three PreBuildEvent lints intact? **Diff the
   dproj after every IDE touch.**
2. Does `Lint-PCharAnsi.ps1` false-positive on FMX-style code under
   `src\ui\fmx`? (It passed on the spike, but the spike is small.)
3. Is the 4.8 MB acceptable in the installer?
