unit uEditingKeys;
{$I ..\..\tr4w.inc}

(*
  DOES THE FOCUSED CONTROL NEED THIS KEYSTROKE? ASKED IN ONE PLACE.

  MOVED HERE FROM uAppInputHooks (2026-09-26), unchanged in logic, because a
  SECOND caller appeared: TTR4WMainForm.IsShortcut. The rule decides who owns
  Ctrl+A, Ctrl+C, Ctrl+V and Ctrl+X, and two copies of it would drift -- the
  hook's copy and the form's copy would be free to disagree about the one thing
  they exist to agree on.

  WHY THE FORM NOW ASKS IT AT ALL. Those three keystrokes are TMenuItem
  shortcuts as of this change, so the widget set draws them right-aligned in the
  shortcut column instead of the caption reading "Send Keyboard Input (Ctrl+A)".
  A menu shortcut is normally answered from ANY form, which is why they were
  kept out of the menu until now -- but TCustomForm.IsShortcut is VIRTUAL
  (forms.pp:721), and a form that returns False WITHOUT calling inherited never
  asks its menu. DoKeyDownBeforeInterface then returns False
  (wincontrol.inc:5876) and the native edit control receives the key and does
  its own Copy, Paste or Select-All.

  WHY THE TELNET ARM IS IN THE COMPOSITE AND NOT LEFT TO THE HOOK. The hook's
  own "if TelnetHasFocus then Exit" covers EVERY key, and it still does -- but
  it only protects keys the HOOK dispatches. Once the menu owns Ctrl+C the hook
  is not on that keystroke's path at all, so without the arm below a Ctrl+C
  meant to copy a spot in the DX cluster window would clear the mult sheet
  again. That is Issue #23, and it is unconditional: it does not wait on the
  OPERATING STANDARD EDIT KEYS setting, exactly as the hook's guard does not.

  CROSS-PLATFORM, STATED FOR WHAT IT IS.

    Win32   the override is needed and is what makes this work: every dispatch
            route to the main menu ends at the main form's IsShortcut.
    Cocoa   NOT needed, and harmless. TCocoaWindowContent.performKeyEquivalent
            (cocoawindows.pas:388-403) hands Cut/Copy/Paste to a focused
            NSTextView BEFORE the menu -- the platform's own convention -- so
            the LCL form is never asked.
    gtk2    NOT VERIFIED. gtk2 accelerators are native accel groups
            (gtk2proc.inc:5308-5311) and the order in which they run relative
            to LCL key delivery has not been read. This wants a bench check on
            the Mint machine; nothing here claims it works.

  There is deliberately NO platform conditional. One could not be justified
  from what is known: the override is correct on Win32, inert on Cocoa, and
  unread on gtk2 -- and gating out a path nobody has measured would only hide
  the answer.
*)

interface

uses
   Classes,      (* TShiftState *)
   Controls,     (* TWinControl *)
   LMessages;    (* TLMKey *)

(* Ctrl, and nothing else, with one of the four editing letters. The pure
  keystroke half of the rule, with no notion of focus in it. *)
function IsAStandardEditingKeystroke(const aKey: word;
                                     const aShift: TShiftState): boolean;

(* Is the operator typing in the DX cluster window? Unchanged from the hook,
  which still calls it for every key it dispatches. *)
function TelnetHasFocus: boolean;

(* THE RULE, ASKED OF A NAMED CONTROL. Separated from the Screen.ActiveControl
  form below for one reason: a test can hand it an edit on a form it built,
  which is the only way to assert this without a focused window on screen. *)
function KeystrokeBelongsToTheControl(const aKey: word;
                                      const aShift: TShiftState;
                                      const aFocused: TWinControl): boolean;

(* The same rule asked of whatever has focus -- what the form's IsShortcut
  calls. The TLMKey form derives the modifiers exactly as TMenu.IsShortcut does
  (menu.inc:277, KeyDataToShiftState), so the two cannot disagree about what
  keystroke arrived. *)
function KeystrokeBelongsToTheFocusedControl(const aKey: word;
                                            const aShift: TShiftState): boolean; overload;
function KeystrokeBelongsToTheFocusedControl(var aMessage: TLMKey): boolean; overload;

implementation

uses
   Forms,            (* Screen, GetParentForm, KeyDataToShiftState *)
   StdCtrls,         (* TCustomEdit, TCustomComboBox -- what "the operator is
                       typing in a field" means, asked of the control rather
                       than of the form *)
   uWindowTable,     (* tr4w_WindowsArray -- which form is the telnet window *)
   uSettingsModel,   (* Settings.Operating.StandardEditKeys *)
   uMainForm,        (* TR4WMainForm -- the one window the rule exempts *)
   VC,               (* tw_TELNETWINDOW_INDEX *)
   MainUnit;         (* logger *)

(* CTRL AND NOTHING ELSE, AND ONE OF FOUR LETTERS.

  Ctrl+X is included though nothing in ACCELERATORS binds it today: cut belongs
  with copy and paste, and leaving it out would mean a future row silently
  taking it away from a focused field.

  CTRL+Z IS NOT IN THE LIST BECAUSE IT IS NOT AN ACCELERATOR. Nothing in the
  table binds it (only Alt+Z is, 10318) and nothing in tr4w/src handles VK_Z, so
  a focused field already gets it. Listing it here would look like a fix and
  change nothing. *)
function IsAStandardEditingKeystroke(const aKey: word;
                                     const aShift: TShiftState): boolean;
begin
   Result := False;

   if (aShift * [ssCtrl, ssAlt, ssShift]) <> [ssCtrl] then
      begin
      Exit;
      end;

   Result := (aKey = Ord('C')) or (aKey = Ord('V')) or
             (aKey = Ord('X')) or (aKey = Ord('A'));
end;

(* IS THE OPERATOR TYPING IN THE DX CLUSTER WINDOW?

  If so the input hook keeps its hands off the keystroke entirely, because the
  accelerator table would otherwise eat the ordinary editing keys: Ctrl-C is
  menu_ctrl_clearmultsheet (10424), Ctrl-V is menu_ctrl_execute_config (10426)
  and Ctrl-A is menu_ctrl_sendkeyboardinput (10400). That is Issue #23 -- a
  Ctrl-C meant to copy a spot cleared the mult sheet instead.

  ASKED OF THE LCL, NOT OF WINDOWS. This was GetFocus plus IsChild against the
  form's HWND -- a Win32 question about a window this code does not own, and
  two HWND locals to hold the answer. Screen.ActiveControl is the same question
  in the framework's own terms, and GetParentForm walks the parent chain for
  us, so a control nested any number of panels deep still answers correctly --
  which is what IsChild was there to do.

  It also stops being a Windows question, which is the point: GetFocus and
  IsChild do not exist on GTK or Cocoa. *)
function TelnetHasFocus: boolean;
var
   focused: TWinControl;
begin
   Result := False;

   if tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndForm = nil then
      begin
      Exit;
      end;

   focused := Screen.ActiveControl;
   if focused = nil then
      begin
      Exit;
      end;

   Result := GetParentForm(focused) = tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndForm;
end;

(* IS THIS ONE OF THE STANDARD EDITING KEYS, TYPED INTO A FIELD THAT IS NOT ON
  THE MAIN WINDOW?

  NY4I, 2026-09-15: "on many dialogs, CTRL-C, CTRL-V, CTRL-Z do not work. Those
  are standard windows commands."

  THREE CONDITIONS, AND ALL THREE ARE REQUIRED.

    the option        OFF by default. An operator who has cleared the mult
                      sheet with Ctrl+C for years keeps doing so until they
                      say otherwise.
    not the main form THE MAIN WINDOW IS NEVER AFFECTED. Its call and exchange
                      fields are edits too, so testing only "is a field
                      focused" would take Ctrl+C away from the one place the
                      accelerator is certainly wanted.
    an edit control   asked of the control, not of the form. A TCustomEdit or a
                      TCustomComboBox is where Ctrl+V means paste; a grid or a
                      button is not, and on those the command should still
                      fire.

  AND ONE CONDITION AHEAD OF ALL THREE, which the setting does not gate: the DX
  cluster window. See the unit header -- that arm is Issue #23, and it was the
  hook's to enforce until the menu took the keystroke. *)
function KeystrokeBelongsToTheControl(const aKey: word;
                                      const aShift: TShiftState;
                                      const aFocused: TWinControl): boolean;
var
   owner: TCustomForm;
begin
   Result := False;

   if not IsAStandardEditingKeystroke(aKey, aShift) then
      begin
      Exit;
      end;

   if aFocused = nil then
      begin
      Exit;
      end;

   owner := GetParentForm(aFocused);

   if (tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndForm <> nil) and
      (owner = tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndForm) then
      begin
      if (logger <> nil) and logger.IsTraceEnabled then
         begin
         logger.Trace('[EditingKeys] Ctrl+%s left to the DX cluster window '
                      + '(Issue #23)', [Char(aKey)]);
         end;
      Result := True;
      Exit;
      end;

   if not Settings.Operating.StandardEditKeys then
      begin
      Exit;
      end;

   if owner = TCustomForm(TR4WMainForm) then
      begin
      Exit;
      end;

   Result := (aFocused is TCustomEdit) or (aFocused is TCustomComboBox);

   if Result and (logger <> nil) and logger.IsTraceEnabled then
      begin
      logger.Trace('[EditingKeys] Ctrl+%s left to %s on %s -- OPERATING '
                   + 'STANDARD EDIT KEYS is on',
                   [Char(aKey), aFocused.ClassName, owner.Name]);
      end;
end;

function KeystrokeBelongsToTheFocusedControl(const aKey: word;
                                            const aShift: TShiftState): boolean;
begin
   Result := KeystrokeBelongsToTheControl(aKey, aShift, Screen.ActiveControl);
end;

function KeystrokeBelongsToTheFocusedControl(var aMessage: TLMKey): boolean;
begin
   Result := KeystrokeBelongsToTheFocusedControl(aMessage.CharCode,
                                                KeyDataToShiftState(aMessage.KeyData));
end;

end.
