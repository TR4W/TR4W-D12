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

(* THE SQLITE LOG, WRITTEN ALONGSIDE THE BINARY ONE -- STEP B2.

  The binary .TRW REMAINS AUTHORITATIVE. Nothing reads this database yet: it is
  written so that a bench session produces a real SQLite log next to a real
  binary one, which is the only way to find out whether the mapper survives
  contact with live logging rather than with corpus fixtures.

  That is the strangler pattern this tree already used for the radio and CW
  keyer factories, in CLAUDE.md's own words: "thin adapters over the existing
  globals first, prove the seam on hardware, then delete the legacy path".

  THE RULE THAT OVERRIDES EVERYTHING ELSE HERE: A FAILURE IN THIS UNIT MUST
  NEVER COST A QSO. Every entry point swallows its exceptions, reports once, and
  switches the shadow OFF for the rest of the session. An operator in a contest
  must not lose a contact because a database he does not yet use would not
  write. That is also why nothing here is on the critical path of the log write
  itself -- each call happens AFTER the binary record is safely on disk.

  OPENED LAZILY, on the first append, so there is no startup wiring to get in
  the wrong order and nothing happens at all in a session that logs nothing.

  WHAT IS SHADOWED, AND WHAT IS NOT -- because a partial shadow that pretends to
  be complete would be worse than none:

    shadowed      appending a QSO             (LOGSUBS2.tAddQSOToLog)
                  rewriting the newest row    (DeleteLastContact,
                                               uNet.UpdateRec,
                                               uQTCS.SetSendedQSOs)

                  editing an arbitrary QSO    (uEditQSO, by record position)
                  the network's own update    (uNet.FindAndUpdateQSOInLog,
                                               by (ceQSOID1, ceQSOID2))
                  ADIF import                 (MainUnit.ImportFromADIF)

  ALL EIGHT WRITE SITES ARE NOW SHADOWED. The drift rebuild in EnsureOpen stays
  anyway, and not as a formality: a session that ran with the shadow switched
  off after a failure, or a log edited by an older build, still leaves the two
  out of step. Rebuilding is cheap (1,316 QSOs in 63 ms) and the .TRW is
  authoritative, so disagreement is settled rather than hoped about. *)
unit uLogShadow;

{$I tr4w.inc}

interface

uses
   VC;

(* Appends a QSO to the shadow.  Call AFTER the binary record is written.
  Never raises. *)
procedure ShadowAppendQSO(const aQso: ContestExchange);

(* Rewrites the shadow's newest row -- what the three "seek back one record"
  sites do to the binary log.  Never raises. *)
procedure ShadowUpdateNewestQSO(const aQso: ContestExchange);

(* Rewrites the row matching a record's POSITION in the binary log -- what the
  QSO editor does with a byte offset.  Never raises. *)
procedure ShadowUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange);

(* Rewrites the row the multi-op network identifies by (ceQSOID1, ceQSOID2).
  Does nothing when that pair is unset.  Never raises. *)
procedure ShadowUpdateQSOBySessionIds(const aQso: ContestExchange);

(* Closes it, if it was ever opened.  Safe to call when it was not. *)
procedure ShadowClose;

(* False after a failure has switched it off, or before anything opened it. *)
function ShadowIsActive: boolean;

implementation

uses
   SysUtils, MainUnit, uLogDatabase, uLogRepository, uLogImport, uLogBinaryFile;

var
   GDatabase: TLogDatabase = nil;
   GRepository: TLogRepository = nil;

   (* Tried and failed. Set once, never cleared, so a broken shadow costs one
     log line rather than one per QSO for the rest of a contest. *)
   GDisabled: boolean = False;

   GTriedToOpen: boolean = False;

function ShadowIsActive: boolean;
begin
   Result := (not GDisabled) and (GRepository <> nil);
end;

(* Report once and stand down.  Called from every except block here. *)
procedure Disable(const aWhere: string; E: Exception);
begin
   if not GDisabled then
      begin
      GDisabled := True;
      if logger <> nil then
         begin
         logger.Error('[LogShadow] switched off after a failure in %s: %s -- %s. ' +
                      'The binary log is unaffected and logging continues.',
                      [aWhere, E.ClassName, E.Message]);
         end;
      end;

   FreeAndNil(GRepository);
   FreeAndNil(GDatabase);
end;

function ShadowFileName: string;
begin
   (* Beside the binary log, same name. A log and its shadow travel together or
     the shadow is worse than useless. *)
   Result := ChangeFileExt(string(StrPas(TR4W_LOG_FILENAME)), '.db');
end;

(* How many records the binary log holds, or -1 if it cannot be read. *)
function BinaryRecordCount: Int64;
var
   reader: TLogBinaryReader;
begin
   Result := -1;
   reader := TLogBinaryReader.Create(string(StrPas(TR4W_LOG_FILENAME)));
   try
      if reader.Status = lbOK then
         begin
         Result := reader.ExpectedRecords;
         end;
   finally
      reader.Free;
   end;
end;

(* True when the shadow is open and usable.

  aRebuilt tells the caller the shadow was just built FROM THE BINARY LOG, which
  matters more than it looks -- see ShadowAppendQSO. *)
function EnsureOpen(out aRebuilt: boolean): boolean;
var
   dbName: string;
   trwCount: Int64;
   res: TLogImportResult;

   (* Returns False rather than raising: the caller is a try/except that would
     only disable the shadow anyway, and raising here meant constructing an
     Exception from a UnicodeString, which narrows. *)
   function RebuildFromBinary(const aWhy: string): boolean;
   begin
      if logger <> nil then
         begin
         logger.Info('[LogShadow] building %s from the binary log (%s)',
                     [dbName, aWhy]);
         end;
      FreeAndNil(GRepository);
      FreeAndNil(GDatabase);
      if FileExists(dbName) then
         begin
         DeleteFile(dbName);
         end;
      res := ImportBinaryLog(string(StrPas(TR4W_LOG_FILENAME)), dbName);
      Result := res.Ok;
      if (not Result) and (logger <> nil) then
         begin
         logger.Error('[LogShadow] could not build the shadow: %s', [res.Message]);
         end;
   end;

begin
   aRebuilt := False;
   Result := ShadowIsActive;
   if Result or GDisabled then
      begin
      Exit;
      end;

   GTriedToOpen := True;
   try
      dbName := ShadowFileName;
      trwCount := BinaryRecordCount;

      if not FileExists(dbName) then
         begin
         (* A contest resumed after a restart has a log already. Importing it
           first is what makes the shadow a shadow rather than a fragment. *)
         if not RebuildFromBinary('no shadow yet') then
            begin
            GDisabled := True;
            Result := False;
            Exit;
            end;
         aRebuilt := True;
         end;

      GDatabase := TLogDatabase.Create;
      GDatabase.Open(dbName);
      GRepository := TLogRepository.Create(GDatabase);

      (* THE DRIFT CHECK. The three unshadowed mutations above, or a session
        that ran with the shadow switched off, leave the two out of step. The
        .TRW is authoritative and rebuilding is cheap, so disagreement is
        settled by rebuilding rather than by hoping. *)
      if (trwCount >= 0) and (GRepository.RecordCount <> trwCount) then
         begin
         if not RebuildFromBinary(
                   Format('shadow holds %d record(s), the log holds %d',
                          [GRepository.RecordCount, trwCount])) then
            begin
            GDisabled := True;
            Result := False;
            Exit;
            end;
         aRebuilt := True;
         GDatabase := TLogDatabase.Create;
         GDatabase.Open(dbName);
         GRepository := TLogRepository.Create(GDatabase);
         end;

      Result := True;
   except
      on E: Exception do
         begin
         Disable('opening the shadow', E);
         Result := False;
         end;
   end;
end;

procedure ShadowAppendQSO(const aQso: ContestExchange);
var
   rebuilt: boolean;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;

      (* THE SHADOW IS OPENED LAZILY, ON THE FIRST APPEND -- AND THE BINARY
        RECORD IS ALREADY ON DISK BY THEN.

        This call happens after tAddQSOToLog has written and closed the file,
        which is deliberate: the contact must be safe before anything else is
        attempted. But it means a rebuild-from-binary triggered HERE has already
        imported the very QSO being appended, and appending it again duplicates
        it.

        Measured, not reasoned: the county-line UI harness logged two QSOs and
        the shadow held THREE, with the first one twice.

        The drift check in EnsureOpen would have repaired it at the next open,
        which is some comfort -- but a shadow that is briefly wrong is a shadow
        nobody can trust mid-contest, and "it fixes itself later" is not a
        property to rely on. *)
      if rebuilt then
         begin
         Exit;
         end;

      (* The contest comes from the records; a binary log has no header naming
        it, and the shadow must answer the same question the same way the
        importer does. *)
      if GRepository.LogContest <> aQso.ceContest then
         begin
         GRepository.SetContest(aQso.ceContest);
         end;

      (* The same grouping rule the importer uses -- a county line logged
        live must relate its rows exactly as an imported one does. *)
      GRepository.SaveQSOGroupingByExchangeId(aQso);

      (* PER QSO, not batched -- section 9b. An operator who loses power should
        lose at most the contact in progress, and this is a shadow of a log
        that has already been written, so a slow commit costs nothing an
        operator can feel. *)
      GRepository.Commit;
   except
      on E: Exception do
         begin
         Disable('appending a QSO', E);
         end;
   end;
end;

procedure ShadowUpdateNewestQSO(const aQso: ContestExchange);
var
   rowId: Int64;
   rebuilt: boolean;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;

      (* A rebuild has just re-read the binary log, which already contains this
        rewrite -- the caller writes the record before calling here, exactly as
        the append does. *)
      if rebuilt then
         begin
         Exit;
         end;

      rowId := GRepository.NewestRowId;
      if rowId <= 0 then
         begin
         (* Nothing to rewrite. Not an error: DeleteLastContact on an empty log
           is a no-op in the binary world too. *)
         Exit;
         end;

      GRepository.UpdateQSO(rowId, aQso);
      GRepository.Commit;
   except
      on E: Exception do
         begin
         Disable('rewriting the newest QSO', E);
         end;
   end;
end;

procedure ShadowUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange);
var
   rowId: Int64;
   rebuilt: boolean;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if rebuilt then
         begin
         (* The rebuild has just re-read the binary log, which already carries
           this edit -- the caller writes before calling here. *)
         Exit;
         end;

      rowId := GRepository.RowIdAtIndex(aRecordIndex);
      if rowId <= 0 then
         begin
         (* The shadow is short of that record. EnsureOpen's drift check will
           rebuild at the next open; saying so here is what makes that visible
           rather than mysterious. *)
         if logger <> nil then
            begin
            logger.Warn('[LogShadow] no row at record index %d -- the shadow ' +
                        'will be rebuilt from the binary log', [aRecordIndex]);
            end;
         Exit;
         end;

      GRepository.UpdateQSO(rowId, aQso);
      GRepository.Commit;
   except
      on E: Exception do
         begin
         Disable('rewriting a QSO by position', E);
         end;
   end;
end;

procedure ShadowUpdateQSOBySessionIds(const aQso: ContestExchange);
var
   rebuilt: boolean;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if rebuilt then
         begin
         Exit;
         end;

      (* False when the pair is unset or matches nothing. Not an error: the
        binary side scans the whole log and finds nothing either. *)
      if GRepository.UpdateQSOBySessionIds(aQso.ceQSOID1, aQso.ceQSOID2, aQso) then
         begin
         GRepository.Commit;
         end;
   except
      on E: Exception do
         begin
         Disable('rewriting a QSO by its network key', E);
         end;
   end;
end;

procedure ShadowClose;
begin
   FreeAndNil(GRepository);
   FreeAndNil(GDatabase);
end;

end.
