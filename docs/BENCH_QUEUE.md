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

## Waiting now (as of 2026-08-19)

### 1. Program message editor — Alt-P, pick a memory, Edit  (`d036b949`, `feb180f0`, `bede4637`)

Partly confirmed already: the dialog opens and Ctrl+P / Ctrl+A inserts a control
character. **Still open:**

- [ ] **Ctrl+P then Ctrl+C** inserts `<03>`, **Ctrl+P then Ctrl+D** inserts `<04>`.
      These are the two that matter — they bracket an embedded command, e.g.
      `CQ CW MEMORY CONTROLF5=<03>SRS=PB1;<04>` — and if they work, that message
      can be built in the editor instead of hand-editing the `.cfg`.
- [ ] **The saved key is clean.** After OK, the contest `.cfg` line should read
      `CQ CW MEMORY F5=...` with **no trailing garbage** on the key. The earlier
      attempt wrote `CQ CW MEMORY F5<A4><AE>6w=<01>` — an unterminated
      `ShortString` read past its length. Fixed; unverified.
- [ ] **An empty Caption REMOVES the key**, rather than writing a blank one. A
      blank caption and an absent one are read differently downstream.
- [ ] Caption field is **disabled** for the "other messages" bank.
- [ ] **&Edit** is enabled only in Phone mode, and only acts on a message naming
      a `.WAV`.
- [ ] Leftover: the stray `CQ CW MEMORY F5<garbage>` line in the contest `.cfg`
      from the earlier attempt is safe to delete by hand.

### 2. List of commands picker — the button inside that editor  (`ed0fdec5`, `fdb7bf5c`)

- [ ] **OK with nothing selected CLOSES** (it did not; fixed).
- [ ] **Double-click with nothing selected does NOT close** — deliberately
      different from OK, and that difference is the original's.
- [ ] The pasted command lands **at the caret**, not at the end.
- [ ] The command pasted is the one **highlighted**. The list is alphabetical
      while `sCommandsArray` is not, so an index-vs-text mistake here pastes a
      plausible-looking wrong command.

### 3. Window control dialog — Ctrl+Alt+M  (`f11a1093`)

Converted tonight; not yet opened once.

- [ ] It **opens** and lists the visible TR4W windows by title.
- [ ] Moving the selection **flashes** the corresponding window.
- [ ] **OK** then lets you move the chosen window (the caller repositions it).
- [ ] **Cancel / Escape / the window button move NOTHING.** This is the one worth
      being deliberate about: the dialog returns its answer in a global whose
      zero means "nothing chosen", so a missed clearing path would move whatever
      window was picked the *previous* time it was opened.

### 4. Band plan editor — Settings, then the band-plan button  (`uBandPlanForm`)

Converted tonight from 33 generated edit boxes to a single `TStringGrid`.

- [ ] It **opens** and shows one row per band with the three current values.
- [ ] Editing a cell and pressing **OK** writes `[BAND PLAN]` in `tr4w.ini` and
      the new values survive a restart.
- [ ] **Cancel changes nothing.**
- [ ] A cell left **empty or non-numeric is skipped** — that band keeps its old
      value rather than becoming 0.

**A DECISION FOR NY4I, not a defect.** The grid costs **295 KB of binary**
(4734 -> 5029 KB, ~6%): `Grids` is linked for the first time and nothing else in
TR4W uses it. It buys one designed control instead of 33 generated ones, and a
dialog that keeps working when a band is added to `BandType`. Two standing rules
point opposite ways here — "limit hand-coding of LCL components" versus "assume
every dependency has a cost" — so this is flagged rather than silently chosen.
Say the word and it goes back to generated `TEdit`s with no new unit linked.

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

### 6. CT1BOH information report  (`uCT1BOHForm`)

A read-only statistics grid: time per band, then QSOs and share per continent.
Open it with a log that has QSOs on several bands, or the grid says nothing.

- [ ] **Eight columns**: a blank label column, then 160 / 80 / 40 / 20 / 15 / 10
      and All.
- [ ] **Row order**: Time ON first, then North America, South America, Europe,
      Africa, Asia, Oceania, Antarctica. If a row is missing or the order is
      shuffled, that is the thing to report -- the rows used to be placed by
      explicit index and now they are appended.
- [ ] A band/continent with **no QSOs shows blank**, not `0 (0%)`.
- [ ] The percentages are a share of that BAND's total, so each band column
      should add to roughly 100%.
- [ ] **Escape closes it.** It has no buttons and never did.

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
