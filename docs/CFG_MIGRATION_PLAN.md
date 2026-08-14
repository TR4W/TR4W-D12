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

**One of the thirty has completed the move: `CW SPEED INCREMENT`.** It is `csJSON`, it is gone from
Ctrl-J, Preferences writes it to `settings\tr4w.json`, an existing ini value is carried across once,
and its global is now `Config.CodeSpeedIncrement`. It is the worked example for the other 29 — chosen
because it is the one NY4I saw duplicated between Preferences and Ctrl-J.

The remaining 29 are still `csOld`/`csNew`: they show in Ctrl-J, round-trip through the ini, and
drive a global each.

The reason is that Preferences reaches them through `RegisterLegacySetting`, which the code
accurately describes as *"a CFGCA row wearing the registry's interface"*. An edit goes:

```
Preferences → TLegacySetting.TrySetText → SetCFGCommandValue → WritePrivateProfileStringA → tr4w.ini
```

So the new UI writes the old store. That is a deliberate bridge, not a defect — but it is a bridge
nobody has crossed yet.

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

### What NY4I should check on screen

The build is green, 3978/0, corpus 22/0/4 — but none of that can see a settings screen. Worth
eyeballing once:

* `CW SPEED INCREMENT` is **gone from Ctrl-J**;
* Preferences → CW shows **Speed step: 2** (not 3) on first start after this build, and
  `tr4w.log` carries `[SeedMigratedCommands] CW SPEED INCREMENT = 2 carried over from tr4w.ini`;
* changing it in Preferences and restarting keeps the new value, and `settings\tr4w.json` — not
  `tr4w.ini` — is what changed;
* the speed-up/slow-down keys still step by that amount on air.

## Where each of the 30 stands

`refs` counts live references to the backing global, excluding the dead `JCtrl1`/`JCTRL2` units and
the CFGCA table binding itself.

| key | CFGCA command | row | backing global | refs |
|---|---|---|---|---|
| operating.cw.serial.ditDahRatio | DIT DAH RATIO | csNew | tDitDahRatio | 3 |
| operating.tworadio.altDCQ | ALT-D CQ ENABLE | csOld | AltDCQEnable | 3 |
| scoring.hamscore.contactInfo | HAMSCORE SEND CONTACT INFO | csNew | HamScoreSendContactInfo | 3 |
| scoring.hamscore.username | HAMSCORE USERNAME | csNew | HamScoreUsername | 3 |
| operating.cw.keypadMemories | KEYPAD CW MEMORIES | csOld | KeypadCWMemories | 4 |
| operating.tworadio.blindCQ | ALWAYS CALL BLIND CQ | csOld | AlwaysCallBlindCQ | 4 |
| scoring.board.postingUrl | SCORE POSTING URL | csOld | GetScoresSeverPostingAddress | 4 |
| scoring.board.readingUrl | SCORE READING URL | csNew | GetScoresSeverReadingAddress | 4 |
| scoring.hamscore.enable | HAMSCORE ENABLE | csNew | HamScoreEnable | 4 |
| scoring.hamscore.password | HAMSCORE PASSWORD | csNew | HamScorePassword | 4 |
| cluster.connectAtStartup | CONNECTION AT STARTUP | csNew | tConnectionAtStartup | 5 |
| scoring.hamscore.url | HAMSCORE URL | csNew | HamScoreURL | 5 |
| cluster.connectCommand | CONNECTION COMMAND | csNew | ConnectionCommand | 6 |
| cw.speedFromDatabase | CW SPEED FROM DATABASE | csOld | CWSpeedFromDataBase | 6 |
| operating.cw.leadingZeroChar | LEADING ZERO CHARACTER | csOld | LeadingZeroCharacter | 6 |
| operating.tworadio.altDBuffer | ALT-D BUFFER ENABLE | csOld | AltDBufferEnable | 6 |
| operating.cw.sayHiRateCutoff | SAY HI RATE CUTOFF | csOld | SayHiRateCutOff | 8 |
| operating.cw.serial.farnsworth | FARNSWORTH ENABLE | csOld | FarnsworthEnable | 8 |
| operating.tworadio.skipActiveBand | SKIP ACTIVE BAND | csOld | SkipActiveBand | 8 |
| operating.bands.hf | HF BAND ENABLE | csOld | HFBandEnable | 8 |
| operating.cw.leadingZeros | LEADING ZEROS | csOld | LeadingZeros | 10 |
| **cw.speedIncrement** | **CW SPEED INCREMENT** | **csJSON** | **Config.CodeSpeedIncrement** | **migrated** |
| operating.cw.sayHi | SAY HI ENABLE | csOld | SayHiEnable | 12 |
| operating.bands.warc | WARC BAND ENABLE | csOld | WARCBandsEnabled | 16 |
| operating.cw.serial.farnsworthSpeed | FARNSWORTH SPEED | csOld | FarnsworthSpeed | 24 |
| operating.bands.vhf | VHF BAND ENABLE | csOld | VHFBandsEnabled | 25 |
| operating.cw.serial.weight | WEIGHT | csOld | Weight | 34 |
| cw.enable | CW ENABLE | csOld | CWEnable | 30 |
| operating.tworadio.enable | TWO RADIO MODE | csOld | TwoRadioMode | 34 |
| cw.tone | CW TONE | csOld | CWTone | 93 |

`refs` is a case-**insensitive** count over the compiled tree, `.PAS` and `.pas` alike, excluding the
uncompiled `JCTRL1`/`JCTRL2`. A case-sensitive `--include=*.pas` misses every TRDOS file spelled
`.PAS` and reports a fraction of the truth — it showed `CodeSpeedIncrement` as 5 when it is 14.
`Weight` is a generic word and its 34 will include unrelated identifiers; count it again before
believing it.

## The csOwned batch — 22 settings, already half-migrated

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

## What does not belong in Preferences

Not every CFGCA row is a *setting*. Some are per-contest state, some are commands rather than
configuration. Sorting those is the last step, once the genuine settings have moved and what remains
is visible.
