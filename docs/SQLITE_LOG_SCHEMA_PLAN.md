# The contest log in SQLite — proposed schema

**A proposal for NY4I to verify, 2026-08-29. Nothing has been built.**

Reference: TR4QT at `C:/projects/TR4QT` (`src/data/schema.sql`, `Database.cpp`,
`BackupManager.cpp`). NY4I: *"TR4QT is not necessarily the right way to do it as
it was not a port. So I am open to other ways. But the ideas such as a flat
table structure, guid where IDs are needed, etc apply."*

Read [`DOMAIN_LAYER_SEQUENCE.md`](DOMAIN_LAYER_SEQUENCE.md) first — it settles
*why* this comes second (after display state) and it already contains the
three-tier event-sourcing decision this schema implements.

**Open questions are at the end and are the point of this document.**

---

## 1. Scope

In: the **contest log**. One database, holding QSOs, the contest's own entry
declaration, and whatever multiplier state we decide to persist.

**Out: a global database.** TR4QT has `tr4qt_global.db` for configuration,
cty.dat-derived tables, LOTW users, SCP and DX spots. NY4I, 2026-08-29: *"the
global in tr4qt was the configuration and cty.dat, etc. We do not need to do the
global database."* Correct, and it is consistent with where this tree already
is: configuration went to `settings/tr4w.json` (166 settings on `csJSON`),
CTY.DAT and TRMASTER.DTA stay as files, and the band map already persists
itself. A second store would be a second source of truth for things that already
have one.

Also out, for now: the `exchange_memory` table (TR4QT's per-callsign exchange
prediction). It is a feature, not a port of anything TR4W has.

---

## 2. What TR4QT gets right, and the one thing that must change

Right, and worth taking directly:

- **Flat tables.** Two that matter — `contests`, `qsos` — with no inheritance,
  no EAV, no normalisation of exchange fields into satellite tables. A contest
  log is read whole, written append-mostly, and exported. Flat is correct.
- **A GUID per QSO**, separate from the row id.
- **Named geographic columns** rather than one overloaded `QTH`. Its schema
  comment says so explicitly: *"Core geographic fields (commonly used, prevent
  overloaded QTH anti-pattern)"* — `state`, `county`, `arrl_section`,
  `grid_square`, `iota_reference` each get a column. This tree has the same
  problem recorded from the other direction: QTH is a contest-dependent
  catch-all, not a town.
- `PRAGMA foreign_keys = ON`, `journal_mode = WAL`, and `user_version` for
  schema version with migrations guarded by `PRAGMA table_info` before each
  `ALTER TABLE` (`Database.cpp:133`, `:137`, `:397`).
- Soft delete (`deleted`), which matches `ceQSO_Deleted` today.
- `is_run_qso`, `radio_nr` — SO2R and run/S&P are already per-QSO facts here.

**The one thing that must change: `my_grid`, `my_state`, `my_county` sit on the
CONTEST row.** A location change mid-log then cannot be represented, and roving
a QSO party or a VHF contest is exactly that. Those move to the QSO row. Its
`qsos.exchange_sent` is already per-QSO and is correct — it is the fix for our
four known corpus divergences.

---

## 3. Event sourcing — the three tiers, applied

The tier test, from `DOMAIN_LAYER_SEQUENCE.md`: **does it change within one
log?**

| tier | what | where it lives |
|---|---|---|
| 1. durable station identity | name, address, city, state, postcode, country, email, club | `settings/tr4w.json` — cross-contest; **seeds** the export form and stays overridable at export |
| 2. per-contest entry declaration | category, transmitters, assisted, overlay, power, station, mode, band, time, soapbox, my park | the **`contest` row**, captured when the log is created — never read live at export |
| 3. per-QSO event | what was **sent**; my county; my grid | the **`qso` row** |

Tier 2 is the subtle one and it is where issue #2 actually bites: these must be
*captured at log creation and stored*, not read from config at export time. A
park cannot vary per QSO — a different park is a different log — but it must
still be what it was when the log was made, not what the config says today.

`_OPERATORS` is **derived** from the QSO rows, not stored.

**VERIFIED 2026-08-29.** The claim is not just true, it is written in the code:
`uCabrilloHeader.pas:24-29` — *"re-exporting a 2024 log stamps TODAY's address
on it… That is a real integrity problem and it is deliberately NOT fixed here."*

`ContestExchange` (`VC.pas:1669-1793`) holds **no `My*` field of any kind**. The
only sending-side data stored per QSO is `NumberSent`, `RSTSent`,
`RandomCharsSent`, `ceOperator`, `ceComputerID`, `ceContest`. `ExchString` is
the **received** exchange, not the sent one — there is no composed sent-exchange
string anywhere in the record.

Twelve station values are read live at export, each into a
`TMyStationExchange` built per QSO (`PostUnit.PAS:3008-3018` →
`uCabrilloExchange.pas:145-155`): `MyState`, `MyGrid`, `MyName`, `MyZone`,
`MyFDClass`, `MySection`, `MyCheck`, `MyPrec`, `MyFOCNumber`, `MyPostalCode`,
`MyPark`, `MyCall`. `MyPark` is NY4I's own example and it is the sharpest:
every record in an exported POTA log gets today's park
(`PostUnit.PAS:2226-2227`). See §12 for the full inventory and for four findings
that change this plan.

---

## 4. Proposed schema

Deliberately close to TR4QT's where there is no reason to differ, so the two can
be compared and a TR4QT log can be read by us later if that is ever wanted.

```sql
PRAGMA user_version = 1;

-- ONE ROW. This is the log's own identity and its entry declaration, frozen
-- when the log is created. Nothing here is re-read from configuration at
-- export: that is the whole point (issue #2).
CREATE TABLE contest (
    id                INTEGER PRIMARY KEY CHECK (id = 1),
    guid              TEXT NOT NULL UNIQUE,
    contest_type      TEXT NOT NULL,      -- our ContestType, as a token
    contest_name      TEXT NOT NULL,
    created_at        INTEGER NOT NULL,   -- unix UTC
    start_time        INTEGER,
    end_time          INTEGER,

    -- tier 2: the entry declaration, as sent in the Cabrillo header
    my_call           TEXT NOT NULL,
    category_operator TEXT,
    category_assisted TEXT,
    category_power    TEXT,
    category_band     TEXT,
    category_mode     TEXT,
    category_station  TEXT,
    category_time     TEXT,
    category_transmitter TEXT,
    category_overlay  TEXT,
    club              TEXT,
    my_park           TEXT,               -- POTA: constant for a whole log
    soapbox           TEXT,

    -- tier 2: station identity AS DECLARED FOR THIS LOG. Copied from the JSON
    -- identity at creation; edited here it does not disturb the next contest.
    op_name           TEXT,
    address           TEXT,
    city              TEXT,
    state             TEXT,
    postcode          TEXT,
    country           TEXT,
    email             TEXT
);

CREATE TABLE qso (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    guid              TEXT NOT NULL UNIQUE,

    qso_at            INTEGER NOT NULL,   -- unix UTC seconds
    callsign          TEXT NOT NULL,
    frequency_hz      INTEGER NOT NULL,
    band              TEXT NOT NULL,
    mode              TEXT NOT NULL,
    submode           TEXT,

    rst_sent          TEXT,
    rst_received      TEXT,
    exchange_sent     TEXT,               -- WHAT WE SENT. tier 3, and the fix
    exchange_received TEXT,               -- for the corpus divergences

    -- tier 3: ours, at the moment of this QSO
    my_county         TEXT,
    my_grid           TEXT,
    my_state          TEXT,

    -- theirs, parsed
    serial_sent       INTEGER,
    serial_received   INTEGER,
    state             TEXT,
    county            TEXT,
    arrl_section      TEXT,
    grid_square       TEXT,
    iota              TEXT,
    contest_class     TEXT,               -- Field Day "2A"
    precedence        TEXT,               -- Sweepstakes
    check_year        TEXT,               -- Sweepstakes
    op_name_received  TEXT,               -- NAQP
    power_received    TEXT,               -- ARRL DX

    -- from CTY.DAT at the time of the QSO
    dxcc_prefix       TEXT,
    dxcc_entity       TEXT,
    dxcc_code         INTEGER,
    cq_zone           INTEGER,
    itu_zone          INTEGER,
    continent         TEXT,

    qso_points        INTEGER DEFAULT 0,
    is_dupe           INTEGER DEFAULT 0,
    is_run            INTEGER DEFAULT 0,
    radio_nr          INTEGER DEFAULT 1,
    operator_call     TEXT,
    deleted           INTEGER DEFAULT 0,
    notes             TEXT
);

CREATE INDEX idx_qso_at       ON qso(qso_at);
CREATE INDEX idx_qso_callsign ON qso(callsign);
CREATE INDEX idx_qso_dupe     ON qso(callsign, band, mode) WHERE deleted = 0;
```

Differences from TR4QT worth noting: `contest` is a **single row** with
`CHECK (id = 1)` rather than a table of many contests (see question 1);
`my_*` fields are on the QSO; there is no `multipliers` table yet (question 3);
`current_serial` is not stored, because it is `MAX(serial_sent)` and a stored
copy is a second source of truth that can disagree.

---

## 5. Identity — GUIDs

A GUID per QSO and per contest, `TEXT`, separate from the `INTEGER PRIMARY KEY`.
The row id is a local detail; the GUID is what survives export, import, and — the
real reason — **multi-op merge**. Today `tr4wserver` reconciles logs by serial
number and callsign; a stable per-QSO identity makes "did I already have this
QSO" answerable without heuristics.

Recommendation: **UUIDv7**, not v4. v7 is time-ordered, so an index on it stays
local rather than scattering, and it sorts by creation. FPC has no v7 generator
built in; it is about fifteen lines (48-bit unix millis + 74 random bits).

---

## 6. Backup — the Online Backup API

NY4I is right that this is the API to use, and right about why. The relevant
part of SQLite's own argument, quoted in the request:

> If a power failure or operating system failure occurs while copying the
> database file the backup database may be corrupted following system recovery.

That holds regardless of how big our logs are, and it is the strongest reason —
stronger than the locking argument, because our locks would be brief anyway.

**FPC already wraps it.** `sqlite3backup.pas` ships with FPC 3.2.2 for
i386-win32 (`units/i386-win32/fcl-db/sqlite3backup.ppu`), and it is a thin
wrapper over `sqlite3_backup_init` / `_step` / `_finish`:

```pascal
function Backup(Source: TSQLite3Connection; FileName: string;
                LockUntilFinished: boolean = true;
                SourceDBName: string = 'main'): boolean;
function Restore(FileName: string; Destination: TSQLite3Connection; ...): boolean;
property OnBackupProgress: TOnBackupProgress;   // (Remaining, PageCount)
property PageStep: integer;        // default 10   } only used when
property LockReleaseTime: integer; // default 100ms} LockUntilFinished = False
```

**`LockUntilFinished` is the whole decision**, and the unit's own header states
the trade honestly:

| | `True` (default) | `False` |
|---|---|---|
| how | `sqlite3_backup_step(-1)` — every page in one call | `PageStep` pages, then `sqlite3_sleep(LockReleaseTime)` |
| lock | held for the whole copy | released between steps |
| if the source is written meanwhile | cannot happen | **the backup restarts** |
| risk | writers wait | under sustained writes it may never finish |

**A nuance that decides which to use, and it is not in the FPC header.** SQLite
restarts the backup when the source is written *through a different connection*.
A write through **the same connection handle** the backup is reading from is
folded into the running copy instead — no restart. So an incremental backup that
shares the logger's connection behaves well, and one on its own connection is
the case that can starve.

That collides with running it off the UI thread: `LockUntilFinished = False` is
a sleep loop, so on the main thread it stalls the program for the whole backup,
and on a worker thread it needs its own connection — which is the restarting
case.

**Recommendation, and it is size-driven.** Today's largest corpus log is
**77,832 bytes** binary; the whole set runs 752 bytes to 77 KB. As SQLite with
indexes call it low single-digit MB for a serious multi-op log. A one-shot
`LockUntilFinished := True` backup of that is milliseconds — the writers-wait
column costs nothing measurable, and we get the power-failure safety that was
the actual reason for using the API.

So: **use the API, with `LockUntilFinished = True`, on the logging thread**, and
keep `False` available behind a threshold if a log ever gets large enough to
matter. `OnBackupProgress` is wired either way so the decision can be revisited
with numbers rather than argument.

Not `VACUUM INTO`, which is what TR4QT actually does
(`BackupManager.cpp:86`) despite the API being available: it is a single
statement and it compacts, but it is a full-lock snapshot with none of the
incremental option, and no path to backing up an in-memory database if we ever
want one for tests.

**Rotation and naming** can be taken from TR4QT directly — timestamped
`<base>_yyyyMMdd_HHmmss.db`, newest-first listing, delete beyond `maxBackups`
(`BackupManager.cpp:262`).

---

## 7. Integrity checks

TR4QT validates a backup by opening it and running `PRAGMA integrity_check`,
accepting only the literal `ok` (`BackupManager.cpp:287`). That is the right
shape and we should take it, plus:

- **`PRAGMA foreign_key_check`** as well as `integrity_check`. The first finds
  structural corruption; the second finds broken references, which is the one a
  bad merge or a partial delete would produce.
- **A domain check the pragmas cannot do**: the backup's QSO count equals the
  source's. TR4QT has exactly this (`getBackupQSOCount`, counting
  `WHERE deleted = 0`) but does not appear to compare it to the source. Compare
  it — a backup that opens cleanly and has the wrong number of QSOs is the
  failure that matters to an operator.
- **On open, not only on backup.** A log opened after a crash should be checked
  before it is written to.
- **Report, never silently repair.** Consistent with this tree's rule that a
  reported error beats a silent fallback.

---

## 8. Pragmas and schema versioning

```
PRAGMA journal_mode = WAL;      -- as TR4QT
PRAGMA foreign_keys = ON;       -- as TR4QT
PRAGMA synchronous = FULL;      -- NOT as TR4QT, which leaves the default
PRAGMA user_version = <n>;
```

`synchronous = FULL` is proposed deliberately. The default (`NORMAL` under WAL)
can lose the most recent transactions on power loss. A contest log writes a few
hundred bytes every several seconds; the durability is free at that rate and the
thing being protected is the operator's contest.

Migrations: `user_version` compared on open, refuse to open a database **newer**
than the running program understands (TR4QT does this, `Database.cpp:177`), and
each migration guarded by `PRAGMA table_info` so it is idempotent.

---

## 9. Drivers — what is installed, and the one thing that is not

NY4I asked whether SQLite drivers need installing for FPC. **The compile-time
half is already here; the runtime half is not.** Measured 2026-08-29:

| | state |
|---|---|
| FPC units, i386-win32 | **present** — `sqlite3conn`, `sqlite3backup`, `sqlite3ds`, `sqlite3dyn`, `sqlite3`, `sqlite3db`, `sqlite3ext` under `units/i386-win32/{sqlite,fcl-db}` |
| `sqlite3.dll` | **now in `tr4w/target/`** — supplied by NY4I 2026-08-29, 2,572,288 bytes, PE machine `0x014c` = **i386**, which is what an i386-win32 build needs |
| our unit search path | **fcl-db is not on it** — `Get-SearchPaths.ps1` adds `fcl-json` and `regexpr`, not `fcl-db`, `fcl-base` or `sqlite` |

So there is **no package to install and nothing to build**. What remains:

1. Add `units\<cpu>-<os>\fcl-db`, `\fcl-base` and `\sqlite` to
   `Get-SearchPaths.ps1` — for the App target, and for Tests if the log gets
   unit coverage (it should). `sqlite3conn` needs `db`, `bufdataset`, `sqldb`
   from fcl-db and `sqlite3dyn` from sqlite.
2. Add `File ..\target\sqlite3.dll` to `build\full.nsi` (it lists each DLL by
   name, `full.nsi:140-145`) and a row in `docs/UPDATING_RUNTIME_DLLS.md`.
   **Deliberately NOT done yet** — nothing loads it, and shipping 2.5 MB for a
   feature that does not exist is not free. This belongs in the same commit as
   the first code that opens a database.
3. FPC's binding is **dynamic** — `sqlite3.inc:28` declares
   `Sqlite3Lib = 'sqlite3.dll'` — so it is loaded at run time and a missing DLL
   is a run-time failure, not a link error. That failure must be **reported**,
   not a silent downgrade.
4. `TSQLite3Connection` and `TSQLite3Backup` are then usable.

**Where the DLL lives.** It arrived in `tr4w/include/`, which is the *vendored
source* directory — Indy, Log4D, PerlRegEx — and is on the compiler's `-Fi`
include path. A runtime DLL there would never be shipped and never be found.
Moved to `tr4w/target/`, beside the six DLLs already tracked there
(`libhamlib-4.dll` and friends), which is both where the program looks and what
the installer copies from.

`sqlite3.def` was supplied with it and is still in `tr4w/include/`. **It is not
needed**: a `.def` exists to build an import library for load-time linking, and
FPC's binding resolves through `LoadLibrary`/`GetProcAddress` at run time. Kept
for now rather than deleted, but it should go — see question 10.

**32-bit for now, 64-bit later** (NY4I, 2026-08-29). The DLL must match the
build, and a mismatch fails inside `LoadLibrary` with an error that does not say
"wrong architecture" — it says the module could not be found. So the 64-bit move
has to swap this DLL, and the load path should **report the architecture it
found** when the load fails, rather than leaving an operator to guess. Cheap:
read the PE machine word from the file we tried to load and say so. The same
trick already guards the server's dialog resource in `Build-Server.ps1`.

Worth pricing honestly against the dependency rules: one ~1.5 MB DLL, in
exchange for deleting a hand-rolled binary record format, its versioning, and
its repair paths. That is a good trade, but it is a trade and it should be a
decision rather than a side effect.

---

## 9a. No caching layer

NY4I, 2026-08-29: *"file size, i/o time, etc are not concerns of mine. A 10000
record sqlite db is basically nothing. Speed of our writes, and reading the
database when needed are important but we do not generally need to do abstract
cache mechanisms etc since sqlite will always do it better than we can."*

Taken as a design rule, and it settles several things at once:

- **No ORM, no repository abstraction for its own sake, no in-memory mirror of
  the log.** Query SQLite; it has a page cache and we will not beat it.
- **No stored derived values** where a query answers it: no `current_serial`
  (it is `MAX(serial_sent)`), no stored score, no stored QSO count.
- The things that must be fast are **the write on logging a QSO** and **the
  dupe check while typing**. Both are single indexed statements against ten
  thousand rows. Use a prepared statement for each and measure once; do not
  design around them in advance.
- It also removes the strongest argument for a `multipliers` table — see
  question 3.

The exception, if one appears, has to be justified with a measurement rather
than a fear.

---

## 10. Constraints that must hold

**The golden corpus is the regression oracle and it reads binary `.dat` through
the export path.** 22 passed / 0 failed / 4 known-divergence is the baseline.
The migration has to keep that oracle working across the change, or the only
proof that scoring and Cabrillo did not move disappears at exactly the moment it
is most needed. Concretely that means an **importer** from `.trw` is not
optional and is not a convenience feature — it is how the corpus keeps running,
and it is how existing operators keep their logs.

The four known divergences should **turn green** as part of this work, because
storing `exchange_sent` per QSO is precisely their fix. That is the acceptance
test for the event-sourcing half of this plan.

---

## 11. Open questions — NY4I

1. **One database per contest, or one holding many?** TR4QT stores one file per
   contest, named `<ContestType>_<StartDate>.db`
   (`docs/File-Storage-Locations.md:185`), but its schema still has a `contests`
   *table* with an autoincrement id and a FK from `qsos` — so the structure
   allows many and the practice is one. I have proposed a **single-row `contest`
   table** (`CHECK (id = 1)`), one file per contest, matching today's one `.cfg`
   + one `.trw` and keeping a log a thing you can email. Say if you want many
   contests per file instead — it changes every query and is much harder to undo
   later than to decide now.

2. **Where do the files live?** Today: beside the `.cfg` in the working
   directory. TR4QT: `%LOCALAPPDATA%\TR4QT\logs\`. There is an existing tabled
   decision here (`settings-location-appdata`) about probing writability and
   telling the operator. Same answer for logs, or different?

3. **Is the multiplier table stored or derived?** TR4QT stores one. Storing it
   makes it a second source of truth that can disagree with the QSOs — and a
   contest logger showing the wrong mult count is showing the wrong score.
   **Derive it by query, store nothing**, which is also what §9a implies: a
   `multipliers` table is a cache, and the only argument for it was a
   performance one that does not survive ten thousand rows. I have left it out
   of §4 on that basis — say if you disagree, because it is scoring-adjacent
   and those calls are yours.

4. **Timestamps: unix INTEGER, or ISO-8601 TEXT?** TR4QT uses INTEGER unix
   seconds. INTEGER sorts and indexes better and is unambiguous about UTC; TEXT
   is readable when someone opens the file in a SQLite browser, which for a
   format operators may inspect is a real argument. I lean INTEGER with a view
   for readability. Also: seconds or milliseconds? Our log records to the
   second today.

5. **GUID version — v7 as recommended, or v4?** v7 is time-ordered and indexes
   better; v4 is what TR4QT uses and is trivially available everywhere.

6. **`frequency_hz` INTEGER — confirm the unit.** The current record's
   frequency unit needs confirming before this is fixed (the background
   verification will report it). If we store Hz and the engine works in tens of
   Hz, the conversion must be in exactly one place.

7. **Backup trigger.** On a timer, on N QSOs, on close, or on demand from a
   menu? TR4QT's `BackupManager` has rotation but the policy is separate. And
   how many generations to keep?

8. **Does a TR4QT log need to be readable by us, or ours by TR4QT?** If yes,
   the schema differences in §4 have a cost and some should be reconsidered. If
   no — which I assume — then the remaining reason to stay close to TR4QT's
   shape is only familiarity.

9. **What happens to `.trw` after the migration?** Import-only, or do we keep
   writing both for a release so an operator can go back? I would write only
   SQLite and keep the importer permanently, but a dual-write release is the
   conservative option and it is cheap.

10. **Delete `tr4w/include/sqlite3.def`?** Not needed by a dynamically-bound
    build (§9). Kept only in case you want it for something else.

11. **`TDBGrid` for View / Edit Log — agreed?** §11a argues yes for that window
    and no for the main-window log. If yes, a second question follows: does the
    grid get its own `TSQLQuery` (simplest, puts SQL in a UI unit for one
    read-only window), or does the domain hand it a dataset (keeps the layering
    clean, slightly more machinery)? I lean to the first **for this window
    only**, on the grounds that a read-only browser is not where the layering
    rule earns its keep — but it is the sort of exception that spreads, so it
    should be a decision with a reason attached rather than a shortcut.

---

## 11a. The two grids — `TDBGrid` or a virtual list?

They are two different windows with two different jobs, and they want two
different answers.

### The main-window log: a VIRTUAL `TListView`, not `TDBGrid`

Verified 2026-08-29:

- **There is no in-place editing to gain.** No `LVS_EDITLABELS`,
  `LVM_EDITLABEL` or `LVN_ENDLABELEDIT` anywhere in the tree. A QSO is edited
  through `uEditQSOForm` — 69 fields, validation, and a re-run of dupe,
  multiplier and scoring. That is `TDBGrid`'s headline feature and we do not use
  it.
- **It is not a table view.** Created `LVS_REPORT | LVS_NOSCROLL |
  LVS_SINGLESEL` (`MainUnit.pas`, `style1`) — a bounded viewport pinned into the
  main window's layout arithmetic, colour-coded by dupe/mult/deleted state.
  `TDBGrid` brings its own scrolling and navigation model and would fight that
  geometry.
- **Layering.** `TDBGrid` → `TDataSource` → `TSQLQuery` makes the grid *be* the
  query and puts SQL in a UI unit — what `src/domain/` and `Lint-DomainPurity`
  exist to prevent. A virtual list asks a domain object for row *N* and never
  learns that SQLite exists.
- **It is a cache by accident.** `TSQLQuery` buffers rows in a `TBufDataset`: a
  second copy of the log in memory, arriving as a side effect rather than a
  decision. See §9a.

It is also the recorded decision already (`DOMAIN_LAYER_SEQUENCE.md` §2). Note
the grid is **not** virtual today — it is populated row by row through
`tAddContestExchangeToLog`. Going virtual is part of this work, and it is cheap
here precisely because `LVS_NOSCROLL` bounds the viewport: `OnData` answers for
a handful of visible rows, so no paging and no cache.

### View / Edit Log: **yes, this is the `TDBGrid` case**

`menu_ctrl_viewlogdat` (Ctrl+L) → `ShowLogEdit` → `uLogEdit.pas:130`. What it
does today:

- `CreateModalDialog(396, 212, ...)` — a runtime-built Win32 dialog, so it has
  to be converted anyway;
- hosts the same `CreateEditableLog` ListView at 790×420;
- **reads the entire log** in a `ReadLogFile` loop, adding every record
  (`uLogEdit.pas:74-79`);
- double-click or the OK button → `EditFullLog` → `OpenEditQSOWindow`.

That is a whole-log browser: read-mostly, off the contest hot path, opened
deliberately, and its only interaction is *pick a row, open the edit form*. Every
objection above either weakens or disappears:

| objection | main log | View / Edit Log |
|---|---|---|
| in-place editing unused | applies | applies — grid stays `ReadOnly`, `dgEditing` off |
| fights a fixed viewport | applies | **does not** — this window wants scrolling |
| SQL in a UI unit | serious, it is the hot path | mild, and containable |
| buffers the log in memory | an unwanted cache | it already loads the whole log |

And it buys something real. **This window cannot sort or filter at all today.**
Behind a dataset, "only multipliers", "sort by callsign", "20m only" are changes
to one `ORDER BY` / `WHERE` — which is the thing SQLite is actually good at, and
a visible improvement for an operator checking a log after a contest.

So: **`TDBGrid` for View / Edit Log, read-only, with the edit form still doing
the editing.** Recommendation, not a decision — see question 11.

### What the two look like in Pascal

NY4I has not used SQLite from Pascal before, so concretely — both are ordinary
FPC/LCL, no third-party anything.

**A. `TDBGrid` for the browser.** Four components, three of them non-visual:

```pascal
uses sqlite3conn, sqldb, db, DBGrids;

FConn := TSQLite3Connection.Create(Self);
FConn.DatabaseName := aLogPath;              // sqlite3.dll loads here
FTx := TSQLTransaction.Create(Self);
FTx.Database := FConn;                       // SQLdb REQUIRES a transaction
FConn.Transaction := FTx;

FQuery := TSQLQuery.Create(Self);
FQuery.Database      := FConn;
FQuery.Transaction   := FTx;
FQuery.PacketRecords := -1;                  // fetch all; the default is 10
FQuery.SQL.Text := 'SELECT qso_at, callsign, band, mode, exchange_sent, ' +
                   'exchange_received FROM qso WHERE deleted = 0 ORDER BY qso_at';
FQuery.Open;

FSource := TDataSource.Create(Self);
FSource.DataSet := FQuery;
dbgLog.DataSource := FSource;                // the grid is now populated
```

Re-sorting is `FQuery.Close; FQuery.SQL.Text := ...ORDER BY callsign; FQuery.Open;`
Colour by state is `OnDrawColumnCell`. Double-click reads
`FQuery.FieldByName('guid').AsString` and opens the edit form on that QSO.

**B. Virtual `TListView` for the main log.** No data-aware components at all:

```pascal
lvLog.OwnerData := True;                     // ask me for rows, do not store them
lvLog.Items.Count := LogModel.VisibleCount;  // domain object, not a query

procedure TfrmMain.lvLogData(Sender: TObject; Item: TListItem);
var q: TQsoRow;                              // a plain record from src/domain
begin
   q := LogModel.RowAt(Item.Index);          // the view never sees SQL
   Item.Caption := q.Callsign;
   Item.SubItems.Add(q.Band);
   Item.SubItems.Add(q.ExchangeReceived);
end;
```

`LogModel` lives under `src/domain/` and is the only thing that knows there is a
database. That is the seam the whole sequencing argument is about, and it is why
the main log gets this shape and the browser can afford the other one.

Measured 2026-08-29 against the code, not inferred. Four of these change the
plan; they are not tidy-ups.

### 12a. The corpus divergences are exactly this mechanism — but fixing it does not close all four

All four differ in **one field only**, the my-exchange column, and nothing else
(a field-level ADIF comparison across all 79 records of `general_qso` found the
differing tag set to be exactly `STX_STRING` plus the normalised version and
timestamp):

| set | D7 reference | current output | cause |
|---|---|---|---|
| `general_qso` adi/cbr | `59 TOM` | `59` | `MyName` empty at export → `SetMyEx` drops it (`uCabrilloExchange.pas:172`) |
| `iaru_hf` adi/cbr | `59 8` | `59 0` | `MyZone` empty → `StrToIntDef(...,0)` yields 0 (`uCabrilloExchange.pas:225`) |

They are empty because `/EXPORT` deliberately skips `ApplyStoredCommands` and
applies only `COMPUTER ID` (`uProgramMain.pas:1067-1072`), so both globals sit
at their `CFGDEF.PAS:294-295` default of `''`.

**But `iaru` will still diverge after event sourcing.** D7 sent `8`, the ITU
zone. The live store's `MY ZONE` is `5`, the CQ zone; `MY ITU ZONE` is a
separate command **that no export path reads at all** (verified by exhaustive
grep — its only consumer is `uGetScores.pas:433`). `MyZone` is one global doing
double duty. **Consequence for the schema: store the zone that was SENT, per
QSO. Do not store "MyZone" and re-derive.** That is the general principle
anyway, and this is the case that proves it.

### 12b. `known-divergences.txt` is wrong in three places

It is the tracking file for the corpus oracle, so this matters more than it
looks.

- Line 13 describes the iaru case as the sent zone *"falls back to MY STATE"*
  and records the candidate as `59  FL`. There is no MY-STATE fallback in that
  arm (`uCabrilloExchange.pas:223-227`); the `FL` was almost certainly the
  dangling-`PChar` bug since fixed and documented at `PostUnit.PAS:2753-2759`
  (*"'599 001' became 'FL 001' across six corpus sets"*).
- Line 14 says general_qso has *"MY STATE appended to sent exchange"*. It is the
  **opposite**: `MY NAME` is missing. Nothing is appended.
- Both entries therefore describe defects that no longer exist, against a
  candidate output that no longer matches.

**Fix the file before using it to judge whether this work succeeded.**

### 12c. A real shipping defect the corpus cannot see

`golden_diff.py` keeps only `QSO:`/`X-QSO:`/`CLAIMED-SCORE:` lines — *"the
header is entrant/settings metadata that legitimately varies"* — so the Cabrillo
**header** is never compared. It diverges badly. On both corpus sets a headless
export produces a file with:

```
CATEGORY-ASSISTED:      absent   (D7: ASSISTED)
CATEGORY-BAND:          absent   (D7: ALL)
CATEGORY-OPERATOR:      absent   (D7: MULTI-OP)
GRID-LOCATOR:           absent   (D7: EL88PA)
CATEGORY-MODE:    SSB            (D7: MIXED)
CATEGORY-TIME:    12-HOURS       (D7: 24-HOURS)
CATEGORY-TRANSMITTER: ONE        (D7: UNLIMITED)
```

Cause: those header lines come **only** from `cabrilloHeader` in `tr4w.json`,
never from the contest `.cfg`. In the GUI the `.cfg` seeds the dialog combos
(`uCbrSum.pas:207`, `245-248`); headless there is no dialog, the tags are unset
(`ctrSave: False` for exactly ASSISTED/BAND/OPERATOR, `uCbrSum.pas:102,103,105`),
and the emit loop skips them (`PostUnit.PAS:2640-2645`). Meanwhile
`CategoryOperator` **from the `.cfg`** *is* used for the per-QSO transmitter
digit (`PostUnit.PAS:3028-3036`) — so the QSO lines and the header disagree
about the same fact within one file.

**A headless export ships a log to a sponsor with three CATEGORY lines missing
and a CATEGORY-MODE that contradicts the log's own configuration.** This is
tracked nowhere. It is squarely tier 2 — capture the entry declaration on the
contest row at log creation and the whole class disappears — which is an
argument for doing tier 2 properly rather than treating it as the easy part.

### 12d. Mid-log change is already possible, and already inconsistent

The design assumed we were deciding whether these *may* change mid-log. They
already can: `MY GRID`, `MY STATE`, `MY SECTION`, `MY ZONE` and `MY PARK` are
all `csOwned` commands editable from Preferences at any moment, applied straight
into the global (`uCFG.pas:1814-1819`). No guard, no warning.

And the effect is **incoherent today**, which is the worst finding here:

- **What is SENT is baked at contest setup.** `CQExchange`,
  `SearchAndPounceExchange` and the F-key memories substitute `MyGrid`
  textually in `FCONTEST.PAS:481-482`, `611-621`, which runs once from
  `uProgramMain.pas:1147`. `FCONTEST.PAS` says so outright: *"MyGrid is
  substituted at FCONTEST init time … the operator must restart the contest
  setup if MyGrid changes."*
- **What is EXPORTED is read live.**

So a rover who edits `MY GRID` mid-contest **keeps sending the old grid and
exports the new one** — the two diverge in the worst possible direction, and
nothing reports it. Storing what was sent per QSO fixes the export half; the
sending half is a contest-factory problem.

Two smaller notes: **`MY COUNTY` does not exist** — no global (commented out at
`LOGWIND.PAS:702`, and also commented out in the D7 tree), no config command —
so QSO-party county roving is a new feature, not a port. And `MyPark` *is* read
live per keystroke (`LOGSTUFF.PAS:5077`), so "a different park is a different
log" is a **policy we would be introducing**, not a fact the code enforces.

### 12e. Corrections to `DOMAIN_LAYER_SEQUENCE.md`

- The header/exchange separation is real but `uCbrSum.pas` is **not** the
  separation point — it is the dialog over the header store. The split is
  structural, between `uCabrilloHeader` (the JSON tag store) and the `My*`
  CFGCA globals.
- `ctrSave` no longer persists to `tr4w.ini [REPORT]`; it goes to
  `settings\tr4w.json` under `cabrilloHeader` (moved 2026-08-16). A stale
  comment in `uCbrSum.pas:326-327` still says `[REPORT]` too.
- `ctrCFG` is declared at line **76** and the array has **21** rows, not 22 —
  and it is **not** uniformly set: 11 `True`, 10 `False`. It is still never
  read, so it is still dead.
