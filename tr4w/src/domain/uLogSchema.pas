{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 }

{ ===========================================================================
  TR4W CONTEST LOG SCHEMA -- the DDL, and the reasoning behind its shape.

  Settled in docs\SQLITE_LOG_SCHEMA_PLAN.md; all eleven open questions were
  answered by NY4I on 2026-08-29.  This unit is the SINGLE SOURCE of the DDL.
  The plan document described it shipping as a separate schema.sql; it does not,
  and that is deliberate -- a .sql file plus a Pascal copy is two definitions of
  one thing, and this tree has been bitten by exactly that often enough to have
  a rule about it (CLAUDE.md: "copies drift, and the drift is invisible").
  The reasoning below is what the .sql file existed to carry, and it carries it
  here, where the code that executes it can be read beside it.

  WHY THIS IS FLAT AND NOT NORMALISED, since that is the first thing a reader
  will want to argue with.  NY4I asked for this to be written down where it
  will be found: "somebody reading this six months from now on GitHub will
  think we had no knowledge of what a relational database was."

  The obvious relational design gives each QSO a set of exchange elements in a
  child table -- exchange_element(qso_id, key, value) -- because a contest
  exchange is a variable set of fields and that is what a child table is for.
  It was considered and REJECTED.  This is a deliberate choice, not an omission.

  WHAT WE MEASURED.  TR4W's ExchangeType enum (src\VC.pas) has 61 members, and
  they are composed from 29 distinct elements.  RST appears in 36 of the 61,
  QTH in 24, serial in 23, and then a long tail: one exchange type each uses the
  Russian district, the French department, an IARU society, a Ten-Ten number.
  The set is not open-ended and it is not large.  It is 29 columns, and it has
  been roughly this size for 25 years and 120-plus contests -- the predecessor
  binary record (ContestExchange) carried about twenty of them as fixed fields
  and covered every contest TR4W has ever supported.

  WHAT NORMALISING WOULD BUY: adding an exchange element needs no schema
  migration.

  WHAT IT WOULD COST: every read.  A dupe check, a multiplier lookup, the
  editable log and Cabrillo export all want a QSO as ONE ROW.  Against a child
  table each becomes a join with a pivot, values lose their types (a zone is an
  INTEGER in one row and a callsign is TEXT in the next, in the same column),
  and nothing can be constrained or indexed usefully.  That is the EAV pattern.
  It is a reasonable design when the attribute set is genuinely unbounded or
  user-defined.  Ours is neither: it is enumerated in VC.pas and changes when a
  new contest is added, which is a code change anyway.

  THE SIZE ARGUMENT DOES NOT APPLY EITHER WAY.  A contest log is about 10,000
  rows at the extreme; the largest in our regression corpus is 78 KB.  An unused
  column costs one byte per row.  Neither design would be measurably faster;
  this is a decision about clarity and correctness, not performance.

  THE ONE HATCH: rcvd_extra is a JSON column for elements we do not model --
  imported foreign fields, experiments.  NOTHING IN SCORING, MULTIPLIERS OR
  CABRILLO EXPORT MAY READ IT.  When something needs to, that is the signal to
  give the element a real column.  If rcvd_extra ever grows a consumer, the rule
  has been broken and the fix is a column, not a query.

  WHY THERE IS NO multipliers TABLE.  It would be a cache of something the qso
  rows already say, and a cache that can disagree with the log is a contest
  logger showing the wrong score.  Multipliers are derived by query (question 3).

  WHY SOME VALUES APPEAR TWICE, as rcvd_* and cty_*: what the other station SENT
  and what CTY.DAT guessed from his prefix are different facts, and in a zone
  contest the sent one is the only correct one.  The copied value OUTRANKS the
  derived one wherever both exist.

  EVENT SOURCING IS THE POINT, NOT A FEATURE.  Nothing on the contest row is
  re-read from configuration at export: that is TR4W-D12 issue #2.  Two of the
  four corpus known-divergences are this defect
  (tr4w\test\corpus\known-divergences.txt), and storing what was SENT per QSO is
  their fix.  Note the trap recorded there: MyZone is one global serving both
  the CQ and the ITU zone, so storing "MyZone" would store the wrong number.
  Store what was sent.

  THE CONTEST CONFIGURATION LIVES HERE TOO, AND THE .cfg FILE GOES AWAY.
  NY4I, 2026-09-01: "the configuration info for a database should go into the
  database file too. That includes anything that goes into the .CFG file
  including Program Messages (Alt-P)... when done, the .cfg file should not be
  necessary."  That was always the destination -- CLAUDE.md has said since
  2026-08-21 that the contest .cfg is exempt from the JSON move because it is
  going to an SQLite3 contest file -- and this is what it means concretely.

  AND config IS KEY/VALUE, WHICH IS THE OPPOSITE OF WHAT THE ESSAY ABOVE ARGUES
  FOR THE EXCHANGE.  Both are right, and the difference is the whole point:

    the QSO exchange   a FIXED, ENUMERATED set (61 exchange types built from 29
                       elements, VC.pas), each with a type, each joined,
                       filtered, indexed and exported.  Columns.
    the configuration  ALREADY a key/value store.  CommandsArray IS the parser:
                       every key is an editable "command" with no cross-key
                       invariant and no validation, nothing joins on a config
                       key, and it is read once at load.  A key/value table is
                       not a compromise here, it is the honest shape.

  Applying the column argument to configuration would give 415 columns that
  nothing queries; applying the key/value argument to the exchange gives EAV on
  the hot path.  The test is not "which pattern is nicer", it is whether the set
  is enumerated AND queried.

  DO NOT DERIVE "WHAT IS CONTEST-SCOPED" FROM crC: 1.  Measured 2026-09-01: 29
  of the 415 CFGCA rows carry crC: 1, and that byte means "SaveNewContest writes
  this", NOT "this belongs to a contest".  The shipped Idaho QSO Party .cfg sets
  EXCHANGE RECEIVED, DOMESTIC MULTIPLIER, QSO POINT METHOD, MULT BY BAND and
  CONTEST TITLE -- and ALL FIVE ARE crC: 0.  They are what makes a contest a
  contest, and a design that took the 29 as the definition would drop the
  exchange, the multiplier rule and the scoring while looking principled.

  The reader has always accepted any of the 415; only the writer is narrow.  So
  config holds WHATEVER THE CONTEST SETS, which is the other reason it cannot be
  columns.

  WHY config CARRIES A source COLUMN, since a key/value table usually should
  not.  uCFG.pas implements station-defaults <- contest-overrides: "AN EXPLICIT
  CONTEST .cfg LINE BEATS THE STORED VALUE, while that contest is loaded", and
  LEADING ZEROS is the live example -- six real contest configs set it and a
  serial-number contest must not be overruled by a station preference.  That
  rule is currently implemented by NOTICING A LINE IN THE FILE.  Delete the file
  and the signal goes with it unless the database records where the value came
  from.  source is that signal, and it is load-bearing rather than metadata.

  THE COMMENTS INSIDE THE CREATE STATEMENTS ARE NOT DECORATION EITHER.  SQLite
  keeps the CREATE text verbatim in sqlite_master, so they survive into every
  log file -- someone opening a .db in a SQLite browser five years from now
  reads them without this repository.  Comments BEFORE a statement do not
  survive, which is why the essay above is a Pascal comment and the per-column
  notes are not.
  =========================================================================== }
unit uLogSchema;

{$I ..\tr4w.inc}

interface

const
   { PRAGMA user_version in every log we create.  Bump ONLY with a migration
     step, and read docs\SQLITE_LOG_SCHEMA_PLAN.md section 8 first: an added
     column is ALTER TABLE ADD COLUMN guarded by PRAGMA table_info, not a
     rebuild. }
   LOG_SCHEMA_VERSION = 1;

   { EXECUTED IN ORDER, ONE STATEMENT PER ELEMENT.

     An array rather than one script split on ';' -- splitting SQL on a
     semicolon is a parser pretending not to be one, and it breaks silently the
     first time a literal or a trigger body contains one.  There is no reason to
     take that risk to save a few brackets. }
   { ANSISTRING, NOT string.  sqldb's ExecuteDirect and TSQLQuery.SQL.Text are
     AnsiString, and tr4w.inc makes a plain `string` UTF-16 -- so declaring
     these as `string` means a narrowing conversion on every statement, which
     the build's narrowing ceiling counts and which would be silently lossy if
     any of this were ever not ASCII.  SQL keywords and our own column names
     are ASCII by construction, so AnsiString is both correct and free. }
   LOG_SCHEMA_STATEMENTS: array[0..8] of AnsiString = (

      { ONE ROW.  This is the log's own identity and its entry declaration,
        frozen when the log is created (tier 2). }
      'CREATE TABLE contest ('#10 +
      '    id                INTEGER PRIMARY KEY CHECK (id = 1),'#10 +
      '    guid              TEXT NOT NULL UNIQUE,'#10 +
      '    contest_type      TEXT NOT NULL,      -- our ContestType, as a token'#10 +
      '    contest_name      TEXT NOT NULL,'#10 +
      '    created_at        INTEGER NOT NULL,   -- unix UTC'#10 +
      '    start_time        INTEGER,'#10 +
      '    end_time          INTEGER,'#10 +
      '    -- Written every time the log is OPENED, and it is the chooser''s'#10 +
      '    -- default sort key: recent activity floats up, not start date. A'#10 +
      '    -- contest resumed on Sunday belongs above one created on Saturday'#10 +
      '    -- and abandoned.'#10 +
      '    last_opened_at    INTEGER,'#10 +
      '    -- tier 2: the entry declaration, as sent in the Cabrillo header.'#10 +
      '    -- NEVER re-read from configuration at export -- that is issue #2.'#10 +
      '    my_call           TEXT NOT NULL,'#10 +
      '    category_operator TEXT,'#10 +
      '    category_assisted TEXT,'#10 +
      '    category_power    TEXT,'#10 +
      '    category_band     TEXT,'#10 +
      '    category_mode     TEXT,'#10 +
      '    category_station  TEXT,'#10 +
      '    category_time     TEXT,'#10 +
      '    category_transmitter TEXT,'#10 +
      '    category_overlay  TEXT,'#10 +
      '    club              TEXT,'#10 +
      '    my_park           TEXT,               -- POTA: constant for a whole log'#10 +
      '    soapbox           TEXT,'#10 +
      '    -- tier 2: station identity AS DECLARED FOR THIS LOG. Copied from the'#10 +
      '    -- JSON identity at creation; edited here it does not disturb the'#10 +
      '    -- next contest.'#10 +
      '    op_name           TEXT,'#10 +
      '    address           TEXT,'#10 +
      '    city              TEXT,'#10 +
      '    state             TEXT,'#10 +
      '    postcode          TEXT,'#10 +
      '    country           TEXT,'#10 +
      '    email             TEXT'#10 +
      ')',

      'CREATE TABLE qso ('#10 +
      '    id                INTEGER PRIMARY KEY AUTOINCREMENT,'#10 +
      '    -- The record ALREADY carries a per-QSO GUID: ContestExchange.id,'#10 +
      '    -- set by GetGUID, read back on ADIF import and emitted by HamScore'#10 +
      '    -- as <ID>. Import preserves it rather than inventing a second one.'#10 +
      '    guid              TEXT NOT NULL UNIQUE,'#10 +
      '    -- THE MULTI-OP NETWORK IDENTITY, and it is a PAIR. ceQSOID1 is the'#10 +
      '    -- program start time and ceQSOID2 is GetTickCount; tr4wserver'#10 +
      '    -- matches a record on BOTH, and WAE links a QTC to its QSO through'#10 +
      '    -- the second. Kept because it is how two stations agree that two'#10 +
      '    -- rows are the same contact.'#10 +
      '    session_id        INTEGER,'#10 +
      '    session_seq       INTEGER,'#10 +
      '    -- WHICH STATION LOGGED IT. A single letter in a multi-op network,'#10 +
      '    -- and the thing that tells each program whether a QSO is its own or'#10 +
      '    -- a foreign one. PostUnit also derives the Cabrillo transmitter'#10 +
      '    -- digit from it. Dropping it would break multi-op silently.'#10 +
      '    computer_id       TEXT,'#10 +
      '    operator_id       INTEGER,            -- no live reader; kept for import fidelity'#10 +
      '    -- A LOG RECORD IS NOT ALWAYS A QSO: rkQSO, rkQTCR, rkQTCS, rkNote.'#10 +
      '    -- Several columns below mean different things depending on this.'#10 +
      '    record_kind       TEXT NOT NULL DEFAULT ''QSO'','#10 +
      '    qso_at            INTEGER NOT NULL,   -- unix UTC seconds'#10 +
      '    callsign          TEXT NOT NULL,'#10 +
      '    -- TWO frequencies. Split is not an edge case in a contest, and one'#10 +
      '    -- column cannot say "listening 14025, transmitting 14200".'#10 +
      '    freq_tx_hz        INTEGER NOT NULL,'#10 +
      '    freq_rx_hz        INTEGER,            -- NULL when not split'#10 +
      '    band              TEXT NOT NULL,'#10 +
      '    mode              TEXT NOT NULL,'#10 +
      '    submode           TEXT,'#10 +
      '    -- THE RAW COPY, and it is the event source for everything below it.'#10 +
      '    exchange_sent     TEXT,               -- what we SENT, verbatim'#10 +
      '    exchange_received TEXT,               -- what we COPIED, verbatim'#10 +
      '    -- Signal report. RST stays NUMERIC; WSJT-X''s dB report gets its own'#10 +
      '    -- column rather than being shoehorned into it as ''-12''.'#10 +
      '    rst_sent          INTEGER,'#10 +
      '    rst_received      INTEGER,'#10 +
      '    snr_sent          INTEGER,            -- dB, WSJT-X modes'#10 +
      '    snr_received      INTEGER,'#10 +
      '    -- COPIED. Parsed out of exchange_received. These OUTRANK the derived'#10 +
      '    -- block below wherever both exist.'#10 +
      '    serial_sent       INTEGER,'#10 +
      '    serial_received   INTEGER,'#10 +
      '    rcvd_zone         INTEGER,            -- CQ **or** ITU: the contest decides'#10 +
      '    rcvd_state        TEXT,'#10 +
      '    rcvd_county       TEXT,'#10 +
      '    rcvd_section      TEXT,               -- ARRL/RAC section'#10 +
      '    rcvd_grid         TEXT,'#10 +
      '    rcvd_name         TEXT,'#10 +
      '    rcvd_age          INTEGER,'#10 +
      '    rcvd_check        TEXT,               -- Sweepstakes: 2-digit year'#10 +
      '    rcvd_precedence   TEXT,               -- Sweepstakes'#10 +
      '    rcvd_class        TEXT,               -- Field Day "2A"'#10 +
      '    rcvd_power        TEXT,               -- ARRL DX'#10 +
      '    rcvd_chapter      TEXT,'#10 +
      '    rcvd_prefecture   TEXT,               -- JA'#10 +
      '    rcvd_continent    TEXT,'#10 +
      '    rcvd_postal_code  TEXT,'#10 +
      '    rcvd_member_no    TEXT,               -- FOC, TenTen, FISTS, club numbers'#10 +
      '    rcvd_society      TEXT,               -- IARU'#10 +
      '    rcvd_department   TEXT,               -- French'#10 +
      '    rcvd_rda          TEXT,               -- Russian district'#10 +
      '    rcvd_qth          TEXT,               -- domestic/DX QTH, the catch-all'#10 +
      '    rcvd_random       TEXT,               -- random-character exchanges'#10 +
      '    random_sent       TEXT,               -- ...and the ones we sent'#10 +
      '    -- ContestExchange.Kids IS OVERLOADED BY record_kind, so it becomes'#10 +
      '    -- TWO columns. For rkQSO it is the Kids-exchange text; for rkQTCR /'#10 +
      '    -- rkQTCS it is the callsign INSIDE the QTC traffic, which is not the'#10 +
      '    -- station in the callsign column. One column meaning either,'#10 +
      '    -- depending on another column, is how a wrong Cabrillo line gets'#10 +
      '    -- written two years from now.'#10 +
      '    rcvd_kids         TEXT,'#10 +
      '    qtc_call          TEXT,'#10 +
      '    rcvd_park         TEXT,               -- POTA'#10 +
      '    rcvd_summit       TEXT,               -- SOTA'#10 +
      '    rcvd_iota         TEXT,'#10 +
      '    rcvd_coords       TEXT,               -- lat/long exchanges'#10 +
      '    rcvd_extra        TEXT,               -- JSON. THE NARROW ESCAPE HATCH.'#10 +
      '                                          -- Scoring, multipliers and'#10 +
      '                                          -- Cabrillo MAY NOT read it.'#10 +
      '    -- OURS, at the moment of this QSO (tier 3). These are the only'#10 +
      '    -- things that can change WITHIN one log -- a rover.'#10 +
      '    my_county         TEXT,'#10 +
      '    my_grid           TEXT,'#10 +
      '    my_state          TEXT,'#10 +
      '    -- DERIVED from CTY.DAT AT THE TIME OF THE QSO. Stored so a later'#10 +
      '    -- CTY.DAT cannot rewrite history -- never re-derived at export, and'#10 +
      '    -- never used where the contest carries the value in the exchange.'#10 +
      '    dxcc_prefix       TEXT,'#10 +
      '    standard_call     TEXT,               -- QTH.StandardCall, the resolved call'#10 +
      '    dxcc_entity       TEXT,'#10 +
      '    dxcc_code         INTEGER,'#10 +
      '    cty_cq_zone       INTEGER,'#10 +
      '    cty_itu_zone      INTEGER,'#10 +
      '    cty_continent     TEXT,'#10 +
      '    -- THE MULTIPLIER OUTCOME, AS DECIDED AT THE TIME. This is not the'#10 +
      '    -- multipliers TABLE that section 11/3 refused -- there is still no'#10 +
      '    -- such table and multiplier COUNTS are derived by query. These are'#10 +
      '    -- per-QSO facts of exactly the same kind as qso_points: what the'#10 +
      '    -- contest rules concluded about this contact when it was logged.'#10 +
      '    mult_domestic     INTEGER DEFAULT 0,'#10 +
      '    mult_dx           INTEGER DEFAULT 0,'#10 +
      '    mult_prefix       INTEGER DEFAULT 0,'#10 +
      '    mult_zone         INTEGER DEFAULT 0,'#10 +
      '    inhibit_mults     INTEGER DEFAULT 0,'#10 +
      '    -- The multiplier STRINGS as counted, which is not the same as the'#10 +
      '    -- literal the operator copied (rcvd_qth) nor the CTY.DAT lookup.'#10 +
      '    prefix_mult       TEXT,               -- WPX prefix; NOT QTH.Prefix from CTY.DAT'#10 +
      '    dx_mult           TEXT,'#10 +
      '    domestic_mult     TEXT,'#10 +
      '    domestic_qth      TEXT,               -- the CORRECTED QTH: AF1 -> AF-001 in IOTA'#10 +
      '    qso_points        INTEGER DEFAULT 0,'#10 +
      '    is_dupe           INTEGER DEFAULT 0,'#10 +
      '    -- is_run is ceSearchAndPounce INVERTED. S&P is the opposite of run,'#10 +
      '    -- and a mapper that copies it straight across is wrong in a way'#10 +
      '    -- nothing reports.'#10 +
      '    is_run            INTEGER DEFAULT 0,'#10 +
      '    -- NOT deleted. The contact happened and stays in the log for the'#10 +
      '    -- other station''s NIL protection, but is not claimed: excluded from'#10 +
      '    -- the QSO count, multipliers, points and dupe checking. Folding this'#10 +
      '    -- into deleted would change what a submitted log claims.'#10 +
      '    is_xqso           INTEGER DEFAULT 0,'#10 +
      '    is_skipped        INTEGER DEFAULT 0,  -- read by the scoring paths'#10 +
      '    sent_in_qtc       INTEGER DEFAULT 0,  -- WAE: already sent in a QTC book'#10 +
      '    name_sent         INTEGER DEFAULT 0,'#10 +
      '    mp3_recorded      INTEGER DEFAULT 0,  -- an MP3 exists on disk for this QSO'#10 +
      '    -- STREAM MARKERS, not UI state: a record can say "the dupe sheet'#10 +
      '    -- was cleared here", and rescoring reads it back.'#10 +
      '    clear_dupe_sheet  INTEGER DEFAULT 0,'#10 +
      '    clear_mult_sheet  INTEGER DEFAULT 0,'#10 +
      '    radio_nr          INTEGER DEFAULT 1,'#10 +
      '    operator_call     TEXT,'#10 +
      '    deleted           INTEGER DEFAULT 0,'#10 +
      '    notes             TEXT,'#10 +
      '    -- DISTRIBUTION STATE. Not about the contact -- about what we have'#10 +
      '    -- told other software. Precedent: ceSendToServer, ceNeedSendToServerAE.'#10 +
      '    sent_to_server    INTEGER DEFAULT 0,  -- the multi-op server has it'#10 +
      '    server_dirty      INTEGER DEFAULT 0,  -- edited since; needs re-sending'#10 +
      '    sent_udp          INTEGER DEFAULT 0,  -- the UDP broadcast went out'#10 +
      '    udp_dirty         INTEGER DEFAULT 0'#10 +
      ')',

      'CREATE INDEX idx_qso_at       ON qso(qso_at)',
      'CREATE INDEX idx_qso_callsign ON qso(callsign)',
      'CREATE INDEX idx_qso_dupe     ON qso(callsign, band, mode) WHERE deleted = 0',

      { The outbound queues are a WHERE clause, not a data structure. }
      'CREATE INDEX idx_qso_unsent     ON qso(id) WHERE sent_to_server = 0 OR server_dirty = 1',
      'CREATE INDEX idx_qso_unsent_udp ON qso(id) WHERE sent_udp = 0 OR udp_dirty = 1',

      { EVERYTHING THE CONTEST .cfg USED TO CARRY.  When this is populated the
        .cfg is no longer necessary, which is the stated goal. }
      'CREATE TABLE config ('#10 +
      '    -- The command exactly as CFGCA spells it -- "QSO POINT METHOD",'#10 +
      '    -- "EXCHANGE RECEIVED". That spelling is the contract with the'#10 +
      '    -- existing parser and with every .cfg an operator already has, so'#10 +
      '    -- it is the key rather than some tidier invented identifier.'#10 +
      '    command   TEXT PRIMARY KEY,'#10 +
      '    -- TEXT for every command regardless of its CFGCA type. The parser'#10 +
      '    -- already converts from text (that is what reading a .cfg IS), so'#10 +
      '    -- storing a typed value would mean converting twice and having two'#10 +
      '    -- places that disagree about what "TRUE" means.'#10 +
      '    value     TEXT NOT NULL,'#10 +
      '    -- WHERE THIS VALUE CAME FROM. Not metadata -- the precedence rule'#10 +
      '    -- depends on it. An explicit contest setting outranks the station'#10 +
      '    -- default (uCFG.pas), and with no .cfg file left there is nothing'#10 +
      '    -- else to tell the two apart.'#10 +
      '    --   contest  set for THIS contest; beats the station default'#10 +
      '    --   station  copied from the station config when the log was made'#10 +
      '    --   operator changed here, in this log, by the operator'#10 +
      '    source    TEXT NOT NULL DEFAULT ''contest'','#10 +
      '    set_at    INTEGER'#10 +
      ')',

      { THE PROGRAM MESSAGES -- Alt-P.  A real table and not config rows,
        because they are structured and the editor wants them by (mode, key):
        FunctionKeyMemoryArray is array[CW..Phone, F1..AltF12] (LogCW.pas:56),
        two of them, CQMemory and EXMemory. }
      'CREATE TABLE message ('#10 +
      '    -- CQMemory or EXMemory: which of the two arrays this is.'#10 +
      '    kind      TEXT NOT NULL,           -- ''CQ'' | ''EX'''#10 +
      '    mode      TEXT NOT NULL,           -- ''CW'' | ''PHONE'''#10 +
      '    -- ''F1''..''F12'', ''AltF1''..''AltF12'' -- KeyId''s spelling, which is'#10 +
      '    -- what AppendConfigFile already writes into a .cfg today as'#10 +
      '    -- "CQ MEMORY F1 = ..." (LogCW.pas:1366).'#10 +
      '    key_id    TEXT NOT NULL,'#10 +
      '    text      TEXT NOT NULL,'#10 +
      '    -- The button label. A separate string in the program'#10 +
      '    -- (SetCQCaptionMemoryString), so it is a separate column.'#10 +
      '    caption   TEXT,'#10 +
      '    PRIMARY KEY (kind, mode, key_id)'#10 +
      ')'
   );

implementation

end.
