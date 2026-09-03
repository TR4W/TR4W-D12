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

(* VIEW / EDIT LOG -- an LCL form over a VIRTUAL list.

  REPLACES A HAND-BUILT WIN32 DIALOG. uLogEdit created its list with
  CreateEditableLog -- a raw CreateWindowExW -- inside a CreateModalDialog
  template, and filled it by walking the whole log and calling
  tAddContestExchangeToLog once per QSO. On a contest-sized log that is
  thousands of LVM_INSERTITEM messages before the window appears.

  OwnerData: THE LIST HOLDS NO ROWS. It knows only how many there are and asks
  OnData for the one it is about to paint, so opening is instant however long
  the log is and memory does not grow with it. That is also why this could not
  be done until now: the old code READ QSO DATA BACK OUT OF THE WIDGET, so an
  empty-but-counted list would have returned nothing. Those reads were
  repointed at the log first (LOGEDIT.LastName was the last one).

  THE ROW TEXT COMES FROM THE ONE PLACE THAT KNOWS IT. MainUnit.LogRowTextFor
  runs the same 360 lines tAddContestExchangeToLog always ran -- every
  condition, every special case -- and returns the columns as text instead of
  writing them into a listview. There is no second formatter to drift.

  A SCROLLBAR, AND NO FIXED ROW COUNT. The Win32 original was created with
  LVS_NOSCROLL and showed LinesInEditableLog rows; this scrolls, which is what
  a window listing a whole contest should do. *)
unit uLogEditForm;

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, Forms, Controls, ComCtrls, Graphics, LCLType,
   VC, uLogSource, MainUnit;

type
   TfrmLogEdit = class(TForm)
      lvLog: TListView;
      procedure FormCreate(Sender: TObject);
      procedure FormShow(Sender: TObject);
      procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure FormResize(Sender: TObject);
      procedure lvLogData(Sender: TObject; Item: TListItem);
      procedure lvLogDblClick(Sender: TObject);
      procedure lvLogCustomDrawItem(Sender: TCustomListView; Item: TListItem;
                                    State: TCustomDrawState; var DefaultDraw: boolean);
   private
      FOpen: boolean;
      procedure BuildColumns;
      procedure SizeColumns;
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
     window is a TForm now. Before the conversion the only way to express this
     was SetWindowLongPtr(GWLP_HWNDPARENT) against a raw handle.

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
   BuildColumns;
end;

(* THE SAME COLUMNS THE MAIN LOG SHOWS, from the same table.

  ColumnsArray carries the caption, the width, the alignment and whether the
  column is enabled at all; CreateEditableLog reads exactly these and so does
  this. A second list of columns here would be a second thing to keep in step. *)
procedure TfrmLogEdit.BuildColumns;
var
   c: LogColumnsType;
   col: TListColumn;
begin
   lvLog.Columns.BeginUpdate;
   try
      lvLog.Columns.Clear;
      for c := Low(LogColumnsType) to High(LogColumnsType) do
         begin
         if not ColumnsArray[c].Enable then
            begin
            Continue;
            end;

         col := lvLog.Columns.Add;
         (* AnsiString() explicitly: a column caption is ASCII and the LCL
           property is a TTranslateString, so the conversion is real. *)
         col.Caption := AnsiString(ColumnsArray[c].Text);
         (* A PLACEHOLDER. SizeColumns measures and distributes -- see there. *)
         col.Width := 40;
         end;
   finally
      lvLog.Columns.EndUpdate;
   end;
end;

(* COLUMNS MEASURED, THEN THE SLACK DISTRIBUTED.

  ColumnsArray[c].Width is a COUNT OF CHARACTERS -- the Win32 listview
  multiplied it by a magic factor (17 for this window, 5 for the main one,
  MainUnit.pas:7938-7947) and the result depended on whichever font had been
  set. Multiplying by a guess is what produced columns two characters wide.

  SO IT IS MEASURED against the font the list is actually using, with a digit
  as the reference glyph because every numeric column is the width of its
  digits, and the header caption is taken into account so a heading is never
  clipped by a narrow column.

  THEN THE LEFTOVER IS GIVEN AWAY IN PROPORTION, which is what NY4I asked for:
  the columns fill the grid rather than huddling at the left with dead space to
  the right. Proportional rather than all-to-the-last, so widening the window
  makes Callsign grow more than Band -- the wide columns are the ones with
  something to show.

  NOTHING SHRINKS BELOW ITS MEASURED WIDTH. If the log genuinely needs more
  room than the window has, the list scrolls horizontally; squeezing every
  column to fit would make all of them unreadable instead of some of them
  off-screen. *)
procedure TfrmLogEdit.SizeColumns;
var
   c:        LogColumnsType;
   i:        integer;
   charW:    integer;
   wanted:   integer;
   total:    integer;
   avail:    integer;
   slack:    integer;
   given:    integer;
begin
   if lvLog.Columns.Count = 0 then
      begin
      Exit;
      end;

   lvLog.Canvas.Font.Assign(lvLog.Font);
   charW := lvLog.Canvas.TextWidth('0');
   if charW < 1 then
      begin
      charW := 7;
      end;

   (* Pass one: what each column needs. *)
   i := 0;
   total := 0;
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[c].Enable then
         begin
         Continue;
         end;
      if i >= lvLog.Columns.Count then
         begin
         Break;
         end;

      wanted := (ColumnsArray[c].Width * charW) + charW;
      if wanted < lvLog.Canvas.TextWidth(AnsiString(ColumnsArray[c].Text)) + charW then
         begin
         wanted := lvLog.Canvas.TextWidth(AnsiString(ColumnsArray[c].Text)) + charW;
         end;

      lvLog.Columns[i].Width := wanted;
      total := total + wanted;
      Inc(i);
      end;

   (* Pass two: hand out what is left, in proportion to what each asked for. *)
   avail := lvLog.ClientWidth;
   if (avail <= total) or (total <= 0) then
      begin
      Exit;
      end;

   slack := avail - total;
   given := 0;
   for i := 0 to lvLog.Columns.Count - 1 do
      begin
      if i = lvLog.Columns.Count - 1 then
         begin
         (* THE LAST COLUMN TAKES THE REMAINDER, so integer division cannot
           leave a one-pixel gap at the right edge. *)
         lvLog.Columns[i].Width := lvLog.Columns[i].Width + (slack - given);
         end
      else
         begin
         wanted := (lvLog.Columns[i].Width * slack) div total;
         lvLog.Columns[i].Width := lvLog.Columns[i].Width + wanted;
         given := given + wanted;
         end;
      end;
end;

procedure TfrmLogEdit.FormShow(Sender: TObject);
begin
   (* HELD OPEN FOR THE LIFE OF THE WINDOW. OnData fires per painted row, so
     opening and closing the source per row would reopen the database
     thousands of times while the operator scrolls. *)
   FOpen := LogSourceOpen;
   if not FOpen then
      begin
      lvLog.Items.Count := 0;
      Exit;
      end;

   lvLog.Items.Count := LogSourceRecordCount;
   SizeColumns;
   lvLog.Invalidate;
end;

(* Re-measured on every resize, which is the point of distributing at all. *)
procedure TfrmLogEdit.FormResize(Sender: TObject);
begin
   SizeColumns;
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

(* ONE ROW, ON DEMAND.

  LogSourceReadAtIndex is documented as independent of any sequential read in
  progress, which is what makes it safe to call from a paint. *)
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

procedure TfrmLogEdit.lvLogData(Sender: TObject; Item: TListItem);
var
   rec:  ContestExchange;
   rowText: TLogRowText;
   c:    LogColumnsType;
   first: boolean;
begin
   if not FOpen then
      begin
      Exit;
      end;

   if not LogSourceReadAtIndex(Item.Index, rec) then
      begin
      Item.Caption := '';
      Exit;
      end;

   LogRowTextFor(rec, rowText);

   first := True;
   Item.SubItems.Clear;
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[c].Enable then
         begin
         Continue;
         end;

      if first then
         begin
         Item.Caption := rowText[c];
         first := False;
         end
      else
         begin
         Item.SubItems.Add(rowText[c]);
         end;
      end;

   (* The record itself is not kept -- Data would have to be freed and the row
     is re-read whenever it is repainted anyway. The X-QSO flag is re-read in
     the custom draw for the same reason. *)
end;

(* X-QSO AND DELETED ROWS ARE VISIBLY DIFFERENT, IN EVERY WINDOW.

  The main window greys an X-QSO row through NM_CUSTOMDRAW in
  uMainWindowProc, reading a flag smuggled into the row's per-item lParam by
  SetRowXQSOFlag. Neither the old Log Edit dialog nor Log Search had that arm,
  so an X-QSO looked identical to a claimed QSO in both -- which is the defect
  NY4I hit on 2026-09-02 and which was recorded as an acceptance criterion for
  this conversion.

  A virtual list needs no smuggling: the row knows its own record. *)
procedure TfrmLogEdit.lvLogCustomDrawItem(Sender: TCustomListView; Item: TListItem;
                                          State: TCustomDrawState; var DefaultDraw: boolean);
var
   rec: ContestExchange;
begin
   DefaultDraw := True;
   if not FOpen then
      begin
      Exit;
      end;

   if not LogSourceReadAtIndex(Item.Index, rec) then
      begin
      Exit;
      end;

   if rec.ceQSO_Deleted then
      begin
      Sender.Canvas.Font.Color := clRed;
      end
   else if rec.ceXQSO then
      begin
      Sender.Canvas.Font.Color := clGray;
      end;
end;

procedure TfrmLogEdit.lvLogDblClick(Sender: TObject);
begin
   if (lvLog.Selected = nil) or (not FOpen) then
      begin
      Exit;
      end;

   (* THE ROW NUMBER IS THE RECORD INDEX: this window lists the whole log, in
     order, from row 0. Stated here because the MAIN window's list does not
     work that way -- it shows a tail, and uEditableLogView owns that mapping. *)
   IndexOfItemInLogForEdit := lvLog.Selected.Index;

   (* The editor reads and writes the log itself, so the source is closed
     around it rather than left open under a window that is about to change
     the record underneath us. *)
   LogSourceClose;
   FOpen := False;
   try
      OpenEditQSOWindow(Self.Handle);
   finally
      FOpen := LogSourceOpen;
      lvLog.Items.Count := LogSourceRecordCount;
      lvLog.Invalidate;
   end;
end;

end.
