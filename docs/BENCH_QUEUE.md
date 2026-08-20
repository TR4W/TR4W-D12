# Bench queue — what is waiting for a real run

A **living list**, not a log. An item goes in when a change lands that no
automated gate can check, and comes **out** when NY4I confirms it. Items that
pass are deleted from here; if the result is interesting it goes into the
document that owns the area (`RADIO_BENCH_STATUS.md`, `D12_HARDWARE_TEST_PLAN.md`,
`CW_Keyer_Factory_Plan.md`) rather than accumulating here.

**"Does it open" is already covered.** `Invoke-MenuSmoke.ps1` now drives all six
converted dialogs (10111, 10302, 10101, 10104, 10557, 10416) and fails if any of
them does not produce a window -- which proves the `.lfm` streams, the form
constructs and `OnShow` runs without raising. So nothing below is asking whether
a dialog appears; every item is about whether what appears is CORRECT, which is
the part no gate reaches.

**Why this exists.** Every defect NY4I found during the Phase 3/4 conversions was
invisible to the eleven lints, the 9244 unit tests and the golden corpus: a
swallowed menu, invisible entry fields, a double caret, a window collapsed to
400×200, the "most recent configuration" button vanishing, `K3Sio 2` for a radio
named `K3S`, Escape not closing a dialog, a settings field accepting letters, and
a message key written with four bytes of garbage on the end. The gates are good
at what they cover; this is the list of what they cannot see.

---

## Waiting now (as of 2026-08-20)

**Bench run 2026-08-20 (NY4I).** Items 2 and 6 passed in full and are gone; the
numbering keeps its gaps on purpose, because commit messages cite these numbers.
Everything NY4I found is in **Findings** at the foot of this file -- seven of
them, F1 to F7, and F7 lands on a change from the same sitting.

### 1. Program message editor — Alt-P, pick a memory, Edit  (`d036b949`, `feb180f0`, `bede4637`)

Ctrl+P / Ctrl+A / Ctrl+C / Ctrl+D all insert their control characters, the saved
`.cfg` key is clean, and the Caption field greys for the "other messages" bank.
**Still open:**

- [ ] **&Edit** is enabled only in Phone mode, and only acts on a message naming
  a `.WAV`.

~~An empty Caption REMOVES the key.~~ **Struck 2026-08-20 (NY4I):** "I see no
evidence of this nor would I want it to work that way." It was written from
reading the old code, not from behaviour, and it is not wanted -- so it is not a
defect and not a requirement. See finding F1, which is the real issue in this
area.

### 3. Window control dialog — Ctrl+Alt+M  (`f11a1093`)

It opens and lists the windows, and Cancel / Escape / the window button correctly
move nothing. The flash-on-selection check has become **finding F2** -- it does
something else entirely. Still open:

- [ ] **OK** then lets you move the chosen window (the caller repositions it).

### 4. Band plan editor — Settings, then the band-plan button  (`uBandPlanForm`)

**BLOCKED 2026-08-20 (NY4I): "I do not see this option in Settings."** Nothing
below can be tested until there is a way in. See finding F3 -- until that is
answered, the checklist stands but is unreachable.

Converted from 33 generated edit boxes to a single `TStringGrid`.

- [ ] It **opens** and shows one row per band with the three current values.
- [ ] Editing a cell and pressing **OK** writes `[BAND PLAN]` in `tr4w.ini` and
  the new values survive a restart.
- [ ] **Cancel changes nothing.**
- [ ] A cell left **empty or non-numeric is skipped** — that band keeps its old
  value rather than becoming 0.

**DECIDED 2026-08-19 (NY4I): the grid stays.** It cost **295 KB of binary**
(4734 -> 5029 KB, ~6%) because `Grids` is linked for the first time and nothing
else in TR4W uses it. Two standing rules pointed opposite ways — "limit
hand-coding of LCL components" against "assume every dependency has a cost" —
and the first wins here: one designed control instead of 33 generated ones, and a
dialog that keeps working when a band is added to `BandType`. Recorded so the
size is not re-litigated, and so the next unit that wants `Grids` knows it is
already paid for.

**Also worth knowing while testing:** the ROW does not decide the band — the
FREQUENCY does. Both loaders call `CalculateBandMode` on the value, so typing a
20m frequency into the 80m row updates 20m. That is pre-existing behaviour, not
new, and it surprised me enough while reading that it is worth surprising you
deliberately rather than accidentally.

### 5. LPT port dialog — Ctrl+Alt+L, or the LPT menu item  (`uLPTForm`)

**Bench this one on hardware if you can**, because it is the dialog that decides
which parallel port keys the paddle and reads the foot switch.

- [ ] It **opens** and shows the three base addresses and the six port
  assignments as they currently are.
- [ ] **OK saves and takes effect** — the paddle and foot switch still work
  afterwards, and the status display updates.
- [ ] With the **radio control port in use**, the FOOT SWITCH and PADDLE combos
  are **greyed** (they come off the radio, not off an LPT).
- [ ] Setting every port to NONE stops the paddle/foot-switch thread; setting one
  back starts it.
- [ ] **Cancel changes nothing.**

The base-address fields are numbers-only now, which they were before via
`ES_NUMBER`.

### 7. Log comparison dialog  (`uLogCompareForm`)

**Multi-op only** -- it appears by itself when a client's log does not match the
server's. To provoke it, connect a client whose `.dat` differs from the server's
(a few QSOs logged while disconnected will do).

- [ ] It **opens** and the table shows six rows -- size, records, CRC32, USQ,
  USQE, contest -- with a **server** and a **local** column. USQ and USQE are
  local-only counters, so their server cells are **blank on purpose**.
- [ ] The **records** row is bytes/record minus one; the log's first record is a
  header, so a 10-QSO log reads 10, not 11.
- [ ] **Synchronize is greyed when the contests differ.** That is the one thing
  this dialog must not allow -- it would merge one contest's QSOs into
  another's log. A server that has not said which contest yet reads
  DUMMYCONTEST, and that is NOT a mismatch, so Synchronize stays available.
- [ ] **Synchronize** closes this window and then opens the server-log dialog.
- [ ] **THE FIX WORTH TESTING:** closing with **Exit**, **Escape** or the window
  **X** must **NOT** open the server-log dialog. It could before, at random.
  The flag meaning "the operator pressed Synchronize" was a LOCAL of the
  window procedure, so a close that did not come from that button read it
  uninitialised -- whatever happened to be on the stack. Someone had already
  seen the symptom: there is a commented-out attempt at a fix in the old code
  that could not have worked either. It is a field now.
- [ ] **Clear all logs** does what the menu item does, and closes.
- [ ] If the local log **cannot be opened**, the window closes immediately rather
  than drawing a comparison against a log that is not there. Unchanged.

### 8. Beacon monitor  (`uBeaconsForm`)

The NCDXF/IBP schedule window. **Opening it QSYs Radio 1 to 14100 kHz CW.**

The grid, the stepping diagonal, the ten mutually-exclusive buttons, the 14100
default and Escape all confirmed. **Still open -- both need a radio:**

- [ ] The highlighted beacon should agree with the schedule table at the foot of
  `src/uBeacons.pas` for the current UTC time.
- [ ] **Pressing a button tunes Radio 1** to that frequency in CW.

### 9. Edit QSO  (`uEditQSOForm`) -- THE ONE THAT WRITES TO THE LOG

Double-click a QSO in the editable log, or reach it from Log Edit / Log Search.
**Work on a copy of a log.**

Confirmed 2026-08-20: it opens over its parent from all three routes, the date
field carries a full date and time, every field edits and lands, the four mult
flags / Name Sent / Inhibit Mults / Dupe are greyed, S&P / Deleted / X-QSO edit
and save, X-QSO still exports with its Cabrillo prefix, callsign typing updates
country / prefix / DX QTH, and note and skipped records behave.

**Two defects came out of that pass -- F4 (the dialog is dirty before you touch
it) and F5 (a bad callsign is accepted). Still open:**

- [x] **Round-trip with no edits**: open a QSO, press Save, reopen. Every field
  should read back identically. Still the single most valuable check here, and
  **F4 has to be fixed before it means anything** -- a dialog that thinks it is
  dirty on open is not testing a clean round trip.
- [ ] **A LONG CALLSIGN SURVIVES.** **Cannot be tested by TYPING** (NY4I,
  2026-08-20: "It is not possible to enter a callsign greater than 12
  characters") -- and that is the design: `MaxLength` limits typing exactly as
  `EM_SETLIMITTEXT` did. The regression was on the LOAD path, so the test has
  to load a long callsign the dialog did not type. Two ways in: log
  `VP2E/W1ABCDE` from the main window if that field allows it, or edit one into
  a scratch `.dat` and open it. Open the QSO, press Save, reopen, and confirm
  it is not shortened. Worth the trouble because it was silent log corruption.
- [ ] **Deleted still sends a contactdelete** to UDP / the external logger.
- [x] **Cancel and Escape discard everything.** See F6 -- NY4I found Escape
  after a change does not prompt, and whether it SHOULD depends on the
  `CONFIRM EDIT CHANGES` question below, so treat these two as one item.
- [x] `CONFIRM EDIT CHANGES = TRUE` still prompts before saving.
- [ ] **Play** is enabled only when the QSO has an MP3 and the file exists; with
  no MP3 player configured it prompts to set one.

**Not a defect, do not report:** the RST fields still refuse a minus sign. That
is deliberate and now has a written reason -- a negative "RST" is a WSJT-X dB
report, and the fix is separate received/sent SNR fields when the log moves to
contest.sqlite, not a wider RST. See the `uEditQSOForm.pas` header.

### 10. Radio panel updates now go through a posted message  (`uPanelUpdate`)

**NEEDS A RADIO.** No UI changed and no control moved -- what changed is HOW the
radio's reading thread reaches the Radio 1 / Radio 2 panels. It used to call
`SetDlgItemTextA` and `EnableWindow` directly across the thread boundary; it now
posts to the main thread, and identical consecutive values are dropped.

Everything below should look exactly as it did. The point of the list is that
"looks the same" is the pass condition, and any DIFFERENCE is the finding.

- [ ] Open the Radio 1 panel (and Radio 2 on an SO2R setup). **VFO A and VFO B
  read the right frequencies and keep up while you tune.**
- [ ] **RIT, XIT and SPLIT light up and go out as you toggle them on the rig**,
  with no lag you did not have before. These are the three that used to be
  written on every single poll; they are now only written when they change,
  so a stuck indicator is the thing to report.
- [ ] **The active VFO highlight follows the radio** when you switch VFO A/B.
- [ ] **Disconnect the radio** (pull the cable or stop the network rig): both VFO
  fields should clear.
- [ ] **A network radio with wrong credentials still shows `AUTH FAILED`** in the
  status line.
- [ ] **Close the panel and reopen it.** Everything should repopulate. This is
  the one genuinely new failure mode: the coalescing cache remembers what it
  last sent, and a panel that reopens BLANK and stays blank would mean the
  cache was not cleared with the window. It is cleared in `CloseTR4WWindow`.
- [ ] Leave it open for a while with the rig idle. Nothing should flicker.
- [ ] **THE PANEL'S TITLE NAMES THE RIG** -- "Radio 1 K4", not just "Radio 1"
  (NY4I, 2026-08-20). The label is `TC_RADIO1`/`TC_RADIO2` so it follows the
  UI language; the rig comes from `RadioName`, which the radio library sets
  when a definition is applied. **With NO radio configured it must read just
  "Radio 1"** -- `RadioName` is initialised to `TC_RADIO1` itself, so an
  unguarded concatenation would say "Radio 1 Radio 1", and that is the state
  the panel is most often opened in while setting a radio up. Check both.
- [ ] **Known limitation, not a defect:** the title is set when the panel OPENS.
  Changing the radio in the CAT dialog while the panel is up leaves the old
  caption until it is closed and reopened. Say so if that is worth fixing --
  `RestartPollingThread` is where a refresh would go.
- [ ] **The MODE labels beside each VFO still show the mode** (CW / USB / …).
  They moved house in the same sitting: they used to be created by the
  generic window opener in `MainUnit` with runtime geometry arithmetic, and
  are now built by `uRadio12` with the rest of the panel and found by
  control id. Verified structurally identical by `Dump-WindowTree` -- same
  197/36 and 197/61, same 55x23 -- so this is confirming they still get
  TEXT, which no dump can show.

**Worth knowing:** the radio thread no longer blocks waiting for the UI on these
writes -- `SetDlgItemTextA` across threads is a synchronous `SendMessage` and
held the poll thread until the main thread serviced it. It should if anything
poll more evenly now. That is a side effect of the change, not its purpose.

### 11. Window positions now live in `settings/tr4w.json`, not `settings/tr4w.pos`

**Why this needs a bench run at all:** the store itself is covered by unit
tests, but the part that reads and writes `tr4w_WindowsArray` is in `MainUnit`
and only runs in the real application. Nothing in the build exercises it.

**Do this in order -- the first step is the migration and it happens once.**

- [ ] **Before starting, note where a few windows are** (Band Map, Telnet, the
  two radio panels) and confirm `settings    r4w.pos` exists and is 550 bytes.
- [ ] Start TR4W. **Every window should come up exactly where it was.** This is
  the seed from the old binary file; if anything moved, the seed is wrong
  and nothing after this is worth testing.
- [ ] **Move two windows somewhere obvious**, then exit TR4W normally.
- [ ] **Open `settings  r4w.json`.** There should be a `"windows"` section with
  one entry per window, keyed by NAME (`"BandMap"`, `"Telnet"`, `"Radio1"`
  ...), each with `left`/`top`/`right`/`bottom`/`visible`. The two you moved
  should show their new positions.
- [ ] **The rest of the file must be intact** -- `radios`, `profiles`, `keyers`,
  `udpBroadcast`, the Cabrillo header sections. This is the one that would
  be expensive to get wrong: exit-save is the first caller in the program
  that saves ONE tenant, and the read-modify-write change exists to stop it
  wiping the others. Check the radio library is still there.
- [ ] **`settings   r4w.pos` should still exist, unchanged.** It is deliberately
  left in place and simply stops being read. Nothing writes it any more.
- [ ] Start TR4W again. The two windows should be where you left them -- read
  from the JSON this time, not the `.pos`.
- [ ] **Open Preferences, change something small, save.** Exit. The `windows`
  section must still be there afterwards: that is the same guarantee from
  the other direction.
- [ ] **Minimise a window and exit.** Its saved rect should not become the
  `-32000` sentinel -- `FindAndSaveRectOfAllWindows` skips iconic windows
  and that logic is untouched, so this is confirming it still is.
- [ ] **Optional, if you have a second monitor:** put a window on it, exit,
  disconnect the monitor, start TR4W. Issue #739's recovery (clamp onto the
  nearest monitor, cascade) runs on the array after loading and is unchanged
  by this work, so it should behave exactly as before.

**Two things a failure here would look like.** A window at the top-left corner
means a rect read as (0,0,0,0) -- which is a LEGAL saved value, so nothing will
report it. A window back at its default position means its name did not match:
`WindowNames` in `VC.pas` is now the on-disk key, and a rename orphans a saved
entry silently.

---

## Findings — bench run 2026-08-20 (NY4I)

Defects found while working the list above. **None of these are fixed.** They
are written down here rather than in the checklists because a checklist item is
a question and these are answers.

### F1 — a stray character appears before a message with a blank caption

**Seen:** F5 saved with the command `EXCHANGERADIOS` and **no caption**. The
function-key display shows *"a random character before the word
EXCHANGERADIOS"*. With a caption present the command is fine.

Screenshot: `C:\Users\toms\Pictures\Screenshots\Screenshot 2026-08-20 112902.png`

**Why it is worth chasing rather than shrugging at:** "a random character" is the
signature of a length byte or a terminator being read as text, and this dialog
has already produced exactly that once -- the earlier `CQ CW MEMORY F5<A4><AE>6w=`
was an unterminated `ShortString` read past its length. A second sighting in the
same area, on the path where a string is EMPTY, says the first fix may have
addressed the symptom at one call site rather than the cause. **An empty caption
is the interesting input**: length zero is the case a length-prefixed read is
most likely to get wrong.

Note this also settles the struck checklist item in section 1 -- the question is
not whether a blank caption should REMOVE the key, it is why a blank caption
renders a character that was never typed.

### F2 — the window control dialog opens a system menu instead of flashing

**Seen:** *"Selecting a window here activates the window but opens the menu with
maximize, minimize, close, etc."*

Expected: moving the selection flashes the corresponding window. What happens
instead is the window's SYSTEM MENU appearing, which is what Windows does for
Alt+Space or a right-click on a title bar -- so the likely cause is the dialog
sending or synthesising something that reaches the target window as a system
command rather than as a flash. Activating the window at all is already more
than intended.

### F3 — the band plan editor has no way in

**Seen:** *"I do not see this option in Settings."*

The form exists and `Invoke-MenuSmoke` proves it constructs and shows, so this is
about the ROUTE, not the dialog. Either the button was never added to the
Settings dialog, or it is there and disabled, or it is behind a mode. Until it is
answered, section 4's checklist cannot be run at all -- and note that the smoke
test passing is exactly why nothing caught this: it opens dialogs by resource
id, not by clicking through the UI a person actually uses.

### F4 — Edit QSO is dirty before you touch it — **FIXED, needs a bench pass**

**Seen:** *"I opened the edit dialog but made no changes. Save was already
enabled upon dialog open and I was prompted to save upon close even though I
changed nothing."*

**Cause, and it is one line.** `uEditQSOForm.pas` enabled Save unconditionally in
`OnShow`, directly contradicting the comment sitting above it:

```pascal
// Save starts disabled and every field's OnChange turns it on, exactly as
// the WM_COMMAND EN_CHANGE / CBN_SELCHANGE / BN_CLICKED arm did.
btnSave.Enabled := True;        // <-- said True
```

D7 enables it **only** from that message arm --
`EnableWindowTrue(hwnddlg, FLD_SAVE_BUTTON)`, `C:\TR4W\tr4w\src\uEditQSO.pas:439`.
So this was a port regression, not a design choice.

**It matters more than a spare button**, which is why it is written up rather
than just fixed: in D7's design the Save button's enabled state **is the dirty
flag**. The dialog keeps no other record of whether anything changed. Enabling it
on open did not merely offer a pointless Save -- it destroyed the only
change-tracking the dialog has, which is exactly why F6 could not work.

The second symptom had a second cause: the "Save changes?" prompt lived inside
`SaveQSOToEditableLog` and was never guarded by whether anything had changed. It
has moved to the UI layer -- see F6.

### F5 — a bad callsign is accepted on Save — **ANSWERED: not a dialog bug**

**Seen:** *"I entered callsign FRED and it accepted it."* NY4I's follow-up:
*"I have no issue if this is a feature, but your test request of me in this file
was to check that a known bad call could not be entered."* -- which is fair, and
the item was a legitimate test. Settled in code rather than left hedged:

**The dialog does validate, in BOTH trees, identically.** `uEditQSO.pas:455`
(this tree) and `:501` (D7, `C:\TR4W`) are the same three lines:

```pascal
  if not GoodCallSyntax(EditableQSORXData.Callsign) then
     begin
     showwarning(TC_CHECKCALLSIGN);
     Result := False;
     Exit;
     end;
```

So this is neither a port regression nor a missing check. `FRED` is accepted
because `GoodCallSyntax` says it is valid. Tracing it in
`uCallSignRoutines.pas:543`: length >= 3 passes, it has letters, there is no
slash, `Call[1] <= '9'` is false so the digits-first test does not fire, and the
length-3 rule does not apply to a four-character call. The rule that WOULD have
rejected it -- no digit anywhere in positions 2 to 4 -- is **commented out**:

```pascal
  { //n4af 4.38.3
  else
    if ((Call[2] < '0') or (Call[2] > '9')) and
       ((Call[3] < '0') or (Call[3] > '9')) and
       ((Call[4] < '0') or (Call[4] > '9')) then
      Exit;
```

**So the defect, if it is one, is a disabled validation rule -- not the dialog.**
Whether a letters-only string should be refused is a decision about
`GoodCallSyntax` and belongs with the callsign routines and their unit tests
(`uTestCallSignRoutines.Test_GoodCallSyntax_Rejects`), not with Edit QSO.

Worth noting for the commented-code sweep: this block is not inert scaffolding,
it is a **behaviour change hiding in a comment** since 4.38.3. Deleting it
without deciding the question would quietly make the decision permanent.

### F6 — Escape after a change does not prompt — **IMPLEMENTED as NEW behaviour**

**Seen:** *"Hitting ESC after a change does not prompt for saving"*, and then
*"I do have edit confirm enabled so when I change a field and hit esc, I should
be prompted."*

**Said plainly: D7 did not do this either.** Its `WM_CLOSE` was a bare
`EndDialog(hwnddlg, 0)` and discarded silently. So this is a REQUESTED FEATURE,
not a restored regression, and it is recorded that way so nobody later reads it
as a port defect.

**What the manual says, and it is right.** `CONFIRM EDIT CHANGES` is documented
against editing "one of your five most recent QSOs (i.e., the QSOs in the
editable log) using the alt-E command". The Edit QSO dialog **is** that editor
today -- `MainUnit.pas:6026` opens it from the editable log via
`IndexOfItemInLogForEdit`. The DOS-era in-place line editor that used to serve
Alt-E, `EditWindowEditor` in `HELP.PAS`, has its whole body inside a 387-line
block comment (lines 1225-1612) and both of its callers are commented out too,
so `uEditQSO.pas` is the only live reader of the setting. (The manual's "five" is
the array bound `NumberEditableLines`, not the selectable row count; NY4I's note
that it should read "the number of most recent QSOs to show" applies to the
DISPLAY, and see the roadmap note about replacing that setting with a resizable
log window.)

**How it is wired.** The confirmation moved out of `SaveQSOToEditableLog` and
into the form: `ConfirmSave` is asked once by `btnSaveClick`, and
`HandleCloseQuery` covers Escape, Cancel and the window's X together (Escape
reaches it because `btnCancel` has `Cancel = True`). A routine that writes 340
lines of binary into the contest log should not also be deciding whether to ask a
question, and with two ways to reach a save it would otherwise have prompted
twice for one action.

Behaviour now, all gated on `CONFIRM EDIT CHANGES`:

| Action              | Nothing changed            | Something changed                                                |
| ------------------- | -------------------------- | ---------------------------------------------------------------- |
| Save button         | unreachable (disabled)     | "Save changes?" -> Yes writes, No returns to the dialog          |
| Escape / Cancel / X | closes silently, as before | "Save changes?" -> Yes writes and closes, No discards and closes |

A save that FAILS does not close -- the operator would otherwise lose the edit to
a validation refusal they never saw resolved.

**To verify on the bench:** all six cells of that table, plus
`CONFIRM EDIT CHANGES = FALSE` giving the old silent behaviour on every one.

### F7 — RIT, XIT and SPLIT show yellow with no radio attached

**Seen:** *"While testing and no radio attached, when the radio window is
opened, the RIT XIT and SPLIT panels are highlighted yellow as if they were
on."*

**This is the one that lands on a change from the same sitting, and I think it is
a regression from the marshalling seam (`9d3a9f79`) -- but I have not proved it
and it needs the bench to confirm.**

The mechanism, as far as the code shows: `uRadio12` creates controls 121-123 with
`CreateStatic`, and a STATIC is created **enabled**. `WM_CTLCOLORSTATIC` paints
ids 121-123 yellow *when the control is enabled* (`uRadio12.pas`, the
`IsWindowEnabled` test). What used to make them grey was
`DisplayCurrentStatus(Radio)`, called from `OpenTR4WWindow` immediately after the
panel is built, which called `EnableWindow(..., False)` **synchronously** -- so
the controls were already disabled before the panel first painted.

**THAT DIAGNOSIS WAS WRONG, and NY4I's test is what killed it.** The prediction
was that forcing a repaint would turn them grey, proving the disable had arrived
and only the paint was stale. Measured on the bench: *"No change when I forced a
repaint and the problem remains."* So they are not stale -- they are **genuinely
still enabled**, and the `EnableWindow(False)` never happened at all.

**THE REAL CAUSE, and it is provable by reading rather than inferred.**
`CloseTR4WWindow` calls `ForgetPanel` **BEFORE** `DestroyWindow`
(`MainUnit.pas:5341`), deliberately and with a comment saying so. But
`ForgetPanel` cleared child entries with `not IsWindow(Target)` -- and at that
moment the children are still perfectly good windows, so that test is false for
every one of them. Its own comment claimed the line *"is what actually clears the
RIT/XIT/SPLIT statics"*. It never did.

So the three `puEnable` entries SURVIVED the close, holding `Enabled = False`.
Windows reuses handles; a freshly created static landing on a remembered HWND
makes `PostControlEnable(h, False)` match the cache and **skip the post** -- while
the new control was created ENABLED. Hence yellow, and hence no repaint could fix
it: the control really is enabled.

It also explains why it shows up **with no radio attached**. With a rig
connected, polling eventually posts a different value and the panel self-heals;
with nothing polling, that one suppressed post is the only one there was.

NY4I confirmed the sequence: *"I closed the radio windows then reopened in same
session (no radio attached) and still RIT XIT and SPLIT are yellow."* On a
genuine first open the cache is empty and they come up grey, which is why this
survived the original bench pass.

**FIXED** in `uPanelUpdate.ForgetPanel` by asking `IsChild(aPanel, Target)` while
the panel still exists, instead of waiting for the children to stop being
windows. The `IsWindow` arm stays as a backstop.

**NOT fixed by moving the call after `DestroyWindow`**, which was the tempting
one-liner: a freed HWND can be reused immediately, so `IsWindow` can be true
again for an unrelated window and the stale entry survives anyway. `IsChild`
answers the question actually being asked, and only works BEFORE the destroy --
so the existing call order was right and only the test was wrong.

**THAT WAS ALSO WRONG.** NY4I rebuilt with the `ForgetPanel` fix and the panels
were still yellow (screenshot 2026-08-20 14:33, caption reading "Radio 1
K4D-278" so it was demonstrably the new binary). Two confident diagnoses, both
refuted by one bench run each. The third was found by stopping at the question
both had assumed away: **does the posted message arrive at all?**

**IT NEVER DID, AND IT NEVER HAD.** The main window is an LCL form subclassed by
`TR4WFormSubclassProc` (`uMainForm.pas`), which asks `IsTR4WsOwnMessage` whether
TR4W wants a message and chains everything else to the LCL. That was a
hand-written list of literal integers, with a comment noting this avoided
"depending on five more units for four integers". **`WM_PANEL_UPDATE`
(`WM_APP + 230`) was not in it.** Every panel update ever posted chained to the
LCL, which has never heard of it, and `RunQueuedPanelUpdate` was never called
once. The seam from `9d3a9f79` had not delivered a single update since the day
it was written -- which is also why bench item 10 has nothing to report yet.

**AND THREE MORE MESSAGES WERE BEING DROPPED THE SAME WAY**, two of them from
long before this work:

| Message | The list said | Actually | Consequence |
|---|---|---|---|
| `WM_CTY_VERSION_CHECKED` | `WM_APP + 213` | `WM_APP + 210` | CTY.DAT version-check result discarded |
| `WM_TRAYBALLON` | `WM_APP + 100` | `WM_SOCK + 3` = `$5F7` | tray icon clicks never handled |
| `WM_PANEL_UPDATE` | absent | `WM_APP + 230` | the whole radio-panel seam |
| `WM_USER_HEADLESS_SYNC_REPLACE` | absent | `WM_USER + 200` | **multi-op log replace never ran**, and it is `SendMessage`d, so the requesting thread blocked to be told nothing happened |

Four of eight. Not one of them produced an error, a log line or a compiler
diagnostic: the post SUCCEEDS, and the work simply does not happen.

**FIXED** by naming the constants instead of their values -- `uMainForm` now has
an implementation-section `uses` for the six units that declare them. A list of
integers that must agree with constants declared elsewhere cannot be checked by
anything; a list of the constants cannot be wrong about a value at all.

**GATED** by `Lint-AppMessages` (`build/Lint-AppMessages.ps1`, wired into
`Run-Lints`), which fails when a message `WindowProc` handles is not claimed by
`IsTR4WsOwnMessage`. It was tested by deleting `WM_PANEL_UPDATE` from the list
again and confirming it fails with that name and the line number.

The `ForgetPanel` fix above stays: it is a real bug on its own -- the entries
genuinely did survive a close -- it just was not this symptom, because nothing
was reaching the panel to be suppressed in the first place.

**To verify on the bench:**

- [x] Open Radio 1 with no radio attached. **RIT, XIT and SPLIT must be GREY.**
      **CONFIRMED 2026-08-20 (NY4I): "rit xit and split appear gray now."** That
      is the first update the marshalling seam has ever delivered.
- [x] Close and reopen it a few times. Still grey every time (that is the
      `ForgetPanel` half, a separate bug from the message routing).
      **CONFIRMED 2026-08-20 (NY4I): "closed and reopened the radio panel, still
      gray."** Both halves of F7 are now verified: the message reaches the panel
      at all, and the coalescing cache no longer suppresses the first update
      after a reopen.
- [ ] With a radio connected, **bench item 10 becomes testable for the first
      time** -- VFO A/B text, the mode labels, RIT/XIT/SPLIT following the rig.
      None of it can ever have worked, so treat that whole item as unrun rather
      than as a regression check.
- [ ] **Multi-op:** a client log replace from the server should now actually
      happen (`WM_USER_HEADLESS_SYNC_REPLACE`).
- ~~**Tray icon:** clicking the notification-area icon should reach TR4W
  again.~~ **STRUCK -- NOT OBSERVABLE, and it should never have been listed.**
  `WM_TRAYBALLON`'s handler in `uMainWindowProc.pas:385` is an EMPTY
  `begin end`. Clicking the tray icon has always done nothing and still does;
  the routing fix means the message now arrives somewhere that ignores it,
  which looks identical from the outside. Written into the checklist without
  reading the handler first.

  Worth knowing rather than deleting: the icon is registered with
  `Balloon_AddTrayIcon(tr4whandle, 11, ..., WM_TRAYBALLON, 'TR4W')`
  (`uTrayBalloon.pas:214`), so the plumbing is real and the click callback now
  genuinely lands. If a tray click is ever meant to DO something -- restore the
  window, show a menu -- the handler is where it goes, and it will work now
  whereas before the message never got there.
- [x] **Taskbar button:** the main window has one again, and clicking it
      restores/minimises normally. **CONFIRMED 2026-08-20 (NY4I).** This is the
      `ShowInTaskBar := stAlways` fix, not a message-routing one: the window had
      had no taskbar button at all since it became an LCL form, because
      stDefault means "show if this is the application's MAIN form" and TR4W has
      none -- `Application.CreateForm` is never called.
- [ ] **CTY.DAT version check** should report a newer version when there is one.

---

## Known and accepted — no action, listed so they are not re-reported

- **CW-by-CAT keys one character per `KY` command** when typing into the
  send-from-keyboard box (Ctrl+A) or during autosend. Staccato, inherent, and
  better than D7 (which sent nothing until Enter). Full explanation and three
  untried directions in `CW_Keyer_Factory_Plan.md`.
- **Preferences collapses the Hardware branch** after visiting another section.
  That is the one-branch-at-a-time rule working. The pane arithmetic behind it
  was recounted 2026-08-18 and two branches now overflow; NY4I is rearranging the
  sections first, then it gets revisited.
