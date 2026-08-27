"""Extract the config-command help text from commands_help_<lang>.ini into .po.

Usage:
   python tools/i18n/ini2po.py                 # write i18n/help_<code>.po
   python tools/i18n/ini2po.py --check         # report drift, write nothing

`tr4w/target/commands_help_<lang>.ini` is TR4W's second string catalogue: one
INI section per config command, read at run time by uOption.pas:842 to fill the
help pane of the settings dialog.

Only DESCRIPTION is translatable.

  - The SECTION NAME is the config command itself ('ALT-D CQ ENABLE'). It is the
    lookup key -- uOption.pas takes it from the ListView's COMMAND_FIELD -- and
    translating it would break the lookup.
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
# UTF-8 on disk; the rest are legacy single-byte. Note that the runtime reader
# is GetPrivateProfileStringA, which decodes with the machine's ANSI codepage --
# so a UTF-8 file with non-ASCII content (cze: 18,404 such bytes) is ALREADY
# being displayed as mojibake. Recorded here, not fixed here.
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


def config_commands(root):
   """The live command set, from uCFG.pas's CFGCA array.

   The help files are NOT the authority and neither is the English one: the
   Czech and Russian files carry sections English lacks (ADD DOMESTIC COUNTRY
   is a live command in CFGCA but has no English entry). Compare against the
   code instead.

   Two classes of row are NOT live and must not be counted as help gaps:

     * `crS: csRem` -- retired. Still recognized so old .CFG files do not
       error, but CheckCommand exits early without applying the value and the
       row is hidden from the Options dialog. A user can never see its help.
     * a row commented out with `//`. Not compiled at all.

   The two overlap but are not the same set: some csRem rows are still
   compiled in, and some commented-out rows are marked csOld rather than
   csRem. Both must be excluded independently.

   crS is compared case-insensitively because Pascal is -- CFGCA spells the
   same value csOld, csOLD and csoLD, and a case-sensitive test silently
   misfiles those rows.

   Uppercased because Windows INI section lookup is case-insensitive, so
   'EXTERNAl LOGGER' really does resolve to the EXTERNAL LOGGER command.
   """
   path = os.path.join(root, "tr4w", "src", "uCFG.pas")
   raw = open(path, "rb").read().decode("utf-8", errors="replace")
   live = set()
   for line in raw.splitlines():
      m = re.search(r"crCommand:\s*'([^']+)'", line)
      if not m:
         continue
      # `//` anywhere ahead of the row comments the whole row out. CFGCA is
      # one record per physical line, so no comment-state machine is needed.
      if "//" in line[:m.start()]:
         continue
      status = re.search(r"crS:\s*(\w+)", line)
      if status and status.group(1).upper() == "CSREM":
         continue
      live.add(m.group(1).upper())
   return live


GAPS_DOC = os.path.join("docs", "HELP_TEXT_GAPS.md")


def write_gaps_doc(root, commands, by_lang, eng_desc, recoverable, blank,
                   empty_desc, orphans):
   """Write docs/HELP_TEXT_GAPS.md -- the English-help work-list.

   Three audiences in one document: the commands where another language
   already has text (so English can be written from it rather than invented),
   the ones where nothing exists anywhere, and the ones whose section exists
   with an empty DESCRIPTION -- which a translator sees as an untranslatable
   blank rather than as a gap.
   """
   out = []
   w = out.append
   w("# English help text: what is missing\n")
   w("Generated by `python tools/i18n/ini2po.py --todo --write-doc`. "
     "Regenerate rather than hand-editing.\n")
   w("`tr4w/target/commands_help_eng.ini` is the source for every translated "
     "help catalogue, so a gap here is a gap in **all** languages. "
     "`uOption.pas:842` reads it with `GetPrivateProfileStringA` and a NULL "
     "default, so a missing section shows the user a **blank help pane** -- no "
     "error, no fallback.\n")
   w("Counts are against the **live** command set only. A `CFGCA` row that is "
     "commented out, or marked `crS: csRem`, is deprecated: `CheckCommand` "
     "exits early without applying it and the Options dialog hides it, so the "
     "user can never reach its help. Those rows are not gaps and are excluded "
     "here.\n")
   w("| | |")
   w("|---|---|")
   w("| live config commands (`uCFG.pas` `CFGCA`) | %d |" % len(commands))
   w("| commands with **no help section** | %d |"
     % (len(recoverable) + len(blank)))
   w("| commands whose section exists but `DESCRIPTION=` is **empty** | %d |"
     % len(empty_desc))
   w("| English sections for a command that is **not live** | %d |"
     % len(orphans))
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
   w("## D. Help for a command that is not live (%d)\n" % len(orphans))
   w("Informational -- **no action taken here.** These sections exist in the "
     "English file (and so are carried into every translation) for a command "
     "that is commented out, `csRem`, or absent from `CFGCA` entirely. They "
     "are dead weight being handed to translators, but removing them is a "
     "separate decision: some are deprecated-but-recognized commands a user "
     "may still have in an old `.CFG`.\n")
   for cmd in orphans:
      w("- `%s`" % cmd)
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


def emit(eng_entries, translations, lang, out_path):
   """Write one help catalogue. Preserves any review decision already there."""
   prior = pofile.by_key(pofile.read_po(out_path))
   is_source = lang == pc.SOURCE_LANG
   entries = []
   seen = set()

   for section, default, desc in eng_entries:
      key = key_for(section)
      seen.add(key)
      # The command name and its default are CONTEXT, not text to translate.
      # Both are shown in the settings dialog; DEFAULT is a config value that
      # must stay canonical.
      note = "Config command: %s" % section
      if default:
         note += "   (default: %s)" % default
      tr = translations.get(section)

      if is_source:
         entries.append(pofile.Entry(key, desc, desc, False, [note]))
         continue
      if tr is None or not tr.strip():
         entries.append(pofile.Entry(key, desc, "", True, [note]))
         continue
      fuzzy = False
      if tr == desc:
         old = prior.get(key)
         fuzzy = not (old is not None and not old.fuzzy and old.target == tr)
      entries.append(pofile.Entry(key, desc, tr, fuzzy, [note]))

   for section, desc in sorted(translations.items()):
      if key_for(section) in seen:
         continue
      entries.append(pofile.Entry(
         key_for(section), desc, desc, False,
         ["Section %s is not in the English file; retained so nothing is "
          "lost." % section], [], obsolete=True))

   pofile.write_po(out_path, entries, pc.LANG_CODES[lang],
                   pc.LANG_CODES[pc.SOURCE_LANG])


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

   commands = config_commands(paths["root"])
   eng_upper = {s.upper() for s in eng_sections}
   every = set()
   for lang in files:
      every |= {s.upper() for s, _, _ in read_ini(files[lang], lang)}

   print("live config commands (uCFG.pas CFGCA): %d" % len(commands))
   print("ENG help sections                    : %d" % len(eng_entries))
   print("  commands with NO English help : %d  <- English must be written "
         "before these can be translated" % len(commands - eng_upper))
   print("  commands with help in NO file : %d" % len(commands - every))
   orphans = sorted(eng_upper - commands)
   if orphans:
      print("  help for a command that is not live (commented out, csRem, or "
            "absent from CFGCA): %s" % ", ".join(orphans))
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
         path = write_gaps_doc(paths["root"], commands, by_lang, eng_desc,
                               recoverable, blank, empty_desc, orphans)
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
      if not args.check:
         out = os.path.join(paths["i18n"], "help_%s.po" % pc.LANG_CODES[lang])
         emit(eng_entries, desc, lang, out)

   if not args.check:
      print()
      print("wrote i18n/help_<code>.po for %d language(s)" % len(files))
   return 0


if __name__ == "__main__":
   sys.exit(main())
