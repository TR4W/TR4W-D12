(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* Q9 -- AN OPERATOR-EDITED CQ MEMORY SURVIVES RE-SELECTING THE CONTEST
  (NY4I, 2026-10-15: "Accept"; "an edited memory is an operator statement").

  A contest's set-up writes default CQ memories -- its TSessionDefaults
  memories (FCONTEST.ApplySessionDefaults) and the engine's default exchange
  messages (CQ F3, FCONTEST's SetUpRST... writers) -- and overwrote the
  operator's edit every time the contest was set up again. Each now goes
  through LogCW.SetContestDefaultCQMemoryString, which leaves a memory the
  operator stated alone (the Alt-P dialog's TryApplyMessageCommand and the
  line-input edit latch it). A statement belongs to the contest set up last:
  setting up ANOTHER contest forgets it, so one contest's edit is never
  carried into the next.

  Driven through the latch and the engine's real default writer; the
  program's memories and messages are restored afterwards.

  Q113 -- AND ACROSS A RESTART (2026-10-23). The log's message table flags the
  memories the operator edited (schema 4, message.edited) and the open puts
  back ONLY those, after the contest has set up its defaults, through the
  same latch -- D7 kept an Alt-P edit across a restart in its .cfg. Pinned
  through uLogStore's own capture and restore against a real log file:

    an edited memory (both banks, a caption, an edit to empty) survives a
    close and reopen, and a re-selection after the restore keeps it;

    an UNEDITED memory comes back as the contest's CURRENT default, not the
    one the table stored -- restoring that would pin a default built from an
    old MY STATE;

    a log from before schema 4 opens, gains the column, and restores
    nothing. *)
unit uTestOperatorCQMemory;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework,
   VC,      (* ContestType *)
   LogCW;   (* FunctionKeyMemoryArray *)

type
   TOperatorCQMemoryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      FSavedCQ: FunctionKeyMemoryArray;
      FSavedEX: FunctionKeyMemoryArray;
      FSavedCQCaption: FunctionKeyMemoryArray;
      FSavedEXCaption: FunctionKeyMemoryArray;
      FSavedCQExchange: string;
      FSavedSPExchange: string;
      FSavedRepeatSPExchange: string;
      FSavedLogName: string;
      FSavedSilent: boolean;
      FTrw: string;
      FDb: string;
      procedure Test_AStatedCQMemoryIsNotADefault;
      procedure Test_ReSelectingTheContestKeepsAnEditedCQMemory;
      procedure Test_Q113_AnEditedMemorySurvivesARestart;
      procedure Test_Q113_AnUneditedMemoryIsTheCurrentDefault;
      procedure Test_Q113_AnOldSchemaLogRestoresNothing;
      (* R2 and R3 (2026-10-23): through the production paths. *)
      procedure Test_R2_AnAcceptedEditIsCommittedWhenOKIsPressed;
      procedure Test_R2_ACommitThatFailsIsNotReportedSaved;
      procedure Test_R3_AnEditSurvivesTheProductionReopen;
      (* R3's focused cases, through the capture and restore helpers. *)
      procedure Test_R3_CWAndPhoneAreSeparateMemories;
      procedure Test_R3_EveryKeyRoundTripsInBothBanks;
      procedure Test_R3_ACaptionOnlyEditRoundTrips;
      procedure Test_R3_AKeyNoLongerEditedLeavesNoEditedRow;
      procedure Test_R3_AnUnknownRowIsSkippedAndTheRestRestore;
      procedure Test_R3_ARestoredEditIsCapturedAsAnEditAgain;
      (* The program's memories, captions and messages, kept and put back. *)
      procedure SaveProgramMemories;
      procedure RestoreProgramMemories;
      (* The STORE pointed at a database-only CQ WPX log, writes allowed, and
         back. A store test that fails can disable the store for the rest of
         the run (GDisabled is never cleared) and, with writes allowed, show a
         modal -- so each one checks the store is usable before it writes. *)
      procedure StartStore(const aLeaf: string);
      procedure StopStore;
      (* The memories into, and the edited ones back out of, a log file. *)
      procedure CaptureTo(const aFileName: string);
      function RestoreFrom(const aFileName: string): integer;
      (* One message row, read through its own connection. *)
      function ReadMessageRow(const aFileName, aKind, aMode, aKeyId: string;
                              out aText, aCaption: string;
                              out aEdited: integer): boolean;
      (* What FoundContest does for a contest's memories: forget another
         contest's statements, then write the defaults (CQ WPX's serial
         exchange: CQ F3 '5NN #', EX F3 '5NN', F4 'NR #', AltF4 'NR?'). *)
      procedure SetUpContest(aContest: ContestType);
      (* A NEW RUN OF THE PROGRAM, as far as the memories go: no statement is
         latched, the memories hold whatever start-up left, and the contest
         is then set up. *)
      procedure Restart;
      function TempLog(const aLeaf: string): string;
   end;

implementation

uses
   SysUtils,
   Contnrs,              (* TObjectList -- LoadEditedMessages *)
   Tree,
   uSettingsModel,
   FCONTEST,
   cfgdef,               (* UpdateSAndPF1Caption -- startup's last default writer *)
   uCFG,                 (* CFGCommandValueAsString *)
   uContestRegistry,
   sqldb,
   utils_text,           (* CharBufferText / SetCharBuffer -- TR4W_LOG_FILENAME *)
   uLogSchema,
   uLogDatabase,
   uLogRepository,
   uLogStore,            (* CaptureMessageMemories / RestoreEditedMessageMemories *)
   uEditMessageForm,     (* ApplyAcceptedMessageEdit -- what OK does *)
   uTestLatestContest;   (* MakeTestContestLog / ScrubTestLog / DowngradeTestLog *)

var
   (* What the replay handed the test's contest set-up, and how often. *)
   GSetUpContestId: string;
   GSetUpCalls: integer;
   (* The store's failure notices, taken instead of the modal. *)
   GNotices: integer;
   GLastNotice: string;

procedure TakeTheNotice(const aText: RawByteString);
begin
   Inc(GNotices);
   GLastNotice := string(aText);
end;

(* THE TEST'S CONTEST SET-UP for LogStoreApplyContestConfigWith: what
   FoundContest does to the memories -- forget another contest's statements,
   write CQ WPX's default memories -- and nothing else, so the session other
   suites read is not rewritten. *)
function SetUpTheLogsContest(const aContestId: ShortString): boolean;
begin
   GSetUpContestId := string(aContestId);
   Inc(GSetUpCalls);
   ForgetMemoryStatementsOfOtherContests(ContestHandleOf(CQWPXCW));
   SetUpRSTQSONumberExchange;
   Result := True;
end;

(* The latch alone: a stated memory is not overwritten by a default, an
   unstated one is, and another contest's set-up forgets the statement. *)
procedure TOperatorCQMemoryTests.Test_AStatedCQMemoryIsNotADefault;
var
   savedF3: string;
   savedF4: string;
begin
   BeginTest('Test_AStatedCQMemoryIsNotADefault');
   savedF3 := string(GetCQMemoryString(CW, F3));
   savedF4 := string(GetCQMemoryString(CW, F4));
   try
      ForgetMemoryStatementsOfOtherContests(ContestHandleOf(CQWWCW));
      ForgetMemoryStatementsOfOtherContests(ContestHandleOf(ARRLDXCW));
      CheckFalse(CQMemoryIsOperatorStated(CW, F3), 'nothing is stated after a set-up');

      CheckTrue(TryApplyMessageCommand('CQ CW MEMORY F3', 'MY OWN F3'), 'the dialog''s edit applies');
      CheckEquals('MY OWN F3', string(GetCQMemoryString(CW, F3)), 'and is the memory');
      CheckTrue(CQMemoryIsOperatorStated(CW, F3), 'and is latched');
      CheckFalse(CQMemoryIsOperatorStated(CW, F4), 'only the key edited');

      SetContestDefaultCQMemoryString(CW, F3, 'A DEFAULT');
      CheckEquals('MY OWN F3', string(GetCQMemoryString(CW, F3)), 'a default does not overwrite it');
      SetContestDefaultCQMemoryString(CW, F4, 'A DEFAULT');
      CheckEquals('A DEFAULT', string(GetCQMemoryString(CW, F4)), 'a default fills an unstated key');

      (* THE SAME CONTEST AGAIN KEEPS IT; ANOTHER FORGETS IT. *)
      ForgetMemoryStatementsOfOtherContests(ContestHandleOf(ARRLDXCW));
      CheckTrue(CQMemoryIsOperatorStated(CW, F3), 'the same contest keeps the statement');
      ForgetMemoryStatementsOfOtherContests(ContestHandleOf(CQWWCW));
      CheckFalse(CQMemoryIsOperatorStated(CW, F3), 'another contest forgets it');
      SetContestDefaultCQMemoryString(CW, F3, 'A DEFAULT');
      CheckEquals('A DEFAULT', string(GetCQMemoryString(CW, F3)), 'and writes its own default');

      (* AN EXCHANGE MEMORY IS NOT A CQ MEMORY: no latch. *)
      CheckTrue(TryApplyMessageCommand('EX CW MEMORY F4', 'EX EDIT'), 'an exchange memory edit applies');
      CheckFalse(CQMemoryIsOperatorStated(CW, F4), 'and latches no CQ memory');
   finally
      SetCQMemoryString(CW, F3, ShortString(savedF3));
      SetCQMemoryString(CW, F4, ShortString(savedF4));
      ForgetMemoryStatementsOfOtherContests(NoContest);
   end;
end;

(* THROUGH THE ENGINE'S DEFAULT EXCHANGE MESSAGES -- the writer a serial
   contest's set-up runs (FCONTEST.SetUpRSTQSONumberExchange, CQ F3 = '5NN #').
   Each set-up below is what FoundContest does for a contest: forget another
   contest's statements, then write the defaults. FoundContest itself is not
   run -- it writes the whole session, which other suites read -- so the
   running program's re-selection is a bench item (BENCH_QUEUE). The writer
   also writes the exchange memories and three messages; they are restored. *)
procedure TOperatorCQMemoryTests.Test_ReSelectingTheContestKeepsAnEditedCQMemory;
const
   EX_KEYS: array[0..4] of AnsiChar = (F3, F4, F5, AltF3, AltF4);
var
   savedCQF3: string;
   savedEX: array[0..4] of string;
   savedCQExchange, savedSPExchange, savedRepeatSPExchange: string;
   i: integer;

   procedure SetUpForContest(aContest: ContestType);
   begin
      ForgetMemoryStatementsOfOtherContests(ContestHandleOf(aContest));
      SetUpRSTQSONumberExchange;
   end;

begin
   BeginTest('Test_ReSelectingTheContestKeepsAnEditedCQMemory');
   savedCQF3 := string(GetCQMemoryString(CW, F3));
   for i := Low(EX_KEYS) to High(EX_KEYS) do
      begin
      savedEX[i] := string(GetEXMemoryString(CW, EX_KEYS[i]));
      end;
   savedCQExchange := string(Settings.Messages.CqExchangeCw);
   savedSPExchange := string(Settings.Messages.SpExchangeCw);
   savedRepeatSPExchange := string(Settings.Messages.RepeatSpExchangeCw);
   try
      SetUpForContest(CQWPXCW);
      CheckEquals('5NN #', string(GetCQMemoryString(CW, F3)), 'the set-up writes its default CQ F3');

      CheckTrue(TryApplyMessageCommand('CQ CW MEMORY F3', 'TEST NY4I EDITED'), 'the operator edits CQ F3');
      SetUpForContest(CQWPXCW);
      CheckEquals('TEST NY4I EDITED', string(GetCQMemoryString(CW, F3)),
                  're-selecting the contest keeps the operator''s CQ F3');
      CheckEquals('5NN', string(GetEXMemoryString(CW, F3)),
                  'and still writes the exchange memories it did not edit');

      SetUpForContest(ARRLDXCW);
      CheckEquals('5NN #', string(GetCQMemoryString(CW, F3)),
                  'another contest writes its own default: the edit is not carried over');
      SetUpForContest(CQWPXCW);
      CheckEquals('5NN #', string(GetCQMemoryString(CW, F3)),
                  'and coming back finds the default -- the edit belonged to the old set-up');
   finally
      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetCQMemoryString(CW, F3, ShortString(savedCQF3));
      for i := Low(EX_KEYS) to High(EX_KEYS) do
         begin
         SetEXMemoryString(CW, EX_KEYS[i], ShortString(savedEX[i]));
         end;
      Settings.Messages.CqExchangeCw := savedCQExchange;
      Settings.Messages.SpExchangeCw := savedSPExchange;
      Settings.Messages.RepeatSpExchangeCw := savedRepeatSPExchange;
   end;
end;

procedure TOperatorCQMemoryTests.SaveProgramMemories;
begin
   FSavedCQ := CQMemory;
   FSavedEX := EXMemory;
   FSavedCQCaption := CQCaptionMemory;
   FSavedEXCaption := EXCaptionMemory;
   FSavedCQExchange := string(Settings.Messages.CqExchangeCw);
   FSavedSPExchange := string(Settings.Messages.SpExchangeCw);
   FSavedRepeatSPExchange := string(Settings.Messages.RepeatSpExchangeCw);
end;

procedure TOperatorCQMemoryTests.RestoreProgramMemories;
begin
   ForgetMemoryStatementsOfOtherContests(NoContest);
   CQMemory := FSavedCQ;
   EXMemory := FSavedEX;
   CQCaptionMemory := FSavedCQCaption;
   EXCaptionMemory := FSavedEXCaption;
   Settings.Messages.CqExchangeCw := FSavedCQExchange;
   Settings.Messages.SpExchangeCw := FSavedSPExchange;
   Settings.Messages.RepeatSpExchangeCw := FSavedRepeatSPExchange;
end;

procedure TOperatorCQMemoryTests.SetUpContest(aContest: ContestType);
begin
   ForgetMemoryStatementsOfOtherContests(ContestHandleOf(aContest));
   SetUpRSTQSONumberExchange;
end;

procedure TOperatorCQMemoryTests.Restart;
begin
   ForgetMemoryStatementsOfOtherContests(NoContest);
   SetCQMemoryString(CW, F3, 'LEFT BY START-UP');
   SetCQCaptionMemoryString(CW, F3, '');
   SetEXMemoryString(CW, F4, 'LEFT BY START-UP');
   SetEXMemoryString(CW, AltF4, 'LEFT BY START-UP');
   SetUpContest(CQWPXCW);
end;

function TOperatorCQMemoryTests.TempLog(const aLeaf: string): string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_q113_' +
             IntToStr(GetProcessID) + '_' + aLeaf;
end;

(* EDITED, CLOSED, RESTARTED, REOPENED: the edits come back -- the CQ bank and
   its caption, the EX bank, and an exchange memory edited to EMPTY -- and a
   re-selection of the contest after the restore keeps them, because the
   restore latches them exactly as the edit did. *)
procedure TOperatorCQMemoryTests.Test_Q113_AnEditedMemorySurvivesARestart;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
begin
   BeginTest('Test_Q113_AnEditedMemorySurvivesARestart');
   CheckTrue(LOG_SCHEMA_VERSION >= 4, 'the schema carries message.edited');
   fn := TempLog('edited.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');

      (* THE SESSION THAT EDITS. *)
      SetUpContest(CQWPXCW);
      CheckTrue(TryApplyMessageCommand('CQ CW MEMORY F3', 'MY CQ EDIT'), 'CQ F3 edited');
      CheckTrue(TryApplyMessageCommand('CQ CW MEMORY F3 CAPTION', 'MYCAP'), 'and its caption');
      CheckTrue(TryApplyMessageCommand('EX CW MEMORY F4', 'MY EX EDIT'), 'EX F4 edited');
      CheckTrue(TryApplyMessageCommand('EX CW MEMORY ALTF4', ''), 'EX AltF4 edited to empty');
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         repo := TLogRepository.Create(db);
         try
            CaptureMessageMemories(repo);
            repo.Commit;
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;

      (* THE NEXT RUN, before the log is read: the contest's defaults. *)
      Restart;
      CheckEquals('5NN #', string(GetCQMemoryString(CW, F3)),
                  'the restart really starts from the default');
      CheckEquals('NR #', string(GetEXMemoryString(CW, F4)), 'EX F4 too');

      db := TLogDatabase.Create;
      try
         db.Open(fn);
         repo := TLogRepository.Create(db);
         try
            CheckEquals(3, RestoreEditedMessageMemories(repo),
                        'three edited keys restored: CQ F3, EX F4, EX AltF4');
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;

      CheckEquals('MY CQ EDIT', string(GetCQMemoryString(CW, F3)), 'the CQ edit is back');
      CheckEquals('MYCAP', string(CQCaptionMemory[CW, F3]), 'with its caption');
      CheckEquals('MY EX EDIT', string(GetEXMemoryString(CW, F4)), 'the EX edit is back');
      CheckEquals('', string(GetEXMemoryString(CW, AltF4)),
                  'an edit to empty is back as empty, not the default');
      CheckEquals('5NN', string(GetEXMemoryString(CW, F3)),
                  'an unedited key keeps the contest''s default');

      (* ONE RULE FOR A RE-SELECT AND A RESTART: the restored edits are
         statements, so setting the same contest up again keeps them. *)
      SetUpContest(CQWPXCW);
      CheckEquals('MY CQ EDIT', string(GetCQMemoryString(CW, F3)),
                  're-selecting after the restore keeps the CQ edit');
      CheckEquals('MY EX EDIT', string(GetEXMemoryString(CW, F4)),
                  'and the EX edit');
      CheckEquals('', string(GetEXMemoryString(CW, AltF4)),
                  'and the edit to empty');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* A ROW NOBODY EDITED IS A RECORD, NOT A SETTING. Session one closes with a
   default built from an older station (EX F4 'NR OLD', written the way a
   contest's set-up writes it); the next run's contest builds 'NR #'; the
   open must leave 'NR #' alone. *)
procedure TOperatorCQMemoryTests.Test_Q113_AnUneditedMemoryIsTheCurrentDefault;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   q: TSQLQuery;
begin
   BeginTest('Test_Q113_AnUneditedMemoryIsTheCurrentDefault');
   fn := TempLog('unedited.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');

      SetUpContest(CQWPXCW);
      SetContestDefaultEXMemoryString(CW, F4, 'NR OLD');
      CheckEquals('NR OLD', string(GetEXMemoryString(CW, F4)), 'the old default is in force');
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         repo := TLogRepository.Create(db);
         try
            CaptureMessageMemories(repo);
            repo.Commit;
         finally
            repo.Free;
         end;

         (* THE TABLE DOES HOLD IT -- so what follows discriminates. *)
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.SQL.Text := 'SELECT text, edited FROM message WHERE kind = ''EX'' ' +
                          'AND mode = ''CW'' AND key_id = ''F4''';
            q.Open;
            CheckFalse(q.EOF, 'EX F4 has a row');
            CheckEquals('NR OLD', q.Fields[0].AsString, 'holding the old default');
            CheckEquals(0, q.Fields[1].AsInteger, 'flagged not edited');
            q.Close;
         finally
            q.Free;
         end;
      finally
         db.Free;
      end;

      Restart;
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         repo := TLogRepository.Create(db);
         try
            CheckEquals(0, RestoreEditedMessageMemories(repo), 'nothing was edited');
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;
      CheckEquals('NR #', string(GetEXMemoryString(CW, F4)),
                  'the CURRENT default, not the stored one');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* A LOG A SCHEMA-3 BUILD WROTE: the message table has no edited column, and
   its rows -- whatever they hold -- were never marked as edits. Opening it
   adds the column (0 throughout) and restores nothing. *)
procedure TOperatorCQMemoryTests.Test_Q113_AnOldSchemaLogRestoresNothing;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
begin
   BeginTest('Test_Q113_AnOldSchemaLogRestoresNothing');
   fn := TempLog('schema3.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');

      (* A ROW, then BACK TO SCHEMA 3 on disk through the shared downgrade
        (R4): the edited column goes, the row stays as a schema-3 build
        wrote it, user_version 3. *)
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         repo := TLogRepository.Create(db);
         try
            repo.SaveMessage('CQ', 'CW', 'F3', 'WRITTEN BY SCHEMA 3', '');
            repo.Commit;
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;
      DowngradeTestLog(fn, 3, Low(LOG_V3_QSO_COLUMNS));

      db := TLogDatabase.Create;
      try
         db.OpenReadOnly(fn);
         CheckEquals(3, db.SchemaVersion, 'the fixture really is schema 3');
         CheckFalse(TestLogHasColumn(db, 'message', 'edited'), 'with no edited column');
      finally
         db.Free;
      end;

      Restart;
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'it opens and migrates');
         CheckTrue(TestLogHasColumn(db, 'message', 'edited'), 'gaining the edited column');
         repo := TLogRepository.Create(db);
         try
            CheckEquals(0, RestoreEditedMessageMemories(repo),
                        'and restores nothing: no row was marked an edit');
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;
      CheckEquals('5NN #', string(GetCQMemoryString(CW, F3)),
                  'CQ F3 is the contest''s default, not the old row');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* ------------------------------------------------------------- helpers *)

procedure TOperatorCQMemoryTests.StartStore(const aLeaf: string);
begin
   (* WHATEVER AN EARLIER SUITE LEFT OPEN IS CLOSED WITHOUT A CAPTURE first,
     so nothing is written into a file that is not this test's. *)
   FSavedSilent := tSilentExport;
   tSilentExport := True;
   LogStoreClose;

   FTrw := TempLog(aLeaf + '.trw');
   FDb := LogDatabaseFileName(FTrw);
   (* A DATABASE-ONLY CONTEST: a log naming CQ WPX CW, with no .cfg and no
     .TRW beside it. *)
   MakeTestContestLog(FDb, ContestHandleOf(CQWPXCW), '');
   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);

   (* WRITES WANTED: an immediate record and the close capture both stand
     down for a batch run, which is what tSilentExport says. *)
   tSilentExport := False;
end;

procedure TOperatorCQMemoryTests.StopStore;
begin
   tSilentExport := True;
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
   ScrubTestLog(FDb);
end;

procedure TOperatorCQMemoryTests.CaptureTo(const aFileName: string);
var
   db: TLogDatabase;
   repo: TLogRepository;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aFileName);
      repo := TLogRepository.Create(db);
      try
         CaptureMessageMemories(repo);
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
end;

function TOperatorCQMemoryTests.RestoreFrom(const aFileName: string): integer;
var
   db: TLogDatabase;
   repo: TLogRepository;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aFileName);
      repo := TLogRepository.Create(db);
      try
         Result := RestoreEditedMessageMemories(repo);
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
end;

function TOperatorCQMemoryTests.ReadMessageRow(const aFileName, aKind, aMode,
                                               aKeyId: string;
                                               out aText, aCaption: string;
                                               out aEdited: integer): boolean;
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   aText := '';
   aCaption := '';
   aEdited := -1;
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aFileName);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT text, IFNULL(caption, ''''), edited FROM message ' +
                       'WHERE kind = :kind AND mode = :mode AND key_id = :key_id';
         q.ParamByName('kind').AsString := aKind;
         q.ParamByName('mode').AsString := aMode;
         q.ParamByName('key_id').AsString := aKeyId;
         q.Open;
         Result := not q.EOF;
         if Result then
            begin
            aText := q.Fields[0].AsString;
            aCaption := q.Fields[1].AsString;
            aEdited := q.Fields[2].AsInteger;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;
end;

(* ---------------------------------------------- R2: durable when accepted *)

(* OK IN THE ALT-P EDITOR COMMITS THE EDIT -- R2 (2026-10-23). D7 wrote it to
   the .cfg the moment OK was pressed; Q113 kept it only at a clean close. The
   edit goes through ApplyAcceptedMessageEdit, which is what OK runs; a
   SECOND CONNECTION then reads the row while the program still holds the
   log open, and again after a close that captures NOTHING -- which is what a
   crash leaves. *)
procedure TOperatorCQMemoryTests.Test_R2_AnAcceptedEditIsCommittedWhenOKIsPressed;
var
   text, caption: string;
   edited: integer;
begin
   BeginTest('R2: an accepted memory edit is committed to the log when OK is pressed');
   SaveProgramMemories;
   StartStore('r2');
   try
      CheckTrue(LogStoreEnsureOpen, 'the store opens the database-only contest');
      if not LogStoreIsUsable then
         begin
         Exit;
         end;
      SetUpContest(CQWPXCW);

      CheckTrue(ApplyAcceptedMessageEdit('CQ CW MEMORY F3', 'R2 CQ TEXT', True, 'R2CAP'),
                'OK on a CQ memory reports it committed');
      CheckTrue(ApplyAcceptedMessageEdit('EX SSB MEMORY ALTF5', 'R2 EX TEXT', True, 'R2EXCAP'),
                'and on a Phone exchange memory under an Alt key');

      (* A SECOND CONNECTION, with the program's still open. *)
      CheckTrue(ReadMessageRow(FDb, 'CQ', 'CW', 'F3', text, caption, edited),
                'the CQ row is in the file');
      CheckEquals('R2 CQ TEXT', text, 'with its text');
      CheckEquals('R2CAP', caption, 'its caption, in the same row');
      CheckEquals(1, edited, 'and flagged edited');
      CheckTrue(ReadMessageRow(FDb, 'EX', 'PHONE', 'AltF5', text, caption, edited),
                'the EX row is in the file');
      CheckEquals('R2 EX TEXT', text, 'with its text');
      CheckEquals('R2EXCAP', caption, 'its caption');
      CheckEquals(1, edited, 'and flagged edited');

      (* A CRASH: the store goes away and NO close capture runs. *)
      tSilentExport := True;
      LogStoreClose;
      CheckTrue(ReadMessageRow(FDb, 'CQ', 'CW', 'F3', text, caption, edited),
                'after a close with no capture the row is still there');
      CheckEquals('R2 CQ TEXT', text, 'text');
      CheckEquals('R2CAP', caption, 'caption');
      CheckEquals(1, edited, 'edited');
   finally
      StopStore;
      RestoreProgramMemories;
   end;
end;

(* A COMMIT THAT FAILS IS NOT REPORTED AS SAVED -- Codex follow-up A
   (2026-10-23). The result was set before the commit, so a failed commit
   still answered True.

   THE FAILURE IS THE COMMIT ITSELF, not the write: a trigger on message
   inserts a row breaking a DEFERRED foreign key, which SQLite checks only at
   COMMIT. So the row is written inside the transaction and the commit is
   what refuses it. The key already holds a committed edit, so "no half
   pair" is checkable: the file must still hold the OLD text AND the OLD
   caption. The store's own policy must still fire -- the notice, once, and
   the store standing down -- and the edit stays in force for the session,
   which is exactly what False distinguishes from saved. *)
procedure TOperatorCQMemoryTests.Test_R2_ACommitThatFailsIsNotReportedSaved;
var
   db: TLogDatabase;
   text, caption: string;
   edited: integer;
begin
   BeginTest('R2: an accepted edit whose commit fails is reported NOT saved, and the file keeps the old row');
   SaveProgramMemories;
   StartStore('r2fail');
   try
      db := TLogDatabase.Create;
      try
         db.Open(FDb);
         db.Connection.ExecuteDirect(
            'INSERT INTO message (kind, mode, key_id, text, caption, edited) VALUES ' +
            '(''CQ'', ''CW'', ''F11'', ''OLD TEXT'', ''OLDCAP'', 1)');
         db.Connection.ExecuteDirect('CREATE TABLE commit_trap_parent (id INTEGER PRIMARY KEY)');
         db.Connection.ExecuteDirect(
            'CREATE TABLE commit_trap (parent_id INTEGER REFERENCES ' +
            'commit_trap_parent(id) DEFERRABLE INITIALLY DEFERRED)');
         db.Connection.ExecuteDirect(
            'CREATE TRIGGER commit_trap_on_insert AFTER INSERT ON message ' +
            'BEGIN INSERT INTO commit_trap (parent_id) VALUES (-1); END');
         db.Connection.ExecuteDirect(
            'CREATE TRIGGER commit_trap_on_update AFTER UPDATE ON message ' +
            'BEGIN INSERT INTO commit_trap (parent_id) VALUES (-1); END');
         db.Transaction.Commit;
      finally
         db.Free;
      end;

      GNotices := 0;
      GLastNotice := '';
      LogStoreFailureNotice := @TakeTheNotice;
      CheckTrue(LogStoreEnsureOpen, 'the store opens the log');

      CheckFalse(ApplyAcceptedMessageEdit('CQ CW MEMORY F11', 'NEW TEXT', True, 'NEWCAP'),
                 'a commit that fails is reported as NOT saved');
      CheckEquals(1, GNotices, 'the operator is told, once');
      CheckTrue(Pos('NOT BEING SAVED', GLastNotice) > 0, 'with the store''s own notice');
      CheckFalse(LogStoreIsUsable, 'and the store stands down, as for every failed write');
      CheckEquals('NEW TEXT', string(GetCQMemoryString(CW, F11)),
                  'the edit is in force for this session only');

      CheckTrue(ReadMessageRow(FDb, 'CQ', 'CW', 'F11', text, caption, edited),
                'the file still holds the key''s row');
      CheckEquals('OLD TEXT', text, 'its OLD text');
      CheckEquals('OLDCAP', caption, 'and its OLD caption -- no half-written pair');
      CheckEquals(1, edited, 'still flagged as the earlier edit');
   finally
      LogStoreFailureNotice := nil;
      LogStoreForgetFailureForTests;
      StopStore;
      RestoreProgramMemories;
   end;
end;

(* ------------------------------------- R3: the production open, in order *)

(* AN EDIT SURVIVES THE PROGRAM'S OWN REOPEN -- R3 (2026-10-23). A
   database-only contest is opened, edited, closed and reopened entirely
   through production routines: LogStoreApplyContestConfigWith (the body of
   LogStoreApplyContestConfig) sets the log's contest up and restores the
   edits, the edit is what OK runs, the close is LogStoreClose's capture, and
   the last default writer at startup -- UpdateSAndPF1Caption -- runs after.
   Only the contest set-up is the test's: FoundContest's effect on the
   memories and nothing else (SetUpTheLogsContest).

   WHAT IT CATCHES: the restore deleted from the replay, or moved before the
   set-up (the set-up then forgets the latch and writes its defaults), or a
   database-only contest that never reaches the set-up. *)
procedure TOperatorCQMemoryTests.Test_R3_AnEditSurvivesTheProductionReopen;
var
   contestNow: string;
   exF1Text: string;
begin
   BeginTest('R3: an edited memory survives the production close and reopen, after every default writer');
   SaveProgramMemories;
   StartStore('r3');
   try
      contestNow := CFGCommandValueAsString('CONTEST');
      CheckTrue((contestNow = '') or (contestNow = ContestId(NoContest)),
                'precondition: no contest is in force, so the open sets up the ' +
                'log''s own (found "' + contestNow + '")');
      ForgetMemoryStatementsOfOtherContests(NoContest);

      (* THE SESSION THAT EDITS. *)
      GSetUpCalls := 0;
      LogStoreApplyContestConfigWith(@SetUpTheLogsContest);
      CheckEquals(1, GSetUpCalls, 'the open set the contest up from the log');
      CheckEquals(ContestId(ContestHandleOf(CQWPXCW)), GSetUpContestId,
                  'and it was the log''s contest');
      CheckTrue(LogStoreIsUsable, 'the store is open');
      if not LogStoreIsUsable then
         begin
         Exit;
         end;
      CheckEquals('5NN #', string(GetCQMemoryString(CW, F3)), 'the set-up wrote its default');

      CheckTrue(ApplyAcceptedMessageEdit('CQ CW MEMORY F3', 'LIFE CQ', True, 'LIFECAP'),
                'CQ F3 edited');
      (* A CAPTION EDIT: the text is accepted as it stands. *)
      exF1Text := string(GetEXMemoryString(CW, F1));
      CheckTrue(ApplyAcceptedMessageEdit('EX CW MEMORY F1', ShortString(AnsiString(exF1Text)),
                                         True, 'MYF1'),
                'EX F1''s caption edited');

      (* THE PRODUCTION CLOSE, capture and all. *)
      LogStoreClose;

      (* THE NEXT RUN, before the log is read. *)
      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetCQMemoryString(CW, F3, 'LEFT BY START-UP');
      SetCQCaptionMemoryString(CW, F3, '');
      SetEXCaptionMemoryString(CW, F1, 'LEFT BY START-UP');

      GSetUpCalls := 0;
      LogStoreApplyContestConfigWith(@SetUpTheLogsContest);
      CheckEquals(1, GSetUpCalls, 'the reopen set the contest up again');
      (* STARTUP'S LAST DEFAULT WRITER, after the log is applied
        (uProgramMain): the S&P F1 caption. *)
      UpdateSAndPF1Caption;

      CheckEquals('LIFE CQ', string(GetCQMemoryString(CW, F3)),
                  'the CQ edit survived the set-up');
      CheckEquals('LIFECAP', string(CQCaptionMemory[CW, F3]), 'with its caption');
      CheckEquals('MYF1', string(EXCaptionMemory[CW, F1]),
                  'the caption edit survived the last default writer');
      CheckEquals(exF1Text, string(GetEXMemoryString(CW, F1)), 'its text as accepted');
      CheckTrue(CQMemoryIsOperatorStated(CW, F3), 'and the edit is latched again');
      CheckEquals('5NN', string(GetEXMemoryString(CW, F3)),
                  'an unedited key is the contest''s default');
   finally
      StopStore;
      RestoreProgramMemories;
   end;
end;

(* ------------------------------------------------- R3: focused cases *)

(* CW AND PHONE ARE TWO ROWS. Distinct text on one key comes back distinct; a
   CW-only edit does not reach the Phone key; and a DIG edit is the CW
   memory (the accessors fold Digital into CW), recorded under CW only. *)
procedure TOperatorCQMemoryTests.Test_R3_CWAndPhoneAreSeparateMemories;
var
   fn: string;
   text, caption: string;
   edited: integer;
begin
   BeginTest('R3: CW and Phone memories of one key are separate rows; DIG is CW');
   fn := TempLog('cwphone.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      SetUpContest(CQWPXCW);
      SetCQMemoryString(Phone, F4, '');
      SetCQMemoryString(Phone, F5, '');
      CheckTrue(TryApplyMessageCommand('CQ CW MEMORY F2', 'CW TWO'), 'CW F2');
      CheckTrue(TryApplyMessageCommand('CQ SSB MEMORY F2', 'PH TWO'), 'Phone F2');
      CheckTrue(TryApplyMessageCommand('CQ CW MEMORY F4', 'CW FOUR'), 'CW F4 only');
      CheckTrue(TryApplyMessageCommand('CQ DIG MEMORY F5', 'DIG FIVE'), 'DIG F5');
      CaptureTo(fn);

      CheckFalse(ReadMessageRow(fn, 'CQ', 'PHONE', 'F4', text, caption, edited),
                 'no Phone row for a key edited only in CW');
      CheckFalse(ReadMessageRow(fn, 'CQ', 'PHONE', 'F5', text, caption, edited),
                 'nor for a DIG edit');
      CheckTrue(ReadMessageRow(fn, 'CQ', 'CW', 'F5', text, caption, edited),
                'the DIG edit is the CW row');
      CheckEquals('DIG FIVE', text, 'holding its text');

      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetCQMemoryString(CW, F2, 'X');
      SetCQMemoryString(Phone, F2, 'X');
      SetCQMemoryString(CW, F4, 'X');
      SetCQMemoryString(Phone, F4, 'LEFT');
      SetCQMemoryString(CW, F5, 'X');
      SetUpContest(CQWPXCW);
      CheckEquals(4, RestoreFrom(fn), 'four edits restored');
      CheckEquals('CW TWO', string(GetCQMemoryString(CW, F2)), 'CW F2');
      CheckEquals('PH TWO', string(GetCQMemoryString(Phone, F2)), 'Phone F2, not the CW text');
      CheckEquals('CW FOUR', string(GetCQMemoryString(CW, F4)), 'CW F4');
      CheckEquals('LEFT', string(GetCQMemoryString(Phone, F4)),
                  'Phone F4 untouched: CW is never restored into Phone');
      CheckEquals('DIG FIVE', string(GetCQMemoryString(Digital, F5)), 'DIG F5, read as DIG');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* EVERY END OF EVERY KEY GROUP, BOTH BANKS, BOTH MODES -- F1/F12,
   ControlF1/ControlF12, AltF1/AltF12. The Ctrl and Alt codes are #124..#147,
   where a Char conversion through the code page lost them (MemoryKeyId).
   Each name is built by MessageMemoryCommand and must parse back to itself;
   text, caption and latch must come back through the log. *)
procedure TOperatorCQMemoryTests.Test_R3_EveryKeyRoundTripsInBothBanks;
const
   KEYS: array[0..5] of AnsiChar = (F1, F12, ControlF1, ControlF12, AltF1, AltF12);
   MODES: array[0..1] of ModeType = (CW, Phone);
var
   fn: string;
   b, m, k, n: integer;
   bank, parsedBank, isCaption: boolean;
   parsedMode: ModeType;
   parsedKey: AnsiChar;
   name: ShortString;
   tag: string;

   function TextOf(aBank, aMode: integer; aKey: AnsiChar): string;
   begin
      if aBank = 0 then
         begin
         Result := string(GetCQMemoryString(MODES[aMode], aKey));
         end
      else
         begin
         Result := string(GetEXMemoryString(MODES[aMode], aKey));
         end;
   end;

   function CaptionOf(aBank, aMode: integer; aKey: AnsiChar): string;
   begin
      if aBank = 0 then
         begin
         Result := string(CQCaptionMemory[MODES[aMode], aKey]);
         end
      else
         begin
         Result := string(EXCaptionMemory[MODES[aMode], aKey]);
         end;
   end;

   function LatchedOf(aBank, aMode: integer; aKey: AnsiChar): boolean;
   begin
      if aBank = 0 then
         begin
         Result := CQMemoryIsOperatorStated(MODES[aMode], aKey);
         end
      else
         begin
         Result := EXMemoryIsOperatorStated(MODES[aMode], aKey);
         end;
   end;

begin
   BeginTest('R3: F1/F12, Ctrl and Alt F1/F12 round-trip in both banks and modes');
   fn := TempLog('everykey.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      SetUpContest(CQWPXCW);
      n := 0;
      for b := 0 to 1 do
         begin
         bank := b = 0;
         for m := Low(MODES) to High(MODES) do
            begin
            for k := Low(KEYS) to High(KEYS) do
               begin
               name := MessageMemoryCommand(bank, MODES[m], KEYS[k]);
               tag := string(name);
               CheckTrue(ParseMessageMemoryCommand(name, parsedBank, parsedMode,
                                                   parsedKey, isCaption),
                         tag + ' parses');
               CheckTrue((parsedBank = bank) and (parsedMode = MODES[m]) and
                         (parsedKey = KEYS[k]) and (not isCaption),
                         tag + ' parses back to its own bank, mode and key');
               CheckTrue(TryApplyMessageCommand(name, ShortString(AnsiString('T' + IntToStr(n)))),
                         tag + ' applies');
               CheckTrue(TryApplyMessageCommand(ShortString(AnsiString(tag + ' CAPTION')),
                                                ShortString(AnsiString('C' + IntToStr(n)))),
                         tag + ' CAPTION applies');
               Inc(n);
               end;
            end;
         end;
      CaptureTo(fn);

      ForgetMemoryStatementsOfOtherContests(NoContest);
      for m := Low(MODES) to High(MODES) do
         begin
         for k := Low(KEYS) to High(KEYS) do
            begin
            SetCQMemoryString(MODES[m], KEYS[k], '');
            SetCQCaptionMemoryString(MODES[m], KEYS[k], '');
            SetEXMemoryString(MODES[m], KEYS[k], '');
            SetEXCaptionMemoryString(MODES[m], KEYS[k], '');
            end;
         end;
      SetUpContest(CQWPXCW);
      CheckEquals(n, RestoreFrom(fn), 'every edited key restored');

      n := 0;
      for b := 0 to 1 do
         begin
         for m := Low(MODES) to High(MODES) do
            begin
            for k := Low(KEYS) to High(KEYS) do
               begin
               tag := string(MessageMemoryCommand(b = 0, MODES[m], KEYS[k]));
               CheckEquals('T' + IntToStr(n), TextOf(b, m, KEYS[k]), tag + ': text');
               CheckEquals('C' + IntToStr(n), CaptionOf(b, m, KEYS[k]), tag + ': caption');
               CheckTrue(LatchedOf(b, m, KEYS[k]), tag + ': latched');
               Inc(n);
               end;
            end;
         end;
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* A CAPTION-ONLY EDIT. The key's text is whatever it was at close, and comes
   back with the caption, as one statement. *)
procedure TOperatorCQMemoryTests.Test_R3_ACaptionOnlyEditRoundTrips;
var
   fn: string;
begin
   BeginTest('R3: a caption-only edit comes back, with the text the key had');
   fn := TempLog('caption.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      SetUpContest(CQWPXCW);
      SetEXMemoryString(CW, F6, 'BEFORE');
      CheckTrue(TryApplyMessageCommand('EX CW MEMORY F6 CAPTION', 'CAPONLY'),
                'the caption alone is edited');
      CaptureTo(fn);

      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetEXMemoryString(CW, F6, 'X');
      SetEXCaptionMemoryString(CW, F6, '');
      SetUpContest(CQWPXCW);
      CheckEquals(1, RestoreFrom(fn), 'one key restored');
      CheckEquals('CAPONLY', string(EXCaptionMemory[CW, F6]), 'its caption');
      CheckEquals('BEFORE', string(GetEXMemoryString(CW, F6)), 'and the text it had');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* CAPTURED TWICE: a key edited, captured, then no longer edited (another
   contest set up) and emptied, captured again -- no edited row may remain
   to be restored. The close capture rewrites the table whole. *)
procedure TOperatorCQMemoryTests.Test_R3_AKeyNoLongerEditedLeavesNoEditedRow;
var
   fn: string;
   text, caption: string;
   edited: integer;
begin
   BeginTest('R3: a second capture leaves no edited row for a key no longer edited');
   fn := TempLog('twice.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      SetUpContest(CQWPXCW);
      CheckTrue(TryApplyMessageCommand('CQ CW MEMORY F9', 'TEMP'), 'CQ F9 edited');
      CaptureTo(fn);
      CheckTrue(ReadMessageRow(fn, 'CQ', 'CW', 'F9', text, caption, edited),
                'the first capture holds the edit');
      CheckEquals(1, edited, 'flagged');

      ForgetMemoryStatementsOfOtherContests(ContestHandleOf(ARRLDXCW));
      SetCQMemoryString(CW, F9, '');
      CaptureTo(fn);
      CheckFalse(ReadMessageRow(fn, 'CQ', 'CW', 'F9', text, caption, edited),
                 'the second capture leaves no row for it');

      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetCQMemoryString(CW, F9, 'LEFT');
      CheckEquals(0, RestoreFrom(fn), 'and nothing is restored');
      CheckEquals('LEFT', string(GetCQMemoryString(CW, F9)), 'the key is untouched');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* A ROW THIS BUILD CANNOT NAME -- an unknown kind, mode or key -- is skipped,
   and the rows after it still restore. The bad rows sort FIRST
   (ORDER BY kind, mode, key_id), so a skip that stopped the walk would
   restore nothing. *)
procedure TOperatorCQMemoryTests.Test_R3_AnUnknownRowIsSkippedAndTheRestRestore;
var
   fn: string;
   db: TLogDatabase;
begin
   BeginTest('R3: an unknown kind, mode or key row is skipped and the valid rows restore');
   fn := TempLog('unknown.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         db.Connection.ExecuteDirect(
            'INSERT INTO message (kind, mode, key_id, text, caption, edited) VALUES ' +
            '(''AA'', ''CW'', ''F1'', ''BAD KIND'', '''', 1), ' +
            '(''CQ'', ''BOGUS'', ''F1'', ''BAD MODE'', '''', 1), ' +
            '(''CQ'', ''CW'', ''AAA'', ''BAD KEY'', '''', 1), ' +
            '(''CQ'', ''CW'', ''F7'', ''GOOD'', ''GCAP'', 1)');
         db.Transaction.Commit;
      finally
         db.Free;
      end;

      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetCQMemoryString(CW, F7, 'X');
      SetUpContest(CQWPXCW);
      CheckEquals(1, RestoreFrom(fn), 'only the valid row is restored');
      CheckEquals('GOOD', string(GetCQMemoryString(CW, F7)), 'its text');
      CheckEquals('GCAP', string(CQCaptionMemory[CW, F7]), 'its caption');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

(* RESTORE, CAPTURE, REOPEN: a restored edit is latched, so the next capture
   flags it edited again and the next open restores it again. *)
procedure TOperatorCQMemoryTests.Test_R3_ARestoredEditIsCapturedAsAnEditAgain;
var
   fn: string;
   db: TLogDatabase;
   text, caption: string;
   edited: integer;
begin
   BeginTest('R3: a restored edit is captured as an edit again');
   fn := TempLog('again.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         db.Connection.ExecuteDirect(
            'INSERT INTO message (kind, mode, key_id, text, caption, edited) VALUES ' +
            '(''EX'', ''CW'', ''F8'', ''FLAGGED'', ''FCAP'', 1)');
         db.Transaction.Commit;
      finally
         db.Free;
      end;

      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetUpContest(CQWPXCW);
      CheckEquals(1, RestoreFrom(fn), 'restored');
      CaptureTo(fn);
      CheckTrue(ReadMessageRow(fn, 'EX', 'CW', 'F8', text, caption, edited),
                'the capture after a restore keeps the row');
      CheckEquals('FLAGGED', text, 'its text');
      CheckEquals(1, edited, 'and flags it edited');

      ForgetMemoryStatementsOfOtherContests(NoContest);
      SetEXMemoryString(CW, F8, 'X');
      SetUpContest(CQWPXCW);
      CheckEquals(1, RestoreFrom(fn), 'so the next open restores it again');
      CheckEquals('FLAGGED', string(GetEXMemoryString(CW, F8)), 'with its text');
   finally
      RestoreProgramMemories;
      ScrubTestLog(fn);
   end;
end;

procedure TOperatorCQMemoryTests.RunAllTests;
begin
   Test_AStatedCQMemoryIsNotADefault;
   Test_ReSelectingTheContestKeepsAnEditedCQMemory;
   Test_Q113_AnEditedMemorySurvivesARestart;
   Test_Q113_AnUneditedMemoryIsTheCurrentDefault;
   Test_Q113_AnOldSchemaLogRestoresNothing;
   Test_R2_AnAcceptedEditIsCommittedWhenOKIsPressed;
   Test_R2_ACommitThatFailsIsNotReportedSaved;
   Test_R3_AnEditSurvivesTheProductionReopen;
   Test_R3_CWAndPhoneAreSeparateMemories;
   Test_R3_EveryKeyRoundTripsInBothBanks;
   Test_R3_ACaptionOnlyEditRoundTrips;
   Test_R3_AKeyNoLongerEditedLeavesNoEditedRow;
   Test_R3_AnUnknownRowIsSkippedAndTheRestRestore;
   Test_R3_ARestoredEditIsCapturedAsAnEditAgain;
end;

end.
