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

**It cannot damage finished work.** It only touches entries that are *both* marked
"Needs work" *and* empty, so a reviewed translation fails both tests. It also drops any
string whose `%s`/`%d` placeholders came back wrong rather than writing a broken one.

Do **not** use `--reseed` unless you mean it — that clears drafts that already have
text, including any a person typed and left flagged.

Seed everything that is empty:

```powershell
python tools\i18n\mt_seed.py --lang ALL
```

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

---

## Put translations into the program

```powershell
powershell -File tr4w\build\Make-LanguageRes.ps1     # catalogues -> res\tr4w_languages.res
powershell -File tr4w\build\Build-App.ps1
```

Only entries a person has **approved** are embedded — anything still marked "Needs
work" is dropped. So a language full of machine drafts adds nothing to the exe until
someone reviews it.

Check it worked:

```powershell
cd tr4w\target
..\..\build-out\app-i386-win32\tr4w_fpc.exe uitest.cfg --lang pl
```

`tr4w\target\tr4w.log` says which catalogue was used:

```
UI language: "pl" from the embedded catalogue
UI language: none loaded; using the compiled-in English
```

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
| `po_merge.py` | adds new strings to every catalogue; never edits an existing translation |
| `pas2po.py` | language tables → `.po` (also creates a new language) |
| `po2pas.py` | `.po` → language tables; refuses anything still "Needs work" |
| `pas2res.py` | English tables → `uTR4WStrings.pas` resourcestrings |
| `po_rekey.py` | adds the run-time identifier beside the `msgctxt` key |
| `po_prune.py` | marks entries obsolete when their key leaves the source |
| `ini2po.py` | help INIs ⟷ `.po` |
| `pofile.py`, `pasconsts.py` | shared readers — not run directly |

---

## If something looks wrong

**A translation does not appear.** Almost always still marked "Needs work" — the
program refuses those deliberately. Check in Poedit.

**Nothing at all appears.** Check the log line above. If it says the language loaded and
you still see English, you are probably looking at strings that are not translatable
yet — the 383 `TC_` set and the tool-window titles. See
[`ADDING_A_LANGUAGE.md`](ADDING_A_LANGUAGE.md).

**A stale translation appears.** A `.po` beside the exe overrides the embedded one:
check for `build-out\app-i386-win32\languages\<lang>\tr4w.po` and delete it.

**`unknown LANG`** — the three-letter name is not registered. Pass `--code` once, as in
*Add a new language* above.
