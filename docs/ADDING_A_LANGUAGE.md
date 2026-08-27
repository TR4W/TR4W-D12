# Adding a language to TR4W

Step by step. Read [`I18N_PLAN.md`](I18N_PLAN.md) first for *why* it is shaped this way;
this document is the recipe.

**Status 2026-08-26.** Steps 1–5 are proven in the real binary. **Step 6 does not work
yet** and is written up honestly below rather than left for the next person to discover.

---

## What you are producing

One `.po` per language, keyed by identifier, loaded at run time so a single binary speaks
every language. Nothing is recompiled per language and nothing is hand-edited in Pascal.

```
resourcestring  ->  <unit>.rsj  ->  rstconv  ->  .po  ->  SetDefaultLang  ->  translated UI
```

---

## 1. Get the English catalogue

The strings live in two mechanisms, and both end up in the same `.po`.

```bash
# the legacy TC_/RC_ tables -> .po
python tools/i18n/pas2po.py

# resourcestrings -> .po, via the compiler's own table
rstconv -i build-out/app-i386-win32/uAppStrings.rsj -o uAppStrings.po -f po
```

`rstconv.exe` ships with FPC (`C:\FPC\3.2.2\bin\i386-Win32`). It reads the `.rsj` the
compiler writes beside the object file — **build first**, or you are extracting a stale
table.

## 2. Add the language

```bash
python tools/i18n/pas2po.py            # writes i18n/tr4w_<code>.po for each known language
```

A language with no `tr4w_consts_<lang>.pas` takes the *generate* path rather than the
surgical-rewrite path; see the tooling README for the worked Italian example.

Use the **two-letter code** (`es`, `de`, `ja`), not the legacy three-letter `LANG_xxx` name.
The code is what `SetDefaultLang` matches and what the directory is named.

## 3. Seed the gaps, but never the finished work

```bash
python tools/i18n/mt_seed.py --lang es
```

`mt_seed` touches **only entries that are both fuzzy and empty**, its output stays fuzzy,
and `po2pas.py` skips fuzzy entries. Clearing the fuzzy flag is a human's review, and that
is what makes an entry usable.

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

The catalogue is found **relative to the EXECUTABLE, not the working directory.** This is
the single most likely reason a correct translation appears to do nothing.

```
<dir containing tr4w.exe>/languages/<code>/tr4w.po
<dir containing tr4w.exe>/locale/<code>/tr4w.po      (also searched)
```

The file name is pinned to `tr4w.po` in `uProgramMain`, not defaulted, because the default
is the *executable's* name — the shipped `tr4w.exe` and the developer's `tr4w_fpc.exe`
would look for different files.

```powershell
tr4w.exe mycontest.cfg --lang es
```

`--lang` is honoured by the LCL itself, then the OS locale. **A TR4W setting should
override both and does not exist yet** — an operator on Spanish Windows does not
necessarily want a Spanish contest log.

Check the log. It says which it loaded, and says so when it loaded nothing:

```
UI language: loaded translations for "es"
UI language: no translation loaded; using the compiled-in English
```

An absent `.po` is not an error — English is the compiled-in default — so without that line
a missing or misnamed catalogue is indistinguishable from a working English build.

### Verified

With one entry translated in `languages/es/tr4w.po`:

```
no --lang   SIniRetireTitle = Old settings file
--lang es   SIniRetireTitle = Archivo de configuracion antiguo
```

---

## 6. Form captions

**They translate. The child controls translate today; the tool-window TITLES do not, and the
reason is not the translation mechanism.**

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

### The fix is already in the plan

**Convert `RC_FKEYS` and its siblings to resourcestrings.** They are among the 163
code-reachable `RC_` constants listed in [`I18N_PLAN.md`](I18N_PLAN.md). Once the menu text is
translated, the title inherits it and the sync is preserved. No change to `OpenTR4WWindow`.

**The menu conversion is a different job and is NOT on this path.** `tr4w_main_menu` is still an
`HMENU`, there is no `TMainMenu` or `TActionList` in the tree, and the `10199 + Ord(ID)`
arithmetic works because the IDs are still real. Replacing that with a `TActionList` is
recorded, worthwhile, and much larger -- and doing it *after* the constants are resourcestrings
means it inherits translated captions instead of having to redo them.

**Consequence for translators:** the `.lfm` caption of a tool window is dead text. It is in the
catalogue because Lazarus extracted it, and translating it changes nothing until the `RC_`
conversion lands. Roughly twenty entries.

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

## Gotchas

* **`.po` beside the EXE.** Not the working directory. Cost the first attempt.
* **Never rename an identifier.** It is the translation key; a rename orphans the
  translation in every language, silently. Rewording the *English* is safe — the entry goes
  `#, fuzzy` and a translator re-checks it.
* **`src/lang/*.pas` are UTF-8 with a BOM** and per-language codepages. Do not edit them
  with a tool that rewrites the encoding; append ASCII bytes or use `po2pas.py`.
* **A stale `.rsj` extracts stale strings.** Build before `rstconv`.
* **Machine output must stay fuzzy.** It is the only thing keeping it out of the build.
