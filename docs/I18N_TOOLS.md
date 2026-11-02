# Running the translation tools

Quick reference. Every command runs from `C:\tr4w-d12`.

For the translator round-trip see [`TRANSLATION_HANDOFF.md`](TRANSLATION_HANDOFF.md);
this is just how to drive the scripts.

---

## Before you start

**Python** — any 3.x on the PATH. No packages to install.

**LibreTranslate** — only needed for seeding. Default `http://localhost:5000`.
Check it is up:

```powershell
python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:5000/languages').status)"
```

**Language codes are TR4W's own three-letter names**, not the two-letter tags in the
file names:

| | | | | | | | |
|---|---|---|---|---|---|---|---|
| ENG en | ESP es | GER de | RUS ru | UKR uk | CZE cs | ROM ro | SER sr |
| MNG mn | POL pl | ITA it | FRA fr | CHN zh_CN | DUT nl | POR pt | JPN ja |
| KOR ko | FIN fi | SWE sv | DAN da | GRE el | PTB pt_BR | | |

---

## Seed a language with machine translation

The one you asked about. Fills every empty entry with a draft, marked "Needs work".

```powershell
python tools\i18n\mt_seed.py --lang POL --dry-run     # see what it would do
python tools\i18n\mt_seed.py --lang POL              # do it
```

Takes roughly **one second per entry** — about 11 minutes for a full language, since
it sends one string per request rather than batching (batching misaligned entries).

**It cannot damage finished work.** It only touches entries that are **empty** --
anything with text in it, reviewed or not, is left alone. (It used to require "Needs
work" as well; Poedit strips that flag from empty entries on save, so it keys on empty
alone.)

**It writes nothing `po_lint` would reject.** Every draft is checked with
`po_lint.draft_defects()` -- the same function `po_lint` itself uses -- and dropped,
not written, if its line breaks, tabs or `%s`/`%d` sequence differ from the English.
The dropped entries are listed at the end of the run with the reason. This is what
LibreTranslate does to a multi-line message: it flattens the line breaks
(`SImportMyFactsQuestion`, 2026-10-19, all 19 languages, issue #92). A dropped entry
stays empty, and an empty entry is a visible to-do.

**To keep an entry out for good**, put a translator comment on it:

```
# mt-seed: skip -- 2026-10-19, the engine flattens its line breaks
#: uappstrings.simportmyfactsquestion
msgid "..."
msgstr ""
```

It is never seeded, and `--reseed` never clears it. Write the reason after `skip`.
A `# ` translator comment is the kind gettext tools keep: `msgmerge`, Poedit, Weblate
and `pofile` all carry it through. Do **not** use `#.` -- that is the template's, and
the next merge rewrites it. Without the marker, an entry you clear because its draft
was bad comes straight back on the next run, because empty is what `mt_seed` fills.

Do **not** use `--reseed` unless you mean it — that clears drafts that already have
text, including any a person typed and left flagged.

Seed everything that is empty:

```powershell
python tools\i18n\mt_seed.py --lang ALL
```

**After a change, seed only what the change touched** (2026-11-01). Every catalogue
carries about 50 empty entries left empty on purpose or by an earlier refusal (840
in `sr` and `mn`, which the engine does not offer), and a plain run fills all of
them. `--only` names an entry by its identifier (msgctxt or `#:`), is repeatable,
and keeps every other gate:

```powershell
python tools\i18n\mt_seed.py --lang GER --only tprefsform.lblappearhint.caption --dry-run
```

**A REWORDED caption needs more than `po_merge`.** `po_merge` skips an entry whose
identifier is already claimed and never updates its msgid, and LazUtils matches on
the identifier, so the old wording's translation keeps shipping under the new
English. Rewrite the msgid by script through `pofile` (precedents: `74a50e27`,
and the five Preferences restart notes on 2026-11-01): refuse a reviewed entry
or one carrying a `# ` comment unless you have read it, clear a plain machine
draft, then `mt_seed --only`. If two keys shared one entry and their English
now differs, take the second identifier off its `#:` lines first so `po_merge`
adds it.

**The help catalogues do this for you.** `python tools\i18n\ini2po.py` merges the
English ini into every `i18n\help_*.po`: a reworded msgid keeps a human
translation (fuzzy, `#|` previous msgid, dated `# ` note) and clears a machine
draft, and the run prints the `mt_seed --catalog help --only ...` line per
language for what it cleared or added empty. Run those, then `po_lint --all`.
`--catalog help` keeps command names and `TRUE`/`FALSE` English (masked as
`<nm>` elements; a draft that loses one is dropped). A new language:
`ini2po.py --new-lang JPN`, then `mt_seed.py --lang JPN --catalog help`.

---

## Check a catalogue

Run this on anything before you trust it — especially a file back from a translator.

```powershell
python tools\i18n\po_lint.py i18n\tr4w_pl.po
python tools\i18n\po_lint.py --all
python tools\i18n\po_lint.py i18n\tr4w_pl.po --fix    # only repairs the harmless case
```

Catches a changed `%s`, a dropped line break, and entries left empty but no longer
flagged. Non-zero exit means a real defect.

It also fails a catalogue whose `TC_TRANSLATION_AUTHOR` is the English msgid (`N4AF`),
**fuzzy or not**, because fuzzy entries ship. That entry is the About box's
"<language> translation by <author>" credit: name and callsign of the translator
(never an email), `(SK)` after a silent key's callsign, and **empty or `LibreTranslate`
for a machine translation**. The About box then says LibreTranslate and adds
`TC_TRANSLATION_CORRECTIONS` ("Corrections are appreciated."). The unit test
`uTestUILanguage.Test_NoCatalogueCreditsTheEnglishAuthor` pins the same rule against the
embedded catalogues, which is the copy that gates a build (2026-10-16).

It also fails an entry whose English is **not language** -- `F1`, `8`, `...` -- because
nothing should have offered it to a translator. `pofile.is_translatable` is the rule;
`po_merge --apply` removes such an entry while its msgstr is empty (2026-10-21).

**There is no English catalogue to lint** (2026-10-21): English is the msgid, and
`tr4w_en.po` was deleted. No catalogue is exempt from any check any more.

---

## Refresh the catalogues after the program changes

Only needed when forms or strings have changed.

```powershell
# 1. Regenerate the template -- LAZARUS IDE ONLY, lazbuild cannot do this.
#    Open tr4w\tr4w.lpi, Project Options -> i18n, tick "Resave forms with
#    enabled i18n", then Run -> Clean up and Build.

# 2. Add anything new to all catalogues. Never touches an existing translation.
python tools\i18n\po_merge.py --pot tr4w\languages\tr4w_laz.pot --apply
```

**Only new RESOURCESTRINGS? No IDE needed.** FPC writes a `.rsj` for every unit
with resourcestrings on every build (`build-out\app-i386-win32\uAppStrings.rsj`),
and Lazarus' own `updatepofiles` turns one into a template. Write it to a
**scratch** file, never to `tr4w_laz.pot`:

```powershell
New-Item -ItemType File <scratch>\uappstrings.pot -Force     # it refuses a missing .pot
C:\Lazarus\tools\updatepofiles.exe build-out\app-i386-win32\uAppStrings.rsj <scratch>\uappstrings.pot
python tools\i18n\po_merge.py --pot <scratch>\uappstrings.pot          # dry run first
python tools\i18n\po_merge.py --pot <scratch>\uappstrings.pot --apply
```

**Never point `updatepofiles` at `tr4w\languages\tr4w_laz.pot`.** It deletes
every template entry that is not in the files it was given
(`translations.pas` `UpdatePOFile` -> `RemoveTaggedItems(0)`), and the form
half of that template comes from `.lrj` files that only the IDE writes when it
resaves forms -- so it would strip every `.lfm` caption out of the template.
The `.lfm` half still needs step 1.

**An `--apply` is lossless since 2026-10-18.** Before that, every catalogue
rewrite -- `po_merge`, `po_lint --fix`, `po_rekey`, `po_prune`, `po_dedupe`,
`mt_seed` -- went through a `pofile.write_po` that rebuilt the file from parsed
fields, dropping every `# ` translator comment and replacing the header (4-5
lines per catalogue, 36 in Polish, G0DVJ's Poedit header among them). It now
writes unchanged entries from their own text, and
`python tools\i18n\test_pofile.py` fails if any catalogue does not read and
write back byte-identical. Check `git diff --numstat i18n` after an `--apply`:
an add-only merge is additions and no deletions.

---

## Put translations into the program

```powershell
powershell -File tr4w\build\Build-App.ps1     # regenerates res\tr4w_languages.res itself
```

**`Build-App.ps1` and `Build-Tests.ps1` regenerate `res\tr4w_languages.res`
automatically** (2026-10-16; before that nothing ran `Make-LanguageRes.ps1` and
two catalogue commits never reached a binary). The trigger is CONTENT, not file
times: `res\tr4w_languages.res.inputs` records a sha256 per `i18n\tr4w_*.po` plus
the generator, and the build recompares them (~0.1 s when current, ~3 s to
regenerate; the output is byte-identical for identical inputs). A failure to
regenerate FAILS the build. **After changing a catalogue, build once and commit
the `.res` AND the `.inputs` together** — the Linux and macOS builds cannot run
the generator, so `build/check-language-res.sh` (stage `languages` in
`build-unix.sh`) FAILS them if the committed pair does not match the
catalogues. You can still run `Make-LanguageRes.ps1` by hand; do so after a
Lazarus upgrade, whose `lclstrconsts` catalogues are embedded but deliberately
not hashed.

Unreviewed ("Needs work") entries ARE embedded since 2026-09-21, with their
`#,` flag stripped in the shipped copy only; the `.po` keeps its marker.
`Make-LanguageRes.ps1 -ReviewedOnly` is an experiment, not a setting: the next
build puts the default back (the stamp's `mode` line no longer matches).

Check it worked:

```powershell
cd tr4w\target
..\..\build-out\app-i386-win32\tr4w_fpc.exe uitest.cfg --lang pl
```

`tr4w\target\tr4w.log` says which catalogue was used:

```
UI language: "pl" selected by <source>, loaded from the embedded catalogue
UI language: none loaded; using the compiled-in English
```

---

## See whether the text fits

A translation is routinely 20–40% longer than the English the layout was drawn for,
and the first anyone usually knows is a clipped caption in a screenshot. This asks
the program itself, in every language:

```powershell
cd tr4w\test\ui
.\Sweep-TextFit.ps1                 # every language
.\Sweep-TextFit.ps1 -Lang de,pl     # just these
```

Findings land in `build-out\textfit-sweep.csv`. Measured 2026-08-28: **45 clipped
captions in German Preferences alone.**

Three things about it are worth knowing, because each one produced a wrong answer
before it was understood:

- **It defuzzes first, into the exe's own directory.** ~~The shipping catalogue has
  every "Needs work" entry dropped~~. That premise has been stale since 2026-09-21: the
  embedded catalogue ships "Needs work" entries too. Note also that `po_defuzz --install`
  writes beside the exe, while on Windows a loose file is looked for under the working
  directory. Whether the sweep's copy is the one actually loaded has not been checked;
  the log line says which was used. The defuzzed copy is for measurement only — the words in it
  are unreviewed machine output. *Layout truth, not language truth.*
- **It measures from inside the program**, not by walking the window tree. A `TLabel`
  is a `TGraphicControl` with no window handle, and most captions in the converted
  forms are labels — which is why the older `Test-TextFit.ps1` reported nothing
  clipped in German. Prefer this one.
- **A zero means something now.** Each form logs how many captions it *measured*
  beside how many failed, so "no findings" can be told apart from "nothing was
  looked at". Until 2026-08-28 they were the same output, and that is how the audit
  managed never to measure a single converted window.

It cannot see anything *painted* rather than placed — the main window's own elements,
owner-drawn list items, grid cells. Those still need eyes.

---

## Add a new language

**Order matters.** The two halves of the catalogue live in different places, and step 1
*replaces* the file rather than merging.

```powershell
# 1. the 383 legacy TC_ strings, from the English table
python tools\i18n\pas2po.py --new-lang FIN --code fi --language-name SUOMI

# 2. the 661 form and resourcestring entries, from the template
python tools\i18n\po_merge.py --pot tr4w\languages\tr4w_laz.pot --apply

# 3. optional
python tools\i18n\mt_seed.py --lang FIN
```

Done the other way round the language silently ends up with 383 entries instead of
1044, missing every form string.

`--code` and `--language-name` are only needed the first time; after that the language
is in `i18n\languages.json` and `--lang FIN` is enough.

---

## What each script does

| script | |
|---|---|
| `mt_seed.py` | machine drafts for empty entries, always marked "Needs work" |
| `po_lint.py` | checks placeholders, line breaks and entry state |
| `po_merge.py` | adds new strings to every catalogue; never edits an existing translation; never adds -- and drops when empty -- an entry that is not language (`F1`, `8`, `...`) |
| `pas2po.py` | creates a new language (`--new-lang`). Never writes English, which has no catalogue |
| `po2pas.py` | `.po` → language tables; refuses anything still "Needs work" |
| `pas2res.py` | English tables → `uTR4WStrings.pas` resourcestrings |
| `po_rekey.py` | adds the run-time identifier beside the `msgctxt` key |
| `po_prune.py` | marks entries obsolete when their key leaves the source. **Do not run it on the real catalogues (issue #144):** it knows only `TC_`/`RC_` keys, so it would obsolete 2,168 live `.lfm`/resourcestring entries, and `po_merge --apply` then deletes every `#~` block |
| `ini2po.py` | help INIs → `help_*.po`: reads the inis, never writes them, and MERGES into every existing help catalogue (the `.po` is the master; `test_ini2po.py`). `--new-lang` creates one |
| `test_ini2po.py` | pins that merge: nothing lost, fuzzy never cleared, reworded English handled |
| `po_defuzz.py` | a copy with the "Needs work" flags removed, for testing only |
| `salvage_lossy.py` | recovers what it can from a lang file that decodes under no codepage (CHN) |
| `pofile.py`, `pasconsts.py` | shared readers — not run directly. `pofile` rewrites losslessly |
| `test_pofile.py` | the gate on that: every catalogue must read and write back byte-identical |
| `test_is_translatable.py` | pins `pofile.is_translatable`, and that no catalogue holds an entry that is not language |

---

## If something looks wrong

**A translation does not appear.** ~~Almost always still marked "Needs work" — the
program refuses those deliberately.~~ Since 2026-09-21 "Needs work" entries ship, so check
these instead:
- Was the `.res` rebuilt and committed? `res\tr4w_languages.res.inputs` must match.
- Is a loose `languages\<lang>\tr4w.po` overriding the embedded copy? A loose file keeps
  the fuzzy gate.
- Is the string in the catalogue at all? A caption added since the last IDE save is not
  (issue #145), and new resourcestrings are not until they are merged.

**Nothing at all appears.** Check the log line above. If it says the language loaded and
you still see English, the string is probably in no catalogue: see the issue #145 case
above, and the `po_merge` step under *Refresh the catalogues*. ~~the 383 `TC_` set and the
tool-window titles~~. Both have been translatable since the `uTR4WStrings` cut-over
(2026-08-27) and the `TMainMenu` (2026-09-07). See
[`ADDING_A_LANGUAGE.md`](ADDING_A_LANGUAGE.md) section 6.

**A stale translation appears.** A loose `.po` overrides the embedded one. On Windows it
is looked for under the **working directory** (`uAppPaths.DataFilePath`), so with the
recipe above check `tr4w\target\languages\<lang>\tr4w.po` and delete it.
~~`build-out\app-i386-win32\languages\<lang>\tr4w.po`~~

**`unknown LANG`** — the three-letter name is not registered. Pass `--code` once, as in
*Add a new language* above.
