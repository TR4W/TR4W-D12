# TR4W internationalisation — the plan and the decisions behind it

**Status 2026-08-26.** The mechanism is proven end to end; the content is not moved.
This is the single place the i18n decisions live. Where it summarises something, the
tooling in `c:/tr4w-i18n/tools/i18n` and its README are authoritative.

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

Measured 2026-08-26: the exe is 5.6 MB with one language. All sixteen catalogues add
**1.4 MB raw, or 1.0 MB** trimmed of `#.` notes and the `pas2po` source references (which
end in a line number and no run time reads). **6.6 MB covers sixteen languages** where
today 5.6 MB covers one and nine languages means nine builds.

Lazarus supports the embedded path directly — `TPOFile.Create(AStream)`, whose own comment
reads *"when loading from internal resource Full needs to be False"*.

**The help side is greenfield.** `uOption.pas`, the Ctrl-J dialog that read
`commands_help_<LANG>.ini`, was deleted in `4321ce1d`. Preferences has no help pane,
nothing in `src` reads `TR4W_COMM_HELP_FILENAME` — it is still assigned in `FCONTEST.PAS`
and never consumed — and **7 help INIs still ship in `target/`, unread**. There is no
existing behaviour to preserve, so the format is a free choice, and `.po` puts translators
in one tool for both halves.

### Language selection is a TR4W setting, not the OS locale

`SetDefaultLang('')` honours a `--lang` switch and then the OS locale. That is the seam,
not the answer: an operator on Spanish Windows does not necessarily want a Spanish contest
log. **Still open.**

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

They belong to Win32 dialogs still loaded from the `.res` — 69 `DialogBox`/`CreateDialog`
call sites remain. **When a dialog becomes an LCL form its text moves into the `.lfm` and
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

In `c:/tr4w-i18n/tools/i18n`, on branch `i18n-ts-poc`. Nothing in the build depends on it.

| tool | does |
|---|---|
| `pasconsts.py` | the shared line-oriented parser for the language fragments |
| `pofile.py` | minimal `.po` reader/writer — `msgctxt`, `#,fuzzy`, `#.`, `#:`, `#~` |
| `pas2po.py` | language tables → `.po` |
| `po2pas.py` | `.po` → language tables, *surgical*; `--verify` proves byte-identical round-trip |
| `po_rekey.py` | adds the `#:` run-time identifier beside the `msgctxt` key |
| `pas2res.py` | English tables → `uTR4WStrings.pas`, 546 resourcestrings |
| `po_prune.py` | marks entries obsolete when their key leaves the source |
| `ini2po.py` | help INIs ⟷ `.po`, plus `--todo --write-doc` |
| `mt_seed.py` | libretranslate seeding |

**Machine output cannot reach a build.** `mt_seed.py` touches only entries that are *both
fuzzy and empty*; its output stays fuzzy; `po2pas.py` skips fuzzy entries. Clearing the
fuzzy flag is a human's review, and that is what makes an entry usable. Native-speaker work
is protected by the flag itself, not by anyone remembering to be careful.

### Translation state, 2026-08-26

417 strings per language. `#, fuzzy` means machine-filled and unreviewed:

| | languages |
|---|---|
| essentially unreviewed (~400+ fuzzy) | fr, ja, ko, nl, pt, it |
| partial review (29–101 fuzzy) | de 101, pl 85, ro 78, uk 74, ru 69, mn 41, cs 39, sr 29 |
| done | es (1) |

**Extract the captions before handing anything to translators.** The corpus goes from 417 to
~880 once `.lfm` captions are in. Hand them over now and they review 417 strings, then get a
second batch of 459 in the same dialogs they already looked at.

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

---

## What is left

| # | step | state |
|---|---|---|
| 1 | measure the `RC_` split | **done** — 546 convertible, 78 deferred, 9 dead |
| 2 | rekey the catalogues | **done** — 6,656 refs, 16 languages, no translation changed |
| 3 | generate `uTR4WStrings.pas` | **done** — 546 strings, compiles, `.rsj` verified |
| 4 | load a `.po` at run time | **done** — `5d7f449f`, proven above |
| 5 | switch to embedded catalogues | open — `TPOFile.Create(TResourceStream)` |
| 6 | language as a TR4W setting | open |
| 7 | cut `VC.pas` over to `uTR4WStrings` | open — **see the hazard below** |
| 8 | `.lfm` captions → `.po` via Lazarus i18n | open — 469 strings, the largest block |
| 9 | help `.po` + a help pane on settings leaves | open — greenfield; INI housekeeping first |
| 10 | a lint so new English cannot get in | open |

### The cut-over hazard (step 7)

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
