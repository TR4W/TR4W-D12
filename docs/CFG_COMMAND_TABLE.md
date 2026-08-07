# The CFG command table — what every field means

`CFGCA` (`uCFG.pas`) is TR4W's configuration system: **506 rows**, each describing one
configuration command. It is not merely a persistence table — it is simultaneously the
`tr4w.ini` parser, the contest `.CFG` parser, the call-window command vocabulary
(`MY CALL = N6TR`), the Options editor's model, and the multi-op network sync list.

This document exists because the ini is slated for retirement in favour of JSON
(`docs/`-adjacent decision, 2026-08-07), and **anything that migrates a row has to honour
every field on it**. Written by reading the consumers, with line references so each claim
can be re-checked. Items marked **[UNCONFIRMED]** are inferences NY4I should settle.

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
3. **`BOOLSWAP`** (`uProcessCommand.pas:628`) — the CW-message macro
   `BOOLSWAP=<command name>`. **IGNORES `crS` COMPLETELY.** It walks `CFGCA` by name and,
   for any `ctBoolean` row, flips the value **directly at `crAddress`**, then calls `crP`.

**So retiring a boolean does not stop `BOOLSWAP` from setting it.** A key marked `csJSON`
would still be flipped from a function-key message, writing to a legacy global while JSON
believes it owns the setting — the two-owners bug via a path nobody would think to check.
Any boolean that moves to JSON needs `BOOLSWAP` taught about the new store, or its legacy
variable kept live and driven by the JSON layer.

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
- String types: `crMax` is the **maximum input length** the editor allows
  (`uOption.pas:695`).
- **[UNCONFIRMED]** whether `crMin` carries any meaning for non-numeric types, or is
  conventionally 0.

### `crS: CFGStatus` — provenance and visibility
`(csNew, csOld, csRem, csOwned)`, documented at `VC.pas:848-854`:
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

#### Proposed: a `csJSON` status (NY4I, 2026-08-07)

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

### `crP` — post-change UI refresh
Index into `CommandsProcArray[1..13]` (`uCFG.pas:225`), all `@Display*` / `@Update*`
procedures (`DisplayBandMap`, `DisplayCodeSpeed`, `UpadateMainWindow`, …). `0` = none.
Called after a value changes from three places: `MainUnit.pas:8501`, `uOption.pas:726`,
`uProcessCommand.pas:644`.

So `crA` and `crP` are **not** two flavours of the same thing: `crA` is parse-time
semantics (derive, validate, reject); `crP` is presentation (redraw what now looks wrong).
NY4I's example, `WARC BAND ENABLE`, is `crA:0 crP:1` — nothing to derive, but the band map
must be redrawn. **[UNCONFIRMED]** that this division is intended rather than incidental.

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

So `cfFunc` is a second storage-routing field alongside `crC`, and a migration must honour
both. **[UNCONFIRMED]** whether `cfRadio1`/`cfRadio2` also select a section or only filter.

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

1. **`crMin` on non-numeric rows** — meaningful, or conventionally 0?
2. **`crA` vs `crP`** — is "derive/validate" vs "redraw" the intended division, or did it
   grow that way?
3. **`ckArray`** — 16 rows; is it still the right mechanism, or a legacy of the DOS table?
4. **`cfRadio1` / `cfRadio2`** — do they select an ini section as `cfCol`/`cfWK` do?
