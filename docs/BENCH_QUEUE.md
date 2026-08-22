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

## Waiting now (as of 2026-08-21)

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
  a `.WAV`.

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

- [ ] **OK** then lets you move the chosen window -- it pops the chosen window's
  SYSTEM MENU at its top-left corner (`WM_POPUPSYSTEMMENU`), and Move from that
  menu is how the repositioning happens. That is the design, in D7 too.
- [ ] Moving the selection with the ARROW KEYS, without accepting, flashes the
  window and does nothing else. This is the half of F2 that is still a question.

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

- [X] **Before starting, note where a few windows are** (Band Map, Telnet, the
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
    the latest or offer the download link. **It dialled `tr4w.com` while sending
    `Host: www.tr4w.net`** -- corrected to `www.tr4w.net`, and since the routine
    had never run, nothing had ever exercised that mismatch. If the check fails,
    the host is the first thing to suspect.
  - [ ] **EXPECT THE UI TO FREEZE for about two seconds.** It does its socket
    work on the main thread and sleeps 2s waiting for the reply. That breaks
    NY4I's own no-I/O-on-the-UI-thread rule and is a KNOWN follow-up: wiring it
    up was the request, and rewriting it in the same change would have meant a
    bench failure could not be attributed to either.
  - [ ] Confirm the menu item sits in **Help**, after "Download POTA Parks".
- [ ] **Preferences -> Logging -> the "Open log file" BUTTON** (bottom of the
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

- [ ] **Run a short contest normally** -- log a few QSOs, work a dupe, change
  band and mode, send CW from the function keys, and exit cleanly.
- [ ] **Then run the golden corpus** once you have deployed, since the sweep
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

- [ ] **Run server** starts `tr4wserver.exe`; **Ping server** pings it.
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
  reverse.

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

| | how | condition |
|---|---|---|
| Windows | `inpout32.dll`, `Inp32`/`Out32` | what `uIO` already does |
| Linux | `ports` unit + `ioperm()` from libc, or FPC's `fpioperm` in unit `x86` | **requires root**, and is **x86-only** |

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

- [ ] **`DE ENABLE`, the worked example.** Change it in Preferences, close TR4W,
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
  and still be what you set after a restart. Before today none of that was true.
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

- [ ] **Appearance -> Colors.** Fifty elements, each with a Text and a
  Background drop-down from the 18-color palette. Change one, OK, and check it
  repaints. Restart and check it stuck.
- [ ] **Look at `settings\tr4w.json`** -- a `colors` object keyed by element
  name, values as SPELLINGS (`"YELLOW"`, not `15`).
- [ ] **Your existing colors must survive.** On first run with an old
  `tr4w.ini`, the log should say `[Colors] seeded 50 element(s) from the loaded
  configuration` and the window should look exactly as it did.
- [ ] **Ctrl-J.** Every menu route that used to open the old list -- Ctrl-J
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

| menu | page |
|---|---|
| Colors | Appearance > Colors |
| Appearance | Appearance |
| WinKeyer | **CW Settings** -- the keying-device library |
| Radio 1 / Radio 2 | Radios |

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

- [ ] **The main window still looks and behaves as it did.** It is a designed
  `TForm` now (`uMainForm.lfm`) rather than one built in code. Border, minimise
  box, taskbar button, background colour all moved from Pascal into the designer,
  so this is the check that nothing was dropped in the move.
- [ ] **The possible-call list.** Type a partial callsign and watch the row of
  suggestions below the entry fields: same font, same column width, dupes still
  red, the selected one still outlined. It is an LCL `TListBox` now, drawn
  through `OnDrawItem` instead of `WM_DRAWITEM`.
- [ ] **A specific thing to watch on that list, recorded honestly:** TR4W fills
  it with raw `LB_ADDSTRING`, so the LCL's own `Items` are empty. Nothing
  recreates the control's handle today, but if it ever DOES the list would go
  blank and refill on the next keystroke. If you see that once, that is what it
  was.
- [ ] **Help > About** opens a designed form instead of a system message box, with
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

- [ ] **F1 through F12 send.** Click each button and confirm the right message
  goes out -- this replaced `WM_COMMAND` / `BN_CLICKED` with `OnClick`, and the
  key code now comes from the panel's `Tag` rather than the control id.
- [ ] **The CQ and S&P banks both show the right text.** Toggle mode and watch
  the captions change. `ShowFMessages` drives them now by setting `Caption`
  instead of invalidating an owner-draw.
- [ ] **Ctrl and Alt banks.** Hold Ctrl, then Alt, and confirm the captions
  switch to those banks and back on release.
- [ ] **AN AMPERSAND IN A CW MESSAGE.** Put `&` in an F-key message and check it
  shows as one `&`, not none and not two. `ShowFMessages` deliberately doubles
  it; a `TPanel` caption treats `&` the same way the owner-draw did, so the
  doubling had to stay. This is the single most likely thing to be wrong.
- [ ] **Right-click a key** -> the one-item context menu, opening the editor on
  the RIGHT row. Do it while holding Ctrl and again holding Alt: the bank is read
  before the menu pops, precisely so releasing the modifier to click the menu
  does not change the answer (Issue #1001).
- [ ] **Right-DOUBLE-click a key** -> the Alt-P editor straight to that row.
- [ ] **The layout.** Twelve buttons across the width, with a wider gap after F4
  and after F8, resizing with the window. That arithmetic was copied unchanged
  from the Win32 `WM_SIZE` handler.
- [ ] **Colours.** F1-F4 white, F5-F8 yellow, F9-F12 as before -- straight from
  the same `ButtonsColor` table the owner-draw read.
- [ ] **The window still docks and remembers its place**, and closing it from the
  menu still works. It goes through the same `WndRect` / `WndVisible` /
  `CloseTR4WWindow` path as before; only the creation changed.
- [ ] **Escape still belongs to the callsign field** while this window is open --
  it must NOT close the F-key row.

**What is left before `Application.Run` can replace the message loop:** the band
map's `WM_KEYUP` arm, and nothing else. That is the next piece of item 1.

**Follow-up noted, not done:** `FunctionKeysWindowDlgProc` is no longer reached
for this window, but it is still registered in `tr4w_WindowsArray[..].WndProcAdr`
and this tree's rule is that unreachable-looking is not proof. Retiring it is a
separate, deliberate step.

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
