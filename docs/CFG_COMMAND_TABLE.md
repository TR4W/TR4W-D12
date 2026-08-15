# The CFG command table — what every field means

`CFGCA` (`uCFG.pas`) is TR4W's configuration system: **506 rows**, each describing one
configuration command. It is not merely a persistence table — it is simultaneously the
`tr4w.ini` parser, the contest `.CFG` parser, the call-window command vocabulary
(`MY CALL = N6TR`), the Options editor's model, and the multi-op network sync list.

This document exists because the ini is slated for retirement in favour of JSON
(`docs/`-adjacent decision, 2026-08-07), and **anything that migrates a row has to honour
every field on it**. Written by reading the consumers, with line references so each claim
can be re-checked. Every field is verified against its consumers, and the open-questions
list at the end is now empty.

```pascal
CFGRecord = record
   {04}crCommand : PAnsiChar;
   {04}crAddress : Pointer;
   {02}crMin     : Word;
   {02}crMax     : Word;
   {01}crS       : CFGStatus;
   {01}crA       : Byte;   // additional proc
   {01}crC       : Byte;   // 1-write to CFG file,
   {01}crP       : Byte;   // Procedure 0-no proc,
   {01}crJ       : Byte;   // 0-edit, 1-edit+restart, 2-readonly, 3-message(ro)
   {01}crKind    : CFGKind;
   {01}cfFunc    : CFGFunc;
   {01}crType    : CFGType;
   {01}crNetwork : Byte;   // 0 Do not send to network, 1- Send to network
end;
```

---

## The trap to read first: `crAddress` is not always an address

For `crKind = ckNormal` (434 rows) `crAddress` is what it says — the address of the global
the value is stored into, interpreted per `crType`.

**For `ckArray` (16 rows) and `ckList` (56 rows) it is an INTEGER INDEX**, cast back with
`integer(CFGCA[i].crAddress)` (`uCFG.pas:1146`, `:1160`), into `ArrayRecordArray` and
`ListParamArray` respectively. Dereferencing it as a pointer reads a wild address.

Any code that walks the table to export values — a JSON writer, a settings dumper — **must
branch on `crKind` before touching `crAddress`.** This is the single easiest way to write a
migration that appears to work and corrupts memory.

**And on two rows `crAddress` is a decoy.** The `ctFreqList` pair — `BAND MAP CUTOFF
FREQUENCY` and `FREQUENCY MEMORY` — point at `tBandMapCutoffFrequency` (`LOGWIND.PAS:60`)
and `tFrequencyMemory` (`LOGWIND.PAS:601`). Both are declared as plain integers and are
**never read or written anywhere in the program**; they exist only so the record has
something to take the address of. The real value goes into a list inside the `crA` function.
Exporting `crAddress` for these rows would faithfully persist a number nobody maintains.

The general lesson: **`crAddress` is where the value lives only for simple rows.** The
honest test for "simple" is already in the source at `uCFG.pas:944` —
`crKind = ckNormal` **and** `crType <> ctFreqList` **and** `crA = 0`. Anything failing it
needs its own handling.

## Three consumers of the table, and only two respect `crS`

Retiring a key is not just about `CheckCommand`, because the table has other readers:

1. **`CheckCommand`** (`uCFG.pas`) — the ini, the contest `.cfg` (`LogCfg.pas:825`) and
   inbound network values (`uNet.pas:318`) all arrive here. Respects `crS`.
2. **The Ctrl+J Options dialog** (`uOption.pas`, bound at `uMenu.pas:42`). Respects `crS` —
   hides `csRem` and `csOwned` (`uOption.pas:343`).
3. ~~**`BOOLSWAP`** — **IGNORES `crS` COMPLETELY.**~~ **NO LONGER TRUE (2026-08-13).**
   `scBOOLSWAP` now goes through `SetCFGCommandValue`, so it respects `crS` like every
   other writer, and refuses a `csJSON` row out loud instead of flipping its legacy
   global behind the JSON store's back.

   It was also **unreachable**, and had been since it was documented in 2010. Dispatch
   matches `caCommand` with an exact `StrComp`, and `FoundCommand` splits the typed
   command on `=` *before* comparing — so the compared string never contains `=`.
   The only row pointing at `scBOOLSWAP` was `' < = SK'`, which does. A reachable
   `'BOOLSWAP'` row was added alongside the rewrite.

   The old body assigned `PBoolean(crAddress)^` directly, skipping validation, the `crA`
   hook, the multi-op `crNetwork` sync and the ini write — so a toggle applied to the
   running session, told the other positions nothing, and vanished on restart. Its
   `QuickDisplay` feedback also sat inside `if crP <> 0`, so any boolean without a
   change-handler toggled in silence.

**BOOLSWAP IS NO LONGER A BLOCKER ON MOVING BOOLEANS TO JSON.** It respects `crS` now, so a
`csJSON` boolean is refused rather than flipped behind the store's back. The four `csOwned`
radio booleans (`RADIO ONE/TWO CW BY CAT`, `RADIO ONE/TWO CW SPEED SYNC`) can convert
whenever their appliers are ready.

The trigger syntax is transitional in any case: the `<03>`/`<04>` control-character form is
not shipping (NY4I, 2026-08-13), and BOOLSWAP is undocumented outside a 2010 release note,
so it is expected to be deprecated before it is ever used in a contest. The body was fixed
so that whatever replaces the syntax inherits a correct implementation — not because the
feature is load-bearing.

---

## Field by field

### `crCommand` — the key
The command text as it appears in a config file or the call window. Matched with
`StrComp` (`uCFG.pas:941`), so it is exact, case-sensitive and space-significant.

### `crAddress` — the target
See the trap above. `ckNormal`: address of the global. `ckArray`/`ckList`: an index.

### `crMin` / `crMax` — bounds, interpreted by `crType`
- Integer types: inclusive range (`uCFG.pas:1264`). **`crMax = MAXWORD - 1` means "no upper
  bound"** — the source comments it `{MAXLONG}`.
- `ctReal`: the bounds are **tenths** — compared against `crMin / 10` and `crMax / 10`
  (`uCFG.pas:1237`).
- Text types: `crMax` is the **maximum input length** the editor allows
  (`uOption.pas:695`) — populated on every `ctCaseSensitive`, `ctPassword`, `ctDirectory`
  and `ctURL` row, and on 49 of 58 `ctString`.
- **`crMin` is 0 on every non-numeric row** — verified across all 506 (NY4I, 2026-08-07).
  Treat it as meaningless outside the numeric types; do not derive validation from it.

**Two inconsistencies found while checking that, neither compiler-visible:**

- **Nine `ctString` rows carry `crMax: 0`** — `CQ MENU`, `EX MENU`, `INPUT CONFIG FILE`,
  `LOG FILE NAME`, `PACKET LOG FILENAME`, `PACKET SPOT COMMENT`, `RTTY RECEIVE STRING`,
  `RTTY SEND STRING`, `TOTAL SCORE MESSAGE`. Since `crMax` is the editor's input length,
  a `0` there is either an unreachable edit or an unbounded one. Worth a look before any
  of them moves.
- **The table spells types inconsistently**: `ctFileName` ×5 but `ctFilename` ×2, and
  `ctInteger` ×93 but `ctinteger` ×1. Pascal is case-insensitive so it compiles, but **any
  tool that parses this table textually must match case-insensitively** — a migration
  generator that groups by literal spelling will silently split a type into two buckets.
  (My own analysis script did exactly that before it was caught.)

### `crS: CFGStatus` — provenance and visibility
`(csNew, csOld, csRem, csOwned, csJSON)`, documented at `VC.pas:848-865`:
- `csNew` / `csOld` — active, value applied. **The difference is informational; no code in
  the program reads it.** It records **whether the command came from N6TR's DOS TR LOG
  (`csOld`) or is new in TR4W (`csNew`)** — settled 2026-08-07 by archaeology, not guesswork:

  `CFGStatus = (csNew, csOld, csRem)` and `CFGStatusArray = ('New','Old','Removed')` are
  present in the 2014 initial import (`b90ba930`, v4.30.3), so they predate this repository
  and were written by the original Win32 port author. The only consumer was
  `uDocumentation` — **source never committed**, but its compiled `.dcu` survives in
  `tr4w/bin/`. Its strings give the game away:

  ```
  <TH>#</TH><TH>Command</TH><TH>Status</TH><TH>Type</TH>
  <H3>TR LOG commands supported by %s.</H3>
  "Removed, not supported"      BGCOLOR=#FFFF88 / BGCOLOR=#88FFFF
  WriteCommandsNew  GenerateSupportedCommandsNew  bgColor
  d:\...\workspace\CMS\out\commands_help_RUS.ini
  ```

  It generated the tr4w.net command reference from `CFGCA`, with a **Status column** and
  row colours driven by `CFGStatusArray` — and it produced `commands_help_*.ini`, which TR4W
  **still ships as a runtime dependency**.

  **Corroborated independently by the data itself.** If `csOld` means "inherited from TR
  LOG", commands that could not exist in a DOS logger must be `csNew` — and they are,
  without exception in the spot check:

  | Command | `crS` | |
  |---|---|---|
  | `WSJT-X ENABLED`, `TELNET SERVER`, `DEBUG LOG LEVEL`, `ALLOW AUTO UPDATE` | `csNew` | impossible in DOS |
  | `MY CALL`, `SPRINT QSY RULE`, `TEN MINUTE RULE`, `MY GRID`, `BEEP ENABLE` | `csOld` | classic TR LOG |
  | `MULTI PORT`, `MULTI PORT BAUD RATE` | `csRem` | TR LOG's DOS serial multi-station link, **dropped** by TR4W for TCP/IP |

  The `csRem` row is the clincher: it marks a TR LOG command TR4W does not support, which is
  exactly the generator's label *"Removed, not supported"*.

  **Third line, external and independent (NY4I):** TR LOG's own release history at
  <https://www.trlog.com/revhistory.shtml> names commands in UPPERCASE, and every one
  checked so far is `csOld` here.

  **The original TR4W manual was checked (NY4I, 2026-08-07) and says nothing about this.**
  Don't spend time there again — the evidence is the `.dcu`, the correlation above, and the
  TR LOG release notes.

  **Why it matters: barely, and that is the useful conclusion.** `csNew`/`csOld` is inert
  provenance — nothing reads it, nothing routes on it, and it has no bearing on retiring a
  key into JSON. The fields that decide that work are `crC`, the *other* `crS` values
  (`csOwned` / `csRem` / `csJSON`), `crA`, `crKind`/`crType`, `crNetwork` and `crJ`. This
  entry exists so the question stays closed, and so a migration leaves the field alone
  instead of wondering whether it encodes behaviour.

  So the field is not dead metadata; it is documentation provenance whose generator was
  lost. **Set it honestly on new rows** (`csNew` for anything TR LOG never had), and treat
  it as read-only history otherwise.
- `csRem` — retired. Still recognised so an old config does not error, but `CheckCommand`
  exits early and it is hidden from Options.
- `csOwned` — **live and applied, but hidden from Options because another dialog owns it.**
  Not the same as `csRem`. The radio-configuration path depends on `CheckCommand` still
  accepting these.

`crS` is *provenance*, **not permission** — it does not make a key read-only. That is `crJ`.

#### Retiring a key into JSON: use `crS`, but in stages

When a setting moves to `settings\tr4w.json`, the ini row must stop being a second owner —
otherwise you get the `57a7f2ee` bug, where a hand-edited ini beat the library. `crS` is the
lever, but **"moved to JSON" is not one condition**, because `CheckCommand` is not only the
ini reader:

| Situation | Marker | Effect |
|---|---|---|
| JSON renders legacy keys; `CheckCommand` still applies them | `csOwned` | applied, hidden from Options — what the radio keys use today |
| JSON is the only source; nothing needs the legacy path | `csRem` (see `csJSON` below) | accepted so old files do not error, but **inert** |
| Key must stay settable from a contest `.cfg` **or** the network | **stays live** | never retired, whatever the ini does |

**The third row is the one that bites.** `csRem` makes `CheckCommand` return early
(`uCFG.pas:1135`), and the contest `.CFG` reaches *the same* `CheckCommand`
(`LogCfg.pas:825`). So retiring `MY STATE` would not merely drop the ini copy — it would
make the **contest override inert**: travel to Georgia, set `MY STATE=GA` in the contest
`.cfg`, and TR4W ignores it. That is the station-defaults ← event-overrides model disabled
by the very marker meant to protect it. The same applies to any `crNetwork = 1` row, because
`uNet.pas:318` feeds inbound multi-op values through `CheckCommand` too.

So: a **station-only, non-synced** key can be retired. An **overlap** key never can — for
those, the `.cfg` path is a feature, not a legacy fallback.

#### `csJSON` — proposed 2026-08-07, **IMPLEMENTED** (see below)

`csRem` already means something specific and historical — *this command was withdrawn*.
Reusing it for migrated keys would conflate two unrelated stories and lose the ability to
ask "what have we moved so far?".

**Proposal: add `csJSON`, behaving exactly like `csRem` (accepted, inert, hidden) but
recording a different reason** — *this setting now lives in `tr4w.json`*.

**Existing `csRem` rows stay as they are.** They are already dead; there is nothing to move
and no value in migrating a command nobody can set.

It also earns its keep in the **Ctrl+J** command-configuration dialog (`uOption.pas`, bound
at `uMenu.pas:42`). That list should shrink as settings move into Preferences, and `csJSON`
makes the shrinking automatic *and* self-documenting — a reader can tell **why** a row is
hidden:

| Status | Hidden from Ctrl+J | Legacy path still applies? | Means |
|---|---|---|---|
| `csOwned` | yes | **yes** | another *dialog* owns the UI; the ini value is still the transport |
| `csJSON` | yes | no | another *store* owns the value; `tr4w.json` is the source |
| `csRem` | yes | no | withdrawn; nobody owns it |

Implementing it is small but **must be done completely**, because a new enum value that no
branch handles would fall through as *active*:

1. `CFGStatus` in `VC.pas:859`.
2. `CFGStatusArray` (`uCFG.pas:315`) — indexed by `CFGStatus`, so a missing entry is a
   **compile error**. That is how `csOwned`'s omission was caught (`uCFG.pas:314`), and it
   is the safety net here too.
3. `CheckCommand` (`uCFG.pas:1135`) — treat as `csRem`.
4. `uOption.pas:343` — hide it, alongside `csRem` and `csOwned`.

**All four are done** (`VC.pas:866`, `CFGStatusArray`, `uCFG.pas:1139`, `uOption.pas:348`),
and the first rows have moved: the seventeen WinKeyer rows and the three
`UDP BROADCAST …` rows are `csJSON` today. The radio rows have **not** — all 54 are still
`csOwned`, which is why `tr4w.ini` is still both read and written for them.

---

## Migrating the RADIO rows — the audit

`csOwned` → `csJSON` for radios cannot be done in one pass. Running this document's own
"simple row" test (`ckNormal` ∧ `crA = 0` ∧ `crType ≠ ctFreqList`) over the 54 `csOwned`
radio rows splits them four ways, and only the first group is a value copy.

**The retirement and the direct applier are ONE piece of work, per set.** `csJSON` makes
`CheckCommand` inert, and `CheckCommand` is currently the *only* thing that moves a radio
definition into the live globals — `ApplyRadioToSlot`'s own comment says so. Retiring a set
without an applier for it does not fall back to the ini; it silently configures nothing.
`uKeyerConfigApply.pas` is the precedent and says the same in its header.

### Set 1 — 25 plain scalars — **DONE 2026-08-10** (`efda90c8`)

Moved to `csJSON` together with `ApplyJSONOwnedRadioKey` in `uRadioConfigApply.pas`, in one
commit, per the rule below. The applier consumes the **rendered value**, not the typed
`TRadioDefinition`, because the renderer holds rules that are load-bearing and bench-proven
(transport blanking, the TCP-port default, FACTORY ID emit-vs-delete); re-deriving them
would be the second implementation the vocabulary hazard warns about. Bounds moved with the
values — bypassing `CheckCommand` bypasses `crMin`/`crMax`, and a `Str20` truncates in
silence.

`Lint-ConfigOwnership.ps1` was **strengthened, not relaxed**: it now reads the applier and
fails the build on a `csJSON` row no applier handles, so the one-commit rule is enforced
mechanically rather than by memory. Still owed: a Pascal unit test of the applier's bounds
(the unit is not linked into the test EXE).

### Set 1 — the original audit
`ckNormal`, `crA = 0`, `crNetwork = 0`, non-boolean. `NAME`, `IP ADDRESS`, `TCP PORT`,
`SERIAL FORMAT`, `STARTUP COMMAND`, `RECEIVER ADDRESS`, `HAMLIB ID`, `FREQUENCY ADDER`,
`ICOM DATA MODE ID`, `KEYER STOP BITS`, `NETWORK USERNAME`, `NETWORK PASSWORD` (both
slots), plus `RADIO ONE FACTORY ID`.

### Set 2 — 16 rows that are not a value copy
Twelve `ckList` (`CONTROL PORT`, `CAT RTS/DTR`, `KEYER RTS/DTR`, `TYPE`) and four `ckArray`
(`BAUD RATE`, `ICOM FILTER BYTE`). The value is a *spelling* in `lpArray` and `crAddress`
is an index. Needs one explicit spelling→enum translation site — exactly what
`uKeyerConfigApply` did for `KeyerModeSA` / `PortTypeSA`. **This is where the vocabulary
hazard named in `crKind` lives, and it has already bitten twice**: `NONE` vs `TCP/IP` cost a
bench session, and the same mismatch in the seeding direction silently converted a network
K4 to serial (fixed 2026-08-09).

### Set 3 — `RADIO ONE/TWO TYPE`, `crA = 9/10`
The only radio rows with a parse-time hook, and the most important rows in the table. Per
the `crA` section, these **cannot be moved by copying a value** — the hook must still run or
dependent globals go stale.

### Set 4 — 12 booleans, BLOCKED on `BOOLSWAP`
`POLL RADIO ONE/TWO`, `CW BY CAT`, `CW SPEED SYNC`, `USE HAMLIB`, `WIDE CW FILTER`,
`FT1000MP CW REVERSE`. `BOOLSWAP` ignores `crS` entirely and writes `crAddress` directly, so
marking these `csJSON` leaves a CW-message macro able to flip a legacy global that JSON
believes it owns. **Do not retire these until `BOOLSWAP` is taught the store** — the
"three consumers" section above predicted exactly this.

### Data defects found during the audit (2026-08-09)
Slot ONE and slot TWO disagree on three rows. Each is a one-word fix, but each changes
behaviour, so they are listed rather than silently corrected:

| Row | `RADIO ONE` | `RADIO TWO` | Consequence |
|---|---|---|---|
| `FACTORY ID` | `crNetwork:0` | `crNetwork:1` | only slot 2 syncs to multi-op; retiring slot 2 breaks that receive path, slot 1 has nothing to break |
| `FREQUENCY ADDER` | `crJ:0` | `crJ:2` | editable on one radio, read-only on the other |
| `RECEIVER ADDRESS` | `crJ:0` | `crJ:2` | same |

`FACTORY ID` is also `crJ:0` on both, which the `crJ` section already flags as wrong — it
should be `crJ:2`.

### `crA` — the deeper-processing hook, which can also reject
Index into `AdditionalProcsArray[1..25]` (`uCFG.pas:194`); `0` = none. NY4I's framing: the
byte selects a procedure that provides **additional processing** for the parameter — e.g.
`BAND MAP CUTOFF FREQUENCY` carries `crA:17`, and element 17 is
`@F_BAND_MAP_CUTOFF_FREQUENCY`.

Every entry is a **parameter-less boolean function**, and its result becomes
`CheckCommand`'s result (`uCFG.pas:1287-1298`). A `False` return reaches callers as "command
not accepted"; `LogCfg.pas:825` then warns or shows a dialog.

**The raw text arrives through a GLOBAL, not a parameter.** `CMD: ShortString`
(`uCFG.pas:323`) is assigned `CMD := CustomCMD` immediately before the call
(`uCFG.pas:1289`). So these functions are **not pure** — anything that invokes one outside
`CheckCommand` must set `CMD` first, or it parses whatever the last command left behind.

**`crA` is not one thing. It has at least two shapes, and they differ in whether the value
was already stored:**

- **Derive after the store.** `F_ZONE_MULTIPLIER` (`uCFG.pas:1477`) reads the global that
  was just assigned and derives dependent state — `ActiveInitialExchange`,
  `CTY.ctyZoneMode`. Returns `True` unconditionally.
- **Parse, validate and apply, itself.** `F_BAND_MAP_CUTOFF_FREQUENCY` does the whole job:

  ```pascal
  function F_BAND_MAP_CUTOFF_FREQUENCY: boolean;
  begin
     Val(CMD, TempLongInt, Result1);
     Result := Result1 = 0;                            // the boolean IS the parse result
     if Result then
        AddBandMapModeCutoffFrequency(TempLongInt);    // applies to a LIST, not a scalar
  end;
  ```

Consequence for migration: **a row with `crA <> 0` cannot be moved by copying a value.** The
hook must still run — or dependent globals go stale, and for the second shape the value is
never applied at all. `uCFG.pas:945` already treats `crA = 0` as part of what makes a
command "simple".

### `crC` — WHICH FILE the editor writes to
`1` → the contest `.CFG`; otherwise `tr4w.ini`. The default is set first
(`p := TR4W_INI_FILENAME`) and `crC` overrides it (`uOption.pas:765`, `:772`).

**This is the station-vs-event scope attribute, and it already exists.** 29 rows are
`crC:1`, 477 are `crC:0`. See `docs/` audit notes: 16 keys that appear in real contest
`.CFG` files are nonetheless `crC:0`, which is where the layering work concentrates.

## Contest scope — NY4I's classification (2026-08-15)

**This is the authoritative answer to "which commands belong to a contest".** It supersedes guessing
from names, and it is what the migration works from: everything NOT on this list *"should go into
the registry and not exist in this Ctrl-J any longer"* (NY4I).

`crC` was the closest thing to this attribute and it is **not reliable** — see the conflicts below.

**Ruled 2026-08-15:** `HF BAND ENABLE`, `WARC BAND ENABLE` and `VHF BAND ENABLE` are contest-level.
NY4I: *"This does not currently consider that a contest level but I do so it goes there."* That also
settles an inconsistency in the table — `HF` and `VHF` are `crC:1` while `WARC` is `crC:0`, for three
settings handled identically, so **`WARC BAND ENABLE` should become `crC:1`** as a data fix.

### The contest set — 63 of the 207 rows still `csOld`

* `BAND`
* `CALL OK NOW CW MESSAGE`
* `CALL OK NOW MESSAGE`
* `CALL OK NOW SSB MESSAGE`
* `CLEAR DUPE SHEET`
* `CONTEST`
* `CONTEST NAME`
* `CONTEST TITLE`
* `CQ CW EXCHANGE`
* `CQ CW EXCHANGE NAME KNOWN`
* `CQ EXCHANGE`
* `CQ EXCHANGE NAME KNOWN`
* `CQ SSB EXCHANGE`
* `CQ SSB EXCHANGE NAME KNOWN`
* `DOMESTIC FILENAME`
* `DOMESTIC MULTIPLIER`
* `DX MULTIPLIER`
* `EXCHANGE RECEIVED`
* `HF BAND ENABLE`
* `LATEST CONFIG FILE`
* `LOG RS SENT`
* `LOG RST SENT`
* `LOOK FOR RST SENT`
* `MODE`
* `MULT BY BAND`
* `MULT BY MODE`
* `PREFIX MULTIPLIER`
* `QSL CW MESSAGE`
* `QSL MESSAGE`
* `QSL SSB MESSAGE`
* `QSO BEFORE CW MESSAGE`
* `QSO BEFORE MESSAGE`
* `QSO BEFORE SSB MESSAGE`
* `QSO BY BAND`
* `QSO BY MODE`
* `QSO POINT METHOD`
* `QSO POINTS DOMESTIC CW`
* `QSO POINTS DOMESTIC PHONE`
* `QSO POINTS DX CW`
* `QSO POINTS DX PHONE`
* `QUICK QSL CW MESSAGE`
* `QUICK QSL CW MESSAGE1`
* `QUICK QSL KEY 1`
* `QUICK QSL KEY 2`
* `QUICK QSL MESSAGE 1`
* `QUICK QSL MESSAGE 2`
* `QUICK QSL SSB MESSAGE`
* `R150S MODE`
* `REPEAT S&P CW EXCHANGE`
* `REPEAT S&P EXCHANGE`
* `REPEAT S&P SSB EXCHANGE`
* `RFOBL MODE`
* `S&P CW EXCHANGE`
* `S&P EXCHANGE`
* `S&P SSB EXCHANGE`
* `SHORT 0`
* `SHORT 1`
* `SHORT 2`
* `SHORT 9`
* `SINGLE BAND SCORE`
* `VHF BAND ENABLE`
* `WARC BAND ENABLE`
* `ZONE MULTIPLIER`

Marked **(macro)** by NY4I, meaning a CW/SSB message template: `CALL OK NOW *`, `CQ CW *`,
`CQ SSB *`, `QSL *`, `QSO BEFORE *`, `QUICK QSL *`, `REPEAT *`, `S&P *`. **These come last** — the
macro definitions are contest-scoped but their design is deferred, so nothing should migrate or
re-home them yet.

Three on his list are already `csNew` rather than `csOld` and so need no action: `LATEST CONFIG
FILE`, `R150S MODE`, `RFOBL MODE`.

### 144 rows to migrate to the registry

Everything else still `csOld`. They leave Ctrl-J, stop being read from and written to `tr4w.ini`,
and their globals move into the config object.

### 31 of those are contest-driven ANYWAY — this needs a ruling

Not on NY4I's list, but `FCONTEST.PAS` assigns them when a contest is selected, or they are declared
`crC:1`. **Migrating one as a flat station setting gives Preferences an editor whose value is
silently replaced at the next contest selection.** It is the same problem as the three band-enable
rows just ruled on, and those were not the only ones.

| command | `crC` | `FCONTEST` writes | in real `.cfg` |
|---|---|---|---|
| `LITERAL DOMESTIC QTH` | 1 | **11×** | — |
| `EXCHANGE MEMORY ENABLE` | 0 | **6×** | — |
| `MINITOUR DURATION` | 0 | **6×** | — |
| `AUTO DUPE ENABLE CQ` | 0 | **5×** | — |
| `COUNT DOMESTIC COUNTRIES` | 0 | **5×** | — |
| `DIGITAL MODE ENABLE` | 0 | **5×** | — |
| `MULTIPLE BANDS` | 1 | **5×** | 1 |
| `SPRINT QSY RULE` | 1 | **5×** | — |
| `AUTO DUPE ENABLE S AND P` | 0 | **4×** | — |
| `INITIAL EXCHANGE OVERWRITE` | 1 | **4×** | — |
| `CALLSIGN UPDATE ENABLE` | 1 | **2×** | 10 |
| `INITIAL EXCHANGE CURSOR POS` | 1 | **2×** | — |
| `MULTIPLE MODES` | 1 | **2×** | 1 |
| `QSO NUMBER BY BAND` | 1 | **2×** | — |
| `CONTACTS PER PAGE` | 0 | **1×** | — |
| `QTC ENABLE` | 0 | **1×** | — |
| `CATEGORY-ASSISTED` | 1 | — | 73 |
| `CATEGORY-BAND` | 1 | — | 73 |
| `CATEGORY-MODE` | 1 | — | 73 |
| `CATEGORY-OPERATOR` | 1 | — | 73 |
| `CATEGORY-OVERLAY` | 1 | — | — |
| `CATEGORY-POWER` | 1 | — | 73 |
| `CATEGORY-TRANSMITTER` | 1 | — | 73 |
| `COLUMN AUTOSIZE` | 1 | — | — |
| `HAND LOG MODE` | 1 | — | — |
| `INITIAL EXCHANGE` | 1 | — | — |
| `INITIAL EXCHANGE FILENAME` | 1 | — | — |
| `SHIFT KEY ENABLE` | 1 | — | — |
| `SHORT INTEGERS` | 1 | — | — |
| `STATIONS CALLSIGNS MASK` | 1 | — | — |
| `TEN MINUTE RULE` | 1 | — | — |

`BAND` and `MODE` are the extreme cases — 29 and 9 `FCONTEST` writes — and are arguably not settings
at all but *current operating state* that a contest initialises, the same category as `CODE SPEED`.

**Until this is ruled on they are held back and the other 113 proceed.** Splitting the batch costs
nothing; migrating a contest-owned row costs a defect that only shows up when someone changes
contest.

### Macro siblings

**Answered 2026-08-15:** *"cq exchange was an omission. it is a macro."* `CQ EXCHANGE` and
`CQ EXCHANGE NAME KNOWN` are in the contest set with the CW and SSB members. The pattern is
`^CQ EXCHANGE` and not a blanket `^CQ ` — `CQ MENU` is a menu, not a message.

**Still unplaced:** `TAIL END MESSAGE` / `TAIL END CW MESSAGE` / `TAIL END SSB MESSAGE`, the same
shape of macro and on no list. `MULTI INFO MESSAGE` is a message but a multi-op one, not a contest
exchange.

### The limit of the mechanical signals, demonstrated

`LOG RS SENT` and `LOG RST SENT` were ruled contest-scoped on 2026-08-15 while carrying **no
mechanical signal at all** — no `.cfg` file names them, `FCONTEST` never assigns them, and `crC` says
`tr4w.ini`. Every automated test available says station setting, and every one of them is wrong,
because whether the log records the RST you sent is a property of the contest's exchange.

So the scans in this document **narrow the review, they do not replace it**. A row landing in the
"no contest signal" pile is a default, not a finding. `LOOK FOR RST SENT` is the third member of
that family and is still unruled for exactly this reason.


### `crP` — post-change UI refresh
Index into `CommandsProcArray[1..13]` (`uCFG.pas:225`), all `@Display*` / `@Update*`
procedures (`DisplayBandMap`, `DisplayCodeSpeed`, `UpadateMainWindow`, …). `0` = none.
Called after a value changes from three places: `MainUnit.pas:8501`, `uOption.pas:726`,
`uProcessCommand.pas:644`.

So `crA` and `crP` are **not** two flavours of the same thing: `crA` is parse-time
semantics (derive, validate, reject); `crP` is presentation (redraw what now looks wrong).
NY4I's example, `WARC BAND ENABLE`, is `crA:0 crP:1` — nothing to derive, but the band map
must be redrawn.

**Why there are two arrays at all: they hold DIFFERENT SIGNATURES** (NY4I, 2026-08-07).

```pascal
TAdditionalProc = function: Boolean;     // uCFG.pas:958      <- crA
cmdProc         : procedure;             // uOption.pas:445   <- crP
```

`AdditionalProcsArray`'s own comment says *"These m[u]st be boolean functions"*
(`uCFG.pas:194`). One array cannot hold both — calling a `function: Boolean` through a
`procedure` type is a calling-convention error. So the split is **mechanical**, and the
semantic pattern above (validate/derive vs. redraw) is a *consequence* of which signature a
hook needs, rather than the design intent.

Consequence for any rework: the two arrays cannot simply be merged, and adding a hook means
choosing the array by **what it must return**, not by what it conceptually does.

### `crJ` — editor behaviour
`0` editable · `1` editable, requires restart (`uOption.pas:764` sets
`tShouldRestartProgram`) · `2` read-only (`uOption.pas:521` refuses the edit, `:809` greys
the row) · `3` message, read-only.

**A read-only mechanism therefore already exists.** The backlog note claiming the CFG system
has "no read-only attribute" is wrong; `RADIO ONE FACTORY ID` being freely editable is a
*data* problem — that row should be `crJ:2` — not a missing feature.

### `crKind: CFGKind` — the shape of the value
`(ckNormal, ckArray, ckList)`. 434 / 16 / 56 rows.
- `ckNormal` — a single value at `crAddress`.
- `ckArray` — value is numeric, and `crAddress` indexes `ArrayRecordArray`
  (`uCFG.pas:166`), whose rows are `(arArrayPtr, arArrayLength, arVar)`. This is a
  **DISCRETE ALLOW-LIST, not a range**: `SetParameterInArray` (`TF.pas:823`) linearly
  searches for an **exact match**, stores into `arVar` on a hit, and returns `False`
  otherwise — which rejects the command.

  That is a capability `crMin`/`crMax` cannot express, and the non-contiguous arrays are
  the proof: `SCP_MINIMUM_LETTERS_ARRAY = (0, 3, 4, 5)` — **1 and 2 are illegal** — and
  `DITDAHRATIO_ARRAY = (3, 4, 5, 6)`. A 0..5 range would wrongly admit 1 and 2.

  **`ckArray` and `ckList` are also a UI affordance, and that is why they exist** (NY4I,
  2026-08-07). In Ctrl+J the operator **clicks a row to advance its value**: the handler
  finds the current entry, steps to the next, wraps at the end, and writes it back
  (`uOption.pas:539-552`; `ckList` does the same over its text vocabulary at `:528`).
  `ctBoolean` is the degenerate case — `InvertBoolean`, a two-element cycle. So the whole
  dialog is click-to-cycle, and these two kinds are its multi-value generalisation:
  **a simplistic way to avoid a drop-down, which is what the UX should have used.**

  The example row shows the index trap in the source itself — no `@` anywhere:

  ```pascal
  (crCommand: 'LEADING ZEROS'; crAddress: pointer(14); crMin:0; crMax:3; ...
   crKind: ckArray; crType: ctInteger; ...)
  ```

  **Consequence for the FMX Preferences work: these arrays ARE the drop-down item lists.**
  When a `ckArray` or `ckList` setting moves to a designed form, the permitted-values array
  becomes the combo's items, and the click-to-cycle behaviour disappears with the dialog
  that needed it. The data required for the new UI is already in the table.

  **`crMin`/`crMax` are DEAD FIELDS on `ckArray` rows.** The branch goes straight from
  `Val` to `SetParameterInArray` and never reads them (`uCFG.pas:1141-1155`), and their
  values are correspondingly inconsistent — `DIT DAH RATIO` and `MP3 RECORDER BITRATE`
  carry `0/0` while `LEADING ZEROS` carries `0/3`, merely duplicating its array. Generating
  validation from them would accept `SCP MINIMUM LETTERS = 2`, which the program rejects
  today, and would validate nothing at all on the `0/0` rows.
- `ckList` — value is an **enumerated word**; `crAddress` indexes `ListParamArray`
  (`uCFG.pas:243`), whose `lpArray` holds the accepted spellings and `lpVar` the target
  (`uCFG.pas:1159-1166`).

`ckList` is where the **text vocabulary reproduction hazard** lives: anything rendering
legacy keys must emit exactly the spelling in `lpArray` (e.g. `PortTypeSA`). One wrong word
(`NONE` for `TCP/IP`) previously cost a bench session and presented as a radio fault.

### `cfFunc: CFGFunc` — which editor page, and which ini section
`(cfAll, cfCol, cfAppearance, cfWK, cfRadio1, cfRadio2)`. Filters the Options list
(`uOption.pas:351`) **and** selects the ini section name — `cfCol` → `COLORS`,
`cfWK` → `WINKEYER` (`uOption.pas:760-761`), otherwise `_COMMANDS`.

**It says WHERE a command is configured** — which settings page it appears on (NY4I,
2026-08-07). Distribution across the 506 rows:

```
cfAll 438 · cfRadio1 24 · cfRadio2 18 · cfWK 17 · cfAppearance 9 · cfCol 0
```

`cfCol` has **no rows at all**, so the Colors page is populated from something other than
`CFGCA`.

**Only `cfCol` and `cfWK` name an ini section.** `cfRadio1`, `cfRadio2`, `cfAppearance` and
`cfAll` fall to the `else` branch and write to `[COMMANDS]`. So `cfFunc` is a second
storage-routing field alongside `crC`, but for two values only.

**Two subtleties in that `case` (`uOption.pas:758`):**

- It switches on **`CommandsFilter`** — the page being *viewed* — **not** on the row's own
  `cfFunc`. They coincide only because the list is filtered by `cfFunc = CommandsFilter`
  (`uOption.pas:351`). Anything that writes outside that dialog cannot rely on the
  coincidence.
- The `cfCol` / `cfWK` branches **never consult `crC` or the `crJ = 1` restart flag** —
  both live in the `else`. Verified latent, not live: no `cfWK` row sets either. But a
  future `cfWK` row with `crJ:1` would silently fail to prompt for a restart.

### `crType: CFGType` — value type and editor
`(ctFreqList, ctDirectory, ctFileName, ctMessage, ctMultiplier, ctBoolean, ctReal, ctByte,
ctInteger, ctWord, ctString, ctURL, ctCaseSensitive, ctPassword, ctOperation, ctOther,
ctChar, ctAlphaChar, ctPortLPT, ctBand)` (`VC.pas:861`). Decides how the text is parsed,
how `crAddress` is written (`PWORD`, etc.), and which editor the Options page offers.

`ctPassword` matters for a JSON migration: whatever the ini does about secrecy today, the
new store should not quietly change it.

### `crNetwork` — multi-op sync
`1` → the value is pushed to other stations on change; `0` → not.
Honoured in `SendParameterToNetwork` (`uOption.pas:865`, which logs the skip at `:867`) and
used to grey the UI control (`uOption.pas:834`, `:842`).

**This answers "which settings sync in multi-op" without reverse-engineering** — the table
already declares it per row. Any key that moves to JSON must keep its sync behaviour, and
`uNet.pas:318` feeds inbound network values back through `CheckCommand`, so the receive path
depends on the row continuing to exist.

---

## What this means for retiring the ini

A row is **not** just "a key and a value". Moving one has to preserve, at minimum:
its parse-time hook (`crA`), its UI refresh (`crP`), its edit policy (`crJ`), its value
shape (`crKind` — and the `crAddress`-is-an-index trap), its vocabulary (`ckList`), its
network behaviour (`crNetwork`), and both storage-routing fields (`crC`, `cfFunc`).

The encouraging part: those fields already exist and are already honoured. The work is
**auditing the classification**, not inventing a mechanism.

## Decisions taken (2026-08-07)

- **Scope of the ini retirement is the INI ONLY.** Contest `.cfg` and `.dom` go with the
  contest factory. `.dom` turns out to be multiplier data, not config commands, so it was
  never in this namespace.
- **Station defaults ← contest/event overrides.** `MY STATE = FL` is identity; `MY STATE =
  GA` in a contest `.cfg` is where you operated that weekend, and `MY PARK` only exists for
  an event. A contest `.cfg` continuing to win while loaded is the semantics, not a
  precedence hack — and it is already the behaviour, since the `.cfg` loads after the ini.
- **`crC` is the existing station-vs-event routing bit** — 29 rows `crC:1`, 477 `crC:0`.
  16 keys observed in real `.CFG` files are nonetheless `crC:0`; that set is the work list.
- **Retire with `crS`, in stages, and add `csJSON`** — see the `crS` section above.
- **`ctFreqList` becomes a JSON array.** Confirmed for `BAND MAP CUTOFF FREQUENCY` (12 bare
  integers). `FREQUENCY MEMORY` is really a 2-D table — `DefaultFreqMemory[band, mode]`,
  where the **band is derived from the frequency** by `CalculateBandMode` and the mode comes
  from an `SSB ` text prefix (`uCFG.pas:1375`) — so store `{mode, freq}` and keep deriving
  the band, rather than transcribing the ini's flat repeated key.

## Open questions for NY4I

*(`csNew` vs `csOld` is no longer open — answered in the `crS` section above: TR LOG
heritage vs. new in TR4W, evidenced from the lost `uDocumentation` generator.)*

*(`crA` vs `crP` is no longer open — answered in the `crA` section above: two arrays because
two signatures, `function: Boolean` vs `procedure`.)*

*(`cfRadio1`/`cfRadio2` is no longer open — answered in the `cfFunc` section above: they do
not name a section; `cfFunc` says which settings page a command is configured on.)*

**None — all five are answered.** `ckArray` was the last: it is a discrete allow-list *and*
a click-to-cycle UI affordance, superseded by a drop-down in a designed form. See `crKind`.

If a new question arises, add it here rather than leaving it in a commit message.
