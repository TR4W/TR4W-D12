unit uTestAltDragMove;
{$I ..\..\src\tr4w.inc}

(*
  ALT + DRAG MOVES A BORDERLESS TOOL WINDOW: uAltDragMove.

  NO CAPTION leaves a tool window with no frame, and Alt + left-button drag
  anywhere inside it is how it moves now. What a test without a screen can
  pin is the arithmetic and the decisions:

  - the new top-left is the start plus the pointer's movement, in screen
    coordinates, and no movement is no change;
  - the clamp keeps a 40 pixel strip on SOME monitor, judged per monitor --
    a window in the dead corner of an L-shaped desktop is pulled onto the
    nearest monitor, not left inside the desktop's bounding rectangle;
  - Alt starts it and AltGr (Ctrl+Alt) does not;
  - only a registered, borderless, non-modal tool window that is not the
    main form is eligible;
  - the hook follows the form's controls, run-time children included, and
    lets go of every one when the form is freed.

  The drag itself (capture, the moves, a native control's own click) needs a
  running program; that is on docs/BENCH_QUEUE.md.
*)

interface

uses
   uTR4WTestFramework;

type
   TAltDragMoveTests = class(TTestCase)
   protected
      procedure Test_TheNewTopLeftIsTheStartPlusThePointerDelta;
      procedure Test_AZeroDeltaChangesNothing;
      procedure Test_TheClampKeepsAStripOnOneMonitor;
      procedure Test_TheClampUsesTheNearestOfSeveralMonitors;
      procedure Test_AWindowSmallerThanTheStripStaysWhole;
      procedure Test_AltStartsAndAltGrDoesNot;
      procedure Test_OnlyABorderlessToolWindowIsEligible;
      procedure Test_ARealFormIsEligibleOnlyWhenRegisteredAndBorderless;
      procedure Test_TheHookFollowsTheControlsAndLetsGoOnFree;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Types, Classes, Controls, Forms, StdCtrls, ExtCtrls,
   uAltDragMove;

const
   STRIP = ALT_DRAG_VISIBLE_STRIP;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

procedure TAltDragMoveTests.Test_TheNewTopLeftIsTheStartPlusThePointerDelta;
var
   p: TPoint;
begin
   BeginTest('AltDragTopLeft: the start position plus the pointer movement');
   p := AltDragTopLeft(Point(100, 200), Point(500, 500), Point(530, 480));
   CheckEquals(130, p.X, 'thirty to the right');
   CheckEquals(180, p.Y, 'twenty up');

   p := AltDragTopLeft(Point(-1500, 40), Point(-1200, 300), Point(-1300, 310));
   CheckEquals(-1600, p.X, 'on a monitor left of the primary: negative X is kept');
   CheckEquals(50, p.Y, 'ten down');
end;

procedure TAltDragMoveTests.Test_AZeroDeltaChangesNothing;
var
   p: TPoint;
   monitor: array[0..0] of TRect;
begin
   BeginTest('AltDragTopLeft and the clamp: no movement leaves an on-screen window where it is');
   p := AltDragTopLeft(Point(250, 300), Point(700, 410), Point(700, 410));
   CheckEquals(250, p.X, 'X unchanged');
   CheckEquals(300, p.Y, 'Y unchanged');

   monitor[0] := Rect(0, 0, 1920, 1040);
   p := KeepStripOnAMonitor(Rect(250, 300, 550, 500), monitor, STRIP);
   CheckEquals(250, p.X, 'the clamp leaves X alone');
   CheckEquals(300, p.Y, 'the clamp leaves Y alone');
end;

procedure TAltDragMoveTests.Test_TheClampKeepsAStripOnOneMonitor;
var
   p: TPoint;
   monitor: array[0..0] of TRect;
begin
   BeginTest('KeepStripOnAMonitor: a 300x200 window keeps 40 pixels on screen at every edge');
   monitor[0] := Rect(0, 0, 1920, 1040);

   p := KeepStripOnAMonitor(Rect(1900, 1030, 2200, 1230), monitor, STRIP);
   CheckEquals(1920 - STRIP, p.X, 'off the right: its left 40 pixels stay');
   CheckEquals(1040 - STRIP, p.Y, 'off the bottom: its top 40 pixels stay');

   p := KeepStripOnAMonitor(Rect(-500, -500, -200, -300), monitor, STRIP);
   CheckEquals(STRIP - 300, p.X, 'off the left: its right 40 pixels stay');
   CheckEquals(STRIP - 200, p.Y, 'off the top: its bottom 40 pixels stay');

   p := KeepStripOnAMonitor(Rect(1870, 100, 2170, 300), monitor, STRIP);
   CheckEquals(1870, p.X, 'exactly 50 pixels showing is enough: not moved');
   CheckEquals(100, p.Y, 'and Y is untouched');
end;

procedure TAltDragMoveTests.Test_TheClampUsesTheNearestOfSeveralMonitors;
var
   p: TPoint;
   monitors: array[0..1] of TRect;
begin
   BeginTest('KeepStripOnAMonitor: two monitors, one left of the primary and shorter');
   (* A 1920x1080 monitor at negative X, beside a 2560x1440 primary. The
     corner below the left one is inside the desktop's bounding rectangle
     but on no monitor. *)
   monitors[0] := Rect(-1920, 0, 0, 1080);
   monitors[1] := Rect(0, 0, 2560, 1440);

   p := KeepStripOnAMonitor(Rect(-1000, 100, -700, 300), monitors, STRIP);
   CheckEquals(-1000, p.X, 'wholly on the left monitor: not moved');
   CheckEquals(100, p.Y, 'wholly on the left monitor: Y not moved');

   p := KeepStripOnAMonitor(Rect(-150, 100, 150, 300), monitors, STRIP);
   CheckEquals(-150, p.X, 'straddling the two: not moved');

   p := KeepStripOnAMonitor(Rect(-1000, 1300, -700, 1500), monitors, STRIP);
   CheckEquals(-1000, p.X, 'in the dead corner: X kept');
   CheckEquals(1080 - STRIP, p.Y, 'in the dead corner: pulled up onto the NEAREST monitor');

   p := KeepStripOnAMonitor(Rect(-3000, 100, -2700, 300), monitors, STRIP);
   CheckEquals(-1920 - 300 + STRIP, p.X, 'far left: back onto the left monitor, not the primary');

   p := KeepStripOnAMonitor(Rect(3000, 1500, 3300, 1700), monitors, STRIP);
   CheckEquals(2560 - STRIP, p.X, 'far right and below: the primary, X');
   CheckEquals(1440 - STRIP, p.Y, 'far right and below: the primary, Y');
end;

procedure TAltDragMoveTests.Test_AWindowSmallerThanTheStripStaysWhole;
var
   p: TPoint;
   monitor: array[0..0] of TRect;
   none: array of TRect;
begin
   BeginTest('KeepStripOnAMonitor: a window smaller than the strip is kept whole; no monitors, no change');
   monitor[0] := Rect(0, 0, 1920, 1040);
   p := KeepStripOnAMonitor(Rect(1950, 1050, 1980, 1070), monitor, STRIP);
   CheckEquals(1920 - 30, p.X, 'a 30 pixel wide window ends at the right edge');
   CheckEquals(1040 - 20, p.Y, 'a 20 pixel tall window ends at the bottom edge');

   SetLength(none, 0);
   p := KeepStripOnAMonitor(Rect(5000, 5000, 5300, 5200), none, STRIP);
   CheckEquals(5000, p.X, 'with no monitor to judge against, nothing moves');
end;

procedure TAltDragMoveTests.Test_AltStartsAndAltGrDoesNot;
begin
   BeginTest('AltDragShiftStarts: Alt starts a drag; Ctrl+Alt (AltGr) and no Alt do not');
   CheckTrue(AltDragShiftStarts([ssAlt]), 'Alt');
   CheckTrue(AltDragShiftStarts([ssAlt, ssShift]), 'Alt+Shift');
   CheckTrue(AltDragShiftStarts([ssAlt, ssLeft]), 'Alt with the left button reported');
   CheckFalse(AltDragShiftStarts([ssAlt, ssCtrl]), 'AltGr types a character');
   CheckFalse(AltDragShiftStarts([]), 'a plain click');
   CheckFalse(AltDragShiftStarts([ssShift]), 'Shift alone');
   CheckFalse(AltDragShiftStarts([ssCtrl]), 'Ctrl alone');
end;

procedure TAltDragMoveTests.Test_OnlyABorderlessToolWindowIsEligible;
begin
   BeginTest('FormMovesByAltDrag: a borderless tool window, and nothing else');
   CheckTrue(FormMovesByAltDrag(bsNone, True, False, False), 'borderless tool window');
   CheckFalse(FormMovesByAltDrag(bsSizeable, True, False, False), 'a tool window with a frame');
   CheckFalse(FormMovesByAltDrag(bsToolWindow, True, False, False), 'a tool-window frame is still a frame');
   CheckFalse(FormMovesByAltDrag(bsNone, True, True, False), 'the main form');
   CheckFalse(FormMovesByAltDrag(bsNone, False, False, False), 'a borderless form that is no tool window');
   CheckFalse(FormMovesByAltDrag(bsNone, True, False, True), 'a modal dialog');
end;

procedure TAltDragMoveTests.Test_ARealFormIsEligibleOnlyWhenRegisteredAndBorderless;
var
   form: TForm;
begin
   BeginTest('FormIsAltDragMovable: a real form, registered by EnableAltDragMove and borderless');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   try
      form.BorderStyle := bsNone;
      CheckFalse(FormIsAltDragMovable(form), 'borderless but never registered');

      EnableAltDragMove(form);
      CheckTrue(FormIsAltDragMovable(form), 'registered and borderless');

      form.BorderStyle := bsSizeable;
      CheckFalse(FormIsAltDragMovable(form), 'registered, but it has a frame again');

      CheckFalse(FormIsAltDragMovable(nil), 'no form');
      if Application.MainForm <> nil then
         begin
         CheckFalse(FormIsAltDragMovable(Application.MainForm), 'the main form');
         end;
   finally
      form.Free;
   end;
end;

procedure TAltDragMoveTests.Test_TheHookFollowsTheControlsAndLetsGoOnFree;
var
   before: integer;
   form: TForm;
   panel: TPanel;
   edit: TEdit;
   late: TPanel;
   lbl: TLabel;
begin
   BeginTest('EnableAltDragMove: hooks every windowed control, run-time children too, and lets go on Free');
   InitWidgetSet;
   before := AltDragHookedControlCount;
   form := TForm.CreateNew(nil);
   try
      form.BorderStyle := bsNone;
      panel := TPanel.Create(form);
      panel.Parent := form;
      edit := TEdit.Create(form);
      edit.Parent := panel;
      lbl := TLabel.Create(form);
      lbl.Parent := panel;

      EnableAltDragMove(form);
      CheckEquals(before + 3, AltDragHookedControlCount,
                  'the form, the panel and the edit; a label is reached through its parent');

      EnableAltDragMove(form);
      CheckEquals(before + 3, AltDragHookedControlCount, 'enabling twice hooks nothing twice');

      late := TPanel.Create(form);
      late.Parent := panel;
      CheckEquals(before + 4, AltDragHookedControlCount, 'a child added after the hook is hooked too');

      late.Free;
      CheckEquals(before + 3, AltDragHookedControlCount, 'a freed child is let go');
   finally
      form.Free;
   end;
   CheckEquals(before, AltDragHookedControlCount, 'freeing the form lets go of everything on it');
end;

procedure TAltDragMoveTests.RunAllTests;
begin
   Test_TheNewTopLeftIsTheStartPlusThePointerDelta;
   Test_AZeroDeltaChangesNothing;
   Test_TheClampKeepsAStripOnOneMonitor;
   Test_TheClampUsesTheNearestOfSeveralMonitors;
   Test_AWindowSmallerThanTheStripStaysWhole;
   Test_AltStartsAndAltGrDoesNot;
   Test_OnlyABorderlessToolWindowIsEligible;
   Test_ARealFormIsEligibleOnlyWhenRegisteredAndBorderless;
   Test_TheHookFollowsTheControlsAndLetsGoOnFree;
end;

end.
