# Sending a language out, and taking it back

The counterpart to [`TRANSLATOR_GUIDE.md`](TRANSLATOR_GUIDE.md), which is the document
the translator gets. This one is yours: how to prepare a file, what to put in the ZIP,
and what to do when it comes back.

Every command runs from `C:\tr4w-d12`.

---

## Before you send anything

### 1. Refresh the catalogue from the program

Do this only if forms or strings have changed since the last handoff. It is what keeps
the translator from being asked twice about the same dialog.

```powershell
# 1a. Regenerate the .lrj/.pot in Lazarus  -- IDE ONLY, lazbuild cannot do it
#     Open tr4w\tr4w.lpi, Project Options -> i18n, tick "Resave forms with
#     enabled i18n", then Run -> Clean up and Build.
#     Produces tr4w\languages\tr4w_laz.pot

# 1b. Merge anything new into all 16 catalogues. Existing translations are
#     never touched -- it only ever adds.
python tools\i18n\po_merge.py --pot tr4w\languages\tr4w_laz.pot --apply
```

### 2. Seed the untranslated entries (optional)

Gives the translator a first draft to correct rather than a blank column. Everything
it writes stays marked "Needs work", so none of it can reach the program unreviewed.

Needs LibreTranslate running on `http://localhost:5000`.

```powershell
python tools\i18n\mt_seed.py --lang POL --dry-run   # see what it would do
python tools\i18n\mt_seed.py --lang POL
```

Language codes are TR4W's own three-letter ones — `ESP`, `POL`, `GER`, `RUS` — not the
two-letter ISO codes used in the file names.

**Whether to seed is a judgement call.** A draft is faster to correct than a blank, but
a bad draft can anchor a translator to a poor phrasing. For a language with an engaged
native speaker, consider sending it unseeded.

### 3. Check the file before it leaves

```powershell
python tools\i18n\po_lint.py i18n\tr4w_pl.po
```

This should be clean going out. If it reports anything, the problem is ours, not the
translator's — fix it first rather than sending a file with known defects.

---

## What to send

**In the ZIP:**

| file | why |
|---|---|
| `i18n\tr4w_<lang>.po` | the only file they edit |
| `docs\TRANSLATOR_GUIDE.md` | how to install Poedit and what the marks mean |

That is all. **Do not send** the `.pot`, the other languages, or anything from
`tools\`. A translator needs one file and one page of instructions; more choices means
more chances to edit the wrong thing.

**In the covering note**, worth saying explicitly:

- the free Poedit is fine — they do not need the paid upgrade
- a partial file is welcome; there is no need to finish
- questions are cheaper than guesses, especially on contest jargon
- roughly how many entries there are, so they can judge the size of the job

```powershell
# how many they are actually being asked to do
python -c "import sys;sys.path.insert(0,'tools/i18n');import pofile;e=[x for x in pofile.read_po('i18n/tr4w_pl.po') if x.source.strip()];print('%d entries, %d already reviewed, %d to look at' % (len(e), sum(1 for x in e if x.target.strip() and not x.fuzzy), sum(1 for x in e if x.fuzzy)))"
```

---

## When it comes back

### 1. Check it before anything else

```powershell
python tools\i18n\po_lint.py <their file>
```

Three things it catches that neither Poedit nor the compiler will:

- **a changed `%s`/`%d`** — TR4W formats through `wsprintfA` with unchecked varargs, so
  a missing placeholder reads the next argument off the stack. This is a crash, not a
  cosmetic defect, and **it is already present in some of the inherited translations**:
  the first run found a Ukrainian `CQ total: %u` truncated to a bare `%`
- **a dropped or added line break** inside a message
- **an entry left empty but no longer marked "Needs work"** — Poedit does this
  routinely, and it makes the entry invisible to the seeder afterwards

A non-zero exit means a real defect. Go back to the translator with the specific
entry; do not repair a translation you cannot read.

```powershell
python tools\i18n\po_lint.py <their file> --fix    # repairs only the third kind
```

### 2. Put it in place

If they edited the file you sent, it replaces `i18n\tr4w_<lang>.po` directly.

If they worked from a copy elsewhere — it happens — do not overwrite blindly. The
adopt step takes their reviews and leaves everything else alone:

```powershell
python tools\i18n\po_lint.py <their file> --fix
copy <their file> i18n\tr4w_<lang>.po
```

### 3. Build it into the program

```powershell
powershell -File tr4w\build\Make-LanguageRes.ps1     # .po -> res\tr4w_languages.res
powershell -File tr4w\build\Build-App.ps1
```

`Make-LanguageRes` embeds **only entries a person has approved** — anything still
marked "Needs work" is dropped before it reaches the binary. So the size of the
resource is a fair measure of how much real translation exists.

### 4. Confirm it

```powershell
cd tr4w\target
..\..\build-out\app-i386-win32\tr4w_fpc.exe uitest.cfg --lang pl
```

The log in `tr4w\target\tr4w.log` says which catalogue was used:

```
UI language: "pl" from the embedded catalogue
UI language: none loaded; using the compiled-in English
```

### 5. Commit

The `.po` and the regenerated `.res` belong in the same commit — a catalogue and the
resource built from it should never disagree in history.

---

## Things that will bite

**A `.po` beside the exe overrides the embedded one.** `languages\<lang>\tr4w.po` next
to `tr4w_fpc.exe` wins. That is deliberate — it lets a corrected translation be dropped
onto an installation without a rebuild — but during testing it means you can be looking
at a stale file and not know. The log line says which was used; read it.

**Not everything on screen is translatable yet.** Tool-window titles come from the
Win32 menu rather than the form, so they stay English until the `RC_` constants become
resourcestrings. Roughly twenty entries. If a translator asks why their work on a
window title has not appeared, that is why — see
[`ADDING_A_LANGUAGE.md`](ADDING_A_LANGUAGE.md) section 6.

**Renaming an identifier orphans its translation in every language.** The key is the
name, not the English. Rewording the English is safe — the entry goes "Needs work" and
the translator re-checks it. Renaming is not.
