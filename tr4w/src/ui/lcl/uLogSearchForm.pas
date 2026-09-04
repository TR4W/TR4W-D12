(*
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
 *)

(* SEARCH LOG -- an LCL form over the same grid the log windows use.

  REPLACES A HAND-BUILT WIN32 MODAL DIALOG. uLogSearch built its controls with
  CreateStatic/CreateEdit/CreateButton inside a CreateModalDialog template, put
  its results in a raw list view from CreateEditableLog, and drove the whole
  thing from a DlgProc with five labels and two gotos.

  NON-MODAL, WHICH NY4I ASKED FOR (2026-09-03): "is it possible to have a
  thread run on the search for an incremental search? I could see that it might
  be useful to have the search window up in a non-modal fashion". It stays open
  beside the log and the operator can keep working.

  INCREMENTAL, AND NOT ON A THREAD. Typing re-runs the search after a 250 ms
  pause -- long enough that a burst of keystrokes costs one search, short
  enough to feel immediate. A THREAD WAS THE OTHER OPTION AND IS THE WRONG ONE
  HERE: the log has exactly one database connection (LogStoreRepository), a
  TSQLConnection belongs to one thread, and giving the search its own
  connection is what left the main grid reading a stale snapshot. The scan is
  the cost, so the fix if it ever becomes one is a WHERE clause, not a thread.

  THE RESULT CAP IS REPORTED. The Win32 version stopped adding rows at
  MAXSEARCHINDEX = 255 and said nothing, so a search matching a thousand QSOs
  showed 255 and looked complete. This one says so. *)
unit uLogSearchForm;

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics, LCLType,
   uLogGrid,
   VC, uLogSource, MainUnit,
   LogStuff;   (* CallWindowString, EscapeDeletedCallEntry -- what to seed with *)

const
   (* AS MANY MATCHES AS ARE WORTH HOLDING. Each is a whole ContestExchange, so
     this is memory, not screen space -- the grid would show any number. A
     search that hits this many is a filter that needs narrowing, and the
     status line says so rather than quietly truncating. *)
   MAX_SEARCH_RESULTS = 5000;

   (* The name this window's bounds are stored under, in the same layout store
     every other window uses. *)
   LAYOUT_NAME = 'SearchLog';

   (* THE ROW THAT MEANS "DO NOT FILTER ON THIS". Named, because it is neither
     a band nor a mode -- and because NY4I asked that the mode read All like
     the band rather than BTH, which is the log's spelling of Both and belongs
     in the log, not in a filter that means "do not filter". *)
   ANY_BAND_CAPTION = 'All';
   ANY_MODE_CAPTION = 'All';

type
   (* A MATCH: the record, and WHERE IT IS IN THE LOG.

     The record is kept rather than re-read. The scan has it in hand, results
     are bounded, and it means painting a result costs no database work at all.

     Index is the record index, which is what the QSO editor addresses. The
     Win32 version kept the same thing in LogSearchIndexesArray, in parallel
     with the list view's rows -- two structures that had to stay in step. *)
   TLogSearchMatch = record
      Index: Int64;
      Qso:   ContestExchange;
   end;

   (* WHICH VALUES THE RESULTS ACTUALLY CONTAIN. *)
   TBandSet = set of BandType;
   TModeSet = set of ModeType;

   TfrmLogSearch = class(TForm)
      lblCall: TLabel;
      edtCall: TEdit;
      lblMode: TLabel;
      cboMode: TComboBox;
      lblBand: TLabel;
      cboBand: TComboBox;
      lblOperator: TLabel;

      (* A COMBO, NOT AN EDIT, so it can do both things the operator wants of
        it: TYPE a partial call sign for an incremental search, or DROP IT DOWN
        and pick from the operators actually present. csDropDown, so the text
        is free. *)
      cboOperator: TComboBox;
      lblStatus: TLabel;
      tmrSearch: TTimer;

      procedure FormCreate(Sender: TObject);
      procedure FormShow(Sender: TObject);
      procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure FilterChanged(Sender: TObject);
      procedure SearchTimer(Sender: TObject);
   private
      FGrid:      TLogGrid;
      FMatches:   array of TLogSearchMatch;
      FTruncated: boolean;

      (* Rebuilding a combo raises OnChange, which would schedule another
        search, which would rebuild the combos again. *)
      FFillingLists: boolean;

      (* Restored ONCE, before the first Show -- see ShowLogSearchForm. *)
      FBoundsRestored: boolean;

      procedure GridFetchRows(Sender: TObject; const aFirstIndex: Int64;
                              var aRows: array of TLogGridRow);
      procedure GridDblClick(Sender: TObject);
      procedure RunSearch;
      procedure ApplyMinimumWidth;

      (* The three filter lists, rebuilt from the records the OTHER filters
        admit -- see the body of RebuildFilterLists. *)
      procedure RebuildFilterLists(const aBands: TBandSet;
                                   const aModes: TModeSet;
                                   const aOperators: TStrings);
      procedure FillCombo(const aCombo: TComboBox; const aItems: TStrings;
                          const aAnyCaption: string; const aKeepText: string);
      function  SelectedBand: BandType;
      function  SelectedMode: ModeType;
   end;

(* THE LOG HAS GAINED A QSO -- RUN THE SEARCH AGAIN.

  NY4I, 2026-09-04: "I had N6 in the search window so I was showing N6TV. I
  then worked a new N6 station in the log. It would be nice if when we added a
  new station to the log, the search ran one more time. That way the new N6
  station would appear in search."

  This is what a non-modal window costs and is worth: it stays open beside the
  log while the operator works, so it has to stay TRUE while the operator
  works. A results list that silently describes the log as it was ten QSOs ago
  is worse than one that was never opened.

  Does nothing when the window is closed or was never opened, so the logging
  path pays nothing for a window nobody is using. *)
procedure LogSearchRefreshIfOpen;

(* THE LIVE BOUNDS, WITHOUT WAITING FOR THE WINDOW TO CLOSE.

  NY4I asked the right question (2026-09-04): "are you saving the window
  position before the window is closed or when the program terminates, or
  both?" It was CLOSE ONLY, which means an operator who moves the window and
  then quits with it still open saves nothing at all.

  That is not a new mistake -- it is the one uPanadapterForm already made and
  fixed on 2026-08-26, in the same words. Riding SaveTR4WPOSFILE gives this
  window the 5-second autosave AND the save-at-exit backstop without a second
  mechanism writing the same file.

  Does nothing when the window has never been opened, so a session that never
  used Search does not write a row for it. *)
procedure SaveLogSearchLayout;

(* Opens it, non-modal, over the main window. Seeds the callsign from the entry
  field, which is what the operator is almost always looking for. *)
procedure ShowLogSearchForm;

implementation

{$R *.lfm}

uses
   uEditQSO,
   uLCLFormHelpers,   (* SaveFormBounds / TryRestoreFormBounds *)
   uMainForm;   (* TR4WMainForm -- this form's owner *)

var
   frmLogSearch: TfrmLogSearch = nil;

procedure ShowLogSearchForm;
begin
   if frmLogSearch = nil then
      begin
      frmLogSearch := TfrmLogSearch.Create(Application);
      end;

   (* THE MAIN WINDOW IS THE OWNER, so switching to another program and back
     brings this forward with it instead of leaving it stranded behind the
     main window -- the defect NY4I hit on the Log Edit window. *)
   if TR4WMainForm <> nil then
      begin
      frmLogSearch.PopupParent := TR4WMainForm;
      end;

   (* BOUNDS BEFORE Show, AND ONLY THE FIRST TIME.

     BEFORE, because the LCL applies the form's Position rule as it shows the
     window -- so a restore from OnShow is overwritten a moment later by
     poMainFormCenter and the window opens centred every time. That is exactly
     what it did (NY4I, 2026-09-04: "the search window position did not save").
     The bounds WERE being saved: the SearchLog row was in settings\tr4w.json
     with the right rectangle in it. Only the restore was too late.

     ONLY THE FIRST TIME, because reshowing must not drag the window back to
     where it was when TR4W started -- an operator who moves it, closes it and
     reopens it expects it where they left it, and the close has already
     written that.

     This is the same pattern uPanadapterForm uses, for the same reasons; its
     comment is where I should have read it. *)
   if not frmLogSearch.FBoundsRestored then
      begin
      frmLogSearch.FBoundsRestored := True;
      TryRestoreFormBounds(frmLogSearch, LAYOUT_NAME);
      end;

   frmLogSearch.Show;
   frmLogSearch.BringToFront;
end;

procedure LogSearchRefreshIfOpen;
begin
   if (frmLogSearch = nil) or (not frmLogSearch.Visible) then
      begin
      Exit;
      end;

   (* THROUGH THE DEBOUNCE, not straight into RunSearch. A run of QSOs logged
     quickly -- a pile-up, or the pending-county drain that logs several from
     one exchange -- would otherwise scan the log once per contact, on the
     thread the operator is typing on. The timer collapses them into one. *)
   frmLogSearch.FilterChanged(nil);
end;

procedure SaveLogSearchLayout;
begin
   if frmLogSearch = nil then
      begin
      Exit;
      end;

   (* THE LIVE VISIBILITY, so quitting with the window open records it as open
     -- which is the point of saving at exit as well as at close. *)
   SaveFormBounds(frmLogSearch, LAYOUT_NAME, frmLogSearch.Visible);
end;

procedure TfrmLogSearch.FormCreate(Sender: TObject);
var
   bt: BandType;
   mt: ModeType;
begin
   (* IN CODE, because TLogGrid is not a registered design-time component and a
     .lfm naming a class the loader cannot resolve fails at the first bad
     property with the window half built. *)
   FGrid := TLogGrid.Create(Self);
   FGrid.Parent     := Self;
   FGrid.Left       := 0;
   FGrid.Top        := 40;
   FGrid.Width      := ClientWidth;
   FGrid.Height     := ClientHeight - 40 - 24;
   FGrid.Anchors    := [akLeft, akTop, akRight, akBottom];
   (* FITTED AND STRETCHED, not the declared widths. This is a window the
     operator resizes, and declared widths leave a band of empty grid down the
     right-hand side of a wide one. The MAIN window log keeps the declared
     widths -- its layout is what an operator has been reading for years. *)
   FGrid.Sizing := lgsFitAndFill;
   FGrid.OnFetchRows := @GridFetchRows;
   FGrid.OnDblClick  := @GridDblClick;
   ApplyMainFontTo(FGrid.Font);
   FGrid.DefaultRowHeight := ws + 2;
   FGrid.BuildColumns;

   (* THE LISTS ARE BUILT FROM THE LOG, not from the enums -- see
     RebuildFilterLists. Filled here with the contest's own bands so the window
     is usable before anything has been searched for. *)
   RebuildFilterLists([], [], cboOperator.Items);
end;

procedure TfrmLogSearch.FormShow(Sender: TObject);
begin
   (* SEEDED FROM THE ENTRY FIELD. The Win32 version did the same, falling back
     to the call an operator had just escaped out of. *)
   if CallWindowString <> '' then
      begin
      edtCall.Text := string(AnsiString(CallWindowString));
      end
   else
      begin
      edtCall.Text := string(AnsiString(EscapeDeletedCallEntry));
      end;

   ApplyMinimumWidth;

   if logger <> nil then
      begin
      logger.Info('[LogSearch] window opened at (%d,%d) %dx%d, seeded with "%s", ' +
                  'min width %d',
                  [Left, Top, Width, Height, edtCall.Text, Constraints.MinWidth]);
      end;

   RunSearch;
   edtCall.SetFocus;
end;

procedure TfrmLogSearch.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   tmrSearch.Enabled := False;

   (* WHERE IT WAS, so it comes back there. NY4I: "the position of the search
     window should be saved (as all window positions should be saved) and
     restored upon reopening." *)
   SaveFormBounds(Self, LAYOUT_NAME, True);

   CloseAction := caHide;
end;

(* ESCAPE CLOSES IT. A Win32 DialogBox did this for free and a TForm does not --
  Lint-FormDefaults exists because that difference is invisible until an
  operator is stuck in a window with no keyboard way out. *)
procedure TfrmLogSearch.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   if (Key = VK_ESCAPE) and (Shift = []) then
      begin
      Key := 0;
      Close;
      end;
end;

(* A KEYSTROKE RESTARTS THE CLOCK RATHER THAN THE SEARCH, so typing a callsign
  costs one search instead of one per letter. *)
procedure TfrmLogSearch.FilterChanged(Sender: TObject);
begin
   (* Rebuilding a list raises OnChange on the way past; that is not the
     operator changing a filter. *)
   if FFillingLists then
      begin
      Exit;
      end;

   tmrSearch.Enabled := False;
   tmrSearch.Enabled := True;
end;

procedure TfrmLogSearch.SearchTimer(Sender: TObject);
begin
   tmrSearch.Enabled := False;
   RunSearch;
end;

(* ONE PREDICATE PER FILTER, SEPARATELY, because the drop-downs need to know
  what the OTHER filters admit -- see RunSearch. As one combined test they
  could only answer "does this row survive everything", which is not the
  question a facet list asks.

  The Win32 version expressed each of these as a `goto NextRecord`. *)
function LoggedContact(const aQso: ContestExchange): boolean;
begin
   Result := aQso.ceRecordKind in [rkQSO, rkQTCR, rkQTCS];
end;

function CallMatches(const aQso: ContestExchange; const aCall: AnsiString): boolean;
begin
   (* SUBSTRING, not prefix -- operators rely on it to find a callsign they
     only partly remember. *)
   Result := (aCall = '') or (Pos(aCall, AnsiString(aQso.Callsign)) > 0);
end;

function OperatorMatches(const aQso: ContestExchange; const aOperator: AnsiString): boolean;
begin
   (* SUBSTRING TOO, AND IT WAS AN EXACT MATCH. NY4I, 2026-09-04: "when I enter
     a partial call in the Operator field, it does not do the same incremental
     search. While there are not that many similar operators, the inconsistency
     is obvious." Two boxes that look alike must behave alike. *)
   Result := (aOperator = '') or
             (Pos(aOperator, AnsiString(aQso.ceOperator)) > 0);
end;

function TfrmLogSearch.SelectedBand: BandType;
begin
   Result := AllBands;
   if (cboBand.ItemIndex >= 0) and
      (cboBand.Items.Objects[cboBand.ItemIndex] <> nil) then
      begin
      Result := BandType(PtrInt(cboBand.Items.Objects[cboBand.ItemIndex]) - 1);
      end;
end;

function TfrmLogSearch.SelectedMode: ModeType;
begin
   Result := Both;
   if (cboMode.ItemIndex >= 0) and
      (cboMode.Items.Objects[cboMode.ItemIndex] <> nil) then
      begin
      Result := ModeType(PtrInt(cboMode.Items.Objects[cboMode.ItemIndex]) - 1);
      end;
end;

(* FILL A DROP-DOWN, KEEPING WHAT WAS CHOSEN.

  The lists change with every search, so a selection cannot be an INDEX -- the
  value it named will be somewhere else next time, or gone. Kept by TEXT and
  restored by text; if it is no longer offered, the list falls back to its
  "any" row, which is the honest outcome of a filter that now matches nothing.

  The value rides in Objects as Ord + 1, because nil is how "this is the any
  row" is told apart from ordinal zero. *)
procedure TfrmLogSearch.FillCombo(const aCombo: TComboBox; const aItems: TStrings;
                                  const aAnyCaption: string; const aKeepText: string);
var
   i: integer;
begin
   aCombo.Items.BeginUpdate;
   try
      aCombo.Items.Clear;
      aCombo.Items.AddObject(aAnyCaption, nil);
      for i := 0 to aItems.Count - 1 do
         begin
         aCombo.Items.AddObject(aItems[i], aItems.Objects[i]);
         end;
   finally
      aCombo.Items.EndUpdate;
   end;

   aCombo.ItemIndex := aCombo.Items.IndexOf(aKeepText);
   if aCombo.ItemIndex < 0 then
      begin
      aCombo.ItemIndex := 0;
      end;
end;

(* THE FILTERS OFFER WHAT THE RESULTS CONTAIN.

  NY4I, 2026-09-04: "if I search for a partial callsign like N6, I see all N6
  calls. But if I then do a search of Band, I see all possible bands versus the
  band box being a subset of just what is in the grid ... adopt the idea that
  the search options like Mode, Band and Operator are built of the set of
  displayed records."

  EACH LIST IS BUILT FROM THE ROWS THE *OTHER* FILTERS ADMIT, not from the
  results. That distinction is the whole design: built from the results, a Band
  list narrowed to 20m the moment 20m was chosen, and there would be no way
  back to 15m without clearing the filter first. Excluding a list's own filter
  keeps every band the rest of the search can still reach.

  WITH NOTHING SEARCHED FOR THERE ARE NO ROWS TO ASK, so the band list falls
  back to the bands this contest actually uses -- WARC BANDS ENABLE and VHF
  BANDS ENABLE, from BandChangeArray, rather than every band the enum can
  name. NY4I asked for that too, and it is why the list offered 10G and 24G to
  a station that had worked 20m and 15m. *)
procedure TfrmLogSearch.RebuildFilterLists(const aBands: TBandSet;
                                           const aModes: TModeSet;
                                           const aOperators: TStrings);
var
   bands, modes: TStringList;
   bt: BandType;
   mt: ModeType;
   i:  integer;
begin
   FFillingLists := True;
   bands := TStringList.Create;
   modes := TStringList.Create;
   try
      if aBands <> [] then
         begin
         for bt := Low(BandType) to High(BandType) do
            begin
            if (bt in aBands) and (bt <> AllBands) and (bt <> NoBand) then
               begin
               bands.AddObject(string(AnsiString(BandStringsArray[bt])),
                               TObject(PtrInt(Ord(bt)) + 1));
               end;
            end;
         end
      else
         begin
         for bt := Low(BandType) to High(BandType) do
            begin
            if (bt = AllBands) or (bt = NoBand) then
               begin
               Continue;
               end;
            if not BandIsEnabledForContest(bt) then
               begin
               Continue;
               end;
            bands.AddObject(string(AnsiString(BandStringsArray[bt])),
                            TObject(PtrInt(Ord(bt)) + 1));
            end;
         end;

      if aModes <> [] then
         begin
         for mt := CW to FM do
            begin
            if (mt in aModes) and (mt <> Both) then
               begin
               modes.AddObject(string(AnsiString(ModeStringArray[mt])),
                               TObject(PtrInt(Ord(mt)) + 1));
               end;
            end;
         end
      else
         begin
         for mt := CW to FM do
            begin
            if mt <> Both then
               begin
               modes.AddObject(string(AnsiString(ModeStringArray[mt])),
                               TObject(PtrInt(Ord(mt)) + 1));
               end;
            end;
         end;

      (* ALL, NOT BTH. NY4I: "the mode of BTH should be All like Band." The
        constant behind it is Both and the table spells it BTH; that spelling
        belongs to the log, not to a filter that means "do not filter". *)
      FillCombo(cboBand, bands, ANY_BAND_CAPTION, cboBand.Text);
      FillCombo(cboMode, modes, ANY_MODE_CAPTION, cboMode.Text);

      (* THE OPERATOR BOX KEEPS WHAT WAS TYPED. It is csDropDown -- the text is
        a substring filter, and the list is a convenience beside it -- so
        replacing the text with a list entry would fight the operator
        mid-keystroke. *)
      i := cboOperator.SelStart;
      cboOperator.Items.BeginUpdate;
      try
         cboOperator.Items.Assign(aOperators);
      finally
         cboOperator.Items.EndUpdate;
      end;
      cboOperator.SelStart := i;
   finally
      bands.Free;
      modes.Free;
      FFillingLists := False;
   end;
end;

(* THE NARROWEST THIS WINDOW MAY BE.

  NY4I, 2026-09-04: "i should not be able to resize smaller than a form that
  shows all the columns." Dragging it narrower simply dropped columns off the
  right-hand edge with nothing to say they existed.

  COMPUTED, NOT WRITTEN DOWN, so adding a column to a contest cannot leave the
  constraint stale.

  RE-APPLIED AFTER EVERY SEARCH: at FormShow the grid holds no rows, so it
  measures its headings and answers far too small. The results are what has to
  fit.

  The filter row has its own floor -- the Operator box is the right-most
  control on it. *)
procedure TfrmLogSearch.ApplyMinimumWidth;
var
   fitWidth: integer;
   rowWidth: integer;
begin
   if FGrid = nil then
      begin
      Exit;
      end;

   fitWidth := FGrid.MinimumWidth + (Width - FGrid.ClientWidth);

   rowWidth := cboOperator.Left + cboOperator.Width + 12;
   if rowWidth > fitWidth then
      begin
      fitWidth := rowWidth;
      end;

   Constraints.MinWidth := fitWidth;
end;

procedure TfrmLogSearch.RunSearch;
var
   call:     AnsiString;
   oper:     AnsiString;
   band:     BandType;
   mode:     ModeType;
   qso:      ContestExchange;
   recIndex: Int64;
   found:    integer;
   started:  QWord;
   bands:    TBandSet;
   modes:    TModeSet;
   ops:      TStringList;
   passCall, passOper, passBand, passMode: boolean;
begin
   call := AnsiString(UpperCase(Trim(edtCall.Text)));
   oper := AnsiString(UpperCase(Trim(cboOperator.Text)));

   band := SelectedBand;
   mode := SelectedMode;

   SetLength(FMatches, 0);
   FTruncated := False;
   FGrid.RecordCount := 0;

   bands := [];
   modes := [];
   ops   := TStringList.Create;
   try
      ops.Sorted := True;
      ops.Duplicates := dupIgnore;

      (* NOTHING TO SEARCH FOR IS NOT A SEARCH FOR EVERYTHING. The Win32
        version exited on an empty callsign AND operator, and so does this --
        otherwise every keystroke that clears the box scans the whole log to
        list it. *)
      if (call = '') and (oper = '') then
         begin
         FGrid.MatchText   := '';
         lblStatus.Caption := '';
         RebuildFilterLists([], [], ops);
         Exit;
         end;

      if not LogSourceIsOpen then
         begin
         if not LogSourceOpen then
            begin
            lblStatus.Caption := 'the log could not be read';
            Exit;
            end;
         end;

      started  := GetTickCount64;
      found    := 0;
      recIndex := -1;

      LogSourceRewind;
      while LogSourceNext(qso) do
         begin
         Inc(recIndex);

         if not LoggedContact(qso) then
            begin
            Continue;
            end;

         passCall := CallMatches(qso, call);
         passOper := OperatorMatches(qso, oper);
         passBand := (band = AllBands) or (qso.Band = band);
         passMode := (mode = Both) or (qso.Mode = mode);

         (* EACH LIST IGNORES ITS OWN FILTER -- see RebuildFilterLists. *)
         if passCall and passOper and passMode then
            begin
            Include(bands, qso.Band);
            end;
         if passCall and passOper and passBand then
            begin
            Include(modes, qso.Mode);
            end;
         if passCall and passBand and passMode then
            begin
            ops.Add(string(AnsiString(qso.ceOperator)));
            end;

         if not (passCall and passOper and passBand and passMode) then
            begin
            Continue;
            end;

         if found >= MAX_SEARCH_RESULTS then
            begin
            FTruncated := True;
            Break;
            end;

         SetLength(FMatches, found + 1);
         FMatches[found].Index := recIndex;
         FMatches[found].Qso   := qso;
         Inc(found);
         end;

      (* What was searched for, so the grid can show where it matched. Set
        before the count, so the first paint already has it. *)
      FGrid.MatchText := string(call);

      FGrid.Reload;
      FGrid.RecordCount := found;

      RebuildFilterLists(bands, modes, ops);
      ApplyMinimumWidth;

      if logger <> nil then
         begin
         logger.Info('[LogSearch] call="%s" op="%s" band=%d mode=%d -> %d match(es) ' +
                     'in %d record(s), %d ms%s',
                     [call, oper, Ord(band), Ord(mode), found, recIndex + 1,
                      GetTickCount64 - started,
                      BoolToStr(FTruncated, ' TRUNCATED', '')]);
         end;

      if FTruncated then
         begin
         lblStatus.Caption := Format('%d matches shown of more than that -- narrow the search (%d ms)',
                                     [found, GetTickCount64 - started]);
         end
      else
         begin
         lblStatus.Caption := Format('%d match(es) in %d ms',
                                     [found, GetTickCount64 - started]);
         end;
   finally
      ops.Free;
   end;
end;

(* THE MATCHES ARE ALREADY IN MEMORY, so a repaint costs no database work.
  aFirstIndex indexes the RESULTS, not the log. *)
procedure TfrmLogSearch.GridFetchRows(Sender: TObject; const aFirstIndex: Int64;
                                      var aRows: array of TLogGridRow);
var
   i: integer;
   m: Int64;
begin
   for i := Low(aRows) to High(aRows) do
      begin
      m := aFirstIndex + (i - Low(aRows));
      if (m < 0) or (m >= Length(FMatches)) then
         begin
         Break;
         end;

      LogRowTextFor(FMatches[m].Qso, aRows[i].Text);
      aRows[i].Deleted := FMatches[m].Qso.ceQSO_Deleted;
      aRows[i].XQSO    := FMatches[m].Qso.ceXQSO;
      aRows[i].Valid   := True;
      end;
end;

procedure TfrmLogSearch.GridDblClick(Sender: TObject);
var
   sel: Int64;
begin
   sel := FGrid.SelectedRecord;
   if (sel < 0) or (sel >= Length(FMatches)) then
      begin
      Exit;
      end;

   (* THE LOG RECORD, not the result row. Keeping the record index beside the
     record is what makes that impossible to get wrong; the Win32 version held
     it in a second array indexed by list-view row. *)
   IndexOfItemInLogForEdit := FMatches[sel].Index;

   (* The editor reads and writes the log itself, so the source is closed
     around it rather than left open under a window that is about to change
     the record underneath us. *)
   LogSourceClose;
   try
      OpenEditQSOWindow(Self.Handle);
   finally
      (* RE-RUN, because the edit may have changed whether the record still
        matches. The Win32 version did this by posting its own Search button. *)
      RunSearch;
   end;
end;

end.
