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

> **Counts ROWS only. See 2g: `CheckCommand` accepts 127 more commands that
> are not rows at all.**

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

## 2h. The 100-command window arm is a bridge too -- and it already half-loses

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

### The same question applies to the band plan

`ApplyBandPlan` reads a `bandPlan` section from the store and there is a
config-file path beside it. It was not examined; it is the next thing to look
at when this decision is made, because it will have the same shape and should
get the same answer.

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
