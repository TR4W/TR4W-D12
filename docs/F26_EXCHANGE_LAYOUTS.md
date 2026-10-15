# F26: export layouts for the fifteen contests with no exchange layout

**Status: PROPOSAL, nothing built.** Research for NY4I's approval, 2026-10-14;
**re-sourced 2026-10-15** under NY4I's rule for where contest facts come from.
Plan item F26 is in `docs/CONTEST_FACTORY_M11_PLAN.md`.

## Questions for NY4I (rules not settled by the Cabrillo spec or WA7BNM)

These are the facts the two accepted sources do not settle. Each one is a contest
rule NY4I checks himself. The question numbers are referred to as **Q-F26-n** below.

1. **ALL JA**: Neither the Cabrillo spec nor WA7BNM lists JARL ALL JA. From JARL's
   rules, please confirm: (a) the exchange is RS(T) + prefecture/district number +
   one power letter; (b) the letters are H (>100 W), M (>10-100 W), L (>5-10 W),
   P (5 W or less); (c) points per QSO and multipliers; (d) whether JARL accepts a
   Cabrillo log body, and with what CONTEST: value.
2. **JALONGPREFECT**: Is this class JARL All Cities All Guns (ACAG)? Neither source
   lists ACAG either. If it is, please confirm the exchange (RS(T) + city/gun/ku
   code + power letter), the scoring, and the log format.
3. **ARCI**: Which QRP ARCI events should the class cover? Its WA7BNM id is 0.
   WA7BNM lists six active ARCI events: Spring QSO Party (ref 315), Fall QSO Party
   (168), Hootowl Sprint (31), Summer Homebrew Sprint (69), Topband Sprint (193) and
   Holiday Homebrew Sprint (198). Which ref should `GetWA7BNMId` return?
4. **ARCI**: Does the qrpcontest.com upload accept a Cabrillo file, and with what
   CONTEST: value? The WA7BNM-referred rules say only "submit your entry online".
   WA7BNM's Cabrillo name list has no ARCI entry.
5. **COUNTYHUNTER**: Which MARAC event is the target? WA7BNM lists two, both now
   marked Inactive:
   - the **MARAC US Counties QSO Party** (ref 3), last held 26-27 July 2025;
   - the **MARAC SSB QSO Party** (ref 20), last held 2010.
   The earlier pass's 1 / 15 / 5 scoring is ref 20's, not ref 3's.
6. **COUNTYHUNTER**: The rules link WA7BNM gives (`marac.org/contests.htm`) is dead:
   marac.org answers 403/404 and its home page has no contest rules. From MARAC's
   current rules, please give:
   (a) the points for a QSO with a **portable** station (ref 3 lists a Portable
   class but no points for working one);
   (b) the points a **DX** entrant scores (ref 3 gives only "US: 2 points per QSO
   with DX station");
   (c) whether a mobile on a county line scores, and counts as a multiplier, once
   per county;
   (d) whether the multiplier is US counties only, once per mode (ref 3), or once
   per contest (ref 20), and whether states or DX count;
   (e) any bonus points (ref 20 says "see rules").
7. **COUNTYHUNTER**: Is the log Cabrillo? If so, what CONTEST: value? WA7BNM's
   Cabrillo name list has no MARAC entry. WA7BNM gives the email address
   contest-logs@marac.org and no format.
8. **COUNTYHUNTER**: What is the dupe rule: once per band per mode (ref 3), or once
   per county per band (ref 20)?
9. **FISTS**: Retire the class? WA7BNM ref 251 is Inactive, last held 8 Feb 2020,
   and the sponsor page it links says the sprints will not continue in 2026.
10. **GRIDLOC**: Retire the class? Neither source lists it. The only evidence that it
    ended in 1996 is a mailing-list archive, which is not an accepted source.
11. **NZFIELDDAY (JW-FD)**: Neither source lists the Jock White Memorial Field Day
    (the class header already records that WA7BNM does not). From NZART's rules,
    please confirm: (a) the exchange is RS(T) + serial from 001 + branch number,
    with a home station sending `00`; (b) the points, which TR4W scores as 5 for a
    ZL CW QSO, 3 for ZL phone and 10 for a non-ZL QSO; (c) the multiplier is branches,
    and whether our own branch counts; (d) whether Cabrillo is accepted, and whether
    NZART wants one log per band.
12. **POTA**: Please confirm that pota.app takes ADIF only and no Cabrillo is wanted.
    POTA is not on WA7BNM (only state-park programmes are), so the earlier pass's
    source, docs.pota.app, is not an accepted one.
13. **QCWA**: Retire or re-model? WA7BNM ref 332 is Inactive, last held March 2021.
    Its referred 2021 rules give the exchange in full (see the section), so only the
    keep-or-retire question is open.
14. **QCWAGOLDEN**: What event is this? Neither source lists a QCWA "Golden" event.
    The only other QCWA entry on WA7BNM is the QCWA Fall QSO Party (ref 127), Inactive
    since 2013. Retire?
15. **TENTEN**: Which 10-10 events should the class cover? Its WA7BNM id is 0.
    WA7BNM lists four current ones, each with its own Cabrillo name: Winter SSB
    (ref 237, `10-10-WINTER-PHONE`), Summer SSB (81, `10-10-SUMMER-PHONE`), 10-10 Day
    Sprint (156, `10-10-SPRINT`) and Fall Digital (464, `10-10-FALL-DIGITAL`).
16. **TENTEN**: Does 10-10 accept Cabrillo, and in what column order? The rules page
    WA7BNM links names no electronic format; it asks for a log of *date, time, call,
    name, 10-10#, QTH, points*. The Cabrillo/ADIF upload guide and QSO template the
    earlier pass quoted (name, **state**, number) are on a separate ten-ten.org page
    that the referred rules do not link, and its column order differs from the rules'
    exchange order (name, **number**, QTH).
17. **UA4WCHAMPIONSHIP**: Neither source lists the Udmurtia Championship. Every fact
    in its section came from search snippets of qrz.ru. Please confirm: (a) the
    exchange (serial + RDA for Russia, serial + locator for others, no RS(T)?);
    (b) the bands and tours; (c) the points and multipliers; (d) the CONTEST: value
    (`R4W-CHAMP`?) and the submission address.
18. **WWL**: What event is this? Neither source lists a "WWL" or "World Wide Locator"
    contest. Retire?
19. **XMAS**: Which contest is this? The only XMAS on WA7BNM is the **DARC Christmas
    Contest** (ref 210), whose exchange is DL: RS(T) + DOK, non-DL: RS(T) + serial.
    That does not match TR4W's RST + serial + five-letter random group. The SSA
    Jultest, which does match, is on neither source; the earlier pass inferred it.
20. **XMAS**: The CONTEST: value. `XMAS` is the DARC Christmas Contest's registered
    Cabrillo name (WA7BNM ref 210), so this class must not use it unless it IS the
    DARC contest.
21. **Station fields for a sent QTH**: Under the ruling at
    [decision 2](#decisions-owed), does sending the JA prefecture number (ALL JA), the
    ACAG city code and the Russian RDA district through `MY STATE` count as reuse?
    If it does, they need `MY JA PREFECTURE`, `MY JA CITY CODE` and `MY RDA`.

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
3. Otherwise, a question for NY4I, listed above.

Marks used below:

- `[Cabrillo spec]`
- `[Cabrillo spec -> WA7BNM cabnames]`
- `[WA7BNM ref N]` for the details page itself
- `[WA7BNM ref N -> sponsor URL]` for the sponsor page it links
- `[UNVERIFIED -- earlier pass used <mirror/inference>]`
- `[TR4W code]` for what this tree does, which is a fact about TR4W, not about the rules

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

## Summary

"WA7BNM" is the calendar's ref and status. "Class id" is what the class's
`GetWA7BNMId` returns today `[TR4W code]`.

| TR4W id | WA7BNM (class id) | Cabrillo CONTEST: | Source of the rules | Proposed sent / received (example) | Confidence |
|---|---|---|---|---|---|
| ALLJA | **not listed** (0) | none | UNVERIFIED (jarl.org found by search) -- Q1 | `599 10H` / `599 13M` | Low until Q1 |
| ARCI | 315, 168, 31, 69, 193, 198 active (0) | none | WA7BNM ref 315/168 -> qrparci.org | `599 FL 5W` / `579 ON 1234` | Medium on exchange; low on log format (Q4) |
| COUNTYHUNTER | 3 (US Counties QSO Party) and 20 (SSB QSO Party), both **Inactive** (0) | none | WA7BNM ref 3 and 20; sponsor link dead -- Q5-Q8 | `599 FL ORA` / `599 PA BUC` | Low until Q5 |
| FISTS | 251 **Inactive** (251, correct) | none | WA7BNM ref 251 -> fistsna.org | `599 FL TOM 1234` / `599 VA STAN 2934` | High that it is defunct; retire? (Q9) |
| GRIDLOC | **not listed** (0) | none | UNVERIFIED (mailing-list archive) -- Q10 | `TOM EL98` / `BOB EM10` | Low; retire? |
| JALONGPREFECT | **not listed** (0) | none | UNVERIFIED (identity inferred) -- Q2 | `599 100116L` / `599 1001L` | Low |
| KIDSDAY | 224 "Active historically, but unconfirmed" (224, correct) | none | WA7BNM ref 224 -> arrl.org | none proposed | High that no log is wanted |
| NZFIELDDAY | **not listed** (0, deliberate) | none (class uses `JW-FD`) | UNVERIFIED (search index) -- Q11 | `599 001 25` / `599 017 00` | Low until Q11 |
| POTA | **not listed** (0) | none | UNVERIFIED (docs.pota.app) -- Q12 | no Cabrillo; ADIF already done | Medium |
| QCWA | 332 **Inactive** (332, correct) | none | WA7BNM ref 332 -> qcwa.org 2021 rules | `61 TOM 151` / `55 BOB 91` | High on the rules; keep? (Q13) |
| QCWAGOLDEN | **not listed** (0) | none | none -- Q14 | as QCWA | Low; retire? |
| TENTEN | 237, 81, 156, 464 (0) | `10-10-WINTER-PHONE`, `10-10-SUMMER-PHONE`, `10-10-SPRINT`, `10-10-FALL-DIGITAL` | WA7BNM ref 237/81/156/464 -> ten-ten.org; cabnames | `TOM 12345 FL` / `BOB 0 MA` | High on exchange; medium on file format (Q16) |
| UA4WCHAMPIONSHIP | **not listed** (0) | none | UNVERIFIED (qrz.ru search snippets) -- Q17 | `001 UD05` / `017 TB02` | Low until Q17 |
| WWL | **not listed** (0) | none | none -- Q18 | `599 KO85` / `599 JN58` | Low on the contest; high on the code |
| XMAS | only DARC Xmas, ref 210, CONTEST `XMAS` (0) | `XMAS` belongs to **DARC** | WA7BNM ref 210 contradicts the inference -- Q19, Q20 | `599 001 PZRIQ` / `599 017 LUCIA` | Low (was Medium) |

**Changed from the first pass:** ALLJA, JALONGPREFECT, NZFIELDDAY, UA4W and POTA drop
in confidence, because their rules rested on sources outside the rule. COUNTYHUNTER's
scoring now comes from WA7BNM and differs from the first pass. TENTEN's column order
is corrected to the sponsor's exchange order. XMAS drops to Low, because WA7BNM's
only Christmas contest with Cabrillo name `XMAS` is DARC's, which has a different
exchange.

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
| `MY ARCI NUMBER` | ARCI (member) | yes | yes | no |
| `MY POWER` | ARCI and FISTS non-members | yes | yes | yes: ARCI's power multiplier |
| `MY FISTS NUMBER` | FISTS, **only if kept** (Q9) | yes | yes | no |
| `MY JA POWER CLASS` | ALLJA, JALONGPREFECT | yes | yes | no |
| `MY COUNTY` | COUNTYHUNTER | yes | yes | no |
| `MY QCWA CHAPTER` | QCWA, QCWAGOLDEN | yes | yes | no |
| `MY YEAR LICENSED` | QCWA, QCWAGOLDEN | yes | yes | no |
| `MY NZART BRANCH` | NZFIELDDAY | yes | yes (replaces today's `MY ZONE` prompt) | yes: the own-branch rule |
| `MY JA PREFECTURE`, `MY JA CITY CODE`, `MY RDA` | ALLJA, JALONGPREFECT, UA4W | yes | yes | no |

The last row is **conditional on Q21**: today `MY STATE` carries these values as "the
QTH sent in this contest". The first nine are needed whatever Q21's answer is.

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
- **Rules** -- all `[UNVERIFIED -- earlier pass used jarl.org found by search, not
  WA7BNM-referred]`; see **Q1**:
  - only stations in Japan may enter (68th running, 2026);
  - exchange: RS(T) + prefecture or Hokkaido district number + one power letter,
    **H** over 100 W, **M** over 10 W up to 100 W, **L** over 5 W up to 10 W,
    **P** 5 W or less;
  - log: a JARL e-log, `<SUMMARYSHEET>` plus a `<LOGSHEET TYPE=...>` body in JARL
    format or Cabrillo; JARL's example row is `59 13L 59 13M`, number and letter as
    one token.
- **TR4W has:** `Precedence` (the received H/M/L/P) and `HisQTH`, which is the
  `DomesticQTH` from `allja.dom` `[TR4W code]`. **Caution:** the parser can store
  `QTHString` as `'p' + number`. That is harmless here unless LITERAL DOMESTIC QTH
  is on.
- **Proposed layout:**
  - **Sent:** `'%-3s %s%s'` of RST, our prefecture and `MY JA POWER CLASS`,
    e.g. `599 10H`. (Was `MyPrec`; the ruling rejects that reuse.)
  - **Received:** `'%-3s %s%s'` of RST, `HisQTH` and `Precedence`, e.g. `599 13M`.
  - **STX_STRING:** the sent text.
  - **Helpers:** new, `CabrilloSentRSTQTHPower` and `CabrilloReceivedRSTQTHPrecedence`.
- **Station fields:** `MY JA POWER CLASS`; and `MY JA PREFECTURE` if Q21 says so.
- **Confidence:** low until Q1. The layout follows the exchange the earlier pass found;
  nothing accepted backs it yet.
- **Decisions owed:** Q1, Q21, and the CONTEST value (`ALL JA` contains a space).

### ARCI: QRP ARCI contests

- **Cabrillo spec:** no CONTEST: value; WA7BNM's Cabrillo name list has no ARCI entry
  `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** active events are Spring QSO Party ref 315 ("Active, confirmed"), Fall
  QSO Party ref 168, Hootowl Sprint 31, Summer Homebrew Sprint 69, Topband Sprint 193
  and Holiday Homebrew Sprint 198. Fifteen more ARCI events are Inactive. **The class
  id is 0** -- see **Q3**.
- **Exchange:**
  - members: RST + state/province/country + ARCI member number;
  - non-members: RST + state/province/country + power out.
  `[WA7BNM ref 315 -> http://qrparci.org/contest/spring-qso-party]`, and the same in
  `[WA7BNM ref 168 -> http://qrparci.org/contest/fall-qso-party]`.
- **Scoring** `[WA7BNM ref 315 -> qrparci.org spring-qso-party]`:
  - 5 points per QSO with a member; 4 per non-member on a different continent; 2 per
    non-member on the same continent;
  - multipliers: states, provinces and countries, each once per band;
  - power multiplier: >5 W x1, 1-5 W x7, 250 mW-1 W x10, 55-250 mW x15, 55 mW or less
    x20. (WA7BNM's own page stops at x15; the sponsor page it links adds x20.)
  - total = QSO points x (state + province + country mults) x power multiplier.
- **Log:** "Submit your entry online at http://www.qrpcontest.com"
  `[WA7BNM ref 315 -> qrparci.org]`. Whether that takes Cabrillo is **not stated** --
  **Q4**. **Removed:** the first pass's N1MM and N3FJP notes, which are not accepted
  sources.
- **TR4W has:**
  - `Power`, which holds the member number or the power; an all-digit value means a
    member;
  - `HisQTH` (`DomesticQTH` for W/VE);
  - `QTHString` / `DXQTH` for DX. `HisQTH` is empty for a DX station, so no existing
    received helper prints the DX country correctly. `[TR4W code]`
- **Proposed layout:**
  - **Sent:** `'%-3s %-3s %-6s'` of RST, `MyState` and `MY ARCI NUMBER`, else
    `MY POWER`, e.g. `599 FL  5W` or `599 FL  12345`.
  - **Received:** `'%-3s %-3s %-6s'` of RST, the QTH and `Power`. The QTH is
    `HisQTH`, else `QTHString`, else `DXQTH`.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Station fields:** `MY ARCI NUMBER`, `MY POWER`.
- **Confidence:** medium on the exchange and scoring; low on the file format (Q4).
- **Decisions owed:** Q3, Q4, and the CONTEST value. `ARCI` has no backing in either
  source.

### COUNTYHUNTER: MARAC County Hunter contest

- **Identity:** **ANSWERED (NY4I, 2026-10-15): "County hunter is marac."** The class is
  the MARAC County Hunter contest. It is KEPT, and its header's "general logging mode"
  wording is to be corrected.
- **Cabrillo spec:** no CONTEST: value; no MARAC entry in WA7BNM's Cabrillo name list
  `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM lists two MARAC contests, both Inactive.** The class id is 0. Which one is
  meant is **Q5**.

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
      scores (**Q6 a, b**).
  - **Multipliers:** each US county, once per mode.
  - **Score:** total QSO points x total multipliers.
  - **Logs:** email to contest-logs@marac.org; postal address N7NU. **No format is
    stated** (**Q7**).
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
  DX), county multipliers, and the dupe rule (Q8) -- its own piece of work, with the
  matrix re-frozen for it. It is not an export fix, and it cannot start until Q5-Q8
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
- **Confidence:** low until Q5. The two WA7BNM pages disagree on DX points,
  multipliers and dupes.
- **Decisions owed:** Q5, Q6, Q7, Q8.

### FISTS: FISTS sprints (Americas)

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **Status: defunct.**
  - **FISTS Winter Unlimited Sprint** (the class's FriendlyName): Inactive, last held
    8 Feb 2020 `[WA7BNM ref 251]`. The class id is 251, which is right.
  - Every other FISTS event on WA7BNM is Inactive too (refs 1, 17, 68, 154, 171, 393,
    584-587, 684, 685). Ref 724, the FISTS Royal Platinum Jubilee Weekend Celebration, is listed without the Inactive mark and is not a sprint.
  - The linked sponsor page: *"Sprints will NOT continue in 2026 due to a lack of
    sufficiant participation."* `[WA7BNM ref 251 -> http://fistsna.org/operating.html#sprints]`.
  - **Removed:** the first pass's FISTS UK note, which was not WA7BNM-referred.
- **Last exchange:** FISTS member: RST + state/province/country + first name + FISTS
  number; non-member: the same with power instead of the number `[WA7BNM ref 251]`.
- **Last scoring:** 5 points per QSO with a FISTS member; FISTS members score 2 per
  QSO with a non-member; multipliers are each US state and VE province once and each
  DXCC country once; total = points x mults. Logs by email to w2dab@fistsna.org
  `[WA7BNM ref 251]`.
- **TR4W has:** `QTHString` / `HisQTH`, `Name`, and `NumberReceived` (member) or
  `Power` `[TR4W code]`.
- **If kept:**
  - **Sent:** `'%-3s %-3s %-6s %-6s'` of RST, `MyState`, `MyName` and
    `MY FISTS NUMBER`, else `MY POWER`.
  - **Received:** the same, built from the QSO.
  - **STX_STRING:** the sent text.
- **Station fields, only if kept:** `MY FISTS NUMBER`, `MY POWER`.
- **Confidence:** high that the event is gone.
- **Decision owed:** Q9 -- retire the class, or keep it as a QSO-logging mode.

### GRIDLOC: International HF Grid Location Contest

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** not listed. The class id is 0. (The grid events WA7BNM does list, TOEC WW
  Grid ref 97 and QRP ARCI HF Grid Square Sprint ref 422, are different contests and
  both Inactive.)
- **Status:** defunct, last held 13-14 April 1996, and the exchange was name +
  4-character grid with logs by email `[UNVERIFIED -- earlier pass used a CQ-Contest
  mailing-list archive and a KA9FOX rules file on qth.com]`.
- **TR4W has:** `Name`, and `HisQTH` (the grid, as `DomesticQTH`) `[TR4W code]`.
- **If kept:**
  - **Sent:** a new `'  %-10s %-4s'` of `MY NAME` and `MY GRID` (both genuine fields).
  - **Received:** `CabrilloReceivedNameQTH`, which exists.
  - **STX_STRING:** the sent text.
- **Confidence:** low.
- **Decision owed:** Q10 -- retire the class.

### JALONGPREFECT: JA "long prefecture" (probably JARL All Cities All Guns)

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** not listed under any JARL ACAG name. The class id is 0.
- **Identity is an inference** `[UNVERIFIED -- earlier pass inferred ACAG from the
  domestic file]`: the file is `jacg3.dom`, which holds 5-digit city/gun codes
  `[TR4W code]`. **Q2.**
- **Rules, if it is ACAG** -- all `[UNVERIFIED -- earlier pass used jarl.org found by
  search]`: only stations in Japan; RS(T) + city/gun/ku number + the same H/M/L/P
  power letter, JARL's example being `59100116L`; a JARL e-log, Cabrillo body
  accepted.
- **TR4W's parser** `[TR4W code]`: `ProcessRSTAndJAPrefectureExchange` reads RST +
  number and **never reads a power letter**. Its domestic file may also be out of
  date.
- **Proposed layout:** the ALL JA layout.
  - **Sent:** `599 100116L`, from our city code + `MY JA POWER CLASS`.
  - **Received:** `599 1001L`. This needs the parser to store `Precedence` first.
- **Station fields:** `MY JA POWER CLASS`; and `MY JA CITY CODE` if Q21 says so.
- **Confidence:** low.
- **Decisions owed:** Q2; if it is ACAG, fix the parser and the `.dom` before adding a
  layout.

### KIDSDAY: ARRL Kids Day

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** ref 224, "Active historically, but unconfirmed"; two runs a year, in
  January and June (3 Jan and 20 Jun 2026). The class id is 224, which is right. Email logs to:
  "(none)" `[WA7BNM ref 224]`.
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
- **WA7BNM:** not listed. The class id is 0 on purpose: its header says *"the calendar
  does not list the event, and 0 disables the calendar menu item"*. The NZART events
  WA7BNM does list are the Memorial Contest (721), the Sangster Shield (589) and the
  ZL Sprint (737).
- **Rules** -- all `[UNVERIFIED -- earlier pass used the search index's copy of
  nzart.org.nz/activities/contests/jwfd]`: last full weekend of February, 80 m and
  40 m, CW and phone; RS(T) + serial from 001 + NZART branch number, a home station
  sending `00`; separate per-band logs with *date, time, station worked, mode, band,
  exchange sent, exchange received*; no Cabrillo mentioned. **Q11.**
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
- **Confidence:** low until Q11.
- **Decisions owed:** Q11; and whether a non-ZL branch prints blank or as `00`.

### POTA: Parks on the Air

- **Cabrillo spec:** no CONTEST: value. WA7BNM's Cabrillo names hold only state-park
  programmes (`TNPOTA`, `TSPOTA`) `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** national POTA is not listed. It lists state programmes: Ohio (486),
  Florida (612), Wisconsin (656), Kentucky (659), Texas (559), Tennessee (725),
  Georgia (738). None of them is this class. The class id is 0, which is right.
- **ADIF requirements** -- `[UNVERIFIED -- earlier pass used docs.pota.app and a
  third-party POTA_ADIF_NOTES.md on GitHub]`, **Q12**:
  - required fields `CALL`, `QSO_DATE`, `TIME_ON`, `BAND`, `MODE`;
  - activator fields `MY_SIG=POTA` and `MY_SIG_INFO`;
  - park-to-park fields `SIG` / `SIG_INFO`;
  - file name `CALL@PARK-YYYYMMDD.adi`;
  - ADIF only; no Cabrillo.
- **TR4W already writes** `[TR4W code]` (`uContestPOTA.pas`,
  `EmitADIFExchangeFields` / `EmitADIFContestFields`):
  - `MY_SIG`, `MY_SIG_INFO` and `MY_POTA_REF`;
  - `SIG`, `SIG_INFO` and `POTA_REF`;
  - `SRX_STRING`;
  - `STX_STRING` = `ADIFSentPark`.
  - **ADIF needs nothing.**
- **Proposal:** **produce no Cabrillo for POTA.** If a Cabrillo file is still wanted
  for the operator's own records, use `'%-3s %-10s'` of RST + `MY PARK` (sent) and
  RST + park worked (received).
- **Station fields:** none new; `MY PARK` exists.
- **Confidence:** medium (was high): the code is right for what POTA was understood to
  want, but that understanding rests on Q12.
- **Decision owed:** Q12, and the "no Cabrillo" mechanism (decision 1).

### QCWA: QCWA QSO Party

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **Status:** Inactive; last held 1800Z 13 March to 1800Z 14 March 2021 `[WA7BNM ref
  332]`. The class id is 332, which is right. The QCWA Fall QSO Party (ref 127) is
  Inactive since 2013.
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
- **Decision owed:** Q13 -- retire, or re-model the exchange.

### QCWAGOLDEN: QCWA "Golden" contest

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** not listed. The class id is 0.
- **No sponsor rules found** in either source. TR4W's row is identical to QCWA's. A
  comment in LOGSTUFF says the CHECK+CHAPTER parser was "Used for the QCWA Golden
  Anniversary contest" `[TR4W code]`; that it was a year-licensed exchange is
  `[UNVERIFIED -- earlier pass inferred it from that comment]`.
- **Proposal:** treat it like QCWA.
- **Station fields:** as QCWA.
- **Confidence:** low.
- **Decision owed:** Q14 -- retire it (most likely), or say what event it is.

### TENTEN: 10-10 International QSO parties

- **Cabrillo names** `[Cabrillo spec -> WA7BNM cabnames]`, one per event:
  - `10-10-WINTER-PHONE` (ref 237); alias `10-10 WINTER PHONE`;
  - `10-10-SUMMER-PHONE` (ref 81); alias `10-10 SUMMER PHONE`;
  - `10-10-SPRINT` (ref 156); alias `10-10 SPRINT`;
  - `10-10-FALL-DIGITAL` (ref 464); alias `10-10 FALL DIGITAL`.
  The aliases are WA7BNM's, from each details page `[WA7BNM ref 237/81/156/464]`.
- **WA7BNM:** Summer SSB and the 10-10 Day Sprint are "Active, confirmed"; Winter SSB
  and Fall Digital are "Active historically, but unconfirmed". Six more 10-10 events
  are Inactive. **The class id is 0** -- see **Q15**.
- **Dates** `[WA7BNM ref 237/81/156/464]`: Winter SSB 0001Z 7 Feb to 2359Z 8 Feb 2026;
  Summer SSB 0001Z 1 Aug to 2359Z 2 Aug 2026; Sprint 10 October every year; Fall
  Digital 0001Z 14 Nov to 2359Z 15 Nov 2026. 10 m only.
- **Exchange:** member: name + 10-10 number + state/province/country; non-member:
  name + `0` + state/province/country `[WA7BNM ref 237]`. The sponsor's words:
  *"call sign, name, 10-10# and QTH (State, Province or Country)"*
  `[WA7BNM ref 237 -> https://www.ten-ten.org/qso-party-rules/]`. **There is no RST.**
- **Scoring:** 2 points for a contact with a 10-10 number, 1 without; no multipliers;
  total = QSO points `[WA7BNM ref 237 -> ten-ten.org/qso-party-rules]`. TR4W scores 2
  for every QSO `[TR4W code]`; see design Q46.
- **Log:** a cover sheet, a log and a dupe sheet; the log in date/time order with
  *UTC date, UTC time, call, name, 10-10# (0 if none), QTH and contact point value*;
  Q95 files are refused; email to tentencontest@ten-ten.org
  `[WA7BNM ref 237 -> ten-ten.org/qso-party-rules]`. **The referred rules name no
  electronic format.**
- **What changed from the first pass:**
  - The first pass quoted a Cabrillo/ADIF upload guide and the template
    `QSO: 28000 SB 2014-02-01 1200 AA1AA BOB MA 12345 AA2BB JIM RI 54123` (name,
    **state**, number) `[UNVERIFIED -- earlier pass used ten-ten.org/guide-to-uploading-logs,
    which the WA7BNM-referred rules do not link]`. **Q16.**
  - The proposed column order is changed to the sponsor's exchange order: name,
    **number**, QTH.
  - The CONTEST value is no longer open: WA7BNM gives one per event.
- **TR4W has:** `Name`, `QTHString` (= `HisQTH`), `TenTenNum` (`MAXWORD` means none)
  `[TR4W code]`.
- **Proposed layout:**
  - **Sent:** `'%-10s %-6s %-3s'` of `MY NAME`, `MY TEN TEN NUMBER` (`0` if none) and
    `MY STATE`, e.g. `TOM        12345  FL`.
  - **Received:** `'%-10s %-6d %-3s'` of `Name`, the number (`0` for `MAXWORD`) and
    `HisQTH`.
  - **STX_STRING:** the sent text.
  - **ADIF also has a `TEN_TEN` field** ([adif.org 3.1.7](https://www.adif.org/317/ADIF_317.htm)),
    worth writing for the received number. (ADIF is a format spec, not a contest
    rule, so the source rule does not apply to it.)
- **Station fields:** `MY TEN TEN NUMBER`.
- **Confidence:** high on the exchange and scoring; medium on the file format (Q16).
- **Decisions owed:** Q15, Q16, and the scoring fix (design Q46).

### UA4WCHAMPIONSHIP: Udmurtia Championship (R4W-CHAMP)

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** not listed. The class id is 0. Its QRZ.RU id is 132 and its submission
  email `r4w@narod.ru` `[TR4W code]`; QRZ.RU is not an accepted source.
- **Rules** -- all `[UNVERIFIED -- earlier pass used search-index snippets of
  qrz.ru/contest/detail/132.html; qrz.ru refused connections]`, **Q17**:
  - 10 April 2026, two tours, SSB 16:00-17:59 UTC and CW 18:00-19:59 UTC, 80 m and
    40 m;
  - exchange: Russia, serial from 001 + RDA district (`001 TB02`); others, serial +
    locator (`001 KN04`); RS(T) not sent; the serial runs through both tours;
  - logs: Cabrillo, contest `R4W-CHAMP`, by email to r4w@narod.ru.
- **TR4W's code** `[TR4W code]`:
  - `ProcessRSTAndGridSquareOrRDAExchange` reads RST + grid/RDA and **does not store a
    received serial**;
  - the class's scoring names 160 m;
  - the class's CONTEST value is `R4W-CHAMP`.
- **Proposed layout, after the parser stores `NumberReceived`:**
  - **Sent:** `'%-3s %.3d %-6s'` of RST, `NumberSent` and our RDA (or `MY GRID` for
    a non-Russian station), e.g. `599 001 UD05`.
  - **Received:** the same from the QSO.
  - **STX_STRING:** the sent text.
  - The RST column is a placeholder for robots that read the generic `rst exch`
    layout. Dropping it gives `001 UD05`.
- **Station fields:** `MY RDA` if Q21 says so; `MY GRID` exists.
- **Confidence:** low until Q17 (was medium).
- **Decisions owed:** Q17; RST column in or out; the parser and scoring update first.

### WWL

- **Cabrillo spec:** no CONTEST: value `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM:** nothing named WWL or World Wide Locator, active or inactive. The class id
  is 0.
- **Identity:** unknown. The first pass's "World Wide Locator" came from a search
  index's listing of TR4W itself `[UNVERIFIED -- earlier pass used a search index]`.
- **TR4W's rule** `[TR4W code]`: one point per 500 km, x2 on 80 m and x4 on 160 m.
- **TR4W has:** `RSTReceived`, and the grid in `QTHString` / `HisQTH`.
- **Proposed layout:** all three helpers already exist.
  - **Sent:** `CabrilloSentRSTGrid` (`'%-3s %-7s'`), e.g. `599 KO85`, from `MY GRID`.
  - **Received:** `CabrilloReceivedRSTQTH`.
  - **STX_STRING:** `ADIFSentRSTGrid`.
- **Station fields:** none new.
- **Confidence:** high that the code is right for the exchange TR4W parses; low on
  the contest.
- **Decision owed:** Q18 -- name the event, or retire the class.

### XMAS: Christmas contest (identity open)

- **Cabrillo spec:** `XMAS` is a registered CONTEST: value, and it belongs to the
  **DARC Christmas Contest** `[Cabrillo spec -> WA7BNM cabnames]`.
- **WA7BNM ref 210, DARC Christmas Contest** `[WA7BNM ref 210]`:
  - 26 December, 0830Z-1059Z; 80 m and 40 m; CW and SSB;
  - exchange: DL stations RS(T) + DOK (or `NM` if not a DARC member); non-DL stations
    RS(T) + serial;
  - 1 point per QSO; multipliers DOKs and prefixes, each once per band;
  - upload log at dxhf2.darc.de; Cabrillo name `XMAS`;
  - rules `[WA7BNM ref 210 -> https://www.darc.de/der-club/referate/conteste/weihnachtswettbewerb/en/]`.
- **TR4W's XMAS** `[TR4W code]`: RST + serial + a 5-letter random group generated per
  QSO by Ctrl-R in LogSend; 2 points per QSO; QRZ.RU id 100, the same as TR4W's
  DARC-XMAS. **That exchange does not match DARC's.**
- **What changed from the first pass.** It said the exchange matches the Swedish **SSA
  Jultest** (RST + serial + a five-letter group that changes every QSO; 2 points;
  Cabrillo required) `[UNVERIFIED -- earlier pass inferred it, using hfcontest.ssa.se
  and contestspalten.ssa.se found by search]`. The SSA Jultest is not on WA7BNM, so
  that identity cannot be confirmed here, and WA7BNM's only XMAS is DARC's. The only
  other Christmas event on WA7BNM, the CW QRS Xmas Activity (ref 709: RST + name +
  QTH), does not match either. Confidence drops from medium to low.
- **TR4W has:**
  - sent: `NumberSent` and `RandomCharsSent`, both per QSO in `aQso`;
  - received: `RSTReceived`, `NumberReceived` and `RandomCharsReceived`.
- **Proposed layout:**
  - **Sent:** `'%-3s %.3d %-5s'` of RST, `NumberSent` and `RandomCharsSent`,
    e.g. `599 001 PZRIQ`.
  - **Received:** the same from the QSO.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Station fields:** none.
- **Confidence:** low on the identity; the layout follows TR4W's own exchange.
- **Decisions owed:** Q19 and Q20. If it is not DARC's contest, the class must not
  write `CONTEST: XMAS`.

## Decisions owed

1. **"No Cabrillo" for POTA and Kids Day.** `TContestBase` has no hook that says a
   contest produces no Cabrillo file. The options are:
   - **(a)** a virtual (e.g. `WritesCabrillo: boolean`) so the export says "this
     activity has no Cabrillo" and writes nothing;
   - **(b)** keep the loud marker;
   - **(c)** invent a layout.
   **(a) is recommended.** (b) leaves every export reporting a failure that is not one.
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
   - Still open under this ruling: Q21, whether `MY STATE` carrying a JA prefecture,
     an ACAG city code or an RDA district is also reuse.
   - Nothing is created in code by this document. Adding a setting follows
     `docs/ADDING_A_SETTING.md`.
3. **Retire or keep the defunct and unidentified contests:** FISTS (Q9), GRIDLOC
   (Q10), QCWA (Q13), QCWAGOLDEN (Q14) and WWL (Q18). COUNTYHUNTER is the MARAC
   contest and is kept (NY4I, 2026-10-15); which MARAC event is Q5.
4. **Contests whose parser or scoring must change before a layout means anything:**
   - **COUNTYHUNTER:** MARAC scoring, multipliers and the worked station's type
     (Q5-Q8);
   - **UA4W:** the serial is not stored, and the RST may no longer be sent (Q17);
   - **JALONGPREFECT:** the power letter is not read (Q2);
   - **QCWA:** the exchange is year + name + chapter.
   These belong to the contest-scoring and contest-factory owners, not to export.
5. **CONTEST values with spaces** break the Cabrillo character rule (A-Z, 0-9,
   hyphen; at most 32 characters) `[Cabrillo spec]`: `ALL JA`, `COUNTY HUNTER`,
   `GRID LOC`, `JA LONG PREFECT`, `KIDS DAY`, `QCWA GOLDEN`, `TEN TEN`. For TENTEN the
   answer is now known, one WA7BNM name per event (Q15 picks which). Renaming one
   changes its ADIF `CONTEST_ID` too, and the old spelling would then need to be kept
   for import, as JW-FD does.
6. **Per-contest questions** are the numbered list at the top.

## Contests WA7BNM marks inactive, or does not list

- **Inactive:** FISTS (ref 251, and every other FISTS sprint); QCWA (ref 332; Fall
  party ref 127); both MARAC contests (refs 3 and 20).
- **"Active historically, but unconfirmed":** Kids Day (224); 10-10 Winter SSB (237)
  and Fall Digital (464); DARC Christmas (210).
- **Not listed at all:** ALL JA, JA ACAG, Grid Location, NZART Jock White Field Day,
  national POTA, QCWA Golden, Udmurtia Championship, WWL, SSA Jultest.

## Rules that rest on a non-accepted source

Each of these is marked `[UNVERIFIED -- ...]` in its section and has a question.

- **ALL JA** (Q1) and **ACAG** (Q2): jarl.org found by search.
- **Grid Location** (Q10): a mailing-list archive and a third-party rules file.
- **NZ JW-FD** (Q11): the search index's copy of nzart.org.nz.
- **POTA** (Q12): docs.pota.app and a third-party GitHub note.
- **10-10 file format** (Q16): a ten-ten.org page the referred rules do not link.
- **UA4W** (Q17): search-index snippets of qrz.ru.
- **WWL** (Q18) and **QCWA Golden** (Q14): no rules at all.
- **Xmas** (Q19): the SSA Jultest identification is an inference.
- **MARAC** (Q6, Q7): WA7BNM's two pages give the scoring, but their sponsor link is
  dead, so nothing past the details pages is checked.
