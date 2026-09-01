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

{ A BINARY .trw LOG -> A SQLite CONTEST LOG.

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
    skipped QSOs   ceQSO_Skiped, which scoring reads.
    QTC records    rkQTCR / rkQTCS -- a whole WAE contest's traffic.
    notes          rkNote.

  The columns for all of those exist (deleted, is_skipped, record_kind), so the
  database holds what the LOG holds and the filtering happens where it always
  did: at export. An importer that quietly dropped a quarter of a WAE log would
  be the worst kind of defect -- it produces a smaller number that looks fine. }
unit uLogImport;

{$I tr4w.inc}

interface

uses
   SysUtils, VC, uLogDatabase, uLogRepository, uLogBinaryFile;

type
   TLogImportResult = record
      Ok: boolean;

      { What the file held and what reached the database. They differ only by
        RecordsFailed, which is normally zero. }
      RecordsRead: integer;
      RecordsWritten: integer;
      RecordsFailed: integer;

      { Broken out because they are the numbers an operator recognises. }
      QSOs: integer;
      QTCs: integer;
      Notes: integer;
      Deleted: integer;
      Skipped: integer;

      { HOW MANY WOULD REACH A CABRILLO FILE -- GoodLookingQSO's count.

        Reported because without it the summary misleads. A florida_qp log
        imported as "5 record(s): 5 QSO, 0 QTC, 0 note, 0 deleted" -- every
        number true -- while TWO of those five are skipped and would never be
        exported. The reader concludes the log is five good QSOs.

        This is the number an operator would compare against his own count, so
        it is the one that has to be there. }
      Exportable: integer;

      { Empty when Ok. Otherwise a sentence, already fit to show. }
      Message: string;
   end;

{ Reads aSourceFile and writes a NEW log at aTargetFile.

  Refuses an existing target -- TLogDatabase.CreateNew does, and importing over
  somebody's log is exactly the mistake worth refusing.

  Never raises for a bad source: a failed import comes back as Ok = False with a
  message, because an operator importing a season of logs needs to know which
  one would not read and still get the rest. }
function ImportBinaryLog(const aSourceFile, aTargetFile: string): TLogImportResult;

implementation

function ImportBinaryLog(const aSourceFile, aTargetFile: string): TLogImportResult;
var
   reader: TLogBinaryReader;
   db: TLogDatabase;
   repo: TLogRepository;
   rec: ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Ok := False;
   Result.Message := '';

   reader := TLogBinaryReader.Create(aSourceFile);
   try
      if reader.Status <> lbOK then
         begin
         Result.Message := reader.Message;
         Exit;
         end;

      db := TLogDatabase.Create;
      try
         try
            db.CreateNew(aTargetFile);
         except
            on E: Exception do
               begin
               Result.Message := E.Message;
               Exit;
               end;
         end;

         repo := TLogRepository.Create(db);
         try
            { ONE TRANSACTION FOR THE WHOLE IMPORT. Ten thousand separate
              commits would each fsync -- section 8 sets synchronous = FULL --
              and turn a second into minutes. The per-QSO commit that section 9b
              argues for is about LOGGING, where losing the contact in progress
              is the thing being prevented; an import that fails half way should
              leave no log at all, which is what one transaction gives. }
            while reader.ReadNext(rec) do
               begin
               Inc(Result.RecordsRead);

               { THE CONTEST COMES FROM THE RECORDS, because a binary log has no
                 header that says which one it is. Taken from the first, then
                 checked against the rest: "one log is one contest" is measured
                 (all thirteen corpus logs carry exactly one) but it is an
                 assumption about somebody else's file, so a log that breaks it
                 says so rather than silently keeping the first answer. }
               if Result.RecordsRead = 1 then
                  begin
                  repo.SetContest(rec.ceContest);
                  end
               else if (rec.ceContest <> repo.LogContest) and
                       (Result.Message = '') then
                  begin
                  Result.Message := SysUtils.Format(
                     'Record %d is contest %d but the log started as %d. The ' +
                     'first one is what the log records; TR4W stores one ' +
                     'contest per log.',
                     [Result.RecordsRead, Ord(rec.ceContest),
                      Ord(repo.LogContest)]);
                  end;
               try
                  repo.SaveQSO(rec);
                  Inc(Result.RecordsWritten);

                  case rec.ceRecordKind of
                     rkQSO:            Inc(Result.QSOs);
                     rkQTCR, rkQTCS:   Inc(Result.QTCs);
                     rkNote:           Inc(Result.Notes);
                  end;
                  if rec.ceQSO_Deleted then
                     begin
                     Inc(Result.Deleted);
                     end;
                  if rec.ceQSO_Skiped then
                     begin
                     Inc(Result.Skipped);
                     end;
                  if GoodLookingQSO(rec) then
                     begin
                     Inc(Result.Exportable);
                     end;
               except
                  on E: Exception do
                     begin
                     { COUNTED AND NAMED, not fatal. One unreadable record in a
                       twenty-year-old log should not cost the other 9,999 --
                       but a silent skip would make the count quietly wrong,
                       which is worse than either. }
                     Inc(Result.RecordsFailed);
                     if Result.Message = '' then
                        begin
                        Result.Message := Format(
                           'Record %d (%s) could not be imported: %s',
                           [Result.RecordsRead, string(rec.Callsign), E.Message]);
                        end;
                     end;
               end;
               end;

            repo.Commit;
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;

      { The file size said how many records there are; the reader stops early
        only if the file was truncated mid-write. Saying so is cheap and it is
        the difference between "your log is short" and "your log is fine". }
      if Result.RecordsRead <> reader.ExpectedRecords then
         begin
         Result.Message := Format(
            '"%s" holds %d record(s) by its size but only %d could be read. ' +
            'The last one is incomplete -- TR4W ignores a trailing partial ' +
            'record, and so does this.',
            [aSourceFile, reader.ExpectedRecords, Result.RecordsRead]);
         end;

      Result.Ok := (Result.RecordsFailed = 0);
   finally
      reader.Free;
   end;
end;

end.
