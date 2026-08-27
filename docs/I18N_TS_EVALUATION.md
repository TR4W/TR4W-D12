# Evaluating Qt Linguist `.ts` as TR4W's translation interchange format

**Status:** proof of concept complete and validated end to end. **`.ts` is now an INTERIM store;
the destination is GNU gettext `.po`** — see [Superseded by the FPC/Lazarus
decision](#superseded-by-the-fpclazarus-decision). Nothing in the build depends on the tooling.
**Date:** 2026-08-09, revised 2026-08-13. **Scope:** `TC_*` constants only (416 keys).

## The question

Can TR4W adopt the way Qt handles internationalisation, so we can reach the established ecosystem
of translation tools that real native speakers already use? The prompting concern is Embarcadero's
move toward third-party cloud i18n tooling and its weak support for language editing.

## The answer

**Yes — but what you adopt is the file format and the translator ecosystem, not Qt's tooling.**

Three findings decide the shape:

1. **`lupdate` is useless here.** Qt's source scanner parses only C++, C++ headers, Java, Python,
   QML and `.ui`. There is no Pascal front-end and no plugin mechanism. **We write the extractor
   ourselves regardless of which format we pick** — and that extractor is essentially the entire
   cost under `.ts`, `.po` or XLIFF alike. This is the single most important fact: it means the
   format choice is cheap and the extractor is the real work.
2. **`.qm` is rejected.** Qt's compiled binary format is not normatively documented and its only
   blessed reader is `QTranslator`, i.e. the Qt libraries. `.ts` is an interchange format only;
   TR4W would compile to a runtime format we own (JSON, per NY4I's brief).
3. **Licensing is clear.** Qt Linguist ships under GPLv3 **with Qt GPL Exception 1.0**, which
   explicitly permits distributing "a larger work which contains the output of this application …
   under terms of your choice." Editing `.ts` in Linguist and shipping the result in TR4W is fine —
   the GPL binds the tool's code, not our data, the same reasoning that lets closed software be
   built with GCC. The line not to cross is **linking** QtCore for `QTranslator`, which is LGPLv3
   or commercial. We never link Qt. *(Not legal advice.)*

`.ts` buys no *extra* translator reach over `.po` or XLIFF — Weblate, Crowdin, Transifex, Poedit
and POEditor read all three. But `lconvert` converts symmetrically between them **and preserves our
stable key** as a `#. ts-id TC_...` comment, so the choice is genuinely reversible. That is why it
was safe to just pick one.

## Superseded by the FPC/Lazarus decision

**2026-08-13: TR4W is moving to Free Pascal / Lazarus, `resourcestring`-based.** That reverses the
format choice above, and the reversibility argument is exactly why this costs nothing.

- **The destination is `.po`, not `.ts`.** FPC emits `.rsj` beside each unit, `.rsj → .po` is the
  supported path, and Lazarus ships a translator unit that loads `.po` at run time. Poedit is a
  *gettext* tool — `.po` is its home format; `.ts` was the courtesy. See
  [`TOOLCHAIN_SWOT_LAZARUS_VS_DELPHI.md`](TOOLCHAIN_SWOT_LAZARUS_VS_DELPHI.md), where native `.po`
  support is one of the stated reasons for the toolchain decision.
- **The single-EXE blocker dies.** Under Delphi it was Win32 dialog templates baked into
  per-language `.RES` files loaded via `MAKEINTRESOURCE`, unfixable because `res/Tr4w.rc` cannot be
  rebuilt. Under Lazarus those become `.lfm` forms whose strings extract like any other. "One build
  per platform" becomes gated on the **LCL coexistence proof**, which the FPC spike already names as
  its dominant open question — the same gate, not a new one.
- **Key identity becomes automatic.** The hand-rolled `<message id="TC_...">` scheme existed because
  Qt's default source-text identity would orphan translations on every English edit. FPC gives
  `unitname.identifier` for free, maintained by the compiler. Our scheme becomes unnecessary.
- **No custom runtime loader.** The `.ts → JSON` compiler and `TLocalizationManager` sketched under
  the Delphi plan are replaced by Lazarus's translator unit. Do not build them.

**What carries over unchanged:** the catalogs (10 languages × ~416 keys of existing translation,
key-matched and validated — the real asset), the completed Spanish pass, and `pas2ts.py --check`,
whose placeholder-arity, key-drift and duplicate-key checks gettext tooling does **not** provide.

**What becomes obsolete:** `ts2pas.py`'s surgical writer, once `TC_*` constants become
`resourcestring` and the `.pas` files stop being the translation store. It is still needed *for* the
one-time migration.

**Timing.** Do not convert the catalogs to `.po` yet. `lconvert` emits `msgctxt "General|"` plus a
`#. ts-id TC_…` comment, but FPC wants `unitname.identifier` — and those names do not exist until
the resourcestrings are declared. Converting now produces an artifact that must be re-keyed. Do it
in one step when the resourcestrings are written.

**A second reason to want the FPC move, found while seeding CJK.** `wsprintf` maps arguments **by
position only** — there is no `%1$s`. Japanese is SOV and genuinely needs a different argument order
from English; three seeded Japanese strings came back with the placeholders reordered and had to be
refused, because applying them would pair the wrong argument with the wrong slot. This is not an
engine artefact and no better translator fixes it: under `wsprintfA` those strings **cannot be
correctly translated at all**. `SysUtils.Format` supports `%0:s` positional indices, so the ceiling
lifts with the migration. It caps translation quality for every language whose word order differs
from English — most visibly Japanese and Korean, to a lesser degree Russian. Together with the
`AnsiString`-at-the-`...A`-boundary problem (CJK renders as `?` on a CP1252 machine), that is why
**JPN and KOR are deferred until after the move**; `ts2pas.py --create` refuses them, and the
catalogues are kept rather than discarded.

**Unchanged either way:** the 231 `RC_` references in `uMenu.pas`'s three *typed constant* arrays.
FPC applies the same rule as Delphi — a `resourcestring` is runtime-mutable and cannot appear in a
constant initializer — so those arrays need runtime population under either toolchain. Cheap to
confirm with `spike/fpc-compile.ps1` rather than taking this document's word for it.

## What was built

| Path | Role |
|---|---|
| `tools/i18n/pasconsts.py` | shared parser: Pascal string expressions, encodings, XML byte handling |
| `tools/i18n/pas2ts.py` | extractor + validator (`--check`) |
| `tools/i18n/ts2pas.py` | surgical writer + round-trip verifier (`--verify`) |
| `tools/i18n/README.md` | translator workflow |
| `i18n/*.ts` | 10 generated translation files, checked in |

**No application code was changed.** `tr4w/src/lang/*.pas` is untouched, `VC.pas` and the
`LANG_xxx` compile-time selection are untouched, and the build is unaffected.

### Design decision: ID-based messages

Qt's default message identity is the `(context, source-text)` pair. That is **wrong for us** — under
it, every English wording fix would silently orphan ten translations. The tools use Qt's ID-based
form instead, `<message id="TC_...">`, so the existing Pascal constant name *is* the stable key.

### Design decision: surgical rewrite, not regeneration

`ts2pas.py` replaces only the string expression on each `TC_` line, using byte spans from the
parser. Indentation, the `=` alignment column, trailing `//` comments, section banners and every
neighbouring `RC_` line survive untouched. Regeneration would have been wrong twice: `RC_`
constants are not in the `.ts` at all, and each language file has its own declaration order, which
is not ENG's (RUS in particular is in a wholly different order).

This also makes the round-trip test far stronger than planned: applying **unmodified** `.ts` files
must leave every `.pas` **byte-identical**, with no "modulo whitespace" caveat.

## Verification

- **Extraction:** 416 ENG keys (412 before the `TC_TELNET` unpack); 10 languages emitted; counts
  agree with an independent grep-based census once duplicates are accounted for.
- **Round-trip:** `ts2pas.py --verify` → **byte-identical for all 10 languages.** Every declaration
  was re-rendered through the encoder (not skipped), so this exercises the parser and the encoder
  on all 4,000-odd declarations, including doubled-quote escapes and `#13` concatenation.
- **Independent cross-validation with the real Qt toolchain** (Qt 6.10.1 is installed on the dev
  machine): `lrelease` compiles our generated files and reports unfinished counts of GER 1, RUS 61,
  SER 4 — **exactly matching our own validator**, from a completely separate implementation.
- **Editor round-trip:** a `.ts` rewritten by Qt's own `lconvert` (what Linguist does on save)
  re-applied with **411 of 412 strings byte-identical**; the one exception was `TC_TELNET`, since
  fixed. With the packed constant gone, the catalogs contain **zero** `<byte value="x00"/>` and the
  `.po` conversion is lossless.
- **Escape hatch:** `lconvert -o de.po` and `-o de.xlf` both succeed and preserve the stable key.

## `TC_TELNET`: the packed string — FIXED 2026-08-13

`TC_TELNET` was not really a string. It was a **NUL-separated Win32 string list** fed to
`TB_ADDSTRING` (`uTelnet.pas:781`), with `tbButtons[].iString` indexing into it, and with the `#0`
separators and the double-NUL terminator embedded *in the translation itself*.

That is unrepresentable, twice over. XML 1.0 cannot carry U+0000 at all — not even as a numeric
character reference — so we encoded it with Qt's purpose-built `<byte value="x00"/>`, and **Qt's own
`lconvert` silently discarded those** (verified: 50 byte elements in, 36 out; `x0d` survived, `x00`
did not). Worse for where we are going, **gettext strings are NUL-terminated C strings, so a NUL
cannot appear in a `.po` msgstr at all** — under `.po` the list collapsed to
`ConectarDesconectarComandosCongelarLimpiar100` with zero NUL bytes. The `.ts → .po` move made the
rework mandatory rather than merely advisable.

**Resolution:** the constant is gone. Five named per-button constants (`TC_TELNET_CONNECT`,
`_DISCONNECT`, `_COMMANDS`, `_FREEZE`, `_CLEAR`) replace it in all 11 language files, each derived
from that language's own items 0–4 so no translation was lost. `TelnetToolbarLabels` in
`uTelnet.pas` joins them with `#0` and appends the terminator. `'100'` stays a literal — it is the
SH/FDX 100 cluster shortcut, not prose, and making it translatable was always a fiction.

This fixed **both** Serbian defects by construction (see below) and removed every NUL from the
translation catalogs: `.ts` now emits **zero** `<byte value="x00"/>`, and `.po` conversion is
lossless. The NUL guard in `ts2pas.py` stays as a regression check.

Verified: ENG, SER and RUS all build green, and the reconstructed list is 6 items (7 for RUS),
double-NUL terminated, with index 5 `'100'` in every language.

## Defects this surfaced

These are live bugs in the shipped translations, **independent of whether `.ts` is adopted**. None
was findable by the current workflow, which is the substantive argument for structured translation
files over hand-edited Pascal.

### 1. Serbian telnet toolbar — TWO defects — FIXED 2026-08-13

`TELNETBUTTONS = 6{$IF LANG = 'RUS'} + 1{$IFEND};` (`uTelnet.pas:105`), and the list must be
**double**-NUL-terminated. Measured before the fix:

| | items | trailing NULs | |
|---|---|---|---|
| ENG and 8 others | 6 | 2 | correct |
| RUS | 6 | 1 | correct — the old code appended `'?'#0#0` for RUS only |
| **SER** | **9** | **1** | **wrong, twice** |

**(a) Out-of-bounds read.** Serbian packed nine items with a single terminator and got no fix-up, so
`TB_ADDSTRING` read past the constant until it happened to find two consecutive NULs in adjacent
memory.

**(b) A mislabelled button.** `iString` 5 is the SH/FDX 100 shortcut, but Serbian's item 5 is
`Korisnici` (*Users*) — its list was written against an older nine-button toolbar, still visible as
commented-out `tbButtons` entries at `idCommand` 205 and 207. So the Serbian build labelled the
SH/FDX 100 button "Users". **Neither defect is visible in a packed string**, which is the whole
argument for the rework above.

Both are now impossible: the separators and the terminator are owned by code, and index 5 is the
`'100'` literal in every language.

### 2. Mongolian is very likely shipping as mojibake

`tr4w_consts_mng.pas` contains **23,247 non-ASCII bytes, is valid UTF-8, and has no BOM.** Per
`CLAUDE.md`, Delphi's per-file encoding mechanism *is* the BOM: a no-BOM file is decoded with the
build machine's ANSI codepage. `'Дуудлага'` (Mongolian for *callsign*) read as CP1251 becomes
`'РџСѓСѓРґР»Р°РіР°'`. ENG has the same problem in miniature — line 537 carries an em-dash (U+2014)
in a BOM-less file.

Adding a BOM to `tr4w_consts_mng.pas` is a one-line fix. **Confirmation needs a build and a visual
check**, which `CLAUDE.md` already records as never having been done for any of the 8 non-ENG
languages. This is inference from the encoding rule, not an observation of the running program.

### 3. Format-specifier mismatches (5)

TR4W's `Format` is **`wsprintfA` from user32** (`TF.pas:263-285`), not `SysUtils.Format`. It raises
no exceptions, so these are **display defects, not crashes**:

| Language | Key | ENG | Translation |
|---|---|---|---|
| MNG | `TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX` | `%s %s` | `%s` |
| MNG | `TC_YOUALREADYWORKEDIN` | `%s %s` | `%s` |
| ROM | `TC_DIFVERSION` | `%s %s %s` | `%s` |
| UKR | `TC_CQTOTAL` | `%u` | trailing bare `%` |
| UKR | `TC_BAND_CHANGES` | `%d` | `% d` (invalid — wsprintf has no space flag) |

The *class* is more dangerous than these instances. `wsprintf` is unchecked varargs: a translator
who writes `%s` where English has `%d` makes it dereference an integer as a pointer — an access
violation. Nothing in the current workflow can catch that; `pas2ts.py --check` does.

### 4. Encoding and key-drift census

`tr4w_consts_chn.pas` decodes under **no** declared codepage (GBK, GB18030, Big5, CP936 all fail at
byte 28854), and carries 3 duplicate keys. Both tools skip it. POL decodes cleanly as CP1250.

| LANG | keys | missing | vanished | same-as-EN |
|---|---|---|---|---|
| CZE | 411 | 4 | 3 | 35 |
| ESP | 460 | 1 | 49 | 92 |
| GER | 411 | 1 | 0 | 96 |
| MNG | 421 | 3 | 12 | 38 |
| POL | 399 | 22 | 9 | 59 |
| ROM | 421 | 5 | 14 | 73 |
| RUS | 400 | 61 | 49 | 8 |
| SER | 414 | 4 | 6 | 25 |
| UKR | 399 | 61 | 48 | 9 |

*missing* = key in ENG with no translation; *vanished* = key present only in that language;
*same-as-EN* = translated text byte-identical to English, i.e. probably never translated. RUS and
UKR are each missing 61 keys and carry ~49 stale ones — the catalogs have drifted substantially.

## Recommendation

**The structured-catalog workflow is proven; keep it.** The round-trip is byte-exact, the real Qt
toolchain validates our output, a real translator completed Spanish through it, and the exercise
found eight live defects. Under FPC/Lazarus the *format* becomes `.po`, but nothing else about the
workflow changes.

One caveat that survives the toolchain change:

- **Poedit, not Qt Linguist, is what you hand a translator.** Qt's standalone Linguist installer for
  Windows is from March 2019. Poedit is actively maintained, reads both formats, and is a *gettext*
  tool — so it is already the right tool for where this is going. Proven in practice: Poedit
  preserved all 461 `id` attributes and all 50 `<byte>` elements on save, where Qt's own `lconvert`
  dropped the NULs.

### Status of the original work plan

1. ~~**Trial one language with a real translator.**~~ **DONE (Spanish, 2026-08-09/10.)** 37 strings
   improved over two rounds, 0 rejects, 92 unfinished → 0. Included a real fix: `TC_CONNECTEDTO`
   lacked the trailing space `uTelnet.pas:643` (`'%s%s:%u'`) depends on, so it rendered
   `Conectando adxcluster:7300`. This was the only genuinely unknown step and it worked.
2. ~~**Unpack `TC_TELNET`.**~~ **DONE 2026-08-13** — see above. The `{$IF LANG = 'RUS'} + 1`
   button-count special case was deliberately left alone: it is a UI-layout question for the LCL
   migration, not a string question.
3. **Fix the remaining defects.** Still open. The BOM on `tr4w_consts_mng.pas` is the one that
   affects a shipped build; the 5 placeholder faults and 3 dropped `#13`s each need a native speaker
   of that language.
4. **Italian** is under review. **Dutch, French and Portuguese** are seeded and
   ready to send. **Japanese and Korean are DEFERRED until after the FPC move**
   and `ts2pas.py --create` refuses them — see below.
5. Wire the catalogs into the `resourcestring` migration **when the resourcestrings are declared**,
   converting to `.po` in the same step so the keys are right the first time.

## What this does not decide

The catalog workflow is **orthogonal** to the runtime migration in
`docs/claude-code-localization-migration-prompt.md`. That work is still needed for runtime language
switching and one build per platform; this pass only changes *how translators receive and return
text*. The two converge — these catalogs become the seed for the `.po` files — but this is
independently useful even if the runtime work slips, because it already gets native speakers out of
Pascal source.

`RC_*` (~250 keys) and `commands_help_*.ini` remain out of scope. `RC_*` in particular leads into a
separate problem: `res/Tr4w.rc` `#include`s `hotkeys.h` and `DEF.H`, neither of which exists in the
repo, so the resource script is not buildable and the per-language `.RES` files are effectively
sourceless.
