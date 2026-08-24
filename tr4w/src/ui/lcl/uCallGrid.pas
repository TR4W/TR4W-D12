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

{ A GRID OF CALLSIGNS THAT FLOWS DOWN THEN ACROSS.

  EXTRACTED THE SECOND TIME IT WAS NEEDED, NOT THE THIRD.  The dupe sheet
  landed as an LCL TDrawGrid on 2026-08-24; the Super Check Partial window is
  the same window with different colours -- the same 80x16 cell, the same flow,
  the same list box read back by its own owner-draw handler.  Writing that
  twice would have produced two copies that drift, and the drift is invisible:
  a fix lands in one and not the other, and nothing in the build points at it.
  So the model and the layout live here once and both forms own one.

  WHAT IS SHARED IS THE MODEL AND THE ARITHMETIC.  What is NOT shared is the
  PAINTING, deliberately: the dupe sheet fills each cell with its district
  colour, and the SCP list gradients only the dupes and inverts their text.
  Those are different windows saying different things, and folding them into
  one parameterised painter would make both harder to read than either.  Each
  form keeps its own OnDrawCell and asks this object what is in the cell.

  THE DOWN-THEN-ACROSS RULE IS THE BAND MAP'S, deliberately: three windows now
  lay callsigns out in columns and an operator moving between them should not
  have to learn a second reading order. }
unit uCallGrid;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, Grids;

type
   TCallGrid = class
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
      function  AddCall(const aCall: string; const aTag: PtrInt): boolean;
      procedure EndRebuild;

      { Recompute rows and columns for the current client size.  Safe to call
        at any time; the form calls it from OnResize. }
      procedure LayOut;

      { Which entry is drawn in this cell, or -1 for a cell past the end -- the
        last column is rarely full. }
      function  IndexAt(const aCol, aRow: integer): integer;

      function  Count: integer;
      function  CallAt(const aIndex: integer): string;
      function  TagAt(const aIndex: integer): PtrInt;

      { How many cells the window currently shows.  This is what the SCP window
        used to keep in MaxItemsInMasterListBox and recompute in its WM_SIZE
        handler from a GetWindowRect. }
      function  Capacity: integer;

      { When True, AddCall stops at Capacity.  SCP wants this -- it is showing
        as many partial matches as fit and the rest are not interesting.  The
        dupe sheet does not: it scrolls. }
      property  LimitToVisible: boolean read FLimitToVisible write FLimitToVisible;
   end;

implementation

constructor TCallGrid.Create(const aGrid: TDrawGrid;
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

destructor TCallGrid.Destroy;
begin
   FreeAndNil(FCalls);
   inherited Destroy;
end;

function TCallGrid.Count: integer;
begin
   Result := FCalls.Count;
end;

function TCallGrid.CallAt(const aIndex: integer): string;
begin
   Result := '';
   if (aIndex >= 0) and (aIndex < FCalls.Count) then
      begin
      Result := FCalls[aIndex];
      end;
end;

function TCallGrid.TagAt(const aIndex: integer): PtrInt;
begin
   Result := 0;
   if (aIndex >= 0) and (aIndex < FCalls.Count) then
      begin
      Result := PtrInt(FCalls.Objects[aIndex]);
      end;
end;

function TCallGrid.Capacity: integer;
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
procedure TCallGrid.BeginRebuild;
begin
   FCalls.Clear;
end;

function TCallGrid.AddCall(const aCall: string; const aTag: PtrInt): boolean;
begin
   Result := False;
   if FLimitToVisible and (FCalls.Count >= Capacity) then
      begin
      Exit;
      end;
   FCalls.AddObject(aCall, TObject(aTag));
   Result := True;
end;

procedure TCallGrid.EndRebuild;
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

procedure TCallGrid.LayOut;
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

function TCallGrid.IndexAt(const aCol, aRow: integer): integer;
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
