unit uTestLogSearchFilters;
{$I ..\..\src\tr4w.inc}

(*
  THE SEARCH LOG WINDOW: A FILTER ROW NAMES ITS BAND OR MODE (pointer audit P9,
  item 5.2).

  The Band and Mode drop-downs are rebuilt on every search from the bands and
  modes the results contain, with an "All" row first. Which band a row MEANS
  rode in Items.Objects[] as TObject(Ord(band) + 1) -- the +1 so that nil could
  mean "All". A row that came back as the wrong band would filter the log on a
  band the operator did not pick, and the results would simply look sparse.

  WRITTEN AGAINST THE OLD SHAPE FIRST and run green there; then the view's
  typed arrays replaced the integers with these tests unchanged. The pinned
  promise: whichever row is chosen, SelectedBand / SelectedMode is the value
  whose spelling that row shows, row 0 is "do not filter", and a choice
  survives a rebuild that still offers it.

  A REAL FORM, streamed and never shown: its FormCreate builds the grid and the
  lists, which is the path the window takes.
*)

interface

uses
   SysUtils, Classes, VC, uTR4WTestFramework;

type
   TLogSearchFilterTests = class(TTestCase)
   protected
      procedure Test_EveryBandRowNamesTheBandItShows;
      procedure Test_EveryModeRowNamesTheModeItShows;
      procedure Test_TheFirstRowIsDoNotFilter;
      procedure Test_AChoiceSurvivesARebuildThatStillOffersIt;
      procedure Test_AChoiceNoLongerOfferedFallsBackToAll;
      procedure Test_TheContestBandListMapsEveryRow;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,             (* Application *)
   uLogSearchForm;

function NewForm: TfrmLogSearch;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   Result := TfrmLogSearch.Create(nil);
end;

procedure Rebuild(const aForm: TfrmLogSearch; const aBands: TBandSet;
                  const aModes: TModeSet);
var
   ops: TStringList;
begin
   ops := TStringList.Create;
   try
      aForm.RebuildFilterLists(aBands, aModes, ops);
   finally
      ops.Free;
   end;
end;

function RowOf(const aItems: TStrings; const aCaption: string): integer;
begin
   Result := aItems.IndexOf(aCaption);
end;

procedure TLogSearchFilterTests.Test_EveryBandRowNamesTheBandItShows;
var
   f: TfrmLogSearch;
   i: integer;
   seen: TBandSet;
begin
   BeginTest('Search Log: every Band row selects the band it shows');
   f := NewForm;
   try
      Rebuild(f, [Band160, Band20, Band10, Band2], [CW]);
      CheckEquals(5, f.cboBand.Items.Count, 'All plus four bands');
      seen := [];
      for i := 1 to f.cboBand.Items.Count - 1 do
         begin
         f.cboBand.ItemIndex := i;
         CheckEquals(f.cboBand.Items[i],
                     string(AnsiString(BandStringsArray[f.SelectedBand])),
                     'band row ' + IntToStr(i));
         Include(seen, f.SelectedBand);
         end;
      CheckTrue(seen = [Band160, Band20, Band10, Band2], 'the rows are the bands asked for');
   finally
      f.Free;
   end;
end;

procedure TLogSearchFilterTests.Test_EveryModeRowNamesTheModeItShows;
var
   f: TfrmLogSearch;
   i: integer;
   seen: TModeSet;
begin
   BeginTest('Search Log: every Mode row selects the mode it shows');
   f := NewForm;
   try
      Rebuild(f, [Band20], [CW, Digital, Phone, FM]);
      CheckEquals(5, f.cboMode.Items.Count, 'All plus four modes');
      seen := [];
      for i := 1 to f.cboMode.Items.Count - 1 do
         begin
         f.cboMode.ItemIndex := i;
         CheckEquals(f.cboMode.Items[i],
                     string(AnsiString(ModeStringArray[f.SelectedMode])),
                     'mode row ' + IntToStr(i));
         Include(seen, f.SelectedMode);
         end;
      CheckTrue(seen = [CW, Digital, Phone, FM], 'the rows are the modes asked for');
   finally
      f.Free;
   end;
end;

procedure TLogSearchFilterTests.Test_TheFirstRowIsDoNotFilter;
var
   f: TfrmLogSearch;
begin
   BeginTest('Search Log: row 0 of each list is All -- AllBands and Both');
   f := NewForm;
   try
      Rebuild(f, [Band40], [Phone]);
      f.cboBand.ItemIndex := 0;
      f.cboMode.ItemIndex := 0;
      CheckEquals(Ord(AllBands), Ord(f.SelectedBand), 'band row 0');
      CheckEquals(Ord(Both), Ord(f.SelectedMode), 'mode row 0');
      f.cboBand.ItemIndex := -1;
      f.cboMode.ItemIndex := -1;
      CheckEquals(Ord(AllBands), Ord(f.SelectedBand), 'no band row');
      CheckEquals(Ord(Both), Ord(f.SelectedMode), 'no mode row');
   finally
      f.Free;
   end;
end;

procedure TLogSearchFilterTests.Test_AChoiceSurvivesARebuildThatStillOffersIt;
var
   f: TfrmLogSearch;
begin
   BeginTest('Search Log: a chosen band and mode survive a rebuild that still offers them');
   f := NewForm;
   try
      Rebuild(f, [Band80, Band40], [CW, Phone]);
      f.cboBand.ItemIndex := RowOf(f.cboBand.Items, string(AnsiString(BandStringsArray[Band40])));
      f.cboMode.ItemIndex := RowOf(f.cboMode.Items, string(AnsiString(ModeStringArray[Phone])));
      CheckEquals(Ord(Band40), Ord(f.SelectedBand), 'band before');
      CheckEquals(Ord(Phone), Ord(f.SelectedMode), 'mode before');

      (* A band added BEFORE the chosen one moves it down a row. *)
      Rebuild(f, [Band160, Band80, Band40], [CW, Digital, Phone]);
      CheckEquals(Ord(Band40), Ord(f.SelectedBand), 'band after');
      CheckEquals(Ord(Phone), Ord(f.SelectedMode), 'mode after');
   finally
      f.Free;
   end;
end;

procedure TLogSearchFilterTests.Test_AChoiceNoLongerOfferedFallsBackToAll;
var
   f: TfrmLogSearch;
begin
   BeginTest('Search Log: a choice the rebuild no longer offers becomes All');
   f := NewForm;
   try
      Rebuild(f, [Band80, Band40], [CW, Phone]);
      f.cboBand.ItemIndex := RowOf(f.cboBand.Items, string(AnsiString(BandStringsArray[Band40])));
      f.cboMode.ItemIndex := RowOf(f.cboMode.Items, string(AnsiString(ModeStringArray[Phone])));

      Rebuild(f, [Band80], [CW]);
      CheckEquals(0, f.cboBand.ItemIndex, 'band row');
      CheckEquals(Ord(AllBands), Ord(f.SelectedBand), 'band');
      CheckEquals(0, f.cboMode.ItemIndex, 'mode row');
      CheckEquals(Ord(Both), Ord(f.SelectedMode), 'mode');
   finally
      f.Free;
   end;
end;

(* With nothing searched for, the band list is the contest's own bands and
  the mode list every mode but Both. Which bands depends on the contest the
  test run has loaded, so this asks only that every row maps to the band it
  spells -- never AllBands, never NoBand, never twice. *)
procedure TLogSearchFilterTests.Test_TheContestBandListMapsEveryRow;
var
   f: TfrmLogSearch;
   i: integer;
   seen: TBandSet;
begin
   BeginTest('Search Log: the unsearched band list maps every row to its own band');
   f := NewForm;
   try
      Rebuild(f, [], []);
      CheckTrue(f.cboBand.Items.Count > 1, 'the contest offered no bands');
      seen := [];
      for i := 1 to f.cboBand.Items.Count - 1 do
         begin
         f.cboBand.ItemIndex := i;
         CheckEquals(f.cboBand.Items[i],
                     string(AnsiString(BandStringsArray[f.SelectedBand])),
                     'band row ' + IntToStr(i));
         CheckFalse(f.SelectedBand in [AllBands, NoBand], 'row ' + IntToStr(i) + ' is not a band');
         CheckFalse(f.SelectedBand in seen, 'row ' + IntToStr(i) + ' repeats a band');
         Include(seen, f.SelectedBand);
         end;
      for i := 1 to f.cboMode.Items.Count - 1 do
         begin
         f.cboMode.ItemIndex := i;
         CheckEquals(f.cboMode.Items[i],
                     string(AnsiString(ModeStringArray[f.SelectedMode])),
                     'mode row ' + IntToStr(i));
         end;
   finally
      f.Free;
   end;
end;

procedure TLogSearchFilterTests.RunAllTests;
begin
   Test_EveryBandRowNamesTheBandItShows;
   Test_EveryModeRowNamesTheModeItShows;
   Test_TheFirstRowIsDoNotFilter;
   Test_AChoiceSurvivesARebuildThatStillOffersIt;
   Test_AChoiceNoLongerOfferedFallsBackToAll;
   Test_TheContestBandListMapsEveryRow;
end;

end.
