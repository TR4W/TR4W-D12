# .dom files against DXLog.net: findings, 2026-10-15

Produced by `python tools/dom-crosscheck/crosscheck_dom_dxlog.py`. Re-run it to update; the tool is
the source of truth, this page is one dated reading of it. NY4I, 2026-10-15: *"it would be good to
validate our DOM files against the dxlog cfg files and also use that to help build any new qso
parties."*

**A difference is a LEAD, not a verdict.** DXLog is another logger's encoding (rule-source order:
Cabrillo spec, WA7BNM / the sponsor, DXLog, then NY4I). Each fix needs the sponsor's page first.

## How the tool works

- **TR4W's side:** the frozen contest-matrix records name the `.dom` each contest loaded for each
  test station, including in-state and out-of-state. The `.dom` files are read the way
  `LOGDOM.EnumDOMFILE` reads them. Includes are followed. Only the aliases after `=` count as
  inputs, and the first match in load order wins.
- **DXLog's side:** the `[MULTIPLIERS START]...[MULTIPLIERS END]` list, which 225 files have.
  **`CFG_MULT_RGX_CHECK` is a fallback only.** It validates the operator's OWN sent QTH in DXLog's
  setup dialog; it is not the multiplier list. Kansas lists its counties only in
  `MULTn_EXCEPTION`.
- **Comparison by meaning, not by spelling.** TR4W names BC `vE7`, so every DXLog key and its
  aliases is fed through TR4W's lookup. The results are: only in DXLog, only in TR4W, merged,
  split, unreachable, and alias collision.
- **Matching contests to DXLog files:** by Cabrillo name, plus a commented override map of 22
  pairs. CIS -> CIS-DX is the weakest pair, since DXLog's only CIS-DX file is the PSK edition.
- `--new-party <DXLog file> [--host Id]` writes a starter `.dom`. It uses TR4W's shared include
  files where DXLog's list contains them whole.

## Summary (2026-10-15)

- 97 contests load a `.dom`.
- 86 matched a DXLog file. 31 are identical and 55 differ.
- 11 had no DXLog file: ARCI, CQIR, RF-CUP-DIG, FISTS, INTERNET SPRINT, JA LONG PREFECT, LOCUST,
  RU3AX, UKRAINE CHAMPIONSHIP, WRTC and SRR-JR.

## Real defects: one typed code reaches the wrong multiplier

The loader takes the first match in load order, and the shared state and province files are
included before the counties. So a county's code that is also a state's alias can never be reached.

| Contest (file) | Typed | Counts as | Should be |
|---|---|---|---|
| Idaho in-state (`idaho.dom`) | MIN | Minnesota | Minidoka |
| Colorado (`colorado.dom`) | CON | Connecticut (`s48.dom`: `Ct = CT, CON`) -- **verified** | Conejos |
| Colorado | MIN | Minnesota | Mineral |
| Missouri (`missouri.dom`) | MIS | Mississippi | Mississippi County |
| Salmon Run in-state (`washington.dom`) | PE | Pend Oreille | Prince Edward Island |
| Virginia (`va.dom`) | ALB | Albemarle | Alberta |
| Wisconsin (`wisconsin.dom`) | MAN | Manitowoc | Manitoba |
| every file including `p13.dom` | LA | Louisiana | NL (p13's own alias) |

Conejos and Mineral (Colorado) and Mississippi County (Missouri) can never be credited.
`jacg3.dom` has hundreds of these collisions, all from city-name prefixes.

## The NA Sprint family (Q88)

- **`naqp.dom`** is used by NAQP CW/SSB/RTTY, NA Sprint CW, NCCC, SST and Sprint SSB.
  - Its header says VE8 and VY1 are one multiplier, but it lists VY1 separately and merges VY0
    into VE8.
  - **No entry accepts `NT`**, so a typed NT is refused in all seven contests.
- **DXLog** counts 50 states, DC and **13** VE multipliers (NL/LB/NF as one). Q88 says the
  sponsor counts 14, so that figure needs re-checking.
- **`s49p8.dom` (NA Sprint RTTY)** has 49 states with no HI, 8 VE and no DC.
- **`s50p13.dom`** says "50 STATES, DC AND 13 PROVINCES" in its header but has no DC entry. No
  contest loads it.

## Counts that differ (sponsor check needed)

- **DC:**
  - TR4W counts DC in-state for Colorado and North Carolina; DXLog does not.
  - NA Sprint RTTY has no DC.
- **Provinces:**
  - Michigan in-state has 11 (no NL, PE or NU input).
  - Florida in-state has 8 (NB merged into NS).
  - Ohio counts NU, YT and OH, where DXLog has 11 provinces and not OH.
  - DXLog has 13 in each case.
- **SST:** TR4W has AK, HI and VE8; DXLog has 48 states plus LB and NT.
- **Own state counted in-state:** IN, TN, VA and TX count their own state; DXLog does not.
- **Host state counted once or per county:**
  - Idaho: TR4W counts ID once, citing the sponsor; DXLog counts each county.
  - The reverse (TR4W per county, or no counties in the in-state list): BC, CO, FL, NY, WI, MN,
    Salmon Run and TX.
- **PA in-state:** DXLog uses ARRL/RAC sections; `pa.dom` uses states and provinces.
- **DX:**
  - DXLog accepts DX, but TR4W's file has no entry: CO, MN and OH.
  - TR4W's file has DX, but DXLog does not: BC, FL, IN7QPNE, IN, NC and NY.

## Spellings and code lists

- **County codes:**
  - Missouri: Holt is HTL in TR4W, HLT in DXLog.
  - OK-OM: VTR in TR4W, VRT in DXLog.
  - IN7QPNE: INDEK in TR4W, INKDE in DXLog.
- **Salmon Run:** FRA, MAS, OKA and THU are not accepted.
- **NEQP:** TR4W spells county-first (`BARMA`), DXLog state-first. Connecticut has 8 old counties
  against 9 planning regions (Q81: the planning regions are right).
- **Lists that have drifted:**
  - RDXC is missing DO, HE, LU and ZP.
  - LABRE is missing GO.
  - King of Spain is missing SMR.
  - ARI is missing SU and still has CI, OG, OT, VS and PS.
  - ARRL 10 has DFE where DXLog has CMX and R1-R3; ARRL 160 is missing R1-R3.
  - UNDX, WW PMC, RSGB 160, NRAU, Gagarin, UBA, MWC and ALL JA also differ.

## File problems

- **`eudx.dom`:** blank ` = ` lines create an empty multiplier, and prose lines containing `=`
  create the junk multipliers `EUDX` and `PAGE`.
- **`YOTA.dom`:** has no `=` line, so it loads nothing. The YOTA class sets the multiplier from
  the age itself.
- **Strays in `target/dom`, none shipped or read:** a mangled-path copy of `missouri_cty.dom`,
  `eudx.dom.new`, `croat.dsm`, `illinois.txt` and `nevada.txt`.

## Not comparable

- **DXLog gives only a pattern or nothing:** IARU, ALRS-UA1DZ, Ural Cup, the RF Championships,
  Winter FD and CIS.
- **Patterns the tool lists rather than guesses:** ARRL FD and SS classes, the EUDX/Gagarin/KCJ/
  WWPMC numbers, NA Sprint's `^[A-Z0-9]{2,3}$`, and others.
