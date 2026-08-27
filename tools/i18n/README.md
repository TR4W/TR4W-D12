# TR4W translation tooling

Converts TR4W's string catalogues to and from **GNU gettext `.po` files**, so native speakers
translate in Poedit instead of editing Pascal source.

`.po` is the master format, chosen on two criteria: **FPC/Lazarus load `.po` at run time**
(`.rsj` -> `.po` is the supported path, and Lazarus ships the translator unit), and **Poedit is a
gettext tool** -- it bundles `msgfmt`, `msgmerge`, `msgcat` and `msguniq` under
`C:\Program Files\Poedit\GettextTools\bin`, which gives real validation and real fuzzy-matching
when English changes. An earlier pass used Qt Linguist `.ts`; it worked, but it would have needed
a conversion step in the build forever, and carrying both formats invited drift.

**Status: proof of concept.** Nothing in the build depends on this. `tr4w/src/lang/*.pas` remains
the source of truth and the `LANG_xxx` compile-time selection is unchanged. See
[`docs/I18N_TS_EVALUATION.md`](../../docs/I18N_TS_EVALUATION.md) for the evaluation and the
decision this supports.

## Scope

`TC_*` constants only — 412 keys, taken from ENG. Deliberately excluded this pass:

- `RC_*` (~250 keys) — consumed by `res/Tr4w.rc`, which `#include`s `hotkeys.h` and `DEF.H`.
  **Neither header exists in the repo**, so the `.rc` is not buildable and the per-language `.RES`
  files are effectively sourceless. That is a separate problem.
- `tr4w/target/commands_help_*.ini` `DESCRIPTION=` text (7 languages).

## Commands

```bash
python tools/i18n/pas2po.py            # tr4w/src/lang/*.pas  ->  i18n/tr4w_<code>.po
python tools/i18n/pas2po.py --check    # validate; writes nothing; non-zero exit on problems
python tools/i18n/po2pas.py --verify   # round-trip proof; writes nothing
python tools/i18n/po2pas.py --dry-run  # show what a translator's edits would change
python tools/i18n/po2pas.py            # apply .po back into the .pas files
```

`po2pas.py` does a **surgical rewrite**: it replaces only the string expression on each `TC_` line
and leaves indentation, the `=` alignment column, trailing `//` comments, section banners and every
neighbouring `RC_` line untouched. Regenerating the files instead would be wrong — `RC_` constants
are not in the catalogue, and each language file has its own declaration order that is not ENG's.

`--verify` is therefore a strong test: applying **unmodified** catalogues must leave every `.pas`
byte-identical. It currently passes for all 10 representable languages.

## Translator workflow

1. Run `pas2po.py` and send the translator their `i18n/tr4w_<code>.po`.
2. They open it in **Poedit**, translate, and send it back. They never see Pascal, and they
   cannot damage the key structure -- the key is the `msgctxt`, which Poedit does not expose
   for editing.
3. Run `po2pas.py --dry-run` to review, then `po2pas.py` to apply.
4. Run `pas2po.py --check` and fix anything it reports before committing.

**Poedit** is the tool to hand a translator: free, cross-platform, actively maintained, and
gettext-native. It also proved the safer editor in practice -- it preserved every key and every
escaped control character on save, where Qt's own `lconvert` silently dropped NUL bytes.

## Adding a new language (worked example: Italian)

`ITA` has no `tr4w_consts_ita.pas`, so it takes the *generate* path rather than the surgical-rewrite
path.

```bash
python tools/i18n/pas2po.py --new-lang ITA     # -> i18n/tr4w_it.po, 416 keys, all fuzzy
# ... email tr4w_it.po to the translator, get it back ...
python tools/i18n/po2pas.py --create ITA       # -> tr4w/src/lang/tr4w_consts_ita.pas
```

`--create` uses the **ENG file as its template**, so the new file inherits ENG's structure, section
banners, alignment and its `RC_` constants (out of scope, left English). Keys the translator did not
fill in **keep the English text**, so the language builds and runs from day one and simply shows
English where nobody has translated yet — a visible English string, not a blank UI.

The generated file is written **UTF-8 with a BOM** and CRLF. That is not cosmetic: Delphi's per-file
encoding mechanism *is* the BOM, and Italian's accented vowels in a BOM-less file would corrupt
exactly the way `tr4w_consts_mng.pas` does today.

Then four small wiring edits, none of which the tool makes for you:

| File | Edit |
|---|---|
| `tr4w/src/VC.pas` | 3 lines in the block at ~209-244: `{$IFDEF LANG_ITA}{$DEFINE _LANG_SET}{$ENDIF}`, `{$IFDEF LANG_ITA}  LANG = 'ITA';{$ENDIF}`, `{$IF LANG = 'ITA'}{$INCLUDE lang\tr4w_consts_ita.pas}{$IFEND}` |
| `tr4w/tr4w.dpr` | 1 line at ~335-345: `{$IF LANG = 'ITA'}{$R res\tr4w_ita.res}{$IFEND}` |
| `tr4w/res/` | copy `tr4w_eng.res` to `tr4w_ita.res` — the `RC_`/menu resource is out of scope, and ENG is the honest placeholder |
| `tr4w/FullBuild.ps1` | add `"ITA"` to `$otherLangs` (~line 890) and `'ITA' = @{ LangId = 0x0410; CodePage = 1252; Name = 'Italian' }` to `$langMap` (~line 287) |

Build it with `msbuild tr4w.dproj /t:Build /p:ExtraDefines="LANG_ITA;VERSIONINFO_RES"`.

**Verified end to end** on 2026-08-09 with a simulated return covering the three cases that corrupt
silently: an accented character (`%s è un duplicato!!`), an apostrophe (round-tripped to Pascal's
doubled-quote form, `'Stai usando l''ultima versione'`), and a `%s` placeholder. Qt's `lrelease`
accepted the file and reported 9 finished / 403 untranslated, matching our own count.

## Seeding from LibreTranslate

```bash
python tools/i18n/mt_seed.py --lang FRA                 # TC_ constants
python tools/i18n/mt_seed.py --lang FRA --catalog help  # config-command help
python tools/i18n/mt_seed.py --lang FRA --reseed        # discard machine output, redo
```

Everything seeded stays **fuzzy**, and `po2pas.py` refuses fuzzy entries, so
machine output cannot reach a build until a human clears "Needs work".
Reviewed (non-fuzzy) entries are never touched, including by `--reseed`.

**One string per request by default.** Batching maps results back by position
and would silently mispair a reordered batch. Measured against the local
engine: `--batch 1` is 2.04 s/string (~15 min per language) against
0.12 s/string batched -- the cost is per-request model inference, not
transport, so it does not vanish on localhost. Paying it is the right trade
because seeding is rare, and because only fuzzy-and-empty entries are touched
every later run handles just the delta -- a handful of new strings, not 400.
`--batch N` is still available and is then automatically alignment-checked:
a sample is re-translated one at a time and compared, which is meaningful
because translation here is deterministic and batch output was verified
byte-identical to individual output.

A missing model is not a blocker: `pas2po.py --new-lang` produces a usable
translator catalogue with no engine involved.

## The second catalogue: config-command help

`tr4w/target/commands_help_<lang>.ini` holds the help text for the settings
dialog — one INI section per config command, read at run time by
`uOption.pas:842`.

```bash
python tools/i18n/ini2po.py            # -> i18n/help_<code>.po (7 languages)
python tools/i18n/ini2po.py --check    # drift report, writes nothing
python tools/i18n/ini2po.py --todo     # commands whose ENGLISH help is missing
```

**Only `DESCRIPTION` is translatable**, which is worth being explicit about:

- The **section name** is the config command (`ALT-D CQ ENABLE`). It is the
  lookup key — `uOption.pas` takes it from the ListView's `COMMAND_FIELD` — so
  translating it would break the lookup.
- **`DEFAULT`** is a config *value*: `FALSE`, `NONE`, `TRUE`, `0`, `CW`,
  `BLACK`, `BTNFACE`, numbers. Verified identical across all seven shipped
  files. Translating `FALSE` would break the parser that reads it. It *is*
  shown to the user, so it is carried into the translator's note as context.

That leaves one translatable string per section, so the key is simply
`TC_HELP_` + the section name: `TC_HELP_ALT_D_CQ_ENABLE`. **gettext has no
array or list concept** — plural forms exist but are strictly for grammatical
plurals — so if a second field ever became translatable it would need its own
suffixed key (`..._DESC`, `..._DEFAULT`) or a distinct `msgctxt`. Not needed
today.

**The English file is not the authority and neither is it complete.** The
command set lives in `uCFG.pas`'s `CommandsArray` — 508 commands against 423
English help sections. `--check` compares against the code, not against English:

| | |
|---|---|
| config commands | 508 |
| English help sections | 423 |
| commands with **no English help** | 86 (11 recoverable from another language) |
| commands with help in **no** language | 75 |
| help for a command that no longer exists | 1 (`SINGLE RADIO MODE`) |

A translation byte-identical to the English is marked `unfinished` — in these
files that is the dominant failure, whole sections having been copied across
when a language fell behind.

**A live defect this surfaced.** The reader is `GetPrivateProfileStringA`, which
decodes with the machine's ANSI codepage — but `commands_help_cze.ini` is
**UTF-8 with 18,404 non-ASCII bytes**, so Czech help text is currently rendering
as mojibake. Same class as the `tr4w_consts_mng.pas` BOM problem. Not fixed
here.

## Validating a catalogue

Poedit's bundled gettext tools work on these files directly:

```bash
msgfmt --check-format --check-domain -o NUL i18n/tr4w_es.po   # validate
msgmerge --update i18n/tr4w_es.po i18n/tr4w_en.po             # re-match after English changes
```

`msgmerge` is the one worth remembering: when a source string is reworded it re-matches the old
translation and marks it fuzzy, which the extractor's exact-key matching cannot do.

## Two traps, both verified against Qt 6.10.1

**1. `lconvert` silently drops `<byte value="x00"/>`.** XML 1.0 cannot carry U+0000, so NUL is
encoded with Qt's `<byte>` element — but Qt's own `lconvert` discards those on rewrite (50 byte
elements in, 36 out). Only one string is affected: `TC_TELNET`, a NUL-separated Win32 string list
fed to `TB_ADDSTRING`. `po2pas.py` **refuses** to apply a translation that has lost its NUL
separators rather than corrupt the file. Do not remove that guard. The real fix is to stop packing
six button labels into one constant.

**2. A literal CR would be silently normalised to LF** by any conforming XML parser, which would
corrupt the `#13` in strings like `TC_DIFVERSION`. CR is therefore also written as `<byte
value="x0d"/>`. Those *do* survive `lconvert`.

## Escape hatch

The format choice stays reversible. Qt's `lconvert` converts symmetrically between `po`, `ts`,
`pot` and `xlf`, so a translator who insists on Qt Linguist, or an agency that wants XLIFF, is
one command away:

```bash
lconvert -i i18n/tr4w_de.po -o de.xlf
```

## Files

| File | Role |
|---|---|
| `pasconsts.py` | shared parser: Pascal string expressions, encodings, XML byte handling |
| `pas2po.py` | extractor and validator |
| `po2pas.py` | surgical writer and round-trip verifier |
| `i18n/*.po` | the catalogues (checked in) |

## Language status

| Language | State |
|---|---|
| ENG + the 8 shipping languages | live |
| ESP | reviewed by a native speaker, 2026-08-10 |
| ITA | seeded, review under way |
| NLD, FRA, POR | seeded, **ready to send to a reviewer** |
| JPN, KOR | seeded but **DEFERRED until after the FPC/Lazarus move** |
| POL, CHN | decided-out (see below) |

**Why JPN and KOR are deferred.** Two Delphi-side blockers, neither of which is
a translation problem:

1. TR4W converts `TC_` strings to `AnsiString` at the `wsprintfA` and `...A` API
   boundaries, which uses the machine's ANSI codepage. On a CP1252 Windows, CJK
   renders as `?`. The `.pas` would compile — `--create` writes UTF-8 with a BOM
   — it just would not display.
2. `wsprintf` maps arguments **by position only** and has no `%1$s` syntax.
   Japanese is SOV and genuinely wants a different argument order from English;
   three seeded strings came back with the placeholders reordered and were
   refused, because applying them would pair the wrong argument with the wrong
   slot. `SysUtils.Format` supports `%0:s`, so this dissolves with FPC.

The catalogues are kept and can still be translated — that work is cheap to keep
and expensive to redo. `po2pas.py --create` **refuses** deferred languages,
because creating the `.pas` is the step that puts a language into a build. Clear
`"deferred"` for that language in `i18n/languages.json` when the blocker is gone.

## Excluded language

`CHN` is skipped by both tools: `tr4w_consts_chn.pas` decodes under **no** declared codepage
(not GBK, GB18030, Big5 or CP936 — it fails at byte 28854). Emitting a catalogue from it would bake
mojibake into a translator's file. CHN and POL are both decided-out languages per `CLAUDE.md`;
POL decodes cleanly as CP1250 and is processed normally.
