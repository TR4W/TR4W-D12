# Eliminating the CFG array

**Started 2026-09-10.** Directed by NY4I in the same conversation that decided
`SERIAL n` has to go: *"we need to move away from the OS name such as serial N"*,
then *"work on the elimination of the cfg array"*.

This document is the **map and the running status**. It replaces nothing: read
[`CFG_MIGRATION_PLAN.md`](CFG_MIGRATION_PLAN.md) for the per-unit detail of the
ini-to-JSON move and [`CFG_COMMAND_TABLE.md`](CFG_COMMAND_TABLE.md) for the radio
row audit. What is new here is the measurement of what the array still **does**,
which turns out not to be what the older documents assume.

---

## 1. The reframe: `csOld` is zero, and the job is not close to done

Every note in `docs/` and in the agent memory tracks progress by counting rows
still marked `csOld` or `csNew`, because those are the rows the operator can
still see in Ctrl-J. **That number is now 0.**

Measured 2026-09-10 over `tr4w/src/uCFG.pas`, live rows only, comments excluded:

| `crS` | rows |
|---|---:|
| `csJSON` | 313 |
| `csOwned` | 94 |
| `csRem` | 84 |
| `csOld` / `csNew` | **0** |

**Reading that as "done" would be the mistake this document exists to prevent.**
`csJSON` means the row's value is *stored* in `settings/tr4w.json` rather than in
`tr4w.ini`. It does **not** mean the row is inert. `CheckCommand` takes an
`aApplyJSONOwned` flag, and the comment at `uCFG.pas:1866` is explicit about why:

> *The inertness exists to stop a STALE INI FILE overriding `settings\tr4w.json`
> … That is a statement about the ini LOADER, not about every caller. A value
> arriving from a trusted source -- the settings screens, or a multi-op peer --
> still has to be APPLIED, and applied through here.*

So Preferences, the multi-op peer sync, and the profile applier all still drive
settings **as text commands through this array**. The store moved. The applier
did not.

**407 live rows still apply.** That, not 0, is the size of the thing.

> It was 408 the day this was written. `ORION PORT` was retired on
> 2026-09-10, and that is the unit of progress here: one row at a time.

---

## 2. What the array actually is

`CFGCA` is three mechanisms wearing one name. They need different work, so
counting rows without splitting them gives a misleading total.

| how the row reaches its value | rows | what replacing it means |
|---|---:|---|
| `crAddress: @SomeGlobal` | **270** | the value has to live somewhere typed |
| `crAddress: @Config.SomeField` | **71** | already done -- this is the destination |
| `crAddress: pointer(N)`, an index into `ListParamArray` or `ArrayRecordArray` | **66** | a spelling table has to stop being the parser |
| `crAddress: Pointer(7)` with no array | 1 | one oddity, unexamined |

By kind: 342 `ckNormal`, 52 `ckList`, 14 `ckArray`.

**The 71 are the shape everything else is heading for.** A `Config` record field
is reachable by name, typed by the compiler, and needs no text at all. The
remaining 270 are bare globals, and moving one is the five-step operation
recorded in agent memory, two of whose steps are silent data loss when skipped.

### The spelling tables

The 66 indexed rows resolve through **54 `ListParamArray` entries over 40
distinct spelling tables**. Two tables carry most of the reuse:

| table | entries |
|---|---:|
| `tr4w_RTSDTRTypeSA` | 8 |
| `PortTypeSA` | 6 |
| `BandStringsArrayWithOutSpaces`, `RadioTypeTokensA` | 2 each |
| the other 36 | 1 each |

**These tables are the second definition problem in its purest form.** A spelling
table is a hand-written array of the text form of an enum, indexed by ordinal,
matched case-insensitively by `TF.GetValueFromArray`. Nothing checks that the
table and the enum agree. The radio work already found what that costs: the
name table was missing `TS140` and carried a `TS530` the enum never had, so a
config saying `TS440` selected the TS-140 driver, for four Kenwoods, for years.

`GetValueFromArray` is also the routine whose pointer walk crashed on Linux in
September, because it computed a stride of 4 for an array of pointers. **Forty
tables reach through that one function**, which is every enumerated config value
the program has.

---

## 3. Stage A -- DONE 2026-09-10

**One rule for turning a configured port into a device name.**

It had been written five times: `ConvertPortTypeToCOMString` in `MainUnit`, and
four bare `Format('COM%d', [Ord(port)])` calls in the radio factory, the CW
keyer, the rotator controller and the WinKeyer. Three of the four carried a
comment naming the other copies.

It is `uPortAddress.SerialDeviceName` now, with an exhaustive pin test over the
enum and a round-trip test against `ComPortEnumerator.ComPortNumber`.

**It found a defect in three of the five.** They guarded with `<> NoPort`, which
a port configured as `NETWORK` satisfies -- ordinal 65, one past `Serial64` --
so the name built was `COM65` and the open went against whatever answered.
`SerialDeviceName` returns `''` for anything that is not serial, and those three
now refuse and log which port kind they were handed.

This is the choke point everything in stage B flows through.

---

## 4. Stage B -- the port rows. PLANNED, NOT STARTED

This is the slice NY4I's `SERIAL n` decision authorises, and it is deliberately
**not** started without review: it touches the profile applier and the radio
open path, which is the most bench-sensitive code in the program and the part
CLAUDE.md is clearest about not trusting to code review.

### What holds it up today

Seven `CFGCA` rows resolve through six `ListParamArray` entries over `PortTypeSA`:

| command | `crS` | variable |
|---|---|---|
| `RADIO ONE CONTROL PORT` | `csOwned` | `Radio1.tCATPortType` |
| `RADIO TWO CONTROL PORT` | `csOwned` | `Radio2.tCATPortType` |
| `KEYER RADIO ONE OUTPUT PORT` | `csOwned` | `Radio1.tKeyerPort` |
| `KEYER RADIO TWO OUTPUT PORT` | `csOwned` | `Radio2.tKeyerPort` |
| `ROTATOR PORT` | `csOwned` | `ActiveRotatorPort` |
| ~~`ORION PORT`~~ | **`csRem` 2026-09-10** | ~~`ActiveRotatorPort`~~ -- retired, see below |
| `WK PORT` | `csJSON` | `WinKeySettings.wksWinKey2Port` |

~~`ORION PORT` and `ROTATOR PORT` are two commands writing one variable.~~
**RULED 2026-09-10.** NY4I: *"Drop Orion port. It covered by the general port
as a type Orion in settings".* It was shorthand for "the rotator is an Orion,
on COM5" -- a second spelling of two other settings, in the same family as
MY QTH being MY STATE -- and its `crA` hook did nothing but set the rotator
type.

It is `csRem`, **not deleted**, and that difference matters to an operator
upgrading from 4.x: a withdrawn row is still RECOGNISED, so an existing `.cfg`
naming it loads inert instead of erroring on every start. Its hook is deleted
and its slot in `AdditionalProcsArray` is `nil` rather than removed, because
that table is positional and dropping an entry would shift every `crA` above
it and repoint twenty-one rows at the wrong hook.

So the port rows are **six**, over five `ListParamArray` entries.

### The chain, and why it has four spellings of one fact

```
   the drop-down          /dev/ttyUSB0   or   COM7      the OS name
   ComNameToPortValue     'SERIAL 7'                    TR4W's own token
   settings/tr4w.json     "controlPort": "SERIAL 7"
   the legacy key text    RADIO ONE CONTROL PORT = SERIAL 7
   PortTypeSA             ordinal 7                     a third spelling
   SerialDeviceName       'COM7'                        the OS name again
   TSerialPort.Create     opens it
```

**Both ends are the OS name.** Everything between is TR4W talking to itself, and
the middle is what cannot be spelled on Linux.

### What the change is

`PortType` conflates three questions. Only the first wants an enumeration.

1. **What kind** -- serial, network, LPT, none. Nearly every call site asks only
   this, through `= NoPort`, `= Network` or `in SerialPorts`.
2. **Which port** -- only the name formatter asks, and this is the part that
   cannot exist off Windows.
3. **A small integer to key an array** -- exactly one table wants this,
   `SerialPortObject: array[TSerialPortRange] of TSerialPort` in the CPU keyer,
   and it wants a dictionary.

So: keep a small kind enum, make the address a string that is the OS name, and
let one table become a dictionary. `TSerialPort` needs no change at all -- it
already takes whatever name it is given, and its own comment already lists
`/dev/ttyUSB0` as a case it expects.

### Compatibility, checked rather than assumed

| question | answer |
|---|---|
| does a port cross the multi-op wire? | **No.** The only reference in the networking units is a commented-out line in `lognet.pas` |
| does a shipped contest `.cfg` carry a port? | **No.** None in `target/dom` |
| what must still be read? | an operator's own `settings/tr4w.json` holding `SERIAL n`. A one-way translation at load, the same read-once pattern `uLegacyIniPrompt` already describes |

There is **no deployed encoding to preserve**. The compatibility surface is one
local file.

### Effort, measured

63 references to the four port globals. Sorted by what they actually need:

- **presence and kind tests** -- the large majority. Untouched by the address change.
- **logging and display** -- four sites reading `PortTypeSA`. Cosmetic.
- **conflict detection** -- one site comparing two radios' ports. Works with any comparable value.
- **the parse** -- the seven rows above.
- **the name formatter** -- one, since stage A.
- **one array indexed by the enum** -- the only structural dependency.

---

## 5. Open, and needing a ruling

1. ~~**`ORION PORT` and `ROTATOR PORT` write the same variable.**~~ **CLOSED
   2026-09-10** -- dropped. See stage B.
2. **Does the kind stay an enum, or become a property of a port class?** CLAUDE.md
   prefers a class to a record, but `RadioObject` is an old-style `object` held in
   globals, so an object-typed field there is a lifetime question rather than a
   style one.
3. **Which stage the 270 bare globals move in, and in what themed batches.** They
   are the bulk of the work and none of it is urgent; the port slice is urgent
   because it blocks a platform.
4. ~~**Whether `GetValueFromArray` and the 40 spelling tables get a guard now.**~~
   **HALF-CLOSED 2026-09-10.** `Lint-SpellingTables` gates the build and fails
   on a duplicate or blank spelling, which is the part that makes an enum value
   unreachable by name. 39 tables, 685 spellings, clean. The 40th,
   `RadioTypeTokensA`, is filled from the enum by the registry and has nothing
   to check -- which is the shape the other 39 should end up as.

   **What the lint CANNOT check, and no lint can:** that each spelling means
   what its ordinal means. That is the second definition problem itself, and the
   only real fix is generating the table from the enum.

   It surfaced one thing needing a ruling: **`QSOPointMethodArray` spells
   `ONY` at ordinals 29 and 85.** The second is commented
   `OldNewYearQSOPointMethod` and is the one unreachable; the first carries no
   provenance comment at all. Already noted in `TF.pas`, baselined in the lint,
   and deliberately not touched: which ordinal `ONY` selects decides which
   scoring rule a contest runs under, and the golden corpus is blind to scoring.
