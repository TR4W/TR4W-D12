(* THE DESIGNED MAIN WINDOW, FOR A TEST THAT RUNS CODE WHICH DRAWS ON IT.

  LIFTED FROM uTestStatusAndNotice (issue 298, stage 2, 2026-11-12), where it
  was that suite's private EnsureMainForm / ReleaseMainForm, when the second
  caller arrived: uTestLogReceivedYear drives the real NET_QSOINFO receive arm,
  whose UpdateWindows writes TR4WMainForm's panels (DisplayTotalScore,
  DisplayNextQSONumber, DisplayQSOsByOpMode) and whose LogContact may call
  DisplayHour. In the program the form exists before any link can deliver --
  uProgramMain calls CreateMainWindow, then NetLinkStartup -- so a NIL form
  there is a fact about this binary, not about the arm: it was the access
  violation stage 1 met and did not explain.

  THE FORM IS LOADED FROM ITS RESOURCE, NOT BUILT IN CODE (see
  uTestStatusAndNotice's header), and it is never shown.

  ALWAYS RELEASE IT: other suites (uTestEditingKeys) assert TR4WMainForm is
  nil, and a form left behind failed three of their assertions once. *)
unit uTestMainFormHarness;

{$I ..\..\src\tr4w.inc}

interface

(* Streams the main form if there is none: the crash log's main thread, the
  widget set, the form, its element bindings, and a window for the
  quick-command panel. Idempotent. *)
procedure EnsureTestMainForm;

(* Frees the form EnsureTestMainForm made, and clears every binding to it.
  Nothing when there is none. *)
procedure ReleaseTestMainForm;

implementation

uses
   Forms,
   VC,              (* mweQuickCommand *)
   uCrashLog,       (* InstallCrashLog -- it is what puts the MAIN THREAD on record *)
   uMainGrids,      (* BindMainGrids -- the need strips *)
   uMainForm;       (* the form, BindMainElements, MainElement *)

procedure EnsureTestMainForm;
begin
   if TR4WMainForm <> nil then
      begin
      Exit;
      end;

   (* Create(nil) STREAMS uMainForm.lfm and nothing else: this form has no
     OnCreate, so none of TR4W's startup runs and no window handle is
     allocated.  BindMainElements is what makes SetElementText able to reach
     pnlQuickCommand -- it is the same call CreateMainWindow makes. *)
   (* WITHOUT THIS EVERY GUARD IN uMainForm SAYS "OFF THE MAIN THREAD", AND
     THAT IS A FACT ABOUT THIS BINARY, NOT ABOUT THE CODE UNDER TEST.
     uCrashLog.OnMainThread compares against GMainThreadId, which is recorded by
     InstallCrashLog and is 0 until something calls it -- BOTH shipping programs
     call InstallCrashLogLCL (the app from uProgramMain, tr4wserver from its own
     program body), and that installs the RTL half too, so both are fine.  A
     test binary that skips it finds SetElementText deferring every write and
     SetStatusText dropping every one, with nothing in the log to say so,
     because ReportOffMainThread also stays quiet while GMainThreadId is 0.
     Idempotent. *)
   InstallCrashLog;

   (* AND THE WIDGET SET HAS TO BE INITIALISED, which a test binary never
     does for itself: without it the first control that needs a window dies with
     "Failed to create win32 control, error 1407: Cannot find window class",
     because the classes are registered by Application.Initialize.  It starts no
     message loop -- Application.Run is what does that -- so this stays a
     console test. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   TR4WMainForm := TTR4WMainForm.Create(nil);
   BindMainElements;

   (* AND THE PANEL NEEDS A WINDOW, because ControlUsable asks HandleAllocated
     -- deliberately, after a startup crash in 2026-08 that came of dropping
     that half of the guard.  The LCL creates a control's window lazily, and
     this form is never shown, so the test has to give the control what a
     running program gives it.  Reading .Handle is what forces it. *)
   if MainElement(mweQuickCommand) <> nil then
      begin
      MainElement(mweQuickCommand).HandleNeeded;
      end;
end;

(* PUT THE PROCESS BACK AS IT WAS FOUND, AND THIS IS NOT TIDINESS -- see the
  header. BindMainElements with no form clears its elements, so nothing is
  left pointing at the freed panels. *)
procedure ReleaseTestMainForm;
var
   frm: TTR4WMainForm;
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   frm := TR4WMainForm;
   TR4WMainForm := nil;
   BindMainElements;
   (* The need strips too: with no form, BindMainGrids forgets its panels. *)
   BindMainGrids;
   frm.Free;
end;

end.
