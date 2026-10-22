"""Cross-walk the N1MM UDC index against TR4W's registered contests.

Run:  python -I tools/udc/crosswalk.py [--cache DIR] [--q98 CSV]

Reads (all READ-ONLY):
   <cache>/udc_index.json                      parse_udc.py's output
   <cache>/extracted/, <cache>/files/          .sec companions
   tr4w/test/contest-matrix/frozen/*.matrix    every contest's frozen record:
                                               id, class, Cabrillo CONTEST:
                                               line, a QSO: line, the ADIF
                                               record, the domestic file
   tr4w/test/unit/uTestContestIdentityPin.pas  display and friendly names
   tr4w/target/dom/*.dom                       domestic multiplier files
   --q98 CSV                                   bands/modes per contest: either
                                               the resolved Q98 table
                                               (contest_id,resolution,bands,
                                               modes) or, by default,
                                               docs/Q98_CONTEST_BANDS_MODES.csv

Writes <cache>/crosswalk.csv (UTF-8 BOM, every field quoted, CRLF) and
prints the counts.  <cache> is gitignored: the rows quote third-party files.

A UDC is community-written and ranks BELOW the D7 tree, the sponsor's rules,
WA7BNM and DXLog.  Every row here is a LEAD to check, never a verdict.

Matching never guesses silently.  The methods, strongest first:
   cabrillo-exact       the UDC CabrilloName equals TR4W's Cabrillo name
   cabrillo-normalized  equal once case, blanks, '_' and '-' are folded
   cabrillo-to-id       the UDC CabrilloName equals TR4W's registry or ADIF id
   name-to-id           the UDC's short Name equals one of TR4W's names
   display-exact        the normalised display names are equal
   curated              CURATED_MATCHES below, each with its reason
A UDC that one method ties to several TR4W contests is resolved by the
UDC's Mode when that picks exactly one (noted), else every candidate is
written as 'ambiguous-match' and the record counts as ambiguous.  Display
names that merely SHARE words are written as 'match-candidate' rows and are
not matches until someone adds them to CURATED_MATCHES.

Standard library only.
"""

import argparse
import collections
import csv
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DEFAULT_CACHE = os.path.join(HERE, "cache")
MATRIX_DIR = os.path.join(REPO, "tr4w", "test", "contest-matrix", "frozen")
PIN_FILE = os.path.join(REPO, "tr4w", "test", "unit", "uTestContestIdentityPin.pas")
DOM_DIR = os.path.join(REPO, "tr4w", "target", "dom")
Q98_DOC = os.path.join(REPO, "docs", "Q98_CONTEST_BANDS_MODES.csv")

CSV_COLUMNS = [
   "tr4w_id", "tr4w_display", "tr4w_cabrillo",
   "udc_file", "udc_name", "udc_display", "udc_cabrillo",
   "match_method", "finding_kind", "tr4w_value", "udc_value", "note",
]

# A match no automatic method can make, each verified by reading both sides.
# (udc Name, udc source file or None for any, TR4W registry id, reason)
CURATED_MATCHES = [
   ("OZCHRVHF", "OZCHR_OCHN.udc", "OZHCR-VHF",
    "same event: the UDC page calls it the Russian VHF contest of OZCHR; "
    "TR4W spells the id OZHCR (letters transposed against its own OZCHR "
    "and OZCHR-TEAMS); both score 144 MHz and up by grid square"),
   ("IRTS80M", "IRTS80M.udc", "IRTS",
    "same event: IRTS 80 m contest, serial and Irish county exchange, "
    "county list IRTS.sec -- TR4W's IRTS 80m Counties Contest"),
   ("UCGCHAMP", "UCG.udc", "UCG",
    "same event: UCG Open Championship"),
   ("OK1WC", "OK1WC.udc", "MWC",
    "same event: OK1WC Memorial -- TR4W's display is 'OK1WC Memorial (MWC)'"),
   ("POTA-ve3fp", "POTA-ve3fp.udc", "POTA",
    "a second Parks on the Air UDC (author VE3FP)"),
   ("IRTSCQIR", "IRTSCQIR.udc", "CQIR",
    "same event: IRTS 'CQIR - Ireland Calling'; the UDC listing calls it "
    "discontinued"),
   ("RUSSIAN160", None, "RU3AX MEMORIAL",
    "same event: TR4W's class is 'the Russian 160-Meter DX Contest' and D7 "
    "renamed the enum RUSSIAN160 -> RU3AXMEMORIAL (D7 PostUnit.PAS~ still "
    "says RUSSIAN160; VC.pas SK3BG id 'russ160')"),
]

# A UDC that MAY be a TR4W contest the automatic methods cannot see, with
# the evidence for and against.  Written as match-candidate, never a match.
# (udc Name, udc source file, TR4W registry id, reason)
CANDIDATE_LEADS = [
   ("YBDXC", "YBDXC.udc", "YBDX",
    "'YB DX Contest' (Indonesian DX Contest, RS(T)+serial) vs TR4W's "
    "'YB ORARI DX Contest' (RSTQSONumberExchange) -- same sponsor? confirm"),
   ("YBDXCYB", "YBDXCYB.udc", "YBDX",
    "as YBDXC, the YB-station file"),
   ("RCWC_MINI", "RCWC_MINITEST.zip", "MINI40",
    "RCWC Minitest vs TR4W's Mini-Test 40/80 and MINITEST -- which TR4W "
    "contest (if any) is the RCWC Minitest?"),
   ("RCWC_MINI", "RCWC_MINITEST.zip", "MINI80",
    "as above"),
]

# A UDC that does not match a TR4W contest but may IDENTIFY one whose
# identity is an open Q98 question.  Written as q98-open, never a match.
# (udc Name, udc source file, TR4W registry id, reason)
Q98_LEADS = [
   ("POP_YTHCUP", "POP_YTHCUP.udc", "RADIO-YOC",
    "D7 gives RADIO-YOC the exchange QSONumberAndPreviousQSONumber and "
    "3 points a QSO; this UDC (Popov Youth Cup) exchanges serial + last "
    "serial received and scores 3 a QSO; and RADIO-YOC's QRZ.RU id 119 "
    "now shows the A.S. Popov Cup.  'YOC' may be YOuth Cup -- confirm"),
]

# Words that carry no identity in a display name.
STOP_WORDS = {
   "the", "contest", "test", "of", "and", "a", "for", "de", "on", "in",
   "stations", "station", "stn", "stns", "non", "member", "only", "dx",
   "cw", "ssb", "phone", "rtty", "hf", "vhf", "party", "qso", "international",
   "ww", "world", "wide", "worldwide", "all", "mode", "modes",
}

RST_WORDS = {"599", "59", "5NN", "579", "57", "589", "58"}

MULTIPLIER_BANDS = {
   "1": "HF contest bands (160-10 m, no WARC)",
   "2": "all HF bands",
   "3": "HF contest bands plus 6 m and 2 m",
   "4": "all VHF bands",
}


# ---------------------------------------------------------------- utilities

def read_text(path):
   """A file as text: UTF-8 (with or without BOM), else cp1252."""
   with open(path, "rb") as f:
      raw = f.read()
   if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
      return raw.decode("utf-16")
   try:
      return raw.decode("utf-8-sig")
   except UnicodeDecodeError:
      return raw.decode("cp1252", errors="replace")


def norm_code(s):
   """A Cabrillo-style code with case, blanks, '_' and '-' folded."""
   s = (s or "").strip().upper()
   s = re.sub(r"[\s_\-]+", "-", s)
   return s.strip("-")


def norm_text(s):
   """A display name folded for an exact comparison."""
   s = (s or "").lower().replace("&", " and ")
   s = re.sub(r"[^0-9a-z]+", " ", s)
   words = [w for w in s.split() if w not in ("the", "contest")]
   return " ".join(words)


def sig_words(s):
   s = (s or "").lower().replace("&", " and ")
   s = re.sub(r"[^0-9a-z]+", " ", s)
   return {w for w in s.split() if w not in STOP_WORDS and len(w) > 1}


def find_case_insensitive(directory, name):
   """The real path of NAME in DIRECTORY ignoring case, else None."""
   if not os.path.isdir(directory):
      return None
   target = name.lower()
   for entry in os.listdir(directory):
      if entry.lower() == target:
         return os.path.join(directory, entry)
   return None


# ---------------------------------------------------------------- TR4W side

def parse_identity_pins(path):
   """Token -> {display, friendly, domfile} from the identity pin literals."""
   text = read_text(path)
   pins = {}
   row = re.compile(
      r"Token:\s*'((?:[^']|'')*)'.*?Friendly:\s*'((?:[^']|'')*)'.*?"
      r"Display:\s*'((?:[^']|'')*)'\s*;\s*DomesticFile:\s*'((?:[^']|'')*)'",
      re.S)
   for m in row.finditer(text):
      token, friendly, display, domfile = (g.replace("''", "'") for g in m.groups())
      pins[token] = {"display": display, "friendly": friendly, "domfile": domfile}
   return pins


ADIF_TAG = re.compile(r"<([A-Za-z0-9_]+):(\d+)(?::[A-Za-z])?>")


def parse_adif_record(line):
   fields = {}
   pos = 0
   while True:
      m = ADIF_TAG.search(line, pos)
      if not m:
         break
      length = int(m.group(2))
      start = m.end()
      fields[m.group(1).upper()] = line[start:start + length]
      pos = start + length
   return fields


def parse_matrix(path):
   """One frozen matrix record -> {id, class, variants: {name: {...}}}."""
   record = {"id": None, "class": None, "variants": collections.OrderedDict()}
   variant = None
   section = None
   for line in read_text(path).splitlines():
      if line.startswith("### variant "):
         name = line[len("### variant "):].split(":", 1)[0].strip()
         variant = {"cabrillo": None, "qso": None, "adif": None, "domfile": None}
         record["variants"][name] = variant
         section = None
         continue
      if line.startswith("== "):
         section = line[3:].strip()
         continue
      if variant is None:
         continue
      if section == "identity":
         m = re.match(r"contest\.selected = (.*?) \(", line)
         if m and record["id"] is None:
            record["id"] = m.group(1)
         m = re.match(r"contest\.class = (.*)$", line)
         if m and record["class"] is None:
            record["class"] = m.group(1).strip()
      elif section == "setup":
         m = re.match(r"setting\.DOMESTIC FILENAME = (.*)$", line)
         if m:
            variant["domfile"] = m.group(1).strip()
      elif section == "export.adif":
         if variant["adif"] is None and line.startswith("<"):
            variant["adif"] = parse_adif_record(line)
      elif section == "export.cabrillo":
         if line.startswith("CONTEST:") and variant["cabrillo"] is None:
            variant["cabrillo"] = line[len("CONTEST:"):].strip()
         elif line.startswith("QSO:") and variant["qso"] is None:
            variant["qso"] = line
   return record


def tr4w_layout(variant):
   """The kinds of the QSO: line's sent and received columns, or None.

   Columns 0-5 are QSO:, frequency, mode, date, time and the sender's call.
   The worked call is the ADIF record's CALL; what lies between is SENT,
   what follows is RECEIVED.  A word is RST when it is a report, NR when it
   is the QSO's serial (STX / SRX), else EXCH.
   """
   qso = variant.get("qso")
   adif = variant.get("adif") or {}
   if not qso or not adif.get("CALL"):
      return None
   tokens = qso.split()
   call = adif["CALL"].upper()
   try:
      at = tokens.index(call, 6)
   except ValueError:
      return None
   sent = tokens[6:at]
   rcvd = tokens[at + 1:]

   def kind(tok, rst, nr):
      if tok.upper() in RST_WORDS or (rst and tok == rst):
         return "RST"
      if tok.isdigit() and nr and nr.strip().isdigit() and int(tok) == int(nr):
         return "NR"
      return "EXCH"

   sent_k = [kind(t, adif.get("RST_SENT"), adif.get("STX")) for t in sent]
   rcvd_k = [kind(t, adif.get("RST_RCVD"), adif.get("SRX")) for t in rcvd]
   return {"sent": sent_k, "rcvd": rcvd_k, "line": " ".join(tokens[6:])}


def load_q98(path):
   """contest id -> {bands, modes, open} from either Q98 table shape."""
   result = {}
   if not path or not os.path.exists(path):
      return result
   with open(path, encoding="utf-8-sig", newline="") as f:
      rows = list(csv.DictReader(f))
   for r in rows:
      cid = r.get("contest_id", "")
      if "resolution" in r:
         result[cid] = {
            "bands": r.get("bands", ""),
            "modes": r.get("modes", ""),
            "open": r.get("resolution", "") == "still-open",
            "question": r.get("question_for_ny4i", ""),
         }
      else:
         bands = (r.get("your_bands") or r.get("proposed_bands") or
                  r.get("wa7bnm_bands") or r.get("dxlog_bands") or "")
         modes = (r.get("your_modes") or r.get("wa7bnm_mode") or
                  r.get("dxlog_modes") or "")
         result[cid] = {
            "bands": bands,
            "modes": modes,
            "open": r.get("status", "") == "NONE" and not bands and not modes,
            "question": r.get("what_is_needed", ""),
         }
   return result


def load_tr4w():
   pins = parse_identity_pins(PIN_FILE)
   contests = []
   for name in sorted(os.listdir(MATRIX_DIR)):
      if not name.endswith(".matrix"):
         continue
      rec = parse_matrix(os.path.join(MATRIX_DIR, name))
      if not rec["id"]:
         print("WARNING: no contest.selected line in " + name, file=sys.stderr)
         continue
      pin = pins.get(rec["id"], {})
      cabs = []
      adifs = []
      domfiles = []
      layouts = collections.OrderedDict()
      for vname, v in rec["variants"].items():
         if v["cabrillo"] and v["cabrillo"] not in cabs:
            cabs.append(v["cabrillo"])
         cid = (v["adif"] or {}).get("CONTEST_ID")
         if cid and cid not in adifs:
            adifs.append(cid)
         if v["domfile"] and v["domfile"] not in domfiles:
            domfiles.append(v["domfile"])
         lay = tr4w_layout(v)
         if lay:
            layouts[vname] = lay
      if pin.get("domfile"):
         candidate = pin["domfile"] + ".dom"
         if candidate.lower() not in (d.lower() for d in domfiles):
            domfiles.append(candidate)
      contests.append({
         "id": rec["id"],
         "class": rec["class"],
         "display": pin.get("display") or rec["id"],
         "friendly": pin.get("friendly") or "",
         "cabrillo": cabs,
         "adif": adifs,
         "domfiles": domfiles,
         "layouts": layouts,
      })
   return contests


def mode_family(contest):
   """CW / SSB / RTTY / DIGI when the id or display names one, else ''."""
   text = (contest["id"] + " " + contest["display"]).upper()
   for fam, words in (("CW", ("-CW", " CW")), ("SSB", ("-SSB", " SSB", "PHONE")),
                      ("RTTY", ("RTTY",)), ("DIGI", ("DIG",))):
      if any(w in text for w in words):
         return fam
   return ""


# -------------------------------------------------------------- .dom reading

def load_dom(name, seen=None):
   """(aliases, multipliers) of one .dom with its INCLUDE FILEs, or None.

   Mirrors logdom.EnumDOMFILE: a line starting 'INCLUDE FILE' loads that
   file; a line holding '=' is an entry 'QTH[ > Mult] = alias, alias, ^Name'.
   Aliases are upper-cased; a '^' word is a display name, not an alias.
   """
   if seen is None:
      seen = set()
   path = find_case_insensitive(DOM_DIR, name)
   if path is None or path.lower() in seen:
      return None
   seen.add(path.lower())
   aliases = set()
   mults = collections.OrderedDict()
   for raw in read_text(path).splitlines():
      line = raw.strip()
      if line.upper().startswith("INCLUDE FILE"):
         sub = load_dom(line[len("INCLUDE FILE"):].strip(), seen)
         if sub:
            aliases |= sub[0]
            for k, v in sub[1].items():
               mults.setdefault(k, set()).update(v)
      if "=" not in line:
         continue
      left, right = line.split("=", 1)
      left = left.strip()
      if ">" in left:
         qth, mult = left.split(">", 1)
         qth = qth.strip()
      else:
         qth = left
      words = [w.strip().upper() for w in right.split(",")]
      words = [w for w in words if w and not w.startswith("^")]
      aliases.update(words)
      mults.setdefault(qth.upper(), set()).update(words)
   return aliases, mults


# ------------------------------------------------------------------ UDC side

def udc_mode(rec):
   return (rec["contest"].get("Mode") or "").strip().upper()


def udc_layout(rec):
   """The kinds of the UDC CabrilloString's sent and received columns."""
   fields = [f["field"] for f in rec.get("cabrillo_fields") or []]
   if "CallSign" not in fields:
      return None
   words = (rec["contest"].get("DefaultContestExchange") or "").split()

   def word_kind(w):
      if w.upper() in RST_WORDS:
         return "RST"
      if w == "#" or re.fullmatch(r"0\d+", w):
         return "NR"
      return "EXCH"

   sent, rcvd = [], []
   side = sent
   for f in fields:
      if f == "CallSign":
         side = rcvd
      elif f == "Space":
         continue
      elif f in ("SNT", "RCV"):
         side.append("RST")
      elif f in ("SentNr", "RcvNr"):
         side.append("NR")
      elif f == "SentExch":
         side.extend([word_kind(w) for w in words] or ["EXCH"])
      elif f.startswith("SentExchPart"):
         try:
            k = int(f[len("SentExchPart"):]) - 1
         except ValueError:
            k = -1
         side.append(word_kind(words[k]) if 0 <= k < len(words) else "EXCH")
      elif f in GENERIC_UDC_FIELDS:
         # N1MM puts a received serial in Exchange1 as often as a QTH, so a
         # generic box says nothing about which it is.
         side.append("ANY")
      else:
         side.append("EXCH")
   return {"sent": sent, "rcvd": rcvd, "fields": fields}


# UDC boxes that may hold a number or a word.
GENERIC_UDC_FIELDS = {"Exchange1", "Misc", "Comment", "LastExch"}


def kinds_agree(udc_kinds, tr4w_kinds):
   if len(udc_kinds) != len(tr4w_kinds):
      return False
   for u, t in zip(udc_kinds, tr4w_kinds):
      if u == "ANY":
         if t not in ("NR", "EXCH"):
            return False
      elif u != t:
         return False
   return True


def render_layout(lay):
   return ("sent " + (" ".join(lay["sent"]) or "-") +
           " | rcvd " + (" ".join(lay["rcvd"]) or "-"))


def find_sec(rec, cache):
   """(path, label, entries) for the UDC's section list, or None.

   Looks for the file its MultWindowType (or QsoErrorString) names: in its
   own bundle first, then as a loose file in files/, then in any bundle.
   """
   wanted = []
   for key in ("MultWindowType", "QsoErrorString"):
      v = (rec["contest"].get(key) or "").strip()
      if v and v.lower() not in ("state", "stateprovince", "province", "section",
                                 "provincie", "dok", "uba", "oblast", "numeric",
                                 "any", "grid", "numeric_not_empty",
                                 "any_not_empty"):
         wanted.append(v.lower())
   names = set()
   for w in wanted:
      names.add(w if w.endswith(".sec") else w + ".sec")
   for comp in rec.get("companions") or []:
      base = os.path.basename(comp["name"]).lower()
      refs = comp.get("referenced_by") or []
      if base.endswith(".sec") and (base in names or
                                   "Contest.MultWindowType" in refs or
                                   "Contest.QsoErrorString" in refs):
         names.add(base)
   if not names:
      return None
   extracted = os.path.join(cache, "extracted")
   own = os.path.join(extracted, rec["source_file"])
   search = []
   if os.path.isdir(own):
      search.append((own, "own bundle"))
   search.append((os.path.join(cache, "files"), "loose file"))
   for d in sorted(os.listdir(extracted)) if os.path.isdir(extracted) else []:
      p = os.path.join(extracted, d)
      if p != own:
         search.append((p, "bundle " + d))
   for base_dir, label in search:
      for root, _dirs, files in os.walk(base_dir):
         for fn in files:
            if fn.lower() in names:
               path = os.path.join(root, fn)
               return path, label + ": " + fn, parse_sec(path)
         if base_dir.endswith("files"):
            break
   return None


def parse_sec(path):
   entries = []
   for raw in read_text(path).splitlines():
      line = raw.strip()
      if not line or line.startswith("#") or line.lower().startswith("type="):
         continue
      entries.append(line.split()[0].upper())
   return entries


# ------------------------------------------------------------------ matching

def build_indexes(contests):
   idx = {k: collections.defaultdict(list) for k in
          ("cab_exact", "cab_norm", "id_adif", "names", "display")}
   for c in contests:
      for cab in c["cabrillo"]:
         idx["cab_exact"][cab.strip().upper()].append(c)
         idx["cab_norm"][norm_code(cab)].append(c)
      for v in [c["id"]] + c["adif"]:
         idx["id_adif"][norm_code(v)].append(c)
      for v in [c["id"]] + c["adif"] + c["cabrillo"]:
         idx["names"][norm_code(v)].append(c)
      for v in (c["display"], c["friendly"]):
         if v:
            idx["display"][norm_text(v)].append(c)
   for table in idx.values():
      for key, lst in table.items():
         uniq = []
         for c in lst:
            if c not in uniq:
               uniq.append(c)
         table[key] = uniq
   return idx


def match_record(rec, idx, by_id):
   """(method, [contests], note) -- the strongest method that finds any."""
   c = rec["contest"]
   name = (c.get("Name") or "").strip()
   for uname, ufile, tid, reason in CURATED_MATCHES:
      if name.upper() == uname.upper() and (ufile is None or
                                            ufile.lower() == rec["source_file"].lower()):
         return "curated", [by_id[tid]], reason
   cab = (c.get("CabrilloName") or "").strip()
   displays = [c.get("DisplayName") or ""]
   if rec.get("display_page") and rec["display_page"].get("display_name"):
      displays.append(rec["display_page"]["display_name"])
   attempts = [
      ("cabrillo-exact", idx["cab_exact"].get(cab.upper()) if cab else None),
      ("cabrillo-normalized", idx["cab_norm"].get(norm_code(cab)) if cab else None),
      ("cabrillo-to-id", idx["id_adif"].get(norm_code(cab)) if cab else None),
      ("name-to-id", idx["names"].get(norm_code(name)) if name else None),
   ]
   for d in displays:
      if norm_text(d):
         attempts.append(("display-exact", idx["display"].get(norm_text(d))))
   for method, found in attempts:
      if found:
         return method, list(found), ""
   return None, [], ""


def tie_break(rec, found):
   """Pick one contest by the UDC's Mode, or None."""
   m = udc_mode(rec)
   fam = {"CW": "CW", "SSB": "SSB", "RTTY": "RTTY", "DIGI": "DIGI",
          "DIGITAL": "DIGI"}.get(m)
   if not fam:
      return None
   hits = [c for c in found if mode_family(c) == fam]
   return hits[0] if len(hits) == 1 else None


def candidates(rec, contests):
   """TR4W contests whose display names share identifying words."""
   c = rec["contest"]
   words = sig_words(c.get("DisplayName")) | sig_words(
      (rec.get("display_page") or {}).get("display_name"))
   words |= {w.lower() for w in re.split(r"[-_\s]+", c.get("CabrilloName") or "")
             if len(w) > 2 and w.lower() not in STOP_WORDS}
   out = []
   for t in contests:
      twords = sig_words(t["display"]) | sig_words(t["friendly"])
      twords |= {w.lower() for cab in t["cabrillo"]
                 for w in re.split(r"[-_\s]+", cab)
                 if len(w) > 2 and w.lower() not in STOP_WORDS}
      shared = words & twords
      if not shared:
         continue
      union = words | twords
      score = len(shared) / len(union) if union else 0
      if score >= 0.34 and (len(shared) >= 2 or score >= 0.5):
         out.append((score, t, sorted(shared)))
   out.sort(key=lambda x: -x[0])
   return out


# ------------------------------------------------------------------ findings

def base_row(t, rec, method):
   c = rec["contest"]
   return {
      "tr4w_id": t["id"] if t else "",
      "tr4w_display": t["display"] if t else "",
      "tr4w_cabrillo": " / ".join(t["cabrillo"]) if t else "",
      "udc_file": rec["source_file"] + (
         "" if rec["udc_member"] == rec["source_file"] else ":" + rec["udc_member"]),
      "udc_name": c.get("Name", ""),
      "udc_display": c.get("DisplayName", ""),
      "udc_cabrillo": c.get("CabrilloName", ""),
      "match_method": method or "",
      "finding_kind": "",
      "tr4w_value": "",
      "udc_value": "",
      "note": "",
   }


def finding(t, rec, method, kind, tval, uval, note):
   row = base_row(t, rec, method)
   row.update({"finding_kind": kind, "tr4w_value": tval,
               "udc_value": uval, "note": note})
   return row


def describe_udc(rec):
   L = rec.get("listing") or {}
   d = (L.get("description") or "").strip()
   return d[:160]


def pair_findings(t, rec, method, q98, cache, note):
   rows = []
   c = rec["contest"]
   rows.append(finding(t, rec, method, "match", "", "", note))

   # Cabrillo CONTEST: name.
   ucab = (c.get("CabrilloName") or "").strip()
   if ucab and ucab.upper() not in (x.strip().upper() for x in t["cabrillo"]):
      how = ("spelling differs only in case/blanks/'-'/'_'"
             if norm_code(ucab) in (norm_code(x) for x in t["cabrillo"])
             else "different name")
      if "sample" in describe_udc(rec).lower():
         how += " (the UDC listing calls itself a sample: weak evidence)"
      rows.append(finding(t, rec, method, "cabrillo-name",
                          " / ".join(t["cabrillo"]), ucab,
                          how + "; check the sponsor's Cabrillo CONTEST: value"))
   if not t["cabrillo"]:
      rows.append(finding(t, rec, method, "cabrillo-name", "(none)", ucab,
                          "TR4W writes no CONTEST: line in the matrix"))

   # QSO: column layout.
   ulay = udc_layout(rec)
   if ulay and t["layouts"]:
      tsigs = collections.OrderedDict()
      for vname, lay in t["layouts"].items():
         tsigs.setdefault(render_layout(lay), []).append(vname)
      usig = render_layout(ulay)
      agrees = any(kinds_agree(ulay["sent"], lay["sent"]) and
                   kinds_agree(ulay["rcvd"], lay["rcvd"])
                   for lay in t["layouts"].values())
      if not agrees:
         same_counts = any(
            len(ulay["sent"]) == len(lay["sent"]) and
            len(ulay["rcvd"]) == len(lay["rcvd"])
            for lay in t["layouts"].values())
         tval = "; ".join("%s [%s]" % (s, ",".join(v)) for s, v in tsigs.items())
         first = next(iter(t["layouts"].values()))
         tval += "; e.g. " + first["line"]
         uval = usig + "; CabrilloString " + " ".join(ulay["fields"])
         dce = (c.get("DefaultContestExchange") or "").strip()
         if dce:
            uval += "; DefaultContestExchange " + dce
         rows.append(finding(t, rec, method, "exchange-layout", tval, uval,
                             ("same column count, different kinds or ORDER"
                              if same_counts else "different column count") +
                             "; a lead -- check the sponsor's Cabrillo template"))

   # Bands and modes, only where TR4W's Q98 data is silent.
   q = q98.get(t["id"])
   if q is not None:
      umode = c.get("Mode") or ""
      if not q["modes"] and umode:
         rows.append(finding(t, rec, method, "mode", "(Q98 has no modes)",
                             umode, "UDC Mode (BOTH = all modes); " +
                             describe_udc(rec)))
      mb = (c.get("MultiplierBands") or "").strip()
      warc = (c.get("ShowWarcBands") or "").strip()
      ppc = (c.get("PointsPerContact") or "").strip()
      if not q["bands"] and (mb or warc or re.search(r"\d+\s*(m|cm)\b", ppc, re.I)):
         uval = "MultiplierBands %s (%s); ShowWarcBands %s; PointsPerContact %s" % (
            mb or "-", MULTIPLIER_BANDS.get(mb, "default"), warc or "-", ppc or "-")
         rows.append(finding(t, rec, method, "bands", "(Q98 has no bands)", uval,
                             "a UDC has no band list; this is the nearest it says"))

   # Section list against the .dom.
   sec = find_sec(rec, cache)
   if sec:
      path, label, entries = sec
      entry_set = set(entries)
      best = None
      for dom in t["domfiles"]:
         loaded = load_dom(dom)
         if not loaded:
            continue
         aliases, mults = loaded
         overlap = len(entry_set & aliases)
         if best is None or overlap > best[0]:
            best = (overlap, dom, aliases, mults)
      if best is None:
         rows.append(finding(t, rec, method, "section-list",
                             "no domestic file (%s)" % (", ".join(t["domfiles"]) or "none"),
                             "%s: %d entries" % (label, len(entries)),
                             "TR4W loads no list this UDC validates against"))
      else:
         overlap, dom, aliases, mults = best
         not_accepted = [e for e in entries if e not in aliases]
         uncovered = [m or "(empty)" for m, al in mults.items() if not (al & entry_set)]
         if not_accepted or uncovered:
            tval = "%s: %d multipliers, %d aliases; multipliers no UDC entry names: %d %s" % (
               dom, len(mults), len(aliases), len(uncovered),
               " ".join(uncovered[:20]) + (" ..." if len(uncovered) > 20 else ""))
            uval = "%s: %d entries; not accepted by TR4W: %d %s" % (
               label, len(entries), len(not_accepted),
               " ".join(not_accepted[:20]) + (" ..." if len(not_accepted) > 20 else ""))
            rows.append(finding(t, rec, method, "section-list", tval, uval,
                                "%d of %d UDC entries are TR4W aliases" % (
                                   overlap, len(entries))))

   # Q98-open identification.
   if q is not None and q["open"]:
      rows.append(finding(t, rec, method, "q98-open",
                          q["question"],
                          "Mode %s; MultiplierBands %s; %s" % (
                             c.get("Mode", ""), c.get("MultiplierBands", "") or "-",
                             describe_udc(rec)),
                          "a UDC identifies this open Q98 contest -- a lead, below "
                          "D7/sponsor/WA7BNM/DXLog"))
   return rows


# ---------------------------------------------------------------------- main

def write_csv(path, rows):
   with open(path, "w", encoding="utf-8-sig", newline="") as f:
      w = csv.DictWriter(f, fieldnames=CSV_COLUMNS, quoting=csv.QUOTE_ALL,
                         lineterminator="\r\n")
      w.writeheader()
      for r in rows:
         w.writerow(r)


def main():
   ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
   ap.add_argument("--cache", default=DEFAULT_CACHE)
   ap.add_argument("--q98", default=Q98_DOC,
                   help="bands/modes table (resolved Q98 CSV or the docs one)")
   args = ap.parse_args()

   with open(os.path.join(args.cache, "udc_index.json"), encoding="utf-8") as f:
      index = json.load(f)
   records = index["contests"]
   contests = load_tr4w()
   by_id = {c["id"]: c for c in contests}
   for _u, _f, tid, _r in CURATED_MATCHES + Q98_LEADS + CANDIDATE_LEADS:
      if tid not in by_id:
         sys.exit("curated id not in the matrix: " + tid)
   q98 = load_q98(args.q98)
   idx = build_indexes(contests)

   rows = []
   outcome = collections.Counter()
   method_count = collections.Counter()
   matched_ids = set()
   for rec in records:
      method, found, note = match_record(rec, idx, by_id)
      if len(found) > 1:
         pick = tie_break(rec, found)
         if pick is not None:
            note = "%s matched %s; the UDC Mode %s picks %s" % (
               method, ", ".join(c["id"] for c in found), udc_mode(rec), pick["id"])
            found = [pick]
      if len(found) == 1:
         t = found[0]
         outcome["matched"] += 1
         method_count[method] += 1
         matched_ids.add(t["id"])
         rows.extend(pair_findings(t, rec, method, q98, args.cache, note))
      elif len(found) > 1:
         outcome["ambiguous"] += 1
         for t in found:
            rows.append(finding(t, rec, method, "ambiguous-match", "", "",
                                "%s ties this UDC to %d TR4W contests; the UDC "
                                "Mode %s does not pick one" % (
                                   method, len(found), udc_mode(rec) or "-")))
      else:
         cands = candidates(rec, contests)
         leads = [(tid, reason) for uname, ufile, tid, reason in CANDIDATE_LEADS
                  if rec["contest"].get("Name", "").upper() == uname.upper() and
                  rec["source_file"].lower() == ufile.lower()]
         if cands or leads:
            outcome["ambiguous"] += 1
            for tid, reason in leads:
               rows.append(finding(by_id[tid], rec, "curated-candidate",
                                   "match-candidate", "", "",
                                   reason + " -- NOT a match until confirmed"))
            for score, t, shared in cands[:3]:
               if any(t["id"] == tid for tid, _r in leads):
                  continue
               rows.append(finding(t, rec, "token-overlap", "match-candidate", "", "",
                                   "shares %s (score %.2f) -- NOT a match until "
                                   "confirmed and added to CURATED_MATCHES" % (
                                      " ".join(shared), score)))
         else:
            outcome["unmatched"] += 1
         rows.append(finding(None, rec, "", "not-in-tr4w", "",
                             "Mode %s; %s" % (rec["contest"].get("Mode", ""),
                                              (rec.get("listing") or {}).get("page_url", "")),
                             describe_udc(rec)))

   # Curated Q98 leads.
   for uname, ufile, tid, reason in Q98_LEADS:
      for rec in records:
         if (rec["contest"].get("Name", "").upper() == uname.upper() and
               rec["source_file"].lower() == ufile.lower()):
            c = rec["contest"]
            rows.append(finding(by_id[tid], rec, "curated-lead", "q98-open",
                                q98.get(tid, {}).get("question", ""),
                                "Mode %s; MultiplierBands %s; PointsPerContact %s; %s" % (
                                   c.get("Mode", ""), c.get("MultiplierBands", "") or "-",
                                   c.get("PointsPerContact", "") or "-", describe_udc(rec)),
                                reason))

   # Open Q98 contests no UDC touched at all.
   touched = {r["tr4w_id"] for r in rows if r["finding_kind"] in
              ("q98-open", "match-candidate", "ambiguous-match")}
   for cid, q in sorted(q98.items()):
      if q["open"] and cid in by_id and cid not in matched_ids and cid not in touched:
         rows.append({
            "tr4w_id": cid, "tr4w_display": by_id[cid]["display"],
            "tr4w_cabrillo": " / ".join(by_id[cid]["cabrillo"]),
            "udc_file": "", "udc_name": "", "udc_display": "", "udc_cabrillo": "",
            "match_method": "", "finding_kind": "q98-open",
            "tr4w_value": q["question"], "udc_value": "",
            "note": "no UDC identifies this contest"})

   out = os.path.join(args.cache, "crosswalk.csv")
   write_csv(out, rows)

   kinds = collections.Counter(r["finding_kind"] for r in rows)
   print("UDC records: %d" % len(records))
   print("  matched %d, ambiguous %d, unmatched %d" % (
      outcome["matched"], outcome["ambiguous"], outcome["unmatched"]))
   print("  by method: " + ", ".join("%s %d" % kv for kv in sorted(method_count.items())))
   print("TR4W contests: %d, with at least one UDC match: %d" % (
      len(contests), len(matched_ids)))
   print("rows by finding_kind: " + ", ".join("%s %d" % kv for kv in sorted(kinds.items())))
   print("wrote " + out)


if __name__ == "__main__":
   main()
