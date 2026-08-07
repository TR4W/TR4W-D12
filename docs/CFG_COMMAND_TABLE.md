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
- `csNew` / `csOld` — active, value applied. **The difference is informational; no code
  reads it.** **[UNCONFIRMED]** what the distinction was meant to record (new in TR4W vs.
  inherited from TR-DOS?).
- `csRem` — retired. Still recognised so an old config does not error, but `CheckCommand`
  exits early and it is hidden from Options.
- `csOwned` — **live and applied, but hidden from Options because another dialog owns it.**
  Not the same as `csRem`. The radio-configuration path depends on `CheckCommand` still
  accepting these.

`crS` is *provenance*, **not permission** — it does not make a key read-only. That is `crJ`.

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
- `ckArray` — value is numeric; `crAddress` indexes `ArrayRecordArray`, and
  `SetParameterInArray` writes into the target array (`uCFG.pas:1141-1155`).
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

## Open questions for NY4I

1. **`csNew` vs `csOld`** — nothing reads the difference. What was it meant to record?
2. **`crMin` on non-numeric rows** — meaningful, or conventionally 0?
3. **`crA` vs `crP`** — is "derive/validate" vs "redraw" the intended division, or did it
   grow that way?
4. **`ckArray`** — 16 rows; is it still the right mechanism, or a legacy of the DOS table?
5. **`cfRadio1` / `cfRadio2`** — do they select an ini section as `cfCol`/`cfWK` do?
