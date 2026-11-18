#!/usr/bin/env python3
"""
lookup_build.py
---------------
Builds the shippable callsign lookup database (fcc_lookup.sqlite) for the TR4W
website: every active US licence (FCC ULS) and every Canadian licence (ISED),
with the licensee's county and ARRL/RAC section.

   US      county  = ZIP code -> county (Census / GeoNames)
           section = county -> arrl-sections-counties.json
   Canada  section = province; Ontario by census division (postal code ->
           GeoNames coordinates -> Statistics Canada boundary polygons)

Designed to be run daily by a scheduler.  It reads the Last-Modified header of
the FCC and ISED files and exits immediately (exit 0) when nothing changed
since the last published build, so an idle day is two HTTP requests.

Outputs (in --output-dir), replaced atomically; a failed run leaves the
previous files untouched and exits non-zero:
   fcc_lookup.sqlite.gz   compressed database
   manifest.json          version/date/size/sha256 so clients can check for
                          updates and verify the download (written last)

Usage:
   python lookup_build.py [--output-dir dist] [--workdir _work] [--force]

The Statistics Canada boundary zip (lcd_000a21a_e.zip) is a one-time download
placed in <workdir>/geo/; see LOOKUP_DB.md.  Standard library only.
"""

import argparse
import csv
import gzip
import hashlib
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import ca_divisions
import county_section
import fcc_import
import trmaster_build

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Bump when the shipped table layout changes (clients check this).
SCHEMA_VERSION = 2

DB_NAME = "fcc_lookup.sqlite"
GZ_NAME = DB_NAME + ".gz"
MANIFEST_NAME = "manifest.json"
BOUNDARY_NAME = "lcd_000a21a_e.zip"

# 2020 Census files: the county list and the ZIP (ZCTA) -> county relationship.
COUNTY_LIST_URL = "https://www2.census.gov/geo/docs/reference/codes2020/national_county2020.txt"
ZCTA_REL_URL = "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt"
# GeoNames fills in ZIPs the Census ZCTA file lacks, and gives Canadian postal coordinates.
GEONAMES_US_URL = "https://download.geonames.org/export/zip/US.zip"
GEONAMES_CA_URL = "https://download.geonames.org/export/zip/CA_full.csv.zip"

# ISED (Canada) amateur callsign file, refreshed by ISED daily.
ISED_URL = "https://apc-cap.ic.gc.ca/datafiles/amateur_delim.zip"

# Sane lower bounds; a build with fewer rows is treated as a failed build.
MIN_EXPECTED_ROWS = 500_000
MIN_EXPECTED_CA_ROWS = 50_000

BATCH_SIZE = 5000

SLIM_SCHEMA_SQL = """
CREATE TABLE callsign (
   call_sign      TEXT PRIMARY KEY,
   country        TEXT,   -- 'US' (FCC) or 'CA' (ISED)
   first_name     TEXT,
   mi             TEXT,
   last_name      TEXT,
   entity_name    TEXT,
   city           TEXT,
   state          TEXT,   -- US state, or Canadian province
   zip5           TEXT,   -- US only
   zip_plus4      TEXT,   -- US only
   postal_code    TEXT,   -- Canada only, 6 chars, no space
   county_fips    TEXT,   -- US only
   county_name    TEXT,   -- US county, or Ontario census division
   arrl_section   TEXT,
   operator_class TEXT,   -- US only (E/G/T/A/N)
   qualifications TEXT,   -- Canada only: letters A-E, e.g. 'ACD'
   applicant_type TEXT    -- I=Individual, B=Club, ...
) WITHOUT ROWID;

CREATE TABLE meta (
   key   TEXT PRIMARY KEY,
   value TEXT
) WITHOUT ROWID;
"""

SLIM_COLUMNS = ("call_sign", "country", "first_name", "mi", "last_name",
                "entity_name", "city", "state", "zip5", "zip_plus4", "postal_code",
                "county_fips", "county_name", "arrl_section", "operator_class",
                "qualifications", "applicant_type")


def log(message):
   print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {message}", flush=True)


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def sha256_file(path):
   digest = hashlib.sha256()
   with open(path, "rb") as fh:
      for chunk in iter(lambda: fh.read(1024 * 1024), b""):
         digest.update(chunk)
   return digest.hexdigest()


def write_json_atomic(path, data):
   part = path.with_name(path.name + ".part")
   part.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
   os.replace(part, path)


def remote_last_modified(url):
   """The Last-Modified header of *url*, or None if it cannot be read."""
   try:
      request = urllib.request.Request(url, method="HEAD")
      with urllib.request.urlopen(request, timeout=60) as response:
         return response.headers.get("Last-Modified")
   except Exception as exc:
      log(f"WARNING: could not read Last-Modified from {url}: {exc}")
      return None


def fetch_cached(url, dest):
   """
   Download *url* to *dest* (trmaster_build.download writes through a .part
   file, so a failure leaves any earlier copy intact).  If the download fails
   and an earlier copy exists, use it: these files change rarely.
   """
   try:
      trmaster_build.download(url, str(dest), force=True, user_agent=None)
   except Exception as exc:
      if not dest.exists():
         raise RuntimeError(f"Could not download {url} and no cached copy: {exc}") from exc
      log(f"WARNING: download of {url} failed ({exc}); using cached {dest}")
   return dest


# ---------------------------------------------------------------------------
# ZIP -> county
# ---------------------------------------------------------------------------

def read_lines(path, encoding="utf-8-sig"):
   with open(path, encoding=encoding, newline="") as fh:
      for line in fh:
         yield line.rstrip("\r\n")


def load_counties(path):
   """geoid (5-digit FIPS) -> (state abbr, county name), from the Census county list."""
   counties = {}
   for line in read_lines(path):
      f = line.split("|")
      if len(f) < 5 or f[0] == "STATE":
         continue
      counties[f[1] + f[2]] = (f[0], f[4])
   return counties


def load_zip_counties(rel_path, geonames_zip, counties):
   """
   zip5 -> county geoid.  Each ZIP goes to the county holding most of its land
   (Census ZCTA relationship file).  ZIPs absent from that file fall back to
   the GeoNames county code.  Same rules as hamlicenselookup's src/geo/build.js.
   """
   best = {}
   cols = None
   for line in read_lines(rel_path):
      if not line:
         continue
      f = line.split("|")
      if cols is None:
         cols = {
            "zcta": f.index("GEOID_ZCTA5_20"),
            "county": f.index("GEOID_COUNTY_20"),
            "area": f.index("AREALAND_PART"),
         }
         continue
      zcta = f[cols["zcta"]]
      if not zcta:
         continue
      area = int(f[cols["area"]] or 0)
      current = best.get(zcta)
      if current is None or area > current[1]:
         best[zcta] = (f[cols["county"]], area)

   zip_county = {z: geoid for z, (geoid, _) in best.items() if geoid in counties}

   # GeoNames US.txt columns: country, postal, place, admin1 name, admin1 code
   # (state), admin2 name, admin2 code (3-digit county FIPS), ...
   fips_by_state = {state: geoid[:2] for geoid, (state, _) in counties.items()}
   with zipfile.ZipFile(geonames_zip) as zf:
      with zf.open("US.txt") as raw:
         for line in raw.read().decode("utf-8").splitlines():
            f = line.split("\t")
            if len(f) < 7 or not re.fullmatch(r"\d{5}", f[1]):
               continue
            if f[1] in zip_county:
               continue
            state_fips = fips_by_state.get(f[4])
            if state_fips and re.fullmatch(r"\d{3}", f[6] or ""):
               geoid = state_fips + f[6]
               if geoid in counties:
                  zip_county[f[1]] = geoid
   return zip_county


def split_zip(zip_code):
   """(zip5, plus4) from an FCC zip_code value; None where not valid."""
   z = (zip_code or "").strip()
   zip5 = z[:5] if re.fullmatch(r"\d{5}(\d{4})?", z) else None
   plus4 = z[5:9] if zip5 and len(z) == 9 else None
   return zip5, plus4


# ---------------------------------------------------------------------------
# Rows
# ---------------------------------------------------------------------------

def insert_sql():
   names = ", ".join(SLIM_COLUMNS)
   params = ", ".join(":" + c for c in SLIM_COLUMNS)
   return f"INSERT OR REPLACE INTO callsign ({names}) VALUES ({params})"


def callsign_row(**fields):
   """A full row dict; columns not supplied (e.g. US-only ones for Canada) are NULL."""
   unknown = set(fields) - set(SLIM_COLUMNS)
   if unknown:
      raise ValueError(f"unknown columns: {sorted(unknown)}")
   return {c: fields.get(c) for c in SLIM_COLUMNS}


# ---------------------------------------------------------------------------
# Canada (ISED amateur_delim.txt)
# ---------------------------------------------------------------------------

ISED_FILE = "amateur_delim.txt"
QUALIFICATION_FIELDS = (("A", "qual_a"), ("B", "qual_b"), ("C", "qual_c"),
                        ("D", "qual_d"), ("E", "qual_e"))


def read_canadian_records(zip_path):
   """Parse ISED's semicolon-delimited amateur file into a list of dicts."""
   with zipfile.ZipFile(zip_path) as zf:
      raw = zf.read(ISED_FILE)
   try:
      text = raw.decode("utf-8-sig")
   except UnicodeDecodeError:
      text = raw.decode("cp1252")
   reader = csv.DictReader(text.splitlines(), delimiter=";", quoting=csv.QUOTE_NONE)
   return list(reader)


def insert_canada(dst, records, table, division_for=None):
   """
   Insert ISED records.  *division_for(postal_code)* returns the census
   division name for an Ontario postal code (or None); it is used only for
   provinces whose section depends on the county/division (Ontario).
   """
   stats = {"rows": 0, "no_province": 0, "no_postal": 0, "no_section": 0,
            "no_division": 0}
   batch = []
   sql = insert_sql()
   for r in records:
      call = (r.get("callsign") or "").strip().upper()
      if not call:
         continue
      province = (r.get("prov_cd") or "").strip().upper() or None
      postal = (r.get("postal_code") or "").upper().replace(" ", "")
      postal = postal if ca_divisions.POSTAL_RE.fullmatch(postal) else None
      club = " ".join(p.strip() for p in (r.get("club_name"), r.get("club_name_2")) if p and p.strip())
      quals = "".join(letter for letter, key in QUALIFICATION_FIELDS if (r.get(key) or "").strip())

      if not province:
         stats["no_province"] += 1
      if not postal:
         stats["no_postal"] += 1

      division = None
      if province and table.is_split(province) and postal and division_for is not None:
         division = division_for(postal)
         if division is None:
            stats["no_division"] += 1
      section = table.section_for(province, division) or None
      if section is None:
         stats["no_section"] += 1

      batch.append(callsign_row(
         call_sign=call, country="CA",
         first_name=(r.get("first_name") or "").strip() or None,
         last_name=(r.get("surname") or "").strip() or None,
         entity_name=club or None,
         city=(r.get("city") or "").strip() or None,
         state=province, postal_code=postal, county_name=division,
         arrl_section=section, qualifications=quals or None,
         applicant_type="B" if club else "I"))
      if len(batch) >= BATCH_SIZE:
         dst.executemany(sql, batch)
         stats["rows"] += len(batch)
         batch = []
   if batch:
      dst.executemany(sql, batch)
      stats["rows"] += len(batch)
   return stats


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

def build_slim_db(scratch_db, slim_db, table, zip_county, counties, meta,
                  ca_records=None, division_for=None):
   """
   Create the shippable DB from the active licences in *scratch_db* (see
   fcc_import) plus the optional Canadian records.  Returns stats.
   """
   if slim_db.exists():
      slim_db.unlink()
   dst = sqlite3.connect(str(slim_db))
   dst.executescript(SLIM_SCHEMA_SQL)

   stats = {"rows": 0, "no_zip": 0, "no_county": 0, "county_state_mismatch": 0,
            "no_section": 0}
   no_section_states = {}
   batch = []
   sql = insert_sql()

   for (call, first, mi, last, entity, city, state, zip_code, op_class,
        app_type) in fcc_import.active_licences(scratch_db):
      state = state.strip().upper() if state else None
      zip5, plus4 = split_zip(zip_code)

      county_fips = county_name = None
      if not zip5:
         stats["no_zip"] += 1
      else:
         geoid = zip_county.get(zip5)
         if geoid is None:
            stats["no_county"] += 1
         else:
            county_state, name = counties[geoid]
            if state and county_state != state:
               # ZIP's county is in another state than the licensee's address
               # (ZIP straddles a state line): do not guess.
               stats["county_state_mismatch"] += 1
            else:
               county_fips, county_name = geoid, name

      section = table.section_for(state, county_name) or None
      if section is None:
         stats["no_section"] += 1
         no_section_states[state] = no_section_states.get(state, 0) + 1

      batch.append(callsign_row(
         call_sign=call, country="US", first_name=first, mi=mi, last_name=last,
         entity_name=entity, city=city, state=state, zip5=zip5, zip_plus4=plus4,
         county_fips=county_fips, county_name=county_name, arrl_section=section,
         operator_class=op_class, applicant_type=app_type))
      if len(batch) >= BATCH_SIZE:
         dst.executemany(sql, batch)
         stats["rows"] += len(batch)
         batch = []
   if batch:
      dst.executemany(sql, batch)
      stats["rows"] += len(batch)

   stats["ca"] = insert_canada(dst, ca_records or [], table, division_for)

   stats["row_count"] = dst.execute("SELECT COUNT(*) FROM callsign").fetchone()[0]
   if stats["row_count"] != stats["rows"] + stats["ca"]["rows"]:
      log(f"WARNING: {stats['rows'] + stats['ca']['rows'] - stats['row_count']} "
          f"duplicate call signs were replaced")
   meta = dict(meta, schema_version=str(SCHEMA_VERSION), row_count=str(stats["row_count"]))
   dst.executemany("INSERT INTO meta VALUES (?, ?)", sorted(meta.items()))
   dst.commit()
   dst.execute("PRAGMA journal_mode = DELETE")
   dst.execute("ANALYZE")
   dst.commit()
   dst.execute("VACUUM")
   dst.close()
   stats["no_section_by_state"] = dict(sorted(no_section_states.items(),
                                              key=lambda kv: -kv[1])[:10])
   return stats


def gzip_file(src, dest):
   part = dest.with_name(dest.name + ".part")
   with open(src, "rb") as fin, gzip.GzipFile(part, "wb", compresslevel=9, mtime=0) as fout:
      shutil.copyfileobj(fin, fout, 1024 * 1024)
   os.replace(part, dest)


def read_manifest(path):
   try:
      return json.loads(path.read_text(encoding="utf-8"))
   except (OSError, ValueError):
      return None


def download_fcc(zip_path):
   """Download l_amat.zip (HTTPS, then the FTP mirror)."""
   for url in (fcc_import.FCC_URL, fcc_import.FCC_FALLBACK_URL):
      try:
         trmaster_build.download(url, str(zip_path), force=True, user_agent=None)
         return
      except Exception as exc:
         log(f"  {exc}")
   raise RuntimeError("could not download the FCC database from any URL")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
   parser = argparse.ArgumentParser(description="Build the shippable callsign lookup DB")
   parser.add_argument("--output-dir", "-o", default="dist",
                       help="Where fcc_lookup.sqlite.gz and manifest.json are published (default: dist)")
   parser.add_argument("--workdir", "-w", default="_work",
                       help="Scratch/cache directory (default: _work)")
   parser.add_argument("--crosswalk", default=county_section.DEFAULT_TABLE,
                       help="arrl-sections-counties.json path (default: next to this script)")
   parser.add_argument("--census-divisions", default=None,
                       help=f"Statistics Canada {BOUNDARY_NAME} (default: <workdir>/geo/{BOUNDARY_NAME})")
   parser.add_argument("--force", action="store_true",
                       help="Rebuild even if the FCC and ISED files are unchanged")
   parser.add_argument("--zip-file", default=None,
                       help="Use a local l_amat.zip instead of downloading (implies --force)")
   parser.add_argument("--ised-zip", default=None,
                       help="Use a local ISED amateur_delim.zip instead of downloading")
   parser.add_argument("--keep-work", action="store_true",
                       help="Keep the downloaded zip and scratch DB after a successful build")
   args = parser.parse_args()

   out_dir = Path(args.output_dir).resolve()
   workdir = Path(args.workdir).resolve()
   crosswalk_path = Path(args.crosswalk).resolve()
   geo = workdir / "geo"
   out_dir.mkdir(parents=True, exist_ok=True)
   geo.mkdir(parents=True, exist_ok=True)
   boundary_zip = Path(args.census_divisions or geo / BOUNDARY_NAME).resolve()

   manifest_path = out_dir / MANIFEST_NAME
   gz_path = out_dir / GZ_NAME
   old = read_manifest(manifest_path)
   crosswalk_sha = sha256_file(crosswalk_path)

   # ---- Is a rebuild needed? ----
   source_lm = ised_lm = None
   if args.zip_file:
      args.force = True
   else:
      source_lm = remote_last_modified(fcc_import.FCC_URL)
      ised_lm = remote_last_modified(ISED_URL)
      unchanged = (old is not None
                   and gz_path.exists()
                   and source_lm is not None
                   and ised_lm is not None
                   and old.get("fcc_source_last_modified") == source_lm
                   and old.get("ised_source_last_modified") == ised_lm
                   and old.get("crosswalk_sha256") == crosswalk_sha
                   and old.get("schema_version") == SCHEMA_VERSION)
      if unchanged and not args.force:
         log(f"Up to date (FCC {source_lm}; ISED {ised_lm}). Nothing to do.")
         return 0

   try:
      t0 = time.time()
      table = county_section.CountySectionTable(crosswalk_path)
      if not boundary_zip.exists():
         raise RuntimeError(f"missing Statistics Canada boundary file {boundary_zip} "
                            f"(one-time download; see LOOKUP_DB.md)")

      # ---- FCC data ----
      if args.zip_file:
         zip_path = Path(args.zip_file).resolve()
      else:
         zip_path = workdir / "l_amat.zip"
         log("Downloading FCC amateur database ...")
         download_fcc(zip_path)
      if not zipfile.is_zipfile(zip_path):
         raise RuntimeError(f"{zip_path} is not a valid ZIP file")

      # ---- Geography ----
      log("Fetching Census/GeoNames geography files ...")
      county_file = fetch_cached(COUNTY_LIST_URL, geo / "national_county2020.txt")
      rel_file = fetch_cached(ZCTA_REL_URL, geo / "zcta_county_rel.txt")
      geonames_us = fetch_cached(GEONAMES_US_URL, geo / "US.zip")
      geonames_ca = fetch_cached(GEONAMES_CA_URL, geo / "CA_full.csv.zip")
      counties = load_counties(county_file)
      zip_county = load_zip_counties(rel_file, geonames_us, counties)
      log(f"  {len(counties):,} counties, {len(zip_county):,} ZIPs with a county")
      ontario = ca_divisions.OntarioDivisions(boundary_zip, geonames_ca)
      log(f"  {len(ontario.coords):,} Ontario postal codes with coordinates")

      # ---- Canada (ISED) ----
      log("Fetching ISED Canadian amateur file ...")
      if args.ised_zip:
         ised_zip = Path(args.ised_zip).resolve()
      else:
         ised_zip = fetch_cached(ISED_URL, geo / "amateur_delim.zip")
      ca_records = read_canadian_records(ised_zip)
      log(f"  {len(ca_records):,} Canadian records")

      # ---- Build ----
      scratch_db = workdir / "fcc_scratch.db"
      scratch_db.unlink(missing_ok=True)
      log("Importing active FCC licences ...")
      active = fcc_import.import_active(zip_path, scratch_db)
      log(f"  {active:,} active licences")

      slim_db = workdir / DB_NAME
      log("Building lookup database ...")
      built_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
      stats = build_slim_db(scratch_db, slim_db, table, zip_county, counties, {
         "built_at_utc": built_at,
         "fcc_source_last_modified": source_lm or "",
         "ised_source_last_modified": ised_lm or "",
         "crosswalk_sha256": crosswalk_sha,
      }, ca_records=ca_records, division_for=ontario.division_for)
      log(f"  US: {stats['rows']:,} active licences; "
          f"no ZIP: {stats['no_zip']:,}, ZIP without county: {stats['no_county']:,}, "
          f"county/state mismatch: {stats['county_state_mismatch']:,}, "
          f"no section: {stats['no_section']:,}")
      log(f"  US no-section by state (top): {stats['no_section_by_state']}")
      log(f"  Canada: {stats['ca']}")
      if stats["rows"] < MIN_EXPECTED_ROWS:
         raise RuntimeError(f"only {stats['rows']:,} US rows (< {MIN_EXPECTED_ROWS:,}); refusing to publish")
      if stats["ca"]["rows"] < MIN_EXPECTED_CA_ROWS:
         raise RuntimeError(f"only {stats['ca']['rows']:,} Canadian rows (< {MIN_EXPECTED_CA_ROWS:,}); refusing to publish")

      # ---- Publish (atomic replace; manifest last) ----
      log("Compressing and publishing ...")
      gzip_file(slim_db, gz_path)
      write_json_atomic(manifest_path, {
         "schema_version": SCHEMA_VERSION,
         "built_at_utc": built_at,
         "fcc_source_url": fcc_import.FCC_URL,
         "fcc_source_last_modified": source_lm,
         "ised_source_url": ISED_URL,
         "ised_source_last_modified": ised_lm,
         "crosswalk_sha256": crosswalk_sha,
         "row_count": stats["row_count"],
         "db_file": DB_NAME,
         "db_size": slim_db.stat().st_size,
         "db_sha256": sha256_file(slim_db),
         "gz_file": GZ_NAME,
         "gz_size": gz_path.stat().st_size,
         "gz_sha256": sha256_file(gz_path),
      })
      log(f"Done in {time.time() - t0:.0f}s: {gz_path} "
          f"({gz_path.stat().st_size / (1024 * 1024):.1f} MB gz, "
          f"{slim_db.stat().st_size / (1024 * 1024):.1f} MB uncompressed)")

      if not args.keep_work:
         scratch_db.unlink(missing_ok=True)
         slim_db.unlink(missing_ok=True)
         if not args.zip_file:
            zip_path.unlink(missing_ok=True)
      return 0
   except Exception as exc:
      log(f"ERROR: {exc}")
      return 1


if __name__ == "__main__":
   sys.exit(main())
