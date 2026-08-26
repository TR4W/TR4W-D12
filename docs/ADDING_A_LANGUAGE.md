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

## 6. Form captions — DOES NOT WORK YET

**Read this before spending a day on it. It has already cost one.**

469 of 545 `.lfm` captions ship as English, so this is the largest block of untranslated
text in the program, and the mechanism below is the intended route to it.

### THE MECHANISM WORKS. THE PROBLEM IS TR4W-SPECIFIC.

Proven 2026-08-26 in a minimal LCL application — one form, one button, the *same*
`SetDefaultLang('', '', '<name>.po', False)` call before any form exists, and a `.po` at
`languages/es/<name>.po`:

```
--lang es -> lang=es  form.caption=Hola Espanol  button.caption=Pulsame
```

Both the form's own caption and a child control's, from keys spelled exactly
`tform1.caption` and `tform1.button1.caption`. **So the format, the file layout, the call
and the LCL are all correct**, and the reason TR4W does not translate is something TR4W
does differently. Candidates, in the order worth checking:

1. **When its forms are created.** The minimal app calls `Application.CreateForm`
   immediately after `SetDefaultLang`, in the program body. TR4W creates its tool windows
   much later, queued onto the message loop after `Application.Run` — see the deferred
   restore in `MainUnit`. A form streamed after the translator is installed *should* still
   pick it up, but that is the biggest structural difference and it is untested.
2. **Whether something overwrites the caption after streaming.** `OpenTR4WWindow` and the
   window manager came from the Win32 era, where titles were set with `SetWindowText`.
   A caption assigned after the form is streamed defeats translation silently.
3. **Whether `LRSTranslator` is still assigned** at the moment the form is created.

The isolation project is the tool for all three: add to it whatever TR4W does differently,
one thing at a time, until it stops translating. That is a much cheaper loop than probing
the real program.

### What else is established

* The runtime path **exists and is installed**. `SetDefaultLang`'s `.po` branch does
  `LocalTranslator := TPOTranslator.Create(lcfn)` and then `LRSTranslator := LocalTranslator`
  (`lcl/lcltranslator.pas`). One catalogue covers resourcestrings *and* form properties;
  no extra wiring is needed.
* Captions **qualify for translation**: `GetIdentifierPath` gates on
  `PropInfo^.PropType = TypeInfo(TTranslateString)`, and `TCaption = TTranslateString`.
* The **key format is confirmed** from Lazarus's own shipped catalogues
  (`components/lazreport/samples/editor/languages/calleditorwithpkg.es.po`):

```
#: tfrmmain.caption                <- the form's own caption
#: tfrmmain.accclose.caption       <- a child control
msgctxt "TFRMMAIN.ACCCOMPOSITE.CAPTION"   <- some entries also carry this, uppercase
```

  That is `t<formclass>.<component>.<property>`, lowercased. `translations.pas` reads the
  `#:` line, **normalises a colon to a dot** ("the RTL creates identifier paths with point
  instead of colons") and matches on `IdentifierLow`.

### What does not work

With the `.po` demonstrably loaded — the resourcestring in the same file translates — a
form caption does **not**. Tried against `TfrmFunctionKeys`, whose title comes from its
`.lfm` and is not reassigned in code:

| tried | result |
|---|---|
| `#: tfrmfunctionkeys.caption` | no change |
| `#: frmfunctionkeys.caption` | no change |
| `#: tfrmfunctionkeys.frmfunctionkeys.caption` | no change |
| `#: ufunctionkeysform.tfrmfunctionkeys.caption` | no change |
| the correct key plus `msgctxt "TFRMFUNCTIONKEYS.CAPTION"` | no change |
| a second `SetDefaultLang(..., ForceUpdate := True)` after the windows are open | no change |
| clean single-entry file, no duplicate msgids, no BOM | no change |

### lazbuild does NOT generate the catalogue

Worth knowing before you try: **`lazbuild` does not run the i18n step.** With
`<EnableI18N Value="True"/>` and `<OutDir Value="languages"/>` set exactly as Lazarus's own
sample project has them, `lazbuild -B` compiled cleanly and produced **no `.lrj` and no
`.po`**. That generation is IDE-only.

`.lrj` is the same JSON as `.rsj` — `{"name":"tmainform.caption","value":"Translation demo"}`
— and Lazarus checks the generated files into its own tree beside the `.lfm`. So a
command-line pipeline has to produce them itself. TR4W already has the parsing half of that
(`pas2res.py` walks `.lfm` files today for the caption census), so extending `pas2po.py` to
emit `.lfm` captions is the practical route, not chasing `lazbuild`.

### What to try next, in this order

1. ~~Isolate the mechanism from TR4W.~~ **DONE — it works.** See above. The format, the
   file layout, the call and the LCL are all correct.
2. ~~Let Lazarus generate the catalogue through `lazbuild`.~~ **DONE — it cannot.** The
   i18n step is IDE-only; `lazbuild -B` produces no `.lrj` and no `.po`.
3. **Find what TR4W does differently**, using the isolation project rather than the real
   program: add one difference at a time until it stops translating. Start with *when* the
   form is created — TR4W queues its tool windows onto the message loop, long after
   `SetDefaultLang` — then look for a caption assigned after streaming.
4. **Extend `pas2po.py` to emit `.lfm` captions** once step 3 explains the failure. TR4W
   already parses `.lfm` files for the caption census, and `lazbuild` will not do it for
   us, so this is the practical route to the 469.
5. Only then consider moving captions into resourcestrings assigned at run time. It is the
   hand-rolled alternative to what the framework already does, it means touching every
   form, and it is what [`I18N_PLAN.md`](I18N_PLAN.md) argues against.

---

## Gotchas

* **`.po` beside the EXE.** Not the working directory. Cost the first attempt.
* **Never rename an identifier.** It is the translation key; a rename orphans the
  translation in every language, silently. Rewording the *English* is safe — the entry goes
  `#, fuzzy` and a translator re-checks it.
* **`src/lang/*.pas` are UTF-8 with a BOM** and per-language codepages. Do not edit them
  with a tool that rewrites the encoding; append ASCII bytes or use `po2pas.py`.
* **A stale `.rsj` extracts stale strings.** Build before `rstconv`.
* **Machine output must stay fuzzy.** It is the only thing keeping it out of the build.
