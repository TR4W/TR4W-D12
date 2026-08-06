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
unit uPrefsForm;

{
  The Preferences window: define many radios, activate a pair by profile.

  This is the UI half of the radio-configuration work.  Everything it decides is
  delegated: uRadioConfigStore owns the data and its rules, uRadioConfigApply
  puts a profile on the air, uRadioRegistry says which radios exist and what
  they support.  This unit lays out controls and moves values between them and
  a store -- deliberately, so that a UI mistake cannot corrupt a configuration
  and so the layers below stay testable without it.

  MODELESS, ALWAYS.  ShowModal runs FMX's own message loop, which means TR4W's
  loop -- and therefore its key handling, CW timing and radio servicing -- is not
  running for as long as the dialog is up.  That is unacceptable during a
  contest, so both windows here are modeless, including the radio editor, which
  reports its result through a callback rather than a modal result.

  WORKING COPY.  The form edits a CLONE of the store.  Cancel throws the clone
  away and reloads from disk; OK and Apply validate, save, and activate.  An
  operator who opens Preferences mid-contest and changes their mind must not
  have altered anything by having looked.

  BOTH FORMS ARE BUILT IN CODE and there is no .fmx.  That is what the
  coexistence spike proved out, and it keeps the whole window in one file that
  can be read top to bottom.  Moving to designer forms later is a mechanical
  change; doing it now would mean debugging form streaming and layout at the
  same time as the logic.

  I18N -- NOT DONE, AND DELIBERATELY VISIBLE.  Every caption in this unit comes
  from the const block below, in one place, so that moving them into
  src\lang\tr4w_consts_<LANG>.pas is a mechanical lift rather than a hunt
  through layout code.  Until that happens this window is English-only, which is
  a gap against the stated requirement, not an oversight.
}

interface

uses
   System.SysUtils,
   System.Classes,
   System.UITypes,
   FMX.Types,
   FMX.Controls,
   FMX.Forms,
   FMX.StdCtrls,
   FMX.Edit,
   FMX.ListBox,
   FMX.Layouts,
   FMX.TabControl,
   FMX.Controls.Presentation,
   uRadioConfigStore,
   uRadioEditForm;   // the Radio editor, its own unit since it is next to be designed

type

   { Edits ONE TRadioDefinition.  It edits the caller's object directly and only
     when the operator accepts; the caller passes a clone if it wants a
     cancellable edit, which is what TPrefsForm does. }
   TPrefsForm = class(TForm)
   private
      FStore: TRadioConfigStore;
      FEditor: TRadioEditForm;
      // The definition currently being edited, and the clone the editor works
      // on.  Held as fields because the editor is modeless: the result arrives
      // later, in a callback, not on the next line.
      FEditTarget: TRadioDefinition;
      FEditClone: TRadioDefinition;
      FEditIsNew: boolean;
      FLoading: boolean;
      // Set by every edit, cleared by every successful save.  Without it,
      // closing with the window's X kept the edits in memory unsaved -- so
      // reopening showed them as though they had been saved, which is the worst
      // of both behaviours.
      FDirty: boolean;

      FNavList: TListBox;
      FContent: TLayout;
      FPlaceholder: TLabel;

      FRadioList: TListBox;
      FProfileCombo: TComboBox;
      FRadio1Combo: TComboBox;
      FRadio2Combo: TComboBox;
      FCW1Combo: TComboBox;
      FCW2Combo: TComboBox;
      FSpeedSync1: TCheckBox;
      FSpeedSync2: TCheckBox;
      FSO2RCheck: TCheckBox;
      FAutoConnect: TCheckBox;
      FActiveLabel: TLabel;
      FHardwarePanel: TLayout;

      procedure BuildControls;
      procedure BuildHardwarePanel;

      function StoreFileName: string;
      function LegacyStoreFileName: string;
      procedure LoadStore;
      function SaveStore(out aError: string): boolean;

      procedure RefreshRadioList;
      procedure RefreshProfileCombo;
      procedure RefreshProfileFields;
      procedure RefreshAll;
      function CurrentProfile: TStationProfile;
      function SelectedRadio: TRadioDefinition;
      procedure FillRadioNameCombo(const aCombo: TComboBox; const aSelected: string);
      procedure FillCWOutputCombo(const aCombo: TComboBox; const aSelected: string);
      procedure CaptureProfileFields;

      procedure HandleNavChange(Sender: TObject);
      procedure HandleAdd(Sender: TObject);
      procedure HandleEdit(Sender: TObject);
      procedure HandleDuplicate(Sender: TObject);
      procedure HandleRemove(Sender: TObject);
      procedure HandleRadioDblClick(Sender: TObject);
      procedure HandleNewProfile(Sender: TObject);
      procedure HandleRenameProfile(Sender: TObject);
      procedure HandleDeleteProfile(Sender: TObject);
      procedure HandleProfileChange(Sender: TObject);
      procedure HandleFieldChange(Sender: TObject);
      procedure HandleActivate(Sender: TObject);
      procedure HandleOK(Sender: TObject);
      procedure HandleCancel(Sender: TObject);
      procedure HandleApply(Sender: TObject);
      procedure DiscardChanges;
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);

      procedure EditorDone(const aAccepted: boolean);
      function ApplyNow(const aActivate: boolean): boolean;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
   end;

// Opens Preferences, creating it on first use.  Called from the PREF
// call-window command.
procedure ShowPreferences;

implementation

uses
   uFMXFormHelpers,
   Winapi.Windows,
   System.IniFiles,
   System.Generics.Collections,
   System.Generics.Defaults,
   FMX.Platform.Win,
   FMX.Dialogs,
   uFMXCoexist,
   uRadioConfigApply,
   uRadioRegistry,
   uCAT,        // DiscoverNetworkRadios
   MainUnit,    // logger
   ComPortEnumerator,
   VC;

var
   gPrefsForm: TPrefsForm = nil;

procedure ShowPreferences;
begin
   if gPrefsForm = nil then
      begin
      gPrefsForm := TPrefsForm.Create(nil);
      end;
   gPrefsForm.Show;
   gPrefsForm.BringToFront;
end;


constructor TPrefsForm.Create(AOwner: TComponent);
begin
   inherited CreateNew(AOwner);
   Caption     := TC_PREFS_TITLE;
   ClientWidth  := 860;
   ClientHeight := 620;
   Position    := TFormPosition.ScreenCenter;
   // FIXED SIZE, deliberately.  Every control here is laid out at a fixed
   // position and a fixed width, so a resize only adds whitespace -- and it
   // used to strand the footer buttons in mid-air, because they were placed
   // once from ClientWidth/ClientHeight rather than anchored (NY4I,
   // 2026-08-05).  They are anchored now as well, so this can be flipped back
   // to Sizeable if the content ever earns it.
   //
   // No maximize button either: offering one on a form that cannot use the
   // space is a promise the dialog does not keep.
   BorderStyle := TFmxFormBorderStyle.Single;
   BorderIcons := [TBorderIcon.biSystemMenu, TBorderIcon.biMinimize];
   OnShow      := HandleShow;
   OnClose     := HandleClose;

   FStore := TRadioConfigStore.Create;
   BuildControls;
   LoadStore;
   RefreshAll;
end;

destructor TPrefsForm.Destroy;
begin
   FreeAndNil(FEditClone);
   FreeAndNil(FStore);
   inherited Destroy;
end;

procedure TPrefsForm.BuildControls;
var
   i: integer;
   item: TListBoxItem;
const
   SECTIONS: array[0..3] of string =
      (TC_PREFS_HARDWARE, TC_PREFS_CONTEST, TC_PREFS_CW, TC_PREFS_CLUSTER);
begin
   FNavList := TListBox.Create(Self);
   FNavList.Parent     := Self;
   FNavList.Position.X := 0;
   FNavList.Position.Y := 0;
   FNavList.Width      := 170;
   FNavList.Height     := ClientHeight - 48;
   FNavList.Align      := TAlignLayout.Left;
   FNavList.OnChange   := HandleNavChange;

   for i := 0 to High(SECTIONS) do
      begin
      item := TListBoxItem.Create(FNavList);
      item.Parent    := FNavList;
      item.Text      := SECTIONS[i];
      item.TagString := SECTIONS[i];
      end;

   FContent := TLayout.Create(Self);
   FContent.Parent     := Self;
   FContent.Position.X := 175;
   FContent.Position.Y := 0;
   FContent.Width      := ClientWidth - 185;
   FContent.Height     := ClientHeight - 48;

   // Shown for every section except Hardware.  The other categories exist in
   // the nav on purpose: they say what this window is GOING to be, so nobody
   // has to guess whether Preferences is meant to grow.
   FPlaceholder := MakeLabel(FContent, TC_PREFS_NOTMIGRATED, LEFTMARGIN, 20, 500);
   FPlaceholder.Height  := 60;
   FPlaceholder.Visible := False;

   BuildHardwarePanel;

   MakeButton(Self, TC_PREFS_OK,     ClientWidth - 290, ClientHeight - 38, 85, HandleOK,     [TAnchorKind.akRight, TAnchorKind.akBottom]);
   MakeButton(Self, TC_PREFS_CANCEL, ClientWidth - 195, ClientHeight - 38, 85, HandleCancel, [TAnchorKind.akRight, TAnchorKind.akBottom]);
   MakeButton(Self, TC_PREFS_APPLY,  ClientWidth - 100, ClientHeight - 38, 85, HandleApply,  [TAnchorKind.akRight, TAnchorKind.akBottom]);

   FNavList.ItemIndex := 0;
end;

procedure TPrefsForm.BuildHardwarePanel;
var
   y: single;
   grp: TGroupBox;
begin
   FHardwarePanel := TLayout.Create(FContent);
   FHardwarePanel.Parent     := FContent;
   FHardwarePanel.Position.X := 0;
   FHardwarePanel.Position.Y := 0;
   FHardwarePanel.Width      := FContent.Width;
   FHardwarePanel.Height     := FContent.Height;

   // --- my radios ----------------------------------------------------------
   MakeLabel(FHardwarePanel, TC_PREFS_MYRADIOS, LEFTMARGIN, 8, 200);

   FRadioList := TListBox.Create(FHardwarePanel);
   FRadioList.Parent       := FHardwarePanel;
   FRadioList.Position.X   := LEFTMARGIN;
   FRadioList.Position.Y   := 30;
   FRadioList.Width        := 420;
   FRadioList.Height       := 150;
   FRadioList.OnDblClick   := HandleRadioDblClick;

   MakeButton(FHardwarePanel, TC_PREFS_ADD,       445, 30,  95, HandleAdd);
   MakeButton(FHardwarePanel, TC_PREFS_EDIT,      445, 62,  95, HandleEdit);
   MakeButton(FHardwarePanel, TC_PREFS_DUPLICATE, 445, 94,  95, HandleDuplicate);
   MakeButton(FHardwarePanel, TC_PREFS_REMOVE,    445, 126, 95, HandleRemove);

   // --- station profile ----------------------------------------------------
   grp := TGroupBox.Create(FHardwarePanel);
   grp.Parent     := FHardwarePanel;
   grp.Position.X := LEFTMARGIN;
   grp.Position.Y := 195;
   grp.Width      := 540;
   grp.Height     := 260;
   grp.Text       := TC_PREFS_PROFILES;

   // Below the caption, same reason as the serial/network groups.
   y := GROUPTOP;
   FProfileCombo := TComboBox.Create(grp);
   FProfileCombo.Parent     := grp;
   FProfileCombo.Position.X := 12;
   FProfileCombo.Position.Y := y;
   FProfileCombo.Width      := 200;
   FProfileCombo.OnChange   := HandleProfileChange;

   MakeButton(grp, TC_PREFS_NEWPROFILE,    220, y, 80, HandleNewProfile);
   MakeButton(grp, TC_PREFS_RENAMEPROFILE, 305, y, 90, HandleRenameProfile);
   MakeButton(grp, TC_PREFS_DELETEPROFILE, 400, y, 80, HandleDeleteProfile);

   y := y + ROWHEIGHT + 6;
   MakeLabel(grp, TC_PREFS_RADIO1, 12, y + 4, 70);
   FRadio1Combo := TComboBox.Create(grp);
   FRadio1Combo.Parent     := grp;
   FRadio1Combo.Position.X := 90;
   FRadio1Combo.Position.Y := y;
   FRadio1Combo.Width      := 190;
   FRadio1Combo.OnChange   := HandleFieldChange;

   MakeLabel(grp, TC_PREFS_CWOUTPUT1, 290, y + 4, 90);
   FCW1Combo := TComboBox.Create(grp);
   FCW1Combo.Parent     := grp;
   FCW1Combo.Position.X := 385;
   FCW1Combo.Position.Y := y;
   FCW1Combo.Width      := 140;
   FCW1Combo.OnChange   := HandleFieldChange;

   y := y + ROWHEIGHT;
   FSpeedSync1 := TCheckBox.Create(grp);
   FSpeedSync1.Parent     := grp;
   FSpeedSync1.Position.X := 385;
   FSpeedSync1.Position.Y := y;
   FSpeedSync1.Width      := 140;
   FSpeedSync1.Text       := TC_PREFS_SPEEDSYNC;
   FSpeedSync1.OnChange   := HandleFieldChange;

   y := y + ROWHEIGHT;
   MakeLabel(grp, TC_PREFS_RADIO2, 12, y + 4, 70);
   FRadio2Combo := TComboBox.Create(grp);
   FRadio2Combo.Parent     := grp;
   FRadio2Combo.Position.X := 90;
   FRadio2Combo.Position.Y := y;
   FRadio2Combo.Width      := 190;
   FRadio2Combo.OnChange   := HandleFieldChange;

   MakeLabel(grp, TC_PREFS_CWOUTPUT2, 290, y + 4, 90);
   FCW2Combo := TComboBox.Create(grp);
   FCW2Combo.Parent     := grp;
   FCW2Combo.Position.X := 385;
   FCW2Combo.Position.Y := y;
   FCW2Combo.Width      := 140;
   FCW2Combo.OnChange   := HandleFieldChange;

   y := y + ROWHEIGHT;
   FSpeedSync2 := TCheckBox.Create(grp);
   FSpeedSync2.Parent     := grp;
   FSpeedSync2.Position.X := 385;
   FSpeedSync2.Position.Y := y;
   FSpeedSync2.Width      := 140;
   FSpeedSync2.Text       := TC_PREFS_SPEEDSYNC;
   FSpeedSync2.OnChange   := HandleFieldChange;

   y := y + ROWHEIGHT;
   FSO2RCheck := TCheckBox.Create(grp);
   FSO2RCheck.Parent     := grp;
   FSO2RCheck.Position.X := 12;
   FSO2RCheck.Position.Y := y;
   FSO2RCheck.Width      := 200;
   FSO2RCheck.Text       := TC_PREFS_SO2R;
   FSO2RCheck.OnChange   := HandleFieldChange;

   y := y + ROWHEIGHT;
   FActiveLabel := MakeLabel(grp, TC_PREFS_ACTIVELABEL, 12, y + 4, 260);
   MakeButton(grp, TC_PREFS_ACTIVATE, 300, y, 225, HandleActivate);

   // --- general ------------------------------------------------------------
   FAutoConnect := TCheckBox.Create(FHardwarePanel);
   FAutoConnect.Parent     := FHardwarePanel;
   FAutoConnect.Position.X := LEFTMARGIN;
   FAutoConnect.Position.Y := 458;
   FAutoConnect.Width      := 300;
   FAutoConnect.Text       := TC_PREFS_AUTOCONNECT;
   FAutoConnect.OnChange   := HandleFieldChange;
end;

{ ------------------------------------------------------------ the store --- }

// The store paths live in uRadioConfigApply, because STARTUP needs them too
// and must not depend on this UI unit.  Two spellings of the same path is
// precisely the divergence this whole change is about.
function TPrefsForm.StoreFileName: string;
begin
   Result := RadioStoreFileName;
end;

function TPrefsForm.LegacyStoreFileName: string;
begin
   Result := LegacyRadioStoreFileName;
end;

procedure TPrefsForm.LoadStore;
var
   ini: TIniFile;
   legacy: TIniFile;
   err: string;
begin
   // 1. The JSON store, if there is one.
   if FStore.LoadFromFile(StoreFileName, err) then
      begin
      Exit;
      end;

   // A file that EXISTS but would not parse is worth a line in the log: the
   // fall-through below is about to present an empty library, and "my radios
   // vanished" is a much harder question to answer without this.
   if FileExists(StoreFileName) then
      begin
      logger.Warn('[Preferences] %s could not be read (%s) -- falling back', [StoreFileName, err]);
      end;

   // 2. The ini store from before F-5a, migrated once.  Saving it back out in
   //    JSON is deliberate: without that the migration would run on every open
   //    and an operator's later edits would keep being overwritten by the ini.
   if FileExists(LegacyStoreFileName) then
      begin
      ini := TIniFile.Create(LegacyStoreFileName);
      try
         FStore.LoadFrom(ini);
      finally
         ini.Free;
      end;

      if FStore.RadioCount > 0 then
         begin
         logger.Info('[Preferences] migrated %d radio(s) from %s to %s',
                     [FStore.RadioCount, LegacyStoreFileName, StoreFileName]);
         FStore.SaveToFile(StoreFileName);
         Exit;
         end;
      end;

   // 3. First run of all: build the library from the configuration the operator
   //    already has, rather than presenting an empty list to someone with two
   //    working radios.  The legacy file is opened READ-ONLY -- seeding must
   //    not be able to damage a configuration still in use.
   legacy := TIniFile.Create(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0]))));
   try
      if TRadioConfigStore.LegacyIniHasRadios(legacy) then
         begin
         FStore.SeedFromLegacyIni(legacy);
         end;
   finally
      legacy.Free;
   end;
end;

function TPrefsForm.SaveStore(out aError: string): boolean;
begin
   Result := FStore.Validate(aError);
   if not Result then
      begin
      Exit;
      end;

   try
      FStore.SaveToFile(StoreFileName);
   except
      // A failed SAVE must be reported, not swallowed: the operator would
      // otherwise close the dialog believing their library was stored.
      on E: Exception do
         begin
         aError := 'Could not write ' + StoreFileName + ': ' + E.Message;
         logger.Error('[Preferences] %s', [aError]);
         Result := False;
      end;
   end;
end;

{ ------------------------------------------------------------- refresh ---- }

function TPrefsForm.CurrentProfile: TStationProfile;
begin
   Result := FStore.FindProfile(SelectedTag(FProfileCombo));
end;

function TPrefsForm.SelectedRadio: TRadioDefinition;
begin
   Result := nil;
   if FRadioList.ItemIndex >= 0 then
      begin
      Result := FStore.FindRadio(FRadioList.ListItems[FRadioList.ItemIndex].TagString);
      end;
end;

procedure TPrefsForm.RefreshRadioList;
var
   i, keep: integer;
   item: TListBoxItem;
begin
   keep := FRadioList.ItemIndex;
   FRadioList.Clear;
   for i := 0 to FStore.RadioCount - 1 do
      begin
      item := TListBoxItem.Create(FRadioList);
      item.Parent    := FRadioList;
      item.Text      := FStore.Radio(i).DisplaySummary;
      item.TagString := FStore.Radio(i).Name;
      end;
   if (keep >= 0) and (keep < FRadioList.Items.Count) then
      begin
      FRadioList.ItemIndex := keep;
      end
   else if FRadioList.Items.Count > 0 then
      begin
      FRadioList.ItemIndex := 0;
      end;
end;

procedure TPrefsForm.FillRadioNameCombo(const aCombo: TComboBox; const aSelected: string);
var
   i: integer;
begin
   aCombo.Clear;
   AddComboItem(aCombo, TC_PREFS_NONE, '');
   for i := 0 to FStore.RadioCount - 1 do
      begin
      AddComboItem(aCombo, FStore.Radio(i).Name, FStore.Radio(i).Name);
      end;
   SelectByTag(aCombo, aSelected);
end;

procedure TPrefsForm.FillCWOutputCombo(const aCombo: TComboBox; const aSelected: string);
var
   enumerator: TComPortEnumerator;
   names: TArray<string>;
   i: integer;
begin
   aCombo.Clear;
   AddComboItem(aCombo, TC_PREFS_NONE, CWOUTPUT_NONE);
   AddComboItem(aCombo, 'CW by CAT',   CWOUTPUT_CAT);

   enumerator := TComPortEnumerator.Create;
   try
      enumerator.Refresh;
      names := enumerator.PortNames;
      for i := 0 to High(names) do
         begin
         AddComboItem(aCombo, names[i], ComNameToPortValue(names[i]));
         end;
   finally
      enumerator.Free;
   end;

   SelectByTag(aCombo, aSelected);
end;

procedure TPrefsForm.RefreshProfileCombo;
var
   i: integer;
   keep: string;
begin
   keep := SelectedTag(FProfileCombo);
   if keep = '' then
      begin
      keep := FStore.ActiveProfileName;
      end;

   FProfileCombo.Clear;
   for i := 0 to FStore.ProfileCount - 1 do
      begin
      AddComboItem(FProfileCombo, FStore.Profile(i).Name, FStore.Profile(i).Name);
      end;
   SelectByTag(FProfileCombo, keep);
end;

procedure TPrefsForm.RefreshProfileFields;
var
   prof: TStationProfile;
begin
   // FLoading guards the OnChange handlers: filling a combo fires OnChange, and
   // without this the act of DISPLAYING a profile would write the previous
   // profile's values into it.
   FLoading := True;
   try
      prof := CurrentProfile;
      if prof = nil then
         begin
         FillRadioNameCombo(FRadio1Combo, '');
         FillRadioNameCombo(FRadio2Combo, '');
         FillCWOutputCombo(FCW1Combo, CWOUTPUT_NONE);
         FillCWOutputCombo(FCW2Combo, CWOUTPUT_NONE);
         FSpeedSync1.IsChecked := False;
         FSpeedSync2.IsChecked := False;
         FSO2RCheck.IsChecked  := False;
         end
      else
         begin
         FillRadioNameCombo(FRadio1Combo, prof.Radio1Name);
         FillRadioNameCombo(FRadio2Combo, prof.Radio2Name);
         FillCWOutputCombo(FCW1Combo, prof.CWOutput1);
         FillCWOutputCombo(FCW2Combo, prof.CWOutput2);
         FSpeedSync1.IsChecked := prof.SpeedSync1;
         FSpeedSync2.IsChecked := prof.SpeedSync2;
         FSO2RCheck.IsChecked  := prof.SO2REnabled;
         end;

      FAutoConnect.IsChecked := FStore.AutoConnectOnStartup;

      if FStore.ActiveProfileName <> '' then
         begin
         FActiveLabel.Text := TC_PREFS_ACTIVELABEL + FStore.ActiveProfileName;
         end
      else
         begin
         FActiveLabel.Text := TC_PREFS_ACTIVELABEL + TC_PREFS_NONE;
         end;
   finally
      FLoading := False;
   end;
end;

procedure TPrefsForm.RefreshAll;
begin
   RefreshRadioList;
   RefreshProfileCombo;
   RefreshProfileFields;
end;

procedure TPrefsForm.CaptureProfileFields;
var
   prof: TStationProfile;
begin
   if FLoading then
      begin
      Exit;
      end;

   FStore.AutoConnectOnStartup := FAutoConnect.IsChecked;

   prof := CurrentProfile;
   if prof = nil then
      begin
      Exit;
      end;

   prof.Radio1Name  := SelectedTag(FRadio1Combo);
   prof.Radio2Name  := SelectedTag(FRadio2Combo);
   prof.CWOutput1   := SelectedTag(FCW1Combo);
   prof.CWOutput2   := SelectedTag(FCW2Combo);
   prof.SpeedSync1  := FSpeedSync1.IsChecked;
   prof.SpeedSync2  := FSpeedSync2.IsChecked;
   prof.SO2REnabled := FSO2RCheck.IsChecked;

   FDirty := True;
end;

{ -------------------------------------------------------------- events ---- }

procedure TPrefsForm.HandleNavChange(Sender: TObject);
var
   isHardware: boolean;
begin
   isHardware := (FNavList.ItemIndex >= 0) and
                 SameText(FNavList.ListItems[FNavList.ItemIndex].TagString, TC_PREFS_HARDWARE);
   FHardwarePanel.Visible := isHardware;
   FPlaceholder.Visible   := not isHardware;
end;

procedure TPrefsForm.HandleAdd(Sender: TObject);
begin
   if FEditor = nil then
      begin
      FEditor := TRadioEditForm.Create(Self);
      end;

   FEditIsNew  := True;
   FEditTarget := nil;
   FreeAndNil(FEditClone);
   FEditClone := TRadioDefinition.Create;
   FEditClone.Name := FStore.UniqueRadioName('Radio');

   FEditor.EditRadio(FEditClone, EditorDone);
end;

procedure TPrefsForm.HandleEdit(Sender: TObject);
var
   radio: TRadioDefinition;
begin
   radio := SelectedRadio;
   if radio = nil then
      begin
      Exit;
      end;

   if FEditor = nil then
      begin
      FEditor := TRadioEditForm.Create(Self);
      end;

   // The editor works on a CLONE, so Cancel really cancels.  The original is
   // remembered so the result can be copied back onto it -- keeping the object
   // identity means profiles referring to it stay valid.
   FEditIsNew  := False;
   FEditTarget := radio;
   FreeAndNil(FEditClone);
   FEditClone := radio.Clone;

   FEditor.EditRadio(FEditClone, EditorDone);
end;

procedure TPrefsForm.HandleRadioDblClick(Sender: TObject);
begin
   HandleEdit(Sender);
end;

procedure TPrefsForm.HandleDuplicate(Sender: TObject);
var
   radio, copy: TRadioDefinition;
   err: string;
begin
   radio := SelectedRadio;
   if radio = nil then
      begin
      Exit;
      end;

   copy := radio.Clone;
   copy.Name := FStore.UniqueRadioName(radio.Name);
   if FStore.AddRadio(copy, err) then
      begin
      FDirty := True;
      RefreshAll;
      end
   else
      begin
      copy.Free;
      ShowMessage(err);
      end;
end;

procedure TPrefsForm.HandleRemove(Sender: TObject);
var
   radio: TRadioDefinition;
   err: string;
begin
   radio := SelectedRadio;
   if radio = nil then
      begin
      Exit;
      end;

   if MessageBoxA(FormToHWND(Self),
                  PAnsiChar(AnsiString(Format(TC_PREFS_CONFIRMREMOVE, [radio.Name]))),
                  'TR4W', MB_YESNO or MB_ICONQUESTION) <> IDYES then
      begin
      Exit;
      end;

   // The store refuses while a profile still refers to it, and says which --
   // a dangling reference would be a profile that silently loses a radio.
   if FStore.DeleteRadio(radio.Name, err) then
      begin
      FDirty := True;
      RefreshAll;
      end
   else
      begin
      ShowMessage(err);
      end;
end;

procedure TPrefsForm.EditorDone(const aAccepted: boolean);
var
   err: string;
begin
   if not aAccepted then
      begin
      FreeAndNil(FEditClone);
      Exit;
      end;

   if FEditIsNew then
      begin
      if FStore.AddRadio(FEditClone, err) then
         begin
         FEditClone := nil;   // the store owns it now
         end
      else
         begin
         ShowMessage(err);
         FreeAndNil(FEditClone);
         end;
      end
   else if FEditTarget <> nil then
      begin
      // A rename has to go through the store so profile references follow it.
      if not SameText(FEditTarget.Name, FEditClone.Name) then
         begin
         if not FStore.RenameRadio(FEditTarget.Name, FEditClone.Name, err) then
            begin
            ShowMessage(err);
            FreeAndNil(FEditClone);
            Exit;
            end;
         end;
      FEditTarget.Assign(FEditClone);
      FreeAndNil(FEditClone);
      end;

   FDirty := True;
   RefreshAll;
end;

procedure TPrefsForm.HandleNewProfile(Sender: TObject);
var
   prof: TStationProfile;
   name: string;
   err: string;
begin
   name := '';
   if not InputQuery(TC_PREFS_PROFILES, TC_PREFS_NEWPROFILE, name) then
      begin
      Exit;
      end;

   prof := TStationProfile.Create;
   prof.Name := name;
   if FStore.AddProfile(prof, err) then
      begin
      FDirty := True;
      RefreshProfileCombo;
      SelectByTag(FProfileCombo, prof.Name);
      RefreshProfileFields;
      end
   else
      begin
      prof.Free;
      ShowMessage(err);
      end;
end;

procedure TPrefsForm.HandleRenameProfile(Sender: TObject);
var
   prof: TStationProfile;
   name: string;
begin
   prof := CurrentProfile;
   if prof = nil then
      begin
      Exit;
      end;

   name := prof.Name;
   if not InputQuery(TC_PREFS_PROFILES, TC_PREFS_RENAMEPROFILE, name) then
      begin
      Exit;
      end;
   if Trim(name) = '' then
      begin
      Exit;
      end;

   if FStore.ActiveProfileName = prof.Name then
      begin
      FStore.ActiveProfileName := Trim(name);
      end;
   prof.Name := Trim(name);
   FDirty := True;
   RefreshProfileCombo;
   SelectByTag(FProfileCombo, prof.Name);
   RefreshProfileFields;
end;

procedure TPrefsForm.HandleDeleteProfile(Sender: TObject);
var
   prof: TStationProfile;
   err: string;
begin
   prof := CurrentProfile;
   if prof = nil then
      begin
      Exit;
      end;
   if FStore.DeleteProfile(prof.Name, err) then
      begin
      FDirty := True;
      RefreshAll;
      end
   else
      begin
      ShowMessage(err);
      end;
end;

procedure TPrefsForm.HandleProfileChange(Sender: TObject);
begin
   if FLoading then
      begin
      Exit;
      end;
   RefreshProfileFields;
end;

procedure TPrefsForm.HandleFieldChange(Sender: TObject);
begin
   CaptureProfileFields;
end;

function TPrefsForm.ApplyNow(const aActivate: boolean): boolean;
var
   prof: TStationProfile;
   err, conflicts: string;
begin
   Result := False;
   CaptureProfileFields;

   if not SaveStore(err) then
      begin
      ShowMessage(err);
      Exit;
      end;

   FDirty := False;

   if not aActivate then
      begin
      Result := True;
      Exit;
      end;

   prof := CurrentProfile;
   if prof = nil then
      begin
      ShowMessage(TC_PREFS_NOPROFILE);
      Exit;
      end;

   // Advisory, not fatal: some collisions are legitimate on a shared cable, so
   // the operator decides.  Validate has already refused the ones that cannot
   // work at all.
   conflicts := DescribePortConflicts(FStore, prof);
   if conflicts <> '' then
      begin
      if MessageBoxA(FormToHWND(Self),
                     PAnsiChar(AnsiString(Format(TC_PREFS_PORTCONFLICT, [conflicts]))),
                     'TR4W', MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2) <> IDYES then
         begin
         Exit;
         end;
      end;

   if not ApplyProfile(FStore, prof, err) then
      begin
      ShowMessage(err);
      Exit;
      end;

   // ApplyProfile sets the active name; persist that too, or a restart would
   // come up on the previously active profile.
   if not SaveStore(err) then
      begin
      ShowMessage(err);
      Exit;
      end;

   RefreshProfileFields;
   ShowMessage(Format(TC_PREFS_APPLIED, [prof.Name]));
   Result := True;
end;

procedure TPrefsForm.HandleActivate(Sender: TObject);
begin
   ApplyNow(True);
end;

procedure TPrefsForm.HandleApply(Sender: TObject);
begin
   // Apply saves but does NOT activate: an operator adjusting a radio they are
   // not currently using should not have their live radios restarted.
   ApplyNow(False);
end;

procedure TPrefsForm.HandleOK(Sender: TObject);
begin
   if ApplyNow(False) then
      begin
      Hide;
      end;
end;

procedure TPrefsForm.DiscardChanges;
begin
   // Throw the working copy away and reload from disk, so that reopening shows
   // what is actually stored rather than the edits just abandoned.
   FStore.Clear;
   LoadStore;
   FDirty := False;
   RefreshAll;
end;

procedure TPrefsForm.HandleCancel(Sender: TObject);
begin
   DiscardChanges;
   Hide;
end;

procedure TPrefsForm.HandleShow(Sender: TObject);
begin
   RegisterFMXFormHandle(FormToHWND(Self));
end;

procedure TPrefsForm.HandleClose(Sender: TObject; var Action: TCloseAction);
var
   answer: integer;
begin
   // The X is easy to hit by accident, so unsaved work gets a question rather
   // than being silently kept OR silently thrown away.  Cancel means "do not
   // close" -- caNone -- which is the option that makes the prompt safe to
   // dismiss.
   if FDirty then
      begin
      answer := MessageBoxA(FormToHWND(Self),
                            PAnsiChar(AnsiString(TC_PREFS_UNSAVED)),
                            PAnsiChar(AnsiString(TC_PREFS_UNSAVEDTITLE)),
                            MB_YESNOCANCEL or MB_ICONQUESTION);
      if answer = IDCANCEL then
         begin
         Action := TCloseAction.caNone;
         Exit;
         end;

      if answer = IDYES then
         begin
         // A save that fails (validation, a bad path) must NOT close the window
         // and lose the work it just refused to store.
         if not ApplyNow(False) then
            begin
            Action := TCloseAction.caNone;
            Exit;
            end;
         end
      else
         begin
         DiscardChanges;
         end;
      end;

   UnregisterFMXFormHandle(FormToHWND(Self));
   // Hide, never free: freeing a form from inside its own event handler is the
   // classic way to crash on the way out, and reopening should be instant.
   Action := TCloseAction.caHide;
end;

initialization

finalization
   FreeAndNil(gPrefsForm);

end.
