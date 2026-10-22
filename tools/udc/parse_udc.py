"""Parse the cached N1MM UDC files into udc_index.json and udc_index.csv.

Run:  python -I tools/udc/parse_udc.py [--cache DIR]

Reads <cache>/files/* (from fetch_udc.py), <cache>/manifest.json and
<cache>/display_names.json.  Writes, under <cache>:
   extracted/<zip stem>/   text members of each ZIP (untrusted DATA)
   udc_index.json          one record per .udc, everything parsed
   udc_index.csv           the useful columns, flat (UTF-8 BOM, all quoted)

EVERYTHING IN A CACHED FILE IS UNTRUSTED.  Nothing is executed; ZIP members
are written only if their path stays inside the extraction directory, they are
small, they are not links or encrypted, and they look like text.  Standard
library only.

Key names are case-sensitive in N1MM Logger+ (UDC_HELP.txt, Note3), so keys
are kept exactly as written.  A key that matches a documented key except for
case is reported as a warning, not silently folded.
"""

import argparse
import csv
import json
import os
import re
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CACHE = os.path.join(HERE, "cache")

# Zip-bomb and path guards.  A UDC bundle is a few KB; these are generous.
MAX_ZIP_MEMBERS = 500
MAX_MEMBER_BYTES = 10 * 1024 * 1024
MAX_TOTAL_BYTES = 50 * 1024 * 1024
MAX_RATIO = 200

# [Contest] keys documented in UDC_HELP.txt (English section).  Used only to
# flag a case-different spelling; an undocumented key is still captured.
DOCUMENTED_CONTEST_KEYS = """
Name DisplayName CabrilloName Mode DupeType Multiplier1Name Multiplier2Name
Multiplier3Name MultSqlString MultSqlString2 MultSqlString3 Period
PointsPerContact PointsMultAtTimeLocal PointsMultAtTimeGMT PointsMultByMode
PointsMultByBand PointsMultByContinent PointsMultByCountry
PointsMultByCategory ShowMyCountryStations ShowWarcBands ZoneType
MultWindowType CQZoneMultContest NumMults BonusPoints BonusPoints2
DoNotCountMeAsMult DoNotCountMeAsMult2 DoNotCountMeAsMult3 CountMultOnlyFor
CountMultOnlyFor2 CountMultOnlyFor3 DoNotCountMultOnlyFor
DoNotCountMultOnlyFor2 DoNotCountMultOnlyFor3 CountMultOnlyForSec
CountMultOnlyForSec2 CountMultOnlyForSec3 MultiplierBands QsoErrorString
EntryWindowInfo FrameText LogInfo DefaultContestExchange IsWorkable
SpecialInstructions DupeSqlString StartOfContest EndOfContest IsMultPer
IsMult1Per IsMult2Per IsMult3Per MinimumOffTime UsesWAECountries
SetSentTimeForContact ScoreSummaryMultNames WebAddress CabrilloFormat
CabrilloString GenericPrintString GenericPrintStringHeader QsoNumbersByBand
DigitalModeSqlString MultipleSessions ResetMultsEverySession
ResetSNEverySession CabrilloVersion MultMult MultMult2 MultMult3
BandChangesPerPeriod SingleOpCountableBandChange MultiOpCountableBandChange
CountBandOrModeChange SOBandChangeCountMax MOBandChangeCountMax
CountBandChangesPerContest CountBandChangesPerPeriod
SOBandChangeTimerDuration MOBandChangeTimerDuration UsesLASTEXCHmacro
DupeQSOMinutesAgo PowerMult OverlayCategory SelfSpotAllowed
""".split()
_DOCUMENTED_BY_LOWER = {k.lower(): k for k in DOCUMENTED_CONTEST_KEYS}

# MultWindowType values the logger knows without a .sec file.
BUILTIN_MULT_WINDOWS = {"state", "stateprovince", "province", "section",
                        "provincie", "dok", "uba", "oblast"}

# Keys whose value is a "name, width, name, width ..." list.
PAIR_KEYS = ("CabrilloString", "EntryWindowInfo", "LogInfo",
             "GenericPrintString")


# ------------------------------------------------------------- decoding

def looks_like_text(raw):
   """True for decodable text: BOM'd UTF-16/UTF-8, or NUL-free and printable."""
   if raw.startswith((b"\xff\xfe", b"\xfe\xff", b"\xef\xbb\xbf")):
      return True
   sample = raw[:4096]
   if b"\x00" in sample:
      # BOM-less UTF-16 alternates NULs with ASCII; binary does not.
      evens = sample[0::2].count(0)
      odds = sample[1::2].count(0)
      half = max(len(sample) // 2, 1)
      return max(evens, odds) > half * 0.4 and min(evens, odds) < half * 0.1
   if not sample:
      return True
   control = sum(1 for b in sample if b < 9 or 13 < b < 32)
   return control / len(sample) < 0.02


def decode_bytes(raw):
   """Return (text, encoding_label).  Never raises."""
   if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
      return raw.decode("utf-16", errors="replace"), "utf-16"
   if raw.startswith(b"\xef\xbb\xbf"):
      return raw.decode("utf-8-sig", errors="replace"), "utf-8-bom"
   sample = raw[:4096]
   if b"\x00" in sample:
      if sample[0::2].count(0) > sample[1::2].count(0):
         return raw.decode("utf-16-be", errors="replace"), "utf-16-be"
      return raw.decode("utf-16-le", errors="replace"), "utf-16-le"
   try:
      return raw.decode("utf-8"), "utf-8"
   except UnicodeDecodeError:
      return raw.decode("cp1252", errors="replace"), "cp1252"


# --------------------------------------------------------------- INI parse

# The header must be alone on its line (a trailing comment is tolerated):
# UDC_HELP.txt is prose with lines such as "[Contest] section" that are not
# headers.
_SECTION = re.compile(r"^\s*\[([^\]]*)\]\s*(?:[;#].*)?$")
_KEYVAL = re.compile(r"^\s*([^=;#\[\s][^=]*?)\s*=(.*)$")


def parse_ini(text):
   """Return (sections, duplicates).

   sections: ordered {section name: {key: value}}, names and keys exactly as
   written.  A key repeated in a section keeps its LAST value (what a
   sequential reader ends with) and is listed in duplicates.
   """
   sections = {}
   duplicates = []
   current = ""
   for line in text.splitlines():
      match = _SECTION.match(line)
      if match:
         current = match.group(1).strip()
         sections.setdefault(current, {})
         continue
      match = _KEYVAL.match(line)
      if not match:
         continue
      key = match.group(1).strip()
      value = match.group(2).strip()
      bucket = sections.setdefault(current, {})
      if key in bucket:
         duplicates.append("%s.%s" % (current, key))
      bucket[key] = value
   return sections, duplicates


def find_section(sections, wanted):
   """The section whose name equals wanted, ignoring case.  (name, dict)."""
   for name, body in sections.items():
      if name.lower() == wanted.lower():
         return name, body
   return None, {}


# ------------------------------------------------------- pair-list parse

def parse_pair_list(value):
   """'SNT, 4, SentNr, 4' -> ([{'field':'SNT','width':4}, ...], warnings).

   Used for CabrilloString (the QSO: line layout), EntryWindowInfo, LogInfo
   and GenericPrintString.  'Space, N' means N blanks and is kept as a field
   named Space.  An odd token count leaves the last field with width None.
   """
   warnings = []
   tokens = [t.strip() for t in value.split(",")] if value.strip() else []
   while tokens and tokens[-1] == "":
      tokens.pop()
   fields = []
   for index in range(0, len(tokens), 2):
      name = tokens[index]
      width = None
      if index + 1 < len(tokens):
         raw_width = tokens[index + 1]
         try:
            width = int(raw_width)
         except ValueError:
            width = raw_width
            warnings.append("non-numeric width %r for %s" % (raw_width, name))
      else:
         warnings.append("odd token count: %s has no width" % name)
      fields.append({"field": name, "width": width})
   return fields, warnings


def width_sum(fields):
   return sum(f["width"] for f in fields if isinstance(f["width"], int))


# -------------------------------------------------------------- zip handling

def _safe_member_path(dest_dir, name):
   """Destination path for a member, or None if it would leave dest_dir."""
   norm = name.replace("\\", "/")
   if not norm or norm.startswith("/") or re.match(r"^[A-Za-z]:", norm):
      return None
   parts = [p for p in norm.split("/") if p not in ("", ".")]
   if not parts or any(p == ".." for p in parts):
      return None
   target = os.path.realpath(os.path.join(dest_dir, *parts))
   root = os.path.realpath(dest_dir)
   if os.path.commonpath([root, target]) != root:
      return None
   return target


def extract_zip(zip_path, dest_dir):
   """Write the safe text members of a ZIP into dest_dir.

   Returns a list of member dicts: {name, size, path (relative to dest_dir,
   or None), skipped (reason or None), raw (bytes, only for kept members)}.
   Raises zipfile.BadZipFile for a file that is not a ZIP.
   """
   members = []
   total = 0
   with zipfile.ZipFile(zip_path) as archive:
      infos = archive.infolist()
      if len(infos) > MAX_ZIP_MEMBERS:
         members.append({"name": "(archive)", "size": len(infos), "path": None,
                         "skipped": "too-many-members (%d)" % len(infos)})
         infos = infos[:MAX_ZIP_MEMBERS]
      for info in infos:
         if info.is_dir():
            continue
         item = {"name": info.filename, "size": info.file_size, "path": None,
                 "skipped": None}
         members.append(item)
         if info.flag_bits & 0x1:
            item["skipped"] = "encrypted"
            continue
         if ((info.external_attr >> 16) & 0o170000) == 0o120000:
            item["skipped"] = "symlink"
            continue
         if info.file_size > MAX_MEMBER_BYTES:
            item["skipped"] = "too-large"
            continue
         if (info.file_size > 1024 * 1024 and
               info.file_size / max(info.compress_size, 1) > MAX_RATIO):
            item["skipped"] = "suspicious-compression-ratio"
            continue
         if total + info.file_size > MAX_TOTAL_BYTES:
            item["skipped"] = "archive-total-too-large"
            continue
         target = _safe_member_path(dest_dir, info.filename)
         if target is None:
            item["skipped"] = "unsafe-path"
            continue
         # Do not trust the header's size: cap the actual read.
         with archive.open(info) as handle:
            raw = handle.read(MAX_MEMBER_BYTES + 1)
         if len(raw) > MAX_MEMBER_BYTES:
            item["skipped"] = "too-large"
            continue
         if not looks_like_text(raw):
            item["skipped"] = "non-text"
            continue
         total += len(raw)
         os.makedirs(os.path.dirname(target), exist_ok=True)
         with open(target, "wb") as out:
            out.write(raw)
         item["path"] = os.path.relpath(target, dest_dir).replace("\\", "/")
         item["raw"] = raw
   return members


# ------------------------------------------------------- companion inventory

def describe_companion(member, udc_sections):
   """Inventory line for one non-.udc member, incl. which key refers to it."""
   info = {"name": member["name"], "size": member["size"],
           "path": member["path"], "skipped": member["skipped"]}
   raw = member.get("raw")
   if raw is not None:
      text, encoding = decode_bytes(raw)
      lines = text.splitlines()
      info["encoding"] = encoding
      info["line_count"] = len(lines)
      info["first_lines"] = [ln[:120] for ln in lines[:5]]
   base = os.path.basename(member["name"].replace("\\", "/"))
   stem = os.path.splitext(base)[0].lower()
   refs = []
   for section, body in udc_sections.items():
      for key, value in body.items():
         tokens = [t for t in re.split(r"[\s,;]+", value.lower()) if t]
         if base.lower() in value.lower() or (
               base.lower().endswith(".sec") and stem in tokens):
            refs.append("%s.%s" % (section, key))
   info["referenced_by"] = refs
   return info


# ---------------------------------------------------------------- records

def slug_of(url):
   return url.rstrip("/").rsplit("/", 1)[-1] if url else ""


def build_display_maps(display_records):
   by_slug = {}
   by_file = {}
   for record in display_records:
      slug = slug_of(record.get("page_url", ""))
      if slug:
         by_slug.setdefault(slug, record)
      for text in record.get("filenames", []):
         for token in re.findall(r"[^\s,;]+\.(?:udc|zip)", text, re.I):
            by_file.setdefault(token.lower(), record)
   return by_slug, by_file


def build_record(source_file, member_name, text, encoding, listing, display,
                 companions):
   sections, duplicates = parse_ini(text)
   warnings = []
   if duplicates:
      warnings.append("duplicate keys (last wins): " + ", ".join(duplicates))
   contest_name, contest = find_section(sections, "Contest")
   if contest_name is None:
      warnings.append("no [Contest] section")
   elif contest_name != "Contest":
      warnings.append("section spelled [%s]" % contest_name)
   for key in contest:
      documented = _DOCUMENTED_BY_LOWER.get(key.lower())
      if documented and documented != key:
         warnings.append("key %r should be %r (keys are case-sensitive)" %
                         (key, documented))
   pair_lists = {}
   for key in PAIR_KEYS:
      if key in contest:
         fields, problems = parse_pair_list(contest[key])
         pair_lists[key] = fields
         warnings.extend("%s: %s" % (key, p) for p in problems)
   cabrillo = pair_lists.get("CabrilloString", [])
   if contest.get("CabrilloFormat") == "99" and not cabrillo:
      warnings.append("CabrilloFormat 99 but CabrilloString is empty")
   mult_window = contest.get("MultWindowType", "")
   external = ""
   in_bundle = None
   if mult_window and mult_window.lower() not in BUILTIN_MULT_WINDOWS:
      external = mult_window
      in_bundle = any(c["name"].lower().endswith(
         ("/" + mult_window.lower() + ".sec", mult_window.lower() + ".sec"))
         for c in companions)
   _, author = find_section(sections, "Author")
   _, filesec = find_section(sections, "File")
   keep = ("Mode", "MultiplierBands", "ShowWarcBands", "DigitalModeSqlString",
           "IsWorkable", "ZoneType")
   return {
      "source_file": source_file,
      "udc_member": member_name,
      "encoding": encoding,
      "listing": listing,
      "display_page": display,
      "author": author,
      "file": filesec,
      "contest": contest,
      "other_sections": {n: b for n, b in sections.items()
                         if n.lower() not in ("contest", "author", "file")},
      "cabrillo_fields": cabrillo,
      "cabrillo_width_sum": width_sum(cabrillo),
      "entry_window_fields": pair_lists.get("EntryWindowInfo", []),
      "log_info_fields": pair_lists.get("LogInfo", []),
      "bands_modes": {k: contest[k] for k in keep if k in contest},
      "external_list": {"name": external, "in_bundle": in_bundle},
      "companions": companions,
      "warnings": warnings,
   }


def process_file(path, cache_dir, manifest_by_file, display_by_slug,
                 display_by_file, failures):
   """All records for one cached file (a .udc gives one, a ZIP any number)."""
   name = os.path.basename(path)
   entry = manifest_by_file.get(name, {})
   listing = {k: entry.get(k) for k in
              ("title", "date", "page_url", "download_url", "author",
               "description", "site_download_count") if k in entry}
   lower = name.lower()
   with open(path, "rb") as handle:
      raw = handle.read()
   udc_items = []      # (member_name, raw bytes)
   companions_raw = []
   if lower.endswith(".zip") or raw.startswith(b"PK\x03\x04"):
      dest = os.path.join(cache_dir, "extracted",
                          re.sub(r"[^A-Za-z0-9._-]", "_", name))
      shutil.rmtree(dest, ignore_errors=True)
      os.makedirs(dest, exist_ok=True)
      try:
         members = extract_zip(path, dest)
      except zipfile.BadZipFile as err:
         failures.append({"file": name, "reason": "bad zip: %s" % err})
         return []
      for member in members:
         if member["name"].lower().endswith(".udc") and "raw" in member:
            udc_items.append((member["name"], member["raw"]))
         else:
            companions_raw.append(member)
      if not udc_items:
         failures.append({"file": name,
                          "reason": "zip holds no .udc (members: %s)" %
                          ", ".join(m["name"] for m in members)[:300]})
         return []
   elif lower.endswith(".udc") or looks_like_text(raw):
      if not looks_like_text(raw):
         failures.append({"file": name, "reason": "not text"})
         return []
      udc_items.append((name, raw))
   else:
      failures.append({"file": name, "reason": "unknown file type"})
      return []

   slug = slug_of(entry.get("page_url", ""))
   records = []
   for member_name, member_raw in udc_items:
      text, encoding = decode_bytes(member_raw)
      base = os.path.basename(member_name.replace("\\", "/")).lower()
      display = (display_by_slug.get(slug) or display_by_file.get(base) or
                 display_by_file.get(lower))
      sections, _ = parse_ini(text)
      siblings = [m for m in companions_raw]
      companions = [describe_companion(m, sections) for m in siblings]
      record = build_record(name, member_name, text, encoding, listing,
                            display, companions)
      if not record["contest"].get("Name"):
         # e.g. a stand-alone .sec / call list uploaded as its own entry, or
         # the UDC editor's help text, which has [Contest] headers but is
         # not a contest.
         failures.append({"file": name,
                          "reason": "%s: no [Contest] Name (not a UDC)" %
                          member_name})
         continue
      records.append(record)
   return records


# ------------------------------------------------------------------ output

CSV_COLUMNS = [
   "Name", "DisplayName", "CabrilloName", "Mode", "MultiplierBands",
   "ShowWarcBands", "EntryWindowFields", "FrameText",
   "DefaultContestExchange", "QsoErrorString", "Multiplier1Name",
   "Multiplier2Name", "Multiplier3Name", "MultSqlString", "MultSqlString2",
   "MultSqlString3", "MultWindowType", "PointsPerContact", "CabrilloFormat",
   "CabrilloVersion", "CabrilloString", "CabrilloFields", "CompanionFiles",
   "ListingTitle", "ListingDate", "DisplayPageName", "SourceFile",
   "UdcMember", "SourceURL", "DownloadURL", "Warnings",
]


def csv_row(record):
   c = record["contest"]
   listing = record["listing"] or {}
   display = record["display_page"] or {}
   return {
      "Name": c.get("Name", ""),
      "DisplayName": c.get("DisplayName", ""),
      "CabrilloName": c.get("CabrilloName", ""),
      "Mode": c.get("Mode", ""),
      "MultiplierBands": c.get("MultiplierBands", ""),
      "ShowWarcBands": c.get("ShowWarcBands", ""),
      "EntryWindowFields": " ".join(f["field"] for f in
                                    record["entry_window_fields"]),
      "FrameText": c.get("FrameText", ""),
      "DefaultContestExchange": c.get("DefaultContestExchange", ""),
      "QsoErrorString": c.get("QsoErrorString", ""),
      "Multiplier1Name": c.get("Multiplier1Name", ""),
      "Multiplier2Name": c.get("Multiplier2Name", ""),
      "Multiplier3Name": c.get("Multiplier3Name", ""),
      "MultSqlString": c.get("MultSqlString", ""),
      "MultSqlString2": c.get("MultSqlString2", ""),
      "MultSqlString3": c.get("MultSqlString3", ""),
      "MultWindowType": c.get("MultWindowType", ""),
      "PointsPerContact": c.get("PointsPerContact", ""),
      "CabrilloFormat": c.get("CabrilloFormat", ""),
      "CabrilloVersion": c.get("CabrilloVersion", ""),
      "CabrilloString": c.get("CabrilloString", ""),
      "CabrilloFields": " ".join("%s:%s" % (f["field"], f["width"])
                                 for f in record["cabrillo_fields"]),
      "CompanionFiles": "; ".join(
         "%s (%s lines)" % (x["name"], x.get("line_count", "?"))
         if not x["skipped"] else "%s [skipped: %s]" % (x["name"], x["skipped"])
         for x in record["companions"]),
      "ListingTitle": listing.get("title", ""),
      "ListingDate": listing.get("date", ""),
      "DisplayPageName": display.get("display_name", ""),
      "SourceFile": record["source_file"],
      "UdcMember": record["udc_member"],
      "SourceURL": listing.get("page_url", ""),
      "DownloadURL": listing.get("download_url", ""),
      "Warnings": " | ".join(record["warnings"]),
   }


def write_csv(path, records):
   with open(path, "w", encoding="utf-8-sig", newline="") as handle:
      writer = csv.DictWriter(handle, fieldnames=CSV_COLUMNS,
                              quoting=csv.QUOTE_ALL, lineterminator="\r\n")
      writer.writeheader()
      for record in records:
         writer.writerow(csv_row(record))


def load_json(path, default):
   if not os.path.isfile(path):
      return default
   with open(path, encoding="utf-8") as handle:
      return json.load(handle)


def main():
   parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
   parser.add_argument("--cache", default=DEFAULT_CACHE)
   args = parser.parse_args()
   cache = args.cache
   files_dir = os.path.join(cache, "files")
   if not os.path.isdir(files_dir):
      print("no %s -- run fetch_udc.py first" % files_dir)
      return 2

   manifest = load_json(os.path.join(cache, "manifest.json"), {"entries": []})
   by_file = {e["file_name"]: e for e in manifest["entries"]
              if e.get("file_name")}
   display = load_json(os.path.join(cache, "display_names.json"), [])
   by_slug, by_dfile = build_display_maps(display)

   records = []
   failures = []
   for name in sorted(os.listdir(files_dir), key=str.lower):
      path = os.path.join(files_dir, name)
      if os.path.isfile(path):
         records.extend(process_file(path, cache, by_file, by_slug, by_dfile,
                                     failures))

   key_counts = {}
   for record in records:
      for key in record["contest"]:
         key_counts[key] = key_counts.get(key, 0) + 1
   stats = {
      "files_parsed": len(os.listdir(files_dir)),
      "records": len(records),
      "failures": len(failures),
      "contest_key_counts": dict(sorted(key_counts.items(),
                                        key=lambda kv: (-kv[1], kv[0]))),
   }
   index = {"stats": stats, "failures": failures, "contests": records}
   with open(os.path.join(cache, "udc_index.json"), "w", encoding="utf-8",
             newline="\n") as handle:
      json.dump(index, handle, indent=3, ensure_ascii=False)
   write_csv(os.path.join(cache, "udc_index.csv"), records)
   print("%d files -> %d contest records, %d failures" %
         (stats["files_parsed"], len(records), len(failures)))
   return 0


if __name__ == "__main__":
   sys.exit(main())
