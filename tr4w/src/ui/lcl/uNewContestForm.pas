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
     handed UTF-8; utils_text.WinAnsi patches it, but an LCL control needs no
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
  Classes, Controls, Forms, StdCtrls, ExtCtrls, Dialogs, Graphics,
  uTR4WStrings,
  LCLStrConsts,   // RC_/TC_ captions -- see the note on SetRowLabels
  VC,             (* TContestHandle -- the identity each contest line holds (M9b; a handle since Q108 S2) *)
  uContestChoices; (* TContestChoices -- the list, its order and its search (Q103) *)

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
    pnlContestPick: TPanel;
    lblContest: TLabel;
    edtContestFilter: TEdit;
    lstContests: TListBox;
    chkShowInactive: TCheckBox;
    pnlDetails: TPanel;
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
    procedure edtContestFilterChange(Sender: TObject);
    procedure edtContestFilterKeyDown(Sender: TObject; var Key: Word;
                                      Shift: TShiftState);
    procedure lstContestsSelectionChange(Sender: TObject; User: boolean);
    procedure chkShowInactiveChange(Sender: TObject);
    procedure chkIAmInChange(Sender: TObject);
    procedure FieldChanged(Sender: TObject);
  private
    FRows: array[1..9] of TNewContestRow;
    (* EVERY CONTEST THE DIALOG OFFERS, in order, with its caption -- built
       once (FillContests) and owned here. The search narrows what is SHOWN;
       it never rebuilds this. *)
    FChoices: TContestChoices;
    (* WHICH CONTEST EACH ROW OF lstContests IS -- Q103. Filled in the same
       pass as the list's Items (ShowMatchingContests), so row i is
       FShown[i]. A typed field the view owns, never the caption read back
       and never an Objects[] cast: the caption is the display name, and the
       contest is the identity. *)
    FShown: array of TContestHandle;
    (* The contest OnContestChanged was last told about. The one place that
       decides "the choice changed" (NotifyContestIfChanged) compares against
       it, so a selection event the widget set raises twice, or raises for a
       refill that kept the same contest, does not clear what the operator
       has typed into the rows. *)
    FNotified: TContestHandle;
    (* True while ShowMatchingContests replaces the Items: a selection event
       raised in the middle describes a half-built list. *)
    FFilling: boolean;
    FChoice: TNewContestChoice;
    FDir: string;            { the directory lstFiles was filled from }
    FBrowsedFile: string;    { set only when Browse... was used }
    { The designed geometry of the bottom of gbExisting, captured once so
      LayoutLatestButton is idempotent and survives a resize. See it. }
    FLatestMargin: integer;      { gbExisting client bottom -> button bottom }
    FLatestHeight: integer;      { the designed height, used as a floor }
    FGapBrowse:    integer;      { Browse bottom -> Latest top }
    FGapList:      integer;      { list bottom -> Browse top }
    FGeometry:     boolean;      { the four above have been captured }
    procedure BuildRows;
    procedure CaptureGeometry;

    procedure ApplyMinimumSize;
    procedure LayoutLatestButton;
    procedure ReassertLatestCaption;
    function  WrappedTextHeight(const aText: TCaption; const aWidth: integer): integer;
    function  WidestLine(const aText: TCaption): integer;
    function  WidestText(aFont: TFont; aTexts: TStrings): integer;
    function  GetRowCount: integer;
    procedure ShowMatchingContests;
    procedure NotifyContestIfChanged;
    procedure SizeContestList;
  public
    destructor Destroy; override;
    { Population -- what WM_INITDIALOG used to do with CreateWindow calls. }
    procedure PopulateFiles(const aDir: string);
    procedure FillContests;
    procedure FillCategories;
    procedure ShowLatest(const aCaption: string);

    { What the caller reads back -- GetDlgItemTextA, named. }
    function  SelectedFile: string;
    function  MyCall: string;
    function  ContestName: string;
    function  SelectedContest: TContestHandle;
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

(* THE DIALOG'S TITLE: the program name and version, then what it is for.
   TC_OPENCONFIGURATIONFILE begins with ' - ' because it was written to FOLLOW
   the version (D7 did exactly this), so it must never be assigned bare -- that
   showed NY4I " - Open configuration file or start a new contest" with no way
   to tell which build he was running. HandleShow is the only writer. *)
function NewContestFormCaption: string;

implementation

{$R *.lfm}

uses
  SysUtils,
  LCLType,          (* VK_DOWN, SM_CXVSCROLL *)
  LCLIntf,          (* GetSystemMetrics -- the LCL's, on every widget set *)
  uSettingsModel,   // the Cabrillo category settings and their spellings
  MainUnit,   // logger
  Log4D,
  Version,    (* TR4W_CURRENTVERSION -- the title names the build *)
  uAppStrings,      (* SNewContestContestLabel, SNewContestSearchHint,
                       SNewContestShowInactive *)
  uContestRegistry; (* ContestId -- the chosen contest's token, Q108 S2 *)

function NewContestFormCaption: string;
begin
   Result := TR4W_CURRENTVERSION + TC_OPENCONFIGURATIONFILE;
end;

const
  (* Client coordinates of pnlDetails, not of the form -- the rows are its
     children, so the panel resizes them with it. pnlDetails is the right-hand
     column of gbNew since Q103: the contest search took the left one, and the
     CONTEST row that stood under MY CALL went with it, which is why the rows
     start 36 higher than they did. *)
  ROW_TOP    = 138;   // first dynamic row, below the comment panel
  ROW_HEIGHT = 30;
  { THE LABEL COLUMN IS SIZED BY ITS LONGEST MEMBER, which is
    CATEGORY-TRANSMITTER. At 140 it fitted that label EXACTLY, so the text ran
    up against the left edge with nothing to spare and read as though it were
    clipped (NY4I, 2026-08-31). Widened by 20 and the column started 4 further
    left, which buys room for a longer translation of the same word rather than
    just un-crowding the English.

    The three move together: the field column starts one gap right of where the
    label column ends, and ROW_FIELD_WIDTH is only the DESIGN width -- the
    fields are akRight-anchored and stretch with the form. }
  ROW_LABEL_LEFT  = 8;
  ROW_LABEL_WIDTH = 160;
  ROW_FIELD_LEFT  = 176;
  ROW_FIELD_WIDTH = 180;
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
         Parent    := pnlDetails;
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
            Parent   := pnlDetails;
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
            Parent := pnlDetails;
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
   FNotified := NoContest;
   FillContests;
   SizeContestList;
   FillCategories;
end;

destructor TfrmNewContest.Destroy;
begin
   FreeAndNil(FChoices);
   inherited Destroy;
end;

procedure TfrmNewContest.HandleShow(Sender: TObject);
begin
   // Captions come from the resourcestrings rather than the .lfm, because a
   // caption typed into a .lfm ships as English in every language -- 469 of
   // them do today (CLAUDE.md). The designer shows the English default; the
   // run time shows the operator's language.
   Caption          := NewContestFormCaption;
   lblMyCall.Caption := RC_CALLSIGN;
   lblContest.Caption := SNewContestContestLabel;
   edtContestFilter.TextHint := SNewContestSearchHint;
   chkShowInactive.Caption := SNewContestShowInactive;
   btnOK.Caption    := rsMbOK;
   btnCancel.Caption := rsMbCancel;

   { THIS IS THE CALL THAT SIZES THE BUTTON. The one in ShowLatest cannot.

     A LABEL CANNOT MEASURE ITSELF UNTIL ITS FORM IS SHOWN, and PrepareForm
     captions the button beforehand. Measured on 2026-08-31, the same caption
     on the same probe at the same width:

         from PrepareForm, form not yet shown   33 px   (one line)
         from here, form shown                  61 px   (three lines)

     So the earlier pass computes a single line however long the text is,
     clamps to the designed height and changes nothing. It is left in place
     because it still does the other half of the job -- showing or hiding the
     button and handing its space back to the file list -- and because deleting
     it would leave the dialog unsized for anything that captions the button
     while it is already open.

     NOTE WHAT THIS IS NOT. The first attempt at this assumed the akBottom
     anchors were reverting the geometry on show; the log said Top and Height
     were untouched at 388/44 both times, because nothing had ever grown them.
     Do not reintroduce an anchor workaround.

     Calling it twice is safe: every value it writes derives from the geometry
     captured once from the .lfm and from the current caption, never from the
     controls' present Top and Height. }
   ReassertLatestCaption;
   LayoutLatestButton;
   ApplyMinimumSize;

   if logger.IsDebugEnabled then
      begin
      logger.Debug('[NewContest] minimum height: pnlDetails client=%d, last row bottom=%d, ' +
                   'form Height=%d -> MinHeight=%d',
                   [pnlDetails.ClientHeight,
                    FRows[High(FRows)].Choice.Top + FRows[High(FRows)].Choice.Height,
                    Height, Constraints.MinHeight]);
      end;
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
   (* FindFirst takes a RawByteString, so a pattern built inline narrows
      implicitly -- and there are two call sites now, not one. Built as a
      string and converted EXPLICITLY at the call: a directory path is
      filesystem bytes either way, and saying so beats the compiler doing it
      silently. *)
   base: string;
   pat: string;
begin
   base := IncludeTrailingPathDelimiter(aDir);
   FBrowsedFile := '';
   dlgOpen.InitialDir := aDir;
   names := TStringList.Create;
   try
      names.Sorted := True;
      (* THE LOGS ARE .db FILES NOW, one per contest, flat in one directory.

         A .CFG IS STILL LISTED WHEN IT HAS NO .db BESIDE IT, and that is the
         migration path rather than an oversight: an operator upgrading has
         contests that exist only as a .cfg and a .TRW, and refusing to show
         them would strand every log they already have. Opening one migrates it
         -- uLogStore builds the database from the binary log on first open --
         after which the .db exists and the .cfg stops being listed, because the
         same contest must not appear twice.

         names is Sorted, so the two passes interleave by name rather than
         showing every .db and then every .cfg. *)
      pat := base + '*.db';
      if FindFirst(RawByteString(pat), faAnyFile, found) = 0 then
         begin
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               names.Add(found.Name);
               end;
         until FindNext(found) <> 0;
         FindClose(found);
         end;

      pat := base + '*.CFG';
      if FindFirst(RawByteString(pat), faAnyFile, found) = 0 then
         begin
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               if not FileExists(base + ChangeFileExt(found.Name, '.db')) then
                  begin
                  names.Add(found.Name);
                  end;
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

(* THE CONTESTS, BY THEIR DISPLAY NAMES, ACTIVE FIRST -- M9b, 2026-10-02;
  A SEARCH OVER A PLAIN LIST SINCE Q103, 2026-10-19.

  NY4I: "i would like the display name in the drop down", and then, of
  DXLog's and N1MM's grouped lists, "search". The ORDER, the inactive mark and
  the search rule are uContestChoices' (unit tested there); this builds that
  list once and shows the rows the search keeps.

  A PLAIN TListBox UNDER A TEdit, NOT A SELF-FILTERING DROP-DOWN. A combo that
  narrows its own Items while the operator types fights the control -- its
  drop-down, its autocomplete and its ItemIndex all assume the Items hold
  still. Two native controls, each doing what it was built for, need no
  owner-draw and no help.

  THE LIST IS NOT Sorted (.lfm), and must not be: a sorted list reorders its
  Items behind FShown's back, and row i would stop being FShown[i]. *)
procedure TfrmNewContest.FillContests;
begin
   FreeAndNil(FChoices);
   FChoices := TContestChoices.Create;
   ShowMatchingContests;
end;

(* THE ROWS THE SEARCH KEEPS, and the selection carried across the refill.

  A CONTEST THAT IS STILL SHOWN STAYS CHOSEN. Narrowing "QSO" to "QSO P" must
  not clear the rows the operator has already filled in for the party they
  picked, so the contest is found again by its identity in the new rows --
  never by its old row number, which the refill has just changed.

  A CONTEST THE SEARCH HIDES IS UN-CHOSEN, and OnContestChanged hears it: OK
  disables (ContestChosen is False) and the previous contest's prompts are
  cleared. OK can never act on a contest the operator can no longer see.

  ONE MATCH IS NOT CHOSEN FOR THE OPERATOR. Choosing a contest puts up its
  prompts and clears the rows, and doing that because a search happened to
  narrow to one line -- possibly while the operator is still typing -- would
  be a choice they did not make. Down arrow or a click chooses it.

  ONE Assign, not one Add per row: Items proxies the widget. FFilling keeps a
  selection event raised mid-refill from reading a half-built list; the one
  notification goes out afterwards, and only if the contest changed. *)
procedure TfrmNewContest.ShowMatchingContests;
var
   was: TContestHandle;
   rows: TContestChoiceIndexes;
   captions: TStringList;
   keep, i: integer;
begin
   if FChoices = nil then
      begin
      Exit;
      end;

   was  := SelectedContest;
   rows := FChoices.Matching(UTF8Decode(edtContestFilter.Text),
                             chkShowInactive.Checked);
   keep := -1;

   captions := TStringList.Create;
   try
      SetLength(FShown, Length(rows));
      for i := 0 to High(rows) do
         begin
         FShown[i] := FChoices.Contest[rows[i]];
         (* UTF-8, stated: the LCL's strings are UTF-8 AnsiStrings and a
            display name is the sponsor's, not necessarily ASCII. *)
         captions.Add(UTF8Encode(FChoices.Caption[rows[i]]));
         if FShown[i] = was then
            begin
            keep := i;
            end;
         end;

      FFilling := True;
      try
         lstContests.Items.Assign(captions);
         lstContests.ItemIndex := keep;
      finally
         FFilling := False;
      end;
   finally
      captions.Free;
   end;

   NotifyContestIfChanged;
end;

(* THE ONE PLACE THAT DECIDES THE CHOICE CHANGED. Every route -- a click, an
  arrow key in the list, Down from the search box, a search that hides the
  chosen contest -- ends here, and OnContestChanged runs only when the contest
  is a different one. uNewContest's handler clears the rows, so running it for
  an unchanged contest would throw away what the operator typed. *)
procedure TfrmNewContest.NotifyContestIfChanged;
var
   current: TContestHandle;
begin
   current := SelectedContest;
   if current = FNotified then
      begin
      Exit;
      end;
   FNotified := current;
   if Assigned(OnContestChanged) then
      begin
      OnContestChanged;
      end;
end;

(* EVERY NAME IN FULL -- Q52, NY4I 2026-10-16: the friendly name in full,
  sized at run time.

  MEASURED, NOT TYPED. The widest caption the list can ever hold, in the
  list's own font, plus the list's frame, its text inset and a vertical
  scroll bar (GetSystemMetrics -- the LCL's, which answers on every widget
  set). A typed width is right for one font at one DPI in one language; this
  is right for the one in use.

  THE COLUMN ONLY GROWS. Its designed width in the .lfm is the floor; when a
  name needs more, the column and the form widen by the same amount, so the
  right-hand column keeps its width and nothing else moves. The minimum width
  grows with it, or a resize could squeeze the names out again.

  NO WIDER THAN THE SCREEN'S WORK AREA. Past that the column stops growing
  and the list scrolls sideways (ScrollWidth) rather than clipping a name.

  Measured from FChoices, ALL the captions, not the rows on show: the column
  is sized once, and a search must not make the dialog jump. *)
procedure TfrmNewContest.SizeContestList;
const
   (* The list's frame and the inset of its text from the frame, both sides
      together. Not measurable without a shown handle; generous rather than
      tight, because a pixel short clips the last letter. *)
   LIST_CHROME = 16;
var
   captions: TStringList;
   widest, need, grow, room, i: integer;
begin
   if FChoices = nil then
      begin
      Exit;
      end;

   captions := TStringList.Create;
   try
      for i := 0 to FChoices.Count - 1 do
         begin
         captions.Add(UTF8Encode(FChoices.Caption[i]));
         end;
      widest := WidestText(lstContests.Font, captions);
   finally
      captions.Free;
   end;

   lstContests.ScrollWidth := widest + LIST_CHROME;

   (* What the panel must be: the list's text, its chrome and scroll bar,
      plus whatever the panel keeps around the list (its BorderSpacing). *)
   need := widest + LIST_CHROME + GetSystemMetrics(SM_CXVSCROLL) +
           (pnlContestPick.Width - lstContests.Width);
   grow := need - pnlContestPick.Width;

   room := Screen.WorkAreaWidth - Width;
   if grow > room then
      begin
      grow := room;
      end;

   if grow > 0 then
      begin
      pnlContestPick.Width  := pnlContestPick.Width + grow;
      Width                 := Width + grow;
      Constraints.MinWidth  := Constraints.MinWidth + grow;
      end;

   if logger.IsDebugEnabled then
      begin
      logger.Debug('[NewContest] contest list: widest name %d px, column needs %d, ' +
                   'grew %d -> column %d, form %d',
                   [widest, need, grow, pnlContestPick.Width, Width]);
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

{ HOW TALL THIS TEXT IS once wrapped into aWidth, in the button's own font.

  MEASURED WITH A TLabel RATHER THAN TEXT METRICS. The LCL already knows how it
  breaks a caption into lines; a hand-rolled word-wrap here would be a SECOND
  opinion, free to disagree with the one that actually paints -- and the failure
  mode of disagreeing is the clipped text this routine exists to prevent.
  Constraints.MaxWidth with AutoSize and WordWrap is the LCL's own idiom for
  "how tall is this, wrapped". The probe is never shown and never parented into
  the visible layout beyond the measurement.

  ShowAccelChar is left at its default because the caption carries one: the
  '&' in 'Alt+&A' is drawn as an underline, not as a character, and measuring
  it as a character would over-estimate by one glyph.

  THE PROBE MUST BE VISIBLE, and that is the whole trick. The LCL does not
  auto-size a control that is not visible -- AutoSize is skipped, Height keeps
  the default, and the measurement comes back as a SINGLE LINE no matter what
  the caption says. Measured on 2026-08-31: an invisible probe reported 17px
  for a caption that renders three lines, so the button never grew and the fix
  looked like it had done nothing at all.

  Nothing flashes on screen. The probe is created, measured and freed without
  the message loop turning, so it never gets the chance to paint.

  ORDER MATTERS TOO: WordWrap and the width constraint go on BEFORE AutoSize
  and the caption, so the first size it computes is already the wrapped one. }
function TfrmNewContest.WrappedTextHeight(const aText: TCaption;
                                          const aWidth: integer): integer;
var
   probe: TLabel;
begin
   probe := TLabel.Create(nil);
   try
      probe.Parent               := Self;
      probe.Font                 := btnLatest.Font;
      probe.WordWrap             := True;
      probe.Constraints.MaxWidth := aWidth;
      probe.Width                := aWidth;
      probe.AutoSize             := True;
      probe.Caption              := aText;
      probe.AdjustSize;
      Result                     := probe.Height;
   finally
      probe.Free;
   end;
end;

{ THE WIDEST LINE IN A CAPTION, IN PIXELS.

  A COMPANION TO WrappedTextHeight, AND THE HALF THAT WAS MISSING. That routine
  answers "how tall would this be IF IT WRAPPED", and the eliding loop below
  used its answer alone -- so a caption was shortened only when it was too TALL
  for the space, never when a single line was too WIDE for the button.

  ON WINDOWS THAT WAS ENOUGH, BECAUSE THE BUTTON REALLY DOES WRAP.
  TWin32WSButton adds BS_MULTILINE (win32wsstdctrls.pp:2152), so a long line
  becomes two and the height check catches it. GTK has no counterpart: a
  GtkButton's label does not wrap, so the line simply runs out of the button.
  NY4I, Linux Mint 2026-09-09, with a screenshot: "Notice how we overran the
  button with the text instead of wrapping."

  So the width is measured directly and the loop below tests both. A TBitmap
  canvas rather than the form's: it needs no handle and no parent, and it
  cannot be affected by whatever the form last painted with.

  LINE BY LINE, because the caption is deliberately two lines -- a label and a
  path -- and the width of the whole string is not a number that means
  anything. }
function TfrmNewContest.WidestLine(const aText: TCaption): integer;
var
   lines: TStringList;
begin
   lines := TStringList.Create;
   try
      lines.Text := aText;
      Result := WidestText(btnLatest.Font, lines);
   finally
      lines.Free;
   end;
end;

(* THE WIDEST OF SEVERAL STRINGS, IN PIXELS, IN aFont -- the measurement
  WidestLine always made, lifted out when the contest list (Q52) became its
  second caller. *)
function TfrmNewContest.WidestText(aFont: TFont; aTexts: TStrings): integer;
var
   probe: TBitmap;
   i, w:  integer;
begin
   Result := 0;

   probe := TBitmap.Create;
   try
      probe.SetSize(1, 1);
      probe.Canvas.Font := aFont;

      for i := 0 to aTexts.Count - 1 do
         begin
         w := probe.Canvas.TextWidth(aTexts[i]);
         if w > Result then
            begin
            Result := w;
            end;
         end;
   finally
      probe.Free;
   end;
end;

{ THE FORM MAY NOT SHRINK PAST ITS LAST CATEGORY ROW.

  The nine rows are built in code, akTop-anchored, so they do NOT move when the
  form is resized -- gbNew simply clips them. Constraints.MinHeight in the .lfm
  was 460 against a designed 524, and the difference is almost exactly two rows:
  at the minimum size CATEGORY-POWER and CATEGORY-TRANSMITTER were both cut off
  with nothing to say so (NY4I, 2026-08-31).

  DERIVED, NOT TYPED, and that is the point. The obvious fix is to type a bigger
  number into the .lfm, which requires knowing whether a form's Height includes
  its caption and borders -- and being wrong there is off by exactly one row,
  which looks like a rounding error rather than a mistake. This asks the form
  what it currently has instead: SLACK is the unused space left inside
  pnlDetails (gbNew's right-hand column) below the last row, and the form may give up precisely that much and no more.

  Both terms are read at the same moment, so the frame size cancels and never
  has to be known. It is also self-maintaining: add a tenth row and the minimum
  grows on its own. }
procedure TfrmNewContest.ApplyMinimumSize;
var
   last : TControl;
   slack: integer;
begin
   last := FRows[High(FRows)].Choice;
   if last = nil then
      begin
      Exit;
      end;

   slack := pnlDetails.ClientHeight - (last.Top + last.Height);
   if slack > 0 then
      begin
      Constraints.MinHeight := Height - slack;
      end;
end;

{ The designed spacing at the bottom of gbExisting, read ONCE from the .lfm.

  CAPTURED RATHER THAN HARD-CODED so the designer stays the single source of
  the layout -- move a control in the .lfm and this follows. Captured ONCE
  because LayoutLatestButton rewrites Top and Height, so reading them again
  afterwards would measure this routine's own output and drift a little further
  every time the button is re-captioned.

  The margin is held against the group box's CLIENT HEIGHT, not as an absolute
  Top, because all three controls are akBottom-anchored and move when the form
  is resized. }
procedure TfrmNewContest.CaptureGeometry;
begin
   if FGeometry then
      begin
      Exit;
      end;
   FLatestMargin := gbExisting.ClientHeight - (btnLatest.Top + btnLatest.Height);
   FLatestHeight := btnLatest.Height;
   FGapBrowse    := btnLatest.Top - (btnBrowse.Top + btnBrowse.Height);
   FGapList      := btnBrowse.Top - (lstFiles.Top + lstFiles.Height);
   FGeometry     := True;
end;

{ SIZE THE BUTTON TO ITS TEXT, and take the difference out of the file list.

  The caption is two logical lines -- the label and then the full path -- and
  the path is as long as the operator's directory names make it. It was a fixed
  44px in the .lfm, which fits exactly two rendered lines, so a path that wrapped
  to a third was silently clipped (NY4I, 2026-08-31: a path ending in
  \2026 wwdigi ny4i\wwdigi.cfg lost its last line).

  GROWS UPWARD, because the button is anchored to the bottom of the group box
  and the operator's eye is on it there. Browse moves up by the same amount and
  the list absorbs it.

  THE LIST HAS A FLOOR. Growth is capped so the file list keeps MIN_LIST pixels
  -- an unbounded path would otherwise consume the very list this dialog exists
  to show. When the cap bites, the PATH is elided in its middle rather than
  clipped at its end: the drive and the file name are the two parts that
  identify it, and they are the two parts a right-clip destroys.

  IDEMPOTENT: every value is derived from the captured design geometry and the
  current caption, never from the controls' present Top and Height. }
procedure TfrmNewContest.LayoutLatestButton;
const
   { A button insets its text from its own edges; measure against the inside. }
   TEXT_INSET = 16;
   MIN_LIST   = 120;
   ELIDE      = '...';
var
   { TCaption, NOT string. In this unit `string` is UnicodeString while an LCL
     caption is TCaption, so a plain string local converts on every read and
     every write -- four narrowing warnings for text that never leaves the
     widget set. Hold the caption in the type the control uses. }
   text, label_, path: TCaption;
   { The ellipsis as a TCaption too. As a bare string constant it is
     UnicodeString here, which promotes the whole concatenation and then
     narrows it back on the way into text -- three warnings for three dots. }
   dots: TCaption;
   avail, needed, capHeight, bottom, keep, brk: integer;
   inner, widest: integer;
begin
   (* INITIALISED, because the debug line at the bottom reads both whatever
     branch ran, and the "no latest file" branch sets neither. NY4I's log
     carried `needed=1587725264` -- a stack value formatted as a measurement,
     which is worse than no figure at all: it looks like an answer. *)
   needed := 0;
   avail  := 0;
   widest := 0;
   inner  := 0;

   CaptureGeometry;

   bottom := gbExisting.ClientHeight - FLatestMargin;

   if not btnLatest.Visible then
      begin
      { No latest file: hand the space back rather than leaving a hole. }
      capHeight := 0;
      end
   else
      begin
      avail := bottom - FGapBrowse - btnBrowse.Height - FGapList
                      - lstFiles.Top - MIN_LIST;

      text   := btnLatest.Caption;
      inner  := btnLatest.Width - TEXT_INSET;
      needed := WrappedTextHeight(text, inner) + TEXT_INSET;
      widest := WidestLine(text);
      if logger.IsDebugEnabled then
         begin
         logger.Debug('[NewContest] measured "%s" at width %d: %d px',
                      [StringReplace(text, #13#10, ' | ', [rfReplaceAll]),
                       btnLatest.Width - TEXT_INSET, needed]);
         end;

      { STILL TOO LONG FOR THE WHOLE ALLOWANCE: shorten the PATH, and only the
        path.  The caption is 'Last Contest, Alt+&A:' + a line break + the
        file name, and eliding into the label would damage the one part that
        says what the button does. Everything after the last line break is the
        path; if there is no line break there is nothing to protect and the
        whole caption is the path.

        Shortened from the MIDDLE: the drive and the file name identify a path,
        and they are exactly the two parts a right-hand clip destroys. Halved
        each pass, so this converges in a handful of passes on any real path,
        and it runs once per show. }
      dots   := ELIDE;
      brk    := LastDelimiter(#10, text);
      label_ := Copy(text, 1, brk);
      path   := Copy(text, brk + 1, MaxInt);
      keep   := Length(path);

      (* TOO TALL *OR* TOO WIDE. The height test alone was a Windows test: a
        button there wraps, so an over-long path became a second line and grew
        the height. Nothing wraps on GTK, so the line ran off the end of the
        button and the height never noticed. *)
      while ((needed > avail) or (widest > inner)) and
            (keep > Length(ELIDE) + 8) do
         begin
         keep := keep div 2;
         text := label_ + Copy(path, 1, keep div 2) + dots +
                 Copy(path, Length(path) - (keep - keep div 2) + 1, MaxInt);
         needed := WrappedTextHeight(text, inner) + TEXT_INSET;
         widest := WidestLine(text);
         end;
      if text <> btnLatest.Caption then
         begin
         { The full path stays reachable even when it cannot be shown. }
         btnLatest.Hint     := btnLatest.Caption;
         btnLatest.ShowHint := True;
         btnLatest.Caption  := text;
         end;

      capHeight := needed;
      if capHeight < FLatestHeight then
         begin
         capHeight := FLatestHeight;
         end;
      if capHeight > avail then
         begin
         capHeight := avail;
         end;

      btnLatest.Height := capHeight;
      btnLatest.Top    := bottom - capHeight;
      capHeight        := capHeight + FGapBrowse;
      end;

   btnBrowse.Top   := bottom - capHeight - btnBrowse.Height;
   lstFiles.Height := btnBrowse.Top - FGapList - lstFiles.Top;

   if logger.IsDebugEnabled then
      begin
      logger.Debug('[NewContest] latest button: client=%d bottom=%d needed=%d ' +
                   'avail=%d widest=%d inner=%d -> Top=%d Height=%d ' +
                   '(browse Top=%d, list Height=%d)',
                   [gbExisting.ClientHeight, bottom, needed, avail,
                    widest, inner,
                    btnLatest.Top, btnLatest.Height, btnBrowse.Top,
                    lstFiles.Height]);
      end;
end;

(* COCOA ONLY LEARNS A CAPTION IS MULTI-LINE WHEN IT ARRIVES THROUGH SetText.

  TCocoaWSButton.SetText switches an NSButton to NSRegularSquareBezelStyle when
  the text contains a line ending; TCocoaWSButtonUtil.allocButton, which is the
  path a caption takes when it was assigned BEFORE the handle existed, does not.
  A rounded NSButton is a fixed-height single-line control, so a second line --
  which here is the whole point, it is the file name -- is simply not drawn.

  And ShowLatest runs from PrepareForm, which is before ShowModal, so this form
  has no handle yet and every caption it sets takes exactly that path.  Nor can
  it be fixed by assigning the same text again later: TControl.RealSetText exits
  when the value has not changed, so the widget set would never hear about it.

  Hence the empty assignment.  It runs from HandleShow, before the first paint,
  and on Win32 and GTK it is two cheap SetText calls that change nothing. *)
procedure TfrmNewContest.ReassertLatestCaption;
var
   want: TCaption;
begin
   if not btnLatest.HandleAllocated then
      begin
      Exit;
      end;

   want := btnLatest.Caption;
   if want = '' then
      begin
      Exit;
      end;

   btnLatest.Caption := '';
   btnLatest.Caption := want;
end;

procedure TfrmNewContest.ShowLatest(const aCaption: string);
begin
   btnLatest.ShowHint := False;
   btnLatest.Hint     := '';
   btnLatest.Caption  := aCaption;
   btnLatest.Visible  := aCaption <> '';
   LayoutLatestButton;
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

(* THE CHOSEN CONTEST, from the row's typed identity -- M9b, a list row since
  Q103. NoContest when none is chosen, which no row holds.

  AN INACTIVE ROW IS NOT A CHOICE -- Q59, NY4I 2026-10-19. Listed when "Show
  inactive contests" is ticked, it can still be selected like any row (a
  TListBox has no per-row enable, and fighting the selection from inside its
  own change event is not the native way), but it is not a contest a NEW
  contest can be: SelectedContest answers NoContest for it, so ContestChosen
  is False, OK stays disabled and no prompts are shown. Every route that asks
  "which contest" -- uNewContest, ContestName, NotifyContestIfChanged, the
  refill that keeps a choice -- comes through here, so this is the one place
  the rule needs to live. *)
function TfrmNewContest.SelectedContest: TContestHandle;
var
   i: integer;
begin
   Result := NoContest;
   i := lstContests.ItemIndex;
   if (i >= 0) and (i <= High(FShown)) then
      begin
      if ContestCanStartNew(FShown[i]) then
         begin
         Result := FShown[i];
         end;
      end;
end;

(* THE CONTEST'S TOKEN -- the spelling the CONTEST command and the log's file
  name have always carried, NOT the caption: the line shows the display name
  since M9b, and what is written must not move with it. '' when none is
  chosen, as the empty combo text was. *)
function TfrmNewContest.ContestName: string;
begin
   Result := '';
   if ContestChosen then
      begin
      Result := ContestId(SelectedContest);
      end;
end;

(* A ROW IS SELECTED, asked through the identity it carries -- so a search
  that hides the chosen contest (ShowMatchingContests clears the row) is "no
  contest" here too, and OK cannot go ahead with one the operator cannot see. *)
function TfrmNewContest.ContestChosen: boolean;
begin
   Result := SelectedContest <> NoContest;
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

{ Forget what the PREVIOUS contest asked for.

  ROWS 1..3 ONLY.  This used to blank `FRows[i].Caption.Caption` for every row,
  including the six CATEGORY-* rows -- which are labelled exactly ONCE, by
  uNewContest's setup loop, and are supposed to stay labelled.  Selecting a
  contest calls ClearFields, so the moment an operator picked a contest that
  asks a question the six drop-downs lost their captions and stood there
  unexplained (NY4I, screenshot, 2026-09-01).

  THAT IS THE SECOND TIME THIS EXACT SYMPTOM HAS SHIPPED.  The first was the
  categories never being labelled at all (NY4I, 2026-08-28), fixed by adding
  SetRowLabel -- whose own comment says "the six CATEGORY-* rows are permanent
  and permanently labelled".  ClearRows was three lines away and quietly
  contradicted it.  A permanent label and a routine that clears everything are
  a contradiction that no compiler and no lint can see; the loop now says which
  rows it owns. }
procedure TfrmNewContest.ClearRows;
var
   i: integer;
begin
   for i := Low(FRows) to FIRST_CHOICE_ROW - 1 do
      begin
      if Assigned(FRows[i].Field) then
         begin
         FRows[i].Field.Text      := '';
         FRows[i].Field.Visible   := False;
         end;
      FRows[i].Caption.Caption := '';
      FRows[i].Caption.Visible := False;
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

(* The search text changed: show the rows it keeps. *)
procedure TfrmNewContest.edtContestFilterChange(Sender: TObject);
begin
   ShowMatchingContests;
end;

(* DOWN ARROW LEAVES THE SEARCH BOX FOR THE LIST, as it does in every
  search-over-a-list the operator has used. With no row chosen it chooses the
  first, so one key both moves and selects; with one chosen it only moves
  focus, and the next Down is the list's own.

  ENTER NEEDS NOTHING HERE: OK is the form's Default button, so Enter in the
  search box or in the list presses OK whenever OK is enabled -- exactly what
  Enter did in the drop-down this replaces. *)
procedure TfrmNewContest.edtContestFilterKeyDown(Sender: TObject; var Key: Word;
                                                 Shift: TShiftState);
begin
   if (Key <> VK_DOWN) or (lstContests.Items.Count = 0) then
      begin
      Exit;
      end;

   if lstContests.ItemIndex < 0 then
      begin
      lstContests.ItemIndex := 0;
      NotifyContestIfChanged;
      end;
   (* CanSetFocus, NOT CanFocus: CanFocus answers for the control alone and
      is True inside a form that is not showing, where SetFocus then raises.
      CanSetFocus walks up to the form. *)
   if lstContests.CanSetFocus then
      begin
      lstContests.SetFocus;
      end;
   Key := 0;
end;

(* A ROW WAS CHOSEN -- by click or by key. What cboContestChange drove before
  Q103, through the same OnContestChanged, now via the one rule that decides
  whether the contest really changed. *)
procedure TfrmNewContest.lstContestsSelectionChange(Sender: TObject; User: boolean);
begin
   if FFilling then
      begin
      Exit;
      end;
   NotifyContestIfChanged;
end;

(* "SHOW INACTIVE CONTESTS" CHANGED -- Q59: list them, or stop listing them,
  under the same search. The refill does the rest: un-ticking while an
  inactive row is selected drops that row, so the selection clears with it;
  an active contest that was chosen stays chosen, found by its identity. *)
procedure TfrmNewContest.chkShowInactiveChange(Sender: TObject);
begin
   ShowMatchingContests;
end;

procedure TfrmNewContest.chkIAmInChange(Sender: TObject);
begin
   if Assigned(OnIAmInChanged) then
      begin
      OnIAmInChanged;
      end;
end;

end.
