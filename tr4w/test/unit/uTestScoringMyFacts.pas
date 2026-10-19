unit uTestScoringMyFacts;

(* A LOGGED QSO IS SCORED BY ITS OWN RECORDED STATION -- log schema 3, stage 3.

  D1: about a dozen distance contests read Station.MyGrid, and a rescore used
  to hand them TODAY'S grid, so a rover's log, or one whose grid was corrected
  mid-contest, was rescored as though every QSO were worked from where the
  station is now. TContestBase.ScoreQSO(aQso, aMyFacts) lays the row's grid
  over the station for that one call. These pin:

    - a two-grid rover log scores each row from its own grid;
    - a row never captured scores as it always did, from the session (A);
    - a captured row with no grid has no distance, whatever the session's;
    - the session's grid is back after the call, an exception included;
    - live entry (the one-argument ScoreQSO) is unchanged;
    - the logged-QSO view hands a whole-log rule each QSO's own station.

  ARRL Digi is the contest used: its rule is the plainest distance rule in
  the factory -- Ceil(km / 500) + 1, 2 for the same grid, 0 with no grid --
  and the expected values are computed by the same LOGGRID function it
  calls, so nothing here restates its arithmetic by hand. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   VC, uTR4WTestFramework, uContestBase, uQsoMyFacts;

type
   TScoringMyFactsTests = class(TTestCase)
   private
      procedure MakeQSO(out aQso: ContestExchange; const aWorkedGrid: string);
      function Facts(const aGrid: AnsiString): TQsoMyFacts;
      function ARRLDigiPoints(const aMyGrid, aWorkedGrid: string): integer;
      function StationWithGrid(const aGrid: string): TStationContext;
   protected
      procedure TestARoverIsScoredFromEachRowsOwnGrid;
      procedure TestANeverCapturedRowIsScoredAsToday;
      procedure TestACapturedRowWithNoGridHasNoDistance;
      procedure TestLiveEntryIsUnchanged;
      procedure TestTheSessionGridIsBackAfterAnException;
      procedure TestTheViewHandsEachQSOsOwnStation;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Math, LOGGRID, uContestRegistry, uTestContestObjects;

const
   SESSION_GRID = 'FN31';
   WORKED_GRID = 'DM79';

type
   (* A RULE THAT RAISES, and says what it saw first: the grid and the facts
     ScoreQSO had laid over the station when the rule ran. *)
   TRaisingContest = class(TContestBase)
   public
      SeenGrid: string;
      SeenSource: TQsoMyFactsSource;
   protected
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

   EScoringTest = class(Exception);

procedure TRaisingContest.CalculateQSOPoints(var aQso: ContestExchange);
begin
   SeenGrid := Station.MyGrid;
   SeenSource := ScoringMyFacts.Source;
   raise EScoringTest.Create('the rule failed part-way');
end;

procedure TScoringMyFactsTests.MakeQSO(out aQso: ContestExchange;
                                       const aWorkedGrid: string);
begin
   aQso := Default(ContestExchange);
   aQso.ceRecordKind := rkQSO;
   aQso.ceContest := ContestHandleOf(ARRLDIGI);
   aQso.Callsign := 'W1AW';
   aQso.Band := Band20;
   aQso.Mode := Digital;
   aQso.QTHString := aWorkedGrid;
   aQso.DomesticQTH := aWorkedGrid;
end;

function TScoringMyFactsTests.Facts(const aGrid: AnsiString): TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := mfsLogged;
   Result.Grid := aGrid;
end;

(* ARRL Digi's own rule, from the same distance function it calls. *)
function TScoringMyFactsTests.ARRLDigiPoints(const aMyGrid, aWorkedGrid: string): integer;
begin
   if (aMyGrid = '') or (aWorkedGrid = '') then
      begin
      Result := 0;
      end
   else if aMyGrid = aWorkedGrid then
      begin
      Result := 2;
      end
   else
      begin
      Result := Ceil(GetDistanceBetweenGrids(aMyGrid, aWorkedGrid) / 500) + 1;
      end;
end;

function TScoringMyFactsTests.StationWithGrid(const aGrid: string): TStationContext;
begin
   Result := NoStation;
   Result.MyGrid := aGrid;
end;

procedure TScoringMyFactsTests.TestARoverIsScoredFromEachRowsOwnGrid;
var
   contest: TContestBase;
   qso: ContestExchange;
   east, west: integer;
begin
   BeginTest('a rover''s QSOs are each scored from the grid that row recorded');
   contest := Make(ARRLDIGI, StationWithGrid(SESSION_GRID));
   try
      MakeQSO(qso, WORKED_GRID);
      contest.ScoreQSO(qso, Facts('FN31'));
      east := qso.QSOPoints;
      MakeQSO(qso, WORKED_GRID);
      contest.ScoreQSO(qso, Facts('DM79'));
      west := qso.QSOPoints;

      CheckEquals(ARRLDigiPoints('FN31', WORKED_GRID), east, 'the QSO worked from FN31');
      CheckEquals(ARRLDigiPoints('DM79', WORKED_GRID), west,
                  'the QSO worked from DM79 -- the same grid as the station worked: 2');
      CheckTrue(east <> west, 'two grids, two scores -- not the session''s twice');
      (* AND THE SESSION'S GRID IS BACK: a live QSO scores from it again. *)
      MakeQSO(qso, WORKED_GRID);
      contest.ScoreQSO(qso);
      CheckEquals(ARRLDigiPoints(SESSION_GRID, WORKED_GRID), qso.QSOPoints,
                  'and a live QSO after them scores from the session''s grid again');
   finally
      contest.Free;
   end;
end;

(* RULING A: a row that recorded no station is scored as it always was. *)
procedure TScoringMyFactsTests.TestANeverCapturedRowIsScoredAsToday;
var
   contest: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('a QSO that recorded no station is scored by the session''s grid, as before');
   contest := Make(ARRLDIGI, StationWithGrid(SESSION_GRID));
   try
      MakeQSO(qso, WORKED_GRID);
      contest.ScoreQSO(qso, NotCapturedMyFacts);
      CheckEquals(ARRLDigiPoints(SESSION_GRID, WORKED_GRID), qso.QSOPoints,
                  'the session''s grid -- the fallback');
   finally
      contest.Free;
   end;
end;

(* '' UNDER A CAPTURED SOURCE IS UNKNOWN, AND IS NOT BORROWED FROM THE SESSION.
  ARRL Digi then scores no distance, 0 (Q116). Not every rule answers 0 for an
  unknown grid -- see the stage-3 hand-back -- which Q116's build settles. *)
procedure TScoringMyFactsTests.TestACapturedRowWithNoGridHasNoDistance;
var
   contest: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('a QSO that recorded an unknown grid is not scored from the session''s');
   contest := Make(ARRLDIGI, StationWithGrid(SESSION_GRID));
   try
      MakeQSO(qso, WORKED_GRID);
      contest.ScoreQSO(qso, Facts(''));
      CheckEquals(0, qso.QSOPoints, 'no grid of ours, no distance');
      MakeQSO(qso, WORKED_GRID);
      contest.ScoreQSO(qso);
      CheckEquals(ARRLDigiPoints(SESSION_GRID, WORKED_GRID), qso.QSOPoints,
                  'and the session''s grid is back for the next live QSO');
   finally
      contest.Free;
   end;
end;

procedure TScoringMyFactsTests.TestLiveEntryIsUnchanged;
var
   contest: TContestBase;
   qso, live: ContestExchange;
begin
   BeginTest('live entry -- the one-argument ScoreQSO -- scores by the session''s grid');
   contest := Make(ARRLDIGI, StationWithGrid(SESSION_GRID));
   try
      MakeQSO(live, WORKED_GRID);
      contest.ScoreQSO(live);
      MakeQSO(qso, WORKED_GRID);
      contest.ScoreQSO(qso, NotCapturedMyFacts);
      CheckEquals(ARRLDigiPoints(SESSION_GRID, WORKED_GRID), live.QSOPoints,
                  'the station''s own grid');
      CheckEquals(qso.QSOPoints, live.QSOPoints,
                  'and exactly what a never-captured row scores');
   finally
      contest.Free;
   end;
end;

procedure TScoringMyFactsTests.TestTheSessionGridIsBackAfterAnException;
var
   contest: TRaisingContest;
   qso: ContestExchange;
   raised: boolean;
begin
   BeginTest('a rule that raises leaves the session''s grid and no scoring facts behind');
   contest := TRaisingContest.Create(ContestHandleOf(ARRLDIGI));
   try
      contest.SetStation(StationWithGrid(SESSION_GRID));
      MakeQSO(qso, WORKED_GRID);
      raised := False;
      try
         contest.ScoreQSO(qso, Facts('JO65'));
      except
         on EScoringTest do
            begin
            raised := True;
            end;
      end;
      CheckTrue(raised, 'the rule''s exception reached the caller');
      CheckEquals('JO65', contest.SeenGrid, 'the rule ran with the row''s grid');
      CheckEquals(Ord(mfsLogged), Ord(contest.SeenSource), 'and saw the row''s facts');
      CheckEquals(SESSION_GRID, contest.Station.MyGrid,
                  'the session''s grid is back after the exception');
      CheckEquals(Ord(mfsNotCaptured), Ord(contest.ScoringMyFacts.Source),
                  'and no row''s facts are left behind');
   finally
      contest.Free;
   end;
end;

(* WHAT A WHOLE-LOG RULE (Idaho's bonus, the Nebraska rare-grid bonus next)
  reads: each QSO's own station, beside the QSO. *)
procedure TScoringMyFactsTests.TestTheViewHandsEachQSOsOwnStation;
var
   list: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('the logged-QSO view hands a whole-log rule each QSO''s own station');
   list := TLoggedQSOList.Create;
   try
      MakeQSO(qso, WORKED_GRID);
      list.Add(qso, Facts('EN01'));
      list.Add(qso);
      list.Add(qso, Facts('EN02'));
      CheckEquals(3, list.Count, 'three QSOs');
      CheckEquals('EN01', string(list.MyFacts(0).Grid), 'the first QSO''s grid');
      CheckEquals(Ord(mfsNotCaptured), Ord(list.MyFacts(1).Source),
                  'a QSO added with no station recorded none');
      CheckEquals('EN02', string(list.MyFacts(2).Grid), 'the third QSO''s grid');
      list.Clear;
      list.Add(qso, Facts('EN03'));
      CheckEquals('EN03', string(list.MyFacts(0).Grid),
                  'a reused list keeps each QSO''s own, not the last fill''s');
   finally
      list.Free;
   end;
end;

procedure TScoringMyFactsTests.RunAllTests;
begin
   TestARoverIsScoredFromEachRowsOwnGrid;
   TestANeverCapturedRowIsScoredAsToday;
   TestACapturedRowWithNoGridHasNoDistance;
   TestLiveEntryIsUnchanged;
   TestTheSessionGridIsBackAfterAnException;
   TestTheViewHandsEachQSOsOwnStation;
end;

end.
