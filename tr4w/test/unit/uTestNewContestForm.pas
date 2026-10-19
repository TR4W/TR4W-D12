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
   LCLType,           (* VK_DOWN *)
   uTR4WTestFramework,
   uTR4WStrings,      (* TC_OPENCONFIGURATIONFILE *)
   Version,           (* TR4W_CURRENTVERSION *)
   VC,                (* TContestHandle, NoContest *)
   uContestChoices,   (* the list, its order and its search -- Q103 *)
   uContestRegistry,  (* ContestIdentity -- IsActive, Q59 *)
   uAppStrings,       (* SNewContestShowInactive *)
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
end;

end.
