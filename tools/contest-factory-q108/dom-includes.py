# Shipped .dom files whose INCLUDE FILE names a file that is missing or not shipped.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
DOM = os.path.join(ROOT, 'tr4w', 'target', 'dom')
nsi = open(os.path.join(ROOT, 'tr4w', 'build', 'full.nsi'), encoding='utf-8', errors='replace').read()
BS = chr(92)
shipped = set(m.lower() for m in re.findall('target' + re.escape(BS) + 'dom' + re.escape(BS) + r'([^\s"]+)', nsi))
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
