unit uAppInputHooks;
{$I ..\..\tr4w.inc}

{
  WHAT THE HAND-ROLLED MESSAGE LOOP DID, AS LCL APPLICATION HANDLERS.

  Phase 3c.  tr4w.lpr owned a GetMessage / TranslateMessage / DispatchMessage
  loop for the life of the program, and four things lived inside it that had
  nowhere else to be: the accelerator table, the numeric-keypad CW memories, the
  F-key label refresh when a modifier is released, and a fault-recovery wrapper.
  Application.Run replaces the loop; this unit is where those four went.

  WHY NOT JUST TRANSLATE THE LOOP.  LCL's Win32 pump
  (TWin32WidgetSet.AppProcessMessages) has NO message-filter hook -- checked in
  the installed source, not assumed -- so TranslateAccelerator can never run
  under Application.Run.  The obvious conclusion is that the whole Win32 menu
  (~181 items) and its 101 accelerators must become a TMainMenu with LCL
  ShortCuts first.  They need not:

  TWinControl.DoKeyDownBeforeInterface calls Application.NotifyKeyDownBeforeHandler
  for EVERY TWinControl in the application, before the focused control and before
  any form's KeyPreview, and setting the key to VK_UNKNOWN swallows it.  So
  AddOnKeyDownBeforeHandler is a genuine application-wide key hook with a veto --
  which is exactly what an accelerator table is.  And ACCELERATORS already holds
  the virtual key and the modifier flags in the shape the handler receives them,
  so the SAME TABLE drives both, and the Win32 menu can convert on its own
  schedule.

  WHAT IS DELIBERATELY NOT HERE.  QuickQSL.  It was a WM_CHAR arm in the loop,
  and there is no application-wide KeyPress hook -- but it also does nothing
  unless CallWindowString is non-empty, so it belongs to the callsign field and
  moved to TTR4WEntryEvents.EntryKeyPress.  That is a narrowing: it will no
  longer fire while a tool window has focus.  Recorded in the bench queue rather
  than smuggled in, because it IS a behaviour change.
}

interface

{ Call once, after Application.Initialize and before Application.Run. }
procedure InstallTR4WInputHooks;

implementation

uses
  Classes, SysUtils, StrUtils, Forms, Controls, LCLType, LMessages,
  Windows,          { GetKeyState -- see the note on TelnetHasFocus }
  uMainThread,      { RunOnMainThread -- the accelerator runs deferred }
  uMainWindowProc,  { DispatchCommandId -- the one command dispatch }
  uAccelerators,    { ACCELERATORS -- the one table }
  uConfigValues,    { Config.KeypadCWMemories }
  uCrashLog,        { LogCaughtException }
  uFunctionKeys,    { ShowFMessages -- the F-key labels }
  VC,
  MainUnit;

const
  { A persistent fault must not become a silent spin.  Ten failures inside a
    minute and TR4W gives up rather than looping forever -- the same limit the
    hand-rolled loop enforced, and the count resets after a quiet minute so
    occasional unrelated faults over a long contest do not accumulate. }
  MAX_FAULTS_PER_MINUTE = 10;
  FAULT_WINDOW_MS       = 60000;

type
  { The LCL's handlers are `of object`, so they need an instance.  It holds the
    fault counters and the modifier state and nothing else. }
  TTR4WInputHooks = class
  private
    FFaults: integer;
    FLastFault: Int64;
    function  AcceleratorFor(const aKey: word; const aShift: TShiftState): word;
  public
    procedure KeyDownBefore(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure AppException(Sender: TObject; E: Exception);
  end;

var
  gHooks: TTR4WInputHooks = nil;

{ Is the DX cluster's command field -- or anything else in the telnet window --
  where the keystroke is going?  Issue #23: Ctrl-C/V/X/A/Z there must reach the
  field and paste, not fire Execute Config File or Clear Mult Sheet.

  STILL AN HWND TEST, and it stays one until the telnet window is a form.  The
  loop asked the same question of a TMsg; this asks it of the focus, which is
  the same question with the message taken out of it. }
function TelnetHasFocus: boolean;
var
  h, focus: HWND;
begin
  Result := False;
  h := tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle;
  if h = 0 then
     begin
     Exit;
     end;
  focus := Windows.GetFocus;
  Result := (focus = h) or Windows.IsChild(h, focus);
end;

function TTR4WInputHooks.AcceleratorFor(const aKey: word;
                                        const aShift: TShiftState): word;
var
  i: integer;
begin
  Result := 0;
  for i := Low(ACCELERATORS) to High(ACCELERATORS) do
     begin
     // acInstall False means DISPLAY ONLY -- the menu shows the keystroke but
     // something else answers it.  Binding those here would create the second
     // binding the flag exists to prevent.
     if not ACCELERATORS[i].acInstall then
        begin
        Continue;
        end;
     if ACCELERATORS[i].acKey <> aKey then
        begin
        Continue;
        end;
     if ACCELERATORS[i].acCtrl <> (ssCtrl in aShift) then
        begin
        Continue;
        end;
     if ACCELERATORS[i].acAlt <> (ssAlt in aShift) then
        begin
        Continue;
        end;
     if ACCELERATORS[i].acShift <> (ssShift in aShift) then
        begin
        Continue;
        end;
     Result := ACCELERATORS[i].acId;
     Exit;
     end;
end;

procedure TTR4WInputHooks.KeyDownBefore(Sender: TObject; var Key: word;
                                        Shift: TShiftState);
var
  id: word;
begin
  // F10 IS SWALLOWED, as the loop swallowed it.  Windows treats it as "activate
  // the menu bar", which steals the keyboard from a contest operator mid-QSO.
  if Key = VK_F10 then
     begin
     Key := VK_UNKNOWN;
     Exit;
     end;

  // THE NUMERIC KEYPAD AS CW MEMORIES.  Fires whatever has focus, which is why
  // it was in the loop and is now here rather than on a form.
  if (Config.KeypadCWMemories)              and
     (Key >= VK_NUMPAD0) and (Key <= VK_NUMPAD9) then
     begin
     if Key <> VK_NUMPAD0 then
        begin
        ProcessFuntionKeys(Key + 27);
        end
     else
        begin
        ProcessFuntionKeys(Key + 37);
        end;
     Key := VK_UNKNOWN;
     Exit;
     end;

  if TelnetHasFocus then
     begin
     Exit;
     end;

  { A MODAL DIALOG OWNS THE KEYBOARD, AND THIS HOOK DOES NOT.

    NotifyKeyDownBeforeHandler fires for EVERY TWinControl in the application --
    that is the whole reason it can serve as an accelerator table, and it is
    also why it reaches controls on a dialog that has nothing to do with the
    main window.

    ESC and TAB are both accelerators (uAccelerators.pas:170 -> menu_escape,
    :174 -> menu_spmode_ortab).  So on any modal form this hook matched them,
    posted WM_COMMAND to tr4whandle and set Key := VK_UNKNOWN -- the dialog
    never saw the keystroke AND the main window acted on it.  NY4I on the bench,
    2026-08-24: ESC did not close the dialog and the main window reacted; TAB
    turned the exchange field green, which is search-and-pounce.

    MODAL, NOT "NOT THE MAIN FORM".  The converted tool windows -- band map,
    stations, dupe sheets, SCP, remaining mults -- are separate forms too, and
    accelerators SHOULD work while one of them has focus; that is a capability
    the LCL conversion gained, because a raw Win32 dialog was never a
    TWinControl and never reached this hook at all.  What must be suppressed is
    the case where a form has deliberately taken the keyboard. }
  if (Screen.ActiveCustomForm <> nil) and
     (fsModal in Screen.ActiveCustomForm.FormState) then
     begin
     (* WHICH FORM, AND IS IT EVEN ON SCREEN?

       THIS GUARD SUPPRESSES EVERY ACCELERATOR, and Enter is one -- id 10651,
       the keystroke that logs a QSO. So a form that is modal when it should
       not be stops the operator logging, silently, for the rest of the
       session, while every other key still works because no other key comes
       through here.

       NY4I is chasing exactly that shape (2026-09-03): logging stopped after
       editing a QSO, Escape still clears the field, and nothing is reported.
       frmEditQSO is created once and never freed, so it stays in
       Screen.CustomForms for the life of the run; if fsModal survives the
       close -- and ShowEditQSO catches exceptions, which is one way it could --
       the guard fires forever afterwards.

       LOGGED, NOT GUESSED AT. Visible is included because a form that is
       hidden and still fsModal is the smoking gun rather than a normal state.
       At INFO, not DEBUG: this is rare and it explains a dead keyboard. *)
     if logger <> nil then
        begin
        logger.Info('[Input] accelerator suppressed: %s is modal ' +
                    '(visible=%s). Key=%d.',
                    [Screen.ActiveCustomForm.Name,
                     BoolToStr(Screen.ActiveCustomForm.Visible, True), Key]);
        end;
     Exit;
     end;

  id := AcceleratorFor(Key, Shift);

  { SAY WHAT THIS HOOK SAW, at TRACE.

    "The accelerator does nothing" has two completely different causes and
    no way to tell them apart from outside: either the keystroke reached
    this hook and matched no row, or WINDOWS TOOK IT FIRST and the program
    never saw it at all.  Ctrl+Shift+<digit> is a standard Windows
    keyboard-layout hotkey, so the second is a real possibility rather than
    a theoretical one -- NY4I reports Ctrl+Shift+0 (MP3 recorder) doing
    nothing while Ctrl+Shift+9 (Stations) works, and the two rows are
    identical in shape.

    A line here separates them in one run: if the key is not logged, it
    never arrived.  Only modified keys are logged -- an unmodified
    keystroke is ordinary typing and would bury the log during a contest. }
  if logger.IsTraceEnabled and (Shift * [ssCtrl, ssAlt, ssShift] <> []) then
     begin
     logger.Trace('[InputHooks] key $%.2x ctrl=%d alt=%d shift=%d -> %s',
                  [Key,
                   Ord(ssCtrl in Shift), Ord(ssAlt in Shift), Ord(ssShift in Shift),
                   IfThen(id = 0, 'no accelerator', SysUtils.Format('command %d', [id]))]);
     end;

  if id = 0 then
     begin
     Exit;
     end;

  // POSTED, NOT SENT -- exactly what TranslateAccelerator did.  The command runs
  // after this key has finished being delivered, so a handler that opens a
  // modal dialog does not do it from inside the LCL's key dispatch.
  (* WHAT WAS ACTUALLY DISPATCHED -- instrumentation, 2026-09-03.

    The trace above only fires for keys with a MODIFIER, so a bare Enter --
    accelerator 10651, the keystroke that logs a QSO -- produced no evidence
    at all of having been seen. That is the one key worth being certain about,
    so it is logged unconditionally at DEBUG. *)
  if (logger <> nil) and (Key = VK_RETURN) then
     begin
     logger.Debug('[Input] Enter -> accelerator %d dispatched', [id]);
     end;

  (* RUN IT, BUT NOT FROM INSIDE THE KEY DISPATCH.

    DEFERRED, WHICH IS WHAT THE POSTED MESSAGE WAS FOR. This was
    PostMessage(tr4whandle, WM_COMMAND, id, 0) -- the accelerator became a
    Win32 message so that the command ran after the keystroke had finished
    being delivered, which matters because a handler may open a modal dialog.
    RunOnMainThread gives exactly that and needs no window, no message id and
    nothing in a window procedure to answer it.

    DispatchCommandId is the same routine the menu goes through, so a command
    cannot behave differently depending on whether it was clicked or typed. *)
  RunOnMainThread(DispatchCommandId, id);
  Key := VK_UNKNOWN;
end;

{ THE MODIFIER TRACKING THAT USED TO LIVE HERE IS GONE, AND SO IS THIS
  HANDLER'S REASON TO EXIST.

  It watched a GetKeyState transition and called ShowFMessages(0) to put the
  plain function-key bank back when Ctrl or Alt was released. It never ran.
  Measured on NY4I's machine with TRACE on, 2026-08-28: KeyDownBefore logged
  every key -- `[InputHooks] key $11 ctrl=1` for Ctrl -- while a log line at the
  top of this handler produced NOTHING at all.

  So AddOnKeyDownBeforeHandler delivers and AddOnUserInputHandler does not, in
  this program. Rather than keep a subscription that answers nothing, the
  release is handled where the events demonstrably arrive: the entry fields'
  OnKeyUp, in uMainWindowProc.RestoreBankOnModifierRelease.

  Removed rather than left in place, because a handler that cannot fire is worse
  than no handler: it reads as the feature being implemented. }

procedure TTR4WInputHooks.AppException(Sender: TObject; E: Exception);
begin
  if (Int64(GetTickCount64) - FLastFault) > FAULT_WINDOW_MS then
     begin
     FFaults := 0;
     end;
  FLastFault := Int64(GetTickCount64);
  Inc(FFaults);

  // THE BACKTRACE FIRST.  ExceptProc only fires for exceptions nobody handles,
  // so handling one here removes the [CRASH] record that says WHERE.  Surviving
  // a fault must not cost the ability to find it -- the first recovered run
  // under the old loop logged 'recovered from EAccessViolation' and nothing
  // else.
  LogCaughtException('AppException', E);
  logger.Error('[AppException] recovered from %s -- %s (failure %d). '
               + 'TR4W is still running; the [CRASH] lines above say where.',
               [E.ClassName, E.Message, FFaults]);

  if FFaults >= MAX_FAULTS_PER_MINUTE then
     begin
     logger.Fatal('[AppException] %d faults inside a minute -- giving up rather '
                  + 'than spinning.', [MAX_FAULTS_PER_MINUTE]);
     Application.Terminate;
     end;
end;

procedure InstallTR4WInputHooks;
begin
  if gHooks <> nil then
     begin
     Exit;
     end;
  gHooks := TTR4WInputHooks.Create;

  // AsFirst: the accelerators must be answered before anything else looks at
  // the key, which is what TranslateAccelerator's position in the loop meant.
  Application.AddOnKeyDownBeforeHandler(gHooks.KeyDownBefore, True);
  Application.AddOnExceptionHandler(gHooks.AppException, True);

  logger.Info('[InputHooks] accelerators, keypad CW memories, modifier tracking '
              + 'and fault recovery are LCL application handlers now');
end;

initialization

finalization
  FreeAndNil(gHooks);

end.
