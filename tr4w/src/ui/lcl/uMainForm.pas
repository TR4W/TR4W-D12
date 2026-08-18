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
  Windows, Forms, Controls, Graphics, StdCtrls, LCLType, LMessages;

type
  TTR4WMainForm = class(TForm)
  end;

{ Creates the callsign or exchange entry field as an LCL TEdit and returns its
  HANDLE, which the caller stores in wh[mweCall] / wh[mweExchange] exactly as
  before.

  RETURNING A HANDLE, NOT THE CONTROL, is what makes this step safe on its own.
  Everything in TR4W addresses these fields through wh[] -- SetWindowText,
  focus, the caret, the colour handler -- and the message loop routes keystrokes
  by comparing Msg.HWND against wh[mweCall]. A TEdit's Handle IS that HWND, so
  every one of those paths keeps working unchanged while the control underneath
  becomes an LCL object.

  That is the point of doing it now: the loop still runs, the routing is
  untouched, and the only thing that changed is what kind of object owns the
  window. Phase 3c then moves the keyboard onto this control's own events and
  DELETES the Msg.HWND comparisons -- which it can only do once the control is
  an LCL control able to raise them. }
function CreateTR4WEntryField(const aLeft, aTop, aWidth, aHeight: integer;
                              const aId: integer;
                              const aBorder: boolean): HWND;

{ Creates the main form and returns its handle, which becomes tr4whandle.
  aMenu is TR4W's own menu, built by CreateTR4WMenu -- CreateWindowExW used to
  take it as a parameter, so it is attached here instead. }
{ Tell the LCL the main window is on screen.

  TR4W SHOWS ITS MAIN WINDOW WITH A RAW SetWindowPos(..., SWP_SHOWWINDOW)
  (OpenOtherWindows), which the LCL cannot see.  A form whose Visible property
  is still False does not show its CHILD CONTROLS -- so the callsign and
  exchange fields were created, sized and positioned correctly and never
  appeared.  NY4I found that on the bench, 2026-08-18; every automated check
  here passed, because a control that exists with the right id at the right
  geometry looks identical to a working one unless something reads its
  Visible flag.  Dump-WindowTree now does.

  Called beside the SetWindowPos rather than replacing it: the raw call still
  does the positioning and z-order the program wants, and this only reconciles
  the LCL's own state with what already happened. }
procedure ShowTR4WMainForm;


function CreateTR4WMainForm(const aMenu: HMENU): HWND;

var
  { The form itself.  Exposed because Phase 3b parents LCL controls onto it and
    Phase 3c hands it to Application.Run.  Nothing else should need it: the rest
    of the program continues to work in tr4whandle. }
  TR4WMainForm: TTR4WMainForm = nil;

implementation

uses
  uMainWindowProc;

var
   { The LCL's own window procedure for the main form, saved when TR4W's is
     installed in front of it.  Everything TR4W does not claim chains here. }
   GLCLFormProc: Pointer = nil;

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

{ TR4W'S WINDOW PROCEDURE, INSTALLED ON THE FORM'S HWND AHEAD OF THE LCL'S.

  WHY A SUBCLASS AND NOT A WndProc OVERRIDE.  The first version of this overrode
  TWinControl.WndProc and matched on TLMessage.msg.  That was wrong, and wrong in
  a way only a person operating the program could find: THE LCL RENAMES MESSAGES
  BEFORE ANY FORM SEES THEM.

    WM_CLOSE   arrives as LM_CLOSEQUERY                (win32callback.inc:2094)
    WM_COMMAND arrives as CN_COMMAND via Perform, for a raw HMENU        (:2205)

  and WM_DRAWITEM, WM_MEASUREITEM, WM_CTLCOLOR* and WM_LBUTTONDOWN are consumed
  by the widgetset's own handlers on the way past.  An allow-list keyed on the
  Win32 numbers therefore never matched: TR4W's menu did nothing, the program
  could not be closed and had to be killed, and owner-drawn parts of the main
  window were being drawn by the wrong code.

  Found on the bench by NY4I, 2026-08-18.  No gate here caught it -- the smoke
  runner asserts only that the process SURVIVED a command, which a program that
  refuses to exit does very well indeed.

  Subclassing removes the class of problem rather than the three instances of
  it: TR4W's procedure sees the RAW Win32 message first, exactly as it did when
  it owned the window class, and anything it does not claim chains on to the LCL
  untouched.  What used to fall through to DefWindowProc now falls through to
  the LCL's proc, which is the right default for a form. }
function TR4WFormSubclassProc(TRHWND: HWND; Msg: UINT;
                              wParam: wParam; lParam: lParam): longword; stdcall;
begin
   if IsTR4WsOwnMessage(Msg) then
      begin
      Result := uMainWindowProc.WindowProc(TRHWND, Msg, wParam, lParam);

      // Three messages run BOTH handlers, for two different reasons.
      //
      // WM_SIZE and WM_WINDOWPOSCHANGING are STRUCTURAL: the LCL tracks its own
      // idea of the form's bounds from them, and a form whose bookkeeping
      // disagrees with its HWND misbehaves later in ways hard to trace back.
      // TR4W's handlers for both are advisory, so running both is correct.
      //
      // WM_COMMAND is chained because CLAIMING IT STARVES THE LCL'S OWN
      // CONTROLS.  A child control's notifications -- EN_CHANGE, EN_SETFOCUS
      // and the rest -- reach their control only through the parent's
      // WM_COMMAND, so an LCL TEdit on this form would never raise OnChange or
      // OnEnter while TR4W swallowed it.  Nothing depends on that yet, which is
      // exactly why it is worth fixing now: the entry fields cannot stop using
      // TR4W's hand-rolled EN_* routing until the framework's own routing
      // works.  TR4W still gets first refusal and still decides; the LCL simply
      // stops being deaf.
      if (Msg = WM_SIZE) or (Msg = WM_WINDOWPOSCHANGING) or (Msg = WM_COMMAND) then
         begin
         Result := Windows.CallWindowProc(GLCLFormProc, TRHWND, Msg, wParam, lParam);
         end;
      Exit;
      end;

   Result := Windows.CallWindowProc(GLCLFormProc, TRHWND, Msg, wParam, lParam);
end;


function CreateTR4WEntryField(const aLeft, aTop, aWidth, aHeight: integer;
                              const aId: integer;
                              const aBorder: boolean): HWND;
var
   edit: TEdit;
begin
   edit := TEdit.Create(TR4WMainForm);
   edit.Parent := TR4WMainForm;

   // The style bits CreateWindowExW used to pass, one by one:
   //   ES_UPPERCASE   -> CharCase
   //   WS_TABSTOP     -> TabStop
   //   ES_AUTOHSCROLL -> AutoSize False + no word wrap; a single-line TEdit
   //                     scrolls horizontally by default
   //   ES_NOHIDESEL   -> HideSelection False, so the selection stays visible
   //                     when focus moves. Contest logging depends on it: the
   //                     operator must see what is selected while the caret is
   //                     in the other field.
   //   WS_EX_STATICEDGE, conditional on NOT Config.NoBorder -> BorderStyle
   edit.CharCase := ecUpperCase;
   edit.TabStop := True;
   edit.HideSelection := False;
   edit.AutoSize := False;
   if aBorder then
      begin
      edit.BorderStyle := bsSingle;
      end
   else
      begin
      edit.BorderStyle := bsNone;
      end;

   // AutoSize False BEFORE SetBounds. LCL controls autosize by default and FMX
   // ones do not, so a streamed or assigned Height is silently overridden --
   // this tree has paid for that once already.
   edit.SetBounds(aLeft, aTop, aWidth, aHeight);

   // The control id is what test/ui/Test-Typing.ps1 and every other instrument
   // finds these fields by, and what the dialog-item helpers use. A TEdit does
   // not set one, so it is applied to the handle directly.
   Result := edit.Handle;
   Windows.SetWindowLong(Result, GWL_ID, aId);
end;

procedure ShowTR4WMainForm;
var
   r: TRect;
begin
   if not Assigned(TR4WMainForm) then
      begin
      Exit;
      end;

   // READ THE REAL BOUNDS BACK FIRST.  Everything that sizes this window --
   // CreateMainWindow, CheckEditableWindowHeight, SetWindowSize -- does it with
   // a raw SetWindowPos on tr4whandle, so the LCL's own idea of the form's
   // bounds is still the placeholder CreateNew was given.  Setting Visible then
   // makes the LCL apply THAT, and the window collapses to the placeholder:
   // NY4I, 2026-08-18, "the screen is quite small and only a partial view" --
   // a 400x200 window with the menu wrapped onto two lines.
   //
   // Reconciling instead of assigning: read what the window actually is and
   // tell the LCL, rather than deciding here what it should be. The program
   // owns its geometry; this only stops the framework overwriting it.
   Windows.GetWindowRect(TR4WMainForm.Handle, r);
   TR4WMainForm.SetBounds(r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top);

   TR4WMainForm.Visible := True;

   // AND PUT IT BACK.  Telling the LCL the bounds is not enough: showing the
   // form makes it apply its own adjustments -- menu height, border metrics --
   // and the window came out 1018x705 where TR4W had made it 1012x656.  Close
   // enough to look almost right, which is worse than obviously wrong.
   //
   // TR4W computes that geometry from the font-size setting and the MEASURED
   // height of the log ListView; it is not a number the framework can improve
   // on.  So the raw rect is restored after the show, and the LCL is left
   // holding a correct BoundsRect either way.
   Windows.SetWindowPos(TR4WMainForm.Handle, 0, r.Left, r.Top,
                        r.Right - r.Left, r.Bottom - r.Top,
                        SWP_NOZORDER or SWP_NOACTIVATE);
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

   // INSTALL TR4W'S PROCEDURE IN FRONT OF THE LCL'S, keeping the LCL's to
   // chain to.  After Handle has forced the window into existence, before
   // anything is shown.
   GLCLFormProc := Pointer(Windows.SetWindowLongPtr(Result, GWL_WNDPROC,
                                                    LONG_PTR(@TR4WFormSubclassProc)));

   if aMenu <> 0 then
      begin
      Windows.SetMenu(Result, aMenu);
      end;
end;

end.
