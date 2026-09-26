unit uTestEditingKeys;
{$I ..\..\src\tr4w.inc}
(*
  WHO GETS Ctrl+A/C/V/X AND PGUP/PGDN -- THE RULE, NOT THE RENDERING.

  TWO KEYSTROKE CLASSES, ONE RULE, AND THE SECOND ARRIVED ON 2026-09-26 WITH THE
  PAGE KEYS. NY4I gave 10503/10504 real menu shortcuts, so PgUp changes CW speed
  from every modeless window instead of only from the call and exchange fields --
  and a menu shortcut is tested BEFORE the focused control sees the key
  (wincontrol.inc:5887), so a scrollable control would have stopped scrolling.
  The decline is what prevents that, and it is the same function, because two
  predicates would be two answers to "which form is the main window".

  Those three (X is bound by nothing) are TMenuItem shortcuts as of 2026-09-26,
  so the widget set draws them right-aligned in the shortcut column. A menu
  shortcut is normally answered from ANY form, and the thing that makes that safe
  is TTR4WMainForm.IsShortcut declining the keystroke when the focused control
  needs it -- uEditingKeys.KeystrokeBelongsToTheFocusedControl.

  WHAT IS TESTED HERE IS THE PREDICATE THE OVERRIDE ASKS, given a named control.
  That is deliberate and it is the honest seam: asserting on the override itself
  would need a real TTR4WMainForm with a focused window on screen, which a
  console test binary cannot produce -- CLAUDE.md is explicit that GUI defects
  need a running program, so pretending otherwise would buy a green test and no
  information. KeystrokeBelongsToTheControl takes the control as a parameter for
  exactly this reason; the Screen.ActiveControl form is a one-line delegation.

  AND ONE THING A TEST CANNOT REACH AT ALL, recorded so nobody wastes an
  afternoon on it: the TLMKey overload derives Ctrl and Shift from the LIVE
  keyboard, not from the message. MsgKeyDataToShiftState (lclintf.pas:198) calls
  GetKeyState for VK_SHIFT and VK_CONTROL and reads only ssAlt out of KeyData. So
  a fabricated TLMKey cannot carry a Ctrl. That is not a defect -- it is exactly
  what TMenu.IsShortcut does with the same message (menu.inc:277), which is the
  property that matters: both sides see the same keystroke.
*)

interface

uses
   SysUtils, Classes, Controls, Forms, StdCtrls, Grids, ComCtrls, LCLType,
   uTR4WTestFramework, uEditingKeys;

type
   TEditingKeysTests = class(TTestCase)
   protected
      procedure Test_TheKeystrokeHalfIsCtrlAndFourLetters;
      procedure Test_TheSettingGatesAFieldOnAnotherForm;
      procedure Test_TheMainWindowIsNeverAffected;
      procedure Test_OnlyAnEditingControlCounts;
      procedure Test_TheClusterWindowDoesNotWaitOnTheSetting;
      procedure Test_TheScrollingKeystrokeHalfIsTheBarePageKeys;
      procedure Test_AScrollableControlKeepsThePageKeys;
      procedure Test_ThePageKeysAreNotGatedOnTheSetting;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uSettingsModel,   (* Settings.Operating.StandardEditKeys *)
   uWindowTable,     (* tr4w_WindowsArray -- the telnet arm *)
   VC;               (* tw_TELNETWINDOW_INDEX *)

procedure TEditingKeysTests.Test_TheKeystrokeHalfIsCtrlAndFourLetters;
begin
   BeginTest('Test_TheKeystrokeHalfIsCtrlAndFourLetters');

   CheckTrue(IsAStandardEditingKeystroke(Ord('A'), [ssCtrl]), 'Ctrl+A');
   CheckTrue(IsAStandardEditingKeystroke(Ord('C'), [ssCtrl]), 'Ctrl+C');
   CheckTrue(IsAStandardEditingKeystroke(Ord('V'), [ssCtrl]), 'Ctrl+V');

   (* Ctrl+X is in the rule though no ACCELERATORS row binds it: cut belongs
     with copy and paste, so a row added later cannot silently take it. *)
   CheckTrue(IsAStandardEditingKeystroke(Ord('X'), [ssCtrl]), 'Ctrl+X');

   CheckFalse(IsAStandardEditingKeystroke(Ord('Z'), [ssCtrl]),
              'Ctrl+Z is bound by nothing, so nothing has to decline it');
   CheckFalse(IsAStandardEditingKeystroke(Ord('C'), []),
              'a bare C is typing');
   CheckFalse(IsAStandardEditingKeystroke(Ord('C'), [ssCtrl, ssShift]),
              'Ctrl+Shift+C is a keystroke somebody pressed on purpose');
   CheckFalse(IsAStandardEditingKeystroke(Ord('C'), [ssCtrl, ssAlt]),
              'Ctrl+Alt+C likewise');
end;

procedure TEditingKeysTests.Test_TheSettingGatesAFieldOnAnotherForm;
var
   form:  TForm;
   edit:  TEdit;
   saved: boolean;
begin
   BeginTest('Test_TheSettingGatesAFieldOnAnotherForm');

   saved := Settings.Operating.StandardEditKeys;
   form  := TForm.Create(nil);
   try
      edit        := TEdit.Create(form);
      edit.Parent := form;

      Settings.Operating.StandardEditKeys := False;
      CheckFalse(KeystrokeBelongsToTheControl(Ord('C'), [ssCtrl], edit),
                 'OFF by default: Ctrl+C still clears the mult sheet');

      Settings.Operating.StandardEditKeys := True;
      CheckTrue(KeystrokeBelongsToTheControl(Ord('C'), [ssCtrl], edit),
                'ON: Ctrl+C is the field''s copy');
      CheckTrue(KeystrokeBelongsToTheControl(Ord('V'), [ssCtrl], edit),
                'ON: Ctrl+V is paste');
      CheckTrue(KeystrokeBelongsToTheControl(Ord('A'), [ssCtrl], edit),
                'ON: Ctrl+A is select all');

      { A keystroke outside the rule is the menu's however the setting is set. }
      CheckFalse(KeystrokeBelongsToTheControl(Ord('B'), [ssCtrl], edit),
                 'Ctrl+B is not an editing key');

      CheckFalse(KeystrokeBelongsToTheControl(Ord('C'), [ssCtrl], nil),
                 'nothing focused, nothing to decline for');
   finally
      Settings.Operating.StandardEditKeys := saved;
      form.Free;
   end;
end;

procedure TEditingKeysTests.Test_TheMainWindowIsNeverAffected;
var
   edit:  TEdit;
   saved: boolean;
begin
   BeginTest('Test_TheMainWindowIsNeverAffected');

   (* THE MAIN FORM'S EXEMPTION, ASKED THE ONLY WAY A CONSOLE TEST CAN ASK IT.
     TR4WMainForm is nil here, and GetParentForm of an UNPARENTED control is nil
     too, so a control with no form is indistinguishable from one on the main
     window -- which is the case this pins: the rule must not answer True for
     something it cannot place. Building a real TTR4WMainForm to get the other
     half would need the whole main window; that half is a bench check. *)
   saved := Settings.Operating.StandardEditKeys;
   edit  := TEdit.Create(nil);
   try
      Settings.Operating.StandardEditKeys := True;
      CheckFalse(KeystrokeBelongsToTheControl(Ord('C'), [ssCtrl], edit),
                 'a control the rule cannot place keeps the accelerator');
   finally
      Settings.Operating.StandardEditKeys := saved;
      edit.Free;
   end;
end;

procedure TEditingKeysTests.Test_OnlyAnEditingControlCounts;
var
   form:   TForm;
   button: TButton;
   combo:  TComboBox;
   saved:  boolean;
begin
   BeginTest('Test_OnlyAnEditingControlCounts');

   saved := Settings.Operating.StandardEditKeys;
   form  := TForm.Create(nil);
   try
      Settings.Operating.StandardEditKeys := True;

      button        := TButton.Create(form);
      button.Parent := form;
      CheckFalse(KeystrokeBelongsToTheControl(Ord('C'), [ssCtrl], button),
                 'Ctrl+C on a button is not a copy -- the command still fires');

      combo        := TComboBox.Create(form);
      combo.Parent := form;
      CheckTrue(KeystrokeBelongsToTheControl(Ord('V'), [ssCtrl], combo),
                'a combo box is somewhere paste means something');
   finally
      Settings.Operating.StandardEditKeys := saved;
      form.Free;
   end;
end;

procedure TEditingKeysTests.Test_TheClusterWindowDoesNotWaitOnTheSetting;
var
   form:  TForm;
   edit:  TEdit;
   saved: boolean;
begin
   BeginTest('Test_TheClusterWindowDoesNotWaitOnTheSetting');

   (* ISSUE #23, AND IT IS THE ARM THIS CHANGE COULD MOST EASILY HAVE LOST.
     Before the menu owned Ctrl+C, the input hook's own "if TelnetHasFocus then
     Exit" protected the DX cluster window -- unconditionally, with no reference
     to the setting. The hook is not on that keystroke's path any more, so the
     arm had to move into the rule the form asks. If it had not, a Ctrl+C meant
     to copy a spot would clear the mult sheet again, and only with the setting
     off, which is the default. *)
   saved := Settings.Operating.StandardEditKeys;
   form  := TForm.Create(nil);
   try
      edit        := TEdit.Create(form);
      edit.Parent := form;

      tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndForm := form;
      Settings.Operating.StandardEditKeys := False;

      CheckTrue(KeystrokeBelongsToTheControl(Ord('C'), [ssCtrl], edit),
                'the cluster window gets Ctrl+C with the setting OFF');
      CheckTrue(KeystrokeBelongsToTheControl(Ord('V'), [ssCtrl], edit),
                'and Ctrl+V');
      CheckFalse(KeystrokeBelongsToTheControl(Ord('B'), [ssCtrl], edit),
                 'but not Ctrl+B -- the arm is the editing keys, not every key');
   finally
      tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndForm := nil;
      Settings.Operating.StandardEditKeys := saved;
      form.Free;
   end;
end;

procedure TEditingKeysTests.Test_TheScrollingKeystrokeHalfIsTheBarePageKeys;
begin
   BeginTest('Test_TheScrollingKeystrokeHalfIsTheBarePageKeys');

   CheckTrue(IsAScrollingKeystroke(VK_PRIOR, []), 'PgUp');
   CheckTrue(IsAScrollingKeystroke(VK_NEXT, []), 'PgDn');

   (* A MODIFIER MAKES IT A DIFFERENT COMMAND, NOT A VARIANT. Ctrl+PgUp and
     Ctrl+PgDn are 10513/10514, the INACTIVE radio's CW speed, and they are
     ordinary menu shortcuts. Declining them to a focused grid would take away a
     keystroke the operator pressed on purpose. *)
   CheckFalse(IsAScrollingKeystroke(VK_PRIOR, [ssCtrl]),
              'Ctrl+PgUp is the inactive radio, not scrolling');
   CheckFalse(IsAScrollingKeystroke(VK_NEXT, [ssCtrl]),
              'Ctrl+PgDn likewise');
   CheckFalse(IsAScrollingKeystroke(VK_PRIOR, [ssShift]),
              'Shift+PgUp is bound by nothing, so nothing has to decline it');
   CheckFalse(IsAScrollingKeystroke(VK_HOME, []),
              'Home is not a page key');
   CheckFalse(IsAScrollingKeystroke(Ord('C'), [ssCtrl]),
              'an editing key is the other arm');
end;

procedure TEditingKeysTests.Test_AScrollableControlKeepsThePageKeys;
var
   form: TForm;
   grid: TStringGrid;
   list: TListBox;
   memo: TMemo;
   tree: TTreeView;
   edit: TEdit;
   butn: TButton;
begin
   BeginTest('Test_AScrollableControlKeepsThePageKeys');

   form := TForm.Create(nil);
   try
      grid        := TStringGrid.Create(form);
      grid.Parent := form;
      list        := TListBox.Create(form);
      list.Parent := form;
      memo        := TMemo.Create(form);
      memo.Parent := form;
      tree        := TTreeView.Create(form);
      tree.Parent := form;
      edit        := TEdit.Create(form);
      edit.Parent := form;
      butn        := TButton.Create(form);
      butn.Parent := form;

      (* EVERY CLASS THE RULE COVERS, ONE ASSERTION EACH, because the coverage
        IS the rule: a class dropped from that test is a control that silently
        stops scrolling, and nothing else in the build would say so. *)
      CheckTrue(KeystrokeBelongsToTheControl(VK_PRIOR, [], grid),
                'a grid pages itself -- the log, the band map, the dupe sheets');
      CheckTrue(KeystrokeBelongsToTheControl(VK_NEXT, [], grid),
                'and PgDn');
      CheckTrue(KeystrokeBelongsToTheControl(VK_PRIOR, [], list),
                'a list box -- THE DX CLUSTER CONSOLE is one, and a native '
                + 'list box answers PgUp after the shortcut test, not before');
      CheckTrue(KeystrokeBelongsToTheControl(VK_PRIOR, [], memo),
                'a memo, where a page of text is the whole point');
      CheckTrue(KeystrokeBelongsToTheControl(VK_PRIOR, [], tree),
                'a tree view scrolls');

      (* AND WHAT IS DELIBERATELY NOT COVERED. A single-line edit does not
        scroll, so declining there would take CW speed away from the telnet send
        line and the Send Keyboard field and give nothing back. *)
      CheckFalse(KeystrokeBelongsToTheControl(VK_PRIOR, [], edit),
                 'a single-line edit does not scroll -- CW speed still changes');
      CheckFalse(KeystrokeBelongsToTheControl(VK_PRIOR, [], butn),
                 'nor does a button');

      { Ctrl+PgUp is a command in its own right and is never declined. }
      CheckFalse(KeystrokeBelongsToTheControl(VK_PRIOR, [ssCtrl], grid),
                 'Ctrl+PgUp reaches the inactive radio even over a grid');

      CheckFalse(KeystrokeBelongsToTheControl(VK_PRIOR, [], nil),
                 'nothing focused, nothing to decline for');
   finally
      form.Free;
   end;
end;

procedure TEditingKeysTests.Test_ThePageKeysAreNotGatedOnTheSetting;
var
   grid:  TStringGrid;
   saved: boolean;
begin
   BeginTest('Test_ThePageKeysAreNotGatedOnTheSetting');

   (* TWO PROPERTIES IN ONE TEST, because they are the two halves of what makes
     the page-key arm different from the editing arm.

     IT IGNORES OPERATING STANDARD EDIT KEYS. Nobody asked for an option about
     whether a grid scrolls, and a grid that stops scrolling reads as broken
     rather than as configured.

     AND THE MAIN WINDOW IS STILL EXEMPT. Asked the only way a console test can
     ask it, exactly as Test_TheMainWindowIsNeverAffected does: TR4WMainForm is
     nil here and GetParentForm of an UNPARENTED control is nil too, so a
     control the rule cannot place is indistinguishable from one on the main
     window -- and must keep the accelerator. That is what preserves PgUp
     changing CW speed with the callsign field focused. *)
   saved := Settings.Operating.StandardEditKeys;
   grid  := TStringGrid.Create(nil);
   try
      Settings.Operating.StandardEditKeys := False;
      CheckFalse(KeystrokeBelongsToTheControl(VK_PRIOR, [], grid),
                 'a grid the rule cannot place keeps the accelerator');

      Settings.Operating.StandardEditKeys := True;
      CheckFalse(KeystrokeBelongsToTheControl(VK_PRIOR, [], grid),
                 'and the setting does not change that either way');
   finally
      Settings.Operating.StandardEditKeys := saved;
      grid.Free;
   end;
end;

procedure TEditingKeysTests.RunAllTests;
begin
   Test_TheKeystrokeHalfIsCtrlAndFourLetters;
   Test_TheSettingGatesAFieldOnAnotherForm;
   Test_TheMainWindowIsNeverAffected;
   Test_OnlyAnEditingControlCounts;
   Test_TheClusterWindowDoesNotWaitOnTheSetting;
   Test_TheScrollingKeystrokeHalfIsTheBarePageKeys;
   Test_AScrollableControlKeepsThePageKeys;
   Test_ThePageKeysAreNotGatedOnTheSetting;
end;

end.
