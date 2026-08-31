"""Seed a .po catalogue with machine translation from a local LibreTranslate.

Usage:
   python tools/i18n/mt_seed.py --lang ITA
   python tools/i18n/mt_seed.py --lang ITA --dry-run
   python tools/i18n/mt_seed.py --lang ALL --fix-spacing
   python tools/i18n/mt_seed.py --lang ITA --catalog help

A STARTING POINT FOR A REVIEWER, never a finished translation. Three properties
enforce that:

  1. Every seeded string stays FUZZY -- "Needs work" in Poedit. po2pas.py skips
     fuzzy entries, so machine output cannot reach a .pas or a build until a
     human clears the flag.
  2. Format specifiers are validated against the English and the string is
     DROPPED rather than seeded on mismatch. TR4W formats through wsprintfA --
     unchecked varargs -- so a %d turned into %s dereferences an integer as a
     pointer. An empty entry is a visible to-do; a corrupted one is a crash.
  3. Leading/trailing whitespace is mirrored from the source. Sixteen values
     carry it as a concatenation seam ('Failed to connect to ' is followed
     straight by the host), and engines strip it.

Only EMPTY entries are touched, so re-running is safe: a translation
and incremental: reviewed work and earlier seeding are left alone.
"""

import argparse
import glob
import html
import json
import os
import re
import sys
import urllib.request

import pasconsts as pc
import pofile

# ONE STRING PER REQUEST by default. Batching maps results back BY POSITION, so
# it trusts the engine to return the array in request order -- and a reordered
# batch would pair translations with the wrong keys silently. Measured against
# the local engine:
#
#     --batch 1     2.04 s/string   ~15 min per language
#     --batch 40    0.12 s/string   ~52 s  per language
#
# The cost is per-request model inference, not transport, so it does not vanish
# on localhost. NY4I's call (2026-08-13) is to pay it: seeding a catalogue is
# rare, and because only fuzzy-and-empty entries are touched, every later run
# handles just the delta -- a handful of new strings, not 400.
#
# --batch >1 is still available and is then automatically alignment-checked: a
# sample is re-translated one at a time and compared. That check is meaningful
# because translation here is deterministic and batch output was verified
# byte-identical to individual output.
DEFAULT_BATCH = 1
DEFAULT_VERIFY = 25

# LibreTranslate mangles bare printf specifiers -- "%s needs %s for %d" comes
# back as "% delle esigenze % per %". Masking survives, and restoration is BY
# INDEX so the original width/precision (%-8s) is exact.
#
# HOW FORMAT SPECIFIERS SURVIVE THE ENGINE. Fourth approach, and the first
# that is not a guess about what a model will leave alone:
#
#   @0@  works for it/fr/nl/ja/ko; the pt model rewrites it "@ 0@" -- 47
#        Portuguese strings lost.
#   {0}  its replacement, and measurably worse than it looked: braces are
#        punctuation to these models and get dropped outright.
#   X0X  alphanumeric, so models mostly leave it alone. Much better, still
#        not safe -- pt-BR 27/30, ko 29/30.
#   <ph> HTML elements sent with format=html. The engine is TOLD it is markup
#        instead of being tricked into ignoring it.
#
# MEASURED 2026-08-30, 30 real placeholder strings per language, one local
# engine, {0} then X0X then <ph>+html:
#
#   pt-BR 11 -> 27 -> 30     ro 21 -> 30 -> 30     ko 25 -> 29 -> 30
#   es    21 -> 30 -> 30     ja 25 -> 30 -> 30     it 26 -> 30 -> 30
#
# <ph>+html scored 330/330 across all eleven target codes. THERE IS NO SAFE
# PLAIN-TEXT MARKER: a model may split, translate or drop anything resembling
# a word, and which one it does varies BY LANGUAGE PAIR. Stop hunting for a
# marker and use the channel the engine documents for markup.
#
# WHAT SURFACED IT: NY4I reported the same ~15 strings re-submitted on every
# runallpo.cmd. They were not being re-submitted so much as NEVER SUCCEEDING.
# A dropped token makes unprotect() reject the translation, msgstr stays
# empty, and an empty msgstr is exactly what makes an entry a candidate next
# run -- a permanent loop reporting work it could never complete. Romanian
# seeded 0 of 14; Brazilian Portuguese 0 of 106.
#
# THE COST of format=html is that the payload is markup, so the source is
# HTML-escaped going out and unescaped coming back. Measured on the 20
# catalogue strings containing & or < : 13/20 keep them under html, 13/20
# under text. IDENTICAL. The menu-accelerator '&' that MT eats is a
# pre-existing quality issue on entries a human reviews anyway.
TOKEN_RE = re.compile(r'<ph id="(\d+)"\s*></ph>')
LANGUAGE_KEY = "TC_TRANSLATION_LANGUAGE"
SKIP_KEYS = {"TC_TRANSLATION_AUTHOR", "TC_TRANSLATOR_EMAIL"}

# Sources that are an AUTHORING TO-DO rather than help text. Translating
# "TO BE COMPLETED" into ten languages produces ten to-dos nobody can act on and
# hides the fact that the English was never written. Matched on the WHOLE
# string: 'DEPRECATED - Use NETWORK PASSWORD' carries real information and is
# translated normally; a bare 'DEPRECATED' does not.
PLACEHOLDER_SOURCES = {
   "TO BE COMPLETED", "DEPRECATED", "TBD", "N/A", "NOT IMPLEMENTED",
   "PENDING RE-IMPLEMENTATION",
}

# STRINGS THAT ARE NOT LANGUAGE, so there is nothing to translate and a machine
# will return something anyway.
#
# Measured on the 640 Spanish entries awaiting a seed: 1 URL, 12 function-key
# labels F1..F12, 21 with no two consecutive letters at all -- 'S&P', '599',
# '--'. A translator then has to notice that 'http://www.tr4w.net' came back
# altered, which is a worse job than translating it would have been.
#
# Neither of the existing guards covers this shape: format validation only fires
# when a %-specifier changes, and PLACEHOLDER_SOURCES matches whole known
# strings.
#
# THE SECOND RULE IS THE GENERAL ONE. Two consecutive letters is what makes a
# word; without them there is no language to translate, and it catches F1, 599,
# -- and S&P in one test rather than a list that grows.
_NOT_LANGUAGE = re.compile(r"^\s*(https?://|www\.|mailto:|ftp://|[a-z]+://)", re.I)


# A DESIGNER PLACEHOLDER IS NOT ENGLISH EITHER.
#
# A converted form keeps its control NAME as the .lfm caption on purpose --
# uServerLogForm is the pattern CLAUDE.md points at, where HandleShow assigns
# the real caption from a constant -- and the .lfm harvest cannot tell that
# apart from a real label. So 'lblNoClusters', 'chkDontAsk' and 'lblPrompt'
# arrived in the catalogues as strings to translate. Nobody needs a control
# name translated (NY4I, 2026-08-31); seeding one produces confident nonsense
# in every language and then puts it in front of a human as though it were a
# label they should check.
#
# The shape is specific enough to be safe: a known widget prefix in lowercase,
# then CamelCase, to the end, with no space and no punctuation. A real caption
# either contains a space or does not begin with a widget prefix -- measured
# against the catalogue this matches exactly the three above and nothing else.
_CONTROL_NAME = re.compile(
    r"^(lbl|btn|chk|edt|cbx|cbo|lst|pnl|grp|rad|mem|img|tv|lay|frm|dlg)"
    r"[A-Z][A-Za-z0-9]*$")


def is_translatable(source):
   """False for text that is not language: a URL, a key name, a bare number."""
   s = source.strip()
   if not s:
      return False
   if _NOT_LANGUAGE.match(s):
      return False
   if not re.search(r"[A-Za-z]{2}", s):
      return False
   if _CONTROL_NAME.match(s):
      return False
   return True


def protect(text):
   """English -> HTML payload with each %-specifier as a <ph> element.

   ESCAPED FIRST, THEN TAGGED. The other order escapes the tags we just
   inserted, and the engine receives literal text reading "&lt;ph id=..." --
   which it translates like any other words.
   """
   originals = []
   escaped = html.escape(text, quote=False)

   def sub(m):
      originals.append(m.group(0))
      return '<ph id="%d"></ph>' % (len(originals) - 1)

   return pc.PLACEHOLDER_RE.sub(sub, escaped), originals


def unprotect(text, originals):
   """Restore specifiers. Returns (text, problem); problem is None if sound.

   wsprintf maps arguments BY POSITION and has no %1$s syntax, so a translation
   that reorders the tokens would pair the wrong argument with the wrong slot.
   Japanese does exactly that -- it is SOV and genuinely wants a different
   order -- so insist the tokens come back complete AND ascending.
   """
   found = [int(n) for n in TOKEN_RE.findall(text)]
   if found != list(range(len(originals))):
      return text, "tokens %s, expected %s" % (found,
                                               list(range(len(originals))))
   restored = TOKEN_RE.sub(lambda m: originals[int(m.group(1))], text)
   # Unescaped AFTER the originals go back: a %-specifier contains no entity,
   # so restoring first cannot be undone here.
   return html.unescape(restored), None


def mirror_edge_space(src, text):
   lead = src[:len(src) - len(src.lstrip())]
   trail = src[len(src.rstrip()):]
   return lead + text.strip() + trail


# A locale the engine spells differently from us. Chinese is the case that
# matters: we key on region (zh_CN), the engine keys on SCRIPT (zh-Hans /
# zh-Hant), and neither is derivable from the other by string surgery.
ENGINE_ALIASES = {
   "zh_CN": ("zh-Hans", "zh"),
   "zh_TW": ("zh-Hant", "zh"),
   "zh_HK": ("zh-Hant", "zh"),
}


def engine_target(url, code, source="en"):
   """Our catalogue code -> the code THIS engine actually offers.

   Asking beats guessing. Splitting on '_' and keeping the head was the old
   rule; it turns zh_CN into 'zh', which LibreTranslate does not have at all,
   and pt_BR into 'pt', silently seeding Brazilian Portuguese from the European
   model. Both are engine-specific facts, so read them off the engine.
   """
   offered = set(_targets(url, source))
   for cand in (ENGINE_ALIASES.get(code, ()) +
                (code.replace("_", "-"), code.split("_")[0])):
      if cand in offered:
         return cand
   # Nothing matched: hand back the old guess so check_target can produce its
   # error, which lists what the engine does have.
   return code.split("_")[0]


def _targets(url, source="en"):
   try:
      with urllib.request.urlopen(url.rstrip("/") + "/languages",
                                  timeout=30) as fh:
         langs = json.loads(fh.read().decode("utf-8"))
   except Exception as exc:                 # noqa: BLE001 - reported, not hidden
      raise SystemExit("cannot reach LibreTranslate at %s: %s" % (url, exc))
   src = next((x for x in langs if x.get("code") == source), None)
   if src is None:
      raise SystemExit("engine does not offer %r as a source" % source)
   return src.get("targets", [])


def check_target(url, target, source="en"):
   """Fail early and legibly if the engine has no model for this pair."""
   src = {"targets": _targets(url, source)}
   if target not in src.get("targets", []):
      raise SystemExit(
         "engine has no %s->%s model. Available: %s\n"
         "Install that model, or translate by hand -- the catalogue is usable "
         "without any engine."
         % (source, target, ", ".join(sorted(src.get("targets", [])))))


def translate(url, texts, target, source="en", batch=DEFAULT_BATCH):
   out = []
   for i in range(0, len(texts), batch):
      chunk = texts[i:i + batch]
      payload = json.dumps({"q": chunk, "source": source, "target": target,
                            "format": "html"}).encode("utf-8")
      req = urllib.request.Request(url.rstrip("/") + "/translate", data=payload,
                                   headers={"Content-Type": "application/json"})
      with urllib.request.urlopen(req, timeout=120) as fh:
         got = json.loads(fh.read().decode("utf-8"))["translatedText"]
      if isinstance(got, str):
         got = [got]
      if len(got) != len(chunk):
         raise SystemExit("engine returned %d results for %d inputs"
                          % (len(got), len(chunk)))
      out.extend(got)
      if batch > 1 or (i + 1) % 50 == 0 or i + 1 == len(texts):
         print("   %d/%d" % (min(i + batch, len(texts)), len(texts)))
   return out


# The fingerprint salvage_lossy.py leaves on a recovered entry. Matched loosely
# on purpose: the note's wording may be edited, its subject will not.
SALVAGE_MARK = "RECOVERED from a bit-corrupted lang file"


def seed(po_path, url, target, lang, dry_run, batch=DEFAULT_BATCH,
         reseed=False, verify=DEFAULT_VERIFY):
   entries = pofile.read_po(po_path)

   if reseed:
      # Discard previous MACHINE output so it can be regenerated. Only fuzzy
      # entries are cleared -- a cleared-fuzzy entry carries a human's review
      # decision and is never touched.
      wiped = 0
      kept_salvage = 0
      for e in entries:
         if e.fuzzy and e.target.strip() and not e.obsolete:
            if any(SALVAGE_MARK in n for n in e.notes):
               # NOT machine output. salvage_lossy.py recovered this from a
               # damaged lang file -- it is a native speaker's words, wearing
               # the same fuzzy flag because the recovery is unverified. An
               # engine cannot regenerate it, so clearing it destroys it.
               kept_salvage += 1
               continue
            e.target = ""
            wiped += 1
      if kept_salvage:
         print("--reseed: kept %d recovered entr%s -- not machine output"
               % (kept_salvage, "y" if kept_salvage == 1 else "ies"))
      print("--reseed: cleared %d unreviewed entr%s"
            % (wiped, "y" if wiped == 1 else "ies"))

   # EMPTY IS THE CONDITION, NOT FUZZY-AND-EMPTY.
   #
   # It used to require both, and that quietly stopped working the first time a
   # catalogue went through Poedit: an empty msgstr is UNTRANSLATED in gettext,
   # a state distinct from fuzzy, so Poedit strips '#, fuzzy' from empty entries
   # when it saves -- correctly. 95 Spanish entries came back from one such save
   # and this function could no longer see any of them (NY4I noticed the flags
   # were gone, 2026-08-27).
   #
   # What protects human work is the NON-empty half: an entry with text in it is
   # never touched here, reviewed or not. Dropping the fuzzy requirement costs
   # nothing and makes seeding independent of which editor last wrote the file.
   candidates = [e for e in entries
                 if not e.target.strip() and not e.obsolete
                 and e.key not in SKIP_KEYS]

   # THE WIDGET SET ALREADY TRANSLATED THESE, SO DO NOT ASK A MACHINE.
   #
   # Every designed form carries its own OK and Cancel captions, so the harvest
   # produces tfrmaltd.btnok.caption, tfrmautocq.btnok.caption and so on -- 39
   # per catalogue, 819 across all of them, whose English is one of six words.
   # Sending those to Argos costs a request each and returns the input:
   #
   #    ('paragraphs:', ['Cancel'])  ('apply_packaged_translation', 'Cancel')
   #
   # (NY4I, watching LibreTranslate, 2026-08-28: "why would you be translating
   # OK".) Lazarus ships lclstrconsts.<lang>.po, translated by the people who
   # maintain the widget set, so the answer is already on disk -- and it is
   # BETTER than the machine's: Spanish OK is 'Aceptar', which Argos will not
   # say because it is not what 'OK' means, it is what the BUTTON is called.
   #
   # Taken as fuzzy like any other unreviewed text: the wording is right, but
   # which button a given form means is still a human's call.
   lcl = pofile.lcl_catalogue(target)
   from_lcl = []
   if lcl:
      remaining = []
      for e in candidates:
         hit = lcl.get(e.source.replace('&', '').strip().lower())
         if hit and e.source.strip():
            # MATCH THE ENGLISH ON ACCELERATORS. The LCL spells its captions
            # with one ('&Aceptar') because its own dialogs use them; a .lfm
            # caption usually does not. Copying the & across where the English
            # has none is exactly what po_lint calls "an & was added where the
            # English has none" -- 800 self-inflicted defects.
            if '&' not in e.source:
               hit = hit.replace('&', '')
            elif '&' not in hit:
               # The English wants an accelerator and the LCL's wording has
               # none. Inventing a position is a guess about which letter is
               # free on THAT form, which is the one thing this cannot know, so
               # leave the entry to the ordinary path instead of shipping a
               # caption with no accelerator.
               remaining.append(e)
               continue
            e.target = hit
            e.fuzzy = True
            from_lcl.append(e)
         else:
            remaining.append(e)
      candidates = remaining
   if from_lcl:
      print("%d entr%s filled from the LCL's own catalogue, not translated: %s"
            % (len(from_lcl), "y" if len(from_lcl) == 1 else "ies",
               ", ".join(sorted({repr(e.source.strip()) for e in from_lcl})[:8])))
   no_source = [e for e in candidates if not e.source.strip()]
   placeholder = [e for e in candidates
                  if e.source.strip().upper() in PLACEHOLDER_SOURCES]
   not_language = [e for e in candidates
                   if e.source.strip()
                   and e.source.strip().upper() not in PLACEHOLDER_SOURCES
                   and not is_translatable(e.source)]
   todo = [e for e in candidates
           if e.source.strip()
           and e.source.strip().upper() not in PLACEHOLDER_SOURCES
           and is_translatable(e.source)]

   if no_source:
      print("%d entr%s have NO English source -- nothing to translate; the "
            "English has to be written first"
            % (len(no_source), "y" if len(no_source) == 1 else "ies"))
   if placeholder:
      print("%d entr%s are an English authoring to-do (%s) -- skipped"
            % (len(placeholder), "y" if len(placeholder) == 1 else "ies",
               ", ".join(sorted({e.source.strip() for e in placeholder}))))
   if not_language:
      sample = sorted({e.source.strip() for e in not_language})[:6]
      print("%d entr%s are not language (URL, key name, bare number) -- skipped: %s"
            % (len(not_language), "y" if len(not_language) == 1 else "ies",
               ", ".join(repr(s) for s in sample)))
   print("%d entr%s to seed" % (len(todo), "y" if len(todo) == 1 else "ies"))
   if dry_run:
      for e in todo[:10]:
         print("   %-38s %r" % (e.key, e.source[:60]))
      return 0
   if not todo:
      # STILL WRITE, if the LCL supplied anything. Returning without saving
      # would throw the fills away and ask again on the next run.
      if from_lcl and not dry_run:
         pofile.write_po(po_path, entries, pc.LANG_CODES[lang],
                         pc.LANG_CODES[pc.SOURCE_LANG])
      return 0

   check_target(url, target)

   # Flatten to line segments so embedded #13 structure survives, masking the
   # specifiers in each.
   segments, index, masks = [], [], []
   for e in todo:
      parts = e.source.split("\r")
      index.append((e, len(parts)))
      for part in parts:
         masked, originals = protect(part)
         segments.append(masked)
         masks.append(originals)

   done = translate(url, segments, target, batch=batch)

   if batch > 1 and verify and segments:
      # Evenly spaced rather than random: a systematic offset shows up wherever
      # it starts, and the spread covers the whole request sequence.
      n = min(verify, len(segments))
      step = max(1, len(segments) // n)
      picks = list(range(0, len(segments), step))[:n]
      print("verifying %d of %d segment(s) one at a time..." % (len(picks),
                                                                len(segments)))
      solo = translate(url, [segments[i] for i in picks], target, batch=1)
      bad = [(i, segments[i], done[i], s)
             for i, s in zip(picks, solo) if s != done[i]]
      if bad:
         print()
         print("ALIGNMENT CHECK FAILED -- batched results do not match "
               "individual ones. Nothing was written.")
         for i, src, got, want in bad[:5]:
            print("   segment %d  %r" % (i, src[:50]))
            print("      batched:    %r" % got[:60])
            print("      individual: %r" % want[:60])
         raise SystemExit("re-run with --batch 1")
      print("alignment OK (%d/%d sampled segments identical)" % (len(picks),
                                                                 len(picks)))

   restored, problems = [], {}
   for i, text in enumerate(done):
      text, problem = unprotect(text, masks[i])
      restored.append(text)
      if problem:
         problems[i] = problem

   seeded, dropped = 0, []
   pos = 0
   for e, count in index:
      bad = [problems[j] for j in range(pos, pos + count) if j in problems]
      chunk = "\r".join(restored[pos:pos + count])
      pos += count
      if bad:
         dropped.append((e.key, bad[0]))
         continue
      if not chunk.strip():
         dropped.append((e.key, "engine returned nothing"))
         continue
      text = mirror_edge_space(e.source, chunk)
      if pc.specifier_types(e.source) != pc.specifier_types(text):
         dropped.append((e.key, "specifiers %s -> %s"
                                % (pc.specifier_types(e.source),
                                   pc.specifier_types(text))))
         continue
      # The engine emits HTML entities -- the French model renders the space
      # before a colon as &#160; -- and TR4W paints them verbatim.
      e.target = pofile.unescape_entities(text)     # stays fuzzy
      seeded += 1

   # ONLY IF EMPTY. This used to overwrite unconditionally, and
   # LANGUAGE_NAMES is the ASCII table that feeds --list-languages on a
   # cp1252 console -- so a seed run turned the catalogue Espanol back into
   # ESPANOL, Dansk into DANSK, undoing the native endonyms on sight.
   #
   # Two audiences, two answers: console text is ASCII because the console
   # cannot print the alternative; catalogue text is UTF-8 and lands in a
   # GUI. A language names itself in its own script there. Filling a BLANK
   # from the ASCII table is still better than leaving it empty.
   if lang in pc.LANGUAGE_NAMES:
      for e in entries:
         if (e.key == LANGUAGE_KEY) and (not e.target.strip()):
            e.target = pc.LANGUAGE_NAMES[lang]

   pofile.write_po(po_path, entries, pc.LANG_CODES[lang],
                   pc.LANG_CODES[pc.SOURCE_LANG])
   print()
   print("seeded  %d" % seeded)
   print("dropped %d" % len(dropped))
   for key, why in dropped:
      print("   %-40s %s" % (key, why))
   print()
   print("Every seeded entry is FUZZY. po2pas.py will not apply them until a")
   print("reviewer clears 'Needs work' in Poedit.")
   return 0


def fix_spacing(po_path, dry_run):
   """Restore concatenation-seam whitespace in an already-seeded catalogue.

   Only touches fuzzy entries: a cleared one carries a human's decision.
   """
   entries = pofile.read_po(po_path)
   fixed = []
   for e in entries:
      if e.obsolete or not e.fuzzy or not e.target.strip():
         continue
      want = mirror_edge_space(e.source, e.target)
      if want != e.target:
         fixed.append((e.key, e.target, want))
         e.target = want
   name = os.path.basename(po_path)
   print("%-16s %d entr%s need edge whitespace restored"
         % (name, len(fixed), "y" if len(fixed) == 1 else "ies"))
   if fixed and not dry_run:
      lang_tag = name[:-3].split("_", 1)[1]
      pofile.write_po(po_path, entries, lang_tag,
                      pc.LANG_CODES[pc.SOURCE_LANG])
   return len(fixed)


def print_languages(paths):
   """The LANG codes this tree accepts, with what each one writes."""
   i18n = paths["i18n"]
   print("LANG codes (TR4W's own, not ISO 639-2):")
   print()
   print("  %-6s %-7s %-24s %s" % ("LANG", "code", "language", "catalogue"))
   print("  %-6s %-7s %-24s %s" % ("-" * 6, "-" * 7, "-" * 24, "-" * 22))
   for lang in sorted(pc.LANG_CODES):
      code = pc.LANG_CODES[lang]
      name = pc.LANGUAGE_NAMES.get(lang, "")
      po = os.path.join(i18n, "tr4w_%s.po" % code)
      mark = os.path.basename(po) if os.path.exists(po) else "-- none yet --"
      print("  %-6s %-7s %-24s %s" % (lang, code, name, mark))
   print()
   print("  ALL is accepted by --fix-spacing only; to seed every language use")
   print("  Refresh-Catalogues.ps1 -Seed ALL, which loops these one at a time.")


def main(argv=None):
   for stream in (sys.stdout, sys.stderr):
      if hasattr(stream, "reconfigure"):
         stream.reconfigure(encoding="utf-8", errors="replace")

   ap = argparse.ArgumentParser(description=__doc__)
   ap.add_argument("--list-languages", action="store_true",
                   help="print the LANG codes this tree knows and exit "
                        "(so does --lang with no value)")
   # nargs="?" so `--lang` ON ITS OWN is legal and means "which are there?".
   # Without it argparse rejects the flag before any of this runs -- which is
   # what NY4I hit, and it is the exact form he asked for:
   #   mt_seed.py --lang
   #   error: argument --lang: expected one argument
   ap.add_argument("--lang", nargs="?", const="", help="LANG code, or ALL for "
                                                 "--fix-spacing")
   ap.add_argument("--catalog", default="tr4w", choices=("tr4w", "help"),
                   help="which catalogue: the TC_ constants (default) or the "
                        "config-command help")
   ap.add_argument("--url", default="http://localhost:5000")
   ap.add_argument("--dry-run", action="store_true")
   ap.add_argument("--fix-spacing", action="store_true")
   ap.add_argument("--batch", type=int, default=DEFAULT_BATCH,
                   help="strings per request (default %d). 1 removes all "
                        "positional trust; raise it only for a remote engine."
                        % DEFAULT_BATCH)
   ap.add_argument("--verify", type=int, default=DEFAULT_VERIFY,
                   help="segments to re-translate individually as an "
                        "alignment check (default %d; 0 disables)"
                        % DEFAULT_VERIFY)
   ap.add_argument("--reseed", action="store_true",
                   help="discard previous machine output and regenerate it. "
                        "Reviewed (non-fuzzy) entries are never touched.")
   args = ap.parse_args(argv)

   paths = pc.repo_paths()
   pc.load_language_registry(paths["i18n"])

   # WHICH THREE LETTERS, and it is a fair question: the codes are TR4W's own
   # (POR is Portugal, PTB is Brazil), not ISO 639-2, so they cannot be guessed
   # or looked up elsewhere. NY4I, 2026-08-28: "I honestly could not recall the
   # three letter code for port. versus brazilian port."
   #
   # Printed when asked for, and ALSO when --lang is omitted or unknown, which
   # is the moment the operator actually needs it -- an error that says "unknown
   # LANG" without saying what the known ones are is a dead end.
   if args.list_languages or not args.lang:
      print_languages(paths)
      return 0 if args.list_languages else 2
   pc.load_language_registry(paths["i18n"])

   if args.fix_spacing:
      if args.lang.upper() == "ALL":
         targets = sorted(glob.glob(os.path.join(paths["i18n"], "*.po")))
      else:
         code = pc.LANG_CODES.get(args.lang.upper())
         if code is None:
            print_languages(paths)
            raise SystemExit("unknown LANG %r -- the codes above are the ones "
                             "this tree knows" % args.lang)
         targets = [os.path.join(paths["i18n"],
                                 "%s_%s.po" % (args.catalog, code))]
      total = sum(fix_spacing(p, args.dry_run) for p in targets
                  if os.path.exists(p))
      print()
      print("%d entr%s %s" % (total, "y" if total == 1 else "ies",
                              "would change" if args.dry_run else "repaired"))
      return 0

   lang = args.lang.upper()
   code = pc.LANG_CODES.get(lang)
   if code is None:
      # THE LIST, not just the complaint. "unknown LANG 'BRA'" without saying
      # what IS known is a dead end, and these codes cannot be guessed.
      print_languages(paths)
      raise SystemExit("unknown LANG %r -- pick one above, or register it with "
                       "`pas2po.py --new-lang %s --code <iso639-1>`"
                       % (lang, lang))
   prefix = "tr4w" if args.catalog == "tr4w" else "help"
   po_path = os.path.join(paths["i18n"], "%s_%s.po" % (prefix, code))
   if not os.path.exists(po_path):
      raise SystemExit("no %s" % po_path)
   # A dry run returns before it ever contacts the engine, so it must not
   # require one to be up just to resolve a code.
   target = code if args.dry_run else engine_target(args.url, code)
   return seed(po_path, args.url, target, lang,
               args.dry_run, args.batch, args.reseed, args.verify)


if __name__ == "__main__":
   sys.exit(main())
