# Contest factory: open questions for NY4I

Collected 2026-10-02 from `docs/CONTEST_OWNERSHIP_DESIGN.md` (where each question
lives with its full evidence, under the same Q number) and from the session.
Branch `contestFactory`. Fill in the **Answer:** line; anything left blank keeps
today's behaviour.

Three groups:

1. **Sponsor rules** -- only you can answer these.
2. **Design** -- each has a recommendation; "accept" is a valid answer.
3. **Already answered** -- listed so nothing is asked twice.

---

## 1. Sponsor rules

### Field Day

- **FD-DX** You wrote "or with a bad ARRL section or DX on field day" next to the
  refusal ruling. Earlier you said a DX station *can* be worked (`1D DX`). Did you
  mean (a) an example of an existing error, e.g. a W station sending `DX` as its
  section, or (b) that a DX contact should be refused in Field Day?
  Today: Field Day accepts DX.
  **Answer:**

- **Q30** Winter Field Day accepts `MX` as a QTH. It still exports as `ARRL_SECT`
  and imports as a section. Is `MX` "DX" under the "DX is never a section" rule?
  **Answer:**

- **Q38** Winter Field Day's score is points x band-modes x power factor, with no
  DX multiplier, yet its session counts DXCC multipliers
  (`ARRLDXCCWithNoARRLSections`). Like Field Day (no multipliers at all), should it
  be none? Only the remaining-multiplier display would change.
  **Answer:**

### Sweepstakes

- **Q31** Any refused exchange with no precedence in it (e.g. `599` alone) now
  says `Missing precedence (Q A B U M S)`. Is that wording acceptable?
  **Answer:**

### QSO parties

- **Q29** "Out-of-state stations work only the host state" is now the default for
  every state party. I could confirm it from the sponsor for NC, CA, WA, BC, AZ,
  FL and ID. Not checked: Michigan, Minnesota, Missouri, Texas, Ohio,
  Pennsylvania, New York, Virginia, Wisconsin, Tennessee, Colorado, Indiana.
  Does any of them let out-of-state stations work each other?
  **Answer:**

- **Q32** Missouri: a "peak-hour" bonus (+1 per 80/40 m QSO logged 1400-1959 UTC,
  up to 250) is counted in live entry only and lost when the log is reopened.
  WA7BNM's rule summary has no such bonus (only W0MA and K0GQ +100 each, and +100
  for an electronic log). Real rule? If yes it is computed from the whole log; if
  no it is deleted.
  **Answer:**

- **Q34** Idaho rovers earn the dormant-county bonus per county they activate, but
  no QSO records the county it was sent from. Add a per-QSO "my county" (log
  field, entry, ADIF `MY_CNTY`), or keep scoring a rover as a fixed station in its
  MY STATE county?
  **Answer:**

- **Q35** Idaho dormant-county threshold: the rovers page says "makes 10 valid
  QSO's", the rules page "MORE THAN 10 contacts". 10 is implemented. The rovers
  page also says "only counties listed in RED are eligible", but the table has
  blue 500-point and red 1000-point counties; all are paid today. Which reading
  is the sponsor's?
  **Answer:**

- **Idaho-DC** Idaho's in-state multipliers include the states and provinces but
  not DC; the sponsor says "each US state". Should DC count?
  **Answer:**

- **Idaho-cfg** The template `target/dom/Idaho QSO Party.cfg` has never shipped in
  the installer. Ship it, or delete it now that the New Contest dialog creates the
  contest?
  **Answer:**

### Other contests

- **Q15** NRAU-Baltic: the contest calendar lists Cabrillo names `NRAU-CW` /
  `NRAU-SSB`; TR4W sends `NRAU-BALTIC-CW` / `NRAU-BALTIC-SSB`. Which is right?
  **Answer:**

- **Q16** Sprint SSB is its own contest, but its ADIF/Cabrillo name is
  `NA-SPRINT-SSB` and its friendly name "North American Sprint, SSB". Change to the
  sponsor's name (https://ssbsprint.com/rules/)? Its multipliers come from the
  `naqp` file with no DXCC, unlike the NA Sprints' North American DXCC. Intended?
  **Answer:**

- **Q17** Locust (inactive): the calendar says CW only, 80 and 40 m, no
  multipliers. TR4W scores every band and mode and counts domestic multipliers.
  State its bands and drop the multipliers, or leave an inactive contest as it was?
  **Answer:**

- **Q36** Locust: 5000 points per QSO with K6VVA or name LOCUST, multiplied like
  any QSO point. Is that the rule, or a one-time bonus after multiplication?
  **Answer:**

- **Q18** Jock White Field Day (https://www.nzart.org.nz/activities/contests/jwfd):
  are ZL contacts 5 CW / 3 phone and non-ZL 10 still the rule? Digital and FM score
  3 today. Your own branch is never a multiplier -- does the sponsor count it?
  **Answer:**

- **Q22** PACC: the row says `RSTAndQSONumberOrDomesticQTHExchange`, but every PACC
  session runs `RSTDomesticQTHExchange`. Which is the contest's exchange?
  **Answer:**

- **Q23** CUP RF: the Cabrillo writer uses the QSO's own QTH for the CW and SSB
  runnings but not for CUP RF DIGITAL. Intended?
  **Answer:**

- **Q24** FOC Marathon now reads N1MM's `APP_N1MM_EXCHANGE1` as the membership
  number when the record has no `FOC_NUM` (what the old code intended but never
  did). Confirm.
  **Answer:**

- **Q26** WAG: an imported record with no `DOK` keeps its received RST (`599`) as
  the QTH. Should it be empty?
  **Answer:**

- **Q27** SAC silently clears the entry when a Russian station (UA, UA2, UA9, EU) is
  typed. Should it show an error, like other invalid stations? And is a Russian
  station really not workable in SAC, or only not a multiplier?
  **Answer:**

### Added after M7b batch 1

- **Q40** Multi-state parties (7QP, NEQP, IN7QPNE): should they share a
  multi-state party base? On a line between two states, whose county rule
  applies? 7QP's sponsor allows up to 4 counties on a line -- enforce it? Nothing
  enforces it today.
  **Answer:**

- **Q41** ARRL VHF: September is set up with the contest name `'VHF QSO JUNE'`
  (the old code named both runnings), and January has never had any setup at
  all -- no 6 m start, HF bands left on. Intended?
  **Answer:**

- **Q42** OZCHR: both session names are literal `?` characters; the Cyrillic was
  lost before this tree (D7 too). Restore the Cyrillic, or use Latin names?
  **Answer:**

- **Q43** (Q7 made concrete) Which of these pairs are ONE contest under one rule
  (a base with children) rather than separate contests: JIDX CW/SSB (identical
  but for names), All Asian CW/SSB, Oceania CW/SSB, the four EU Sprints, the
  three ARRL VHF runnings?
  **Answer:**

### Added after M7b batch 2

- **Q43, extended** Batch 2 added four more sibling pairs to the same question:
  King of Spain CW/SSB and REF CW/SSB (identical rows but for names and ids),
  RSGB RoPoCo CW/SSB (one shared set-up), and the Region 1 Field Day RCC CW/SSB
  runnings (identical rows). Are any of them one contest under one rule?
  **Answer:**

- **Q45** EUDX and IRTS score "is the worked station in the EU?" with a test that
  can never be false (`DomMultQTH[4] <> ''`), so every contact scores as an EU
  contact -- 10 points (2 for our own country when we are in an EU region). The
  sponsor's table needs a real EU test. What should decide it (the domestic
  file's region code?), and should it be fixed now? Both contests' scores move.
  **Answer:**

- **Q46** Ten-Ten scores 2 for every QSO: the "2 with a Ten-Ten number, else 1"
  test can never be false (a 16-bit field compared with -1). Should a QSO with no
  Ten-Ten number score 1, as the code was evidently meant to?
  **Answer:**

### Added after M8 (multipliers and dupes)

- **Q48** YB DX: the program had a rule "for an Indonesian entrant, set the
  prefix multiplier again" that set exactly the value it already had -- it did
  nothing, here and in D7. It is deleted (nothing moved). What was it meant to
  do -- does an Indonesian entrant count a different multiplier (prefixes
  rather than districts?) in the sponsor's rules?
  **Answer:**

- **Q49** BC QSO Party: "a DX station earns no multiplier" tests the
  multiplier for lower-case `dx`, but the in-province file maps `dx=DX`
  (`target/dom/ve7.dom` line 2), so the multiplier is always upper-case `DX`
  and the rule never fires -- an in-province station gets a `DX` domestic
  multiplier. New York and Indiana test `DX` and do fire. Should BC's be
  `DX` like theirs? (A scoring change for in-province BC logs with DX QSOs.)
  **Answer:**

---

## 2. Design (recommendation given; "accept" is enough)

- **Q6** POTA as a contest class, following the General QSO precedent. Its park
  "n-fer" is stored the same way as a county line. *Recommended: yes.*
  **Answer:**

- **Q7** Apply the NRAU pattern (a base + CW/SSB children) to every two-mode pair?
  So far only NRAU-Baltic has it; NA Sprint CW/RTTY and the other pairs are
  siblings or copies. *Recommended: only where the two rows are genuinely one rule
  today; otherwise copies.*
  **Answer:**

- **Q28** UA4W: may the station context carry MY CALL's CQ zone, so UA4W can get a
  class? *Recommended: yes* (the same service shape ARRL 160 is getting).
  **Answer:**

- **Q33** RSGB 1.8 MHz scores 7 for a contact that is a new multiplier. May a class
  be handed the multiplier sheet's "is this a new multiplier?" answer, so it can
  get a class? *Recommended: yes, as a read-only question at M8.*
  **M8 did not build it, on purpose (unanswered):** M8's seam is the contest
  DECLARING which QSOs count; this is the contest READING the sheet while
  scoring one QSO -- a history-dependent point rule, which design 7.7 says to
  allow only by widening stage 1 deliberately. What it needs, measured: a
  read-only query handed in with the station (is domestic key X / DX country
  N unworked over ALL bands and BOTH modes -- the arm ignores the session's
  by-band and by-mode keys and whether DX multipliers are on at all).
  **Answer:**

- **Q37** `LOGGRID.ConvertGridToLatLon` reads past the end of a grid shorter than 4
  characters, so a malformed grid's score depends on leftover memory (identical
  ALRS QSOs scored 43, 42, 42). Tesla and European VHF read short grids the same
  way. Fixing it changes scores for malformed grids in every grid contest. What should a malformed grid score? *Recommended: fix the
  read; a grid that is not a grid scores as no distance.*
  **Answer:**

- **Q4** Retire `EXCHANGE RECEIVED`, the four multiplier commands and `INITIAL
  EXCHANGE` along with `QSO POINT METHOD` at the end? They select from shared sets
  the same way. *Recommended: yes.*
  **Answer:**

- **Q8** Events with no `ContestType` that the code still identifies by name:
  `'TRC'`, `'PGA'`, `'EURASIA'`, `'DL-DX-RTTY'`. Give each a type and class, or
  delete the tests? *Recommended: give a type to any that is still run; delete the
  rest.*
  **Answer:**

- **Q9** Should an operator-edited CQ memory survive re-selecting the contest?
  *Recommended: yes -- an edited memory is an operator statement.*
  **Answer:**

- **Q10** May a `ContestType` nobody runs be deleted instead of given a class?
  *Recommended: yes, with the list shown to you first.*
  **Answer:**

- **Q11** Legacy scoring arms reachable only through an operator's `QSO POINT
  METHOD`, and three point kinds with no arm (`SouthAmerican`, `IN`, `NYQPQP`):
  delete them together when the setting retires. *Recommended: yes.*
  **Answer:**

- **Q13** Oregon QSO Party scores by the radio's current mode, not the QSO's, so a
  rescore follows the radio. Fix when OQP gets its class? *Recommended: yes* (the
  same kind of fix as the Croatian clock).
  **Answer:**

- **Q44** Three contests keep their band rule inside their scoring, not as the
  contest's bands: RTC (0 points and no multiplier off 40/20/15/10 m or off
  CW/SSB), and CQMM and WRTC (0 points off 80-10 m, but the multiplier still
  counts). Your off-band ruling is 0 points and no multiplier. State each one's
  bands the standard way? *Recommended: yes* -- RTC changes nothing visible; CQMM
  and WRTC stop crediting a multiplier from an off-band QSO.
  **Answer:**

- **Q47** Three harmless read-past-the-end shapes were kept exactly: MWC (a call
  longer than ten characters, or ending in `/`), the Region 1 Field Day (no MY
  COUNTRY), and the Region 1 RCC runnings (a one-character call scores 4). Bound
  them the next time each contest is touched? *Recommended: yes* -- no real QSO's
  score moves.
  **Answer:**

- **Q50** "A Russian call's oblast" is written three ways that disagree: the
  initial exchange from a call (Russian DX, RU3AX -- CTY.DAT country starting
  `UA`, standard call format), LOGEDIT's initial-exchange fallback (Russian DX,
  RDA, RU3AX -- `RussianID` of the country, so any `R...` entity too, raw
  call), and the need-multiplier hint (Russian DX, RF Championships --
  `RussianID` of the CALL). M8 moved the hint as it was and left the fallback
  in LOGEDIT (it is an exchange rule, not a multiplier one). Make it one rule
  each contest calls? *Recommended: yes* -- `RussianID` of the country is the
  likely intent; only `R...` entities outside `UA` (e.g. Franz Josef Land)
  move, and only in what is pre-filled or hinted.
  **Answer:**

- **Q51** An off-band QSO no longer marks the dupe sheet at all (M8), so the
  30 m dupe sheet and the Stations window's `+` do not show it -- consistent
  with "not a dupe", but they are also "have I worked him there" displays.
  Keep it so, or keep a worked-there mark that is not a dupe? *Recommended:
  keep it so* -- one rule, and no shipped contest but Idaho states bands.
  **Answer:**

---

## 3. Already answered (for reference)

| Q | Answer | Where it landed |
|---|---|---|
| Q1 | Field Day has no multipliers; DX is never an ARRL section | M2 |
| Q2 | No interim fix for the rotated point-method spellings | design 7.2 |
| Q3 | The log stores only what the operator stated | M2a (decided under delegation) |
| Q5 | Salmon Run W7DX bonus: implement | M6 |
| Q12 | `TContestFixedPoints` retired, `FixedModePoints` kept | M3 |
| Q14 | Out-of-state works only the host state; `nc_cty.dom` = 100 counties | M5b |
| Q19 | No Sweepstakes QSO without a precedence (refused) | M5b |
| Q20 | FD DX exports `CLASS` as logged, `SRX_STRING` `1D DX`, never `ARRL_SECT` | M5b |
| Q21 | Night rules read the QSO's recorded time | after M4 |
| Q25 | FD DX import is not a section | M5b |
| Q39 | A contest never writes a station setting | design 7.11 (decided), lands M9 |
| -- | Out-of-state x out-of-state in a QSO party: refuse with an error | M5b |
| -- | Off-band QSO: logged, 0 points, no mult, no need-mult hint, not a dupe | 1e4f66f9 (points, mults); M8 (dupes, hints) |
| -- | QRP = our power; last touch point wins; may change mid-contest with a reminder | Idaho, design 7.6 (M9) |
| -- | ALL ASIAN SSB is `ALL-ASIAN-DX-PHONE` | e1c6f873 |
| -- | RSGB RoPoCo: an ADIF record is the SSB running's when its mode is phone (one ADIF id, `RSGB-ROLO`) | M7b batch 2 (decided under delegation, design 8.2k) |

---

## Not questions, but waiting on you

- **Translations:** `tr4w/languages/tr4w_laz.pot` is from 2026-09-08, so 35 of
  `uAppStrings`' 48 strings are in no catalogue and show in English everywhere.
  Fix: regenerate the `.pot` in the Lazarus IDE, then
  `python tools/i18n/po_merge.py --pot tr4w/languages/tr4w_laz.pot --apply`.
- **Bench checks** (`docs/BENCH_QUEUE.md`): Idaho in-state and out-of-state
  multipliers; live Croatian and UK/EI logging by day and night; DXKeeper
  receiving `ARRL-FIELD-DAY`; typed-entry refusals; the score display with
  bonuses.
