# Eliminating the CFG array

**Started 2026-09-10.** Directed by NY4I in the same conversation that decided
`SERIAL n` has to go: *"we need to move away from the OS name such as serial N"*,
then *"work on the elimination of the cfg array"*.

## IT IS DONE -- 2026-09-14. THE ARRAY IS GONE.

`CFGCA` held **415 rows** when this document was written and holds none. Deleted
with it: `CFGRecord`, `ArrayRecord`, `ListParamRecord`, `CommandsArraySize`, the
`Changed` parallel array, and all four positional side tables --
`ArrayRecordArray` (16), `ListParamArray` (54), `AdditionalProcsArray` (25) and
`CommandsProcArray` (13).

**Measure it rather than believing this line:**

```bash
grep -c "crCommand:" tr4w/src/uCFG.pas          # 0
```

```powershell
.\tr4w\build\Lint-ConfigArrays.ps1              # every ceiling is 0, and 0 is now the PASS
```

**THE LINT IS INVERTED, NOT RETIRED.** It used to ask "has a number risen", which
needed a floor as well -- a count of zero from a broken parser looks exactly like
a count of zero from finished work. Zero is the answer now, so **any** occurrence
fails, it scans the whole tree rather than `uCFG` alone, and it still proves the
parse before believing a zero. Verified with a planted row: it reports `CAME
BACK`.

**WHERE EVERY FIELD WENT**, which is the part worth keeping:

| the row's field | where it went |
|---|---|
| `crCommand` | derived from the property path |
| `crAddress`, `crType` | the property itself |
| `crMin` / `crMax` | a **subrange type**, read back out of RTTI |
| `crP` (redraw index) | the property's **setter** |
| `crA` (additional proc) | an effect in `uSettingsEffects`, which runs however the value was set |
| `crJ` | a parameter on `RegisterModelSetting`, or `TSettingBase.ReadOnly` |
| `crNetwork` | `uCFG.CommandIsSharedWithPeers` -- a statement about the multi-op protocol, not about a setting |
| `crS` | nothing. It was a migratory status |
| a `ckList` spelling table | the **subsystem** registers its own vocabulary |
| a `ckArray` allow-list | a subrange, or `RegisterSettingAllowedValues` |

**FOUR COMMANDS WERE NEVER SETTINGS** and are a named dispatch now,
`uCFG.TryApplyCommandAction`: ADD DOMESTIC COUNTRY, CLEAR DUPE SHEET, BAND MAP
CUTOFF FREQUENCY and FREQUENCY MEMORY. Three append to a list and one is a bare
instruction, so each row was a router to its hook with a `crAddress` pointing at
scratch nobody read back.

**WHAT THE REST OF THIS DOCUMENT IS FOR: the reasoning, not the status.** Read it
to understand why the array was shaped as it was and what each measurement
uncovered -- several of the defects it names were found by doing this work and
are fixed. Do not read any COUNT below this line as current; all of them are
zero.

---

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

---

## 2a. The destination, in NY4I's words

> *"every caller of a parameter in the array should just reference the config
> registry. So rather than reading from json into the registry then setting CFG
> array items to those values callers just access Registry.variable name. That
> way the array can be retired."* -- NY4I, 2026-09-10

So the target is not "move the storage". It is **remove the hop**:

```
   today       JSON  ->  registry  ->  CheckCommand  ->  a global  ->  callers
   target      JSON  ->  registry  ->  callers
```

**THIS OVERRIDES WHAT `uSettingsRegistry`'s OWN HEADER SAYS**, and the header
should be corrected rather than left to contradict the plan. It currently reads:

> *ON THE GLOBALS. This does NOT try to abolish TR4W's global variables; they
> are read from thousands of places and that is a separate, much larger job.
> The registry sits in FRONT of them.*

That was the right scope for building the registry. It is no longer the scope of
the project: the separate, much larger job **is** the job.

### The successor exists, and is UNDER REVIEW rather than settled

**NY4I interrupted the session that built this, deliberately, to review it
(2026-09-10).** So read the table below as *what was built*, not as *what is
agreed*. Nothing in this document depends on it -- the measurements in 1, 2 and
2b are of `uCFG.pas` itself and stand either way -- but the STAGING does: if the
registry's shape changes, the batches in 2b are still the batches, and only
their destination moves.

Work in the 24 hours before this was written, in another session:

| | |
|---|---|
| `uSettingsRegistry` | a setting is a typed getter/setter pair, not an address plus a tag saying how to dereference it |
| the three blocking prerequisites | **closed** -- `ReadOnly` lifts `crJ` 2 and 3, `HasSideEffects` lifts `crP` and `crA`, `Broadcast` lifts `crNetwork` |
| `uTestAllSettings` | walks every real setting, ~1500 assertions, and holds each to the contract a config file and a panel depend on |
| settings actually graduated | **4** -- the QSO-point rows, and they went first because `CFGCA` structurally **could not hold them**: `crMin`/`crMax` are `Word`, so a table row cannot express the -1 those variables legitimately carry |

**That last row is the strongest argument in the whole file.** The table was not
merely inconvenient for those four settings. It could not describe them, and had
been declaring a range its own variables violated.

Note what did NOT happen to those four: their `CFGCA` rows stayed **fully
active**, because a contest `.cfg` sets QSO points and retiring the row would
have left every such contest scoring on -1. **One variable, two writers.** That
is the general case, not an exception, and it is why "retire the row" is a
different decision from "graduate the setting".

---

## 2d. What we would do from scratch in an FPC app

NY4I, 2026-09-10: *"confirm this is the way we should do global settings. And
remember our most important rule is what would we do if we were doing this from
scratch in a FPC app"*.

**The honest answer: from scratch you would NOT build a registry of getter and
setter method pointers. You would declare a settings CLASS with published
properties and let the RTTI streamer persist it.**

```pascal
   TUdpSettings = class(TPersistent)
   published
      property Address: string read FAddress write FAddress;
      property PortScore: integer read FPortScore write FPortScore;
   end;
```

The property NAME is the key. The property TYPE is the type. There is no table,
no `crAddress`, no `crType`, no `crKind`, and no closure pair -- because the
compiler already emits all of that as RTTI, and `fpjsonrtti` already reads it.

### Proven in this toolchain, not assumed

A probe compiled with TR4W's own mode -- `{$MODE Delphi}` plus
`{$MODESWITCH UnicodeStrings}`, which is where this program's string surprises
live -- streamed and re-read a nested settings object:

```
{ "CodeSpeed" : 34, "CwMode" : 1, "MyCall" : "NY4I", "QsoPointsDomesticCw" : -1,
  "SayHi" : true, "Udp" : { "Address" : "192.168.1.255",
  "BroadcastAllQsos" : true, "PortScore" : 12060 } }

ROUND TRIP OK
partial update: MyCall=W1AW CodeSpeed=99 (CodeSpeed must still be 99)
```

Four of those results matter:

| result | why it matters |
|---|---|
| `QsoPointsDomesticCw : -1` | this is the exact value `CFGCA` **structurally cannot hold**, because `crMin`/`crMax` are `Word`. RTTI does not care |
| the nested `Udp` object | settings GROUP. One object per area, not 500 flat keys |
| the enum | `CwMode` round-trips as an ordinal with no spelling table, which is the whole of section 2c |
| the partial update | a key the file does not carry leaves the property alone, so an OLDER settings file is safe by construction rather than by a migration step |

**No new dependency.** `fcl-json` is already on the build's search path for
`uJSON`, and `fpjsonrtti` ships in it. `typinfo` is in the RTL.

### So why does the registry exist, and is it wrong?

**It is the right MIGRATION device and the wrong DESTINATION**, and those are
not in conflict.

You cannot put a `published property` on a global variable, and TR4W has ~500 of
them read from 446 files. The registry's getter/setter pair is the only thing
that can put a typed, key-addressable façade in front of storage it does not
own. That is exactly what it was built for and it does that job well.

But it is a hand-built reflection layer, and FPC already has reflection. Every
column it replaces -- `crType`, `crKind`, `crMin`/`crMax` -- is a fact the
compiler knows and would emit for free.

### The blocker is `Config` being a RECORD, and the array is why

`TR4WConfig` is a `record`, initialised as a typed constant. That is not a style
choice; the reason is recorded in the agent memory for this project:

> `CFGCA` holds the ADDRESS of each setting's storage, and `CheckCommand` writes
> through it. `@Config.Field` works because the offset is known at link time.
> **The address of an object's field does not exist at compile time.**

So the record shape is a CONSEQUENCE of the array. And a record has no published
properties and no RTTI, so it cannot be streamed this way. **The array is
forcing the very shape that blocks the native answer.**

It is also already against this repository's standing rule -- CLAUDE.md prefers a
class to a record and grants exactly one automatic exemption, a layout defined by
something outside this code. `TR4WConfig` is not that.

**Retire the array and the record constraint dies with it.** That is the
strongest argument yet for the order of work.

### What RTTI does not give you, honestly

| the registry has | the native answer |
|---|---|
| declared `Min`/`Max` per setting | a property setter, which is ordinary Pascal the compiler checks |
| a declared allow-list | an enum IS the allow-list; where it is not, a setter |
| `ReadOnly` | a property with no `write` clause. The compiler enforces it |
| `Broadcast`, `HasSideEffects`, `OnApply` | a real method on the settings object |
| a stable key independent of the identifier | the property path IS the key, so a rename is a file-format change -- the one genuine cost, and it is the same cost every RTTI-persisted app pays |

The old text commands still need a home, and this is the array's one honest
remaining job: `'MY CALL'` has to reach `Settings.Station.MyCall`. That is a
small alias map from command text to property path, driven through
`typinfo.SetPropValue` -- **not** 500 rows carrying a pointer and four tag bytes.

### What this changes about the plan

Nothing about the batches in 2b, and everything about where they land.

1. The ~85 cheap settings still move first, for the same reason.
2. They should land on **published properties of a settings class**, not on
   fields of the `Config` record.
3. `Config` becomes a class when the last `@Config.Field` row leaves `CFGCA`.
4. The registry stays as the façade over whatever has NOT moved, and shrinks to
   nothing rather than being deleted.

**This is a proposal awaiting NY4I's ruling**, and it is the third open item
below. Nothing in stages A or B depends on it.

## 2b. How big the hop-removal actually is

Measured 2026-09-10: every textual reference under `tr4w/src` to the 270 globals
still on a bare `crAddress`, folded for case, 446 files scanned.

| | |
|---|---|
| total references | **4,663** |
| upper bound, because | it counts the declaration and the `CFGCA` row itself |

**The distribution is the useful part, because it says how to batch this:**

| references to that global | settings |
|---|---:|
| 1 to 5 | **85** |
| 6 to 20 | 117 |
| 21 to 60 | 56 |
| over 60 | 12 |

**Eighty-five settings are nearly free.** Five references or fewer means the
global is read where it is set and almost nowhere else, so moving it is a local
change a test can cover. That is a third of the remaining work available in
small, low-risk batches.

The twelve at the other end are the identity fields, and they are expensive for
an obvious reason:

| setting | global | references | units |
|---|---|---:|---:|
| `MY CALL` | `MyCall` | 169 | 32 |
| `MY COUNTRY` | `MyCountry` | 146 | 15 |
| `MY STATE` / `MY QTH` | `MyState` | 146 | 24 |
| `RADIO ONE`/`TWO NAME` | `RadioN.RadioName` | 112 | 15 |
| `CODE SPEED` | `CodeSpeed` | 109 | 17 |
| `MY GRID` | `MyGrid` | 104 | 16 |

**`MY STATE` and `MY QTH` are one variable under two names**, the same shape as
the `ORION PORT` alias just retired -- and this one is already known to be
harder, because QTH is a contest-dependent catch-all rather than a town.
**`CODE SPEED` is not a setting at all** in the sense the others are: it is live
shared state that every keyer mutates during a contest, so it must not be
repointed into a config object without a decision about that.

---

## 2c. The spelling tables

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

## 2e. What the remaining rows ARE -- and why "400 to go" was the wrong number

> **Two corrections: it counts ROWS only (see 2g), and its "279 bridges"
> framing is WRONG (see 2j). Those rows are not bridges to dismantle one at
> a time; they are the READER for two legacy file formats, and they retire
> together.**

Measured 2026-09-10, after seven settings had migrated, by classifying every
row that still applies rather than counting them.

| what the row is | rows | references behind it |
|---|---:|---:|
| already adapted by the settings registry | 113 | |
| belongs to a STRUCTURED STORE (radio, keyer, rotator, UDP, cluster) | 95 | |
| already a `Config` record field | 71 | |
| reached through a spelling table or an array index | 42 | |
| a bare global, over 60 references | 12 | 1,612 |
| a bare global, 21 to 60 references | 20 | 568 |
| a bare global, 6 to 20 references | 37 | 418 |
| a bare global, 1 to 5 references | 10 | 35 |

**279 OF THE 400 ROWS ALREADY HAVE A MODERN OWNER.** The registry, a structured
store, or the `Config` record holds the value; the row is a BRIDGE to
`CheckCommand`, not the storage.

That is a different project from the one section 2b described. Migrating 400
settings and repointing 4,663 references is not the work. **Removing the bridge
is**, and for 279 rows it touches no reader at all.

### What still needs the bridge, for a row that already has an owner

Three things, and they are the same three the model already answers by name:

1. **the one-time import** of a legacy value;
2. **multi-op peer sync**, which arrives as command TEXT;
3. **the contest `.cfg`**, a live input format that is not going away.

`uSettingsModel` handles 1 and 2 today, by deriving the command name from the
property path. Point 3 is the one that keeps a text-to-value path alive
permanently, and it is much smaller than CFGCA: the commands a contest `.cfg`
actually sets, not all 400.

### So the order of work changes

1. **Retire the rows whose owner is a structured store**, once peer sync and
   the `.cfg` reach that store directly. 95 rows, no reader touched.
2. **Retire the registry-adapted rows** the same way. 113 rows.
3. **Move the 71 `Config` fields** onto the settings object, which is a rename
   at each reader rather than a migration.
4. **The 79 bare globals are the real remainder**, and the 12 with over 60
   references each -- `MyCall` at 169 across 32 units -- are each a project.
5. **The 42 spelling-table rows** go with the tables, and
   `Lint-SpellingTables` is what holds them still meanwhile.

### The trivial tier is already gone

At five references or fewer, with no second writer, no registry adapter and
excluding families a structured store owns, the candidate list is **four rows**
-- and two of those are LPT ports, which keep their enum by decision. Everything
left costs either a string-model edit (a fixed `AnsiChar` array becoming a
`string`) or a decision about which of two owners wins.

---

## 2f. ~~What has to survive: 37 commands, not 400~~

> **WRONG TWICE OVER -- see 2g and 2i. The 37 counts rows only, and
> NOTHING has to survive permanently: the contest `.cfg` is an IMPORT
> format, not a file TR4W reads at every start.**

The contest `.cfg` is the one text-to-value path that does NOT go away with the
ini. CLAUDE.md is explicit that it is exempt and heading for SQLite, not JSON.
So "how big is the parser we can never delete" is the number that decides what
CFGCA reduces to, and it had never been measured.

**Measured 2026-09-10 across the 85 shipped contest files in `target/`:
37 distinct CFGCA commands.**

Nearly all of them are identity and category, not behaviour:

| what | commands | reach |
|---|---:|---|
| the Cabrillo `CATEGORY-*` fields | 6 | 82 of 85 files |
| `CONTEST` and `MY CALL` | 2 | every file |
| the other `MY ...` identity rows | 9 | 1 to 29 files each |
| contest behaviour -- exchanges, multipliers, QSO points | ~20 | mostly 1 file each |

**So the permanent parser is 37 rows wide.** Everything else CFGCA carries is
there for a file format that is being retired, or for a value some other store
already owns.

### And the message memories are NOT CFGCA rows

62 lines in those files name something the array does not know, and the two
groups are worth telling apart:

- **`CQ CW MEMORY F3`, `EX CW MEMORY F4 CAPTION` and friends.** The function-key
  and CQ/QSL message memories, which CLAUDE.md already records as living in the
  contest `.cfg` deliberately. They reach the program by a different route and
  are not part of this at all.
- **`COLUMN WIDTH CALLSIGN`, `COLUMN WIDTH DATE` and four more**, in up to 17
  files each. These ARE settings and they are not CFGCA commands under those
  names -- worth finding out what reads them before the `.cfg` parser is
  rewritten, because a contest file is setting something and this document
  cannot say what.

### What this means for the end state

`CFGCA` does not shrink to nothing. It shrinks to a **contest-file parser** of
about 37 entries, and everything else -- the ini vocabulary, the 243 keys in the
JSON `commands` section, the spelling tables that serve only them -- goes.

That is a far smaller and more defensible artifact than the 508-row table, and
it is one whose remaining job is honest: reading a file format contests ship.

---

## 2g. CORRECTION: CheckCommand has THREE families, and a row census sees one

**Written 2026-09-11, correcting sections 2e and 2f, which were written the day
before and counted only ROWS.**

Chasing the one thing 2f could not account for -- `COLUMN WIDTH CALLSIGN`,
appearing in up to 17 contest files and matching no row -- turned up a whole
mechanism the census was blind to. `CheckCommand` dispatches three ways:

| family | how a command is recognised | commands |
|---|---|---:|
| `CFGCA` rows | an exact match against 508 declared rows | 508 |
| `<element> WINDOW COLOR` / `BACKGROUND` | a scan of `TWindows[].mweName`, 50 elements | **100** |
| `COLUMN WIDTH <token>` | a scan of `ColumnCanonicalName[]`, 27 columns | **27** |

**So the command surface is 635, not 508**, and 127 of those commands are
GENERATED from a table of window elements and a table of log columns rather
than declared. A census that greps for `crCommand:` cannot see any of them.

### Why this matters more than the arithmetic

**They would SURVIVE deleting the array**, because they are not in it. Anyone
who retires the last row and expects `CheckCommand` to go with it will find two
hand-written arms still sitting there, still needed.

And 2f's "37 commands have to survive" is **wrong as stated**: the shipped
contest files use `COLUMN WIDTH` on **73 lines**, so the permanent contest-file
parser is those 37 rows PLUS the column-width arm. No shipped contest file sets
a window colour, but an operator's own file may.

### The one good thing about them

**Both arms are already GENERATED from a table rather than typed out**, which is
the shape section 2d argues everything should end up in. Adding a main-window
element gives you its two colour commands for free; adding a log column gives
you its width command. Neither can drift from the enum the way a spelling table
can, because neither is a second list.

So they are not the problem CFGCA is. They are two small parsers over data the
program already owns, and the honest end state keeps them.

---

## 2h. ~~The 100-command window arm is a bridge too~~ -- IT IS THE IMPORTER

> **CORRECTED 2026-09-11 by NY4I: *"The colors are already written to the
> json file through the registry. So they are migrated the same way you are
> doing with the rest of the registry."* He is right, the machinery is
> already there, and this section had framed it as a decision he needed to
> make. See the correction at the end.**

Found 2026-09-11 while looking for more rows of the kind section 2g describes.

`<element> WINDOW COLOR` and `<element> WINDOW BACKGROUND` write
`TWindows[e].mweColor` and `.mweBackG`. **So does the store**, through
`ApplyElementColors`, from an `elementColors` section, and Preferences edits
that section and calls the same applier.

### The ordering, which is the interesting part

| | `uProgramMain` |
|---|---|
| the contest `.cfg` is read | line 1585 |
| the store applies element colours | line 1654, via `ApplyActiveProfileToConfigAtStartup` |

**The store applies SECOND**, so a colour set in a config file is already
overridden for any element the store has an entry for. The arm therefore
"works" only for elements the store happens not to know about -- a legacy path
that half-functions, which is worse for an operator than one that plainly does
not.

### Why it is NOT retired here

Removing it removes the ability to set a window colour from a config file, and
that is a capability decision rather than a cleanup. **NY4I's call.** Three
things worth knowing before making it:

1. **No shipped contest file uses it.** Measured across all 85: zero `WINDOW`
   lines. Only an operator's own `.cfg` or ini could.
2. **It is 100 commands** -- 50 elements times two -- which is the largest
   single block left outside the row table.
3. **It is GENERATED, not typed**, so unlike a spelling table it cannot drift
   from the element list. If it stays, it costs nothing to maintain.

### CORRECTION: there is no decision to make, and the conversion is built

`ApplyElementColors` calls **`SeedElementColorsFromGlobals`** first, and that
routine copies every element's colour out of `TWindows[]` and into the store --
**once**, guarded on `aStore.ColorCount > 0`.

So the real order is:

1. the ini or `.cfg` is read, and the `WINDOW COLOR` arm writes `TWindows[]`;
2. `SeedElementColorsFromGlobals` copies that into the store, once;
3. from then on the store is the owner and applies at every start.

**THE ARM IS THE ONE-TIME IMPORTER.** It is not a bridge competing with the
store; it is the step that gets a legacy file's colours INTO the store. It
retires when the legacy files do, along with every other importer -- exactly
the rule in 2i, and no capability is lost because the value has already been
converted.

**And it seeds from the GLOBALS rather than re-parsing the file**, which the
routine's own comment explains: the config loader is section-blind, so by the
time it runs whatever the file said is already in `TWindows` -- *"no second
parser, and no chance of the two disagreeing"*. That is the same reasoning that
makes a derived command name better than a declared one.

**What this section got wrong** is worth keeping: it found a real shape (a
generated arm writing state a store also owns), drew the right ordering, and
then reached for the wrong conclusion -- that an operator capability was at
stake and NY4I had to rule on it. Nothing was at stake. Reading one function
further up the call chain would have shown that.

### The band plan is the same question

`ApplyBandPlan` reads a `bandPlan` section, and `SeedElementColorsFromGlobals`'s
own comment says seeding from the globals *"was not an option for the band
plan"* -- so that one is NOT the same shape and is worth its own look.

---

## 2i. CORRECTION: the contest `.cfg` is an IMPORT, so NOTHING has to survive

**NY4I, 2026-09-11:** *"the CFG file is read input only simply to convert to the
json configuration. Once read, the CFG is never used again."* And, clarifying
where it lands: *"The same applies for the ini file. For a contest CFG file,
that data is stored in the contest SQLite database."*

Section 2f concluded that a 37-command parser has to live forever because the
contest `.cfg` is a permanent input. **That is wrong**, and the machinery that
makes it wrong is already in the tree.

### TWO import formats, TWO destinations, ONE rule

| read once from | into | already built? |
|---|---|---|
| `settings/tr4w.ini` | `settings/tr4w.json` | yes -- `uLegacyIniPrompt`, and `uSettingsModel` for what has migrated |
| a contest `.cfg` | **the contest SQLite database** | yes -- phase E2, `LogStoreApplyContestConfig` in `uLogStore` |

**The contest half does NOT go to JSON**, and getting that wrong would send
whoever writes the importer to the wrong store. It agrees with CLAUDE.md, which
has said since 2026-08-21 that the contest `.cfg` is *"going to an SQLite3
contest file, not to JSON"*. `LogStoreApplyContestConfig` lives in `uLogStore`,
which is the SQLite log, so the capture is already landing in the right place.

### It is phase E2, and it is built

`uProgramMain` around line 1588 says it plainly:

> *a contest `.cfg` is read once, when the log is created, and captured into the
> log. From then on the LOG says what the contest is. An operator who deletes
> the `.cfg`, or opens the log on another machine, gets the same contest.*

`LogStoreApplyContestConfig` applies the log's own captured settings AFTER every
config file, so the log already has the last word. NY4I's note on that code is
the same sentence he repeated today: *"when done, the .cfg file should not be
necessary."*

### Today versus the destination

| | |
|---|---|
| **today** | `ReadInConfigFile(cfgCFG)` runs at EVERY start, and the log then overrides it |
| **destination** | the `.cfg` is read ONCE, at capture, and never again |

So the 37 commands need an IMPORTER, not a resident parser -- and an importer
does not have to be `CFGCA`, does not have to run at startup, and does not have
to be fast or complete for settings no contest file contains.

### What that changes

**The array can go entirely.** Every earlier section here was working toward
shrinking it to a permanent core; there is no permanent core. What remains at
the end is:

1. a **one-time contest-file importer**, roughly 37 commands wide, living
   wherever the log capture lives rather than in a settings table;
2. the **one-time legacy settings import**, which `uSettingsModel` already does;
3. the two **generated arms** of section 2g -- and 2h shows the window one is a
   bridge with a modern owner as well, so it is a candidate for the same
   treatment rather than a survivor.

**This is the same rule twice.** "Old settings are migrated once and never used
again" and "the CFG is read once and never used again" are one principle, and
neither leaves a parser resident in the program.

---

## 2j. THE ROWS ARE NOT BRIDGES. THEY ARE THE IMPORTER, AND THEY RETIRE TOGETHER

**Written 2026-09-11, and it corrects section 2e, which is the framing the last
several days of work were built on.**

2e said 279 rows "already have a modern owner" and called them bridges to be
dismantled one at a time. Going looking for them found eight, and then seven of
the eight turned out not to be bridges at all.

### What a search for bridges actually returns

A bridge is a row whose global a **store applier** already assigns. Not any
second writer -- `fcontest` sets contest defaults, `cfgdef` the compiled
defaults, `LogCW` the operator's speed mid-contest, and none of those makes a
row redundant. Filtered to the four units that read `settings/tr4w.json` and
put it into force, the answer is **eight rows**. And of those:

| rows | what they really are |
|---:|---|
| 7 | the `WK ...` family -- and `SeedKeyerLibraryFromLegacy` seeds the keyer library FROM `WinKeySettings`, so the row is how a legacy WinKeyer configuration gets INTO the store |
| 1 | `CONNECTION COMMAND`, already recorded in the agent memory as a live two-owners defect, and `crNetwork:1` so a peer can send it |

**So there is essentially nothing to retire one at a time.** The seven are the
same shape as the window colour arm in 2h: the row writes a global, a seeder
copies that global into the store once, and the store owns it thereafter.

### The convergence

Three separate investigations arrived at the same answer this week:

- the window colour arm (2h) -- an importer, seeded by `SeedElementColorsFromGlobals`;
- the `WK` family (here) -- an importer, seeded by `SeedKeyerLibraryFromLegacy`;
- the contest `.cfg` (2i) -- an importer, captured by `LogStoreApplyContestConfig`.

**`CFGCA` is not a settings table with a few stale entries. It is the READER
for two legacy file formats**, and nearly every row in it exists to get a value
out of one of those files and into a modern store exactly once.

### Which makes the task ONE change, not four hundred

The rows do not retire individually, because individually each one is still the
only way an unconverted station's value arrives. They retire **together**, the
moment the legacy read stops happening at every start:

```
   today        ReadInConfigFile(cfgINI) and (cfgCFG) run on EVERY start,
                and the stores then override what they set

   destination  both run ONCE, at migration, and never again
```

`uLegacyIniPrompt` already states that rule for the ini -- *"READ ONCE per
installation, to carry an existing configuration into the store, and then never
again"* -- and section 2i shows phase E2 already does it for the contest file.
**The startup read is the one thing still breaking it**, and CLAUDE.md has said
so since before this work began: *"that startup read is the one place still
breaking it."*

So the remaining work is not 400 migrations. It is:

1. make the two legacy reads happen once, guarded by a migration marker;
2. prove every value they carry has a seeder into its store -- colours, keyer,
   radios, UDP, cluster and contest all have one, and what has NOT got one is
   the actual gap list;
3. then delete the array, the ini vocabulary and the spelling tables in one
   change, because nothing is left reading them.

**Step 2 is the real work and it is a SEARCH, not a refactor.** A row with no
seeder is a setting that would be silently lost at the moment the legacy read
stops -- which is the same silent-loss failure this project keeps finding, and
the reason to look for them before flipping the switch rather than after.

---

## 2k. THE GAP LIST: 27 settings stand between here and switching the ini off

**NY4I, 2026-09-11:** *"do not convert if there is already a json file and a
contest .db file of the same contest."*

Section 2j said the remaining work is one switch plus a SEARCH: prove every
value the legacy read carries has a seeder into a modern store. This is that
search, done.

### Every live row, by what carries its value across

| | rows |
|---|---:|
| seeded by `MIGRATED_COMMANDS` | 245 |
| owned by a structured store and its own seeder | 89 |
| read-only, or not an operator setting | 29 |
| contest-scoped -- captured into the log | 2 |
| **NO SEEDER** | **28**, less `DEBUG LOG LEVEL` which `SeedLoggingFromIni` covers = **27** |

### The 27, and they group cleanly

| group | settings |
|---|---|
| band map display | ALL BANDS, ALL MODES, CALL WINDOW ENABLE, DISPLAY CQ, DISPLAY GHZ, DUPE DISPLAY, MULTS ONLY, SO2R DISPLAY |
| `MY ...` identity | CHECK, FD CLASS, FOC NUMBER, GRID, IOTA, ITU ZONE, NAME, PARK, POSTAL CODE, PREC, SECTION |
| WSJT-X | ENABLED, RADIO CONTROL ENABLED, SEND HIGHLIGHTS |
| the rest | BOLD FONT, CONNECTION COMMAND, POLL RADIO ONE, POLL RADIO TWO, SERVER AUTO SYNCHRONIZE LOG ON CONNECT |

**These are what a station upgrading from 4.x would silently lose** the moment
the ini read is skipped. That is the whole reason to have looked before
flipping the switch rather than after.

### Two cautions before anyone bulk-adds them to the seed list

1. **They are `csOwned`, not `csJSON`.** CLAUDE.md records that 63 `csOwned`
   rows are stored in a STRUCTURED section under a DIFFERENT NAME -- a radio's
   port is `radios[].controlPort`, not a `commands` key. Seeding such a row into
   `commands` would create a second copy of a value that already has a home,
   which is the exact defect this whole effort exists to remove. **Each of the
   27 needs its storage name checked, not assumed.**
2. **`CONNECTION COMMAND` is already a known two-owners defect** in the agent
   memory, and `crNetwork:1`. It wants its own decision rather than a line in a
   list.

### A measurement error worth recording

The first run of this search reported **154** rows with no seeder. It was
wrong: the extractor read `MIGRATED_COMMANDS` with a non-greedy regex, and the
array is `array[0..250]` carrying commented-out entries and parenthesised
prose, so the match stopped a third of the way in and under-reported the seed
list by 154 entries.

**An under-reported seed list invents a gap that does not exist**, which is the
opposite of what the search is for -- and 154 is alarming enough to have
changed the plan. It reads line by line now. The lesson is the one this
document keeps relearning: a number produced by a parser needs a second source
before it is believed, and `Lint-SettingsMigration` was sitting there saying
"251 seeded" the whole time.

---

## 2l. THE SETTER IS THE MECHANISM. 113 ROWS GONE, 2026-09-11

**NY4I:** *"a property setter can do the side effect, which is better than a
hook index."* And: *"csOwned, csjson, csnew were all migratory steps. Those
concepts have no meaning any longer. csRem are obsolete that require no
conversion so they can just be deleted."*

Section 2j concluded the rows are the IMPORTER and retire TOGETHER when the
legacy read stops. That is still true of the rows that carry a value nothing
else owns. It was **too strong as a general claim**, and this section is the
correction: a row can leave the moment (a) something else owns its value and
(b) its name still resolves. The second condition is what was missing.

### What was actually blocking a deletion, and it was not the value

`LogCfg.pas:1262` shows a **modal** *"invalid statement in config file"* when
`CheckCommand` refuses a line. So deleting a row did not merely lose a
setting -- it told an operator their working configuration was invalid, once
per stale line. **That, and only that, is why 98 hollow `csRem` rows existed.**

Two mechanisms remove it:

| | |
|---|---|
| the setting MOVED | `CheckCommand` asks the settings object, which resolves the name and applies the value for real |
| the feature WENT | the name is in `uCFG.RETIRED_COMMANDS` -- accepted, logged once, ignored |

**Neither is a fallback.** A migrated name, a retired name and a live row are
three disjoint sets; each resolves in exactly one place. Framing the first as
a fallback -- which the first draft did -- makes `CFGCA` the authority and the
settings object the safety net, which is backwards for an array being deleted.

### The count

| | rows |
|---|---:|
| start of the session | 508 |
| band map filters + HF/VHF/WARC, to `uSettingsModel` | -11 |
| every `csRem` row | -98 |
| band map display limit and item geometry | -4 |
| **now** | **395** |

### Where each of the row's twenty fields went

Not "replaced" -- most of them were restating something the compiler already
knew, which is the whole thesis of `uSettingsModel`:

| field | destination |
|---|---|
| `crCommand` | derived from the property path; `BandMap.AllBands` gives `BAND MAP ALL BANDS` |
| `crAddress`, `crType` | the property |
| `crMin`/`crMax` | **a subrange type**, read back from RTTI |
| `crP` | **the setter**, plus one subscriber in `uSettingsEffects` |
| `crJ` | a parameter on `RegisterModelSetting` |
| `crNetwork` | a parameter on `RegisterModelSetting` |
| `crS` | nothing |

### Three things measured on the way that were not obvious

1. **`WARC BAND ENABLE` is not a band map setting, and `crP` cannot tell you
   that.** It carries `crP: 1` -- the band map redraw -- so by hook index it
   looks like one. It also refuses a band change at four sites in `logstuff`,
   and five contests in `fcontest` assign it as a rule of the contest. An
   index says *redraw the band map* and nothing more, so it actively invites
   that mis-grouping. This is the clearest argument for the setter, stated
   against a real row.

2. **A commented-out row is not a `csRem` row.** `K1EA NETWORK ENABLE` is
   commented out, so `CheckCommand` has never accepted it -- an old config
   naming it already got the dialog. Adding the commented-out names to the
   retired list would be a behaviour change, not a tidy-up. A test pins it in
   both directions.

3. **A subrange type bounds the STORAGE as well as the value.** FPC gives
   `TBandMapItemWidth = 100..200` a single byte, so a stored `9999` has
   already wrapped to `15` before anything can clamp it down, and then clamps
   *up*. The invariant worth asserting is "ends up inside its range", not the
   direction of the correction.

### What the compiler did for free

`LayOutGrid` floored item height at 8 and item width at 40 -- both *below* the
config minimums of 12 and 100 -- commented *"operator settings, so they are
floored rather than trusted"*. Against subrange properties FPC reports the
comparison as **always false** and the build fails on it. The guard was dead,
and the hazard it was written for now lives at the boundary where untrusted
values actually arrive: `FromJSON` clamps every bounded property in one RTTI
walk, because the streamer is the only path that bypasses `TrySetByCommand`.

### Where the count stands

| | rows |
|---|---:|
| start of the session | 508 |
| band map filters + HF/VHF/WARC | -11 |
| every `csRem` row | -98 |
| band map display limit and item geometry | -4 |
| push to talk, off the `Config` record | -5 |
| the paddle, off the `Config` record | -4 |
| **now** | **386** |

`Config` itself is **71 rows -> 62**.

### Still open, and three of these are QUESTIONS rather than tasks

**Tasks -- known how, just not done:**

* `DVK ENABLE` and `DVK LOCALIZED MESSAGES ENABLE` are two plain booleans with
  about thirty-five call sites. Mechanical.
* `BAND MAP DECAY TIME` (`crA: 5`) and `BAND MAP CUTOFF FREQUENCY` (`crA: 17`,
  `ctFreqList`) carry an additional-proc hook that has to be reproduced first.
* `BAND MAP SPLIT MODE` is a `ckList` reached through a second array -- an
  enum property, not an integer.

**Questions for NY4I:**

* **`BAND MAP GUARD BAND`'s default contradicts its minimum.** The global is
  declared `: integer; // = 200;` with no initialiser, so the runtime default
  is **0**, while `crMin` is **100** -- so a config file cannot set what the
  program starts with. A subrange type cannot express both, which is what
  surfaced it. Which is right?

* **`PADDLE MONITOR TONE` has no live reader.** Searching for the SETTING
  rather than the field found a config row, a commented-out default in
  `cfgdef`, and three translated captions -- and no code that reads it. It is
  stored, editable and broadcast to peers, and used by nothing. Did the paddle
  sidetone move somewhere else, or did the feature go? It was left exactly as
  it was: deleting a setting an operator may have set is not a cleanup.

* **The DVK paths are blocked on a `PChar` conversion, not on the settings
  work.** `Config.DVKPath` and `Config.DVKRecorder` are `FileNameType` --
  fixed `AnsiChar` arrays -- and their readers use
  `GetRealPath(Path, FileName, AddFolder: PAnsiChar): PAnsiChar`, plus
  `Config.DVKRecorder[0] = #0` and `pPos('\\', Config.DVKPath)`.

  Making them `string` properties (which is the right shape, and the move that
  took two `PChar`s out of the tree when `MMTTY ENGINE` went) means converting
  `GetRealPath` and its seven callers. That is squarely the `PChar` audit
  CLAUDE.md already owes, and doing it as a side effect of a settings batch
  would hide it inside an unrelated commit. **Adding casts at the call sites
  instead would ADD `PChar`s, which is the wrong direction entirely.**

### ~~Not a blocker, but decide before the end: passwords~~ -- CLOSED 2026-09-13

**Every password TR4W stores is in the operating system's vault, and no file
holds one.** `uKeychain` is the platform-neutral front; `uKeychainWindows`
binds Credential Manager. A settings file carries a REFERENCE, named by
appending `Ref` to the member it replaces, and nothing else.

| what | where the reference is written |
|---|---|
| `HAMSCORE PASSWORD`, `SERVER PASSWORD` | `TR4WSettings.ProtectSecretsInDocument`, an RTTI post-pass over the streamed document |
| a radio's `NetworkPassword` | `uRadioConfigStore.AddProtectedPassword` |
| a cluster's `Password` | the same |

**The rule that does the work is what happens on REFUSAL.** If the vault will
not take it -- a locked keyring, a platform with no backend yet -- the
password is written NOWHERE. It is kept for the session and asked for again,
and the store says why. Falling back to the file in the clear is the failure
this exists to prevent, and `Test_NoVaultMeansNoPasswordAnywhere` pins it.

**And there is no flag day.** A plaintext member in an existing file is read
as-is; the next save moves it to the vault and stops writing it. Nothing has
to be migrated by hand, and an operator who never saves keeps working.

Two things worth knowing before touching this:

* **A radio's secret is keyed by its `Id`, a cluster's by its NAME.** A
  cluster has no id and its name is already its identity -- the active
  cluster is remembered by name -- so renaming one loses its password, the
  same way it loses every other reference to it.

* **`settings\tr4wradios.ini` still reads a plaintext password on purpose.**
  It is a read-once import format; `LoadFrom` is called once by Preferences
  and `SaveTo` has no production caller at all. Reading what an older TR4W
  wrote is the whole job there.

---

## 2m. THE SOURCE DECIDES, NOT THE ROW -- and `csJSON` goes at import

**NY4I, 2026-09-11:** *"I submit that the entire concept of
`(CFGCA[i].crS = csJSON)` should go away on import since everything
non-contest related is in json."* And: *"plus CFGCA will be removed too."*

A code review reached the same conclusion from the other direction the same
day (Codex): *"give config ingestion an explicit source/phase policy... Do not
let the generic command reader decide this implicitly."*

They are the same point and it is the right one.

### What `aApplyJSONOwned` actually is

It is a boolean parameter on `CheckCommand` that means **"trust me"**. The ini
loader passes the default `False` and a csJSON row refuses to apply; the
Preferences form, a multi-op peer and the contest `.cfg` pass `True` and it
applies.

So a PER-ROW flag (`crS`) plus a PER-CALL flag (`aApplyJSONOwned`) are together
encoding one question that belongs to neither: **which FILE is being read, and
what is that file allowed to do?**

### Why that shape produced a real defect

Restoring the guard for migrated settings (see the commit of 2026-09-11) took
TWO changes, in two units, because the question is spread out:

* `CheckCommand` had to learn that a migrated setting is as protected as the
  csJSON row it came from;
* `CommandIsJSONOwned` had to learn that a migrated setting is still
  JSON-owned, or the same guard would have muted the CONTEST file -- the one
  source that is supposed to win.

Miss either half and the bug is silent. That is the cost of an implicit
policy: the rule is not in one place, so it cannot be read, and it cannot be
tested as a rule.

### The destination

**Each SOURCE gets a stated policy, and the reader applies it.**

| source | what it may do |
|---|---|
| `settings\tr4w.json` | the station's settings. Read at startup, written by Preferences. **The source of record.** |
| `settings\tr4w.ini` | **import only, and only when there is no store.** It holds nothing on a converted station -- NY4I's own file is 67 bytes of sentinel text |
| the contest `.cfg` | **contest-scoped**, and wins while that contest is loaded. Captured into the contest database when the log is created |
| Preferences, a multi-op peer | apply and persist |

Nothing in that table needs `crS`, and nothing needs a per-row status at all.
`csOld`, `csNew`, `csOwned` and `csJSON` were all migratory markers; `csRem`
is already deleted (§2l). The remaining three go with the array.

### Why this is not done yet

The array is still 369 rows, and until a setting has actually moved, `crS` is
the only thing standing between a stale ini and the JSON store for it. The
guard restored on 2026-09-11 is a **stop-gap that buys parity**, not the
design -- it makes a migrated setting behave exactly like the csJSON row it
came from, so nothing regresses while the rest of the migration happens.

**The order is: migrate the rows, then delete the statuses, then delete the
array.** Deleting the statuses first would remove the only protection the
unmigrated rows have.

### The test that was missing, and the one still owed

Two tests now assert `CheckCommand` with `aApplyJSONOwned` both ways, which is
the distinction the model tests could not see -- they call `TrySetByCommand`
directly and never reproduce the startup ORDER.

**Still owed, and the review is right to ask for it:** a startup-configuration
integration fixture using temporary JSON/ini/cfg files that asserts which
value wins, for each source, including the first-run case where there is no
settings section. That is the test that would have caught this without a human
reading the code, and it is the one that will prove the source policy above
when it lands.

---

## 2n. THE ALLOW-LISTS, AND WHAT IS ACTUALLY LEFT -- 2026-09-13

**150 -> 138 rows in one session.** Nine of the twelve were `ckArray` rows,
which is a different mechanism from the `crMin`/`crMax` range everything else
carried, and they are worth reading as a group.

### A ckArray row is an ALLOW-LIST, and most of them are ranges in disguise

`crAddress: pointer(N)` indexes `ArrayRecordArray`, whose entry names a const
array of the values the setting accepts; `CheckCommand` refuses anything not
in it, and `crMin`/`crMax` are advisory there. One was simply wrong -- MULT
REPORT MINIMUM BANDS says `2..5` against an array of `(2, 3, 4)`.

**Seven of the nine lists turned out to be contiguous**, so a subrange says
exactly what the array said and no new mechanism was needed:

| setting | the array | the type |
|---|---|---|
| CW SPEED INCREMENT | (1..10) | `TCwSpeedIncrement` |
| DIT DAH RATIO | (3, 4, 5, 6) | `TCwDitDahRatio` |
| LEADING ZEROS | (0, 1, 2, 3) | `TCwLeadingZeros` |
| AUTO SEND CHARACTER COUNT | (0..6) | `TAutoSendCharacterCount` |
| ROW COUNT | (5..15) | `TLogRowCount` |
| WINDOW SIZE | (1..15) | `TMainWindowSize` |
| AUTO QSL INTERVAL | (0..6) | `TAutoQslInterval` |

**THE FREED SLOTS STAY BEHIND WITH A NIL `arVar`.** `ArrayRecordArray` is
positional, so removing an entry shifts every index above it and silently
repoints other rows at the wrong allow-list -- the same reason
`AdditionalProcsArray` keeps its freed slots.

### The two that are NOT ranges: a setting can be TOLD its vocabulary

SCP MINIMUM LETTERS admits `(0, 3, 4, 5)`; STEREO CONTROL PIN admits `(5, 9)`,
an LPT pin number where 6, 7 and 8 are other signals. A subrange would quietly
widen both.

`RegisterSettingAllowedValues(path, values)` is the answer, and it lives where
MY COUNTRY's validator already lives: **registered, by the unit that owns the
vocabulary.** uCFG renders it from the very const arrays `CheckCommand` matched
against, so the arrays are untouched and there is still one statement of which
values are legal.

**ONE REGISTRATION DOES BOTH JOBS** -- membership is the refusal, and the same
list is what a drop-down offers. That is precisely the complaint against the
`ckArray` row it replaces, where the allow-list and whatever the UI offered
were free to disagree.

**And the hand-wired Preferences path falls through.** SCP MINIMUM LETTERS has
no `RegisterStoredSetting` at all; Preferences fills its combo by command name
through `CFGCommandAllowedValues`, which read the row. With no row it asks the
settings model, which fixes this one and every future one.

### THE DROP-DOWN PROBLEM BIT ONCE ALREADY, AND NOTHING SAW IT

Three Preferences combos -- CW SPEED INCREMENT, DIT DAH RATIO and LEADING ZEROS
-- **came up empty** the moment those settings moved. `TModelSetting` did not
override `AllowedValues`, so it answered nil, which means *no fixed list* -- the
right answer for a text box and the wrong one for a combo.

The build was clean, 35 lints passed, the corpus was green. **A combo with no
items is invisible to every oracle this tree has**, and it stayed that way for
two commits.

It is fixed at the mechanism: `AllowedValuesForCommand` reads `MinValue` and
`MaxValue` off the property's subrange, so nothing has to be written down, and
it refuses to build a list longer than 64 -- a 0..65535 subrange is a text box,
not a drop-down. `Test_ABoundedSettingOffersItsValues` pins it.

**AND BOTH FILL PATHS NOW REPORT AN EMPTY LIST.** A text box bound to a setting
with no fixed list is correct and says nothing; a COMBO bound to one is a
control the operator cannot use, so it writes an error naming the setting. It
is silent in normal operation -- there are three combo bindings in Preferences
and all three offer values -- which is the test a diagnostic has to pass.

### What is left, by WHY -- and only two of these are work

**Counted from `uCFG.pas`, and they sum to the row count** -- 123 live rows by
this count, against the lint's 124 (the lint's pattern also matches the
record's own field declaration). **THE ckList ENUM FAMILY IS GONE**: every
row left is in one of the tracks below. Re-measure rather than quoting these:

```bash
grep "^ (crCommand:" tr4w/src/uCFG.pas | sed "s/.*'\([^']*\)'.*/\1/"
```

| rows | what | why it is still a row |
|---:|---|---|
| 56 | `RADIO ONE ...`, `RADIO TWO ...`, POLL RADIO ONE, POLL RADIO TWO | the radio library track owns them |
| 21 | BAND, MODE, CONTEST, CONTEST NAME/TITLE, the six CATEGORY-*, the four multiplier rows, QSL MODE, QSO POINT METHOD, EXCHANGE RECEIVED, SINGLE BAND SCORE, INITIAL EXCHANGE and its cursor position | the contest `.cfg` importer; see 2i |
| 17 | `WK ...` | the keyer library track owns them |

| 9 | LPT1-3 BASE ADDRESS, PADDLE PORT, RELAY CONTROL PORT, STEREO CONTROL PORT, ROTATOR PORT, KEYER RADIO ONE/TWO OUTPUT PORT | stage B, which section 4 says is deliberately not started without review: it touches the profile applier and the radio open path. **LPT1-3 BASE ADDRESS is separable** -- an I/O base address is not a port NAME, so it is not part of the `SERIAL n` question -- but it sits on the parallel-port write path that keys CW, which is not code to move unattended |
| 7 | CODE SPEED, CW ENABLE, CW TONE, FARNSWORTH ENABLE, FARNSWORTH SPEED, WEIGHT, STEREO PIN HIGH | **live session state**, changed by control codes mid-message and by keystrokes -- a streamed property would persist a mid-contest adjustment |
| 6 | DVK PATH, DVK RECORDER, MP3 PATH, MP3 PLAYER, BACKUP LOG FILE NAME, INITIAL EXCHANGE FILENAME | `FileNameType` buffers read through `GetRealPath(PAnsiChar)`; this is the PChar audit, not a settings batch |
| 3 | ADD DOMESTIC COUNTRY, FREQUENCY MEMORY, BAND MAP CUTOFF FREQUENCY | an accumulating LIST -- each config line ADDS, so the row is not a value |
| 4 | CLEAR DUPE SHEET (an ACTION, not a setting), CONNECTION COMMAND (the cluster library owns it), MY CONTINENT (deliberately stays), MULT REPORT MINIMUM BANDS (below) | one reason each |

### THE ENUM ROWS ARE MOSTLY DONE -- NY4I RULED, 2026-09-13

> *"If it is related to settings, regardless of where it is defined today, it
> should now live in uSettings. That goes for VC.pas too."*

**That inverts the dependency and removes the whole difficulty.** The type is
declared in `uSettingsModel`; the TRDOS unit uses `uSettingsModel`, which most
of them already did. Nothing new is dragged into the settings model -- it still
depends on the RTL alone.

**Nine went this way**, each taking its enum type AND its spelling table:

| setting | type was in | now |
|---|---|---|
| RATE DISPLAY | logwind | `MainWindow.RateDisplay` |
| HOUR DISPLAY | logwind | `MainWindow.HourDisplay` |
| USER INFO SHOWN | logwind | `MainWindow.UserInfoShown` |
| BAND MAP SPLIT MODE | logwind | `BandMap.SplitMode` |
| TEN MINUTE RULE | logwind | `Operating.TenMinuteRule` |
| DUPE CHECK SOUND | logstuff | `Operating.DupeCheckSound` |
| DISTANCE MODE | loggrid | `Log.DistanceMode` |
| REMAINING MULT DISPLAY MODE | logdom | `RemainingMults.DisplayMode` |
| DEBUG LOG LEVEL | **VC.pas** | `Log.DebugLevel` |
| POSSIBLE CALL MODE | logscp (a FIELD of the SCP record) | `Scp.PossibleCallMode` |

**THE SPELLING TABLE TRAVELS WITH THE TYPE**, as `string` rather than
`PAnsiChar`, and is registered against the property. The enum arms of
`TrySetByCommand` and `TryGetByCommand` match it BY POSITION before falling
back to `GetEnumValue` -- which is exactly what the `ckList` row did: find the
text in a spelling table, write the table's index. A file says `QSO POINTS`
where the enum member is `Points`, so RTTI alone answers -1 reading it and
writes a word no TR4W has ever accepted back.

**`Lint-SpellingTables` FOLLOWS A TABLE THAT MOVES**, and it had to be taught:
it checks the tables `ListParamArray` points at, so five leaving showed up only
as its FLOOR failing. It now also reads the tables registered by name in
`uSettingsModel`. 39 tables, 685 spellings -- exactly what it checked before.

**`loggrid` NOW EXPORTS NO STATE AT ALL.** Emptying a `type`, `const` or `var`
section is a syntax error reported at the NEXT keyword, which cost three builds.

### DEBUG LOG LEVEL is the one that paid for itself

Its own comment in `uRadioConfigApply` asked for this: *"the ini carries a
SPELLING; tLogLevels is a Pascal enum; somewhere the two must meet, and the
whole point is that it happens exactly once."* **It happened in three places**
-- a hand-written loop in `ApplyLoggingSettings`, another in `uProgramMain`'s
startup parse, and a third walk of the same array to fill the Preferences
combo. All three ask the setting now.

It is also the only row so far to move `CommandsProcArray` -- `crP: 13` went
without an effects arm, because all three sites that assign the level already
call `UpdateDebugLogLevel` themselves. The hook was a fourth caller, not the
only one.

### REMINDER was WITHDRAWN, not migrated -- NY4I, 2026-09-13

There is no variable called Reminder anywhere, nothing reads it, and its row
was `ckNormal` carrying `crAddress: pointer(51)` -- a `ListParamArray` INDEX in
the field that means an address. **It wrote nothing only because `ctOther` has
no arm in the ckNormal dispatch**, which is worth knowing before anyone reads
that row and assumes a bug.

The NAME is in `RETIRED_COMMANDS`, which is what that list is for: a config
file still saying REMINDER loads inert instead of raising a modal *"invalid
statement in config file"* once per stale line.

**The FEATURE behind it is orphaned and that is a separate decision.**
`ProcessReminder` has no caller, `menu_alt_reminder` is declared in VC and
handled nowhere, and logwind's per-minute loop over `Reminders^` cannot fire
because the count is only ever zero. It was never wired up rather than removed.

### A SUBSYSTEM KEEPS ITS TAXONOMY AND THE SETTING HOLDS A TOKEN

**NY4I, 2026-09-13**, on the external logger and the rotator:

> *"Since the external logger and rotator controller are each a subsystem, then
> I would expect it to work now where the main code would either just check
> Settings.ExternalLogger.Enabled true, or it could just call the external
> logger and if the factory is not set, it would simply return. But the
> parameters are then strictly supporting the factory objects (just like the
> radio works)."*

So the enum does NOT move to `uSettingsModel`. The setting is a STRING token,
exactly as a radio definition holds an opaque `RegistryId`:

| setting | holds | the enum stays in |
|---|---|---|
| `ExternalLogger.LoggerType` | 'NONE', 'DXKEEPER', 'ACLOG', 'HRD' | `uExternalLoggerBase` -- it is what `CreateLogger` takes |
| `Rotator.RotatorType` | 'NONE', 'DCU1', 'ORION', 'YAESU', 'ALFA SPID', 'PSTROTATOR' | `rotatorFactory/uRotatorRegistry`, moved there from logwind |

**THE SUBSYSTEM PUBLISHES ITS OWN VOCABULARY** -- each registers its token
table against its setting at initialization, so the settings model never learns
what logger programs or rotators exist, and there is no second list.

**AND THE CALLER STOPS NAMING TYPES.** Startup was
`if elLogType <> lt_NoExternalLogger then TExternalLogger.Create(elLogType)`
and is `StartExternalLoggerFromSettings`. An unknown token answers "none"
rather than raising: a settings file from a later build naming a logger this
one does not have should leave the feature off, not stop the program.

**THE ROTATOR SEED GOT SIMPLER.** It read
`id := string(RotatorTypeSA[ActiveRotatorType])` -- an enum turned back into
the string the registry keys on, because the registry has always keyed on
strings. There is nothing to translate now.

### THREE "BLOCKED" CALLS WERE WRONG, AND THE RULE THAT CAME OUT OF IT

**NY4I, 2026-09-13:** *"when you come to the conclusion that a row is blocked,
you should validate it in a second way to ensure that is the case and it is
really blocked."*

| I wrote | the second check |
|---|---|
| the enum rows are blocked by a CIRCULAR REFERENCE | a cycle needs BOTH units to name each other in their INTERFACE. A probe compile took three minutes and passed |
| ROTATOR TYPE has a SECOND WRITER in `uRotatorOrion` | that line is inside a BLOCK COMMENT describing the retired ORION PORT hook. So are all three "comparisons" in the rotator drivers. The only live reader was the legacy seed |
| POSSIBLE CALL MODE / SCP COUNTRY STRING are fields of the SCP record read by bare name inside its own methods | accurate, and irrelevant: two reads and four reads respectively |

**The second check must use a DIFFERENT method than the first.** A grep for an
identifier, in a tree whose comments quote the code they replaced, answers a
different question than the one being asked.

### The earlier correction, kept because the lesson is the point

### The enum rows: CORRECTED. There is no cycle, and the cost is a dependency

**An earlier version of this section said the batch was blocked by a circular
reference. THAT WAS WRONG, and it was asserted rather than tested.** A Pascal
cycle is illegal only when BOTH units name each other in their INTERFACE
sections. Every one of these types is declared in a unit that names
`uSettingsModel` in its IMPLEMENTATION, or not at all:

| type | declared in | names uSettingsModel |
|---|---|---|
| `RateDisplayType`, `HourDisplayType`, `TenMinuteRuleType`, `UserInfoType`, `BandMapSplitModeType`, `RotatorType` | `trdos/logwind.pas` | implementation only |
| `DistanceDisplayType` | `trdos/loggrid.pas` | implementation only |
| `RemainingMultDisplayModeType` | `trdos/logdom.pas` | not at all |
| `PossibleCallActionType` | `trdos/logscp.pas` | not at all |
| `ParameterOkayModeType` | `trdos/logstuff.pas` | not at all (its two interface mentions are COMMENTS) |

**Measured, not reasoned:** a probe that put `LogWind` in `uSettingsModel`'s
interface uses clause and published a real `RateDisplayType` property compiled
clean, whole program, both ratchets unchanged. The probe was reverted.

So what is left is a COST and a small mechanism, not a blocker.

**THE COST: `uSettingsModel` currently depends on almost nothing** -- Classes,
SysUtils, uJSON, TypInfo, fpjson -- and that is deliberate and load-bearing: it
is what lets the unit-test binary link it without the application. `uses
LogWind` drags in the widget set and most of the program. The alternative is to
move the enum declarations to a leaf unit first, which is a change to the shape
of the TRDOS units. **Which of those two is NY4I's call.**

**THE MECHANISM: the spelling is not the identifier.** `RateDisplayType` is
`(QSOs, Points, BandQSOs)` and the file says `QSO POINTS` for the middle one,
so `GetEnumValue` answers -1 and `GetEnumName` answers `Points`, which no
config file has ever contained. `RegisterSettingAllowedValues` already carries
the right list; what is missing is that `TrySetByCommand`'s `tkEnumeration` arm
should match a registered list BY POSITION before falling back to
`GetEnumValue`, and `TryGetByCommand` should render from it. That is a small,
testable extension to code written this session.

### MULT REPORT MINIMUM BANDS: stored, editable, broadcast, and read by NOTHING

Its allow-list `(2, 3, 4)` is contiguous and it could have gone with the seven.
It did not, for two reasons that are both NY4I's call:

* **It has no live reader anywhere in the tree.** A declaration, a commented-out
  line in `cfgdef`, and the `ArrayRecordArray` entry. That is the same shape as
  PADDLE MONITOR TONE, which was left exactly as it was on the ruling that
  *deleting a setting an operator may have set is not a cleanup*.
* **The group it would join, `Mult`, is contest-scoped**, and its row says
  `cfAll`. `IsContestScoped` is all-or-nothing per group, so filing it there
  would move an operator's value from `tr4w.json` into the contest database.

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

> **The port work is planned in full in
> [`PORT_IDENTITY_PLAN.md`](PORT_IDENTITY_PLAN.md)**, which covers the
> enumerator and the naming as well as these rows. What follows is the CFGCA
> half; read that document for the order of work and how it gets proven.

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
3. **Is the settings REGISTRY the destination, or a settings CLASS with
   published properties?** See 2d: the native FPC answer is proven to work
   in this toolchain, needs no new dependency, and handles the one value
   `CFGCA` structurally cannot. The registry is the right migration device
   either way. **NY4I's call.**
4. **Which stage the 270 bare globals move in, and in what themed batches.** They
   are the bulk of the work and none of it is urgent; the port slice is urgent
   because it blocks a platform.
5. ~~**Whether `GetValueFromArray` and the 40 spelling tables get a guard now.**~~
   **HALF-CLOSED 2026-09-10.** `Lint-SpellingTables` gates the build and fails
   on a duplicate or blank spelling, which is the part that makes an enum value
   unreachable by name. 39 tables, 685 spellings, clean. The 40th,
   `RadioTypeTokensA`, is filled from the enum by the registry and has nothing
   to check -- which is the shape the other 39 should end up as.

   **What the lint CANNOT check, and no lint can:** that each spelling means
   what its ordinal means. That is the second definition problem itself, and the
   only real fix is generating the table from the enum.

   **It does not duplicate `uTestAllSettings`, and the difference matters.**
   That suite round-trips each setting's *current* value, so it catches a
   shadowed spelling only when a station happens to be sitting on the shadowed
   ordinal. The lint is static and exhaustive over every ordinal in every table,
   including the ~490 settings the registry has not adopted yet.

   It surfaced one thing needing a ruling: **`QSOPointMethodArray` spells
   `ONY` at ordinals 29 and 85.** The second is commented
   `OldNewYearQSOPointMethod` and is the one unreachable; the first carries no
   provenance comment at all. Already noted in `TF.pas`, baselined in the lint,
   and deliberately not touched: which ordinal `ONY` selects decides which
   scoring rule a contest runs under, and the golden corpus is blind to scoring.
