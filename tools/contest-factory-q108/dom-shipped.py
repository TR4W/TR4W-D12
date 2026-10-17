# target/dom files not named in full.nsi, and names in full.nsi that are absent.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# "Named" comes from nsi_dom.py: a wildcard File line (the installer ships
# File ..\target\dom\*.*) counts as every file in the folder.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nsi_dom

shipped = nsi_dom.shipped_names()
allf = sorted(os.listdir(nsi_dom.DOM_DIR))
missing = [f for f in allf if f.lower() not in shipped]
print('in target/dom:', len(allf), ' packaged by full.nsi:', len(shipped))
print('NOT shipped (%d):' % len(missing), ascii(missing))
print('named but absent:', sorted(shipped - set(f.lower() for f in allf)))
