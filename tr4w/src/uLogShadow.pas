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

(* MAKES THE SQLITE LOG EXIST AND MATCH THE BINARY ONE, and returns whether it
  can be relied on.  Its file name is uLogDatabase.LogDatabaseFileName.

  THIS IS WHAT A READER NEEDS AND A WRITER DID NOT. While only writes were
  shadowed, the database was built lazily by the first append and no one else
  cared. A READ can now come first -- a headless export of a log this build has
  never appended to, or an operator opening the log window before working
  anybody -- and it must not find an absent or stale file.

  Rebuild-when-absent and the drift check already existed for the write path;
  this exposes them. Never raises: on failure the shadow disables itself and
  this returns False, which is the caller's cue to say so rather than to
  silently read the wrong store. *)
function ShadowEnsureCurrent: boolean;

implementation

uses
   SysUtils, MainUnit, uLogDatabase, uLogRepository, uLogImport, uLogBinaryFile,
   (* The canonical sent-exchange builder -- the same one the UDP broadcast
      uses, so the database and the broadcast cannot disagree. *)
   uExchangeBuilder,
   (* The Cabrillo header's tag table -- CabrilloTagText answers from the live
      window when it is open and from the store otherwise. *)
   uCbrSum,
   (* MyPark, which is not a Cabrillo tag: it is a per-log fact TR4W keeps as
      its own global. *)
   LOGWIND;

var
   GDatabase: TLogDatabase = nil;
   GRepository: TLogRepository = nil;

   (* Tried and failed. Set once, never cleared, so a broken shadow costs one
     log line rather than one per QSO for the rest of a contest. *)
   GDisabled: boolean = False;

   GTriedToOpen: boolean = False;

   (* THERE IS NO "written already" FLAG, ON PURPOSE -- see EnsureOpen. *)

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

(* THE ENTRY DECLARATION, READ ONCE, WHEN THE LOG IS MADE.

   This is tier 2 of the event-sourcing decision and it fixes a defect the
   golden corpus cannot see, because golden_diff.py compares only QSO lines and
   never the header. Measured: a headless export ships a Cabrillo file with
   CATEGORY-ASSISTED, CATEGORY-BAND and CATEGORY-OPERATOR simply ABSENT, and a
   CATEGORY-MODE of SSB where the log's own configuration says MIXED -- because
   those tags come only from tr4w.json and headless has no dialog to seed them.

   CabrilloTagText is the right source and the only one: it answers from the
   live window when it is open and from the store otherwise, which is exactly
   what made the interactive and headless paths agree in the first place.

   ONCE. Reading it again later would reintroduce the bug at the header level:
   what an entry DECLARED is a fact about the entry, not about today. *)
function ReadEntryDeclaration: TLogEntryDeclaration;
begin
   FillChar(Result, SizeOf(Result), 0);

   Result.MyCall := AnsiString(MyCall);
   Result.MyPark := AnsiString(MyPark);

   Result.CategoryOperator    := AnsiString(CabrilloTagText(ctCategoryOperator));
   Result.CategoryAssisted    := AnsiString(CabrilloTagText(ctCategoryAssisted));
   Result.CategoryPower       := AnsiString(CabrilloTagText(ctCategoryPower));
   Result.CategoryBand        := AnsiString(CabrilloTagText(ctCategoryBand));
   Result.CategoryMode        := AnsiString(CabrilloTagText(ctCategoryMode));
   Result.CategoryStation     := AnsiString(CabrilloTagText(ctCategoryStation));
   Result.CategoryTime        := AnsiString(CabrilloTagText(ctCategoryTime));
   Result.CategoryTransmitter := AnsiString(CabrilloTagText(ctCategoryTransmitter));
   Result.CategoryOverlay     := AnsiString(CabrilloTagText(ctCategoryOverlay));

   Result.Club    := AnsiString(CabrilloTagText(ctClub));
   Result.Soapbox := AnsiString(CabrilloTagText(ctSoapbox));

   Result.OpName   := AnsiString(CabrilloTagText(ctName));
   Result.Address  := AnsiString(CabrilloTagText(ctAddress));
   Result.City     := AnsiString(CabrilloTagText(ctAddressCity));
   Result.State    := AnsiString(CabrilloTagText(ctAddressStateProvince));
   Result.Postcode := AnsiString(CabrilloTagText(ctAddressPostalcode));
   Result.Country  := AnsiString(CabrilloTagText(ctAddressCountry));
   Result.Email    := AnsiString(CabrilloTagText(ctEmail));
end;

(* Moves a database aside, with the -wal and -shm beside it.

  ALL THREE OR THE RENAME IS A CORRUPTION. A -wal left behind belongs to the
  file that is no longer there, and SQLite would either ignore it -- losing
  every transaction it holds -- or graft it onto the NEW database of the same
  name. Renaming them together keeps the orphan openable and the fresh one
  clean. Failures are reported, never raised: this runs on the path that is
  trying to avoid losing data, and it must not be the thing that loses it. *)
procedure RenameAside(const aDbName, aOrphanName: string);

   procedure MoveOne(const aFrom, aTo: string);
   begin
      if not FileExists(aFrom) then
         begin
         Exit;
         end;
      if not RenameFile(aFrom, aTo) then
         begin
         if logger <> nil then
            begin
            logger.Error('[LogShadow] could not move %s aside to %s. The file ' +
                         'is left where it is.', [aFrom, aTo]);
            end;
         end;
   end;

begin
   MoveOne(aDbName, aOrphanName);
   MoveOne(aDbName + '-wal', aOrphanName + '-wal');
   MoveOne(aDbName + '-shm', aOrphanName + '-shm');
end;

function ShadowFileName: string;
begin
   (* The rule itself is uLogDatabase.LogDatabaseFileName -- it outlives this
     unit, which B5 deletes. *)
   Result := LogDatabaseFileName(string(StrPas(TR4W_LOG_FILENAME)));
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
(* aAppendPending -- THE CALLER IS PART WAY THROUGH ADDING A QSO.

   The binary record is written and the file CLOSED before ShadowAppendQSO is
   called (LOGSUBS2.tAddQSOToLog, and that order is deliberate: the contact must
   be durable before anything else is attempted). So during an append the log
   holds exactly ONE record more than the shadow, and that is AGREEMENT, not
   drift.

   Reading it as drift is what the first version did, and the cost was not
   theoretical: EVERY RESUMED SESSION RE-IMPORTED THE WHOLE LOG on its first
   QSO, and the plain-reopen path below was never once taken -- dead code that
   looked live. Measured on the county-line harness with -KeepLog: "shadow holds
   2 record(s), the log holds 3", on a shadow that was perfectly in step.

   AN EXACT EXPECTATION, NOT A TOLERANCE. Accepting a difference of one in
   either direction would have been fewer lines and would have made a genuinely
   lost record invisible -- which is the one thing this check exists to catch. *)
function EnsureOpen(out aRebuilt: boolean; aAppendPending: boolean): boolean;
var
   dbName: string;
   trwCount: Int64;
   expected: Int64;
   orphan: string;
   orphanRows: Int64;
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
      if aRebuilt then
         begin
         (* JUST REBUILT FROM THE LOG, so it cannot be out of step with it --
            and checking anyway would rebuild a SECOND time on every new log.
            The import copies the WHOLE binary log, the QSO being appended
            included, so the shadow legitimately holds trwCount here while an
            append expects trwCount - 1. Setting expected from aAppendPending
            regardless made those disagree by exactly one, every time.

            Skipping is not a shortcut past the check: an import that fell short
            of the log would have already raised, and RebuildFromBinary returning
            False is handled above. *)
         expected := GRepository.RecordCount;
         end
      else if aAppendPending then
         begin
         (* The record being appended is already in the log and not yet in the
            shadow. See the note on the parameter. *)
         expected := trwCount - 1;
         end
      else
         begin
         expected := trwCount;
         end;

      (* A REBUILD MUST NEVER DESTROY THE FULLER STORE.

         THE BINARY LOG IS APPEND-ONLY. Deletes mark a record, they do not
         remove it, so its record count can rise and can stay the same -- it
         cannot legitimately FALL. A count that has fallen does not mean the
         shadow drifted; it means the binary log was lost, truncated, or newly
         created, and rebuilding the database from it would replace real QSOs
         with nothing.

         MEASURED, and it is not a corner case. Move a .TRW aside and start
         TR4W: the program CREATES a fresh log -- 376 bytes, a header and no
         records -- because that is what it does for a new contest. The shadow
         then read "shadow holds 101, the log holds 0", called it drift, and
         rebuilt. 101 QSOs became 0, in one startup, with an INFO line as the
         only trace. The export that followed produced an empty ADIF and
         returned success.

         So the database is KEPT and the anomaly is reported. It is the store
         that still has the contest in it; the empty log beside it is the
         damaged one. Reconciliation runs in one direction only. *)
      if (trwCount >= 0) and (trwCount < GRepository.RecordCount) then
         begin
         (* THE BINARY LOG HAS SHRUNK, WHICH IT CANNOT LEGITIMATELY DO.

            It is append-only -- a delete MARKS a record rather than removing
            it -- so a fall in its count means it was lost, truncated, or newly
            created. Two very different things produce it and NOTHING HERE CAN
            TELL THEM APART:

              the .TRW was lost mid-contest, and the database is now the only
              copy of those QSOs;

              the operator (or a test) reset the log to start again, and the
              database holds the PREVIOUS contest.

            TLogHeader carries no identity that would separate them -- version
            string, description, warning, all byte-identical in every TR4W log
            ever written -- so there is no honest way to choose.

            Both naive answers are wrong, and both were tried. Rebuilding
            DESTROYS a contest: measured, 101 QSOs became 0 in one startup, with
            an INFO line as the only trace and a successful empty export after
            it. Keeping the database RESURRECTS one: the county-line harness
            resets its log every run and inherited three QSOs from the run
            before.

            So neither. The database is MOVED ASIDE, intact, and a fresh one is
            built to match the log. Nothing is destroyed, nothing is silently
            carried into a contest it does not belong to, and the error below
            says exactly where the QSOs went -- which is the part that makes
            this recoverable rather than merely safe. *)
         orphan := dbName + '.orphaned-' +
                   FormatDateTime('yyyymmdd-hhnnss', Now);
         orphanRows := GRepository.RecordCount;

         (* Closed first, so SQLite checkpoints the WAL into the file being
            renamed. Renaming a database out from under an open connection
            would orphan the -wal beside it and lose the newest transactions --
            the very QSOs most worth keeping. *)
         FreeAndNil(GRepository);
         FreeAndNil(GDatabase);
         RenameAside(dbName, orphan);

         if logger <> nil then
            begin
            logger.Error('[LogShadow] the binary log holds %d record(s) but the ' +
                         'SQLite log held %d. The binary log is append-only and ' +
                         'cannot shrink, so it has been lost, truncated or ' +
                         'recreated -- and nothing here can tell that apart from ' +
                         'a deliberate reset. The %d QSO(s) have NOT been ' +
                         'deleted: the database was moved to %s. A fresh one is ' +
                         'being built to match the log. If the binary log was ' +
                         'lost rather than reset, that file is your contest.',
                         [trwCount, orphanRows, orphanRows, orphan]);
            end;

         if not RebuildFromBinary('the shadow was orphaned to ' + orphan) then
            begin
            GDisabled := True;
            Result := False;
            Exit;
            end;
         aRebuilt := True;
         GDatabase := TLogDatabase.Create;
         GDatabase.Open(dbName);
         GRepository := TLogRepository.Create(GDatabase);
         end
      else if (trwCount >= 0) and (GRepository.RecordCount <> expected) then
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

      (* THE ENTRY DECLARATION, REFRESHED EVERY TIME THE SHADOW OPENS -- not
         captured once, and the distinction is NY4I's correction:

           "You shouldn't be putting those in the QSO records, because those can
            change. For example, I'm halfway through the contest, decide to
            change my category from unassisted to assisted. So the only time
            that's particularly relevant is when I do the Cabrillo submission."

         THE CATEGORY FIELDS ARE NOT EVENT-SOURCE DATA. What a QSO SENT is a
         fact about that QSO at that instant, and freezing it is the whole point
         of exchange_sent. A CATEGORY is a fact about the SUBMISSION: switch to
         assisted at 0300 and the entry IS assisted, all of it, including the
         QSOs made before you switched. There is no earlier truth being
         protected, so freezing one at log creation would simply serve a stale
         category to a sponsor months later.

         The FIRST version of this wrote it once and never again, which is the
         right shape for exchange_sent and the wrong one here.

         SO WHY STORE IT AT ALL, when the header store already has it? Because
         the point of this migration is a log file that describes itself: hand
         somebody a .db and it should carry its own submission metadata. The
         header store stays authoritative at submission time; this is a copy
         kept current, and it is refreshed rather than merged so it cannot
         drift into a third opinion. *)
      GRepository.SetEntryDeclaration(ReadEntryDeclaration);

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
   rowId: Int64;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      (* True: tAddQSOToLog has already written this QSO to the binary log,
         so the log being one ahead of the shadow is expected. *)
      if not EnsureOpen(rebuilt, True) then
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
         (* THE REBUILD ALREADY IMPORTED THIS QSO, so appending would duplicate
            it -- but the import cannot know what was SENT, and this call can.
            Skipping outright therefore lost the sent exchange of the first QSO
            of every session, which is exactly the field this work exists to
            capture. Measured: row 1 came back with exchange_sent NULL while
            row 2 carried it.

            The record just written to the binary log is its LAST one, so the
            row the rebuild just imported is the newest -- update that one with
            what only the live path knows. *)
         GRepository.SetNextSentExchange(
            AnsiString(BuildSentExchangeText(aQso)));
         rowId := GRepository.NewestRowId;
         if rowId > 0 then
            begin
            GRepository.UpdateQSO(rowId, aQso);
            GRepository.Commit;
            end;
         Exit;
         end;

      (* The contest comes from the records; a binary log has no header naming
        it, and the shadow must answer the same question the same way the
        importer does. *)
      if GRepository.LogContest <> aQso.ceContest then
         begin
         GRepository.SetContest(aQso.ceContest);
         end;

      (* WHAT WAS SENT, CAPTURED NOW -- this is TR4W-D12 issue #2 being fixed
        rather than worked around.

        The binary record has no field for the sent exchange, so today it is
        rebuilt from station globals at EXPORT time: correct a typo in MY NAME
        or move house, and every past QSO retroactively claims to have sent the
        new value. Two of the four corpus known-divergences are that defect.

        BuildSentExchangeText is the canonical builder already used for the UDP
        broadcast, and it reads the LIVE CQExchange template. Calling it here,
        at the moment of the QSO, records what actually went out -- including a
        stale grid if the operator changed one mid-contest, because that is
        what was sent. An event source records the event, not today's opinion
        of it. *)
      GRepository.SetNextSentExchange(
         AnsiString(BuildSentExchangeText(aQso)));

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
      if not EnsureOpen(rebuilt, False) then
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
      if not EnsureOpen(rebuilt, False) then
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
      if not EnsureOpen(rebuilt, False) then
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

function ShadowEnsureCurrent: boolean;
var
   rebuilt: boolean;
begin
   (* aAppendPending FALSE: nobody is part way through adding a QSO here, so the
      log and the shadow should agree exactly. *)
   Result := EnsureOpen(rebuilt, False);
end;

procedure ShadowClose;
begin
   FreeAndNil(GRepository);
   FreeAndNil(GDatabase);
end;

end.
