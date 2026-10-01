"""render.py -- the document, as markdown (LF; generate.py writes it CRLF).

Every number here comes from the Inventory built in generate.py. The prose is
DESCRIPTIVE -- what a column means, how a value was measured -- and belongs
with the code that measures it. Prose that JUDGES lives in the document's
hand-maintained blocks, which this module only places (HAND_BLOCKS) and never
writes.
"""

import re
from collections import Counter, defaultdict

import judgements
from analyses import NO_CONTEST_ID

HAND_BLOCKS = ["headline-facts", "setup-seam", "registered-first-reads", "findings", "lint-proposal"]
HAND_BEGIN = "<!-- BEGIN HAND-MAINTAINED: {} -->"
HAND_END = "<!-- END HAND-MAINTAINED: {} -->"
HAND_RX = re.compile(r"<!-- BEGIN HAND-MAINTAINED: ([\w-]+) -->\n(.*?)\n<!-- END HAND-MAINTAINED: \1 -->", re.S)
HAND_NOTE = ("*Hand-maintained below -- judgement, not measurement. The generator preserves it verbatim "
             "and does not re-check it; its line numbers are as of when it was written.*")


def extract_hand_blocks(text):
   """{name: body} from an existing document (LF). Fails closed: a missing,
   duplicated or unknown block would be silently lost on the next write."""
   found = {}
   for m in HAND_RX.finditer(text):
      if m.group(1) in found:
         raise SystemExit(f"hand-maintained block '{m.group(1)}' appears twice in the document")
      found[m.group(1)] = m.group(2)
   unknown = set(found) - set(HAND_BLOCKS)
   missing = set(HAND_BLOCKS) - set(found)
   opened = set(re.findall(r"<!-- BEGIN HAND-MAINTAINED: ([\w-]+) -->", text))
   if unknown or missing or opened != set(found):
      raise SystemExit("hand-maintained blocks do not match render.HAND_BLOCKS -- refusing to drop hand-written text.\n"
                       f"   missing: {sorted(missing)}\n   unknown: {sorted(unknown)}\n"
                       f"   unterminated: {sorted(opened - set(found))}")
   return found


def short(rel):
   return rel.replace("tr4w/src/", "")


class Renderer:
   def __init__(self, inv, hand):
      self.inv = inv
      self.hand = hand
      self.reg = inv.registered

   # ------------------------------------------------------------ helpers
   def bold(self, cs):
      if not cs:
         return "(none by default)"
      return ", ".join(f"**{c}**" if c in self.reg else c for c in cs)

   def regcol(self, cs):
      if not cs:
         return "-"
      r = [c for c in cs if c in self.reg]
      if len(r) == len(cs):
         return "all"
      if not r:
         return "none"
      return "some: " + ", ".join(r)

   def block(self, name):
      return [HAND_NOTE, "", HAND_BEGIN.format(name), self.hand[name], HAND_END.format(name)]

   # ------------------------------------------------------------ document
   def render(self):
      out = []
      for part in (self.header, self.summary, self.method, self.how_to_read, self.sites,
                   self.setup, self.index, self.findings, self.measurements):
         out += part()
      return "\n".join(out) + "\n"

   def header(self):
      i = self.inv
      dirty = ", **plus uncommitted changes under `tr4w/`**" if i.dirty else ""
      return [
         "# Contest rules outside the contest factory -- an inventory",
         "",
         "**GENERATED. Do not edit outside the marked hand-maintained blocks.**",
         "Regenerate with `python tools/contest-rules-inventory/generate.py` (any working",
         f"directory). This copy was generated from commit `{i.commit}` ({i.commit_date}){dirty}.",
         "Owner: `contest-factory`, with `contest-scoring` (the engine side of every row",
         "below), `file-formats` (ADIF and Cabrillo rows) and `lcl-ui` (the UI rows).",
         "",
         "**What it answers (NY4I):** every place outside `tr4w/src/contestFactory/`",
         "where code applies a rule that belongs to a SPECIFIC contest -- behaviour that",
         "should live in that contest's class. The worked example is",
         "`MainUnit.ApplyContestSpecificADIFTail`, a `case exch.ceContest of` that",
         "reinterprets imported ADIF per contest.",
         "",
         "**Two kinds of text live here.** Everything outside a hand-maintained block is",
         "regenerated from the tree on every run, so its numbers and line numbers are",
         "those of the commit above. The hand-maintained blocks -- the headline",
         "judgements, the seam notes, the bug and dead-code findings (section 7) and the",
         "lint proposal (section 8) -- are judgement: the generator copies them verbatim",
         "and cannot re-check them. Section 9 recomputes the measurements those findings",
         "rest on, so a finding whose number has moved shows up there first.",
         "",
         "---",
         "",
      ]

   def summary(self):
      i = self.inv
      rows = i.rows
      by_shape = Counter(r["shape"] for r in rows)
      s1 = [s for s in i.test_sites if s["shape"] == 1]
      s2 = [s for s in i.test_sites if s["shape"] == 2]
      pc = Counter(p["class"] for p in i.proxies)
      proxy = [p for p in i.proxies if p["class"] == "PROXY" and p["contests"] != ["DUMMYCONTEST"]]
      reach1 = sum(1 for p in proxy if len(p["contests"]) == 1)
      reach23 = [p for p in proxy if len(p["contests"]) > 1]
      generic = [p for p in proxy if any(v.upper() in judgements.GENERIC for v in p["values"])]
      generic23 = sum(1 for p in generic if len(p["contests"]) > 1)
      generic1 = len(generic) - generic23
      dummy = sum(1 for p in i.proxies if p["class"] == "PROXY" and p["contests"] == ["DUMMYCONTEST"])
      s4sites = [s for s in i.sites if s["shape"] == 4]
      s4cmp = sum(1 for s in s4sites if s["kind"] == "compare")
      arms = i.fc_arms
      fc_contests = {c for a in arms for c in a["labels"]}

      out = [
         "## 1. Summary",
         "",
         "### 1.1 By shape",
         "",
         "| shape | what it is | sites | table rows | how measured |",
         "|---|---|---:|---:|---|",
         f"| 1 | the global `Contest` compared, `in`-tested or cased | **{len(s1)}** in {len({s['file'] for s in s1})} files "
         f"| {by_shape[1]} | `scan.py` (section 2.1). "
         "Rows > sites because a `case` is one site and one row per arm |",
         f"| 2 | a contest-typed FIELD or VARIABLE tested: `exch.ceContest`, `rec.ceContest`, `RXData.ceContest`, "
         f"`SelectedContest` | **{len(s2)}** in {len({s['file'] for s in s2})} files | {by_shape[2]} | `scan.py` |",
         f"| 3 | a contest identified by a STRING: contest name/title, a station state, a sponsor or bonus callsign "
         f"| **{by_shape[3]}** | {by_shape[3]} | `judgements.SHAPE3`, curated from `scan.string_candidates` (section 2.4) |",
         f"| 4 | an `Active*` proxy whose tested value reaches only 1-{judgements.FAMILY_MAX} contests by default "
         f"| **{by_shape[4]}** of {len(i.proxies)} classified | {by_shape[4]} | `scan.classify_proxies` |",
         f"| 5 | `FoundContest`'s setup `case Contest of` | 1 case, **{len(arms)} arms**, {len(fc_contests)} contests "
         f"| {len(arms)} | `scan.found_contest_arms` -- its own table, section 5 |",
         "",
         f"Shape 4 in full: the {len(s4sites)} `Active*` sites ({s4cmp} comparisons, {len(s4sites) - s4cmp} `case`s) break",
         f"into {len(i.proxies)} comparison-or-arm records --",
         "",
         "| class | records | meaning |",
         "|---|---:|---|",
         f"| PROXY, reach 1 | {reach1} | the tested value reaches exactly ONE contest by default -- a contest rule wearing a disguise |",
         f"| PROXY, reach 2-{judgements.FAMILY_MAX} | {len(reach23)} | mostly a CW/SSB pair or a family (ARRL SS, the Field Days, "
         f"UBA, SAC, REF); **{generic23}** of them test a value whose NAME is generic (`ThreePointsPerQSO`, `GridExchange`, "
         "`RSTAgeExchange`, ...) and are flagged `GENERIC-NAMED` in the tables -- judge those individually. "
         f"{generic1} reach-1 rows carry the same flag |",
         f"| PROXY for DUMMYCONTEST | {dummy} | `NoQSOPointMethod`, the sentinel; dropped |",
         f"| SHARED | {pc['SHARED']} | reaches {judgements.FAMILY_MAX + 1}+ contests -- genuinely shared behaviour, "
         "**not a finding**, counted only |",
         f"| UNUSED | {pc['UNUSED']} | reaches NO contest by default -- only an operator's `.cfg` setting can select it (section 1.4) |",
         "",
         "### 1.2 By category (table rows; section 4 has every row)",
         "",
         "| category | s1 | s2 | s3 | s4 | total |",
         "|---|---:|---:|---:|---:|---:|",
      ]
      for key, title in judgements.CATEGORIES:
         c = Counter(r["shape"] for r in rows if r["cat"] == key)
         total = sum(c.values())
         extra = f" (+ {len(arms)} FoundContest arms, section 5)" if key == "setup" else ""
         out.append(f"| {title} | {c[1]} | {c[2]} | {c[3]} | {c[4]} | {total}{extra} |")
      out.append(f"| **total** | **{by_shape[1]}** | **{by_shape[2]}** | **{by_shape[3]}** | **{by_shape[4]}** "
                 f"| **{len(rows)}** (+{len(arms)}) |")

      files = Counter(short(r["file"]) for r in rows)
      fc_rows = files["trdos/fcontest.pas"]
      files["trdos/fcontest.pas"] += len(arms)
      out += ["", "### 1.3 Top files (table rows, plus FoundContest's arms)", "",
              "| file | rows |", "|---|---:|"]
      for f, n in files.most_common(10):
         note = f" ({len(arms)} setup arms + {fc_rows})" if f == "trdos/fcontest.pas" else ""
         out.append(f"| `{f}` | {n}{note} |")

      reg_with = i.registered_with
      none = sorted(self.reg - set(reg_with))
      out += ["", "### 1.4 The headline facts", "",
              f"1. **{len(reg_with)} of the {len(self.reg)} registered contests still have rules outside the factory.**",
              f"   With none: {', '.join(f'`{c}`' for c in none) or 'none'}. The per-contest index (section 6)",
              "   lists every site, registered contests first.",
              ""]
      out += self.block("headline-facts")
      out += ["", "---", ""]
      return out

   def method(self):
      i = self.inv
      case_n, cmp_n, in_n = i.shape1_breakdown
      cand = i.candidates
      collisions = len(i.enum_collisions)
      all_score = all("CALCULATEQSOPOINTS" in v["implements"] for v in i.registry.classes.values())
      return [
         "## 2. Method",
         "",
         "**Scope.** `git ls-files 'tr4w/*.pas' 'tr4w/*.inc' 'tr4w/*.lpr'`, minus",
         "`tr4w/include/` (vendored) and `tr4w/test/`, minus `src/contestFactory/`:",
         f"**{i.file_count} files**. Using the tracked list excludes the gitignored `backup/`,",
         "`graphify-out/` and `.claude/worktrees/` copies by construction.",
         "",
         "**Parsing.** Every file is first reduced to CODE ONLY by",
         "`tr4w/build/PascalSource.psm1` (`Get-PascalCodeOnlyText`, once with",
         "`-BlankStrings` and once without), which preserves line numbers. Everything",
         "structural is then done on TOKENS, not lines (`pascal.py`): a `case` is parsed",
         "with a nesting counter (`begin`/`case`/`try`/`record`/`asm`/`repeat` open,",
         "`end`/`until` close), so a nested case's arms are not counted as the outer",
         "case's, and a label separated from its colon by a comment is still a label.",
         "The first version treated `repeat` as flat and mis-read two arms of",
         "`logddx.GetRandomDDXCallsign`; that is fixed and was checked by hand.",
         "",
         "**The tool** is `tools/contest-rules-inventory/`:",
         "",
         "| module | what it does |",
         "|---|---|",
         "| `generate.py` | the entry point: dumps, scans, renders, writes this file CRLF |",
         "| `dump-code-only.ps1` | the two code-only copies, through `PascalSource.psm1` |",
         "| `pascal.py` | tokens, the enclosing routine, operands, the ONE `case` walker |",
         "| `model.py` | `VC.pas` (`ContestType`, `ContestsArray`, `ContestTypeSA`) and the factory registry |",
         "| `scan.py` | shapes 1-5 |",
         "| `analyses.py` | the measurements behind sections 7 and 8 (section 9) |",
         "| `judgements.py` | **the only opinions**: categories, seams, thresholds, the curated shape-3 list |",
         "| `render.py` | this document, and the hand-maintained blocks it preserves |",
         "",
         "Intermediates go to `build-out/contest-rules-inventory/` (gitignored), never",
         "into the repository.",
         "",
         "### 2.1 Shapes 1 and 2",
         "",
         "A `ContestType` member used as a comparison operand, as a member of an `in`",
         "set, or as a `case` label. The other operand decides the shape: the bare",
         "global `Contest` is shape 1, anything else (a field, a parameter, a local) is",
         "shape 2.",
         "",
         f"- **{collisions} enum names collide with another enum's member** (`analyses.enum_collisions`),",
         "  so a member in code is unambiguous -- **except** where a LOCAL or FIELD",
         "  shares its spelling: `TENTEN` is a string field in `logscp.pas`, `rda` a",
         "  parameter in `tree.pas`/`logstuff.pas`, `pCC` a parameter in",
         "  `uDXLabPathfinder.pas`, `Iota` a property in `uSettingsModel.pas`. Those are",
         "  excluded (a token followed by `:`, `[` or `.`, or preceded by `.`), and so are",
         "  the `if TENTEN <> ''` tests in `logscp.pas` (a `with`-scoped field compared",
         "  with a string, not the enum).",
         f"- Shape 1 is {case_n} `case` + {cmp_n} comparisons + {in_n} `in` tests = **{case_n + cmp_n + in_n}**.",
         "  At `9acdc5bd` that was exactly the set `Lint-ContestNameTests.ps1 -List`",
         "  printed. The lint has since been widened (`c3841b55`) to count by VALUE",
         "  and one per `case` arm -- sections 9.4 and 9.5 are the comparable figures.",
         "  The lint and this scanner are separate implementations, so a",
         "  disagreement between them is worth a look.",
         "",
         "### 2.2 Which contests have a class",
         "",
         f"`RegisterContest(<enum>, <class>)` in `src/contestFactory/`: **{len(self.reg)}**",
         "(`model.Registry`, which also walks each class's ancestry). "
         + (f"All {len(self.reg)} score through their own chain -- none falls through to `TContestBase`'s zero."
            if all_score else "**Not all of them score through their own chain** -- see section 9.2."),
         "",
         "### 2.3 Shape 4 -- who reaches an `Active*` value",
         "",
         "The reach of a value is each contest's `ContestsArray` row",
         f"({len(i.contests.enum)} enum values against {len(i.contests.enum)} rows, matched by position)",
         f"UNION every `Active* :=` inside `FoundContest`'s arms ({len(i.overrides)} assignments).",
         "That over-approximates who uses a value, which is the safe direction for",
         "deciding \"only one contest uses this\". Values are compared case-insensitively,",
         "because Pascal is: `TWOPOINTSPERQSO` and `TwoPointsPerQSO` are one identifier.",
         "",
         "**The thresholds are a judgement, stated as one** (`judgements.FAMILY_MAX`):",
         f"reach 1 is unambiguous; reach 2-{judgements.FAMILY_MAX} is kept as PROXY because it is almost",
         "always a CW/SSB pair or one sponsor's family; more is SHARED. The reach-2-3",
         "rows whose value has a generic NAME (`judgements.GENERIC`) are flagged in the",
         "tables rather than silently reclassified.",
         "",
         "### 2.4 Shape 3 -- what was kept and what was not",
         "",
         "`scan.string_candidates` matches every string literal against every contest",
         "identity string (the `ContestTypeSA` spelling, and the row's Name, ADIFName,",
         f"CABName, DF and FriendlyName): **{cand['literals']}** hits today, and lists **{cand['name_tests']}** lines",
         "using a contest-name expression. Those are CANDIDATES; `judgements.SHAPE3` is",
         "what was read and kept. The translation tables (`TC_UKRAINE = 'Ukraine'`",
         "matching a DF name), `FoundContest` ASSIGNING a name, and emitting `'POTA'`",
         "inside an already-POTA branch are not tests and were dropped; the lines that",
         "TEST a name are kept. Sponsor and bonus callsigns were found with `rg` for",
         "callsign-shaped literals compared with `Callsign`/`Call`.",
         "",
         "Each kept site is located by a pattern and an expected match count, never by",
         "line number, and **the generator fails if a count is not met** -- the code",
         "has moved under a judgement and someone has to read it again. **If the two",
         "candidate counts above change, re-read the candidates**: a new string test",
         "is not added to the tables until a human adds it to `judgements.SHAPE3`.",
         "",
         "### 2.5 Categories and seams -- the one judgement step",
         "",
         "Each routine is assigned a category and a destination seam by hand, in",
         f"`judgements.ROUTINES`; {len(judgements.SITE_OVERRIDES)} sites override their routine's category",
         "(`judgements.SITE_OVERRIDES`, by pattern). Every other value in the tables is",
         "computed, and **a site in a routine with no judgement stops the generator**",
         "rather than landing in a default category. A seam that exists today is named",
         "as a `TContestBase` virtual; anything else is **\"new seam needed\"**, and where",
         "`docs/ADDING_A_CONTEST.md` section 6 already reserves a name",
         "(`parseReceivedExchange`, `getReceivedExchangeFields`, `getMultiplierValue`,",
         "`calculateTotalScore`, `getCabrilloHeaders`, `formatSentExchange`) that name",
         "is used and marked `(s6)`.",
         "",
         "---",
         "",
      ]

   def how_to_read(self):
      return [
         "## 3. How to read the tables",
         "",
         "- **bold** contest = it has a class (registered). `class?` says whether all,",
         "  none or some of the named contests have one.",
         "- A `case` appears as one row per ARM that names a contest, with the arm's",
         "  line; `@<line>` is the `case` itself.",
         "- Shape-4 rows carry `reach N` -- how many contests reach the tested value by",
         "  default -- and `GENERIC-NAMED` where the value's name is generic.",
         "",
         "## 4. The sites, by category",
      ]

   def sites(self):
      out = []
      for key, title in judgements.CATEGORIES:
         rs = sorted([r for r in self.inv.rows if r["cat"] == key], key=lambda r: (short(r["file"]), r["line"]))
         out += ["", f"### {title} ({len(rs)} rows)", ""]
         if not rs:
            out.append("None found.")
            continue
         out.append("| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |")
         out.append("|---|---|---|---|---|---|---|")
         for r in rs:
            out.append(f"| `{short(r['file'])}:{r['line']}` | {r['routine']} | {r['shape']} | {self.bold(r['contests'])} "
                       f"| {self.regcol(r['contests'])} | {r['seam']} | {r['note']} |")
      out += ["", "---", ""]
      return out

   def setup(self):
      i = self.inv
      arms = i.fc_arms
      contests = {c for a in arms for c in a["labels"]}
      outside = sorted([r for r in i.rows if r["routine"].upper() == "FOUNDCONTEST" and r["shape"] == 1
                        and not r["note"].startswith("arm of")], key=lambda r: r["line"])
      out = [
         f"## 5. Setup -- `FoundContest`'s `case Contest of` (`fcontest.pas:{i.fc_case_line}`)",
         "",
         f"**{len(arms)} arms naming {len(contests)} contests; {len(contests & self.reg)} of those contests have a class**",
         "(`scan.found_contest_arms`). The arm is where a",
         "contest's session is configured, and it is the biggest single block of",
         "contest identity outside the factory. Registered contests are listed first.",
         "",
         "What an arm does is tagged by what it assigns: `Active*` (an exchange,",
         "multiplier or point-method override of the `ContestsArray` row), `Settings`",
         "(`Settings.<group>.<name>`), `CQmem` (`SetCQMemoryString` /",
         "`SetEXMemoryString`), `domfile` (the domestic file and `AddDomesticCountry`",
         "family), `band` (`ActiveBand` / `ActiveMode`), and `other:<target>` for",
         "anything else. `calls only` = the arm assigns nothing and only calls",
         "procedures.",
         "",
      ]
      out += self.block("setup-seam")
      if outside:
         where = ", ".join(f"`fcontest.pas:{r['line']}` ({', '.join(f'`{c}`' for c in r['contests'])})" for r in outside)
         out += ["", f"{len(outside)} more shape-1 tests in `FoundContest` sit outside the case -- {where} --",
                 "and are in the Setup table in section 4."]
      out += ["", "| lines | contest(s) -- **bold = has a class** | what the arm assigns |", "|---|---|---|"]
      for a in sorted(arms, key=lambda a: (0 if a["registered"] else 1, a["start"])):
         tags = ", ".join(f"{k} {v}" for k, v in sorted(a["tags"].items())) or "calls only"
         out.append(f"| `fcontest.pas:{a['start']}-{a['end']}` | {self.bold(a['labels'])} | {tags} |")
      out += ["", "---", ""]
      return out

   def index(self):
      i = self.inv
      idx = i.index
      catorder = {k: n for n, (k, _) in enumerate(judgements.CATEGORIES)}

      def table(names):
         lines = ["| contest | sites outside the factory, by category |", "|---|---|"]
         for c in names:
            by = defaultdict(list)
            for cat, where in idx[c]:
               by[cat].append(where)
            cells = []
            for cat in sorted(by, key=lambda k: catorder[k]):
               ws = sorted(set(by[cat]), key=lambda w: (w.split(":")[0], int(w.split(":")[1])))
               cells.append(f"**{cat}** " + ", ".join(f"`{w}`" for w in ws))
            lines.append(f"| {c} | {'; '.join(cells)} |")
         return lines

      reg_with = i.registered_with
      none = sorted(self.reg - set(reg_with))
      unreg = i.unregistered_named
      no_class = len(i.contests.real()) - len(self.reg)
      out = [
         "## 6. Per-contest index",
         "",
         "Every site from sections 4 and 5, by contest. Shape-4 rows are included for",
         f"every contest the tested value reaches (reach 1-{judgements.FAMILY_MAX}).",
         "",
         "### 6.1 Registered contests -- rules that should already have moved",
         "",
         f"**{len(reg_with)} of {len(self.reg)}.** Sorted by number of sites. Registered contests with",
         f"**no** site outside the factory: {', '.join(f'`{c}`' for c in none) or 'none'}.",
         "",
      ]
      out += self.block("registered-first-reads")
      out += [""] + table(reg_with)
      out += ["", "### 6.2 Contests with no class", ""]
      if len(unreg) == no_class:
         out += [f"**{len(unreg)}** -- every contest without a class ({len(i.contests.real())} non-sentinel enum values minus",
                 f"{len(self.reg)}) appears at least once in section 4 or section 5."]
      else:
         out += [f"**{len(unreg)}** of the {no_class} contests without a class appear in section 4 or section 5;",
                 f"the other {no_class - len(unreg)} have no site."]
      named = []
      for name, needle, how in judgements.NAME_ONLY_CONTESTS:
         n = sum(1 for r in i.rows if r["shape"] == 3 and needle in r["note"])
         named.append(f"**{name}** ({how}, {n} site{'s' if n != 1 else ''})")
      out += ["Contests that exist only as an operator-configured name, with no",
              "`ContestType` at all, appear only in the shape-3 rows: " + " and ".join(named) + ".",
              ""]
      out += table(unreg)
      out += ["", "---", ""]
      return out

   def findings(self):
      out = self.block("findings")
      out += ["", "---", ""]
      out += self.block("lint-proposal")
      out += ["", "---", ""]
      return out

   def measurements(self):
      i = self.inv
      dead = i.dead_arms
      traits = i.traits
      ident = i.identity
      today, widened = i.lint_widening
      out = [
         "## 9. Measurements behind sections 7 and 8 (generated)",
         "",
         "Recomputed on every run, so a hand-maintained finding can be checked against",
         "the tree without re-deriving it. A finding whose rows have gone from here has",
         "probably been fixed; one whose rows have grown wants re-reading.",
         "",
         "### 9.1 Legacy arms dead by default (D3, D4)",
         "",
         "A `case ActiveQSOPointMethod of` arm in `CalculateQSOPoints` reached only by",
         "registered contests (the class scores and `Exit`s first), and a `case",
         "ActiveExchange of` arm in `SetHisEx` / `FormatADIFMyExchange` reached only by",
         f"classes whose `FormatsExchange` is True ({len(dead['formats'])} classes).",
         "",
         "| arm | routine | value | reached by |",
         "|---|---|---|---|",
      ]
      for r in dead["scoring"] + dead["export"]:
         out.append(f"| `{short(r['file'])}:{r['line']}` | {r['routine']} | `{', '.join(r['values'])}` "
                    f"| {', '.join(r['contests'])} |")
      out += [
         "",
         "### 9.2 Class traits the engine contradicts (D8)",
         "",
         f"**{traits['checked']}** trait overrides checked (`GetQSOPointMethod`, `GetExchangeKind`,",
         "`GetDomesticMultiplierType`, `GetDXMultiplierType`), each against the value the",
         "ENGINE uses -- the last `FoundContest` arm assignment for the contest, else its",
         f"`ContestsArray` row. **{len(traits['rows'])}** disagree or could not be read:",
         "",
         "| contest | getter | class says | engine uses | row | FoundContest arms |",
         "|---|---|---|---|---|---|",
      ]
      for r in traits["rows"]:
         out.append(f"| {r['contest']} | {r['getter']} | `{r['class']}` | `{r['engine']}` | `{r['row']}` "
                    f"| {', '.join(f'`{a}`' for a in r['arms']) or '-'} |")
      blank = ident["blank_adif"]
      out += [
         "",
         "### 9.3 Contest identity: what the class says, what the exporters emit (D9)",
         "",
         f"- **{len(blank)}** contests have a blank `ContestsArray` `ADIFName` (excluding",
         f"  {', '.join(sorted(NO_CONTEST_ID))}, which write no `CONTEST_ID`), so their exported id is the",
         f"  `ContestTypeSA` spelling and import cannot resolve it; **{len(ident['blank_adif_registered'])}** of them are",
         "  registered: " + ", ".join(ident["blank_adif_registered"]) + ".",
         f"- {ident['compared']} literal identity getters (`GetCabrilloName`, `GetADIFContestId`) were",
         f"  compared with what the exporters emit; **{len(ident['rows'])}** differ"
         + (":" if ident["rows"] else "."),
      ]
      if ident["rows"]:
         out += ["", "| contest | format | class says | exporter emits |", "|---|---|---|---|"]
         for r in ident["rows"]:
            out.append(f"| {r['contest']} | {r['format']} | `{r['class']}` | `{r['exported']}` |")
      files = sorted(set(today) | set(widened), key=lambda f: short(f))
      out += [
         "",
         "### 9.4 Shape 1 against shapes 1 + 2, per file (section 8.2)",
         "",
         f"Shape 1 (the global `Contest` only): **{sum(today.values())}** in {len(today)} files. Shapes 1 + 2 (testing",
         f"the VALUE rather than the operand): **{sum(widened.values())}** in {len(widened)} files. A `case` counts",
         "once here; `Lint-ContestNameTests` counts its contest-naming arms instead (section 9.5).",
         "",
         "| file | shape 1 | shapes 1 + 2 |",
         "|---|---:|---:|",
      ]
      for f in files:
         t = today.get(f, 0)
         w = widened.get(f, 0)
         mark = f"**{w}**" if w != t else str(w)
         out.append(f"| `{short(f)}` | {t if t else '--'} | {mark} |")
      cases = i.case_arms
      out += [
         "",
         "### 9.5 Contest-naming `case` arms (section 8.3)",
         "",
         f"**{sum(len(s['arms']) for s in cases)}** arms across {len(cases)} cases.",
         "",
         "| case | routine | shape | contest-naming arms |",
         "|---|---|---|---:|",
      ]
      for s in cases:
         out.append(f"| `{short(s['file'])}:{s['line']}` | {s['routine']} | {s['shape']} | {len(s['arms'])} |")
      return out

