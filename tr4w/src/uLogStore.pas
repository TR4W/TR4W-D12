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
unit uLogStore;

{$I tr4w.inc}

interface

uses
   VC;

(* Appends a QSO to the shadow.  Call AFTER the binary record is written.
  Never raises. *)
procedure LogStoreAppendQSO(const aQso: ContestExchange);

(* Rewrites the shadow's newest row -- what the three "seek back one record"
  sites do to the binary log.  Never raises. *)
procedure LogStoreUpdateNewestQSO(const aQso: ContestExchange);

(* Rewrites the row matching a record's POSITION in the binary log -- what the
  QSO editor does with a byte offset.  Never raises. *)
procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange);

(* Rewrites the row the multi-op network identifies by (ceQSOID1, ceQSOID2).
  Does nothing when that pair is unset.  Never raises. *)
(* True when a QSO with that network key was found and rewritten.

  IT RETURNS SOMETHING NOW BECAUSE THE CALLER NEEDS IT. uNet's
  FindAndUpdateQSOInLog used to answer that question itself, by scanning
  the .TRW backwards until the key matched -- so it knew whether it had
  found one. The scan is gone; the answer has to come from here. *)
function LogStoreUpdateQSOBySessionIds(const aQso: ContestExchange): boolean;

(* Closes it, if it was ever opened.  Safe to call when it was not. *)
procedure LogStoreClose;

(* False after a failure has switched it off, or before anything opened it. *)
function LogStoreIsUsable: boolean;

(* APPLIES THE CONTEST CONFIGURATION THE LOG CARRIES -- phase E2.

  NY4I: "when done, the .cfg file should not be necessary."

  This is what makes that true. A contest .cfg is read once, when the log is
  created, and captured; from then on the LOG says what the contest is and the
  file is not consulted. Returns how many commands it applied, so a caller can
  tell "this log has none" from "this log has been read".

  ONLY source = 'contest'. See TLogRepository.LoadContestConfig for why. *)
function LogStoreApplyContestConfig: integer;

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
function LogStoreEnsureOpen: boolean;

implementation

uses
   SysUtils, Classes, MainUnit, uLogDatabase, uLogRepository, uLogImport,
   uLogBinaryFile,
   (* The canonical sent-exchange builder -- the same one the UDP broadcast
      uses, so the database and the broadcast cannot disagree. *)
   uExchangeBuilder,
   (* The Cabrillo header's tag table -- CabrilloTagText answers from the live
      window when it is open and from the store otherwise. *)
   uCbrSum,
   (* CFGCA and the value/provenance accessors -- phase E1. *)
   uCFG,
   (* GetCQMemoryString / GetEXMemoryString -- the program's own accessors. *)
   LogCW,
   (* KeyId, which is the spelling a .cfg already uses for a function key. *)
   Tree,
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

function LogStoreIsUsable: boolean;
begin
   Result := (not GDisabled) and (GRepository <> nil);
end;

(* Report once and stand down.  Called from every except block here. *)
(* A FAILURE HERE IS NOW A LOST QSO, AND MUST BE SAID OUT LOUD.

  THIS RULE IS THE EXACT REVERSE OF THE ONE IT REPLACES, and the reversal had to
  be made deliberately or it would not have been made at all -- the code reaches
  this state unchanged and looks fine.

  While the binary log was authoritative, the right behaviour was to swallow
  everything: report once, switch off, and let the contest carry on. An operator
  must not lose a contact because a database he did not yet use would not write.
  That reasoning depended entirely on there being a fallback.

  There is none. This IS the log. Code that quietly stands down after a write
  failure is code that silently stops logging a contest -- the operator keeps
  working, the screen keeps updating, and the QSOs are going nowhere.

  So the failure is put in front of the operator, once, and the store stays
  disabled so the message is not repeated per QSO. It cannot repair itself and
  pretending otherwise would be worse: what it can do is make sure the person at
  the radio knows to stop and fix it before working anybody else. *)
procedure Disable(const aWhere: string; E: Exception);
begin
   if not GDisabled then
      begin
      GDisabled := True;
      if logger <> nil then
         begin
         logger.Error('[LogStore] THE LOG IS NOT BEING WRITTEN. Failure in %s: ' +
                      '%s -- %s. There is no binary log behind this any more; ' +
                      'QSOs logged from here are NOT being saved.',
                      [aWhere, E.ClassName, E.Message]);
         end;

      (* IN FRONT OF THE OPERATOR, not only in a file nobody reads mid-contest.
         Once -- GDisabled guards it -- because a modal dialog per QSO would be
         its own kind of contest-ending. *)
      ShowMessage(PAnsiChar(AnsiString(
         'THE CONTEST LOG IS NOT BEING SAVED.' + #13#10#13#10 +
         'Writing to the log database failed in ' + aWhere + ':' + #13#10 +
         E.ClassName + ' -- ' + E.Message + #13#10#13#10 +
         'QSOs made from now on are NOT being recorded. Stop and fix this ' +
         'before working anyone else. The log written so far is intact in ' +
         LogDatabaseFileName(string(StrPas(TR4W_LOG_FILENAME))) + '.')));
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

(* THE CONFIGURATION AND THE PROGRAM MESSAGES, INTO THE LOG -- PHASE E1.

  NY4I: "the configuration info for a database should go into the database file
  too. That includes anything that goes into the .CFG file including Program
  Messages (Alt-P)... when done, the .cfg file should not be necessary."

  E1 WRITES. Nothing reads these yet, and that split is deliberate: writing them
  cannot change how the program behaves, so it can be verified by looking at a
  real log rather than by trusting a reading of the code. E2 makes them
  authoritative, and that is the step that can break a contest.

  EVERY LIVE ROW, NOT THE ONES THAT LOOK CONTEST-SHAPED. Choosing a subset would
  mean this unit deciding which settings matter, which is exactly the judgement
  that leaves an operator's log missing the one thing they changed. Only csRem
  is skipped, because csRem means the command was WITHDRAWN -- recognised so an
  old config does not error, applied by nothing.

  THE SOURCE COLUMN IS NOT DESCRIPTIVE. With no .cfg left, 'contest' versus
  'station' is the only thing that will say an explicit contest setting outranks
  the station default. uCFG already tracks it -- CommandCameFromContestCFG --
  and this asks rather than re-deriving, because a second derivation of a
  precedence rule is a second answer waiting to differ.

  ONE TRANSACTION for four hundred-odd upserts. Left to itself sqldb would
  commit each one, and under WAL that is a flush apiece on a path that runs at
  every log open. *)
(* 'CW' or 'PHONE' -- the two values the message table's mode column is
  specified to hold.  ADIFModeString is the wrong source for this: it answers
  'SSB' for Phone, which is the ADIF spelling and not this schema's. *)
function MessageModeName(aMode: ModeType): AnsiString;
begin
   if aMode = CW then
      begin
      Result := 'CW';
      end
   else
      begin
      Result := 'PHONE';
      end;
end;

procedure CaptureConfiguration;
var
   i: integer;
   cmd: string;
   src: AnsiString;
   value: AnsiString;
   renderable: boolean;
   mode: ModeType;
   Column: LogColumnsType;
   key: AnsiChar;
   memText: ShortString;
begin
   for i := 1 to CommandsArraySize do
      begin
      if CFGCA[i].crS = csRem then
         begin
         Continue;
         end;
      if CFGCA[i].crCommand = nil then
         begin
         Continue;
         end;

      cmd := string(StrPas(CFGCA[i].crCommand));
      if cmd = '' then
         begin
         Continue;
         end;

      (* CONTEST IS THE CONTEST. It is not a station preference that happens
        to be stored in a log, and it must be captured as contest-scoped even
        when nothing read a .cfg -- which is now the ORDINARY case, because a
        contest created by the New Contest dialog has a .db and no .cfg at all.

        WITHOUT THIS THE LOG CANNOT BE REOPENED USEFULLY, and the failure is
        total and silent. Measured on NY4I's own log, 2026-09-03: 410 captured
        rows, of which exactly ONE was contest-scoped -- MY CALL. On the next
        open, Contest stayed DUMMYCONTEST, so FCONTEST never ran
        `ActiveExchange := ContestsArray[Contest].AE` and ActiveExchange
        remained UnknownExchange. ProcessExchange's case has no else, so it
        returned False without a word and NO QSO COULD BE LOGGED AT ALL. The
        operator sees Enter do nothing.

        CommandCameFromContestCFG ANSWERS FALSE FOR A CONTEST THAT NEVER HAD A
        .cfg, which is exactly backwards for this row: the newer the contest,
        the less likely it is to be recorded as belonging to one. MY CALL was
        already special-cased here for the same reason; CONTEST is the other
        half of that pair and was missed. *)
      (* CONTEST IS NOT CAPTURED AT ALL. NY4I, 2026-09-03: "the config row has
        outlived its usefulness since we can store that in the .db file."

        The contest table holds contest_type, written once when the log is
        created and never recomputed. This row was a SECOND copy, rewritten on
        every clean exit from whatever the running program believed at the
        time -- so one bad session poisoned it permanently. That is not
        hypothetical: NY4I's log opened without a contest, exited cleanly, and
        this wrote CONTEST = DUMMY CONTEST into it. Every open afterwards read
        it back and refused it, and the log could never be used again while
        the contest table said CQ-WW-SSB the whole time.

        One of the two was a fact about the log; the other was a fact about a
        session. Only one of them belongs in the file. *)
      if cmd = 'CONTEST' then
         begin
         Continue;
         end;

      if CommandCameFromContestCFG(cmd) or (cmd = 'MY CALL') then
         begin
         (* MY CALL IS A CONTEST SETTING AND HAS TO BE NAMED AS ONE.

            CommandCameFromContestCFG says no for it, and not because it came
            from the station config: LogCfg SKIPS the "MY CALL" line while
            reading a .cfg when a callsign is already set (it has its own
            first-command rule), so NoteCommandFromContestCFG never fires and
            the row is recorded as 'station' by default.

            It is the ENTRY'S callsign -- which is why C2 already stores it on
            the contest row -- and without it here, a log opened with an empty
            .cfg halts on "No callsign specified" while its own callsign sits
            in the config table unread. *)
         src := 'contest';
         end
      else
         begin
         src := 'station';
         end;

      (* A COMMAND WHOSE VALUE CANNOT BE WRITTEN DOWN IS NOT CAPTURED.

        THIS HUNG THE PROGRAM, and headlessly it hung it forever. REMINDER is
        an ACTION, not a setting -- applying it calls QuickEditResponse('Enter
        time for reminder') and waits for a human (HELP.PAS:642). It was being
        captured with an empty value and re-applied on every open, so a batch
        /EXPORT sat at a prompt nobody could see. Measured on the golden corpus:
        general_qso aborted every run, and the count of failures moved around
        because it depended on which sets had been opened.

        THE ctFreqList PAIR ARE THE SAME MISTAKE WITH A WORSE ENDING. BAND MAP
        CUTOFF FREQUENCY and FREQUENCY MEMORY appear ONCE PER ENTRY in the band
        plan; capturing one blank value and applying it can replace an
        operator's whole band plan with nothing (see uCFG's note on
        CFGCommandIsMultiValued).

        THE RENDERER ALREADY KNEW -- it warned '%s: crType %d is not rendered
        here' and returned ''. What it could not do was say so to a caller,
        because '' is a legitimate value for a string setting. Now it can. *)
      value := AnsiString(CFGCommandValueAsString(cmd, renderable));
      if not renderable then
         begin
         Continue;
         end;

      GRepository.SaveConfigValue(AnsiString(cmd), value, src);
      end;

   (* THE EDITABLE-LOG COLUMN WIDTHS.

     These are not CommandsArray rows -- CheckCommand special-cases
     'COLUMN WIDTH <token>' (uCFG.pas:1664) rather than holding one row per
     column -- so the loop above cannot reach them and they need naming here,
     exactly as the function-key memories do below.

     THEY USED TO LIVE IN THE CONTEST .cfg, written by
     MainUnit.SaveColumnWidthToConfig. That write is gone: TR4W_CFG_FILENAME is
     a .db now, and asking the INI API to rewrite a SQLite file froze the
     program. Capturing them keeps the behaviour an operator sees -- widths
     survive a restart, and they are per contest, because they are in the
     contest's own file.

     SOURCE 'contest' BECAUSE THAT IS WHERE THEY CAME FROM, and because the
     startup apply reads contest-scoped rows. A width recorded as 'station'
     would be captured and never restored, which is worse than not capturing
     it: it looks saved. *)
   for Column := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[Column].Enable then
         begin
         Continue;
         end;

      (* ONLY A WIDTH THE OPERATOR ACTUALLY SET, AND IN PIXELS.

        THIS CAPTURED THE WRONG NUMBER AND BLANKED THE MAIN LOG. It wrote
        ColumnsArray[].Width, which is a COUNT OF CHARACTERS -- 9, 3, 12 -- and
        the value in a COLUMN WIDTH command is a PIXEL width: CheckCommand puts
        it in ColumnWidthOverride and MainUnit.pas:9514 hands that straight to
        ListView_SetColumnWidth. So every column came back a few pixels wide and
        the editable log rendered as blank paper with a striped edge (NY4I,
        2026-09-03, with a screenshot).

        ColumnWidthOverride IS THE RIGHT SOURCE, and zero is the right reason to
        skip: the override is only set when SaveColumnWidthToConfig runs, which
        is only when a divider is dragged or double-clicked. That is also what
        the old .cfg held -- a COLUMN WIDTH line existed for the columns an
        operator had touched and for no others, so an untouched column keeps the
        character-count default rather than being pinned to whatever pixel width
        it happened to have. *)
      if ColumnWidthOverride[Column] <= 0 then
         begin
         Continue;
         end;

      GRepository.SaveConfigValue(
         AnsiString('COLUMN WIDTH ' + string(StrPas(ColumnCanonicalName[Column]))),
         AnsiString(IntToStr(ColumnWidthOverride[Column])),
         'contest');
      end;

   (* THE FUNCTION-KEY MEMORIES, both kinds and both modes. GetCQMemoryString /
      GetEXMemoryString are the accessors the program itself uses, and KeyId is
      the spelling AppendConfigFile already writes into a .cfg -- so a message
      round-trips through the same names it has always had. *)
   for mode := CW to Phone do
      begin
      for key := F1 to AltF12 do
         begin
         (* ONLY KEYS THE PROGRAM CAN NAME.

            F1..AltF12 is a CHARACTER range, not an enumeration of function
            keys, so iterating it walks every code in between -- and several of
            those are not function keys at all. KeyId answers '' for them.

            That is not a cosmetic problem: the message table is keyed
            (kind, mode, key_id), so every unnamed key collapses onto the SAME
            row and each one silently overwrites the last. The first capture
            recorded a 'CQ/CW' memory of "QRL?" under an empty key, which is
            one of those codes winning the race.

            A key the program cannot name is also one a .cfg could never have
            expressed -- AppendConfigFile writes "CQ MEMORY " + KeyId(...) --
            so there is nothing here that a config file could round-trip. *)
         if KeyId(Char(key)) = '' then
            begin
            Continue;
            end;

         memText := GetCQMemoryString(mode, key);
         if memText <> '' then
            begin
            GRepository.SaveMessage('CQ', MessageModeName(mode),
                                    AnsiString(KeyId(Char(key))),
                                    AnsiString(memText), '');
            end;

         memText := GetEXMemoryString(mode, key);
         if memText <> '' then
            begin
            GRepository.SaveMessage('EX', MessageModeName(mode),
                                    AnsiString(KeyId(Char(key))),
                                    AnsiString(memText), '');
            end;
         end;
      end;

   GRepository.Commit;
end;

function LogStoreFileName: string;
begin
   (* The rule itself is uLogDatabase.LogDatabaseFileName -- it outlives this
     unit, which B5 deletes. *)
   Result := LogDatabaseFileName(string(StrPas(TR4W_LOG_FILENAME)));
end;

(* DOES A BINARY LOG WITH QSOs IN IT EXIST?

  A yes/no question now, not a count. Counts were what the drift check compared,
  and the drift check is gone with the second store -- see EnsureOpen. The only
  remaining caller asks whether there is anything to MIGRATE. *)
function BinaryLogHasRecords: boolean;
var
   reader: TLogBinaryReader;
begin
   reader := TLogBinaryReader.Create(string(StrPas(TR4W_LOG_FILENAME)));
   try
      Result := (reader.Status = lbOK) and (reader.ExpectedRecords > 0);
   finally
      reader.Free;
   end;
end;

(* True when the shadow is open and usable.

  aRebuilt tells the caller the shadow was just built FROM THE BINARY LOG, which
  matters more than it looks -- see LogStoreAppendQSO. *)
(* aAppendPending -- THE CALLER IS PART WAY THROUGH ADDING A QSO.

   The binary record is written and the file CLOSED before LogStoreAppendQSO is
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
   (* True only on the open that CREATED this log -- see the capture below. *)
   isNewLog: boolean;
   res: TLogImportResult;

   (* Returns False rather than raising: the caller is a try/except that would
     only disable the shadow anyway, and raising here meant constructing an
     Exception from a UnicodeString, which narrows. *)
   function RebuildFromBinary(const aWhy: string): boolean;
   begin
      if logger <> nil then
         begin
         logger.Info('[LogStore] building %s from the binary log (%s)',
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
         logger.Error('[LogStore] could not build the log: %s', [res.Message]);
         end;
   end;

begin
   aRebuilt := False;
   Result := LogStoreIsUsable;
   if Result or GDisabled then
      begin
      Exit;
      end;

   GTriedToOpen := True;
   isNewLog := False;
   try
      dbName := LogDatabaseFileName(string(StrPas(TR4W_LOG_FILENAME)));

      (* THE DATABASE IS THE LOG. IT IS NOT DERIVED FROM ANYTHING.

         Until B5 this opened the .TRW alongside, compared record counts, and
         reconciled -- rebuilding the database when the counts disagreed, or
         moving it aside when the binary log had shrunk. All of that existed
         because there were TWO LIVE STORES and something had to decide which
         was right on every open.

         There is one now, so there is nothing to decide. The drift check, the
         orphan rename and the count comparison are gone, and with them a whole
         class of failure: they could not tell "the .TRW was lost" from "the log
         was reset", and either answer destroyed or resurrected a contest.

         WHAT REMAINS IS MIGRATION, WHICH IS A DIFFERENT THING. A one-time
         import when the database does not exist and a binary log does. It runs
         ONCE, when an operator opens a 4.x or pre-B5 contest for the first
         time, and never again -- because after it the database exists. That is
         not reconciliation; nothing is being kept in step. *)
      GDatabase := TLogDatabase.Create;

      if FileExists(dbName) then
         begin
         GDatabase.Open(dbName);
         end
      else if BinaryLogHasRecords then
         begin
         (* AN EXISTING CONTEST, OPENED BY THIS BUILD FOR THE FIRST TIME.
            Migrate it rather than presenting the operator with an empty log
            beside a .TRW full of their QSOs. Once -- after this the database
            exists and the binary log is never consulted again. *)
         FreeAndNil(GDatabase);
         if not RebuildFromBinary('migrating an existing binary log') then
            begin
            GDisabled := True;
            Result := False;
            Exit;
            end;
         aRebuilt := True;
         GDatabase := TLogDatabase.Create;
         GDatabase.Open(dbName);
         end
      else
         begin
         (* A NEW CONTEST. CreateNew, not Open: Open REFUSES a missing file on
            purpose -- "an empty log that opens cleanly hides the real mistake"
            -- and that refusal is right for every other caller. Creating one
            is a decision, and this is the one place entitled to make it. *)
         GDatabase.CreateNew(dbName);
         isNewLog := True;
         end;

      (* WHICH FILE IS THIS LOG? NY4I asked for it, 2026-09-02: "The log should
        show the name of the database file. If not, it should."

        IT IS THE FIRST QUESTION EVERY REPORT NEEDS and nothing answered it.
        Diagnosing an edit that would not stick meant working out the path from
        the contest name; if a write and a read ever land on different files,
        this line is what shows it. Logged ONCE per open, not per statement. *)
      if logger <> nil then
         begin
         logger.Info('[LogStore] log database: %s', [dbName]);
         end;

      GRepository := TLogRepository.Create(GDatabase);


      GRepository.SetEntryDeclaration(ReadEntryDeclaration);

      (* THE CONFIGURATION IS CAPTURED WHEN THE LOG IS MADE, AND ONLY THEN.

         E1 refreshed it on every open, which was right while nothing read it
         back. It is exactly wrong now that something does: the stored
         configuration IS the contest's configuration, so overwriting it at
         open with whatever the .cfg happens to say would hand authority back
         to the file this work exists to retire -- and would silently discard
         anything the operator had changed.

         A MIGRATED LOG COUNTS AS NEW, and must: it has just been built from a
         binary log that carried no configuration at all, so the .cfg read at
         startup is the only description of that contest in existence. Skipping
         the capture there would leave it with none.

         Changes made DURING a contest are written back at LogStoreClose --
         see there, and see the limitation it states. *)
      if isNewLog or aRebuilt then
         begin
         CaptureConfiguration;
         end;

      Result := True;
   except
      on E: Exception do
         begin
         Disable('opening the log', E);
         Result := False;
         end;
   end;
end;

procedure LogStoreAppendQSO(const aQso: ContestExchange);
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

procedure LogStoreUpdateNewestQSO(const aQso: ContestExchange);
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

procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange);
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
      (* A REBUILD USED TO MEAN "THE EDIT IS ALREADY IN THE BINARY LOG", AND
        THAT STOPPED BEING TRUE. This exited here on the reasoning that the
        caller wrote to the .TRW before calling and the rebuild had just
        re-read it. uEditQSO's seek-and-write is gone, so nothing puts the edit
        anywhere but this call -- exiting would DISCARD it, silently, which is
        the same class of defect as the OpenLogFile gate in that unit.

        SO THE UPDATE PROCEEDS. A rebuild here only happens on the one-time
        migration of an existing .TRW, and after it the row for this record
        exists and is exactly what the migration produced -- which is the
        record WITHOUT the operator's edit. Applying it is the correct
        finish to the migration, not a race with it.

        REPORTED EITHER WAY, because a rebuild in the middle of saving an edit
        is worth knowing about and this branch said nothing at all. *)
      if rebuilt and (logger <> nil) then
         begin
         logger.Info('[LogStore] the log was rebuilt while saving an edit to ' +
                     'record %d; applying the edit on top of the rebuild',
                     [aRecordIndex]);
         end;

      rowId := GRepository.RowIdAtIndex(aRecordIndex);
      if rowId <= 0 then
         begin
         (* The shadow is short of that record. EnsureOpen's drift check will
           rebuild at the next open; saying so here is what makes that visible
           rather than mysterious. *)
         if logger <> nil then
            begin
            logger.Warn('[LogStore] no row at record index %d -- the shadow ' +
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

function LogStoreUpdateQSOBySessionIds(const aQso: ContestExchange): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt, False) then
         begin
         Exit;
         end;

      (* False when the pair is unset or matches nothing, and that is not an
        error -- it means this station has no such QSO. *)
      Result := GRepository.UpdateQSOBySessionIds(aQso.ceQSOID1, aQso.ceQSOID2, aQso);
      if Result then
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

function LogStoreApplyContestConfig: integer;
var
   rebuilt: boolean;
   rows: TStringList;
   i: integer;
   cmd, val: string;
   renderable: boolean;
   (* A NAMED LOCAL, so PAnsiChar below points at a string that is still alive.
      PAnsiChar of a temporary is a dangling pointer -- Delphi's allocator hid
      that and FPC's does not. *)
   cmdName: ShortString;
   valName: ShortString;
   idx: integer;
   valAsShort: ShortString;
begin
   Result := 0;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt, False) then
         begin
         Exit;
         end;

      rows := TStringList.Create;
      try
         GRepository.LoadContestConfig(rows);
         (* THE CONTEST COMES FROM THE CONTEST TABLE, NOT FROM A CAPTURED
           SETTING -- and it is applied FIRST, because everything else depends
           on it. FoundContest sets the Contest enum, ActiveExchange and the
           domestic file; until it has run, ProcessExchange has no arm to take
           and no QSO can be logged.

           WHY THE TABLE AND NOT THE config ROW. contest_type is written once,
           when the log is created, and never recomputed. The captured CONTEST
           row is rewritten on every clean exit from whatever the running
           program believed at the time -- so a single bad session poisons it
           permanently, which is exactly what happened. One of the two is a
           fact about the log; the other is a fact about a session.

           A captured CONTEST row is ignored below for the same reason. *)
         (* ONLY WHEN NOTHING ELSE HAS ANSWERED. If a contest .cfg was read it
           has already set this, and it is the better source: the table'''s
           contest_type is derived at IMPORT from the first record'''s ceContest
           ordinal, and a .TRW written under an older ContestType layout maps
           that ordinal to the wrong name. Measured 2026-09-03: the golden
           corpus'''s winter_fd log is stamped ALRS-UA1DZ-CUP while its .CFG says
           WINTER FIELD DAY, and applying the table unconditionally broke that
           set'''s export and made the factory A/B disagree.

           So the table answers the case it exists for -- a log with no .cfg at
           all, which is every contest created by the New Contest dialog -- and
           stays out of the way otherwise. *)
         if (GRepository.LogContest <> DUMMYCONTEST) and
            ((CFGCommandValueAsString('CONTEST') = '') or
             (CFGCommandValueAsString('CONTEST') =
              string(ContestTypeSA[DUMMYCONTEST]))) then
            begin
            cmdName := ShortString(AnsiString('CONTEST'));
            valName := ShortString(AnsiString(
               ContestTypeSA[GRepository.LogContest]));
            (* ONLY IF IT IS NOT ALREADY RIGHT. FoundContest is NOT
               idempotent -- re-running it appends to the domestic file name
               (dom\iaruhq.domiaruhq.dom), and applying it unconditionally on
               every open took the golden corpus from 20 passed to 10 passed /
               14 failed in one run. The comparison is against the CFGCA row
               because that is what the hook maintains; the VALUE comes from
               the contest table because that is what is trustworthy. *)
            if (CFGCommandValueAsString('CONTEST') <> string(valName)) and
               CheckCommand(@cmdName, valName, True) then
               begin
               if logger <> nil then
                  begin
                  logger.Info('[LogStore] contest: %s (from the log)',
                              [string(valName)]);
                  end;
               end
            else if logger <> nil then
               begin
               logger.Error('[LogStore] the log names contest "%s" and this ' +
                            'build did not accept it.', [string(valName)]);
               end;
            end;

         for i := 0 to rows.Count - 1 do
            begin
            cmd := rows.Names[i];

            (* Applied above, from the contest table. *)
            if cmd = 'CONTEST' then
               begin
               Continue;
               end;

            val := rows.ValueFromIndex[i];
            if cmd = '' then
               begin
               Continue;
               end;

            (* AN ACTION IS NOT A SETTING, AND APPLYING ONE HANGS THE PROGRAM.

              REMINDER is the case that found this. It is a COMMAND, not a
              value: applying it calls QuickEditResponse('Enter time for
              reminder') and waits for the operator (HELP.PAS:642). In a
              headless /EXPORT that waits forever; in the interactive program it
              is worse, because the prompt takes the keyboard in the quick
              command window and the operator sees a log that has simply stopped
              accepting QSOs -- NY4I, 2026-09-02: "stuck at entering the zone 4".

              THE GUARD IS HERE, ON THE APPLY, AND NOT ONLY ON THE CAPTURE.
              CaptureConfiguration no longer stores these, but every log written
              before that fix already has them -- 410 rows including REMINDER
              and the two ctFreqList commands. Guarding only the writer would
              leave every existing log broken and unopenable, and the operator
              with no way to tell why. A reader that can be handed bad data has
              to defend itself.

              SAME QUESTION THE CAPTURE ASKS, so the two cannot drift: can this
              command's value be written down at all? If it cannot, it was never
              a setting and there is nothing here to restore. Reported once per
              command rather than silently, because a log carrying rows this
              build refuses is worth knowing about. *)
            CFGCommandValueAsString(cmd, renderable);
            if not renderable then
               begin
               if logger <> nil then
                  begin
                  logger.Warn('[LogStore] "%s" is an action, not a setting -- ' +
                              'ignored. It was captured by a build that should ' +
                              'not have stored it.', [cmd]);
                  end;
               Continue;
               end;

            (* CheckCommand WITH aApplyJSONOwned = TRUE -- the mechanism uCFG
               already provides for exactly this, in its own words:

                 "Default False keeps every existing caller, above all the ini
                  loader, exactly as it was. A trusted caller passes True and
                  the row behaves like any other."

               THE LOG IS THAT TRUSTED CALLER. csJSON means settings\tr4w.json
               owns the row, which is right for a STATION setting; CONTEST and
               the CATEGORY tags are properties of THIS CONTEST, and the log is
               where they now live.

               TWO WRONG ROUTES WERE TRIED FIRST, and both failed the same way.
               SetCFGCommandValue is the "operator changed a setting" path: it
               applies AND PERSISTS, and refuses csJSON outright with "Refusing
               to write tr4w.ini". ProcessConfigInstruction is the .cfg reader's
               line handler, and it calls CheckCommand with the default -- so it
               skips csJSON rows silently and returns True, reporting success
               for a command it did not apply.

               Measured with an emptied .cfg: CONTEST, CATEGORY-POWER,
               CATEGORY-OPERATOR, CATEGORY-BAND, CATEGORY-MODE and
               CATEGORY-TRANSMITTER were all refused, the contest was never set,
               and THE EXPORT PRODUCED NOTHING -- while the log held every one
               of those values.

               Nothing here needs persisting: the value came OUT of the log,
               which is where it is stored. What is wanted is the application
               only -- the same range checks, type conversion and crA hook a
               .cfg line gets. *)
            (* A SHORTSTRING, AND ITS ADDRESS -- NOT PAnsiChar OF AN AnsiString.

               CheckCommand declares its first parameter PAnsiChar and then
               compares with StrComp(@Command[1], ...) -- skipping a byte. That
               is only right if what was passed is a pointer to a SHORTSTRING,
               whose byte 0 is the length and whose first character is at [1].
               Every existing caller does that: ProcessConfigInstruction passes
               @ID with ID a ShortString.

               Handing it PAnsiChar of an AnsiString points at the first
               CHARACTER, so the comparison started one in: 'CONTEST' was
               matched as 'ONTEST', no row was found, and every command came
               back rejected -- with a warning that plausibly blamed the value.

               The declared type cannot catch this; both are PAnsiChar. *)
            (* ONLY WHAT ACTUALLY DIFFERS.

               Re-applying a command that already holds the stored value is not
               free, because a row's crA hook is not required to be idempotent
               and at least one is not. CONTEST's rebuilds the domestic-file
               name, and running it twice produced

                   dom\iaruhq.domiaruhq.dom

               -- the name appended to itself. The file could not be opened, the
               contest loaded no domestic data, and the export produced NOTHING.
               All seven settings had applied successfully; applying them was
               the problem.

               Skipping the no-ops also makes this a genuine no-op when the .cfg
               and the log agree, which is every log created by this build --
               and is why the corpus does not move. *)
            (* SKIP A NO-OP ONLY WHERE APPLYING IT REALLY WOULD BE ONE.

               A ROW WITH A crA HOOK DOES MORE THAN STORE A VALUE, and CONTEST
               is the one that matters: its hook runs FoundContest, which sets
               the Contest enum, ActiveExchange and the domestic file. The
               stored STRING can already match while none of that has happened
               -- which is precisely the state a log-backed contest starts in,
               because nothing parsed a .cfg to make it happen.

               MEASURED 2026-09-03: startup logged "the log applied 2 contest
               setting(s)" while the title bar showed NO CONTEST. CONTEST was
               counted here and skipped, so ActiveExchange stayed
               UnknownExchange; ProcessExchange's case has no else, so it
               returned False in silence and no QSO could be logged at all.
               The count was the most misleading part -- it reported success
               for the very row it had declined to apply.

               THE COMPARISON STAYS FOR ORDINARY ROWS, which is what it was
               added for: CONTEST's hook is NOT idempotent, and re-applying it
               appended to the domestic file name. Both facts are true, and the
               crA test is what separates them. *)
            idx := FindCFGCommand(cmd);
            if (CFGCommandValueAsString(cmd) = val) and
               (idx >= 0) and (CFGCA[idx].crA = 0) then
               begin
               inc(Result);
               Continue;
               end;

            FillChar(cmdName, SizeOf(cmdName), 0);
            FillChar(valAsShort, SizeOf(valAsShort), 0);
            cmdName := ShortString(AnsiString(cmd));

            (* PLAIN ASSIGNMENT, NOT ShortString(val).

               THE CAST IS NOT A CONVERSION. FPC reinterprets the string's
               POINTER as a ShortString -- the first byte of the pointer becomes
               the length -- so CheckCommand received garbage and rejected every
               command, silently and with a perfectly plausible warning saying
               the build would not accept the value. The value was fine; it
               never arrived.

               CLAUDE.md lists this under "Strings and buffers" and it has now
               cost two separate sessions of this migration. Assignment converts
               and truncates correctly; the cast compiles and lies. *)
            valAsShort := ShortString(AnsiString(val));
            if CheckCommand(@cmdName, valAsShort, True) then
               begin
               inc(Result);
               end
            else
               begin
               (* Reported rather than skipped in silence: a command the log
                  carries and this build will not accept is either a setting
                  withdrawn since the log was made or a value out of range, and
                  both are things an operator would want to know rather than
                  discover by its absence. *)
               if logger <> nil then
                  begin
                  logger.Warn('[LogStore] the log sets %s = %s and this build ' +
                              'would not accept it (CFGCA row %d). The command ' +
                              'is left at its current value.',
                              [cmd, val, FindCFGCommand(cmd)]);
                  end;
               end;
            end;
      finally
         rows.Free;
      end;
   except
      on E: Exception do
         begin
         Disable('applying the contest configuration', E);
         Result := 0;
         end;
   end;
end;

function LogStoreEnsureOpen: boolean;
var
   rebuilt: boolean;
begin
   (* aAppendPending FALSE: nobody is part way through adding a QSO here, so the
      log and the shadow should agree exactly. *)
   Result := EnsureOpen(rebuilt, False);
end;

(* WHAT THE CONTEST'S CONFIGURATION IS WHEN THE OPERATOR STOPS.

  The capture at creation records what the contest STARTED as. An operator who
  changes QSO POINT METHOD, or edits an F-key memory, halfway through has
  changed the contest's configuration, and the log has to carry the new value or
  it is not self-describing.

  ON CLOSE RATHER THAN ON EVERY CHANGE, and the limitation is worth stating
  plainly: SetCFGCommandValue is called from dozens of places, several of them
  DURING config load, so hooking it would mean writing to the store before it is
  open and re-recording the file the load just read. Closing is the one moment
  the configuration is definitely settled.

  THE COST IS A CRASH. Kill TR4W mid-contest and the settings changed in that
  session are not in the log, though every QSO is -- QSOs are committed as they
  are made. Recording changes as they happen is the fix, and it belongs with
  the settings work rather than here. *)
procedure CaptureConfigurationOnClose;
begin
   (* A BATCH EXPORT DOES NOT REWRITE THE LOG IT IS EXPORTING.

     The program already says so at startup -- "batch /EXPORT: settings are
     READ-ONLY for this run" -- and this was quietly contradicting it, writing
     roughly four hundred config rows into the log on the way out of a run
     whose whole purpose is to read.

     IT WAS ALSO MAKING THE GOLDEN CORPUS FLAKY. A different set aborted on
     every run once the capture started happening, because each of the thirteen
     exports now did a few hundred extra writes at close and the next run read
     back whatever that left. A regression oracle that changes its answer
     between runs is worse than no oracle.

     THE CAPTURE IS FOR AN INTERACTIVE SESSION, where the operator has actually
     changed something. *)
   if tSilentExport then
      begin
      Exit;
      end;

   if (GRepository = nil) or GDisabled then
      begin
      Exit;
      end;
   try
      CaptureConfiguration;
   except
      on E: Exception do
         begin
         (* Reported, not raised: this runs while shutting down, and a failure
            to record a setting must not stop the program closing its log. *)
         if logger <> nil then
            begin
            logger.Error('[LogStore] the configuration could not be recorded ' +
                         'on close: %s -- %s. QSOs are unaffected.',
                         [E.ClassName, E.Message]);
            end;
         end;
   end;
end;

procedure LogStoreClose;
begin
   CaptureConfigurationOnClose;
   FreeAndNil(GRepository);
   FreeAndNil(GDatabase);
end;

(* A BACKSTOP FOR THE EXIT PATHS THAT ARE NOT tr4w_ShutDown.

  THE TWO EXITS ARE NOT THE SAME AND NEITHER COVERS THE OTHER. The interactive
  program leaves through ExitProcess, which runs NO finalization at all -- so
  this section is dead on that path and the explicit call in tr4w_ShutDown is
  the one that works. The headless modes leave through Halt (/EXPORT, /RESCORE,
  /IMPORTLOG and the startup refusals), which DOES run finalization but never
  reaches tr4w_ShutDown -- so there the explicit call is the dead one and this
  section is what closes the database.

  Corpus runs are the headless case, and they were leaving a -wal behind on
  every one of the thirteen logs.

  SAFE TO RUN TWICE: LogStoreClose is FreeAndNil throughout and
  CaptureConfigurationOnClose returns immediately once GRepository is nil. *)
finalization
   try
      LogStoreClose;
   except
      on E: Exception do
         begin
         (* Finalization order is not ours to choose and a unit this one
           depends on may already be gone. A crash HERE loses the whole
           run for a close that has usually already happened in
           tr4w_ShutDown. *)
         end;
   end;

end.
