"""Mark catalogue entries obsolete when their key no longer exists in the source.

A .po drifts from the code. A constant is renamed or deleted and its entry stays
behind, still carrying a translation, looking live. Measured 2026-08-26 across
tr4w_es.po: 35 of 416 live entries named a TC_ constant the English table does
not have, and none of the 35 was referenced anywhere in the program.

WHAT THIS DOES NOT DO IS DELETE THEM. gettext keeps an obsolete entry in the
file as `#~`, translation intact; Poedit hides it, msgfmt ignores it, and it
comes back the moment the key returns. ~417 of these strings are native-speaker
work (NY4I: "we do not want to re-translate already completed items"), so
discarding one to tidy a file is a bad trade at any ratio. Marking is
reversible; deleting is not.

WHAT COUNTS AS "IN THE SOURCE" is every declaration the program can actually
reach:

  * src/lang/tr4w_consts_eng.pas   -- the legacy TC_/RC_ tables
  * any `resourcestring` in src/  -- where user-facing text is moving

The second half matters and is easy to forget. When a string moves from the
language table into a resourcestring unit it is still perfectly live; a check
that only read the tables would mark it obsolete and quietly retire sixteen
translations at exactly the moment the migration touched it.

Usage
-----
  python tools/i18n/po_prune.py --repo C:/tr4w-d12              # dry run
  python tools/i18n/po_prune.py --repo C:/tr4w-d12 --apply
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile


def source_keys(repo):
   """Every TC_/RC_ name the program declares, from either mechanism."""
   src = os.path.join(repo, "tr4w", "src")
   keys = set()

   eng = os.path.join(src, "lang", "tr4w_consts_eng.pas")
   if os.path.exists(eng):
      with open(eng, encoding="utf-8", errors="replace") as fh:
         for m in re.finditer(r"^\s*((?:TC|RC)_\w+)\s*(?::|=)", fh.read(), re.M):
            keys.add(m.group(1).upper())

   # resourcestring blocks anywhere under src. Walk by extension, not glob:
   # src/trdos is UPPERCASE .PAS and a case-sensitive pattern misses 27 files.
   for dirpath, _dirnames, filenames in os.walk(src):
      for fn in filenames:
         if not fn.lower().endswith((".pas", ".inc")):
            continue
         with open(os.path.join(dirpath, fn), encoding="utf-8", errors="replace") as fh:
            keys.update(resourcestring_names(fh.read()))
   return keys


# Section keywords that END a resourcestring block. Matched only as the FIRST
# TOKEN OF A LINE, never anywhere in the text.
#
# The first version of this searched for the words themselves, and a comment
# INSIDE the block reading "`resourcestring`, not `const`" ended it before its
# first declaration -- so all 95 migrated strings read as absent from the
# source, which would have marked their catalogue entries obsolete. Exactly the
# failure this module exists to prevent, produced by the module itself.
_ENDS = ("const", "type", "var", "function", "procedure", "constructor",
         "destructor", "implementation", "initialization", "finalization",
         "begin", "end")


def resourcestring_names(text):
   """TC_/RC_ names declared in `resourcestring` blocks. Line-oriented, like
   pasconsts, because that is what survives comments."""
   names = set()
   inblock = False
   incomment = False
   for raw in text.splitlines():
      line = raw
      if incomment:
         if "}" in line:
            line = line.split("}", 1)[1]
            incomment = False
         else:
            continue
      while "{" in line:
         before, rest = line.split("{", 1)
         if "}" in rest:
            line = before + " " + rest.split("}", 1)[1]
         else:
            line = before
            incomment = True
            break
      line = line.split("//", 1)[0]
      token = line.strip().lower()
      if not token:
         continue
      first = re.split(r"[^a-z]", token, 1)[0]
      if first == "resourcestring":
         inblock = True
         continue
      if first in _ENDS:
         inblock = False
         continue
      if inblock:
         m = re.match(r"\s*((?:TC|RC)_\w+)\s*=", line, re.I)
         if m:
            names.add(m.group(1).upper())
   return names


def prune(path, live, apply_changes):
   entries = pofile.read_po(path)
   marked = []
   for e in entries:
      if e.obsolete or not e.key:
         continue
      if e.key.upper() not in live:
         e.obsolete = True
         marked.append(e.key)
   if apply_changes and marked:
      lang = os.path.basename(path).rsplit("_", 1)[-1].replace(".po", "")
      pofile.write_po(path, entries, lang)
   return marked


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument("--repo", required=True, help="repo root holding tr4w/src")
   ap.add_argument("--apply", action="store_true", help="write the files")
   ap.add_argument("--dir", default=None, help="the i18n directory")
   args = ap.parse_args()

   here = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   i18n = args.dir or os.path.join(here, "i18n")

   live = source_keys(args.repo)
   print("  %d TC_/RC_ names declared in the source" % len(live))

   files = sorted(f for f in os.listdir(i18n)
                  if f.lower().startswith("tr4w_") and f.lower().endswith(".po"))
   total = 0
   sample = None
   for f in files:
      marked = prune(os.path.join(i18n, f), live, args.apply)
      total += len(marked)
      if sample is None and marked:
         sample = marked
      print("  %-16s %3d marked obsolete" % (f, len(marked)))

   if sample:
      print("\n  e.g. " + ", ".join(sorted(sample)[:6]))
   print("\n%d entry/entries %s across %d file(s)"
         % (total, "marked" if args.apply else "would be marked", len(files)))
   if not args.apply:
      print("Dry run -- nothing written. Re-run with --apply.")
   return 0


if __name__ == "__main__":
   sys.exit(main())
