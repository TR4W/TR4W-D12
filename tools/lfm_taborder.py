"""Tab order of a designed form against its reading order.

WHY THIS EXISTS. An .lfm stores a TabOrder per windowed control, and nothing
ties that number to where the control sits.  The Preferences window shipped
with Tab jumping Server -> This station -> a checkbox -> Port on its Network
page (NY4I, 2026-11-02), and no lint, compiler or unit test could see it,
because every value was individually legal.  The numbers were the order the
controls were CREATED in; the controls had been moved since.

THE RULE APPLIED.  Within one parent, the windowed children (the objects that
carry a TabOrder line -- a TLabel has none and takes no Tab stop) are read the
way the page reads:

   * into ROWS: a control joins the current row when its Top is within
     ROW_SLACK pixels of the row's first control.  A label and its edit box
     are one row although their tops differ by 4; a list box with stacked
     buttons beside it reads list, first button, second button, ...
   * rows top to bottom, and within a row left to right.
   * two controls at the SAME position (stacked alternatives, or the page
     panels of a navigation form, all at 0,0) keep their existing order.

COLUMNS ARE DECLARED, NOT GUESSED.  A page that reads down a left column and
then a right one (two headings side by side, or a sidebar beside a content
area) is named in the config file with the x at which the columns split.  The
lint still judges it -- column by column -- so a declared page stays gated.

Anchored children are judged by the Left/Top the designer wrote, which the LCL
writes for every control.  A parent with an ALIGNED child (Align other than
alNone) is skipped: its written position is not where it is drawn.

USAGE
   python tools/lfm_taborder.py report <file.lfm>...     every parent, before/after
   python tools/lfm_taborder.py check  <file.lfm>...     exit 1 on a disagreement
   python tools/lfm_taborder.py fix    <file.lfm>...     rewrite TabOrder in place

   --config <file>   lines of
                        columns <form>.lfm:<parent> <x>[,<x>...]
                        allow   <form>.lfm:<parent>      # why
                     An 'allow' entry excuses a parent from check (the ratchet
                     for forms not yet fixed).  A stale one -- the parent now
                     agrees, or no longer exists -- FAILS, so the list only
                     shrinks.

fix renumbers ONLY a parent whose order disagrees, 0..n-1 in reading order, and
touches no other line.  The file's BOM and newlines are preserved (srcfile).
A file that does not parse, or a check over zero files, fails.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from srcfile import read, write   # noqa: E402

ROW_SLACK = 8

OBJ_RE = re.compile(r'^(\s*)(object|inherited|inline)\s+(\w*)\s*:\s*(\w+)')
PROP_RE = re.compile(r'^(\s*)(Left|Top|Width|Height|TabOrder|Align|Tag)\s*=\s*(\S+)\s*$')


class Node(object):
   def __init__(self, name, cls, indent, parent):
      self.name = name
      self.cls = cls
      self.indent = indent
      self.parent = parent
      self.children = []
      self.props = {}
      self.tab_line = None      # index into the file's lines

   def num(self, key, default=0):
      try:
         return int(self.props.get(key, default))
      except ValueError:
         return default


def parse(lines):
   """The object tree.  Collection items (item ... end) are tracked so their
   'end' does not close an object, and only property lines at an object's own
   property indent are read."""
   root = None
   stack = []           # Node, or the string 'item'
   for i, raw in enumerate(lines):
      line = raw.rstrip('\r\n')
      m = OBJ_RE.match(line)
      if m:
         parent = None
         for frame in reversed(stack):
            if isinstance(frame, Node):
               parent = frame
               break
         node = Node(m.group(3), m.group(4), len(m.group(1)), parent)
         if parent is not None:
            parent.children.append(node)
         elif root is None:
            root = node
         stack.append(node)
         continue
      stripped = line.strip()
      if stripped == 'item':
         stack.append('item')
         continue
      if stripped in ('end', 'end>'):
         if stack:
            stack.pop()
         continue
      if stack and isinstance(stack[-1], Node):
         node = stack[-1]
         p = PROP_RE.match(line)
         if p and len(p.group(1)) == node.indent + 2:
            node.props[p.group(2)] = p.group(3)
            if p.group(2) == 'TabOrder':
               node.tab_line = i
   return root


def tab_children(node):
   return [c for c in node.children if c.tab_line is not None]


def row_order(kids):
   """Rows by Top (within ROW_SLACK of the row's first), then Left; ties keep
   the existing TabOrder."""
   by_top = sorted(kids, key=lambda c: (c.num('Top'), c.num('Left'), c.num('TabOrder')))
   rows = []
   for c in by_top:
      if rows and abs(c.num('Top') - rows[-1][0].num('Top')) <= ROW_SLACK:
         rows[-1].append(c)
      else:
         rows.append([c])
   result = []
   for row in rows:
      result.extend(sorted(row, key=lambda c: (c.num('Left'), c.num('Top'), c.num('TabOrder'))))
   return result


def reading_order(kids, splits):
   """Column by column (a control belongs to the column its Left falls in),
   and in reading order within each."""
   if not splits:
      return row_order(kids)
   edges = sorted(splits)
   columns = [[] for _ in range(len(edges) + 1)]
   for c in kids:
      col = sum(1 for x in edges if c.num('Left') >= x)
      columns[col].append(c)
   result = []
   for col in columns:
      result.extend(row_order(col))
   return result


def walk(node):
   yield node
   for c in node.children:
      for n in walk(c):
         yield n


def judged_parents(root, base, columns):
   """(parent, current order, reading order) for each parent with 2+ stops."""
   out = []
   for node in walk(root):
      kids = tab_children(node)
      if len(kids) < 2:
         continue
      if any(c.props.get('Align', 'alNone') != 'alNone' for c in kids):
         continue
      current = sorted(kids, key=lambda c: c.num('TabOrder'))
      splits = columns.get('%s:%s' % (base, node.name), [])
      out.append((node, current, reading_order(kids, splits)))
   return out


def names(seq):
   return ', '.join('%s(%d)' % (c.name, c.num('TabOrder')) for c in seq)


def load_config(path):
   """(columns: key -> [x...], allow: set of key)."""
   columns = {}
   allow = set()
   if not path:
      return columns, allow
   for n, raw in enumerate(read(path).splitlines(), 1):
      s = raw.split('#', 1)[0].strip()
      if not s:
         continue
      parts = s.split()
      if parts[0] == 'columns' and len(parts) == 3:
         columns[parts[1]] = [int(x) for x in parts[2].split(',')]
      elif parts[0] == 'allow' and len(parts) == 2:
         allow.add(parts[1])
      else:
         raise SystemExit('%s:%d: not understood: %s' % (path, n, raw))
   return columns, allow


def main(argv):
   if len(argv) < 2:
      print(__doc__)
      return 2
   mode = argv[0]
   if mode not in ('report', 'check', 'fix'):
      print(__doc__)
      return 2
   files = []
   config_path = None
   it = iter(argv[1:])
   for a in it:
      if a == '--config':
         config_path = next(it)
      else:
         files.append(a)
   columns, allow = load_config(config_path)
   seen = set()
   failures = 0

   if not files:
      print('Lint-TabOrder: no .lfm files given')
      return 1

   for path in files:
      text = read(path)
      lines = text.splitlines(True)
      root = parse(lines)
      if root is None:
         print('Lint-TabOrder: cannot parse ' + path)
         failures += 1
         continue
      base = os.path.basename(path)
      changed = False
      for parent, current, wanted in judged_parents(root, base, columns):
         key = '%s:%s' % (base, parent.name)
         seen.add(key)
         ok = [c.name for c in current] == [c.name for c in wanted]
         if mode == 'report':
            label = parent.name
            if 'Tag' in parent.props:
               label += ' (Tag %s)' % parent.props['Tag']
            print('%s %s:%s' % ('ok  ' if ok else 'BAD ', base, label))
            if not ok:
               print('   before: ' + names(current))
               print('   after:  ' + ', '.join(c.name for c in wanted))
         elif mode == 'check':
            if key in allow:
               if ok:
                  print('STALE allow entry (now agrees -- delete it): ' + key)
                  failures += 1
            elif not ok:
               print('TabOrder disagrees with reading order: ' + key)
               print('   now:    ' + ', '.join(c.name for c in current))
               print('   reads:  ' + ', '.join(c.name for c in wanted))
               failures += 1
         elif mode == 'fix' and not ok:
            for n, c in enumerate(wanted):
               old = lines[c.tab_line]
               body = old.rstrip('\r\n')
               eol = old[len(body):]
               lines[c.tab_line] = re.sub(r'=\s*\S+\s*$', '= %d' % n, body) + eol
            changed = True
            print('fixed ' + key)
      if mode == 'fix' and changed:
         write(path, ''.join(lines))

   if mode == 'check':
      for key in sorted((allow | set(columns)) - seen):
         print('STALE config entry (no such parent judged): ' + key)
         failures += 1
      print('Lint-TabOrder: %d problem(s) in %d file(s), %d allowed'
            % (failures, len(files), len(allow)))
   return 1 if failures else 0


if __name__ == '__main__':
   sys.exit(main(sys.argv[1:]))
