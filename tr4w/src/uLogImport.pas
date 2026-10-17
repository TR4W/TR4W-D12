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

(* A BINARY .trw LOG -> A SQLite CONTEST LOG.

  Task A3 of docs\SQLITE_MIGRATION_TASKS.md, and section 10 of the schema plan
  is emphatic that this is not a convenience feature:

    the golden corpus is the regression oracle and it reads binary .trw through
    the export path, so the migration has to keep that oracle working -- an
    importer is how the corpus keeps running, and how existing operators keep
    their logs.

  It is also the one piece that is genuinely transitional. It reads a format we
  are leaving, and it is unavoidable in every possible ordering.

  IT IMPORTS EVERY RECORD, NOT EVERY QSO, and that distinction is the whole
  design. GoodLookingQSO -- not deleted, not skipped, a real band and mode, kind
  rkQSO -- is what ExportToADIF EMITS. It is an EXPORT filter. Applying it here
  would silently discard:

    deleted QSOs   kept on purpose. An operator deletes a contact and the log
                   still records that it happened; Cabrillo X-QSO and the
                   other station's NIL protection depend on it.
    skipped QSOs   folded into ceQSO_Deleted -- see ceQSO_Skiped in VC.pas.
    QTC records    rkQTCR / rkQTCS -- a whole WAE contest's traffic.
    notes          rkNote.

  The columns for all of those exist (deleted, is_skipped, record_kind), so the
  database holds what the LOG holds and the filtering happens where it always
  did: at export. An importer that quietly dropped a quarter of a WAE log would
  be the worst kind of defect -- it produces a smaller number that looks fine. *)
unit uLogImport;

{$I tr4w.inc}

interface

uses
   SysUtils, VC, uLogDatabase, uLogRepository, uLogBinaryFile;

type
   TLogImportResult = record
      Ok: boolean;

      (* What the file held and what reached the database. They differ only by
        RecordsFailed, which is normally zero. *)
      RecordsRead: integer;
      RecordsWritten: integer;
      RecordsFailed: integer;

      (* Broken out because they are the numbers an operator recognises. *)
      QSOs: integer;
      QTCs: integer;
      Notes: integer;
      Deleted: integer;
      Skipped: integer;

      (* HOW MANY WOULD REACH A CABRILLO FILE -- GoodLookingQSO's count.

        Reported because without it the summary misleads. A florida_qp log
        imported as "5 record(s): 5 QSO, 0 QTC, 0 note, 0 deleted" -- every
        number true -- while TWO of those five are skipped and would never be
        exported. The reader concludes the log is five good QSOs.

        This is the number an operator would compare against his own count, so
        it is the one that has to be there. *)
      Exportable: integer;

      (* Empty when Ok. Otherwise a sentence, already fit to show. *)
      Message: string;

      (* A STAGED FILE LEFT BY AN EARLIER IMPORT THAT NEVER FINISHED, and
        deleted before this one began: its path, or empty when there was none.
        The caller says so in its own log, because this unit has no logger
        (it is linked by tools that assign none). See ImportBinaryLog. *)
      DiscardedStaged: string;
   end;

   (* A FAULT SEAM, FOR THE TESTS ONLY. Called after each record is saved,
     with its 1-based number; raising from it is that record failing, exactly
     as a failed write would. Production passes nothing. The precedent is
     uLogContestStatements' aIsRetired, which the section 9c audit used the
     same way: a routine with no seam cannot have its failure path pinned. *)
   TLogImportRecordHook = procedure(aRecordNumber: integer) of object;

(* WHERE AN IMPORT IS BUILT BEFORE IT BECOMES THE LOG: aTargetFile plus
  '.importing'. Public so a caller can name it in a report and a test can look
  for it. *)
function StagedImportFileName(const aTargetFile: string): string;

(* Reads aSourceFile and writes a NEW log at aTargetFile.

  Refuses an existing target -- importing over somebody's log is exactly the
  mistake worth refusing.

  ALL OR NOTHING, AT THE LEVEL OF THE FILE (NY4I, 2026-10-14). The import is
  built under StagedImportFileName and renamed to aTargetFile only once every
  record is written, the one transaction has committed and the database is
  closed with no -wal or -shm left beside it. So aTargetFile either does not
  exist or is a complete import -- there is no moment at which it is a partial
  one. A record that fails, a commit that fails or a rename that fails leaves
  NO aTargetFile, and Ok = False with a sentence that says which.

  A staged file left by an earlier run that died part way (a crash, a power
  cut) is deleted first and the import starts again from aSourceFile; its path
  comes back in DiscardedStaged.

  Never raises for a bad source: a failed import comes back as Ok = False with a
  message, because an operator importing a season of logs needs to know which
  one would not read and still get the rest. *)
function ImportBinaryLog(const aSourceFile, aTargetFile: string;
                         aAfterRecord: TLogImportRecordHook = nil): TLogImportResult;

implementation

uses
   uContestRegistry;   (* ContestLegacyNumber -- the first record's contest *)

const
   (* WHAT SQLITE MAY LEAVE BESIDE A DATABASE. The write-ahead log and its
     index, because every log runs in WAL mode (TLogDatabase.ApplyPragmas);
     and the rollback journal, which is what SQLite uses when it refuses WAL --
     a network share, for one. *)
   SQLITE_SIDECARS: array[0..2] of string = ('-wal', '-shm', '-journal');

function StagedImportFileName(const aTargetFile: string): string;
begin
   Result := aTargetFile + '.importing';
end;

(* The first sidecar of aDatabase that exists, or empty. *)
function FirstSidecarPresent(const aDatabase: string): string;
var
   i: integer;
begin
   Result := '';
   for i := Low(SQLITE_SIDECARS) to High(SQLITE_SIDECARS) do
      begin
      if FileExists(aDatabase + SQLITE_SIDECARS[i]) then
         begin
         Result := aDatabase + SQLITE_SIDECARS[i];
         Exit;
         end;
      end;
end;

(* Deletes aStaged and every sidecar of it. True only when none is left.

  THE SIDECARS GO FIRST, AND A SIDECAR THAT WILL NOT GO IS A REFUSAL. A -wal
  carries no record of which database it belongs to, so SQLite opening a NEW
  file beside an old -wal would try to recover that log's frames into it.
  Deleting the database and leaving its -wal behind would therefore be worse
  than deleting nothing. *)
function DeleteStagedFiles(const aStaged: string): boolean;
var
   i: integer;
begin
   for i := Low(SQLITE_SIDECARS) to High(SQLITE_SIDECARS) do
      begin
      if FileExists(aStaged + SQLITE_SIDECARS[i]) then
         begin
         DeleteFile(aStaged + SQLITE_SIDECARS[i]);
         end;
      end;
   if (FirstSidecarPresent(aStaged) = '') and FileExists(aStaged) then
      begin
      DeleteFile(aStaged);
      end;
   Result := (FirstSidecarPresent(aStaged) = '') and (not FileExists(aStaged));
end;

(* EVERY RECORD OF aReader INTO A NEW DATABASE AT aStaged, IN ONE TRANSACTION.

  True only when every record was written AND the transaction committed AND
  the database closed cleanly. Anything else is False with the first failure
  in aFailure. Never raises.

  THE DATABASE IS CLOSED BEFORE THIS RETURNS, on every path, because the
  caller's next question -- is anything left beside the file? -- and its
  rename both need it closed: SQLite removes -wal and -shm when the last
  connection closes, and Windows will not rename an open file. *)
function BuildStagedLog(aReader: TLogBinaryReader; const aStaged: string;
                        aAfterRecord: TLogImportRecordHook;
                        var aResult: TLogImportResult;
                        out aFailure: string): boolean;
var
   db: TLogDatabase;
   repo: TLogRepository;
   rec: ContestExchange;
   legacyNumber: integer;
begin
   Result := False;
   aFailure := '';

   db := TLogDatabase.Create;
   try
      try
         db.CreateNew(aStaged);

         repo := TLogRepository.Create(db);
         try
            (* ONE TRANSACTION FOR THE WHOLE IMPORT. Ten thousand separate
              commits would each fsync -- section 8 sets synchronous = FULL --
              and turn a second into minutes. The per-QSO commit that section 9b
              argues for is about LOGGING, where losing the contact in progress
              is the thing being prevented; an import that fails half way should
              leave no log at all.

              AND NOW IT DOES LEAVE NO LOG (section 9c, ruling of 2026-10-14).
              The transaction gave "no QSOs", not "no log": CreateNew had
              already made and committed the FILE, and uLogStore.EnsureOpen
              adopts an existing file as the log, so a crash before the Commit
              left an empty log that the next start opened instead of migrating
              the .TRW again. This file is the STAGED name; the caller renames
              it to the log only after all of this has succeeded.

              THE PER-RECORD HANDLER BELOW NO LONGER CARRIES ON INTO A LOG. A
              record that fails is counted and named, and the loop finishes so
              the report can say how many -- but nothing is committed and the
              staged file is discarded. That also closes the second gap 9c
              recorded: SQLite may roll the transaction back by itself on
              SQLITE_FULL, IOERR, NOMEM or BUSY without telling sqldb, which
              would put the records after a failure in AUTOCOMMIT. They would
              now land in a file nobody publishes. *)
            while aReader.ReadNext(rec) do
               begin
               Inc(aResult.RecordsRead);

               (* THE CONTEST COMES FROM THE RECORDS, because a binary log has no
                 header that says which one it is. Taken from the first, then
                 checked against the rest: "one log is one contest" is measured
                 (all thirteen corpus logs carry exactly one) but it is an
                 assumption about somebody else's file, so a log that breaks it
                 says so rather than silently keeping the first answer. *)
               if aResult.RecordsRead = 1 then
                  begin
                  (* A CONTEST NUMBER THIS PROGRAM DOES NOT KNOW IS REFUSED,
                    NOT STORED (Q108 S2, design 8.2u). The byte is a D7
                    ContestType ordinal; one above the last of them is a
                    damaged file or one from a newer TR4W. It used to index
                    ContestTypeSA out of range when the log was stamped.
                    Counted as a failed record, so nothing is committed and
                    the staged file is discarded -- no log rather than a
                    log that names no contest.

                    A LEGACY NUMBER, NOT MERELY A KNOWN HANDLE (Q108 S3): a
                    .TRW predates every contest registered by id, so a byte
                    that is such a contest's handle in this build is damaged
                    data too -- it must not open as that contest. *)
                  if not ContestLegacyNumber(rec.ceContest, legacyNumber) then
                     begin
                     Inc(aResult.RecordsFailed);
                     aFailure := SysUtils.Format(
                        'record 1 names contest number %d, and the last ' +
                        'contest this TR4W knows is %d -- the file is ' +
                        'damaged, or was written by a newer TR4W. Nothing ' +
                        'was imported.',
                        [rec.ceContest.ToByte, Ord(High(ContestType))]);
                     Break;
                     end;
                  repo.SetContest(rec.ceContest);
                  end
               else if (rec.ceContest <> repo.LogContest) and
                       (aResult.Message = '') then
                  begin
                  aResult.Message := SysUtils.Format(
                     'Record %d is contest %d but the log started as %d. The ' +
                     'first one is what the log records; TR4W stores one ' +
                     'contest per log.',
                     [aResult.RecordsRead, rec.ceContest.ToByte,
                      repo.LogContest.ToByte]);
                  end;
               try
                  (* Grouped, so a county line or a POTA n-fer arrives as one
                    contact of several QSOs rather than as unrelated rows. *)
                  repo.SaveQSOGroupingByExchangeId(rec);
                  if Assigned(aAfterRecord) then
                     begin
                     aAfterRecord(aResult.RecordsRead);
                     end;
                  Inc(aResult.RecordsWritten);

                  case rec.ceRecordKind of
                     rkQSO:            Inc(aResult.QSOs);
                     rkQTCR, rkQTCS:   Inc(aResult.QTCs);
                     rkNote:           Inc(aResult.Notes);
                  end;
                  if rec.ceQSO_Deleted then
                     begin
                     Inc(aResult.Deleted);
                     end;
                  (* Skipped and Deleted were counted apart when they were two
                     flags. One flag now, so this counter only ever reported the
                     same records twice; it is left in the result record because
                     callers print it, and it stays at zero. *)
                  if GoodLookingQSO(rec) then
                     begin
                     Inc(aResult.Exportable);
                     end;
               except
                  on E: Exception do
                     begin
                     (* COUNTED AND NAMED. A silent skip would make the count
                       quietly wrong, which is worse than failing. *)
                     Inc(aResult.RecordsFailed);
                     if aFailure = '' then
                        begin
                        aFailure := Format(
                           'record %d (%s) could not be imported: %s',
                           [aResult.RecordsRead, string(rec.Callsign), E.Message]);
                        end;
                     end;
               end;
               end;

            if aResult.RecordsFailed = 0 then
               begin
               repo.Commit;
               Result := True;
               end;
         finally
            repo.Free;
         end;
      except
         on E: Exception do
            begin
            (* CreateNew refused, the statements would not prepare, or the
              COMMIT itself failed. *)
            Result := False;
            if aFailure = '' then
               begin
               aFailure := E.Message;
               end;
            end;
      end;
   finally
      (* A CLOSE THAT RAISES IS A FAILED IMPORT, NOT AN ESCAPE. Close rolls
        back whatever is open, and that ROLLBACK can fail; this routine is
        documented never to raise. *)
      try
         db.Free;
      except
         on E: Exception do
            begin
            Result := False;
            if aFailure = '' then
               begin
               aFailure := 'closing the imported log failed: ' + E.Message;
               end;
            end;
      end;
   end;
end;

function ImportBinaryLog(const aSourceFile, aTargetFile: string;
                         aAfterRecord: TLogImportRecordHook): TLogImportResult;
var
   reader: TLogBinaryReader;
   staged: string;
   leftover: string;
   failure: string;
begin
   (* Default, not FillChar: the record holds managed strings. *)
   Result := Default(TLogImportResult);

   reader := TLogBinaryReader.Create(aSourceFile);
   try
      if reader.Status <> lbOK then
         begin
         Result.Message := reader.Message;
         Exit;
         end;

      (* ASKED HERE, BEFORE ANYTHING IS TOUCHED. CreateNew used to say this,
        when it was handed the target itself; it is handed the staged name
        now, so the refusal has to be made on the target's behalf. *)
      if FileExists(aTargetFile) then
         begin
         Result.Message := Format(
            'A contest log already exists at "%s". Importing into it would ' +
            'destroy it; open it instead, or choose another name.',
            [aTargetFile]);
         Exit;
         end;

      (* AN IMPORT THAT NEVER FINISHED. Its staged file was never the log --
        that is the whole point of staging -- so it is worth nothing, and the
        source it came from is still here to import again. *)
      staged := StagedImportFileName(aTargetFile);
      leftover := FirstSidecarPresent(staged);
      if FileExists(staged) then
         begin
         leftover := staged;
         end;
      if leftover <> '' then
         begin
         if not DeleteStagedFiles(staged) then
            begin
            Result.Message := Format(
               'An unfinished import from an earlier run is at "%s" and could ' +
               'not be deleted, so nothing was imported. Delete it, and any ' +
               '-wal, -shm or -journal file beside it, then try again.',
               [leftover]);
            Exit;
            end;
         Result.DiscardedStaged := leftover;
         end;

      if not BuildStagedLog(reader, staged, aAfterRecord, Result, failure) then
         begin
         DeleteStagedFiles(staged);
         if Result.RecordsFailed > 0 then
            begin
            Result.Message := Format(
               '%d of %d record(s) could not be imported, so NOTHING was ' +
               'imported and no log was written at "%s". The first: %s',
               [Result.RecordsFailed, Result.RecordsRead, aTargetFile, failure]);
            end
         else
            begin
            Result.Message := Format(
               'The import failed, so no log was written at "%s": %s',
               [aTargetFile, failure]);
            end;
         Exit;
         end;

      (* NOTHING MAY BE LEFT BESIDE IT. The database is closed, and on a clean
        close of the last connection SQLite checkpoints the -wal into the file
        and deletes both -wal and -shm (measured 2026-09-19, and pinned by
        uTestLogImport). That is what makes the rename below safe: renaming
        the .db away from a -wal that still held committed pages would publish
        a log without them. So it is CHECKED rather than assumed, and a sidecar
        that survived stops the publish.

        A CHECKPOINT WAS NOT ADDED BEFORE THE CLOSE. The close already
        checkpoints, and a PRAGMA wal_checkpoint here would only repeat it; it
        is the check after the close that turns "SQLite normally does this"
        into a guarantee. *)
      leftover := FirstSidecarPresent(staged);
      if leftover <> '' then
         begin
         DeleteStagedFiles(staged);
         Result.Message := Format(
            'The import completed, but "%s" was still beside it after the ' +
            'database closed, so it was not made the log: renaming the ' +
            'database away from it could lose what it holds. Nothing was ' +
            'imported and no log was written at "%s".',
            [leftover, aTargetFile]);
         Exit;
         end;

      (* PUBLISH. One rename, so aTargetFile goes from not existing to holding
        the whole import with no moment in between. A failure is said in full
        and the finished import is LEFT at the staged name, where the operator
        can see it -- it is never adopted, and the next import discards it. *)
      if not RenameFile(staged, aTargetFile) then
         begin
         Result.Message := Format(
            'The import completed but could not be renamed from "%s" to "%s", ' +
            'so it is NOT the log and nothing was imported. The finished ' +
            'import has been left at "%s"; the next import discards it.',
            [staged, aTargetFile, staged]);
         Exit;
         end;

      (* The file size said how many records there are; the reader stops early
        only if the file was truncated mid-write. Saying so is cheap and it is
        the difference between "your log is short" and "your log is fine". *)
      if Result.RecordsRead <> reader.ExpectedRecords then
         begin
         Result.Message := Format(
            '"%s" holds %d record(s) by its size but only %d could be read. ' +
            'The last one is incomplete -- TR4W ignores a trailing partial ' +
            'record, and so does this.',
            [aSourceFile, reader.ExpectedRecords, Result.RecordsRead]);
         end;

      Result.Ok := True;
   finally
      reader.Free;
   end;
end;

end.
