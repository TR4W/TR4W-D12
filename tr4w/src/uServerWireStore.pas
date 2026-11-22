unit uServerWireStore;

{$I tr4w.inc}

(*
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
*)

(*
  THE TR4WSERVER LOG AS ITS OWN SQLITE DATABASE -- stage W2 of
  docs/TR4WSERVER_SQLITE_DESIGN.md section 13 (issues 300 and 341). The rules
  the Python server follows too are section 13.6 of that note.

  WHAT THIS IS. A store whose unit of storage is a TWireValues, one value per
  column of the multi-op wire (uWireQso, uQsoColumns), and whose questions are
  the ones uServerLogStore's TServerLogStore asks of the flat file: hold a run,
  insert a QSO unless the server already has it, rewrite the newest copy of an
  edited QSO, does it hold this one, clear, set the clear flags, the largest
  serial, the count -- and, in place of the byte-exact image the sync port used
  to stream, ReadAll: every row in arrival order from one read transaction.

  SINCE W3+W5 (2026-11-22) THIS IS THE SERVER'S LOG: tr4wserverUnit stores,
  relays and clears through it (uServerWireFrames decides what to do with a
  message), and the sync port streams its ReadAll. SERVERLOG.TRW and the flat
  file store (uServerLogStore) are gone.

  A LEAF in the server's sense: no window, no Indy, no server state. It uses the
  contest log's CONNECTION LAYER (uLogDatabase.TLogDatabase.OpenWithoutIdentity:
  the busy timeout, synchronous = FULL, WAL, read back) and nothing of the
  station's schema, repository or identity check.

  THE SCHEMA (13.6): meta(key, value) holding schema_version; qso(seq INTEGER
  PRIMARY KEY AUTOINCREMENT, then the wire's columns in column order, each
  INTEGER or TEXT with the column's DEFAULT); a NON-unique index on guid. The
  file is stamped with PRAGMA application_id = WIRE_STORE_APPLICATION_ID ('TR4S',
  not the station's 'TR4W') and is named *.tr4wsrv, so the station's Open dialog
  (which scans for .db) and its VerifyIdentity can never take it for a contest.

  IDENTITY IS THE guid COLUMN. The old pair (ceQSOID1, ceQSOID2) is the station's
  session_id / session_seq, which are LOCAL columns that never reach the wire
  (uQsoColumns), so guid -- the row's own UUIDv7 -- is the only per-row identity
  the wire carries. An EMPTY guid is the old (0, 0): it names nothing, so it is
  stored every time, is never "held", and an edit carrying one changes nothing
  (it used to rewrite the newest (0, 0) record, which was a guess). Uniqueness is
  enforced IN THE INSERT, inside the transaction (INSERT ... SELECT ... WHERE NOT
  EXISTS), never by a UNIQUE index: a log restocked from several stations may
  legitimately hold repeats the server has not judged (design 5.2).

  NULL AND ''. Canonical text makes NULL and '' the same value on the wire, so
  the store stores '' as NULL in EVERY column and reads NULL back as ''. A numeric
  column is bound as an Int64 and a text column as text, so the string "0" stays
  text. Text is UTF-8 bytes, bound and read byte for byte whatever the program's
  default code page is.

  DURABILITY. WAL with synchronous = FULL: a COMMIT that returned is on disk. An
  insert outside a hold is committed before it returns, so a caller that
  acknowledges after Insert has acknowledged a durable QSO. INSIDE A HOLD the row
  is committed at Release, not at Insert: an ACK sent before Release is an ACK
  for a row that is not yet durable, so W3 MUST ACK a held run after Release.
  A failure inside a held run rolls back the WHOLE run (SQLite may already have
  ended the transaction itself on a full disk), ends the hold and is reported
  through OnWriteFailed; the rows of the run before the failing one are then not
  stored. That is the price of one transaction per run; the server still relays,
  as it always has, and the next station to link restocks.

  THREADS. One connection, owned by the thread that calls everything except
  ReadAll -- the main thread, as the server's writes always are. ReadAll opens a
  connection of its own (read-only, one transaction) and touches only the file
  name and the column list, so the sync port's Indy thread may call it while
  the main thread writes: it sees what is COMMITTED, as one snapshot (design
  6.2's hazard fixed by construction).
*)

interface

uses
   SysUtils,
   Classes,
   Log4D,
   uWireQso,
   uLogDatabase;

const
   (* THE SERVER DATABASE'S SCHEMA VERSION, in meta('schema_version'). Bumped
     whenever the table's shape changes in a way an older file cannot be read
     as. A file carrying another number is REFUSED, never adopted (13.6). It is
     independent of NET_PROTOCOL_VERSION; W3 may decide to tie them. *)
   WIRE_STORE_SCHEMA_VERSION = 1;
   (* 'TR4S': not the station's 'TR4W' ($54523457). *)
   WIRE_STORE_APPLICATION_ID = $54523453;
   (* NOT .db, which the station's Open dialog scans for contests. *)
   WIRE_STORE_EXTENSION = '.tr4wsrv';
   (* The meta key holding the version. *)
   WIRE_STORE_META_VERSION = 'schema_version';

type
   (* WHAT Initialize FOUND. *)
   TWireStoreInit = (
      wsiReady,         (* open, schema present or created, ready for use *)
      wsiCannotOpen,    (* the file could not be opened or created *)
      wsiRefused);      (* a file that is not this server's, of another schema
                           version, with other columns, or damaged: left untouched *)

   (* WHAT Insert DID. *)
   TWireInsert = (
      wiStored,         (* a new row *)
      wiDuplicate,      (* the identity is already held: nothing written *)
      wiRejected,       (* the values are not a row of this schema: nothing written,
                           and not a failure of the disk *)
      wiFailed);        (* the write failed; OnWriteFailed was called *)

   (* The action ClearFlags takes on every QSO row. *)
   TWireFlagAction = (
      wfaSetClearDupesheet,   (* clear_dupe_sheet := 1 *)
      wfaClearMults);         (* clear_mult_sheet := 1; the four mult flags := 0 *)

   TWireRows = array of TWireValues;

   TWireStoreReasonEvent = procedure(const aReason: string);
   TWireStoreNoticeEvent = procedure;
   TWireStoreCountEvent = procedure(aCount: integer);

   TServerWireStore = class(TObject)
   private
      FColumns: TWireColumns;
      FFileName: string;
      FDb: TLogDatabase;
      FHeld: boolean;
      FCount: integer;
      FGuidIndex: integer;
      FInsertPlain: string;
      FInsertIfAbsent: string;
      FUpdateNewest: string;
      FSelectAll: string;
      procedure BuildStatements;
      procedure Report(const aFormat: string; aLevel: integer; const aArgs: array of const);
      procedure BeginWrite;
      procedure EndRead;
      procedure FailWrite(E: Exception; const aWhat: string);
      procedure ReportWritten;
      procedure NoteCount;
      function ApplySchema: boolean;
      function Judge(aDb: TLogDatabase; out aFresh: boolean; out aWhy: string): boolean;
      function ScalarText(aDb: TLogDatabase; const aSql: string): string;
      function ReadCount: integer;
      function RowsValid(const aValues: TWireValues): boolean;
      procedure BindRow(aQuery: TObject; const aValues: TWireValues);
   public
      (* A write failed (the reason), a write worked, and the number of QSOs the
        store holds changed. Called where the server always made the same calls;
        any may be nil. *)
      OnWriteFailed: TWireStoreReasonEvent;
      OnWritten: TWireStoreNoticeEvent;
      OnCountChanged: TWireStoreCountEvent;
      (* The server's logger; nil in a test. *)
      Logger: TLogLogger;

      (* aColumns: the wire's columns (uQsoColumns.QsoWireColumns), shared and
        never freed here. It must name guid, record_kind, serial_sent,
        clear_dupe_sheet, clear_mult_sheet and the four mult_ flags: the store
        raises EWireQsoError at once if one is missing, so a schema change that
        drops one cannot go unnoticed until a QSO arrives. *)
      constructor Create(aColumns: TWireColumns; const aFileName: string);
      destructor Destroy; override;

      (* Open the database, creating it (schema, version, application id) when
        the file is missing or is an empty SQLite file. An existing file is
        first examined READ-ONLY, so a file that is not ours is refused without
        one byte of it written. aWhy names the reason for anything but wsiReady. *)
      function Initialize(out aWhy: string): TWireStoreInit;

      (* Keep one transaction open across a run of OFFLINEQSO packets. Release
        commits it; it does nothing when no hold is in force. See DURABILITY. *)
      procedure Hold;
      (* True when no run was held or its commit worked. FALSE when the commit
        failed: the whole run was rolled back, so a caller that was about to
        ACK the run's rows must not (13.6 rule 11). *)
      function Release: boolean;

      (* THE CONTEST THIS SERVER'S LOG HOLDS (13.7 ruling 4): meta('contest'),
        the contest id string the FIRST accepted station announced in its HELLO.
        RememberContest stores aId only when none is stored and aId is not empty
        (False when nothing was stored for any reason but "already set").
        ForgetContest is for Clear-all-logs: a cleared log starts a new contest.
        Both are main-thread calls, like every write. *)
      function Contest: string;
      function RememberContest(const aId: string): boolean;
      procedure ForgetContest;

      (* A DATED COPY OF THE DATABASE, taken BEFORE a clear (design D9): VACUUM
        INTO from a connection of its own, so it holds every committed row
        including the -wal's, which a plain file copy would miss. The
        destination must not exist. aWhy names the failure. *)
      function BackupTo(const aDestination: string; out aWhy: string): boolean;

      (* Store a row unless its identity is already held. *)
      function Insert(const aValues: TWireValues): TWireInsert;
      (* Rewrite the NEWEST row with this identity as the whole of aValues (last
        writer wins, no edit counter). False when the store could not be read or
        the row not written; True otherwise, INCLUDING WHEN NO ROW HAS THE
        IDENTITY (an edit of a QSO the server never held is relayed and not
        stored, as it always was; design 6.4) and when the identity is empty. *)
      function UpdateNewest(const aValues: TWireValues): boolean;
      (* Does the store hold this identity? False for '' and for a store that
        cannot be read. *)
      function Holds(const aGuid: string): boolean;
      (* Remove every QSO. False when it could not be done. *)
      function Clear: boolean;
      (* Set the clear-dupesheet flag, or clear the multiplier flags, on every
        row of record_kind QSO. False when the store holds no row or the write
        failed. *)
      function ClearFlags(aAction: TWireFlagAction): boolean;
      (* The largest serial_sent (0 for none; NULL, the old -1, counts as none).
        False when it could not be read. *)
      function MaxNumberSent(out aMax: integer): boolean;
      (* The number of rows, or -1 when it could not be read. *)
      function Count: integer;
      (* EVERY ROW IN ARRIVAL ORDER (seq), from one read transaction on a
        connection of its own. Callable from any thread. False when it could
        not be read. *)
      function ReadAll(out aRows: TWireRows): boolean; overload;
      (* The same, and the stored contest read in the SAME snapshot, so the sync
        stream's header cannot disagree with its rows. *)
      function ReadAll(out aRows: TWireRows; out aContest: string): boolean; overload;

      property FileName: string read FFileName;
      property Columns: TWireColumns read FColumns;
      (* What the write connection reports (journal_mode, synchronous) so a test
        and the server's log can say it. Empty / -1 before Initialize. *)
      function JournalMode: string;
      function Synchronous: integer;
   end;

(* THE CREATE TABLE of the qso table for aColumns, exactly as Initialize runs it:
  seq, then every column in order, INTEGER or TEXT, with DEFAULT when the
  column's default is not ''. Public so a test can compare it with columns.json
  and the Python server can be held to the same rule (13.6). *)
function WireStoreCreateTable(aColumns: TWireColumns): string;
(* The CREATE INDEX statement for the identity. *)
function WireStoreCreateIndex: string;

implementation

uses
   db,
   sqldb;

const
   (* A code page number, not the unit that names it: UTF-8. *)
   CODE_PAGE_UTF8 = 65001;
   (* SQLite's primary result codes for "not a database" and "malformed". *)
   SQLITE_CORRUPT_PRIMARY = 11;
   SQLITE_NOTADB_PRIMARY = 26;
   LEVEL_WARN = 1;
   LEVEL_ERROR = 2;
   LEVEL_INFO = 0;

   (* The columns the store's own statements name. *)
   META_CONTEST = 'contest';
   COL_GUID = 'guid';
   COL_KIND = 'record_kind';
   COL_SERIAL = 'serial_sent';
   COL_DUPE = 'clear_dupe_sheet';
   COL_MULT_SHEET = 'clear_mult_sheet';
   NEEDED_COLUMNS: array[0..8] of string = (
      COL_GUID, COL_KIND, COL_SERIAL, COL_DUPE, COL_MULT_SHEET,
      'mult_domestic', 'mult_dx', 'mult_prefix', 'mult_zone');

(* --------------------------------------------------------------------------- *)
(* the DDL -- one definition, read by the store and by the tests                  *)
(* --------------------------------------------------------------------------- *)

(* A DEFAULT as an SQL literal. The quote is doubled by hand:
  SysUtils.StringReplace is AnsiString in FPC 3.2.2. *)
function SqlLiteral(aNumeric: boolean; const aValue: string): string;
var
   i: integer;
begin
   if aNumeric then
      begin
      Result := aValue;
      Exit;
      end;
   Result := '''';
   for i := 1 to Length(aValue) do
      begin
      if aValue[i] = '''' then
         begin
         Result := Result + '''''';
         end
      else
         begin
         Result := Result + aValue[i];
         end;
      end;
   Result := Result + '''';
end;

function WireStoreCreateTable(aColumns: TWireColumns): string;
var
   i: integer;
   def: string;
begin
   Result := 'CREATE TABLE qso (seq INTEGER PRIMARY KEY AUTOINCREMENT';
   for i := 0 to aColumns.Count - 1 do
      begin
      Result := Result + ', ' + aColumns.Name[i];
      if aColumns.Numeric[i] then
         begin
         Result := Result + ' INTEGER';
         end
      else
         begin
         Result := Result + ' TEXT';
         end;
      def := aColumns.Default[i];
      if def <> '' then
         begin
         Result := Result + ' DEFAULT ' + SqlLiteral(aColumns.Numeric[i], def);
         end;
      end;
   Result := Result + ')';
end;

function WireStoreCreateIndex: string;
begin
   Result := 'CREATE INDEX idx_qso_guid ON qso(' + COL_GUID + ')';
end;

(* --------------------------------------------------------------------------- *)
(* binding and reading text, byte for byte                                       *)
(* --------------------------------------------------------------------------- *)

(* The UTF-8 bytes of aValue as a parameter. RELABELLED, never converted: the
  parameter takes an AnsiString of the program's default code page, and a
  conversion from UTF-8 to a default that is not UTF-8 would lose characters. *)
procedure SetParamText(aParam: TParam; const aValue: string);
var
   raw: RawByteString;
begin
   raw := UTF8Encode(aValue);
   SetCodePage(raw, DefaultSystemCodePage, False);
   aParam.AsString := raw;
end;

(* A text field's bytes, read as UTF-8 whatever the default code page is. *)
function FieldText(aField: TField): string;
var
   raw: RawByteString;
begin
   raw := RawByteString(aField.AsString);
   SetCodePage(raw, CODE_PAGE_UTF8, False);
   Result := UnicodeString(raw);
end;

(* --------------------------------------------------------------------------- *)
(* TServerWireStore                                                              *)
(* --------------------------------------------------------------------------- *)

constructor TServerWireStore.Create(aColumns: TWireColumns; const aFileName: string);
var
   i: integer;
begin
   inherited Create;
   FColumns := aColumns;
   FFileName := aFileName;
   FCount := -1;
   for i := Low(NEEDED_COLUMNS) to High(NEEDED_COLUMNS) do
      begin
      if FColumns.IndexOfName(NEEDED_COLUMNS[i]) < 0 then
         begin
         raise EWireQsoError.Create(AnsiString('The server store needs the wire column "' +
                                               NEEDED_COLUMNS[i] + '".'));
         end;
      end;
   FGuidIndex := FColumns.IndexOfName(COL_GUID);
   BuildStatements;
end;

destructor TServerWireStore.Destroy;
begin
   (* A run still held is acknowledged work: commit it rather than lose it. *)
   Release;
   FreeAndNil(FDb);
   inherited Destroy;
end;

procedure TServerWireStore.Report(const aFormat: string; aLevel: integer;
                                  const aArgs: array of const);
begin
   if Logger = nil then
      begin
      Exit;
      end;
   case aLevel of
      LEVEL_ERROR: Logger.Error(aFormat, aArgs);
      LEVEL_WARN: Logger.Warn(aFormat, aArgs);
   else
      Logger.Info(aFormat, aArgs);
   end;
end;

procedure TServerWireStore.BuildStatements;
var
   i: integer;
   cols, vals, sets: string;
begin
   cols := '';
   vals := '';
   sets := '';
   for i := 0 to FColumns.Count - 1 do
      begin
      if i > 0 then
         begin
         cols := cols + ', ';
         vals := vals + ', ';
         sets := sets + ', ';
         end;
      cols := cols + FColumns.Name[i];
      vals := vals + ':p' + IntToStr(i);
      sets := sets + FColumns.Name[i] + ' = :p' + IntToStr(i);
      end;
   FInsertPlain := 'INSERT INTO qso (' + cols + ') VALUES (' + vals + ')';
   FInsertIfAbsent := 'INSERT INTO qso (' + cols + ') SELECT ' + vals +
                      ' WHERE NOT EXISTS (SELECT 1 FROM qso WHERE guid = :g)';
   FUpdateNewest := 'UPDATE qso SET ' + sets +
                    ' WHERE seq = (SELECT MAX(seq) FROM qso WHERE guid = :g)';
   FSelectAll := 'SELECT ' + cols + ' FROM qso ORDER BY seq';
end;

function TServerWireStore.JournalMode: string;
begin
   Result := '';
   if FDb <> nil then
      begin
      Result := FDb.JournalMode;
      end;
end;

function TServerWireStore.Synchronous: integer;
begin
   Result := -1;
   if FDb <> nil then
      begin
      Result := FDb.Synchronous;
      end;
end;

procedure TServerWireStore.ReportWritten;
begin
   if Assigned(OnWritten) then
      begin
      OnWritten;
      end;
end;

procedure TServerWireStore.NoteCount;
begin
   if Assigned(OnCountChanged) then
      begin
      OnCountChanged(FCount);
      end;
end;

(* THE ONE PLACE A WRITE'S FAILURE IS HANDLED: roll back (TLogDatabase.Rollback
  copes with SQLite having ended the transaction itself on a full disk), end any
  hold, forget the cached count, log it and tell the server. Never raises. *)
procedure TServerWireStore.FailWrite(E: Exception; const aWhat: string);
var
   kind: string;
begin
   try
      FDb.Rollback;
   except
      on Exception do
         begin
         (* Nothing more can be done for a transaction that will not end; the
           next BeginWrite ends whatever remains. *)
         end;
   end;
   if FHeld then
      begin
      FHeld := False;
      Report('[WireStore] the held run was rolled back: its rows are not stored.', LEVEL_ERROR, []);
      end;
   FCount := -1;
   case SQLiteWriteFailure(E) of
      lwfDiskFull: kind := 'the disk is full';
      lwfWriteError: kind := 'the disk refused a write';
   else
      kind := E.Message;
   end;
   Report('[WireStore] cannot %s: %s', LEVEL_ERROR, [aWhat, E.Message]);
   if Assigned(OnWriteFailed) then
      begin
      OnWriteFailed(kind);
      end;
end;

(* A write transaction, unless a hold already has one. A read leaves sqldb's
  implicit transaction open and a write from that old snapshot fails at once
  (SQLITE_BUSY_SNAPSHOT), so it is ended first -- TLogDatabase.EndTransaction. *)
procedure TServerWireStore.BeginWrite;
begin
   if FHeld then
      begin
      Exit;
      end;
   FDb.EndTransaction;
   FDb.Transaction.StartTransaction;
end;

(* After a read that is not inside a hold. *)
procedure TServerWireStore.EndRead;
begin
   if (FDb <> nil) and (not FHeld) then
      begin
      FDb.EndTransaction;
      end;
end;

function TServerWireStore.ScalarText(aDb: TLogDatabase; const aSql: string): string;
var
   q: TSQLQuery;
begin
   Result := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDb.Connection;
      q.SQL.Text := AnsiString(aSql);
      q.Open;
      if not q.EOF then
         begin
         Result := string(q.Fields[0].AsString);
         end;
      q.Close;
   finally
      q.Free;
   end;
   aDb.EndTransaction;
end;

(* IS THIS FILE ONE OF OURS, OF THIS VERSION, WITH THESE COLUMNS? Reads only.
  aFresh: an empty SQLite file (no application id, no tables) that Initialize
  may build. Every other answer that is not True is a refusal with a reason. *)
function TServerWireStore.Judge(aDb: TLogDatabase; out aFresh: boolean;
                                out aWhy: string): boolean;
var
   appId, version: Int64;
   tables: string;
   q: TSQLQuery;
   i: integer;
begin
   Result := False;
   aFresh := False;
   aWhy := '';
   appId := StrToInt64Def(ScalarText(aDb, 'PRAGMA application_id'), 0);
   tables := ScalarText(aDb,
      'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name NOT LIKE ''sqlite_%''');
   if (appId = 0) and (StrToIntDef(tables, 0) = 0) then
      begin
      aFresh := True;
      Result := True;
      Exit;
      end;
   if appId <> WIRE_STORE_APPLICATION_ID then
      begin
      aWhy := Format('"%s" is a SQLite database but not a TR4WServer log: its application ' +
                     'id is 0x%.8x, and a server log carries 0x%.8x.',
                     [FFileName, appId, WIRE_STORE_APPLICATION_ID]);
      Exit;
      end;
   try
      version := StrToInt64Def(ScalarText(aDb,
         'SELECT value FROM meta WHERE key = ''' + WIRE_STORE_META_VERSION + ''''), -1);
   except
      on E: Exception do
         begin
         aWhy := Format('"%s" has no meta table with a schema version: %s', [FFileName, E.Message]);
         Exit;
         end;
   end;
   if version <> WIRE_STORE_SCHEMA_VERSION then
      begin
      aWhy := Format('"%s" is server log schema %d; this server reads schema %d. ' +
                     'It is left as it is.', [FFileName, version, WIRE_STORE_SCHEMA_VERSION]);
      Exit;
      end;
   (* THE COLUMNS, BY NAME AND ORDER: a file of this version whose qso table is
     another shape (a column added since) must not be written as if it were ours. *)
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDb.Connection;
      q.SQL.Text := AnsiString('SELECT name FROM pragma_table_info(''qso'') ORDER BY cid');
      q.Open;
      if q.EOF or (string(q.Fields[0].AsString) <> 'seq') then
         begin
         aWhy := Format('"%s" has no qso table of this server''s shape.', [FFileName]);
         Exit;
         end;
      q.Next;
      for i := 0 to FColumns.Count - 1 do
         begin
         if q.EOF or (string(q.Fields[0].AsString) <> FColumns.Name[i]) then
            begin
            aWhy := Format('"%s": its qso table does not have the wire column "%s" at ' +
                           'position %d.', [FFileName, FColumns.Name[i], i + 1]);
            Exit;
            end;
         q.Next;
         end;
      if not q.EOF then
         begin
         aWhy := Format('"%s": its qso table has more columns than the wire has.', [FFileName]);
         Exit;
         end;
      q.Close;
   finally
      q.Free;
   end;
   aDb.EndTransaction;
   Result := True;
end;

(* THE SCHEMA, in ONE transaction, then the file's identity. A failure leaves
  an empty file, which Initialize deletes only if it created it. *)
function TServerWireStore.ApplySchema: boolean;
begin
   Result := False;
   try
      FDb.EndTransaction;
      FDb.Transaction.StartTransaction;
      FDb.Connection.ExecuteDirect('CREATE TABLE meta (key TEXT PRIMARY KEY, value)');
      FDb.Connection.ExecuteDirect(AnsiString(WireStoreCreateTable(FColumns)));
      FDb.Connection.ExecuteDirect(AnsiString(WireStoreCreateIndex));
      FDb.Connection.ExecuteDirect(AnsiString(Format(
         'INSERT INTO meta (key, value) VALUES (''%s'', %d)',
         [WIRE_STORE_META_VERSION, WIRE_STORE_SCHEMA_VERSION])));
      FDb.Transaction.Commit;
      FDb.Connection.ExecutePragma(AnsiString(Format('PRAGMA application_id = %d',
                                                     [WIRE_STORE_APPLICATION_ID])));
      Result := True;
   except
      on E: Exception do
         begin
         Report('[WireStore] cannot create the schema in "%s": %s', LEVEL_ERROR,
                [FFileName, E.Message]);
         try
            FDb.Rollback;
         except
            on Exception do
               begin
               end;
         end;
         end;
   end;
end;

function TServerWireStore.ReadCount: integer;
begin
   Result := StrToIntDef(ScalarText(FDb, 'SELECT COUNT(*) FROM qso'), -1);
end;

function TServerWireStore.Initialize(out aWhy: string): TWireStoreInit;
var
   peek: TLogDatabase;
   fresh, existed: boolean;
   integrity: TIntegrityResult;
begin
   aWhy := '';
   Result := wsiCannotOpen;
   FreeAndNil(FDb);
   FHeld := False;
   existed := FileExists(FFileName);
   fresh := True;

   if existed then
      begin
      (* EXAMINED READ-ONLY FIRST: a file that is not ours must not have one
        byte of it written -- opening read-write sets WAL, which rewrites the
        header. *)
      peek := TLogDatabase.Create;
      try
         try
            peek.OpenWithoutIdentity(FFileName, True);
         except
            on E: Exception do
               begin
               (* SQLite opened the file and then could not read its header: it is
                 not a database (NOTADB) or is damaged (CORRUPT). That is a file
                 that is not ours, not a file we could not open. *)
               aWhy := Format('cannot open "%s": %s', [FFileName, E.Message]);
               if (SQLiteErrorCode(E) and $FF) in [SQLITE_CORRUPT_PRIMARY, SQLITE_NOTADB_PRIMARY] then
                  begin
                  Result := wsiRefused;
                  end;
               Exit;
               end;
         end;
         try
            if not Judge(peek, fresh, aWhy) then
               begin
               Result := wsiRefused;
               Exit;
               end;
         except
            on E: Exception do
               begin
               (* A read that fails on a file SQLite did open: it is not a
                 database at all (SQLITE_NOTADB) or is damaged. *)
               aWhy := Format('"%s" is not a readable server log: %s', [FFileName, E.Message]);
               Result := wsiRefused;
               Exit;
               end;
         end;
      finally
         peek.Free;
      end;
      end;

   FDb := TLogDatabase.Create;
   try
      FDb.OpenWithoutIdentity(FFileName, False);
   except
      on E: Exception do
         begin
         aWhy := Format('cannot open "%s": %s', [FFileName, E.Message]);
         FreeAndNil(FDb);
         Exit;
         end;
   end;

   if fresh then
      begin
      if not ApplySchema then
         begin
         aWhy := Format('cannot create the schema in "%s"', [FFileName]);
         FreeAndNil(FDb);
         if not existed then
            begin
            DeleteFile(FFileName);
            end;
         Exit;
         end;
      end
   else
      begin
      (* A file that was already ours is checked before it is written to. *)
      integrity := FDb.CheckIntegrity;
      if not integrity.Ok then
         begin
         aWhy := Format('"%s" failed its integrity check: %s', [FFileName, integrity.Report]);
         FreeAndNil(FDb);
         Result := wsiRefused;
         Exit;
         end;
      end;

   if LowerCase(FDb.JournalMode) <> 'wal' then
      begin
      Report('[WireStore] journal mode is "%s", not WAL (a network share?); commits are ' +
             'still durable but readers and the writer will block each other.',
             LEVEL_WARN, [FDb.JournalMode]);
      end;
   FCount := ReadCount;
   NoteCount;
   Result := wsiReady;
end;

procedure TServerWireStore.Hold;
begin
   if (FDb = nil) or FHeld then
      begin
      Exit;
      end;
   try
      FDb.EndTransaction;
      FDb.Transaction.StartTransaction;
      FHeld := True;
   except
      on E: Exception do
         begin
         FailWrite(E, 'begin a run of QSOs');
         end;
   end;
end;

function TServerWireStore.Release: boolean;
begin
   Result := True;
   if (FDb = nil) or (not FHeld) then
      begin
      Exit;
      end;
   try
      FDb.Transaction.Commit;
      FHeld := False;
   except
      on E: Exception do
         begin
         Result := False;
         FailWrite(E, 'commit a run of QSOs');
         end;
   end;
end;

function TServerWireStore.Contest: string;
begin
   Result := '';
   if FDb = nil then
      begin
      Exit;
      end;
   try
      Result := ScalarText(FDb, 'SELECT value FROM meta WHERE key = ''' + META_CONTEST + '''');
   except
      on E: Exception do
         begin
         Report('[WireStore] cannot read the contest: %s', LEVEL_ERROR, [E.Message]);
         end;
   end;
   EndRead;
end;

function TServerWireStore.RememberContest(const aId: string): boolean;
var
   q: TSQLQuery;
begin
   Result := False;
   if (FDb = nil) or (aId = '') or (Contest <> '') then
      begin
      Exit;
      end;
   try
      BeginWrite;
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := FDb.Connection;
         q.SQL.Text := AnsiString('INSERT OR IGNORE INTO meta (key, value) VALUES (''' +
                                  META_CONTEST + ''', :v)');
         SetParamText(q.Params.ParamByName('v'), aId);
         q.ExecSQL;
      finally
         q.Free;
      end;
      if not FHeld then
         begin
         FDb.Transaction.Commit;
         end;
      Result := True;
   except
      on E: Exception do
         begin
         FailWrite(E, 'record the contest');
         end;
   end;
end;

procedure TServerWireStore.ForgetContest;
begin
   if FDb = nil then
      begin
      Exit;
      end;
   try
      BeginWrite;
      FDb.Connection.ExecuteDirect('DELETE FROM meta WHERE key = ''' + META_CONTEST + '''');
      if not FHeld then
         begin
         FDb.Transaction.Commit;
         end;
   except
      on E: Exception do
         begin
         FailWrite(E, 'forget the contest');
         end;
   end;
end;

function TServerWireStore.BackupTo(const aDestination: string; out aWhy: string): boolean;
begin
   Result := False;
   aWhy := '';
   if FDb = nil then
      begin
      aWhy := 'the server log is not open';
      Exit;
      end;
   try
      FDb.SnapshotTo(aDestination, False);
      Result := FileExists(aDestination);
      if not Result then
         begin
         aWhy := 'the backup file was not written';
         end;
   except
      on E: Exception do
         begin
         aWhy := E.Message;
         end;
   end;
end;

(* The row is a row of THIS schema: the right number of values, and a numeric
  column holding canonical digits or nothing. *)
function TServerWireStore.RowsValid(const aValues: TWireValues): boolean;
var
   i: integer;
   n: Int64;
begin
   Result := False;
   if Length(aValues) <> FColumns.Count then
      begin
      Report('[WireStore] rejected a row of %d values; the schema has %d columns.',
             LEVEL_WARN, [Length(aValues), FColumns.Count]);
      Exit;
      end;
   for i := 0 to FColumns.Count - 1 do
      begin
      if FColumns.Numeric[i] and (aValues[i] <> '') and
         (not TryCanonicalInt64(aValues[i], n)) then
         begin
         Report('[WireStore] rejected a row: column %s is numeric and holds "%s".',
                LEVEL_WARN, [FColumns.Name[i], aValues[i]]);
         Exit;
         end;
      end;
   Result := True;
end;

procedure TServerWireStore.BindRow(aQuery: TObject; const aValues: TWireValues);
var
   q: TSQLQuery;
   i: integer;
   p: TParam;
   n: Int64;
begin
   q := TSQLQuery(aQuery);
   for i := 0 to FColumns.Count - 1 do
      begin
      p := q.Params.FindParam(AnsiString('p' + IntToStr(i)));
      if p = nil then
         begin
         Continue;
         end;
      if aValues[i] = '' then
         begin
         p.Clear;
         end
      else if FColumns.Numeric[i] then
         begin
         TryCanonicalInt64(aValues[i], n);
         p.AsLargeInt := n;
         end
      else
         begin
         SetParamText(p, aValues[i]);
         end;
      end;
end;

function TServerWireStore.Insert(const aValues: TWireValues): TWireInsert;
var
   q: TSQLQuery;
   identified, stored: boolean;
begin
   Result := wiFailed;
   if FDb = nil then
      begin
      Exit;
      end;
   if not RowsValid(aValues) then
      begin
      Result := wiRejected;
      Exit;
      end;
   identified := aValues[FGuidIndex] <> '';
   try
      BeginWrite;
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := FDb.Connection;
         if identified then
            begin
            q.SQL.Text := AnsiString(FInsertIfAbsent);
            end
         else
            begin
            q.SQL.Text := AnsiString(FInsertPlain);
            end;
         BindRow(q, aValues);
         if identified then
            begin
            SetParamText(q.Params.ParamByName('g'), aValues[FGuidIndex]);
            end;
         q.ExecSQL;
         stored := (not identified) or (q.RowsAffected > 0);
      finally
         q.Free;
      end;
      if not FHeld then
         begin
         FDb.Transaction.Commit;
         end;
   except
      on E: Exception do
         begin
         FailWrite(E, 'store a QSO');
         Exit;
         end;
   end;
   if stored then
      begin
      if FCount >= 0 then
         begin
         Inc(FCount);
         end;
      Result := wiStored;
      ReportWritten;
      NoteCount;
      end
   else
      begin
      Result := wiDuplicate;
      end;
end;

function TServerWireStore.UpdateNewest(const aValues: TWireValues): boolean;
var
   q: TSQLQuery;
begin
   Result := True;
   if FDb = nil then
      begin
      Result := False;
      Report('[WireStore] cannot rewrite an edited QSO: the store is not open.', LEVEL_ERROR, []);
      if Assigned(OnWriteFailed) then
         begin
         OnWriteFailed('cannot open the log');
         end;
      Exit;
      end;
   if not RowsValid(aValues) then
      begin
      (* Not a row of this schema: nothing is rewritten, and the server relays as
        it always has. Not a failure of the disk. *)
      Exit;
      end;
   if aValues[FGuidIndex] = '' then
      begin
      Exit;   (* names nothing: see IDENTITY *)
      end;
   try
      BeginWrite;
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := FDb.Connection;
         q.SQL.Text := AnsiString(FUpdateNewest);
         BindRow(q, aValues);
         SetParamText(q.Params.ParamByName('g'), aValues[FGuidIndex]);
         q.ExecSQL;
      finally
         q.Free;
      end;
      if not FHeld then
         begin
         FDb.Transaction.Commit;
         end;
      ReportWritten;
   except
      on E: Exception do
         begin
         FailWrite(E, 'rewrite an edited QSO');
         Result := False;
         end;
   end;
end;

function TServerWireStore.Holds(const aGuid: string): boolean;
var
   q: TSQLQuery;
begin
   Result := False;
   if (FDb = nil) or (aGuid = '') then
      begin
      Exit;
      end;
   try
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := FDb.Connection;
         q.SQL.Text := AnsiString('SELECT 1 FROM qso WHERE guid = :g LIMIT 1');
         SetParamText(q.Params.ParamByName('g'), aGuid);
         q.Open;
         Result := not q.EOF;
         q.Close;
      finally
         q.Free;
      end;
   except
      on E: Exception do
         begin
         Report('[WireStore] cannot ask whether a QSO is held: %s', LEVEL_ERROR, [E.Message]);
         Result := False;
         end;
   end;
   EndRead;
end;

function TServerWireStore.Clear: boolean;
begin
   Result := False;
   if FDb = nil then
      begin
      Exit;
      end;
   try
      BeginWrite;
      FDb.Connection.ExecuteDirect('DELETE FROM qso');
      if not FHeld then
         begin
         FDb.Transaction.Commit;
         end;
      FCount := 0;
      Result := True;
      NoteCount;
   except
      on E: Exception do
         begin
         FailWrite(E, 'clear the log');
         end;
   end;
end;

function TServerWireStore.ClearFlags(aAction: TWireFlagAction): boolean;
var
   sql: string;
   q: TSQLQuery;
begin
   Result := False;
   if FDb = nil then
      begin
      Exit;
      end;
   if Count <= 0 then
      begin
      Exit;
      end;
   case aAction of
      wfaSetClearDupesheet:
         sql := 'UPDATE qso SET ' + COL_DUPE + ' = 1 WHERE ' + COL_KIND + ' = ''QSO''';
   else
      sql := 'UPDATE qso SET ' + COL_MULT_SHEET + ' = 1, mult_domestic = 0, mult_dx = 0, ' +
             'mult_prefix = 0, mult_zone = 0 WHERE ' + COL_KIND + ' = ''QSO''';
   end;
   try
      BeginWrite;
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := FDb.Connection;
         q.SQL.Text := AnsiString(sql);
         q.ExecSQL;
      finally
         q.Free;
      end;
      if not FHeld then
         begin
         FDb.Transaction.Commit;
         end;
      Result := True;
      ReportWritten;
   except
      on E: Exception do
         begin
         FailWrite(E, 'change the QSO flags');
         end;
   end;
end;

function TServerWireStore.MaxNumberSent(out aMax: integer): boolean;
var
   text: string;
begin
   Result := False;
   aMax := 0;
   if FDb = nil then
      begin
      Exit;
      end;
   try
      (* As text: an expression has no declared type, and sqlite3conn gives it a
        255-character string field, which reads fine for a number. *)
      text := ScalarText(FDb, 'SELECT COALESCE(MAX(' + COL_SERIAL + '), 0) FROM qso');
      aMax := StrToIntDef(text, 0);
      Result := True;
   except
      on E: Exception do
         begin
         Report('[WireStore] cannot read the largest serial number: %s', LEVEL_ERROR, [E.Message]);
         end;
   end;
   EndRead;
end;

function TServerWireStore.Count: integer;
begin
   Result := -1;
   if FDb = nil then
      begin
      Exit;
      end;
   try
      Result := ReadCount;
   except
      on E: Exception do
         begin
         Report('[WireStore] cannot count the QSOs: %s', LEVEL_ERROR, [E.Message]);
         end;
   end;
   EndRead;
end;

function TServerWireStore.ReadAll(out aRows: TWireRows): boolean;
var
   ignored: string;
begin
   Result := ReadAll(aRows, ignored);
end;

function TServerWireStore.ReadAll(out aRows: TWireRows; out aContest: string): boolean;
var
   reader: TLogDatabase;
   q: TSQLQuery;
   n, i: integer;
   row: TWireValues;
begin
   Result := False;
   SetLength(aRows, 0);
   aContest := '';
   reader := TLogDatabase.Create;
   try
      try
         reader.OpenWithoutIdentity(FFileName, True);
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := reader.Connection;
            (* THE CONTEST FIRST, in the same read transaction as the rows (the
              transaction is not ended between the two queries). *)
            q.SQL.Text := AnsiString('SELECT value FROM meta WHERE key = ''' + META_CONTEST + '''');
            q.Open;
            if not q.EOF then
               begin
               aContest := FieldText(q.Fields[0]);
               end;
            q.Close;
            q.SQL.Text := AnsiString(FSelectAll);
            q.Open;
            n := 0;
            while not q.EOF do
               begin
               SetLength(row, FColumns.Count);
               for i := 0 to FColumns.Count - 1 do
                  begin
                  if q.Fields[i].IsNull then
                     begin
                     row[i] := '';
                     end
                  else if FColumns.Numeric[i] then
                     begin
                     row[i] := IntToStr(q.Fields[i].AsLargeInt);
                     end
                  else
                     begin
                     row[i] := FieldText(q.Fields[i]);
                     end;
                  end;
               if n >= Length(aRows) then
                  begin
                  SetLength(aRows, (n + 1) * 2);
                  end;
               aRows[n] := row;
               row := nil;
               Inc(n);
               q.Next;
               end;
            SetLength(aRows, n);
            q.Close;
         finally
            q.Free;
         end;
         Result := True;
      except
         on E: Exception do
            begin
            SetLength(aRows, 0);
            Report('[WireStore] cannot read the log: %s', LEVEL_ERROR, [E.Message]);
            end;
      end;
   finally
      reader.Free;
   end;
end;

end.
