# Callsign Lookup Database (`fcc_lookup.sqlite`)

A small, read-only SQLite database for looking up a US or Canadian amateur
radio call sign and getting the licensee's name, city, state/province,
ZIP/postal code, **county** and **ARRL/RAC section**. It is built from the FCC
ULS data (US) and ISED's amateur file (Canada) by `lookup_build.py` and meant to
be downloaded by applications (for example TR4W) from a website, because it is
too big to ship in an installer.

This document has two audiences:

- [For application developers](#for-application-developers) - how to download,
  verify and query it.
- [For the maintainer](#for-the-maintainer) - how it is built, scheduled and
  published.

---

## For application developers

### Published files

Two files are published side by side at the same URL prefix:

| File | Purpose |
|---|---|
| `manifest.json` | ~600 bytes. Fetch this first to see whether a new build exists. |
| `fcc_lookup.sqlite.gz` | The gzip-compressed database (~33 MB; ~88 MB once unpacked). |

`manifest.json`:

```json
{
  "schema_version": 2,
  "built_at_utc": "2026-11-18T05:50:18Z",
  "fcc_source_last_modified": "Sun, 15 Nov 2026 14:09:11 GMT",
  "ised_source_last_modified": "Tue, 17 Nov 2026 07:00:01 GMT",
  "crosswalk_sha256": "...",
  "row_count": 914361,
  "db_file": "fcc_lookup.sqlite",
  "db_size": 88100864,
  "db_sha256": "...",
  "gz_file": "fcc_lookup.sqlite.gz",
  "gz_size": 33392304,
  "gz_sha256": "..."
}
```

### Recommended client flow

1. Download `manifest.json` (cheap; do this at most once a day).
2. If `schema_version` is higher than the version your code understands, stop
   and tell the user to update the application.
3. If `built_at_utc` is not newer than the copy you already have, you are done.
4. Download `fcc_lookup.sqlite.gz` to a temporary file. Check its size and
   `gz_sha256` against the manifest.
5. Decompress to a temporary file next to the final location and (optionally)
   check `db_sha256`.
6. Replace the old database by renaming the temporary file over it. Never
   write into the database file you have open. Close your connection first.

The FCC refreshes its full data file weekly and ISED refreshes the Canadian file
daily, so a build can change daily even though the US data changes weekly.

### Opening it

Open **read-only** - the file is a static snapshot:

```
file:fcc_lookup.sqlite?mode=ro
```

The file is not in WAL mode and has no `-wal`/`-shm` sidecar files.

### Schema (`schema_version` 2)

```sql
CREATE TABLE callsign (
   call_sign      TEXT PRIMARY KEY,   -- upper case, e.g. 'NY4I', 'VE3AA'
   country        TEXT,               -- 'US' (FCC) or 'CA' (ISED)
   first_name     TEXT,               -- individuals
   mi             TEXT,               -- US only
   last_name      TEXT,
   entity_name    TEXT,               -- clubs / organisations
   city           TEXT,
   state          TEXT,               -- US state (incl. DC, PR, VI, GU, AS, MP, AA/AE/AP) or Canadian province
   zip5           TEXT,               -- US only: 5 digits, NULL if blank/invalid
   zip_plus4      TEXT,               -- US only: 4 digits when the FCC gave ZIP+4
   postal_code    TEXT,               -- Canada only: 6 chars, no space, e.g. 'B3H1T5'
   county_fips    TEXT,               -- US only: 5-digit state+county FIPS, e.g. '12103'
   county_name    TEXT,               -- US county ('Pinellas County') or Ontario census division ('Peel')
   arrl_section   TEXT,               -- e.g. 'WCF', 'NS', 'GH'; NULL if it cannot be determined
   operator_class TEXT,               -- US only: E=Extra G=General T=Technician A=Advanced N=Novice
   qualifications TEXT,               -- Canada only: letters, A=Basic B=5wpm C=12wpm D=Advanced E=Basic+Honours
   applicant_type TEXT                -- I=Individual B=Club (US also M=Military R=RACES G=Government)
) WITHOUT ROWID;

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT) WITHOUT ROWID;
-- meta keys: schema_version, built_at_utc, fcc_source_last_modified,
--            ised_source_last_modified, crosswalk_sha256, row_count
```

Only **active** US licenses (about 822,000) and every Canadian record in ISED's
public file (about 92,000) are included. Street address, email and phone are
deliberately **not** included, and are never read into the build's scratch
database. About 23% of Canadian records have no postal code and about 2% no
province: ISED omits those details for licensees who opted out of publication.

### Looking up a call sign

```sql
SELECT call_sign, first_name, last_name, city, state, zip5,
       county_name, arrl_section, operator_class
FROM callsign
WHERE call_sign = 'NY4I';
```

- Call signs are stored upper case; upper-case the input.
- Matching is exact. Strip portable suffixes/prefixes first (`W1AW/4`,
  `KH6/NY4I`) and look up the base call.
- No row means "not an active US or Canadian license" (expired, unlicensed, or
  from another country).

### When `county_name` / `arrl_section` is NULL

Do not treat NULL as an error; fall back to asking the operator.

| Situation | county | section |
|---|---|---|
| Normal | set | set |
| ZIP missing, or ZIP not in the Census/GeoNames data (~2,300 licensees) | NULL | NULL for FL/CA/TX/NY/NJ/MA/PA/WA; the state's section elsewhere |
| ZIP's county is in a different state than the licensee's address (ZIP straddles a state line, ~500) | NULL | same as above |
| Military (AA, AE, AP) | -- | NULL (not in the crosswalk) |
| Canada, province with one section (all but Ontario) | -- | set (NB, NS, PE, NL, QC, MB, SK, AB, BC; TER for NT/NU/YT) |
| Canada, Ontario, postal code resolved (~79% of Ontario records) | census division | GH / ONE / ONN / ONS |
| Canada, Ontario, no postal code (~5,200, ISED opt-outs), postal code unknown to GeoNames (~260), or postal code that is not an Ontario one (~10) | NULL | NULL |
| Canada, province missing (~2,000 records) | -- | NULL |

States with a single ARRL section always get a section from the state alone,
even when the county is unknown.

### How county and section are derived (accuracy limits)

- **US county** comes from the **ZIP code**, not the street address. Each ZIP goes
  to the county that holds most of its land (2020 Census ZCTA-to-county
  relationship file); ZIPs the Census file lacks use the GeoNames county code.
  A licensee near a county line may land in the neighbouring county.
- **Ontario** has no county in ISED's file. Its postal code is looked up in
  GeoNames (one point per postal code), and that point is tested against
  Statistics Canada's 2021 census division polygons. The division name is then
  looked up in `arrl-sections-counties.json`. If any step fails the section stays
  NULL: it is never guessed. A postal code whose point lies close to a division
  line can land in the neighbouring division. Judge a record by its postal code,
  not by ISED's `city`, which is the mailing city and is often stale. Checked
  against QRZ: of the calls ISED lists in Toronto, Brampton or Hamilton whose
  postal code resolves elsewhere, VA3CQM is in Mississauga, VA3CWZ in Tichborne
  and VA3GDE in Kingsville, and VA3JLE's QRZ coordinates fall in the division its
  postal code gives (Halton). The postal code was right each time.
- **Section** comes from `arrl-sections-counties.json` (state + county -> ARRL
  section). A section is therefore only as precise as the ZIP-to-county or
  postal-code-to-division step. It is a convenience default for contest
  exchanges; the operator can always correct it.
- Two JSON names are finer than a census division: **Algonquin Park** (ONE) and
  **Killarney** (ONN). A postal code inside either gets the section of the
  census division that contains its point.

### Attribution

County and ZIP data derives from US Census Bureau files (public domain) and
GeoNames postal-code data, which is licensed **CC-BY 4.0**
(https://www.geonames.org). Applications redistributing the database should
credit GeoNames. US license data is from the FCC ULS public bulk files; Canadian
data is from Innovation, Science and Economic Development Canada's public
amateur radio file (https://apc-cap.ic.gc.ca/datafiles/amateur_delim.zip),
published under the Open Government Licence - Canada. Ontario census division
boundaries are Statistics Canada's 2021 Census boundary files, also under the
Statistics Canada Open Licence.

---

## For the maintainer

### Files (in `tools/trmaster/`)

| File | Role |
|---|---|
| `lookup_build.py` | Builds and publishes the database (this is what you schedule). |
| `fcc_import.py` | Reads the active licences from FCC's `l_amat.zip` (call, name, city, state, ZIP, class, type only). |
| `ca_divisions.py` | Ontario postal code -> census division (shapefile reader, Lambert projection, point-in-polygon). |
| `county_section.py` | County/division -> section, from `arrl-sections-counties.json` (shared with the TRMASTER build). |
| `arrl-sections-counties.json` | **Single source of truth** for county -> section. Edit it directly. |
| `test_lookup_build.py`, `test_ca_divisions.py` | `python -I test_lookup_build.py`, `python -I test_ca_divisions.py` |

Run `lookup_build.py` with `python`, **not** `python -I`: it imports its sibling
modules. (The tests insert their own folder into the path, so `-I` is fine
there.)

### One-time setup: the Statistics Canada boundary file

Download **2021 Census Boundary Files**, **English**, **SHP**, Cartographic
Boundary File, **Census divisions**, from the Statistics Canada "Boundary files,
2021 Census" page. The zip is named `lcd_000a21a_e.zip` (about 11 MB) and contains
`.shp .shx .dbf .prj .xml`. Put it in `<workdir>/geo/` (default `_work/geo/`) or pass
`--census-divisions PATH`. It only changes at the five-yearly census. The build
fails, rather than publishing a database with no Ontario sections, if the file is
missing. (Statistics Canada answers a script's download with 403, so this one is
fetched by hand.)

The Ontario census division names in the file must match the names in the JSON.
Two do not and are aliased in `ca_divisions.DIVISION_ALIASES`
(Greater Sudbury / Grand Sudbury; Haldimand-Norfolk, whose two halves are both
ONS). `test_real_file_names_and_points` checks every division against the JSON.

### What a run does

1. `HEAD` the FCC full file `l_amat.zip` and ISED's `amateur_delim.zip` and read their `Last-Modified`.
2. Compare with `manifest.json` in the output folder. If both source files, the
   crosswalk JSON (sha256) and `SCHEMA_VERSION` are all unchanged, **exit 0
   immediately** - a daily run is then two HTTP requests. (A changed boundary
   file is not detected; use `--force` after replacing it.)
3. Otherwise download `l_amat.zip` (~200 MB) and the Census/GeoNames files
   (cached in `--workdir/geo`; a failed download falls back to the cache).
4. Import the active FCC licences into a scratch database (`fcc_import`).
5. Build the slim `callsign` table: US ZIP -> county -> section; Canada province
   -> section, Ontario by census division.
6. Refuse to publish if fewer than 500,000 US rows or 50,000 Canadian rows came out.
7. gzip, then atomically replace `fcc_lookup.sqlite.gz`, then write
   `manifest.json` **last**, so a client never sees a manifest that points at a
   half-written file. A failed run leaves the previously published files alone.

A full build takes about 45 seconds and needs ~1 GB of temporary disk.

### Command line

```
python lookup_build.py --output-dir D:\site\downloads\fcc --workdir D:\work\fcc
```

| Option | Meaning |
|---|---|
| `--output-dir` | Folder the website serves (gets the `.gz` and `manifest.json`). Default `dist`. |
| `--workdir` | Scratch and cache folder. Default `_work`. |
| `--crosswalk` | Alternative `arrl-sections-counties.json`. |
| `--census-divisions PATH` | The Statistics Canada boundary zip (default `<workdir>/geo/lcd_000a21a_e.zip`). |
| `--force` | Rebuild even if nothing changed. |
| `--zip-file PATH` | Use an already-downloaded `l_amat.zip` (implies `--force`). |
| `--ised-zip PATH` | Use an already-downloaded ISED `amateur_delim.zip`. |
| `--keep-work` | Keep the scratch DB and zip for inspection. |

Exit code is 0 when the build succeeded or nothing needed doing, 1 on error.
Standard output is timestamped and suitable for a scheduler log.

### Scheduling (Windows Task Scheduler)

Daily at 03:30, logging to a file:

```
schtasks /Create /TN "Callsign lookup DB" /SC DAILY /ST 03:30 ^
  /TR "cmd /c cd /d C:\tr4w-d12\tr4w\tools\trmaster && python lookup_build.py --output-dir D:\site\downloads\fcc --workdir D:\work\fcc >> D:\work\fcc\build.log 2>&1"
```

Do not let two runs overlap (there is no lock file); a daily schedule with a
~1 minute run is safe. If the website folder is synced elsewhere (rsync, scp,
upload), run that sync as a second scheduled step or at the end of the same
command, after the build returns 0.

### Maintaining the crosswalk

Edit `arrl-sections-counties.json` and rerun; the changed file hash forces a
rebuild on the next run. County names are matched after normalisation by
`county_section.county_key` (accents, case, "County"/"Parish"/"Borough" suffix,
"St."/"Saint", punctuation), so use the Census spelling. Hawaii and the US
Pacific possessions (HI, GU, AS, MP, UM) are all section PAC. Known gap:
military codes (AA, AE, AP) have no section.

### Changing the layout

Bump `SCHEMA_VERSION` in `lookup_build.py` whenever the table layout changes.
Clients compare it with the version they understand. Update this document in
the same change.

### Data sources

| Data | Source |
|---|---|
| US licenses | `https://data.fcc.gov/download/pub/uls/complete/l_amat.zip` (weekly) |
| Canadian licenses | `https://apc-cap.ic.gc.ca/datafiles/amateur_delim.zip` (daily) |
| County list | Census 2020 `national_county2020.txt` |
| ZIP -> county | Census 2020 `tab20_zcta520_county20_natl.txt` |
| ZIP fallback | GeoNames `US.zip` (CC-BY 4.0) |
| Canadian postal code -> coordinates | GeoNames `CA_full.csv.zip` (CC-BY 4.0) |
| Ontario census divisions | Statistics Canada `lcd_000a21a_e.zip` (hand-downloaded once) |
| County -> section | `arrl-sections-counties.json` |

The FCC's server answers a custom `User-Agent` with 403 but accepts Python's
default, so `lookup_build.py` downloads with `user_agent=None`.

The ZIP-to-county rule is the same one used by the `hamlicenselookup` project
(`src/geo/build.js`). If one changes, change the other.
