#!/usr/bin/env python3
"""
Offline cross-check of TR4W's per-radio capability declarations (radio factory,
Delphi source) against HamLib's rig backend caps structs (C source).

READ-ONLY AUDIT.  Parses source text on both sides -- no runtime import of
either program -- joins them via the enum -> hamlibID mapping in LOGRADIO.PAS,
and writes docs/HAMLIB_CAPS_CROSSCHECK.md.

Evidence asymmetry (project methodology): an independent implementation is
EVIDENCE when it STATES something and close to WORTHLESS when it OMITS
something.  HamLib stating a capability TR4W denies -> STRONG lead.  HamLib
merely lacking something TR4W claims -> WEAK lead.  Findings are ranked
accordingly.  This report proposes BENCH LEADS, never automatic changes.

Rerunnable, takes no args.  Python 3.12.
"""

import os
import re
import subprocess
import sys
from collections import OrderedDict

# ---------------------------------------------------------------------------
# Hard-coded repo paths (per task spec).  TR4W is the working repo; HAMLIB is
# the independent reference checkout -- rigs/ backends ONLY, never simulators/.
# ---------------------------------------------------------------------------
TR4W_ROOT = r"C:\tr4w-d12"
HAMLIB_ROOT = r"C:\Users\toms\projects\Hamlib"

FACTORY_DIR = os.path.join(TR4W_ROOT, r"tr4w\src\radioFactory")
VC_PAS = os.path.join(TR4W_ROOT, r"tr4w\src\VC.pas")
LOGRADIO_PAS = os.path.join(TR4W_ROOT, r"tr4w\src\trdos\LOGRADIO.PAS")
RIGLIST_H = os.path.join(HAMLIB_ROOT, r"include\hamlib\riglist.h")
RIGS_DIR = os.path.join(HAMLIB_ROOT, "rigs")
REPORT_PATH = os.path.join(TR4W_ROOT, r"docs\HAMLIB_CAPS_CROSSCHECK.md")

CAP_FLAGS = [
   "rcReadVFOB", "rcReadRIT", "rcReadSplit", "rcReadTXStatus", "rcDataMode",
   "rcCWByCAT", "rcPlayDVK", "rcCWFlushDisruptsTiming", "rcCWSpeedSync",
   "rcSharedRITXITOffset",
]

# Parsing problems accumulated for the appendix -- silent truncation is forbidden.
LIMITATIONS = []


def note(msg):
   if msg not in LIMITATIONS:
      LIMITATIONS.append(msg)


# ---------------------------------------------------------------------------
# Comment stripping (state machines -- regex stripping breaks on braces/quotes
# inside string literals)
# ---------------------------------------------------------------------------

def strip_pascal_comments(text):
   """Remove //, { }, (* *) comments (incl. {$...} directives), keep strings."""
   out = []
   i, n = 0, len(text)
   while i < n:
      c = text[i]
      if c == "'":                       # string literal ('' = escaped quote)
         j = i + 1
         while j < n:
            if text[j] == "'":
               if j + 1 < n and text[j + 1] == "'":
                  j += 2
                  continue
               break
            j += 1
         out.append(text[i:j + 1])
         i = j + 1
      elif c == "{":
         j = text.find("}", i + 1)
         j = n if j < 0 else j
         out.append(" " * 0)
         # keep line structure for better error messages
         out.append("\n" * text.count("\n", i, j + 1))
         i = j + 1
      elif c == "(" and i + 1 < n and text[i + 1] == "*":
         j = text.find("*)", i + 2)
         j = n if j < 0 else j + 1
         out.append("\n" * text.count("\n", i, j + 1))
         i = j + 1
      elif c == "/" and i + 1 < n and text[i + 1] == "/":
         j = text.find("\n", i)
         j = n if j < 0 else j
         i = j
      else:
         out.append(c)
         i += 1
   return "".join(out)


def strip_c_comments(text):
   out = []
   i, n = 0, len(text)
   while i < n:
      c = text[i]
      if c == '"' or c == "'":
         q = c
         j = i + 1
         while j < n:
            if text[j] == "\\":
               j += 2
               continue
            if text[j] == q:
               break
            j += 1
         out.append(text[i:j + 1])
         i = j + 1
      elif c == "/" and i + 1 < n and text[i + 1] == "*":
         j = text.find("*/", i + 2)
         j = n if j < 0 else j + 1
         out.append("\n" * text.count("\n", i, j + 1))
         i = j + 1
      elif c == "/" and i + 1 < n and text[i + 1] == "/":
         j = text.find("\n", i)
         j = n if j < 0 else j
         i = j
      else:
         out.append(c)
         i += 1
   return "".join(out)


# ---------------------------------------------------------------------------
# TR4W side
# ---------------------------------------------------------------------------

def parse_enum_names():
   """InterfacedRadioType members, in declaration order, from VC.pas."""
   with open(VC_PAS, "r", encoding="utf-8", errors="replace") as f:
      text = f.read()
   m = re.search(r"InterfacedRadioType\s*=\s*\(", text)
   if not m:
      sys.exit("FATAL: InterfacedRadioType enum not found in VC.pas")
   start = m.end()
   depth = 1
   i = start
   while i < len(text) and depth > 0:
      if text[i] == "(":
         depth += 1
      elif text[i] == ")":
         depth -= 1
      i += 1
   body = strip_pascal_comments(text[start:i - 1])
   names = [t.strip() for t in body.split(",")]
   names = [t for t in names if t]
   return names


def parse_hamlib_ids(enum_names):
   """Positional parse of RadioParametersArray in LOGRADIO.PAS -> enum -> hamlibID.

   Rows are in enum order (stated in the source: 'PLS NOTE VC INTERFACEDRADIOTYPE
   ARRAY AND THE BELOW ARRAY ARE IN THE SAME ORDER OF ENTRY').  The {Name: 'X'}
   comments are used as a cross-check only.
   """
   with open(LOGRADIO_PAS, "r", encoding="latin-1") as f:
      text = f.read()
   # Strip // line comments BEFORE the paren scan -- a trailing comment like
   # "(radio menu can raise to 115200)" would otherwise create a phantom row.
   # { } comments are KEPT (they carry the per-row {Name: 'X'} tag), and (* *)
   # must NOT be stripped: LOGRADIO brackets this very array with the {(*} /
   # {*)} brace-guard idiom, which a naive (*...*) strip would swallow whole.
   text = re.sub(r"//[^\n]*", "", text)
   m = re.search(r"RadioParametersArray\s*:\s*array\[InterfacedRadioType\]\s*of\s*"
                 r"TRadioParameters\s*=\s*\(", text)
   if not m:
      sys.exit("FATAL: RadioParametersArray not found in LOGRADIO.PAS")
   start = m.end() - 1     # at the opening '('
   depth = 0
   i = start
   rows = []
   row_start = None
   while i < len(text):
      c = text[i]
      if c == "(":
         depth += 1
         if depth == 2:
            row_start = i
      elif c == ")":
         if depth == 2 and row_start is not None:
            rows.append(text[row_start + 1:i])
            row_start = None
         depth -= 1
         if depth == 0:
            break
      elif c == "{" and depth == 1:
         # a {(*} style comment brace at row level -- skip to closing }
         j = text.find("}", i + 1)
         i = j if j > 0 else i
      i += 1
   if len(rows) != len(enum_names):
      sys.exit("FATAL: RadioParametersArray row count (%d) != enum member count (%d); "
               "positional hamlibID mapping would be wrong -- fix the parser."
               % (len(rows), len(enum_names)))
   mapping = OrderedDict()
   name_mismatches = []
   for idx, enum in enumerate(enum_names):
      if idx >= len(rows):
         mapping[enum] = None
         continue
      row = rows[idx]
      hm = re.search(r"hamlibID\s*:\s*(\d+)", row)
      mapping[enum] = int(hm.group(1)) if hm else None
      nm = re.search(r"Name\s*:\s*'([^']*)'", row)
      if nm:
         cname = nm.group(1).upper().replace("-", "").replace(" ", "")
         ename = enum.upper()
         if cname not in ename and ename not in cname and \
               not (cname == "NONE" and ename == "NOINTERFACEDRADIO"):
            name_mismatches.append("%s (enum) vs '%s' (row comment)" % (enum, nm.group(1)))
   if name_mismatches:
      sys.exit("FATAL: enum/row {Name:} cross-check mismatches -- positional mapping "
               "unsafe: " + "; ".join(name_mismatches))
   return mapping


PAS_STMT_RE = re.compile(
   r"(?P<inh>\binherited\s+Create\b)"
   r"|(?P<addsub>FCapabilities\.Flags\s*:=\s*FCapabilities\.Flags\s*(?P<op>[+-])\s*\[(?P<addlist>[^\]]*)\])"
   r"|(?P<full>FCapabilities\.Flags\s*:=\s*\[(?P<fulllist>[^\]]*)\])"
   r"|(?P<incl>\b(?P<inclop>Include|Exclude)\s*\(\s*FCapabilities\.Flags\s*,\s*(?P<inclflag>\w+)\s*\))"
   r"|(?P<capspeed>FCapabilities\.CWSpeed(?P<capwhich>Min|Max)\s*:=\s*(?P<capval>[\w.]+))"
   r"|(?P<fspeed>\bFCWSpeed(?P<fwhich>Min|Max)\s*:=\s*(?P<fval>[\w.]+))"
   r"|(?P<defcall>\bDefineCapabilities\s*;)",
   re.IGNORECASE)


def extract_method_body(text, start_idx):
   """From the index just past a method header, capture the begin..end body."""
   m = re.compile(r"\bbegin\b", re.IGNORECASE).search(text, start_idx)
   if not m:
      return None
   depth = 1
   i = m.end()
   tok = re.compile(r"\b(begin|case|try|end)\b", re.IGNORECASE)
   while depth > 0:
      t = tok.search(text, i)
      if not t:
         return None
      if t.group(1).lower() == "end":
         depth -= 1
      else:
         depth += 1
      i = t.end()
   return text[m.end():i - 3]


class PascalModel:
   def __init__(self):
      self.parent = {}          # class -> parent class
      self.ctor = {}            # class -> [stmt, ...]
      self.definecaps = {}      # class -> [stmt, ...]
      self.consts = {}          # NAME(lower) -> int
      self.registrations = []   # dicts
      self.class_unit = {}      # class -> unit file name


def parse_statements(body):
   stmts = []
   for m in PAS_STMT_RE.finditer(body):
      if m.group("inh"):
         stmts.append(("inherited",))
      elif m.group("addsub"):
         flags = [f.strip() for f in m.group("addlist").split(",") if f.strip()]
         stmts.append(("addsub", m.group("op"), flags))
      elif m.group("full"):
         flags = [f.strip() for f in m.group("fulllist").split(",") if f.strip()]
         stmts.append(("full", flags))
      elif m.group("incl"):
         stmts.append(("incl", m.group("inclop").lower(), m.group("inclflag")))
      elif m.group("capspeed"):
         stmts.append(("capspeed", m.group("capwhich").lower(), m.group("capval")))
      elif m.group("fspeed"):
         stmts.append(("fspeed", m.group("fwhich").lower(), m.group("fval")))
      elif m.group("defcall"):
         stmts.append(("definecaps",))
   return stmts


def balanced_call_args(text, open_idx):
   """text[open_idx] == '(' -> return contents up to the matching ')'."""
   depth = 0
   for i in range(open_idx, len(text)):
      if text[i] == "(":
         depth += 1
      elif text[i] == ")":
         depth -= 1
         if depth == 0:
            return text[open_idx + 1:i]
   return None


def parse_factory():
   model = PascalModel()
   for fname in sorted(os.listdir(FACTORY_DIR)):
      if not fname.lower().endswith(".pas"):
         continue
      # uRadioRegistry declares/implements RegisterRadio itself -- its parameter
      # lists and internal dispatch would parse as junk "registrations".
      scan_registrations = fname.lower() != "uradioregistry.pas"
      path = os.path.join(FACTORY_DIR, fname)
      with open(path, "r", encoding="utf-8", errors="replace") as f:
         raw = f.read()
      text = strip_pascal_comments(raw)

      for m in re.finditer(r"\b(T\w+)\s*=\s*class\s*\(\s*(T\w+)\s*\)", text, re.IGNORECASE):
         model.parent[m.group(1)] = m.group(2)
         model.class_unit[m.group(1)] = fname

      for m in re.finditer(r"^\s*(\w+)\s*=\s*(\d+)\s*;", text, re.MULTILINE):
         model.consts.setdefault(m.group(1).lower(), int(m.group(2)))

      for m in re.finditer(r"\bconstructor\s+(T\w+)\.Create\b", text, re.IGNORECASE):
         body = extract_method_body(text, m.end())
         if body is None:
            note("%s: could not capture body of %s.Create" % (fname, m.group(1)))
            continue
         model.ctor[m.group(1)] = parse_statements(body)

      for m in re.finditer(r"\bprocedure\s+(T\w+)\.DefineCapabilities\b", text, re.IGNORECASE):
         body = extract_method_body(text, m.end())
         if body is None:
            note("%s: could not capture body of %s.DefineCapabilities" % (fname, m.group(1)))
            continue
         model.definecaps[m.group(1)] = parse_statements(body)

      if not scan_registrations:
         continue

      for m in re.finditer(r"\bRegisterRadio\s*\(", text):
         args = balanced_call_args(text, m.end() - 1)
         if args is None:
            note("%s: unbalanced RegisterRadio call" % fname)
            continue
         em = re.match(r"\s*(\w+)\s*,", args)
         classes = re.findall(r"\b(T\w+)\.Create\b", args)
         disp = re.search(r"'([^']*)'", args)
         sp = re.search(r"SerialParams\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(\d+)\s*\)", args)
         links = re.search(r"\[\s*(rl[^\]]*)\]", args)
         model.registrations.append({
            "enum": em.group(1) if em else None,
            "classes": classes,
            "display": disp.group(1) if disp else None,
            "serial": (int(sp.group(1)), int(sp.group(2)), sp.group(3), int(sp.group(4))) if sp else None,
            "links": [x.strip() for x in links.group(1).split(",")] if links else [],
            "unit": fname,
         })

      for m in re.finditer(r"\bRegisterRadioById\s*\(", text):
         args = balanced_call_args(text, m.end() - 1)
         if args is None:
            continue
         disp = re.search(r"'([^']*)'", args)
         note("RegisterRadioById (string-id, no enum -> unmappable): id/display '%s' in %s"
              % (disp.group(1) if disp else "?", fname))
   return model


def resolve_speed_value(val, state, consts):
   v = val.strip()
   if re.fullmatch(r"\d+", v):
      return int(v)
   lv = v.lower()
   if lv == "fcwspeedmin":
      return state.get("fcwmin")
   if lv == "fcwspeedmax":
      return state.get("fcwmax")
   if lv == "fcapabilities.cwspeedmin":     # TIcomRadio ctor cache: FCWSpeedMin := FCapabilities.CWSpeedMin
      return state.get("cwmin")
   if lv == "fcapabilities.cwspeedmax":
      return state.get("cwmax")
   if lv in consts:
      return consts[lv]
   note("Unresolvable CW speed value '%s' -- left as None" % val)
   return None


def simulate_class(model, cls):
   """Execute the constructor chain of cls; return capability state."""
   state = {"flags": set(), "cwmin": 0, "cwmax": 0, "fcwmin": None, "fcwmax": None}
   canon = {c.lower(): c for c in set(list(model.parent.keys()) + list(model.ctor.keys())
                                      + list(model.definecaps.keys()))}

   def find_definecaps(start_cls):
      c = start_cls
      seen = set()
      while c and c.lower() not in seen:
         seen.add(c.lower())
         for k, v in model.definecaps.items():
            if k.lower() == c.lower():
               return v
         c = model.parent.get(canon.get(c.lower(), c))
      return None

   def run_ctor(c, virtual_root):
      # find nearest ancestor (incl. c) with a recorded ctor
      cur = c
      seen = set()
      while cur and cur.lower() not in seen:
         seen.add(cur.lower())
         body = None
         for k, v in model.ctor.items():
            if k.lower() == cur.lower():
               body = v
               break
         if body is not None:
            exec_body(body, cur, virtual_root)
            return
         cur = model.parent.get(canon.get(cur.lower(), cur))
      # no recorded ctor anywhere (e.g. TObject) -> no-op

   def exec_body(stmts, owner_cls, virtual_root):
      for st in stmts:
         kind = st[0]
         if kind == "inherited":
            parent = model.parent.get(canon.get(owner_cls.lower(), owner_cls))
            if parent:
               run_ctor(parent, virtual_root)
         elif kind == "full":
            state["flags"] = set(st[1])
         elif kind == "addsub":
            if st[1] == "+":
               state["flags"] |= set(st[2])
            else:
               state["flags"] -= set(st[2])
         elif kind == "incl":
            if st[1] == "include":
               state["flags"].add(st[2])
            else:
               state["flags"].discard(st[2])
         elif kind == "capspeed":
            v = resolve_speed_value(st[2], state, model.consts)
            if v is not None:
               state["cwmin" if st[1] == "min" else "cwmax"] = v
         elif kind == "fspeed":
            v = resolve_speed_value(st[2], state, model.consts)
            if v is not None:
               state["fcwmin" if st[1] == "min" else "fcwmax"] = v
         elif kind == "definecaps":
            body = find_definecaps(virtual_root)
            if body is not None:
               exec_body(body, owner_cls, virtual_root)

   run_ctor(cls, cls)
   # normalize flag spelling
   spell = {f.lower(): f for f in CAP_FLAGS}
   state["flags"] = {spell.get(f.lower(), f) for f in state["flags"]}
   return state


# ---------------------------------------------------------------------------
# HamLib side
# ---------------------------------------------------------------------------

def parse_riglist():
   with open(RIGLIST_H, "r", encoding="utf-8", errors="replace") as f:
      text = strip_c_comments(f.read())
   backends = {}
   for m in re.finditer(r"#define\s+(RIG_[A-Z0-9_]+)\s+(\d+)\s*$", text, re.MULTILINE):
      if not m.group(1).startswith("RIG_MODEL_"):
         backends[m.group(1)] = int(m.group(2))
   mmb = re.search(r"#define\s+MAX_MODELS_PER_BACKEND\s+(\d+)", text)
   mult = int(mmb.group(1)) if mmb else 1000
   models = {}
   for m in re.finditer(r"#define\s+(RIG_MODEL_\w+)\s+RIG_MAKE_MODEL\(\s*(\w+)\s*,\s*(\d+)\s*\)", text):
      be = backends.get(m.group(2))
      if be is None:
         continue
      models[m.group(1)] = mult * be + int(m.group(3))
   return models


def collect_backend_macros(dirpath):
   """Object-like #define NAME body macros from all .c/.h in a backend dir."""
   macros = {}
   for fn in os.listdir(dirpath):
      if not (fn.endswith(".c") or fn.endswith(".h")):
         continue
      try:
         with open(os.path.join(dirpath, fn), "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
      except OSError:
         continue
      raw = raw.replace("\\\n", " ")
      text = strip_c_comments(raw)
      for m in re.finditer(r"#define\s+([A-Za-z_]\w*)\s+([^\n]+)", text):
         name = m.group(1)
         if "(" in name:
            continue
         # skip function-like macros: '(' immediately after name in original
         if re.search(r"#define\s+%s\(" % re.escape(name), text):
            continue
         macros.setdefault(name, m.group(2).strip())
   return macros


def expand_tokens(expr, macros, depth=8):
   toks = set(re.findall(r"[A-Za-z_]\w*", expr))
   for _ in range(depth):
      new = expr
      for t in list(toks):
         if t in macros:
            new = re.sub(r"\b%s\b" % re.escape(t), "(" + macros[t] + ")", new)
      if new == expr:
         break
      expr = new
      toks = set(re.findall(r"[A-Za-z_]\w*", expr))
   return expr


def find_field(struct_text, field):
   m = re.search(r"\.%s\s*=\s*([A-Za-z_]\w*)" % field, struct_text)
   if not m:
      return None
   return None if m.group(1) == "NULL" else m.group(1)


def brace_block(text, start_idx):
   """text[start_idx] == '{' -> contents up to matching '}'."""
   depth = 0
   for i in range(start_idx, len(text)):
      if text[i] == "{":
         depth += 1
      elif text[i] == "}":
         depth -= 1
         if depth == 0:
            return text[start_idx + 1:i]
   return None


KEYSPD_GRAN_RE = re.compile(
   r"\[LVL_KEYSPD\]\s*=\s*\{\s*\.min\s*=\s*\{\s*\.i\s*=\s*(\d+)\s*\}\s*,"
   r"\s*\.max\s*=\s*\{\s*\.i\s*=\s*(\d+)", re.DOTALL)

_gran_file_cache = {}


def keyspd_from_gran_file(dirpath, incname):
   key = (dirpath, incname)
   if key in _gran_file_cache:
      return _gran_file_cache[key]
   path = os.path.join(dirpath, incname)
   rng = None
   if os.path.isfile(path):
      with open(path, "r", encoding="utf-8", errors="replace") as f:
         t = strip_c_comments(f.read())
      m = KEYSPD_GRAN_RE.search(t)
      if m:
         rng = (int(m.group(1)), int(m.group(2)))
   _gran_file_cache[key] = rng
   return rng


def parse_hamlib_caps():
   """Scan rigs/**/*.c for struct rig_caps; return model_id -> caps dict."""
   caps_by_id = {}
   for sub in sorted(os.listdir(RIGS_DIR)):
      dirpath = os.path.join(RIGS_DIR, sub)
      if not os.path.isdir(dirpath):
         continue
      macros = collect_backend_macros(dirpath)
      for fn in sorted(os.listdir(dirpath)):
         if not fn.endswith(".c"):
            continue
         path = os.path.join(dirpath, fn)
         with open(path, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
         text = strip_c_comments(raw)
         file_defines_nokeyspd = "#define NO_LVL_KEYSPD" in text
         for m in re.finditer(r"struct\s+rig_caps\s+(\w+)\s*=\s*", text):
            ob = text.find("{", m.end())
            if ob < 0:
               continue
            body = brace_block(text, ob)
            if body is None:
               note("hamlib %s/%s: unbalanced braces in caps struct %s" % (sub, fn, m.group(1)))
               continue
            mm = re.search(r"RIG_MODEL\s*\(\s*(RIG_MODEL_\w+)\s*\)", body) or \
                 re.search(r"\.rig_model\s*=\s*(RIG_MODEL_\w+)", body)
            if not mm:
               continue
            model_macro = mm.group(1)
            line_no = text.count("\n", 0, m.start()) + 1
            cap = {
               "file": "rigs/%s/%s" % (sub, fn),
               "line": line_no,
               "struct": m.group(1),
               "model_macro": model_macro,
            }
            tv = re.search(r"\.targetable_vfo\s*=\s*([^,\n]+)", body)
            targetable = False
            if tv:
               ex = expand_tokens(tv.group(1), macros)
               targetable = ("RIG_TARGETABLE_FREQ" in ex) or ("RIG_TARGETABLE_ALL" in ex) \
                            or ("0x7fffffff" in ex.lower())
            cap["targetable_freq"] = targetable
            cap["targetable_raw"] = tv.group(1).strip() if tv else None
            for fld in ("get_rit", "set_rit", "get_xit", "set_xit", "get_split_vfo",
                        "get_ptt", "send_morse", "send_voice_mem"):
               cap[fld] = find_field(body, fld)
            pt = re.search(r"\.ptt_type\s*=\s*(\w+)", body)
            cap["ptt_type"] = pt.group(1) if pt else None
            lvl_keyspd = False
            for which in ("has_get_level", "has_set_level"):
               lm = re.search(r"\.%s\s*=\s*([^,\n]+(?:\([^)]*\))?)" % which, body)
               if lm:
                  ex = expand_tokens(lm.group(1), macros)
                  if "RIG_LEVEL_KEYSPD" in ex:
                     lvl_keyspd = True
            cap["level_keyspd"] = lvl_keyspd
            for fld in ("serial_rate_min", "serial_rate_max", "serial_data_bits",
                        "serial_stop_bits"):
               sm = re.search(r"\.%s\s*=\s*(\d+)" % fld, body)
               cap[fld] = int(sm.group(1)) if sm else None
            pm = re.search(r"\.serial_parity\s*=\s*RIG_PARITY_(\w+)", body)
            cap["serial_parity"] = pm.group(1) if pm else None
            # KEYSPD range: explicit [LVL_KEYSPD] override in the struct wins
            # (last one), else the backend's level_gran include default.
            rng = None
            gm = re.search(r"\.level_gran\s*=\s*", body)
            if gm:
               gb = body.find("{", gm.end())
               gblock = brace_block(body, gb) if gb >= 0 else None
               if gblock is not None:
                  hits = KEYSPD_GRAN_RE.findall(gblock)
                  if hits:
                     rng = (int(hits[-1][0]), int(hits[-1][1]))
                  else:
                     inc = re.search(r"#include\s+\"([^\"]+)\"", gblock)
                     if inc and not file_defines_nokeyspd:
                        rng = keyspd_from_gran_file(dirpath, inc.group(1))
            cap["keyspd_range"] = rng
            caps_by_id.setdefault(model_macro, cap)
   return caps_by_id


# ---------------------------------------------------------------------------
# Comparison + report
# ---------------------------------------------------------------------------

# TR4W flag -> (hamlib evidence key, human description of the hamlib signal)
FLAG_MAP = [
   ("rcReadVFOB", "targetable_freq", ".targetable_vfo includes RIG_TARGETABLE_FREQ"),
   ("rcReadRIT", "get_rit", ".get_rit implemented"),
   ("rcReadSplit", "get_split_vfo", ".get_split_vfo implemented"),
   ("rcReadTXStatus", "get_ptt", ".get_ptt implemented"),
   ("rcCWByCAT", "send_morse", ".send_morse implemented"),
   ("rcCWSpeedSync", "level_keyspd", "RIG_LEVEL_KEYSPD in has_get/set_level"),
   ("rcPlayDVK", "send_voice_mem", ".send_voice_mem implemented"),
]

# TR4W parity constants (uRadioRegistry.pas) -> hamlib RIG_PARITY_* names
PARITY_NAME = {"PARITY_NONE": "NONE", "PARITY_ODD": "ODD", "PARITY_EVEN": "EVEN"}

# Known-good joins whose names do not match textually (model naming quirks).
JOIN_ALLOWLIST = {
   ("FTDX9000", "FT9000"),        # hamlib names the FTDX-9000 FT9000
   ("FT1200", "FTDX1200"),        # hamlib names the FT-1200 FTDX1200 (same radio)
   ("OMNI6", "OMNIVIP"),          # Omni VI Plus; TR4W drives the Omni VI via CI-V
   ("IC7850", "IC785X"),          # hamlib merges 7850/7851 as IC785x
   ("IC7851", "IC785X"),
   ("IC706II", "IC706MKII"),
   ("IC706IIG", "IC706MKIIG"),
}


def norm_model(s):
   return re.sub(r"[^A-Z0-9]", "", s.upper().replace("RIG_MODEL_", ""))


def join_is_plausible(enum, macro):
   a, b = norm_model(enum), norm_model(macro)
   if a in b or b in a:
      return True
   return (a, b) in JOIN_ALLOWLIST

# Families whose factory driver demonstrably READS state it does not declare as a
# capability flag (flags are consumed by callers only where needed; the project's
# own comment in uRadioYaesuASCIILegacy.pas:148-158 states absence can mean "TR4W
# does not poll it", not "the radio cannot").  Used to annotate Section A rows.
UNDERDECLARED_NOTE = {
   "uRadioKenwoodTS": "TKenwoodSerial/TKenwoodLAN parse RIT/XIT state+offset, TX, split and "
                      "the unselected VFO from IF;/FA;/FB; (uRadioKenwoodSerial.pas) -- the "
                      "flags are simply not declared for this family.",
   "uRadioKenwoodLAN": "TKenwoodLAN speaks the same Kenwood IF; dialect over TCP.",
   "uRadioElecraftK4": "TK4Radio parses the K4's IF;/auto-info stream; flags not declared.",
   "uRadioElecraft": "TElecraftSerial parses the K2/K3 IF; response (RIT/XIT, TX, split); "
                     "flags not declared for this family.",
}


def underdeclared_note_for(unit):
   for prefix, txt in UNDERDECLARED_NOTE.items():
      if unit.startswith(prefix):
         return txt
   return None


def hamlib_commit():
   try:
      out = subprocess.run(["git", "-C", HAMLIB_ROOT, "rev-parse", "--short", "HEAD"],
                           capture_output=True, text=True, check=True)
      commit = out.stdout.strip()
      out2 = subprocess.run(["git", "-C", HAMLIB_ROOT, "log", "-1", "--format=%ci"],
                            capture_output=True, text=True, check=True)
      return commit, out2.stdout.strip()
   except Exception as e:                                    # noqa: BLE001
      note("Could not read HamLib git commit: %s" % e)
      return "unknown", "unknown"


def main():
   enum_names = parse_enum_names()
   hamlib_ids = parse_hamlib_ids(enum_names)
   model = parse_factory()
   riglist = parse_riglist()           # RIG_MODEL_X -> numeric id
   id_to_macro = {}
   for k, v in riglist.items():
      id_to_macro.setdefault(v, k)
   caps_by_macro = parse_hamlib_caps()
   caps_by_id = {}
   for macro, cap in caps_by_macro.items():
      num = riglist.get(macro)
      if num is not None:
         caps_by_id.setdefault(num, cap)

   # ---- Build the TR4W per-registration capability table --------------------
   registered = OrderedDict()
   for reg in model.registrations:
      enum = reg["enum"]
      if enum is None or not reg["classes"]:
         note("Registration in %s with unparsable enum/class skipped: %r" % (reg["unit"], reg))
         continue
      states = [simulate_class(model, c) for c in reg["classes"]]
      flags = set()
      for s in states:
         flags |= s["flags"]
      cwmin = max((s["cwmin"] for s in states), default=0)
      cwmax = max((s["cwmax"] for s in states), default=0)
      # for single-class radios (the norm) use that class's range verbatim
      if len(states) == 1:
         cwmin, cwmax = states[0]["cwmin"], states[0]["cwmax"]
      if enum in registered:
         note("Enum %s registered more than once (%s and %s)"
              % (enum, registered[enum]["unit"], reg["unit"]))
      registered[enum] = {
         "classes": reg["classes"], "display": reg["display"], "unit": reg["unit"],
         "flags": flags, "cwmin": cwmin, "cwmax": cwmax,
         "serial": reg["serial"], "links": reg["links"],
         "multiclass": len(reg["classes"]) > 1,
      }

   # ---- Sanity anchors (fail loudly if the parser is wrong) -----------------
   errors = []
   ic718 = registered.get("IC718")
   if not ic718:
      errors.append("anchor: IC718 not found among registrations")
   else:
      if "rcReadVFOB" in ic718["flags"]:
         errors.append("anchor: IC718 must NOT claim rcReadVFOB")
      if ic718["cwmin"] != 6 or ic718["cwmax"] != 60:
         errors.append("anchor: IC718 CW range parsed as %d..%d, expected 6..60"
                       % (ic718["cwmin"], ic718["cwmax"]))
      if "rcCWFlushDisruptsTiming" not in ic718["flags"]:
         errors.append("anchor: IC718 must inherit rcCWFlushDisruptsTiming from TIcomRadio ctor")
   ic7300 = registered.get("IC7300")
   if ic7300:
      need = {"rcReadVFOB", "rcReadRIT", "rcReadSplit", "rcReadTXStatus", "rcDataMode",
              "rcCWByCAT", "rcCWSpeedSync", "rcPlayDVK"}
      if not need <= ic7300["flags"]:
         errors.append("anchor: IC7300 missing expected flags: %s" % (need - ic7300["flags"]))
   else:
      errors.append("anchor: IC7300 not registered?")
   if "FT736R" in registered:
      errors.append("anchor: FT736R must NOT be a factory-registered radio")
   mp = registered.get("FT1000MP")
   if mp and "rcSharedRITXITOffset" not in mp["flags"]:
      errors.append("anchor: FT1000MP must declare rcSharedRITXITOffset")
   c718 = caps_by_id.get(3013)
   if not c718:
      errors.append("anchor: hamlib model 3013 (IC-718) not found")
   elif c718["targetable_freq"]:
      errors.append("anchor: hamlib IC-718 targetable_vfo parsed as FREQ-capable; source says 0")
   if errors:
      for e in errors:
         print("ANCHOR FAILURE:", e)
      sys.exit(1)

   # ---- Compare -------------------------------------------------------------
   strong, weak, serial_findings, cw_findings, agreements = [], [], [], [], 0
   unmapped, no_caps, suspect_joins = [], [], []
   for enum, info in registered.items():
      hid = hamlib_ids.get(enum)
      if not hid:
         unmapped.append((enum, info["display"], "no hamlibID in RadioParametersArray row"))
         continue
      cap = caps_by_id.get(hid)
      if not cap:
         no_caps.append((enum, info["display"], hid, id_to_macro.get(hid, "id not in riglist.h")))
         continue
      if not join_is_plausible(enum, cap["model_macro"]):
         # The hamlibID row points at a DIFFERENT radio -- comparing caps would
         # contaminate every section.  Reported separately as a finding about
         # LOGRADIO's hamlibID column itself.
         candidates = sorted(m for m in riglist
                             if norm_model(enum) in norm_model(m) and riglist[m] in caps_by_id)
         suspect_joins.append({
            "enum": enum, "display": info["display"], "hid": hid,
            "macro": cap["model_macro"], "cite": "%s:%d" % (cap["file"], cap["line"]),
            "candidates": [(m, riglist[m]) for m in candidates],
         })
         continue
      cite = "%s:%d (%s)" % (cap["file"], cap["line"], cap["model_macro"])
      for flag, key, desc in FLAG_MAP:
         hl = bool(cap.get(key))
         tr = flag in info["flags"]
         if hl and not tr:
            strong.append({
               "enum": enum, "display": info["display"], "flag": flag, "desc": desc,
               "cite": cite, "value": cap.get(key) if key != "targetable_freq" else cap.get("targetable_raw"),
               "unit": info["unit"], "note": underdeclared_note_for(info["unit"]),
               "ptt_type": cap.get("ptt_type") if flag == "rcReadTXStatus" else None,
            })
         elif tr and not hl:
            weak.append({
               "enum": enum, "display": info["display"], "flag": flag, "desc": desc,
               "cite": cite, "unit": info["unit"],
            })
         else:
            agreements += 1
      # serial params
      sp = info["serial"]
      if sp and "rlSerial" in info["links"]:
         baud, databits, parity, stopbits = sp
         issues = []
         if cap["serial_rate_min"] is not None and cap["serial_rate_max"] is not None:
            if not (cap["serial_rate_min"] <= baud <= cap["serial_rate_max"]):
               issues.append("baud %d outside hamlib %d..%d"
                             % (baud, cap["serial_rate_min"], cap["serial_rate_max"]))
         if cap["serial_data_bits"] is not None and cap["serial_data_bits"] != databits:
            issues.append("data bits %d vs hamlib %d" % (databits, cap["serial_data_bits"]))
         if cap["serial_stop_bits"] is not None and cap["serial_stop_bits"] != stopbits:
            issues.append("stop bits %d vs hamlib %d" % (stopbits, cap["serial_stop_bits"]))
         hp = cap["serial_parity"]
         tp = PARITY_NAME.get(parity, parity)
         if hp is not None and hp != tp:
            issues.append("parity %s vs hamlib %s" % (tp, hp))
         if issues:
            serial_findings.append({"enum": enum, "display": info["display"],
                                    "issues": issues, "cite": cite,
                                    "tr4w": "%d,%d,%s,%d stop" % (baud, databits, tp, stopbits)})
      # CW speed range
      if info["cwmin"] or info["cwmax"]:
         rng = cap.get("keyspd_range")
         if rng and (rng[0] != info["cwmin"] or rng[1] != info["cwmax"]):
            cw_findings.append({"enum": enum, "display": info["display"],
                                "tr4w": (info["cwmin"], info["cwmax"]), "hamlib": rng,
                                "cite": cite})

   enums_not_registered = [e for e in enum_names
                           if e not in registered and e != "NoInterfacedRadio"]

   write_report(registered, strong, weak, serial_findings, cw_findings, agreements,
                unmapped, no_caps, suspect_joins, enums_not_registered, hamlib_ids,
                caps_by_id)

   print("TR4W factory registrations parsed : %d" % len(registered))
   print("  ... with a hamlibID mapping      : %d"
         % sum(1 for e in registered if hamlib_ids.get(e)))
   print("  ... matched to a hamlib caps     : %d"
         % sum(1 for e in registered if hamlib_ids.get(e) in caps_by_id))
   print("HamLib caps structs parsed        : %d" % len(caps_by_id))
   print("Section A strong leads            : %d" % len(strong))
   print("Section B weak leads              : %d" % len(weak))
   print("Section C serial disagreements    : %d" % len(serial_findings))
   print("Section D CW-speed disagreements  : %d" % len(cw_findings))
   print("Suspect hamlibID joins (excluded) : %d  %s"
         % (len(suspect_joins), [s["enum"] for s in suspect_joins]))
   print("Flag agreements                   : %d" % agreements)
   print("Report written to %s" % REPORT_PATH)
   if LIMITATIONS:
      print("Limitations noted: %d (see appendix)" % len(LIMITATIONS))


def write_report(registered, strong, weak, serial_findings, cw_findings, agreements,
                 unmapped, no_caps, suspect_joins, enums_not_registered, hamlib_ids,
                 caps_by_id):
   commit, cdate = hamlib_commit()
   L = []
   L.append("# TR4W radio-factory capabilities vs HamLib rig backends -- offline cross-check")
   L.append("")
   L.append("**Generated by** `tools/hamlib-crosscheck/crosscheck.py` (rerunnable, no args).")
   L.append("**HamLib reference:** `%s`, commit `%s` (%s) -- `rigs/` backend sources ONLY;"
            % (HAMLIB_ROOT, commit, cdate))
   L.append("the `simulators/` directory is deliberately ignored (the project has established")
   L.append("that the sims contradict the library).")
   L.append("")
   L.append("## Purpose and methodology")
   L.append("")
   L.append("This is a build-time text-parse comparison of what each TR4W factory radio")
   L.append("declares in `FCapabilities.Flags` / `CWSpeedMin..Max` / `SerialParams(...)`")
   L.append("against what the corresponding HamLib `struct rig_caps` states. The join key is")
   L.append("the `hamlibID` column of `RadioParametersArray` in `tr4w/src/trdos/LOGRADIO.PAS`.")
   L.append("")
   L.append("**Evidence asymmetry (core rule):** an independent implementation is EVIDENCE")
   L.append("when it STATES something and close to WORTHLESS when it OMITS something.")
   L.append("A disagreement where HamLib states a capability that TR4W denies is a STRONG")
   L.append("lead; where HamLib merely lacks something TR4W claims, it is a WEAK lead.")
   L.append("")
   L.append("**This report proposes BENCH LEADS, never automatic changes.** Nothing here is")
   L.append("evidence enough on its own to flip a capability flag; each lead needs a bench")
   L.append("check on the real rig (or a manual citation) first.")
   L.append("")
   L.append("**Known caveat for Section A (stated up front):** for several non-Icom families")
   L.append("the factory declares only the flags something currently consumes. The project's")
   L.append("own comment (uRadioYaesuASCIILegacy.pas:148-158) says absence can mean \"TR4W")
   L.append("does not poll it\", not \"the radio cannot\". Rows below carry a note when the")
   L.append("TR4W driver visibly reads the state anyway; those are documentation gaps rather")
   L.append("than functional leads.")
   L.append("")
   L.append("Flag-to-caps mapping used: rcReadVFOB <- `.targetable_vfo` has RIG_TARGETABLE_FREQ;")
   L.append("rcReadRIT <- `.get_rit`; rcReadSplit <- `.get_split_vfo`; rcReadTXStatus <- `.get_ptt`;")
   L.append("rcCWByCAT <- `.send_morse`; rcCWSpeedSync <- RIG_LEVEL_KEYSPD in `.has_get/set_level`;")
   L.append("rcPlayDVK <- `.send_voice_mem` (approximate -- HamLib's voice-memory API is newer and")
   L.append("thinly implemented, so its absence is especially weak evidence). rcDataMode,")
   L.append("rcSharedRITXITOffset and rcCWFlushDisruptsTiming have no per-model HamLib analogue")
   L.append("and are not cross-checked (rcCWFlushDisruptsTiming is a TR4W send-queue mechanism;")
   L.append("every CI-V radio carries it by design).")
   L.append("")

   n_mapped = sum(1 for e in registered if hamlib_ids.get(e) in caps_by_id)
   L.append("## Coverage")
   L.append("")
   L.append("| | count |")
   L.append("|---|---|")
   L.append("| TR4W factory registrations (enum-keyed) | %d |" % len(registered))
   L.append("| ... with a hamlibID in RadioParametersArray | %d |"
            % sum(1 for e in registered if hamlib_ids.get(e)))
   L.append("| ... joined to a parsed HamLib caps struct | %d |" % n_mapped)
   L.append("| HamLib caps structs parsed (all rigs/) | %d |" % len(caps_by_id))
   L.append("| Flag comparisons in agreement | %d |" % agreements)
   L.append("")

   # ---- Section A ----
   L.append("## Section A -- STRONG leads (HamLib STATES it, TR4W denies it)")
   L.append("")
   if strong:
      L.append("Sorted with genuine functional leads first (rows without an \"under-declared")
      L.append("family\" note), then the flags-not-declared documentation gaps.")
      L.append("")
      L.append("| TR4W radio | flag TR4W lacks | HamLib evidence | HamLib citation | note |")
      L.append("|---|---|---|---|---|")
      for row in sorted(strong, key=lambda r: (r["note"] is not None, r["flag"], r["enum"])):
         extra = row["note"] or ""
         if row.get("ptt_type") == "RIG_PTT_NONE" and row["flag"] == "rcReadTXStatus":
            extra = (extra + " " if extra else "") + \
                    "(hamlib .ptt_type=RIG_PTT_NONE -- get_ptt is a CAT read, consistent)"
         val = row.get("value")
         ev = row["desc"] + ((" (`%s`)" % val) if val and val is not True else "")
         L.append("| %s (%s) | %s | %s | %s | %s |"
                  % (row["enum"], row["display"], row["flag"], ev, row["cite"], extra))
   else:
      L.append("None found.")
   L.append("")

   # ---- Section B ----
   L.append("## Section B -- WEAK leads (TR4W claims it, HamLib omits it)")
   L.append("")
   L.append("HamLib omission may simply mean \"unimplemented in HamLib\"; these rank far")
   L.append("below Section A and mostly need no action.")
   L.append("")
   if weak:
      L.append("| TR4W radio | flag TR4W claims | HamLib omission | HamLib citation |")
      L.append("|---|---|---|---|")
      for row in sorted(weak, key=lambda r: (r["flag"], r["enum"])):
         L.append("| %s (%s) | %s | no %s | %s |"
                  % (row["enum"], row["display"], row["flag"],
                     row["desc"].split(" ")[0], row["cite"]))
   else:
      L.append("None found.")
   L.append("")

   # ---- Section C ----
   L.append("## Section C -- serial-parameter disagreements")
   L.append("")
   L.append("TR4W registration `SerialParams(baud, data, parity, stop)` vs hamlib")
   L.append("`serial_rate_min/max`, `serial_data_bits`, `serial_stop_bits`, `serial_parity`.")
   L.append("A TR4W default baud inside hamlib's range is NOT a finding (defaults may differ).")
   L.append("")
   L.append("**Known deliberate divergence:** OMNI6 uses **1 stop bit** per its Model 563")
   L.append("manual section 5.2 (bench-decided). If hamlib disagrees below, hamlib is the one")
   L.append("likely wrong -- do not flag TR4W.")
   L.append("")
   L.append("**Caution on stop bits generally:** hamlib caps state what hamlib SENDS, not what")
   L.append("the rig requires (a UART receiving with 1 stop bit accepts 2-stop-bit frames).")
   L.append("Classic Kenwood serial protocol docs specify 4800 baud with 2 stop bits, so for")
   L.append("the older Kenwoods TR4W's 2 is likely the manual-correct value and hamlib's 1 the")
   L.append("permissive one. The Elecraft rows (default 8N1 per Elecraft's programmer's")
   L.append("reference) are the ones most worth a bench/manual check.")
   L.append("")
   if serial_findings:
      L.append("| TR4W radio | TR4W default | disagreement(s) | HamLib citation |")
      L.append("|---|---|---|---|")
      for row in serial_findings:
         mark = " **(OMNI6 exception -- see above; TR4W is right)**" if row["enum"] == "OMNI6" else ""
         L.append("| %s (%s) | %s | %s%s | %s |"
                  % (row["enum"], row["display"], row["tr4w"],
                     "; ".join(row["issues"]), mark, row["cite"]))
   else:
      L.append("None found.")
   L.append("")

   # ---- Section D ----
   L.append("## Section D -- CW keyer speed range disagreements")
   L.append("")
   L.append("Only radios where TR4W declares a non-zero range AND hamlib's level_gran gives a")
   L.append("KEYSPD range. Note hamlib backends mostly inherit a family-wide default from")
   L.append("`level_gran_<backend>.h` (e.g. 4..60), so a mismatch here is usually hamlib being")
   L.append("generic rather than TR4W being wrong -- weigh these as weak-to-medium leads and")
   L.append("check the rig manual, not hamlib, for the truth.")
   L.append("")
   if cw_findings:
      L.append("| TR4W radio | TR4W wpm | HamLib wpm | HamLib citation |")
      L.append("|---|---|---|---|")
      for row in cw_findings:
         L.append("| %s (%s) | %d..%d | %d..%d | %s |"
                  % (row["enum"], row["display"], row["tr4w"][0], row["tr4w"][1],
                     row["hamlib"][0], row["hamlib"][1], row["cite"]))
   else:
      L.append("None found.")
   L.append("")

   # ---- Section E ----
   L.append("## Section E -- suspect hamlibID values in RadioParametersArray")
   L.append("")
   L.append("These enum rows carry a hamlibID that resolves to a DIFFERENT radio in this")
   L.append("HamLib checkout. They are excluded from Sections A-D (the join would compare")
   L.append("the wrong rig), and they are findings in their own right: the hamlibID is what")
   L.append("TR4W hands to HamLib when a radio is driven through the HamLib path, so a wrong")
   L.append("ID there drives the rig with another model's backend. Verify against the")
   L.append("riglist of the HamLib version TR4W actually ships (`libhamlib-4.dll`) before")
   L.append("changing anything -- IDs are stable in HamLib, but the shipped list is the")
   L.append("authority.")
   L.append("")
   if suspect_joins:
      L.append("| TR4W enum | hamlibID in LOGRADIO | resolves to | name-matching candidates in riglist.h |")
      L.append("|---|---|---|---|")
      for s in suspect_joins:
         cands = ", ".join("%s = %d" % (m.replace("RIG_MODEL_", ""), n)
                           for m, n in s["candidates"]) or "(none by name)"
         L.append("| %s (%s) | %d | %s (%s) | %s |"
                  % (s["enum"], s["display"], s["hid"],
                     s["macro"].replace("RIG_MODEL_", ""), s["cite"], cands))
      if any(s["enum"] == "FLEX" for s in suspect_joins):
         L.append("")
         L.append("FLEX = 2048 is RIG_MODEL_POWERSDR (the PowerSDR/Flex-5000-era backend).")
         L.append("The factory registration is 'FlexRadio 6000'; HamLib's 6000-series model is")
         L.append("RIG_MODEL_F6K = 2036 (rigs/kenwood/flex6xxx.c). Possibly deliberate --")
         L.append("the ID predates the 6000 driver -- but worth a decision on record.")
   else:
      L.append("None found.")
   L.append("")

   # ---- Appendix ----
   L.append("## Appendix -- unmappable / unresolved / limitations")
   L.append("")
   L.append("### TR4W registrations with no hamlibID (unmappable)")
   L.append("")
   if unmapped:
      for e, d, why in unmapped:
         L.append("- %s (%s): %s" % (e, d, why))
   else:
      L.append("None.")
   L.append("")
   L.append("### TR4W registrations whose hamlibID has no parsed caps struct")
   L.append("")
   if no_caps:
      for e, d, hid, macro in no_caps:
         L.append("- %s (%s): hamlibID %d -> %s" % (e, d, hid, macro))
   else:
      L.append("None.")
   L.append("")
   L.append("### Enum members with NO factory registration (legacy/HamLib-only path)")
   L.append("")
   L.append("These are in `InterfacedRadioType` but have no `RegisterRadio` call, so they are")
   L.append("not TR4W factory radios and are excluded from all sections above:")
   L.append("")
   L.append(", ".join(enums_not_registered) if enums_not_registered else "None.")
   L.append("")
   L.append("### Special cases")
   L.append("")
   flex = registered.get("FLEX")
   if flex and flex.get("multiclass"):
      L.append("- FLEX registers TWO driver classes (%s); their capability sets were UNIONED"
               % " + ".join(flex["classes"]))
      L.append("  for this comparison. HamLib's flex6xxx backend is a Kenwood-derived CAT")
      L.append("  driver, closest to TFlexCAT.")
   L.append("- TR4W maps its single TS570 entry to hamlibID %s; hamlib splits TS-570D/TS-570S"
            % hamlib_ids.get("TS570"))
   L.append("  into two models with identical relevant caps.")
   L.append("")
   L.append("### Parser limitations (honest list -- nothing silently truncated)")
   L.append("")
   L.append("- Pascal side: capability statements are recognized only inside `Create`")
   L.append("  constructors and `DefineCapabilities` bodies (which is where the codebase puts")
   L.append("  them); a capability set anywhere else would be missed.")
   L.append("- `inherited Create` is assumed to run the nearest ancestor constructor (the")
   L.append("  intended semantics; the known bare-`inherited Create` overload trap would be a")
   L.append("  TR4W bug, not a parser feature).")
   L.append("- C side: no real preprocessor. Object-like #defines from the backend directory")
   L.append("  are expanded iteratively; #ifdef branches inside caps structs are all taken.")
   L.append("- HamLib \"presence of a caps field\" can be inherited generic code (e.g.")
   L.append("  `icom_mem_get_split_vfo`, `kenwood_get_rit`) that a given rig may NAK at run")
   L.append("  time -- exactly why every Section A row is a bench lead, not a fact.")
   if LIMITATIONS:
      for lim in LIMITATIONS:
         L.append("- %s" % lim)
   L.append("")

   # ---- Full data table (transparency) ----
   L.append("## Reference -- full joined table")
   L.append("")
   L.append("TR4W flags shown without the universal rcCWFlushDisruptsTiming. HamLib columns:")
   L.append("V=targetable freq, R=get_rit, S=get_split_vfo, T=get_ptt, M=send_morse,")
   L.append("K=KEYSPD level, D=send_voice_mem. '-' = not stated / not present.")
   L.append("")
   L.append("| enum | hamlibID | hamlib model | TR4W flags | TR4W wpm | hamlib V R S T M K D | hamlib wpm |")
   L.append("|---|---|---|---|---|---|---|")
   for enum, info in registered.items():
      hid = hamlib_ids.get(enum)
      cap = caps_by_id.get(hid) if hid else None
      shown = sorted(f for f in info["flags"] if f != "rcCWFlushDisruptsTiming")
      wpm = "%d..%d" % (info["cwmin"], info["cwmax"]) if (info["cwmin"] or info["cwmax"]) else "-"
      if cap:
         hl = " ".join("Y" if cap.get(k) else "-"
                       for k in ("targetable_freq", "get_rit", "get_split_vfo",
                                 "get_ptt", "send_morse", "level_keyspd", "send_voice_mem"))
         hwpm = "%d..%d" % cap["keyspd_range"] if cap.get("keyspd_range") else "-"
         mdl = cap["model_macro"].replace("RIG_MODEL_", "")
         if not join_is_plausible(enum, cap["model_macro"]):
            mdl += " **(SUSPECT JOIN -- see Section E)**"
      else:
         hl, hwpm, mdl = "(no caps)", "-", "-"
      L.append("| %s | %s | %s | %s | %s | %s | %s |"
               % (enum, hid or "-", mdl, ", ".join(shown) or "(none)", wpm, hl, hwpm))
   L.append("")

   os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
   with open(REPORT_PATH, "w", encoding="utf-8", newline="\n") as f:
      f.write("\n".join(L))


if __name__ == "__main__":
   main()
