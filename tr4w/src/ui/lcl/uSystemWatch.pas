unit uSystemWatch;

(* HAS THE CLOCK JUMPED, AND HAS THE DISPLAY LAYOUT CHANGED?

  Two questions Windows used to answer by sending the main window a message --
  WM_TIMECHANGE and WM_DISPLAYCHANGE -- which is why TR4W had a window
  procedure subclassed in front of its LCL form to catch them. Neither has a
  cross-platform equivalent, and NY4I named the alternative on 2026-09-06:
  "unless there is an alternative cross platform way, a timer to check both
  time and screen info?"

  So they are POLLED. Each helper is self-seeding: the first call records the
  current state and answers False, and every later call compares and answers
  once per change.

  WHY POLLING IS HONEST HERE RATHER THAN A DOWNGRADE. Both events are rare and
  neither needs to be handled promptly to the millisecond -- a clock correction
  or a monitor being unplugged is noticed within one tick. Against that, a
  window message needs a window, a handle, a procedure subclassed in front of
  the LCL's own, and an allow-list entry saying TR4W claims it; that machinery
  is the thing that does not port.

  A CLOCK JUMP IS THE DIFFERENCE BETWEEN TWO CLOCKS, not a change in one. The
  wall clock advances on its own, so "it moved" says nothing. What identifies
  an NTP correction or an operator setting the time is the wall clock moving by
  a DIFFERENT amount than the monotonic tick count over the same interval.
  GetTickCount64 is the RTL's and does not follow the wall clock, which is
  exactly the property needed.

  THE THRESHOLD IS DELIBERATELY LOOSE. Timers are not exact and neither clock
  is read at the same instant, so a couple of seconds of slop is normal; a real
  correction is far larger. Too tight a threshold would report a jump on an
  ordinary busy tick, and this triggers a UI refresh. *)

{$I ..\..\tr4w.inc}

interface

{ True ONCE, on the tick after the wall clock moved out of step with the
  monotonic tick count.  Self-seeding: the first call answers False. }
function SystemClockJumped: boolean;

{ True ONCE, on the tick after the screen geometry or monitor count changed.
  Self-seeding: the first call answers False. }
function DisplayLayoutChanged: boolean;

(* RE-READ THE DISPLAY COLOUR DEPTH into tEightBitsPerPixel.

  There is no LCL equivalent, and exactly one reader: uGradient collapses a
  gradient to a flat fill on an 8-bit display. Windows-only INSIDE, so the
  caller needs no conditional -- elsewhere the startup value stands, which on
  any platform that is not Windows means the False it was initialised to. *)
procedure RefreshColourDepth;

implementation

uses
   SysUtils,   { Now, GetTickCount64 }
   DateUtils,  { MilliSecondsBetween }
   Forms,      { Screen }
{$IFDEF WINDOWS}
   LCLIntf,    { GetDC / GetDeviceCaps / ReleaseDC -- see RefreshColourDepth.
                 The LCL declares all three, and BITSPIXEL is in LCLType, so
                 each widget set answers for its own screen. }
   LCLType,
{$ENDIF}
   VC;         { tEightBitsPerPixel }

const
   (* How far the two clocks may drift apart in one interval before it counts
     as a jump.  Two seconds: far above timer jitter, far below any correction
     worth reacting to. *)
   JUMP_TOLERANCE_MS = 2000;

var
   GSeeded:   boolean = False;
   GLastWall: TDateTime;
   GLastMono: QWord;

   GHaveLayout: boolean = False;
   GLastWidth:  integer = 0;
   GLastHeight: integer = 0;
   GLastCount:  integer = 0;

procedure RefreshColourDepth;
{$IFDEF WINDOWS}
var
   dc: HDC;
{$ENDIF}
begin
{$IFDEF WINDOWS}
   dc := LCLIntf.GetDC(0);
   if dc <> 0 then
      begin
      try
         tEightBitsPerPixel := LCLIntf.GetDeviceCaps(dc, BITSPIXEL) <= 8;
      finally
         LCLIntf.ReleaseDC(0, dc);
      end;
      end;
{$ENDIF}
end;

function SystemClockJumped: boolean;
var
   wall:     TDateTime;
   mono:     QWord;
   expected: Int64;
   actual:   Int64;
begin
   Result := False;

   wall := Now;
   mono := GetTickCount64;

   if not GSeeded then
      begin
      GSeeded   := True;
      GLastWall := wall;
      GLastMono := mono;
      Exit;
      end;

   { Both in milliseconds, and both signed: the wall clock can move BACKWARDS,
     which is the case a Cardinal difference would turn into an enormous
     forward jump. }
   expected := Int64(mono - GLastMono);
   actual   := MilliSecondsBetween(wall, GLastWall);
   if wall < GLastWall then
      begin
      actual := -actual;
      end;

   Result := Abs(actual - expected) > JUMP_TOLERANCE_MS;

   GLastWall := wall;
   GLastMono := mono;
end;

function DisplayLayoutChanged: boolean;
var
   w, h, n: integer;
begin
   Result := False;

   (* Screen, not GetSystemMetrics: the LCL keeps these for every widget set,
     and MonitorCount is what catches a display being added or removed at the
     same overall desktop size. *)
   w := Screen.Width;
   h := Screen.Height;
   n := Screen.MonitorCount;

   if not GHaveLayout then
      begin
      GHaveLayout := True;
      GLastWidth  := w;
      GLastHeight := h;
      GLastCount  := n;
      Exit;
      end;

   Result := (w <> GLastWidth) or (h <> GLastHeight) or (n <> GLastCount);

   GLastWidth  := w;
   GLastHeight := h;
   GLastCount  := n;
end;

end.
