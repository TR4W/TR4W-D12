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
  program's memories and messages are restored afterwards. *)
unit uTestOperatorCQMemory;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TOperatorCQMemoryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_AStatedCQMemoryIsNotADefault;
      procedure Test_ReSelectingTheContestKeepsAnEditedCQMemory;
   end;

implementation

uses
   SysUtils,
   VC,
   Tree,
   uSettingsModel,
   LogCW,
   FCONTEST,
   uContestRegistry;

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
      ForgetCQMemoryStatementsOfOtherContests(ContestHandleOf(CQWWCW));
      ForgetCQMemoryStatementsOfOtherContests(ContestHandleOf(ARRLDXCW));
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
      ForgetCQMemoryStatementsOfOtherContests(ContestHandleOf(ARRLDXCW));
      CheckTrue(CQMemoryIsOperatorStated(CW, F3), 'the same contest keeps the statement');
      ForgetCQMemoryStatementsOfOtherContests(ContestHandleOf(CQWWCW));
      CheckFalse(CQMemoryIsOperatorStated(CW, F3), 'another contest forgets it');
      SetContestDefaultCQMemoryString(CW, F3, 'A DEFAULT');
      CheckEquals('A DEFAULT', string(GetCQMemoryString(CW, F3)), 'and writes its own default');

      (* AN EXCHANGE MEMORY IS NOT A CQ MEMORY: no latch. *)
      CheckTrue(TryApplyMessageCommand('EX CW MEMORY F4', 'EX EDIT'), 'an exchange memory edit applies');
      CheckFalse(CQMemoryIsOperatorStated(CW, F4), 'and latches no CQ memory');
   finally
      SetCQMemoryString(CW, F3, ShortString(savedF3));
      SetCQMemoryString(CW, F4, ShortString(savedF4));
      ForgetCQMemoryStatementsOfOtherContests(NoContest);
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
      ForgetCQMemoryStatementsOfOtherContests(ContestHandleOf(aContest));
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
      ForgetCQMemoryStatementsOfOtherContests(NoContest);
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

procedure TOperatorCQMemoryTests.RunAllTests;
begin
   Test_AStatedCQMemoryIsNotADefault;
   Test_ReSelectingTheContestKeepsAnEditedCQMemory;
end;

end.
