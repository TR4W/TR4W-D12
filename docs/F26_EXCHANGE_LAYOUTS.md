# F26: export layouts for the fifteen contests with no exchange layout

**Status: PROPOSAL, nothing built.** Research for NY4I's approval, 2026-10-14.
Plan item F26 is in `docs/CONTEST_FACTORY_M11_PLAN.md`.

## Why this exists

Fifteen registered contests have no export layout. Each one calls
`CabrilloSentNotHandled` / `CabrilloReceivedNotHandled`, so every Cabrillo `QSO:`
line prints `ERROR EXCHANGE NOT HANDLED` in both exchange columns. Fourteen of them
also call `ADIFSentNotImplemented`, so ADIF leaves out `STX_STRING`. POTA is the
exception: it already writes `ADIFSentPark`.

For each contest this document gives:

- the sponsor's current rules;
- the fields TR4W already holds;
- a proposed sent column, received column and `STX_STRING`;
- the decisions NY4I owes.

**The Cabrillo specification defines no QSO template for any of these contests.**
The WWROF template list ([wwrof.org/cabrillo/cabrillo-qso-data](https://wwrof.org/cabrillo/cabrillo-qso-data/))
covers CQ, ARRL, RSGB, RDXC, NAQP, NEQP and UBA only. Every layout below therefore
uses the generic form, `QSO: freq mo date time call rst exch call rst exch`, with the
exchange in the order the sponsor gives it. Cabrillo is whitespace-separated, so the
column widths below follow this tree's existing style; they are not a sponsor
requirement.

## Summary

| TR4W id | Sponsor status | Exchange changed since TR4W's code? | Cabrillo taken? | Proposed sent / received (example) | Reuse | Confidence |
|---|---|---|---|---|---|---|
| ALLJA | Active (JARL, 68th running 2026) | Partly: power is now H/M/L/P (parser already reads it) | Yes, as the body of a JARL e-log | `599 10H` / `599 13M` | new helper | Medium |
| ARCI | Active (several QRP ARCI events) | No | Web "autolog"; Cabrillo is written by N1MM/N3FJP | `599 FL 5W` / `579 ON 1234` | new helper | Medium |
| COUNTYHUNTER | MARAC contest exists; current rules page could not be reached | No | Not stated | `599 FL ORA` / `599 PA BUC` | `CabrilloSentRSTState`, `CabrilloReceivedRSTQTH` | Low |
| FISTS | **Defunct**: NA sprints ended after 2025; Winter Unlimited inactive since 2020 | -- | (was email) | `599 FL TOM 1234` / `599 VA STAN 2934` | new helper | Low; consider retiring |
| GRIDLOC | **Defunct**: last held 1996 | -- | (was email) | `TOM EL98` / `BOB EM10` | `CabrilloReceivedNameQTH` + new sent | Low; consider retiring |
| JALONGPREFECT | Probably JARL All Cities All Guns (ACAG); identity not confirmed | **Yes**: power code added; parser does not read it | Yes, as a JARL e-log body | `599 100116L` / `599 1001L` | new helper | Low |
| KIDSDAY | Active, but **no logs and no scores** | -- | **No** (survey and photos only) | none proposed | -- | High that no log is wanted |
| NZFIELDDAY | Active (NZART JW-FD) | No | Paper-style per-band logs; Cabrillo not mentioned | `599 001 25` / `599 017 00` | new helper | Medium |
| POTA | Active; an activation, not a contest | -- | **No**: pota.app takes ADIF only | no Cabrillo; ADIF already done | `ADIFSentPark` (exists) | High |
| QCWA | **Inactive since 2021** | **Yes**: year licensed + name + chapter or SPC; no serial | Yes, by email (2020 rules) | `61 TOM 151` / `55 BOB 91` | new helper | Medium; parser must change first |
| QCWAGOLDEN | No sponsor rules found | Unknown | Unknown | as QCWA | as QCWA | Low |
| TENTEN | Active (10-10 International) | No | Yes: Cabrillo or ADIF upload | `TOM FL 12345` / `BOB MA 0` | new helper | High |
| UA4WCHAMPIONSHIP | Active (Udmurtia Championship, CONTEST `R4W-CHAMP`) | **Yes**: now serial + RDA or locator, **no RST** | Yes, by email to r4w@narod.ru | `001 UD05` / `017 TB02` | new helper | Medium; parser must change first |
| WWL | **Sponsor not identified** | Unknown | Unknown | `599 KO85` / `599 JN58` | **all three helpers exist**: `CabrilloSentRSTGrid`, `CabrilloReceivedRSTQTH`, `ADIFSentRSTGrid` | Low on the contest; high on the code |
| XMAS | Almost certainly the **SSA Jultest** (Sweden); identity not confirmed by TR4W's history | No | **Cabrillo required** | `599 001 PZRIQ` / `599 017 LUCIA` | new helper | Medium |

## Fields that are available, and fields that are not

**The sent side** comes from `TMyStationExchange`, which `PostUnit.CurrentMyStationExchange`
builds. The fields are `MyState` (the state *sent in this contest*), `MyGrid`,
`MyName`, `MyZone`, `MyFDClass`, `MySection`, `MyCheck`, `MyPrec`, `MyFOCNumber`,
`MyPostalCode` and `MyPark`. The per-QSO values come from the `ContestExchange`
record `aQso`: `NumberSent`, `RSTSent` (formatted as `aCtx.RSTSent`) and
`RandomCharsSent`.

**There is no station fact for:**

- a membership number for 10-10, FISTS or ARCI;
- transmitter power, needed by ARCI and FISTS non-members and as the JA power letter;
- a county;
- an age.

This shortage is the main decision NY4I owes. See [Decisions owed](#decisions-owed).

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

- **Rules:** [jarl.org allja_rules.html](https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/allja_rules.html)
  (68th running, 2026). Only stations in Japan may enter.
- **Exchange:** RS(T), then the prefecture or Hokkaido district number, then one power
  letter. The power letters are:
  - **H**: over 100 W;
  - **M**: over 10 W, up to 100 W;
  - **L**: over 5 W, up to 10 W;
  - **P**: 5 W or less.
- **Log submission:** a JARL e-log, which is a `<SUMMARYSHEET>` plus a
  `<LOGSHEET TYPE=...>` body. JARL recommends that the body be in either JARL format
  or Cabrillo, and the upload page converts UTC.
  ([logformat.html](https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/logformat.html),
  [cabrillo.html](https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/cabrillo.html))
- **JARL's own example row:** `59 13L 59 13M`. The number and the power letter are
  written as one token.
- **TR4W has:** `Precedence` (the received H/M/L/P) and `HisQTH`, which is the
  `DomesticQTH` from `allja.dom`. **Caution:** the parser can store `QTHString` as
  `'p' + number`. That is harmless here unless LITERAL DOMESTIC QTH is on.
- **Proposed layout:**
  - **Sent:** `'%-3s %s%s'` of RST, `MyState` and `MyPrec`, e.g. `599 10H`.
  - **Received:** `'%-3s %s%s'` of RST, `HisQTH` and `Precedence`, e.g. `599 13M`.
  - **STX_STRING:** the sent text.
  - **Helpers:** new, `CabrilloSentRSTQTHPower` and `CabrilloReceivedRSTQTHPrecedence`.
- **Confidence:** medium. The exchange is certain. The Cabrillo body is accepted, but
  JARL publishes no column template.
- **Decisions owed:**
  - Where our power letter comes from. Reusing `MY PREC` is the cheapest option, and the
    received side already reuses `Precedence`.
  - The CONTEST value. `ALL JA` contains a space, which the Cabrillo character rule does
    not allow; JARL picks the contest on its upload page anyway.

### ARCI: QRP ARCI contests

- **Rules:**
  - [Spring QSO Party](https://www.qrparci.org/contest/spring-qso-party);
  - [Fall QSO Party](https://www.qrparci.org/contest/fall-qso-party);
  - the same exchange is used by the Hoot Owl, Summer Homebrew, Holiday Spirits and Top
    Band events ([N1MM's notes](https://n1mmwp.hamdocs.com/manual-supported/contests-setup/setup-hf-contests/)).
- **Exchange:**
  - members send RST, state/province/country and their ARCI number;
  - non-members send RST, state/province/country and their output power.
- **Log submission:** online "autolog" at [qrpcontest.com](https://www.qrpcontest.com/).
  The site does not say whether it parses a Cabrillo file. N1MM and N3FJP write Cabrillo
  for ARCI, and N1MM's log type is `ARCI`.
- **TR4W has:**
  - `Power`, which holds the member number or the power; an all-digit value means a member;
  - `HisQTH` (`DomesticQTH` for W/VE);
  - `QTHString` / `DXQTH` for DX. `HisQTH` is empty for a DX station, so no existing
    received helper prints the DX country correctly.
- **Proposed layout:**
  - **Sent:** `'%-3s %-3s %-6s'` of RST, `MyState` and our number-or-power,
    e.g. `599 FL  5W` or `599 FL  12345`.
  - **Received:** `'%-3s %-3s %-6s'` of RST, the QTH and `Power`. The QTH is `HisQTH`,
    else `QTHString`, else `DXQTH`.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Confidence:** medium.
- **Decisions owed:**
  - The source for our member number or power (see [Decisions owed](#decisions-owed)).
  - Whether to keep CONTEST `ARCI`. It matches N1MM.

### COUNTYHUNTER: MARAC County Hunter contest / general county-hunting log

- **Rules:** MARAC contest rules
  ([marac.org/contestrules.htm](http://marac.org/contestrules.htm)); the page could not be
  reached from here. A copy of the rules is at
  [qsl.net/yt1dz](https://www.qsl.net/yt1dz/contests_files/htmlrules/marac.html).
  - **Exchange:** RST plus county and state; others send RST plus province or country.
  - **Scoring:** 1 point for a fixed station, 15 for a mobile, 5 for DX.
  - **Log submission:** the log, a summary sheet and check sheets, due 6 June. No
    Cabrillo format is stated.
- **TR4W:** the class's own header calls it a *general logging mode*, not that contest.
  `HisQTH` is `QTHString` as typed, e.g. `FL ORA`.
- **Proposed layout:**
  - **Sent:** `CabrilloSentRSTState`, with `MY STATE` holding `FL ORA`.
  - **Received:** `CabrilloReceivedRSTQTH`.
  - **STX_STRING:** `ADIFSentRSTState`.
  - **Width:** the 7-wide QTH field truncates county lines (`FL ORA/SEM`). A 12-wide
    variant may be wanted.
- **Confidence:** low. The sponsor publishes no Cabrillo layout.
- **Decisions owed:**
  - Is this class the MARAC contest, or a county-hunting log?
  - Does the county go in `MY STATE`, or does it need its own station fact?
  - Is a Cabrillo file wanted at all?

### FISTS: FISTS sprints (Americas)

- **Status: defunct.**
  - [fistsna.org](https://www.fistsna.org/operating.php): *"Sprints will NOT continue in
    2026 due to a lack of sufficient participation."*
  - The FISTS Winter Unlimited Sprint (TR4W's FriendlyName) is listed **Inactive**, last
    held 8 Feb 2020 ([WA7BNM 251](https://www.contestcalendar.com/contestdetails.php?ref=251)).
  - FISTS UK's current sprints need "no minimum exchange"
    ([fists.co.uk](https://fists.co.uk/activitiescalendar.html)).
- **Last exchange:** RST + state/province/country + first name + FISTS number; a
  non-member sent power instead of the number.
- **TR4W has:** `QTHString` / `HisQTH`, `Name`, and `NumberReceived` (member) or `Power`.
- **If kept:**
  - **Sent:** `'%-3s %-3s %-6s %-6s'` of RST, `MyState`, `MyName` and number-or-power.
  - **Received:** the same, built from the QSO.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Confidence:** low; the event is gone.
- **Decision owed:** retire the class, or keep it as a QSO-logging mode.

### GRIDLOC: International HF Grid Location Contest

- **Status: defunct.** The 2nd annual running was 13-14 April 1996
  ([CQ-Contest, 1995](http://lists.contesting.com/_cq-contest/1995-04/msg00020.html),
  [KA9FOX rules](https://www.qth.com/ka9fox/rules_gridloc.txt)).
- **Exchange:** name + 4-character grid. Logs were sent by email.
- **TR4W has:** `Name`, and `HisQTH` (the grid, as `DomesticQTH`).
- **If kept:**
  - **Sent:** a new `'  %-10s %-4s'` of `MyName` and `MyGrid`.
  - **Received:** `CabrilloReceivedNameQTH`, which exists.
  - **STX_STRING:** the sent text.
- **Confidence:** low.
- **Decision owed:** retire the class.

### JALONGPREFECT: JA "long prefecture" (probably JARL All Cities All Guns)

- **Identity is an assumption.** The domestic file is `jacg3.dom`, which holds 5-digit
  city/gun codes. That matches JARL's **All Cities All Guns (ACAG)** contest
  ([acag_rules.html](https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/acag_rules.html)).
  - **Who:** only stations in Japan.
  - **Exchange:** RS(T) + city/gun/ku number + the same H/M/L/P power letter. JARL's
    example is `59100116L`.
  - **Log submission:** a JARL e-log; JARL accepts a Cabrillo body as for ALL JA.
- **The exchange has changed since TR4W's parser was written (KK1L 6.72).**
  `ProcessRSTAndJAPrefectureExchange` reads RST + number and **never reads the power
  letter**, and its domestic file may also be out of date.
- **Proposed layout:** the ALL JA layout.
  - **Sent:** `599 100116L`, from `MyState` + `MyPrec`.
  - **Received:** `599 1001L`. This needs the parser to store `Precedence` first.
- **Confidence:** low.
- **Decisions owed:**
  - Is this ACAG?
  - If so, fix the parser and the `.dom` before adding an export layout, or merge it with
    ALL JA's layout.

### KIDSDAY: ARRL Kids Day

- **Rules:** [arrl.org/kids-day](https://www.arrl.org/kids-day); WA7BNM ref 224.
  - **Suggested exchange:** name, age, location, favourite colour.
  - **Not scored, and no log is submitted.** Participants post to the Soapbox, send
    photos, or fill in a survey.
- **TR4W has:** `Kids`, which is the whole received string. There is no station fact for
  our age or colour.
- **Proposal:** **produce no Cabrillo.**
  - If a file is wanted anyway, the received column is `Kids` as typed, and the sent
    column is `MyName` plus free text.
  - **STX_STRING:** `MyName`, or leave it out.
- **Confidence:** high that no log is wanted.
- **Decision owed:** how a contest says "no Cabrillo". The same question arises for POTA;
  see [Decisions owed](#decisions-owed).

### NZFIELDDAY: NZART Jock White Memorial Field Day (JW-FD)

- **Rules:** [nzart.org.nz/activities/contests/jwfd](https://nzart.org.nz/activities/contests/jwfd/);
  the page could not be fetched directly, so the details here are quoted from the search
  index.
  - **When:** last full weekend of February, on 80 m and 40 m, CW and phone.
  - **Exchange:** RS(T) + a serial from 001 + the NZART branch number. A home station
    sends branch `00`. Overseas (Oceania) stations may be worked.
  - **Logs:** separate per-band logs in time order with columns *date, time, station
    worked, mode, band, exchange sent, exchange received*. No Cabrillo is mentioned.
- **TR4W has:**
  - sent: `NumberSent`, and `MyZone` (`ZoneSentForThisContest`) as the branch;
  - received: `RSTReceived`, `NumberReceived`, `Zone`. The parser reads a branch only
    for a ZL call.
- **Proposed layout:**
  - **Sent:** `'%-3s %.3d %.2d'` of RST, `NumberSent` and the branch, e.g. `599 001 25`.
  - **Received:** the same from the QSO, e.g. `599 017 00`.
  - **Non-ZL station:** no branch is printed.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Confidence:** medium on the exchange; low on whether Cabrillo is accepted.
- **Decisions owed:**
  - Does NZART accept Cabrillo? If so, should there be one file per band, as its rules
    ask?
  - Should a non-ZL station's branch print blank, or as `00`?

### POTA: Parks on the Air

- **pota.app takes ADIF only.**
  - **Required fields:** `CALL`, `QSO_DATE`, `TIME_ON`, `BAND`, `MODE`.
  - **Activator fields:** `MY_SIG=POTA` and `MY_SIG_INFO`.
  - **Park-to-park fields:** `SIG` / `SIG_INFO`.
  - **File name:** `CALL@PARK-YYYYMMDD.adi`.
  - Sources: [docs.pota.app](https://docs.pota.app/docs/activator_reference/logging_made_easy.html),
    [POTA ADIF notes](https://github.com/cniesen/PotaLogger/blob/master/POTA_ADIF_NOTES.md).
- **TR4W already writes:**
  - `MY_SIG`, `MY_SIG_INFO` and `MY_POTA_REF`;
  - `SIG`, `SIG_INFO` and `POTA_REF`;
  - `SRX_STRING`;
  - `STX_STRING` = `ADIFSentPark`.
  - Source: `uContestPOTA.pas`, `EmitADIFExchangeFields` / `EmitADIFContestFields`.
  - **ADIF needs nothing.**
- **Proposal:** **produce no Cabrillo for POTA.** If a Cabrillo file is still wanted for
  the operator's own records, use `'%-3s %-10s'` of RST + `MyPark` (sent) and RST + park
  worked (received).
- **Confidence:** high.
- **Decision owed:** the "no Cabrillo" mechanism (below).

### QCWA: QCWA QSO Party

- **Status: inactive since the 2021 running**
  ([WA7BNM 332](https://www.contestcalendar.com/contestdetails.php?ref=332);
  [2021 rules](https://www.qcwa.org/2021-qso-party-rules.pdf)).
- **The exchange has changed.** The 2020 rules
  ([qcwa.org](https://www.qcwa.org/2020-qso-party-rules.pdf)) give:
  - **Exchange:** *call, year of license (last 2 digits), name, chapter/state/province/country*.
  - **There is no serial**, and "AL" must not be used.
  - **Logs:** Cabrillo by email to w2od@aol.com.
  - **N1MM:** log type `QCWAQSO`.
- **What TR4W parses:**
  - `ProcessQSONumberNameChapterAndQTHExchange` expects *serial, name, chapter, QTH*,
    which is the old exchange.
  - `ProcessCheckAndChapterOrQTHExchange` reads the year into `Check` plus a chapter or
    QTH. It is close to the current rule, and **no contest uses it**.
- **Proposed layout, after the parser is fixed:**
  - **Sent:** `'%.2d %-10s %-4s'` of `MyCheck` (year licensed), `MyName` and the chapter,
    e.g. `61 TOM 151`.
  - **Received:** `Check`, `Name`, then `Chapter` (else the QTH).
  - **STX_STRING:** the sent text.
- **Confidence:** medium on the rules; the event itself may be over.
- **Decisions owed:**
  - Retire the class, or re-model its exchange.
  - Our chapter needs a station fact. `MY STATE` would do for a member with no chapter.

### QCWAGOLDEN: QCWA "Golden" contest

- **No sponsor rules found.** TR4W's row is identical to QCWA's. A comment in LOGSTUFF
  says the CHECK+CHAPTER parser was "Used for the QCWA Golden Anniversary contest", which
  suggests that event once had a year-licensed exchange. That is a guess.
- **Proposal:** treat it like QCWA.
- **Confidence:** low.
- **Decision owed:** retire it (most likely), or tell us what event it is.

### TENTEN: 10-10 International QSO parties

- **Rules:** [ten-ten.org/qso-party-rules](https://www.ten-ten.org/qso-party-rules).
  - **Events:** Winter Phone (first full weekend of February), Summer Phone (first full
    weekend of August), and the 10-10 Sprint (10 October).
  - **Exchange:** call, name, 10-10 number and QTH. Log `0` when the other station has
    no number.
  - **Scoring: 2 points with a 10-10 number, 1 without.** TR4W scores 2 for every QSO;
    see design Q46.
- **Upload:** [Guide to Uploading Logs](https://www.ten-ten.org/guide-to-uploading-logs/)
  takes Cabrillo or ADIF.
  - **CONTEST header:** `CONTEST: Name of QSO Party`.
  - **Sponsor's template:** `QSO: 28000 SB 2014-02-01 1200 AA1AA BOB MA 12345 AA2BB JIM RI 54123`,
    i.e. *name, state, 10-10 number*. **There is no RST.**
- **TR4W has:** `Name`, `QTHString` (= `HisQTH`), `TenTenNum` (`MAXWORD` means none).
- **Proposed layout:**
  - **Sent:** `'%-10s %-3s %-6s'` of `MyName`, `MyState` and our 10-10 number,
    e.g. `TOM        FL  12345`.
  - **Received:** `'%-10s %-3s %-6d'` of `Name`, `HisQTH` and the number, printing `0`
    for `MAXWORD`.
  - **STX_STRING:** the sent text.
  - **ADIF also has a `TEN_TEN` field** ([adif.org 3.1.7](https://www.adif.org/317/ADIF_317.htm)),
    worth writing for the received number.
- **Confidence:** high.
- **Decisions owed:**
  - Where our 10-10 number lives.
  - The CONTEST value: per event (e.g. `10-10-WINTER-PHONE`), or keep `TEN TEN`, which
    contains a space. The sponsor gives only "Name of QSO Party".
  - The scoring fix (Q46).

### UA4WCHAMPIONSHIP: Udmurtia Championship (R4W-CHAMP)

- **Rules:** [qrz.ru contest 132](https://www.qrz.ru/contest/detail/132.html); qrz.ru
  refused connections from here, so the details are quoted from the search index.
  - **Date:** 10 April 2026, in two tours: SSB 16:00-17:59 UTC and CW 18:00-19:59 UTC,
    on 80 m and 40 m.
  - **Exchange:**
    - Russia: a serial from 001 + the RDA district, e.g. `001 TB02`;
    - everyone else: serial + locator, e.g. `001 KN04`;
    - **RS(T) is not sent**, and the serial runs on through both tours.
  - **Logs:** Cabrillo, with the contest selected as `R4W-CHAMP`, emailed to
    r4w@narod.ru. TR4W is named as a supported program.
- **This has changed from TR4W's code.**
  - `ProcessRSTAndGridSquareOrRDAExchange` reads RST + grid/RDA and **does not store a
    received serial**.
  - The class's scoring names 160 m, and the event is now 80 m and 40 m.
  - The class's CONTEST value already matches: `R4W-CHAMP`.
- **Proposed layout, after the parser stores `NumberReceived`:**
  - **Sent:** `'%-3s %.3d %-6s'` of RST, `NumberSent` and `MyState` (our RDA or
    locator), e.g. `599 001 UD05`.
  - **Received:** the same from the QSO.
  - **STX_STRING:** the sent text.
  - The RST column is kept as a placeholder because Russian robots usually read the
    generic `rst exch` layout. Dropping it gives `001 UD05`.
- **Confidence:** medium.
- **Decisions owed:**
  - Should the RST column be in or out?
  - The parser and scoring update is contest-scoring work and comes first.

### WWL

- **Sponsor not identified.**
  - The search index lists TR4W's entry as "World Wide Locator".
  - Its scoring is one point per 500 km, ×2 on 80 m and ×4 on 160 m. That is not the
    Stew Perry (1 + 1 per 500 km) and matches no current contest found.
- **TR4W has:** `RSTReceived`, and the grid in `QTHString` / `HisQTH`.
- **Proposed layout:** all three helpers already exist.
  - **Sent:** `CabrilloSentRSTGrid` (`'%-3s %-7s'`), e.g. `599 KO85`.
  - **Received:** `CabrilloReceivedRSTQTH`.
  - **STX_STRING:** `ADIFSentRSTGrid`.
- **Confidence:** high that the code is right for the exchange TR4W parses; low on the
  contest.
- **Decision owed:** name the event, or retire the class.

### XMAS: Christmas contest (probably the SSA Jultest)

- **Identity.**
  - The exchange TR4W parses is RST + serial + a 5-letter random group, generated per QSO
    by Ctrl-R in LogSend. The scoring is 2 points per QSO.
  - Both match the Swedish **SSA Jultest**
    ([rules](https://hfcontest.ssa.se/ssa-jt/regler.html);
    [pre-2022 rules](https://contestspalten.ssa.se/ssa-jultest-regler-fore-2022/)):
    - **When:** 25 December, 0800-1100 UTC.
    - **Who:** Swedish stations only, on 80 m and 40 m, CW and SSB.
    - **Exchange:** RST + a 3-digit serial + a five-letter group that changes every QSO,
      e.g. `599 017 LUCIA`.
    - **Scoring:** 2 points per QSO, no multipliers.
    - **Logs: Cabrillo required**, uploaded at [hfcontest.ssa.se](https://hfcontest.ssa.se/)
      by 2 January.
  - TR4W's row gives QRZRUID 100, the same as DARC-XMAS. That looks like a copy, not
    evidence that the contest is Russian.
- **TR4W has:**
  - sent: `NumberSent` and `RandomCharsSent`, both per QSO in `aQso`;
  - received: `RSTReceived`, `NumberReceived` and `RandomCharsReceived`.
- **Proposed layout:**
  - **Sent:** `'%-3s %.3d %-5s'` of RST, `NumberSent` and `RandomCharsSent`,
    e.g. `599 001 PZRIQ`.
  - **Received:** the same from the QSO.
  - **STX_STRING:** the sent text.
  - **Helpers:** new.
- **Confidence:** medium. The exchange fits exactly; the identity is inferred.
- **Decisions owed:**
  - Confirm it is the SSA Jultest.
  - The CONTEST value. The sponsor's is not published. **`XMAS` is N1MM's name for the
    DARC Christmas contest** (TR4W's `DARCXMAS`), so a robot could misfile it. A candidate
    is `SSA-JT`, the sponsor's own short name.

## Decisions owed

1. **"No Cabrillo" for POTA and Kids Day.** `TContestBase` has no hook that says a contest
   produces no Cabrillo file. The options are:
   - **(a)** a virtual (e.g. `WritesCabrillo: boolean`) so the export says "this activity
     has no Cabrillo" and writes nothing;
   - **(b)** keep the loud marker;
   - **(c)** invent a layout.
   **(a) is recommended.** (b) leaves every export reporting a failure that is not one.
2. **Missing station facts.** These values are sent but have nowhere to live:
   - a membership number (10-10, ARCI, FISTS);
   - transmitter power, or the JA power letter;
   - a county;
   - a QCWA chapter.

   The options are:
   - **(a)** one generic `MY MEMBER NUMBER` and one `MY POWER`, each overridable per
     contest;
   - **(b)** one fact per programme;
   - **(c)** reuse existing fields: `MY PREC` for the JA power letter, `MY CHECK` for the
     QCWA year, `MY STATE` for a county.

   (c) works today for ALL JA and QCWA. Only (a) or (b) solves 10-10 and ARCI.
3. **Retire or keep the defunct and unidentified contests:** FISTS, GRIDLOC, QCWA,
   QCWAGOLDEN, WWL, and possibly COUNTYHUNTER.
4. **Contests whose parser must change before a layout means anything:**
   - **UA4W:** the serial is not stored, and the RST is no longer sent;
   - **JALONGPREFECT:** the power letter is not read;
   - **QCWA:** the exchange is now year + name + chapter.
   These belong to the contest-scoring and contest-factory owners, not to export.
5. **CONTEST values with spaces** break the Cabrillo character rule (A-Z, 0-9, hyphen; at
   most 32 characters): `ALL JA`, `COUNTY HUNTER`, `GRID LOC`, `JA LONG PREFECT`,
   `KIDS DAY`, `QCWA GOLDEN`, `TEN TEN`. Renaming one changes its ADIF `CONTEST_ID` too,
   and the old spelling would then need to be kept for import, as JW-FD does.
6. **Per-contest questions** are listed in each section above, for ALL JA, ARCI, County
   Hunter, NZ, 10-10, UA4W and Xmas.

## Rules that could not be confirmed

- **WWL:** no sponsor was found.
- **QCWA Golden:** no sponsor was found.
- **County Hunter (MARAC):** marac.org could not be reached; the rules used are a
  third-party copy, and no log format is stated.
- **NZ JW-FD:** nzart.org.nz could not be fetched; the rules come from the search index.
  Whether Cabrillo is accepted is unknown.
- **UA4W:** qrz.ru and radioman-portal.ru refused connections; the rules come from the
  search index.
- **JA Long Prefect:** that it is ACAG is an inference.
- **Xmas:** that it is the SSA Jultest is an inference.
- **ARCI:** whether qrpcontest.com accepts a Cabrillo upload is not stated.
- **ADIF `FISTS` field:** it is believed to exist in ADIF 3.x but was not confirmed.
