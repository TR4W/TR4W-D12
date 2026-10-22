# Which target/dom files does full.nsi package?  Imported by dom-shipped.py and
# dom-includes.py so there is ONE reader of the installer's File lines.
# (GitHub issue #90; the PowerShell scripts use NsiDom.ps1, the same rule.)
#
# Two forms of File line name a dom file:
#   File ..\target\dom\x.dom     one file, by name
#   File ..\target\dom\*.*       a wildcard: EVERY file in that directory
#                                (since 8b3d3e9a the installer ships the folder)
# A wildcard is expanded against the directory on disk.  Before this, a
# wildcard was read as one "file" named '*.*'.
import fnmatch
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
DOM_DIR = os.path.join(ROOT, 'tr4w', 'target', 'dom')
NSI = os.path.join(ROOT, 'tr4w', 'build', 'full.nsi')

# 'target\dom\<leaf>' as written in a File line (a comment line is skipped).
_LEAF = re.compile(r'target\\dom\\([^\s"]+)', re.IGNORECASE)


def shipped_names():
   """Lower-cased leaf names full.nsi packages from target/dom."""
   on_disk = os.listdir(DOM_DIR)
   shipped = set()
   with open(NSI, encoding='utf-8', errors='replace') as nsi:
      for line in nsi:
         if line.lstrip().startswith(';'):
            continue
         for leaf in _LEAF.findall(line):
            if '*' in leaf or '?' in leaf:
               # Windows rule NSIS relies on: '*.*' matches every file,
               # dotless names included, which fnmatch's '*.*' would not.
               pattern = '*' if leaf == '*.*' else leaf
               for name in on_disk:
                  if fnmatch.fnmatch(name.lower(), pattern.lower()):
                     shipped.add(name.lower())
            else:
               shipped.add(leaf.lower())
   return shipped
