unit uTestNewContestHostArea;
{$I ..\..\src\tr4w.inc}

(* A QSO PARTY STATION SAYS WHETHER IT IS IN THE HOST AREA -- issue 217.

  NY4I, 2026-11-05, Florida QSO Party, a Florida station: the row read MY
  STATE while its notice asked for a county, and nothing checked what was
  typed. The dialog now asks "I am in FL" first; ticked, the row is a list of
  the county file's keys, unticked, free entry for a state, a province or DX.

  WHAT IS PINNED, AND WHY EACH:

    the places      are the county file's KEYS, by uDomFileKeys' own rule,
                    INCLUDE not followed -- because set-up's in-state test
                    (FCONTEST.FoundMyStateInDomFile) reads them that way;
    inside          is exactly "a key of that file" -- the same test;
    outside         takes a state, a province or DX and nothing else;
    every party     that offers the box offers only places set-up judges IN
                    state, on the row its own prompts ask for -- a walk over
                    the registry, so no party loses its prompt and a new one
                    is held without a row added here;
    the dialog      queues MY STATE with the same text either way: 'ALC'
                    chosen from the list is what typing ALC queued, and 'GA'
                    typed outside is 'GA'. Driven through uNewContest's real
                    rules on a form that is never shown. *)

interface

uses
   uTR4WTestFramework;

type
   TNewContestHostAreaTests = class(TTestCase)
   protected
      procedure Test_PlacesAreTheCountyFileKeys;
      procedure Test_InsideIsExactlyAKeyOfTheCountyFile;
      procedure Test_AnOutsideEntryIsAStateAProvinceOrDX;
      procedure Test_EveryPartyThatAsksOffersOnlyInStatePlaces;
      procedure Test_TheDialogQueuesTheSameMyStateInsideAndOut;
      procedure Test_TickingKeepsTheOtherRows;
      procedure Test_APartyWithoutTheBoxKeepsFreeEntry;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, Forms,
   VC,                  (* ContestType, TContestHandle *)
   uContestBase,        (* TNewContestHostArea, TNewContestPrompts *)
   uContestRegistry,    (* ContestIdentity, ContestHandleOf, FindContestById *)
   uTestRegisteredContests, (* ContestsToWalk, ContestWho, HandleOf *)
   uAppPaths,           (* ShippedDomFilePath *)
   uTestContestObjects, (* ShippedDomDir -- the tree's target\dom *)
   uDomFileKeys,        (* DomFileOnDiskDeclaresKey, DOM_EXTENSION *)
   uAppStrings,         (* SNewContestHostArea* *)
   uTR4WStrings,        (* TC_IAMIN *)
   uNewContestHostArea,
   uNewContestCommands, (* ClearNewContestChoices, QueuedNewContestValue *)
   uNewContest,         (* AttachNewContestForm, QueueNewContestRows *)
   uNewContestForm;

(* A shipped .dom in the tree's target\dom, in any case -- the file set-up
  reads as ShippedDomFilePath(name), which is DataDir's dom folder and is
  not the tree's off Windows (uTestShippedDom's note). *)
function TreeDomFile(const aFileName: string): string;
begin
   Result := ExistingDataFile(ShippedDomDir + aFileName);
end;

(* The county file a contest's box reads, as set-up names it. *)
function PlacesPath(const aArea: TNewContestHostArea): string;
begin
   Result := TreeDomFile(aArea.PlacesFile + string(DOM_EXTENSION));
end;

function LoadedPlaces(const aFileName: string): THostAreaPlaces;
begin
   Result := THostAreaPlaces.Create;
   Result.LoadFromFile(TreeDomFile(aFileName));
end;

procedure TNewContestHostAreaTests.Test_PlacesAreTheCountyFileKeys;
var
   lines: TStringList;
   places: THostAreaPlaces;
begin
   BeginTest('Test_PlacesAreTheCountyFileKeys');

   lines := TStringList.Create;
   places := THostAreaPlaces.Create;
   try
      lines.Add('3 Test Counties');            (* a header: no '=', no key *)
      lines.Add('');
      lines.Add('Alc = ALC');
      lines.Add('Ande = ANDE,^Anderson');
      lines.Add('Bak > Fl = BAK');              (* a mapped key: cut at '>' *)
      lines.Add('alc = ALACHUA');               (* the same key again: first wins *)
      lines.Add('INCLUDE FILE S50.DOM');        (* not followed *)
      places.LoadFromLines(lines);

      CheckEquals(3, places.Count, 'three keys, the repeat and the header dropped');
      CheckEquals('ALC', places.Key(0), 'the key, upper-cased as typing stored it');
      CheckEquals('ALC', places.Display(0), 'no ^name: the key alone');
      CheckEquals('ANDE', places.Key(1), 'Texas-style key');
      CheckEquals('ANDE - Anderson', places.Display(1), 'with its ^name');
      CheckEquals('BAK', places.Key(2), 'the key is the text before ">"');
      CheckEquals(-1, places.IndexOfKey('GA'), 'nothing from the INCLUDE');
   finally
      places.Free;
      lines.Free;
   end;

   (* The shipped files: a county party with no names (Florida), one with
     names (Texas), and a district party (British Columbia). *)
   places := LoadedPlaces('florida_cty' + string(DOM_EXTENSION));
   try
      CheckEquals(67, places.Count, 'Florida''s 67 counties');
      CheckTrue(places.IndexOfKey('ALC') >= 0, 'Alachua is ALC');
   finally
      places.Free;
   end;

   places := LoadedPlaces('texas_cty' + string(DOM_EXTENSION));
   try
      CheckEquals(254, places.Count, 'Texas''s 254 counties');
      CheckTrue(places.IndexOfKey('ANDE') >= 0, 'Anderson is ANDE');
      if places.IndexOfKey('ANDE') >= 0 then
         begin
         CheckEquals('ANDE - Anderson', places.Display(places.IndexOfKey('ANDE')),
                     'a Texas county shows its name');
         end;
   finally
      places.Free;
   end;

   places := LoadedPlaces('ve7_cty' + string(DOM_EXTENSION));
   try
      CheckTrue(places.Count > 0, 'British Columbia''s districts load the same way');
      CheckTrue(places.IndexOfKey('ABF') >= 0, 'ABF is a district');
   finally
      places.Free;
   end;
end;

procedure TNewContestHostAreaTests.Test_InsideIsExactlyAKeyOfTheCountyFile;
const
   VALUES: array[0..7] of string = ('ALC', 'alc', ' Alc ', 'GA', 'FL', 'DX', '', 'ALACHUA');
var
   places: THostAreaPlaces;
   path: string;
   i: integer;
begin
   BeginTest('Test_InsideIsExactlyAKeyOfTheCountyFile');

   path := TreeDomFile('florida_cty' + string(DOM_EXTENSION));
   places := THostAreaPlaces.Create;
   try
      places.LoadFromFile(path);
      CheckTrue(HostAreaStationIsInside(places, 'ALC'), 'a county is inside');
      CheckTrue(HostAreaStationIsInside(places, 'alc'), 'in any case');
      CheckFalse(HostAreaStationIsInside(places, 'GA'), 'a state is outside');
      CheckFalse(HostAreaStationIsInside(places, ''), 'nothing is nowhere');
      CheckFalse(HostAreaStationIsInside(nil, 'ALC'), 'no places, no inside');

      (* AND IT IS SET-UP'S ANSWER, value for value. *)
      for i := Low(VALUES) to High(VALUES) do
         begin
         CheckTrue(DomFileOnDiskDeclaresKey(path, VALUES[i]) =
                   HostAreaStationIsInside(places, VALUES[i]),
                   '"' + VALUES[i] + '": the dialog and set-up agree');
         end;
   finally
      places.Free;
   end;
end;

procedure TNewContestHostAreaTests.Test_AnOutsideEntryIsAStateAProvinceOrDX;
var
   places: THostAreaPlaces;
begin
   BeginTest('Test_AnOutsideEntryIsAStateAProvinceOrDX');

   places := LoadedPlaces('florida_cty' + string(DOM_EXTENSION));
   try
      CheckEquals('', HostAreaOutsideRefusal(places, 'FL', 'FL', 'GA'), 'a state');
      CheckEquals('', HostAreaOutsideRefusal(places, 'FL', 'FL', 'ga'), 'in any case');
      CheckEquals('', HostAreaOutsideRefusal(places, 'FL', 'FL', 'ON'), 'a province');
      CheckEquals('', HostAreaOutsideRefusal(places, 'FL', 'FL', 'DX'), 'DX');
      CheckEquals('', HostAreaOutsideRefusal(places, 'FL', 'FL', ''),
                  'empty is the dialog''s own empty-row rule');

      CheckEquals(Format(SNewContestHostAreaEntryNotAState, ['XX']),
                  HostAreaOutsideRefusal(places, 'FL', 'FL', 'XX'),
                  'XX is no state, province or DX');
      CheckEquals(Format(SNewContestHostAreaEntryNotAState, ['GEORGIA']),
                  HostAreaOutsideRefusal(places, 'FL', 'FL', 'Georgia'),
                  'the two-letter code, not the name');
      CheckEquals(Format(SNewContestHostAreaEntryIsInside, ['ALC', 'FL']),
                  HostAreaOutsideRefusal(places, 'FL', 'FL', 'ALC'),
                  'a county belongs inside');
      CheckEquals(Format(SNewContestHostAreaEntryIsInside, ['FL', 'FL']),
                  HostAreaOutsideRefusal(places, 'FL', 'FL', 'fl'),
                  'so does the host state itself');
      CheckEquals('', HostAreaOutsideRefusal(places, '7th area', '', 'AZ'),
                  'a multi-state area names no host state to refuse');
   finally
      places.Free;
   end;
end;

(* Does aContest's own prompt list ask for aField (aAsked), and does it offer
  a box of its own (aBoxed)? *)
procedure ReadPrompts(aContest: TContestBase; aField: TNewContestField;
                      out aAsked, aBoxed: boolean);
var
   prompts: TNewContestPrompts;
   i: integer;
begin
   prompts := TNewContestPrompts.Create;
   try
      aContest.DescribeNewContestPrompts(prompts);
      aAsked := False;
      aBoxed := prompts.InsideCount > 0;
      for i := 0 to prompts.ChoiceCount - 1 do
         begin
         if (prompts.Choice(i).Kind in [npkField, npkFieldWithComment]) and
            (prompts.Choice(i).Field = aField) then
            begin
            aAsked := True;
            end;
         if prompts.Choice(i).Kind in [npkIAmIn, npkIAmInCaption] then
            begin
            aBoxed := True;
            end;
         end;
   finally
      prompts.Free;
   end;
end;

procedure TNewContestHostAreaTests.Test_EveryPartyThatAsksOffersOnlyInStatePlaces;
var
   contests: TContestIdentityList;
   area: TNewContestHostArea;
   places: THostAreaPlaces;
   path: string;
   offering: integer;
   i, k: integer;
   handle: TContestHandle;
   withoutBox: array[0..3] of TContestHandle;
   expectedWithout: boolean;
   asked: boolean;
   boxed: boolean;
begin
   BeginTest('Test_EveryPartyThatAsksOffersOnlyInStatePlaces');

   (* THE US QSO PARTIES THAT STATE NO BOX, each for a reason its class
     gives (issue 217): a different outside rule, or no inside at all. *)
   withoutBox[0] := ContestHandleOf(BCQP);
   withoutBox[1] := ContestHandleOf(IN7QPNE);
   CheckTrue(FindContestById('ON-QSO-PARTY', withoutBox[2]), 'Ontario is registered');
   CheckTrue(FindContestById('QC-QSO-PARTY', withoutBox[3]), 'Quebec is registered');

   contests := ContestsToWalk;
   offering := 0;
   for i := 0 to High(contests) do
      begin
      handle := HandleOf(contests[i]);
      expectedWithout := False;
      for k := Low(withoutBox) to High(withoutBox) do
         begin
         if handle = withoutBox[k] then
            begin
            expectedWithout := True;
            end;
         end;

      if not contests[i].DescribeNewContestHostArea(area) then
         begin
         CheckFalse(contests[i].IsUSQSOParty and (not expectedWithout),
                    ContestWho(contests[i]) + ': a US QSO party offers the box ' +
                    'unless its class says why not');
         Continue;
         end;

      inc(offering);
      CheckTrue(contests[i].IsUSQSOParty, ContestWho(contests[i]) +
                ': only a party whose set-up runs the in-state test offers the box');
      CheckFalse(expectedWithout, ContestWho(contests[i]) + ': states no box');
      CheckTrue(area.Field = ncfMyState, ContestWho(contests[i]) +
                ': the box governs MY STATE, the field set-up reads');
      CheckTrue(area.Area <> '', ContestWho(contests[i]) + ': the box names its area');
      CheckEquals(contests[i].DomesticFileName, area.PlacesFile,
                  ContestWho(contests[i]) + ': the places are the in-state test''s file');
      ReadPrompts(contests[i], area.Field, asked, boxed);
      CheckTrue(asked, ContestWho(contests[i]) +
                ': its prompts ask for the row the box governs');
      CheckFalse(boxed, ContestWho(contests[i]) +
                 ': the box is the host area''s, so it offers none of its own');

      path := PlacesPath(area);
      places := THostAreaPlaces.Create;
      try
         places.LoadFromFile(path);
         CheckTrue(places.Count > 0, ContestWho(contests[i]) + ': ' + path +
                   ' gives the list its places');
         for k := 0 to places.Count - 1 do
            begin
            if not DomFileOnDiskDeclaresKey(path, places.Key(k)) then
               begin
               CheckTrue(False, ContestWho(contests[i]) + ': ' + places.Key(k) +
                         ' is offered but set-up would judge it OUT of state');
               Break;
               end;
            end;
      finally
         places.Free;
      end;
      end;

   CheckTrue(offering > 0, 'some party offers the box -- the walk is not empty');
   CheckTrue(ContestIdentity(ContestHandleOf(FLORIDAQSOPARTY)).DescribeNewContestHostArea(area),
             'the Florida QSO Party offers it (the report)');
   CheckEquals('FL', area.Area, 'Florida''s box says FL');
   CheckEquals('FL', area.HostState, 'and refuses FL as an outside entry');
   CheckTrue(ContestIdentity(ContestHandleOf(SEVENQP)).DescribeNewContestHostArea(area),
             'the 7QP, a multi-state party off the party base, offers it');
   CheckEquals('', area.HostState, 'the 7QP names no single host state');
end;

(* A fresh, never-shown dialog with uNewContest's rules attached. *)
function NewDialog: TfrmNewContest;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   Result := TfrmNewContest.Create(nil);
   AttachNewContestForm(Result, ShippedDomDir);
end;

procedure FreeDialog(aForm: TfrmNewContest);
begin
   DetachNewContestForm;
   aForm.Free;
end;

(* Chooses aContest in the list, as a click does. *)
function Choose(aForm: TfrmNewContest; aContest: TContestHandle): boolean;
var
   i: integer;
begin
   Result := False;
   aForm.edtContestFilter.Text := ContestIdentity(aContest).DisplayName;
   aForm.edtContestFilter.OnChange(aForm.edtContestFilter);
   for i := 0 to aForm.lstContests.Items.Count - 1 do
      begin
      aForm.lstContests.ItemIndex := i;
      aForm.lstContests.OnSelectionChange(aForm.lstContests, True);
      if aForm.SelectedContest = aContest then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

procedure Tick(aForm: TfrmNewContest; aChecked: boolean);
begin
   aForm.chkIAmIn.Checked := aChecked;
   aForm.chkIAmIn.OnChange(aForm.chkIAmIn);
end;

(* The row whose label is aCaption, or 0. *)
function RowCaptioned(aForm: TfrmNewContest; const aCaption: string): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 1 to aForm.Rows do
      begin
      if aForm.RowCaption(i) = aCaption then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TNewContestHostAreaTests.Test_TheDialogQueuesTheSameMyStateInsideAndOut;
var
   frm: TfrmNewContest;
   row: integer;
begin
   BeginTest('Test_TheDialogQueuesTheSameMyStateInsideAndOut');

   frm := NewDialog;
   try
      frm.SetMyCall('NY4I');
      CheckTrue(Choose(frm, ContestHandleOf(FLORIDAQSOPARTY)), 'Florida can be chosen');

      (* OUTSIDE, as the dialog opens: free entry under MY STATE. *)
      CheckTrue(frm.chkIAmIn.Visible, 'the box is offered');
      CheckEquals(Format(TC_IAMIN, ['FL']), frm.chkIAmIn.Caption, '"I am in FL"');
      CheckFalse(frm.IAmIn, 'and starts unticked');
      row := RowCaptioned(frm, SNewContestHostAreaStateLabel);
      CheckTrue(row > 0, 'outside, the row reads MY STATE');
      CheckFalse(frm.RowIsPick(row), 'and is free entry');
      CheckEquals(Format(SNewContestHostAreaOutsideNotice, ['FL']),
                  frm.lblComment.Caption, 'the outside notice');

      frm.SetRowText(row, 'XX');
      CheckFalse(frm.btnOK.Enabled, 'XX is refused');
      CheckEquals(Format(SNewContestHostAreaEntryNotAState, ['XX']),
                  frm.lblComment.Caption, 'and the notice says why');

      frm.SetRowText(row, 'GA');
      CheckTrue(frm.btnOK.Enabled, 'GA is accepted');
      CheckEquals(Format(SNewContestHostAreaOutsideNotice, ['FL']),
                  frm.lblComment.Caption, 'the notice is back');
      ClearNewContestChoices;
      QueueNewContestRows;
      CheckEquals('GA', QueuedNewContestValue('MY STATE'), 'outside sends GA, as typed');

      (* INSIDE: a list of the counties under MY COUNTY. *)
      Tick(frm, True);
      CheckEquals(row, RowCaptioned(frm, SNewContestHostAreaCountyLabel),
                  'inside, the same row reads MY COUNTY');
      CheckTrue(frm.RowIsPick(row), 'and is a list');
      CheckEquals('', frm.RowText(row), 'with nothing chosen -- GA did not carry over');
      CheckFalse(frm.btnOK.Enabled, 'no county, no OK');
      CheckEquals(Format(SNewContestHostAreaInsideNotice, ['FL']),
                  frm.lblComment.Caption, 'the inside notice');

      CheckTrue(frm.PickRowValue(row, 'ALC'), 'ALC is in the list');
      CheckEquals('ALC', frm.RowText(row), 'the row holds the key');
      CheckTrue(frm.btnOK.Enabled, 'a county chosen: OK');
      ClearNewContestChoices;
      QueueNewContestRows;
      CheckEquals('ALC', QueuedNewContestValue('MY STATE'),
                  'inside sends ALC under MY STATE -- what typing ALC sent');
      CheckEquals('', QueuedNewContestValue('MY COUNTY'), 'the label is not a command');

      (* And back out: free entry, empty again. *)
      Tick(frm, False);
      CheckFalse(frm.RowIsPick(row), 'unticked, free entry again');
      CheckEquals('', frm.RowText(row), 'and empty -- ALC did not carry over');
   finally
      ClearNewContestChoices;
      FreeDialog(frm);
   end;
end;

procedure TNewContestHostAreaTests.Test_TickingKeepsTheOtherRows;
var
   frm: TfrmNewContest;
   nameRow: integer;
   stateRow: integer;
begin
   BeginTest('Test_TickingKeepsTheOtherRows');

   frm := NewDialog;
   try
      frm.SetMyCall('NY4I');
      CheckTrue(Choose(frm, ContestHandleOf(COLORADOQSOPARTY)), 'Colorado can be chosen');
      nameRow := RowCaptioned(frm, 'MY NAME');
      stateRow := RowCaptioned(frm, SNewContestHostAreaStateLabel);
      CheckTrue((nameRow > 0) and (stateRow > 0), 'Colorado asks for both rows');

      frm.SetRowText(nameRow, 'TOM');
      Tick(frm, True);
      CheckEquals('TOM', frm.RowText(nameRow), 'ticking the box leaves MY NAME alone');
      CheckTrue(frm.RowIsPick(stateRow), 'and turns only its own row into a list');
   finally
      FreeDialog(frm);
   end;
end;

procedure TNewContestHostAreaTests.Test_APartyWithoutTheBoxKeepsFreeEntry;
var
   frm: TfrmNewContest;
   row: integer;
begin
   BeginTest('Test_APartyWithoutTheBoxKeepsFreeEntry');

   frm := NewDialog;
   try
      frm.SetMyCall('NY4I');
      CheckTrue(Choose(frm, ContestHandleOf(BCQP)), 'British Columbia can be chosen');
      CheckFalse(frm.chkIAmIn.Visible, 'no box');
      row := RowCaptioned(frm, 'MY STATE');
      CheckTrue(row > 0, 'its row is MY STATE, as before');
      CheckFalse(frm.RowIsPick(row), 'free entry, as before');
      CheckEquals(TC_ENTERYOURISTRICTIFINVE7, frm.lblComment.Caption,
                  'its own notice, as before');
      frm.SetRowText(row, 'XX');
      CheckTrue(frm.btnOK.Enabled, 'and anything typed is taken, as before');
   finally
      FreeDialog(frm);
   end;
end;

procedure TNewContestHostAreaTests.RunAllTests;
begin
   Test_PlacesAreTheCountyFileKeys;
   Test_InsideIsExactlyAKeyOfTheCountyFile;
   Test_AnOutsideEntryIsAStateAProvinceOrDX;
   Test_EveryPartyThatAsksOffersOnlyInStatePlaces;
   Test_TheDialogQueuesTheSameMyStateInsideAndOut;
   Test_TickingKeepsTheOtherRows;
   Test_APartyWithoutTheBoxKeepsFreeEntry;
end;

end.
