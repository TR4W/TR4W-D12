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
      procedure Test_AStatedCQMemoryIsNotADefault;
      procedure Test_ReSelectingTheContestKeepsAnEditedCQMemory;
      procedure Test_Q113_AnEditedMemorySurvivesARestart;
      procedure Test_Q113_AnUneditedMemoryIsTheCurrentDefault;
      procedure Test_Q113_AnOldSchemaLogRestoresNothing;
      (* The program's memories, captions and messages, kept and put back. *)
      procedure SaveProgramMemories;
      procedure RestoreProgramMemories;
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
   Tree,
   uSettingsModel,
   FCONTEST,
   uContestRegistry,
   sqldb,
   uLogSchema,
   uLogDatabase,
   uLogRepository,
   uLogStore,            (* CaptureMessageMemories / RestoreEditedMessageMemories *)
   uTestLatestContest;   (* MakeTestContestLog / ScrubTestLog -- one way to make a test log *)

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
   CheckEquals(4, LOG_SCHEMA_VERSION, 'the schema that carries message.edited');
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
   q: TSQLQuery;

   function MessageHasEditedColumn: boolean;
   begin
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT name FROM pragma_table_info(''message'') ' +
                       'WHERE name = ''edited''';
         q.Open;
         Result := not q.EOF;
         q.Close;
      finally
         q.Free;
      end;
   end;

begin
   BeginTest('Test_Q113_AnOldSchemaLogRestoresNothing');
   fn := TempLog('schema3.db');
   SaveProgramMemories;
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');

      (* BACK TO SCHEMA 3, on disk: the column dropped, a row written the way
        a schema-3 build wrote one, user_version 3. *)
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         db.Connection.ExecuteDirect('ALTER TABLE message DROP COLUMN edited');
         db.Connection.ExecuteDirect(
            'INSERT INTO message (kind, mode, key_id, text, caption) VALUES ' +
            '(''CQ'', ''CW'', ''F3'', ''WRITTEN BY SCHEMA 3'', '''')');
         db.Transaction.Commit;
         db.Connection.ExecuteDirect('PRAGMA user_version = 3');
         db.Transaction.Commit;
      finally
         db.Free;
      end;

      db := TLogDatabase.Create;
      try
         db.OpenReadOnly(fn);
         CheckEquals(3, db.SchemaVersion, 'the fixture really is schema 3');
         CheckFalse(MessageHasEditedColumn, 'with no edited column');
      finally
         db.Free;
      end;

      Restart;
      db := TLogDatabase.Create;
      try
         db.Open(fn);
         CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'it opens and migrates');
         CheckTrue(MessageHasEditedColumn, 'gaining the edited column');
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

procedure TOperatorCQMemoryTests.RunAllTests;
begin
   Test_AStatedCQMemoryIsNotADefault;
   Test_ReSelectingTheContestKeepsAnEditedCQMemory;
   Test_Q113_AnEditedMemorySurvivesARestart;
   Test_Q113_AnUneditedMemoryIsTheCurrentDefault;
   Test_Q113_AnOldSchemaLogRestoresNothing;
end;

end.
