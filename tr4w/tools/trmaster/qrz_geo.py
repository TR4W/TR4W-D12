"""
Grid and section from a QRZ cache entry -- the pure part of the geo resolver.

trmaster_names_qrz.py keeps what QRZ returned; this module turns it into the
two values the TRMASTER.DTA record has slots for: Grid (^G, string[6]) and
Section (^A, string[5]).  No network, so it is tested without QRZ.

CASE.  Both the 4.x and 5.x readers copy the field out verbatim, and the
program upper-cases a grid wherever it compares or computes with one
(tree.LooksLikeAGrid, loggrid, the beam heading).  We store the Maidenhead
convention, field and square upper case and the subsquare lower case
(EL88, EL88ab) -- the same spelling uGetScores sends HamScore.

LENGTH.  string[6]: a 4 or 6 character grid.  QRZ sometimes holds 8
characters; the extended square is cut off, never the subsquare.
"""

import re

import county_section as cs

GRID_RE = re.compile(r"^([A-Ra-r]{2})([0-9]{2})(?:([A-Xa-x]{2})(?:[0-9]{2})?)?$")

# QRZ's `country` for the places the section table covers.  Anything else with
# a state-looking value (a DX operator whose QRZ page has a "state") must not
# be given a US section.
SECTION_COUNTRIES = {
   "united states", "canada", "puerto rico", "guam", "hawaii", "alaska",
   "us virgin islands", "u.s. virgin islands", "virgin islands",
   "american samoa", "northern mariana islands",
}


def normalize_grid(raw):
   """A QRZ <grid> value -> 'EL88' or 'EL88ab', or '' if it is not a grid."""
   if not raw:
      return ""
   m = GRID_RE.match(raw.strip())
   if not m:
      return ""
   field, square, sub = m.group(1), m.group(2), m.group(3)
   result = field.upper() + square
   if sub:
      result += sub.lower()
   return result


def grid_from_latlon(lat, lon):
   """The 4-character square holding a latitude/longitude, or ''.

   Only the square, not the subsquare: QRZ's lat/lon is a geocoded address, so
   it names the town more reliably than the house, and a wrong subsquare would
   look as authoritative as a right one."""
   try:
      la = float(lat)
      lo = float(lon)
   except (TypeError, ValueError):
      return ""
   if not (-90.0 <= la < 90.0 and -180.0 <= lo < 180.0):
      return ""
   lo += 180.0
   la += 90.0
   return "%s%s%d%d" % (chr(ord("A") + int(lo // 20)), chr(ord("A") + int(la // 10)),
                        int((lo % 20) // 2), int(la % 10))


def geo_from_entry(entry, table):
   """(grid, section, grid_source) for one cache entry.

   grid_source is 'qrz', 'latlon' or '' -- reported by the sample run so the
   derived squares can be judged separately from QRZ's own."""
   grid = normalize_grid(entry.get("grid", ""))
   source = "qrz" if grid else ""
   if not grid:
      grid = grid_from_latlon(entry.get("lat"), entry.get("lon"))
      source = "latlon" if grid else ""

   section = ""
   country = (entry.get("country") or "").strip().lower()
   state = (entry.get("state") or "").strip()
   if state and country in SECTION_COUNTRIES and table.knows_state(state):
      section = table.section_for(state, entry.get("county", ""))
   return grid, section, source
