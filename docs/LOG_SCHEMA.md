# The contest log: schema definition

This document defines the TR4W contest log as it stands at **schema 13**. A
contest log is one SQLite file per contest.

**The code is the source.** The DDL lives in
`tr4w/src/domain/uLogSchema.pas` (`LOG_SCHEMA_STATEMENTS`; the `qso` table and
its indexes are the named `LOG_QSO_TABLE` and `LOG_QSO_INDEXES`, which the
schema-11 rebuild runs too). The migration is
`TLogDatabase.MigrateSchema` in `tr4w/src/domain/uLogDatabase.pas`. The
column-to-record mapping is `tr4w/src/uLogRepository.pas` (`QSO_COLUMNS`,
`TQsoColumn`, `BindRecord`, `ReadRecord`). If this document and the code
disagree, the code is right and this document has a bug.

`docs/SQLITE_LOG_SCHEMA_PLAN.md` is the plan and the decision history: why
the schema is flat, every ruling, and the measurements behind them. It is not
a definition of the current schema. Its section 4 is a proposal that the
shipped DDL diverged from; that document's own banner says so. Where the two
disagree, see "Where the plan document disagrees" at the end of this file.

---

## 1. File identity, pragmas and compatibility

| what | value | where |
| --- | --- | --- |
| `PRAGMA application_id` | `0x54523457` ('TR4W'). 0 is accepted as "never stamped". Any other value is refused. | `LOG_APPLICATION_ID`, `VerifyIdentity` |
| `PRAGMA user_version` | `LOG_SCHEMA_VERSION`, currently **12** | `uLogSchema` |
| `PRAGMA journal_mode` | `WAL`, requested and read back. A network share may refuse WAL and fall back to the rollback journal; the open records which one took effect. | `ApplyWritePragmas` |
| `PRAGMA synchronous` | `FULL`. This differs from SQLite's WAL default (`NORMAL`) on purpose: the log must survive a power cut. | `ApplyWritePragmas` |
| `PRAGMA foreign_keys` | `ON`, read back. A connection that cannot enable it is refused. | `ApplyPragmas` |
| `PRAGMA busy_timeout` | Set first on every connection: 2000 ms on the main connection, 1000 ms on the WRL worker's, less in tests. | `ApplyPragmas`, `LOG_BUSY_TIMEOUT_MS` |

Rules that apply to every open:

- **A log from a newer schema is refused.** `VerifyIdentity` will not open a
  file whose `user_version` is above the build's own.
- **An older log is migrated in place by `TLogDatabase.Open`.** Opening is
  enough. Once a build has opened a log, every build older than it will
  refuse that log.
- **THE PROGRAM BACKS UP AN OLDER LOG BEFORE IT MIGRATES IT** (NY4I,
  2026-11-19). `TLogDatabase.Open`, with `BeforeMigration` assigned, opens
  the file READ-ONLY on a connection of its own, before its write connection
  exists (so before `journal_mode = WAL` touches the header), and reads
  `user_version`. Below `LOG_SCHEMA_VERSION` it asks for a backup;
  the store's answer (`uLogStore.OpenExistingLog`) is
  `uLogBackup.BackUpLogBeforeUpgrade`: the `TLogBackup` sequence (staged
  `.new`, `integrity_check` on its own read-only connection, rename) to
  `<log> before schema <from> to <to>.db` in `uAppPaths.BackupDir` (the
  folder every backup uses; `--settings` moves it). **A taken name gets a
  number** (`uLogNaming.FirstFreeLogFileName`), so no backup is overwritten
  or displaced to `.bak`. **If the backup fails, the open is REFUSED**
  (`ELogDatabaseError`, naming both versions and the reason) **and the file
  has not been written**; the store stands down as for any failed open and
  logs it at Error. What each open does:
  - a log already at the current schema, and a new log: no backup;
  - an older log: one backup, then the migration; opened again it is current,
    so no second backup;
  - a headless run (`/EXPORT`, `/RESCORE`, `/IMPORT`) of an older log: the
    same backup, to the same folder -- the corpus's schema-2 logs each take
    one, into the corpus's own settings folder (`corpus-lib.sh` clears it).
    A refused one, MEASURED 2026-11-19 (`/EXPORT`, the backup folder a
    file): two Error lines in `tr4w.log`, the log byte-identical with no
    sidecar, no ADIF or Cabrillo written -- and **exit code 0**, which is
    what every failed store open does under `/EXPORT` today (not new here;
    open);
  - a log from a newer build, or not a TR4W log: refused by the read-only
    probe, never copied;
  - the store's read-only mode and `OpenReadOnly`: never migrate, so never
    back up.
  `BeforeMigration` is a per-instance property, nil by default: a test or a
  tool that opens a file it made itself takes no backup, and only the store
  assigns it. The store's folder comes from `LogStoreUpgradeBackupFolder`
  (`uProgramMain` assigns `BackupDir`; a test its own scratch folder); unset,
  an older log is refused. **Not covered**: the one migration that can reach
  a log already AT the current schema (`external_delivery.last_sent`, which
  arrived inside schema 5; development logs only). A migration that fails
  after its backup is backed up again on the next attempt, under a numbered
  name. The version is read through `OpenToPeek`, so a refusal for a missing
  folder leaves nothing beside a WAL-mode log; a backup that fails after its
  snapshot began may leave SQLite's empty `-wal`/`-shm` beside it. Pinned by
  `uTestLogMigrationBackup`.
- **`TLogDatabase.OpenReadOnly` neither migrates nor writes.** It sets no
  write pragmas. The store's read-only mode cannot open an older-schema log
  at all, because the upgrade is a write.
- **A whole migration is ONE transaction.** Every `ALTER`, every carried
  value, every backfill mark and the new `user_version` are one commit
  (`TestAMigrationIsOneCommit` counts the commit frames). Each added column is
  checked with `pragma_table_info` before it is added. The checks are made
  before the first change, so asking them never commits half a migration.
- **A removed column is a table REBUILD, never `ALTER TABLE DROP COLUMN`**
  (schema 11). `DROP COLUMN` needs SQLite 3.35, the Linux tarball and macOS
  use the system library, and 3.42 and later distro builds fail it around
  comment-only lines (issue #141). The rebuild renames the old table,
  creates `LOG_QSO_TABLE` verbatim, copies every kept column by name, keeps
  the AUTOINCREMENT mark, drops the old table and recreates
  `LOG_QSO_INDEXES`, inside the migration's one transaction. A trigger or
  view on `qso`, a foreign key to it, or a column this program never made
  refuses the migration before any change.

---

## 2. Column classes

Every `qso` column belongs to exactly one class. The class decides who may
write the column and when. The class is the point of this section.

| class | meaning | who writes it |
| --- | --- | --- |
| **IDENTITY** | Which row, which contact, which network QSO. | Minted at insert. Never changed by an edit. |
| **OPERATOR-STATED** | What the operator copied, typed, chose or corrected: the exchange as copied, the band and mode, his X-QSO flag, a delete, his notes. | Logging, an import (the file's statement), Edit QSO. |
| **CAPTURED-AT-LOGGING** | A fact of the moment the QSO was made: what we SENT, our station (`my_*`), the CTY.DAT lookup. These record history. They are never rebuilt from today's settings. | Insert only. Edit QSO may correct them (marked `edited`). Two one-shot migration backfills. |
| **DERIVED-AND-STORED** | The contest's rules applied to the QSO: points, dupe, multipliers, and since schema 10 whether the contest credits the QSO at all. Stored so that a reader never works a rule out. | **Only at a setting point:** a QSO logged (`LOGSUBS2.LogContact` and the store's append), the rescore (`MainUnit.tUpdateLog` through `RescoreLog`), an import, and Edit QSO's save (which ends in `RescoreLog`). |
| **DISTRIBUTION** | What other software has been told. This is not about the contact. | The multi-op link, the UDP sender. |
| **RESERVED** | In the DDL but written by nothing in this build. Always NULL or the default. | Nothing yet. A future writer must add the column to `QSO_COLUMNS`. |

### 2a. The rule for readers (an invariant)

**A reader of a logged QSO reads stored columns and evaluates NO contest rule
at read time.**

Readers include:

- the Cabrillo writer (`PostUnit`, `uCabrillo`)
- the ADIF writer (`uADIF`)
- the log grids, Search and Edit QSO
- the summary sheet, the loader (`LoadinLog`) and the bonus view
- HamScore and UDP XML (`IsClaimedQso`)
- the multi-op resend and restock

Whether a QSO is an X-QSO is answered by
`uContestRegistry.StoredQSOIsXQSO` = `is_xqso OR is_off_contest`. Whether it
counts is answered by `StoredQSOCountsTowardTotals`.

**The only places allowed to evaluate a contest rule are the ones that SET a
derived column:**

- logging (`LogContact`, `uLogStore` appends)
- the rescore
- an import (through the store's append)
- Edit QSO's save
- a record arriving from the network (a peer's edit through `uLogStore`, the
  server's log in `uGetServerLog`)
- the one-shot stamp of a migrated log
- the scoring code those moments run (`uContestBase`, and the multiplier kinds
  in `LOGDUPE`)

**`tr4w/build/Lint-XQSOReads.ps1` enforces this, with two fences:**

1. It fails a code read of `ceXQSO` or `ceOffContest` outside their listed
   owners.
2. It fails a call of the judge routines (`QSOIsOffContest`, `QSOIsXQSO`,
   `LoggedQSOIsXQSO`, `QSOCountsTowardTotals`, `StampOffContest`) outside the
   units that set the stored value.

Known residue, not yet fenced:

- **`TContestBase.CountsTowardBonus`** (a whole-log bonus rule at the final
  score) still asks `QSOIsXQSO` of rows already in the view. The view holds
  only rows the stored value counts, so the two agree. They can differ only
  when the rule changed and the log has not been rescored since.
- **`LOGDUPE`'s multiplier helpers still judge a stored row in two places**:
  `AdditionalDomesticMultipliersBeforeSheet`, which Alt-Y's undelete post
  asks of the row it read, and `MultiplierKindsCredited` inside the replay's
  `Feed`. The replay's own gate reads the stored value. Both helpers agree
  with the stored value except between a rule change and the next rescore.
- **The lint fences by file, not by call path.** The scoring calls in
  `uContestBase` and `LOGDUPE` are allowed because they run at the setting
  points. A new read-time call added inside one of those files would not be
  caught.

### 2b. Why `is_off_contest` is not `is_xqso`

`is_xqso` is the **operator's statement**: the Edit QSO checkbox, or a file
that said `CLAIMEDQSO 0` or `XQSO=Y`. `is_off_contest` is the **contest's
rule** as it was applied:

- off the contest's bands or modes (`UsesBand`, `UsesMode`, `UsesBandInMode`)
- or a worked station the host-area rule does not credit
  (`CreditsWorkedStation`)

They are kept apart so that a rule which changes can **release** a QSO at the
next rescore without erasing the operator's own decision. The stamp never
writes `is_xqso`. Edit QSO shows its box **checked and greyed** when only the
rule says X-QSO, and its save never writes that state into `is_xqso`.

---

## 3. Tables

### 3a. `contest` -- one row (`id = 1`)

The log's identity and its entry declaration, written when the log is made or
migrated from a `.TRW`. Nothing re-reads the declaration from configuration at
export (issue #2).

| column | type | null | default | class | meaning |
| --- | --- | --- | --- | --- | --- |
| `id` | INTEGER PK | | `CHECK (id = 1)` | IDENTITY | there is one row |
| `guid` | TEXT | NOT NULL, UNIQUE | | IDENTITY | the log's own UUIDv7 (32 hex characters) |
| `contest_type` | TEXT | NOT NULL | | IDENTITY | the contest's id (`uContestRegistry.ContestId`; a legacy contest's `ContestTypeSA` spelling) |
| `contest_name` | TEXT | NOT NULL | | IDENTITY | display name |
| `created_at` | INTEGER | NOT NULL | | CAPTURED | Unix UTC seconds |
| `start_time`, `end_time` | INTEGER | null | | RESERVED | nothing writes them yet (Q99) |
| `my_call` | TEXT | NOT NULL | | CAPTURED | the entry declaration's call |
| `category_operator` .. `category_overlay` (nine `category_*`), `club`, `my_park`, `soapbox` | TEXT | null | | CAPTURED | the declaration as made. **Nothing reads the `category_*` columns**; the categories' one home is the `config` table (Q61). |
| `op_name`, `address`, `city`, `state`, `postcode`, `country`, `email` | TEXT | null | | CAPTURED | station identity as declared for this log |

A log created before 2026-10-16 may also carry `last_opened_at` (NULL, never
written or read). It was removed from the DDL without a version bump; see the
note in `uLogSchema.pas`.

### 3b. `qso` -- one row per log record

A record is not always a QSO. `record_kind` is `QSO`, `QTCR`, `QTCS` or
`NOTE`, and several columns mean different things by kind.

| column | type | null | default | class | meaning |
| --- | --- | --- | --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | | | IDENTITY | the row id. Never bound by a writer. |
| `guid` | TEXT | NOT NULL, UNIQUE | | IDENTITY | this row's UUIDv7, always minted |
| `exchange_id` | TEXT | null | | IDENTITY | `ContestExchange.id`. It identifies the EXCHANGE: a county-line contact's rows share it. HamScore's `<ID>`, ADIF `APP_TR4W_ID`. |
| `qso_set_id` | TEXT | NOT NULL | | IDENTITY | which contact the row came from. A single QSO is a set of one. Insert only. |
| `session_id`, `session_seq` | INTEGER | null | | IDENTITY | the multi-op network key (`ceQSOID1`, `ceQSOID2`). (0, 0) means no network identity (an import). |
| `computer_id` | TEXT | null | | IDENTITY | which station logged it (a letter) |
| `operator_id` | INTEGER | null | | IDENTITY | import fidelity only; no live reader |
| `record_kind` | TEXT | NOT NULL | `'QSO'` | IDENTITY | QSO / QTCR / QTCS / NOTE |
| `qso_at` | INTEGER | NOT NULL | | OPERATOR-STATED | Unix UTC seconds |
| `callsign` | TEXT | NOT NULL | | OPERATOR-STATED | the worked call |
| `standard_call` | TEXT | null | | CAPTURED | the resolved call (`QTH.StandardCall`) |
| `freq_tx_hz`, `freq_rx_hz` | INTEGER | NOT NULL | | OPERATOR-STATED | both always set; equal when not split |
| `is_split` | INTEGER | NOT NULL | 0 | OPERATOR-STATED | split stated, never inferred (0 for every `.TRW` import) |
| `band`, `mode` | TEXT | NOT NULL | | OPERATOR-STATED | the enum spellings |
| `submode` | TEXT | null | | OPERATOR-STATED | `ExtendedModeType` |
| `exchange_sent` | TEXT | null | | CAPTURED | what we SENT, verbatim. Insert only; an imported row's STX_STRING. |
| `exchange_received` | TEXT | null | | OPERATOR-STATED | what we COPIED, verbatim |
| `rst_sent`, `rst_received` | INTEGER | null | | OPERATOR-STATED | numeric RST |
| `serial_sent` | INTEGER | null | | CAPTURED | our serial |
| `serial_received` | INTEGER | null | | OPERATOR-STATED | his serial |
| `rcvd_zone`, `rcvd_name`, `rcvd_age`, `rcvd_check`, `rcvd_precedence`, `rcvd_class`, `rcvd_power`, `rcvd_chapter`, `rcvd_prefecture`, `rcvd_member_no`, `rcvd_qth`, `rcvd_random`, `rcvd_kids` | as declared (numbers are INTEGER) | null | | OPERATOR-STATED | the parsed received exchange. These outrank the CTY.DAT columns wherever both exist. |
| `rcvd_year` | INTEGER | null | | OPERATOR-STATED | the received licence year (schema 6). NULL means no year; 0 is the year 00. |
| `random_sent` | TEXT | null | | CAPTURED | random characters we sent |
| `qtc_call` | TEXT | null | | OPERATOR-STATED | for QTC records, the call inside the traffic |
| `domestic_qth` | TEXT | null | | DERIVED-AND-STORED | the corrected QTH (AF1 -> AF-001) |
| `dxcc_prefix`, `dxcc_entity`, `dxcc_code`, `cty_cq_zone`, `cty_continent` | | null | | CAPTURED | CTY.DAT at the time of the QSO, so a later CTY.DAT cannot rewrite history -- at export. **The rescore DOES look the call up again** for a contest with a prefix, zone or DX multiplier (`MainUnit.RecomputeQSOScoring`), so in those contests these are recomputed with the derived columns; its per-record log line reports what changed. |
| `my_county`, `my_grid`, `my_state`, `my_call`, `my_section`, `my_park`, `my_iota`, `my_country`, `my_continent`, `my_cq_zone`, `my_itu_zone` | | null | | CAPTURED | our station for this QSO (schema 3). Insert only, plus Edit QSO (`UpdateQSOMyFacts`). |
| `my_source` | TEXT | null | | CAPTURED | NULL = never captured (a reader falls back to the session). Otherwise `logged`, `assumed` (a peer's QSO stamped with ours), `imported`, `stamped` or `edited`. |
| `year_sent` | INTEGER | null | | CAPTURED | the licence year this QSO sent (schema 8). NULL means sent none. |
| `my_name`, `my_fd_class`, `my_check`, `my_prec`, `my_postal_code`, `my_foc_number` | TEXT | null | | CAPTURED | the rest of our station as typed (schema 9) |
| `mult_domestic`, `mult_dx`, `mult_prefix`, `mult_zone` | INTEGER | null | 0 | DERIVED-AND-STORED | the multiplier outcome as decided |
| `inhibit_mults` | INTEGER | null | 0 | DERIVED-AND-STORED | |
| `prefix_mult`, `dx_mult`, `domestic_mult` | TEXT | null | | DERIVED-AND-STORED | the multiplier strings as counted |
| `qso_points` | INTEGER | null | 0 | DERIVED-AND-STORED | the points. 0 for any X-QSO (`ClearXQSOScoring`). |
| `is_dupe` | INTEGER | null | 0 | DERIVED-AND-STORED | |
| **`is_off_contest`** | INTEGER | **NOT NULL** | **0** | **DERIVED-AND-STORED** | **schema 10: 1 when the contest's own rule refuses this QSO** (off its bands or modes, or the host-area rule): an automatic X-QSO. Set by `uContestRegistry.StampOffContest` only at a setting point. The rescore recomputes it. See section 2b. |
| `my_rover_qth` | TEXT | null | | CAPTURED | **schema 12** (issues 133 and 87): the contest's own place (a county code, a Hawaii district) a ROVER sent this QSO from; NULL when not roving. On the record (`ContestExchange.ceRoverQTH`, offset 331) and UPDATABLE like it. The export sends it in place of MY STATE (`uContestBase.MyStationExchangeWithRoverPlace`); `my_county` of such a row is the ADIF county it lies in (`PostUnit.RoverPlaceADIFCounty`). `my_state` is never the district. |
| `my_sent_unit` | TEXT | null | | CAPTURED | **schema 13** (issues 133 and 87, NY4I 2026-11-20): the contest's own UNIT this QSO was sent from (KIN, ALB, KOH) -- a rover's place, or an in-state party station's MY STATE as sent. The export's sent slot reads it (`uContestBase.MyStationExchangeOfQSO`), so `my_state` holds the host's primary subdivision (NY, HI) and `my_county` the unit's ADIF county (`NY,KINGS`). Set by `PostUnit.ApplyPartyUnitToMyFacts` (the class's `ADIFCountyState`). NULL: the slot sends `my_state`, exactly as every older row. A `QSO_MY_COLUMNS` member. |
| `my_rover_places` | TEXT | null | | CAPTURED | **schema 13** (NY4I 2026-11-20, ruling 6): every place of the rover's operation when the QSO was logged, `/`-joined (KIN/QUE). The Cabrillo and on-air call is `uQsoMyFacts.AssembledCall(my_call, my_rover_places)` (`uLogSource.CabrilloCallFor`); ADIF writes `my_call` alone, which since 13 is the call SETTING as set (VE3FRV/W2), never the places. NULL: `my_call` is signed as stored -- a schema-12 rover row's `my_call` already holds NY4I/KIN/QUE, so it exports unchanged. |
| `is_xqso` | INTEGER | null | 0 | OPERATOR-STATED | the operator's X-QSO, or the file's. Never written by a rule. |
| `is_run` | INTEGER | null | 0 | CAPTURED | `NOT ceSearchAndPounce`. The inversion is deliberate. |
| `is_skipped` | INTEGER | null | 0 | (legacy) | written 0, never read back. A historical 1 is folded into `deleted` on read. |
| `sent_in_qtc` | INTEGER | null | 0 | OPERATOR-STATED | WAE: already sent in a QTC book |
| `name_sent`, `mp3_recorded` | INTEGER | null | 0 | CAPTURED | |
| `clear_dupe_sheet`, `clear_mult_sheet` | INTEGER | null | 0 | OPERATOR-STATED | stream markers the rescore reads back |
| `radio_nr` | INTEGER | null | 1 | CAPTURED | |
| `operator_call` | TEXT | null | | CAPTURED | `ceOperator` |
| `deleted` | INTEGER | null | 0 | OPERATOR-STATED | the one delete flag |
| `notes` | TEXT | null | | OPERATOR-STATED | a NOTE record's text |
| `sent_to_server`, `server_dirty` | INTEGER | null | 0 | DISTRIBUTION | the multi-op server has it / it was edited since |
| `sent_udp`, `udp_dirty` | INTEGER | null | 0 | RESERVED | distribution state not yet wired |
| `rcvd_extra` | TEXT | null | | RESERVED | the JSON escape hatch. **Scoring, multipliers and Cabrillo may NOT read it.** A consumer would need a real column. |

What ordinary updates touch:

- **Insert only:** `guid`, `qso_set_id`, `exchange_sent` and every `my_*`
  column, `year_sent` included (`QSO_MY_COLUMNS`). They are absent from
  `QSO_COLUMNS_UPDATABLE`.
- **Updated:** every other mapped column, `is_off_contest` included. An update
  writes back whatever the record held when it was read, so a QTC mark or a
  delete carries the stored rule back unchanged. Only a setting point
  re-stamps it.

### 3c. `session_state` -- key/value, where the operator left off

| column | type | null | meaning |
| --- | --- | --- | --- |
| `key` | TEXT PK | | |
| `value` | TEXT | NOT NULL | |
| `saved_at` | INTEGER | null | Unix UTC seconds |

The keys:

| key(s) | written by | meaning |
| --- | --- | --- |
| `radio1.band`, `radio2.band`, `radio1.mode`, `radio2.mode`, `radio1.speed`, `radio2.speed` | `LOGDUPE.SaveRestartFile` | each radio's memories |
| `lastCQ.frequency`, `lastCQ.mode` | same | |
| `remainingMultDisplay` | same | |
| `freqMemory.<band>.<mode>` | same | one row per array element, so an added band reads as a default |
| `currentOperator` | same | |
| `configHoldsStatementsOnly` | `uLogContestStatements` | the mark that every contest-scoped `config` row is an operator statement |
| `yearSentBackfillPending` | migration to 8 | the store's one-shot `year_sent` fill (`LOG_YEAR_SENT_BACKFILL_KEY`) |
| `stationFactsBackfillPending` | migration to 9 | the one-shot schema-9 fill (`LOG_STATION_FACTS_BACKFILL_KEY`) |
| `offContestBackfillPending` | migration to 10, and the `.TRW` import | the one-shot `is_off_contest` stamp (`LOG_OFF_CONTEST_BACKFILL_KEY`) |
| `tr4w.writeProbe` | `uLogStore.ProbeAWriteCommits` | a `zeroblob(4096)` row inserted and deleted in ONE transaction, to prove a full disk has space again. It never remains in the table. |

### 3d. `config` -- the contest's settings (what the `.cfg` carried)

| column | type | null | default | meaning |
| --- | --- | --- | --- | --- |
| `command` | TEXT PK | | | the command as spelled in the command vocabulary ("QSO POINT METHOD") |
| `value` | TEXT | NOT NULL | | as text; the parser converts |
| `source` | TEXT | NOT NULL | `'contest'` | `contest` / `station` / `operator`. Load-bearing: the precedence rule reads it. |
| `set_at` | INTEGER | null | | Unix UTC seconds |

For a contest-scoped setting, a row means the operator STATED it. No row
means the contest decides. Main-log column widths are `config` rows
(`COLUMN WIDTH <token>`). Detail: `.claude/agents/log-database.md`.

### 3e. `message` -- function-key memories (Alt-P)

| column | type | null | default | meaning |
| --- | --- | --- | --- | --- |
| `kind` | TEXT | NOT NULL | | `CQ` / `EX` |
| `mode` | TEXT | NOT NULL | | `CW` / `PHONE` |
| `key_id` | TEXT | NOT NULL | | `F1`..`F12`, `AltF1`.., the `KeyId` spelling |
| `text` | TEXT | NOT NULL | | |
| `caption` | TEXT | null | | |
| `edited` | INTEGER | NOT NULL | 0 | schema 4: the operator edited it. Only these rows are restored. |

The primary key is `(kind, mode, key_id)`.

### 3f. `external_delivery` -- durable hand-off to external loggers (schema 5)

The primary key is `(logger, account, logbook, contact)`. `contact` is the
QSO's `guid`. Columns:

- `remote_id`, `revision`, `confirmed_revision`, `payload`,
  `confirmed_payload`, `deleted`
- `state`, one of `pending`, `inflight`, `synced`, `uncertain`, `failed`
- `flight_revision`, `flight_payload`, `flight_deleted`
- `next_attempt`, `error_code`, `request_id`
- `last_sent` (Unix UTC seconds; 0 means never; it arrived inside schema 5)

This table is owned by `src/domain/uExternalDelivery.pas`, and the WRL worker
uses its own connection. DISTRIBUTION class throughout.

### 3g. Indexes

| index | on | why |
| --- | --- | --- |
| `idx_qso_at` | `qso(qso_at)` | time order |
| `idx_qso_callsign` | `qso(callsign)` | |
| `idx_qso_set` | `qso(qso_set_id)` | "what else was this contact" (ADIF export) |
| `idx_qso_exchange` | `qso(exchange_id)` | grouping a county line |
| `idx_qso_dupe` | `qso(callsign, band, mode) WHERE deleted = 0` | |
| `idx_qso_unsent` | `qso(id) WHERE sent_to_server = 0 OR server_dirty = 1` | the multi-op owed rows |
| `idx_qso_unsent_udp` | `qso(id) WHERE sent_udp = 0 OR udp_dirty = 1` | reserved with its columns |
| `idx_external_delivery_pending` | `external_delivery(logger, account, next_attempt) WHERE state = 'pending'` | |
| `idx_external_delivery_contact` | `external_delivery(contact, logger)` | Edit QSO's delivery line |

There is NO index on `(session_id, session_seq)`. This was measured and is
deliberate; see `multi-op-network.md`.

---

## 4. Version history

| version | added | existing rows |
| --- | --- | --- |
| 1 | `contest`, `qso`, `config`, `message`, the `qso` indexes | |
| 2 | `session_state` (replaced the `.RST` restart file) | table created |
| 3 | the `my_*` columns and `my_source` (`LOG_V3_QSO_COLUMNS`) | NULL = never captured; nothing touched |
| 4 | `message.edited` | 0: nothing restored from an old log |
| 5 | `external_delivery` and its indexes; `last_sent` added inside 5 | |
| 6 | `qso.rcvd_year` | carried from `rcvd_zone` for a contest that kept its year there |
| 7 | no shape change: the re-carry | a year contest's `rcvd_year := rcvd_zone`, every row |
| 8 | `qso.year_sent` | marked; **the store fills it once** after set-up |
| 9 | `my_name` .. `my_foc_number` (`LOG_V9_QSO_COLUMNS`) | marked when a row captured a station; **the store fills it once** |
| 10 | `qso.is_off_contest` (`LOG_V10_QSO_OFF_CONTEST_COLUMN`, `INTEGER NOT NULL DEFAULT 0`) | 0, marked when the log holds a QSO; **the store stamps every QSO row once** |
| **11** | **REMOVED** sixteen `qso` columns no build ever wrote or read (`LOG_V11_DROPPED_QSO_COLUMNS`): `snr_sent`, `snr_received`, `rcvd_state`, `rcvd_county`, `rcvd_section`, `rcvd_grid`, `rcvd_continent`, `rcvd_postal_code`, `rcvd_society`, `rcvd_department`, `rcvd_rda`, `rcvd_park`, `rcvd_summit`, `rcvd_iota`, `rcvd_coords`, `cty_itu_zone` (issue 94) | the table is **rebuilt** (section 1); every kept value is copied unchanged. A received QTH of any kind is `rcvd_qth`; `my_*` is our station, `rcvd_*` the worked one. |
| **12** | `qso.my_rover_qth` (`LOG_V12_QSO_ROVER_QTH_COLUMN`, TEXT, last column) | NULL in every existing row, which is the truth (no earlier build roved). ALTER on a schema-11 table; from below 11 the rebuild's new table already has it. No backfill, no mark. |
| **13** | `qso.my_sent_unit`, `qso.my_rover_places` (`LOG_V13_QSO_COLUMNS`, TEXT, last two columns) | NULL in every existing row, meaning "as before": no row is rewritten, and a row's export is unchanged. ALTER on a schema-12 table; from below 11 the rebuild's new table already has them. No backfill, no mark. |

### The stamp-once backfill (schemas 8, 9, 10)

Some added values need the contest to compute them: the year it sends, its
station facts, its band/mode/host-area rule.

`uLogDatabase` is a domain leaf. It cannot see the contest factory, and it
runs before the contest is set up. So the split is:

1. **The migration** adds the column and writes a `session_state` mark, in
   its one transaction.
2. **The store** (`uLogStore.LogStoreApplyContestConfigWith`) runs the
   backfill once the contest is set up and the station is settled. The
   backfill runs on the same open, before anything reads the log.
3. **The backfill and the mark's deletion are one commit.** The backfill is
   idempotent, so a crash between steps 1 and 2 simply runs it again on the
   next open.
4. **A read-only open leaves the mark** for the next writable one.

For schema 10 the backfill is `TLogRepository.BackfillOffContest`, handed
`uContestRegistry.StampOffContest`:

- It reads every QSO row, oldest first. The cursor is closed before any
  write.
- It stamps each row through `LoggedQSOContest`, which is the session's object
  when the row is the session's contest, so the host-area rule is judged with
  the entrant. The store refreshes that object's station first
  (`ActiveContest`).
- It writes 1 for the rows the stamp refuses and 0 for every other row.

That is exactly the question every export asked of the row until schema 10, so
the stamp freezes what was exported. Before the mark is deleted, every row
reads 0.

**A `.TRW` import also writes the schema-10 mark.** Its rows arrive before any
contest is set up, and the binary reader clears the record's byte.

---

## 5. The record and the wire

`ContestExchange` (`src/VC.pas`) is the in-memory record:

- It is **376 bytes**.
- It is read raw from a D7 `.TRW`.
- It is sent raw in the 384-byte multi-op QSO packet.
- It is stored raw in the server's `SERVERLOG.TRW`.

Its fields have been carved one at a time out of the trailing `sReserved`
string, so **no earlier offset ever moves**:

| field | offset | arrived with |
| --- | --- | --- |
| `ceXQSO` | 323 | |
| `RcvdYear` / `RcvdYearKnown` | 324 / 326 | protocol 3 |
| `YearSentKnown` / `YearSent` | 327 / 328 | protocol 4 |
| **`ceOffContest`** | **330** | **schema 10** |
| **`ceRoverQTH`** (`string[10]`) | **331** | **schema 12** |

`sReserved` is now `string[31]` at 342..373 (it was `string[42]` at 331 until schema 12). Bytes 374..375 are padding. The
offsets are pinned by `uTestLogBinaryFile`.

Byte 330 was `sReserved`'s length byte, which is always zero, so every older
record reads `ceOffContest = False`. **No receiver trusts it:**

- The `.TRW` reader clears it.
- A peer's QSO is stamped by THIS station's contest in `LogContact`.
- A peer's edit is stamped in `LogStoreUpdateQSOBySessionIds`.
- A catch-up or an import is stamped in `LogStoreAppendQSOs`.
- A server-log row is stamped as it is read (`uGetServerLog`).

So the network protocol did not change. A QSO from an older station is judged
on arrival exactly as one from a newer station.

---

## 6. How to add a column -- the checklist

1. **Decide its class** (section 2). A DERIVED-AND-STORED column also needs
   its setting points named, and its readers must read the column, not the
   rule.
2. **`uLogSchema.pas`**:
   - Append the column LAST in the `qso` CREATE TABLE, so a migrated table
     matches a new one.
   - Issue #141: no comment-only line between two columns; put the note after
     the last column.
   - Add a `LOG_V<n>_...` `TLogAddedColumn` constant.
   - Bump `LOG_SCHEMA_VERSION` and write the version's paragraph above it.
   - REMOVING a column is not this checklist: it is a rebuild of the table
     (schema 11, `TLogDatabase.RebuildQsoTable`), never `DROP COLUMN`.
   - If existing rows need a contest-computed value, add a `..._BACKFILL_KEY`.
3. **`uLogDatabase.MigrateSchema`**:
   - Ask `pragma_table_info` (and anything else the step needs) BEFORE the
     first change.
   - Then `ALTER TABLE ... ADD COLUMN`, plus the mark, inside the same
     transaction.
4. **`uLogRepository.pas`**: add the column to `QSO_COLUMNS`, to
   `QSO_COLUMNS_UPDATABLE` if it is updatable, to `QSO_PARAMS`, and to
   `TQsoColumn` in the same position (`qc_` plus the exact name). Then add
   `BindRecord` and `ReadRecord`. `TLogRepository.Create` raises on a
   mismatch.
5. **The record**:
   - If the value lives on `ContestExchange`, carve it from `sReserved` (VC.pas)
     without moving an earlier offset.
   - Clear it in `uLogBinaryFile.ReadNext`.
   - Pin the offset in `uTestLogBinaryFile`.
   - Decide what a receiver does with the sender's byte.
6. **A backfill**, if one is needed: a `TLogRepository.Backfill...` that does
   not commit, called from `LogStoreApplyContestConfigWith` after set-up.
   Add it to `TestEveryWriteWaitsForItsCommit` and to that test's
   fingerprint.
7. **Readers and the lint.** A stored flag that has a "derived" twin gets an
   owner list in `Lint-XQSOReads` (or a lint like it), with its self-test
   fixture extended.
8. **Tests**:
   - the round trip (`CompareQSO`, `MakeDistinctQSO`)
   - the migration is ONE commit (`CommitFramesInWal`)
   - an empty log is not marked
   - the backfill runs once
   - `DowngradeTestLog` drops the column and its mark first
   - every pin of `LOG_SCHEMA_VERSION`
9. **Docs**: this file (the table, the class, the version row), the
   `log-database` agent file, and the agents of every area the column touches.

---

## Where the plan document disagrees

`docs/SQLITE_LOG_SCHEMA_PLAN.md` disagrees with the code in these places. The
code wins in each case.

- **Section 4's DDL is a proposal.** The shipped table has `freq_rx_hz NOT
  NULL` plus `is_split`, INTEGER `rcvd_check`/`rcvd_prefecture`/
  `rcvd_member_no`, and many columns section 4 lacks. The plan's own banner
  says so.
- **The plan says the DDL ships as `schema.sql`.** It does not: the DDL is
  `uLogSchema.pas` and nothing else. A later note in the plan itself records
  the departure.
- **The plan's section 13 ("what is built") is stale.**
- **Section 4 shows `PRAGMA user_version = 1`.** The schema is 11.
- **Section 4's DDL lists `snr_*`, the typed `rcvd_*` QTH kinds and
  `cty_itu_zone`.** Schema 11 removed all sixteen (issue 94).
- **`contest.last_opened_at`** is in section 4 and absent from the DDL. It was
  removed in 2026-10-16 with no version bump.
- **Before schema 10, the plan and the agent files described an automatic
  X-QSO as "derived, never stored".** Since schema 10 it is stored
  (`is_off_contest`). The plan's earlier sections are history.
