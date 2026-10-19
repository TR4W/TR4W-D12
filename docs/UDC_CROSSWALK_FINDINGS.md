# N1MM UDC cross-walk against TR4W's contests -- findings

**Reading of 2026-10-19.** Regenerate with:

```
python -I tools/udc/fetch_udc.py          # only if the cache is missing or stale
python -I tools/udc/parse_udc.py
python -I tools/udc/crosswalk.py --q98 <resolved Q98 table>
```

`--q98` defaults to `docs/Q98_CONTEST_BANDS_MODES.csv`; this reading used the
resolved Q98 table (`contest_id, resolution, bands, modes, ...`), in which
seven contests are still open. The output, `tools/udc/cache/crosswalk.csv`, is
gitignored: it quotes third-party files. See `tools/udc/README.md`.

**Source ranking (NY4I): D7 > sponsor rules > WA7BNM > DXLog > UDC.** A UDC is
community-written for another program. Every item below is a LEAD to check
against a higher source, never a verdict. The reading itself changed no code,
`.dom` or class; items 1 and 2 below were then checked against the sponsors'
rules and FIXED (2026-10-19, NY4I: *"yes add GO to brazil.dom and clean up
EUDX"*).

## Counts

| | |
|---|---|
| UDC records (from 406 files) | 540 |
| matched to one TR4W contest | 36 (28 distinct TR4W contests of 187) |
| ambiguous (a candidate a human must confirm) | 21 |
| unmatched | 483 |

Matches by method: `cabrillo-exact` 18, `cabrillo-normalized` 1,
`cabrillo-to-id` 4, `name-to-id` 1, `display-exact` 3, `curated` 9 (each with
its reason in `CURATED_MATCHES`).

Rows by finding kind: `match` 36, `cabrillo-name` 18, `exchange-layout` 8,
`section-list` 6, `mode` 1, `bands` 0, `q98-open` 7, `match-candidate` 32,
`not-in-tr4w` 504 (388 distinct UDC Cabrillo names).

**Why the overlap is small:** N1MM ships the major contests (CQ, ARRL, IARU,
WAE, the state parties it supports...) as built-in modules, so the UDC library
is mostly the minor events N1MM does not carry. Only 28 TR4W contests have a
UDC at all.

## Worth NY4I's attention

### Section and multiplier lists (`.dom` against the UDC's `.sec`)

1. **FIXED 2026-10-19. LABRE DX: `brazil.dom` had no Goias (`GO`).** The
   sponsor's list is longer than the UDC's: the 2026 rules
   (<https://www.labre.org.br/contest/wp-content/uploads/2026/07/Regulamento-Contest-LABRE-DX-2026-Ingles-v3.pdf>,
   section V, Table 1) give 28 codes -- the 26 states, `DF` and Fernando de
   Noronha (`FN`) -- and section VI.C counts the official LABRE stations,
   whose exchange is `HQ`, as a multiplier. The file had 26; `GO`, `FN` and
   `HQ` were added, so a station sending one is no longer refused as an
   improper domestic QTH. Pinned by `uTestShippedDomLists`.
   **ALSO FIXED, found while measuring:** the multiplier was the line's LEFT
   side (the state's NAME), and the domestic table and the sheet both keep
   ten characters, so `Rio Grande do Norte`/`Rio Grande do Sul` were one
   multiplier (`Rio Grande`) and `Mato Grosso`/`Mato Grosso do Sul` another
   (`Mato Gross`): 26 lines loaded as 24 multipliers. NY4I: *"The codes are
   the multipliers. Rio Grande is RN (Norte) and RS (Sul)."* Every line is
   `CODE = CODE, ^Name` now -- 29 distinct multipliers, the code still the
   accepted exchange, the name the remaining-multipliers window's display
   name (`^`, `EnumDOMFILE` -> `AltName`, upper-cased by the loader). LABRE's
   frozen matrix record moves with it (the stored multiplier is the code).
2. **FIXED 2026-10-19. EUDX: `eudx.dom` had `BE011` where the sponsor has
   `BE11`** (East Flanders; <https://www.eudx-contest.com/rules/>, point 7),
   and 28 lines that were not regions: 26 ` = `, `eudx = eudx` and
   `Page = Page`. MEASURED before removal: `EnumDOMFILE` added the left side
   of each to the sheet's domestic list -- an EMPTY multiplier, `eudx` and
   `Page` (279 entries for 276 regions), all listed by the remaining-
   multipliers window (`uRemMults`) -- and `EUDX` and `PAGE` were accepted
   exchanges; because `TContestEUDX` scores a station as in the EU when its
   exchange matched the file, either scored as an EU region (10 points from
   outside the EU). All removed; pinned by `uTestShippedDomLists`.
   **`DK06` ALSO REMOVED** ("Overseas Countries and Territories"): it is in
   the sponsor's 2022-2025 lists (Wayback, 2025-01-27) and gone from the 2026
   rules, which list `DK01`-`DK05`; the UDC agrees, and NY4I confirmed it.
   The file and the sponsor's 2026 list now agree code for code (275
   regions), pinned by the same test.
3. **Winter Field Day: the UDC's section list is the stale one, not TR4W's.**
   It carries `GTA`, `MAR` and `NT`; TR4W's `arrlsect.dom` has `GH`, `NB`, `NS`
   and `TER` -- the current RAC sections. Nothing to change on that account. The
   UDC also lists `DX`; check that TR4W's WFD accepts a DX station by its own
   path, since `arrlsect.dom` has no DX entry.
4. **Jock White Field Day (`NZ FIELD DAY`, Cabrillo `JW-FD`): the UDC validates
   the branch number against a 00-99 list; TR4W loads no domestic file.** A
   lead only if the branch is a multiplier under the NZART rules.
5. **Arktika Spring: the UDC ships a 133-entry list** (`AC1`, `AC2`, ...);
   TR4W loads no domestic file for it. Check the sponsor's multiplier rule.
6. Ural Cup: the UDC limits multipliers to 42 grid fields; TR4W loads every
   field (`grids.dom`). Low priority -- a fixed region list may be the UDC's
   own simplification.

### Cabrillo `CONTEST:` names that differ (18 rows, 14 contests)

| TR4W id | TR4W writes | UDC writes | note |
|---|---|---|---|
| OZHCR-VHF | `OZHCR-VHF` | `OZCHR-VHF` | TR4W's spelling transposes the letters against its own OZCHR and OZCHR-TEAMS; the D7 enum spelling, so a stored name -- an alias question if it changes |
| RU3AX MEMORIAL | `RU3AX MEMORIAL` | `RADIO-160` | three UDC files agree; TR4W's class is the Russian 160-Meter DX Contest |
| EUDX | `EUDX` | `EUDXC` | |
| BATAVIA-FT8 | `BATAVIA` | `BATAVIA-FT8` | TR4W's own id and ADIF id are `BATAVIA-FT8` |
| MST | `MST` | `ICWC-MST` | TR4W's own ADIF id is `ICWC-MST` |
| YOTA | `YOTA-CONTEST` | `YOTA` | |
| IRTS | `IRTS` | `IRTS80M` | |
| CQIR | `CQIR` | `IRTS-CQIR` | the UDC listing calls the event discontinued |
| MWC | `MWC` | `OK1WC` | |
| OK-OM DX SSB | `OK-OM DX SSB` | `OKOM-DX` | the UDC serves both modes |
| UCG | `UCG` | `UCG-Champ` | |
| SALMON RUN | `WA-SALMON-RUN` | `WASHINGTON SALMON RUN` | weak: the UDC listing calls itself a sample |
| MARCONI MEMORIAL | `MARCONI MEMORIAL` | `MARCONI-MEMORIAL` | blank against hyphen only |
| POTA | `POTA` | `POTA-ve3fp` | an author's private name; ignore |

### QSO: line layout (8 leads)

Compared column KINDS (report, serial, other) on each side of the worked call,
TR4W's taken from the contest matrix's frozen Cabrillo for every station
variant. A UDC box such as `Exchange1` may hold a serial or a word, so it
matches either.

- **IRTS:** the UDC writes a serial on both sides; TR4W writes report + QTH only.
- **RTC:** TR4W writes a report; the UDC writes serial + grid without one.
- **ICWC MST:** TR4W writes serial then name; the UDC writes name then serial.
- **PCC:** the UDC sends a member suffix (`/M`) as a third sent column.
- **OK/OM DX SSB, Arktika Spring, RADIO-MEMORY, SRR-JR:** column counts differ
  (county code, serial, silent-key call and age, age respectively).

Each is a lead to check against the sponsor's Cabrillo template.

### Q98 open contests

- **OZHCR-VHF -- the UDC identifies it** (Russian VHF contest of OZCHR): mode
  `BOTH` (all modes), VHF bands only, points by 2 m / 70 cm / 23 cm. This
  supports answering Q98's open mode question with CW and phone, the bands
  being D7's already. Below D7 and the sponsor; a lead.
- **RADIO-YOC -- a probable identification: the Popov Youth Cup.** D7 gives
  RADIO-YOC the exchange serial + previous serial and 3 points a QSO; the
  Popov Youth Cup UDC exchanges serial + last serial received and scores 3 a
  QSO; RADIO-YOC's QRZ.RU id 119 now shows the A.S. Popov Cup. The UDC is SSB
  and points CW users at another module. Confirm before relying on it.
- **JA LONG PREFECT, QCWA GOLDEN, SOUTH AMERICAN WW, UKRAINE CHAMPIONSHIP, WWL:
  no UDC identifies them.** Checked by hand and rejected: the South America CW
  and 10 m SA contests (neither scores D7's 2 / 10 SA split), and the EPC
  Ukrainian DX (a digital DX contest, not a championship).

### Candidates a human must confirm (`match-candidate`)

YBDX against the UDC "YB DX Contest" (same exchange; sponsor not stated);
the RCWC Minitest against TR4W's MINI40 / MINI80 / MINITEST; FISTS Sprint
against FISTS; K1USN SST Open against SST; KCJ Top Band against KCJ; NCCC FT4
Sprint against NCCC Sprint. The rest of the token-overlap candidates are
plainly different events (AMSAT Field Day, SARA Spring Sprint, SP PGA...).

## Limits

- One QSO line per station variant, on the matrix's synthetic data; a column
  the matrix leaves blank in a variant is absent from that variant's layout.
- Bands and modes are reported only where the Q98 table has none.
- A `.sec` is the UDC's validation list; a `.dom`'s left side is the
  multiplier and its right side the accepted spellings. "Not accepted" means
  the UDC spelling is not a TR4W alias, not that the multiplier is missing.
- `not-in-tr4w` is a reference list. NY4I is not adding those contests.

## N1MM built-in contests

**Reading of 2026-10-19, from the N1MM Logger source, c. 2014** -- NY4I's copy,
from a review he did for the N1MM team about twelve years ago. It is not in
this repository and its text must never be. Its Cabrillo names may be stale
against today's sponsors, so where TR4W and N1MM differ, **the sponsor's
current name is the verdict**, and WA7BNM's detail page (which also lists the
names the sponsor's log robot accepts as ALIASES) stands in for the sponsor
where the sponsor publishes none. Authority order: D7 > sponsor's Cabrillo
template > WA7BNM > DXLog > N1MM built-in > UDC. **Nothing here renamed
anything**: a stored name keeps its meaning forever, and a rename (with its
read alias) is NY4I's call.

```
python -I tools/udc/n1mm_builtin.py "C:\projects\N1MMSource\N1MM Logger\Source" ^
       --names <contest-names CSV> --names-out <same CSV> [--fetch-wa7bnm]
```

It wrote `tools/udc/cache/n1mm_builtin.csv` and `n1mm_crosswalk.csv`
(gitignored), and added eight columns to NY4I's contest-names table: N1MM
name / display name / Cabrillo name / mode, UDC Cabrillo name, WA7BNM
Cabrillo name, `Cabrillo agrees?` (TR4W against N1MM) and a Note. See
`tools/udc/README.md`.

### Counts

| | |
|---|---|
| `AddChgContest` calls in the VB source files | 229: **227 parsed, 2 unparsed** |
| unparsed | `ContestInterface.cls` (the plug-in interface template, 9 arguments); `CUserChoice.cls` (the UDC loader -- every argument is a variable) |
| excluded, not VB source | `CDx.cls.bak`, `CQCWAQSO.cls.bak`, `CQSOpartyNR.cls.bak`, `CUserChoice.cls.bak` (13 calls between them), `New contest.wri` |
| branch-dependent calls | `CAA.cls` (continent: WPX prefix or country multiplier) and `CArrlDx.cls` (US/VE or not) -- the same contest under each branch, so one entry each |
| distinct N1MM entries | 223: matched 101, ambiguous 5, unmatched 117 |
| **TR4W contests (187)** | **matched 93, ambiguous 13, unmatched 81** |

Matches by method: `cabrillo-exact` 64, `cabrillo-normalized` 3,
`name-to-id` 4, `display-exact` 3, `curated` 19 (each with its evidence in
`N1MM_CURATED`). The 13 ambiguous TR4W contests are listed, not counted: N1MM
has one module where TR4W has several -- RAC (Canada Day / Winter), the EU
Sprint CW and SSB (spring / autumn), IARU Region 1 Field Day (TR4W's plain
and two RCC runnings), `Mini Test CW` (MINITEST / MINI40 / MINI80) -- and
three RSGB 1.8 MHz entries (CW, 1st, 2nd) for TR4W's one RSGB-160.

Most of the 117 unmatched N1MM entries are events TR4W does not carry (BARTG,
the ARRL Rookie Roundup, DARC 10 m Digi, JARTS, the UK DX, LoTW, the TARA
events...). Of the 81 unmatched TR4W contests, about twenty are state QSO
parties (N1MM has one generic `QSOPARTY` module); the rest are events N1MM
did not carry in 2014 or carries under a name nothing here could tie.

### TR4W and N1MM disagree on 29 Cabrillo names -- the verdicts

TR4W agrees with N1MM on the other 64 matched contests.

| verdict | contests (TR4W writes / N1MM writes / the answer) |
|---|---|
| **TR4W is right** (6) | ALL-ASIAN-DX-CW and -SSB (`AADX-CW` / `AA-CW`: WA7BNM `AADX-CW`, N1MM's is an alias); **AP-SPRINT** (`AP-SPRINT` / `AP-Sprint-CW`, `-SSB`: the sponsor's own rules, revised January 2024, give `CONTEST: AP-SPRINT` for both modes); CWOPEN (`CW-OPEN` / `CWOPS-Open`: WA7BNM `CW-OPEN`); RSGB-ROPOCO-CW (`RSGB-ROLO` / `RSGB-ROPOCO`: WA7BNM `RSGB-ROLO`, the old name an alias); YUDX (`YUDX` / `YU-DX`: WA7BNM `YUDX`) |
| **N1MM writes the primary name; TR4W's is an accepted alias** (6) | BALTIC (`BALTIC-CONTEST`), EUROPEAN HFC (`EUHFC`), HA DX (`HA-DX`), LZ DX (`LZ-DX`), OK-OM DX CW (`OK-OM-DX`), GAGARIN-CUP (`GC`) |
| **neither writes the primary; both are aliases** (4) | CROATIAN (WA7BNM `9A-DX`; `CROATIAN` and N1MM's `9A-CW` both aliases), SP DX (`SPDX`), UN DX (`UN-DX`), WW PMC (`WW-PMC`) |
| **TR4W's name is NOT accepted; N1MM writes the primary** (4) | CQMM (`CQMM` / `CQMMDX`), CWOPS (`CWOPS` / `CW-Ops`; WA7BNM `CW-OPS`, alias `CW-OPS-CWT`), UKRAINIAN (`UKRAINIAN` / `UKRAINIAN-DX`; alias `URDXC`), WRTC (`WRTC` / `IARU-HF`: WRTC is scored inside the IARU HF Championship -- whether TR4W's WRTC should write `IARU-HF` is NY4I's call) |
| **TR4W's name is NOT accepted; N1MM writes an alias** (1) | GACW-WWSA-CW (`GACW-WWSA-CW` / `GACW`; WA7BNM `WWSA`) |
| **unsettled -- no WA7BNM name and no sponsor answer** (6) | BWQP (`FOC-BWQP`: the FOC page names none); QCWA (`QCWAQSO`: the 2021 rules ask only for "Cabrillo format"); RF-CUP-CW / -SSB / -DIG (`RFC-CW` / `-SSB` / `-DIGI`: the rules are on qrz.ru, unreachable from here by design); UKRAINE CHAMPIONSHIP (`UKR-CHAMP-CW` / `-SSB` / `-RTTY`; see Q98 below) |
| **moot -- inactive** (2) | CIS (`CISDX-CW`; inactive since 2004, the sponsor page names none), WWIH (`WW-IH`; inactive, rules PDF gone) |

### TR4W against WA7BNM, where N1MM has nothing to say

WA7BNM gives a Cabrillo name for 126 of TR4W's contests. **TR4W writes
neither that name nor one of its aliases for 18**: the five in the last two
"NOT accepted" rows above, and BCQP (`BC-QSO-PARTY`), CALIFORNIA QSO PARTY
(`CA-QSO-PARTY`), CQ-VHF (`CQ-VHF-SSBCW` -- N1MM's c. 2014 `CQ-VHF` agrees with
TR4W; a guess, unchecked: the name changed when CQ added the separate
`CQ-VHF-DIGI` running), DARC-XMAS (`XMAS`), EUDX (`EUDXC`, as
the UDC said), MST (`ICWC-MST`), IRTS (`IRTS-80-CONTEST`), MARCONI MEMORIAL
(`MMC-HF-CW`), CANADA DAY and CANADA WINTER (`CANADA-DAY`, `CANADA-WINTER`),
RU3AX MEMORIAL (`RADIO-160`, as three UDCs said), TEXAS QSO PARTY (`TXQP`) and
YBDX (`ORARI-DX`). These are the strongest candidates for NY4I's rename list,
each a stored-name decision with a read alias.

**DONE 2026-10-19 -- all 18 renamed** (NY4I: *"do the cabrillo renames"*).
Each class's `GetCabrilloName` now states WA7BNM's name; the left-hand names
above were re-measured from the classes first and all 18 matched the
crosswalk. Only the Cabrillo `CONTEST:` line moves (and LOGSUBS2's UDP
`<contestname>`, which writes the same `CabrilloName`): the stored id
(`ContestTypeSA`), the ADIF `CONTEST_ID` and the display names are separate
literals and did not change. **No read alias was needed**: TR4W has no Cabrillo
import, and every reader of `CabrilloName` writes it.

**TR4W's XMAS contest is NOT the DARC Christmas contest** (NY4I, 2026-10-19),
so it no longer writes `XMAS` beside it. It is the **SSA Jultest** (Sveriges
Sändareamatörer, 25 December 0800-1100 UTC, 80/40 m CW/SSB): RST + serial from
001 + a five-letter group, 2 points per QSO, no multipliers -- this class's
exchange and scoring exactly (`regler.html`, updated 2022-11-01). The sponsor's
Cabrillo page says the name *must* be `SSA-JULTEST`
(https://hfcontest.ssa.se/ssa-jt/ssa-jt-cabrillo.html, updated 2022-11-12);
DXLog's `SSA_JT.txt` and N1MM's `SSA_JT.udc` agree, and WA7BNM does not list
it. `uContestXmas.GetCabrilloName` now writes `SSA-JULTEST`; its stored id and
ADIF id stay `XMAS`. **A data defect stays in that class, reported and not
changed**: its QRZ.RU id 100 is the DARC XMAS Contest page (checked through the
Wayback Machine), the DARC-XMAS row's id copied into this row in D7; the
Jultest's own id is not known.

So **two Cabrillo names are SHARED on purpose**, and no others: WRTC writes
`IARU-HF` as the IARU HF Championship does, and the RSGB RoLo's CW and SSB
runnings both write `RSGB-ROLO`, the one name WA7BNM gives each (refs 77 and
361; this predates the renames). `uTestContestIdentityPin.Test_WA7BNMCabrilloRenamesMoveOnlyTheCabrilloName`
pins all 18 renames and XMAS's, and walks the registry: any other two contests
writing one Cabrillo name fail it. The "NOT accepted" rows in the table above
and this paragraph record the 2026-10-19 reading, before the renames.

### Gaps N1MM fills

**None of the kind asked for: no TR4W contest has a blank Cabrillo name.**
N1MM's value is the 29 disagreements above, and the leads below.

### Q98 open contests

- **UKRAINE CHAMPIONSHIP -- identified, with a scoring question.** N1MM's
  `CUKRChamp.cls` is the "Championship of Ukraine": oblast (two letters) +
  serial, 2 points a QSO, 160 and 80 m, RTTY, CW and SSB, four one-hour
  sessions. D7's row agrees on the exchange (QSONumberDomesticQTHExchange,
  `ukraine.dom`'s two-letter oblasts) and the 2 points. N1MM also adds 10
  points for each oblast per session, where D7 counts domestic multipliers.
  WA7BNM 334, the *Open* Ukraine RTTY Championship (`UKR-CHAMP-RTTY`), scores
  the same 2 + 10 with no multipliers but runs 160-10 m. A lead for Q98's
  bands (160/80) and modes (CW, SSB, RTTY); confirm against the sponsor.
- **SOUTH AMERICAN WW -- WA7BNM accepts TR4W's own Cabrillo name for the WWSA.**
  WA7BNM 45 (GACW WWSA CW, Cabrillo `WWSA`) lists `SOUTH AMERICAN WW` as an
  alias, so the WWSA log robot takes a TR4W log as WWSA. That ties D7's
  contest to the GACW WWSA, which TR4W also carries as GACW-WWSA-CW. But
  today's WWSA scores RST + CQ zone, 0/1/3 and 5 for South America, not D7's
  RST + continent and 2/10. Either the rules changed after D7, or they are two
  events sharing a name. N1MM's `CCQSA.cls` (CQ SA SSB: 10 points to South
  America for non-SA stations) is a weaker lead.
- **QCWA GOLDEN -- no identification.** N1MM carries only the QCWA QSO Party
  (`CQCWAQSO.cls`, matched to TR4W's QCWA). TR4W's QCWA and QCWA GOLDEN score
  identically (2 CW, 1 phone), so N1MM's one module does not separate them.
- **JA LONG PREFECT -- no identification.** N1MM's `CJAdomestic.cls` is a
  generic JA-domestic module (JA works JA; prefecture number + power letter,
  1 point, with an ALL JA example). TR4W's contest exchanges a "long" JA
  prefecture (`jacg3`), so the module does not settle it.
- **OZHCR-VHF, WWL, RADIO-YOC -- nothing in N1MM.** N1MM's `cRRTC.cls` writes
  `OZCHR` for both the RRTC and RRTCT entries (TR4W's OZCHR, matched);
  nothing names the VHF running. WA7BNM's Popov Memorial (`RADIO-POPOV`) is a
  YL event and does not support the Popov Youth Cup lead above.
