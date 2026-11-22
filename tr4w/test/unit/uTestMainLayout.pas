unit uTestMainLayout;
{$I ..\..\src\tr4w.inc}

(*
  THE MAIN WINDOW'S LAYOUT, AT EVERY SCALE AND EVERY SIZE (plan stages e2, e3
  and e5, docs/MAIN_WINDOW_WIDTH_PLAN.md).

  Since e5 every control is a child of one of three bands -- pnlTopBand
  (alTop), pnlNeedsBlock (alRight inside it) and pnlBottomBand (alBottom,
  above the status strip) -- placed in the band's own coordinates, and the log
  is alClient. THE INVARIANT HELD THROUGHOUT: at the same ws, in a window of
  the old size, every control is at the same place IN THE WINDOW as before
  the bands. The oracle for that is the e2 formula, written out here from
  TWindows[] (OldWindowRect), not asked of uMainLayout.

  1. THE ARITHMETIC (uMainLayout, no form): at every ws from WS_MIN to WS_MAX,
     every rectangle lies inside its band, the band rectangles put each one
     where the e2 formula did, no two controls overlap, and nothing in the
     top band reaches under the needs block. Two overlaps exist and are pinned
     BY NAME, each with the condition under which it happens; a pinned overlap
     that stops happening fails too, so the pin is removed by whoever fixes
     it.

  2. THE SAME BOUNDS (the streamed main form): LayOutMainWindow at ws 17 puts
     every generated panel exactly where uMainForm.lfm has it in its band --
     tools/gen_main_elements.py writes the .lfm from its own Python copy of
     the formulas, and Lint-MainElements pins it -- and, shown, in the window
     where the e2 formula put it. Then ws 13 against literals worked out by
     hand at d689fef9 (before the bands), then ws 17 again, then a second
     call changes nothing.

  3. THE BANDS FOLLOW THE WINDOW (stages e3 and e5), on the form shown off
     screen: taller gives the log the height and moves the bottom band with
     the bottom edge; wider gives the log and the possible-call strip the
     width and moves the needs block with the right edge, and nothing else
     moves; narrower than the layout is refused by MinWidth; a re-layout at
     ws 13 and at ws 27 keeps the status strip at the bottom and the bottom
     band on top of it.

  4. SHOW GRIDLINES (stage e1): a gridline toggle leaves a log the window made
     taller as it is.

  5. THE MINIMUM HEIGHT shows three whole log rows (NY4I, 2026-11-21) at ws
     13, 17 and 27, measured on the grid.

  6. THE SCALE FOLLOWS THE WIDTH (stage e4): uMainLayout.ScaleForClient at
     every boundary; then the shown form, armed, dragged up to ws 20, held by
     the slack, stepped down at once with nothing clipped, and back to ws 17
     exactly; a resize before arming changes nothing; a window too short for
     a larger scale is capped.

  Tests 2 to 5 follow the program's start-up order as far as it runs without
  a contest: the form streamed, its window made, the grids bound, then
  MakeMainWindowResizeable and LayOutMainWindow, as CreateMainWindow calls
  them. A form that is not shown does not align its children, so every check
  of a position in the WINDOW is made on the form shown off screen.

  The numbers are printed (WriteLn) so a failure can be read without a
  debugger.
*)

interface

uses
   Types, uTR4WTestFramework;

type
   TMainLayoutTests = class(TTestCase)
   private
      procedure CheckBounds(const aName: string; const aActual: TRect;
                            const aLeft, aTop, aWidth, aHeight: integer;
                            const aWhere: string);
      procedure CheckStatusStripAtTheBottom(const aWhere: string);
      procedure CheckEveryControlInsideItsParent(const aWhere: string);
      procedure CheckLaidOutAt(const aWS: integer; const aWhere: string);
   protected
      procedure Test_EveryRectInsideItsBandAndWhereItWasAtEveryScale;
      procedure Test_LayOutReproducesTheDesignedFormAndMovesWithTheScale;
      procedure Test_TheBandsFollowTheWindow;
      procedure Test_GridlinesLeaveATallLogAlone;
      procedure Test_TheMinimumHeightShowsThreeLogRows;
      procedure Test_ScaleForClientAtItsBoundaries;
      procedure Test_TheScaleFollowsTheWidth;
      procedure Test_AShortWindowCapsTheScale;
      procedure Test_StretchXKeepsEveryEdge;
      procedure Test_TheBottomBandStretchesToTheWidth;
      procedure Test_TheLogCellPadGrowsWithTheFont;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Generics.Collections, Forms, Controls, StdCtrls, ComCtrls,
   ExtCtrls,
   VC, uSettingsModel, uMainLayout, uElementPanel, uMainForm, uMainGrids,
   MainUnit,
   LogWind,          (* DispalayLogGridLines -- the SHOW GRIDLINES arm *)
   uLogGrid,         (* LogCellPad -- the log's cell padding *)
   uTestMainFormHarness, uTestShowOffScreen;

function SameBounds(const a, b: TRect): boolean;
begin
   Result := (a.Left = b.Left) and (a.Top = b.Top) and
             (a.Right = b.Right) and (a.Bottom = b.Bottom);
end;

function BoundsText(const aRect: TRect): string;
begin
   Result := Format('(%d,%d %dx%d)', [aRect.Left, aRect.Top,
                    aRect.Right - aRect.Left, aRect.Bottom - aRect.Top]);
end;

procedure TMainLayoutTests.CheckBounds(const aName: string; const aActual: TRect;
                                       const aLeft, aTop, aWidth, aHeight: integer;
                                       const aWhere: string);
begin
   CheckTrue(SameBounds(aActual, Bounds(aLeft, aTop, aWidth, aHeight)),
             Format('%s: %s is %s, expected %s',
                    [aWhere, aName, BoundsText(aActual),
                     BoundsText(Bounds(aLeft, aTop, aWidth, aHeight))]));
end;

(* THE e2 FORMULA, FROM THE TABLE: where an element's panel sat in the window
  before the bands, for a log aLogHeight tall. Written out here, not asked of
  uMainLayout, so it is an independent oracle for the band arithmetic. *)
function OldWindowRect(const aElement: TMainWindowElement;
                       const aWS, aLogHeight: integer): TRect;
begin
   Result := Bounds(TWindows[aElement].mweiX * aWS,
                    TWindows[aElement].mweiY * aWS + TWindows[aElement].mweB * aLogHeight,
                    TWindows[aElement].mweiWidth * aWS,
                    TWindows[aElement].mweiHeight * aWS);
end;

function Shifted(const aRect: TRect; const aBy: TPoint): TRect;
begin
   Result := Bounds(aRect.Left + aBy.X, aRect.Top + aBy.Y,
                    aRect.Right - aRect.Left, aRect.Bottom - aRect.Top);
end;

function BandSize(const aBand: TMainBand; const aWS: integer): TPoint;
begin
   case aBand of
      mbNeeds:
         begin
         Result := Point(NeedsBlockWidth(aWS), TopBandHeight(aWS));
         end;
      mbBottom:
         begin
         Result := Point(LayoutWidth(aWS), BottomBandHeight(aWS));
         end;
      else
         begin
         Result := Point(LayoutWidth(aWS), TopBandHeight(aWS));
         end;
      end;
end;

(* ---------------------------------------------------------------------------
  THE PURE HALF.
  --------------------------------------------------------------------------- *)

type
   TNamedRect = class
   public
      Name: string;
      Band: TMainBand;
      InBand: TRect;
      Rect: TRect;        (* in the window, at the layout width and start log *)
      constructor Create(const aName: string; const aBand: TMainBand;
                         const aInBand: TRect; const aWS: integer);
   end;

   TNamedRects = TObjectList<TNamedRect>;

constructor TNamedRect.Create(const aName: string; const aBand: TMainBand;
                              const aInBand: TRect; const aWS: integer);
begin
   inherited Create;
   Name := aName;
   Band := aBand;
   InBand := aInBand;
   Rect := Shifted(aInBand, BandOrigin(aBand, aWS, LayoutWidth(aWS),
                                       LogHeightForRows(MAIN_LOG_START_ROWS, aWS)));
end;

(* Every control the layout places in a band, at aWS. aMinitour adds the
  minitour row and narrows the quick-command panel, as LayOutMainWindow does
  when MINITOUR DURATION is set. The caller frees the list. *)
function LayoutRects(const aWS: integer; const aMinitour: boolean): TNamedRects;
var
   e: TMainWindowElement;
   c, r, row, i, left, width, pitch: integer;
begin
   Result := TNamedRects.Create(True);

   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if not ElementHasPanel(e) then
         begin
         Continue;
         end;
      if aMinitour and (e = mweQuickCommand) then
         begin
         Result.Add(TNamedRect.Create('element ' + TWindows[e].mweName, mbBottom,
                                      MinitourQuickCommandRect(aWS), aWS));
         end
      else
         begin
         Result.Add(TNamedRect.Create('element ' + TWindows[e].mweName, ElementBand(e),
                                      ElementRect(e, aWS), aWS));
         end;
      end;

   Result.Add(TNamedRect.Create('call field', mbBottom, EntryFieldRect(efrCall, aWS), aWS));
   Result.Add(TNamedRect.Create('exchange field', mbBottom, EntryFieldRect(efrExchange, aWS), aWS));
   Result.Add(TNamedRect.Create('last-hour bar', mbBottom, LastHourBarRect(aWS), aWS));
   Result.Add(TNamedRect.Create('rate bar', mbBottom, RateBarRect(aWS), aWS));
   Result.Add(TNamedRect.Create('possible-call strip', mbBottom, PossibleCallRect(aWS), aWS));
   if aMinitour then
      begin
      Result.Add(TNamedRect.Create('tour bar', mbBottom, TourDurationBarRect(aWS), aWS));
      Result.Add(TNamedRect.Create('tour text', mbBottom, TourDurationTextRect(aWS), aWS));
      end;

   for c := 0 to TOTALS_COLUMNS - 1 do
      begin
      TotalsColumnGeometry(aWS, c, left, width);
      for r := 0 to TOTALS_ROWS - 1 do
         begin
         Result.Add(TNamedRect.Create(Format('totals cell %d,%d', [c, r]), mbTop,
                                      Bounds(left, aWS * 2 + r * aWS, width, aWS), aWS));
         end;
      if c >= TOTALS_FIRST_HEADER then
         begin
         Result.Add(TNamedRect.Create(Format('totals head %d', [c]), mbTop,
                                      Bounds(left, 0, width, aWS * 2), aWS));
         end;
      end;

   (* As uMainGrids.PositionMainGrids places them, in the needs block: rows 1
     and 2 of each strip, a label and six band cells two pixels narrower than
     the pitch. *)
   pitch := NeedCellPitch(aWS);
   for row := 1 to 2 do
      begin
      Result.Add(TNamedRect.Create(Format('QSO need label %d', [row]), mbNeeds,
                                   Bounds(0, aWS * row, pitch, aWS), aWS));
      Result.Add(TNamedRect.Create(Format('mult need label %d', [row]), mbNeeds,
                                   Bounds(0, aWS * (row + 3), pitch, aWS), aWS));
      for i := 1 to 6 do
         begin
         Result.Add(TNamedRect.Create(Format('QSO need %d,%d', [row, i]), mbNeeds,
                                      Bounds(i * pitch, aWS * row, pitch - 2, aWS), aWS));
         Result.Add(TNamedRect.Create(Format('mult need %d,%d', [row, i]), mbNeeds,
                                      Bounds(i * pitch, aWS * (row + 3), pitch - 2, aWS), aWS));
         end;
      end;
end;

function Overlaps(const a, b: TRect): boolean;
begin
   (* Interiors only: two controls that share an edge do not overlap. *)
   Result := (a.Left < b.Right) and (b.Left < a.Right) and
             (a.Top < b.Bottom) and (b.Top < a.Bottom);
end;

function PairIs(const aFirst, aSecond, x, y: string): boolean;
begin
   Result := ((aFirst = x) and (aSecond = y)) or ((aFirst = y) and (aSecond = x));
end;

(* Whether the totals pitch, Round(ws * 2.5), rounds UP at aWS. *)
function TotalsPitchRoundsUp(const aWS: integer): boolean;
begin
   Result := TotalsColumnPitch(aWS) * 2 > aWS * 5;
end;

(* THE OVERLAPS THAT EXIST, NAMED, WITH WHEN THEY HAPPEN. Findings for NY4I,
  2026-11-21, not decisions; each goes when it is fixed.

  - THE ROVER PANEL (TWindows[] row 10, columns 15-25) LIES OVER THE EXCHANGE
    FIELD at every scale. It is hidden until roving (issue 133), so the overlap
    is on screen only while roving. Lint-FormOverlap cannot see it: the entry
    fields are made in code, not in the .lfm.
  - THE TOTALS GRID'S "All" COLUMN RUNS 3 px UNDER TOTAL SCORE AND DUPE INFO
    CALL when the pitch rounds UP (ws 15, 19, 23, 27 -- WINDOW SIZE 3, 7, 11,
    15): the column then ends at 5 * ws + 6 * pitch + 3 * ws, past 23 * ws. At
    ws 17 the pitch rounds down, which is why the .lfm-based lint never saw
    it. *)
function KnownOverlap(const a, b: string; const aWS: integer): boolean;
begin
   Result := PairIs(a, b, 'element ROVER', 'exchange field') or
             (TotalsPitchRoundsUp(aWS) and
              (PairIs(a, b, 'totals head 7', 'element TOTAL SCORE') or
               PairIs(a, b, 'totals head 7', 'element DUPE INFO CALL') or
               PairIs(a, b, 'totals cell 7,0', 'element DUPE INFO CALL')));
end;

function KnownOverlapCount(const aWS: integer): integer;
begin
   Result := 1;
   if TotalsPitchRoundsUp(aWS) then
      begin
      Result := Result + 3;
      end;
end;

procedure TMainLayoutTests.Test_EveryRectInsideItsBandAndWhereItWasAtEveryScale;
var
   scale, i, j, known, logH: integer;
   minitour: boolean;
   rects: TNamedRects;
   size: TPoint;
   e: TMainWindowElement;
   old: TRect;
begin
   BeginTest('MainLayout: every rectangle inside its band, where the e2 layout put it, ' +
             'and no two overlapping, at every scale');
   for minitour := False to True do
      begin
      for scale := WS_MIN to WS_MAX do
         begin
         logH := LogHeightForRows(MAIN_LOG_START_ROWS, scale);
         rects := LayoutRects(scale, minitour);
         try
            known := 0;
            for i := 0 to rects.Count - 1 do
               begin
               (* IN ITS BAND. *)
               size := BandSize(rects[i].Band, scale);
               CheckTrue((rects[i].InBand.Left >= 0) and (rects[i].InBand.Top >= 0) and
                         (rects[i].InBand.Right <= size.X) and
                         (rects[i].InBand.Bottom <= size.Y),
                         Format('ws %d: %s is %s, outside its band''s %dx%d',
                                [scale, rects[i].Name, BoundsText(rects[i].InBand),
                                 size.X, size.Y]));

               (* NEVER UNDER THE NEEDS BLOCK, at the narrowest window. *)
               if rects[i].Band = mbTop then
                  begin
                  CheckTrue(rects[i].InBand.Right <= LayoutWidth(scale) - NeedsBlockWidth(scale),
                            Format('ws %d: %s ends at %d, under the needs block at %d',
                                   [scale, rects[i].Name, rects[i].InBand.Right,
                                    LayoutWidth(scale) - NeedsBlockWidth(scale)]));
                  end;

               (* THE WINDOW, as before the bands. *)
               CheckTrue((rects[i].Rect.Left >= 0) and
                         (rects[i].Rect.Right <= LayoutWidth(scale)),
                         Format('ws %d: %s spans %d..%d, outside 0..%d',
                                [scale, rects[i].Name, rects[i].Rect.Left,
                                 rects[i].Rect.Right, LayoutWidth(scale)]));
               CheckTrue(rects[i].Rect.Bottom <= StartClientHeight(scale),
                         Format('ws %d: %s ends at %d, below the layout''s %d',
                                [scale, rects[i].Name, rects[i].Rect.Bottom,
                                 StartClientHeight(scale)]));
               for j := i + 1 to rects.Count - 1 do
                  begin
                  if not Overlaps(rects[i].Rect, rects[j].Rect) then
                     begin
                     Continue;
                     end;
                  if KnownOverlap(rects[i].Name, rects[j].Name, scale) then
                     begin
                     Inc(known);
                     Continue;
                     end;
                  CheckTrue(False, Format('ws %d (minitour %s): %s %s overlaps %s %s',
                                          [scale, BoolToStr(minitour, True),
                                           rects[i].Name, BoundsText(rects[i].Rect),
                                           rects[j].Name, BoundsText(rects[j].Rect)]));
                  end;
               end;
            (* A PINNED OVERLAP THAT HAS GONE FAILS TOO, so the pin goes with it. *)
            CheckEquals(KnownOverlapCount(scale), known,
                        Format('ws %d: the known overlaps (see KnownOverlap) all still happen',
                               [scale]));
         finally
            rects.Free;
         end;

         (* EVERY ELEMENT, IN ITS BAND, IS WHERE THE e2 FORMULA PUT IT. *)
         for e := Low(TMainWindowElement) to High(TMainWindowElement) do
            begin
            if not ElementHasPanel(e) then
               begin
               Continue;
               end;
            old := OldWindowRect(e, scale, logH);
            CheckTrue(SameBounds(Shifted(ElementRect(e, scale),
                                         BandOrigin(ElementBand(e), scale,
                                                    LayoutWidth(scale), logH)), old),
                      Format('ws %d: %s in its band lands at %s, the e2 layout had %s',
                             [scale, TWindows[e].mweName,
                              BoundsText(Shifted(ElementRect(e, scale),
                                                 BandOrigin(ElementBand(e), scale,
                                                            LayoutWidth(scale), logH))),
                              BoundsText(old)]));
            end;

         (* AND THE CONTROLS THAT ARE NOT TABLE ROWS, against the e2 literals'
           formulas: the call field at (15, 8) units below the log, the
           possible-call strip 13 units below it, the bars on row 10. *)
         CheckTrue(SameBounds(Shifted(EntryFieldRect(efrCall, scale),
                                      BandOrigin(mbBottom, scale, LayoutWidth(scale), logH)),
                              Bounds(scale * 15, logH + scale * 8, scale * 13,
                                     EntryFieldHeight(scale))),
                   Format('ws %d: the call field moved', [scale]));
         CheckTrue(SameBounds(Shifted(PossibleCallRect(scale),
                                      BandOrigin(mbBottom, scale, LayoutWidth(scale), logH)),
                              Bounds(0, logH + scale * 13, LayoutWidth(scale), scale)),
                   Format('ws %d: the possible-call strip moved', [scale]));
         CheckTrue(SameBounds(Shifted(LastHourBarRect(scale),
                                      BandOrigin(mbBottom, scale, LayoutWidth(scale), logH)),
                              Bounds(scale * 28, logH + scale * 10, scale * 5, scale)),
                   Format('ws %d: the last-hour bar moved', [scale]));
         CheckEquals(scale * 14 + 6, FixedBandsHeight(scale),
                     Format('ws %d: the two bands are the e2 layout''s fixed height', [scale]));
         end;
      end;
end;

(* ---------------------------------------------------------------------------
  THE FORM HALF.
  --------------------------------------------------------------------------- *)

type
   (* The scale globals and the one setting the layout reads, put back after:
     another suite must not inherit ws 13. *)
   TSavedLayoutState = class
   private
      FWS, FWS2, FChildsWidth: integer;
      FMinitour: TTourDuration;
   public
      constructor Create;
      procedure Restore;
   end;

constructor TSavedLayoutState.Create;
begin
   inherited Create;
   FWS := ws;
   FWS2 := ws2;
   FChildsWidth := MainWindowChildsWidth;
   FMinitour := Settings.Contest.MinitourDuration;
end;

procedure TSavedLayoutState.Restore;
begin
   ws := FWS;
   ws2 := FWS2;
   MainWindowChildsWidth := FChildsWidth;
   Settings.Contest.MinitourDuration := FMinitour;
end;

(* THE STREAMED MAIN FORM, WITH WHAT CreateMainWindow GIVES IT BEFORE THE
  LAYOUT: its window (CreateTR4WMainForm calls HandleNeeded, and the element
  setters ask for one), the grids bound, and two entry fields in the bottom
  band, as CreateTR4WEntryField parents them. The log grid is not built here:
  the tests that need it build it with no rows, so nothing reads a contest
  log. *)
procedure BuildTestMainWindow;
var
   edit: TEdit;
begin
   ReleaseTestMainForm;
   EnsureTestMainForm;
   TR4WMainForm.HandleNeeded;
   BindMainGrids;

   edit := TEdit.Create(TR4WMainForm);
   edit.AutoSize := False;
   edit.Parent := TR4WMainForm.pnlBottomBand;
   TR4WCallEdit := edit;

   edit := TEdit.Create(TR4WMainForm);
   edit.AutoSize := False;
   edit.Parent := TR4WMainForm.pnlBottomBand;
   TR4WExchangeEdit := edit;
end;

procedure ReleaseTestMainWindow;
begin
   (* The edits and the log grid are the form's; the globals would point into
     it. *)
   TR4WCallEdit := nil;
   TR4WExchangeEdit := nil;
   TR4WEditableLog := nil;
   ReleaseTestMainForm;
end;

(* CreateMainWindow's own sequence at aWS: size the window at the start log,
  with the minimum log as its floor, then lay it out. *)
procedure SizeAndLayOut(const aWS: integer);
begin
   MakeMainWindowResizeable(LayoutWidth(aWS),
                            StartClientHeight(aWS) + MainStatusBarHeight,
                            MinClientHeight(aWS) + MainStatusBarHeight);
   LayOutMainWindow(aWS);
end;

(* LET THE WIDGET SET CATCH UP. gtk2 delivers a resize after the call that
  caused it (see lcl-ui, "the same trap bites DESIGNED controls on gtk2"), so
  one pass of the queue is not always enough. *)
procedure Settle;
var
   k: integer;
begin
   for k := 1 to 5 do
      begin
      Application.ProcessMessages;
      Sleep(10);
      end;
end;

(* THE SAME, ON A SHOWN WINDOW, and the client height held to the start
  layout's. At 598 px (ws 13) the menu bar may wrap to a second line once the
  window is that narrow, which takes its height out of the client area after
  the client was sized; the bands would then sit a menu row higher than the
  literals, for a reason that has nothing to do with them. Said in the output
  when it happens, because on screen it is a finding of its own. *)
procedure SizeAndLayOutShown(const aWS: integer);
var
   wanted: integer;
begin
   SizeAndLayOut(aWS);
   Settle;
   wanted := StartClientHeight(aWS) + MainStatusBarHeight;
   if TR4WMainForm.ClientHeight <> wanted then
      begin
      WriteLn('  [MainLayout] ws ', aWS, ': the client came out ',
              TR4WMainForm.ClientHeight, ' high, not ', wanted, '; set again');
      TR4WMainForm.ClientHeight := wanted;
      Settle;
      end;
end;

(* WHETHER THIS DESKTOP CAN HOLD THE LAYOUT AT aWS. A sizeable window is held
  to about the screen's width (Windows' maximum track size; a window manager
  may do the same), so at ws 27 (1242 px) on a narrow test desktop the window
  is clamped and its bands come out narrower than the layout -- a fact about
  the desktop, not the code. The checks that need the full width ask this. *)
function DesktopFits(const aWS: integer): boolean;
begin
   Result := LayoutWidth(aWS) + 32 <= Screen.Width;
   if not Result then
      begin
      WriteLn('  [MainLayout] ws ', aWS, ': the desktop is ', Screen.Width,
              ' px wide, too narrow for ', LayoutWidth(aWS),
              '; its width checks are skipped');
      end;
end;

(* Shown off screen, as a running program's window is shown. Its activation
  handler moves focus and repaints the function keys, which is the running
  program's business, not these tests'. *)
procedure ShowTestMainWindow;
begin
   TR4WMainForm.OnActivate := nil;
   ShowOffScreen(TR4WMainForm);
   Settle;
end;

function ControlNamed(const aName: string): TControl;
var
   c: TComponent;
begin
   Result := nil;
   c := TR4WMainForm.FindComponent(aName);
   if c is TControl then
      begin
      Result := TControl(c);
      end;
end;

(* WHERE A CONTROL IS IN THE WINDOW: its own bounds plus every parent's
  offset up to the form. Exact because a band has no bevel, border or caption
  (pinned in test 2), so its client area starts at its own corner. *)
function FormRect(const aControl: TControl): TRect;
var
   p: TControl;
   x, y: integer;
begin
   x := aControl.Left;
   y := aControl.Top;
   p := aControl.Parent;
   while (p <> nil) and (p <> TR4WMainForm) do
      begin
      x := x + p.Left;
      y := y + p.Top;
      p := p.Parent;
      end;
   Result := Bounds(x, y, aControl.Width, aControl.Height);
end;

function FormRectOf(const aName: string): TRect;
var
   c: TControl;
begin
   Result := Bounds(-1, -1, 0, 0);
   c := ControlNamed(aName);
   if c <> nil then
      begin
      Result := FormRect(c);
      end;
end;

function BandPanel(const aBand: TMainBand): TPanel;
begin
   case aBand of
      mbNeeds:
         begin
         Result := TR4WMainForm.pnlNeedsBlock;
         end;
      mbBottom:
         begin
         Result := TR4WMainForm.pnlBottomBand;
         end;
      else
         begin
         Result := TR4WMainForm.pnlTopBand;
         end;
      end;
end;

(* EVERY CONTROL ON THE FORM THAT THE LAYOUT PLACES AND THE .lfm DESIGNS AT
  ws 17: the TWindows[] panels, the totals and need panels and the two
  progress bars. *)
function IsDesignedLayoutControl(const aControl: TControl): boolean;
begin
   Result := (aControl is TElementPanel) or (aControl is TProgressBar);
   (* The minitour row is placed only in a minitour, and these tests run with
     none. The auto-send arrow's left edge is DisplayAutoSendCharacterCount's,
     which depends on the CW settings. *)
   if (aControl.Name = 'pnlTourDuration') or
      (aControl.Name = 'pbTourDuration') or
      (aControl.Name = 'pnlAutoSendCount') then
      begin
      Result := False;
      end;
end;

procedure TMainLayoutTests.CheckStatusStripAtTheBottom(const aWhere: string);
var
   bar: TStatusBar;
begin
   bar := TR4WMainForm.sbStatus;
   CheckEquals(TR4WMainForm.ClientHeight, bar.Top + bar.Height,
               aWhere + ': the status strip is at the bottom of the window');
   CheckEquals(bar.Top, TR4WMainForm.pnlBottomBand.Top + TR4WMainForm.pnlBottomBand.Height,
               aWhere + ': the bottom band sits on the status strip');
   CheckEquals(0, TR4WMainForm.pnlTopBand.Top, aWhere + ': the top band is at the top');
   CheckEquals(TR4WMainForm.ClientWidth,
               TR4WMainForm.pnlNeedsBlock.Left + TR4WMainForm.pnlNeedsBlock.Width,
               aWhere + ': the needs block is at the right edge');
end;

(* NOTHING CLIPPED: every visible control's right and bottom edge inside its
  parent's client area, the window's for a band. *)
procedure TMainLayoutTests.CheckEveryControlInsideItsParent(const aWhere: string);

   procedure Walk(const aParent: TWinControl);
   var
      i: integer;
      c: TControl;
   begin
      for i := 0 to aParent.ControlCount - 1 do
         begin
         c := aParent.Controls[i];
         if not c.Visible then
            begin
            Continue;
            end;
         CheckTrue(((c.Left + c.Width) <= aParent.ClientWidth) and
                   ((c.Top + c.Height) <= aParent.ClientHeight),
                   Format('%s: %s ends at (%d,%d), outside %s''s %dx%d',
                          [aWhere, c.Name, c.Left + c.Width, c.Top + c.Height,
                           aParent.Name, aParent.ClientWidth, aParent.ClientHeight]));
         if (c is TPanel) and not (c is TElementPanel) then
            begin
            Walk(TPanel(c));
            end;
         end;
   end;

begin
   Walk(TR4WMainForm);
end;

procedure TMainLayoutTests.Test_LayOutReproducesTheDesignedFormAndMovesWithTheScale;
const
   (* The log at the five-row start: 30 + 5 * (ws + 2). *)
   LOG_17 = 125;
   LOG_13 = 105;
var
   saved: TSavedLayoutState;
   controls: TList<TControl>;
   designed: TList<TRect>;
   afterFirst: TList<TRect>;
   fonts: TList<integer>;
   i: integer;
   c: TControl;
   e: TMainWindowElement;
   b: TMainBand;
   expected: TRect;
begin
   BeginTest('MainLayout: ws 17 reproduces uMainForm.lfm and the e2 window, ws 13 moves ' +
             'every control, and a second call changes nothing');
   (* THE .lfm IS A 96-PPI PICTURE. On a screen the LCL scales forms for, the
     streamed bounds are scaled and the layout's are not, so the oracle does
     not apply there. TR4W declares no DPI awareness, so Windows reports 96. *)
   if Screen.PixelsPerInch <> 96 then
      begin
      WriteLn('  [MainLayout] skipped: the screen is ', Screen.PixelsPerInch,
              ' ppi and uMainForm.lfm is a 96-ppi picture');
      Exit;
      end;
   saved := TSavedLayoutState.Create;
   controls := TList<TControl>.Create;
   designed := TList<TRect>.Create;
   afterFirst := TList<TRect>.Create;
   fonts := TList<integer>.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;

      (* THE ORACLE, BEFORE ANYTHING IS LAID OUT: every designed control's
        bounds in its band. Components, not Controls: the form's own
        children are the bands. *)
      for i := 0 to TR4WMainForm.ComponentCount - 1 do
         begin
         if not (TR4WMainForm.Components[i] is TControl) then
            begin
            Continue;
            end;
         c := TControl(TR4WMainForm.Components[i]);
         if IsDesignedLayoutControl(c) then
            begin
            controls.Add(c);
            designed.Add(c.BoundsRect);
            CheckTrue((c.Parent = TR4WMainForm.pnlTopBand) or
                      (c.Parent = TR4WMainForm.pnlNeedsBlock) or
                      (c.Parent = TR4WMainForm.pnlBottomBand),
                      Format('%s is a child of a band, not of %s',
                             [c.Name, c.Parent.Name]));
            end;
         end;
      WriteLn('  [MainLayout] ', controls.Count, ' designed controls in the bands');
      CheckTrue(controls.Count > 100,
                'the form carries its generated panels (the totals grid alone is 39)');

      (* THE GENERATOR AND uMainLayout AGREE ON EVERY ELEMENT'S BAND, and a
        visible element has its window before the form is shown: the element
        setters need one (ElementUsable), and CreateMainWindow writes captions
        before the show. *)
      for e := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if (not ElementHasPanel(e)) or (MainElement(e) = nil) then
            begin
            Continue;
            end;
         b := ElementBand(e);
         CheckTrue(MainElement(e).Parent = BandPanel(b),
                   Format('%s is in %s; uMainLayout says %s',
                          [MainElement(e).Name, MainElement(e).Parent.Name,
                           BandPanel(b).Name]));
         if MainElement(e).Visible then
            begin
            CheckTrue(MainElement(e).HandleAllocated,
                      Format('%s has its window before the form is shown',
                             [MainElement(e).Name]));
            end;
         end;

      (* THE BANDS HAVE NO INSET, so a child's band coordinates are exact. *)
      for b := Low(TMainBand) to High(TMainBand) do
         begin
         CheckEquals(BandPanel(b).Width, BandPanel(b).ClientWidth,
                     BandPanel(b).Name + ': client width is its width');
         CheckEquals(BandPanel(b).Height, BandPanel(b).ClientHeight,
                     BandPanel(b).Name + ': client height is its height');
         end;

      (* WS 17, NOT YET SHOWN -- the start-up path: the .lfm, exactly. *)
      SizeAndLayOut(17);
      for i := 0 to controls.Count - 1 do
         begin
         CheckTrue(SameBounds(controls[i].BoundsRect, designed[i]),
                   Format('ws 17 hidden: %s is %s, the .lfm has %s',
                          [controls[i].Name, BoundsText(controls[i].BoundsRect),
                           BoundsText(designed[i])]));
         end;

      (* SHOWN: the bands aligned, and every control where the e2 layout put
        it in the window. The strip is shown so it is aligned too. *)
      TR4WMainForm.lstPossibleCall.Visible := True;
      ShowTestMainWindow;
      CheckEquals(782, TR4WMainForm.ClientWidth, 'ws 17: the client width');
      CheckStatusStripAtTheBottom('ws 17');
      for i := 0 to controls.Count - 1 do
         begin
         CheckTrue(SameBounds(controls[i].BoundsRect, designed[i]),
                   Format('ws 17: %s is %s, the .lfm has %s',
                          [controls[i].Name, BoundsText(controls[i].BoundsRect),
                           BoundsText(designed[i])]));
         end;
      for e := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if (not ElementHasPanel(e)) or (MainElement(e) = nil) or
            (e = mweAutoSendCount) then
            begin
            Continue;
            end;
         expected := OldWindowRect(e, 17, LOG_17);
         CheckTrue(SameBounds(FormRect(MainElement(e)), expected),
                   Format('ws 17: %s is at %s in the window, the e2 layout had %s',
                          [MainElement(e).Name, BoundsText(FormRect(MainElement(e))),
                           BoundsText(expected)]));
         end;
      CheckBounds('call field', FormRect(TR4WCallEdit), 255, 261, 221, 24, 'ws 17');
      CheckBounds('exchange field', FormRect(TR4WExchangeEdit), 255, 286, 221, 24, 'ws 17');
      CheckBounds('possible-call strip', FormRect(TR4WMainForm.lstPossibleCall),
                  0, 346, 782, 17, 'ws 17');
      CheckBounds('pnlQSONeedR1Label', FormRectOf('pnlQSONeedR1Label'),
                  544, 17, 34, 17, 'ws 17');
      CheckEquals(782, MainWindowChildsWidth, 'ws 17: the layout width');

      (* WS 13: LITERALS, worked out by hand from the arithmetic at d689fef9,
        IN THE WINDOW. *)
      SizeAndLayOutShown(13);
      CheckEquals(13, ws, 'ws 13: the scale global');
      CheckEquals(598, MainWindowChildsWidth, 'ws 13: the layout width');
      CheckEquals(598, TR4WMainForm.ClientWidth, 'ws 13: the client width');
      CheckStatusStripAtTheBottom('ws 13');
      CheckBounds('pnlBandMode', FormRectOf('pnlBandMode'), 0, 196, 52, 13, 'ws 13');
      CheckBounds('pnlQSONumber', FormRectOf('pnlQSONumber'), 143, 196, 52, 26, 'ws 13');
      CheckBounds('pnlInsert', FormRectOf('pnlInsert'), 546, 196, 52, 13, 'ws 13');
      CheckBounds('pnlCQTotal', FormRectOf('pnlCQTotal'), 494, 222, 104, 13, 'ws 13');
      CheckBounds('pnlWSJTX', FormRectOf('pnlWSJTX'), 104, 222, 39, 13, 'ws 13');
      CheckBounds('pbLastHour', FormRectOf('pbLastHour'), 364, 235, 65, 13, 'ws 13');
      CheckBounds('pnlTotalHead_1', FormRectOf('pnlTotalHead_1'), 65, 0, 32, 26, 'ws 13');
      CheckBounds('pnlTotalHead_7', FormRectOf('pnlTotalHead_7'), 257, 0, 39, 26, 'ws 13');
      CheckBounds('pnlTotalCell_7_3', FormRectOf('pnlTotalCell_7_3'), 257, 65, 39, 13, 'ws 13');
      CheckBounds('pnlQSONeedR1Label', FormRectOf('pnlQSONeedR1Label'), 416, 13, 26, 13, 'ws 13');
      CheckBounds('pnlMultNeedR2_10', FormRectOf('pnlMultNeedR2_10'), 572, 65, 24, 13, 'ws 13');
      CheckBounds('call field', FormRect(TR4WCallEdit), 195, 209, 169, 18, 'ws 13');
      CheckBounds('exchange field', FormRect(TR4WExchangeEdit), 195, 228, 169, 18, 'ws 13');
      CheckBounds('possible-call strip', FormRect(TR4WMainForm.lstPossibleCall),
                  0, 274, 598, 13, 'ws 13');

      (* EVERY PANEL, not only the literals: at its uMainLayout rectangle in
        its band, and at the e2 rectangle in the window. *)
      for e := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if (not ElementHasPanel(e)) or (MainElement(e) = nil) or
            (e = mweAutoSendCount) then
            begin
            Continue;
            end;
         expected := ElementRect(e, 13);
         CheckTrue(SameBounds(MainElement(e).BoundsRect, expected),
                   Format('ws 13: %s is %s in its band, the layout says %s',
                          [MainElement(e).Name, BoundsText(MainElement(e).BoundsRect),
                           BoundsText(expected)]));
         expected := OldWindowRect(e, 13, LOG_13);
         CheckTrue(SameBounds(FormRect(MainElement(e)), expected),
                   Format('ws 13: %s is at %s in the window, the e2 layout had %s',
                          [MainElement(e).Name, BoundsText(FormRect(MainElement(e))),
                           BoundsText(expected)]));
         end;

      (* THE FONTS THAT FOLLOW ws. *)
      CheckEquals(-ElementFontHeight(13, Settings.Font.Size),
                  TElementPanel(ControlNamed('pnlBandMode')).BaseFontHeight,
                  'ws 13: an element''s font');
      CheckEquals(-WSJTXFontHeight(13, Settings.Font.Size),
                  TElementPanel(ControlNamed('pnlWSJTX')).BaseFontHeight,
                  'ws 13: the WSJT-X indicator''s font');
      CheckEquals(-EntryFontHeight(13),
                  TElementPanel(ControlNamed('pnlQSONumber')).BaseFontHeight,
                  'ws 13: the QSO number''s font');
      CheckEquals(-EntryFontHeight(13), TR4WCallEdit.Font.Height,
                  'ws 13: the call field''s font');
      CheckEquals(-ElementFontHeight(13, Settings.Font.Size),
                  TR4WMainForm.lstPossibleCall.Font.Height,
                  'ws 13: the possible-call strip''s font');
      CheckEquals(13, TR4WMainForm.lstPossibleCall.DefaultRowHeight,
                  'ws 13: the possible-call strip''s row height');
      CheckEquals(MainFontCellHeight,
                  TElementPanel(ControlNamed('pnlTotalCell_0_0')).BaseFontHeight,
                  'ws 13: a totals cell''s font');

      (* BACK TO 17: THE .lfm AGAIN. *)
      SizeAndLayOutShown(17);
      CheckStatusStripAtTheBottom('ws 13 then 17');
      for i := 0 to controls.Count - 1 do
         begin
         CheckTrue(SameBounds(controls[i].BoundsRect, designed[i]),
                   Format('ws 13 then 17: %s is %s, the .lfm has %s',
                          [controls[i].Name, BoundsText(controls[i].BoundsRect),
                           BoundsText(designed[i])]));
         end;
      CheckEquals(-ElementFontHeight(17, Settings.Font.Size),
                  TElementPanel(ControlNamed('pnlBandMode')).BaseFontHeight,
                  'ws 13 then 17: an element''s font');

      (* AND A SECOND CALL AT THE SAME SCALE CHANGES NOTHING. *)
      for i := 0 to controls.Count - 1 do
         begin
         afterFirst.Add(FormRect(controls[i]));
         if controls[i] is TElementPanel then
            begin
            fonts.Add(TElementPanel(controls[i]).Font.Height);
            end
         else
            begin
            fonts.Add(0);
            end;
         end;
      LayOutMainWindow(17);
      Settle;
      for i := 0 to controls.Count - 1 do
         begin
         CheckTrue(SameBounds(FormRect(controls[i]), afterFirst[i]),
                   Format('the second call moved %s', [controls[i].Name]));
         if controls[i] is TElementPanel then
            begin
            CheckEquals(fonts[i], TElementPanel(controls[i]).Font.Height,
                        Format('the second call changed %s''s font', [controls[i].Name]));
            end;
         end;
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
      controls.Free;
      designed.Free;
      afterFirst.Free;
      fonts.Free;
   end;
end;

(* PLAN STAGES e3 AND e5, DECIDED HERE: the window resized in each axis, and
  re-laid out at two other scales, with the bands doing all of it. *)
procedure TMainLayoutTests.Test_TheBandsFollowTheWindow;
const
   GROWTH = 60;
   WIDENING = 200;
var
   saved: TSavedLayoutState;
   bottom, top, needs: TList<TControl>;
   before: TList<TRect>;
   k, logH, logW, stripW: integer;
   r: TRect;

   procedure Watch(const aList: TList<TControl>; const aControl: TControl);
   begin
      if (aControl <> nil) and aControl.Visible then
         begin
         aList.Add(aControl);
         end;
   end;

   (* Each control's place in the window, in watched order: bottom, top,
     needs. *)
   procedure Record_;
   var
      j: integer;
   begin
      before.Clear;
      for j := 0 to bottom.Count - 1 do
         begin
         before.Add(FormRect(bottom[j]));
         end;
      for j := 0 to top.Count - 1 do
         begin
         before.Add(FormRect(top[j]));
         end;
      for j := 0 to needs.Count - 1 do
         begin
         before.Add(FormRect(needs[j]));
         end;
   end;

   (* The needs block's controls are taken from the block itself -- its three
     TWindows[] rows and the need strips alike -- so the table loop skips
     them. *)
   procedure WatchTheBands;
   var
      j: integer;
      element: TMainWindowElement;
   begin
      bottom.Clear;
      top.Clear;
      needs.Clear;
      for element := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if (not ElementHasPanel(element)) or (element = mweAutoSendCount) then
            begin
            Continue;
            end;
         case ElementBand(element) of
            mbBottom:
               begin
               Watch(bottom, MainElement(element));
               end;
            mbTop:
               begin
               Watch(top, MainElement(element));
               end;
            else
               begin
               (* mbNeeds: taken from the block below. *)
               end;
            end;
         end;
      Watch(bottom, TR4WCallEdit);
      Watch(bottom, TR4WExchangeEdit);
      Watch(bottom, ControlNamed('pbLastHour'));
      Watch(bottom, ControlNamed('pbRate'));
      Watch(top, ControlNamed('pnlTotalCell_0_0'));
      Watch(top, ControlNamed('pnlTotalHead_7'));
      for j := 0 to TR4WMainForm.pnlNeedsBlock.ControlCount - 1 do
         begin
         if not (TR4WMainForm.pnlNeedsBlock.Controls[j] is TElementPanel) then
            begin
            Continue;
            end;
         Watch(needs, TR4WMainForm.pnlNeedsBlock.Controls[j]);
         end;
   end;

begin
   BeginTest('MainLayout: the bands follow the window -- taller, wider, too narrow, ' +
             'and re-laid out at ws 13 and 27 (plan stages e3 and e5)');
   saved := TSavedLayoutState.Create;
   bottom := TList<TControl>.Create;
   top := TList<TControl>.Create;
   needs := TList<TControl>.Create;
   before := TList<TRect>.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;

      (* SetWindowSize, then CreateMainWindow's own sequence at ws 17, with the
        log grid (no rows) and the possible-call strip shown. *)
      ApplyMainWindowScale(17);
      CreateTR4WEditableLog(0, TopBandHeight(17), LayoutWidth(17),
                            LogHeightForRows(MAIN_LOG_START_ROWS, 17));
      TR4WMainForm.lstPossibleCall.Visible := True;
      SizeAndLayOut(17);
      ShowTestMainWindow;
      CheckStatusStripAtTheBottom('ws 17');
      CheckBounds('the log', FormRect(TR4WEditableLog), 0, 119, 782, 125, 'ws 17');

      WatchTheBands;
      WriteLn('  [MainLayout] watching ', bottom.Count, ' bottom-band, ', top.Count,
              ' top-band and ', needs.Count, ' needs-block controls');
      CheckTrue(bottom.Count > 20, 'the bottom band has its controls');
      CheckTrue(needs.Count > 3, 'the needs block has its controls');

      (* (a) TALLER: the log takes it, the bottom band rides the bottom edge,
        the top band stays. *)
      Record_;
      logH := TR4WEditableLog.Height;
      TR4WMainForm.ClientHeight := TR4WMainForm.ClientHeight + GROWTH;
      Settle;
      CheckEquals(logH + GROWTH, TR4WEditableLog.Height, 'taller: the log took the growth');
      CheckStatusStripAtTheBottom('taller');
      for k := 0 to bottom.Count - 1 do
         begin
         r := FormRect(bottom[k]);
         CheckEquals(before[k].Top + GROWTH, r.Top,
                     Format('taller: %s followed the bottom edge', [bottom[k].Name]));
         end;
      for k := 0 to top.Count + needs.Count - 1 do
         begin
         if k < top.Count then
            begin
            r := FormRect(top[k]);
            end
         else
            begin
            r := FormRect(needs[k - top.Count]);
            end;
         CheckTrue(SameBounds(r, before[bottom.Count + k]),
                   Format('taller: a top-band control moved from %s to %s',
                          [BoundsText(before[bottom.Count + k]), BoundsText(r)]));
         end;

      (* (b) WIDER: the log and the strip take it, the needs block rides the
        right edge, and nothing else moves. *)
      Record_;
      logW := TR4WEditableLog.Width;
      stripW := TR4WMainForm.lstPossibleCall.Width;
      TR4WMainForm.ClientWidth := TR4WMainForm.ClientWidth + WIDENING;
      Settle;
      CheckEquals(LayoutWidth(17) + WIDENING, TR4WMainForm.ClientWidth,
                  'wider: the window took the width (MaxWidth is gone)');
      CheckEquals(logW + WIDENING, TR4WEditableLog.Width, 'wider: the log took the width');
      CheckEquals(stripW + WIDENING, TR4WMainForm.lstPossibleCall.Width,
                  'wider: the possible-call strip took the width');
      CheckStatusStripAtTheBottom('wider');
      for k := 0 to bottom.Count + top.Count - 1 do
         begin
         if k < bottom.Count then
            begin
            r := FormRect(bottom[k]);
            end
         else
            begin
            r := FormRect(top[k - bottom.Count]);
            end;
         CheckTrue(SameBounds(r, before[k]),
                   Format('wider: a control outside the needs block moved from %s to %s',
                          [BoundsText(before[k]), BoundsText(r)]));
         end;
      for k := 0 to needs.Count - 1 do
         begin
         r := FormRect(needs[k]);
         CheckEquals(before[bottom.Count + top.Count + k].Left + WIDENING, r.Left,
                     Format('wider: %s kept its distance from the right edge',
                            [needs[k].Name]));
         end;
      CheckEveryControlInsideItsParent('wider');

      (* (c) TOO NARROW: MinWidth refuses it, and nothing is clipped. *)
      TR4WMainForm.ClientWidth := LayoutWidth(17) - 100;
      Settle;
      CheckTrue(TR4WMainForm.ClientWidth >= LayoutWidth(17),
                Format('narrower: the client is %d, below the layout''s %d',
                       [TR4WMainForm.ClientWidth, LayoutWidth(17)]));
      CheckStatusStripAtTheBottom('narrower');
      CheckEveryControlInsideItsParent('narrower');

      (* (d) RE-LAID OUT AT ws 13, THEN TALLER: the old risk d2, which no
        longer exists -- nothing is anchored. *)
      SizeAndLayOut(13);
      Settle;
      CheckStatusStripAtTheBottom('ws 13 re-layout');
      CheckBounds('call field', FormRect(TR4WCallEdit), 195,
                  TR4WMainForm.pnlBottomBand.Top + 13, 169, 18, 'ws 13 re-layout');
      CheckEquals(TR4WMainForm.pnlBottomBand.Top - TopBandHeight(13),
                  TR4WEditableLog.Height, 'ws 13 re-layout: the log fills between the bands');
      WatchTheBands;
      Record_;
      TR4WMainForm.ClientHeight := TR4WMainForm.ClientHeight + 40;
      Settle;
      for k := 0 to bottom.Count - 1 do
         begin
         CheckEquals(before[k].Top + 40, FormRect(bottom[k]).Top,
                     Format('ws 13 then taller: %s followed the bottom edge',
                            [bottom[k].Name]));
         end;
      CheckEveryControlInsideItsParent('ws 13 then taller');

      (* (e) RE-LAID OUT AT ws 27: the band grows by 70 px, and the status
        strip must stay below it (see uMainForm.PlaceMainBands). *)
      SizeAndLayOut(27);
      Settle;
      CheckStatusStripAtTheBottom('ws 27 re-layout');
      CheckEquals(TopBandHeight(27), TR4WMainForm.pnlTopBand.Height, 'ws 27: the top band');
      CheckEquals(BottomBandHeight(27), TR4WMainForm.pnlBottomBand.Height,
                  'ws 27: the bottom band');
      CheckEquals(TopBandHeight(27), TR4WEditableLog.Top, 'ws 27: the log starts below the top band');
      CheckEquals(TR4WMainForm.pnlBottomBand.Top, TR4WEditableLog.Top + TR4WEditableLog.Height,
                  'ws 27: the log ends on the bottom band');
      if DesktopFits(27) then
         begin
         CheckEveryControlInsideItsParent('ws 27');
         end;
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
      bottom.Free;
      top.Free;
      needs.Free;
      before.Free;
   end;
end;

(* PLAN STAGE e1: SHOW GRIDLINES APPLIES LIVE AND MUST NOT TOUCH THE LOG'S
  BOUNDS. Its arm, DispalayLogGridLines, used to call CheckEditableWindowHeight,
  which put a log the operator had dragged taller back to the layout height
  and left the space below it empty. Here the window is grown, the log
  follows it, and a gridline toggle changes nothing but the lines. The log
  grid is built with no rows: RecordCount stays 0, so nothing reads the
  contest log. *)
procedure TMainLayoutTests.Test_GridlinesLeaveATallLogAlone;
const
   GROWTH = 60;
var
   saved: TSavedLayoutState;
   logBefore, logAfter: TRect;
   callTop: integer;
begin
   BeginTest('MainLayout: a gridline toggle leaves a log the window made taller ' +
             'as it is (plan stage e1)');
   saved := TSavedLayoutState.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;

      (* SetWindowSize, then CreateMainWindow's own sequence, at ws 17, with
        the log. *)
      ApplyMainWindowScale(17);
      CreateTR4WEditableLog(0, TopBandHeight(17), LayoutWidth(17),
                            LogHeightForRows(MAIN_LOG_START_ROWS, 17));
      SizeAndLayOut(17);
      ShowTestMainWindow;

      logBefore := TR4WEditableLog.BoundsRect;
      TR4WMainForm.ClientHeight := TR4WMainForm.ClientHeight + GROWTH;
      Settle;
      CheckEquals((logBefore.Bottom - logBefore.Top) + GROWTH,
                  TR4WEditableLog.Height, 'the log took the window''s growth');

      logBefore := TR4WEditableLog.BoundsRect;
      callTop := FormRect(TR4WCallEdit).Top;

      (* BOTH STATES, THEN THE ARM ITSELF. The setting is not touched: its
        setter marks the settings changed, and the defect this guards against
        was a bounds call inside DispalayLogGridLines, whatever the value. *)
      TR4WEditableLogSetGridLines(True);
      Settle;
      TR4WEditableLogSetGridLines(False);
      Settle;
      DispalayLogGridLines;
      Settle;

      logAfter := TR4WEditableLog.BoundsRect;
      CheckTrue(SameBounds(logAfter, logBefore),
                Format('the gridline toggle moved the log from %s to %s',
                       [BoundsText(logBefore), BoundsText(logAfter)]));
      CheckEquals(callTop, FormRect(TR4WCallEdit).Top, 'the gridline toggle moved the call field');
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
   end;
end;

(* THE FLOOR IS THREE WHOLE LOG ROWS (NY4I, 2026-11-21), MEASURED ON THE GRID,
  not trusted to the arithmetic: the window asked for one pixel of client,
  the constraint answers, and the grid's own client area is counted in rows
  under its header. At ws 27 the old 30 px allowance would have left a row
  short. *)
procedure TMainLayoutTests.Test_TheMinimumHeightShowsThreeLogRows;
const
   SCALES: array[0..2] of integer = (13, 17, 27);
var
   saved: TSavedLayoutState;
   k, scale, rows: integer;
begin
   BeginTest('MainLayout: at its minimum height the window shows three whole log rows');
   saved := TSavedLayoutState.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;
      ApplyMainWindowScale(17);
      CreateTR4WEditableLog(0, TopBandHeight(17), LayoutWidth(17),
                            LogHeightForRows(MAIN_LOG_START_ROWS, 17));
      SizeAndLayOut(17);
      ShowTestMainWindow;

      for k := Low(SCALES) to High(SCALES) do
         begin
         scale := SCALES[k];
         SizeAndLayOut(scale);
         Settle;
         TR4WMainForm.ClientHeight := 1;
         Settle;
         rows := (TR4WEditableLog.ClientHeight - TR4WEditableLog.RowHeights[0]) div
                 TR4WEditableLog.DefaultRowHeight;
         WriteLn('  [MainLayout] ws ', scale, ' at MinHeight: client ',
                 TR4WMainForm.ClientHeight, ', log ', TR4WEditableLog.Height,
                 ' (client ', TR4WEditableLog.ClientHeight, '), ', rows, ' whole rows');
         CheckTrue(rows >= MAIN_LOG_MINIMUM_ROWS,
                   Format('ws %d: the log shows %d whole rows at the window''s minimum ' +
                          'height, wanted %d', [scale, rows, MAIN_LOG_MINIMUM_ROWS]));
         CheckStatusStripAtTheBottom(Format('ws %d at MinHeight', [scale]));
         if DesktopFits(scale) then
            begin
            CheckEveryControlInsideItsParent(Format('ws %d at MinHeight', [scale]));
            end;
         end;
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
   end;
end;

(* ---------------------------------------------------------------------------
  PLAN STAGE e4: THE SCALE FOLLOWS THE WIDTH.
  --------------------------------------------------------------------------- *)

(* THE PURE RULE, at every boundary of every scale. A height of 10000 never
  caps; the cap has its own checks at the end. *)
procedure TMainLayoutTests.Test_ScaleForClientAtItsBoundaries;
const
   TALL = 10000;
var
   current, width, got, upper: integer;
begin
   BeginTest('MainLayout: ScaleForClient steps down at once, up past the slack, ' +
             'within WS_MIN..WS_MAX and under the height cap (plan stage e4)');

   for current := WS_MIN to WS_MAX do
      begin
      upper := current + 1;
      if upper > WS_MAX then
         begin
         upper := WS_MAX;
         end;

      CheckEquals(current, ScaleForClient(LayoutWidth(current), TALL, current),
                  Format('ws %d: exactly the layout width keeps it', [current]));

      if current > WS_MIN then
         begin
         CheckEquals(current - 1, ScaleForClient(LayoutWidth(current) - 1, TALL, current),
                     Format('ws %d: one pixel narrower steps down at once', [current]));
         end
      else
         begin
         CheckEquals(WS_MIN, ScaleForClient(LayoutWidth(current) - 1, TALL, current),
                     'WS_MIN: narrower than the smallest layout stays at WS_MIN');
         end;

      CheckEquals(current,
                  ScaleForClient(LayoutWidth(current + 1) + WS_STEP_UP_SLACK - 1, TALL, current),
                  Format('ws %d: one pixel short of the step-up threshold keeps it', [current]));
      CheckEquals(upper,
                  ScaleForClient(LayoutWidth(current + 1) + WS_STEP_UP_SLACK, TALL, current),
                  Format('ws %d: the step-up threshold steps up', [current]));

      (* THE INVARIANT: never wider than the client, always in range. *)
      for width := LayoutWidth(WS_MIN) to LayoutWidth(WS_MAX + 1) + 50 do
         begin
         got := ScaleForClient(width, TALL, current);
         if (got < WS_MIN) or (got > WS_MAX) or (LayoutWidth(got) > width) then
            begin
            CheckTrue(False, Format('ws %d at width %d gave %d: out of range or ' +
                                    'wider than the client', [current, width, got]));
            Break;
            end;
         end;
      end;

   (* Several steps at once, and exactly 46 * n from below lands on n. *)
   CheckEquals(20, ScaleForClient(LayoutWidth(20), TALL, 17), '17 to exactly 46 * 20 is 20');
   CheckEquals(13, ScaleForClient(LayoutWidth(13), TALL, 20), '20 to exactly 46 * 13 is 13');
   CheckEquals(WS_MAX, ScaleForClient(5000, TALL, 17), 'a very wide window is WS_MAX');

   (* Transients and a current scale out of range. *)
   CheckEquals(17, ScaleForClient(0, TALL, 17), 'a zero width keeps the scale');
   CheckEquals(17, ScaleForClient(-5, TALL, 17), 'a negative width keeps the scale');
   CheckEquals(17, ScaleForClient(LayoutWidth(20), 0, 17), 'a zero height keeps the scale');
   CheckEquals(WS_MIN, ScaleForClient(0, TALL, 5), 'VC''s initial ws of 5 reads as WS_MIN');
   CheckEquals(WS_MAX, ScaleForClient(LayoutWidth(WS_MAX), TALL, 40), 'a current above WS_MAX reads as WS_MAX');

   (* THE HEIGHT CAP. *)
   CheckEquals(20, ScaleForClient(LayoutWidth(27), MinClientHeight(20), 17),
               'a wide window exactly tall enough for ws 20 is capped there');
   CheckEquals(19, ScaleForClient(LayoutWidth(27), MinClientHeight(20) - 1, 17),
               'one pixel shorter is capped one step lower');
   CheckEquals(WS_MIN, ScaleForClient(LayoutWidth(27), 1, 17),
               'a window too short for any scale is WS_MIN');
   CheckEquals(17, ScaleForClient(LayoutWidth(17), MinClientHeight(17), 17),
               'the floor height holds the current scale');
end;

(* EVERY CONTROL THE LAYOUT PLACES, IN ITS BAND, and the bands -- the snapshot
  a rescale has to return to. *)
procedure CollectPlacedControls(const aList: TList<TControl>);

   procedure Walk(const aParent: TWinControl);
   var
      i: integer;
      c: TControl;
   begin
      for i := 0 to aParent.ControlCount - 1 do
         begin
         c := aParent.Controls[i];
         if IsDesignedLayoutControl(c) then
            begin
            aList.Add(c);
            end;
         if (c is TPanel) and not (c is TElementPanel) then
            begin
            Walk(TPanel(c));
            end;
         end;
   end;

begin
   aList.Clear;
   aList.Add(TR4WMainForm.pnlTopBand);
   aList.Add(TR4WMainForm.pnlNeedsBlock);
   aList.Add(TR4WMainForm.pnlBottomBand);
   Walk(TR4WMainForm);
end;

(* THE WINDOW LAID OUT AT aWS: the bands' sizes, every TWindows[] panel where
  uMainLayout puts it in its band, the fonts that follow ws, the entry fields,
  and the log between the bands. *)
procedure TMainLayoutTests.CheckLaidOutAt(const aWS: integer; const aWhere: string);
var
   e: TMainWindowElement;
   r, want: TRect;
begin
   CheckEquals(aWS, ws, aWhere + ': ws');
   CheckEquals(TopBandHeight(aWS), TR4WMainForm.pnlTopBand.Height, aWhere + ': the top band');
   CheckEquals(NeedsBlockWidth(aWS), TR4WMainForm.pnlNeedsBlock.Width, aWhere + ': the needs block');
   CheckEquals(BottomBandHeight(aWS), TR4WMainForm.pnlBottomBand.Height, aWhere + ': the bottom band');

   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if (not ElementHasPanel(e)) or (e = mweAutoSendCount) or (MainElement(e) = nil) then
         begin
         Continue;
         end;
      r := MainElement(e).BoundsRect;
      want := ElementRect(e, aWS);
      (* THE BOTTOM BAND IS STRETCHED to the client width; at the layout width
        that is the identity. *)
      if ElementBand(e) = mbBottom then
         begin
         want := StretchRect(want, TR4WMainForm.ClientWidth, aWS);
         end;
      CheckTrue(SameBounds(r, want),
                      Format('%s: %s is %s, expected %s',
                             [aWhere, MainElement(e).Name, BoundsText(r), BoundsText(want)]));
      end;

   CheckEquals(-ElementFontHeight(aWS, Settings.Font.Size),
                     TElementPanel(ControlNamed('pnlBandMode')).BaseFontHeight,
                     aWhere + ': an element''s font');
   CheckEquals(-WSJTXFontHeight(aWS, Settings.Font.Size),
                     TElementPanel(ControlNamed('pnlWSJTX')).BaseFontHeight,
                     aWhere + ': the WSJT-X indicator''s font');
   CheckEquals(-EntryFontHeight(aWS),
                     TElementPanel(ControlNamed('pnlQSONumber')).BaseFontHeight,
                     aWhere + ': the QSO number''s font');
   CheckEquals(-EntryFontHeight(aWS), TR4WCallEdit.Font.Height,
                     aWhere + ': the call field''s font');
   CheckTrue(SameBounds(TR4WCallEdit.BoundsRect,
                        StretchRect(EntryFieldRect(efrCall, aWS), TR4WMainForm.ClientWidth, aWS)),
                   aWhere + ': the call field is at ' + BoundsText(TR4WCallEdit.BoundsRect));
   CheckEquals(-ElementFontHeight(aWS, Settings.Font.Size),
                     TR4WMainForm.lstPossibleCall.Font.Height,
                     aWhere + ': the possible-call strip''s font');
   CheckEquals(LogRowHeight(aWS), TR4WEditableLog.DefaultRowHeight,
                     aWhere + ': the log''s row height');

   (* THE LOG FILLS WHAT THE BANDS LEAVE. *)
   CheckEquals(TopBandHeight(aWS), TR4WEditableLog.Top, aWhere + ': the log starts under the top band');
   CheckEquals(TR4WMainForm.pnlBottomBand.Top, TR4WEditableLog.Top + TR4WEditableLog.Height,
                     aWhere + ': the log ends on the bottom band');
end;

(* THE SHOWN WINDOW, ARMED, DRAGGED ACROSS STEPS: stepping up, the slack,
  stepping down at once with nothing clipped, a resize before arming, and the
  layout returning exactly to ws 17's. *)
procedure TMainLayoutTests.Test_TheScaleFollowsTheWidth;
var
   saved: TSavedLayoutState;
   placed: TList<TControl>;
   at17: TList<TRect>;
   i: integer;
begin
   BeginTest('MainLayout: the scale follows the window''s width once armed (plan stage e4)');
   saved := TSavedLayoutState.Create;
   placed := TList<TControl>.Create;
   at17 := TList<TRect>.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;
      ApplyMainWindowScale(17);
      CreateTR4WEditableLog(0, TopBandHeight(17), LayoutWidth(17),
                            LogHeightForRows(MAIN_LOG_START_ROWS, 17));
      SizeAndLayOut(17);
      ShowTestMainWindow;

      if not DesktopFits(21) then
         begin
         Exit;
         end;

      (* TALL ENOUGH THAT THE HEIGHT CAP NEVER DECIDES here: it has its own
        test. *)
      TR4WMainForm.ClientHeight := MinClientHeight(22) + MainStatusBarHeight + 20;
      Settle;

      (* NOT ARMED: a resize does not touch the scale. *)
      CheckFalse(TR4WMainForm.ScaleArmed, 'a streamed form starts unarmed');
      TR4WMainForm.ClientWidth := LayoutWidth(20) + WS_STEP_UP_SLACK;
      Settle;
      CheckEquals(17, ws, 'a resize before the form is armed leaves ws alone');
      TR4WMainForm.ClientWidth := LayoutWidth(17);
      Settle;

      (* ARMED at exactly the layout width: still 17. *)
      TR4WMainForm.ArmScaling;
      Settle;
      CheckEquals(17, ws, 'arming at 46 * 17 keeps 17');
      CollectPlacedControls(placed);
      for i := 0 to placed.Count - 1 do
         begin
         at17.Add(placed[i].BoundsRect);
         end;

      (* UP TO 20 in one drag. *)
      TR4WMainForm.ClientWidth := LayoutWidth(20);
      Settle;
      WriteLn('  [MainLayout] e4: client ', TR4WMainForm.ClientWidth, 'x',
              TR4WMainForm.ClientHeight, ' -> ws ', ws);
      CheckLaidOutAt(20, 'grown to 46 * 20');
      CheckStatusStripAtTheBottom('grown to 46 * 20');
      CheckEveryControlInsideItsParent('grown to 46 * 20');

      (* THE SLACK: one pixel short of the next step changes nothing. *)
      TR4WMainForm.ClientWidth := LayoutWidth(21) + WS_STEP_UP_SLACK - 1;
      Settle;
      CheckEquals(20, ws, 'one pixel below the step-up threshold keeps ws 20');

      (* DOWN AT ONCE: one pixel narrower than the layout, and nothing clipped. *)
      TR4WMainForm.ClientWidth := LayoutWidth(20) - 1;
      Settle;
      CheckEquals(19, ws, 'one pixel below 46 * 20 steps down at once');
      CheckLaidOutAt(19, 'shrunk to 46 * 20 - 1');
      CheckEveryControlInsideItsParent('shrunk to 46 * 20 - 1');
      CheckTrue(LayoutWidth(ws) <= TR4WMainForm.ClientWidth,
                'the layout is never wider than the client');

      (* AND BACK: the layout at 17 is exactly what it was. *)
      TR4WMainForm.ClientWidth := LayoutWidth(17);
      Settle;
      CheckLaidOutAt(17, 'back to 46 * 17');
      for i := 0 to placed.Count - 1 do
         begin
         CheckTrue(SameBounds(placed[i].BoundsRect, at17[i]),
                   Format('back at 17, %s is %s, was %s',
                          [placed[i].Name, BoundsText(placed[i].BoundsRect),
                           BoundsText(at17[i])]));
         end;
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
      at17.Free;
      placed.Free;
   end;
end;

(* THE HEIGHT CAP ON A SHOWN WINDOW: wide enough for ws 20 and only as tall as
  ws 17's floor stays at 17; made tall enough for 19, it steps to 19 and no
  further. *)
procedure TMainLayoutTests.Test_AShortWindowCapsTheScale;
var
   saved: TSavedLayoutState;
   layoutHeight: integer;
begin
   BeginTest('MainLayout: a wide window too short for a larger scale keeps the log''s ' +
             'three rows (plan stage e4)');
   saved := TSavedLayoutState.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;
      ApplyMainWindowScale(17);
      CreateTR4WEditableLog(0, TopBandHeight(17), LayoutWidth(17),
                            LogHeightForRows(MAIN_LOG_START_ROWS, 17));
      SizeAndLayOut(17);
      ShowTestMainWindow;
      if not DesktopFits(20) then
         begin
         Exit;
         end;
      TR4WMainForm.ArmScaling;
      Settle;

      TR4WMainForm.ClientHeight := MinClientHeight(17) + MainStatusBarHeight;
      Settle;
      TR4WMainForm.ClientWidth := LayoutWidth(20);
      Settle;
      layoutHeight := TR4WMainForm.ClientHeight - MainStatusBarHeight;
      WriteLn('  [MainLayout] e4 cap: client ', TR4WMainForm.ClientWidth, 'x',
              TR4WMainForm.ClientHeight, ' -> ws ', ws);
      CheckTrue(MinClientHeight(ws) <= layoutHeight,
                Format('ws %d needs %d px above the status strip; the window has %d',
                       [ws, MinClientHeight(ws), layoutHeight]));
      if layoutHeight = MinClientHeight(17) then
         begin
         CheckEquals(17, ws, 'a window only as tall as ws 17''s floor stays at 17');
         end;
      CheckStatusStripAtTheBottom('capped');

      TR4WMainForm.ClientHeight := MinClientHeight(19) + MainStatusBarHeight;
      Settle;
      CheckEquals(19, ws, 'made tall enough for 19, the capped window steps to 19, not 20');
      CheckLaidOutAt(19, 'capped at 19');
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
   end;
end;

function RectsOverlap(const a, b: TRect): boolean;
begin
   Result := (a.Left < b.Right) and (b.Left < a.Right) and
             (a.Top < b.Bottom) and (b.Top < a.Bottom);
end;

(* THE PURE STRETCH, AT EVERY SCALE: the identity at the layout width and for
  a narrower band, column 46 on the band's edge, monotone, and the bottom
  band's TWindows[] rows keeping every shared edge and never overlapping a
  neighbour they did not overlap unstretched. *)
procedure TMainLayoutTests.Test_StretchXKeepsEveryEdge;
const
   EXTRA: array[0..5] of integer = (1, 7, 23, 45, 99, 640);
var
   w, x, k, band: integer;
   a, b: TMainWindowElement;
   ra, rb, sa, sb: TRect;
begin
   BeginTest('MainLayout: StretchX is the identity at the layout width, ends on the ' +
             'band''s edge, is monotone and keeps every shared edge');
   for w := WS_MIN to WS_MAX do
      begin
      for x := 0 to LayoutWidth(w) do
         begin
         CheckEquals(x, StretchX(x, LayoutWidth(w), w),
                     Format('ws %d: x %d at the layout width', [w, x]));
         end;
      CheckEquals(100, StretchX(100, LayoutWidth(w) - 10, w),
                  Format('ws %d: a band narrower than the layout is not squeezed', [w]));
      CheckEquals(100, StretchX(100, 0, w), Format('ws %d: no band width, no stretch', [w]));

      for k := Low(EXTRA) to High(EXTRA) do
         begin
         band := LayoutWidth(w) + EXTRA[k];
         CheckEquals(band, StretchX(LayoutWidth(w), band, w),
                     Format('ws %d, band %d: column 46 is the band''s edge', [w, band]));
         CheckEquals(0, StretchX(0, band, w), Format('ws %d, band %d: column 0 stays', [w, band]));
         for x := 0 to LayoutWidth(w) - 1 do
            begin
            if StretchX(x, band, w) > StretchX(x + 1, band, w) then
               begin
               CheckTrue(False, Format('ws %d, band %d: StretchX falls between %d and %d',
                                       [w, band, x, x + 1]));
               Break;
               end;
            end;

         for a := Low(TMainWindowElement) to High(TMainWindowElement) do
            begin
            if (not ElementHasPanel(a)) or (ElementBand(a) <> mbBottom) then
               begin
               Continue;
               end;
            ra := ElementRect(a, w);
            sa := StretchRect(ra, band, w);
            CheckEquals(ra.Top, sa.Top, 'the stretch moves no top edge');
            CheckEquals(ra.Bottom, sa.Bottom, 'the stretch moves no bottom edge');
            CheckTrue(sa.Right <= band, Format('ws %d: %d ends inside the band', [w, Ord(a)]));
            for b := Low(TMainWindowElement) to High(TMainWindowElement) do
               begin
               if (a = b) or (not ElementHasPanel(b)) or (ElementBand(b) <> mbBottom) then
                  begin
                  Continue;
                  end;
               rb := ElementRect(b, w);
               sb := StretchRect(rb, band, w);
               if ra.Right = rb.Left then
                  begin
                  CheckEquals(sa.Right, sb.Left,
                              Format('ws %d, band %d: elements %d and %d share an edge',
                                     [w, band, Ord(a), Ord(b)]));
                  end;
               if (not RectsOverlap(ra, rb)) and RectsOverlap(sa, sb) then
                  begin
                  CheckTrue(False, Format('ws %d, band %d: elements %d and %d overlap stretched',
                                          [w, band, Ord(a), Ord(b)]));
                  end;
               end;
            end;
         end;
      end;
end;

(* THE SHOWN WINDOW, ARMED, A LITTLE WIDER THAN ITS SCALE: ws holds, the bottom
  band reaches the right edge with nothing clipped or overlapping, a height-only
  resize moves no x, and the layout width brings back the exact bounds. *)
procedure TMainLayoutTests.Test_TheBottomBandStretchesToTheWidth;
const
   (* Below the step-up threshold, LayoutWidth(18) + WS_STEP_UP_SLACK. *)
   WIDENING = 30;
var
   saved: TSavedLayoutState;
   bottom: TList<TControl>;
   at17: TList<TRect>;
   e, f: TMainWindowElement;
   i, widest, reach: integer;
   endsAt46: boolean;
   r: TRect;
begin
   BeginTest('MainLayout: the bottom band stretches to the window''s width between ' +
             'scale steps');
   saved := TSavedLayoutState.Create;
   bottom := TList<TControl>.Create;
   at17 := TList<TRect>.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;
      ApplyMainWindowScale(17);
      CreateTR4WEditableLog(0, TopBandHeight(17), LayoutWidth(17),
                            LogHeightForRows(MAIN_LOG_START_ROWS, 17));
      SizeAndLayOut(17);
      ShowTestMainWindow;
      if not DesktopFits(18) then
         begin
         Exit;
         end;
      TR4WMainForm.ClientHeight := MinClientHeight(17) + MainStatusBarHeight + 40;
      Settle;
      TR4WMainForm.ClientWidth := LayoutWidth(17);
      Settle;
      TR4WMainForm.ArmScaling;
      Settle;
      CheckEquals(17, ws, 'armed at 46 * 17');

      endsAt46 := False;
      for e := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if (not ElementHasPanel(e)) or (ElementBand(e) <> mbBottom) or
            (e = mweAutoSendCount) or (MainElement(e) = nil) then
            begin
            Continue;
            end;
         bottom.Add(MainElement(e));
         at17.Add(MainElement(e).BoundsRect);
         if TWindows[e].mweiX + TWindows[e].mweiWidth = LAYOUT_COLUMNS then
            begin
            endsAt46 := True;
            end;
         end;
      bottom.Add(TR4WCallEdit);
      at17.Add(TR4WCallEdit.BoundsRect);
      bottom.Add(TR4WExchangeEdit);
      at17.Add(TR4WExchangeEdit.BoundsRect);

      (* WIDER, BUT NOT BY A STEP. *)
      TR4WMainForm.ClientWidth := LayoutWidth(17) + WIDENING;
      Settle;
      CheckEquals(17, ws, 'a window 30 px wider keeps ws 17');
      CheckLaidOutAt(17, 'stretched by 30');
      CheckEveryControlInsideItsParent('stretched by 30');

      widest := 0;
      for i := 0 to bottom.Count - 1 do
         begin
         reach := bottom[i].Left + bottom[i].Width;
         if reach > widest then
            begin
            widest := reach;
            end;
         end;
      WriteLn('  [MainLayout] stretched: client ', TR4WMainForm.ClientWidth,
              ', the bottom band reaches ', widest);
      if endsAt46 then
         begin
         CheckEquals(TR4WMainForm.ClientWidth, widest,
                     'the rightmost bottom-band element ends on the window''s right edge');
         end
      else
         begin
         CheckTrue(widest <= TR4WMainForm.ClientWidth, 'nothing passes the right edge');
         end;

      (* NO OVERLAP THAT WAS NOT THERE AT THE LAYOUT WIDTH. *)
      for e := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if (e = High(TMainWindowElement)) or
            (not ElementHasPanel(e)) or (ElementBand(e) <> mbBottom) or
            (e = mweAutoSendCount) or (MainElement(e) = nil) then
            begin
            Continue;
            end;
         for f := Succ(e) to High(TMainWindowElement) do
            begin
            if (not ElementHasPanel(f)) or (ElementBand(f) <> mbBottom) or
               (f = mweAutoSendCount) or (MainElement(f) = nil) then
               begin
               Continue;
               end;
            if (not RectsOverlap(ElementRect(e, 17), ElementRect(f, 17))) and
               RectsOverlap(MainElement(e).BoundsRect, MainElement(f).BoundsRect) then
               begin
               CheckTrue(False, Format('stretched: %s overlaps %s',
                                       [MainElement(e).Name, MainElement(f).Name]));
               end;
            end;
         end;

      (* TALLER ONLY: no x moves. *)
      r := TR4WCallEdit.BoundsRect;
      TR4WMainForm.ClientHeight := TR4WMainForm.ClientHeight + 20;
      Settle;
      CheckEquals(r.Left, TR4WCallEdit.Left, 'taller: the call field''s left edge holds');
      CheckEquals(r.Right - r.Left, TR4WCallEdit.Width, 'taller: the call field''s width holds');

      (* BACK TO THE LAYOUT WIDTH: exactly what it was. *)
      TR4WMainForm.ClientWidth := LayoutWidth(17);
      Settle;
      for i := 0 to bottom.Count - 1 do
         begin
         CheckTrue(SameBounds(bottom[i].BoundsRect, at17[i]),
                   Format('back at 46 * 17, %s is %s, was %s',
                          [bottom[i].Name, BoundsText(bottom[i].BoundsRect),
                           BoundsText(at17[i])]));
         end;
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
      at17.Free;
      bottom.Free;
   end;
end;

(* THE LOG'S CELL PADDING: 3 px at every ordinary font, growing with a large
  one, never falling. *)
procedure TMainLayoutTests.Test_TheLogCellPadGrowsWithTheFont;
var
   h: integer;
begin
   BeginTest('MainLayout: the log''s cell padding is 3 px at ordinary fonts and grows ' +
             'with the font (the QsS / Callsign headings at ws 43)');
   CheckEquals(3, LogCellPad(0), 'no height: the floor');
   CheckEquals(3, LogCellPad(17), 'the ws 17 font: 3 px, as before');
   CheckEquals(3, LogCellPad(23), 'up to a 23 px text height: 3 px, as before');
   CheckTrue(LogCellPad(ElementFontHeight(WS_MAX, 2)) >= 7,
             Format('at ws %d the pad is %d', [WS_MAX, LogCellPad(ElementFontHeight(WS_MAX, 2))]));
   for h := 0 to 120 do
      begin
      CheckTrue(LogCellPad(h) <= LogCellPad(h + 1),
                Format('the pad never falls as the font grows (%d)', [h]));
      end;
end;

procedure TMainLayoutTests.RunAllTests;
begin
   Test_EveryRectInsideItsBandAndWhereItWasAtEveryScale;
   Test_LayOutReproducesTheDesignedFormAndMovesWithTheScale;
   Test_TheBandsFollowTheWindow;
   Test_GridlinesLeaveATallLogAlone;
   Test_TheMinimumHeightShowsThreeLogRows;
   Test_ScaleForClientAtItsBoundaries;
   Test_TheScaleFollowsTheWidth;
   Test_AShortWindowCapsTheScale;
   Test_StretchXKeepsEveryEdge;
   Test_TheBottomBandStretchesToTheWidth;
   Test_TheLogCellPadGrowsWithTheFont;
end;

end.
