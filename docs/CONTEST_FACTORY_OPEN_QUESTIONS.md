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

## What is still open (index, 2026-10-16)

Re-read 2026-10-16: every question below is genuinely unanswered; the rest are
in section 4. One line each -- the full text is further down.

**Sponsor rules (section 1)**
- **Q27** SAC: is a Russian station not workable, or only not a multiplier?
- **Q97** Franz Josef Land (R1FJ) oblast reads as "SP" in Russian DX.
- **Q70** UA4W Championship's 18/19 zone rule.
- **Q106** Nebraska: rare grid bonus, satellite points, FT8/FT4 competition.

**Design (section 2) -- each has a recommendation; "accept" is enough**
- **Q8** Events with no ContestType still named in code (TRC, PGA, EURASIA ...).
- **Q47** Fix the three kept read-past-the-end shapes now?
- **Q101** Fill the typed `rcvd_*` columns from each class, or delete them?
- **Q110** Multi-op: a peer's QSO is logged even when the peer is on a different contest.

**Awaiting only your yes (section 3)**
- **Q10** Retire unused ContestTypes through `TContestRetired` (MINITEST needs it).
- **Q26** WAG import with no DOK: empty QTH.
- **Q88** NA Sprint domestic file (13 vs 14 VE; the SSB Sprint too).
- **Q95** Croatian ITU zones.
- **Q23** CUP RF: the QSO line, and the difference never reached a file -- close.
- **Q40** County-line limits: 7QP 4, NEQP none (stated); a rover logs its own party.

**Not a question but open:** Q59 asks you to confirm GREY (unselectable) for an
inactive contest in the New Contest list.

---

## 1. Sponsor rules

### Other contests

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

### Added with the UA4W Championship's and RSGB 1.8's classes (2026-10-14)

- **Q70** The UA4W Championship pays 10/20 on 80/160 m when your CQ zone is
  18 or 19. It now uses a zone you stated first (your 7.12 ruling); the old
  code always used your call's CQ zone. With no zone stated, the two agree.
  A zone typed for this contest is taken as a CQ zone, as MY ZONE's command
  says. *Recommended: confirm.*
  **Answer:**

### Added with the IN7QPNE composite (2026-10-14)

- **Q106** (Nebraska, 2026-10-16) Three sponsor rules the new class does
  not build yet. (1) **Rare grid bonus**: a station activating DN91CE, DN91DE
  or DN91EE gets those QSOs' points x5 as a bonus. (2) **Satellite** QSOs are 4
  points -- TR4W has no notion of a satellite QSO. (3) **FT8/FT4** is a
  separate competition (grid-square exchange, 2 points, grid multipliers,
  its own log); in this class an FT8/FT4 QSO is off-mode -- logged, scores
  nothing. Also the sponsor's UTC times disagree with its own local times.
  25-26 Apr 2026 is after US daylight time began (8 Mar 2026), so Nebraska's
  Central zone is CDT, UTC-5: "1400 UTC (8:00 AM CDT)" -- 8 AM CDT is 1300
  UTC; "Sunday April 27th at 0200 UTC (08:00 PM CDT)" -- 8 PM CDT Sunday the
  26th is 0100 UTC Monday the 27th (27 Apr 2026 is a Monday). The UTC figures
  are CST arithmetic. WA7BNM ref 336 gives 1300Z Apr 25 - 0100Z Apr 27,
  matching the CDT times. A schedule is stored in UTC (Q99); which figure the
  sponsor means is theirs to say -- *recommended: WA7BNM's, which agrees with
  the sponsor's own local times.*
  *Recommended: (1) build it -- it needs only our own grid, which the
  contest already knows; (2) leave until satellite QSOs are a concept; (3) a
  separate contest class later, if wanted.*
  Three more, found building the class (2026-10-16):
  (4) **Does a Nebraska entrant who works another Nebraska station also
  earn NE as a STATE?** The sponsor: in-state multipliers are "Nebraska
  counties worked plus ... States/Provinces/Countries ... The maximum number
  of states worked is 50" -- 50 suggests NE counts. Built: the county only (a
  Nebraska station sends its county, so NE as a state is never reached).
  DXLog does the opposite: every county collapses into ONE "Nebraska"
  multiplier, and counties do not count separately for an in-state entrant
  -- which contradicts the sponsor's "counties plus S/P/C".
  *Recommended: county AND NE (the first NE county worked also credits NE),
  so the 50 is reachable.*
  **Answer to (4):** (NY4I, 2026-10-16) *"the state of the contest is not
  counted for an in-state station. line 15 of ... DXLog.net\Contest\NEQP.txt.
  Many other QSO parties do the same to exclude its own state."* DXLog line 15
  reads "# DX, states, and provinces except NE". So the recommendation was
  wrong and **the class is right as built**: county plus S/P/C, NE never
  credited as a state. No change. (Noted: DXLog's own file is inconsistent
  here -- the regex under that comment includes `NE`, and its in-state list
  maps every county to one "Nebraska" entry; the sponsor's "counties plus
  S/P/C" and this ruling are the authority.)
  (5) **Exactly 100 W**: the sponsor gives x2 for "less than 100 watts" and
  x1 "for over 100 watts" -- 100 W itself is not covered. Built: x2, since
  Cabrillo's LOW category is "100 W or less" and TR4W cannot tell 100 W from
  99. *Recommended: keep.*
  (6) Side finding, not Nebraska's alone: the shared `P13.DOM` lists `LA` as a
  Labrador alias, which collides with Louisiana; S50 loads first, so `LA`
  means Louisiana in every party that includes both. Labrador is `NL` (with
  `LB`/`NF`). *Recommended: drop `LA` from P13.DOM.*
  **Answer:**

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

- **Q101** Thirteen typed received-exchange columns are never written or read:
  `rcvd_state`, `rcvd_county`, `rcvd_section`, `rcvd_grid`,
  `rcvd_postal_code`, `rcvd_society`, `rcvd_department`, `rcvd_rda`,
  `rcvd_park`, `rcvd_summit`, `rcvd_iota`, `rcvd_coords`, `rcvd_continent` --
  plus `snr_sent`, `snr_received` and `cty_itu_zone`. Everything they would
  hold sits in `rcvd_qth` today, and the mapper refuses to guess the type
  ("the contest factory decides"). Should each contest class fill the typed
  column for its own exchange (so an export or a query can read `rcvd_county`
  rather than parse `rcvd_qth`), or should the unused columns be deleted?
  *Recommended: the class fills them* -- it is the one place that knows
  whether a QTH is a county, a section or a grid, which is exactly the
  question Q89's ADIF STATE fix had to answer.
  **Answer:**

- **Q110** (found building Q108 S4, 2026-10-17) **Multi-op: a peer's QSO is
  logged even when the peer is running a DIFFERENT contest.** `uNet`'s
  `NET_QSOINFO` arm calls `LogContact` for every QSO from another station
  (`uNet.pas` ~591) without comparing the packet's contest with this
  station's -- so two stations on one server in different contests would
  each log the other's QSOs, scored under the wrong contest's rules. D7 did
  the same (`uNet.pas:355-365`), so this is not a regression. Is a mixed
  network a real configuration (e.g. a multi-multi running two events), or
  should a QSO from another contest be refused like a by-id contest is?
  *Recommended: refuse it (logged, not added), through the same
  `NetCarriesContest` door S4 added, and show the operator once that a peer
  is on another contest -- a QSO scored under the wrong contest's rules is
  never what anyone wants. If mixed networks are real, they belong to the
  new row-based protocol, not to V1.*
  **Answer:**

---

## 3. Awaiting only your yes

Each carries a **Proposed answer** with its source. "Yes" (or "yes to all")
closes it; anything else reopens it.

- **Q23** CUP RF: the Cabrillo writer takes the QSO's own QTH for the CW and
  SSB runnings but not for CUP RF DIGITAL. Intended?
  You asked (2026-10-16): *"Do you mean the QSO record in cabrillo or the
  contest header?"* -- **the QSO line**: the RECEIVED exchange's QTH column
  (his grid), not the header. D7's `postunit.pas` picked that column's text
  in two steps: with domestic multipliers on, the typed QTH when LITERAL
  DOMESTIC QTH is TRUE, else the matched domestic value; then
  `if Contest in [CUPRFCW, CUPRFSSB]` forced the typed QTH. DIGITAL was left
  out of the second step -- but all three runnings set LITERAL DOMESTIC QTH
  = TRUE, so the first step already gave DIGITAL the typed QTH. **The
  difference never reached a file.** Today the three classes call the same
  writer (`CabrilloReceivedQSONumberQTHShort`), and the frozen matrix's QSO
  lines for CUPRFCW and CUPRFDIG are identical (`0101 CT`).
  **Proposed answer:** no change; close.
  **Answer:**

- **Q40** *Reworded 2026-10-16.* Your answer: IN7QPNE has no rules of its
  own -- it is an umbrella; the open item was whether a rover in, say, New
  England uses IN7QPNE or NEQP. **Answered by the sponsor's page: NEQP** --
  IN7QPNE is for stations outside all four areas (Q104, answered yes: New
  Contest enforces it). So a rover's county list and cap always come from its own
  party, and only the per-party county-line limits are left:
  **Proposed answer:** each party states its own. **7QP: 4** (the figure on
  record in design section 8.2r; 7qp.org refused the connection today, so it
  was not re-read). **NEQP (New England -- not Nebraska, see Q104): no
  maximum, stated explicitly** -- neqp.org/rules:
  *"County line QSOs should be logged as two separate QSOs"*, and no limit is
  given. (Indiana and Delaware already state 2.)
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
| -- | The New Contest drop-down shows the display name | M9b (Q52 settles the words) |
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
| Q75 | Delaware: WA7BNM id 240; the log address from the sponsor's page | built |
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
| Q74 | Cabrillo LOCATION is seeded from the station at New Contest time and stored in the contest; the seed is the ARRL section for W/VE, `DX` otherwise (Q79) | not built |
| Q68 | On reopen, the station-fact rows are applied before the contest row | not built |
| Q76 | ADIF `STATE` is the worked station's state, `MY_STATE` ours -- fix the host-state export | built `35986731` (with Q89) |
| Q82 | IN7QPNE county-line count left as is; future fix | issue #85 |
| Q84 | A party's DX-multiplier test ignores case (files unchanged) | not built |
| Q77 | IN7QPNE per-party score: deferred | issue #86 |
| Q78 | IN7QPNE cross-party scoring view: deferred with Q77 | issue #86 |
| Q98 | Every contest states its bands and modes; an off-band/off-mode QSO is logged, scores nothing, and is an automatic X-QSO in the log and the export (flag OR off-band) | not built |
| Q41 | ARRL VHF runnings named ARRL-VHF-JAN/JUN/SEP; all three get June's set-up | built |
| Q62 | POTA: the worked station's DXCC from its callsign; our MY_DXCC and MY_STATE from our park | not built |
| Q57 | CQ WW RTTY messages built without writing MY ZONE | done with 7.12 |
| Q63 | "Activator" stays untranslated -- a universal POTA term | no change |
| Q72 | Delaware: 160-10 m without WARC plus 6 m and up through light ("DC to daylight") | already so; no change |
| Q85 | 7QP excludes WARC (and the sponsor scores digital 4) | not built |
| Q86 | Minnesota is the only HamScore QSO party; its flag is right | no change |
| Q83 | Online-score posting and HamScore are separate permissions; WRTC and IN7QPNE neither (WRTC amended by Q55) | split not built; WRTC as built |
| Q69 | MY ZONE is the CQ zone; ITU-zone contests read MY ITU ZONE | not built (own step) |
| Q71 | RSGB 1.8, ARRL 160, CQ 160 credit 160 m only; UA4W prompt uses TC_ENTERYOURRDAIDORGRID | not built |
| Q58 | WRTC is named "World Radiosport Team Championship" (display and friendly name) | built |
| Q15 | NRAU Cabrillo names become WA7BNM's NRAU-CW / NRAU-SSB; ADIF keeps NRAU-BALTIC-*; sponsor times | built (names); times are Q99 |
| Q16 | SSB Sprint is "North American SSB Sprint"; NA-SPRINT-SSB stays; gains the North American country multiplier | built |
| Q22 | PACC: both exchanges, one per station (PA receives either); a PA entrant's sent column must be its province, not a serial | built |
| Q61 | ASSISTED, BAND, MODE, OPERATOR: one value each, in the contest database | not built |
| Q54 | WFD writes FM as FM (proposal reversed); HamScore asks the contest's mode spelling; one corpus divergence | built |
| Q34 | Rover county/grid per QSO, set by a call-window command; sketched for later | issue #87 |
| Q89 | BCQP ADIF exports STATE:BC; no CNTY (ADIF defines no Canadian secondary subdivision) | built -- and STATE is now the WORKED station's in every party (Q76) |
| Q99 | Each class states its schedule (typed); New Contest list alphabetical, a check box orders by next date; start/end seeded | not built |
| Q35 | Idaho bonus: at least 10 QSOs (as built); all 25 table counties; one table per year, by the log's year | per-year table not built |
| Q52 | The New Contest drop-down shows each friendly name in full (sized at run time); reconsider if too wide | not built |
| Q53 | Names for the 43 unnamed contests: docs/Q53_CONTEST_NAMES.csv; MINITEST retired | built |
| Q67 | New Contest rows seeded from the station; the values at OK are the contest's own | not built |
| Q49 | BCQP: in-province DX contact earns no domestic mult (case-insensitive test) | not built |
| Q73 | QSO party: CALL/<valid county> is its own station for dupes (K1AR/NHHIL in NEQP) | not built |
| Q48 | YB DX: YB entrant counts all prefixes, others YB prefixes only -- already so (DXLog agrees) | no change |
| Q66 | A Contest Details dialog edits the contest's stored values (seeded station facts, Cabrillo fields); a station change mid-contest offers to copy it | not built |
| Q64 | POTA shows as "Parks on the Air(r) Logging" | as built |
| Q59 | Inactive contests listed grey and unselectable for a NEW contest; old logs still open and import | not built (confirm grey) |
| Q102 | SOUTHAMERICANWW retires (GACW WWSA is ref 45) | not built (needs Q10) |
| Q42 | OZCHR session names restored in Cyrillic, recovered from D7 `b90ba930` | built |
| Q43 | Sibling pairs follow DXLog: one definition file = one contest, a base with per-mode (or per-date) children | not built |
| Q45 | EUDX/IRTS "in the EU" reads the worked station's resolved region, not `DomMultQTH` | not built |
| Q55 | WRTC posts no DynamicResults XML; no multiplier row; amends Q83 | no change |
| Q80 | IN7QPNE in-area multipliers per party, after Q4 -- MOOT: Q104 keeps in-area stations out | moot |
| Q104 | IN7QPNE is refused for a station inside IN, the 7th area, New England or DE; the message names the party (7QP for the 7th area). `NEQP` = New England, `NE-QSO-PARTY` = Nebraska (TR4W has none) | not built |
| Q105 | New England is `NEWEQP` (Cabrillo `NEWE-QSO-PARTY`, ADIF `NEQP`), `NEQP` kept as a read alias; Nebraska QSO Party added as `NE-QSO-PARTY` | building |
| Q79 (LOCATION) | IN7QPNE requires no LOCATION; Cabrillo spec: section for W/VE, `DX` otherwise | no change |
| Q79 (VHF) | IN7QPNE bands = the union of the four parties; a QSO scores on its party's bands. New England 80-10, 7QP and Indiana 160-10, Delaware 160-10 + 6 m up -- each states its own | building |
| Q51 | An X-QSO never counts as worked: logged and exported only so the other station avoids a not-in-log penalty; no dupe, worked, mult or points mark | already so; the live path must share the predicate when Q98 lands |
| Q103 | New Contest list: search filter over a plain list, names only; no groups | not built |
| Q100 | `contest.last_opened_at` deleted (the last-contest button gives quick access); the button reads "Last Contest" | building |
| Q107 | QSO parties: an out-of-state entrant's QSO with a non-host station scores 0 and no mult (scoring applies the entry rule; one predicate) | building |
| Q108 | Contests register by string id like radios (no `VC.pas` line for a new contest); multi-op refused for a contest with no legacy number until the new protocol; `<contestnr>` open | design after the cleanup |
| Q109 | UDP `dynamicresults`: send the ALL row, per-mode totals, WRTC mults; never suppressed (WRTC's local aggregators read it -- also settles Q55) | built 2026-10-16 |
| Q52 note | Settled by Q52 | removed |

### Answered since the table was last updated (full text)

- **Q109** (found by the new end-to-end UDP tests, 2026-10-16) The N1MM-style
  UDP **score** message (`dynamicresults`, `SendScoreToUDP`) has four
  problems, ALL also in D7 4.151 (tag names and structure match D7):
  1. **No `<point>` rows are ever sent.** The mode loop runs `CW to Phone`
     (`{Both do}` is commented out), so the "ALL" mode row in the header's
     own sample XML is never written.
  2. **The `total` row is inflated when two modes are worked** -- a running
     sum is reused: CW 5 on 20 m + Phone 3 on 15 m gives `total CW` = 8 and
     `total PH` = 13 (should be 5 and 3). Single-mode contests come out right.
  3. **WRTC sends no `<mult>` rows** -- its labels exist only for the
     all-modes row that (1) never reaches.
  4. **No suppression:** the UDP score goes out for a contest that forbids
     score posting (WRTC) -- only HamScore and the menu ask the contest.
  The tests pin today's output, (2) as a named known-defect test, so each
  fix is a deliberate test edit. *Recommended: fix 1-3 (send the ALL row,
  per-mode totals, WRTC's mults follow from 1); for 4, ask the contest the
  same way HamScore does -- a local N1MM-style listener is arguably not
  "posting", so this one is your call.*
  **Answer:** (NY4I, 2026-10-16) *"q109 is ok except dynamicresults is
  perfectly fine for wrtc. That was its original purpose."* So: FIX 1-3
  (send the ALL row, per-mode totals, WRTC's mults) and do NOT suppress the
  UDP score for WRTC -- the UDP `dynamicresults` message is what WRTC's local
  aggregators read; that is what it was built for. This also settles Q55:
  WRTC's multipliers belong in THIS message (fix 3), and Q83's "WRTC posts
  neither" applies to the ONLINE scoreboard and HamScore, not to the local
  UDP broadcast. Not built.
  **BUILT 2026-10-16:** the mode loop runs `CW to Both` (the ALL rows -- qso,
  mult, point -- per band and `total`), each `total` row is its own mode's
  bands summed (`nModeTotal`), WRTC's HQ/country rows follow from the ALL row,
  and nothing suppresses the UDP score. Tests: `uTestUDPDatagrams`.

- **Q108** (NY4I, 2026-10-16) A new contest should not touch `VC.pas`:
  *"I prefer we have a registry similar to when we Add a new radio so the
  simple fact that the radio class exists allows the table for the drop-down
  to be built ... The goal is to minimize the things a new contest needs to
  touch beyond its data files (like a DOM, tests, and the class itself)."*
  Measured with `tr4w/build/PascalSource.psm1` (comments and strings
  excluded): `ContestType` has 188 members, named 3,499 times in tests
  (mostly the pin tables the self-contained cleanup removes), 194 times in
  the 188 contest classes (each its own), and only 70 times in 20 other
  files, nearly all one default member each. The enum's ORDINAL leaves the
  program in three places: the binary `.TRW` record (import-only history ->
  a frozen legacy table), the multi-op packet's `ContestExchange`, and the
  UDP/HamScore `<contestnr>` (N1MM's contact-broadcast format; any stable
  number groups a logger's contacts).
  Plan: a contest's identity becomes the string id it REGISTERS (today's
  `ContestTypeSA` spelling, already what every SQLite log stores); each class
  self-registers from its `initialization`, like `RegisterRadioById`; the
  New Contest list comes from the registry; existing contests keep their
  legacy number only where it leaves the program; a new contest has none.
  No RTTI needed -- the `.lpr` uses line (as for radios) is what links a class.
  Order: commit 5.0.28 -> the self-contained cleanup (counts, pins,
  installer) -> this design written into `CONTEST_OWNERSHIP_DESIGN.md` for
  NY4I's review -> build.
  **Decision 1 -- multi-op:** (NY4I, 2026-10-16) *"refuse multi-op for new
  contests until the new protocol."* A contest with no legacy number is
  refused for multi-op, with a clear message, until the row-based
  multi-station protocol replaces the packet.
  **Decision 2 -- `<contestnr>`:** the legacy number where a contest has one,
  a stable derived number otherwise, after confirming no consumer (HamScore,
  N1MM listeners) treats it as a global contest code -- taken under NY4I's
  go-ahead below.
  **Go-ahead:** (NY4I, 2026-10-16) *"I'm not sure we can separate q108 from
  our current work. We could end up with throw-away work otherwise so I
  would be ok proceeding with that."* The self-contained cleanup (counts,
  pin tables, installer wildcard) and this registry are ONE piece of work,
  built after the 5.0.28 commit; the design goes into
  `CONTEST_OWNERSHIP_DESIGN.md` as it is built, not ahead of it for review.
  **Progress (design 8.2u):** S1 committed (`3a375123`); S2 -- the one-byte
  `TContestHandle`, ids in the registry, legacy numbers unchanged -- built
  2026-10-16 with every oracle unchanged. S3 waits on NY4I's ruling on
  renaming the matrix files.

- **Q107** (found checking Nebraska's first matrix record, 2026-10-16) **"An
  out-of-state station works only the host state" is enforced only when a
  QSO is TYPED.** The entry refusal (M5b) stops it at the keyboard; scoring
  does not apply it. So a QSO that arrives any other way -- an ADIF import, a
  network peer, the matrix's injected records -- scores against the rule.
  Measured in the frozen matrix, the same injected QSOs for an out-of-state
  (Kansas) entrant: W1AW sending `CT` scores 2-3 points AND counts `CT` as a
  multiplier, and JA1ABC sending nothing scores 2-3 points -- in Idaho,
  Delaware, Florida and the new Nebraska alike. The sponsors say otherwise
  (Nebraska: an out-of-state station's multipliers are Nebraska counties,
  and "each out-of-state station must copy the NE county"; DXLog scores such
  a QSO invalid). Under Q13 a logged QSO is scored from its record by the
  contest's rules, so the rule belongs in SCORING too: an out-of-state
  entrant's QSO with a station that sent no host-state QTH scores 0 and
  earns no multiplier (logged, like an off-band QSO -- an X-QSO under Q98?).
  *Recommended: yes, once, in the QSO-party base, so every party gets it;
  the matrix records of every state party move and are re-frozen with that
  reason.*
  **Answer:** (NY4I, 2026-10-16) *"Q107 yes, go with your
  recommendation."* One predicate, asked by both the entry refusal and
  scoring, once in the QSO-party base; the multi-state parties checked one
  by one. Being built (contest-factory); every state party's matrix record
  moves and is re-frozen with this reason.

- **Q100** `contest.last_opened_at` is never written or read. The schema says
  it is "written every time the log is OPENED, and it is the chooser's default
  sort key: recent activity floats up" -- neither is true. Write it at open
  and sort the log chooser by it, or delete it? *Recommended: write it* --
  "the contest I was just working" first is the chooser's most useful order,
  and the comment states the intent.
  You answered (2026-10-16): *"The button for last contest file would get
  quick access to the last one."* That button exists: New Contest's
  "Latest config file" (Alt+A) reopens the one path `settings/tr4w.json`
  records at every start (`uProgramMain` -> `SetLatestConfigFile`), and is
  hidden, with a log line, when that file is gone. The path is the contest's
  `.db` now, not a `.cfg`.
  **Proposed answer:** the button IS "quick access to the last one", so
  nothing needs a per-database open time: **delete `contest.last_opened_at`**
  and the schema comment that promises a sort no chooser performs (log-
  database). And, found checking it: the button's caption says "Latest config
  file" and `uProgramMain`'s comment says it "names the contest .cfg" --
  both stale since a contest became its SQLite file. Rename the caption to
  "Last contest" (`TC_LATEST_CONFIG_FILE`, through the i18n catalogues, not a
  retyped `.lfm` string) and fix the comment.
  **Answer (caption half):** (NY4I, 2026-10-16) *"change that from Last
  config file to Last Contest"* -- the caption becomes **"Last Contest"**,
  through the catalogues (i18n). Being built. Still open: deleting
  `last_opened_at`.
  **Answer (column half):** (NY4I, 2026-10-16) *"yes, delete
  last_opened_at"*. Being built (log-database).

- **Q103** The New Contest list: group the QSO parties? (NY4I, 2026-10-16,
  with DXLog's grouped list -- highlighted, self-drawn headings -- and N1MM's
  Log Type then State.) His leaning: *"The N1MM shape seems good but with the
  addition of the search filter. One could make an argument that we could do
  what we have today but add the search then if I type QSO, I would see the
  QSO parties."* *Recommended: SEARCH ONLY, groups later if missed.* A filter
  box over a plain list (TEdit above a TListBox -- native, 15-20 rows visible,
  no owner-draw; a self-filtering drop-down fights the control). It matches
  the contest's NAME, case-insensitive, anywhere: "QSO" or "party" lists the
  parties (every party's name says "QSO Party"), and CW / RTTY / VHF / Sprint
  / Field Day become groups for free. Each row shows the name only -- NY4I,
  2026-10-16: "let's leave out the internal name. Besides it is not an N1MM
  clone..." Under it: "Show inactive contests" (Q59 -- a native list cannot
  grey one item, so inactive ones are hidden unless asked for, never lost) and
  "Order by next date" (Q99). An empty filter is today's alphabetical list.
  Groups would need all 187 classes to state one (no inherited default), so
  they wait until search proves short. Same dialog as Q52, Q59, Q99; lcl-ui.
  **Answer:** (NY4I, 2026-10-16) *"search"*. SEARCH ONLY, as recommended:
  a filter box over a plain list, matching the display name anywhere,
  case-insensitive; rows show the name only; "Show inactive contests" (Q59)
  and "Order by next date" (Q99) beneath; no groups unless search proves
  short. Built with Q52, Q59 and Q99 as one New Contest dialog change
  (lcl-ui). Not built.

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
  **Answer:** (NY4I, 2026-10-16) *"x-qso never counts as worked. It is
  simply so we do not leave it out of the log and potentially cause our QSO
  partner to receive a Not-in-log penalty."* Kept so, and the PURPOSE is now
  the rule: an X-QSO -- flagged by hand, or automatically off-band (Q98) --
  is in the log and the exports for the other station's sake, and is
  otherwise invisible: no dupe mark, no worked-there mark, no multiplier, no
  points, and a later QSO with the same station on that band is NOT a dupe.
  Checked 2026-10-16 that every path agrees today: the rescore skips a
  flagged X-QSO (`MainUnit.pas` ~8902, zero points, no dupe, not added to the
  sheets); a log's load adds only what `QSOCountsTowardTotals` admits, which
  excludes X-QSOs; the X flag is set only by ADIF import, the database read
  and Edit QSO. The live logging path (`logsubs2.pas` ~1728, `SetMultFlags` +
  `AddQSOToSheets`) has no X-QSO test because nothing is an X-QSO when it is
  first logged -- **when Q98's automatic off-band X-QSO is built, that path
  must ask the same `QSOCountsTowardTotals`**, not a copy of the test. No
  change now.

- **Q79** *Reworded 2026-10-16 -- what is still open.* LOCATION is settled by
  your answer (section 4): IN7QPNE requires none. Left: IN7QPNE has **no VHF**,
  while 7QP and Delaware accept 6 m and up -- so an out-of-area station's 6 m
  QSO with a 7QP or Delaware station is refused today. Turn VHF on (a QSO
  still scores only where its party allows)? The rest (one `dx` multiplier,
  FT8 written `DG`, no power multiplier, no +50 bonus) stays.
  *Recommended: VHF on; keep the rest.*
  **Answer:** (NY4I, 2026-10-16) *"NEWEQP is only 80-40-20-15-10m. 7QP is
  160, 80, 40, 20, 15 and 10m. We already know DE allows 6m and up in
  addition to HF. So this means that to answer the question, you look at the
  4 qso parties to see which bands are valid. And finally, INQP is 160, 80,
  40, 20, 15 and 10 meter."* **Correction:** the question said "7QP and
  Delaware accept 6 m and up" -- only Delaware does. So IN7QPNE's bands are
  the UNION of the four (160-10 without WARC, plus Delaware's 6 m and up),
  and each QSO scores only on its judging party's bands -- the routing
  `uContestIN7QPNE` already has. Checking it found three parties that state
  NO bands (so every band counted, WARC and VHF included): New England
  (should be 80-10, no 160), 7QP (160-10; its flags even enabled VHF bands),
  and Indiana (160-10). Each now states its own. Building.

- **Q105** New England vs Nebraska: names, and a Nebraska QSO Party.
  **Answer:** (NY4I, 2026-10-16) *"It will have a NE qso party as I do want to
  implement all qso parties eventually"*; *"dxlog uses NEWEQP and cabrillo
  name is NEWE-QSO-PARTY"*; *"go with your recommendation"*. Checked against
  ADIF 3.1.7 (NY4I's screenshot: `NE-QSO-PARTY` Nebraska, `NEQP` New England),
  WA7BNM (ref 10 New England: Cabrillo `NEQP`, alias `NEWE-QSO-PARTY`; ref 336
  Nebraska: `NE-QSO-PARTY`) and DXLog (`NEWEQP.txt` New England writes
  `NEWE-QSO-PARTY`; `NEQP.txt` is NEBRASKA and writes `NE-QSO-PARTY`):

  | | New England | Nebraska (new) |
  |---|---|---|
  | TR4W name (stored in every log) | `NEWEQP` | `NE-QSO-PARTY` |
  | old spelling still read | `NEQP`, permanently -- a read alias | -- |
  | Cabrillo | `NEWE-QSO-PARTY` | `NE-QSO-PARTY` |
  | ADIF | `NEQP` (ADIF enumeration) | `NE-QSO-PARTY` |

  **Why `NEQP` is not reused for Nebraska:** it is stored data. Every New
  England SQLite log holds it (`uLogRepository.SetContest`) and reopens
  through `TF.GetContestFromString`, and D7 `.cfg` files say `CONTEST = NEQP`;
  reassigning it would reopen them all as Nebraska, silently. The rule: a
  contest name ever written to a file is never given to another contest.

  Nebraska is built from the sponsor's 2026 rules (nebraskaqsoparty.com),
  with DXLog's `NEQP.txt` for the bonus calls and the 93 county
  abbreviations: digital 1, phone 2, CW 3; ONE power multiplier on the score
  (x5 all QRP, x2 under 100 W); geo multipliers once per contest (out of
  state: NE counties; in state: counties + states + provinces + countries);
  bonus 100 for KA0BOJ, 50 for each of K0SMM K0RPT K0NEB NF0N N0FER KE0XQ;
  160-10 m without WARC plus all VHF/UHF; county lines two counties. Where
  DXLog differs (6 m only; power per QSO) the sponsor wins. Building.

- **Q104** (raised 2026-10-16 by your Q40 answer) **IN7QPNE is for stations
  outside all four parties.** The 4QP page (stateqsoparty.com, "4QP Cabrillo
  log parsing"): *"If you are out-of-state for all contests this weekend,
  select the IN7QPNE option"*; an in-state station selects its own party.
  DXLog's `IN7QPNEDE.txt` agrees: *"4QP is the collection of INQP, 7QP, NEWEQP
  and DEQP for out-of-state stations"*, and its entry error says *"INQP, 7QP,
  NEWEQP, and DEQP in-state stations should use the respective QP."*
  So a New England rover logs **NEQP** (New England), never IN7QPNE, and New Contest needs
  no extra question -- the contest's MY STATE already names the party.
  Should New Contest refuse IN7QPNE when MY STATE is in Indiana, a 7th-area
  state (AZ ID MT NV OR UT WA WY), New England (CT MA ME NH RI VT) or
  Delaware, with a message naming that party?
  *Recommended: yes.* Consequence: your Q80 "yes" (in-area entrants'
  multipliers inside IN7QPNE) becomes moot -- no in-area entrant reaches it --
  and Q79 shrinks to what an out-of-area station needs.
  **Answer:** (NY4I, 2026-10-16), from the New England QSO Party's own
  page (its N1MM set-up note): *"Most stations from outside of New England
  should choose Log Type: QSOPARTY ... and choose IN7QPNE. Stations from
  Indiana, pick IN, from Delaware pick DE, and from the 7th Call Area, pick
  7QP"* -- *"it tells me that a station in one of the states should use
  their respective qso party. Note for 7th area, they would select 7QP and
  not their individual state qso parties like Utah or WA. Same for New
  England picking NEQP."* **YES:** New Contest refuses IN7QPNE when the
  contest's MY STATE is inside one of the four, and names the party to use:
  IN -> Indiana QSO Party; AZ ID MT NV OR UT WA WY -> **7QP** (never a
  single-state party such as Utah's or the Salmon Run); CT MA ME NH RI VT ->
  New England QSO Party; DE -> Delaware QSO Party. Q80 becomes moot. Not
  built.

  **New England vs Nebraska -- you asked how we tell them apart.** By the
  ADIF Contest-ID list (adif.org 3.1.6): **`NEQP` is the New England QSO
  Party** and **`NE-QSO-PARTY` is Nebraska**. TR4W's `NEWENGLANDQSO` writes
  `NEQP` to Cabrillo and ADIF (WA7BNM id 10), which is right, and TR4W has
  **no Nebraska QSO Party at all**. The trap is DXLog: its `NEQP.txt` is
  NEBRASKA and New England is `NEWEQP.txt` (`tools/dom-crosscheck` already
  carries that warning). The neqp.org rules quoted under Q40 are New
  England's -- first full weekend of May, 2000Z-0500Z and 1300Z-2400Z.

- **Q102** (split from Q53) SOUTHAMERICANWW vs GACW WWSA CW (WA7BNM ref 45):
  one contest or two?
  **Answer:** (NY4I, 2026-10-16) *"Retire"*. SOUTHAMERICANWW retires, like
  MINITEST; `GACWWWSACW` stays the ref-45 contest. Both retirements go
  through Q10's `TContestRetired` (awaiting your yes): an old log still opens
  and imports. Not built.

- **Q42** OZCHR: both session names were literal `?` characters. Restore the
  Cyrillic, or use Latin names?
  **Answer:** (NY4I, 2026-10-16) *"Restore Cyrillic."* **The text is
  recovered, not guessed:** D7's first commit (`C:\TR4W`, `b90ba930`,
  `tr4w/src/trdos/FCONTEST.PAS`) still holds the cp1251 bytes, so the loss
  came later. Decoded, and matching the `?` patterns letter for letter:
  - OZCR_Z (individual, "заочные" -- remote entrants):
    **Очно-заочный чемпионат России - заочные участники**
  - OZCR_O (teams, "очные" -- on-site entrants):
    **Очно-заочный чемпионат России - очные участники**

  The same commit also has a third, shorter name, `ОЗЧР - Очный тур`, used
  by a `CMD = 'OZCR'` arm. **Built 2026-10-17** (both names checked
  against `b90ba930` decoded as cp1251: OZCR_Z's arm at line 751, OZCR_O's
  at 1361). The session's name is written as `#$xxxx` code points, so the
  source stays ASCII and no build machine's codepage can mis-decode it
  (a non-ASCII literal in a BOM-less unit is read in the ANSI codepage --
  `Lint-BOM.ps1`). Where it reaches: the title bar, the summary sheet and
  the hour report (display); NOT the Cabrillo `CONTEST:` line, which is
  `CabrilloName` for both classes; and the EDI export's `TName`, which
  now writes the Cabrillo name in place of a non-ASCII session name
  (`PostUnit.EDIContestName` -- every other contest's session name is
  ASCII, so it writes what it wrote). No ADIF field carries it.
  Pinned by `uTestContestSession.Test_OZCHRSessionNamesAreCyrillic`,
  which compares every code point with the text decoded from its UTF-8
  bytes. The `OZCR` arm's third name was not asked for and is not used.

- **Q43** Which sibling pairs are one contest under one rule (a base with
  children)? First list: JIDX, All Asian, Oceania CW/SSB, the four EU
  Sprints, the three ARRL VHF runnings. Extended: King of Spain, REF and RSGB
  RoPoCo CW/SSB, and the Region 1 Field Day RCC CW/SSB runnings.
  **Answer:** (NY4I, 2026-10-16) first list *"Yes"*; extended: *"Region 1 is
  its own so I think these should be unique. If DXNet [DXLog.net] has unique
  ones, then we should as well."* So **DXLog decides**, one definition file
  for one contest. Read 2026-10-16 from `C:\Program Files (x86)\DXLog.net\Contest`:

  | pair | DXLog | so in TR4W |
  |---|---|---|
  | JIDX CW/SSB | `JIDXC.txt`, `MODES=CW;SSB` | one base, CW and SSB children |
  | All Asian CW/SSB | `AllAsian.txt`, `MODES=CW;SSB` | one base, two children |
  | Oceania CW/SSB | `OceaniaDX.txt`, `MODES=CW;SSB` | one base, two children |
  | the four EU Sprints | `EUSPRINT.txt`, `CABRILLO_CONTEST_NAME=EU-SPRINT-{MODE}` | one base, four children |
  | King of Spain CW/SSB | `HMKOS.txt`, `MODES=CW;SSB` | one base, two children |
  | REF CW/SSB | `REF.txt`, `MODES=CW;SSB` | one base, two children |
  | RSGB RoPoCo CW/SSB | `RSGB_RoLo.txt`, `MODES=CW;SSB` | one base, two children |
  | Region 1 FD, RCC CW/SSB | `RCCFD.txt`, `MODES=CW;SSB` -- separate from DXLog's national R1 FD files (`IARU1FD_DL`, `IARU1FD_RUS`) | its own contest (your "Region 1 is its own"); one base for its two runnings |
  | ARRL VHF Jan/Jun/Sep | three files, one per date | one base, three children (Q41 already gives all three June's set-up) |

  A child keeps its own name, ids and dates; only the shared rule moves up.
  If "unique" meant the R1 FD CW and SSB runnings should stay two separate
  classes, say so -- DXLog's single `RCCFD.txt` is why this reads them as one.
  Not built.

- **Q45** EUDX and IRTS test "is the worked station in the EU?" with
  `DomMultQTH[4] <> ''`, which can never be false. What should decide it?
  **Answer:** (NY4I, 2026-10-16) *"DomMultQTH is a catch-all left over from
  the D7 shared fields implementation. I would expect in the new
  implementation to use the discrete values."* So the test reads the worked
  station's own resolved EU region -- the domestic value his exchange matched
  in the contest's `.dom` -- and is false when he sent none (a non-EU
  station). Both contests' scores move (non-EU contacts stop scoring 10); the
  matrix rows for EUDX and IRTS are re-frozen with that reason. Not built.
  **Check when building (found 2026-10-16):** `eudx.dom` spells one Belgian
  region `BE011` where the raw code list it was built from (`eudx.dom.new`,
  deleted in `8b3d3e9a`, in git history) has `BE11` -- so a station sending
  BE11 may not match. Confirm against the sponsor's region list.

- **Q55** WRTC's live-score XML has never carried a multiplier.
  **Answer:** (NY4I, 2026-10-16) *"WRTC score posting is not done with the
  DynamicResults score summary the WRTC local aggregators use. Recall that
  WRTC is just for the competitors and IARU-HF is the contest non-WRTC event
  competitors use."* TR4W's online post IS the DynamicResults XML
  (`uGetScores.BuildDynamicResultsXml`), so WRTC does not post through it:
  **leave the XML; no multiplier row is needed.** This **amends Q83**: WRTC
  posts NEITHER online nor to HamScore -- which is what the build does today
  (one flag, `oaScorePosting`, off for WRTC). The split into two permissions
  still stands for other contests. No change.
  **CORRECTED by Q109 (NY4I, same day):** *"dynamicresults is perfectly fine
  for wrtc. That was its original purpose."* There are TWO dynamicresults
  builders and this entry conflated them: the ONLINE one
  (`uGetScores.BuildDynamicResultsXml`, scoreboard/HamScore -- WRTC posts
  neither, as above) and the local UDP one (`logsubs2.BuildScoreUDPXml`), which
  is what WRTC's local aggregators read. WRTC's multipliers DO belong in the
  UDP message -- Q109 fix 3 (built 2026-10-16).

- **Q80** IN7QPNE multipliers for in-area entrants per party, once Q4's
  piece exists?
  **Answer:** (NY4I, 2026-10-16) *"Yes per the recommendation."* **But see
  Q104**: the sponsor's page sends in-area stations to their own party, so if
  Q104 is yes this has no entrant to apply to. **Q104 is yes (same day), so
  this is moot.**

- **Q79 (LOCATION half)** IN7QPNE: no Cabrillo LOCATION required.
  **Answer:** (NY4I, 2026-10-16), quoting the Cabrillo specification:
  *"LOCATION: Used to indicate the location where the station was operating
  from. ARRL/RAC Sections: For USA and Canada stations LOCATION must be the
  ARRL section abbreviation. For foreign stations LOCATION must be 'DX'. This
  information is required for IARU-HF and for all ARRL and CQ contests. IOTA
  Island Name: required for RSGB-IOTA ... RDA Number: required for RDXC. For
  others, like DX, I checked the public logs for dx stations from here:
  Location: DX."* So IN7QPNE keeps "not required" (no change). It also fixes
  **Q74's seed value**: a US or Canadian station's LOCATION is its ARRL
  section, any other station's is `DX`. A contest whose sponsor asks for
  LOCATION (Delaware does) still requires it. The VHF half of Q79 is still
  open (section 1).

- **Q52 note** (does the drop-down still need Q52's wording?)
  **Answer:** (NY4I, 2026-10-16) *"This seems like it was answered."* Yes --
  Q52 (the friendly name in full, sized at run time). Note removed.

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
  **Answer:** (NY4I, 2026-10-16) *"yes"* -- as proposed: the New Contest rows
  start with the station's values (the seed), and whatever a row holds at OK
  is the CONTEST's value, stored in its database; a later Preferences change
  does not reach an existing contest (Q66 adds the Contest Details dialog to
  edit it, and the offer to copy a station change in). Not built.

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
  **Answer:** (NY4I, 2026-10-16) *"yes"* -- as proposed: compared ignoring
  case (Q84), BC's rule fires, so an in-province BC station's DX contact earns
  no domestic multiplier, as New York and Indiana. A scoring change for in-
  province BC logs with DX QSOs. Not built.

- **Q53** Forty-seven contests have no friendly name, so their display name is
  still the internal spelling -- `ALRS-UA1DZ-CUP`, `RF-CUP-CW`, `UKEI`,
  `YOUTHCHAMPIONSHIPRF` and the rest
  (`uTestContestDisplay.ENUM_SPELLED_DISPLAY_NAMES`). Human names for them,
  please; any you give leave that list.
  *Cross-walked 2026-10-15 (NY4I: "the wa7bnm link should be embedded for
  cross-walking"): the TR4W website lists a contest by a WA7BNM-linked name
  only when its class has a WA7BNM ref, and all 49 here return 0. Research
  table: `docs/Q53_WA7BNM_CROSSWALK.md`. WA7BNM's full database (719 contests,
  active and inactive) lists 21 of the 49 -- each gets its ref and WA7BNM's
  name as its friendly name; 28 are not listed at all (mostly Russian and
  Danish contests), and those need names from you or another source.
  EUSPRINT_SPRING_CW already has ref 317 and only lacks a name.*
  **Answer:** (NY4I, 2026-10-16) given in `docs/Q53_CONTEST_NAMES.csv` (43
  rows; the six already decided are left out): 15 WA7BNM names with refs
  accepted; All JA Contest; DXLog names for seven, the three Russian ones in
  English (Russian Cup Contest, CW / SSB; Udmurtia Open Championship);
  "European VHF"; MINITEST RETIRED as a duplicate of MINI80; the 17 with no
  name found keep their internal name, stated in each class. The CSV's
  decision column says where each came from. SOUTHAMERICANWW is split out as
  Q102. **Built 2026-10-17:** the 24 named contests state the name as
  their display AND friendly name, and the 14 accepted WA7BNM refs that
  were not yet stated (EUSPRINT_SPRING_CW already had 317); they left
  `ENUM_SPELLED_DISPLAY_NAMES`, and `uTestContestIdentityPin`'s rows were
  changed by hand. The 17 with no name already stated their internal
  name and are unchanged. MINITEST's retirement waits on Q10 and is not
  built; SOUTHAMERICANWW is Q102.

- **Q73** "A DE mobile that changes county is a new station." TR4W's dupe
  check uses the call, band and mode, and no contest can change that today.
  So a mobile's second county shows as a dupe unless worked as a county
  line. The sponsor's page confirms the rule: "Delaware Mobiles that change
  counties are considered new stations, and can be worked for both
  multiplier and QSO Point credit."
  Add a way for a QSO party to put the county into the dupe check, or
  leave it to the operator? *Recommended: add it, as its own step, for every
  state party with mobiles.*
  **Answer:** (NY4I, 2026-10-16) *"yes NY4I/PIN in FQP should be considered a
  different station than NY4I/HIL. This is a QSO party idea only where the
  characters after the slash have to be a valid county. Note in the NEQP (or
  IN7QPNE) that could be K1AR/NHHIL."* So yes, as its own step: in a QSO
  party, a /suffix that is a valid county of THAT contest (its .dom spelling
  -- NHHIL in NEQP and IN7QPNE, PIN in FQP) makes CALL/county a separate
  station for the dupe check, so a mobile that changes county is workable
  again. A suffix that is not a valid county keeps today's rule (it is not a
  rover suffix). Same validity test as the rover county (issue #87). Not
  built.

- **Q48** YB DX: the program had a rule "for an Indonesian entrant, set the
  prefix multiplier again" that set exactly the value it already had -- it did
  nothing, here and in D7. It is deleted (nothing moved). What was it meant to
  do -- does an Indonesian entrant count a different multiplier (prefixes
  rather than districts?) in the sponsor's rules?
  **Answer:** (NY4I, 2026-10-16) WA7BNM's page (ref 621) says nothing on
  prefixes and the sponsor's site was down. DXLog's YBDXSSB.txt settles it:
  "YB WPX prefixes are multipliers for non-YB stations. All WPX prefixes are
  multipliers for YB stations", plus DXCC for all, per band. That is exactly
  what TR4W already does: `IndonesianDistrict` (uPrefixMultiplierKey.pas:126)
  keys the prefix when EITHER the worked station or the entrant is Indonesian,
  and the class counts per band (cfMultByBand). The deleted rule was redundant
  -- what it was for is already done. Points match DXLog too. No change.

- **Q66** Preferences shows and edits the station's value. If this contest
  overrides that field (zone 3 in Utah), an edit there changes the station
  but not this contest, and nothing on the page says so. Should the Station
  page show the contest's value beside the field, with a way to clear it?
  *Recommended: yes, a hint that names the contest's value.* This is
  `lcl-ui` work.
  **Answer:** (NY4I, 2026-10-16) *"the idea is we need a way to edit the
  contest details. So while the station info is used as a seed value for a new
  contest, we should allow an edit dialog to edit the contest. That could also
  be the place we edit cabrillo fields today. The zone 3 in Utah for NY4I/7
  would be edited in this dialog. ... if I change the station info during a
  live contest, we should advise this info will not update the contest (or
  maybe we offer the opportunity to do so)?"* So: a CONTEST DETAILS dialog
  edits the values the contest stores -- the seeded station facts (zone,
  state, section, grid ...) and the Cabrillo header fields (Q61's categories)
  -- in the contest database; the station page keeps editing the station.
  Changing a station value while a contest is open says the contest keeps its
  own value, and offers to copy the new value into it (recommended: offer,
  never silently). This replaces the "hint beside the field" proposal. Its
  storage half is Q61 and the declaration fix found by the column audit. lcl-
  ui + log-database. Not built.

- **Q64** The New Contest drop-down now lists POTA as "Parks on the Air(r)
  Logging" (its friendly name -- every contest class shows its human name,
  your M9a ruling) where it used to say "POTA". Keep that, or should POTA's
  line stay "POTA"?
  **Answer:** (NY4I, 2026-10-16) *"I like the Parks on the Air with the
  trademark as you suggested."* Kept: POTA's line is its friendly name, "Parks
  on the Air(r) Logging". No change.

- **Q59** Inactive contests: SA Sprint and Locust are marked inactive and
  listed last, as you said. Any others? (A contest marked inactive still
  opens and scores an old log; it only moves to the bottom of the list.)
  *Partly answered in F26 (2026-10-15): MARAC, Ten-Ten, FISTS and QCWA are
  inactive; FISTS, QCWA Golden, WWL, XMAS and Locust retire. Any others?*
  **Answer:** (NY4I, 2026-10-16) *"Should inactive contests be in gray in the
  drop-down so they cannot be selected? ... I see no reason anyone would ever
  select it. It allows a transition period to see our port did not simply
  forget them."* Recommendation, for his yes: GREY AND NOT SELECTABLE in the
  New Contest drop-down, still listed (so the port visibly kept them) -- but
  an existing log of an inactive contest still OPENS, rescores and exports,
  and its ADIF still imports, because those are old logs, not new contests. No
  others named inactive. lcl-ui. Not built.

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
  **Answer:** (NY4I, 2026-10-16) *"Let's use the full friendly name in the
  drop-down. If it gets too wide, we can reconsider."* The drop-down already
  shows the friendly name (M9b); what it does not do is show it WHOLE.
  `cboContest` (`uNewContestForm.lfm:96`) is 200 px at design time, stretched
  by its anchors to the panel, and the list opens at the combo's width, so
  long names are clipped. Measured across the 187 pinned friendly names: most
  fit in 38 characters ("RSGB International Sprint Contest, SSB", "Yuri
  Gagarin International DX Contest", "World Radiosport Team Championship");
  one outlier is 67, the IN7QPNE composite ("Combined Indiana, 7th Call Area,
  New England and Delaware QSO Party") -- the "too wide" case to reconsider if
  it is. So: the list must show each name in full, sized from the names at run
  time rather than a hard-coded width (lcl-ui). Not built.

- **Q35** Idaho dormant-county threshold: the rovers page says "makes 10 valid
  QSO's", the rules page "MORE THAN 10 contacts". 10 is implemented. The rovers
  page also says "only counties listed in RED are eligible", but the table has
  blue 500-point and red 1000-point counties; all are paid today. Which reading
  is the sponsor's?
  **Partly answered (NY4I, 2026-10-16):** *"Perhaps. This is an annual update
  as the rare counties change each year"*, with the sponsor's "2027 Bonus"
  table (25 counties, 500 or 1000). It matches the class's
  `IdahoBonusCounties` row for row. **RED settled:** re-read 2026-10-16, "Only
  counties listed in RED are eligible" refers to the MAP (idahomap2027.jpg);
  the table is the bonus list, so all 25 are paid, as today. **Still open: the
  threshold** -- the rovers page says "makes 10 valid QSO's", the rules page
  "MORE THAN 10"; 10 stays until the sponsor says otherwise. **New, from
  "annual update":** a table that changes every year cannot be one constant,
  or rescoring a 2026 log after the 2027 update pays the wrong counties.
  Proposal: the class keeps one table PER YEAR and picks it by the contest's
  own year (the QSO dates), so an old log keeps its year's bonus -- "a logged
  QSO reads its record". Adding a year is one new table, with a pin test that
  the current year has one.
  **Answer:** (NY4I, 2026-10-16) *"it is at least 10 qsos."* So the bonus
  needs 10 or more valid QSOs from the county -- exactly what the class does
  (`validQSOs >= IdahoBonusMinimumQSOs`, 10). No change there. All 25 table
  counties are paid (RED is the map). Still to build: one bonus table per
  year, chosen by the log's year, above.
  **Where (NY4I, same day):** *"In the contest class? That would not be
  terrible."* Yes -- in TContestIdahoQP, beside today's IdahoBonusCounties:
  one typed table per year, a lookup by the log's contest year that REPORTS a
  year with no table rather than paying nothing, and a pin test that fails
  when the current year has none (the yearly reminder). Not a data file: the
  class owns its scoring, and a typed table is checked before release.
  **An old contest (NY4I, same day):** *"you have to handle reviewing an old
  contest as you need to know which list of counties to use."* The year comes
  from the LOG, never today's clock, so a 2026 log opened in 2029 still pays
  the 2026 list; a log whose year has no table says so (no silent zero). NY4I:
  *"That does imply that in the contest database file, we do log the original
  start date of the contest."* Measured: the `contest` table HAS `start_time`
  and `end_time` columns, and NOTHING writes or reads them. Q99(b) seeds them
  at New Contest time; the lookup reads `start_time`, and for an older log
  where it is empty, the first QSO's date. **Which year the current table
  is:** the sponsor heads it "2027 Bonus", but the Wayback capture of
  2026-05-11 -- four months BEFORE the 2026 contest -- shows the identical
  table under the same heading (captures of 2026-03-15 and 2026-04-12 show the
  page with no table). So it is the list that was in force for the 2026
  contest, whatever the label says; an earlier claim here that TR4W pays 2026
  logs the wrong list is WITHDRAWN. Which contest years it covers (2026 only,
  or 2026 and 2027) is the sponsor's to say.

- **Q99** **A contest states when it runs** (raised by NY4I with Q15,
  2026-10-16: *"we should be storing the times and relative dates of the
  contest like the contest factory in TR4QT does"*). TR4W stores none today.
  TR4QT's `ContestMetadata` holds a month plus a rule STRING ("2nd Saturday",
  "Last full weekend") parsed at run time, and no time of day; it uses the
  date only to list upcoming contests first, and never refuses a contest
  outside it.
  **Recommendation:** each class states one or more occurrences, TYPED rather
  than parsed: month; anchor (Nth weekday, Nth full weekend, last full
  weekend, or a fixed date); the start day within it; start UTC; duration. A
  misspelt rule string yields no date and no error; a typed one does not
  compile. Worked example, NRAU-Baltic SSB: January, 2nd full weekend, Sunday,
  0600 UTC, 2 h (CW: the same at 0830 UTC). No inherited default (Q51's rule):
  a class with no regular date (General QSO, POTA) says so explicitly, and a
  pin test fails a class that states nothing.
  **Uses, in order:** (a) the New Contest drop-down lists upcoming contests
  first, as TR4QT does; (b) a new contest's start and end are seeded into its
  SQLite file from the next occurrence. Later, and only on your word: (c) flag
  a QSO logged outside the period. Like TR4QT, a contest always opens on any
  date. Sources: the sponsor's rules, then WA7BNM (which lists dates for every
  contest it carries, so a tool can propose each class's rule for checking by
  hand). Accept (a) and (b)?
  **Answer:** (NY4I, 2026-10-16) *"Proceed with your recommendation. The idea
  is when we present the new contest dialog, we can default to alphabetical
  list of contests or a check to offer them in date order so the next contest
  per the calendar are displayed first. That is what TR4QT was doing."*
  Accepted as recommended: each class states its occurrences, typed (month,
  anchor, start day, start UTC, duration), with no inherited default. Use (a),
  refined: the New Contest drop-down stays ALPHABETICAL by default, and a
  check box beside it re-orders by the next occurrence from today, so the
  coming contests are listed first. Use (b): a new contest's start and end are
  seeded from the next occurrence. Use (c), flagging out-of-period QSOs, is
  not asked for. Not built; the bulk of it is data (a schedule per class, from
  the sponsors, WA7BNM as the cross-check).

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
  **Answer:** (NY4I, 2026-10-16) *"so yes"*, citing the ADIF specification:
  `STATE` is "the code for the contacted station's Primary Administrative
  Subdivision (e.g. US State, JA Island, VE Province)". So BCQP exports
  `STATE:BC`. **The county half does NOT follow**: ADIF's `CNTY` is an
  enumeration (Secondary Administrative Subdivision, ADIF 3.1.6 III.B.22)
  defined only for Alaska, Hawaii, the USA, the Russian entities, Ukraine,
  Japan, New Zealand and Spain -- nothing for Canada (DXCC 1). A BC regional
  district written as `CNTY` would be a value the spec does not allow, so BCQP
  writes no `CNTY`; the district still goes to the sponsor in the Cabrillo
  exchange. Not built.

- **Q34** Idaho rovers earn the dormant-county bonus per county they activate, but
  no QSO records the county it was sent from. Add a per-QSO "my county" (log
  field, entry, ADIF `MY_CNTY`), or keep scoring a rover as a fixed station in its
  MY STATE county?
  **Proposed answer:** SETTLED BY the Q13 audit (finding C) and the MY_CNTY
  ruling (Q19): yes, a per-QSO "my county". The log already has `my_county`
  (and `my_state`, `my_grid`) per QSO for exactly this and nothing writes
  them; a rover's QSO records the county it was sent from, ADIF exports it as
  `MY_CNTY`, and the dormant-county bonus counts from it.
  **Answer:** (NY4I, 2026-10-16) *"We really do not have a mechanism for
  rovers to change their county mid-contest in qso parties. If we did, then
  that would drive this answer ... We could sketch that out for future
  implementation if it answers this and handles it for other contests."*
  Searched D7 and this tree for "rover" (case-insensitive): every hit handles
  WORKING a rover (the `CALL/CTY` suffix, VHF `/R`), none BEING one. No `MY
  COUNTY` setting exists; the per-QSO `my_county` / `my_grid` / `my_state`
  columns exist and nothing writes them; the `\`-command hook
  `logsubs2.ProcessCallWindowCommand` has no caller. So the answer is the
  proposal, deferred: a per-QSO "my county" (and grid), written at logging
  time, set mid-contest by a call-window command such as `\COUNTY BNV` or
  `\GRID EM10`; the contest class decides what a move means (Idaho's dormant-
  county bonus counts distinct `my_county`; a party's rover dupe rule; VHF
  rover grids); ADIF writes `MY_CNTY` / `MY_GRIDSQUARE` per QSO. Sketch and
  open points: issue #87 (https://github.com/TR4W/TR4W-D12/issues/87). Until
  then Idaho scores a rover as a fixed station. Not built.
  **Follow-up (NY4I, same day):** *"There is a UDP command for example that
  goes in the callwindow, that should be processed in same case statement."*
  Right -- the call window's live commands are
  `MainUnit.CheckCommandInCallsignWindow` (ADIF, CAB, UDP, SCORE, PREF and ten
  more), whose `case` arms are numbered by POSITION in the word list;
  `TXON`/`TXOFF` sit in a separate `if` chain; the `\RADIO` procedure is dead.
  Step 0 of issue #87: one command table keyed by NAME, holding all of them,
  so the rover's `COUNTY`/`GRID` is one more entry. Open: an argument needs a
  separator the call window keeps, since the space bar is already a dupe
  check.
  **Decided (NY4I, same day):** typing ROVER in the call window opens a dialog
  listing THIS contest's counties from its .dom; typing filters, Enter picks
  -- so only a valid county can be chosen and nothing is parsed (NY4I: "I am
  not thrilled with finicky parsers"; ROVER=BNV, briefly agreed, is dropped).
  The current county shows in a new status element beside WK. All call-window
  commands move into one name -> handler table, guarded by unit tests and a
  lint. Detail: issue #87.
  **County line (NY4I, same day):** the dialog is a check-box list -- up to
  the contest's own CountyLineCountiesMax (California states 4; NY4I: "CAQP
  allows 4 for example"), so a county-line rover checks several. Each QSO
  stores every county it was sent from.

- **Q54** HamScore's one-QSO Cabrillo line writes Winter Field Day's FM
  contacts as `FM`; the Cabrillo file writes `PH`. Should HamScore ask the
  contest too? *Recommended: yes* -- one rule for both; it changes what
  HamScore receives for WFD FM QSOs.
  **Proposed answer:** SETTLED BY Q52's ruling (the Cabrillo form is the
  contest class's own definition): HamScore's one-QSO Cabrillo line asks the
  contest, as the file does, so WFD FM goes as `PH` in both.
  **Answer:** (NY4I, 2026-10-16) *"FM is a valid Cabrillo mode
  (https://wwrof.org/cabrillo/cabrillo-qso-data/). The WFD rules also state:
  The mode should be one of the valid Cabrillo modes. CW, PH, FM, RY, DG. It
  is preferred that you use RY or DG. So I am not sure what is in doubt."*
  What was in doubt was which of the two spellings is right, and the proposal
  picked the wrong one. So the PROPOSED ANSWER IS REVERSED: Winter Field Day
  writes an FM contact as `FM`, in the Cabrillo file and in HamScore alike.
  The class's `CabrilloModeString` override (FM written as PH, carried from
  D7's PostUnit) is deleted, so WFD takes the base's spelling. Scoring is
  untouched: an FM contact still scores as phone (1 point) -- that is the
  points rule, not the mode column. HamScore already writes `FM`, so the two
  agree once the override goes; it should still ask the contest's
  `CabrilloModeString` rather than keep its own map, so they cannot drift
  again. Corpus: `winter_fd_2025_w4ta` holds one FM QSO, so its `ref.cbr`
  (D7-produced, never regenerated) will differ on that one line; it becomes a
  recorded known divergence citing this answer. Not built.

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
  **Answer:** (NY4I, 2026-10-16) *"Yes."* As proposed: ASSISTED, BAND, MODE
  and OPERATOR are one value each, set at New Contest time and stored in the
  contest database, which the summary window edits and a headless export
  reads. Not built.
  **Found by the database column audit (2026-10-16), both confirmed by reading
  the code -- neither has been run:** (1) the declaration is written on EVERY
  open, not once: `uLogStore.pas:1025` calls `SetEntryDeclaration`
  unconditionally, against its own "READ ONCE, WHEN THE LOG IS MADE" comment
  (~415). Harmless only because nothing reads the columns back yet; the moment
  Q61 reads them, every open would overwrite the operator's edits with the
  live settings. It moves under the new-log branch as part of Q61. (2)
  `qso.exchange_sent` is NULLed by every update: it is in
  `QSO_COLUMNS_UPDATABLE`, `BindUpdate` binds it from
  `FSentExchangeForNextSave`, and that is cleared after every save
  (`uLogRepository.pas:1926`) and set again only by the live save and the
  rebuild path -- so Edit QSO, the rescore and a network update each erase it.
  Also latent (nothing reads the column). Fix: take it out of the updatable
  list, as `qso_set_id` already was for the same reason, with a pin that an
  edit keeps it.

- **Q22** PACC: the row says `RSTAndQSONumberOrDomesticQTHExchange`, but every PACC
  session runs `RSTDomesticQTHExchange`. Which is the contest's exchange?
  **Answer:** (NY4I, 2026-10-16, with the PACC 2026 rules,
  https://veron.nl/wp-content/uploads/2025/12/PACC_2026_rules_eng.pdf) *"I
  believe the OR in RSTAndQSONumberOrDomesticQTHExchange is because Dutch
  stations send signal report (59) and two-letter province code BUT non-Dutch
  stations send signal report and a serial number."* Confirmed by rule 6 (non-
  PA: RST + serial from 001; PA: RST + one of 12 province codes) and rule 7.1
  (a foreign station scores only PA contacts; a PA station works everyone, PA
  included). So both exchanges are right, one per station, and the class
  already chooses them so: a PA entrant receives either (the row's OR
  exchange), anyone else receives RST + province (`RSTDomesticQTHExchange`).
  The question's "every session" was the contest matrix, which has no PA
  station. **Defect found:** the class's Cabrillo and ADIF sent column writes
  OUR SERIAL at every station. D7 did that only in the
  `RSTDomesticQTHExchange` arm (non-PA); a PA entrant took the OR-exchange arm
  and sent RST + its province (D7 `PostUnit.PAS:3372`,
  `uCabrilloExchange.pas:474`). So a Dutch entrant's log today carries a
  serial where the province belongs. Fix: the sent column chooses by station
  as `DescribeSession` does, with a PA variant added to the pins. **Built
  2026-10-16:** `TContestPACC.IsDutchEntrant` (the one station test) chooses
  the sent column; the PA rows of `uTestCabrilloColumns` and
  `uTestADIFSentExchange` pin province, or serial when MY STATE is empty.

- **Q16** Sprint SSB is its own contest, but its ADIF/Cabrillo name is
  `NA-SPRINT-SSB` and its friendly name "North American Sprint, SSB". Change to the
  sponsor's name (https://ssbsprint.com/rules/)? Its multipliers come from the
  `naqp` file with no DXCC, unlike the NA Sprints' North American DXCC. Intended?
  *Partly settled: the Cabrillo name is the class's own definition (Q52), by
  the name rule (D7's, else the enumeration), so `NA-SPRINT-SSB` stays unless
  the sponsor's page or its public logs say otherwise; the friendly name is
  Q52/Q53's. The multiplier half goes to the DXLog cross-check.*
  **Answer:** (NY4I, 2026-10-16) *"Yes that website and name appears
  correct."* The display and friendly name become the sponsor's, "North
  American SSB Sprint" (the heading of https://ssbsprint.com/rules/). The
  Cabrillo and ADIF name stays `NA-SPRINT-SSB`: WA7BNM (ref 242) gives that
  Cabrillo name, the ADIF enumeration lists it, and the sponsor names none.
  **Multipliers:** the sponsor's rule 10 settles the second half -- each US
  state and DC (KL7 and KH6 count as states), each Canadian province or
  territory, AND each North American country other than W and VE ("North
  American" by the CQ WW list). TR4W counts no countries (`NoDXMults`), so it
  undercounts; the class gets the North American DX multiplier the NA Sprint
  CW class already has. The sponsor counts 13 Canadian multipliers with NT and
  NU separate, and `naqp.dom` joins them as one (12): that is Q88's file
  question, which now covers the SSB Sprint too. **Built 2026-10-16:** the
  names, and the class's own `HasDXMultiplier` / `DXMultiplierKey` (North
  America but K, VE, KL and KH6; once per contest -- no `cfMultByBand`).

- **Q15** NRAU-Baltic: the contest calendar lists Cabrillo names `NRAU-CW` /
  `NRAU-SSB`; TR4W sends `NRAU-BALTIC-CW` / `NRAU-BALTIC-SSB`. Which is right?
  *Now answerable from the sources: the Cabrillo spec's contest list and the
  sponsor's public logs say which name is current.*
  **Answer:** (NY4I, 2026-10-16) *"Use the name from WA7BNM if it conflicts
  with what TR4W has currently. So it should be NRAU-SSB for the SSB
  contest."* So the Cabrillo `CONTEST:` names become WA7BNM's: `NRAU-SSB` (ref
  222) and, by the same rule, `NRAU-CW` (ref 220). The ADIF Contest_ID stays
  `NRAU-BALTIC-CW` / `NRAU-BALTIC-SSB`: those are the ADIF 3.1.6 enumeration's
  names, and ADIF import matches them. The friendly names already match
  WA7BNM's. TR4W has no Cabrillo import, so no older log is orphaned by the
  rename. **Times**, from the sponsor text NY4I pasted: the Sunday of the 2nd
  full weekend of January, SSB 0600-0800 UTC and CW 0830-1030 UTC, two
  separate contests (the sponsor also lists combined CW+SSB results, which
  needs no third class). WA7BNM's page contradicts itself (0630-0830 and
  0900-1100 for 2027 onward), so the sponsor's times stand. How a class stores
  its schedule is Q99. **Names built 2026-10-16.**

- **Q58** WRTC's row gives it IARU's friendly name, "IARU HF World
  Championship", so the two were identical lines in the drop-down. They now
  read "IARU HF World Championship [IARU-HF]" and "... [WRTC]" (the token in
  brackets, only where a name is shared). A name of WRTC's own, please -- it
  also becomes its friendly name, which the summary sheet's `CONTEST:` line
  and the log database show.
  **Answer:** (NY4I, 2026-10-16) *"World Radiosport Team Championship."*
  Built: it is WRTC's display and friendly name, so the drop-down shows it
  bare and IARU HF bare -- no two contests share a display name now, and the
  bracketed-token rule stays only for a future pair. The summary sheet's
  CONTEST: line adds the new name in parentheses after the contest name.
  Unchanged: Cabrillo and ADIF name WRTC, WA7BNM ref 67 (the IARU HF event it
  runs inside), domestic file iaruhq.

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
  **Band half ANSWERED (NY4I, 2026-10-15):** *"a 1.8 MHz contest like this
  (and ARRL-160 or CQ-160) would only allow points for 160."* So RSGB 1.8 MHz,
  ARRL 160 and the CQ 160 CW and SSB runnings each list 160 m as their only
  band (Q98's rule); a QSO on any other band scores 0 and is an automatic
  X-QSO. Today none of the four states a band. Not built. Still open below:
  the UA4W prompt's wording.
  **Answer:** (NY4I, 2026-10-15) *"Da."* The UA4W prompt uses the translated
  `TC_ENTERYOURRDAIDORGRID` as it stands ("for Russian stations"), replacing
  the fixed English text. Bands: 160 m only, above. Not built.

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
  gains one. **Built 2026-10-17:** the Cabrillo names were already
  right; June and September now name their sessions `ARRL-VHF-JUN` and
  `ARRL-VHF-SEP`, and January gained June's `DescribeSession` (6 m, HF
  bands off) -- its session name was already `ARRL-VHF-JAN`, the default.
  January's matrix record is now June's line for line but for the ids.
  Pinned by `uTestContestSession.Test_EveryARRLVHFRunningHasJunesSetUpAndItsOwnName`.

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
  **Built 2026-10-17:** WA7BNM 240, and `qsoparty@gmail.com` -- the
  sponsor's rules page (fsarc.org, `qsoparty/rules-2024.html`) says
  "qsoparty at google's mail system", and WA7BNM's ref 240 page
  writes `qsoparty[at]gmail[dot]com`; both read that day.

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
