"""
Slim import of the FCC ULS amateur file (l_amat.zip) for the lookup database.

Reads only what the lookup database ships: the active licences' call sign,
name, city, state, ZIP, licence class and applicant type.  Street address,
e-mail and phone are never read into the scratch database.  Pure standard
library.

l_amat.zip holds pipe-delimited, Latin-1 text files with no quoting:
   HD.dat  licence header   (unique_system_identifier, call_sign, license_status)
   EN.dat  entity record    (name and address; entity_type 'L' = the licensee)
   AM.dat  amateur record   (operator_class)
Column positions below are the FCC's documented record layouts.
"""

import io
import sqlite3
import zipfile

FCC_URL = "https://data.fcc.gov/download/pub/uls/complete/l_amat.zip"
FCC_FALLBACK_URL = "ftp://wirelessftp.fcc.gov/pub/uls/complete/l_amat.zip"

# 0-based column positions in each .dat record.
HD_USI, HD_CALL, HD_STATUS = 1, 4, 5
EN_USI, EN_TYPE, EN_ENTITY, EN_FIRST, EN_MI, EN_LAST = 1, 5, 7, 8, 9, 10
EN_CITY, EN_STATE, EN_ZIP, EN_APPLICANT_TYPE = 16, 17, 18, 23
AM_USI, AM_CLASS = 1, 5

LICENSEE = "L"
ACTIVE = "A"
BATCH_SIZE = 5000

SCRATCH_SQL = """
CREATE TABLE hd (usi INTEGER PRIMARY KEY, call_sign TEXT);
CREATE TABLE en (usi INTEGER PRIMARY KEY, entity_name TEXT, first_name TEXT,
                 mi TEXT, last_name TEXT, city TEXT, state TEXT, zip_code TEXT,
                 applicant_type TEXT);
CREATE TABLE am (usi INTEGER PRIMARY KEY, operator_class TEXT);
"""

ACTIVE_QUERY = """
SELECT h.call_sign, e.first_name, e.mi, e.last_name, e.entity_name, e.city,
       e.state, e.zip_code, a.operator_class, e.applicant_type
FROM hd h
LEFT JOIN en e ON e.usi = h.usi
LEFT JOIN am a ON a.usi = h.usi
WHERE h.call_sign IS NOT NULL AND h.call_sign != ''
"""


def clean(value):
   """A stripped field, or None when blank."""
   value = value.strip()
   return value or None


def dat_rows(zf, name, minimum_columns):
   """Split lines of one .dat file; short lines are skipped."""
   with zf.open(name) as raw:
      for line in io.TextIOWrapper(raw, encoding="latin-1", errors="replace"):
         fields = line.rstrip("\r\n").split("|")
         if len(fields) >= minimum_columns:
            yield fields


def insert_batched(db, sql, rows):
   batch = []
   count = 0
   for row in rows:
      batch.append(row)
      if len(batch) >= BATCH_SIZE:
         db.executemany(sql, batch)
         count += len(batch)
         batch = []
   if batch:
      db.executemany(sql, batch)
      count += len(batch)
   return count


def import_active(zip_path, scratch_db):
   """Load the active licences of *zip_path* into a new scratch database.

   Returns the number of active licences.  EN and AM rows are kept only for
   those licences, so the scratch database stays small."""
   db = sqlite3.connect(str(scratch_db))
   db.executescript(SCRATCH_SQL)
   with zipfile.ZipFile(zip_path) as zf:
      active = insert_batched(
         db, "INSERT OR REPLACE INTO hd VALUES (?, ?)",
         ((int(f[HD_USI]), clean(f[HD_CALL]))
          for f in dat_rows(zf, "HD.dat", HD_STATUS + 1)
          if f[HD_STATUS].strip() == ACTIVE and f[HD_USI].strip().isdigit()))
      wanted = {row[0] for row in db.execute("SELECT usi FROM hd")}
      insert_batched(
         db, "INSERT OR REPLACE INTO en VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
         ((int(f[EN_USI]), clean(f[EN_ENTITY]), clean(f[EN_FIRST]), clean(f[EN_MI]),
           clean(f[EN_LAST]), clean(f[EN_CITY]), clean(f[EN_STATE]), clean(f[EN_ZIP]),
           clean(f[EN_APPLICANT_TYPE]))
          for f in dat_rows(zf, "EN.dat", EN_APPLICANT_TYPE + 1)
          if f[EN_TYPE].strip() == LICENSEE and f[EN_USI].strip().isdigit()
          and int(f[EN_USI]) in wanted))
      insert_batched(
         db, "INSERT OR REPLACE INTO am VALUES (?, ?)",
         ((int(f[AM_USI]), clean(f[AM_CLASS]))
          for f in dat_rows(zf, "AM.dat", AM_CLASS + 1)
          if f[AM_USI].strip().isdigit() and int(f[AM_USI]) in wanted))
   db.commit()
   db.close()
   return active


def active_licences(scratch_db):
   """Yield one tuple per active licence:
   (call_sign, first_name, mi, last_name, entity_name, city, state, zip_code,
    operator_class, applicant_type)."""
   db = sqlite3.connect(str(scratch_db))
   try:
      yield from db.execute(ACTIVE_QUERY)
   finally:
      db.close()
