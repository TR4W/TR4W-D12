{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uLCLCoexist;
{$I ..\..\tr4w.inc}

{
  TR4W's LCL dependency, in one unit.

  HISTORICAL, AND NO LONGER TRUE OF THE FIRST LINE: this unit was called into
  being to host LCL forms inside TR4W's OWN GetMessage / TranslateMessage /
  DispatchMessage loop, and its header said "Application.Run is never called".
  That stopped being true on 2026-08-23 (Phase 3c).  RunLCLApplication below IS
  that call, and tr4w.lpr no longer has a loop of its own.

  What survives from the old arrangement, because it is still the reason this
  unit exists: tr4w.lpr does not link Forms, so every reference to Application
  lives here.

  THIS UNIT IS DELIBERATELY ALMOST EMPTY, and the reason is worth stating
  because its FMX counterpart is not.

  uFMXCoexist carried TellFMXTheApplicationIsRunning, a shim installed because
  FMX asks "is the application running?" before it will activate a form, and on
  Windows that answer came from TPlatformWin.FRunning -- set by Application.Run,
  which this architecture did not then call.  Every hosted FMX form therefore
  stayed Active=False for its whole life, and the only visible symptom was that
  an edit accepted keystrokes but SHOWED NO CARET (bench, 2026-08-05).

  The LCL was asked the same question directly rather than assumed to differ
  (spike\lclprobe, 2026-08-13).  With Application.Initialize called and
  Application.Run never called, inside a hand-rolled loop:

      form Active      : TRUE
      form Visible     : TRUE
      handle allocated : TRUE
      edit Focused     : TRUE

  So there is nothing to mirror.  The LCL activates and focuses a hosted form
  without being told anything, which is why this unit holds an initialiser and
  no shim.

  WHICH WINDOWS ARE OURS was in uHostedFormWindows -- pure Win32, naming no
  toolkit, shared with the FMX side.  A form registered its handle as it showed
  and unregistered as it closed, and tr4w.lpr's loop asked that unit whether a
  message belonged to a hosted window before applying its own CW-memory and
  accelerator handling.  With the loop gone nothing asks any more: the registry
  is still written by eighteen forms and read by nobody, and should be retired.
}

interface

uses
   (* Interfaces FIRST -- see the note on the implementation's uses clause,
     which is where it used to be listed. It moved up with Forms, which the
     interface now needs for TTaskBarBehavior; Interfaces must still come
     before it. *)
   Interfaces,
   Forms;

// Call ONCE, early in startup, before any LCL form is created.  Idempotent:
// calling it twice is harmless, which matters because the call site is a
// startup path that has grown conditional branches over the years.
//
// It does NOT start the message loop; RunLCLApplication does, once TR4W has
// finished starting up.
procedure InitLCLApplication;

{ Tell the operator that TR4W is already running, and say it VISIBLY.

  This was a raw MessageBoxW(0, ...) in tr4w.lpr with MB_SYSTEMMODAL.
  Application.Initialize has already run by this point, so the LCL owns the
  message pump such a dialog needs; going around it with a raw Win32 call was
  gratuitous.

  A NOTE ON WHAT THIS DID *NOT* FIX, because an earlier version of this comment
  claimed otherwise.  It was written believing the raw call created no window at
  all -- read off a probe that reported no top-level window for the process.
  That probe could not see ANY window, not even Notepad's, so it proved nothing;
  NY4I confirmed the dialog does appear on his desktop.  The real cause of the
  invisible, unkillable-looking TR4W was a HEADLESS EXPORT reaching this dialog,
  and that is fixed in tr4w.lpr by deciding batch mode before the
  single-instance check. }
procedure ReportAlreadyRunning(const aMessage: string);

(* A WARNING AT STARTUP, WHILE THERE IS NO MAIN WINDOW TO OWN IT.  The title is
  SAlreadyRunningTitle ('TR4W'), named for its first use; renaming it would
  orphan its entries in the translation catalogues.  Never call this from a
  headless run -- there is nobody to dismiss it. *)
procedure ReportStartupWarning(const aMessage: string);

{ Hand the program to the LCL and do not come back.

  Phase 3c: TR4W ran its own GetMessage loop until 2026-08-23, which is why the
  initialiser above used to be called InitLCLForHostedLoop -- the LCL was a
  guest inside TR4W's loop.  It is the other way round now.

  Application.Run is HERE rather than in tr4w.lpr for the same reason
  Application.Initialize is: this unit owns the whole LCL dependency, and
  tr4w.lpr does not link Forms. }
procedure RunLCLApplication;

// True once InitLCLApplication has run.  A form that creates itself before
// the widgetset is initialised fails in ways that do not name the cause, so
// the form units assert on this rather than discovering it at random.
function LCLReadyForHostedForms: boolean;

(* WHO CARRIES TR4W'S TASKBAR BUTTON (NY4I, 2026-11-16).

  THE DEFECT. With the New Contest dialog up at startup the pinned TR4W icon
  showed no "running" mark, and clicking it started a second copy, which hit
  the single-instance mutex and warned. Once the main window was up the icon
  showed running and a click raised the main window.

  WHY, read from the LCL source (Lazarus win32 widgetset):

    * The button belongs to the main form, the one form here that is
      ShowInTaskBar = stAlways and unowned.
    * Every other form is stDefault. With MainFormOnTaskBar False,
      TWin32WSCustomForm.CreateHandle gives it the hidden Application window
      (AppHandle) as its owner, and an owned window gets no button.
    * AppHandle itself is shown by TApplication.UpdateVisible only for a
      showing form that "uses the application's taskbar item":
      Application.MainForm (TR4W has none), an stNever form, or an stDefault
      form when TaskBarBehavior is tbSingleButton. None applies under
      tbDefault, so AppHandle stays hidden.
    * So before the main window shows, TR4W is a process with windows and NO
      taskbar button, and the shell's pinned icon cannot match it.

  THE FIX IS THE LCL'S OWN KNOB, Application.TaskBarBehavior. Until the main
  window shows it is tbSingleButton: every stDefault form counts, so the
  Application window is shown and carries one button (titled TR4W, the
  program's icon), and a click on it is routed by the LCL to the modal or
  last-active window (AppBringToFront / CM_ACTIVATE). Ownership does NOT
  change -- stDefault and stNever both give AppHandle as the owner here -- so
  nothing about how a startup dialog stacks is different. It covers the
  dialogs the LCL builds itself (MessageDlg, QuestionDlg, ShowMessage, the
  already-running warning), which no per-form ShowInTaskBar could reach.
  When the main window is about to show, ShowTR4WMainForm puts tbDefault
  back; that form's Visible := True runs UpdateVisible, which hides
  AppHandle, so the main window's button is the only one again.

  A BUTTON CAN MINIMIZE, so while it is the Application window's the startup
  modal has to come back on restore, which the LCL does not do without an
  Application.MainForm. TStartupRestorer in the implementation answers the
  restore event (measured on the GUI test VM, 2026-11-17).

  WINDOWS ONLY. On gtk2 tbSingleButton maps stDefault to stNever, which sets
  skip-taskbar and would REMOVE the entry every startup dialog has today.

  StartupTaskBarBehavior is the decision, pure and tested;
  ApplyStartupTaskBarBehavior applies it. *)
function StartupTaskBarBehavior(const aMainWindowShowing: boolean): TTaskBarBehavior;
procedure ApplyStartupTaskBarBehavior(const aMainWindowShowing: boolean);


implementation


uses
   (* Interfaces FIRST, and it is not optional.  It is what links the
     widgetset, which supplies every WSRegisterXxx symbol the LCL's controls
     reference.  Without it the link fails with a wall of
         Undefined symbol: WSRegisterControl, WSRegisterMenu, ...
     that names no unit and does not suggest its own cause.

     IT IS ALSO LISTED FIRST IN tr4w.lpr NOW (2026-11-15), and that listing,
     not this one, decides WHEN it initialises -- and so when it finalises,
     freeing Application and the widgetset. Reached only from here it
     finalised before uAppTimers, uPrefsForm and other UI units did, and their
     cleanup ran against a nil Application (exit 217 off Windows). The unit
     still names its own dependency, and still puts Interfaces before Forms
     for any program that reaches the LCL through this unit alone -- in the
     INTERFACE's uses clause since 2026-11-16, which needs Forms. *)
   Dialogs,      (* MessageDlg *)
   utils_text,     (* LclText -- MessageDlg's parameters are the LCL's
                    AnsiString and this unit's `string` is UTF-16 *)
   uAppStrings;  (* SAlreadyRunningTitle *)

var
   gInitialised: boolean = False;

procedure ReportAlreadyRunning(const aMessage: string);
begin
   (* MessageDlg, NOT Application.MessageBox.

     The old call was the only thing here that needed a byte pointer, and the
     comment that stood in its place explained the cast rather than questioning
     the call: TApplication.MessageBox takes PChar meaning PAnsiChar, and this
     unit compiles with {$MODESWITCH UnicodeStrings}, so the text had to be
     narrowed to bytes first or the box would render one letter and stop.

     MessageDlg takes STRINGS, is what an LCL program written from scratch
     would call, and drops both the pointer and the code page. It also drops
     LCLType, which was in the uses clause only for MB_OK and MB_ICONWARNING. *)
   ReportStartupWarning(aMessage);
end;

procedure ReportStartupWarning(const aMessage: string);
begin
   MessageDlg(LclText(SAlreadyRunningTitle), LclText(aMessage),
              mtWarning, [mbOK], 0);
end;

procedure InitLCLApplication;
begin
   if gInitialised then
      begin
      Exit;
      end;

   // Registers the widgetset and the platform services an LCL form needs to
   // create its window.  It does not start a message loop; RunLCLApplication
   // does that, once TR4W has finished starting up.
   Application.Initialize;
   gInitialised := True;

   (* Before ANY form, the already-running warning included: no main window
     is showing yet, so the Application window carries the button. *)
   ApplyStartupTaskBarBehavior(False);
end;

function StartupTaskBarBehavior(const aMainWindowShowing: boolean): TTaskBarBehavior;
begin
   if aMainWindowShowing then
      begin
      // The main form is stAlways and carries the one button itself.
      Result := tbDefault;
      end
   else
      begin
      // The hidden Application window is shown and carries it instead.
      Result := tbSingleButton;
      end;
end;

{$IFDEF WINDOWS}
type
   (* A CLASS because Application.AddOnRestoreHandler takes a TNotifyEvent.

     THE BUTTON CAN MINIMIZE THE APPLICATION WINDOW, and the startup modal
     must come back when it is restored (measured on the GUI test VM,
     2026-11-17: after SC_MINIMIZE then SC_RESTORE the New Contest dialog
     stayed hidden, with nothing on screen to type into). Windows hides a
     minimized window's owned windows, and the LCL's SC_RESTORE arm for the
     Application window (win32callback.inc, DoSysCmdRestore) re-shows them
     ONLY when Application.MainForm is set -- TR4W has none. It does raise
     Application's restore event, so this answers it with the LCL's own
     Application.Restore, whose win32 arm (AppRestore) restores every showing
     modal form while ModalLevel > 0.

     ONLY WITH A MODAL UP: with none, AppRestore sends SC_RESTORE to the
     Application window again, which would raise this event again. Every
     window TR4W shows before its main window is modal. *)
   TStartupRestorer = class(TObject)
   public
      procedure ApplicationRestored(Sender: TObject);
   end;

var
   (* Created when the handler is added, freed in finalization after it is
     removed, so Application never holds a method of a freed object. *)
   gStartupRestorer: TStartupRestorer = nil;

procedure TStartupRestorer.ApplicationRestored(Sender: TObject);
begin
   if Application.ModalLevel > 0 then
      begin
      Application.Restore;
      end;
end;
{$ENDIF}

procedure ApplyStartupTaskBarBehavior(const aMainWindowShowing: boolean);
begin
{$IFDEF WINDOWS}
   (* WINDOWS ONLY: the gap is the win32 widgetset's ownership model (see the
     interface note). gtk2 gives every stDefault form its own entry already,
     and tbSingleButton there would take those entries away. *)
   if Application = nil then
      begin
      Exit;
      end;

   if aMainWindowShowing then
      begin
      if gStartupRestorer <> nil then
         begin
         Application.RemoveOnRestoreHandler(gStartupRestorer.ApplicationRestored);
         end;
      end
   else
      begin
      (* The button's text. Application.Title is unset, so the Application
        window was created with the executable's name (tr4w, or tr4w_fpc on a
        developer build). Set here and not on other platforms: on macOS the
        title names the application menu. *)
      Application.Title := 'TR4W';
      if gStartupRestorer = nil then
         begin
         gStartupRestorer := TStartupRestorer.Create;
         end;
      (* AddOnRestoreHandler does not add a handler twice. *)
      Application.AddOnRestoreHandler(gStartupRestorer.ApplicationRestored);
      end;
   Application.TaskBarBehavior := StartupTaskBarBehavior(aMainWindowShowing);
{$ENDIF}
end;

procedure RunLCLApplication;
begin
   // NOT SHOWN BY Run.  CreateMainWindow has already positioned and shown the
   // main form with geometry it can only compute once the editable log exists
   // and has been measured; letting Run show it again would flash it at its
   // designed size first.
   Application.ShowMainForm := False;

   // Does not return in normal use: TR4W exits through ExitProcess in
   // tr4w_ShutDown, reached from ExitProgram.  Nothing may be placed after the
   // call site that has to run.
   Application.Run;
end;

function LCLReadyForHostedForms: boolean;
begin
   Result := gInitialised;
end;


finalization
{$IFDEF WINDOWS}
   (* Interfaces finalizes AFTER this unit (it is listed first in tr4w.lpr), so
     Application is still there to let go of the handler. *)
   if gStartupRestorer <> nil then
      begin
      if Application <> nil then
         begin
         Application.RemoveOnRestoreHandler(gStartupRestorer.ApplicationRestored);
         end;
      gStartupRestorer.Free;
      gStartupRestorer := nil;
      end;
{$ENDIF}
end.
