"""analyses.py -- the measurements the hand-maintained findings (sections 7
and 8 of the document) rest on, recomputed every run so a reader can see
whether a finding still holds without re-deriving it.

   dead_arms             legacy arms only registered contests reach (D3, D4)
   enum_collisions       ContestType members that are another enum's too
   lint_widening         shape 1 vs shapes 1+2, per file (section 8.2)
   contest_case_arms     contest-naming arms per case (section 8.3)
"""

import re
from collections import Counter


def dead_arms(proxies, registry):
   """Arms no contest reaches BY DEFAULT because every contest that would has
   a class that answers first.

     scoring  logstuff.CalculateQSOPoints hands the QSO to the class and Exits
              when one is registered, so a `case ActiveQSOPointMethod of` arm
              reached only by registered contests is dead by default.
     export   the shared arms in uCabrilloExchange / uADIFExchange are
              TContestBase's default (M4), so an arm reached only by classes
              that override FormatCabrilloSentExchange is dead by default."""
   reg = registry.registered()
   formats = registry.implementers("FormatCabrilloSentExchange")
   scoring, export = [], []
   for r in sorted(proxies, key=lambda r: (r["file"], r["line"])):
      cs = set(r["contests"])
      if not cs or r["kind"] != "case":
         continue
      if r["routine"].upper() == "CALCULATEQSOPOINTS" and cs <= reg:
         scoring.append(r)
      if r["routine"].upper() in ("SETHISEX", "FORMATCABRILLOEXCHANGEOFKIND",
                                  "FORMATADIFEXCHANGEOFKIND") and cs <= formats:
         export.append(r)
   return {"scoring": scoring, "export": export, "formats": sorted(formats)}


# trait_disagreements AND identity_gaps ARE GONE -- M10 S8, 2026-10-14.
# Each compared a class's getter with the ContestsArray row (the engine's
# value, the exporters' id). The row is deleted and the class's getter is
# now the only statement of either, so both would compare a value with
# itself. Sections 9.2 and 9.3 of the document say so.


ENUM_RX = re.compile(r"\b(\w+)\s*=\s*\(([^()]*?)\)\s*;", re.S)


def enum_collisions(dump, contests):
   """ContestType members that are also a member of another enumerated type
   anywhere in the dump -- a collision would make a member in code ambiguous."""
   found = {}
   for rel in dump.files():
      for m in ENUM_RX.finditer(dump.text(rel)):
         if m.group(1).lower() == "contesttype":
            continue
         for x in m.group(2).split(","):
            name = x.strip().split("=")[0].strip().upper()
            if name in contests.canon:
               found.setdefault(name, []).append(f"{rel} enum {m.group(1)}")
   return found


def test_sites(sites):
   """Shape 1 and 2 test sites -- a `case` counts once. A shape-2 comparison
   with no operand is the `with`-scoped TENTEN string field in logscp.pas,
   not the enum, and is dropped."""
   return [s for s in sites if s["shape"] in (1, 2)
           and not (s["shape"] == 2 and s["kind"] == "compare" and not s["operand"])]


def lint_widening(sites):
   """Per file: shape-1 sites (what Lint-ContestNameTests counts) and shape
   1+2 sites (what it would count if it tested the VALUE, not the operand)."""
   today = Counter()
   widened = Counter()
   for s in test_sites(sites):
      widened[s["file"]] += 1
      if s["shape"] == 1:
         today[s["file"]] += 1
   return today, widened


def contest_case_arms(sites):
   """Every `case` naming a contest in an arm, with its contest-naming arm
   count, largest first."""
   cases = [s for s in test_sites(sites) if s["kind"] == "case"]
   return sorted(cases, key=lambda s: (-len(s["arms"]), s["file"], s["line"]))


def shape1_breakdown(sites):
   c = Counter(s["kind"] for s in test_sites(sites) if s["shape"] == 1)
   return c["case"], c["compare"], c["in"]

