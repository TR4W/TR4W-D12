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
   (* ONE ROW, REMEMBERED.

     WHY A CACHE AT ALL. A virtual list asks for what it is about to paint, and
     it asks TWICE per row -- once in OnData for the text and again in
     OnCustomDrawItem for the colour. Each of those was a SQLite read plus a
     run of the 360-line row builder, so a single repaint of a dozen visible
     rows was two dozen queries. NY4I could watch it: "It is still not smooth
     and I can watch the grid redraw."

     The columns were never the slow part. Painting was. *)
   TLogRowCacheEntry = record
      Index:   integer;   (* the record this holds, or -1 for empty *)
      Text:    TLogRowText;
      Deleted: boolean;
      XQSO:    boolean;
   end;
   PLogRowCacheEntry = ^TLogRowCacheEntry;

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
      FCache: array of TLogRowCacheEntry;
      function  Row(aIndex: integer): PLogRowCacheEntry;
      procedure DropCache;
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

(* DIRECT-MAPPED, AND BOUNDED. A slot per index modulo the cache size: no
  eviction policy to get wrong, no list to walk, and the memory does not grow
  with the log -- which is the whole reason the list is virtual. Rows near each
  other collide only when they are CACHE_ROWS apart, and a repaint touches a
  contiguous run, so in practice a paint hits the cache for every row after the
  first pass over it.

  512 rows is roughly twenty screens; a scroll re-reads only what scrolls in. *)
const
   CACHE_ROWS = 512;

function TfrmLogEdit.Row(aIndex: integer): PLogRowCacheEntry;
var
   rec: ContestExchange;
   c:   LogColumnsType;
begin
   Result := @FCache[aIndex mod CACHE_ROWS];
   if Result^.Index = aIndex then
      begin
      Exit;
      end;

   Result^.Index := -1;
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      Result^.Text[c] := '';
      end;
   Result^.Deleted := False;
   Result^.XQSO    := False;

   if not FOpen then
      begin
      Exit;
      end;
   if not LogSourceReadAtIndex(aIndex, rec) then
      begin
      Exit;
      end;

   LogRowTextFor(rec, Result^.Text);
   Result^.Deleted := rec.ceQSO_Deleted;
   Result^.XQSO    := rec.ceXQSO;
   Result^.Index   := aIndex;
end;

(* AFTER ANYTHING THAT CAN CHANGE THE LOG. Cheaper and more honest than trying
  to work out which rows moved: an edit can renumber everything after it. *)
procedure TfrmLogEdit.DropCache;
var
   i: integer;
begin
   SetLength(FCache, CACHE_ROWS);
   for i := 0 to High(FCache) do
      begin
      FCache[i].Index := -1;
      end;
end;

procedure TfrmLogEdit.FormCreate(Sender: TObject);
begin
   FOpen := False;
   DropCache;
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
   c:       LogColumnsType;
   i:       integer;
   charW:   integer;
   wanted:  integer;
   total:   integer;
   avail:   integer;
   slack:   integer;
   given:   integer;
   widths:  array of integer;
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

   SetLength(widths, lvLog.Columns.Count);

   (* PASS ONE -- WHAT EACH COLUMN NEEDS, INTO AN ARRAY AND NOT INTO THE
     WIDGET. Writing the widths as they were computed is what NY4I could
     SEE: "the columns all compress to the left, then it extended to the
     right again", and the same animation on every resize. Each assignment
     to Columns[i].Width repaints, so the intermediate state of a two-pass
     calculation was being drawn. *)
   total := 0;
   i := 0;
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[c].Enable then
         begin
         Continue;
         end;
      if i > High(widths) then
         begin
         Break;
         end;

      wanted := (ColumnsArray[c].Width * charW) + charW;
      if wanted < lvLog.Canvas.TextWidth(AnsiString(ColumnsArray[c].Text)) + charW then
         begin
         wanted := lvLog.Canvas.TextWidth(AnsiString(ColumnsArray[c].Text)) + charW;
         end;

      widths[i] := wanted;
      total := total + wanted;
      Inc(i);
      end;

   (* PASS TWO -- the leftover, in proportion, still only in the array. *)
   avail := lvLog.ClientWidth;
   if (avail > total) and (total > 0) then
      begin
      slack := avail - total;
      given := 0;
      for i := 0 to High(widths) do
         begin
         if i = High(widths) then
            begin
            widths[i] := widths[i] + (slack - given);
            end
         else
            begin
            wanted := (widths[i] * slack) div total;
            widths[i] := widths[i] + wanted;
            given := given + wanted;
            end;
         end;
      end;

   (* ONE PAINT. BeginUpdate/EndUpdate around the only loop that touches the
     control, and a width that is already right is not written at all -- which
     is why re-opening the window was smooth even before this: the assignments
     were no-ops and the LCL skipped them. *)
   lvLog.Columns.BeginUpdate;
   try
      for i := 0 to High(widths) do
         begin
         if lvLog.Columns[i].Width <> widths[i] then
            begin
            lvLog.Columns[i].Width := widths[i];
            end;
         end;
   finally
      lvLog.Columns.EndUpdate;
   end;
end;

(* SIZED BEFORE THE ROWS ARE COUNTED, so the first paint already has the final
  columns. Sizing afterwards meant the window appeared with the .lfm's
  placeholder widths and then corrected itself in view. *)
procedure TfrmLogEdit.FormShow(Sender: TObject);
begin
   SizeColumns;
   (* HELD OPEN FOR THE LIFE OF THE WINDOW. OnData fires per painted row, so
     opening and closing the source per row would reopen the database
     thousands of times while the operator scrolls. *)
   FOpen := LogSourceOpen;
   if not FOpen then
      begin
      lvLog.Items.Count := 0;
      Exit;
      end;

   DropCache;
   lvLog.Items.Count := LogSourceRecordCount;
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
   e:     PLogRowCacheEntry;
   c:     LogColumnsType;
   first: boolean;
begin
   e := Row(Item.Index);

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
         Item.Caption := e^.Text[c];
         first := False;
         end
      else
         begin
         Item.SubItems.Add(e^.Text[c]);
         end;
      end;
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
   e: PLogRowCacheEntry;
begin
   DefaultDraw := True;
   e := Row(Item.Index);

   if e^.Deleted then
      begin
      Sender.Canvas.Font.Color := clRed;
      end
   else if e^.XQSO then
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
      DropCache;
      lvLog.Items.Count := LogSourceRecordCount;
      lvLog.Invalidate;
   end;
end;

end.
