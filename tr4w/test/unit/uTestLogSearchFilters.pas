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

  ISSUE 230 ADDS TWO PROMISES. The Callsign box is seeded only with what could
  be a call, and otherwise shows a placeholder (TextHint) rather than a word --
  on 2026-11-05 it opened holding SEARCH, typed into the main call entry. And
  with nothing searched for, the three lists hold what the LOG holds: those
  tests run RunSearch over a real SQLite log in a scratch directory, the way
  uTestLogMyFacts and uTestLogStore isolate theirs.
*)

interface

uses
   SysUtils, Classes, VC, uTR4WTestFramework;

type
   TLogSearchFilterTests = class(TTestCase)
   private
      FDir:          string;
      FDb:           string;
      FSavedLogName: string;
      FSavedSilent:  boolean;
      procedure StartEmptyLog(const aLeaf: string);
      procedure StopLog;
      procedure AppendQSO(const aSeed: integer; const aCall: string;
                          const aBand: BandType; const aMode: ModeType;
                          const aOperator: string);
      procedure AppendThreeBandTwoModeLog;
   protected
      procedure Test_EveryBandRowNamesTheBandItShows;
      procedure Test_EveryModeRowNamesTheModeItShows;
      procedure Test_TheFirstRowIsDoNotFilter;
      procedure Test_AChoiceSurvivesARebuildThatStillOffersIt;
      procedure Test_AChoiceNoLongerOfferedFallsBackToAll;
      procedure Test_TheContestBandListMapsEveryRow;
      procedure Test_OnlyACallOrPartOfOneSeedsTheCallBox;
      procedure Test_TheEmptyCallBoxShowsAPlaceholderNotText;
      procedure Test_OnlyALoggedContactWithAnOperatorFillsTheLists;
      procedure Test_AnEmptySearchListsWhatTheLogHolds;
      procedure Test_AnEmptyLogFallsBackAsBefore;
      procedure Test_ATypedSearchStillListsWhatTheOtherFiltersAdmit;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,             (* Application *)
   uLogStore,         (* LogStoreEnsureOpen, LogStoreAppendQSO, LogStoreClose *)
   uLogSource,        (* LogSourceClose -- the cursor the search leaves open *)
   uLogDatabase,      (* LogDatabaseFileName *)
   utils_text,        (* SetCharBuffer, CharBufferText *)
   uAppStrings,       (* SLogSearchCallHint *)
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

(* ------------------------------------------------------------ issue 230 *)

(* The rows after "All", in list order, joined with commas -- or, for the
  operator list (no "All" row), from row 0. *)
function RowsText(const aItems: TStrings; const aFirstRow: integer): string;
var
   i: integer;
begin
   Result := '';
   for i := aFirstRow to aItems.Count - 1 do
      begin
      if Result <> '' then
         begin
         Result := Result + ',';
         end;
      Result := Result + aItems[i];
      end;
end;

function BandText(const aBand: BandType): string;
begin
   Result := string(AnsiString(BandStringsArray[aBand]));
end;

function ModeText(const aMode: ModeType): string;
begin
   Result := string(AnsiString(ModeStringArray[aMode]));
end;

(* A NEW, EMPTY LOG in a scratch directory: no .trw beside it, so
  LogStoreEnsureOpen creates the database (uTestLogStore's
  TestAnEmptyLogIsBackedUpBeforeClear). *)
procedure TLogSearchFilterTests.StartEmptyLog(const aLeaf: string);
var
   trw: string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_logsearch_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;

   LogStoreClose;
   trw := IncludeTrailingPathDelimiter(FDir) + aLeaf + '.trw';
   FDb := LogDatabaseFileName(trw);
   if FileExists(FDb) then
      begin
      DeleteFile(FDb);
      end;

   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   FSavedSilent := tSilentExport;
   SetCharBuffer(TR4W_LOG_FILENAME, trw);
   (* A failure is a log line and a False, not a modal. *)
   tSilentExport := True;

   CheckTrue(LogStoreEnsureOpen, 'with no .trw the open makes a new, empty log');
end;

procedure TLogSearchFilterTests.StopLog;
const
   SUFFIXES: array[0..3] of string = ('', '-wal', '-shm', '-journal');
var
   i: integer;
begin
   LogSourceClose;
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(FDb + SUFFIXES[i]) then
         begin
         DeleteFile(FDb + SUFFIXES[i]);
         end;
      end;
end;

(* uTestLogMyFacts.MakeQSO's record, with the four fields these tests vary. *)
procedure TLogSearchFilterTests.AppendQSO(const aSeed: integer; const aCall: string;
                                          const aBand: BandType; const aMode: ModeType;
                                          const aOperator: string);
var
   q: ContestExchange;
begin
   q := Default(ContestExchange);
   q.ceRecordKind := rkQSO;
   q.ceContest := NoContest;
   q.id := 'logsearch' + IntToStr(aSeed);
   q.ceQSOID1 := 5000 + aSeed;
   q.ceQSOID2 := 6000 + aSeed;
   q.tSysTime.qtYear := 26;
   q.tSysTime.qtMonth := 11;
   q.tSysTime.qtDay := 5;
   q.tSysTime.qtHour := 12;
   q.tSysTime.qtMinute := aSeed;
   q.Callsign := aCall;
   q.Frequency := 14025000 + aSeed;
   q.Band := aBand;
   q.Mode := aMode;
   if aMode = Phone then
      begin
      q.ExtMode := eSSB;
      end
   else
      begin
      q.ExtMode := eCW;
      end;
   q.ceOperator := aOperator;
   q.NumberReceived := -1;
   q.NumberSent := -1;
   q.Prefecture := 255;
   q.Zone := 255;
   q.QTH.Zone := 255;
   q.TenTenNum := 65535;
   CheckTrue(LogStoreAppendQSO(q), 'logged ' + aCall);
end;

(* THREE BANDS, TWO MODES, TWO OPERATORS AND ONE BLANK ONE. 80m, the contest's
  own first band, is deliberately absent, so a list that fell back to the
  contest's bands would show it. *)
procedure TLogSearchFilterTests.AppendThreeBandTwoModeLog;
begin
   AppendQSO(1, 'W1AAA', Band20, CW,    'NY4I');
   AppendQSO(2, 'W1BBB', Band40, Phone, 'NY4I');
   AppendQSO(3, 'K2CCC', Band15, CW,    'K4XYZ');
   AppendQSO(4, 'N3DDD', Band20, Phone, '');
end;

procedure TLogSearchFilterTests.Test_OnlyACallOrPartOfOneSeedsTheCallBox;
begin
   BeginTest('Search Log: the Callsign box is seeded only with a call or part of one');
   (* The word that was in the box on 2026-11-05, and other words and a QSY. *)
   CheckFalse(CouldBePartOfACall('SEARCH'), 'SEARCH is a word');
   CheckFalse(CouldBePartOfACall('search'), 'in any case');
   CheckFalse(CouldBePartOfACall('CQ'), 'CQ is a word');
   CheckFalse(CouldBePartOfACall('14025'), 'a frequency typed to QSY');
   CheckFalse(CouldBePartOfACall(''), 'nothing');
   CheckFalse(CouldBePartOfACall('N6 TV'), 'a space is not a call character');
   (* What an operator searches for. *)
   CheckTrue(CouldBePartOfACall('N6'), 'a partial, NY4I''s own example');
   CheckTrue(CouldBePartOfACall('NY4I'), 'a call');
   CheckTrue(CouldBePartOfACall('W1AW/7'), 'a portable call');
   CheckTrue(CouldBePartOfACall(' k1abc '), 'trimmed and in any case');

   CheckEquals('K1ABC', SearchSeedFor('K1ABC', 'N6TV'), 'the call entry first');
   CheckEquals('N6TV', SearchSeedFor('SEARCH', 'N6TV'), 'then the call escaped out of it');
   CheckEquals('N6TV', SearchSeedFor('', 'N6TV'), 'an empty entry, as before');
   CheckEquals('', SearchSeedFor('SEARCH', ''), 'a word seeds nothing');
   CheckEquals('', SearchSeedFor('SEARCH', 'SEARCH'), 'not even from the escaped call');
end;

procedure TLogSearchFilterTests.Test_TheEmptyCallBoxShowsAPlaceholderNotText;
var
   f: TfrmLogSearch;
begin
   BeginTest('Search Log: the Callsign box''s prompt is a TextHint, never its Text');
   f := NewForm;
   try
      CheckEquals(SLogSearchCallHint, f.edtCall.TextHint, 'the translated placeholder');
      CheckEquals('', f.edtCall.Text, 'and the box holds no text');
   finally
      f.Free;
   end;
end;

procedure TLogSearchFilterTests.Test_OnlyALoggedContactWithAnOperatorFillsTheLists;
var
   facets: TLogSearchFacets;
   q: ContestExchange;
begin
   BeginTest('Search Log: a note adds nothing; a blank operator is not an operator');
   facets := TLogSearchFacets.Create;
   try
      q := Default(ContestExchange);
      q.ceRecordKind := rkNote;
      q.Band := Band160;
      q.Mode := FM;
      q.ceOperator := 'NOTE';
      facets.Admit(q, True, True, True);
      CheckTrue(facets.Bands = [], 'a note adds no band');
      CheckTrue(facets.Modes = [], 'nor a mode');
      CheckEquals(0, facets.Operators.Count, 'nor an operator');

      q.ceRecordKind := rkQSO;
      q.ceOperator := '';
      facets.Admit(q, True, True, True);
      CheckTrue(facets.Bands = [Band160], 'a QSO adds its band');
      CheckTrue(facets.Modes = [FM], 'and its mode');
      CheckEquals(0, facets.Operators.Count, 'but a blank operator is not listed');

      q.Band := Band20;
      q.Mode := CW;
      q.ceOperator := 'NY4I';
      facets.Admit(q, False, True, True);
      CheckTrue(facets.Bands = [Band160], 'a row not admitted to the band list adds no band');
      CheckTrue(facets.Modes = [FM, CW], 'but is admitted to the mode list');
      CheckEquals('NY4I', RowsText(facets.Operators, 0), 'and to the operator list');

      facets.Clear;
      CheckTrue((facets.Bands = []) and (facets.Modes = []) and
                (facets.Operators.Count = 0), 'Clear empties all three');
   finally
      facets.Free;
   end;
end;

procedure TLogSearchFilterTests.Test_AnEmptySearchListsWhatTheLogHolds;
var
   f: TfrmLogSearch;
begin
   BeginTest('Search Log: with nothing searched for, the lists are the log''s bands, modes, operators');
   StartEmptyLog('three-bands');
   try
      AppendThreeBandTwoModeLog;
      f := NewForm;
      try
         f.edtCall.Text := '';
         f.cboOperator.Text := '';
         f.tmrSearch.Enabled := False;
         f.RunSearch;

         CheckEquals(BandText(Band40) + ',' + BandText(Band20) + ',' + BandText(Band15),
                     RowsText(f.cboBand.Items, 1), 'the three bands the log holds, in band order');
         CheckEquals(ModeText(CW) + ',' + ModeText(Phone),
                     RowsText(f.cboMode.Items, 1), 'the two modes the log holds');
         CheckEquals('K4XYZ,NY4I', RowsText(f.cboOperator.Items, 0),
                     'the operators the log holds, the blank one left out');

         (* EVERY ROW STILL SELECTS WHAT IT SHOWS -- the bench check, pick each band. *)
         f.cboBand.ItemIndex := 2;
         CheckEquals(Ord(Band20), Ord(f.SelectedBand), 'the 20m row selects 20m');

         (* A QSO ON A NEW BAND, LOGGED WHILE THE BOX IS EMPTY: the cached read
           is not repeated by an empty search ... *)
         AppendQSO(5, 'K5EEE', Band10, CW, 'NY4I');
         f.RunSearch;
         CheckEquals(-1, f.cboBand.Items.IndexOf(BandText(Band10)),
                     'an empty search does not re-read the log');

         (* ... and is after the log changes: InvalidateLogFacets is what
           LogSearchRefreshIfOpen, FormShow and an edit from the results call. *)
         f.InvalidateLogFacets;
         f.RunSearch;
         CheckTrue(f.cboBand.Items.IndexOf(BandText(Band10)) > 0,
                   'the new band is listed once the log is read again');
      finally
         f.Free;
      end;
   finally
      StopLog;
   end;
end;

procedure TLogSearchFilterTests.Test_AnEmptyLogFallsBackAsBefore;
var
   f: TfrmLogSearch;
   fallbackBands, fallbackModes: string;
begin
   BeginTest('Search Log: an empty log lists the contest''s bands and every mode, as before');
   StartEmptyLog('empty');
   try
      f := NewForm;
      try
         (* What FormCreate built: the fallback, from nothing. *)
         Rebuild(f, [], []);
         fallbackBands := RowsText(f.cboBand.Items, 1);
         fallbackModes := RowsText(f.cboMode.Items, 1);
         CheckTrue(fallbackBands <> '', 'the contest offers bands');
         CheckEquals(ModeText(CW) + ',' + ModeText(Digital) + ',' + ModeText(Phone) + ',' +
                     ModeText(FM), fallbackModes,
                     'every mode an operator logs -- not BTH, and not NON');

         CheckTrue(f.ReadLogFacets, 'an empty log reads');
         f.edtCall.Text := '';
         f.tmrSearch.Enabled := False;
         f.RunSearch;
         CheckEquals(fallbackBands, RowsText(f.cboBand.Items, 1), 'the contest''s bands');
         CheckEquals(fallbackModes, RowsText(f.cboMode.Items, 1), 'every mode');
         CheckEquals(0, f.cboOperator.Items.Count, 'no operators');
         CheckEquals('', f.lblStatus.Caption, 'and an empty log is not an error');
      finally
         f.Free;
      end;
   finally
      StopLog;
   end;
end;

(* THE EXISTING RULE, UNCHANGED BY ISSUE 230: a typed search builds each list
  from the rows the OTHER filters admit, so choosing a band does not narrow
  the band list. *)
procedure TLogSearchFilterTests.Test_ATypedSearchStillListsWhatTheOtherFiltersAdmit;
var
   f: TfrmLogSearch;
begin
   BeginTest('Search Log: a typed search lists what the other filters admit');
   StartEmptyLog('typed');
   try
      AppendThreeBandTwoModeLog;
      f := NewForm;
      try
         f.edtCall.Text := 'W1';
         f.tmrSearch.Enabled := False;
         f.RunSearch;
         CheckEquals(BandText(Band40) + ',' + BandText(Band20),
                     RowsText(f.cboBand.Items, 1), 'the bands W1 was worked on');
         CheckEquals(ModeText(CW) + ',' + ModeText(Phone),
                     RowsText(f.cboMode.Items, 1), 'the modes W1 was worked in');
         CheckEquals('NY4I', RowsText(f.cboOperator.Items, 0), 'the operator who worked them');
         CheckEquals(1, Pos('2 ', f.lblStatus.Caption), 'two matches: ' + f.lblStatus.Caption);

         f.cboBand.ItemIndex := f.cboBand.Items.IndexOf(BandText(Band20));
         f.RunSearch;
         CheckEquals(Ord(Band20), Ord(f.SelectedBand), '20m is still chosen');
         CheckEquals(BandText(Band40) + ',' + BandText(Band20),
                     RowsText(f.cboBand.Items, 1), 'the band list ignores its own filter');
         CheckEquals(ModeText(CW), RowsText(f.cboMode.Items, 1),
                     'the mode list is W1 on 20m');
         CheckEquals(1, Pos('1 ', f.lblStatus.Caption), 'one match: ' + f.lblStatus.Caption);
      finally
         f.Free;
      end;
   finally
      StopLog;
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
   Test_OnlyACallOrPartOfOneSeedsTheCallBox;
   Test_TheEmptyCallBoxShowsAPlaceholderNotText;
   Test_OnlyALoggedContactWithAnOperatorFillsTheLists;
   Test_AnEmptySearchListsWhatTheLogHolds;
   Test_AnEmptyLogFallsBackAsBefore;
   Test_ATypedSearchStillListsWhatTheOtherFiltersAdmit;
end;

end.
