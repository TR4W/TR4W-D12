unit uExternalLoggersForm;
(* The editor for ONE external logger definition. The list, its order, the
   Send new QSOs flag and removal live in the Preferences grid
   (uExternalLoggerGrid, issue 220); this form is opened from there for Add
   and Edit. It works on a private copy of the whole configuration so the
   validation (unique names, shared destinations) sees the other loggers, and
   hands the copy back only on OK.

   THE ROWS BELONG TO THE PROVIDER (issue 227). This form does not know what a
   provider needs: it asks the registry for the provider's field descriptors
   (uExternalLoggerRegistry) and builds one row for each -- a text box, a
   masked secret, or a drop-down for a choice. A choice shows NAMES; the id
   behind a name, and anything the lookup derives (WRL's account id), is kept
   internally and is never a field. The choices come from the provider's loader
   on a worker thread, so the form never waits on a network. *)
{$I ..\..\tr4w.inc}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, SyncObjs,
   Generics.Collections, uExternalLoggerConfig, uExternalLoggerRegistry;
type
   (* One declared field, as built on the form. *)
   TFieldRow = class
   public
      Descriptor: TLoggerFieldDescriptor;
      Panel: TPanel;
      CaptionLabel: TLabel;
      Edit: TEdit;
      Combo: TComboBox;
      RefreshButton: TButton;
      (* A yes/no field (issue 256): the box; the caption is its own. *)
      Check: TCheckBox;
      (* A choice: the stored value and the true name behind each combo item.
         A name is '' when it was never recorded; the item then shows a
         placeholder. *)
      Values, Names: TStringList;
      (* The account the last successful lookup revealed. Written to the
         definition only when the operator picks from the list. *)
      DerivedAccount: string;
      (* The operator picked from the list. *)
      Touched: boolean;
      (* The list no longer belongs to the credentials it was loaded with
         (the key was edited): the stored choice is dropped on Save. *)
      Cleared: boolean;
      destructor Destroy; override;
   end;

   (* Loads one choice field's list off the main thread. It owns a private
      copy of the definition and never touches the form. *)
   TChoiceTask = class(TThread)
   protected
      procedure Execute; override;
   public
      Key: string;
      Loader: TLoggerChoiceLoader;
      Work: TExternalLoggerDefinition;
      Choices: TLoggerChoices;
      ErrorCode: string;
      Done: TEvent;
      (* The rows were rebuilt while this ran: its answer is for rows that
         no longer exist. *)
      Stale: boolean;
      constructor Create(const aKey: string; aLoader: TLoggerChoiceLoader;
         const aSource: TExternalLoggerDefinition);
      destructor Destroy; override;
   end;

   TExternalLoggersForm = class(TForm)
   published
      edtName: TEdit;
      cbProvider: TComboBox;
      chkActive: TCheckBox;
      pnlFields: TPanel;
      btnOK, btnCancel: TButton;
      lblName, lblProvider, lblNote: TLabel;
      lblFieldStatus, lblStatus: TLabel;
      (* The warning shown while a certificate box is cleared (issue 256). *)
      lblVerifyNote: TLabel;
      tmrLoad: TTimer;
      procedure ProviderChanged(Sender: TObject);
      procedure Accept(Sender: TObject);
      procedure PollLoad(Sender: TObject);
      procedure EditorCloseQuery(Sender: TObject; var aCanClose: boolean);
      procedure EditorShow(Sender: TObject);
   private
      FConfig: TExternalLoggerConfig;
      FDefinition: TExternalLoggerDefinition;
      FFields: TLoggerFieldList;
      FRows: TObjectList<TFieldRow>;
      FTask: TChoiceTask;
      FBuilding: integer;
      FCloseRequested: boolean;
      FAutoLoadChoices: boolean;
      procedure ClearCredentials;
      function BuildRow(const aDescriptor: TLoggerFieldDescriptor;
         aIndex: integer): TFieldRow;
      function RowOf(const aSender: TObject): TFieldRow;
      function RowByKey(const aKey: string): TFieldRow;
      procedure RowChanged(Sender: TObject);
      procedure UpdateVerifyNote;
      procedure RefreshClick(Sender: TObject);
      procedure SetChoiceSaved(const aRow: TFieldRow; const aValue, aName: string);
      procedure ShowChoice(const aRow: TFieldRow);
      procedure ReadRows(const aTarget: TExternalLoggerDefinition; aFinal: boolean);
      procedure StartLoad(const aRow: TFieldRow);
      procedure ApplyLoad(const aTask: TChoiceTask);
      procedure StartAutoLoad;
      procedure SetBusy;
      procedure ShowDefinition;
   public
      constructor Create(aOwner: TComponent); override;
      destructor Destroy; override;
      (* Shows aDefinition (which stays owned by Config) and builds its rows. *)
      procedure BeginEdit(const aDefinition: TExternalLoggerDefinition);
      (* Reads the rows and the plain controls back into the definition. *)
      procedure Capture;
      (* Replaces the rows with those of aFields, taking ownership of it. The
         provider change uses it with the registry's list; a test uses it with
         its own. *)
      procedure RebuildRows(const aFields: TLoggerFieldList);
      function RowCount: integer;
      (* Lays the dialog out from what its captions and controls measure
         (issue 232). Runs on every show and after the rows are rebuilt;
         running it twice moves nothing. *)
      procedure FitLayout;
      function FieldEdit(const aKey: string): TEdit;
      function FieldCombo(const aKey: string): TComboBox;
      function FieldCheck(const aKey: string): TCheckBox;
      function FieldRefreshButton(const aKey: string): TButton;
      function LoadRunning: boolean;
      property Config: TExternalLoggerConfig read FConfig;
      (* Off, a choice list is only loaded by its Refresh button. *)
      property AutoLoadChoices: boolean read FAutoLoadChoices write FAutoLoadChoices;
   end;

const
   (* A provider declares at most this many rows; one declaring more is a
      defect found the first time its editor opens. The dialog grows to fit
      the rows it has (FitLayout), so this is a statement about providers,
      not about room. *)
   EXTERNAL_LOGGER_MAX_FIELDS = 4;

(* Add (aId = '') or edit one definition of aConfig. True when the operator
   accepted; aConfig then holds the change. *)
function EditExternalLoggerDefinition(const aConfig: TExternalLoggerConfig;
   const aId: string): boolean;

(* The checks the editor's OK button makes, shared with the grid's Send new
   QSOs toggle so neither can switch on a logger the other would refuse. They
   speak to the operator; False means a message was shown. *)
function ExternalLoggerConfigAcceptable(const aConfig: TExternalLoggerConfig): boolean;

implementation
uses Graphics, Math, uLCLFormHelpers, uLCLTranslate, uPasswordReveal, uAppStrings,
   uExternalDelivery, uLogStore, uHTTPDownload;
{$R *.lfm}
const
   (* THE DESIGNED GEOMETRY, AT 96 DPI, AND ONLY AS FLOORS (issue 232). These
      were the row geometry itself -- a 42 px row, captions 190 wide, boxes
      at 200, Refresh 90 wide -- so a caption wider than 190 in the running
      font was clipped, a box taller than 40 left its row, and Refresh's
      caption could outgrow its button. FitLayout measures each of those and
      uses these only as the least it will make them, through
      Scale96ToForm, so at 100% on Windows the widths and lefts are the
      designed ones. The HEIGHT is not: the designed dialog kept room for
      four rows, and the dialog is now as tall as the rows it has.

      A 96-dpi number is honest here only through Scale96ToForm: the form's
      PixelsPerInch is what the LCL scaled the designed controls to. *)
   LABEL_WIDTH_96 = 190;      (* the caption column, floor *)
   LABEL_PAD_96 = 4;          (* beyond the measured caption *)
   COLUMN_GAP_96 = 10;        (* caption to box, box to Refresh *)
   FIELD_WIDTH_96 = 470;      (* the box column (edtName's designed width), floor *)
   REFRESH_WIDTH_96 = 90;     (* the Refresh button, floor *)
   BUTTON_CHROME_96 = 24;     (* a push button's frame beside its caption *)
   ROW_PITCH_96 = 42;         (* one row, floor *)
   ROW_SPACE_96 = 14;         (* what a row leaves around its tallest control *)
   FIRST_ROW_TOP_96 = 13;     (* the Name row's band, so its box sits at 20 *)
   SIDE_MARGIN_96 = 16;       (* left of everything *)
   RIGHT_MARGIN_96 = 24;      (* right of the rows *)
   SECTION_GAP_96 = 8;        (* between the blocks below the rows *)
   BUTTONS_GAP_96 = 14;       (* above the buttons *)
   STATUS_LINES = 2;          (* the field status holds this many lines *)
   BUTTON_GAP_96 = 10;        (* between Save and Cancel *)
   BUTTON_RIGHT_96 = 20;      (* right of Cancel *)
   BOTTOM_MARGIN_96 = 12;     (* below the buttons *)
   DESIGN_CLIENT_WIDTH_96 = 710;

destructor TFieldRow.Destroy;
begin
   Values.Free;
   Names.Free;
   Panel.Free;
   inherited Destroy;
end;

constructor TChoiceTask.Create(const aKey: string; aLoader: TLoggerChoiceLoader;
   const aSource: TExternalLoggerDefinition);
begin
   inherited Create(True);
   Key := aKey;
   Loader := aLoader;
   Work := TExternalLoggerDefinition.Create;
   Work.Assign(aSource);
   Choices := TLoggerChoices.Create;
   Done := TEvent.Create(nil, True, False, '');
end;

destructor TChoiceTask.Destroy;
begin
   Terminate;
   if not Suspended then
      begin
      WaitFor;
      end;
   inherited Destroy;
   Done.Free;
   Choices.Free;
   Work.Free;
end;

procedure TChoiceTask.Execute;
begin
   try
      try
         ErrorCode := Loader(Work, Choices);
      except
         on E: Exception do
            begin
            (* The message may echo the request; only a fixed code leaves. *)
            ErrorCode := 'INVALID_RESPONSE';
            end;
      end;
   finally
      Done.SetEvent;
   end;
end;

constructor TExternalLoggersForm.Create(aOwner: TComponent);
var
   i: integer;
begin
   inherited Create(aOwner);
   FConfig := TExternalLoggerConfig.Create;
   FRows := TObjectList<TFieldRow>.Create(True);
   FFields := TLoggerFieldList.Create(True);
   FAutoLoadChoices := True;
   for i := 0 to ExternalLoggerProviderCount - 1 do
      begin
      cbProvider.Items.Add(AnsiString(ExternalLoggerRegistration(i).Id));
      end;
   TranslateForm(Self);
   (* RUN-TIME TEXT FROM uAppStrings, after the form walk, so the catalogue
      is the one route; the .lfm text is a placeholder (uServerLogForm's
      pattern). Before the first layout, which measures it. *)
   lblNote.Caption := UTF8Encode(SLoggerEditorNote);
end;

destructor TExternalLoggersForm.Destroy;
begin
   tmrLoad.Enabled := False;
   FTask.Free;
   FTask := nil;
   FRows.Free;
   FFields.Free;
   FConfig.Free;
   inherited Destroy;
end;

function TExternalLoggersForm.RowCount: integer;
begin
   Result := FRows.Count;
end;

function TExternalLoggersForm.RowByKey(const aKey: string): TFieldRow;
var
   row: TFieldRow;
begin
   Result := nil;
   for row in FRows do
      begin
      if row.Descriptor.Key = aKey then
         begin
         Result := row;
         Exit;
         end;
      end;
end;

function TExternalLoggersForm.RowOf(const aSender: TObject): TFieldRow;
var
   row: TFieldRow;
begin
   Result := nil;
   for row in FRows do
      begin
      if (row.Edit = aSender) or (row.Combo = aSender) or
         (row.RefreshButton = aSender) or (row.Check = aSender) then
         begin
         Result := row;
         Exit;
         end;
      end;
end;

function TExternalLoggersForm.FieldEdit(const aKey: string): TEdit;
var
   row: TFieldRow;
begin
   Result := nil;
   row := RowByKey(aKey);
   if row <> nil then
      begin
      Result := row.Edit;
      end;
end;

function TExternalLoggersForm.FieldCombo(const aKey: string): TComboBox;
var
   row: TFieldRow;
begin
   Result := nil;
   row := RowByKey(aKey);
   if row <> nil then
      begin
      Result := row.Combo;
      end;
end;

function TExternalLoggersForm.FieldCheck(const aKey: string): TCheckBox;
var
   row: TFieldRow;
begin
   Result := nil;
   row := RowByKey(aKey);
   if row <> nil then
      begin
      Result := row.Check;
      end;
end;

function TExternalLoggersForm.FieldRefreshButton(const aKey: string): TButton;
var
   row: TFieldRow;
begin
   Result := nil;
   row := RowByKey(aKey);
   if row <> nil then
      begin
      Result := row.RefreshButton;
      end;
end;

function TExternalLoggersForm.LoadRunning: boolean;
begin
   Result := FTask <> nil;
end;

(* A choice shows names. The item for a saved choice whose name was never
   recorded shows a placeholder, and still carries its value. *)
procedure TExternalLoggersForm.ShowChoice(const aRow: TFieldRow);
var
   i: integer;
   text: string;
begin
   aRow.Combo.Items.Clear;
   for i := 0 to aRow.Values.Count - 1 do
      begin
      text := string(aRow.Names[i]);
      if text = '' then
         begin
         aRow.Combo.Items.Add(UTF8Encode(SLoggerChoiceSaved));
         end
      else
         begin
         aRow.Combo.Items.Add(UTF8Encode(text));
         end;
      end;
end;

procedure TExternalLoggersForm.SetChoiceSaved(const aRow: TFieldRow;
   const aValue, aName: string);
begin
   aRow.Values.Clear;
   aRow.Names.Clear;
   if aValue <> '' then
      begin
      aRow.Values.Add(AnsiString(aValue));
      aRow.Names.Add(AnsiString(aName));
      end;
   ShowChoice(aRow);
   if aValue <> '' then
      begin
      aRow.Combo.ItemIndex := 0;
      end
   else
      begin
      aRow.Combo.ItemIndex := -1;
      end;
end;

function TExternalLoggersForm.BuildRow(const aDescriptor: TLoggerFieldDescriptor;
   aIndex: integer): TFieldRow;
var
   rowWidth: integer;
begin
   rowWidth := pnlFields.ClientWidth;
   Result := TFieldRow.Create;
   Result.Descriptor := aDescriptor;
   Result.Values := TStringList.Create;
   Result.Names := TStringList.Create;
   Result.Panel := TPanel.Create(pnlFields);
   Result.Panel.Parent := pnlFields;
   Result.Panel.BevelOuter := bvNone;
   Result.Panel.Caption := '';
   Result.Panel.Height := Scale96ToForm(ROW_PITCH_96);
   Result.Panel.Top := aIndex * Result.Panel.Height;
   (* THE CONTROLS OF A ROW ARE ANCHORED LEFT AND TOP ONLY (issue 231). The
      panel is created at its default 170 wide and Align stretches it to the
      panel's width afterwards; a control anchored to the right moves by that
      whole difference, which put the key's eye over its box and pushed the
      Logbook drop-down's arrow and the Refresh button out of the row.
      FitLayout places every control in the row from measurement, after the
      panel has its width. The bounds given here are only a start. *)
   Result.Panel.Width := rowWidth;
   Result.Panel.Align := alTop;
   Result.CaptionLabel := TLabel.Create(Result.Panel);
   Result.CaptionLabel.Parent := Result.Panel;
   Result.CaptionLabel.AutoSize := False;
   Result.CaptionLabel.Layout := tlCenter;
   Result.CaptionLabel.SetBounds(0, 0, Scale96ToForm(LABEL_WIDTH_96), Result.Panel.Height);
   Result.CaptionLabel.Caption := UTF8Encode(aDescriptor.Caption);
   if aDescriptor.Kind = lfkCheck then
      begin
      (* THE BOX CARRIES ITS OWN CAPTION in the box column, so the caption
         column stays empty for this row (issue 256). FitLayout sizes it. *)
      Result.CaptionLabel.Caption := '';
      Result.Check := TCheckBox.Create(Result.Panel);
      Result.Check.Parent := Result.Panel;
      Result.Check.AutoSize := False;
      Result.Check.Anchors := [akTop, akLeft];
      Result.Check.Caption := UTF8Encode(aDescriptor.Caption);
      Result.Check.Checked := FDefinition.FieldText(aDescriptor.Key) <> '0';
      Result.Check.OnChange := RowChanged;
      end
   else if aDescriptor.Kind = lfkChoice then
      begin
      Result.Combo := TComboBox.Create(Result.Panel);
      Result.Combo.Parent := Result.Panel;
      Result.Combo.Style := csDropDownList;
      Result.Combo.Anchors := [akTop, akLeft];
      Result.Combo.OnChange := RowChanged;
      Result.RefreshButton := TButton.Create(Result.Panel);
      Result.RefreshButton.Parent := Result.Panel;
      Result.RefreshButton.Anchors := [akTop, akLeft];
      Result.RefreshButton.Caption := UTF8Encode(SLoggerChoiceRefresh);
      Result.RefreshButton.OnClick := RefreshClick;
      SetChoiceSaved(Result, FDefinition.FieldText(aDescriptor.Key),
         FDefinition.FieldText(aDescriptor.DisplayKey));
      end
   else
      begin
      Result.Edit := TEdit.Create(Result.Panel);
      Result.Edit.Parent := Result.Panel;
      Result.Edit.SetBounds(Scale96ToForm(LABEL_WIDTH_96 + COLUMN_GAP_96), 0,
         Scale96ToForm(FIELD_WIDTH_96), Result.Edit.Height);
      Result.Edit.Anchors := [akTop, akLeft];
      Result.Edit.Text := UTF8Encode(FDefinition.FieldText(aDescriptor.Key));
      if aDescriptor.Key = LF_URL then
         begin
         (* A plain http:// address has no certificate: the certificate box
            is disabled while it stands (UpdateVerifyNote). *)
         Result.Edit.OnChange := RowChanged;
         end;
      if aDescriptor.Kind = lfkSecret then
         begin
         Result.Edit.PasswordChar := '*';
         (* Before the reveal toggle: it chains the handler it finds. *)
         Result.Edit.OnChange := RowChanged;
         AttachPasswordReveal(Result.Edit);
         end;
      end;
end;

procedure TExternalLoggersForm.RebuildRows(const aFields: TLoggerFieldList);
var
   i: integer;
begin
   if aFields.Count > EXTERNAL_LOGGER_MAX_FIELDS then
      begin
      aFields.Free;
      raise EInvalidOperation.Create('An external logger declares too many fields');
      end;
   Inc(FBuilding);
   try
      (* A list being loaded belongs to rows that are about to go. *)
      if FTask <> nil then
         begin
         FTask.Stale := True;
         end;
      FRows.Clear;
      FFields.Free;
      FFields := aFields;
      for i := 0 to FFields.Count - 1 do
         begin
         FRows.Add(BuildRow(FFields[i], i));
         end;
      lblFieldStatus.Caption := '';
   finally
      Dec(FBuilding);
   end;
   SetBusy;
   UpdateVerifyNote;
   (* A provider changed while the dialog is open. Before it is shown the
      widget set can measure nothing (a label's preferred size needs its
      parent's handle), so the first layout is the show's. *)
   if Visible then
      begin
      FitLayout;
      end;
end;

procedure TExternalLoggersForm.EditorShow(Sender: TObject);
begin
   FitLayout;
end;

(* THE DIALOG IS LAID OUT FROM MEASUREMENT (issue 232), the Edit QSO pattern
   (uEditQSOForm.FitLayout) on a smaller form:

   - the caption column is as wide as the widest caption -- Name, Provider and
     every row the provider declared -- measured in its own font;
   - the box column starts after it, for the Name and Provider boxes and the
     rows alike, and is wide enough for each drop-down's longest item plus
     its chrome (DROPDOWN_CHROME_96), and for Refresh beside a choice;
   - Refresh is as wide as its caption and its widget set want;
   - every row is as tall as the tallest control in any row, plus the
     designed space around it, and each control is centred in its row; a
     secret's eye is as tall and as wide as its box is high, beside it;
   - below the rows each block is as tall as it measures: the wrapped status
     and note lines at their width, the check box and the buttons at their
     own (AutoSize) size.

   The designed numbers are floors, scaled through Scale96ToForm. The dialog
   grows about its centre, and shrinks back to the designed width when the
   content allows. *)
procedure TExternalLoggersForm.FitLayout;

   function Px(const a96: integer): integer;
   begin
      Result := Scale96ToForm(a96);
   end;

   (* As tall as it is, or as its widget set prefers, whichever is more. *)
   function HeightOf(const aControl: TControl): integer;
   var
      pw, ph: integer;
   begin
      ControlPreferredSize(aControl, pw, ph);
      Result := Max(aControl.Height, ph);
   end;

   function CaptionNeed(const aLabel: TLabel): integer;
   begin
      Result := TextWidthInFont(aLabel.Font, aLabel.Caption) + Px(LABEL_PAD_96);
   end;

   function ButtonNeed(const aButton: TButton; const aFloor: integer): integer;
   var
      pw, ph: integer;
   begin
      ControlPreferredSize(aButton, pw, ph);
      Result := Max(aFloor, Max(pw, TextWidthInFont(aButton.Font, aButton.Caption) +
         Px(BUTTON_CHROME_96)));
   end;

   (* A word-wrapped label at the width it has been given. Its anchors hold
      it left and right, which is what makes the LCL wrap the preferred
      height at that width. aLines lines of its font is the least it takes,
      so text arriving later (a load's status) has room. *)
   function WrappedHeight(const aLabel: TLabel; const aLines: integer): integer;
   var
      pw, ph: integer;
   begin
      ControlPreferredSize(aLabel, pw, ph);
      Result := Max(ph, aLines * TextHeightInFont(aLabel.Font, 'Ag'));
   end;

   procedure PlaceDropDown(const aCombo: TComboBox; const aLeft, aBandTop,
      aBandHeight, aWidth: integer);
   var
      h: integer;
   begin
      h := HeightOf(aCombo);
      (* MinWidth AS WELL AS Width: an AutoSize drop-down's widget set would
         otherwise put its own preferred width back (cocoa shrinks one below
         its text). Cleared first, so a narrower layout is not held wide. *)
      aCombo.Constraints.MinWidth := 0;
      aCombo.SetBounds(aLeft, aBandTop + (aBandHeight - h) div 2, aWidth, h);
      aCombo.Constraints.MinWidth := aWidth;
   end;

var
   row: TFieldRow;
   eye: TControl;
   side, labelW, editLeft, fieldW, rowW, refreshW, rowH, h, w, y, eyeW: integer;
   clientW, pw, ph: integer;
   oldW, oldH, centreX, centreY: integer;
begin
   oldW := Width;
   oldH := Height;
   centreX := Left + oldW div 2;
   centreY := Top + oldH div 2;
   side := Px(SIDE_MARGIN_96);

   (* The caption column. *)
   labelW := Max(Px(LABEL_WIDTH_96), Max(CaptionNeed(lblName), CaptionNeed(lblProvider)));
   for row in FRows do
      begin
      labelW := Max(labelW, CaptionNeed(row.CaptionLabel));
      end;
   editLeft := labelW + Px(COLUMN_GAP_96);

   (* Refresh, and the box column. *)
   refreshW := 0;
   for row in FRows do
      begin
      if row.RefreshButton <> nil then
         begin
         refreshW := Max(refreshW, ButtonNeed(row.RefreshButton, Px(REFRESH_WIDTH_96)));
         end;
      end;
   fieldW := Max(Px(FIELD_WIDTH_96),
      WidestText(cbProvider.Font, cbProvider.Items) + Px(DROPDOWN_CHROME_96));
   for row in FRows do
      begin
      if row.Combo <> nil then
         begin
         fieldW := Max(fieldW, WidestText(row.Combo.Font, row.Combo.Items) +
            Px(DROPDOWN_CHROME_96) + Px(COLUMN_GAP_96) + refreshW);
         end;
      end;
   rowW := editLeft + fieldW;

   (* The dialog's width: the rows, the check box and the buttons each fit,
      and never less than designed. The box column then takes what the
      dialog gives it. *)
   ControlPreferredSize(chkActive, pw, ph);
   clientW := Max(Px(DESIGN_CLIENT_WIDTH_96), side + rowW + Px(RIGHT_MARGIN_96));
   clientW := Max(clientW, side + Max(chkActive.Width, pw) + Px(RIGHT_MARGIN_96));
   clientW := Max(clientW, side + btnOK.Width + Px(BUTTON_GAP_96) + btnCancel.Width +
      Px(BUTTON_RIGHT_96));
   ClientWidth := clientW;
   rowW := clientW - side - Px(RIGHT_MARGIN_96);
   fieldW := rowW - editLeft;

   (* One row height for every row: the tallest control, plus the designed
      space around it. *)
   rowH := Max(HeightOf(edtName), HeightOf(cbProvider));
   for row in FRows do
      begin
      if row.Combo <> nil then
         begin
         rowH := Max(rowH, Max(HeightOf(row.Combo), HeightOf(row.RefreshButton)));
         end
      else if row.Check <> nil then
         begin
         rowH := Max(rowH, HeightOf(row.Check));
         end
      else
         begin
         rowH := Max(rowH, HeightOf(row.Edit));
         end;
      end;
   rowH := Max(Px(ROW_PITCH_96), rowH + Px(ROW_SPACE_96));

   (* Name and Provider, on the form. *)
   y := Px(FIRST_ROW_TOP_96);
   lblName.SetBounds(side, y, labelW, rowH);
   h := HeightOf(edtName);
   edtName.SetBounds(side + editLeft, y + (rowH - h) div 2, fieldW, h);
   y := y + rowH;
   lblProvider.SetBounds(side, y, labelW, rowH);
   PlaceDropDown(cbProvider, side + editLeft, y, rowH, fieldW);
   y := y + rowH;

   (* The provider's rows, each in its own panel (aligned to the top of
      pnlFields, so a panel's width is pnlFields'). *)
   pnlFields.SetBounds(side, y, rowW, FRows.Count * rowH);
   for row in FRows do
      begin
      row.Panel.Height := rowH;
      row.CaptionLabel.SetBounds(0, 0, labelW, rowH);
      if row.Combo <> nil then
         begin
         h := HeightOf(row.RefreshButton);
         row.RefreshButton.SetBounds(rowW - refreshW, (rowH - h) div 2, refreshW, h);
         PlaceDropDown(row.Combo, editLeft, 0, rowH,
            fieldW - Px(COLUMN_GAP_96) - refreshW);
         end
      else if row.Check <> nil then
         begin
         (* The box, in the box column, as wide as the column: its caption is
            its own and is clipped by nothing narrower than the column. *)
         h := HeightOf(row.Check);
         row.Check.SetBounds(editLeft, (rowH - h) div 2, fieldW, h);
         end
      else
         begin
         h := HeightOf(row.Edit);
         (* The eye is anchored to the box's right side, top and bottom
            (uPasswordReveal), so it follows the box; only its width is its
            own, and it is square at the box's height. *)
         eyeW := 0;
         eye := PasswordRevealControl(row.Edit);
         if eye <> nil then
            begin
            eyeW := h;
            eye.Width := eyeW;
            end;
         row.Edit.SetBounds(editLeft, (rowH - h) div 2, fieldW - eyeW, h);
         end;
      end;
   y := pnlFields.Top + pnlFields.Height + Px(SECTION_GAP_96);

   (* The blocks below the rows, each as tall as it measures. *)
   lblFieldStatus.SetBounds(side, y, rowW, lblFieldStatus.Height);
   lblFieldStatus.Height := WrappedHeight(lblFieldStatus, STATUS_LINES);
   y := y + lblFieldStatus.Height + Px(SECTION_GAP_96);

   (* The certificate warning takes room only while it is shown (issue 256),
      so a provider without the box lays out exactly as before. *)
   if lblVerifyNote.Visible then
      begin
      lblVerifyNote.SetBounds(side, y, rowW, lblVerifyNote.Height);
      lblVerifyNote.Height := WrappedHeight(lblVerifyNote, 2);
      y := y + lblVerifyNote.Height + Px(SECTION_GAP_96);
      end;

   chkActive.SetBounds(side, y, chkActive.Width, chkActive.Height);
   y := y + chkActive.Height + Px(SECTION_GAP_96);

   lblNote.SetBounds(side, y, rowW, lblNote.Height);
   lblNote.Height := WrappedHeight(lblNote, 1);
   y := y + lblNote.Height + Px(SECTION_GAP_96);

   lblStatus.SetBounds(side, y, rowW, lblStatus.Height);
   lblStatus.Height := WrappedHeight(lblStatus, 1);
   y := y + lblStatus.Height + Px(BUTTONS_GAP_96);

   (* Save and Cancel size themselves to their captions (AutoSize); they are
      placed from the right. *)
   btnCancel.SetBounds(clientW - Px(BUTTON_RIGHT_96) - btnCancel.Width, y,
      btnCancel.Width, btnCancel.Height);
   w := btnOK.Width;
   btnOK.SetBounds(btnCancel.Left - Px(BUTTON_GAP_96) - w, y, w, btnOK.Height);
   ClientHeight := y + Max(btnOK.Height, btnCancel.Height) + Px(BOTTOM_MARGIN_96);

   (* KEEP THE CENTRE, as Edit QSO does: the dialog was centred before it was
      shown, and a provider change while it is open should not walk it
      across the screen. Unchanged size, no move. *)
   if (Width <> oldW) or (Height <> oldH) then
      begin
      SetBounds(centreX - Width div 2, centreY - Height div 2, Width, Height);
      end;
end;

(* A secret edited by the operator invalidates every choice list: the list
   belongs to the credentials it was loaded with, and so does the account
   derived from it. *)
(* THE CERTIFICATE WARNING (issue 256): shown while a certificate box is
   CLEARED, with the sentence its descriptor declared. A plain http://
   address has no certificate, so the box is DISABLED (it keeps its value) and
   no warning is shown while that address stands. Only the check box rows and
   the URL row matter; a provider with neither shows nothing. *)
procedure TExternalLoggersForm.UpdateVerifyNote;
var
   row, urlRow: TFieldRow;
   plain: boolean;
   warning: string;
begin
   plain := False;
   urlRow := RowByKey(LF_URL);
   if (urlRow <> nil) and (urlRow.Edit <> nil) then
      begin
      plain := IsPlainHttpUrl(UTF8Decode(urlRow.Edit.Text));
      end;
   warning := '';
   for row in FRows do
      begin
      if row.Check <> nil then
         begin
         row.Check.Enabled := not plain;
         if (not plain) and (not row.Check.Checked) and (warning = '') then
            begin
            warning := row.Descriptor.OffWarning;
            end;
         end;
      end;
   lblVerifyNote.Caption := UTF8Encode(warning);
   lblVerifyNote.Visible := warning <> '';
end;

procedure TExternalLoggersForm.RowChanged(Sender: TObject);
var
   row, other: TFieldRow;
   noteWasShown: boolean;
begin
   if FBuilding > 0 then
      begin
      Exit;
      end;
   row := RowOf(Sender);
   if row = nil then
      begin
      Exit;
      end;
   if (row.Descriptor.Kind = lfkCheck) or (row.Descriptor.Key = LF_URL) then
      begin
      (* The certificate warning follows the box and the address. Only when it
         appears or goes does the dialog need laying out again. *)
      noteWasShown := lblVerifyNote.Visible;
      UpdateVerifyNote;
      if (noteWasShown <> lblVerifyNote.Visible) and Visible then
         begin
         FitLayout;
         end;
      Exit;
      end;
   if row.Descriptor.Kind = lfkChoice then
      begin
      row.Touched := True;
      Exit;
      end;
   if row.Descriptor.Kind = lfkSecret then
      begin
      for other in FRows do
         begin
         if other.Descriptor.Kind = lfkChoice then
            begin
            other.Values.Clear;
            other.Names.Clear;
            ShowChoice(other);
            other.Combo.ItemIndex := -1;
            other.DerivedAccount := '';
            other.Touched := False;
            other.Cleared := True;
            end;
         end;
      end;
end;

procedure TExternalLoggersForm.RefreshClick(Sender: TObject);
begin
   StartLoad(RowOf(Sender));
end;

procedure TExternalLoggersForm.SetBusy;
var
   row: TFieldRow;
begin
   for row in FRows do
      begin
      if row.RefreshButton <> nil then
         begin
         row.RefreshButton.Enabled := FTask = nil;
         end;
      end;
   tmrLoad.Enabled := FTask <> nil;
end;

(* Writes the rows into aTarget. aFinal is the operator accepting. Only that
   case puts a derived account into the definition after a pick, and only that
   case treats a replaced secret as the end of a legacy vault reference.
   Opening, showing and saving without touching a row leaves every stored
   value as it was. *)
procedure TExternalLoggersForm.ReadRows(const aTarget: TExternalLoggerDefinition;
   aFinal: boolean);
var
   row: TFieldRow;
   text: string;
   index: integer;
begin
   for row in FRows do
      begin
      if row.Descriptor.Kind = lfkChoice then
         begin
         index := row.Combo.ItemIndex;
         if index >= 0 then
            begin
            aTarget.SetFieldText(row.Descriptor.Key, string(row.Values[index]));
            aTarget.SetFieldText(row.Descriptor.DisplayKey, string(row.Names[index]));
            if aFinal and row.Touched and (row.DerivedAccount <> '') then
               begin
               aTarget.Account := row.DerivedAccount;
               end;
            end
         else if row.Cleared then
            begin
            aTarget.SetFieldText(row.Descriptor.Key, '');
            aTarget.SetFieldText(row.Descriptor.DisplayKey, '');
            aTarget.Account := '';
            end;
         end
      else if row.Check <> nil then
         begin
         (* '1' / '0' is the definition's own spelling for a yes/no field. *)
         if row.Check.Checked then
            begin
            aTarget.SetFieldText(row.Descriptor.Key, '1');
            end
         else
            begin
            aTarget.SetFieldText(row.Descriptor.Key, '0');
            end;
         end
      else
         begin
         text := UTF8Decode(row.Edit.Text);
         if row.Descriptor.Kind <> lfkSecret then
            begin
            text := Trim(text);
            end
         else if aFinal and (aTarget.FieldText(row.Descriptor.Key) <> text) then
            begin
            aTarget.LegacySecretPending := False;
            end;
         aTarget.SetFieldText(row.Descriptor.Key, text);
         end;
      end;
end;

procedure TExternalLoggersForm.Capture;
begin
   if FDefinition = nil then
      begin
      Exit;
      end;
   FDefinition.Name := Trim(UTF8Decode(edtName.Text));
   FDefinition.ProviderId := UTF8Decode(cbProvider.Text);
   ReadRows(FDefinition, True);
   FConfig.SetActive(FDefinition.Id, chkActive.Checked);
end;

procedure TExternalLoggersForm.StartLoad(const aRow: TFieldRow);
var
   work: TExternalLoggerDefinition;
begin
   if (aRow = nil) or (FTask <> nil) or
      not Assigned(aRow.Descriptor.Loader) then
      begin
      Exit;
      end;
   (* The task copies the definition WITH the rows' present text, so a key
      typed a moment ago is the one used. *)
   work := TExternalLoggerDefinition.Create;
   try
      work.Assign(FDefinition);
      ReadRows(work, False);
      FTask := TChoiceTask.Create(aRow.Descriptor.Key, aRow.Descriptor.Loader, work);
   finally
      work.Free;
   end;
   lblFieldStatus.Caption := UTF8Encode(SLoggerChoiceLoading);
   FTask.Start;
   SetBusy;
end;

(* The saved entry stays selectable, whatever the answer was: without a
   network it is the only entry, and a logbook the provider no longer lists
   is not silently dropped from the definition. *)
procedure TExternalLoggersForm.ApplyLoad(const aTask: TChoiceTask);
var
   row: TFieldRow;
   i, index: integer;
   current, currentName: string;
begin
   row := RowByKey(aTask.Key);
   if row = nil then
      begin
      Exit;
      end;
   if aTask.ErrorCode <> '' then
      begin
      lblFieldStatus.Caption := UTF8Encode(
         UnicodeFormat(SLoggerChoiceFailed, [aTask.ErrorCode]));
      Exit;
      end;
   lblFieldStatus.Caption := '';
   current := '';
   currentName := '';
   if row.Combo.ItemIndex >= 0 then
      begin
      current := string(row.Values[row.Combo.ItemIndex]);
      currentName := string(row.Names[row.Combo.ItemIndex]);
      end;
   Inc(FBuilding);
   try
      row.Values.Clear;
      row.Names.Clear;
      if (current <> '') and (aTask.Choices.IndexOfValue(current) < 0) then
         begin
         row.Values.Add(AnsiString(current));
         row.Names.Add(AnsiString(currentName));
         end;
      for i := 0 to aTask.Choices.Count - 1 do
         begin
         row.Values.Add(AnsiString(aTask.Choices.Value[i]));
         row.Names.Add(AnsiString(aTask.Choices.Display[i]));
         end;
      ShowChoice(row);
      index := -1;
      if current <> '' then
         begin
         index := row.Values.IndexOf(AnsiString(current));
         end;
      row.Combo.ItemIndex := index;
      row.DerivedAccount := aTask.Work.Account;
      row.Cleared := False;
   finally
      Dec(FBuilding);
   end;
end;

procedure TExternalLoggersForm.PollLoad(Sender: TObject);
var
   task: TChoiceTask;
begin
   if (FTask = nil) or (FTask.Done.WaitFor(0) <> wrSignaled) then
      begin
      Exit;
      end;
   task := FTask;
   FTask := nil;
   try
      if not task.Stale then
         begin
         ApplyLoad(task);
         end;
   finally
      task.Free;
   end;
   SetBusy;
   if FCloseRequested then
      begin
      ModalResult := mrCancel;
      end;
end;

procedure TExternalLoggersForm.EditorCloseQuery(Sender: TObject;
   var aCanClose: boolean);
begin
   aCanClose := FTask = nil;
   if FTask <> nil then
      begin
      FCloseRequested := True;
      FTask.Terminate;
      end;
end;

(* The list is loaded for a definition that already has credentials, so the
   operator sees names at once instead of having to ask. *)
procedure TExternalLoggersForm.StartAutoLoad;
var
   row, secret: TFieldRow;
   hasSecret: boolean;
begin
   if not FAutoLoadChoices then
      begin
      Exit;
      end;
   hasSecret := False;
   for secret in FRows do
      begin
      if (secret.Descriptor.Kind = lfkSecret) and (secret.Edit.Text <> '') then
         begin
         hasSecret := True;
         end;
      end;
   if not hasSecret then
      begin
      Exit;
      end;
   for row in FRows do
      begin
      if row.Descriptor.Kind = lfkChoice then
         begin
         StartLoad(row);
         Exit;
         end;
      end;
end;

procedure TExternalLoggersForm.ClearCredentials;
begin
   FDefinition.ApiKey := '';
   FDefinition.Password := '';
   FDefinition.URL := '';
   FDefinition.Account := '';
   FDefinition.Logbook := '';
   FDefinition.LogbookName := '';
   FDefinition.LegacySecretPending := False;
   FDefinition.LegacyWRL := False;
   (* A new provider starts verifying: another provider's opt-out is not
      carried over (issue 256). *)
   FDefinition.VerifyServer := True;
end;

procedure TExternalLoggersForm.BeginEdit(const aDefinition: TExternalLoggerDefinition);
begin
   FDefinition := aDefinition;
   ShowDefinition;
end;

procedure TExternalLoggersForm.ShowDefinition;
var
   counts: TDeliveryCounts;
begin
   Inc(FBuilding);
   try
      edtName.Text := UTF8Encode(FDefinition.Name);
      cbProvider.ItemIndex := cbProvider.Items.IndexOf(AnsiString(FDefinition.ProviderId));
      chkActive.Checked := FConfig.ActivePosition(FDefinition.Id) > 0;
   finally
      Dec(FBuilding);
   end;
   ProviderChanged(nil);
   StartAutoLoad;
   lblStatus.Caption := UTF8Encode(SLoggerEditorNoLog);
   if LogStoreRepository <> nil then
      begin
      try
         counts := ExternalDeliveryCounts(LogStoreRepository.Database.FileName, FDefinition.DeliveryId);
         lblStatus.Caption := UTF8Encode(UnicodeFormat(SLoggerEditorCounts,
            [counts.Pending, counts.InFlight, counts.Synced, counts.Uncertain, counts.Failed]));
      except
         on E: Exception do
            begin
            lblStatus.Caption := UTF8Encode(SLoggerEditorNoCounts);
            end;
      end;
      end;
end;

(* Sender is nil when the editor itself is showing a definition. A change by
   the operator keeps the values the old provider's rows shared (host, port),
   drops the credentials, and builds the new provider's rows. *)
procedure TExternalLoggersForm.ProviderChanged(Sender: TObject);
var
   registration: TExternalLoggerRegistration;
   fields: TLoggerFieldList;
   previousDefault: integer;
begin
   if FDefinition = nil then
      begin
      Exit;
      end;
   if (Sender <> nil) and (FBuilding = 0) then
      begin
      ReadRows(FDefinition, False);
      ClearCredentials;
      previousDefault := 0;
      if FindExternalLoggerRegistration(FDefinition.ProviderId, registration) then
         begin
         previousDefault := registration.DefaultPort;
         end;
      FDefinition.ProviderId := UTF8Decode(cbProvider.Text);
      (* A port still at the old provider's default (or empty) moves to the new
         provider's own; a port the operator chose stays. *)
      if FindExternalLoggerRegistration(FDefinition.ProviderId, registration) and
         (registration.DefaultPort <> 0) and
         ((FDefinition.Port = 0) or (FDefinition.Port = previousDefault)) then
         begin
         FDefinition.Port := registration.DefaultPort;
         end;
      end;
   if FindExternalLoggerRegistration(FDefinition.ProviderId, registration) then
      begin
      fields := registration.CreateFields;
      end
   else
      begin
      fields := TLoggerFieldList.Create(True);
      end;
   RebuildRows(fields);
end;

function ExternalLoggerConfigAcceptable(const aConfig: TExternalLoggerConfig): boolean;
var
   definition, earlier: TExternalLoggerDefinition;
   error: string;
   i, j: integer;
begin
   Result := False;
   for i := 0 to aConfig.ActiveIds.Count - 1 do
      begin
      definition := aConfig.Find(string(aConfig.ActiveIds[i]));
      if definition <> nil then
         begin
         error := ExternalLoggerDefinitionError(definition);
         if error <> '' then
            begin
            ShowMessage(UTF8Encode(definition.Name + ': ' + error));
            Exit;
            end;
         end;
      end;
   if not aConfig.Validate(error) then
      begin
      ShowMessage(UTF8Encode(error));
      Exit;
      end;
   for i := 0 to aConfig.ActiveIds.Count - 1 do
      begin
      definition := aConfig.Find(string(aConfig.ActiveIds[i]));
      for j := 0 to i - 1 do
         begin
         earlier := aConfig.Find(string(aConfig.ActiveIds[j]));
         if (definition.ProviderId = earlier.ProviderId) and
            (definition.DestinationFingerprint = earlier.DestinationFingerprint) then
            begin
            if QuestionDlg('TR4W', UTF8Encode('The active loggers "' + definition.Name +
               '" and "' + earlier.Name +
               '" point to the same destination. Send each contact twice?'),
               mtWarning, [mrYes, mrNo, 'IsDefault'], 0) <> mrYes then
               begin
               Exit;
               end;
            end;
         end;
      end;
   Result := True;
end;

procedure TExternalLoggersForm.Accept(Sender: TObject);
begin
   (* A list still arriving would decide the account after the fact. *)
   if FTask <> nil then
      begin
      Exit;
      end;
   Capture;
   if not ExternalLoggerConfigAcceptable(FConfig) then
      begin
      Exit;
      end;
   FConfig.Present := True;
   ModalResult := mrOK;
end;

function EditExternalLoggerDefinition(const aConfig: TExternalLoggerConfig;
   const aId: string): boolean;
var
   dialog: TExternalLoggersForm;
   definition: TExternalLoggerDefinition;
begin
   Result := False;
   if aConfig.Error <> '' then
      begin
      ShowMessage(UTF8Encode('External logger settings could not be read: ' + aConfig.Error));
      Exit;
      end;
   dialog := TExternalLoggersForm.Create(nil);
   try
      dialog.FConfig.Assign(aConfig);
      if aId = '' then
         begin
         (* A new definition starts inactive: the operator chooses to send. *)
         definition := TExternalLoggerDefinition.Create;
         definition.Name := dialog.FConfig.NewDefinitionName;
         definition.ProviderId := 'DXKEEPER';
         definition.Address := '127.0.0.1';
         definition.Port := DXKEEPER_DEFAULT_PORT;
         dialog.FConfig.Definitions.Add(definition);
         end
      else
         begin
         definition := dialog.FConfig.Find(aId);
         end;
      if definition = nil then
         begin
         Exit;
         end;
      dialog.BeginEdit(definition);
      Result := dialog.ShowModal = mrOK;
      if Result then
         begin
         aConfig.Assign(dialog.FConfig);
         end;
   finally
      dialog.Free;
   end;
end;
end.
