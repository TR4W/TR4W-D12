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
unit uSetupWizardForm;
{$I ..\..\tr4w.inc}

(* THE SETUP WIZARD -- docs/SETUP_WIZARD_DESIGN.md is the design.

  One Station page, one checklist (Radio, WinKeyer, DX cluster, external
  logger, rotator, WSJT-X), one page per ticked item in canonical order, then
  "Create configuration" and a result page that says what landed and what did
  not.  Opens by itself on a brand-new install (uProgramMain) and from
  Tools -> Setup Wizard.

  WHAT THIS UNIT OWNS AND WHAT IT DOES NOT (design 3.1).  The wizard owns
  intent and navigation.  It declares no setting of its own:

    station     written through ApplyAndStoreCommand, the Preferences Station
                page's own path, so CheckCommand's hooks, bounds and the
                multi-op broadcast all apply exactly as they do there
    radio/keyer edited in the EXISTING editors (TRadioEditForm,
                TfrmKeyerEdit), HOSTED as this window's own pages -- their
                content panels moved in, never a second window -- on a copy
                the wizard holds
    all three   put in the stores by uSetupWizard.StageSetupItems, then saved
                and applied with SaveConfig, ApplyProfile and
                ApplyActiveCluster -- what Preferences' Activate does
    logger      edited in the EXISTING editor (TExternalLoggersForm), hosted
                the same way (EditLoggerIn), on a copy of the definitions;
                staged by StageSetupLogger after the startup seed
                (SeedExternalLoggers), its secrets left to SaveConfig's
                keychain path (issue 334)
    rotator     the rotator type and port, as Preferences' Rotators page sets
                them (FillRotatorTypeCombo, RotatorUsesSerialPort,
                FillSerialPortCombo), staged by StageSetupRotator and made
                live with ConfigureRotators -- what Preferences' save does
    WSJT-X      the five Settings.Wsjtx settings Preferences' WSJT-X page
                offers (switch, UDP port, highlights, radio control and its
                DX Commander interface, multicast group), each written only
                if changed (SetupWsjtxChanges), through ApplyAndStoreCommand
                like the station

  ORDER SO THAT FAILURE COSTS NOTHING (design 3.2).  Nothing is written until
  "Create configuration".  Then the station is applied and SAVED FIRST, and
  only then are the radio, keyer and cluster staged, validated, saved and put
  into use -- so a radio that will not open cannot cost the callsign.

  MODELESS from Tools -> Setup Wizard, for the editors' reason: ShowModal runs
  a second message loop, and TR4W's CW timing and radio servicing would stop
  for as long as the wizard was up.  Owned by the main window so it stays in
  front of it.  One at a time (gSetupWizard), freed on close, so every opening
  starts from what is on disk.  The STARTUP run is modal instead (see
  RunSetupWizardAtStartup): nothing is being serviced yet. *)

interface

uses
   SysUtils,
   Classes,
   Generics.Collections,
   Controls,
   Forms,
   StdCtrls,
   ExtCtrls,
   ComCtrls,
   uInputCaption,     // TInputCaption -- a caption a screen reader can name (issue 278)
   uRadioConfigStore,
   uKeyerConfigStore,
   uRadioEditForm,
   uKeyerEditForm,
   uExternalLoggerConfig,   // TExternalLoggerDefinition -- the logger draft
   uExternalLoggersForm,    // TExternalLoggersForm -- hosted on the logger page
   uCallbookBase,       // TCallbookRecord
   uSetupWizard;

type
   (* ONE STATION FIELD: the command it writes, the box that shows it, what it
     held when the wizard opened, and -- for the four the callsign decides --
     whether the operator has made it theirs.  Only a field that changed is
     written; a derived field that is still derived is never written, so the
     program goes on deriving it from the callsign. *)
   TWizStationField = class(TObject)
   public
      Command: string;
      Edit: TEdit;
      Loaded: string;
      Derivable: boolean;
      OperatorOwned: boolean;
   end;

   TfrmSetupWizard = class(TForm)
      pnlHeader: TPanel;
      lblHeading: TLabel;
      lblStep: TLabel;
      lblIntro: TLabel;
      pgPages: TPageControl;

      tsStation: TTabSheet;
      edtCall: TEdit;
      lblCall: TInputCaption;
      edtName: TEdit;
      lblName: TInputCaption;
      edtGrid: TEdit;
      lblGrid: TInputCaption;
      edtState: TEdit;
      lblState: TInputCaption;
      edtSection: TEdit;
      lblSection: TInputCaption;
      edtPostal: TEdit;
      lblPostal: TInputCaption;
      edtZone: TEdit;
      lblZone: TInputCaption;
      edtITUZone: TEdit;
      lblITUZone: TInputCaption;
      edtCountry: TEdit;
      lblCountry: TInputCaption;
      cbxContinent: TComboBox;
      lblContinent: TInputCaption;
      lblLookup: TLabel;
      lblCtyStatus: TLabel;
      btnCtyDownload: TButton;
      lblDerived: TLabel;

      tsChecklist: TTabSheet;
      chkRadio: TCheckBox;
      lblRadioHint: TLabel;
      chkKeyer: TCheckBox;
      lblKeyerHint: TLabel;
      chkCluster: TCheckBox;
      lblClusterHint: TLabel;
      chkLogger: TCheckBox;
      lblLoggerHint: TLabel;
      chkRotator: TCheckBox;
      lblRotatorHint: TLabel;
      chkWSJTX: TCheckBox;
      lblWSJTXHint: TLabel;

      (* The Radio and WinKeyer sheets are empty in the designer: each is the
        host of the existing editor's panel (EditRadioIn / EditKeyerIn), so the
        editor is a page of THIS window and not a second one. *)
      tsRadio: TTabSheet;
      tsKeyer: TTabSheet;
      (* The wizard's own two choices under the hosted radio editor, shown only
        for a radio that can do them -- see UpdateCWChoices. *)
      chkCWByCAT: TCheckBox;
      chkSpeedSync: TCheckBox;

      tsCluster: TTabSheet;
      cbxServer: TComboBox;
      lblServer: TInputCaption;
      edtPort: TEdit;
      lblPort: TInputCaption;
      lblServerHint: TLabel;
      edtLogin: TEdit;
      lblLogin: TInputCaption;
      edtPassword: TEdit;
      lblPassword: TInputCaption;
      edtCommand: TEdit;
      lblCommand: TInputCaption;

      (* Empty in the designer, like the Radio sheet: the host of the external
        logger editor's panel (EditLoggerIn). *)
      tsLogger: TTabSheet;

      tsRotator: TTabSheet;
      cbxRotatorType: TComboBox;
      lblRotatorType: TInputCaption;
      cbxRotatorPort: TComboBox;
      lblRotatorPort: TInputCaption;
      edtRotatorIP: TEdit;
      lblRotatorIP: TInputCaption;
      edtRotatorUDP: TEdit;
      lblRotatorUDP: TInputCaption;

      (* Every Settings.Wsjtx setting Preferences' WSJT-X page offers.  The
        rows below the port hang from the row above (AnchorSideTop), so a
        wrapped hint pushes what follows down by itself on every widget set. *)
      tsWSJTX: TTabSheet;
      chkWSJTXEnable: TCheckBox;
      edtWSJTXPort: TEdit;
      lblWSJTXPort: TInputCaption;
      chkWSJTXHighlights: TCheckBox;
      lblWSJTXHighlightsHint: TLabel;
      chkWSJTXRadioControl: TCheckBox;
      lblWSJTXRadioControlHint: TLabel;
      edtWSJTXMulticast: TEdit;
      lblWSJTXMulticast: TInputCaption;
      lblWSJTXMulticastHint: TLabel;

      tsResult: TTabSheet;
      memResult: TMemo;
      chkDetails: TCheckBox;

      pnlButtons: TPanel;
      btnBack: TButton;
      btnNext: TButton;
      btnCancel: TButton;
      tmrLookup: TTimer;

      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
      procedure HandleCloseQuery(Sender: TObject; var CanClose: boolean);
      procedure btnCtyDownloadClick(Sender: TObject);
      procedure btnBackClick(Sender: TObject);
      procedure btnNextClick(Sender: TObject);
      procedure btnCancelClick(Sender: TObject);
      procedure edtCallChange(Sender: TObject);
      procedure DerivedFieldChange(Sender: TObject);
      procedure ChecklistChange(Sender: TObject);
      procedure tmrLookupTimer(Sender: TObject);
      procedure GridExit(Sender: TObject);
      procedure ServerExit(Sender: TObject);
      procedure ServerSelect(Sender: TObject);
      procedure DetailsChange(Sender: TObject);
      procedure RotatorTypeChange(Sender: TObject);
      procedure WSJTXEnableChange(Sender: TObject);
   private
      FFields: TObjectList<TWizStationField>;
      FContinentLoaded: string;
      FContinentOwned: boolean;
      (* True while code, not the operator, is filling controls -- their
        change events must not mark a field as the operator's. *)
      FFilling: boolean;

      FPlan: TSetupPagePlan;
      FIndex: integer;
      (* The odd-looking callsign the operator has already said yes to, so
        Back-then-Next does not ask again. *)
      FConfirmedCall: string;
      FClusterListLoaded: boolean;

      (* A draft is what an editor accepted when Next was pressed on its page;
        the editing copy is what the editor's controls write into.  Both nil
        until the page is first reached.  Unticking frees all three, editor
        included, so a re-ticked item starts blank. *)
      FRadioDraft: TRadioDefinition;
      FRadioEditing: TRadioDefinition;
      FRadioEditor: TRadioEditForm;
      FKeyerDraft: TKeyerDefinition;
      FKeyerEditing: TKeyerDefinition;
      FKeyerEditor: TfrmKeyerEdit;
      (* THE EXTERNAL LOGGER (issue 334): the hosted editor holds its own copy
        of the definitions; the draft is a copy of the definition it accepted,
        and whether its Active box was ticked. *)
      FLoggerEditor: TExternalLoggersForm;
      FLoggerDraft: TExternalLoggerDefinition;
      FLoggerDraftActive: boolean;
      (* The rotator page's two lists are filled when it is first reached. *)
      FRotatorListsLoaded: boolean;
      (* What the WSJT-X settings held when the wizard opened: only a change
        is written (CommitStation's rule, decided by SetupWsjtxChanges).
        Owned; made in the constructor, before the first LoadWSJTX. *)
      FWSJTXLoaded: TSetupWsjtxValues;
      (* The client height and width the designer gave the window; pages that
        host an editor are taller (and the logger editor wider), and the
        others return to these. *)
      FBaseClientHeight: integer;
      FBaseClientWidth: integer;
      (* The header's designed height: the description under the title may
        wrap to more lines than it was designed for, and the window grows by
        the difference (FitWindowTo). *)
      FBaseHeaderHeight: integer;
      (* RUN FROM STARTUP, BEFORE THE NEW CONTEST WINDOW (ShowSetupWizardAtStartup).
        Nothing exists yet to put a radio or a cluster into use on, and startup
        applies the saved active profile and cluster itself a little later --
        so this run saves and leaves it there.  See Commit. *)
      FStartupMode: boolean;
      (* The country file is being fetched on its own thread, and its done-event
        is a method of this form -- so the form must not be freed under it. *)
      FDownloading: boolean;
      (* The result page's two texts: the brief report, and the same with the
        detail lines added, which "Show details" switches to. *)
      FReportBrief: string;
      FReportDetails: string;
      (* The callsign the callbook was last asked about, so a settled call is
        asked once. *)
      FCallbookCall: string;

      procedure ShowCountryFileState;
      procedure ShowEditorPage(const aPage: TSetupPage);
      procedure FitWindowTo(const aHosted: integer; const aHostedWidth: integer = 0);
      function FitPageColumns: integer;
      function ChecklistHeight: integer;
      procedure LoggerLayoutChanged(Sender: TObject);
      procedure DropLoggerEditor;
      procedure LoadRotatorLists;
      procedure ShowRotatorTransport;
      procedure ClearRotatorPage;
      function RotatorIsSerial: boolean;
      function RotatorDraft: TRotatorDefinition;
      procedure LoadWSJTX;
      procedure ShowWSJTXSwitch;
      function ShownWSJTX: TSetupWsjtxValues;
      procedure CommitWSJTX(const aStore: TRadioConfigStore; var aReport: string);
      procedure UpdateCWChoices;
      procedure RadioTypeChanged(Sender: TObject);
      procedure ShowResult;
      function ClusterServerText: string;
      procedure StartCallbookLookup;
      procedure DropRadioEditor;
      procedure DropKeyerEditor;
      function AcceptEditorPage(const aPage: TSetupPage): boolean;
      procedure CountryFileDownloaded(Sender: TObject; aSucceeded: boolean);
      procedure AddField(const aCommand: string; const aEdit: TEdit;
                         const aDerivable: boolean);
      function FieldForEdit(const aEdit: TObject): TWizStationField;
      procedure AssignCaptions;
      procedure ApplyFieldHelp;
      procedure LoadStation;
      procedure RunLookup;
      function DerivedValue(const aCommand, aCall: string): string;
      function TickedItems: TSetupItems;
      function SheetFor(const aPage: TSetupPage): TTabSheet;
      procedure ShowCurrentPage;
      procedure UpdateButtons;
      function PageIsComplete(const aPage: TSetupPage): boolean;
      function PortsAcceptable: boolean;
      procedure CommitStation(const aStore: TRadioConfigStore;
                              var aReport: string);
      procedure Commit;
      procedure SplitPickedServer(aData: PtrInt);
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      (* A callbook reply, on the main thread.  Fills ONLY the boxes that are
        still empty, and says so. *)
      procedure ApplyCallbook(const aRec: TCallbookRecord);
   end;

(* Open the wizard, or bring the open one forward.  Refuses, with a message,
  while Preferences is on screen: both edit the same libraries from their own
  copies, and the second to save would undo the first. *)
procedure ShowSetupWizard;

(* THE FIRST-RUN OFFER, before the New Contest window, in two steps so startup
  can do its own work between them: AskSetupWizardAtStartup puts the question
  (True on Yes), then startup makes sure a country file is loaded -- the
  callsign lookup needs it, and only startup knows how to fetch one -- and
  RunSetupWizardAtStartup runs the wizard MODALLY and returns when it is
  closed.  Modal is right here and wrong for ShowSetupWizard: no radio is being
  serviced and no CW is being timed yet, so a second message loop stops
  nothing, and the New Contest window that follows must not open over it.

  Nothing is put into use: the radio, keyer and cluster are SAVED, and the
  startup that follows applies the saved active profile and cluster as it does
  on every start.  The callsign it saves is what New Contest then offers. *)
function AskSetupWizardAtStartup: boolean;
procedure RunSetupWizardAtStartup;

implementation

{$R *.lfm}

uses
   (* FIRST, so every unit below wins over it for a shared name: it is here
     for UnqueueAsyncCalls alone. *)
   uMainForm,
   Dialogs,
   System.UITypes,
   ComPortEnumerator,   // the real serial ports, as Preferences' Rotators page lists them
   uSettingsModel,      // Settings.ExternalLogger, Settings.Rotator, Settings.Wsjtx
   uExternalLoggerMigration,   // SeedExternalLoggers -- startup's rule, before adding
   uExternalLoggerFactory,     // ApplyExternalLoggerConfiguration -- what Preferences' save does
   uRotatorRegistry,    // RotatorUsesSerialPort
   uRotatorControl,     // ConfigureRotators -- what Preferences' save does
   VC,                  // ContinentTypeSA
   uctydat,             // ctyGetCountryID, ctyGetZone, ctyGetITUZone, ctyGetContinent
   uCallSignRoutines,   // IsAGoodCall
   uTR4WConfigFile,     // LoadConfig, SaveConfig
   uRadioRegistry,      // SupportsForId -- which radios can do CW by CAT
   uDXLabCommanderProtocol,   // COMMANDER_DEFAULT_PORT -- the port WSJT-X's radio control connects to
   uRadioConfigApply,   // ApplyAndStoreCommand, StationCommandValue, ApplyProfile ...
   uPrefsForm,          // PreferencesIsShowing, LoadClusterDirectory ...
   uLCLFormHelpers,     // OwnFormByMainWindow, FitCaptionColumn, WrappedTextHeight
   uAppStrings,
   uAppPaths,           // DownloadedDataFilePath, HelpDir
   uEmbeddedTranslations, // ActiveUILanguage -- which help catalogue to load
   uCommandHelp,        // TCommandHelp -- every field's tooltip
   uSettingsBinding,    // ApplyCommandHelpHint -- the one tooltip rule
   uCTYUpdate,          // DownloadCTYAsync, LoadCountryFileFrom
   uCallbookFactory,    // LookupCallsignAsync
   LCLIntf,             // GetWindowRect -- the LCL's own, not the Windows unit's
   utils_text,          // LclText -- a UTF-16 string onto an LCL property
   MainUnit;            // logger

const
   (* The row of CW choices under a hosted radio editor, with its gap. *)
   CW_ROW_HEIGHT = 28;

type
   (* THE CALLBOOK'S REPLY ARRIVES ON ITS OWN SCHEDULE, possibly after the
     wizard is gone, and the lookup thread holds a method pointer it cannot be
     told to drop.  So the pointer is to a CLASS method -- there is no
     instance to free while a lookup is in flight, which the unit-finalization
     free of the old relay object was (review M15) -- and the wizard that is
     open (if any) is looked up when the reply comes. *)
   TCallbookRelay = class(TObject)
   public
      class procedure Deliver(const aRec: TCallbookRecord);
   end;

var
   gSetupWizard: TfrmSetupWizard = nil;
   (* The wizard a callbook reply goes to: set by its constructor, cleared by
     its destructor -- not gSetupWizard, which a modal startup run never sets. *)
   gCallbookTarget: TfrmSetupWizard = nil;

class procedure TCallbookRelay.Deliver(const aRec: TCallbookRecord);
begin
   if gCallbookTarget <> nil then
      begin
      gCallbookTarget.ApplyCallbook(aRec);
      end;
end;

procedure ShowSetupWizard;
begin
   if PreferencesIsShowing then
      begin
      ShowMessage(SWizPrefsOpen);
      Exit;
      end;

   if gSetupWizard = nil then
      begin
      gSetupWizard := TfrmSetupWizard.Create(nil);
      (* OWNED BY THE MAIN WINDOW, unlike a tool window (issue #1): a wizard
        is meant to stay in front of the window it is setting up, and at
        startup the main window is promoted after this is shown. *)
      OwnFormByMainWindow(gSetupWizard);
      end;
   gSetupWizard.Show;
   gSetupWizard.BringToFront;
end;

function AskSetupWizardAtStartup: boolean;
begin
   (* Yes/No with the stock button captions, which the LCL localises.  YES is
     the default -- the marker applies to the button before it: this question
     is only ever asked of a station with no callsign, and Enter on it should
     start the guided setup that issue 81 asked for. *)
   Result := QuestionDlg('TR4W', LclText(SWizStartupPrompt),
                         TMsgDlgType.mtConfirmation,
                         [mrYes, 'IsDefault', mrNo], 0) = mrYes;
end;

procedure RunSetupWizardAtStartup;
var
   wizard: TfrmSetupWizard;
begin
   wizard := TfrmSetupWizard.Create(nil);
   try
      wizard.FStartupMode := True;
      wizard.ShowModal;
   finally
      wizard.Free;
   end;
end;

{ TfrmSetupWizard }

constructor TfrmSetupWizard.Create(AOwner: TComponent);
var
   c: ContinentType;
begin
   inherited Create(AOwner);
   gCallbookTarget := Self;
   FFields := TObjectList<TWizStationField>.Create(True);
   FWSJTXLoaded := TSetupWsjtxValues.Create;

   (* THE CALLSIGN FIRST: it is applied first, and its hook derives what the
     later rows have not stated. *)
   AddField('MY CALL',        edtCall,    False);
   AddField('MY NAME',        edtName,    False);
   AddField('MY GRID',        edtGrid,    False);
   AddField('MY STATE',       edtState,   False);
   AddField('MY SECTION',     edtSection, False);
   AddField('MY POSTAL CODE', edtPostal,  False);
   AddField('MY ZONE',        edtZone,    True);
   AddField('MY ITU ZONE',    edtITUZone, True);
   AddField('MY COUNTRY',     edtCountry, True);

   (* From the vocabulary, not typed into the designer -- the Station page's
     rule, so a continent added there appears here too. *)
   cbxContinent.Items.BeginUpdate;
   try
      cbxContinent.Items.Clear;
      for c := Low(ContinentType) to High(ContinentType) do
         begin
         cbxContinent.Items.Add(AnsiString(ContinentTypeSA[c]));
         end;
   finally
      cbxContinent.Items.EndUpdate;
   end;

   FBaseClientHeight := ClientHeight;
   FBaseClientWidth := ClientWidth;
   FBaseHeaderHeight := pnlHeader.Height;
   AssignCaptions;
   (* The captions are final now: every page's label column is fitted to its
     language once, and the window is as wide as the widest page needs. *)
   FBaseClientWidth := FBaseClientWidth
                       + GrowWithinRoom(FitPageColumns, Screen.WorkAreaWidth - Width);
   ApplyFieldHelp;
   LoadStation;
   LoadWSJTX;
   ShowCountryFileState;

   FPlan := SetupPagePlan([]);
   FIndex := 0;
   ShowCurrentPage;
end;

destructor TfrmSetupWizard.Destroy;
begin
   (* The editors first: they hold the editing copies freed with them. *)
   DropRadioEditor;
   DropKeyerEditor;
   DropLoggerEditor;
   FreeAndNil(FRadioDraft);
   FreeAndNil(FKeyerDraft);
   FreeAndNil(FLoggerDraft);
   FreeAndNil(FFields);
   FreeAndNil(FWSJTXLoaded);
   if gSetupWizard = Self then
      begin
      gSetupWizard := nil;
      end;
   if gCallbookTarget = Self then
      begin
      gCallbookTarget := nil;
      end;
   (* A queued split must not find this form gone. Through UnqueueAsyncCalls,
     which skips a nil or stopped Application. That guards THIS call only:
     inherited Destroy (TCustomForm.Destroy) calls Application.RemoveAsyncCalls
     itself, unguarded. What keeps Application alive for a wizard destroyed at
     unit finalization is Interfaces being listed first in tr4w.lpr. *)
   UnqueueAsyncCalls(Self);
   inherited Destroy;
end;

procedure TfrmSetupWizard.AddField(const aCommand: string; const aEdit: TEdit;
                                   const aDerivable: boolean);
var
   f: TWizStationField;
begin
   f := TWizStationField.Create;
   f.Command   := aCommand;
   f.Edit      := aEdit;
   f.Derivable := aDerivable;
   FFields.Add(f);
end;

function TfrmSetupWizard.FieldForEdit(const aEdit: TObject): TWizStationField;
var
   f: TWizStationField;
begin
   Result := nil;
   for f in FFields do
      begin
      if f.Edit = aEdit then
         begin
         Result := f;
         Exit;
         end;
      end;
end;

(* EVERY CAPTION FROM uAppStrings.  The .lfm text is a designer placeholder;
  a caption typed there would ship English to every language (see i18n). *)
procedure TfrmSetupWizard.AssignCaptions;
begin
   Caption                := SWizTitle;
   lblCall.Caption        := SWizCallsign;
   lblName.Caption        := SWizName;
   lblGrid.Caption        := SWizGrid;
   lblState.Caption       := SWizState;
   lblSection.Caption     := SWizSection;
   lblPostal.Caption      := SWizPostal;
   lblZone.Caption        := SWizCQZone;
   lblITUZone.Caption     := SWizITUZone;
   lblCountry.Caption     := SWizCountry;
   lblContinent.Caption   := SWizContinent;
   lblDerived.Caption     := SWizDerivedNote;
   chkCWByCAT.Caption     := SWizRadioCWByCAT;
   chkSpeedSync.Caption   := SWizRadioSpeedSync;
   chkDetails.Caption     := SWizResShowDetails;
   lblPort.Caption        := SWizClusterPort;
   lblServerHint.Caption  := SWizClusterServerHint;
   edtPort.TextHint       := '23';
   lblLookup.Caption      := '';
   btnCtyDownload.Caption := SWizCtyDownload;
   lblCtyStatus.Caption   := '';

   chkRadio.Caption       := SWizItemRadio;
   lblRadioHint.Caption   := SWizItemRadioHint;
   chkKeyer.Caption       := SWizItemKeyer;
   lblKeyerHint.Caption   := SWizItemKeyerHint;
   chkCluster.Caption     := SWizItemCluster;
   lblClusterHint.Caption := SWizItemClusterHint;
   chkLogger.Caption      := SWizItemLogger;
   lblLoggerHint.Caption  := SWizItemLoggerHint;
   chkRotator.Caption     := SWizItemRotator;
   lblRotatorHint.Caption := SWizItemRotatorHint;
   chkWSJTX.Caption       := SWizItemWSJTX;
   lblWSJTXHint.Caption   := SWizItemWSJTXHint;

   lblRotatorType.Caption := SWizRotatorType;
   lblRotatorPort.Caption := SWizRotatorPort;
   lblRotatorIP.Caption   := SWizRotatorAddress;
   lblRotatorUDP.Caption  := SWizRotatorUDPPort;
   chkWSJTXEnable.Caption := SWizWSJTXEnable;
   lblWSJTXPort.Caption   := SWizWSJTXPort;
   chkWSJTXHighlights.Caption       := SWizWSJTXHighlights;
   lblWSJTXHighlightsHint.Caption   := SWizWSJTXHighlightsHint;
   chkWSJTXRadioControl.Caption     := SWizWSJTXRadioControl;
   (* The port is the protocol unit's constant, the one uWSJTX's listener
     uses; the caption must not state a second copy of it. *)
   lblWSJTXRadioControlHint.Caption := Format(SWizWSJTXRadioControlHint,
                                              [COMMANDER_DEFAULT_PORT]);
   lblWSJTXMulticast.Caption        := SWizWSJTXMulticast;
   lblWSJTXMulticastHint.Caption    := SWizWSJTXMulticastHint;

   lblServer.Caption      := SWizClusterServer;
   lblLogin.Caption       := SWizClusterLogin;
   lblPassword.Caption    := SWizClusterPassword;
   lblCommand.Caption     := SWizClusterCommand;

   btnBack.Caption        := SWizBack;
   btnCancel.Caption      := SWizCancel;
end;

(* WHAT THE STATION HOLDS NOW -- the same values the Preferences Station page
  shows, through the same function.  On a brand-new install that is the
  callsign the New Contest window has just taken. *)
procedure TfrmSetupWizard.LoadStation;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   readFrom: TRadioConfigStore;
   loadErr: string;
   f: TWizStationField;
   call: string;
begin
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   FFilling := True;
   try
      readFrom := nil;
      if FileExists(RadioStoreFileName) and
         LoadConfig(RadioStoreFileName, store, keyers, loadErr) then
         begin
         readFrom := store;
         end;

      for f in FFields do
         begin
         f.Loaded := Trim(StationCommandValue(readFrom, f.Command));
         (* A zone that has never been set reads "0": a number, but one that
           means "nothing yet", and a new operator would read it as an answer.
           Shown BLANK.  f.Loaded keeps the real value, so the comparison at
           commit is unchanged, and a derived field that is blank is still
           derived from the callsign. *)
         if f.Derivable and (f.Loaded = '0') then
            begin
            f.Edit.Text := '';
            end
         else
            begin
            f.Edit.Text := LclText(f.Loaded);
            end;
         end;

      FContinentLoaded := UpperCase(Trim(StationCommandValue(readFrom, 'MY CONTINENT')));
      cbxContinent.ItemIndex := cbxContinent.Items.IndexOf(LclText(FContinentLoaded));

      (* A DERIVED FIELD IS THE OPERATOR'S ONLY IF IT SAYS SOMETHING THE
        CALLSIGN DOES NOT: empty, or equal to what the country file gives
        for the loaded callsign, is still derived and will follow the
        callsign.  Anything else was stated before, and stays. *)
      call := FFields[0].Loaded;
      for f in FFields do
         begin
         f.OperatorOwned := f.Derivable                                  and
                            (f.Loaded <> '')                             and
                            (f.Loaded <> '0')                            and
                            (f.Loaded <> DerivedValue(f.Command, call));
         end;
      FContinentOwned := (FContinentLoaded <> '')                                and
                         (FContinentLoaded <> 'NONE')                            and
                         (FContinentLoaded <> DerivedValue('MY CONTINENT', call));
   finally
      FFilling := False;
      keyers.Free;
      store.Free;
   end;

   RunLookup;
end;

(* What the country file says for aCall, in the spelling the command takes;
  '' when it does not know the call. *)
function TfrmSetupWizard.DerivedValue(const aCommand, aCall: string): string;
begin
   Result := '';
   (* NO TABLE, NO QUESTION: with no country file loaded ctyFindCallsign throws
     (and logs) on every call it is asked.  Seen 2026-11-14 on a first run from
     an empty directory -- the wizard asked before any file had been found. *)
   if (Length(aCall) < 3) or (ctyGetTotalCountries = 0) or
      (ctyGetCountryID(aCall) = '') then
      begin
      Exit;
      end;

   if aCommand = 'MY ZONE' then
      begin
      Result := IntToStr(ctyGetZone(aCall));
      end
   else if aCommand = 'MY ITU ZONE' then
      begin
      Result := IntToStr(ctyGetITUZone(aCall));
      end
   else if aCommand = 'MY COUNTRY' then
      begin
      Result := ctyGetCountryID(aCall);
      end
   else if aCommand = 'MY CONTINENT' then
      begin
      Result := ContinentTypeSA[ctyGetContinent(aCall)];
      end;
end;

(* FILL IN WHAT THE CALLSIGN DECIDES -- debounced by tmrLookup, so a half-
  typed call does not flicker through the wrong country.  A field the
  operator has made theirs is never touched; a call the country file does
  not know changes nothing and blocks nothing (design section 4). *)
procedure TfrmSetupWizard.RunLookup;
var
   call: string;
   f: TWizStationField;
   v: string;
begin
   call := Trim(edtCall.Text);
   lblLookup.Caption := '';
   if Length(call) < 3 then
      begin
      Exit;
      end;

   (* NO FILE IS NOT "UNKNOWN CALL": the country-file line beside it already
     says there is none. *)
   if ctyGetTotalCountries = 0 then
      begin
      Exit;
      end;

   if ctyGetCountryID(call) = '' then
      begin
      lblLookup.Caption := SWizNoCountry;
      Exit;
      end;

   FFilling := True;
   try
      for f in FFields do
         begin
         if f.Derivable and (not f.OperatorOwned) then
            begin
            v := DerivedValue(f.Command, call);
            if v <> '' then
               begin
               f.Edit.Text := LclText(v);
               end;
            end;
         end;
      if not FContinentOwned then
         begin
         v := DerivedValue('MY CONTINENT', call);
         if v <> '' then
            begin
            cbxContinent.ItemIndex := cbxContinent.Items.IndexOf(LclText(v));
            end;
         end;
   finally
      FFilling := False;
   end;
end;

procedure TfrmSetupWizard.edtCallChange(Sender: TObject);
begin
   if FFilling then
      begin
      Exit;
      end;
   (* Restart the wait: the lookup runs once typing pauses. *)
   tmrLookup.Enabled := False;
   tmrLookup.Enabled := True;
end;

procedure TfrmSetupWizard.tmrLookupTimer(Sender: TObject);
begin
   tmrLookup.Enabled := False;
   RunLookup;
   StartCallbookLookup;
end;

(* ASK THE CALLBOOK ONCE the callsign has settled -- the debounce above -- and
  only while there is something it could fill.  Only the callsign leaves the
  machine.  A reply that is late, empty or never comes changes nothing. *)
procedure TfrmSetupWizard.StartCallbookLookup;
var
   call: string;
begin
   call := Trim(edtCall.Text);
   if (Length(call) < 3) or (not IsAGoodCall(call)) or (call = FCallbookCall) then
      begin
      Exit;
      end;
   if (Trim(edtName.Text) <> '') and (Trim(edtGrid.Text) <> '') and
      (Trim(edtState.Text) <> '') and (Trim(edtPostal.Text) <> '') then
      begin
      Exit;
      end;

   FCallbookCall := call;
   LookupCallsignAsync(call, TCallbookRelay.Deliver);
end;

(* "THOMAS" -> "Thomas": a callbook holds names in capitals. *)
function TitleCaseName(const aName: string): string;
begin
   Result := Trim(aName);
   if Result <> '' then
      begin
      Result := UpperCase(Copy(Result, 1, 1)) + LowerCase(Copy(Result, 2, MaxInt));
      end;
end;

procedure TfrmSetupWizard.ApplyCallbook(const aRec: TCallbookRecord);
var
   filled: boolean;
begin
   (* STALE: the operator has typed a different call since the question. *)
   if (not aRec.Found) or (not UnicodeSameText(aRec.Call, Trim(edtCall.Text))) then
      begin
      Exit;
      end;

   (* NOT ON THE STATION PAGE ANY MORE (review M15): a reply can arrive many
     seconds after the question, and filling boxes the operator has left would
     have CommitStation save four values nobody saw -- not "offered as
     defaults". Forgotten, so the next settled callsign is asked about even
     when it is this same one. *)
   if (FPlan = nil) or (FPlan[FIndex] <> spStation) then
      begin
      FCallbookCall := '';
      Exit;
      end;

   filled := False;
   FFilling := True;
   try
      if (Trim(edtName.Text) = '') and (aRec.FirstName <> '') then
         begin
         edtName.Text := LclText(TitleCaseName(aRec.FirstName));
         filled := True;
         end;
      if (Trim(edtGrid.Text) = '') and (aRec.Grid <> '') then
         begin
         edtGrid.Text := LclText(NormalizeGridSquare(aRec.Grid));
         filled := True;
         end;
      if (Trim(edtState.Text) = '') and (aRec.State <> '') then
         begin
         edtState.Text := LclText(UpperCase(aRec.State));
         filled := True;
         end;
      if (Trim(edtPostal.Text) = '') and (aRec.Zip <> '') then
         begin
         edtPostal.Text := LclText(UpperCase(aRec.Zip));
         filled := True;
         end;
   finally
      FFilling := False;
   end;

   if filled then
      begin
      lblLookup.Caption := LclText(lblLookup.Caption + sLineBreak + SWizCallbookFilled);
      end;
end;

(* THE OPERATOR TYPED IN A DERIVED FIELD: from now on it is theirs, and a
  later callsign change does not take it back. *)
procedure TfrmSetupWizard.DerivedFieldChange(Sender: TObject);
var
   f: TWizStationField;
begin
   if FFilling then
      begin
      Exit;
      end;
   if Sender = cbxContinent then
      begin
      FContinentOwned := True;
      Exit;
      end;
   f := FieldForEdit(Sender);
   if f <> nil then
      begin
      f.OperatorOwned := True;
      end;
end;

(* THE LOCATOR IN ITS STANDARD CASE when the operator leaves the box: EL88pa,
  not EL88PA.  The box takes what is typed, so a four-character locator and a
  six-character one are both written the way the standard writes them. *)
procedure TfrmSetupWizard.GridExit(Sender: TObject);
begin
   edtGrid.Text := LclText(NormalizeGridSquare(edtGrid.Text));
end;

(* ONE SERVER, TWO BOXES.  A cluster picked from the list, or a host:port
  pasted into the server box, is split so the host and the port each sit in
  their own box; the store keeps the one 'host:port' spelling. *)
procedure TfrmSetupWizard.ServerExit(Sender: TObject);
var
   host, port: string;
begin
   SplitClusterServer(cbxServer.Text, host, port);
   cbxServer.Text := LclText(host);
   if port <> '' then
      begin
      edtPort.Text := LclText(port);
      end;
end;

(* SPLIT AFTER THE SELECTION HAS FINISHED.  Writing the combo's Text from inside
  its own OnSelect left the Server box empty with no item selected (seen at
  1280x800, 2026-11-15): the widget sets its text from the chosen item after the
  event returns.  Queued, the split runs once it is done. *)
procedure TfrmSetupWizard.ServerSelect(Sender: TObject);
begin
   Application.QueueAsyncCall(SplitPickedServer, 0);
end;

procedure TfrmSetupWizard.SplitPickedServer(aData: PtrInt);
begin
   (* A list entry replaces the port, which belongs to the cluster picked. *)
   edtPort.Text := '';
   ServerExit(nil);
end;

function TfrmSetupWizard.ClusterServerText: string;
var
   host, port: string;
begin
   SplitClusterServer(cbxServer.Text, host, port);
   if Trim(edtPort.Text) <> '' then
      begin
      port := Trim(edtPort.Text);
      end;
   Result := JoinClusterServer(host, port);
end;

function TfrmSetupWizard.TickedItems: TSetupItems;
begin
   Result := [];
   if chkRadio.Checked then
      begin
      Include(Result, siRadio);
      end;
   if chkKeyer.Checked then
      begin
      Include(Result, siKeyer);
      end;
   if chkCluster.Checked then
      begin
      Include(Result, siCluster);
      end;
   if chkLogger.Checked then
      begin
      Include(Result, siLogger);
      end;
   if chkRotator.Checked then
      begin
      Include(Result, siRotator);
      end;
   if chkWSJTX.Checked then
      begin
      Include(Result, siWSJTX);
      end;
end;

(* THE CHECKLIST CHANGED: recompute the plan.  UNTICKING DESTROYS THE DRAFT
  (design 11.1) -- a hidden, half-made radio is how a later run would write
  something the operator took back. *)
procedure TfrmSetupWizard.ChecklistChange(Sender: TObject);
begin
   if FFilling then
      begin
      Exit;
      end;
   if not chkRadio.Checked then
      begin
      DropRadioEditor;
      FreeAndNil(FRadioDraft);
      end;
   if not chkKeyer.Checked then
      begin
      DropKeyerEditor;
      FreeAndNil(FKeyerDraft);
      end;
   if not chkCluster.Checked then
      begin
      cbxServer.Text      := '';
      edtPort.Text        := '';
      edtLogin.Text       := '';
      edtPassword.Text    := '';
      edtCommand.Text     := '';
      end;
   if not chkLogger.Checked then
      begin
      DropLoggerEditor;
      FreeAndNil(FLoggerDraft);
      end;
   if not chkRotator.Checked then
      begin
      ClearRotatorPage;
      end;
   if not chkWSJTX.Checked then
      begin
      (* Unticked means "leave WSJT-X as it is": back to what is stored. *)
      LoadWSJTX;
      end
   else if Sender = chkWSJTX then
      begin
      (* TICKING THE ITEM SAYS "I USE WSJT-X" (NY4I, 2026-11-25): the page
        opens with the switch ON, whatever is stored -- every WSJT-X option is
        off by default now, so following the stored value would make the
        operator tick twice. Only the switch: highlights, radio control, the
        port and the group stay as stored. It is written only if it differs
        from what was stored (SetupWsjtxChanges), and unticking puts the
        stored value back (LoadWSJTX, above). Asked only when the WSJT-X box
        itself changed, so ticking another item later leaves the operator's
        own choice on the WSJT-X page alone. *)
      chkWSJTXEnable.Checked := True;
      ShowWSJTXSwitch;
      end;
   FPlan := SetupPagePlan(TickedItems);
   UpdateButtons;
end;

function TfrmSetupWizard.SheetFor(const aPage: TSetupPage): TTabSheet;
begin
   case aPage of
      spStation:
         begin
         Result := tsStation;
         end;
      spChecklist:
         begin
         Result := tsChecklist;
         end;
      spRadio:
         begin
         Result := tsRadio;
         end;
      spKeyer:
         begin
         Result := tsKeyer;
         end;
      spCluster:
         begin
         Result := tsCluster;
         end;
      spLogger:
         begin
         Result := tsLogger;
         end;
      spRotator:
         begin
         Result := tsRotator;
         end;
      spWSJTX:
         begin
         Result := tsWSJTX;
         end;
   else
      begin
      Result := tsResult;
      end;
   end;
end;

procedure TfrmSetupWizard.ShowCurrentPage;
var
   page: TSetupPage;
   heading, intro: AnsiString;
begin
   page := FPlan[FIndex];
   heading := '';
   intro := '';
   case page of
      spStation:
         begin
         heading := SWizStationHeading;
         intro   := SWizStationIntro;
         end;
      spChecklist:
         begin
         heading := SWizChecklistHeading;
         intro   := SWizChecklistIntro;
         end;
      spRadio:
         begin
         heading := SWizRadioHeading;
         intro   := SWizRadioIntro;
         end;
      spKeyer:
         begin
         heading := SWizKeyerHeading;
         intro   := SWizKeyerIntro;
         end;
      spCluster:
         begin
         heading := SWizClusterHeading;
         intro   := SWizClusterIntro;
         (* THE PUBLIC DIRECTORY, read when the page is first reached -- the
           Preferences picker's rule and its reader. *)
         if not FClusterListLoaded then
            begin
            FClusterListLoaded := True;
            LoadClusterDirectory(cbxServer.Items);
            end;
         (* Blank logs in as MY CALL; the hint says which call that is.  The
           box is upper case already (CharCase). *)
         edtLogin.TextHint := edtCall.Text;
         end;
      spLogger:
         begin
         heading := SWizLoggerHeading;
         intro   := SWizLoggerIntro;
         end;
      spRotator:
         begin
         heading := SWizRotatorHeading;
         intro   := SWizRotatorIntro;
         LoadRotatorLists;
         end;
      spWSJTX:
         begin
         heading := SWizWSJTXHeading;
         intro   := SWizWSJTXIntro;
         end;
      spResult:
         begin
         heading := SWizResultHeading;
         intro   := SWizResultIntro;
         end;
   end;

   lblHeading.Caption := heading;
   lblIntro.Caption   := intro;
   ShowEditorPage(page);
   pgPages.ActivePage := SheetFor(page);
   (* THE LOGGER EDITOR AGAIN, NOW ITS SHEET IS THE ONE SHOWING: a word-wrapped
     label reports its wrapped height only once its parent has a window, so
     the layout made before the sheet was active took the editor's long note
     for one line. *)
   if (page = spLogger) and (FLoggerEditor <> nil) then
      begin
      FLoggerEditor.FitLayout;
      LoggerLayoutChanged(FLoggerEditor);
      end;
   UpdateButtons;
end;

procedure TfrmSetupWizard.UpdateButtons;
var
   page: TSetupPage;
begin
   (* An unticked page that was showing is gone from the plan; the index is
     only ever moved by Back and Next, and the checklist page itself is never
     removed, so it stays in range. *)
   if FIndex > High(FPlan) then
      begin
      FIndex := High(FPlan);
      end;
   page := FPlan[FIndex];

   lblStep.Caption := Format(SWizStepOf, [FIndex + 1, Length(FPlan)]);

   if page = spResult then
      begin
      btnBack.Visible   := False;
      btnNext.Visible   := False;
      btnCancel.Caption := SWizClose;
      Exit;
      end;

   btnBack.Enabled := (FIndex > 0) and (not FDownloading);
   btnNext.Enabled := not FDownloading;
   btnCancel.Enabled := not FDownloading;
   if IsCommitPage(FPlan, FIndex) then
      begin
      btnNext.Caption := SWizCreate;
      end
   else
      begin
      btnNext.Caption := SWizNext;
      end;
end;

(* THE RADIO AND WINKEYER PAGES ARE THE EXISTING EDITORS, hosted in this
  window (NY4I, 2026-11-14: a wizard steps you through things in ONE window --
  the editor used to open as a second one, behind the wizard on the desktop).

  An editor is made when its page is first reached and kept while the item stays
  ticked, so Back and Next keep what was typed.  The window grows to fit a hosted
  editor and returns to its designed size on every other page.  What the editor
  holds becomes the draft only when Next is pressed on its page
  (AcceptEditorPage), which is also where its own validation speaks. *)
procedure TfrmSetupWizard.ShowEditorPage(const aPage: TSetupPage);
var
   hosted, hostedWidth: integer;
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   loadErr: string;
begin
   hosted := 0;
   hostedWidth := 0;
   case aPage of
      spChecklist:
         begin
         hosted := ChecklistHeight;
         end;
      spRadio:
         begin
         if FRadioEditor = nil then
            begin
            FRadioEditor := TRadioEditForm.Create(Self);
            FRadioEditing := TRadioDefinition.Create;
            FRadioEditing.Name := SDefaultRadioName;
            FRadioEditor.OnTypeChanged := RadioTypeChanged;
            FRadioEditor.EditRadioIn(FRadioEditing, tsRadio);
            end;
         UpdateCWChoices;
         hosted := FRadioEditor.pnlContent.Height;
         (* As wide as its captions made it (TRadioEditForm.FitLayout). *)
         hostedWidth := FRadioEditor.pnlContent.Width;
         if chkCWByCAT.Visible or chkSpeedSync.Visible then
            begin
            hosted := hosted + CW_ROW_HEIGHT;
            end;
         end;
      spKeyer:
         begin
         if FKeyerEditor = nil then
            begin
            FKeyerEditor := TfrmKeyerEdit.Create(Self);
            FKeyerEditing := TKeyerDefinition.Create;   // a WinKeyer, no port yet
            FKeyerEditing.Name := SDefaultKeyerName;
            FKeyerEditor.EditKeyerIn(FKeyerEditing, tsKeyer);
            end;
         hosted := FKeyerEditor.pnlContent.Height;
         hostedWidth := FKeyerEditor.pnlContent.Width;
         end;
      spLogger:
         begin
         if FLoggerEditor = nil then
            begin
            (* THE DEFINITIONS AS STORED, SEEDED THE WAY STARTUP SEEDS THEM, so
              the editor's own checks (a unique name, two loggers sending to
              one destination) see exactly what Create will save.  A library
              that cannot be read leaves the copy empty; Create then says so
              and writes nothing over it. *)
            store  := TRadioConfigStore.Create;
            keyers := TKeyerConfigStore.Create;
            try
               if FileExists(RadioStoreFileName) then
                  begin
                  LoadConfig(RadioStoreFileName, store, keyers, loadErr);
                  end;
               if store.ExternalLoggers.Error = '' then
                  begin
                  SeedExternalLoggers(store.ExternalLoggers, Settings.ExternalLogger);
                  end;
               FLoggerEditor := TExternalLoggersForm.Create(Self);
               FLoggerEditor.OnLayoutChanged := LoggerLayoutChanged;
               (* SWITCHED ON: ticking the item was the choice to send.  The
                 editor's own checks then ask for what sending needs. *)
               FLoggerEditor.EditLoggerIn(store.ExternalLoggers, tsLogger, True);
            finally
               keyers.Free;
               store.Free;
            end;
            end;
         FLoggerEditor.FitLayout;
         hosted := FLoggerEditor.pnlContent.Height;
         hostedWidth := FLoggerEditor.pnlContent.Width;
         end;
   end;

   FitWindowTo(hosted, hostedWidth);
end;

(* The hosted logger editor rebuilt its rows (a provider change) or showed
  its certificate note: the window follows the panel's new size. *)
procedure TfrmSetupWizard.LoggerLayoutChanged(Sender: TObject);
begin
   if (FPlan <> nil) and (FPlan[FIndex] = spLogger) and (FLoggerEditor <> nil) then
      begin
      FitWindowTo(FLoggerEditor.pnlContent.Height, FLoggerEditor.pnlContent.Width);
      end;
end;

procedure TfrmSetupWizard.DropLoggerEditor;
begin
   (* Its definitions are its own copy, freed with it. *)
   FreeAndNil(FLoggerEditor);
end;

(* CW BY CAT AND SPEED SYNC, offered only for a radio that can do them -- the
  same two questions Preferences > Hardware asks (SupportsForId, by registry
  id, so a radio with no enum member such as TCI is answered too).  They sit
  in a row under the hosted editor.  A WinKeyer ticked on the checklist makes
  CW by CAT moot -- a slot has one CW output and the keyer wins -- so the box
  is disabled while that is ticked. *)
procedure TfrmSetupWizard.UpdateCWChoices;
var
   id: string;
   canCAT, canSync: boolean;
begin
   id := '';
   if FRadioEditor <> nil then
      begin
      id := FRadioEditor.SelectedRegistryId;
      end;
   canCAT  := (id <> '') and SupportsForId(id, rcCWByCAT);
   canSync := (id <> '') and SupportsForId(id, rcCWSpeedSync);

   if not canCAT then
      begin
      chkCWByCAT.Checked := False;
      end;
   if not canSync then
      begin
      chkSpeedSync.Checked := False;
      end;
   chkCWByCAT.Visible   := canCAT;
   chkSpeedSync.Visible := canSync;
   chkCWByCAT.Enabled   := not chkKeyer.Checked;

   if FRadioEditor <> nil then
      begin
      (* chkSpeedSync is anchored to chkCWByCAT, so it follows. *)
      chkCWByCAT.Top := FRadioEditor.pnlContent.Top + FRadioEditor.pnlContent.Height + 4;
      end;
end;

(* The radio type was changed in the hosted editor: the choices and the window
  height follow it. *)
procedure TfrmSetupWizard.RadioTypeChanged(Sender: TObject);
begin
   if (FPlan <> nil) and (FPlan[FIndex] = spRadio) then
      begin
      ShowEditorPage(spRadio);
      end;
end;

(* EVERY PAGE'S LABEL COLUMN AS WIDE AS ITS WIDEST CAPTION, and how much
  wider than designed the window must be for the widest page.

  The columns were typed for English (120-140 px) and a translation was cut
  off -- German on gtk2 showed "Hafer" for the cluster's Port and "Nach dem
  Verbind..." for After connecting. uLCLFormHelpers.FitCaptionColumn widens a
  column to its widest caption and moves the inputs (and the Station page's
  right-hand notes) by the same amount; the cluster's Port caption is a
  column of its own, after the server box. The notes that wrap are anchored
  in the .lfm (left and right, rows hanging from the one above), so they
  follow without code.

  The answer is what the widest page's right edge, plus the designed 16 px
  margin, needs beyond the page as designed -- 0 in English, so the window
  keeps its designed width there. The caller caps it at the work area. Once,
  from the constructor: the language does not change while the wizard lives. *)
function TfrmSetupWizard.FitPageColumns: integer;
const
   PAGE_MARGIN = 16;
   PAGE_FRAME  = 8;
var
   sheets: array[0..4] of TTabSheet;
   i:      integer;
   want:   integer;
begin
   FitCaptionColumn([lblCall, lblName, lblGrid, lblState, lblSection, lblPostal,
                     lblZone, lblITUZone, lblCountry, lblContinent],
                    [edtCall, edtName, edtGrid, edtState, edtSection, edtPostal,
                     edtZone, edtITUZone, edtCountry, cbxContinent,
                     lblLookup, lblCtyStatus, btnCtyDownload, lblDerived]);

   FitCaptionColumn([lblServer, lblLogin, lblPassword, lblCommand],
                    [cbxServer, lblPort, edtPort, edtLogin, edtPassword, edtCommand]);
   FitCaptionColumn([lblPort], [edtPort]);

   FitCaptionColumn([lblRotatorType, lblRotatorPort, lblRotatorIP, lblRotatorUDP],
                    [cbxRotatorType, cbxRotatorPort, edtRotatorIP, edtRotatorUDP]);

   FitCaptionColumn([lblWSJTXPort, lblWSJTXMulticast],
                    [edtWSJTXPort, edtWSJTXMulticast]);

   sheets[0] := tsStation;
   sheets[1] := tsChecklist;
   sheets[2] := tsCluster;
   sheets[3] := tsRotator;
   sheets[4] := tsWSJTX;

   Result := 0;
   for i := Low(sheets) to High(sheets) do
      begin
      want := ChildrenRightEdge(sheets[i]) + Scale96ToForm(PAGE_MARGIN)
              - (ClientWidth - Scale96ToForm(PAGE_FRAME));
      if want > Result then
         begin
         Result := want;
         end;
      end;
end;

(* HOW TALL THE CHECKLIST PAGE'S CONTENT IS, its notes wrapped. Each note
  hangs under its box and the next box under the note (the .lfm), so a note
  that wraps to more lines pushes the rest down -- past the designed page in a
  long language. Measured (WrappedTextHeight) at the width the notes get: the
  page less their 40 px indent and 16 px right margin. English is 287 px plus
  the page's own frame, inside the designed window, so nothing changes there. *)
function TfrmSetupWizard.ChecklistHeight: integer;
const
   FIRST_TOP   = 8;    (* the first box's top *)
   NOTE_GAP    = 1;    (* box to its note *)
   ITEM_GAP    = 9;    (* note to the next box *)
   NOTE_INDENT = 40;
   NOTE_RIGHT  = 16;
   PAGE_FRAME  = 8;
   PAGE_AIR    = 20;   (* the page control's frame and the air under the last note *)
var
   boxes: array[0..5] of TCheckBox;
   notes: array[0..5] of TLabel;
   i, noteWidth: integer;
begin
   boxes[0] := chkRadio;
   boxes[1] := chkKeyer;
   boxes[2] := chkCluster;
   boxes[3] := chkLogger;
   boxes[4] := chkRotator;
   boxes[5] := chkWSJTX;
   notes[0] := lblRadioHint;
   notes[1] := lblKeyerHint;
   notes[2] := lblClusterHint;
   notes[3] := lblLoggerHint;
   notes[4] := lblRotatorHint;
   notes[5] := lblWSJTXHint;

   noteWidth := FBaseClientWidth
                - Scale96ToForm(PAGE_FRAME + NOTE_INDENT + NOTE_RIGHT);
   Result := Scale96ToForm(FIRST_TOP + PAGE_AIR);
   for i := Low(boxes) to High(boxes) do
      begin
      if i > Low(boxes) then
         begin
         Result := Result + Scale96ToForm(ITEM_GAP);
         end;
      Result := Result + boxes[i].Height + Scale96ToForm(NOTE_GAP)
                + WrappedTextHeight(notes[i].Font, notes[i].Caption, noteWidth);
      end;
end;

(* Size the window to the header, the hosted editor (and anything under it),
  the buttons and a little air. *)
procedure TfrmSetupWizard.FitWindowTo(const aHosted: integer; const aHostedWidth: integer);
const
   SLACK = 8;
   INTRO_RIGHT  = 16;   (* the designed margin right of the description *)
   INTRO_BOTTOM = 4;    (* and under it *)
var
   needed, neededWidth, header: integer;
   work, outer: TRect;
begin
   (* WIDER ONLY FOR AN EDITOR THAT IS: the external logger and radio editors
     lay out from measurement and can be wider than the designed window.  The
     page control's frame is SLACK.  FBaseClientWidth already holds what the
     widest fitted page needs (FitPageColumns). *)
   neededWidth := aHostedWidth + SLACK;
   if neededWidth < FBaseClientWidth then
      begin
      neededWidth := FBaseClientWidth;
      end;
   ClientWidth := neededWidth;

   (* THE DESCRIPTION UNDER THE TITLE IS AS TALL AS IT WRAPS, at the width it
     will have (it is anchored left and right, so the width just set).  It was
     a fixed two lines, and a translation was cut off mid-sentence on every
     page.  Measured, not asked of the label: before the window is shown a
     word-wrapped label reports no wrapped height.  Never below the designed
     header, so English is unchanged. *)
   header := lblIntro.Top
             + WrappedTextHeight(lblIntro.Font, lblIntro.Caption,
                                 ClientWidth - lblIntro.Left - Scale96ToForm(INTRO_RIGHT))
             + Scale96ToForm(INTRO_BOTTOM);
   if header < FBaseHeaderHeight then
      begin
      header := FBaseHeaderHeight;
      end;
   pnlHeader.Height := header;

   (* The designed page area under a taller header: the window grows by what
     the header grew, so no page loses its bottom rows. *)
   needed := pnlHeader.Height + aHosted + pnlButtons.Height + SLACK;
   if needed < FBaseClientHeight + (pnlHeader.Height - FBaseHeaderHeight) then
      begin
      needed := FBaseClientHeight + (pnlHeader.Height - FBaseHeaderHeight);
      end;
   ClientHeight := needed;

   (* GROWN DOWNWARDS, so a window placed for its normal height ends with its
     Back and Next under the taskbar (seen at 1280x800, 2026-11-14).  Pull it
     up until its bottom is inside the work area, but never above the top. *)
   work := Monitor.WorkareaRect;
   (* THE WINDOW'S OUTER RECTANGLE, title bar and frame included: Top + Height
     leaves out ~30 px of decoration, which is exactly how far Back and Next
     stayed under the taskbar (measured 2026-11-15).  Not available before the
     window has a handle, and the designed size always fits. *)
   if HandleAllocated then
      begin
      LCLIntf.GetWindowRect(Handle, outer);
      if outer.Bottom > work.Bottom then
         begin
         Top := Top - (outer.Bottom - work.Bottom);
         end;
      end
   else if Top + Height > work.Bottom then
      begin
      Top := work.Bottom - Height;
      end;
   if Top < work.Top then
      begin
      Top := work.Top;
      end;
   (* Grown to the right, so pulled back in the same way. *)
   if Left + Width > work.Right then
      begin
      Left := work.Right - Width;
      end;
   if Left < work.Left then
      begin
      Left := work.Left;
      end;
end;

{ ------------------------------------------------------------- rotator ---- }

(* THE ROTATOR PAGE'S LISTS, as Preferences' Rotators page fills them: the
  types from the registry with the id in each row, and the ports that exist.
  Once, when the page is first reached -- enumerating ports is not free. *)
procedure TfrmSetupWizard.LoadRotatorLists;
var
   enumerator: TComPortEnumerator;
begin
   if FRotatorListsLoaded then
      begin
      Exit;
      end;
   FRotatorListsLoaded := True;
   FillRotatorTypeCombo(cbxRotatorType);
   enumerator := TComPortEnumerator.Create;
   try
      enumerator.Refresh;
      FillSerialPortCombo(cbxRotatorPort, enumerator);
   finally
      enumerator.Free;
   end;
   ShowRotatorTransport;
end;

(* Whether the chosen type is on a serial port; no type yet reads as serial. *)
function TfrmSetupWizard.RotatorIsSerial: boolean;
var
   baud: integer;
   id: string;
begin
   id := '';
   if cbxRotatorType.ItemIndex >= 0 then
      begin
      id := SelectedTag(cbxRotatorType);
      end;
   Result := RotatorUsesSerialPort(id, baud);
end;

(* SERIAL OR NETWORK IS THE DRIVER'S ANSWER (RotatorUsesSerialPort), the rule
  Preferences follows: the port for a serial rotator, the address and UDP port
  for one that is not.  A network rotator left blank uses the program's
  defaults, shown greyed in the boxes. *)
procedure TfrmSetupWizard.ShowRotatorTransport;
var
   serial: boolean;
begin
   serial := RotatorIsSerial;
   cbxRotatorPort.Enabled := serial;
   lblRotatorPort.Enabled := serial;
   edtRotatorIP.Enabled   := not serial;
   lblRotatorIP.Enabled   := not serial;
   edtRotatorUDP.Enabled  := not serial;
   lblRotatorUDP.Enabled  := not serial;
   edtRotatorIP.TextHint  := LclText(string(Settings.Rotator.IpAddress));
   edtRotatorUDP.TextHint := LclText(IntToStr(Settings.Rotator.UdpPort));
end;

procedure TfrmSetupWizard.RotatorTypeChange(Sender: TObject);
begin
   ShowRotatorTransport;
end;

(* UNTICKED: nothing chosen is kept, so a re-ticked rotator starts blank. *)
procedure TfrmSetupWizard.ClearRotatorPage;
begin
   cbxRotatorType.ItemIndex := -1;
   cbxRotatorPort.ItemIndex := -1;
   edtRotatorIP.Text  := '';
   edtRotatorUDP.Text := '';
   if FRotatorListsLoaded then
      begin
      ShowRotatorTransport;
      end;
end;

(* WHAT THE PAGE SAYS, as a definition the store can take: the type's id, and
  either its port or its address.  No name (StageSetupRotator gives it one),
  no baud rate (the driver's own), no bands (every band).  The caller owns
  it. *)
function TfrmSetupWizard.RotatorDraft: TRotatorDefinition;
var
   udp: Longint;
   code: integer;
begin
   Result := TRotatorDefinition.Create;
   if cbxRotatorType.ItemIndex >= 0 then
      begin
      Result.RotatorId := SelectedTag(cbxRotatorType);
      end;
   Result.ControlPort := PORT_NONE;
   if RotatorIsSerial then
      begin
      if cbxRotatorPort.ItemIndex >= 0 then
         begin
         Result.ControlPort := SelectedTag(cbxRotatorPort);
         end;
      end
   else
      begin
      Result.IPAddress := Trim(edtRotatorIP.Text);
      udp := 0;
      code := 0;
      if Trim(edtRotatorUDP.Text) <> '' then
         begin
         ValChecked(Trim(edtRotatorUDP.Text), udp, code);
         end;
      if code = 0 then
         begin
         Result.UDPPort := udp;
         end;
      end;
end;

{ -------------------------------------------------------------- WSJT-X ---- }

(* THE COMMANDS, NAMED ONCE for the load and the commit.  The settings object
  owns all five (uSettingsModel's aliases); Preferences' WSJT-X page reads
  and writes the same names. *)
const
   WSJTX_CMD_ENABLED       = 'WSJT-X ENABLED';
   WSJTX_CMD_RADIO_CONTROL = 'WSJT-X RADIO CONTROL ENABLED';
   WSJTX_CMD_HIGHLIGHTS    = 'WSJT-X SEND HIGHLIGHTS';
   WSJTX_CMD_PORT          = 'WSJT-X BROADCAST PORT';
   WSJTX_CMD_MULTICAST     = 'WSJT-X MULTICAST GROUP';

(* EVERY FIELD'S TOOLTIP, the radio editor's pattern (uRadioEditForm).  HERE,
  below the WSJT-X command names, so the table can use them.

  A FIELD THAT EDITS WHAT ANOTHER WINDOW EDITS WEARS THAT WINDOW'S HELP, so
  the text is written once: the station boxes are the Station page's commands
  (the same names AddField gives them), the CW choices are slot one's (the
  wizard's radio goes into Radio 1 -- StageSetupItems), the cluster, rotator
  and WSJT-X fields are Preferences'.  Only the checklist, the result page's
  details box and the split cluster port are the wizard's own.  The hosted
  radio, keyer and logger editors bring their own tooltips. *)
procedure TfrmSetupWizard.ApplyFieldHelp;
var
   help: TCommandHelp;

   (* ONE ROW OF THE TABLE: the field, its caption (nil for a check box, whose
     caption is its own) and the help name.  Both get the same tooltip. *)
   procedure HintFromHelp(const aControl, aCaption: TControl; const aCommand: string);
   begin
      ApplyCommandHelpHint(aControl, help, aCommand);
      ApplyCommandHelpHint(aCaption, help, aCommand);
   end;

begin
   help := TCommandHelp.Create(HelpDir, ActiveUILanguage);
   try
      // Station
      HintFromHelp(edtCall,              lblCall,           'MY CALL');
      HintFromHelp(edtName,              lblName,           'MY NAME');
      HintFromHelp(edtGrid,              lblGrid,           'MY GRID');
      HintFromHelp(edtState,             lblState,          'MY STATE');
      HintFromHelp(edtSection,           lblSection,        'MY SECTION');
      HintFromHelp(edtPostal,            lblPostal,         'MY POSTAL CODE');
      HintFromHelp(edtZone,              lblZone,           'MY ZONE');
      HintFromHelp(edtITUZone,           lblITUZone,        'MY ITU ZONE');
      HintFromHelp(edtCountry,           lblCountry,        'MY COUNTRY');
      HintFromHelp(cbxContinent,         lblContinent,      'MY CONTINENT');

      // What to set up
      HintFromHelp(chkRadio,             nil,               'SETUP WIZARD RADIO');
      HintFromHelp(chkKeyer,             nil,               'SETUP WIZARD KEYER');
      HintFromHelp(chkCluster,           nil,               'SETUP WIZARD CLUSTER');
      HintFromHelp(chkLogger,            nil,               'SETUP WIZARD LOGGER');
      HintFromHelp(chkRotator,           nil,               'SETUP WIZARD ROTATOR');
      HintFromHelp(chkWSJTX,             nil,               'SETUP WIZARD WSJT-X');

      // Radio page, under the hosted editor
      HintFromHelp(chkCWByCAT,           nil,               'RADIO ONE CW BY CAT');
      HintFromHelp(chkSpeedSync,         nil,               'RADIO ONE CW SPEED SYNC');

      // DX cluster
      HintFromHelp(cbxServer,            lblServer,         'TELNET SERVER');
      HintFromHelp(edtPort,              lblPort,           'SETUP WIZARD CLUSTER PORT');
      HintFromHelp(edtLogin,             lblLogin,          'PREFERENCES CLUSTER LOGIN');
      HintFromHelp(edtPassword,          lblPassword,       'PREFERENCES CLUSTER PASSWORD');
      HintFromHelp(edtCommand,           lblCommand,        'CONNECTION COMMAND');

      // Rotator
      HintFromHelp(cbxRotatorType,       lblRotatorType,    'PREFERENCES ROTATOR TYPE');
      HintFromHelp(cbxRotatorPort,       lblRotatorPort,    'PREFERENCES ROTATOR PORT');
      HintFromHelp(edtRotatorIP,         lblRotatorIP,      'PREFERENCES ROTATOR IP ADDRESS');
      HintFromHelp(edtRotatorUDP,        lblRotatorUDP,     'PREFERENCES ROTATOR UDP PORT');

      // WSJT-X
      HintFromHelp(chkWSJTXEnable,       nil,               WSJTX_CMD_ENABLED);
      HintFromHelp(edtWSJTXPort,         lblWSJTXPort,      WSJTX_CMD_PORT);
      HintFromHelp(chkWSJTXHighlights,   nil,               WSJTX_CMD_HIGHLIGHTS);
      HintFromHelp(chkWSJTXRadioControl, nil,               WSJTX_CMD_RADIO_CONTROL);
      HintFromHelp(edtWSJTXMulticast,    lblWSJTXMulticast, WSJTX_CMD_MULTICAST);

      // Result page
      HintFromHelp(chkDetails,           nil,               'SETUP WIZARD SHOW DETAILS');
   finally
      help.Free;
   end;
end;

(* A boolean command's stored value as a boolean: BA's spelling, the one
  Preferences' CommandBool compares with. *)
function WSJTXCommandBool(const aCommand: string): boolean;
begin
   (* UnicodeSameText, not SameText: SysUtils' SameText takes the 8-bit
     string, and the call would be a narrowing the build counts. *)
   Result := UnicodeSameText(Trim(StationCommandValue(nil, aCommand)), string(BA[True]));
end;

(* WHAT THE WSJT-X SETTINGS HOLD NOW, through the same function the Station
  page uses (StationCommandValue).  On a new install that is the model's
  default: every option OFF (2026-11-25), port 2237, no multicast group.
  Ticking the checklist item then switches the page ON (ChecklistChange). *)
procedure TfrmSetupWizard.LoadWSJTX;
begin
   FWSJTXLoaded.Enabled        := WSJTXCommandBool(WSJTX_CMD_ENABLED);
   FWSJTXLoaded.RadioControl   := WSJTXCommandBool(WSJTX_CMD_RADIO_CONTROL);
   FWSJTXLoaded.Highlights     := WSJTXCommandBool(WSJTX_CMD_HIGHLIGHTS);
   FWSJTXLoaded.Port           := Trim(StationCommandValue(nil, WSJTX_CMD_PORT));
   FWSJTXLoaded.MulticastGroup := Trim(StationCommandValue(nil, WSJTX_CMD_MULTICAST));

   chkWSJTXEnable.Checked       := FWSJTXLoaded.Enabled;
   chkWSJTXRadioControl.Checked := FWSJTXLoaded.RadioControl;
   chkWSJTXHighlights.Checked   := FWSJTXLoaded.Highlights;
   edtWSJTXPort.Text            := LclText(FWSJTXLoaded.Port);
   edtWSJTXMulticast.Text       := LclText(FWSJTXLoaded.MulticastGroup);
   (* Checked raises OnChange only when the value moves, so the greying is
     stated here as well. *)
   ShowWSJTXSwitch;
end;

(* SWITCHED OFF, THE REST OF THE PAGE IS GREYED: nothing below the switch is
  written while it is off (SetupWsjtxChanges), and a box that is not written
  must not look editable. *)
procedure TfrmSetupWizard.ShowWSJTXSwitch;
var
   switchedOn: boolean;
begin
   switchedOn := chkWSJTXEnable.Checked;
   edtWSJTXPort.Enabled             := switchedOn;
   lblWSJTXPort.Enabled             := switchedOn;
   chkWSJTXHighlights.Enabled       := switchedOn;
   lblWSJTXHighlightsHint.Enabled   := switchedOn;
   chkWSJTXRadioControl.Enabled     := switchedOn;
   lblWSJTXRadioControlHint.Enabled := switchedOn;
   edtWSJTXMulticast.Enabled        := switchedOn;
   lblWSJTXMulticast.Enabled        := switchedOn;
   lblWSJTXMulticastHint.Enabled    := switchedOn;
end;

procedure TfrmSetupWizard.WSJTXEnableChange(Sender: TObject);
begin
   ShowWSJTXSwitch;
end;

(* WHAT THE PAGE SHOWS NOW, trimmed as it would be written.  The caller owns
  the result. *)
function TfrmSetupWizard.ShownWSJTX: TSetupWsjtxValues;
begin
   Result := TSetupWsjtxValues.Create;
   Result.Enabled        := chkWSJTXEnable.Checked;
   Result.RadioControl   := chkWSJTXRadioControl.Checked;
   Result.Highlights     := chkWSJTXHighlights.Checked;
   Result.Port           := Trim(edtWSJTXPort.Text);
   Result.MulticastGroup := Trim(edtWSJTXMulticast.Text);
end;

(* ONLY WHAT CHANGED IS WRITTEN (SetupWsjtxChanges), through Preferences' own
  path.  A refused value is reported.  From the Tools menu, some changes wait
  for a restart, and the result says so:
    switching WSJT-X on   only when its server was never made -- since
                          2026-11-25 uProgramMain makes it at every start and
                          uSettingsEffects starts it at once, so this is the
                          run BEFORE that point (the startup wizard), which
                          the same start then completes
    the UDP port          bound when the server starts
    radio control         the DX Commander listener is made with the server,
                          and only when radio control is on (TWSJTXServer.Create)
    a multicast group     replaced or cleared: a new group is joined at once
                          (uSettingsEffects), but nothing leaves the old one
  Highlights apply at once (uSettingsEffects sets SendColorization). *)
procedure TfrmSetupWizard.CommitWSJTX(const aStore: TRadioConfigStore;
                                      var aReport: string);
var
   shown: TSetupWsjtxValues;
   changes: TSetupWsjtxFields;
   needsRestart: boolean;

   (* One command through Preferences' path; a refusal is reported. *)
   function WriteCommand(const aCommand, aValue: string): boolean;
   begin
      Result := ApplyAndStoreCommand(aStore, aCommand, aValue);
      if not Result then
         begin
         AddReportLine(aReport, UnicodeFormat(SWizResRefused, [aCommand, aValue]));
         end;
   end;

begin
   needsRestart := False;
   shown := ShownWSJTX;
   try
      changes := SetupWsjtxChanges(FWSJTXLoaded, shown);

      if swfEnabled in changes then
         begin
         if WriteCommand(WSJTX_CMD_ENABLED, string(BA[shown.Enabled])) and shown.Enabled then
            begin
            (* The startup run comes before the server is made; that same
              start makes it and starts it (uProgramMain). *)
            needsRestart := (wsjtx = nil) and (not FStartupMode);
            end;
         end;
      if swfPort in changes then
         begin
         if WriteCommand(WSJTX_CMD_PORT, shown.Port) then
            begin
            needsRestart := True;
            end;
         end;
      if swfRadioControl in changes then
         begin
         if WriteCommand(WSJTX_CMD_RADIO_CONTROL, string(BA[shown.RadioControl])) then
            begin
            needsRestart := True;
            end;
         end;
      if swfHighlights in changes then
         begin
         WriteCommand(WSJTX_CMD_HIGHLIGHTS, string(BA[shown.Highlights]));
         end;
      if swfMulticastGroup in changes then
         begin
         if WriteCommand(WSJTX_CMD_MULTICAST, shown.MulticastGroup) and
            (FWSJTXLoaded.MulticastGroup <> '') then
            begin
            needsRestart := True;
            end;
         end;

      if shown.Enabled then
         begin
         AddReportLine(aReport, UnicodeFormat(SWizResWSJTXOn, [shown.Port]));
         if shown.Highlights then
            begin
            AddReportLine(aReport, SWizResWSJTXHighlights);
            end;
         if shown.RadioControl then
            begin
            AddReportLine(aReport, UnicodeFormat(SWizResWSJTXRadioControl,
                                                 [COMMANDER_DEFAULT_PORT]));
            end;
         if shown.MulticastGroup <> '' then
            begin
            AddReportLine(aReport, UnicodeFormat(SWizResWSJTXMulticast,
                                                 [shown.MulticastGroup]));
            end;
         end
      else
         begin
         AddReportLine(aReport, SWizResWSJTXOff);
         end;
      if needsRestart and (not FStartupMode) then
         begin
         AddReportLine(aReport, SWizResWSJTXRestart);
         end;
   finally
      shown.Free;
   end;
end;

(* Editor first, then the copy it writes into -- it holds a pointer to it. *)
procedure TfrmSetupWizard.DropRadioEditor;
begin
   FreeAndNil(FRadioEditor);
   FreeAndNil(FRadioEditing);
   (* A re-ticked radio starts blank, and its CW choices with it. *)
   chkCWByCAT.Checked   := False;
   chkSpeedSync.Checked := False;
   chkCWByCAT.Visible   := False;
   chkSpeedSync.Visible := False;
end;

procedure TfrmSetupWizard.DropKeyerEditor;
begin
   FreeAndNil(FKeyerEditor);
   FreeAndNil(FKeyerEditing);
end;

(* NEXT ON AN EDITOR PAGE: the editor validates and writes into its editing
  copy, and the draft becomes a copy of that.  False leaves the operator on the
  page, the editor having said why. *)
function TfrmSetupWizard.AcceptEditorPage(const aPage: TSetupPage): boolean;
begin
   Result := False;
   if (aPage = spRadio) and (FRadioEditor <> nil) then
      begin
      Result := FRadioEditor.AcceptEdits;
      if Result then
         begin
         (* The editor has no CW fields; the draft carries the two choices in
           the radio's own CW flags, and StageSetupItems moves them to the
           profile.  A box that is hidden or disabled counts as unticked. *)
         FRadioEditing.CWByCAT     := chkCWByCAT.Visible and chkCWByCAT.Enabled and
                                      chkCWByCAT.Checked;
         FRadioEditing.CWSpeedSync := chkSpeedSync.Visible and chkSpeedSync.Checked;
         FreeAndNil(FRadioDraft);
         FRadioDraft := FRadioEditing.Clone;
         end;
      end
   else if (aPage = spKeyer) and (FKeyerEditor <> nil) then
      begin
      Result := FKeyerEditor.AcceptEdits;
      if Result then
         begin
         FreeAndNil(FKeyerDraft);
         FKeyerDraft := FKeyerEditing.Clone;
         end;
      end
   else if (aPage = spLogger) and (FLoggerEditor <> nil) then
      begin
      (* A logbook list still arriving would decide the account after the
        fact: the editor refuses, and the wizard says why. *)
      if FLoggerEditor.LoadRunning then
         begin
         ShowMessage(SWizLoggerLoading);
         Exit;
         end;
      Result := FLoggerEditor.AcceptEdits;
      if Result then
         begin
         FreeAndNil(FLoggerDraft);
         FLoggerDraft := TExternalLoggerDefinition.Create;
         FLoggerDraft.Assign(FLoggerEditor.Definition);
         FLoggerDraftActive :=
            FLoggerEditor.Config.ActivePosition(FLoggerEditor.Definition.Id) > 0;
         end;
      end;
end;

(* CAN THE OPERATOR LEAVE THIS PAGE FORWARDS?  Says why not, once. *)
function TfrmSetupWizard.PageIsComplete(const aPage: TSetupPage): boolean;
var
   call: string;
begin
   Result := True;
   case aPage of
      spStation:
         begin
         call := Trim(edtCall.Text);
         if call = '' then
            begin
            ShowMessage(SWizCallRequired);
            edtCall.SetFocus;
            Result := False;
            Exit;
            end;
         (* QUERIED, NOT REFUSED -- IsAGoodCall is a syntax screen, and the
           Station page asks the same question for the same reason. *)
         if (not IsAGoodCall(call)) and (call <> FConfirmedCall) then
            begin
            if MessageDlg(Format(SWizCallOdd, [call]),
                          TMsgDlgType.mtWarning,
                          [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
               begin
               edtCall.SetFocus;
               Result := False;
               Exit;
               end;
            FConfirmedCall := call;
            end;
         end;
      spRadio, spKeyer, spLogger:
         begin
         Result := AcceptEditorPage(aPage);
         end;
      spRotator:
         begin
         if cbxRotatorType.ItemIndex < 0 then
            begin
            ShowMessage(SWizRotatorNeedsType);
            cbxRotatorType.SetFocus;
            Result := False;
            end
         else if RotatorIsSerial and
                 ((cbxRotatorPort.ItemIndex < 0) or
                  UnicodeSameText(SelectedTag(cbxRotatorPort), PORT_NONE)) then
            begin
            ShowMessage(SWizRotatorNeedsPort);
            cbxRotatorPort.SetFocus;
            Result := False;
            end
         else if (not RotatorIsSerial) and (not IsValidClusterPort(edtRotatorUDP.Text)) then
            begin
            (* IsValidClusterPort is the general rule: blank, or 1 to 65535. *)
            ShowMessage(SWizRotatorUDPPortBad);
            edtRotatorUDP.SetFocus;
            Result := False;
            end;
         end;
      spWSJTX:
         begin
         if chkWSJTXEnable.Checked and
            ((Trim(edtWSJTXPort.Text) = '') or (not IsValidClusterPort(edtWSJTXPort.Text))) then
            begin
            ShowMessage(SWizWSJTXPortBad);
            edtWSJTXPort.SetFocus;
            Result := False;
            end;
         end;
      spCluster:
         begin
         ServerExit(nil);
         if Trim(cbxServer.Text) = '' then
            begin
            ShowMessage(SWizClusterNeeded);
            cbxServer.SetFocus;
            Result := False;
            end
         else if not IsValidClusterPort(edtPort.Text) then
            begin
            ShowMessage(SWizClusterPortBad);
            edtPort.SetFocus;
            Result := False;
            end;
         end;
   end;
end;

procedure TfrmSetupWizard.btnNextClick(Sender: TObject);
begin
   if FDownloading then
      begin
      Exit;
      end;
   if not PageIsComplete(FPlan[FIndex]) then
      begin
      Exit;
      end;

   if IsCommitPage(FPlan, FIndex) then
      begin
      (* PREFERENCES OPENED WHILE THE WIZARD WAS UP.  ShowSetupWizard refuses
        the other order; this is this one.  Preferences holds the libraries
        as it loaded them, and its next save would delete what this adds --
        so nothing is written until it is closed, and the operator stays on
        this page with everything still typed. *)
      if PreferencesIsShowing then
         begin
         ShowMessage(SWizPrefsOpen);
         Exit;
         end;
      if not PortsAcceptable then
         begin
         Exit;
         end;
      Commit;
      FIndex := IndexOfSetupPage(FPlan, spResult);
      end
   else
      begin
      Inc(FIndex);
      end;
   ShowCurrentPage;
end;

procedure TfrmSetupWizard.btnBackClick(Sender: TObject);
begin
   if (FIndex > 0) and (not FDownloading) then
      begin
      Dec(FIndex);
      ShowCurrentPage;
      end;
end;

procedure TfrmSetupWizard.btnCancelClick(Sender: TObject);
begin
   Close;
end;

procedure TfrmSetupWizard.HandleShow(Sender: TObject);
begin
   if (pgPages.ActivePage = tsStation) and edtCall.CanSetFocus then
      begin
      edtCall.SetFocus;
      end;
end;

procedure TfrmSetupWizard.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   (* Freed, not hidden: the next opening starts from what is on disk.
     Cancel before "Create configuration" has written nothing.

     A MODAL run is freed by the routine that showed it, once ShowModal has
     returned -- freeing a form from inside its own modal loop is the one
     order that can fault. *)
   if FStartupMode then
      begin
      Action := caHide;
      end
   else
      begin
      Action := caFree;
      end;
end;

(* NO CLOSING MID-DOWNLOAD: the download's done-event is a method of this form.
  CloseQuery is also what resets a modal run's ModalResult, so the window's own
  X cannot end a startup run from under it. *)
procedure TfrmSetupWizard.HandleCloseQuery(Sender: TObject; var CanClose: boolean);
begin
   CanClose := not FDownloading;
end;

{ ------------------------------------------------------------- country file ---- }

(* THE STATION PAGE SAYS WHETHER THERE IS A COUNTRY FILE, and offers the
  download beside the callsign that needs it -- in the wizard's own window
  rather than a question from outside it (NY4I, 2026-11-14). *)
procedure TfrmSetupWizard.ShowCountryFileState;
var
   missing: boolean;
begin
   missing := ctyGetTotalCountries = 0;
   lblCtyStatus.Visible := missing;
   btnCtyDownload.Visible := missing;
   btnCtyDownload.Enabled := missing and (not FDownloading);
   if missing and (not FDownloading) then
      begin
      lblCtyStatus.Caption := SWizCtyMissing;
      end;
end;

procedure TfrmSetupWizard.btnCtyDownloadClick(Sender: TObject);
begin
   if FDownloading then
      begin
      Exit;
      end;
   FDownloading := True;
   lblCtyStatus.Caption := SWizCtyDownloading;
   btnCtyDownload.Enabled := False;
   UpdateButtons;
   (* WHERE DOWNLOADED DATA BELONGS, never the shipped copy -- the rule
     EnsureCountryFile and the menu item follow. *)
   DownloadCTYAsync(DownloadedDataFilePath('CTY.DAT'), CountryFileDownloaded);
end;

(* ON THE MAIN THREAD (TThread.OnTerminate).  Adopts the file only if it
  PARSES: a download can succeed and leave something that is not a country
  file. *)
procedure TfrmSetupWizard.CountryFileDownloaded(Sender: TObject; aSucceeded: boolean);
begin
   FDownloading := False;
   if aSucceeded and LoadCountryFileFrom(DownloadedDataFilePath('CTY.DAT')) then
      begin
      ShowCountryFileState;
      lblCtyStatus.Visible := True;
      lblCtyStatus.Caption := SWizCtyDone;
      RunLookup;
      end
   else
      begin
      ShowCountryFileState;
      lblCtyStatus.Caption := SWizCtyFailed;
      end;
   UpdateButtons;
end;

{ -------------------------------------------------------------- commit ---- }

(* COLLIDING PORTS ARE ASKED ABOUT BEFORE ANYTHING IS WRITTEN -- Preferences'
  own question (TC_PREFS_PORTCONFLICT), with its default of No.

  Asked here and not after the commit, because after it there is nothing to
  decide: the profile would already be saved as the active one, and the next
  start would put it on the air regardless.  A WinKeyer given the radio's port
  is the double-open design section 7 forbids, so the operator is told and
  chooses; No leaves them on this page to go Back and change the port.

  The answer is computed the way the commit will compute it: the libraries as
  they are on disk, with this run's drafts staged into a THROWAWAY copy. *)
function TfrmSetupWizard.PortsAcceptable: boolean;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   ticked: TSetupItems;
   radio: TRadioDefinition;
   keyer: TKeyerDefinition;
   loadErr, scratch, conflicts: string;
begin
   Result := True;
   ticked := TickedItems;
   if not ((siRadio in ticked) or (siKeyer in ticked)) then
      begin
      Exit;
      end;

   radio := nil;
   keyer := nil;
   if siRadio in ticked then
      begin
      radio := FRadioDraft;
      end;
   if siKeyer in ticked then
      begin
      keyer := FKeyerDraft;
      end;

   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      (* An unreadable store is the commit's to report; nothing is asked. *)
      if FileExists(RadioStoreFileName) and
         (not LoadConfig(RadioStoreFileName, store, keyers, loadErr)) then
         begin
         Exit;
         end;
      scratch := '';
      StageSetupItems(store, keyers, radio, keyer, nil, scratch);
      if store.ActiveProfile = nil then
         begin
         Exit;
         end;
      conflicts := DescribePortConflicts(store, store.ActiveProfile, keyers);
      if conflicts = '' then
         begin
         Exit;
         end;
      (* Preferences' own question and default (ConfirmPortConflicts): one
        definition, so the two cannot disagree about what a collision asks. *)
      Result := ConfirmPortConflicts(conflicts);
   finally
      keyers.Free;
      store.Free;
   end;
end;

(* THE STATION, THROUGH THE PREFERENCES STATION PAGE'S OWN PATH.  Only what
  changed is written, and a derived field still following the callsign is
  never written at all.  A refused value is reported, not swallowed. *)
procedure TfrmSetupWizard.CommitStation(const aStore: TRadioConfigStore;
                                        var aReport: string);
var
   f: TWizStationField;
   value: string;
   refused: string;
begin
   refused := '';
   for f in FFields do
      begin
      if f.Derivable and (not f.OperatorOwned) then
         begin
         Continue;
         end;
      value := Trim(f.Edit.Text);
      if f.Command = 'MY GRID' then
         begin
         value := NormalizeGridSquare(value);
         end;
      if value = f.Loaded then
         begin
         Continue;
         end;
      if not ApplyAndStoreCommand(aStore, f.Command, value) then
         begin
         AddReportLine(refused, UnicodeFormat(SWizResRefused, [f.Command, value]));
         end;
      end;

   if FContinentOwned and (cbxContinent.ItemIndex >= 0) then
      begin
      value := cbxContinent.Items[cbxContinent.ItemIndex];
      if value <> FContinentLoaded then
         begin
         if not ApplyAndStoreCommand(aStore, 'MY CONTINENT', value) then
            begin
            AddReportLine(refused, UnicodeFormat(SWizResRefused, ['MY CONTINENT', value]));
            end;
         end;
      end;

   AddReportLine(aReport, UnicodeFormat(SWizResStation, [Trim(edtCall.Text)]));
   if refused <> '' then
      begin
      AddReportLine(aReport, refused);
      end;
end;

procedure TfrmSetupWizard.Commit;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   storeRead: boolean;
   loadErr, err, conflicts: string;
   report, details: string;
   ticked, staged: TSetupItems;
   radio: TRadioDefinition;
   keyer: TKeyerDefinition;
   cluster: TClusterDefinition;
   rotator: TRotatorDefinition;
   profile: TStationProfile;
begin
   report := '';
   details := '';
   ticked := TickedItems;
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   cluster := nil;
   try
      storeRead := True;
      loadErr := '';
      if FileExists(RadioStoreFileName) then
         begin
         storeRead := LoadConfig(RadioStoreFileName, store, keyers, loadErr);
         end;

      (* 1. THE STATION, AND IT IS SAVED BEFORE ANYTHING ELSE IS TRIED.  A
        command the settings object owns is saved by ApplyAndStoreCommand
        itself; the rest land in the store, saved here.  A store that could
        not be read is never written over -- the station's owned values are
        still saved, and the rest is reported. *)
      if storeRead then
         begin
         CommitStation(store, report);
         SaveConfig(RadioStoreFileName, store, keyers);
         end
      else
         begin
         CommitStation(nil, report);
         end;
      logger.Info('[SetupWizard] station applied: %s', [Trim(edtCall.Text)]);

      (* WSJT-X IS SETTINGS, not a library, so it goes with the station: saved
        by ApplyAndStoreCommand, whether or not the libraries could be read. *)
      if siWSJTX in ticked then
         begin
         if storeRead then
            begin
            CommitWSJTX(store, report);
            end
         else
            begin
            CommitWSJTX(nil, report);
            end;
         end;

      if ticked - [siWSJTX] = [] then
         begin
         Exit;
         end;

      if not storeRead then
         begin
         AddReportLine(report, UnicodeFormat(SWizResNotSaved, [loadErr]));
         logger.Error('[SetupWizard] %s could not be read (%s) -- the radio, ' +
                      'keyer and cluster were not saved', [RadioStoreFileName, loadErr]);
         Exit;
         end;

      (* 2. THE HARDWARE, each item independently. *)
      radio := nil;
      keyer := nil;
      if siRadio in ticked then
         begin
         radio := FRadioDraft;
         end;
      if siKeyer in ticked then
         begin
         keyer := FKeyerDraft;
         end;
      if siCluster in ticked then
         begin
         cluster := TClusterDefinition.Create;
         cluster.Server         := ClusterServerText;
         cluster.LoginCall      := Trim(edtLogin.Text);
         // NOT trimmed -- a password may begin or end with a space.
         cluster.Password       := edtPassword.Text;
         cluster.ConnectCommand := Trim(edtCommand.Text);
         end;

      staged := StageSetupItems(store, keyers, radio, keyer, cluster, report);

      (* THE ROTATOR AND THE EXTERNAL LOGGER, each on its own (issue 334). *)
      if siRotator in ticked then
         begin
         rotator := RotatorDraft;
         try
            if StageSetupRotator(store, rotator, report) then
               begin
               Include(staged, siRotator);
               end;
         finally
            rotator.Free;
         end;
         end;
      if (siLogger in ticked) and (FLoggerDraft <> nil) then
         begin
         (* STARTUP'S SEED FIRST: on a file that predates the definitions it is
           what carries a legacy single logger across, and it marks the
           library present.  A library that could not be read is left to
           StageSetupLogger to refuse. *)
         if store.ExternalLoggers.Error = '' then
            begin
            SeedExternalLoggers(store.ExternalLoggers, Settings.ExternalLogger);
            end;
         if StageSetupLogger(store.ExternalLoggers, FLoggerDraft, FLoggerDraftActive, report) then
            begin
            Include(staged, siLogger);
            end;
         end;

      (* What "Show details" adds, only for what actually landed. *)
      if not (siRadio in staged) then
         begin
         radio := nil;
         end;
      if not (siKeyer in staged) then
         begin
         keyer := nil;
         end;
      if not (siCluster in staged) then
         begin
         FreeAndNil(cluster);
         end;
      details := SetupDetailLines(radio, keyer, cluster);

      (* THE STORES' OWN VALIDATION decides whether this is saveable.  A
        refusal leaves the file as step 1 wrote it -- the station kept, the
        hardware not -- and says why. *)
      if not store.Validate(err) then
         begin
         AddReportLine(report, UnicodeFormat(SWizResNotSaved, [err]));
         logger.Error('[SetupWizard] radio library refused: %s', [err]);
         Exit;
         end;
      if not keyers.Validate(err) then
         begin
         AddReportLine(report, UnicodeFormat(SWizResNotSaved, [err]));
         logger.Error('[SetupWizard] keyer library refused: %s', [err]);
         Exit;
         end;
      (* A REFUSED SAVE IS SAID ON THE RESULT PAGE (issue 165): SaveConfig
        reports it instead of raising, and the page would otherwise read as
        if everything had been kept. uTR4WConfigFile logged it and told the
        operator once. *)
      if not SaveConfig(RadioStoreFileName, store, keyers) then
         begin
         AddReportLine(report, UnicodeFormat(SWizResNotSaved, [LastConfigWriteFailure]));
         end;

      (* AT STARTUP THERE IS NOTHING TO PUT INTO USE ON: saved is as far as this
        goes.  Startup applies the saved active profile and cluster itself, a
        few steps after the New Contest window -- the same road every later
        start takes, so a wizard run and an ordinary start cannot differ. *)
      if FStartupMode then
         begin
         logger.Info('[SetupWizard] configuration saved; startup applies it');
         Exit;
         end;

      (* 3. PUT IT INTO USE -- what Preferences' Activate does.  An operational
        failure (a port that will not open) is reported, never a reason to
        undo what was saved: the configuration is right even if the radio is
        at the other end of the house today. *)
      profile := store.ActiveProfile;
      (* No profile only when the store refused to add one -- already
        reported by StageSetupItems. *)
      if ((siRadio in staged) or (siKeyer in staged)) and (profile <> nil) then
         begin
         (* A collision reaching here was ACCEPTED by the operator on the
           commit page (PortsAcceptable); it is still listed on the result. *)
         conflicts := DescribePortConflicts(store, profile, keyers);
         if conflicts <> '' then
            begin
            AddReportLine(report, UnicodeFormat(SWizResPortWarning, [conflicts]));
            end;
         if ApplyProfile(store, profile, err, keyers) then
            begin
            // ApplyProfile records the active profile; keep that across a restart.
            SaveConfig(RadioStoreFileName, store, keyers);
            end
         else
            begin
            AddReportLine(report, UnicodeFormat(SWizResApplyFailed, [err]));
            logger.Error('[SetupWizard] applying the profile failed: %s', [err]);
            end;
         end;

      if siCluster in staged then
         begin
         ApplyActiveCluster(store);
         end;

      (* What Preferences' save does with these two libraries. *)
      if siRotator in staged then
         begin
         ConfigureRotators(store);
         end;
      if siLogger in staged then
         begin
         ApplyExternalLoggerConfiguration(store.ExternalLoggers);
         (* A definition added since start runs from the next start (issue
           233): the set of running services is fixed for the session. *)
         if FLoggerDraftActive then
            begin
            AddReportLine(report, SWizResLoggerRestart);
            end;
         end;

      logger.Info('[SetupWizard] configuration created');
   finally
      cluster.Free;
      keyers.Free;
      store.Free;
      (* A hidden Preferences holds the libraries as they were; it re-reads
        them now, or its next save would undo this. *)
      PreferencesReloadAfterExternalSave;
      FReportBrief := report;
      FReportDetails := report;
      if details <> '' then
         begin
         (* The detail lines follow the brief report as an indented block. *)
         AddReportLine(FReportDetails, '');
         AddReportLine(FReportDetails, details);
         end;
      ShowResult;
   end;
end;

procedure TfrmSetupWizard.ShowResult;
begin
   if chkDetails.Checked then
      begin
      memResult.Text := LclText(FReportDetails);
      end
   else
      begin
      memResult.Text := LclText(FReportBrief);
      end;
   (* Nothing to show beyond the brief report: no box to offer. *)
   chkDetails.Visible := FReportDetails <> FReportBrief;
end;

procedure TfrmSetupWizard.DetailsChange(Sender: TObject);
begin
   ShowResult;
end;

initialization

finalization
   gCallbookTarget := nil;

end.
