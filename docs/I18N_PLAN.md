# TR4W internationalisation — the plan and the decisions behind it

~~**Status 2026-08-26.** The mechanism is proven end to end; the content is not moved.~~

**Status 2026-11-01.** One binary carries every language. The `TC_`/`RC_` constants have
been resourcestrings since `1ee6b50f` (2026-08-27). The `.lfm` captions are harvested into
the catalogues. 21 catalogues are embedded in the executable, and the build regenerates them
(2026-10-16). Unreviewed (fuzzy) entries ship as well (2026-09-21). What is **not** done is
the human review. See [Catalogue state](#catalogue-state-2026-11-01) and
[Open tooling issues](#open-tooling-issues).

This is the single place the i18n decisions live. Where it summarises something, the tooling
in **`tools/i18n/`** (in this tree, with its `README.md`) is authoritative. It is no longer a
separate worktree: ~~`c:/tr4w-i18n`, branch `i18n-ts-poc`~~.

---

## Where this came from

TR4W translates by **compiling a different binary per language**: one `TC_` constant per
string in `src/lang/tr4w_consts_<LANG>.pas`, selected by a `LANG_xxx` define. Nine
binaries, nine constant files that drift, each an ANSI file in its own codepage — 1251
Russian, 1250 Czech and Serbian, 1252 German — so a file that loses its BOM silently
corrupts.

The replacement is **`resourcestring` and one binary per platform** (NY4I, 2026-08-13),
translated at run time from a `.po`. Resource DLLs are out: no FMX/macOS/Linux equivalent.

The English constants files are **not hardcoded English that needs replacing**. A
`resourcestring` is the *default value* and the *source text a translator reads*; the
**identifier** is the key. That distinction governs everything below.

---

## What is decided

### The key is the identifier, and it must never be renamed

The catalogues carry two keys per entry, and both are the identifier:

```
#: utr4wstrings:tc_telnet_connect      <- what the RUN TIME matches on
msgctxt "TC_TELNET_CONNECT"            <- what po2pas.py and gettext match on
msgid   "Connect"                      <- the English source text
msgstr  "Conectar"                     <- the translation
```

**Renaming an identifier orphans its translation in every language, silently.** Rewording
the *English* does not: the key is unchanged, the `hash` no longer matches, and the entry
is flagged `#, fuzzy` for review. That asymmetry is the whole reason names were kept.

So `TC_`/`RC_` names are **kept** as they move to `resourcestring`, even though
`uAppStrings.pas` states the convention `S<Area><Thing>` and "no TC_ prefix". That
convention governs strings written new. `TC_`/`RC_` now means *carried over from the
legacy tables*, which is readable provenance rather than a wart.

> NY4I, 2026-08-26: *"the critical part is that we do not want to re-translate already
> completed items. Most of this translation was done by native speakers."*

If a rename is ever genuinely needed it must **carry** the translation — rewrite `msgctxt`
and `#:` and keep `msgstr` in one pass. Never rename in Pascal and regenerate.

### `.po` is the master format

Chosen on two grounds: FPC/Lazarus load `.po` at run time, and Poedit is a gettext tool
that bundles `msgfmt`/`msgmerge` for real validation and real fuzzy-matching. An earlier
pass used Qt Linguist `.ts`; it worked but needed a conversion step in the build forever.

### UI strings are embedded; help text is co-located

| | where | why |
|---|---|---|
| **UI strings** (~640, 16 langs, ~1 MB) | **embedded in the exe** | needed at startup before any file I/O; small; changes only when code changes; a missing file would mean a silently English UI |
| **Help text** (10 langs, 2.2 MB) | **`.po` beside the exe** | read on demand; twice the size of everything else; updated on its own cadence — a wording fix should not need a rebuild |

Measured 2026-08-26 (historical, sixteen catalogues and ~640 strings): the exe is 5.6 MB with one language. All sixteen catalogues add
**1.4 MB raw, or 1.0 MB** trimmed of `#.` notes and the `pas2po` source references (which
end in a line number and no run time reads). **6.6 MB covers sixteen languages** where
today 5.6 MB covers one and nine languages means nine builds.

**Measured 2026-11-01:** `tr4w/res/tr4w_languages.res` is **5,171,624 bytes**. It holds 21
TR4W catalogues of about 1,390 entries each, with fuzzy entries included, plus the Lazarus
`lclstrconsts` catalogues that `Make-LanguageRes.ps1` embeds next to them. Re-measure with
`ls -l tr4w/res/tr4w_languages.res`. The 2026-08-26 figures above are from a corpus
roughly a third of today's size.

Lazarus supports the embedded path directly — `TPOFile.Create(AStream)`, whose own comment
reads *"when loading from internal resource Full needs to be False"*.

**Since 2026-11-02 the help catalogues ARE read** -- as tooltips, by
`src/uCommandHelp.pas` (step 9). The paragraph below is the state before that.

**The help side is greenfield.** `uOption.pas`, the Ctrl-J dialog that read
`commands_help_<LANG>.ini`, was deleted in `4321ce1d`. Preferences has no help pane,
nothing in `src` reads `TR4W_COMM_HELP_FILENAME` — it is still assigned in `fcontest.pas`
and never consumed — and **7 help INIs still ship in `target/`, unread**. There is no
existing behaviour to preserve, so the format is a free choice, and `.po` puts translators
in one tool for both halves.

### Language selection is a TR4W setting, not the OS locale

**Done 2026-09-19.** Preferences › Appearance has a **Language** drop-down: "System
default" plus each catalogue the binary carries. That is `Settings.Display.Language`, and
the command is `DISPLAY LANGUAGE`. The precedence is `--lang`, then the setting, then the
OS, then English (`uUILanguage.ChooseUILanguage`). The setting is read from `tr4w.json`
before the settings object loads, so a change takes effect at the next start. On macOS
the OS language is now the user's *preferred* language: a Finder launch has no `LANG`,
and the LCL's own fallback reads the region locale. See `.claude/agents/i18n.md`.

### macOS: the per-app language picker, and what it needs from the bundle

**Done 2026-09-20.** System Settings › General › Language & Region › Applications lets an
operator choose a language for one app. Until now macOS answered *"TR4W doesn't support
additional languages"* (NY4I, on `mac-ci`), and the reason was not the code: macOS only
offers an app in that list if the **bundle declares its localizations**, through
`CFBundleLocalizations` in `Info.plist` or `.lproj` directories under `Contents/Resources`.
TR4W has no `.lproj` and never will — its catalogues are `.po` files compiled into the
executable as RCDATA, which Cocoa cannot see — so nothing told macOS what we speak.

`TR4W.app/Contents/Info.plist` now carries `CFBundleLocalizations` (22 tags) and
`CFBundleDevelopmentRegion` (`en`). **The list is derived, never typed**: the Darwin arm of
`tr4w/build/build-unix.sh` reads the resource names out of `tr4w/res/tr4w_languages.res` —
the `.res` that is `{$R}`-linked into the binary — so it cannot claim a language the
executable does not carry. **English is the exception, added rather than read** (2026-10-21):
it is the compiled-in language and has no catalogue since `tr4w_en.po` was deleted, so the
`.res` holds 21 names and the plist still declares 22 tags. Apple's spelling differs from our catalogue keys in two places
and both are inverses of `uUILanguage.SystemLanguageCode`: `pt_BR` is declared `pt-BR`, and
`zh_CN` is declared **`zh-Hans`**, because macOS identifies Chinese by script rather than by
country.

**No other code change was needed, but one was found.** The picker writes the choice into
the app's own preferences domain, which is exactly what `CFLocaleCopyPreferredLanguages`
reads, so `SystemUILanguage`'s Darwin arm already sees it. What it then did with the answer
was wrong for the two region-qualified tags: it took the language half only, so `pt-BR`
became European Portuguese and `zh-Hans` became `zh`, for which there is no catalogue — the
picker would have looked as though it worked and the run would have been in English. That
arm calls `SystemLanguageCode` now. Verified on `mac-ci`, four languages end to end:

```
UI language: "es"    selected by the macOS preferred language (es)
UI language: "pt_br" selected by the macOS preferred language (pt-BR)
UI language: "zh_cn" selected by the macOS preferred language (zh-Hans)
UI language: "de"    selected by the macOS preferred language (de)
```

**THE IN-APP SETTING WINS, SO IT MUST BE "SYSTEM DEFAULT" FOR THE PICKER TO DO ANYTHING.**
The precedence above is unchanged — `--lang`, then `Settings.Display.Language`, then the OS.
An operator who has chosen a language in Preferences › Appearance has chosen it *instead of*
the OS, and the macOS picker will appear to be ignored. That is deliberate, not a defect:
the setting exists precisely because a Mac started from Finder gets no command line. Either
control works; they are not meant to be used together.

Serbian is declared `sr`, not `sr-Latn`, although our catalogue is in Latin script. Both
resolve to the same catalogue; nobody has yet confirmed how the macOS picker labels either.

### `LCLTranslator`, not `DefaultTranslator`

`DefaultTranslator` is a 24-line unit whose entire body is
`SetDefaultLang('', '', '', false)` in an `initialization` section. It takes the choice
away and hides where it happens. TR4W calls the real entry point, in the startup sequence,
where it can be read, ordered and logged.

The catalogue name is **pinned to `tr4w.po`**. Defaulted it is the *executable's* name, and
this program ships as `tr4w.exe` but builds as `tr4w_fpc.exe` — the developer binary would
silently find nothing and look like a translation bug.

---

## Where the strings are

**HISTORICAL. This was measured 2026-08-26, before the cut-over and the `.lfm` harvest.**
It is kept because it is the reasoning behind the plan. It is not today's state.
Today's counts are in [Catalogue state](#catalogue-state-2026-11-01). Since this was
measured, the `TC_` table and the code-reachable `RC_` were generated into `uTR4WStrings`
as resourcestrings, and that unit is in the build (`rg -c "^\s+RC_\w+\s*=" tr4w/src/uTR4WStrings.pas` gave 171 and `TC_` gave 472 on
2026-11-01). The `.lfm` row was harvested (step 8).

Measured 2026-08-26. Roughly **1,070** user-facing strings in three places, of which
**381** are translated.

| | count | state |
|---|---:|---|
| `TC_` in the language tables | 383 | translated in 16 languages |
| `RC_` reachable from Pascal code | 163 | **not** in any catalogue — new work |
| `RC_` appearing only in `res/Tr4w.rc` | 78 | deferred — see below |
| `RC_` referenced nowhere | 9 | dead |
| stranded consts, now `resourcestring` | 95 | **were** in no catalogue; fixed `95c7c532` |
| `.lfm` design-time captions | 469 | **not** in any catalogue — the largest block |

### Why the 78 `RC_` are deferred, not converted

Their text reaches the screen from the **compiled `.RES`**, not from the Pascal constant, so
declaring a `resourcestring` for one would translate nothing. `res/Tr4w.rc` `#include`s
`hotkeys.h` and `DEF.H`, **neither of which exists in this repo**, so the `.rc` cannot be
rebuilt to fix it there either.

They belong to Win32 dialogs still loaded from the `.res`. ~~69 `DialogBox`/`CreateDialog`
call sites remain~~: that 2026-08-26 count is not restated. Measure what is left with
`tr4w/build/Lint-Win32Dialogs.ps1 -Group ui`. **When a dialog becomes an LCL form its text moves into the `.lfm` and
its `RC_` entry retires by itself.** `RC_` is therefore not a separate workstream; it is a
by-product of finishing the dialog conversion.

### The `.lfm` captions are the big one, and they are a regression

**A converted window loses its translations, silently, and every conversion so far has.**
The Win32 code assigned captions from `TC_`/`RC_` constants; a designed form carries its
caption in the `.lfm`, and each conversion re-typed the English there and left the constant
behind. Telnet is the clearest case:

```
uTelnetForm.lfm   Caption = 'Connect'
catalogues        TC_TELNET_CONNECT   es='Conectar'   (now #~ obsolete)
```

Of 545 `.lfm` captions only **45** are assigned at run time; **469** ship as English. Only
**10** have an exact English match with an existing translation, so this really is ~459
strings of new work.

**These are not moved into resourcestrings.** Lazarus's own i18n extracts `.lfm` captions
to `.po` without anyone re-typing anything, and hand-lifting 469 captions into code would
be a hand-rolled version of what the framework does.

---

## The tooling

In **`tools/i18n/`** in this tree. ~~`c:/tr4w-i18n/tools/i18n`, on branch `i18n-ts-poc`.
Nothing in the build depends on it.~~ The build still runs none of these Python scripts.
What it does run is `tr4w/build/Make-LanguageRes.ps1`, through
`tr4w/build/LanguageResStamp.ps1`, from `Build-App.ps1` and `Build-Tests.ps1`. That happens
whenever the sha256 stamp in `tr4w/res/tr4w_languages.res.inputs` no longer matches the
`i18n/tr4w_*.po` files or the generator (2026-10-16). `build/check-language-res.sh` fails
a Linux or macOS build whose committed `.res` is stale. `Run-Lints.ps1` runs the CRLF lint
over `tools/`. The table below is not the complete list; `docs/I18N_TOOLS.md` has all of
them, including `po_merge`, `po_lint`, `po_dedupe`, `po_defuzz` and `salvage_lossy`.

| tool | does |
|---|---|
| `pasconsts.py` | the shared line-oriented parser for the language fragments |
| `pofile.py` | minimal `.po` reader/writer — `msgctxt`, `#,fuzzy`, `#.`, `#:`, `#~`; keeps `# ` and `#|` lines and the header. A rewrite is byte-identical except where a caller changed an entry (`test_pofile.py`) |
| `pas2po.py` | language tables → `.po`. **`--new-lang` only. NEVER use it to pick up new strings**: that dropped 2,203 translations on 2026-08-29. Use `po_merge --pot` |
| `po2pas.py` | `.po` → language tables, *surgical*; `--verify` proves byte-identical round-trip |
| `po_rekey.py` | adds the `#:` run-time identifier beside the `msgctxt` key |
| `pas2res.py` | English tables → `uTR4WStrings.pas`, 546 resourcestrings |
| `po_prune.py` | marks entries obsolete when their key leaves the source. **Unsafe on the real catalogues, issue #144** (see below) |
| `ini2po.py` | help INIs ⟷ `.po`, plus `--todo --write-doc` |
| `mt_seed.py` | libretranslate seeding |

~~**Machine output cannot reach a build.**~~ **IT DOES, SINCE 2026-09-21, AND THAT IS
NY4I'S DECISION** -- *"We want to show the non-reviewed as well for testing."*
`Make-LanguageRes.ps1` now embeds a fuzzy entry with its `#,` flag line stripped, which is
what gets it past LazUtils' run-time gate (`translations.pas:1223`, *"Load translation only
if it exists and is NOT fuzzy"*). Run it with `-ReviewedOnly` to put both gates back.

**The `.po` files are untouched and the flag still means what it meant.** `mt_seed.py`
touches only **empty** entries. ~~*both fuzzy and empty*~~ was the old rule; Poedit strips
the flag from empty entries, so emptiness alone is the condition. An entry can be kept out
with a `# mt-seed: skip -- <reason>` comment (`docs/I18N_TOOLS.md`). Its output stays fuzzy;
`po2pas.py` still skips fuzzy entries. Clearing the flag is still a human's review --
what changed is only what the BUILD does with an unreviewed entry, and it changed
because the languages are under review and NY4I needs to see them on a screen.

### ~~Translation state, 2026-08-26~~

~~417 strings per language~~. The 2026-08-26 table (es 1 fuzzy, de 101, pl 85, ...) was
taken before the `.lfm` harvest more than tripled the corpus. It is replaced by the table
below. ~~**Extract the captions before handing anything to translators.**~~ That has been
done (step 8).

### Catalogue state, 2026-11-01

Measured on `main` at `0371650c`, from `i18n/tr4w_*.po` as committed. Re-measure from the
repo root (bash):

```bash
for f in i18n/tr4w_*.po; do
   m=$(rg -c '^msgid ' $f)                       # minus 1 for the header entry
   z=$(rg -c '^#, .*fuzzy' $f)                    # the header carries no fuzzy flag
   e=$(rg -c -U '^msgstr ""\r?\n\r?$' $f)         # single-line empty msgstr only
   o=$(rg -c '^#~ msgid ' $f)
   echo "$f $((m-1)) ${z:-0} ${e:-0} ${o:-0}"
done
```

Or, for the fuzzy column alone, in either shell: `rg -c '^#, fuzzy' i18n -g 'tr4w_*.po'`.
It gives the same numbers.

| catalogue | entries (msgid) | fuzzy | empty msgstr | obsolete `#~` |
|---|---:|---:|---:|---:|
| cs | 1393 | 903 | 53 | 0 |
| da | 1393 | 1392 | 55 | 0 |
| de | 1393 | 970 | 53 | 0 |
| el | 1393 | 1392 | 55 | 0 |
| es | 1393 | 857 | 51 | 0 |
| fi | 1393 | 1392 | 55 | 0 |
| fr | 1393 | 1391 | 53 | 0 |
| it | 1393 | 1374 | 53 | 0 |
| ja | 1393 | 1392 | 54 | 0 |
| ko | 1393 | 1392 | 54 | 0 |
| mn | 1393 | 910 | 847 | 0 |
| nl | 1393 | 1392 | 54 | 0 |
| pl | 2285 | 1609 | 52 | 0 |
| pt | 1393 | 1392 | 54 | 0 |
| pt_BR | 1393 | 1392 | 55 | 0 |
| ro | 1393 | 943 | 53 | 0 |
| ru | 1393 | 910 | 53 | 0 |
| sr | 1393 | 889 | 847 | 0 |
| sv | 1393 | 1392 | 55 | 0 |
| uk | 1393 | 905 | 52 | 0 |
| zh_CN | 1389 | 1388 | 55 | 0 |

The columns are raw counts. `entries - fuzzy` is **not** the reviewed count, because a
non-fuzzy entry can still be empty. `fuzzy` means unreviewed. Since 2026-09-21 those entries
ship anyway, by NY4I's decision; the flag is the review record, not a gate. **Do not defuzz
to make this table look better.** `zh_CN` in particular holds salvaged text that must stay
fuzzy (see `.claude/agents/i18n.md`). `tr4w/res/tr4w_languages.res.inputs` matched all 21
catalogues and both generator scripts on the same date, so the committed `.res` is current.

**The review pass is planned, not started.** NY4I, 2026-10-22: i18n will be reviewed, with
Weblate, *after the contest factory is complete*. The factory has been in `main` since
5.0.30. That is not the same as complete, so the trigger has not fired. Until then
catalogue questions are parked. A change that adds strings still adds them to every
catalogue, so a build never loses a caption.

### Open tooling issues

- **#144: there is no safe way to retire a string that has left the code.**
  `po_prune.py` decides "dead" from the `TC_`/`RC_` tables alone. Its dry run would have
  marked **2,168 live entries** obsolete: every `.lfm` and resourcestring key, 391 of them
  in Polish. It was not applied. Even if it had been, `po_merge --apply` **deletes every
  `#~` block** by design, so a reviewed translation that was marked obsolete would be gone
  at the next merge. `po_merge` also leaves a live entry in place after its resourcestring
  has been removed. **Do not run `po_prune.py` on the real catalogues** until #144 is fixed.
  The one retirement so far (`SContestNotOnMultiOp`, `069fe64c`) was done by a targeted
  script that writes through `pofile`'s lossless writer.
- **#145: `.lfm` captions added since the last IDE save reach no catalogue.** A form's
  captions reach the template through the `.lrj` that only the Lazarus IDE writes, and only
  when it saves the form. So a control added or renamed since then has no key. Example:
  `uPrefsForm.lfm` `lblLanguage` / `lblLanguageHint`, whose `.lrj` dates from 2026-08-31.
  Those captions show in English in every language. The fix that is needed is a harvest
  from the `.lfm` files that does not depend on the IDE. This is the same silent loss as the
  469 captions above, seen from the template's side.
- **New resourcestrings not yet in any catalogue (2026-11-01).** `src/uAppStrings.pas`
  declares 33 strings in the `SEditQSODelivery*`, `SLogLocked*` and `SWRL*` families. None
  of them appears in any `i18n/*.po` or in `tr4w/languages/`; checked with
  `rg -c -i "seditqsodelivery|sloglocked|swrl" i18n tr4w/languages`, which finds nothing.
  They show in English in every language until they are merged. The recipe needs no IDE:
  `updatepofiles` on the `.rsj` into a scratch `.pot`, then `po_merge --pot`. See
  `docs/I18N_TOOLS.md`.

---

## What is proven

Verified in the real binary, not asserted:

1. `resourcestring` → FPC writes `<unit>.rsj` — `uTR4WStrings.rsj`, 546 entries, keyed
   `utr4wstrings.tc_wagwarn`.
2. `rstconv -f po` turns that into a `.po` — 546 msgids, key in the `#:` line.
3. LazUtils `translations.pas` reads that line and **normalises the colon to a dot**
   ("the RTL creates identifier paths with point instead of colons"), then matches on
   `IdentifierLow`. It parses and re-emits `msgctxt` too, so carrying both keys costs
   nothing.
4. The generated identifiers **match what `po_rekey` wrote** into the catalogues:
   546 exposed, 381 already translated in Spanish, 165 new.
5. The value actually changes at run time (`5d7f449f`):

```
no --lang   SIniRetireTitle = Old settings file
            UI language: no translation loaded; using the compiled-in English
--lang es   SIniRetireTitle = Archivo de configuracion antiguo
            UI language: loaded translations for "es"
```

**The `.po` is found relative to the EXECUTABLE, not the working directory.** The first
attempt failed with the catalogue in `target/` while the dev binary ran from `build-out`.

> **That was true of `SetDefaultLang` at the time, and it is not how it works now.** The
> catalogue is embedded (step 5). A loose `languages/<code>/tr4w.po` still overrides the
> embedded copy, but it is located by `uAppPaths.DataFilePath`
> (`uEmbeddedTranslations.LanguageFilePath`). On Windows that is the **working
> directory**, on macOS the bundle's `Contents/Resources`, and on Linux `/usr/share/tr4w/`
> or the binary's directory. Only `languages/` is searched. The log line now reads
> `UI language: "<code>" selected by <source>, loaded from the embedded catalogue`, or
> `..., loaded from <path> (overriding the embedded catalogue)`.

---

## What is left

| # | step | state |
|---|---|---|
| 1 | measure the `RC_` split | **done** — 546 convertible, 78 deferred, 9 dead |
| 2 | rekey the catalogues | **done** — 6,656 refs, 16 languages, no translation changed |
| 3 | generate `uTR4WStrings.pas` | **done** — 546 strings, compiles, `.rsj` verified |
| 4 | load a `.po` at run time | **done** — `5d7f449f`, proven above |
| 5 | switch to embedded catalogues | **done** — `fe88ad0f`, 514 KB for 16 languages, exe 5.62 → 6.13 MB (2026-08 figures; see above for today's `.res`) |
| 5a | the build regenerates the `.res` | **done 2026-10-16** — sha256 stamp in `res/tr4w_languages.res.inputs`; `check-language-res.sh` on Unix |
| 5b | unreviewed (fuzzy) entries ship | **done 2026-09-21** (NY4I) — `Make-LanguageRes.ps1 -ReviewedOnly` restores the gate |
| 6 | language as a TR4W setting | **done 2026-09-19** — `Settings.Display.Language` / `DISPLAY LANGUAGE`; see above |
| 7 | cut `VC.pas` over to `uTR4WStrings` | **done** — `1ee6b50f`, 2026-08-27; the `{$INCLUDE}` of the language tables is gone from `VC.pas` |
| 8 | `.lfm` captions → `.po` | **done** — 561 harvested, merged into all 16; captions added after the last IDE save are not (issue #145) |
| 8a | retiring a removed string safely | open — issue #144 |
| 8b | the Weblate review pass | planned, after the contest factory is complete (NY4I, 2026-10-22) |
| 9 | help `.po` + a help pane on settings leaves | **tooltips done 2026-11-02** — `src/uCommandHelp.pas` reads `help\help_<code>.po` over `help_en.po` and `TSettingBindings.Bind` sets each bound control's hint. No pane. Open: `help_en.po` lags the ini (6 entries; `docs/HELP_TEXT_GAPS.md` section E), and the INI housekeeping (section D) is NY4I's |
| 10 | a lint so new English cannot get in | open |
| 11 | catalogue validation | **done** — `tools/i18n/po_lint.py`, found 9 defects in the inherited translations |
| 12 | translator handoff documented | **done** — `TRANSLATOR_GUIDE.md`, `TRANSLATION_HANDOFF.md` |

### Line breaks inside translatable strings — decided, and against the first instinct

21 English strings carry a `\r` or `\n` in the middle: 11 legacy `TC_` and 10 modern.
NY4I's first preference (2026-08-27) was to **split** them, so a translator cannot
delete a line break: *"all it takes is a translator to mis-edit and delete that and the
message does not display correctly."* The risk is real — one had already been lost
before any human touched the file.

**They are NOT split, and the reasoning is worth keeping.**

* **Splitting the 11 legacy ones re-keys them**, orphaning finished translations in 16
  languages. That is the one thing the whole pipeline is built to avoid.
* **Fragments translate badly.** A message cut into three resourcestrings joined in
  code gives the translator three pieces with no context, and word order, agreement and
  gender do not survive being assembled by `+`. This is a well-known gettext
  anti-pattern, and it makes the *translation* worse in order to make one *editing
  mistake* harder.
* **The mistake is detectable instead.** `po_lint.py` compares control characters
  between the English and the translation and fails on any difference. That catches the
  exact failure without changing a single string.

So: whole messages stay whole, and the check is what protects them. Revisit only if a
translator actually loses a break that the lint does not catch.

### The cut-over hazard (step 7) — HISTORICAL, the cut-over was made in `1ee6b50f`

Kept for the reasoning only. `VC.pas` now `uses uTR4WStrings`, and its comment records why
68 units gained that unit in their uses clause.

`uTR4WStrings` declares `TC_WAGWarn` and 545 others **that `VC.pas` already declares as
consts** from the language table. With both in scope the winner is decided by uses-order,
silently. That is why the unit is generated but **not in the build**: the cut-over is a
deliberate commit that removes the `{$INCLUDE}` of the language tables in the same change,
not a side effect of adding a unit.

### The lint (step 10)

Three defects this month were new English entering the code past every mechanism: the
CTY.DAT bootstrap block (7 hardcoded strings, written 2026-08-25), the 95 stranded consts,
and 469 `.lfm` captions. A diff-scoped lint — a non-empty literal reaching a UI sink,
`logger` calls excepted — would have caught all three at the point of writing. It should
flag *the sink*, not prescribe the replacement, so it outlives whichever mechanism wins.
