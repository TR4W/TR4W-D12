"""Propagate English help text from help_en.po to every other help catalogue.

THE PROCESS FOR A NEW COMMAND'S HELP
   1. The English sentence goes into i18n/help_en.po as the msgid (the entry is
      already there, empty, with its "#. Config command:" comment). The msgstr
      may stay empty: this copies msgid into it. A msgid that starts with
      AGENT (an owner's note, or a draft "AGENT WRITTEN: ...") is NOT final and
      is skipped everywhere; delete the prefix when the text is approved.
   2. python tools/i18n/help_add.py            # report what would change
      python tools/i18n/help_add.py --apply    # copy it into the other 21
   3. python tools/i18n/mt_seed.py --catalog help --lang X   # seed each language

WHY STEP 2 EXISTS. In i18n/help_<code>.po the English sentence is the msgid and
every catalogue carries its own copy. A command with no help yet has an EMPTY
msgid in all 22 files, so mt_seed.py (which translates the msgid it finds in the
language's own file) has nothing to work on until step 2 has run.

WHAT IT DOES, per entry in help_en.po whose msgid is non-empty: in every other
help_*.po, where that entry's msgid is EMPTY, write the English into the msgid.
The msgstr is left as it is (empty stays empty, for mt_seed.py).

WHAT IT NEVER DOES
   * touch an entry whose msgid is already non-empty (changing a msgid orphans
     its translations; a corrected English sentence is a separate decision),
   * touch msgstr, flags, comments, the header or the line endings: only the one
     msgid line of each entry is rewritten, the rest of the file is byte-identical,
   * move anything: an entry a catalogue lacks is APPENDED to its end, empty.
It is idempotent; a second run changes nothing.

   python tools/i18n/help_add.py --list      # entries with no English yet
"""

import argparse
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CATALOGUE_DIR = os.path.join(HERE, "..", "..", "i18n")

STRING = r'"(?:[^"\\\r\n]|\\.)*"'
ENTRY = re.compile(
   r'(?P<head>(?:#[^\r\n]*\r?\n)*?msgctxt "(?P<key>TC_HELP_\w+)"\r?\n)'
   r'msgid (?P<msgid>' + STRING + r'(?:\r?\n' + STRING + r')*)'
   r'(?P<mid>\r?\nmsgstr )')

COMMAND_COMMENT = re.compile(r'#\. Config command: (.*?)\s+\(default:')


def msgid_is_empty(block):
   return block.replace('"', "").replace("\r", "").replace("\n", "").strip() == ""


def key_of(name):
   """'DVK PATH' or 'TC_HELP_DVK_PATH' -> 'TC_HELP_DVK_PATH'."""
   if name.startswith("TC_HELP_"):
      return name
   return "TC_HELP_" + re.sub(r"[^A-Z0-9]+", "_", name.upper()).strip("_")


def read(path):
   with open(path, "rb") as f:
      return f.read().decode("utf-8")


def write(path, text):
   with open(path, "wb") as f:
      f.write(text.encode("utf-8"))


def is_unreviewed_note(block):
   """An owner's note ("AGENT - still used?") or a draft the agent wrote
   ("AGENT WRITTEN: ...") is NOT help text yet. It must not reach the other 21
   catalogues, where it would become a msgid and then be machine-translated.
   The owner removes the prefix when the text is final; this then lets it go."""
   return block.lstrip('"').upper().startswith("AGENT")


def english_entries(directory):
   """key -> (the '#.' comment lines, the msgid block) as written in help_en.po,
   non-empty, reviewed entries only."""
   result = {}
   for m in ENTRY.finditer(read(os.path.join(directory, "help_en.po"))):
      if (not msgid_is_empty(m.group("msgid"))
            and not is_unreviewed_note(m.group("msgid"))):
         comments = [line for line in m.group("head").splitlines()
                     if line.startswith("#.")]
         result[m.group("key")] = (comments, m.group("msgid"))
   return result


def list_missing(directory):
   count = 0
   for m in ENTRY.finditer(read(os.path.join(directory, "help_en.po"))):
      if msgid_is_empty(m.group("msgid")):
         comment = COMMAND_COMMENT.search(m.group("head"))
         print("%-40s %s" % (m.group("key"), comment.group(1) if comment else ""))
         count += 1
   print("%d entr%s with no English help" % (count, "y" if count == 1 else "ies"))


ENGLISH_ENTRY = re.compile(
   r'(?P<head>(?:#[^\r\n]*\r?\n)*?msgctxt "(?P<key>TC_HELP_\w+)"\r?\n)'
   r'msgid (?P<msgid>' + STRING + r'(?:\r?\n' + STRING + r')*)'
   r'(?P<mid>\r?\nmsgstr )(?P<msgstr>' + STRING + r'(?:\r?\n' + STRING + r')*)')


def fill_english_msgstr(path):
   """In help_en.po the msgstr is the English again. Where the msgid has reviewed
   text and the msgstr is still empty, copy the msgid into it. Returns
   (old text, new text, keys filled)."""
   text = read(path)
   filled = []

   def edit(m):
      if (msgid_is_empty(m.group("msgid")) or is_unreviewed_note(m.group("msgid"))
            or not msgid_is_empty(m.group("msgstr"))):
         return m.group(0)
      filled.append(m.group("key"))
      return (m.group("head") + "msgid " + m.group("msgid") + m.group("mid")
              + m.group("msgid"))

   return text, ENGLISH_ENTRY.sub(edit, text), filled


def remove_from(path, keys):
   """Delete the whole entry (comments, flags, msgctxt, msgid, msgstr and the
   blank line after it) for each key. Returns (old text, new text, keys removed).
   Used when a command is retired and its help must leave all 22 catalogues."""
   text = read(path)
   removed = []

   def edit(m):
      if m.group("key") not in keys:
         return m.group(0)
      removed.append(m.group("key"))
      return ""

   new = re.sub(ENGLISH_ENTRY.pattern + r'(?:\r?\n){1,2}', edit, text)
   return text, new, removed


def escape(text):
   return (text.replace("\\", "\\\\").replace('"', '\\"')
           .replace("\n", "\\n").replace("\t", "\\t"))


def update_in(path, key, text):
   """Replace the English of ONE entry. help_en.po gets the text as msgid and
   msgstr. Every other catalogue gets it as the msgid, KEEPS its msgstr and is
   flagged fuzzy, because that translation now answers an older sentence and a
   reviewer must look. Returns (old text, new text, whether the entry was found)."""
   text_old = read(path)
   is_english = os.path.basename(path) == "help_en.po"
   found = []

   def edit(m):
      if m.group("key") != key:
         return m.group(0)
      found.append(key)
      newline = "\r\n" if "\r\n" in m.group(0) else "\n"
      head = m.group("head")
      if is_english:
         head = re.sub(r"#, fuzzy\r?\n", "", head)
      elif "#, fuzzy" not in head:
         head = head.replace('msgctxt "', "#, fuzzy" + newline + 'msgctxt "', 1)
      body = '"%s"' % escape(text)
      msgstr = body if is_english else m.group("msgstr")
      return head + "msgid " + body + m.group("mid") + msgstr

   new = ENGLISH_ENTRY.sub(edit, text_old)
   return text_old, new, bool(found)


def propagate_into(path, english):
   """Return (new text, keys filled, keys English has that this file lacks)."""
   text = read(path)
   filled = []
   present = set()

   def edit(m):
      key = m.group("key")
      present.add(key)
      if key not in english or not msgid_is_empty(m.group("msgid")):
         return m.group(0)
      filled.append(key)
      return m.group("head") + "msgid " + english[key][1] + m.group("mid")

   new = ENTRY.sub(edit, text)
   absent = sorted(set(english) - present)
   if absent:
      # A command help_en.po has and this catalogue has never heard of: append
      # the entry, empty, for mt_seed.py. Appended, never inserted, so nothing
      # already in the file moves.
      newline = "\r\n" if "\r\n" in text else "\n"
      if not new.endswith(newline):
         new += newline
      for key in absent:
         comments, msgid = english[key]
         msgid = msgid.replace("\r\n", "\n").replace("\n", newline)
         block = comments + ['msgctxt "%s"' % key, "msgid " + msgid,
                             "msgstr \"\""]
         new += newline.join(block) + newline + newline
   return text, new, filled, absent


def main():
   parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
   parser.add_argument("--apply", action="store_true", help="write the files")
   parser.add_argument("--list", action="store_true",
                       help="list entries whose English help is empty")
   parser.add_argument("--dir", help="catalogue directory (default: i18n/); for tests")
   parser.add_argument("--remove", nargs="+", metavar="COMMAND",
                       help="delete these commands' entries from ALL help catalogues "
                            "(a retired command); a name or a TC_HELP_ key")
   parser.add_argument("--update", nargs=2, metavar=("COMMAND", "TEXT"),
                       help="replace the English of one command in ALL help "
                            "catalogues; other languages keep their translation, "
                            "marked fuzzy")
   args = parser.parse_args()
   directory = args.dir or CATALOGUE_DIR

   if args.update:
      key = key_of(args.update[0])
      changed = 0
      for path in sorted(glob.glob(os.path.join(directory, "help_*.po"))):
         old, new, found = update_in(path, key, args.update[1])
         if found:
            changed += 1
            if args.apply:
               write(path, new)
         else:
            print("%s: no entry for %s" % (os.path.basename(path), key))
      print("%d catalogue(s) %s" % (changed,
                                    "UPDATED" if args.apply else "would change (no --apply)"))
      return 0

   if args.remove:
      keys = set(key_of(name) for name in args.remove)
      total = 0
      for path in sorted(glob.glob(os.path.join(directory, "help_*.po"))):
         old, new, removed = remove_from(path, keys)
         total += len(removed)
         if args.apply and new != old:
            write(path, new)
      print("%d entr%s %s" % (total, "y" if total == 1 else "ies",
                              "REMOVED" if args.apply else "would be removed (no --apply)"))
      return 0

   if args.list:
      list_missing(directory)
      return 0

   # Step 1: help_en.po's own msgstr, copied from its msgid where still empty.
   en_path = os.path.join(directory, "help_en.po")
   old, new, en_filled = fill_english_msgstr(en_path)
   if en_filled:
      print("help_en.po: msgstr set from msgid for %s" % ", ".join(en_filled))
      if args.apply:
         write(en_path, new)

   # Step 2: the other catalogues. (Read AFTER step 1 so --apply sees the file.)
   english = english_entries(directory)
   problems = 0
   total = 0
   paths = [p for p in sorted(glob.glob(os.path.join(directory, "help_*.po")))
            if os.path.basename(p) != "help_en.po"]
   for path in paths:
      old, new, filled, absent = propagate_into(path, english)
      total += len(filled)
      if absent:
         print("%s: %s added (empty)" % (os.path.basename(path), ", ".join(absent)))
      if args.apply and new != old:
         write(path, new)
   print("%d catalogue(s); %d msgid(s) %s" % (
      len(paths), total, "WRITTEN" if args.apply else "to write (no --apply)"))
   return 1 if problems else 0


if __name__ == "__main__":
   sys.exit(main())
