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
  The Preferences window: define the station's HARDWARE once, then build
  PROFILES from it.

  NY4I's model, 2026-08-07: "TR4W has all this hardware it knows about and we
  build different profiles based on what combination of radios and keyers I
  want to use."  So there are LIBRARIES -- radios (uRadioConfigStore) and
  keyers (uKeyerConfigStore) -- and a profile REFERENCES entries in them by
  name.  A radio does not own a keyer, and a keyer is not a property of a
  radio: the pairing is the profile's business, which is why the CW output
  drop-down sits beside the radio drop-down in the profile group.

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

  A DESIGNED FORM.  The layout lives in uPrefsForm.fmx and is edited in the IDE;
  this unit holds behaviour.  The .fmx was GENERATED from the running code-built
  form rather than hand-authored, so the designed layout started out identical to
  the one that had been tested.

  THE DESIGNER IS THE SOURCE OF THE ENGLISH UI (NY4I 2026-08-06).  Captions are
  typed in the Object Inspector and ship as typed; TranslateForm (uFMXTranslate)
  later overrides only the keys a language table supplies and falls through to
  the designed text otherwise.  Nothing here reassigns a caption at construction,
  because a caption that looks right in the designer and is silently replaced at
  run time is precisely the trap this form had.

  WHAT STAYS IN CODE.  Text that CHANGES at run time -- the active profile name,
  '(none)' in a combo, every message box -- is assigned at the point of use from
  the const block below.  So is all list POPULATION that depends on the store or
  the machine.  The nav sections are the exception and are designed: they are a
  fixed structure, identified by Tag.  See SelectFirstSection.
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
   uKeyerConfigStore,
   uRadioEditForm,   // the Radio editor, its own unit since it is next to be designed
   uKeyerEditForm;   // the CW keying-device editor

type

   { Edits ONE TRadioDefinition.  It edits the caller's object directly and only
     when the operator accepts; the caller passes a clone if it wants a
     cancellable edit, which is what TPrefsForm does. }
   // PUBLISHED for streaming, exactly as TRadioEditForm is -- see that unit's
   // header.  A control binds to a field only when the field is published and
   // its name matches the component's Name; an event binds only when the
   // handler is a published method, because TWriter stores it BY NAME.
   TPrefsForm = class(TForm)
      lstNav: TListBox;
      layContent: TLayout;
      lblPlaceholder: TLabel;

      lblMyRadios: TLabel;
      lstRadios: TListBox;
      btnAdd: TButton;
      btnEdit: TButton;
      btnDuplicate: TButton;
      btnRemove: TButton;

      grpProfile: TGroupBox;
      cbxProfile: TComboBox;
      btnNewProfile: TButton;
      btnRenameProfile: TButton;
      btnDeleteProfile: TButton;
      lblRadio1: TLabel;
      cbxRadio1: TComboBox;
      lblCWOutput1: TLabel;
      cbxCW1: TComboBox;
      chkSpeedSync1: TCheckBox;
      lblRadio2: TLabel;
      cbxRadio2: TComboBox;
      lblCWOutput2: TLabel;
      cbxCW2: TComboBox;
      chkSpeedSync2: TCheckBox;
      chkSO2R: TCheckBox;
      lblActive: TLabel;
      btnActivate: TButton;

      chkAutoConnect: TCheckBox;
      layHardware: TLayout;

      // --- CW section (Tag = NAV_CW), the keying-device library ---------------
      layCW: TLayout;
      lblMyKeyers: TLabel;
      lstKeyers: TListBox;
      btnAddKeyer: TButton;
      btnEditKeyer: TButton;
      btnDuplicateKeyer: TButton;
      btnRemoveKeyer: TButton;
      lblKeyerHint: TLabel;

      btnOK: TButton;
      btnCancel: TButton;
      btnApply: TButton;

      procedure HandleNavChange(Sender: TObject);
      procedure HandleAdd(Sender: TObject);
      procedure HandleEdit(Sender: TObject);
      procedure HandleDuplicate(Sender: TObject);
      procedure HandleRemove(Sender: TObject);
      procedure HandleRadioDblClick(Sender: TObject);
      procedure HandleAddKeyer(Sender: TObject);
      procedure HandleEditKeyer(Sender: TObject);
      procedure HandleDuplicateKeyer(Sender: TObject);
      procedure HandleRemoveKeyer(Sender: TObject);
      procedure HandleKeyerDblClick(Sender: TObject);
      procedure HandleNewProfile(Sender: TObject);
      procedure HandleRenameProfile(Sender: TObject);
      procedure HandleDeleteProfile(Sender: TObject);
      procedure HandleProfileChange(Sender: TObject);
      procedure HandleFieldChange(Sender: TObject);
      // MUST live here, with the other streamed handlers.  The .fmx stores an
      // event as the NAME of a PUBLISHED method; declared in a private section
      // it does not resolve, and the form fails to load at run time with
      // "Error reading cbxRadio1.OnChange: Invalid property value" -- no
      // compile error anywhere (NY4I, 2026-08-08).
      procedure HandleSlotRadioChange(Sender: TObject);
      procedure HandleActivate(Sender: TObject);
      procedure HandleOK(Sender: TObject);
      procedure HandleCancel(Sender: TObject);
      procedure HandleApply(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
   private
      // STATE, not controls: nothing here is streamed, so it keeps the F prefix
      // and stays private.
      FStore: TRadioConfigStore;
      // The keyer library, sharing settings\tr4w.json with the radios.
      // uTR4WConfigFile owns the root; neither store knows about the other.
      //
      // THE MODEL (NY4I 2026-08-07): TR4W knows about all the hardware, and a
      // PROFILE is a combination of it -- which radios and which keyers to use
      // together.  So the CW output belongs here beside the radio choice, not
      // on the radio itself.
      FKeyerStore: TKeyerConfigStore;
      FEditor: TRadioEditForm;
      // The keyer editor and its working copy. Modeless like the radio editor,
      // so the result arrives in a callback rather than on the next line.
      FKeyerEditor: TfrmKeyerEdit;
      FKeyerEditTarget: TKeyerDefinition;
      FKeyerEditClone: TKeyerDefinition;
      FKeyerEditIsNew: boolean;
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
      // FDirty is written from ten places.  A SETTER rather than ten calls to a
      // refresh routine, because the eleventh would be the one that forgot --
      // and a stale "Save" button is exactly the confusion this fixes.
      procedure SetDirty(const aValue: boolean);
      property Dirty: boolean read FDirty write SetDirty;

      procedure SelectFirstSection;

      function StoreFileName: string;
      function LegacyStoreFileName: string;
      procedure LoadStore;
      function SaveStore(out aError: string): boolean;

      procedure RefreshRadioList;
      procedure RefreshKeyerList;
      function SelectedKeyer: TKeyerDefinition;
      procedure KeyerEditorDone(const aAccepted: boolean);
      // Profiles reference a keyer BY NAME, so a rename has to follow through
      // and a delete has to be refused while anything still points at it --
      // the same bookkeeping TRadioConfigStore does for radios.
      procedure RenameKeyerInProfiles(const aOldName, aNewName: string);
      function ProfilesUsingKeyer(const aName: string): string;
      procedure RefreshProfileCombo;
      procedure RefreshProfileFields;
      procedure RefreshAll;
      function CurrentProfile: TStationProfile;
      function SelectedRadio: TRadioDefinition;
      procedure FillRadioNameCombo(const aCombo: TComboBox;
                                   const aSelected, aUsedByOtherSlot,
                                   aOtherSlotLabel: string);
      procedure FillCWOutputCombo(const aCombo: TComboBox;
                                  const aSelected, aRadioName: string);
      procedure CaptureProfileFields;

      procedure DiscardChanges;
      procedure EditorDone(const aAccepted: boolean);
      function ApplyNow(const aActivate: boolean): boolean;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
   end;

const
   // The Tag each nav item carries, set in the Object Inspector.  Tag rather
   // than caption text, so the nav survives translation, and rather than
   // position, so reordering the list in the designer cannot silently remap the
   // sections.  THE NUMBER IS THE IDENTITY: it must not be renumbered to match a
   // new display order.
   //
   // Only Hardware has a panel today.  Every other section deliberately shows
   // the placeholder -- they are in the nav to say what this window is GOING to
   // be, so nobody has to guess whether Preferences is meant to grow.
   // NUMBERED FROM 1, and that is load-bearing rather than taste.  A section's
   // PANEL carries the same Tag as its nav item, which is what lets
   // HandleNavChange match them with no case statement and no table -- but Tag
   // defaults to 0 on every control ever dropped on this form.  Starting at 1
   // means 0 reads as "not a section panel", so an untagged control cannot
   // accidentally claim a section.
   NAV_NONE              = 0;
   NAV_STATION           = 1;
   NAV_HARDWARE          = 2;
   NAV_CLUSTER           = 3;
   NAV_SCP               = 4;
   NAV_UDPBROADCAST      = 5;
   NAV_NETWORK           = 6;
   NAV_APPEARANCE        = 7;
   NAV_LOGGING           = 8;
   NAV_BACKUP            = 9;
   NAV_CONTEST           = 10;
   NAV_CW                = 11;
   NAV_WEBSERVER         = 12;
   NAV_EXTERNALSOFTWARE  = 13;
   NAV_ADVANCED          = 14;

// Opens Preferences, creating it on first use.  Called from the PREF
// call-window command.
procedure ShowPreferences;

implementation

{$R *.fmx}

uses
   uFMXFormHelpers,
   uFMXTranslate,
   Winapi.Windows,
   System.IniFiles,
   System.Generics.Collections,
   System.Generics.Defaults,
   FMX.Platform.Win,
   FMX.Dialogs,
   uFMXCoexist,
   uTR4WConfigFile,
   uRadioConfigApply,
   uRadioRegistry,
   uCAT,        // DiscoverNetworkRadios
   MainUnit,    // logger
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
   // Create, NOT CreateNew -- the inherited constructor streams uPrefsForm.fmx.
   // See uRadioEditForm for the full reasoning; this form followed it.
   //
   // SIZE AND BORDER ARE PROPERTIES IN THE DESIGNER NOW, and the reasoning does
   // not survive in a .fmx, so it is recorded here.  Fixed size on purpose
   // (BorderStyle Single, no maximize): every control has a fixed position and
   // width, so a resize would only add whitespace, and a maximize button on a
   // form that cannot use the space is a promise the dialog does not keep.  The
   // three footer buttons are anchored [akRight, akBottom] regardless -- they
   // were once placed from ClientWidth/ClientHeight without anchors and
   // stranded in mid-air on resize (NY4I, 2026-08-05).
   inherited Create(AOwner);

   // English lives in the .fmx; TranslateForm overrides only what a language
   // table supplies and leaves the designed text alone otherwise.  Today no
   // lookup is assigned, so this is a no-op and the designer is the UI.
   TranslateForm(Self);

   // In code as well as in the resource: losing these is invisible -- the form
   // still opens and still looks right, having silently stopped registering its
   // window handle with the FMX coexistence layer, which is what keyboard
   // handling depends on.
   OnShow  := HandleShow;
   OnClose := HandleClose;

   FStore := TRadioConfigStore.Create;
   FKeyerStore := TKeyerConfigStore.Create;
   SelectFirstSection;
   LoadStore;
   RefreshAll;

   // Through the SETTER, so the button starts greyed.  A freshly opened window
   // has nothing unsaved, but the designer leaves every button enabled, and
   // FDirty being False by default would never say so.
   Dirty := False;
end;

// The nav sections are DESIGNED, not built here -- add one in the IDE, set its
// Tag, and wire it.  That is only possible because the section is identified by
// Tag: TComponent.Tag is PUBLISHED, so it streams and appears in the Object
// Inspector, whereas TFmxObject.TagString is public and can do neither.  The
// first version of this form keyed the nav off TagString and so had to build the
// items in code and Clear them on every construction -- which silently threw
// away anything added in the designer (NY4I found it that way, 2026-08-06).
//
// The old code also compared TagString against the CAPTION constant, so
// translating the nav would have broken section switching.  A Tag cannot be
// translated, which is the point.
procedure TPrefsForm.SelectFirstSection;
var
   i: integer;
begin
   // Selecting fires HandleNavChange, which shows the matching panel.  Done here
   // rather than by streaming ItemIndex from the .fmx: OnChange would then fire
   // part-way through loading the form, with the panels it switches not yet
   // streamed in.
   //
   // HARDWARE by tag, not the first row.  Hardware is the only section with a
   // panel, so opening on whatever happens to be top of the list would show the
   // operator the "not migrated yet" placeholder as their first impression of
   // Preferences -- and it would change again the next time the nav is reordered
   // in the designer.
   for i := 0 to lstNav.Items.Count - 1 do
      begin
      if lstNav.ListItems[i].Tag = NAV_HARDWARE then
         begin
         lstNav.ItemIndex := i;
         Exit;
         end;
      end;

   // No Hardware row at all: fall back to the first, so the window is never
   // left with nothing selected.
   if lstNav.Items.Count > 0 then
      begin
      lstNav.ItemIndex := 0;
      end;
end;

destructor TPrefsForm.Destroy;
begin
   FreeAndNil(FEditClone);
   FreeAndNil(FKeyerEditClone);
   FreeAndNil(FKeyerStore);
   FreeAndNil(FStore);
   inherited Destroy;
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
   // 1. The JSON store, if there is one.  Via uTR4WConfigFile, which loads
   //    EVERY library sharing the file -- radios, profiles and keyers -- so the
   //    two stores can never drift out of step through separate reads.
   if LoadConfig(StoreFileName, FStore, FKeyerStore, err) then
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
      // Every library in one atomic write -- see uTR4WConfigFile.
      SaveConfig(StoreFileName, FStore, FKeyerStore);
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
   Result := FStore.FindProfile(SelectedTag(cbxProfile));
end;

function TPrefsForm.SelectedRadio: TRadioDefinition;
begin
   Result := nil;
   if lstRadios.ItemIndex >= 0 then
      begin
      Result := FStore.FindRadio(lstRadios.ListItems[lstRadios.ItemIndex].TagString);
      end;
end;

procedure TPrefsForm.RefreshRadioList;
var
   i, keep: integer;
   item: TListBoxItem;
begin
   keep := lstRadios.ItemIndex;
   lstRadios.Clear;
   for i := 0 to FStore.RadioCount - 1 do
      begin
      item := TListBoxItem.Create(lstRadios);
      item.Stored    := False;
      item.Parent    := lstRadios;
      item.Text      := FStore.Radio(i).DisplaySummary;
      item.TagString := FStore.Radio(i).Name;
      end;
   if (keep >= 0) and (keep < lstRadios.Items.Count) then
      begin
      lstRadios.ItemIndex := keep;
      end
   else if lstRadios.Items.Count > 0 then
      begin
      lstRadios.ItemIndex := 0;
      end;
end;

// aUsedByOtherSlot is the radio the OTHER slot already has.  One physical radio
// cannot be both Radio 1 and Radio 2 -- it is one rig on one port, and putting
// it in both slots makes TR4W open that port twice and poll itself.
//
// SAID IN THE ITEM, not in a dialog afterwards (NY4I 2026-08-08).  The row
// reads "9700-IP (in use as Radio 1)", so the reason is on screen AT THE MOMENT
// OF CHOOSING rather than in a message box after the fact -- and a message box
// that explains a rule the list could have stated is just a longer way of
// saying the same thing, late.
//
// Marked and greyed, NOT removed.  A radio that silently vanished would read as
// a missing definition and send the operator looking for it in the library.
// The TAG stays the bare radio name, so selection still matches by TagString
// and the decorated text never reaches the profile -- the reason this dialog
// selects by tag and never by index.
procedure TPrefsForm.FillRadioNameCombo(const aCombo: TComboBox;
                                        const aSelected, aUsedByOtherSlot,
                                        aOtherSlotLabel: string);
var
   i: integer;
   name, shown: string;
   item: TListBoxItem;
begin
   aCombo.Clear;
   AddComboItem(aCombo, TC_PREFS_NONE, '');
   for i := 0 to FStore.RadioCount - 1 do
      begin
      name  := FStore.Radio(i).Name;
      shown := name;

      // The exception is THIS slot's own current value.  A profile written
      // before this rule can legitimately hold the same radio twice, and
      // marking the very item the combo has to display would leave the control
      // showing a decorated name -- hiding the conflict instead of showing it.
      if (aUsedByOtherSlot <> '') and
         SameText(name, aUsedByOtherSlot) and
         (not SameText(name, aSelected)) then
         begin
         shown := Format(TC_PREFS_RADIOINUSE, [name, aOtherSlotLabel]);
         item  := AddComboItem(aCombo, shown, name);
         item.Enabled := False;
         Continue;
         end;

      AddComboItem(aCombo, shown, name);
      end;
   SelectByTag(aCombo, aSelected);
end;

// The CW output for a profile slot is A CHOICE OF THE CONFIGURED KEYING
// METHODS (NY4I, 2026-08-07) -- not a raw COM port.  This used to offer every
// port on the machine plus 'CW by CAT', which asked the operator to remember
// which port had a keyer on it and to re-answer that question in every profile.
// Now a keyer is DEFINED once in the keyer library and REFERENCED here by name,
// exactly as a radio is.
procedure TPrefsForm.FillCWOutputCombo(const aCombo: TComboBox;
                                       const aSelected, aRadioName: string);
var
   i: integer;
   radio: TRadioDefinition;
begin
   aCombo.Clear;
   AddComboItem(aCombo, TC_PREFS_NONE, CWOUTPUT_NONE);

   // The two RADIO-RELATIVE choices, offered only when the slot's radio can
   // actually provide them.  Both are properties of that radio, not devices --
   // see uKeyerConfigStore's header for where the line falls.
   radio := nil;
   if Trim(aRadioName) <> '' then
      begin
      radio := FStore.FindRadio(aRadioName);
      end;

   if radio <> nil then
      begin
      // ASKED BY REGISTRY ID, not by model enum.  A string-id radio (TCI) has
      // no enum member, so the enum-keyed CapabilitiesFor answers False to
      // everything -- which is precisely how TCI once ended up with no CW at
      // all.  SupportsForId handles both.
      if SupportsForId(radio.RegistryId, rcCWByCAT) then
         begin
         AddComboItem(aCombo, 'CW by CAT', CWOUT_CAT);
         end;

      if (Trim(radio.KeyerOutputPort) <> '') and
         (not SameText(radio.KeyerOutputPort, PORT_NONE)) then
         begin
         AddComboItem(aCombo,
                      Format('Radio keyer port (%s)', [radio.KeyerOutputPort]),
                      CWOUT_RADIOPORT);
         end;
      end;

   // Then every DEVICE in the keyer library, by name.
   for i := 0 to FKeyerStore.KeyerCount - 1 do
      begin
      AddComboItem(aCombo,
                   FKeyerStore.Keyer(i).DisplaySummary,
                   FKeyerStore.Keyer(i).Name);
      end;

   // A stored value that matches nothing on offer is SHOWN, not silently
   // dropped: a profile written before the keyer library holds a raw port like
   // 'SERIAL 3', and CW by CAT stays visible even if the operator has just
   // switched the slot to a radio that cannot do it.  Snapping the profile to
   // '(none)' behind their back would lose a setting they never changed.
   if (Trim(aSelected) <> '') and
      (not SameText(aSelected, CWOUTPUT_NONE)) and
      (not HasTag(aCombo, aSelected)) then
      begin
      AddComboItem(aCombo, Format('%s (not available for this radio)', [aSelected]), aSelected);
      end;

   SelectByTag(aCombo, aSelected);
end;

procedure TPrefsForm.RenameKeyerInProfiles(const aOldName, aNewName: string);
var
   i: integer;
   prof: TStationProfile;
begin
   for i := 0 to FStore.ProfileCount - 1 do
      begin
      prof := FStore.Profile(i);
      if SameText(prof.CWOutput1, aOldName) then
         begin
         prof.CWOutput1 := aNewName;
         end;
      if SameText(prof.CWOutput2, aOldName) then
         begin
         prof.CWOutput2 := aNewName;
         end;
      end;
end;

function TPrefsForm.ProfilesUsingKeyer(const aName: string): string;
var
   i: integer;
   prof: TStationProfile;
begin
   Result := '';
   for i := 0 to FStore.ProfileCount - 1 do
      begin
      prof := FStore.Profile(i);
      if SameText(prof.CWOutput1, aName) or SameText(prof.CWOutput2, aName) then
         begin
         if Result <> '' then
            begin
            Result := Result + ', ';
            end;
         Result := Result + prof.Name;
         end;
      end;
end;

procedure TPrefsForm.RefreshKeyerList;
var
   i, keep: integer;
   item: TListBoxItem;
begin
   keep := lstKeyers.ItemIndex;
   lstKeyers.Clear;
   for i := 0 to FKeyerStore.KeyerCount - 1 do
      begin
      item := TListBoxItem.Create(lstKeyers);
      item.Parent    := lstKeyers;
      // NOT stored: these rows come from the library at run time, so a designer
      // save must never freeze them into the .fmx. See AddComboItem.
      item.Stored    := False;
      item.Text      := FKeyerStore.Keyer(i).DisplaySummary;
      item.TagString := FKeyerStore.Keyer(i).Name;
      end;
   if (keep >= 0) and (keep < lstKeyers.Items.Count) then
      begin
      lstKeyers.ItemIndex := keep;
      end;
end;

function TPrefsForm.SelectedKeyer: TKeyerDefinition;
begin
   Result := nil;
   if (lstKeyers.ItemIndex >= 0) and (lstKeyers.ItemIndex < lstKeyers.Items.Count) then
      begin
      Result := FKeyerStore.FindKeyer(lstKeyers.ListItems[lstKeyers.ItemIndex].TagString);
      end;
end;

procedure TPrefsForm.HandleAddKeyer(Sender: TObject);
begin
   if FKeyerEditor = nil then
      begin
      FKeyerEditor := TfrmKeyerEdit.Create(Self);
      end;

   FKeyerEditIsNew  := True;
   FKeyerEditTarget := nil;
   FreeAndNil(FKeyerEditClone);
   FKeyerEditClone := TKeyerDefinition.Create;
   FKeyerEditClone.Name := FKeyerStore.UniqueKeyerName('WinKeyer');
   FKeyerEditor.EditKeyer(FKeyerEditClone, KeyerEditorDone);
end;

procedure TPrefsForm.HandleEditKeyer(Sender: TObject);
var
   target: TKeyerDefinition;
begin
   target := SelectedKeyer;
   if target = nil then
      begin
      Exit;
      end;

   if FKeyerEditor = nil then
      begin
      FKeyerEditor := TfrmKeyerEdit.Create(Self);
      end;

   // The editor works on a CLONE, so Cancel costs nothing -- the same rule the
   // radio editor follows and the reason opening a dialog cannot alter a
   // configuration by having been looked at.
   FKeyerEditIsNew  := False;
   FKeyerEditTarget := target;
   FreeAndNil(FKeyerEditClone);
   FKeyerEditClone := target.Clone;
   FKeyerEditor.EditKeyer(FKeyerEditClone, KeyerEditorDone);
end;

procedure TPrefsForm.KeyerEditorDone(const aAccepted: boolean);
var
   err: string;
begin
   if not aAccepted then
      begin
      FreeAndNil(FKeyerEditClone);
      Exit;
      end;

   if FKeyerEditIsNew then
      begin
      if FKeyerStore.FindKeyer(FKeyerEditClone.Name) <> nil then
         begin
         ShowMessage(Format('A keyer named "%s" already exists.', [FKeyerEditClone.Name]));
         Exit;
         end;
      FKeyerStore.AddKeyer(FKeyerEditClone.Name, FKeyerEditClone.Kind).Assign(FKeyerEditClone);
      FreeAndNil(FKeyerEditClone);
      end
   else
      begin
      // A RENAME has to fix the profiles that reference this keyer by name,
      // otherwise the reference dangles and the slot silently keys nothing.
      if not SameText(FKeyerEditTarget.Name, FKeyerEditClone.Name) then
         begin
         if not FKeyerStore.RenameKeyer(FKeyerEditTarget.Name, FKeyerEditClone.Name, err) then
            begin
            ShowMessage(err);
            Exit;
            end;
         RenameKeyerInProfiles(FKeyerEditTarget.Name, FKeyerEditClone.Name);
         end;
      FKeyerEditTarget.Assign(FKeyerEditClone);
      FreeAndNil(FKeyerEditClone);
      end;

   Dirty := True;
   RefreshAll;
end;

procedure TPrefsForm.HandleDuplicateKeyer(Sender: TObject);
var
   source, copy: TKeyerDefinition;
begin
   source := SelectedKeyer;
   if source = nil then
      begin
      Exit;
      end;

   copy := FKeyerStore.AddKeyer(FKeyerStore.UniqueKeyerName(source.Name), source.Kind);
   copy.Assign(source);
   copy.Name := FKeyerStore.UniqueKeyerName(source.Name);
   Dirty := True;
   RefreshAll;
end;

procedure TPrefsForm.HandleRemoveKeyer(Sender: TObject);
var
   target: TKeyerDefinition;
   used: string;
begin
   target := SelectedKeyer;
   if target = nil then
      begin
      Exit;
      end;

   // REFUSED while a profile still names it, exactly as a referenced radio is.
   // Deleting it and leaving the reference behind would give that slot no CW
   // with nothing on screen to explain why.
   used := ProfilesUsingKeyer(target.Name);
   if used <> '' then
      begin
      ShowMessage(Format('"%s" is still used by: %s', [target.Name, used]));
      Exit;
      end;

   if MessageDlg(Format(TC_PREFS_CONFIRMREMOVE, [target.Name]),
                 TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
      begin
      Exit;
      end;

   FKeyerStore.RemoveKeyer(target.Name);
   Dirty := True;
   RefreshAll;
end;

procedure TPrefsForm.HandleKeyerDblClick(Sender: TObject);
begin
   HandleEditKeyer(Sender);
end;

procedure TPrefsForm.RefreshProfileCombo;
var
   i: integer;
   keep: string;
begin
   keep := SelectedTag(cbxProfile);
   if keep = '' then
      begin
      keep := FStore.ActiveProfileName;
      end;

   cbxProfile.Clear;
   for i := 0 to FStore.ProfileCount - 1 do
      begin
      AddComboItem(cbxProfile, FStore.Profile(i).Name, FStore.Profile(i).Name);
      end;
   SelectByTag(cbxProfile, keep);
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
         FillRadioNameCombo(cbxRadio1, '', '', '');
         FillRadioNameCombo(cbxRadio2, '', '', '');
         FillCWOutputCombo(cbxCW1, CWOUTPUT_NONE, '');
         FillCWOutputCombo(cbxCW2, CWOUTPUT_NONE, '');
         chkSpeedSync1.IsChecked := False;
         chkSpeedSync2.IsChecked := False;
         chkSO2R.IsChecked  := False;
         end
      else
         begin
         FillRadioNameCombo(cbxRadio1, prof.Radio1Name, prof.Radio2Name, TC_PREFS_RADIO2);
         FillRadioNameCombo(cbxRadio2, prof.Radio2Name, prof.Radio1Name, TC_PREFS_RADIO1);
         FillCWOutputCombo(cbxCW1, prof.CWOutput1, prof.Radio1Name);
         FillCWOutputCombo(cbxCW2, prof.CWOutput2, prof.Radio2Name);
         chkSpeedSync1.IsChecked := prof.SpeedSync1;
         chkSpeedSync2.IsChecked := prof.SpeedSync2;
         chkSO2R.IsChecked  := prof.SO2REnabled;
         end;

      chkAutoConnect.IsChecked := FStore.AutoConnectOnStartup;

      if FStore.ActiveProfileName <> '' then
         begin
         lblActive.Text := TC_PREFS_ACTIVELABEL + FStore.ActiveProfileName;
         end
      else
         begin
         lblActive.Text := TC_PREFS_ACTIVELABEL + TC_PREFS_NONE;
         end;
   finally
      FLoading := False;
   end;
end;

procedure TPrefsForm.RefreshAll;
begin
   RefreshRadioList;
   RefreshKeyerList;
   RefreshProfileCombo;
   RefreshProfileFields;
end;

// "Save" is the only button whose effect is invisible: nothing on screen moves
// when it is pressed, so it reads as a no-op and the whole Save / Save-and-close
// / Cancel set starts to look redundant (NY4I, 2026-08-08).  Greying it when
// there is nothing to commit gives it a visible meaning -- enabled says "there
// are unsaved changes", greyed says "everything here is on disk".
procedure TPrefsForm.SetDirty(const aValue: boolean);
begin
   FDirty := aValue;
   if btnApply <> nil then
      begin
      btnApply.Enabled := FDirty;
      end;
end;

procedure TPrefsForm.CaptureProfileFields;
var
   prof: TStationProfile;
begin
   if FLoading then
      begin
      Exit;
      end;

   FStore.AutoConnectOnStartup := chkAutoConnect.IsChecked;

   prof := CurrentProfile;
   if prof = nil then
      begin
      Exit;
      end;

   prof.Radio1Name  := SelectedTag(cbxRadio1);
   prof.Radio2Name  := SelectedTag(cbxRadio2);
   prof.CWOutput1   := SelectedTag(cbxCW1);
   prof.CWOutput2   := SelectedTag(cbxCW2);
   prof.SpeedSync1  := chkSpeedSync1.IsChecked;
   prof.SpeedSync2  := chkSpeedSync2.IsChecked;
   prof.SO2REnabled := chkSO2R.IsChecked;

   Dirty := True;
end;

{ -------------------------------------------------------------- events ---- }

procedure TPrefsForm.HandleNavChange(Sender: TObject);
var
   i: integer;
   wanted: NativeInt;
   shown: boolean;
   panel: TControl;
begin
   // Guarded because this is wired in the resource: streaming can activate a
   // selection before the panels it switches have themselves been read in.
   if (layHardware = nil) or (lblPlaceholder = nil) then
      begin
      Exit;
      end;

   // Identified by TAG, not by caption.  The previous version compared the
   // item's TagString against TC_PREFS_HARDWARE -- the caption constant -- so
   // translating the nav would have stopped section switching from working, and
   // the coupling was invisible.  A Tag survives translation, and being
   // published it can be set in the Object Inspector on a section added there.
   wanted := NAV_NONE;
   if lstNav.ItemIndex >= 0 then
      begin
      wanted := lstNav.ListItems[lstNav.ItemIndex].Tag;
      end;

   // A SECTION PANEL IS ANY CHILD OF layContent WHOSE TAG MATCHES.  No case
   // statement and no tag-to-panel table: adding a section is designer work
   // only -- drop a layout in layContent, give it the same Tag as its nav item,
   // and it appears.  Nothing here needs to know the section exists.
   //
   // Tag 0 is skipped, which is what keeps the placeholder (and any future
   // untagged decoration) out of the rotation.  See the NAV_ constants.
   shown := False;
   for i := 0 to layContent.ChildrenCount - 1 do
      begin
      if layContent.Children[i] is TControl then
         begin
         panel := TControl(layContent.Children[i]);
         if panel.Tag <> NAV_NONE then
            begin
            panel.Visible := (panel.Tag = wanted);
            shown := shown or panel.Visible;
            end;
         end;
      end;

   // The placeholder is the answer for every section that has no panel yet --
   // which is most of them, deliberately: the nav says what this window is
   // GOING to be, so nobody has to guess whether Preferences is meant to grow.
   lblPlaceholder.Visible := not shown;
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
      Dirty := True;
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
      Dirty := True;
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

   Dirty := True;
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
      Dirty := True;
      RefreshProfileCombo;
      SelectByTag(cbxProfile, prof.Name);
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
   Dirty := True;
   RefreshProfileCombo;
   SelectByTag(cbxProfile, prof.Name);
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
      Dirty := True;
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

// A slot's RADIO changed, so that slot's CW-output list is stale: "CW by CAT"
// and "Radio keyer port" are offered only when THAT radio provides them.
// HandleFieldChange alone captured the new name and left the list built for
// the previously displayed radio, so choosing a K4 in a profile whose slot had
// been empty offered no CW-by-CAT at all -- it looked as though the option
// belonged to some other profile (NY4I, 2026-08-08).
//
// Only the changed slot is rebuilt: refilling both would reset the other
// slot's selection to whatever its stored value is, discarding an edit the
// operator had just made and not yet saved.
procedure TPrefsForm.HandleSlotRadioChange(Sender: TObject);
var
   wasLoading: boolean;
   prof: TStationProfile;
   thisCombo, otherCombo: TComboBox;
   chosen, taken, previous: string;
begin
   if FLoading then
      begin
      CaptureProfileFields;
      Exit;
      end;

   // ENFORCED HERE, not by the greying below.  FMX greys a disabled list item
   // but still SELECTS it: TComboListBox.MouseUp resolves the click through
   // ItemByPoint, which tests only Visible, and then assigns ItemIndex
   // unconditionally (FMX.ListBox.pas).  So Enabled := False on a combo item is
   // presentation only -- it was shipped as if it were a constraint and NY4I
   // could still pick the same radio twice (2026-08-08).  The greying stays as
   // the AFFORDANCE; this is the rule.
   //
   // Read BEFORE CaptureProfileFields, because that is what overwrites the
   // profile with the new selection -- the old value is the only thing that can
   // be reverted to.
   if Sender = cbxRadio2 then
      begin
      thisCombo  := cbxRadio2;
      otherCombo := cbxRadio1;
      end
   else
      begin
      thisCombo  := cbxRadio1;
      otherCombo := cbxRadio2;
      end;

   prof   := CurrentProfile;
   chosen := SelectedTag(thisCombo);
   taken  := SelectedTag(otherCombo);

   if (prof <> nil) and (Trim(chosen) <> '') and SameText(chosen, taken) then
      begin
      if thisCombo = cbxRadio2 then
         begin
         previous := prof.Radio2Name;
         end
      else
         begin
         previous := prof.Radio1Name;
         end;

      // REVERTED SILENTLY.  The row the operator clicked says "(in use as
      // Radio 1)" in as many words, so the reason was on screen before the
      // click -- a modal afterwards only repeats it, later and more loudly.
      //
      // It also removes a real defect rather than papering over it: showing a
      // message box from inside a combo's OnChange put the dialog up TWICE
      // (NY4I 2026-08-08).  Reverting is a control assignment, which the
      // FLoading guard already covers; a modal is re-entrant in a way no guard
      // here was going to make reliable.
      wasLoading := FLoading;
      FLoading := True;
      try
         SelectByTag(thisCombo, previous);
      finally
         FLoading := wasLoading;
      end;
      Exit;
      end;

   CaptureProfileFields;

   // Refilling fires the combo's own OnChange; the guard stops that from
   // writing a half-built list back into the profile.
   wasLoading := FLoading;
   FLoading := True;
   try
      if Sender = cbxRadio2 then
         begin
         FillCWOutputCombo(cbxCW2, SelectedTag(cbxCW2), SelectedTag(cbxRadio2));
         end
      else
         begin
         FillCWOutputCombo(cbxCW1, SelectedTag(cbxCW1), SelectedTag(cbxRadio1));
         end;

      // The OTHER slot's list is now stale: whatever this slot just took must
      // become unavailable over there, and whatever it released must come back.
      // Rebuilt preserving that slot's own selection, so refreshing the greying
      // never changes a choice the operator made.
      FillRadioNameCombo(cbxRadio1, SelectedTag(cbxRadio1), SelectedTag(cbxRadio2), TC_PREFS_RADIO2);
      FillRadioNameCombo(cbxRadio2, SelectedTag(cbxRadio2), SelectedTag(cbxRadio1), TC_PREFS_RADIO1);
   finally
      FLoading := wasLoading;
   end;

   // The refill may have dropped a choice the new radio cannot provide, so the
   // profile must be re-read from the controls rather than left at the value
   // captured above.
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

   Dirty := False;

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

   if not ApplyProfile(FStore, prof, err, FKeyerStore) then
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
   Dirty := False;
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
