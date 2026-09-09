# How TR4QT Handles Program Settings

Reference for the TR4W FreePascal/Lazarus port. Written from the actual TR4QT
source at `~/projects/TR4QT` (v3.51.81), not from memory.

The question this document exists to answer: **TR4W's `CommandsArray`/CFGCA stores
each setting as an untyped `pointer` plus a type tag, and that breaks on 64-bit
Linux/macOS. TR4QT was written from scratch. What did it do instead, and what did
that cost?**

Short version: TR4QT uses **typed getter/setter pairs on a singleton, over a
key/value store**. It has no pointers, no type tags, and no command table. It also
has no change notification, no introspection, and a 3,746-line hand-wired
preferences dialog as a direct consequence. Both halves of that matter.

---

## 1. The storage layer

TR4QT persists settings through **Qt's `QSettings`** — a platform-native key/value
store. On macOS it is a plist, on Windows the registry, on Linux an INI file under
`~/.config`. The Pascal equivalent is a JSON file, which is what TR4W already has.
Nothing in the design depends on which of those it is.

Two facts about the store that turned out to matter:

**The domain is a compile-time constant, not a runtime string.** `Constants.h`
defines `APP_ORG` and `APP_NAME` inside `#ifndef` guards, so the test build can
override them on the compiler command line and write to a completely separate
plist. Production settings are untouchable from a test run. This was not the first
attempt: file permissions and runtime path redirection were both tried and both
failed, because the macOS preferences daemon ignores them. Only the compile-time
domain split worked.

**There is exactly one settings object in the process.** `AppSettings::instance()`
is a singleton holding one `QSettings m_settings` member. Copy and assign are
deleted. Every read and write in the program goes through it. There are 242 call
sites across the codebase.

## 2. The access layer — the part that replaces CFGCA

Every setting is a **hand-written pair of member functions** on `AppSettings`:

```cpp
// AppSettings.h  — declaration
void    setMorseWPM(int wpm);
int     getMorseWPM() const;      // Default: 25 WPM

void    setMyCallsign(const QString& callsign);
QString getMyCallsign() const;
```

```cpp
// AppSettings.cpp — definition
void AppSettings::setMorseWPM(int wpm) {
    m_settings.setValue("Morse/wpm", wpm);
    m_settings.sync();
}

int AppSettings::getMorseWPM() const {
    return m_settings.value("Morse/wpm", 25).toInt();   // default lives here
}

void AppSettings::setMyCallsign(const QString& callsign) {
    m_settings.setValue("Station/callsign", callsign.toUpper());  // normalisation
    m_settings.sync();
}
```

Read that against a CFGCA row and the differences are the whole point:

| CFGCA | TR4QT |
|---|---|
| `crAddress: @MyCall` — untyped pointer | no address is ever taken |
| `crType: ctString` — a tag saying how to dereference | the C++ return type *is* the type; nothing to tag |
| `crKind: ckArray` — "the pointer is secretly an index" | does not exist; indexed settings take an `int` parameter |
| `crMin`/`crMax` re-checked by callers | normalisation and clamping live in the setter, one place |
| `crA` index into `AdditionalProcsArray` | the setter body, or an explicit call after it |

The key string (`"Morse/wpm"`) appears **twice**, once in the getter and once in
the setter. That is the single largest weakness of this design and is discussed in
section 6.

Settings are grouped by a prefix in the key, not by any structure in code:
`Station/`, `Radio/`, `Morse/`, `WSJTX/`, `SCP/`, `Rotator/`, `Amplifier/`, `UDP/`.
The prefix is pure convention, enforced by nothing.

### Naming and grouping in practice

Roughly 200 accessor pairs exist. A representative spread:

- Station identity: `MyCallsign`, `MyGridSquare`, `MyContinent`, `MyCQZone`,
  `MyITUZone`, `MyState`, `MyARRLSection`, `MyCounty`, `MyFirstName`,
  `MyLastName`, `ComputerID`, `LicenseClass`, `CurrentOperator`
- Radio, amplifier, rotator: model id, port, baud, parity, poll interval,
  auto-connect
- CW: WPM, WPM increment, sidetone pitch/volume, WinKeyer weighting/lead-in/tail,
  keyer device type, keying source, DTR/RTS pin
- Messages: F1–F12 per mode, plus Ctrl+F and Alt+F variants
- Cluster, band map, LoTW, SCP, WSJT-X, web server, logging, backups, appearance

### Indexed settings without `ckArray`

TR4W's `ckArray` exists because a pointer had to double as an index. TR4QT needs
no such trick — the index is just a parameter:

```cpp
void    setCQMessage(int fKey, const QString& templateStr);
QString getCQMessage(int fKey) const;
void    setCtrlFMessage(int fKey, bool cqMode, const QString& templateStr);
```

and the implementation composes the key: `QString("Morse/macro%1_label").arg(index)`.

## 3. Structured settings — records, not flat keys

Not every setting is a scalar. Radio configurations, station profiles and CW
output profiles are **records with many fields, stored as arrays of records**.
These use a different API shape: one call saves or loads a whole `QList`.

```cpp
void                 saveRadioProfiles(const QList<RadioProfile>& profiles);
QList<RadioProfile>  loadRadioProfiles() const;
QList<StationProfile> loadStationProfiles() const;
```

The serialisation is a plain field-by-field loop over an indexed array in the
store. Note the two things that go with it:

- **Every field has an explicit default at read time.** `value("baudRate", 38400)`.
  A profile written by an older version that lacked a field still loads.
- **Secrets do not go in the settings file at all.** Passwords are routed to the
  OS credential store (Keychain / Windows Credential Manager) via a separate
  `CredentialStore` singleton, keyed by profile name plus username. The settings
  file holds the username; the credential store holds the password. There is a
  one-time migration that moves any legacy plaintext password out of the settings
  file and verifies the round-trip before deleting it.

If TR4W is putting radio passwords in the JSON file, that is a bug worth fixing
independently of this argument.

## 4. Schema evolution — the migration pattern

This is the part most worth copying, and TR4QT has had to do it four times.

Each migration is a **private method run once from the constructor**, guarded by a
flag in the store so it never runs twice:

```cpp
void migrateLegacyPaths();          // old ~/.tr4qt paths -> platform AppData
void migrateToRadioProfiles();      // single radio config -> "Default" profile
void migrateToStationProfiles();    // radio profiles -> station profiles
void migrateToCWOutputProfiles();   // flat keyer keys -> CW output profile
void migrateCredentialsToSecureStore();  // plaintext passwords -> Keychain
```

Three rules fell out of doing this:

1. **Never rename a key in place.** Add the new key, write a migration that reads
   the old one and writes the new one, then stop reading the old one. The old key
   is left on disk. It costs nothing.
2. **A migration that touches an external system runs late, not in the
   constructor.** The credential migration needs a running event loop, so it is
   called from `startAutoSave()` after the application object exists. A partial
   migration retries on the next launch.
3. **The old reader stays.** TR4W already reached the same conclusion in
   `uSettingsRegistry.pas`: CFGCA remains the reader for old INI files because
   nothing else can do that job. Keep it. The mistake would be keeping it as the
   *applier*.

## 5. Durability

Settings loss is a support nightmare, so this got more attention than it
otherwise deserves:

- **`sync()` after every single write.** Flushes to disk immediately.
- **A 60-second auto-save timer**, started once from `main()`.
- **Timestamped backups** kept in `settings_backups/`, capped at 5, with
  `createBackup()` / `restoreFromBackup()` / `verifySettingsIntegrity()`.
- **RAII guards** around every scoped store operation, so an exception mid-write
  cannot leave the store stuck inside a group:

```cpp
class QSettingsGroupGuard {
public:
    QSettingsGroupGuard(QSettings& s, const QString& g) : m_settings(s) { s.beginGroup(g); }
    ~QSettingsGroupGuard() { m_settings.endGroup(); }   // always runs
};
```

The Pascal equivalent is `try`/`finally`, which is cheaper and clearer.

## 6. What this design costs — read this before copying it

TR4QT's settings layer works, but it is not a model of restraint. Four concrete
problems, all of which a Pascal port would inherit verbatim:

**The class is a god class.** `AppSettings.h` is 713 lines, `AppSettings.cpp` is
2,633. Both are past the project's own 1,500-line hard stop. Two hundred accessor
pairs, each three to five lines, add up to nothing else.

**The key string is duplicated and unchecked.** `"Morse/wpm"` is typed once in the
getter and once in the setter. A typo in one of them compiles cleanly, and the
symptom is a setting that silently reverts on restart. There is no test that
enumerates the keys, because nothing can enumerate them.

**There is no change notification.** `AppSettings` derives from `QObject` and
declares zero signals. Nothing is notified when a setting changes. Every consumer
must be told to re-read by hand, which means the preferences dialog has to know
which subsystems care about which setting. That coupling is exactly what TR4W's
`OnApply` / `OnChanged` closures exist to avoid, and TR4QT does not have it.

**Nothing can be enumerated, so the UI is hand-wired.** `PreferencesDialog.cpp` is
**3,746 lines**. Every widget is created by hand, loaded from a named getter by
hand, and written back through a named setter by hand. There is no way to dump all
settings for a bug report, no way to diff two configurations, no way to generate a
panel from a declaration, and no way to write a test that checks every setting
round-trips. That is the direct, measurable price of having accessors and nothing
else.

**A generic escape hatch exists and undermines the rest.**

```cpp
QString AppSettings::getValue(const QString& key, const QString& defaultValue) const;
```

One untyped, unchecked, string-keyed reader, added because sometimes a caller only
has a key. Every use of it is a hole in the type safety the other 200 methods pay
for.

## 7. What this means for the TR4W port

The pointer problem and the architecture question are **two separate problems**,
and conflating them is how this argument goes wrong.

**The registry is the right design and is not in question.**
`uSettingsRegistry.pas` replaced `crAddress`/`crType`/`crKind` with typed
`of object` getter/setter method pointers. `TBoolGetter = function: boolean of
object`. There is no address to mis-dereference and no tag to check, which is the
same property TR4QT's accessors have. FPC 3.2.2 cannot compile the anonymous-method
form, hence method pointers rather than closures. That call was already made and
is correct. Keep the key, the caption, the range, the allow-list and the apply
hook. They are what CFGCA had that a bare property does not, and they are what
lets a panel be generated and a round-trip test be written. TR4QT has none of
them, and its 3,746-line preferences dialog is what that cost.

**What is in question is the applier, and the applier has not moved.** The
migration is much further along than a first look suggests, but it moved storage
and presentation, not access. Counts from `uCFG.pas` as of this writing:

| Measure | Count |
|---|---|
| `crCommand` rows in CFGCA | 508 |
| Rows marked `csJSON` (JSON is system of record) | 315 |
| Settings declared in the registry | 232 |
| **`csJSON` rows still carrying `crAddress: @Something`** | **270** |
| **`csJSON` rows still carrying `crAddress: pointer(N)`** | **44** |
| `ckArray` rows (all of them `pointer(N)`) | 16 |

Read the fourth and fifth rows carefully. A row that has *fully migrated* to the
JSON store still stores an untyped pointer, still carries a `crType` tag saying
how to dereference it, and is still applied by `CheckCommand` writing through
that pointer. `csJSON` means the row is inert *to the ini loader*. It does not
mean the pointer is gone. Forty-four migrated rows still hold an integer cast to
a pointer, which is the exact construct that produced the `SCP MINIMUM LETTERS`
access violation and the exact construct that does not survive a 64-bit port.
`AdditionalProcsArray: array[1..25] of Pointer` is still live alongside it.

An honest statement of the current state: the JSON file is the system of record,
the registry is the facade, and a 1990s untyped-pointer table is still the
mechanism that puts values into variables. That middle layer is not a stepping
stone toward anything. Nothing above it needs it, and it is the only remaining
source of the class of bug that started this work.

**So the target shape is:** call sites read `Config.SayHiEnable`. `Config` is a
class with real properties. The registry holds a `TSetting` whose getter and
setter *are* those property accessors, keyed for the JSON store and the UI. No
`@` anywhere. `CheckCommand` keeps exactly one job, reading old ini and contest
`.cfg` files, and stops being an applier.

### BLOCKING PREREQUISITES — do not move the applier until these are closed

`CheckCommand` is not only an assignment routine. Each CFGCA row carries five
fields that make it do more, and `TSettingBase` currently reproduces three of
them. The two it does not reproduce are hard blockers. Retiring `CheckCommand` as
the applier before they are closed removes working behaviour with no compiler
error and no test failure, and the symptom appears at a multi-op station during a
contest, which is the worst possible place to find it.

| CFGCA field | What it does | Covered by `TSettingBase`? |
|---|---|---|
| `crMin` / `crMax` | Range check on assignment | Yes, via `TrySetText` |
| `crKind: ckArray` | Discrete allow-list | Yes, via `AllowedValues` |
| `crA` | Index into `AdditionalProcsArray` | Yes, via `OnApply` |
| **`crNetwork`** | **Send the change to networked stations** | **NO** |
| **`crJ`** | **Read-only, or edit-plus-restart-required** | **NO** |

**BLOCKER 1 — `crNetwork` has no equivalent.** `crNetwork: 1` on a row means the
value is propagated to the other stations in a networked multi-op setup when it
changes. The registry has `OnApply` and `OnChanged`, which are local hooks. There
is no concept of a setting that must be transmitted. If `CheckCommand` stops
being the applier while this is missing, networked stations silently stop
receiving setting changes. Nothing reports it. The operators discover it when two
positions disagree about a setting mid-contest.

*Close it by:* adding a `Networked: boolean` property to `TSettingBase`, carrying
it through `RegisterStoredSetting` from the row's existing `crNetwork` value, and
having whatever replaces `CheckCommand` fire the network send for any setting
where it is true. Write the test before the change: set a networked setting on
one station, assert the other received it.

**BLOCKER 2 — `crJ` has no equivalent.** `crJ` encodes four editability states:
`0` editable, `1` editable but requires a restart, `2` read-only, `3` a read-only
message. `TSettingBase` has an `FNeedsRestart` field, but no read-only state and
nothing that carries `crJ` in from the row. A read-only setting reached through a
property setter is writable by definition. Two failures follow. A settings screen
built on the registry will offer an editable control for a value the program will
not honour. And a `crJ: 1` setting changed at runtime will appear to take effect
when it will not until restart, with no notice to the operator.

*Close it by:* promoting `crJ` to an enumerated `Editability` property on
`TSettingBase`, populating it in `RegisterStoredSetting`, having `TrySetText`
refuse a write to a read-only setting with a real error, and having the UI read
the property rather than assuming every setting is editable.

**Neither blocker can be deferred to a cleanup pass.** Both are silent failures.
Both affect settings that are already marked `csJSON` and therefore already
consider themselves migrated. Close them while `CheckCommand` is still the
applier, so the old path and the new path can be compared on the same setting.

### Concrete recommendations, in order

1. **Close the two blocking prerequisites above.** `crNetwork` first, because it
   is the one that fails silently at a multi-op station.
2. **Decide where contest `.cfg` precedence lives.** `NoteCommandFromContestCFG`
   keys the station-defaults-versus-contest-overrides rule on the legacy command
   name. That precedence has to move onto the setting key, or a contest file
   stops being able to override a station preference.
3. **Resolve the `ActiveStoreProvider` gate.** `TStoredSetting` refuses a write
   when no store is open, so writes work only while Preferences is up. A plain
   property setter callable from anywhere has no such gate. Decide deliberately
   whether program-initiated writes persist, rather than discovering it.
4. **Make `Config` a class with properties, not a record**, in the same commit
   that CFGCA stops being the applier. `uConfigValues.pas` documents why it is a
   record: CFGCA const arrays take `@Config.Field` at compile time, which needs
   statically addressable storage. A class breaks that deliberately. Those two
   changes are one change and cannot be sequenced apart.
5. **Register each property as a `TSetting` whose getter/setter are the
   property's accessors.** Call sites use the property. The UI and the JSON store
   use the key. Neither knows about the other.
6. **Retire `pointer(N)` and `ckArray` first, not last.** They are 16 rows, they
   are the actual 64-bit hazard, and 44 of them sit in rows already marked
   migrated. Convert them to `AllowedValues` on the setting object.
7. **Give every setting a default at the point of reading**, not in an
   initialisation pass. A JSON file written by an older build must load.
8. **Add an `OnChanged` hook** and use it. TR4QT's absence of one is a real
   defect, not a simplification.
9. **Move passwords to a credential store**, not the JSON file.
10. **Write the round-trip test first**: for every registered setting, write a
    non-default value, reload, assert it comes back. This is only possible
    because the registry can enumerate.
11. **Convert one Preferences section per commit**, with the lint scripts
    already in `tr4w/build/` gating each one. Add a lint rule that fails on any
    `csJSON` row still holding a non-nil `crAddress`, so the count only goes
    down.

---

## 8. JSON file versus the database, for non-contest settings

Verdict up front: **the file is the right choice**, and the reasons are stronger
than "our users are used to looking at a file". But TR4W's current JSON writer
has a data-loss bug that the database would have prevented for free, and it is
open today.

### 8.1 TR4QT ran this experiment and the file won by walkover

TR4QT built the database option and never used it. Both schemas define a
key/value settings table:

```sql
-- global_schema.sql
CREATE TABLE IF NOT EXISTS global_settings (
    key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER NOT NULL);

-- schema.sql  (per-contest database)
CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT);
```

Neither table has a single reader or writer anywhere in the C++ source. Grep the
tree for `global_settings` outside the schema file and you get nothing. All ~200
settings went to the platform key/value store instead. Two settings tables were
designed, shipped in the schema, and never had a row written to them.

What *did* go in the global database is the useful signal: `lotw_users`,
`scp_callsigns`, `dxcc_entities`, `dx_spots`. Bulk reference data, indexed, and
queried on every keystroke. That is the boundary, and it is not about file format
preference at all.

### 8.2 Reasons the file wins that have nothing to do with familiarity

**Bootstrap ordering.** The database path is itself a setting. So are the log
level, the log path, and the data directory. Settings must be readable before the
database is open, because they say where it is and whether to log the attempt. A
settings store that lives in the database cannot configure the database.

**Failure isolation.** A locked, corrupt or mid-upgrade contest database must not
take the station configuration down with it. Separate files fail separately.

**Support economics.** "Email me your `tr4w.json`" resolves a case. Asking an
operator to extract rows from a SQLite file does not, and neither does asking
them to send a binary.

**Diff.** Two positions at a multi-op that behave differently can be compared
with a text diff in seconds.

**No schema migration to add a setting.** Adding a key to a JSON file is a
one-line change. Adding one to a relational schema is a migration, and TR4W has
508 of them to move.

Familiarity is a real reason on top of these, not instead of them. Operators
already read and hand-edit `tr4w.ini`. Removing that ability would be a
regression that buys nothing.

### 8.3 What SQLite gives for free that you must now build by hand

This is the price of the choice, and one item on the list is currently unpaid.

**Torn writes — OPEN BUG.** `utils/uFileText.pas:106`:

```pascal
procedure WriteAllTextUTF8(const aFileName: string; const aText: string);
begin
   raw := UTF8Encode(aText);
   stream := TFileStream.Create(aFileName, fmCreate);   // truncates to 0 bytes
   ...
   stream.WriteBuffer(raw[1], Length(raw));
```

`fmCreate` truncates the target to zero length **before** anything is written.
Between those two statements the operator's entire settings file is empty on
disk. A crash, a power loss, a full disk, or an exception thrown from the write
destroys the configuration outright. `TRadioConfigStore.SaveToFile` calls this
directly on the real filename, and three other call sites do the same. SQLite
would have made this failure structurally impossible.

*Fix:* write to `<name>.tmp` in the same directory, flush, close, rename the
previous file to `<name>.bak`, then rename the temp over the target. Rename
within a directory is atomic on NTFS, APFS and ext4. This also fixes readers: a
reader that opens the file mid-write today gets truncated JSON and a parse error.

**Concurrent writers.** Two TR4W instances on one machine, or the logger plus a
utility, both writing `tr4w.json` is last-writer-wins with silent loss. SQLite
locks; a file does not. Decide explicitly whether two instances is supported. If
it is, add a lock file. If it is not, detect and refuse the second instance
rather than letting it quietly overwrite.

**Schema version in every file.** `uRadioConfigStore` already has
`JSONKEY_VERSION`, which is right. Every settings file needs one from the first
release, not retrofitted. A version field costs nothing and is impossible to add
retroactively to files already in the field.

**Corrupt-file handling.** Hand-editability guarantees that operators will
eventually save invalid JSON. That must quarantine the file to `tr4w.json.bad`
and report loudly with the parse position. It must never silently fall back to
defaults, because a station that quietly reverts to defaults mid-contest is worse
than one that refuses to start.

**Backups.** TR4QT keeps five timestamped copies under `settings_backups/`. Cheap
to copy and worth having, precisely because the file is hand-editable.

### 8.4 Where the line should be in TR4W

| Goes in the JSON file | Goes in the database |
|---|---|
| Station identity, address, state, section | Callsign databases and SCP |
| Radio, amplifier, rotator, keyer config | DXCC and cty entity data |
| CW and phone messages | Spot history |
| Appearance, window behaviour | LoTW user list |
| Network peers, cluster servers | QSOs and contest data |

The test is not "is it a setting". It is: **does it need indexed lookup, or does
it exceed a few thousand rows?** If yes, database. Otherwise file. Roughly 500
scalar settings read once at startup gain nothing from a query engine.

### 8.5 The one argument against the file you should answer, not dismiss

A file store is wrong for anything written frequently at runtime. Rewriting and
re-serialising the whole document on every band change is a real cost, and it
multiplies the torn-write window above by however often it happens.

TR4QT got this wrong in the direction worth avoiding: it calls `sync()` after
every single setter, flushing to disk on every property write, and then adds a
60-second timer on top. That is a disk flush per assignment for no durability
benefit the atomic-rename pattern would not give better.

TR4W has already made the right split here by keeping `uWindowLayoutStore` and
`uPanadapterRestore` separate from the settings store. Keep going: audit for any
registered setting written more than once a minute. If one exists, it is session
state rather than a setting, and it belongs in its own store with its own write
cadence.

---

## Appendix — key files in TR4QT

| File | Lines | Role |
|---|---|---|
| `src/utils/AppSettings.h` | 713 | All ~200 accessor declarations |
| `src/utils/AppSettings.cpp` | 2,633 | Implementations, migrations, backup |
| `src/utils/CredentialStore.h` | — | OS keychain wrapper for passwords |
| `src/ui/managers/SettingsManager.h` | 128 | Groups related settings into structs for the UI |
| `src/ui/dialogs/PreferencesDialog.cpp` | 3,746 | Hand-wired settings UI |
| `src/core/Constants.h` | — | `APP_ORG` / `APP_NAME`, overridable at compile time |

`SettingsManager` is worth a look for the port. It sits above `AppSettings` and
returns whole structs — `FontConfig`, `WindowGeometry`, `BackupConfig`,
`UdpBroadcastConfig` — so the UI asks for one coherent group rather than calling
eight getters. It is the one place TR4QT partially recovers the grouping that a
registry would have given for free.
