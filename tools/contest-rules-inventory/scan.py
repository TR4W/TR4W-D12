"""scan.py -- find every place outside src/contestFactory that applies a rule
belonging to a SPECIFIC contest.

   shape 1  the global `Contest` compared, `in`-tested or cased
   shape 2  any other contest-typed operand (exch.ceContest, SelectedContest...)
   shape 3  a contest identified by a STRING (curated in judgements.SHAPE3)
   shape 4  an Active* global tested against a value only 1-3 contests reach
   shape 5  FoundContest's setup `case Contest of`, arm by arm

All structure comes from pascal.py's tokens, never from a line regex.
"""

import re
from collections import Counter

import judgements
import pascal
from model import SENTINEL

# ActiveQSOPointMethod LEFT THIS MAP AT M10 S4 (2026-10-14), deleted with
# the point method; ActivePrefixMult (Pxm) left it, and SESSION below, at M11
# S3 part 2 (2026-10-14), deleted with PrefixMultType; ActiveDXMult (XM) at
# M11 S4 part 2 (2026-10-14), deleted with DXMultType; ActiveZoneMult (ZnM)
# at M11 S5 part 2 (2026-10-14), deleted with ZoneMultType;
# ActiveDomesticMult (DM) at M11 S6 part 2 (2026-10-14), deleted with
# DomesticMultType.
ACTIVE = {
   "ACTIVEEXCHANGE": "AE",
   "ACTIVEINITIALEXCHANGE": "AIE",
}

# A KIND THAT MOVED INTO THE SESSION OBJECT (M10 S9a-f, uContestSession) is
# read as `ContestSession.<Kind>` -- the same field, so the same shape-4 site.
# Without this the bare-name match above skips it (a token after `.` is a
# record field, not the global) and the site drops out of the inventory in
# silence. Add a kind here in the commit that moves it. KEEP its ACTIVE
# entry: effective_reach reads ACTIVE.values() as the list of kind fields,
# so dropping one would empty that field's reach (M10 S9b, a correction).
SESSION_OBJECT = "CONTESTSESSION"
SESSION = {
   "INITIALEXCHANGE": "AIE",
   "EXCHANGE": "AE",
}

# A PARAMETER THAT CARRIES A SESSION KIND, keyed (file, ROUTINE, NAME).
# logdupe.SetUpExchangeInformation's parameter was named ActiveExchange and
# shadowed the global, and this scanner read its `case` AS the global -- right
# only because the one caller (uProgramMain) passes ActiveExchange. Renamed
# at M10 S9a (plan F9); listed here so the rename does not drop its arms. The
# caller passed ContestSession.Exchange from S9f. The routine is DELETED (M11
# S9a, 2026-10-14) -- each contest states TContestBase.ReceivedExchangeFields --
# so the map is empty; keep it for the next parameter that carries a kind.
KIND_PARAMETERS = {
}


def _kind_field(toks, i):
   """(field, first token of the designator) when toks[i] reads a kind --
   the old global `ActiveX`, or `ContestSession.X` -- else (None, i)."""
   u = toks[i][0].upper()
   if u in ACTIVE and not (i > 0 and toks[i - 1][0] == "."):
      return ACTIVE[u], i
   after_dot = i > 1 and toks[i - 1][0] == "."
   if u in SESSION and after_dot and toks[i - 2][0].upper() == SESSION_OBJECT:
      if not (i > 2 and toks[i - 3][0] == "."):
         return SESSION[u], i - 2
   return None, i


class FileScan:
   """Tokens and the routine map of one dumped file, made once."""

   def __init__(self, dump, rel):
      self.rel = rel
      text = dump.text(rel)
      self.toks = pascal.tokenize(text)
      self.routine = pascal.routines_by_line(text)


# ------------------------------------------------------------ shapes 1, 2, 4
def scan_sites(dump, contests):
   """Every contest-member test, and every Active* test, outside the factory.

   Returns (sites, file count). A site is a dict with file, line, routine,
   shape, kind ('case' | 'compare' | 'in' | 'index' | 'assign' | 'mention'),
   operand; contests (shapes 1-2); arms (cases); field and values (shape 4).
   Shape 0 = a mention that is not a test, kept only so nothing is silent."""
   canon = contests.canon
   sites = []
   files = dump.outside_factory()
   for rel in files:
      fs = FileScan(dump, rel)
      toks = fs.toks
      label_tokens = set()

      def at(ln):
         return fs.routine.get(ln, "?")

      # --- case statements ------------------------------------------------
      for i, (t, ln) in enumerate(toks):
         if t.upper() != "CASE":
            continue
         case = pascal.walk_case(toks, i)
         label_tokens |= case.label_tokens
         sel_u = case.selector.upper()
         contest_arms = []
         for a in case.labelled_arms():
            labs = [canon[x.upper()] for x in a["labels"] if x.upper() in canon]
            if labs:
               contest_arms.append([a["line"], labs])
         if contest_arms:
            sites.append({
               "file": rel, "line": ln, "routine": at(ln),
               "shape": 1 if sel_u == "CONTEST" else 2,
               "kind": "case", "operand": case.selector,
               "contests": sorted({x for _, labs in contest_arms for x in labs}),
               "arms": contest_arms, "arm_count": len(case.labelled_arms()),
            })
            continue
         selectors = [(key, field) for key, field in ACTIVE.items()]
         selectors += [(SESSION_OBJECT + r"\." + key, field) for key, field in SESSION.items()]
         selectors += [(name, field) for (f, routine, name), field in KIND_PARAMETERS.items()
                       if f == rel and routine == at(ln).upper()]
         for key, field in selectors:
            if re.search(r"(?<![\w.])" + key + r"$", sel_u):
               sites.append({
                  "file": rel, "line": ln, "routine": at(ln), "shape": 4,
                  "kind": "case", "operand": case.selector, "field": field,
                  "arms": [[a["line"], a["labels"]] for a in case.labelled_arms()],
                  "arm_count": len(case.labelled_arms()),
               })

      # --- comparisons, sets and mentions of a contest member -------------
      for i, (t, ln) in enumerate(toks):
         u = t.upper()
         if u not in canon or u == SENTINEL or i in label_tokens:
            continue
         # An identifier that merely SHARES the member's name -- a record
         # field `.TENTEN`, a parameter `rda: Str20`, `pCC: Pointer` -- is not
         # the enum member.
         prev = toks[i - 1][0] if i > 0 else ""
         nxt = toks[i + 1][0] if i + 1 < len(toks) else ""
         if prev == "." or nxt in (":", "[", "."):
            continue
         rec = {"file": rel, "line": ln, "routine": at(ln), "contests": [canon[u]]}
         if prev in ("=", "<>"):
            rec.update(kind="compare", operand=pascal.operand_before(toks, i - 1))
         elif nxt in ("=", "<>") and not (i + 2 < len(toks) and toks[i + 2][0] == "="):
            rec.update(kind="compare", operand=pascal.operand_after(toks, i + 1))
         else:
            lb = _enclosing_set(toks, i)
            if lb is not None and lb > 0 and toks[lb - 1][0].upper() == "IN":
               rec.update(kind="in", operand=pascal.operand_before(toks, lb - 1), set_start=lb)
            elif lb is not None and lb > 0 and pascal.is_ident(toks[lb - 1][0]) \
                  and toks[lb - 1][0].upper() not in ("IN", "OF", "THEN", "ELSE", "DO"):
               rec.update(kind="index", operand=toks[lb - 1][0])
            elif prev == ":=":
               rec.update(kind="assign", operand=pascal.operand_before(toks, i - 1))
            else:
               rec.update(kind="mention", operand="")
         if rec["kind"] in ("compare", "in"):
            rec["shape"] = 1 if rec["operand"].upper() == "CONTEST" else 2
         else:
            rec["shape"] = 0
         sites.append(rec)

      # --- Active* comparisons --------------------------------------------
      for i, (t, ln) in enumerate(toks):
         field, s = _kind_field(toks, i)
         if field is None:
            continue
         prev = toks[s - 1][0] if s > 0 else ""
         nxt = toks[i + 1][0] if i + 1 < len(toks) else ""
         if nxt in ("=", "<>"):
            vals = [pascal.operand_after(toks, i + 1)]
         elif prev in ("=", "<>") and not (s > 1 and toks[s - 2][0] == ":"):
            vals = [pascal.operand_before(toks, s - 1)]
         elif nxt.upper() == "IN" and i + 2 < len(toks) and toks[i + 2][0] == "[":
            vals = pascal.set_members(toks, i + 2)
         else:
            continue
         operand = "".join(x[0] for x in toks[s:i + 1])
         sites.append({"file": rel, "line": ln, "routine": at(ln), "shape": 4,
                       "kind": "compare", "operand": operand, "field": field, "values": vals})

   return _merge_sets(sites), len(files)


def _enclosing_set(toks, i):
   """Index of the unmatched '[' enclosing toks[i] within its statement."""
   depth = 0
   k = i - 1
   while k >= 0 and k > i - 200:
      tk = toks[k][0]
      if tk == "]":
         depth += 1
      elif tk == "[":
         if depth == 0:
            return k
         depth -= 1
      elif tk == ";":
         return None
      k -= 1
   return None


def _merge_sets(sites):
   """The members of ONE `in [...]` set are one site."""
   merged = []
   seen = {}
   for s in sites:
      if s.get("kind") == "in" and s["shape"] in (1, 2):
         key = (s["file"], s["set_start"])
         if key in seen:
            seen[key]["contests"] = sorted(set(seen[key]["contests"]) | set(s["contests"]))
            continue
         seen[key] = s
      merged.append(s)
   for s in merged:
      s.pop("set_start", None)
   return merged


# ------------------------------------------------------------------ shape 5
FOUNDCONTEST_FILE = "tr4w/src/trdos/fcontest.pas"


def found_contest_arms(dump, contests, registered):
   """FoundContest's `case Contest of`, arm by arm.

   Returns (case line, arms, overrides): each arm has start/end lines, its
   contests, the registered ones, and tags for what it assigns; overrides are
   the `Active* := value` assignments inside an arm, which is how FoundContest
   replaced a row value (FoundContest's case is gone since M7a)."""
   fs = FileScan(dump, FOUNDCONTEST_FILE)
   toks = fs.toks
   found = [i for i, (t, ln) in enumerate(toks)
            if t.upper() == "CASE" and fs.routine.get(ln, "").upper() == "FOUNDCONTEST"
            and i + 2 < len(toks) and toks[i + 1][0].upper() == "CONTEST" and toks[i + 2][0].upper() == "OF"]
   # NONE IS THE END STATE: the last arm (the UA4W Championship's) became its
   # class's DescribeSession on 2026-10-14 and the `case` was deleted. More
   # than one would mean somebody has started a second, which is an error.
   if len(found) == 0:
      return None, [], []
   if len(found) != 1:
      raise SystemExit(f"{FOUNDCONTEST_FILE}: expected at most ONE `case Contest of` in FoundContest, found {len(found)}")
   start = found[0]
   case_line = toks[start][1]
   case = pascal.walk_case(toks, start)
   lines = dump.lines(FOUNDCONTEST_FILE)

   arms = []
   overrides = []
   for a, first, last in case.line_spans(toks):
      if a["is_else"]:
         continue
      labs = [contests.canon.get(x.upper(), x) for x in a["labels"]]
      arms.append({"start": first, "end": last, "labels": labs,
                   "registered": [x for x in labs if x in registered],
                   "tags": _arm_tags("\n".join(lines[first - 1:last]))})
      for j in range(a["start_tok"], a["end_tok"]):
         u = toks[j][0].upper()
         if u in ACTIVE and j + 2 < len(toks) and toks[j + 1][0] == ":=":
            overrides.append({"line": toks[j][1], "field": ACTIVE[u], "value": toks[j + 2][0], "contests": labs})
   return case_line, arms, overrides


def _arm_tags(body):
   """What an arm does, counted by what it assigns."""
   tags = Counter()
   for m in re.finditer(r"([A-Za-z_][\w.\[\]^]*)\s*:=", body):
      tgt = m.group(1)
      if re.match(r"Active(QSOPointMethod|Exchange|InitialExchange|DomesticMult|DXMult|ZoneMult|PrefixMult)$", tgt, re.I):
         tags["Active*"] += 1
      elif re.match(r"Active(Band|Mode)$", tgt, re.I):
         tags["band"] += 1
      elif tgt.lower().startswith("settings."):
         tags["Settings"] += 1
      elif re.match(r"TempDomesticQTHDataFileName$", tgt, re.I):
         tags["domfile"] += 1
      else:
         tags["other:" + tgt.split(".")[0].split("[")[0]] += 1
   tags["CQmem"] += len(re.findall(r"\bSet(CQ|EX)MemoryString\b", body, re.I))
   tags["domfile"] += len(re.findall(r"\b(AddDomesticCountry|Add_KVE\w*|AddRussianDomesticCountrys|AddARRLSectionDomesticCountries)\b", body, re.I))
   return {k: v for k, v in tags.items() if v}


# ------------------------------------------------------------------ shape 4
# THE SESSION'S SECOND WRITER (M11 S0a, plan F1). Since M10 S2 a session kind
# has exactly two writers: the class's trait, then the class's DescribeSession
# (fcontest.ApplyContestTraits, then ApplySessionDefaults). The reach below
# read the trait and FoundContest's arms, and the arms are gone (M7a), so it
# could not see DescribeSession at all -- and called twelve live records
# UNUSED (WAEDC's CQEuropean, PACC, DOK, SAC, YBDX, JIDX's prefecture...).
DESCRIBE_SESSION = "DESCRIBESESSION"
DESCRIBE_SESSION_PARAMETER = "ASESSION"


def describe_session_statements(dump):
   """{CLASS: [(field, value)]} -- every `aSession.<Kind> := <value>` in a
   factory class's DescribeSession, under ANY condition. Counting a value
   stated on one branch as reached by the contest over-approximates, which is
   the safe direction for "only one contest uses this".

   FAILS CLOSED: a kind statement outside DescribeSession, or one whose value
   is not a single identifier, means the session has a writer this reach does
   not model; and finding none at all means the reader is blind."""
   stated = {}
   problems = []
   found = 0
   for rel in dump.factory():
      fs = FileScan(dump, rel)
      toks = fs.toks
      for i, (t, ln) in enumerate(toks):
         u = t.upper()
         if u not in SESSION or i < 2 or i + 3 >= len(toks):
            continue
         if toks[i - 1][0] != "." or toks[i - 2][0].upper() != DESCRIBE_SESSION_PARAMETER or toks[i + 1][0] != ":=":
            continue
         routine = fs.routine.get(ln, "")
         value = toks[i + 2][0]
         if not routine.upper().endswith("." + DESCRIBE_SESSION):
            problems.append(f"   {rel}:{ln} aSession.{t} is written in {routine}, not DescribeSession")
            continue
         if not pascal.is_ident(value) or toks[i + 3][0].upper() not in (";", "END", "ELSE"):
            problems.append(f"   {rel}:{ln} aSession.{t} := is not a single identifier")
            continue
         stated.setdefault(routine.split(".")[0].upper(), []).append((SESSION[u], value))
         found += 1
   if problems:
      raise SystemExit("DescribeSession kind statements this reach cannot model:\n" + "\n".join(problems))
   if found == 0:
      raise SystemExit("no `aSession.<Kind> :=` found in any DescribeSession -- the reader is blind, not the factory empty")
   return stated


def effective_reach(contests, overrides, stated=None, registry=None):
   """{field: {VALUE: {contests}}} -- each contest's class-stated value UNION
   every FoundContest override UNION (when `stated` and `registry` are given)
   every value its chain's DescribeSession states. That over-approximates who
   uses a value, which is the safe direction for "only one contest uses
   this". Values fold case, because Pascal does."""
   eff = {}
   for e in contests.enum:
      for f in ACTIVE.values():
         v = contests.field(e, f)
         if v:
            eff.setdefault(f, {}).setdefault(v.upper(), set()).add(e)
   for o in overrides:
      for c in o["contests"]:
         eff.setdefault(o["field"], {}).setdefault(o["value"].upper(), set()).add(c)
   if stated is not None:
      for c, info in registry.classes.items():
         for cls in info["chain"]:
            for f, v in stated.get(cls, ()):
               eff.setdefault(f, {}).setdefault(v.upper(), set()).add(c)
   return eff


def classify_proxies(sites, eff, registered):
   """One record per Active* comparison and per arm of a `case Active* of`:
   SHAPE (inside one of judgements.SHAPE_MACHINES, whatever its reach),
   PROXY (reach 1..FAMILY_MAX), SHARED (more), UNUSED (none)."""
   records = []
   for s in sites:
      if s["shape"] != 4:
         continue
      items = [(s["line"], s["values"])] if s["kind"] == "compare" else [(ln, labs) for ln, labs in s["arms"]]
      for ln, vals in items:
         vals = [v for v in vals if v]
         if not vals:
            continue
         cs = set()
         for v in vals:
            cs |= eff.get(s["field"], {}).get(v.upper(), set())
         if judgements.is_shape_machine(s["file"], s["routine"]):
            cls = "SHAPE"
         elif not cs:
            cls = "UNUSED"
         elif len(cs) <= judgements.FAMILY_MAX:
            cls = "PROXY"
         else:
            cls = "SHARED"
         records.append({"file": s["file"], "line": ln, "routine": s["routine"], "kind": s["kind"],
                         "case_line": s["line"], "field": s["field"], "values": vals, "class": cls,
                         "contests": sorted(cs), "registered": sorted(cs & registered)})
   return records


# ------------------------------------------------------------------ shape 3
NAME_EXPR_RX = re.compile(
   r"(Settings\.Contest\.(?:Name|Title)|\bContestTitle\b|\bContestName\b|ContestTypeSA\s*\[|\.CABName\b|\.ADIFName\b)", re.I)
NAME_TEST_RX = re.compile(r"(=|<>|\bPos\s*\(|\bAnsiContainsText|\bContainsText|\bSameText|\bStartsText)", re.I)
LITERAL_RX = re.compile(r"'((?:[^']|'')*)'")


def string_candidates(dump, contests):
   """The CANDIDATE list judgements.SHAPE3 was curated from -- reported as two
   counts so a reader can see when the candidate set moves and the curated
   list wants another look.

     literals    string literals equal to a contest identity string (the
                 ContestTypeSA spelling, or the class's DisplayName, ADIFContestId,
                 CabrilloName, DomesticFileName or FriendlyName)
     name_tests  lines testing a contest-name expression"""
   ident = set()
   for e in contests.enum:
      ident.add(contests.sa[e].strip().upper())
      for f in ("Name", "ADIFName", "CABName", "DF", "FriendlyName"):
         v = contests.field(e, f).strip().upper()
         if v:
            ident.add(v)
   literals = 0
   name_tests = 0
   for rel in dump.outside_factory():
      if rel.endswith("src/VC.pas"):
         continue
      for line in dump.lines(rel, strings=True):
         for lm in LITERAL_RX.finditer(line):
            v = lm.group(1).strip().upper()
            if len(v) >= 3 and v in ident:
               literals += 1
         m = NAME_EXPR_RX.search(line)
         if m and NAME_TEST_RX.search(line) and ":=" not in line.split(m.group(0))[0][-4:]:
            name_tests += 1
   return {"literals": literals, "name_tests": name_tests}


def resolve_shape3(dump):
   """judgements.SHAPE3 resolved to lines. Fails when a pattern's match count
   is not what was judged, because then the code has moved under a judgement."""
   rows = []
   problems = []
   for rel, rx, expected, cs, note in judgements.SHAPE3:
      routine = pascal.routines_by_line(dump.text(rel))
      hits = [ln for ln, line in enumerate(dump.lines(rel, strings=True), start=1) if re.search(rx, line, re.I)]
      if len(hits) != expected:
         problems.append(f"   {rel}: /{rx}/ matched {len(hits)} line(s), judged {expected}")
         continue
      for ln in hits:
         rows.append({"file": rel, "line": ln, "routine": routine.get(ln, "?"), "contests": sorted(cs), "note": note})
   if problems:
      raise SystemExit("judgements.SHAPE3 no longer matches the tree -- re-read these sites and update it:\n"
                       + "\n".join(problems))
   return rows
