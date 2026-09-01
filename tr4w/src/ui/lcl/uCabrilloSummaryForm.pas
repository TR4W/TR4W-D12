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
unit uCabrilloSummaryForm;
{$I ..\..\tr4w.inc}

(*
  THE CABRILLO STATION-INFORMATION WINDOW, AS AN LCL FORM.

  It was CreateModalDialog(187, 260, ...) with a dialog proc that built all
  forty-two controls in WM_INITDIALOG and read them back with GetDlgItemTextA
  on WM_CLOSE.  All of that is deleted rather than wrapped.

  THE ROWS ARE STILL BUILT IN CODE, DELIBERATELY, and this is the one place the
  migration's "make it a designed form" rule bends.  The window IS the tag
  table: twenty-one rows, each a label and either a drop-down or an edit,
  decided by CabrilloTagsArray[tag].ctrList.  Drawing them in the designer would
  be a SECOND statement of what a Cabrillo header contains, and this tree has
  already paid for that kind of duplicate -- the enum-indexed radio tables
  drifted until a config saying TS440 selected the TS-140 driver.  Add a tag to
  the enum and its row appears here with no designer work; that is the property
  worth keeping.  The FRAME is designed: the scroll box, the button panel, and
  the anchoring that makes the window resizable.

  READ WHILE IT IS OPEN.  PostUnit needs the operator's answers while the export
  runs, and it used to get them by calling GetDlgItemTextA against a global HWND
  with a control id computed as Ord(tag) + 200 -- from another unit, which is
  the trap CLAUDE.md records for uServerLogForm.  The replacement is
  uCbrSum.CabrilloTagText, which asks THIS form when it is open and the header
  store when it is not.  That fold matters beyond tidiness: the "no dialog"
  branch existed only in PostUnit, so headless /EXPORT and the interactive path
  read the header through two different pieces of code, and they had already
  drifted once.

  MODALITY IS PRESERVED, and so is the order of events on OK: the export action
  runs FIRST and the values are written to the header store as the window
  closes, exactly as the Win32 ExitAndClose path did.  Cancel saves too -- that
  is the old behaviour, odd as it looks, and changing it is a decision for the
  bench and not a side effect of a port.
*)

interface

uses
   Classes,
   SysUtils,
   Forms,
   Controls,
   StdCtrls,
   ExtCtrls,
   uCbrSum,          { CabrilloTags, the tag table, the category lists }
   uTR4WStrings;

type
   { PUBLISHED for streaming: a control binds to a field only when the field is
     published and its name matches the component's Name, and an event binds
     only when the handler is a published method, because TWriter stores it BY
     NAME.  Both directions are checked by Lint-FormFields, which gates the
     build. }
   TfrmCabrilloSummary = class(TForm)
      sbTags: TScrollBox;
      pnlButtons: TPanel;
      btnOK: TButton;
      btnCancel: TButton;

      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure OKClick(Sender: TObject);
      procedure CancelClick(Sender: TObject);
   private
      FRow    : array[CabrilloTags] of TControl;
      FAction : TCabrilloSummaryAction;
      FBuilt  : boolean;

      procedure BuildRows;
      procedure FillCategoryItems(const aTag: CabrilloTags;
                                  const aCombo: TComboBox);
      procedure ApplyErmakCategories;
      procedure LoadValues;
      procedure SaveValues;
   public
      { AnsiString, NOT string.  Every LCL caption and edit is a
        TTranslateString, which is an AnsiString; declaring these as the
        unit's own string type would convert at every control touched, and
        each of those conversions is a place characters can be lost. }
      function  TagText(const aTag: CabrilloTags): AnsiString;
      function  TagItemIndex(const aTag: CabrilloTags): integer;
      function  RowCount: integer;
      function  ListCount: integer;
      function  EmptyListCount: integer;
      property  Action: TCabrilloSummaryAction read FAction write FAction;
   end;

{ Is the window up?  Callers ask this rather than holding a reference: the form
  is created on first use and then lives for the session. }
function CabrilloSummaryOpen: boolean;
function CabrilloSummary: TfrmCabrilloSummary;

procedure ShowCabrilloSummary(const aAction: TCabrilloSummaryAction);

{ Bring it forward.  MainUnit does this after the full-log preview, which the
  export action opens on top of this window. }
procedure FocusCabrilloSummary;

implementation

{$R *.lfm}

uses
   LCLType,               { VK_ESCAPE }
   VC,                    { ErmakSpecification, ERMAKSECTION, CABRILLOSECTION }
   PostUnit,              { ErmakOverlayCategory, NumberErmakOverlayCategories }
   uCabrilloHeader,       { the header store, settings\tr4w.json }
   uLCLFormHelpers,       { ApplyContentMinimumSize, ShowModalOverWin32Parent }
   uHostedFormWindows,
   MainUnit,              { logger }
   Log4D;

type
   { CategoriesArray points at arrays of PAnsiChar and the Win32 code walked
     them with cvrStart + n * 4.  Named, so the stride is the compiler's
     business rather than a literal that is wrong on any other target. }
   PPAnsiCharItem = ^PAnsiChar;

var
   GForm: TfrmCabrilloSummary = nil;

const
   { One row.  The label column is wide enough for ADDRESS-STATE-PROVINCE,
     which is the longest tag name. }
   ROW_PITCH  = 28;
   ROW_TOP    = 8;
   LABEL_LEFT = 12;
   LABEL_W    = 168;
   FIELD_LEFT = 188;
   FIELD_H    = 24;
   RIGHT_GAP  = 16;

{ The header section this window reads and writes.  ERMAK selects a different
  one; ErmakSpecification comes from the contest table's ERMAK_BIT. }
function HeaderSection: string;
begin
   if ErmakSpecification then
      begin
      Result := string(ERMAKSECTION);
      end
   else
      begin
      Result := string(CABRILLOSECTION);
      end;
end;

{ 'CATEGORY-ASSISTED' from '_CATEGORY-ASSISTED'.  The stored key keeps the
  underscore; only the label drops it, which is what the Win32 code did by
  taking the address of the second character. }
function TagLabel(const aTag: CabrilloTags): AnsiString;
begin
   Result := Copy(AnsiString(CabrilloTagsArray[aTag].ctrTag), 2, MaxInt);
end;

procedure TfrmCabrilloSummary.FillCategoryItems(const aTag: CabrilloTags;
                                                const aCombo: TComboBox);
var
   item: PPAnsiCharItem;
   i   : integer;
begin
   { Not every listed tag has a category array -- CategoriesArray stops at
     ctCategoryOverlay.  Indexing past it would read whatever follows. }
   if (aTag < Low(CategoriesArray)) or (aTag > High(CategoriesArray)) then
      begin
      Exit;
      end;

   item := PPAnsiCharItem(CategoriesArray[aTag].cvrStart);
   for i := 0 to CategoriesArray[aTag].cvrCount do
      begin
      aCombo.Items.Add(AnsiString(item^));
      Inc(item);
      end;
end;

procedure TfrmCabrilloSummary.BuildRows;
var
   tag    : CabrilloTags;
   lbl    : TLabel;
   cbo    : TComboBox;
   edt    : TEdit;
   y      : integer;
   fieldW : integer;
begin
   y := ROW_TOP;
   fieldW := sbTags.ClientWidth - FIELD_LEFT - RIGHT_GAP;
   if fieldW < 80 then
      begin
      fieldW := 80;
      end;

   for tag := Low(CabrilloTags) to High(CabrilloTags) do
      begin
      lbl := TLabel.Create(Self);
      lbl.Parent   := sbTags;
      lbl.AutoSize := False;
      lbl.SetBounds(LABEL_LEFT, y + 4, LABEL_W, 18);
      lbl.Caption  := TagLabel(tag);

      if CabrilloTagsArray[tag].ctrList then
         begin
         cbo := TComboBox.Create(Self);
         cbo.Parent := sbTags;
         { csDropDownList, not csDropDown: CBS_DROPDOWNLIST is what the dialog
           created, and a category the sponsor does not publish is not a value
           an operator should be able to type. }
         cbo.Style  := csDropDownList;
         cbo.SetBounds(FIELD_LEFT, y, fieldW, FIELD_H);
         cbo.Anchors := [akLeft, akTop, akRight];
         FillCategoryItems(tag, cbo);
         FRow[tag] := cbo;
         end
      else
         begin
         edt := TEdit.Create(Self);
         edt.Parent := sbTags;
         edt.SetBounds(FIELD_LEFT, y, fieldW, FIELD_H);
         edt.Anchors := [akLeft, akTop, akRight];
         FRow[tag] := edt;
         end;

      Inc(y, ROW_PITCH);
      end;
end;

{ ERMAK's extra category values.  Kept because ErmakSpecification is still set
  from the contest table and these are ordinary Cabrillo header values -- the
  part of ERMAK that is commented out is its own report window, not this.  See
  the banner in uErmak.pas. }
procedure TfrmCabrilloSummary.ApplyErmakCategories;
var
   i: integer;
begin
   if not ErmakSpecification then
      begin
      Exit;
      end;

   if FRow[ctCategoryMode] is TComboBox then
      begin
      TComboBox(FRow[ctCategoryMode]).Items.Add('DIGI');
      end;
   if FRow[ctCategoryOperator] is TComboBox then
      begin
      TComboBox(FRow[ctCategoryOperator]).Items.Add('MULTI-OP-2');
      end;
   if FRow[ctCategoryBand] is TComboBox then
      begin
      TComboBox(FRow[ctCategoryBand]).Items.Add('10M-15M-20M');
      TComboBox(FRow[ctCategoryBand]).Items.Add('80M-40M-160M');
      end;

   { REPLACED, not appended -- CB_RESETCONTENT stood here. }
   if FRow[ctCategoryOverlay] is TComboBox then
      begin
      TComboBox(FRow[ctCategoryOverlay]).Items.Clear;
      for i := 0 to NumberErmakOverlayCategories - 1 do
         begin
         TComboBox(FRow[ctCategoryOverlay]).Items.Add(AnsiString(ErmakOverlayCategory[i]));
         end;
      end;
end;

procedure TfrmCabrilloSummary.LoadValues;
var
   tag     : CabrilloTags;
   section : string;
   saved   : AnsiString;
   idx     : integer;

   { The five whose initial selection is an INDEX held in a global byte rather
     than a string in the header store. }
   function InitialIndex(const aTag: CabrilloTags): integer;
   begin
      { Ord, because these five are ENUM-typed globals in VC.pas and the
        dialog read them through a PByte.  Naming the enum is the point:
        InitialTagsValuesArray was an array of PByte and said nothing about
        what it pointed at. }
      case aTag of
         ctCategoryAssisted: Result := Ord(CategoryAssisted);
         ctCategoryBand:     Result := Ord(CategoryBand);
         ctCategoryMode:     Result := Ord(CategoryMode);
         ctCategoryOperator: Result := Ord(CategoryOperator);
         ctCategoryPower:    Result := Ord(CategoryPower);
      else
         Result := -1;
      end;
   end;

begin
   section := HeaderSection;

   for tag := Low(CabrilloTags) to High(CabrilloTags) do
      begin
      if FRow[tag] is TComboBox then
         begin
         idx := InitialIndex(tag);
         if idx >= 0 then
            begin
            if idx < TComboBox(FRow[tag]).Items.Count then
               begin
               TComboBox(FRow[tag]).ItemIndex := idx;
               end;
            end
         else if CabrilloTagsArray[tag].ctrSave then
            begin
            { Issue #976: restore the saved value into a ctrSave drop-down
              outside the index-based range above -- CATEGORY-STATION, TIME,
              OVERLAY.  By TEXT, because that is what was stored. }
            saved := AnsiString(HeaderValue(section,
                                    string(CabrilloTagsArray[tag].ctrTag)));
            if saved <> '' then
               begin
               TComboBox(FRow[tag]).ItemIndex :=
                  TComboBox(FRow[tag]).Items.IndexOf(saved);
               end;
            end;
         end
      else if FRow[tag] is TEdit then
         begin
         if CabrilloTagsArray[tag].ctrSave then
            begin
            TEdit(FRow[tag]).Text :=
               AnsiString(HeaderValue(section,
                             string(CabrilloTagsArray[tag].ctrTag)));
            end;
         end;
      end;
end;

procedure TfrmCabrilloSummary.SaveValues;
var
   tag     : CabrilloTags;
   section : string;
   value   : AnsiString;
begin
   section := HeaderSection;

   { ONE FILE WRITE, not one per tag.  SetHeaderValue persists immediately by
     design, which is right for a single edit and wrong for twelve in a row.
     The finally is not optional: EndHeaderBatch is what actually saves. }
   BeginHeaderBatch;
   try
      for tag := Low(CabrilloTags) to High(CabrilloTags) do
         begin
         if not CabrilloTagsArray[tag].ctrSave then
            begin
            Continue;
            end;

         value := TagText(tag);

         { GetDlgItemTextA returned a length and the old code only wrote when it
           was non-zero, so an emptied field kept its previous value.  That is
           preserved: clearing a header field here has never removed it, and
           making it do so is a behaviour change for the bench, not for a port. }
         if value <> '' then
            begin
            SetHeaderValue(section, string(CabrilloTagsArray[tag].ctrTag),
                           string(value));
            end;
         end;
   finally
      EndHeaderBatch;
   end;
end;

function TfrmCabrilloSummary.TagText(const aTag: CabrilloTags): AnsiString;
begin
   Result := '';
   if FRow[aTag] is TComboBox then
      begin
      { Text, not Items[ItemIndex]: a csDropDownList combo with nothing selected
        reports the empty string, which is what GetDlgItemTextA gave. }
      Result := TComboBox(FRow[aTag]).Text;
      end
   else if FRow[aTag] is TEdit then
      begin
      Result := TEdit(FRow[aTag]).Text;
      end;
end;

{ What actually got built.  Derived from the controls, not from the enum: the
  question a harness is asking is whether the rows EXIST, and counting the enum
  would answer it from the same table that was supposed to have produced them. }
function TfrmCabrilloSummary.RowCount: integer;
var
   tag: CabrilloTags;
begin
   Result := 0;
   for tag := Low(CabrilloTags) to High(CabrilloTags) do
      begin
      if FRow[tag] <> nil then
         begin
         Inc(Result);
         end;
      end;
end;

function TfrmCabrilloSummary.ListCount: integer;
var
   tag: CabrilloTags;
begin
   Result := 0;
   for tag := Low(CabrilloTags) to High(CabrilloTags) do
      begin
      if FRow[tag] is TComboBox then
         begin
         Inc(Result);
         end;
      end;
end;

{ SEPARATE FROM ListCount, because they fail differently.  A missing drop-down
  is a row built as the wrong control; a drop-down with no items is a field the
  operator can see and cannot answer, and it looks identical to a correct one
  until it is clicked. }
function TfrmCabrilloSummary.EmptyListCount: integer;
var
   tag: CabrilloTags;
begin
   Result := 0;
   for tag := Low(CabrilloTags) to High(CabrilloTags) do
      begin
      if (FRow[tag] is TComboBox) and (TComboBox(FRow[tag]).Items.Count = 0) then
         begin
         Inc(Result);
         end;
      end;
end;

function TfrmCabrilloSummary.TagItemIndex(const aTag: CabrilloTags): integer;
begin
   Result := -1;
   if FRow[aTag] is TComboBox then
      begin
      Result := TComboBox(FRow[aTag]).ItemIndex;
      end;
end;

procedure TfrmCabrilloSummary.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   { ASSIGNED HERE, NOT LEFT IN THE .lfm.  A designed caption is English
     forever; RC_STATIONINFO is in the catalogues. }
   Caption := RC_STATIONINFO;

   if not FBuilt then
      begin
      BuildRows;
      ApplyErmakCategories;
      FBuilt := True;
      end;

   { Every opening: the contest, and so the header section, may have changed
     since the last one. }
   LoadValues;

   ApplyContentMinimumSize(Self);

   { REPORTED, so a harness can see it.  Alt-P is the precedent: it converted
     cleanly, opened with the right title and columns and NOT ONE ROW, and
     nothing in the tree could tell -- the corpus reads files, the unit tests
     cannot construct a form, and the lints check that handlers are wired, not
     that anything calls them.  A row count and the section is the smallest
     thing that would have failed loudly. }
   if logger <> nil then
      begin
      logger.Debug(SysUtils.Format('[CbrSum] built %d row(s), %d list(s), %d empty, section=%s',
                      [RowCount, ListCount, EmptyListCount, HeaderSection]));
      end;
end;

procedure TfrmCabrilloSummary.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   { EVERY exit saves, including Cancel and the window button.  That is what the
     Win32 WM_CLOSE / ExitAndClose path did. }
   SaveValues;
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmCabrilloSummary.HandleKeyDown(Sender: TObject; var Key: word;
                                            Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmCabrilloSummary.OKClick(Sender: TObject);
var
   act: TCabrilloSummaryAction;
begin
   act := FAction;

   { Issue #914: opened standalone from Tools -> Edit Cabrillo Summary there is
     no action, and OK then means the same as Cancel -- close, saving on the way
     out. }
   if not Assigned(act) then
      begin
      Close;
      Exit;
      end;

   { THE ACTION RUNS FIRST AND THE WINDOW IS STILL OPEN, which is not
     incidental: the export reads the operator's answers back out of these
     controls through uCbrSum.CabrilloTagText while it runs. }
   act;

   { Issue #976: close after a successful export rather than dropping the
     operator back at OK/Cancel with nothing left to do. }
   Close;
end;

procedure TfrmCabrilloSummary.CancelClick(Sender: TObject);
begin
   Close;
end;

function CabrilloSummary: TfrmCabrilloSummary;
begin
   Result := GForm;
end;

function CabrilloSummaryOpen: boolean;
begin
   Result := (GForm <> nil) and GForm.Visible;
end;

procedure FocusCabrilloSummary;
begin
   if CabrilloSummaryOpen then
      begin
      GForm.BringToFront;
      end;
end;

procedure ShowCabrilloSummary(const aAction: TCabrilloSummaryAction);
begin
   { The try/except is permanent and deliberate: under FPC an exception that
     escapes into the main loop is a bare RTE with no class, and it takes the
     contest log down with it.  Logging the phase is what makes such a report
     actionable. }
   try
      if GForm = nil then
         begin
         GForm := TfrmCabrilloSummary.Create(Application);
         end;
      GForm.Action := aAction;
      ShowModalOverWin32Parent(GForm, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowCabrilloSummary failed: ' + E.ClassName + ': ' +
                         E.Message);
            end;
         end;
   end;
end;

end.
