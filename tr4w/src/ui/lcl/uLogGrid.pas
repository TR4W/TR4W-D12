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

      (* The first moment the columns can be measured -- see SizeColumns. *)
      procedure InitializeWnd; override;
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

   (* Breathing room either side of a cell's text. *)
   CELL_PAD = 3;

   (* No column narrower than this, whatever the table says -- a zero-width
     column is invisible and cannot be dragged back. *)
   MIN_COLUMN_WIDTH = 8;

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
   (* THE SAME HEIGHT THE REST OF THE WINDOW IS LAID OUT WITH.
     CheckEditableWindowHeight sizes this control as
     30 + LinesInEditableLog * (ws + 2), so a row is ws + 2 and the arithmetic
     on both sides of the layout agrees. *)
   DefaultRowHeight := ws + 2;

   Color      := tr4wColorsArray[trWhite];
   Font.Color := tr4wColorsArray[trBlack];

   (* THE FONT IS THE MAIN WINDOW'S, applied by the owner through
     MainUnit.ApplyMainFontTo -- the operator chooses it, and a log in a
     different typeface from the rest of the window is exactly what the first
     version of this looked like. *)
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

(* THE WIDTHS, AS THE ORIGINAL SET THEM.

  ColumnsArray[].Width IS A COUNT IN `ws` UNITS, NOT CHARACTERS AND NOT PIXELS.
  CreateEditableLog set each column to Width * ws -- ws being the main window's
  scale unit, WindowSize + 12 -- and that is the whole rule. There was no
  redistribution of leftover width.

  GETTING THIS WRONG IS WHAT MADE THE GRID LOOK NOTHING LIKE THE PROGRAM. The
  first version multiplied by the width of a character instead, which is a
  third of ws, so every column came out cramped; then it handed ALL the
  leftover width to the callsign column, which became about five hundred pixels
  with the callsign at its left edge. That is the empty channel down the middle
  of the window in NY4I's screenshot, and the reason Freq and Op were jammed
  together at the right.

  THREE CASES, and they are the original's, in order:

    1. The operator has dragged this column -- ColumnWidthOverride, in pixels.
       Their width wins over everything.
    2. ColumnAutoSize, for columns from logColNumberReceive rightwards: fit the
       header. LVSCW_AUTOSIZE_USEHEADER fits the wider of header and content,
       and a virtual grid has no content to measure, so it is the header text
       against the declared width.
    3. Otherwise Width * ws. *)
procedure TLogGrid.SizeColumns;
var
   i:      integer;
   c:      LogColumnsType;
   w:      integer;
   header: integer;
begin
   if Length(FColumnOf) = 0 then
      begin
      Exit;
      end;

   (* NOT BEFORE THERE IS A WINDOW TO MEASURE IN.

     Canvas on a control with no handle allocated raises, and this is reached
     from BuildColumns, which a form calls from its OnCreate -- before the form
     is shown and therefore before either has a handle. That is an access
     violation on opening View/Edit Log, which is what it did (NY4I,
     2026-09-04: "I also cannot open the view/edit log window").

     InitializeWnd calls this again the moment the handle exists, so nothing is
     lost by declining now. *)
   if not HandleAllocated then
      begin
      Exit;
      end;

   Canvas.Font.Assign(Font);

   for i := 0 to High(FColumnOf) do
      begin
      c := FColumnOf[i];

      if ColumnWidthOverride[c] > 0 then
         begin
         w := ColumnWidthOverride[c];
         end
      else
         begin
         w := ColumnsArray[c].Width * ws;

         if (c >= logColNumberReceive) and ColumnAutoSize then
            begin
            header := Canvas.TextWidth(ColumnsArray[c].Text) + CELL_PAD * 2;
            if header > w then
               begin
               w := header;
               end;
            end;
         end;

      if w < MIN_COLUMN_WIDTH then
         begin
         w := MIN_COLUMN_WIDTH;
         end;

      ColWidths[i] := w;
      end;
end;

procedure TLogGrid.DoOnResize;
begin
   inherited DoOnResize;
   SizeColumns;
end;

procedure TLogGrid.InitializeWnd;
begin
   inherited InitializeWnd;
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

  TRUNCATED WITH AN ELLIPSIS, which is what the list view did and what the
  program has always looked like: a date too wide for its column reads
  `03-09-...` and a frequency reads `14070...`. Clipping instead -- the first
  version of this -- ran neighbouring columns together, so `14070` and `NY4I`
  appeared as `14070NY4I` with no way to tell there were two values.

  A DELETED QSO IS RED AND AN X-QSO IS GREY. Those two rules were in a
  custom-draw handler on each of two list views; they are one rule now. *)
procedure TLogGrid.DrawCell(aCol, aRow: integer; aRect: TRect;
                            aState: TGridDrawState);
var
   e:     PLogGridCacheEntry;
   s:     string;
   c:     LogColumnsType;
   style: TTextStyle;
begin
   if (aCol < 0) or (aCol > High(FColumnOf)) then
      begin
      Exit;
      end;

   c := FColumnOf[aCol];

   Canvas.Font.Assign(Font);

   (* ALIGNMENT COMES FROM ColumnsArray as the Win32 LVCFMT_ constants it has
     always carried -- read as the numbers they are rather than renamed and
     migrated, because the CFG files and the corpus references carry them. *)
   FillChar(style, SizeOf(style), 0);
   style.SingleLine  := True;
   style.Layout      := tlCenter;
   style.EndEllipsis := True;
   style.Wordbreak   := False;
   style.Clipping    := True;
   style.Opaque      := False;

   case ColumnsArray[c].Align of
      LVCFMT_RIGHT:
         begin
         style.Alignment := taRightJustify;
         end;
      LVCFMT_CENTER:
         begin
         style.Alignment := taCenter;
         end;
      else
         begin
         style.Alignment := taLeftJustify;
         end;
      end;

   if aRow < FixedRows then
      begin
      (* THE HEADER, drawn by the LCL so it looks like every other header in
        the program -- the fixed colour and the frame -- with the caption over
        it. *)
      inherited DrawCell(aCol, aRow, aRect, aState);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color  := Font.Color;
      (* Plain arithmetic, not InflateRect -- that is a Win32 API and this
        unit names no platform. *)
      Inc(aRect.Left, CELL_PAD);
      Dec(aRect.Right, CELL_PAD);
      Canvas.TextRect(aRect, aRect.Left, aRect.Top, ColumnsArray[c].Text, style);
      Canvas.Brush.Style := bsSolid;
      Exit;
      end;

   Canvas.Brush.Color := Color;
   Canvas.Font.Color  := Font.Color;

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

   (* THE SELECTED ROW. clHighlight/clHighlightText rather than a colour from
     tr4wColorsArray, because that palette names COLOURS and has no role for a
     selection -- see docs/COLOR_ROLES_DESIGN.md. They are also the colours an
     operator's high-contrast theme changes. *)
   if gdSelected in aState then
      begin
      Canvas.Brush.Color := clHighlight;
      Canvas.Font.Color  := clHighlightText;
      end;

   Canvas.FillRect(aRect);

   Canvas.Brush.Style := bsClear;
   Inc(aRect.Left, CELL_PAD);
   Dec(aRect.Right, CELL_PAD);
   Canvas.TextRect(aRect, aRect.Left, aRect.Top, s, style);
   Canvas.Brush.Style := bsSolid;
end;

end.
