unit uTestWindowSnap;
{$I ..\..\src\tr4w.inc}

(* THE EDGE-SNAP RULE, PINNED.

  It is pure arithmetic on six integers, so it is testable without a form, a
  widget set or a message -- which it was NOT while it lived inside
  WMWindowPosChanging. The only check it ever had was Test-MainWindowEvents
  driving a real window with SetWindowPos, and that harness needs a built
  binary, a staged contest and a visible desktop.

  Two callers share this now (the caption drag via LM_WINDOWPOSCHANGING, the
  body drag via the form's own mouse handlers), which is the reason the rule
  had to come out of the message handler at all -- and the reason it is worth
  pinning: a change made for one path silently applies to the other. *)

interface

uses
   uTR4WTestFramework;

type
   TTestWindowSnap = class(TTestCase)
   protected
      procedure TestNearLeftSnapsFlush;
      procedure TestNearTopSnapsFlush;
      procedure TestMidScreenIsLeftAlone;
      procedure TestJustOutsideRangeIsLeftAlone;
      procedure TestFarEdgesSnapUsingTheSize;
      procedure TestSnapsToWorkAreaNotToZero;
      procedure TestOvershootSnapsBack;
      procedure TestZeroSizeCannotReachFarEdges;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uWindowSnap;

const
   { A 1920x1080 screen with a 40px taskbar along the bottom. }
   WL = 0;
   WT = 0;
   WR = 1920;
   WB = 1040;

   { A window the size the main form actually is. }
   FW = 1028;
   FH = 700;

procedure TTestWindowSnap.TestNearLeftSnapsFlush;
var
   l, t: integer;
begin
   l := 15;          // inside SNAP (20) of the left edge
   t := 400;
   SnapWindowToEdges(l, t, FW, FH, WL, WT, WR, WB);
   CheckEquals(WL,  l, 'left snapped flush');
   CheckEquals(400, t, 'top untouched');
end;

procedure TTestWindowSnap.TestNearTopSnapsFlush;
var
   l, t: integer;
begin
   l := 400;
   t := 19;
   SnapWindowToEdges(l, t, FW, FH, WL, WT, WR, WB);
   CheckEquals(400, l, 'left untouched');
   CheckEquals(WT,  t, 'top snapped flush');
end;

procedure TTestWindowSnap.TestMidScreenIsLeftAlone;
var
   l, t: integer;
begin
   (* THE CONTROL CASE. A rule that snaps everything looks identical to a
     rule that works, until a window will not sit where it is put. *)
   l := 500;
   t := 300;
   SnapWindowToEdges(l, t, FW, FH, WL, WT, WR, WB);
   CheckEquals(500, l, 'left untouched mid-screen');
   CheckEquals(300, t, 'top untouched mid-screen');
end;

procedure TTestWindowSnap.TestJustOutsideRangeIsLeftAlone;
var
   l, t: integer;
begin
   (* THE BOUNDARY IS EXCLUSIVE: < SNAP, not <=. Pinned because an off-by-one
     here is invisible on screen and would only ever show as "it snaps from
     one pixel further away than it used to". *)
   l := WINDOW_SNAP_DISTANCE;
   t := WINDOW_SNAP_DISTANCE;
   SnapWindowToEdges(l, t, FW, FH, WL, WT, WR, WB);
   CheckEquals(WINDOW_SNAP_DISTANCE, l, 'exactly SNAP away does not snap');
   CheckEquals(WINDOW_SNAP_DISTANCE, t, 'exactly SNAP away does not snap');
end;

procedure TTestWindowSnap.TestFarEdgesSnapUsingTheSize;
var
   l, t: integer;
begin
   (* The far arms are the ones that need aWidth/aHeight, and they are why a
     programmatic SetWindowPos with SWP_NOSIZE does not snap. *)
   l := WR - FW - 5;
   t := WB - FH - 5;
   SnapWindowToEdges(l, t, FW, FH, WL, WT, WR, WB);
   CheckEquals(WR - FW, l, 'right edge flush with the work area');
   CheckEquals(WB - FH, t, 'bottom edge flush with the work area');
end;

procedure TTestWindowSnap.TestSnapsToWorkAreaNotToZero;
var
   l, t: integer;
begin
   (* THE ORIGINAL SNAPPED THE NEAR EDGES TO LITERAL 0.

     With a taskbar docked LEFT or TOP the work area does not start at 0, and
     0 puts the window UNDERNEATH the taskbar. It never showed because the
     usual taskbar is along the bottom, where work.Left is 0 and the two
     answers agree. This is the case that tells them apart: a 120px taskbar
     on the left. *)
   l := 130;         // 10 px inside the work area's left edge
   t := 500;
   SnapWindowToEdges(l, t, FW, FH, 120, WT, WR, WB);
   CheckEquals(120, l, 'snaps to the work area, not under the taskbar');
end;

procedure TTestWindowSnap.TestOvershootSnapsBack;
var
   l, t: integer;
begin
   (* Dragged slightly PAST the edge -- negative, or beyond the far side. The
     rule is a distance, so it pulls back as well as forward. *)
   l := -8;
   t := WB - FH + 9;
   SnapWindowToEdges(l, t, FW, FH, WL, WT, WR, WB);
   CheckEquals(WL,      l, 'pulled back from off-screen left');
   CheckEquals(WB - FH, t, 'pulled back from below the work area');
end;

procedure TTestWindowSnap.TestZeroSizeCannotReachFarEdges;
var
   l, t: integer;
begin
   (* A NOSIZE message leaves cx and cy at zero, and this pins that such a
     move is NOT snapped to the far edges -- the behaviour the harness
     header and the unit both describe. A window restored to a saved
     position must land where it was saved. *)
   l := 500;
   t := 300;
   SnapWindowToEdges(l, t, 0, 0, WL, WT, WR, WB);
   CheckEquals(500, l, 'a sizeless move is not pulled to the right edge');
   CheckEquals(300, t, 'a sizeless move is not pulled to the bottom edge');
end;

procedure TTestWindowSnap.RunAllTests;
begin
   TestNearLeftSnapsFlush;
   TestNearTopSnapsFlush;
   TestMidScreenIsLeftAlone;
   TestJustOutsideRangeIsLeftAlone;
   TestFarEdgesSnapUsingTheSize;
   TestSnapsToWorkAreaNotToZero;
   TestOvershootSnapsBack;
   TestZeroSizeCannotReachFarEdges;
end;

end.
