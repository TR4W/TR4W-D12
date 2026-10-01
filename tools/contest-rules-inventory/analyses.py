"""analyses.py -- the measurements the hand-maintained findings (sections 7
and 8 of the document) rest on, recomputed every run so a reader can see
whether a finding still holds without re-deriving it.

   dead_arms             legacy arms only registered contests reach (D3, D4)
   trait_disagreements   class traits the engine contradicts (D8)
   identity_gaps         exported contest ids import cannot resolve (D9)
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
     export   uCabrilloExchange.SetHisEx / uADIFExchange.FormatADIFMyExchange
              Exit when the class's FormatsExchange is True, so an arm reached
              only by such classes is dead by default."""
   reg = registry.registered()
   formats = registry.implementers("GetFormatsExchange")
   scoring, export = [], []
   for r in sorted(proxies, key=lambda r: (r["file"], r["line"])):
      cs = set(r["contests"])
      if not cs or r["kind"] != "case":
         continue
      if r["routine"].upper() == "CALCULATEQSOPOINTS" and cs <= reg:
         scoring.append(r)
      if r["routine"].upper() in ("SETHISEX", "FORMATADIFMYEXCHANGE") and cs <= formats:
         export.append(r)
   return {"scoring": scoring, "export": export, "formats": sorted(formats)}


TRAIT_GETTERS = {"GETQSOPOINTMETHOD": "QP", "GETEXCHANGEKIND": "AE",
                 "GETDOMESTICMULTIPLIERTYPE": "DM", "GETDXMULTIPLIERTYPE": "XM"}


def trait_disagreements(registry, contests, overrides):
   """For every registered class that overrides a trait getter, the value it
   returns against what the ENGINE uses: the ContestsArray row, or the last
   FoundContest arm assignment for that contest. A getter body that is not a
   single `Result := IDENT;` is reported as complex."""
   checked = 0
   rows = []
   for member in sorted(registry.classes):
      for getter, field in TRAIT_GETTERS.items():
         found = registry.body(member, getter)
         if found is None:
            continue
         checked += 1
         rel, body = found
         row = contests.field(member, field) or "?"
         arms = [o["value"] for o in overrides if o["field"] == field and member in o["contests"]]
         values = re.findall(r"Result\s*:=\s*(\w+)\s*;", body)
         if len(values) != 1:
            rows.append({"contest": member, "getter": getter, "class": "(complex)", "engine": arms[-1] if arms else row,
                         "row": row, "arms": arms, "file": rel})
            continue
         engine = arms[-1] if arms else row
         if values[0].upper() != engine.upper():
            rows.append({"contest": member, "getter": getter, "class": values[0], "engine": engine,
                         "row": row, "arms": arms, "file": rel})
   return {"checked": checked, "rows": rows}


# Contests whose ADIF export writes no CONTEST_ID at all (uADIF.EmitADIFRecord).
NO_CONTEST_ID = {"POTA", "GENERALQSO"}


def identity_gaps(registry, contests):
   """The contest id the EXPORTERS emit (they read ContestsArray: CABName or
   ADIFName, else the ContestTypeSA spelling) against what the CLASS states,
   and how many contests export an ADIF id that import cannot resolve (import
   matches only the class's ADIFContestId, whose default is the row's ADIFName,
   and its FormerADIFContestIds)."""
   compared = 0
   rows = []
   for member in sorted(registry.classes):
      row = contests.table[member]
      cab = row.get("CABName", "").strip() or contests.sa[member].strip()
      adif = "" if member in NO_CONTEST_ID else (row.get("ADIFName", "").strip() or contests.sa[member].strip())
      for getter, exported, label in (("GetCabrilloName", cab, "Cabrillo"), ("GetADIFContestId", adif, "ADIF")):
         found = registry.body(member, getter)
         if found is None:
            continue
         lits = re.findall(r"Result\s*:=\s*'((?:[^']|'')*)'\s*;", found[1])
         if len(lits) != 1:
            continue
         compared += 1
         if lits[0].strip().upper() != exported.upper():
            rows.append({"contest": member, "format": label, "class": lits[0], "exported": exported})
   blank = [e for e in contests.real()
            if e not in NO_CONTEST_ID and not contests.field(e, "ADIFName").strip()]
   reg = registry.registered()
   return {"compared": compared, "rows": rows, "blank_adif": blank,
           "blank_adif_registered": [e for e in blank if e in reg]}


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

