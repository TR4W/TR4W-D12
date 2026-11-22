# Plan: "This contest's exchange values" window (issues 241 and 300)

Status: **PLAN ONLY, for NY4I's approval.** Nothing here has been built. Written
2026-11-22 by the settings-config agent. Areas: settings-config (owner),
lcl-ui (the form), log-database (the config rows), contest-scoring (what
reads a value, and when).

NY4I's words this plan answers:

- #300 (newest comment): *"When we open the contest, we should populate the
  fields for that contest. Optimally, when I select a contest, I will see the
  answers to the question from when I opened the contest. ... we need a way to
  edit all the answers I entered when we setup the contest as new."*
- #241 A: *"Whatever parameters we asked of the operator at the new contest
  setup needs to be editable."* B (clearing an override): *"need more info"*.
  C (does the license-year question become part of this?): *"possibly related
  to A?"*

---

## 0. Executive summary

1. Most of the machinery already exists and works: the override per station
   fact (`TMySettings.SetContestOverride` / `ClearContestOverride` /
   `Resolved`), its log row (`config`, source `contest`), the one-row write
   (`uLogStore.LogStoreRecordContestStatement`), and the Station page's "also
   this contest" question for every fact (2026-11-17).
2. **What is missing is a place that lists every value the contest stated, says
   where each one comes from, and lets the operator CLEAR one.** No control can
   clear an override today.
3. **#300's display half is already built.** Since 2026-11-17 the Station page
   shows the contest's value wherever the contest states one
   (`TStationFactsShown`) and names the differences (`lblStationContestNote`).
   What remains of #300 is a GUI rerun on a current build.
4. **Clearing (decision B) needs no schema change and no new row kind.** The log
   already has a rule for a withdrawn override: rewrite the row as source
   `station`, which the reopen does not apply. Deleting the row would be undone
   by the next clean-close capture. Recommendation: use the existing rule.
5. **The plan found a real defect to fix first:** MY STATE has a second name,
   MY QTH. Both names get a `config` row. A mid-session edit or clear rewrites
   only one of them, so a stale `MY QTH` `contest` row can bring a cleared or
   changed value back on reopen. This is reasoned from the code, not measured.
   It only happens when the edit is not followed by a clean close. Stage 1 fixes
   it.
6. Changing a value mid-contest changes NEW QSOs only. Since schema 9 every fact
   is stored on the QSO row. Old QSOs are corrected by the existing second
   question (default No) or by Tools > Correct Station Facts (97c832798).
7. **Not every value takes effect at once.** The CW exchange messages and some
   contest set-up are built once, when the contest opens (`tSetupExchangeNumbers`,
   `FCONTEST`). The window must say which values wait for the next open.
8. Five stages, each its own commit with tests. Estimate: about 3 to 4 working
   days, half of it for the form and its GUI case.

---

## 1. Current state, with evidence

### 1.1 The facts

`uSettingsModel.TStationFact` (uSettingsModel.pas:2449) has 14 members:

| fact | command | New Contest field | kept on the QSO (`uStationFactRecord.STATION_FACT_IN_RECORD`) | feeds scoring (`StationFactFeedsScoring`) |
|---|---|---|---|---|
| sfState | MY STATE (+ alias **MY QTH**) | ncfMyState, ncfMyQTH | my_state, as typed | yes |
| sfSection | MY SECTION | ncfMySection | my_section, as typed | yes |
| sfZone | MY ZONE | ncfMyZone | my_cq_zone, **as sent** | yes |
| sfItuZone | MY ITU ZONE | (none) | my_itu_zone, as sent | yes |
| sfGrid | MY GRID | ncfMyGrid | my_grid, as typed | yes |
| sfName | MY NAME | ncfMyName | my_name, as typed | no |
| sfFdClass | MY FD CLASS | ncfMyFDClass | my_fd_class, as typed | no |
| sfCheck | MY CHECK | ncfMyCheck | my_check, as typed | no |
| sfPrec | MY PREC | ncfMyPrec | my_prec, as typed | no |
| sfPark | MY PARK | ncfMyPark | my_park, as typed | yes |
| sfIota | MY IOTA | ncfMyIOTA | my_iota, as typed | yes |
| sfPostalCode | MY POSTAL CODE | ncfMyPostalCode | my_postal_code, as typed | no |
| sfFocNumber | MY FOC NUMBER | ncfMyFOC | my_foc_number, as typed | no |
| sfLicenseYear | MY LICENSE YEAR | ncfMyLicenseYear | year_sent, **as sent** | no |

`uContestBase.NEW_CONTEST_FIELD_FACT` (uContestBase.pas:6282) maps each New
Contest field to its fact, so there is already **one list**.
`ContestUsesStationFact(contest, fact)` answers "did this contest's New Contest
prompts ask for it" (for the license year: "does it send one").

**What the New Contest dialog queues that is NOT a fact** (uNewContest.pas:823-892):

- `MY CALL`. It is deliberately not a fact (Q65, the club-call case). It goes
  through the kept-station-value route (`ApplyContestStatement` ->
  `KeepStationValue`).
- The CATEGORY rows (ASSISTED, BAND, MODE, OPERATOR, POWER...). They are
  contest-scoped settings and already have an editor: Tools > Edit Cabrillo
  Summary, which writes through `uCFG.ApplyContestEdit` and
  `LogStoreRecordContestStatement`.
- `CONTEST` itself.

### 1.2 How an override is stored, resolved and applied

- **In memory:** `TMySettings.FContestValue` / `FContestStated`
  (uSettingsModel.pas:2507). These are not published, so they are never
  streamed into `tr4w.json`. `Resolved(fact)` returns the contest's value if it
  stated one, else `StationValue(fact)` (uSettingsModel.pas:5876).
- **Setting one:** `TR4WSettings.TryOverrideForContest(cmd, value)`
  (uSettingsModel.pas:7118). It applies the property's own value check, and for
  MY ITU ZONE the 0..90 range.
- **The only door:** `uCFG.ApplyContestStatement` (uCFG.pas:1893), used by the
  `.cfg`, the New Contest queue (`uNewContestCommands.ApplyOne`) and the log's
  own rows when it is reopened.
- **In the log:** the `config` table (uLogSchema.pas:923) has
  `command TEXT PRIMARY KEY, value, source ('contest'|'station'|'operator'), set_at`.
  - `SaveConfigValue` is an upsert (`ON CONFLICT(command)`).
  - `DeleteConfigValue` exists.
  - `LoadContestConfig` reads only `source = 'contest'` rows (plus `CONTEST`)
    (uLogRepository.pas:3511-3533).
- **Capture rule for a fact** (`uLogContestStatements.StationFactRow` /
  `CaptureStationFactRow` / `CaptureStationFactRows`, lines 383-452):
  - while the contest states the fact: its value, source `contest`;
  - otherwise: the station's value, source `station`, a record that nothing
    applies.
  - The header says it outright: *"A withdrawn override's row is not deleted
    but rewritten as 'station'."*
- **When a row is written:** at log creation and at a clean close (whole
  capture), and **at the moment of change** through
  `uLogStore.LogStoreRecordContestStatement(cmd)`. Its body routes an
  overridable command to `CaptureStationFactRow` (uLogStore.pas, inside the
  function at 4808) and commits.
- **Reopen:** a `contest` fact row goes through `ApplyContestStatement` before
  the no-op skip, so a fact is never demoted (log-database.md, "Station rows
  are unchanged -- except the station FACTS").
- **Not shared with peers:** no `MY ...` name is in `uCFG.SHARED_WITH_PEERS`
  (checked with rg). Each position keeps its own facts.

### 1.3 Editors that exist today

| editor | what it does for a fact | gap |
|---|---|---|
| New Contest dialog | states each asked fact as the contest's | runs once |
| Preferences > Station page | **shows the contest's value where it states one** (`TStationFactsShown.Take`, uPrefsForm.pas:9235); a note lists station defaults that differ (`ShowStationContestNote`); Save asks one question, "Also this contest" / "Station default only" (default), for every changed fact the contest uses (`uStationFactChange.StationFactsToAskOnPage`, `ApplyStationFactScope`); then the log row (`LogStoreRecordContestStatement(StationFactCommand(fact))`, uPrefsForm.pas:9697); then an optional default-No correction of logged QSOs | **cannot clear** an override; mixes the station default and the contest value in one box; cannot show both values side by side |
| License year (issue 300) | the same path; `uLicenseYearChange` delegates to `uStationFactChange` | same |
| Tools > Correct Station Facts (97c832798) | rewrites one my_* value on logged QSOs (whitelist `STATION_FACT_BULK_CORRECTABLE`; never MY CALL, park or license year), with a backup first and a rescore | edits QSOs, not the contest's value. A different job, and this plan links to it |
| Edit Cabrillo Summary | the CATEGORY-* statements | not facts |

**So the answer to #300's open question (should Preferences show the station
default or the contest's year?) is already decided and built: the contest's.**
The last GUI evidence on #300 is from 2026-11-13, which predates that work.

---

## 2. Target UX and data model

### 2.1 The window

Proposed name: **"This contest's values"**. It is a designed LCL form
(`src/ui/lcl/uContestValuesForm.pas` + `.lfm`). It opens from:

- a button on the Preferences Station page beside `lblStationContestNote`;
- a Settings (or Tools) menu item while a log is open;
- optionally, the Open Log flow: NY4I's *"when I select a contest, I will see
  the answers"*. See question Q3.

It refuses to open, with a message, while the log is read-only or unusable, as
Correct Station Facts does.

One grid. The data lives in the control (`Cells`), with no shadow array.

| Value | This contest | Station default | Source | Takes effect |
|---|---|---|---|---|
| MY PREC | U | B | **this contest** (stated) | next QSO; CW messages at next open |
| MY CHECK | 80 | 80 | this contest (same as station) | next QSO |
| MY SECTION | | NFL | follows the station | -- |
| MY ZONE | 5 | 5 (from MY CALL) | follows the station (derived) | next QSO |

**Rows:** `ContestUsesStationFact(contest, f)` **OR** `HasContestOverride(f)`.
That is the facts this contest asked for, plus any fact it stated by another
route (a `.cfg` import, an ITU zone), so that every statement is visible and
can be cleared. No second list is created.

**Per row:**

- **Edit** "This contest". It writes `TryOverrideForContest` and then
  `LogStoreRecordContestStatement` for every name of the fact (see 2.3). It
  never writes the station default.
- **Follow the station** (clear). It calls `ClearContestOverride` and then
  records every name of the fact. Result: the row becomes `station`, and the
  value shown becomes the station's.
- Format check inline, red text plus one label, with no modal. It uses the same
  rule as the Station page: `uStationFieldCheck.StationFieldProblem`.
- **OK applies all changed rows in one go.** If a changed fact is kept on the
  QSO as typed, it then asks the existing second question, default No,
  "correct N logged QSOs that sent the old value?"
  (`StationFactCorrectionOf`, `LogStoreCountQSOsSentStationValue`). For the two
  zones and the year, the message names Tools > Correct Station Facts or the
  year correction instead.

**Below the grid:** read-only lines for MY CALL (the contest's call, and the
station's if they differ) and for the category rows, with a button "Edit
Cabrillo summary...". See question Q2.

### 2.2 The rule as data (a leaf, unit-tested)

Add the row state to `uStationFactChange`. That unit already holds
`StateContestValue` / `ApplyStationFactScope`, so this is not a sibling unit:

```pascal
TContestValueSource = (cvsStated, cvsStatedSameAsStation, cvsFollowsStation);
function ContestValueSource(aSettings: TR4WSettings; aFact: TStationFact): TContestValueSource;
function ContestValueRows(aSettings: TR4WSettings; aContest: TContestBase): TStationFacts;
function ClearContestValue(aSettings: TR4WSettings; aFact: TStationFact): boolean;  (* True when it changed *)
```

The form only renders these answers and calls them.

### 2.3 Decision B: clearing an override in the log

| option | what the row becomes | evidence | verdict |
|---|---|---|---|
| **(a) Delete the row** (`DeleteConfigValue`) | absent | Absence already means "the station decides" on reopen. **But the next clean close runs `CaptureStationFactRows`, which writes a `station` row back.** So the result depends on whether the session closed cleanly. The other route also has a different on-disk shape. | works, but is unstable and a second rule |
| **(b) A new explicit "follow station" row** (for example source `follow`) | a new row kind | Needs `LoadContestConfig`, `KeepOnlyStatements` and every older build to agree on a source the schema comment does not list. An older build reading the log ignores it, which happens to be right, but it is a new contract for no gain. | rejected |
| **(c) Rewrite as `station` (the existing rule)** | `source='station'`, the station's value | It is exactly what `CaptureStationFactRow` writes when `HasContestOverride` is False (uLogContestStatements.pas:383-426), and what the close capture would write anyway. `LoadContestConfig` does not replay it. **No schema change. Any build, older or newer, reads it the same way.** | **recommended** |

**Can the close capture undo a clear?** No, checked. New Contest marks every
queued fact with `NoteCommandFromContestCFG`, and the close capture's
station walk gives a row source `contest` while `CommandCameFromContestCFG`
says so. But that walk `Continue`s past every `CommandIsContestOverridable`
name (uLogStore.pas:2360), and facts are written only by
`CaptureStationFactRows` (uLogStore.pas:2421), which asks `HasContestOverride`
and nothing else. A cleared fact therefore stays `station` across a clean
close. Stage 2 still adds a test that pins this.

**No control can clear an override today, checked.** The only caller of
`ClearContestOverride(` outside `ClearContestOverrides` is
`uContestFactory.pas:318`, the one-time migration of a year that an older
log stored in MY ZONE. It is not an operator action.

Is it safe? Yes. One statement is committed by `LogStoreRecordContestStatement`.
In /EXPORT it does nothing. If the store is disabled it warns and the clear
holds for this session only, the same as every other statement.

**The defect (c) exposes, fixed in Stage 1: the second name.** `AlsoKnownAs('MY
QTH', 'My.State')` (uSettingsModel.pas:6676) puts both names in `CommandNames`.
So the creation capture writes **two** rows for sfState, and a contest that
asked `ncfMyQTH` states it under `MY QTH`. `StationFactCommand(sfState)` names
one of them. Since issue 300 / schema 9, a Station-page "Also this contest"
edit of MY STATE rewrites only that row. The other `contest` row keeps the old
value until a clean close. After a crash it stays, and on reopen it is replayed
too, so which one wins depends on replay order. This is reasoned from the code,
not measured; Stage 1's test is the measurement. The license year never hit it
because it has no second name.

**Fix:** a routine that records every command name resolving to the fact
(`uLogContestStatements.CaptureStationFactRowsFor(settings, repo, fact)`, a loop
over `CommandNames` filtered by `StationFactOfCommand`). Both the Station page
and the window call it through one `uLogStore` entry point.

---

## 3. Interaction with in-flight logging

- **Logged QSOs do not change.** Schema 9 stores every fact on the QSO row
  (`STATION_FACT_IN_RECORD`), and the sent exchange is rebuilt from the row
  (NY4I 2026-11-13: *"a QSO record depends on nothing but its own row"*).
  Changing MY ZONE mid-contest therefore affects the next QSO's captured
  `my_cq_zone` and its export. Earlier QSOs keep what they sent.
- **Correcting earlier QSOs is a separate, explicit act.** It uses:
  - the default-No second question after OK, for facts kept as typed (the
    existing `StationFactCorrectionOf` path; a rescore follows when
    `StationFactFeedsScoring`);
  - Tools > Correct Station Facts (97c832798) for a value on every QSO or on
    QSOs from record n onward. Its whitelist excludes MY CALL, park and the
    license year;
  - the license-year correction (`uLicenseYearChange`) for the year.
- **Not every reader is live. Measured readers of `Settings.My.Resolved*`:**

  | reader | when | consequence |
  |---|---|---|
  | QSO capture into the row (`uStationFactRecord`), `uExchangeBuilder` (grid), `LogSend` (name, postal code in CW), `logwind`/`logedit` (grid bearings), `logstuff` (park) | every use | live at the next QSO |
  | `logcfg.tSetupExchangeNumbers` -> `CQExchangeDefault(CurrentStation)` / `RepeatSPExchangeDefault`; `fcontest.pas:494` writes `Messages.CqExchangeCw` from ResolvedName + SentMyState | **once, at contest set-up** | the CW exchange memories keep the old value until the next open (or until the operator edits the memory) |
  | `FCONTEST` set-up through `CurrentStation` / `DescribeSession` (zone mode, host-area membership, SentMyState) | **once, at contest set-up** | scoring context changes at the next open. This is the `NeedsRestart` gap in settings-config.md, where NY4I lost twenty minutes. |

  **The window must say this per row** (the "Takes effect" column), for each
  fact whose set-up reader exists for the open contest. Stage 4 decides,
  per fact, between "next QSO" and "next time the contest is opened". A
  re-run of the set-up after an edit (rebuild messages, `ApplyContestTraits`)
  is **not** proposed: it is contest-scoring's question and could overwrite an
  operator's edited CW memory. See Q5.

---

## 4. Staged commits (each: quick loop only, `Build-Tests.ps1 -Run`)

**Stage 1: one fact, every name (defect fix, no UI).**
- `uLogContestStatements.CaptureStationFactRowsFor(aSettings, aRepository, aFact)`.
- A `uLogStore` entry point, `LogStoreRecordStationFact(aFact)`, that commits
  once.
- Repoint the Station page (uPrefsForm.pas:9697) and `uLicenseYearChange`'s
  caller to it.
- Tests (`uTestLogContestStatements`):
  - state MY STATE through `MY QTH`, capture, change through `MY STATE`, record,
    and `LoadContestConfig` must hold one value for both names;
  - a cleared override leaves zero `contest` rows for the fact.

**Stage 2: the rule leaf.**
- `ContestValueSource`, `ContestValueRows`, `ClearContestValue` in
  `uStationFactChange`.
- Tests (`uTestStationFactOverrides` or a new `uTestContestValues`):
  - every fact x {stated, stated equal to station, follows};
  - rows = used ∪ stated, for a contest with prompts and for a `.cfg`-stated
    ITU zone;
  - clear then `Resolved` = station value;
  - clear of an unstated fact = no change.

**Stage 3: the form.**
- `uContestValuesForm` (.pas/.lfm, `RegisterClass` if needed,
  `Lint-LFMProperties`).
- Strings in `uAppStrings` and propagated to the catalogues
  (`tools/i18n`; `.po` and `languages.res` committed together).
- Menu item plus a Station-page button.
- The Station page reloads after the window saves (the cached-singleton rule:
  reload while not dirty).
- A GUI case in `tools/gui_test`:
  1. Create SS with MY PREC=M, station default B.
  2. Log one QSO.
  3. Open the window: M is shown as stated, over the station's B.
  4. Clear it and log a second QSO.
  5. Close and reopen.
  6. Check:
     - the window shows MY PREC as "follows the station" (B);
     - the FIRST QSO still exports M, because schema 9 rebuilds the exchange
       from the row;
     - the second QSO exports B.

**Stage 4: "takes effect" and the correction hand-off.**
- A per-fact `StationFactLiveness(contest, fact)` in the leaf, pinned per fact.
- The OK path asks the existing correction question. Point the zones and the
  year at their tools.

**Stage 5: docs and agents.**
- `docs/ADDING_A_SETTING.md`: a new station fact appears in the window with no
  code, because the rows come from `TStationFact`.
- settings-config.md, lcl-ui.md and log-database.md: the clear rule and the
  alias fix.
- A `BENCH_QUEUE.md` entry.
- Close #241. #300 is closed by NY4I after the GUI rerun.

---

## 5. Risks

1. **The alias defect is live today**, independent of this window: a Station-page
   "Also this contest" edit of MY STATE in a contest that used MY QTH. This is
   why Stage 1 comes first.
2. **Derived MY ZONE.** `StationValue(sfZone)` can be a value derived from MY
   CALL (`ZoneWasSet` False). Clearing to "follow the station" then follows the
   derivation, which is correct but must be labelled "(from MY CALL)", or it
   reads as a stated station default. Writing it back would latch it, which is
   the #319 bug again; the window must never write the station.
3. **Two editors of one value** (the Station page with its question, and the
   window). They share the leaf and the log entry point, so the rules cannot
   diverge. The Station page must reload after the window saves, and the window
   must reload after Preferences saves. Both forms are cached.
4. **A value the contest asked for but the operator left blank** at New
   Contest is not queued (a blank non-category row is skipped), so it follows
   the station. The window shows it as "follows the station". That is accurate,
   but it may surprise NY4I's "answers I entered". See Q4.
5. **Peers:** facts are per position. If NY4I expects a multi-op station to
   share MY PREC/CHECK, that is a protocol decision, not this window's.
6. **Old logs** written before 7.12 hold `contest` rows for facts and read as
   before. Nothing here migrates them.
7. **Scope creep:** re-running contest set-up after an edit (Q5) is a separate
   piece of work.

---

## 6. Questions only NY4I can answer (each with a recommendation)

- **Q1 (#241 B, clearing).** Clearing a contest value makes the contest follow
  the station default again. In the log, the row is rewritten as a "station"
  record (the existing rule; reopen ignores it), rather than deleted or given a
  new marker. **Recommend: yes, the existing rule.** It needs no schema change,
  and every build reads it the same way.
- **Q2 (#241 A, scope).** "Whatever we asked" also covers MY CALL (the club
  call) and the CATEGORY rows. **Recommend:**
  - show the categories read-only, with a button into Edit Cabrillo Summary
    (their editor already exists);
  - show MY CALL read-only. Changing the contest's call after QSOs are logged
    is a larger question (Q65, everything derived from the call moves with it)
    and should be its own issue.
- **Q3 (#300, "when I select a contest, I will see the answers").** Should
  opening a log show this window, or is the Station page (which already shows
  the contest's values) plus a menu item enough? **Recommend: no automatic
  window.** Add a one-line status or log message at open, "this contest states
  N values; Settings > This contest's values", and the menu item.
- **Q4.** A field left blank at New Contest follows the station. Should a blank
  be a statement ("this contest sends nothing for MY CHECK")? **Recommend: no.**
  Blank keeps meaning "follow the station". A stated empty value would be a new
  rule for every reader.
- **Q5.** An edit that only takes effect at the next open (the CW exchange
  memories, the zone mode): is labelling it in the window enough, or should OK
  rebuild the contest's set-up? **Recommend: label only now**, and file a
  separate issue for a safe re-setup, which must not overwrite an
  operator-edited memory.
- **Q6 (#241 C).** Does the Station page keep its "Also this contest" question
  once the window exists? **Recommend: keep it** (confirmed and working). Add
  the button into the window. Do **not** make the Station page read-only as
  #241 item 2 first proposed: the 2026-11-17 design already shows the
  contest's value there.

---

## 7. Size estimate (honest)

| stage | work | estimate |
|---|---|---|
| 1 alias fix | about 60 lines plus 2 tests | 0.5 day |
| 2 leaf | about 120 lines plus about 15 tests | 0.5 day |
| 3 form | `.lfm` + about 400 lines, strings and catalogues, menu, Station-page button, GUI case | 1.5 to 2 days (the GUI case and catalogue propagation are the slow part) |
| 4 liveness and correction hand-off | needs a per-fact reader audit with contest-scoring | 0.5 to 1 day |
| 5 docs and agents | | 0.25 day |

**Total: about 3 to 4 days.** Rework if Q2 or Q5 widen the scope. The unknown
is Stage 4: a per-fact list of set-up readers was sampled here (rg of
`My.Resolved*`), not walked from every contest class.
