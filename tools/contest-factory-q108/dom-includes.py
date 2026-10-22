# Shipped .dom files whose INCLUDE FILE names a file that is missing or not shipped.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# "Shipped" comes from nsi_dom.py, which expands full.nsi's dom wildcard.
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nsi_dom

DOM = nsi_dom.DOM_DIR
shipped = nsi_dom.shipped_names()
present = set(f.lower() for f in os.listdir(DOM))
problems = 0
for f in sorted(os.listdir(DOM)):
   try:
      text = open(os.path.join(DOM, f), encoding='latin-1').read()
   except OSError:
      continue
   for inc in re.findall(r'(?im)^\s*include\s*file\s*=?\s*(\S+)', text):
      name = inc.lower()
      state = []
      if name not in present:
         state.append('MISSING FROM target/dom')
      if name not in shipped:
         state.append('NOT SHIPPED')
      if state and f.lower() in shipped:
         problems += 1
         print('%-20s includes %-16s %s' % (f, inc, ', '.join(state)))
print('shipped dom files including an unshipped/missing file: %d' % problems)
