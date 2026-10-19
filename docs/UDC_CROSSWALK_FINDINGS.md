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
against a higher source, never a verdict, and nothing here changed any code,
`.dom` or class.

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

1. **LABRE DX: `brazil.dom` has no Goias (`GO`).** It holds 26 multipliers;
   Brazil is 26 states plus the Federal District, and DF is present, so GO is
   the one missing. The UDC's state list carries GO (and `HQ`, presumably the
   LABRE headquarters station). Strongest data lead in this reading.
2. **EUDX: `EUDX.dom` has `BE011` where the UDC has `BE11`** -- probably a typo
   for Belgian region 11. The same file also carries entries that are not
   regions: `eudx = eudx`, `Page = Page`, and 26 blank ` = ` lines, all read by
   the loader as entries (`logdom.EnumDOMFILE` takes every line holding `=`).
   Whether `EUDX`, `PAGE` or an empty multiplier then reaches the remaining-
   multipliers list was not checked here. The UDC lacks `DK06`, which TR4W has.
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
