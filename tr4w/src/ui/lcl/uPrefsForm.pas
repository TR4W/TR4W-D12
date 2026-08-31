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
   Types,          // TRect -- the implementation uses Windows, which has its own
   LCLType,        // LM_USER for the deferred-focus message, and odSelected
                   // for the search list's owner-draw (Windows declares one too)
   System.UITypes,
   uLCLFormHelpers,      // TStopwatch and the list/combo tag helpers
   Controls,
   Forms,
   StdCtrls,
   Grids,          // TStringGrid -- the colors page is one grid, not 100 combos
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
   uSettingsBinding,          // TSettingBindings -- a field on the form below
  uTR4WStrings,
  uAnsiStr;


const
   { How many timer ticks to spend getting the caret into a searched setting
     before giving up and saying so.  ~15 x 15 ms: long enough for a page that
     has just been shown to become focusable, short enough that a control which
     never will does not spin a timer for the life of the window. }
   FOCUS_MAX_TRIES = 15;

   { How far below the top of a scrolling page a searched setting is placed.
     Enough that it does not sit on the frame, little enough that the rows above
     it stay visible for context. }
   FOUND_ROW_MARGIN = 60;

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
   { ONE SEARCHABLE SETTING.  Built by walking the bindings: the binding knows
     the key, the registry knows the caption and the legacy Ctrl-J name, and the
     control's parent panel knows which of the 27 sections it sits in.

     These live here rather than in uPrefsSearch because they name a TWinControl,
     and that unit is deliberately free of the LCL so the ranking can be unit
     tested without a UI framework. }
   TPrefsSearchEntry = record
      Caption: string;
      Command: string;       // the legacy Ctrl-J spelling, or ''
      SectionTag: NativeInt;
      SectionName: string;
      Control: TWinControl;
   end;

   TPrefsSearchHit = record
      Score: integer;
      Entry: integer;        // index into FSearchIndex
   end;

   TNavItemVisit = procedure (item: TTreeNode) of object;

   TPrefsForm = class(TForm)
      edtSearch: TEdit;
      tvNav: TTreeView;
      layHardware: TPanel;
      lblHardwareHeading: TLabel;
      lblHardwareInfo: TLabel;
      lblRelayPort: TLabel;
      cbxRelayPort: TComboBox;
      lblRelayPortInfo: TLabel;
      lblBandOutput1: TLabel;
      cbxBandOutput1: TComboBox;
      lblBandOutput2: TLabel;
      cbxBandOutput2: TComboBox;
      lblStereoPort: TLabel;
      cbxStereoPort: TComboBox;
      chkUseControlPort: TCheckBox;
      chkPTTViaCommands: TCheckBox;
      chkPTTLockout: TCheckBox;
      layOperating: TPanel;
      lblOperatingHeading: TLabel;
      lblOperatingInfo: TLabel;
      chkAutoReturnToCQ: TCheckBox;
      chkAutoCallTerminate: TCheckBox;
      chkEscapeExitsSAP: TCheckBox;
      chkLeaveCursorInCall: TCheckBox;
      chkLogWithSingleEnter: TCheckBox;
      chkSpaceBarDupeCheck: TCheckBox;
      chkConfirmEditChanges: TCheckBox;
      chkAutoQSONumberDecrement: TCheckBox;
      lblSCPMatchHeading: TLabel;
      chkPossibleCalls: TCheckBox;
      chkPartialCall: TCheckBox;
      chkWildcardPartials: TCheckBox;
      chkNameFlag: TCheckBox;
      chkCallWindowShowAllSpots: TCheckBox;
      chkSwapPacketSpotRadios: TCheckBox;
      lblLogFilesHeading: TLabel;
      chkCheckLogFileSize: TCheckBox;
      chkUnknownCountryFile: TCheckBox;
      chkUpdateRestartFile: TCheckBox;
      chkYCCCSO2R: TCheckBox;
      lblYCCCInfo: TLabel;
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
      // Sits beside the enable box rather than in the paragraph below it: the
      // scope is the thing an operator needs at the moment of ticking, and
      // "Enable the TCI server" on its own reads as though it already permits
      // what the second checkbox controls. (NY4I, 2026-08-14.)
      lblTCIServerScope: TLabel;
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
      lblSpotCollectorHint: TLabel;
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
      btnUseRotator: TButton;
      lblActiveRotator: TLabel;
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
      chkInBandLockout: TCheckBox;
      chkQSYInactive: TCheckBox;
      chkSwapRelaySense: TCheckBox;
      chkWaitForStrength: TCheckBox;
      chkMultiMultsOnly: TCheckBox;
      chkIntercomFile: TCheckBox;

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
      chkCWMessagesChainable: TCheckBox;
      chkTuneWithDits: TCheckBox;
      chkSendFourLetterCall: TCheckBox;
      chkIncludeFKeyNumber: TCheckBox;
      lblMainWindowHeading: TLabel;
      chkNoBorder: TCheckBox;
      chkNoCaption: TCheckBox;
      chkNoColumnHeader: TCheckBox;
      chkShowGridlines: TCheckBox;
      lblAppearMenuNote: TLabel;
      layAudio: TPanel;
      lblAudioHeading: TLabel;
      lblAudioInfo: TLabel;
      lblDVKHeading: TLabel;
      chkDVKEnable: TCheckBox;
      chkDVKLocalizedMessages: TCheckBox;
      chkUseRecordedSigns: TCheckBox;
      lblDVKPath: TLabel;
      edtDVKPath: TEdit;
      lblDVKRecorder: TLabel;
      edtDVKRecorder: TEdit;
      lblMP3Heading: TLabel;
      chkMP3RecorderEnable: TCheckBox;
      lblMP3Path: TLabel;
      edtMP3Path: TEdit;
      lblMP3Player: TLabel;
      edtMP3Player: TEdit;
      lblAudioNote: TLabel;
      { The cards. Two panels each: a hairline-coloured outer and a white
        inner one pixel inside it, which is how the LCL draws a 1px border
        without owner-drawing. Published because they are streamed. }
      cardDVK: TPanel;
      cardDVKInner: TPanel;
      cardMP3: TPanel;
      cardMP3Inner: TPanel;
      btnBrowseDVKPath: TButton;
      btnBrowseDVKRecorder: TButton;
      btnBrowseMP3Path: TButton;
      btnBrowseMP3Player: TButton;
      layPaddlePTT: TPanel;
      lblPaddlePTTHeading: TLabel;
      lblPaddlePTTInfo: TLabel;
      lblPaddleGroup: TLabel;
      lblPaddleSpeed: TLabel;
      edtPaddleSpeed: TEdit;
      lblPaddleSpeedUnits: TLabel;
      lblPaddleTone: TLabel;
      edtPaddleTone: TEdit;
      lblPaddleToneUnits: TLabel;
      lblPaddleHold: TLabel;
      edtPaddleHold: TEdit;
      lblPaddleHoldUnits: TLabel;
      chkSwapPaddles: TCheckBox;
      lblPTTGroup: TLabel;
      chkPTTEnable: TCheckBox;
      lblPTTDelay: TLabel;
      edtPTTDelay: TEdit;
      lblPTTDelayUnits: TLabel;
      chkNoPollDuringPTT: TCheckBox;
      lblPaddlePortNote: TLabel;
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
      procedure tvNavExpanded(Sender: TObject; Node: TTreeNode);
      // CLICKING AN ALREADY-SELECTED PARENT TOGGLES IT.  Without this a branch
      // can be opened but not closed by the same click that opened it: the
      // expand lives in tvNavChange, which only fires when the SELECTION
      // changes, and clicking the selected row changes nothing (NY4I,
      // 2026-08-21).  MouseDOWN deliberately -- the selection has not moved yet,
      // so tvNav.Selected still names the row that was already selected, which
      // is the whole test.
      procedure tvNavMouseDown(Sender: TObject; Button: TMouseButton;
                               Shift: TShiftState; X, Y: integer);
      procedure cbxRelayPortChange(Sender: TObject);

      { PUBLISHED because the RESOURCE binds them by name -- TWriter stores an
        event as a string and the loader looks it up in published RTTI. Declared
        anywhere else, as these briefly were, the .lfm streams until it reaches
        OnChange and then fails: the same RTE 217 that made Preferences
        unopenable for a day. Lint-FormFields caught it here instead. }
      procedure edtSearchChange(Sender: TObject);
      procedure edtSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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
      procedure btnBrowseDVKPathClick(Sender: TObject);
      procedure btnBrowseDVKRecorderClick(Sender: TObject);
      procedure btnBrowseMP3PathClick(Sender: TObject);
      procedure btnBrowseMP3PlayerClick(Sender: TObject);
      { The pickers themselves. ONE handler per button, each
        delegating with explicit arguments -- no branching on
        Sender, which is the house rule and what keeps a rename
        from silently repointing a button at the wrong edit. }
      procedure BrowseForFolder(const aEdit: TEdit; const aTitle: string);
      procedure BrowseForProgram(const aEdit: TEdit; const aTitle,
                                 aFilter: string);
      procedure btnBrowseBackupClick(Sender: TObject);
      // OnSelectionChange, NOT OnChange -- and hence the extra parameter.  An
      // LCL TListBox has no OnChange at all (TComboBox does, which is why only
      // the two list boxes differ), so this is TSelectionChangeEvent; `User` is
      // True when the operator moved the selection and False when code did.
      // Both handlers ignore it deliberately: re-showing the selected item's
      // fields is correct either way.
      procedure lstClustersChange(Sender: TObject; User: boolean);
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
      procedure btnUseRotatorClick(Sender: TObject);
      procedure ShowActiveRotator;
      // TSelectionChangeEvent -- see lstClustersChange above.
      procedure lstRotatorsChange(Sender: TObject; User: boolean);
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

      { THE SEARCH BOX.  Not streamed: the results list is created in code, so
        it must not be a published field or Lint-FormFields would demand a
        component for it in the resource.

        A CHILD LISTBOX, NOT A POPUP FORM.  A popup would have to be shown with
        SW_SHOWNOACTIVATE and hand focus back by hand; a child control simply
        never takes focus, because nothing focuses it. The overlay only needs to
        cover this window's own content, and Preferences is a fixed-size window,
        so there is nothing a popup would buy. }
      FSearchList: TListBox;
      FSearchHits: array of TPrefsSearchHit;
      FSearchIndexBuilt: boolean;
      FSearchIndex: array of TPrefsSearchEntry;
      { Generated rows that are DISPLAY-ONLY and therefore deliberately not
        bound -- see AddGeneratedRows. They have no binding for BuildSearchIndex
        to walk, so they are collected here and appended to the index by hand.
        Without this, making them unsaveable would also make them unfindable,
        and "I can search and find every one of these" is a requirement. }
      FDisplayOnlyRows: array of TPrefsSearchEntry;
      { The CONTAINERS the generated sections created -- the pages, and the block
        panel added to a designed page. BuildBindings runs again on Cancel, so
        the generator runs again; without freeing these first the second pass
        raises "Duplicate name: a component named gen_… already exists" (NY4I hit
        exactly that, 2026-08-16). Containers only: freeing one frees its
        children, and tracking the children too would double-free them. }
      FGeneratedRoots: array of TControl;
      { The control a deep link or a search hit wants focused, held until
        QueueAsyncCall can act on it -- see FocusControlOnItsSection. }
      FPendingFocus: TWinControl;
      FFocusTimer: TTimer;
      FFocusTries: integer;

      { Controls bound to settings by KEY -- see uSettingsBinding.  Anything
        bound needs no load/save code of its own. }
      FBindings: TSettingBindings;

      { WHAT EACH COMMAND READ WHEN THE PAGE LOADED (name=value).  A command
        absent from here was never loaded through CommandText, and ApplyIfChanged
        then writes it unconditionally -- the old behaviour. }
      FLoaded: TStringList;
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
      { The colors page is ONE GRID, not a control per cell.

        It was 50 labels and 100 combo boxes, built when the form was
        constructed -- 150 windowed controls, each combo filled one item at a
        time.  That delayed opening PREFERENCES ITSELF by seconds and the page
        still drew empty (NY4I, 2026-08-21: "I stopped waiting for any of the
        color fields at 5 seconds").
        A TStringGrid with pick-list columns is one control with one editor,
        which is what uBandPlanForm already does for the same shape of data. }
      FColorGrid: TStringGrid;
      FColorElements: TStringList;   // row -> mweName, owned
      { Set once, the first time the rows are known. See SizeColorColumns. }
      FColorColumnsSized: boolean;
      { THE VALUE BEING CHOSEN RIGHT NOW, before the grid has taken it. The
        sample paints from this so the preview follows the drop-down as it is
        used -- see ColorGridSetEditText. -1 when nothing is being edited. }
      FPreviewCol: integer;
      FPreviewRow: integer;
      FPreviewText: string;
      FPalette: TStringList;         // the colour spellings, owned; see ColorGridSelectEditor

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
      { HOW DEEP IN A LOAD WE ARE, not whether we are in one.
        A boolean here was cleared by whichever inner scope finished FIRST:
        ShowSelectedCluster and ShowSelectedRotator both ran inside
        construction's own load and both ended with Loading := False, so the
        rest of construction ran unguarded and the bindings' change events
        drove a full CaptureProfileFields over controls that had not been
        populated yet.  Three other call sites had each grown their own
        wasLoading save/restore to work around it.  A counter cannot be
        cleared by an inner scope, so none of them need to. }
      FLoadingDepth: integer;
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
      navColors: TTreeNode;
      navLogging: TTreeNode;
      navBackup: TTreeNode;
      navContest: TTreeNode;
      navMore: TTreeNode;
      navCW: TTreeNode;
      navAudio: TTreeNode;
   navPaddlePTT: TTreeNode;
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

      { Bracket every routine that WRITES controls from the store.  Always in
        a try/finally: an exception between them would otherwise leave the form
        permanently unable to notice an edit. }
      function  GetLoading: boolean;
      procedure BeginLoading;
      procedure EndLoading;
      property Loading: boolean read GetLoading;

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
      procedure ShowClusterDirectoryState;
      procedure LoadClusterList;
      { The blanket "something was edited" marker.  See HookDirtyMarkers. }
      procedure MarkDirty(Sender: TObject);
      procedure HookDirtyMarkers(const aRoot: TWinControl);
      procedure HookDirtyMarker(const aControl: TWinControl);
      function  ClusterIsActive(const aCluster: TClusterDefinition): boolean;
      procedure ShowClusterRow(const aIndex: integer;
                               const aCluster: TClusterDefinition);
      procedure RefreshClusterRows;
      function  RotatorIsActive(const aRotator: TRotatorDefinition): boolean;
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
      { A command's STORED value -- the startup default the page edits. }
      function  CommandText(const aCommand: string): string;

      { Apply and store, but ONLY if this differs from what the page loaded. }
      function  ApplyIfChanged(const aCommand, aValue: string): boolean;
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

      { The Preferences search box -- see the SEARCH block in the implementation. }
      procedure BuildSearchIndex;
      procedure AddStationFieldsToSearchIndex(var aN: integer);
      procedure RunSearch(const aNeedle: string);
      procedure ActivateSearchHit(const aIndex: integer);
      procedure HideSearchResults;
      function SectionPanelFor(const aControl: TWinControl): TControl;
      function NavItemForTag(const aTag: NativeInt): TTreeNode;

      { Deep link: "open Preferences AT this setting."  ControlForCommand maps a
        legacy Ctrl-J command spelling to the control that edits it;
        FocusControlOnItsSection is the two-step (select the nav item, focus the
        control) that a search hit already performed inline. }
      { Open AT a page.  ControlForCommand deep-links to one CONTROL; this
        selects a whole section, which is what a menu item naming a page wants
        -- Settings > Colors should land on Colors, not on wherever Preferences
        was last left (NY4I, 2026-08-21). }
      function  SelectPage(const aTag: NativeInt): boolean;

      function  ControlForCommand(const aCommand: string): TWinControl;
      procedure FocusControlOnItsSection(const aControl: TWinControl);
      procedure FocusTimerTick(Sender: TObject);
      procedure ScrollControlIntoView(const aControl: TControl);

      { SAY WHICH ROW WAS FOUND.  Scrolling to a hit and focusing it is enough
        for an edit box -- the caret is the indicator -- but a drop-down or a
        read-only row lands with nothing to look at, on a page of forty rows
        that all look alike (NY4I, 2026-08-21, on AUTO SEND CHARACTER COUNT).
        The row's CAPTION is marked rather than the control, because that is the
        one part every row shape has. }
      procedure HighlightSearchedRow(const aControl: TWinControl);
      procedure ClearSearchHighlight(const aRoot: TWinControl);

      { GENERATED SECTIONS -- the Ctrl-J replacement.

        One panel built at run time per key prefix, a label and a control per
        registered setting.  This is how 152 settings get a home without 152
        controls in the designer, and it is what makes regrouping them later a
        rename rather than a week in the form editor.

        Ctrl-J was itself a generic renderer -- a ListView over CFGCA -- so this
        is that idea moved into Preferences, with sections and search instead of
        one flat alphabetical list. }
      procedure BuildGeneratedSections;

      { THE COLORS PAGE.  Not a BuildGeneratedSection: those are driven by
        setting-key prefixes, and the main-window colors are not settings at
        all -- CheckCommand matches them by PREFIX against TWindows[..].mweName,
        so no CFGCA row exists for any of them.  The rows are generated from
        TWindows itself, which is the only list there is. }
      function  BuildColorsSection: integer;
      procedure ColorGridSelectEditor(Sender: TObject; aCol, aRow: integer;
                                      var Editor: TWinControl);
      procedure ColorGridPrepareCanvas(Sender: TObject; aCol, aRow: integer;
                                       aState: TGridDrawState);
      procedure SizeColorColumns;
      { AnsiString EXPLICITLY, and the compiler is what says so: TSetEditEvent
        is declared in the LCL, which is compiled with 8-bit strings, while
        `string` in this unit is UnicodeString (tr4w.inc). A method assigned to
        an event has to match its signature exactly. }
      procedure ColorGridSetEditText(Sender: TObject; aCol, aRow: integer;
                                     const aValue: AnsiString);
      procedure ColorGridEditingDone(Sender: TObject);
      procedure LoadColorRows;
      procedure SaveColorRows;
      function  BuildGeneratedSection(const aTag: NativeInt; const aHeading: string;
                                      const aPrefixes: array of string): integer;
      function  AddGeneratedRows(const aParent: TWinControl; const aKeyPrefix: string;
                                 var aY: integer): integer;
      // The OnClick of the "Edit..." button a ctFreqList row gets instead of a
      // dead text box. One handler for both such rows, because there is one
      // editor and it edits the whole band plan -- there is nothing to branch
      // on, so this is not the branch-on-Sender the house rule forbids.
      procedure GeneratedBandPlanClick(Sender: TObject);
      procedure BuildGeneratedBlock(const aParent: TWinControl; const aTop: integer;
                                    const aHeading: string;
                                    const aPrefixes: array of string);
      procedure TrackGeneratedRoot(const aControl: TControl);
      { A control backed by the STORE rather than by a CFGCA command. It has no
        legacy command name, so it is registered under its own caption and is
        findable by search but never by ShowPreferencesForCommand -- which is
        correct: there is no command to open it AT. }
      procedure AddStoreBackedToSearchIndex(var aN: integer;
                                            const aControl: TWinControl;
                                            const aCaption: string = '');
      procedure AddHandWiredToSearchIndex(var aN: integer; const aCommand: string;
                                          const aControl: TWinControl);
      procedure SearchListClick(Sender: TObject);
      { BOTH TYPES QUALIFIED, and that is not pedantry: FPC's Windows unit
        declares its OWN TOwnerDrawState and TRect, and this unit uses Windows
        in the implementation section. Unqualified, the declaration and the
        implementation name different types with identical spellings, and FPC
        reports a header mismatch printing two signatures that read the same. }
      procedure SearchListDrawItem(Control: TWinControl; Index: Integer;
                                   ARect: Types.TRect;
                                   State: StdCtrls.TOwnerDrawState);
      { Visitors. Each is a method because each needs Self anyway -- one to reach
        the form's helpers, one to record what it found. }
      procedure LoadHardwarePanel;
      procedure SaveHardwarePanel;
      { ONE parallel-port picker, used by all four. They differ only in which
        command they carry, and four copies of the detection-and-collapse rules
        would drift the first time one of them was corrected. }
      procedure LoadLPTCombo(const aCombo: TComboBox; const aLabel: TLabel;
                             const aCommand: string);
      procedure SaveLPTCombo(const aCombo: TComboBox; const aCommand: string);
      procedure BuildNavTree;
      procedure NoteRadiosNavItem(item: TTreeNode);
      procedure ApplyChevrons;

      function  KeyerIdForOutput(const aOutput: string): string;
      function  RadioNameForId(const aId: string): string;
      procedure FillRadioNameCombo(const aCombo: TComboBox;
                                   const aSelected, aUsedByOtherSlot,
                                   aOtherSlotLabel: string);
      procedure FillCWOutputCombo(const aCombo: TComboBox;
                                  const aSelected, aRadioId: string);
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

   // 28 and 29 are layPaddlePTT and layAudio, which carry literal Tags in the
   // .lfm rather than these constants. 30 is the first free number.
   //
   // A HOLDING PAGE for the settings that left Ctrl-J and have no designed page
   // yet. It is meant to shrink to nothing: each time a page is designed, its
   // settings' key prefix changes and they move off here. Named on screen as
   // what it is, so it does not read as a permanent home.
   NAV_MORE              = 30;

   // Colors. A page of its own under Appearance rather than a block on it:
   // fifty elements with two drop-downs each is a hundred controls, and the
   // designed panel has room for a small block and no more.
   NAV_COLORS            = 31;


// Opens Preferences, creating it on first use.  Called from the PREF
// call-window command.
procedure ShowPreferences;

// Opens Preferences AT a specific setting: the section that owns aCommand is
// selected and the control that edits it is focused, so the operator lands on
// the field rather than on a page to go hunting through.
//
// aCommand is the legacy Ctrl-J spelling ('MY GRID', 'COMPUTER ID'), which is
// what the rest of TR4W already uses to name a setting -- see CFGCA in uCFG.
//
// RETURNS FALSE IF THE COMMAND IS NOT ON ANY PANEL, and the form is then left
// showing whatever it showed before.  The caller MUST handle that rather than
// assume: guessing wrong here is what the Ctrl-J path used to do, silently
// selecting row 0 when it could not find the command (uOption.pas).
function ShowPreferencesForCommand(const aCommand: string): boolean;

// Open Preferences AT a section, by its nav tag (the NAV_* constants).
function ShowPreferencesAtPage(const aTag: NativeInt): boolean;

implementation

{$R *.lfm}

uses
   uLPTPortEnumerator,   // which parallel ports this machine actually has
   StrUtils,             // IfThen
   Math,                 // Max -- clamping the scroll position
   uLCLTranslate,
   uPrefsSearch,   // PrefsMatchScore -- the ranking, unit tested without a UI
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
   uTelnet,     // TelnetRefreshClusterList -- the cluster window's drop-down
   uUDPBroadcaster,   // TestDestination, and Configure once the settings are saved
   uTCIServer,        // started/stopped when the check box is saved
   uFileText,          // FileTextExists -- System.IOUtils is Delphi-only
   LCLIntf,     // OpenDocument -- open the log in the operator's editor
   uCFG,        // CFGCommandValueAsString / SetCFGCommandValue -- Station edits CFGCA rows
   uSettingsRegistry,     // the settings themselves
   uSettingsLegacy,       // ActiveStoreProvider -- graduated settings write to OUR store
   uAppPaths,             // DataFilePath -- shipped read-only data
   uSettingsDeclarations, // DeclareAllSettings
   ComPortEnumerator,   // the real serial ports, same source as the radio editor
   uRotatorBase,        // UsesSerialPort / PreferredBaudRate -- asked, not assumed
   uRotatorControl,     // rebuild the live rotators when the library is saved
   uRotatorRegistry,    // the rotator type list comes from the registry
   uCallSignRoutines,   // IsAGoodCall -- the MY CALL sanity check
   uBandPlanForm,       // ShowBandPlan -- the two ctFreqList rows' Edit button.
                        // Direct, not via uBMCF: that unit is the seam for the
                        // Win32 caller (uOption) and drags VC/TF/Tree/LogWind
                        // in with it; an LCL form calls the LCL form.
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

// OPENING A SETTINGS WINDOW MUST NOT BE ABLE TO TAKE DOWN A CONTEST LOGGER.
// An exception escaping here reaches the message loop, and under FPC that is a
// bare "RTE 217" on the console with no class, no message and no location --
// which is exactly the state the LCL port was in when this guard was written
// (2026-08-13).  The handler is PERMANENT, not a debugging aid to be removed
// once that fault is found: an operator mid-contest should lose Preferences,
// not the log.
//
// The phase string is the diagnostic.  gPrefsForm is nil on entry to the first
// open and a failing constructor destroys its own instance, so a construction
// failure leaves the global nil and the next open retries cleanly; a failure
// after that point leaves a form that exists but may not be usable, which the
// phase name distinguishes in the log.
procedure ShowPreferences;
var
   sw: TStopwatch;
   phase: string;
begin
   sw := TStopwatch.StartNew;
   phase := 'construct';

   try
      if gPrefsForm = nil then
         begin
         gPrefsForm := TPrefsForm.Create(nil);

         // OWNED BY THE MAIN WINDOW, like every other form TR4W shows.
         //
         // Without this the form has no PopupParent, and PopupMode pmAuto
         // resolves to Application.MainForm -- which is NIL here, because TR4W
         // never calls Application.CreateForm.  So Preferences was a top-level
         // window owned by nothing: switching to another program and back
         // brought the MAIN window forward and left this one behind, and the
         // operator had to reopen Preferences to see it again (NY4I,
         // 2026-08-23).
         //
         // OwnFormByMainWindow sets PopupParent / pmExplicit, which is what
         // makes a window follow its owner on activate and restore.  It is the
         // same call the converted tool windows use.
         OwnFormByMainWindow(gPrefsForm);

         LogPhase(sw, 'CONSTRUCT first open', True);
         end;

      phase := 'show';
      gPrefsForm.Show;

      phase := 'bring to front';
      gPrefsForm.BringToFront;
      LogPhase(sw, 'Show + BringToFront');
   except
      on E: Exception do
         begin
         logger.Error(Format('[Prefs] FAILED during %s: %s: %s',
                             [phase, E.ClassName, E.Message]));
         ShowMessage(Format(TC_PREFERENCESCOULDOPENEDS + #13#10 +
                            '%s: %s'#13#10#13#10 +
                            'Logging continues normally; see tr4w.log.',
                            [phase, E.ClassName, E.Message]));
         end;
      end;
end;

function ShowPreferencesAtPage(const aTag: NativeInt): boolean;
begin
   Result := False;
   ShowPreferences;
   if gPrefsForm = nil then
      begin
      Exit;
      end;
   Result := gPrefsForm.SelectPage(aTag);
end;

function ShowPreferencesForCommand(const aCommand: string): boolean;
var
   ctl: TWinControl;
begin
   Result := False;

   // Open first: the form has to exist before it can be asked which control
   // edits a command, and the operator should see Preferences either way. A
   // command we cannot locate is still better served by an open Preferences
   // window than by nothing at all.
   ShowPreferences;

   if gPrefsForm = nil then
      begin
      Exit;
      end;

   try
      ctl := gPrefsForm.ControlForCommand(aCommand);
      if ctl = nil then
         begin
         // NOT silent. This is the failure the old Ctrl-J path hid by selecting
         // row 0; if a command ever loses its control, the log says which one.
         logger.Warn('[Prefs] no control edits "%s" -- opened Preferences ' +
                     'without a deep link', [aCommand]);
         Exit;
         end;

      gPrefsForm.FocusControlOnItsSection(ctl);
      Result := True;
      logger.Debug('[Prefs] deep link -> %s (%s)', [aCommand, ctl.Name]);
   except
      on E: Exception do
         begin
         logger.Error('[Prefs] deep link to "%s" failed: %s: %s',
                      [aCommand, E.ClassName, E.Message]);
         end;
      end;
end;


{ Supplies the store a graduated setting should write to.

  A plain function, not a method, because ActiveStoreProvider is a `function:
  TObject` -- deliberately, so uSettingsLegacy does not have to know this form
  exists.  It reads the single form instance, as the rest of this unit does.

  Nil-safe on purpose: a provider that returned a dangling store would corrupt
  a save rather than fail one. }
function ProvideActiveStore: TObject;
begin
   if gPrefsForm <> nil then
      begin
      Result := gPrefsForm.FStore;
      end
   else
      begin
      Result := nil;
      end;
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
   LogPhase(FTiming, 'stream .lfm');

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

   // Hand the WORKING COPY to the settings registry, so a graduated setting
   // (RegisterStoredSetting) writes to the store this form will save, not to a
   // fresh one loaded from disk. That is what keeps Cancel meaning Cancel.
   // Cleared in the destructor -- a provider outliving the form would hand out
   // a freed store.
   uSettingsLegacy.ActiveStoreProvider := ProvideActiveStore;

   // BEFORE SelectFirstSection, which selects the first top-level node and so
   // has nothing to select until the tree exists.  Under FMX the 27 nav items
   // were streamed with the form and no call was needed; the LCL cannot stream
   // them (see BuildNavTree), and the port left the routine written but
   // uncalled -- which opened Preferences with an empty navigation strip and no
   // error anywhere, because an empty tree is not a failure to any layer here.
   BuildNavTree;
   LogPhase(FTiming, 'BuildNavTree');

   // THE SEARCH RESULTS OVERLAY, created here rather than streamed.
   //
   // A child of the FORM, not of the nav strip or the content panel: it has to
   // straddle both, exactly as the Windows Settings drop-down spills over the
   // page beneath it. Parenting it to either one would clip it at that control's
   // edge.
   //
   // Created in code, so it is a private field and NOT published -- a published
   // field with no component in the .lfm is what Lint-FormFields exists to
   // catch.
   FSearchList := TListBox.Create(Self);
   FSearchList.Parent   := Self;
   FSearchList.Visible  := False;
   FSearchList.TabStop  := False;   // Tab must skip it: focus belongs to the box
   FSearchList.SetBounds(4, 28, 430, 200);
   FSearchList.Style       := lbOwnerDrawFixed;   // ItemHeight is only honoured here
   FSearchList.ItemHeight  := 26;                 // room to breathe; the default is font-tall
   FSearchList.BorderStyle := bsSingle;
   FSearchList.OnClick     := SearchListClick;
   FSearchList.OnDrawItem  := SearchListDrawItem;
   LogPhase(FTiming, 'SearchOverlay');

   SelectFirstSection;
   LogPhase(FTiming, 'SelectFirstSection');
   LoadStore;
   LogPhase(FTiming, 'LoadStore');
   RefreshAll;
   LogPhase(FTiming, 'RefreshAll');

   // AFTER the form is populated, so that loading cannot mark it dirty even if
   // a future Load routine forgets to set Loading.  Belt and braces on purpose:
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
   // Before FStore goes: a provider still pointing here would hand a freed
   // store to the next setting that tried to save.
   uSettingsLegacy.ActiveStoreProvider := nil;

   FreeAndNil(FBindings);
   FreeAndNil(FLoaded);
   FreeAndNil(FColorElements);
   FreeAndNil(FPalette);
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
         SaveConfig(StoreFileName, FStore, FKeyerStore, FUDPConfig);
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
         ShowMessage(TC_THESEENTRIESWEREACCEPTEDBEENSAVED
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
      // BEFORE the write, and this is THE save path.  The colour rows are not
      // bindings -- they edit TWindows, not settings -- so SaveAll does not know
      // about them and they have to be folded into the store by hand.
      //
      // The first version called this from the LEGACY MIGRATION branch above,
      // which only runs on a station being converted from the old radio ini, so
      // on every ordinary save it never ran at all: colours applied on screen,
      // the store's "colors" stayed {}, and the next start restored the
      // defaults (NY4I, 2026-08-22: "I changed and saved values of certain
      // colors but when I started up again, they were reverted black").
      SaveColorRows;

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
      // originally started only from tr4w.lpr, which reproduced the exact
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
               ShowMessage(Format(TC_TCISERVERCOULDOPENPORTDS,
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
   { A REFILL, NOT AN EDIT. Clearing and repopulating a control raises its
     change events, and this form answers those by writing the model FROM the
     controls -- so a refill that is not fenced can save a half-built state.
     Guarding here rather than at each call site means a new caller cannot get
     it wrong. }
   BeginLoading;
   try
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
   finally
      EndLoading;
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
{ The keyer id behind a CW-output choice, or '' when the choice is a sentinel
  ('CAT', 'NONE') or names no keyer. }
function TPrefsForm.KeyerIdForOutput(const aOutput: string): string;
var
   keyer: TKeyerDefinition;
begin
   Result := '';
   if (Trim(aOutput) = '') or
      SameText(aOutput, CWOUTPUT_CAT) or
      SameText(aOutput, CWOUTPUT_NONE) then
      begin
      Exit;
      end;
   keyer := FKeyerStore.FindKeyer(aOutput);
   if keyer <> nil then
      begin
      Result := keyer.Id;
      end;
end;

{ The name to SHOW for a stored id, or '' when the id names nothing. }
function TPrefsForm.RadioNameForId(const aId: string): string;
var
   radio: TRadioDefinition;
begin
   Result := '';
   radio := FStore.FindRadioById(aId);
   if radio <> nil then
      begin
      Result := radio.Name;
      end;
end;

procedure TPrefsForm.FillRadioNameCombo(const aCombo: TComboBox;
                                        const aSelected, aUsedByOtherSlot,
                                        aOtherSlotLabel: string);
var
   i: integer;
   id, name, shown: string;
begin
   { THE TAG IS THE RADIO'S ID, the caption is its name. A profile references
     by id, so the control has to hand one back -- and the operator still picks
     a radio by the name they gave it. aSelected and aUsedByOtherSlot are ids
     for the same reason. }
   ClearComboItems(aCombo);
   AddComboItem(aCombo, TC_PREFS_NONE, '');
   for i := 0 to FStore.RadioCount - 1 do
      begin
      id    := FStore.Radio(i).Id;
      name  := FStore.Radio(i).Name;
      shown := name;

      // The exception is THIS slot's own current value.  A profile written
      // before this rule can legitimately hold the same radio twice, and
      // marking the very item the combo has to display would leave the control
      // showing a decorated name -- hiding the conflict instead of showing it.
      if (aUsedByOtherSlot <> '') and
         SameText(id, aUsedByOtherSlot) and
         (not SameText(id, aSelected)) then
         begin
         // THE ROW STILL SAYS SO, IT IS JUST NOT GREYED.  FMX let an item be
         // Enabled := False; an LCL combo holds plain strings and has no
         // per-item enable.  No enforcement is lost: FMX's greying never
         // enforced anything either -- ItemByPoint tests only Visible, so a
         // greyed item was still selectable, and the actual refusal has always
         // lived in the OnChange handler.  What is lost is the visual cue, and
         // the caption carries that (TC_PREFS_RADIOINUSE names the other slot).
         shown := Format(TC_PREFS_RADIOINUSE, [name, aOtherSlotLabel]);
         AddComboItem(aCombo, shown, id);
         Continue;
         end;

      AddComboItem(aCombo, shown, id);
      end;
   SelectByTag(aCombo, aSelected);
end;

// The CW output for a profile slot is A CHOICE OF THE CONFIGURED KEYING
// METHODS (NY4I, 2026-08-07) -- not a raw COM port.  This used to offer every
// port on the machine plus 'CW by CAT', which asked the operator to remember
// which port had a keyer on it and to re-answer that question in every profile.
// Now a keyer is DEFINED once in the keyer library and REFERENCED here by name,
// exactly as a radio is.
// THE RADIO IS NAMED BY ID, NOT BY DISPLAY NAME.  A radio's id is a GUID and
// its name is an operator-chosen label, so the two can never coincide -- and
// both the radio combo's item tag and the profile's Radio1Id/Radio2Id already
// hold the id.  This routine alone wanted a name, and the interactive path
// (OnRadioComboChanged) passed it the combo tag, which is an id: FindRadio is
// a name-only lookup, so it returned nil, the whole radio-relative block was
// skipped, and neither 'CW by CAT' nor the radio keyer port was offered.  It
// failed silently and only when the operator CHANGED a radio -- loading a
// saved profile converted the id first and worked, which is what made it look
// like the IC-7100 lacked a capability it declares (NY4I, 2026-08-31).
procedure TPrefsForm.FillCWOutputCombo(const aCombo: TComboBox;
                                       const aSelected, aRadioId: string);
var
   i: integer;
   radio: TRadioDefinition;
   offered: string;
begin
   ClearComboItems(aCombo);
   AddComboItem(aCombo, TC_PREFS_NONE, CWOUTPUT_NONE);

   // The two RADIO-RELATIVE choices, offered only when the slot's radio can
   // actually provide them.  Both are properties of that radio, not devices --
   // see uKeyerConfigStore's header for where the line falls.
   radio := nil;
   if Trim(aRadioId) <> '' then
      begin
      radio := FStore.FindRadioById(aRadioId);
      end;

   { OBSERVABLE FOR THE UI HARNESS.  An id that fails to resolve is the exact
     signature of the name-versus-id defect this routine had, and nothing
     reported it: the combo simply came up short two entries.  The harness
     asserts on UNRESOLVED, so the defect cannot return silently. }

   if logger.IsDebugEnabled then
      begin
      if (Trim(aRadioId) <> '') and (radio = nil) then
         begin
         logger.Debug('[Prefs] CW output combo: radio id=%s UNRESOLVED', [aRadioId]);
         end
      else if radio <> nil then
         begin
         { declaresCAT comes from the SAME call the combo uses to decide, so the
           harness asserts an internal invariant rather than re-encoding which
           radios can key over CAT -- a second copy of that list would drift. }

         logger.Debug('[Prefs] CW output combo: radio id=%s resolved name=%s registryId=%s declaresCAT=%s',
                      [aRadioId, radio.Name, radio.RegistryId,
                       BoolToStr(SupportsForId(radio.RegistryId, rcCWByCAT), True)]);
         end;
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

   { The tags actually on offer, so the harness can assert that a radio
     declaring rcCWByCAT is given the CAT choice. }

   if logger.IsDebugEnabled then
      begin
      offered := '';
      for i := 0 to aCombo.Items.Count - 1 do
         begin
         if offered <> '' then
            begin
            offered := offered + ',';
            end;
         offered := offered + aCombo.Items[i];
         end;
      logger.Debug('[Prefs] CW output combo: offering [%s]', [offered]);
      end;
end;

{ THE MIRROR, NOT THE REFERENCE -- since keyers gained ids, a profile written
  by this build already points at the right device and this changes nothing it
  depends on. It stays for two reasons: the name is what the file and the combo
  show, so it must not go stale; and a profile written BEFORE keyer ids has no
  id yet and is still resolved by name until it is next saved. }
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
   { A REFILL, NOT AN EDIT. Clearing and repopulating a control raises its
     change events, and this form answers those by writing the model FROM the
     controls -- so a refill that is not fenced can save a half-built state.
     Guarding here rather than at each call site means a new caller cannot get
     it wrong. }
   BeginLoading;
   try
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
   finally
      EndLoading;
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
         ShowMessage(Format(TC_KEYERNAMEDSALREADYEXISTS, [FKeyerEditClone.Name]));
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
      ShowMessage(Format(TC_SSTILLUSEDBYS, [target.Name, used]));
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
   { A REFILL, NOT AN EDIT -- and it has to say so itself, because every caller
     would otherwise have to remember.

     Clear and the SelectByTag below both raise OnChange, and OnChange runs
     CaptureProfileFields, which writes the profile's radio ids FROM THE COMBO
     BOXES. Mid-refill those are not in a state worth saving, so a profile could
     be written back with empty slots. That is what renaming a profile did:
     "renaming a profile clears out the radios defined in the combo boxes"
     (NY4I, 2026-08-28) -- the same shape as the radio rename fixed in
     ab2a9b8d, one level up. }
   BeginLoading;
   try
   keep := SelectedTag(cbxProfile);
   if keep = '' then
      begin
      keep := FStore.ActiveProfileName;
      end;

   ClearComboItems(cbxProfile);
   for i := 0 to FStore.ProfileCount - 1 do
      begin
      AddComboItem(cbxProfile, FStore.Profile(i).Name, FStore.Profile(i).Name);
      end;
   SelectByTag(cbxProfile, keep);
   if logger.IsDebugEnabled then
      begin
      logger.Debug('[Prefs] profile combo rebuilt: %d profile(s), keep="%s" ' +
                   '-> ItemIndex=%d, SelectedTag="%s"',
                   [FStore.ProfileCount, keep, cbxProfile.ItemIndex,
                    SelectedTag(cbxProfile)]);
      end;
   finally
      EndLoading;
   end;
end;

procedure TPrefsForm.RefreshProfileFields;
var
   prof: TStationProfile;
begin
   // Loading guards the OnChange handlers: filling a combo fires OnChange, and
   // without this the act of DISPLAYING a profile would write the previous
   // profile's values into it.
   BeginLoading;
   try
      prof := CurrentProfile;

      { NO CURRENT PROFILE, BUT PROFILES EXIST, IS A TRANSIENT -- NOT AN ANSWER.

        THIS is what emptied the combos when a profile was renamed, and it took
        three wrong fixes to find because it clears the DISPLAY without touching
        the model: the log showed both slots filled correctly (ItemIndex 3 and
        7), no capture ever cleared them, and the rename produced no fill at all
        -- because it came through here instead.

        CurrentProfile resolves the profile combo's selection, and immediately
        after a rename that selection can name a profile that no longer exists
        under that name. The honest answer then is "ask again", not "there is no
        profile": fall back to the active one, or the first, and only truly
        empty the panel when the store really has none.

        NY4I, three times: "renaming a profile clears out the radios defined in
        the combo boxes." }
      if (prof = nil) and (FStore.ProfileCount > 0) then
         begin
         prof := FStore.FindProfile(FStore.ActiveProfileName);
         if prof = nil then
            begin
            prof := FStore.Profile(0);
            end;
         if logger.IsDebugEnabled then
            begin
            logger.Debug('[Prefs] no profile for combo tag %s -- falling back to "%s"',
                         [SelectedTag(cbxProfile), prof.Name]);
            end;
         SelectByTag(cbxProfile, prof.Name);
         end;

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
         FillRadioNameCombo(cbxRadio1, prof.Radio1Id, prof.Radio2Id, TC_PREFS_RADIO2);
         FillRadioNameCombo(cbxRadio2, prof.Radio2Id, prof.Radio1Id, TC_PREFS_RADIO1);
         if logger.IsDebugEnabled then
            begin
            logger.Debug('[Prefs] filled "%s": r1 id=%s -> ItemIndex=%d, r2 id=%s -> ItemIndex=%d',
                         [prof.Name, prof.Radio1Id, cbxRadio1.ItemIndex,
                          prof.Radio2Id, cbxRadio2.ItemIndex]);
            end;
         FillCWOutputCombo(cbxCW1, prof.CWOutput1, prof.Radio1Id);
         FillCWOutputCombo(cbxCW2, prof.CWOutput2, prof.Radio2Id);
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

      // BEFORE THE FIRST PANEL LOADS, not with the bindings.  BuildBindings runs
      // AFTER the hand-written panels, so clearing there threw away the very
      // snapshot they had just taken and every one of their settings looked
      // dirty -- which is the clobber this exists to stop.
      if FLoaded = nil then
         begin
         FLoaded := TStringList.Create;
         end;
      FLoaded.Clear;

      chkAutoConnect.Checked := FStore.AutoConnectOnStartup;
      LogPhase(FTiming, '  profile combos');
      LoadStationPanel;
      LogPhase(FTiming, '  Station');
      LoadExternalSoftwarePanels;
      LoadHardwarePanel;
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
      EndLoading;
   end;
end;

procedure TPrefsForm.RefreshAll;
begin
   { THE WHOLE SEQUENCE IS A REFILL, so nothing in it may be mistaken for the
     operator editing something.

     RefreshProfileFields already guarded itself, and that was not enough: the
     refills BEFORE it -- the radio list, the keyer list, the profile combo --
     each fire their own OnChange, and CaptureProfileFields answers those by
     writing prof.Radio1Name/Radio2Name FROM THE COMBO BOXES. During RefreshAll
     those combos still hold the previous state, so a model change made just
     before it could be written straight back out.

     That is how renaming a radio emptied the ACTIVE profile's second radio
     (NY4I, 2026-08-28). RenameRadio had correctly updated every profile --
     measured in his settings/tr4w.json, where the non-active profile "K4Z/K3"
     kept radio1 = "K40" while the active "K4D/K4Z" had lost its radio2 key
     entirely. Only the active one is written back from controls, which is
     exactly the one that lost it, and the next apply then reported the profile
     referring to a radio that no longer existed.

     BeginLoading counts depth, so the inner guards still work. }
   BeginLoading;
   try
      RefreshRadioList;
      RefreshKeyerList;
      RefreshProfileCombo;
      RefreshProfileFields;
      RefreshUDPList;
   finally
      EndLoading;
   end;
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
   if Loading then
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

function TPrefsForm.GetLoading: boolean;
begin
   Result := FLoadingDepth > 0;
end;

procedure TPrefsForm.BeginLoading;
begin
   Inc(FLoadingDepth);
end;

procedure TPrefsForm.EndLoading;
begin
   if FLoadingDepth > 0 then
      begin
      Dec(FLoadingDepth);
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
   if Loading then
      begin
      Exit;
      end;

   FStore.AutoConnectOnStartup := chkAutoConnect.Checked;
   SaveStationPanel;
   SaveExternalSoftwarePanels;
   SaveHardwarePanel;
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

   { AN EMPTY CONTROL IS NOT AN ANSWER.

     Everything above this line has been a fence around WHEN this runs, and
     renaming a profile still emptied both radio slots (NY4I, 2026-08-28, after
     the fences went in). So state the rule the fences were only approximating:
     a combo with no items in it has not been filled yet, and a control that
     has not been filled cannot be the authority for a stored value. Writing
     SelectedTag from one turns "I do not know yet" into "the operator chose
     nothing", which is how a rename erased two radios.

     This is deliberately about ITEMS, not about the selection. A filled combo
     sitting on its "None" row IS an answer and must still be honoured -- that
     is how a slot gets cleared on purpose. }
   { One line when it matters, so a third report can be diagnosed from a log
     instead of a guess: this has now been chased through two orderings. }
   if logger.IsDebugEnabled and
      ((cbxRadio1.Items.Count = 0) or (cbxRadio2.Items.Count = 0)) then
      begin
      logger.Debug('[Prefs] capture SKIPPED for %s -- radio combos hold %d/%d items',
                   [prof.Name, cbxRadio1.Items.Count, cbxRadio2.Items.Count]);
      end;

   { LOG THE HARMFUL EVENT ITSELF, not its neighbourhood. Two fences and an
     emptiness rule have all failed to stop a rename clearing both slots, and
     the SKIPPED line above never fired -- so the combos DO hold items and the
     selection is what is wrong. This says so, with everything needed to tell
     which: the profile, what is being overwritten, the item count and the
     selected index. }
   if logger.IsDebugEnabled then
      begin
      if (prof.Radio1Id <> '') and (SelectedTag(cbxRadio1) = '') then
         begin
         logger.Warn('[Prefs] CLEARING radio1 of "%s" (was %s); combo has %d item(s), ItemIndex=%d',
                     [prof.Name, prof.Radio1Name, cbxRadio1.Items.Count, cbxRadio1.ItemIndex]);
         end;
      if (prof.Radio2Id <> '') and (SelectedTag(cbxRadio2) = '') then
         begin
         logger.Warn('[Prefs] CLEARING radio2 of "%s" (was %s); combo has %d item(s), ItemIndex=%d',
                     [prof.Name, prof.Radio2Name, cbxRadio2.Items.Count, cbxRadio2.ItemIndex]);
         end;
      end;

   if cbxRadio1.Items.Count > 0 then
      begin
      prof.Radio1Id   := SelectedTag(cbxRadio1);
      prof.Radio1Name := RadioNameForId(prof.Radio1Id);
      end;
   if cbxRadio2.Items.Count > 0 then
      begin
      prof.Radio2Id   := SelectedTag(cbxRadio2);
      prof.Radio2Name := RadioNameForId(prof.Radio2Id);
      end;

   { THE CHOICE AND ITS ID TOGETHER. CWOutput carries 'CAT' or 'NONE' as
     itself and a keyer as its NAME; the id beside it is the reference and is
     empty for the two sentinels. Stamped here so a profile written by this
     build survives a keyer rename, and so an older profile picks one up the
     first time it is touched. }
   if cbxCW1.Items.Count > 0 then
      begin
      prof.CWOutput1   := SelectedTag(cbxCW1);
      prof.CWOutput1Id := KeyerIdForOutput(prof.CWOutput1);
      end;
   if cbxCW2.Items.Count > 0 then
      begin
      prof.CWOutput2   := SelectedTag(cbxCW2);
      prof.CWOutput2Id := KeyerIdForOutput(prof.CWOutput2);
      end;
   prof.SpeedSync1  := chkSpeedSync1.Checked;
   prof.SpeedSync2  := chkSpeedSync2.Checked;
   prof.SO2REnabled := chkSO2R.Checked;

   Dirty := True;
end;

{ -------------------------------------------------------------- events ---- }

{ ============================================================== SEARCH ===== }

const
   { How many rows the overlay shows. The list is a WINDOW onto the ranking, not
     the ranking itself -- putting every candidate into a TListBox is what made a
     726-item combo cost 1.8 seconds to populate. }
   SEARCH_MAX_HITS = 12;

function TPrefsForm.SelectPage(const aTag: NativeInt): boolean;
var
   navItem: TTreeNode;
begin
   // THROUGH THE TREE, not by showing the panel directly.  Assigning Selected
   // fires tvNavChange, which is the one place that decides which panel is
   // visible -- setting a panel's Visible here would leave the tree disagreeing
   // with the screen.  Same reasoning as FocusControlOnItsSection.
   Result := False;
   navItem := NavItemForTag(aTag);
   if navItem = nil then
      begin
      logger.Warn('[Prefs] no navigation item with tag %d', [aTag]);
      Exit;
      end;

   navItem.Selected := True;
   Result := True;
end;

function TPrefsForm.NavItemForTag(const aTag: NativeInt): TTreeNode;
var
   i: integer;
begin
   // tvNav.Items walks the WHOLE tree, children included -- the sections that
   // matter most here (WSJT-X, External Logger, MMTTY) are children of External
   // Software, and a top-level-only loop would silently never find them.
   Result := nil;
   for i := 0 to tvNav.Items.Count - 1 do
      begin
      if NavTagOf(tvNav.Items[i]) = aTag then
         begin
         Result := tvNav.Items[i];
         Exit;
         end;
      end;
end;

function TPrefsForm.SectionPanelFor(const aControl: TWinControl): TControl;
var
   c: TControl;
begin
   // Walk up to the child OF layContent -- that is the section panel, and it
   // carries the same Tag as its nav item. No table and no case statement,
   // exactly as tvNavChange works, so a section added in the designer is found
   // here automatically.
   Result := nil;
   c := aControl;
   while (c <> nil) and (c.Parent <> nil) do
      begin
      if c.Parent = layContent then
         begin
         Result := c;
         Exit;
         end;
      c := c.Parent;
      end;
end;

{ ------------------------------------------------- generated sections ----- }

// One generated panel per key prefix. Called from the constructor, after
// BuildNavTree so the nav items exist and before LoadStore so the bindings are
// in place when values are read.
//
// The prefix IS the placement rule: a setting registered as `contest.foo` lands
// on the Contest page and nowhere else. That is the whole of the layout policy,
// which is what makes "we will organise these once the contest factory is done"
// a rename rather than a redesign.
procedure TPrefsForm.BuildGeneratedSections;
var
   total, i: integer;
begin
   // IDEMPOTENT, because BuildBindings runs again every time the form reloads --
   // Cancel is the obvious one. Without this the second pass tried to create
   // `gen_contest_autoQslInterval` a second time and the LCL raised
   // "Duplicate name" over a half-built page (2026-08-16).
   //
   // Containers only. Freeing a scroll box frees the labels and controls inside
   // it; freeing those separately afterwards would be a double free.
   logger.Debug('[Prefs] BuildGeneratedSections: freeing %d previous root(s)',
                [Length(FGeneratedRoots)]);
   for i := High(FGeneratedRoots) downto Low(FGeneratedRoots) do
      begin
      FGeneratedRoots[i].Free;
      end;
   SetLength(FGeneratedRoots, 0);

   // The colors grid was a child of one of those scroll boxes and has just been
   // freed with it.  Left dangling, LoadColorRows would write into freed memory
   // the next time a page was shown.
   FColorGrid := nil;

   // Their index entries went with them. Left behind, they would point at freed
   // controls and a search hit would focus a dangling reference.
   SetLength(FDisplayOnlyRows, 0);

   // ONE GENERATED PAGE PER TAG THAT HAS NO DESIGNED PANEL.
   //
   // A generated page is a child of layContent carrying a section Tag, so it is
   // found by exactly the same tvNavChange loop as a designed one. That also
   // means a tag may have ONE panel: generating a page for a tag that already
   // has a designed panel would put two panels on screen at once, and binding a
   // second control to a key that already has one makes both write, with the
   // operator seeing whichever loaded last.
   //
   // Only NAV_CONTEST and NAV_ADVANCED are panel-less today. The rest of the
   // Ctrl-J tail therefore lands on "More settings" until each page is designed
   // -- see the heading text, which says so on screen rather than in a comment
   // nobody reads.
   total := 0;
   total := total + BuildGeneratedSection(NAV_CONTEST, 'Contest settings',
                                          ['contest.']);
   total := total + BuildGeneratedSection(NAV_ADVANCED, 'Advanced',
                                          ['advanced.']);
   total := total + BuildGeneratedSection(NAV_MORE,
      'More settings' + #13#10 +
      'Settings that left Ctrl-J and do not have a designed page yet. ' +
      'They work here; they will move to the pages named below.',
      ['operating.ctrlj.', 'cw.ctrlj.', 'appearance.ctrlj.', 'hardware.ctrlj.',
       'files.ctrlj.', 'bandmap.ctrlj.', 'network.ctrlj.', 'voice.ctrlj.',
       'cluster.ctrlj.']);

   // Onto the DESIGNED Appearance panel, below its controls (they end at
   // y=452 of 572, so there is room for a small block and no more).
   BuildGeneratedBlock(layAppearance, 462, 'Layout', ['appearance.layout.']);

   total := total + BuildColorsSection;

   logger.Info('[Prefs] generated sections: %d control(s) built', [total]);
end;

{ The colors grid's columns.  Shared by the builder and the editor callback,
  which is why they are not local to either. }
const
   COLORS_COL_ELEMENT = 0;
   COLORS_COL_FG      = 1;
   COLORS_COL_BG      = 2;
   { A LIVE PREVIEW, asked for by NY4I: "Is it possible to arrange this dialog
     to show in the table a sample of the text and background?" Two colour NAMES
     side by side do not answer "is that readable" -- LIGHT GRAY on WHITE reads
     fine as words and is nearly invisible on screen. }
   COLORS_COL_SAMPLE  = 3;

function TPrefsForm.BuildColorsSection: integer;
var
   box: TPanel;
   head: TLabel;
   e: TMainWindowElement;
   palette: TArray<string>;
   v, name: string;
   row: integer;
begin
   // A PANEL, NOT A SCROLL BOX, and the GRID does the scrolling.
   //
   // The other generated pages are scroll boxes because they are a tall column
   // of individual controls.  This one is a single grid that scrolls itself, and
   // nesting it in a scroll box gave neither of them a scrollbar: the box sized
   // itself to the grid, and the grid had been handed absolute bounds while the
   // page was still Visible := False, so it never knew it was too short for
   // fifty rows (NY4I, 2026-08-22: "colors grid has no scroll vertical bars").
   //
   // Aligned rather than positioned, so the layout is right whatever the page
   // is sized to and whenever it is first shown.
   box := TPanel.Create(Self);
   box.Parent      := layContent;
   box.Tag         := NAV_COLORS;
   box.Align       := alClient;
   box.BevelOuter  := bvNone;
   box.Caption     := '';
   box.Color       := clWindow;
   box.ParentColor := False;
   box.Visible     := False;
   TrackGeneratedRoot(box);

   head := TLabel.Create(box);
   head.Parent     := box;
   head.Caption    := 'Colors' + #13#10 +
                      'The colors of each main-window element. ' +
                      'Changes take effect when the window next repaints.';
   head.WordWrap   := True;
   head.Align      := alTop;
   head.Height     := 52;
   head.BorderSpacing.Around := 12;
   head.Font.Style := [fsBold];

   // FROM THE ENUM, through uRadioConfigApply.PaletteSpellings -- not a list
   // typed in here.  A hand-kept copy would offer a color this build does not
   // have the moment the palette changes, and the applier would then refuse it.
   palette := PaletteSpellings;

   // FREED FIRST: BuildGeneratedSections runs again on every reload (Cancel is
   // the obvious one), and this list is ours rather than a component's child,
   // so it is not freed with the page.  The grid IS a child of the scroll box
   // and goes with it; the pointer is re-assigned below.
   FreeAndNil(FColorElements);
   FColorElements := TStringList.Create;

   FColorGrid := TStringGrid.Create(box);
   FColorGrid.Parent      := box;
   FColorGrid.Align       := alClient;
   FColorGrid.BorderSpacing.Around := 12;
   // EXPLICIT.  Fifty rows will not fit whatever the page is sized to, so the
   // vertical bar has to be there; ssAutoBoth also covers a window narrowed
   // past the three columns.
   FColorGrid.ScrollBars  := ssAutoBoth;
   // NO Columns COLLECTION, and that is the fix rather than a simplification.
   //
   // The first version set ColCount := 3 AND added three Columns.  In the LCL
   // the collection DEFINES the column count, so the grid ended up with the
   // three configured columns plus three empty ones -- the white space to the
   // right of the values -- and a content width that no longer matched what was
   // drawn.  It never worked out that it needed to scroll, so fifty elements
   // showed about twenty-two and the rest were unreachable (NY4I, 2026-08-22).
   //
   // uBandPlanForm's grid, which works, uses ColCount and no collection.  This
   // one now does too, and the pick list arrives through OnSelectEditor -- the
   // LCL's own way to give a column a drop-down without a Columns entry, and
   // still ONE editor for the whole grid rather than a control per cell.
   FColorGrid.ColCount    := 4;   { element, text, background, sample }
   FColorGrid.FixedRows   := 1;
   FColorGrid.FixedCols   := 0;
   FColorGrid.Options     := FColorGrid.Options + [goEditing, goVertLine, goHorzLine,
                                                   goColSizing, goSmoothScroll];
   FColorGrid.Cells[COLORS_COL_ELEMENT, 0] := 'Element';
   FColorGrid.Cells[COLORS_COL_FG,      0] := 'Text';
   FColorGrid.Cells[COLORS_COL_BG,      0] := 'Background';
   FColorGrid.Cells[COLORS_COL_SAMPLE,  0] := 'Sample';
   { No fixed widths: SizeColorColumns measures the real content once the rows
     are loaded. Four numbers guessed here cannot survive a font-size change. }
   FColorGrid.OnSelectEditor  := ColorGridSelectEditor;
   { The grid paints the sample cell; nothing here creates a control, which is
     the whole reason this page is a grid rather than 150 windows. }
   FColorGrid.OnPrepareCanvas := ColorGridPrepareCanvas;
   FColorGrid.OnSetEditText    := ColorGridSetEditText;
   FColorGrid.OnEditingDone    := ColorGridEditingDone;
   FPreviewCol := -1;
   FPreviewRow := -1;

   FreeAndNil(FPalette);
   FPalette := TStringList.Create;
   for v in palette do
      begin
      FPalette.Add(v);
      end;

   row := 1;
   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      // A nameless element has no window of its own; there is nothing to color
      // and nothing for CheckCommand to have matched either.
      if TWindows[e].mweName = nil then
         begin
         Continue;
         end;
      name := string(AnsiString(TWindows[e].mweName));
      FColorElements.Add(name);
      Inc(row);
      end;

   FColorGrid.RowCount := FColorElements.Count + 1;
   LoadColorRows;

   Result := FColorElements.Count;
   logger.Debug('[Prefs] colors page: %d element(s) in one grid', [Result]);
end;

procedure TPrefsForm.ColorGridSelectEditor(Sender: TObject; aCol, aRow: integer;
                                           var Editor: TWinControl);
begin
   // COLUMN 0 IS THE ELEMENT NAME and is not editable.  Refusing an editor is
   // how a grid says that per-column when there is no Columns collection to
   // carry a ReadOnly flag.
   if (aCol = COLORS_COL_ELEMENT) or (aCol = COLORS_COL_SAMPLE) then
      begin
      { The sample is an OUTPUT. Editing it would offer to change a picture. }
      Editor := nil;
      Exit;
      end;

   // ONE editor, borrowed from the grid and refilled each time it is shown.
   // EditorByStyle is the LCL's own pick-list cell editor; nothing here creates
   // a control, which is the whole reason this page is a grid.
   Editor := TStringGrid(Sender).EditorByStyle(cbsPickList);
   if (Editor is TCustomComboBox) and (FPalette <> nil) then
      begin
      TCustomComboBox(Editor).Items.Assign(FPalette);
      end;
end;

{ The tr4wColors member a spelling names, or -1. The two tables are indexed by
  the same enum, so the name in the grid and the TColor to paint with are the
  same lookup. }
function ColorIndexForName(const aName: string): integer;
var
   c: tr4wColors;
begin
   Result := -1;
   for c := Low(tr4wColors) to High(tr4wColors) do
      begin
      if SameText(string(AnsiString(tr4wColorsSA[c])), Trim(aName)) then
         begin
         Result := Ord(c);
         Exit;
         end;
      end;
end;

{ PAINT THE SAMPLE CELL IN THE COLOURS ITS ROW DESCRIBES.

  OnPrepareCanvas rather than OnDrawCell: the grid still does the drawing, this
  only says what to draw it with, so selection, focus and the rest keep working.
  A row whose spelling matches nothing is left alone -- an unpainted cell is a
  visible "I do not know that colour", which is better than guessing black. }
procedure TPrefsForm.ColorGridPrepareCanvas(Sender: TObject; aCol, aRow: integer;
                                            aState: TGridDrawState);
var
   fg, bg: integer;
   fgName, bgName: string;
begin
   if (aCol <> COLORS_COL_SAMPLE) or (aRow < 1) then
      begin
      Exit;
      end;

   { The cell still holds the OLD spelling while the drop-down is open, so the
     value being chosen wins for the row it belongs to. That is what makes this
     a demonstration rather than a report: NY4I, 2026-08-28, "the change needs
     to be immediate. This is a way the user can demo the colors." }
   fgName := FColorGrid.Cells[COLORS_COL_FG, aRow];
   bgName := FColorGrid.Cells[COLORS_COL_BG, aRow];
   if aRow = FPreviewRow then
      begin
      if FPreviewCol = COLORS_COL_FG then
         begin
         fgName := FPreviewText;
         end
      else if FPreviewCol = COLORS_COL_BG then
         begin
         bgName := FPreviewText;
         end;
      end;

   fg := ColorIndexForName(fgName);
   bg := ColorIndexForName(bgName);
   if (fg < 0) or (bg < 0) then
      begin
      Exit;
      end;

   FColorGrid.Canvas.Brush.Color := tr4wColorsArray[tr4wColors(bg)];
   FColorGrid.Canvas.Font.Color  := tr4wColorsArray[tr4wColors(fg)];
end;

procedure TPrefsForm.LoadColorRows;
var
   i: integer;
   e: TMainWindowElement;
begin
   if (FColorGrid = nil) or (FColorElements = nil) then
      begin
      Exit;
      end;

   // FROM THE LIVE VALUES, not from the store.  The store may hold nothing yet
   // on a station that has never saved, and TWindows is what is actually on
   // screen -- which is what the operator is editing.
   FColorGrid.BeginUpdate;
   try
      for i := 0 to FColorElements.Count - 1 do
         begin
         FColorGrid.Cells[0, i + 1] := FColorElements[i];
         for e := Low(TMainWindowElement) to High(TMainWindowElement) do
            begin
            if (TWindows[e].mweName <> nil) and
               SameText(string(AnsiString(TWindows[e].mweName)), FColorElements[i]) then
               begin
               FColorGrid.Cells[1, i + 1] := string(AnsiString(tr4wColorsSA[TWindows[e].mweColor]));
               FColorGrid.Cells[2, i + 1] := string(AnsiString(tr4wColorsSA[TWindows[e].mweBackG]));
               { SOMETHING TO READ, not a swatch. The question the sample has to
                 answer is "can I read this during a contest", so it carries
                 letters and digits at the size the grid draws -- a plain block
                 of colour would not answer it. }
               FColorGrid.Cells[COLORS_COL_SAMPLE, i + 1] := 'W1AW 599 14.025';
               Break;
               end;
            end;
         end;
   finally
      FColorGrid.EndUpdate;
   end;

   SizeColorColumns;
end;

{ FIT THE COLUMNS TO WHAT IS IN THEM, ONCE.

  The widths were four fixed numbers -- 260/170/170/170 -- chosen before the
  Sample column existed. They were too wide for the three text columns and too
  narrow overall, so the page opened needing a horizontal scroll and the sample
  itself was cut off mid-word (NY4I's screenshot, 2026-08-28: "W1A|").

  AutoSizeColumns is the LCL's own measurement -- it asks the canvas about the
  real strings in the real font, which is the only thing that can answer this
  when the operator's font size is a setting.

  ONCE, AND ONLY ONCE, which is the other half of what was asked: "If the user
  resizes the columns or forms, we want to capture that but the default should
  be readable without scrolling." LoadColorRows runs again on Cancel-and-reload,
  and re-sizing there would silently undo a width the operator had dragged. }
{ EVERY KEYSTROKE AND EVERY PICK, while the editor is still open.

  The grid does not write the cell until editing finishes, so without this the
  sample only caught up after the operator moved away -- too late to be a
  preview. The chosen value is remembered and the row redrawn; nothing is
  written to the grid here, because the grid owns the cell and writing it
  underneath its own editor is how editors get confused. }
procedure TPrefsForm.ColorGridSetEditText(Sender: TObject; aCol, aRow: integer;
                                          const aValue: AnsiString);
begin
   FPreviewCol  := aCol;
   FPreviewRow  := aRow;
   FPreviewText := string(aValue);
   FColorGrid.InvalidateRow(aRow);
end;

{ The cell holds the value now, so the override has to go -- otherwise a stale
  preview would outlive the edit and paint the next row it happened to match. }
procedure TPrefsForm.ColorGridEditingDone(Sender: TObject);
begin
   FPreviewCol := -1;
   FPreviewRow := -1;
   FPreviewText := '';
   if FColorGrid <> nil then
      begin
      FColorGrid.Invalidate;
      end;
end;

procedure TPrefsForm.SizeColorColumns;
const
   { Breathing room either side of the text. AutoSize measures the glyphs; this
     is the margin that stops a cell reading as though it were clipped. }
   COLOR_COL_PADDING = 14;
var
   c: integer;
begin
   if FColorColumnsSized or (FColorGrid = nil) then
      begin
      Exit;
      end;

   FColorGrid.AutoSizeColumns;
   for c := 0 to FColorGrid.ColCount - 1 do
      begin
      FColorGrid.ColWidths[c] := FColorGrid.ColWidths[c] + COLOR_COL_PADDING;
      end;

   FColorColumnsSized := True;
end;

procedure TPrefsForm.SaveColorRows;
var
   i: integer;
begin
   if (FStore = nil) or (FColorGrid = nil) or (FColorElements = nil) then
      begin
      Exit;
      end;

   for i := 0 to FColorElements.Count - 1 do
      begin
      FStore.SetElementColors(FColorElements[i],
                              Trim(FColorGrid.Cells[1, i + 1]),
                              Trim(FColorGrid.Cells[2, i + 1]));
      end;

   // Straight onto the program as well as into the store, so the change is
   // visible without a restart -- the same reason ApplyLoggingSettings is
   // called from here.
   ApplyElementColors(FStore);
end;

// Build one generated page and return how many controls it carries.
//
// Returns 0 rather than failing when a prefix matches nothing -- a page with no
// settings is a real state while the tail is being re-homed -- but the count is
// logged, so an unexpected zero is visible instead of silent.
function TPrefsForm.BuildGeneratedSection(const aTag: NativeInt; const aHeading: string;
                                          const aPrefixes: array of string): integer;
var
   box: TScrollBox;
   head: TLabel;
   p: string;
   y, n: integer;
begin
   box := TScrollBox.Create(Self);
   box.Parent      := layContent;
   box.Tag         := aTag;          // tvNavChange finds it by this and nothing else
   box.Align       := alClient;
   box.BorderStyle := bsNone;
   box.Color       := clWindow;
   box.ParentColor := False;
   box.Visible     := False;         // tvNavChange owns visibility
   TrackGeneratedRoot(box);

   head := TLabel.Create(box);
   head.Parent    := box;
   head.Caption   := aHeading;
   head.WordWrap  := True;
   head.SetBounds(16, 12, 620, 40);
   head.Font.Style := [fsBold];

   y := 64;
   n := 0;
   for p in aPrefixes do
      begin
      n := n + AddGeneratedRows(box, p, y);
      end;

   Result := n;
   logger.Debug('[Prefs] generated page tag=%d -> %d setting(s)', [aTag, n]);
end;

// Append generated rows to an EXISTING DESIGNED PANEL, below whatever the
// designer put there.
//
// The other overload builds a whole page; this one adds a block to a page that
// already exists. It is how a setting reaches its real home without waiting for
// its whole page to be regenerated -- ROW COUNT and WINDOW SIZE went onto the
// designed Appearance panel this way (NY4I, 2026-08-16).
//
// The prefix is still the placement rule, so moving a setting here is a rename:
// `appearance.ctrlj.rowCount` became `appearance.layout.rowCount` and that
// alone took it off the holding page.
//
// aTop must clear the designed controls. There is no layout manager on these
// panels -- everything is absolutely positioned -- so a block placed too high
// silently overlaps rather than pushing anything down. Lint-FormOverlap checks
// the .lfm and cannot see runtime children, which is exactly why this takes an
// explicit top rather than guessing one.
procedure TPrefsForm.BuildGeneratedBlock(const aParent: TWinControl; const aTop: integer;
                                         const aHeading: string;
                                         const aPrefixes: array of string);
var
   host: TPanel;
   head: TLabel;
   p: string;
   y, n: integer;
begin
   // A HOST PANEL rather than parenting straight onto the designed page, so the
   // block is one thing to free when BuildBindings runs again. Parenting the
   // rows directly would leave them scattered among the designer's controls
   // with nothing to free them by.
   host := TPanel.Create(Self);
   host.Parent      := aParent;
   host.BevelOuter  := bvNone;
   host.Color       := clWindow;
   host.ParentColor := False;
   host.Caption     := '';
   host.SetBounds(0, aTop, aParent.Width, aParent.Height - aTop);
   TrackGeneratedRoot(host);

   y := 0;
   n := 0;

   head := TLabel.Create(host);
   head.Parent     := host;
   head.Caption    := aHeading;
   head.SetBounds(16, y, 500, 18);
   head.Font.Style := [fsBold];
   Inc(y, 26);

   for p in aPrefixes do
      begin
      n := n + AddGeneratedRows(host, p, y);
      end;

   host.Visible := n > 0;   // no heading, and no empty host, over nothing
   logger.Debug('[Prefs] generated block on %s -> %d setting(s)', [aParent.Name, n]);
end;

// Remember a generated container so the next BuildBindings can free it.
procedure TPrefsForm.TrackGeneratedRoot(const aControl: TControl);
var
   n: integer;
begin
   n := Length(FGeneratedRoots);
   SetLength(FGeneratedRoots, n + 1);
   FGeneratedRoots[n] := aControl;
end;

// Emit a label and a control for every registered setting whose key starts with
// aKeyPrefix, advancing aY. Returns how many rows it added.
//
// CONTROL CHOICE, in this order and for these reasons:
//   * ctBoolean            -> CHECK BOX. AllowedValues cannot answer this (it
//                             speaks only for ckArray), so a boolean would
//                             otherwise render as a text field that happily
//                             accepts "maybe".
//   * AllowedValues <> []  -> DROP-DOWN, filled BY THE BINDING from the setting
//                             itself. A ckArray is a discrete allow-list, so a
//                             text box offers values the program will refuse
//                             (NY4I, 2026-08-16).
//   * otherwise            -> text box.
//
// A read-only row (crJ 2 or 3) renders DISABLED rather than hidden: Ctrl-J
// showed those values and operators read them, so hiding them loses
// information -- but letting them be edited would invite changing something the
// next contest selection silently overwrites.
// The way back into the band plan editor.  See AddGeneratedRows for why the two
// ctFreqList rows carry a button rather than a text box.
//
// PARENT 0, NOT Self.Handle, and that is the documented contract rather than an
// omission: ShowModalOverWin32Parent disables a WIN32 parent because LCL modal
// forms disable only LCL ones.  Preferences IS an LCL form, so ShowModal
// already covers it, and passing a handle here would disable and re-enable it a
// second time from underneath the LCL's own bookkeeping.  uOption still passes
// its handle because it is still a raw Win32 window.
procedure TPrefsForm.GeneratedBandPlanClick(Sender: TObject);
begin
   ShowBandPlan(0);
end;
function TPrefsForm.AddGeneratedRows(const aParent: TWinControl; const aKeyPrefix: string;
                                     var aY: integer): integer;
const
   ROW_H   = 30;
   LABEL_W = 300;
   CTRL_X  = 330;
   CTRL_W  = 280;
var
   lbl: TLabel;
   chk: TCheckBox;
   cbo: TComboBox;
   edt: TEdit;
   btn: TButton;
   ctl: TWinControl;
   s: TSettingBase;
   n, n2: integer;
   ro: boolean;
begin
   n := 0;

   for s in AllSettings do
      begin
      if not SameText(Copy(s.Key, 1, Length(aKeyPrefix)), aKeyPrefix) then
         begin
         Continue;
         end;

      // DISPLAY-ONLY, and it must not be BOUND -- disabling is not enough.
      //
      // A binding is saved by SaveAll whether or not its control is enabled, so
      // a disabled control still writes its text back. For these rows that text
      // is a display form the parser refuses, and Preferences wrote
      // `SINGLE BAND SCORE=All` into tr4w.ini, breaking every later start with
      // "Invalid statement in config file" (2026-08-16). Not binding them is
      // the fix: a row that cannot be edited cannot be saved either.
      //
      // Two kinds qualify: crJ 2/3 (Ctrl-J showed them read-only too), and
      // ctFreqList, which is genuinely MULTI-VALUED and gets an Edit... button
      // below instead.
      //
      // ckList USED TO BE HERE and no longer is (2026-08-21).  Those rows have
      // a fixed spelling list, CFGCommandAllowedValues now enumerates it, and
      // they render as ordinary drop-downs.  What had kept them out was
      // diagnosed as space-padded spellings; that was wrong -- not one of the
      // 40 arrays is padded.  The real fault was case: the config loader
      // uppercases the line and the matcher compared case-sensitively, so the
      // six mixed-case spellings could be written and never read back.  Fixed
      // in TF.GetValueFromArray.
      ro := (s.LegacyCommand <> '') and
            (CFGCommandIsReadOnly(s.LegacyCommand) or CFGCommandIsList(s.LegacyCommand));

      lbl := TLabel.Create(aParent);
      lbl.Parent  := aParent;
      lbl.Caption := s.Caption;
      lbl.SetBounds(16, aY + 4, LABEL_W, 18);

      // A ctFreqList ROW GETS A WAY IN, not a dead box.  BAND MAP CUTOFF
      // FREQUENCY and FREQUENCY MEMORY are the only two, they are multi-valued
      // and so must stay unbound (see `ro` below and uCFG.pas:1247), but unlike
      // a ckList they HAVE an editor -- uBandPlanForm.  Rendering them as a
      // disabled edit box left that editor with no live caller in the whole
      // program once Ctrl-J stopped listing them: finding F3, 2026-08-20.
      //
      // The button is deliberately NOT bound.  A row that cannot be edited in
      // place still must not be saved from here; the band plan editor writes
      // [BAND PLAN] itself, as a section.
      if (s.LegacyCommand <> '') and CFGCommandIsFreqList(s.LegacyCommand) then
         begin
         btn := TButton.Create(aParent);
         btn.Parent  := aParent;
         btn.Caption := 'Edit...';
         btn.OnClick := GeneratedBandPlanClick;
         btn.SetBounds(CTRL_X, aY, 90, 24);
         ctl := btn;
         end
      else if ro then
         begin
         edt := TEdit.Create(aParent);
         edt.Parent   := aParent;
         edt.Text     := s.AsText;   // straight from the setting, never bound
         edt.ReadOnly := True;
         edt.Enabled  := False;
         edt.SetBounds(CTRL_X, aY, CTRL_W, 24);
         ctl := edt;
         end
      else if (s.LegacyCommand <> '') and CFGCommandIsBoolean(s.LegacyCommand) then
         begin
         chk := TCheckBox.Create(aParent);
         chk.Parent  := aParent;
         chk.Caption := '';
         chk.SetBounds(CTRL_X, aY + 2, 24, 22);
         FBindings.Bind(chk, s.Key);
         ctl := chk;
         end
      else if Length(s.AllowedValues) > 0 then
         begin
         cbo := TComboBox.Create(aParent);
         cbo.Parent := aParent;
         cbo.Style  := csDropDownList;   // the allow-list IS the list
         cbo.SetBounds(CTRL_X, aY, CTRL_W, 24);
         FBindings.Bind(cbo, s.Key);
         ctl := cbo;
         end
      else
         begin
         edt := TEdit.Create(aParent);
         edt.Parent := aParent;
         edt.SetBounds(CTRL_X, aY, CTRL_W, 24);

         // AN INTEGER ROW GETS AN INTEGER BOX.  This branch is the catch-all --
         // not read-only, not boolean, no allow-list -- and it rendered a plain
         // TEdit for everything, so an integer setting accepted letters. NY4I
         // typed "ewed" into Auto-CQ Delay Time, 2026-08-18.
         //
         // The type is already declared on the CFGCA row, so the panel can just
         // ask rather than the operator being trusted. Same shape as the
         // CFGCommandIsBoolean test above, which is what stops a boolean
         // rendering as a text box that accepts "maybe".
         edt.NumbersOnly := (s.LegacyCommand <> '') and
                            CFGCommandIsInteger(s.LegacyCommand);

         FBindings.Bind(edt, s.Key);
         ctl := edt;
         end;

      // PAIRS THE CAPTION TO THE CONTROL, and is how HighlightSearchedRow
      // finds one from the other.  FocusControl is the LCL's own way of saying
      // "this label belongs to that control" -- no parallel array, and a click
      // on the caption now lands in the field as it does everywhere else.
      lbl.FocusControl := ctl;

      if ro then
         begin
         // NOT ON A BAND-PLAN ROW.  It is `ro` for a different reason -- it
         // cannot be represented by one edit box -- and no contest sets it,
         // so that suffix would be a plain lie next to an Edit button.
         if not (ctl is TButton) then
            begin
            lbl.Caption := s.Caption + '   (set by the contest)';
            end;

         // Remembered for the search index. It has no binding, so
         // BuildSearchIndex would never see it -- and a row an operator cannot
         // find is barely better than one that is not there.
         n2 := Length(FDisplayOnlyRows);
         SetLength(FDisplayOnlyRows, n2 + 1);
         FDisplayOnlyRows[n2].Caption     := s.Caption;
         FDisplayOnlyRows[n2].Command     := s.LegacyCommand;
         FDisplayOnlyRows[n2].Control     := ctl;
         FDisplayOnlyRows[n2].SectionTag  := 0;   // resolved in BuildSearchIndex
         FDisplayOnlyRows[n2].SectionName := '';
         end;

      // NAMED: a nameless control is invisible to a bug report and to the
      // PostMessage-driven UI checks. Not PUBLISHED, so Lint-FormFields is
      // untroubled -- it checks published fields against the .lfm.
      //
      // THE NAME GOES ON BEFORE THE CAPTION IS CLEARED, and that order matters:
      // TControl.SetName copies the new Name into Caption when the caption still
      // matches the old name -- which it does on a control created moments ago
      // with both blank. Naming a check box last therefore captioned it
      // `gen_advanced_handLogMode` on screen (NY4I, 2026-08-16). The label to
      // its left already says what it is, so the caption is cleared after.
      ctl.Name := 'gen_' + StringReplace(s.Key, '.', '_', [rfReplaceAll]);
      if ctl is TCheckBox then
         begin
         TCheckBox(ctl).Caption := '';
         end;

      Inc(n);
      Inc(aY, ROW_H);
      end;

   Result := n;
end;

procedure TPrefsForm.BuildSearchIndex;
var
   i, n, k: integer;
   b: TSettingBinding;
   s: TSettingBase;
   ctl: TWinControl;
   panel: TControl;
   navItem: TTreeNode;
begin
   FSearchIndexBuilt := True;
   SetLength(FSearchIndex, 0);
   if FBindings = nil then
      begin
      Exit;
      end;

   n := 0;
   SetLength(FSearchIndex, FBindings.Count);
   for i := 0 to FBindings.Count - 1 do
      begin
      b := FBindings.Item(i);
      if b = nil then
         begin
         Continue;
         end;

      s   := FindSetting(b.Key);
      ctl := b.Control;
      if (s = nil) or (ctl = nil) then
         begin
         Continue;
         end;

      panel := SectionPanelFor(ctl);
      if panel = nil then
         begin
         Continue;
         end;

      FSearchIndex[n].Caption    := s.Caption;
      FSearchIndex[n].Command    := s.LegacyCommand;
      FSearchIndex[n].SectionTag := panel.Tag;
      FSearchIndex[n].Control    := ctl;

      // The section's own nav caption, so a hit reads
      // "CW Settings  >  Send a greeting" and the operator LEARNS the layout
      // instead of depending on search for ever.
      FSearchIndex[n].SectionName := '';
      navItem := NavItemForTag(panel.Tag);
      if navItem <> nil then
         begin
         FSearchIndex[n].SectionName := navItem.Text;
         end;

      Inc(n);
      end;
   SetLength(FSearchIndex, n);

   // THE HAND-WIRED PANELS, added 2026-08-16 (NY4I: "make sure I can search and
   // find every one of these").
   //
   // The comment that used to sit here said the shortfall was logged and left:
   // the Station panel and its neighbours call ApplyAndStoreCommand directly,
   // so they are not in FBindings and were invisible to search. In practice
   // that meant MY CALL and MY GRID could not be found -- two of the first
   // things anyone looks for.
   //
   // StationFields already pairs each command with its control, which is
   // everything an index entry needs, so this is a second pass over that list
   // rather than a second source of truth. The caption comes from the control's
   // own label where there is one, and falls back to the command spelling,
   // which is what an operator types anyway.
   AddStationFieldsToSearchIndex(n);

   // The generated DISPLAY-ONLY rows, which have no binding by design (a bound
   // row is a saved row, and these must never be written back -- see
   // AddGeneratedRows). Collected when they were created; the section tag is
   // resolved here, once they are parented.
   for k := Low(FDisplayOnlyRows) to High(FDisplayOnlyRows) do
      begin
      panel := SectionPanelFor(FDisplayOnlyRows[k].Control);
      if panel = nil then
         begin
         Continue;
         end;
      SetLength(FSearchIndex, n + 1);
      FSearchIndex[n] := FDisplayOnlyRows[k];
      FSearchIndex[n].SectionTag := panel.Tag;
      navItem := NavItemForTag(panel.Tag);
      if navItem <> nil then
         begin
         FSearchIndex[n].SectionName := navItem.Text;
         end;
      Inc(n);
      end;

   SetLength(FSearchIndex, n);

   logger.Info('[Prefs] search index: %d entries (%d registered setting(s) exist)',
               [n, SettingCount]);
end;

// One index entry for a hand-wired control -- one that edits a CFGCA command
// directly rather than through a binding, so BuildSearchIndex's own loop cannot
// see it.
//
// Skips a nil control and a control on no section panel, both of which are
// ordinary states while a page is being built rather than errors.
{ THE THIRD CLASS OF SETTING, which the index could not see at all.

  BuildSearchIndex walks FBindings; AddHandWiredToSearchIndex covers controls
  that edit a CFGCA command directly. A control loaded from the STORE --
  chkTCIServer reads FStore.TCIServerEnabled -- is neither, and could not be
  registered even by someone who remembered, because that routine takes a
  COMMAND STRING and there is no command.

  NY4I found it the way an operator would, 2026-08-30: "when I searched for TCI,
  I was not offered any config option but there is clearly an Enable the TCI
  Server option."

  The caption defaults to the control's own, so a TCheckBox needs no text here
  and cannot drift from what is on screen. Command is left EMPTY on purpose:
  it is the legacy-name lookup key, and inventing one would make
  ShowPreferencesForCommand answer for a command that does not exist. }
procedure TPrefsForm.AddStoreBackedToSearchIndex(var aN: integer;
                                                 const aControl: TWinControl;
                                                 const aCaption: string = '');
var
   panel: TControl;
   navItem: TTreeNode;
   text: string;
begin
   if aControl = nil then
      begin
      Exit;
      end;
   panel := SectionPanelFor(aControl);
   if panel = nil then
      begin
      Exit;
      end;

   text := aCaption;
   if (text = '') and (aControl is TCheckBox) then
      begin
      text := TCheckBox(aControl).Caption;
      end;
   if text = '' then
      begin
      Exit;      // nothing to match on; silently indexing blank helps nobody
      end;

   SetLength(FSearchIndex, aN + 1);
   FSearchIndex[aN].Caption     := text;
   FSearchIndex[aN].Command     := '';
   FSearchIndex[aN].SectionTag  := panel.Tag;
   FSearchIndex[aN].Control     := aControl;
   FSearchIndex[aN].SectionName := '';
   navItem := NavItemForTag(panel.Tag);
   if navItem <> nil then
      begin
      FSearchIndex[aN].SectionName := navItem.Text;
      end;
   Inc(aN);
end;

procedure TPrefsForm.AddHandWiredToSearchIndex(var aN: integer;
                                               const aCommand: string;
                                               const aControl: TWinControl);
var
   panel: TControl;
   navItem: TTreeNode;
begin
   if aControl = nil then
      begin
      Exit;
      end;

   panel := SectionPanelFor(aControl);
   if panel = nil then
      begin
      Exit;
      end;

   SetLength(FSearchIndex, aN + 1);
   FSearchIndex[aN].Caption     := aCommand;
   FSearchIndex[aN].Command     := aCommand;
   FSearchIndex[aN].SectionTag  := panel.Tag;
   FSearchIndex[aN].Control     := aControl;
   FSearchIndex[aN].SectionName := '';
   navItem := NavItemForTag(panel.Tag);
   if navItem <> nil then
      begin
      FSearchIndex[aN].SectionName := navItem.Text;
      end;
   Inc(aN);
end;

// Every hand-wired panel's settings, so search covers them too.
//
// These panels call ApplyAndStoreCommand / FStore.CommandValue directly and are
// invisible to FBindings -- BuildSearchIndex said so in its own comment for
// months. Station was added first; NY4I then searched "external", found
// nothing, and landed on the External Software placeholder (2026-08-16), which
// is what this list is for.
//
// IT IS A HAND-KEPT LIST AND THAT IS A KNOWN COST. The right end state is for
// these panels to bind like the rest, at which point this routine deletes
// itself. Until then a missing line here costs searchability, not correctness,
// and Lint-FormFields will not catch it -- so add to this when adding to a
// hand-wired panel.
procedure TPrefsForm.AddStationFieldsToSearchIndex(var aN: integer);
var
   f: TStationField;
begin
   for f in StationFields do
      begin
      AddHandWiredToSearchIndex(aN, f.Command, f.Edit);
      end;

   // --- WSJT-X (page tag NAV_WSJTX) ---
   { Searchable at last. It never was: the hand-wired list below covers WSJT-X,
     the external logger and MMTTY, and SPOT COLLECTOR ENABLED was simply not on
     it -- so "spot collector" found nothing while the setting sat in plain
     sight on the DX Cluster page. }
   { The TCI server page. Store-backed, so these go through the other route.
     Captions come from the controls themselves. }
   AddStoreBackedToSearchIndex(aN, chkTCIServer);
   AddStoreBackedToSearchIndex(aN, chkTCIBindAll);
   AddStoreBackedToSearchIndex(aN, chkTCIDebug);
   AddStoreBackedToSearchIndex(aN, edtTCIPort, 'TCI server port');

   AddHandWiredToSearchIndex(aN, 'SPOT COLLECTOR ENABLED',      chkSpotCollector);

   AddHandWiredToSearchIndex(aN, 'WSJT-X ENABLED',               chkWSJTXEnabled);
   AddHandWiredToSearchIndex(aN, 'WSJT-X RADIO CONTROL ENABLED', chkWSJTXRadioControl);
   AddHandWiredToSearchIndex(aN, 'WSJT-X SEND HIGHLIGHTS',       chkWSJTXHighlights);
   AddHandWiredToSearchIndex(aN, 'WSJT-X BROADCAST PORT',        edtWSJTXPort);
   AddHandWiredToSearchIndex(aN, 'WSJT-X MULTICAST GROUP',       edtWSJTXMulticast);

   // --- External logger (page tag NAV_EXTERNALLOGGER) ---
   AddHandWiredToSearchIndex(aN, 'EXTERNAL LOGGER',         cbxLoggerType);
   AddHandWiredToSearchIndex(aN, 'EXTERNAL LOGGER ENABLED', chkLoggerEnabled);
   AddHandWiredToSearchIndex(aN, 'EXTERNAL LOGGER ADDRESS', edtLoggerAddress);
   AddHandWiredToSearchIndex(aN, 'EXTERNAL LOGGER PORT',    edtLoggerPort);

   // --- MMTTY (page tag NAV_MMTTY) ---
   AddHandWiredToSearchIndex(aN, 'MMTTY ENGINE',           edtMMTTYEngine);

   { EVERYTHING BELOW WAS INVISIBLE TO THE SEARCH BOX until 2026-08-31.

     These controls all SAVE correctly -- they write a CFGCA command directly
     through ApplyIfChanged/SetCommandBool, or they are backed by a store
     property -- so nothing was losing data. They simply had no registration,
     and the index is built only from FBindings plus the two lists here, so an
     operator searching for "band map decay" or "main font" got nothing while
     the setting sat in plain sight on its page.

     Lint-SearchIndex now fails the build if a designed control on a section
     panel reaches neither the bindings nor this list, so the next one cannot
     be forgotten silently. }

   // --- layAppearance ---
   AddHandWiredToSearchIndex(aN, 'BOLD FONT',                         chkBoldFont);
   AddHandWiredToSearchIndex(aN, 'COLUMN DUPESHEET COLOR',            chkDupeSheetColor);
   AddHandWiredToSearchIndex(aN, 'FONT SIZE',                         edtFontSize);
   AddHandWiredToSearchIndex(aN, 'MAIN FONT',                         edtMainFont);

   // --- layBackup ---
   AddHandWiredToSearchIndex(aN, 'BACKUP LOG FREQUENCY',              edtBackupEvery);
   AddHandWiredToSearchIndex(aN, 'BACKUP LOG FILE NAME',              edtBackupFile);

   // --- layBandMap ---
   AddHandWiredToSearchIndex(aN, 'BAND MAP ALL BANDS',                chkBandMapAllBands);
   AddHandWiredToSearchIndex(aN, 'BAND MAP ALL MODES',                chkBandMapAllModes);
   AddHandWiredToSearchIndex(aN, 'BAND MAP DISPLAY CQ',               chkBandMapCQ);
   AddHandWiredToSearchIndex(aN, 'BAND MAP CALL WINDOW ENABLE',       chkBandMapCallWindow);
   AddHandWiredToSearchIndex(aN, 'BAND MAP DUPE DISPLAY',             chkBandMapDupes);
   AddHandWiredToSearchIndex(aN, 'BAND MAP DISPLAY GHZ',              chkBandMapGHz);
   AddHandWiredToSearchIndex(aN, 'BAND MAP MULTS ONLY',               chkBandMapMultsOnly);
   AddHandWiredToSearchIndex(aN, 'BAND MAP SO2R DISPLAY',             chkBandMapSO2R);
   AddHandWiredToSearchIndex(aN, 'BAND MAP DECAY TIME',               edtBandMapDecay);
   AddHandWiredToSearchIndex(aN, 'BAND MAP GUARD BAND',               edtBandMapGuard);
   AddHandWiredToSearchIndex(aN, 'BAND MAP DISPLAY LIMIT',            edtBandMapLimit);

   // --- layHardware ---
   AddHandWiredToSearchIndex(aN, 'RADIO ONE BAND OUTPUT PORT',        cbxBandOutput1);
   AddHandWiredToSearchIndex(aN, 'RADIO TWO BAND OUTPUT PORT',        cbxBandOutput2);
   AddHandWiredToSearchIndex(aN, 'RELAY CONTROL PORT',                cbxRelayPort);
   AddHandWiredToSearchIndex(aN, 'STEREO CONTROL PORT',               cbxStereoPort);
   AddStoreBackedToSearchIndex(aN, chkUseControlPort);
   AddHandWiredToSearchIndex(aN, 'YCCC SO2R ENABLE',                  chkYCCCSO2R);

   // --- layLogging ---
   AddStoreBackedToSearchIndex(aN, cbxLogLevel);
   AddStoreBackedToSearchIndex(aN, chkHamLibAsyncOnly);
   AddStoreBackedToSearchIndex(aN, chkHamLibDebug);
   AddStoreBackedToSearchIndex(aN, chkHamLibTrace);
   AddStoreBackedToSearchIndex(aN, chkTelnetDebug);

   // --- layNetwork ---
   AddHandWiredToSearchIndex(aN, 'SERVER AUTO SYNCHRONIZE LOG ON CONNECT', chkNetAutoSync);
   AddHandWiredToSearchIndex(aN, 'SERVER ADDRESS',                    edtNetAddress);
   AddHandWiredToSearchIndex(aN, 'COMPUTER ID',                       edtNetComputerID);
   AddHandWiredToSearchIndex(aN, 'SERVER PASSWORD',                   edtNetPassword);
   AddHandWiredToSearchIndex(aN, 'SERVER PORT',                       edtNetPort);
   AddHandWiredToSearchIndex(aN, 'RADIO TCP SERVER PORT',             edtRadioTCPPort);

   // --- laySCP ---
   AddHandWiredToSearchIndex(aN, 'SCP MINIMUM LETTERS',               cbxSCPMinLetters);
   AddHandWiredToSearchIndex(aN, 'SCP COUNTRY STRING',                edtSCPCountry);

   // --- layStation ---
   AddStoreBackedToSearchIndex(aN, cbxMyContinent);
   AddHandWiredToSearchIndex(aN, 'MY CALL',                           edtMyCall);
   AddHandWiredToSearchIndex(aN, 'MY CHECK',                          edtMyCheck);
   AddHandWiredToSearchIndex(aN, 'MY COUNTRY',                        edtMyCountry);
   AddHandWiredToSearchIndex(aN, 'MY FD CLASS',                       edtMyFDClass);
   AddHandWiredToSearchIndex(aN, 'MY FOC NUMBER',                     edtMyFOCNumber);
   AddHandWiredToSearchIndex(aN, 'MY GRID',                           edtMyGrid);
   AddHandWiredToSearchIndex(aN, 'MY IOTA',                           edtMyIOTA);
   AddHandWiredToSearchIndex(aN, 'MY ITU ZONE',                       edtMyITUZone);
   AddHandWiredToSearchIndex(aN, 'MY NAME',                           edtMyName);
   AddHandWiredToSearchIndex(aN, 'MY PARK',                           edtMyPark);
   AddHandWiredToSearchIndex(aN, 'MY POSTAL CODE',                    edtMyPostalCode);
   AddHandWiredToSearchIndex(aN, 'MY PREC',                           edtMyPrec);
   AddHandWiredToSearchIndex(aN, 'MY SECTION',                        edtMySection);
   AddHandWiredToSearchIndex(aN, 'MY STATE',                          edtMyState);
   AddHandWiredToSearchIndex(aN, 'MY ZONE',                           edtMyZone);

   // --- layTCIServer ---
   AddStoreBackedToSearchIndex(aN, edtTCIMaxTx);
end;

procedure TPrefsForm.RunSearch(const aNeedle: string);
var
   i, j, score, count: integer;
   hit: TPrefsSearchHit;
begin
   if not FSearchIndexBuilt then
      begin
      BuildSearchIndex;
      end;

   SetLength(FSearchHits, 0);
   if Trim(aNeedle) = '' then
      begin
      HideSearchResults;
      Exit;
      end;

   count := 0;
   SetLength(FSearchHits, Length(FSearchIndex));
   for i := 0 to High(FSearchIndex) do
      begin
      score := PrefsMatchScore(FSearchIndex[i].Caption, FSearchIndex[i].Command, aNeedle);
      if score > PREFS_MATCH_NONE then
         begin
         FSearchHits[count].Score := score;
         FSearchHits[count].Entry := i;
         Inc(count);
         end;
      end;
   SetLength(FSearchHits, count);

   // Insertion sort, descending by score then by caption. The caption tiebreak
   // is what keeps the order STABLE while the operator keeps typing -- a list
   // that reshuffles under the cursor is how you select the wrong row.
   for i := 1 to High(FSearchHits) do
      begin
      hit := FSearchHits[i];
      j   := i - 1;
      while (j >= 0) and
            ((FSearchHits[j].Score < hit.Score) or
             ((FSearchHits[j].Score = hit.Score) and
              (CompareText(FSearchIndex[FSearchHits[j].Entry].Caption,
                           FSearchIndex[hit.Entry].Caption) > 0))) do
         begin
         FSearchHits[j + 1] := FSearchHits[j];
         Dec(j);
         end;
      FSearchHits[j + 1] := hit;
      end;

   if count = 0 then
      begin
      HideSearchResults;
      Exit;
      end;

   if count > SEARCH_MAX_HITS then
      begin
      count := SEARCH_MAX_HITS;
      SetLength(FSearchHits, count);
      end;

   FSearchList.Items.BeginUpdate;
   try
      FSearchList.Items.Clear;
      for i := 0 to High(FSearchHits) do
         begin
         // The TEXT is only a fallback -- SearchListDrawItem paints the row from
         // the index, so caption and section can carry different colours.
         FSearchList.Items.Add(FSearchIndex[FSearchHits[i].Entry].Caption);
         end;
   finally
      FSearchList.Items.EndUpdate;
   end;

   FSearchList.ItemIndex := 0;
   FSearchList.Height    := 8 + (FSearchList.ItemHeight * Length(FSearchHits));
   FSearchList.Visible   := True;
   FSearchList.BringToFront;
end;

procedure TPrefsForm.HideSearchResults;
begin
   if FSearchList <> nil then
      begin
      FSearchList.Visible := False;
      end;
end;

// Select the section that owns aControl, then focus aControl itself.
//
// Extracted from ActivateSearchHit so the deep link (ControlForCommand, below)
// and a search hit reach a setting by exactly ONE code path.  Two copies of
// "select the page, then focus the field" would drift, and the drift would show
// up as a deep link that lands on the right page with nothing focused --
// visible only to whoever tried it.
procedure TPrefsForm.FocusControlOnItsSection(const aControl: TWinControl);
var
   panel: TControl;
   navItem: TTreeNode;
begin
   if aControl = nil then
      begin
      Exit;
      end;

   // Select the NAV ITEM rather than showing the panel directly, so the tree
   // agrees with what is on screen and tvNavChange does the switching. One code
   // path, the same one a click uses.
   panel := SectionPanelFor(aControl);
   if panel <> nil then
      begin
      navItem := NavItemForTag(panel.Tag);
      if navItem <> nil then
         begin
         navItem.Selected := True;
         end;
      end;

   // FOCUS THE CONTROL, not merely the page it lives on. That is the difference
   // between "here is the section, go hunting" and "here it is" -- and it is the
   // part Windows Settings itself does not do.
   //
   // CanFocus is False while the panel is still hidden, which is why this runs
   // AFTER the nav selection above and not before it.
   // FOCUS IS DEFERRED, and it has to be.
   //
   // Measured (2026-08-17): calling SetFocus here does nothing at all --
   //    focus edtMyGrid: visible=True enabled=True canfocus=False -> active=edtSearch
   // The control is visible and enabled, but CanFocus is still False because the
   // panel was made visible microseconds ago in this same message and its parent
   // chain is not realised yet.  So the guarded call was skipped silently and
   // focus stayed in the search box -- which is exactly what NY4I saw.
   //
   // A search hit has a second problem on top: ActivateSearchHit runs inside the
   // result list's OnClick, and the LCL restores focus to the clicked control
   // after the handler returns, undoing anything set during it.
   //
   // QueueAsyncCall runs after the current message is finished, by which time
   // the panel is real and the click is over.  Both problems, one mechanism.
   FPendingFocus := aControl;
   // A ONE-SHOT TIMER, and the two simpler things were tried first and measured.
   //
   // Application.QueueAsyncCall never ran: the LCL drains that queue from
   // TApplication.Idle, and TR4W runs its OWN GetMessage loop and never calls
   // Application.Run, so nothing drains it.  A message posted straight to the
   // form's handle did not arrive either.  A TTimer becomes SetTimer/WM_TIMER,
   // which is the mechanism the rest of TR4W already relies on and which its
   // loop demonstrably dispatches (QuickDisplay uses exactly that).
   //
   // Interval 1: as soon as the current message is finished, not later.
   if FFocusTimer = nil then
      begin
      FFocusTimer := TTimer.Create(Self);
      FFocusTimer.Enabled  := False;
      FFocusTimer.Interval := 15;
      FFocusTimer.OnTimer  := FocusTimerTick;
      end;
   FFocusTries := 0;
   FFocusTimer.Enabled := True;
end;

// The second half of FocusControlOnItsSection -- see the comment there.
// Bring a control into view inside whatever scrolling container holds it.
//
// The INNERMOST one: a generated page is a TScrollBox inside layContent inside
// the form, and scrolling the form instead of the box would move the wrong
// thing.  Nothing to do when there is no scrolling ancestor, which is the case
// for a control sitting on a designed panel that fits.
procedure TPrefsForm.ScrollControlIntoView(const aControl: TControl);
var
   p: TWinControl;
   sc: TScrollingWinControl;
   pos: integer;
begin
   if aControl = nil then
      begin
      Exit;
      end;

   p := aControl.Parent;
   while p <> nil do
      begin
      if p is TScrollingWinControl then
         begin
         sc  := TScrollingWinControl(p);
         pos := sc.VertScrollBar.Position;

         // ONLY IF IT IS NOT ALREADY VISIBLE.  Scrolling a setting that is
         // already on screen would move the page under the operator for no
         // reason.
         if (aControl.Top < pos) or
            (aControl.Top + aControl.Height > pos + p.Height) then
            begin
            // NEAR THE TOP, not the minimum scroll.  ScrollInView moves just
            // far enough, which leaves a searched row jammed against the bottom
            // edge -- measured at top=664 in a 572-high box, scrolled to 117,
            // so the row sat on the last pixel.  Landing it a little below the
            // top is where the eye goes and shows what follows it.
            sc.VertScrollBar.Position := Max(0, aControl.Top - FOUND_ROW_MARGIN);
            logger.Debug('[Prefs] scrolled to %s (top=%d, scroll %d -> %d, view=%d)',
                         [aControl.Name, aControl.Top, pos,
                          sc.VertScrollBar.Position, p.Height]);
            end;
         Exit;
         end;
      p := p.Parent;
      end;
end;

// BOUNDED RETRY, not a single shot.
//
// One tick was enough when the hit was already on the visible page, and not
// enough when it was on another (NY4I, 2026-08-17: "if I was already on the
// panel ... the cursor does go to the field.  But if I was on a different one,
// then the cursor stays in the searchbox").  Two things can still be in flight
// 1 ms after a search hit changes pages: the newly shown panel may not have its
// handle yet, so CanFocus is False; and the LCL restores focus to the clicked
// result list after its OnClick returns, taking it back from us.
//
// So keep asking until the focus has ACTUALLY LANDED -- ActiveControl is the
// only honest test -- and give up loudly after a bounded number of tries rather
// than spinning a timer forever on a page that will never accept focus.
procedure TPrefsForm.ClearSearchHighlight(const aRoot: TWinControl);
var
   i: integer;
begin
   for i := 0 to aRoot.ControlCount - 1 do
      begin
      // Only a GENERATED row caption: those are the labels that carry a
      // FocusControl.  Section headings are bold by design and must be left
      // alone, and they have none.
      if (aRoot.Controls[i] is TLabel) and
         (TLabel(aRoot.Controls[i]).FocusControl <> nil) then
         begin
         TLabel(aRoot.Controls[i]).Font.Style := [];
         TLabel(aRoot.Controls[i]).Font.Color := clDefault;
         end;

      if aRoot.Controls[i] is TWinControl then
         begin
         ClearSearchHighlight(TWinControl(aRoot.Controls[i]));
         end;
      end;
end;

procedure TPrefsForm.HighlightSearchedRow(const aControl: TWinControl);
var
   i: integer;
   lbl: TLabel;
begin
   // Whole form, not just this page: the operator may have searched twice, and
   // the earlier hit can be on a page that is no longer showing.  Walking a
   // LIVE tree also means a regenerated page cannot leave a dangling label
   // reference behind -- which storing "the last one highlighted" would.
   ClearSearchHighlight(Self);

   if (aControl = nil) or (aControl.Parent = nil) then
      begin
      Exit;
      end;

   for i := 0 to aControl.Parent.ControlCount - 1 do
      begin
      if not (aControl.Parent.Controls[i] is TLabel) then
         begin
         Continue;
         end;

      lbl := TLabel(aControl.Parent.Controls[i]);
      if lbl.FocusControl = aControl then
         begin
         lbl.Font.Style := [fsBold];
         lbl.Font.Color := clHighlight;
         Exit;
         end;
      end;
end;

procedure TPrefsForm.FocusTimerTick(Sender: TObject);
var
   ctl: TWinControl;
begin
   ctl := FPendingFocus;

   // Gone: the form closed, or a regenerated page freed the control.  Ordinary.
   if ctl = nil then
      begin
      FFocusTimer.Enabled := False;
      Exit;
      end;

   Inc(FFocusTries);

   // SCROLL FIRST, and on every attempt.  A hit below the fold is barely found
   // -- the generated pages are scroll boxes and a searched setting is often
   // well down one (NY4I, 2026-08-17).  Doing it before the focus attempt also
   // means a row that can never take focus is still brought into view.
   ScrollControlIntoView(ctl);
   HighlightSearchedRow(ctl);

   // A DISPLAY-ONLY ROW WILL NEVER FOCUS, by design -- read-only and ckList /
   // ctFreqList rows are deliberately unbound and disabled.  Scrolling to it is
   // the whole of what we can do, so stop here rather than spending fifteen
   // attempts and then warning about something working as intended.
   if not ctl.Enabled then
      begin
      FFocusTimer.Enabled := False;
      FPendingFocus       := nil;
      logger.Debug('[Prefs] scrolled to %s (read-only, cannot take focus)', [ctl.Name]);
      Exit;
      end;

   if ctl.CanFocus then
      begin
      ctl.SetFocus;
      end;

   // LANDED?  Asking ActiveControl rather than trusting SetFocus is the whole
   // point: SetFocus succeeded on the first attempt too, and focus was then
   // taken straight back.
   if ActiveControl = ctl then
      begin
      FFocusTimer.Enabled := False;
      FPendingFocus       := nil;
      logger.Debug('[Prefs] focus -> %s after %d attempt(s)', [ctl.Name, FFocusTries]);
      Exit;
      end;

   if FFocusTries >= FOCUS_MAX_TRIES then
      begin
      FFocusTimer.Enabled := False;
      FPendingFocus       := nil;
      // NOT silent.  A setting the operator searched for and cannot type into
      // is exactly the failure this whole mechanism exists to prevent.
      logger.Warn('[Prefs] gave up focusing %s after %d attempts ' +
                  '(canfocus=%s, active=%s)',
                  [ctl.Name, FFocusTries,
                   BoolToStr(ctl.CanFocus, True),
                   IfThen(ActiveControl <> nil, ActiveControl.Name, '<none>')]);
      end;
end;

// Maps a legacy Ctrl-J command spelling to the control that edits it.
//
// TWO SOURCES, DELIBERATELY, because the form genuinely has two kinds of field
// and neither alone would cover 'MY GRID':
//
//   1. The hand-wired Station panel (StationFields), which calls
//      ApplyAndStoreCommand directly and is NOT in the settings registry --
//      BuildSearchIndex says so itself, and that is exactly why Preferences
//      search cannot find MY GRID today.
//   2. FSearchIndex, covering every registry-bound setting.
//
// Returns nil when the command is on no panel -- an honest "I cannot take you
// there", which the caller turns into a fallback rather than a wrong guess.
function TPrefsForm.ControlForCommand(const aCommand: string): TWinControl;
var
   f: TStationField;
   i: integer;
begin
   Result := nil;

   for f in StationFields do
      begin
      if SameText(f.Command, aCommand) then
         begin
         Result := f.Edit;
         Exit;
         end;
      end;

   if not FSearchIndexBuilt then
      begin
      BuildSearchIndex;
      end;

   for i := Low(FSearchIndex) to High(FSearchIndex) do
      begin
      if SameText(FSearchIndex[i].Command, aCommand) then
         begin
         Result := FSearchIndex[i].Control;
         Exit;
         end;
      end;
end;

procedure TPrefsForm.ActivateSearchHit(const aIndex: integer);
var
   e: TPrefsSearchEntry;
begin
   if (aIndex < 0) or (aIndex > High(FSearchHits)) then
      begin
      Exit;
      end;

   e := FSearchIndex[FSearchHits[aIndex].Entry];
   HideSearchResults;

   FocusControlOnItsSection(e.Control);

   logger.Debug('[Prefs] search -> %s (%s), section tag=%d',
                [e.Caption, e.Command, e.SectionTag]);
end;

procedure TPrefsForm.edtSearchChange(Sender: TObject);
begin
   RunSearch(edtSearch.Text);
end;

procedure TPrefsForm.edtSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
   // FOCUS NEVER LEAVES THE BOX. Up/Down move the list's selection WITHOUT
   // focusing it, so the operator keeps typing, narrowing and choosing without
   // reaching for the mouse. Focusing the list instead would stop the next
   // keystroke reaching the edit, which is the whole point of the pattern.
   if (FSearchList = nil) or (not FSearchList.Visible) then
      begin
      Exit;
      end;

   case Key of
      VK_DOWN:
         begin
         if FSearchList.ItemIndex < FSearchList.Items.Count - 1 then
            begin
            FSearchList.ItemIndex := FSearchList.ItemIndex + 1;
            end;
         Key := 0;
         end;

      VK_UP:
         begin
         if FSearchList.ItemIndex > 0 then
            begin
            FSearchList.ItemIndex := FSearchList.ItemIndex - 1;
            end;
         Key := 0;
         end;

      VK_RETURN:
         begin
         ActivateSearchHit(FSearchList.ItemIndex);
         Key := 0;
         end;

      VK_ESCAPE:
         begin
         HideSearchResults;
         Key := 0;
         end;
   end;
end;

procedure TPrefsForm.SearchListDrawItem(Control: TWinControl; Index: Integer;
                                        ARect: Types.TRect;
                                        State: StdCtrls.TOwnerDrawState);
var
   c: TCanvas;
   e: TPrefsSearchEntry;
   x, y: integer;
   sectionText: string;
begin
   // OWNER-DRAWN because a standard TListBox row is font-height tall with no
   // padding, which is most of what makes an LCL list look like 1995. The row
   // height, the left margin and the second colour are the whole difference.
   if (Index < 0) or (Index > High(FSearchHits)) then
      begin
      Exit;
      end;

   c := FSearchList.Canvas;
   e := FSearchIndex[FSearchHits[Index].Entry];

   // LCLType.odSelected, for the same reason the parameter types are qualified:
   // Windows declares an odSelected of its own.
   // SYSTEM COLOURS, not invented ones. A hardcoded wash looks deliberate until
   // the operator runs a dark or high-contrast theme, at which point it is text
   // nobody can read. clHighlight follows whatever the desktop is set to.
   if LCLType.odSelected in State then
      begin
      c.Brush.Color := clHighlight;
      c.Font.Color  := clHighlightText;
      end
   else
      begin
      c.Brush.Color := clWindow;
      c.Font.Color  := clWindowText;
      end;
   c.FillRect(ARect);

   // The caption, vertically centred rather than sat on the top edge.
   y := ARect.Top + ((ARect.Bottom - ARect.Top - c.TextHeight('Ag')) div 2);
   x := ARect.Left + 10;
   c.TextOut(x, y, e.Caption);

   // The section, greyed and right-aligned: context without competing with the
   // thing the operator is actually reading.
   sectionText := e.SectionName;
   if sectionText <> '' then
      begin
      // Greyed against the row's OWN background: clGrayText on a highlighted
      // row is unreadable, so a selected row keeps the highlight text colour.
      if not (LCLType.odSelected in State) then
         begin
         c.Font.Color := clGrayText;
         end;
      x := ARect.Right - 10 - c.TextWidth(sectionText);
      if x > ARect.Left + 10 + c.TextWidth(e.Caption) + 16 then
         begin
         c.TextOut(x, y, sectionText);
         end;
      end;
end;

procedure TPrefsForm.SearchListClick(Sender: TObject);
begin
   ActivateSearchHit(FSearchList.ItemIndex);
end;

procedure TPrefsForm.tvNavMouseDown(Sender: TObject; Button: TMouseButton;
                                    Shift: TShiftState; X, Y: integer);
var
   node: TTreeNode;
begin
   if Button <> mbLeft then
      begin
      Exit;
      end;

   // THE EXPAND SIGN IS NOT OURS TO HANDLE.  The tree already toggles on a
   // click there; toggling again here would undo it and the chevron would look
   // dead.  htOnButton is that hit and nothing else.
   if htOnButton in tvNav.GetHitTestInfoAt(X, Y) then
      begin
      Exit;
      end;

   node := tvNav.GetNodeAt(X, Y);
   if (node = nil) or (not node.HasChildren) then
      begin
      Exit;
      end;

   // A DIFFERENT row: let the selection change, and tvNavChange opens it. Only
   // a re-click on the row that is ALREADY selected toggles, which is what
   // makes this additive rather than a second, competing expand rule.
   if node <> tvNav.Selected then
      begin
      Exit;
      end;

   if node.Expanded then
      begin
      node.Collapse(False);
      end
   else
      begin
      node.Expand(False);
      end;
end;
procedure TPrefsForm.tvNavExpanded(Sender: TObject; Node: TTreeNode);
var
   i: integer;
   sibling: TTreeNode;
begin
   // ONE BRANCH OPEN AT A TIME, so the strip needs a scrollbar as rarely as
   // possible.
   //
   // The arithmetic, because this is a constraint rather than a preference
   // (NY4I: "I don't want to scroll that vertical left pane"). RECOUNTED
   // 2026-08-18 -- the numbers that were here had gone stale as sections were
   // added, and they overstated the headroom:
   //
   //   pane 541px at 26px/row      = 20 rows visible
   //   top-level sections          = 18   (this comment used to say 16)
   //   every row with all open     = 30   (this comment used to say 27)
   //
   //   collapsed              18 rows   fits, two spare (not four)
   //   Hardware open          20 rows   fits exactly, none spare
   //   CW Settings open       19 rows   fits
   //   External Software open 22 rows   SCROLLS
   //   Operating open         23 rows   SCROLLS
   //
   // SO THE NO-SCROLL PROMISE IS ALREADY NOT BEING KEPT for the two largest
   // branches, and it stopped being kept silently. ssAutoVertical means it
   // degrades rather than clips, which is why nobody noticed.
   //
   // LEFT AS IS ON PURPOSE (NY4I, 2026-08-18): "leave it for now. I have seen
   // places to rearrange some of the items (like more CW Settings under
   // hardware but that is an example). So once I rearrange, we can review this
   // again." Rearranging the sections changes the counts, so tuning the rule
   // before that would be tuning against numbers about to move.
   //
   // Collapsing the siblings keeps the worst case at 18 + the largest branch.
   //
   // Worth knowing when that review happens: this rule is ALSO why Hardware
   // appears collapsed after visiting another section. Preferences selects
   // Hardware on open and tvNavChange expands it, so the first sight of the
   // window shows its children -- but navigating to any other branch collapses
   // it, and coming back from a modal does not re-run the initial selection.
   // NY4I read that as a regression on 2026-08-18; it is this rule working.
   if (Node = nil) or (Node.Parent <> nil) then
      begin
      Exit;
      end;

   for i := 0 to tvNav.Items.TopLvlCount - 1 do
      begin
      sibling := tvNav.Items.TopLvlItems[i];
      if (sibling <> Node) and sibling.Expanded then
         begin
         sibling.Collapse(False);
         end;
      end;
end;

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

   // A PARENT OPENS ITSELF (NY4I, 2026-08-16).
   //
   // External Software has no panel -- it is a grouping, and its settings live
   // on WSJT-X, External Logger, DXLab and MMTTY beneath it. But the tree opens
   // collapsed, so selecting it showed a bare placeholder reading "this section
   // has not been migrated yet" over four pages that HAVE been migrated. It
   // read as missing functionality; it was a closed node.
   //
   // Expanding on selection makes the children visible at the moment the
   // operator asks about them. tvNavExpanded still collapses the siblings, so
   // the one-branch-at-a-time rule (and the no-scrollbar constraint behind it)
   // is untouched.
   if (tvNav.Selected <> nil) and (tvNav.Selected.HasChildren) and
      (not tvNav.Selected.Expanded) then
      begin
      tvNav.Selected.Expand(False);
      end;

   // The placeholder is the answer for every section that has no panel yet --
   // which is most of them, deliberately: the nav says what this window is
   // GOING to be, so nobody has to guess whether Preferences is meant to grow.
   //
   // Two DIFFERENT states, and saying the wrong one is worse than saying
   // nothing: a grouping node has no panel because its pages are its children,
   // not because nobody has written it.
   if (not shown) and (tvNav.Selected <> nil) and (tvNav.Selected.HasChildren) then
      begin
      lblPlaceholder.Caption :=
         'Choose one of the pages listed under this heading.';
      end
   else
      begin
      lblPlaceholder.Caption :=
         'This section has not been migrated yet.' + #13#10 +
         'Use the existing configuration screens for it.';
      end;
   lblPlaceholder.Visible := not shown;

   // SAY WHICH SECTION OPENED AND WHETHER IT HAD ANYTHING TO SHOW.  Nothing
   // outside the process can determine this: an LCL TLabel is a TGraphicControl
   // with no window handle, so a placeholder-only section is indistinguishable
   // from an empty one to any window-enumerating harness -- which is precisely
   // how the nav tree itself stayed empty for a whole session without a single
   // line in the log.  One Debug line per section click makes the sweep in
   // test/ui/Test-PreferencesSections.ps1 assert on the form's OWN answer than
   // inferring one from the outside.
   if shown then
      begin
      logger.Debug('[Prefs] section tag=%d -> panel', [wanted]);
      end
   else
      begin
      logger.Debug('[Prefs] section tag=%d -> placeholder', [wanted]);
      end;

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
                  PAnsiChar(WinAnsi(Format(TC_PREFS_CONFIRMREMOVE, [radio.Name]))),
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
      { One refill: combo, selection and fields together, so nothing between
        them can be mistaken for the operator editing a profile. }
      BeginLoading;
      try
         RefreshProfileCombo;
         SelectByTag(cbxProfile, prof.Name);
         if logger.IsDebugEnabled then
            begin
            logger.Debug('[Prefs] new profile "%s" (len %d): %d item(s) ' +
                         '-> ItemIndex=%d, SelectedTag="%s", HasTag=%s',
                         [prof.Name, Length(prof.Name), cbxProfile.Items.Count,
                          cbxProfile.ItemIndex, SelectedTag(cbxProfile),
                          BoolToStr(HasTag(cbxProfile, prof.Name), True)]);
            end;
      finally
         EndLoading;
      end;
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
   BeginLoading;
   try
      RefreshProfileCombo;
      SelectByTag(cbxProfile, prof.Name);
   finally
      EndLoading;
   end;
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
   if Loading then
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

   // INSTALLED HERE, not left to the caller.  Every line below hard-casts a
   // TTreeNode to TNavNode to set Tag, which is only true because the node
   // class hook makes the tree produce TNavNodes.  Without it those casts
   // write an integer past the end of a plain TTreeNode -- silent heap
   // corruption, no exception, and nothing the compiler can see.  Putting the
   // install in the same routine as the casts makes the ordering an invariant
   // of the code rather than a rule someone has to remember.
   UseNavNodes(tvNav);

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
      // Under Appearance, because that is where an operator looks for it, and
      // as its own page because fifty elements x two drop-downs will not fit
      // on the designed panel.
      navColors := tvNav.Items.AddChild(navAppearance, 'Colors');
      TNavNode(navColors).Tag := NAV_COLORS;
      navLogging := tvNav.Items.Add(nil, 'Logging');
      TNavNode(navLogging).Tag := 8;
      navBackup := tvNav.Items.Add(nil, 'Backup');
      TNavNode(navBackup).Tag := 9;
      navContest := tvNav.Items.Add(nil, 'Contest');
      TNavNode(navContest).Tag := 10;
      // The holding page for settings that left Ctrl-J -- see NAV_MORE. Last in
      // the list on purpose: it is the page that should shrink to nothing.
      navMore := tvNav.Items.Add(nil, 'More settings');
      TNavNode(navMore).Tag := NAV_MORE;
      navAudio := tvNav.Items.Add(nil, 'Audio');
      TNavNode(navAudio).Tag := 29;
      navCW := tvNav.Items.Add(nil, 'CW Settings');
      TNavNode(navCW).Tag := 11;
      navPaddlePTT := tvNav.Items.AddChild(navCW, 'Paddle and PTT');
      TNavNode(navPaddlePTT).Tag := 28;
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
   // EMPTY, AND THAT IS NOW DELIBERATE RATHER THAN AN OVERSIGHT.
   //
   // FMX had no expand indicator of its own, so this drew one per item.  The
   // LCL draws them natively from tvNav.Options, and the body was emptied in
   // the conversion -- but the option that makes them appear on a TOP-LEVEL
   // node, tvoShowRoot, was not set, so no chevron was drawn anywhere and the
   // four parents (Hardware, Operating, CW Settings, External Software) looked
   // like leaves.  treeview.inc:5574 is the rule:
   //
   //   HasExpandSign := ShowButtons and Node.HasChildren and
   //                    ((tvoShowRoot in Options) or (Node.Parent <> nil));
   //
   // Fixed in the .lfm (NY4I, 2026-08-21).  This routine and its call in
   // SelectFirstSection are kept as the named place that answers "where did
   // the chevrons go", and because a future custom glyph would go here.
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
{ THE STORED VALUE -- WHICH IS THE STARTUP DEFAULT, NOT THE LIVE ONE.

  This page EDITS the default.  For most settings the two are the same and the
  distinction never shows; for the ones whose live value legitimately moves
  during operation -- CODE SPEED by keystroke, the band map filters from their
  own menu -- showing the live value here would present a transient as if it
  were the configured default, and one save would make it one.

  What stops a save from clobbering the live value is not this function but
  ApplyIfChanged, which writes only the commands the operator actually edited.

  Live is still the fallback: a row the store has never held (and the handful
  with no single global to render) has nowhere else to come from. }
function TPrefsForm.CommandText(const aCommand: string): string;
begin
   Result := FStore.CommandValue(aCommand, CFGCommandValueAsString(aCommand));

   // THE SNAPSHOT, taken here because this is what every hand-written panel
   // loads through -- one place rather than twenty-eight call sites.
   if FLoaded <> nil then
      begin
      FLoaded.Values[aCommand] := Result;
      end;
end;

{ WRITE WHAT CHANGED.  See the long note on TSettingBinding.Save for why an
  untouched control must not be written: the same Preferences save that raised
  NY4I's band map display limit switched his All bands and All modes filters
  back on, because Save wrote every control on the page. }
function TPrefsForm.ApplyIfChanged(const aCommand, aValue: string): boolean;
begin
   if (FLoaded <> nil) and (FLoaded.IndexOfName(aCommand) >= 0) and
      (FLoaded.Values[aCommand] = aValue) then
      begin
      Result := True;
      Exit;
      end;

   // THE REAL WRITE.  Not ApplyIfChanged -- calling itself here is what a
   // careless global rename did on 2026-08-25, and it recursed until the stack
   // gave out the first time NY4I changed CW speed.
   Result := ApplyAndStoreCommand(FStore, aCommand, aValue);
   if Result and (FLoaded <> nil) then
      begin
      FLoaded.Values[aCommand] := aValue;
      end;
end;

function TPrefsForm.CommandBool(const aCommand: string): boolean;
begin
   Result := SameText(Trim(CommandText(aCommand)), string(BA[True]));
end;

function TPrefsForm.SetCommandBool(const aCommand: string; const aValue: boolean): boolean;
begin
   Result := ApplyIfChanged(aCommand, string(BA[aValue]));
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
   current := CommandText(aCommand);

   aCombo.Items.BeginUpdate;
   try
      ClearComboItems(aCombo);
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
   FBindings.Bind(chkCWMessagesChainable,  'cw.messagesChainable');
   FBindings.Bind(chkTuneWithDits,         'cw.tuneWithDits');
   FBindings.Bind(chkSendFourLetterCall,   'cw.sendFourLetterCall');
   FBindings.Bind(chkIncludeFKeyNumber,  'cw.includeFKeyNumber');

   FBindings.Bind(chkNoBorder,           'appearance.noBorder');
   FBindings.Bind(chkNoCaption,          'appearance.noCaption');
   FBindings.Bind(chkNoColumnHeader,     'appearance.noColumnHeader');
   FBindings.Bind(chkShowGridlines,      'appearance.showGridlines');

   FBindings.Bind(chkDVKEnable,          'audio.dvk.enable');
   FBindings.Bind(chkDVKLocalizedMessages,
                                         'audio.dvk.localizedMessages');
   FBindings.Bind(chkUseRecordedSigns,   'audio.useRecordedSigns');
   FBindings.Bind(edtDVKPath,            'audio.dvk.path');
   FBindings.Bind(edtDVKRecorder,        'audio.dvk.recorder');
   FBindings.Bind(chkMP3RecorderEnable,  'audio.mp3.recorderEnable');
   FBindings.Bind(edtMP3Path,            'audio.mp3.path');
   FBindings.Bind(edtMP3Player,          'audio.mp3.player');

   // Paddle and PTT -- a CHILD of CW Settings, so the nav gains nothing
   // in height while collapsed. NY4I asked that the left pane never
   // need scrolling, and these ten settings would not fit on the CW
   // page itself.
   FBindings.Bind(edtPaddleSpeed,          'cw.paddle.speed');
   FBindings.Bind(edtPaddleTone,           'cw.paddle.monitorTone');
   FBindings.Bind(edtPaddleHold,           'cw.paddle.pttHoldCount');
   FBindings.Bind(chkSwapPaddles,          'cw.paddle.swap');
   FBindings.Bind(chkPTTEnable,            'ptt.enable');
   FBindings.Bind(edtPTTDelay,             'ptt.turnOnDelay');
   FBindings.Bind(chkNoPollDuringPTT,      'ptt.noPollDuringPTT');
   FBindings.Bind(chkPTTViaCommands,     'ptt.viaCommands');
   FBindings.Bind(chkPTTLockout,         'ptt.lockout');

   // Operating -- a NEW page on the parent nav node (Tag 21). It had a
   // node with children and no page of its own, so clicking it showed
   // nothing; Hardware already works this way.
   FBindings.Bind(chkAutoReturnToCQ,     'operating.autoReturnToCQ');
   FBindings.Bind(chkAutoCallTerminate,  'operating.autoCallTerminate');
   FBindings.Bind(chkEscapeExitsSAP,     'operating.escapeExitsSAP');
   FBindings.Bind(chkLeaveCursorInCall,  'operating.leaveCursorInCall');
   FBindings.Bind(chkLogWithSingleEnter, 'operating.logWithSingleEnter');
   FBindings.Bind(chkSpaceBarDupeCheck,  'operating.spaceBarDupeCheck');
   FBindings.Bind(chkConfirmEditChanges, 'operating.confirmEditChanges');
   FBindings.Bind(chkAutoQSONumberDecrement,
                                         'operating.autoQSONumberDecrement');

   FBindings.Bind(chkPossibleCalls,      'scp.possibleCalls');
   FBindings.Bind(chkPartialCall,        'scp.partialCall');
   FBindings.Bind(chkWildcardPartials,   'scp.wildcardPartials');
   FBindings.Bind(chkNameFlag,           'scp.nameFlag');
   FBindings.Bind(chkCallWindowShowAllSpots,
                                         'bandmap.callWindowShowAllSpots');
   FBindings.Bind(chkSwapPacketSpotRadios,
                                         'bandmap.swapPacketSpotRadios');
   FBindings.Bind(chkCheckLogFileSize,   'logging.checkLogFileSize');
   FBindings.Bind(chkUnknownCountryFile, 'logging.unknownCountryFile');
   FBindings.Bind(chkUpdateRestartFile,  'logging.updateRestartFile');

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
   FBindings.Bind(chkInBandLockout,     'operating.tworadio.inBandLockout');
   FBindings.Bind(chkQSYInactive,       'operating.tworadio.qsyInactive');
   FBindings.Bind(chkSwapRelaySense,    'operating.tworadio.swapRelaySense');
   FBindings.Bind(chkWaitForStrength,   'operating.tworadio.waitForStrength');
   FBindings.Bind(chkMultiMultsOnly,    'network.multiMultsOnly');
   FBindings.Bind(chkIntercomFile,      'network.intercomFile');

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
   // NOT BOUND to a flat setting -- the CLUSTER DEFINITION owns this box.
   //
   // It was bound both ways: this binding wrote CONNECTION COMMAND to tr4w.ini,
   // while the control's OnChange captured the same text into the selected
   // cluster. Only one of them was ever read -- ApplyActiveCluster assigns
   // ConnectionCommand from the cluster definition at startup, after the config
   // files -- so the ini write was noise that looked authoritative to anyone who
   // opened the file, and an edit made here appeared to save to a setting that
   // could never win.
   //
   // The editor populates the box (LoadSelectedCluster) and captures it
   // (CaptureSelectedCluster), so removing the binding removes a writer, not a
   // reader.

   // THE GENERATED PAGES GO LAST, AND HAVE TO.
   //
   // Two reasons, both learned the hard way on 2026-08-16 by building them in
   // the constructor and getting three empty pages:
   //
   //   * DeclareAllSettings is called at the TOP of this routine, so before it
   //     runs the registry is empty and a generator finds nothing to render;
   //   * this routine does FreeAndNil(FBindings) and creates a new collection,
   //     which would throw away any binding made earlier.
   //
   // Building them here means the registry is populated and FBindings is the
   // one that survives, so a generated control loads and saves exactly like a
   // designed one.
   BuildGeneratedSections;

   // INDEX EAGERLY, so the coverage line is in every log rather than only in
   // one where somebody happened to search. "Every setting must be findable"
   // is a requirement now (NY4I, 2026-08-16), and a requirement whose only
   // evidence appears when a user exercises it is one nobody notices breaking.
   // The cost is a pass over ~230 bindings; the expensive part of opening this
   // window was never this, it was populating combos.
   BuildSearchIndex;
end;


{ ------------------------------------------------------------ Rotators ----- }


{ ---------------------------------------------------------- DX clusters --- }

{ WHERE THE SHIPPED SERVER DIRECTORY LIVES.

  ONE EXPRESSION was not enough -- it also has to be the RIGHT one. This read
  ExtractFilePath(ParamStr(0)), the BINARY's directory, which is only the data
  directory when the exe happens to sit beside the data. Running the build-out
  binary with the working directory set to target -- how this is developed --
  put it in build-out, where there is no trcluster.dat, so the picker reported an
  empty directory while the DX Cluster window read the same file successfully
  from the working directory (NY4I again, 2026-08-31: "we did not find the
  trclusters file in the target if we were supposed to").

  uAppPaths.DataFilePath is the single rule for shipped read-only data, and this
  is its FIRST caller; the other 44 path sites still resolve their own way.
  See docs/OWED_BEFORE_CROSS_PLATFORM.md item 3.

  THE NAME IS UPPERCASE AND THE FILE ON DISK IS LOWERCASE (trcluster.dat).
  Windows does not care; macOS and Linux will. Do not "fix" the case here in
  isolation -- it has to be settled for every shipped data file at once, with
  DataFilePath as the place to do it. }
function ClusterDirectoryPath: string;
begin
   Result := DataFilePath('TRCLUSTER.DAT');
end;

{ Say beside the drop-down whether there is a directory to drop down.

  CHEAP, so it can run when the page loads rather than waiting for the combo to
  be focused: an existence test, not the 726-line parse. The parse stays on
  OnEnter where it was measured and put.

  IN PLACE OF THE NORMAL HINT, not beside it. The normal hint says "the
  drop-down lists the servers in TRCLUSTER.DAT" -- with no file that sentence
  is false, and a wrong hint next to a right warning is worse than either
  alone. }
procedure TPrefsForm.ShowClusterDirectoryState;
begin
   if FileTextExists(ClusterDirectoryPath) then
      begin
      lblClusterServerHint.Caption   := TC_CLUSTERSERVERHINT;
      lblClusterServerHint.Font.Color := clGrayText;
      end
   else
      begin
      lblClusterServerHint.Caption   := TC_CLUSTERDIRMISSING;
      lblClusterServerHint.Font.Color := clRed;
      end;
end;

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

      fileName := ClusterDirectoryPath;
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
         end
      else
         begin
         { SAY THE FILE WAS NOT THERE, and say WHERE we looked.

           Without this the operator gets an empty picker and a log line reading
           "0 entries", which is what an EMPTY file would also produce -- so the
           one number that could have explained it says the same thing for two
           different causes.

           It is not hypothetical. NY4I hit exactly this on 2026-08-30 running
           the binary from build-out\ while the data sits in tr4w\target\:
           this routine resolves TRCLUSTER.DAT beside the BINARY, and the DX
           Cluster window resolves it against the WORKING DIRECTORY, so the
           window listed servers and the picker did not. Two rules, one
           filename, and nothing said so. See
           docs\OWED_BEFORE_CROSS_PLATFORM.md item 3 for the fix to the rules
           themselves; this line is what makes the NEXT instance self-
           diagnosing rather than a conversation. }
         logger.Warn('[Prefs] cluster directory not found at %s -- the server '
                     + 'picker will be empty. It is read from beside the '
                     + 'program, not from the working directory.', [fileName]);
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
   keep, active: integer;
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

   // OPEN ON THE ACTIVE ONE, same rule as the rotator list and for the same
   // reason: the tick sat on one cluster while the fields below described
   // another, so the page contradicted itself on open.
   if (keep >= 0) and (keep < lstClusters.Items.Count) then
      begin
      lstClusters.ItemIndex := keep;
      end
   else if lstClusters.Items.Count > 0 then
      begin
      active := FStore.IndexOfCluster(FStore.ActiveClusterName);
      if (active >= 0) and (active < lstClusters.Items.Count) then
         begin
         lstClusters.ItemIndex := active;
         end
      else
         begin
         lstClusters.ItemIndex := 0;
         end;
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

   BeginLoading;
   try
      c := FStore.Cluster(lstClusters.ItemIndex);
      edtClusterName.Text     := c.Name;
      cbxClusterServer.Text   := c.Server;
      edtClusterLogin.Text    := c.LoginCall;
      edtClusterPassword.Text := c.Password;
      edtClusterCommand.Text  := c.ConnectCommand;
   finally
      EndLoading;
   end;
end;

procedure TPrefsForm.CaptureSelectedCluster;
var
   c: TClusterDefinition;
   wasActive: boolean;
begin
   if Loading then
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
   // forget it.  Below the Loading guard on purpose: loading the form is not
   // an edit, and marking it dirty would arm the unsaved-changes prompt on a
   // window nobody has touched.
   Dirty := True;
end;

procedure TPrefsForm.lstClustersChange(Sender: TObject; User: boolean);
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

   if MessageDlg(Format(TC_REMOVECLUSTERS, [FStore.Cluster(i).Name]),
                 TMsgDlgType.mtConfirmation,
                 [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
      begin
      Exit;
      end;

   FStore.DeleteCluster(i);
   LoadClusterList;
end;

// Choose the rotator that turns.  Mirrors btnUseClusterClick, deliberately: the
// operator learns one idiom -- a tick in the list and a "Use this" button --
// and it means the same thing on both pages.
procedure TPrefsForm.btnUseRotatorClick(Sender: TObject);
begin
   if (lstRotators.ItemIndex < 0) or (lstRotators.ItemIndex >= FStore.RotatorCount) then
      begin
      Exit;
      end;

   { BOTH: the id is the reference, the name is the readable mirror. }
   FStore.ActiveRotatorId   := FStore.Rotator(lstRotators.ItemIndex).Id;
   FStore.ActiveRotatorName := FStore.Rotator(lstRotators.ItemIndex).Name;
   ShowActiveRotator;
   LoadRotatorList;   // redraw so the tick moves

   // Choosing which rotator turns IS a change to be saved.  Without this the
   // tick moves, the operator closes the window, and the choice is gone.
   Dirty := True;

   // NOT re-configured here.  ConfigureRotators reopens serial ports, and doing
   // that from a settings window while the operator is mid-contest would drop a
   // working port for a choice that takes effect on the next start anyway.
end;

// Say which rotator turns, in words, under the list.  The tick alone answers
// "which one" but not "and the others do nothing", which is the part that was
// invisible when every defined rotator was live.
procedure TPrefsForm.ShowActiveRotator;
var
   i: integer;
begin
   i := FStore.IndexOfActiveRotator;
   if i < 0 then
      begin
      if FStore.RotatorCount > 0 then
         begin
         // Matches what ConfigureRotators will actually do, rather than leaving
         // the operator to guess that "none chosen" means "the first one".
         lblActiveRotator.Caption :=
            'No rotator chosen -- ' + FStore.Rotator(0).Name + ' will be used.';
         end
      else
         begin
         lblActiveRotator.Caption := 'No rotators defined.';
         end;
      Exit;
      end;

   lblActiveRotator.Caption := 'Turning: ' + FStore.Rotator(i).Name +
      '   (the others are configured but do not turn)';
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

// The tick is the SAME mark the cluster list uses, because it means the same
// thing: this is the one in use. Without it the list said only which rotator
// you were editing, while every defined rotator was turning (NY4I, 2026-08-16).
//
// The band claim is shown too. A blank claim means EVERY band, and that being
// invisible is what made "both of mine are turning" impossible to see.
function RotatorRowText(const aRotator: TRotatorDefinition;
                        const aIsActive: boolean): string;
var
   mark, bands: string;
begin
   if aIsActive then
      begin
      mark := CLUSTER_ACTIVE_MARK;
      end
   else
      begin
      mark := CLUSTER_INACTIVE_MARK;
      end;

   if Trim(aRotator.Bands) = '' then
      begin
      bands := 'all bands';
      end
   else
      begin
      bands := aRotator.Bands;
      end;

   Result := Format('%s%s [%s]  -  %s',
      [mark, aRotator.Name, RotatorDisplayName(aRotator.RotatorId), bands]);
end;

function TPrefsForm.RotatorIsActive(const aRotator: TRotatorDefinition): boolean;
begin
   // BY ID. It used to be by name, and the comment here said renaming the
   // active rotator "must carry ActiveRotatorName with it" -- nothing did, and
   // the editor writes r.Name on EVERY KEYSTROKE in the name box, so typing a
   // new name silently deactivated the rotator one letter in.
   //
   // The name is still accepted as a fallback so a store written before rotator
   // ids keeps its active rotator until it is next saved.
   Result := (aRotator <> nil)
             and (((FStore.ActiveRotatorId <> '')
                   and SameText(aRotator.Id, FStore.ActiveRotatorId))
                  or ((FStore.ActiveRotatorId = '')
                      and (FStore.ActiveRotatorName <> '')
                      and SameText(aRotator.Name, FStore.ActiveRotatorName)));
end;

procedure TPrefsForm.ShowRotatorRow(const aIndex: integer;
                                    const aRotator: TRotatorDefinition);
begin
   if (aIndex < 0) or (aIndex >= lstRotators.Items.Count) or (aRotator = nil) then
      begin
      Exit;
      end;

   SetListItemText(lstRotators, aIndex,
                   RotatorRowText(aRotator, RotatorIsActive(aRotator)));
end;

procedure TPrefsForm.LoadRotatorList;
var
   i: integer;
   id: string;
   keep, active: integer;
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
      ClearComboItems(cbxRotatorPort);
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
         lstRotators.Items.Add(RotatorRowText(FStore.Rotator(i),
                                              RotatorIsActive(FStore.Rotator(i))));
         end;
   finally
      lstRotators.Items.EndUpdate;
   end;

   // KEEP THE OPERATOR'S SELECTION on a redraw, but OPEN on the ACTIVE one.
   //
   // Opening on index 0 meant the tick sat on one rotator while the fields
   // below described another -- the page said "Turning: RT-21" over PSTRotator's
   // port and baud rate (NY4I, 2026-08-17).  Reading a form that contradicts
   // itself costs more than the redraw it saved.
   //
   // `keep` is >= 0 only when this is a REDRAW of a list the operator was
   // already working in, so their selection survives Add, Remove and Use this.
   if (keep >= 0) and (keep < lstRotators.Items.Count) then
      begin
      lstRotators.ItemIndex := keep;
      end
   else if lstRotators.Items.Count > 0 then
      begin
      active := FStore.IndexOfActiveRotator;
      if (active >= 0) and (active < lstRotators.Items.Count) then
         begin
         lstRotators.ItemIndex := active;
         end
      else
         begin
         // No choice recorded: the first is what ConfigureRotators will use, so
         // it is also what the page should be showing.
         lstRotators.ItemIndex := 0;
         end;
      end;

   ShowSelectedRotator;
   ShowActiveRotator;   // the tick says which; this says what that means
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

   BeginLoading;
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
      EndLoading;
   end;
end;

procedure TPrefsForm.CaptureSelectedRotator;
var
   r: TRotatorDefinition;
   n: integer;
   ids: TArray<string>;
begin
   if Loading then
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

procedure TPrefsForm.lstRotatorsChange(Sender: TObject; User: boolean);
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

   if MessageDlg(Format(TC_REMOVEROTATORS, [FStore.Rotator(i).Name]),
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

   edtMainFont.Text := CommandText('MAIN FONT');
   edtFontSize.Text := CommandText('FONT SIZE');
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
      ApplyIfChanged('SCP MINIMUM LETTERS',
                           cbxSCPMinLetters.Items[cbxSCPMinLetters.ItemIndex]);
      end;
   ApplyIfChanged('SCP COUNTRY STRING',  Trim(edtSCPCountry.Text));

   ApplyIfChanged('SERVER ADDRESS',  Trim(edtNetAddress.Text));
   ApplyIfChanged('SERVER PORT',     Trim(edtNetPort.Text));
   // NOT trimmed: a password may legitimately begin or end with a space, and
   // silently removing one turns "wrong password" into an unsolvable puzzle.
   ApplyIfChanged('SERVER PASSWORD', edtNetPassword.Text);
   ApplyIfChanged('COMPUTER ID',     Trim(edtNetComputerID.Text));
   SetCommandBool('SERVER AUTO SYNCHRONIZE LOG ON CONNECT', chkNetAutoSync.Checked);
   ApplyIfChanged('RADIO TCP SERVER PORT', Trim(edtRadioTCPPort.Text));

   ApplyIfChanged('MAIN FONT', Trim(edtMainFont.Text));
   ApplyIfChanged('FONT SIZE', Trim(edtFontSize.Text));
   SetCommandBool('BOLD FONT',              chkBoldFont.Checked);
   SetCommandBool('COLUMN DUPESHEET COLOR', chkDupeSheetColor.Checked);

   ApplyIfChanged('BACKUP LOG FREQUENCY', Trim(edtBackupEvery.Text));
   ApplyIfChanged('BACKUP LOG FILE NAME', Trim(edtBackupFile.Text));
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
   { Whether there is a server directory at all, said beside the drop-down.
     Here rather than in LoadClusterServerList because that one is deferred to
     the combo's OnEnter -- the operator would otherwise have to click the
     control to be told why it is empty. }
   ShowClusterDirectoryState;

   // TELNET SERVER is no longer edited directly -- it is a rendering of
   // whichever cluster is active, written in SaveClusterPanels.

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

   { AND REPOINT THE CLUSTER WINDOW'S DROP-DOWN AT THE EDITED LIBRARY, without
     changing what the operator has selected there. Adding or renaming a cluster
     must not silently move the window to a different server -- possibly one it
     is not connected to -- so the refresh restores the previous choice. }
   TelnetRefreshClusterList;

   ApplyIfChanged('BAND MAP DECAY TIME',    Trim(edtBandMapDecay.Text));
   ApplyIfChanged('BAND MAP GUARD BAND',    Trim(edtBandMapGuard.Text));
   ApplyIfChanged('BAND MAP DISPLAY LIMIT', Trim(edtBandMapLimit.Text));

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
   { DXLab SpotCollector. LOADED AND SAVED HERE because the control lives on the
     DXLab page -- it was read by LoadClusterPanels while sitting on the DX
     Cluster page, which is how a control and the code that fills it come to
     disagree about which page they are on. }
   chkSpotCollector.Checked     := CommandBool('SPOT COLLECTOR ENABLED');

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

{ HARDWARE ROOT -- station-wide hardware.

  NY4I: the relay control port is per STATION, not per radio ("someone using an
  LPT port to handle switching external hardware"), so it belongs here rather
  than on a radio. Anything targeting a Radio1/Radio2 variable belongs on the
  radio form instead -- that is the rule this panel exists to respect. }
procedure TPrefsForm.LoadLPTCombo(const aCombo: TComboBox; const aLabel: TLabel;
                                  const aCommand: string);
var
   v, label_: string;
   idx, i, want: integer;
begin
   if aCombo = nil then
      begin
      Exit;
      end;

   // Read the configured value FIRST: whether to collapse the list to
   // "not available" depends on it, not only on what the machine reports.
   v := UpperCase(Trim(FStore.CommandValue(aCommand,
                       CFGCommandValueAsString(aCommand))));
   if (v = '') or (v = 'NONE') then
      begin
      want := 0;
      end
   else
      begin
      want := StrToIntDef(v, 0);
      end;

   aCombo.Items.BeginUpdate;
   try
      aCombo.Items.Clear;
      // The VALUE is the spelling CFGCA accepts -- GetLPTPortFromChar
      // (CfgCmd:192) reads 'NONE' or '1'/'2'/'3'. It is carried in Objects[] so
      // the label is free to say more than the value does; reading the value
      // back off the visible text would break the moment the label changed.
      // NOTHING TO PICK AND NOTHING CONFIGURED -> say so, and stop.
      //
      // Listing three ports that do not exist invites a choice that cannot work
      // (NY4I). But a station whose port TR4W cannot SEE must still show it --
      // an unusual driver or an oddly enumerated add-in card is exactly the case
      // where silently rewriting the setting would be worst -- so the list is
      // only collapsed when the machine has no ports AND none is configured.
      if (PresentLPTPortsDescription = '') and (want = 0) then
         begin
         aCombo.Items.AddObject('Not available (no parallel ports)',
                                TObject(PtrInt(0)));
         aCombo.ItemIndex := 0;
         aCombo.Enabled   := False;
         if aLabel <> nil then
            begin
            aLabel.Enabled := False;
            end;
         Exit;
         end;

      aCombo.Enabled := True;
      if aLabel <> nil then
         begin
         aLabel.Enabled := True;
         end;
      aCombo.Items.AddObject('None', TObject(PtrInt(0)));
      for i := 1 to 3 do
         begin
         // ANNOTATED, NOT REMOVED. Dropping undetected ports would silently
         // change a station whose port TR4W cannot see -- a driver arrangement
         // this does not recognise, or an add-in card enumerated oddly -- from
         // its configured port to whatever happened to be first. Saying "not
         // detected" informs without deciding, and the operator keeps the final
         // say over their own hardware.
         label_ := IntToStr(i);
         if LPTPortPresent(i) then
            begin
            label_ := label_ + '   (LPT' + IntToStr(i) + ' detected)';
            end
         else
            begin
            label_ := label_ + '   (not detected)';
            end;
         aCombo.Items.AddObject(label_, TObject(PtrInt(i)));
         end;
   finally
      aCombo.Items.EndUpdate;
   end;

   // BY STORED VALUE, never by index. The labels carry detection text, so
   // matching on them would break the first time that wording changed -- and
   // index arithmetic is what the COM picker was fixed for.
   aCombo.ItemIndex := 0;
   for idx := 0 to aCombo.Items.Count - 1 do
      begin
      if PtrInt(aCombo.Items.Objects[idx]) = want then
         begin
         aCombo.ItemIndex := idx;
         Break;
         end;
      end;
end;

procedure TPrefsForm.SaveLPTCombo(const aCombo: TComboBox; const aCommand: string);
var
   n: integer;
begin
   if (aCombo = nil) or (aCombo.ItemIndex < 0) then
      begin
      Exit;
      end;
   // NOT WHEN THE LIST COLLAPSED. "Not available" carries 0, and writing that
   // would turn "this machine has no parallel port today" into "the operator
   // chose None" -- erasing the setting of someone who moved a log to a laptop
   // and back. Nothing to pick means nothing to save.
   if not aCombo.Enabled then
      begin
      Exit;
      end;

   // The stored value comes from Objects[], NOT from the visible text -- the
   // label says '1   (not detected)' and CFGCA accepts '1'.
   n := PtrInt(aCombo.Items.Objects[aCombo.ItemIndex]);
   if n = 0 then
      begin
      ApplyIfChanged(aCommand, 'NONE');
      end
   else
      begin
      ApplyIfChanged(aCommand, IntToStr(n));
      end;
end;

procedure TPrefsForm.LoadHardwarePanel;
begin
   if cbxRelayPort = nil then
      begin
      Exit;
      end;

   // ALL FOUR ARE STATION CABLING, not radio settings, which is why they are
   // here and not on the radio form. NY4I placed the two BAND OUTPUT ports here
   // deliberately ('breaking my own rule'): the rule sends anything addressing
   // Radio1/Radio2 to the radio form, but what these name is which LPT pin
   // header drives the band decoder for an operating position -- that belongs to
   // the desk, and it stays put when a different radio is activated into the
   // slot. Holding it on the radio DEFINITION was in fact a live defect: every
   // activation re-rendered the key, and would have reverted whatever was set
   // here. See the note in uRadioConfigLegacyMap.
   LoadLPTCombo(cbxRelayPort,   lblRelayPort,   'RELAY CONTROL PORT');
   LoadLPTCombo(cbxBandOutput1, lblBandOutput1, 'RADIO ONE BAND OUTPUT PORT');
   LoadLPTCombo(cbxBandOutput2, lblBandOutput2, 'RADIO TWO BAND OUTPUT PORT');
   LoadLPTCombo(cbxStereoPort,  lblStereoPort,  'STEREO CONTROL PORT');

   // USE CONTROL PORT -- A PLACEHOLDER, deliberately unchecked and deliberately
   // not editable (NY4I 2026-08-14).
   //
   // It selects the radio's CAT port instead of an LPT port for paddle and foot
   // switch, and the code around it is old enough that its intent is no longer
   // clear from reading it: LogCfg's TryRunPaddleAndFootSwitchThread gates on the
   // CAT port HANDLE, which NY4I reads as 'unless the CAT port is open we will
   // not use a foot switch or paddle on the LPT port at all'.
   //
   // It is here so the decision is visible rather than buried in Ctrl-J: whether
   // TR4W supports LPT ports at all in 2026. NY4I is leaning towards not.
   //
   // SHOWN FALSE, BUT NOT WRITTEN. SaveHardwarePanel does not store this, so a
   // station that has it set keeps its value and its paddle keeps working. A
   // disabled control that silently rewrote the setting behind it would be a
   // data change disguised as a UI decision -- and this one is not decided yet.
   chkUseControlPort.Checked := False;

   chkYCCCSO2R.Checked := CommandBool('YCCC SO2R ENABLE');

   logger.Info('[Prefs] parallel ports detected: %s',
               [IfThen(PresentLPTPortsDescription = '', 'none',
                       PresentLPTPortsDescription)]);
end;

procedure TPrefsForm.SaveHardwarePanel;
begin
   SaveLPTCombo(cbxRelayPort,   'RELAY CONTROL PORT');
   SaveLPTCombo(cbxBandOutput1, 'RADIO ONE BAND OUTPUT PORT');
   SaveLPTCombo(cbxBandOutput2, 'RADIO TWO BAND OUTPUT PORT');
   SaveLPTCombo(cbxStereoPort,  'STEREO CONTROL PORT');

   SetCommandBool('YCCC SO2R ENABLE', chkYCCCSO2R.Checked);
end;

procedure TPrefsForm.cbxRelayPortChange(Sender: TObject);
begin
   // Was empty, for the same reason and with the same consequence as
   // cbxLogLevelChange above: an assigned handler suppresses MarkDirty, so
   // changing the relay port and closing the window lost it without a prompt.
   // Mark, do not apply -- Cancel still discards.
   Dirty := True;
end;

procedure TPrefsForm.SaveExternalSoftwarePanels;
begin
   SetCommandBool('SPOT COLLECTOR ENABLED',       chkSpotCollector.Checked);
   SetCommandBool('WSJT-X ENABLED',               chkWSJTXEnabled.Checked);
   SetCommandBool('WSJT-X RADIO CONTROL ENABLED', chkWSJTXRadioControl.Checked);
   SetCommandBool('WSJT-X SEND HIGHLIGHTS',       chkWSJTXHighlights.Checked);
   ApplyIfChanged('WSJT-X BROADCAST PORT',  Trim(edtWSJTXPort.Text));
   ApplyIfChanged('WSJT-X MULTICAST GROUP', Trim(edtWSJTXMulticast.Text));

   if cbxLoggerType.ItemIndex >= 0 then
      begin
      ApplyIfChanged('EXTERNAL LOGGER',
                           cbxLoggerType.Items[cbxLoggerType.ItemIndex]);
      end;
   SetCommandBool('EXTERNAL LOGGER ENABLED', chkLoggerEnabled.Checked);
   ApplyIfChanged('EXTERNAL LOGGER ADDRESS', Trim(edtLoggerAddress.Text));
   ApplyIfChanged('EXTERNAL LOGGER PORT',    Trim(edtLoggerPort.Text));

   ApplyIfChanged('MMTTY ENGINE', Trim(edtMMTTYEngine.Text));
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


procedure TPrefsForm.BrowseForFolder(const aEdit: TEdit; const aTitle: string);
var
   dlg: TSelectDirectoryDialog;
begin
   dlg := TSelectDirectoryDialog.Create(nil);
   try
      dlg.Title := aTitle;
      // START WHERE THE OPERATOR ALREADY IS. A relative folder ('DVK' is the
      // shipped default) expands against the program directory, which is what it
      // means at run time -- opening the picker at the current working directory
      // instead would send them somewhere the setting never referred to.
      if Trim(aEdit.Text) <> '' then
         begin
         dlg.InitialDir := ExpandFileName(Trim(aEdit.Text));
         end;
      if dlg.Execute then
         begin
         aEdit.Text := dlg.FileName;
         end;
   finally
      dlg.Free;
   end;
end;

procedure TPrefsForm.BrowseForProgram(const aEdit: TEdit; const aTitle,
                                      aFilter: string);
var
   dlg: TOpenDialog;
begin
   dlg := TOpenDialog.Create(nil);
   try
      dlg.Title  := aTitle;
      dlg.Filter := aFilter;
      if Trim(aEdit.Text) <> '' then
         begin
         dlg.FileName := Trim(aEdit.Text);
         end;
      if dlg.Execute then
         begin
         aEdit.Text := dlg.FileName;
         end;
   finally
      dlg.Free;
   end;
end;

procedure TPrefsForm.btnBrowseDVKPathClick(Sender: TObject);
begin
   BrowseForFolder(edtDVKPath, 'Folder for DVK recordings');
end;

procedure TPrefsForm.btnBrowseDVKRecorderClick(Sender: TObject);
begin
   // DLLs ARE OFFERED, and that is not a slip: NY4I's own station has
   // lame_enc.dll in this field. The recorder is whatever component does the
   // encoding, so a filter that showed only .exe would hide the working answer.
   BrowseForProgram(edtDVKRecorder, 'DVK recorder',
                    'Programs and encoders (*.exe;*.dll)|*.exe;*.dll|' +
                    'All files (*.*)|*.*');
end;

procedure TPrefsForm.btnBrowseMP3PathClick(Sender: TObject);
begin
   BrowseForFolder(edtMP3Path, 'Folder for MP3 recordings');
end;

procedure TPrefsForm.btnBrowseMP3PlayerClick(Sender: TObject);
begin
   BrowseForProgram(edtMP3Player, 'MP3 player',
                    'Programs (*.exe)|*.exe|All files (*.*)|*.*');
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
   // Refusing outright would be worse than useless.  IsAGoodCall is a syntax
   // heuristic and real operators hold calls it will not love -- special event
   // calls, unusual prefixes, /MM.  A settings screen that will not accept the
   // operator's own callsign is a bug however good the checker is.  So the
   // check exists to catch a TYPO, and confirming means it is taken as typed.
   //
   // IsAGoodCall, NOT LooksLikeACallSign.  They answer different questions.
   // LooksLikeACallSign asks "is this token in a RECEIVED EXCHANGE probably a
   // call", so it deliberately tolerates partials -- and it reads the global
   // `contest` for a PCC special case.  IsAGoodCall asks "is this a
   // well-formed callsign", which is what a settings field is asking, and it is
   // already extracted into uCallSignRoutines and already unit-tested.
   //
   // Blank is NOT queried: IsAGoodCall('') is False, so checking it would
   // nag every time the operator cleared the field.
   callText := Trim(edtMyCall.Text);
   if (callText <> '') and (not IsAGoodCall(callText)) then
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
      if not ApplyIfChanged(f.Command, Trim(f.Edit.Text)) then
         begin
         bad := bad + f.Command + ' = "' + Trim(f.Edit.Text) + '"' + sLineBreak;
         Result := False;
         end;
      end;

   if cbxMyContinent.ItemIndex >= 0 then
      begin
      if not ApplyIfChanged('MY CONTINENT',
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
      ShowMessage(TC_THESEENTRIESWEREACCEPTEDBEENSAVED
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
   // AN EMPTY HANDLER IS NOT THE SAME AS NO HANDLER, and that is the whole bug.
   //
   // This was empty, on the reasoning that nothing should be applied until Save.
   // That reasoning is right -- DiscardChanges really does reload from disk, so
   // applying here would survive a Cancel that promised to discard it.  But
   // HookDirtyMarker attaches MarkDirty only to a control with NO handler
   // assigned, so merely EXISTING stopped this combo from marking the form
   // dirty: Apply stayed greyed, the close prompt never appeared, and choosing
   // a log level and shutting the window lost it in silence.
   //
   // Mark, do not apply.  That keeps the Cancel contract and lets Apply, OK and
   // the close prompt do what they are for.
   Dirty := True;
end;

procedure TPrefsForm.btnOpenLogFileClick(Sender: TObject);
var
   fileName: string;
begin
   if not Assigned(appender) then
      begin
      ShowMessage(TC_LOGGINGRUNNINGSOTHERENOFILEOPEN);
      Exit;
      end;

   fileName := ExpandFileName(appender.FileName);
   if not FileTextExists(fileName) then
      begin
      ShowMessage(Format(TC_THERENOLOGFILEYETS, [fileName]));
      Exit;
      end;

   // OpenDocument, so the operator's own choice of text editor opens it --
   // the LCL's own launcher, which is ShellExecute here and xdg-open or `open`
   // elsewhere.  Nothing is written and the file stays open in the appender --
   // which is why there is no "Clear log file" button beside this one: the
   // rolling appender holds the handle, and truncating underneath it is not
   // something to do casually from a settings screen.
   LCLIntf.OpenDocument(fileName);
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
   prof: TStationProfile;
   thisCombo, otherCombo: TComboBox;
   chosen, taken, previous: string;
begin
   thisCombo  := aThisCombo;
   otherCombo := aOtherCombo;

   if Loading then
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
      { AN ID, because that is what the combo's tag now is and what
        SelectByTag below will look for. Reverting to a NAME would match no
        item and silently clear the slot. }
      if thisCombo = cbxRadio2 then
         begin
         previous := prof.Radio2Id;
         end
      else
         begin
         previous := prof.Radio1Id;
         end;

      // REVERTED SILENTLY.  The row the operator clicked says "(in use as
      // Radio 1)" in as many words, so the reason was on screen before the
      // click -- a modal afterwards only repeats it, later and more loudly.
      //
      // It also removes a real defect rather than papering over it: showing a
      // message box from inside a combo's OnChange put the dialog up TWICE
      // (NY4I 2026-08-08).  Reverting is a control assignment, which the
      // Loading guard already covers; a modal is re-entrant in a way no guard
      // here was going to make reliable.
      BeginLoading;
      try
         SelectByTag(thisCombo, previous);
      finally
         EndLoading;
      end;
      Exit;
      end;

   CaptureProfileFields;

   // Refilling fires the combo's own OnChange; the guard stops that from
   // writing a half-built list back into the profile.
   BeginLoading;
   try
      FillCWOutputCombo(aThisCWCombo, SelectedTag(aThisCWCombo), SelectedTag(thisCombo));

      // The OTHER slot's list is now stale: whatever this slot just took must
      // become unavailable over there, and whatever it released must come back.
      // Rebuilt preserving that slot's own selection, so refreshing the greying
      // never changes a choice the operator made.
      FillRadioNameCombo(cbxRadio1, SelectedTag(cbxRadio1), SelectedTag(cbxRadio2), TC_PREFS_RADIO2);
      FillRadioNameCombo(cbxRadio2, SelectedTag(cbxRadio2), SelectedTag(cbxRadio1), TC_PREFS_RADIO1);
   finally
      EndLoading;
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
   BeginLoading;
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
      EndLoading;
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
   if (FUDPConfig = nil) or Loading then
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
                     PAnsiChar(WinAnsi(Format(TC_PREFS_PORTCONFLICT, [conflicts]))),
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
   // their change events, and while Loading suppresses the marker, clearing the
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

   // A FRESH SEARCH BOX ON EVERY OPENING.  This form is a cached singleton
   // shown modeless (ShowPreferences reuses gPrefsForm), so everything about it
   // survives a close -- including the search text.  Reopening Preferences
   // showed the PREVIOUS search still sitting in the box while the results list
   // it belonged to was long hidden, which is text describing nothing on
   // screen.  NY4I, 2026-08-18.
   //
   // Assigning Text fires edtSearchChange -> RunSearch(''), which takes the
   // empty-needle path and hides the results, so this needs no second call and
   // cannot leave a stale hit list behind.
   //
   // NOT cleared when a hit is CHOSEN, which is the other half of what NY4I
   // raised. ActivateSearchHit already hides the list; keeping the text is what
   // lets a search with several matches be revisited -- type one character and
   // the list is back -- and the box AutoSelects on focus, so replacing the
   // query is still a single action. Clearing there would mean retyping the
   // whole query to check the second match, which is the common case.
   edtSearch.Text := '';
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
                            PAnsiChar(WinAnsi(TC_PREFS_UNSAVED)),
                            PAnsiChar(WinAnsi(TC_PREFS_UNSAVEDTITLE)),
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
