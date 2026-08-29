"""Extract TR4W's TC_ language constants into GNU gettext .po catalogues.

Usage:
   python tools/i18n/pas2po.py                    # write i18n/tr4w_<code>.po
   python tools/i18n/pas2po.py --check            # validate only, write nothing
   python tools/i18n/pas2po.py --new-lang FRA --code fr --language-name FRANCAIS
   python tools/i18n/pas2po.py --reflag-identical # re-mark copied-English

ENG is the single source of truth for the key set, the source text and the
message order. Every other language is matched BY KEY -- never by position,
because the RUS file is in a wholly different order from ENG.

The stable key is the Pascal constant name, carried in `msgctxt`. gettext
identity is (msgctxt, msgid), so an English wording fix does not orphan ten
translations. When the resourcestrings are declared this becomes FPC's own
`unitname.identifier`; the re-key is mechanical.

A translation byte-identical to the English is marked FUZZY -- "Needs work" in
Poedit. There is no way to tell "deliberately the same" from "nobody has
translated this", and the asymmetry matters: a spurious flag costs one click,
a false "done" means the string is invisible and never gets translated.
"""

import argparse
import io
import os
import re
import sys

import pasconsts as pc
import pofile


def live_resourcestrings(repo):
   """The names uTR4WStrings actually declares -- the catalogue's true scope.

   THIS FUNCTION IS THE FIX FOR A 170-STRING HOLE. Until 2026-08-27 this tool
   harvested with parse_lang_file's default prefix, TC_, because that is all the
   constants were when it was written. RC_ constants became resourcestrings in
   the binary during the cut-over, so they were live, on screen, and in NO
   catalogue in ANY language: 170 of 550 for Spanish, of which 169 already had a
   Spanish translation sitting unused in TR4W_CONSTS_ESP.PAS.

   That is how RC_WINDOWS -- the main menu's `Window` -- had no entry to fill in
   (NY4I, 2026-08-27), while 'Ventanas' sat in the language table all along.

   Scoping to the GENERATED UNIT rather than to a prefix is what stops it
   happening again: whatever pas2res emits is what a translator sees, so the two
   cannot drift. A new prefix needs no change here.
   """
   path = os.path.join(repo, "tr4w", "src", "uTR4WStrings.pas")
   with io.open(path, encoding="utf-8", errors="replace") as fh:
      text = fh.read()
   return {m.group(1).lower()
           for m in re.finditer(r"^\s{3}([A-Za-z_]\w*)\s+=", text, re.M)}


def build_catalog(lang_dir, live=None):
   files = pc.find_lang_files(lang_dir)
   if pc.SOURCE_LANG not in files:
      raise SystemExit("no %s lang file under %s" % (pc.SOURCE_LANG, lang_dir))

   # prefix="" takes every constant in the table; `live` then narrows it to the
   # ones the program actually ships. Passing a prefix here is what created the
   # hole -- see live_resourcestrings.
   def take(path):
      decls, _lines, form = pc.parse_lang_file(path, prefix="")
      if live is not None:
         decls = [d for d in decls if d.name and d.name.lower() in live]
      return decls, form

   eng_decls, _ = take(files[pc.SOURCE_LANG])
   others, lossy = {}, set()
   for lang, path in sorted(files.items()):
      decls, form = take(path)
      if form.lossy:
         lossy.add(lang)
      by_name = {}
      for d in decls:
         by_name.setdefault(d.name, d)      # first wins; --check reports dupes
      others[lang] = by_name
   return eng_decls, others, files, lossy


def same_as_english(translated, english):
   """Is the 'translation' the English wearing a hat?

   The accelerator moves or vanishes between languages, a trailing ellipsis is
   punctuation and not words, and case is not a translation."""
   def norm(s):
      return s.replace("&", "").replace("...", "").replace(u"…", "").strip().lower()
   return norm(translated) == norm(english) and norm(english) != ""


def emit(eng_decls, translations, lang, out_path, reflag_identical=False):
   """Write one .po, preserving any review decision already in the file."""
   prior = pofile.by_key(pofile.read_po(out_path))
   is_source = lang == pc.SOURCE_LANG
   seen = set()
   entries = []

   for d in eng_decls:
      seen.add(d.name)
      t = translations.get(d.name)
      notes = ["Section: %s" % d.context]
      if d.comment:
         notes.append(d.comment)
      refs = ["tr4w/src/lang/tr4w_consts_eng.pas:%d" % d.lineno]

      if is_source:
         entries.append(pofile.Entry(d.name, d.value, d.value, False,
                                     notes, refs))
         continue
      if t is None:
         entries.append(pofile.Entry(d.name, d.value, "", True, notes, refs))
         continue

      fuzzy = False
      # NOT ==. English differing only by an accelerator, an ellipsis or case is
      # still the English, and an exact test let 106 of them through as finished
      # translations -- 81 Spanish, 17 German (NY4I found one in Polish,
      # 2026-08-28: 'List of commands' translated as '&List of commands').
      # po_lint carries the same comparison for catalogues that already exist.
      if same_as_english(t.value, d.value):
         old = prior.get(d.name)
         reviewed = old is not None and not old.fuzzy and old.target == t.value
         fuzzy = reflag_identical or not reviewed
      entries.append(pofile.Entry(d.name, d.value, t.value, fuzzy, notes, refs))

   # A key present only in this language: keep it as an obsolete entry rather
   # than dropping text nobody can get back.
   for name, t in sorted(translations.items(), key=lambda kv: kv[1].lineno):
      if name in seen:
         continue
      entries.append(pofile.Entry(
         name, t.value, t.value, False,
         ["Not present in ENG; retained so nothing is lost."], [],
         obsolete=True))

   # FAIL CLOSED BEFORE WRITING.
   #
   # This tool rebuilds a catalogue from the TC_/RC_ language tables, and those
   # are not the only source the catalogues have: the Lazarus harvest
   # contributes every .lfm property and resourcestring key, which arrive
   # through po_merge and are invisible here. Rebuilding therefore DELETES them.
   #
   # Measured 2026-08-29, running this to pick up eight new strings: 2,203
   # finished native-speaker translations destroyed across ten catalogues, exit
   # code 0, no diagnostic. The obsolete-entry path above does not catch it --
   # that retains keys present in the LANGUAGE TABLE, and these were only ever
   # in the .po.
   #
   # So: adding strings to existing catalogues is po_merge's job, and this
   # refuses rather than being the tool that happens to be to hand.
   keeping = {e.key for e in entries}
   losing = sorted(k for k, e in prior.items()
                   if e.target.strip() and k not in keeping)
   if losing:
      raise SystemExit(
         "pas2po: refusing to write %s -- it would delete %d translated "
         "entr%s that are not in the language tables.\n"
         "  e.g. %s\n"
         "  These come from the Lazarus harvest (.lfm properties and "
         "resourcestrings).\n"
         "  To ADD strings to catalogues that already exist, use:\n"
         "      python tools/i18n/po_merge.py --pot tr4w/languages/tr4w_laz.pot "
         "--apply\n"
         "  pas2po is for creating a NEW language (--new-lang)."
         % (out_path, len(losing), 'y' if len(losing) == 1 else 'ies',
            ', '.join(losing[:5])))

   pofile.write_po(out_path, entries, pc.LANG_CODES[lang],
                   pc.LANG_CODES[pc.SOURCE_LANG])


def check(eng_decls, others, files):
   eng = {d.name: d for d in eng_decls}
   problems = 0

   for lang, path in sorted(files.items()):
      decls, _, _ = pc.parse_lang_file(path)
      counts = {}
      for d in decls:
         counts[d.name] = counts.get(d.name, 0) + 1
      dupes = sorted(n for n, c in counts.items() if c > 1)
      if dupes:
         problems += len(dupes)
         print("[%s] DUPLICATE KEYS (%d): %s" % (lang, len(dupes),
                                                 ", ".join(dupes)))

   print()
   print("%-5s %7s %8s %9s %10s %8s %8s"
         % ("LANG", "keys", "missing", "extra", "same-as-en", "bad-fmt",
            "edge-ws"))
   print("-" * 62)
   fmt_faults, ws_faults = [], []
   for lang in sorted(others):
      tr = others[lang]
      missing = [n for n in eng if n not in tr]
      extra = [n for n in tr if n not in eng]
      same = bad = []
      same = 0
      bad, ws = [], []
      for name, d in eng.items():
         t = tr.get(name)
         if t is None:
            continue
         if t.value == d.value:
            same += 1
         if pc.specifier_types(t.value) != pc.specifier_types(d.value):
            bad.append((name, d.value, t.value))
         if pc.edge_space(d.value) != pc.edge_space(t.value):
            ws.append((name, d.value, t.value))
      if bad:
         fmt_faults.append((lang, bad))
      if ws:
         ws_faults.append((lang, ws))
      problems += len(bad) + len(ws)
      print("%-5s %7d %8d %9d %10d %8d %8d"
            % (lang, len(tr), len(missing), len(extra), same, len(bad),
               len(ws)))

   for title, faults, why in (
         ("PLACEHOLDER MISMATCHES", fmt_faults,
          "TR4W formats through wsprintfA -- unchecked varargs, so a %d turned "
          "into %s dereferences an integer as a pointer."),
         ("EDGE-WHITESPACE MISMATCHES", ws_faults,
          "The space is a concatenation seam, so dropping it runs two words "
          "together at run time.")):
      if not faults:
         continue
      print()
      print("%s -- %s" % (title, why))
      for lang, items in faults:
         print()
         print("[%s]" % lang)
         for name, src, dst in items:
            print("    %-38s en=%r  %s=%r"
                  % (name, src[:34], lang.lower()[:2], dst[:34]))

   print()
   print("%d problem(s)." % problems)
   return 1 if problems else 0


def main(argv=None):
   for stream in (sys.stdout, sys.stderr):
      if hasattr(stream, "reconfigure"):
         stream.reconfigure(encoding="utf-8", errors="replace")

   ap = argparse.ArgumentParser(description=__doc__)
   ap.add_argument("--check", action="store_true")
   ap.add_argument("--reflag-identical", action="store_true",
                   help="re-mark every translation identical to English as "
                        "fuzzy, overriding earlier reviewer decisions")
   ap.add_argument("--new-lang", metavar="LANG")
   ap.add_argument("--code", metavar="ISO639_1",
                   help="with --new-lang: ISO 639-1 tag for the file name")
   ap.add_argument("--language-name", metavar="ENDONYM")
   args = ap.parse_args(argv)

   paths = pc.repo_paths()
   pc.load_language_registry(paths["i18n"])
   live = live_resourcestrings(paths["root"])
   eng_decls, others, files, lossy = build_catalog(paths["lang"], live)

   if args.check:
      return check(eng_decls, others, files)

   if args.new_lang:
      lang = args.new_lang.upper()
      code = pc.LANG_CODES.get(lang)
      if args.code:
         code = args.code
         pc.register_language(paths["i18n"], lang, code, args.language_name)
         print("registered %s -> %s in %s" % (lang, code,
                                              pc.LANGUAGE_REGISTRY))
      if code is None:
         print("unknown LANG %r -- pass --code with its ISO 639-1 tag" % lang,
               file=sys.stderr)
         return 2
      # A lossy language HAS a lang file and still has nothing safely
      # harvestable: its bytes decode under no declared codepage, so a blanket
      # take would emit mojibake. Treating it as new seeds the catalogue from
      # ENG -- all fuzzy, nothing invented. What DOES decode is merged in
      # afterwards by salvage_lossy.py, which is a separate, reviewable step.
      if lang in files and lang not in lossy:
         print("%s already has a lang file; use plain pas2po.py" % lang,
               file=sys.stderr)
         return 2
      out = os.path.join(paths["i18n"], "tr4w_%s.po" % code)
      done = [e for e in pofile.read_po(out) if e.translated]
      if done:
         print("%s already holds %d finished translation(s) and is the only "
               "copy -- refusing to overwrite." % (os.path.basename(out),
                                                   len(done)), file=sys.stderr)
         return 2
      emit(eng_decls, {}, lang, out)
      print("%-5s -> %-24s %4d keys, all fuzzy" % (lang, os.path.basename(out),
                                                   len(eng_decls)))
      return 0

   os.makedirs(paths["i18n"], exist_ok=True)
   for lang in sorted(files):
      code = pc.LANG_CODES.get(lang)
      if code is None:
         print("skipping unknown LANG %s" % lang, file=sys.stderr)
         continue
      if lang in lossy:
         print("%-5s SKIPPED -- decodes under no declared codepage; seed its "
               "catalogue from ENG with --new-lang %s, then salvage what "
               "decodes with salvage_lossy.py" % (lang, lang))
         continue
      out = os.path.join(paths["i18n"], "tr4w_%s.po" % code)
      emit(eng_decls, others[lang], lang, out, args.reflag_identical)
      print("%-5s -> %-24s %4d keys" % (lang, os.path.basename(out),
                                        len(others[lang])))
   print()
   print("ENG source keys: %d" % len(eng_decls))
   return 0


if __name__ == "__main__":
   sys.exit(main())
