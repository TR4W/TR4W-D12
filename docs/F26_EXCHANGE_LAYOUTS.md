# F26: export layouts for the fifteen contests with no exchange layout

**Status: PROPOSAL, nothing built.** Research for NY4I's approval, 2026-10-14;
**re-sourced 2026-10-15** under NY4I's rule for where contest facts come from;
**third pass 2026-10-15**, applying NY4I's answers to the old Q1-Q3 and mining
DXLog.net's contest definition files, the source he added that day.
Plan item F26 is in `docs/CONTEST_FACTORY_M11_PLAN.md`.

## Questions for NY4I (rules not settled by the Cabrillo spec, WA7BNM or DXLog)

These are the facts the accepted sources do not settle. Each one is a contest
rule or a naming decision NY4I checks himself. The question numbers are referred
to as **Q-F26-n** below.

**Renumbered 2026-10-15.** Old Q1, Q2 and Q3 are answered; old Q12 is settled by
DXLog. Old to new:

| old | new | | old | new | | old | new |
|---|---|---|---|---|---|---|---|
| Q1 | answered; remainder in Q1 | | Q8 | Q7 | | Q15 | Q13 |
| Q2 | answered; remainder in Q1 | | Q9 | Q8 | | Q16 | Q14 |
| Q3 | answered; remainder in Q2 | | Q10 | Q9 | | Q17 | Q15 |
| Q4 | Q3 | | Q11 | Q10 | | Q18 | Q16 |
| Q5 | Q4 | | Q12 | settled by DXLog | | Q19 | Q17 |
| Q6 | Q5 | | Q13 | Q11 | | Q20 | Q18 |
| Q7 | Q6 | | Q14 | Q12 | | Q21 | Q19 |
| | | | | | | decision 5 | Q20 |

### Answered

- **Old Q1, ALL JA and every Cabrillo CONTEST: name -- ANSWERED (NY4I,
  2026-10-15):** *"Just use whatever D7 used. If it was blank, then we use the name
  in the enumeration."* D7's `CABName` is blank for all fifteen, so every one falls
  through to the enumeration name. The values are in the
  [CONTEST: table](#contest-values-under-the-d7-enumeration-rule); which spelling of
  "the name in the enumeration" is meant is **Q20**.
- **Old Q2, JALONGPREFECT -- ANSWERED (NY4I, 2026-10-15):** it IS the JARL All
  Cities All Guns contest (ACAG). Reference given: https://contestclock.com/contest/jarl-acag.
  The rules are in [its section](#jalongprefect-jarl-all-cities-all-guns-acag).
- **Old Q3, ARCI -- ANSWERED (NY4I, 2026-10-15):** *"These are different events
  even though they could possibly share the same rules. I would think these should
  be listed as individual events so the wa7bnm id would be the distinct id."* Each
  ARCI event becomes its own contest with its own WA7BNM ref. The six events are in
  [the ARCI section](#arci-qrp-arci-contests----six-events).
- **Old Q12, POTA -- SETTLED BY DXLOG, NY4I may override:** no Cabrillo is wanted.
  DXLog's POTA definition labels its Cabrillo block *"Dummy Cabrillo export"* and
  comments out its `CABRILLO_LINE`, and writes the activation as ADIF
  `MY_SIG`/`MY_SIG_INFO`/`SIG`/`SIG_INFO` `[DXLog POTA.txt]`. That is a second
  logger agreeing with TR4W's reading, not the sponsor.
- **Q20, the CONTEST: and ADIF names -- ANSWERED (NY4I, 2026-10-15), per contest
  rather than by one spelling rule:**
  - **COUNTYHUNTER:** *"As this is an inactive contest, just use MARAC for the county
    hunter cab and adif name."* Cabrillo CONTEST: `MARAC`; ADIF CONTEST_ID `MARAC`.
  - **ALLJA:** *"I thought we answered the all-ja with the dxlog files."* So `ALL-JA`,
    DXLog's `CABRILLO_CONTEST_NAME` `[DXLog ALLJA.txt]`.
  - **JALONGPREFECT:** *"may be answered like dxlog.net"*. **DXLog has no ACAG file**
    (its JARL files are ALLJA, JIDXC, KCJ, KCJ_TOPBAND and JARLWWR; checked
    2026-10-15), so there is no DXLog name to take. The ALL JA pattern gives
    **`ACAG`** (JARL's own name for the event) -- **CONFIRMED by NY4I, 2026-10-15:
    "ACAG is fine."**
  - **KIDSDAY:** *"Use KIDS-DAY for kids day."* `KIDS-DAY` (and no Cabrillo file
    is produced; see decision 1).
  - **TENTEN:** *"Use TEN-TEN."* `TEN-TEN`. Whether the four events are split
    (Q13) is still open; if they are, each event's name is still to be set.
  - **QCWA and QCWAGOLDEN:** *"Use QCWA."* `QCWA` for both. (Whether QCWA GOLDEN is
    kept at all is still Q12.)
  - **GRIDLOC:** NY4I: *"I need more info on grid loc as that does not sound like a
    contest (more like general qso)."* The information is in
    [the GRIDLOC section](#gridloc-grid-loc). Its name follows from Q9's remainder.
- **Q9, GRIDLOC -- ANSWERED (NY4I, 2026-10-15): KEEP IT.** *"while general qso will
  allow logging of grid and name, grid loc would show if the grid is needed or worked
  so keep it."* What remains is small and stays open as Q9a: does it write a Cabrillo
  file at all, and if so is its name `GRID-LOC`?
  - **NZFIELDDAY** keeps `JW-FD` (NY4I's own choice of 2026-09-29), and the
    remaining names are those of the CONTEST: table.
- **Q9a, Grid Loc's Cabrillo and name -- ANSWERED (NY4I, 2026-10-15):** *"Grid Loc
  not needed as we would not create CABRILLO for it. So use FFMA for it as a place
  holder (Fred Fish Memorial Award is about tracking grids)."*
  - **No Cabrillo file** for Grid Loc -- it joins POTA and Kids Day under decision 1.
  - **Its name is `FFMA`**, a placeholder (the ARRL Fred Fish Memorial Award, for
    working the 488 grids on 6 m, is the grid-tracking use the class serves). Used
    wherever the contest has to name itself, e.g. ADIF CONTEST_ID.
- **Retire or keep -- ANSWERED (NY4I, 2026-10-15):**
  - **[Q8] FISTS: RETIRE.** *"FISTS is inactive so retire."*
  - **[Q11] QCWA: KEEP, re-modelled to the 2021 exchange** -- year licensed + name +
    chapter/state/province/country, no serial; CW/digital 2 points, phone 1; W2MM
    bonus; chapters/states/provinces/countries once per contest; Cabrillo by email.
    Its parser and scoring change before its export layout means anything.
  - **[Q12] QCWA Golden: RETIRE.** *"QCWA Golden was a one time event."*
  - **[Q16] WWL: RETIRE.** *"wwl retire."*
  - *(Read as: "remodel QCWA to 2021 exchange but RETIRE [QCWA Golden]". If QCWA
    itself was meant to be retired too, say so.)*
  - **How a contest is retired is a design call (delegated), recorded here:** the
    contest leaves the New Contest drop-down and gets no new work, but its
    `ContestType` member, its `ContestTypeSA` spelling and its class stay, so a log
    or `.cfg` that already names it still opens, rescores and exports. Deleting the
    enum member would make such a log unreadable, and that is the one cost a
    retirement must not have.
- **[Q15, part] UA4W's address -- ANSWERED (NY4I, 2026-10-15):** r4w@narod.ru is
  valid. The schedule question stays open.
- **Q13, split TEN-TEN into its four events -- ANSWERED NO (NY4I, 2026-10-15):**
  *"Ten Ten is also inactive so it seems redundant to break this further."* It stays
  ONE contest, `TEN-TEN` (Q20), unlike ARCI. Its WA7BNM id stays 0, since one class
  cannot carry four refs.
- **Q4-Q7, County Hunter (MARAC) -- DELEGATED (NY4I, 2026-10-15): "MARAC is
  inactive so just pick a reasonable default."** The default chosen:
  - **Scoring stays as it is:** one point per QSO, no multipliers, dupes as today --
    D7's "General County Hunting Log". No MARAC scoring is implemented for a contest
    that is not run, so Q5 (points, mults, bonuses) and Q7 (dupe rule) fall away,
    and so does Q4's choice between ref 3 and ref 20.
  - **Cabrillo (Q6): yes,** so a county log can still be submitted somewhere.
    `CONTEST: MARAC` (Q20). Columns, from helpers that already exist: sent
    `CabrilloSentRSTState` (RST + MY STATE), received `CabrilloReceivedRSTQTH` (RST +
    the QTH as typed, e.g. `FL ORA`); ADIF STX_STRING `ADIFSentRSTState`.
  - **Our own county:** a distinct `MY COUNTY` station field (decision 2), sent after
    the state, rather than putting the county in MY STATE.
  - Revisit only if MARAC runs a contest again.
- **Q2, ARCI event names -- APPROVED (NY4I, 2026-10-15):** `ARCI-SPRING` (WA7BNM
  315), `ARCI-FALL` (168), `ARCI-HOOTOWL` (31), `ARCI-SUMMER-HB` (69),
  `ARCI-TOPBAND` (193), `ARCI-HOLIDAY-HB` (198). Each is its own contest and is also
  its Cabrillo CONTEST: value.
- **Earlier, kept for the record:** COUNTYHUNTER is the MARAC contest, and missing
  station facts get distinct station fields (both NY4I, 2026-10-15; see the
  COUNTYHUNTER section and [decision 2](#decisions-owed)).

### Open -- what NY4I still has to answer

**Only unanswered questions are here** (cleaned 2026-10-15). Anything answered,
in whole or in part, is under [Answered](#answered); an item below carries only
the part still owed. The `[Qn]` tag is the number the question has been cited by.

**ALL JA and ACAG**

- **[Q1] Log format.** Does JARL accept a Cabrillo body inside its e-log, or must
  TR4W write the JARL log-sheet format? And is the power letter its own column
  (`599 10 H`, as DXLog writes it) or joined to the number (`599 10H`, as JARL's
  example shows)?
- **[Q19] Sent QTH field.** Does sending the JA prefecture number (ALL JA) or the
  ACAG city/gun/ku code through `MY STATE` count as reuse under the distinct-fields
  ruling? If it does, they get `MY JA PREFECTURE` and `MY JA CITY CODE`. (Same
  question for UA4W's RDA, below.)

**ARCI**

- **[Q3] Log format.** Does the qrpcontest.com upload take a Cabrillo file?

**NZ Field Day (JW-FD)**

- **[Q10] Rules:** (a) RS(T) + serial + branch, a home station sending `00`?
  (b) 5 points ZL CW, 3 ZL phone, 10 non-ZL? (c) branches as multipliers -- does our
  own count? (d) Cabrillo accepted, and one log per band?

**TEN-TEN**

- **[Q14] Log format.** Does 10-10 accept a Cabrillo file?

**UA4W**

- **[Q15] Schedule.** One 2-hour window, 1600-1800 UTC, with 15-minute periods
  (DXLog), or two tours ending 19:59 (earlier pass)? (The address is answered:
  r4w@narod.ru is valid.)
- **[Q19] Sent QTH field** -- the RDA district: same question as ALL JA/ACAG above
  (`MY RDA`?). Only Udmurtia stations send one; everyone else sends `MY GRID`.

**Xmas**

- **[Q17] Which contest is it?** Is it the SSA Jultest (DXLog's `SSA_JT.txt` matches
  its exchange)? If so, the group sent is the one RECEIVED in the previous QSO, not a
  fresh random one -- which does TR4W do?
- **[Q18] Its name.** If it is the Jultest, `SSA-JULTEST` (DXLog's name), since `XMAS`
  is the DARC Christmas Contest's registered name?

(Decision 1, a way for a contest to say "no Cabrillo file", is no longer owed: with
POTA, Kids Day and Grid Loc all writing none, it is decided -- a `TContestBase`
answer, False by default, that those three state; the Cabrillo writer then refuses
with a message instead of writing error-marker lines. A design call under the
delegation, not a sponsor rule.)

## Sources, and how each fact is marked

NY4I's rule (2026-10-15): *"We use the Cabrillo spec or wa7bnm refers or ask and I
check the rules."* The accepted sources, in order:

1. **The Cabrillo specification** at wwrof.org. Its header page enumerates the
   CONTEST: values it defines itself, and for any other contest it says *"Additional
   contest name examples can be seen here"*, linking WA7BNM's
   [Cabrillo Names list](https://www.contestcalendar.com/cabnames.php). That list is
   therefore marked `[Cabrillo spec -> WA7BNM cabnames]`.
2. **WA7BNM's contest calendar**: a `contestdetails.php?ref=N` page, and the sponsor
   page it links under "Find rules at".
3. **A reference NY4I names.** For ACAG he gave contestclock.com; its page links
   JARL's rules, marked `[contestclock jarl-acag -> jarl.org acag_rules]`.
4. **DXLog.net's contest definition files** (added by NY4I 2026-10-15),
   `C:\Program Files (x86)\DXLog.net\Contest\*.txt`, 543 files. **This is another
   logger's encoding of the rules, not the sponsor.** Where it disagrees with the
   Cabrillo spec or a WA7BNM-referred sponsor page, the sponsor wins and the
   disagreement is recorded.
5. Otherwise, a question for NY4I, listed above.

Marks used below:

- `[Cabrillo spec]`
- `[Cabrillo spec -> WA7BNM cabnames]`
- `[WA7BNM ref N]` for the details page itself
- `[WA7BNM ref N -> sponsor URL]` for the sponsor page it links
- `[contestclock jarl-acag -> jarl.org acag_rules]`
- `[DXLog <file>]` for a DXLog.net definition file
- `[D7]` for C:\TR4W's `VC.pas` / `PostUnit.PAS`, a fact about the old program
- `[UNVERIFIED -- earlier pass used <mirror/inference>]`
- `[TR4W code]` for what this tree does, which is a fact about TR4W, not about the rules

**What DXLog holds for the fifteen.** All 543 files were searched by name and by
content (`CONTESTNAME`, `CABRILLO_CONTEST_NAME`, `CONTESTWEB`, and sponsor names).
Matches: `ALLJA.txt` (ALL JA), `FISTSSPR.txt` (FISTS), `POTA.txt` (POTA),
`R4W-CHAMP.txt` (Udmurtia), `TENTENQP.txt` (10-10), `SSA_JT.txt` (the SSA Jultest,
for XMAS) and `DARC_XMAS.txt` (the DARC contest XMAS is not). `HB_XMAS.txt` (USKA,
canton exchange) and `RSGB_VHF_XMAS.txt` (VHF, distance-scored) match nothing.
**No file** for ACAG, any QRP ARCI event, MARAC, Grid Location, NZART JW-FD, Kids
Day, QCWA, QCWA Golden or WWL.

**What the Cabrillo spec says about all fifteen.** Its own CONTEST: list is ARRL-10,
ARRL-10-GHZ, ARRL-160, ARRL-DIGI, ARRL-DX-CW, ARRL-DX-SSB, ARRL-EME, ARRL-SS-CW,
ARRL-SS-SSB, BARTG-RTTY, CQ-160-CW, CQ-160-SSB, CQ-WPX-CW, CQ-WPX-RTTY, CQ-WPX-SSB,
CQ-VHF-SSBCW, CQ-VHF-DIGI, CQ-WW-CW, CQ-WW-RTTY, CQ-WW-SSB, IARU-HF, NAQP-CW,
NAQP-SSB, NAQP-RTTY, RDXC, RSGB-IOTA, SPDXC, SPDXC-RTTY, TARA-RTTY, WAG and WW-DIGI.
**None of the fifteen is among them**, and its QSO-data page
([cabrillo-qso-data](https://wwrof.org/cabrillo/cabrillo-qso-data/)) gives no template
for any of them `[Cabrillo spec]`. A CONTEST: value may use only A-Z, 0-9 and hyphen,
at most 32 characters `[Cabrillo spec]`. Of WA7BNM's Cabrillo names, only the four
10-10 events and the DARC Christmas Contest (`XMAS`) touch these classes
`[Cabrillo spec -> WA7BNM cabnames]`. Every layout below therefore uses the generic
form, `QSO: freq mo date time call rst exch call rst exch`, with the exchange in the
order the sponsor gives it. Cabrillo is whitespace-separated, so the column widths
follow this tree's existing style; they are not a sponsor requirement.

## Why this exists

Fifteen registered contests have no export layout. Each one calls
`CabrilloSentNotHandled` / `CabrilloReceivedNotHandled`, so every Cabrillo `QSO:`
line prints `ERROR EXCHANGE NOT HANDLED` in both exchange columns. Fourteen of them
also call `ADIFSentNotImplemented`, so ADIF leaves out `STX_STRING`. POTA is the
exception: it already writes `ADIFSentPark`.

For each contest this document gives:

- the sponsor's rules, each fact marked with its source;
- the fields TR4W already holds;
- a proposed sent column, received column and `STX_STRING`;
- the station fields the sent side needs (see [decision 2](#decisions-owed));
- the decisions NY4I owes.

## CONTEST: values under the D7 / enumeration rule

NY4I (2026-10-15): *"Just use whatever D7 used. If it was blank, then we use the
name in the enumeration."* D7's `ContestsArray` row carries `CABName:''` for **all
fifteen** `[D7]` (C:\TR4W\tr4w\src\VC.pas, the rows at lines 3425-3555). D7 then
printed `ContestTypeSA[Contest]` (`PostUnit.PAS:2192-2198`) `[D7]`, so D7's actual
output was the `ContestTypeSA` spelling.

| TR4W enum member (today's `VC.pas`) | D7 `CABName` | `ContestTypeSA` spelling (D7's fallback; today's `GetCabrilloName`) | Legal Cabrillo? | Enum identifier | DXLog `CABRILLO_CONTEST_NAME` |
|---|---|---|---|---|---|
| `ALLJA` | blank | `ALL JA` | **no** (space) | `ALLJA` | `ALL-JA` |
| `ARCI` | blank | `ARCI` | yes | `ARCI` | none (no file) |
| `COUNTYHUNTER` | blank | `COUNTY HUNTER` | **no** | `COUNTYHUNTER` | none |
| `FISTS` | blank | `FISTS` | yes | `FISTS` | `FISTS-SPRINT` |
| `GRIDLOC` | blank | `GRID LOC` | **no** | `GRIDLOC` | none |
| `JALONGPREFECT` | blank | `JA LONG PREFECT` | **no** | `JALONGPREFECT` | none |
| `KIDSDAY` | blank | `KIDS DAY` | **no** | `KIDSDAY` | none |
| `NZFIELDDAY` | blank | `NZ FIELD DAY` (D7); today `JW-FD`, NY4I 2026-09-29 | `JW-FD` yes | `NZFIELDDAY` | none |
| `POTA` | blank | `POTA` | yes | `POTA` | `POTA` (marked "Dummy") |
| `QCWA` | blank | `QCWA` | yes | `QCWA` | none |
| `QCWAGOLDEN` | blank | `QCWA GOLDEN` | **no** | `QCWAGOLDEN` | none |
| `TENTEN` | blank | `TEN TEN` | **no** | `TENTEN` | `TENTEN-{MODE}` |
| `UA4WCHAMPIONSHIP` | blank | `R4W-CHAMP` | yes | `UA4WCHAMPIONSHIP` | `R4W-CHAMP` |
| `WWL` | blank | `WWL` | yes | `WWL` | none |
| `XMAS` | blank | `XMAS` (collides with DARC's registered name) | yes, but taken | `XMAS` | n/a; `SSA-JULTEST` for the Jultest |

**What the rule changes in code:** nothing for fourteen of the fifteen. Every class
already returns its `ContestTypeSA` spelling, and NZFIELDDAY returns `JW-FD`. So
[decision 5](#decisions-owed) narrows to **Q20**: if "the name in the enumeration"
means the `ContestTypeSA` spelling, seven values stay illegal Cabrillo; if it means
the enum identifier, none do. **XMAS** is a separate case (Q18). Where DXLog's name
differs (`ALL-JA`, `FISTS-SPRINT`, `TENTEN-{MODE}`), it is recorded and not used:
NY4I's rule decides, and for 10-10 WA7BNM's per-event names are preferred over
DXLog's per-mode one.

Of the D7 rows, one more fact worth having: D7's `NZ FIELD DAY` row carries WA7BNM
222 and FriendlyName *"NRAU-Baltic Contest, SSB"* `[D7]`, a copy-and-paste error in
the old table. Today's class returns 0 on purpose.

## Summary

"WA7BNM" is the calendar's ref and status. "Class id" is what the class's
`GetWA7BNMId` returns today `[TR4W code]`.

| TR4W id | WA7BNM (class id) | Cabrillo CONTEST: under the D7 / enum rule | Source of the rules | Proposed sent / received (example) | Confidence |
|---|---|---|---|---|---|
| ALLJA | **not listed** (0) | `ALL JA` (or `ALLJA`, Q20); DXLog `ALL-JA` | DXLog ALLJA.txt; JARL power letters via ACAG's sponsor page | `599 10H` / `599 13M` | Medium on exchange and scoring; low on log format (Q1) |
| ARCI -> **six events** | 315, 168, 31, 69, 193, 198 (0) | one per event, Q2; `ARCI` today | WA7BNM refs 315/168/31/69/193/198 | `599 FL 5W` / `579 ON 1234` | High on exchange and scoring; low on log format (Q3) |
| COUNTYHUNTER | 3 and 20, both **Inactive** (0) | `COUNTY HUNTER` (or `COUNTYHUNTER`, Q20) | WA7BNM ref 3 and 20; sponsor link dead; no DXLog -- Q4-Q7 | `599 FL ORA` / `599 PA BUC` | Low until Q4 |
| FISTS | 251 **Inactive** (251, correct) | `FISTS`; DXLog `FISTS-SPRINT` | WA7BNM ref 251 -> fistsna.org; DXLog FISTSSPR.txt | `599 FL TOM 1234` / `599 VA STAN 2934` | High that it is defunct; retire? (Q8) |
| GRIDLOC | **not listed** (0) | `GRID LOC` (or `GRIDLOC`) | UNVERIFIED (mailing-list archive); no DXLog -- Q9 | `TOM EL98` / `BOB EM10` | Low; retire? |
| JALONGPREFECT (= ACAG) | **not listed** (0) | `JA LONG PREFECT` (or `JALONGPREFECT`) | contestclock -> jarl.org ACAG rules | `599 100116L` / `599 1001L` | **High on the rules** (was Low); low on log format (Q1); parser and flags must change |
| KIDSDAY | 224 "Active historically, but unconfirmed" (224, correct) | `KIDS DAY` (no file produced) | WA7BNM ref 224 -> arrl.org | none proposed | High that no log is wanted |
| NZFIELDDAY | **not listed** (0, deliberate) | `JW-FD` (Q20) | UNVERIFIED (search index); no DXLog -- Q10 | `599 001 25` / `599 017 00` | Low until Q10 |
| POTA | **not listed** (0) | `POTA` (no file produced) | DXLog POTA.txt (agrees); earlier docs.pota.app | no Cabrillo; ADIF already done | **Medium-high** (was Medium) |
| QCWA | 332 **Inactive** (332, correct) | `QCWA` | WA7BNM ref 332 -> qcwa.org 2021 rules | `61 TOM 151` / `55 BOB 91` | High on the rules; keep? (Q11) |
| QCWAGOLDEN | **not listed** (0) | `QCWA GOLDEN` (or `QCWAGOLDEN`) | none -- Q12 | as QCWA | Low; retire? |
| TENTEN | 237, 81, 156, 464 (0) | WA7BNM's per event if split (Q13); else `TEN TEN` / `TENTEN` | WA7BNM refs -> ten-ten.org; cabnames; DXLog TENTENQP.txt | `TOM 12345 FL` / `BOB 0 MA` | High on exchange; column order now corroborated; medium on file format (Q14) |
| UA4WCHAMPIONSHIP | **not listed** (0) | `R4W-CHAMP` (DXLog agrees) | DXLog R4W-CHAMP.txt (cites qrz.ru) -- Q15 | `001 UD05` / `017 KO85` | **Medium** (was Low) |
| WWL | **not listed** (0) | `WWL` | none; no DXLog match -- Q16 | `599 KO85` / `599 JN58` | Low on the contest; high on the code |
| XMAS | only DARC Xmas, ref 210 (0) | `XMAS` under the rule, but DARC owns it -- Q18 | DXLog SSA_JT.txt matches -- Q17 | `599 001 PZRIQ` / `599 017 LUCIA` | **Medium** on identity (was Low); the group rule differs |

**Changed in the third pass:** JALONGPREFECT is ACAG (NY4I) and its rules come from
JARL's own page, so it rises to High on the rules -- and shows TR4W's dupe and
multiplier flags are wrong for it. ARCI becomes six events. ALLJA, UA4W and XMAS
rise because DXLog encodes each of them. POTA's no-Cabrillo reading is corroborated.
Every CONTEST: value now follows the D7 / enumeration rule.

**Changed in the second pass:** ALLJA, JALONGPREFECT, NZFIELDDAY, UA4W and POTA
dropped in confidence, because their rules rested on sources outside the rule.
COUNTYHUNTER's scoring came from WA7BNM and differed from the first pass. TENTEN's
column order was corrected to the sponsor's exchange order. XMAS dropped to Low.

## Fields that are available, and fields that are not

**The sent side** comes from `TMyStationExchange`, which `PostUnit.CurrentMyStationExchange`
builds. The fields are `MyState` (the state *sent in this contest*), `MyGrid`,
`MyName`, `MyZone`, `MyFDClass`, `MySection`, `MyCheck`, `MyPrec`, `MyFOCNumber`,
`MyPostalCode` and `MyPark`. The per-QSO values come from the `ContestExchange`
record `aQso`: `NumberSent`, `RSTSent` (formatted as `aCtx.RSTSent`) and
`RandomCharsSent`.

**Under NY4I's ruling at [decision 2](#decisions-owed), each missing fact gets its own
station field.** None of these exists today. `MY FOC NUMBER` is the precedent for a
programme's membership number.

| Proposed station field | Contest(s) | Export needs it (sent column, `STX_STRING`) | On-air exchange needs it (CQ/S&P message, New Contest prompt) | Scoring reads it |
|---|---|---|---|---|
| `MY TEN TEN NUMBER` | TENTEN | yes | yes | no |
| `MY ARCI NUMBER` | the six ARCI events (member) | yes | yes | no |
| `MY POWER` | ARCI and FISTS non-members | yes | yes | yes: ARCI's power multiplier |
| `MY FISTS NUMBER` | FISTS, **only if kept** (Q8) | yes | yes | no |
| `MY JA POWER CLASS` | ALLJA, JALONGPREFECT (ACAG) | yes | yes | no |
| `MY COUNTY` | COUNTYHUNTER | yes | yes | no |
| `MY QCWA CHAPTER` | QCWA, QCWAGOLDEN | yes | yes | no |
| `MY YEAR LICENSED` | QCWA, QCWAGOLDEN | yes | yes | no |
| `MY NZART BRANCH` | NZFIELDDAY | yes | yes (replaces today's `MY ZONE` prompt) | yes: the own-branch rule |
| `MY JA PREFECTURE`, `MY JA CITY CODE`, `MY RDA` | ALLJA, JALONGPREFECT, UA4W | yes | yes | no |

The last row is **conditional on Q19**: today `MY STATE` carries these values as "the
QTH sent in this contest". The first nine are needed whatever Q19's answer is.
`MY RDA` is needed only by a station in Udmurtia; every other UA4W entrant sends
`MY GRID` `[DXLog R4W-CHAMP.txt]`.

The name `MY TEN TEN NUMBER` spells the digits out. TR4W derives the command name
from the published property's path, and a Pascal identifier cannot start with a
digit, so `MY 10-10 NUMBER` cannot be a property name. Plain station facts that are
genuine and need no new field are `MY NAME`, `MY GRID`, `MY STATE` (a real US state
or province) and `MY PARK`.

**The received side** has these fields:

| Field in `aQso` | What it holds here |
|---|---|
| `QTHString` | the QTH as typed |
| `DomesticQTH` | the QTH resolved against the domestic file |
| `aCtx.HisQTH` | `DomesticQTH` when the contest has a domestic multiplier, else `QTHString` |
| `Name` | the received name |
| `NumberReceived` | the received serial, or the FISTS member number |
| `Power` | ARCI's power or member number; FISTS's power |
| `Precedence` | the ALL JA power letter |
| `Chapter` | the QCWA chapter |
| `TenTenNum` | the 10-10 number; `MAXWORD` means none |
| `Zone` | the NZ branch number |
| `RandomCharsReceived` | the received random group |
| `Kids` | the whole Kids Day exchange string |
| `Check` | the year licensed (`ProcessCheckAndChapterOrQTHExchange` sets it) |

## Per contest

### ALLJA: JARL ALL JA

- **Cabrillo spec:** no CONTEST: value; JARL's only entry in the list is
  `JARL-WW-RTTY` `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** not listed, active or inactive. The class id is 0, which is right.
- **CONTEST: value under the D7 / enum rule:** D7's `CABName` is blank `[D7]`, so
  `ALL JA` (the `ContestTypeSA` spelling, which has a space) or `ALLJA` (the enum
  identifier) -- **Q20**. DXLog writes `ALL-JA` `[DXLog ALLJA.txt]`.
- **Rules** `[DXLog ALLJA.txt]`, which links JARL's `allja_rules.html`:
  - Japan only: `CFG_MULT_DX_ALLOWED=NO`, and points are scored only for a JA
    station;
  - bands 160, 80, 40, 20, 15, 10 m and 6 m; CW and SSB; categories CW, SSB, Mixed;
  - exchange: RS(T) + prefecture or Hokkaido district number (`02`-`48`, `101`-`114`)
    + one power letter, `H`, `M`, `L` or `P`;
  - **dupe rule: once per band** (`DOUBLE_QSO=PER_BAND`), so not again on another
    mode;
  - **points: 1 per QSO** with a JA station;
  - **multipliers: prefecture/district numbers, per band**, own number valid;
  - Cabrillo line: RST, prefecture (3 wide, right-aligned), power letter as **its
    own column**, then the received call, RST, number, letter.
- **Power-letter thresholds:** DXLog gives only the letters. JARL's ACAG rules give
  H over 100 W, M over 10 W to 100 W, L over 5 W to 10 W, P 5 W or less
  `[contestclock jarl-acag -> jarl.org acag_rules]`, the same thresholds the earlier
  pass found for ALL JA `[UNVERIFIED -- earlier pass used jarl.org found by search]`.
  Treated as settled; one sponsor, two contests, same letters.
- **Log:** a JARL e-log, `<SUMMARYSHEET>` plus a `<LOGSHEET TYPE=...>` body in JARL
  format or Cabrillo; JARL's example row is `59 13L 59 13M` `[UNVERIFIED -- earlier
  pass used jarl.org found by search]`. **Q1.**
- **TR4W has:** `Precedence` (the received H/M/L/P) and `HisQTH`, which is the
  `DomesticQTH` from `allja.dom` `[TR4W code]`. Flags `[cfQSOByBand, cfMultByBand,
  cfVHFBandsEnabled]` `[TR4W code]` agree with DXLog's dupe and multiplier rules.
  **Caution:** the parser can store `QTHString` as `'p' + number`. That is harmless
  here unless LITERAL DOMESTIC QTH is on.
- **Proposed layout:**
  - **Sent:** `'%-3s %s%s'` of RST, our prefecture and `MY JA POWER CLASS`,
    e.g. `599 10H`; or `'%-3s %3s %s'`, `599  10 H`, if Q1 says the letter is its own
    column, as DXLog writes it.
  - **Received:** the same of RST, `HisQTH` and `Precedence`, e.g. `599 13M`.
  - **STX_STRING:** the sent text. (DXLog's is `$STATE+" "+$EXCHANGE`, number and
    letter without the RST `[DXLog ALLJA.txt]`.)
  - **Helpers:** new, `CabrilloSentRSTQTHPower` and `CabrilloReceivedRSTQTHPrecedence`.
- **Station fields:** `MY JA POWER CLASS`; and `MY JA PREFECTURE` if Q19 says so.
- **Confidence:** medium on the exchange and scoring (was low); low on the log
  format until Q1.
- **Decisions owed:** Q1, Q19, Q20.

### ARCI: QRP ARCI contests -- six events

- **Identity -- ANSWERED (NY4I, 2026-10-15):** each ARCI event is its own contest,
  with its own WA7BNM ref as its distinct id. Today's single `ARCI` class (id 0)
  becomes six.
- **Cabrillo spec:** no CONTEST: value; WA7BNM's Cabrillo name list has no ARCI entry
  `[Cabrillo spec -> WA7BNM cabnames]`. **DXLog has no ARCI definition.**
- **D7:** one `ARCI` row, `CABName` blank `[D7]`. No D7 row exists for any single
  event, so under the Q1 rule each event's **enumeration name is its CONTEST:
  value** -- **Q2**.

**The six active events**, all `[WA7BNM ref N]`:

| Proposed enum / CONTEST: | Event | WA7BNM ref, status | When | Bands, mode | Rules link WA7BNM gives |
|---|---|---|---|---|---|
| `ARCI-SPRING` | Spring QSO Party | 315, Active, confirmed | 0000Z-2359Z, 2nd Saturday of April (11 Apr 2026) | 160-10 m, CW | qrparci.org/contest/spring-qso-party |
| `ARCI-FALL` | Fall QSO Party | 168, Active, but no recent results | 0000Z-2359Z, 2nd Saturday of October (10 Oct 2026) | 160-10 m, CW | qrparci.org/contest/fall-qso-party |
| `ARCI-HOOTOWL` | Hootowl Sprint | 31, Active, confirmed | 0000Z-0100Z, 25 May 2026 | 160-10 m, CW | qrparci.org/contest/hoot-owl-sprint |
| `ARCI-SUMMER-HB` | Summer Homebrew Sprint | 69, Active, confirmed | 2000Z-2300Z, 12 Jul 2026 | 160-10 m, CW | qrparci.org/contests/2026 Summer Homebrew Sprint.txt |
| `ARCI-TOPBAND` | Topband Sprint | 193, Active historically, but unconfirmed | 0000Z-0300Z, 3 Dec 2026; logs due 15 Dec | **160 m only, CW and SSB** | qrpcontest.com/qrparci_topband/ |
| `ARCI-HOLIDAY-HB` | Holiday Homebrew Sprint | 198, Active historically, but unconfirmed | 2000Z-2300Z, 13 Dec 2026; logs due 22 Dec | 160-10 m, CW | qrpcontest.com/qrparci_holiday/ |

The names are proposals: hyphenated so they are legal Cabrillo whatever Q20 decides.
Fifteen more ARCI events on WA7BNM are Inactive and are not proposed.

**What all six share** `[WA7BNM refs 315, 168, 31, 69, 193, 198]`:

- **Exchange:** member: RST + state/province/country + ARCI number; non-member:
  RST + state/province/country + power out. (Ref 315 writes "RS"; its sponsor page
  says RST `[WA7BNM ref 315 -> qrparci.org spring-qso-party]`.)
- **QSO points:** 5 with a member; 4 with a non-member on a different continent; 2
  with a non-member on the same continent.
- **Multipliers:** states, VE provinces and countries.
- **Power multiplier (CW):** >5 W x1, 1-5 W x7, 250 mW-1 W x10, 55-250 mW x15, 55 mW
  or less x20. (Ref 315 writes `<=55mW`; the others `<55mW`.)
- **Score:** QSO points x (state + province + country mults) x power mult.
- **Log:** upload at qrpcontest.com; no email, no post. **Format not stated** -- Q3.

**Where they differ:**

| Event | Work stations | Multipliers counted | Extra |
|---|---|---|---|
| Spring, Fall | once per band | once per band | none |
| Hootowl | once per band | once per band | +5000 for portable on battery with a temporary antenna |
| Summer Homebrew | once per band | once per band | per band: +2000 homebrew transmitter, +3000 homebrew receiver, +5000 homebrew transceiver; +5000 portable on emergency power with temporary antennas |
| Holiday Homebrew | once per band | once per band | the same homebrew bonuses per band; +5000 battery portable with temporary antenna, *"not once per band"*; adds Multi-Op and DX classes |
| **Topband** | **once per mode** | **once, regardless of mode** | **SSB power mult:** >10 W x1, 2-10 W x7, 500 mW-2 W x10, 100-500 mW x15, <100 mW x20; Mixed uses the smaller of the CW and SSB mults |

Score with a bonus is `(QSO points x mults x power mult) + bonus points` (refs 31,
69, 198).

- **TR4W has:**
  - `Power`, which holds the member number or the power; an all-digit value means a
    member;
  - `HisQTH` (`DomesticQTH` for W/VE);
  - `QTHString` / `DXQTH` for DX. `HisQTH` is empty for a DX station, so no existing
    received helper prints the DX country correctly. `[TR4W code]`
  - Flags `[cfQSOByBand, cfMultByBand]` `[TR4W code]`: right for five events, wrong
    for Topband (once per mode, mults once per contest).
  - No bonus-point input; the homebrew and portable bonuses are a scoring decision
    for the contest-scoring owner, not export.
- **Proposed layout** (one layout, shared by all six; a family base is justified
  only if one rule governs them, which design `CONTEST_OWNERSHIP_DESIGN.md` decides):
  - **Sent:** `'%-3s %-3s %-6s'` of RST, `MyState` and `MY ARCI NUMBER`, else
    `MY POWER`, e.g. `599 FL  5W` or `599 FL  12345`.
  - **Received:** `'%-3s %-3s %-6s'` of RST, the QTH and `Power`. The QTH is
    `HisQTH`, else `QTHString`, else `DXQTH`.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Station fields:** `MY ARCI NUMBER`, `MY POWER`.
- **Confidence:** high on the exchange and scoring of each event; low on the file
  format (Q3).
- **Decisions owed:** Q2, Q3.

### COUNTYHUNTER: MARAC County Hunter contest

- **Identity:** **ANSWERED (NY4I, 2026-10-15): "County hunter is marac."** The class is
  the MARAC County Hunter contest. It is KEPT, and its header's "general logging mode"
  wording is to be corrected.
- **Cabrillo spec:** no CONTEST: value; no MARAC entry in WA7BNM's Cabrillo name list
  `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `COUNTY HUNTER`
  or `COUNTYHUNTER` (Q20). It stays open in Q6 only if MARAC names one.
- **DXLog:** no MARAC or county-hunter definition. Nothing here changes.
- **WA7BNM lists two MARAC contests, both Inactive.** The class id is 0. Which one is
  meant is **Q4**.

  **MARAC US Counties QSO Party** -- `[WA7BNM ref 3]`:
  - Status: Inactive; last held 0000Z 26 July to 2400Z 27 July 2025; 2024 was 27-28 July.
  - Modes CW/Digital and Phone; bands 160, 80, 40, 20, 15, 10, 6 and 2 m.
  - Classes: Fixed Single Op, Portable Single Op and Mobile, each CW-Dig / Phone /
    Mixed; and DX.
  - **Exchange:** RS(T) + state and county, or "DX".
  - **Work stations:** once per band per mode.
  - **QSO points:**
    - 1 point per QSO with a fixed US station;
    - 15 points per QSO with a US mobile;
    - US entrants: 2 points per QSO with a DX station.
    - **Not stated:** points for working a portable station, and what a DX entrant
      scores (**Q5 a, b**).
  - **Multipliers:** each US county, once per mode.
  - **Score:** total QSO points x total multipliers.
  - **Logs:** email to contest-logs@marac.org; postal address N7NU. **No format is
    stated** (**Q6**).
  - "Find rules at" `http://www.marac.org/contests.htm` -- **dead**: marac.org returns
    403 or 404 for it, and the current marac.org home page links only award rules.

  **MARAC SSB QSO Party** -- `[WA7BNM ref 20]`:
  - Status: Inactive; last held 1-2 May 2010. SSB only, 80-10 m.
  - Classes: Fixed, Mobile Op, Mixed.
  - **Exchange:** W: RS + county and state; non-W: RS + province or country.
  - **Work stations:** once per county per band.
  - **QSO points (fixed entrant):** 1 per fixed station, 15 per mobile, 5 per DX
    station; bonus points "see rules".
  - **Multipliers:** each US county once.
  - **Score:** total QSO points x total multipliers.
  - **Logs:** email to ka3qlf@comcast.net. Rules link `http://marac.org/ssbrules.htm`
    is dead as above.

- **What changed from the first pass.** The first pass gave 1 / 15 / 5 (fixed /
  mobile / DX) and a 6 June due date from a qsl.net copy. **1 / 15 / 5 is the 2010 SSB
  QSO Party's scoring (ref 20).** The event that ran until 2025 (ref 3) scores DX at
  **2**, not 5, counts multipliers **once per mode**, and adds a Portable class.
  The 6 June date is dropped: it is in neither WA7BNM page. `[UNVERIFIED -- earlier
  pass used the qsl.net/yt1dz mirror]` for anything not restated above.
- **What TR4W does today** `[TR4W code]`: D7's row named it *"General County Hunting
  Log"*, with `OnePointPerQSO`, no multipliers and no WA7BNM id (C:\TR4W
  `VC.pas:3444`), and the class carries that over: `FixedModePoints(Mode, 1, 1, 1)`.
  `HisQTH` is `QTHString` as typed, e.g. `FL ORA`. **Making the class the MARAC contest
  is NEW SCORING** -- points by the worked station's type (fixed, portable, mobile,
  DX), county multipliers, and the dupe rule (Q7) -- its own piece of work, with the
  matrix re-frozen for it. It is not an export fix, and it cannot start until Q4-Q7
  are answered.
- **What the scoring needs that TR4W does not hold:** whether the *worked* station is
  mobile or portable. That is a received-side fact per QSO, not a station field, and
  no field in `aQso` carries it today.
- **Proposed layout:**
  - **Sent:** `'%-3s %-2s %-12s'` of RST, `MY STATE` and `MY COUNTY`,
    e.g. `599 FL ORA`. (Was the county packed into `MY STATE`; the ruling rejects
    that.)
  - **Received:** RST + the QTH as typed, 12 wide, so a county line (`FL ORA/SEM`)
    is not truncated. `CabrilloReceivedRSTQTH`'s 7-wide field is too narrow.
  - **STX_STRING:** the sent text.
- **Station fields:** `MY COUNTY`.
- **Confidence:** low until Q4. The two WA7BNM pages disagree on DX points,
  multipliers and dupes.
- **Decisions owed:** Q4, Q5, Q6, Q7.

### FISTS: FISTS sprints (Americas)

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `FISTS` (legal
  either way). DXLog writes `FISTS-SPRINT` `[DXLog FISTSSPR.txt]`; not used.
- **Status: defunct.**
  - **FISTS Winter Unlimited Sprint** (the class's FriendlyName): Inactive, last held
    8 Feb 2020 `[WA7BNM ref 251]`. The class id is 251, which is right.
  - Every other FISTS event on WA7BNM is Inactive too (refs 1, 17, 68, 154, 171, 393,
    584-587, 684, 685). Ref 724, the FISTS Royal Platinum Jubilee Weekend Celebration, is listed without the Inactive mark and is not a sprint.
  - The linked sponsor page: *"Sprints will NOT continue in 2026 due to a lack of
    sufficiant participation."* `[WA7BNM ref 251 -> http://fistsna.org/operating.html#sprints]`.
  - DXLog still ships a generic "FISTS Sprint" definition, updated 2025-12-28
    `[DXLog FISTSSPR.txt]`. That does not contradict the sponsor: it is a file kept,
    not an event held.
  - **Removed:** the first pass's FISTS UK note, which was not WA7BNM-referred.
- **Last exchange:** FISTS member: RST + state/province/country + first name + FISTS
  number; non-member: the same with power instead of the number `[WA7BNM ref 251]`.
- **Last rules** `[WA7BNM ref 251]`: bands 80-10 m; work stations **once per band**;
  5 points per QSO with a FISTS member; FISTS members score 2 per QSO with a
  non-member; multipliers are each US state and VE province once and each DXCC
  country once; total = points x mults. Logs by email to w2dab@fistsna.org.
- **Where DXLog disagrees** `[DXLog FISTSSPR.txt]`, and the sponsor wins:
  - DXLog's dupe rule is `PER_MODE`; CW only, so once per contest. WA7BNM says once
    per band.
  - DXLog has a non-member send `NM` and print **nothing** in the number column;
    WA7BNM has a non-member send **power**.
  - DXLog scores 2 for any non-member QSO, whoever is operating; WA7BNM gives the 2
    to members.
  - DXLog agrees on 5 points with a member, the location multiplier once per
    contest, and the column order name, number, location.
- **TR4W has:** `QTHString` / `HisQTH`, `Name`, and `NumberReceived` (member) or
  `Power` `[TR4W code]`. Flags `[cfQSOByBand]` agree with WA7BNM.
- **If kept:**
  - **Sent:** `'%-3s %-3s %-6s %-6s'` of RST, `MyState`, `MyName` and
    `MY FISTS NUMBER`, else `MY POWER`.
  - **Received:** the same, built from the QSO.
  - **STX_STRING:** the sent text.
- **Station fields, only if kept:** `MY FISTS NUMBER`, `MY POWER`.
- **Confidence:** high that the event is gone.
- **Decision owed:** Q8 -- retire the class, or keep it as a QSO-logging mode.

### GRIDLOC: International HF Grid Location Contest

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `GRID LOC` or
  `GRIDLOC` (Q20).
- **WA7BNM:** not listed. The class id is 0. (The grid events WA7BNM does list, TOEC WW
  Grid ref 97 and QRP ARCI HF Grid Square Sprint ref 422, are different contests and
  both Inactive.)
- **DXLog:** no definition. Its grid-exchange files (`CASUALVHFGRID.txt`,
  `EUVUS-GRID.txt` and the VHF distance contests) are other events.
- **Status:** defunct, last held 13-14 April 1996, and the exchange was name +
  4-character grid with logs by email `[UNVERIFIED -- earlier pass used a CQ-Contest
  mailing-list archive and a KA9FOX rules file on qth.com]`.
- **TR4W has:** `Name`, and `HisQTH` (the grid, as `DomesticQTH`) `[TR4W code]`.
- **If kept:**
  - **Sent:** a new `'  %-10s %-4s'` of `MY NAME` and `MY GRID` (both genuine fields).
  - **Received:** `CabrilloReceivedNameQTH`, which exists.
  - **STX_STRING:** the sent text.
- **Confidence:** low.
- **Decision owed:** Q9 -- retire the class.
- **MORE INFORMATION, for NY4I (2026-10-15: "that does not sound like a contest (more
  like general qso)"):**
  - **Where it came from:** N6TR's original TR-Log DOS contest list. D7's
    `LOGPROM.PAS` has `Contests[27] := 'GRID LOC'`, between `GENERAL QSO` (26) and
    `HA DX` (28). It arrived in this tree with the DOS engine, not as a sponsor's
    contest.
  - **D7's row** (`VC.pas:3471`) gives it no email, no WA7BNM id, no QRZ.ru id, no
    ADIF or Cabrillo name and no friendly name, which is the shape of a generic mode,
    not a sponsored event. GENERAL QSO's row is the same.
  - **What TR4W does with it today:**
    - **exchange:** a name, and possibly a grid square;
    - **initial exchange:** the name;
    - **points:** one per QSO;
    - **multiplier:** every distinct grid square typed counts as a multiplier, per
      band (`WYSIWYGDomestic`, so the grid is taken as typed);
    - **dupes:** per band and per mode.
  - **So you are right: it is General QSO plus grid squares as multipliers**, a
    "grid-chasing log". The 1996 International HF Grid Location Contest the earlier
    pass named is not supported by any accepted source.
  - **The choice (Q9):**
    - (a) **retire it** (General QSO already logs name and grid);
    - (b) **fold it into General QSO** as an option that counts grids;
    - (c) **keep it** as a named generic mode that writes no Cabrillo file, like
      POTA and Kids Day (decision 1).

    Recommended: (a), unless an operator is known to use it.
  - **ANSWERED (NY4I, 2026-10-15): KEEP IT** -- option (c). *"I can see where someone
    may want to know if they have worked the same grid. so while general qso will
    allow logging of grid and name, grid loc would show if the grid is needed or
    worked so keep it."* Its purpose is the grid multiplier's worked/needed display,
    which General QSO does not have. Still to settle: whether it writes a Cabrillo
    file at all (decision 1's "no Cabrillo" hook, as POTA and Kids Day), and if it
    does, its name (`GRID-LOC` would follow the TEN-TEN / KIDS-DAY pattern).

### JALONGPREFECT: JARL All Cities All Guns (ACAG)

- **Identity -- ANSWERED (NY4I, 2026-10-15):** this class IS the JARL All Cities All
  Guns contest (全市全郡コンテスト). Reference: https://contestclock.com/contest/jarl-acag.
  Its domestic file `jacg3.dom` holds the city/gun codes `[TR4W code]`.
- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** not listed under any JARL ACAG name. The class id is 0. **DXLog:** no
  ACAG definition.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so
  `JA LONG PREFECT` or `JALONGPREFECT` (Q20).
- **Rules** -- `[contestclock jarl-acag -> jarl.org acag_rules]`, i.e.
  https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/acag_rules.html (the 47th
  running):
  - **When:** 21:00 JST Saturday to 21:00 JST Sunday, the weekend before the second
    Monday of October (1200Z 10 Oct to 1200Z 11 Oct 2026); logs received by 21 Oct.
  - **Who:** stations in Japan, and SWLs. Others may be worked but cannot enter.
  - **Bands:** 1.9, 3.5, 7, 14, 21, 28, 50, 144 and 430 MHz, and 1200 MHz and up.
    Phone all-band and Newcomer categories exclude 14 MHz.
  - **Modes:** CW, phone (AM/SSB; FM on 28 MHz and up), mixed. Cross-band and
    cross-mode contacts are not allowed.
  - **Exchange:** RST + the JCC/JCG number of the operating location (the **ward**
    number in a city with wards) + one power letter. Examples: `59100116L` (phone,
    Toshima ward, 10 W) and `59910002M` (CW, Nishitama gun, 100 W).
  - **Power letters:** H over 100 W; M over 10 W (20 W on 50-430 MHz) to 100 W;
    L over 5 W to 10 W (20 W); P 5 W or less.
  - **Points:** 1 per complete QSO.
  - **Dupe rule:** once per station **per band**; a second QSO on the same band on
    another mode does not count.
  - **Multipliers:** each different city, gun or ward, **once per band**; not per
    mode. Whether our own city counts is not stated.
  - **Score:** all-band, total points x total multipliers summed over bands.
  - **Log:** a JARL e-log, uploaded at contest.jarl.org/upload or emailed as text to
    acag@jarl.org; paper up to 100 QSOs. **Cabrillo is not mentioned** -- Q1.
- **What TR4W gets wrong for ACAG** `[TR4W code]`:
  - `ProcessRSTAndJAPrefectureExchange` reads RST + number and **never reads a power
    letter**;
  - the class's flags are `[cfQSOByMode]`: a dupe per **mode**, and multipliers
    **not** per band. JARL's rules say once per **band** and multipliers per band, so
    the right flags are `[cfQSOByBand, cfMultByBand]`, the same as ALL JA's;
  - the domestic file may be out of date.
  These are contest-scoring fixes (decision 4), not export.
- **Proposed layout:** the ALL JA layout, decided by Q1.
  - **Sent:** `599 100116L`, from our city code + `MY JA POWER CLASS`.
  - **Received:** `599 1001L`. This needs the parser to store `Precedence` first.
- **Station fields:** `MY JA POWER CLASS`; and `MY JA CITY CODE` if Q19 says so.
- **Confidence:** high on the rules (was low); low on the log format until Q1.
- **Decisions owed:** Q1, Q19, Q20; the parser, flags and `.dom` before a layout.

### KIDSDAY: ARRL Kids Day

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `KIDS DAY` or
  `KIDSDAY`; moot if no file is produced (decision 1).
- **WA7BNM:** ref 224, "Active historically, but unconfirmed"; two runs a year, in
  January and June (3 Jan and 20 Jun 2026). The class id is 224, which is right. Email logs to:
  "(none)" `[WA7BNM ref 224]`. **DXLog:** no definition.
- **Exchange:** name + age + QTH + favourite colour `[WA7BNM ref 224]`; the sponsor
  adds *"Be sure to work the same station again if an operator has changed."*
  `[WA7BNM ref 224 -> http://www.arrl.org/kids-day]`.
- **Not scored, and no log is submitted.** Participants post to the Kids Day Soapbox,
  email photos to contests@arrl.org, or fill in a survey of call sign, age groups,
  number of contacts and a description `[WA7BNM ref 224 -> arrl.org/kids-day]`.
- **TR4W has:** `Kids`, the whole received string `[TR4W code]`. No station field is
  proposed for our age or colour: no log is submitted, so the export never needs them.
- **Proposal:** **produce no Cabrillo.**
  - If a file is wanted anyway, the received column is `Kids` as typed, and the sent
    column is `MY NAME` plus free text.
  - **STX_STRING:** `MY NAME`, or leave it out.
- **Confidence:** high that no log is wanted.
- **Decision owed:** how a contest says "no Cabrillo" (decision 1).

### NZFIELDDAY: NZART Jock White Memorial Field Day (JW-FD)

- **Cabrillo spec:** no CONTEST: value. WA7BNM's Cabrillo names have two NZART
  entries, `MEMORIAL-CONTEST` (NZART Memorial Contest) and `WIA-JMMFD` (the Australian
  John Moyle Field Day); **neither is this event** `[Cabrillo spec -> WA7BNM cabnames]`.
  The class uses `JW-FD` for both ADIF and Cabrillo, set by NY4I on 2026-09-29
  `[TR4W code]`.
- **CONTEST: value under the D7 / enum rule:** D7's `CABName` was blank, so D7 wrote
  `NZ FIELD DAY` `[D7]`. NY4I's later explicit `JW-FD` is assumed to stand; Q20
  confirms.
- **WA7BNM:** not listed. The class id is 0 on purpose: its header says *"the calendar
  does not list the event, and 0 disables the calendar menu item"*. The NZART events
  WA7BNM does list are the Memorial Contest (721), the Sangster Shield (589) and the
  ZL Sprint (737). **DXLog:** no NZART definition.
- **Rules** -- all `[UNVERIFIED -- earlier pass used the search index's copy of
  nzart.org.nz/activities/contests/jwfd]`: last full weekend of February, 80 m and
  40 m, CW and phone; RS(T) + serial from 001 + NZART branch number, a home station
  sending `00`; separate per-band logs with *date, time, station worked, mode, band,
  exchange sent, exchange received*; no Cabrillo mentioned. **Q10.**
- **TR4W scores** `[TR4W code]`: a ZL station 5 points on CW and 3 on phone, any other
  station 10; a QSO in our own branch earns no branch multiplier.
- **TR4W has** `[TR4W code]`:
  - sent: `NumberSent`, and today `MY ZONE` (`ZoneSentForThisContest`) as the branch;
  - received: `RSTReceived`, `NumberReceived`, `Zone`. The parser reads a branch only
    for a ZL call.
- **Proposed layout:**
  - **Sent:** `'%-3s %.3d %.2d'` of RST, `NumberSent` and `MY NZART BRANCH`,
    e.g. `599 001 25`.
  - **Received:** the same from the QSO, e.g. `599 017 00`.
  - **Non-ZL station:** no branch is printed.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Station fields:** `MY NZART BRANCH`. Today the branch lives in `MY ZONE`, which is
  exactly the reuse the ruling rejects; the CQ-exchange default, the New Contest
  prompt and the own-branch scoring rule all read it and would move with it.
- **Confidence:** low until Q10.
- **Decisions owed:** Q10, Q20; and whether a non-ZL branch prints blank or as `00`.

### POTA: Parks on the Air

- **Cabrillo spec:** no CONTEST: value. WA7BNM's Cabrillo names hold only state-park
  programmes (`TNPOTA`, `TSPOTA`) `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `POTA`; moot if
  no file is produced (decision 1). DXLog also writes `POTA`, in a block it labels
  *"Dummy Cabrillo export"* `[DXLog POTA.txt]`.
- **WA7BNM:** national POTA is not listed. It lists state programmes: Ohio (486),
  Florida (612), Wisconsin (656), Kentucky (659), Texas (559), Tennessee (725),
  Georgia (738). None of them is this class. The class id is 0, which is right.
- **ADIF requirements** -- `[UNVERIFIED -- earlier pass used docs.pota.app and a
  third-party POTA_ADIF_NOTES.md on GitHub]`:
  - required fields `CALL`, `QSO_DATE`, `TIME_ON`, `BAND`, `MODE`;
  - activator fields `MY_SIG=POTA` and `MY_SIG_INFO`;
  - park-to-park fields `SIG` / `SIG_INFO`;
  - file name `CALL@PARK-YYYYMMDD.adi`;
  - ADIF only; no Cabrillo.
- **What DXLog does** `[DXLog POTA.txt]`, which **corroborates** the above (old Q12,
  now settled):
  - its Cabrillo line is commented out;
  - ADIF `MY_SIG=POTA` and `MY_SIG_INFO` = our reference with a hyphen inserted
    before the last four digits (`SM0228` -> `SM-0228`); `SIG=POTA` (or `WWFF` for an
    `FF` reference) and `SIG_INFO` for a park-to-park QSO;
  - dupe rule `PER_BAND_MODE_RCVD`: the same station again on a band and mode counts
    if it is in a different park;
  - 1 point per QSO; bands 160-6 m including 60 m; CW, SSB, FM.
- **TR4W already writes** `[TR4W code]` (`uContestPOTA.pas`,
  `EmitADIFExchangeFields` / `EmitADIFContestFields`):
  - `MY_SIG`, `MY_SIG_INFO` and `MY_POTA_REF`;
  - `SIG`, `SIG_INFO` and `POTA_REF`;
  - `SRX_STRING`;
  - `STX_STRING` = `ADIFSentPark`.
  - **ADIF needs nothing.** Flags `[cfQSOByBand, cfQSOByMode]`: a park-to-park repeat
    from a second park is a dupe in TR4W and not in DXLog. That is a logging-rule
    question for the contest-scoring owner, not export.
- **Proposal:** **produce no Cabrillo for POTA.** If a Cabrillo file is still wanted
  for the operator's own records, use `'%-3s %-10s'` of RST + `MY PARK` (sent) and
  RST + park worked (received).
- **Station fields:** none new; `MY PARK` exists.
- **Confidence:** medium-high (was medium): a second logger reads POTA the same way.
- **Decision owed:** the "no Cabrillo" mechanism (decision 1).

### QCWA: QCWA QSO Party

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `QCWA`.
- **Status:** Inactive; last held 1800Z 13 March to 1800Z 14 March 2021 `[WA7BNM ref
  332]`. The class id is 332, which is right. The QCWA Fall QSO Party (ref 127) is
  Inactive since 2013. **DXLog:** no QCWA definition.
- **Rules** -- `[WA7BNM ref 332 -> https://www.qcwa.org/2021-qso-party-rules.pdf]`
  (the 65th running):
  - **Exchange:** *"The callsign, year of license, name and
    chapter/state/province/country."* The year is the last two digits of the year
    first licensed. A station with no QCWA chapter (any non-member, or a member with
    no chapter) sends state, province or country. "At Large" (AL) must not be used.
  - **There is no serial.**
  - **Points:** CW/digital QSOs 2 each; phone 1 each. A station may be worked once per
    band/mode; CW and digital on one band count once.
  - **Bonus:** 100 points per QSO with W2MM, per band and mode.
  - **Multipliers:** each QCWA chapter, and each state, province or country reported
    by a station not in a chapter, **once per contest** regardless of band or mode.
  - **Score:** QSO points x multipliers, plus bonus points (WA7BNM's summary agrees).
  - **Logs:** paper to W2OD, or **digital logs in Cabrillo** to w2od@aol.com, within
    30 days. QsoNet (CQ100) operation is logged and scored separately.
  - **Unchanged from the first pass**, which quoted the 2020 rules. The 2021 rules,
    which WA7BNM links, say the same. **Removed:** the N1MM log-type note.
- **What TR4W parses** `[TR4W code]`:
  - `ProcessQSONumberNameChapterAndQTHExchange` expects *serial, name, chapter, QTH*,
    which is not this exchange.
  - `ProcessCheckAndChapterOrQTHExchange` reads the year into `Check` plus a chapter
    or QTH. It is close to the current rule, and **no contest uses it**.
  - Scoring is `OnePhoneTwoCW`, which matches the 1 / 2 points; the W2MM bonus and the
    chapter-or-QTH multiplier are not checked here.
- **Proposed layout, after the parser is fixed:**
  - **Sent:** `'%.2d %-10s %-4s'` of `MY YEAR LICENSED`, `MY NAME` and
    `MY QCWA CHAPTER`, else `MY STATE`, e.g. `61 TOM 151`. (Was `MyCheck`; the ruling
    rejects that reuse.)
  - **Received:** `Check`, `Name`, then `Chapter` (else the QTH).
  - **STX_STRING:** the sent text.
- **Station fields:** `MY YEAR LICENSED`, `MY QCWA CHAPTER`.
- **Confidence:** high on the rules; the event is inactive.
- **Decision owed:** Q11 -- retire, or re-model the exchange.

### QCWAGOLDEN: QCWA "Golden" contest

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `QCWA GOLDEN` or
  `QCWAGOLDEN` (Q20).
- **WA7BNM:** not listed. The class id is 0. **DXLog:** no definition.
- **No sponsor rules found** in any source. TR4W's row is identical to QCWA's. A
  comment in LOGSTUFF says the CHECK+CHAPTER parser was "Used for the QCWA Golden
  Anniversary contest" `[TR4W code]`; that it was a year-licensed exchange is
  `[UNVERIFIED -- earlier pass inferred it from that comment]`.
- **Proposal:** treat it like QCWA.
- **Station fields:** as QCWA.
- **Confidence:** low.
- **Decision owed:** Q12 -- retire it (most likely), or say what event it is.

### TENTEN: 10-10 International QSO parties

- **By the same principle as ARCI, confirm (Q13):** NY4I's ARCI answer -- separate
  events, each with its distinct WA7BNM ref -- reads directly onto 10-10's four
  events below. If confirmed, TENTEN becomes four contests, each with its WA7BNM
  Cabrillo name as its enumeration name.
- **Cabrillo names** `[Cabrillo spec -> WA7BNM cabnames]`, one per event:
  - `10-10-WINTER-PHONE` (ref 237); alias `10-10 WINTER PHONE`;
  - `10-10-SUMMER-PHONE` (ref 81); alias `10-10 SUMMER PHONE`;
  - `10-10-SPRINT` (ref 156); alias `10-10 SPRINT`;
  - `10-10-FALL-DIGITAL` (ref 464); alias `10-10 FALL DIGITAL`.
  The aliases are WA7BNM's, from each details page `[WA7BNM ref 237/81/156/464]`.
  **An enum identifier cannot start with a digit**, so the members would be spelled
  e.g. `TENTENWINTERPHONE`, with `ContestTypeSA` `10-10-WINTER-PHONE`; that is
  another reason Q20 matters.
- **CONTEST: value under the D7 / enum rule, as one class:** D7 blank `[D7]`, so
  `TEN TEN` or `TENTEN`. DXLog writes `TENTEN-{MODE}`, e.g. `TENTEN-PH`
  `[DXLog TENTENQP.txt]`; **it disagrees with WA7BNM's per-event names, and WA7BNM
  wins.**
- **WA7BNM:** Summer SSB and the 10-10 Day Sprint are "Active, confirmed"; Winter SSB
  and Fall Digital are "Active historically, but unconfirmed". Six more 10-10 events
  are Inactive. **The class id is 0** -- see **Q13**.
- **Dates** `[WA7BNM ref 237/81/156/464]`: Winter SSB 0001Z 7 Feb to 2359Z 8 Feb 2026;
  Summer SSB 0001Z 1 Aug to 2359Z 2 Aug 2026; Sprint 10 October every year; Fall
  Digital 0001Z 14 Nov to 2359Z 15 Nov 2026. 10 m only.
- **Exchange:** member: name + 10-10 number + state/province/country; non-member:
  name + `0` + state/province/country `[WA7BNM ref 237]`. The sponsor's words:
  *"call sign, name, 10-10# and QTH (State, Province or Country)"*
  `[WA7BNM ref 237 -> https://www.ten-ten.org/qso-party-rules/]`. **There is no RST.**
- **Scoring:** 2 points for a contact with a 10-10 number, 1 without; no multipliers;
  total = QSO points `[WA7BNM ref 237 -> ten-ten.org/qso-party-rules]`. DXLog
  agrees: 2 for a received number 1 or more, else 1, and no multiplier
  `[DXLog TENTENQP.txt]`. TR4W scores 2 for every QSO `[TR4W code]`; see design Q46.
- **Dupe rule:** once per band and mode `[DXLog TENTENQP.txt]`; TR4W's flags
  `[cfQSOByBand, cfQSOByMode]` agree `[TR4W code]`. One band, so effectively once per
  mode.
- **Log:** a cover sheet, a log and a dupe sheet; the log in date/time order with
  *UTC date, UTC time, call, name, 10-10# (0 if none), QTH and contact point value*;
  Q95 files are refused; email to tentencontest@ten-ten.org
  `[WA7BNM ref 237 -> ten-ten.org/qso-party-rules]`. **The referred rules name no
  electronic format** -- Q14.
- **Column order -- now corroborated.** DXLog's Cabrillo line is name (10 wide),
  10-10 number (5 wide, `0` for none), state/province/DXCC prefix (3 wide)
  `[DXLog TENTENQP.txt]`: the sponsor's exchange order, and this document's
  proposed order. It **contradicts** the earlier pass's upload-guide template
  (`BOB MA 12345`: name, **state**, number) `[UNVERIFIED -- earlier pass used
  ten-ten.org/guide-to-uploading-logs, which the WA7BNM-referred rules do not link]`.
  Two sources against one unreferred page; the proposed order stands.
- **TR4W has:** `Name`, `QTHString` (= `HisQTH`), `TenTenNum` (`MAXWORD` means none)
  `[TR4W code]`.
- **Proposed layout:**
  - **Sent:** `'%-10s %-6s %-3s'` of `MY NAME`, `MY TEN TEN NUMBER` (`0` if none) and
    `MY STATE`, e.g. `TOM        12345  FL`.
  - **Received:** `'%-10s %-6d %-3s'` of `Name`, the number (`0` for `MAXWORD`) and
    `HisQTH`.
  - **STX_STRING:** the sent text. (DXLog's is name + number + QTH, and name + QTH
    for a DX entrant `[DXLog TENTENQP.txt]`.)
  - **ADIF also has a `TEN_TEN` field** ([adif.org 3.1.7](https://www.adif.org/317/ADIF_317.htm)),
    worth writing for the received number. (ADIF is a format spec, not a contest
    rule, so the source rule does not apply to it.)
- **Station fields:** `MY TEN TEN NUMBER`.
- **Confidence:** high on the exchange, scoring and column order; medium on the file
  format (Q14).
- **Decisions owed:** Q13, Q14, and the scoring fix (design Q46).

### UA4WCHAMPIONSHIP: Udmurtia Championship (R4W-CHAMP)

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7's `CABName` is blank and its
  `ContestTypeSA` spelling is `R4W-CHAMP` `[D7]`, so **`R4W-CHAMP`**, legal Cabrillo.
  DXLog writes the same `[DXLog R4W-CHAMP.txt]`. **Settled.** (The enum identifier
  would be `UA4WCHAMPIONSHIP`; Q20 decides, but both are legal.)
- **WA7BNM:** not listed. The class id is 0. Its QRZ.RU id is 132 and its submission
  email `r4w@narod.ru` `[TR4W code]`; QRZ.RU is not an accepted source.
- **Rules** `[DXLog R4W-CHAMP.txt]`, whose `CONTESTRULES` is
  qrz.ru/contest/detail/132.html -- the same sponsor page the earlier pass could not
  reach:
  - **When:** from 1600 UTC for 120 minutes, in 15-minute periods. **This disagrees
    with the earlier pass**, which had two tours, SSB 16:00-17:59 and CW 18:00-19:59
    `[UNVERIFIED -- search snippets of qrz.ru]`. **Q15.**
  - **Bands:** 80 m and 40 m. **Modes:** CW and SSB; categories CW, SSB, Mixed.
    Single operator, 100 W or less; Junior overlay.
  - **Exchange:** serial from 001 + a four-character code: **a station in Udmurtia
    sends its RDA district (`UD01`-`UD34`); every other station sends its grid
    locator** (`KO55`). **No RST** (the RST field is hidden). This **corrects** the
    earlier pass, which had *all Russian* stations sending an RDA, with `TB02`
    (Tatarstan) as its example.
  - **Serial:** one sequence for the whole contest (`QSO_NUMBER=ALL`).
  - **Dupe rule:** once **per period per band** (`DOUBLE_QSO=PER_PERIOD_BAND`).
  - **Points:** 3 for a QSO with a Udmurtia station (`UD...`), 1 otherwise.
  - **Multipliers:** Udmurtia RDA districts per band, and grid locators per band.
  - **Log:** Cabrillo, `CONTEST: R4W-CHAMP`; the line is our serial (3 wide,
    zero-padded), our code, then the call, serial and code received.
- **TR4W's code against those rules** `[TR4W code]`:
  - `ProcessRSTAndGridSquareOrRDAExchange` reads RST + grid/RDA and **does not store a
    received serial**;
  - the class's scoring names 160 m, which the contest does not use;
  - flags `[cfQSOByBand, cfErmakSpecification]`: no per-period dupe and no
    per-band multiplier;
  - the class's CONTEST value is `R4W-CHAMP`, which is right.
- **Proposed layout, after the parser stores `NumberReceived`:**
  - **Sent:** `'%.3d %-4s'` of `NumberSent` and our code -- `MY RDA` in Udmurtia,
    else `MY GRID` -- e.g. `001 UD05`, or `001 KO85` outside Udmurtia.
  - **Received:** the same from the QSO, e.g. `017 KO85`.
  - **STX_STRING:** the sent text (DXLog's is serial + code `[DXLog R4W-CHAMP.txt]`).
  - **The RST column is dropped**: DXLog writes none, and the old open question
    "RST column in or out" is settled out.
- **Station fields:** `MY RDA` (Udmurtia only) if Q19 says so; `MY GRID` exists.
- **Confidence:** medium (was low): a full rule set from a second logger, citing the
  sponsor page; the time window is open.
- **Decisions owed:** Q15, Q19; the parser, scoring and flags update first
  (decision 4).

### WWL

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `WWL`.
- **WA7BNM:** nothing named WWL or World Wide Locator, active or inactive. The class id
  is 0.
- **DXLog:** no match. Of its 80 distance-scored definitions, none uses TR4W's rule.
  The nearest are the Stew Perry (160 m only, 1 + 1 per 500 km `[DXLog
  StewPerry.txt]`), UKEICC80 (80 m only, 1 + 1 per 500 km to 5000 km
  `[DXLog UKEICC80.txt]`) and the Russian 160 m contest (1 + 1 per 500 km, doubled
  on SSB `[DXLog Russian160.txt]`); none has the band doubling or a grid-field
  multiplier.
- **Identity:** unknown. The first pass's "World Wide Locator" came from a search
  index's listing of TR4W itself `[UNVERIFIED -- earlier pass used a search index]`.
- **TR4W's rule** `[TR4W code]`: one point per 500 km begun, x2 on 80 m and x4 on
  160 m; grid-field multipliers per band.
- **TR4W has:** `RSTReceived`, and the grid in `QTHString` / `HisQTH`.
- **Proposed layout:** all three helpers already exist.
  - **Sent:** `CabrilloSentRSTGrid` (`'%-3s %-7s'`), e.g. `599 KO85`, from `MY GRID`.
  - **Received:** `CabrilloReceivedRSTQTH`.
  - **STX_STRING:** `ADIFSentRSTGrid`.
- **Station fields:** none new.
- **Confidence:** high that the code is right for the exchange TR4W parses; low on
  the contest.
- **Decision owed:** Q16 -- name the event, or retire the class.

### XMAS: Christmas contest -- probably the SSA Jultest

- **Cabrillo spec:** `XMAS` is a registered CONTEST: value, and it belongs to the
  **DARC Christmas Contest** `[Cabrillo spec -> WA7BNM cabnames]`; DXLog agrees
  `[DXLog DARC_XMAS.txt]`.
- **CONTEST: value under the D7 / enum rule:** D7 blank `[D7]`, so `XMAS` -- the
  DARC contest's name. **Q18.**
- **WA7BNM ref 210, DARC Christmas Contest** `[WA7BNM ref 210]`:
  - 26 December, 0830Z-1059Z; 80 m and 40 m; CW and SSB;
  - exchange: DL stations RS(T) + DOK (or `NM` if not a DARC member); non-DL stations
    RS(T) + serial;
  - 1 point per QSO; multipliers DOKs and prefixes, each once per band;
  - upload log at dxhf2.darc.de; Cabrillo name `XMAS`;
  - rules `[WA7BNM ref 210 -> https://www.darc.de/der-club/referate/conteste/weihnachtswettbewerb/en/]`.
  - DXLog's DARC file agrees, and counts dupes and both multipliers per band **and
    mode** `[DXLog DARC_XMAS.txt]`. TR4W's separate `DARCXMAS` class covers it.
- **TR4W's XMAS** `[TR4W code]`: RST + serial + a 5-letter random group generated per
  QSO by Ctrl-R in LogSend; 2 points per QSO; QRZ.RU id 100, the same as TR4W's
  DARC-XMAS. **That exchange does not match DARC's.**
- **The SSA Jultest matches** `[DXLog SSA_JT.txt]`, whose rules link is
  hfcontest.ssa.se/ssa-jt/regler.html:
  - 80 m and 40 m; CW and SSB; Single Operator and Checklog; High, Low, QRP;
  - exchange: RST + serial (3 digits, zero-padded) + a five-letter group;
  - **the group sent is the group received in the previous QSO**; only the first is
    chosen by the operator (`FIRST_PREV_RECINFO=EXCHANGE`, and the sent column is
    `PREV_RECINFO`);
  - dupe rule once per band; **2 points** per QSO between two SM stations; **no
    multipliers**;
  - Cabrillo `CONTEST: SSA-JULTEST`, sample line
    `QSO:  3500 CW 2006-12-25 0802 7S3A 599 002 GJRBX SM5ALJ 599 001 NSTVO`.
  The SSA Jultest is still not on WA7BNM, so this rests on DXLog, not the sponsor.
- **Where TR4W differs from the Jultest:** TR4W makes a **new random** group for each
  QSO; the Jultest **passes on** the last group received. TR4W also counts
  multipliers per band (`cfMultByBand` `[TR4W code]`) where the Jultest has none.
  **Q17.** The other Christmas files in DXLog (`HB_XMAS.txt`, USKA, canton exchange;
  `RSGB_VHF_XMAS.txt`, VHF distance) do not match, nor does WA7BNM's CW QRS Xmas
  Activity (ref 709: RST + name + QTH).
- **TR4W has:**
  - sent: `NumberSent` and `RandomCharsSent`, both per QSO in `aQso`;
  - received: `RSTReceived`, `NumberReceived` and `RandomCharsReceived`.
- **Proposed layout** (unchanged; it already matches DXLog's Jultest line):
  - **Sent:** `'%-3s %.3d %-5s'` of RST, `NumberSent` and `RandomCharsSent`,
    e.g. `599 001 PZRIQ`.
  - **Received:** the same from the QSO.
  - **STX_STRING:** the sent text. (DXLog's is the serial only `[DXLog SSA_JT.txt]`.)
  - **Helpers:** new.
- **Station fields:** none.
- **Confidence:** medium on the identity (was low); the layout follows TR4W's own
  exchange; the group rule is Q17.
- **Decisions owed:** Q17 and Q18. If it is not DARC's contest, the class should not
  write `CONTEST: XMAS`.

## Decisions owed

1. **"No Cabrillo" for POTA and Kids Day.** `TContestBase` has no hook that says a
   contest produces no Cabrillo file. The options are:
   - **(a)** a virtual (e.g. `WritesCabrillo: boolean`) so the export says "this
     activity has no Cabrillo" and writes nothing;
   - **(b)** keep the loud marker;
   - **(c)** invent a layout.
   **(a) is recommended.** (b) leaves every export reporting a failure that is not one.
   DXLog's POTA definition does in effect (a): a dummy block and no QSO line.
2. **Missing station facts -- ANSWERED (NY4I, 2026-10-15):** *"Don't reuse fields. We
   should use distinct station fields."*
   - Option (c), reusing `MY PREC` for the JA power letter, `MY CHECK` for the QCWA
     year and `MY STATE` for a county, is **REJECTED**.
   - **Each fact gets its own distinct station field.** The list, and which of them
     the export, the on-air exchange and scoring each need, is in
     [Fields that are available](#fields-that-are-available-and-fields-that-are-not):
     `MY TEN TEN NUMBER`, `MY ARCI NUMBER`, `MY POWER`, `MY FISTS NUMBER` (if FISTS is
     kept), `MY JA POWER CLASS`, `MY COUNTY`, `MY QCWA CHAPTER`, `MY YEAR LICENSED`
     and `MY NZART BRANCH` (which moves the NZ branch out of `MY ZONE`).
   - Still open under this ruling: Q19, whether `MY STATE` carrying a JA prefecture,
     an ACAG city code or an RDA district is also reuse.
   - Nothing is created in code by this document. Adding a setting follows
     `docs/ADDING_A_SETTING.md`.
3. **Retire or keep the defunct and unidentified contests:** FISTS (Q8), GRIDLOC
   (Q9), QCWA (Q11), QCWAGOLDEN (Q12) and WWL (Q16). COUNTYHUNTER is the MARAC
   contest and is kept (NY4I, 2026-10-15); which MARAC event is Q4.
4. **Contests whose parser, flags or scoring must change before a layout means
   anything:**
   - **COUNTYHUNTER:** MARAC scoring, multipliers and the worked station's type
     (Q4-Q7);
   - **UA4W:** the serial is not stored, no RST is sent, 160 m is not a contest band,
     the dupe is per period per band and the multipliers per band
     `[DXLog R4W-CHAMP.txt]` (Q15 for the window);
   - **JALONGPREFECT (ACAG):** the power letter is not read, and the flags must
     become per-band dupe and per-band multipliers, not per-mode
     `[contestclock jarl-acag -> jarl.org acag_rules]`;
   - **ARCI:** split into six classes (NY4I); Topband's dupe and multiplier rules
     and SSB power table differ; the homebrew and portable bonuses;
   - **XMAS:** the group rule, and whether it has multipliers (Q17);
   - **QCWA:** the exchange is year + name + chapter.
   These belong to the contest-scoring and contest-factory owners, not to export.
5. **CONTEST values with spaces -- NARROWED to Q20.** NY4I's D7 / enumeration rule
   decides every name. If "the name in the enumeration" is the `ContestTypeSA`
   spelling, seven stay illegal Cabrillo (`ALL JA`, `COUNTY HUNTER`, `GRID LOC`,
   `JA LONG PREFECT`, `KIDS DAY`, `QCWA GOLDEN`, `TEN TEN`) `[Cabrillo spec]`; if it is
   the enum identifier, none are. Renaming one changes its ADIF `CONTEST_ID` too, and
   the old spelling would then need to be kept for import, as JW-FD does.
6. **Per-contest questions** are the numbered list at the top.

## Contests WA7BNM marks inactive, or does not list

- **Inactive:** FISTS (ref 251, and every other FISTS sprint); QCWA (ref 332; Fall
  party ref 127); both MARAC contests (refs 3 and 20).
- **"Active historically, but unconfirmed":** Kids Day (224); 10-10 Winter SSB (237)
  and Fall Digital (464); ARCI Topband (193) and Holiday Homebrew (198); DARC
  Christmas (210).
- **"Active, but no recent results":** ARCI Fall QSO Party (168).
- **Not listed at all:** ALL JA, JA ACAG, Grid Location, NZART Jock White Field Day,
  national POTA, QCWA Golden, Udmurtia Championship, WWL, SSA Jultest. Of these,
  DXLog encodes ALL JA, POTA, the Udmurtia Championship and the SSA Jultest.

## Rules that rest on a non-accepted source

Each of these is marked `[UNVERIFIED -- ...]` in its section and has a question.

- **JARL log format** (Q1): the e-log's Cabrillo body rests on jarl.org found by
  search.
- **Grid Location** (Q9): a mailing-list archive and a third-party rules file.
- **NZ JW-FD** (Q10): the search index's copy of nzart.org.nz.
- **10-10 file format** (Q14): a ten-ten.org page the referred rules do not link.
- **UA4W time window** (Q15): search-index snippets of qrz.ru against DXLog.
- **WWL** (Q16) and **QCWA Golden** (Q12): no rules at all.
- **MARAC** (Q5, Q6): WA7BNM's two pages give the scoring, but their sponsor link is
  dead, so nothing past the details pages is checked.

**Resting on DXLog alone** (another logger, not the sponsor; acceptable under NY4I's
2026-10-15 addition, but weaker than a WA7BNM-referred page): ALL JA's exchange,
scoring, dupe and multipliers; POTA's no-Cabrillo reading; the Udmurtia rules; the
SSA Jultest identification for XMAS.
