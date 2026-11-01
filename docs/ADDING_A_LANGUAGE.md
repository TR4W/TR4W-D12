# Adding a language to TR4W

Step by step. Read [`I18N_PLAN.md`](I18N_PLAN.md) first for *why* it is shaped this way;
this document is the recipe.

~~**Status 2026-08-26.** Steps 1–5 are proven in the real binary. **Step 6 does not work
yet**~~

**Status 2026-11-01.** Steps 1–6 hold. The gap that step 6 described is closed, as
shown from the code (see section 6): tool-window titles come from menu captions, and those
captions are now resourcestrings. Nobody has yet looked at a translated title on a running
screen to confirm it. One known gap remains for form captions: a caption added after the
form was last saved in the Lazarus IDE reaches no catalogue (issue #145).

---

## What you are producing

One `.po` per language, keyed by identifier, loaded at run time so a single binary speaks
every language. Nothing is recompiled per language and nothing is hand-edited in Pascal.

```
resourcestring  ->  <unit>.rsj  ->  rstconv  ->  .po  ->  SetDefaultLang  ->  translated UI
```

---

## 1. Get the English catalogue

**There is no `i18n/tr4w_en.po`, and nothing should make one** (deleted 2026-10-21). English
is the `msgid` every catalogue already carries, and the program loads no catalogue for its
compiled-in language. "The English catalogue" here means the TEMPLATE -- the strings below,
and `tr4w/languages/tr4w_laz.pot` for the `.lfm` captions. English's name in Preferences
("English (en)") is `uEmbeddedTranslations.COMPILED_IN_LANGUAGE_NAME`.

**And not every caption is a string.** `F1`, `8`, `...` are not language and never become a
catalogue entry -- `pofile.is_translatable` is the rule, and `po_merge` and `pas2po` both ask
it. The form keeps its `.lfm` text, which is what an untranslated property shows anyway.

The strings live in two mechanisms, and both end up in the same `.po`. The templates are:

- **`.lfm` captions and the generated `uTR4WStrings`:** `tr4w/languages/tr4w_laz.pot`,
  which the Lazarus IDE regenerates when it resaves forms (issue #145 covers what it misses).
- **New resourcestrings (`uAppStrings`):** a scratch `.pot` made by
  `C:\Lazarus\tools\updatepofiles.exe` from the `.rsj` that FPC writes on every build.
  **Build first**, or you are extracting a stale table. The exact recipe is in
  `I18N_TOOLS.md`, *Refresh the catalogues*. Never point `updatepofiles` at `tr4w_laz.pot`.

~~`python tools/i18n/pas2po.py`~~ and ~~`rstconv ... -o uAppStrings.po -f po`~~ stood here.
The first is the destructive whole-catalogue rebuild, which now refuses. The second writes
a catalogue directly instead of a template that `po_merge` can apply.

## 2. Add the language

```bash
python tools/i18n/pas2po.py --new-lang <LANG> --code <xx>   # writes i18n/tr4w_<xx>.po, all fuzzy
python tools/i18n/po_merge.py --pot tr4w/languages/tr4w_laz.pot --apply   # THEN the form + resourcestring half
```

**Both lines, in that order.** `pas2po --new-lang` writes only the `TC_` table. Without the
merge, the new language silently lacks every form string. Then merge any scratch `.pot`
of resourcestrings newer than `tr4w_laz.pot`, as in step 1.

~~`python tools/i18n/pas2po.py`~~ with no `--new-lang` rebuilds EVERY catalogue from the
`TC_`/`RC_` tables alone, which deletes the `.lfm` and resourcestring entries (2,203
translations, 2026-08-29); it now refuses rather than doing so. It never writes English.
Existing catalogues take new strings from `po_merge.py --pot`.

A language with no `tr4w_consts_<lang>.pas` takes the *generate* path rather than the
surgical-rewrite path; see the tooling README for the worked Italian example.

Use the **two-letter code** (`es`, `de`, `ja`), not the legacy three-letter `LANG_xxx` name.
The code is what `SetDefaultLang` matches and what the directory is named.

## 3. Seed the gaps, but never the finished work

```bash
python tools/i18n/mt_seed.py --lang es
```

`mt_seed` touches **only empty entries**. ~~both fuzzy and empty~~: Poedit strips the flag
from an empty entry, so emptiness is the whole condition. A `# mt-seed: skip -- <reason>`
comment keeps an entry out for good (see `I18N_TOOLS.md`). Its output stays fuzzy, and
`po2pas.py` skips fuzzy entries. Clearing the fuzzy flag is a human's review.

**It no longer keeps the entry out of the BUILD, though** (2026-09-21, NY4I): the embedded
catalogue ships fuzzy entries with the flag stripped so the languages can be exercised while
they are reviewed. `Make-LanguageRes.ps1 -ReviewedOnly` restores the gate.

**Never re-run a generator across entries that already have translations.** ~417 strings
are native-speaker work. NY4I, 2026-08-26: *"we do not want to re-translate already
completed items."*

## 4. Send the translator the `.po`, not the Pascal

Poedit. They never see source, and they cannot damage the key structure — the key is the
`msgctxt`/`#:` pair, which Poedit does not expose for editing.

**Before you send anything, check the catalogue is complete.** The corpus grows as strings
move out of `.lfm` files; handing over an incomplete file means the same dialogs get
reviewed twice.

## 5. Install and run it

**The catalogue is EMBEDDED in the executable** (`tr4w/res/tr4w_languages.res`, RCDATA
`TR4W_<CODE>`). `Build-App.ps1` regenerates it whenever an `i18n/tr4w_*.po` changes
(2026-10-16). So installing a language means building, and then committing the `.res`
together with its `.res.inputs`. Nothing needs to be copied beside the exe.

~~The catalogue is found relative to the EXECUTABLE~~. That was `SetDefaultLang`'s rule
(2026-08). A **loose** file still wins over the embedded copy, for testing or as a patch,
but it is located by `uAppPaths.DataFilePath`:

```
languages/<code>/tr4w.po     Windows: the WORKING directory
                             macOS:   TR4W.app/Contents/Resources/
                             Linux:   /usr/share/tr4w/, else the binary's directory
```

~~`locale/<code>/tr4w.po` (also searched)~~: only `languages/` is searched. A loose file
is read by LazUtils with its run-time fuzzy gate intact, so it shows reviewed entries only.
A stale one silently hides the embedded catalogue, which makes it the likeliest reason a
correct translation appears to do nothing.

```powershell
tr4w.exe mycontest.cfg --lang es
```

The precedence is `--lang`, then the **Language** setting (Preferences › Appearance,
`DISPLAY LANGUAGE`), then the OS, then English. A new language shows up in that
drop-down on its own: the list is read from the catalogues embedded in the binary, so
there is nothing to add by hand.

Check the log. It says which it loaded, and says so when it loaded nothing
(`uEmbeddedTranslations`, `uProgramMain`):

```
UI language: "es" selected by <source>, loaded from the embedded catalogue
UI language: "es" selected by <source>, loaded from <path> (overriding the embedded catalogue)
UI language: none loaded; using the compiled-in English
```

An absent `.po` is not an error — English is the compiled-in default — so without that line
a missing or misnamed catalogue is indistinguishable from a working English build.

### Verified (2026-08, with a loose file under `SetDefaultLang`)

With one entry translated in `languages/es/tr4w.po`:

```
no --lang   SIniRetireTitle = Old settings file
--lang es   SIniRetireTitle = Archivo de configuracion antiguo
```

---

## 6. Form captions

**They translate. Since 2026-09-07 that includes the tool-window titles, as shown from
the code. Nobody has yet confirmed a translated title on a running screen.**

**Current state (2026-11-01).** The title is still set from the window's menu row:
`OpenTR4WWindow` does `lclForm.Caption := TCaption(menuTitle)`, where
`menuTitle := MenuCaption(10199 + Ord(ID))`. But the menu has been a **`TMainMenu`** since
`de8e1ccf` (2026-09-07), and `uMenu.InitializeMenuText` fills its captions from
resourcestrings (`T_MENU_ARRAY[i].mrText := RC_FKEYS`). The `TC_`/`RC_` constants have been
resourcestrings in `uTR4WStrings` since `1ee6b50f` (2026-08-27). `uProgramMain` calls
`InitializeMenuText` *after* `LoadEmbeddedTranslation`, so the menu row, and with it the
title, carries the translated text. The catalogues carry the key (`#: utr4wstrings.rc_fkeys`).
The fix proposed below ("convert `RC_FKEYS` and its siblings to resourcestrings") is
therefore made. The menu/title sync it was meant to preserve is preserved.

What remains open for form captions is **issue #145**. A caption reaches the template only
through the `.lrj` that the IDE writes when it saves a form. So a control added since the
last save is in no catalogue and shows in English everywhere. Example: `uPrefsForm`'s
`lblLanguage`.

The rest of this section is the **2026-08-26 investigation, kept as history**. Its code
snippets (`GetMenuStringW`, `HMENU`, "no `TMainMenu` in the tree") no longer describe the
tree.

### What works

Everything the LCL does. Proven 2026-08-26 in TR4W itself, with the real generated catalogue
and a probe either side of form construction:

```
at form creation : LRSTranslator = True, caption = PROBE-CAPTION-OK   <- translated
after OwnForm    : caption = PROBE-CAPTION-OK
after Handle     : caption = PROBE-CAPTION-OK
at OnShow        : caption = Function keys                            <- overwritten
```

So the `.po` loads, `LRSTranslator` is installed, the key matches, the LFM streams and the
caption comes out **in Spanish**. Buttons, labels, tab captions and list items all keep it —
that is the bulk of the 561 strings, and nothing further is needed for them.

### What overwrites the title, and why

`MainUnit.pas`, in `OpenTR4WWindow`, immediately after the form is built:

```pascal
if lclForm <> nil then
   begin
   lclForm.Caption := string(PWideChar(@menuText[0]));
   end
```

where `menuText` came from

```pascal
GetMenuStringW(tr4w_main_menu, 10199 + Ord(ID), menuText, ...)
```

**Every tool window is titled from its MENU ITEM**, and the menu is a Win32 `HMENU` built in
`uMenu.pas` from the legacy per-language constants — `(mrText: RC_FKEYS; mrId:
menu_windows_funckeys)`. So the translated caption is replaced by `RC_FKEYS`, which is compiled
in and never translated at run time.

**That assignment is not a bug and should not simply be deleted.** Its own comment records the
defect it fixes: a window that later sets its own caption assigns the same string it assigned
last time, `TControl.SetCaption` compares and does nothing, and the native title keeps whatever
was written before -- so the operator saw "Radio 1" on every reopen. Title and menu item are
meant to stay in step.

### ~~The fix is already in the plan~~ The fix is made (see the current state above)

**Convert `RC_FKEYS` and its siblings to resourcestrings.** They are among the 163
code-reachable `RC_` constants listed in [`I18N_PLAN.md`](I18N_PLAN.md). Once the menu text is
translated, the title inherits it and the sync is preserved. No change to `OpenTR4WWindow`.

**The menu conversion is a different job and is NOT on this path.** `tr4w_main_menu` is still an
`HMENU`, there is no `TMainMenu` or `TActionList` in the tree, and the `10199 + Ord(ID)`
arithmetic works because the IDs are still real. Replacing that with a `TActionList` is
recorded, worthwhile, and much larger -- and doing it *after* the constants are resourcestrings
means it inherits translated captions instead of having to redo them.

**Consequence for translators:** the `.lfm` caption of a tool window is dead text. It is in the
catalogue because Lazarus extracted it, but the title on screen is the menu row's text. That
is the `RC_` entry, which now translates. Some catalogues file both keys on one entry
(`#: tfrmfunctionkeys.caption utr4wstrings:rc_fkeys`). ~~translating it changes nothing
until the `RC_` conversion lands~~.

### What was eliminated getting here

Recorded so nobody repeats it. None of these was the cause:

| tested | result |
|---|---|
| Late form creation, queued onto the loop as TR4W does | still translates |
| `Application.Initialize` before `SetDefaultLang`, TR4W's order | still translates |
| `TForm.Create(nil)` instead of `Application.CreateForm` | still translates |
| Four candidate identifier spellings | the first was right all along |
| An uppercase `msgctxt` beside the `#:` line | no effect either way |
| A second `SetDefaultLang` with `ForceUpdate := True` | no effect |
| Hand-written vs tool-generated catalogue | same result |

Two process notes worth more than the list:

* **The isolation project found in minutes what a day of probing the real program did not.**
  Build a minimal LCL app, add ONE TR4W difference at a time, and stop when it breaks.
* **Every run needs a positive control.** The run that finally located this had a
  resourcestring and a caption translated in the SAME catalogue: the resourcestring changed and
  the caption did not, which is what proved the catalogue was applied and narrowed the search to
  the form path. Earlier runs had no control and could not distinguish "not applied" from
  "applied and overwritten".

### lazbuild does not generate the catalogue

`lazbuild -B` compiles clean and writes no `.lrj` and no `.po`, with `EnableI18N` and `OutDir`
set exactly as Lazarus's own sample project has them. The step is IDE-only:
`ide/sourcefilemanager.pas` writes the `.lrj` inside `SaveUnitComponent`, i.e. when a form is
**saved**, never when one is built.

Three clean builds produced nothing. What does it is the project option **"Resave forms with
enabled i18n"**, which saves every form once. All 37 units must also carry
`ComponentName`/`ResourceBaseClass` in the `.lpi` first -- only 19 did, and the IDE extracts
captions only from units it knows are forms.

**This is still true, and it is issue #145.** Until a harvest that does not need the IDE
exists, every new or renamed `.lfm` caption needs either an IDE resave or a key added by
hand to a merge template (as was done for `chkNetAutoConnect`, `74a50e27`). Resourcestrings
do not have this problem: `updatepofiles` on the `.rsj` is enough (`docs/I18N_TOOLS.md`).

## Gotchas

* ~~**`.po` beside the EXE.** Not the working directory.~~ The catalogue is embedded. A
  loose override is found through `uAppPaths.DataFilePath`, which on Windows is the working
  directory (section 5).
* **Never rename an identifier.** It is the translation key; a rename orphans the
  translation in every language, silently. Rewording the *English* is safe — the entry goes
  `#, fuzzy` and a translator re-checks it.
* **`src/lang/*.pas` are UTF-8 with a BOM** and per-language codepages. Do not edit them
  with a tool that rewrites the encoding; append ASCII bytes or use `po2pas.py`.
* **A stale `.rsj` extracts stale strings.** Build before `rstconv`.
* **Machine output must stay fuzzy in the `.po`.** ~~It is the only thing keeping it out of
  the build~~ -- the build ships it anyway since 2026-09-21 (see section 3); the flag is now
  the review record, not the gate.
