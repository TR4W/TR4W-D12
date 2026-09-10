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
      FPaintCount:  integer;
      FPaintClient: integer;
      FPaintRowH:   integer;
      FPaintRows:   integer;
      FPaintGrid:   integer;
      FPaintDrawn:  integer;
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

      (* WAS THE NEWEST QSO IN VIEW WHEN THE RESIZE STARTED -- see DoSetBounds.
        Captured against the OLD size, because by the time DoOnResize runs the
        question can no longer be asked. *)
      FWasAtEnd:    boolean;
      FColumnOf:    array of LogColumnsType;
      FCache:       array of TLogGridCacheEntry;

      function  Fetch(const aIndex: Int64): PLogGridCacheEntry;
      procedure FillBatch(const aFirstIndex: Int64);
      procedure SizeColumnsAsDeclared;
      procedure SizeColumnsToFit;
      function  AnyRowCached: boolean;
      function  AtEnd: boolean;
      procedure SetRecordCount(const aValue: Int64);
      procedure SetMatchText(const aValue: string);
      procedure DrawMatchIn(const aRect: TRect; const aText: string;
                            aTextLeft: integer);
      function  GetSelectedRecord: Int64;
      procedure SetSelectedRecord(const aValue: Int64);
   protected
      (* Fills the strip below the last row. See the body. *)
      procedure Paint; override;
      (* Tells the widget set the horizontal bar is off, which the LCL
        never does by itself. See the body. *)
      procedure CreateWnd; override;
      procedure DrawCell(aCol, aRow: integer; aRect: TRect;
                         aState: TGridDrawState); override;
      procedure DoOnResize; override;

      (* The last moment the OLD geometry is still true -- see the body. *)
      procedure DoSetBounds(aLeft, aTop, aWidth, aHeight: integer); override;

      (* The first moment the columns can be measured -- see SizeColumns. *)
      procedure InitializeWnd; override;

      (* Double-clicking a column divider fits the column to its contents --
        see the body. *)
      procedure AutoAdjustColumn(aCol: integer); override;
   public
      (* What the last Paint measured. See Paint. *)
      property PaintCount:  integer read FPaintCount;
      property PaintClient: integer read FPaintClient;
      property PaintRowH:   integer read FPaintRowH;
      property PaintRows:   integer read FPaintRows;
      property PaintGrid:   integer read FPaintGrid;
      property PaintDrawn:  integer read FPaintDrawn;
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

(* THE STRIP BELOW THE LAST ROW IS OURS TO PAINT.

  A grid draws whole rows. When its height is not a multiple of the row height
  the remainder belongs to no row, and the LCL leaves it alone -- so the widget
  set's own background shows through. On Win32 that is close enough to the
  grid's white to pass unnoticed; gtk2 paints a themed, recessed grey, which is
  indistinguishable from a scroll-bar trough.

  NY4I reported it six times across two days, as a horizontal scroll bar with a
  thumb, and I named the wrong control three times before measuring. The bounds
  dump put the grid at T=119 H=125 and the status panels at T=244 -- meeting
  exactly, which left nowhere else for the band to be. The arithmetic finished
  it: 125 is six rows of 19 plus ELEVEN PIXELS.

  WHY NOT ROUND THE HEIGHT INSTEAD. That was tried first and it is the wrong
  layer. This grid is anchored [akLeft, akTop, akRight, akBottom], so the LCL
  stretches it whenever the form is restored to a saved size, without passing
  through any setter -- a height fixed at creation is undone by the first
  resize. And a machine with no saved window position never sees that happen,
  which is precisely how the snap came to look like a fix from here while
  NY4I still had the band.

  CheckEditableWindowHeight had already settled the principle: "The list
  scrolls now, so there is no reason to make a whole number of rows fit." A
  fractional height is fine. An unpainted remainder is not.

  GridHeight is the LCL's own sum of the row heights, so this asks the control
  what it drew rather than recomputing it -- there is no second arithmetic here
  to disagree with the first. *)
procedure TLogGrid.Paint;
var
   rest:  TRect;
   drawn: integer;
begin
   inherited Paint;

   if DefaultRowHeight <= 0 then
      begin
      Exit;
      end;

   (* HOW FAR DOWN THE GRID ACTUALLY DREW, WHICH IS NOT GridHeight.

     THE FIRST VERSION OF THIS USED GridHeight AND FIXED NOTHING FOR AN
     OPERATOR, because GridHeight is the sum of ALL rows -- and the moment the
     log holds more QSOs than fit, that is LARGER than the client. The guard
     `if GridHeight >= ClientHeight then Exit` then skipped the fill in exactly
     the case every real contest is in.

     It looked right here because a fresh contest has no QSOs: GridHeight was
     one header row, smaller than the client, the fill ran, and the strip went.
     NY4I's log had fifteen. Same defect as the snap before it -- a fix
     validated on the one state that does not exhibit the problem.

     THE GRID DRAWS WHOLE ROWS AND STOPS. So the painted extent is the largest
     multiple of the row height that fits, capped by however many rows exist.
     Both terms are needed: the first covers a scrolling log, the second an
     almost-empty one. *)
   drawn := (ClientHeight div DefaultRowHeight) * DefaultRowHeight;
   if GridHeight < drawn then
      begin
      drawn := GridHeight;
      end;

   (* RECORDED FOR WHOEVER LOGS, RATHER THAN LOGGED FROM HERE.

     Two sources have disagreed about this control for two days: the bounds
     dump says the grid and the status panels meet exactly, and a magnified
     screen capture shows a band between them. The numbers this routine
     actually sees will say which is wrong -- including whether it runs at all,
     which nothing so far has established.

     THIS UNIT HAS NO LOGGER AND IS NOT GETTING ONE for a probe. It publishes
     what it saw; uMainForm's child dump prints it, which is also the only
     place that already knows how to reach this control. *)
   Inc(FPaintCount);
   FPaintClient := ClientHeight;
   FPaintRowH   := DefaultRowHeight;
   FPaintRows   := RowCount;
   FPaintGrid   := GridHeight;
   FPaintDrawn  := drawn;

   if drawn >= ClientHeight then
      begin
      Exit;
      end;

   rest := Rect(0, drawn, ClientWidth, ClientHeight);
   Canvas.Brush.Color := Color;
   Canvas.Brush.Style := bsSolid;
   Canvas.FillRect(rest);
end;

(* SAY IT OUT LOUD: THERE IS NO HORIZONTAL SCROLL BAR.

  NY4I, 2026-09-10: "can we fix the implementation in Laz on linux to
  accurately set the horzscrollbar to false (as opposed to your just checking
  it)?" Yes, and this is that -- and his scepticism about my last explanation
  was better founded than my explanation was. A gap between two controls does
  not have a thumb in it.

  THE LCL NEVER TELLS THE WIDGET SET. TCustomGrid.UpdateHorzScrollBar is the
  only thing that would, and it is guarded:

      NeedUpdate := FHSbVisible <> Ord(AVisible);
      if NeedUpdate then ScrollBarShow(SB_HORZ, aVisible);

  FHSbVisible starts at 0, and for ssAutoVertical GetSBVisibility computes
  HsbVisible = False. They agree, so ScrollBarShow is NEVER CALLED, and
  whatever state the widget set created the control in is what the operator
  gets. On Win32 that is nothing; the LCL's own belief and the screen happen to
  match. On gtk2 they need not, and nothing in the LCL ever reconciles them.

  ScrollBarIsVisible does not help either -- it reads the same cache
  (grids.pas:3531), with a comment explaining that asking the widget set
  directly is unsafe on Gtk2. So the LCL cannot even see the disagreement.

  CreateWnd IS THE RIGHT MOMENT: the handle exists, so the call reaches the
  widget set, and it runs again if the handle is ever recreated. ScrollBarShow
  is TCustomGrid's own protected method, so this is the LCL's API rather than a
  raw platform call -- which is what CLAUDE.md asks for.

  IF THIS IS NOT THE BAND, IT IS STILL CORRECT. Stating a property the program
  actually holds, rather than assuming a default, is right whatever it turns
  out to fix. *)
procedure TLogGrid.CreateWnd;
begin
   inherited CreateWnd;

   if HandleAllocated then
      begin
      ScrollBarShow(SB_HORZ, False);
      end;
end;

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

   (* A GRID NOBODY HAS SCROLLED YET IS FOLLOWING THE LOG. Left False, the
     first resize after startup would be the one resize that does not keep
     the newest QSO in view. *)
   FWasAtEnd  := True;

   FMatchText      := '';
   FMatchColumn    := logColCallsign;
   FMatchColor     := $0080FFFF;   (* BGR: a soft yellow *)
   FMatchTextColor := clBlack;
   FNeedsFit  := True;

   FixedCols     := 0;
   FixedRows     := 1;
   ColCount      := 1;
   RowCount      := 1;
   (* ssVertical, NOT ssAutoVertical.

     THE BAND UNDER THE LAST ROW IS A REAL HORIZONTAL SCROLL BAR WITH A THUMB.
     Seen at last by capturing NY4I's actual screen with xwd and cropping the
     window: a grey trough with a lighter thumb at the left, full width,
     immediately below the last QSO. Seven reports, and every earlier answer of
     mine was reasoning rather than looking.

     WHY AN AUTO STYLE DOES NOT SUPPRESS IT. TCustomGrid.GetSBVisibility does
     compute HsbVisible := False for ssAutoVertical -- I checked that, and it
     is true, and it is not enough. UpdateHorzScrollBar only calls
     ScrollBarShow when its cached FHSbVisible DISAGREES with the new value:

         NeedUpdate := FHSbVisible <> Ord(AVisible);
         if NeedUpdate then ScrollBarShow(SB_HORZ, aVisible);

     FHSbVisible starts at 0 and the computed value is also False, so they
     agree, so ScrollBarShow is NEVER CALLED -- and whatever the widget set
     created the control with stays. On Win32 that is nothing. On gtk2 it is a
     visible bar.

     THE CACHE IS THE BUG, AND IT IS NOT OURS TO FIX. Naming the vertical bar
     explicitly takes the horizontal one out of that machinery altogether. A
     log that scrolls always wants its vertical bar, so a permanent one costs
     nothing. *)
   ScrollBars    := ssVertical;
   BorderStyle   := bsSingle;
   (* THE SAME HEIGHT THE REST OF THE WINDOW IS LAID OUT WITH.
     CheckEditableWindowHeight sizes this control as
     30 + LinesInEditableLog * (ws + 2), so a row is ws + 2 and the arithmetic
     on both sides of the layout agrees. *)
   DefaultRowHeight := ws + 2;

   Color      := tr4wColorsArray[trWhite];
   Font.Color := tr4wColorsArray[trBlack];

   (* A TINT, NOT A SYSTEM COLOUR. It has to say "this row is current" while
     remaining obviously part of the log, and it has to do that against black,
     red (deleted) and grey (X-QSO) text, which is why the row keeps its own
     font colour and only the background moves.

     NOT clHighlight and NOT clBtnFace. The first is a saturated selection
     colour meant for a control with the keyboard, and this one never has it;
     the second is window chrome and produced a bar that read as a scroll-bar
     trough on gtk2. A fixed light blue is neither, on any theme.

     FadeUnfocusedSelection OFF so the LCL leaves the choice alone: its own
     unfocused path substitutes clBtnFace, which is the colour this is
     avoiding. *)
   SelectedColor           := $00FFDEC5;   (* BGR: a pale blue *)
   FadeUnfocusedSelection  := False;

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
   fixed:  array of boolean;
   total:  integer;
   share:  integer;
   spare:  integer;
   given:  integer;
   avail:  integer;
   last:   integer;
begin
   if (FRecordCount > 0) and (not AnyRowCached) then
      begin
      FillBatch(0);
      end;

   Canvas.Font.Assign(Font);
   SetLength(want, Length(FColumnOf));
   SetLength(fixed, Length(FColumnOf));
   total := 0;
   share := 0;
   last  := -1;

   for i := 0 to High(FColumnOf) do
      begin
      c := FColumnOf[i];

      (* A WIDTH THE OPERATOR DRAGGED IS NOT A SUGGESTION. It wins, and it is
        excluded from the surplus below -- otherwise the column they sized by
        hand would be stretched away from the width they chose the moment the
        window got wider. *)
      if ColumnWidthOverride[c] > 0 then
         begin
         want[i]  := ColumnWidthOverride[c];
         fixed[i] := True;
         Inc(total, want[i]);
         Continue;
         end;

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

      want[i]  := w;
      fixed[i] := False;
      Inc(total, w);
      Inc(share, w);
      last := i;
      end;

   (* Less the grid lines, and room for a vertical scrollbar so a full-width
     fit does not provoke a horizontal one. *)
   avail := ClientWidth - Length(FColumnOf) - 2;
   spare := avail - total;

   if (spare > 0) and (share > 0) then
      begin
      given := 0;
      for i := 0 to High(FColumnOf) do
         begin
         if fixed[i] then
            begin
            Continue;
            end;

         if i = last then
            begin
            (* THE LAST FREE COLUMN TAKES THE REMAINDER, so integer division
              cannot leave a few pixels of blank grid -- which is the whole
              complaint this routine exists to answer. *)
            Inc(want[i], spare - given);
            end
         else
            begin
            k := (spare * want[i]) div share;
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

(* IS THE NEWEST QSO IN VIEW?

  MaxTopLeft.y is the grid's own answer to "as far down as this scrolls" (see
  ScrollToEnd), so being at or past it is what "at the bottom" means. When the
  whole log fits, MaxTopLeft.y is FixedRows and the answer is always yes --
  which is right: a short log is entirely on screen and cannot be behind. *)
function TLogGrid.AtEnd: boolean;
begin
   Result := (FRecordCount <= 0) or (TopRow >= GCache.MaxTopLeft.y);
end;

(* THE LAST MOMENT THE OLD GEOMETRY IS STILL TRUE.

  DoOnResize needs to know whether the operator was looking at the newest QSO
  BEFORE the window changed size, and by then the grid has already been
  re-measured and the question cannot be answered. ChangeBounds calls this
  first and Resize afterwards, so this is where it is asked. *)
procedure TLogGrid.DoSetBounds(aLeft, aTop, aWidth, aHeight: integer);
begin
   FWasAtEnd := AtEnd;
   inherited DoSetBounds(aLeft, aTop, aWidth, aHeight);
end;

(* A RESIZE KEEPS THE NEWEST QSO IN VIEW -- BUT ONLY IF IT ALREADY WAS.

  Growing the window adds room BELOW the rows on screen, so without this the
  operator gets a band of empty grid under the last QSO and has to scroll to
  see what they just worked; shrinking it hides the newest contacts behind the
  bottom edge, which is worse (NY4I, 2026-09-08).

  CONDITIONAL, THOUGH. An operator scrolled back through the log to read an
  earlier contact, who then drags the window edge, must not be thrown to the
  end -- they would lose their place for a reason that has nothing to do with
  what they were doing. Following the log is the behaviour of a view that was
  ALREADY following it.

  AFTER SizeColumns, DELIBERATELY: re-fitting the columns can add or remove the
  horizontal scrollbar, which changes how much height the rows have to sit in.
  Scrolling first would aim at the wrong bottom. *)
procedure TLogGrid.DoOnResize;
begin
   inherited DoOnResize;
   SizeColumns;

   if FWasAtEnd then
      begin
      ScrollToEnd;
      end;
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

   (* PERSISTED, BUT NOT FROM HERE. TCustomGrid.DblClick calls HeaderSized
     itself when this changes a width (grids.pas:7217-7222), so raising it
     again would save the same width twice -- and the second write is the one
     that would look like a defect later, because nothing here would say why.

     The Win32 version had the opposite bug and it is worth not repeating: it
     deferred the save to a follow-up HDN_ENDTRACK, which Windows does not send
     for a double-click, so the column was fitted and the width silently never
     stored. *)
   ColWidths[aCol] := widest;
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
begin
   if FRecordCount <= 0 then
      begin
      Exit;
      end;

   last := RowCount - 1;
   Row  := last;

   (* ASK FOR THE LAST ROW AND LET THE GRID CLAMP, WHICH IS THE WHOLE FIX.

     This used to compute the top itself, as `last - VisibleRowCount + 1`, and
     that is off by one ROW every time -- VisibleRowCount INCLUDES the row that
     is only partly on screen (grids.pas, GetVisibleRowCount: it is simply
     VisibleGrid.bottom - VisibleGrid.top). So the arithmetic asked for one row
     more than actually fits, and the newest QSO sat permanently cut in half at
     the bottom edge (NY4I, 2026-09-08).

     TopRow goes through ScrollGrid, which ends with

         Result.y := Max(FixedRows, Min(Result.y, FGCache.MaxTopLeft.y))

     and CalcMaxTopLeft builds MaxTopLeft.y by walking upwards from the last
     row while `H <= ScrollHeight` -- the topmost row from which every
     remaining row fits WHOLE. That is exactly the question this routine is
     asking, already answered, against the real row heights and the real
     client height with whatever scrollbars are up. So asking for the last row
     lands on the true bottom and the LCL owns the arithmetic.

     THE CLAMP HOLDS ONLY BECAUSE goSmoothScroll IS NOT IN Options: with
     smooth scrolling the grid may stop part-way into a row and carry the
     remainder in MaxTLOffset. If that option is ever added here, reread this. *)
   TopRow := last;
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
     operator's high-contrast theme changes.

     ONLY AT FULL STRENGTH WHILE THIS GRID HAS THE KEYBOARD, and in a contest
     it essentially never does -- the operator is typing in the callsign field,
     and this grid is selected only because ScrollToEnd sets Row to keep the
     newest QSO in view. So the newest contact was painted in solid focus blue
     for the whole contest, with the callsign, the exchange and the multiplier
     flags reversed out of it.

     NY4I, Linux Mint 2026-09-09: "it highlights the entire dupe line and it is
     hard to read". He was looking at the newest row, not at a match -- the
     partial-call swatch DrawMatchIn paints was underneath it and unreadable
     for the same reason.

     WHY IT LOOKED FINE ON WINDOWS. Win32 draws an unfocused selection in a
     muted grey by convention, so the same code produced a subtle band there
     and a saturated one on gtk2. This makes the intent explicit rather than
     inheriting whichever answer the platform happens to give -- and it is the
     desktop convention on both.

     THE FONT COLOUR IS LEFT ALONE when unfocused, deliberately: red means
     deleted and grey means X-QSO, and reversing them out would delete two
     meanings to signal one. DrawMatchIn's note makes the same argument. *)
   if gdSelected in aState then
      begin
      (* THE GRID'S OWN SelectedColor, WHICHEVER WAY THE FOCUS HAPPENS TO BE.

        THIS LINE WAS clBtnFace WHEN UNFOCUSED, AND clBtnFace IS WINDOW CHROME.
        On Windows it is F0F0F0, near enough to white that a muted selection
        reads as a selection. On NY4I's gtk2 theme it is (220,218,213) -- and
        since ScrollToEnd keeps the newest QSO selected, and this grid never
        has the keyboard during a contest, the result was a FULL-WIDTH GREY BAR
        ONE ROW HIGH, permanently, immediately under the last contact.

        THAT IS THE "horizontal scroll bar with a thumb" HE REPORTED SEVEN
        TIMES. Captured with xwd and measured off the pixels: white above,
        white below, 19 grey rows between -- exactly one DefaultRowHeight, at
        the row ScrollToEnd had selected. Nothing was a scroll bar and nothing
        was dead space; a row was being painted the colour of a trough.

        I INTRODUCED IT the same day, replacing a saturated blue he had called
        hard to read. The complaint was right and so was muting it; borrowing
        a system chrome colour to do it was not.

        SelectedColor is a published grid property, so the colour is stated
        once in the constructor instead of being decided per paint, and
        FadeUnfocusedSelection is off so the LCL never swaps in clBtnFace on
        its own account -- which its PrepareCanvas does, with a comment naming
        the same two colours this went wrong on. *)
      Canvas.Brush.Color := SelectedColor;
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
