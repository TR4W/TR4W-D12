unit uWindowSnap;
{$I tr4w.inc}

(* EDGE SNAPPING, AS ARITHMETIC AND NOTHING ELSE.

  A window being dragged goes flush when it comes within SNAP pixels of an
  edge. That rule used to live inside TTR4WMainForm.WMWindowPosChanging, which
  meant it could only ever be exercised by a Win32 message -- and it now has
  TWO callers that arrive by different routes:

    the CAPTION drag   the system's own move loop, seen as LM_WINDOWPOSCHANGING
                       (Windows only -- no other widget set sends it)

    the BODY drag      TTR4WMainForm's own mouse handlers, which work
                       everywhere and are what a window with no title bar is
                       moved by

  ONE COPY, because two would drift and the drift would be invisible: an
  operator would find that dragging by the title bar snapped and dragging by
  the body did not, or that they snapped to positions eight pixels apart.

  PLAIN INTEGERS, NOT TRect. This unit links no LCL and no Windows, so the
  rule is unit-testable without booting a form -- and `TRect` is ambiguous in
  the form that calls this (Windows.TRect and Types.TRect are different
  declarations, which uMainForm's uses clause already warns about).

  A NOTE ON WHAT IS *NOT* SYMMETRIC HERE, carried over deliberately rather
  than tidied: the near edges snap to the WORK AREA's left and top, the far
  edges to its right and bottom. The original snapped the near edges to
  literal 0 instead. On a primary monitor with a bottom or right taskbar those
  are the same number, which is why it never showed; with a taskbar docked
  LEFT or TOP, 0 puts the window UNDERNEATH it. Using the work area on all
  four edges is what the far-edge arms already did. *)

interface

const
   { Pixels. The harness Test-MainWindowEvents.ps1 carries this number too. }
   WINDOW_SNAP_DISTANCE = 20;

(* Adjusts aLeft/aTop in place when they are within aSnap of a work-area edge.

  aWidth/aHeight must be the size in the SAME coordinate space as aLeft/aTop
  and the work area -- see the note at the message-handler call site, where
  they come off the message rather than off the form, because the two differ
  on Windows by the invisible resize border. *)
procedure SnapWindowToEdges(var aLeft: integer; var aTop: integer;
                            const aWidth: integer; const aHeight: integer;
                            const aWorkLeft: integer; const aWorkTop: integer;
                            const aWorkRight: integer; const aWorkBottom: integer;
                            const aSnap: integer = WINDOW_SNAP_DISTANCE);

implementation

procedure SnapWindowToEdges(var aLeft: integer; var aTop: integer;
                            const aWidth: integer; const aHeight: integer;
                            const aWorkLeft: integer; const aWorkTop: integer;
                            const aWorkRight: integer; const aWorkBottom: integer;
                            const aSnap: integer);
begin
   if Abs(aLeft - aWorkLeft) < aSnap then
      begin
      aLeft := aWorkLeft;
      end;

   if Abs(aTop - aWorkTop) < aSnap then
      begin
      aTop := aWorkTop;
      end;

   (* THE FAR EDGES NEED THE SIZE, and that is why a programmatic move does
     not snap on them. SetWindowPos(..., SWP_NOSIZE) leaves cx and cy at
     whatever the caller happened to pass -- documented as ignored, usually
     zero -- so the distance comes out a screen width wrong. That is the RIGHT
     outcome: a saved window position restored at start-up should land where
     it was saved, not be pulled to an edge. It is only worth knowing before
     treating a programmatic move as a test of these two arms. *)
   if Abs(aWorkBottom - (aTop + aHeight)) < aSnap then
      begin
      aTop := aWorkBottom - aHeight;
      end;

   if Abs(aWorkRight - (aLeft + aWidth)) < aSnap then
      begin
      aLeft := aWorkRight - aWidth;
      end;
end;

end.
