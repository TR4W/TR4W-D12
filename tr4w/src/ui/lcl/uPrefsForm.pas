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
{$I ..\..\tr4w.inc}

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
  typed in the Object Inspector and ship as typed; TranslateForm (uLCLTranslate)
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
   SysUtils,
   Classes,
   System.UITypes,
   uLCLFormHelpers,      // TStopwatch and the list/combo tag helpers
   Controls,
   Forms,
   StdCtrls,
   // TComboBox -- the cluster server picker is editable
   ComCtrls,
   ExtCtrls,       // TPath -- the nav expander chevron
   Graphics,      // TBrushKind / TStrokeCap / TStrokeJoin for that chevron
   uRadioConfigStore,
   uKeyerConfigStore,
   uRadioEditForm,   // the Radio editor, its own unit since it is next to be designed
   uKeyerEditForm,   // the CW keying-device editor
   uUDPDestinationEditForm,   // one UDP destination, edited in isolation
   uUDPBroadcastConfig,       // the settings this panel edits
   uSettingsBinding;          // TSettingBindings -- a field on the form below

type

   { Edits ONE TRadioDefinition.  It edits the caller's object directly and only
     when the operator accepts; the caller passes a clone if it wants a
     cancellable edit, which is what TPrefsForm does. }
   // PUBLISHED for streaming, exactly as TRadioEditForm is -- see that unit's
   // header.  A control binds to a field only when the field is published and
   // its name matches the component's Name; an event binds only when the
   // handler is a published method, because TWriter stores it BY NAME.
   { One row of the Station panel: the CFGCA command it edits, and the control
     that shows it.  A TABLE rather than thirty lines of copy-paste -- every
     field does the same thing, so the only per-field facts are the command name
     and the control, and those belong in data. }
   TStationField = record
      Command: string;
      Edit: TEdit;
   end;

   { What ForEachNavItem calls for each item. }
   TNavItemVisit = procedure (item: TTreeNode) of object;

   TPrefsForm = class(TForm)
      tvNav: TTreeView;
      layContent: TPanel;
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
      layRadios: TPanel;

      // --- TCI Server (Tag = NAV_TCISERVER) ----------------------------------
      // Its OWN section, beside Web Server, because that is what it is: a
      // network service TR4W offers to other programs.  Not a radio -- it
      // exposes whichever radio is ACTIVE, which is the point of trx 0 / trx 1
      // -- and not external software either.  The enable check box MOVED here
      // off Hardware rather than being duplicated: enable in one place and port
      // in another is exactly the split this settings pass exists to remove.
      layTCIServer: TPanel;
      chkTCIServer: TCheckBox;
      lblTCIIntro: TLabel;
      lblTCIPort: TLabel;
      edtTCIPort: TEdit;
      chkTCIBindAll: TCheckBox;
      lblTCIBindAllWarning: TLabel;
      lblTCIMaxTx: TLabel;
      edtTCIMaxTx: TEdit;
      lblTCIMaxTxUnits: TLabel;
      lblTCIMaxTxHint: TLabel;
      lblTCILogHint: TLabel;

      // --- Station (Tag = NAV_STATION) ----------------------------------------
      // The TR4QT station pane combined with TR4W's MY* commands, per
      // docs/Settings Design Proposal.md.  ONE control for MY STATE: 'MY QTH'
      // is the same global (@MyState), a back-compat alias.
      layStation: TPanel;
      lblStationHeading: TLabel;
      lblContestHeading: TLabel;
      lblStationHint: TLabel;
      lblMyContinent: TLabel;
      cbxMyContinent: TComboBox;
      lblMyCall: TLabel;
      edtMyCall: TEdit;
      lblMyName: TLabel;
      edtMyName: TEdit;
      lblMyGrid: TLabel;
      edtMyGrid: TEdit;
      lblMyZone: TLabel;
      edtMyZone: TEdit;
      lblMyITUZone: TLabel;
      edtMyITUZone: TEdit;
      lblMyState: TLabel;
      edtMyState: TEdit;
      lblMySection: TLabel;
      edtMySection: TEdit;
      lblMyCountry: TLabel;
      edtMyCountry: TEdit;
      lblMyPostalCode: TLabel;
      edtMyPostalCode: TEdit;
      lblMyCheck: TLabel;
      edtMyCheck: TEdit;
      lblMyPrec: TLabel;
      edtMyPrec: TEdit;
      lblMyFDClass: TLabel;
      edtMyFDClass: TEdit;
      lblMyFOCNumber: TLabel;
      edtMyFOCNumber: TEdit;
      lblMyIOTA: TLabel;
      edtMyIOTA: TEdit;
      lblMyPark: TLabel;
      edtMyPark: TEdit;

      // --- External Software (Tags 16..19) ------------------------------------
      // Four children of the External Software node.  DXLab has no settings of
      // its own -- see its panel -- and is present because operators look for it.
      layWSJTX: TPanel;
      layExternalLogger: TPanel;
      layDXLab: TPanel;
      layMMTTY: TPanel;
      lblWSJTXHeading: TLabel;
      lblWSJTXPort: TLabel;
      lblWSJTXMulticast: TLabel;
      lblWSJTXRestart: TLabel;
      lblWSJTXTCIHint: TLabel;
      lblLoggerHeading: TLabel;
      lblLoggerType: TLabel;
      lblLoggerAddress: TLabel;
      lblLoggerPort: TLabel;
      lblLoggerRestart: TLabel;
      lblLoggerStatus: TLabel;
      lblDXLabHeading: TLabel;
      lblDXLabInfo: TLabel;
      lblDXLabInfo2: TLabel;
      lblMMTTYHeading: TLabel;
      lblMMTTYEngine: TLabel;
      lblMMTTYHint: TLabel;
      chkWSJTXEnabled: TCheckBox;
      chkWSJTXRadioControl: TCheckBox;
      chkWSJTXHighlights: TCheckBox;
      chkLoggerEnabled: TCheckBox;
      edtWSJTXPort: TEdit;
      edtWSJTXMulticast: TEdit;
      edtLoggerAddress: TEdit;
      edtLoggerPort: TEdit;
      edtMMTTYEngine: TEdit;
      cbxLoggerType: TComboBox;
      btnBrowseMMTTY: TButton;

      // --- DX Cluster (Tag 3) and Band Map (Tag 20) ---------------------------
      layCluster: TPanel;
      lblClusterHeading: TLabel;
      lstClusters: TListBox;
      btnAddCluster: TButton;
      btnRemoveCluster: TButton;
      btnUseCluster: TButton;
      lblActiveCluster: TLabel;
      lblClusterName: TLabel;
      edtClusterName: TEdit;
      lblClusterServer: TLabel;
      // A TComboBox, not a TComboBox: FMX's TComboBox.Text is READ-ONLY
      // (it reflects the selection), and this field has to accept a server
      // that is not in TRCLUSTER.DAT -- a club node, or a private one.
      cbxClusterServer: TComboBox;
      lblClusterServerHint: TLabel;
      lblClusterLogin: TLabel;
      edtClusterLogin: TEdit;
      lblClusterLoginHint: TLabel;
      lblClusterPassword: TLabel;
      edtClusterPassword: TEdit;
      lblClusterCommandHint: TLabel;
      lblClusterGlobalHeading: TLabel;
      chkSpotCollector: TCheckBox;
      lblClusterNote: TLabel;
      layBandMap: TPanel;
      lblBandMapHeading: TLabel;
      chkBandMapEnable: TCheckBox;
      lblBandMapDecay: TLabel;
      edtBandMapDecay: TEdit;
      lblBandMapDecayUnits: TLabel;
      lblBandMapGuard: TLabel;
      edtBandMapGuard: TEdit;
      lblBandMapGuardUnits: TLabel;
      lblBandMapLimit: TLabel;
      edtBandMapLimit: TEdit;
      lblBandMapLimitUnits: TLabel;
      lblBandMapNote: TLabel;
      chkBandMapDupes: TCheckBox;
      chkBandMapMultsOnly: TCheckBox;
      chkBandMapAllBands: TCheckBox;
      chkBandMapAllModes: TCheckBox;
      chkBandMapCQ: TCheckBox;
      chkBandMapCallWindow: TCheckBox;
      chkBandMapSO2R: TCheckBox;
      chkBandMapGHz: TCheckBox;

      // --- SCP (4), Network (6), Appearance (7), Backup (9) -------------------
      laySCP: TPanel;
      layNetwork: TPanel;
      layAppearance: TPanel;
      layBackup: TPanel;
      lblSCPHeading: TLabel;
      lblSCPMinLetters: TLabel;
      lblSCPMinLettersUnits: TLabel;
      lblSCPCountry: TLabel;
      lblSCPHint: TLabel;
      lblSCPFileHint: TLabel;
      lblNetHeading: TLabel;
      lblNetAddress: TLabel;
      lblNetPort: TLabel;
      lblNetPassword: TLabel;
      lblNetComputerID: TLabel;
      lblNetComputerIDHint: TLabel;
      lblNetHint: TLabel;
      lblRadioTCPHeading: TLabel;
      lblRadioTCPPort: TLabel;
      lblRadioTCPHint: TLabel;
      lblAppearHeading: TLabel;
      lblMainFont: TLabel;
      lblFontSize: TLabel;
      lblAppearHint: TLabel;
      lblAppearColorsHint: TLabel;
      lblBackupHeading: TLabel;
      lblBackupEvery: TLabel;
      lblBackupEveryUnits: TLabel;
      lblBackupFile: TLabel;
      lblBackupHint: TLabel;
      cbxSCPMinLetters: TComboBox;
      edtSCPCountry: TEdit;
      edtNetAddress: TEdit;
      edtNetPort: TEdit;
      edtNetPassword: TEdit;
      edtNetComputerID: TEdit;
      edtRadioTCPPort: TEdit;
      edtMainFont: TEdit;
      edtFontSize: TEdit;
      edtBackupEvery: TEdit;
      edtBackupFile: TEdit;
      chkNetAutoSync: TCheckBox;
      chkBoldFont: TCheckBox;
      chkDupeSheetColor: TCheckBox;
      btnBrowseBackup: TButton;

      // --- Operating leaves, CW sending, and the DX cluster additions ---------
      // Declared because a binding or a handler touches them.  Labels and the
      // nav items are not: labels are decoration, and nav items are found by Tag.
      chkCWEnable: TCheckBox;
      chkCWSpeedFromDatabase: TCheckBox;
      cbxCWSpeedIncrement: TComboBox;
      edtCWTone: TEdit;
      chkClusterAtStartup: TCheckBox;
      edtClusterCommand: TEdit;
      chkHamScoreEnable: TCheckBox;
      edtHamScoreURL: TEdit;
      edtHamScoreUser: TEdit;
      edtHamScorePass: TEdit;
      chkHamScoreContact: TCheckBox;
      edtScorePostURL: TEdit;
      edtScoreReadURL: TEdit;
      chkSayHiEnable: TCheckBox;
      edtSayHiCutoff: TEdit;
      chkKeypadCWMemories: TCheckBox;
      cbxLeadingZeros: TComboBox;
      edtLeadingZeroChar: TEdit;
      cbxDitDah: TComboBox;
      edtWeight: TEdit;
      chkFarnsworth: TCheckBox;
      edtFarnsworthSpeed: TEdit;
      chkHFBands: TCheckBox;
      chkWARCBands: TCheckBox;
      chkVHFBands: TCheckBox;
      chkTwoRadioMode: TCheckBox;
      chkAltDBuffer: TCheckBox;
      chkAltDCQ: TCheckBox;
      chkAlwaysBlindCQ: TCheckBox;
      chkSkipActiveBand: TCheckBox;

      // --- Rotators (Tag = NAV_ROTATORS) --------------------------------------
      layRotators: TPanel;
      lblMyRotators: TLabel;
      lstRotators: TListBox;
      btnAddRotator: TButton;
      btnRemoveRotator: TButton;
      lblRotatorName: TLabel;
      edtRotatorName: TEdit;
      lblRotatorType: TLabel;
      cbxRotatorType: TComboBox;
      lblRotatorPort: TLabel;
      cbxRotatorPort: TComboBox;
      lblRotatorBaud: TLabel;
      edtRotatorBaud: TEdit;
      lblRotatorBaudHint: TLabel;
      lblRotatorIP: TLabel;
      edtRotatorIP: TEdit;
      lblRotatorUDP: TLabel;
      edtRotatorUDP: TEdit;
      lblRotatorBands: TLabel;
      edtRotatorBands: TEdit;
      lblRotatorBandsHint: TLabel;
      lblRotatorNote: TLabel;

      // --- Logging (Tag = NAV_LOGGING) ---------------------------------------
      // The ONE place for logging, which used to be spread across a level key,
      // three HamLib switches, a telnet switch, and TCI's own settings file
      // (NY4I: "our logging is all over the place").
      layLogging: TPanel;
      lblLogLevel: TLabel;
      cbxLogLevel: TComboBox;
      lblLogLevelHint: TLabel;
      lblDetailLogs: TLabel;
      chkTelnetDebug: TCheckBox;
      chkTCIDebug: TCheckBox;
      chkHamLibDebug: TCheckBox;
      chkHamLibTrace: TCheckBox;
      chkHamLibAsyncOnly: TCheckBox;
      lblHamLibRestart: TLabel;
      btnOpenLogFile: TButton;
      lblLogFilePath: TLabel;

      // --- CW section (Tag = NAV_CW), the keying-device library ---------------
      layCW: TPanel;
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

      // --- UDP section (Tag = NAV_UDPBROADCAST) -------------------------------
      layUDP: TPanel;
      chkUDPEnabled: TCheckBox;
      lblUDPDestinations: TLabel;
      lstUDPDestinations: TListBox;
      btnUDPAdd: TButton;
      btnUDPEdit: TButton;
      btnUDPRemove: TButton;
      btnUDPTest: TButton;
      chkUDPAllQSOs: TCheckBox;
      lblUDPHint: TLabel;

      procedure tvNavChange(Sender: TObject);
      procedure btnAddClick(Sender: TObject);
      procedure btnEditClick(Sender: TObject);
      procedure btnDuplicateClick(Sender: TObject);
      procedure btnRemoveClick(Sender: TObject);
      procedure lstRadiosDblClick(Sender: TObject);
      procedure btnAddKeyerClick(Sender: TObject);
      procedure btnEditKeyerClick(Sender: TObject);
      procedure btnDuplicateKeyerClick(Sender: TObject);
      procedure btnRemoveKeyerClick(Sender: TObject);
      procedure lstKeyersDblClick(Sender: TObject);
      procedure btnNewProfileClick(Sender: TObject);
      procedure btnRenameProfileClick(Sender: TObject);
      procedure btnDeleteProfileClick(Sender: TObject);
      procedure cbxProfileChange(Sender: TObject);

      // ONE HANDLER PER CONTROL, named the way the IDE names them, each a thin
      // adapter over a private method that takes what it needs as PARAMETERS
      // (NY4I 2026-08-08).  The alternative -- one handler shared by several
      // controls, working out from Sender which one fired -- is a dispatcher
      // wearing an event handler's signature: the compiler cannot check an
      // untyped TObject comparison, and pointing a new control at it silently
      // takes the else branch.  Sharing is only safe where the body ignores
      // Sender entirely, and then it saves nothing worth the ambiguity.
      procedure cbxCW1Change(Sender: TObject);
      procedure cbxCW2Change(Sender: TObject);
      procedure chkSpeedSync1Change(Sender: TObject);
      procedure chkSpeedSync2Change(Sender: TObject);
      procedure chkSO2RChange(Sender: TObject);
      procedure chkAutoConnectChange(Sender: TObject);
      procedure chkTCIServerChange(Sender: TObject);
      procedure cbxLogLevelChange(Sender: TObject);
      procedure btnBrowseMMTTYClick(Sender: TObject);
      procedure btnBrowseBackupClick(Sender: TObject);
      procedure lstClustersChange(Sender: TObject);
      procedure cbxClusterServerChange(Sender: TObject);
      procedure cbxClusterServerEnter(Sender: TObject);
      // ONE HANDLER PER CONTROL, each delegating to the same capture routine --
      // the house pattern, and NOT one handler branching on Sender.  These were
      // missing entirely until 2026-08-11: the capture routine existed and was
      // correct, but nothing in the .fmx ever called it, so every one of these
      // fields was typed into and silently discarded (NY4I lost a password that
      // way).  Delphi cannot warn about this -- an unreferenced published method
      // is just an unused method -- which is why Lint-FormEvents now exists.
      procedure edtClusterNameChange(Sender: TObject);
      procedure edtClusterLoginChange(Sender: TObject);
      procedure edtClusterPasswordChange(Sender: TObject);
      procedure edtClusterCommandChange(Sender: TObject);
      procedure btnAddClusterClick(Sender: TObject);
      procedure btnRemoveClusterClick(Sender: TObject);
      procedure btnUseClusterClick(Sender: TObject);
      procedure lstRotatorsChange(Sender: TObject);
      procedure cbxRotatorTypeChange(Sender: TObject);
      procedure cbxRotatorPortChange(Sender: TObject);
      procedure edtRotatorNameChange(Sender: TObject);
      procedure edtRotatorBaudChange(Sender: TObject);
      procedure edtRotatorIPChange(Sender: TObject);
      procedure edtRotatorUDPChange(Sender: TObject);
      procedure edtRotatorBandsChange(Sender: TObject);
      procedure btnAddRotatorClick(Sender: TObject);
      procedure btnRemoveRotatorClick(Sender: TObject);
      procedure btnOpenLogFileClick(Sender: TObject);

      // MUST live here, with the other streamed handlers.  The .fmx stores an
      // event as the NAME of a PUBLISHED method; declared in a private section
      // it does not resolve, and the form fails to load at run time with
      // "Error reading cbxRadio1.OnChange: Invalid property value" -- no
      // compile error anywhere (NY4I, 2026-08-08).
      procedure cbxRadio1Change(Sender: TObject);
      procedure cbxRadio2Change(Sender: TObject);
      procedure btnActivateClick(Sender: TObject);

      // --- UDP section --------------------------------------------------------
      procedure btnUDPAddClick(Sender: TObject);
      procedure btnUDPEditClick(Sender: TObject);
      procedure btnUDPRemoveClick(Sender: TObject);
      procedure btnUDPTestClick(Sender: TObject);
      procedure lstUDPDestinationsDblClick(Sender: TObject);
      procedure chkUDPEnabledChange(Sender: TObject);
      procedure chkUDPAllQSOsChange(Sender: TObject);

      procedure btnOKClick(Sender: TObject);
      procedure btnCancelClick(Sender: TObject);
      procedure btnApplyClick(Sender: TObject);
      procedure FormShow(Sender: TObject);
      procedure FormClose(Sender: TObject; var Action: TCloseAction);
   private
      // STATE, not controls: nothing here is streamed, so it keeps the F prefix
      // and stays private.
      FStore: TRadioConfigStore;
      { Controls bound to settings by KEY -- see uSettingsBinding.  Anything
        bound needs no load/save code of its own. }
      FBindings: TSettingBindings;
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

      // The UDP broadcast settings, edited as a WORKING COPY like every other
      // library here: Cancel throws it away and reloads, Apply writes it and
      // hands it to the broadcaster.  It shares settings\tr4w.json with the
      // radios and keyers through uTR4WConfigFile, so one write covers all
      // three and they cannot drift apart.
      FUDPConfig: TUDPBroadcastConfig;
      FUDPEditor: TfrmUDPDestinationEdit;
      FUDPEditTarget: TUDPDestination;
      FUDPEditClone: TUDPDestination;
      FUDPEditIsNew: boolean;
      FLoading: boolean;
      // The cluster directory is built once per program run, on first visit to
      // the DX Cluster section.  See LoadClusterServerList for the measurement.
      FClusterServersLoaded: boolean;
      { Where NoteRadiosNavItem leaves its answer.  A field rather than a
        captured local: the visitor is a method now, so it needs somewhere on
        the object to put the result. }
      FNavWanted: TTreeNode;

      // The navigation nodes, built by BuildNavTree rather than streamed.
      navStation: TTreeNode;
      navHardware: TTreeNode;
      navRadios: TTreeNode;
      navRotators: TTreeNode;
      navCluster: TTreeNode;
      navOperating: TTreeNode;
      navBandMap: TTreeNode;
      navBands: TTreeNode;
      navOperatingCW: TTreeNode;
      navOnlineScoring: TTreeNode;
      navTwoRadio: TTreeNode;
      navSCP: TTreeNode;
      navUDPBroadcast: TTreeNode;
      navNetwork: TTreeNode;
      navAppearance: TTreeNode;
      navLogging: TTreeNode;
      navBackup: TTreeNode;
      navContest: TTreeNode;
      navCW: TTreeNode;
      navWebServer: TTreeNode;
      navTCIServer: TTreeNode;
      navExternalSoftware: TTreeNode;
      navWSJTX: TTreeNode;
      navExternalLogger: TTreeNode;
      navDXLab: TTreeNode;
      navMMTTY: TTreeNode;
      navAdvanced: TTreeNode;
      // The construction phase timer -- a FIELD rather than a local so that the
      // phases inside RefreshProfileFields report against the same watch and the
      // numbers still sum to the total.  See LogPhase.
      FTiming: TStopwatch;
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
      // Logging panel <-> store.  Separate from LoadStore/SaveStore only for
      // readability; they are called from exactly there.
      procedure LoadLoggingPanel;
      procedure SaveLoggingPanel;
      procedure LoadTCIPanel;
      procedure SaveTCIPanel;

      // Station.  Save returns False when CFGCA refused any value, having told
      // the operator which -- a refused entry must not close silently.
      procedure FillFromAllowedValues(const aCombo: TComboBox; const aCommand: string);
      procedure BuildBindings;
      procedure LoadClusterServerList;
      procedure LoadClusterList;
      { The blanket "something was edited" marker.  See HookDirtyMarkers. }
      procedure MarkDirty(Sender: TObject);
      procedure HookDirtyMarkers(const aRoot: TWinControl);
      procedure HookDirtyMarker(const aControl: TWinControl);
      function  ClusterIsActive(const aCluster: TClusterDefinition): boolean;
      procedure ShowClusterRow(const aIndex: integer;
                               const aCluster: TClusterDefinition);
      procedure RefreshClusterRows;
      procedure ShowRotatorRow(const aIndex: integer;
                               const aRotator: TRotatorDefinition);
      procedure ShowActiveCluster;
      procedure ShowSelectedCluster;
      procedure CaptureSelectedCluster;
      procedure LoadRotatorList;
      procedure ShowSelectedRotator;
      procedure CaptureSelectedRotator;
      procedure LoadRemainingPanels;
      procedure SaveRemainingPanels;
      procedure LoadClusterPanels;
      procedure SaveClusterPanels;
      procedure LoadExternalSoftwarePanels;
      procedure SaveExternalSoftwarePanels;
      function  CommandBool(const aCommand: string): boolean;
      function  SetCommandBool(const aCommand: string; const aValue: boolean): boolean;
      procedure LoadStationPanel;
      function  SaveStationPanel: boolean;
      function  StationFields: TArray<TStationField>;
      function  MakeStationField(const aCommand: string; const aEdit: TEdit): TStationField;

      // The nav expander drawn as a chevron rather than the style's filled
      // triangle -- see the implementation.
      { Every nav item, expanded or not.  NOT GlobalCount -- see the
        implementation; that list stops at a collapsed parent. }
      { A METHOD POINTER, not TProc<T>.  Same change as the radio and rotator
        factories: `of object` names the owner of whatever the visitor touches,
        and it compiles without closures. }
      procedure ForEachNavItem(const aVisit: TNavItemVisit);
      { Visitors. Each is a method because each needs Self anyway -- one to reach
        the form's helpers, one to record what it found. }
      procedure BuildNavTree;
      procedure NoteRadiosNavItem(item: TTreeNode);
      procedure ApplyChevrons;

      procedure FillRadioNameCombo(const aCombo: TComboBox;
                                   const aSelected, aUsedByOtherSlot,
                                   aOtherSlotLabel: string);
      procedure FillCWOutputCombo(const aCombo: TComboBox;
                                  const aSelected, aRadioName: string);
      procedure CaptureProfileFields;

      // WHERE THE WORK LIVES.  Each is called by more than one control's
      // handler -- Edit and a double-click, slot 1 and slot 2 -- so it takes
      // what it operates on as an argument instead of asking who called it.
      procedure EditSelectedRadio;
      procedure EditSelectedKeyer;
      procedure SlotRadioChanged(const aThisCombo, aOtherCombo, aThisCWCombo: TComboBox);

      // --- UDP section --------------------------------------------------------
      procedure RefreshUDPList;
      function  UDPRowText(const aDestination: TUDPDestination): string;
      function  SelectedUDPDestination: TUDPDestination;
      procedure EditSelectedUDPDestination;
      procedure UDPEditorDone(const aAccepted: boolean);
      procedure CaptureUDPFields;

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
   // tvNavChange match them with no case statement and no table -- but Tag
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

   // APPENDED, NOT RENUMBERED.  The tags are stamped into the .fmx resource;
   // renumbering would mean re-editing every nav item and every panel in the
   // designer, and a single missed pair is a section that silently stops
   // opening.  Order in the tree is a designer concern and is independent of
   // these numbers.
   NAV_TCISERVER         = 15;   // its own leaf: a service TR4W offers, like Web Server

   // Children of External Software.  Nav entries only for now -- a section with
   // no panel shows the placeholder, which Lint-FormTags deliberately allows.
   // They exist so the HIERARCHY is settled before panels are written against
   // it: splitting one flat panel into four later is the throwaway work worth
   // avoiding (NY4I).
   NAV_WSJTX             = 16;
   NAV_EXTERNALLOGGER    = 17;
   NAV_DXLAB             = 18;
   NAV_MMTTY             = 19;

   // Band map is its OWN section, not part of DX Cluster.  NY4I: "a band map
   // strictly speaking can be used without a dx cluster" -- it also holds spots
   // the operator makes by hand and whatever the second radio hears, so filing
   // it under the cluster would say something untrue about when it works.
   NAV_BANDMAP           = 20;

   // A PARENT for the things that are about operating rather than about
   // hardware or files (NY4I).  It has no panel of its own -- selecting it
   // shows the placeholder, the same as External Software -- because it is a
   // grouping, and inventing a page for it would mean inventing content.
   // Band Map is its first leaf; SCP, Contest and CW Settings are the obvious
   // candidates to join it once NY4I says so.
   NAV_OPERATING         = 21;

   // Pixels a child is indented under its parent.  Stated rather than taken
   // from the style -- see ApplyChevrons for why that is not optional.
   NAV_CHILD_INDENT      = 20;

   // Hardware became a PARENT (NY4I): the radio library moved to a Radios leaf
   // beside a new Rotators one.  The Hardware panel itself was simply retagged
   // -- 272 lines of designed layout that did not have to move, which is what
   // tag dispatch buys.
   NAV_RADIOS            = 26;
   NAV_ROTATORS          = 27;

// Opens Preferences, creating it on first use.  Called from the PREF
// call-window command.
procedure ShowPreferences;

implementation

{$R *.lfm}

uses
   uLCLTranslate,
   Windows,
   IniFiles,
   Generics.Collections,
   Generics.Defaults,
   uHostedFormWindows,
   Dialogs,
   uTR4WConfigFile,
   uRadioConfigApply,
   uRadioRegistry,
   uCAT,        // DiscoverNetworkRadios
   uUDPBroadcaster,   // TestDestination, and Configure once the settings are saved
   uTCIServer,        // started/stopped when the check box is saved
   uFileText,          // FileTextExists -- System.IOUtils is Delphi-only
   ShellAPI,    // ShellExecute -- open the log in the operator's editor
   uCFG,        // CFGCommandValueAsString / SetCFGCommandValue -- Station edits CFGCA rows
   uSettingsRegistry,     // the settings themselves
   uSettingsDeclarations, // DeclareAllSettings
   ComPortEnumerator,   // the real serial ports, same source as the radio editor
   uRotatorBase,        // UsesSerialPort / PreferredBaudRate -- asked, not assumed
   uRotatorControl,     // rebuild the live rotators when the library is saved
   uRotatorRegistry,    // the rotator type list comes from the registry
   uCallSignRoutines,   // GoodCallSyntax -- the MY CALL sanity check
   uExternalLoggerBase, // ExternalLoggerTypeSA -- the logger-program list
   MainUnit,    // logger, and `appender` for the log file's real path
   VC;          // tLogLevels / tLogLevelsSA / logLevels, TR4W_TCI_DEBUG

var
   gPrefsForm: TPrefsForm = nil;

// WHERE THE FIRST-OPEN SECOND GOES.  NY4I reported a noticeable delay the first
// time Preferences opens after startup and none on later opens -- which points
// at construction rather than at Show, but "points at" is not a measurement.
// The form went from 67 designed controls to 347 in one day, and construction
// also enumerates the serial ports and pours TRCLUSTER.DAT into a combo, so
// there are three credible suspects and no way to pick between them by reading.
//
// KEPT after the fix, not deleted with it.  "Preferences is slow" is a report
// that will come again -- a new panel, a bigger file, a slower machine -- and
// the whole reason this one took a build to answer is that there was no number
// anywhere.  The cost is a handful of QueryPerformanceCounter calls.
//
// TOTALS at Info, PHASES at Debug.  An operator reporting slowness should not
// have to reconfigure logging to give a useful number, but fifteen lines per
// open is noise in everybody else's log.  Each call restarts the watch, so the
// phases are individual costs and sum to the total.
procedure LogPhase(var aWatch: TStopwatch; const aName: string;
                   const aIsTotal: boolean = False);
begin
   if aIsTotal then
      begin
      logger.Info('[Prefs] %-22s %5d ms', [aName, aWatch.ElapsedMilliseconds]);
      end
   else
      begin
      logger.Debug('[Prefs] %-22s %5d ms', [aName, aWatch.ElapsedMilliseconds]);
      end;
   aWatch := TStopwatch.StartNew;
end;

procedure ShowPreferences;
var
   sw: TStopwatch;
begin
   sw := TStopwatch.StartNew;

   if gPrefsForm = nil then
      begin
      gPrefsForm := TPrefsForm.Create(nil);
      LogPhase(sw, 'CONSTRUCT first open', True);
      end;

   gPrefsForm.Show;
   gPrefsForm.BringToFront;
   LogPhase(sw, 'Show + BringToFront');
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
   FTiming := TStopwatch.StartNew;
   inherited Create(AOwner);
   LogPhase(FTiming, 'stream .fmx');

   // English lives in the .fmx; TranslateForm overrides only what a language
   // table supplies and leaves the designed text alone otherwise.  Today no
   // lookup is assigned, so this is a no-op and the designer is the UI.
   TranslateForm(Self);
   LogPhase(FTiming, 'TranslateForm');

   // In code as well as in the resource: losing these is invisible -- the form
   // still opens and still looks right, having silently stopped registering its
   // window handle with the FMX coexistence layer, which is what keyboard
   // handling depends on.
   OnShow  := FormShow;
   OnClose := FormClose;

   FStore := TRadioConfigStore.Create;
   FKeyerStore := TKeyerConfigStore.Create;
   FUDPConfig := TUDPBroadcastConfig.Create;
   SelectFirstSection;
   LogPhase(FTiming, 'SelectFirstSection');
   LoadStore;
   LogPhase(FTiming, 'LoadStore');
   RefreshAll;
   LogPhase(FTiming, 'RefreshAll');

   // AFTER the form is populated, so that loading cannot mark it dirty even if
   // a future Load routine forgets to set FLoading.  Belt and braces on purpose:
   // the cost of getting this wrong is a save prompt on an untouched window.
   HookDirtyMarkers(Self);
   LogPhase(FTiming, 'HookDirtyMarkers');

   // Through the SETTER, so the button starts greyed.  A freshly opened window
   // has nothing unsaved, but the designer leaves every button enabled, and
   // FDirty being False by default would never say so.
   Dirty := False;
end;

// The nav sections are DESIGNED, not built here -- add one in the IDE, set its
// Tag, and wire it.  That is only possible because the section is identified by
// Tag: TComponent.Tag is PUBLISHED, so it streams and appears in the Object
// Inspector, whereas TWinControl.TagString is public and can do neither.  The
// first version of this form keyed the nav off TagString and so had to build the
// items in code and Clear them on every construction -- which silently threw
// away anything added in the designer (NY4I found it that way, 2026-08-06).
//
// The old code also compared TagString against the CAPTION constant, so
// translating the nav would have broken section switching.  A Tag cannot be
// translated, which is the point.
procedure TPrefsForm.SelectFirstSection;
var
   wanted: TTreeNode;
begin
   // Chevrons before the selection, so the tree is already drawing the way it
   // will keep drawing when the operator first sees it.
   ApplyChevrons;

   // Selecting fires tvNavChange, which shows the matching panel.  Done here
   // rather than by streaming a selection from the .fmx: OnChange would then
   // fire part-way through loading the form, with the panels it switches not
   // yet streamed in.
   //
   // HARDWARE by tag, not the first row.  Opening on whatever happens to be top
   // of the tree would show the operator the "not migrated yet" placeholder as
   // their first impression of Preferences -- and it would change again the next
   // time the nav is reordered in the designer.
   //
   // GlobalCount / ItemByGlobalIndex, NOT Count / Items[].  On a TTreeView those
   // are different sets: Count is Content.ControlsCount -- ROOT ITEMS ONLY --
   // while GlobalCount walks the whole tree.  Since External Software now has
   // children, the root-only form would silently fail to find any child section
   // by tag, and the failure would look like "that section just doesn't open".
   // Read from ComCtrls rather than assumed.
   // ForEachNavItem, not GlobalCount: with the tree starting COLLAPSED the
   // global list stops at a collapsed parent, so a section that lives under one
   // could not be found by tag at all.  Hardware is a root item today and would
   // survive either way -- but "the default section happens to be at the root"
   // is not something to depend on, and the next default might not be.
   FNavWanted := nil;
   ForEachNavItem(NoteRadiosNavItem);
   wanted := FNavWanted;

   if wanted <> nil then
      begin
      tvNav.Selected := wanted;
      Exit;
      end;

   // No Hardware row at all: fall back to the first, so the window is never
   // left with nothing selected.
   if tvNav.Items.TopLvlCount > 0 then
      begin
      tvNav.Selected := tvNav.Items.TopLvlItems[0];
      end;
end;

destructor TPrefsForm.Destroy;
begin
   FreeAndNil(FBindings);
   FreeAndNil(FEditClone);
   FreeAndNil(FKeyerEditClone);
   FreeAndNil(FUDPEditClone);
   FreeAndNil(FKeyerStore);
   FreeAndNil(FStore);
   FreeAndNil(FUDPConfig);
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
   udp: TUDPBroadcastConfig;
   err: string;
begin
   // 0. The UDP settings, through the SAME call startup uses.  That function
   //    reads the JSON section when it is there and seeds from the operator's
   //    tr4w.ini when it is not, so the dialog and startup cannot disagree
   //    about what is configured -- which they would the moment either grew its
   //    own copy of the fall-back rule.
   udp := LoadUDPForStartup(StoreFileName, SettingsDirectory + 'tr4w.ini');
   try
      FUDPConfig.Assign(udp);
   finally
      udp.Free;
   end;

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
var
   tciPort: integer;
   bindErrors: string;
begin
   Result := FStore.Validate(aError);
   if not Result then
      begin
      Exit;
      end;
   // REPORTED HERE, once, and all of them together: a panel of thirty settings
   // that showed one problem per visit would take thirty visits to correct.
   // The accepted values were already applied as they were typed.
   if FBindings <> nil then
      begin
      if not FBindings.SaveAll(bindErrors) then
         begin
         ShowMessage('These entries were not accepted and have not been saved:'
                     + sLineBreak + sLineBreak + bindErrors);
         end;
      end;

   // The UDP settings are validated on the SAME footing as the radio library,
   // and before anything is written: a duplicated endpoint or a row carrying
   // nothing is refused here rather than discovered as silence on the wire.
   Result := FUDPConfig.Validate(aError);
   if not Result then
      begin
      Exit;
      end;

   try
      // Every library in one atomic write -- see uTR4WConfigFile.
      SaveConfig(StoreFileName, FStore, FKeyerStore, FUDPConfig);

      // HERE, not in the two ApplyNow call sites.  The broadcaster's settings
      // and the file must change together: a save that did not reconfigure
      // would leave the operator's new destination stored but not broadcasting
      // until a restart, and "it only works after I restart TR4W" is a bug
      // report nobody can act on.  Configure takes a COPY, so the working copy
      // stays the dialog's.  (The radios need an explicit Activate because
      // restarting them mid-contest is a real cost; a UDP destination has none.)
      UDPBroadcaster.Configure(FUDPConfig);

      // Rotators rebuilt on save, for the same reason the TCI server is
      // started and stopped here: a library the operator just edited that does
      // not take effect until a restart is a settings screen that lies.
      uRotatorControl.ConfigureRotators(FStore);

      // The TCI server, on the same footing and for the same reason.  It was
      // originally started only from tr4w.dpr, which reproduced the exact
      // uWSJTX trap this project already knows about: the enable flag was
      // read once at startup, so ticking the box did nothing until the next
      // launch and the operator had no way to tell that from a broken server.
      // A listening socket costs nothing to start or stop, unlike restarting
      // the radios -- which is why THOSE still need an explicit Activate.
      // Debug and MaxTxSeconds live in the store now, not in tr4w.ini, but the
      // server reads them from GLOBALS at the point of use.  Publishing here --
      // in the apply layer rather than in the store -- keeps uRadioConfigStore's
      // uses clause pure RTL so uTestRadioConfigStore can go on linking it
      // standalone.  Unconditional, and before the start/stop below, so a debug
      // flag ticked in the same visit is already in force for the very first
      // message the server logs.
      TR4W_TCI_DEBUG          := FStore.TCIDebug;
      TR4W_TCI_MAX_TX_SECONDS := FStore.TCIMaxTxSeconds;

      if TCIServer <> nil then
         begin
         if FStore.TCIServerEnabled and (not TCIServer.Active) then
            begin
            // 0 in the store means "whatever the server calls default", so the
            // number 50001 is written down in exactly one place.
            tciPort := FStore.TCIPort;
            if tciPort <= 0 then
               begin
               tciPort := TCI_SERVER_DEFAULT_PORT;
               end;

            if not TCIServer.Start(tciPort, FStore.TCIBindAll) then
               begin
               // Reported, not swallowed.  A port already in use is the
               // common case and the operator cannot diagnose silence.
               ShowMessage(Format('The TCI server could not open port %d: %s',
                                  [tciPort, TCIServer.LastError]));
               end;
            end
         else if (not FStore.TCIServerEnabled) and TCIServer.Active then
            begin
            TCIServer.Stop;
            end;
         end;
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
      Result := FStore.FindRadio(SelectedListTag(lstRadios));
      end;
end;

procedure TPrefsForm.RefreshRadioList;
var
   i, keep: integer;
begin
   keep := lstRadios.ItemIndex;
   ClearListItems(lstRadios);
   for i := 0 to FStore.RadioCount - 1 do
      begin
      AddListItem(lstRadios, FStore.Radio(i).DisplaySummary,
                  FStore.Radio(i).Name);
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
         // THE ROW STILL SAYS SO, IT IS JUST NOT GREYED.  FMX let an item be
         // Enabled := False; an LCL combo holds plain strings and has no
         // per-item enable.  No enforcement is lost: FMX's greying never
         // enforced anything either -- ItemByPoint tests only Visible, so a
         // greyed item was still selectable, and the actual refusal has always
         // lived in the OnChange handler.  What is lost is the visual cue, and
         // the caption carries that (TC_PREFS_RADIOINUSE names the other slot).
         shown := Format(TC_PREFS_RADIOINUSE, [name, aOtherSlotLabel]);
         AddComboItem(aCombo, shown, name);
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
begin
   keep := lstKeyers.ItemIndex;
   ClearListItems(lstKeyers);
   for i := 0 to FKeyerStore.KeyerCount - 1 do
      begin
      AddListItem(lstKeyers, FKeyerStore.Keyer(i).DisplaySummary,
                  FKeyerStore.Keyer(i).Name);
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
      Result := FKeyerStore.FindKeyer(SelectedListTag(lstKeyers));
      end;
end;

procedure TPrefsForm.btnAddKeyerClick(Sender: TObject);
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

procedure TPrefsForm.btnEditKeyerClick(Sender: TObject);
begin
   EditSelectedKeyer;
end;

procedure TPrefsForm.EditSelectedKeyer;
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

procedure TPrefsForm.btnDuplicateKeyerClick(Sender: TObject);
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

procedure TPrefsForm.btnRemoveKeyerClick(Sender: TObject);
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

procedure TPrefsForm.lstKeyersDblClick(Sender: TObject);
begin
   EditSelectedKeyer;
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
         chkSpeedSync1.Checked := False;
         chkSpeedSync2.Checked := False;
         chkSO2R.Checked  := False;
         end
      else
         begin
         FillRadioNameCombo(cbxRadio1, prof.Radio1Name, prof.Radio2Name, TC_PREFS_RADIO2);
         FillRadioNameCombo(cbxRadio2, prof.Radio2Name, prof.Radio1Name, TC_PREFS_RADIO1);
         FillCWOutputCombo(cbxCW1, prof.CWOutput1, prof.Radio1Name);
         FillCWOutputCombo(cbxCW2, prof.CWOutput2, prof.Radio2Name);
         chkSpeedSync1.Checked := prof.SpeedSync1;
         chkSpeedSync2.Checked := prof.SpeedSync2;
         chkSO2R.Checked  := prof.SO2REnabled;
         end;

      // RESTARTED HERE.  FTiming is a field, so between one refresh and the next
      // it keeps running -- and the first phase logged afterwards then reports
      // however long the operator sat looking at the window.  It read a
      // convincing "profile combos 4138 ms" that way on the first run, which is
      // exactly the sort of number that sends someone optimising nothing.
      FTiming := TStopwatch.StartNew;

      chkAutoConnect.Checked := FStore.AutoConnectOnStartup;
      LogPhase(FTiming, '  profile combos');
      LoadStationPanel;
      LogPhase(FTiming, '  Station');
      LoadExternalSoftwarePanels;
      LogPhase(FTiming, '  External software');
      LoadClusterPanels;
      LogPhase(FTiming, '  Cluster panels');
      LoadRemainingPanels;
      LogPhase(FTiming, '  Remaining panels');
      LoadRotatorList;
      LogPhase(FTiming, '  Rotators (COM enum)');
      LoadClusterList;
      LogPhase(FTiming, '  Cluster list (DAT)');
      BuildBindings;
      FBindings.LoadAll;
      LogPhase(FTiming, '  Bindings');
      LoadTCIPanel;
      LoadLoggingPanel;
      LogPhase(FTiming, '  TCI + Logging');

      if FStore.ActiveProfileName <> '' then
         begin
         lblActive.Caption := TC_PREFS_ACTIVELABEL + FStore.ActiveProfileName;
         end
      else
         begin
         lblActive.Caption := TC_PREFS_ACTIVELABEL + TC_PREFS_NONE;
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
   RefreshUDPList;
end;

// "Save" is the only button whose effect is invisible: nothing on screen moves
// when it is pressed, so it reads as a no-op and the whole Save / Save-and-close
// / Cancel set starts to look redundant (NY4I, 2026-08-08).  Greying it when
// there is nothing to commit gives it a visible meaning -- enabled says "there
// are unsaved changes", greyed says "everything here is on disk".
{ ------------------------------------------------- the blanket dirty flag --- }

// WHY THIS IS ATTACHED IN CODE and not ninety designer assignments.
//
// Marking the form dirty is a CROSS-CUTTING concern: every control does the
// same thing, so ninety identical one-line handlers would be ninety chances to
// forget the ninety-first.  It had already gone wrong -- on 2026-08-11 exactly
// 100 of the 147 interactive controls on this form had no event at all, so
// Save stayed greyed while the operator typed and, worse, closing with the X
// discarded the work WITHOUT the unsaved-changes prompt, because that prompt is
// gated on FDirty (NY4I).
//
// Attaching by a walk means a control dropped on this form in the designer
// tomorrow is covered without anyone remembering this file exists.  That is the
// property worth having; a table of control names would rot the same way.
//
// NOT the same thing as an event handler with behaviour.  The house rule --
// one named handler per control, never branch on Sender -- is about handlers
// that DO something specific; this one does the identical thing for every
// control and never asks who Sender is.
//
// EXISTING HANDLERS ARE NEVER REPLACED.  A control the designer already wired
// keeps its handler, which is responsible for its own Dirty (the cluster and
// rotator captures set it centrally, in Capture*Selected).
procedure TPrefsForm.MarkDirty(Sender: TObject);
begin
   // Loading is not editing.  Without this, populating the form would arm the
   // unsaved-changes prompt on a window nobody has touched -- and DiscardChanges
   // would leave the form dirty immediately after discarding.
   if FLoading then
      begin
      Exit;
      end;

   Dirty := True;
end;

procedure TPrefsForm.HookDirtyMarker(const aControl: TWinControl);
begin
   // OnChange for edits.  Under FMX this had to be OnChangeTracking, because
   // there OnChange fired on the validate/commit path -- effectively when the
   // field was left -- and a Save button that only un-greys once you tab out
   // reads as a bug.  The LCL has no OnChangeTracking and does not need one:
   // TCustomEdit.Change is raised from the widgetset's EN_CHANGE, so OnChange
   // IS the per-keystroke event here.  Read from StdCtrls, not assumed.
   if aControl is TCustomEdit then
      begin
      if not Assigned(TCustomEdit(aControl).OnChange) then
         begin
         TCustomEdit(aControl).OnChange := MarkDirty;
         end;
      Exit;
      end;

   // TComboBox is NOT a TCustomEdit descendant -- it comes down through
   // TComboEditBase -- so it needs its own arm rather than being caught above.
   if aControl is TComboBox then
      begin
      if not Assigned(TComboBox(aControl).OnChange) then
         begin
         TComboBox(aControl).OnChange := MarkDirty;
         end;
      Exit;
      end;

   // TComboBox, not TCustomComboBox: the base declares OnChange PROTECTED and
   // only the concrete class publishes it, so the base-class form does not
   // compile.  A descendant of TComboBox is still caught by the `is` test.
   if aControl is TComboBox then
      begin
      if not Assigned(TComboBox(aControl).OnChange) then
         begin
         TComboBox(aControl).OnChange := MarkDirty;
         end;
      Exit;
      end;

   if aControl is TCheckBox then
      begin
      if not Assigned(TCheckBox(aControl).OnChange) then
         begin
         TCheckBox(aControl).OnChange := MarkDirty;
         end;
      Exit;
      end;

   if aControl is TRadioButton then
      begin
      if not Assigned(TRadioButton(aControl).OnChange) then
         begin
         TRadioButton(aControl).OnChange := MarkDirty;
         end;
      Exit;
      end;

   // DELIBERATELY NOT LISTS OR THE TREE.  Selecting a different cluster, keyer
   // or nav section is navigation, not an edit; marking those dirty would make
   // simply LOOKING at the window prompt to save on the way out, which trains
   // the operator to dismiss the prompt that matters.
   //
   // ADDING A CONTROL TYPE: add an arm here.  Missing one costs a greyed Save
   // button, not data -- the Save* routines read their controls directly at save
   // time -- but it is still the silent-gap shape this whole change is about.
end;

procedure TPrefsForm.HookDirtyMarkers(const aRoot: TWinControl);
var
   i: integer;
begin
   if aRoot = nil then
      begin
      Exit;
      end;

   for i := 0 to aRoot.ControlCount - 1 do
      begin
      // GUARDED, unlike the FMX original: there every child was a TFmxObject,
      // but an LCL container also holds TGraphicControls (labels, shapes) which
      // are not TWinControl and carry none of the events hooked below.
      if aRoot.Controls[i] is TWinControl then
         begin
         HookDirtyMarker(TWinControl(aRoot.Controls[i]));
         // Recursive: every control on this form is nested at least two deep,
         // inside its section panel inside layContent.
         HookDirtyMarkers(TWinControl(aRoot.Controls[i]));
         end;
      end;
end;

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
   ignoredErrors: string;
begin
   if FLoading then
      begin
      Exit;
      end;

   FStore.AutoConnectOnStartup := chkAutoConnect.Checked;
   SaveStationPanel;
   SaveExternalSoftwarePanels;
   SaveClusterPanels;
   SaveRemainingPanels;

   // QUIETLY here.  This runs on every change -- every keystroke in an edit --
   // so a refusal is expected mid-typing: "5" on the way to "50" is genuinely
   // out of range for a moment.  Reporting it here would pop a dialog while the
   // operator is still typing.  The accepted values apply as they are typed;
   // the refusals are reported ONCE, on the explicit save, in SaveStore.
   if FBindings <> nil then
      begin
      FBindings.SaveAll(ignoredErrors);
      end;
   SaveTCIPanel;
   SaveLoggingPanel;


   prof := CurrentProfile;
   if prof = nil then
      begin
      Exit;
      end;

   prof.Radio1Name  := SelectedTag(cbxRadio1);
   prof.Radio2Name  := SelectedTag(cbxRadio2);
   prof.CWOutput1   := SelectedTag(cbxCW1);
   prof.CWOutput2   := SelectedTag(cbxCW2);
   prof.SpeedSync1  := chkSpeedSync1.Checked;
   prof.SpeedSync2  := chkSpeedSync2.Checked;
   prof.SO2REnabled := chkSO2R.Checked;

   Dirty := True;
end;

{ -------------------------------------------------------------- events ---- }

procedure TPrefsForm.tvNavChange(Sender: TObject);
var
   i: integer;
   wanted: NativeInt;
   shown: boolean;
   panel: TControl;
begin
   // Guarded because this is wired in the resource: streaming can activate a
   // selection before the panels it switches have themselves been read in.
   if (layRadios = nil) or (lblPlaceholder = nil) then
      begin
      Exit;
      end;

   // Identified by TAG, not by caption.  The previous version compared the
   // item's TagString against TC_PREFS_HARDWARE -- the caption constant -- so
   // translating the nav would have stopped section switching from working, and
   // the coupling was invisible.  A Tag survives translation, and being
   // published it can be set in the Object Inspector on a section added there.
   // Selected, not an index: on a tree the selection can be a CHILD, and there
   // is no single index that addresses both levels.
   wanted := NAV_NONE;
   if tvNav.Selected <> nil then
      begin
      wanted := NavTagOf(tvNav.Selected);
      end;

   // A SECTION PANEL IS ANY CHILD OF layContent WHOSE TAG MATCHES.  No case
   // statement and no tag-to-panel table: adding a section is designer work
   // only -- drop a layout in layContent, give it the same Tag as its nav item,
   // and it appears.  Nothing here needs to know the section exists.
   //
   // Tag 0 is skipped, which is what keeps the placeholder (and any future
   // untagged decoration) out of the rotation.  See the NAV_ constants.
   shown := False;
   for i := 0 to layContent.ControlCount - 1 do
      begin
      if layContent.Controls[i] is TControl then
         begin
         panel := layContent.Controls[i];
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

   // The cluster directory is NOT built here.  Opening the section was already
   // far better than building it on every refresh -- 1864 ms measured, once --
   // but a section that pauses when you click it still reads as a slow program.
   // It is built from the drop-down instead; see cbxClusterServerPopup.
end;

procedure TPrefsForm.btnAddClick(Sender: TObject);
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

procedure TPrefsForm.btnEditClick(Sender: TObject);
begin
   EditSelectedRadio;
end;

procedure TPrefsForm.EditSelectedRadio;
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

procedure TPrefsForm.lstRadiosDblClick(Sender: TObject);
begin
   EditSelectedRadio;
end;

procedure TPrefsForm.btnDuplicateClick(Sender: TObject);
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

procedure TPrefsForm.btnRemoveClick(Sender: TObject);
var
   radio: TRadioDefinition;
   err: string;
begin
   radio := SelectedRadio;
   if radio = nil then
      begin
      Exit;
      end;

   if MessageBoxA(Self.Handle,
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

procedure TPrefsForm.btnNewProfileClick(Sender: TObject);
var
   prof: TStationProfile;
   name: string;
   err: string;
begin
   name := '';
   if not AskForText(TC_PREFS_PROFILES, TC_PREFS_NEWPROFILE, name) then
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

procedure TPrefsForm.btnRenameProfileClick(Sender: TObject);
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
   if not AskForText(TC_PREFS_PROFILES, TC_PREFS_RENAMEPROFILE, name) then
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

procedure TPrefsForm.btnDeleteProfileClick(Sender: TObject);
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

procedure TPrefsForm.cbxProfileChange(Sender: TObject);
begin
   if FLoading then
      begin
      Exit;
      end;
   RefreshProfileFields;
end;

// Six controls, six handlers, one line each.  They used to share one
// HandleFieldChange; it never looked at Sender, so sharing was SAFE -- but it
// was one control's handler wearing six controls' hats, and the Object
// Inspector gave no hint that retyping it on one would change all six.
procedure TPrefsForm.cbxCW1Change(Sender: TObject);
begin
   CaptureProfileFields;
end;

procedure TPrefsForm.cbxCW2Change(Sender: TObject);
begin
   CaptureProfileFields;
end;

procedure TPrefsForm.chkSpeedSync1Change(Sender: TObject);
begin
   CaptureProfileFields;
end;

procedure TPrefsForm.chkSpeedSync2Change(Sender: TObject);
begin
   CaptureProfileFields;
end;

procedure TPrefsForm.chkSO2RChange(Sender: TObject);
begin
   CaptureProfileFields;
end;

procedure TPrefsForm.chkAutoConnectChange(Sender: TObject);
begin
   CaptureProfileFields;
end;

procedure TPrefsForm.chkTCIServerChange(Sender: TObject);
begin
   CaptureProfileFields;
end;


{ --------------------------------------------------------------- Logging --- }


{ ------------------------------------------------------------ TCI Server --- }


{ ------------------------------------------------------------- chevrons ---- }

// ApplyChevronToItem WAS HERE AND IS NOT PORTED.  It was 86 lines of
// hand-restyling: FMX's Win10Modern style draws a TTreeNode expander as
// two filled 7x7 triangles, where Windows Explorer -- and everyone's
// expectation of a tree -- uses a stroked chevron, so the routine walked each
// item's children, found the TPath objects and rewrote their Data, Fill and
// Stroke.
//
// The LCL's TTreeView is the native Windows control and draws Explorer's
// expander itself.  The defect being worked around does not exist here, so
// the workaround does not come with us.  This is the FIRST thing the port has
// deleted rather than translated, and it will not be the last: some of what
// these forms do is compensation for FMX, not behaviour TR4W wants.

procedure TPrefsForm.NoteRadiosNavItem(item: TTreeNode);
begin
   // FIRST match wins, so a later item with the same tag cannot displace it.
   if (FNavWanted = nil) and (NavTagOf(item) = NAV_RADIOS) then
      begin
      FNavWanted := item;
      end;
end;

procedure TPrefsForm.BuildNavTree;
begin
   // BUILT IN CODE, not streamed.  An LCL TTreeNode is not a component, so
   // unlike FMX the 27 items cannot live in the form resource.  Tags are
   // reproduced EXACTLY as the designer had them -- the panel dispatch keys
   // off Tag and Lint-FormTags gates it, so renumbering would silently point
   // every menu entry at the wrong page.
   tvNav.Items.BeginUpdate;
   try
      tvNav.Items.Clear;

      navStation := tvNav.Items.Add(nil, 'Station');
      TNavNode(navStation).Tag := 1;
      navHardware := tvNav.Items.Add(nil, 'Hardware');
      TNavNode(navHardware).Tag := 2;
      navRadios := tvNav.Items.AddChild(navHardware, 'Radios');
      TNavNode(navRadios).Tag := 26;
      navRotators := tvNav.Items.AddChild(navHardware, 'Rotators');
      TNavNode(navRotators).Tag := 27;
      navCluster := tvNav.Items.Add(nil, 'DX Cluster');
      TNavNode(navCluster).Tag := 3;
      navOperating := tvNav.Items.Add(nil, 'Operating');
      TNavNode(navOperating).Tag := 21;
      navBandMap := tvNav.Items.AddChild(navOperating, 'Band Map');
      TNavNode(navBandMap).Tag := 20;
      navBands := tvNav.Items.AddChild(navOperating, 'Bands');
      TNavNode(navBands).Tag := 24;
      navOperatingCW := tvNav.Items.AddChild(navOperating, 'CW');
      TNavNode(navOperatingCW).Tag := 23;
      navOnlineScoring := tvNav.Items.AddChild(navOperating, 'Online Scoring');
      TNavNode(navOnlineScoring).Tag := 22;
      navTwoRadio := tvNav.Items.AddChild(navOperating, 'Two Radio Mode');
      TNavNode(navTwoRadio).Tag := 25;
      navSCP := tvNav.Items.Add(nil, 'SCP');
      TNavNode(navSCP).Tag := 4;
      navUDPBroadcast := tvNav.Items.Add(nil, 'UDP Broadcast');
      TNavNode(navUDPBroadcast).Tag := 5;
      navNetwork := tvNav.Items.Add(nil, 'Network');
      TNavNode(navNetwork).Tag := 6;
      navAppearance := tvNav.Items.Add(nil, 'Appearance');
      TNavNode(navAppearance).Tag := 7;
      navLogging := tvNav.Items.Add(nil, 'Logging');
      TNavNode(navLogging).Tag := 8;
      navBackup := tvNav.Items.Add(nil, 'Backup');
      TNavNode(navBackup).Tag := 9;
      navContest := tvNav.Items.Add(nil, 'Contest');
      TNavNode(navContest).Tag := 10;
      navCW := tvNav.Items.Add(nil, 'CW Settings');
      TNavNode(navCW).Tag := 11;
      navWebServer := tvNav.Items.Add(nil, 'Web Server');
      TNavNode(navWebServer).Tag := 12;
      navTCIServer := tvNav.Items.Add(nil, 'TCI Server');
      TNavNode(navTCIServer).Tag := 15;
      navExternalSoftware := tvNav.Items.Add(nil, 'External Software');
      TNavNode(navExternalSoftware).Tag := 13;
      navWSJTX := tvNav.Items.AddChild(navExternalSoftware, 'WSJT-X');
      TNavNode(navWSJTX).Tag := 16;
      navExternalLogger := tvNav.Items.AddChild(navExternalSoftware, 'External Logger');
      TNavNode(navExternalLogger).Tag := 17;
      navDXLab := tvNav.Items.AddChild(navExternalSoftware, 'DXLab');
      TNavNode(navDXLab).Tag := 18;
      navMMTTY := tvNav.Items.AddChild(navExternalSoftware, 'MMTTY');
      TNavNode(navMMTTY).Tag := 19;
      navAdvanced := tvNav.Items.Add(nil, 'Advanced');
      TNavNode(navAdvanced).Tag := 14;

      // Collapsed at open, as the designed form was: an operator looking for
      // one setting should not be handed 27 lines.
      tvNav.FullCollapse;
   finally
      tvNav.Items.EndUpdate;
   end;
end;

procedure TPrefsForm.ForEachNavItem(const aVisit: TNavItemVisit);

   procedure Walk(const aItem: TTreeNode);
   var
      i: integer;
   begin
      aVisit(aItem);
      for i := 0 to aItem.Count - 1 do
         begin
         Walk(aItem.Items[i]);
         end;
   end;

var
   i: integer;
begin
   // RECURSIVE, AND DELIBERATELY NOT GlobalCount.
   //
   // TCustomTreeView.UpdateGlobalIndexes recurses into an item's children only
   // `if AItem.IsExpanded` (FMX.TreeView.pas:1582), so the global list STOPS AT
   // A COLLAPSED PARENT.  With the tree now starting collapsed, a GlobalCount
   // walk would never visit the children -- and the two things this walk does,
   // the chevron and CustomChildrenOffset, are needed by exactly those items.
   // The indent defect would have come straight back, and only for operators
   // who expanded a node, which is the worst kind of intermittent.
   // TOP-LEVEL nodes, then recurse.  The LCL tree exposes its roots through
   // Items.TopLvlItems; Items.Count would be every node at every depth and
   // would visit each child twice.
   for i := 0 to tvNav.Items.TopLvlCount - 1 do
      begin
      Walk(tvNav.Items.TopLvlItems[i]);
      end;
end;

procedure TPrefsForm.ApplyChevrons;
begin
   // Every item, collapsed parents included -- see ForEachNavItem.
end;


{ ------------------------------------------------------------- Station ----- }

function TPrefsForm.StationFields: TArray<TStationField>;
begin
   Result := [
      // Station identity
      MakeStationField('MY CALL',         edtMyCall),
      MakeStationField('MY NAME',         edtMyName),
      MakeStationField('MY GRID',         edtMyGrid),
      MakeStationField('MY ZONE',         edtMyZone),
      MakeStationField('MY ITU ZONE',     edtMyITUZone),
      // ONE control for MY STATE.  'MY QTH' is the SAME GLOBAL (@MyState) -- a
      // back-compat alias, like ICOM NETWORK USERNAME.  Two boxes would let
      // editing one silently change the other.  The alias row stays in CFGCA so
      // existing config files and multi-op peers keep working.
      MakeStationField('MY STATE',        edtMyState),
      MakeStationField('MY SECTION',      edtMySection),
      MakeStationField('MY COUNTRY',      edtMyCountry),
      MakeStationField('MY POSTAL CODE',  edtMyPostalCode),

      // Contest exchange
      MakeStationField('MY CHECK',        edtMyCheck),
      MakeStationField('MY PREC',         edtMyPrec),
      MakeStationField('MY FD CLASS',     edtMyFDClass),
      MakeStationField('MY FOC NUMBER',   edtMyFOCNumber),
      MakeStationField('MY IOTA',         edtMyIOTA),
      MakeStationField('MY PARK',         edtMyPark)
   ];
end;

function TPrefsForm.MakeStationField(const aCommand: string;
                                     const aEdit: TEdit): TStationField;
begin
   Result.Command := aCommand;
   Result.Edit    := aEdit;
end;


{ ---------------------------------------------------- External Software ---- }

// Boolean CFGCA rows are text: BA[] is the table CheckCommand itself matches
// against, so reading and writing through it means the two cannot disagree
// about how TRUE is spelled.
function TPrefsForm.CommandBool(const aCommand: string): boolean;
begin
   Result := SameText(Trim(FStore.CommandValue(aCommand,
                           CFGCommandValueAsString(aCommand))), string(BA[True]));
end;

function TPrefsForm.SetCommandBool(const aCommand: string; const aValue: boolean): boolean;
begin
   Result := ApplyAndStoreCommand(FStore, aCommand, string(BA[aValue]));
end;


{ --------------------------------------------- DX cluster and band map ----- }


{ ------------------------------ SCP, network, appearance, backup ----------- }


procedure TPrefsForm.FillFromAllowedValues(const aCombo: TComboBox;
                                           const aCommand: string);
var
   v: string;
   current: string;
begin
   // Filled from CFGCA's own allow-list, never typed into the designer -- a
   // populated combo bakes itself into the .fmx resource, so a hand-entered
   // list becomes a permanent second copy that keeps working while it drifts
   // from the values the program actually accepts.
   current := FStore.CommandValue(aCommand, CFGCommandValueAsString(aCommand));

   aCombo.Items.BeginUpdate;
   try
      aCombo.Clear;
      for v in CFGCommandAllowedValues(aCommand) do
         begin
         aCombo.Items.Add(v);
         end;
   finally
      aCombo.Items.EndUpdate;
   end;

   aCombo.ItemIndex := aCombo.Items.IndexOf(Trim(current));
end;

procedure TPrefsForm.BuildBindings;
begin
   // DECLARED ONCE, HERE, AND NOWHERE ELSE.  Each line says which control edits
   // which setting; load, save, validation, allow-lists and the
   // drop-down-versus-text-box decision all follow from the setting.  There is
   // deliberately no per-field code below this -- that is the whole point, and
   // the reason the older panels above still have hand-written Load/Save pairs
   // is only that they were written before this existed.
   DeclareAllSettings;

   FreeAndNil(FBindings);
   FBindings := TSettingBindings.Create;

   // Operating - CW
   FBindings.Bind(chkSayHiEnable,       'operating.cw.sayHi');
   FBindings.Bind(edtSayHiCutoff,       'operating.cw.sayHiRateCutoff');
   FBindings.Bind(chkKeypadCWMemories,  'operating.cw.keypadMemories');
   FBindings.Bind(cbxLeadingZeros,      'operating.cw.leadingZeros');
   FBindings.Bind(edtLeadingZeroChar,   'operating.cw.leadingZeroChar');
   FBindings.Bind(cbxDitDah,            'operating.cw.serial.ditDahRatio');
   FBindings.Bind(edtWeight,            'operating.cw.serial.weight');
   FBindings.Bind(chkFarnsworth,        'operating.cw.serial.farnsworth');
   FBindings.Bind(edtFarnsworthSpeed,   'operating.cw.serial.farnsworthSpeed');

   // CW Settings
   FBindings.Bind(chkCWEnable,             'cw.enable');
   FBindings.Bind(chkCWSpeedFromDatabase,  'cw.speedFromDatabase');
   FBindings.Bind(cbxCWSpeedIncrement,     'cw.speedIncrement');
   FBindings.Bind(edtCWTone,               'cw.tone');

   // Operating - Bands
   FBindings.Bind(chkHFBands,   'operating.bands.hf');
   FBindings.Bind(chkWARCBands, 'operating.bands.warc');
   FBindings.Bind(chkVHFBands,  'operating.bands.vhf');

   // Operating - Two radio
   FBindings.Bind(chkTwoRadioMode,    'operating.tworadio.enable');
   FBindings.Bind(chkAltDBuffer,      'operating.tworadio.altDBuffer');
   FBindings.Bind(chkAltDCQ,          'operating.tworadio.altDCQ');
   FBindings.Bind(chkAlwaysBlindCQ,   'operating.tworadio.blindCQ');
   FBindings.Bind(chkSkipActiveBand,  'operating.tworadio.skipActiveBand');

   // Operating - Online scoring
   FBindings.Bind(chkHamScoreEnable,  'scoring.hamscore.enable');
   FBindings.Bind(edtHamScoreURL,     'scoring.hamscore.url');
   FBindings.Bind(edtHamScoreUser,    'scoring.hamscore.username');
   FBindings.Bind(edtHamScorePass,    'scoring.hamscore.password');
   FBindings.Bind(chkHamScoreContact, 'scoring.hamscore.contactInfo');
   FBindings.Bind(edtScorePostURL,    'scoring.board.postingUrl');
   FBindings.Bind(edtScoreReadURL,    'scoring.board.readingUrl');

   // DX cluster
   FBindings.Bind(chkClusterAtStartup, 'cluster.connectAtStartup');
   FBindings.Bind(edtClusterCommand,   'cluster.connectCommand');
end;


{ ------------------------------------------------------------ Rotators ----- }


{ ---------------------------------------------------------- DX clusters --- }

procedure TPrefsForm.LoadClusterServerList;
var
   fileName: string;
   lines: TStringList;
   i: integer;
   line: string;
   sw: TStopwatch;
begin
   // THE PUBLIC DIRECTORY, offered as a picker.  TRCLUSTER.DAT is ~15 KB of
   // host:port lines that ship with TR4W -- it is not the operator's list, it
   // is the list they choose FROM.  Their own servers, with credentials, are
   // the library above.
   //
   // Editable, not a closed list: a club or a private node will not be in the
   // file, and refusing to accept one would make the picker a cage.
   //
   // ONCE PER PROGRAM RUN, AND NOT BEFORE IT IS LOOKED AT.  Measured 2026-08-11:
   // 726 entries cost 1.8 SECONDS, because FMX builds a styled list item per
   // entry.  It was being paid twice on every load -- RefreshProfileCombo fires
   // the profile OnChange, which re-enters RefreshProfileFields -- and a load
   // happens on construction AND inside DiscardChanges, so opening Preferences
   // cost 3.9 s and cancelling out of it cost another 3.6 s (NY4I felt both).
   //
   // The guard is correct rather than merely cheap: the file is read-only data
   // shipped with the program, so it cannot change while TR4W is running, and
   // rebuilding an identical list can only ever cost time.  The one caller that
   // legitimately wants it fresh is a hypothetical "reload the directory"
   // action, which would clear the flag.
   if FClusterServersLoaded then
      begin
      Exit;
      end;
   FClusterServersLoaded := True;
   sw := TStopwatch.StartNew;

   // THE WAIT CURSOR, for the one operation on this form that visibly takes
   // time.  Nearly two seconds of frozen UI with no acknowledgement reads as a
   // hang, and the operator's instinct is to click again -- which on a combo
   // means a second DropDown arriving while the first is still building.
   //
   // WIN32 SetCursor, NOT the FMX Cursor property, and the difference is the
   // whole point.  Assigning Cursor asks FMX to apply the change on the next
   // WM_SETCURSOR -- but this routine then blocks the UI thread outright, so no
   // message is pumped, the change is never applied, and it has already been
   // restored by the time one is.  Setting Cursor := crHourGlass here produced
   // no visible indication at all (NY4I, 2026-08-11).
   //
   // SetCursor takes effect immediately, and it STAYS for exactly the same
   // reason the property does not: nothing is pumping the messages that would
   // reset it. That makes the blocked thread work in our favour rather than
   // against us. Windows restores the cursor naturally on the first
   // WM_SETCURSOR after we return.
   SetCursor(LoadCursor(0, IDC_WAIT));
   cbxClusterServer.Items.BeginUpdate;
   try
      cbxClusterServer.Clear;

      fileName := ExtractFilePath(ParamStr(0)) + 'TRCLUSTER.DAT';
      if FileTextExists(fileName) then
         begin
         lines := TStringList.Create;
         try
            lines.LoadFromFile(fileName);
            for i := 0 to lines.Count - 1 do
               begin
               line := Trim(lines[i]);
               // Skip blanks and anything that looks like a comment.  The file
               // is hand-maintained and has picked up both over the years.
               if (line <> '') and (line[1] <> ';') and (line[1] <> '#') then
                  begin
                  cbxClusterServer.Items.Add(line);
                  end;
               end;
         finally
            lines.Free;
         end;
         end;
   finally
      cbxClusterServer.Items.EndUpdate;
      // In the finally: a directory file that throws mid-load must not leave the
      // operator with a permanent hourglass on a window that is working fine.
      SetCursor(LoadCursor(0, IDC_ARROW));
   end;

   // Info, and it names the count: this is the one remaining pause an operator
   // can feel, it happens once, and the number tells the next reader whether it
   // is the file that grew or FMX that got slower.
   logger.Info('[Prefs] cluster directory: %d entries in %d ms (once per run)',
               [cbxClusterServer.Items.Count, sw.ElapsedMilliseconds]);
end;

const
   // A TICK ON THE ACTIVE ROW.  TR4W connects to exactly one cluster, and until
   // now the list gave no sign of which -- the only indication was the
   // "Connecting to:" label above the fields, which is nowhere near the list the
   // operator is reading (NY4I, 2026-08-11).
   //
   // As a code point, NOT as a literal tick in the source.  A non-ASCII byte in
   // a .pas is decoded with the build machine's ANSI codepage unless the file
   // carries a BOM, which is the silent-corruption trap the lang files are
   // documented for.  #$2713 cannot be corrupted by a re-save.
   CLUSTER_ACTIVE_MARK   = #$2713 + ' ';
   // Same width, so the names line up whether or not a row is ticked.
   CLUSTER_INACTIVE_MARK = '  ';

// The one place that spells a cluster's row, so the list built by LoadClusterList
// and the row rewritten on every keystroke cannot drift into two formats.
function ClusterRowText(const aCluster: TClusterDefinition;
                        const aIsActive: boolean): string;
var
   mark: string;
begin
   if aIsActive then
      begin
      mark := CLUSTER_ACTIVE_MARK;
      end
   else
      begin
      mark := CLUSTER_INACTIVE_MARK;
      end;

   Result := Format('%s%s  -  %s', [mark, aCluster.Name, aCluster.Server]);
end;

function TPrefsForm.ClusterIsActive(const aCluster: TClusterDefinition): boolean;
begin
   // BY NAME, which is how the store identifies it -- and why renaming the
   // active cluster has to carry ActiveClusterName with it (see
   // CaptureSelectedCluster).  An index would silently re-point at whatever
   // moved into that slot.
   Result := (aCluster <> nil)
             and (FStore.ActiveClusterName <> '')
             and SameText(aCluster.Name, FStore.ActiveClusterName);
end;

procedure TPrefsForm.ShowClusterRow(const aIndex: integer;
                                    const aCluster: TClusterDefinition);
begin
   if (aIndex < 0) or (aIndex >= lstClusters.Items.Count) or (aCluster = nil) then
      begin
      Exit;
      end;

   SetListItemText(lstClusters, aIndex,
                   ClusterRowText(aCluster, ClusterIsActive(aCluster)));
end;

// Every row, because the tick MOVES: making one cluster active un-ticks
// whichever held it.  Rewriting only the newly active row would leave two ticks
// on screen, and a list claiming two active clusters is worse than one claiming
// none.
procedure TPrefsForm.RefreshClusterRows;
var
   i: integer;
begin
   for i := 0 to FStore.ClusterCount - 1 do
      begin
      ShowClusterRow(i, FStore.Cluster(i));
      end;
end;

procedure TPrefsForm.LoadClusterList;
var
   i: integer;
   keep: integer;
begin
   // NOT LoadClusterServerList.  The directory is populated when the DX Cluster
   // section is first opened (see tvNavChange), not whenever the operator's own
   // cluster library is refreshed -- the two lists have nothing to do with each
   // other, and coupling them is what put a 1.8 s file load on the path of every
   // add, remove and cancel.
   //
   // The stored server still SHOWS with the list empty: cbxClusterServer is a
   // TComboBox, whose Text is independent of Items.
   keep := lstClusters.ItemIndex;
   lstClusters.Items.BeginUpdate;
   try
      ClearListItems(lstClusters);
      for i := 0 to FStore.ClusterCount - 1 do
         begin
         lstClusters.Items.Add(ClusterRowText(FStore.Cluster(i),
                                              ClusterIsActive(FStore.Cluster(i))));
         end;
   finally
      lstClusters.Items.EndUpdate;
   end;

   if (keep >= 0) and (keep < lstClusters.Items.Count) then
      begin
      lstClusters.ItemIndex := keep;
      end
   else if lstClusters.Items.Count > 0 then
      begin
      lstClusters.ItemIndex := 0;
      end;

   ShowActiveCluster;
   ShowSelectedCluster;
end;

procedure TPrefsForm.ShowActiveCluster;
begin
   if FStore.ActiveCluster <> nil then
      begin
      lblActiveCluster.Caption := 'Connecting to: ' + FStore.ActiveCluster.Name +
                               '  -  ' + FStore.ActiveCluster.Server;
      end
   else
      begin
      // SAID PLAINLY.  A cluster page listing three servers while connecting to
      // none is the kind of thing an operator discovers mid-contest.
      lblActiveCluster.Caption := 'Connecting to: (none chosen -- select one and press Use this)';
      end;
end;

procedure TPrefsForm.ShowSelectedCluster;
var
   c: TClusterDefinition;
   have: boolean;
begin
   have := (lstClusters.ItemIndex >= 0) and (lstClusters.ItemIndex < FStore.ClusterCount);

   // Nothing selected means nothing to edit -- the same rule as the rotator
   // page.  Fields that merely LOOK empty still accept typing, and that typing
   // goes nowhere.
   edtClusterName.Enabled     := have;
   cbxClusterServer.Enabled   := have;
   edtClusterLogin.Enabled    := have;
   edtClusterPassword.Enabled := have;
   edtClusterCommand.Enabled  := have;
   btnRemoveCluster.Enabled   := have;
   btnUseCluster.Enabled      := have;

   if not have then
      begin
      edtClusterName.Text     := '';
      cbxClusterServer.Text   := '';
      edtClusterLogin.Text    := '';
      edtClusterPassword.Text := '';
      edtClusterCommand.Text  := '';
      Exit;
      end;

   FLoading := True;
   try
      c := FStore.Cluster(lstClusters.ItemIndex);
      edtClusterName.Text     := c.Name;
      cbxClusterServer.Text   := c.Server;
      edtClusterLogin.Text    := c.LoginCall;
      edtClusterPassword.Text := c.Password;
      edtClusterCommand.Text  := c.ConnectCommand;
   finally
      FLoading := False;
   end;
end;

procedure TPrefsForm.CaptureSelectedCluster;
var
   c: TClusterDefinition;
   wasActive: boolean;
begin
   if FLoading then
      begin
      Exit;
      end;
   if (lstClusters.ItemIndex < 0) or (lstClusters.ItemIndex >= FStore.ClusterCount) then
      begin
      Exit;
      end;

   c := FStore.Cluster(lstClusters.ItemIndex);
   wasActive := SameText(c.Name, FStore.ActiveClusterName);

   // A blank name keeps the old one: this runs on every keystroke, and the box
   // is empty for a moment whenever somebody clears it to retype.
   if Trim(edtClusterName.Text) <> '' then
      begin
      c.Name := Trim(edtClusterName.Text);
      // RENAMING THE ACTIVE ONE MUST FOLLOW IT.  ActiveClusterName is matched by
      // name, so a rename would otherwise silently deactivate the very cluster
      // the operator was editing.
      if wasActive then
         begin
         FStore.ActiveClusterName := c.Name;
         ShowActiveCluster;
         end;
      end;

   c.Server         := Trim(cbxClusterServer.Text);
   c.LoginCall      := Trim(edtClusterLogin.Text);
   // NOT trimmed -- a password may legitimately begin or end with a space.
   c.Password       := edtClusterPassword.Text;
   c.ConnectCommand := Trim(edtClusterCommand.Text);

   // THE LIST ROW FOLLOWS THE EDIT.  Without this the row kept the name it was
   // created with -- NY4I typed a whole HamAlert definition and the list still
   // read "Cluster  -", which makes it look as though nothing was recorded.
   //
   // ListItems[].Text, not Items[] and not a rebuild: assigning to Items fires
   // the list's OnChange, which re-enters ShowSelectedCluster and reloads every
   // field from the store MID-KEYSTROKE -- moving the caret and undoing what is
   // being typed.
   ShowClusterRow(lstClusters.ItemIndex, c);

   // Set HERE rather than in each of the five handlers, so the sixth cannot
   // forget it.  Below the FLoading guard on purpose: loading the form is not
   // an edit, and marking it dirty would arm the unsaved-changes prompt on a
   // window nobody has touched.
   Dirty := True;
end;

procedure TPrefsForm.lstClustersChange(Sender: TObject);
begin
   ShowSelectedCluster;
end;

procedure TPrefsForm.cbxClusterServerChange(Sender: TObject);
begin
   CaptureSelectedCluster;
end;

// THE DIRECTORY IS BUILT WHEN THE OPERATOR REACHES THE CONTROL -- N1MM's
// behaviour, which NY4I asked for after seeing it.  It is the honest place for
// the cost: a list being assembled is what a click on a drop-down leads someone
// to expect, whereas the same pause on merely opening a tab reads as a slow
// program.
//
// OnEnter, NOT OnPopup, and the reason is worth keeping.  TComboBox HAS an
// OnPopup and it looks like exactly the right hook, but TStyledComboEdit.DropDown
// reads:
//
//    Model.DroppedDown := True;
//    if Model.Count > 0 then          <-- the popup, and OnPopup, live in here
//
// so an EMPTY combo never opens its popup and never raises the event. Filling
// on OnPopup cannot work by construction: the event only fires once the list is
// already populated. Wired that way first, and the arrow did nothing at all
// (NY4I, 2026-08-11).
//
// LoadClusterServerList is idempotent, so only the first visit pays.
procedure TPrefsForm.cbxClusterServerEnter(Sender: TObject);
begin
   LoadClusterServerList;
end;

procedure TPrefsForm.edtClusterNameChange(Sender: TObject);
begin
   CaptureSelectedCluster;
end;

procedure TPrefsForm.edtClusterLoginChange(Sender: TObject);
begin
   CaptureSelectedCluster;
end;

procedure TPrefsForm.edtClusterPasswordChange(Sender: TObject);
begin
   CaptureSelectedCluster;
end;

procedure TPrefsForm.edtClusterCommandChange(Sender: TObject);
begin
   CaptureSelectedCluster;
end;

procedure TPrefsForm.btnAddClusterClick(Sender: TObject);
var
   c: TClusterDefinition;
begin
   c := TClusterDefinition.Create;
   c.Name := FStore.UniqueClusterName('Cluster');

   if not FStore.AddCluster(c) then
      begin
      // AddCluster does not free on refusal -- the caller still owns it.
      c.Free;
      Exit;
      end;

   // THE FIRST ONE BECOMES ACTIVE.  An operator who defines exactly one cluster
   // means that one; making them press Use this as well would be ceremony.
   if FStore.ClusterCount = 1 then
      begin
      FStore.ActiveClusterName := c.Name;
      end;

   LoadClusterList;
   lstClusters.ItemIndex := FStore.ClusterCount - 1;
   ShowSelectedCluster;
end;

procedure TPrefsForm.btnRemoveClusterClick(Sender: TObject);
var
   i: integer;
begin
   i := lstClusters.ItemIndex;
   if (i < 0) or (i >= FStore.ClusterCount) then
      begin
      Exit;
      end;

   if MessageDlg(Format('Remove the cluster "%s"?', [FStore.Cluster(i).Name]),
                 TMsgDlgType.mtConfirmation,
                 [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
      begin
      Exit;
      end;

   FStore.DeleteCluster(i);
   LoadClusterList;
end;

procedure TPrefsForm.btnUseClusterClick(Sender: TObject);
begin
   if (lstClusters.ItemIndex < 0) or (lstClusters.ItemIndex >= FStore.ClusterCount) then
      begin
      Exit;
      end;

   FStore.ActiveClusterName := FStore.Cluster(lstClusters.ItemIndex).Name;
   ShowActiveCluster;
   RefreshClusterRows;
   // Choosing where to connect IS a change to be saved.  Without this the tick
   // moves, the operator closes the window, and the choice is gone.
   Dirty := True;

   // NOT reconnected here.  Dropping a live cluster connection the moment
   // somebody clicks in a settings window would lose the spots on screen; the
   // choice takes effect on the next connect, which the operator controls.
end;

function RotatorRowText(const aRotator: TRotatorDefinition): string;
begin
   Result := Format('%s [%s]',
      [aRotator.Name, RotatorDisplayName(aRotator.RotatorId)]);
end;

procedure TPrefsForm.ShowRotatorRow(const aIndex: integer;
                                    const aRotator: TRotatorDefinition);
begin
   if (aIndex < 0) or (aIndex >= lstRotators.Items.Count) or (aRotator = nil) then
      begin
      Exit;
      end;

   SetListItemText(lstRotators, aIndex,
                   RotatorRowText(aRotator));
end;

procedure TPrefsForm.LoadRotatorList;
var
   i: integer;
   id: string;
   keep: integer;
   enumerator: TComPortEnumerator;
   names: TArray<string>;
   info: TComPortInfo;
   caption: string;
begin
   // THE TYPE LIST COMES FROM THE REGISTRY, never from the designer.  Same rule
   // as the log level and the external-logger list: a combo populated in the
   // designer bakes itself into the .fmx and becomes a second copy that keeps
   // working while it drifts.  Add a rotator driver and it appears here with no
   // edit to this form -- which is the whole promise of the factory.
   cbxRotatorType.Items.BeginUpdate;
   try
      cbxRotatorType.Clear;
      for id in RegisteredRotatorIds do
         begin
         cbxRotatorType.Items.Add(RotatorDisplayName(id));
         end;
   finally
      cbxRotatorType.Items.EndUpdate;
   end;

   // THE PORTS THAT ACTUALLY EXIST, through the same enumerator the radio
   // editor uses -- not a hopeful SERIAL 1..64.  NY4I asked for this and it is
   // the right call twice over: a list of sixty-four mostly-imaginary ports
   // makes the operator hunt for the real one, and the friendly name is what
   // tells a CP210x apart from an FTDI when a station has four of them.
   //
   // The CAPTION carries the friendly name; the ITEM'S TAG carries the config
   // value.  Storing what is displayed would put 'COM17 - Silicon Labs CP210x'
   // into the settings file, which is the corruption the legacy dialog had to
   // be fixed for.
   cbxRotatorPort.Items.BeginUpdate;
   try
      cbxRotatorPort.Clear;
      AddComboItem(cbxRotatorPort, TC_PREFS_NONE, PORT_NONE);

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
            AddComboItem(cbxRotatorPort, caption, ComNameToPortValue(names[i]));
            end;
      finally
         enumerator.Free;
      end;
   finally
      cbxRotatorPort.Items.EndUpdate;
   end;

   keep := lstRotators.ItemIndex;
   lstRotators.Items.BeginUpdate;
   try
      ClearListItems(lstRotators);
      for i := 0 to FStore.RotatorCount - 1 do
         begin
         lstRotators.Items.Add(RotatorRowText(FStore.Rotator(i)));
         end;
   finally
      lstRotators.Items.EndUpdate;
   end;

   if (keep >= 0) and (keep < lstRotators.Items.Count) then
      begin
      lstRotators.ItemIndex := keep;
      end
   else if lstRotators.Items.Count > 0 then
      begin
      lstRotators.ItemIndex := 0;
      end;

   ShowSelectedRotator;
end;

procedure TPrefsForm.ShowSelectedRotator;
var
   r: TRotatorDefinition;
   serial: boolean;
   drv: TRotatorBase;
begin
   if (lstRotators.ItemIndex < 0) or (lstRotators.ItemIndex >= FStore.RotatorCount) then
      begin
      edtRotatorName.Text  := '';
      edtRotatorBaud.Text  := '';
      edtRotatorIP.Text    := '';
      edtRotatorUDP.Text   := '';
      edtRotatorBands.Text := '';
      cbxRotatorType.ItemIndex := -1;
      cbxRotatorPort.ItemIndex := -1;

      // NOTHING SELECTED MEANS NOTHING TO EDIT (NY4I).  The fields were merely
      // cleared, so an empty page still accepted typing -- which went nowhere,
      // because CaptureSelectedRotator has no rotator to write to.  A control
      // that takes input and discards it is worse than one that refuses it.
      // Add... is what creates something to edit.
      edtRotatorName.Enabled  := False;
      cbxRotatorType.Enabled  := False;
      cbxRotatorPort.Enabled  := False;
      edtRotatorBaud.Enabled  := False;
      edtRotatorIP.Enabled    := False;
      edtRotatorUDP.Enabled   := False;
      edtRotatorBands.Enabled := False;
      btnRemoveRotator.Enabled := False;
      Exit;
      end;

   // Something is selected, so the fields that apply to it come back.  Which of
   // the transport fields apply is decided below, by asking the driver.
   edtRotatorName.Enabled   := True;
   cbxRotatorType.Enabled   := True;
   edtRotatorBands.Enabled  := True;
   btnRemoveRotator.Enabled := True;

   FLoading := True;
   try
      r := FStore.Rotator(lstRotators.ItemIndex);
      edtRotatorName.Text := r.Name;
      cbxRotatorType.ItemIndex :=
         cbxRotatorType.Items.IndexOf(RotatorDisplayName(r.RotatorId));
      // A STORED PORT THAT IS NO LONGER PLUGGED IN still has to show.  Adding
      // it back rather than selecting nothing is what stops opening this page
      // on a machine with the interface unplugged from silently clearing the
      // operator's rotator port.
      if (r.ControlPort <> '') and (not HasTag(cbxRotatorPort, r.ControlPort)) then
         begin
         AddComboItem(cbxRotatorPort, r.ControlPort + ' (not present)', r.ControlPort);
         end;
      SelectByTag(cbxRotatorPort, r.ControlPort);

      // Blank rather than 0: 0 means "the type's own default", and showing it
      // as a number invites the operator to treat it as a chosen value.
      if r.BaudRate > 0 then
         begin
         edtRotatorBaud.Text := IntToStr(r.BaudRate);
         end
      else
         begin
         edtRotatorBaud.Text := '';
         end;

      edtRotatorIP.Text := r.IPAddress;
      if r.UDPPort > 0 then
         begin
         edtRotatorUDP.Text := IntToStr(r.UDPPort);
         end
      else
         begin
         edtRotatorUDP.Text := '';
         end;
      edtRotatorBands.Text := r.Bands;

      // WHETHER IT IS SERIAL IS THE DRIVER'S ANSWER, not a list of type names
      // kept here.  Building one and asking it is what stops this form growing
      // the `if type = PSTROTATOR` the factory exists to remove -- and a future
      // networked rotator greys the right fields without touching this unit.
      serial := True;
      drv := CreateRotator(r.RotatorId, nil);
      if drv <> nil then
         begin
         try
            serial := drv.UsesSerialPort;
            // The greyed hint shows what this type uses when the box is left
            // blank, so the default is visible without being typed in and
            // thereby frozen against a later change.
            edtRotatorBaud.TextHint := IntToStr(drv.PreferredBaudRate);
         finally
            drv.Free;
         end;
         end;

      cbxRotatorPort.Enabled := serial;
      edtRotatorBaud.Enabled := serial;
      edtRotatorIP.Enabled   := not serial;
      edtRotatorUDP.Enabled  := not serial;
   finally
      FLoading := False;
   end;
end;

procedure TPrefsForm.CaptureSelectedRotator;
var
   r: TRotatorDefinition;
   n: integer;
   ids: TArray<string>;
begin
   if FLoading then
      begin
      Exit;
      end;
   if (lstRotators.ItemIndex < 0) or (lstRotators.ItemIndex >= FStore.RotatorCount) then
      begin
      Exit;
      end;

   r := FStore.Rotator(lstRotators.ItemIndex);

   // A blank name keeps the old one rather than raising: this runs on every
   // keystroke, and the box is momentarily empty whenever somebody clears it to
   // retype.  A dialog there would fire mid-edit.
   if Trim(edtRotatorName.Text) <> '' then
      begin
      r.Name := Trim(edtRotatorName.Text);
      end;

   // STORE THE ID, SHOW THE DISPLAY NAME.  The id is what the registry and the
   // JSON use, and it survives a display name being reworded or translated.
   ids := RegisteredRotatorIds;
   if (cbxRotatorType.ItemIndex >= 0) and (cbxRotatorType.ItemIndex < Length(ids)) then
      begin
      r.RotatorId := ids[cbxRotatorType.ItemIndex];
      end;

   if cbxRotatorPort.ItemIndex >= 0 then
      begin
      // The TAG, never the caption -- see LoadRotatorList.
      r.ControlPort := SelectedTag(cbxRotatorPort);
      end;

   if TryStrToInt(Trim(edtRotatorBaud.Text), n) then
      begin
      r.BaudRate := n;
      end
   else
      begin
      r.BaudRate := 0;
      end;

   r.IPAddress := Trim(edtRotatorIP.Text);
   if TryStrToInt(Trim(edtRotatorUDP.Text), n) then
      begin
      r.UDPPort := n;
      end
   else
      begin
      r.UDPPort := 0;
      end;

   r.Bands := Trim(edtRotatorBands.Text);

   // The row follows the edit -- see CaptureSelectedCluster for why this is
   // ListItems[].Text and not a rebuild.
   ShowRotatorRow(lstRotators.ItemIndex, r);
   Dirty := True;
end;

procedure TPrefsForm.lstRotatorsChange(Sender: TObject);
begin
   ShowSelectedRotator;
end;

procedure TPrefsForm.cbxRotatorTypeChange(Sender: TObject);
begin
   CaptureSelectedRotator;
   // Re-shown, not merely captured: changing the type changes WHICH FIELDS
   // APPLY, and the driver is what says so.
   ShowSelectedRotator;
end;

procedure TPrefsForm.cbxRotatorPortChange(Sender: TObject);
begin
   CaptureSelectedRotator;
end;

procedure TPrefsForm.edtRotatorNameChange(Sender: TObject);
begin
   CaptureSelectedRotator;
end;

procedure TPrefsForm.edtRotatorBaudChange(Sender: TObject);
begin
   CaptureSelectedRotator;
end;

procedure TPrefsForm.edtRotatorIPChange(Sender: TObject);
begin
   CaptureSelectedRotator;
end;

procedure TPrefsForm.edtRotatorUDPChange(Sender: TObject);
begin
   CaptureSelectedRotator;
end;

procedure TPrefsForm.edtRotatorBandsChange(Sender: TObject);
begin
   CaptureSelectedRotator;
end;

procedure TPrefsForm.btnAddRotatorClick(Sender: TObject);
var
   r: TRotatorDefinition;
   ids: TArray<string>;
begin
   r := TRotatorDefinition.Create;
   r.Name := FStore.UniqueRotatorName('Rotator');

   // Defaults to the first registered driver rather than to nothing: a rotator
   // with no type is not something the operator asked for, and an empty combo
   // invites them to believe one is optional.
   ids := RegisteredRotatorIds;
   if Length(ids) > 0 then
      begin
      r.RotatorId := ids[0];
      end;
   r.ControlPort := PORT_NONE;

   if not FStore.AddRotator(r) then
      begin
      // AddRotator does NOT free on refusal -- the caller still owns it, which
      // is what stops a rejected add becoming a double free.
      r.Free;
      Exit;
      end;

   LoadRotatorList;
   lstRotators.ItemIndex := FStore.RotatorCount - 1;
   ShowSelectedRotator;
end;

procedure TPrefsForm.btnRemoveRotatorClick(Sender: TObject);
var
   i: integer;
begin
   i := lstRotators.ItemIndex;
   if (i < 0) or (i >= FStore.RotatorCount) then
      begin
      Exit;
      end;

   if MessageDlg(Format('Remove the rotator "%s"?', [FStore.Rotator(i).Name]),
                 TMsgDlgType.mtConfirmation,
                 [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
      begin
      Exit;
      end;

   FStore.DeleteRotator(i);
   LoadRotatorList;
end;

procedure TPrefsForm.LoadRemainingPanels;
begin
   // A DROP-DOWN, not a text box: SCP MINIMUM LETTERS is ckArray, a discrete
   // allow-list of (0, 3, 4, 5).  A text box would let the operator type 2 and
   // have it silently refused.  The list comes from the table itself, so it
   // cannot drift from what CheckCommand will accept.
   FillFromAllowedValues(cbxSCPMinLetters, 'SCP MINIMUM LETTERS');
   edtSCPCountry.Text    := FStore.CommandValue('SCP COUNTRY STRING',
                               CFGCommandValueAsString('SCP COUNTRY STRING'));

   edtNetAddress.Text    := FStore.CommandValue('SERVER ADDRESS',
                               CFGCommandValueAsString('SERVER ADDRESS'));
   edtNetPort.Text       := FStore.CommandValue('SERVER PORT',
                               CFGCommandValueAsString('SERVER PORT'));
   edtNetPassword.Text   := FStore.CommandValue('SERVER PASSWORD',
                               CFGCommandValueAsString('SERVER PASSWORD'));
   edtNetComputerID.Text := FStore.CommandValue('COMPUTER ID',
                               CFGCommandValueAsString('COMPUTER ID'));
   chkNetAutoSync.Checked := CommandBool('SERVER AUTO SYNCHRONIZE LOG ON CONNECT');
   edtRadioTCPPort.Text  := FStore.CommandValue('RADIO TCP SERVER PORT',
                               CFGCommandValueAsString('RADIO TCP SERVER PORT'));

   edtMainFont.Text := FStore.CommandValue('MAIN FONT', CFGCommandValueAsString('MAIN FONT'));
   edtFontSize.Text := FStore.CommandValue('FONT SIZE', CFGCommandValueAsString('FONT SIZE'));
   chkBoldFont.Checked       := CommandBool('BOLD FONT');
   chkDupeSheetColor.Checked := CommandBool('COLUMN DUPESHEET COLOR');

   edtBackupEvery.Text := FStore.CommandValue('BACKUP LOG FREQUENCY',
                             CFGCommandValueAsString('BACKUP LOG FREQUENCY'));
   edtBackupFile.Text  := FStore.CommandValue('BACKUP LOG FILE NAME',
                             CFGCommandValueAsString('BACKUP LOG FILE NAME'));
end;

procedure TPrefsForm.SaveRemainingPanels;
begin
   if cbxSCPMinLetters.ItemIndex >= 0 then
      begin
      ApplyAndStoreCommand(FStore, 'SCP MINIMUM LETTERS',
                           cbxSCPMinLetters.Items[cbxSCPMinLetters.ItemIndex]);
      end;
   ApplyAndStoreCommand(FStore, 'SCP COUNTRY STRING',  Trim(edtSCPCountry.Text));

   ApplyAndStoreCommand(FStore, 'SERVER ADDRESS',  Trim(edtNetAddress.Text));
   ApplyAndStoreCommand(FStore, 'SERVER PORT',     Trim(edtNetPort.Text));
   // NOT trimmed: a password may legitimately begin or end with a space, and
   // silently removing one turns "wrong password" into an unsolvable puzzle.
   ApplyAndStoreCommand(FStore, 'SERVER PASSWORD', edtNetPassword.Text);
   ApplyAndStoreCommand(FStore, 'COMPUTER ID',     Trim(edtNetComputerID.Text));
   SetCommandBool('SERVER AUTO SYNCHRONIZE LOG ON CONNECT', chkNetAutoSync.Checked);
   ApplyAndStoreCommand(FStore, 'RADIO TCP SERVER PORT', Trim(edtRadioTCPPort.Text));

   ApplyAndStoreCommand(FStore, 'MAIN FONT', Trim(edtMainFont.Text));
   ApplyAndStoreCommand(FStore, 'FONT SIZE', Trim(edtFontSize.Text));
   SetCommandBool('BOLD FONT',              chkBoldFont.Checked);
   SetCommandBool('COLUMN DUPESHEET COLOR', chkDupeSheetColor.Checked);

   ApplyAndStoreCommand(FStore, 'BACKUP LOG FREQUENCY', Trim(edtBackupEvery.Text));
   ApplyAndStoreCommand(FStore, 'BACKUP LOG FILE NAME', Trim(edtBackupFile.Text));
end;

procedure TPrefsForm.btnBrowseBackupClick(Sender: TObject);
var
   dlg: TSaveDialog;
begin
   // SAVE dialog, not Open: the backup file is somewhere to WRITE, and it
   // usually does not exist yet.  An Open dialog would refuse to name it.
   dlg := TSaveDialog.Create(nil);
   try
      dlg.Title   := 'Backup log file';
      dlg.Filter  := 'Log files (*.dat)|*.dat|All files (*.*)|*.*';
      dlg.Options := dlg.Options - [TOpenOption.ofOverwritePrompt];
      if Trim(edtBackupFile.Text) <> '' then
         begin
         dlg.FileName := Trim(edtBackupFile.Text);
         end;
      if dlg.Execute then
         begin
         edtBackupFile.Text := dlg.FileName;
         end;
   finally
      dlg.Free;
   end;
end;

procedure TPrefsForm.LoadClusterPanels;
begin
   // TELNET SERVER is no longer edited directly -- it is a rendering of
   // whichever cluster is active, written in SaveClusterPanels.
   chkSpotCollector.Checked := CommandBool('SPOT COLLECTOR ENABLED');

   chkBandMapEnable.Checked     := CommandBool('BAND MAP ENABLE');
   edtBandMapDecay.Text := FStore.CommandValue('BAND MAP DECAY TIME',
                              CFGCommandValueAsString('BAND MAP DECAY TIME'));
   edtBandMapGuard.Text := FStore.CommandValue('BAND MAP GUARD BAND',
                              CFGCommandValueAsString('BAND MAP GUARD BAND'));
   edtBandMapLimit.Text := FStore.CommandValue('BAND MAP DISPLAY LIMIT',
                              CFGCommandValueAsString('BAND MAP DISPLAY LIMIT'));

   chkBandMapDupes.Checked      := CommandBool('BAND MAP DUPE DISPLAY');
   chkBandMapMultsOnly.Checked  := CommandBool('BAND MAP MULTS ONLY');
   chkBandMapAllBands.Checked   := CommandBool('BAND MAP ALL BANDS');
   chkBandMapAllModes.Checked   := CommandBool('BAND MAP ALL MODES');
   chkBandMapCQ.Checked         := CommandBool('BAND MAP DISPLAY CQ');
   chkBandMapCallWindow.Checked := CommandBool('BAND MAP CALL WINDOW ENABLE');
   chkBandMapSO2R.Checked       := CommandBool('BAND MAP SO2R DISPLAY');
   chkBandMapGHz.Checked        := CommandBool('BAND MAP DISPLAY GHZ');
end;

procedure TPrefsForm.SaveClusterPanels;
begin
   // THE ACTIVE CLUSTER IS WHAT TELNET SERVER MEANS NOW.  The connect path
   // still reads that one global, so the library stays a library and the
   // legacy setting becomes a rendering of the operator's choice -- the same
   // relationship the [Radio] keys have with the radio library.  A cluster's
   // credentials go with it; only the server name has somewhere old to live.
   // ONE call, doing what startup does.  This used to render only the server,
   // so the login callsign, password and post-connect command were stored and
   // never reached the connect path -- and Preferences and startup rendered the
   // active cluster differently, which is the divergence this whole seam exists
   // to prevent.
   ApplyActiveCluster(FStore);
   SetCommandBool('SPOT COLLECTOR ENABLED', chkSpotCollector.Checked);

   SetCommandBool('BAND MAP ENABLE', chkBandMapEnable.Checked);
   ApplyAndStoreCommand(FStore, 'BAND MAP DECAY TIME',    Trim(edtBandMapDecay.Text));
   ApplyAndStoreCommand(FStore, 'BAND MAP GUARD BAND',    Trim(edtBandMapGuard.Text));
   ApplyAndStoreCommand(FStore, 'BAND MAP DISPLAY LIMIT', Trim(edtBandMapLimit.Text));

   SetCommandBool('BAND MAP DUPE DISPLAY',       chkBandMapDupes.Checked);
   SetCommandBool('BAND MAP MULTS ONLY',         chkBandMapMultsOnly.Checked);
   SetCommandBool('BAND MAP ALL BANDS',          chkBandMapAllBands.Checked);
   SetCommandBool('BAND MAP ALL MODES',          chkBandMapAllModes.Checked);
   SetCommandBool('BAND MAP DISPLAY CQ',         chkBandMapCQ.Checked);
   SetCommandBool('BAND MAP CALL WINDOW ENABLE', chkBandMapCallWindow.Checked);
   SetCommandBool('BAND MAP SO2R DISPLAY',       chkBandMapSO2R.Checked);
   SetCommandBool('BAND MAP DISPLAY GHZ',        chkBandMapGHz.Checked);
end;

procedure TPrefsForm.LoadExternalSoftwarePanels;
var
   t: ExternalLoggerType;
begin
   chkWSJTXEnabled.Checked      := CommandBool('WSJT-X ENABLED');
   chkWSJTXRadioControl.Checked := CommandBool('WSJT-X RADIO CONTROL ENABLED');
   chkWSJTXHighlights.Checked   := CommandBool('WSJT-X SEND HIGHLIGHTS');
   edtWSJTXPort.Text      := FStore.CommandValue('WSJT-X BROADCAST PORT',
                                CFGCommandValueAsString('WSJT-X BROADCAST PORT'));
   edtWSJTXMulticast.Text := FStore.CommandValue('WSJT-X MULTICAST GROUP',
                                CFGCommandValueAsString('WSJT-X MULTICAST GROUP'));

   // Filled from ExternalLoggerTypeSA, the same array CFGCA matches against --
   // not typed into the designer, where it would be a second copy that keeps
   // working while it drifts.  A populated combo also bakes itself into the
   // .fmx resource, which is how such a copy becomes permanent.
   cbxLoggerType.Items.BeginUpdate;
   try
      cbxLoggerType.Clear;
      for t := Low(ExternalLoggerType) to High(ExternalLoggerType) do
         begin
         cbxLoggerType.Items.Add(string(AnsiString(ExternalLoggerTypeSA[t])));
         end;
   finally
      cbxLoggerType.Items.EndUpdate;
   end;
   cbxLoggerType.ItemIndex := cbxLoggerType.Items.IndexOf(
      UpperCase(Trim(FStore.CommandValue('EXTERNAL LOGGER',
                     CFGCommandValueAsString('EXTERNAL LOGGER')))));

   chkLoggerEnabled.Checked := CommandBool('EXTERNAL LOGGER ENABLED');
   edtLoggerAddress.Text := FStore.CommandValue('EXTERNAL LOGGER ADDRESS',
                               CFGCommandValueAsString('EXTERNAL LOGGER ADDRESS'));
   edtLoggerPort.Text    := FStore.CommandValue('EXTERNAL LOGGER PORT',
                               CFGCommandValueAsString('EXTERNAL LOGGER PORT'));

   edtMMTTYEngine.Text   := FStore.CommandValue('MMTTY ENGINE',
                               CFGCommandValueAsString('MMTTY ENGINE'));
end;

procedure TPrefsForm.SaveExternalSoftwarePanels;
begin
   SetCommandBool('WSJT-X ENABLED',               chkWSJTXEnabled.Checked);
   SetCommandBool('WSJT-X RADIO CONTROL ENABLED', chkWSJTXRadioControl.Checked);
   SetCommandBool('WSJT-X SEND HIGHLIGHTS',       chkWSJTXHighlights.Checked);
   ApplyAndStoreCommand(FStore, 'WSJT-X BROADCAST PORT',  Trim(edtWSJTXPort.Text));
   ApplyAndStoreCommand(FStore, 'WSJT-X MULTICAST GROUP', Trim(edtWSJTXMulticast.Text));

   if cbxLoggerType.ItemIndex >= 0 then
      begin
      ApplyAndStoreCommand(FStore, 'EXTERNAL LOGGER',
                           cbxLoggerType.Items[cbxLoggerType.ItemIndex]);
      end;
   SetCommandBool('EXTERNAL LOGGER ENABLED', chkLoggerEnabled.Checked);
   ApplyAndStoreCommand(FStore, 'EXTERNAL LOGGER ADDRESS', Trim(edtLoggerAddress.Text));
   ApplyAndStoreCommand(FStore, 'EXTERNAL LOGGER PORT',    Trim(edtLoggerPort.Text));

   ApplyAndStoreCommand(FStore, 'MMTTY ENGINE', Trim(edtMMTTYEngine.Text));
end;

procedure TPrefsForm.btnBrowseMMTTYClick(Sender: TObject);
var
   dlg: TOpenDialog;
begin
   dlg := TOpenDialog.Create(nil);
   try
      dlg.Title  := 'Locate MMTTY.EXE';
      dlg.Filter := 'MMTTY|MMTTY.exe|Programs (*.exe)|*.exe|All files (*.*)|*.*';
      if Trim(edtMMTTYEngine.Text) <> '' then
         begin
         dlg.FileName := Trim(edtMMTTYEngine.Text);
         end;
      if dlg.Execute then
         begin
         edtMMTTYEngine.Text := dlg.FileName;
         end;
   finally
      dlg.Free;
   end;
end;

procedure TPrefsForm.LoadStationPanel;
var
   f: TStationField;
   c: ContinentType;
begin
   for f in StationFields do
      begin
      // The STORE is the record now; CFGCA is where the value is applied.
      // Falling back to the live global covers the first run after upgrade,
      // when the store has nothing yet and the ini seeded the globals.
      f.Edit.Text := FStore.CommandValue(f.Command,
                                         CFGCommandValueAsString(f.Command));
      end;

   // Continent is a ckList: the value is a SPELLING in ContinentTypeSA, and the
   // combo is filled from that array rather than typed into the designer, for
   // the same reason the log level is -- one vocabulary, no drift, and a new
   // continent would appear here for free.
   cbxMyContinent.Items.BeginUpdate;
   try
      cbxMyContinent.Clear;
      for c := Low(ContinentType) to High(ContinentType) do
         begin
         cbxMyContinent.Items.Add(string(AnsiString(ContinentTypeSA[c])));
         end;
   finally
      cbxMyContinent.Items.EndUpdate;
   end;
   cbxMyContinent.ItemIndex :=
      cbxMyContinent.Items.IndexOf(UpperCase(Trim(
         FStore.CommandValue('MY CONTINENT',
                             CFGCommandValueAsString('MY CONTINENT')))));
end;

function TPrefsForm.SaveStationPanel: boolean;
var
   f: TStationField;
   bad: string;
   callText: string;
begin
   Result := True;
   bad := '';

   // A CALLSIGN THAT DOES NOT LOOK LIKE ONE IS QUERIED, NOT REFUSED (NY4I: "if
   // it looks wrong ask the user to confirm... but accept it if they confirm").
   //
   // Refusing outright would be worse than useless.  GoodCallSyntax is a syntax
   // heuristic and real operators hold calls it will not love -- special event
   // calls, unusual prefixes, /MM.  A settings screen that will not accept the
   // operator's own callsign is a bug however good the checker is.  So the
   // check exists to catch a TYPO, and confirming means it is taken as typed.
   //
   // GoodCallSyntax, NOT LooksLikeACallSign.  They answer different questions.
   // LooksLikeACallSign asks "is this token in a RECEIVED EXCHANGE probably a
   // call", so it deliberately tolerates partials -- and it reads the global
   // `contest` for a PCC special case.  GoodCallSyntax asks "is this a
   // well-formed callsign", which is what a settings field is asking, and it is
   // already extracted into uCallSignRoutines and already unit-tested.
   //
   // Blank is NOT queried: GoodCallSyntax('') is False, so checking it would
   // nag every time the operator cleared the field.
   callText := Trim(edtMyCall.Text);
   if (callText <> '') and (not GoodCallSyntax(callText)) then
      begin
      if MessageDlg(Format('"%s" does not look like a regular callsign.' + sLineBreak +
                           sLineBreak + 'Use it anyway?', [callText]),
                    TMsgDlgType.mtWarning,
                    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
         begin
         // Nothing saved, so the operator comes back to a panel still showing
         // what they typed and can correct it.
         Result := False;
         Exit;
         end;
      end;

   // WRITTEN THROUGH CheckCommand, NOT INTO A JSON SECTION, and that is a
   // decision rather than an omission.  Three things depend on the row still
   // being applied by CFGCA:
   //
   //   1. EVERY 'MY' ROW IS crNetwork:1 -- it is pushed to the other stations
   //      in a multi-op network when it changes, and uNet.pas:318 applies an
   //      INBOUND change by calling CheckCommand.  csJSON makes CheckCommand
   //      inert, so a change made at another position would be accepted,
   //      written to the ini, and never reach the program.
   //   2. MY CALL, MY CONTINENT, MY COUNTRY and MY ZONE carry crA hooks
   //      (F_MY_CALL, F_MY_CONTINENT, F_MY_COUNTRY, F_MY_ZONE) which derive
   //      dependent state.  A value copied past them leaves that state stale.
   //   3. CheckCommand is where the crMin/crMax bounds live.
   //
   // So Station keeps the ini as its transport for now.  The rows move to
   // csOwned -- hidden from Ctrl-J so there is ONE editor -- but stay applied.
   // Moving them to JSON needs the multi-op receive path to have somewhere else
   // to land, which is its own piece of work.
   for f in StationFields do
      begin
      if not ApplyAndStoreCommand(FStore, f.Command, Trim(f.Edit.Text)) then
         begin
         bad := bad + f.Command + ' = "' + Trim(f.Edit.Text) + '"' + sLineBreak;
         Result := False;
         end;
      end;

   if cbxMyContinent.ItemIndex >= 0 then
      begin
      if not ApplyAndStoreCommand(FStore, 'MY CONTINENT',
                                  cbxMyContinent.Items[cbxMyContinent.ItemIndex]) then
         begin
         bad := bad + 'MY CONTINENT' + sLineBreak;
         Result := False;
         end;
      end;

   if not Result then
      begin
      // REPORTED, not swallowed.  A refused value means the operator's typing
      // did not take, and the only thing worse than a rejection is a silent
      // one -- they would close Preferences believing the station was set.
      ShowMessage('These entries were not accepted and have not been saved:'
                  + sLineBreak + sLineBreak + bad);
      end;
end;

procedure TPrefsForm.LoadTCIPanel;
begin
   chkTCIServer.Checked  := FStore.TCIServerEnabled;
   chkTCIBindAll.Checked := FStore.TCIBindAll;

   // A BLANK PORT MEANS "the default", which is what 0 means in the store.
   // Showing 0 would invite the operator to think the server listens on port
   // zero; the greyed prompt shows the number that will actually be used
   // without pretending it has been chosen.  Same idiom as the CI-V address
   // and auto-info hints in the radio editor.
   if FStore.TCIPort > 0 then
      begin
      edtTCIPort.Text := IntToStr(FStore.TCIPort);
      end
   else
      begin
      edtTCIPort.Text := '';
      end;
   edtTCIPort.TextHint := IntToStr(TCI_SERVER_DEFAULT_PORT);

   edtTCIMaxTx.Text := IntToStr(FStore.TCIMaxTxSeconds);
end;

procedure TPrefsForm.SaveTCIPanel;
var
   n: integer;
   txt: string;
begin
   FStore.TCIServerEnabled := chkTCIServer.Checked;
   FStore.TCIBindAll       := chkTCIBindAll.Checked;

   // Blank -> 0 -> "the server's default".  A value that is not a usable port
   // is REFUSED and the previous one kept, rather than being coerced to 0:
   // coercion would silently move the operator's server to a different port
   // and they would find out when a client failed to connect.
   txt := Trim(edtTCIPort.Text);
   if txt = '' then
      begin
      FStore.TCIPort := 0;
      end
   else if TryStrToInt(txt, n) and (n > 0) and (n <= 65535) then
      begin
      FStore.TCIPort := n;
      end
   else
      begin
      logger.Warn('[Preferences] "%s" is not a port number 1..65535 -- keeping %d',
                  [txt, FStore.TCIPort]);
      end;

   // 0 is legal here and means NO LIMIT, so it is not refused -- unlike the
   // port, where 0 means something else entirely.
   txt := Trim(edtTCIMaxTx.Text);
   if TryStrToInt(txt, n) and (n >= 0) and (n <= 3600) then
      begin
      FStore.TCIMaxTxSeconds := n;
      end
   else
      begin
      logger.Warn('[Preferences] "%s" is not 0..3600 seconds -- keeping %d',
                  [txt, FStore.TCIMaxTxSeconds]);
      end;
end;

procedure TPrefsForm.LoadLoggingPanel;
var
   lvl: tLogLevels;
   idx: integer;
begin
   // THE LEVEL LIST IS BUILT FROM tLogLevelsSA, NOT TYPED INTO THE DESIGNER.
   //
   // A populated combo BAKES ITSELF INTO THE .fmx resource (learned building
   // the radio editor), so designer-entered items would be a second copy of the
   // level vocabulary -- one that keeps working while it drifts from the enum.
   // Reading the same array CFGCA matched against makes drift impossible: add a
   // level to tLogLevels and it appears here.
   cbxLogLevel.Items.BeginUpdate;
   try
      cbxLogLevel.Clear;
      for lvl := Low(tLogLevels) to High(tLogLevels) do
         begin
         cbxLogLevel.Items.Add(string(AnsiString(tLogLevelsSA[lvl])));
         end;
   finally
      cbxLogLevel.Items.EndUpdate;
   end;

   idx := cbxLogLevel.Items.IndexOf(UpperCase(Trim(FStore.LogLevelName)));
   if idx < 0 then
      begin
      // An unreadable level in the file selects nothing rather than silently
      // showing NONE, which the operator would then save and thereby turn
      // logging off without ever choosing to.
      logger.Warn('[Preferences] log level "%s" is not one this build knows',
                  [FStore.LogLevelName]);
      end;
   cbxLogLevel.ItemIndex := idx;

   chkTelnetDebug.Checked     := FStore.TelnetDebug;
   chkHamLibDebug.Checked     := FStore.HamLibDebug;
   chkHamLibTrace.Checked     := FStore.HamLibTrace;
   chkHamLibAsyncOnly.Checked := FStore.HamLibAsyncOnly;

   // TCI's debug flag is SHOWN here and OWNED by the tci section -- this panel
   // is a view of it, not a second home for it.
   chkTCIDebug.Checked := FStore.TCIDebug;

   // ASK THE APPENDER, do not recompute the path.  It is a MainUnit global
   // created with 'tr4w.log' relative to the program directory; deriving it
   // again here would be a second answer to one question, and the two would
   // disagree the day the appender moves.
   if Assigned(appender) then
      begin
      lblLogFilePath.Caption := ExpandFileName(appender.FileName);
      end
   else
      begin
      lblLogFilePath.Caption := '';
      end;
end;

procedure TPrefsForm.SaveLoggingPanel;
begin
   if cbxLogLevel.ItemIndex >= 0 then
      begin
      FStore.LogLevelName := cbxLogLevel.Items[cbxLogLevel.ItemIndex];
      end;

   FStore.TelnetDebug     := chkTelnetDebug.Checked;
   FStore.HamLibDebug     := chkHamLibDebug.Checked;
   FStore.HamLibTrace     := chkHamLibTrace.Checked;
   FStore.HamLibAsyncOnly := chkHamLibAsyncOnly.Checked;
   FStore.TCIDebug        := chkTCIDebug.Checked;

   // STRAIGHT ONTO THE PROGRAM, not just into the store.  These rows are csJSON
   // now, so CheckCommand is inert for them and nothing else will publish them
   // -- and the level in particular has always taken effect IMMEDIATELY (NY4I),
   // which is what CommandsProcArray[13] = @UpdateDebugLogLevel exists for.
   // ApplyLoggingSettings makes that call; assigning logLevels alone would
   // leave the running logger untouched.
   ApplyLoggingSettings(FStore);
   TR4W_TCI_DEBUG := FStore.TCIDebug;
end;

procedure TPrefsForm.cbxLogLevelChange(Sender: TObject);
begin
   // Deliberately does NOT apply the level here.  Save is what commits every
   // other setting on this form, and a level that changed on selection while
   // Cancel still promised to discard it would be lying about Cancel.
end;

procedure TPrefsForm.btnOpenLogFileClick(Sender: TObject);
var
   fileName: string;
begin
   if not Assigned(appender) then
      begin
      ShowMessage('Logging is not running, so there is no file to open.');
      Exit;
      end;

   fileName := ExpandFileName(appender.FileName);
   if not FileTextExists(fileName) then
      begin
      ShowMessage(Format('There is no log file yet at %s.', [fileName]));
      Exit;
      end;

   // ShellExecute with no verb, so the operator's own choice of text editor
   // opens it.  Nothing is written and the file stays open in the appender --
   // which is why there is no "Clear log file" button beside this one: the
   // rolling appender holds the handle, and truncating underneath it is not
   // something to do casually from a settings screen.
   ShellExecute(0, nil, PChar(fileName), nil, nil, SW_SHOWNORMAL);
end;

procedure TPrefsForm.cbxRadio1Change(Sender: TObject);
begin
   SlotRadioChanged(cbxRadio1, cbxRadio2, cbxCW1);
end;

procedure TPrefsForm.cbxRadio2Change(Sender: TObject);
begin
   SlotRadioChanged(cbxRadio2, cbxRadio1, cbxCW2);
end;

// A slot's RADIO changed, so that slot's CW-output list is stale: "CW by CAT"
// and "Radio keyer port" are offered only when THAT radio provides them.
// Capturing the field alone left the list built for the previously displayed
// radio, so choosing a K4 in a profile whose slot had been empty offered no
// CW-by-CAT at all -- it looked as though the option belonged to some other
// profile (NY4I, 2026-08-08).
//
// WHICH SLOT IS A PARAMETER, not something to work out from Sender.  This used
// to be one handler on both combos that opened with `if Sender = cbxRadio2`,
// and that comparison is uncheckable: TObject against TObject compiles whatever
// is passed, so a third combo wired to it would silently take the slot-1 branch
// (NY4I 2026-08-08).  The two callers above already know which slot they are.
//
// Only the changed slot is rebuilt: refilling both would reset the other
// slot's selection to whatever its stored value is, discarding an edit the
// operator had just made and not yet saved.
procedure TPrefsForm.SlotRadioChanged(const aThisCombo, aOtherCombo, aThisCWCombo: TComboBox);
var
   wasLoading: boolean;
   prof: TStationProfile;
   thisCombo, otherCombo: TComboBox;
   chosen, taken, previous: string;
begin
   thisCombo  := aThisCombo;
   otherCombo := aOtherCombo;

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
      FillCWOutputCombo(aThisCWCombo, SelectedTag(aThisCWCombo), SelectedTag(thisCombo));

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

{ ------------------------------------------------- UDP broadcast section --- }

// The stream's name for the OPERATOR.  Deliberately not UDPStreamName, which is
// the storage spelling ('appInfo') and must stay stable in the file whatever
// the UI calls it.
function UDPStreamCaption(const aStream: TUDPStream): string;
begin
   case aStream of
      usContact: Result := TC_PREFS_UDPSTREAM_CONTACT;
      usRadio:   Result := TC_PREFS_UDPSTREAM_RADIO;
      usScore:   Result := TC_PREFS_UDPSTREAM_SCORE;
      usRotor:   Result := TC_PREFS_UDPSTREAM_ROTOR;
      usLookup:  Result := TC_PREFS_UDPSTREAM_LOOKUP;
      usAppInfo: Result := TC_PREFS_UDPSTREAM_APPINFO;
   else
      // A stream added to the enum with no caption here: show the storage name
      // rather than an empty column, so it is visibly unfinished instead of
      // invisibly missing.
      Result := UDPStreamName(aStream);
   end;
end;

function TPrefsForm.UDPRowText(const aDestination: TUDPDestination): string;
var
   st: TUDPStream;
   streams: string;
begin
   streams := '';
   for st := Low(TUDPStream) to High(TUDPStream) do
      begin
      if aDestination.Carries(st) then
         begin
         if streams <> '' then
            begin
            streams := streams + ', ';
            end;
         streams := streams + UDPStreamCaption(st);
         end;
      end;

   // The editor refuses to save a destination carrying nothing, so this is only
   // reachable through a hand-edited file -- and it must READ as wrong rather
   // than as a row with an empty column.
   if streams = '' then
      begin
      streams := TC_PREFS_UDPNOSTREAMS;
      end;

   // Address, port and streams all on the row: "which port does radio info go
   // to" is answerable without opening anything.
   Result := Format('%s:%d   %s', [aDestination.Address, aDestination.Port, streams]);
end;

procedure TPrefsForm.RefreshUDPList;
var
   wasLoading: boolean;
   keep: integer;
   i: integer;
begin
   if FUDPConfig = nil then
      begin
      Exit;
      end;

   // The two checkboxes below fire OnChange when assigned, and their handlers
   // capture and mark the panel dirty.  Without this guard, merely OPENING
   // Preferences would light up Apply.
   wasLoading := FLoading;
   FLoading := True;
   try
      keep := lstUDPDestinations.ItemIndex;

      ClearListItems(lstUDPDestinations);
      for i := 0 to FUDPConfig.DestinationCount - 1 do
         begin
         lstUDPDestinations.Items.Add(UDPRowText(FUDPConfig.Destination[i]));
         end;

      // Selection restored by POSITION, which is what it means here: the list
      // is the config's own order and the operator's mental row number.
      if (keep >= 0) and (keep < lstUDPDestinations.Items.Count) then
         begin
         lstUDPDestinations.ItemIndex := keep;
         end;

      chkUDPEnabled.Checked := FUDPConfig.Enabled;
      chkUDPAllQSOs.Checked := FUDPConfig.AllQSOs;
   finally
      FLoading := wasLoading;
   end;
end;

function TPrefsForm.SelectedUDPDestination: TUDPDestination;
begin
   Result := nil;
   if (FUDPConfig = nil) or (lstUDPDestinations.ItemIndex < 0) then
      begin
      Exit;
      end;
   if lstUDPDestinations.ItemIndex >= FUDPConfig.DestinationCount then
      begin
      Exit;
      end;
   Result := FUDPConfig.Destination[lstUDPDestinations.ItemIndex];
end;

procedure TPrefsForm.btnUDPAddClick(Sender: TObject);
begin
   if FUDPEditor = nil then
      begin
      FUDPEditor := TfrmUDPDestinationEdit.Create(Self);
      end;

   FUDPEditIsNew  := True;
   FUDPEditTarget := nil;
   FreeAndNil(FUDPEditClone);

   // Opens on the compiled-in defaults with contacts ticked: that is what most
   // stations are adding, and an empty dialog makes the operator supply three
   // answers to add the ordinary case.
   FUDPEditClone := TUDPDestination.Create(UDP_DEFAULT_ADDRESS, UDP_DEFAULT_PORT,
                                           [usContact]);
   FUDPEditor.EditDestination(FUDPEditClone, UDPEditorDone);
end;

procedure TPrefsForm.EditSelectedUDPDestination;
var
   target: TUDPDestination;
begin
   target := SelectedUDPDestination;
   if target = nil then
      begin
      Exit;
      end;

   if FUDPEditor = nil then
      begin
      FUDPEditor := TfrmUDPDestinationEdit.Create(Self);
      end;

   // A CLONE, so Cancel costs nothing -- the same rule the radio and keyer
   // editors follow.  The original is remembered so the accepted values can be
   // assigned back onto it, keeping the object identity the list indexes.
   FUDPEditIsNew  := False;
   FUDPEditTarget := target;
   FreeAndNil(FUDPEditClone);
   FUDPEditClone := target.Clone;
   FUDPEditor.EditDestination(FUDPEditClone, UDPEditorDone);
end;

procedure TPrefsForm.btnUDPEditClick(Sender: TObject);
begin
   EditSelectedUDPDestination;
end;

procedure TPrefsForm.lstUDPDestinationsDblClick(Sender: TObject);
begin
   EditSelectedUDPDestination;
end;

procedure TPrefsForm.UDPEditorDone(const aAccepted: boolean);
var
   clash: TUDPDestination;
begin
   if not aAccepted then
      begin
      FreeAndNil(FUDPEditClone);
      Exit;
      end;

   // REFUSED HERE, not at save time.  The same address and port twice would
   // send everything it carries twice, and Validate would then block a save the
   // operator cannot see the cause of.  Told now, while the dialog they just
   // accepted is still what they are thinking about.
   clash := FUDPConfig.FindDestination(FUDPEditClone.Address, FUDPEditClone.Port);
   if (clash <> nil) and (clash <> FUDPEditTarget) then
      begin
      ShowMessage(Format(TC_PREFS_UDPDUPLICATE,
                         [FUDPEditClone.Address, FUDPEditClone.Port]));
      FreeAndNil(FUDPEditClone);
      Exit;
      end;

   if FUDPEditIsNew then
      begin
      FUDPConfig.AddDestination(FUDPEditClone.Address, FUDPEditClone.Port,
                                FUDPEditClone.Streams);
      end
   else if FUDPEditTarget <> nil then
      begin
      // Assigned onto the existing object rather than replaced, so the list
      // position and anything holding it stay valid.
      FUDPEditTarget.Assign(FUDPEditClone);
      end;

   // The clone is ours either way: AddDestination builds its own object from
   // the values, so this is not an ownership transfer.
   FreeAndNil(FUDPEditClone);

   Dirty := True;
   RefreshUDPList;
end;

procedure TPrefsForm.btnUDPRemoveClick(Sender: TObject);
var
   target: TUDPDestination;
   index: integer;
begin
   target := SelectedUDPDestination;
   if target = nil then
      begin
      Exit;
      end;

   index := lstUDPDestinations.ItemIndex;
   if MessageDlg(Format(TC_PREFS_UDPCONFIRMREMOVE, [target.Address, target.Port]),
                 TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
      begin
      Exit;
      end;

   FUDPConfig.RemoveDestination(index);
   Dirty := True;
   RefreshUDPList;
end;

procedure TPrefsForm.btnUDPTestClick(Sender: TObject);
var
   target: TUDPDestination;
   err: string;
begin
   target := SelectedUDPDestination;
   if target = nil then
      begin
      ShowMessage(TC_PREFS_UDPSELECTFIRST);
      Exit;
      end;

   // Tests the ROW, not the configuration: it works whether or not the master
   // switch is on and whether or not the panel has been saved, because "does
   // this endpoint work" is a different question from "am I broadcasting".
   if UDPBroadcaster.TestDestination(target.Address, target.Port, err) then
      begin
      // SENT, not delivered -- UDP cannot tell us the difference and neither
      // can this message.
      ShowMessage(Format(TC_PREFS_UDPTESTSENT, [target.Address, target.Port]));
      end
   else
      begin
      ShowMessage(err);
      end;
end;

procedure TPrefsForm.CaptureUDPFields;
begin
   if (FUDPConfig = nil) or FLoading then
      begin
      Exit;
      end;
   FUDPConfig.Enabled := chkUDPEnabled.Checked;
   FUDPConfig.AllQSOs := chkUDPAllQSOs.Checked;
   Dirty := True;
end;

procedure TPrefsForm.chkUDPEnabledChange(Sender: TObject);
begin
   CaptureUDPFields;
end;

procedure TPrefsForm.chkUDPAllQSOsChange(Sender: TObject);
begin
   CaptureUDPFields;
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
      if MessageBoxA(Self.Handle,
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

procedure TPrefsForm.btnActivateClick(Sender: TObject);
var
   oldCaption: string;
begin
   // ACTIVATING TAKES SECONDS AND LOOKS LIKE NOTHING (NY4I).  Both radios are
   // closed and reopened, and closing waits on the OS and on a polling thread
   // noticing -- so the window sits there with no cursor change and no message,
   // which reads as a hang.  An operator who clicks again during it starts a
   // SECOND teardown on top of the first.
   //
   // The button says what is happening and is disabled while it happens, which
   // costs nothing and removes the double-click.  Whether the wait itself can
   // be shortened is a separate question, and the per-phase timings now in the
   // log are what will answer it.
   oldCaption := btnActivate.Caption;
   btnActivate.Caption    := 'Activating...';
   btnActivate.Enabled := False;
   try
      // Repainted before the work starts, or the new caption never appears --
      // the whole apply runs without returning to the message loop.
      Application.ProcessMessages;

      // AFTER ProcessMessages, deliberately.  The FMX Cursor property was set
      // here originally and showed nothing: FMX applies a cursor on the next
      // WM_SETCURSOR, and Windows only sends one when the pointer MOVES -- which
      // it does not, because it is resting on the button that was just clicked.
      // Pumping the queue therefore repaints the caption and still leaves the
      // cursor alone.
      //
      // Win32 SetCursor changes it now, and it survives the whole apply because
      // nothing after this point pumps the message that would reset it.  It goes
      // after ProcessMessages so that the pump cannot undo it.  Same reasoning
      // as LoadClusterServerList; see the longer note there.
      SetCursor(LoadCursor(0, IDC_WAIT));
      ApplyNow(True);
   finally
      SetCursor(LoadCursor(0, IDC_ARROW));
      btnActivate.Caption    := oldCaption;
      btnActivate.Enabled := True;
   end;
end;

procedure TPrefsForm.btnApplyClick(Sender: TObject);
begin
   // Apply saves but does NOT activate: an operator adjusting a radio they are
   // not currently using should not have their live radios restarted.
   ApplyNow(False);
end;

procedure TPrefsForm.btnOKClick(Sender: TObject);
var
   sw: TStopwatch;
begin
   sw := TStopwatch.StartNew;
   if ApplyNow(False) then
      begin
      LogPhase(sw, 'OK: ApplyNow', True);
      Hide;
      LogPhase(sw, 'OK: Hide');
      end;
end;

procedure TPrefsForm.DiscardChanges;
var
   sw: TStopwatch;
begin
   // Throw the working copy away and reload from disk, so that reopening shows
   // what is actually stored rather than the edits just abandoned.
   //
   // NOTE THE COST: this repeats the whole of RefreshAll, which is the same work
   // construction does -- including the COM enumeration and the cluster file.
   // That is why the CLOSE is timed too; NY4I reported a delay on the way out as
   // well as on the way in, and this is the only path that could explain it.
   // ITS OWN WATCH, not FTiming.  The nested phase logging restarts FTiming, so
   // a total read from it afterwards reports only the last phase -- which is
   // exactly what it did on the first run here: 2 ms against a 3.6 s reality.
   sw := TStopwatch.StartNew;
   FStore.Clear;
   LoadStore;
   RefreshAll;
   // CLEARED AFTER THE REFRESH, not before.  Repopulating the controls fires
   // their change events, and while FLoading suppresses the marker, clearing the
   // flag first would leave the form dirty the moment anything slipped past that
   // guard -- discarding changes and being told there are unsaved changes.
   Dirty := False;
   LogPhase(sw, 'CANCEL: reload', True);
end;

procedure TPrefsForm.btnCancelClick(Sender: TObject);
begin
   DiscardChanges;
   Hide;
end;

procedure TPrefsForm.FormShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);
end;

procedure TPrefsForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
   answer: integer;
begin
   // The X is easy to hit by accident, so unsaved work gets a question rather
   // than being silently kept OR silently thrown away.  Cancel means "do not
   // close" -- caNone -- which is the option that makes the prompt safe to
   // dismiss.
   if FDirty then
      begin
      answer := MessageBoxA(Self.Handle,
                            PAnsiChar(AnsiString(TC_PREFS_UNSAVED)),
                            PAnsiChar(AnsiString(TC_PREFS_UNSAVEDTITLE)),
                            MB_YESNOCANCEL or MB_ICONQUESTION);
      if answer = IDCANCEL then
         begin
         Action := caNone;
         Exit;
         end;

      if answer = IDYES then
         begin
         // A save that fails (validation, a bad path) must NOT close the window
         // and lose the work it just refused to store.
         if not ApplyNow(False) then
            begin
            Action := caNone;
            Exit;
            end;
         end
      else
         begin
         DiscardChanges;
         end;
      end;

   UnregisterHostedFormHandle(Self.Handle);
   // Hide, never free: freeing a form from inside its own event handler is the
   // classic way to crash on the way out, and reopening should be instant.
   Action := caHide;
end;

initialization

finalization
   FreeAndNil(gPrefsForm);

end.
