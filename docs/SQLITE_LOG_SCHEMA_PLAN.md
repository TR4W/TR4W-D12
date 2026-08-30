# The contest log in SQLite — proposed schema

**A proposal for NY4I to verify, 2026-08-29. Nothing has been built.**

Reference: TR4QT at `C:/projects/TR4QT` (`src/data/schema.sql`, `Database.cpp`,
`BackupManager.cpp`). NY4I: *"TR4QT is not necessarily the right way to do it as
it was not a port. So I am open to other ways. But the ideas such as a flat
table structure, guid where IDs are needed, etc apply."*

Read [`DOMAIN_LAYER_SEQUENCE.md`](DOMAIN_LAYER_SEQUENCE.md) first — it settles
*why* this comes second (after display state) and it already contains the
three-tier event-sourcing decision this schema implements.

**All eleven open questions were answered by NY4I on 2026-08-29 — see §11.**
The schema below is therefore a proposal whose decisions are settled; what is
not settled is the code, of which none is written.

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
| 3. per-QSO event | what was **sent**; what was **copied**; my county; my grid | the **`qso` row** |

There is a fourth thing that is not a tier but obeys the same law: values
**derived** at the time of the QSO — DXCC entity, zones and continent from
CTY.DAT. They are stored, never re-derived, and they lose to what was copied
wherever both exist. §4a, which corrects a real mistake in the first draft.

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

Shaped like TR4QT's where there is no reason to differ, purely so the two are
easy to compare. **Not** for interoperability — question 8 settled that a TR4QT
log never has to be readable by us, which is what frees §4a and §4b to diverge
where we have a better answer.

**The header comment below is part of the deliverable, not decoration.** It
ships in `schema.sql` verbatim. NY4I, 2026-08-29: *"make sure in the code you
document the decisions for why a flat record versus a referential one, because
somebody reading this six months from now on GitHub will think we had no
knowledge of what a relational database was."*

```sql
-- ===========================================================================
-- TR4W CONTEST LOG SCHEMA
--
-- WHY THIS IS FLAT AND NOT NORMALISED, since that is the first thing a reader
-- will want to argue with.
--
-- The obvious relational design gives each QSO a set of exchange elements in a
-- child table -- exchange_element(qso_id, key, value) -- because a contest
-- exchange is a variable set of fields and that is what a child table is for.
-- It was considered and rejected. This is a deliberate choice, not an omission.
--
-- WHAT WE MEASURED. TR4W's ExchangeType enum (src/VC.pas) has 61 members, and
-- they are composed from 29 distinct elements. RST appears in 36 of the 61,
-- QTH in 24, serial in 23, and then a long tail: one exchange type each uses
-- the Russian district, the French department, an IARU society, a Ten-Ten
-- number. The set is not open-ended and it is not large. It is 29 columns, and
-- it has been roughly this size for 25 years and 120-plus contests -- the
-- predecessor binary record (ContestExchange) carried about twenty of them as
-- fixed fields and covered every contest TR4W has ever supported.
--
-- WHAT NORMALISING WOULD BUY: adding an exchange element needs no schema
-- migration.
--
-- WHAT IT WOULD COST: every read. A dupe check, a multiplier lookup, the
-- editable log, and Cabrillo export all want a QSO as ONE ROW. Against a child
-- table each becomes a join with a pivot, values lose their types (a zone is an
-- INTEGER in one row and a callsign is TEXT in the next, in the same column),
-- and nothing can be constrained or indexed usefully. That is the EAV pattern.
-- It is a reasonable design when the attribute set is genuinely unbounded or
-- user-defined. Ours is neither: it is enumerated in VC.pas and changes when a
-- new contest is added, which is a code change anyway.
--
-- THE SIZE ARGUMENT DOES NOT APPLY EITHER WAY. A contest log is about 10,000
-- rows at the extreme; the largest in our regression corpus is 78 KB. An
-- unused column costs one byte per row. Neither design would be measurably
-- faster; this is a decision about clarity and correctness, not performance.
--
-- THE ONE HATCH: rcvd_extra is a JSON column for elements we do not model --
-- imported foreign fields, experiments. NOTHING IN SCORING, MULTIPLIERS OR
-- CABRILLO EXPORT MAY READ IT. When something needs to, that is the signal to
-- give the element a real column (ALTER TABLE ADD COLUMN, guarded by
-- PRAGMA table_info -- see the migration note below). If rcvd_extra ever grows
-- a consumer, the rule has been broken and the fix is a column, not a query.
--
-- WHY THERE IS NO multipliers TABLE. It would be a cache of something the qso
-- rows already say, and a cache that can disagree with the log is a contest
-- logger showing the wrong score. Multipliers are derived by query.
--
-- WHY SOME VALUES APPEAR TWICE, as rcvd_* and cty_*: see the block above the
-- rcvd_ columns. Short version -- what the other station SENT and what CTY.DAT
-- guessed from his prefix are different facts, and in a zone contest the sent
-- one is the only correct one.
-- ===========================================================================

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
    -- Written every time the log is OPENED, and it is the chooser's default
    -- sort key: recent activity floats up, not start date (§11b). A contest
    -- resumed on Sunday belongs above one created on Saturday and abandoned.
    last_opened_at    INTEGER,

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
    guid              TEXT NOT NULL UNIQUE,          -- UUIDv7

    qso_at            INTEGER NOT NULL,   -- unix UTC seconds
    callsign          TEXT NOT NULL,

    -- TWO frequencies. Split is not an edge case in a contest, and one column
    -- cannot say "listening 14025, transmitting 14200".
    freq_tx_hz        INTEGER NOT NULL,
    freq_rx_hz        INTEGER,            -- NULL when not split
    band              TEXT NOT NULL,
    mode              TEXT NOT NULL,
    submode           TEXT,

    -- THE RAW COPY, and it is the event source for everything below it.
    exchange_sent     TEXT,               -- what we SENT, verbatim
    exchange_received TEXT,               -- what we COPIED, verbatim

    -- Signal report. RST stays NUMERIC; WSJT-X's dB report gets its own column
    -- rather than being shoehorned into it as '-12'.
    rst_sent          INTEGER,
    rst_received      INTEGER,
    snr_sent          INTEGER,            -- dB, WSJT-X modes
    snr_received      INTEGER,

    -- =====================================================================
    -- COPIED. Parsed out of exchange_received. These OUTRANK the derived
    -- block below wherever both exist -- see 4a.
    -- =====================================================================
    serial_sent       INTEGER,
    serial_received   INTEGER,
    rcvd_zone         INTEGER,            -- CQ **or** ITU: the contest decides
    rcvd_state        TEXT,
    rcvd_county       TEXT,
    rcvd_section      TEXT,               -- ARRL/RAC section
    rcvd_grid         TEXT,
    rcvd_name         TEXT,
    rcvd_age          INTEGER,
    rcvd_check        TEXT,               -- Sweepstakes: 2-digit year
    rcvd_precedence   TEXT,               -- Sweepstakes
    rcvd_class        TEXT,               -- Field Day "2A"
    rcvd_power        TEXT,               -- ARRL DX
    rcvd_chapter      TEXT,
    rcvd_prefecture   TEXT,               -- JA
    rcvd_continent    TEXT,
    rcvd_postal_code  TEXT,
    rcvd_member_no    TEXT,               -- FOC, TenTen, FISTS, club numbers
    rcvd_society      TEXT,               -- IARU
    rcvd_department   TEXT,               -- French
    rcvd_rda          TEXT,               -- Russian district
    rcvd_qth          TEXT,               -- domestic/DX QTH, the catch-all
    rcvd_random       TEXT,               -- random-character exchanges
    rcvd_park         TEXT,               -- POTA
    rcvd_summit       TEXT,               -- SOTA
    rcvd_iota         TEXT,
    rcvd_coords       TEXT,               -- lat/long exchanges
    rcvd_extra        TEXT,               -- JSON. THE NARROW ESCAPE HATCH, 4b

    -- =====================================================================
    -- OURS, at the moment of this QSO (tier 3)
    -- =====================================================================
    my_county         TEXT,
    my_grid           TEXT,
    my_state          TEXT,

    -- =====================================================================
    -- DERIVED from CTY.DAT AT THE TIME OF THE QSO. Stored so a later CTY.DAT
    -- cannot rewrite history -- never re-derived at export, and never used
    -- where the contest carries the value in the exchange (4a).
    -- =====================================================================
    dxcc_prefix       TEXT,
    dxcc_entity       TEXT,
    dxcc_code         INTEGER,
    cty_cq_zone       INTEGER,
    cty_itu_zone      INTEGER,
    cty_continent     TEXT,

    qso_points        INTEGER DEFAULT 0,
    is_dupe           INTEGER DEFAULT 0,
    is_run            INTEGER DEFAULT 0,
    radio_nr          INTEGER DEFAULT 1,
    operator_call     TEXT,
    deleted           INTEGER DEFAULT 0,
    notes             TEXT,

    -- =====================================================================
    -- DISTRIBUTION STATE. Not about the contact -- about what we have told
    -- other software. Precedent: ceSendToServer and ceNeedSendToServerAE.
    -- =====================================================================
    sent_to_server    INTEGER DEFAULT 0,  -- the multi-op server has it
    server_dirty      INTEGER DEFAULT 0,  -- edited since; needs re-sending
    sent_udp          INTEGER DEFAULT 0,  -- the UDP broadcast went out
    udp_dirty         INTEGER DEFAULT 0
);

CREATE INDEX idx_qso_at       ON qso(qso_at);
CREATE INDEX idx_qso_callsign ON qso(callsign);
CREATE INDEX idx_qso_dupe     ON qso(callsign, band, mode) WHERE deleted = 0;

-- The outbound queues are a WHERE clause, not a data structure.
CREATE INDEX idx_qso_unsent   ON qso(id) WHERE sent_to_server = 0 OR server_dirty = 1;
CREATE INDEX idx_qso_unsent_udp ON qso(id) WHERE sent_udp = 0 OR udp_dirty = 1;
```

Differences from TR4QT worth noting, and free to take now that question 8 has
ruled out any need to read a TR4QT log: `contest` is a **single row** with
`CHECK (id = 1)` rather than a table of many contests (question 1: one log per
file);
`my_*` fields are on the QSO; there is no `multipliers` table yet (question 3);
`current_serial` is not stored, because it is `MAX(serial_sent)` and a stored
copy is a second source of truth that can disagree.

---

### 4a. WHAT WAS COPIED OUTRANKS WHAT WAS LOOKED UP

NY4I, 2026-08-29, and this is a **defect in the first draft of §4**, not a
refinement of it. That draft had one `cq_zone` and one `itu_zone` column
labelled *"from CTY.DAT"*, which is wrong in exactly the contests where zones
matter:

- **CQ WW**: the zone is what the other station **sent**. CTY.DAT's zone for his
  prefix is a *guess*, and it is wrong for every station operating away from
  home, every rover, and a good part of Russia and the USA.
- **IARU HF**: the ITU zone is copied, and may be a **society** instead.
- **A QSO party**: county and state are copied. CTY.DAT knows neither.

So the schema now has two clearly separated blocks — `rcvd_*` for what was
parsed out of the exchange, and `cty_*` for what CTY.DAT said at the time — and
one rule:

> **Scoring, multipliers and export read `rcvd_*` when the contest's exchange
> carries that value, and `cty_*` only when it does not.** Which of the two
> applies is a property of the CONTEST, and belongs in the contest definition
> rather than being decided per query.

Both are stored. Neither is re-derived at export. That is the same event-source
principle as §3, applied one level down — and note that **CTY.DAT is itself a
moving target**: it is updated every few weeks, TR4W rewrites it at run time
(hence its `.gitignore` entry), and a DXCC entity can be added, deleted or
re-mapped between a contest and its log check. Re-deriving DXCC at export would
reproduce issue #2 in a second place, with a slower fuse.

`rcvd_zone` is deliberately **one** column, not two. A contest asks for one
zone; which kind it is, is a property of the contest, and storing a CQ zone in
an ITU column would be the same category error in reverse. The verification
found the live code has the matching bug from the other direction: `MyZone` is
a single global doing double duty for CQ and ITU, `MY ITU ZONE` is read by no
export path, and it is why the `iaru_hf` corpus divergence will not close by
event sourcing alone (§12a).

### 4b. Flat, or something cleverer? — flat, with one narrow hatch

NY4I: *"the more and more things we get into, I wonder if the flat record is
going to cause us some issues… maybe we do a hybrid."*

Measured before answering. `ExchangeType` (`VC.pas:3412`) has **61 members**,
and they are composed from **29 distinct elements**:

| element | in N exchange types | | element | in N |
|---|---:|---|---|---:|
| RST | 36 | | Precedence | 2 |
| QTH (domestic/DX) | 24 | | FOC number | 2 |
| QSO number | 23 | | Class | 1 |
| Grid | 10 | | Kids | 1 |
| Name | 9 | | TenTen | 1 |
| Zone | 5 | | Continent | 1 |
| Age | 4 | | POTA park | 1 |
| Prefecture | 3 | | Member number | 1 |
| Power | 3 | | Postal code | 1 |
| Check | 2 | | Random characters | 1 |
| Chapter | 2 | | Society | 1 |
| Coordinates | 2 | | French department | 1 |
| | | | RDA | 1 |

**The flat design is not a proposal, it is the thing that already works.**
`ContestExchange` carries about twenty of these as fixed fields and has covered
120-plus contests for twenty-five years. Twenty-nine columns is nothing to
SQLite — the cost of a column you do not use is one NULL byte per row, and at
ten thousand rows the whole concern disappears (§9a).

The alternative — an `exchange_element(qso_id, key, value)` side table — buys
"adding a field needs no migration" and pays for it in every query, every
export, every dupe check, and all type safety. It is the EAV pattern, and it is
how a log that reads in one statement becomes one that reads in a join with a
pivot.

**So: flat, plus exactly one escape hatch — `rcvd_extra`, a JSON column.** The
rule for it has to be written down or it becomes a dumping ground:

- A new exchange element gets a **real column** the moment a contest we support
  uses it. Adding a column is `ALTER TABLE ADD COLUMN` guarded by
  `PRAGMA table_info` (§8) — cheap, and SQLite does it without rewriting the
  table.
- `rcvd_extra` is for **imported foreign fields we do not model** and for
  experiments that have not earned a column yet. Nothing in scoring, multipliers
  or Cabrillo export may read it. If something needs to, that is the signal to
  promote it.

SQLite's `json_extract()` can even index into it, which is the temptation to
resist rather than the feature to use.

**This reasoning ships in the schema, not only here.** The DDL in §4 opens with
it, and that comment is part of the deliverable — a reader who meets
`schema.sql` on GitHub in six months must find the argument at the point of
contact, not be left to assume nobody here knew what third normal form was.
Same rule for the units that carry it: the one that owns the schema, and the
one that reads `rcvd_extra`, each restate the part that constrains them. This
tree already works that way — `uCrashLogLCL`, `uServerLogForm` and the resource
block in `tr4w.lpr` all explain themselves where the reader arrives, and each of
those comments exists because someone otherwise "fixed" the thing they describe.

**Worth doing while the list is in front of us:** the 29 elements above come
from the *names* of the exchange types. The authoritative list of what is
actually parsed and stored is `ContestExchange` plus the arms of
`ProcessExchange`, and the two should be reconciled field by field before the
DDL is final — that is a mechanical pass over `LOGSTUFF.PAS` and
`uCabrilloExchange.pas`, and it is the sort of thing that is done once properly
or wrong forever.

### 4c. Sending it to the network

NY4I: *"we also need to have some information in this record about has it been
sent to the network and has it been sent via UDP already… I suspect we'll send a
JSON record, but that's got to be pretty fast. So I think I just more have a
JSON record of the items that are changed."*

**The flags.** Precedent exists and is worth copying exactly, because it already
encodes the hard part. `ContestExchange` has `ceSendToServer` — the multi-op
server has this QSO — *and* `ceNeedSendToServerAE`, set when a QSO is **edited**
(`uEditQSO.pas:748`). Two booleans, not one: "sent" and "sent, but has changed
since". A single flag cannot express a QSO that was delivered and then corrected,
which is precisely the case a multi-op needs to get right.

UDP has **no such flag today** — that is the gap. So four columns, two per
transport, as in §4.

The outbound queue is then a `WHERE` clause with a partial index on it, not a
data structure to maintain — which is also §9a's rule.

**The wire format.** A delta rather than a whole record is the right instinct,
and the GUID is what makes it safe: `{"guid": "...", "rcvd_state": "MA"}` is
unambiguous about which QSO it patches, in a way that `{serial: 41}` is not once
two stations are logging. Three things to settle when that work starts, flagged
here so the schema does not foreclose them:

1. **A delta needs a version or a sequence**, or two edits racing between
   stations resolve by arrival order, which is not the same as by time.
2. **Deletion is an edit**, not an absence — `deleted = 1` travels as a patch.
3. The existing binary protocol with CRC32
   (`src/utils/networkmessageutils.pas`) is what `tr4wserver` speaks today.
   Whether the delta rides inside it or replaces it is a networking decision,
   not a schema one — but the schema should not assume either.


---

### 4d. `ContestExchange` is PERSISTED, not replaced

The most important scoping decision in this plan, and it is NY4I's:

> *"Let's not make light of the fact that ContestExchange is everywhere in the contest logic of this
> program. So changing that is a pretty significant undertaking, and that of anything is probably a
> candidate for a shim more than anything else. Ultimately we might get rid of it."*

Measured 2026-08-29: **430 references across 34 units.**

| unit | refs | | unit | refs |
|---|---:|---|---|---:|
| `trdos/LOGSTUFF.PAS` | 94 | | `uExternalLogger` | 19 |
| `MainUnit` | 60 | | `uHamScore` | 12 |
| `trdos/LOGSUBS2.PAS` | 36 | | `trdos/LOGEDIT.PAS` | 11 |
| `trdos/LOGDUPE.PAS` | 34 | | `uNet` | 10 |
| `uADIF` | 32 | | `uEditQSO` | 8 |
| `tr4wserverUnit` | 32 | | `trdos/PostUnit.PAS` | 7 |

It is not a data structure the log happens to use. It is the currency the contest engine is written
in — dupe checking, scoring, exchange parsing, ADIF and Cabrillo export, the multi-op server wire
format, and the editable log all speak it.

**So the SQLite work does not touch it.** What gets built is a mapper at the storage boundary:

```
    ContestExchange  <-- one function -->  a row in qso
```

Read a row, fill a record, hand it to the engine unchanged. Take a record, write a row. Everything
above the mapper carries on exactly as it does today, and the 430 sites are not edited.

**This is the pattern this tree has already used twice and it is recorded as the model** — CLAUDE.md
on the radio and CW keyer factories: *"thin adapters over the existing globals first, prove the seam
on hardware, then delete the legacy path."* Same shape here: adapter first, prove it against the
golden corpus, and only then consider whether the record becomes an object.

Three consequences worth being explicit about:

1. **The DDL stays close to the record's fields on purpose.** A mapper that is a column-per-field
   assignment is one that can be read and checked; a clever one is where a silent field drop hides.
   §4a's `rcvd_*` split is the one place the schema deliberately says more than the record does, and
   it says more because the record is missing the fact — not because the mapping got creative.
2. **`ContestExchange` becoming a class is the CONTEST FACTORY's job, not this one.**
   `DOMAIN_LAYER_SEQUENCE.md` already places it there: *"it is where `ContestExchange` becomes an
   object."* That is phase 3. This is phase 2, and conflating them would put a 430-site refactor
   inside a storage change.
3. **The binary format outlives the record's use as a persistence format**, because the importer
   still has to read it — years of operator `.trw` files and the corpus fixtures. That is why the
   32/64-bit layout measurement in `ROADMAP.md` §3 matters even though the record is on its way out:
   the importer may well be a 64-bit build.


---

### 4e. The class — wanted, and where its `Save` should live

NY4I, 2026-08-29:

> *"From an object-oriented standpoint I really do like the idea of ContestExchange essentially
> becoming a class, and one of the functions of that class is persist, or write to the database, and
> that handles the writing to the database. Same with reading it in."*

Agreed as the destination, and it is consistent with how this tree already does its best work —
CLAUDE.md calls the radio and CW-keyer factories *"genuine OOP subsystems"* and the model for what
comes next. Two things to settle so the class arrives well rather than early.

#### The hazard: a record and a class do not behave the same, and Pascal will not tell you

This is the single biggest risk in the whole plan, and it is invisible to the compiler.

```pascal
   var a, b: ContestExchange;   // RECORD  -- b := a COPIES
   b := a;  b.Callsign := 'W1AW';          // a is untouched

   var a, b: TContestExchange;  // CLASS   -- b := a ALIASES
   b := a;  b.Callsign := 'W1AW';          // a CHANGED TOO
```

Every one of the 430 sites that assigns, copies or stashes a `ContestExchange` changes meaning, and
none of them produces a diagnostic. `ZeroMemory(@TempRXData, SizeOf(ContestExchange))`
(`MainUnit.pas:3522`) stops meaning what it says. `SizeOf` as a file-offset multiplier stops working
at all. The corpus would catch some of it; aliasing bugs in dupe checking and scoring are exactly
the kind that pass 22 byte-diffs and then go wrong in a contest.

That is the argument for the shim in §4d — not that the class is wrong, but that it is a **separate
change from adding a database**, and doing both at once means a storage bug and an aliasing bug
arriving in the same commit with no way to tell them apart.

#### The strongest argument for the class is one the codebase already makes

NY4I: *"there's such value in having those records all be classes, because then the class can be
self-aware on if it's been edited, and it can go ahead and persist itself to the database."*

**That is the best argument in this section, and the evidence is already in the tree.**
`ContestExchange` carries `ceNeedSendToServerAE` — "this QSO was edited after the server got it" —
and it is set **by hand, at exactly one site**: `uEditQSO.pas:748`. Every other path that could
modify a QSO has to remember. §4c adds three more flags of the same kind (`server_dirty`,
`sent_udp`, `udp_dirty`), and each one is another thing a future edit path must not forget.

A record cannot know it was written to. An object can:

```pascal
   procedure TContestExchange.SetCallsign(const aValue: string);
   begin
      if FCallsign = aValue then Exit;
      FCallsign := aValue;
      FDirty    := True;          // cannot be forgotten
   end;
```

That deletes a whole class of silent defect — the edit that never reaches the multi-op server
because someone added a code path and did not set a boolean. So: **yes to the class, and yes to it
being self-aware.** The only question left is where the SQL goes.

#### The names, so the next discussion is shorter

NY4I: *"no doubt what I'm describing is some particular pattern name, I just don't know the name of
it — it's just the way I've done it for years."* It is three, all from Fowler's *Patterns of
Enterprise Application Architecture*:

| what | name | who else uses it |
|---|---|---|
| an object that wraps a row and carries its own `Save`/`Load` | **Active Record** | Rails, Django |
| the object knowing it has been modified since load | **dirty tracking**, the core mechanism of **Unit of Work** | most ORMs |
| a separate object moving data between class and database, class knows no SQL | **Data Mapper** | **TR4QT** — `struct QSO` + `QSORepository` |

So the choice below is the classic Active Record versus Data Mapper trade, and it is a real trade:
Active Record wins on ergonomics and on the dirty-flag argument above; Data Mapper wins on layering
and on being able to unit-test scoring without a database.

What this section recommends is the common hybrid — the entity keeps `Save` and the dirty flag,
`Save` delegates to a repository. It has no crisp Fowler name; it is usually described as a rich
domain model with an injected repository.

#### Where `Save` should live: the class delegates, it does not embed SQL

Two shapes, and the difference matters more than it looks:

| | Active Record | Data Mapper |
|---|---|---|
| shape | `Qso.Save` opens/uses the connection itself | `Repo.Save(Qso)`; the class knows no SQL |
| domain purity | the domain type depends on SQLite | the domain type depends on nothing |
| testing | needs a database to test scoring | scoring is testable with a plain object |
| our lint | `Lint-DomainPurity` bans LCL and Windows in `src/domain/`; a type that reaches SQLite is the same coupling one layer over | passes it by construction |
| TR4QT does | — | **this** — `QSORepository`, `ContestRepository` |

Recommended, and it gives NY4I the method he wants without the coupling:

```pascal
   // the class HAS a Save. It does not CONTAIN the SQL.
   procedure TContestExchange.Save;
   begin
      FRepo.Store(Self);        // injected; the repository owns the statement
   end;
```

The call site reads as asked — `Qso.Save` — while the SQL, the prepared statements and the
connection stay in one unit that can be swapped for a test double. It also keeps §9b's rule intact:
one connection and one set of prepared statements, owned by the repository, not created per object.

#### So the order stands

1. **Phase 2, this document:** the record, persisted through a mapper. No semantics change, 430
   sites untouched, and the corpus stays a valid oracle across the move — which is the whole reason
   it survives the migration.
2. **Phase 3, the contest factory:** `TContestExchange` becomes a class, with `Save`/`Load`
   delegating to the repository the mapper already is. `DOMAIN_LAYER_SEQUENCE.md` already puts the
   record-to-object move there, and by then the storage is proven and any aliasing defect has only
   one possible cause.

The mapper written in phase 2 is not thrown away by phase 3. It **becomes** the repository.


---

### 4f. Is the in-memory log a `TList<TContestExchange>`?

NY4I's follow-on: *"if it's a class, should the in-memory log simply be a TList of ContestExchange
objects?"* — and then, rightly: *"it's probably worth taking a look at TR4QT and seeing how it did
it."*

#### What TR4QT actually does

Read 2026-08-29. It answers in three parts, and it does not all point one way:

| | TR4QT |
|---|---|
| the QSO type | `struct QSO` — `src/models/QSO.h:37`. A plain **value** type, not a class |
| does it persist itself? | **No.** `QSORepository::saveQSO(QSO& qso, int contestId)` — Data Mapper, as §4e recommends |
| the in-memory log | `QList<QSO> loadedQSOs` — `src/controllers/ContestManager.h:57`. **The whole log, held open** |

So NY4I's instinct matches the reference on the *collection* and not on the *class*: TR4QT keeps a
full in-memory list of every QSO and passes it by const-reference —
`QSOLogger::logQSO(const Input&, const QList<QSO>& existingQSOs)` dupe-checks against the list rather
than querying the database.

**And the price of that choice is visible in the same codebase.** There is a whole
`DataIntegrityManager` whose job is reconciling the two copies, and its signature names the problem:

```cpp
    QString fullIntegrityCheck(const QList<QSO>& memoryQSOs, bool criticalOnly);
```

`memoryQSOs`, checked against the database. That class exists because the list and the table can
disagree — the cost §9a predicts, made concrete. It also carries a `rescore` that recalculates
points, dupe status and multiplier flags across the whole contest, precisely because derived values
in memory drift from what the rows imply.

#### What to take, and what to leave

**Take the struct and the repository.** A value type that knows nothing about the database,
persisted by something else, is the shape that survives §4e's aliasing hazard *and* keeps scoring
testable without a database. Note this is TR4QT agreeing with §4d twice over: its QSO is a value
type like our record, and it is not an Active Record.

**Leave the full mirror**, unless a measurement demands it — and if it is ever adopted, adopt the
integrity manager with it, because TR4QT needed one. A copy that can disagree with the log is a
contest logger showing the wrong score, which is the same reason §11/3 refused a `multipliers`
table.

#### So: as a result set yes, as "the log" no

The difference is lifetime, not type.

| use | shape | why |
|---|---|---|
| a query result — one band, a browser page | `TObjectList<TContestExchange>` | built, read, freed. Cannot drift: it does not outlive the question |
| rows visible in the editable log | a small window buffer | bounded by `LVS_NOSCROLL`; re-read on change (§11a) |
| the whole log, held open | **no** | that is the mirror, and it brings an integrity manager with it |

Three practical notes if a list is used:

- **`TObjectList<T>`, not `TList<T>`.** With records, freeing the list was the whole job; with
  classes a `TList` frees the pointers and leaks every object. `TObjectList` and `OwnsObjects` make
  you answer the ownership question a record never asked.
- **`Generics.Collections` needs `{$MODE Delphi}`**, which `tr4w.inc` already sets tree-wide — worth
  knowing before someone reaches for `fgl`.
- **The virtual list wants O(1) by index** (§11a's `OnData` asks for row *N*). A `TObjectList` gives
  it, and it only has to hold the visible window rather than ten thousand rows.

**One honest caveat.** A full in-memory list is not absurd here: 10,000 records at ~400 bytes is
about 4 MB, and dupe and multiplier checks are the hottest paths in the program. If a measurement
ever shows a query per keystroke is too slow, a bounded cache is the answer — with the measurement
attached, per §9a's rule that the exception is justified by a number and not by a fear.


---

## 5. Identity — GUIDs

A GUID per QSO and per contest, `TEXT`, separate from the `INTEGER PRIMARY KEY`.
The row id is a local detail; the GUID is what survives export, import, and — the
real reason — **multi-op merge**. Today `tr4wserver` reconciles logs by serial
number and callsign; a stable per-QSO identity makes "did I already have this
QSO" answerable without heuristics.

**Decided: UUIDv7** (NY4I, question 5). v7 is time-ordered, so an index on it
stays local rather than scattering, and it sorts by creation. FPC has no v7
generator built in; it is about fifteen lines (48-bit unix millis + 74 random
bits), and it wants a unit test that asserts monotonicity across a tight loop —
two v7s generated in the same millisecond must still order correctly.

It is also what makes a future backup **merge** possible (§11, question 7):
"which QSOs does this backup not have" is answerable exactly, by GUID, rather
than by guessing from serial and callsign.

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
(`BackupManager.cpp:262`). This replaces today's single overwritten destination
(`LOGSTUFF.PAS:5405`, `CopyFileA` with `bFailIfExists = False`).

**And `Restore` is half the reason to use this API at all** — NY4I called it the
more important half, and today there is no restore path of any kind. Same unit,
same safety, opposite direction:

```pascal
function Restore(FileName: string; Destination: TSQLite3Connection;
                 LockUntilFinished: boolean = true;
                 DestinationDBName: string = 'main'): boolean;
```

See §11 question 7 for what has to surround it: detection, letting the operator
choose a backup by timestamp and QSO count, and moving the damaged database
aside rather than overwriting it.

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

## 9b. Connection lifecycle — confirmed

NY4I asked to confirm this, and it is worth stating in the plan because getting
it wrong is a classic way to make SQLite look slow.

**One connection per open log, created once.** `TSQLite3Connection` and its
`TSQLTransaction` are created when a log is opened and destroyed when it closes.
The database path is set once, at that moment. Nothing re-opens the file per
QSO, per query, or per screen refresh.

**Queries are created as needed** — but the two on the hot path are created
once and **prepared**, then re-executed with parameters:

```pascal
// once, when the log opens
FInsertQso.SQL.Text := 'INSERT INTO qso (guid, qso_at, callsign, ...) ' +
                       'VALUES (:guid, :qso_at, :callsign, ...)';
FInsertQso.Prepare;

FDupeCheck.SQL.Text := 'SELECT 1 FROM qso WHERE callsign = :call ' +
                       'AND band = :band AND mode = :mode AND deleted = 0 LIMIT 1';
FDupeCheck.Prepare;

// per QSO / per keystroke
FInsertQso.ParamByName('callsign').AsString := aCall;
FInsertQso.ExecSQL;
```

That is the whole performance story, and it is why §9a can say "do not build a
cache" without hand-waving: a prepared statement against an indexed column is
one B-tree descent. Re-assigning `SQL.Text` on every call throws the prepared
plan away and re-parses the SQL, which is the mistake that makes people conclude
they need a cache.

Three consequences worth writing down:

- **A connection belongs to one thread.** The backup decision in §6
  (`LockUntilFinished = True`, on the logging thread) is consistent with this.
  If a backup ever moves to a worker it needs its own connection, and then it is
  the restarting case §6 describes.
- **`TSQLTransaction` is not optional.** SQLdb requires one; without an explicit
  `Commit` the writes sit in a transaction that is rolled back when the object
  dies. Commit policy — per QSO, or batched — is a real decision, and per QSO is
  the right default for a contest log: an operator who loses power should lose
  at most the QSO in progress.
- **The chooser (§11b) is the exception** and opens many databases briefly. Those
  are separate, short-lived, read-only connections and are not this connection.


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

## 11. Decisions — answered by NY4I, 2026-08-29

All eleven settled. Recorded here so the DDL above and any later argument have
one place to point at.

| # | question | decision |
|---|---|---|
| 1 | one database per contest, or many per file? | **one log per file.** The single-row `contest` table with `CHECK (id = 1)` in §4 stands |
| 2 | where do the files live? | **`target/`, as today.** `%LOCALAPPDATA%` has merit but consistency with what we already do wins |
| 3 | multipliers stored or derived? | **derived.** No `multipliers` table |
| 4 | timestamp format | **INTEGER, and always UTC** |
| 5 | GUID version | **UUIDv7** |
| 6 | frequency unit | **Hz** — the lowest granularity needed |
| 7 | backup trigger and generations | see below — the important half is RESTORE |
| 8 | must a TR4QT log be readable by us? | **no.** TR4QT is a reference, not an interop target |
| 9 | what happens to `.trw`? | **import only** |
| 10 | delete `sqlite3.def`? | **already deleted** |
| 11 | `TDBGrid` for View / Edit Log? | **agreed** — §11a |

Two of these change §4 as written: nothing about the schema, but 8 removes the
last reason to stay shaped like TR4QT where we have a better answer, and 3
confirms the `multipliers` table stays out.

### 7 in full — backup, generations, and the restore that does not exist

**What happens today, verified rather than recalled.** `SaveLogFileToFloppy`
(`LOGSTUFF.PAS:5405`) does

```pascal
Windows.CopyFileA(TR4W_LOG_FILENAME, TR4W_FLOPPY_FILENAME, False)
```

— `bFailIfExists = False`, so it **overwrites one destination file**. It is
driven by two `csJSON` settings, `BACKUP LOG FILE NAME` and
`BACKUP LOG FREQUENCY` (`uCFG.pas:498-499`), and does nothing at all when the
name is empty. The DOS heritage is in the routine's name: this is the floppy
backup. NY4I's description — *"it's just backing up, it overwrites the backup
file"* — is exactly right.

Note what that means alongside §6: **the current backup is a plain file copy of
a live file**, which is precisely the mechanism SQLite's own documentation warns
can yield a corrupt backup if the machine loses power mid-copy. Moving to the
online backup API fixes a real hazard that exists today, not a hypothetical one.

**Generations: yes, but they are the easy half.** Timestamped names and a
rotation count, taken from TR4QT's `BackupManager` (`listBackups`,
`rotateBackups`) which already does newest-first ordering and delete-beyond-N.
One setting for how many to keep.

**Restore is the half that does not exist, and NY4I named it as the more
important one.** Today there is no path from a backup back into the live log at
all — the operator would close TR4W and copy a file by hand, and would have to
know which file. So this is new design, not a port, and the pieces are:

1. **Detection.** `PRAGMA integrity_check` and `foreign_key_check` on open (§7),
   and a QSO-count comparison after each backup. An integrity failure must be
   **reported and actionable**, never silently repaired — consistent with this
   tree's standing rule.
2. **Choosing.** The operator has to see what the candidates are: each backup's
   timestamp and its QSO count. TR4QT already computes the second
   (`getBackupQSOCount`, counting `WHERE deleted = 0`) which is exactly the
   number an operator can recognise — "the one from 14:32 with 812 QSOs".
3. **Restoring.** `TSQLite3Backup.Restore(FileName, Destination)` — the same
   API in the other direction, so the copy back is as safe as the copy out.
4. **Not losing the damaged file.** A restore must move the suspect database
   aside, not overwrite it. The QSOs it still holds may be the newest ones, and
   a merge may be possible later; a restore that destroys the evidence turns a
   recoverable afternoon into a lost one.
5. **When.** At minimum on demand. Offering it automatically at startup when the
   integrity check fails is the case that actually helps an operator at 03:00
   in a contest — that is the moment the feature is for.

**Open, and deliberately not decided here:** whether a restore should attempt to
MERGE the surviving rows of the damaged log into the restored one. It is
attractive — GUIDs make "which QSOs does the backup not have" answerable
exactly — and it is also the kind of thing that quietly does the wrong thing at
the worst moment. My recommendation is to ship restore-and-set-aside first, and
treat merge as a separate feature with its own tests. Flagging it now because
the GUID decision (5) is what makes it possible later, and is one more reason
that decision is right.


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
the editing.** Agreed by NY4I, question 11.

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

---

## 11b. The log chooser — a requirement that has been waiting for this

NY4I, 2026-08-29: *"one of the things TR4QT does which is nice is that it
displays a chooser with information about the databases… it still would be nice
to say the name and the contest, the date, maybe the number of QSOs, maybe the
callsign used… clicking on the date column would make it so they can find the
last one."*

**This is already a written requirement, and it has been blocked on exactly this
work.** `docs/NEW_CONTEST_DIALOG_DESIGN_BRIEF.md` lists as **Tier 1**:

| feature | note in the brief |
|---|---|
| Database-backed list (no filesystem browser) | kill `[..]` and absolute paths |
| Columned existing-contest grid (Name/Type/Date/Ver) | *"From TR4QT"* |
| Clickable sortable columns | *"Enables recent"* |
| "Last Opened" column / sort key | *"Recent activity floats up, not start date"* |
| Delete / manage existing contests | *"From TR4QT"* |

And the current LCL dialog says so itself, in the comment above `PopulateFiles`
(`uNewContestForm.pas:244-262`), explaining why it settled for a plain list:

> *"The one thing it cannot do — show columns read from INSIDE each .cfg, which
> is the brief's Tier 1 — no filesystem browser can do either, **because that
> needs the contest database**."*

So this is not a new idea to evaluate; it is the feature that motivated part of
the brief, and the schema has to serve it.

### Is opening every database unreasonable? No.

NY4I: *"I suspect it'd be pretty fast."* It is, and the reason is structural
rather than lucky:

- Opening a SQLite file is **lazy** — it reads the header and the schema, not
  the data.
- Everything the chooser wants except the QSO count is **one row**, because
  `contest` is a single-row table (question 1): `SELECT contest_name,
  contest_type, my_call, start_time, created_at, last_opened_at FROM contest`.
- The count is `SELECT COUNT(*) FROM qso WHERE deleted = 0`, which the partial
  index in §4 already serves.

That is two trivial statements per file. At a hundred saved logs it is on the
order of a tenth of a second, once, when the dialog opens — and a contester with
a hundred logs is already unusual. If it ever did become slow the answer is to
fill the count column asynchronously, not to cache metadata in a sidecar file
that can drift from the log it describes (§9a).

### What the schema owes it

One addition to the `contest` row, which the brief asks for and the draft did
not have:

```sql
    last_opened_at    INTEGER,   -- unix UTC; written when the log is OPENED
```

"Last opened" rather than "created" is deliberate and the brief is explicit
about why: *recent activity floats up, not start date*. A contest resumed on
Sunday morning should sort above one created on Saturday and abandoned.

The schema version for the "Ver" column is free — `PRAGMA user_version` (§8).

### Two things it must get right

**A bad file must not break the dialog.** One corrupt, truncated, locked or
foreign `.db` in the directory has to render as a row that says so, not as an
exception that stops the chooser listing the other ninety-nine. This is the same
fail-visibly rule as everywhere else in this tree.

**It is the natural place to surface an integrity problem.** The chooser already
has to open every database; `PRAGMA quick_check` is cheap enough to run there,
so a damaged log can be marked in the list **before** an operator opens it and
starts logging into it. That is also where the restore path from §11/7 wants to
be offered — the operator is already looking at a list of logs with dates and
QSO counts, which is exactly the information needed to choose a backup.



---

## 12. Findings from the event-source verification

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
