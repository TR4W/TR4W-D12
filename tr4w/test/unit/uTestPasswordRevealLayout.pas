unit uTestPasswordRevealLayout;
{$I ..\..\src\tr4w.inc}

(*
  THE REVEAL EYE SITS BESIDE ITS EDIT, ON A FORM THAT IS SHOWN (issue 231).

  After issue 227 the External logger editor builds its rows at run time and
  the eye on the key / token rows showed a fragment. The unit tests that
  stream the form never showed it, so no geometry was ever laid out and
  nothing could notice. These tests SHOW the form (off screen, as
  uTestNewContestForm does), let the LCL lay it out, and measure:

  - the eye lies fully inside its parent, beside the edit and not over it,
    and is as tall as the edit;
  - on the editor's Logbook row the drop-down keeps room for its arrow, the
    Refresh button lies beside it inside the row, and the caption does not
    run under the drop-down;
  - the same for a form that attaches the eye at show time (the generic
    input prompt), so the helper is checked on more than one caller.

  The numbers are printed (WriteLn) so a failure on another machine's DPI
  can be read without a debugger.
*)

interface

uses
   StdCtrls, uTR4WTestFramework;

type
   TPasswordRevealLayoutTests = class(TTestCase)
   private
      procedure CheckEyeBeside(const aEdit: TEdit; const aWhere: string);
   protected
      procedure Test_EditorRows_ClubLogToken;
      procedure Test_EditorRows_WRLKeyAndLogbook;
      procedure Test_InputPrompt_EyeBesideTheField;
      procedure Test_RadioEditor_EyeBesideTheNetworkPassword;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Forms, Controls, ExtCtrls,
   uExternalLoggerConfig, uExternalLoggerRegistry, uExternalLoggersForm,
   uWRLExternalLogger, uClubLogExternalLogger, uPasswordReveal,
   uInputQueryForm, uRadioEditForm, ComCtrls, VC;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

procedure ShowOffScreen(const aForm: TCustomForm);
begin
   aForm.Position := poDesigned;
   aForm.ShowInTaskBar := stNever;
   aForm.Left := Screen.DesktopLeft - aForm.Width - 200;
   aForm.Top := Screen.DesktopTop;
   aForm.Show;
   Application.ProcessMessages;
end;

function Bounds4(const aControl: TControl): string;
begin
   Result := Format('L%d T%d W%d H%d', [aControl.Left, aControl.Top,
      aControl.Width, aControl.Height]);
end;

(* The eye of aEdit lies inside the parent it shares with the edit, directly
   right of it and not over it, at the edit's height. *)
procedure TPasswordRevealLayoutTests.CheckEyeBeside(const aEdit: TEdit; const aWhere: string);
var
   eye: TControl;
   parent: TWinControl;
   gap: integer;
begin
   eye := PasswordRevealControl(aEdit);
   CheckTrue(eye <> nil, aWhere + ': the eye is attached');
   if eye = nil then
      begin
      Exit;
      end;
   parent := aEdit.Parent;
   WriteLn('  [Reveal] ', aWhere, ': parent ', parent.ClientWidth, 'x',
      parent.ClientHeight, '  edit ', Bounds4(aEdit), '  eye ', Bounds4(eye));
   CheckTrue(eye.Parent = parent, aWhere + ': eye and edit share a parent');
   CheckTrue(eye.Visible, aWhere + ': the eye is visible');
   gap := eye.Left - (aEdit.Left + aEdit.Width);
   CheckTrue(gap >= 0, aWhere + ': the eye is not over the edit (gap ' +
      IntToStr(gap) + ')');
   CheckTrue(gap <= 2, aWhere + ': the eye is next to the edit (gap ' +
      IntToStr(gap) + ')');
   CheckTrue(eye.Left + eye.Width <= parent.ClientWidth,
      aWhere + ': the eye is inside the parent on the right');
   CheckTrue((eye.Top >= 0) and (eye.Top + eye.Height <= parent.ClientHeight),
      aWhere + ': the eye is inside the parent vertically');
   CheckTrue(eye.Width >= 12, aWhere + ': the eye is wide enough to read');
   CheckTrue(Abs(eye.Height - aEdit.Height) <= 2,
      aWhere + ': the eye is as tall as the edit');
   CheckTrue(Abs(eye.Top - aEdit.Top) <= 1,
      aWhere + ': the eye is level with the edit');
end;

function EditorFor(const aForm: TExternalLoggersForm;
   const aProvider, aKey: string): TExternalLoggerDefinition;
begin
   Result := TExternalLoggerDefinition.Create;
   Result.Name := 'Layout';
   Result.ProviderId := aProvider;
   Result.ApiKey := aKey;
   Result.Account := 'acct-1';
   Result.Logbook := 'book-1';
   Result.LogbookName := 'A rather long logbook name for the drop-down';
   aForm.Config.Definitions.Add(Result);
end;

procedure TPasswordRevealLayoutTests.Test_EditorRows_ClubLogToken;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
begin
   InitWidgetSet;
   BeginTest('Reveal: Club Log editor, the token''s eye is beside the token box');
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      d := EditorFor(form, 'CLUBLOG', 'a-token');
      form.BeginEdit(d);
      ShowOffScreen(form);
      CheckEyeBeside(form.FieldEdit(LF_API_KEY), 'Club Log token');
   finally
      form.Free;
   end;
end;

procedure TPasswordRevealLayoutTests.Test_EditorRows_WRLKeyAndLogbook;
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
   key: TEdit;
   combo: TComboBox;
   refresh: TButton;
   rowParent: TWinControl;
begin
   InitWidgetSet;
   BeginTest('Reveal: WRL editor, the key''s eye is beside the key box; the Logbook row keeps its arrow and Refresh');
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      d := EditorFor(form, 'WRL', 'a-key');
      form.BeginEdit(d);
      ShowOffScreen(form);
      key := form.FieldEdit(LF_API_KEY);
      CheckEyeBeside(key, 'WRL key');

      combo := form.FieldCombo(LF_LOGBOOK);
      refresh := form.FieldRefreshButton(LF_LOGBOOK);
      CheckTrue((combo <> nil) and (refresh <> nil), 'the Logbook row has a drop-down and a Refresh');
      rowParent := combo.Parent;
      WriteLn('  [Reveal] WRL logbook: parent ', rowParent.ClientWidth, 'x',
         rowParent.ClientHeight, '  combo ', Bounds4(combo), '  refresh ',
         Bounds4(refresh));
      CheckTrue(combo.Visible and refresh.Visible, 'both are visible');
      CheckTrue(combo.Width >= 120, 'the drop-down is wide enough to show its arrow');
      CheckTrue(combo.Height >= 18, 'the drop-down has a height');
      CheckTrue(refresh.Left >= combo.Left + combo.Width,
         'Refresh is beside the drop-down, not over it');
      CheckTrue(refresh.Left + refresh.Width <= rowParent.ClientWidth,
         'Refresh is inside the row on the right');
      CheckTrue(refresh.Width >= 60, 'Refresh is wide enough for its caption');
      CheckTrue(refresh.Top + refresh.Height <= rowParent.ClientHeight,
         'Refresh is inside the row vertically');
   finally
      form.Free;
   end;
end;

procedure TPasswordRevealLayoutTests.Test_InputPrompt_EyeBesideTheField;
var
   frm: TfrmInputQuery;
begin
   InitWidgetSet;
   BeginTest('Reveal: the generic input prompt (eye attached at show time) is beside its field');
   frm := TfrmInputQuery.Create(nil);
   try
      tInputDialogPassword := True;
      ShowOffScreen(frm);
      frm.edtValue.Text := 'secret';
      CheckEyeBeside(frm.edtValue, 'input prompt');
   finally
      frm.Free;
   end;
end;

(* A caller that attaches the eye at CREATE time, before any layout: the radio
   editor's network password, on a tab of a page control. *)
procedure TPasswordRevealLayoutTests.Test_RadioEditor_EyeBesideTheNetworkPassword;
var
   frm: TRadioEditForm;
begin
   InitWidgetSet;
   BeginTest('Reveal: the radio editor (eye attached at create time, on a tab) is beside its field');
   frm := TRadioEditForm.Create(nil);
   try
      ShowOffScreen(frm);
      if frm.edtPassword.Parent is TTabSheet then
         begin
         frm.tbcTransport.ActivePage := TTabSheet(frm.edtPassword.Parent);
         Application.ProcessMessages;
         end;
      frm.edtPassword.Text := 'secret';
      CheckEyeBeside(frm.edtPassword, 'radio editor');
   finally
      frm.Free;
   end;
end;

procedure TPasswordRevealLayoutTests.RunAllTests;
begin
   Test_EditorRows_ClubLogToken;
   Test_EditorRows_WRLKeyAndLogbook;
   Test_InputPrompt_EyeBesideTheField;
   Test_RadioEditor_EyeBesideTheNetworkPassword;
end;

end.
