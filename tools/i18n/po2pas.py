"""Apply translations from .po catalogues back into TR4W's lang files.

Usage:
   python tools/i18n/po2pas.py --verify    # round-trip proof; writes nothing
   python tools/i18n/po2pas.py --dry-run   # show what would change
   python tools/i18n/po2pas.py             # write the .pas files
   python tools/i18n/po2pas.py --create ITA

SURGICAL REWRITE, not regeneration: only the string expression on each TC_ line
is replaced. Indentation, the `=` alignment column, trailing `//` comments,
section banners and every neighbouring RC_ line survive untouched. Regenerating
would be wrong twice -- RC_ constants are not in the catalogue at all, and each
language file has its own declaration order, which is not ENG's.

That makes `--verify` strong: applying an unmodified catalogue must leave every
.pas BYTE-IDENTICAL.

FUZZY IS THE GATE. A fuzzy entry is never written back, so machine translation
and unreviewed edits cannot reach a build until a human clears "Needs work" in
Poedit.
"""

import argparse
import os
import sys

import pasconsts as pc
import pofile


def english_values(paths):
   eng_path = os.path.join(paths["lang"], "tr4w_consts_eng.pas")
   decls, _, _ = pc.parse_lang_file(eng_path)
   return {d.name: d.value for d in decls}


def apply_to_lang(pas_path, po_path, eng_values):
   """Returns (new_lines, form, changes, rejects, warnings). Writes nothing."""
   translations = {e.key: e.target for e in pofile.read_po(po_path)
                   if e.translated}
   decls, lines, form = pc.parse_lang_file(pas_path)

   new_lines = list(lines)
   changes, rejects, warnings = [], [], []
   for d in decls:
      if d.name not in translations:
         continue
      new_value = translations[d.name]

      # Empty means "not translated", never "set this constant to ''".
      if new_value == "":
         continue

      # A NUL-packed value would be destroyed by any tool that cannot carry
      # NUL -- and gettext cannot, since its strings are C strings. TC_TELNET
      # was unpacked for exactly this reason; the guard stays as a regression
      # check in case another packed constant appears.
      if "\x00" in d.value and "\x00" not in new_value:
         rejects.append((d, "NUL separators lost; not applied"))
         continue

      eng_text = eng_values.get(d.name, d.value)

      # wsprintfA is unchecked varargs: %d changed to %s dereferences an
      # integer as a pointer.
      want = pc.specifier_types(eng_text)
      got = pc.specifier_types(new_value)
      if want != got:
         rejects.append((d, "format specifiers %s -> %s; not applied"
                            % (want, got)))
         continue

      # Leading/trailing space on a source string is a concatenation seam.
      if pc.edge_space(eng_text) != pc.edge_space(new_value):
         warnings.append((d, "edge whitespace %r -> %r"
                             % (pc.edge_space(eng_text),
                                pc.edge_space(new_value))))
      if eng_text.count("\r") > new_value.count("\r"):
         warnings.append((d, "line break (#13) dropped"))

      rewritten = d.rewrite(new_value)
      if rewritten != d.line:
         changes.append((d, d.line, rewritten))
         new_lines[d.lineno - 1] = rewritten

   return new_lines, form, changes, rejects, warnings


def create_lang_file(lang, paths):
   """Create tr4w_consts_<lang>.pas for a language that has none yet.

   The ENG file is the template, so the new file inherits its structure,
   banners, alignment and RC_ constants. Untranslated keys keep the English
   text, so the language builds and runs from day one and shows English where
   nobody has translated -- a visible English string, not a blank UI.

   Written UTF-8 WITH A BOM: Delphi's per-file encoding mechanism IS the BOM,
   and a BOM-less non-ASCII file is decoded with the build machine's ANSI
   codepage. That is exactly how tr4w_consts_mng.pas corrupts today.
   """
   if lang in pc.DEFERRED:
      raise SystemExit(
         "%s is DEFERRED: %s\nIts catalogue is kept and still translatable, "
         "but creating the .pas is the step that puts a language into a "
         'build. Clear "deferred" in i18n/%s when the blocker is gone.'
         % (lang, pc.DEFERRED[lang], pc.LANGUAGE_REGISTRY))

   code = pc.LANG_CODES[lang]
   po_path = os.path.join(paths["i18n"], "tr4w_%s.po" % code)
   if not os.path.exists(po_path):
      raise SystemExit("no %s -- run pas2po.py --new-lang %s first"
                       % (po_path, lang))
   out_path = os.path.join(paths["lang"], "tr4w_consts_%s.pas" % lang.lower())
   if os.path.exists(out_path):
      raise SystemExit("%s already exists; use the normal apply path"
                       % out_path)

   translations = {e.key: e.target for e in pofile.read_po(po_path)
                   if e.translated}
   eng_path = os.path.join(paths["lang"], "tr4w_consts_eng.pas")
   decls, lines, form = pc.parse_lang_file(eng_path)

   new_lines = list(lines)
   applied = 0
   for d in decls:
      value = translations.get(d.name)
      if not value:
         continue
      if "\x00" in d.value and "\x00" not in value:
         print("   REJECT %s: NUL separators lost" % d.name)
         continue
      new_lines[d.lineno - 1] = d.rewrite(value)
      applied += 1

   pc.write_lang_file(out_path, new_lines,
                      pc.FileForm(True, form.newline, "utf-8"))
   print("created %s" % out_path)
   print("   %d of %d keys translated, %d left as English"
         % (applied, len(decls), len(decls) - applied))
   print()
   print("Remaining wiring (see tools/i18n/README.md):")
   print("   VC.pas         3 lines: _LANG_SET, LANG = '%s', {$INCLUDE}" % lang)
   print("   tr4w.dpr       1 line:  {$R res\\tr4w_%s.res}" % lang.lower())
   print("   res/           copy tr4w_eng.res -> tr4w_%s.res" % lang.lower())
   print("   FullBuild.ps1  add '%s' to $otherLangs and $langMap" % lang)
   return 0


def main(argv=None):
   for stream in (sys.stdout, sys.stderr):
      if hasattr(stream, "reconfigure"):
         stream.reconfigure(encoding="utf-8", errors="replace")

   ap = argparse.ArgumentParser(description=__doc__)
   mode = ap.add_mutually_exclusive_group()
   mode.add_argument("--verify", action="store_true")
   mode.add_argument("--dry-run", action="store_true")
   mode.add_argument("--create", metavar="LANG")
   ap.add_argument("--lang", help="restrict to one LANG code")
   args = ap.parse_args(argv)

   paths = pc.repo_paths()
   pc.load_language_registry(paths["i18n"])

   if args.create:
      lang = args.create.upper()
      if lang not in pc.LANG_CODES:
         print("unknown LANG %r" % lang, file=sys.stderr)
         return 2
      return create_lang_file(lang, paths)

   eng_values = english_values(paths)
   files = pc.find_lang_files(paths["lang"])
   if args.lang:
      files = {k: v for k, v in files.items() if k == args.lang.upper()}

   failures = rejected = touched = 0
   for lang, pas_path in sorted(files.items()):
      code = pc.LANG_CODES.get(lang)
      po_path = os.path.join(paths["i18n"], "tr4w_%s.po" % code)
      if not code or not os.path.exists(po_path):
         print("%-5s no .po -- skipped" % lang)
         continue

      new_lines, form, changes, rejects, warns = apply_to_lang(
         pas_path, po_path, eng_values)
      if form.lossy:
         print("%-5s SKIPPED -- decodes under no declared codepage" % lang)
         continue
      for d, why in warns:
         print("%-5s WARN   line %d %s: %s" % (lang, d.lineno, d.name, why))
      for d, why in rejects:
         rejected += 1
         print("%-5s REJECT line %d %s: %s" % (lang, d.lineno, d.name, why))

      if args.verify:
         with open(pas_path, "rb") as fh:
            before = fh.read()
         after = form.newline.join(new_lines).encode(form.encoding,
                                                     errors="surrogateescape")
         if form.has_bom:
            after = b"\xef\xbb\xbf" + after
         if before == after:
            print("%-5s OK   byte-identical" % lang)
         else:
            failures += 1
            print("%-5s DIFFERS -- %d line(s), pending edits or loss:"
                  % (lang, len(changes)))
            for d, old, new in changes[:10]:
               print("    line %d  %s" % (d.lineno, d.name))
               print("      was: %s" % old.strip())
               print("      now: %s" % new.strip())
         continue

      if args.dry_run:
         print("%-5s %d line(s) would change" % (lang, len(changes)))
         for d, old, new in changes[:20]:
            print("    line %d  %s" % (d.lineno, d.name))
            print("      was: %s" % old.strip())
            print("      now: %s" % new.strip())
         continue

      if changes:
         pc.write_lang_file(pas_path, new_lines, form)
         touched += 1
      print("%-5s %d line(s) written" % (lang, len(changes)))

   if rejected:
      print()
      print("%d key(s) REJECTED and left unchanged." % rejected)
   if args.verify:
      print()
      if failures:
         print("%d language(s) differ from their .po. If you have not edited "
               "them, that is a round-trip loss and a bug." % failures)
         return 1
      print("ROUND-TRIP CLEAN -- every .pas is byte-identical.")
      return 0
   if not args.dry_run:
      print()
      print("%d file(s) modified." % touched)
   return 1 if rejected else 0


if __name__ == "__main__":
   sys.exit(main())
