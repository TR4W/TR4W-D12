unit uLogGrid;

(* THE CONTEST LOG, DRAWN.

  ONE CONTROL, TWO WINDOWS: the log on the main window and the View/Edit Log
  window are the same grid with different bounds. They had been two separate
  list views with two row caches, two column builders and two sets of colour
  rules, and they had already drifted -- the edit window grew a working
  double-click while the main one still counted rows in a widget.

  WHY A GRID AND NOT A LIST VIEW.

  The LCL's TListView on Windows IS the comctl32 list-view control -- a thin
  wrapper over a native window. Everything it does well, it does because the
  native control does it, and everything the native control believes about
  itself is reachable by any code holding its handle. That is not a theory:
  the main log rendered as blank paper for three sessions because one line in
  LOGWIND replaced the control's entire window style with a literal
  ($5000A005), which stripped LVS_OWNERDATA -- so a virtual list had no rows --
  and set LVS_NOSCROLL, which is why there was no scrollbar and why the log
  showed a fixed five QSOs of a contest (NY4I, repeatedly).

  TDrawGrid is drawn by the LCL itself. There is no native control underneath
  to be reconfigured behind its back, the scrollbar is the LCL's, and the
  painting is the code below rather than a message protocol. That is what
  makes this a form written as an LCL form rather than a port of a Win32 one.

  IT HOLDS NO ROWS. The log is a file or a database table of unbounded length;
  this asks for the rows it is about to paint, through OnFetchRow, and caches
  what it gets. Opening is therefore instant whether the log holds ten QSOs or
  ten thousand, and no part of the program has to decide how many rows are
  "enough" to keep in a widget. *)

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

interface

uses
   Classes, SysUtils, Graphics, Grids, Controls, StdCtrls,
   VC;   (* LogColumnsType, TLogRowText, ColumnsArray, tr4wColorsArray *)

type
   (* HOW THE GRID GETS A ROW.

     aIndex is a RECORD index into the log, not a screen row -- the grid does
     that arithmetic itself and the caller never sees a scroll position. Return
     False when there is no such record; the grid paints nothing rather than
     guessing.

     aDeleted and aXQSO are the two states a row is drawn in, and they are
     properties of the QSO rather than of the display, which is why they come
     back from the fetch instead of being asked for separately. *)
   TLogRowFetchEvent = procedure(Sender: TObject;
                                 const aIndex: Int64;
                                 out aText: TLogRowText;
                                 out aDeleted: boolean;
                                 out aXQSO: boolean;
                                 var aOK: boolean) of object;

   TLogGridCacheEntry = record
      Index:   Int64;
      Valid:   boolean;
      Deleted: boolean;
      XQSO:    boolean;
      Text:    TLogRowText;
   end;
   PLogGridCacheEntry = ^TLogGridCacheEntry;

   TLogGrid = class(TDrawGrid)
   private
      FRecordCount: Int64;
      FOnFetchRow:  TLogRowFetchEvent;
      FColumnOf:    array of LogColumnsType;
      FCache:       array of TLogGridCacheEntry;

      function  Fetch(const aIndex: Int64): PLogGridCacheEntry;
      procedure SetRecordCount(const aValue: Int64);
      function  GetSelectedRecord: Int64;
      procedure SetSelectedRecord(const aValue: Int64);
   protected
      procedure DrawCell(aCol, aRow: integer; aRect: TRect;
                         aState: TGridDrawState); override;
      procedure DoOnResize; override;
   public
      constructor Create(aOwner: TComponent); override;

      (* Rebuild the visible columns from ColumnsArray and distribute the
        width. Call after a contest changes which columns are enabled. *)
      procedure BuildColumns;

      (* Share the width out among the visible columns -- see the body. *)
      procedure SizeColumns;

      (* Forget every cached row and repaint. The log changed under us. *)
      procedure Reload;

      (* Put the newest QSO in view, which is where an operator looks. *)
      procedure ScrollToEnd;

      (* The record index under the current row, or -1 if the grid is on its
        header or empty. This is the only place row->record is computed. *)
      property SelectedRecord: Int64 read GetSelectedRecord write SetSelectedRecord;

      (* How many log records exist. Setting it is what makes the log appear. *)
      property RecordCount: Int64 read FRecordCount write SetRecordCount;

      property OnFetchRow: TLogRowFetchEvent read FOnFetchRow write FOnFetchRow;
   end;

implementation

const
   (* A DIRECT-MAPPED CACHE, sized to comfortably exceed a screenful so that
     scrolling never evicts a row it is about to ask for again. Direct-mapped
     rather than an LRU because the access pattern is a contiguous window --
     index mod N collides only between rows N apart, which are never on screen
     together. *)
   CACHE_ROWS = 512;

constructor TLogGrid.Create(aOwner: TComponent);
begin
   inherited Create(aOwner);

   SetLength(FCache, CACHE_ROWS);
   Reload;

   FRecordCount := 0;

   (* goRowSelect: a log row is the unit an operator selects, never a cell.
     goThumbTracking: the rows follow the scrollbar thumb while it is dragged
     rather than jumping when it is released. goColSizing lets the operator
     drag a column edge, which is the feature the old header-tracking code in
     uMainWindowProc existed to provide and no longer has to. *)
   Options := [goRowSelect, goThumbTracking, goColSizing, goVertLine, goHorzLine];

   FixedCols     := 0;
   FixedRows     := 1;
   ColCount      := 1;
   RowCount      := 1;
   ScrollBars    := ssAutoVertical;
   BorderStyle   := bsSingle;
   DefaultRowHeight := 16;
   Color         := tr4wColorsArray[trWhite];
   Font.Color    := tr4wColorsArray[trBlack];
   Font.Name     := 'Courier New';
   Font.Size     := 9;
end;

(* WHICH COLUMNS ARE SHOWN, AND IN WHICH ORDER.

  ColumnsArray is the source of truth -- Enable says whether a column applies
  to this contest, and it changes when the contest does. FColumnOf maps a grid
  column back to its LogColumnsType so that painting never has to re-walk the
  enable flags. *)
procedure TLogGrid.BuildColumns;
var
   c: LogColumnsType;
   n: integer;
begin
   n := 0;
   SetLength(FColumnOf, Ord(High(LogColumnsType)) - Ord(Low(LogColumnsType)) + 1);

   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[c].Enable then
         begin
         Continue;
         end;
      FColumnOf[n] := c;
      Inc(n);
      end;

   SetLength(FColumnOf, n);

   if n = 0 then
      begin
      (* A contest with no enabled columns cannot happen, but a grid with zero
        columns can be constructed and would divide by zero below. *)
      n := 1;
      SetLength(FColumnOf, 1);
      FColumnOf[0] := logColCallsign;
      end;

   ColCount := n;
   SizeColumns;
end;

(* THE WIDTHS.

  ColumnsArray[].Width IS A COUNT OF CHARACTERS, not pixels -- it was written
  for a fixed-pitch DOS display and the Win32 port passed it to a control that
  wanted pixels, which is why narrow columns clipped their own headers. It is
  multiplied by the width of a character in the grid's actual font here, which
  is the only place that conversion happens.

  Any width left over after every column has what it asked for goes to the
  callsign column, because that is the field an operator reads across the room
  and the one whose contents vary most in length. *)
procedure TLogGrid.SizeColumns;
var
   i:      integer;
   charW:  integer;
   want:   integer;
   total:  integer;
   spare:  integer;
   callIx: integer;
begin
   if Length(FColumnOf) = 0 then
      begin
      Exit;
      end;

   Canvas.Font.Assign(Font);
   charW := Canvas.TextWidth('0');
   if charW <= 0 then
      begin
      charW := 8;
      end;

   total  := 0;
   callIx := -1;

   for i := 0 to High(FColumnOf) do
      begin
      want := (ColumnsArray[FColumnOf[i]].Width * charW) + charW;

      (* Never narrower than its own heading, or the header row clips. *)
      if want < Canvas.TextWidth(ColumnsArray[FColumnOf[i]].Text) + charW then
         begin
         want := Canvas.TextWidth(ColumnsArray[FColumnOf[i]].Text) + charW;
         end;

      ColWidths[i] := want;
      Inc(total, want);

      if FColumnOf[i] = logColCallsign then
         begin
         callIx := i;
         end;
      end;

   spare := ClientWidth - total - 4;
   if (spare > 0) and (callIx >= 0) then
      begin
      ColWidths[callIx] := ColWidths[callIx] + spare;
      end;
end;

procedure TLogGrid.DoOnResize;
begin
   inherited DoOnResize;
   SizeColumns;
end;

procedure TLogGrid.Reload;
var
   i: integer;
begin
   for i := Low(FCache) to High(FCache) do
      begin
      FCache[i].Valid := False;
      FCache[i].Index := -1;
      end;
   Invalidate;
end;

function TLogGrid.Fetch(const aIndex: Int64): PLogGridCacheEntry;
var
   ok: boolean;
begin
   Result := @FCache[aIndex mod CACHE_ROWS];

   if Result^.Valid and (Result^.Index = aIndex) then
      begin
      Exit;
      end;

   Result^.Index   := aIndex;
   Result^.Valid   := False;
   Result^.Deleted := False;
   Result^.XQSO    := False;
   FillChar(Result^.Text, SizeOf(Result^.Text), 0);

   if not Assigned(FOnFetchRow) then
      begin
      Exit;
      end;

   ok := False;
   FOnFetchRow(Self, aIndex, Result^.Text, Result^.Deleted, Result^.XQSO, ok);
   Result^.Valid := ok;
end;

procedure TLogGrid.SetRecordCount(const aValue: Int64);
var
   n: Int64;
begin
   n := aValue;
   if n < 0 then
      begin
      n := 0;
      end;

   FRecordCount := n;
   Reload;

   (* One header row plus the records. RowCount is an integer, and a log that
     exceeded it would be a log of two billion QSOs. *)
   RowCount := 1 + integer(n);
end;

function TLogGrid.GetSelectedRecord: Int64;
begin
   Result := -1;
   if (FRecordCount <= 0) or (Row < FixedRows) then
      begin
      Exit;
      end;

   Result := Row - FixedRows;
   if Result >= FRecordCount then
      begin
      Result := -1;
      end;
end;

procedure TLogGrid.SetSelectedRecord(const aValue: Int64);
begin
   if (aValue < 0) or (aValue >= FRecordCount) then
      begin
      Exit;
      end;
   Row := FixedRows + integer(aValue);
end;

procedure TLogGrid.ScrollToEnd;
begin
   if FRecordCount <= 0 then
      begin
      Exit;
      end;
   Row := RowCount - 1;
end;

(* PAINTING ONE CELL.

  THE HEADER ROW IS DRAWN HERE TOO rather than by a fixed-cell style, so that
  its font and colours are the grid's own and it cannot end up looking like a
  Windows control on one machine and like the log on another.

  A DELETED QSO IS RED AND AN X-QSO IS GREY. Those two rules were in a
  custom-draw handler on each of the two list views; they are one rule now. *)
procedure TLogGrid.DrawCell(aCol, aRow: integer; aRect: TRect;
                            aState: TGridDrawState);
var
   e:     PLogGridCacheEntry;
   s:     string;
   c:     LogColumnsType;
   x:     integer;
   tw:    integer;
begin
   if (aCol < 0) or (aCol > High(FColumnOf)) then
      begin
      Exit;
      end;

   c := FColumnOf[aCol];

   Canvas.Font.Assign(Font);
   Canvas.Brush.Color := Color;
   Canvas.Font.Color  := Font.Color;

   if aRow < FixedRows then
      begin
      s := ColumnsArray[c].Text;
      Canvas.Brush.Color := tr4wColorsArray[trBtnFace];
      end
   else
      begin
      e := Fetch(aRow - FixedRows);
      if not e^.Valid then
         begin
         Canvas.FillRect(aRect);
         Exit;
         end;

      s := e^.Text[c];

      if e^.Deleted then
         begin
         Canvas.Font.Color := clRed;
         end
      else if e^.XQSO then
         begin
         Canvas.Font.Color := clGray;
         end;

      if gdSelected in aState then
         begin
         Canvas.Brush.Color := clHighlight;
         end;
      end;

   Canvas.FillRect(aRect);

   (* ALIGNMENT. ColumnsArray states it per column and the values are the
     Win32 LVCFMT_ constants, which are what the CFG files and the corpus
     references have always carried -- so they are read here as the numbers
     they are rather than renamed and migrated. *)
   tw := Canvas.TextWidth(s);
   case ColumnsArray[c].Align of
      LVCFMT_RIGHT:
         begin
         x := aRect.Right - tw - 2;
         end;
      LVCFMT_CENTER:
         begin
         x := aRect.Left + ((aRect.Right - aRect.Left) - tw) div 2;
         end;
      else
         begin
         x := aRect.Left + 2;
         end;
      end;

   if x < aRect.Left + 1 then
      begin
      x := aRect.Left + 1;
      end;

   Canvas.TextRect(aRect, x, aRect.Top + 1, s);
end;

end.
