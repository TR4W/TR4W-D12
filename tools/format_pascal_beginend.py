#!/usr/bin/env python3
"""
format_pascal_beginend.py -- enforce the TR4W begin/end house style.

House style (see CLAUDE.md):

   if SomeCondition then
      begin
      DoSomething;
      DoSomethingElse;
      end
   else
      begin
      DoAlternative;
      end;

   * 3-space indentation.
   * begin/end always, even for a single statement.
   * begin on its OWN line, 3 spaces in from the if/for/while/with/else.
   * the block body sits at the SAME indent as its begin/end -- not past it.

Two transformations:

   1. Re-indent an existing control block (a begin that is the body of
      then/do/else/on..do) so begin/end land at header+3 and the body lines
      are shifted, as a rigid group, onto that same column.
   2. Wrap an unwrapped single-statement body in begin/end, including the
      one-line `if X then DoSomething;` form.

Both are driven by a real Object Pascal lexer plus a recursive-descent
statement parser, NOT by regular expressions: `end` closes six different
things in Pascal and only some of them are block bodies.  Anything the
parser cannot account for is left strictly alone -- see REFUSALS below.

REFUSALS (deliberate; the tool prints them with --verbose):
   * any edit whose line span contains a compiler directive ({$IFDEF} and
     friends).  A begin inside one branch may pair with an end outside it.
   * a body that is itself an `if` -- wrapping it would move the binding of
     a dangling `else`.  `else if` chains are left flat for the same reason.
   * `asm` blocks, and any routine whose body fails to parse.
   * any line that begins inside a multi-line { } or (* *) comment.
   * bodies whose header/statement layout is not clean (extra code sharing
     the line, a trailing comment where we would have to move it, a `;` on a
     different line than the statement it closes).
   * `initialization`/`finalization` statement lists (no begin to anchor on).

Encoding/EOL: files are read and written as BYTES.  A UTF-8 BOM is
preserved byte for byte, per-line EOLs are preserved exactly (CRLF is
load-bearing in this repo), and a file that is not valid UTF-8 is round
tripped through latin-1 so no byte is ever changed by decoding.
"""

import argparse
import bisect
import difflib
import os
import sys

INDENT = "   "          # 3 spaces, per CLAUDE.md
INDENT_N = len(INDENT)
MAX_PASSES = 8

# Bodies the lint (tr4w/build/Lint-PascalBeginEnd.ps1) explicitly allows to
# stand alone.  We agree with it for the one-line form so the two tools never
# disagree about the same source line.
LINT_SKIPPABLE = ("exit", "continue", "break")


class LexError(Exception):
   pass


class Refusal(Exception):
   """Raised by the parser when it will not vouch for a region."""

   def __init__(self, reason, line=None):
      super().__init__(reason)
      self.reason = reason
      self.line = line


# ---------------------------------------------------------------------------
# Lexer
# ---------------------------------------------------------------------------

class Token:
   __slots__ = ("kind", "text", "low", "start", "end", "line")

   def __init__(self, kind, text, start, end, line):
      self.kind = kind
      self.text = text
      self.low = text.lower()
      self.start = start
      self.end = end
      self.line = line

   def __repr__(self):
      return "Token(%s,%r,L%d)" % (self.kind, self.text, self.line + 1)


IDENT_START = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_&")
IDENT_CHARS = IDENT_START | set("0123456789")
DIGITS = set("0123456789")
MULTI_SYMBOLS = (":=", "<>", "<=", ">=", "..", "+=", "-=", "*=", "/=")


class Lexed:
   """Token stream plus the per-line bookkeeping the rewriter needs."""

   def __init__(self, text):
      self.text = text
      self.line_starts = _line_starts(text)
      self.tokens = []          # significant tokens only
      self.directive_lines = set()
      self.comment_lines = set()   # lines carrying a // or {...} comment
      self.frozen_lines = set()    # lines that begin inside a multi-line token
      self._lex()

   def line_of(self, offset):
      return bisect.bisect_right(self.line_starts, offset) - 1

   def _mark_span(self, start, end, is_directive):
      ls = self.line_of(start)
      le = self.line_of(max(start, end - 1))
      if is_directive:
         for ln in range(ls, le + 1):
            self.directive_lines.add(ln)
      else:
         self.comment_lines.add(ls)
      # every line after the first is a continuation: its leading whitespace
      # is comment content, so it must never be re-indented.
      for ln in range(ls + 1, le + 1):
         self.frozen_lines.add(ln)

   def _lex(self):
      text = self.text
      n = len(text)
      i = 0
      while i < n:
         c = text[i]
         if c in " \t\r\n":
            i += 1
            continue
         if c == "/" and text[i + 1:i + 2] == "/":
            j = text.find("\n", i)
            j = n if j < 0 else j
            self._mark_span(i, j, False)
            i = j
            continue
         if c == "{":
            j = text.find("}", i)
            if j < 0:
               raise LexError("unterminated { comment at line %d" % (self.line_of(i) + 1))
            j += 1
            self._mark_span(i, j, text[i + 1:i + 2] == "$")
            i = j
            continue
         if c == "(" and text[i + 1:i + 2] == "*":
            j = text.find("*)", i + 2)
            if j < 0:
               raise LexError("unterminated (* comment at line %d" % (self.line_of(i) + 1))
            j += 2
            self._mark_span(i, j, text[i + 2:i + 3] == "$")
            i = j
            continue
         if c == "'":
            j = i + 1
            while True:
               if j >= n or text[j] == "\n":
                  raise LexError("unterminated string at line %d" % (self.line_of(i) + 1))
               if text[j] == "'":
                  if text[j + 1:j + 2] == "'":
                     j += 2
                     continue
                  j += 1
                  break
               j += 1
            self._push("str", i, j)
            i = j
            continue
         if c == "#":
            j = i + 1
            if text[j:j + 1] == "$":
               j += 1
               while j < n and text[j] in "0123456789abcdefABCDEF":
                  j += 1
            else:
               while j < n and text[j] in DIGITS:
                  j += 1
            self._push("chr", i, j)
            i = j
            continue
         if c == "$":
            j = i + 1
            while j < n and text[j] in "0123456789abcdefABCDEF":
               j += 1
            self._push("num", i, j)
            i = j
            continue
         if c in DIGITS:
            j = i
            while j < n and text[j] in DIGITS:
               j += 1
            if text[j:j + 1] == "." and text[j + 1:j + 2] != ".":
               j += 1
               while j < n and text[j] in DIGITS:
                  j += 1
            if text[j:j + 1] in ("e", "E"):
               k = j + 1
               if text[k:k + 1] in ("+", "-"):
                  k += 1
               if text[k:k + 1] in DIGITS:
                  j = k
                  while j < n and text[j] in DIGITS:
                     j += 1
            self._push("num", i, j)
            i = j
            continue
         if c in IDENT_START:
            j = i + 1
            while j < n and text[j] in IDENT_CHARS:
               j += 1
            self._push("id", i, j)
            i = j
            continue
         two = text[i:i + 2]
         if two in MULTI_SYMBOLS:
            self._push("sym", i, i + 2)
            i += 2
            continue
         self._push("sym", i, i + 1)
         i += 1

   def _push(self, kind, start, end):
      self.tokens.append(Token(kind, self.text[start:end], start, end, self.line_of(start)))


def _line_starts(text):
   starts = [0]
   pos = text.find("\n")
   while pos >= 0:
      starts.append(pos + 1)
      pos = text.find("\n", pos + 1)
   return starts


# ---------------------------------------------------------------------------
# Edit records
# ---------------------------------------------------------------------------

class BlockRec:
   """An existing begin..end that is the body of a control statement."""

   kind = "block"

   def __init__(self, ctrl_idx, header_idx, begin_idx, end_idx):
      self.ctrl_idx = ctrl_idx        # the if/for/while/with/else/on token
      self.header_idx = header_idx    # the then/do/else token
      self.begin_idx = begin_idx
      self.end_idx = end_idx


class WrapRec:
   """An unwrapped single-statement body that needs begin/end."""

   kind = "wrap"

   def __init__(self, ctrl_idx, header_idx, stmt_start, stmt_end, semi_idx):
      self.ctrl_idx = ctrl_idx
      self.header_idx = header_idx
      self.stmt_start = stmt_start
      self.stmt_end = stmt_end        # last token of the statement proper
      self.semi_idx = semi_idx        # index of the closing ';' or None


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

BLOCK_OPENERS_FOR_SKIP = ("begin", "case", "try", "asm", "record", "class",
                          "object", "interface", "dispinterface")

STMT_TERMINATORS = ("end", "else", "until", "finally", "except")


class Parser:
   """
   Recursive-descent over statement structure only.  Declarations are not
   parsed: the driver scans forward for a top-level `begin` and parses the
   block it opens, which is exactly the region where begin/end style matters.
   """

   def __init__(self, lexed, refusals):
      self.lx = lexed
      self.T = lexed.tokens
      self.n = len(lexed.tokens)
      self.records = []
      self.refusals = refusals

   # -- helpers ------------------------------------------------------------

   def low(self, i):
      return self.T[i].low if 0 <= i < self.n else ""

   def txt(self, i):
      return self.T[i].text if 0 <= i < self.n else ""

   def refuse(self, reason, i):
      line = self.T[i].line + 1 if 0 <= i < self.n else 0
      raise Refusal(reason, line)

   def find_kw(self, i, kw, stop=("begin",)):
      """Scan forward for keyword `kw` at paren depth 0."""
      depth = 0
      while i < self.n:
         t = self.T[i]
         if t.text in "([":
            depth += 1
         elif t.text in ")]":
            depth -= 1
         elif depth == 0:
            if t.low == kw:
               return i
            if t.text == ";" or t.low in stop:
               self.refuse("missing '%s'" % kw, i)
         i += 1
      self.refuse("ran off the end looking for '%s'" % kw, self.n - 1)

   # -- entry point --------------------------------------------------------

   def parse_file(self):
      i = 0
      while i < self.n:
         if self.low(i) == "begin":
            mark = len(self.records)
            try:
               i = self.parse_block(i)
            except Refusal as exc:
               del self.records[mark:]
               self.refusals.append((exc.line, exc.reason))
               i = self.skip_block_dumb(i)
         else:
            i += 1
      return self.records

   def skip_block_dumb(self, i):
      """Balanced skip past a block we refused to parse."""
      depth = 0
      while i < self.n:
         low = self.low(i)
         if low in BLOCK_OPENERS_FOR_SKIP:
            depth += 1
         elif low == "end":
            depth -= 1
            if depth <= 0:
               return i + 1
         i += 1
      return self.n

   # -- statements ---------------------------------------------------------

   def parse_block(self, i):
      """T[i] is 'begin'.  Returns index just past the matching 'end'."""
      i = self.parse_stmt_list(i + 1, ("end",))
      if self.low(i) != "end":
         self.refuse("expected 'end'", min(i, self.n - 1))
      return i + 1

   def parse_stmt_list(self, i, terminators):
      while i < self.n:
         while self.txt(i) == ";":
            i += 1
         if i >= self.n:
            break
         if self.low(i) in terminators:
            return i
         if self.low(i) in STMT_TERMINATORS:
            self.refuse("unexpected '%s'" % self.txt(i), i)
         i = self.parse_statement(i)
      self.refuse("ran off the end of a statement list", self.n - 1)

   def parse_statement(self, i):
      low = self.low(i)

      # a label:  `10: Foo;`  /  `MyLabel: Foo;`
      if self.T[i].kind in ("id", "num") and self.txt(i + 1) == ":" and low not in (
            "if", "case", "for", "while", "with", "try", "repeat", "begin", "asm"):
         nxt = self.low(i + 2)
         if nxt in ("begin", "if", "for", "while", "with", "case", "try", "repeat"):
            return self.parse_statement(i + 2)

      if low == "begin":
         return self.parse_block(i)
      if low == "if":
         return self.parse_if(i)
      if low in ("for", "while", "with"):
         return self.parse_loop(i)
      if low == "case":
         return self.parse_case(i)
      if low == "try":
         return self.parse_try(i)
      if low == "repeat":
         return self.parse_repeat(i)
      if low == "asm":
         self.refuse("asm block", i)
      return self.parse_simple(i)

   def parse_simple(self, i):
      depth = 0
      start = i
      while i < self.n:
         t = self.T[i]
         if t.text in "([":
            depth += 1
         elif t.text in ")]":
            depth -= 1
         elif depth == 0:
            if t.text == ";":
               return i
            if t.low in STMT_TERMINATORS:
               return i
            if t.low in ("begin", "procedure", "function", "asm"):
               # an anonymous method (or a construct we do not model)
               self.refuse("unmodelled '%s' inside a statement" % t.text, i)
         i += 1
      self.refuse("unterminated statement", start)

   def parse_if(self, i):
      then_idx = self.find_kw(i + 1, "then")
      j = self.parse_body(i, then_idx, then_idx + 1)
      if self.low(j) == "else":
         return self.parse_body(j, j, j + 1)
      return j

   def parse_loop(self, i):
      do_idx = self.find_kw(i + 1, "do")
      return self.parse_body(i, do_idx, do_idx + 1)

   def parse_repeat(self, i):
      i = self.parse_stmt_list(i + 1, ("until",))
      if self.low(i) != "until":
         self.refuse("expected 'until'", min(i, self.n - 1))
      return self.parse_simple(i + 1)

   def parse_case(self, i):
      i = self.find_kw(i + 1, "of") + 1
      while i < self.n:
         while self.txt(i) == ";":
            i += 1
         low = self.low(i)
         if low == "end":
            return i + 1
         if low == "else":
            i = self.parse_stmt_list(i + 1, ("end",))
            if self.low(i) != "end":
               self.refuse("expected 'end' closing case", min(i, self.n - 1))
            return i + 1
         # label list, then ':' , then one statement
         depth = 0
         while i < self.n:
            t = self.T[i]
            if t.text in "([":
               depth += 1
            elif t.text in ")]":
               depth -= 1
            elif depth == 0 and t.text == ":":
               break
            elif depth == 0 and t.text == ";":
               self.refuse("malformed case label", i)
            i += 1
         if i >= self.n:
            self.refuse("malformed case label", self.n - 1)
         i += 1
         if self.low(i) in ("end", "else"):
            continue
         i = self.parse_statement(i)
      self.refuse("unterminated case", self.n - 1)

   def parse_try(self, i):
      i = self.parse_stmt_list(i + 1, ("finally", "except"))
      low = self.low(i)
      if low == "finally":
         i = self.parse_stmt_list(i + 1, ("end",))
      elif low == "except":
         i += 1
         while self.low(i) == "on":
            do_idx = self.find_kw(i + 1, "do")
            i = self.parse_body(i, do_idx, do_idx + 1)
            while self.txt(i) == ";":
               i += 1
         if self.low(i) == "else":
            i = self.parse_stmt_list(i + 1, ("end",))
         elif self.low(i) != "end":
            i = self.parse_stmt_list(i, ("end", "else"))
            if self.low(i) == "else":
               i = self.parse_stmt_list(i + 1, ("end",))
      else:
         self.refuse("expected finally/except", min(i, self.n - 1))
      if self.low(i) != "end":
         self.refuse("expected 'end' closing try", min(i, self.n - 1))
      return i + 1

   def parse_body(self, ctrl_idx, header_idx, i):
      """
      Parse the body of then/do/else and record what should happen to it.
      ctrl_idx is the token whose LINE sets the target indent.
      """
      if i >= self.n:
         self.refuse("missing body", self.n - 1)
      low = self.low(i)

      if low == "begin":
         slot = len(self.records)
         self.records.append(None)
         j = self.parse_block(i)
         self.records[slot] = BlockRec(ctrl_idx, header_idx, i, j - 1)
         return j

      if low == "if":
         # Wrapping a bare `if` body would re-bind a dangling else.  Parse it
         # (so inner blocks are still reached) but never wrap it.
         return self.parse_statement(i)
      if low == "asm":
         self.refuse("asm as a control body", i)

      slot = len(self.records)
      self.records.append(None)
      j = self.parse_statement(i)
      if j <= i:
         # An EMPTY statement -- `else` followed straight by `end`, which in
         # real TR4W source means the body is commented out.  There is nothing
         # to wrap, and wrapping nothing produces `begin end` noise that then
         # fails to converge.
         del self.records[slot:]
         return j
      semi = j if self.txt(j) == ";" else None
      self.records[slot] = WrapRec(ctrl_idx, header_idx, i, j - 1, semi)
      return j


# ---------------------------------------------------------------------------
# Rewriter
# ---------------------------------------------------------------------------

class Line:
   __slots__ = ("indent", "orig_indent", "body", "eol", "raw", "frozen", "blank")

   def __init__(self, raw):
      self.raw = raw
      if raw.endswith("\r\n"):
         self.eol = "\r\n"
      elif raw.endswith("\n"):
         self.eol = "\n"
      elif raw.endswith("\r"):
         self.eol = "\r"
      else:
         self.eol = ""
      core = raw[:len(raw) - len(self.eol)]
      stripped = core.lstrip(" \t")
      self.indent = len(core) - len(stripped)
      self.orig_indent = self.indent
      self.body = stripped
      self.blank = (stripped == "")
      self.frozen = False

   def render(self):
      if self.frozen or self.blank:
         return self.raw
      return (" " * self.indent) + self.body + self.eol


def split_lines(text):
   out = []
   i = 0
   n = len(text)
   while i < n:
      j = text.find("\n", i)
      if j < 0:
         out.append(text[i:])
         break
      out.append(text[i:j + 1])
      i = j + 1
   return out


class Rewriter:
   def __init__(self, lexed, records, opts, refusals):
      self.lx = lexed
      self.T = lexed.tokens
      self.opts = opts
      self.refusals = refusals
      self.lines = [Line(raw) for raw in split_lines(lexed.text)]
      for ln in lexed.frozen_lines:
         if ln < len(self.lines):
            self.lines[ln].frozen = True
      self.records = records
      self.insert_before = {}   # line -> [(indent, body)]
      self.insert_after = {}
      self.replace = {}         # line -> [(indent, body)]
      self.touched = set()      # lines whose text we rewrote/split
      # significant tokens per line, in order
      self.by_line = {}
      for idx, t in enumerate(self.T):
         self.by_line.setdefault(t.line, []).append(idx)

   # -- guards -------------------------------------------------------------

   def has_directive(self, l0, l1):
      for ln in range(l0, l1 + 1):
         if ln in self.lx.directive_lines:
            return True
      return False

   def span_clear(self, l0, l1):
      if self.has_directive(l0, l1):
         return False, "compiler directive in the region"
      for ln in range(l0, l1 + 1):
         if ln in self.touched:
            return False, "overlaps an earlier edit"
      return True, ""

   def is_first_on_line(self, idx):
      return self.by_line[self.T[idx].line][0] == idx

   def is_last_on_line(self, idx):
      return self.by_line[self.T[idx].line][-1] == idx

   def line_has_comment(self, ln):
      return ln in self.lx.comment_lines

   def anchor_indent(self, ctrl_idx):
      """
      Column the block's begin/end must line up 3 spaces in from.

      Normally the indent of the control statement's line.  When the control
      token does not start its line (a case arm's `1: if A then`), the token's
      own column is the only honest anchor -- and it has to be expressed in
      terms of the line's CURRENT indent, since an enclosing block may already
      have shifted it this pass.
      """
      idx = ctrl_idx
      # `else if B then` is one visual unit: anchor on the head of the chain,
      # never on the inner `if`, or an else-if ladder walks right.
      while (idx > 0 and self.T[idx - 1].low == "else"
             and self.T[idx - 1].line == self.T[idx].line):
         idx -= 1
      tok = self.T[idx]
      line = self.lines[tok.line]
      if self.is_first_on_line(idx):
         return line.indent
      if self.T[idx - 1].low == "end" and self.T[idx - 1].line == tok.line:
         # `end else ...` -- the else's column is an artefact of the end
         # before it, not an indent we should propagate.
         return None
      col = tok.start - self.lx.line_starts[tok.line]
      return col + (line.indent - line.orig_indent)

   def note(self, rec, reason):
      line = self.T[rec.ctrl_idx].line + 1
      self.refusals.append((line, reason))

   # -- driver -------------------------------------------------------------

   def run(self):
      for rec in self.records:
         if rec is None:
            continue
         try:
            if rec.kind == "block":
               self.do_block(rec)
            else:
               self.do_wrap(rec)
         except Refusal as exc:
            self.refusals.append((exc.line, exc.reason))
      return self.render()

   # -- block re-indentation ----------------------------------------------

   def do_block(self, rec):
      T = self.T
      bl = T[rec.begin_idx].line
      el = T[rec.end_idx].line
      ctrl_line = T[rec.ctrl_idx].line
      ok, why = self.span_clear(min(ctrl_line, bl), el)
      if not ok:
         self.note(rec, "block not re-indented: " + why)
         return
      if not self.is_last_on_line(rec.begin_idx):
         self.note(rec, "block not re-indented: code follows 'begin' on its line")
         return
      if not self.is_first_on_line(rec.end_idx):
         self.note(rec, "block not re-indented: code precedes 'end' on its line")
         return
      if self.line_has_comment(bl) and bl != ctrl_line:
         # a trailing comment on the begin line is fine to move with it
         pass

      anchor = self.anchor_indent(rec.ctrl_idx)
      if anchor is None:
         self.note(rec, "block not re-indented: no reliable indent anchor")
         return
      target = anchor + INDENT_N

      # begin sharing the header line -> split it onto its own line
      if bl == ctrl_line:
         if not self.is_first_on_line(rec.ctrl_idx):
            # e.g. `end else begin` -- moving the begin down would leave the
            # `else` stranded on the wrong column.  Not our business.
            self.note(rec, "block not re-indented: '%s' does not start its line"
                      % self.T[rec.ctrl_idx].text)
            return
         if self.line_has_comment(bl):
            self.note(rec, "block not re-indented: comment on the 'begin' line")
            return
         line = self.lines[bl]
         head_end = T[rec.begin_idx].start - self.lx.line_starts[bl]
         head_txt = line.raw[:head_end].rstrip()
         head_body = head_txt.lstrip(" \t")
         if head_body == "":
            self.note(rec, "block not re-indented: nothing precedes 'begin'")
            return
         self.replace[bl] = [(line.indent, head_body), (target, "begin")]
         self.touched.add(bl)
         begin_indent_now = target
      else:
         self.lines[bl].indent = target
         begin_indent_now = target

      # body: shift as a rigid group so nested structure survives
      first = None
      for ln in range(bl + 1, el):
         if not self.lines[ln].blank and not self.lines[ln].frozen:
            first = ln
            break
      if first is not None:
         shift = begin_indent_now - self.lines[first].indent
         if shift:
            for ln in range(bl + 1, el):
               lo = self.lines[ln]
               if lo.blank or lo.frozen:
                  continue
               if lo.indent + shift < 0:
                  self.note(rec, "block not re-indented: shift would go negative")
                  return
            for ln in range(bl + 1, el):
               lo = self.lines[ln]
               if lo.blank or lo.frozen:
                  continue
               lo.indent += shift
      self.lines[el].indent = target

   # -- wrapping -----------------------------------------------------------

   def do_wrap(self, rec):
      T = self.T
      ctrl_line = T[rec.ctrl_idx].line
      hl = T[rec.header_idx].line
      sl = T[rec.stmt_start].line
      last_idx = rec.semi_idx if rec.semi_idx is not None else rec.stmt_end
      xl = T[last_idx].line

      ok, why = self.span_clear(min(ctrl_line, hl), xl)
      if not ok:
         self.note(rec, "body not wrapped: " + why)
         return

      anchor = self.anchor_indent(rec.ctrl_idx)
      if anchor is None:
         self.note(rec, "body not wrapped: no reliable indent anchor")
         return
      target = anchor + INDENT_N
      tail = ";" if rec.semi_idx is not None else ""

      if hl == sl:
         self.wrap_single_line(rec, ctrl_line, hl, xl, target, tail)
      else:
         self.wrap_multi_line(rec, ctrl_line, hl, sl, xl, target, tail)

   def wrap_multi_line(self, rec, ctrl_line, hl, sl, xl, target, tail):
      T = self.T
      if not self.is_last_on_line(rec.header_idx):
         self.note(rec, "body not wrapped: code follows then/do/else on its line")
         return
      if not self.is_first_on_line(rec.stmt_start):
         self.note(rec, "body not wrapped: code precedes the statement")
         return
      last_idx = rec.semi_idx if rec.semi_idx is not None else rec.stmt_end
      if not self.is_last_on_line(last_idx):
         self.note(rec, "body not wrapped: code follows the statement on its line")
         return
      for ln in range(sl, xl + 1):
         if self.lines[ln].frozen:
            self.note(rec, "body not wrapped: multi-line comment inside the body")
            return

      shift = target - self.lines[sl].indent
      for ln in range(sl, xl + 1):
         lo = self.lines[ln]
         if lo.blank:
            continue
         if lo.indent + shift < 0:
            self.note(rec, "body not wrapped: shift would go negative")
            return
      for ln in range(sl, xl + 1):
         lo = self.lines[ln]
         if not lo.blank:
            lo.indent += shift

      self.insert_before.setdefault(sl, []).append((target, "begin"))
      self.insert_after.setdefault(xl, []).append((target, "end" + tail))
      for ln in range(sl, xl + 1):
         self.touched.add(ln)

   def wrap_single_line(self, rec, ctrl_line, hl, xl, target, tail):
      """The `if X then DoSomething;` form -- expand it to four lines."""
      T = self.T
      if not self.opts.split_single_line:
         return
      if hl != xl or hl != ctrl_line:
         self.note(rec, "body not wrapped: one-line form spans lines")
         return
      if self.line_has_comment(hl):
         self.note(rec, "body not wrapped: comment on the one-line form")
         return
      stmt_first = self.T[rec.stmt_start].low
      if (not self.opts.split_exit) and stmt_first in LINT_SKIPPABLE:
         return
      last_idx = rec.semi_idx if rec.semi_idx is not None else rec.stmt_end
      if not self.is_last_on_line(last_idx):
         self.note(rec, "body not wrapped: code follows the one-line form")
         return
      if not self.is_first_on_line(rec.ctrl_idx):
         self.note(rec, "body not wrapped: code precedes the one-line form")
         return

      line = self.lines[hl]
      base = self.lx.line_starts[hl]
      head = line.raw[:T[rec.header_idx].end - base].strip()
      stmt = line.raw[T[rec.stmt_start].start - base:T[rec.stmt_end].end - base].strip()
      self.replace[hl] = [
         (line.indent, head),
         (target, "begin"),
         (target, stmt + tail),
         (target, "end" + tail),
      ]
      self.touched.add(hl)

   # -- output -------------------------------------------------------------

   def render(self):
      default_eol = "\r\n"
      for lo in self.lines:
         if lo.eol:
            default_eol = lo.eol
            break
      out = []
      for ln, lo in enumerate(self.lines):
         eol = lo.eol or default_eol
         for indent, body in self.insert_before.get(ln, []):
            out.append((" " * indent) + body + eol)
         if ln in self.replace:
            parts = self.replace[ln]
            for k, (indent, body) in enumerate(parts):
               use_eol = eol if (k < len(parts) - 1 or lo.eol) else ""
               out.append((" " * indent) + body + (use_eol if use_eol else ""))
         else:
            out.append(lo.render())
         for indent, body in self.insert_after.get(ln, []):
            out.append((" " * indent) + body + eol)
      return "".join(out)


# ---------------------------------------------------------------------------
# Top level
# ---------------------------------------------------------------------------

class Options:
   def __init__(self, split_single_line=True, split_exit=False):
      self.split_single_line = split_single_line
      self.split_exit = split_exit


def token_signature(text):
   """
   The file's significant tokens, minus exactly the punctuation this
   formatter is entitled to add: the begin/end pair, and the extra `;` that
   wrapping `Foo;` into `begin Foo; end;` creates.  Two texts with the same
   signature contain the same code.
   """
   sig = []
   for tok in Lexed(text).tokens:
      if tok.low in ("begin", "end"):
         continue
      if tok.text == ";" and sig and sig[-1] == ";":
         continue
      sig.append(tok.low)
   return sig


def format_text(text, opts=None, refusals=None):
   """Format `text` (a decoded string, EOLs intact).  Runs to a fixed point."""
   opts = opts or Options()
   cur = text
   for _ in range(MAX_PASSES):
      collected = []
      lexed = Lexed(cur)
      parser = Parser(lexed, collected)
      records = parser.parse_file()
      new = Rewriter(lexed, records, opts, collected).run()
      if refusals is not None and not refusals:
         refusals.extend(collected)
      if new == cur:
         break
      cur = new
   else:
      raise Refusal("did not converge after %d passes" % MAX_PASSES, 0)

   # Safety net: never hand back output that is not the same code.  This is
   # cheap next to the cost of silently corrupting a source file, and it is
   # what turns a formatter bug into a skipped file instead of a bad commit.
   if token_signature(text) != token_signature(cur):
      raise Refusal("internal check failed: the token stream changed", 0)
   return cur


def read_source(path):
   with open(path, "rb") as fh:
      raw = fh.read()
   bom = b""
   if raw.startswith(b"\xef\xbb\xbf"):
      bom = raw[:3]
      raw = raw[3:]
   try:
      return bom, raw.decode("utf-8"), "utf-8"
   except UnicodeDecodeError:
      return bom, raw.decode("latin-1"), "latin-1"


def write_source(path, bom, text, codec):
   with open(path, "wb") as fh:
      fh.write(bom + text.encode(codec))


def gather(paths, directory):
   files = list(paths)
   if directory:
      for root, _dirs, names in os.walk(directory):
         for name in names:
            if name.lower().endswith((".pas", ".dpr", ".inc")):
               files.append(os.path.join(root, name))
   return files


def main(argv=None):
   ap = argparse.ArgumentParser(description=__doc__.split("\n")[1],
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument("paths", nargs="*", help="Pascal files to process")
   ap.add_argument("--dir", help="walk this directory for .pas/.dpr/.inc")
   mode = ap.add_mutually_exclusive_group()
   mode.add_argument("--check", action="store_true", help="report what would change (default)")
   mode.add_argument("--apply", action="store_true", help="rewrite files in place")
   mode.add_argument("--diff", action="store_true", help="print a unified diff")
   ap.add_argument("--no-split-single-line", action="store_true",
                   help="leave `if X then Foo;` one-liners alone")
   ap.add_argument("--split-exit", action="store_true",
                   help="also split `if X then Exit;` (the lint allows it as is)")
   ap.add_argument("--verbose", action="store_true", help="list refusals")
   args = ap.parse_args(argv)

   opts = Options(split_single_line=not args.no_split_single_line,
                  split_exit=args.split_exit)

   files = gather(args.paths, args.dir)
   if not files:
      ap.error("no input files")

   changed = []
   failed = []
   for path in files:
      try:
         bom, text, codec = read_source(path)
         refusals = []
         new = format_text(text, opts, refusals)
      except (LexError, Refusal) as exc:
         failed.append((path, str(exc)))
         continue
      if new != text:
         changed.append(path)
         if args.diff:
            sys.stdout.writelines(difflib.unified_diff(
               text.splitlines(True), new.splitlines(True),
               fromfile=path, tofile=path + " (formatted)"))
         elif args.apply:
            write_source(path, bom, new, codec)
            print("formatted: %s" % path)
         else:
            print("would change: %s" % path)
      if args.verbose and refusals:
         for line, reason in refusals:
            print("  %s:%s: refused -- %s" % (path, line, reason))

   for path, why in failed:
      print("SKIPPED (unparsable): %s -- %s" % (path, why), file=sys.stderr)

   print("%d file(s) examined, %d would change, %d skipped"
         % (len(files), len(changed), len(failed)), file=sys.stderr)

   if args.apply:
      return 1 if failed else 0
   return 1 if (changed or failed) else 0


if __name__ == "__main__":
   sys.exit(main())
