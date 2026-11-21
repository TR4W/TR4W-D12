unit uMainLayout;

(* THE MAIN WINDOW'S GEOMETRY, AS ARITHMETIC AND NOTHING ELSE.

  Every rectangle the main window's controls take is a function of the scale
  step ws (Settings.MainWindow.WindowSize + 12, 13..27) and, for the band
  below the log, of the log's height. Those functions lived inline in
  MainUnit.CreateMainWindow and uMainGrids.PositionMainGrids, where no test
  could reach them and only the default scale was ever checked (Lint-
  FormOverlap reads the .lfm, which shows ws 17).

  THIS UNIT HOLDS NO CONTROL AND USES NO WIDGET SET. MainUnit.LayOutMainWindow
  asks it for each rectangle and applies the answer; uTestMainLayout asks it at
  every ws from WS_MIN to WS_MAX. VC is used for TWindows[] only (LCLType is a
  types unit, not a widget set), as uCategoryWindow does.

  THE LAYOUT, in ws units (docs/MAIN_WINDOW_WIDTH_PLAN.md, section a6): a grid
  46 columns wide. Rows 0..6 are the top band, then the log, then rows 7..13
  below it. A TWindows[] row with mweB = 1 is in the lower band, and its top
  is mweiY * ws + the log's height.

  tools/gen_main_elements.py computes the same formulas at ws 17 for the
  design-time picture. Two languages, so two copies; keep them in step. *)

{$I tr4w.inc}

interface

uses
   Types,
   VC;

const
   (* THE SCALE RANGE: WindowSize 1..15, plus 12. NY4I kept it (2026-11-21). *)
   WS_MIN = 13;
   WS_MAX = 27;

   (* The width of the layout, in ws. *)
   LAYOUT_COLUMNS = 46;

   (* THE LOG'S HEIGHT IN ROWS: the minimum the layout is built at (and so the
     window's MinHeight), and how tall a first run opens. ROW COUNT, retired
     2026-11-21, was 5 by default. *)
   MAIN_LOG_MINIMUM_ROWS   = 5;
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

(* 46 * ws: the client width the layout fills. *)
function LayoutWidth(const aWS: integer): integer;

(* The log grid's row height, and the height of the log pane for aRows rows.
  30 was the Win32 list view's header and border allowance; it is kept so the
  five-row layout is the pixel height it always was. *)
function LogRowHeight(const aWS: integer): integer;
function LogHeightForRows(const aRows, aWS: integer): integer;

(* EVERYTHING THAT IS NOT THE LOG OR THE STATUS STRIP: seven rows above the
  log, seven below it, and 6 px. The client height is this, plus the log,
  plus the status strip (whose height is the widget set's). *)
function FixedBandsHeight(const aWS: integer): integer;

(* THE CLIENT HEIGHT AT THE MINIMUM LOG, LESS THE STATUS STRIP. *)
function MinClientHeight(const aWS: integer): integer;

(* The log pane. *)
function LogRect(const aWS, aLogHeight: integer): TRect;

(* Whether the element-creation loop gives aElement a panel at all. A row
  whose style is 0..2 is the window itself, a duplicate, or a control built by
  its own routine (the entry fields, the log, the possible-call strip). *)
function ElementHasPanel(const aElement: TMainWindowElement): boolean;

(* An element's panel, from its TWindows[] row. *)
function ElementRect(const aElement: TMainWindowElement;
                     const aWS, aLogHeight: integer): TRect;

(* The entry fields: (3 * ws) div 2 - 1 tall, the exchange one pixel below
  the call. *)
function EntryFieldHeight(const aWS: integer): integer;
function EntryFieldRect(const aRow: TEntryFieldRow;
                        const aWS, aLogHeight: integer): TRect;

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

(* The lower band's controls that are not TWindows[] rows. *)
function LastHourBarRect(const aWS, aLogHeight: integer): TRect;
function RateBarRect(const aWS, aLogHeight: integer): TRect;
(* The minitour row (only when MINITOUR DURATION is set): the quick-command
  panel narrowed to make room, the tour's progress bar and its readout. *)
function MinitourQuickCommandRect(const aWS, aLogHeight: integer): TRect;
function TourDurationBarRect(const aWS, aLogHeight: integer): TRect;
function TourDurationTextRect(const aWS, aLogHeight: integer): TRect;
(* The possible-call strip, its row height and its column width. *)
function PossibleCallRect(const aWS, aLogHeight: integer): TRect;
function PossibleCallColumnWidth(const aWS: integer): integer;

(* THE TOTALS GRID'S COLUMNS. Column 0 is the label column, ws * 5 wide to line
  up with the clocks above it; column 7 ("All") is three units wide; the band
  columns between them are one pitch, Round(ws * 2.5), each, starting AFTER the
  label column. *)
function TotalsColumnPitch(const aWS: integer): integer;
function TotalsLabelWidth(const aWS: integer): integer;
procedure TotalsColumnGeometry(const aWS, aColumn: integer;
                              out aLeft, aWidth: integer);

(* THE LEFT EDGE OF THE NEED STRIPS: 14 units in from the right of the client.
  Their row labels start here and the band cells follow, one 2 * ws pitch
  each. *)
function NeedLeft(const aClientWidth, aWS: integer): integer;
function NeedCellPitch(const aWS: integer): integer;

implementation

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

function FixedBandsHeight(const aWS: integer): integer;
begin
   Result := 6 + aWS * 14;
end;

function MinClientHeight(const aWS: integer): integer;
begin
   Result := FixedBandsHeight(aWS) + LogHeightForRows(MAIN_LOG_MINIMUM_ROWS, aWS);
end;

function LogRect(const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(0, aWS * 7, LayoutWidth(aWS), aLogHeight);
end;

function ElementHasPanel(const aElement: TMainWindowElement): boolean;
begin
   Result := TWindows[aElement].mweiStyle > 2;
end;

function ElementRect(const aElement: TMainWindowElement;
                     const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(TWindows[aElement].mweiX * aWS,
                    TWindows[aElement].mweiY * aWS +
                       TWindows[aElement].mweB * aLogHeight,
                    TWindows[aElement].mweiWidth * aWS,
                    TWindows[aElement].mweiHeight * aWS);
end;

function EntryFieldHeight(const aWS: integer): integer;
begin
   Result := ((aWS * 3) div 2) - 1;
end;

function EntryFieldRect(const aRow: TEntryFieldRow;
                        const aWS, aLogHeight: integer): TRect;
var
   top: integer;
begin
   top := aLogHeight + aWS * 8;
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

function LastHourBarRect(const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(aWS * 28, aLogHeight + aWS * 10, aWS * 5, aWS);
end;

function RateBarRect(const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(aWS * 33, aLogHeight + aWS * 10, aWS * 5, aWS);
end;

function MinitourQuickCommandRect(const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(0, aLogHeight + aWS * 12, aWS * 33, aWS);
end;

function TourDurationBarRect(const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(aWS * 33, aLogHeight + aWS * 12, aWS * 5, aWS);
end;

function TourDurationTextRect(const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(aWS * 38, aLogHeight + aWS * 12, aWS * 8, aWS);
end;

function PossibleCallRect(const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(0, aLogHeight + aWS * 13, LayoutWidth(aWS), aWS);
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

function NeedLeft(const aClientWidth, aWS: integer): integer;
begin
   Result := aClientWidth - aWS * 14;
end;

function NeedCellPitch(const aWS: integer): integer;
begin
   Result := aWS * 2;
end;

end.
