"""model.py -- what the tree DECLARES about contests, read from the code dump.

   Dump      the two code-only copies dump-code-only.ps1 writes
   Contests  VC.pas: the ContestType enum and ContestTypeSA; and, once the
             registry is read, each contest's row values AS ITS CLASS STATES
             THEM (adopt_class_facts)
   Registry  src/contestFactory: every RegisterContest, each class's ancestry,
             which ancestor implements which method, and getter bodies

THE ROW VALUES COME FROM THE CLASSES SINCE M10 S8 (2026-10-14), which deleted
VC.pas's ContestsArray. Every registered class states each value the row held
(S5), and the base answers DUMMYCONTEST's neutral row (S6), so the class's
getter IS the row: a contest's value is the single literal its chain's getter
returns, else the base's.

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


# The row fields the scans read, and the TContestBase getter that states each
# since M10 S8. The keys keep the old row's field names, so scan.ACTIVE and
# the string candidates read on unchanged.
FIELD_GETTERS = {
   "Name": "GETDISPLAYNAME",
   "ADIFName": "GETADIFCONTESTID",
   "CABName": "GETCABRILLONAME",
   "FriendlyName": "GETFRIENDLYNAME",
   "DF": "GETDOMESTICFILENAME",
   "AE": "GETEXCHANGEKIND",
   "AIE": "GETINITIALEXCHANGEKIND",
   # "Pxm" (GETPREFIXMULTIPLIERTYPE) left at M11 S3 part 2 with the getter,
   # "XM" (GETDXMULTIPLIERTYPE) at M11 S4 part 2, "ZnM"
   # (GETZONEMULTIPLIERTYPE) at M11 S5 part 2 and "DM"
   # (GETDOMESTICMULTIPLIERTYPE) at M11 S6 part 2, each with its getter.
}

_RESULT_RX = re.compile(r"\bResult\s*:=\s*('(?:[^']|'')*'|\w+)\s*;", re.I)


def _single_value(body):
   """The one value a getter body returns -- a string literal (unquoted) or an
   identifier -- or None when the body is not exactly one `Result := X;`."""
   values = _RESULT_RX.findall(body)
   if len(values) != 1:
      return None
   v = values[0]
   if v.startswith("'"):
      return v[1:-1].replace("''", "'")
   return v


class Contests:
   """enum: ContestType members in declaration order.
   table: {member: {field: value}} -- each contest's row values as its class
          states them; empty until adopt_class_facts runs.
   unreadable: [(member, field, file)] -- a getter in the chain whose body is
          not one `Result := X;`, so its value could not be read (reported,
          never guessed).
   sa: {member: ContestTypeSA spelling}.
   canon: {MEMBER: member} -- Pascal is case-insensitive, so lookups go here."""

   def __init__(self, dump):
      vc = dump.text("tr4w/src/VC.pas", strings=True)
      m = re.search(r"\bContestType\s*=\s*\((.*?)\)\s*;", vc, re.S | re.I)
      if not m:
         raise SystemExit("VC.pas: no ContestType declaration found")
      self.enum = [t.strip() for t in m.group(1).split(",") if t.strip()]
      self.canon = {e.upper(): e for e in self.enum}
      self.table = {e: {} for e in self.enum}
      self.unreadable = []

      m = re.search(r"ContestTypeSA\s*:\s*array\[ContestType\]\s*of\s*string\s*=\s*\((.*?)\)\s*;", vc, re.S | re.I)
      if not m:
         raise SystemExit("VC.pas: no ContestTypeSA declaration found")
      sa = re.findall(r"'((?:[^']|'')*)'", m.group(1))
      if len(sa) != len(self.enum):
         raise SystemExit(f"VC.pas: {len(self.enum)} ContestType members but {len(sa)} ContestTypeSA entries")
      self.sa = dict(zip(self.enum, sa))

   def adopt_class_facts(self, registry):
      """Fill `table` from the classes: for every contest and every field,
      the single value its chain's getter returns, else TContestBase's.

      FAILS CLOSED. The base must implement every getter in FIELD_GETTERS --
      a renamed getter would otherwise read as "no value" for every contest
      -- and the result must hold a value for most contests, or the bodies
      were not read at all."""
      for field, getter in FIELD_GETTERS.items():
         if ("TCONTESTBASE", getter) not in registry.bodies:
            raise SystemExit(f"TContestBase.{getter} not found -- FIELD_GETTERS no longer matches the base")
      for e in self.enum:
         row = {}
         for field, getter in FIELD_GETTERS.items():
            found = registry.body(e, getter) if e in registry.classes else None
            if found is None:
               body = registry.bodies[("TCONTESTBASE", getter)][1]
               value = _single_value(body)
            else:
               value = _single_value(found[1])
               if value is None:
                  self.unreadable.append((e, field, found[0]))
            # A base getter that computes its answer (the names answer the
            # enum's spelling) reads as no value, which is what the deleted
            # row's blank field said.
            row[field] = value or ""
         self.table[e] = row
      filled = sum(1 for e in self.real() if self.table[e].get("AE"))
      if filled < len(self.real()) // 2:
         raise SystemExit(f"only {filled} of {len(self.real())} contests have an exchange kind -- "
                          "the class getters were not read")

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
   # A CONTEST REGISTERED BY ITS STRING ID (Q108 S3) -- no ContestType member,
   # so nothing below can key it. The declaration (`const aId`) is not a call.
   BYID_RX = re.compile(r"RegisterContestById\(\s*(?!const\s)([^,()]+),\s*(T\w+)\s*\)", re.I)
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
         # FAIL CLOSED, NOT SILENT: the inventory is keyed by the frozen enum,
         # and a contest registered by id would simply vanish from it. No real
         # contest registers that way before Q108 S4; the first one to (S5)
         # extends Contests and Registry with an id-keyed entry, here.
         for m in self.BYID_RX.finditer(code):
            raise SystemExit(f"{rel}: {m.group(2)} registers by id (RegisterContestById) -- "
                             "the inventory does not model a contest with no ContestType member yet; "
                             "extend tools/contest-rules-inventory/model.py (design 8.2u, S5)")
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
