{
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
 }

{ THE DUPE SHEET, as an LCL form.  Fourth tw_ window to convert.

  TWO OF THEM, one per radio, which is the first thing that makes this window
  different from the three before it: TR4WBandMapForm and TR4WStationsForm are
  single globals, and this one cannot be.  The instances live in GForms and are
  addressed by their tw_ index.

  A TDrawGrid RATHER THAN THE OWNER-DRAWN LIST BOX, and the same shape the band
  map already uses: the cells flow DOWN THEN ACROSS, and how many columns that
  needs falls out of how many fit down.  That is exactly what LB_SETCOLUMNWIDTH
  was asking the list box to work out; the LCL wants the counts instead, which
  is the same arithmetic made explicit.

  NOTE WHICH RESIZE BEHAVIOUR THIS IS.  The stations window has FIXED columns,
  so it scales font and columns together (see TfrmStations.HandleResize).  This
  one REFLOWS -- a wider window means more columns of the same size, not bigger
  cells -- which is what the list box did and what a dupe sheet wants: the
  operator is scanning for a callsign, and more of them visible beats bigger
  ones.  Two different behaviours, deliberately.

  THE MODEL IS FCalls.  CallsignsList is the real source and rebuilds this on
  every band or mode change; FCalls is the derived pair the display needs --
  the callsign and its district digit -- so the grid never has to be read back
  to find out what is in it.  The Win32 version had no choice and used
  LB_GETTEXT plus LB_GETITEMDATA from inside its own draw handler. }
unit uDupeSheetForm;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, Grids, Graphics, VC;

type
   TfrmDupeSheet = class(TForm)
      grdDupes: TDrawGrid;
      procedure HandleCreate(Sender: TObject);
      procedure HandleDestroy(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure HandleResize(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure DupesDrawCell(Sender: TObject; aCol, aRow: integer;
                              aRect: TRect; aState: TGridDrawState);
   private
      FIndex: WindowsType;
      { The callsign, and its district digit as an ORDINAL ('0'..'9' -> 48..57)
        because that is what indexes VDColorsArray. }
      FCalls: TStringList;
      function  CellIndex(const aCol, aRow: integer): integer;
      procedure LayOutGrid;
   public
      procedure BeginRebuild;
      procedure AddCall(const aCall: string; const aDistrict: byte);
      procedure EndRebuild;
   end;

{ What WM_INITDIALOG did, as a seam.  uCallsigns owns the contents and assigns
  this at initialization; this unit knows nothing about callsigns.  Same shape
  as uStationsForm's StationsOnShow and uBandMapView. }
var
   DupeSheetOnShow: procedure(const aIndex: WindowsType) = nil;

{ And what WM_CLOSE did beyond closing: the radio has to be told its dupe sheet
  is gone.  A seam for the same reason -- this unit does not know what a radio
  is. }
   DupeSheetOnClose: procedure(const aIndex: WindowsType) = nil;

function CreateTR4WDupeSheetWindow(const aIndex: WindowsType): HWND;
function DupeSheetForm(const aIndex: WindowsType): TfrmDupeSheet;

{ The writer holds a HANDLE -- Radio.tDupeSheetWnd -- not a form, and changing
  that would spread this conversion into RadioPtr.  One lookup keeps it here. }
function DupeSheetFormForHandle(const aWnd: HWND): TfrmDupeSheet;

implementation

{$R *.lfm}

uses
   MainUnit,          { CloseTR4WWindow }
   uDupesheet,        { VDColorsArray -- the district colours, unchanged }
   uLCLFormHelpers;   { OwnFormByMainWindow }

const
   { The design cell.  80 is the width the list box was given
     (tLB_SETCOLUMNWIDTH, 80 + Ord(BoldFont) * 15). }
   CELL_WIDTH  = 80;
   CELL_HEIGHT = 16;

var
   { Slot 0 is dupe sheet 1, slot 1 is dupe sheet 2. }
   GForms: array[0..1] of TfrmDupeSheet = (nil, nil);

function SlotOf(const aIndex: WindowsType): integer;
begin
   if aIndex = tw_DUPESHEETWINDOW2_INDEX then
      begin
      Result := 1;
      end
   else
      begin
      Result := 0;
      end;
end;

function DupeSheetForm(const aIndex: WindowsType): TfrmDupeSheet;
begin
   Result := GForms[SlotOf(aIndex)];
end;

function DupeSheetFormForHandle(const aWnd: HWND): TfrmDupeSheet;
var
   i: integer;
begin
   Result := nil;
   if aWnd = 0 then
      begin
      Exit;
      end;

   for i := Low(GForms) to High(GForms) do
      begin
      // HandleAllocated first: reading .Handle on a form whose window has not
      // been created would CREATE it, from inside whatever is asking.
      if (GForms[i] <> nil)         and
         GForms[i].HandleAllocated  and
         (GForms[i].Handle = aWnd)  then
         begin
         Result := GForms[i];
         Exit;
         end;
      end;
end;

procedure TfrmDupeSheet.HandleCreate(Sender: TObject);
begin
   FCalls := TStringList.Create;
end;

procedure TfrmDupeSheet.HandleDestroy(Sender: TObject);
begin
   FreeAndNil(FCalls);
end;

procedure TfrmDupeSheet.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // Through the window manager, exactly as WM_CLOSE was, so the saved
   // rectangle, the menu check mark and WndHandle stay in step.  caFree would
   // tear the form down behind CloseTR4WWindow's back.
   CloseAction := caNone;
   if Assigned(DupeSheetOnClose) then
      begin
      DupeSheetOnClose(FIndex);
      end;
   CloseTR4WWindow(FIndex);
end;

procedure TfrmDupeSheet.HandleKeyDown(Sender: TObject; var Key: Word;
                                      Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;      // through HandleClose, so the seam runs
      end;
end;

procedure TfrmDupeSheet.HandleShow(Sender: TObject);
begin
   if Assigned(DupeSheetOnShow) then
      begin
      DupeSheetOnShow(FIndex);
      end;
end;

procedure TfrmDupeSheet.HandleResize(Sender: TObject);
begin
   LayOutGrid;
end;

{ DOWN THEN ACROSS.  This one line is the layout; everything else follows from
  it, and it is deliberately the same rule as the band map's SpotIndexAt so the
  two windows cannot drift into different reading orders. }
function TfrmDupeSheet.CellIndex(const aCol, aRow: integer): integer;
begin
   Result := (aCol * grdDupes.RowCount) + aRow;
end;

procedure TfrmDupeSheet.LayOutGrid;
var
   rowsDown, colsAcross, n: integer;
begin
   if grdDupes = nil then
      begin
      Exit;
      end;

   grdDupes.DefaultColWidth  := CELL_WIDTH;
   grdDupes.DefaultRowHeight := CELL_HEIGHT;

   rowsDown := grdDupes.ClientHeight div CELL_HEIGHT;
   if rowsDown < 1 then
      begin
      rowsDown := 1;
      end;

   n := 0;
   if FCalls <> nil then
      begin
      n := FCalls.Count;
      end;

   colsAcross := (n + rowsDown - 1) div rowsDown;
   if colsAcross < 1 then
      begin
      colsAcross := 1;
      end;

   // ROWS BEFORE COLUMNS.  CellIndex multiplies by RowCount, so a column count
   // set against the old row count maps cells to the wrong callsigns for one
   // paint.  Same ordering trap the band map documents.
   if grdDupes.RowCount <> rowsDown then
      begin
      grdDupes.RowCount := rowsDown;
      end;
   if grdDupes.ColCount <> colsAcross then
      begin
      grdDupes.ColCount := colsAcross;
      end;
end;

{ THE GRADIENT WAS A GRADIENT BETWEEN A COLOUR AND ITSELF.

  The Win32 handler called GradientRect with the SAME colour for both stops, so
  what it produced was a flat fill -- and its `else` arm, which would have
  filled white and walked VDCurrentCallDistrict, could never run: `Left` was set
  to 1 at the top of the procedure and never changed, so `if Left <> 0` was
  always true.  A solid brush is what the operator has always seen; this is not
  a simplification of the appearance, it is the appearance with the machinery
  that never did anything taken out. }
procedure TfrmDupeSheet.DupesDrawCell(Sender: TObject; aCol, aRow: integer;
                                      aRect: TRect; aState: TGridDrawState);
var
   idx: integer;
   district: byte;
begin
   idx := CellIndex(aCol, aRow);

   grdDupes.Canvas.Brush.Style := bsSolid;

   if (FCalls = nil) or (idx < 0) or (idx >= FCalls.Count) then
      begin
      // Past the end of the model -- the last column is rarely full.
      grdDupes.Canvas.Brush.Color := clWindow;
      grdDupes.Canvas.FillRect(aRect);
      Exit;
      end;

   district := byte(PtrInt(FCalls.Objects[idx]));
   if (district < Low(VDColorsArray)) or (district > High(VDColorsArray)) then
      begin
      district := Ord('0');
      end;

   grdDupes.Canvas.Brush.Color := tr4wColorsArray[VDColorsArray[district]];
   grdDupes.Canvas.FillRect(aRect);

   grdDupes.Canvas.Brush.Style := bsClear;      // SetBkMode(TRANSPARENT)
   grdDupes.Canvas.Font.Color  := clBlack;
   grdDupes.Canvas.TextRect(aRect, aRect.Left, aRect.Top, FCalls[idx],
                            TTextStyle(grdDupes.Canvas.TextStyle));
end;

procedure TfrmDupeSheet.BeginRebuild;
begin
   if FCalls = nil then
      begin
      FCalls := TStringList.Create;
      end;
   FCalls.BeginUpdate;
   FCalls.Clear;
end;

procedure TfrmDupeSheet.AddCall(const aCall: string; const aDistrict: byte);
begin
   if FCalls = nil then
      begin
      Exit;
      end;
   FCalls.AddObject(aCall, TObject(PtrInt(aDistrict)));
end;

procedure TfrmDupeSheet.EndRebuild;
begin
   if FCalls = nil then
      begin
      Exit;
      end;
   FCalls.EndUpdate;

   // The cell count changed, so the shape has to be recomputed before anything
   // repaints -- and then repainted, because a grid whose cells carry no text
   // of their own has no way to know its model moved.  Same lesson the
   // possible-call list taught on 2026-08-24.
   LayOutGrid;
   grdDupes.Invalidate;
end;

function CreateTR4WDupeSheetWindow(const aIndex: WindowsType): HWND;
var
   slot: integer;
begin
   slot := SlotOf(aIndex);

   if GForms[slot] = nil then
      begin
      GForms[slot] := TfrmDupeSheet.Create(nil);
      GForms[slot].FIndex := aIndex;
      end;

   // PARENTED THE LCL WAY -- PopupParent / pmExplicit, not
   // SetWindowLongPtr(GWL_HWNDPARENT).
   OwnFormByMainWindow(GForms[slot]);

   Result := GForms[slot].Handle;
end;

end.
