# Band plan settings: frequency memories and band-map cutoffs

**Written 2026-08-16** after the two rows were found to be unsafe to render as ordinary settings.
This is the design; nothing here is built yet.

## The one-line version

`FREQUENCY MEMORY` and `BAND MAP CUTOFF FREQUENCY` are **not lists**. Both are arrays **keyed by
band**, and the repeated-key form in `tr4w.ini` is an encoding artifact, not the data model. They
should move to `settings\tr4w.json` keyed by band, and get two grids — frequency memories on a
**Band Plan** page, cutoffs on the **Band Map** page.

## What the data actually is

Read from the code, not from the ini:

```pascal
TFreqMemoryType = array[BandType, CW..Phone] of LONGINT;   // LOGWIND.PAS:125
DefaultFreqMemory : TFreqMemoryType = ( ... );             // LOGWIND.PAS:600

BandMapModeCutoffFrequency : array[Band160..Band2] of LONGINT = ( ... );  // LOGWIND.PAS:516
```

| | shape | mode axis | bands |
| --- | --- | --- | --- |
| `FREQUENCY MEMORY` | `[band, mode]` | **three** slots: `CW`, `Digital`, `Phone` | all of `BandType` |
| `BAND MAP CUTOFF FREQUENCY` | `[band]` | none | `Band160..Band2` only |

**Both already have compiled defaults**, so "if it is not set, use the default" is what happens
today — the ini lines only *override* individual cells. That is the behaviour to preserve, and it is
why an editor can safely show every cell pre-filled.

### The band is DERIVED, never stated

Neither ini line names its band. `F_FREQUENCY_MEMORY` (`uCFG.pas:1827`) and
`AddBandMapModeCutoffFrequency` (`LOGWIND.PAS:3156`) both call `CalculateBandMode(Freq, …)` and use
the answer as the array index:

```pascal
if StringHas(CMD, 'SSB') then          // 'SSB 3850000'  -> the Phone slot
   DefaultFreqMemory[TempBand, Phone] := TempFreq
else                                    // '3525000'      -> the CW slot
   DefaultFreqMemory[TempBand, CW]   := TempFreq;
```

Three consequences worth stating plainly, because they are invisible in the ini:

1. **Two lines for the same band and mode silently overwrite.** The file looks like a list; the store
   is not one.
2. **The `Digital` slot is unreachable from the ini.** The array has three mode slots and the parser
   writes only two — `CW` and `Phone`. The defaults populate `Digital` (e.g. 160 m is
   `1820000 / 1840000 / 1840000`), and nothing an operator can put in `tr4w.ini` will change it.
3. **The cutoff parser silently drops anything above 2 m** — `if TempBand in [Band160..Band2]`. A
   line for 70 cm is accepted, parsed, and discarded without a word.

## Why this cannot use the ordinary settings path

`SetCFGCommandValue` — what every registered setting writes through — does exactly one thing:

```pascal
Windows.WritePrivateProfileStringA(_COMMANDS, @keyShort[1], @valueShort[1], …);
```

**One key, one value, into `[COMMANDS]`.** The band plan is 36 lines living in `[BAND PLAN]`. So a
single edit control bound to one of these rows would write one frequency into the wrong section —
and because the config loader is section-blind (last-in-file wins), that one line could take
precedence over the whole plan.

That is not hypothetical: on 2026-08-16 the generated Preferences page rendered both rows as text
boxes. They are now forced display-only (`CFGCommandIsList` covers `ctFreqList`) precisely so this
cannot happen before the real editor exists.

## The proposed shape

### Storage: `settings\tr4w.json`, keyed by band

A repeated ini key is what a JSON array or object is for. Keying by band explicitly removes the
derive-the-band-from-the-frequency step, which is where the silent behaviour above comes from.

```json
"bandPlan": {
  "frequencyMemory": {
    "160": { "cw": 1820000, "digital": 1840000, "phone": 1840000 },
    "80":  { "cw": 3525000, "phone": 3850000 },
    "40":  { "cw": 7025000 }
  },
  "bandMapCutoff": {
    "160": 1870000,
    "80":  3600000,
    "40":  7100000
  }
}
```

**An absent key means "use the compiled default"** — the same rule as today, now explicit rather
than emergent. That keeps the file small, keeps a new install's file empty, and means shipping a
better default actually reaches operators who never touched the setting.

Band keys are the human band names (`"160"`, `"80"`, `"6"`, `"2"`), not the `BandType` ordinal.
Ordinals would break the moment a band is inserted into the enum — which has already happened once:
`Band60` is **commented out** of `BandType` (`VC.pas:1215`).

### Editing: two grids, on two different pages

| page | control | rows | columns |
| --- | --- | --- | --- |
| **Band Plan** (new) | frequency memories | bands we support | CW · Digital · Phone |
| **Band Map** (exists, Tag 20) | mode cutoffs | `Band160`…`Band2` | one frequency |

Every cell pre-filled with the **effective** value. A cell the operator has not overridden shows the
default in the greyed-hint idiom already agreed for the `MY *` family, so blank reads as "use the
default" rather than as an omission — and clearing a cell restores the default rather than writing a
zero.

The Band Map cutoffs go on the Band Map page rather than the new one because that is what they
affect (`LOGWIND.PAS:3145` uses them to decide a spot's mode), and because the page already exists.

## What has to be built

1. **Store**: a `bandPlan` section in `TRadioConfigStore`, load and save, band names ↔ `BandType`.
2. **Apply**: at startup, overlay the stored values on the compiled defaults — *after*
   `SetConfigurationDefaultValues`, and it must be idempotent.
3. **Seed once from the ini**, like every other migrated setting: read the existing `[BAND PLAN]`
   lines through the current parsers and write the resulting arrays out as JSON. Without this an
   operator's 36 hand-tuned lines silently revert to defaults on the first run — the exact failure
   `SeedMigratedCommandsFromIni` exists to prevent, and the one this work is most likely to repeat.
4. **Two grid controls.** The generated-panel renderer cannot do this — it emits one control per
   scalar setting — so these are hand-built panels, and that is correct: they are the two settings
   that genuinely are not scalars.
5. **Retire the ini rows** to `csJSON` once the store is authoritative, and delete `[BAND PLAN]`
   handling.

## Open questions

**Answered 2026-08-16 (NY4I), and the syntax was then verified by running it.**

### The accepted syntax is exactly two forms

Measured by feeding variants through a headless `/EXPORT`, which logs what the modal would have said:

| ini value | result |
| --- | --- |
| `FREQUENCY MEMORY=3525000` | **accepted** -> the `CW` slot |
| `FREQUENCY MEMORY=SSB 3850000` | **accepted** -> the `Phone` slot |
| `FREQUENCY MEMORY=ssb 3860000` | **accepted** -- the value is case-folded before the test |
| `FREQUENCY MEMORY=CW 3530000` | **REJECTED** -- "Invalid statement in config file" |
| `FREQUENCY MEMORY=ANY 3540000` | **REJECTED** |

So **a bare frequency IS the CW form** -- there is no `CW` keyword, and writing one is an error. The
parser tests only for `SSB`; everything else falls through to `Val`, which fails on any prefix.

Three consequences for the editor:

- **The grid is bands x {CW, SSB}.** Two columns, not three.
- **There is no "any mode".** NY4I's earlier "CW, SSB or ANY" was conceptual; the parser has no such
  form and one should not be invented -- a third column would write a line TR4W refuses to read.
- **The `Digital` slot stays unreachable and unedited.** The array has it, the defaults populate it,
  and nothing in the ini can reach it. Leave it alone rather than exposing a column whose value
  cannot round-trip through the file.

### Band range

**Ignore 60 m, and everything above 70 cm** (NY4I). That settles the `Band60`-commented-out question
for this work -- the grid simply has no 60 m row -- and it matches the cutoff array's own
`[Band160..Band2]` guard closely enough that the two do not need to disagree.

`BAND MAP CUTOFF FREQUENCY` takes **no mode qualifier at all**; the SSB/bare distinction is a
`FREQUENCY MEMORY` feature only.

## What NOT to do

- **Do not teach the ini writer to emit repeated keys.** It would be building new capability into
  the file being retired, and it would not fix the section-blind precedence problem underneath.
- **Do not render either row as a scalar control**, on any page, until the grids exist. That is what
  caused the `SINGLE BAND SCORE=All` corruption on the same day, in the same panel, by the same
  mistake — assuming a row is a scalar because it looks like one in the ini.
