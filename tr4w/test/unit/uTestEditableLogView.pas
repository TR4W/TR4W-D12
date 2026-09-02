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

(* THE EDITABLE LOG'S ROW-TO-RECORD MAPPING.

  WORKED EXAMPLES WITH THE NUMBERS SPELLED OUT, because this is arithmetic that
  was wrong for years in a way no test could see -- the corpus never opens the
  UI, and the defect needs a log LONGER than the window to reach.

  THE CASE THAT WAS BROKEN IS FIRST AND IS NAMED. Ten records in a five-row
  window: the window must show 5..9, and the old code showed 4..9.

  THE ROUND TRIP IS THE REAL ASSERTION. Whatever the first record is, row 0 must
  BE that record and the last row must be the newest -- because LOGSUBS2 deletes
  row 0 and appends at rowCount-1 on every logged QSO, and its trim fires only
  on an exact row count. *)
unit uTestEditableLogView;

{$I tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TEditableLogViewTests = class(TTestCase)
   public
      procedure RunAllTests; override;

      procedure TestTheCaseThatWasBroken;
      procedure TestExactlyAsManyRecordsAsRows;
      procedure TestFewerRecordsThanRows;
      procedure TestOneMoreRecordThanRows;
      procedure TestEmptyLog;
      procedure TestRowsOutsideTheWindow;
      procedure TestBlankRowsOfAShortLogAreNotRecords;
      procedure TestRoundTripHoldsAtEverySize;
      procedure TestDegenerateRowCount;
   end;

implementation

uses
   SysUtils, uEditableLogView;

(* TEN RECORDS, FIVE ROWS -- the exact shape of the defect.

  The window shows the LAST five, which are records 5,6,7,8,9. The old code
  computed (Size - 1) - rows = 4 and showed SIX records, 4..9. Two things
  followed: a double click opened the record above the one clicked, because
  EditableLogWindowDblClick correctly expected 5..9; and the extra row left the
  global tLogIndex one past LinesInEditableLog, so LOGSUBS2's equality-tested
  trim never fired again and the list grew for the rest of the session. *)
procedure TEditableLogViewTests.TestTheCaseThatWasBroken;
begin
   BeginTest('TestTheCaseThatWasBroken');
   CheckEquals(5, EditableLogFirstRecord(10, 5),
               'ten records in five rows start at 5, not 4');

   CheckEquals(5, EditableLogRowToRecord(10, 5, 0), 'row 0 is the oldest shown');
   CheckEquals(6, EditableLogRowToRecord(10, 5, 1), 'row 1');
   CheckEquals(7, EditableLogRowToRecord(10, 5, 2), 'row 2');
   CheckEquals(8, EditableLogRowToRecord(10, 5, 3), 'row 3');
   CheckEquals(9, EditableLogRowToRecord(10, 5, 4),
               'the last row is the NEWEST QSO -- what Ctrl-W means by it');
end;

procedure TEditableLogViewTests.TestExactlyAsManyRecordsAsRows;
begin
   BeginTest('TestExactlyAsManyRecordsAsRows');
   CheckEquals(0, EditableLogFirstRecord(5, 5),
               'five records fill five rows exactly, from the start');
   CheckEquals(0, EditableLogRowToRecord(5, 5, 0), 'row 0 is record 0');
   CheckEquals(4, EditableLogRowToRecord(5, 5, 4), 'row 4 is record 4');
end;

procedure TEditableLogViewTests.TestFewerRecordsThanRows;
begin
   BeginTest('TestFewerRecordsThanRows');
   CheckEquals(0, EditableLogFirstRecord(3, 5), 'a short log starts at 0');
   CheckEquals(0, EditableLogRowToRecord(3, 5, 0), 'row 0');
   CheckEquals(2, EditableLogRowToRecord(3, 5, 2), 'row 2 is the last QSO');
end;

(* THE BOUNDARY, and the old code was wrong here too but differently: six
  records gave (6-1) > 5 = False, so it started at 0 and showed all six. *)
procedure TEditableLogViewTests.TestOneMoreRecordThanRows;
begin
   BeginTest('TestOneMoreRecordThanRows');
   CheckEquals(1, EditableLogFirstRecord(6, 5),
               'six records in five rows drop the oldest');
   CheckEquals(1, EditableLogRowToRecord(6, 5, 0), 'row 0 is record 1');
   CheckEquals(5, EditableLogRowToRecord(6, 5, 4), 'row 4 is record 5');
end;

procedure TEditableLogViewTests.TestEmptyLog;
begin
   BeginTest('TestEmptyLog');
   CheckEquals(0, EditableLogFirstRecord(0, 5), 'nothing logged yet');
   CheckEquals(-1, EditableLogRowToRecord(0, 5, 0),
               'no row of an empty log is a record');
end;

procedure TEditableLogViewTests.TestRowsOutsideTheWindow;
begin
   BeginTest('TestRowsOutsideTheWindow');
   CheckEquals(-1, EditableLogRowToRecord(10, 5, -1), 'negative row');
   CheckEquals(-1, EditableLogRowToRecord(10, 5, 5),
               'row 5 does not exist in a five-row window');
   CheckEquals(-1, EditableLogRowToRecord(10, 5, 99), 'far past the end');
end;

(* -1 RATHER THAN A PLAUSIBLE INDEX. With three QSOs, rows 3 and 4 are blank.
  Answering 3 or 4 would let a double click open a record that is not on
  screen; the caller checks for -1 and does nothing. *)
procedure TEditableLogViewTests.TestBlankRowsOfAShortLogAreNotRecords;
begin
   BeginTest('TestBlankRowsOfAShortLogAreNotRecords');
   CheckEquals(-1, EditableLogRowToRecord(3, 5, 3), 'first blank row');
   CheckEquals(-1, EditableLogRowToRecord(3, 5, 4), 'last blank row');
end;

(* THE INVARIANT LOGSUBS2 DEPENDS ON, checked across every size that matters
  rather than at the two the author happened to think of.

  For any log at least as long as the window: row 0 must be the first record
  shown, the last row must be the newest record, and the number of rows filled
  must be EXACTLY the row count -- that last one is what the trim tests for
  equality. *)
procedure TEditableLogViewTests.TestRoundTripHoldsAtEverySize;
var
   rows, count, row, filled: integer;
   rec: Int64;
begin
   BeginTest('TestRoundTripHoldsAtEverySize');

   for rows := 1 to 8 do
      begin
      for count := 0 to 40 do
         begin
         filled := 0;
         for row := 0 to rows - 1 do
            begin
            rec := EditableLogRowToRecord(count, rows, row);
            if rec >= 0 then
               begin
               Inc(filled);
               end;
            end;

         if count >= rows then
            begin
            CheckEquals(rows, filled,
                        Format('rows=%d count=%d: every row is a record',
                               [rows, count]));
            CheckEquals(EditableLogFirstRecord(count, rows),
                        EditableLogRowToRecord(count, rows, 0),
                        Format('rows=%d count=%d: row 0 IS the first record',
                               [rows, count]));
            CheckEquals(count - 1, EditableLogRowToRecord(count, rows, rows - 1),
                        Format('rows=%d count=%d: the last row is the newest',
                               [rows, count]));
            end
         else
            begin
            CheckEquals(count, filled,
                        Format('rows=%d count=%d: a short log fills only what it has',
                               [rows, count]));
            end;
         end;
      end;
end;

(* A row count from configuration could be zero or negative. Nothing is shown,
  and no row is a record -- rather than a negative first record, which would
  seek before the start of the log. *)
procedure TEditableLogViewTests.TestDegenerateRowCount;
begin
   BeginTest('TestDegenerateRowCount');
   CheckEquals(0,  EditableLogFirstRecord(10, 0),  'zero rows show nothing');
   CheckEquals(0,  EditableLogFirstRecord(10, -3), 'negative rows show nothing');
   CheckEquals(-1, EditableLogRowToRecord(10, 0, 0),  'no row exists');
   CheckEquals(-1, EditableLogRowToRecord(10, -3, 0), 'no row exists');
end;

procedure TEditableLogViewTests.RunAllTests;
begin
   TestTheCaseThatWasBroken;
   TestExactlyAsManyRecordsAsRows;
   TestFewerRecordsThanRows;
   TestOneMoreRecordThanRows;
   TestEmptyLog;
   TestRowsOutsideTheWindow;
   TestBlankRowsOfAShortLogAreNotRecords;
   TestRoundTripHoldsAtEverySize;
   TestDegenerateRowCount;
end;

end.
