"""Generate tr4w/src/uDXCCEntities.pas -- CTY.DAT primary prefix -> ADIF DXCC code.

WHY A TABLE AT ALL. CTY.DAT names every entity by its primary prefix ('K',
'VE', '*GM/s') and carries NO DXCC entity number. ADIF's DXCC field is that
number (291 for the USA, 1 for Canada), and nothing else in this program knew
it: the Field Days hard-code 291 and 1. A POTA hunter can be anywhere, so the
POTA export needs the whole list.

WHERE THE NUMBERS COME FROM. The country-files.com CSV edition of the same
file (cty.csv) puts the ADIF entity number in column 3 of every row, keyed by
the SAME primary prefix as cty.dat. This script joins the two on that prefix
and REFUSES to write a table unless:

   * every primary prefix in cty.dat has a row in the CSV, and
   * every number it assigns is a live (not deleted) entity in Club Log's
     cty.xml, an independent source of the ADIF numbering.

Usage (from the repository root):

   python tools/dxcc/gen_dxcc_entities.py --cty-dat tr4w/target/cty.dat \
      --cty-csv <cty.csv> --clublog-xml <clublog_cty.xml>

Run it again when the tracked cty.dat is replaced. A prefix cty.dat gains that
the CSV lacks fails here, and uTestDXCCEntities fails the same way for a
cty.dat that was updated without it.
"""

import argparse
import os
import sys
import xml.etree.ElementTree as ET

HEADER = """\
(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* CTY.DAT PRIMARY PREFIX -> ADIF DXCC ENTITY CODE. GENERATED -- DO NOT EDIT.

  Regenerate with tools/dxcc/gen_dxcc_entities.py (its header says where the
  numbers come from and what it refuses to write).

  WHY IT EXISTS. CTY.DAT carries no DXCC number, ADIF's DXCC field IS that
  number, and a POTA hunter's country is whatever his callsign says (Q62,
  2026-10-17). The key is ContestExchange.QTH.CountryID -- the entity's
  primary prefix exactly as cty.dat spells it, star included: '*GM/s'
  (Shetland) is ADIF 279, Scotland, the entity DXCC credits it to.

  A PREFIX THIS TABLE DOES NOT KNOW ANSWERS 0 -- an operator's own cty.dat may
  name an entity added after this table was made -- and the caller leaves the
  DXCC tag out rather than guess. PURE: no globals. *)
unit uDXCCEntities;

{$I tr4w.inc}

interface

(* The ADIF DXCC entity code of the CTY entity aCountryID (its primary prefix,
  e.g. 'K' -> 291, 'VE' -> 1), or 0 when the table has no such entity. *)
function ADIFDXCCOfCTYEntity(const aCountryID: string): integer;

(* The table itself, for the test that holds it to the shipped cty.dat. *)
function DXCCEntityCount: integer;
function DXCCEntityPrefixAt(aIndex: integer): string;

implementation

type
   TDXCCEntity = record
      Prefix: string[6];
      Code: integer;
   end;

const
   DXCC_ENTITY_COUNT = %(count)d;

   DXCC_ENTITIES: array[0 .. DXCC_ENTITY_COUNT - 1] of TDXCCEntity = (
%(rows)s
   );

function ADIFDXCCOfCTYEntity(const aCountryID: string): integer;
var
   i: integer;
begin
   Result := 0;
   for i := Low(DXCC_ENTITIES) to High(DXCC_ENTITIES) do
      begin
      if DXCC_ENTITIES[i].Prefix = aCountryID then
         begin
         Result := DXCC_ENTITIES[i].Code;
         Exit;
         end;
      end;
end;

function DXCCEntityCount: integer;
begin
   Result := DXCC_ENTITY_COUNT;
end;

function DXCCEntityPrefixAt(aIndex: integer): string;
begin
   Result := string(DXCC_ENTITIES[aIndex].Prefix);
end;

end.
"""


def die(message):
   sys.stderr.write("gen_dxcc_entities: " + message + "\n")
   sys.exit(1)


def read_primary_prefixes(path):
   """The primary prefix of every entity in a cty.dat, in file order."""
   text = open(path, "rb").read().decode("latin-1")
   result = []
   for record in text.split(";"):
      if not record.strip():
         continue
      head = record.strip().split("\n")[0]
      parts = [p.strip() for p in head.split(":")]
      if len(parts) < 8:
         die("not a cty.dat record: " + head[:60])
      result.append(parts[7])
   return result


def read_csv_codes(path):
   """prefix -> ADIF code, from the country-files.com CSV."""
   result = {}
   for line in open(path, encoding="latin-1"):
      fields = line.split(",")
      if len(fields) < 3:
         continue
      result[fields[0]] = int(fields[2])
   return result


def read_live_clublog_codes(path):
   """The ADIF codes Club Log lists and has not deleted."""
   live = set()
   for entity in ET.parse(path).getroot().iter("entity"):
      code = entity.findtext("adif")
      if code and entity.findtext("prefix"):
         if (entity.findtext("deleted") or "false") != "true":
            live.add(int(code))
   return live


def main():
   parser = argparse.ArgumentParser()
   parser.add_argument("--cty-dat", required=True)
   parser.add_argument("--cty-csv", required=True)
   parser.add_argument("--clublog-xml", required=True)
   parser.add_argument("--out", default=os.path.join("tr4w", "src", "uDXCCEntities.pas"))
   args = parser.parse_args()

   primaries = read_primary_prefixes(args.cty_dat)
   codes = read_csv_codes(args.cty_csv)
   live = read_live_clublog_codes(args.clublog_xml)

   missing = [p for p in primaries if p not in codes]
   if missing:
      die("cty.dat prefixes with no row in the CSV: " + ", ".join(missing))
   dead = [(p, codes[p]) for p in primaries if codes[p] not in live]
   if dead:
      die("codes that are not live in Club Log: " + repr(dead))
   if len(set(primaries)) != len(primaries):
      die("a primary prefix appears twice in cty.dat")

   rows = []
   for prefix in sorted(primaries):
      rows.append("      (Prefix: '%s'; Code: %d)" % (prefix, codes[prefix]))
   body = HEADER % {"count": len(rows), "rows": ",\n".join(rows)}
   with open(args.out, "wb") as handle:
      handle.write(body.replace("\n", "\r\n").encode("utf-8"))
   sys.stdout.write("wrote %d entities to %s\n" % (len(rows), args.out))


main()
