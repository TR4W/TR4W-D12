unit uAppTimers;
{$I ..\..\tr4w.inc}

(* THE FOUR TIMERS TR4W RUNS, as LCL TTimers rather than Win32 timer ids.

  WHY THEY HAD TO MOVE. SetTimer/KillTimer take an HWND and a WNDPROC-adjacent
  callback; neither exists on GTK or Cocoa, and the handle they were given was
  tr4whandle -- the main form's -- so four unrelated subsystems reached for the
  main window in order to ask for a tick.

  AND ONE OF THEM WAS ALREADY BROKEN, which is the part worth reading. A Win32
  TIMERPROC is `stdcall` with four arguments, and on i386 a stdcall callee pops
  those arguments off the stack. Two of the four callbacks were declared as
  plain procedures and passed with @:

    LOGWIND       SetTimer(..., @ClearQuickDisplayText)   procedure, no stdcall
    uCWKeyerCPU   SetTimer(..., @SendMessageStatus)       procedure, no stdcall

  so Windows called them stdcall and they returned without unwinding four
  arguments' worth of stack. The @ operator is what let that compile. Nothing
  diagnoses it, the corruption is small and the two are infrequent -- 30 s and
  250 ms -- which is exactly the shape of a fault that gets blamed on something
  else. A TNotifyEvent cannot be got wrong this way: the compiler checks it.

  THE SHAPE. Callers pass their own plain procedure and an interval; this unit
  owns the TTimer. It deliberately knows nothing about what the timers DO --
  the callbacks live in LOGK1EA, LOGWIND, uNet and MainUnit, and a unit that
  called into all four would be a cycle in every direction. *)

interface

type
   (* Named, not numbered. The Win32 ids these replace were integer constants
     in VC.pas, and one of them -- WAV_STOP_PTT_TIMER_IDENTIFIER -- turned out
     to be killed in a routine nothing ever registered. *)
   TAppTimer = (
      atAutoCQ,            (* the auto-CQ repeat, one shot per CQ *)
      atQuickDisplayClear, (* wipe the quick-command line after 30 s *)
      atNetCWStatus,       (* tell the multi-op network what CW is sending *)
      atOneSecond);        (* the clock and rate displays *)

   TAppTimerProc = procedure;

(* Start (or restart) a timer. Restarting one that is already running resets
  its interval, which is what SetTimer with the same id did. *)
procedure StartAppTimer(const aTimer: TAppTimer; const aIntervalMs: integer;
                        const aProc: TAppTimerProc);

(* Stop it. Safe on one that was never started -- KillTimer was too, and three
  of the call sites rely on that. *)
procedure StopAppTimer(const aTimer: TAppTimer);

function AppTimerRunning(const aTimer: TAppTimer): boolean;

implementation

uses
   SysUtils,
   Classes,      (* TObject, TNotifyEvent *)
   ExtCtrls;     (* TTimer *)

type
   (* TTimer.OnTimer is a TNotifyEvent, so something has to own a method. One
     host for all four: which timer fired is its Tag, and the plain procedure
     to call is in GProcs. *)
   TAppTimerHost = class(TObject)
      procedure Tick(Sender: TObject);
   end;

var
   GHost:   TAppTimerHost = nil;
   GTimers: array[TAppTimer] of TTimer;
   GProcs:  array[TAppTimer] of TAppTimerProc;

procedure TAppTimerHost.Tick(Sender: TObject);
var
   which: TAppTimer;
begin
   if not (Sender is TTimer) then
      begin
      Exit;
      end;

   which := TAppTimer(TTimer(Sender).Tag);
   if not Assigned(GProcs[which]) then
      begin
      Exit;
      end;

   (* NO try/except HERE, deliberately. An exception on an LCL timer reaches
     Application.OnException and the crash log, which is a diagnosis; swallowing
     it here would turn a fault into a timer that silently stops working. That
     is the opposite of what the Win32 version did, where an exception leaving
     a TIMERPROC crossed a kernel callback and killed the process outright. *)
   GProcs[which]();
end;

function TimerFor(const aTimer: TAppTimer): TTimer;
begin
   if GHost = nil then
      begin
      GHost := TAppTimerHost.Create;
      end;

   if GTimers[aTimer] = nil then
      begin
      (* Owner nil: this unit frees them in its finalization. Giving them the
        main form as owner would tie a timer's lifetime to a window, which is
        the coupling being removed. *)
      GTimers[aTimer] := TTimer.Create(nil);
      GTimers[aTimer].Enabled := False;
      GTimers[aTimer].Tag := Ord(aTimer);
      GTimers[aTimer].OnTimer := GHost.Tick;
      end;

   Result := GTimers[aTimer];
end;

procedure StartAppTimer(const aTimer: TAppTimer; const aIntervalMs: integer;
                        const aProc: TAppTimerProc);
var
   t: TTimer;
begin
   if (aIntervalMs <= 0) or (not Assigned(aProc)) then
      begin
      Exit;
      end;

   GProcs[aTimer] := aProc;
   t := TimerFor(aTimer);

   (* DISABLE FIRST. Assigning Interval to a running TTimer restarts it on some
     widget sets and not others; doing it explicitly means the interval is what
     the caller asked for on every platform. *)
   t.Enabled  := False;
   t.Interval := aIntervalMs;
   t.Enabled  := True;
end;

procedure StopAppTimer(const aTimer: TAppTimer);
begin
   if GTimers[aTimer] <> nil then
      begin
      GTimers[aTimer].Enabled := False;
      end;
end;

function AppTimerRunning(const aTimer: TAppTimer): boolean;
begin
   Result := (GTimers[aTimer] <> nil) and GTimers[aTimer].Enabled;
end;

var
   cleanup: TAppTimer;

initialization

finalization
   for cleanup := Low(TAppTimer) to High(TAppTimer) do
      begin
      FreeAndNil(GTimers[cleanup]);
      end;
   FreeAndNil(GHost);

end.
