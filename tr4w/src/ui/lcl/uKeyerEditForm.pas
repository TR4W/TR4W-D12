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
unit uKeyerEditForm;
{$I ..\..\tr4w.inc}

{
  The keyer editor: one CW keying DEVICE, edited in isolation.

  Built as a designed form from the start -- the layout is in uKeyerEditForm.fmx
  and edited in the IDE.  Everything about the shape of this unit follows
  uRadioEditForm, which is the worked example: published control fields whose
  names match the .fmx exactly, published event handlers (TWriter stores an
  event as the NAME of a published method, so a private one is silently not
  written to the resource), captions from the designer, and population in code.

  MODELESS, like the radio editor, and for the same reason: ShowModal runs FMX's
  own message loop, which would stop TR4W's -- and therefore its key handling,
  CW timing and radio servicing -- for as long as the dialog is up.  The result
  comes back through a callback.

  ONLY DEVICES WITH THEIR OWN SETTINGS ARE EDITED HERE -- a WinKeyer or a YCCC
  SO2R+ box.  Keying on a radio's own port, or by CAT, is part of that RADIO's
  setup, and which method a slot uses is the PROFILE's choice.  See
  uKeyerConfigStore's header for where that line falls and why.
}

interface

uses
   SysUtils,
   Classes,
   System.UITypes,
   Controls,
   Forms,
   StdCtrls,
   ExtCtrls,
   uKeyerConfigStore;

type
   TKeyerEditDone = procedure(const aAccepted: boolean) of object;

   TfrmKeyerEdit = class(TForm)
      lblName: TLabel;
      edtName: TEdit;
      lblKind: TLabel;
      cbxKind: TComboBox;
      lblPort: TLabel;
      cbxPort: TComboBox;

      grpWinKeyer: TGroupBox;
      lblWKKeyerMode: TLabel;
      cbxWKKeyerMode: TComboBox;
      lblWKSidetone: TLabel;
      cbxWKSidetone: TComboBox;
      lblWKWeight: TLabel;
      edtWKWeight: TEdit;
      lblWKLeadIn: TLabel;
      edtWKLeadIn: TEdit;
      lblWKTail: TLabel;
      edtWKTail: TEdit;
      lblWKRatio: TLabel;
      edtWKRatio: TEdit;
      lblWKFirstExt: TLabel;
      edtWKFirstExt: TEdit;
      lblWKComp: TLabel;
      edtWKComp: TEdit;
      lblWKSwitchpoint: TLabel;
      edtWKSwitchpoint: TEdit;
      chkWKAutospace: TCheckBox;
      chkWKCTSpacing: TCheckBox;
      chkWKIgnoreSpeedPot: TCheckBox;
      chkWKSidetoneEnable: TCheckBox;
      chkWKPaddleOnlySidetone: TCheckBox;
      chkWKPaddleSwap: TCheckBox;

      btnOK: TButton;
      btnCancel: TButton;

      procedure HandleKindChange(Sender: TObject);
      procedure HandleOK(Sender: TObject);
      procedure HandleCancel(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
   private
      FKeyer: TKeyerDefinition;
      FOnDone: TKeyerEditDone;
      // False until streaming has finished. Assigning a combo's ItemIndex fires
      // OnChange, and the handler would otherwise run against controls that are
      // still nil -- the same guard uRadioEditForm needs, for the same reason.
      FBuilt: boolean;

      procedure PopulateKindCombo;
      procedure PopulateWinKeyCombos;
      procedure PopulatePortCombo;
      procedure LoadFromKeyer;
      function SaveToKeyer(out aError: string): boolean;
      procedure UpdateEnabledState;
   public
      constructor Create(AOwner: TComponent); override;
      procedure EditKeyer(const aKeyer: TKeyerDefinition; const aOnDone: TKeyerEditDone);
   end;

implementation

{$R *.lfm}

uses
   uHostedFormWindows,
   Dialogs,
   uLCLFormHelpers,
   uLCLTranslate,
   uKeyerConfigApply,   // KeyerModeSpellings / SidetoneSpellings -- one vocabulary
   ComPortEnumerator;

constructor TfrmKeyerEdit.Create(AOwner: TComponent);
begin
   // Create, not CreateNew: the inherited constructor finds the resource named
   // for this class and streams the layout in.
   inherited Create(AOwner);

   TranslateForm(Self);

   // Assigned here as well as in the resource: losing them is invisible -- the
   // form still opens and looks right, having silently stopped registering its
   // window handle with the coexistence layer, which is what keyboard handling
   // depends on.
   OnShow  := HandleShow;
   OnClose := HandleClose;

   FBuilt := True;
   PopulateKindCombo;
   PopulatePortCombo;
   PopulateWinKeyCombos;
end;

procedure TfrmKeyerEdit.PopulateKindCombo;
var
   k: TKeyerKind;
begin
   cbxKind.Clear;
   // Built from the enum, so a device kind added later appears here with no
   // change to this file.
   for k := Low(TKeyerKind) to High(TKeyerKind) do
      begin
      AddComboItem(cbxKind, KeyerKindToStr(k), KeyerKindToStr(k));
      end;
end;

procedure TfrmKeyerEdit.PopulateWinKeyCombos;
var
   v: string;
begin
   // DECLARED BUT NEVER FILLED until 2026-08-21: both of these were read from
   // and selected into, and nothing ever put an item in them, so keyer mode and
   // sidetone frequency were permanently blank and could not be set at all
   // (NY4I).  Built ONCE with the form -- unlike the port list, these two
   // vocabularies cannot change while TR4W is running.
   cbxWKKeyerMode.Items.BeginUpdate;
   try
      cbxWKKeyerMode.Clear;
      for v in KeyerModeSpellings do
         begin
         AddComboItem(cbxWKKeyerMode, v, v);
         end;
   finally
      cbxWKKeyerMode.Items.EndUpdate;
   end;

   cbxWKSidetone.Items.BeginUpdate;
   try
      cbxWKSidetone.Clear;
      for v in SidetoneSpellings do
         begin
         AddComboItem(cbxWKSidetone, v, v);
         end;
   finally
      cbxWKSidetone.Items.EndUpdate;
   end;
end;

procedure TfrmKeyerEdit.PopulatePortCombo;
var
   enumerator: TComPortEnumerator;
   names: TArray<string>;
   info: TComPortInfo;
   i: integer;
   caption: string;
begin
   cbxPort.Clear;
   AddComboItem(cbxPort, TC_PREFS_NONE, PORT_NONE);

   enumerator := TComPortEnumerator.Create;
   try
      enumerator.Refresh;
      names := enumerator.PortNames;
      for i := 0 to High(names) do
         begin
         caption := names[i];
         if enumerator.PortByName(names[i], info) and (info.FriendlyName <> '') then
            begin
            caption := names[i] + ' - ' + info.FriendlyName;
            end;
         // Friendly name SHOWN, config value in the tag -- storing the display
         // text would put 'COM17 - Silicon Labs CP210x' into the settings file,
         // which is the corruption the legacy dialog had to be fixed for.
         AddComboItem(cbxPort, caption, ComNameToPortValue(names[i]));
         end;
   finally
      enumerator.Free;
   end;
end;

procedure TfrmKeyerEdit.EditKeyer(const aKeyer: TKeyerDefinition;
                                  const aOnDone: TKeyerEditDone);
begin
   FKeyer  := aKeyer;
   FOnDone := aOnDone;
   PopulatePortCombo;   // ports may have changed since the form was built
   LoadFromKeyer;
   Show;
   BringToFront;
end;

procedure TfrmKeyerEdit.LoadFromKeyer;

   function NumText(const aValue: integer): string;
   begin
      // 0 means "leave it to the device", so it shows as blank rather than as a
      // zero the operator might read as a real setting.
      if aValue = 0 then
         begin
         Result := '';
         end
      else
         begin
         Result := IntToStr(aValue);
         end;
   end;

begin
   if FKeyer = nil then
      begin
      Exit;
      end;

   edtName.Text := FKeyer.Name;
   SelectByTag(cbxKind, KeyerKindToStr(FKeyer.Kind));
   SelectByTag(cbxPort, FKeyer.Port);

   SelectByTag(cbxWKKeyerMode, FKeyer.WKKeyerMode);
   SelectByTag(cbxWKSidetone,  FKeyer.WKSidetoneFrequency);

   edtWKWeight.Text       := NumText(FKeyer.WKWeight);
   edtWKLeadIn.Text       := NumText(FKeyer.WKLeadInTime);
   edtWKTail.Text         := NumText(FKeyer.WKTailTime);
   edtWKRatio.Text        := NumText(FKeyer.WKDitDahRatio);
   edtWKFirstExt.Text     := NumText(FKeyer.WKFirstExtension);
   edtWKComp.Text         := NumText(FKeyer.WKKeyerCompensation);
   edtWKSwitchpoint.Text  := NumText(FKeyer.WKPaddleSwitchpoint);

   chkWKAutospace.Checked          := FKeyer.WKAutospace;
   chkWKCTSpacing.Checked          := FKeyer.WKCTSpacing;
   chkWKIgnoreSpeedPot.Checked     := FKeyer.WKIgnoreSpeedPot;
   chkWKSidetoneEnable.Checked     := FKeyer.WKSidetoneEnable;
   chkWKPaddleOnlySidetone.Checked := FKeyer.WKPaddleOnlySidetone;
   chkWKPaddleSwap.Checked         := FKeyer.WKPaddleSwap;

   UpdateEnabledState;
end;

function TfrmKeyerEdit.SaveToKeyer(out aError: string): boolean;
var
   kind: TKeyerKind;
begin
   aError := '';
   Result := False;

   if Trim(edtName.Text) = '' then
      begin
      aError := 'The keyer needs a name.';
      Exit;
      end;

   if not StrToKeyerKind(SelectedTag(cbxKind), kind) then
      begin
      aError := 'Choose a keyer type.';
      Exit;
      end;

   // A device with no port cannot key. Reported here rather than left to fail
   // silently at the hardware, which presents as a fault in the radio.
   if SameText(SelectedTag(cbxPort), PORT_NONE) or (SelectedTag(cbxPort) = '') then
      begin
      aError := 'Choose the port this keyer is connected to.';
      Exit;
      end;

   FKeyer.Name := Trim(edtName.Text);
   FKeyer.Kind := kind;
   FKeyer.Port := SelectedTag(cbxPort);

   FKeyer.WKKeyerMode         := SelectedTag(cbxWKKeyerMode);
   FKeyer.WKSidetoneFrequency := SelectedTag(cbxWKSidetone);

   // StrToIntDef(..., 0): a blank box means "leave it to the device", the same
   // convention the radio store uses for BaudRate and ReceiverAddress.
   FKeyer.WKWeight             := StrToIntDef(Trim(edtWKWeight.Text), 0);
   FKeyer.WKLeadInTime         := StrToIntDef(Trim(edtWKLeadIn.Text), 0);
   FKeyer.WKTailTime           := StrToIntDef(Trim(edtWKTail.Text), 0);
   FKeyer.WKDitDahRatio        := StrToIntDef(Trim(edtWKRatio.Text), 0);
   FKeyer.WKFirstExtension     := StrToIntDef(Trim(edtWKFirstExt.Text), 0);
   FKeyer.WKKeyerCompensation  := StrToIntDef(Trim(edtWKComp.Text), 0);
   FKeyer.WKPaddleSwitchpoint  := StrToIntDef(Trim(edtWKSwitchpoint.Text), 0);

   FKeyer.WKAutospace          := chkWKAutospace.Checked;
   FKeyer.WKCTSpacing          := chkWKCTSpacing.Checked;
   FKeyer.WKIgnoreSpeedPot     := chkWKIgnoreSpeedPot.Checked;
   FKeyer.WKSidetoneEnable     := chkWKSidetoneEnable.Checked;
   FKeyer.WKPaddleOnlySidetone := chkWKPaddleOnlySidetone.Checked;
   FKeyer.WKPaddleSwap         := chkWKPaddleSwap.Checked;

   Result := True;
end;

procedure TfrmKeyerEdit.UpdateEnabledState;
var
   kind: TKeyerKind;
   isWinKeyer: boolean;
begin
   if not FBuilt then
      begin
      Exit;
      end;

   isWinKeyer := StrToKeyerKind(SelectedTag(cbxKind), kind) and (kind = kkWinKeyer);

   // GREYED, not hidden: a group that vanishes makes the operator wonder
   // whether the settings still exist. A YCCC box has none of these knobs --
   // showing them enabled would invite setting something that is never sent.
   grpWinKeyer.Enabled := isWinKeyer;
end;

procedure TfrmKeyerEdit.HandleKindChange(Sender: TObject);
begin
   // Guarded: PopulateKindCombo sets ItemIndex during construction, which fires
   // this before the rest of the form exists.
   if not FBuilt then
      begin
      Exit;
      end;
   UpdateEnabledState;
end;

procedure TfrmKeyerEdit.HandleOK(Sender: TObject);
var
   err: string;
begin
   if not SaveToKeyer(err) then
      begin
      ShowMessage(err);
      Exit;
      end;
   Hide;
   if Assigned(FOnDone) then
      begin
      FOnDone(True);
      end;
end;

procedure TfrmKeyerEdit.HandleCancel(Sender: TObject);
begin
   Hide;
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

procedure TfrmKeyerEdit.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);
end;

procedure TfrmKeyerEdit.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
   // Closing with the window button means Cancel: the operator did not accept.
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

end.
