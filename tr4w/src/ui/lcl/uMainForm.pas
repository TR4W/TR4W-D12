unit uMainForm;
{$I ..\..\tr4w.inc}
{
  THE MAIN WINDOW, AS AN LCL FORM.  Phase 3a of the Win32-to-LCL migration.

  BEHAVIOUR-NEUTRAL BY CONSTRUCTION, and that is the whole design of this step.
  tr4whandle stops being the result of CreateWindowExW on TR4W's own registered
  class and becomes a TForm's Handle.  EVERYTHING ELSE IS UNCHANGED: the 43
  child elements are still created by the same placement loop from the same
  TWindows table, still parented to tr4whandle, still painted the same way; the
  hand-rolled GetMessage loop is still running; the accelerator table is still
  applied by TranslateAccelerator.

  Later steps -- not this one -- move the four input-bearing controls onto LCL
  controls (3b) and replace the loop with Application.Run (3c).

  WHY A FORM AT ALL, THIS EARLY.  A raw Win32 child parented to a TForm receives
  Windows messages but generates NO LCL key events, so TForm.KeyPreview and
  Application.AddOnKeyDownBeforeHandler cannot route it.  The input-bearing
  controls therefore have to become LCL controls in the same step that retires
  the loop -- and they cannot become LCL controls until there is a form to put
  them on.  This is that form.

  NOT A DESIGNED .lfm, deliberately.  The main window's layout is a TABLE TIMES
  A RUNTIME SCALE FACTOR: every element is placed at TWindows[e].mweiX * ws,
  where ws derives from the operator's font-size setting, and the vertical
  origin depends on EditableLogHeight, which is MEASURED at run time from the
  ListView.  A designed form would freeze 50 positions at one font size.  So the
  form is created with CreateNew and the placement loop is kept.

  THE ONE OBSERVABLE CHANGE: the window's Win32 CLASS name.  It was 'TR4W'; an
  LCL form's class is 'Window', hardcoded at win32int.pp:240 and used for forms
  at win32wsforms.pp:212 -- LCL's TCreateParams has no WinClassName, so unlike
  the VCL there is no override.  The window's TITLE is unaffected (DisplayContestTitle
  sets it with SetWindowTextA), as are the taskbar entry and everything an
  operator sees.  Only FindWindow('TR4W', nil) from another process would notice.
  NY4I confirmed 2026-08-17 that nothing third-party depends on it.
}

interface

uses
  Windows, Forms, Controls, Graphics, LCLType, LMessages;

type
  TTR4WMainForm = class(TForm)
  protected
    procedure WndProc(var TheMessage: TLMessage); override;
  end;

{ Creates the main form and returns its handle, which becomes tr4whandle.
  aMenu is TR4W's own menu, built by CreateTR4WMenu -- CreateWindowExW used to
  take it as a parameter, so it is attached here instead. }
function CreateTR4WMainForm(const aMenu: HMENU): HWND;

var
  { The form itself.  Exposed because Phase 3b parents LCL controls onto it and
    Phase 3c hands it to Application.Run.  Nothing else should need it: the rest
    of the program continues to work in tr4whandle. }
  TR4WMainForm: TTR4WMainForm = nil;

implementation

uses
  uMainWindowProc;

{ The messages TR4W's own window procedure handles.

  AN EXPLICIT ALLOW-LIST, not "delegate everything".  The alternative -- pass
  every message to the legacy proc and let its DefWindowProc fallthrough deal
  with the rest -- would take WM_PAINT, WM_ERASEBKGND, WM_DESTROY and the LCL's
  own bookkeeping away from the form and break it in ways that present as
  painting bugs.  This list is exactly the case labels in
  uMainWindowProc.WindowProc, so the two must be kept in step; a message added
  there and not here is silently never delivered. }
function IsTR4WsOwnMessage(const aMsg: UINT): boolean;
begin
   Result := (aMsg = WM_CLOSE) or
             (aMsg = WM_COMMAND) or
             (aMsg = WM_NOTIFY) or
             (aMsg = WM_DRAWITEM) or
             (aMsg = WM_MEASUREITEM) or
             (aMsg = WM_CTLCOLORLISTBOX) or
             (aMsg = WM_CTLCOLOREDIT) or
             (aMsg = WM_CTLCOLORSTATIC) or
             (aMsg = WM_LBUTTONDOWN) or
             (aMsg = WM_SETFOCUS) or
             (aMsg = WM_TIMECHANGE) or
             (aMsg = WM_DISPLAYCHANGE) or
             (aMsg = WM_WINDOWPOSCHANGING) or
             (aMsg = WM_SIZE) or
             // The WM_APP+n messages TR4W posts to itself from worker threads.
             // Named by value rather than by constant to keep this unit from
             // depending on five more units for four integers.
             (aMsg = WM_APP + 200) or   // WM_POTA_DOWNLOAD_DONE
             (aMsg = WM_APP + 201) or   // WM_POTA_LOAD_DONE
             (aMsg = WM_APP + 211) or   // WM_CTY_DOWNLOAD_DONE
             (aMsg = WM_APP + 212) or   // WM_TRMASTER_DOWNLOAD_DONE
             (aMsg = WM_APP + 213) or   // WM_CTY_VERSION_CHECKED
             (aMsg = WM_APP + 220) or   // WM_TCI_APPLY
             (aMsg = WM_APP + 100);     // WM_TRAYBALLON
end;

procedure TTR4WMainForm.WndProc(var TheMessage: TLMessage);
begin
   if IsTR4WsOwnMessage(TheMessage.msg) then
      begin
      // QUALIFIED. TWinControl already publishes a WindowProc property (a
      // TWndMethod), so a bare WindowProc inside a form method resolves to the
      // inherited one and fails with "wrong number of parameters" -- a name
      // collision the compiler reports in terms that do not name it.
      TheMessage.Result := uMainWindowProc.WindowProc(Handle, TheMessage.msg,
                                                      TheMessage.wParam,
                                                      TheMessage.lParam);

      // Two of them are STRUCTURAL: the LCL tracks its own idea of the form's
      // size and position from these, and a form whose bookkeeping disagrees
      // with its HWND misbehaves later in ways that are hard to trace back.
      // TR4W's handlers for both are advisory -- WM_SIZE only nudges the MMTTY
      // window, WM_WINDOWPOSCHANGING only constrains -- so running both is
      // correct rather than a compromise.
      if (TheMessage.msg = WM_SIZE) or (TheMessage.msg = WM_WINDOWPOSCHANGING) then
         begin
         inherited WndProc(TheMessage);
         end;
      end
   else
      begin
      inherited WndProc(TheMessage);
      end;
end;

function CreateTR4WMainForm(const aMenu: HMENU): HWND;
begin
   TR4WMainForm := TTR4WMainForm.CreateNew(nil);

   // The style bits CreateWindowExW used to pass: WS_SYSMENU or WS_MINIMIZEBOX,
   // and no WS_THICKFRAME or WS_MAXIMIZEBOX. bsSingle is the fixed-border
   // equivalent; the operator could never resize this window by dragging and
   // still cannot.
   TR4WMainForm.BorderStyle := bsSingle;
   TR4WMainForm.BorderIcons := [biSystemMenu, biMinimize];

   // Position and size are placeholders. CreateMainWindow calls SetWindowPos
   // immediately afterwards with the real geometry, which it can only compute
   // once the editable-log ListView exists and has been measured.
   TR4WMainForm.Position := poDesigned;
   TR4WMainForm.SetBounds(0, 30, 400, 200);

   // Matches the class brush the registered window class carried:
   // tr4wBrushArray[TWindows[mweWholeScreen].mweBackG], and mweBackG is
   // trBtnFace. Set explicitly because a form paints its own background and
   // would otherwise use the LCL default.
   TR4WMainForm.Color := clBtnFace;

   // Touching Handle is what forces the window to exist.
   Result := TR4WMainForm.Handle;

   if aMenu <> 0 then
      begin
      Windows.SetMenu(Result, aMenu);
      end;
end;

end.
