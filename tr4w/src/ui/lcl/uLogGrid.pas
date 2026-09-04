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
   LCLIntf, LCLType,   (* GetSystemMetrics / SM_CXVSCROLL -- the LCL's own,
                       not the Windows unit *)
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
   (* ONE ROW AS THE GRID HOLDS IT. *)
   TLogGridRow = record
      Text:    TLogRowText;
      Deleted: boolean;
      XQSO:    boolean;
      Valid:   boolean;
   end;

   (* HOW THE GRID GETS ITS ROWS -- A RUN OF THEM, NOT ONE.

     aFirstIndex is a RECORD index into the log, not a screen row; the grid
     does that arithmetic itself and the owner never sees a scroll position.
     Fill aRows for as many as exist, leaving Valid False for the rest.

     A RUN RATHER THAN A ROW because the store underneath is a database. Asked
     one row at a time it compiled three statements per row -- a row count, an
     O(n) OFFSET walk and a load -- which is what made a repaint expensive and
     made a cache look compulsory. *)
   TLogRowsFetchEvent = procedure(Sender: TObject;
                                  const aFirstIndex: Int64;
                                  var aRows: array of TLogGridRow) of object;

   TLogGridCacheEntry = record
      Index: Int64;
      Row:   TLogGridRow;
   end;
   PLogGridCacheEntry = ^TLogGridCacheEntry;

   (* HOW THE COLUMNS GET THEIR WIDTHS.

     lgsDeclared -- ColumnsArray[].Width * ws, which is what CreateEditableLog
       did and what the MAIN WINDOW log must keep: its widths are part of a
       layout an operator has been reading for years, and the window is sized
       to them rather than the other way round.

     lgsFitAndFill -- each column as narrow as its contents allow, then the
       leftover shared out so the grid fills the window. For a window the
       operator resizes, where declared widths leave a band of empty grid down
       the right-hand side (NY4I, 2026-09-04: "we do have the resize issue
       where the window does not scale. notice the white space").

     The DX cluster achieves the same END by scaling its FONT, because it is a
     monospace console of fixed column count. A grid has real columns, so it
     distributes those instead. *)
   TLogGridSizing = (lgsDeclared, lgsFitAndFill);

   TLogGrid = class(TDrawGrid)
   private
      FRecordCount: Int64;
      FOnFetchRows: TLogRowsFetchEvent;
      FSizing:      TLogGridSizing;

      (* WHAT THE OPERATOR TYPED, SHOWN WHERE IT MATCHED. Empty means no
        highlighting, which is every window except the search. *)
      FMatchText:      string;
      FMatchColumn:    LogColumnsType;
      FMatchColor:     TColor;
      FMatchTextColor: TColor;

      (* Re-entrancy guard. Writing ColWidths repaints, a repaint fetches, and
        a fetch may ask to be re-sized -- which would be unbounded. *)
      FSizingNow:   boolean;

      (* Set when the rows change, so a fit-and-fill grid measures the NEW
        contents once rather than on every paint. *)
      FNeedsFit:    boolean;
      FColumnOf:    array of LogColumnsType;
      FCache:       array of TLogGridCacheEntry;

      function  Fetch(const aIndex: Int64): PLogGridCacheEntry;
      procedure FillBatch(const aFirstIndex: Int64);
      procedure SizeColumnsAsDeclared;
      procedure SizeColumnsToFit;
      function  AnyRowCached: boolean;
      procedure SetRecordCount(const aValue: Int64);
      procedure SetMatchText(const aValue: string);
      procedure DrawMatchIn(const aRect: TRect; const aText: string;
                            aTextLeft: integer);
      function  GetSelectedRecord: Int64;
      procedure SetSelectedRecord(const aValue: Int64);
   protected
      procedure DrawCell(aCol, aRow: integer; aRect: TRect;
                         aState: TGridDrawState); override;
      procedure DoOnResize; override;

      (* The first moment the columns can be measured -- see SizeColumns. *)
      procedure InitializeWnd; override;

      (* Double-clicking a column divider fits the column to its contents --
        see the body. *)
      procedure AutoAdjustColumn(aCol: integer); override;
   public
      constructor Create(aOwner: TComponent); override;

      (* Rebuild the visible columns from ColumnsArray and distribute the
        width. Call after a contest changes which columns are enabled. *)
      procedure BuildColumns;

      (* Share the width out among the visible columns -- see the body. *)
      procedure SizeColumns;

      (* THE NARROWEST THE GRID CAN BE AND STILL SHOW EVERY COLUMN.

        For a form to refuse to be resized below it. Without this an operator
        drags the window narrow and columns simply fall off the right-hand edge
        with nothing to say they exist -- NY4I, 2026-09-04: "i should not be
        able to resize smaller than a form that shows all the columns."

        Measured the same way lgsFitAndFill measures, so the two agree by
        construction rather than by both being kept up to date. *)
      function MinimumWidth: integer;

      (* Forget every cached row and repaint. The log changed under us. *)
      procedure Reload;

      (* Put the newest QSO in view, which is where an operator looks. *)
      procedure ScrollToEnd;

      (* The record index under the current row, or -1 if the grid is on its
        header or empty. This is the only place row->record is computed. *)
      property SelectedRecord: Int64 read GetSelectedRecord write SetSelectedRecord;

      (* How many log records exist. Setting it is what makes the log appear. *)
      property RecordCount: Int64 read FRecordCount write SetRecordCount;

      property OnFetchRows: TLogRowsFetchEvent read FOnFetchRows write FOnFetchRows;

      (* Declared widths, or fitted to the contents and stretched to the
        window. See TLogGridSizing. *)
      property Sizing: TLogGridSizing read FSizing write FSizing;

      (* THE TYPED TEXT, HIGHLIGHTED WHERE IT MATCHED -- searching for "TV"
        marks the TV in N6TV (NY4I, 2026-09-04).

        Case-insensitive, and only in MatchColumn: a callsign search that lit
        up matching characters in the date or the frequency would be noise.
        Set MatchText to '' to turn it off, which is the default. *)
      property MatchText: string read FMatchText write SetMatchText;
      property MatchColumn: LogColumnsType read FMatchColumn write FMatchColumn;

      (* Definable, because legibility depends on the operator's colours. The
        default is the find-in-page convention -- black on yellow -- which
        reads on the white row background AND on the selection blue, where a
        change of TEXT colour alone would not. *)
      property MatchColor: TColor read FMatchColor write FMatchColor;
      property MatchTextColor: TColor read FMatchTextColor write FMatchTextColor;
   end;

implementation

const
   (* A DIRECT-MAPPED CACHE, sized to comfortably exceed a screenful so that
     scrolling never evicts a row it is about to ask for again. Direct-mapped
     rather than an LRU because the access pattern is a contiguous window --
     index mod N collides only between rows N apart, which are never on screen
     together. *)
   (* WHY A CACHE AT ALL, with a number attached -- section 9a asks for exactly
     that and the first version of this file did not have one.

     DrawCell is called PER CELL. A log row is fourteen columns, so painting one
     row asks for it fourteen times; without somewhere to put the answer that is
     fourteen fetches for one row, and it stays fourteen however cheap the fetch
     becomes. That is a property of the control, not a performance guess.

     512 entries, direct-mapped: index mod N collides only between rows N apart,
     which are never on screen together. *)
   CACHE_ROWS = 512;

   (* HOW MANY ROWS ONE FETCH ASKS FOR. A screenful is a handful, but the fetch
     costs an OFFSET walk to reach its first row whatever its size, so a batch
     amortises that over the rows that follow -- and scrolling asks for the next
     ones anyway. *)
   BATCH_ROWS = 64;

   (* Breathing room after an auto-fit, so the widest value does not sit hard
     against the divider. The Win32 original used 12 for the same reason. *)
   DIVIDER_DBLCLICK_PAD = 12;

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
   (* goDblClickAutoSize: double-clicking a divider fits the column -- see
     AutoAdjustColumn. *)
   Options := [goRowSelect, goThumbTracking, goColSizing, goDblClickAutoSize,
               goVertLine, goHorzLine];

   FSizing    := lgsDeclared;

   FMatchText      := '';
   FMatchColumn    := logColCallsign;
   FMatchColor     := $0080FFFF;   (* BGR: a soft yellow *)
   FMatchTextColor := clBlack;
   FNeedsFit  := True;

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
begin
   if Length(FColumnOf) = 0 then
      begin
      Exit;
      end;

   (* NOT BEFORE THERE IS A WINDOW TO MEASURE IN.

     Canvas on a control with no handle allocated raises, and this is reached
     from BuildColumns, which a form calls from its OnCreate -- before the form
     is shown and therefore before either has a handle. That is an access
     violation on opening a window, which is what it did (NY4I, 2026-09-04:
     "I also cannot open the view/edit log window").

     InitializeWnd calls this again the moment the handle exists, so nothing is
     lost by declining now. *)
   if not HandleAllocated then
      begin
      Exit;
      end;

   if FSizingNow then
      begin
      Exit;
      end;

   FSizingNow := True;
   try
      case FSizing of
         lgsFitAndFill:
            begin
            SizeColumnsToFit;
            end;
         else
            begin
            SizeColumnsAsDeclared;
            end;
         end;
   finally
      FSizingNow := False;
   end;
end;

(* THE WIDTHS AS THE ORIGINAL SET THEM.

  ColumnsArray[].Width IS A COUNT IN `ws` UNITS, NOT CHARACTERS AND NOT PIXELS.
  CreateEditableLog set each column to Width * ws -- ws being the main window's
  scale unit, WindowSize + 12 -- and that is the whole rule. There was no
  redistribution of leftover width.

  GETTING THIS WRONG IS WHAT MADE THE GRID LOOK NOTHING LIKE THE PROGRAM. The
  first version multiplied by the width of a character instead, which is a
  third of ws, so every column came out cramped; then it handed ALL the
  leftover width to the callsign column, which became about five hundred pixels
  with the callsign at its left edge -- an empty channel down the middle of the
  window, with Freq and Op jammed together at the right.

  THREE CASES, and they are the original's, in order:

    1. The operator has dragged this column -- ColumnWidthOverride, in pixels.
       Their width wins over everything.
    2. ColumnAutoSize, for columns from logColNumberReceive rightwards: fit the
       header. LVSCW_AUTOSIZE_USEHEADER fits the wider of header and content,
       and a virtual grid has no content to measure, so it is the header text
       against the declared width.
    3. Otherwise Width * ws. *)
procedure TLogGrid.SizeColumnsAsDeclared;
var
   i:      integer;
   c:      LogColumnsType;
   w:      integer;
   header: integer;
begin
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

(* AS NARROW AS THE CONTENTS ALLOW, THEN STRETCHED TO FILL THE WINDOW.

  For a window the operator resizes. Declared widths do not grow with it, so a
  wide window showed a band of grid with nothing in it down the right-hand
  side, and the selected row's highlight stopped in the middle of the window.

  MEASURED FROM THE ROWS THE GRID HAS, which for a search is all of them and
  for a long log is the cached window. The first batch is fetched here if the
  cache is empty, because sizing before any row exists would fit every column
  to its heading and never revisit it.

  THE SURPLUS IS SHARED IN PROPORTION to what each column asked for, so the
  callsign grows more than the zone. Handing it all to one column is what the
  main log did wrong.

  A DEFICIT IS LEFT ALONE: if the contents genuinely need more room than the
  window has, the columns keep their widths and the grid scrolls, rather than
  squeezing every column until nothing is readable. *)
procedure TLogGrid.SizeColumnsToFit;
var
   i, k:   integer;
   c:      LogColumnsType;
   w:      integer;
   want:   array of integer;
   total:  integer;
   spare:  integer;
   given:  integer;
   avail:  integer;
begin
   if (FRecordCount > 0) and (not AnyRowCached) then
      begin
      FillBatch(0);
      end;

   Canvas.Font.Assign(Font);
   SetLength(want, Length(FColumnOf));
   total := 0;

   for i := 0 to High(FColumnOf) do
      begin
      c := FColumnOf[i];

      (* The heading is a floor: a column narrower than its own name is
        unreadable however short its values are. *)
      w := Canvas.TextWidth(ColumnsArray[c].Text);

      for k := Low(FCache) to High(FCache) do
         begin
         if not FCache[k].Row.Valid then
            begin
            Continue;
            end;
         if Canvas.TextWidth(FCache[k].Row.Text[c]) > w then
            begin
            w := Canvas.TextWidth(FCache[k].Row.Text[c]);
            end;
         end;

      Inc(w, CELL_PAD * 2);
      if w < MIN_COLUMN_WIDTH then
         begin
         w := MIN_COLUMN_WIDTH;
         end;

      want[i] := w;
      Inc(total, w);
      end;

   (* Less the grid lines, and room for a vertical scrollbar so a full-width
     fit does not provoke a horizontal one. *)
   avail := ClientWidth - Length(FColumnOf) - 2;
   spare := avail - total;

   if (spare > 0) and (total > 0) then
      begin
      given := 0;
      for i := 0 to High(FColumnOf) do
         begin
         if i = High(FColumnOf) then
            begin
            (* THE LAST COLUMN TAKES THE REMAINDER, so integer division cannot
              leave a few pixels of blank grid -- which is the whole complaint
              this routine exists to answer. *)
            Inc(want[i], spare - given);
            end
         else
            begin
            k := (spare * want[i]) div total;
            Inc(want[i], k);
            Inc(given, k);
            end;
         end;
      end;

   for i := 0 to High(FColumnOf) do
      begin
      ColWidths[i] := want[i];
      end;
end;

procedure TLogGrid.SetMatchText(const aValue: string);
begin
   if FMatchText = aValue then
      begin
      Exit;
      end;

   FMatchText := aValue;
   Invalidate;
end;

(* THE MATCHED RUN, PAINTED OVER THE TEXT THAT IS ALREADY THERE.

  Drawn as a background swatch rather than a change of text colour, because the
  row underneath may already be red (deleted), grey (X-QSO) or drawn on the
  selection blue -- a fourth text colour would be illegible against at least
  one of them, and invisible against another.

  ONLY WHEN THE WHOLE VALUE FITS. If the text is ellipsised the run may be
  partly or wholly cut, and there is no honest place to put the swatch; leaving
  it off is better than marking the wrong characters.

  LEFT-ALIGNED COLUMNS ONLY, for the same reason -- the prefix width IS the
  offset when text starts at the left edge, and is not when it is centred or
  right-aligned. The callsign, which is what this is for, is left-aligned. *)
procedure TLogGrid.DrawMatchIn(const aRect: TRect; const aText: string;
                               aTextLeft: integer);
var
   at:     integer;
   x0, x1: integer;
   run:    string;
begin
   if (FMatchText = '') or (aText = '') then
      begin
      Exit;
      end;

   at := Pos(UpperCase(FMatchText), UpperCase(aText));
   if at <= 0 then
      begin
      Exit;
      end;

   if Canvas.TextWidth(aText) > (aRect.Right - aRect.Left) then
      begin
      Exit;
      end;

   run := Copy(aText, at, Length(FMatchText));
   x0  := aTextLeft + Canvas.TextWidth(Copy(aText, 1, at - 1));
   x1  := x0 + Canvas.TextWidth(run);

   if x1 > aRect.Right then
      begin
      Exit;
      end;

   Canvas.Brush.Color := FMatchColor;
   Canvas.Brush.Style := bsSolid;
   Canvas.FillRect(Rect(x0, aRect.Top + 1, x1, aRect.Bottom - 1));

   Canvas.Brush.Style := bsClear;
   Canvas.Font.Color  := FMatchTextColor;
   Canvas.TextOut(x0, aRect.Top + ((aRect.Bottom - aRect.Top) -
                                   Canvas.TextHeight(run)) div 2, run);
end;

function TLogGrid.MinimumWidth: integer;
var
   i, k:   integer;
   c:      LogColumnsType;
   w:      integer;
begin
   Result := 0;
   if (Length(FColumnOf) = 0) or (not HandleAllocated) then
      begin
      Exit;
      end;

   Canvas.Font.Assign(Font);

   for i := 0 to High(FColumnOf) do
      begin
      c := FColumnOf[i];

      if FSizing = lgsDeclared then
         begin
         (* The declared width IS the requirement: those columns do not shrink
           to their contents. *)
         w := ColumnsArray[c].Width * ws;
         end
      else
         begin
         w := Canvas.TextWidth(ColumnsArray[c].Text);
         for k := Low(FCache) to High(FCache) do
            begin
            if FCache[k].Row.Valid and
               (Canvas.TextWidth(FCache[k].Row.Text[c]) > w) then
               begin
               w := Canvas.TextWidth(FCache[k].Row.Text[c]);
               end;
            end;
         Inc(w, CELL_PAD * 2);
         end;

      if w < MIN_COLUMN_WIDTH then
         begin
         w := MIN_COLUMN_WIDTH;
         end;

      Inc(Result, w);
      end;

   (* The grid lines between columns, and room for a vertical scrollbar so the
     narrowest allowed width does not itself provoke a horizontal one. *)
   Inc(Result, Length(FColumnOf) + GetSystemMetrics(SM_CXVSCROLL) + 2);
end;

function TLogGrid.AnyRowCached: boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(FCache) to High(FCache) do
      begin
      if FCache[i].Row.Valid then
         begin
         Result := True;
         Exit;
         end;
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

(* DOUBLE-CLICK ON A COLUMN DIVIDER FITS THE COLUMN TO WHAT IS IN IT.

  goDblClickAutoSize brings the LCL as far as calling this; the base does
  nothing, because a TDrawGrid holds no text to measure. The text is in the row
  cache, so this measures that.

  THE ROWS IT CAN SEE, WHICH IS NOT EVERY ROW, and the distinction is worth
  stating rather than pretending. The grid is virtual: only the cached rows
  exist in memory, so a column is fitted to the widest value among those and
  its own heading. Measuring the whole log would mean reading every record --
  a contest log is tens of thousands -- to answer a double-click.

  That is also what the Win32 original did without saying so:
  LVSCW_AUTOSIZE_USEHEADER measured the items the list view HELD, and it held
  only the tail of the log.

  The width is saved: HeaderSized raises OnHeaderSized, the same path a dragged
  divider takes, so the operator's choice persists either way. *)
procedure TLogGrid.AutoAdjustColumn(aCol: integer);
var
   i:     integer;
   c:     LogColumnsType;
   w:     integer;
   widest: integer;
begin
   if (aCol < 0) or (aCol > High(FColumnOf)) then
      begin
      Exit;
      end;

   if not HandleAllocated then
      begin
      Exit;
      end;

   c := FColumnOf[aCol];
   Canvas.Font.Assign(Font);

   widest := Canvas.TextWidth(ColumnsArray[c].Text);

   for i := Low(FCache) to High(FCache) do
      begin
      if not FCache[i].Row.Valid then
         begin
         Continue;
         end;

      w := Canvas.TextWidth(FCache[i].Row.Text[c]);
      if w > widest then
         begin
         widest := w;
         end;
      end;

   widest := widest + CELL_PAD * 2 + DIVIDER_DBLCLICK_PAD;
   if widest < MIN_COLUMN_WIDTH then
      begin
      widest := MIN_COLUMN_WIDTH;
      end;

   ColWidths[aCol] := widest;

   (* PERSISTED, through the same event a dragged divider raises. The Win32
     version had a defect here worth not repeating: it deferred the save to a
     follow-up HDN_ENDTRACK, which the OS does not send for a double-click, so
     the width was fitted and never saved. *)
   HeaderSized(True, aCol);
end;

procedure TLogGrid.Reload;
var
   i: integer;
begin
   for i := Low(FCache) to High(FCache) do
      begin
      FCache[i].Row.Valid := False;
      FCache[i].Index     := -1;
      end;
   Invalidate;
end;

(* THE ROW AT aIndex, FETCHING A BATCH AROUND IT ON A MISS.

  The batch starts on a BATCH_ROWS boundary rather than at aIndex, so scrolling
  through the log asks for each batch once instead of shifting the window by a
  row at a time and re-fetching almost the same rows. *)
function TLogGrid.Fetch(const aIndex: Int64): PLogGridCacheEntry;
begin
   Result := @FCache[aIndex mod CACHE_ROWS];

   if Result^.Row.Valid and (Result^.Index = aIndex) then
      begin
      Exit;
      end;

   FillBatch((aIndex div BATCH_ROWS) * BATCH_ROWS);

   Result := @FCache[aIndex mod CACHE_ROWS];
   if Result^.Index <> aIndex then
      begin
      (* The batch did not reach it -- past the end of the log, or evicted by a
        collision within the batch itself, which cannot happen while
        BATCH_ROWS <= CACHE_ROWS. *)
      Result^.Index      := aIndex;
      Result^.Row.Valid  := False;
      end;
end;

procedure TLogGrid.FillBatch(const aFirstIndex: Int64);
var
   rows: array[0 .. BATCH_ROWS - 1] of TLogGridRow;
   i:    integer;
   e:    PLogGridCacheEntry;
   idx:  Int64;
begin
   for i := Low(rows) to High(rows) do
      begin
      rows[i].Valid   := False;
      rows[i].Deleted := False;
      rows[i].XQSO    := False;
      FillChar(rows[i].Text, SizeOf(rows[i].Text), 0);
      end;

   if Assigned(FOnFetchRows) then
      begin
      FOnFetchRows(Self, aFirstIndex, rows);
      end;

   for i := Low(rows) to High(rows) do
      begin
      idx := aFirstIndex + i;
      if idx >= FRecordCount then
         begin
         Break;
         end;

      e := @FCache[idx mod CACHE_ROWS];
      e^.Index := idx;
      e^.Row   := rows[i];
      end;

   (* NOW THAT THERE IS SOMETHING TO MEASURE. Once per change of contents, not
     per batch -- and SizeColumns guards its own re-entry, because writing a
     column width repaints and a repaint fetches. *)
   if FNeedsFit and (FSizing = lgsFitAndFill) then
      begin
      FNeedsFit := False;
      SizeColumns;
      end;
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
   FNeedsFit    := True;
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

(* THE NEWEST QSO IN VIEW -- WHICH MEANS MOVING THE VIEWPORT, NOT THE
  SELECTION.

  Setting Row moves the SELECTED row. On a grid that does not have focus that
  does not necessarily bring the row into view, so the last line of this used
  to be all there was and the log looked frozen: the count grew, the rows were
  correct, and the operator went on looking at the same eight rows near the top
  while every new contact landed below the bottom edge (NY4I, 2026-09-04).

  IT PASSED A UI TEST ANYWAY, and that is the part worth remembering. The
  harness logged into an EMPTY log, so two records both fitted on screen and
  nothing ever had to scroll. A test that cannot reach the state the defect
  lives in reports PASS with complete confidence. *)
procedure TLogGrid.ScrollToEnd;
var
   last: integer;
   top:  integer;
begin
   if FRecordCount <= 0 then
      begin
      Exit;
      end;

   last := RowCount - 1;
   Row  := last;

   top := last - VisibleRowCount + 1;
   if top < FixedRows then
      begin
      top := FixedRows;
      end;
   TopRow := top;
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
   if not e^.Row.Valid then
      begin
      Canvas.FillRect(aRect);
      Exit;
      end;

   s := e^.Row.Text[c];

   if e^.Row.Deleted then
      begin
      Canvas.Font.Color := clRed;
      end
   else if e^.Row.XQSO then
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

   if (c = FMatchColumn) and (ColumnsArray[c].Align = LVCFMT_LEFT) then
      begin
      DrawMatchIn(aRect, s, aRect.Left);
      end;

   Canvas.Brush.Style := bsSolid;
end;

end.
