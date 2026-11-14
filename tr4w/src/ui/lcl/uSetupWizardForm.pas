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
                TfrmKeyerEdit), on a draft the wizard holds
    all three   put in the stores by uSetupWizard.StageSetupItems, then saved
                and applied with SaveConfig, ApplyProfile and
                ApplyActiveCluster -- what Preferences' Activate does

  ORDER SO THAT FAILURE COSTS NOTHING (design 3.2).  Nothing is written until
  "Create configuration".  Then the station is applied and SAVED FIRST, and
  only then are the radio, keyer and cluster staged, validated, saved and put
  into use -- so a radio that will not open cannot cost the callsign.

  MODELESS, like the two editors it opens and for their reason: ShowModal runs
  a second message loop, and TR4W's CW timing and radio servicing would stop
  for as long as the wizard was up.  Owned by the main window so it stays in
  front of it.  One at a time (gSetupWizard), freed on close, so every opening
  starts from what is on disk. *)

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
      lblDerived: TLabel;

      tsChecklist: TTabSheet;
      chkRadio: TCheckBox;
      lblRadioHint: TLabel;
      chkKeyer: TCheckBox;
      lblKeyerHint: TLabel;
      chkCluster: TCheckBox;
      lblClusterHint: TLabel;

      tsRadio: TTabSheet;
      btnRadio: TButton;
      lblRadioSummary: TLabel;

      tsKeyer: TTabSheet;
      btnKeyer: TButton;
      lblKeyerSummary: TLabel;

      tsCluster: TTabSheet;
      cbxServer: TComboBox;
      lblServer: TInputCaption;
      edtLogin: TEdit;
      lblLogin: TInputCaption;
      edtPassword: TEdit;
      lblPassword: TInputCaption;
      edtCommand: TEdit;
      lblCommand: TInputCaption;

      tsResult: TTabSheet;
      memResult: TMemo;

      pnlButtons: TPanel;
      btnBack: TButton;
      btnNext: TButton;
      btnCancel: TButton;
      tmrLookup: TTimer;

      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
      procedure btnBackClick(Sender: TObject);
      procedure btnNextClick(Sender: TObject);
      procedure btnCancelClick(Sender: TObject);
      procedure btnRadioClick(Sender: TObject);
      procedure btnKeyerClick(Sender: TObject);
      procedure edtCallChange(Sender: TObject);
      procedure DerivedFieldChange(Sender: TObject);
      procedure ChecklistChange(Sender: TObject);
      procedure tmrLookupTimer(Sender: TObject);
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

      (* A draft is what an editor accepted; the editing copy is what an open
        editor is working on.  nil until set up.  Unticking frees the draft. *)
      FRadioDraft: TRadioDefinition;
      FRadioEditing: TRadioDefinition;
      FRadioEditor: TRadioEditForm;
      FKeyerDraft: TKeyerDefinition;
      FKeyerEditing: TKeyerDefinition;
      FKeyerEditor: TfrmKeyerEdit;
      FEditorOpen: boolean;

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
      procedure RefreshSummaries;
      procedure SetEditorOpen(const aOpen: boolean);
      function PageIsComplete(const aPage: TSetupPage): boolean;
      function PortsAcceptable: boolean;
      procedure RadioEditorDone(const aAccepted: boolean);
      procedure KeyerEditorDone(const aAccepted: boolean);
      procedure CommitStation(const aStore: TRadioConfigStore;
                              var aReport: string);
      procedure Commit;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
   end;

(* Open the wizard, or bring the open one forward.  Refuses, with a message,
  while Preferences is on screen: both edit the same libraries from their own
  copies, and the second to save would undo the first. *)
procedure ShowSetupWizard;

implementation

{$R *.lfm}

uses
   Dialogs,
   System.UITypes,
   VC,                  // ContinentTypeSA
   uctydat,             // ctyGetCountryID, ctyGetZone, ctyGetITUZone, ctyGetContinent
   uCallSignRoutines,   // IsAGoodCall
   uTR4WConfigFile,     // LoadConfig, SaveConfig
   uRadioConfigApply,   // ApplyAndStoreCommand, StationCommandValue, ApplyProfile ...
   uPrefsForm,          // PreferencesIsShowing, LoadClusterDirectory ...
   uLCLFormHelpers,     // OwnFormByMainWindow
   uAppStrings,
   utils_text,          // LclText -- a UTF-16 string onto an LCL property
   MainUnit;            // logger

var
   gSetupWizard: TfrmSetupWizard = nil;

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

{ TfrmSetupWizard }

constructor TfrmSetupWizard.Create(AOwner: TComponent);
var
   c: ContinentType;
begin
   inherited Create(AOwner);
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

   AssignCaptions;
   LoadStation;

   FPlan := SetupPagePlan([]);
   FIndex := 0;
   ShowCurrentPage;
end;

destructor TfrmSetupWizard.Destroy;
begin
   (* The editors first: they hold the editing copies freed below. *)
   FreeAndNil(FRadioEditor);
   FreeAndNil(FKeyerEditor);
   FreeAndNil(FRadioEditing);
   FreeAndNil(FRadioDraft);
   FreeAndNil(FKeyerEditing);
   FreeAndNil(FKeyerDraft);
   FreeAndNil(FFields);
   if gSetupWizard = Self then
      begin
      gSetupWizard := nil;
      end;
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
   lblLookup.Caption      := '';

   chkRadio.Caption       := SWizItemRadio;
   lblRadioHint.Caption   := SWizItemRadioHint;
   chkKeyer.Caption       := SWizItemKeyer;
   lblKeyerHint.Caption   := SWizItemKeyerHint;
   chkCluster.Caption     := SWizItemCluster;
   lblClusterHint.Caption := SWizItemClusterHint;

   btnRadio.Caption       := SWizRadioButton;
   btnKeyer.Caption       := SWizKeyerButton;

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
         f.Edit.Text := LclText(f.Loaded);
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
   if (Length(aCall) < 3) or (ctyGetCountryID(aCall) = '') then
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
      FreeAndNil(FRadioDraft);
      end;
   if not chkKeyer.Checked then
      begin
      FreeAndNil(FKeyerDraft);
      end;
   if not chkCluster.Checked then
      begin
      cbxServer.Text      := '';
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
   pgPages.ActivePage := SheetFor(page);
   RefreshSummaries;
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

   btnBack.Enabled := (FIndex > 0) and (not FEditorOpen);
   btnNext.Enabled := not FEditorOpen;
   btnCancel.Enabled := not FEditorOpen;
   if IsCommitPage(FPlan, FIndex) then
      begin
      btnNext.Caption := SWizCreate;
      end
   else
      begin
      btnNext.Caption := SWizNext;
      end;
end;

procedure TfrmSetupWizard.RefreshSummaries;
begin
   if FRadioDraft <> nil then
      begin
      lblRadioSummary.Caption := LclText(FRadioDraft.DisplaySummary);
      end
   else
      begin
      lblRadioSummary.Caption := SWizNotSetUp;
      end;

   if FKeyerDraft <> nil then
      begin
      lblKeyerSummary.Caption := LclText(FKeyerDraft.DisplaySummary);
      end
   else
      begin
      lblKeyerSummary.Caption := SWizNotSetUp;
      end;
end;

(* WHILE AN EDITOR IS OPEN THE WIZARD WAITS: moving on would leave the editor
  writing into a draft whose page is gone. *)
procedure TfrmSetupWizard.SetEditorOpen(const aOpen: boolean);
begin
   FEditorOpen := aOpen;
   btnRadio.Enabled := not aOpen;
   btnKeyer.Enabled := not aOpen;
   UpdateButtons;
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
      spRadio:
         begin
         if FRadioDraft = nil then
            begin
            ShowMessage(SWizRadioNeeded);
            Result := False;
            end;
         end;
      spKeyer:
         begin
         if FKeyerDraft = nil then
            begin
            ShowMessage(SWizKeyerNeeded);
            Result := False;
            end;
         end;
      spCluster:
         begin
         if Trim(cbxServer.Text) = '' then
            begin
            ShowMessage(SWizClusterNeeded);
            cbxServer.SetFocus;
            Result := False;
            end;
         end;
   end;
end;

procedure TfrmSetupWizard.btnNextClick(Sender: TObject);
begin
   if FEditorOpen then
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
   if (FIndex > 0) and (not FEditorOpen) then
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
   (* NOT WHILE AN EDITOR IS OPEN: it is working on a copy this form owns. *)
   if FEditorOpen then
      begin
      Action := caNone;
      Exit;
      end;
   (* Freed, not hidden: the next opening starts from what is on disk.
     Cancel before "Create configuration" has written nothing. *)
   Action := caFree;
end;

{ ------------------------------------------------------------- editors ---- }

procedure TfrmSetupWizard.btnRadioClick(Sender: TObject);
begin
   if FRadioEditor = nil then
      begin
      FRadioEditor := TRadioEditForm.Create(Self);
      end;
   (* The editor works on a COPY, so its Cancel really cancels. *)
   FreeAndNil(FRadioEditing);
   if FRadioDraft <> nil then
      begin
      FRadioEditing := FRadioDraft.Clone;
      end
   else
      begin
      FRadioEditing := TRadioDefinition.Create;
      FRadioEditing.Name := 'Radio';
      end;
   SetEditorOpen(True);
   FRadioEditor.EditRadio(FRadioEditing, RadioEditorDone);
end;

procedure TfrmSetupWizard.RadioEditorDone(const aAccepted: boolean);
begin
   if aAccepted then
      begin
      FreeAndNil(FRadioDraft);
      FRadioDraft := FRadioEditing;
      FRadioEditing := nil;
      end
   else
      begin
      FreeAndNil(FRadioEditing);
      end;
   SetEditorOpen(False);
   RefreshSummaries;
end;

procedure TfrmSetupWizard.btnKeyerClick(Sender: TObject);
begin
   if FKeyerEditor = nil then
      begin
      FKeyerEditor := TfrmKeyerEdit.Create(Self);
      end;
   FreeAndNil(FKeyerEditing);
   if FKeyerDraft <> nil then
      begin
      FKeyerEditing := FKeyerDraft.Clone;
      end
   else
      begin
      FKeyerEditing := TKeyerDefinition.Create;   // a WinKeyer, no port yet
      FKeyerEditing.Name := 'WinKeyer';
      end;
   SetEditorOpen(True);
   FKeyerEditor.EditKeyer(FKeyerEditing, KeyerEditorDone);
end;

procedure TfrmSetupWizard.KeyerEditorDone(const aAccepted: boolean);
begin
   if aAccepted then
      begin
      FreeAndNil(FKeyerDraft);
      FKeyerDraft := FKeyerEditing;
      FKeyerEditing := nil;
      end
   else
      begin
      FreeAndNil(FKeyerEditing);
      end;
   SetEditorOpen(False);
   RefreshSummaries;
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
      conflicts := DescribePortConflicts(store, store.ActiveProfile);
      if conflicts = '' then
         begin
         Exit;
         end;
      (* The marker sits last, applying to mrNo -- No is the default, the
        same as Preferences, so a reflexive Enter does not key a radio. *)
      Result := QuestionDlg('TR4W', Format(TC_PREFS_PORTCONFLICT, [conflicts]),
                            TMsgDlgType.mtWarning,
                            [mrYes, mrNo, 'IsDefault'], 0) = mrYes;
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
   report: string;
   ticked, staged: TSetupItems;
   radio: TRadioDefinition;
   keyer: TKeyerDefinition;
   cluster: TClusterDefinition;
   profile: TStationProfile;
begin
   report := '';
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
         cluster.Server         := Trim(cbxServer.Text);
         cluster.LoginCall      := Trim(edtLogin.Text);
         // NOT trimmed -- a password may begin or end with a space.
         cluster.Password       := edtPassword.Text;
         cluster.ConnectCommand := Trim(edtCommand.Text);
         end;

      staged := StageSetupItems(store, keyers, radio, keyer, cluster, report);

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
         conflicts := DescribePortConflicts(store, profile);
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
      memResult.Text := LclText(report);
   end;
end;

end.
