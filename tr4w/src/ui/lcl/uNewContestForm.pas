unit uNewContestForm;
{$I ..\..\tr4w.inc}

{
  THE OPEN-CONFIGURATION / NEW-CONTEST DIALOG, AS A DESIGNED LCL FORM.

  WHAT IT REPLACES. uNewContest builds this dialog by hand: CreateModalDialog
  with a template measured in dialog units, then ~30 controls created in
  WM_INITDIALOG with literal pixel coordinates, addressed afterwards by numeric
  id through GetDlgItem. It is the last Win32 dialog the operator meets before
  logging, and it is the FIRST thing they see at start-up.

  WHY IT IS BEING CONVERTED FIRST, of the 26 units still running a dialog proc.
  Three reasons, and only the third is cosmetic:

  1. It is the dialog NY4I found rendering 'Ultimo archivo de configuracion'
     with every accented letter doubled. That is a Win32 ...A entry point being
     handed UTF-8; uAnsiStr.WinAnsi patches it, but an LCL control needs no
     patch because no conversion happens at all.
  2. docs/NEW_CONTEST_DIALOG_DESIGN_BRIEF.md specifies a Tier 1 redesign --
     database-backed grid, sortable columns, type-ahead, resizable, DPI aware.
     None of that can be built against a hand-laid dialog template. This is the
     prerequisite, not the redesign.
  3. XP-era flat grey at 150% DPI, which is section 3.7 of the brief.

  WHAT THIS UNIT DELIBERATELY DOES NOT OWN. The contest knowledge stays in
  uNewContest: the ~200-line `case SelectedContest of` that decides which
  prompt and which field a contest needs is proven, contest-by-contest logic
  that no conversion should be retyping. It reaches the screen through the
  presentation methods below, so it can move across verbatim.

  THE COMMENT PANEL IS STILL A PANEL. The brief (3.5) calls it "an inert
  recessed gray panel, easily mistaken for decoration" and wants inline
  per-field guidance instead. That is a Tier 2 change and needs the contest
  factory to declare the fields; keeping the panel here means this step changes
  presentation only, which is what makes it reviewable against the old dialog.
}

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, Dialogs,
  uTR4WStrings,
  LCLStrConsts;   // RC_/TC_ captions -- see the note on SetRowLabels

type
  { The nine dynamic rows: three free-text fields then six CATEGORY-* choices.
    Built in code rather than in the designer because their labels and their
    enabled state are decided per contest, and because the count follows
    InitialCommandsSA2 in uNewContest -- duplicating it in the .lfm would give
    two places to keep in step. }
  TNewContestRow = record
     Caption: TLabel;
     Field:   TEdit;        // rows 1..3
     Choice:  TComboBox;    // rows 4..9
  end;

  { THE FORM IS PRESENTATION ONLY. uNewContest owns the contest knowledge and
    hangs these off the form's events, so the ~260 lines of
    `case SelectedContest of` move across VERBATIM rather than being retyped
    into a form unit that has no business knowing what a REF department is.
    Same shape as PossibleCallDrawProc in uMainForm, and for the same
    reason: a procedure variable, assigned by the unit that owns the rule. }
  TNewContestNotify = procedure;

  { WHAT THE OPERATOR ASKED FOR. Three different intentions all closed this
    dialog with the same Win32 result, and were told apart by WHICH control
    sent the notification -- OK meant create, a list double-click meant open
    that file, and the Latest button meant reopen the last one. A modal
    result cannot carry that, so it is named instead of inferred. }
  TNewContestChoice = (nccNone, nccCreate, nccOpenSelected, nccLatest);

  TfrmNewContest = class(TForm)
    gbExisting: TGroupBox;
    gbNew: TGroupBox;
    lstFiles: TListBox;
    btnBrowse: TButton;
    dlgOpen: TOpenDialog;
    btnLatest: TButton;
    lblMyCall: TLabel;
    edtMyCall: TEdit;
    lblContest: TLabel;
    cboContest: TComboBox;
    chkIAmIn: TCheckBox;
    pnlComment: TPanel;
    lblComment: TLabel;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleCreate(Sender: TObject);
    procedure HandleShow(Sender: TObject);
    procedure lstFilesDblClick(Sender: TObject);
    procedure btnLatestClick(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure cboContestChange(Sender: TObject);
    procedure chkIAmInChange(Sender: TObject);
    procedure FieldChanged(Sender: TObject);
  private
    FRows: array[1..9] of TNewContestRow;
    FChoice: TNewContestChoice;
    FDir: string;            { the directory lstFiles was filled from }
    FBrowsedFile: string;    { set only when Browse... was used }
    procedure BuildRows;
    function GetRowCount: integer;
  public
    { Population -- what WM_INITDIALOG used to do with CreateWindow calls. }
    procedure PopulateFiles(const aDir: string);
    procedure FillContests;
    procedure FillCategories;
    procedure ShowLatest(const aCaption: string);

    { What the caller reads back -- GetDlgItemTextA, named. }
    function  SelectedFile: string;
    function  MyCall: string;
    function  ContestName: string;
    function  ContestChosen: boolean;
    function  IAmIn: boolean;
    function  RowCaption(aRow: integer): string;
    procedure EnableOK(const aEnabled: boolean);
    procedure SetMyCall(const aCall: string);
    procedure SetRowLabel(aRow: integer; const aCaption: string);
    property  Choice: TNewContestChoice read FChoice;
    procedure ResetIAmIn;

    { The presentation surface uNewContest drives. Each one is the LCL
      equivalent of a SetDlgItemText / EnableWindow / ShowWindow pair, so the
      contest case statement calls the same shapes it always did. }
    procedure SetComment(const aText: string);
    procedure ClearRows;
    procedure EnableRow(aRow: integer; const aCaption: string);
    procedure ShowIAmIn(const aText: string);
    function  RowText(aRow: integer): string;
    property  Rows: integer read GetRowCount;
  end;

var
  frmNewContest: TfrmNewContest;

  { Assigned by uNewContest before the form is shown; nil is legal and means
    the form simply does nothing on that event. }
  OnContestChanged: TNewContestNotify = nil;
  OnIAmInChanged:   TNewContestNotify = nil;
  OnFieldsChanged:  TNewContestNotify = nil;

implementation

{$R *.lfm}

uses
  SysUtils, Graphics,
  VC;   { ContestTypeSA, tCategory*SA -- the source of truth for types }

const
  { Client coordinates of gbNew, not of the form -- the rows are its children,
    so the group box resizes them with it. }
  ROW_TOP    = 174;   // first dynamic row, below the comment panel
  ROW_HEIGHT = 30;
  ROW_LABEL_LEFT  = 12;
  ROW_LABEL_WIDTH = 140;
  ROW_FIELD_LEFT  = 160;
  ROW_FIELD_WIDTH = 200;
  FIRST_CHOICE_ROW = 4;   // rows 1..3 are free text, 4..9 are CATEGORY-* lists

function TfrmNewContest.GetRowCount: integer;
begin
   Result := High(FRows);
end;

procedure TfrmNewContest.BuildRows;
var
   i: integer;
begin
   for i := Low(FRows) to High(FRows) do
      begin
      FRows[i].Caption := TLabel.Create(Self);
      with FRows[i].Caption do
         begin
         Parent    := gbNew;
         AutoSize  := False;
         Alignment := taRightJustify;
         Left      := ROW_LABEL_LEFT;
         Top       := ROW_TOP + (i - 1) * ROW_HEIGHT + 3;
         Width     := ROW_LABEL_WIDTH;
         Height    := 18;
         Caption   := '';
         end;

      if i < FIRST_CHOICE_ROW then
         begin
         { VISIBLE, not Enabled. The Win32 rows 1..3 were created without
           WS_VISIBLE and ShowWindow'd by DisplayInitialCommand as each contest
           asked for them -- a disabled-but-present row is a different thing,
           and would show three empty boxes on every contest that wants none. }
         FRows[i].Caption.Visible := False;
         FRows[i].Field := TEdit.Create(Self);
         with FRows[i].Field do
            begin
            Parent   := gbNew;
            Left     := ROW_FIELD_LEFT;
            Top      := ROW_TOP + (i - 1) * ROW_HEIGHT;
            Width    := ROW_FIELD_WIDTH;
            Anchors  := [akTop, akLeft, akRight];
            CharCase := ecUpperCase;
            Visible  := False;
            OnChange := FieldChanged;
            end;
         end
      else
         begin
         FRows[i].Choice := TComboBox.Create(Self);
         with FRows[i].Choice do
            begin
            Parent := gbNew;
            Left   := ROW_FIELD_LEFT;
            Top    := ROW_TOP + (i - 1) * ROW_HEIGHT;
            Width   := ROW_FIELD_WIDTH;
            Anchors := [akTop, akLeft, akRight];
            Style   := csDropDownList;
            end;
         end;
      end;
end;

procedure TfrmNewContest.HandleCreate(Sender: TObject);
begin
   BuildRows;
   edtMyCall.OnChange := FieldChanged;
   FillContests;
   FillCategories;
end;

procedure TfrmNewContest.HandleShow(Sender: TObject);
begin
   // Captions come from the resourcestrings rather than the .lfm, because a
   // caption typed into a .lfm ships as English in every language -- 469 of
   // them do today (CLAUDE.md). The designer shows the English default; the
   // run time shows the operator's language.
   Caption          := TC_OPENCONFIGURATIONFILE;
   lblMyCall.Caption := RC_CALLSIGN;
   btnOK.Caption    := rsMbOK;
   btnCancel.Caption := rsMbCancel;
end;

{ THE .CFG FILES WHERE TR4W KEEPS THEM -- the one-click common case.

  This list is deliberately NOT a file browser. Two were tried first and both
  were wrong for different reasons.

  The Win32 dialog browsed with DlgDirListA / DlgDirSelectExA, a subclassed
  list box to catch Enter, and SelectParentDir for [..] -- four dialog APIs and
  a subclass, hand-rolling a file picker.  Replacing that with LCL ShellCtrls
  (a TShellTreeView driving a TShellListView) worked, but it was still a file
  picker we owned, maintained and had to lay out.

  NY4I, 2026-08-28: "is there a reason you opted to not use Lazarus'
  TOpenDialog?"  There was not.  TOpenDialog is the platform's own picker and
  arrives with traversal, type-ahead, sorting, recent places, network paths and
  keyboard conventions that would each be code here.  The one thing it cannot
  do -- show columns read from INSIDE each .cfg, which is the brief's Tier 1 --
  no filesystem browser can do either, because that needs the contest database.
  So the browser bought nothing now and was scheduled for deletion later.

  What is left is the cheap half: the files in one known directory, listed. }
procedure TfrmNewContest.PopulateFiles(const aDir: string);
var
   found: TSearchRec;
   names: TStringList;
begin
   FBrowsedFile := '';
   dlgOpen.InitialDir := aDir;
   names := TStringList.Create;
   try
      names.Sorted := True;
      if FindFirst(IncludeTrailingPathDelimiter(aDir) + '*.CFG',
                   faAnyFile, found) = 0 then
         begin
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               names.Add(found.Name);
               end;
         until FindNext(found) <> 0;
         FindClose(found);
         end;
      { ONE assignment, not one Add per row: Items proxies the widget. }
      lstFiles.Items.Assign(names);
      FDir := IncludeTrailingPathDelimiter(aDir);
   finally
      names.Free;
   end;
end;

{ ANYWHERE ELSE. The picker answers with a full path, which is why
  FBrowsedFile exists rather than trying to select something in a list that
  only holds one directory. }
procedure TfrmNewContest.btnBrowseClick(Sender: TObject);
begin
   if dlgOpen.Execute then
      begin
      FBrowsedFile := dlgOpen.FileName;
      FChoice      := nccOpenSelected;
      ModalResult  := mrOk;
      end;
end;

procedure TfrmNewContest.FillContests;
var
   ct:  ContestType;
   all: TStringList;
begin
   all := TStringList.Create;
   try
      all.Sorted := True;   { CBS_SORT, which the Win32 combo asked for }
      for ct := Succ(DUMMYCONTEST) to High(ContestType) do
         begin
         all.Add(ContestTypeSA[ct]);
         end;
      cboContest.Items.Assign(all);
   finally
      all.Free;
   end;
end;

{ The six CATEGORY-* choices. Each list is the contest-INDEPENDENT set of legal
  values for that Cabrillo header, so it is filled once and never rebuilt. }
procedure TfrmNewContest.FillCategories;
var
   a:  tCategoryAssisted;
   bd: tCategoryBand;
   m:  tCategoryMode;
   o:  tCategoryOperator;
   pw: tCategoryPower;
   tx: tCategoryTransmitter;
   i:  integer;
begin
   for a := Low(tCategoryAssisted) to High(tCategoryAssisted) do
      begin
      FRows[4].Choice.Items.Add(tCategoryAssistedSA[a]);
      end;
   for bd := Low(tCategoryBand) to High(tCategoryBand) do
      begin
      FRows[5].Choice.Items.Add(tCategoryBandSA[bd]);
      end;
   for m := Low(tCategoryMode) to High(tCategoryMode) do
      begin
      FRows[6].Choice.Items.Add(tCategoryModeSA[m]);
      end;
   for o := Low(tCategoryOperator) to High(tCategoryOperator) do
      begin
      FRows[7].Choice.Items.Add(tCategoryOperatorSA[o]);
      end;
   for pw := Low(tCategoryPower) to High(tCategoryPower) do
      begin
      FRows[8].Choice.Items.Add(tCategoryPowerSA[pw]);
      end;
   for tx := Low(tCategoryTransmitter) to High(tCategoryTransmitter) do
      begin
      FRows[9].Choice.Items.Add(tCategoryTransmitterSA[tx]);
      end;

   { CB_SETCURSEL 0 on each: a Cabrillo CATEGORY- header with no value is not
     legal, so there is no empty state to offer. }
   for i := FIRST_CHOICE_ROW to High(FRows) do
      begin
      if FRows[i].Choice.Items.Count > 0 then
         begin
         FRows[i].Choice.ItemIndex := 0;
         end;
      end;
end;

procedure TfrmNewContest.ShowLatest(const aCaption: string);
begin
   btnLatest.Caption := aCaption;
   btnLatest.Visible := aCaption <> '';
end;

{ THE FULL PATH, whichever way it was chosen: Browse answers with one already,
  and a list selection is joined to the directory it was listed from. The caller
  has nothing to prepend, which is what StartContestFromListbox got wrong when it
  expanded a name with GetFullPathNameA against the process's current directory. }
function TfrmNewContest.SelectedFile: string;
begin
   Result := FBrowsedFile;
   if Result <> '' then
      begin
      Exit;
      end;
   if (lstFiles.ItemIndex >= 0) and (lstFiles.ItemIndex < lstFiles.Items.Count) then
      begin
      Result := FDir + lstFiles.Items[lstFiles.ItemIndex];
      end;
end;

function TfrmNewContest.MyCall: string;
begin
   Result := Trim(edtMyCall.Text);
end;

function TfrmNewContest.ContestName: string;
begin
   Result := cboContest.Text;
end;

{ CB_GETCURSEL = -1, named. Text that matches no entry is not a chosen contest,
  which is why this asks the INDEX rather than the string. }
function TfrmNewContest.ContestChosen: boolean;
begin
   Result := cboContest.ItemIndex >= 0;
end;

function TfrmNewContest.IAmIn: boolean;
begin
   Result := chkIAmIn.Checked;
end;

procedure TfrmNewContest.ResetIAmIn;
begin
   chkIAmIn.Checked := False;
   chkIAmIn.Visible := False;
end;

{ The label beside a row IS the .cfg command name SaveNewContest writes, which
  is why it is read back here rather than kept in a parallel array. }
function TfrmNewContest.RowCaption(aRow: integer): string;
begin
   Result := '';
   if (aRow >= Low(FRows)) and (aRow <= High(FRows)) then
      begin
      Result := FRows[aRow].Caption.Caption;
      end;
end;

{ THE CAPTION ONLY, without showing the row.

  The six CATEGORY-* rows are permanent and permanently labelled; rows 1..3
  are labelled as a contest asks for them, by EnableRow. Built empty and
  never labelled, the categories shipped as six unexplained drop-downs --
  visible in NY4I's screenshot, 2026-08-28. }
procedure TfrmNewContest.SetRowLabel(aRow: integer; const aCaption: string);
begin
   if (aRow >= Low(FRows)) and (aRow <= High(FRows)) then
      begin
      FRows[aRow].Caption.Caption := aCaption;
      FRows[aRow].Caption.Visible := True;
      end;
end;

procedure TfrmNewContest.SetMyCall(const aCall: string);
begin
   edtMyCall.Text := aCall;
end;

procedure TfrmNewContest.EnableOK(const aEnabled: boolean);
begin
   btnOK.Enabled := aEnabled;
end;

procedure TfrmNewContest.SetComment(const aText: string);
begin
   lblComment.Caption := aText;
end;

procedure TfrmNewContest.ClearRows;
var
   i: integer;
begin
   for i := Low(FRows) to High(FRows) do
      begin
      if Assigned(FRows[i].Field) then
         begin
         FRows[i].Field.Text    := '';
         FRows[i].Field.Visible := False;
         FRows[i].Caption.Visible := False;
         end;
      FRows[i].Caption.Caption := '';
      end;
   lblComment.Caption := '';
end;

procedure TfrmNewContest.EnableRow(aRow: integer; const aCaption: string);
begin
   if (aRow < Low(FRows)) or (aRow > High(FRows)) then
      begin
      Exit;
      end;
   FRows[aRow].Caption.Caption := aCaption;
   FRows[aRow].Caption.Visible := True;
   if Assigned(FRows[aRow].Field) then
      begin
      FRows[aRow].Field.Visible := True;
      if FRows[aRow].Field.CanFocus then
         begin
         FRows[aRow].Field.SetFocus;
         end;
      end;
end;

function TfrmNewContest.RowText(aRow: integer): string;
begin
   Result := '';
   if (aRow >= Low(FRows)) and (aRow <= High(FRows)) then
      begin
      if Assigned(FRows[aRow].Field) then
         begin
         Result := FRows[aRow].Field.Text;
         end
      else if Assigned(FRows[aRow].Choice) then
         begin
         Result := FRows[aRow].Choice.Text;
         end;
      end;
end;

procedure TfrmNewContest.ShowIAmIn(const aText: string);
begin
   chkIAmIn.Caption := aText;
   chkIAmIn.Visible := aText <> '';
end;

procedure TfrmNewContest.lstFilesDblClick(Sender: TObject);
begin
   { LBN_DBLCLK used to mean ChangeDir -- descend, or open if it was a file.
     With a flat list there is nothing to descend into, so it only ever meant
     the second thing. }
   if SelectedFile <> '' then
      begin
      FChoice     := nccOpenSelected;
      ModalResult := mrOk;
      end;
end;

{ Every edit that can invalidate the OK button routes here; uNewContest owns
  the rule (BeginNewContest) because it knows what a good callsign is. }
procedure TfrmNewContest.FieldChanged(Sender: TObject);
begin
   if Assigned(OnFieldsChanged) then
      begin
      OnFieldsChanged;
      end;
end;

procedure TfrmNewContest.btnLatestClick(Sender: TObject);
begin
   FChoice := nccLatest;
   ModalResult := mrOk;
end;

procedure TfrmNewContest.btnOKClick(Sender: TObject);
begin
   FChoice := nccCreate;
   ModalResult := mrOk;
end;

procedure TfrmNewContest.cboContestChange(Sender: TObject);
begin
   if Assigned(OnContestChanged) then
      begin
      OnContestChanged;
      end;
end;

procedure TfrmNewContest.chkIAmInChange(Sender: TObject);
begin
   if Assigned(OnIAmInChanged) then
      begin
      OnIAmInChanged;
      end;
end;

end.
