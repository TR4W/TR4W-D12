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
   TC_RADIOEDIT_ADVANCED     = 'Advanced';
   TC_RADIOEDIT_PORT         = 'Port';
   TC_RADIOEDIT_BAUD         = 'Baud rate';
   TC_RADIOEDIT_DATABITS     = 'Data bits';
   TC_RADIOEDIT_PARITY       = 'Parity';
   TC_RADIOEDIT_STOPBITS     = 'Stop bits';
   TC_RADIOEDIT_PARITYNONE   = 'None';
   TC_RADIOEDIT_PARITYODD    = 'Odd';
   TC_RADIOEDIT_PARITYEVEN   = 'Even';
   TC_RADIOEDIT_IPADDRESS    = 'IP address';
   TC_RADIOEDIT_TCPPORT      = 'TCP port';
   TC_RADIOEDIT_USERNAME     = 'User name';
   TC_RADIOEDIT_PASSWORD     = 'Password';
   TC_RADIOEDIT_KEYERPORT    = 'Keyer output port';
   TC_RADIOEDIT_CIVADDRESS   = 'CI-V address (hex)';
   TC_RADIOEDIT_BADCIV       = 'The CI-V address must be a hex value, e.g. 88 or $88.';
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
      // The TABS are the transport selector -- there is no separate combo.
      // Transport is exclusive, so a combo plus a visible group would be two
      // controls expressing one fact and free to disagree.  Choosing the tab IS
      // choosing the connection, and its parameters are what the tab reveals.
      FTransportTabs: TTabControl;
      FSerialTab: TTabItem;
      FNetworkTab: TTabItem;
      FAdvancedTab: TTabItem;
      // Advanced is a tab but NOT a transport, so the transport is REMEMBERED
      // rather than read from whichever tab happens to be showing.  Without
      // this, looking at Advanced would silently change the radio's connection.
      FTransport: TRadioTransport;
      FPortCombo: TComboBox;
      FBaudEdit: TEdit;
      // The serial frame as three pickers rather than a typed '8N1'.  It is
      // not only tidier: a free-text frame can be wrong in ways that are
      // invisible until the radio does not answer, and '8N1' vs '8-N-1' vs
      // 'N81' all look reasonable to someone typing quickly.  Three groups can
      // only ever produce a combination the parser accepts.
      FData7, FData8: TRadioButton;
      FParityN, FParityO, FParityE: TRadioButton;
      FStop1, FStop2: TRadioButton;
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

      procedure BuildControls;
      procedure PopulateTypeCombo;
      procedure PopulatePortCombos;
      procedure SetSerialFrame(const aFormat: string);
      function SerialFrame: string;
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
   // A TGroupBox draws its caption INSIDE the top of the frame, so content
   // placed at y=8 is drawn underneath the caption text.  Every row inside a
   // group starts below this instead.
   GROUPTOP   = 26;
   // A TTabItem's children sit inside the tab's own content area, so they need
   // only a small margin -- the tab strip is not part of it.
   TABTOP     = 12;
   // What the tab strip itself takes out of the control's height.
   TABSTRIP   = 36;

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

function MakeRadio(const aParent: TFmxObject; const aText, aGroup: string;
                   const aX, aY, aWidth: single): TRadioButton;
begin
   Result := TRadioButton.Create(aParent);
   Result.Parent     := aParent;
   Result.Position.X := aX;
   Result.Position.Y := aY;
   Result.Width      := aWidth;
   Result.Text       := aText;
   // Explicit group, never the parent-derived default -- see the call site.
   Result.GroupName  := aGroup;
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

// Is this registry id an Icom?  ManufacturerOf reads the first word of the
// registry DISPLAY NAME ('Icom IC-7300' -> 'Icom'), which is the only
// manufacturer the registry actually records.  For a string-id radio there is
// no enum to ask, so the display name is read directly -- the same rule, one
// step earlier.
//
// A capability flag would be better than a brand test, and if a non-Icom radio
// ever grows a filter byte this should become one.  It is a brand test today
// because the two settings it gates ARE brand-specific: 'ICOM FILTER BYTE' and
// 'ICOM DATA MODE ID' are the config keys' own names.
function IsIcomRadio(const aRegistryId: string): boolean;
var
   model: InterfacedRadioType;
begin
   if Trim(aRegistryId) = '' then
      begin
      Result := False;
      Exit;
      end;

   model := ModelForId(aRegistryId);
   if model <> NoInterfacedRadio then
      begin
      Result := SameText(ManufacturerOf(model), 'Icom');
      end
   else
      begin
      Result := SameText(Copy(Trim(DisplayNameId(aRegistryId)), 1, 4), 'Icom');
      end;
end;

// Parses a CI-V address written the way manuals and radio menus write it: hex,
// with or without a '$' or '0x'.  An empty box is a legitimate "not set" and
// yields 0, so it must not be an error.
function TryParseHexByte(const aText: string; out aValue: integer): boolean;
var
   t: string;
begin
   aValue := 0;
   t := Trim(aText);
   if t = '' then
      begin
      Result := True;
      Exit;
      end;

   if (Length(t) > 1) and (LowerCase(Copy(t, 1, 2)) = '0x') then
      begin
      t := Copy(t, 3, MaxInt);
      end
   else if t[1] = '$' then
      begin
      t := Copy(t, 2, MaxInt);
      end;

   Result := TryStrToInt('$' + t, aValue) and (aValue >= 0) and (aValue <= 255);
end;

{ =========================================================== TRadioEditForm = }

constructor TRadioEditForm.Create(AOwner: TComponent);
begin
   inherited CreateNew(AOwner);
   Caption     := TC_RADIOEDIT_TITLE;
   // ClientWidth/ClientHeight, NOT Width/Height.  In FMX, Height includes the
   // caption bar and borders, so laying controls out against Height puts the
   // last row BELOW the visible client area -- which is exactly how the OK and
   // Cancel buttons went missing on NY4I's first look at this window.
   ClientWidth  := 520;
   ClientHeight := 470;
   Position    := TFormPosition.ScreenCenter;
   BorderStyle := TFmxFormBorderStyle.Sizeable;
   OnShow      := HandleShow;
   OnClose     := HandleClose;
   BuildControls;
end;

procedure TRadioEditForm.BuildControls;
var
   y: single;
   tab: TFmxObject;

   function NextRow: single;
   begin
      Result := y;
      y := y + ROWHEIGHT;
   end;

begin
   y := 12;

   // --- identity, always visible -------------------------------------------
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

   // --- Serial / Network / Advanced ----------------------------------------
   FTransportTabs := TTabControl.Create(Self);
   FTransportTabs.Parent     := Self;
   FTransportTabs.Position.X := LEFTMARGIN;
   FTransportTabs.Position.Y := NextRow;
   FTransportTabs.Width      := 480;
   FTransportTabs.Height     := TABSTRIP + 5 * ROWHEIGHT + 16;
   FTransportTabs.OnChange   := HandleTransportChange;
   y := y + FTransportTabs.Height - ROWHEIGHT + 10;

   FSerialTab := TTabItem.Create(FTransportTabs);
   FSerialTab.Parent    := FTransportTabs;
   FSerialTab.Text      := TC_RADIOEDIT_SERIAL;
   FSerialTab.TagString := TransportToStr(rtSerial);

   FNetworkTab := TTabItem.Create(FTransportTabs);
   FNetworkTab.Parent    := FTransportTabs;
   FNetworkTab.Text      := TC_RADIOEDIT_NETWORK;
   FNetworkTab.TagString := TransportToStr(rtNetwork);

   FAdvancedTab := TTabItem.Create(FTransportTabs);
   FAdvancedTab.Parent    := FTransportTabs;
   FAdvancedTab.Text      := TC_RADIOEDIT_ADVANCED;
   FAdvancedTab.TagString := '';   // not a transport -- see FTransport

   // --- serial --------------------------------------------------------------
   tab := FSerialTab;
   MakeLabel(tab, TC_RADIOEDIT_PORT, 10, TABTOP + 4, 120);
   FPortCombo := TComboBox.Create(tab);
   FPortCombo.Parent     := tab;
   FPortCombo.Position.X := 140;
   FPortCombo.Position.Y := TABTOP;
   FPortCombo.Width      := 320;

   MakeLabel(tab, TC_RADIOEDIT_BAUD, 10, TABTOP + 4 + ROWHEIGHT, 120);
   FBaudEdit := TEdit.Create(tab);
   FBaudEdit.Parent     := tab;
   FBaudEdit.Position.X := 140;
   FBaudEdit.Position.Y := TABTOP + ROWHEIGHT;
   FBaudEdit.Width      := 120;

   // GroupName is what makes each row mutually exclusive.  Without it FMX
   // groups radio buttons by PARENT, so all seven would fight over one
   // selection and only the last clicked would ever be set.
   MakeLabel(tab, TC_RADIOEDIT_DATABITS, 10, TABTOP + 4 + 2 * ROWHEIGHT, 120);
   FData7 := MakeRadio(tab, '7', 'databits', 140, TABTOP + 2 * ROWHEIGHT, 60);
   FData8 := MakeRadio(tab, '8', 'databits', 205, TABTOP + 2 * ROWHEIGHT, 60);

   MakeLabel(tab, TC_RADIOEDIT_PARITY, 10, TABTOP + 4 + 3 * ROWHEIGHT, 120);
   FParityN := MakeRadio(tab, TC_RADIOEDIT_PARITYNONE, 'parity', 140, TABTOP + 3 * ROWHEIGHT, 75);
   FParityO := MakeRadio(tab, TC_RADIOEDIT_PARITYODD,  'parity', 220, TABTOP + 3 * ROWHEIGHT, 65);
   FParityE := MakeRadio(tab, TC_RADIOEDIT_PARITYEVEN, 'parity', 290, TABTOP + 3 * ROWHEIGHT, 70);

   MakeLabel(tab, TC_RADIOEDIT_STOPBITS, 10, TABTOP + 4 + 4 * ROWHEIGHT, 120);
   FStop1 := MakeRadio(tab, '1', 'stopbits', 140, TABTOP + 4 * ROWHEIGHT, 60);
   FStop2 := MakeRadio(tab, '2', 'stopbits', 205, TABTOP + 4 * ROWHEIGHT, 60);

   // --- network -------------------------------------------------------------
   tab := FNetworkTab;
   MakeLabel(tab, TC_RADIOEDIT_IPADDRESS, 10, TABTOP + 4, 120);
   FIPEdit := TEdit.Create(tab);
   FIPEdit.Parent     := tab;
   FIPEdit.Position.X := 140;
   FIPEdit.Position.Y := TABTOP;
   FIPEdit.Width      := 200;

   MakeLabel(tab, TC_RADIOEDIT_TCPPORT, 10, TABTOP + 4 + ROWHEIGHT, 120);
   FTCPPortEdit := TEdit.Create(tab);
   FTCPPortEdit.Parent     := tab;
   FTCPPortEdit.Position.X := 140;
   FTCPPortEdit.Position.Y := TABTOP + ROWHEIGHT;
   FTCPPortEdit.Width      := 120;

   MakeLabel(tab, TC_RADIOEDIT_USERNAME, 10, TABTOP + 4 + 2 * ROWHEIGHT, 120);
   FUserEdit := TEdit.Create(tab);
   FUserEdit.Parent     := tab;
   FUserEdit.Position.X := 140;
   FUserEdit.Position.Y := TABTOP + 2 * ROWHEIGHT;
   FUserEdit.Width      := 200;

   MakeLabel(tab, TC_RADIOEDIT_PASSWORD, 10, TABTOP + 4 + 3 * ROWHEIGHT, 120);
   FPasswordEdit := TEdit.Create(tab);
   FPasswordEdit.Parent     := tab;
   FPasswordEdit.Position.X := 140;
   FPasswordEdit.Position.Y := TABTOP + 3 * ROWHEIGHT;
   FPasswordEdit.Width      := 200;
   FPasswordEdit.Password   := True;

   // --- advanced ------------------------------------------------------------
   // Everything here is a diagnostic or a per-model quirk, NOT a setup choice.
   // "Poll this radio" is the clearest case (NY4I): an operator has no way to
   // know whether their radio should be polled -- that is something TR4W knows
   // -- so it is on by default and lives here for the rare case of switching it
   // off to chase a problem.  Same for the startup command and the Icom bytes.
   tab := FAdvancedTab;
   MakeLabel(tab, TC_RADIOEDIT_STARTUP, 10, TABTOP + 4, 130);
   FStartupEdit := TEdit.Create(tab);
   FStartupEdit.Parent     := tab;
   FStartupEdit.Position.X := 150;
   FStartupEdit.Position.Y := TABTOP;
   FStartupEdit.Width      := 310;

   MakeLabel(tab, TC_RADIOEDIT_FILTERBYTE, 10, TABTOP + 4 + ROWHEIGHT, 130);
   FFilterByteEdit := TEdit.Create(tab);
   FFilterByteEdit.Parent     := tab;
   FFilterByteEdit.Position.X := 150;
   FFilterByteEdit.Position.Y := TABTOP + ROWHEIGHT;
   FFilterByteEdit.Width      := 70;

   MakeLabel(tab, TC_RADIOEDIT_DATAMODEID, 240, TABTOP + 4 + ROWHEIGHT, 140);
   FDataModeEdit := TEdit.Create(tab);
   FDataModeEdit.Parent     := tab;
   FDataModeEdit.Position.X := 390;
   FDataModeEdit.Position.Y := TABTOP + ROWHEIGHT;
   FDataModeEdit.Width      := 70;

   MakeLabel(tab, TC_RADIOEDIT_HAMLIBID, 10, TABTOP + 4 + 2 * ROWHEIGHT, 130);
   FHamLibEdit := TEdit.Create(tab);
   FHamLibEdit.Parent     := tab;
   FHamLibEdit.Position.X := 150;
   FHamLibEdit.Position.Y := TABTOP + 2 * ROWHEIGHT;
   FHamLibEdit.Width      := 70;

   FUseHamLibCheck := TCheckBox.Create(tab);
   FUseHamLibCheck.Parent     := tab;
   FUseHamLibCheck.Position.X := 240;
   FUseHamLibCheck.Position.Y := TABTOP + 2 * ROWHEIGHT + 4;
   FUseHamLibCheck.Width      := 220;
   FUseHamLibCheck.Text       := TC_RADIOEDIT_USEHAMLIB;

   FWideCWCheck := TCheckBox.Create(tab);
   FWideCWCheck.Parent     := tab;
   FWideCWCheck.Position.X := 10;
   FWideCWCheck.Position.Y := TABTOP + 3 * ROWHEIGHT + 4;
   FWideCWCheck.Width      := 200;
   FWideCWCheck.Text       := TC_RADIOEDIT_WIDECW;

   FFT1000MPRevCheck := TCheckBox.Create(tab);
   FFT1000MPRevCheck.Parent     := tab;
   FFT1000MPRevCheck.Position.X := 240;
   FFT1000MPRevCheck.Position.Y := TABTOP + 3 * ROWHEIGHT + 4;
   FFT1000MPRevCheck.Width      := 230;
   FFT1000MPRevCheck.Text       := TC_RADIOEDIT_FT1000MPREV;

   FPollingCheck := TCheckBox.Create(tab);
   FPollingCheck.Parent     := tab;
   FPollingCheck.Position.X := 10;
   FPollingCheck.Position.Y := TABTOP + 4 * ROWHEIGHT + 4;
   FPollingCheck.Width      := 220;
   FPollingCheck.Text       := TC_RADIOEDIT_POLLING;

   // --- common, below the tabs ---------------------------------------------
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

   // Anchored to the bottom of the CLIENT area, so a row added above can never
   // push them off the form the way it did once already.
   MakeButton(Self, TC_PREFS_OK,     ClientWidth - 200, ClientHeight - 38, 90, HandleOK);
   MakeButton(Self, TC_PREFS_CANCEL, ClientWidth - 100, ClientHeight - 38, 90, HandleCancel);

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

// Drives the three pickers from an '8N1'-style string.  An unparseable or
// empty value falls back to 8N1 -- the near-universal default -- rather than
// leaving nothing selected, because "no data bits chosen" is not a state the
// radio can be in.
procedure TRadioEditForm.SetSerialFrame(const aFormat: string);
var
   dataBits, parity, stopBits: Byte;
begin
   if not TryParseSerialFormat(Trim(aFormat), dataBits, parity, stopBits) then
      begin
      dataBits := 8;
      parity   := PARITY_NONE;
      stopBits := 1;
      end;

   FData7.IsChecked := (dataBits = 7);
   FData8.IsChecked := (dataBits = 8);

   FParityN.IsChecked := (parity = PARITY_NONE);
   FParityO.IsChecked := (parity = PARITY_ODD);
   FParityE.IsChecked := (parity = PARITY_EVEN);

   FStop1.IsChecked := (stopBits = 1);
   FStop2.IsChecked := (stopBits = 2);
end;

// The three pickers back into the '8N1' the config command expects.  Composed
// through SerialFormatToString rather than by string concatenation here, so the
// spelling can only ever be the one the parser accepts.
function TRadioEditForm.SerialFrame: string;
var
   dataBits, parity, stopBits: Byte;
begin
   if FData7.IsChecked then
      begin
      dataBits := 7;
      end
   else
      begin
      dataBits := 8;
      end;

   if FParityO.IsChecked then
      begin
      parity := PARITY_ODD;
      end
   else if FParityE.IsChecked then
      begin
      parity := PARITY_EVEN;
      end
   else
      begin
      parity := PARITY_NONE;
      end;

   if FStop2.IsChecked then
      begin
      stopBits := 2;
      end
   else
      begin
      stopBits := 1;
      end;

   Result := SerialFormatToString(dataBits, parity, stopBits);
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

   // A NEW radio starts with NOTHING selected, rather than falling back to the
   // first row of an alphabetical list.  A defaulted type is a silent wrong
   // answer: the operator fills in the port, saves, and has an Elecraft K2 they
   // never chose.  It also means the "Choose a radio type" check below can
   // actually fire -- with a fallback selection it never could.
   //
   // There is deliberately no '(none)' row in this list.  In TR4W's vocabulary
   // NONE means "no radio in this slot", which is a different idea and already
   // offered at profile level; a radio DEFINITION with no type is not something
   // worth being able to save, so it is un-selectable rather than
   // selectable-and-invalid.
   if Trim(FRadio.RegistryId) = '' then
      begin
      FTypeCombo.ItemIndex := -1;
      end
   else
      begin
      SelectByTag(FTypeCombo, FRadio.RegistryId);
      end;
   FTransport := FRadio.Transport;
   if FTransport = rtNetwork then
      begin
      FTransportTabs.ActiveTab := FNetworkTab;
      end
   else
      begin
      FTransportTabs.ActiveTab := FSerialTab;
      end;

   SelectByTag(FPortCombo, FRadio.ControlPort);
   if FRadio.BaudRate > 0 then
      begin
      FBaudEdit.Text := IntToStr(FRadio.BaudRate);
      end
   else
      begin
      FBaudEdit.Text := '';
      end;
   SetSerialFrame(FRadio.SerialFormat);

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
   // HEX, because that is what the radio's own menu and every Icom manual show
   // (NY4I).  The value is STORED as the decimal the config command expects --
   // only the presentation changes, so nothing downstream has to know.
   if FRadio.ReceiverAddress > 0 then
      begin
      FCIVEdit.Text := IntToHex(FRadio.ReceiverAddress, 2);
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
var
   civ: integer;
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
   FRadio.Transport  := FTransport;

   FRadio.ControlPort  := SelectedTag(FPortCombo);
   FRadio.BaudRate     := StrToIntDef(Trim(FBaudEdit.Text), 0);
   FRadio.SerialFormat := SerialFrame;

   FRadio.IPAddress       := Trim(FIPEdit.Text);
   FRadio.TCPPort         := StrToIntDef(Trim(FTCPPortEdit.Text), 0);
   FRadio.NetworkUsername := Trim(FUserEdit.Text);
   FRadio.NetworkPassword := FPasswordEdit.Text;   // not trimmed: it is a password

   FRadio.KeyerOutputPort := SelectedTag(FKeyerPortCombo);
   if not TryParseHexByte(FCIVEdit.Text, civ) then
      begin
      aError := TC_RADIOEDIT_BADCIV;
      Exit;
      end;
   FRadio.ReceiverAddress := civ;
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
   isIcom: boolean;
begin
   id := SelectedRegistryId;
   transport := FTransport;

   // Grey rather than hide: a field that vanishes makes the operator wonder
   // whether the setting still exists.  The registry knows which links a model
   // actually supports, so a serial-only radio cannot be set to network here.
   // A radio that cannot speak a transport does not get that tab.  The registry
   // is the authority on which links a model supports.
   FSerialTab.Enabled  := (id = '') or SupportsSerialId(id);
   FNetworkTab.Enabled := (id = '') or SupportsNetworkId(id);

   // HamLib ID is the operator's value ONLY for HamLib-any; for every other
   // radio the registry supplies it and typing one here would pin a model the
   // operator never chose.  Same rule the legacy dialog applies.
   FHamLibEdit.Enabled := SameText(id, 'HAMLIBANY');

   // Model-specific settings are enabled only for the models they mean anything
   // to (NY4I).  An Icom filter byte on a Kenwood is not a harmless spare
   // field: it is an invitation to set something that will never be sent, and
   // then to wonder why it had no effect.
   isIcom := IsIcomRadio(id);
   FFilterByteEdit.Enabled := isIcom;
   FDataModeEdit.Enabled   := isIcom;

   // CI-V is offered only where the REGISTRY says the model has a CI-V address
   // -- its own declared meaning ('0 = not a CI-V radio'), not a brand guess.
   // That is not pedantry: the Ten-Tec Omni VI has an Icom-compatible CI-V
   // interface and declares address 4, so a brand test would have locked it out
   // of the one field it needs.
   FCIVEdit.Enabled := (id <> '') and (RegisteredCIVAddress(ModelForId(id)) <> 0);
   if not FCIVEdit.Enabled then
      begin
      FCIVEdit.Text := '';
      end;

   // The FT-1000MP's reversed CW sidebands are a quirk of that one radio.
   FFT1000MPRevCheck.Enabled := (ModelForId(id) = FT1000MP);

   // Blank a disabled field rather than leave a stale value showing: a greyed
   // box with a number in it reads as "set, but locked", which is the opposite
   // of what it means.
   if not FFilterByteEdit.Enabled then
      begin
      FFilterByteEdit.Text := '';
      end;
   if not FDataModeEdit.Enabled then
      begin
      FDataModeEdit.Text := '';
      end;
   if not FFT1000MPRevCheck.Enabled then
      begin
      FFT1000MPRevCheck.IsChecked := False;
      end;
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
   // The frame always has a value now (the pickers cannot be blank), so this
   // adopts the registry's frame whenever the operator has not yet saved one --
   // which is what picking a radio type should do.
   if Trim(FRadio.SerialFormat) = '' then
      begin
      SetSerialFrame(SerialFormatToString(params.dataBits, params.parity, params.stopBits));
      end;
   if (Trim(FTCPPortEdit.Text) = '') and (RegisteredNetworkPortId(id) > 0) then
      begin
      FTCPPortEdit.Text := IntToStr(RegisteredNetworkPortId(id));
      end;

   model := ModelForId(id);
   if (model <> NoInterfacedRadio) and (Trim(FCIVEdit.Text) = '') and
      (RegisteredCIVAddress(model) <> 0) then
      begin
      FCIVEdit.Text := IntToHex(RegisteredCIVAddress(model), 2);
      end;

   // If the radio only speaks one transport, move the selection there rather
   // than leaving an impossible combination on screen.
   if SupportsNetworkId(id) and (not SupportsSerialId(id)) then
      begin
      FTransport := rtNetwork;
      FTransportTabs.ActiveTab := FNetworkTab;
      end
   else if SupportsSerialId(id) and (not SupportsNetworkId(id)) then
      begin
      FTransport := rtSerial;
      FTransportTabs.ActiveTab := FSerialTab;
      end;

   UpdateEnabledState;
end;

procedure TRadioEditForm.HandleTransportChange(Sender: TObject);
begin
   // ONLY the two transport tabs change the transport.  Advanced is a tab but
   // not a connection, so opening it must not silently turn a network radio
   // into a serial one -- which is exactly what reading the transport straight
   // off the active tab would do.
   if FTransportTabs.ActiveTab = FSerialTab then
      begin
      FTransport := rtSerial;
      end
   else if FTransportTabs.ActiveTab = FNetworkTab then
      begin
      FTransport := rtNetwork;
      end;

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
   ClientWidth  := 860;
   ClientHeight := 620;
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

   MakeButton(Self, TC_PREFS_OK,     ClientWidth - 290, ClientHeight - 38, 85, HandleOK);
   MakeButton(Self, TC_PREFS_CANCEL, ClientWidth - 195, ClientHeight - 38, 85, HandleCancel);
   MakeButton(Self, TC_PREFS_APPLY,  ClientWidth - 100, ClientHeight - 38, 85, HandleApply);

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
