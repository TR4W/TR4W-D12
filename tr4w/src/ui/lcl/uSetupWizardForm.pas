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

  One Station page, one checklist (Radio, WinKeyer, DX cluster), one page per
  ticked item in canonical order, then "Create configuration" and a result
  page that says what landed and what did not.  Opens by itself on a
  brand-new install (uProgramMain) and from Tools -> Setup Wizard.

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
      (* The client height the designer gave the window; pages that host an
        editor are taller and the others return to this. *)
      FBaseClientHeight: integer;
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
      procedure FitWindowTo(const aHosted: integer);
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
   VC,                  // ContinentTypeSA
   uctydat,             // ctyGetCountryID, ctyGetZone, ctyGetITUZone, ctyGetContinent
   uCallSignRoutines,   // IsAGoodCall
   uTR4WConfigFile,     // LoadConfig, SaveConfig
   uRadioRegistry,      // SupportsForId -- which radios can do CW by CAT
   uRadioConfigApply,   // ApplyAndStoreCommand, StationCommandValue, ApplyProfile ...
   uPrefsForm,          // PreferencesIsShowing, LoadClusterDirectory ...
   uLCLFormHelpers,     // OwnFormByMainWindow
   uAppStrings,
   uAppPaths,           // DownloadedDataFilePath
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
   AssignCaptions;
   LoadStation;
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
   FreeAndNil(FRadioDraft);
   FreeAndNil(FKeyerDraft);
   FreeAndNil(FFields);
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
   hosted: integer;
begin
   hosted := 0;
   case aPage of
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
         end;
   end;

   FitWindowTo(hosted);
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

(* Size the window to the header, the hosted editor (and anything under it),
  the buttons and a little air. *)
procedure TfrmSetupWizard.FitWindowTo(const aHosted: integer);
const
   SLACK = 8;
var
   needed: integer;
   work, outer: TRect;
begin
   needed := pnlHeader.Height + aHosted + pnlButtons.Height + SLACK;
   if needed < FBaseClientHeight then
      begin
      needed := FBaseClientHeight;
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
      spRadio, spKeyer:
         begin
         Result := AcceptEditorPage(aPage);
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

      if ticked = [] then
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
      SaveConfig(RadioStoreFileName, store, keyers);

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
