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
unit uVerificationForm;
{$I ..\..\tr4w.inc}

(*
  THE RESULTS OF THE VERIFICATION CHECKS, ON SCREEN.

  Tools -> Run Verification Checks. The checks themselves are in
  uVerificationChecks and know nothing about this form; this renders what they
  return and nothing else.

  THE GRID HOLDS THE DATA. Two columns, the check and its verdict, with the
  explanation for the selected row in the memo below -- so a passing run is one
  glance and a failure is one click. Nothing is kept in a parallel array beside
  the grid: the grid IS the model here, which is what the LCL expects and what
  keeps a count and a display from disagreeing.

  IT RUNS ON THE MAIN THREAD, AND SAYS SO WHILE IT DOES. integrity_check walks
  every page of the contest log, which is seconds on a large one -- short enough
  that a thread and its marshalling would cost more than it buys, and long
  enough that the window must not simply freeze in silence. The status line and
  an hourglass carry that, and the buttons are disabled so a second run cannot
  be started on top of the first.
*)

interface

uses
  Forms, Controls, StdCtrls, Grids, Classes;

type
  TfrmVerification = class(TForm)
    lblStatus: TLabel;
    grdResults: TStringGrid;
    memDetail: TMemo;
    btnRun: TButton;
    btnClose: TButton;
    procedure btnRunClick(Sender: TObject);
    procedure grdResultsSelection(Sender: TObject; aCol, aRow: integer);
  private
    procedure PrepareGrid;
    procedure RunChecks;
    procedure ShowDetailForRow(aRow: integer);
  end;

(* Open the window and run the checks once, so the operator who chose the menu
  item gets the answer without a second click.  Modal: it is a question with an
  answer, not a tool window to leave open. *)
procedure ShowVerificationChecks;

implementation

{$R *.lfm}

uses
  SysUtils,
  uAppStrings,
  uVerificationChecks,
  utils_text,          (* LclText -- the grid holds UTF-8 bytes *)
  uLCLFormHelpers;   (* OwnFormByMainWindow *)

const
   COL_CHECK  = 0;
   COL_RESULT = 1;
   (* Hidden -- zero width. See PrepareGrid. *)
   COL_DETAIL = 2;


procedure ShowVerificationChecks;
var
  f: TfrmVerification;
begin
   f := TfrmVerification.Create(nil);
   try
      OwnFormByMainWindow(f);

      (* EVERY CAPTION IS ASSIGNED HERE, and the .lfm text is a designer
        placeholder. A designed form carries its caption in the .lfm, and every
        conversion that re-typed the English there lost the translation that
        already existed -- see CLAUDE.md. These strings are new, so they live in
        uAppStrings where the harvest can find them. *)
      f.Caption          := SVerifyTitle;
      f.btnRun.Caption   := SVerifyRun;
      f.btnClose.Caption := SVerifyClose;

      f.PrepareGrid;
      f.RunChecks;
      f.ShowModal;
   finally
      f.Free;
   end;
end;


procedure TfrmVerification.PrepareGrid;
begin
   (* THREE COLUMNS, THE THIRD HIDDEN. It carries each row's explanation, so
     selecting a row reads the detail OUT OF THE ROW rather than out of an
     array kept beside the grid -- which is the shape that lets a count and a
     display disagree. *)
   grdResults.ColCount := 3;
   grdResults.FixedRows := 1;
   grdResults.RowCount := 1;
   grdResults.Cells[COL_CHECK, 0]  := SVerifyColumnCheck;
   grdResults.Cells[COL_RESULT, 0] := SVerifyColumnResult;
   grdResults.ColWidths[COL_CHECK] := 420;
   grdResults.ColWidths[COL_RESULT] := 120;
   grdResults.ColWidths[COL_DETAIL] := 0;
end;


procedure TfrmVerification.RunChecks;
var
  results: TVerificationResults;
  i: integer;
  failures: integer;
begin
   btnRun.Enabled := False;
   btnClose.Enabled := False;
   memDetail.Clear;
   grdResults.RowCount := 1;

   lblStatus.Caption := Format(SVerifyRunning, [VerificationCheckCount]);
   Screen.Cursor := crHourGlass;
   try
      (* SO THE STATUS LINE IS PAINTED BEFORE THE WORK STARTS. Without this the
        message never reaches the screen, because the first check begins before
        the paint message is handled. *)
      Application.ProcessMessages;

      results := RunAllVerificationChecks;

      failures := 0;
      grdResults.RowCount := 1 + Length(results);
      for i := 0 to High(results) do
         begin
         (* LclText, NOT a bare assignment: a grid cell is an AnsiString and
           the LCL reads it as UTF-8, so the conversion is stated rather than
           left to the codepage of the machine. *)
         grdResults.Cells[COL_CHECK, i + 1] := LclText(results[i].Name);
         if results[i].Passed then
            begin
            grdResults.Cells[COL_RESULT, i + 1] := SVerifyPassed;
            end
         else
            begin
            grdResults.Cells[COL_RESULT, i + 1] := SVerifyFailed;
            Inc(failures);
            end;

         grdResults.Cells[COL_DETAIL, i + 1] := LclText(results[i].Detail);
         end;

      if failures = 0 then
         begin
         lblStatus.Caption := Format(SVerifyAllPassed, [Length(results)]);
         end
      else
         begin
         lblStatus.Caption := Format(SVerifySomeFailed, [failures, Length(results)]);
         end;

      if Length(results) > 0 then
         begin
         grdResults.Row := 1;
         ShowDetailForRow(1);
         end;
   finally
      Screen.Cursor := crDefault;
      btnRun.Enabled := True;
      btnClose.Enabled := True;
   end;
end;


procedure TfrmVerification.ShowDetailForRow(aRow: integer);
begin
   if (aRow < 1) or (aRow >= grdResults.RowCount) then
      begin
      memDetail.Clear;
      Exit;
      end;
   memDetail.Text := grdResults.Cells[COL_DETAIL, aRow];
end;


procedure TfrmVerification.btnRunClick(Sender: TObject);
begin
   RunChecks;
end;


procedure TfrmVerification.grdResultsSelection(Sender: TObject; aCol, aRow: integer);
begin
   ShowDetailForRow(aRow);
end;

end.
