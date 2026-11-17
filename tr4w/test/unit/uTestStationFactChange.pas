(* A STATION-PAGE EDIT OF ANY VALUE THE OPEN CONTEST USES -- log schema 9,
  phase 2 (2026-11-17). Issue 300's license-year rule, generalised
  (uStationFactChange), and the pieces around it. THE BENCH FINDING: a wrong
  MY PREC stated at New Contest could not be corrected from the UI, because
  the Station page changed only the station's default and the contest's
  statement won. These pin:

    the use        which values a contest uses (uContestBase.
                   ContestUsesStationFact): its New Contest prompts, and the
                   license year where it sends one
    the command    every station value's command name derives from its
                   property and names it back
    the question   asked for a changed value the contest uses, never for
                   one it does not; one Save, one list
    the answers    station only pins a followed value and keeps a stated
                   one; also this contest states the new value
    the correction offered for a value kept as typed, not for a zone or the
                   year (which has its own); the repository's count and write
                   take exactly this station's captured rows, and mark them
                   edited
    Edit QSO       a CHANGED value is checked by the Station page's rule; an
                   unchanged old value is not *)
unit uTestStationFactChange;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TStationFactChangeTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
   protected
      procedure Test_TheContestSaysWhichValuesItUses;
      procedure Test_EveryValueHasACommandThatNamesItBack;
      procedure Test_TheQuestionListsOnlyChangedValuesTheContestUses;
      procedure Test_StationOnlyPinsAFollowedPrecedenceAndKeepsAStatedOne;
      procedure Test_AlsoThisContestStatesTheNewPrecedence;
      procedure Test_ACorrectionIsOfferedOnlyForAValueKeptAsTyped;
      procedure Test_TheCorrectionTakesThisStationsCapturedRowsOnly;
      procedure Test_EditQSOChecksOnlyAChangedValue;
      procedure Test_ThePageShowsTheContestsValueAndAsksWhenItChanges;
      procedure Test_EachContestShowsItsOwnValues;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uCFG,                   (* registers the settings' value checks *)
   uContestBase,
   uContestRegistry,       (* ContestIdentity, ContestHandleOf *)
   uQsoMyFacts,
   uStationFactRecord,
   uStationFactChange,
   uLogDatabase, uLogRepository,
   uTestLatestContest,     (* MakeTestContestLog, ScrubTestLog *)
   uTestLogReceivedYear;   (* MakeRow, QueryText *)

const
   PREC_SQL = 'SELECT group_concat(IFNULL(my_prec, ''N'') || ''/'' || ' +
              'IFNULL(my_source, ''N''), '','') FROM (SELECT my_prec, my_source ' +
              'FROM qso ORDER BY id)';

function TStationFactChangeTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_stationfactchange_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TStationFactChangeTests.Test_TheContestSaysWhichValuesItUses;
var
   ss, fd, naqp, ropoco, foc, cqww: TContestBase;
begin
   BeginTest('a contest uses the station values its New Contest prompts ask for');
   ss := ContestIdentity(ARRLSSCW);
   fd := ContestIdentity(ARRLFIELDDAY);
   naqp := ContestIdentity(NAQSOCW);
   ropoco := ContestIdentity(RSGB_ROPOCO_CW);
   foc := ContestIdentity(FOCMARATHON);
   cqww := ContestIdentity(CQWWCW);

   CheckTrue(ContestUsesStationFact(ss, sfPrec), 'Sweepstakes: precedence');
   CheckTrue(ContestUsesStationFact(ss, sfCheck), 'Sweepstakes: check');
   CheckFalse(ContestUsesStationFact(ss, sfName), 'Sweepstakes: no name');
   CheckTrue(ContestUsesStationFact(fd, sfFdClass), 'Field Day: class');
   CheckFalse(ContestUsesStationFact(fd, sfPrec), 'Field Day: no precedence');
   CheckTrue(ContestUsesStationFact(naqp, sfName), 'NAQP: name');
   CheckTrue(ContestUsesStationFact(ropoco, sfPostalCode), 'RoPoCo: postal code');
   CheckTrue(ContestUsesStationFact(foc, sfFocNumber), 'FOC Marathon: FOC number');
   CheckFalse(ContestUsesStationFact(cqww, sfName), 'CQWW: no name');
   CheckFalse(ContestUsesStationFact(cqww, sfPrec), 'CQWW: no precedence');
   CheckFalse(ContestUsesStationFact(cqww, sfFdClass), 'CQWW: no class');
   CheckFalse(ContestUsesStationFact(nil, sfPrec), 'no contest uses nothing');

   CheckTrue(ContestUsesStationFact(ContestIdentity(EUROPEANHFC), sfLicenseYear),
             'a contest that sends a year uses the license year');
   CheckFalse(ContestUsesStationFact(ss, sfLicenseYear),
              'Sweepstakes sends a check, not the license year');
end;

procedure TStationFactChangeTests.Test_EveryValueHasACommandThatNamesItBack;
var
   s: TR4WSettings;
   fact, back: TStationFact;
begin
   BeginTest('every station value''s command derives from its property and names it back');
   CheckEquals('MY PREC', StationFactCommand(sfPrec), 'precedence');
   CheckEquals('MY FD CLASS', StationFactCommand(sfFdClass), 'FD class');
   CheckEquals('MY FOC NUMBER', StationFactCommand(sfFocNumber), 'FOC number');
   CheckEquals('MY LICENSE YEAR', StationFactCommand(sfLicenseYear), 'license year');
   s := TR4WSettings.Create;
   try
      for fact := Low(TStationFact) to High(TStationFact) do
         begin
         CheckTrue(s.StationFactOfCommand(StationFactCommand(fact), back) and (back = fact),
                   StationFactCommand(fact) + ' names its fact');
         end;
   finally
      s.Free;
   end;
end;

procedure TStationFactChangeTests.Test_TheQuestionListsOnlyChangedValuesTheContestUses;
var
   s: TR4WSettings;
   before: TStationFactsBefore;
   asked: TStationFacts;
begin
   BeginTest('one question lists every changed value the contest uses, and nothing else');
   s := TR4WSettings.Create;
   try
      s.TrySetByCommand('MY PREC', 'B');
      s.TrySetByCommand('MY CHECK', '64');
      s.TrySetByCommand('MY NAME', 'TOM');
      before := TStationFactsBefore.Create(s);
      try
         s.TrySetByCommand('MY PREC', 'A');
         s.TrySetByCommand('MY CHECK', '72');
         s.TrySetByCommand('MY NAME', 'BOB');
         asked := StationFactsToAsk(before, s, ContestIdentity(ARRLSSCW));
         CheckTrue(asked = [sfPrec, sfCheck],
                   'Sweepstakes asks about its precedence and check, not the name');
         asked := StationFactsToAsk(before, s, ContestIdentity(CQWWCW));
         CheckTrue(asked = [], 'CQWW uses none of them: no question');
      finally
         before.Free;
      end;

      before := TStationFactsBefore.Create(s);
      try
         s.TrySetByCommand('MY PREC', ' A ');
         asked := StationFactsToAsk(before, s, ContestIdentity(ARRLSSCW));
         CheckTrue(asked = [], 'blanks around the same value are not a change');
      finally
         before.Free;
      end;
   finally
      s.Free;
   end;
   CheckFalse(StationFactEditAsks(False, 'A', 'B'), 'unused: no question');
   CheckTrue(StationFactEditAsks(True, '', 'B'), 'a first value');
end;

procedure TStationFactChangeTests.Test_StationOnlyPinsAFollowedPrecedenceAndKeepsAStatedOne;
var
   s: TR4WSettings;
   before: string;
begin
   BeginTest('station only: a followed precedence is pinned, a stated one kept');
   s := TR4WSettings.Create;
   try
      s.TrySetByCommand('MY PREC', 'B');
      before := s.My.Resolved(sfPrec);
      s.TrySetByCommand('MY PREC', 'A');
      CheckTrue(ApplyStationFactScope(s, sfPrec, sfsStationOnly, before),
                'a statement to record');
      CheckEquals('B', s.My.Resolved(sfPrec), 'the contest keeps the precedence it followed');
      CheckEquals('A', s.My.Prec, 'the station default moved');

      CheckFalse(ApplyStationFactScope(s, sfPrec, sfsStationOnly, s.My.Resolved(sfPrec)),
                 'a stated value is untouched: nothing to record');
      CheckEquals('B', s.My.Resolved(sfPrec), 'still B');
   finally
      s.Free;
   end;
end;

procedure TStationFactChangeTests.Test_AlsoThisContestStatesTheNewPrecedence;
var
   s: TR4WSettings;
   before: string;
begin
   BeginTest('also this contest: the stated precedence is corrected (the bench finding)');
   s := TR4WSettings.Create;
   try
      s.TrySetByCommand('MY PREC', 'A');
      s.TryOverrideForContest('MY PREC', 'B');   (* stated wrong at New Contest *)
      before := s.My.Resolved(sfPrec);
      CheckEquals('B', before, 'the contest sends its stated B');
      s.TrySetByCommand('MY PREC', 'Q');
      CheckEquals('B', s.My.Resolved(sfPrec), 'a station edit alone cannot reach it');
      CheckTrue(ApplyStationFactScope(s, sfPrec, sfsAlsoContest, before), 'stated anew');
      CheckEquals('Q', s.My.Resolved(sfPrec), 'the contest sends Q now');
      CheckFalse(ApplyStationFactScope(s, sfPrec, sfsAlsoContest, before),
                 'stating the same value again records nothing');
   finally
      s.Free;
   end;
end;

procedure TStationFactChangeTests.Test_ACorrectionIsOfferedOnlyForAValueKeptAsTyped;
var
   c: TStationFactCorrection;
begin
   BeginTest('a correction of logged QSOs is offered for a value kept as typed');
   CheckTrue(StationFactCorrectionOf(sfPrec, 'B', 'A', c), 'precedence');
   CheckEquals('B', string(c.OldText), 'the old text, as the column holds it');
   CheckEquals('A', string(c.NewText), 'the new');
   CheckFalse(StationFactCorrectionOf(sfPrec, 'A', 'A', c), 'nothing changed');
   CheckTrue(StationFactCorrectionOf(sfCheck, '', '07', c), 'a first check: the NULL rows');
   CheckFalse(StationFactCorrectionOf(sfZone, '5', '4', c), 'a zone is kept as scored');
   CheckFalse(StationFactCorrectionOf(sfLicenseYear, '1964', '1990', c),
              'the year has its own correction');
   CheckFalse(StationCorrectionAsks(sfsStationOnly, True, 5), 'only after also this contest');
   CheckFalse(StationCorrectionAsks(sfsAlsoContest, True, 0), 'no QSOs: no question');
   CheckFalse(StationCorrectionAsks(sfsAlsoContest, True, -1), 'an unreadable log: none');
   CheckTrue(StationCorrectionAsks(sfsAlsoContest, True, 3), 'QSOs sent the old value');
   CheckFalse(StationFactFeedsScoring(sfPrec), 'no scoring rule reads the precedence');
   CheckTrue(StationFactFeedsScoring(sfGrid), 'a grid may be scored');
end;

(* One row with a precedence and a source. *)
procedure SaveRow(aRepo: TLogRepository; aSeed: integer; aSource: TQsoMyFactsSource;
                  const aPrec: AnsiString; aNote: boolean = False);
var
   rec: ContestExchange;
   facts: TQsoMyFacts;
begin
   rec := MakeRow(aSeed, 255);
   if aNote then
      begin
      rec.ceRecordKind := rkNote;
      end;
   facts := NotCapturedMyFacts;
   facts.Source := aSource;
   facts.Prec := aPrec;
   aRepo.SetNextMyFacts(facts);
   aRepo.SaveQSO(rec);
end;

procedure TStationFactChangeTests.Test_TheCorrectionTakesThisStationsCapturedRowsOnly;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   raised: boolean;
begin
   BeginTest('the correction takes this station''s captured rows that sent the old value');
   fn := TempLogName('correct.db');
   MakeTestContestLog(fn, ContestHandleOf(ARRLSSCW), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, mfsLogged, 'B');          (* corrected *)
         SaveRow(repo, 2, mfsEdited, 'B');          (* corrected *)
         SaveRow(repo, 3, mfsAssumed, 'B');         (* a peer's: never *)
         SaveRow(repo, 4, mfsImported, 'B');        (* its file's: never *)
         SaveRow(repo, 5, mfsNotCaptured, '');      (* falls back: never *)
         SaveRow(repo, 6, mfsLogged, 'Q');          (* sent another: kept *)
         SaveRow(repo, 7, mfsLogged, '');           (* sent none *)
         repo.Commit;

         CheckEquals(2, repo.CountQSOsSentStationValue('my_prec', 'B'), 'two of ours sent B');
         CheckEquals(1, repo.CountQSOsSentStationValue('my_prec', ''),
                     'one of ours sent none -- the never-captured row is not counted');
         CheckEquals(2, repo.CorrectSentStationValue('my_prec', 'B', 'A'), 'two corrected');
         repo.Commit;
         CheckEquals('A/edited,A/edited,B/assumed,B/imported,N/N,Q/logged,N/logged',
                     QueryText(db, PREC_SQL), 'exactly those, marked edited');

         raised := False;
         try
            repo.CountQSOsSentStationValue('my_source', 'logged');
         except
            on E: Exception do
               begin
               raised := True;
               end;
         end;
         CheckTrue(raised, 'the provenance is not a station value');
         raised := False;
         try
            repo.CorrectSentStationValue('callsign', 'X', 'Y');
         except
            on E: Exception do
               begin
               raised := True;
               end;
         end;
         CheckTrue(raised, 'nor is any other column');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TStationFactChangeTests.Test_EditQSOChecksOnlyAChangedValue;
var
   shown, typed: TQsoMyFacts;
   fact: TStationFact;
   text: string;
begin
   BeginTest('Edit QSO checks a changed station value by the Station page''s rule');
   shown := NotCapturedMyFacts;
   shown.Source := mfsLogged;
   shown.Check := '7';      (* from before the two-digit rule *)
   shown.Prec := 'A';

   typed := shown;
   typed.Grid := 'EL88';
   CheckEquals('', EditedStationFactProblem(shown, typed, fact, text),
               'an old one-digit check does not stop a grid correction');

   typed.Prec := 'X';
   CheckTrue(EditedStationFactProblem(shown, typed, fact, text) <> '',
             'a precedence that is no precedence is refused');
   CheckTrue(fact = sfPrec, 'and named');
   CheckEquals('X', text, 'with its text');
   CheckTrue(EditedStationFactRefusal(shown, typed) <> '', 'the sentence Edit QSO shows');

   typed := shown;
   typed.Check := '07';
   CheckEquals('', EditedStationFactProblem(shown, typed, fact, text), 'a good check');
   typed.CQZone := 41;
   CheckTrue(EditedStationFactProblem(shown, typed, fact, text) <> '', 'zone 41');
   CheckTrue(fact = sfZone, 'named as the CQ zone');
   typed := shown;
   typed.Prec := '';
   CheckEquals('', EditedStationFactProblem(shown, typed, fact, text),
               'emptied is always allowed');
end;

(* NY4I'S BENCH, 2026-11-17: ARRL-SS-SSB stated MY PREC = U and MY CHECK = 80
  at New Contest; an earlier Preferences save had made the station's default
  B with no check. The page showed B and empty, OK changed nothing and asked
  nothing, and the contest's U could not be seen or changed. *)
procedure TStationFactChangeTests.Test_ThePageShowsTheContestsValueAndAsksWhenItChanges;
var
   s: TR4WSettings;
   shown: TStationFactsShown;
   before: TStationFactsBefore;
   asked: TStationFacts;
   oldResolved: string;
begin
   BeginTest('the Station page shows the contest''s value, and changing it asks');
   s := TR4WSettings.Create;
   shown := TStationFactsShown.Create;
   try
      s.TrySetByCommand('MY PREC', 'B');
      s.TryOverrideForContest('MY PREC', 'U');
      s.TryOverrideForContest('MY CHECK', '80');

      CheckEquals('U', shown.Take(s, sfPrec, s.My.StationValue(sfPrec)),
                  'the box shows what the contest sends');
      CheckEquals('80', shown.Take(s, sfCheck, s.My.StationValue(sfCheck)), 'and its check');
      CheckEquals('TOM', shown.Take(s, sfName, 'TOM'),
                  'a value the contest does not state shows the station''s');
      CheckTrue(shown.ShowsContest(sfPrec) and not shown.ShowsContest(sfName),
                'and says which is which');
      CheckTrue(shown.DifferingFromStation(s) = [sfPrec, sfCheck],
                'the note lists the two that differ from the defaults');
      CheckEquals('B', s.My.Prec, 'showing the contest''s value wrote nothing to the station');

      CheckFalse(shown.WritesStation(sfPrec, ' U '),
                 'left as shown, nothing is written -- not U into the station default');
      CheckTrue(shown.WritesStation(sfPrec, 'B'), 'changed, the default is written');
      CheckTrue(shown.WritesStation(sfName, 'TOM'), 'a station-only box writes as before');

      (* He types B over the shown U; the station's default already is B, so
         it does not move -- and the question must still be asked. *)
      before := TStationFactsBefore.Create(s);
      try
         oldResolved := before.Resolved(sfPrec);
         asked := StationFactsToAskOnPage(before, s, ContestIdentity(ARRLSSSSB), [sfPrec]);
         CheckTrue(sfPrec in asked, 'the changed contest value is asked about');
         CheckFalse(sfCheck in asked, 'the untouched check is not');

         CheckFalse(ApplyStationFactScope(s, sfPrec, sfsStationOnly, oldResolved),
                    'station default only: the contest''s statement stands');
         CheckEquals('U', shown.Take(s, sfPrec, 'B'),
                     'and the box goes back to the contest''s U');
         CheckTrue(ApplyStationFactScope(s, sfPrec, sfsAlsoContest, oldResolved),
                   'also this contest: stated anew');
         CheckEquals('B', s.My.Resolved(sfPrec), 'the contest sends B');
         CheckEquals('B', shown.Take(s, sfPrec, 'B'), 'and the box shows B');
         CheckTrue(shown.DifferingFromStation(s) = [sfCheck], 'only the check still differs');
      finally
         before.Free;
      end;
   finally
      shown.Free;
      s.Free;
   end;
end;

(* EVERY CONTEST SHOWS ITS OWN (NY4I, 2026-11-17: "after the initial New
  Contest screen we should still set the values in the contest section of
  Station to the values we entered"). A contest's statements arrive through
  TryOverrideForContest (the New Contest queue, the log's own rows on
  reopen); opening another contest clears them (ClearContestOverrides). The
  station's default never moves. *)
procedure TStationFactChangeTests.Test_EachContestShowsItsOwnValues;
var
   s: TR4WSettings;
   shown: TStationFactsShown;

   procedure OpenContestA;
   begin
      s.My.ClearContestOverrides;
      s.TryOverrideForContest('MY PREC', 'U');
      s.TryOverrideForContest('MY CHECK', '80');
   end;

begin
   BeginTest('each contest shows its own stated values; the station default stays');
   s := TR4WSettings.Create;
   shown := TStationFactsShown.Create;
   try
      s.TrySetByCommand('MY PREC', 'B');

      OpenContestA;
      CheckEquals('U', shown.Take(s, sfPrec, s.My.StationValue(sfPrec)), 'contest A: U');
      CheckEquals('80', shown.Take(s, sfCheck, s.My.StationValue(sfCheck)), 'contest A: 80');

      s.My.ClearContestOverrides;   (* contest B states nothing *)
      CheckEquals('B', shown.Take(s, sfPrec, s.My.StationValue(sfPrec)),
                  'contest B: the station default');
      CheckEquals('', shown.Take(s, sfCheck, s.My.StationValue(sfCheck)),
                  'contest B: no check, as the station has none');
      CheckTrue(shown.DifferingFromStation(s) = [], 'no note');

      OpenContestA;
      CheckEquals('U', shown.Take(s, sfPrec, s.My.StationValue(sfPrec)), 'back to A: U');
      CheckEquals('80', shown.Take(s, sfCheck, s.My.StationValue(sfCheck)), 'back to A: 80');
      CheckEquals('B', s.My.Prec, 'the station default never moved');
      CheckEquals('', s.My.Check, 'nor its check');
   finally
      shown.Free;
      s.Free;
   end;
end;

procedure TStationFactChangeTests.RunAllTests;
begin
   Test_ThePageShowsTheContestsValueAndAsksWhenItChanges;
   Test_EachContestShowsItsOwnValues;
   Test_TheContestSaysWhichValuesItUses;
   Test_EveryValueHasACommandThatNamesItBack;
   Test_TheQuestionListsOnlyChangedValuesTheContestUses;
   Test_StationOnlyPinsAFollowedPrecedenceAndKeepsAStatedOne;
   Test_AlsoThisContestStatesTheNewPrecedence;
   Test_ACorrectionIsOfferedOnlyForAValueKeptAsTyped;
   Test_TheCorrectionTakesThisStationsCapturedRowsOnly;
   Test_EditQSOChecksOnlyAChangedValue;

   if (FDir <> '') and RemoveDir(FDir) then
      begin
      FDir := '';
      end;
end;

end.
