"""Extract N1MM Logger's BUILT-IN contests and cross-walk them against TR4W.

Run:
   python -I tools/udc/n1mm_builtin.py "<N1MM Logger>/Source"
          [--cache DIR] [--names CSV --names-out CSV]

N1MM's built-in contest modules register themselves with

   api.AddChgContest name, DisplayName, CabrilloName, Mode, DupeType,
                     Multiplier1Name, Multiplier2Name, Multiplier3Name,
                     Period, PointsPerContact[, CabrilloVersion]

(ContestPlugInAPI.cls; DupeType 1 = all bands, 2 = each band, 3 = each band
and mode, 4 = all dupes allowed; CabrilloVersion defaults to "2.0").

The N1MM source is NOT ours and is NOT in this repository, which is public.
Pass its Source directory as the argument; only the Visual Basic source files
(.cls .bas .frm .ctl) directly in that directory are read.  Any other file
there that mentions AddChgContest (editor backups, a .wri) is listed as
excluded, never parsed.  Output lands in the gitignored <cache>:

   <cache>/n1mm_builtin.csv     one row per AddChgContest call
   <cache>/n1mm_crosswalk.csv   one row per TR4W contest: its N1MM match

and, with --names IN --names-out OUT, NY4I's contest-names table with seven
N1MM / UDC columns added (OUT may be IN: the step is re-runnable, replacing
the columns it added before and copying every other column through).  CSVs
are UTF-8 with BOM, every field quoted, CRLF.

Provenance: the N1MM source NY4I holds is from a review he did for the N1MM
team c. 2014 ("N1MM Logger source, c. 2014").  Its Cabrillo names may be
stale against today's sponsors -- one more reason the sponsor's CURRENT
Cabrillo name is the verdict where TR4W and N1MM differ.

TR4W's side is crosswalk.py's reader (the contest matrix's frozen records and
the identity pins) -- imported, not copied.  Source ranking (NY4I):
D7 > sponsor's Cabrillo template > WA7BNM > DXLog > N1MM built-in > UDC.  A
difference is a LEAD; nothing here changes a TR4W class.

Matching, strongest first: cabrillo-exact, cabrillo-normalized,
cabrillo-to-id, name-to-id, display-exact (crosswalk.py's methods), then
N1MM_CURATED below, each with its evidence.  A method that ties one N1MM
entry to several TR4W contests is resolved by the N1MM Mode only when that
picks exactly one; otherwise the entry is ambiguous and counts as no match.
A TR4W contest that several N1MM entries with DIFFERENT Cabrillo names match
is ambiguous too, and is listed, never counted as matched.

Standard library only.
"""

import argparse
import collections
import csv
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# python -I does not put the script's directory on sys.path; crosswalk.py
# is our own sibling module, so add exactly that directory.
sys.path.insert(0, HERE)
import crosswalk  # noqa: E402

DEFAULT_CACHE = os.path.join(HERE, "cache")
VB_EXTENSIONS = (".cls", ".bas", ".frm", ".ctl")

ARG_NAMES = ["name", "display", "cabrillo", "mode", "dupe_type",
             "mult1", "mult2", "mult3", "period", "points_per_contact",
             "cabrillo_version"]

DUPE_TYPES = {"1": "all bands", "2": "each band", "3": "each band and mode",
              "4": "all dupes allowed"}

RECORD_COLUMNS = [
   "file", "line", "procedure", "branch", "status",
   "name", "display", "cabrillo", "mode", "dupe_type", "dupe_type_meaning",
   "mult1", "mult2", "mult3", "period", "points_per_contact",
   "cabrillo_version", "raw_args",
]

CROSSWALK_COLUMNS = [
   "tr4w_id", "tr4w_display", "tr4w_cabrillo", "outcome", "match_method",
   "n1mm_name", "n1mm_display", "n1mm_cabrillo", "n1mm_mode", "n1mm_file",
   "cabrillo_agrees", "note",
]

NEW_NAME_COLUMNS = [
   "N1MM name", "N1MM display name", "N1MM Cabrillo name", "N1MM mode",
   "UDC Cabrillo name", "WA7BNM Cabrillo name", "Cabrillo agrees?", "Note",
]

# An N1MM entry no automatic method can tie to a TR4W contest, each checked
# by reading both sides.  (N1MM name, [TR4W registry ids], evidence).  One id
# is a match; several are resolved by the N1MM Mode when that picks exactly
# one, else the entry is AMBIGUOUS and counts as no match.
N1MM_CURATED = [
   ("ALLASIACW", ["ALL-ASIAN-DX-CW"],
    "CAA.cls 'AA CW': the All Asian DX contest (WPX-prefix mults outside Asia)"),
   ("ALLASIASSB", ["ALL-ASIAN-DX-SSB"], "CAA.cls 'AA SSB', as above"),
   ("APSCW", ["AP-SPRINT"],
    "CAPSprint.cls 'Asia Pacific Sprint CW'; TR4W's one AP-SPRINT (QRZ.RU 77) "
    "serves both modes"),
   ("APSSSB", ["AP-SPRINT"], "CAPSprint.cls 'Asia Pacific Sprint SSB', as above"),
   ("9ACW", ["CROATIAN"],
    "C9ACW.cls: CW only, 3rd full weekend of December, serial exchange -- the "
    "HRS Croatian DX Contest (TR4W WA7BNM 206)"),
   ("CQMMDX", ["CQMM"], "CCQMMDX.CLS 'CQ MM DX' is the CQMM DX Contest"),
   ("CWOPSOPEN", ["CWOPEN"], "CCWOPS.cls 'CWOPSOPEN': the CWOps CW Open"),
   ("FOCBWQP", ["BWQP"],
    "CCWOPS.cls 'FOCBWQP': FOC's Bill Windle QSO Party"),
   ("EUHFC", ["EUROPEAN HFC"],
    "CEUHFC.cls: exchange is the two-digit licence year, EU-only points -- "
    "the European HF Championship"),
   ("GACW", ["GACW-WWSA-CW"],
    "CCqWw.cls: 'Added GACW CW (WWSA) contest ... non SA get 5 points "
    "working SA'"),
   ("GCUP", ["GAGARIN-CUP"], "CGCup.cls 'Gagarin Cup'"),
   ("QCWAQSO", ["QCWA"],
    "CQCWAQSO.cls 'QCWA QSO Party by K3CT' -- TR4W's QCWA is 'QCWA QSO Party'"),
   ("RFCCW", ["RF-CUP-CW"],
    "cRFC.cls cites qrz.ru/contest/detail/24 'Russian Federation Cup'; TR4W "
    "RF-CUP-SSB's QRZ.RU id is 24, and RF-CUP is TR4W's Russian Cup"),
   ("RFCSSB", ["RF-CUP-SSB"], "cRFC.cls, as above"),
   ("RFCDIGI", ["RF-CUP-DIG"], "cRFC.cls 'RFC DIGI', registered beside RFC CW/SSB"),
   ("WWPMC", ["WW PMC"], "cWWPMC.cls 'WWPMC'"),
   ("WRTC", ["WRTC"],
    "cWRTC2010.cls 'WRTC' -- it writes IARU-HF because WRTC is contested "
    "inside the IARU HF Championship; without this the Cabrillo name would "
    "tie it to TR4W's IARU-HF"),
   ("OKOMDX", ["OK-OM DX CW", "OK-OM DX SSB"],
    "COKOMDX.cls 'OK-OM DX', Mode CW in the registration"),
   ("ROPOCO", ["RSGB-ROPOCO-CW", "RSGB-ROPOCO-SSB"],
    "CROPOCO.cls 'RSGB ROPOCO', Mode CW in the registration"),
   ("UKRCHCW", ["UKRAINE CHAMPIONSHIP"],
    "CUKRChamp.cls 'Championship of Ukraine': oblast (2 letters) + serial, "
    "2 points a QSO -- D7's row is QSONumberDomesticQTHExchange, 2 points, "
    "ukraine.dom's two-letter oblasts (ZP, KV ...).  N1MM also adds 10 for "
    "each oblast per session and runs 160/80 m in four one-hour sessions"),
   ("UKRCHSSB", ["UKRAINE CHAMPIONSHIP"], "CUKRChamp.cls, as above"),
   ("UKRCHRTTY", ["UKRAINE CHAMPIONSHIP"], "CUKRChamp.cls, as above"),
   ("UKRRTTYOPN", ["UKRAINE CHAMPIONSHIP"],
    "CUKRChamp.cls 'UKR CHAMP RTTY OPEN', same Cabrillo name as UKRCHRTTY"),
   # Several TR4W contests; the N1MM Mode cannot pick one, so AMBIGUOUS.
   ("EUSCW", ["EU-SPRINT-SPRING-CW", "EU-SPRINT-AUTUMN-CW"],
    "CEUSprint.cls 'European Sprint CW' -- one module for both seasons"),
   ("EUSSSB", ["EU-SPRINT-SPRING-SSB", "EU-SPRINT-AUTUMN-SSB"],
    "CEUSprint.cls 'European Sprint SSB' -- one module for both seasons"),
   ("RAC", ["CANADA DAY", "CANADA WINTER"],
    "CRAC.cls 'RAC' -- one module for both RAC contests"),
   ("FDREG1", ["REGION 1 FIELD DAY", "REGION 1 FIELD DAY-RCC-CW",
               "REGION 1 FIELD DAY-RCC-SSB"],
    "CFdReg1.cls 'IARU Reg. 1 Fieldday', Mode Both"),
   ("MiniTestCW", ["MINITEST", "MINI40", "MINI80"],
    "CDx.cls 'Mini Test CW' -- which TR4W Mini-Test, if any?"),
   ("RSGB160CW", ["RSGB-160"],
    "CRSGB160.cls: RSGB 1.8 MHz CW, RST + serial (+ UK district)"),
   ("RSGB1ST160", ["RSGB-160"], "CRSGB160.cls '1st' 1.8 MHz event"),
   ("RSGB2ND160", ["RSGB-160"], "CRSGB160.cls '2nd' 1.8 MHz event"),
]

# An automatic match that is WRONG, each checked.  (N1MM name, TR4W id, why)
N1MM_REJECTED = [
]

# The sponsor's (or a higher source's) answer where TR4W and N1MM write
# different Cabrillo CONTEST: names.  TR4W id -> note.  A rename stays NY4I's
# call: a stored name keeps its meaning forever and a rename keeps an alias.
#
# Most rows need no entry: the WA7BNM column and its note (the Cabrillo name
# and the aliases WA7BNM's detail page lists) answer them.  These are the
# rows WA7BNM cannot answer, each checked 2026-10-19.
SPONSOR_VERDICTS = {
   "AP-SPRINT":
      "SPONSOR: the AP Sprint rules (jsfc.org/apsprint/aprule.txt, revised "
      "January 2024) give 'CONTEST: AP-SPRINT' for both modes -- TR4W is "
      "right; N1MM's per-mode names are not the sponsor's",
   "BWQP":
      "UNSETTLED: the FOC page (g4foc.org/bill-windle-qso-party) names no "
      "CONTEST: value and WA7BNM 479 lists none",
   "CIS":
      "MOOT: inactive since 2004 (WA7BNM 197); the sponsor page "
      "(srars.org/rules.htm) names no CONTEST: value",
   "QCWA":
      "UNSETTLED: the QCWA 2021 rules ask only for 'Cabrillo format'; "
      "WA7BNM 332 (inactive) lists no name",
   "RF-CUP-CW":
      "UNSETTLED: the rules are on qrz.ru (contest 27), unreachable from "
      "here by design; WA7BNM lists no name",
   "RF-CUP-SSB":
      "UNSETTLED: the rules are on qrz.ru (contest 24, the page cRFC.cls "
      "cites), unreachable from here by design; WA7BNM lists no name",
   "RF-CUP-DIG":
      "UNSETTLED: the rules are on qrz.ru (contest 86), unreachable from "
      "here by design; WA7BNM 595 lists no name",
   "UKRAINE CHAMPIONSHIP":
      "LEAD (Q98): WA7BNM 334 'Open Ukraine RTTY Championship' writes "
      "UKR-CHAMP-RTTY, as N1MM does: RTTY, 160-10 m, 2-letter region + "
      "serial, 2 points, 10 per new region per period, no multipliers.  "
      "Whether TR4W's D7 contest is that event (or the CW/SSB Championship "
      "N1MM also registers) is Q98's open question",
   "WWIH":
      "MOOT: inactive (WA7BNM 552); the rules PDF is gone (HTTP 404)",
   "WRTC":
      "WRTC is scored inside the IARU HF Championship; WA7BNM and N1MM both "
      "write IARU-HF for it.  Whether TR4W's WRTC should is NY4I's call",
   "SOUTH AMERICAN WW":
      "LEAD (Q98): WA7BNM 45 (GACW WWSA CW, Cabrillo WWSA) accepts "
      "'SOUTH AMERICAN WW' -- TR4W's own Cabrillo name -- as an alias, so the "
      "WWSA robot takes TR4W's log as WWSA.  But today's WWSA scores RST + CQ "
      "zone, 0/1/3 and 5 for South America, not D7's RST + continent, 2/10",
}


# ------------------------------------------------------------ VB reading

def strip_comment(line):
   """(code, comment) of one physical VB line; '"' toggles a string."""
   in_string = False
   for i, ch in enumerate(line):
      if ch == '"':
         in_string = not in_string
      elif ch == "'" and not in_string:
         return line[:i], line[i + 1:]
   code = line
   if re.match(r"\s*Rem\b", code, re.I):
      return "", code
   return code, ""


def logical_lines(text):
   """(first line number, code) with ' _' continuations joined."""
   pending = None
   start = 0
   for number, raw in enumerate(text.splitlines(), 1):
      code, _comment = strip_comment(raw)
      if pending is None:
         start = number
         pending = ""
      stripped = code.rstrip()
      if stripped.endswith(" _") or stripped == "_":
         pending += stripped[:-1] + " "
         continue
      yield start, pending + code
      pending = None
   if pending:
      yield start, pending


def split_statements(code):
   """Split on ':' outside strings (VB's statement separator)."""
   parts = []
   cur = []
   in_string = False
   for ch in code:
      if ch == '"':
         in_string = not in_string
      if ch == ":" and not in_string:
         parts.append("".join(cur))
         cur = []
      else:
         cur.append(ch)
   parts.append("".join(cur))
   return [p.strip() for p in parts if p.strip()]


def split_args(text):
   args = []
   cur = []
   depth = 0
   in_string = False
   for ch in text:
      if ch == '"':
         in_string = not in_string
      elif not in_string and ch == "(":
         depth += 1
      elif not in_string and ch == ")":
         depth -= 1
      if ch == "," and depth == 0 and not in_string:
         args.append("".join(cur).strip())
         cur = []
      else:
         cur.append(ch)
   if "".join(cur).strip():
      args.append("".join(cur).strip())
   return args


def literal(arg):
   """(True, value) for a string or number literal, else (False, arg)."""
   m = re.fullmatch(r'"((?:[^"]|"")*)"', arg)
   if m:
      return True, m.group(1).replace('""', '"')
   if re.fullmatch(r"-?\d+(\.\d+)?", arg):
      return True, arg
   return False, arg


PROC_START = re.compile(
   r"^(?:(?:Public|Private|Friend)\s+)?(?:Static\s+)?"
   r"(Sub|Function|Property\s+(?:Get|Let|Set))\s+(\w+)", re.I)
PROC_END = re.compile(r"^End\s+(Sub|Function|Property)\b", re.I)
CALL = re.compile(r"(?:^|[.\s])AddChgContest\b(.*)$", re.I)


class Branches:
   """The If / Select Case conditions enclosing the current statement."""

   def __init__(self):
      self.frames = []

   def reset(self):
      self.frames = []

   def describe(self, extra=None):
      parts = [f["current"] for f in self.frames]
      if extra:
         parts.append(extra)
      return " / ".join(parts)

   def feed(self, stmt):
      """Update the stack; answer the single-line If condition, if any."""
      m = re.match(r"^If\s+(.+?)\s+Then\s*(.*)$", stmt, re.I)
      if m:
         if m.group(2).strip():
            return "If " + m.group(1), m.group(2).strip()
         self.frames.append({"conds": [m.group(1)], "current": "If " + m.group(1)})
         return None, None
      m = re.match(r"^ElseIf\s+(.+?)\s+Then\s*$", stmt, re.I)
      if m and self.frames:
         f = self.frames[-1]
         f["current"] = "ElseIf %s (not: %s)" % (m.group(1), "; ".join(f["conds"]))
         f["conds"].append(m.group(1))
         return None, None
      if re.match(r"^Else\s*$", stmt, re.I) and self.frames:
         f = self.frames[-1]
         f["current"] = "Else (not: %s)" % "; ".join(f["conds"])
         return None, None
      if re.match(r"^End\s+(If|Select)\b", stmt, re.I) and self.frames:
         self.frames.pop()
         return None, None
      m = re.match(r"^Select\s+Case\s+(.+)$", stmt, re.I)
      if m:
         self.frames.append({"conds": [], "expr": m.group(1),
                             "current": "Select Case " + m.group(1)})
         return None, None
      m = re.match(r"^Case\s+(.+)$", stmt, re.I)
      if m and self.frames and "expr" in self.frames[-1]:
         f = self.frames[-1]
         f["current"] = "Select Case %s: Case %s" % (f["expr"], m.group(1))
         return None, None
      return None, stmt


def parse_file(path):
   """Every AddChgContest call in one VB file, as records."""
   text = crosswalk.read_text(path)
   records = []
   branches = Branches()
   procedure = ""
   for number, code in logical_lines(text):
      for stmt in split_statements(code):
         m = PROC_START.match(stmt)
         if m:
            procedure = m.group(2)
            branches.reset()
            if m.group(2).lower() == "addchgcontest":
               continue
            continue
         if PROC_END.match(stmt):
            procedure = ""
            branches.reset()
            continue
         single_cond, rest = branches.feed(stmt)
         if rest is None:
            continue
         call = CALL.search(rest)
         if not call:
            continue
         arg_text = call.group(1).strip()
         if arg_text.startswith("(") and arg_text.endswith(")"):
            arg_text = arg_text[1:-1]
         args = split_args(arg_text)
         rec = {k: "" for k in RECORD_COLUMNS}
         rec.update({
            "file": os.path.basename(path), "line": str(number),
            "procedure": procedure,
            "branch": branches.describe(single_cond),
            "raw_args": arg_text,
         })
         values = [literal(a) for a in args]
         if len(args) not in (10, 11):
            rec["status"] = "unparsed: %d arguments, the API takes 10 or 11" % len(args)
         elif not all(ok for ok, _v in values):
            rec["status"] = "unparsed: non-literal argument(s) " + ", ".join(
               ARG_NAMES[i] for i, (ok, _v) in enumerate(values) if not ok)
         else:
            rec["status"] = "ok"
            for i, (_ok, v) in enumerate(values):
               rec[ARG_NAMES[i]] = v
            rec["dupe_type_meaning"] = DUPE_TYPES.get(rec["dupe_type"], "?")
            if not rec["cabrillo_version"]:
               rec["cabrillo_version"] = "2.0 (default)"
         records.append(rec)
   return records


def scan(source):
   records = []
   excluded = []
   for fn in sorted(os.listdir(source), key=str.lower):
      path = os.path.join(source, fn)
      if not os.path.isfile(path):
         continue
      if fn.lower().endswith(VB_EXTENSIONS):
         records.extend(parse_file(path))
      else:
         with open(path, "rb") as f:
            if b"addchgcontest" in f.read().lower():
               excluded.append(fn)
   return records, excluded


# ------------------------------------------------------------ matching

def match_entry(entry, idx, by_id):
   """(method, [contests]) for one N1MM entry."""
   for uname, tids, _why in N1MM_CURATED:
      if entry["name"].upper() == uname.upper():
         return "curated", [by_id[t] for t in tids]
   cab = entry["cabrillo"].strip()
   name = entry["name"].strip()
   attempts = [
      ("cabrillo-exact", idx["cab_exact"].get(cab.upper()) if cab else None),
      ("cabrillo-normalized",
       idx["cab_norm"].get(crosswalk.norm_code(cab)) if cab else None),
      ("cabrillo-to-id",
       idx["id_adif"].get(crosswalk.norm_code(cab)) if cab else None),
      ("name-to-id", idx["names"].get(crosswalk.norm_code(name)) if name else None),
      ("display-exact", idx["display"].get(crosswalk.norm_text(entry["display"]))
       if crosswalk.norm_text(entry["display"]) else None),
   ]
   rejected = {(u.upper(), t) for u, t, _w in N1MM_REJECTED}
   for method, found in attempts:
      found = [c for c in (found or []) if (name.upper(), c["id"]) not in rejected]
      if found:
         return method, found
   return None, []


def tie_break(entry, found):
   fam = {"CW": "CW", "SSB": "SSB", "RTTY": "RTTY"}.get(entry["mode"].strip().upper())
   if not fam:
      return None
   hits = [c for c in found if crosswalk.mode_family(c) == fam]
   return hits[0] if len(hits) == 1 else None


def cabrillo_agreement(tr4w_cab, n1mm_cab):
   """('Y' | 'N', detail)."""
   t = (tr4w_cab or "").strip()
   n = (n1mm_cab or "").strip()
   if not t:
      return "N", "TR4W writes no Cabrillo name; N1MM writes " + n
   if t == n:
      return "Y", ""
   if t.upper() == n.upper():
      return "Y", "differs in letter case only"
   if crosswalk.norm_code(t) == crosswalk.norm_code(n):
      return "N", "differs only in blanks / '-' / '_'"
   return "N", "different name"


WA7BNM_URL = "https://www.contestcalendar.com/cabnames.php"
WA7BNM_FILE = "wa7bnm_cabnames.html"


WA7BNM_DETAIL_URL = "https://www.contestcalendar.com/contestdetails.php?ref="
WA7BNM_DETAIL_DIR = "wa7bnm"


def fetch_url(url, path):
   import urllib.request
   req = urllib.request.Request(url, headers={
      "User-Agent": "Mozilla/5.0 (TR4W contest-data research)"})
   with urllib.request.urlopen(req, timeout=60) as resp:
      data = resp.read()
   with open(path, "wb") as f:
      f.write(data)


def fetch_wa7bnm(cache, refs):
   """Save WA7BNM's master list, and the detail page of each REF not yet
   cached, one request at a time.  The master list omits INACTIVE contests;
   a detail page states the Cabrillo name and its accepted aliases."""
   import time
   fetch_url(WA7BNM_URL, os.path.join(cache, WA7BNM_FILE))
   detail_dir = os.path.join(cache, WA7BNM_DETAIL_DIR)
   os.makedirs(detail_dir, exist_ok=True)
   for ref in sorted(set(refs), key=int):
      path = os.path.join(detail_dir, ref + ".html")
      if os.path.exists(path):
         continue
      try:
         time.sleep(1.5)
         fetch_url(WA7BNM_DETAIL_URL + ref, path)
      except Exception as exc:                  # keep going; report it
         print("WARNING: WA7BNM %s not fetched: %s" % (ref, exc), file=sys.stderr)


def html_cell(s):
   import html
   return html.unescape(re.sub(r"<[^>]+>", "", s)).replace("\xa0", " ").strip()


def load_wa7bnm(cache):
   """WA7BNM contest id -> {contest, cabrillo, aliases}.

   The master list is one table row per ACTIVE contest: the id (a
   contestdetails.php?ref= link), the contest name, the Cabrillo name.  A
   saved detail page, where there is one, overrides it and adds the aliases
   ('Cabrillo name:' and 'Cabrillo name aliases:' rows).
   """
   out = {}
   path = os.path.join(cache, WA7BNM_FILE)
   if not os.path.exists(path):
      print("NOTE: no %s -- run with --fetch-wa7bnm; the WA7BNM column stays "
            "empty" % path, file=sys.stderr)
      return out
   text = crosswalk.read_text(path)
   row = re.compile(r"<tr>\s*<td[^>]*>\s*<a[^>]*ref=(\d+)[^>]*>\s*\d+\s*</a>\s*</td>"
                    r"\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*</tr>", re.S | re.I)
   for m in row.finditer(text):
      out[m.group(1)] = {"contest": html_cell(m.group(2)),
                         "cabrillo": html_cell(m.group(3)), "aliases": []}
   detail_dir = os.path.join(cache, WA7BNM_DETAIL_DIR)
   if os.path.isdir(detail_dir):
      for fn in os.listdir(detail_dir):
         ref = fn[:-len(".html")]
         if not fn.endswith(".html") or not ref.isdigit():
            continue
         page = crosswalk.read_text(os.path.join(detail_dir, fn))
         entry = out.setdefault(ref, {"contest": "", "cabrillo": "", "aliases": []})
         m = re.search(r"Cabrillo name:\s*</td>\s*<td>(.*?)</td>", page, re.S | re.I)
         if m and html_cell(m.group(1)):
            entry["cabrillo"] = html_cell(m.group(1))
         m = re.search(r"Cabrillo name aliases:\s*</td>\s*<td>(.*?)</td>", page,
                       re.S | re.I)
         if m:
            # Split on <br/> BEFORE removing tags: one alias per line.
            entry["aliases"] = [html_cell(a) for a in re.split(r"<br\s*/?>",
                                                               m.group(1), flags=re.I)
                                if html_cell(a)]
         if not entry["contest"]:
            m = re.search(r"Terms of Use.*?<h\d[^>]*>(.*?)</h\d>", page, re.S | re.I)
            entry["contest"] = html_cell(m.group(1)) if m else ""
   return out


def udc_cabrillo_by_id(cache):
   """TR4W id -> UDC Cabrillo names, from crosswalk.csv's match rows."""
   out = collections.defaultdict(list)
   path = os.path.join(cache, "crosswalk.csv")
   if not os.path.exists(path):
      print("NOTE: no %s -- the UDC column stays empty" % path, file=sys.stderr)
      return out
   with open(path, encoding="utf-8-sig", newline="") as f:
      for r in csv.DictReader(f):
         if r["finding_kind"] == "match" and r["udc_cabrillo"]:
            if r["udc_cabrillo"] not in out[r["tr4w_id"]]:
               out[r["tr4w_id"]].append(r["udc_cabrillo"])
   return out


def write_csv(path, columns, rows):
   with open(path, "w", encoding="utf-8-sig", newline="") as f:
      w = csv.DictWriter(f, fieldnames=columns, quoting=csv.QUOTE_ALL,
                         lineterminator="\r\n")
      w.writeheader()
      for r in rows:
         w.writerow(r)


def contest_outcome(found):
   """'matched' / 'ambiguous' and a note, for one TR4W contest's N1MM hits.

   Several N1MM entries with ONE Cabrillo name, or one name per MODE (N1MM
   registering a two-mode contest once per mode), are a match.  Several
   names that the mode does not separate are ambiguous.
   """
   groups = collections.OrderedDict()
   for _m, e in found:
      groups.setdefault(e["cabrillo"].upper(), set()).add(e["mode"].upper())
   if len(groups) == 1:
      return "matched", ""
   modes = [next(iter(m)) for m in groups.values() if len(m) == 1]
   if len(modes) == len(groups) and len(set(modes)) == len(modes):
      return "matched", "N1MM registers one entry per mode"
   return "ambiguous", "several N1MM entries with different Cabrillo names"


def agreement_with_any(tr4w_cab, n1mm_cabs):
   """cabrillo_agreement against several N1MM names: Y if any agrees."""
   results = [cabrillo_agreement(tr4w_cab, n) for n in n1mm_cabs]
   for agree, detail in results:
      if agree == "Y":
         return agree, detail
   return results[0] if results else ("", "")


def wa7bnm_note(tr4w_cab, n1mm_cabs, wa7):
   """The WA7BNM answer, as a note: who agrees with it."""
   if wa7 is None:
      return "no WA7BNM entry"
   cab = wa7["cabrillo"]
   if not cab:
      return "WA7BNM %r lists no Cabrillo name" % wa7["contest"]
   aliases = [a.upper() for a in wa7["aliases"]]

   def verdict(who, names):
      names = [(n or "").strip().upper() for n in names]
      if cab.upper() in names:
         return who + " agrees"
      if any(n in aliases for n in names):
         return who + " writes an accepted alias"
      return who + " differs"

   text = "WA7BNM: %s" % cab
   if wa7["aliases"]:
      text += " (aliases %s)" % ", ".join(wa7["aliases"])
   parts = [verdict("TR4W", [tr4w_cab])]
   if n1mm_cabs:
      parts.append(verdict("N1MM", n1mm_cabs))
   return "%s -- %s" % (text, ", ".join(parts))


def wa7bnm_differs(tr4w_cab, wa7):
   """True when WA7BNM names a Cabrillo name TR4W neither writes nor aliases."""
   if not wa7 or not wa7["cabrillo"]:
      return False
   t = (tr4w_cab or "").strip().upper()
   return t != wa7["cabrillo"].upper() and t not in (a.upper() for a in wa7["aliases"])


def main():
   ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
   ap.add_argument("source", help="N1MM Logger's Source directory (not in this repo)")
   ap.add_argument("--cache", default=DEFAULT_CACHE)
   ap.add_argument("--names", help="NY4I's contest-names table")
   ap.add_argument("--names-out", help="where to write it with the N1MM columns "
                   "(may be --names itself)")
   ap.add_argument("--fetch-wa7bnm", action="store_true",
                   help="save WA7BNM's Cabrillo-name list into the cache first")
   args = ap.parse_args()
   if not os.path.isdir(args.source):
      sys.exit("not a directory: " + args.source)
   if bool(args.names) != bool(args.names_out):
      sys.exit("--names and --names-out go together")

   records, excluded = scan(args.source)
   os.makedirs(args.cache, exist_ok=True)
   write_csv(os.path.join(args.cache, "n1mm_builtin.csv"), RECORD_COLUMNS, records)
   ok = [r for r in records if r["status"] == "ok"]
   unparsed = [r for r in records if r["status"] != "ok"]
   if args.fetch_wa7bnm:
      # The contest ids come from the names table, the one place TR4W's
      # WA7BNM ids are tabulated; without it only the master list is saved.
      refs = []
      if args.names:
         with open(args.names, encoding="utf-8-sig", newline="") as f:
            refs = [r.get("WA7BNM id", "").strip() for r in csv.DictReader(f)]
         refs = [r for r in refs if r.isdigit() and r != "0"]
      fetch_wa7bnm(args.cache, refs)
   wa7bnm = load_wa7bnm(args.cache)

   # One entry per distinct (name, display, cabrillo, mode): a branch that
   # only changes the multiplier registers the same contest twice.
   entries = collections.OrderedDict()
   for r in ok:
      key = (r["name"].upper(), r["display"], r["cabrillo"], r["mode"].upper())
      e = entries.setdefault(key, dict(r, files=[]))
      e["files"].append("%s:%s" % (r["file"], r["line"]))

   contests = crosswalk.load_tr4w()
   by_id = {c["id"]: c for c in contests}
   for _u, tids, _w in N1MM_CURATED:
      for tid in tids:
         if tid not in by_id:
            sys.exit("curated id not in the matrix: " + tid)
   for _u, tid, _w in N1MM_REJECTED:
      if tid not in by_id:
         sys.exit("rejected id not in the matrix: " + tid)
   for tid in SPONSOR_VERDICTS:
      if tid not in by_id:
         sys.exit("verdict id not in the matrix: " + tid)
   curated_names = {u.upper() for u, _t, _w in N1MM_CURATED}
   for u in curated_names:
      if not any(e["name"].upper() == u for e in entries.values()):
         sys.exit("curated N1MM name not found in the source: " + u)
   idx = crosswalk.build_indexes(contests)

   hits = collections.defaultdict(list)          # tr4w id -> [(method, entry)]
   ambiguous_entries = []
   entry_outcome = collections.Counter()
   for e in entries.values():
      method, found = match_entry(e, idx, by_id)
      if len(found) > 1:
         pick = tie_break(e, found)
         if pick is not None:
            found = [pick]
            method += " (mode)"
      if len(found) == 1:
         hits[found[0]["id"]].append((method, e))
         entry_outcome["matched"] += 1
      elif found:
         ambiguous_entries.append((e, method, found))
         entry_outcome["ambiguous"] += 1
      else:
         entry_outcome["unmatched"] += 1

   rows = []
   outcome = collections.Counter()
   per_id = {}
   for c in contests:
      found = hits.get(c["id"], [])
      base = {k: "" for k in CROSSWALK_COLUMNS}
      base.update({"tr4w_id": c["id"], "tr4w_display": c["display"],
                   "tr4w_cabrillo": " / ".join(c["cabrillo"])})
      notes = []
      amb = [(e, m, f) for e, m, f in ambiguous_entries
             if any(x["id"] == c["id"] for x in f)]
      if found:
         base["outcome"], why = contest_outcome(found)
         notes.append(why)
      elif amb:
         base["outcome"] = "ambiguous"
      else:
         base["outcome"] = "unmatched"
      for e, m, f in amb:
         notes.append("%s (%s) %s ties it to %s, which its Mode %s does not "
                      "separate" % (e["name"], e["cabrillo"], m,
                                    ", ".join(x["id"] for x in f), e["mode"]))
      shown = found or [(m, e) for e, m, _f in amb]
      if shown:
         base["match_method"] = " / ".join(dict.fromkeys(m for m, _e in shown))
         base["n1mm_name"] = " / ".join(e["name"] for _m, e in shown)
         base["n1mm_display"] = " / ".join(e["display"] for _m, e in shown)
         base["n1mm_cabrillo"] = " / ".join(dict.fromkeys(e["cabrillo"] for _m, e in shown))
         base["n1mm_mode"] = " / ".join(e["mode"] for _m, e in shown)
         base["n1mm_file"] = " / ".join(", ".join(e["files"]) for _m, e in shown)
         # The curated evidence; an 'as above' line only points at its
         # sibling's, so it is left out of a joined note.
         for _m, e in shown:
            for uname, _tids, why in N1MM_CURATED:
               if (uname.upper() == e["name"].upper() and why not in notes and
                     not why.endswith("as above")):
                  notes.append(why)
      if base["outcome"] == "matched":
         cabs = [e["cabrillo"] for _m, e in found]
         agree, detail = ("N", "") if not c["cabrillo"] else ("", "")
         for tcab in c["cabrillo"]:
            agree, detail = agreement_with_any(tcab, cabs)
            if agree == "Y":
               break
         base["cabrillo_agrees"] = agree
         notes.append(detail)
         if agree == "N" and c["id"] in SPONSOR_VERDICTS:
            notes.append(SPONSOR_VERDICTS[c["id"]])
      base["note"] = "; ".join(n for n in notes if n)
      outcome[base["outcome"]] += 1
      per_id[c["id"]] = base
      rows.append(base)
   write_csv(os.path.join(args.cache, "n1mm_crosswalk.csv"), CROSSWALK_COLUMNS, rows)

   print("N1MM source (N1MM Logger source, c. 2014): %s" % args.source)
   print("excluded (mention AddChgContest, not VB source): " + (", ".join(excluded) or "none"))
   print("AddChgContest calls: %d parsed, %d unparsed" % (len(ok), len(unparsed)))
   for r in unparsed:
      print("  UNPARSED %s:%s %s -- %s" % (r["file"], r["line"], r["status"], r["raw_args"]))
   print("distinct N1MM entries: %d (matched %d, ambiguous %d, unmatched %d)" % (
      len(entries), entry_outcome["matched"], entry_outcome["ambiguous"],
      entry_outcome["unmatched"]))
   for e, m, f in ambiguous_entries:
      print("  AMBIGUOUS %s (%s, %s) by %s: %s" % (
         e["name"], e["cabrillo"], e["mode"], m, ", ".join(x["id"] for x in f)))
   print("TR4W contests: %d -- matched %d, ambiguous %d, unmatched %d" % (
      len(contests), outcome["matched"], outcome["ambiguous"], outcome["unmatched"]))
   for r in rows:
      if r["outcome"] == "ambiguous":
         print("  AMBIGUOUS TR4W %s: %s" % (r["tr4w_id"], r["note"]))
   disagree = [r for r in rows if r["cabrillo_agrees"] == "N"]
   print("Cabrillo disagreements: %d" % len(disagree))
   for r in disagree:
      print("  %s: TR4W %r, N1MM %r" % (r["tr4w_id"], r["tr4w_cabrillo"], r["n1mm_cabrillo"]))

   if args.names:
      udc = udc_cabrillo_by_id(args.cache)
      # Re-runnable: columns this step added last time are dropped and
      # rewritten, so running it after every regeneration (or twice) gives
      # the same file.  Every other column is copied through untouched.
      with open(args.names, encoding="utf-8-sig", newline="") as f:
         reader = csv.DictReader(f)
         kept = [c for c in reader.fieldnames if c not in NEW_NAME_COLUMNS]
         columns = kept + NEW_NAME_COLUMNS
         table = [{c: r[c] for c in kept} for r in reader]
      out_rows = []
      missing = []
      for t in table:
         tid = t["Registry id"]
         row = per_id.get(tid)
         if row is None:
            missing.append(tid)
            row = {k: "" for k in CROSSWALK_COLUMNS}
         t = dict(t)
         n1mm_cabs = [x for x in row["n1mm_cabrillo"].split(" / ") if x]
         t["N1MM name"] = row["n1mm_name"]
         t["N1MM display name"] = row["n1mm_display"]
         t["N1MM Cabrillo name"] = row["n1mm_cabrillo"]
         t["N1MM mode"] = row["n1mm_mode"]
         t["UDC Cabrillo name"] = " / ".join(udc.get(tid, []))
         wa7 = wa7bnm.get(t.get("WA7BNM id", "").strip())
         t["WA7BNM Cabrillo name"] = wa7["cabrillo"] if wa7 else ""
         notes = []
         if row["outcome"] == "matched":
            agree, detail = agreement_with_any(t["Cabrillo name"], n1mm_cabs)
            t["Cabrillo agrees?"] = agree
            notes.append(row["note"])
            if detail and detail not in row["note"]:
               notes.append(detail)
         else:
            t["Cabrillo agrees?"] = "no N1MM entry"
            if row["outcome"] == "ambiguous":
               notes.append("AMBIGUOUS -- " + row["note"])
         if not t["Cabrillo name"].strip():
            notes.append("TR4W HAS NO CABRILLO NAME")
         if (t["Cabrillo agrees?"] == "N" or not t["Cabrillo name"].strip() or
               wa7bnm_differs(t["Cabrillo name"], wa7)):
            notes.append(wa7bnm_note(t["Cabrillo name"],
                                     n1mm_cabs if row["outcome"] == "matched" else [],
                                     wa7))
         verdict = SPONSOR_VERDICTS.get(tid, "")
         if verdict and verdict not in "; ".join(notes):
            notes.append(verdict)
         t["Note"] = "; ".join(n for n in notes if n)
         out_rows.append(t)
      if missing:
         print("WARNING: names-table ids not in the matrix: " + ", ".join(missing),
               file=sys.stderr)
      # Written beside the target and swapped in, so a failure part-way
      # never leaves NY4I's table half-written (--names-out may be --names).
      temp = args.names_out + ".tmp"
      write_csv(temp, columns, out_rows)
      os.replace(temp, args.names_out)
      wa7_differs = [t for t in out_rows
                     if wa7bnm_differs(t["Cabrillo name"],
                                       wa7bnm.get(t.get("WA7BNM id", "").strip()))]
      print("WA7BNM: %d contests with a WA7BNM Cabrillo name; TR4W writes neither "
            "it nor an alias for %d" % (
               sum(1 for t in out_rows if t["WA7BNM Cabrillo name"]), len(wa7_differs)))
      for t in wa7_differs:
         print("  %s: TR4W %r, WA7BNM %r, N1MM %r" % (
            t["Registry id"], t["Cabrillo name"], t["WA7BNM Cabrillo name"],
            t["N1MM Cabrillo name"]))
      print("wrote " + args.names_out)


if __name__ == "__main__":
   main()
