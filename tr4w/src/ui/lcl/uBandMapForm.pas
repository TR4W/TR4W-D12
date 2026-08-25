unit uBandMapForm;
{$I ..\..\tr4w.inc}

{
  THE BAND MAP, AS A DESIGNED LCL FORM.

  Design: docs/BANDMAP_LCL_DESIGN.md.  Read it before changing this unit.

  IT IS A NEWSPAPER LAYOUT, NOT A TABLE, and getting that wrong is the first
  thing a reader will be tempted to "fix".  The Win32 band map was a MULTI-COLUMN
  list box -- tLB_SETCOLUMNWIDTH(hwnddlg, BandMapItemWidth) -- so spots flow DOWN
  a column and then into the NEXT column, and widening the window shows MORE
  SPOTS rather than wider ones.  On a 1280-pixel window that is fifty-odd spots
  at once across eight columns.  A table of fields -- frequency, flags, call,
  QSX, comment laid across the width -- would show eight.

  So the grid here is a LAYOUT grid: ColCount is how many newspaper columns fit,
  RowCount is how many spots fit down one, and cell (c, r) is spot c*RowCount+r.
  Each cell draws one whole spot inside BandMapItemWidth pixels.

  WHY A TDrawGrid AT ALL.  The old list box was rebuilt from scratch on every
  update -- LB_RESETCONTENT then one LB_ADDSTRING per row, wrapped in
  WM_SETREDRAW off/on, then ValidateRect and a RDW_NOERASE RedrawWindow, on a
  dialog carrying WS_EX_COMPOSITED.  Three flash mitigations stacked on one
  cause: destroying every item to show that one changed.  A grid's cell count IS
  the model size and OnDrawCell is asked only for cells actually on screen, so
  none of the three is needed.

  THE ROWS ARE VALUE COPIES.  FRows holds TSpotRecords, not indexes.  The old
  code stored an FList index as list-box item data and read it back through
  SpotsList.Get -- but InsertSpot Moves the array, so a spot arriving between a
  rebuild and the next paint renumbered every index above it and a cell painted
  a DIFFERENT spot.  Nothing here holds an index across a call; actions resolve
  by identity (IndexOfSpot), so Delete cannot remove the wrong spot either.

  THREE FACTS IN A SEVENTEEN-PIXEL BOX.  The old flag box wrote one letter --
  'M' for multiplier, then 'S' for split, then 'D' for dupe, each overwriting
  the last -- so a spot that was two of those admitted to one, and a split that
  was also a dupe showed no split at all.  Here the BACKGROUND carries dupe and
  multiplier (the colours the operator already reads) and the LETTER is left for
  the split.  Same pixels, nothing lost.

  THE FILTERING IS NOT HERE.  Which spots, in what order, is
  TDXSpotsList.BuildVisibleSpots -- one implementation, shared, because that
  code has already been wrong twice.  This unit decides only how they look.

  FOCUS FREEZES THE VIEW, NEVER THE MODEL.  While the grid has focus the cells
  still refresh, but the selection is held by identity so what is under the
  mouse does not move.  The old window set a global that made AddSpot DISCARD
  arriving spots -- design note 3.1.
}

interface

uses
  Forms, Controls, Grids, ComCtrls, Menus, ExtCtrls, Classes, Graphics,
  LCLType,      { HWND, VK_* -- the LCL's own, so this unit needs no Windows }
  VC;           { TSpotRecord, CallString }

type
  TfrmBandMap = class(TForm)
    grdSpots: TDrawGrid;
    sbSpot: TStatusBar;
    tmrRefresh: TTimer;
    pmBandMap: TPopupMenu;
    miAllBands: TMenuItem;
    miAllModes: TMenuItem;
    miDisplayCQ: TMenuItem;
    miDupeDisplay: TMenuItem;
    miMultsOnly: TMenuItem;
    miSep1: TMenuItem;
    miDeleteSpot: TMenuItem;
    miRemoveAll: TMenuItem;
    miSep2: TMenuItem;
    miQSYInactive: TMenuItem;
    miSO2RDisplay: TMenuItem;
    procedure HandleCreate(Sender: TObject);
    procedure HandleResize(Sender: TObject);
    procedure HandleDestroy(Sender: TObject);
    procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure RefreshTick(Sender: TObject);
    procedure SpotsDrawCell(Sender: TObject; aCol, aRow: integer;
                            aRect: TRect; aState: TGridDrawState);
    procedure SpotsDblClick(Sender: TObject);
    procedure SpotsKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure SpotsSelection(Sender: TObject; aCol, aRow: integer);
    procedure SpotsEnter(Sender: TObject);
    procedure SpotsExit(Sender: TObject);
    procedure MenuPopup(Sender: TObject);
    procedure MenuAllBandsClick(Sender: TObject);
    procedure MenuAllModesClick(Sender: TObject);
    procedure MenuDisplayCQClick(Sender: TObject);
    procedure MenuDupeDisplayClick(Sender: TObject);
    procedure MenuMultsOnlyClick(Sender: TObject);
    procedure MenuDeleteSpotClick(Sender: TObject);
    procedure MenuRemoveAllClick(Sender: TObject);
    procedure MenuQSYInactiveClick(Sender: TObject);
    procedure MenuSO2RDisplayClick(Sender: TObject);
  private
    { The snapshot the grid paints from -- value copies, rebuilt at most once
      per timer tick.  Never indexes: see the header. }
    FRows: array of TSpotRecord;
    FRowCount: integer;

    { The selection as IDENTITY, not as a cell, so a spot inserted above it does
      not move it.  The old code re-derived a row from a remembered frequency
      and then set it on a list box holding only the scrolled window -- off by
      the scroll offset once past the display limit (design note 3.7). }
    FSelFreq: LONGINT;
    FSelCall: CallString;
    FHasSel: boolean;

    { True while the grid has focus.  Freezes the SELECTION, not the refresh. }
    FFrozen: boolean;

    function  SpotIndexAt(const aCol, aRow: integer): integer;
  public
    { Called through the view seam, from places that used to post a message to a
      list box handle: BMFirst (a hot key) and ProcessReturn (Enter). }
    procedure SelectTopSpot;
  private
    procedure LayOutGrid;
    procedure RebuildSnapshot;
    procedure RestoreSelection;
    procedure RememberSelection;
    procedure ShowSelectedSpotInfo;
    function  SelectedSpot(out aSpot: TSpotRecord): boolean;
    procedure ToggleAndRepaint(var aFlag: boolean);
    procedure DrawSpotCell(const aSpot: TSpotRecord; const aRect: TRect;
                           const aSelected: boolean);
    function  AgeColor(const aSpot: TSpotRecord): TColor;
  end;

var
  { The live form, or nil.  MainUnit's OpenTR4WWindow needs its Handle. }
  TR4WBandMapForm: TfrmBandMap = nil;

{ Create the window and return its handle, for OpenTR4WWindow's seam.  The HWND
  in this signature is the last Win32 surface in the band map's path, and it is
  not the band map's own: OpenTR4WWindow and tr4w_WindowsArray deal in handles
  for all twenty tool windows, and both go when the last of them is a form. }
function CreateTR4WBandMapWindow: HWND;

implementation

{$R *.lfm}

uses
  SysUtils,
  uLCLFormHelpers,   { OwnFormByMainWindow -- the LCL way to parent a tool window }
  uBandMapView,      { the seam this form fills in }
  uSpots,
  uBandmap,          { TuneRadioToSpot }
  uConfigValues,     { Config.TwoRadioMode, Config.QSYInactiveRadio }
  uCTYDAT,
  uDupesheet,        { ClearAltD }
  TF,                { FreqToPChar2 }
  MainUnit,          { CloseTR4WWindow, SetOpMode, tCallWindowSetFocus }
  LogWind,
  LogRadio,
  LogK1EA,           { ActiveRadio / InActiveRadio }
  LogSubs2,          { DupeCheckOnInactiveRadio }
  LogStuff;

const
  { The status bar: six panels, fixed position, varying content -- the same six
    the Win32 STATUSCLASSNAME bar had, with one addition.  The split frequency
    finally has somewhere to go: uDXSpotParse has a real tokenizer for the QSX
    grammar and until now the only thing that ever reached the operator was an
    'S' that a dupe overwrote (design note 3.3). }
  SB_CALL    = 0;
  SB_AGE     = 1;
  SB_COUNTRY = 2;
  SB_SOURCE  = 3;
  SB_NOTES   = 4;
  SB_COUNT   = 5;

  { These index a collection declared in the .lfm, and the compiler cannot see
    the .lfm.  Shipping five constants against four declared panels raised
    "List index (5) out of bounds" from inside OnCreate, which aborted the
    form's construction -- so the symptom was not a wrong status bar but an
    empty band map and a context menu that would not open (NY4I, 2026-08-22).
    SB_PANELS is checked once at create, where it names the problem. }
  SB_PANELS  = 6;

  { Inside one cell, left to right.  The frequency field was sized by measuring
    '28888.8' with the actual font; Canvas.TextWidth asks the LCL the same
    question. }
  FLAG_WIDTH = 17;
  CELL_PAD   = 2;
  { D7's `Shift`: every spot is drawn inside a one-pixel border of window
    background, which is what visually separates one from the next. }
  CELL_INSET = 1;

{ -------------------------------------------------------------- lifecycle -- }

procedure TfrmBandMap.HandleCreate(Sender: TObject);
begin
   // The three captions that already exist as resource constants.  The other
   // items name CFG commands verbatim, so their .lfm captions ARE the
   // identifiers and are left alone.
   miDeleteSpot.Caption  := RC_DELETESELSPOT;
   miRemoveAll.Caption   := RC_REMOVEALLSP;
   miQSYInactive.Caption := RC_SENDINRIG;

   if sbSpot.Panels.Count <> SB_PANELS then
      begin
      // Fail with the reason rather than an index number three calls deeper.
      raise Exception.CreateFmt(
         'uBandMapForm.lfm declares %d status panels; the code indexes %d.',
         [sbSpot.Panels.Count, SB_PANELS]);
      end;

   FHasSel   := False;
   FRowCount := 0;
   RebuildSnapshot;
end;

procedure TfrmBandMap.HandleResize(Sender: TObject);
begin
   LayOutGrid;
end;

procedure TfrmBandMap.HandleDestroy(Sender: TObject);
begin
   BandMapRefresh    := nil;
   BandMapSelected   := nil;
   BandMapSelectTop  := nil;
   TR4WBandMapForm   := nil;
end;

procedure TfrmBandMap.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // Route the close through the window manager exactly as WM_CLOSE did, so the
   // saved rectangle, the menu check mark and WndHandle stay in step.  caFree
   // would tear the form down behind CloseTR4WWindow's back.
   // caHIDE, NOT caNone.  caNone leaves the form VISIBLE as far as the LCL is
   // concerned, and CloseTR4WWindow then destroys the handle underneath it --
   // so the widget set recreates it and the window will not go away.  NY4I:
   // "Clicking on the X on the Stations window does not close it. Nor does
   // hitting the accelerator key again" (bench queue, 2026-08).  The six
   // windows converted later all use caHide and close correctly; these five
   // were the early ones.
   CloseAction := caHide;
   CloseTR4WWindow(tw_BANDMAPWINDOW_INDEX);
end;

{ ------------------------------------------------------------- the layout -- }

function TfrmBandMap.SpotIndexAt(const aCol, aRow: integer): integer;
begin
   // DOWN THEN ACROSS.  This one line is the newspaper layout; everything else
   // follows from it.
   Result := (aCol * grdSpots.RowCount) + aRow;
end;

procedure TfrmBandMap.LayOutGrid;
var
   rowsDown, colsAcross: integer;
begin
   // BANDMAP ITEM HEIGHT and BANDMAP ITEM WIDTH are operator settings, so they
   // are floored rather than trusted: a zero would divide by zero below.
   if BandMapItemHeight < 8 then
      begin
      BandMapItemHeight := 8;
      end;
   if BandMapItemWidth < 40 then
      begin
      BandMapItemWidth := 40;
      end;

   grdSpots.DefaultRowHeight := BandMapItemHeight;
   grdSpots.DefaultColWidth  := BandMapItemWidth;

   // HOW MANY FIT DOWN, then how many columns those need.  The Win32 list box
   // was told only the column WIDTH and worked the rest out itself; the LCL
   // wants the counts, which is the same arithmetic made explicit.
   rowsDown := grdSpots.ClientHeight div BandMapItemHeight;
   if rowsDown < 1 then
      begin
      rowsDown := 1;
      end;

   colsAcross := (FRowCount + rowsDown - 1) div rowsDown;
   if colsAcross < 1 then
      begin
      colsAcross := 1;
      end;

   // ROWS BEFORE COLUMNS.  SpotIndexAt multiplies by RowCount, so a column
   // count computed against the old row count maps cells to the wrong spots for
   // one paint.
   if grdSpots.RowCount <> rowsDown then
      begin
      grdSpots.RowCount := rowsDown;
      end;
   if grdSpots.ColCount <> colsAcross then
      begin
      grdSpots.ColCount := colsAcross;
      end;
end;

{ -------------------------------------------------------------- the model -- }

procedure TfrmBandMap.RebuildSnapshot;
var
   idx: array of integer;
   cursorRow: integer;
   n, i: integer;
begin
   n := SpotsList.Count;
   SetLength(idx, n + 1);
   cursorRow := -1;
   n := SpotsList.BuildVisibleSpots(idx, cursorRow);

   SetLength(FRows, n);
   for i := 0 to n - 1 do
      begin
      // THE COPY.  Taken here and nowhere else, so nothing downstream holds an
      // index that InsertSpot could renumber under it.
      FRows[i] := SpotsList.Get(idx[i]);
      end;
   FRowCount := n;

   LayOutGrid;
   RestoreSelection;

   sbSpot.Panels[SB_COUNT].Text := SysUtils.Format(TC_SPOTS, [n]);
   ShowSelectedSpotInfo;
   grdSpots.Invalidate;
end;

procedure TfrmBandMap.RememberSelection;
var
   i: integer;
begin
   i := SpotIndexAt(grdSpots.Col, grdSpots.Row);
   FHasSel := (i >= 0) and (i < FRowCount);
   if FHasSel then
      begin
      FSelFreq := FRows[i].FFrequency;
      FSelCall := FRows[i].FCall;
      end;
end;

procedure TfrmBandMap.RestoreSelection;
var
   i, c, r: integer;
begin
   if (FRowCount = 0) or (not FHasSel) or (grdSpots.RowCount < 1) then
      begin
      Exit;
      end;
   // BY IDENTITY.  A cell number would be wrong the moment a spot is inserted
   // above the selected one -- most refreshes on a busy cluster -- and wrong
   // again the moment the window is resized and the columns reflow.
   for i := 0 to FRowCount - 1 do
      begin
      if (FRows[i].FFrequency = FSelFreq) and (FRows[i].FCall = FSelCall) then
         begin
         c := i div grdSpots.RowCount;
         r := i mod grdSpots.RowCount;
         if (c < grdSpots.ColCount) and
            ((grdSpots.Col <> c) or (grdSpots.Row <> r)) then
            begin
            grdSpots.Col := c;
            grdSpots.Row := r;
            end;
         Exit;
         end;
      end;
   // The selected spot is gone -- filtered out, decayed or deleted.  Leave the
   // cursor where it is rather than jumping the operator somewhere arbitrary.
end;

function TfrmBandMap.SelectedSpot(out aSpot: TSpotRecord): boolean;
var
   i: integer;
begin
   i := SpotIndexAt(grdSpots.Col, grdSpots.Row);
   Result := (i >= 0) and (i < FRowCount);
   if Result then
      begin
      aSpot := FRows[i];
      end;
end;

procedure TfrmBandMap.ShowSelectedSpotInfo;
var
   spot: TSpotRecord;
   notes: string;
begin
   if not SelectedSpot(spot) then
      begin
      sbSpot.Panels[SB_CALL].Text    := '';
      sbSpot.Panels[SB_AGE].Text     := '';
      sbSpot.Panels[SB_COUNTRY].Text := '';
      sbSpot.Panels[SB_SOURCE].Text  := '';
      sbSpot.Panels[SB_NOTES].Text   := '';
      Exit;
      end;

   sbSpot.Panels[SB_CALL].Text   := string(spot.FCall);
   // MINUTES TO THE OPERATOR, seconds underneath.  TC_MIN is '%u min.'.
   sbSpot.Panels[SB_AGE].Text    := SysUtils.Format(TC_MIN,
                                                    [spot.FAgeSeconds div 60]);
   sbSpot.Panels[SB_SOURCE].Text := SysUtils.Format(TC_SOURCE,
                                                    [string(spot.FSourceCall)]);

   notes := Trim(string(AnsiString(spot.FNotes)));
   if spot.FQSXFrequency <> 0 then
      begin
      // THE SPLIT FREQUENCY ITSELF.  Parsed all along, displayed nowhere.
      notes := Trim('QSX ' + FreqToPChar2(spot.FQSXFrequency) + '  ' + notes);
      end;
   sbSpot.Panels[SB_NOTES].Text := notes;

   // CQ and NEW are placeholders in the callsign field, not callsigns, and have
   // no country.  The old code reached the same conclusion by comparing the
   // first four bytes as an integer.
   if (spot.FCall = 'CQ') or (spot.FCall = 'NEW') then
      begin
      sbSpot.Panels[SB_COUNTRY].Text := '';
      end
   else
      begin
      sbSpot.Panels[SB_COUNTRY].Text :=
         string(ctyGetCountryNamePchar(ctyGetCountry(spot.FCall)));
      end;
end;

procedure TfrmBandMap.SelectTopSpot;
begin
   if FRowCount < 1 then
      begin
      Exit;
      end;
   grdSpots.Col := 0;
   grdSpots.Row := 0;
   RememberSelection;
   ShowSelectedSpotInfo;
end;

procedure TfrmBandMap.RefreshTick(Sender: TObject);
begin
   // NOT VISIBLE, NOT PAINTED.  The form is an owned popup of the main window,
   // so Windows hides it when TR4W is minimised.  The token is deliberately NOT
   // consumed, so the first tick after a restore draws everything that arrived
   // meanwhile.
   if not Visible then
      begin
      Exit;
      end;
   if not SpotsList.NeedsRepaint then
      begin
      Exit;
      end;
   SpotsList.MarkPainted;
   RebuildSnapshot;
end;

{ --------------------------------------------------------------- painting -- }

{ THE AGE RAMP, CONTINUOUS RATHER THAN FIVE STEPS.

  The owner-draw had steps at 2, 10, 20 and 30 MINUTES, which was all the
  resolution a minute-granular age could support -- and at a short decay time
  meant every spot spent its whole life in the freshest step, so the map showed
  no ageing at all before emptying.

  With a real age in seconds the colour can simply follow it.  The shape is
  kept: blue while the spot is worth chasing, then fading through grey to
  near-invisible.  FRESH_SECONDS matches the old 2-minute step, and is the
  band handled by the caller as a black fill with white text.

  Expressed against the OPERATOR'S decay time rather than fixed minutes, so a
  15-minute map and a 60-minute map both show a spot half-faded halfway
  through its life.  That is the part the fixed thresholds could not do. }
function TfrmBandMap.AgeColor(const aSpot: TSpotRecord): TColor;
const
   FRESH_SECONDS = 120;
var
   life: integer;
   frac: double;
   grey: integer;
begin
   life := BandMapDecayTime * 60;
   if life <= FRESH_SECONDS then
      begin
      // A decay time inside the fresh band leaves nothing to ramp over.
      Result := clBlue;
      Exit;
      end;

   if aSpot.FAgeSeconds <= FRESH_SECONDS then
      begin
      Result := clWhite;
      Exit;
      end;

   // 0 at the end of the fresh band, 1 at expiry.
   frac := (aSpot.FAgeSeconds - FRESH_SECONDS) / (life - FRESH_SECONDS);
   if frac < 0 then
      begin
      frac := 0;
      end;
   if frac > 1 then
      begin
      frac := 1;
      end;

   // The first fifth stays blue -- the old <= 10 minute step of a 60 minute
   // map -- and the rest fades $50 -> $C0 grey, the range the steps covered.
   if frac <= 0.2 then
      begin
      Result := clBlue;
      Exit;
      end;

   grey := $50 + Round(((frac - 0.2) / 0.8) * ($C0 - $50));
   Result := TColor(grey or (grey shl 8) or (grey shl 16));
end;

procedure TfrmBandMap.DrawSpotCell(const aSpot: TSpotRecord; const aRect: TRect;
                                   const aSelected: boolean);
var
   cellRect, freqRect, flagRect, callRect: TRect;
   freqText: string;
   flagText: string;
   bandColor: TColor;
   callColor: TColor;
   y: integer;
begin
   { THE ONE-PIXEL INSET, WHICH IS WHAT SEPARATES ONE SPOT FROM THE NEXT.

     D7 fills the whole item with the window background and then insets every
     rect by Shift = 1 on all four sides (uBandmap.pas:142, applied at
     :208-212), so each spot sits inside a hairline of background.  The
     conversion filled edge to edge, so a callsign's black block ran straight
     into the next column's red flag with nothing between them -- NY4I put the
     two band maps side by side and saw it, 2026-08-24. }
   cellRect := aRect;
   Inc(cellRect.Left,   CELL_INSET);
   Inc(cellRect.Top,    CELL_INSET);
   Dec(cellRect.Right,  CELL_INSET);
   Dec(cellRect.Bottom, CELL_INSET);

   grdSpots.Canvas.Brush.Color := grdSpots.Color;
   grdSpots.Canvas.FillRect(aRect);

   freqRect := cellRect;
   freqRect.Right := freqRect.Left +
                     grdSpots.Canvas.TextWidth('28888.8') + CELL_PAD * 3;

   flagRect := cellRect;
   flagRect.Left  := freqRect.Right;
   flagRect.Right := flagRect.Left + FLAG_WIDTH;

   callRect := cellRect;
   callRect.Left := flagRect.Right + CELL_PAD;

   y := cellRect.Top + ((cellRect.Bottom - cellRect.Top -
                      grdSpots.Canvas.TextHeight('X')) div 2);

   // --- the frequency, on a band-coloured field -------------------------
   //
   // PRESERVED EXACTLY, INCLUDING A DEAD BRANCH -- design note 3.8.  The Win32
   // code set clRed for a spot inside the guard band and then let the band test
   // overwrite it unconditionally, so the red never rendered.  Reproduced
   // rather than quietly fixed: changing what the operator sees inside a port
   // makes any difference impossible to attribute, and this window is watched
   // constantly during a contest.  Correcting the order is one line once NY4I
   // has decided the red is wanted.
   if Abs(aSpot.FFrequency - BandMapCursorFrequency) <= BandMapGuardBand then
      begin
      bandColor := clRed;
      end;

   if ((aSpot.FBand = InactiveRadioPtr.BandMemory) and Config.TwoRadioMode) or
      ((aSpot.FBand = BandmapBand) and (not Config.TwoRadioMode)) then
      begin
      bandColor := clBlue;
      end
   else
      begin
      bandColor := clSilver;
      end;

   grdSpots.Canvas.Brush.Color := bandColor;
   grdSpots.Canvas.FillRect(freqRect);

   freqText := FreqToPChar2(aSpot.FFrequency);
   grdSpots.Canvas.Brush.Style := bsClear;
   grdSpots.Canvas.Font.Color  := clWhite;
   grdSpots.Canvas.TextOut(freqRect.Right - CELL_PAD -
                           grdSpots.Canvas.TextWidth(freqText), y, freqText);
   grdSpots.Canvas.Brush.Style := bsSolid;

   { --- the flags: A FILL AND A LETTER, and the letter had gone missing ---

     Restored against the D7 source (C:\TR4W uBandmap.pas:284-305) after NY4I
     put the two band maps side by side, 2026-08-24.  The conversion kept the
     FILLS and dropped two of the three LETTERS: a multiplier showed as a red
     block with nothing in it, and a dupe as a yellow block, where D7 writes M
     and D.  Only S survived.

     THE PRECEDENCE IS D7'S AND IT IS NOT A SIMPLE else-if.  D7 assigns the
     letter three times in order, so each stage overrides the last:

       mult -> red-to-white gradient, letter 'M'
       QSX  -> letter becomes 'S'   -- THE FILL IS NOT TOUCHED, so a multiplier
               worked split stays red and shows S
       dupe -> yellow fill, letter 'D'  -- overrides BOTH

     The previous version had `if dupe else if mult` for the fill and an
     unconditional S for the letter, which gave a dupe-and-split spot a yellow
     block with 'S' where D7 shows 'D'.

     The gradient is red-to-WHITE, not flat red.  TCanvas.Handle is the HDC
     uGradient wants, so this is the same call D7 made. }
   grdSpots.Canvas.Brush.Color := grdSpots.Color;
   grdSpots.Canvas.FillRect(flagRect);

   flagText := '';

   if aSpot.FMult then
      begin
      { THE LCL'S OWN GRADIENT, NOT uGradient's.  That unit declares its own
        `tcolor` (uGradient.pas:25) and an implementation uses clause wins over
        the interface's, so pulling it in here silently redefined TColor for the
        whole unit and AgeColor's header stopped matching its declaration.
        TCanvas.GradientFill is native, needs no HDC, and has no type to clash. }
      grdSpots.Canvas.GradientFill(flagRect, clRed, clWhite, gdHorizontal);
      flagText := 'M';
      end;

   if aSpot.FQSXFrequency <> 0 then
      begin
      flagText := 'S';
      end;

   if aSpot.FDupe then
      begin
      grdSpots.Canvas.Brush.Color := clYellow;
      grdSpots.Canvas.FillRect(flagRect);
      flagText := 'D';
      end;

   if flagText <> '' then
      begin
      grdSpots.Canvas.Brush.Style := bsClear;
      grdSpots.Canvas.Font.Color  := clBlack;
      grdSpots.Canvas.TextOut(flagRect.Left +
         ((FLAG_WIDTH - grdSpots.Canvas.TextWidth(flagText)) div 2), y, flagText);
      grdSpots.Canvas.Brush.Style := bsSolid;
      end;

   // --- the callsign, ramped by age -------------------------------------
   if aSelected then
      begin
      grdSpots.Canvas.Brush.Color := clHighlight;
      callColor := clHighlightText;
      end
   else if aSpot.FAgeSeconds <= 120 then
      begin
      grdSpots.Canvas.Brush.Color := clBlack;
      callColor := clWhite;
      end
   else
      begin
      grdSpots.Canvas.Brush.Color := grdSpots.Color;
      callColor := AgeColor(aSpot);
      end;
   grdSpots.Canvas.FillRect(callRect);

   grdSpots.Canvas.Brush.Style := bsClear;
   grdSpots.Canvas.Font.Color  := callColor;
   grdSpots.Canvas.TextOut(callRect.Left + CELL_PAD, y, string(aSpot.FCall));
   grdSpots.Canvas.Brush.Style := bsSolid;
end;

procedure TfrmBandMap.SpotsDrawCell(Sender: TObject; aCol, aRow: integer;
                                    aRect: TRect; aState: TGridDrawState);
var
   i: integer;
begin
   i := SpotIndexAt(aCol, aRow);
   if (i < 0) or (i >= FRowCount) then
      begin
      // The tail of the last column.  Blank, not stale.
      grdSpots.Canvas.Brush.Color := grdSpots.Color;
      grdSpots.Canvas.FillRect(aRect);
      Exit;
      end;
   DrawSpotCell(FRows[i], aRect, gdSelected in aState);
end;

{ ------------------------------------------------------------ interaction -- }

procedure TfrmBandMap.SpotsSelection(Sender: TObject; aCol, aRow: integer);
begin
   RememberSelection;
   ShowSelectedSpotInfo;
end;

procedure TfrmBandMap.SpotsEnter(Sender: TObject);
begin
   FFrozen := True;
   RememberSelection;
   ShowSelectedSpotInfo;
end;

procedure TfrmBandMap.SpotsExit(Sender: TObject);
begin
   FFrozen := False;
end;

procedure TfrmBandMap.SpotsDblClick(Sender: TObject);
var
   spot: TSpotRecord;
begin
   if not SelectedSpot(spot) then
      begin
      Exit;
      end;

   if ((Radio1.FilteredStatus.Freq <> 0) and (Radio2.FilteredStatus.Freq <> 0)) and
      Config.QSYInactiveRadio then
      begin
      InactiveRadioPtr.BandMemory := spot.FBand;
      tClearDupeInfoCall;
      ClearAltD;
      DupeInfoCall := spot.FCall;
      DupeCheckOnInactiveRadio(True);
      TuneRadioToSpot(spot, InActiveRadio);
      SetOpMode(CQOpMode);
      end
   else
      begin
      TuneRadioToSpot(spot, ActiveRadio);
      end;

   // Focus returns to the callsign window, as it did from LBN_DBLCLK.
   tCallWindowSetFocus;
end;

{ ON THE FORM, NOT ONLY ON THE GRID.

  These were wired to grdSpots.OnKeyUp, so they fired only while the GRID
  itself had focus.  The window does not get focus when it opens --
  OpenTR4WWindow ends with FrmSetFocus, which returns the keyboard to the main
  window -- so opening the band map and pressing D sent a 'D' to the callsign
  field instead.  NY4I on the bench, 2026-08-24: "I pressed D, M, etc but it did
  not change those options."

  KeyPreview is already True on this form, so a form-level handler sees the key
  first whichever child has focus.  Still scoped to this window: with the main
  window active these letters type into the entry fields, which is correct. }
procedure TfrmBandMap.SpotsKeyUp(Sender: TObject; var Key: word;
                                 Shift: TShiftState);
begin
   // These arrived here from tr4w.dpr's message loop, where they were dispatched
   // by comparing Msg.HWND against the list box handle -- the last
   // window-specific arm in the loop, and the thing that gated Application.Run.
   // A raw Win32 child raises no LCL key events, which is why they could not
   // move until the control did.
   //
   // The loop also tested wParam 80 and 206.  80 ('P') had no handler at all and
   // 206 is not a virtual key any keyboard produces; both are dropped.  The SO2R
   // toggle they were reaching for is on the context menu.
   case Key of
      VK_DELETE:
         begin
         MenuDeleteSpotClick(nil);
         end;
      VK_B:
         begin
         ToggleAndRepaint(BandMapAllBands);
         end;
      VK_M:
         begin
         ToggleAndRepaint(BandMapAllModes);
         end;
      VK_D:
         begin
         ToggleAndRepaint(BandMapDupeDisplay);
         end;
   end;
end;

{ ------------------------------------------------------------------- menu -- }

procedure TfrmBandMap.MenuPopup(Sender: TObject);
begin
   miAllBands.Checked    := BandMapAllBands;
   miAllModes.Checked    := BandMapAllModes;
   miDisplayCQ.Checked   := BandMapDisplayCQ;
   miDupeDisplay.Checked := BandMapDupeDisplay;
   miMultsOnly.Checked   := BandMapMultsOnly;

   // Both SO2R items were only ever meaningful with two radios; the old window
   // expressed that by not ticking them, which is not the same as saying why.
   miQSYInactive.Enabled := Config.TwoRadioMode;
   miSO2RDisplay.Enabled := Config.TwoRadioMode;
   miQSYInactive.Checked := Config.QSYInactiveRadio and Config.TwoRadioMode;
   miSO2RDisplay.Checked := BandMapSO2RDisplay and Config.TwoRadioMode;
end;

procedure TfrmBandMap.ToggleAndRepaint(var aFlag: boolean);
begin
   aFlag := not aFlag;
   // A VIEW change: the filter moved, the list did not.  RequestRepaint is what
   // the coalescing timer watches, so this needs no direct repaint call.
   SpotsList.RequestRepaint;
end;

procedure TfrmBandMap.MenuAllBandsClick(Sender: TObject);
begin
   ToggleAndRepaint(BandMapAllBands);
end;

procedure TfrmBandMap.MenuAllModesClick(Sender: TObject);
begin
   ToggleAndRepaint(BandMapAllModes);
end;

procedure TfrmBandMap.MenuDisplayCQClick(Sender: TObject);
begin
   ToggleAndRepaint(BandMapDisplayCQ);
end;

procedure TfrmBandMap.MenuDupeDisplayClick(Sender: TObject);
begin
   ToggleAndRepaint(BandMapDupeDisplay);
end;

procedure TfrmBandMap.MenuMultsOnlyClick(Sender: TObject);
begin
   ToggleAndRepaint(BandMapMultsOnly);
end;

procedure TfrmBandMap.MenuDeleteSpotClick(Sender: TObject);
var
   spot: TSpotRecord;
   i: integer;
begin
   if not SelectedSpot(spot) then
      begin
      Exit;
      end;
   // BY IDENTITY, not by the cell's index.  The snapshot may be a quarter second
   // old and FList may have been renumbered by an insert since it was taken.
   i := SpotsList.IndexOfSpot(spot);
   if i >= 0 then
      begin
      SpotsList.Delete(i);
      end;
end;

procedure TfrmBandMap.MenuRemoveAllClick(Sender: TObject);
begin
   SpotsList.Clear;
   FHasSel := False;
   tCallWindowSetFocus;
end;

procedure TfrmBandMap.MenuQSYInactiveClick(Sender: TObject);
begin
   if Config.TwoRadioMode then
      begin
      ToggleAndRepaint(Config.QSYInactiveRadio);
      end;
end;

procedure TfrmBandMap.MenuSO2RDisplayClick(Sender: TObject);
begin
   if Config.TwoRadioMode then
      begin
      ToggleAndRepaint(BandMapSO2RDisplay);
      end;
end;

{ --------------------------------------------------------------- the seam -- }

procedure BandMapSelectTopImpl;
begin
   if TR4WBandMapForm <> nil then
      begin
      TR4WBandMapForm.SelectTopSpot;
      end;
end;

procedure BandMapRefreshImpl;
begin
   if TR4WBandMapForm <> nil then
      begin
      TR4WBandMapForm.RebuildSnapshot;
      end;
end;

function BandMapSelectedImpl: integer;
var
   spot: TSpotRecord;
begin
   Result := -1;
   if TR4WBandMapForm = nil then
      begin
      Exit;
      end;
   if not TR4WBandMapForm.SelectedSpot(spot) then
      begin
      Exit;
      end;
   Result := SpotsList.IndexOfSpot(spot);
end;

function CreateTR4WBandMapWindow: HWND;
begin
   if TR4WBandMapForm = nil then
      begin
      TR4WBandMapForm := TfrmBandMap.Create(nil);
      end;

   // PARENTED THE LCL WAY -- PopupParent / pmExplicit, not
   // SetWindowLongPtr(GWL_HWNDPARENT).  The same call the function-keys window
   // uses, and the reason this unit needs no Windows uses clause.
   OwnFormByMainWindow(TR4WBandMapForm);

   BandMapRefresh    := @BandMapRefreshImpl;
   BandMapSelected   := @BandMapSelectedImpl;
   BandMapSelectTop  := @BandMapSelectTopImpl;

   Result := TR4WBandMapForm.Handle;
end;

end.
