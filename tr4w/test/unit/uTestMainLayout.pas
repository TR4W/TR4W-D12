unit uTestMainLayout;
{$I ..\..\src\tr4w.inc}

(*
  THE MAIN WINDOW'S LAYOUT, AT EVERY SCALE (plan stage e2,
  docs/MAIN_WINDOW_WIDTH_PLAN.md).

  Until now nothing checked the layout at any ws but 17: Lint-FormOverlap
  reads the .lfm, which is the ws-17 picture. Four things are pinned here.

  1. THE ARITHMETIC (uMainLayout, no form): at every ws from WS_MIN to WS_MAX,
     no two controls overlap and nothing runs past 46 * ws. Two overlaps exist
     today and are pinned BY NAME, each with the condition under which it
     happens; a pinned overlap that stops happening fails too, so the pin is
     removed by whoever fixes it.

  2. THE SAME BOUNDS (the streamed main form): LayOutMainWindow at ws 17 puts
     every generated panel exactly where uMainForm.lfm has it. That is an
     INDEPENDENT oracle: tools/gen_main_elements.py writes the .lfm from its own
     Python copy of the formulas and Lint-MainElements pins it. Then ws 13 is
     checked against literals worked out by hand from the arithmetic as it stood
     at d689fef9 (before the extraction), then ws 17 again, then a second call
     changes nothing.

  3. THE ANCHORS AFTER A RE-LAYOUT (plan risk d2), on the form shown off
     screen: after LayOutMainWindow at another scale, growing the window moves
     every bottom-anchored control by exactly the growth. Read from the LCL
     (control.inc: SetBounds re-captures the anchor base when it moves a
     control) and NOT measured when written -- this test is what decides it.

  4. SHOW GRIDLINES (plan stage e1): on the shown form, with the log grid, a
     gridline toggle leaves a log the window made taller as it is.

  Tests 2 to 4 follow the program's start-up order as far as it runs without
  a contest: the form streamed, its window made, the grids bound, then
  LayOutMainWindow, and in tests 3 and 4 MakeMainWindowResizeable and
  AnchorMainWindowControls after it, as CreateMainWindow calls them.

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
   protected
      procedure Test_NoOverlapAndInsideTheWidthAtEveryScale;
      procedure Test_LayOutReproducesTheDesignedFormAndMovesWithTheScale;
      procedure Test_BottomAnchorsHoldAfterARelayout;
      procedure Test_GridlinesLeaveATallLogAlone;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Generics.Collections, Forms, Controls, StdCtrls, ComCtrls,
   VC, uSettingsModel, uMainLayout, uElementPanel, uMainForm, uMainGrids,
   MainUnit,
   LogWind,          (* DispalayLogGridLines -- the SHOW GRIDLINES arm *)
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

(* ---------------------------------------------------------------------------
  THE PURE HALF.
  --------------------------------------------------------------------------- *)

type
   TNamedRect = class
   public
      Name: string;
      Rect: TRect;
      constructor Create(const aName: string; const aRect: TRect);
   end;

   TNamedRects = TObjectList<TNamedRect>;

constructor TNamedRect.Create(const aName: string; const aRect: TRect);
begin
   inherited Create;
   Name := aName;
   Rect := aRect;
end;

(* Every control the layout places, at aWS with the minimum log. aMinitour adds
  the minitour row and narrows the quick-command panel, as LayOutMainWindow
  does when MINITOUR DURATION is set. The caller frees the list. *)
function LayoutRects(const aWS: integer; const aMinitour: boolean): TNamedRects;
var
   e: TMainWindowElement;
   logH, c, r, row, i, left, width, stripLeft, pitch: integer;
begin
   Result := TNamedRects.Create(True);
   logH := LogHeightForRows(MAIN_LOG_MINIMUM_ROWS, aWS);

   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if not ElementHasPanel(e) then
         begin
         Continue;
         end;
      if aMinitour and (e = mweQuickCommand) then
         begin
         Result.Add(TNamedRect.Create('element ' + TWindows[e].mweName,
                                      MinitourQuickCommandRect(aWS, logH)));
         end
      else
         begin
         Result.Add(TNamedRect.Create('element ' + TWindows[e].mweName,
                                      ElementRect(e, aWS, logH)));
         end;
      end;

   Result.Add(TNamedRect.Create('log', LogRect(aWS, logH)));
   Result.Add(TNamedRect.Create('call field', EntryFieldRect(efrCall, aWS, logH)));
   Result.Add(TNamedRect.Create('exchange field', EntryFieldRect(efrExchange, aWS, logH)));
   Result.Add(TNamedRect.Create('last-hour bar', LastHourBarRect(aWS, logH)));
   Result.Add(TNamedRect.Create('rate bar', RateBarRect(aWS, logH)));
   Result.Add(TNamedRect.Create('possible-call strip', PossibleCallRect(aWS, logH)));
   if aMinitour then
      begin
      Result.Add(TNamedRect.Create('tour bar', TourDurationBarRect(aWS, logH)));
      Result.Add(TNamedRect.Create('tour text', TourDurationTextRect(aWS, logH)));
      end;

   for c := 0 to TOTALS_COLUMNS - 1 do
      begin
      TotalsColumnGeometry(aWS, c, left, width);
      for r := 0 to TOTALS_ROWS - 1 do
         begin
         Result.Add(TNamedRect.Create(Format('totals cell %d,%d', [c, r]),
                                      Bounds(left, aWS * 2 + r * aWS, width, aWS)));
         end;
      if c >= TOTALS_FIRST_HEADER then
         begin
         Result.Add(TNamedRect.Create(Format('totals head %d', [c]),
                                      Bounds(left, 0, width, aWS * 2)));
         end;
      end;

   (* As uMainGrids.PositionMainGrids places them: rows 1 and 2 of each strip,
     a label and six band cells two pixels narrower than the pitch. *)
   stripLeft := NeedLeft(LayoutWidth(aWS), aWS);
   pitch := NeedCellPitch(aWS);
   for row := 1 to 2 do
      begin
      Result.Add(TNamedRect.Create(Format('QSO need label %d', [row]),
                                   Bounds(stripLeft, aWS * row, pitch, aWS)));
      Result.Add(TNamedRect.Create(Format('mult need label %d', [row]),
                                   Bounds(stripLeft, aWS * (row + 3), pitch, aWS)));
      for i := 1 to 6 do
         begin
         Result.Add(TNamedRect.Create(Format('QSO need %d,%d', [row, i]),
                                      Bounds(stripLeft + i * pitch, aWS * row,
                                             pitch - 2, aWS)));
         Result.Add(TNamedRect.Create(Format('mult need %d,%d', [row, i]),
                                      Bounds(stripLeft + i * pitch, aWS * (row + 3),
                                             pitch - 2, aWS)));
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

procedure TMainLayoutTests.Test_NoOverlapAndInsideTheWidthAtEveryScale;
var
   scale, i, j, known: integer;
   minitour: boolean;
   rects: TNamedRects;
begin
   BeginTest('MainLayout: no two controls overlap, and none runs past 46 * ws, at every scale');
   for minitour := False to True do
      begin
      for scale := WS_MIN to WS_MAX do
         begin
         rects := LayoutRects(scale, minitour);
         try
            known := 0;
            for i := 0 to rects.Count - 1 do
               begin
               CheckTrue((rects[i].Rect.Left >= 0) and
                         (rects[i].Rect.Right <= LayoutWidth(scale)),
                         Format('ws %d: %s spans %d..%d, outside 0..%d',
                                [scale, rects[i].Name, rects[i].Rect.Left,
                                 rects[i].Rect.Right, LayoutWidth(scale)]));
               CheckTrue(rects[i].Rect.Bottom <= MinClientHeight(scale),
                         Format('ws %d: %s ends at %d, below the layout''s %d',
                                [scale, rects[i].Name, rects[i].Rect.Bottom,
                                 MinClientHeight(scale)]));
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
      FWS, FWS2, FChildsWidth, FLogHeight: integer;
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
   FLogHeight := EditableLogHeight;
   FMinitour := Settings.Contest.MinitourDuration;
end;

procedure TSavedLayoutState.Restore;
begin
   ws := FWS;
   ws2 := FWS2;
   MainWindowChildsWidth := FChildsWidth;
   EditableLogHeight := FLogHeight;
   Settings.Contest.MinitourDuration := FMinitour;
end;

(* THE STREAMED MAIN FORM, WITH WHAT CreateMainWindow GIVES IT BEFORE THE
  LAYOUT: its window (CreateTR4WMainForm calls HandleNeeded, and the element
  setters ask for one), the grids bound, and two entry fields. The log grid is
  not built: building it reads the contest log. *)
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
   edit.Parent := TR4WMainForm;
   TR4WCallEdit := edit;

   edit := TEdit.Create(TR4WMainForm);
   edit.AutoSize := False;
   edit.Parent := TR4WMainForm;
   TR4WExchangeEdit := edit;
end;

procedure ReleaseTestMainWindow;
begin
   (* The edits are the form's; the globals would point into it. *)
   TR4WCallEdit := nil;
   TR4WExchangeEdit := nil;
   ReleaseTestMainForm;
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

function BoundsOf(const aName: string): TRect;
var
   c: TControl;
begin
   Result := Bounds(-1, -1, 0, 0);
   c := ControlNamed(aName);
   if c <> nil then
      begin
      Result := c.BoundsRect;
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

procedure TMainLayoutTests.Test_LayOutReproducesTheDesignedFormAndMovesWithTheScale;
const
   (* The log at five rows: 30 + 5 * (ws + 2). *)
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
   expected: TRect;
begin
   BeginTest('MainLayout: ws 17 reproduces uMainForm.lfm, ws 13 moves every control, ' +
             'and a second call changes nothing');
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

      (* THE ORACLE, BEFORE ANYTHING IS LAID OUT. *)
      for i := 0 to TR4WMainForm.ControlCount - 1 do
         begin
         c := TR4WMainForm.Controls[i];
         if IsDesignedLayoutControl(c) then
            begin
            controls.Add(c);
            designed.Add(c.BoundsRect);
            end;
         end;
      WriteLn('  [MainLayout] ', controls.Count, ' designed controls on the form');
      CheckTrue(controls.Count > 100,
                'the form carries its generated panels (the totals grid alone is 39)');

      (* WS 17: THE .lfm, EXACTLY. *)
      LayOutMainWindow(17, LOG_17);
      for i := 0 to controls.Count - 1 do
         begin
         CheckTrue(SameBounds(controls[i].BoundsRect, designed[i]),
                   Format('ws 17: %s is %s, the .lfm has %s',
                          [controls[i].Name, BoundsText(controls[i].BoundsRect),
                           BoundsText(designed[i])]));
         end;
      (* Not in the .lfm's picture: worked out from the arithmetic. *)
      CheckBounds('call field', TR4WCallEdit.BoundsRect, 255, 261, 221, 24, 'ws 17');
      CheckBounds('exchange field', TR4WExchangeEdit.BoundsRect, 255, 286, 221, 24, 'ws 17');
      CheckBounds('possible-call strip', TR4WMainForm.lstPossibleCall.BoundsRect,
                  0, 346, 782, 17, 'ws 17');
      CheckEquals(782, MainWindowChildsWidth, 'ws 17: the layout width');
      CheckEquals(LOG_17, EditableLogHeight, 'ws 17: the log height the band hangs from');

      (* WS 13: LITERALS, worked out by hand from the arithmetic at d689fef9. *)
      LayOutMainWindow(13, LOG_13);
      CheckEquals(13, ws, 'ws 13: the scale global');
      CheckEquals(598, MainWindowChildsWidth, 'ws 13: the layout width');
      CheckBounds('pnlBandMode', BoundsOf('pnlBandMode'), 0, 196, 52, 13, 'ws 13');
      CheckBounds('pnlQSONumber', BoundsOf('pnlQSONumber'), 143, 196, 52, 26, 'ws 13');
      CheckBounds('pnlInsert', BoundsOf('pnlInsert'), 546, 196, 52, 13, 'ws 13');
      CheckBounds('pnlCQTotal', BoundsOf('pnlCQTotal'), 494, 222, 104, 13, 'ws 13');
      CheckBounds('pnlWSJTX', BoundsOf('pnlWSJTX'), 104, 222, 39, 13, 'ws 13');
      CheckBounds('pbLastHour', BoundsOf('pbLastHour'), 364, 235, 65, 13, 'ws 13');
      CheckBounds('pnlTotalHead_1', BoundsOf('pnlTotalHead_1'), 65, 0, 32, 26, 'ws 13');
      CheckBounds('pnlTotalHead_7', BoundsOf('pnlTotalHead_7'), 257, 0, 39, 26, 'ws 13');
      CheckBounds('pnlTotalCell_7_3', BoundsOf('pnlTotalCell_7_3'), 257, 65, 39, 13, 'ws 13');
      CheckBounds('pnlQSONeedR1Label', BoundsOf('pnlQSONeedR1Label'), 416, 13, 26, 13, 'ws 13');
      CheckBounds('pnlMultNeedR2_10', BoundsOf('pnlMultNeedR2_10'), 572, 65, 24, 13, 'ws 13');
      CheckBounds('call field', TR4WCallEdit.BoundsRect, 195, 209, 169, 18, 'ws 13');
      CheckBounds('exchange field', TR4WExchangeEdit.BoundsRect, 195, 228, 169, 18, 'ws 13');
      CheckBounds('possible-call strip', TR4WMainForm.lstPossibleCall.BoundsRect,
                  0, 274, 598, 13, 'ws 13');

      (* EVERY PANEL, not only the literals: at its uMainLayout rectangle. *)
      for e := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if (not ElementHasPanel(e)) or (MainElement(e) = nil) or
            (e = mweAutoSendCount) then
            begin
            Continue;
            end;
         expected := ElementRect(e, 13, LOG_13);
         CheckTrue(SameBounds(MainElement(e).BoundsRect, expected),
                   Format('ws 13: %s is %s, the layout says %s',
                          [MainElement(e).Name, BoundsText(MainElement(e).BoundsRect),
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
      LayOutMainWindow(17, LOG_17);
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
         afterFirst.Add(controls[i].BoundsRect);
         if controls[i] is TElementPanel then
            begin
            fonts.Add(TElementPanel(controls[i]).Font.Height);
            end
         else
            begin
            fonts.Add(0);
            end;
         end;
      LayOutMainWindow(17, LOG_17);
      for i := 0 to controls.Count - 1 do
         begin
         CheckTrue(SameBounds(controls[i].BoundsRect, afterFirst[i]),
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

(* PLAN RISK d2, DECIDED HERE. CreateMainWindow's order -- place, size the
  window, anchor -- is what makes the anchors right at startup. A layout run
  again later places controls that are ALREADY anchored. If the LCL re-captures
  each moved control's anchor base (control.inc, ChangeBounds ->
  UpdateAnchorRules), growing the window afterwards moves every bottom-anchored
  control by exactly the growth; if it does not, they jump, and the band
  containers of plan stage e5 are what replaces the anchors. *)
procedure TMainLayoutTests.Test_BottomAnchorsHoldAfterARelayout;
const
   GROWTH = 40;
var
   saved: TSavedLayoutState;
   watched: TList<TControl>;
   before: TList<integer>;
   e: TMainWindowElement;
   logH: integer;

   procedure Watch(const aControl: TControl);
   begin
      if (aControl <> nil) and aControl.Visible then
         begin
         watched.Add(aControl);
         end;
   end;

   procedure GrowAndCheck(const aWhere: string);
   var
      k: integer;
   begin
      before.Clear;
      for k := 0 to watched.Count - 1 do
         begin
         before.Add(watched[k].Top);
         end;
      TR4WMainForm.ClientHeight := TR4WMainForm.ClientHeight + GROWTH;
      Settle;
      for k := 0 to watched.Count - 1 do
         begin
         CheckEquals(before[k] + GROWTH, watched[k].Top,
                     Format('%s: %s followed the bottom edge', [aWhere, watched[k].Name]));
         end;
   end;

begin
   BeginTest('MainLayout: after a layout at another scale, the bottom band still ' +
             'follows the window''s bottom edge (plan risk d2)');
   saved := TSavedLayoutState.Create;
   watched := TList<TControl>.Create;
   before := TList<integer>.Create;
   BuildTestMainWindow;
   try
      Settings.Contest.MinitourDuration := 0;

      (* CreateMainWindow's own sequence, at ws 17. *)
      LayOutMainWindow(17, LogHeightForRows(MAIN_LOG_MINIMUM_ROWS, 17));
      MakeMainWindowResizeable(MainWindowChildsWidth,
                               FixedBandsHeight(17) + EditableLogHeight + MainStatusBarHeight);
      AnchorMainWindowControls;

      (* Shown, because anchors are applied when a shown form is resized. Its
        activation handler moves focus and repaints the function keys, which
        is the running program's business, not this test's. *)
      TR4WMainForm.OnActivate := nil;
      ShowOffScreen(TR4WMainForm);

      for e := Low(TMainWindowElement) to High(TMainWindowElement) do
         begin
         if ElementHasPanel(e) and (TWindows[e].mweB = 1) and (e <> mweAutoSendCount) then
            begin
            Watch(MainElement(e));
            end;
         end;
      Watch(TR4WCallEdit);
      Watch(TR4WExchangeEdit);
      Watch(ControlNamed('pbLastHour'));
      Watch(ControlNamed('pbRate'));
      WriteLn('  [MainLayout] watching ', watched.Count, ' bottom-band controls');
      CheckTrue(watched.Count > 20, 'the bottom band has its controls');

      (* The startup anchoring, as a baseline. *)
      GrowAndCheck('after startup');

      (* THE QUESTION: re-laid out at ws 13 for the window's current height,
        then grown. *)
      logH := TR4WMainForm.ClientHeight - MainStatusBarHeight - FixedBandsHeight(13);
      WriteLn('  [MainLayout] re-laying out at ws 13 with a ', logH, ' px log');
      LayOutMainWindow(13, logH);
      Settle;
      CheckBounds('call field', TR4WCallEdit.BoundsRect,
                  195, logH + 13 * 8, 169, 18, 'ws 13 re-layout');
      GrowAndCheck('after a re-layout at ws 13');
   finally
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
      watched.Free;
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
      CreateTR4WEditableLog(0, 17 * 7, LayoutWidth(17),
                            LogHeightForRows(MAIN_LOG_MINIMUM_ROWS, 17));
      LayOutMainWindow(17, LogHeightForRows(MAIN_LOG_MINIMUM_ROWS, 17));
      MakeMainWindowResizeable(MainWindowChildsWidth,
                               FixedBandsHeight(17) + EditableLogHeight + MainStatusBarHeight);
      AnchorMainWindowControls;
      TR4WMainForm.OnActivate := nil;
      ShowOffScreen(TR4WMainForm);

      logBefore := TR4WEditableLog.BoundsRect;
      TR4WMainForm.ClientHeight := TR4WMainForm.ClientHeight + GROWTH;
      Settle;
      CheckEquals((logBefore.Bottom - logBefore.Top) + GROWTH,
                  TR4WEditableLog.Height, 'the log took the window''s growth');

      logBefore := TR4WEditableLog.BoundsRect;
      callTop := TR4WCallEdit.Top;

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
      CheckEquals(callTop, TR4WCallEdit.Top, 'the gridline toggle moved the call field');
   finally
      (* The grid is the form's; the global would point into it. *)
      TR4WEditableLog := nil;
      ReleaseTestMainWindow;
      saved.Restore;
      saved.Free;
   end;
end;

procedure TMainLayoutTests.RunAllTests;
begin
   Test_NoOverlapAndInsideTheWidthAtEveryScale;
   Test_LayOutReproducesTheDesignedFormAndMovesWithTheScale;
   Test_BottomAnchorsHoldAfterARelayout;
   Test_GridlinesLeaveATallLogAlone;
end;

end.
