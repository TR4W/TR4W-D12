"""model.py -- what the tree DECLARES about contests, read from the code dump.

   Dump      the two code-only copies dump-code-only.ps1 writes
   Contests  VC.pas: the ContestType enum, the ContestsArray rows, ContestTypeSA
   Registry  src/contestFactory: every RegisterContest, each class's ancestry,
             which ancestor implements which method, and getter bodies

Nothing here judges anything; judgements.py does that.
"""

import os
import re

SENTINEL = "DUMMYCONTEST"
FACTORY_DIR = "tr4w/src/contestFactory/"


class Dump:
   """The code-only copies. `rel` paths are repo-relative with '/'."""

   def __init__(self, root):
      self.root = root
      self._cache = {}

   def path(self, variant, rel):
      return os.path.join(self.root, variant, *rel.split("/"))

   def text(self, rel, strings=False):
      key = (rel, strings)
      if key not in self._cache:
         with open(self.path("codestr" if strings else "code", rel), encoding="utf-8", errors="replace") as f:
            self._cache[key] = f.read()
      return self._cache[key]

   def lines(self, rel, strings=False):
      return self.text(rel, strings).split("\n")

   def files(self):
      """Every dumped file, repo-relative, sorted."""
      base = os.path.join(self.root, "code")
      out = []
      for dp, _, fn in os.walk(base):
         for f in fn:
            out.append(os.path.relpath(os.path.join(dp, f), base).replace("\\", "/"))
      return sorted(out)

   def outside_factory(self):
      return [f for f in self.files() if not f.startswith(FACTORY_DIR)]

   def factory(self):
      return [f for f in self.files() if f.startswith(FACTORY_DIR)]


def _split_rows(body):
   """The top-level parenthesised rows of a typed-constant array, string-aware."""
   rows = []
   depth = 0
   cur = None
   in_str = False
   for c in body:
      if in_str:
         if c == "'":
            in_str = False
         if cur is not None:
            cur.append(c)
         continue
      if c == "'":
         in_str = True
         if cur is not None:
            cur.append(c)
      elif c == "(":
         depth += 1
         if depth == 1:
            cur = []
         else:
            cur.append(c)
      elif c == ")":
         if depth == 0:
            break
         depth -= 1
         if depth == 0:
            rows.append("".join(cur))
            cur = None
         else:
            cur.append(c)
      elif cur is not None:
         cur.append(c)
   return rows


class Contests:
   """enum: ContestType members in declaration order.
   table: {member: {field: value}} from ContestsArray, matched by position.
   sa: {member: ContestTypeSA spelling}.
   canon: {MEMBER: member} -- Pascal is case-insensitive, so lookups go here."""

   def __init__(self, dump):
      vc = dump.text("tr4w/src/VC.pas", strings=True)
      m = re.search(r"\bContestType\s*=\s*\((.*?)\)\s*;", vc, re.S | re.I)
      if not m:
         raise SystemExit("VC.pas: no ContestType declaration found")
      self.enum = [t.strip() for t in m.group(1).split(",") if t.strip()]
      self.canon = {e.upper(): e for e in self.enum}

      start = re.search(r"ContestsArray\s*:\s*array\[ContestType\]\s*of\s*TContestInfo\s*=\s*\(", vc, re.I)
      if not start:
         raise SystemExit("VC.pas: no ContestsArray declaration found")
      rows = _split_rows(vc[start.end():])
      if len(rows) != len(self.enum):
         raise SystemExit(f"VC.pas: {len(self.enum)} ContestType members but {len(rows)} ContestsArray rows")
      field_rx = re.compile(r"(\w+)\s*:\s*('(?:[^']|'')*'|[\w]+)")
      self.table = {}
      for name, row in zip(self.enum, rows):
         self.table[name] = {k: v.strip("'") for k, v in field_rx.findall(row)}

      m = re.search(r"ContestTypeSA\s*:\s*array\[ContestType\]\s*of\s*string\s*=\s*\((.*?)\)\s*;", vc, re.S | re.I)
      if not m:
         raise SystemExit("VC.pas: no ContestTypeSA declaration found")
      sa = re.findall(r"'((?:[^']|'')*)'", m.group(1))
      if len(sa) != len(self.enum):
         raise SystemExit(f"VC.pas: {len(self.enum)} ContestType members but {len(sa)} ContestTypeSA entries")
      self.sa = dict(zip(self.enum, sa))

   def field(self, contest, name):
      return self.table[contest].get(name, "")

   def real(self):
      """Every member except the sentinel."""
      return [e for e in self.enum if e != SENTINEL]


class Registry:
   """classes: {member: {'class', 'chain', 'implements': {METHOD: owning class}}}
   for every RegisterContest(<member>, <class>) in the factory.

   `implements` answers "which class in this contest's chain supplies METHOD",
   for every method any class in the chain defines; TContestBase is excluded,
   so an absent method means the base's default."""

   DECL_RX = re.compile(r"\b(T\w+)\s*=\s*class\s*\(\s*(T\w+)\s*\)", re.I)
   REG_RX = re.compile(r"RegisterContest\(\s*(\w+)\s*,\s*(T\w+)\s*\)", re.I)
   METH_RX = re.compile(r"^\s*(?:procedure|function)\s+(T\w+)\.(\w+)", re.I | re.M)
   BODY_RX = re.compile(r"^\s*function\s+(T\w+)\.(\w+)\s*:\s*\w+\s*;(.*?)^\s*end\s*;", re.I | re.M | re.S)

   def __init__(self, dump, contests):
      parent = {}
      methods = {}
      regs = []
      self.bodies = {}
      for rel in dump.factory():
         code = dump.text(rel)
         for m in self.DECL_RX.finditer(code):
            parent[m.group(1).upper()] = m.group(2).upper()
         for m in self.REG_RX.finditer(code):
            if m.group(1).lower() == "acontest":
               continue   # the declaration in uContestRegistry, not a call
            member = contests.canon.get(m.group(1).upper())
            if member is None:
               raise SystemExit(f"{rel}: RegisterContest names {m.group(1)}, which is not a ContestType member")
            regs.append((member, m.group(2).upper()))
         for m in self.METH_RX.finditer(code):
            methods.setdefault(m.group(1).upper(), set()).add(m.group(2).upper())
         for m in self.BODY_RX.finditer(dump.text(rel, strings=True)):
            self.bodies[(m.group(1).upper(), m.group(2).upper())] = (rel, m.group(3))
      if not regs:
         raise SystemExit("no RegisterContest call found in the factory -- refusing to report every contest as unregistered")

      self.classes = {}
      for member, cls in sorted(regs):
         chain = [cls]
         while chain[-1] in parent and chain[-1] != "TCONTESTBASE":
            chain.append(parent[chain[-1]])
         implements = {}
         for c in chain:
            if c == "TCONTESTBASE":
               continue
            for meth in methods.get(c, ()):
               implements.setdefault(meth, c)
         self.classes[member] = {"class": cls, "chain": chain, "implements": implements}

   def registered(self):
      return set(self.classes)

   def implementers(self, method):
      """Members whose chain (above TContestBase) implements METHOD."""
      return {e for e, v in self.classes.items() if method.upper() in v["implements"]}

   def body(self, member, method):
      """(file, body text) of the class in member's chain that implements
      METHOD, or None when the chain inherits the base's. An implementation
      whose body could not be read comes back as ('?', '') -- present, and
      unparseable -- so a caller reports it rather than skipping it."""
      owner = self.classes[member]["implements"].get(method.upper())
      if owner is None:
         return None
      return self.bodies.get((owner, method.upper()), ("?", ""))
