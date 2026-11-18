unit uTestRadioEditHamLib;
{$I ..\..\src\tr4w.inc}

(*
  THE RADIO EDITOR'S HAMLIB MODEL ID (2026-11-17, NY4I).

  An IC-7100 with "Drive through HamLib" ticked showed the HamLib model ID box
  greyed: it was enabled for HAMLIBANY alone, and a value typed for any other
  radio was thrown away by the renderer and by logradio. The rule now is
  uRadioRegistry.HamLibModelFor -- the operator's value for any radio driven
  through HamLib, blank meaning the registered model -- and these tests drive
  the REAL streamed form (never shown) to pin the editor's half of it:

  - the box is enabled exactly when the radio is HamLib-driven (the box
    ticked, or a HamLib-only type), and greyed otherwise;
  - blank shows the registered id as prompt text;
  - a value typed for one radio type is cleared when the type changes, so it
    cannot open the new type as the old rig;
  - the "Drive through HamLib" tooltip names the HamLib version, and says it
    is not available when there is none.
*)

interface

uses
   uTR4WTestFramework;

type
   TRadioEditHamLibTests = class(TTestCase)
   protected
      procedure Test_TheModelIdFollowsTheHamLibBox;
      procedure Test_AHamLibOnlyTypeOffersTheModelIdUnticked;
      procedure Test_ATypedModelIdIsClearedWhenTheTypeChanges;
      procedure Test_TheHamLibTooltipNamesTheVersion;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Forms, Controls,
   uRadioConfigStore, uRadioRegistry, uRadioEditForm, uLCLFormHelpers,
   uAppStrings;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

function MakeRadio(const aRegistryId: string; aUseHamLib: Boolean;
                   aHamLibID: Integer): TRadioDefinition;
begin
   Result := TRadioDefinition.Create;
   Result.Name       := 'test radio';
   Result.RegistryId := aRegistryId;
   Result.UseHamLib  := aUseHamLib;
   Result.HamLibID   := aHamLibID;
end;

(* The editor loaded with aRadio, its panel hosted in a form that is never
  shown -- EditRadioIn is the public way to load without showing. *)
procedure OpenEditor(const aRadio: TRadioDefinition;
                     out aEditor: TRadioEditForm; out aHost: TForm);
begin
   InitWidgetSet;
   aHost   := TForm.CreateNew(nil);
   aEditor := TRadioEditForm.Create(nil);
   aEditor.EditRadioIn(aRadio, aHost);
end;

procedure CloseEditor(var aEditor: TRadioEditForm; var aHost: TForm);
begin
   FreeAndNil(aEditor);
   FreeAndNil(aHost);
end;

procedure TRadioEditHamLibTests.Test_TheModelIdFollowsTheHamLibBox;
var
   radio: TRadioDefinition;
   editor: TRadioEditForm;
   host: TForm;
begin
   BeginTest('RadioEdit: the HamLib model ID is editable when, and only when, the IC-7100 is driven through HamLib');
   radio := MakeRadio('IC7100', False, 0);
   try
      OpenEditor(radio, editor, host);
      try
         CheckFalse(editor.edtHamLibID.Enabled, 'box clear: the model ID is greyed');
         CheckFalse(editor.lblHamLibID.Enabled, 'box clear: its caption is greyed with it');

         editor.chkUseHamLib.Checked := True;
         editor.HandleUseHamLibClick(editor.chkUseHamLib);
         CheckTrue(editor.edtHamLibID.Enabled, 'box ticked: the model ID can be changed');
         CheckTrue(editor.lblHamLibID.Enabled, 'box ticked: its caption is enabled');
         CheckFalse(editor.edtPollRate.Enabled,
                    'box ticked: the poll rate is greyed by the same predicate');
         CheckEquals('', editor.edtHamLibID.Text, 'nothing typed: blank, meaning the model''s id');
         CheckTrue(Pos(IntToStr(RegisteredHamLibIDId('IC7100')),
                       editor.edtHamLibID.TextHint) > 0,
                   'the prompt shows the registered id, ' +
                   IntToStr(RegisteredHamLibIDId('IC7100')) + ': "' +
                   editor.edtHamLibID.TextHint + '"');

         editor.chkUseHamLib.Checked := False;
         editor.HandleUseHamLibClick(editor.chkUseHamLib);
         CheckFalse(editor.edtHamLibID.Enabled, 'box cleared again: greyed again');
         CheckEquals('', editor.edtHamLibID.TextHint,
                     'greyed: no prompt, as the CI-V box does');
      finally
         CloseEditor(editor, host);
      end;
   finally
      radio.Free;
   end;
end;

procedure TRadioEditHamLibTests.Test_AHamLibOnlyTypeOffersTheModelIdUnticked;
var
   radio: TRadioDefinition;
   editor: TRadioEditForm;
   host: TForm;
begin
   BeginTest('RadioEdit: HamLib-any offers the model ID whatever the box says, and shows a stored one');
   radio := MakeRadio('HAMLIBANY', False, 2043);
   try
      OpenEditor(radio, editor, host);
      try
         CheckTrue(editor.edtHamLibID.Enabled,
                   'a HamLib-only type is always HamLib-driven');
         CheckEquals('2043', editor.edtHamLibID.Text, 'the stored model is shown');
      finally
         CloseEditor(editor, host);
      end;
   finally
      radio.Free;
   end;
end;

procedure TRadioEditHamLibTests.Test_ATypedModelIdIsClearedWhenTheTypeChanges;
var
   radio: TRadioDefinition;
   editor: TRadioEditForm;
   host: TForm;
begin
   BeginTest('RadioEdit: a HamLib model ID stays with the type it was typed for');
   radio := MakeRadio('IC7100', True, 9999);
   try
      OpenEditor(radio, editor, host);
      try
         CheckEquals('9999', editor.edtHamLibID.Text,
                     'the IC-7100''s own override is shown, not cleared by loading');
         CheckTrue(editor.edtHamLibID.Enabled, 'and it can be changed');

         SelectByTag(editor.cbxType, 'K3');
         editor.HandleTypeChange(editor.cbxType);
         CheckEquals('K3', editor.SelectedRegistryId, 'the type really changed');
         CheckEquals('', editor.edtHamLibID.Text,
                     'the IC-7100''s 9999 does not follow the radio to a K3');
      finally
         CloseEditor(editor, host);
      end;
   finally
      radio.Free;
   end;
end;

procedure TRadioEditHamLibTests.Test_TheHamLibTooltipNamesTheVersion;
var
   editor: TRadioEditForm;
   host: TForm;
   radio: TRadioDefinition;
begin
   BeginTest('RadioEdit: the "Drive through HamLib" tooltip carries the HamLib version');
   CheckTrue(Pos('4.7.2', UseHamLibHintText('4.7.2')) > 0,
             'a version is named: "' + UseHamLibHintText('4.7.2') + '"');
   CheckTrue(Pos(SRadioEditHamLibNotAvailable, UseHamLibHintText('')) > 0,
             'no version: says it is not available, in the catalogue''s words');
   CheckTrue(Pos(SRadioEditHamLibNotAvailable, UseHamLibHintText('   ')) > 0,
             'a blank version is no version');

   radio := MakeRadio('IC7100', False, 0);
   try
      OpenEditor(radio, editor, host);
      try
         CheckTrue(editor.chkUseHamLib.ShowHint, 'the box shows a tooltip');
         CheckTrue(editor.chkUseHamLib.Hint <> '',
                   'it has one, so the LCL asks OnShowHint for it');
         CheckTrue(Assigned(editor.chkUseHamLib.OnShowHint),
                   'the version is filled in when the tooltip shows, not at open');
      finally
         CloseEditor(editor, host);
      end;
   finally
      radio.Free;
   end;
end;

procedure TRadioEditHamLibTests.RunAllTests;
begin
   Test_TheModelIdFollowsTheHamLibBox;
   Test_AHamLibOnlyTypeOffersTheModelIdUnticked;
   Test_ATypedModelIdIsClearedWhenTheTypeChanges;
   Test_TheHamLibTooltipNamesTheVersion;
end;

end.
