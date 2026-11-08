# TRMASTER.DTA offline builder

Offline tooling to (re)generate `TRMASTER.DTA` without depending on an external
maintainer's pipeline. **Nothing here runs inside TR4W** — run it before a build.

It unions a fresh callsign list (supercheckpartial) with the membership/name
layer (CWops, FOC, HSC), a curated name seed, and curated callsign-history name
files (ICWC-MST, K1USN SST, VE2FK Names) whose on-air names are more precise than
QRZ, optionally prunes lapsed US/UK/CA calls, backfills the rest from QRZ, and
writes the same **K1EA "CT / TRlog" `.dta`** TR4W already reads (no program
changes).

## Files

- **`build_trmaster.cmd`** — the monthly one-command runner. Downloads sources,
  builds, QRZ-fills names, prunes, and deploys to `tr4w\target\TRMASTER.DTA`
  (previous file → `.bak`). Edit the variables at the top. **Start here.**
- **`trmaster_build.py`** — downloads sources, merges, prunes, writes, validates.
- **`trmaster_codec.py`** — reader/writer for the `.dta` format + a self-test.
  `python trmaster_codec.py ../../target/TRMASTER.DTA` reports a field census and
  a read→write→read round-trip (PASS = writer reproduces the same calls, fields,
  and bucket placement the reader sees).
- **`trmaster_names_qrz.py`** — QRZ name resolver. Looks up still-nameless calls
  in a built `.dta` and emits a `CALL,NAME` CSV for `--names-csv`. Name priority:
  **nickname** ("Tom") → `fname` ("Thomas") → the `name` field **if it looks like
  a person, not a club** (recovers DX individuals like `9M2OCX→SHAHRUL`). Names
  are ASCII-folded (José→JOSE) for CW. Creds from `~/qrz_settings.cfg`; its own
  UTF-8 JSON cache with **atomic incremental saves** (kill-safe) and a **180-day
  TTL for names / 30-day for no-name results**. `--cache-only` regenerates the
  CSV from cache with no API calls. **Skips cleanly** (empty CSV, exit 0) with no
  QRZ subscription, so a future maintainer without QRZ can still build.
  With `--geo-out` it also keeps each operator's **grid, state, county and lat/lon
  from the same response** (no extra calls) and writes `CALL,GRID,SECTION` for
  `trmaster_build.py --geo-csv`. See [Grid and section](#grid-and-section-from-qrz).
- **`qrz_geo.py`**, **`county_section.py`** — the pure halves of that: a QRZ cache
  entry → grid + section, and state + county → ARRL/RAC section. Tests:
  `python -I test_qrz_geo.py`, `python -I test_county_section.py`.
- **`check_dta_names.py`** — read-only scan of a `.dta` for names that fail the name
  rule below. `python check_dta_names.py ../../target/TRMASTER.DTA` prints the
  offenders and a count; exit 1 if any. Tests: `python -I test_name_validator.py`.

## Quick start (monthly)

```
build_trmaster.cmd
```

On first run it seeds `seed\TRMASTER_seed.DTA` from the current
`target\TRMASTER.DTA`, then: downloads SCP.DB (+ MASTER.DTA + CWops), builds,
runs QRZ, builds again with names, and deploys. Re-run `trmaster_names_qrz.py`
(step 3) a few times the first month to backfill the ~44k bare calls; the cache
makes later runs fast.

## Format (documented in `trmaster_codec.py`)

- 37×37 = 1,369 buckets (`A–Z 0–9 /`); 5,480-byte offset table (1,369 starts +
  1 end-offset = file size); then null-terminated `call + ^tag fields` records.
- A call is stored in the bucket of **each distinct adjacent char pair**, **except
  `JA`** (deliberately skipped — too common; matches `LogSCP.BestTwoLetters`).
- Field tags (verified against `N4AF`): `=N`/^N = first name (UPPERCASE),
  `=U`/^U = **CWops number**, `=F`/^F = **FOC number**, `=V`/^V = **HSC number**,
  plus Section/CQZone/Grid/ITUZone/Check/QTH/Hits/Speed/etc.

## Sources

- **supercheckpartial MASTER.DTA** — `https://supercheckpartial.com/downloads/MASTER.DTA`
  (calls only; the SCP coverage layer, ~50k). Read directly by the codec.
- **supercheckpartial SCP.DB** — `https://supercheckpartial.com/downloads/SCP.DB`
  (SQLite; `callsigns` ~69k with `verified` bitmask). Used for the QRZ-verified
  prune. Note: its `annual_rate` is **lifetime QSOs ÷ years active** — a lifetime
  average with **no recency**, so it can't tell active-now from long-lapsed.
- **CWops roster CSV** — Google Sheets `…/export?format=csv`. Positional columns
  (no header): `[2]=call, [3]=CWops#, [4]=first name`. Refreshed every run.
- **FOC / HSC** — seeded from the curated seed file (no live feed: the FOC page is
  a Cloudflare/AJAX wall). Override with `--foc-csv` / `--hsc-csv CALL,NUM[,NAME]`.
- **Callsign-history name files** — N1MM-style `CALL,NAME,...` text files kept in
  `seed\` (`ICWC-MST-*.txt`, `K1USNSST-*.txt`, `Names_VE2FK-*.txt`). Curated
  on-air CW names (nicknames), **more precise than QRZ**. Passed via `--history-glob
  PATTERN` (repeatable; pattern order = priority, ICWC > K1USN > VE2FK). Each
  pattern resolves to its **single newest** match, so **dropping an updated copy
  into `seed\` each month supersedes the prior one** — a name corrected/removed in
  the new file is not resurrected from a stale old copy. Like the CWops/FOC/HSC
  rosters, these calls **expand** the TRMASTER universe (curated → never pruned).

## Pruning lapsed calls (`--prune-qrz-unverified SCP.DB`)

Drops calls SCP.DB marks **not QRZ-verified** — but **only US/UK/CA** prefixes
(`K/N/W/AA-AL`, `G/M/2E/2I/2M/2U/2W`, `VA/VE/VO/VY`), where QRZ/licensing coverage
is comprehensive enough that "not QRZ-verified" means lapsed/invalid. **DX calls
are always kept** (QRZ is not a definitive source outside those regions), and
curated CWops/FOC/HSC/seed calls are never pruned. In practice this removes
~158 dead US/UK/CA calls while keeping ~1,822 valid DX without QRZ pages.

## Name augmentation

The bare SCP calls have no name. **QRZ** (`trmaster_names_qrz.py`) is the source:
it has the on-air **nickname** *and* covers **international** calls. Credentials in
`~/qrz_settings.cfg`. No subscription → it skips and calls stay bare (fine for SCP).
*(FCC ULS `en.first_name` is a US-only fallback if ever needed — gives the formal
name, not the nickname — exportable to a `--names-csv`.)*

## Merge precedence (per call)

Name precedence, highest → lowest: **CWops > FOC > history > seed > QRZ**.

1. curated **seed** (preserve accumulated Name + memberships + orphan names)
2. **callsign-history files** → Name (curated on-air names; **override** the
   accumulated seed/QRZ name, but the authoritative CWops/FOC rosters below still
   win). Within the history layer the first file to name a call wins (ICWC >
   K1USN > VE2FK). These calls also expand the universe.
3. CWops CSV → `User1` (CWops #) + Name (current roster wins)
4. FOC → `FOC` # + Name (roster name wins over history)
5. HSC → `User2` (HSC #)
6. `--names-csv` (QRZ) fills any remaining nameless call
7. `--geo-csv` (QRZ) fills an **empty** `Grid` / `Section` slot; a value already in the
   seed is curated and is never overwritten

## Name validator (issue 239)

One rule, `trmaster_build.valid_name`, gates **every** name before it is merged: the
CWops roster, the FOC/HSC exports, the history files, `--names-csv` (QRZ) **and the
names carried forward from the previous DTA / seed**. A name is accepted only if it
is words of `A-Z` joined by a single space, hyphen or apostrophe (`ED`, `MARY-ANN`,
`O'BRIEN`, `JEAN PIERRE`), with at least 2 letters. No digits, no other punctuation,
no leading/trailing/doubled separator, no non-ASCII (the `.dta` is single-byte
uppercase).

A rejected name is **logged with its call and source** (`rejected name '2A' for PS2CIA
from names csv (QRZ)`) and simply not stored, so the call **falls through to the next
source** in the order above: a junk CWops name keeps the member's number and lets the
history/seed/QRZ name stand; a junk name in the old DTA is dropped, never carried
forward. Inside the history layer a junk name in ICWC lets K1USN/VE2FK name the call.

Why: the program reads operator names from TRMASTER.DTA, and POTA's free-form
exchange accepted a class word (`2A`) as the operator. Measured on the 2026-11-07 DTA
(1,368 of 64,018 names invalid): nearly all came from the **QRZ cache** -- QRZ
`2ª Cia. Com` folded to `2A`, `NIGHTOWL（夜猫）` to `NIGHTOWL()`, `宇(YU)` to `(YU)`,
`QRA: TORRES...` to `QRA:`, plus a callsign or `146TH` in the name field -- and were
then carried forward. The rest were accented CWops names (`JÜRGEN` read as
`J?RGEN`) and one-letter history names.

Audit an existing file (read-only; it never changes the `.dta`):

```
python check_dta_names.py ../../target/TRMASTER.DTA --limit 0
```

Calls present only in the SCP source stay **bare** — still work for Super Check
Partial, just no prefill.

## Self-reference / what to back up

`build_trmaster.cmd` reads a **frozen** `seed\TRMASTER_seed.DTA` (created once) and
*writes* `target\TRMASTER.DTA`. There is **no read-from-and-write-to-`target`
loop**, so the monthly `target` output is fully regenerable and you do **not** need
to keep old copies (one `.bak` is kept for rollback). The files that carry
non-regenerable history — **back these up**:

- `seed\TRMASTER_seed.DTA` — frozen curated names / FOC / HSC / orphan names.
- `seed\ICWC-MST-*.txt`, `seed\K1USNSST-*.txt`, `seed\Names_VE2FK-*.txt` — the
  curated callsign-history name files (drop updated copies here monthly).
- `~\.publicLogProcessor\qrz_name_cache.json` — accumulated QRZ lookups (the
  expensive part; otherwise re-querying ~44k calls).

Caveat: FOC/HSC are frozen at the seed snapshot (no live roster feed); CWops is
refreshed live each run; QRZ names grow via the cache. Re-baseline the seed
(`copy target → seed`) only as a deliberate choice.

## `arrl-sections-counties.json` — county to ARRL/RAC section

Supplied by NY4I (2026-11-01); it rarely changes. A state or province maps either
straight to its section (`"OH": "OH"`) or, for the nine whose sections split inside
the state (CA, FL, MA, NJ, NY, ON, PA, TX, WA), county by county
(`"CA": {"Alameda": "EB", ...}`). `county_section.py` reads it: QRZ's county spelling
is matched to these names (case, "St."/"Saint"/"Ste.", "County"/"Parish"/"Borough"
suffix, hyphens, accents) and a split state with an unmatched county gives **no
section, never a guess**. `python check_county_sections.py` checks that every section
it names is one `target/dom/arrlsect.dom` accepts. Turn it into a Pascal unit only if
the program itself ever needs the lookup at run time.

## Grid and section from QRZ

One `.DTA` serves 4.x and 5.x: the record already has a **Grid (^G, string[6])** and
a **Section (^A, string[5])** slot, and the 4.x and 5.x `logscp.pas` decode both the
same way (verified 2026-11-01; the shipped file simply never carried them). Nothing
in the record layout changes.

```
python trmaster_names_qrz.py --dta _work\TRMASTER_new.DTA --all ^
    --out _work\qrz_names.csv --geo-out _work\qrz_geo.csv --limit 2000 --sleep 0.2
python trmaster_build.py ... --names-csv _work\qrz_names.csv --geo-csv _work\qrz_geo.csv
```

Run the resolver with `python` (not `-I`): it imports its sibling modules.

- **`--all` is needed** to resolve calls that already have a name; without it the
  resolver only visits nameless calls.
- **Grid** is QRZ's `<grid>`, stored Maidenhead style (`EL88`, `EL88ab`), never longer
  than 6; if QRZ has none the 4-character square is derived from its lat/lon.
- **Section** is the county crosswalk above, for a US/Canada/US-territory country only.
  QRZ gives no county for Canada, so the Ontario calls (a split province) get **no
  section** by design.
- **Cache freshness:** names are unchanged. Geo has its own stamp (`geo_ts`,
  `--geo-max-age-days`, default 365). An entry cached before this change has none and
  is re-fetched **only** when `--geo-out` is given, so a names-only run never spends a
  lookup on geo.
- **Measured 2026-11-01 on 300 calls** (230 US, 35 VE, 35 other): US grid 228/230, county
  228/230, section 228/230 (the 2 misses were not on QRZ); VE grid 35/35, section
  22/35 (the 13 Ontario calls); all 296 grids QRZ supplied were 6 characters; no US
  county failed to match the crosswalk. About 0.53 s per call at `--sleep 0.2`, so a
  full ~67k pass is roughly 10 hours: run it in `--limit` batches, the cache accumulates.

## `_work/`

Scratch dir for downloads + caches; git-ignored. Never commit downloaded data.

## Status / follow-ups

- Codec round-trip **proven** vs the shipped `TRMASTER.DTA` (6,354 calls); reads
  supercheckpartial's foreign `MASTER.DTA` (50,015 calls) cleanly.
- Current build: ~53k calls, ~8.6k named, US/UK/CA prune, validated.
- TODO: live FOC/HSC roster feeds; optional — measure live SCP lookup speed with
  the larger file before making it the default.
