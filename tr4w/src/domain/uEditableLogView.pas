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

(* WHICH LOG RECORDS DOES THE EDITABLE LOG SHOW, AND WHICH ROW IS WHICH?

  ONE DEFINITION, BECAUSE THERE WERE TWO AND THEY DRIFTED. The editable log
  window shows the tail of the log, and two places computed that independently:

    MainUnit.LoadinLog                which record to start displaying at
    MainUnit.EditableLogWindowDblClick  which record a clicked row is

  They disagreed by one, and the disagreement produced two defects of very
  different sizes -- a double click opening the QSO above the one clicked, and
  the editable log growing without bound for the rest of the session. Neither is
  visible to any automated gate: the corpus never opens the UI.

  THE MODEL, stated once so nothing has to re-derive it:

    - The log holds aRecordCount records, indexed from 0.
    - The window shows the LAST aRowCount of them, or all of them when the log
      is shorter.
    - Row 0 is the OLDEST shown, row (rows-1) the NEWEST.

  LOGSUBS2 DEPENDS ON THIS LITERALLY. When a QSO is logged it deletes row 0 and
  re-adds at aRowCount-1, but only when the row count is EXACTLY aRowCount
  (LOGSUBS2.PAS:2541) -- an equality test, so a load that produces one row too
  many disables the trim permanently rather than degrading it.

  A LEAF, AND DOMAIN-PURE: integers in, integers out. No widget, no globals, no
  Windows unit -- which is what lets the arithmetic be tested exhaustively
  without starting TR4W, and what Lint-DomainPurity enforces for this
  directory. *)
unit uEditableLogView;

{$I tr4w.inc}

interface

(* THE FIRST RECORD THE WINDOW SHOWS.

  aRowCount is LinesInEditableLog at every call site; it is a parameter so this
  can be tested at sizes nobody runs with, and so the reasoning does not depend
  on a global. *)
function EditableLogFirstRecord(const aRecordCount: Int64;
                                const aRowCount: integer): Int64;

(* THE RECORD A GIVEN ROW IS SHOWING, or -1 when that row is not filled.

  -1 RATHER THAN A GUESS. With fewer records than rows, the lower rows are
  genuinely empty, and a caller that opens record -1 fails loudly where one
  handed a plausible index would open the wrong QSO silently. *)
function EditableLogRowToRecord(const aRecordCount: Int64;
                                const aRowCount: integer;
                                const aRow: integer): Int64;

implementation

function EditableLogFirstRecord(const aRecordCount: Int64;
                                const aRowCount: integer): Int64;
begin
   (* A NON-POSITIVE ROW COUNT SHOWS NOTHING, and starting at 0 is the honest
     answer: there is no window to fill. Guarded because aRowCount reaches this
     from configuration. *)
   if aRowCount <= 0 then
      begin
      Result := 0;
      Exit;
      end;

   if aRecordCount > aRowCount then
      begin
      (* THE COUNT MINUS THE ROWS, not the last INDEX minus the rows. That
        distinction is the whole bug this unit was written for: records are
        0-based, so the last aRowCount of aRecordCount records begin at
        aRecordCount - aRowCount. Subtracting from aRecordCount - 1 yields one
        record too many. *)
      Result := aRecordCount - aRowCount;
      end
   else
      begin
      Result := 0;
      end;
end;

function EditableLogRowToRecord(const aRecordCount: Int64;
                                const aRowCount: integer;
                                const aRow: integer): Int64;
begin
   Result := -1;

   if (aRowCount <= 0) or (aRow < 0) or (aRow >= aRowCount) then
      begin
      Exit;
      end;

   (* THE SAME FIRST RECORD THE LOADER USED -- that is the point of the unit.
     The two cannot drift because there is only one expression. *)
   Result := EditableLogFirstRecord(aRecordCount, aRowCount) + aRow;

   if Result >= aRecordCount then
      begin
      (* A row past the end of a short log: displayed as blank, and not a
        record. *)
      Result := -1;
      end;
end;

end.
