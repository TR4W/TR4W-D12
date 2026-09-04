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

(* VIEW / EDIT LOG -- the whole contest log, in a window.

  REPLACES A HAND-BUILT WIN32 DIALOG. uLogEdit created its list with
  CreateEditableLog -- a raw CreateWindowExW -- inside a CreateModalDialog
  template, and filled it by walking the whole log and calling
  tAddContestExchangeToLog once per QSO. On a contest-sized log that is
  thousands of LVM_INSERTITEM messages before the window appears.

  THE SAME GRID THE MAIN WINDOW USES. This form held its own virtual list, its
  own 512-row cache, its own column builder and its own colour rules, and the
  main window held a second copy of each. They had already drifted -- this one
  grew a working double-click while the main one still counted rows in a
  widget. One TLogGrid (uLogGrid) is both, so a fix to how the log looks or
  scrolls lands in both windows or in neither.

  THE ROW TEXT COMES FROM THE ONE PLACE THAT KNOWS IT. MainUnit.LogRowTextFor
  runs the same 360 lines tAddContestExchangeToLog always ran -- every
  condition, every special case -- and returns the columns as text instead of
  writing them into a control. There is no second formatter to drift. *)
unit uLogEditForm;

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, Forms, Controls, Graphics, LCLType,
   uLogGrid,
   VC, uLogSource, MainUnit;

type
   TfrmLogEdit = class(TForm)
      procedure FormCreate(Sender: TObject);
      procedure FormShow(Sender: TObject);
      procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   private
      FGrid: TLogGrid;
      FOpen: boolean;

      procedure GridFetchRow(Sender: TObject; const aIndex: Int64;
                             out aText: TLogRowText;
                             out aDeleted: boolean;
                             out aXQSO: boolean;
                             var aOK: boolean);
      procedure GridDblClick(Sender: TObject);
      procedure ReloadFromLog;
   end;

(* Opens it modally over the main window. *)
procedure ShowLogEditForm;

implementation

{$R *.lfm}

uses
   uEditQSO, uLCLFormHelpers,
   uMainForm;   (* TR4WMainForm -- this form's owner; see ShowLogEditForm *)

var
   frmLogEdit: TfrmLogEdit = nil;

procedure ShowLogEditForm;
begin
   if frmLogEdit = nil then
      begin
      frmLogEdit := TfrmLogEdit.Create(Application);
      end;

   (* THE MAIN WINDOW IS THIS FORM'S OWNER, AND SAYING SO IS WHAT KEEPS IT ON
     TOP. ShowModalOverWin32Parent disables the parent -- which stops clicks --
     but never establishes an OWNER relationship, so Windows does not know the
     two belong together: switching to another program and back brought the
     MAIN window forward and left this one behind it, still modal and now
     invisible (NY4I, 2026-09-03).

     PopupParent is the LCL's own way to say it, and it works because the main
     window is a TForm now.

     EVERY CONVERTED DIALOG SHOWN THIS WAY HAS THE SAME GAP. Fixing it in
     ShowModalOverWin32Parent would fix all of them at once, but that helper
     takes an HWND and would have to find the form behind it; recorded in the
     bench queue rather than guessed at here. *)
   if TR4WMainForm <> nil then
      begin
      frmLogEdit.PopupParent := TR4WMainForm;
      end;

   ShowModalOverWin32Parent(frmLogEdit, tr4whandle);
end;

procedure TfrmLogEdit.FormCreate(Sender: TObject);
begin
   FOpen := False;

   (* IN CODE RATHER THAN IN THE .lfm, because TLogGrid is not a registered
     design-time component and a .lfm naming a class the streaming loader
     cannot resolve fails at the FIRST bad property with the window half
     built. Everything else about this form is designed. *)
   FGrid := TLogGrid.Create(Self);
   FGrid.Parent     := Self;
   FGrid.Align      := alClient;
   (* @ ON BOTH: this unit is {$mode objfpc}, where a method reference needs
     the address operator. uMainForm is {$MODE Delphi} and assigns the same
     kind of handler without one -- the two forms are not inconsistent, their
     compiler modes are. *)
   FGrid.OnFetchRow := @GridFetchRow;
   FGrid.OnDblClick := @GridDblClick;
   FGrid.BuildColumns;
end;

(* HELD OPEN FOR THE LIFE OF THE WINDOW. The grid asks per painted row, so
  opening and closing the source per row would reopen the database thousands of
  times while the operator scrolls. *)
procedure TfrmLogEdit.FormShow(Sender: TObject);
begin
   FOpen := LogSourceOpen;
   ReloadFromLog;
end;

procedure TfrmLogEdit.ReloadFromLog;
begin
   FGrid.Reload;
   if FOpen then
      begin
      FGrid.RecordCount := LogSourceRecordCount;
      end
   else
      begin
      FGrid.RecordCount := 0;
      end;
end;

procedure TfrmLogEdit.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   if FOpen then
      begin
      LogSourceClose;
      FOpen := False;
      end;
   CloseAction := caHide;
end;

(* ESCAPE CLOSES IT.

  A Win32 DialogBox did this for free and a TForm does not -- Lint-FormDefaults
  exists because that difference is invisible until an operator is stuck in a
  window with no keyboard way out. There is no Cancel button to carry it, so
  the form takes the key itself through KeyPreview. *)
procedure TfrmLogEdit.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   if (Key = VK_ESCAPE) and (Shift = []) then
      begin
      Key := 0;
      Close;
      end;
end;

(* ONE ROW, ON DEMAND.

  LogSourceReadAtIndex is documented as independent of any sequential read in
  progress, which is what makes it safe to call from a paint.

  X-QSO AND DELETED ROWS ARE VISIBLY DIFFERENT, and the grid draws that
  difference from these two flags. The main window used to do it through
  NM_CUSTOMDRAW, reading a flag smuggled into the row's per-item lParam by
  SetRowXQSOFlag, and neither this window nor Log Search had that arm -- so an
  X-QSO looked identical to a claimed QSO in both, which is the defect NY4I hit
  on 2026-09-02. A row that knows its own record needs no smuggling. *)
procedure TfrmLogEdit.GridFetchRow(Sender: TObject; const aIndex: Int64;
                                   out aText: TLogRowText;
                                   out aDeleted: boolean;
                                   out aXQSO: boolean;
                                   var aOK: boolean);
var
   rec: ContestExchange;
begin
   aOK      := False;
   aDeleted := False;
   aXQSO    := False;
   FillChar(aText, SizeOf(aText), 0);

   (* THE SAME SELF-HEALING CHECK THE MAIN LOG MAKES, and for the same reason:
     FOpen records that THIS FORM opened the source, which is not the same fact
     as the source being open. The QSO editor this window launches closes it. *)
   if not LogSourceIsOpen then
      begin
      if not LogSourceOpen then
         begin
         Exit;
         end;
      end;

   if not LogSourceReadAtIndex(aIndex, rec) then
      begin
      Exit;
      end;

   LogRowTextFor(rec, aText);
   aDeleted := rec.ceQSO_Deleted;
   aXQSO    := rec.ceXQSO;
   aOK      := True;
end;

procedure TfrmLogEdit.GridDblClick(Sender: TObject);
var
   rec: Int64;
begin
   rec := FGrid.SelectedRecord;
   if (rec < 0) or (not FOpen) then
      begin
      Exit;
      end;

   (* THE GRID ANSWERS IN RECORDS, NOT ROWS. This window lists the whole log in
     order, so the two happen to coincide here -- but they did not in the main
     window, and asking the control for a row index is what produced the
     row/record mismatch NY4I hit. There is one definition of that mapping now
     and it is TLogGrid.SelectedRecord. *)
   IndexOfItemInLogForEdit := rec;

   (* The editor reads and writes the log itself, so the source is closed
     around it rather than left open under a window that is about to change
     the record underneath us. *)
   LogSourceClose;
   FOpen := False;
   try
      OpenEditQSOWindow(Self.Handle);
   finally
      FOpen := LogSourceOpen;
      ReloadFromLog;
   end;
end;

end.
