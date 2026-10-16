# Contest factory: open questions for NY4I

Collected 2026-10-02 from `docs/CONTEST_OWNERSHIP_DESIGN.md` (where each question
lives with its full evidence, under the same Q number) and from the session.
Branch `contestFactory`. Fill in the **Answer:** line; anything left blank keeps
today's behaviour.

Four groups. **Sections 1 and 2 hold ONLY open questions**; an answered one
moves to section 4 in the commit that records it.

1. **Sponsor rules** -- only you can answer these.
2. **Design** -- each has a recommendation; "accept" is a valid answer.
3. **Awaiting only your yes** -- answered from the sponsor's own page (your
   source rule) or decided under the delegation; a "yes" closes each.
4. **Already answered** -- listed so nothing is asked twice.

---

## 1. Sponsor rules

### QSO parties

- **Q35** Idaho dormant-county threshold: the rovers page says "makes 10 valid
  QSO's", the rules page "MORE THAN 10 contacts". 10 is implemented. The rovers
  page also says "only counties listed in RED are eligible", but the table has
  blue 500-point and red 1000-point counties; all are paid today. Which reading
  is the sponsor's?
  **Answer:**

### Other contests

- **Q15** NRAU-Baltic: the contest calendar lists Cabrillo names `NRAU-CW` /
  `NRAU-SSB`; TR4W sends `NRAU-BALTIC-CW` / `NRAU-BALTIC-SSB`. Which is right?
  *Now answerable from the sources: the Cabrillo spec's contest list and the
  sponsor's public logs say which name is current.*
  **Answer:**

- **Q16** Sprint SSB is its own contest, but its ADIF/Cabrillo name is
  `NA-SPRINT-SSB` and its friendly name "North American Sprint, SSB". Change to the
  sponsor's name (https://ssbsprint.com/rules/)? Its multipliers come from the
  `naqp` file with no DXCC, unlike the NA Sprints' North American DXCC. Intended?
  *Partly settled: the Cabrillo name is the class's own definition (Q52), by
  the name rule (D7's, else the enumeration), so `NA-SPRINT-SSB` stays unless
  the sponsor's page or its public logs say otherwise; the friendly name is
  Q52/Q53's. The multiplier half goes to the DXLog cross-check.*
  **Answer:**

- **Q22** PACC: the row says `RSTAndQSONumberOrDomesticQTHExchange`, but every PACC
  session runs `RSTDomesticQTHExchange`. Which is the contest's exchange?
  **Answer:**

- **Q23** CUP RF: the Cabrillo writer uses the QSO's own QTH for the CW and SSB
  runnings but not for CUP RF DIGITAL. Intended?
  **Answer:**

- **Q27** SAC silently clears the entry when a Russian station (UA, UA2, UA9, EU) is
  typed. Should it show an error, like other invalid stations? And is a Russian
  station really not workable in SAC, or only not a multiplier?
  *Partly settled by 7.10 and FD-DX (2026-10-15): a station the contest does
  not accept is REFUSED WITH AN ERROR, never silently cleared. Still open: is
  a Russian station really not workable in SAC, or only not a multiplier?*
  **Answer:**

- **Q97** (found implementing Q50, 2026-10-15) Franz Josef Land (`R1FJ`)
  is a Russian entity, so the Russian DX contests now pre-fill and hint an
  oblast for it -- but `GetRussiaOblastID('R1FJL')` reads the `1F` after the
  prefix and answers `SP`, St Petersburg. D7's live fallback pre-filled the
  same `SP`; the hint is new. What does the RDXC sponsor count FJL as --
  Arkhangelsk (`AR`, its administrative oblast), its own multiplier, or no
  oblast? Malyj Vysotskij (`R1MV`) has the same shape.
  **Answer:**

### Added after M7b batch 1

- **Q40** Multi-state parties (7QP, NEQP, IN7QPNE): should they share a
  multi-state party base? On a line between two states, whose county rule
  applies? 7QP's sponsor allows up to 4 counties on a line -- enforce it? Nothing
  enforces it today.
  **Answer:** **IN7QPNE RULED 2026-10-13: a composite of four parties (IN, 7QP, NE, DE), per-QSO rules of the worked station's party; one Cabrillo; no score posting -- design 7.14. 7QP/NEQP multi-state rules otherwise still open.**

- **Q42** OZCHR: both session names are literal `?` characters; the Cyrillic was
  lost before this tree (D7 too). Restore the Cyrillic, or use Latin names?
  **Answer:**

- **Q43** (Q7 made concrete) Which of these pairs are ONE contest under one rule
  (a base with children) rather than separate contests: JIDX CW/SSB (identical
  but for names), All Asian CW/SSB, Oceania CW/SSB, the four EU Sprints, the
  three ARRL VHF runnings?
  *Now decidable under Q7's rule ("one rule today" = a base; otherwise
  copies): the rows named here are measurably identical or not, so I can
  propose each pair from the evidence for a yes.*
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

### Added after M8 (multipliers and dupes)

- **Q48** YB DX: the program had a rule "for an Indonesian entrant, set the
  prefix multiplier again" that set exactly the value it already had -- it did
  nothing, here and in D7. It is deleted (nothing moved). What was it meant to
  do -- does an Indonesian entrant count a different multiplier (prefixes
  rather than districts?) in the sponsor's rules?
  **Answer:**

### Added after M9a (the display and the reports)

- **Q52** Every contest's display name is now its row's friendly name, as you
  asked -- the name the New Contest drop-down will show at M9b. Twelve
  classes had a longer hand-written one: "ARRL International DX Contest - CW"
  is now "ARRL Inter. DX Contest, CW", "CQ World Wide DX - CW" is "CQ Worldwide
  DX Contest, CW", "General QSO" is "General QSO/DX Logging" (and the
  Sweepstakes, CQ WPX, NA Sprint and ARRL Digital ones). Which should the
  drop-down show? If the longer ones, the friendly name changes with them,
  and that also changes the summary sheet's `CONTEST:` line and the log
  database's friendly name.
  *Ruled in part (NY4I, 2026-10-15): "I disagree that the longer display name
  should have anything to do with the CONTEST: name in Cabrillo. The cab name
  should just be another definition in the contest class."* **It already is,
  and the question above was wrong to suggest otherwise:** the Cabrillo file's
  `CONTEST:` line is `GetCabrilloName` (`postunit.pas:2802`, through
  `CabrilloContestName`), and the display and friendly names never reach it.
  What a friendly-name change DOES reach is the printed summary sheet, whose
  "CONTEST:" line is the session's contest name with the friendly name in
  brackets (`postunit.pas:993`), and the log database's friendly-name column.
  Still open: which WORDS the drop-down shows.
  **Answer:**

- **Q53** Forty-seven contests have no friendly name, so their display name is
  still the internal spelling -- `ALRS-UA1DZ-CUP`, `RF-CUP-CW`, `UKEI`,
  `YOUTHCHAMPIONSHIPRF` and the rest
  (`uTestContestDisplay.ENUM_SPELLED_DISPLAY_NAMES`). Human names for them,
  please; any you give leave that list.
  **Answer:**

- **Q55** WRTC's live-score XML has never carried a multiplier: its rule
  posts HQ and country on an "all modes" row the writer never produces. Post
  them per mode, add the row, or leave it (WRTC forbids score posting anyway)?
  *No longer moot: Q83 (2026-10-15) lets WRTC post ONLINE scores, so the posted XML needs the multipliers -- this question is live.*
  **Answer:**

### Added after M9b (the New Contest drop-down and CATEGORY-POWER)

- **Q52 note** -- M9b did what you asked: the drop-down shows the display
  name, which is now the friendly name. Q52 still asks WHICH words; answering
  it changes the drop-down with no further code.

- **Q58** WRTC's row gives it IARU's friendly name, "IARU HF World
  Championship", so the two were identical lines in the drop-down. They now
  read "IARU HF World Championship [IARU-HF]" and "... [WRTC]" (the token in
  brackets, only where a name is shared). A name of WRTC's own, please -- it
  also becomes its friendly name, which the summary sheet's `CONTEST:` line
  and the log database show.
  **Answer:**

- **Q59** Inactive contests: SA Sprint and Locust are marked inactive and
  listed last, as you said. Any others? (A contest marked inactive still
  opens and scores an old log; it only moves to the bottom of the list.)
  *Partly answered in F26 (2026-10-15): MARAC, Ten-Ten, FISTS and QCWA are
  inactive; FISTS, QCWA Golden, WWL, XMAS and Locust retire. Any others?*
  **Answer:**

- **Q64** The New Contest drop-down now lists POTA as "Parks on the Air(r)
  Logging" (its friendly name -- every contest class shows its human name,
  your M9a ruling) where it used to say "POTA". Keep that, or should POTA's
  line stay "POTA"?
  **Answer:**

### Added with 7.12 (station facts a contest may override, 2026-10-13)

- **Q66** Preferences shows and edits the station's value. If this contest
  overrides that field (zone 3 in Utah), an edit there changes the station
  but not this contest, and nothing on the page says so. Should the Station
  page show the contest's value beside the field, with a way to clear it?
  *Recommended: yes, a hint that names the contest's value.* This is
  `lcl-ui` work.
  **Answer:**

### Added with the UA4W Championship's and RSGB 1.8's classes (2026-10-14)

- **Q70** The UA4W Championship pays 10/20 on 80/160 m when your CQ zone is
  18 or 19. It now uses a zone you stated first (your 7.12 ruling); the old
  code always used your call's CQ zone. With no zone stated, the two agree.
  A zone typed for this contest is taken as a CQ zone, as MY ZONE's command
  says. *Recommended: confirm.*
  **Answer:**

- **Q71** RSGB 1.8 MHz is a 160 m contest, but its class credits every band,
  as its row always did. Should it credit 160 m only? An off-band QSO would
  then score 0 and earn no multiplier (7.4). Separately, the UA4W
  Championship's New Contest prompt is a fixed English text that no
  catalogue translates. It also differs from the translated
  `TC_ENTERYOURRDAIDORGRID` ("for UA1A stations" against "for Russian
  stations"). Which wording, and should it be translatable?
  *Recommended: 160 m only; use the translated string with your wording.*
  *The band half is now Q98's (every contest states its bands; 7.4, Q44).
  Still open here: the UA4W prompt's wording.*
  **Answer:**

### Added with the Delaware QSO Party's class (2026-10-14)

- **Q73** "A DE mobile that changes county is a new station." TR4W's dupe
  check uses the call, band and mode, and no contest can change that today.
  So a mobile's second county shows as a dupe unless worked as a county
  line. The sponsor's page confirms the rule: "Delaware Mobiles that change
  counties are considered new stations, and can be worked for both
  multiplier and QSO Point credit."
  Add a way for a QSO party to put the county into the dupe check, or
  leave it to the operator? *Recommended: add it, as its own step, for every
  state party with mobiles.*
  **Answer:**

### Added with the IN7QPNE composite (2026-10-14)

- **Q79** Some settings hold one value for the whole session, so IN7QPNE
  keeps its own old values where the parties differ:
  multipliers once per contest (Delaware counts per band); no VHF (7QP and
  Delaware use 6 m and up); DX is one `dx` multiplier (7QP, NEQP and
  Delaware in-state count DXCC entities); no Cabrillo LOCATION required and
  FT8 written `DG` (Delaware: LOCATION required, every digital mode `RY`);
  no power multiplier and no +50 bonus (Delaware has both). Which of these
  should IN7QPNE take? *Recommended: turn VHF on (a QSO still scores only
  where its party allows); keep the rest.*
  **Answer:**

- **Q80** In IN7QPNE every county is its own multiplier for everyone, and an
  in-area entrant also counts states, provinces and one `dx`. The parties'
  own files differ: in 7QP, an in-state entrant's 7th-area counties count
  as their STATE. Making that per party needs a new piece (the contest
  naming the multiplier, Q4). Wanted? *Recommended: yes, when Q4 is done.*
  **Answer:**

### Found while the classes took over the table's values (M10 S5, 2026-10-14)

These were copied into the classes exactly as the old table had them, so
nothing changed. Each looks wrong; none was fixed without your answer.

### Raised by the M11 plan (2026-10-14; `docs/CONTEST_FACTORY_M11_PLAN.md`)

M10 is complete. M11 moves the multiplier and exchange "kind" rules into
the classes. These decide how far it goes. M11's early stages (pins,
dead members, prefix/DX/zone/domestic multipliers) do not wait on them.

*All answered (Q50, Q90-Q96): see section 4.*

---

## 2. Design (recommendation given; "accept" is enough)

- **Q8** Events with no `ContestType` that the code still identifies by name:
  `'TRC'`, `'PGA'`, `'EURASIA'`, `'DL-DX-RTTY'`. Give each a type and class, or
  delete the tests? *Recommended: give a type to any that is still run; delete the
  rest.*
  **Answer:**

- **Q47** Three harmless read-past-the-end shapes were kept exactly: MWC (a call
  longer than ten characters, or ending in `/`), the Region 1 Field Day (no MY
  COUNTRY), and the Region 1 RCC runnings (a one-character call scores 4). Bound
  them the next time each contest is touched? *Recommended: yes* -- no real QSO's
  score moves.
  *Detail added 2026-10-15 (re-read in the code):* each reads text without
  checking its length, copied exactly from the old code. In plain terms:
  1. **MWC** (`uContestMWC.pas:118`) -- the multiplier is a character of the
     worked call: the one before a `/`-letter suffix, else the call's last
     character. The call is copied into a 10-character buffer, then walked to
     its FULL length. A call of 11 or more characters (`PA/W1ABCD/P`) is read
     past the buffer, so the multiplier is a leftover memory byte; a call
     ending in `/` reads one past it; a call starting with `/` reads the
     string's length byte. **"Harmless" above is wrong here**: long portable
     calls are legal, so a real QSO can get a garbage multiplier -- rarely.
  2. **Region 1 Field Day** (`uContestRegion1FieldDay.pas:266`) -- doubles
     points on 160 and 10 m when MY COUNTRY starts with `G`, reading its
     first character unchecked. With no MY COUNTRY it reads a leftover byte
     (almost never `G`, so in practice no doubling). Only a station with no
     country configured is affected.
  3. **Region 1 Field Day RCC CW/SSB** (`uContestRegion1FieldDayRCCCW.pas:141`,
     the same in SSB) -- a `/P` or `/M` station scores 4, tested as "the
     position of `/P` = the call's length minus 1". For a one-character call,
     "not found" (0) equals 1 - 1, so it scores 4. Not a memory read, a wrong
     comparison, and unreachable with a real call: entry refuses
     one-character calls.
  *Revised recommendation: fix all three NOW, one small commit* -- MWC can
  touch a real QSO, each is a line or two, and Q37's ruling points the same
  way (bad input is refused or bounded, never read out of memory). MWC walks
  the whole call and never reads outside it; an empty MY COUNTRY is simply
  not `G`; RCC scores 4 only when `/P` or `/M` is actually present. The
  contest matrix confirms no frozen QSO moves before the commit.
  **Answer:**

- **Q51** An off-band QSO no longer marks the dupe sheet at all (M8), so the
  30 m dupe sheet and the Stations window's `+` do not show it -- consistent
  with "not a dupe", but they are also "have I worked him there" displays.
  Keep it so, or keep a worked-there mark that is not a dupe? *Recommended:
  keep it so* -- one rule.
  *Reworded 2026-10-15 (NY4I: "ambiguous as every contest states bands"):*
  every contest has bands; what was meant is that the OFF-BAND rule fires only
  for a class that overrides `TContestBase.UsesBand`, and measured today only
  **Idaho and Delaware** do. Every other class inherits the base's answer --
  every band is credited -- so this question only affects those two today.
  Q98 asks about the other contests.
  *NY4I, 2026-10-15, on the sentence above: "As most contests are specifically
  not WARC bands, and most HF do not allow 6m and up, HF only would be the
  default. But I would feel better if contest classes just explicitly listed
  the bands they allow."* Recorded on Q98 as its build rule. What stays open
  here is only the display question: does an off-band QSO -- now an automatic
  X-QSO (Q98) -- show as worked-there on the dupe sheet and in the Stations
  window?
  **Answer:**

---

### Added after M9a

---

## 3. Awaiting only your yes

Each carries a **Proposed answer** with its source. "Yes" (or "yes to all")
closes it; anything else reopens it.

- **Q49** BC QSO Party: "a DX station earns no multiplier" tests the
  multiplier for lower-case `dx`, but the in-province file maps `dx=DX`
  (`target/dom/ve7.dom` line 2), so the multiplier is always upper-case `DX`
  and the rule never fires -- an in-province station gets a `DX` domestic
  multiplier. New York and Indiana test `DX` and do fire. Should BC's be
  `DX` like theirs? (A scoring change for in-province BC logs with DX QSOs.)
  **Proposed answer:** SETTLED BY Q84 ("ignore case", 2026-10-15): BC's rule
  tests `dx`, its file maps to `DX`; compared ignoring case, the rule fires,
  so an in-province BC station's DX contact earns no domestic multiplier -- as
  New York and Indiana already do. A scoring change for in-province BC logs
  with DX QSOs.
  **Answer:**

- **Q67** The New Contest dialog's rows start empty, and every row has to be
  filled before OK is enabled. So every contest that asks for MY ZONE
  states a zone override, even when you type your station's own zone. That
  contest then ignores a later Preferences change to the zone. Should the
  rows start with your station's values (read from the file, because the
  dialog runs before the settings load)? And should a row you leave
  unchanged count as "use the station's value" rather than as an override?
  *Recommended: yes to both.*
  **Proposed answer:** SETTLED BY Q65 + Q74 + "a contest is its SQLite file"
  (2026-10-15): the rows start with the station's values (the seed), and
  whatever a row holds at OK -- changed or not -- is the CONTEST's value,
  stored in its database. So yes to seeding; and an unchanged row is NOT "use
  the station's value" but the contest's own copy -- a later Preferences
  change does not reach an existing contest, which is what makes the database
  self-contained.
  **Answer:**

- **Q34** Idaho rovers earn the dormant-county bonus per county they activate, but
  no QSO records the county it was sent from. Add a per-QSO "my county" (log
  field, entry, ADIF `MY_CNTY`), or keep scoring a rover as a fixed station in its
  MY STATE county?
  **Proposed answer:** SETTLED BY the Q13 audit (finding C) and the MY_CNTY
  ruling (Q19): yes, a per-QSO "my county". The log already has `my_county`
  (and `my_state`, `my_grid`) per QSO for exactly this and nothing writes
  them; a rover's QSO records the county it was sent from, ADIF exports it as
  `MY_CNTY`, and the dormant-county bonus counts from it.
  **Answer:**

- **Q89** British Columbia QSO Party ADIF export: TR4W writes NO `STATE`
  (and no `CNTY`) for a BCQP QSO, because the old table named BC's area
  `VE7` -- not two letters -- and the export only writes a two-letter
  state. The BC class itself says its host is `BC`, and ADIF's `STATE`
  field does carry Canadian provinces. Should BCQP export `STATE:BC` (and
  the county) like the US parties do? M10 S6 deliberately kept today's
  output; this would change BCQP's ADIF, so it waits for you.
  *Recommended: yes, export BC.*
  **Proposed answer:** SETTLED BY Q19 (2026-10-15): STATE is ADIF's primary
  subdivision, provinces included. So BCQP exports `STATE:BC` and the county
  like the US parties.
  **Answer:**

- **Q61** CATEGORY-POWER is now one value (design 7.6). Four other Cabrillo
  categories have the same two-store shape: ASSISTED, BAND, MODE and OPERATOR
  start from the setting the New Contest dialog wrote, but the summary window
  writes MODE to a copy of its own and the other three nowhere, so a headless
  export reads a stale or empty copy. Make them one value each, the same way
  (no rescore -- no contest scores by them)?
  **Proposed answer:** SETTLED BY "a contest is its SQLite file" and 7.6: each
  of ASSISTED, BAND, MODE and OPERATOR is ONE value, set at New Contest time
  and stored in the contest database, which the summary window edits and a
  headless export reads -- no copies.
  **Answer:**

- **Q54** HamScore's one-QSO Cabrillo line writes Winter Field Day's FM
  contacts as `FM`; the Cabrillo file writes `PH`. Should HamScore ask the
  contest too? *Recommended: yes* -- one rule for both; it changes what
  HamScore receives for WFD FM QSOs.
  **Proposed answer:** SETTLED BY Q52's ruling (the Cabrillo form is the
  contest class's own definition): HamScore's one-QSO Cabrillo line asks the
  contest, as the file does, so WFD FM goes as `PH` in both.
  **Answer:**

- **Q26** WAG: an imported record with no `DOK` keeps its received RST (`599`) as
  the QTH. Should it be empty?
  **Proposed answer:** SETTLED BY Q3 (the log stores only what the operator
  stated) and Q13 (an import keeps the record): an imported WAG record with no
  DOK has an EMPTY QTH -- an RST is not a DOK.
  **Answer:**

- **Q10** May a `ContestType` nobody runs be deleted instead of given a class?
  *Recommended: yes, with the list shown to you first.*
  **Proposed answer (NY4I asked 2026-10-15: "could we have a hybrid to refer
  this ContestType question to a generic class?"):** yes, and the registry
  already does half of it -- ContestIdentity falls back to a plain
  TContestBase for a ContestType with no class (DUMMYCONTEST today), and never
  returns nil. The hybrid: a contest nobody runs keeps its enum member and its
  ContestTypeSA spelling (old logs and .cfg files still open) but its own
  class is DELETED, and it resolves to one named generic class
  (TContestRetired) instead of the bare base. That class names itself by the
  ContestTypeSA spelling, logs and exports ADIF, writes no Cabrillo, is not
  on the New Contest list, and scores one point per QSO with no multipliers.
  The cost, stated plainly: the contest's ADIF CONTEST_ID, Cabrillo name and
  display name lived in its class and go with it (ADIF then omits
  CONTEST_ID); rescoring an old log gives the generic score, not the
  sponsor's; its matrix record is re-frozen once; and its rules survive only
  in git history and the D7 tree. Candidates are listed to you before any
  class is deleted.
  **Answer:**

- **Q88** The NA Sprint CW and RTTY rows name different domestic files:
  CW uses `naqp`, RTTY uses `s49p8`. Both are the same sprint exchange
  (states, provinces, NA). Is one of them wrong, and which file should
  both use?
  **Proposed answer:** From the sponsor (researched 2026-10-14): the sprint
  counts the 50 states, DC and 14 Canadian provinces and territories. `naqp`
  has 12 provinces and `s49p8` has 49 + 8, so **both are wrong**: one
  corrected file, used by both.
  *Check before saying yes (dom cross-check, 2026-10-15):* DXLog's NAQP and
  NA Sprint files count **13** VE multipliers (NL/LB/NF as one; NT, NU, YT
  separate), not 14, and no TR4W file accepts a typed `NT` at all. See
  `docs/DOM_CROSSCHECK_FINDINGS.md`.
  **Answer:**

- **Q95** Croatian counts ITU zones but looks zones up with CQ zones, so it
  exports `<ITUZ:2>05` for W1AW (whose CQ zone is 5; its ITU zone is 8).
  CW Open is the reverse (CQ zones over an ITU lookup). Defects? Which
  system does each sponsor want?
  *Recommended: Croatian ITU throughout; check CW Open's rules.*
  **Proposed answer:** From the sponsors (researched 2026-10-14): Croatian
  (9A) uses **ITU zones** in the exchange and the multipliers, so the CQ
  lookup is the defect. CW Open has **no zones**: serial + name, and the
  multiplier is each call once per session, so TR4W's 40 CQ-zone multipliers
  are a scoring defect.
  **Answer:**

---

## 4. Already answered (for reference)

| Q | Answer | Where it landed |
|---|---|---|
| Q4 | Retire all seven shared-set settings at the endpoint; user-defined contests to be revisited another way | M10 |
| Q6 | POTA becomes a contest class, treated like General QSO | `TContestPOTA`, 2026-10-13 (design 8.2o) |
| Q11 | Delete the QSO-POINT-METHOD-only arms at M10 | M10 |
| Q28 | Station facts default from station config, overridable per contest | design 7.12; LANDED 2026-10-13 (`TMySettings.Resolved*`); UA4W's class 2026-10-14 (design 8.2p) |
| Q33 | RSGB 1.8 gets a read-only new-multiplier answer | design 7.13; its class 2026-10-14 (design 8.2p) |
| -- | IN7QPNE is a composite of IN/7QP/NE/DE; Delaware becomes a contest | design 7.14; Delaware 2026-10-14 (8.2q); the composite `TContestIN7QPNE` 2026-10-14 (8.2r; Q77-Q84) |
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
| Q39 | A contest never writes a station setting | design 7.11 (decided); LANDED at M9a for MY STATE (Q57 is MY ZONE) |
| -- | Out-of-state x out-of-state in a QSO party: refuse with an error | M5b |
| -- | Off-band QSO: logged, 0 points, no mult, no need-mult hint, not a dupe | 1e4f66f9 (points, mults); M8 (dupes, hints) |
| -- | QRP = our power; last touch point wins; may change mid-contest with a reminder | Idaho, design 7.6; LANDED at M9b (the summary writes the one setting, a change with QSOs rescores and shows a notice) |
| -- | The New Contest drop-down shows the display name | M9b (Q52 still asks which words) |
| -- | Inactive contests go at the bottom of the drop-down (SA Sprint, Locust) | M9b (`IsActive`; Q59 asks for others) |
| -- | ALL ASIAN SSB is `ALL-ASIAN-DX-PHONE` | e1c6f873 |
| -- | RSGB RoPoCo: an ADIF record is the SSB running's when its mode is phone (one ADIF id, `RSGB-ROLO`) | M7b batch 2 (decided under delegation, design 8.2k) |
| Q18 | JW-FD: CW 5 / phone 3 everywhere, Oceania only; own branch not a multiplier | F26 build list (C) |
| Q50 | A Russian call's oblast: `RussianID` of the country, one helper | M11, 2026-10-15 |
| Q60 | Off time 60 for CQ WW (CW, SSB, RTTY), 30 elsewhere incl. IARU HF | `a7e8fe41` |
| Q87 | IN7QPNE prompt names the four areas | `ed4ad807` |
| Q90 | A slash suffix is a county rover only in a state QSO party | `bb07fd06` |
| Q91 | Delete `logddx.pas` and `logmenu.pas` | `32bcadb9` |
| Q92 | Option 2: shapes become named helpers each class calls | M11 S9 |
| Q93 | Moot under Q92 | -- |
| Q94 | Answered by Q90 | `bb07fd06` |
| Q96 | CQ WW CW fills the zone, like SSB and RTTY | `c9caaa08` |
| Q46 | Ten-Ten: 2 points with a 10-10 number, 1 without | F26 build list C11 (not built) |
| Q56 | A contest's sent state stands for the whole session | design 8.2m (already built) |
| Q75 | Delaware: WA7BNM id 240; the log address from the sponsor's page | not built |
| Q81 | NEQP: state-first abbreviations and CT planning regions; `neqso.dom` to be brought into line | not built |
| Q7 | Base + CW/SSB children only where the pair is one rule today | design rule; Q43 lists the pairs |
| Q9 | An edited CQ memory survives re-selecting the contest | not built |
| Q37 | A malformed grid is refused at entry (and import); the read made safe | not built |
| Q13 | A logged QSO is scored from its record, never from live state (radio mode, operator) | rule; audit found A1-A3, B, C, E1-E2 (not fixed) |
| Q44 | RTC, CQMM, WRTC state their bands; off-band/off-mode QSOs score 0, are not in HamScore's QSO counts, but advance the serial | not built |
| FD-DX | `DX` from a W (or other sectioned) station is refused; a DX station is still `1D DX` | not built |
| Q30 | Winter FD: `MX` is a section (Cabrillo, SRX_STRING, ARRL_SECT), as D7 does | already so; no change |
| Q31 | `Missing precedence (Q A B U M S)` is acceptable wording | already so |
| Q38 | Winter FD has no DXCC multiplier (D7 tracked one but never scored it) | not built |
| Q32 | Missouri peak-hour bonus is real; computed from each QSO's logged time over the whole log, cap 250 | not built |
| Q29 | Out-of-state works only the host state: true for QSO parties in general | already so |
| Idaho-DC | DC is not a state, so not an Idaho multiplier | already so |
| Idaho-cfg | No `.cfg` in `target/dom` -- the Idaho and Delaware templates deleted | done 2026-10-15 |
| Q17 | Moot: Locust is retired | -- |
| Q36 | Moot: Locust is retired | -- |
| Q24 | FOC reads N1MM's APP_N1MM_EXCHANGE1 only when the record's CONTEST_ID is FOC's | not built; needs N1MM's id spelling |
| Q65 | MY CALL is a station fact a contest may override; the contest's call lives in its database | not built (own stage) |
| Q74 | Cabrillo LOCATION is seeded from the station at New Contest time and stored in the contest | not built |
| Q68 | On reopen, the station-fact rows are applied before the contest row | not built |
| Q76 | ADIF `STATE` is the worked station's state, `MY_STATE` ours -- fix the host-state export | not built |
| Q82 | IN7QPNE county-line count left as is; future fix | issue #85 |
| Q84 | A party's DX-multiplier test ignores case (files unchanged) | not built |
| Q77 | IN7QPNE per-party score: deferred | issue #86 |
| Q78 | IN7QPNE cross-party scoring view: deferred with Q77 | issue #86 |
| Q98 | Every contest states its bands and modes; an off-band/off-mode QSO is logged, scores nothing, and is an automatic X-QSO in the log and the export (flag OR off-band) | not built |
| Q41 | ARRL VHF runnings named ARRL-VHF-JAN/JUN/SEP; all three get June's set-up | not built |
| Q62 | POTA: the worked station's DXCC from its callsign; our MY_DXCC and MY_STATE from our park | not built |
| Q57 | CQ WW RTTY messages built without writing MY ZONE | done with 7.12 |
| Q63 | "Activator" stays untranslated -- a universal POTA term | no change |
| Q72 | Delaware: 160-10 m without WARC plus 6 m and up through light ("DC to daylight") | already so; no change |
| Q85 | 7QP excludes WARC (and the sponsor scores digital 4) | not built |
| Q86 | Minnesota is the only HamScore QSO party; its flag is right | no change |
| Q83 | Online-score posting and HamScore are separate permissions; WRTC online yes / HamScore no; IN7QPNE neither | not built |
| Q69 | MY ZONE is the CQ zone; ITU-zone contests read MY ITU ZONE | not built (own step) |

### Answered since the table was last updated (full text)

- **Q69** MY ZONE, when nobody states it, is worked out from your call in
  the contest's own zone system. Most contests use ITU zones, so there it
  is the ITU zone: K0AAA gets 7, not CQ zone 4, in the UA4W Championship.
  7.12 calls MY ZONE your CQ zone, and IARU relies on the ITU answer. Should
  MY ZONE always be the CQ zone, with ITU-zone contests reading MY ITU ZONE?
  That would change IARU's set-up and messages when no zone is stated, so it
  would be its own step. *Recommended: yes, separately.* Until then the UA4W
  class asks a separate service for your CQ zone (design 8.2p).
  **Answer:** (NY4I, 2026-10-15) *"actually most contests when they mention
  zone mean cq zone and not itu zone."* This also corrects the question's
  premise ("most contests use ITU zones" was wrong). YES: MY ZONE is the CQ
  zone, everywhere it is not stated otherwise; the few ITU-zone contests (IARU
  HF, Croatian per Q95, and any other whose sponsor says ITU) read a separate
  MY ITU ZONE. Its own step: it changes IARU's set-up and messages when no
  zone is stated. Then the UA4W class's separate CQ-zone service (design 8.2p)
  can go. Not built.

- **Q83** HamScore now asks the contest whether its score may be posted.
  Until now only the post-scores window asked, so WRTC (no live score
  posting) still went to HamScore when HAMSCORE ENABLE was on. With this
  change neither WRTC nor IN7QPNE is posted. Is that right for WRTC?
  *Recommended: yes.*
  **Answer:** (NY4I, 2026-10-15) *"Correct. It is a very limited subset of
  contests that allow the RTC data to go to hamscore. The contestOnline scores
  is a different thing but the combined in7qpne would not be sent online since
  it is combined. WRTC could be for local competitors using TR4W."* Asked
  which for WRTC: **online scores yes, HamScore no.** So the two are SEPARATE
  permissions, where today one flag (`oaScorePosting`, read by `ContestPermitsScorePosting`) gates both: (1) the online
  scoreboard (post-scores window) -- IN7QPNE no, WRTC YES; (2) HamScore -- a
  very limited subset (RTC-capable, e.g. Minnesota); IN7QPNE and WRTC no. Not
  built. Q55 is live again (WRTC's posted XML carries no multiplier).

- **Q86** The Minnesota QSO Party is the only state party whose table row
  marks it "RTC capable" (live score posting through the RTC uploader).
  No other party has it. Intended, or a typo in the row?
  *Recommended: remove it unless Minnesota is posted to a scoreboard.*
  **Proposed answer:** From HamScore (researched 2026-10-14): the Minnesota
  QSO Party IS on its real-time scoreboard, so the flag is correct. No change.
  **Answer:** (NY4I, 2026-10-15) *"MNQP is indeed the only hamscore qso party
  of which I am aware."* The flag is correct: Minnesota keeps live score
  posting, and no other party gets it. No change.

- **Q85** Does 7QP allow the WARC bands? The 7QP class scores a 30 m CW QSO
  at 3 points (frozen matrix, `SEVENQP.matrix` QSO 09), and IN7QPNE now
  inherits that for every 7QP-judged QSO. Delaware excludes WARC by its
  sponsor's rules; nothing in TR4W says whether 7QP does. If it does not,
  the 7QP class should declare its bands the way Delaware's does, and
  WARC QSOs then score 0 (logged, never refused).
  *Recommended: check the 7QP rules page and tell me which bands.*
  **Proposed answer:** From the 7QP sponsor (researched 2026-10-14): 7QP
  **excludes WARC**, so the 7QP class declares its bands and WARC QSOs score
  0. The same page scores SSB 2 / CW 3 / **digital 4**; TR4W gives digital 2
  -- a second defect, fixed in the same commit.
  **Answer:** (NY4I, 2026-10-15) *"7qp does not allow WARC."* So the 7QP class
  states its bands (160-10 m without WARC, like Delaware) and a WARC QSO
  scores 0 and, under Q98, is an automatic X-QSO; IN7QPNE inherits it for 7QP-
  judged QSOs. The digital-4-points item in the proposal comes from the 7QP
  sponsor's page (rule-source order) and is kept as a fix in the same commit
  unless NY4I says otherwise. Not built.

- **Q72** Delaware's bands: "all HF bands except WARC, plus 6 m and up".
  The class counts 160 m and light as well as 80-10 m (no WARC) and 6 m up.
  Both are my reading of the summary, not of the sponsor's page. Are they
  in? A QSO on a band that is out scores 0 and earns no multiplier.
  *Checked against the sponsor's 2024 page (2026-10-14):* it says "All HF
  bands excluding WARC bands" and "6 meters and up", so **light is in**.
  160 m is not named either way, and the page's suggested frequencies do
  not list it. 1.8 MHz is strictly MF, not HF. So only 160 m is open.
  *Recommended: keep 160 m in unless you know the sponsor excludes it.*
  **Proposed answer:** From the sponsor's page (researched 2026-10-14): its
  suggested frequencies include 1860 kHz, so 160 m is in -- what the class
  already does. Light is in too. No change.
  **Answer:** (NY4I, 2026-10-15) First *"Light is in too" is not correct. Just
  HF bands* (160-10 m, no WARC). Then, shown the 2024 rules page
  (https://www.fsarc.org/qsoparty/rules-2024.html: *"DEQP also allows contacts
  on any band and mode 6 meters and up to include repeater contacts within
  Delaware"*): *"oh....I did not see that line. Then it is DC to Daylight..."*
  FINAL: 160-10 m without WARC, plus 6 m and up THROUGH LIGHT -- exactly what
  TContestDelawareQP.UsesBand already states. No change.
  NY4I: *"DC to daylight means all of the amateur radio spectrum including HF
  (but no WARC)."* Measured: the class states every band TR4W has except 30, 17
  and 12 m. TR4W has no 2200 m, 630 m or 60 m band (60 m is commented out of
  BandType) and nothing above 24 GHz but light, so those cannot be logged at all.

- **Q63** The New Contest dialog captions POTA's box "Activator" as plain
  English text, so no translation can reach it. Moved as it was. Give it a
  translatable string?
  **Proposed answer:** SETTLED BY the i18n rule (CLAUDE.md: a caption typed as
  plain English reaches no catalogue): "Activator" becomes a translatable
  string.
  **Answer:** (NY4I, 2026-10-15) *"activator is a universal term at least
  until I find a pota translation that tells me otherwise."* NO: "Activator"
  stays as it is, untranslated -- the proposal is withdrawn. Revisit only if a
  POTA translation shows a different word.

- **Q57** CQ WW RTTY's messages. A W/VE station sends RST, zone AND state
  (`599 05 FL`). D7 built those messages by briefly OVERWRITING MY ZONE with
  the zone, a space and MY STATE -- `05 FL` -- building the CQ, F3, F4, F5 and
  S&P messages from it, then restoring the zone (D7 `FCONTEST.PAS:181-199`).
  Since 7.12 a write to MY ZONE marks it as this contest's own value, so even
  that brief write would stop MY ZONE following MY CALL. Build the messages
  without touching MY ZONE?
  *Reworded 2026-10-15 -- NY4I asked what "zone state" meant: it was shorthand
  for that `05 FL` text, not a field. MY ZONE and MY STATE are the two
  fields.*
  **Already implemented with 7.12 (2026-10-13), by necessity:** the messages
  are built in a local (`WriteRSTZone(SendsStateAfterZone)`); MY ZONE and MY
  STATE are never written, and the messages are the same text D7 produced.
  **Proposed answer:** confirm -- no further change.
  **Answer:** (NY4I, 2026-10-15) *Yes* -- confirmed; already built with 7.12.

- **Q62** POTA ADIF export: WHOSE DXCC. We are the activator, in our park; our
  park goes out as `MY_SIG_INFO` / `MY_POTA_REF` and is right. The defect is
  about the OTHER station: a hunter at home who sends us a Canadian province
  (`ON`) is exported with `DXCC:291` -- the USA -- and `STATE:ON`, because the
  export writes 291 for anything that looks like a state, and that list
  includes the provinces (`uContestPOTA.pas:329`). (A hunter who sends a park,
  park-to-park, gets no DXCC written at all.)
  *Reworded 2026-10-15 -- NY4I read the 291 as OUR station: "why would a pota
  hunter operating in canada be considered a US station? When they setup and
  select their park, it would indicate VE-0001 and we should see they are in
  canada."* It is the worked station's DXCC, not ours. His point adds a second
  item: OUR `MY_DXCC` (and `MY_STATE`) could come from our park reference
  (`VE-0001` is Canada) -- today neither is written.
  **Proposed answer:** the worked station's DXCC comes from its CALLSIGN's
  country (VE3ABC -> 1, Canada), as in every other contest, never from the
  shape of what it sent; `STATE` stays what the hunter sent. Separately, write
  our `MY_DXCC` and `MY_STATE` from our park reference.
  **Answer:** (NY4I, 2026-10-15) *Yes* -- both halves. Not built.

- **Q41** ARRL VHF: September is set up with the contest name `'VHF QSO JUNE'`
  (the old code named both runnings), and January has never had any setup at
  all -- no 6 m start, HF bands left on. Intended?
  **Proposed answer (checked 2026-10-15 against ARRL's public logs,
  tools/public-logs/fetch_arrl_public_logs.py):** the Cabrillo `CONTEST:`
  lines are already right -- the 2026 January and June and 2025 September logs
  say `ARRL-VHF-JAN`, `ARRL-VHF-JUN` and `ARRL-VHF-SEP`, which the three
  classes write. The defect is the set-up: September's `'VHF QSO JUNE'` is not
  cosmetic, it heads the summary sheet (`postunit.pas:992-993`: "VHF QSO JUNE
  SUMMARY SHEET", "CONTEST: VHF QSO JUNE"); and January has none. Every
  January public log sampled starts on 6 m. So: all three runnings get June's
  set-up (start on 6 m, HF bands off), each with its own name -- `VHF QSO
  JANUARY`, `VHF QSO JUNE`, `VHF QSO SEPTEMBER`.
  **Answer:** (NY4I, 2026-10-15) *"each one gets its own name so ARRL-VHF-JUN,
  ARRL-VHF-SEP, etc."* So the session's contest name -- what heads the summary
  sheet -- is `ARRL-VHF-JAN`, `ARRL-VHF-JUN` and `ARRL-VHF-SEP`, the same
  spelling as each running's Cabrillo name (not the `VHF QSO ...` names
  proposed). All three get June's set-up (start on 6 m, HF bands off); January
  gains one. Not built.

- **Q98** (raised by Q51's wording, 2026-10-15) Off-band crediting is
  enforced for 2 of 186 contests. `UsesBand` (and, for Q44's RTC, a mode
  equivalent that does not exist yet) is overridden only by Idaho and
  Delaware; every other class credits every band, so a 30 m QSO in CQ WW
  or an FT8 QSO in a CW-only contest scores like any other. Your 7.4 ruling
  says the off-band rule "applies to basically any contest". Sweep every
  class to state the bands (and modes) its sponsor allows, one family per
  commit, with each changed matrix record re-frozen? *Recommended: yes* --
  bands from the same sources as F26 (Cabrillo spec, WA7BNM, DXLog's
  definition files), Q44's three first, and any contest whose sponsor
  page is silent left as every band and listed to you.
  **Answer:** (NY4I, 2026-10-15, as a scenario) *"I am working in the CQ WW
  SSB contest ... I see a DX station country I need on 17 meters (not a
  contest band). I do not want to open up my regular logger (DXKeeper) just to
  work this station. So I enter the DX callsign in TR4W. I work him and move
  on back to the contest. When I import the contest ADIF file to DXKeeper, I
  will get this 17m DX station. But since it is off-band, it should be marked
  X-QSO so I do not send it to the sponsor for credit. It should not be in my
  score totals or any of the other places if it were not an X-QSO."* So YES to
  the sweep -- every contest states its bands (and modes) -- and it adds the
  EXPORT half 7.4 did not have:
  - An off-band or off-mode QSO is logged normally and kept in the ADIF, so
    DXKeeper still gets it.
  - It scores 0, earns no multiplier, is not a dupe, is left out of the score
    totals and HamScore's counts (Q44), and is not a need-multiplier hint.
  - On EXPORT it is an X-QSO: the Cabrillo line is `X-QSO:`, and the ADIF
    carries `APP_TR4W_CLAIMEDQSO` `0`, the marker an X-QSO already gets.
  - **AUTOMATIC X-QSO -- 7.4 REVERSED (NY4I, 2026-10-15: "I thought about it
    and automatic X-QSO is OK.")** 7.4 had said an off-band QSO is "not an
    automatic X-QSO (that would be confusing to an op)". Now it IS one, and
    the log shows it as one too. Built as: a QSO is an X-QSO when the operator
    flagged it OR the contest's band/mode rule says it is off-band -- worked
    out, not written into the record, so a corrected band list re-classifies
    old QSOs on the next rescore with no data change (Q13: the record is the
    event).
  - Today none of this happens for 184 of 186 contests (no `UsesBand`), and
    even for Idaho and Delaware the export writes a plain `QSO:` line -- the
    `X-QSO:` prefix reads only the stored flag (`postunit.pas:3166`).
  Not built.
  **BUILD RULE (NY4I, 2026-10-15): every contest class LISTS ITS BANDS
  EXPLICITLY -- no inherited default.** Not even "HF without WARC", though
  that is what most contests are: a default is a guess for every class that
  forgets to override it. TContestBase.UsesBand stops answering True for every
  band, and a pin test over every registered contest fails if a class states
  no band list -- the way uTestCWFraming fails a radio that keys CW without a
  frame rule.
- **Q77** IN7QPNE's score. You said a combined score is not needed, and it
  would be nice to see the score of the party just worked. Nothing on screen
  can show more than one score today, so the window, the summary sheet and
  the Cabrillo `CLAIMED-SCORE` show points x multipliers over the whole
  combined log -- a number that is no sponsor's score. Should TR4W get a way
  to show one score per party, or should the Cabrillo claim nothing?
  *Recommended: a per-party score, as its own step; until then leave it.*
  **Answer:** (NY4I, 2026-10-15, on Q78; it covers Q77 too) *"defer how to
  display the score in each contest for in7qpne. I am undecided if it is
  important or how we would display this short of a tooltip over score with
  the breakdown or a new scoring window."* DEFERRED, both: TR4W keeps today's
  combined score and the worked party's view. Tracked as issue #86
  (https://github.com/TR4W/TR4W-D12/issues/86).

- **Q78** An Indiana, 7QP, NE or DE entrant who works a station in ANOTHER of
  the four parties: TR4W scores it by the worked party's rules only, as you
  ruled. The entrant's own sponsor may count it too (an Indiana station
  working Arizona earns an Arizona multiplier in the Indiana QSO Party).
  Each sponsor scores the shared log itself, so their results are not
  affected; only TR4W's points show one party's view. Is that right?
  **Answer:** (NY4I, 2026-10-15, on Q78; it covers Q77 too) *"defer how to
  display the score in each contest for in7qpne. I am undecided if it is
  important or how we would display this short of a tooltip over score with
  the breakdown or a new scoring window."* DEFERRED, both: TR4W keeps today's
  combined score and the worked party's view. Tracked as issue #86
  (https://github.com/TR4W/TR4W-D12/issues/86).

- **Q84** Indiana's rule is "a DX station is not a multiplier", and it looks
  for `DX` in capitals. Indiana's own file says `DX = DX`, but IN7QPNE's
  file says `dx = dx`, so in IN7QPNE an Indiana entrant's DX contact still
  earns the one `dx` multiplier. Change IN7QPNE's file to `DX`, or make the
  rule ignore case? *Recommended: change the file.*
  **Answer:** (NY4I, 2026-10-15) *"ignore case."* The RULE ignores case, not
  the file: a `DX` multiplier test matches `dx`, `Dx` and `DX` alike, so
  IN7QPNE's `dx = dx` stays and an Indiana entrant's DX contact earns no
  multiplier there. One rule for every party that tests for DX (Indiana, New
  York, BC -- see Q49). Not built.

- **Q82** County lines in IN7QPNE: Indiana and Delaware allow two counties,
  7QP four. TR4W checks the COUNT before it knows the counties, so IN7QPNE
  allows any number, as it always did. Teach the check which party the
  counties are in, or leave it? *Recommended: leave it until a line between
  two parties is real.*
  **Answer:** (NY4I, 2026-10-15) *"leave it but note it as a future item to
  fix (an issue is fine too for these future items)."* Left as it is; tracked
  as issue #85 (https://github.com/TR4W/TR4W-D12/issues/85). From now on, a
  "future item" answer gets an issue, linked here.

- **Q76** **A DEFECT IN TODAY'S EXPORT:** in every single-state party, an
  in-state station's ADIF labels every QSO with the HOST state -- a DE
  station working a PA station exports `STATE:DE` beside `QTH:PA`, which
  puts our state in the worked station's field.
  **Answer:** (NY4I, 2026-10-15) *"ADIF typically prefaces the local station
  fields with MY_ (as in MY_STATE). So if you write STATE in ADIF, that is the
  state of the worked station."* So `STATE` is always the WORKED station's
  state and our own goes in `MY_STATE`: a DE station working PA exports
  `STATE:PA` and `MY_STATE:DE`; working a Kent County station exports
  `STATE:DE` because HE is in DE. The rule for every `MY_` field is the same
  (`MY_CNTY`, `MY_GRIDSQUARE`, ...). Not built; it changes the ADIF of every
  in-state party log.

- **Q68** Reopening a log with no `.cfg` sets up the contest before the
  log's own rows are applied. The in-state test and the exchange messages
  are built then, so they use the station's state and zone rather than this
  contest's override. Before 7.12 this was the same, with the contest's
  value written into the station after set-up. MY CALL is already applied
  first for the same reason. Should the station-fact rows be applied first
  too? *Recommended: yes.* That would change set-up on reopen for a log
  whose override differs from the station.
  *Reworded 2026-10-15.* NY4I read this as moot ("we have an external program
  to convert cfg files. We should not have cfg files for contests going
  forward"). It is the opposite: "with no `.cfg`" is the ONLY reopen path from
  now on, because the contest database is the only source. On reopen, contest
  set-up (`FoundContest`) runs when the stored contest row is applied
  (`uSettingsEffects.pas:354`), and builds the in-state test and the exchange
  messages then -- before a MY STATE or MY ZONE override row is applied. So
  every reopened log whose contest overrides the station's state or zone sets
  up with the STATION's values until something re-runs set-up. The question is
  only the order: apply the station-fact rows (and, with Q65, MY CALL) before
  the contest row? *Recommended: yes.*
  **Answer:** (NY4I, 2026-10-15) *Yes.* On reopen, the station-fact rows (MY
  STATE, MY ZONE, LOCATION and, with Q65, MY CALL) are applied BEFORE the
  contest row, so set-up builds the in-state test and the messages from the
  contest's own values. Not built.

- **Q74** Delaware's Cabrillo header must have `ARRL-SECTION:` or
  `LOCATION:` (DE, your state or section, or DX). TR4W now refuses to write
  the file without a LOCATION, and you type it. Should TR4W fill it in from
  where you are? *Recommended: yes -- DE in state, else your state, else DX.*
  **Answer:** (NY4I, 2026-10-15) *"arrl section for LOCATION is set at new
  contest definition time as with the other values seeded from MY STATION."*
  So LOCATION is a station fact seeded into the New Contest dialog (from the
  station's section or state, as Q65/7.12 seed MY CALL, MY STATE and MY ZONE),
  and what the dialog holds at OK is the contest's value, stored in its
  database. The Cabrillo writer reads it from there. Not built.

- **Q65** MY CALL has the problem 7.12 just fixed for MY STATE and MY ZONE.
  When a contest is run under a club call (W4TA), the call is written into
  the station's MY CALL. The next settings save in the session, such as a
  Preferences edit, writes W4TA into `tr4w.json` as the station's own call.
  It was left out on purpose: about 120 places read MY CALL, and your
  country, continent and zone are derived from it. Should MY CALL become an
  overridable station fact too, as its own step? MY COUNTRY would then be
  derived from the call this contest uses. *Recommended: yes, separately.*
  **Answer:** (NY4I, 2026-10-15) *"conceptually there is my station call and
  the call I want to use as the contest. Just like in the case where I go to a
  different state from FL (which is in my station state), we can use these as
  the seed in a new contest definition/selection, but if I enter W4TA, then
  that goes into the contest database file."* YES, as its own step: MY CALL
  becomes a station fact a contest may override, exactly as 7.12 did for MY
  STATE and MY ZONE. The station's call (`tr4w.json`) seeds the New Contest
  dialog; a call typed there is the CONTEST's and is stored in that contest's
  database, never written back to the station. MY COUNTRY, continent and zone
  derive from the call the contest uses. Not built; about 120 readers of MY
  CALL to route through the resolver, so it is planned as its own stage.

- **Q24** FOC Marathon now reads N1MM's `APP_N1MM_EXCHANGE1` as the membership
  number when the record has no `FOC_NUM` (what the old code intended but never
  did). Confirm.
  **Answer:** (NY4I, 2026-10-15) *"Yes if we can get the import from N1MM
  (only when the cabrillo contest ID is ok, that is fine to use)."* So
  `APP_N1MM_EXCHANGE1` is read as the membership number only when the record's
  own `CONTEST_ID` names the FOC Marathon. **Not so today:**
  `TContestFOCMarathon.ApplyADIFImport` also runs for a record with NO
  `CONTEST_ID` imported into an FOC log, and uses the tag there too. **And the
  id must be matchable:** `FindContestByADIFContestId` takes an exact id or a
  listed former id; FOC's is `FOC MARATHON` (space), DXLog's
  `FOC_MARATHON.TXT` writes `FOC-MARATHON` (hyphen), and N1MM's spelling is
  not yet known. To build: gate the tag on the record's CONTEST_ID, and add
  N1MM's spelling to FOC's accepted ids -- **NY4I: what CONTEST_ID does N1MM
  write for the FOC Marathon? A sample N1MM ADIF settles it.**

- **Q17** Locust (inactive): the calendar says CW only, 80 and 40 m, no
  multipliers. TR4W scores every band and mode and counts domestic multipliers.
  State its bands and drop the multipliers, or leave an inactive contest as it was?
  **Answer:** (NY4I, 2026-10-15) *"Q17 and Q36 are retired so not needed."*
  MOOT: Locust is RETIRED, joining FISTS, QCWA Golden, WWL and XMAS (F26).
  Retired = off the New Contest list; its enum member and `ContestTypeSA`
  spelling stay so old logs open (Q10 asks whether its class goes to a generic
  one). Its bands, multipliers and K6VVA bonus stay as they are.

- **Q36** Locust: 5000 points per QSO with K6VVA or name LOCUST, multiplied like
  any QSO point. Is that the rule, or a one-time bonus after multiplication?
  **Answer:** (NY4I, 2026-10-15) *"Q17 and Q36 are retired so not needed."*
  MOOT: Locust is RETIRED, joining FISTS, QCWA Golden, WWL and XMAS (F26).
  Retired = off the New Contest list; its enum member and `ContestTypeSA`
  spelling stay so old logs open (Q10 asks whether its class goes to a generic
  one). Its bands, multipliers and K6VVA bonus stay as they are.

- **Idaho-cfg** The template `target/dom/Idaho QSO Party.cfg` has never shipped in
  the installer. Ship it, or delete it now that the New Contest dialog creates the
  contest?
  **Answer:** (NY4I, 2026-10-15) *"Why would we ship any .cfg files in the dom
  folder? Those are only DOM files."* Neither: DELETED, with `Delaware QSO
  Party.cfg`, the same kind of template added at 8.2q. Nothing read either
  (the installer lists its `dom` files by name and names no `.cfg`); a new contest
  is its SQLite file alone -- the New Contest dialog writes no `.cfg` (since
  `66ac1ebe`); a `.cfg` is only read, to import an old or external contest.

- **Idaho-DC** Idaho's in-state multipliers include the states and provinces but
  not DC; the sponsor says "each US state". Should DC count?
  **Answer:** (NY4I, 2026-10-15) *"DC is not a state."* DC does not count as
  an Idaho multiplier -- what TR4W does today. No change.

- **Q29** "Out-of-state stations work only the host state" is now the default for
  every state party. I could confirm it from the sponsor for NC, CA, WA, BC, AZ,
  FL and ID. Not checked: Michigan, Minnesota, Missouri, Texas, Ohio,
  Pennsylvania, New York, Virginia, Wisconsin, Tennessee, Colorado, Indiana.
  Does any of them let out-of-state stations work each other?
  **Answer:** (NY4I, 2026-10-15) *"That is true for qso parties in general."*
  The default on the state-QSO-party base stands for every party, the twelve
  unchecked ones included; a party whose sponsor says otherwise overrides it,
  as any contest rule does. Already so; no change.

- **Q32** Missouri: a "peak-hour" bonus (+1 per 80/40 m QSO logged 1400-1959 UTC,
  up to 250) is counted in live entry only and lost when the log is reopened.
  WA7BNM's rule summary has no such bonus (only W0MA and K0GQ +100 each, and +100
  for an electronic log). Real rule? If yes it is computed from the whole log; if
  no it is deleted.
  **Answer:** (NY4I, 2026-10-15) *"The wall clock logged into the log record
  determines this."* **The bonus is real** -- the sponsor's 2026 rules
  (https://www.w0ma.org/mo_qso_party/results/thisyear/moqp-2026-rules-
  final.pdf, Points, rule 7): *"Any valid contacts made between the hours of
  1400 UTC Saturday to 2000 UTC Saturday and 1400 UTC Sunday to 2000 UTC
  Sunday on the 40 and 80 meter bands will count as an additional point each.
  Up to 250-point bonus can be added to the total score."* WA7BNM's summary
  omitted it. So it is computed over the WHOLE LOG from each QSO's own logged
  time and band (Q13: never the clock now), counting valid QSOs only (no dupe,
  no 0-point off-band QSO), capped at 250 -- and it survives reopening the
  log. The same page confirms the W0MA and K0GQ +100 each (rules 4-5); the
  +100 for an electronic Cabrillo log (rule 6) is the sponsor's to award. Not
  built: today the tally is counted at live entry only and is lost on reopen.

- **Q38** Winter Field Day's score is points x band-modes x power factor, with no
  DX multiplier, yet its session counts DXCC multipliers
  (`ARRLDXCCWithNoARRLSections`). Like Field Day (no multipliers at all), should it
  be none? Only the remaining-multiplier display would change.
  **Answer:** (NY4I, 2026-10-15) *"Winter FD does not count DXCC multipliers
  or at least it did not in D7."* So: none, like Field Day. **For the record,
  D7 did TRACK them** -- `FCONTEST.PAS:414` sets `ActiveDXMult :=
  ARRLDXCCWithNoARRLSections` for Winter Field Day, so the multiplier sheet
  and the remaining-multiplier window counted DXCC countries -- but never
  SCORED them: the score is points x band-modes x power factor (the summary
  report's Winter FD case, `PostUnit.PAS:871`). The ruling removes the
  tracking too. Not built: `TContestWinterFieldDay.HasDXMultiplier` becomes
  False; only the multiplier displays change, no score moves.

- **Q30** Winter Field Day accepts `MX` as a QTH. It still exports as `ARRL_SECT`
  and imports as a section. Is `MX` "DX" under the "DX is never a section" rule?
  **Answer:** (NY4I, 2026-10-15) *"The section is MX in cabrillo and
  srx_string. The current D7 implementation of winter fd is the right guide."*
  So `MX` is a section, not DX. Checked against D7: entry accepts `MX`
  (`LOGSTUFF.PAS:1364`), ADIF writes `ARRL_SECT` and `CLASS` for any QTH but
  `DX` (`PostUnit.PAS:1958`), Cabrillo writes the QTH in the section position
  (`uCabrilloExchange.pas:377`), and import reads `ARRL_SECT` back as the
  section (`MainUnit.pas:7814`). `TContestWinterFieldDay` already does all
  four. No change.

- **Q31** Any refused exchange with no precedence in it (e.g. `599` alone) now
  says `Missing precedence (Q A B U M S)`. Is that wording acceptable?
  **Answer:** (NY4I, 2026-10-15) *Yes* -- the wording stands. No change.

- **FD-DX** You wrote "or with a bad ARRL section or DX on field day" next to the
  refusal ruling. Earlier you said a DX station *can* be worked (`1D DX`). Did you
  mean (a) an example of an existing error, e.g. a W station sending `DX` as its
  section, or (b) that a DX contact should be refused in Field Day?
  Today: Field Day accepts DX.
  **Answer:** (NY4I, 2026-10-15) *"A W should never be logged with DX as that
  would be an invalid domestic qth."* Reading (a): an example of an existing
  error, not a ban on DX. A DX station is still worked as `1D DX` (7.1); `DX`
  from a station whose country has ARRL/RAC sections is an invalid section and
  is REFUSED at entry with an error (7.10). Not built: today Field Day accepts
  `DX` from anyone (`ParseClassDomesticOrDXQTH`). How an ADIF import holding
  such a record behaves is to be proposed with the change.

- **Q44** Three contests keep their band rule inside their scoring, not as the
  contest's bands: RTC (0 points and no multiplier off 40/20/15/10 m or off
  CW/SSB), and CQMM and WRTC (0 points off 80-10 m, but the multiplier still
  counts). Your off-band ruling is 0 points and no multiplier. State each one's
  bands the standard way? *Recommended: yes* -- RTC changes nothing visible; CQMM
  and WRTC stop crediting a multiplier from an off-band QSO.
  **Answer:** (NY4I, 2026-10-15) *Accept.* RTC, CQMM and WRTC state their
  bands (and RTC its modes) the standard way. NY4I added: *"off-band (or off-
  mode) are not added to the score since they are zero. They are likewise not
  added to the qso counts sent to hamscore. But it is ok to increase the qso
  number we sent."* So an off-band or off-mode QSO is logged, scores 0, earns
  no multiplier, is left out of the QSO counts posted to HamScore, and still
  advances the sent serial number. Not built; what HamScore's counts include
  today is to be measured first.

- **Q13** Oregon QSO Party scores by the radio's current mode, not the QSO's, so a
  rescore follows the radio. Fix when OQP gets its class? *Recommended: yes* (the
  same kind of fix as the Croatian clock).
  **Answer:** (NY4I, 2026-10-15) *"a rescore should never follow the radio.
  The whole idea of capturing the event source was the mode at the point in
  time it was logged. The current radio mode is irrelevant (as is the current
  operator for example). Once in the database as the event of logging a QSO is
  captured, that is kept. A subsequent edit simply updates what the operator
  edits."* A RULE FOR EVERY CONTEST, not only OQP: scoring, dupes, multipliers
  and exports of a logged QSO read the QSO record and nothing live. **The OQP
  arm itself is already gone:** it was the Ontario QSO Party's
  `OQPQSOPointMethod`, which no D7 contest row named, reachable only through
  an operator's `QSO POINT METHOD`, and deleted at M10 (Q11).
  **AUDIT 2026-10-15 (contest-scoring, read-only).** Rescore, network receive,
  `.TRW` import and the scoring classes read NO live state; the exchange
  parser's `ActiveMode` reads are reached only from live entry (and the
  contest matrix sets them first). D7's rescore read the clock (Croatian at
  23:30 doubled every QSO); that is already fixed here. Found, none fixed yet:
  - **A1 Alt-E (SO2R edit)** -- `so2r_swap` is cleared only after a
    SUCCESSFUL save (`uEditQSO.pas:806`); cancel, Escape or a refused save
    leaves it set, and the next ordinary Edit QSO writes the inactive radio's
    band and frequency captured at that old Alt-E. While set, the form's own
    Band and Frequency edits are ignored. D7 the same.
  - **A2 ADIF import** stamps a record with no `OPERATOR` with whoever is
    logged in now (`uADIF.pas:1294`). D7 the same.
  - **A3 Cabrillo** prints a digital QSO's report as SNR-to-RST or `599`
    depending on whether WSJT-X is enabled NOW (`postunit.pas:3041`), so one
    log exports two ways. D7 the same.
  - **B WSJT-X** -- a QSO logged in WSJT-X goes through live entry: its time
    and operator are overwritten with the arrival time and the current
    operator, RST checks follow the radio's mode, and under QSO NUMBER BY BAND
    it takes the radio band's serial. D7 the same.
  - **C rover / station facts** -- scoring reads the CURRENT grid, state,
    power and county on a rescore. The schema has `my_grid`, `my_state` and
    `my_county` per QSO for exactly this, and nothing writes or reads them.
    Joins the known `exchange_sent`-never-written gap and F26 group B.
  - **E1 Edit QSO** computes points BEFORE reading the edited fields
    (`uEditQSO.pas:491`), so the copy sent to network peers carries pre-edit
    points (the local rescore corrects it; a peer only with AllowAutoUpdate).
  - **E2** the rescore keys FM dupes as FM; `LoadinLog` folds FM into Phone.

- **Q7** Apply the NRAU pattern (a base + CW/SSB children) to every two-mode pair?
  So far only NRAU-Baltic has it; NA Sprint CW/RTTY and the other pairs are
  siblings or copies. *Recommended: only where the two rows are genuinely one rule
  today; otherwise copies.*
  **Answer:** (NY4I, 2026-10-15) *Accept.* A base with CW/SSB children only
  where the two rows are genuinely one rule today; otherwise copies. Q43 asks
  which pairs qualify.

- **Q9** Should an operator-edited CQ memory survive re-selecting the contest?
  *Recommended: yes -- an edited memory is an operator statement.*
  **Answer:** (NY4I, 2026-10-15) *Accept.* An operator-edited CQ memory
  survives re-selecting the contest. Not built.

- **Q37** `LOGGRID.ConvertGridToLatLon` reads past the end of a grid shorter than 4
  characters, so a malformed grid's score depends on leftover memory (identical
  ALRS QSOs scored 43, 42, 42). Tesla and European VHF read short grids the same
  way. Fixing it changes scores for malformed grids in every grid contest. What should a malformed grid score? *Recommended: fix the
  read; a grid that is not a grid scores as no distance.*
  **Answer:** (NY4I, 2026-10-15) *"a malformed grid should never have been
  logged."* Read as: a grid exchange that is not a grid is REFUSED at entry
  with an error, the 7.10 rule for an invalid exchange -- and, as my reading,
  an ADIF import holding one fails like any other bad record (call, band, mode
  and time named, nothing imported). The read past the end is still made safe,
  so a log that already holds one scores it as no distance instead of leftover
  memory. Not built.

- **Q46** Ten-Ten scores 2 for every QSO: the "2 with a Ten-Ten number, else 1"
  test can never be false (a 16-bit field compared with -1). Should a QSO with no
  Ten-Ten number score 1, as the code was evidently meant to?
  **Proposed answer:** From the F26 research (`docs/F26_EXCHANGE_LAYOUTS.md`):
  2 points with a 10-10 number, 1 without, as WA7BNM and DXLog `TENTENQP.txt`
  state it. It is item C11 of F26's build list.
  **Answer:** (NY4I, 2026-10-15) *Yes* -- the proposed answer stands.

- **Q56** (decided under the delegation; please confirm) A contest's sent
  state now stands for the whole session: a MY STATE line after CONTEST in a
  `.cfg`, or a Preferences edit mid-contest, no longer changes what Canada
  Day/Winter, the Russian DX contests or the Cup RF send. The alternative
  would have sent a stale state after reopening a log (design 8.2m).
  *Recommended: accept.*
  **Proposed answer:** Decided under the delegation and implemented (design
  8.2m).
  **Answer:** (NY4I, 2026-10-15) *Yes* -- the proposed answer stands.

- **Q75** What are the Delaware QSO Party's WA7BNM calendar id and log
  submission address? Both are blank, so its calendar menu item is greyed.
  **Proposed answer:** From WA7BNM (researched 2026-10-14): calendar id
  **240**; logs go to the sponsor's Gmail address on its page, to be copied
  exactly when the class is filled in.
  **Answer:** (NY4I, 2026-10-15) *Yes* -- the proposed answer stands.

- **Q81** New England county abbreviations: IN7QPNE's file spells them
  state first (`MEAND`) and uses Connecticut's new planning regions
  (`CTCAP`); NEQP's own file spells them county first (`ANDME`) with the
  eight old CT counties. Which does the NEQP sponsor use now? IN7QPNE works
  out the party from its own file's spelling, so it is right either way;
  this is about the two files agreeing.
  **Proposed answer:** From the NEQP sponsor (researched 2026-10-14): state
  first (`MEAND`) and the Connecticut planning regions. So IN7QPNE's file is
  current and NEQP's `neqso.dom` is stale, to be brought into line.
  **Answer:** (NY4I, 2026-10-15) *Yes* -- the proposed answer stands.

- **Q18** Jock White Field Day (https://www.nzart.org.nz/activities/contests/jwfd):
  are ZL contacts 5 CW / 3 phone and non-ZL 10 still the rule? Digital and FM score
  3 today. Your own branch is never a multiplier -- does the sponsor count it?
  **Answer:** (2026-10-15, from NZART's own page, which NY4I supplied; rules updated
  21 April 2025.) **No to the 10:** since October 2023 contacts score the same
  inside and outside ZL -- **CW 5, phone 3** -- and overseas contacts must be in
  Oceania. **Own branch: does NOT count**, which matches TR4W today (a same-branch
  QSO scores points, no multiplier). The page names only phone and CW (80/40 m), so
  digital and FM are not modes of this contest. Three further defects came out of
  the same page -- hourly dupe periods, a serial per band, the field-station QSO
  minimum -- recorded in `docs/F26_EXCHANGE_LAYOUTS.md` (Q10). To fix in its own
  commit with a matrix re-freeze.

- **Q60** The off-time minimum (the gap that counts as a break) is 60 minutes
  for CQ WW and 30 for everything else -- but the two places that use it
  disagree about IARU: the main window's on-screen operating time uses 60 for
  CQ WW **and IARU HF** (n4af, 4.115.4), the summary sheet's OPERATING TIME
  uses 60 for CQ WW only (and reads it from the contest NAME, so a stated
  `CONTEST NAME` changes it). Same in D7. The IARU HF rules have no off-time
  rule that I know of. Which is right for IARU -- 60 or 30? Once you say, it
  becomes one value on the contest and both places use it.
  **Answer:** (NY4I, 2026-10-15, from DXLog.net's contest definitions.) CQ WW is
  **60** -- `CQWW.txt` has `MIN_OFF_TIME=60`, which NY4I called confirmation. IARU HF
  is **not** 60: `IARUHF.txt` sets no `MIN_OFF_TIME` at all (33 of DXLog's 543 files
  set one, and IARU's own are its VHF/UHF and field-day events, at 120). So IARU HF
  takes the default 30, and the main window's IARU arm (n4af, 4.115.4) is the one that
  is wrong. Implementation: the off-time becomes one value the contest states, which
  both the main window and the summary sheet read, so the summary sheet no longer
  derives it from the contest NAME.
  **IMPLEMENTED 2026-10-15.** `TContestBase.MinimumOffTimeMinutes` (base 30);
  `TContestCQWWBase` (CW and SSB) and its sibling `TContestCQWWRTTY` say 60 --
  the three tokens `Pos('CQ-WW', ...)` matched. `PostUnit.CalculateTotals`
  (the summary sheet's OPERATING TIME and the CT1BOH window's per-band times)
  asks `ContestIdentity(Contest)`, and its rule is `GapIsOperatingTime`. Its
  `CONTEST NAME` test is deleted: a stated name no longer changes the break.
  **THE MAIN WINDOW'S COPY WAS DEAD, NOT WRONG IN EFFECT**: it wrote
  `MainUnit.T1`, and nothing read it -- LOGWIND's reader sat inside a `{ }`
  comment in D7 as well. It is deleted, not pointed at the contest, so the
  on-screen times do not change for IARU or any contest (the on-air counter
  has no break rule). Pinned by `uTestContestUI`
  (`Test_OnlyCQWWHasASixtyMinuteBreak`, `Test_AGapCountsUpToTheBreak`).
  ~~Still open: whether CQ WW RTTY's own rules set a different off time.~~
  **Answered (NY4I, 2026-10-15, quoting the CQ WW RTTY rules):** the Classic
  overlay's *"off times are a minimum of 60 minutes during which no QSO is
  logged"*. So CQ WW RTTY stays at 60, which is what it already uses.
  No code change.

- **Q87** IN7QPNE's New Contest prompt names its "area" as `IN7QPNE` -- a
  token, not a place -- and the prompt shows it twice. Should it read
  something like "Indiana, 7th area, New England or Delaware"?
  *Recommended: yes; the composite class can state its own prompt.*
  **Answer:** (NY4I, 2026-10-14) *"Your recommendation."* The composite
  class states its own prompt naming the four areas, shown once.

- **Q90** Rover calls on ADIF export. TR4W writes a state party's rover
  (`KG1S/MON`, suffix = the QSO's county) as the bare call plus
  `APP_TR4W_ROVERCALL`, but only for the 15 parties whose old table row said
  `CountyLineAllowed: True`. Arizona, BC, Virginia, the Salmon Run and New
  York have no such flag, so their rovers export as plain `KG1S/MON` calls;
  and the import reads `APP_TR4W_ROVERCALL` for every contest. A rover is not
  a county line, the flag was only a stand-in for "is a state QSO party", and
  M10 S7 (which moved the county-line IMPORT to the class) left this export
  rule on the old row. Should every state party split a rover call on export
  (a change to those five parties' ADIF), and may the class state it as its
  own property so the row can be deleted at S8?
  *Recommended: yes, every state party, as a class property.*
  **M10 S8 (2026-10-14) did the second half without changing behaviour:** the
  row is deleted and the class states it -- `SplitsRoverCallOnExport` on
  the state-party base, True for exactly those fifteen. What is left is the
  first half: should Arizona, BC, Virginia, the Salmon Run and New York
  split too (one override each, and a change to their ADIF)?
  **Answer:** (NY4I, 2026-10-14) *"yes QSO parties allow it but in any
  contest NY4I/7 or VP9/NY4I is a valid call."* Read as one rule, which also
  answers Q94: **a slash suffix is a county rover only in a state QSO
  party**, and there it is both stripped live and split on export -- so
  Arizona, BC, Virginia, the Salmon Run and New York split too, and CA, CO,
  MN, OH and PA strip live too. **Everywhere else the slash call is the
  call**: ALRS, ARRL 160, ARRL DX (CW and SSB), LABRE, PACC and TOEC stop
  stripping it. County Hunter keeps its strip (my call, not NY4I's: its
  exchange IS a county and its mobiles run county lines) -- flag it if that
  is wrong.

- **Q91** `tr4w/src/trdos/logddx.pas` (TR's DX simulator, "DDX") is compiled
  by nothing, and was not compiled in D7 either: every `uses LOGDDX` is
  commented out in both trees (`MainUnit`, `LogCfg`, `logsubs2`), and it
  uses a `Country9` unit that exists in neither. Its 26+ references to
  the `Active*` globals therefore go stale as M10 S9 deletes them, with no
  compiler to notice. Delete it (git history keeps it, and design §2's
  `SampleExchange` row is the end-state plan for a simulator), or keep it
  as reference? I tried to delete it and the session's safety check
  refused an irreversible delete without you, so it is untouched; the
  remaining S9 stages leave it alone.
  **Same question for `tr4w/src/trdos/logmenu.pas`** (found at S9d): every
  `uses LOGMENU` is commented out (`MainUnit`, `LogCfg`, `logedit`,
  `logsubs1`, `logsubs2`) and `tr4w.lpr` does not list it, yet it holds a
  second textual caller of `FoundContest` -- which made the country-mode
  ordering check (F5) look riskier than it is.
  *Recommended: delete both.*
  **Answer:** (NY4I, 2026-10-14) *"delete both."*

- **Q92 -- THE DESIGN QUESTION.** Keep `ExchangeType` as a vocabulary of
  exchange SHAPES that a class selects? The design says the kind enums
  "die with the engine" and that a helper is "never selected ... by an
  enum". Measured: 162 of `ExchangeType`'s 168 `case` arms are four
  contest-blind machines keyed on the shape -- the parser (56 arms), the
  field list (43), ADIF (32) and Cabrillo (31). Deleting the enum means
  every one of 186 classes overrides all four and keeps them agreeing, or
  a per-shape object, which is a strategy and is forbidden. It is not
  stored and does not cross the network, so the whole price is code. The
  other five kinds (initial exchange, domestic/DX/prefix/zone
  multipliers) ARE rules and M11 deletes them either way.
  *Recommended: keep it, documented as shapes -- like CountryModeType
  and ZoneModeType, it describes data, not a rule.*
  **Answer (NY4I, 2026-10-14): OPTION 2 -- the CLASS chooses, explicitly.** Not
  the recommendation above. The four shape `case`s become plain named
  helper functions (e.g. `ADIFRstAndState(rst, state)`), and each class's
  `FormatADIF*` / `FormatCabrillo*` / parse / field-list override CALLS the
  helper it wants -- once on a family base where a family shares one.
  The enum stops selecting anything, which is what design §1.3 already
  says ("a helper is never selected ... by an enum"). Shared formats stay
  in one place, so there are no copies. Asked by NY4I while reading
  `uADIFExchange.pas:357`: "Shouldn't the ADIF process call the contest
  class and ask it to build the exchange for ADIF and Cabrillo?"

- **Q93** (MOOT under Q92's option 2 -- every shape becomes a helper a class calls, so a single-contest shape is simply a helper with one caller; nothing extra moves.) Originally: if Q92 is yes: should the 20 shapes that exactly one contest uses
  still move into their contest (about 80 arms, one contest per commit)?
  It buys a smaller vocabulary, not ownership.
  *Recommended: no, unless you want the vocabulary small.*
  **Answer:** MOOT -- Q92 option 2 (a helper each class calls) leaves nothing
  for this question to decide.

- **Q94** (with Q90) "Is a slash suffix a county?" is answered two ways
  that disagree: by exchange shape on the live path (25 contests) and by
  the class on export (15). Split on export but not stripped live: CA,
  CO, MN, OH, PA. Stripped live but not split on export: ALRS, ARRL 160,
  ARRL DX x2, AZ, BC, County Hunter, IN7QPNE, LABRE, NEQP, NY, PACC,
  Salmon Run, 7QP, TOEC. Which contests really have /county rovers? M11
  will transcribe today's two sets exactly until you say.
  **Answer:** answered by NY4I's Q90 ruling (2026-10-14): a slash suffix is a
  county rover only in a state QSO party. **IMPLEMENTED `bb07fd06`.**

- **Q96** CQ WW CW starts the exchange field with a Custom initial exchange,
  CQ WW SSB with the zone -- one family, two answers. Intended?
  *Recommended: both Zone, unless the CW Custom was deliberate.*
  **Answer:** (NY4I, 2026-10-14) *"Yes both should fill zone if that option
  is set for initial exchange."* CQ WW CW becomes `ZoneInitialExchange`, as
  SSB and RTTY already are. Note for the record: the CW `Custom` came from D7
  (`VC.pas` row 4.105.17), and with the default empty CUSTOM INITIAL EXCHANGE
  STRING it filled nothing. No setting gates the zone fill itself -- the
  per-contest INITIAL EXCHANGE command retired at M10 S2 -- so "that option"
  is the contest's own initial-exchange kind; REVERSE INITIAL EX still
  prefers the callsigns list where it is set.

- **Q50 is now an M11 blocker.** The Russian DX / RU3AX "initial exchange
  from a call" has not run since M10 S2 -- the only arms that reach it are
  used by no contest -- while LOGEDIT's fallback is the live rule, and a
  unit test pins the dead one. M11's S1 (dead members) and S8 (initial
  exchange) wait on Q50.
  **Unblocked 2026-10-15:** Q50 is answered (next entry).

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
  **Answer:** (NY4I, 2026-10-15) *"go with recommendation."* One rule:
  `RussianID` of the CTY.DAT **country**, then `GetRussiaOblastID` of the call,
  as a named helper each contest calls (Russian DX, RU3AX, RDA for the initial
  exchange; Russian DX, both RF Championships and RDA for the hint). D7 had the
  same three disagreeing sites: ZONECONT's `UA` test never ran (both contests'
  rows said `NoInitialExchange`), LOGEDIT's country-based fallback was the live
  rule, and the hint tested the raw CALL, so Russian `UB`..`UI` calls got no
  hint. D7's Russian DX scoring also tests the country.

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
