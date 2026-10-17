# target/dom files not named in full.nsi, and names in full.nsi that are absent.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
nsi = open(os.path.join(ROOT, 'tr4w', 'build', 'full.nsi'), encoding='utf-8', errors='replace').read()
BS = chr(92)
pattern = 'target' + re.escape(BS) + 'dom' + re.escape(BS) + r'([^\s"]+)'
shipped = set(m.lower() for m in re.findall(pattern, nsi))
allf = sorted(os.listdir(os.path.join(ROOT, 'tr4w', 'target', 'dom')))
missing = [f for f in allf if f.lower() not in shipped]
print('in target/dom:', len(allf), ' named in full.nsi:', len(shipped))
print('NOT shipped (%d):' % len(missing), ascii(missing))
print('named but absent:', sorted(shipped - set(f.lower() for f in allf)))
