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
unit uRadioEditForm;

{
  The Radio editor: one radio DEFINITION, edited in isolation.

  SPLIT OUT OF uPrefsForm 2026-08-06, ahead of converting it to a designed .fmx.
  A designed form owns a resource named for its unit, so one form per unit is not
  a style preference here -- it is what the IDE and the form-resource directive
  require.  The unit
  it came from held two forms and 2,336 lines.

  Layout is still built in code.  Converting THAT is the next step; this move is
  deliberately behaviour-preserving so that if the designed version misbehaves,
  the difference between the two commits is the layout and nothing else.

  WHAT WILL NOT MOVE INTO THE DESIGNER.  Population stays here: the port and
  radio-type combos depend on what is plugged into the machine and what the
  registry holds, neither of which can be expressed in a .fmx.  Captions stay in
  code too, assigned from the constants in uFMXFormHelpers, so the move to
  Delphi resourcestring is not fought by literals baked into the form resource.
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

type
   // Reports the editor's outcome.  A callback rather than a modal result,
   // because the editor is modeless -- see the unit header.
   TRadioEditDone = procedure(const aAccepted: boolean) of object;

   TRadioEditForm = class(TForm)
   private
      FRadio: TRadioDefinition;
      // What the radio looked like when the editor opened.  Comparing against
      // this answers "did anything change" exactly, with no dirty flag to keep
      // in step with the control count.
      FSnapshot: TRadioDefinition;
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
      // False until BuildControls has created EVERY control.  Assigning a
      // TTabItem's Parent makes it the active tab, which fires OnChange -- so
      // the handler runs while the tabs and edits created after it are still
      // nil.  Guarding each field individually would mean remembering to add a
      // test every time a control joins the form; one flag cannot be forgotten.
      FBuilt: boolean;
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
      FDiscoverButton: TButton;
      FFoundCombo: TComboBox;
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

      // The labels of the model-only fields, kept so they can be greyed WITH
      // their field (NY4I 2026-08-05).  Disabling the edit alone is invisible:
      // the gating code blanks a disabled field's Text and TextPrompt, so what
      // is left is an empty box that looks exactly like an enabled one, under a
      // caption still drawn in full black.  Greying the caption is what makes
      // "this radio does not have that setting" legible -- and it is the
      // convention every other Windows dialog uses.
      FCIVLabel: TLabel;
      FFilterByteLabel: TLabel;
      FDataModeLabel: TLabel;
      FHamLibLabel: TLabel;


      procedure BuildControls;
      procedure PopulateTypeCombo;
      procedure PopulatePortCombos;
      procedure SetSerialFrame(const aFormat: string);
      function SerialFrame: string;
      procedure LoadFromRadio;
      function SaveToRadio(out aError: string): boolean;
      function SaveTo(const aTarget: TRadioDefinition; out aError: string): boolean;
      function IsModified: boolean;
      function SelectedRegistryId: string;
      procedure UpdateEnabledState;
      procedure HandleTypeChange(Sender: TObject);
      procedure HandleTransportChange(Sender: TObject);
      procedure HandleDiscover(Sender: TObject);
      procedure HandleFoundSelect(Sender: TObject);
      procedure HandleOK(Sender: TObject);
      procedure HandleCancel(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure EditRadio(const aRadio: TRadioDefinition; const aOnDone: TRadioEditDone);
   end;

implementation

uses
   Winapi.Windows,
   System.StrUtils,
   System.Generics.Collections,
   System.Generics.Defaults,
   FMX.Platform.Win,
   FMX.Dialogs,
   uFMXFormHelpers,
   uFMXCoexist,
   uRadioConfigApply,
   uRadioRegistry,
   uCAT,
   ComPortEnumerator,
   VC,
   MainUnit;

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

   FDiscoverButton := MakeButton(tab, TC_RADIOEDIT_DISCOVER,
                                 350, TABTOP, 110, HandleDiscover);

   MakeLabel(tab, TC_RADIOEDIT_FOUND, 10, TABTOP + 4 + 4 * ROWHEIGHT, 120);
   FFoundCombo := TComboBox.Create(tab);
   FFoundCombo.Parent     := tab;
   FFoundCombo.Position.X := 140;
   FFoundCombo.Position.Y := TABTOP + 4 * ROWHEIGHT;
   FFoundCombo.Width      := 320;
   FFoundCombo.OnChange   := HandleFoundSelect;

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

   FFilterByteLabel := MakeLabel(tab, TC_RADIOEDIT_FILTERBYTE, 10, TABTOP + 4 + ROWHEIGHT, 130);
   FFilterByteEdit := TEdit.Create(tab);
   FFilterByteEdit.Parent     := tab;
   FFilterByteEdit.Position.X := 150;
   FFilterByteEdit.Position.Y := TABTOP + ROWHEIGHT;
   FFilterByteEdit.Width      := 70;

   FDataModeLabel := MakeLabel(tab, TC_RADIOEDIT_DATAMODEID, 240, TABTOP + 4 + ROWHEIGHT, 140);
   FDataModeEdit := TEdit.Create(tab);
   FDataModeEdit.Parent     := tab;
   FDataModeEdit.Position.X := 390;
   FDataModeEdit.Position.Y := TABTOP + ROWHEIGHT;
   FDataModeEdit.Width      := 70;

   FHamLibLabel := MakeLabel(tab, TC_RADIOEDIT_HAMLIBID, 10, TABTOP + 4 + 2 * ROWHEIGHT, 130);
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

   FCIVLabel := MakeLabel(Self, TC_RADIOEDIT_CIVADDRESS, LEFTMARGIN, y + 4, 130);
   FCIVEdit := TEdit.Create(Self);
   FCIVEdit.Parent     := Self;
   FCIVEdit.Position.X := 150;
   FCIVEdit.Position.Y := NextRow;
   FCIVEdit.Width      := 80;

   // Placed against the bottom-right of the client area AND anchored there, so
   // they neither get pushed off by a row added above nor stranded in mid-air
   // when the operator resizes the dialog.
   MakeButton(Self, TC_PREFS_OK,     ClientWidth - 200, ClientHeight - 38, 90, HandleOK,     [TAnchorKind.akRight, TAnchorKind.akBottom]);
   MakeButton(Self, TC_PREFS_CANCEL, ClientWidth - 100, ClientHeight - 38, 90, HandleCancel, [TAnchorKind.akRight, TAnchorKind.akBottom]);

   // Last: every control now exists, so the handlers may run.  PopulateTypeCombo
   // below sets ItemIndex and fires OnChange, which is safe from here on.
   FBuilt := True;

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

   FreeAndNil(FSnapshot);
   if aRadio <> nil then
      begin
      FSnapshot := aRadio.Clone;
      end;
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

destructor TRadioEditForm.Destroy;
begin
   FreeAndNil(FSnapshot);
   inherited Destroy;
end;

// True when the controls hold something different from what was loaded.  It
// works by writing the controls into a scratch copy and comparing -- so it can
// never disagree with what OK would actually save, which a hand-maintained
// dirty flag eventually does.
function TRadioEditForm.IsModified: boolean;
var
   scratch: TRadioDefinition;
   err: string;
begin
   Result := False;
   if (FRadio = nil) or (FSnapshot = nil) then
      begin
      Exit;
      end;

   scratch := FRadio.Clone;
   try
      // A scratch copy that will not even validate is certainly not identical
      // to the snapshot, so treat that as modified and let the prompt appear.
      if not SaveTo(scratch, err) then
         begin
         Result := True;
         Exit;
         end;
      Result := not scratch.SameAs(FSnapshot);
   finally
      scratch.Free;
   end;
end;

function TRadioEditForm.SaveToRadio(out aError: string): boolean;
begin
   Result := SaveTo(FRadio, aError);
end;

function TRadioEditForm.SaveTo(const aTarget: TRadioDefinition; out aError: string): boolean;
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
   civDefault: integer;
begin
   // Reached during construction, from the first tab becoming active -- see
   // FBuilt.  Every control this method touches is created AFTER the tab
   // control, so without this it dereferences nil.
   if not FBuilt then
      begin
      Exit;
      end;

   id := SelectedRegistryId;
   transport := FTransport;

   // Grey rather than hide: a field that vanishes makes the operator wonder
   // whether the setting still exists.  The registry knows which links a model
   // actually supports, so a serial-only radio cannot be set to network here.
   // A radio that cannot speak a transport does not get that tab.  The registry
   // is the authority on which links a model supports.
   FSerialTab.Enabled  := (id = '') or SupportsSerialId(id);
   FNetworkTab.Enabled := (id = '') or SupportsNetworkId(id);

   // Discovery is offered only where the registry says the model announces
   // itself.  Broadcasting for a radio that cannot answer would produce a
   // three-second wait and an empty list, which reads as a fault.
   FDiscoverButton.Enabled := (id <> '') and RegisteredDiscoverableId(id);

   // HamLib ID is the operator's value ONLY for HamLib-any; for every other
   // radio the registry supplies it and typing one here would pin a model the
   // operator never chose.  Same rule the legacy dialog applies.
   FHamLibEdit.Enabled := SameText(id, 'HAMLIBANY');
   FHamLibLabel.Enabled := FHamLibEdit.Enabled;

   // Model-specific settings are enabled only for the models they mean anything
   // to (NY4I).  An Icom filter byte on a Kenwood is not a harmless spare
   // field: it is an invitation to set something that will never be sent, and
   // then to wonder why it had no effect.
   isIcom := IsIcomRadio(id);
   FFilterByteEdit.Enabled  := isIcom;
   FDataModeEdit.Enabled    := isIcom;
   FFilterByteLabel.Enabled := isIcom;
   FDataModeLabel.Enabled   := isIcom;

   // CI-V is offered only where the REGISTRY says the model has a CI-V address
   // -- its own declared meaning ('0 = not a CI-V radio'), not a brand guess.
   // That is not pedantry: the Ten-Tec Omni VI has an Icom-compatible CI-V
   // interface and declares address 4, so a brand test would have locked it out
   // of the one field it needs.
   civDefault := 0;
   if id <> '' then
      begin
      civDefault := RegisteredCIVAddress(ModelForId(id));
      end;

   FCIVEdit.Enabled := (civDefault <> 0);
   // Grey the caption with the box.  The gating below blanks a disabled field's
   // Text and TextPrompt, which leaves nothing to render greyed -- so on a K3
   // (registered civAddress 0, correctly disabled) the operator saw an ordinary
   // empty box under a full-black caption and read it as editable.  NY4I, bench,
   // 2026-08-05.
   FCIVLabel.Enabled := FCIVEdit.Enabled;
   if not FCIVEdit.Enabled then
      begin
      FCIVEdit.Text       := '';
      FCIVEdit.TextPrompt := '';
      end
   else
      begin
      // Greyed, and only visible while the box is empty -- so it disappears the
      // moment the operator types their own address, and comes back if they
      // clear it.  Hex, to match the label, the radio's menu and the manual.
      FCIVEdit.TextPrompt := Format(TC_RADIOEDIT_DEFAULTHINT,
                                    [IntToHex(civDefault, 2)]);
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
   // NOTHING here may touch FRadio without this guard.  OnChange is wired in
   // BuildControls, and PopulateTypeCombo -- called at the END of that same
   // constructor -- sets ItemIndex, which fires this handler while FRadio is
   // still nil.  The earlier version of this method only touched controls and
   // so survived; adding one FRadio.SerialFormat read turned first-open of the
   // editor into an access violation.
   //
   // The general shape: an event handler wired before its subject exists will
   // be called before its subject exists.
   if FRadio = nil then
      begin
      Exit;
      end;

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

   // The CI-V address is deliberately NOT prefilled.  Writing the model default
   // into the box makes it look like an operator choice, and it then stops
   // tracking the registry if that default is ever corrected.  Blank means "use
   // the model default", and UpdateEnabledState shows what that default is as
   // greyed prompt text inside the empty field -- which is what makes blank
   // read as a decision rather than an omission (NY4I).

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
   // Building the tabs must not decide the radio's transport: the first tab
   // becomes active as a side effect of being parented, long before any radio
   // is loaded.
   if not FBuilt then
      begin
      Exit;
      end;

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

procedure TRadioEditForm.HandleDiscover(Sender: TObject);
var
   model: InterfacedRadioType;
begin
   model := ModelForId(SelectedRegistryId);
   if model = NoInterfacedRadio then
      begin
      Exit;
      end;

   // The button stays disabled for the whole search: a second broadcast while
   // the first is still listening would have two sockets on the same port.
   FDiscoverButton.Enabled := False;
   FDiscoverButton.Text    := TC_RADIOEDIT_SEARCHING;
   FFoundCombo.Clear;

   // OFF THE MAIN THREAD.  DiscoverNetworkRadios broadcasts and then waits out
   // its timeout -- about three seconds -- and doing that on the main thread
   // would freeze not just this window but TR4W's whole message loop, which is
   // also servicing the radios and the cluster.
   //
   // The completion comes back through TThread.Queue.  That is the mechanism
   // the FMX coexistence spike existed to prove: nothing in TR4W calls
   // CheckSynchronize, and Queue works only because FMX.Forms hooks
   // WakeMainThread and that message reaches FMX through the main loop's
   // fall-through DispatchMessage.
   TThread.CreateAnonymousThread(
      procedure
      var
         found: TStringList;
      begin
         found := TStringList.Create;
         try
            try
               DiscoverNetworkRadios(model, found);
            except
               // A discovery failure is not worth taking the program down for;
               // it comes back as "nothing answered", which is what the
               // operator sees anyway when the radio is off.
               on E: Exception do
                  begin
                  logger.Warn('[Preferences] Discovery failed: %s', [E.Message]);
                  end;
            end;

            TThread.Queue(nil,
               procedure
               var
                  i: integer;
               begin
                  FDiscoverButton.Text    := TC_RADIOEDIT_DISCOVER;
                  FDiscoverButton.Enabled := True;

                  for i := 0 to found.Count - 1 do
                     begin
                     AddComboItem(FFoundCombo, found[i], found[i]);
                     end;

                  if found.Count = 0 then
                     begin
                     ShowMessage(TC_RADIOEDIT_NONEFOUND);
                     end
                  else if found.Count = 1 then
                     begin
                     // Exactly one answer is not a choice -- fill it in.
                     FFoundCombo.ItemIndex := 0;
                     FIPEdit.Text := found[0];
                     end;

                  found.Free;
               end);
         except
            found.Free;
            raise;
         end;
      end).Start;
end;

procedure TRadioEditForm.HandleFoundSelect(Sender: TObject);
begin
   if not FBuilt then
      begin
      Exit;
      end;
   if SelectedTag(FFoundCombo) <> '' then
      begin
      FIPEdit.Text := SelectedTag(FFoundCombo);
      end;
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

end.
