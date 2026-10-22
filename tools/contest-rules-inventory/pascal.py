"""pascal.py -- the token-level Pascal reader every other module uses.

It reads the CODE-ONLY text that tr4w/build/PascalSource.psm1 produces
(comments stripped, line numbers preserved), so nothing here has to know about
comments. What it does know is STRUCTURE, which a line regex cannot answer --
CLAUDE.md's "A LINE REGEX CANNOT PARSE PASCAL" records three wrong answers that
came from trying.

ONE case walker. The throwaway audit carried three copies of it (the site
scanner, the FoundContest override reader and the arm-span reader), and they
had already drifted on how an `else` part ends the labels. This is the careful
one: nesting-aware (begin/case/try/record/asm/repeat open, end/until close),
so a nested case's arms are not counted as the outer case's, and a label split
from its colon by a stripped comment is still a label.
"""

import re

TOKEN_RX = re.compile(r"'(?:[^']|'')*'|[A-Za-z_]\w*|\d+(?:\.\d+)?|:=|<>|<=|>=|\.\.|\S")
IDENT_RX = re.compile(r"[A-Za-z_]\w*$")
ROUTINE_RX = re.compile(r"^\s*(?:class\s+)?(procedure|function|constructor|destructor)\s+([\w.]+)", re.I)

OPENERS = {"BEGIN", "CASE", "TRY", "RECORD", "ASM", "REPEAT"}
CLOSERS = {"END", "UNTIL"}
STOP_BEFORE = {"IF", "AND", "OR", "NOT", "THEN", "WHILE", "UNTIL", "XOR", "BEGIN", "ELSE", "DO"}
STOP_AFTER = {"THEN", "AND", "OR", "DO", "OF", "ELSE"}


def is_ident(t):
   return IDENT_RX.match(t) is not None


def tokenize(text):
   """[(token, line)] for the whole text, lines 1-based."""
   toks = []
   for ln, line in enumerate(text.split("\n"), start=1):
      for m in TOKEN_RX.finditer(line):
         toks.append((m.group(0), ln))
   return toks


def routines_by_line(text):
   """{line: enclosing routine} -- the most recent implementation-section
   routine header at or above the line, or '(unit level)'."""
   out = {}
   current = "(unit level)"
   in_impl = False
   for ln, line in enumerate(text.split("\n"), start=1):
      if re.match(r"^\s*implementation\b", line, re.I):
         in_impl = True
      if in_impl:
         m = ROUTINE_RX.match(line)
         if m:
            current = m.group(2)
      out[ln] = current
   return out


def _matching(toks, j, step, opener, closer):
   """Index of the bracket matching toks[j], walking in direction `step`."""
   depth = 0
   k = j
   while 0 <= k < len(toks):
      if toks[k][0] == opener:
         depth += 1
      elif toks[k][0] == closer:
         depth -= 1
         if depth == 0:
            return k
      k += step
   return k


def operand_before(toks, i):
   """The designator ending at toks[i - 1]: walks back over a.b^[x](y)."""
   j = i - 1
   parts = []
   while j >= 0:
      t = toks[j][0]
      if t in (")", "]"):
         k = _matching(toks, j, -1, t, "(" if t == ")" else "[")
         parts = [x[0] for x in toks[k:j + 1]] + parts
         j = k - 1
         continue
      if is_ident(t) or t in (".", "^"):
         if is_ident(t) and parts and is_ident(parts[0]):
            break
         if t.upper() in STOP_BEFORE:
            break
         parts.insert(0, t)
         j -= 1
         continue
      break
   return "".join(parts)


def operand_after(toks, i):
   """The designator starting at toks[i + 1]."""
   j = i + 1
   parts = []
   while j < len(toks):
      t = toks[j][0]
      if is_ident(t):
         if parts and is_ident(parts[-1]):
            break
         if t.upper() in STOP_AFTER:
            break
         parts.append(t)
      elif t in (".", "^"):
         parts.append(t)
      elif t in ("(", "["):
         k = _matching(toks, j, 1, t, ")" if t == "(" else "]")
         parts += [x[0] for x in toks[j:k + 1]]
         j = k
      else:
         break
      j += 1
   return "".join(parts)


def set_members(toks, i):
   """toks[i] is '[': the identifiers inside the set constructor."""
   out = []
   j = i + 1
   depth = 1
   while j < len(toks) and depth > 0:
      t = toks[j][0]
      if t == "[":
         depth += 1
      elif t == "]":
         depth -= 1
      elif is_ident(t):
         out.append(t)
      j += 1
   return out


class CaseStatement:
   """One `case <selector> of ... end`.

   arms: [{'labels': [identifiers], 'line': label line, 'start_tok', 'end_tok',
           'is_else': bool}] -- the else part is an arm with is_else True and
           no labels. end_tok is exclusive.
   label_tokens: indices of every token that is part of a label, so a scanner
           can tell `X:` from a use of X.
   end_tok: index of the closing END.
   """

   def __init__(self, selector, arms, label_tokens, end_tok):
      self.selector = selector
      self.arms = arms
      self.label_tokens = label_tokens
      self.end_tok = end_tok

   def labelled_arms(self):
      return [a for a in self.arms if not a["is_else"]]

   def line_spans(self, toks):
      """[(arm, first line, last line)] -- an arm runs to the line before the
      next arm's label; the last runs to the END line."""
      out = []
      end_line = toks[self.end_tok][1] if self.end_tok < len(toks) else toks[-1][1]
      for n, a in enumerate(self.arms):
         if n + 1 < len(self.arms):
            last = self.arms[n + 1]["line"] - 1
         else:
            last = end_line
         out.append((a, a["line"], last))
      return out


def walk_case(toks, i):
   """toks[i] is CASE. Parse the statement; nested cases are skipped whole."""
   j = i + 1
   sel = []
   while j < len(toks) and toks[j][0].upper() != "OF":
      sel.append(toks[j][0])
      j += 1
   selector = "".join(
      (" " + t if re.match(r"\w", t) and prev and re.match(r"\w", prev) else t)
      for prev, t in zip([""] + sel[:-1], sel))
   j += 1
   arms = []
   label_tokens = set()
   depth = 0
   expecting_label = True
   label = []
   label_start = None
   seen_else = False

   def close_current(at):
      if arms:
         arms[-1]["end_tok"] = at

   while j < len(toks):
      t, ln = toks[j]
      u = t.upper()
      if depth == 0 and u == "END":
         close_current(j)
         return CaseStatement(selector, arms, label_tokens, j)
      if u in OPENERS:
         if u == "CASE":
            nested = walk_case(toks, j)
            j = nested.end_tok + 1
            expecting_label = False
            continue
         depth += 1
         expecting_label = False
      elif u in CLOSERS:
         depth -= 1
      elif depth == 0:
         if expecting_label and not seen_else:
            if u in ("ELSE", "OTHERWISE"):
               seen_else = True
               expecting_label = False
               close_current(j)
               arms.append({"labels": [], "line": ln, "start_tok": j, "end_tok": None, "is_else": True})
            elif t == ":":
               close_current(label_start)
               arms.append({"labels": [x[0] for x in label if is_ident(x[0])],
                            "line": label[0][1] if label else ln,
                            "start_tok": label_start, "end_tok": None, "is_else": False})
               label = []
               expecting_label = False
            else:
               if not label:
                  label_start = j
               label.append((t, ln))
               label_tokens.add(j)
         elif t == ";":
            expecting_label = True
            label = []
      j += 1
   close_current(j)
   return CaseStatement(selector, arms, label_tokens, j)
