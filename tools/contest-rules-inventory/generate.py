#!/usr/bin/env python3
"""Generate docs/CONTEST_RULES_OUTSIDE_FACTORY.md -- every place outside
tr4w/src/contestFactory/ that applies a rule belonging to a SPECIFIC contest.

NY4I, 2026-09-03: "A script that generates the numbers is always preferable."
The first version of this inventory was written by throwaway scripts in an
agent's scratchpad and would have gone stale the day it was committed; this is
those scripts, made one maintained tool.

   python tools/contest-rules-inventory/generate.py          # from any directory
   python tools/contest-rules-inventory/generate.py --root <a checkout>

WHAT IT PRESERVES. The document mixes measurement and judgement. Measurement
is regenerated every run. Judgement -- the bug and dead-code findings, the lint
proposal, the seam notes -- sits between

   <!-- BEGIN HAND-MAINTAINED: <name> -->  ...  <!-- END HAND-MAINTAINED: <name> -->

markers and is copied verbatim from the existing document (render.HAND_BLOCKS
lists the names). A missing or unknown block STOPS the run rather than losing
hand-written text, which is also why the document must exist: restore it from
git if it does not.

IT FAILS CLOSED, and each failure means a human has to look:
   - a contest-test site in a routine judgements.ROUTINES does not cover
   - a judgements.SHAPE3 pattern whose match count moved
   - a judgements.SITE_OVERRIDES entry that no longer matches a site
   - VC.pas whose enum, ContestsArray and ContestTypeSA disagree in length

Intermediates go to <root>/build-out/contest-rules-inventory/ (gitignored).
Needs Windows PowerShell or pwsh, for tr4w/build/PascalSource.psm1 -- the same
code-only reader the counting lints use. Standard library only otherwise.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOL_DIR)
sys.path.insert(1, os.path.dirname(TOOL_DIR))   # tools/, for srcfile

import analyses   # noqa: E402
import judgements   # noqa: E402
import render   # noqa: E402
import scan   # noqa: E402
import srcfile   # noqa: E402
from model import Contests, Dump, Registry, SENTINEL   # noqa: E402

DOC = os.path.join("docs", "CONTEST_RULES_OUTSIDE_FACTORY.md")


def git(root, *args):
   return subprocess.run(["git", "-C", root, *args], check=True, capture_output=True, text=True).stdout.strip()


def dump_code_only(root, out):
   shell = shutil.which("powershell") or shutil.which("pwsh")
   if not shell:
      raise SystemExit("needs Windows PowerShell or pwsh to run tr4w/build/PascalSource.psm1")
   subprocess.run([shell, "-NoProfile", "-ExecutionPolicy", "Bypass",
                   "-File", os.path.join(TOOL_DIR, "dump-code-only.ps1"), "-Repo", root, "-Out", out], check=True)


class Inventory:
   """Everything the document states, measured."""

   def __init__(self, root, dump_dir):
      self.commit = git(root, "rev-parse", "--short=8", "HEAD")
      self.commit_date = git(root, "log", "-1", "--format=%cs")
      self.dirty = bool(git(root, "status", "--porcelain", "--untracked-files=no", "--", "tr4w"))

      dump = Dump(dump_dir)
      self.contests = Contests(dump)
      self.registry = Registry(dump, self.contests)
      self.registered = self.registry.registered()

      self.sites, self.file_count = scan.scan_sites(dump, self.contests)
      self.fc_case_line, self.fc_arms, self.overrides = scan.found_contest_arms(dump, self.contests, self.registered)
      eff = scan.effective_reach(self.contests, self.overrides)
      self.proxies = scan.classify_proxies(self.sites, eff, self.registered)
      self.candidates = scan.string_candidates(dump, self.contests)
      self.test_sites = analyses.test_sites(self.sites)

      self.rows = self._rows(dump)
      self._index()

      self.dead_arms = analyses.dead_arms(self.proxies, self.registry)
      self.traits = analyses.trait_disagreements(self.registry, self.contests, self.overrides)
      self.identity = analyses.identity_gaps(self.registry, self.contests)
      self.enum_collisions = analyses.enum_collisions(dump, self.contests)
      self.lint_widening = analyses.lint_widening(self.sites)
      self.case_arms = analyses.contest_case_arms(self.sites)
      self.shape1_breakdown = analyses.shape1_breakdown(self.sites)

   def _rows(self, dump):
      """One table row per test site, per contest-naming case arm, per curated
      shape-3 site and per PROXY record, each with its category and seam."""
      unjudged = set()
      overrides_used = set()

      def judge(file, routine, line):
         text = dump.lines(file, strings=True)[line - 1]
         verdict, override = judgements.classify(file, routine, text)
         if override is not None:
            overrides_used.add(override)
         if verdict is None:
            unjudged.add((file, routine))
            return "?", "?"
         return verdict

      rows = []
      for s in self.test_sites:
         cat, seam = judge(s["file"], s["routine"], s["line"])
         if s["kind"] == "case":
            if s["file"] == scan.FOUNDCONTEST_FILE and s["line"] == self.fc_case_line:
               continue   # the setup case gets its own table (section 5)
            for aln, cs in s["arms"]:
               rows.append(dict(cat=cat, file=s["file"], line=aln, routine=s["routine"], shape=s["shape"],
                                contests=sorted(cs), seam=seam, note=f"arm of `case {s['operand']} of` @{s['line']}"))
         else:
            rows.append(dict(cat=cat, file=s["file"], line=s["line"], routine=s["routine"], shape=s["shape"],
                             contests=sorted(s["contests"]), seam=seam, note=f"`{s['operand']}` {s['kind']}"))

      for r in scan.resolve_shape3(dump):
         bad = [c for c in r["contests"] if c not in self.contests.table]
         if bad:
            raise SystemExit(f"judgements.SHAPE3 names {bad}, which are not ContestType members")
         cat, seam = judge(r["file"], r["routine"], r["line"])
         rows.append(dict(cat=cat, file=r["file"], line=r["line"], routine=r["routine"], shape=3,
                          contests=r["contests"], seam=seam, note=r["note"]))

      for p in self.proxies:
         if p["class"] != "PROXY" or p["contests"] == [SENTINEL]:
            continue
         cat, seam = judge(p["file"], p["routine"], p["line"])
         generic = any(v.upper() in judgements.GENERIC for v in p["values"])
         what = f"reach {len(p['contests'])}{' GENERIC-NAMED' if generic else ''}: `{p['field']}` = {', '.join(p['values'])}"
         if p["kind"] == "case":
            what += f" (arm of case @{p['case_line']})"
         rows.append(dict(cat=cat, file=p["file"], line=p["line"], routine=p["routine"], shape=4,
                          contests=p["contests"], seam=seam, note=what))

      problems = [f"   {f} : {r}  -- add it to judgements.ROUTINES" for f, r in sorted(unjudged)]
      problems += [f"   SITE_OVERRIDES[{n}] {judgements.SITE_OVERRIDES[n][:3]} matches no site -- re-read it"
                   for n in range(len(judgements.SITE_OVERRIDES)) if n not in overrides_used]
      if problems:
         raise SystemExit("contest rules with no judgement -- refusing to file them under a default:\n" + "\n".join(problems))
      return rows

   def _index(self):
      idx = {}
      for r in self.rows:
         for c in r["contests"]:
            idx.setdefault(c, []).append((r["cat"], f"{render.short(r['file'])}:{r['line']}"))
      for a in self.fc_arms:
         for c in a["labels"]:
            idx.setdefault(c, []).append(("setup", f"trdos/fcontest.pas:{a['start']}"))
      self.index = idx
      order = lambda c: (-len(idx[c]), c)   # noqa: E731
      self.registered_with = sorted([c for c in idx if c in self.registered], key=order)
      self.unregistered_named = sorted([c for c in idx if c not in self.registered and c != SENTINEL], key=order)


def main():
   ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
   ap.add_argument("--root", default=os.path.dirname(os.path.dirname(TOOL_DIR)),
                   help="the checkout to inventory (default: the one this tool lives in)")
   args = ap.parse_args()
   root = os.path.abspath(args.root)

   doc = os.path.join(root, DOC)
   if not os.path.exists(doc):
      raise SystemExit(f"{doc} does not exist. Its hand-maintained blocks are not reproducible -- restore it from git.")
   hand = render.extract_hand_blocks(srcfile.read(doc).replace("\r\n", "\n"))

   work = os.path.join(root, "build-out", "contest-rules-inventory")
   os.makedirs(work, exist_ok=True)
   dump_code_only(root, os.path.join(work, "dump"))

   inv = Inventory(root, os.path.join(work, "dump"))
   with open(os.path.join(work, "inventory.json"), "w", encoding="utf-8") as f:
      json.dump({"rows": inv.rows, "sites": inv.sites, "proxies": inv.proxies, "foundcontest_arms": inv.fc_arms},
                f, indent=1)

   srcfile.write(doc, render.Renderer(inv, hand).render(), newline="\r\n", bom=False)

   shapes = {n: sum(1 for r in inv.rows if r["shape"] == n) for n in (1, 2, 3, 4)}
   print(f"wrote {doc}")
   print(f"   commit {inv.commit}{' + uncommitted changes under tr4w/' if inv.dirty else ''}")
   print(f"   {len(inv.rows)} rows, shapes 1-4: {shapes[1]}/{shapes[2]}/{shapes[3]}/{shapes[4]}"
         f", + {len(inv.fc_arms)} FoundContest arms")
   print(f"   {len(inv.registered_with)} of {len(inv.registered)} registered contests have rules outside the factory")
   print(f"   shape-3 candidates: {inv.candidates['literals']} literals, {inv.candidates['name_tests']} name tests"
         " -- if these moved, re-read them against judgements.SHAPE3")


if __name__ == "__main__":
   main()
