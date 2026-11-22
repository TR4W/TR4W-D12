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
   uSettingsModel,   { Settings.Contest.Category* -- the entry's categories }
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
      procedure FillOverlayItems;
      procedure FillStationItems;
      procedure LoadValues;
      procedure SaveValues;
      procedure CommitCategory(const aTag: CabrilloTags;
                               const aCommand: string;
                               const aSpellings: array of string;
                               aCurrent: integer);
      procedure CommitCategories;
      procedure CommitCategoryPower;
      procedure CommitOverlay;
      procedure CommitStation;
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
   VC,                    (* CABRILLOSECTION *)
   PostUnit,              (* OverlayCategory, Contest *)
   uCabrilloHeader,       { the header store, settings\tr4w.json }
   uOperatorList,         (* OperatorListFromLog -- the OPERATORS row *)
   uLCLFormHelpers,       { ApplyContentMinimumSize, ShowModalOverWin32Parent }
   MainUnit,              { logger, RescoreLog }
   Log4D,
   (* CATEGORY-POWER, ONE VALUE -- M9b, design 7.6. See CommitCategoryPower. *)
   uCategoryPowerChange,
   uCFG,                  (* ApplyContestEdit -- the contest-parameter route *)
   LogDupe,               (* QSOTotals -- is anything logged yet *)
   LogWind,               (* QuickDisplay -- the main window's notice *)
   (* LogStoreRecordContestStatement -- a category change is written into the
     contest database when it is made (Q61). *)
   uLogStore,
   (* ContestIdentity -- the session contest's sponsor overlays, issue 122 *)
   uContestRegistry,
   uAppStrings;           (* SCategoryPowerChangedRescored *)

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

(* The header section this window reads and writes: CABRILLOSECTION for every
  contest and station, as uCbrSum.CabrilloTagText reads it (issue 74,
  2026-11-22 -- the ERMAK store a Russian station was switched to is gone). *)
function HeaderSection: string;
begin
   Result := CABRILLOSECTION;
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
   values: TArray<string>;
   i     : integer;
begin
   (* A LIST OF STRINGS, NOT A POINTER AND A COUNT.  This walked a
     ^PAnsiChar with Inc() over a const table of addresses, and needed a
     bounds test first because the table stopped short of the tag range.
     An empty result says "no list" on its own. *)
   values := CategoryValuesFor(aTag);
   for i := 0 to High(values) do
      begin
      aCombo.Items.Add(values[i]);
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

         { CLOSED BY DEFAULT, OPEN WHERE THE TAG SAYS SO.  CBS_DROPDOWNLIST is
           what the Win32 dialog created for every list, and for a category
           whose legal values Cabrillo v3 actually fixes that is right -- a
           typed CATEGORY-MODE is a rejected log.

           ctrOpen marks the tags where the published list is a suggestion.
           CATEGORY-TRANSMITTER is the one today: sponsors routinely ask for a
           value outside ONE/TWO/LIMITED/UNLIMITED/SWL, and until now that tag
           was a bare edit, which meant the five official values were not
           offered at all. }
         if CabrilloTagsArray[tag].ctrOpen then
            begin
            cbo.Style := csDropDown;
            end
         else
            begin
            cbo.Style := csDropDownList;
            end;
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

(* THE OVERLAY ROW, REFILLED AT EVERY OPENING -- issue 122. The window lives
  for the session and BuildRows runs once, but the overlays a sponsor names
  belong to the contest open NOW (ContestIdentity(Contest).
  CabrilloOverlayCategories), so they are asked here, before LoadValues
  restores the saved choice -- a saved POTA must be in the list to be
  selected again. The base list is the standard one; uCbrSum.OverlayValuesWith
  adds the sponsor's, blank last. (ERMAK's replacement overlay list and its
  extra mode, operator and band values went with issue 74, 2026-11-22: a
  sponsor that needs one states it in its class.) *)
procedure TfrmCabrilloSummary.FillOverlayItems;
var
   values : TArray<string>;
   cbo    : TComboBox;
   i      : integer;
begin
   if not (FRow[ctCategoryOverlay] is TComboBox) then
      begin
      Exit;
      end;
   cbo := TComboBox(FRow[ctCategoryOverlay]);

   values := OverlayValuesWith(OverlayCategory,
                               ContestIdentity(Contest).CabrilloOverlayCategories);

   cbo.Items.BeginUpdate;
   try
      cbo.Items.Clear;
      for i := 0 to High(values) do
         begin
         cbo.Items.Add(AnsiString(values[i]));
         end;
   finally
      cbo.Items.EndUpdate;
   end;
end;

(* THE STATION ROW, REFILLED AT EVERY OPENING (2026-11-20, the Florida QSO
  Party) -- FillOverlayItems' reason: a sponsor that names its own station
  categories (ContestIdentity(Contest).CabrilloStationCategories) names them
  for the contest open NOW. uCbrSum.StationValuesWith composes the list. *)
procedure TfrmCabrilloSummary.FillStationItems;
var
   values : TArray<string>;
   cbo    : TComboBox;
   i      : integer;
begin
   if not (FRow[ctCategoryStation] is TComboBox) then
      begin
      Exit;
      end;
   cbo := TComboBox(FRow[ctCategoryStation]);

   values := StationValuesWith(StationCategory,
                               ContestIdentity(Contest).CabrilloStationCategories);

   cbo.Items.BeginUpdate;
   try
      cbo.Items.Clear;
      for i := 0 to High(values) do
         begin
         cbo.Items.Add(AnsiString(values[i]));
         end;
   finally
      cbo.Items.EndUpdate;
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
         ctCategoryAssisted: Result := Ord(Settings.Contest.CategoryAssisted);
         ctCategoryBand:     Result := Ord(Settings.Contest.CategoryBand);
         ctCategoryMode:     Result := Ord(Settings.Contest.CategoryMode);
         ctCategoryOperator: Result := Ord(Settings.Contest.CategoryOperator);
         ctCategoryPower:    Result := Ord(Settings.Contest.CategoryPower);
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
         else if tag = ctCategoryOverlay then
            begin
            (* THE CONTEST'S OVERLAY -- issue 122: the setting (this contest's
              statement, else the station default), selected by TEXT after
              FillOverlayItems put the contest's own values in the list. A
              value the list does not offer is left unselected; '' selects
              the blank "no overlay" item. *)
            TComboBox(FRow[tag]).ItemIndex :=
               TComboBox(FRow[tag]).Items.IndexOf(
                  AnsiString(Trim(Settings.Contest.CategoryOverlay)));
            end
         else if tag = ctCategoryStation then
            begin
            (* THE CONTEST'S STATION CATEGORY (2026-11-20): what the header
              will write -- the setting, else the station default
              (uCbrSum.StationCategoryInForce) -- selected by TEXT after
              FillStationItems put the contest's own values in the list. A
              value the list does not offer is left unselected. *)
            TComboBox(FRow[tag]).ItemIndex :=
               TComboBox(FRow[tag]).Items.IndexOf(
                  AnsiString(StationCategoryInForce));
            end
         else if CabrilloTagsArray[tag].ctrSave then
            begin
            { Issue #976: restore the saved value into a ctrSave drop-down
              outside the index-based range above -- CATEGORY-STATION, TIME,
              OVERLAY.  By TEXT, because that is what was stored. }
            saved := AnsiString(HeaderValue(section,
                                    CabrilloTagsArray[tag].ctrTag));
            if saved = '' then
               begin
               (* NOTHING STORED IS "NO CATEGORY" -- the blank choice every
                 category list ends in (uCbrSum.CategoryValuesFor), and what
                 the export writes for it: the bare tag. Selected, so the row
                 shows the answer the header will give. *)
               TComboBox(FRow[tag]).ItemIndex :=
                  TComboBox(FRow[tag]).Items.IndexOf('');
               end
            else
               begin
               idx := TComboBox(FRow[tag]).Items.IndexOf(saved);
               if idx >= 0 then
                  begin
                  TComboBox(FRow[tag]).ItemIndex := idx;
                  end
               else if CabrilloTagsArray[tag].ctrOpen then
                  begin
                  { AN OPEN LIST MUST BE ABLE TO RELOAD WHAT IT SAVED.  Setting
                    ItemIndex to the -1 that IndexOf returned would silently
                    blank the sponsor-specific value the operator typed last
                    time -- the field would look untouched and the header would
                    lose it on the next save. }
                  TComboBox(FRow[tag]).Text := saved;
                  end
               else
                  begin
                  { A closed list holding a value it does not offer: leave it
                    unselected rather than invent a selection. }
                  TComboBox(FRow[tag]).ItemIndex := -1;
                  end;
               end;
            end;
         end
      else if FRow[tag] is TEdit then
         begin
         if tag = ctOperators then
            begin
            (* THE LOG'S OWN LIST, READ-ONLY: contacts only, most first. A typed
              value would be ignored by every writer, so it is not offered.
              uCbrSum.CabrilloTagText answers the same routine while the
              window is open. *)
            TEdit(FRow[tag]).ReadOnly := True;
            TEdit(FRow[tag]).Text     := AnsiString(OperatorListFromLog);
            end
         else if CabrilloTagsArray[tag].ctrSave then
            begin
            TEdit(FRow[tag]).Text :=
               AnsiString(HeaderValue(section,
                             CabrilloTagsArray[tag].ctrTag));
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

         (* GetDlgItemTextA returned a length and the old code only wrote when it
           was non-zero, so an emptied field kept its previous value.  That is
           preserved for a typed field: clearing a header field here has never
           removed it. *)
         (* EXCEPT A CHOSEN BLANK CATEGORY (NY4I, 2026-10-29). Each category
           list ends in a blank "no category" item, and choosing it must
           stick, or the row reverts on the next open and the export writes
           the old value. A drop-down with an item selected is a choice; one
           with nothing selected and no text is still "left alone". Writing ''
           removes the key, which HeaderValue answers as '' -- the same
           thing. *)
         if (value <> '') or
            ((FRow[tag] is TComboBox) and
             (TComboBox(FRow[tag]).ItemIndex >= 0)) then
            begin
            SetHeaderValue(section, CabrilloTagsArray[tag].ctrTag,
                           string(value));
            end;
         end;
   finally
      EndHeaderBatch;
   end;
end;

(* THE CATEGORY-POWER ROW WRITES THE ONE SETTING SCORING READS -- M9b, design
  7.6. NY4I: "If they select QRP right before cabrillo generation, we have to
  assume they know what they are doing" -- so the last touch wins, here as in
  the New Contest dialog, and a change with QSOs logged rescores the log and
  says so ("Maybe we remind them of that mid-contest but let it be changed").

  The decision is uCategoryPowerChange's, unit tested; this does what it says.
  RUN BEFORE THE EXPORT ACTION (OKClick) as well as on close, so a Cabrillo
  file's CLAIMED-SCORE is computed with the power its header declares. The
  second call finds nothing changed and does nothing. *)
procedure TfrmCabrilloSummary.CommitCategoryPower;
var
   chosen: tCategoryPower;
   change: TCategoryPowerChange;
begin
   (* Nothing selected changes nothing -- see CommitCategory. *)
   if TagItemIndex(ctCategoryPower) < 0 then
      begin
      Exit;
      end;

   change := DecideCategoryPowerChange(Settings.Contest.CategoryPower,
                                       string(TagText(ctCategoryPower)),
                                       QSOTotals[AllBands, Both],
                                       chosen);
   if change = cpcUnchanged then
      begin
      Exit;
      end;

   if not ApplyContestEdit('CATEGORY-POWER', tCategoryPowerSA[chosen]) then
      begin
      Exit;
      end;
   (* INTO THE CONTEST DATABASE NOW, not only at a clean close -- Q61. *)
   LogStoreRecordContestStatement('CATEGORY-POWER');

   if change = cpcSetAndRescore then
      begin
      RescoreLog;
      QuickDisplay(SysUtils.Format(SCategoryPowerChangedRescored,
                                   [tCategoryPowerSA[chosen]]));
      end;
end;

(* ASSISTED, BAND, MODE AND OPERATOR WRITE THE ONE SETTING EACH -- Q61 (NY4I,
  2026-10-16: "Yes."), the same way the POWER row does (7.6), and for the
  same reason: the window used to write MODE to a copy in settings\tr4w.json
  and the other three nowhere, so a change made here was lost on close and a
  headless /EXPORT never saw it.

  ApplyContestEdit -- the CONTEST-PARAMETER route (NY4I, 2026-11-15): it
  applies the value, records it as the operator's statement and tells a
  multi-op peer (all four are SHARED_WITH_PEERS) -- then the statement goes
  into the contest database at once. It writes NOTHING to settings\tr4w.json;
  SetCFGCommandValue, used here until that date, also put a copy in the
  legacy `commands` bucket there, a station default. NO RESCORE: no contest scores a QSO by these
  (uCategoryPowerChange.CategoryChoiceIndex says why MODE's bonus is not an
  exception). An unchanged row, or a value no setting can hold, does nothing. *)
procedure TfrmCabrilloSummary.CommitCategory(const aTag: CabrilloTags;
                                             const aCommand: string;
                                             const aSpellings: array of string;
                                             aCurrent: integer);
var
   idx: integer;
begin
   (* NOTHING SELECTED CHANGES NOTHING. The blank "no category" item is a
     spelling now (the *UNSET member's ''), so the empty text of a row with
     NO item selected would otherwise read as choosing it. *)
   if TagItemIndex(aTag) < 0 then
      begin
      Exit;
      end;

   idx := CategoryChoiceIndex(aSpellings, aCurrent, string(TagText(aTag)));
   if idx < 0 then
      begin
      Exit;
      end;

   if ApplyContestEdit(aCommand, aSpellings[idx]) then
      begin
      LogStoreRecordContestStatement(aCommand);
      end;
end;

(* EVERY CATEGORY ROW, POWER LAST -- its rescore then scores with the other
  four already in force. Run wherever POWER was: before the export action and
  on close. *)
procedure TfrmCabrilloSummary.CommitCategories;
begin
   CommitCategory(ctCategoryAssisted, 'CATEGORY-ASSISTED', tCategoryAssistedSA,
                  Ord(Settings.Contest.CategoryAssisted));
   CommitCategory(ctCategoryBand, 'CATEGORY-BAND', tCategoryBandSA,
                  Ord(Settings.Contest.CategoryBand));
   CommitCategory(ctCategoryMode, 'CATEGORY-MODE', tCategoryModeSA,
                  Ord(Settings.Contest.CategoryMode));
   CommitCategory(ctCategoryOperator, 'CATEGORY-OPERATOR', tCategoryOperatorSA,
                  Ord(Settings.Contest.CategoryOperator));
   CommitOverlay;
   CommitStation;
   CommitCategoryPower;
end;

(* THE STATION ROW WRITES THIS CONTEST'S SETTING (2026-11-20) -- the overlay's
  route and rule. Compared with what the header would write
  (StationCategoryInForce), so opening and closing the window over an
  inherited station default records nothing. *)
procedure TfrmCabrilloSummary.CommitStation;
var
   value: string;
begin
   if not OverlayChoiceToCommit(TagItemIndex(ctCategoryStation) >= 0,
                                string(TagText(ctCategoryStation)),
                                StationCategoryInForce,
                                value) then
      begin
      Exit;
      end;
   if ApplyContestEdit('CATEGORY-STATION', value) then
      begin
      LogStoreRecordContestStatement('CATEGORY-STATION');
      end;
end;

(* THE OVERLAY ROW WRITES THIS CONTEST'S SETTING -- issue 122 (NY4I,
  2026-11-19: Cabrillo header fields are "a contest item seeded by the
  station default"). The same route as the categories (ApplyContestEdit,
  then the log at once); the decision is uCbrSum.OverlayChoiceToCommit. *)
procedure TfrmCabrilloSummary.CommitOverlay;
var
   value: string;
begin
   if not OverlayChoiceToCommit(TagItemIndex(ctCategoryOverlay) >= 0,
                                string(TagText(ctCategoryOverlay)),
                                Settings.Contest.CategoryOverlay,
                                value) then
      begin
      Exit;
      end;
   if ApplyContestEdit('CATEGORY-OVERLAY', value) then
      begin
      LogStoreRecordContestStatement('CATEGORY-OVERLAY');
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

   { ASSIGNED HERE, NOT LEFT IN THE .lfm.  A designed caption is English
     forever; RC_STATIONINFO is in the catalogues. }
   Caption := RC_STATIONINFO;

   if not FBuilt then
      begin
      BuildRows;
      FBuilt := True;
      end;

   { Every opening: the contest, and so the header section, may have changed
     since the last one. }
   FillOverlayItems;
   FillStationItems;
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
   CommitCategories;
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
   (* AFTER THE POWER IS COMMITTED, though -- M9b: the export's
     CLAIMED-SCORE must be scored with the power its header says. And the
     other four categories with it (Q61): one value each, in force before
     the file is written. *)
   CommitCategories;
   CabrilloExportRefused := False;
   act;

   { The export refused the header (an empty LOCATION) and said so: stay open so
     the operator can fix the field. Closing here dropped him out of the form
     with the field still empty (NY4I, 2026-11-20). }
   if CabrilloExportRefused then
      begin
      CabrilloExportRefused := False;
      Exit;
      end;

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
      ShowModalOverWin32Parent(GForm);
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
