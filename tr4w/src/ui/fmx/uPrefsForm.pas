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
   FMX.Controls.Presentation,
   uRadioConfigStore;

const
   // --- captions ------------------------------------------------------------
   // ONE place, so the i18n lift is mechanical.  See the unit header.
   TC_PREFS_TITLE            = 'TR4W Preferences';
   TC_PREFS_HARDWARE         = 'Hardware';
   TC_PREFS_CONTEST          = 'Contest';
   TC_PREFS_CW               = 'CW';
   TC_PREFS_CLUSTER          = 'DX Cluster';
   TC_PREFS_NOTMIGRATED      = 'This section has not been migrated yet.' + sLineBreak +
                               'Use the existing configuration screens for it.';

   TC_PREFS_MYRADIOS         = 'My radios';
   TC_PREFS_ADD              = 'Add...';
   TC_PREFS_EDIT             = 'Edit...';
   TC_PREFS_DUPLICATE        = 'Duplicate';
   TC_PREFS_REMOVE           = 'Remove';

   TC_PREFS_PROFILES         = 'Station profile';
   TC_PREFS_NEWPROFILE       = 'New...';
   TC_PREFS_RENAMEPROFILE    = 'Rename...';
   TC_PREFS_DELETEPROFILE    = 'Delete';
   TC_PREFS_RADIO1           = 'Radio 1';
   TC_PREFS_RADIO2           = 'Radio 2';
   TC_PREFS_NONE             = '(none)';
   TC_PREFS_CWOUTPUT1        = 'CW output 1';
   TC_PREFS_CWOUTPUT2        = 'CW output 2';
   TC_PREFS_SPEEDSYNC        = 'Speed sync';
   TC_PREFS_SO2R             = 'SO2R enabled';
   TC_PREFS_AUTOCONNECT      = 'Connect radios at startup';
   TC_PREFS_ACTIVATE         = 'Activate this profile';
   TC_PREFS_ACTIVELABEL      = 'Active profile: ';

   TC_PREFS_OK               = 'OK';
   TC_PREFS_CANCEL           = 'Cancel';
   TC_PREFS_APPLY            = 'Apply';

   TC_PREFS_PORTCONFLICT     = 'Port conflicts:' + sLineBreak + sLineBreak + '%s' +
                               sLineBreak + sLineBreak + 'Apply anyway?';
   TC_PREFS_APPLIED          = 'Profile "%s" is active.';
   TC_PREFS_NOPROFILE        = 'Select or create a station profile first.';
   TC_PREFS_CONFIRMREMOVE    = 'Remove radio "%s"?';

   // --- radio editor --------------------------------------------------------
   TC_RADIOEDIT_TITLE        = 'Radio';
   TC_RADIOEDIT_NAME         = 'Name';
   TC_RADIOEDIT_TYPE         = 'Radio type';
   TC_RADIOEDIT_TRANSPORT    = 'Connection';
   TC_RADIOEDIT_SERIAL       = 'Serial';
   TC_RADIOEDIT_NETWORK      = 'Network';
   TC_RADIOEDIT_PORT         = 'Port';
   TC_RADIOEDIT_BAUD         = 'Baud rate';
   TC_RADIOEDIT_FORMAT       = 'Data/parity/stop';
   TC_RADIOEDIT_IPADDRESS    = 'IP address';
   TC_RADIOEDIT_TCPPORT      = 'TCP port';
   TC_RADIOEDIT_USERNAME     = 'User name';
   TC_RADIOEDIT_PASSWORD     = 'Password';
   TC_RADIOEDIT_KEYERPORT    = 'Keyer output port';
   TC_RADIOEDIT_CIVADDRESS   = 'CI-V address';
   TC_RADIOEDIT_HAMLIBID     = 'HamLib model ID';
   TC_RADIOEDIT_STARTUP      = 'Startup command';
   TC_RADIOEDIT_FILTERBYTE   = 'Icom filter byte';
   TC_RADIOEDIT_DATAMODEID   = 'Icom data mode ID';
   TC_RADIOEDIT_WIDECW       = 'Wide CW filter';
   TC_RADIOEDIT_FT1000MPREV  = 'FT-1000MP CW reverse';
   TC_RADIOEDIT_POLLING      = 'Poll this radio';
   TC_RADIOEDIT_USEHAMLIB    = 'Drive through HamLib';
   TC_RADIOEDIT_NAMEREQUIRED = 'The radio needs a name.';
   TC_RADIOEDIT_TYPEREQUIRED = 'Choose a radio type.';

type
   // Reports the editor's outcome.  A callback rather than a modal result,
   // because the editor is modeless -- see the unit header.
   TRadioEditDone = procedure(const aAccepted: boolean) of object;

   { Edits ONE TRadioDefinition.  It edits the caller's object directly and only
     when the operator accepts; the caller passes a clone if it wants a
     cancellable edit, which is what TPrefsForm does. }
   TRadioEditForm = class(TForm)
   private
      FRadio: TRadioDefinition;
      FOnDone: TRadioEditDone;

      FNameEdit: TEdit;
      FTypeCombo: TComboBox;
      FTransportCombo: TComboBox;
      FPortCombo: TComboBox;
      FBaudEdit: TEdit;
      FFormatEdit: TEdit;
      FIPEdit: TEdit;
      FTCPPortEdit: TEdit;
      FUserEdit: TEdit;
      FPasswordEdit: TEdit;
      FKeyerPortCombo: TComboBox;
      FCIVEdit: TEdit;
      FHamLibEdit: TEdit;
      FStartupEdit: TEdit;
      FPollingCheck: TCheckBox;
      FUseHamLibCheck: TCheckBox;
      // Radio-scoped settings that used to sit in the flat config-command list,
      // where they read as applying to the station rather than to one rig
      // (NY4I 2026-08-05).  Their CFGCA rows are now csOwned.
      FFilterByteEdit: TEdit;
      FDataModeEdit: TEdit;
      FWideCWCheck: TCheckBox;
      FFT1000MPRevCheck: TCheckBox;
      FSerialGroup: TGroupBox;
      FNetworkGroup: TGroupBox;

      procedure BuildControls;
      procedure PopulateTypeCombo;
      procedure PopulatePortCombos;
      procedure LoadFromRadio;
      function SaveToRadio(out aError: string): boolean;
      function SelectedRegistryId: string;
      procedure UpdateEnabledState;
      procedure HandleTypeChange(Sender: TObject);
      procedure HandleTransportChange(Sender: TObject);
      procedure HandleOK(Sender: TObject);
      procedure HandleCancel(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
   public
      constructor Create(AOwner: TComponent); override;
      procedure EditRadio(const aRadio: TRadioDefinition; const aOnDone: TRadioEditDone);
   end;

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
   Winapi.Windows,
   System.IniFiles,
   System.Generics.Collections,
   System.Generics.Defaults,
   FMX.Platform.Win,
   FMX.Dialogs,
   uFMXCoexist,
   uRadioConfigApply,
   uRadioRegistry,
   ComPortEnumerator,
   VC;

const
   ROWHEIGHT  = 30;
   LEFTMARGIN = 12;

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

{ ------------------------------------------------------------- helpers ---- }

function AddComboItem(const aCombo: TComboBox; const aText, aTag: string): TListBoxItem;
begin
   Result := TListBoxItem.Create(aCombo);
   Result.Parent    := aCombo;
   Result.Text      := aText;
   // The registry id / radio name travels in TagString, never as an index.
   // Index arithmetic against a list whose contents depend on what is plugged
   // in is how the legacy port combo grew its bugs.
   Result.TagString := aTag;
end;

// Select the item whose TagString matches, or the first item when it is absent.
procedure SelectByTag(const aCombo: TComboBox; const aTag: string);
var
   i: integer;
begin
   for i := 0 to aCombo.Items.Count - 1 do
      begin
      if SameText(aCombo.ListItems[i].TagString, aTag) then
         begin
         aCombo.ItemIndex := i;
         Exit;
         end;
      end;
   if aCombo.Items.Count > 0 then
      begin
      aCombo.ItemIndex := 0;
      end;
end;

function SelectedTag(const aCombo: TComboBox): string;
begin
   Result := '';
   if (aCombo.ItemIndex >= 0) and (aCombo.ItemIndex < aCombo.Items.Count) then
      begin
      Result := aCombo.ListItems[aCombo.ItemIndex].TagString;
      end;
end;

function MakeLabel(const aParent: TFmxObject; const aText: string;
                   const aX, aY, aWidth: single): TLabel;
begin
   Result := TLabel.Create(aParent);
   Result.Parent     := aParent;
   Result.Position.X := aX;
   Result.Position.Y := aY;
   Result.Width      := aWidth;
   Result.Text       := aText;
end;

function MakeButton(const aParent: TFmxObject; const aText: string;
                    const aX, aY, aWidth: single;
                    const aOnClick: TNotifyEvent): TButton;
begin
   Result := TButton.Create(aParent);
   Result.Parent     := aParent;
   Result.Position.X := aX;
   Result.Position.Y := aY;
   Result.Width      := aWidth;
   Result.Height     := 25;
   Result.Text       := aText;
   Result.OnClick    := aOnClick;
end;

// The 'SERIAL n' vocabulary CFGCA expects, from a Windows 'COMn' name.  Kept
// here rather than in the store: the store holds whatever string the UI chose,
// and the translation is a presentation concern.
function ComNameToPortValue(const aComName: string): string;
var
   n: integer;
begin
   n := ComPortNumber(aComName);
   if n > 0 then
      begin
      Result := 'SERIAL ' + IntToStr(n);
      end
   else
      begin
      Result := PORT_NONE;
      end;
end;

{ =========================================================== TRadioEditForm = }

constructor TRadioEditForm.Create(AOwner: TComponent);
begin
   inherited CreateNew(AOwner);
   Caption     := TC_RADIOEDIT_TITLE;
   Width       := 520;
   Height      := 660;
   Position    := TFormPosition.ScreenCenter;
   BorderStyle := TFmxFormBorderStyle.Sizeable;
   OnShow      := HandleShow;
   OnClose     := HandleClose;
   BuildControls;
end;

procedure TRadioEditForm.BuildControls;
var
   y: single;
   grp: TGroupBox;

   function NextRow: single;
   begin
      Result := y;
      y := y + ROWHEIGHT;
   end;

begin
   y := 12;

   MakeLabel(Self, TC_RADIOEDIT_NAME, LEFTMARGIN, y + 4, 120);
   FNameEdit := TEdit.Create(Self);
   FNameEdit.Parent     := Self;
   FNameEdit.Position.X := 140;
   FNameEdit.Position.Y := NextRow;
   FNameEdit.Width      := 340;

   MakeLabel(Self, TC_RADIOEDIT_TYPE, LEFTMARGIN, y + 4, 120);
   FTypeCombo := TComboBox.Create(Self);
   FTypeCombo.Parent     := Self;
   FTypeCombo.Position.X := 140;
   FTypeCombo.Position.Y := NextRow;
   FTypeCombo.Width      := 340;
   FTypeCombo.OnChange   := HandleTypeChange;

   MakeLabel(Self, TC_RADIOEDIT_TRANSPORT, LEFTMARGIN, y + 4, 120);
   FTransportCombo := TComboBox.Create(Self);
   FTransportCombo.Parent     := Self;
   FTransportCombo.Position.X := 140;
   FTransportCombo.Position.Y := NextRow;
   FTransportCombo.Width      := 200;
   FTransportCombo.OnChange   := HandleTransportChange;
   AddComboItem(FTransportCombo, TC_RADIOEDIT_SERIAL,  TransportToStr(rtSerial));
   AddComboItem(FTransportCombo, TC_RADIOEDIT_NETWORK, TransportToStr(rtNetwork));

   // --- serial ------------------------------------------------------------
   FSerialGroup := TGroupBox.Create(Self);
   FSerialGroup.Parent     := Self;
   FSerialGroup.Position.X := LEFTMARGIN;
   FSerialGroup.Position.Y := NextRow;
   FSerialGroup.Width      := 480;
   FSerialGroup.Height     := 3 * ROWHEIGHT + 20;
   FSerialGroup.Text       := TC_RADIOEDIT_SERIAL;
   y := y + FSerialGroup.Height - ROWHEIGHT + 8;

   grp := FSerialGroup;
   MakeLabel(grp, TC_RADIOEDIT_PORT, 10, 12, 120);
   FPortCombo := TComboBox.Create(grp);
   FPortCombo.Parent     := grp;
   FPortCombo.Position.X := 140;
   FPortCombo.Position.Y := 8;
   FPortCombo.Width      := 320;

   MakeLabel(grp, TC_RADIOEDIT_BAUD, 10, 12 + ROWHEIGHT, 120);
   FBaudEdit := TEdit.Create(grp);
   FBaudEdit.Parent     := grp;
   FBaudEdit.Position.X := 140;
   FBaudEdit.Position.Y := 8 + ROWHEIGHT;
   FBaudEdit.Width      := 120;

   MakeLabel(grp, TC_RADIOEDIT_FORMAT, 10, 12 + 2 * ROWHEIGHT, 120);
   FFormatEdit := TEdit.Create(grp);
   FFormatEdit.Parent     := grp;
   FFormatEdit.Position.X := 140;
   FFormatEdit.Position.Y := 8 + 2 * ROWHEIGHT;
   FFormatEdit.Width      := 120;

   // --- network -----------------------------------------------------------
   FNetworkGroup := TGroupBox.Create(Self);
   FNetworkGroup.Parent     := Self;
   FNetworkGroup.Position.X := LEFTMARGIN;
   FNetworkGroup.Position.Y := NextRow;
   FNetworkGroup.Width      := 480;
   FNetworkGroup.Height     := 4 * ROWHEIGHT + 20;
   FNetworkGroup.Text       := TC_RADIOEDIT_NETWORK;
   y := y + FNetworkGroup.Height - ROWHEIGHT + 8;

   grp := FNetworkGroup;
   MakeLabel(grp, TC_RADIOEDIT_IPADDRESS, 10, 12, 120);
   FIPEdit := TEdit.Create(grp);
   FIPEdit.Parent     := grp;
   FIPEdit.Position.X := 140;
   FIPEdit.Position.Y := 8;
   FIPEdit.Width      := 200;

   MakeLabel(grp, TC_RADIOEDIT_TCPPORT, 10, 12 + ROWHEIGHT, 120);
   FTCPPortEdit := TEdit.Create(grp);
   FTCPPortEdit.Parent     := grp;
   FTCPPortEdit.Position.X := 140;
   FTCPPortEdit.Position.Y := 8 + ROWHEIGHT;
   FTCPPortEdit.Width      := 120;

   MakeLabel(grp, TC_RADIOEDIT_USERNAME, 10, 12 + 2 * ROWHEIGHT, 120);
   FUserEdit := TEdit.Create(grp);
   FUserEdit.Parent     := grp;
   FUserEdit.Position.X := 140;
   FUserEdit.Position.Y := 8 + 2 * ROWHEIGHT;
   FUserEdit.Width      := 200;

   MakeLabel(grp, TC_RADIOEDIT_PASSWORD, 10, 12 + 3 * ROWHEIGHT, 120);
   FPasswordEdit := TEdit.Create(grp);
   FPasswordEdit.Parent     := grp;
   FPasswordEdit.Position.X := 140;
   FPasswordEdit.Position.Y := 8 + 3 * ROWHEIGHT;
   FPasswordEdit.Width      := 200;
   FPasswordEdit.Password   := True;

   // --- options -----------------------------------------------------------
   MakeLabel(Self, TC_RADIOEDIT_KEYERPORT, LEFTMARGIN, y + 4, 130);
   FKeyerPortCombo := TComboBox.Create(Self);
   FKeyerPortCombo.Parent     := Self;
   FKeyerPortCombo.Position.X := 150;
   FKeyerPortCombo.Position.Y := NextRow;
   FKeyerPortCombo.Width      := 200;

   MakeLabel(Self, TC_RADIOEDIT_CIVADDRESS, LEFTMARGIN, y + 4, 130);
   FCIVEdit := TEdit.Create(Self);
   FCIVEdit.Parent     := Self;
   FCIVEdit.Position.X := 150;
   FCIVEdit.Position.Y := NextRow;
   FCIVEdit.Width      := 80;

   MakeLabel(Self, TC_RADIOEDIT_HAMLIBID, LEFTMARGIN, y + 4, 130);
   FHamLibEdit := TEdit.Create(Self);
   FHamLibEdit.Parent     := Self;
   FHamLibEdit.Position.X := 150;
   FHamLibEdit.Position.Y := NextRow;
   FHamLibEdit.Width      := 80;

   MakeLabel(Self, TC_RADIOEDIT_STARTUP, LEFTMARGIN, y + 4, 130);
   FStartupEdit := TEdit.Create(Self);
   FStartupEdit.Parent     := Self;
   FStartupEdit.Position.X := 150;
   FStartupEdit.Position.Y := NextRow;
   FStartupEdit.Width      := 330;

   FUseHamLibCheck := TCheckBox.Create(Self);
   FUseHamLibCheck.Parent     := Self;
   FUseHamLibCheck.Position.X := LEFTMARGIN;
   FUseHamLibCheck.Position.Y := NextRow;
   FUseHamLibCheck.Width      := 220;
   FUseHamLibCheck.Text       := TC_RADIOEDIT_USEHAMLIB;

   FPollingCheck := TCheckBox.Create(Self);
   FPollingCheck.Parent     := Self;
   FPollingCheck.Position.X := 250;
   FPollingCheck.Position.Y := FUseHamLibCheck.Position.Y;
   FPollingCheck.Width      := 220;
   FPollingCheck.Text       := TC_RADIOEDIT_POLLING;

   NextRow;

   // --- radio-scoped settings lifted out of the config-command dialog -------
   MakeLabel(Self, TC_RADIOEDIT_FILTERBYTE, LEFTMARGIN, y + 4, 130);
   FFilterByteEdit := TEdit.Create(Self);
   FFilterByteEdit.Parent     := Self;
   FFilterByteEdit.Position.X := 150;
   FFilterByteEdit.Position.Y := y;
   FFilterByteEdit.Width      := 80;

   MakeLabel(Self, TC_RADIOEDIT_DATAMODEID, 250, y + 4, 140);
   FDataModeEdit := TEdit.Create(Self);
   FDataModeEdit.Parent     := Self;
   FDataModeEdit.Position.X := 400;
   FDataModeEdit.Position.Y := NextRow;
   FDataModeEdit.Width      := 80;

   FWideCWCheck := TCheckBox.Create(Self);
   FWideCWCheck.Parent     := Self;
   FWideCWCheck.Position.X := LEFTMARGIN;
   FWideCWCheck.Position.Y := y;
   FWideCWCheck.Width      := 200;
   FWideCWCheck.Text       := TC_RADIOEDIT_WIDECW;

   FFT1000MPRevCheck := TCheckBox.Create(Self);
   FFT1000MPRevCheck.Parent     := Self;
   FFT1000MPRevCheck.Position.X := 250;
   FFT1000MPRevCheck.Position.Y := NextRow;
   FFT1000MPRevCheck.Width      := 230;
   FFT1000MPRevCheck.Text       := TC_RADIOEDIT_FT1000MPREV;

   NextRow;
   MakeButton(Self, TC_PREFS_OK,     280, y, 90, HandleOK);
   MakeButton(Self, TC_PREFS_CANCEL, 380, y, 90, HandleCancel);

   PopulateTypeCombo;
   PopulatePortCombos;
end;

procedure TRadioEditForm.PopulateTypeCombo;
var
   ids: TArray<string>;
   labels: TList<string>;
   i: integer;
begin
   // Built from the REGISTRY, not from a hand-kept list: adding a radio unit
   // must make it selectable here with no change to this file.  RegisteredIds
   // covers enum-backed and string-id radios alike, which is what makes TCI
   // appear without a special case.
   FTypeCombo.Clear;
   ids := RegisteredIds;

   labels := TList<string>.Create;
   try
      for i := 0 to High(ids) do
         begin
         labels.Add(DisplayNameId(ids[i]) + #9 + ids[i]);
         end;
      labels.Sort(TComparer<string>.Construct(
         function(const L, R: string): integer
         begin
            Result := CompareText(L, R);
         end));

      for i := 0 to labels.Count - 1 do
         begin
         AddComboItem(FTypeCombo,
                      Copy(labels[i], 1, Pos(#9, labels[i]) - 1),
                      Copy(labels[i], Pos(#9, labels[i]) + 1, MaxInt));
         end;
   finally
      labels.Free;
   end;
end;

procedure TRadioEditForm.PopulatePortCombos;
var
   enumerator: TComPortEnumerator;
   names: TArray<string>;
   info: TComPortInfo;
   i: integer;
   caption: string;
begin
   FPortCombo.Clear;
   FKeyerPortCombo.Clear;

   AddComboItem(FPortCombo,      TC_PREFS_NONE, PORT_NONE);
   AddComboItem(FKeyerPortCombo, TC_PREFS_NONE, PORT_NONE);

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
         // The friendly name is shown; the CONFIG VALUE is what travels in the
         // tag.  Storing the displayed text would put 'COM17 - Silicon Labs
         // CP210x' into the ini, which is exactly the corruption the legacy
         // dialog had to be fixed for.
         AddComboItem(FPortCombo,      caption, ComNameToPortValue(names[i]));
         AddComboItem(FKeyerPortCombo, caption, ComNameToPortValue(names[i]));
         end;
   finally
      enumerator.Free;
   end;
end;

procedure TRadioEditForm.EditRadio(const aRadio: TRadioDefinition;
                                   const aOnDone: TRadioEditDone);
begin
   FRadio  := aRadio;
   FOnDone := aOnDone;
   PopulatePortCombos;   // ports may have changed since the form was built
   LoadFromRadio;
   Show;
   BringToFront;
end;

procedure TRadioEditForm.LoadFromRadio;
begin
   if FRadio = nil then
      begin
      Exit;
      end;

   FNameEdit.Text := FRadio.Name;
   SelectByTag(FTypeCombo, FRadio.RegistryId);
   SelectByTag(FTransportCombo, TransportToStr(FRadio.Transport));

   SelectByTag(FPortCombo, FRadio.ControlPort);
   if FRadio.BaudRate > 0 then
      begin
      FBaudEdit.Text := IntToStr(FRadio.BaudRate);
      end
   else
      begin
      FBaudEdit.Text := '';
      end;
   FFormatEdit.Text := FRadio.SerialFormat;

   FIPEdit.Text       := FRadio.IPAddress;
   if FRadio.TCPPort > 0 then
      begin
      FTCPPortEdit.Text := IntToStr(FRadio.TCPPort);
      end
   else
      begin
      FTCPPortEdit.Text := '';
      end;
   FUserEdit.Text     := FRadio.NetworkUsername;
   FPasswordEdit.Text := FRadio.NetworkPassword;

   SelectByTag(FKeyerPortCombo, FRadio.KeyerOutputPort);
   if FRadio.ReceiverAddress > 0 then
      begin
      FCIVEdit.Text := IntToStr(FRadio.ReceiverAddress);
      end
   else
      begin
      FCIVEdit.Text := '';
      end;
   if FRadio.HamLibID > 0 then
      begin
      FHamLibEdit.Text := IntToStr(FRadio.HamLibID);
      end
   else
      begin
      FHamLibEdit.Text := '';
      end;
   FStartupEdit.Text        := FRadio.StartupCommand;
   if FRadio.IcomFilterByte > 0 then
      begin
      FFilterByteEdit.Text := IntToStr(FRadio.IcomFilterByte);
      end
   else
      begin
      FFilterByteEdit.Text := '';
      end;
   if FRadio.IcomDataModeID > 0 then
      begin
      FDataModeEdit.Text := IntToStr(FRadio.IcomDataModeID);
      end
   else
      begin
      FDataModeEdit.Text := '';
      end;
   FWideCWCheck.IsChecked      := FRadio.WideCWFilter;
   FFT1000MPRevCheck.IsChecked := FRadio.FT1000MPCWReverse;
   FUseHamLibCheck.IsChecked := FRadio.UseHamLib;
   FPollingCheck.IsChecked   := FRadio.PollingEnable;

   UpdateEnabledState;
end;

function TRadioEditForm.SelectedRegistryId: string;
begin
   Result := SelectedTag(FTypeCombo);
end;

function TRadioEditForm.SaveToRadio(out aError: string): boolean;
begin
   aError := '';
   Result := False;

   if Trim(FNameEdit.Text) = '' then
      begin
      aError := TC_RADIOEDIT_NAMEREQUIRED;
      Exit;
      end;
   if SelectedRegistryId = '' then
      begin
      aError := TC_RADIOEDIT_TYPEREQUIRED;
      Exit;
      end;

   FRadio.Name       := Trim(FNameEdit.Text);
   FRadio.RegistryId := SelectedRegistryId;
   FRadio.Transport  := StrToTransport(SelectedTag(FTransportCombo));

   FRadio.ControlPort  := SelectedTag(FPortCombo);
   FRadio.BaudRate     := StrToIntDef(Trim(FBaudEdit.Text), 0);
   FRadio.SerialFormat := Trim(FFormatEdit.Text);

   FRadio.IPAddress       := Trim(FIPEdit.Text);
   FRadio.TCPPort         := StrToIntDef(Trim(FTCPPortEdit.Text), 0);
   FRadio.NetworkUsername := Trim(FUserEdit.Text);
   FRadio.NetworkPassword := FPasswordEdit.Text;   // not trimmed: it is a password

   FRadio.KeyerOutputPort := SelectedTag(FKeyerPortCombo);
   FRadio.ReceiverAddress := StrToIntDef(Trim(FCIVEdit.Text), 0);
   FRadio.HamLibID        := StrToIntDef(Trim(FHamLibEdit.Text), 0);
   FRadio.StartupCommand  := Trim(FStartupEdit.Text);
   FRadio.IcomFilterByte    := StrToIntDef(Trim(FFilterByteEdit.Text), 0);
   FRadio.IcomDataModeID    := StrToIntDef(Trim(FDataModeEdit.Text), 0);
   FRadio.WideCWFilter      := FWideCWCheck.IsChecked;
   FRadio.FT1000MPCWReverse := FFT1000MPRevCheck.IsChecked;
   FRadio.UseHamLib       := FUseHamLibCheck.IsChecked;
   FRadio.PollingEnable   := FPollingCheck.IsChecked;

   Result := True;
end;

procedure TRadioEditForm.UpdateEnabledState;
var
   id: string;
   transport: TRadioTransport;
begin
   id := SelectedRegistryId;
   transport := StrToTransport(SelectedTag(FTransportCombo));

   // Grey rather than hide: a field that vanishes makes the operator wonder
   // whether the setting still exists.  The registry knows which links a model
   // actually supports, so a serial-only radio cannot be set to network here.
   FSerialGroup.Enabled  := (transport = rtSerial) and
                            ((id = '') or SupportsSerialId(id));
   FNetworkGroup.Enabled := (transport = rtNetwork) and
                            ((id = '') or SupportsNetworkId(id));

   // HamLib ID is the operator's value ONLY for HamLib-any; for every other
   // radio the registry supplies it and typing one here would pin a model the
   // operator never chose.  Same rule the legacy dialog applies.
   FHamLibEdit.Enabled := SameText(id, 'HAMLIBANY');
end;

procedure TRadioEditForm.HandleTypeChange(Sender: TObject);
var
   id: string;
   params: TSerialParams;
   model: InterfacedRadioType;
begin
   id := SelectedRegistryId;
   if id = '' then
      begin
      Exit;
      end;

   // Prefill from the registry, but only into fields the operator has not
   // already filled in: re-picking the same radio must not silently discard a
   // baud rate they chose deliberately.
   params := SerialParamsForId(id);
   if (Trim(FBaudEdit.Text) = '') and (params.baud > 0) then
      begin
      FBaudEdit.Text := IntToStr(params.baud);
      end;
   if Trim(FFormatEdit.Text) = '' then
      begin
      FFormatEdit.Text := SerialFormatToString(params.dataBits, params.parity, params.stopBits);
      end;
   if (Trim(FTCPPortEdit.Text) = '') and (RegisteredNetworkPortId(id) > 0) then
      begin
      FTCPPortEdit.Text := IntToStr(RegisteredNetworkPortId(id));
      end;

   model := ModelForId(id);
   if (model <> NoInterfacedRadio) and (Trim(FCIVEdit.Text) = '') and
      (RegisteredCIVAddress(model) <> 0) then
      begin
      FCIVEdit.Text := IntToStr(RegisteredCIVAddress(model));
      end;

   // If the radio only speaks one transport, move the selection there rather
   // than leaving an impossible combination on screen.
   if SupportsNetworkId(id) and (not SupportsSerialId(id)) then
      begin
      SelectByTag(FTransportCombo, TransportToStr(rtNetwork));
      end
   else if SupportsSerialId(id) and (not SupportsNetworkId(id)) then
      begin
      SelectByTag(FTransportCombo, TransportToStr(rtSerial));
      end;

   UpdateEnabledState;
end;

procedure TRadioEditForm.HandleTransportChange(Sender: TObject);
begin
   UpdateEnabledState;
end;

procedure TRadioEditForm.HandleOK(Sender: TObject);
var
   err: string;
begin
   if not SaveToRadio(err) then
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

procedure TRadioEditForm.HandleCancel(Sender: TObject);
begin
   Hide;
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

procedure TRadioEditForm.HandleShow(Sender: TObject);
begin
   RegisterFMXFormHandle(FormToHWND(Self));
end;

procedure TRadioEditForm.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterFMXFormHandle(FormToHWND(Self));
   Action := TCloseAction.caHide;
   // Closing with the window button means Cancel: the operator did not accept.
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

{ ============================================================== TPrefsForm = }

constructor TPrefsForm.Create(AOwner: TComponent);
begin
   inherited CreateNew(AOwner);
   Caption     := TC_PREFS_TITLE;
   Width       := 860;
   Height      := 600;
   Position    := TFormPosition.ScreenCenter;
   BorderStyle := TFmxFormBorderStyle.Sizeable;
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
   FNavList.Height     := ClientHeight - 45;
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
   FContent.Width      := Width - 185;
   FContent.Height     := Height - 55;

   // Shown for every section except Hardware.  The other categories exist in
   // the nav on purpose: they say what this window is GOING to be, so nobody
   // has to guess whether Preferences is meant to grow.
   FPlaceholder := MakeLabel(FContent, TC_PREFS_NOTMIGRATED, LEFTMARGIN, 20, 500);
   FPlaceholder.Height  := 60;
   FPlaceholder.Visible := False;

   BuildHardwarePanel;

   MakeButton(Self, TC_PREFS_OK,     Width - 290, Height - 45, 85, HandleOK);
   MakeButton(Self, TC_PREFS_CANCEL, Width - 195, Height - 45, 85, HandleCancel);
   MakeButton(Self, TC_PREFS_APPLY,  Width - 100, Height - 45, 85, HandleApply);

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
   grp.Height     := 250;
   grp.Text       := TC_PREFS_PROFILES;

   y := 14;
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

function TPrefsForm.StoreFileName: string;
begin
   // Beside tr4w.ini, in settings\, but a SEPARATE file -- the legacy [Radio]
   // section is rewritten wholesale by GroupRadioIniKeys, so sharing one file
   // would let either system discard the other's work.
   Result := ExtractFilePath(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0])))) +
             'tr4wradios.ini';
end;

procedure TPrefsForm.LoadStore;
var
   ini: TIniFile;
   legacy: TIniFile;
begin
   ini := TIniFile.Create(StoreFileName);
   try
      FStore.LoadFrom(ini);
   finally
      ini.Free;
   end;

   if FStore.RadioCount > 0 then
      begin
      Exit;
      end;

   // First open: build the library from the configuration the operator already
   // has, rather than presenting an empty list to someone with two working
   // radios.  The legacy file is opened READ-ONLY -- seeding must not be able
   // to damage a configuration still in use.
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
var
   ini: TIniFile;
begin
   Result := FStore.Validate(aError);
   if not Result then
      begin
      Exit;
      end;

   ini := TIniFile.Create(StoreFileName);
   try
      FStore.SaveTo(ini);
   finally
      ini.Free;
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

procedure TPrefsForm.HandleCancel(Sender: TObject);
begin
   // Throw the working copy away and reload from disk, so that reopening shows
   // what is actually stored rather than the edits just abandoned.
   FStore.Clear;
   LoadStore;
   RefreshAll;
   Hide;
end;

procedure TPrefsForm.HandleShow(Sender: TObject);
begin
   RegisterFMXFormHandle(FormToHWND(Self));
end;

procedure TPrefsForm.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterFMXFormHandle(FormToHWND(Self));
   // Hide, never free: freeing a form from inside its own event handler is the
   // classic way to crash on the way out, and reopening should be instant.
   Action := TCloseAction.caHide;
end;

initialization

finalization
   FreeAndNil(gPrefsForm);

end.
