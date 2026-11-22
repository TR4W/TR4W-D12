unit uLogRestore;

(* RESTORING THE CONTEST LOG FROM A BACKUP -- the engine, stage 1 of issue 242.
  No user interface: the chooser (stage 2) is lcl-ui's, and NY4I asked for
  research into how a SQLite backup recovery should look before it is built.

  TWO QUESTIONS, ANSWERED HERE.

  1. WHAT CAN THIS LOG BE RESTORED FROM? ListRestoreCandidates looks in the
     backup folder (uAppPaths.BackupDir) and, when one is set, BACKUP
     DESTINATION, for the files the backup code writes for THIS log:

        <base> periodic.db                     the periodic backup
        <base> periodic.db.bak                 its previous generation
        <base> before clear <stamp>Z.db        taken before Clear Log
        <base> before catch-up <stamp>Z.db     taken before a server catch-up
        <base> before schema <n> to <m>.db     taken before an upgrade, and
        <base> before schema <n> to <m> 2.db   its numbered repeats
        any of them + .new                     a verified copy whose publish
                                               rename failed (TLogBackup.Run
                                               keeps it on purpose)

     <base> is uLogBackup.LogBackupBaseName of the log, so "X 2.db" and "X.db"
     never share a backup. The copier's destination folder holds the same
     final names plus .bak, so one classifier serves both folders.

     NOT LISTED: the copier's OUTBOX (<final>.<guid>.outbox) -- a transient
     copy of a local backup that is already listed, deleted once the copy
     lands; a .partial or .old (never a backup, by the copier's own rule); a
     set-aside <log>.damaged-<stamp> (the file a restore replaced); and the
     log itself.

     Each candidate is READ, never adopted: OpenToPeek for its schema
     (user_version), its QSO count and its newest QSO (uLogFileFacts'
     ReadLogQsoFacts, the New Contest grid's rule), then StagedBackupIsSound
     -- the very check a backup passes before it is published. Sorted newest
     first: by the newest QSO, then the file time (UTC), then the path. The
     file time alone would mislead: a destination copy's time is when it was
     COPIED.

  2. HOW IS THE LOG REPLACED WITHOUT LOSING ANYTHING? RestoreLogFromBackup,
     in this order, which is the contract:

        a. refuse a candidate that is the log itself
        b. the candidate must read (identity: a TR4W log, not newer than this
           build) and be sound; its schema may be OLDER -- the next Open
           migrates it, after its own backup-before-upgrade
        c. a staging file <log>.restoring is cleared, and the candidate is
           written there by TLogBackup.Run (VACUUM INTO on a read-only
           connection to .restoring.new, verified, renamed): the copy holds
           every committed row of the candidate, its -wal included
        d. the COPY is checked again on its own: sound, the same schema, the
           same QSO count, and nothing beside it
        e. THE DAMAGED LOG IS SET ASIDE, NEVER DELETED (NY4I's ruling on issue
           242): <log> and every sidecar of it (-wal, -shm, -journal) are
           RENAMED to <log>.damaged-<UTC stamp>Z plus the same suffix, so
           SQLite still pairs them if anyone opens the set-aside file. The
           database first, so a crash between the renames never leaves the
           log's name on a database whose WAL has gone. A rename that fails
           puts back every one already done
        f. nothing may be left under the log's name -- above all no -wal: a
           -wal left there would be REPLAYED INTO THE RESTORED DATABASE on its
           next open
        g. the staging file is renamed to the log; a failure puts the
           set-aside files back

     ON ANY FAILURE THE LOG IS LEFT EXACTLY AS IT WAS, and the staging file is
     removed. The one case that cannot promise that is a failed rename BACK
     during a rollback; the reason then names every file and where it is.
     No rename ever targets an existing name, so this behaves the same where
     rename(2) would replace and where MoveFileW would refuse.

     THE DAMAGED LOG IS NEVER OPENED. A write connection would checkpoint its
     WAL into it -- changing the evidence -- and a read gains nothing.

  THE PRECONDITION, AND WHO ENFORCES IT. Nothing in this process may have the
  log open: not the store, not the WRL worker's connection, not the periodic
  backup worker. On Windows a rename of an open file fails, and the original
  is left as it was; on Unix rename(2) succeeds under an open connection,
  which would go on writing into the set-aside file. This leaf cannot see the
  store, so the program's door is uLogStore.LogStoreRestoreLog, which refuses
  while the store has this log open or a periodic backup is running. Stage 2
  restores from the New Contest dialog, before any log is opened, and
  relaunches into the restored log afterwards (uOpenLogRelaunch).

  EXTERNAL-LOGGER DELIVERY STATE (issue 242 decision B, option (i), WARN
  ONLY -- recommended, not yet ruled). external_delivery lives in the log, so
  a restore rolls it back with the QSOs: a QSO sent after the backup is at
  Club Log / WRL / DXKeeper but not in the log, and a row the backup holds as
  pending may be sent again. Nothing is changed: the result carries
  DeliveryMayDiffer and a notice (uAppStrings.SLogRestoreDeliveryNotice) the
  caller shows. It is set when the backup holds any external_delivery row; a
  backup taken before the first delivery holds none, so a caller that knows a
  logger is configured should show the notice too.

  The file system is reached through TLogRestoreFiles, whose methods are
  virtual so a test can fail any one step. Never raises; every path sets the
  result's Reason. *)

{$I ..\tr4w.inc}

interface

uses
   Classes, Generics.Collections;

type
   (* WHICH BACKUP A FILE IS, by its name. *)
   TRestoreBackupKind = (rbkPeriodic, rbkBeforeClear, rbkBeforeCatchUp,
                         rbkBeforeUpgrade,
                         (* Tools > Correct Station Facts (issue 223) *)
                         rbkBeforeCorrection);

   (* WHERE IT WAS FOUND. *)
   TRestoreBackupPlace = (rbpBackupFolder, rbpDestination);

   (* ONE FILE THE LOG COULD BE RESTORED FROM. Times are UTC; 0 = unknown. *)
   TRestoreCandidate = class
   public
      Path: string;
      Kind: TRestoreBackupKind;
      (* <name>.bak: the previous generation of that backup. *)
      Previous: boolean;
      (* <name>.new: verified, but its publish rename failed. *)
      Staged: boolean;
      Place: TRestoreBackupPlace;
      FileTimeUTC: TDateTime;
      LastQSOTime: TDateTime;
      QSOCount: integer;
      SchemaVersion: integer;
      (* It opened, read-only, as a TR4W log this build can read. *)
      Readable: boolean;
      (* integrity_check and foreign_key_check passed. *)
      Sound: boolean;
      (* Why it is not readable or not sound; '' when it is both. *)
      Why: string;
      (* It holds at least one external_delivery row. *)
      HasDeliveryRows: boolean;
   end;

   TRestoreCandidateList = TObjectList<TRestoreCandidate>;

   (* A list of names or lines, UnicodeString throughout: FPC 3.2.2's
     TStringList holds AnsiString, and every Add would be a narrowing. *)
   TRestoreNameList = TList<string>;

   (* THE FILE SYSTEM, AS THE RESTORE SEES IT. Every method is virtual so a
     test can make one step fail; the defaults are the real thing. None of
     them raises. *)
   TLogRestoreFiles = class
   public
      (* The FILE names (no folder) in aFolder; nothing when it is missing. *)
      procedure ListFiles(const aFolder: string; aNames: TRestoreNameList); virtual;
      function FileTimeUTC(const aPath: string; out aTime: TDateTime): boolean; virtual;
      function FileExists(const aPath: string): boolean; virtual;
      function RenameFile(const aOld, aNew: string): boolean; virtual;
      function DeleteFile(const aPath: string): boolean; virtual;
      (* Fill aCandidate's facts from the file at aCandidate.Path: read-only,
        never adopted, never migrated. *)
      procedure Inspect(aCandidate: TRestoreCandidate); virtual;
      (* A verified copy of aSource at aTarget, which must not exist. *)
      function CopyVerified(const aSource, aTarget: string; out aWhy: string): boolean; virtual;
   end;

   (* WHAT A RESTORE DID. Ok only when the restored file is under the log's
     name. Reason is one paragraph for the operator (English, like every
     backup report); Steps is the trail for tr4w.log. *)
   TLogRestoreResult = class
   private
      FSteps: TRestoreNameList;
   public
      Ok: boolean;
      Reason: string;
      RestoredFrom: string;
      (* Where the replaced log went; '' when there was no log to replace. *)
      SetAsidePath: string;
      QSOCount: integer;
      (* WARN ONLY: see the unit header. *)
      DeliveryMayDiffer: boolean;
      DeliveryNotice: string;
      constructor Create;
      destructor Destroy; override;
      procedure Fail(const aReason: string);
      property Steps: TRestoreNameList read FSteps;
   end;

(* IS aFileName (a name, no folder) A BACKUP OF aLogFile? Pure. *)
function ClassifyRestoreName(const aLogFile, aFileName: string;
   out aKind: TRestoreBackupKind; out aPrevious, aStaged: boolean): boolean;

(* Newest QSO first, then the newer file, then the path. *)
function CompareRestoreCandidates(constref aLeft, aRight: TRestoreCandidate): integer;
procedure SortRestoreCandidates(aList: TRestoreCandidateList);

(* Do two names name one file? Case-insensitive on Windows only. *)
function RestoreSameFile(const aOne, aTwo: string): boolean;

(* <log>.restoring -- where the copy is made, beside the log. *)
function RestoreStagingFileName(const aLogFile: string): string;

(* <log>.damaged-<yyyy-mm-dd-hhnnss>Z for aUTC. Pure. *)
function DamagedLogBaseName(const aLogFile: string; aUTC: TDateTime): string;

(* DamagedLogBaseName, or with -2, -3 ... when that name, or any sidecar
  name beside it, is taken. *)
function DamagedLogFileName(const aLogFile: string; aUTC: TDateTime;
   aFiles: TLogRestoreFiles): string;

(* THE BACKUPS aLogFile COULD BE RESTORED FROM, newest first. aDestinationDir
  is BACKUP DESTINATION ('' = none; the same folder as aBackupDir is looked at
  once). A folder that is missing or unreachable contributes nothing. aFiles
  nil = the real file system. The caller owns the list. *)
function ListRestoreCandidates(const aLogFile, aBackupDir, aDestinationDir: string;
   aFiles: TLogRestoreFiles = nil): TRestoreCandidateList;

(* REPLACE aLogFile BY THE BACKUP aCandidate, SETTING THE OLD ONE ASIDE. See
  the header for the order and the precondition (nothing in this process has
  aLogFile open -- use uLogStore.LogStoreRestoreLog). aUTCNow names the
  set-aside file. aFiles nil = the real file system. The caller owns the
  result. Never raises. *)
function RestoreLogFromBackup(const aLogFile, aCandidate: string;
   aUTCNow: TDateTime; aFiles: TLogRestoreFiles = nil): TLogRestoreResult;

const
   RESTORE_STAGING_SUFFIX = '.restoring';
   RESTORE_DAMAGED_INFIX = '.damaged-';

implementation

uses
   db, sqldb, Generics.Defaults, DateUtils, SysUtils,
   uAppStrings, uLogDatabase, uLogSchema, uLogBackup, uLogFileFacts,
   uBackupCopier;

const
   (* The suffixes a set-aside moves with the database, in the order they
     move: the database FIRST (see the header, step e). *)
   RESTORE_MOVED_SUFFIXES: array[0..3] of string = ('', '-wal', '-shm', '-journal');

(* ---------------------------------------------------------------------------
  names
  --------------------------------------------------------------------------- *)

function EndsWithText(const aText, aSuffix: string): boolean;
begin
   Result := (Length(aText) >= Length(aSuffix)) and
             UnicodeSameText(Copy(aText, Length(aText) - Length(aSuffix) + 1,
                                  Length(aSuffix)), aSuffix);
end;

function StartsWithExactly(const aText, aPrefix: string): boolean;
begin
   Result := Copy(aText, 1, Length(aPrefix)) = aPrefix;
end;

(* Only digits, spaces and the letters of ' to ': what follows ' before schema '
  in a schema backup's name. LogBackupBaseName has already proved the shape;
  this keeps a stacked name (one that also ends in ' periodic') out. *)
function OnlySchemaSuffixCharacters(const aText: string): boolean;
var
   i: integer;
begin
   Result := aText <> '';
   for i := 1 to Length(aText) do
      begin
      if not (((aText[i] >= '0') and (aText[i] <= '9')) or
              (aText[i] = ' ') or (aText[i] = 't') or (aText[i] = 'o')) then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

(* aStem (no .db) is ONE backup suffix on a name whose base is aLogBase. *)
function KindOfStem(const aStem, aLogBase: string;
   out aKind: TRestoreBackupKind): boolean;
var
   base: string;
   rest: string;
begin
   Result := False;
   aKind := rbkPeriodic;
   base := LogBackupBaseName(aStem);
   if (Length(base) = Length(aStem)) or
      (not UnicodeSameText(base, aLogBase)) then
      begin
      Exit;
      end;

   rest := Copy(aStem, Length(base) + 1, Length(aStem) - Length(base));
   if rest = PERIODIC_BACKUP_SUFFIX then
      begin
      aKind := rbkPeriodic;
      Result := True;
      end
   else if StartsWithExactly(rest, CLEAR_BACKUP_INFIX) and
           (Length(rest) = Length(CLEAR_BACKUP_INFIX) + Length(CLEAR_BACKUP_STAMP_SHAPE)) then
      begin
      aKind := rbkBeforeClear;
      Result := True;
      end
   else if StartsWithExactly(rest, CATCHUP_BACKUP_INFIX) and
           (Length(rest) = Length(CATCHUP_BACKUP_INFIX) + Length(CLEAR_BACKUP_STAMP_SHAPE)) then
      begin
      aKind := rbkBeforeCatchUp;
      Result := True;
      end
   else if StartsWithExactly(rest, CORRECTION_BACKUP_INFIX) and
           (Length(rest) = Length(CORRECTION_BACKUP_INFIX) + Length(CLEAR_BACKUP_STAMP_SHAPE)) then
      begin
      aKind := rbkBeforeCorrection;
      Result := True;
      end
   else if StartsWithExactly(rest, SCHEMA_BACKUP_INFIX) and
           OnlySchemaSuffixCharacters(Copy(rest, Length(SCHEMA_BACKUP_INFIX) + 1,
                                           Length(rest) - Length(SCHEMA_BACKUP_INFIX))) then
      begin
      aKind := rbkBeforeUpgrade;
      Result := True;
      end;
end;

function ClassifyRestoreName(const aLogFile, aFileName: string;
   out aKind: TRestoreBackupKind; out aPrevious, aStaged: boolean): boolean;
var
   name: string;
   stem: string;
   logBase: string;
   digits: integer;
begin
   Result := False;
   aKind := rbkPeriodic;
   aPrevious := False;
   aStaged := False;

   name := aFileName;
   if EndsWithText(name, '.bak') then
      begin
      aPrevious := True;
      name := Copy(name, 1, Length(name) - Length('.bak'));
      end
   else if EndsWithText(name, '.new') then
      begin
      aStaged := True;
      name := Copy(name, 1, Length(name) - Length('.new'));
      end;

   if not EndsWithText(name, '.db') then
      begin
      Exit;
      end;
   stem := Copy(name, 1, Length(name) - Length('.db'));
   logBase := LogBackupBaseName(aLogFile);

   if KindOfStem(stem, logBase, aKind) then
      begin
      Result := True;
      Exit;
      end;

   (* A NUMBERED SCHEMA BACKUP: "<...> before schema 2 to 13 2". The number
     is uLogNaming.FirstFreeLogFileName's, and LogBackupBaseName does not
     strip it, so it is taken off here -- for that kind ONLY, because a log
     may itself be called "X 2" and its backups are not X's. *)
   digits := 0;
   while (digits < Length(stem)) and
         (stem[Length(stem) - digits] >= '0') and
         (stem[Length(stem) - digits] <= '9') do
      begin
      inc(digits);
      end;
   if (digits > 0) and
      (Length(stem) > digits + 1) and
      (stem[Length(stem) - digits] = ' ') then
      begin
      stem := Copy(stem, 1, Length(stem) - digits - 1);
      if KindOfStem(stem, logBase, aKind) and
         (aKind = rbkBeforeUpgrade) then
         begin
         Result := True;
         end;
      end;
end;

function CompareRestoreCandidates(constref aLeft, aRight: TRestoreCandidate): integer;
begin
   Result := 0;
   if aLeft.LastQSOTime > aRight.LastQSOTime then
      begin
      Result := -1;
      end
   else if aLeft.LastQSOTime < aRight.LastQSOTime then
      begin
      Result := 1;
      end
   else if aLeft.FileTimeUTC > aRight.FileTimeUTC then
      begin
      Result := -1;
      end
   else if aLeft.FileTimeUTC < aRight.FileTimeUTC then
      begin
      Result := 1;
      end;

   if Result = 0 then
      begin
      Result := UnicodeCompareStr(aLeft.Path, aRight.Path);
      end;
end;

procedure SortRestoreCandidates(aList: TRestoreCandidateList);
begin
   aList.Sort(TComparer<TRestoreCandidate>.Construct(CompareRestoreCandidates));
end;

function RestoreSameFile(const aOne, aTwo: string): boolean;
var
   one: string;
   two: string;
begin
   one := ExpandFileName(aOne);
   two := ExpandFileName(aTwo);
   {$IFDEF WINDOWS}
   Result := UnicodeSameText(one, two);
   {$ELSE}
   Result := one = two;
   {$ENDIF}
end;

function SameFolder(const aOne, aTwo: string): boolean;
begin
   Result := RestoreSameFile(IncludeTrailingPathDelimiter(aOne),
                             IncludeTrailingPathDelimiter(aTwo));
end;

function RestoreStagingFileName(const aLogFile: string): string;
begin
   Result := aLogFile + RESTORE_STAGING_SUFFIX;
end;

function DamagedLogBaseName(const aLogFile: string; aUTC: TDateTime): string;
begin
   (* '-' is a literal to FormatDateTime; no locale separator is used. *)
   Result := aLogFile + RESTORE_DAMAGED_INFIX +
             string(FormatDateTime('yyyy-mm-dd-hhnnss', aUTC)) + 'Z';
end;

(* Is aBase, or any sidecar name beside it, taken? *)
function SetAsideNameTaken(const aBase: string; aFiles: TLogRestoreFiles): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(RESTORE_MOVED_SUFFIXES) to High(RESTORE_MOVED_SUFFIXES) do
      begin
      if aFiles.FileExists(aBase + RESTORE_MOVED_SUFFIXES[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function DamagedLogFileName(const aLogFile: string; aUTC: TDateTime;
   aFiles: TLogRestoreFiles): string;
var
   base: string;
   n: integer;
begin
   base := DamagedLogBaseName(aLogFile, aUTC);
   Result := base;
   n := 2;
   (* Past 9999 the last name is answered even though it is taken: the
     set-aside then refuses to rename onto it, and the restore stops with the
     log untouched -- a broken test of existence, not a real folder. *)
   while SetAsideNameTaken(Result, aFiles) and (n <= 9999) do
      begin
      Result := base + '-' + IntToStr(n);
      inc(n);
      end;
end;

(* ---------------------------------------------------------------------------
  the file system
  --------------------------------------------------------------------------- *)

procedure TLogRestoreFiles.ListFiles(const aFolder: string; aNames: TRestoreNameList);
var
   (* The UnicodeString search record, so the names need no conversion. *)
   found: TUnicodeSearchRec;
begin
   if (Trim(aFolder) = '') or
      (not DirectoryExists(aFolder)) then
      begin
      Exit;
      end;
   if FindFirst(IncludeTrailingPathDelimiter(aFolder) + '*', SysUtils.faAnyFile, found) = 0 then
      begin
      try
         repeat
            if (found.Attr and SysUtils.faDirectory) = 0 then
               begin
               aNames.Add(found.Name);
               end;
         until FindNext(found) <> 0;
      finally
         FindClose(found);
      end;
      end;
end;

function TLogRestoreFiles.FileTimeUTC(const aPath: string; out aTime: TDateTime): boolean;
var
   local: TDateTime;
begin
   aTime := 0;
   Result := FileAge(aPath, local);
   if Result then
      begin
      (* FileAge answers local time. *)
      aTime := LocalTimeToUniversal(local);
      end;
end;

function TLogRestoreFiles.FileExists(const aPath: string): boolean;
begin
   Result := SysUtils.FileExists(aPath);
end;

(* THE RENAME IS THE BACKUP COPIER'S OWN (TBackupFileOps.RenameFile), not a
  second raw call here: Count-LiveWrites allows no new one, and a rename of a
  file this program owns is the one operation both need. *)
function TLogRestoreFiles.RenameFile(const aOld, aNew: string): boolean;
var
   ops: TBackupFileOps;
begin
   ops := TBackupFileOps.Create;
   try
      Result := ops.RenameFile(aOld, aNew);
   finally
      ops.Free;
   end;
end;

function TLogRestoreFiles.DeleteFile(const aPath: string): boolean;
begin
   Result := SysUtils.DeleteFile(aPath);
end;

(* Does the log on aDatabase hold any external_delivery row? The table exists
  from schema 5; below that the answer is no. *)
function LogHasDeliveryRows(aDatabase: TLogDatabase): boolean;
var
   q: TSQLQuery;
begin
   Result := False;
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDatabase.Connection;
      q.Transaction := aDatabase.Transaction;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text := 'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' ' +
                    'AND name = ''external_delivery''';
      q.Open;
      if q.EOF or (q.Fields[0].AsInteger = 0) then
         begin
         q.Close;
         Exit;
         end;
      q.Close;

      q.SQL.Text := 'SELECT EXISTS (SELECT 1 FROM external_delivery)';
      q.Open;
      Result := (not q.EOF) and (q.Fields[0].AsInteger <> 0);
      q.Close;
   finally
      q.Free;
   end;
end;

procedure TLogRestoreFiles.Inspect(aCandidate: TRestoreCandidate);
var
   log: TLogDatabase;
   why: string;
begin
   aCandidate.Readable := False;
   aCandidate.Sound := False;
   aCandidate.Why := '';
   aCandidate.QSOCount := 0;
   aCandidate.LastQSOTime := 0;
   aCandidate.SchemaVersion := 0;
   aCandidate.HasDeliveryRows := False;

   (* THE FACTS, ON A PEEK: immutable when nothing is beside the file, so
     nothing is left in the backup folder. VerifyIdentity inside it refuses a
     database that is not a TR4W log, and one from a newer build. *)
   log := TLogDatabase.Create;
   try
      try
         log.OpenToPeek(aCandidate.Path);
         aCandidate.SchemaVersion := log.SchemaVersion;
         ReadLogQsoFacts(log, aCandidate.QSOCount, aCandidate.LastQSOTime);
         aCandidate.HasDeliveryRows := LogHasDeliveryRows(log);
         aCandidate.Readable := True;
      except
         on E: Exception do
            begin
            aCandidate.Why := E.Message;
            end;
      end;
   finally
      log.Free;
   end;

   if not aCandidate.Readable then
      begin
      Exit;
      end;

   (* THE CHECK A BACKUP PASSES BEFORE IT IS PUBLISHED, on its own read-only
     connection. *)
   aCandidate.Sound := StagedBackupIsSound(aCandidate.Path, why);
   if not aCandidate.Sound then
      begin
      aCandidate.Why := why;
      end;
end;

function TLogRestoreFiles.CopyVerified(const aSource, aTarget: string;
   out aWhy: string): boolean;
var
   backup: TLogFileBackup;
begin
   (* TLogBackup.Run: VACUUM INTO <target>.new on a read-only connection to
     the source, integrity-checked on its own connection, renamed. The same
     staged copy every backup makes, not a second implementation. Run never
     raises. *)
   backup := TLogFileBackup.Create(aSource);
   try
      Result := backup.Run(aTarget, aWhy);
   finally
      backup.Free;
   end;
end;

(* ---------------------------------------------------------------------------
  the result
  --------------------------------------------------------------------------- *)

constructor TLogRestoreResult.Create;
begin
   inherited Create;
   FSteps := TRestoreNameList.Create;
end;

destructor TLogRestoreResult.Destroy;
begin
   FSteps.Free;
   inherited Destroy;
end;

procedure TLogRestoreResult.Fail(const aReason: string);
begin
   Ok := False;
   Reason := aReason;
   FSteps.Add('refused: ' + aReason);
end;

(* ---------------------------------------------------------------------------
  listing
  --------------------------------------------------------------------------- *)

procedure AddCandidatesIn(const aLogFile, aFolder: string;
   aPlace: TRestoreBackupPlace; aFiles: TLogRestoreFiles;
   aList: TRestoreCandidateList);
var
   names: TRestoreNameList;
   i: integer;
   kind: TRestoreBackupKind;
   previous: boolean;
   staged: boolean;
   candidate: TRestoreCandidate;
   stamp: TDateTime;
begin
   names := TRestoreNameList.Create;
   try
      aFiles.ListFiles(aFolder, names);
      for i := 0 to names.Count - 1 do
         begin
         if not ClassifyRestoreName(aLogFile, names[i], kind, previous, staged) then
            begin
            Continue;
            end;
         candidate := TRestoreCandidate.Create;
         aList.Add(candidate);
         candidate.Path := IncludeTrailingPathDelimiter(aFolder) + names[i];
         candidate.Kind := kind;
         candidate.Previous := previous;
         candidate.Staged := staged;
         candidate.Place := aPlace;
         if aFiles.FileTimeUTC(candidate.Path, stamp) then
            begin
            candidate.FileTimeUTC := stamp;
            end;
         aFiles.Inspect(candidate);
         end;
   finally
      names.Free;
   end;
end;

function ListRestoreCandidates(const aLogFile, aBackupDir, aDestinationDir: string;
   aFiles: TLogRestoreFiles): TRestoreCandidateList;
var
   files: TLogRestoreFiles;
begin
   Result := TRestoreCandidateList.Create(True);
   files := aFiles;
   if files = nil then
      begin
      files := TLogRestoreFiles.Create;
      end;
   try
      try
         AddCandidatesIn(aLogFile, aBackupDir, rbpBackupFolder, files, Result);
         if (Trim(aDestinationDir) <> '') and
            ((Trim(aBackupDir) = '') or (not SameFolder(aBackupDir, aDestinationDir))) then
            begin
            AddCandidatesIn(aLogFile, aDestinationDir, rbpDestination, files, Result);
            end;
         SortRestoreCandidates(Result);
      except
         on E: Exception do
            begin
            (* A folder that fails part-way leaves what was read; listing is
              a question, never a reason to fail the caller. *)
            end;
      end;
   finally
      if files <> aFiles then
         begin
         files.Free;
         end;
   end;
end;

(* ---------------------------------------------------------------------------
  restoring
  --------------------------------------------------------------------------- *)

(* Remove the staging file and anything beside it. False when one will not
  go -- the restore must not then go on, since Run would displace it. *)
function ClearStaging(const aStaging: string; aFiles: TLogRestoreFiles;
   out aWhy: string): boolean;
var
   i: integer;
   path: string;
begin
   Result := True;
   aWhy := '';
   for i := Low(RESTORE_MOVED_SUFFIXES) to High(RESTORE_MOVED_SUFFIXES) do
      begin
      path := aStaging + RESTORE_MOVED_SUFFIXES[i];
      if aFiles.FileExists(path) and
         (not aFiles.DeleteFile(path)) then
         begin
         Result := False;
         aWhy := UnicodeFormat('%s could not be deleted', [path]);
         end;
      end;
   (* A .bak only exists if Run ever displaced a staging file; never kept. *)
   path := aStaging + '.bak';
   if aFiles.FileExists(path) and
      (not aFiles.DeleteFile(path)) then
      begin
      Result := False;
      aWhy := UnicodeFormat('%s could not be deleted', [path]);
      end;
end;

(* Put back every rename in aFrom/aTo, newest first. '' when all went back,
  else a sentence naming each file left where it is. *)
function PutBack(aFrom, aTo: TRestoreNameList; aFiles: TLogRestoreFiles): string;
var
   i: integer;
begin
   Result := '';
   for i := aFrom.Count - 1 downto 0 do
      begin
      if aFiles.FileExists(aFrom[i]) or
         (not aFiles.RenameFile(aTo[i], aFrom[i])) then
         begin
         Result := Result + UnicodeFormat(' %s is at %s and must be renamed back to %s by hand.',
                                   [aFrom[i], aTo[i], aFrom[i]]);
         end;
      end;
end;

(* Step e: move <log> and its sidecars to aAside + the same suffix. On a
  failure every move is put back; aWhy says what happened. *)
function SetAside(const aLogFile, aAside: string; aFiles: TLogRestoreFiles;
   aFrom, aTo: TRestoreNameList; out aWhy: string): boolean;
var
   i: integer;
   source: string;
   target: string;
   leftOut: string;
begin
   Result := True;
   aWhy := '';
   for i := Low(RESTORE_MOVED_SUFFIXES) to High(RESTORE_MOVED_SUFFIXES) do
      begin
      source := aLogFile + RESTORE_MOVED_SUFFIXES[i];
      target := aAside + RESTORE_MOVED_SUFFIXES[i];
      if not aFiles.FileExists(source) then
         begin
         Continue;
         end;
      if aFiles.FileExists(target) or
         (not aFiles.RenameFile(source, target)) then
         begin
         Result := False;
         aWhy := UnicodeFormat('%s could not be renamed to %s', [source, target]);
         leftOut := PutBack(aFrom, aTo, aFiles);
         if leftOut <> '' then
            begin
            aWhy := aWhy + ', and putting the log back FAILED:' + leftOut;
            end;
         aFrom.Clear;
         aTo.Clear;
         Exit;
         end;
      aFrom.Add(source);
      aTo.Add(target);
      end;
end;

(* Is anything left under aPath's sidecar names? The first one found, or ''. *)
function SidecarLeft(const aPath: string; aFiles: TLogRestoreFiles): string;
var
   i: integer;
begin
   Result := '';
   for i := Low(LOG_SIDECAR_SUFFIXES) to High(LOG_SIDECAR_SUFFIXES) do
      begin
      if aFiles.FileExists(aPath + LOG_SIDECAR_SUFFIXES[i]) then
         begin
         Result := aPath + LOG_SIDECAR_SUFFIXES[i];
         Exit;
         end;
      end;
end;

(* The body of RestoreLogFromBackup, with the objects in hand. *)
procedure RunRestore(const aLogFile, aCandidate: string; aUTCNow: TDateTime;
   aFiles: TLogRestoreFiles; aResult: TLogRestoreResult;
   aSource, aCopy: TRestoreCandidate; aFrom, aTo: TRestoreNameList);
const
   UNCHANGED = ' The log was not changed.';
var
   staging: string;
   aside: string;
   why: string;
   cleared: string;
   leftOver: string;
begin
   if (Trim(aLogFile) = '') or (Trim(aCandidate) = '') then
      begin
      aResult.Fail('No log or no backup was named, so nothing was restored.');
      Exit;
      end;

   (* a. *)
   if RestoreSameFile(aLogFile, aCandidate) then
      begin
      aResult.Fail(UnicodeFormat('%s is the log itself, not a backup of it, so nothing ' +
                          'was restored.', [aCandidate]));
      Exit;
      end;
   if not aFiles.FileExists(aCandidate) then
      begin
      aResult.Fail(UnicodeFormat('The backup %s is not there, so nothing was restored.' +
                          UNCHANGED, [aCandidate]));
      Exit;
      end;

   (* b. *)
   aSource.Path := aCandidate;
   aFiles.Inspect(aSource);
   if not aSource.Readable then
      begin
      aResult.Fail(UnicodeFormat('The backup %s could not be read as a TR4W log (%s), ' +
                          'so nothing was restored.' + UNCHANGED,
                          [aCandidate, aSource.Why]));
      Exit;
      end;
   if aSource.SchemaVersion > LOG_SCHEMA_VERSION then
      begin
      aResult.Fail(UnicodeFormat('The backup %s is schema %d, newer than this build ' +
                          'reads (%d), so nothing was restored.' + UNCHANGED,
                          [aCandidate, aSource.SchemaVersion, LOG_SCHEMA_VERSION]));
      Exit;
      end;
   if not aSource.Sound then
      begin
      aResult.Fail(UnicodeFormat('The backup %s failed its integrity check (%s), so ' +
                          'nothing was restored.' + UNCHANGED,
                          [aCandidate, aSource.Why]));
      Exit;
      end;
   aResult.QSOCount := aSource.QSOCount;
   aResult.Steps.Add(UnicodeFormat('backup %s is sound: schema %d, %d QSOs',
                            [aCandidate, aSource.SchemaVersion, aSource.QSOCount]));

   (* c. *)
   staging := RestoreStagingFileName(aLogFile);
   if not ClearStaging(staging, aFiles, why) then
      begin
      aResult.Fail(UnicodeFormat('A copy left by an earlier restore could not be ' +
                          'removed (%s), so nothing was restored.' + UNCHANGED, [why]));
      Exit;
      end;
   if not aFiles.CopyVerified(aCandidate, staging, why) then
      begin
      ClearStaging(staging, aFiles, cleared);
      aResult.Fail(UnicodeFormat('The backup could not be copied beside the log (%s), ' +
                          'so nothing was restored.' + UNCHANGED, [why]));
      Exit;
      end;
   aResult.Steps.Add('copied to ' + staging);

   (* d. *)
   aCopy.Path := staging;
   aFiles.Inspect(aCopy);
   leftOver := SidecarLeft(staging, aFiles);
   if (not aCopy.Readable) or
      (not aCopy.Sound) or
      (aCopy.SchemaVersion <> aSource.SchemaVersion) or
      (aCopy.QSOCount <> aSource.QSOCount) or
      (leftOver <> '') then
      begin
      why := aCopy.Why;
      if why = '' then
         begin
         why := UnicodeFormat('schema %d and %d QSOs, against the backup''s %d and %d',
                       [aCopy.SchemaVersion, aCopy.QSOCount,
                        aSource.SchemaVersion, aSource.QSOCount]);
         end;
      if leftOver <> '' then
         begin
         why := why + '; ' + leftOver + ' is beside it';
         end;
      ClearStaging(staging, aFiles, cleared);
      aResult.Fail(UnicodeFormat('The copy of the backup did not verify (%s), so ' +
                          'nothing was restored.' + UNCHANGED, [why]));
      Exit;
      end;
   aResult.Steps.Add('the copy verified');

   (* e. *)
   aside := DamagedLogFileName(aLogFile, aUTCNow, aFiles);
   if not SetAside(aLogFile, aside, aFiles, aFrom, aTo, why) then
      begin
      ClearStaging(staging, aFiles, cleared);
      aResult.Fail(UnicodeFormat('The log could not be set aside (%s), so nothing was ' +
                          'restored.', [why]));
      Exit;
      end;
   if aFrom.Count > 0 then
      begin
      aResult.SetAsidePath := aside;
      aResult.Steps.Add(UnicodeFormat('%s set aside as %s (%d file(s))',
                               [aLogFile, aside, aFrom.Count]));
      end
   else
      begin
      aResult.Steps.Add('there was no log to set aside');
      end;

   (* f. *)
   leftOver := SidecarLeft(aLogFile, aFiles);
   if aFiles.FileExists(aLogFile) then
      begin
      leftOver := aLogFile;
      end;
   if leftOver <> '' then
      begin
      why := PutBack(aFrom, aTo, aFiles);
      ClearStaging(staging, aFiles, cleared);
      aResult.SetAsidePath := '';
      aResult.Fail(UnicodeFormat('%s is still under the log''s name, so the backup was ' +
                          'not put in place.%s', [leftOver, why]));
      Exit;
      end;

   (* g. *)
   if not aFiles.RenameFile(staging, aLogFile) then
      begin
      why := PutBack(aFrom, aTo, aFiles);
      ClearStaging(staging, aFiles, cleared);
      aResult.SetAsidePath := '';
      if why = '' then
         begin
         aResult.Fail(UnicodeFormat('The verified copy could not be renamed to %s, so ' +
                             'the log was put back as it was.', [aLogFile]));
         end
      else
         begin
         aResult.Fail(UnicodeFormat('The verified copy could not be renamed to %s, and ' +
                             'putting the log back FAILED:%s', [aLogFile, why]));
         end;
      Exit;
      end;

   aResult.Ok := True;
   if aResult.SetAsidePath <> '' then
      begin
      aResult.Reason := UnicodeFormat('The log was restored from %s (%d QSOs). The log ' +
                               'it replaced was kept as %s.',
                               [aCandidate, aSource.QSOCount, aResult.SetAsidePath]);
      end
   else
      begin
      aResult.Reason := UnicodeFormat('The log was restored from %s (%d QSOs).',
                               [aCandidate, aSource.QSOCount]);
      end;
   aResult.Steps.Add('restored: ' + aResult.Reason);

   if aSource.HasDeliveryRows then
      begin
      aResult.DeliveryMayDiffer := True;
      aResult.DeliveryNotice := SLogRestoreDeliveryNotice;
      end;
end;

function RestoreLogFromBackup(const aLogFile, aCandidate: string;
   aUTCNow: TDateTime; aFiles: TLogRestoreFiles): TLogRestoreResult;
var
   files: TLogRestoreFiles;
   source: TRestoreCandidate;
   copied: TRestoreCandidate;
   moveFrom: TRestoreNameList;
   moveTo: TRestoreNameList;
   leftOut: string;
begin
   Result := TLogRestoreResult.Create;
   Result.RestoredFrom := aCandidate;
   files := aFiles;
   if files = nil then
      begin
      files := TLogRestoreFiles.Create;
      end;
   source := TRestoreCandidate.Create;
   copied := TRestoreCandidate.Create;
   moveFrom := TRestoreNameList.Create;
   moveTo := TRestoreNameList.Create;
   try
      try
         RunRestore(aLogFile, aCandidate, aUTCNow, files, Result, source, copied,
                    moveFrom, moveTo);
      except
         on E: Exception do
            begin
            (* Nothing above raises by design; this is the backstop. Whatever
              was set aside goes back unless the restore had finished. *)
            if not Result.Ok then
               begin
               leftOut := PutBack(moveFrom, moveTo, files);
               Result.SetAsidePath := '';
               Result.Fail(UnicodeFormat('The restore failed: %s.%s', [E.Message, leftOut]));
               end;
            end;
      end;
   finally
      moveTo.Free;
      moveFrom.Free;
      copied.Free;
      source.Free;
      if files <> aFiles then
         begin
         files.Free;
         end;
   end;
end;

end.
