"""
Tests for ca_divisions.py.  Plain asserts; run:  python -I test_ca_divisions.py

The shapefile and GeoNames inputs are built in memory, so the tests need no
download.  Tests that use the real Statistics Canada file run only when it is
in _work/geo/ (see LOOKUP_DB.md) and otherwise print SKIP.
"""

import io
import json
import os
import struct
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import ca_divisions as cd
import county_section as cs

REAL_BOUNDARY = os.path.join(HERE, "_work", "geo", "lcd_000a21a_e.zip")
TABLE = cs.CountySectionTable()


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


# --- building shapefile / dBase / GeoNames bytes ---------------------------

def polygon_record(number, rings):
   points = [p for ring in rings for p in ring]
   xs = [p[0] for p in points]
   ys = [p[1] for p in points]
   starts, total = [], 0
   for ring in rings:
      starts.append(total)
      total += len(ring)
   body = struct.pack("<i4d2i", cd.SHAPE_POLYGON, min(xs), min(ys), max(xs), max(ys),
                      len(rings), len(points))
   body += struct.pack("<%di" % len(starts), *starts)
   body += struct.pack("<%dd" % (2 * len(points)), *[v for p in points for v in p])
   return struct.pack(">2I", number, len(body) // 2) + body


def shp_bytes(polygons):
   return b"\0" * 100 + b"".join(polygon_record(i + 1, rings) for i, rings in enumerate(polygons))


def dbf_bytes(rows, widths):
   fields = list(widths)
   record_len = 1 + sum(widths[f] for f in fields)
   header_len = 32 + 32 * len(fields) + 1
   data = struct.pack("<4xIHH", len(rows), header_len, record_len) + b"\0" * 20
   for f in fields:
      data += f.encode("ascii").ljust(11, b"\0") + b"C" + b"\0" * 4 + bytes([widths[f]]) + b"\0" * 15
   data += b"\x0D"
   for row in rows:
      data += b" " + b"".join(row[f].encode("utf-8").ljust(widths[f]) for f in fields)
   return data


def box(lat0, lon0, lat1, lon1):
   """A closed rectangle ring in the boundary file's projected coordinates."""
   proj = cd.statcan_lambert()
   corners = [(lat0, lon0), (lat1, lon0), (lat1, lon1), (lat0, lon1), (lat0, lon0)]
   return [proj.forward(lat, lon) for lat, lon in corners]


def boundary_zip(path_or_buffer):
   # "Toronto" is a plain box; "Haldimand-Norfolk" has a hole (an enclave);
   # "Ottawa" is in another province (PRUID 24) and must be ignored.
   polygons = [[box(43.5, -79.6, 43.9, -79.1)],
               [box(42.7, -80.5, 43.0, -79.9), box(42.8, -80.3, 42.9, -80.1)],
               [box(45.0, -76.0, 45.6, -75.4)]]
   rows = [{"PRUID": "35", "CDNAME": "Toronto"},
           {"PRUID": "35", "CDNAME": "Haldimand-Norfolk"},
           {"PRUID": "24", "CDNAME": "Ottawa"}]
   with zipfile.ZipFile(path_or_buffer, "w") as zf:
      zf.writestr("x.shp", shp_bytes(polygons))
      zf.writestr("x.dbf", dbf_bytes(rows, {"PRUID": 2, "CDNAME": 40}))
   return path_or_buffer


def geonames_zip(path_or_buffer):
   lines = ["CA\tM5V 2T6\tToronto\tOntario\tON\t\t\t\t\t43.64\t-79.39\t6",
            "CA\tN0A 1A0\tSimcoe\tOntario\tON\t\t\t\t\t42.75\t-80.40\t6",
            "CA\tN0A 1B0\tEnclave\tOntario\tON\t\t\t\t\t42.85\t-80.20\t6",
            "CA\tK1A 0B1\tOttawa\tOntario\tON\t\t\t\t\t45.30\t-75.70\t6",
            "CA\tH0H 0H0\tMontreal\tQuebec\tQC\t\t\t\t\t45.50\t-73.60\t6",
            "CA\tbad\tJunk\tOntario\tON\t\t\t\t\t1\t2\t6"]
   with zipfile.ZipFile(path_or_buffer, "w") as zf:
      zf.writestr("CA_full.txt", "\n".join(lines) + "\n")
   return path_or_buffer


# --- projection and geometry ------------------------------------------------

def test_projection_origin_is_the_false_origin():
   x, y = cd.statcan_lambert().forward(63.390675, -91.86666666666666)
   assert abs(x - 6200000) < 0.01 and abs(y - 3000000) < 0.01, (x, y)


def test_projection_toronto_regression():
   x, y = cd.statcan_lambert().forward(43.6532, -79.3832)
   assert abs(x - 7224817.5) < 1 and abs(y - 928699.05) < 1, (x, y)


def test_ring_contains():
   ring = [(0, 0), (4, 0), (4, 4), (0, 4), (0, 0)]
   check(cd.ring_contains(ring, 2, 2), True, "inside")
   check(cd.ring_contains(ring, 5, 2), False, "outside")
   check(cd.ring_contains(ring, 2, 5), False, "above")


def test_readers_round_trip():
   rings = [[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 0.0)],
            [(5.0, 5.0), (6.0, 5.0), (6.0, 6.0), (5.0, 5.0)]]
   got = cd.read_polygons(shp_bytes([rings]))
   check(got, [rings], "polygon with two parts")
   rows = cd.read_dbf(dbf_bytes([{"PRUID": "35", "CDNAME": "Prince Edward"}],
                                {"PRUID": 2, "CDNAME": 30}))
   check(rows, [{"PRUID": "35", "CDNAME": "Prince Edward"}], "dbf row")


# --- division lookup --------------------------------------------------------

def test_finder_picks_the_province_and_honours_holes():
   finder = cd.load_division_finder(boundary_zip(io.BytesIO()))
   check([n for n, _ in finder.divisions], ["Toronto", "Haldimand-Norfolk"],
         "only Ontario divisions are loaded")
   check(finder.find(43.65, -79.39), "Toronto", "inside Toronto")
   check(finder.find(42.75, -80.40), "Haldimand-Norfolk", "inside the outer ring")
   check(finder.find(42.85, -80.20), None, "inside the hole")
   check(finder.find(45.30, -75.70), None, "Ottawa is not an Ontario division here")
   check(finder.find(50.0, -90.0), None, "outside every division")


def test_ontario_divisions_end_to_end():
   on = cd.OntarioDivisions(boundary_zip(io.BytesIO()), geonames_zip(io.BytesIO()))
   check(on.division_for("M5V2T6"), "Toronto", "known postal code")
   check(on.division_for("N0A1A0"), "Haldimand", "alias applied")
   check(on.division_for("N0A1B0"), None, "point in no division: never guessed")
   check(on.division_for("Z9Z9Z9"), None, "postal code unknown to GeoNames")
   check(on.division_for("H0H0H0"), None, "other provinces are not loaded")
   check(len(on.coords), 4, "invalid postal row skipped, QC row skipped")


# --- names against the real crosswalk ---------------------------------------

def test_aliases_name_real_crosswalk_divisions():
   for census_name, json_name in cd.DIVISION_ALIASES.items():
      assert TABLE.section_for("ON", json_name), (census_name, json_name)
   # Both halves of Haldimand-Norfolk must agree, or the alias would be a guess.
   check(TABLE.section_for("ON", "Haldimand"), TABLE.section_for("ON", "Norfolk"),
         "Haldimand and Norfolk share a section")


# --- the real Statistics Canada file (skipped when it is not present) -------

def test_real_file_names_and_points():
   if not os.path.exists(REAL_BOUNDARY):
      print("SKIP real boundary file not at", REAL_BOUNDARY)
      return
   finder = cd.load_division_finder(REAL_BOUNDARY)
   check(len(finder.divisions), 49, "Ontario census divisions")
   for name, _ in finder.divisions:
      shown = cd.DIVISION_ALIASES.get(name, name)
      assert TABLE.section_for("ON", shown), "no section for census division %r" % shown
   # lat/lon given by QRZ for known operators, and well-known cities
   for lat, lon, want, section in [
         (43.522081, -79.795940, "Halton", "GH"),        # VA3JLE
         (43.6532, -79.3832, "Toronto", "GH"),
         (45.4215, -75.6972, "Ottawa", "ONE"),
         (48.3809, -89.2477, "Thunder Bay", "ONN"),
         (42.3149, -83.0364, "Essex", "ONS")]:
      name = finder.find(lat, lon)
      check(name, want, "division at %s,%s" % (lat, lon))
      check(TABLE.section_for("ON", name), section, "section for " + want)


def main():
   tests = [(n, f) for n, f in sorted(globals().items())
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
