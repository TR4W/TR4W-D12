# Retiring the ini: moving CFG commands to JSON

**Written 2026-08-14** after auditing the current state. This is the *how*; the per-setting status
table is at the end.

## The rule (NY4I)

When a setting moves from the old world to the new one it must, in one step:

1. be marked **`csJSON`**, so it disappears from Ctrl-J;
2. no longer be **read from or written to `tr4w.ini`**;
3. have every reference to its controlling variable go **through the config object**, so the
   global disappears.

### Two steps the rule implies but does not say, and both are silent when missed

**4. Seed the existing ini value into the store, once.** A `csJSON` row is inert to the ini loader,
so on the first run after the flip nothing applies the value the operator set months ago — it is
still sitting in `tr4w.ini` and the setting reverts to its compiled default. For
`CW SPEED INCREMENT` that is 2 becoming 3. There is no error, no log line, and nothing for the
operator to notice until mid-contest. `SeedMigratedCommandsFromIni` (`uRadioConfigApply`) carries
each migrated command across once, and every flip adds its command to that list in the same commit.

**5. Check `crNetwork`.** A row with `crNetwork: 1` is propagated between multi-op positions, and
the receiving end (`uNet.pas:327`) applied it with a bare `CheckCommand` — which is inert for
`csJSON`. So flipping a network-synced row silently stopped peer propagation for it: the station
that made the change saw it work, the others neither applied it nor said anything. **Seventeen rows
were already in that state before this work started**, the whole UDP broadcast block among them.
Fixed at the layer that owns the question rather than per row: `ApplyPeerCommand` routes on the
row's own state and persists to whichever file is that row's system of record.

## What is actually true today

**Twenty-seven of the thirty have completed the move, and one has been removed rather than
migrated.** They are `csJSON`, gone from Ctrl-J, written by Preferences to
`settings\tr4w.json`, their existing ini values carried across once, and their globals are now
fields of `Config`.

`CW SPEED INCREMENT` went first because it is the one NY4I saw duplicated between Preferences and
Ctrl-J. Then the five HAMSCORE settings, then the thirteen of category A below — the SO2R/two-radio
group, the small CW settings, the scoreboard URLs and the cluster connect-at-startup flag. HAMSCORE went second on purpose: it is the first **string** group, and a `ctString` row
aimed at anything other than a `ShortString` would write 256 bytes into the next field with nothing
to report it — not the compiler, which sees only a pointer, and not a test, because the damage lands
elsewhere. The `Config` fields therefore carry the *exact* old types.

The remaining 3 are still `csOld`/`csNew`: they show in Ctrl-J, round-trip through the ini, and
drive a global each. The bridge they still use is:

```
Preferences -> TLegacySetting.TrySetText -> SetCFGCommandValue -> WritePrivateProfileStringA -> tr4w.ini
```

So the new UI writes the old store. A deliberate bridge, not a defect — but one that has now been
crossed twenty-four times and needs crossing 6 more.

### A password in the ini is not trustworthy as a password

Ctrl-J displays `ctPassword` rows as a fixed `********` mask. `uOption.pas:761` refuses to write that
mask back — but an existing file can already contain it, and **NY4I's does**:

```
HAMSCORE PASSWORD=********
```

Carrying that across would set the password to the literal mask and produce an authentication
failure that reads like a server problem. A masked value is indistinguishable from a real one, so
seeding skips `ctPassword` rows entirely and logs that the operator should type it once in
Preferences. Note what this also says: that ini value is *already* useless to the running program,
so the migration lost nothing that was working.

Passwords in `settings\tr4w.json` are plaintext, exactly as they were in `tr4w.ini`, and that file
already holds cluster and server passwords. Not made worse here — but it is the open decision this
work should not finish without.

## The machinery for crossing it already exists, and it works

This is the important finding: **no new plumbing is needed.** The path is built, wired, and proven
by the radio rows.

| piece | where | what it does |
|---|---|---|
| `ApplyAndStoreCommand` | `uRadioConfigApply` | applies via `CheckCommand(…, True)` **and** records in the store |
| `TRadioConfigStore.Commands` | `uRadioConfigStore` | persists as the `commands` section of `settings\tr4w.json` |
| `ApplyStoredCommands` | `uRadioConfigApply:307` | applies every stored command at startup |
| `ApplyActiveProfileToConfigAtStartup` | called from `tr4w.dpr:971` | **the live startup hook** |
| `crS = csJSON` | `uCFG:1415` | the ini loader skips the row |
| `crS = csJSON` | `uOption:362` | Ctrl-J hides the row |
| `CommandIsJSONOwned` | `uCFG:965` | the ini writer skips the row |

`ApplyStoredCommands` is **generic** — it applies whatever is in the store, not just radio keys —
and `settings\tr4w.json` already carries 52 commands through it. So steps 1 and 2 of the rule are a
two-line change per setting:

* register the setting so its writes go through `ApplyAndStoreCommand` instead of
  `SetCFGCommandValue`;
* flip the CFGCA row to `csJSON`.

Both must land in the **same commit**. A row flipped without the writer moving loses the value on
restart; a writer moved without the flip leaves the ini as a second, stale source.

## Step 3: the config object, and the constraint that shapes it

`uConfigValues.pas` holds `TR4WConfig` — one record variable, `Config`, one field per migrated
setting. `Config.CodeSpeedIncrement` is the first.

**It is a record variable and not a class, and that is forced, not preferred.** `CFGCA` and
`ArrayRecordArray` are *const* arrays holding the **address** of each setting's storage, and
`CheckCommand` writes through that address. A compile-time initialiser can take
`@Config.CodeSpeedIncrement`, whose offset is known at link time; it cannot take the address of a
field of an object that does not exist until run time. The pre-existing `@CD.CountryString` row is
the same construction and has always compiled, which is what established the technique before
anything was moved.

So while `CheckCommand` remains the applier, the storage must be statically addressable. Replacing
`CheckCommand` is the step that finally removes the address-taking — and it cannot happen until the
rows have moved, which is why this order.

**`Config` is itself one global, and that is the point.** The thirty settings are today thirty
unrelated variables scattered across `LOGWIND`, `VC` and the TRDOS core, writable from anywhere,
with nothing marking them as configuration and no way to enumerate them. One named record makes
every call site say `Config.X` out loud and leaves one place to change later.

### Migrating the reads: the parameterless-function swap

Eliminating the global is where the cost is, and it varies by three orders of magnitude:

```
 3 refs  tDitDahRatio, AltDCQEnable, HamScoreSendContactInfo, HamScoreUsername
 …
30 refs  CWEnable
34 refs  TwoRadioMode
93 refs  CWTone
```

Rewriting 93 call sites to `FindSetting('cw.tone')…` would churn the contest engine, turn a memory
read into a registry lookup, and put risk into code that currently works.

**Recommended instead — the parameterless-function swap.** In Pascal, replacing

```pascal
var CWTone: integer;                 // global
```

with

```pascal
function CWTone: integer; inline;    // reads the config object
```

leaves **every read compiling unchanged** — `if CWTone > 0` is still valid syntax — while **every
write becomes a compile error**. That is exactly the property wanted: the reads cost nothing to
migrate, and the compiler hands over the complete list of writers, which are the sites that must go
through a setter. The global is genuinely gone; no call site churns; nothing is missed.

Two things it does not survive, both of which the compiler also catches:

* `@CWTone` — the CFGCA row's `crAddress`. A migrated row is inert, but the table must still
  compile, so the row needs its address changed or the row removed.
* `var`/`out` parameters taking the global.

## Order of work

1. ~~**Foundation** — `RegisterStoredSetting`, routing writes through `ApplyAndStoreCommand`, using
   the *form's* store so Cancel still discards.~~ **Done.** Plus the two things it turned out to
   need: `SeedMigratedCommandsFromIni` and `ApplyPeerCommand`.
2. ~~**The worked example** — `CW SPEED INCREMENT`, all five steps.~~ **Done**, pending NY4I's
   on-screen check.
3. **Per setting, one commit each** — registration swap, row flip, seed-list entry, `crNetwork`
   check, global into `Config`. Verify the key leaves Ctrl-J, stops appearing in `tr4w.ini`, and
   survives a restart via `tr4w.json`.
4. **The `csOwned` batch** — row flip only, in small themed commits.
5. **The expensive globals** (`CWTone` at 93, `Weight` at 34, `TwoRadioMode` at 34) — the function
   swap, once the cheap ones have proved the shape.

### The corpus cannot see a migrated setting

`tr4w.dpr:971` skips `ApplyActiveProfileToConfigAtStartup` under `/EXPORT` — deliberately, so
automated testing never touches the operator's live settings. The consequence for this work:
**headless export runs on compiled defaults, so a migrated setting is invisible to the corpus.**

That is fine for the six migrated so far — none of them changes ADIF or Cabrillo output — but it
means a green corpus is *not* evidence for a setting that affects an exported field. Anything in
that class has to be checked another way, and the check has to be named in the commit rather than
implied by "22 passed".

### What NY4I should check on screen

The build is green, 3978/0, corpus 22/0/4 — but none of that can see a settings screen. Worth
eyeballing once:

* `CW SPEED INCREMENT` is **gone from Ctrl-J**;
* Preferences → CW shows **Speed step: 2** (not 3) on first start after this build, and
  `tr4w.log` carries `[SeedMigratedCommands] CW SPEED INCREMENT = 2 carried over from tr4w.ini`;
* changing it in Preferences and restarting keeps the new value, and `settings\tr4w.json` — not
  `tr4w.ini` — is what changed;
* the speed-up/slow-down keys still step by that amount on air.

## Beyond the original 30 (2026-08-14)

The 30 above are done, **including item 5's "expensive globals"** — `CWTone`, `Weight` and
`TwoRadioMode` all reach `Config` and no standalone declaration survives. What follows is the work
after that list, and the method is the same two tests, applied before any code is touched:

1. **Does a contest `.cfg` claim it?** All 74 `.cfg` files under `target/` are scanned. This is not
   ceremony — it is how `LEADING ZEROS` was caught.
2. **Does anything else write the global?** Live assignments only. Half the apparent writers in
   `CFGDEF.PAS` are commented out and a naive grep reports them as real.

### The parallel-port wiring — station cabling, not radio settings

`RELAY CONTROL PORT`, `RADIO ONE/TWO BAND OUTPUT PORT`, `STEREO CONTROL PORT` → **Preferences >
Hardware**. NY4I placed the two band-output ports there deliberately, against his own "anything
addressing `Radio1`/`Radio2` goes on the radio form" rule, because what they name is which LPT pin
header drives the band decoder for an operating position. That follows the desk, not the radio.

**It was already a defect.** `BandOutputPort` was a field on `TRadioDefinition`, so activating a
radio re-rendered the CFG key and clearing a slot blanked it to `NONE` — any Hardware edit would
have been silently reverted by the next activation. The field is removed, and
`Test_BandOutputPortIsNotRadioScoped` pins both render paths including the empty slot.

**Before putting any setting on a station-level panel, check whether something else RENDERS its CFG
key.** `RenderedKeyNames` in `uRadioConfigLegacyMap` is the list.

### CW keying, paddle and PTT — ten settings, all category A

`ALL CW MESSAGES CHAINABLE`, `TUNE WITH DITS`, `SEND COMPLETE FOUR LETTER CALL`, `PADDLE SPEED`,
`PADDLE MONITOR TONE`, `SWAP PADDLES`, `PADDLE PTT HOLD COUNT`, `PTT ENABLE`, `PTT TURN ON DELAY`,
`NO POLL DURING PTT`. No contest names one; the config table was their only writer.

**Four were typed constants with non-zero values** (`PTTEnable = True`, `PTTTurnOnDelay = 15`,
`PaddleMonitorTone = 700`, `PaddlePTTHoldCount = 13`) and **a record field defaults to zero**. Losing
those means PTT disabled, a 0 Hz sidetone, and PTT dropping between characters — hot switching, on an
amplifier. Neither the compiler nor the corpus can see it (headless export skips the settings apply,
`tr4w.dpr:971`). `test/unit/uTestConfigDefaults.pas` pins every default and was proved to fail.

UI: three checkboxes on **CW Settings**, the other seven on a new **Paddle and PTT** page made a
*child* of it — collapsed by default, so the nav gains no height.

**Open, reported not fixed:** the two consumers of `PTT TURN ON DELAY` disagree about its unit.
`MainUnit.pas:9646` does `Sleep(Config.PTTTurnOnDelay)` — plain milliseconds — while `LOGK1EA` counts
it down in keyer ticks, which the help documents as × 1.7 ms. Both readings are live. Correcting
either changes amplifier sequencing on air, so it needs bench evidence.

**Held back:** `AUTO SEND CHARACTER COUNT` (`ckArray` via `pointer(2)` — a different mechanism).

### `CODE SPEED` does not belong in `Config` at all (NY4I, 2026-08-14)

> *"CodeSpeed is a global for all keyers to access."*

Stopped before the repoint on that instruction, and it is the right call for a reason worth writing
down: **`CodeSpeed` is not a setting that happens to be mutable — it is live shared runtime state.**
Every keyer reads it, the speed keys move it ±6% (`uCWKeyerCAT`), SO2R restores it per radio from
`Radio1/2.SpeedMemory`, and `CW SPEED FROM DATABASE` sets it from the station's last-worked speed.

`Config` holds what the operator configured. Pointing 151 keyer reads at `Config.CodeSpeed` would
work mechanically and would quietly redefine the config record as a place runtime state lives — the
same category error as putting the current frequency there.

**The distinction to keep:** `CODE SPEED` the *stored setting* is the speed a session STARTS at;
`CodeSpeed` the *global* is the speed it is at now. Those are two values, and today one variable does
both jobs. If the setting is wanted in Preferences, it wants its own stored field seeding the global
at startup — not a repoint. Left `csOld` until that is designed.

**Related, pre-existing and unfixed:** `Radio1/2.SpeedMemory` default to `InitialCodeSpeed` (35,
`tree.pas:742`) independently of the configured `CODE SPEED`, so a station configured to 28 WPM jumps
to 35 on its first radio switch. `LOGWIND.PAS:1587` writes the live speed back into the active
radio's memory, so it self-corrects after one manual change. Worth deciding when the setting is.

### Still `csOld`, and mostly not Preferences work

178 rows remain. The bulk are **contest properties** — `QSO POINTS *`, the `* MULTIPLIER` family, the
CQ/S&P/QSL message set, `MULT BY BAND`, `DOMESTIC MULTIPLIER` — and belong with the contest factory,
not in a settings dialog. NY4I said he would identify those. What is left that is genuinely
station-scoped is a short list: the remaining LPT rows (blocked on the LPT decision), `CODE SPEED`,
and a handful of display and keyboard preferences.

## Where each of the 30 stands

`refs` counts live references to the backing global, excluding the dead `JCtrl1`/`JCTRL2` units and
the CFGCA table binding itself.

| key | CFGCA command | row | backing global | refs |
|---|---|---|---|---|
| operating.cw.serial.ditDahRatio | DIT DAH RATIO | **csJSON** | Config.tDitDahRatio | **migrated** |
| operating.tworadio.altDCQ | ALT-D CQ ENABLE | **csJSON** | Config.AltDCQEnable | **migrated** |
| scoring.hamscore.contactInfo | HAMSCORE SEND CONTACT INFO | **csJSON** | Config.HamScoreSendContactInfo | **migrated** |
| scoring.hamscore.username | HAMSCORE USERNAME | **csJSON** | Config.HamScoreUsername | **migrated** |
| operating.cw.keypadMemories | KEYPAD CW MEMORIES | **csJSON** | Config.KeypadCWMemories | **migrated** |
| operating.tworadio.blindCQ | ALWAYS CALL BLIND CQ | **csJSON** | Config.AlwaysCallBlindCQ | **migrated** |
| scoring.board.postingUrl | SCORE POSTING URL | **csJSON** | Config.GetScoresSeverPostingAddress | **migrated** |
| scoring.board.readingUrl | SCORE READING URL | **csJSON** | Config.GetScoresSeverReadingAddress | **migrated** |
| scoring.hamscore.enable | HAMSCORE ENABLE | **csJSON** | Config.HamScoreEnable | **migrated** |
| scoring.hamscore.password | HAMSCORE PASSWORD | **csJSON** | Config.HamScorePassword | **migrated** |
| cluster.connectAtStartup | CONNECTION AT STARTUP | **csJSON** | Config.tConnectionAtStartup | **migrated** |
| scoring.hamscore.url | HAMSCORE URL | **csJSON** | Config.HamScoreURL | **migrated** |
| cluster.connectCommand | CONNECTION COMMAND | csNew | *(cluster definition)* | **removed from the flat registry** |
| cw.speedFromDatabase | CW SPEED FROM DATABASE | **csJSON** | Config.CWSpeedFromDataBase | **migrated** |
| operating.cw.leadingZeroChar | LEADING ZERO CHARACTER | **csJSON** | Config.LeadingZeroCharacter | **migrated** |
| operating.tworadio.altDBuffer | ALT-D BUFFER ENABLE | **csJSON** | Config.AltDBufferEnable | **migrated** |
| operating.cw.sayHiRateCutoff | SAY HI RATE CUTOFF | **csJSON** | Config.SayHiRateCutOff | **migrated** |
| operating.cw.serial.farnsworth | FARNSWORTH ENABLE | **csJSON** | Config.FarnsworthEnable | **migrated** |
| operating.tworadio.skipActiveBand | SKIP ACTIVE BAND | **csJSON** | Config.SkipActiveBand | **migrated** |
| operating.bands.hf | HF BAND ENABLE | csOld | HFBandEnable | 8 |
| operating.cw.leadingZeros | LEADING ZEROS | **csJSON** | Config.LeadingZeros | **migrated** |
| **cw.speedIncrement** | **CW SPEED INCREMENT** | **csJSON** | **Config.CodeSpeedIncrement** | **migrated** |
| operating.cw.sayHi | SAY HI ENABLE | **csJSON** | Config.SayHiEnable | **migrated** |
| operating.bands.warc | WARC BAND ENABLE | csOld | WARCBandsEnabled | 16 |
| operating.cw.serial.farnsworthSpeed | FARNSWORTH SPEED | **csJSON** | Config.FarnsworthSpeed | **migrated** |
| operating.bands.vhf | VHF BAND ENABLE | csOld | VHFBandsEnabled | 25 |
| operating.cw.serial.weight | WEIGHT | **csJSON** | Config.Weight | **migrated** |
| cw.enable | CW ENABLE | **csJSON** | Config.CWEnable | **migrated** |
| operating.tworadio.enable | TWO RADIO MODE | **csJSON** | Config.TwoRadioMode | **migrated** |
| cw.tone | CW TONE | **csJSON** | Config.CWTone | **migrated** |

`refs` is a case-**insensitive** count over the compiled tree, `.PAS` and `.pas` alike, excluding the
uncompiled `JCTRL1`/`JCTRL2`. A case-sensitive `--include=*.pas` misses every TRDOS file spelled
`.PAS` and reports a fraction of the truth — it showed `CodeSpeedIncrement` as 5 when it is 14.
`Weight` is a generic word and its 34 will include unrelated identifiers; count it again before
believing it.

## The csOwned batch — ~~22 settings, already half-migrated~~ **21 DONE, 1 held back**

The **hand-wired** Preferences panels (SCP, network, fonts, backup, band map, WSJT-X, external
logger, MMTTY, …) already call `ApplyAndStoreCommand`, so 22 commands are already written to JSON.
All 22 rows are `csOwned`, which is a real state and not an oversight:

| | hidden from Ctrl-J | applied from the ini | written to the ini |
|---|---|---|---|
| `csOwned` | yes | **yes** | yes |
| `csJSON` | yes | no | no |

So `csOwned` satisfies step 1 but not step 2: the value is in both files and the ini is still a
second, staler source that the loader applies before `ApplyStoredCommands` overrides it. They are a
cheaper batch — the writer has already moved — but **not a blind sweep**: 45 of the 86 `csOwned`
rows are `crNetwork: 1`, so each one has to be checked against the peer path above, and each needs
its seed-list entry. Do them in small themed commits (backup, band map, WSJT-X …), not one change of
22.


**Done 2026-08-14.** Twenty-one flipped to `csJSON`, each added to the ini→store seed list so a
station that has never opened Preferences keeps its values: backup (2), band map (3), external
logger (3), fonts (2), MMTTY, SCP (2), server/network (4), radio TCP port, telnet, WSJT-X (2).

**`MY CONTINENT` was held back**, and not because it is risky to flip. It is the wrong *shape*: it
has 71 references in `LOGSTUFF.PAS` — scoring, multipliers, DX/domestic decisions — and belongs to
the station-vs-contest question above, not to a batch of UI-owned settings. `/EXPORT` also skips the
JSON apply, so a flip could change an exported log for an operator who had overridden it.

## What is left, and where each of it lands

NY4I asked to see "what is left and where it lands in either settings or some other location".
This is that answer for the 24 not yet migrated, decided by **who else writes the variable** —
scanned for live assignments only, because half the apparent writers in `CFGDEF.PAS` are
commented-out lines and a naive grep reports them as real.

### A. Nothing else writes them — migrate as flat settings (13, see A-bis)

The stored value is the only source, so these were pure Preferences settings and the cheapest work.
**All thirteen migrated 2026-08-14** (the fourteenth, `LEADING ZERO CHARACTER`, went with them; only
`LEADING ZEROS` is held back — see A-bis):

`DIT DAH RATIO`, `ALT-D CQ ENABLE`, `KEYPAD CW MEMORIES`, `ALWAYS CALL BLIND CQ`,
`SCORE POSTING URL`, `SCORE READING URL`, `CONNECTION AT STARTUP`, `CW SPEED FROM DATABASE`,
`ALT-D BUFFER ENABLE`, `SAY HI RATE CUTOFF`, `SKIP ACTIVE BAND`, `LEADING ZEROS`,
`LEADING ZERO CHARACTER`, `SAY HI ENABLE`.

(`LEADING ZERO CHARACTER` is assigned in `CFGDEF.PAS:487`, but `SetConfigurationDefaultValues`
runs **once** at startup and **before** the config files — it is an initial default, not a
competing owner. Checked rather than assumed, because a defaults procedure that ran on contest
change would silently reset the setting instead.)

### A-bis. ~~`LEADING ZEROS`~~ **MIGRATED** — a CW setting a contest may override

Measured, not assumed: of the 30, **only `LEADING ZEROS` appears in a contest `.cfg`** — 6 of 137
scanned files, including `CQ-WPX-CW.CFG` and `CQ-WPX-SSB.CFG`, which fits a serial-number contest.
The other 29 appear in none.

So it is *not* category A. No code writes it, but a loaded contest does, and a `.cfg` legitimately
winning while loaded is the agreed semantics rather than a precedence bug. The open question is the
**write path**: editing it in Preferences during WPX must update the station default, not the event
override — or the reverse — and nothing in `CheckCommand` knows layers exist. Settle that before
migrating this one.

### B. The contest owns them, not the operator (3)

`HF BAND ENABLE`, `WARC BAND ENABLE`, `VHF BAND ENABLE` are assigned by `FCONTEST.PAS` when a
contest is selected — `ARRLVHFJUN` sets `HFBandEnable := False` (`FCONTEST.PAS:634`), and there are
fourteen such sites. They are **contest properties wearing a settings costume**. Migrating them as
flat settings would give Preferences an editor for a value the next contest selection silently
overwrites. They belong with the contest definition; the Preferences panel should show them read-only
or not at all. **NY4I's call, and the clearest example of "somewhere else".**

### C. ~~The session mutates them~~ **MIGRATED 2026-08-14** (5)

| setting | live writer | what changes it |
|---|---|---|
| `WEIGHT` | `LOGK1EA.PAS:2120` | CW-buffer control codes, mid-message |
| `FARNSWORTH SPEED` | `LOGK1EA.PAS:2125+` | same |
| `FARNSWORTH ENABLE` | `LOGK1EA.PAS:2124` | same |
| `CW ENABLE` | `MainUnit.pas:2845`, `LogCW.pas:2289` | live keystroke toggle |
| `CW TONE` | `MainUnit.pas:2766`, `uProcessCommand.pas:354` | live keystroke toggle |

These can migrate, but the semantics have to be **stated rather than assumed**: Preferences sets the
value the session *starts* with, and a live change is not written back. Today that is also true and
nobody has said so. `CW TONE` at 93 references is the single most expensive item in the whole
exercise and should go last, with the function swap.

### D. ~~A library already owns it~~ **DONE — duplicate editor removed** (1)

`CONNECTION COMMAND`. `ApplyActiveCluster` assigns `ConnectionCommand` from the active cluster
definition (`uRadioConfigApply.pas:601`), and it runs **after** `ApplyStoredCommands`. So there are
two owners and the cluster wins.

**This is a live defect, not a future one:** editing "Connection command" in Preferences today writes
the ini, and the cluster library overwrites it on the next start. Migrating it to JSON would not fix
that — it would move the losing value to a different file. The fix is to drop `cluster.connectCommand`
from the flat registry and let the cluster editor own it, which is where the operator already expects
to find it.

### E. ~~Two commands feed one variable~~ **DONE — alias withdrawn** (1)

`TWO RADIO MODE` also receives the deprecated `SINGLE RADIO MODE` alias (`uCFG.pas:1359`, inverted).
Migrating one row without the other leaves the alias writing the ini into a variable the JSON store
also claims. Retire the alias in the same commit.

## The `MY *` family is not a station setting (NY4I, 2026-08-14)

There is a **line** between the MY... fields in Station settings and the MY info a
contest uses. Home state Florida, but operating a contest from Georgia: the state
*sent* comes from the contest setup, while the Cabrillo header still carries the
operator's real details. In NAQP people send a short made-up name — `JO` rather
than `Joseph` — purely because it is faster to key.

So three values, not one:

| | value |
|---|---|
| station identity | the operator's own details |
| what the contest sends | set at contest setup; legitimately different |
| the Cabrillo header | the real details again, not the exchange |

The header is already structurally separate: `uCbrSum.pas` marks the address tags
`ctrCFG: False` / `ctrSave: True`, so it keeps its own storage rather than reading
the exchange globals.

**The rule** is *what did the contest setup ask for* — the contest value when the
setup collected one, the station value otherwise, with the station value shown as
**greyed hint text rather than pre-filled**, so blank reads as "use my default"
instead of as an omission. Same idiom the radio editor uses for the CI-V default.

**Deferred to the contest factory**, deliberately. The consequence here and now is
that `MY CONTINENT` was excluded from the `csOwned` batch: 71 references in
`LOGSTUFF.PAS`, and `/EXPORT` skips the JSON apply, so a row flip could silently
change an exported log for anyone who had overridden it.

The read side already exists — a contest `.cfg` naming a migrated command applies
it and wins while that contest is loaded. What is missing is the UI half.

## What does not belong in Preferences

Not every CFGCA row is a *setting*. Some are per-contest state, some are commands rather than
configuration. Sorting those is the last step, once the genuine settings have moved and what remains
is visible.
