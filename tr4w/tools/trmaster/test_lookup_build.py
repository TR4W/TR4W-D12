"""
Tests for lookup_build.py and fcc_import.py.  Plain asserts; run:
   python -I test_lookup_build.py
Everything is built in memory / in a temp folder; no download is needed.
"""

import os
import sqlite3
import sys
import tempfile
import zipfile
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import county_section as cs
import fcc_import
import lookup_build as lb

TABLE = cs.CountySectionTable()


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


# --- split_zip --------------------------------------------------------------

def test_split_zip():
   check(lb.split_zip("33761"), ("33761", None), "five digit")
   check(lb.split_zip("337611234"), ("33761", "1234"), "nine digit")
   check(lb.split_zip(""), (None, None), "blank")
   check(lb.split_zip(None), (None, None), "none")
   check(lb.split_zip("3376"), (None, None), "short")


# --- fcc_import -------------------------------------------------------------

def dat_line(width, **fields):
   row = [""] * width
   for index, value in fields.items():
      row[int(index[1:])] = value
   return "|".join(row)


def hd(usi, call, status):
   return dat_line(59, c1=str(usi), c4=call, c5=status)


def en(usi, kind, first="", last="", entity="", city="", state="", zip_code="",
       applicant="I", street="1 SECRET ST", email="secret@example.com"):
   return dat_line(30, c1=str(usi), c5=kind, c7=entity, c8=first, c10=last,
                   c15=street, c14=email, c16=city, c17=state, c18=zip_code,
                   c23=applicant)


def am(usi, operator_class):
   return dat_line(18, c1=str(usi), c5=operator_class)


def write_fcc_zip(path, hd_lines, en_lines, am_lines):
   with zipfile.ZipFile(path, "w") as zf:
      zf.writestr("HD.dat", "\r\n".join(hd_lines) + "\r\n")
      zf.writestr("EN.dat", "\r\n".join(en_lines) + "\r\n")
      zf.writestr("AM.dat", "\r\n".join(am_lines) + "\r\n")


def sample_scratch(tmp):
   zip_path = Path(tmp) / "l_amat.zip"
   write_fcc_zip(zip_path,
      [hd(1, "NY4I", "A"), hd(2, "K0OLD", "E"), hd(3, "W1XX", "A"),
       hd(4, "N1BAD", "A"), hd(5, "N2OUT", "A")],
      [en(1, "L", first="T", last="S", city="Clearwater", state="fl", zip_code="337611234"),
       en(2, "L", first="X", last="Y", city="X", state="FL", zip_code="33761"),
       en(3, "L", entity="Club", city="Hartford", state="CT", zip_code="06111", applicant="B"),
       en(3, "A", first="NOT", last="THE LICENSEE"),
       en(4, "L", city="Y", state="FL", zip_code="99999"),
       en(5, "L", city="Z", state="FL", zip_code="42223")],
      [am(1, "E"), am(3, ""), am(4, "G"), am(5, "G")])
   scratch = Path(tmp) / "scratch.db"
   active = fcc_import.import_active(zip_path, scratch)
   return scratch, active


def test_import_keeps_only_active_licensee_rows():
   with tempfile.TemporaryDirectory() as tmp:
      scratch, active = sample_scratch(tmp)
      check(active, 4, "active licences")
      rows = {r[0]: r for r in fcc_import.active_licences(scratch)}
      check(sorted(rows), ["N1BAD", "N2OUT", "NY4I", "W1XX"], "expired licence excluded")
      check(rows["NY4I"][1:], ("T", None, "S", None, "Clearwater", "fl", "337611234", "E", "I"),
            "NY4I row")
      check(rows["W1XX"][4], "Club", "entity name of the licensee row, not the applicant row")
      check(rows["W1XX"][8], None, "blank operator class is NULL")


def test_import_never_stores_address_email_or_phone():
   with tempfile.TemporaryDirectory() as tmp:
      scratch, _ = sample_scratch(tmp)
      db = sqlite3.connect(str(scratch))
      columns = {c[1] for t in ("hd", "en", "am") for c in db.execute("PRAGMA table_info(%s)" % t)}
      dump = " ".join(str(v) for t in ("hd", "en", "am") for r in db.execute("SELECT * FROM " + t) for v in r)
      db.close()
      assert not columns & {"street_address", "email", "phone"}, columns
      assert "SECRET" not in dump and "secret@example.com" not in dump, "address or e-mail leaked"


# --- end to end -------------------------------------------------------------

COUNTIES = {"12103": ("FL", "Pinellas County"),
            "09003": ("CT", "Hartford County"),
            "47147": ("TN", "Robertson County")}
ZIP_COUNTY = {"33761": "12103", "06111": "09003", "42223": "47147"}


def build(tmp, scratch, ca_records=None, division_for=None):
   slim = Path(tmp) / "slim.db"
   stats = lb.build_slim_db(scratch, slim, TABLE, ZIP_COUNTY, COUNTIES, {},
                            ca_records=ca_records, division_for=division_for)
   return slim, stats


def test_county_and_section_end_to_end():
   with tempfile.TemporaryDirectory() as tmp:
      scratch, _ = sample_scratch(tmp)
      slim, stats = build(tmp, scratch)
      check(stats["row_count"], 4, "rows")
      db = sqlite3.connect(str(slim))
      get = lambda call: db.execute(
         "SELECT state, zip5, zip_plus4, county_fips, county_name, arrl_section "
         "FROM callsign WHERE call_sign=?", (call,)).fetchone()
      check(get("NY4I"), ("FL", "33761", "1234", "12103", "Pinellas County", "WCF"), "NY4I")
      check(get("W1XX"), ("CT", "06111", None, "09003", "Hartford County", "CT"), "W1XX")
      check(get("K0OLD"), None, "expired call is absent")
      check(get("N1BAD")[3:], (None, None, None), "ZIP unknown: FL is split, so no section")
      check(get("N2OUT")[3:], (None, None, None), "ZIP in another state's county: not guessed")
      check(stats["county_state_mismatch"], 1, "mismatch count")
      check(db.execute("SELECT value FROM meta WHERE key='schema_version'").fetchone()[0],
            str(lb.SCHEMA_VERSION), "schema_version in meta")
      db.close()


def test_pacific_possessions_and_territories_have_sections():
   for state in ("HI", "GU", "AS", "MP", "UM"):
      check(TABLE.section_for(state), "PAC", state)
   for state in ("NT", "NU", "YT"):
      check(TABLE.section_for(state), "TER", state)


# --- Canada -----------------------------------------------------------------

CA_FIELDS = ("callsign", "first_name", "surname", "address_line", "city", "prov_cd",
             "postal_code", "qual_a", "qual_b", "qual_c", "qual_d", "qual_e",
             "club_name", "club_name_2")


def ca(**kw):
   return {f: kw.get(f, "") for f in CA_FIELDS}


def insert_ca(tmp, records, division_for=None):
   db = sqlite3.connect(str(Path(tmp) / "ca.db"))
   db.executescript(lb.SLIM_SCHEMA_SQL)
   stats = lb.insert_canada(db, records, TABLE, division_for)
   return db, stats


def test_province_maps_directly():
   with tempfile.TemporaryDirectory() as tmp:
      db, stats = insert_ca(tmp, [
         ca(callsign="ve1aa", first_name="A", surname="B", city="HALIFAX", prov_cd="NS",
            postal_code="b3h 1t5", qual_a="A", qual_c="C", qual_e="E")])
      row = db.execute("SELECT call_sign, country, state, postal_code, arrl_section, "
                       "qualifications, applicant_type, zip5, county_fips FROM callsign").fetchone()
      check(row, ("VE1AA", "CA", "NS", "B3H1T5", "NS", "ACE", "I", None, None), "VE1AA")
      check(stats["rows"], 1, "rows")
      db.close()


def test_territories_share_ter():
   with tempfile.TemporaryDirectory() as tmp:
      db, _ = insert_ca(tmp, [ca(callsign="VY1A", prov_cd="YT"), ca(callsign="VE8A", prov_cd="NT"),
                              ca(callsign="VY0A", prov_cd="NU")])
      check({r[0] for r in db.execute("SELECT arrl_section FROM callsign")}, {"TER"}, "sections")
      db.close()


def test_club_and_blank_fields():
   with tempfile.TemporaryDirectory() as tmp:
      db, stats = insert_ca(tmp, [
         ca(callsign="VE3X", prov_cd="", club_name="Some Club", club_name_2="Inc"),
         ca(callsign="VE3Y", prov_cd="BC", postal_code="bad")])
      check(db.execute("SELECT entity_name, applicant_type, state, arrl_section "
                       "FROM callsign WHERE call_sign='VE3X'").fetchone(),
            ("Some Club Inc", "B", None, None), "club")
      check(db.execute("SELECT postal_code FROM callsign WHERE call_sign='VE3Y'").fetchone()[0],
            None, "invalid postal code")
      check((stats["no_province"], stats["no_postal"]), (1, 2), "counts")
      db.close()


def test_ontario_needs_a_division():
   with tempfile.TemporaryDirectory() as tmp:
      recs = [ca(callsign="VE3A", prov_cd="ON", postal_code="M5V2T6"),
              ca(callsign="VE3B", prov_cd="ON", postal_code="K1A0B1"),
              ca(callsign="VE3C", prov_cd="ON", postal_code="Z9Z9Z9"),
              ca(callsign="VE3D", prov_cd="ON", postal_code="")]
      lookup = {"M5V2T6": "Toronto", "K1A0B1": "Ottawa"}.get
      db, stats = insert_ca(tmp, recs, lookup)
      check(dict(db.execute("SELECT call_sign, arrl_section FROM callsign")),
            {"VE3A": "GH", "VE3B": "ONE", "VE3C": None, "VE3D": None}, "sections")
      check(db.execute("SELECT county_name FROM callsign WHERE call_sign='VE3A'").fetchone()[0],
            "Toronto", "division stored as county_name")
      check(stats["no_division"], 1, "postal codes that resolved to no division")
      db.close()


def test_ontario_without_resolver_is_null():
   with tempfile.TemporaryDirectory() as tmp:
      db, _ = insert_ca(tmp, [ca(callsign="VE3A", prov_cd="ON", postal_code="M5V2T6")])
      check(db.execute("SELECT arrl_section FROM callsign").fetchone()[0], None, "section")
      db.close()


def test_reads_ised_zip():
   with tempfile.TemporaryDirectory() as tmp:
      path = Path(tmp) / "a.zip"
      with zipfile.ZipFile(path, "w") as zf:
         header = "callsign;first_name;surname;address_line;city;prov_cd;postal_code;qual_a"
         row = "VE1AA;Zoé;O'Neil;1 Main;HALIFAX;NS;B3H1T5;A"
         zf.writestr("amateur_delim.txt", (header + "\r\n" + row + "\r\n").encode("utf-8"))
      recs = lb.read_canadian_records(path)
      check((recs[0]["callsign"], recs[0]["first_name"]), ("VE1AA", "Zoé"), "record")


def _git(args, cwd):
   import subprocess
   return subprocess.run(["git"] + args, cwd=str(cwd), capture_output=True, text=True, check=True).stdout


def test_deploy_uploads_then_is_a_no_op():
   """--deploy against a local bare repo: the first run commits both files,
   the second (same bytes) commits nothing, a changed .gz commits again."""
   with tempfile.TemporaryDirectory() as tmp:
      tmp = Path(tmp)
      bare = tmp / "site.git"
      seed = tmp / "seed"
      out = tmp / "out"
      work = tmp / "work"
      for d in (out, work, seed):
         d.mkdir()
      _git(["init", "--bare", "-b", "main", str(bare)], tmp)
      _git(["init", "-b", "main"], seed)
      (seed / "index.html").write_text("site")
      _git(["add", "index.html"], seed)
      _git(["-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-m", "seed"], seed)
      _git(["push", str(bare), "main"], seed)

      (out / lb.GZ_NAME).write_bytes(b"gz one")
      (out / lb.MANIFEST_NAME).write_text('{"built_at_utc": "2026-11-20T00:00:00Z"}')
      env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com",
             "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com"}
      old_env = {k: os.environ.get(k) for k in env}
      os.environ.update(env)
      try:
         lb.deploy(out, str(bare), work)
         check(int(_git(["rev-list", "--count", "main"], bare)), 2, "first deploy adds one commit")
         check(_git(["show", "main:" + lb.GZ_NAME], bare), "gz one", "the .gz is on the site")
         lb.deploy(out, str(bare), work)
         check(int(_git(["rev-list", "--count", "main"], bare)), 2, "identical files: no new commit")
         (out / lb.GZ_NAME).write_bytes(b"gz two")
         lb.deploy(out, str(bare), work)
         check(int(_git(["rev-list", "--count", "main"], bare)), 3, "a changed .gz is a new commit")
      finally:
         for k, v in old_env.items():
            if v is None:
               os.environ.pop(k, None)
            else:
               os.environ[k] = v


def test_deploy_without_files_is_refused():
   with tempfile.TemporaryDirectory() as tmp:
      raised = False
      try:
         lb.deploy(Path(tmp), "unused", Path(tmp))
      except RuntimeError:
         raised = True
      check(raised, True, "no .gz and manifest: deploy refuses")


def main():
   tests =[(n, f) for n, f in sorted(globals().items())
            if n.startswith("test_") and callable(f)]
   failed = 0
   for name, fn in tests:
      try:
         fn()
         print("ok  ", name)
      except AssertionError as e:
         failed += 1
         print("FAIL", name, "-", e)
   print("%d tests, %d failed" % (len(tests), failed))
   return 1 if failed else 0


if __name__ == "__main__":
   sys.exit(main())
