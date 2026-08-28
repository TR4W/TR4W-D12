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
  Classes, Controls, Forms, StdCtrls, ExtCtrls,
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

  TfrmNewContest = class(TForm)
    lblFiles: TLabel;
    lstFiles: TListBox;
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
    procedure btnOKClick(Sender: TObject);
    procedure cboContestChange(Sender: TObject);
    procedure chkIAmInChange(Sender: TObject);
  private
    FRows: array[1..9] of TNewContestRow;
    procedure BuildRows;
    function GetRowCount: integer;
  public
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

implementation

{$R *.lfm}

uses
  SysUtils, Graphics;

const
  ROW_TOP    = 148;   // first dynamic row, below the comment panel
  ROW_HEIGHT = 24;
  ROW_LABEL_LEFT  = 272;
  ROW_LABEL_WIDTH = 176;
  ROW_FIELD_LEFT  = 456;
  ROW_FIELD_WIDTH = 152;
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
         Parent    := Self;
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
         FRows[i].Field := TEdit.Create(Self);
         with FRows[i].Field do
            begin
            Parent   := Self;
            Left     := ROW_FIELD_LEFT;
            Top      := ROW_TOP + (i - 1) * ROW_HEIGHT;
            Width    := ROW_FIELD_WIDTH;
            CharCase := ecUpperCase;
            Enabled  := False;
            end;
         end
      else
         begin
         FRows[i].Choice := TComboBox.Create(Self);
         with FRows[i].Choice do
            begin
            Parent := Self;
            Left   := ROW_FIELD_LEFT;
            Top    := ROW_TOP + (i - 1) * ROW_HEIGHT;
            Width  := ROW_FIELD_WIDTH;
            Style  := csDropDownList;
            end;
         end;
      end;
end;

procedure TfrmNewContest.HandleCreate(Sender: TObject);
begin
   BuildRows;
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
         FRows[i].Field.Enabled := False;
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
   if Assigned(FRows[aRow].Field) then
      begin
      FRows[aRow].Field.Enabled := True;
      FRows[aRow].Field.SetFocus;
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
   // placeholder: the directory walk still lives in uNewContest.ChangeDir
end;

procedure TfrmNewContest.btnLatestClick(Sender: TObject);
begin
   ModalResult := mrYes;   // "resume the last contest" -- the caller reads this
end;

procedure TfrmNewContest.btnOKClick(Sender: TObject);
begin
   ModalResult := mrOK;
end;

procedure TfrmNewContest.cboContestChange(Sender: TObject);
begin
   // the contest case statement in uNewContest hangs off this
end;

procedure TfrmNewContest.chkIAmInChange(Sender: TObject);
begin
   // ditto
end;

end.
