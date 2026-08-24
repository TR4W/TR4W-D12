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

{ A GRID OF SHORT STRINGS THAT FLOWS DOWN THEN ACROSS.

  EXTRACTED THE SECOND TIME IT WAS NEEDED, NOT THE THIRD.  The dupe sheet
  landed as an LCL TDrawGrid on 2026-08-24; the Super Check Partial window is
  the same window with different colours -- the same 80x16 cell, the same flow,
  the same list box read back by its own owner-draw handler.  Writing that
  twice would have produced two copies that drift, and the drift is invisible:
  a fix lands in one and not the other, and nothing in the build points at it.
  So the model and the layout live here once and each form owns one.

  RENAMED FROM TCallGrid AT THE THIRD CALLER, hours after the second.  The
  remaining-multipliers windows are the same grid again -- same flow, same
  owner-drawn list box read back by its own WM_DRAWITEM -- but their cells hold
  prefixes, DXCC ids and zone numbers, not callsigns.  A name that was accurate
  for two windows and wrong for the third is worth changing while it costs four
  files.

  AND THE TEXT IS OPTIONAL, which is what the third caller needed.  Remaining
  mults store only the TAG -- a packed (multiplier type, index) pair -- and
  resolve the text in their own OnDrawCell from mo.PrfList, mo.DomList or
  CTY.ctyTable, because those answers change as the contest runs and a copy
  taken at rebuild time would go stale between rebuilds.  That was the Win32
  behaviour too: LB_ADDSTRING's lParam carried the pair, never a string.

  WHAT IS SHARED IS THE MODEL AND THE ARITHMETIC.  What is NOT shared is the
  PAINTING, deliberately: the dupe sheet fills each cell with its district
  colour, and the SCP list gradients only the dupes and inverts their text.
  Those are different windows saying different things, and folding them into
  one parameterised painter would make both harder to read than either.  Each
  form keeps its own OnDrawCell and asks this object what is in the cell.

  THE DOWN-THEN-ACROSS RULE IS THE BAND MAP'S, deliberately: three windows now
  lay callsigns out in columns and an operator moving between them should not
  have to learn a second reading order. }
unit uFlowGrid;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, Grids;

type
   TFlowGrid = class
   private
      FGrid: TDrawGrid;
      { The callsign, with a per-window meaning in Objects[] -- the district
        digit for the dupe sheet, "is a dupe" for SCP.  One PtrInt is enough for
        both, and naming it TAG rather than either keeps this unit honest about
        not knowing which window it is serving. }
      FCalls: TStringList;
      FCellWidth: integer;
      FCellHeight: integer;
      FLimitToVisible: boolean;
   public
      constructor Create(const aGrid: TDrawGrid;
                         const aCellWidth, aCellHeight: integer);
      destructor Destroy; override;

      procedure BeginRebuild;
      { False means the cell budget is full and the call was NOT added.  Only
        possible when LimitToVisible is set. }
      function  AddItem(const aCall: string; const aTag: PtrInt): boolean;
      procedure EndRebuild;

      { Recompute rows and columns for the current client size.  Safe to call
        at any time; the form calls it from OnResize. }
      procedure LayOut;

      { The cell width is per-window and, for remaining mults, per-CONTEST:
        SetRemMultsColumnWidth widens it when domestic multiplier NAMES are
        shown or the contest does prefix mults.  Setting it re-lays out. }
      procedure SetCellWidth(const aWidth: integer);

      { Which entry is drawn in this cell, or -1 for a cell past the end -- the
        last column is rarely full. }
      function  IndexAt(const aCol, aRow: integer): integer;

      function  Count: integer;
      function  TextAt(const aIndex: integer): string;
      function  TagAt(const aIndex: integer): PtrInt;

      { How many cells the window currently shows.  This is what the SCP window
        used to keep in MaxItemsInMasterListBox and recompute in its WM_SIZE
        handler from a GetWindowRect. }
      function  Capacity: integer;

      { When True, AddItem stops at Capacity.  SCP wants this -- it is showing
        as many partial matches as fit and the rest are not interesting.  The
        dupe sheet does not: it scrolls. }
      property  LimitToVisible: boolean read FLimitToVisible write FLimitToVisible;
   end;

implementation

constructor TFlowGrid.Create(const aGrid: TDrawGrid;
                             const aCellWidth, aCellHeight: integer);
begin
   inherited Create;
   FGrid := aGrid;
   FCalls := TStringList.Create;

   // Floored rather than trusted: a zero divides below, and these come from
   // constants today but are exactly the shape of thing that becomes an
   // operator setting later (the band map's already are).
   FCellWidth := aCellWidth;
   if FCellWidth < 8 then
      begin
      FCellWidth := 8;
      end;
   FCellHeight := aCellHeight;
   if FCellHeight < 4 then
      begin
      FCellHeight := 4;
      end;
end;

destructor TFlowGrid.Destroy;
begin
   FreeAndNil(FCalls);
   inherited Destroy;
end;

function TFlowGrid.Count: integer;
begin
   Result := FCalls.Count;
end;

function TFlowGrid.TextAt(const aIndex: integer): string;
begin
   Result := '';
   if (aIndex >= 0) and (aIndex < FCalls.Count) then
      begin
      Result := FCalls[aIndex];
      end;
end;

function TFlowGrid.TagAt(const aIndex: integer): PtrInt;
begin
   Result := 0;
   if (aIndex >= 0) and (aIndex < FCalls.Count) then
      begin
      Result := PtrInt(FCalls.Objects[aIndex]);
      end;
end;

function TFlowGrid.Capacity: integer;
var
   across, down: integer;
begin
   Result := 0;
   if FGrid = nil then
      begin
      Exit;
      end;

   across := FGrid.ClientWidth div FCellWidth;
   down   := FGrid.ClientHeight div FCellHeight;
   if (across < 1) or (down < 1) then
      begin
      Exit;
      end;
   Result := across * down;
end;

{ NO BeginUpdate/EndUpdate PAIR, deliberately.  The list is not bound to a
  control, so there is nothing to suppress -- and the callers do not nest
  cleanly: the SCP window is cleared through one path (ClearMasterListBox) and
  filled through another (SuperCheckPartial), so a counter would go negative and
  the NEXT rebuild would be the one that broke. }
procedure TFlowGrid.BeginRebuild;
begin
   FCalls.Clear;
end;

function TFlowGrid.AddItem(const aCall: string; const aTag: PtrInt): boolean;
begin
   Result := False;
   if FLimitToVisible and (FCalls.Count >= Capacity) then
      begin
      Exit;
      end;
   FCalls.AddObject(aCall, TObject(aTag));
   Result := True;
end;

procedure TFlowGrid.EndRebuild;
begin
   // The cell count changed, so the shape is recomputed -- and then repainted,
   // because a grid whose cells carry no text of their own has no way to know
   // its model moved.  That lesson cost an afternoon on the possible-call list
   // (2026-08-24): the Win32 list box repainted because each item's DATA
   // differed, which was never a decision anyone made.
   LayOut;
   if FGrid <> nil then
      begin
      FGrid.Invalidate;
      end;
end;

procedure TFlowGrid.LayOut;
var
   rowsDown, colsAcross: integer;
begin
   if FGrid = nil then
      begin
      Exit;
      end;

   FGrid.DefaultColWidth  := FCellWidth;
   FGrid.DefaultRowHeight := FCellHeight;

   rowsDown := FGrid.ClientHeight div FCellHeight;
   if rowsDown < 1 then
      begin
      rowsDown := 1;
      end;

   colsAcross := (FCalls.Count + rowsDown - 1) div rowsDown;
   if colsAcross < 1 then
      begin
      colsAcross := 1;
      end;

   // ROWS BEFORE COLUMNS.  IndexAt multiplies by RowCount, so a column count
   // set against the old row count maps cells to the wrong callsigns for one
   // paint.  The band map documents the same trap.
   if FGrid.RowCount <> rowsDown then
      begin
      FGrid.RowCount := rowsDown;
      end;
   if FGrid.ColCount <> colsAcross then
      begin
      FGrid.ColCount := colsAcross;
      end;
end;

procedure TFlowGrid.SetCellWidth(const aWidth: integer);
begin
   if aWidth < 8 then
      begin
      Exit;
      end;
   if FCellWidth = aWidth then
      begin
      Exit;
      end;
   FCellWidth := aWidth;
   LayOut;
end;

function TFlowGrid.IndexAt(const aCol, aRow: integer): integer;
begin
   Result := -1;
   if FGrid = nil then
      begin
      Exit;
      end;

   Result := (aCol * FGrid.RowCount) + aRow;
   if (Result < 0) or (Result >= FCalls.Count) then
      begin
      Result := -1;
      end;
end;

end.
