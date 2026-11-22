unit uMainLayout;

(* THE MAIN WINDOW'S GEOMETRY, AS ARITHMETIC AND NOTHING ELSE.

  Every rectangle the main window's controls take is a function of the scale
  step ws, 13..27, which since plan stage e4 follows the window's width
  (ScaleForClient; WINDOW SIZE + 12 only seeds it). Those functions lived
  inline in MainUnit.CreateMainWindow and uMainGrids.PositionMainGrids, where
  no test could reach them and only the default scale was ever checked (Lint-
  FormOverlap reads the .lfm, which shows ws 17).

  THIS UNIT HOLDS NO CONTROL AND USES NO WIDGET SET. MainUnit.LayOutMainWindow
  asks it for each rectangle and applies the answer; uTestMainLayout asks it at
  every ws from WS_MIN to WS_MAX. VC is used for TWindows[] only (LCLType is a
  types unit, not a widget set), as uCategoryWindow does.

  THE LAYOUT, in ws units (docs/MAIN_WINDOW_WIDTH_PLAN.md, section a6): a grid
  46 columns wide. Rows 0..6 are the TOP BAND, then the log, then rows 7..13
  in the BOTTOM BAND below it.

  THE BANDS ARE CONTAINERS (plan stage e5, 2026-11-21). uMainForm.lfm holds
  three panels, and every control is a child of one of them:

    pnlTopBand      alTop, 7 * ws tall: the clocks, the totals grid, Total
                    Score and Dupe Info;
    pnlNeedsBlock   alRight INSIDE the top band, 14 * ws wide: the need
                    headers, Beam Heading and the need strips (columns 32..46),
                    so it follows the window's right edge;
    pnlBottomBand   alBottom above the status strip, 7 * ws + 6 tall: every
                    TWindows[] row with mweB = 1, the entry fields, the
                    progress bars, the minitour row and the possible-call
                    strip.

  The log is alClient and takes whatever is left, so a taller or wider window
  needs no code. EVERY RECTANGLE BELOW IS IN ITS BAND'S OWN COORDINATES, which
  is why none of them takes the log's height: the log is no longer anybody's y
  origin. BandOrigin turns one back into window coordinates, for the tests.

  tools/gen_main_elements.py computes the same formulas at ws 17 for the
  design-time picture. Two languages, so two copies; keep them in step. *)

{$I tr4w.inc}

interface

uses
   Types,
   VC;

const
   (* THE SCALE RANGE: WindowSize 1..15, plus 12, up to 43 so a wide window scales up (NY4I, 2026-11-21: "at least lets see it"). *)
   WS_MIN = 13;
   WS_MAX = 43;

   (* The width of the layout, in ws. *)
   LAYOUT_COLUMNS = 46;

   (* EACH BAND IS SEVEN ROWS. The bottom band has 6 px more, below the
     possible-call strip and above the status strip. *)
   BAND_ROWS          = 7;
   BOTTOM_BAND_MARGIN = 6;

   (* THE RIGHT-HAND BLOCK OF THE TOP BAND: the 14 columns from column 32. A
     TWindows[] row of the top band that starts at or after this column lives
     in pnlNeedsBlock. *)
   NEEDS_BLOCK_COLUMNS      = 14;
   NEEDS_BLOCK_FIRST_COLUMN = LAYOUT_COLUMNS - NEEDS_BLOCK_COLUMNS;

   (* THE LOG'S HEIGHT IN ROWS.
     - MINIMUM: the fewest the window may be dragged down to -- NY4I's three
       (2026-11-21). It is the window's MinHeight; see MinLogHeight.
     - START: the height CreateMainWindow builds the window at, and so the
       window every absolute position in the e2 layout was measured from. ROW
       COUNT, retired 2026-11-21, was 5 by default.
     - FIRST_RUN: how tall a window with no saved size opens. *)
   MAIN_LOG_MINIMUM_ROWS   = 3;
   MAIN_LOG_START_ROWS     = 5;
   MAIN_LOG_FIRST_RUN_ROWS = 12;

   (* THE TOTALS GRID'S SHAPE, AND THE SINGLE SOURCE OF TRUTH FOR IT. See
     uMainGrids, which re-exports these, for the history of the four rows. *)
   TOTALS_COLUMNS      = 8;
   TOTALS_ROWS         = 4;
   TOTALS_FIRST_HEADER = 1;

type
   (* WHICH OF THE TWO ENTRY FIELDS. uMainWindowProc's TTR4WEntryField names
     the same two, but that unit is not a leaf. *)
   TEntryFieldRow = (efrCall, efrExchange);

   (* THE THREE CONTAINERS a control can live in -- see the unit note. *)
   TMainBand = (mbTop, mbNeeds, mbBottom);

(* 46 * ws: the client width the layout fills, and the window's MinWidth. *)
function LayoutWidth(const aWS: integer): integer;

(* The log grid's row height, and the height of the log pane for aRows rows.
  30 was the Win32 list view's header and border allowance; it is kept so the
  five-row start layout is the pixel height it always was. *)
function LogRowHeight(const aWS: integer): integer;
function LogHeightForRows(const aRows, aWS: integer): integer;

(* THE SMALLEST LOG PANE THAT SHOWS MAIN_LOG_MINIMUM_ROWS WHOLE DATA ROWS: the
  header row, those rows, and LOG_FRAME_ALLOWANCE for the grid's border. Not
  LogHeightForRows: its 30 px was a list view's allowance, and at ws 27 a
  29 px header leaves it one pixel for a border the widget set draws wider. *)
function MinLogHeight(const aWS: integer): integer;

(* THE BANDS' OWN SIZES. *)
function TopBandHeight(const aWS: integer): integer;
function BottomBandHeight(const aWS: integer): integer;
function NeedsBlockWidth(const aWS: integer): integer;

(* EVERYTHING THAT IS NOT THE LOG OR THE STATUS STRIP: both bands. The client
  height is this, plus the log, plus the status strip (whose height is the
  widget set's). *)
function FixedBandsHeight(const aWS: integer): integer;

(* THE SMALLEST CLIENT HEIGHT, LESS THE STATUS STRIP: both bands and
  MinLogHeight. *)
function MinClientHeight(const aWS: integer): integer;

(* THE CLIENT HEIGHT CreateMainWindow BUILDS, LESS THE STATUS STRIP: both bands
  and the MAIN_LOG_START_ROWS log. *)
function StartClientHeight(const aWS: integer): integer;

(* Whether the element-creation loop gives aElement a panel at all. A row
  whose style is 0..2 is the window itself, a duplicate, or a control built by
  its own routine (the entry fields, the log, the possible-call strip). *)
function ElementHasPanel(const aElement: TMainWindowElement): boolean;

(* WHICH BAND AN ELEMENT'S PANEL IS A CHILD OF: mweB = 1 is the bottom band; a
  top-band row from column NEEDS_BLOCK_FIRST_COLUMN on is the needs block. *)
function ElementBand(const aElement: TMainWindowElement): TMainBand;

(* An element's panel, from its TWindows[] row, IN ITS BAND. *)
function ElementRect(const aElement: TMainWindowElement;
                     const aWS: integer): TRect;

(* WHERE A BAND'S (0, 0) SITS IN THE WINDOW'S CLIENT AREA, for a window
  aClientWidth wide whose log is aLogHeight tall. The program never asks this
  -- the LCL places the bands -- but a test that holds the window to its old
  absolute positions does. *)
function BandOrigin(const aBand: TMainBand;
                    const aWS, aClientWidth, aLogHeight: integer): TPoint;

(* The entry fields, in the bottom band: (3 * ws) div 2 - 1 tall, the exchange
  one pixel below the call. *)
function EntryFieldHeight(const aWS: integer): integer;
function EntryFieldRect(const aRow: TEntryFieldRow; const aWS: integer): TRect;

(* THE FONT HEIGHTS THAT FOLLOW ws, all character heights in pixels.
  aFontSize is Settings.Font.Size (0..2, a step added to the scale).
  - an element panel: ws - 2 + aFontSize;
  - the entry fields and the QSO number: ws + 3;
  - the WSJT-X indicator: the element height scaled by its 3 cells over its 5
    characters ('WSJTX'), never below WSJTX_MIN_FONT_HEIGHT. A smaller font
    rather than a wider cell was NY4I's call (2026-08-26). *)
function ElementFontHeight(const aWS, aFontSize: integer): integer;
function EntryFontHeight(const aWS: integer): integer;
function WSJTXFontHeight(const aWS, aFontSize: integer): integer;

(* The bottom band's controls that are not TWindows[] rows, in that band. *)
function LastHourBarRect(const aWS: integer): TRect;
function RateBarRect(const aWS: integer): TRect;
(* The minitour row (only when MINITOUR DURATION is set): the quick-command
  panel narrowed to make room, the tour's progress bar and its readout. *)
function MinitourQuickCommandRect(const aWS: integer): TRect;
function TourDurationBarRect(const aWS: integer): TRect;
function TourDurationTextRect(const aWS: integer): TRect;
(* THE POSSIBLE-CALL STRIP, at the layout width. It is alBottom in the band
  with BOTTOM_BAND_MARGIN below it, so the program sets only its height; the
  rectangle is where that puts it in a band LayoutWidth wide. *)
function PossibleCallRect(const aWS: integer): TRect;
function PossibleCallColumnWidth(const aWS: integer): integer;

(* THE TOTALS GRID'S COLUMNS, in the top band. Column 0 is the label column,
  ws * 5 wide to line up with the clocks above it; column 7 ("All") is three
  units wide; the band columns between them are one pitch, Round(ws * 2.5),
  each, starting AFTER the label column. *)
function TotalsColumnPitch(const aWS: integer): integer;
function TotalsLabelWidth(const aWS: integer): integer;
procedure TotalsColumnGeometry(const aWS, aColumn: integer;
                              out aLeft, aWidth: integer);

(* THE NEED STRIPS, in the needs block: each row's label starts at the
  block's left edge and the band cells follow, one 2 * ws pitch each. *)
function NeedCellPitch(const aWS: integer): integer;

const
   (* HOW FAR PAST A STEP BOUNDARY THE CLIENT MUST GROW BEFORE ws STEPS UP
     (plan b1). It stops the scale flickering while a dragged edge sits on
     a boundary. Stepping DOWN has no slack, because it must not overflow. *)
   WS_STEP_UP_SLACK = 8;

(* THE SCALE A CLIENT AREA HOLDS (plan stage e4): ws follows the window's
  width, in whole steps.

  - aClientWidth: the form's client width.
  - aLayoutHeight: the client height LESS THE STATUS STRIP (whose height is
    the widget set's, so the caller measures it).
  - aCurrentWs: the scale in force now; clamped to WS_MIN..WS_MAX first.

  THE RULES, in order:
  1. A width of zero or less, or a height of zero or less, is a transient
     and keeps the current scale.
  2. STEP DOWN AT ONCE when the width is below LayoutWidth(current): to
     aClientWidth div 46. Nothing is ever wider than the window, which is
     what keeps the 2026-09-09 gtk2 clipping defect fixed.
  3. STEP UP only once the width reaches LayoutWidth(current + 1) +
     WS_STEP_UP_SLACK: then to aClientWidth div 46, which may be several
     steps. The slack decides WHEN to step up, not how far, so a window set
     to exactly 46 * n from a smaller scale lands on n (for n at least two
     steps up), and one dragged a pixel at a time steps up WS_STEP_UP_SLACK
     px past the boundary and back down only below it.
  4. Clamp to WS_MIN..WS_MAX.
  5. THE HEIGHT CAP: lower the result while MinClientHeight(ws) is more than
     aLayoutHeight, never below WS_MIN. The log keeps its three rows, and the
     window never has to grow to make room for a larger scale.

  Whenever aClientWidth >= LayoutWidth(WS_MIN), LayoutWidth(Result) is at
  most aClientWidth. *)
function ScaleForClient(const aClientWidth, aLayoutHeight,
                        aCurrentWs: integer): integer;

implementation

const
   (* THE GRID'S BORDER, generously: a win32 bsSingle grid draws a 2 px client
     edge on each side. uTestMainLayout measures the rows at MinHeight on the
     shown form, and gtk2 and cocoa are on BENCH_QUEUE. *)
   LOG_FRAME_ALLOWANCE = 8;

function LayoutWidth(const aWS: integer): integer;
begin
   Result := LAYOUT_COLUMNS * aWS;
end;

function LogRowHeight(const aWS: integer): integer;
begin
   Result := aWS + 2;
end;

function LogHeightForRows(const aRows, aWS: integer): integer;
begin
   Result := 30 + aRows * LogRowHeight(aWS);
end;

function MinLogHeight(const aWS: integer): integer;
begin
   Result := (MAIN_LOG_MINIMUM_ROWS + 1) * LogRowHeight(aWS) + LOG_FRAME_ALLOWANCE;
end;

function TopBandHeight(const aWS: integer): integer;
begin
   Result := BAND_ROWS * aWS;
end;

function BottomBandHeight(const aWS: integer): integer;
begin
   Result := BAND_ROWS * aWS + BOTTOM_BAND_MARGIN;
end;

function NeedsBlockWidth(const aWS: integer): integer;
begin
   Result := NEEDS_BLOCK_COLUMNS * aWS;
end;

function FixedBandsHeight(const aWS: integer): integer;
begin
   Result := TopBandHeight(aWS) + BottomBandHeight(aWS);
end;

function MinClientHeight(const aWS: integer): integer;
begin
   Result := FixedBandsHeight(aWS) + MinLogHeight(aWS);
end;

function StartClientHeight(const aWS: integer): integer;
begin
   Result := FixedBandsHeight(aWS) + LogHeightForRows(MAIN_LOG_START_ROWS, aWS);
end;

function ElementHasPanel(const aElement: TMainWindowElement): boolean;
begin
   Result := TWindows[aElement].mweiStyle > 2;
end;

function ElementBand(const aElement: TMainWindowElement): TMainBand;
begin
   if TWindows[aElement].mweB = 1 then
      begin
      Result := mbBottom;
      end
   else if TWindows[aElement].mweiX >= NEEDS_BLOCK_FIRST_COLUMN then
      begin
      Result := mbNeeds;
      end
   else
      begin
      Result := mbTop;
      end;
end;

function ElementRect(const aElement: TMainWindowElement;
                     const aWS: integer): TRect;
var
   column, row: integer;
begin
   column := TWindows[aElement].mweiX;
   row := TWindows[aElement].mweiY;
   case ElementBand(aElement) of
      mbNeeds:
         begin
         column := column - NEEDS_BLOCK_FIRST_COLUMN;
         end;
      mbBottom:
         begin
         row := row - BAND_ROWS;
         end;
      else
         begin
         (* mbTop: the top band's origin is the window's. *)
         end;
      end;
   Result := Bounds(column * aWS, row * aWS,
                    TWindows[aElement].mweiWidth * aWS,
                    TWindows[aElement].mweiHeight * aWS);
end;

function BandOrigin(const aBand: TMainBand;
                    const aWS, aClientWidth, aLogHeight: integer): TPoint;
begin
   case aBand of
      mbNeeds:
         begin
         Result := Point(aClientWidth - NeedsBlockWidth(aWS), 0);
         end;
      mbBottom:
         begin
         Result := Point(0, TopBandHeight(aWS) + aLogHeight);
         end;
      else
         begin
         Result := Point(0, 0);
         end;
      end;
end;

function EntryFieldHeight(const aWS: integer): integer;
begin
   Result := ((aWS * 3) div 2) - 1;
end;

function EntryFieldRect(const aRow: TEntryFieldRow; const aWS: integer): TRect;
var
   top: integer;
begin
   top := aWS;
   if aRow = efrExchange then
      begin
      top := top + EntryFieldHeight(aWS) + 1;
      end;
   Result := Bounds(aWS * 15, top, aWS * 13, EntryFieldHeight(aWS));
end;

const
   WSJTX_CELLS           = 3;   (* mweWSJTX's mweiWidth *)
   WSJTX_CHARS           = 5;   (* Length('WSJTX'), written by uStateBridge *)
   WSJTX_MIN_FONT_HEIGHT = 8;   (* below this it stops being readable *)

function ElementFontHeight(const aWS, aFontSize: integer): integer;
begin
   Result := aWS - 2 + aFontSize;
end;

function EntryFontHeight(const aWS: integer): integer;
begin
   Result := aWS + 3;
end;

function WSJTXFontHeight(const aWS, aFontSize: integer): integer;
begin
   Result := Round(ElementFontHeight(aWS, aFontSize) * WSJTX_CELLS / WSJTX_CHARS);
   if Result < WSJTX_MIN_FONT_HEIGHT then
      begin
      Result := WSJTX_MIN_FONT_HEIGHT;
      end;
end;

function LastHourBarRect(const aWS: integer): TRect;
begin
   Result := Bounds(aWS * 28, aWS * 3, aWS * 5, aWS);
end;

function RateBarRect(const aWS: integer): TRect;
begin
   Result := Bounds(aWS * 33, aWS * 3, aWS * 5, aWS);
end;

function MinitourQuickCommandRect(const aWS: integer): TRect;
begin
   Result := Bounds(0, aWS * 5, aWS * 33, aWS);
end;

function TourDurationBarRect(const aWS: integer): TRect;
begin
   Result := Bounds(aWS * 33, aWS * 5, aWS * 5, aWS);
end;

function TourDurationTextRect(const aWS: integer): TRect;
begin
   Result := Bounds(aWS * 38, aWS * 5, aWS * 8, aWS);
end;

function PossibleCallRect(const aWS: integer): TRect;
begin
   Result := Bounds(0, BottomBandHeight(aWS) - BOTTOM_BAND_MARGIN - aWS,
                    LayoutWidth(aWS), aWS);
end;

function PossibleCallColumnWidth(const aWS: integer): integer;
begin
   Result := aWS * 5;
end;

(* THE BAND COLUMNS USED TO START ONE PIXEL INSIDE THE LABEL COLUMN: they were
  placed at (column + 1) * pitch, and at ws 17 that put column 1 at 84 against
  a label column ending at 85. Lint-FormOverlap found it once these became
  designed controls. *)
function TotalsColumnPitch(const aWS: integer): integer;
begin
   Result := Round(aWS * 2.5);
end;

function TotalsLabelWidth(const aWS: integer): integer;
begin
   Result := aWS * 5;
end;

procedure TotalsColumnGeometry(const aWS, aColumn: integer;
                              out aLeft, aWidth: integer);
begin
   if aColumn = 0 then
      begin
      aLeft := 0;
      aWidth := TotalsLabelWidth(aWS);
      end
   else
      begin
      aLeft := TotalsLabelWidth(aWS) + (aColumn - 1) * TotalsColumnPitch(aWS);
      if aColumn = TOTALS_COLUMNS - 1 then
         begin
         aWidth := aWS * 3;
         end
      else
         begin
         aWidth := TotalsColumnPitch(aWS);
         end;
      end;
end;

function NeedCellPitch(const aWS: integer): integer;
begin
   Result := aWS * 2;
end;

function ClampScale(const aWS: integer): integer;
begin
   Result := aWS;
   if Result < WS_MIN then
      begin
      Result := WS_MIN;
      end;
   if Result > WS_MAX then
      begin
      Result := WS_MAX;
      end;
end;

function ScaleForClient(const aClientWidth, aLayoutHeight,
                        aCurrentWs: integer): integer;
var
   current: integer;
begin
   current := ClampScale(aCurrentWs);
   Result := current;

   if (aClientWidth <= 0) or (aLayoutHeight <= 0) then
      begin
      Exit;
      end;

   if aClientWidth < LayoutWidth(current) then
      begin
      Result := aClientWidth div LAYOUT_COLUMNS;
      end
   else if aClientWidth >= LayoutWidth(current + 1) + WS_STEP_UP_SLACK then
      begin
      Result := aClientWidth div LAYOUT_COLUMNS;
      end;

   Result := ClampScale(Result);

   while (Result > WS_MIN) and (MinClientHeight(Result) > aLayoutHeight) do
      begin
      Dec(Result);
      end;
end;

end.
