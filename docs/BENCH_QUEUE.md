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

## Added 2026-08-28 (evening) -- FIXED FROM NY4I'S NOTES, UNRUN

Worked from the [AGENT ...] notes as instructions. Each of these is a change he
reported and has not re-tested, except where marked confirmed.

- [x] **Edit QSO wrote the operator as its first letter only** (`1e53f410`).
  CONFIRMED as a defect from his log; the fix itself wants a look: edit a QSO,
  change Operator to something longer than one character, save, reopen.

- [x] **Check for Updates is off the Help menu** (`2366f099`). Verified by
  dumping the live menu. **Still yours:** an endpoint that returns a version
  string, and a static link to the latest.

- [x] **Edit QSO tab order** (`9792b795`) -- RST received -> Operator ->
  Deleted -> X-QSO -> Save -> Cancel.

- [x] **Picking a window from the Windows menu always shows it** (`9792b795`).
  Was: an item shown UNCHECKED could still take the close branch. Applies to
  every tool window, so worth a pass over several.

- [x] **The call and exchange fields use the main font** (`9adffbeb`). They were
  still being handed an HFONT, which an LCL control ignores, so they kept the
  form default while everything beside them did not.

- [x] **One config log line per CHANGE, not two per save** (`53921ce2`), and it
  now says what the value was.

- [x] **Renaming a profile no longer empties the radio combos** (`ca1eb59a`).
  CONFIRMED by NY4I. Took four attempts; the first three fenced the capture
  side when the fault was on the display side.

### Stable ids -- three stores changed, NONE bench-verified

`875c71b6` radios, `aacf6571` keyers, `79cda4c5` rotators. Profiles and the
active-device references are ids now, not names. Migration from a file without
ids is covered by unit tests, including one built from the shape of his own
settings/tr4w.json.

- [ ] **Rename a radio** in Preferences and confirm the active profile keeps it.
  This is the case that failed and started all of it.
- [ ] **Rename a keyer** and confirm the profile's CW output still names it.
- [ ] **Rename the active rotator** -- type over its name a character at a time.
  It used to deactivate after the first letter.
- [ ] **Open an existing station** and confirm nothing moved: the migration runs
  once, silently, on the first load with this build.

### Still open from his notes

- [ ] **Ctrl/Alt bank labels do not restore on release** (`88d5d5ef`
  instrumented, not fixed). Set DEBUG, press and release Ctrl then Alt, send the
  `[Modifiers]` lines. Two lines = the restore ran and the fault is inside
  `ShowFMessages(0)`; one line = the release never arrives.
- [ ] **The beacon monitor tunes the radio just by opening.** "I should have to
  take an overt act to start changing the radio frequency."
- [ ] **The colours table could show a sample** of the text and background.
- [ ] **Escape closes the DX cluster with no confirmation.** Escape closes every
  converted window, so this is a decision about all of them, not one.

---

## What the agent can check without you  (audit, 2026-08-28)

NY4I asked: "confirm there are not any of the steps you added to this document
for me to check that you could have checked."

**The honest answer is that some of them were.** The harness in `test/ui` can
launch TR4W, enumerate every window and control, drive menu commands, type into
fields and read the log back. Anything in the list below should be run by the
agent BEFORE it reaches this file.

| Question   | Tool                | Verified tonight |
| ---------- | ------------------- | ---------------- |
| Does a     | ` Invoke-MenuSmoke. | 8 commands, 7    |
| dialog     | ps1`                | windows          |
| openat     |                     |                  |
| all?       |                     |                  |
| Do Edit    | `Invoke-FieldCheck  | 69/69            |
| QSO's      | .ps1`               |                  |
| fields     |                     |                  |
| round-trip |                     |                  |
| ?          |                     |                  |
| Is a menu  | `Dump-Menu.ps1`     | caught About     |
| caption,   |                     | reading "Check   |
| idor       |                     | for Updates"     |
| shortcut   |                     |                  |
| right?     |                     |                  |
| Do         | `Dump-Accelerators  | --               |
| accelerato | .ps1`               |                  |
| rs         |                     |                  |
| collide?   |                     |                  |
| Did a      | `Dump-WindowTree.p  | --               |
| window     | s1` +               |                  |
| losea      | `Compare-WindowTre  |                  |
| control,   | e.ps1`              |                  |
| or its     |                     |                  |
| size?      |                     |                  |
| Does a     | `Test-TextFit.ps1`  | --               |
| translated |                     |                  |
| caption    |                     |                  |
| still fit? |                     |                  |
| Does       | `Test-Typing.ps1`   | --               |
| typing     |                     |                  |
| reach the  |                     |                  |
| right      |                     |                  |
| field?     |                     |                  |
| Does       | `Test-PreferencesS  | --               |
| Preference | ections.ps1`        |                  |
| s show     |                     |                  |
| every      |                     |                  |
| section?   |                     |                  |
| Did the    | read                | proved the       |
| program    | `target/tr4w.log`   | Spanish menu is  |
| write      |                     | not ours         |
| whatit     |                     |                  |
| claims?    |                     |                  |

**What the agent still cannot do**, and what therefore belongs here: judge a
COLOUR or a layout by eye; confirm a caret is visible; see flicker or timing;
anything needing a radio (`tools/radiosim` or the TCI simulator can stand in for
some of it); anything needing a second station; and any question about whether
what appeared is CORRECT rather than merely present.

That distinction is the point. `Invoke-MenuSmoke` proves a window OPENS and says
so in its own output -- "Still NOT a check that any window is CORRECT" -- and
that gap is exactly what the rest of this file is for.

---

## Added 2026-08-28 (overnight) -- UNRUN

Everything below was built, linted, unit-tested and corpus-checked. None of it
has been on screen.

### A. New Contest dialog is now an LCL form  (`16ffc284`)

**This is the first thing the operator sees, and it changed shape** -- it
replaced 494 lines of `NewContestDlgProc`.

- [x] **The `.CFG` list** shows the TR4W directory, and **Browse...** opens the
  standard file picker and can reach a config somewhere else.

- [x] **Latest config file** still reopens the last one.

- [x] **OK stays disabled** until the callsign and every shown field are filled.
  Pick a contest and watch the prompt panel and any extra field appear.

- [x] **A contest that asks for a field** -- `NEWENGLANDQSO`, `WAG`, `POTA` --
  shows one row with the right label.

- [x] **The "I am in" box** on a QSO-party contest changes the prompts.

- [x] **The six `CATEGORY-*` drop-downs have labels.** They shipped unlabelled in
  the first pass; this is the fix.

- [ ] **Resize the window** -- list and fields follow, buttons stay bottom-right.

- [ ] **DECISION: should `ARRL10/160/DXCW/RTTY_ROUNDUP` pre-tick something?**
  Those four arms called `SendMessage(107, BM_SETCHECK, ...)`, and 107 is a
  control ID, not an HWND, so it addressed nothing and never worked. Dropped
  rather than reinvented: giving it a meaning now is a new decision, not a port.

### B. YesOrNo lost its HWND at 16 call sites  (`384d1895`)

- [ ] **Every Yes/No prompt still defaults to No.** Press Enter on "do you really
  want to clear the log" and it must NOT clear. This is the one to check
  because the failure is silent and one keystroke wide: `MessageDlg` focuses
  the FIRST button, so a naive port would have moved every destructive prompt's
  default to Yes. Confirmed once on the exit prompt; the other fifteen are
  unverified.

### C. Twelve units deleted  (`96d2f2c2`, `7d65787b`, `49b30e07`, `3722f669`)

uRemMults_DOM/DX/Zone, uDXSSpotsFilter, uSpotsFilter, uMultsFrequencies,
ColorCfg, LOGHP, LOGPROM, uSCP, uReminder, uQuickEdit -- 3070 lines, twelve
Win32 dialog procedures, and eight HWND globals nothing read. All were proved
unreachable: absent from every program's uses clause, or a dialog procedure
nothing ever passes to `DialogBox`.

- [ ] **Nothing should have changed.** If a menu item now does nothing that used
  to work, it is one of these -- `git revert` the commit above and say which.

### D. Decisions waiting on NY4I, not bench items

- [ ] **`uExternalLoggerManager` and `uRadioManager` are excluded for an expired
  reason.** `tr4w.dpr` says "uses Generics.Collections (Delphi 2009+) - not
  Delphi 7 IDE compatible". Delphi 7 is gone and FPC has
  `Generics.Collections`. CLAUDE.md still describes `uExternalLoggerManager` as
  carrying the external-logger implementation, so this is either work to finish
  or code to delete -- it should not stay in limbo. **The one worth your time.** [AGENT: Yes the external loggers should be a factory. I believe it is so I am not sure why the Generics aftect this. I could see there being an external logger status indicator but a better UX might be an external status panel. That way we could show the time of the last WSJT-X message, the last status sent form ExternalLOggers, the last exchange with Hamscore. Sort of a status window on these items. But new windows can wait and the external logger works now.]

- [ ] **`MixW2DlgProc` and `WinKeyer2SettingsDlgProc` have zero references.**
  Their units are live (MixW integration, WinKeyer driver) but those two
  dialogs are never opened. Is the WinKeyer settings dialog reachable from a
  menu, or has Preferences replaced it? If replaced, both procedures can go.

- [ ] **The main window's start-up paint is still unexplained** -- grid lines,
  then data. The `WM_SETREDRAW` bracket was tried, made no visible difference,
  and was reverted when the lint showed it added three `wh[]` references to a
  surface being retired. Cause unknown; likely the control's own first paint
  before any rows exist, which redraw suppression cannot touch.

- [ ] **15 unreferenced routines in `TF.pas` and `uDialogs.pas`** --
  `SelectColor`, `SelectFolder`, `SaveFileDlg`, `TR4W_OFNHookProc` (referenced
  only from a commented-out `lpfnHook` assignment, so the hook is never
  installed) and others. Two automated attempts to remove them broke on a
  multi-line declaration and on an assembly block; they need a hand pass.

---

## Added 2026-08-26 (overnight) -- UNRUN

Five changes landed while NY4I was away. Three are visible and want an eye; two
are diagnostics that cost nothing to leave on.

- [ ] **The Windows menu and its accelerator now CLOSE a converted window.**
  Previously the second press did nothing: the toggle called
  `CloseTR4WWindow` directly, which destroys the handle behind the LCL's back
  on a form that is still Visible, so the widget set recreated it. Try it on
  **every** converted window, not just Stations -- the fix is shared
  (`RequestCloseTR4WWindow`). Also **Escape in the Stations window**, which had
  the same bug and appeared to do nothing.

- [ ] **Three menu items no longer show their shortcut twice** -- File > Export >
  Cabrillo, Settings > Winkeyer, Settings > LPT. They read `Ctrl+Alt+B
  Ctrl+Alt+B` and so on. Check the keys still WORK as well as reading right.

- [x] **The WSJT-X indicator's font is smaller** so its text fits its cell --
  see the item in section 40. The layout is unchanged. [AGENT: But after that change, the font size of the call window is now smaller. That should be the same size as other items on the form like band, date, time, etc.]

- [x] **`DEBUG LOG LEVEL = DEBUG` now logs every configuration change**, both
  storage paths, and logs REJECTED values too. Change a few settings in
  Preferences and confirm the lines match what you did: [AGENT: Note this worked but I see two messages in the log as if we are going through this code twice: `28 Aug 2026 13:49:23.846 700244 [27180] debug TR4WDebugLog  - [Config] BAND MAP SIZE = 4 (stored in tr4w.json)`
  `28 Aug 2026 13:49:23.846 700244 [27180] debug TR4WDebugLog  - [Config] BAND MAP SIZE = 4 (stored in tr4w.json)`
  
        [Config] BAND MAP DECAY TIME = 20 (stored in tr4w.json)
  
- [x] **`DEBUG LOG LEVEL = TRACE` now logs every MODIFIED keystroke the
  accelerator hook sees.** This is the instrument for the Ctrl+Shift+0
  question in section 34 -- press it and look for
  `[InputHooks] key $30 ctrl=1 alt=0 shift=1`. **No line means Windows took the
  key before TR4W saw it.**

**Not in the bench queue because a gate now covers it:** the menu itself.
`test\ui\Dump-Menu.ps1` captures the live menu and `baselines\menu.json` is the
committed reference, so a menu row that changes caption, shortcut, position or
id shows up as a diff rather than needing to be noticed by eye.

---

## Waiting now (as of 2026-08-24)

**Sections 31-42 were added 2026-08-24 and are UNRUN.**  Section 37 is the
biggest of them: the entire main window display changed. NY4I confirmed
the dupe sheet window, the Stations window and the entry-field colours on the
bench that day, but was remote when the captions, the resize behaviours and
the band-change message landed -- so those are recorded here rather than
counted as tested.

**STILL UNRUN AND THE OLDEST ITEM HERE: the radio bench test (section 10).**
The 2026-08-20 commits were held for it and then pushed on 2026-08-21 without
it having happened, at NY4I's instruction. Nothing in the radio panel seam has
been exercised on hardware, and it had NEVER delivered an update before that
fix -- so section 10 is new behaviour, not a regression check.

**Bench run 2026-08-20 (NY4I).** Items 2 and 6 passed in full and are gone; the
numbering keeps its gaps on purpose, because commit messages cite these numbers.
Everything NY4I found is in **Findings** at the foot of this file -- seven of
them, F1 to F7, and F7 lands on a change from the same sitting.

### 1. Program message editor — Alt-P, pick a memory, Edit  (`d036b949`, `feb180f0`, `bede4637`)

Ctrl+P / Ctrl+A / Ctrl+C / Ctrl+D all insert their control characters, the saved
`.cfg` key is clean, and the Caption field greys for the "other messages" bank.
**Still open:**

- [ ] **&Edit** is enabled only in Phone mode, and only acts on a message naming
  a `.WAV`. [AGENT: Given the comment below, is this still a viable task to test. Also, you headline has test steps rather than a tasklist under the heading. This needs some more explanation.]

~~An empty Caption REMOVES the key.~~ **Struck 2026-08-20 (NY4I):** "I see no
evidence of this nor would I want it to work that way." It was written from
reading the old code, not from behaviour, and it is not wanted -- so it is not a
defect and not a requirement. See finding F1, which is the real issue in this
area.

### 3. Window control dialog — Ctrl+Alt+M  (`f11a1093`)

It opens and lists the windows, and Cancel / Escape / the window button correctly
move nothing. The flash-on-selection check became **finding F2**, which is now
answered: the system menu NY4I saw is the accept path doing what it was always
meant to do, and it is the mechanism behind the item still open below. Still
open:

- [x] **OK** then lets you move the chosen window -- it pops the chosen window's
  SYSTEM MENU at its top-left corner (`WM_POPUPSYSTEMMENU`), and Move from that
  menu is how the repositioning happens. That is the design, in D7 too. ~~[AGENT - There is a weird artifact from Spanish. The move menu (or if I click on any TR4W top-left icon, shows me the choices in Spanish. I am NOT running in Spanish mode)]~~
  **RESOLVED 2026-08-28 -- not TR4W.** That is the WINDOWS system menu, and the
  log proves TR4W translated nothing on that run: `UI language: "en" from the
  operating system locale (en_US); that is the compiled-in language, so no
  catalogue is loaded`, then `UI language: none loaded`. With no catalogue
  applied the program cannot be the source of a Spanish word. Move / Size /
  Close come from Windows and follow the WINDOWS DISPLAY LANGUAGE, so the place
  to look is Settings > Language, not us.

- [ ] Moving the selection with the ARROW KEYS, without accepting, flashes the
  window and does nothing else. This is the half of F2 that is still a question. [AGENT: There is no way to move with arrow keys as when I press OK, the window control daughter menu appears and the arrow keys navigate in that menu (up and down).]

### 4. Band plan editor — Preferences, More settings, the Edit... button  (`uBandPlanForm`)

**UNBLOCKED 2026-08-21.** The way in is an "Edit..." button on the two
band-plan rows in **Preferences -> More settings** -- captioned *Band Map Cutoff
Frequency* and *Frequency Memory*. Note it is NOT in Ctrl-J Settings, which is
where it used to be and where it was looked for; finding F3 records why.
Confirmed opening on the bench (NY4I).

Converted from 33 generated edit boxes to a single `TStringGrid`.

**Confirmed 2026-08-21 (NY4I):** it opens from Preferences, it is resizable, the
headings are readable, the grid fills the window, and the position is remembered
across openings. **What is still unrun is everything that WRITES:**

- [x] It **opens** and shows one row per band with the three current values.
- [ ] ~~Editing a cell and pressing **OK** writes `[BAND PLAN]` in `tr4w.ini` and
  the new values survive a restart.~~[AGENT: Nothing is suppose to write to the .ini so validate this is meant to be .json. You should also consider if this is something you can automatically test now that we figured out how you can run the program to test. IN fact, confirm there are not any  of the steps you added to this document for me to check that you could have checked.]~~

  **ANSWERED 2026-08-28 -- it is JSON, and this step is out of date.** The band
  plan lives in `uRadioConfigStore` (`settings/tr4w.json`); the ini's
  `[BAND PLAN]` section is READ once, by `uRadioConfigApply`, to migrate a
  station upgrading from an older build, and `uBandPlanForm` guards against
  falling back to writing it. So the check is: edit a cell, OK, and confirm the
  values land in **tr4w.json** and survive a restart -- nothing should appear in
  tr4w.ini.

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
default and Escape all confirmed. **Still open -- both need a radio:** [AGENT - Simply the act of opening the beacons monitor window changes the radio frequency to the first monitor. That should not work that way--even though it may have in D7 too). I should have to take an overt act to start changing the radio frequency]

- [x] The highlighted beacon should agree with the schedule table at the foot of
  `src/uBeacons.pas` for the current UTC time.
- [x] **Pressing a button tunes Radio 1** to that frequency in CW.

### 9. Edit QSO  (`uEditQSOForm`) -- THE ONE THAT WRITES TO THE LOG

Double-click a QSO in the editable log, or reach it from Log Edit / Log Search.
**Work on a copy of a log.**

Confirmed 2026-08-20: it opens over its parent from all three routes, the date
field carries a full date and time, every field edits and lands, the four mult
flags / Name Sent / Inhibit Mults / Dupe are greyed, S&P / Deleted / X-QSO edit
and save, X-QSO still exports with its Cabrillo prefix, callsign typing updates
country / prefix / DX QTH, and note and skipped records behave.

~~[AGENT - Editing a QSO is changing the Operator field to just the first character.]~~ We have to add a mechanism to check the fields in the qso record upon entry to the edit field is the exact same as when we leave except for the dirty field. In  the test log, I changed the contact for W1SSB and it updated operator to just N. The sanctity of a QSO is paramount] 
**FIXED 2026-08-28 (`1e53f410`).** `ceOperator` is `array[0..10] of AnsiChar`,
and the save did `Move(tempOperator[1], ..., length * sizeof(char))` with `char`
two bytes wide under `{$MODESWITCH UnicodeStrings}` -- so 'NY4I' was written as
`N`,#0,`Y`,#0,... and read back at the first #0 as `N`. Two more faults in the
same three lines: the zero-fill measured the value ALREADY in the record, so a
shorter name left the old tail behind, and nothing bounded the copy, so an
11-character operator wrote past the field. Worth knowing:
`Invoke-FieldCheck.ps1` reported 69/69 both before and after -- it proves a
value survives the CONTROL, and this was the write to the RECORD.


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
- [x] **Deleted still sends a contactdelete** to UDP / the external logger.
- [x] **Cancel and Escape discard everything.** See F6 -- NY4I found Escape
  after a change does not prompt, and whether it SHOULD depends on the
  `CONFIRM EDIT CHANGES` question below, so treat these two as one item.
- [x] `CONFIRM EDIT CHANGES = TRUE` still prompts before saving.
- [ ] **Play** is enabled only when the QSO has an MP3 and the file exists; with
  no MP3 player configured it prompts to set one. [AGENT: I can confirm Play is not enabled as there is no MP3 file. We have to work on the recording system to get an MP3 file. I do not even know where these would go or the name of one to test it.]
- [ ] [AGENT: The Tab order on the edit QSO dialog is a bit off. The check boxes for Deleted and X-QSO should be entered after tabbing out of Operator. And after RST received, the next in the tab order should be Operator.]

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

- [x] Open the Radio 1 panel (and Radio 2 on an SO2R setup). **VFO A and VFO B
  read the right frequencies and keep up while you tune.**
- [x] **RIT, XIT and SPLIT light up and go out as you toggle them on the rig**,
  with no lag you did not have before. These are the three that used to be
  written on every single poll; they are now only written when they change,
  so a stuck indicator is the thing to report.
- [x] **The active VFO highlight follows the radio** when you switch VFO A/B.
- [x] **Disconnect the radio** (pull the cable or stop the network rig): both VFO
  fields should clear.
- [ ] **A network radio with wrong credentials still shows `AUTH FAILED`** in the
  status line.
- [x] **Close the panel and reopen it.** Everything should repopulate. This is
  the one genuinely new failure mode: the coalescing cache remembers what it
  last sent, and a panel that reopens BLANK and stays blank would mean the
  cache was not cleared with the window. It is cleared in `CloseTR4WWindow`.
- [x] Leave it open for a while with the rig idle. Nothing should flicker.
- [x] **THE PANEL'S TITLE NAMES THE RIG** -- "Radio 1 K4", not just "Radio 1"
  (NY4I, 2026-08-20). The label is `TC_RADIO1`/`TC_RADIO2` so it follows the
  UI language; the rig comes from `RadioName`, which the radio library sets
  when a definition is applied. **With NO radio configured it must read just
  "Radio 1"** -- `RadioName` is initialised to `TC_RADIO1` itself, so an
  unguarded concatenation would say "Radio 1 Radio 1", and that is the state
  the panel is most often opened in while setting a radio up. Check both.
- [ ] **Known limitation, not a defect:** the title is set when the panel OPENS.
  Changing the radio in the CAT dialog while the panel is up leaves the old
  caption until it is closed and reopened. Say so if that is worth fixing --
  `RestartPollingThread` is where a refresh would go. [AGENT: While testing, I ran into an issue here... I changed the name of the K4Z to K40 in My radios. When I did that, the radio was removed from the active profile. I then selected the new name K4) from the drop-down for Radio 2, but received this error message - ![image-20260828141727836](C:\Users\toms\AppData\Roaming\Typora\typora-user-images\image-20260828141727836.png) So there are at least two issues. First, when I change the name of a radio in MY radios, that name should also be updated in the saved (and active profile). It would appear you are using the radio name as an id when it would make more sense to say use a GUID and reference it by index so these changes will just flow through once you just do an update on the profile drop-downs.  The second issue of course is the error dialog but the prior statement about a guid or some index besides the name could address that. On the subject of what this item discussed specifically, stale data is never good and should be updated as we change it so yes the name in the radio window and the main window should change.]
- [x] **The MODE labels beside each VFO still show the mode** (CW / USB / …).
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

- [x] **Before starting, note where a few windows are** (Band Map, Telnet, the
  two radio panels) and confirm `settings tr4w.pos` exists and is 550 bytes.
- [x] Start TR4W. **Every window should come up exactly where it was.** This is
  the seed from the old binary file; if anything moved, the seed is wrong
  and nothing after this is worth testing.
- [x] **Move two windows somewhere obvious**, then exit TR4W normally.
- [x] **Open `settings  tr4w.json`.** There should be a `"windows"` section with
  one entry per window, keyed by NAME (`"BandMap"`, `"Telnet"`, `"Radio1"`
  ...), each with `left`/`top`/`right`/`bottom`/`visible`. The two you moved
  should show their new positions.
- [x] **The rest of the file must be intact** -- `radios`, `profiles`, `keyers`,
  `udpBroadcast`, the Cabrillo header sections. This is the one that would
  be expensive to get wrong: exit-save is the first caller in the program
  that saves ONE tenant, and the read-modify-write change exists to stop it
  wiping the others. Check the radio library is still there.
- [x] **`settings   tr4w.pos` should still exist, unchanged.** It is deliberately
  left in place and simply stops being read. Nothing writes it any more.
- [x] Start TR4W again. The two windows should be where you left them -- read
  from the JSON this time, not the `.pos`.
- [x] **Open Preferences, change something small, save.** Exit. The `windows`
  section must still be there afterwards: that is the same guarantee from
  the other direction.
- [x] **Minimise a window and exit.** Its saved rect should not become the
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

### 12. Six links, after `OpenUrl` became the only launcher  (`f3fece6d`)

**One click each, and the point is that they still open.** `ShellExecute` was
replaced by `LCLIntf.OpenURL`/`OpenDocument`, and four menu items that had grown
their own `ShellExecute` now go through `OpenUrl` like the other six callers did
all along.

- [x] **3830 scores** and **ARRL log submission** (both under the log-submission
  menu) each open a browser.

- [x] **QRZ.RU calendar** and **WA7BNM calendar** open the page **for the CURRENT
  CONTEST** -- these two build their URL from `ContestsArray[Contest]`, and the
  URL is now composed with `SysUtils.Format` into a string instead of
  `TF.Format` into a buffer, so a wrong contest id or a truncated URL is the
  thing to watch for.

- [ ] **Help -> Check for Updates** -- NEW, 2026-08-22, and it has NEVER RUN
  BEFORE. `uCheckLatestVersion` had existed complete since the D7 days with no
  caller; NY4I asked for it on the Help menu after this queue sent him looking
  for an option that did not exist.

  - [ ] It should reach `www.tr4w.net`, compare versions, and either say you have
    the latest or offer the download link. **It dialed `tr4w.com` while sending
    `Host: www.tr4w.net`** -- corrected to `www.tr4w.net`, and since the routine
    had never run, nothing had ever exercised that mismatch. If the check fails,
    the host is the first thing to suspect. ~~[AGENT: ;I tested this but we still have the issue of implementing a good pattern where our website can give you the latest version info so the program can decide if it needs to offer a download. I also need to get a static link that redirects to the latest. SO for now, let's disable that menu item. This is the error I received: ![image-20260828142557318](C:\Users\toms\AppData\Roaming\Typora\typora-user-images\image-20260828142557318.png)]~~
    **DONE 2026-08-28 (`2366f099`) -- the item is off the Help menu.** The unit,
    handler and id all stay; restoring it is one line once the site serves a
    version STRING rather than a web page. Removing the row also required
    removing its caption line: captions are assigned POSITIONALLY, so the first
    attempt left About reading "Check for Updates". Verified by dumping the
    live menu.
    **Still open, and yours:** a documented endpoint, and a static link that
    redirects to the latest.

  - [ ] **EXPECT THE UI TO FREEZE for about two seconds.** It does its socket
    work on the main thread and sleeps 2s waiting for the reply. That breaks
    NY4I's own no-I/O-on-the-UI-thread rule and is a KNOWN follow-up: wiring it
    up was the request, and rewriting it in the same change would have meant a
    bench failure could not be attributed to either. [ AGENT: You know how I feel about I/O on the main thread]
  - [x] Confirm the menu item sits in **Help**, after "Download POTA Parks".

  **DEFERRED, and the client side is only half the question (NY4I, 2026-08-22).**
  This routine expects `GET /include_pages/version.txt` from `www.tr4w.net` to
  return a version string it can compare against `TR4W_CURRENTVERSION`. Whether
  that endpoint still exists, still contains a current number, and still matches
  the format the compare expects is a question about the RELEASES SITE, not
  about this code -- NY4I is checking that infrastructure separately and this
  item stays UNTESTED until he has.

  Worth asking at the same time whether this mechanism is still the right one:
  releases now go out with `Invoke-Release.ps1` and a GitHub tag, so a hand-kept
  `version.txt` is a second place the version has to be right. If the answer is
  a GitHub releases API call, the socket code and the 2-second freeze both go
  away with it rather than needing the threading rewrite.

- [x] **Preferences -> Logging -> the "Open log file" BUTTON** (bottom of the
  Logging page, below the trace check boxes) opens `tr4w.log` in whatever
  editor the operator has associated with `.txt`. It is a button, not a menu
  item -- the original wording read like a menu path, which is why it could
  not be found. 

### 13. Nothing should have changed -- 7,187 lines of commented-out code are gone

  (`dd53c1ab`, `67af7f28`, `3c1c4703`)

**No behaviour change is intended anywhere in this, which is exactly why it wants
a normal session rather than a checklist.** The app, `tr4wserver`, 16 lints and
9558 unit tests are green, and the golden corpus has NOT been run (it needs a
deploy into `target\`, which is yours).

- [x] **Run a short contest normally** -- log a few QSOs, work a dupe, change
  band and mode, send CW from the function keys, and exit cleanly.
- [x] **Then run the golden corpus** once you have deployed, since the sweep
  touched `LOGSTUFF`, `LOGSUBS2`, `LOGDUPE`, `PostUnit` and `tree` -- the units
  the corpus is built to protect. That is the real regression gate here.

**Two decisions this sweep surfaced, both yours and neither urgent:**

- [x] **EMPTY PROCEDURES.** `DeleteOrMoveLog` (`LOGMENU`), and routines in
  `LOGWAE` and `LOGHP`, had their ENTIRE bodies commented out -- so removing the
  comment leaves `begin end;`. They have been silent no-ops for years while
  still being called. That is a dead FEATURE, not dead text: delete the
  routines and their call sites, or reinstate the behaviour.
- [x] **`StartNewContest` is dead and carries a hardcoded path.** No callers
  anywhere (checked case-insensitively, including `tr4w.dpr` and `test\`), and
  its body is `WinExec('D:\TR4W_WinAPI\out\tr4w.exe', 0)` -- the original
  author's own machine. It could never have worked on a user's PC. Delete, or
  say what it was meant to do.

### 14. The judgement calls -- F5 is DECIDED

**Blocks under 30 lines were left alone deliberately**, along with anything
that looked like a DISABLED RULE rather than replaced code.

**F5 is now answered by NY4I, 2026-08-21: the rule stays disabled.** The
`//n4af 4.38.3` block in `GoodCallSyntax` -- "no digit in positions 2-4",
plus the clause refusing a call that ends in a digit unless it is a
five-character `B...` prefix -- has been DELETED rather than reinstated. So
`GoodCallSyntax` deliberately accepts a letters-only string like `FRED`, and
that is now a decision on the record instead of an accident of a comment.
Nothing to bench; `uTestCallSignRoutines` still passes.

### 15. Launching other programs now goes through one unit  (`07c55fa4`)

`WinExec`/`ShellExecute` were replaced by `uPlatformProcess` -- `RunProgram`
(TProcess, no guard) for programs the operator chose or we ship, and
`RunWindowsUtility` (the only WinExec left, inside a WINDOWS conditional) for
Windows programs. **Behaviour on Windows should be identical**; the point of the
list is that "identical" is the pass condition.

**THE THREE THAT CHANGED SHAPE, and so are worth trying with a path that has a
SPACE in it** -- they used to build `'"%s" "%s"'` by hand and now pass the file
as an argument, so quoting is no longer their problem:

- [ ] **Play** on a QSO in Edit QSO starts the configured **MP3 player** with
  the recording.
- [ ] The **DVK recorder** starts from the program-message editor with the file
  to record.
- [x] **Open in editor** (file preview, history.txt) opens the operator's
  `.txt`-associated program -- and still falls back to Notepad when there is no
  association.

**The rest should be unremarkable:**

- [ ] **Run server** starts `tr4wserver.exe`; **Ping server** pings it. [ AGENT: Confirm how you are pinging the server. When I did it, it tried ::1 so it grabbed the IPv6 address. We should ping the address set in the server address in the config.]
- [x] Calculator, Volume control, Recording control, Device manager, the
  date/time applet, a command prompt, and "show the log folder" all still open.
- [x] **MMTTY** starts with its `-t -s -u -r` switches. It stays Windows-only by
  decision (NY4I, 2026-08-21: not on macOS, and not on Linux either).
- [x] The **WINEXEC** function-key command still runs an operator command line,
  minimised as before.

**A FAILURE NOW SAYS SO.** WinExec's "less than 32 means it failed" was checked
at two of the seventeen old sites, so a mistyped path in the MP3 Player setting
used to do nothing at all with nothing in the log. Both routines log now -- so if
one of these does not start, `tr4w.log` should say why, and that line is worth
reporting.

**The decision that was here is DONE (NY4I, 2026-08-21):** `K6VVA_WK_DEBUG`
and the WinKeyer HTML debug facility are deleted -- *"we now have a wk_debug
extra flag"* -- and the program's last `wsprintf` went with them
(`fb26b49b`). Nothing to test: none of it had ever compiled.

### 16. One callsign validator: IsAGoodCall  (`d3d4d5b3`)

The three callsign REGEXES are gone -- `RX_CALLSIGN`, `RX_US_PREFIX`,
`RX_US_CALLSIGN` -- replaced by hand-written tests in `uCallSignRoutines`.
Measured over 234,467 real callsigns: four times faster than the pattern it
replaced and a strict SUPERSET of it (131 real calls it accepts that the regex
refused, none the other way). 254 of those callsigns are now a test fixture.

- [x] **Operator login** -- confirmed 2026-08-21 (NY4I). The only path whose
  behaviour genuinely changed: lower-case `w1aw` now takes the STRICT US check
  it used to skip, because the old `RX_US_PREFIX` had 'a' twice and no
  lower-case 'w'.
- [ ] **WSJT-X CQ decoding** (`uWSJTX.pas:557`) -- swapped from
  `IsValidCallsign` to `IsAGoodCall`. Marginal calls in the decode list are
  where a difference would show.
- [ ] **DX spots and packet spots** -- the heaviest users of `IsAGoodCall`. The
  tell would be a spot that used to be filtered out and now is not, or the
  reverse. ~~[AGENT - We do not have the concept of a filter in spots.]~~
  **CONFIRMED 2026-08-28 -- correct, and the code agrees.** `uSpotsFilter` and
  `uDXSSpotsFilter` were commented out of `tr4w.dpr` since the initial commit,
  never compiled, and are now deleted (`96d2f2c2`). There is no spot filter to
  test; the item is struck rather than pending.


**If something looks wrong, the benchmark diagnoses it faster than a symptom
will:** `build\Build-Bench.ps1`, then run `test\bench\bench_callsign.exe` over
any list of callsigns -- it reports exactly which ones are accepted and refused,
rather than leaving us to infer it from behaviour.

### 17. LPT CW keying and the YCCC box -- test before any decision

**NY4I, 2026-08-21: "I have Windows users using the LPT port for CW and YCCC box
control so I cannot delete it yet."** Nothing here is a removal candidate. It is
listed so the testing happens before the questions below are reopened.

**Two different dependencies, often spoken of together but not the same thing:**

- **LPT** -- `uIO.pas` loads `inpout32.dll` and drives the parallel port: CW
  keying, PTT, and the paddle / foot-switch INPUTS. `LPT.pas` is the settings
  dialog for the port assignments.
- **YCCC SO2R+** -- `uYCCCSO2R.pas`, a USB **HID** device. Different transport,
  different future.

#### To test

- [ ] **CW keys from the LPT port** at the configured base address, with clean
  timing at contest speed.
- [ ] **PTT asserts and releases** on the LPT line.
- [ ] **The paddle and the foot switch read back.** These are INPUTS on the same
  port, and an input that never asserts looks exactly like an unplugged switch --
  worth testing deliberately rather than assuming.
- [ ] **The YCCC SO2R+ box opens and switches.** HID, so a separate check.
- [ ] **A machine with no `inpout32.dll`** still starts and reports the absence
  ONCE rather than on every attempt (`NoInpOut32Message`; the load is attempted
  at most once by design).

#### The HWND in OpenLPT is a mislabel, not a design problem

An earlier reading of this called the platform seam an API DESIGN decision. That
was wrong, and the body says so:

```pascal
function OpenLPT(var PortHandle: HWND; LPT: PortType): boolean;
begin
  ...
  PortHandle := LPTBaseAA[LPT];    // an I/O BASE ADDRESS -- 0x378, not a window
  Result := True;
end;
```

`PortHandle` never holds a window handle. Every caller passes something that is
plainly an address: `tPaddlePortBaseAddress`, `tBandOutputPortBaseAddress`,
`Radio1.tKeyerPortHandle`. `HWND` is simply the integer type that happened to be
in scope. So the fix is a TYPE CORRECTION -- `HWND` to `Word`, or a named
`TLPTBaseAddress` -- with no behaviour change whatsoever, which is the
type-honesty rule in CLAUDE.md: fix the declaration, do not cast at the call
site.

Worth noting: `src\DLPortIO.pas`, the DEAD predecessor, has the more portable
signature already -- `GetPortByte(Address: Word)`, `OpenDriver: boolean`.

- [ ] **Sequencing is NY4I's call:** correct the type BEFORE the lab test (so the
  binary tested is the corrected one, and it is only tested once), or AFTER (so
  the binary tested is exactly what ships today). It is mechanical either way.

#### DECIDED: what we have today is fine (NY4I, 2026-08-21)

*"I am ok to use what we have today."* So **no LPT work is scheduled** -- not
the seam, not the type correction, not the Linux path. `inpout32` on Windows
stays exactly as it is, and the only open item above is the BENCH TEST.

What follows is recorded because it was investigated, not because it is
planned. It exists so that whoever picks LPT up later starts from the answers
rather than the questions.

#### Linux is possible -- with two real conditions

NY4I, 2026-08-21, pointing at <https://wiki.freepascal.org/Hardware_Access>: the
parallel-port methods there cover Windows AND Linux, and they share TR4W's model
of "read or write a byte at an I/O base address".

|         | how                           | condition |
| ------- | ----------------------------- | --------- |
| Windows | `inpout32.dll` , `Inp32`      | what      |
|         | /`Out32`                      | `uIO`     |
|         |                               | already   |
|         |                               | does      |
| Linux   | `ports` unit + `ioperm()`     | **require |
|         | from libc, or FPC's           | s root**, |
|         | `fpioperm` in unit `x86`      | and is    |
|         |                               | **x86-onl |
|         |                               | y**       |

**Both conditions matter and neither should be designed away.** Asking a contest
operator to run the logger as root is a genuine deployment problem, and
`fpioperm` does not exist on ARM because ARM has no x86 I/O ports -- so a
Raspberry Pi station gets no LPT by this route regardless. `ppdev`
(`/dev/parport`) is the other Linux path and does not require root, but the wiki
does not cover it and it has not been looked at here.

**So LPT moves from GUARD to a candidate for ABSTRACT in Phase 8** -- a seam with
a per-OS implementation behind it, rather than a permanent `{$IFDEF WINDOWS}`.
Not scheduled, and not before the bench test.

#### `src\DLPortIO.pas` stays

668 lines, in no project file, referenced by no unit -- the older parallel-port
driver `uIO` replaced (GM0GAV, 2015: *"Rewrite of uIO to use InpOut32.dll"*).
Dead, but it is the reference for how the previous driver did this, and deleting
it in the week the LPT path gets bench-tested would throw away the comparison
exactly when it might be wanted. Revisit after the test.

### 18. 112 settings now persist to JSON instead of tr4w.ini  (`de15d7c4`, `cfcba0f8`)

**This is the one to test first, and your read-only `tr4w.ini` is the perfect
rig for it.** Before tonight, 153 settings appeared in Preferences, applied
immediately when changed, and wrote `tr4w.ini` -- which on your station is empty
and read-only, so they silently reverted on restart. `DE ENABLE` was the one you
noticed. 112 of them now write `settings\tr4w.json`.

- [x] **`DE ENABLE`, the worked example.** Change it in Preferences, close TR4W,
  reopen. It should still be what you set. Before tonight it would not have been.
- [ ] **Two or three others from different panels** -- say `ROW COUNT` (a
  drop-down, `ckArray`), `AUTO-CQ DELAY TIME` (an integer), and any check box.
  Same test: set, restart, still set.
- [ ] **Hand-edit one in `settings\tr4w.json`**, as you did to verify the radio
  settings, and confirm TR4W honours it on the next start.
- [ ] **The log should be quiet.** `[ApplyStoredCommands] CFGCA refused "X" =
  "Y"` in `tr4w.log` means a stored value the row will not accept -- that is the
  failure mode of this change and it names itself. Worth one grep after a
  session.
- [ ] **A setting you have NOT touched keeps its old value.** The seeding path
  (`MIGRATED_COMMANDS`, 214 entries now) carries an existing `tr4w.ini` value
  into the store once, so an operator upgrading does not silently revert to
  compiled defaults. Your station has an EMPTY ini, so this one is better tested
  on a machine with a populated one.

**A failure now says so.** `SetCFGCommandValue` checks the ini write result --
it never did -- so a setting that cannot be saved reports "applied but could NOT
be saved" instead of vanishing quietly.

**Still on the ini, deliberately: 41.** Thirty are `ckList` rows that Preferences
renders READ-ONLY, so they cannot be edited at all yet; the rest are read-only
rows, an action trigger (`CLEAR DUPE SHEET`), the band plan, and the LPT port.
Each reason is written down in `docs/CFG_MIGRATION_PLAN.md`, along with what
unlocking the `ckList` thirty would take and the padding trap that makes it
delicate.

### 19. The `ckList` rows are editable for the first time  (21 more settings to JSON)

**These rows have NEVER been editable in Preferences.** They rendered as
disabled boxes because `CFGCommandAllowedValues` returned nothing for a `ckList`
row, and a row with no allowed values is forced read-only. They are drop-downs
now, and 21 of them store to `settings\tr4w.json` instead of `tr4w.ini`.

- [ ] **Three station settings, set and restart:** `HOUR DISPLAY`,
  `RATE DISPLAY`, `DUPE CHECK SOUND`. Each should be a drop-down, take effect,
  and still be what you set after a restart. Before today none of that was true. [AGENT - I am changing these but do not see any evidence of a change on the main window]
- [ ] **`MP3 RECORDER DURATION` and `BAND MAP SPLIT MODE`** -- same test, and
  the second one has a redraw handler (`crP: 1`), so the band map should change
  WITHOUT a restart.
- [ ] **A Cabrillo category, e.g. `CATEGORY-POWER`.** These are contest-scoped.
  Set one, then load a contest `.cfg` that names the same key: **the contest
  must win.** That precedence already existed (`CommandCameFromContestCFG`);
  this is confirming the migration did not disturb it.
- [ ] **`tr4w.log` should be quiet.** `[ApplyStoredCommands] CFGCA refused` names
  a stored value a row will not accept -- the failure mode of this change.

**The mixed-case fix is the one to watch for surprises.** Six spellings across
the whole program are not all-caps -- `All`, `Yes`, `No`,
`Indonesian Districts`, `NC QSO Party`. The config loader uppercases every line
before parsing, and the matcher compared case-SENSITIVELY, so those six could be
written and never read back. That was the whole of the
`SINGLE BAND SCORE=All` -> "Invalid statement in config file" failure of
2026-08-16. The matcher now folds case.

- [ ] **Load a few real contest `.cfg` files** and confirm no
  "Invalid statement in config file" and no new `[Config] ... was REFUSED`
  lines. The golden corpus (22/0/4) covers 13 of them already; this is about
  configs the corpus does not carry.

**Two defects found while doing this, NEITHER fixed -- they need a decision:**

1. **`QSOPointMethodArray` has two identical `'ONY'` entries** (`VC.pas:3264`
   and `:3319`). Only the first is reachable by name, so one QSO-point method
   cannot be selected by spelling and shows the wrong label. Aligning the array
   to the enum did not reconcile (133 members vs 136 entries), so which value is
   mislabelled needs a read rather than a guess.
2. **`SetCFGCommandValue` ignores `crC`.** Ctrl-J wrote a contest-scoped row to
   the contest `.cfg` (`uOption.pas:851`); Preferences writes every row to
   `tr4w.ini`. So a contest-scoped setting edited in Preferences was written to
   the wrong file and lost on the next start, silently. The 11 migrated today
   are out of that path; the rest go when the remaining 20 do.

### 20. 15 more settings to JSON -- ini count now 5, and the risky ones are here

The rule used was the table's own: **`crC` says which FILE owns the value.**
`crC=0` means the station file, which today is `tr4w.ini`, so those must move.
Only `BAND` and `SINGLE BAND SCORE` are `crC=1` (contest-owned) and stay for the
contest file.

**These 15 are read-only in Preferences, so nothing can be tested by changing
them.** That is exactly why they need watching: their values arrive only through
the config parser reading a file, and the file just changed.

- [ ] **The multiplier and scoring rows are the ones to watch:**
  `DOMESTIC MULTIPLIER`, `DX MULTIPLIER`, `PREFIX MULTIPLIER`, `ZONE
  MULTIPLIER`, `QSO POINT METHOD`, `EXCHANGE RECEIVED`, `CONTEST`,
  `CONTEST NAME`. Start a contest of each kind you care about and confirm the
  multipliers and scoring are what they should be. **If a stale value were being
  applied over the contest's, wrong SCORING is how it would show** -- not an
  error message.
- [ ] **The golden corpus covers 13 contests and is green (22/0/4)**, so this is
  about contests the corpus does not carry.
- [ ] **QUICK QSL messages x5 and `REMINDER`** -- confirm the quick-QSL message
  still sends what it used to.
- [ ] **`PADDLE PORT`** is the one genuinely editable row in this batch. Set it,
  restart, confirm it stuck.

**Why this should be safe, and what would disprove it:** nothing in the program
writes these keys -- there is no writer for any of them outside CFGCA -- so a
value only ever came from a file line. `MIGRATED_COMMANDS` carries an existing
`tr4w.ini` value into the store once, and the contest `.cfg` still overrides via
`CommandCameFromContestCFG`. Equivalent to today, minus the ini. A contest whose
multipliers come out wrong disproves it.

**Still on the ini, 5:** `CLEAR DUPE SHEET` (an ACTION trigger --
`@ClearDupeSheetCommandGiven` -- persisting TRUE would clear the dupe sheet on
every start), `BAND` and `SINGLE BAND SCORE` (contest-owned, going to the SQLite
contest file), and `BAND MAP CUTOFF FREQUENCY` + `FREQUENCY MEMORY` (multi-valued
`ctFreqList`, needing a JSON home for the whole `[BAND PLAN]` section).

**Sections still ahead before `tr4w.ini` can be deleted:** `[BAND PLAN]`,
`[COLORS]` (~112 elements x 2, and the reason Ctrl-J cannot be deleted yet),
`[WINKEYER]`, and `uNewContest`'s `MAIN CALLSIGN` read.

### 21. The band plan moved to JSON -- and its file finally says what it means

`[BAND PLAN]` in `tr4w.ini` is gone. `settings\tr4w.json` now holds:

```json
"bandPlan": { "160": { "cutoff": 1800, "cw": 1815, "ssb": 1845 } }
```

**Why this was the awkward one.** The ini held REPEATED keys -- twelve
`BAND MAP CUTOFF FREQUENCY=` lines and up to twenty-four `FREQUENCY MEMORY=`
ones -- with the band DERIVED from each frequency, and the phone memory told
apart from the CW one by an `SSB ` prefix inside the VALUE. Nothing in that file
said which band a line was for, so a frequency in the wrong band was invisible.
It is also why these two rows could never be ordinary settings.

- [ ] **Open the band plan editor, change one cutoff, OK, restart.** It should
  stick, and `settings\tr4w.json` should show it under `bandPlan`.
- [ ] **Look at the file.** Every band you have set should be there and read
  sensibly. A band with no values should be ABSENT rather than three zeros --
  absent means "leave that band alone", which is what an empty cell means.
- [ ] **The seed, which is the part with a real risk.** If you still have a
  `tr4w.ini` with a `[BAND PLAN]` section, TR4W reads it ONCE into the store
  (`[BandPlan] seeded N band(s) from tr4w.ini` in the log) and never again.
  **Check the seeded values land on the right bands** -- the seed re-derives the
  band from each frequency exactly as the old loader did, and that arithmetic is
  the one thing that could put a memory on the wrong band.
- [ ] **A contest `.cfg` carrying `FREQUENCY MEMORY` lines must still win.** The
  store is skipped for whichever of the two keys the contest names, the same
  rule `ApplyStoredCommands` uses. Load such a contest and confirm its memories
  are in force, not your station ones.
- [ ] **The band map mode cutoff still splits CW from phone** on each band.

**Note for a station with no `tr4w.ini`:** the seed reads nothing, so the band
plan starts from the compiled defaults. Set it once in the editor.

**Settings still on the ini: 3.** `CLEAR DUPE SHEET` (an action trigger, must
never persist), and `BAND` + `SINGLE BAND SCORE` (contest-owned, going to the
SQLite contest file). No station setting writes `tr4w.ini` any more.

**What still does:** `[COLORS]` (~112 elements x 2, and the reason Ctrl-J cannot
be deleted), `[WINKEYER]`, and `uNewContest`'s `MAIN CALLSIGN` read.

### 22. Colors moved to JSON, and Ctrl-J is GONE

`uOption.pas` is deleted -- 960-odd lines, the last Win32 settings dialog. What
kept it alive was the Colors editor, which was never a Ctrl-J filter at all: it
was a different dialog wearing the same window, built from
`TWindows[TMainWindowElement]`, two rows per element, saved to `[COLORS]` in
`tr4w.ini`. Preferences now has a **Colors** page under Appearance.

**Why `[COLORS]` in the ini ever worked, which is worth knowing:** the config
loader is SECTION-BLIND. It reads every line of `tr4w.ini` in order regardless
of which `[SECTION]` heading it sits under. That is also what made the migration
exact -- the seed copies out of `TWindows` AFTER the load, so whatever the ini
said is already in force and there is no second parser to disagree with.

- [x] **Appearance -> Colors.** Fifty elements, each with a Text and a
  Background drop-down from the 18-color palette. Change one, OK, and check it
  repaints. Restart and check it stuck.
- [x] **Look at `settings\tr4w.json`** -- a `colors` object keyed by element
  name, values as SPELLINGS (`"YELLOW"`, not `15`).
- [x] **Your existing colors must survive.** On first run with an old
  `tr4w.ini`, the log should say `[Colors] seeded 50 element(s) from the loaded
  configuration` and the window should look exactly as it did.
- [x] **Ctrl-J.** Every menu route that used to open the old list -- Ctrl-J
  itself, Appearance, Colors, WinKeyer -- must open Preferences and nothing
  else. Nothing should open an empty list, and nothing should fail to open.
- [ ] **`QuickEditResponse` prompts still parent correctly.** They used to
  prefer `settingswindowhandle`, which only existed while the old dialog was
  open; that branch is gone and they parent to the main window. Trigger one
  (any prompt that asks for a value) and confirm it appears where it should.

**A stranding check that came out clean:** measured against comment-stripped
source there are ZERO live `csOld`/`csNew` rows -- every live row is `csOwned`,
`csJSON` or `csRem`. So no setting lost its only editor when Ctrl-J went. Six
rows LOOK like csOld in the raw file (`DISPLAY REFRESH`, `MULTIPLIER ITEM
WIDTH`, four `TAIL END *`), and all six are commented out.

**Counts that fell as a result:** ini writes 7 -> 6, ini reads 10 -> 8, Win32 UI
call sites 245 -> 236, non-UI platform 110 -> 107.

**What still touches `tr4w.ini`, and it is now only the seed path:** the
one-time readers that migrate an existing installation, plus three CFGCA rows --
`CLEAR DUPE SHEET` (an action trigger that must never persist) and `BAND` +
`SINGLE BAND SCORE` (contest-owned, going to the SQLite contest file).

### 23. TR4W offers to remove tr4w.ini -- once -- and the first resourcestring

Every station setting is in `settings\tr4w.json`. What remains of `tr4w.ini` is
a file read ONCE per installation to carry an existing configuration across, and
never again. So TR4W now asks, one time, whether to remove it.

**The wording states what has already happened before it asks for anything.** An
operator told "may I delete your configuration" reasonably says no; an operator
told "your settings have already been copied, this file is no longer read" can
answer the question actually being asked.

- [ ] **On a station WITH a `tr4w.ini`:** start TR4W. The prompt should appear
  once, after the window is up. Say **No** -- it must not ask again on the next
  start, and `settings\tr4w.json` should carry `"keepLegacyIni": true`.
- [ ] **Then flip that back to `false` by hand, restart, and say Yes.** The file
  should be gone and a confirmation shown. **No `.bak` is made** -- that is
  deliberate ("There should not be any backups of the ini or anything else").
- [ ] **Restart again with everything you had set** -- radios, colors, band
  plan, DE ENABLE, auto-send count. All of it must survive the ini being gone.
  This is the real test of the whole migration and the reason to do it on a
  station you can restore.
- [ ] **Make the ini read-only and say Yes.** It should report that it could not
  remove it and carry on -- the file is ignored either way.
- [ ] **A station with no `tr4w.ini` must never see the prompt.**

**The corpus is the automated half of this and is green (22/0/4).** The prompt
sits AFTER the `/EXPORT` Halt in `tr4w.dpr` for exactly that reason: a modal
dialog in headless mode would HANG all thirteen runs rather than fail them.

**First `resourcestring` in the program** (`src\uAppStrings.pas`). New dialogs
and message boxes declare their text there from now on, not as a `TC_` constant
in the nine per-language files. Nothing existing was converted -- that sweep
belongs with the translation work, not a feature commit.

### 24. WinKeyer -- the menu now lands on it, and an upgrading station gets its keyer back

**"Where did all those WinKeyer options go?" (NY4I, 2026-08-21).** Two separate
faults, and neither had lost a setting.

**1. The menu did not go anywhere in particular.** `RunOptionsDialog` has taken
a `CFGFunc` filter since Ctrl-J, and once every filter routed to Preferences the
parameter was ignored -- so Settings > WinKeyer opened Preferences wherever it
was last left. Every filter that names a page now maps to one:

| menu        | page                                  |
| ----------- | ------------------------------------- |
| Colors      | Appearance > Colors                   |
| Appearance  | Appearance                            |
| WinKeyer    | **CW Settings** -- the keying-device  |
|             | library                               |
| Radio 1 /   | Radios                                |
| Radio 2     |                                       |

- [ ] Settings > WinKeyer must land on **CW Settings**, with the keying devices
  list at the top. Pick the keyer, **Edit...**, and all seventeen options are
  there.
- [ ] Settings > Colors, Appearance, and the radio items likewise.

**2. The keyer LIBRARY was never seeded from the legacy settings, and this is
the real one.** The seventeen `WK` rows are `csJSON`, so an upgrading station's
WinKeyer settings were carried into the store and applied into `WinKeySettings`
-- the keyer KEYED correctly. But the editor does not read `WinKeySettings`; it
reads the device library, and nothing ever populated it. So every option was in
force and none could be seen or changed. Rotators already had this seed; keyers
did not.

- [ ] **On a station that had a WinKeyer configured before today:** start TR4W
  and look for `[Keyers] seeded "WinKeyer" from the legacy WinKeyer settings` in
  `tr4w.log`. CW Settings should then list one device.
- [ ] **Open it and check every value against what you had** -- port, keyer
  mode, sidetone frequency, weight, dit/dah ratio, lead-in, tail, first
  extension, key compensation, paddle switchpoint, and the six switches.
- [ ] **It seeds ONCE, into an EMPTY library only.** Restart again: there must
  still be exactly one keyer, not two.
- [ ] **A station that never enabled a WinKeyer must get an empty list** -- not
  a phantom device it has to work out how to delete.
- [ ] **Then key some CW.** The seed writes the device; `ApplyKeyerToWinKey`
  reads it back on the next start, so this is the round trip that matters.

**Note:** there is no "enabled" flag on a keyer DEVICE, deliberately -- whether
the WinKeyer is in use is a property of the PROFILE (`SetWinKeyerEnabled`). The
seed describes the device on the desk and nothing more.

### 25. Overnight 2026-08-22: the main window is a designed form, and two controls moved

Everything below is built, green (9803 unit tests, 21 lints, corpus 22/0/4) and
committed but **not pushed**.

- [x] **The main window still looks and behaves as it did.** It is a designed
  `TForm` now (`uMainForm.lfm`) rather than one built in code. Border, minimise
  box, taskbar button, background colour all moved from Pascal into the designer,
  so this is the check that nothing was dropped in the move.
- [x] **The possible-call list.** Type a partial callsign and watch the row of
  suggestions below the entry fields: same font, same column width, dupes still
  red, the selected one still outlined. It is an LCL `TListBox` now, drawn
  through `OnDrawItem` instead of `WM_DRAWITEM`.
- [x] **A specific thing to watch on that list, recorded honestly:** TR4W fills
  it with raw `LB_ADDSTRING`, so the LCL's own `Items` are empty. Nothing
  recreates the control's handle today, but if it ever DOES the list would go
  blank and refill on the next keystroke. If you see that once, that is what it
  was.
- [x] **Help > About** opens a designed form instead of a system message box, with
  the same content and the website as a clickable link. Check the version and
  date read correctly -- they are composed from the same constants, not typed
  into the form.

**Not done, and each for a stated reason** (docs/ROADMAP.md section 2):

* **The editable log stays a Win32 ListView.** `TListView` caches its rows and
  TR4W does not use that cache -- it inserts with raw `LVM_INSERTITEM` across
  ~150 call sites. The control would show hundreds of rows while the LCL believed
  it had none, and anything that recreated the handle would rebuild it from the
  empty cache: **a blank log, mid-contest, with no error.** Converting it means
  moving those call sites to the `Items` API, with the log-dump harness proving
  rows survive.
* **The three remaining Win32 dialogs are all entangled** -- CAT is 2570 lines and
  actively maintained, Missing Mults builds a runtime grid of child windows, and
  Get Server Log embeds the editable log and so is blocked on the same work.
* **`Application.Run` is still gated on the band map and the function-keys
  window**, not on the main form.

### 26. The function-keys window is an LCL form -- TEST THIS ONE PROPERLY

**This window sends CW.** It is the first `tw_` tool window converted, two of the
three message-loop arms blocking `Application.Run` went with it, and none of it
is provable by build. Please give it a real session.

- [x] **F1 through F12 send.** Click each button and confirm the right message
  goes out -- this replaced `WM_COMMAND` / `BN_CLICKED` with `OnClick`, and the
  key code now comes from the panel's `Tag` rather than the control id.
- [x] **The CQ and S&P banks both show the right text.** Toggle mode and watch
  the captions change. `ShowFMessages` drives them now by setting `Caption`
  instead of invalidating an owner-draw.
- [ ] **Ctrl and Alt banks.** Hold Ctrl, then Alt, and confirm the captions
  switch to those banks and back on release. [AGENT - When I press CTRL in the main window, the function key labels do change but when I unkey CTRL, they do not restore to their original non-CTRL setting. Same for ALT.]

  **INSTRUMENTED 2026-08-28 (`pending`), not yet fixed -- and deliberately so.**
  The press and the release are handled in two DIFFERENT places: the press by
  the entry field's `OnKeyDown` (`uMainWindowProc`, `ShowFMessages(12)` for
  Ctrl and `(24)` for Alt), the release application-wide in
  `uAppInputHooks.UserInput`, which watches a `GetKeyState` TRANSITION and
  calls `ShowFMessages(0)`. Both are wired and installed, so which half is
  missing decides the fix and the two look identical from the outside.

  It cannot be reproduced from the harness: `Test-Typing` drives keys with
  `PostMessage`, which does not move the real keyboard state `GetKeyState`
  reads, so a modifier HOLD cannot be simulated. Driving it with `SendInput`
  would type into whatever has focus on NY4I's desktop.

  So `DEBUG LOG LEVEL = DEBUG`, press and release Ctrl, then Alt, and send the
  `[Modifiers]` lines. Two lines per press means the transition is seen and the
  restore ran -- the fault is then in `ShowFMessages(0)` itself. No second line
  means the release never reaches the handler, which is a different fix.

- [ ] **AN AMPERSAND IN A CW MESSAGE.** Put `&` in an F-key message and check it
  shows as one `&`, not none and not two. `ShowFMessages` deliberately doubles
  it; a `TPanel` caption treats `&` the same way the owner-draw did, so the
  doubling had to stay. This is the single most likely thing to be wrong.
- [x] **Right-click a key** -> the one-item context menu, opening the editor on
  the RIGHT row. Do it while holding Ctrl and again holding Alt: the bank is read
  before the menu pops, precisely so releasing the modifier to click the menu
  does not change the answer (Issue #1001).
- [x] **Right-DOUBLE-click a key** -> the Alt-P editor straight to that row.
- [x] **The layout.** Twelve buttons across the width, with a wider gap after F4
  and after F8, resizing with the window. That arithmetic was copied unchanged
  from the Win32 `WM_SIZE` handler.
- [x] **Colours.** F1-F4 white, F5-F8 yellow, F9-F12 as before -- straight from
  the same `ButtonsColor` table the owner-draw read.
- [x] **The window still docks and remembers its place**, and closing it from the
  menu still works. It goes through the same `WndRect` / `WndVisible` /
  `CloseTR4WWindow` path as before; only the creation changed.
- [x] **Escape still belongs to the callsign field** while this window is open --
  it must NOT close the F-key row.

**What is left before `Application.Run` can replace the message loop:** the band
map's `WM_KEYUP` arm, and nothing else. That is the next piece of item 1.

**Follow-up noted, not done:** `FunctionKeysWindowDlgProc` is no longer reached
for this window, but it is still registered in `tr4w_WindowsArray[..].WndProcAdr`
and this tree's rule is that unreachable-looking is not proof. Retiring it is a
separate, deliberate step.

### 27. Band map step 1: the model, before any form exists

**No UI change.** The band map is still the Win32 window; what changed is
underneath it. Design at `docs/BANDMAP_LCL_DESIGN.md` -- these are the three
defects that were provable by reading and did not need the new form.

- [x] **THE BIG ONE -- spots no longer vanish while the band map has focus.**
  Connect to a cluster, click INTO the band map list and leave it focused
  for a minute or two on a busy node, then click away (or into the callsign
  window). **Every spot that arrived while you were looking should now be
  there.** Before this change they were gone for good: `AddSpot` returned
  before inserting, and the buffer that was supposed to replay them was
  never filled by anything -- `InsertSpotBuffer` was declared, defined and
  never called. Cross-check against the telnet console, which always showed
  the lines.
- [x] **The rows still hold still while you have focus.** That half was
  deliberate and is kept -- the freeze now applies to the VIEW only. If the
  list starts re-sorting under the mouse, that is a regression.
- [x] **Ordinary spot flow is unchanged** -- new spots appear within about a
  quarter second, no more flashing than before, no less.
- [x] **The VFO cursor line still tracks the radio.** `uRadioPolling` used to
  set a global flag; it now calls `SpotsList.RequestRepaint`.
- [ ] **A logged QSO still turns its spot into a dupe**, and clearing the dupe
  sheet still un-dupes them.
- [x] **Deleting a spot** from the band map's context menu still works and the
  list is intact afterwards -- `Delete` had `try ... finally
  CriticalSection.Leave` with **no matching `Enter`**, so it released a lock
  it never took. Fixed here. This is the one item where a latent
  intermittent (two threads in the list at once) becomes less likely rather
  than visibly different, so there is nothing to see -- just confirm delete
  behaves.

**Added after the first bench attempt (NY4I, 2026-08-22 evening) -- the band map
showed nothing at all.** Three separate things, and the log settled all of them.

- [x] **BAND MAP ENABLE is RETIRED. Opening the window is what enables it.**
  `settings\tr4w.json` held `"BAND MAP ENABLE" : "FALSE"`, so
  `DisplayBandMap` refused every spot at the gate -- the log showed
  `BandMapEnable=0, BandMapWindowExists=1, FCount=49`: the spots were
  arriving and being thrown away. The cause is that one boolean was both the
  persisted setting AND the window's runtime flag, and `WM_DESTROY` wrote
  False to it -- so **closing the band map turned the feature off and the
  next settings save persisted that.** Opening Preferences to change the
  cluster re-applied the stored FALSE over the live TRUE.
  `BandMapEnable` is now a function returning
  `tWindowsExist(tw_BANDMAPWINDOW_INDEX)`, the command is `csRem`, and the
  Preferences checkbox is gone. **Test: open the band map -- spots should
  appear. Close it and reopen it, repeatedly, including with a trip through
  Preferences in between. It must never go dead again.** The stale FALSE
  still in your json is now ignored rather than obeyed.

- [x] **The Preferences band map page lost a row.** "Show the band map" is gone
  and everything below it moved up 38px. Check the page still reads
  properly and nothing is clipped or overlapping.

- [ ] **The log should be readable again.** 1,287 of the 9,810 lines in that
  run were `[DisplayBandMap]` trace, ~2,600 of them before the window even
  existed -- my regression: the repaint token stays raised until Display
  actually paints (deliberately, so spots that arrive while the window is
  shut are drawn when it opens), but with no window it never paints, so the
  250 ms timer called `DisplayBandMap` forever. The timer now returns early
  when there is no band map window, WITHOUT consuming the token. **Test:
  run for a few minutes with the band map CLOSED and confirm `tr4w.log` is
  not full of `[DisplayBandMap]` lines.**

- [x] **Minimise TR4W with the band map open and a busy cluster running.** The
  tool windows are owned popups, so Windows hides the band map with its
  owner -- and until now that hidden window still cost a full render four
  times a second. The refresh timer now skips a window that is not visible.
  **Restore TR4W and every spot that arrived while it was down should be
  there immediately**, because the skip does not consume the repaint token.
  Watch for a stale or empty list on restore; that would mean the token
  logic is wrong.

- [ ] **Leave it minimised over a decay boundary** (a minute or more). Spot ages
  must still advance -- `DecrementSpotsTimes` is model work and still runs;
  only its repaint waits. Restore and check the age colours are right, not
  a minute behind.

- [ ] **NOT tested and deliberately not implemented: occlusion.** If another
  window is simply sitting on top of the band map, TR4W still repaints it.
  Windows will not answer "am I covered" reliably and guessing would trade
  a real repaint for a maybe-saved one.

- [x] **DX cluster logging was never broken** -- 56 `[Telnet RX]` lines were in
  that log, buried under the flood above. Nothing to fix; noted so it is
  not re-reported.

**What did NOT change, deliberately.** `UpdateSpotsMultiplierStatus` still runs
on the paint path -- a CTY prefix resolution per spot per repaint. Moving it
needs the full list of places the LOG changes, and `UpdateWindows` demonstrably
covers QSO-logged, log-load, network QSO and WSJT-X but **not** an in-place log
edit. A stale multiplier flag shows up as WRONG SCORING, not as an error, so it
is carved out into its own change rather than guessed at here.

### 28. The band map form, and three defects the bench run found

The band map is an LCL form (section 27 covers the model work underneath it).
Everything here was found by NY4I running it on 2026-08-22/23, and none of it
was visible to a lint or a unit test.

- [x] **Status bar panel count.** The .lfm declared four panels; the code
  indexed six. `List index (5) out of bounds` came out of the form's
  OnCreate, so the CONSTRUCTOR never completed and TR4WBandMapForm stayed
  nil -- which presented as an empty band map with no context menu rather
  than as a wrong status bar. There is a `SB_PANELS` check at create now
  that names the mismatch instead.
- [x] **A form shown by SetWindowPos is not Visible to the LCL.** Every tw_
  window is shown with a raw `SWP_SHOWWINDOW` on an HWND, which the LCL
  cannot see, so `TForm.Visible` stayed False while the window was on
  screen: the refresh timer skipped every tick and the LCL never showed the
  child controls. `OpenTR4WWindow` now tells the LCL, once, for whichever
  form the seam built -- so the next tool window to convert inherits it.
  **The same note already existed on ShowTR4WMainForm**; it is the second
  time this has been discovered.
- [x] **Re-test the band map end to end** now those are fixed: resize wide and
  narrow (the columns reflow -- it is a newspaper layout, widening shows
  MORE spots), a spot arriving while a row is selected, a split spot that
  is also a dupe, double-click and Enter both tuning, Ctrl-End landing
  focus in the grid, and Delete.

### 29. Preferences: two defects, one of them the reason settings did not stick

- [x] **THE LOAD GUARD DID NOT NEST.** `FLoading` was a plain boolean and
  nested loaders each set it True and then set it **False** on the way out.
  `ShowSelectedCluster` and `ShowSelectedRotator` both do that, and
  construction calls both before `FBindings.LoadAll` -- so the guard was OFF
  for the rest of construction, the bindings' change events fired, and
  `CaptureProfileFields` wrote every panel's UNLOADED controls back over the
  store. A check box the operator had turned on came back off because
  construction saved False over it from an unticked box and then read that
  False back. It is now a DEPTH COUNTER, which an inner scope cannot clear.
  **Test: set the logging check boxes, restart, and confirm they hold** --
  and the same for anything on a panel loaded after the cluster and rotator
  lists.
- [x] **An empty handler is not the same as no handler.** `cbxLogLevel` and
  `cbxRelayPort` had do-nothing OnChange stubs, and `HookDirtyMarker`
  attaches its MarkDirty only to a control with NO handler -- so merely
  existing stopped them marking the form dirty: Apply stayed greyed, the
  close prompt never appeared, and the edit went in silence. Both now mark
  dirty without applying, so Cancel still discards.
  **Test: change the log level alone, close, and it should offer to save.**
- [x] **Preferences vanished behind TR4W after switching to another program.**
  It had no PopupParent, and pmAuto resolves to `Application.MainForm`,
  which is nil here because TR4W never calls `Application.CreateForm`. So
  it was a top-level window owned by nothing. `OwnFormByMainWindow` now
  owns it, like every other form.

**Audited while there, and clean:** every other control on Preferences either
reaches `Dirty` through its handler or is picked up by `HookDirtyMarker`, whose
arms cover every control type the form actually uses. The remainder of the
report is buttons, which do their own work, and navigation, which is excluded
on purpose.

### 30. Application.Run -- THE PIVOT.  Test this harder than anything before it

**TR4W no longer owns its message loop.** `Application.Run` does. Nothing in
this section is provable by a build, a lint or the corpus -- the corpus runs
headless `/EXPORT`, which halts before any GUI init, so it says nothing at all
about this change. Branch `phase3c-application-run`.

**If something feels wrong that is not listed here, say so before rationalising
it.** Four things that used to be answered by one loop are now answered by four
different LCL mechanisms, and the failure mode of each is "a key does nothing"
rather than a crash.

- [x] **EVERY MENU SHORTCUT.** All 101 rows of `ACCELERATORS` are now matched in
  an `AddOnKeyDownBeforeHandler` instead of by `TranslateAccelerator`. Work
  down the menus and try the ones you actually use -- Alt+X, Ctrl+J,
  Ctrl+Alt+B, Ctrl+W, the Ctrl+Shift+digit window shortcuts. A shortcut that
  does nothing is the signature failure of this change.

  - [ ] **Ctrl+Shift+0 (MP3 recorder) does nothing** -- NY4I, 2026-08-26,
    while Ctrl+Shift+9 (Stations) works. **Investigated 2026-08-26 and NOT
    resolved by reading.** The two `ACCELERATORS` rows are identical in
    shape (`acKey $30`/`$39`, same modifiers, both `acInstall: true`), the
    matcher compares them the same way, and posting `WM_COMMAND 10216`
    directly DOES open the window -- so the open path is sound and this is
    a keystroke question. There are two candidate causes and they are
    indistinguishable from outside: the key reached the hook and matched
    nothing, or **Windows took it first** -- `Ctrl+Shift+<digit>` is a
    standard keyboard-layout switch hotkey when more than one layout is
    installed.

    `uAppInputHooks` now logs every MODIFIED keystroke it sees at TRACE
    (`[InputHooks] key $30 ctrl=1 alt=0 shift=1 -> no accelerator`), which
    separates them **in one run**: set `DEBUG LOG LEVEL = TRACE`, press
    Ctrl+Shift+0, and look. **No line at all means the program never saw
    the key** and the fix is in Windows' settings, not here.
- [ ] **The same shortcuts with a TOOL WINDOW focused.** The handler is
  application-wide by design, so Ctrl+Shift+1 should open the dupe sheet
  whether the callsign field or the band map has focus.
- [ ] **Ctrl-C / V / X / A / Z in the DX cluster command field** must still
  paste and copy, NOT fire Execute Config File or Clear Mult Sheet
  (issue #23). This is now a focus test rather than a message test. [AGENT - ESCAPE closes the dxcluster without confirmation - That is too drastic a step. We should confirm. Also note that after this, when I selected the now unchecked DX Cluster from the Windows menu, the window did not appear. But looking at the menu again, it was checked. I had to select a now-checked DX cluster option for it to appear. Selecting the unchecked DX cluster in the window should ALWAYS show the window - goes for all others too]
- [ ] **The numeric keypad as CW memories**, if you use them
  (`KEYPAD CW MEMORIES`). They fire whatever has focus.
- [ ] **F10 does nothing**, as before -- it must not open the menu bar.
- [ ] **The F-key labels follow Ctrl and Alt.** Hold Ctrl: the alternate bank
  shows. Release: the plain one comes back. This is the arm with the largest
  change in mechanism -- the loop watched for a key-up whose key WAS Ctrl or
  Alt; there is no application-wide key-up hook, so it now watches the
  modifier state TRANSITION through `OnUserInput`. Watch for labels that
  stick on the wrong bank.
- [ ] **QUICK QSL -- and a deliberate narrowing.** `\` and `=` still QSL while
  you are typing a callsign. They no longer fire while a TOOL WINDOW has
  focus: type a call, click into the band map, press `\` -- nothing happens,
  where it used to QSL. There is no application-wide KeyPress hook, and
  QuickQSL does nothing unless the call window has text, so it moved onto
  the entry fields. **If that edge case matters to you, say so** -- it can
  come back, at the cost of a `VkKeyScan` and a keyboard-layout assumption.
- [ ] **A fault must not take the session down.** The recovery wrapper is an
  `AddOnExceptionHandler` now, same 10-faults-in-a-minute limit. Hard to
  provoke deliberately; what to watch for is the OPPOSITE failure -- a
  dialog appearing for an exception that used to be swallowed and logged.
  `grep AppException tr4w.log`.
- [ ] **Shutdown.** `HamScoreShutdown` moved into `tr4w_ShutDown`. It was a
  `finally` below the message loop, which **could never have run**: TR4W
  exits through `ExitProcess`. So this is the first build in which the
  HamScore uploader is actually stopped cleanly -- watch for a hang or a
  delay on exit that was not there before.
- [x] **Long soak.** Leave it running for a session with a cluster connected.
  The loop had its own fault recovery for a reason.

**Still Win32, deliberately, and not blocked by any of this:** the main menu is
a raw `HMENU` of ~181 items attached with `SetMenu`, and it stays one. The
accelerator handler reads the same `ACCELERATORS` table the menu captions are
drawn from, so there is still ONE source of truth and the menu can convert on
its own schedule rather than being dragged into the pivot.

### 31. The dupe sheet is a form and a TDrawGrid  (`uDupeSheetForm`)

NY4I confirmed the window itself on 2026-08-24 -- both sheets open, refill on a
worked station, follow band and mode, resize and close on Escape. **What is
below was changed AFTER that sitting and he was remote when it landed, so none
of it has been seen.**

- [ ] **The title, on a REOPEN.** Open a dupe sheet, close it, open it again.
  Both times it must read `Radio 1 Dupesheet - 10m-CW`. The first open was
  always right; it was the second that showed the bare menu text (NY4I:
  "it just states Radio 1"), because `OpenTR4WWindow` wrote the native title
  with `SetWindowTextW` behind the LCL's back and left `Caption` stale, so
  the form's own later assignment of the SAME string was compared, found
  equal, and dropped.
- [ ] **The stations window title, on a reopen** -- same fix, same mechanism,
  and it had the identical latent bug: "Stations in CW mode" is likewise the
  same string every time it is set. Must not revert to the menu text.
- [ ] **Every other converted tool window still gets its caption.** The fix is
  in the GENERIC opener, so the band map and the function-keys window take
  the new path too. They must still be titled from the menu.
- [ ] **Two dupe sheets at once, both correct.** This is the first converted
  window with more than one instance. Open both, work a station on each
  radio's band, and check each sheet shows ITS radio's calls with ITS radio
  in the title.
- [ ] **Retirement of `COLUMN DUPESHEET ENABLE`.** Setting it in a `.cfg` or
  `tr4w.ini` must still LOAD WITHOUT AN ERROR (it is `csRem`, not deleted)
  and must have no effect. It must not appear in Preferences. `tr4w.json`
  may still hold the key from before the retirement; that is inert.

**Not asking whether it opens** -- see the note at the head of this file.

### 32. The stations window scales; the dupe sheet reflows  (`uStationsForm`, `uDupeSheetForm`)

Two DIFFERENT resize behaviours, deliberately, and the pair is worth one look
side by side because getting them backwards would be easy to miss:

- [x] **Stations SCALES.** Fixed columns; the font grows with the window and the
  columns are sized from the font that was applied, floor 7pt, ceiling 28pt.
  Widen it and the text gets bigger; there must be no grey strip to the
  right of the last band column at any width.
- [x] **The dupe sheet REFLOWS.** Widening it gives MORE COLUMNS of the same
  size, not bigger cells -- which is what `LB_SETCOLUMNWIDTH` did, and what
  scanning for a callsign wants.
- [x] **The 28pt ceiling is mine, not NY4I's** (he asked only for a minimum).
  Maximise the stations window and say whether 28pt is the right stopping
  point.

### 33. Band change now says why it refused  (`TC_BANDCHANGEDISABLED`)

- [x] With `MULTIPLE BANDS = FALSE` and at least one QSO logged, Alt-B / Alt-V
  and the Band Up / Band Down menu items must show
  "Band change requires MULTIPLE BANDS = TRUE once the log has QSOs"
  instead of doing nothing in silence. Same for anything that reaches
  `GoToBand` -- a band map click, for instance.
- [x] With `MULTIPLE BANDS = TRUE`, no message and band change works as before.

The CAUSE of NY4I hitting this is not fixed here and is not meant to be: a
`csJSON` stored setting outlives contest selection, so `FCONTEST.PAS`'s
per-contest initialisation never took effect on a newly selected CQ WW. NY4I
owns that -- the contest factory harvests those states.

### 34. The entry fields colour themselves  (`RefreshEntryFieldColors`)

Confirmed by NY4I on 2026-08-24 for search-and-pounce green, overtype with
Insert off, and a palette change. Left here for ONE case that sitting did not
cover: [AGENT - Is it possible to arrange this dialog to show in the table a sample of the text and background?]

- [x] **A colour change made while the program is running, from Preferences,
  with the operator IN search-and-pounce.** The exchange field must stay
  green rather than snapping to the new normal background, and must take the
  new background when S&P is left.

### 35. Super Check Partial is a form, and the dupe sheet moved under it  (`uMasterForm`, `uCallGrid`)

**Neither has been seen since this change.** The dupe sheet WAS confirmed on
2026-08-24 (section 31) and was then refactored onto the shared `TCallGrid` --
so its confirmation no longer covers the code that runs. Re-check both.

- [x] **SCP fills as you type.** Type three or more characters of a callsign
  with the SCP window open; partial matches appear. Fewer than
  `SCP MINIMUM LETTERS` shows nothing, and the window hides itself when the
  callsign is too short, exactly as before.
- [x] **Dupes are painted and the text inverts.** A partial match already
  worked on this band and mode must show in `SCP DUPE COLOR` with white
  text; everything else plain on the window background.
- [ ] **IT STOPS AT WHAT FITS AND DOES NOT SCROLL.** That is the old behaviour
  (`MaxItemsInMasterListBox`), now `TCallGrid.LimitToVisible`. Make the
  window small with a common partial like `K1` and confirm it fills and
  stops rather than growing a scrollbar. Then make it BIG and confirm more
  matches appear -- the capacity is asked for, not cached, so a resize must
  change how many the next keystroke shows.
- [ ] **Opening SCP with `SCP MINIMUM LETTERS` at 0 still sets it to 3.** A
  config write from a window-open; kept as it was, flagged as a shape not to
  copy.
- [ ] **The dupe sheet still behaves as it did in section 31** -- both sheets,
  refill on a worked station, follow band and mode, reflow on resize.
- [ ] **The two windows read the same way.** SCP, the dupe sheet and the band
  map all flow DOWN THEN ACROSS now. Confirm none of them reads across-then-
  down, which would be the one arithmetic slip this extraction could hide.

### 36. All five remaining-multiplier windows are forms  (`uRemMultsForm`)

One dialog procedure served `tw_REMMULTSWINDOW_INDEX` and the four fixed-type
windows; there are five instances of one form class now. **None seen.**

- [x] **Open all five.** Remaining mults, and the DX / zone / domestic / prefix
  windows. Each must show ITS OWN multiplier type, and the generic one must
  follow `RemainingMultDisplay` when you swap it (Alt-M or the menu).
- [ ] **Worked multipliers fade, needed ones are plain.** In `HILIGHT` mode all
  multipliers are listed and worked ones are gradiented to white with white
  text. In `ERASE` mode only NEEDED ones are listed at all. `NONE` empties
  the window.
- [ ] **THE FADE COLOUR IS A QUESTION FOR YOU.** The original picks it with
  `tr4wColorsArray[tr4wColors(Ord(rmt))]` -- the MULTIPLIER TYPE's ordinal
  used as a colour index, so a faded prefix and a faded zone differ for no
  stated reason. It is reproduced exactly rather than "fixed" unseen. Say
  whether the colours are meaningful to you or whether they should become
  one deliberate colour.
- [ ] **Clean sweep.** When every multiplier is worked, the congratulations
  message takes the window.
- [ ] **Column width follows SHOW DOMESTIC MULTIPLIER NAME** on the generic
  window (wider when names are shown or the contest does prefix mults).
  **It does NOT on the other four** -- they were given the base width once
  at creation and never followed the setting. That inconsistency is
  preserved; tell me if it should not be.
- [x] **Work a multiplier and watch it fade without reopening the window.** The
  text and the worked flag are resolved at PAINT time, not at rebuild, so
  this is the check that the resolution seam is wired.
- [ ] **The zone window numbers from 1, except EUHFC which numbers from 0.**

### 37. THE MAIN WINDOW'S FORTY-TWO ELEMENTS ARE LCL CONTROLS — test this like section 30

The single largest visible change of the conversion. Every static on the main
window -- band, mode, frequency, rate, totals, the status indicators, the radio
rows -- was a Win32 STATIC painted by TR4W's own WM_CTLCOLORSTATIC handler.
They are LCL TPanels now and they paint from their own properties. **Nothing
below has been seen.**

**If something on the main window is the wrong color, blank, mispositioned or
the wrong size, this is the change that did it.**

- [ ] **Everything is there, in the right place, at the right size.** Compare
  against a screenshot of the previous build if you have one. The positions
  come from the same TWindows[] table and the same `ws` arithmetic; the
  FONT is now built from the same three numbers instead of an HFONT, and a
  wrong sign on the height would show as visibly larger text.
- [ ] **The sunken borders.** defStyle carries SS_SUNKEN and that is
  `BevelOuter = bvLowered`. With `NO BORDER = TRUE` they should be flat, as
  before.
- [ ] **The QSO number's bigger font.** It is the one element with its own --
  Lucida Console, ws+3. FW_EXTRABOLD has no LCL counterpart and is now
  fsBold; say if it reads lighter.
- [x] **The auto-send arrow.** Down arrow, and it MOVES as the character count
  changes. Set `AUTO SEND CHARACTER COUNT` above 0 in CW.
- [x] **THE FIVE LIVE COLOURS.** These were re-evaluated on every repaint by
  DrawWindows and are now pushed when the state changes. Each needs
  exercising:
  - **PTT** goes red on radio 1, yellow on radio 2, while transmitting.
  - **WSJT-X** green when connected, red when not, and the element hides
    when WSJT-X goes away.
  - **Dupe info** takes its state colour when Alt-D reports a dupe, and
    clears.
  - **Radio 1 / radio 2 rows** turn the alert colour when that radio
    disconnects and back when it reconnects. **This one has no text write
    behind it** -- it rides on a new main-thread job (mtRadioAlertColors),
    so it is the most likely of the five to be missed.
- [x] **The frequency display tracks the radio.** It is written from the
  POLLING THREAD and now travels through uPanelUpdate's coalescing queue
  (puElement) rather than SetWindowTextW on a handle -- because an LCL
  control paints from a property and a handle write would leave it stale.
  Watch it follow the VFO continuously, and go blank on disconnect.
- [x] **Colour scheme changes still reach the main window** (Preferences ->
  colours). RefreshMainWindowColors pushes the elements now.
- [x] **THE INITIAL EXCHANGE FILLS.** With `INITIAL EXCHANGE` set to Zone, type
  a callsign and the zone must appear in the exchange field. Found broken on
  the bench 2026-08-24 (NY4I: "I enter AF4O, the zone in the exchange is
  not displayed... That was working earlier") and fixed the same evening:
  `SetMainWindowText(mweExchange, ...)` reached a nil panel, because the
  creation loop skips `mweiStyle <= 2` and the entry fields are TEdits, not
  panels. Two siblings were dead the same way and are worth checking too:
- [ ] **The exchange field CLEARS when the operating mode changes** (Ctrl-Enter
  between CQ and S&P with something typed in it).
- [ ] **WAE QTC puts the callsign into the call field** (`LOGWAE:177`), if you
  run WAE.
- [x] **Greying still works:** the inactive radio's row in two-radio mode, the
  foot switch and WinKey indicators, and the quick-display FLASH (which is
  still an enable/disable toggle -- see LOGWIND).

### 38. Three injected keystrokes are deferred calls now

Each was a PostMessage into an entry field, and the POST was doing real work --
deferring the action until the current message finished. That deferral is kept
through Application.QueueAsyncCall; what went away is the synthetic keystroke.

- [ ] **The trailing space in the exchange field** (space bar at the end of an
  exchange that does not already end in one).
- [ ] **The foot switch's start-sending key** in CW. Was a WM_CHAR into the call
  field; now calls the field's own key handler.
- [ ] **MMTTY double-click pastes a callsign into the call field AND FOCUSES
  IT.** The focus half never worked: the old code posted WM_SETFOCUS, which
  tells a window it has gained focus rather than giving it focus. If the
  caret now lands in the call field where it did not before, that is the
  fix, not a regression.

### 39. The WSJT-X indicator is driven by domain state  (`uWSJTXState`, `uStateBridge`)

First slice of the domain layer -- one boolean, one writer, one indicator,
chosen because it proves the whole path with almost nothing to get wrong. The
listener thread no longer names a widget.

- [x] **Start WSJT-X: the indicator appears and goes green.**
- [x] **Stop WSJT-X and the box stays RED. FIXED 2026-08-26, wants a look.**
  It used to disappear entirely, which NY4I reported and which was the same
  defect as the box staying red while the link was up: the indicator tracked
  the LINK when it should track the SETTING.

  **The rule now: `WSJT-X ENABLED = TRUE` shows the box, always. Its COLOUR
  says whether the link is live -- green connected, red not.** Disabled
  hides it. NY4I settled it: *"the normal user is not in development mode --
  wouldn't the red indicator show that. We should put WSJTX in that box
  regardless if it is red or green."*

  That also closes the old open question of how long red shows before it
  hides: while enabled, it does not hide.

  **It earns its keep immediately.** A wrong multicast group in WSJT-X
  reaches TR4W as complete silence -- the join succeeds and nothing ever
  arrives (this is exactly what happened on 2026-08-26). Under the old
  behaviour the only sign was a box that was not there, which is
  indistinguishable from the feature being off. Red says it.

  **Check:** enabled with WSJT-X down -> red box; start WSJT-X -> green
  within a heartbeat (~15 s) with no radios needed; untick WSJT-X ENABLED
  in Preferences -> box goes immediately, not at the next heartbeat.
- [x] **Start TR4W with WSJT-X ALREADY RUNNING.** A heartbeat can arrive before
  the main form exists; InstallStateBridge brings the view into line once at
  install for exactly that case, and it is the half most likely to be wrong.
- [ ] **It does not flicker.** A heartbeat arrives every few seconds and setting
  the state to what it already holds must notify nobody.
- [x] **DISABLE WSJT-X IN PREFERENCES AND THE BOX GOES OUT. CONFIRMED
  2026-08-24 (NY4I): "restarted it, box goes out now."** First bench
  confirmation of the domain layer -- state object, notification, bridge and
  view, end to end.
  Original report and fix: Found on the bench
  2026-08-24 and fixed the same evening: `Stop` closed the sockets without
  telling `WSJTXState`, so the indicator stayed GREEN with nothing behind
  it. The state is cleared in `Stop` now, before the sockets close and
  outside the `started` guard. **Re-enable and confirm it comes back green
  when the first heartbeat arrives -- not the moment the server binds.**
- [x] **Saving Preferences with WSJT-X disabled no longer logs
  `JoinMulticastGroup called but UDP server not active`.** It fired on every
  Save. A warning that appears during correct operation is one people learn
  to ignore.

  - [x] **DONE 2026-08-26 -- config changes are logged at DEBUG.** NY4I:
    *"it would help if we are running DEBUG or higher to log when a command
    is changed."* Both storage paths report, which matters because they are
    not one path: `SetCFGCommandValue` covers the ini rows and
    `TStoredSetting.TrySetText` the 226 in `tr4w.json`. A line in only one
    would have answered the question for a fraction of the settings and
    said nothing about the rest.

        [Config] BAND MAP DECAY TIME = 20 (stored in tr4w.json)
        [Config] SCP MINIMUM LETTERS = 99 REJECTED -- not applied, not stored

    **The rejection line is the half worth having.** A value CheckCommand
    refuses was previously discarded with nothing anywhere to say why, so a
    setting the operator typed could simply vanish. DEBUG rather than INFO
    because one OK on a Preferences page can write dozens of rows.
- [x] **The WSJT-X indicator was too narrow for its own text. FIXED
  2026-08-26, WANTS A LOOK.** NY4I: *"The WSJTX letters are too big for the
  field."*

  Not the font -- the FIELD. `mweWSJTX` was declared `mweiWidth: 03` and the
  text written into it is the literal `'WSJTX'`, five characters
  (`uStateBridge.pas:106`). It never fitted.

  **SMALLER FONT, NOT A WIDER CELL** -- NY4I's call, 2026-08-26. Widening it
  (tried first, reverted) pushed `QSO B4` from x=11 to x=13, and moving a
  row of the main window that is otherwise exactly where it has always been
  is a bigger change than the defect. **The geometry is untouched.**

  The size is DERIVED, not picked: the same base every other element gets,
  scaled by cells-over-characters (3/5), with a floor of 8. So it tracks
  the operator's FONT SIZE setting and the window scale rather than being
  right at one size and wrong at every other.

  **Confirm by eye**: start with WSJT-X running so the indicator shows.
  Check it fits, that it is still readable, and that it still looks right
  at a different FONT SIZE. No automated gate covers main-window element
  geometry -- `Lint-FormOverlap` only sees designed `.lfm` forms, and these
  elements are a table in `VC.pas`.

### 40. Two multi-op message-loop defects fixed, and the silent drop now reports

`uNet.pas`. Multi-op only -- **not** the DX cluster; those are unrelated
subsystems and the only place they touch is the spot-forwarding call fixed
below. Needs a real multi-op session; nothing automated reaches any of it (there
is no `uNet` test at all).

- [ ] **A spot announced by another operator still reaches the cluster**, and
  **the QSO behind it in the same segment still arrives.** The spot arm
  advanced by 264 bytes for a 48-byte message -- an overshoot of 216 -- so
  one network-forwarded spot desynchronised the rest of that buffer. This is
  the fix most likely to be observable.
- [ ] **When one station drops off the network, the others' QSOs still arrive.**
  The disconnect arm overwrote the recv byte count with a client index, so
  the loop exited early and discarded whatever followed the notice.
- [ ] **Watch `tr4w.log` for `[Net] Unrecognised message id`.** New. If it never
  appears, the framing is holding. **If it does, capture the log** -- it
  names the id and the offset, and it is the first evidence this program has
  ever produced for a class of loss that was previously invisible.
- [ ] **A busy multi-op run.** HALF the structural defect is now fixed: a
  message whose bytes have not all arrived is REFUSED AND LOGGED rather than
  assembled from stale buffer contents and logged as a real QSO. What is
  still missing is the carry-over buffer -- `Bufindex := 1` on every recv --
  so a split message is **dropped**, not recovered. Dropped-and-logged beats
  silently-wrong, but the recovery is the transport rewrite.
  **Watch for `[Net] Message id ... needs N bytes but only M arrived`.** If
  that line appears in a real multi-op session, splits are happening in the
  field and the transport rewrite moves up the list.

**Not a defect, do not re-report:** `NET_MESSAGESTATE_ID` is sent and received
only under `{$IF OZCR2008}`, and that is `False` -- so no shipping TR4W emits it
and the missing receive arm cannot fire. It was briefly reported as live during
this session and that was wrong: the `SetTimer` that would arm it is inside the
same conditional (`uCWKeyerCPU.pas:87`). The residual hazard is cross-build
only -- `tr4wserver` relays the id ungated, so a client compiled WITH the switch
would feed standard clients something they cannot advance past.

### 41. Two ADIF export defects, found by pinning and NOT fixed

Both surfaced while extracting `GetMyExchangeForExport` into `uADIFExchange` and
pinning its arms. Both are pinned as-is, because that commit's whole claim is
that it changed nothing, and both need a CONTEST answer rather than a
refactoring one.

- [x] **`AgeAndQSONumberExchange` exports `Error generating my exchange`.** The
  arm is `Format('%-3d %-2s %03d      ', [cMyState, nrSent])` -- **three
  format specifiers, two arguments**, and the first specifier is `%d` while
  the first argument is a PAnsiChar. `Format` raises, the routine's own
  `try/except` swallows it, and the caller gets the initialisation string.
  Every contest using that exchange has been exporting the error text in
  that ADIF field.

  **ANSWERED 2026-08-26 -- NY4I asked which contests use this exchange.**
  **Exactly one: `SRR-JR`.** All 186 contest rows in `VC.pas` were parsed on
  their `AE:` field; `SRR-JR` is the only one whose `AE` is
  `AgeAndQSONumberExchange` (a Russian contest, `DF: 'russian'`,
  `QRZRUID: 331`). So the blast radius is one contest, not a family.

  **And the evidence says it is NOT RST**, which was the suspicion. The
  CABRILLO arm for the same exchange is intact and states the field
  meanings outright (`uCabrilloExchange.pas`):

      SetMyEx('%-2s %.*d ', [cMyState, 3 - Ord(nrSent < 0), nrSent]);
      SetHisEx(' %-3d %.*d', [hisAge, 4 - Ord(nrReceived < 0), nrReceived]);

  Sent is **age then serial**, received is **age then serial**; no RST
  anywhere. `cMyState` carries the AGE here (a `PAnsiChar`), which is also
  why the ADIF arm raises: its first specifier is `%-3d` and its first
  argument is that pointer.

  So the likely correct ADIF arm is `Format('%-2s %03d', [cMyState, nrSent])`
  -- the same two fields Cabrillo writes, in the same order. **Still not
  fixed**, because that is a contest-rules answer and NY4I asked to check
  the rules: confirm SRR-JR sends age + serial and the ADIF field should
  carry both.
- [x] **Serial numbers are not zero-padded, though the format looks like they
  would be.** `RSTQSONumberExchange` is `'%-3d %03d '`. In C `%03d` of 7 is
  `007`; in Object Pascal the leading zero is part of the WIDTH, so it is
  right-justified with spaces -- serial 7 exports as `  7`. The arm carries
  the comment "issue 177", which suggests somebody wanted `007` and wrote
  the C spelling. **Should it be `007`?** If so it is `Format('%.3d', ...)`
  or explicit padding, and it changes every affected log.

  **DECIDED 2026-08-26 (NY4I): padding is NOT required.** *"The spec states
  that the spacing between the fields is what the log checking tools use."*
  Three digits, four digits or none are all acceptable; zero-padding only
  aids readability. A dynamic width -- `DigitsIn(max(qsoNumber))` -- would
  be legitimate but is not wanted for its own sake.

  So this is **not a defect to fix**, and the reason to touch it would be
  readability alone. What must NOT change is the FIELD SPACING, which is
  what the checking tools parse.

Neither is a regression -- both predate today and are unchanged by the
extraction, which the corpus confirms byte-for-byte across all 13 ADIF fixtures.

### 42. Accelerators no longer reach past a modal dialog

Found on the bench 2026-08-24 (NY4I): with a dialog open, ESC did not close it
and the main window reacted instead; TAB turned the exchange field green, which
is search-and-pounce.

ESC and TAB are both accelerators (`uAccelerators.pas:170` -> `menu_escape`,
`:174` -> `menu_spmode_ortab`), and `Application.NotifyKeyDownBeforeHandler`
fires for EVERY `TWinControl` in the application -- so the hook matched them on
a dialog's controls, posted `WM_COMMAND` to the main window, and swallowed the
key. Suppressed now while a modal form is active.

- [ ] **ESC closes a dialog** and the main window does NOT react. Try several:
  Preferences, Edit QSO, Send Spot, the message editor.
- [ ] **TAB moves between controls inside a dialog** and does NOT put the main
  window into search-and-pounce.
- [ ] **ACCELERATORS STILL WORK FROM A MODELESS TOOL WINDOW.** This is the half
  that must not have been broken by the fix: with focus in the band map,
  stations, a dupe sheet, SCP or a remaining-mults window, Alt-B / Alt-V and
  the other accelerators must still fire. The guard is on MODAL forms
  specifically, not on "any form that is not the main window", because tool
  windows are separate forms too.
- [ ] **And they still work from the main window itself.**

---

### 44. The radio panels are LCL forms -- and colour used to mean state

Converted 2026-08-25.  Everything here needs a rig on the bench; none of it is
provable by the unit tests, the lints or the corpus.

- [ ] **Both VFO rows track the rig**, on Radio 1 and Radio 2, and the
  **RIT figure** and **both mode labels** with them.  These five writes were
  raw cross-thread `SetDlgItemText` / `SetWindowText` until the commit
  before this one; they now travel through `uPanelUpdate`.
- [ ] **The INACTIVE VFO row is greyed.**  102/104 really do mean
  enabled/disabled, and a `TLabel` greys natively.
- [ ] **RIT / XIT / SPLIT go YELLOW when the rig has them on.**  THIS IS THE
  ONE TO WATCH.  The dialog got the colour by returning a yellow brush from
  `WM_CTLCOLORSTATIC` for an ENABLED control, so `EnableWindow` was doing
  two jobs at once -- recording the rig state AND colouring the label.  An
  LCL label has no such coupling, so the flag is explicit state now and the
  colour follows from it.  Behaviour-preserving, and no compiler can check
  that claim.
- [ ] **The ACTIVE radio's panel is tinted light blue**, and the tint MOVES when
  the active radio changes.  That was two `InvalidateRect` calls in
  `LOGSUBS1` making `WM_CTLCOLORDLG` run again; it is
  `RadioPanelsRefreshActive` now.
- [ ] **The status line still shows connection failures in red** -- the
  `AUTH FAILED` path in `uRadioPolling`.
- [ ] **Both panels remember their position** across a close and reopen, and
  across a restart (the `BoundsRect` fix, section 43).
- [ ] **Escape closes each panel**, which a `DialogBox` gave away free.

**Watch the poll cost.**  `PostPanelEnable` coalesces on (panel, control id) and
the RIT/XIT/SPLIT posts run on EVERY poll, at rates down to 10 ms.  A steady
state should cost nothing.  If the UI feels heavy with two rigs polling fast,
that is the first place to look.

---

### 45. The multi-op link runs on Indy -- NEEDS A SECOND STATION

Converted 2026-08-25.  **This is the one section in this file that cannot be
tested solo**, and the one where a regression costs somebody else's log.

- [ ] **Connect to TR4WServer**, with the right password.  The handshake moved
  into TNetClient.Connect: ten bytes of password, then a four-byte
  acknowledgement.  The `Sleep(200)` that used to sit between them is gone --
  a blocking read waits properly.
- [ ] **A WRONG password still says so.**  The server answers 'PASS' and the
  operator gets TC_CONNECTTOTR4WSERVERFAILED, as before.
- [ ] **Two stations logging at once**: QSOs, mults, serial numbers, the station
  status list, intercom messages and spot forwarding.  Every message arm is
  byte-for-byte the code that ran before; what changed underneath is only how
  the bytes arrive.
- [ ] **Pull the network cable.**  The link drop now arrives as an EVENT from the
  reader thread rather than as a zero-length recv, and auto-reconnect still
  runs off the window's WM_TIMER.  Confirm it reconnects.
- [ ] **Close the network WINDOW while connected, and keep logging.**  This is
  the whole point of the change: the window used to BE the socket's event
  sink (WSAAsyncSelect posted WM_SOCK_NET to it), so it could not be closed
  or converted.  The link must now be entirely independent of it.
- [ ] **Watch tr4w.log for `[Net] stream desynchronised`.**  It should never
  appear.  If it does, the buffer was discarded to resynchronise and
  something upstream sent an id this build does not know.

**What to watch hardest: partial records.**  A read can end mid-message, and the
tail is now KEPT and completed by the next read instead of being logged and
dropped (bench queue 40 asked for exactly this).  That is a fix, but it is the
kind of fix that shows up as a rare, weird QSO if it is wrong.

---

## Findings — bench run 2026-08-20 (NY4I)

Defects found while working the list above. **A finding is not a checklist item.** They
are written down here rather than in the checklists because a checklist item is
a question and these are answers.

### F1 — a stray character appears before a message with a blank caption — **ANSWERED: the command delimiters; PARKED behind the JSON/F-key rewrite**

**Seen:** F5 saved with the command `EXCHANGERADIOS` and **no caption**. The
function-key display shows *"a random character before the word
EXCHANGERADIOS"*. With a caption present the command is fine.

Screenshot: `C:\Users\toms\Pictures\Screenshots\Screenshot 2026-08-20 112902.png`

**ANSWERED 2026-08-21: it is the command delimiters, drawn raw. It is NOT the
length-byte bug, and it is NOT new.** The suspicion below was that "a random
character" is the signature of a length byte read as text, because this area had
produced exactly that once (`CQ CW MEMORY F5<A4><AE>6w=`, an unterminated
`ShortString` read past its length). It is not the same defect.

A message is STORED with its control characters in it. A command is bracketed by
`ControlC`/`ControlD` -- `<03>EXCHANGERADIOS<04>` is how `tr4w.ini` spells it,
and `CfgCmd.SniffOutControlCharacters` turns that spelling into the two real
bytes on load, which is what `uProcessCommand.FoundCommand` then parses.
`uFunctionKeys.ShowFMessages` puts the STORED string on the button
(`uFunctionKeys.pas:319`/`:323`), so both delimiters are drawn, each as a
missing-glyph box. The screenshot shows one before the word and one after.

A caption hides it because the caption is displayed INSTEAD of the message, so
the blank-caption path is not a length-zero read going wrong -- it is simply the
only path that shows the message itself. The D7 tree's `uFunctionKeys.pas` does
the identical thing, so this is original behaviour, not a port regression.
`uAltP`'s message column (`uAltP.pas:312`/`:316`) has it too.

**PARKED, deliberately, and not fixed (NY4I, 2026-08-21):** the function-key
messages are moving to JSON and the way commands are processed is being redone.
The control characters ARE the storage format, so a display-side strip written
now is thrown away by that work -- and worse, it would hide the question the
rewrite has to answer, which is how a command should be represented once the
message is no longer a byte string with markers in it. Park it there.

Note this also settles the struck checklist item in section 1 -- the question was
never whether a blank caption should REMOVE the key; the character it renders was
typed, just not by the operator.

### F2 — the window control dialog opens a system menu instead of flashing — **ANSWERED: that menu is the accept path, by design**

**Seen:** *"Selecting a window here activates the window but opens the menu with
maximize, minimize, close, etc."*

**ANSWERED 2026-08-21: the system menu is the ACCEPT path, and it is the
original design.** It does not come from the dialog and it is not the flash.
Once a window is chosen, `MainUnit.pas:4429` sends the chosen window `$313` --
`WM_POPUPSYSTEMMENU` -- at its own top-left corner. That IS the mechanism behind
section 3's remaining checklist item "OK then lets you move the chosen window":
the operator is meant to pick Move from that menu. The D7 tree has the same line
at `MainUnit.pas:3965`, so nothing about it came from the LCL conversion.

The selection-change handler is correct as written --
`uWinManagerForm.lstWindowsSelectionChange` calls `Windows.FlashWindow`, which
inverts the target's caption and does not activate anything. So there is no
defect proven here, and the reading is that the menu was seen after ACCEPTING a
row (double-click, OK or Enter) rather than after merely moving the selection.

**Not closed, because one half is still a bench question:** does moving the
selection with the arrow keys, without accepting, flash the window and nothing
else? If it does, F2 is a misreading of intended behaviour and can be deleted.
If a system menu appears on selection alone, the diagnosis above is wrong and
that is worth knowing.

### F3 — the band plan editor has no way in — **FIXED 2026-08-21, confirmed on the bench**

**Seen:** *"I do not see this option in Settings."*

The form exists and `Invoke-MenuSmoke` proves it constructs and shows, so this is
about the ROUTE, not the dialog -- and note that the smoke test passing is
exactly why nothing caught this: it opens dialogs by resource id, not by clicking
through the UI a person actually uses.

**ANSWERED 2026-08-21: the editor has no live caller at all, and the route was
removed on 2026-08-16.** Its only entry point is `uOption.pas:746`, reached by
activating a settings row whose type is `ctFreqList`. There are exactly two such
rows, `BAND MAP CUTOFF FREQUENCY` and `FREQUENCY MEMORY` (`uCFG.pas:478`,
`:585`). Commit `79d4b6f0`, "empty Ctrl-J -- 173 settings move into Preferences",
flipped both from `csOld` to `csOwned`, and the Ctrl-J list builder skips
`csOwned` rows (`uOption.pas:389`). So the rows are not listed, and the call that
opens the band plan editor can no longer be reached.

Preferences does show both, and renders them DISABLED on purpose: they are
multi-valued `[BAND PLAN]` rows and a bound edit box would write one frequency
into `[COMMANDS]` and could replace a whole band plan (`uCFG.pas:1247` states
this at length, and it is right). So the fix is not to bind them.

**Decided (NY4I, 2026-08-21): put the way back in Preferences**, as an "Edit..."
button on those two rows calling `ShowBandPlan`. That keeps them unbound -- a row
that cannot be edited in place still cannot be saved -- while giving the dialog
that owns the setting the job of offering the editor for it.

**DONE, and confirmed opening on the bench the same day.** `CFGCommandIsFreqList`
(`uCFG.pas`) is the predicate -- a refinement of `CFGCommandIsList`, because both
kinds stay unbound but only this one has an editor behind it. The button carries
no binding, so the `[BAND PLAN]` hazard is untouched. Section 4's checklist is
live again; the items that WRITE the ini are still unrun.

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

### F5 — a bad callsign is accepted on Save — **CLOSED 2026-08-21: it is a feature**

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

**DECIDED AND DONE (NY4I, 2026-08-21).** The commented `//n4af 4.38.3` block
was DELETED, not reinstated -- so accepting `FRED` is the intended behaviour
of `GoodCallSyntax`, on the record, rather than a rule that happened to be
switched off in a comment since 4.38.3. The point this finding was making
stands either way: the block had to be DECIDED, because deleting it blind
would have settled the question without anyone noticing it was asked.

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

| Action | Nothing changed | Something changed        |
| ------ | --------------- | ------------------------ |
| Save   | unreachable     | "Save changes?" -> Yes   |
| button | (disabled)      | writes, No returns to    |
|        |                 | the dialog               |
| Escape | closes          | "Save changes?" -> Yes   |
| /      | silently, as    | writes and closes, No    |
| Cancel | before          | discards and closes      |
| / X    |                 |                          |

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

| Message | The list said | Actually | Consequence    |
| ------- | ------------- | -------- | -------------- |
| `       | ` WM_APP + 21 | ` WM_APP | CTY.DAT        |
| WM_CTY_ |               |          |                |
| VER     |               |          |                |
| SION_CH | 3`            | + 210`   | version-check  |
| ECKED`  |               |          | result         |
|         |               |          | discarded      |
| `       | ` WM_APP + 10 | `        | tray icon      |
| WM_TRAY |               | WM_SOCK  |                |
| BAL     |               |          |                |
| LON`    | 0`            | + 3` =   | clicks never   |
|         |               | `$5F7`   | handled        |
| `WM_PAN | absent        | `WM_APP  | the whole      |
|  EL_U P |               | + 230`   | radio-panel    |
| D ATE`  |               |          | seam           |
| `WM_USE | absent        | `WM_USER | **multi-op log |
|  R_HE A |               |  + 200`  | replace never  |
| D LESS_ |               |          | ran**, anditis |
|  SYNC _ |               |          | `SendMessage`  |
|  REP LA |               |          | d, so the      |
| CE `    |               |          | requesting     |
|         |               |          | thread blocked |
|         |               |          | tobe told      |
|         |               |          | nothing        |
|         |               |          | happened       |

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
