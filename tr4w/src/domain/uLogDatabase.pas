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

{ ONE LOG, ONE FILE, ONE CONNECTION.  The first code in TR4W that opens a
  database.

  Design settled in docs\SQLITE_LOG_SCHEMA_PLAN.md; the DDL and the reasoning
  behind its shape are in uLogSchema.pas.  What this unit adds is the lifecycle
  and the failure reporting.

  CONNECTION LIFECYCLE (plan section 9b).  One connection per open log, created
  when the log opens and destroyed when it closes.  Nothing re-opens the file
  per QSO, per query or per screen refresh -- that is the classic way to make
  SQLite look slow, and it is the reason section 9a can say "do not build a
  cache" without hand-waving.  The two hot statements (insert a QSO, dupe-check
  a callsign) are prepared once by whatever owns them; this unit does not own
  them and deliberately has no opinion about them yet.

  A CONNECTION BELONGS TO ONE THREAD.  Not enforced here, because enforcing it
  would mean this unit knowing which thread is special, and the domain does not
  know a main thread exists (see uDomainState).  It is a precondition on the
  caller and it is written down in the plan.

  WHY THE DLL FAILURE IS DIAGNOSED RATHER THAN RE-RAISED.  FPC's binding is
  DYNAMIC -- sqlite3.inc declares Sqlite3Lib = 'sqlite3.dll' and resolves
  through LoadLibrary at run time -- so a missing or wrong-architecture DLL is a
  RUN-TIME failure, not a link error.  Windows reports a 32/64-bit mismatch as
  "the specified module could not be found", which sends the reader looking for
  a file that is sitting right there.  We ship a 32-bit DLL because we build
  i386; the 64-bit move has to swap it (plan section 9).  So on failure this
  unit reads the PE machine word out of the file it found and says what it is,
  which turns a half-hour into a sentence.

  CLAUDE.md's standing rule applies and is the reason this exists at all:
  prefer a REPORTED error over a silent fallback.  There is no fallback to make
  here -- without SQLite there is no log -- so the whole value is in the
  message. }
unit uLogDatabase;

{$I ..\tr4w.inc}

interface

uses
   Classes, SysUtils, db, sqldb, sqlite3conn, sqlite3dyn;

type
   ELogDatabaseError = class(Exception);

   { The outcome of CheckIntegrity.  A record and not a boolean because the
     answer an operator needs is WHICH check failed and what it said -- SQLite's
     own messages are specific and throwing them away to return False would be
     the silent-downgrade mistake this tree keeps finding. }
   TIntegrityResult = record
      Ok: boolean;
      { Empty when Ok. Otherwise one line per problem, already human-readable. }
      Report: string;
   end;

   { An open contest log.  Owns its connection and its transaction; owns no
     queries, because the statements that matter are prepared by the mapper
     that uses them. }
   TLogDatabase = class(TObject)
   private
      FConnection: TSQLite3Connection;
      FTransaction: TSQLTransaction;
      FFileName: string;
      FJournalMode: string;
      FForeignKeysEnforced: boolean;

      procedure OpenConnection(const aFileName: string);
      procedure ApplySchema;
      procedure ApplyPragmas;
      procedure StampIdentity;
      procedure VerifyIdentity;

      { PRAGMA takes no parameter markers, so these are the only places SQL is
        built by formatting.  Every caller passes a constant from this unit or
        from uLogSchema -- never anything from a file or an operator. }
      { ANSISTRING for the same reason the schema statements are -- this is the
        type sqldb and the SQLite C API actually take. }
      function PragmaAsInteger(const aPragma: AnsiString): integer;
      function PragmaAsString(const aPragma: AnsiString): AnsiString;
      procedure ExecPragma(const aPragma: AnsiString);

      { The connection-level pragmas, executed BENEATH sqldb.  See its
        implementation: they cannot be set through sqldb at all. }
      procedure ExecPragmaRaw(const aPragma: AnsiString);

      { SQLDB OPENS A TRANSACTION IMPLICITLY ON THE FIRST STATEMENT, and it does
        not close it. }
      procedure EndTransaction;
   public
      constructor Create;
      destructor Destroy; override;

      { Create a NEW log and apply the schema.  REFUSES an existing file: a
        contest log is the operator's only copy of a weekend, and "create"
        silently truncating one is not a risk worth taking for the convenience
        of not asking. }
      procedure CreateNew(const aFileName: string);

      { Open an EXISTING log.  Refuses a missing file for the same reason in
        reverse: SQLite would helpfully create an empty database, and an empty
        log that opens cleanly is worse than an error. }
      procedure Open(const aFileName: string);

      procedure Close;
      function IsOpen: boolean;

      { PRAGMA user_version.  0 means "no schema", which is what an empty file
        reports -- so it is also how a caller detects a database that is not
        one of ours. }
      function SchemaVersion: integer;

      { PRAGMA integrity_check + foreign_key_check, and a WAL checkpoint first
        so recent writes are actually visible to it.  Reports; never repairs.

        Call it on OPEN as well as after a backup: a log opened after a crash
        should be looked at before it is written to. }
      function CheckIntegrity: TIntegrityResult;

      property FileName: string read FFileName;
      { What journal_mode actually came back -- 'wal' normally, 'delete' when
        SQLite refused WAL (a network share). Worth reading before concluding
        anything about locking or speed. }
      property JournalMode: string read FJournalMode;

      { Whether foreign key enforcement is actually ON, read back rather than
        assumed. See ApplyPragmas for why that distinction is not pedantry. }
      property ForeignKeysEnforced: boolean read FForeignKeysEnforced;

      property Connection: TSQLite3Connection read FConnection;
      property Transaction: TSQLTransaction read FTransaction;
   end;

{ The architecture of a Windows PE file -- 'i386', 'x86-64', 'ARM64', an
  'unknown (0x....)' for a machine word we do not name, or '' when the file is
  not a PE at all (which includes "does not exist").

  Pure file reading, and separated out precisely so it can be tested: the
  failure it explains needs a broken installation to reproduce, and a test
  cannot have one.  It can, however, point this at any two binaries and check
  the answers, which is what test\unit\uTestLogDatabase.pas does. }
function DescribePEArchitecture(const aFileName: string): string;

{ What this build is, in the same spelling DescribePEArchitecture returns, so
  the two can be compared and quoted in one sentence. }
function BuildArchitecture: string;

{ Why SQLite probably did not load.  Takes the FULL PATH of the library to
  examine rather than a directory to search: the caller already knows where the
  file should be (uAppPaths does), and a routine that re-derives it would be a
  second opinion about the install layout.  Returns a sentence for a human;
  never raises. }
function DiagnoseSQLiteLoad(const aLibraryPath: string): string;

{ Where the library should be.  Separated so the message and the load agree
  about one path rather than each working it out. }
function SQLiteLibraryPath: string;

const
   SQLITE_LIBRARY_NAME = 'sqlite3.dll';

   { PRAGMA application_id -- four bytes at offset 68 of every log we create,
     which is 'TR4W' in ASCII.  Taken from TR4QT, which uses 0x54523451 ('TR4Q')
     for the same purpose (Database.h:49) and refuses to open a database whose
     id is set to something else (Database.cpp:161).

     WHY IT IS WORTH THE FOUR BYTES.  Without it, "is this file one of ours"
     can only be answered by opening it and guessing from the tables present,
     and question 8 settled that a TR4QT log is NOT an interop target -- so the
     two must be distinguishable rather than merely different.  It also makes
     the file identifiable to `file`, to SQLite's own tooling and to anyone
     staring at a hex dump five years from now.

     NOT MENTIONED IN THE PLAN DOCUMENT, and found by reading TR4QT at NY4I's
     suggestion on 2026-09-01. }
   LOG_APPLICATION_ID = $54523457;   { 'TR4W' }

implementation

uses
   uLogSchema, uAppPaths;

{ ---------------------------------------------------------------------------
  PE architecture
  --------------------------------------------------------------------------- }

const
   { The three machine words that can matter to this program.  From the PE
     specification's IMAGE_FILE_HEADER.Machine. }
   IMAGE_FILE_MACHINE_I386  = $014C;
   IMAGE_FILE_MACHINE_AMD64 = $8664;
   IMAGE_FILE_MACHINE_ARM64 = $AA64;

function DescribePEArchitecture(const aFileName: string): string;
var
   fs: TFileStream;
   mzSignature: word;
   peOffset: longword;
   peSignature: longword;
   machine: word;
begin
   Result := '';

   if not FileExists(aFileName) then
      begin
      Exit;
      end;

   try
      { EXPLICIT, at a genuine boundary. The RTL's file API is AnsiString and
        FPC treats it as the file-system codepage, which on this build is UTF-8
        -- so this is the conversion that was happening anyway, said out loud.
        CLAUDE.md's done-criterion allows the cast exactly here. }
      fs := TFileStream.Create(AnsiString(aFileName), fmOpenRead or fmShareDenyNone);
      try
         { 'MZ', then the PE header offset at 0x3C, then 'PE\0\0', then the
           machine word.  Each step is checked because this function is handed
           whatever file happened to be at the path -- including, on a bad
           install, an HTML error page with a .dll name. }
         if fs.Size < $40 then
            begin
            Exit;
            end;

         fs.Position := 0;
         mzSignature := fs.ReadWord;
         if mzSignature <> $5A4D then          { 'MZ', little-endian }
            begin
            Exit;
            end;

         fs.Position := $3C;
         peOffset := fs.ReadDWord;
         if (peOffset = 0) or (peOffset + 6 > longword(fs.Size)) then
            begin
            Exit;
            end;

         fs.Position := peOffset;
         peSignature := fs.ReadDWord;
         if peSignature <> $00004550 then      { 'PE', 0, 0 }
            begin
            Exit;
            end;

         machine := fs.ReadWord;

         case machine of
            IMAGE_FILE_MACHINE_I386:
               begin
               Result := 'i386';
               end;
            IMAGE_FILE_MACHINE_AMD64:
               begin
               Result := 'x86-64';
               end;
            IMAGE_FILE_MACHINE_ARM64:
               begin
               Result := 'ARM64';
               end;
            else
               begin
               Result := Format('unknown (0x%.4x)', [machine]);
               end;
         end;
      finally
         fs.Free;
      end;
   except
      { A file we cannot read tells us nothing, and this routine exists to
        improve an error message -- it must never replace one. }
      on E: Exception do
         begin
         Result := '';
         end;
   end;
end;

function BuildArchitecture: string;
begin
   {$IF DEFINED(CPUX86_64) OR DEFINED(CPUAMD64)}
   Result := 'x86-64';
   {$ELSEIF DEFINED(CPUAARCH64)}
   Result := 'ARM64';
   {$ELSEIF DEFINED(CPU386) OR DEFINED(CPUI386)}
   Result := 'i386';
   {$ELSE}
   Result := 'unknown';
   {$IFEND}
end;

{ DataFilePath, not SettingsFilePath or LogFilePath: sqlite3.dll is SHIPPED and
  read-only.  On Windows all three are the same directory and the choice looks
  cosmetic; on macOS and Linux they are three different places, which is why
  Lint-AppPaths refuses a hand-rolled ExtractFilePath(ParamStr(0)) here. }
function SQLiteLibraryPath: string;
begin
   Result := DataFilePath(SQLITE_LIBRARY_NAME);
end;

function DiagnoseSQLiteLoad(const aLibraryPath: string): string;
var
   dllPath: string;
   dllArch: string;
   ourArch: string;
begin
   ourArch := BuildArchitecture;
   dllPath := aLibraryPath;

   if not FileExists(dllPath) then
      begin
      Result := Format('%s was not found. TR4W looked for it at "%s". It is a ' +
                       'required runtime file and is shipped by the installer.',
                       [SQLITE_LIBRARY_NAME, dllPath]);
      Exit;
      end;

   dllArch := DescribePEArchitecture(dllPath);

   if dllArch = '' then
      begin
      Result := Format('%s exists but is not a valid Windows library -- it has ' +
                       'no PE header. It is probably truncated or was replaced ' +
                       'by something that is not a DLL.', [dllPath]);
      Exit;
      end;

   if dllArch <> ourArch then
      begin
      { The case the whole routine exists for.  Windows reports this as "the
        specified module could not be found", pointing at a file that is
        present. }
      Result := Format('%s is a %s library and this is a %s build of TR4W. ' +
                       'Windows reports an architecture mismatch as "the ' +
                       'specified module could not be found", which is why the ' +
                       'file appears to be missing when it is not. Replace it ' +
                       'with the %s build of SQLite.',
                       [dllPath, dllArch, ourArch, ourArch]);
      Exit;
      end;

   Result := Format('%s is present and is the right architecture (%s), so the ' +
                    'failure is not the library itself.', [dllPath, dllArch]);
end;

{ ---------------------------------------------------------------------------
  TLogDatabase
  --------------------------------------------------------------------------- }

{ SQLDB STARTS A TRANSACTION BY ITSELF AND LEAVES IT OPEN.  Any statement
  through TSQLQuery or ExecuteDirect begins one lazily if none is active, and
  nothing ends it until something commits.  For ordinary data that is exactly
  right.  For pragmas it is fatal, and the failure is not obvious:

      ESQLDatabaseError -- TSQLite3Connection :
      Safety level may not be changed inside a transaction

  which is SQLite refusing PRAGMA synchronous, having been handed a transaction
  that nothing in our code opened.  PRAGMA journal_mode refuses for the same
  reason.  Measured 2026-09-01: setting foreign_keys first was enough to open
  the transaction that then broke synchronous.

  So every pragma is bracketed.  Committing an empty transaction costs nothing
  and it makes the rule "a pragma runs on its own" rather than a comment about
  ordering that the next edit silently breaks. }
procedure TLogDatabase.EndTransaction;
begin
   if FTransaction.Active then
      begin
      FTransaction.Commit;
      end;
end;

procedure TLogDatabase.ExecPragma(const aPragma: AnsiString);
begin
   EndTransaction;
   FConnection.ExecuteDirect(aPragma);
   EndTransaction;
end;

{ THE CONNECTION-LEVEL PRAGMAS CANNOT BE SET THROUGH sqldb.  MEASURED, because
  the first two attempts at this were wrong in different ways.

  sqldb begins a transaction lazily on any statement and does not end it, so
  ExecuteDirect always runs inside one.  SQLite then:

    PRAGMA synchronous     RAISES -- "Safety level may not be changed inside a
                           transaction". Loud, and the reason this was found.
    PRAGMA journal_mode    RAISES likewise.
    PRAGMA foreign_keys    IS A SILENT NO-OP. The statement succeeds, nothing is
                           reported, and foreign keys are still off.

  THAT THIRD ONE IS THE DANGEROUS CASE and it is why this routine exists rather
  than a comment about ordering.  A guard that reports success while doing
  nothing is precisely the failure this tree keeps writing lints about -- and no
  amount of committing first helps, because ExecuteDirect opens a NEW
  transaction before it runs the statement.  Committing beforehand was the
  second wrong attempt; it fails identically.

  So these three go to sqlite3_exec on the connection's own handle, immediately
  after Open and before anything has had a chance to start a transaction.  The
  handle is real and valid at that point -- TSQLite3Connection.Open has already
  called sqlite3_open.  Everything else in this unit still goes through sqldb;
  this is the narrow exception, not a pattern to copy. }
procedure TLogDatabase.ExecPragmaRaw(const aPragma: AnsiString);
var
   rc: integer;
   errMsg: PAnsiChar;
   detail: string;
begin
   errMsg := nil;
   rc := sqlite3_exec(FConnection.Handle, PAnsiChar(aPragma),
                      nil, nil, @errMsg);
   if rc <> SQLITE_OK then
      begin
      detail := '';
      if errMsg <> nil then
         begin
         detail := ' -- ' + string(AnsiString(errMsg));
         sqlite3_free(errMsg);
         end;
      raise ELogDatabaseError.CreateFmt(
         'The contest log "%s" would not accept "%s" (SQLite error %d%s).',
         [FFileName, aPragma, rc, detail]);
      end;
   if errMsg <> nil then
      begin
      sqlite3_free(errMsg);
      end;
end;

function TLogDatabase.PragmaAsString(const aPragma: AnsiString): AnsiString;
var
   q: TSQLQuery;
begin
   Result := '';
   EndTransaction;
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FConnection;
      q.SQL.Text := aPragma;
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsString;
         end;
      q.Close;
   finally
      q.Free;
   end;
   EndTransaction;
end;

function TLogDatabase.PragmaAsInteger(const aPragma: AnsiString): integer;
var
   s: AnsiString;
begin
   s := PragmaAsString(aPragma);
   Result := StrToIntDef(s, 0);
end;

{ SET ON EVERY OPEN, not only on create: journal mode is a property of the FILE
  and persists, but foreign_keys and synchronous are per-CONNECTION and reset to
  their defaults every time.  Setting all three here means one place to read
  rather than a rule about which is which. }
procedure TLogDatabase.ApplyPragmas;
begin
   { ORDER MATTERS: all three run before any sqldb statement has opened a
     transaction. See ExecPragmaRaw. }
   ExecPragmaRaw('PRAGMA foreign_keys = ON');

   { synchronous = FULL is a DELIBERATE divergence from TR4QT, which leaves the
     default. Under WAL the default drops to NORMAL, which can lose the most
     recent transactions on power loss. A contest log writes a few hundred bytes
     every several seconds, so the durability costs nothing measurable at that
     rate -- and the thing being protected is the operator's weekend. }
   ExecPragmaRaw('PRAGMA synchronous = FULL');

   { WAL is requested here and CHECKED below: SQLite refuses WAL on a database
     reached over a network share, which is exactly where a multi-op station is
     most likely to put one. Falling back to the rollback journal is legal and
     safe; not KNOWING you fell back is what makes a later "why did that lock"
     unanswerable. }
   ExecPragmaRaw('PRAGMA journal_mode = WAL');

   { READ BACK, ALL OF THEM. Requesting a pragma and assuming it took is the
     mistake this whole routine is a correction for. }
   FJournalMode := PragmaAsString('PRAGMA journal_mode');
   FForeignKeysEnforced := PragmaAsInteger('PRAGMA foreign_keys') = 1;

   if not FForeignKeysEnforced then
      begin
      { Nothing legitimate produces this once the pragma runs outside a
        transaction, so it means the mechanism above has been broken by an
        edit -- report it rather than run a log with its referential guarantees
        quietly switched off. }
      raise ELogDatabaseError.CreateFmt(
         'The contest log "%s" opened, but foreign key enforcement could not ' +
         'be switched on. This is a defect in TR4W rather than a problem with ' +
         'your log; please report it.', [FFileName]);
      end;
end;

procedure TLogDatabase.StampIdentity;
begin
   ExecPragma(AnsiString(Format('PRAGMA application_id = %d',
                                [LOG_APPLICATION_ID])));
   ExecPragma(AnsiString(Format('PRAGMA user_version = %d',
                                [LOG_SCHEMA_VERSION])));
end;

{ IS THIS ONE OF OURS, AND CAN THIS BUILD UNDERSTAND IT.  Both questions are
  asked on open and both refuse rather than guess. }
procedure TLogDatabase.VerifyIdentity;
var
   appId: integer;
   version: integer;
begin
   appId := PragmaAsInteger('PRAGMA application_id');

   { ZERO IS ACCEPTED. It means "never stamped" -- an empty file, or a log made
     by a build of TR4W older than this check. Refusing those would refuse the
     operator's own logs on the day this ships, which is not a trade worth
     making for a diagnostic. Anything ELSE was stamped deliberately by some
     other program and is not ours. }
   if (appId <> 0) and (appId <> LOG_APPLICATION_ID) then
      begin
      raise ELogDatabaseError.CreateFmt(
         '"%s" is a SQLite database but not a TR4W contest log: its ' +
         'application id is 0x%.8x, and a TR4W log carries 0x%.8x. Opening ' +
         'it would risk writing contest data into somebody else''s file.',
         [FFileName, appId, LOG_APPLICATION_ID]);
      end;

   version := PragmaAsInteger('PRAGMA user_version');

   { REFUSE A LOG FROM THE FUTURE. Taken from TR4QT (Database.cpp:177) and it is
     the right instinct: a newer schema may have columns this build cannot see,
     so opening it read-write would quietly drop them on the next write. An
     older one is fine -- that is what a migration is for. }
   if version > LOG_SCHEMA_VERSION then
      begin
      raise ELogDatabaseError.CreateFmt(
         '"%s" was written by a newer version of TR4W (log schema %d; this ' +
         'build understands %d). Opening it here could silently discard data ' +
         'this version does not know about. Update TR4W.',
         [FFileName, version, LOG_SCHEMA_VERSION]);
      end;
end;

{ WHAT WE TAKE FROM TR4QT AND WHAT WE DO NOT -- the reasoning is in
  docs\SQLITE_LOG_SCHEMA_PLAN.md section 7; the short form is here because this
  is the routine somebody will compare against theirs.

  TAKEN: PRAGMA integrity_check accepting ONLY the literal 'ok'
  (BackupManager.cpp:307), and the WAL checkpoint first -- TR4QT's own comment
  says that without it the check reports false positives for QSOs still in the
  WAL, which is a real bug found the expensive way and worth inheriting.

  ADDED: foreign_key_check, which TR4QT does not run. integrity_check finds
  structural damage; foreign_key_check finds broken references, which is what a
  partial delete or a bad merge produces.

  NOT TAKEN: their tiers 1 and 3, which compare the database against an
  in-memory QList<QSO>. That comparison exists because TR4QT holds the whole log
  in memory; we decided not to (plan 4f), so there is no second copy to
  disagree and the check has nothing to check. Their DataIntegrityManager is
  515 lines and most of it is answering a question we arranged not to have. }
function TLogDatabase.CheckIntegrity: TIntegrityResult;
var
   q: TSQLQuery;
   verdict: AnsiString;
   problems: string;
begin
   Result.Ok := True;
   Result.Report := '';
   problems := '';

   if not IsOpen then
      begin
      Result.Ok := False;
      Result.Report := 'The log is not open, so it cannot be checked.';
      Exit;
      end;

   { Make recent writes visible to the checks below. }
   PragmaAsString('PRAGMA wal_checkpoint(PASSIVE)');

   verdict := PragmaAsString('PRAGMA integrity_check');
   if verdict <> 'ok' then
      begin
      problems := problems + 'integrity_check: ' + verdict + sLineBreak;
      end;

   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FConnection;
      q.SQL.Text := 'PRAGMA foreign_key_check';
      q.Open;
      while not q.EOF do
         begin
         { row: table, rowid, parent table, fkid }
         problems := problems + Format(
            'foreign_key_check: %s row %s references a missing row in %s' + sLineBreak,
            [q.Fields[0].AsString, q.Fields[1].AsString, q.Fields[2].AsString]);
         q.Next;
         end;
      q.Close;
   finally
      q.Free;
   end;

   if problems <> '' then
      begin
      Result.Ok := False;
      Result.Report := problems;
      end;
end;

constructor TLogDatabase.Create;
begin
   inherited Create;
   FConnection := TSQLite3Connection.Create(nil);
   FTransaction := TSQLTransaction.Create(nil);
   FConnection.Transaction := FTransaction;
end;

destructor TLogDatabase.Destroy;
begin
   Close;
   FTransaction.Free;
   FConnection.Free;
   inherited Destroy;
end;

function TLogDatabase.IsOpen: boolean;
begin
   Result := FConnection.Connected;
end;

procedure TLogDatabase.OpenConnection(const aFileName: string);
begin
   { EXPLICIT, and UTF-8 is not merely acceptable here -- it is what SQLite
     specifies. sqlite3_open takes a UTF-8 filename, and DefaultSystemCodePage
     is 65001 in this build, so AnsiString() produces exactly that. A path with
     non-ASCII characters (an operator whose Windows account name has an accent,
     which is the realistic case) therefore works rather than being mangled. }
   FConnection.DatabaseName := AnsiString(aFileName);
   try
      FConnection.Open;
   except
      on E: Exception do
         begin
         { The diagnosis is APPENDED to the original message, never substituted
           for it: our guess about the cause must not hide what actually
           failed. }
         raise ELogDatabaseError.CreateFmt(
            'Could not open the contest log "%s". %s: %s'#13#10#13#10'%s',
            [aFileName, E.ClassName, E.Message,
             DiagnoseSQLiteLoad(SQLiteLibraryPath)]);
         end;
   end;
   FFileName := aFileName;
   ApplyPragmas;
end;

procedure TLogDatabase.ApplySchema;
var
   i: integer;
begin
   for i := Low(LOG_SCHEMA_STATEMENTS) to High(LOG_SCHEMA_STATEMENTS) do
      begin
      FConnection.ExecuteDirect(LOG_SCHEMA_STATEMENTS[i]);
      end;

   FTransaction.Commit;

   { AFTER the tables and after the commit: these are file-level properties and
     there is no point stamping a database whose schema failed to build. }
   StampIdentity;
end;

procedure TLogDatabase.CreateNew(const aFileName: string);
begin
   if FileExists(aFileName) then
      begin
      raise ELogDatabaseError.CreateFmt(
         'A contest log already exists at "%s". Creating one here would ' +
         'destroy it; open it instead, or choose another name.', [aFileName]);
      end;

   OpenConnection(aFileName);
   try
      ApplySchema;
   except
      on E: Exception do
         begin
         { A half-built database is worse than none: it opens, reports schema
           version 0, and looks like a log.  Roll the file back out. }
         Close;
         if FileExists(aFileName) then
            begin
            DeleteFile(aFileName);
            end;
         raise;
         end;
   end;
end;

procedure TLogDatabase.Open(const aFileName: string);
begin
   if not FileExists(aFileName) then
      begin
      raise ELogDatabaseError.CreateFmt(
         'There is no contest log at "%s". SQLite would create an empty ' +
         'database here rather than fail, so this is refused: an empty log ' +
         'that opens cleanly hides the real mistake.', [aFileName]);
      end;

   OpenConnection(aFileName);
   VerifyIdentity;
end;

procedure TLogDatabase.Close;
begin
   if FConnection.Connected then
      begin
      if FTransaction.Active then
         begin
         { Anything uncommitted at close is by definition not wanted -- a
           committed QSO is committed at the moment it is logged (plan 9b). }
         FTransaction.Rollback;
         end;
      FConnection.Close;
      end;
   FFileName := '';
   FJournalMode := '';
   FForeignKeysEnforced := False;
end;

function TLogDatabase.SchemaVersion: integer;
var
   q: TSQLQuery;
begin
   Result := 0;
   if not IsOpen then
      begin
      Exit;
      end;

   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FConnection;
      q.SQL.Text := 'PRAGMA user_version';
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsInteger;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

end.
