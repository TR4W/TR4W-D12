unit uTestNewContestForm;
{$I ..\..\src\tr4w.inc}

(* THE NEW CONTEST DIALOG NAMES THE BUILD IN ITS TITLE.

  NY4I, 2026-10-16: the first window of a session read
  " - Open configuration file or start a new contest" -- no program name and no
  version, so he could not see which build he was running. Two writers set the
  caption: uNewContest.PrepareForm wrote TR4W_CURRENTVERSION + the constant,
  and the form's own OnShow, which runs AFTER it, overwrote that with the bare
  constant -- a string that starts with ' - ' because it was written to follow
  the version. The form is the one writer now.

  THE FORM IS STREAMED FROM ITS RESOURCE AND ITS OnShow IS INVOKED THROUGH THE
  EVENT THE .lfm WIRES, not by calling HandleShow by name -- so this also fails
  if the .lfm stops binding OnShow, which is the half a pin on the caption
  function alone could not see. It is never shown: Show would put a window on
  the desktop of whoever runs the suite. *)

interface

uses
   SysUtils, Classes, Forms, Controls, Graphics,
   StdCtrls,          (* TScrollStyle -- the file grid scrolls when it cannot grow *)
   Grids,             (* goRowSelect, goCellHints -- the file grid's options *)
   LCLType,           (* VK_DOWN *)
   uContestNames,     (* ContestFromName -- the test logs' contests *)
   uTR4WTestFramework,
   uTR4WStrings,      (* TC_OPENCONFIGURATIONFILE *)
   Version,           (* TR4W_CURRENTVERSION *)
   VC,                (* TContestHandle, NoContest *)
   uContestChoices,   (* the list, its order and its search -- Q103 *)
   uContestRegistry,  (* ContestIdentity -- IsActive, Q59 *)
   uAppStrings,       (* SNewContestShowInactive, SNewContestFiles* *)
   uLatestContest,    (* TLatestContest -- what each grid row must say *)
   uTestLatestContest, (* MakeTestContestLog, WriteDamagedTestLog, ScrubTestLog *)
   uNewContestForm;

type
   TNewContestFormTests = class(TTestCase)
   private
      function NewForm: TfrmNewContest;
      procedure Search(aForm: TfrmNewContest; const aText: string);
      procedure ChooseRow(aForm: TfrmNewContest; aRow: integer);
      procedure ShowInactive(aForm: TfrmNewContest; aShow: boolean);
   protected
      procedure Test_TheCaptionFunctionNamesTheBuild;
      procedure Test_TheShownFormNamesTheBuild;

      (* Q103: the search rule, without a form. *)
      procedure Test_SearchMatchesAnywhereIgnoringCase;
      procedure Test_AnEmptySearchKeepsTheWholeListInOrder;
      procedure Test_QSOListsEveryQSOPartyAndNothingElse;

      (* Q59: inactive contests, without a form. *)
      procedure Test_InactiveContestsAreKeptOnlyWhenAsked;
      procedure Test_AnInactiveContestCannotStartANewOne;

      (* Q103: the dialog. *)
      procedure Test_TheListStartsWithEveryActiveContest;
      procedure Test_TheSearchBoxNarrowsTheList;
      procedure Test_AStillShownContestStaysChosen;
      procedure Test_AHiddenContestIsUnchosen;
      procedure Test_DownArrowChoosesTheFirstRow;

      (* Q59: the dialog. *)
      procedure Test_TheShowInactiveBoxListsThemLast;
      procedure Test_AnInactiveRowCannotBeChosen;
      procedure Test_UntickingClearsAnInactiveSelection;

      (* Q52: every name fits. *)
      procedure Test_TheListIsWideEnoughForEveryName;

      (* The existing-log grid, NY4I 2026-10-19. *)
      procedure Test_TheFileGridDescribesEachLog;
      procedure Test_TheSelectedRowIsTheFileOpened;
      procedure Test_TheFileGridIsWideEnoughAndSizesOnce;
      procedure Test_GrowthStopsAtTheWorkArea;
      procedure Test_AHundredLogsFillQuickly;

      (* NY4I 2026-10-19: Enter opens the selected log; the order is newest
        year first. The order is pinned without a form. *)
      procedure Test_LogsSortNewestYearFirst;
      procedure Test_TheGridListsInTheSortedOrder;
      procedure Test_EnterOpensTheSelectedLog;
   private
      (* A fresh, empty directory for one test's logs. *)
      function NewFilesDir(const aName: string): string;
      procedure RemoveFilesDir(const aDir: string);
      (* The grid row whose File cell is aName; -1 when none is. *)
      function RowOfFile(aForm: TfrmNewContest; const aName: string): integer;
      procedure WriteTextFile(const aFileName, aText: string);
   public
      procedure RunAllTests; override;
   end;

implementation

var
   (* How many times the form told uNewContest the contest changed. *)
   GContestChanges: integer;

procedure CountContestChange;
begin
   inc(GContestChanges);
end;

function TNewContestFormTests.NewForm: TfrmNewContest;
begin
   (* The widget set must be initialised before a control needs a window --
     see Test_TheShownFormNamesTheBuild. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   GContestChanges := 0;
   Result := TfrmNewContest.Create(nil);
end;

(* TYPES INTO THE SEARCH BOX and raises the change through the event the .lfm
  wires -- so the test also fails if the .lfm stops binding OnChange. Setting
  Text may raise it already; a second, unchanged refill is harmless by design
  and that is one of the things these tests pin. *)
procedure TNewContestFormTests.Search(aForm: TfrmNewContest; const aText: string);
begin
   aForm.edtContestFilter.Text := aText;
   CheckTrue(Assigned(aForm.edtContestFilter.OnChange),
             'uNewContestForm.lfm must wire the search box''s OnChange');
   if Assigned(aForm.edtContestFilter.OnChange) then
      begin
      aForm.edtContestFilter.OnChange(aForm.edtContestFilter);
      end;
end;

(* CHOOSES A ROW the way a click does: ItemIndex, then the list's
  OnSelectionChange through the event the .lfm wires. *)
procedure TNewContestFormTests.ChooseRow(aForm: TfrmNewContest; aRow: integer);
begin
   aForm.lstContests.ItemIndex := aRow;
   CheckTrue(Assigned(aForm.lstContests.OnSelectionChange),
             'uNewContestForm.lfm must wire the list''s OnSelectionChange');
   if Assigned(aForm.lstContests.OnSelectionChange) then
      begin
      aForm.lstContests.OnSelectionChange(aForm.lstContests, True);
      end;
end;

(* TICKS OR UN-TICKS "Show inactive contests" and raises the change through the
  event the .lfm wires. Setting Checked may raise it already; a second refill
  with nothing changed is harmless by design. *)
procedure TNewContestFormTests.ShowInactive(aForm: TfrmNewContest; aShow: boolean);
begin
   aForm.chkShowInactive.Checked := aShow;
   CheckTrue(Assigned(aForm.chkShowInactive.OnChange),
             'uNewContestForm.lfm must wire the show-inactive box''s OnChange');
   if Assigned(aForm.chkShowInactive.OnChange) then
      begin
      aForm.chkShowInactive.OnChange(aForm.chkShowInactive);
      end;
end;

procedure TNewContestFormTests.Test_InactiveContestsAreKeptOnlyWhenAsked;
var
   choices: TContestChoices;
   hidden, shown: TContestChoiceIndexes;
   i, inactive: integer;
   kept: array of boolean;
begin
   BeginTest('Test_InactiveContestsAreKeptOnlyWhenAsked');

   choices := TContestChoices.Create;
   try
      inactive := 0;
      for i := 0 to choices.Count - 1 do
         begin
         if not ContestIdentity(choices.Contest[i]).IsActive then
            begin
            inc(inactive);
            end;
         end;
      CheckTrue(inactive > 0, 'the registry has inactive contests (SA Sprint, Locust ...)');

      hidden := choices.Matching('', False);
      CheckEquals(choices.Count - inactive, Length(hidden),
                  'without the box, every active contest and no inactive one');
      SetLength(kept, choices.Count);
      for i := 0 to High(hidden) do
         begin
         kept[hidden[i]] := True;
         CheckTrue(ContestIdentity(choices.Contest[hidden[i]]).IsActive,
                   '"' + choices.Caption[hidden[i]] + '" is inactive and was kept');
         end;
      for i := 0 to choices.Count - 1 do
         begin
         if ContestIdentity(choices.Contest[i]).IsActive then
            begin
            CheckTrue(kept[i], 'the active "' + choices.Caption[i] + '" was dropped');
            end;
         end;

      shown := choices.Matching('', True);
      CheckEquals(choices.Count, Length(shown),
                  'with the box, every contest, the inactive ones included');

      (* THE SEARCH STILL APPLIES TO THE INACTIVE ONES. "inactive" matches the
        mark, so it finds exactly the inactive contests -- or none at all. *)
      CheckEquals(inactive, Length(choices.Matching('inactive', True)),
                  'with the box, a search keeps the inactive lines that match');
      CheckEquals(0, Length(choices.Matching('inactive', False)),
                  'without it, the same search keeps none of them');
      CheckEquals(0, Length(choices.Matching('no contest is called this', True)),
                  'with the box, a search nothing matches still keeps nothing');
   finally
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_AnInactiveContestCannotStartANewOne;
var
   choices: TContestChoices;
   i: integer;
begin
   BeginTest('Test_AnInactiveContestCannotStartANewOne');

   CheckFalse(ContestCanStartNew(NoContest), '"no contest" cannot be started');
   choices := TContestChoices.Create;
   try
      for i := 0 to choices.Count - 1 do
         begin
         if ContestCanStartNew(choices.Contest[i]) <>
            ContestIdentity(choices.Contest[i]).IsActive then
            begin
            CheckEquals(Ord(ContestIdentity(choices.Contest[i]).IsActive),
                        Ord(ContestCanStartNew(choices.Contest[i])),
                        '"' + choices.Caption[i] + '" can be started exactly when active');
            Break;
            end;
         end;
   finally
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_SearchMatchesAnywhereIgnoringCase;
begin
   BeginTest('Test_SearchMatchesAnywhereIgnoringCase');

   CheckTrue(ContestChoiceMatches('Michigan QSO Party', 'QSO'),
             'the text matches in the middle of the name');
   CheckTrue(ContestChoiceMatches('Michigan QSO Party', 'qso'),
             'the search ignores case');
   CheckTrue(ContestChoiceMatches('Michigan QSO Party', 'mICHIGAN'),
             'the text matches at the start, ignoring case');
   CheckTrue(ContestChoiceMatches('Michigan QSO Party', 'party'),
             'the text matches at the end');
   CheckTrue(ContestChoiceMatches('Michigan QSO Party', '  qso  '),
             'blanks around the search text are ignored');
   CheckFalse(ContestChoiceMatches('CQ Worldwide DX Contest, CW', 'qso'),
              'a name without the text is not kept');
   CheckFalse(ContestChoiceMatches('Michigan QSO Party', 'QSO  Party'),
              'blanks INSIDE the search text are matched as typed');
   CheckTrue(ContestChoiceMatches('Michigan QSO Party', ''),
             'an empty search keeps every name');
   CheckTrue(ContestChoiceMatches('Michigan QSO Party', '   '),
             'an all-blank search keeps every name');
end;

procedure TNewContestFormTests.Test_AnEmptySearchKeepsTheWholeListInOrder;
var
   choices: TContestChoices;
   rows: TContestChoiceIndexes;
   i: integer;
begin
   BeginTest('Test_AnEmptySearchKeepsTheWholeListInOrder');

   choices := TContestChoices.Create;
   try
      rows := choices.Matching('', True);
      CheckEquals(choices.Count, Length(rows),
                  'an empty search, inactive included, keeps every contest');
      for i := 0 to High(rows) do
         begin
         if rows[i] <> i then
            begin
            CheckEquals(i, rows[i], 'an empty search keeps the list''s order');
            Break;
            end;
         end;
   finally
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_QSOListsEveryQSOPartyAndNothingElse;
var
   choices: TContestChoices;
   rows: TContestChoiceIndexes;
   kept: array of boolean;
   i, parties: integer;
   isParty: boolean;
begin
   BeginTest('Test_QSOListsEveryQSOPartyAndNothingElse');

   choices := TContestChoices.Create;
   try
      rows := choices.Matching('QSO', True);
      SetLength(kept, choices.Count);
      for i := 0 to High(rows) do
         begin
         kept[rows[i]] := True;
         if (i > 0) and (rows[i] <= rows[i - 1]) then
            begin
            CheckTrue(False, 'the search keeps the list''s order, row ' + IntToStr(i));
            end;
         end;

      parties := 0;
      for i := 0 to choices.Count - 1 do
         begin
         isParty := Pos('qso party', LowerCase(choices.Caption[i])) > 0;
         if isParty then
            begin
            inc(parties);
            CheckTrue(kept[i], '"QSO" keeps the party "' + choices.Caption[i] + '"');
            end;
         if kept[i] then
            begin
            CheckTrue(Pos('qso', LowerCase(choices.Caption[i])) > 0,
                      '"QSO" kept "' + choices.Caption[i] + '", which does not say QSO');
            end;
         end;
      CheckTrue(parties >= 10,
                'the registry offers the QSO parties (found ' + IntToStr(parties) + ')');
      CheckEquals(Length(rows), Length(choices.Matching('qso', True)),
                  '"qso" and "QSO" keep the same rows');
   finally
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_TheListStartsWithEveryActiveContest;
var
   frm: TfrmNewContest;
   choices: TContestChoices;
   rows: TContestChoiceIndexes;
   i: integer;
begin
   BeginTest('Test_TheListStartsWithEveryActiveContest');

   choices := TContestChoices.Create;
   frm := NewForm;
   try
      rows := choices.Matching('', False);
      CheckEquals(Length(rows), frm.lstContests.Items.Count,
                  'with no search the list holds every ACTIVE contest');
      CheckTrue(Length(rows) < choices.Count,
                'and that is fewer than every contest -- the inactive ones are hidden');
      CheckFalse(frm.lstContests.Sorted,
                 'the list must not sort itself -- row i is the form''s FShown[i]');
      for i := 0 to High(rows) do
         begin
         if frm.lstContests.Items[i] <> UTF8Encode(choices.Caption[rows[i]]) then
            begin
            CheckEquals(UTF8Encode(choices.Caption[rows[i]]), frm.lstContests.Items[i],
                        'row ' + IntToStr(i) + ' shows the contest''s caption, in order');
            Break;
            end;
         end;
      CheckFalse(frm.ContestChosen, 'no contest is chosen when the dialog opens');
      CheckEquals(0, GContestChanges, 'building the list chooses nothing');
   finally
      frm.Free;
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_TheSearchBoxNarrowsTheList;
var
   frm: TfrmNewContest;
   choices: TContestChoices;
   i: integer;
begin
   BeginTest('Test_TheSearchBoxNarrowsTheList');

   choices := TContestChoices.Create;
   frm := NewForm;
   try
      Search(frm, 'qso');
      CheckEquals(Length(choices.Matching('qso', False)), frm.lstContests.Items.Count,
                  'the list shows exactly the rows the search keeps');
      CheckTrue(frm.lstContests.Items.Count > 0, '"qso" keeps some contests');
      for i := 0 to frm.lstContests.Items.Count - 1 do
         begin
         CheckTrue(Pos('qso', LowerCase(frm.lstContests.Items[i])) > 0,
                   'row "' + frm.lstContests.Items[i] + '" says QSO');
         end;

      (* The identity follows the row: the contest row 0 names is the one
        whose caption row 0 shows. *)
      ChooseRow(frm, 0);
      CheckEquals(frm.lstContests.Items[0],
                  UTF8Encode(ContestChoiceCaption(frm.SelectedContest)),
                  'the chosen contest is the one its row names');

      Search(frm, '');
      CheckEquals(Length(choices.Matching('', False)), frm.lstContests.Items.Count,
                  'clearing the search brings every active contest back');

      Search(frm, 'no contest is called this');
      CheckEquals(0, frm.lstContests.Items.Count,
                  'a search nothing matches shows an empty list');
   finally
      frm.Free;
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_AStillShownContestStaysChosen;
var
   frm: TfrmNewContest;
   chosen: TContestHandle;
   i, row: integer;
begin
   BeginTest('Test_AStillShownContestStaysChosen');

   frm := NewForm;
   OnContestChanged := CountContestChange;
   try
      (* A party, chosen from the whole list. *)
      row := -1;
      for i := 0 to frm.lstContests.Items.Count - 1 do
         begin
         if Pos('qso party', LowerCase(frm.lstContests.Items[i])) > 0 then
            begin
            row := i;
            Break;
            end;
         end;
      CheckTrue(row >= 0, 'the list holds a QSO party');
      if row < 0 then
         begin
         Exit;
         end;

      ChooseRow(frm, row);
      chosen := frm.SelectedContest;
      CheckTrue(frm.ContestChosen, 'choosing a row chooses its contest');
      CheckEquals(1, GContestChanges, 'choosing a row tells uNewContest once');

      ChooseRow(frm, row);
      CheckEquals(1, GContestChanges,
                  'the same row raised again is not a change -- the rows the ' +
                  'operator filled in are not cleared');

      Search(frm, 'qso');
      CheckTrue(frm.ContestChosen, 'a search that still shows the contest keeps it chosen');
      CheckTrue(frm.SelectedContest = chosen,
                'the SAME contest stays chosen, found by its identity in the new rows');
      CheckTrue(frm.lstContests.ItemIndex >= 0,
                'its row is selected in the narrowed list');
      CheckEquals(UTF8Encode(ContestChoiceCaption(chosen)),
                  frm.lstContests.Items[frm.lstContests.ItemIndex],
                  'the selected row is the chosen contest''s row');
      CheckEquals(1, GContestChanges,
                  'narrowing around the chosen contest is not a change');
   finally
      OnContestChanged := nil;
      frm.Free;
   end;
end;

procedure TNewContestFormTests.Test_AHiddenContestIsUnchosen;
var
   frm: TfrmNewContest;
begin
   BeginTest('Test_AHiddenContestIsUnchosen');

   frm := NewForm;
   OnContestChanged := CountContestChange;
   try
      ChooseRow(frm, 0);
      CheckTrue(frm.ContestChosen, 'row 0 is chosen');
      CheckEquals(1, GContestChanges, 'choosing it was one change');

      Search(frm, 'no contest is called this');
      CheckFalse(frm.ContestChosen,
                 'a search that hides the chosen contest un-chooses it, so OK ' +
                 'cannot go ahead with a contest the operator cannot see');
      CheckTrue(frm.SelectedContest = NoContest, 'and SelectedContest says so');
      CheckEquals('', frm.ContestName, 'and there is no contest name to write');
      CheckEquals(2, GContestChanges,
                  'uNewContest is told, so it clears the hidden contest''s prompts');

      Search(frm, '');
      CheckFalse(frm.ContestChosen,
                 'clearing the search does not choose a contest for the operator');
      CheckEquals(2, GContestChanges, 'and is not a change');
   finally
      OnContestChanged := nil;
      frm.Free;
   end;
end;

procedure TNewContestFormTests.Test_DownArrowChoosesTheFirstRow;
var
   frm: TfrmNewContest;
   key: Word;
   first: TContestHandle;
begin
   BeginTest('Test_DownArrowChoosesTheFirstRow');

   frm := NewForm;
   OnContestChanged := CountContestChange;
   try
      CheckTrue(Assigned(frm.edtContestFilter.OnKeyDown),
                'uNewContestForm.lfm must wire the search box''s OnKeyDown');
      if not Assigned(frm.edtContestFilter.OnKeyDown) then
         begin
         Exit;
         end;

      key := VK_A;
      frm.edtContestFilter.OnKeyDown(frm.edtContestFilter, key, []);
      CheckEquals(VK_A, key, 'any other key is left to the search box');
      CheckFalse(frm.ContestChosen, 'and chooses nothing');

      key := VK_DOWN;
      frm.edtContestFilter.OnKeyDown(frm.edtContestFilter, key, []);
      CheckEquals(0, frm.lstContests.ItemIndex, 'Down from the search box chooses the first row');
      CheckEquals(0, key, 'and the key is consumed');
      CheckEquals(1, GContestChanges, 'and uNewContest is told once');
      first := frm.SelectedContest;

      ChooseRow(frm, 1);
      key := VK_DOWN;
      frm.edtContestFilter.OnKeyDown(frm.edtContestFilter, key, []);
      CheckEquals(1, frm.lstContests.ItemIndex,
                  'with a row already chosen, Down only moves focus -- it does not ' +
                  'go back to the first');
      CheckTrue(frm.SelectedContest <> first, 'the second row''s contest stays chosen');
   finally
      OnContestChanged := nil;
      frm.Free;
   end;
end;

procedure TNewContestFormTests.Test_TheShowInactiveBoxListsThemLast;
var
   frm: TfrmNewContest;
   choices: TContestChoices;
   active, i: integer;
   rows: TContestChoiceIndexes;
begin
   BeginTest('Test_TheShowInactiveBoxListsThemLast');

   choices := TContestChoices.Create;
   frm := NewForm;
   try
      CheckFalse(frm.chkShowInactive.Checked, 'the box starts un-ticked');
      active := frm.lstContests.Items.Count;
      CheckEquals(Length(choices.Matching('', False)), active,
                  'un-ticked, the list holds the active contests only');

      ShowInactive(frm, True);
      CheckEquals(choices.Count, frm.lstContests.Items.Count,
                  'ticked, the list holds every contest');
      for i := 0 to choices.Count - 1 do
         begin
         if frm.lstContests.Items[i] <> UTF8Encode(choices.Caption[i]) then
            begin
            CheckEquals(UTF8Encode(choices.Caption[i]), frm.lstContests.Items[i],
                        'ticked, row ' + IntToStr(i) + ' is the list''s own order');
            Break;
            end;
         end;
      CheckFalse(ContestIdentity(choices.Contest[active]).IsActive,
                 'the first row past the active ones is an inactive contest -- they are last');

      Search(frm, 'inactive');
      rows := choices.Matching('inactive', True);
      CheckEquals(Length(rows), frm.lstContests.Items.Count,
                  'ticked, the search still applies to the inactive rows');
      CheckEquals(choices.Count - active, frm.lstContests.Items.Count,
                  'and "inactive" finds exactly the inactive contests');

      ShowInactive(frm, False);
      CheckEquals(0, frm.lstContests.Items.Count,
                  'un-ticked again, the same search shows none of them');
   finally
      frm.Free;
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_AnInactiveRowCannotBeChosen;
var
   frm: TfrmNewContest;
   last: integer;
begin
   BeginTest('Test_AnInactiveRowCannotBeChosen');

   frm := NewForm;
   OnContestChanged := CountContestChange;
   try
      ShowInactive(frm, True);
      last := frm.lstContests.Items.Count - 1;
      CheckEquals(0, GContestChanges, 'listing the inactive contests chooses nothing');

      ChooseRow(frm, last);
      CheckEquals(last, frm.lstContests.ItemIndex, 'the inactive row can be selected');
      CheckFalse(frm.ContestChosen, 'but it is not a contest a new contest can be');
      CheckTrue(frm.SelectedContest = NoContest, 'SelectedContest is NoContest');
      CheckEquals('', frm.ContestName, 'and there is no contest name to write');
      CheckEquals(0, GContestChanges,
                  'nothing was chosen before, so nothing changed -- no prompts appear');

      ChooseRow(frm, 0);
      CheckTrue(frm.ContestChosen, 'an active row is still a choice');
      CheckEquals(1, GContestChanges, 'and choosing it is one change');

      ChooseRow(frm, last);
      CheckFalse(frm.ContestChosen, 'moving to the inactive row un-chooses the contest');
      CheckEquals(2, GContestChanges,
                  'uNewContest is told, so it clears the prompts and disables OK');
   finally
      OnContestChanged := nil;
      frm.Free;
   end;
end;

procedure TNewContestFormTests.Test_UntickingClearsAnInactiveSelection;
var
   frm: TfrmNewContest;
   chosen: TContestHandle;
begin
   BeginTest('Test_UntickingClearsAnInactiveSelection');

   frm := NewForm;
   try
      ShowInactive(frm, True);
      ChooseRow(frm, frm.lstContests.Items.Count - 1);
      ShowInactive(frm, False);
      CheckEquals(-1, frm.lstContests.ItemIndex,
                  'un-ticking with an inactive row selected clears the selection');
      CheckFalse(frm.ContestChosen, 'and nothing is chosen');

      ChooseRow(frm, 1);
      chosen := frm.SelectedContest;
      ShowInactive(frm, True);
      CheckTrue(frm.SelectedContest = chosen, 'ticking keeps an active choice');
      ShowInactive(frm, False);
      CheckTrue(frm.SelectedContest = chosen, 'and so does un-ticking');
      CheckEquals(1, frm.lstContests.ItemIndex, 'on the same row');
   finally
      frm.Free;
   end;
end;

procedure TNewContestFormTests.Test_TheListIsWideEnoughForEveryName;
var
   frm: TfrmNewContest;
   choices: TContestChoices;
   probe: TBitmap;
   i, w, widest, onScreen: integer;
   widestName: string;
begin
   BeginTest('Test_TheListIsWideEnoughForEveryName');
   widestName := '';

   choices := TContestChoices.Create;
   frm := NewForm;
   probe := TBitmap.Create;
   try
      probe.SetSize(1, 1);
      probe.Canvas.Font := frm.lstContests.Font;
      widest := 0;
      for i := 0 to choices.Count - 1 do
         begin
         w := probe.Canvas.TextWidth(UTF8Encode(choices.Caption[i]));
         if w > widest then
            begin
            widest := w;
            widestName := choices.Caption[i];
            end;
         end;
      CheckTrue(widest > 0, 'the names were measured');

      CheckTrue(frm.lstContests.ScrollWidth >= widest,
                'the list scrolls at least as wide as its widest name');

      (* THE WIDTH THE LIST WILL HAVE ON SCREEN. The LCL lays out aligned
        children only once the form is showing (AutoSizeDelayed), and this
        suite never shows a window, so the list still has its designed width
        here. It is alClient in the column, so on screen it is the column's
        client width less its own BorderSpacing -- the LCL's rule, read from
        the control rather than assumed. *)
      CheckTrue(frm.lstContests.Align = alClient,
                'the list fills its column, so the column''s width is the list''s');
      onScreen := frm.pnlContestPick.ClientWidth -
                  frm.lstContests.BorderSpacing.Left -
                  frm.lstContests.BorderSpacing.Right -
                  2 * frm.lstContests.BorderSpacing.Around;

      (* Unless the screen is too narrow to hold it, the list is as wide as
        the widest name -- no name is cut short. *)
      if frm.Width < Screen.WorkAreaWidth then
         begin
         CheckTrue(onScreen >= widest,
                   'the list (' + IntToStr(onScreen) + ' px) holds its widest name, "' +
                   widestName + '" (' + IntToStr(widest) + ' px)');
         end;
      CheckTrue(frm.Constraints.MinWidth <= frm.Width,
                'the minimum width still fits the form');
   finally
      probe.Free;
      frm.Free;
      choices.Free;
   end;
end;

procedure TNewContestFormTests.Test_TheCaptionFunctionNamesTheBuild;
var
   caption: string;
begin
   BeginTest('Test_TheCaptionFunctionNamesTheBuild');

   caption := NewContestFormCaption;
   CheckEquals(TR4W_CURRENTVERSION + TC_OPENCONFIGURATIONFILE, caption,
               'the title is the version followed by what the dialog is for');
   CheckTrue(Pos(TR4W_CURRENTVERSION, caption) = 1,
             'the title STARTS with the program name and version');
end;

procedure TNewContestFormTests.Test_TheShownFormNamesTheBuild;
var
   frm: TfrmNewContest;
begin
   BeginTest('Test_TheShownFormNamesTheBuild');

   (* The widget set must be initialised before a control needs a window --
     see uTestStatusAndNotice.EnsureMainForm, which does the same. It starts no
     message loop. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   frm := TfrmNewContest.Create(nil);
   try
      CheckTrue(Assigned(frm.OnShow),
                'uNewContestForm.lfm must wire OnShow -- it is the caption''s writer');
      (* The .lfm's placeholder IS the English text, so blank it first: what
        is read back after OnShow must have been written by OnShow. *)
      frm.chkShowInactive.Caption := '';
      if Assigned(frm.OnShow) then
         begin
         frm.OnShow(frm);
         end;

      CheckTrue(Pos(TR4W_CURRENTVERSION, frm.Caption) = 1,
                'after OnShow the title starts with the version, got "' +
                frm.Caption + '"');
      CheckEquals(NewContestFormCaption, frm.Caption,
                  'after OnShow the title is the one the form owns');
      CheckEquals(SNewContestShowInactive, frm.chkShowInactive.Caption,
                  'after OnShow the show-inactive box is captioned from the ' +
                  'resourcestring, not the .lfm');
   finally
      frm.Free;
   end;
end;

(* ---------------------------------------------------------------------------
  the existing-log grid
  --------------------------------------------------------------------------- *)

function TNewContestFormTests.NewFilesDir(const aName: string): string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_newcontest_' +
             aName + '_' + IntToStr(GetProcessID);
   RemoveFilesDir(Result);
   ForceDirectories(Result);
   Result := IncludeTrailingPathDelimiter(Result);
end;

procedure TNewContestFormTests.RemoveFilesDir(const aDir: string);
var
   found: TSearchRec;
   base: string;
begin
   base := IncludeTrailingPathDelimiter(aDir);
   if FindFirst(RawByteString(base + '*'), faAnyFile, found) = 0 then
      begin
      repeat
         if (found.Attr and faDirectory) = 0 then
            begin
            DeleteFile(base + string(found.Name));
            end;
      until FindNext(found) <> 0;
      FindClose(found);
      end;
   RemoveDir(ExcludeTrailingPathDelimiter(aDir));
end;

function TNewContestFormTests.RowOfFile(aForm: TfrmNewContest; const aName: string): integer;
var
   r: integer;
begin
   Result := -1;
   for r := aForm.grdFiles.FixedRows to aForm.grdFiles.RowCount - 1 do
      begin
      if aForm.grdFiles.Cells[3, r] = aName then
         begin
         Result := r;
         Exit;
         end;
      end;
end;

procedure TNewContestFormTests.WriteTextFile(const aFileName, aText: string);
var
   lines: TStringList;
begin
   lines := TStringList.Create;
   try
      lines.Text := aText;
      lines.SaveToFile(aFileName);
   finally
      lines.Free;
   end;
end;

(* EVERY LOG A ROW, DESCRIBED BY THE LOG -- and the files that cannot describe
  themselves still listed. Five files on disk, four rows:

    cqww ssb ny4i.db   a real CQ WW SSB log declared by NY4I
    ne party.db        a real New England QSO Party log, no call declared
    damaged.db         passes the byte check, fails in SQLite
    old.cfg            a .cfg with no log beside it -- the migration path
    migrated.cfg       a .cfg WITH migrated.db beside it -- not listed
    migrated.db        (that log)

  Each described row must say exactly what TLatestContest says of the same
  file, which is what the Last Contest button shows: one rule, not two. *)
procedure TNewContestFormTests.Test_TheFileGridDescribesEachLog;
const
   COL_CONTEST = 0;
   COL_YEAR = 1;
   COL_CALL = 2;
   COL_FILE = 3;
var
   frm: TfrmNewContest;
   dir: string;
   r: integer;
   hint: AnsiString;
   expected: TLatestContest;

   procedure CheckDescribedRow(const aName: string);
   var
      row: integer;
   begin
      row := RowOfFile(frm, aName);
      CheckTrue(row > 0, '"' + aName + '" is listed');
      if row <= 0 then
         begin
         Exit;
         end;
      expected := TLatestContest.Create(dir + aName);
      try
         CheckTrue(expected.Described, aName + ' describes itself: ' + expected.Why);
         CheckEquals(UTF8Encode(expected.ContestName), frm.grdFiles.Cells[COL_CONTEST, row],
                     aName + ': the Contest column is the button''s contest name');
         CheckEquals(IntToStr(expected.Year), frm.grdFiles.Cells[COL_YEAR, row],
                     aName + ': the Year column is the button''s year');
         CheckEquals(UTF8Encode(expected.Call), frm.grdFiles.Cells[COL_CALL, row],
                     aName + ': the Call column is the declared call');
      finally
         expected.Free;
      end;
      CheckEquals(dir + aName, frm.FileOnRow(row),
                  aName + ': the row holds the full path of its own file');
   end;

   procedure CheckUndescribedRow(const aName: string);
   var
      row: integer;
   begin
      row := RowOfFile(frm, aName);
      CheckTrue(row > 0, '"' + aName + '" is still listed, though it cannot describe itself');
      if row <= 0 then
         begin
         Exit;
         end;
      CheckEquals('', frm.grdFiles.Cells[COL_CONTEST, row], aName + ': no contest');
      CheckEquals('', frm.grdFiles.Cells[COL_YEAR, row], aName + ': no year');
      CheckEquals('', frm.grdFiles.Cells[COL_CALL, row], aName + ': no call');
      CheckEquals(dir + aName, frm.FileOnRow(row), aName + ': its own full path');
   end;

begin
   BeginTest('Test_TheFileGridDescribesEachLog');

   dir := NewFilesDir('describe');
   MakeTestContestLog(dir + 'cqww ssb ny4i.db', ContestFromName('CQ-WW-SSB'), 'NY4I');
   MakeTestContestLog(dir + 'ne party.db', ContestFromName('NE-QSO-PARTY'), '');
   WriteDamagedTestLog(dir + 'damaged.db');
   WriteTextFile(dir + 'old.cfg', 'MY CALL = NY4I' + LineEnding + 'CONTEST = CQWWSSB');
   WriteTextFile(dir + 'migrated.cfg', 'MY CALL = NY4I');
   MakeTestContestLog(dir + 'migrated.db', ContestFromName('CQ-WW-SSB'), 'K1AR');

   frm := NewForm;
   try
      CheckEquals(UTF8Encode(SNewContestFilesContest), frm.grdFiles.Cells[COL_CONTEST, 0],
                  'the Contest header is the resourcestring');
      CheckEquals(UTF8Encode(SNewContestFilesYear), frm.grdFiles.Cells[COL_YEAR, 0],
                  'the Year header');
      CheckEquals(UTF8Encode(SNewContestFilesCall), frm.grdFiles.Cells[COL_CALL, 0],
                  'the Call header');
      CheckEquals(UTF8Encode(SNewContestFilesFile), frm.grdFiles.Cells[COL_FILE, 0],
                  'the File header');
      CheckEquals(1, frm.grdFiles.FixedRows, 'one header row');
      CheckEquals(0, frm.grdFiles.FixedCols, 'no fixed column');
      CheckTrue(goRowSelect in frm.grdFiles.Options, 'a row is selected whole');
      CheckFalse(goEditing in frm.grdFiles.Options, 'the cells are not editable');

      frm.PopulateFiles(dir);

      CheckEquals(1 + 5, frm.grdFiles.RowCount,
                  'five rows: four logs and the .cfg with no log beside it');
      CheckEquals(-1, RowOfFile(frm, 'migrated.cfg'),
                  'a .cfg whose log exists is not listed twice');

      (* SortContestFiles' order: one year, so by contest (CQ Worldwide
        before Nebraska), the two CQ WW logs by file name, then the two that
        cannot describe themselves, by file name. *)
      CheckEquals('cqww ssb ny4i.db', frm.grdFiles.Cells[COL_FILE, 1], 'row 1');
      CheckEquals('migrated.db',      frm.grdFiles.Cells[COL_FILE, 2], 'row 2');
      CheckEquals('ne party.db',      frm.grdFiles.Cells[COL_FILE, 3], 'row 3');
      CheckEquals('damaged.db',       frm.grdFiles.Cells[COL_FILE, 4], 'row 4');
      CheckEquals('old.cfg',          frm.grdFiles.Cells[COL_FILE, 5], 'row 5');

      CheckDescribedRow('cqww ssb ny4i.db');
      CheckDescribedRow('ne party.db');
      CheckDescribedRow('migrated.db');
      CheckEquals('NY4I', frm.grdFiles.Cells[COL_CALL, RowOfFile(frm, 'cqww ssb ny4i.db')],
                  'the declared call, literally');
      CheckEquals('', frm.grdFiles.Cells[COL_CALL, RowOfFile(frm, 'ne party.db')],
                  'no call declared, none shown');
      CheckTrue(frm.grdFiles.Cells[COL_CONTEST, RowOfFile(frm, 'ne party.db')] <>
                frm.grdFiles.Cells[COL_CONTEST, RowOfFile(frm, 'cqww ssb ny4i.db')],
                'two contests, two names');

      CheckUndescribedRow('damaged.db');
      CheckUndescribedRow('old.cfg');

      (* The full path is each row's hint, through the event the .lfm wires. *)
      CheckTrue(Assigned(frm.grdFiles.OnGetCellHint),
                'uNewContestForm.lfm must wire the grid''s OnGetCellHint');
      CheckTrue(goCellHints in frm.grdFiles.Options, 'and turn cell hints on');
      if Assigned(frm.grdFiles.OnGetCellHint) then
         begin
         for r := 1 to frm.grdFiles.RowCount - 1 do
            begin
            hint := '';
            frm.grdFiles.OnGetCellHint(frm.grdFiles, 1, r, hint);
            CheckEquals(UTF8Encode(frm.FileOnRow(r)), hint,
                        'row ' + IntToStr(r) + '''s hint is its full path');
            end;
         hint := 'x';
         frm.grdFiles.OnGetCellHint(frm.grdFiles, 0, 0, hint);
         CheckEquals('', hint, 'the header has no hint');
         end;
      CheckEquals('', frm.FileOnRow(0), 'the header row is no file');
      CheckEquals('', frm.FileOnRow(frm.grdFiles.RowCount), 'past the last row is no file');
   finally
      frm.Free;
      RemoveFilesDir(dir);
   end;
end;

(* THE ROW SELECTED IS THE FILE OPENED -- by its path, whatever the row's
  position, and a double-click is wired. *)
procedure TNewContestFormTests.Test_TheSelectedRowIsTheFileOpened;
var
   frm: TfrmNewContest;
   dir: string;
   r: integer;
begin
   BeginTest('Test_TheSelectedRowIsTheFileOpened');

   dir := NewFilesDir('select');
   MakeTestContestLog(dir + 'a.db', ContestFromName('CQ-WW-SSB'), 'NY4I');
   MakeTestContestLog(dir + 'b.db', ContestFromName('NE-QSO-PARTY'), 'W1AW');
   WriteTextFile(dir + 'c.cfg', 'MY CALL = NY4I');

   frm := NewForm;
   try
      frm.PopulateFiles(dir);
      CheckEquals(4, frm.grdFiles.RowCount, 'three rows under the header');
      for r := 1 to frm.grdFiles.RowCount - 1 do
         begin
         frm.grdFiles.Row := r;
         CheckEquals(dir + frm.grdFiles.Cells[3, r], frm.SelectedFile,
                     'selecting row ' + IntToStr(r) + ' selects its own file');
         end;

      frm.grdFiles.Row := 2;
      CheckEquals(dir + 'b.db', frm.SelectedFile, 'row 2 is b.db');

      CheckTrue(Assigned(frm.grdFiles.OnDblClick),
                'uNewContestForm.lfm must wire the grid''s OnDblClick -- it opens the row');
      CheckEquals(Ord(nccNone), Ord(frm.Choice), 'nothing is chosen by filling the grid');

      (* AN EMPTY DIRECTORY: no rows, and no file is selected. *)
      RemoveFilesDir(dir);
      dir := NewFilesDir('select');
      frm.PopulateFiles(dir);
      CheckEquals(1, frm.grdFiles.RowCount, 'an empty directory leaves the header alone');
      CheckEquals('', frm.SelectedFile, 'and selects no file');
   finally
      frm.Free;
      RemoveFilesDir(dir);
   end;
end;

(* EVERY COLUMN HOLDS ITS WIDEST CELL, THE GROUP GROWS TO HOLD THE COLUMNS, AND
  IT GROWS ONCE: a second fill of the same directory changes nothing, and an
  empty one gives the room back. gbNew's left side is anchored to gbExisting,
  so it moves over rather than being squeezed.

  TRUE ON ANY SCREEN. The group grows by what the columns need or by the room
  the work area leaves beside the form, whichever is smaller -- and with no
  room it keeps its width and the grid scrolls sideways. The CI runner is a
  service session whose desktop is no wider than this form once the contest
  list has widened it, so there the room is 0; on a normal screen the room is
  ample and the widening is checked in full. The cap itself is pinned on every
  screen by Test_GrowthStopsAtTheWorkArea. *)
procedure TNewContestFormTests.Test_TheFileGridIsWideEnoughAndSizesOnce;
var
   frm: TfrmNewContest;
   dir, where: string;
   probe: TBitmap;
   c, r, w, columns, w0, g0, min0, w1, g1, room, designedGrid: integer;
begin
   BeginTest('Test_TheFileGridIsWideEnoughAndSizesOnce');

   dir := NewFilesDir('size');
   MakeTestContestLog(dir + 'a rather long file name for a contest log 2026.db',
                      ContestFromName('CQ-WW-SSB'), 'NY4I');
   MakeTestContestLog(dir + 'b.db', ContestFromName('NE-QSO-PARTY'), 'W1AW');

   frm := NewForm;
   probe := TBitmap.Create;
   try
      CheckTrue(frm.gbNew.AnchorSideLeft.Control = frm.gbExisting,
                'gbNew''s left side follows gbExisting''s right (.lfm)');
      CheckTrue(akLeft in frm.gbNew.Anchors, 'and gbNew is anchored on the left');

      w0   := frm.Width;
      g0   := frm.gbExisting.Width;
      min0 := frm.Constraints.MinWidth;
      designedGrid := frm.grdFiles.Width;
      room := Screen.WorkAreaWidth - w0;
      where := ' (work area ' + IntToStr(Screen.WorkAreaWidth) + ' px, form ' +
               IntToStr(w0) + ' px, room ' + IntToStr(room) + ' px)';

      frm.PopulateFiles(dir);
      probe.SetSize(1, 1);
      columns := 0;
      for c := 0 to frm.grdFiles.ColCount - 1 do
         begin
         for r := 0 to frm.grdFiles.RowCount - 1 do
            begin
            if r < frm.grdFiles.FixedRows then
               begin
               probe.Canvas.Font := frm.grdFiles.TitleFont;
               end
            else
               begin
               probe.Canvas.Font := frm.grdFiles.Font;
               end;
            w := probe.Canvas.TextWidth(frm.grdFiles.Cells[c, r]);
            CheckTrue(frm.grdFiles.ColWidths[c] > w,
                      'column ' + IntToStr(c) + ' (' + IntToStr(frm.grdFiles.ColWidths[c]) +
                      ' px) holds "' + frm.grdFiles.Cells[c, r] + '" (' + IntToStr(w) + ' px)');
            end;
         columns := columns + frm.grdFiles.ColWidths[c];
         end;

      (* THE FIXTURE MUST NEED THE ROOM, or nothing below is tested. *)
      CheckTrue(columns > designedGrid,
                'the columns (' + IntToStr(columns) + ' px) need more than the designed grid (' +
                IntToStr(designedGrid) + ' px)');

      g1 := frm.gbExisting.Width;
      w1 := frm.Width;
      if room > 0 then
         begin
         CheckTrue(g1 > g0, 'a long file name widens the group (' + IntToStr(g0) + ' -> ' +
                            IntToStr(g1) + ')' + where);
         CheckTrue(g1 - g0 <= room, 'but never past the work area (grew ' +
                                    IntToStr(g1 - g0) + ')' + where);
         end
      else
         begin
         CheckEquals(g0, g1, 'with no room the group keeps its width' + where);
         CheckTrue(frm.grdFiles.ScrollBars in [ssHorizontal, ssBoth, ssAutoHorizontal, ssAutoBoth],
                   'and the grid scrolls sideways rather than clipping a column' + where);
         end;
      CheckEquals(g1 - g0, w1 - w0, 'the form widens by exactly what the group did');
      CheckEquals(g1 - g0, frm.Constraints.MinWidth - min0, 'and so does its minimum');
      if w1 < Screen.WorkAreaWidth then
         begin
         (* The grid on screen is the group less its designed margins. *)
         CheckTrue(frm.grdFiles.Width + (g1 - g0) >= columns,
                   'the grid, once laid out, holds every column (' +
                   IntToStr(frm.grdFiles.Width + (g1 - g0)) + ' >= ' + IntToStr(columns) + ')');
         end;

      frm.PopulateFiles(dir);
      CheckEquals(g1, frm.gbExisting.Width, 'a second fill does not grow the group again');
      CheckEquals(w1, frm.Width, 'nor the form');

      RemoveFilesDir(dir);
      dir := NewFilesDir('size');
      frm.PopulateFiles(dir);
      CheckEquals(g0, frm.gbExisting.Width, 'an empty directory gives the room back');
      CheckEquals(w0, frm.Width, 'and the form returns to its width');
      CheckEquals(min0, frm.Constraints.MinWidth, 'and its minimum');
   finally
      probe.Free;
      frm.Free;
      RemoveFilesDir(dir);
   end;
end;

(* THE CAP, ON ANY SCREEN: a column grows by what it wants or by the room the
  work area leaves, whichever is smaller, and never shrinks the dialog. The
  rooms here are forced small -- a real desktop cannot be made narrow from a
  test -- including none at all and less than none, which is a form already
  wider than its screen. *)
procedure TNewContestFormTests.Test_GrowthStopsAtTheWorkArea;
begin
   BeginTest('Test_GrowthStopsAtTheWorkArea');

   CheckEquals(100, GrowWithinRoom(100, 500), 'ample room: the whole of what is wanted');
   CheckEquals(100, GrowWithinRoom(100, 100), 'exactly enough room: all of it');
   CheckEquals(40,  GrowWithinRoom(100, 40),  'too little room: only the room');
   CheckEquals(0,   GrowWithinRoom(100, 0),   'no room: no growth');
   CheckEquals(0,   GrowWithinRoom(100, -50), 'a form wider than its screen is not shrunk');
   CheckEquals(0,   GrowWithinRoom(-20, 500), 'a column that needs less than designed does not shrink');
   CheckEquals(0,   GrowWithinRoom(0, 500),   'nothing wanted, nothing grown');
end;

(* ONE DESCRIBE PER FILE AT SHOW, AND IT MUST NOT BLOCK: a hundred copies of a
  real log, the time to fill the grid printed for the record. The bound is
  loose on purpose -- it catches a describe that has become a scan, not a
  slow runner. The budget is 300 ms. *)
procedure TNewContestFormTests.Test_AHundredLogsFillQuickly;
const
   COPIES = 100;
var
   frm: TfrmNewContest;
   dir, source: string;
   i: integer;
   src, dst: TFileStream;
   started, took: QWord;
begin
   BeginTest('Test_AHundredLogsFillQuickly');

   dir := NewFilesDir('hundred');
   source := dir + 'log 000.db';
   MakeTestContestLog(source, ContestFromName('CQ-WW-SSB'), 'NY4I');
   for i := 1 to COPIES - 1 do
      begin
      src := TFileStream.Create(AnsiString(source), fmOpenRead or fmShareDenyNone);
      try
         dst := TFileStream.Create(AnsiString(dir + Format('log %.3d.db', [i])), fmCreate);
         try
            dst.CopyFrom(src, 0);
         finally
            dst.Free;
         end;
      finally
         src.Free;
      end;
      end;

   frm := NewForm;
   try
      started := GetTickCount64;
      frm.PopulateFiles(dir);
      took := GetTickCount64 - started;
      WriteLn('  [NewContest] file grid: ', COPIES, ' logs described in ', took, ' ms');

      CheckEquals(1 + COPIES, frm.grdFiles.RowCount, 'every copy is a row');
      CheckEquals('NY4I', frm.grdFiles.Cells[2, COPIES], 'and the last is described');
      CheckTrue(took < 3000, 'filling the grid took ' + IntToStr(took) + ' ms');
   finally
      frm.Free;
      RemoveFilesDir(dir);
   end;
end;

(* THE ORDER, WITHOUT A FORM OR A FILE. Added scrambled; read back as:

    b.db   ARRL DX 2026     newest year first ...
    Y.db   arrl dx 2026     ... the same contest (its name compared without
    z.db   ARRL DX 2026         case), so by file name, also without case
    a.db   CQ WW   2026
    x.db   CQ WW   2024     an older year after
    c.db   Zed     (none)   a log with no year after every dated one
    B.cfg  (undescribed)    the files that cannot describe themselves last,
    m.cfg  (undescribed)    by file name *)
procedure TNewContestFormTests.Test_LogsSortNewestYearFirst;
const
   EXPECTED: array[0..7] of string =
      ('b.db', 'Y.db', 'z.db', 'a.db', 'x.db', 'c.db', 'B.cfg', 'm.cfg');
var
   files: TContestFileList;
   gone: string;
   i: integer;
begin
   BeginTest('Test_LogsSortNewestYearFirst');

   (* A directory that does not exist: these files cannot describe
     themselves, and describing them creates nothing. *)
   gone := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_no_such_dir_' +
           IntToStr(GetProcessID) + PathDelim;

   files := TContestFileList.Create(True);
   try
      files.Add(TLatestContest.CreateFor('c:\logs\x.db', 'CQ WW', 2024, 'NY4I'));
      files.Add(TLatestContest.Create(gone + 'm.cfg'));
      files.Add(TLatestContest.CreateFor('c:\logs\z.db', 'ARRL DX', 2026, ''));
      files.Add(TLatestContest.CreateFor('c:\logs\c.db', 'Zed', 0, ''));
      files.Add(TLatestContest.CreateFor('c:\logs\a.db', 'CQ WW', 2026, 'NY4I'));
      files.Add(TLatestContest.Create(gone + 'B.cfg'));
      files.Add(TLatestContest.CreateFor('c:\logs\b.db', 'ARRL DX', 2026, 'K1AR'));
      files.Add(TLatestContest.CreateFor('c:\logs\Y.db', 'arrl dx', 2026, 'W1AW'));
      CheckFalse(files[1].Described, 'a missing file does not describe itself');

      SortContestFiles(files);

      CheckEquals(Length(EXPECTED), files.Count, 'sorting keeps every file');
      for i := 0 to files.Count - 1 do
         begin
         CheckEquals(EXPECTED[i], ExtractFileName(files[i].FileName),
                     'position ' + IntToStr(i));
         end;

      (* The comparison itself: a total order. *)
      CheckEquals(0, CompareContestFiles(files[0], files[0]), 'a file equals itself');
      for i := 0 to files.Count - 2 do
         begin
         CheckTrue(CompareContestFiles(files[i], files[i + 1]) < 0,
                   EXPECTED[i] + ' lists before ' + EXPECTED[i + 1]);
         CheckTrue(CompareContestFiles(files[i + 1], files[i]) > 0,
                   'and ' + EXPECTED[i + 1] + ' after ' + EXPECTED[i]);
         end;
   finally
      files.Free;
   end;
   CheckFalse(DirectoryExists(gone), 'describing a missing file created nothing');
end;

(* THE GRID SHOWS THAT ORDER, over real files: two years of logs and a .cfg. *)
procedure TNewContestFormTests.Test_TheGridListsInTheSortedOrder;
var
   frm: TfrmNewContest;
   dir: string;
   expected: TContestFileList;
   r: integer;
   searched: TSearchRec;
begin
   BeginTest('Test_TheGridListsInTheSortedOrder');

   dir := NewFilesDir('order');
   MakeTestContestLog(dir + 'a.db', ContestFromName('NE-QSO-PARTY'), 'NY4I');
   MakeTestContestLog(dir + 'b.db', ContestFromName('CQ-WW-SSB'), 'NY4I');
   MakeTestContestLog(dir + 'c.db', ContestFromName('CQ-WW-SSB'), 'K1AR');
   WriteTextFile(dir + '0 old.cfg', 'MY CALL = NY4I');

   frm := NewForm;
   expected := TContestFileList.Create(True);
   try
      (* The same files, described and sorted by uLatestContest alone. *)
      if FindFirst(RawByteString(dir + '*'), faAnyFile, searched) = 0 then
         begin
         repeat
            if (searched.Attr and faDirectory) = 0 then
               begin
               expected.Add(TLatestContest.Create(dir + string(searched.Name)));
               end;
         until FindNext(searched) <> 0;
         FindClose(searched);
         end;
      SortContestFiles(expected);

      frm.PopulateFiles(dir);
      CheckEquals(1 + expected.Count, frm.grdFiles.RowCount, 'one row per file');
      for r := 1 to frm.grdFiles.RowCount - 1 do
         begin
         CheckEquals(expected[r - 1].FileName, frm.FileOnRow(r),
                     'row ' + IntToStr(r) + ' is SortContestFiles'' file ' + IntToStr(r - 1));
         end;
      (* All three logs were made this year: the contest names decide, and
        the file name breaks the tie between the two CQ WW logs. *)
      CheckEquals('b.db', frm.grdFiles.Cells[3, 1], 'CQ WW (b) first');
      CheckEquals('c.db', frm.grdFiles.Cells[3, 2], 'then CQ WW (c)');
      CheckEquals('a.db', frm.grdFiles.Cells[3, 3], 'then the party');
      CheckEquals('0 old.cfg', frm.grdFiles.Cells[3, 4],
                  'and the .cfg last, though its name sorts first');
   finally
      expected.Free;
      frm.Free;
      RemoveFilesDir(dir);
   end;
end;

(* ENTER IN THE GRID OPENS THE SELECTED LOG, through the OnKeyDown the .lfm
  wires, and CONSUMES the key: a consumed key-down never reaches
  TApplication.ControlKeyDown, so the key-up does not press OK (the Default
  button) as well. A grid with no logs leaves Enter to OK. *)
procedure TNewContestFormTests.Test_EnterOpensTheSelectedLog;
var
   frm: TfrmNewContest;
   dir: string;
   key: Word;
begin
   BeginTest('Test_EnterOpensTheSelectedLog');

   dir := NewFilesDir('enter');
   MakeTestContestLog(dir + 'a.db', ContestFromName('CQ-WW-SSB'), 'NY4I');
   MakeTestContestLog(dir + 'b.db', ContestFromName('CQ-WW-SSB'), 'K1AR');

   frm := NewForm;
   try
      CheckTrue(Assigned(frm.grdFiles.OnKeyDown),
                'uNewContestForm.lfm must wire the grid''s OnKeyDown');
      if not Assigned(frm.grdFiles.OnKeyDown) then
         begin
         Exit;
         end;
      frm.PopulateFiles(dir);
      frm.grdFiles.Row := 2;

      key := VK_A;
      frm.grdFiles.OnKeyDown(frm.grdFiles, key, []);
      CheckEquals(VK_A, key, 'another key is the grid''s own');
      CheckEquals(Ord(nccNone), Ord(frm.Choice), 'and opens nothing');

      key := VK_RETURN;
      frm.grdFiles.OnKeyDown(frm.grdFiles, key, [ssShift]);
      CheckEquals(VK_RETURN, key, 'Shift+Enter is not taken');
      CheckEquals(Ord(nccNone), Ord(frm.Choice), 'and opens nothing');
      CheckEquals(Ord(mrNone), Ord(frm.ModalResult), 'and does not close the dialog');

      key := VK_RETURN;
      frm.grdFiles.OnKeyDown(frm.grdFiles, key, []);
      CheckEquals(0, key, 'Enter is consumed, so OK is not pressed as well');
      CheckEquals(Ord(nccOpenSelected), Ord(frm.Choice), 'Enter OPENS the log');
      CheckEquals(Ord(mrOk), Ord(frm.ModalResult), 'and closes the dialog');
      CheckEquals(frm.FileOnRow(2), frm.SelectedFile, 'the selected row''s log');
      CheckTrue(frm.SelectedFile <> '', 'which is a file');
   finally
      frm.Free;
   end;

   (* NO LOGS: the selected row is the header, which no Enter can open. *)
   RemoveFilesDir(dir);
   dir := NewFilesDir('enter');
   frm := NewForm;
   try
      frm.PopulateFiles(dir);
      CheckEquals(1, frm.grdFiles.RowCount, 'only the header');
      key := VK_RETURN;
      if Assigned(frm.grdFiles.OnKeyDown) then
         begin
         frm.grdFiles.OnKeyDown(frm.grdFiles, key, []);
         end;
      CheckEquals(VK_RETURN, key, 'with no log, Enter is left to OK');
      CheckEquals(Ord(nccNone), Ord(frm.Choice), 'and the header is not opened');
      CheckEquals(Ord(mrNone), Ord(frm.ModalResult), 'and the dialog stays open');
   finally
      frm.Free;
      RemoveFilesDir(dir);
   end;
end;

procedure TNewContestFormTests.RunAllTests;
begin
   Test_TheCaptionFunctionNamesTheBuild;
   Test_TheShownFormNamesTheBuild;
   Test_SearchMatchesAnywhereIgnoringCase;
   Test_AnEmptySearchKeepsTheWholeListInOrder;
   Test_QSOListsEveryQSOPartyAndNothingElse;
   Test_InactiveContestsAreKeptOnlyWhenAsked;
   Test_AnInactiveContestCannotStartANewOne;
   Test_TheListStartsWithEveryActiveContest;
   Test_TheSearchBoxNarrowsTheList;
   Test_AStillShownContestStaysChosen;
   Test_AHiddenContestIsUnchosen;
   Test_DownArrowChoosesTheFirstRow;
   Test_TheShowInactiveBoxListsThemLast;
   Test_AnInactiveRowCannotBeChosen;
   Test_UntickingClearsAnInactiveSelection;
   Test_TheListIsWideEnoughForEveryName;
   Test_TheFileGridDescribesEachLog;
   Test_TheSelectedRowIsTheFileOpened;
   Test_TheFileGridIsWideEnoughAndSizesOnce;
   Test_GrowthStopsAtTheWorkArea;
   Test_AHundredLogsFillQuickly;
   Test_LogsSortNewestYearFirst;
   Test_TheGridListsInTheSortedOrder;
   Test_EnterOpensTheSelectedLog;
end;

end.
