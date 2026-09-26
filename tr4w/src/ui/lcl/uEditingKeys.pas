unit uEditingKeys;
{$I ..\..\tr4w.inc}

(*
  DOES THE FOCUSED CONTROL NEED THIS KEYSTROKE? ASKED IN ONE PLACE.

  TWO KEYSTROKE CLASSES REACH IT, AND THERE IS STILL ONE RULE.

    Ctrl+A/C/V/X   the EDITING keys. Gated on OPERATING STANDARD EDIT KEYS,
                   except in the DX cluster window. Issue #23, and NY4I's
                   2026-09-15 report that copy and paste do not work on a
                   dialog.
    PgUp / PgDn    the SCROLLING keys, added 2026-09-26 when NY4I gave
                   10503/10504 real menu shortcuts so CW speed changes from
                   every modeless window rather than only from the call and
                   exchange fields. Ungated: a grid, a list box or a memo
                   scrolls whatever the setting says, because nobody asked for
                   an option about that and a control that stops scrolling
                   reads as broken.

  ONE FUNCTION ANSWERS BOTH. Two predicates side by side would be two rules
  free to disagree about the case they share -- which form is the main window,
  and what "the focused control" even means -- and the cost of that is exactly
  what the note below records about the hook's copy and the form's copy.

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

(* PgUp or PgDn with NO modifier. The pure keystroke half of the scrolling
  rule, with no notion of focus in it.

  Ctrl+PgUp and Ctrl+PgDn are deliberately NOT this: they are 10513 and 10514,
  the INACTIVE radio's CW speed, and they are ordinary menu shortcuts that
  nothing should decline. *)
function IsAScrollingKeystroke(const aKey: word;
                               const aShift: TShiftState): boolean;

(* Is the operator typing in the DX cluster window? Unchanged from the hook,
  which still calls it for every key it dispatches. *)
function TelnetHasFocus: boolean;

(* THE RULE, ASKED OF A NAMED CONTROL -- for BOTH keystroke classes; see the
  unit header. Separated from the Screen.ActiveControl form below for one
  reason: a test can hand it an edit on a form it built, which is the only way
  to assert this without a focused window on screen. *)
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
   LCLType,          (* VK_PRIOR, VK_NEXT *)
   StdCtrls,         (* TCustomEdit, TCustomComboBox -- what "the operator is
                       typing in a field" means, asked of the control rather
                       than of the form. TCustomListBox and TCustomMemo are
                       here too: both scroll on PgUp *)
   Grids,            (* TCustomGrid -- the log, the band map, both dupe
                       sheets, SCP, the remaining-mult windows *)
   ComCtrls,         (* TCustomTreeView *)
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

(* PAGE UP AND PAGE DOWN, UNMODIFIED, AND NOTHING ELSE.

  THE MASK IS EXACT EQUALITY WITH THE EMPTY SET, as the editing rule's is with
  [ssCtrl], and for the same reason: a modifier makes it a DIFFERENT COMMAND
  rather than a variant of this one. Ctrl+PgUp and Ctrl+PgDn are 10513/10514,
  the inactive radio's CW speed. Declining those to a focused grid would take
  away a keystroke the operator pressed on purpose.

  SHIFT+PGUP IS NOT HERE EITHER, and nothing binds it, so a memo extending its
  selection with it was never at risk. *)
function IsAScrollingKeystroke(const aKey: word;
                               const aShift: TShiftState): boolean;
begin
   Result := False;

   if (aShift * [ssCtrl, ssAlt, ssShift]) <> [] then
      begin
      Exit;
      end;

   Result := (aKey = VK_PRIOR) or (aKey = VK_NEXT);
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

(* DOES THE FOCUSED CONTROL NEED THIS KEYSTROKE? TWO ARMS, ONE FUNCTION.

  ARM ONE IS PGUP AND PGDN and is documented at the arm itself, because what it
  turns on is a list of control classes and the list belongs beside the test.

  ARM TWO IS THE EDITING KEYS, and is the original rule, unchanged:

  IS THIS ONE OF THE STANDARD EDITING KEYS, TYPED INTO A FIELD THAT IS NOT ON
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

   if aFocused = nil then
      begin
      Exit;
      end;

   owner := GetParentForm(aFocused);

   (* ARM ONE: PGUP AND PGDN, WHICH A SCROLLABLE CONTROL ANSWERS ITSELF.

     THE MAIN WINDOW IS NEVER AFFECTED, exactly as in the editing arm below:
     the log IS a grid, and declining there would take PgUp away from the one
     place CW speed is certainly what the operator means. Asked again here
     rather than hoisted above both arms, because the editing arm asks it AFTER
     the cluster-window arm and after the setting, and that order is
     load-bearing -- see the comment on the editing arm.

     WHAT IS COVERED, ONE CLASS AT A TIME, AND WHY EACH:

       TCustomGrid       the log, the band map, both dupe sheets, SCP and the
                         remaining-mult windows. The widget set already
                         consumes PgUp here (grids.pas:7776, and MoveSel sets
                         Key := 0), so the shortcut is not even reached -- but
                         the rule says so anyway, because that is a fact about
                         TCustomGrid's KeyDown and not a promise.
       TCustomListBox    ELEVEN of them, the DX CLUSTER CONSOLE among them
                         (uTelnetForm.lfm, lstConsole). This is the one that
                         genuinely needs the arm: a Win32 list box answers
                         PgUp in the NATIVE window procedure, which runs after
                         the shortcut test, so without this the console would
                         stop paging.
       TCustomMemo       same shape, and a memo is the one control where a page
                         of text is the whole point. It descends from
                         TCustomEdit, so it has to be named separately.
       TCustomComboBox   PgUp moves its selection, dropped down or not.
       TCustomTreeView   scrolls, one in the tree.

     WHAT IS DELIBERATELY NOT COVERED:

       a single-line TCustomEdit    it does not scroll. Declining there would
                                    take CW speed away from the telnet send
                                    line and the Send Keyboard field and give
                                    nothing back.
       TScrollBox, TScrollingWinControl, a panel
                                    a scrolling CONTAINER does not take the
                                    keyboard; the focused child does, and that
                                    is what this is asked about.
       Pause and Ins                not scrolling keys. They are menu
                                    shortcuts now by NY4I's decision, so Ins
                                    no longer toggles a native edit's
                                    overwrite mode on a modeless window. A
                                    MODAL form is unaffected -- it never
                                    reaches the main form's IsShortcut at all
                                    (application.inc:2146).
       a modal form                 same reason. *)
   if IsAScrollingKeystroke(aKey, aShift) then
      begin
      if owner = TCustomForm(TR4WMainForm) then
         begin
         Exit;
         end;

      Result := (aFocused is TCustomGrid)     or
                (aFocused is TCustomListBox)  or
                (aFocused is TCustomMemo)     or
                (aFocused is TCustomComboBox) or
                (aFocused is TCustomTreeView);

      { owner <> nil BEFORE owner.Name: GetParentForm answers nil for an
        unparented control, which is a state a test can produce. }
      if Result and (owner <> nil) and (logger <> nil) and logger.IsTraceEnabled then
         begin
         logger.Trace('[EditingKeys] PgUp/PgDn left to %s on %s -- it scrolls',
                      [aFocused.ClassName, owner.Name]);
         end;

      Exit;
      end;

   if not IsAStandardEditingKeystroke(aKey, aShift) then
      begin
      Exit;
      end;

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
