"""Extract the config-command help text from commands_help_<lang>.ini into .po.

Usage:
   python tools/i18n/ini2po.py                 # merge the English into every i18n/help_<code>.po
   python tools/i18n/ini2po.py --check         # report drift, write nothing
   python tools/i18n/ini2po.py --new-lang JPN  # create help_ja.po, every entry empty and fuzzy

THE INIS ARE READ, NEVER WRITTEN (NY4I: they are historical artifacts, used
only to seed the .po files). And a run is a MERGE into each existing catalogue,
not a rebuild -- the .po is the master; see _merge for exactly what it may
change. `python tools/i18n/test_ini2po.py` pins it.

`tr4w/target/commands_help_<lang>.ini` is TR4W's second string catalogue: one
INI section per config command. It is the AUTHORING source; the program does
not read it. It reads the help_<code>.po this tool writes (installed as
help/help_<code>.po) through src/uCommandHelp.pas, keyed by msgctxt, and shows
the text as the tooltip of each bound Preferences control. (D7's uOption.pas
read the ini for its Ctrl-J help pane; that dialog was deleted in 4321ce1d.)

Only DESCRIPTION is translatable.

  - The SECTION NAME is the config command itself ('ALT-D CQ ENABLE'). It is the
    lookup key -- uCommandHelp.CommandHelpKey derives the same msgctxt from
    the setting's command name -- and translating it would break the lookup.
  - DEFAULT is a config VALUE: FALSE, NONE, TRUE, 0, CW, BLACK, BTNFACE, numbers.
    Verified identical across all seven shipped files; nobody has ever
    translated it, and translating FALSE would break the parser that reads it.
    It IS shown to the user (dialog item 104), so it is carried into the
    translator's note as context rather than offered for translation.

So there is exactly one translatable string per section, and the key can be
derived from the section name: TC_HELP_ALT_D_CQ_ENABLE.

A translation byte-identical to the English is emitted as `unfinished`. In these
files that is the dominant case -- whole sections were copied from English when
a language fell behind -- and it is precisely what a reviewer needs to see.
"""

import argparse
import io
import os
import re
import sys
from xml.sax.saxutils import escape, quoteattr

import pasconsts as pc
import pofile

# LANG -> the codepage to try if the file is not valid UTF-8. eng and cze are
# UTF-8 on disk; the rest are legacy single-byte. That mix is why the program
# reads the UTF-8 .po this tool writes and not the ini: D7's reader was
# GetPrivateProfileStringA, which decoded with the machine's ANSI codepage, so
# the UTF-8 Czech file (18,404 non-ASCII bytes) displayed as mojibake.
INI_CODEPAGES = {
   "ENG": "cp1252", "GER": "cp1252", "ESP": "cp1252",
   "CZE": "cp1250", "ROM": "cp1250",
   "RUS": "cp1251", "UKR": "cp1251",
}

SECTION_RE = re.compile(r"^\s*\[(?P<name>[^\]]+)\]\s*$")
KEY_RE = re.compile(r"^\s*(?P<key>[A-Za-z_]+)\s*=\s*(?P<value>.*)$")

KEY_PREFIX = "TC_HELP_"


def key_for(section):
   """TC_HELP_ + the section name, uppercased with runs of punctuation as _."""
   slug = re.sub(r"[^A-Za-z0-9]+", "_", section.strip().upper()).strip("_")
   return KEY_PREFIX + slug


def read_ini(path, lang):
   """Parse one help ini. Returns (ordered [(section, default, description)])."""
   raw = open(path, "rb").read()
   if raw.startswith(b"\xef\xbb\xbf"):
      raw = raw[3:]
   try:
      text = raw.decode("utf-8")
   except UnicodeDecodeError:
      text = raw.decode(INI_CODEPAGES.get(lang, "cp1252"), errors="replace")

   entries = []
   section = None
   fields = {}
   for line in text.replace("\r\n", "\n").split("\n"):
      m = SECTION_RE.match(line)
      if m:
         if section is not None:
            entries.append((section, fields.get("DEFAULT", ""),
                            fields.get("DESCRIPTION", "")))
         section = m.group("name").strip()
         fields = {}
         continue
      if section is None or line.lstrip().startswith(";"):
         continue          # header, blank, or an inline '; EN:' source comment
      km = KEY_RE.match(line)
      if km:
         # GetPrivateProfileString reads to end of line, so a value is exactly
         # one physical line -- no continuation handling is correct here.
         fields[km.group("key").upper()] = km.group("value").rstrip()
   if section is not None:
      entries.append((section, fields.get("DEFAULT", ""),
                      fields.get("DESCRIPTION", "")))
   return entries


def _pascal_string_list(source, name):
   """The quoted names in `NAME: array[..] of string = ( ... );` in uCFG.pas.

   A small scan rather than a regex over the block: RETIRED_COMMANDS carries
   (* *) notes with parentheses and apostrophes in them, so the list cannot
   be cut at the first ')' -- strings and comments are skipped the way the
   compiler skips them, and the list ends at the first ')' outside both.
   """
   m = re.search(r"\b%s\s*:\s*array\s*\[[^\]]*\]\s*of\s+string\s*=\s*\("
                 % re.escape(name), source, re.I)
   if not m:
      raise SystemExit("ini2po: no %s list in uCFG.pas -- the generator is "
                       "out of step with the code" % name)
   names = set()
   i = m.end()
   n = len(source)
   while i < n:
      c = source[i]
      if source.startswith("(*", i):
         i = source.index("*)", i + 2) + 2
      elif c == "{":
         i = source.index("}", i + 1) + 1
      elif source.startswith("//", i):
         i = source.find("\n", i)
         i = n if i < 0 else i
      elif c == "'":
         j = i + 1
         value = []
         while True:
            if source[j] == "'" and j + 1 < n and source[j + 1] == "'":
               value.append("'")
               j += 2
            elif source[j] == "'":
               break
            else:
               value.append(source[j])
               j += 1
         names.add("".join(value).upper())
         i = j + 1
      elif c == ")":
         return names
      else:
         i += 1
   raise SystemExit("ini2po: the %s list in uCFG.pas never closes" % name)


class CommandSet:
   """The CURRENT command vocabulary, read from the code.

   CFGCA is gone (2026-09-14). A setting is a published property of the
   settings object, so the live commands are what tools/settings_inventory.py
   derives from uSettingsModel.pas -- the same parse that writes
   tr4w/docs/SETTINGS_INVENTORY.md and is validated against the frozen
   vocabulary in uTestSettingsModel. Reused, not re-implemented.

     live       primary names: what Preferences binds and the program looks
                up help under (uCommandHelp asks by the registered name and
                resolves no alias)
     aka        second name -> primary (AlsoKnownAs), e.g. BACKUP LOG FILE
                NAME -> BACKUP DESTINATION; its old help may describe what the
                name USED to mean, so it is reported, never used
     retired    uCFG.RETIRED_COMMANDS -- accepted, logged once, ignored
     store      uCFG.OWNED_BY_A_STORE, plus the radio library's key shape
                (uCFG.CommandIsRadioLibraryKey) -- accepted, applied by a
                JSON store (radio, keyer, UDP), not the settings object

   Uppercased because the help lookup is: ini2po.key_for upper-cases, and so
   does uCommandHelp.CommandHelpKey.
   """

   def __init__(self, root):
      sys.path.insert(0, os.path.join(root, "tools"))
      import settings_inventory
      moved, _ = settings_inventory.collect()
      self.live = {m["command"].upper() for m in moved}
      self.aka = {}
      for m in moved:
         for name in (m["aka"] or "").split(","):
            if name.strip():
               self.aka[name.strip().upper()] = m["command"].upper()
      cfg = open(os.path.join(root, "tr4w", "src", "uCFG.pas"), "rb").read() \
         .decode("utf-8", errors="replace")
      self.retired = _pascal_string_list(cfg, "RETIRED_COMMANDS")
      self.store = _pascal_string_list(cfg, "OWNED_BY_A_STORE")

   def classify(self, name):
      """Why a help section that is not a live primary name exists."""
      if name in self.aka:
         return "a second name of %s" % self.aka[name]
      if name in self.retired:
         return "retired (RETIRED_COMMANDS)"
      if name in self.store:
         return "owned by a store (OWNED_BY_A_STORE)"
      # The radio library's keys are a SHAPE, not a list: the rule is
      # uCFG.CommandIsRadioLibraryKey, mirrored here for the report only.
      if (name.startswith(("RADIO ONE ", "RADIO TWO ",
                           "KEYER RADIO ONE ", "KEYER RADIO TWO "))
          or name in ("POLL RADIO ONE", "POLL RADIO TWO")):
         return "owned by a store (OWNED_BY_A_STORE)"
      return "unknown to the program"


GAPS_DOC = os.path.join("docs", "HELP_TEXT_GAPS.md")


def help_en_po_lag(i18n_dir, eng_entries):
   """[(command, state)] where i18n/help_en.po differs from the English ini.

   help_en.po is what the program loads for English; the ini is what this
   tool measures and regenerates it from. Read-only.
   """
   path = os.path.join(i18n_dir, "help_en.po")
   po = {e.key: e for e in pofile.read_po(path) if not e.obsolete}
   lag = []
   ini_keys = set()
   for section, _, desc in eng_entries:
      key = key_for(section)
      ini_keys.add(key)
      entry = po.get(key)
      if entry is None:
         lag.append((section, "in the ini, not in help_en.po"))
      elif entry.source != desc:
         lag.append((section, "the English changed in the ini since help_en.po was built"))
   for key, entry in sorted(po.items()):
      if key not in ini_keys:
         lag.append((key, "in help_en.po, no longer in the ini"))
   return sorted(lag)


def write_gaps_doc(root, commands, by_lang, eng_desc, recoverable, blank,
                   empty_desc, orphans, cmds, po_lag):
   """Write docs/HELP_TEXT_GAPS.md -- the English-help work-list.

   Three audiences in one document: the commands where another language
   already has text (so English can be written from it rather than invented),
   the ones where nothing exists anywhere, and the ones whose section exists
   with an empty DESCRIPTION -- which a translator sees as an untranslatable
   blank rather than as a gap. Plus what the program LOADS lagging what this
   file measures: help_en.po is generated from the ini, and only an ini2po run
   brings it up to date.
   """
   out = []
   w = out.append
   w("# English help text: what is missing\n")
   w("Generated by `python tools/i18n/ini2po.py --todo --write-doc`. "
     "Regenerate rather than hand-editing.\n")
   w("**Measured against `tr4w/target/commands_help_eng.ini`**, the authoring "
     "source for every help catalogue -- so a gap here is a gap in **all** "
     "languages. The program does not read the ini: Preferences shows each "
     "bound control's help as its tooltip from `help/help_<code>.po` over "
     "`help/help_en.po` (`src/uCommandHelp.pas`), which `ini2po.py` builds from "
     "it. A command with no help shows **no tooltip** -- no error. Section E "
     "lists where `i18n/help_en.po` lags the ini.\n")
   w("Counts are against the **live** command set: every command the settings "
     "object answers to, by its primary name, as `tools/settings_inventory.py` "
     "derives it from `uSettingsModel.pas` (the parse behind "
     "`tr4w/docs/SETTINGS_INVENTORY.md`). Help is looked up by the name a "
     "control is registered under, with no alias resolution; that is the "
     "primary name except for the two QUICK QSL registrations that use a "
     "second name, so a second name's section in D is otherwise unused. "
     "`uTestCommandHelp.KNOWN_HELP_GAPS` pins the subset Preferences "
     "registers.\n")
   w("| | |")
   w("|---|---|")
   w("| live config commands (settings object, primary names) | %d |"
     % len(commands))
   w("| commands with **no help section** | %d |"
     % (len(recoverable) + len(blank)))
   w("| commands whose section exists but `DESCRIPTION=` is **empty** | %d |"
     % len(empty_desc))
   w("| English sections for a name that is **not a live primary name** | %d |"
     % len(orphans))
   w("| entries where `i18n/help_en.po` **lags** the ini | %d |"
     % len(po_lag))
   w("")
   w("## A. Section missing, but another language has text (%d)\n"
     % len(recoverable))
   w("These can be written from the existing translation rather than "
     "invented. The Spanish or German text is given where available.\n")
   for cmd, have in recoverable:
      w("### `%s`\n" % cmd)
      w("Has text in: %s\n" % ", ".join(have))
      for pick in ("ESP", "GER", "RUS"):
         if pick in have:
            w("> **%s:** %s\n" % (pick, by_lang[pick][cmd].strip()))
            break
   w("## B. Section missing everywhere -- must be written (%d)\n" % len(blank))
   w("No help text exists in any language for these.\n")
   for cmd, _ in blank:
      w("- `%s`" % cmd)
   w("")
   w("## C. Section present but DESCRIPTION is empty (%d)\n" % len(empty_desc))
   w("The section exists in the English file with nothing after "
     "`DESCRIPTION=`. These are the entries a translator sees as an "
     "untranslatable blank.\n")
   for cmd in empty_desc:
      w("- `%s`" % cmd)
   w("")
   w("## D. Help for a name that is not a live primary name (%d)\n"
     % len(orphans))
   w("Informational -- **no action taken here.** These sections exist in the "
     "English file (and so are carried into every translation) for a name the "
     "settings object does not answer to by that name. Removing or renaming "
     "one is NY4I's decision: a retired name may still be in an old `.cfg`, a "
     "store-owned name has a real setting in the radio or keyer library, and a "
     "second name's text may describe what the name USED to mean.\n")
   groups = {}
   for cmd in orphans:
      why = cmds.classify(cmd)
      key = why if not why.startswith("a second name") else "a second name"
      groups.setdefault(key, []).append((cmd, why))
   for key in ("a second name", "owned by a store (OWNED_BY_A_STORE)",
               "retired (RETIRED_COMMANDS)", "unknown to the program"):
      rows = groups.get(key, [])
      w("### %s (%d)\n" % (key[0].upper() + key[1:], len(rows)))
      for cmd, why in rows:
         if key == "a second name":
            w("- `%s` -- %s" % (cmd, why))
         else:
            w("- `%s`" % cmd)
      w("")
   w("## E. `i18n/help_en.po` lags the ini (%d)\n" % len(po_lag))
   w("What the program loads, against what this document measures. Closing "
     "these is a run of `python tools/i18n/ini2po.py`, which **merges** the "
     "English into every `i18n/help_*.po` -- the `.po` is the master, nothing "
     "is lost and no fuzzy flag is cleared (see `_merge`) -- and then the "
     "`mt_seed --only` lines it prints. Not run by this report.\n")
   for cmd, state in po_lag:
      w("- `%s` -- %s" % (cmd, state))
   w("")

   path = os.path.join(root, GAPS_DOC)
   os.makedirs(os.path.dirname(path), exist_ok=True)
   # CRLF: the repo's .gitattributes treats docs as text, and the file is
   # authored on Windows -- keep it byte-stable across regenerations.
   io.open(path, "w", encoding="utf-8", newline="\r\n").write("\n".join(out))
   return path


def find_ini_files(target_dir):
   found = {}
   for entry in os.listdir(target_dir):
      m = re.match(r"^commands_help_([a-z]{3})\.ini$", entry, re.I)
      if m:
         found[m.group(1).upper()] = os.path.join(target_dir, entry)
   return found


def _note_for(section, default):
   """The '#.' note: the command name and its default are CONTEXT, not text
   to translate. Both are shown to the user; DEFAULT is a config value that
   must stay canonical."""
   note = "Config command: %s" % section
   if default:
      note += "   (default: %s)" % default
   return note


def _real(tr, desc):
   """An ini translation worth having: non-empty and not the English copied."""
   return tr is not None and tr.strip() != "" and tr != desc


def _retained_extras(translations, seen, have):
   """Sections the language's ini has and the English does not: kept as
   obsolete entries so nothing is lost. `have` is the keys already present."""
   out = []
   for section, desc in sorted(translations.items()):
      key = key_for(section)
      if key in seen or key in have:
         continue
      out.append(pofile.Entry(
         key, desc, desc, False,
         ["Section %s is not in the English file; retained so nothing is "
          "lost." % section], [], obsolete=True))
   return out


def _build_fresh(eng_entries, translations, is_source):
   """A catalogue that does not exist yet: every entry from the inis."""
   entries = []
   seen = set()
   for section, default, desc in eng_entries:
      key = key_for(section)
      seen.add(key)
      note = _note_for(section, default)
      tr = translations.get(section)
      if is_source:
         entries.append(pofile.Entry(key, desc, desc, False, [note]))
      elif _real(tr, desc):
         entries.append(pofile.Entry(key, desc, tr, False, [note]))
      else:
         entries.append(pofile.Entry(key, desc, tr or "", True, [note]))
   return entries + _retained_extras(translations, seen, set())


def _merge(prior, eng_entries, translations, is_source, today):
   """Bring an EXISTING catalogue up to the English ini. THE .po IS THE MASTER.

   WHY THIS IS A MERGE AND NOT A REBUILD (2026-11-02). emit() used to rebuild
   every catalogue from the inis alone. Measured on the first run after the
   tooltips shipped, it would have wiped 552 machine drafts held only in the
   .po files (cs 92, de 101, es 70, ro 114, ru 85, uk 90) -- fuzzy, so they
   ship -- and DEFUZZED 25 entries a reviewer had sent back on purpose
   (57170de5, the 'S&P' accelerators), because "the ini text differs from
   the English" was taken as "reviewed". The inis are historical seeds (NY4I:
   never modified, used only to seed the .po files); review state lives in
   the .po and only a human changes it.

   The rules, per entry, by key:

     unchanged English   the entry is left EXACTLY as it is (written back
                         verbatim by pofile) -- except that an EMPTY target is
                         filled from the ini when the ini has real text, and
                         then it is fuzzy.
     reworded English    the msgid is updated, the old English is kept as a
                         '#|' previous-msgid line (what msgmerge --previous
                         writes; Poedit shows the difference), and:
                           - a translation from a human (reviewed, or the
                             ini's own text) is KEPT and marked fuzzy, with a
                             dated '# ' comment -- it translates the OLD
                             English and needs a reader;
                           - a machine draft (fuzzy, not the ini's text) is
                             CLEARED, for `mt_seed --catalog help --only`.
     new key             fuzzy, from the ini when it has real text -- it was
                         never read against THIS English -- else from an
                         entry in this catalogue whose OLD English was exactly
                         this text (text that moved between commands), else
                         empty. An obsolete twin of the key is consumed.
     gone from English   kept, as obsolete. Nothing is dropped.

   The fuzzy flag is never cleared here. The source catalogue (help_en.po) is
   the English itself: msgstr = msgid, never fuzzy.

   Returns (entries, report) where report counts what changed, by kind.
   """
   live = {e.key: e for e in prior if not e.obsolete and e.key}
   obsolete = [e for e in prior if e.obsolete]
   # The translation memory: OLD English -> (key, translation), COPIED before
   # any entry below is changed -- a reworded draft is cleared in this very
   # loop, and its text may be exactly what a new key needs.
   memory = {}
   for e in prior:
      if not e.obsolete and e.target.strip() and e.source:
         memory.setdefault(e.source, (e.key, e.target))

   report = {"added": [], "added-empty": [], "reworded-kept": [],
             "reworded-cleared": [],
             "filled-from-ini": [], "to-obsolete": [], "notes": []}
   entries = []
   seen = set()
   for section, default, desc in eng_entries:
      key = key_for(section)
      seen.add(key)
      note = _note_for(section, default)
      tr = translations.get(section)
      old = live.get(key)

      if old is None:
         if is_source:
            e = pofile.Entry(key, desc, desc, False, [note])
         elif _real(tr, desc):
            e = pofile.Entry(key, desc, tr, True, [note], comments=[
               "# %s: new entry; text from the language's commands_help ini, "
               "not yet read against this English (ini2po)" % today])
         elif desc in memory:
            donor_key, donor_text = memory[desc]
            e = pofile.Entry(key, desc, donor_text, True, [note], comments=[
               "# %s: new entry; text carried from %s, whose old English was "
               "exactly this (ini2po)" % (today, donor_key)])
         else:
            e = pofile.Entry(key, desc, "", True, [note])
         obsolete = [o for o in obsolete if o.key != key]
         entries.append(e)
         report["added"].append(key)
         if not is_source and not e.target.strip():
            report["added-empty"].append(key)
         continue

      # Only the 'Config command:' note is ours to refresh (its default may
      # change). Any other '#.' note was put there by another tool or a
      # reviewer -- 57170de5's ACCELERATOR notes are -- and stays.
      notes = [note if n.startswith("Config command:") else n
               for n in old.notes]
      if not any(n.startswith("Config command:") for n in old.notes):
         notes.append(note)
      if notes != old.notes:
         old.notes = notes
         report["notes"].append(key)

      if old.source != desc:
         previous = old.source
         old.source = desc
         if is_source:
            old.target = desc
            old.fuzzy = False
         elif not old.target.strip():
            old.fuzzy = True
         elif old.fuzzy and old.target != tr:
            old.target = ""
            report["reworded-cleared"].append(key)
         else:
            old.fuzzy = True
            old.previous = ['#| msgid "%s"' % pofile.escape(previous)]
            old.comments = list(old.comments) + [
               "# %s: the English was reworded (ini2po); this translates the "
               "previous English, shown on the #| line" % today]
            report["reworded-kept"].append(key)
      elif not is_source and not old.target.strip() and _real(tr, desc):
         old.target = tr
         old.fuzzy = True
         report["filled-from-ini"].append(key)
      entries.append(old)

   for key, old in live.items():
      if key not in seen:
         old.obsolete = True
         entries.append(old)
         report["to-obsolete"].append(key)

   entries.extend(obsolete)
   have = {e.key for e in entries}
   entries.extend(_retained_extras(translations, seen, have))
   return entries, report


def emit(eng_entries, translations, lang, out_path, today=None):
   """Write one help catalogue: build it if it does not exist, otherwise
   merge the English into it without losing anything (see _merge).
   Returns the merge report, or None for a catalogue built fresh."""
   import datetime
   today = today or datetime.date.today().isoformat()
   prior = pofile.read_po(out_path)
   is_source = lang == pc.SOURCE_LANG
   if prior:
      entries, report = _merge(prior, eng_entries, translations, is_source,
                               today)
   else:
      entries, report = _build_fresh(eng_entries, translations, is_source), None
   pofile.write_po(out_path, entries, pc.LANG_CODES[lang],
                   pc.LANG_CODES[pc.SOURCE_LANG])
   return report


def main(argv=None):
   for stream in (sys.stdout, sys.stderr):
      if hasattr(stream, "reconfigure"):
         stream.reconfigure(encoding="utf-8", errors="replace")

   ap = argparse.ArgumentParser(description=__doc__)
   ap.add_argument("--check", action="store_true",
                   help="report section drift and copied-English; write nothing")
   ap.add_argument("--todo", action="store_true",
                   help="list the commands whose ENGLISH help is missing, "
                        "split by whether another language has text that can "
                        "seed it; write nothing")
   ap.add_argument("--write-doc", action="store_true",
                   help="with --todo, also write %s" % GAPS_DOC)
   ap.add_argument("--new-lang", metavar="LANG",
                   help="create help_<code>.po for a language with no "
                        "commands_help_<lang>.ini at all (ITA, FRA, NLD): "
                        "every English source, every entry fuzzy and empty")
   args = ap.parse_args(argv)

   # --write-doc on its own would fall through to the .po-writing path, which
   # REWRITES every help_<code>.po as a side effect of asking for a document.
   # That is destructive (see emit(): a translation held only in the .po is
   # replaced by an empty target), so require the read-only mode explicitly.
   if args.write_doc and not args.todo:
      raise SystemExit("--write-doc requires --todo (it is a report, not a "
                       "regeneration); run: ini2po.py --todo --write-doc")

   paths = pc.repo_paths()
   pc.load_language_registry(paths["i18n"])
   target = os.path.join(paths["root"], "tr4w", "target")
   files = find_ini_files(target)
   if pc.SOURCE_LANG not in files:
      raise SystemExit("no commands_help_eng.ini under %s" % target)

   eng_entries = read_ini(files[pc.SOURCE_LANG], pc.SOURCE_LANG)
   eng_sections = [s for s, _, _ in eng_entries]

   if args.new_lang:
      lang = args.new_lang.upper()
      code = pc.LANG_CODES.get(lang)
      if code is None:
         raise SystemExit("unknown LANG %r -- register it with "
                          "`pas2po.py --new-lang %s --code <iso639-1>`"
                          % (lang, lang))
      out = os.path.join(paths["i18n"], "help_%s.po" % code)
      done = [e for e in pofile.read_po(out) if e.translated]
      if done:
         raise SystemExit("%s already holds %d finished translation(s) -- "
                          "refusing to overwrite"
                          % (os.path.basename(out), len(done)))
      emit(eng_entries, {}, lang, out)
      print("%-5s -> %-16s %4d entries, all fuzzy"
            % (lang, os.path.basename(out), len(eng_entries)))
      print()
      print("Seed it with:  mt_seed.py --lang %s --catalog help" % lang)
      return 0

   cmds = CommandSet(paths["root"])
   commands = cmds.live
   eng_upper = {s.upper() for s in eng_sections}
   every = set()
   for lang in files:
      every |= {s.upper() for s, _, _ in read_ini(files[lang], lang)}

   print("live config commands (settings object): %d" % len(commands))
   print("ENG help sections                     : %d" % len(eng_entries))
   print("  commands with NO English help : %d  <- English must be written "
         "before these can be translated" % len(commands - eng_upper))
   print("  commands with help in NO file : %d" % len(commands - every))
   orphans = sorted(eng_upper - commands)
   if orphans:
      print("  help for a name that is not a live primary name: %d "
            "(see --todo --write-doc, section D)" % len(orphans))
   print()

   if args.todo:
      # Where English is missing but another language has text, that text can
      # seed the English rather than someone writing it from nothing.
      by_lang = {lang: {s.upper(): d for s, _, d in read_ini(files[lang], lang)}
                 for lang in files}
      recoverable, blank = [], []
      for cmd in sorted(commands - eng_upper):
         have = [l for l in sorted(by_lang)
                 if l != pc.SOURCE_LANG and by_lang[l].get(cmd, "").strip()]
         (recoverable if have else blank).append((cmd, have))
      print("ENGLISH HELP MISSING for %d command(s)."
            % (len(recoverable) + len(blank)))
      print()
      print("%d can be seeded from another language:" % len(recoverable))
      for cmd, have in recoverable:
         print("   %-42s has: %s" % (cmd, ", ".join(have)))
      print()
      print("%d have no help in any language and must be written from scratch:"
            % len(blank))
      for cmd, _ in blank:
         print("   %s" % cmd)
      if args.write_doc:
         eng_desc = {s.upper(): d for s, _, d in eng_entries}
         empty_desc = sorted(c for c in commands
                             if c in eng_desc and not eng_desc[c].strip())
         po_lag = help_en_po_lag(paths["i18n"], eng_entries)
         path = write_gaps_doc(paths["root"], commands, by_lang, eng_desc,
                               recoverable, blank, empty_desc, orphans, cmds,
                               po_lag)
         print()
         print("wrote %s" % path)
      return 0

   print("%-5s %9s %9s %9s %11s" % ("LANG", "sections", "missing", "extra",
                                    "same-as-en"))
   print("-" * 48)

   os.makedirs(paths["i18n"], exist_ok=True)
   eng_desc = {s: d for s, _, d in eng_entries}
   for lang in sorted(files):
      entries = read_ini(files[lang], lang)
      desc = {s: d for s, _, d in entries}
      missing = [s for s in eng_sections if s not in desc]
      extra = [s for s in desc if s not in eng_desc]
      same = sum(1 for s, d in desc.items()
                 if s in eng_desc and d == eng_desc[s] and d)
      print("%-5s %9d %9d %9d %11d"
            % (lang, len(entries), len(missing), len(extra), same))
   if args.check:
      return 0

   # EVERY HELP CATALOGUE, not only the seven with an ini. A language created
   # with --new-lang (fr, it, nl, pl, ...) has no ini, and until 2026-11-02 a
   # run never reached it, so a reworded or added English section never
   # arrived there. Such a catalogue merges against no translations.
   by_code = {pc.LANG_CODES[lang]: lang for lang in files}
   code_to_lang = {code: lang for lang, code in pc.LANG_CODES.items()}
   for name in sorted(os.listdir(paths["i18n"])):
      m = re.match(r"^help_(.+)\.po$", name)
      if m and m.group(1) not in by_code and m.group(1) in code_to_lang:
         by_code[m.group(1)] = code_to_lang[m.group(1)]

   print()
   print("%-6s %6s %9s %9s %8s %8s" % ("code", "added", "reworded", "drafts",
                                        "filled", "obsolete"))
   print("%-6s %6s %9s %9s %8s %8s" % ("", "", "kept-fuzzy", "cleared",
                                        "from-ini", "now"))
   cleared = {}
   for code in sorted(by_code):
      lang = by_code[code]
      desc = ({s: d for s, _, d in read_ini(files[lang], lang)}
              if lang in files else {})
      out = os.path.join(paths["i18n"], "help_%s.po" % code)
      report = emit(eng_entries, desc, lang, out)
      if report is None:
         print("%-6s built fresh" % code)
         continue
      print("%-6s %6d %9d %9d %8d %8d"
            % (code, len(report["added"]), len(report["reworded-kept"]),
               len(report["reworded-cleared"]), len(report["filled-from-ini"]),
               len(report["to-obsolete"])))
      if report["reworded-cleared"] or report["added-empty"]:
         cleared[code] = report["reworded-cleared"] + report["added-empty"]
   print()
   print("wrote i18n/help_<code>.po for %d catalogue(s)" % len(by_code))
   if cleared:
      # The machine drafts of reworded English were cleared, and new keys
      # arrived empty; seed exactly those, not every empty entry (mt_seed
      # fills every empty entry otherwise, and some catalogues are mostly
      # empty by design -- help_pl.po awaits its translator).
      print()
      print("Seed the cleared drafts and the new empty entries:")
      for code, keys in sorted(cleared.items()):
         print("   mt_seed.py --lang %s --catalog help %s"
               % (code_to_lang[code], " ".join("--only %s" % k for k in keys)))
   return 0


if __name__ == "__main__":
   sys.exit(main())
