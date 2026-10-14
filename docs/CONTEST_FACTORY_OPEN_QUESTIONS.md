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
  **Answer:** **IN7QPNE RULED 2026-10-13: a composite of four parties (IN, 7QP, NE, DE), per-QSO rules of the worked station's party; one Cabrillo; no score posting -- design 7.14. 7QP/NEQP multi-state rules otherwise still open.**

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
  **Answer:**

- **Q60** The off-time minimum (the gap that counts as a break) is 60 minutes
  for CQ WW and 30 for everything else -- but the two places that use it
  disagree about IARU: the main window's on-screen operating time uses 60 for
  CQ WW **and IARU HF** (n4af, 4.115.4), the summary sheet's OPERATING TIME
  uses 60 for CQ WW only (and reads it from the contest NAME, so a stated
  `CONTEST NAME` changes it). Same in D7. The IARU HF rules have no off-time
  rule that I know of. Which is right for IARU -- 60 or 30? Once you say, it
  becomes one value on the contest and both places use it.
  **Answer:**

- **Q61** CATEGORY-POWER is now one value (design 7.6). Four other Cabrillo
  categories have the same two-store shape: ASSISTED, BAND, MODE and OPERATOR
  start from the setting the New Contest dialog wrote, but the summary window
  writes MODE to a copy of its own and the other three nowhere, so a headless
  export reads a stale or empty copy. Make them one value each, the same way
  (no rescore -- no contest scores by them)?
  **Answer:**

- **Q62** (POTA's class, 2026-10-13) A POTA hunter who sends a Canadian
  province is exported with `DXCC 291` -- the USA -- beside `STATE ON`. The
  export always wrote 291 for anything that looked like a state, and that list
  includes the provinces. Moved exactly as it was. Should a province write
  Canada (1), or should POTA leave DXCC to the callsign's country like every
  other contest?
  **Answer:**

- **Q63** The New Contest dialog captions POTA's box "Activator" as plain
  English text, so no translation can reach it. Moved as it was. Give it a
  translatable string?
  **Answer:**

- **Q64** The New Contest drop-down now lists POTA as "Parks on the Air(r)
  Logging" (its friendly name -- every contest class shows its human name,
  your M9a ruling) where it used to say "POTA". Keep that, or should POTA's
  line stay "POTA"?
  **Answer:**

### Added with 7.12 (station facts a contest may override, 2026-10-13)

- **Q65** MY CALL has the problem 7.12 just fixed for MY STATE and MY ZONE.
  When a contest is run under a club call (W4TA), the call is written into
  the station's MY CALL. The next settings save in the session, such as a
  Preferences edit, writes W4TA into `tr4w.json` as the station's own call.
  It was left out on purpose: about 120 places read MY CALL, and your
  country, continent and zone are derived from it. Should MY CALL become an
  overridable station fact too, as its own step? MY COUNTRY would then be
  derived from the call this contest uses. *Recommended: yes, separately.*
  **Answer:**

- **Q66** Preferences shows and edits the station's value. If this contest
  overrides that field (zone 3 in Utah), an edit there changes the station
  but not this contest, and nothing on the page says so. Should the Station
  page show the contest's value beside the field, with a way to clear it?
  *Recommended: yes, a hint that names the contest's value.* This is
  `lcl-ui` work.
  **Answer:**

- **Q67** The New Contest dialog's rows start empty, and every row has to be
  filled before OK is enabled. So every contest that asks for MY ZONE
  states a zone override, even when you type your station's own zone. That
  contest then ignores a later Preferences change to the zone. Should the
  rows start with your station's values (read from the file, because the
  dialog runs before the settings load)? And should a row you leave
  unchanged count as "use the station's value" rather than as an override?
  *Recommended: yes to both.*
  **Answer:**

- **Q68** Reopening a log with no `.cfg` sets up the contest before the
  log's own rows are applied. The in-state test and the exchange messages
  are built then, so they use the station's state and zone rather than this
  contest's override. Before 7.12 this was the same, with the contest's
  value written into the station after set-up. MY CALL is already applied
  first for the same reason. Should the station-fact rows be applied first
  too? *Recommended: yes.* That would change set-up on reopen for a log
  whose override differs from the station.
  **Answer:**

### Added with the UA4W Championship's and RSGB 1.8's classes (2026-10-14)

- **Q69** MY ZONE, when nobody states it, is worked out from your call in
  the contest's own zone system. Most contests use ITU zones, so there it
  is the ITU zone: K0AAA gets 7, not CQ zone 4, in the UA4W Championship.
  7.12 calls MY ZONE your CQ zone, and IARU relies on the ITU answer. Should
  MY ZONE always be the CQ zone, with ITU-zone contests reading MY ITU ZONE?
  That would change IARU's set-up and messages when no zone is stated, so it
  would be its own step. *Recommended: yes, separately.* Until then the UA4W
  class asks a separate service for your CQ zone (design 8.2p).
  **Answer:**

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
  **Answer:**

### Added with the Delaware QSO Party's class (2026-10-14)

- **Q72** Delaware's bands: "all HF bands except WARC, plus 6 m and up".
  The class counts 160 m and light as well as 80-10 m (no WARC) and 6 m up.
  Both are my reading of the summary, not of the sponsor's page. Are they
  in? A QSO on a band that is out scores 0 and earns no multiplier.
  *Checked against the sponsor's 2024 page (2026-10-14):* it says "All HF
  bands excluding WARC bands" and "6 meters and up", so **light is in**.
  160 m is not named either way, and the page's suggested frequencies do
  not list it. 1.8 MHz is strictly MF, not HF. So only 160 m is open.
  *Recommended: keep 160 m in unless you know the sponsor excludes it.*
  **Answer:**

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

- **Q74** Delaware's Cabrillo header must have `ARRL-SECTION:` or
  `LOCATION:` (DE, your state or section, or DX). TR4W now refuses to write
  the file without a LOCATION, and you type it. Should TR4W fill it in from
  where you are? *Recommended: yes -- DE in state, else your state, else DX.*
  **Answer:**

- **Q75** What are the Delaware QSO Party's WA7BNM calendar id and log
  submission address? Both are blank, so its calendar menu item is greyed.
  **Answer:**

- **Q76** In every single-state party, an in-state station's ADIF export
  labels every QSO with the HOST state: a DE station working a PA station
  exports `STATE:DE` beside `QTH:PA`. Should `STATE` be the host state only
  for a host county, and the worked state otherwise? This changes the
  ADIF of every in-state party log, so it would be its own step.
  *Recommended: yes, separately.*
  **Answer:**

### Added with the IN7QPNE composite (2026-10-14)

- **Q77** IN7QPNE's score. You said a combined score is not needed, and it
  would be nice to see the score of the party just worked. Nothing on screen
  can show more than one score today, so the window, the summary sheet and
  the Cabrillo `CLAIMED-SCORE` show points x multipliers over the whole
  combined log -- a number that is no sponsor's score. Should TR4W get a way
  to show one score per party, or should the Cabrillo claim nothing?
  *Recommended: a per-party score, as its own step; until then leave it.*
  **Answer:**

- **Q78** An Indiana, 7QP, NE or DE entrant who works a station in ANOTHER of
  the four parties: TR4W scores it by the worked party's rules only, as you
  ruled. The entrant's own sponsor may count it too (an Indiana station
  working Arizona earns an Arizona multiplier in the Indiana QSO Party).
  Each sponsor scores the shared log itself, so their results are not
  affected; only TR4W's points show one party's view. Is that right?
  **Answer:**

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

- **Q81** New England county abbreviations: IN7QPNE's file spells them
  state first (`MEAND`) and uses Connecticut's new planning regions
  (`CTCAP`); NEQP's own file spells them county first (`ANDME`) with the
  eight old CT counties. Which does the NEQP sponsor use now? IN7QPNE works
  out the party from its own file's spelling, so it is right either way;
  this is about the two files agreeing.
  **Answer:**

- **Q82** County lines in IN7QPNE: Indiana and Delaware allow two counties,
  7QP four. TR4W checks the COUNT before it knows the counties, so IN7QPNE
  allows any number, as it always did. Teach the check which party the
  counties are in, or leave it? *Recommended: leave it until a line between
  two parties is real.*
  **Answer:**

- **Q83** HamScore now asks the contest whether its score may be posted.
  Until now only the post-scores window asked, so WRTC (no live score
  posting) still went to HamScore when HAMSCORE ENABLE was on. With this
  change neither WRTC nor IN7QPNE is posted. Is that right for WRTC?
  *Recommended: yes.*
  **Answer:**

- **Q84** Indiana's rule is "a DX station is not a multiplier", and it looks
  for `DX` in capitals. Indiana's own file says `DX = DX`, but IN7QPNE's
  file says `dx = dx`, so in IN7QPNE an Indiana entrant's DX contact still
  earns the one `dx` multiplier. Change IN7QPNE's file to `DX`, or make the
  rule ignore case? *Recommended: change the file.*
  **Answer:**

- **Q85** Does 7QP allow the WARC bands? The 7QP class scores a 30 m CW QSO
  at 3 points (frozen matrix, `SEVENQP.matrix` QSO 09), and IN7QPNE now
  inherits that for every 7QP-judged QSO. Delaware excludes WARC by its
  sponsor's rules; nothing in TR4W says whether 7QP does. If it does not,
  the 7QP class should declare its bands the way Delaware's does, and
  WARC QSOs then score 0 (logged, never refused).
  *Recommended: check the 7QP rules page and tell me which bands.*
  **Answer:**

### Found while the classes took over the table's values (M10 S5, 2026-10-14)

These were copied into the classes exactly as the old table had them, so
nothing changed. Each looks wrong; none was fixed without your answer.

- **Q86** The Minnesota QSO Party is the only state party whose table row
  marks it "RTC capable" (live score posting through the RTC uploader).
  No other party has it. Intended, or a typo in the row?
  *Recommended: remove it unless Minnesota is posted to a scoreboard.*
  **Answer:**

- **Q87** IN7QPNE's New Contest prompt names its "area" as `IN7QPNE` -- a
  token, not a place -- and the prompt shows it twice. Should it read
  something like "Indiana, 7th area, New England or Delaware"?
  *Recommended: yes; the composite class can state its own prompt.*
  **Answer:**

- **Q88** The NA Sprint CW and RTTY rows name different domestic files:
  CW uses `naqp`, RTTY uses `s49p8`. Both are the same sprint exchange
  (states, provinces, NA). Is one of them wrong, and which file should
  both use?
  **Answer:**

- **Q89** British Columbia QSO Party ADIF export: TR4W writes NO `STATE`
  (and no `CNTY`) for a BCQP QSO, because the old table named BC's area
  `VE7` -- not two letters -- and the export only writes a two-letter
  state. The BC class itself says its host is `BC`, and ADIF's `STATE`
  field does carry Canadian provinces. Should BCQP export `STATE:BC` (and
  the county) like the US parties do? M10 S6 deliberately kept today's
  output; this would change BCQP's ADIF, so it waits for you.
  *Recommended: yes, export BC.*
  **Answer:**

---

## 2. Design (recommendation given; "accept" is enough)

- **Q6** POTA as a contest class, following the General QSO precedent. Its park
  "n-fer" is stored the same way as a county line. *Recommended: yes.*
  **Answer:** **RULED 2026-10-13 (NY4I): YES -- POTA becomes a contest class.** "While it is not a contest per se, just like with GENERAL QSO, we treat it that way." **Built the same day: `TContestPOTA` (design 8.2o).**

- **Q7** Apply the NRAU pattern (a base + CW/SSB children) to every two-mode pair?
  So far only NRAU-Baltic has it; NA Sprint CW/RTTY and the other pairs are
  siblings or copies. *Recommended: only where the two rows are genuinely one rule
  today; otherwise copies.*
  **Answer:**

- **Q28** UA4W: may the station context carry MY CALL's CQ zone, so UA4W can get a
  class? *Recommended: yes* (the same service shape ARRL 160 is getting).
  **Answer:** **RULED 2026-10-13: yes, and station facts (CQ zone, state, section) are a station default a contest may override at selection time -- design 7.12.** **Built 2026-10-14: `TContestUA4WChampionship`, reading the `MyCQZone` service (design 8.2p; Q69, Q70).**

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
  **Answer:** **RULED 2026-10-13: yes, a read-only new-multiplier answer -- design 7.13.** **Built 2026-10-14: `TContestRSGB18`, reading the `IsNewMultiplierAnywhere` service (design 8.2p; Q71).**

- **Q37** `LOGGRID.ConvertGridToLatLon` reads past the end of a grid shorter than 4
  characters, so a malformed grid's score depends on leftover memory (identical
  ALRS QSOs scored 43, 42, 42). Tesla and European VHF read short grids the same
  way. Fixing it changes scores for malformed grids in every grid contest. What should a malformed grid score? *Recommended: fix the
  read; a grid that is not a grid scores as no distance.*
  **Answer:**

- **Q4** Retire `EXCHANGE RECEIVED`, the four multiplier commands and `INITIAL
  EXCHANGE` along with `QSO POINT METHOD` at the end? They select from shared sets
  the same way. *Recommended: yes.*
  **Answer:** **RULED 2026-10-13 (NY4I): YES, all seven retire.** "Since we will be able to enter contests faster, we can retire the user entering their own contests. That is a desired feature by the user community but we can revisit another way to do it."

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
  **Answer:** **RULED 2026-10-13: yes, delete them at M10 -- design 7.15.**

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

### Added after M9a

- **Q54** HamScore's one-QSO Cabrillo line writes Winter Field Day's FM
  contacts as `FM`; the Cabrillo file writes `PH`. Should HamScore ask the
  contest too? *Recommended: yes* -- one rule for both; it changes what
  HamScore receives for WFD FM QSOs.
  **Answer:**

- **Q56** (decided under the delegation; please confirm) A contest's sent
  state now stands for the whole session: a MY STATE line after CONTEST in a
  `.cfg`, or a Preferences edit mid-contest, no longer changes what Canada
  Day/Winter, the Russian DX contests or the Cup RF send. The alternative
  would have sent a stale state after reopening a log (design 8.2m).
  *Recommended: accept.*
  **Answer:**

- **Q57** CQ WW RTTY's set-up writes MY ZONE as "zone state" while it builds
  its messages, then puts it back -- and the write marks MY ZONE as yours, so
  it no longer follows MY CALL. Build the messages without touching MY ZONE?
  *Recommended: yes* (the messages are identical; only a later MY CALL change
  behaves differently).
  **Implemented with 7.12 (2026-10-13), by necessity:** with the readers on the
  resolver, the transient write would have dropped the state whenever a zone
  override was stated. The messages are built from a local; MY ZONE is never
  written. Please confirm.
  **Answer:**

---

## 3. Already answered (for reference)

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
