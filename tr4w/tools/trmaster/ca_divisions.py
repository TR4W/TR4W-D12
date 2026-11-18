"""
Ontario postal code -> census division name, for the ARRL/RAC section lookup.

ISED's amateur file gives an Ontario licensee a postal code but no county, and
Ontario's four sections (GH, ONE, ONN, ONS) follow census divisions.  So:

   postal code --GeoNames--> latitude/longitude
               --Statistics Canada boundary file--> census division name

Pure standard library.  The boundary file is Statistics Canada's 2021 Census
Cartographic Boundary File, census divisions, Shapefile (lcd_000a21a_e.zip); it
is read straight from the zip.  Its coordinates are Lambert conformal conic, so
a point is projected before it is tested against the polygons (the projection
parameters come from the file's own .prj).

THE RULE THAT MATTERS: a postal code we cannot place (not in GeoNames, or its
point lies in no Ontario division) returns None.  Never a "nearest" guess: a
wrong section is sent as the operator's exchange.
"""

import csv
import io
import math
import re
import struct
import zipfile

PROVINCE_ID_ONTARIO = "35"

# Where a census division's name differs from the name in
# arrl-sections-counties.json.  Haldimand-Norfolk is one division; the JSON lists
# its two halves, and both are ONS, so either name gives the right section.
DIVISION_ALIASES = {
   "Greater Sudbury / Grand Sudbury": "Greater Sudbury",
   "Haldimand-Norfolk": "Haldimand",
}

SHAPE_POLYGON = 5
SHAPE_NULL = 0


# ---------------------------------------------------------------------------
# Shapefile / dBase readers
# ---------------------------------------------------------------------------

def read_dbf(data):
   """Rows (dicts of stripped strings) of a dBase table given as bytes."""
   count, header_len, record_len = struct.unpack("<xxxxIHH", data[:12])
   fields = []
   pos = 32
   while data[pos] != 0x0D:
      name = data[pos:pos + 11].split(b"\0")[0].decode("ascii")
      fields.append((name, data[pos + 16]))
      pos += 32
   rows = []
   for index in range(count):
      start = header_len + index * record_len
      record = data[start:start + record_len]
      offset = 1                                   # byte 0 is the deleted flag
      row = {}
      for name, length in fields:
         row[name] = record[offset:offset + length].decode("utf-8", errors="replace").strip()
         offset += length
      rows.append(row)
   return rows


def read_polygons(data):
   """One entry per record: a list of rings, each ring a list of (x, y)."""
   records = []
   pos = 100                                        # skip the file header
   while pos < len(data):
      length = struct.unpack(">4xI", data[pos:pos + 8])[0] * 2
      body = data[pos + 8:pos + 8 + length]
      pos += 8 + length
      shape_type = struct.unpack("<i", body[:4])[0]
      if shape_type == SHAPE_NULL:
         records.append([])
         continue
      if shape_type != SHAPE_POLYGON:
         raise ValueError("unsupported shape type %d (expected polygons)" % shape_type)
      part_count, point_count = struct.unpack("<ii", body[36:44])
      starts = list(struct.unpack("<%di" % part_count, body[44:44 + 4 * part_count]))
      starts.append(point_count)
      first = 44 + 4 * part_count
      flat = struct.unpack("<%dd" % (2 * point_count), body[first:first + 16 * point_count])
      points = list(zip(flat[0::2], flat[1::2]))
      records.append([points[starts[i]:starts[i + 1]] for i in range(part_count)])
   return records


# ---------------------------------------------------------------------------
# Projection and point-in-polygon
# ---------------------------------------------------------------------------

class LambertConformalConic:
   """Two-standard-parallel Lambert conformal conic on an ellipsoid (Snyder)."""

   def __init__(self, parallel1, parallel2, origin_lat, central_meridian,
                false_easting, false_northing,
                semi_major=6378137.0, inverse_flattening=298.257222101):
      flattening = 1.0 / inverse_flattening
      self.e = math.sqrt(2 * flattening - flattening * flattening)
      self.a = semi_major
      self.lon0 = math.radians(central_meridian)
      self.false_easting = false_easting
      self.false_northing = false_northing
      phi1, phi2, phi0 = (math.radians(v) for v in (parallel1, parallel2, origin_lat))
      m1, m2 = self._m(phi1), self._m(phi2)
      t1, t2, t0 = self._t(phi1), self._t(phi2), self._t(phi0)
      self.n = (math.log(m1) - math.log(m2)) / (math.log(t1) - math.log(t2))
      self.f = m1 / (self.n * t1 ** self.n)
      self.rho0 = self.a * self.f * t0 ** self.n

   def _m(self, phi):
      s = math.sin(phi)
      return math.cos(phi) / math.sqrt(1 - self.e ** 2 * s * s)

   def _t(self, phi):
      s = self.e * math.sin(phi)
      return math.tan(math.pi / 4 - phi / 2) / ((1 - s) / (1 + s)) ** (self.e / 2)

   def forward(self, lat, lon):
      """(easting, northing) in metres for a latitude/longitude in degrees."""
      rho = self.a * self.f * self._t(math.radians(lat)) ** self.n
      theta = self.n * (math.radians(lon) - self.lon0)
      return (self.false_easting + rho * math.sin(theta),
              self.false_northing + self.rho0 - rho * math.cos(theta))


def statcan_lambert():
   """The projection of Statistics Canada's boundary files (their .prj)."""
   return LambertConformalConic(49, 77, 63.390675, -91.86666666666666, 6200000, 3000000)


def ring_contains(ring, x, y):
   """Even-odd ray test for one ring."""
   inside = False
   x1, y1 = ring[-1]
   for x2, y2 in ring:
      if (y2 > y) != (y1 > y) and x < (x1 - x2) * (y - y2) / (y1 - y2) + x2:
         inside = not inside
      x1, y1 = x2, y2
   return inside


def bounding_box(ring):
   xs = [p[0] for p in ring]
   ys = [p[1] for p in ring]
   return (min(xs), min(ys), max(xs), max(ys))


class DivisionFinder:
   """Which census division holds a point.  Built from the boundary data."""

   def __init__(self, names, polygons, projection):
      self.projection = projection
      self.divisions = [(name, [(bounding_box(r), r) for r in rings])
                        for name, rings in zip(names, polygons)]

   def find(self, lat, lon):
      """The division name for a latitude/longitude, or None."""
      x, y = self.projection.forward(lat, lon)
      for name, rings in self.divisions:
         crossings = 0
         for (x0, y0, x1, y1), ring in rings:
            if x0 <= x <= x1 and y0 <= y <= y1 and ring_contains(ring, x, y):
               crossings += 1                       # holes count again: even = outside
         if crossings % 2 == 1:
            return name
      return None


def load_division_finder(boundary_zip, province_id=PROVINCE_ID_ONTARIO):
   """A DivisionFinder over one province's divisions, from the StatCan zip."""
   with zipfile.ZipFile(boundary_zip) as zf:
      by_ext = {n.rsplit(".", 1)[-1].lower(): n for n in zf.namelist()}
      shapes = read_polygons(zf.read(by_ext["shp"]))
      rows = read_dbf(zf.read(by_ext["dbf"]))
   if len(shapes) != len(rows):
      raise ValueError("boundary file: %d shapes but %d attribute rows"
                       % (len(shapes), len(rows)))
   names = []
   polygons = []
   for row, rings in zip(rows, shapes):
      if row["PRUID"] == province_id:
         names.append(row["CDNAME"])
         polygons.append(rings)
   if not names:
      raise ValueError("boundary file has no divisions for province %s" % province_id)
   return DivisionFinder(names, polygons, statcan_lambert())


# ---------------------------------------------------------------------------
# Postal code -> coordinates (GeoNames CA_full.csv.zip)
# ---------------------------------------------------------------------------

POSTAL_RE = re.compile(r"[A-Z][0-9][A-Z][0-9][A-Z][0-9]")


def load_postal_coordinates(geonames_zip, province="ON"):
   """{postal code without space: (lat, lon)} for one province.

   GeoNames tab-separated columns: country, postal, place, province name,
   province code, ..., latitude (9), longitude (10), accuracy."""
   coords = {}
   with zipfile.ZipFile(geonames_zip) as zf:
      with zf.open("CA_full.txt") as raw:
         for row in csv.reader(io.TextIOWrapper(raw, encoding="utf-8"), delimiter="\t"):
            if len(row) < 11 or row[4] != province:
               continue
            postal = row[1].replace(" ", "").upper()
            if POSTAL_RE.fullmatch(postal):
               coords[postal] = (float(row[9]), float(row[10]))
   return coords


class OntarioDivisions:
   """postal code -> census division name (JSON spelling), or None."""

   def __init__(self, boundary_zip, geonames_zip):
      self.finder = load_division_finder(boundary_zip)
      self.coords = load_postal_coordinates(geonames_zip, "ON")
      self.cache = {}

   def division_for(self, postal):
      if postal not in self.cache:
         point = self.coords.get(postal)
         name = self.finder.find(*point) if point else None
         self.cache[postal] = DIVISION_ALIASES.get(name, name)
      return self.cache[postal]
