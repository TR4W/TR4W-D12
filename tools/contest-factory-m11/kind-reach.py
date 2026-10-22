"""kind-reach.py -- M11's measurement: where the six kind enums are read, and
which contests reach each value (trait U frozen matrix U DescribeSession).

   python tools/contest-factory-m11/kind-reach.py <dump-dir> [--inventory]

<dump-dir> holds code/ and codestr/ from
tools/contest-rules-inventory/dump-code-only.ps1. logddx.pas (compiled by
nothing, M10 F14) is skipped. --inventory also runs the inventory's own
shape-4 scan and reclassifies its records with the session reach.

SINCE M11 S0a THE INVENTORY'S OWN REACH UNIONS DescribeSession (plan F1), so
--inventory is a CROSS-CHECK: every record should reclassify to its own
class, and a pair that does not is a value the frozen matrix records that
neither the trait nor DescribeSession states. At f006acb2, before the fix,
it reported 12 UNUSED->PROXY and 3 PROXY->SHARED (plan 1.4)."""

import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "contest-rules-inventory"))
import pascal   # noqa: E402
import scan     # noqa: E402
from model import Dump, Contests, Registry   # noqa: E402

# enum -> (row field, matrix line key). PrefixMultType left at M11 S3 part 2,
# DXMultType at M11 S4 part 2, ZoneMultType at M11 S5 part 2 and
# DomesticMultType at M11 S6 part 2 (all 2026-10-14), each deleted with its
# trait and its matrix line.
ENUMS = {"ExchangeType": ("AE", "exchange"),
         "InitialExchangeType": ("AIE", "initialexchange")}


def enum_members(vc, e):
   body = re.search(r"\b" + e + r"\s*=\s*\((.*?)\)\s*;", vc, re.S | re.I).group(1)
   return re.findall(r"[A-Za-z_]\w*", body)


def record_member(path, contests):
   """The ContestType member a frozen matrix record is for. Since Q108 S3 a
   record is named by the contest's ID (blanks as '_'), so the member is read
   from the record's own identity line -- 'contest.requested = <id> (legacy
   number N)' -- never from the file name. A record with no legacy number is
   a contest registered by id, which this measurement (over the frozen kind
   enums) does not model: refused, not skipped."""
   for line in open(path, encoding="latin-1"):
      m = re.match(r"contest\.requested = .* \(legacy number (\d+)\)\s*$", line)
      if m:
         return contests.enum[int(m.group(1))]
      if line.startswith("contest.requested = "):
         raise SystemExit(f"{path}: a contest with no legacy number -- kind-reach does not model one")
   raise SystemExit(f"{path}: no contest.requested line")


def session_reach(dump, contests, reg):
   """{enum: {VALUE: {contests}}} -- trait U matrix U DescribeSession."""
   session = {e: collections.defaultdict(set) for e in ENUMS}
   for c in contests.real():
      for e, (f, _) in ENUMS.items():
         v = contests.field(c, f)
         if v:
            session[e][v.upper()].add(c)
   for path in glob.glob(os.path.join(ROOT, "tr4w", "test", "contest-matrix", "frozen", "*.matrix")):
      c = record_member(path, contests)
      for line in open(path, encoding="latin-1"):
         m = re.match(r"active\.(\w+) = (\S+)", line)
         if not m:
            continue
         for e, (_, key) in ENUMS.items():
            if m.group(1) == key:
               session[e][m.group(2).upper()].add(c)
   # The DescribeSession half is the inventory's own token-level reader
   # (scan.describe_session_statements, M11 S0a): one reader, so this script
   # and the inventory cannot disagree about what a class states. The first
   # version read it with a line regex here, and found the same 89.
   f2e = {v[0]: e for e, v in ENUMS.items()}
   stated = scan.describe_session_statements(dump)
   for c, info in reg.classes.items():
      for k in info["chain"]:
         for f, v in stated.get(k, []):
            session[f2e[f]][v.upper()].add(c)
   return session


def main():
   dump = Dump(sys.argv[1])
   contests = Contests(dump)
   reg = Registry(dump, contests)
   contests.adopt_class_facts(reg)
   vc = dump.text("tr4w/src/VC.pas")
   member_of = {}
   for e in ENUMS:
      for t in enum_members(vc, e):
         member_of[t.upper()] = e
   session = session_reach(dump, contests, reg)

   def reach(e, vals):
      out = set()
      for v in vals:
         out |= session[e].get(v.upper(), set())
      return out

   for rel in dump.files():
      if rel.endswith("logddx.pas"):
         continue
      text = dump.text(rel)
      toks = pascal.tokenize(text)
      rt = pascal.routines_by_line(text)
      labels = set()
      for i, (t, ln) in enumerate(toks):
         if t.upper() != "CASE":
            continue
         cs = pascal.walk_case(toks, i)
         arms = [(a["line"], [x for x in a["labels"] if x.upper() in member_of]) for a in cs.labelled_arms()]
         arms = [a for a in arms if a[1]]
         if arms:
            labels |= cs.label_tokens
            e = member_of[arms[0][1][0].upper()]
            print(f"CASE {rel}:{ln} {rt.get(ln)} [{cs.selector}] {len(arms)} arms")
            for aln, labs in arms:
               print(f"   :{aln} {','.join(labs)} reach={len(reach(e, labs))}")
      for i, (t, ln) in enumerate(toks):
         u = t.upper()
         # `Prefix` is also a local/field name all over the tree; its real
         # kind tests are SetPrefix's labels and MainUnit's `in` set.
         if u not in member_of or i in labels or u == "PREFIX" or i == 0 or toks[i - 1][0] == ".":
            continue
         prev = toks[i - 1][0]
         nxt = toks[i + 1][0] if i + 1 < len(toks) else ""
         lb = scan._enclosing_set(toks, i)
         in_set = lb is not None and lb > 0 and toks[lb - 1][0].upper() == "IN"
         if prev in ("=", "<>") or nxt in ("=", "<>") or in_set:
            print(f"TEST {rel}:{ln} {rt.get(ln)} {t} reach={len(reach(member_of[u], [t]))}")
   for e in ENUMS:
      for m in enum_members(vc, e):
         print(f"MEMBER {e} {m} reach={len(session[e].get(m.upper(), ()))}")

   if "--inventory" in sys.argv:
      sites, _ = scan.scan_sites(dump, contests)
      eff = scan.effective_reach(contests, [], scan.describe_session_statements(dump), reg)
      prox = scan.classify_proxies(sites, eff, reg.registered())
      f2e = {v[0]: e for e, v in ENUMS.items()}
      print("INVENTORY sites", sum(1 for s in sites if s["shape"] == 4),
            "records", collections.Counter(p["class"] for p in prox))
      moved = collections.Counter()
      for p in prox:
         n = len(reach(f2e[p["field"]], p["values"]))
         if p["class"] == "SHAPE":
            now = "SHAPE"
         else:
            now = "UNUSED" if n == 0 else ("PROXY" if n <= 3 else "SHARED")
         moved[(p["class"], now)] += 1
         if p["class"] == "UNUSED" and n:
            print(f"   LIVE-BUT-UNUSED {p['file']}:{p['line']} {p['values']}")
      print("INVENTORY reclassified", dict(moved))


if __name__ == "__main__":
   main()
