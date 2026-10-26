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

(* EACH CONTEST OWNS ITS FINAL SCORE AND ITS BONUSES -- milestone M6,
  2026-10-02 (docs/CONTEST_OWNERSHIP_DESIGN.md 5, 7.7).

  The application hands a contest a TScoreTotals and a read-only view of the
  log; these tests hand it HAND-BUILT ones, so what is pinned is the
  contest's own arithmetic and nothing the engine does to fill them. The
  engine's filling is the contest matrix's to pin (its totals section, frozen
  before anything moved), and the corpus's CLAIMED-SCORE for its thirteen
  logs.

    * THE BASE: points times the sum of the multipliers, on the scored band;
      the points alone for a session with no multiplier -- a template no
      contest can skip (FISTS's points alone are its own formula since M11
      S7); a bonus only from declared stations.
    * THE FORMULAS THAT MOVED out of LogEdit.TotalScore, each with numbers
      that tell it apart from the general case.
    * EVERY BONUS AT ITS EDGES: Missouri's stations and capped tally, North
      Carolina's sweep (four counties against five), the Salmon Run's W7DX
      (one mode against two, and a single-mode entry), Idaho's dormant county
      (nine QSOs against ten).
    * THE NEW CLASSES' PER-QSO RULES, spot-checked against the arms they
      transcribe; the contest matrix holds them exactly. *)
unit uTestContestTotals;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestTotalsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_BaseIsPointsTimesMultipliers;
      procedure Test_NoMultipliersScoresThePoints;
      procedure Test_FieldDayFormulas;
      procedure Test_WAEWeightsItsMultipliers;
      procedure Test_RussianCupsAddPerMultiplier;
      procedure Test_UralCupPaysPrefixesAsPoints;
      procedure Test_RSGB18ScoresItsPointsAlone;
      procedure Test_FinalScoreIsFormulaPlusBonus;
      procedure Test_MissouriBonusStations;
      procedure Test_MissouriPeakHourBonus;
      procedure Test_NCSweepNeedsFiveRareCounties;
      procedure Test_SalmonRunW7DXOncePerMode;
      procedure Test_SalmonRunSingleModeEntry;
      procedure Test_BonusStationScopes;
      procedure Test_IdahoDormantCountyNeedsTenQSOs;
      procedure Test_LogContestYearReadsTheLog;
      procedure Test_IdahoPaysTheTableOfTheLogsYear;
      procedure Test_IdahoYearWithNoTablePaysNothingAndSaysSo;
      procedure Test_IdahoStartTimeOutranksTheFirstQSO;
      procedure Test_IdahoHasATableForTheCurrentYear;
      procedure Test_QSOCountsTowardTotals;
      procedure Test_SummarySheetCountsWhatTheTotalsCount;
      procedure Test_RescoredXQSOKeepsNoScoring;
      procedure Test_ApplicationViewIsTheLoadersSet;
      procedure Test_NewClassesScoreTheirArms;
      procedure Test_OnlyBonusContestsDeclareStations;
   end;

implementation

uses
   SysUtils, VC, uSettingsModel, uContestBase, uContestRegistry,
   (* The application's view, kept beside the totals. *)
   uScoreTotals,
   (* Make and NoStation -- lifted there at M8, the third copy being due. *)
   uTestContestObjects,
   (* TallySummaryTotals and the summary sheet's counts -- Q51. *)
   PostUnit,
   (* Q35: Idaho's per-year table, and proof its "no table" report is
      written. *)
   uContestIdahoQP,
   Log4D,
   uTestLogCapture;

(* ---------------------------------------------------------------------------
   HAND-BUILT INPUTS
   --------------------------------------------------------------------------- *)

(* Totals with the session counting multipliers, all bands scored, and the
   given points; every count zero. *)
function Totals(aPoints: longint): TScoreTotals;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.QSOPoints := aPoints;
   Result.ScoredBand := AllBands;
   Result.SessionCountsMultipliers := True;
end;


(* A logged QSO: a QSO record, as the log's loader would count it. *)
function LoggedQSO(const aCall: string; aBand: BandType; aMode: ModeType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := ShortString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
end;

function WithCounty(const aQso: ContestExchange; const aCounty: string): ContestExchange;
begin
   Result := aQso;
   Result.DomesticQTH := ShortString(aCounty);
end;

function AsDupe(const aQso: ContestExchange): ContestExchange;
begin
   Result := aQso;
   Result.ceDupe := True;
end;

(* aQso logged on 14 March of aYear (the Idaho QSO Party's second full
   weekend in 2026), 12:00 UTC. qtYear is the year minus 2000. *)
function OnDay(const aQso: ContestExchange; aYear, aMonth, aDay: integer): ContestExchange;
begin
   Result := aQso;
   Result.tSysTime.qtYear := aYear - 2000;
   Result.tSysTime.qtMonth := aMonth;
   Result.tSysTime.qtDay := aDay;
   Result.tSysTime.qtHour := 12;
end;

function InYear(const aQso: ContestExchange; aYear: integer): ContestExchange;
begin
   Result := OnDay(aQso, aYear, 3, 14);
end;

(* A view of aCount valid Idaho QSOs (20 m CW, distinct calls), all in
   aYear. *)
procedure AddIdahoQSOs(aView: TLoggedQSOList; aCount, aYear: integer);
var
   i: integer;
begin
   for i := 1 to aCount do
      begin
      aView.Add(InYear(LoggedQSO('K' + IntToStr(i mod 10) + 'A' + IntToStr(i), Band20, CW), aYear));
      end;
end;

(* An in-state Idaho entrant in aCounty. *)
function IdahoEntrant(const aCounty: string): TStationContext;
begin
   Result := NoStation;
   Result.InHostState := True;
   Result.MyState := aCounty;
end;

(* Idaho's bonus over aView with aTotals (so a test can state the log's
   start time). *)
function IdahoBonus(const aStation: TStationContext; const aTotals: TScoreTotals;
                    aView: TLoggedQSOView): longint;
var
   contestObject: TContestBase;
begin
   contestObject := Make(IDAHOQSOPARTY, aStation);
   try
      Result := contestObject.BonusPoints(aTotals, aView);
   finally
      contestObject.Free;
   end;
end;

(* The final score of aContest over aView, with aTotals. *)
function Final(aContest: ContestType; const aStation: TStationContext;
               const aTotals: TScoreTotals; aView: TLoggedQSOView): longint;
var
   contestObject: TContestBase;
begin
   contestObject := Make(aContest, aStation);
   try
      Result := contestObject.FinalScore(aTotals, aView);
   finally
      contestObject.Free;
   end;
end;

function Bonus(aContest: ContestType; const aStation: TStationContext;
               aView: TLoggedQSOView): longint;
var
   contestObject: TContestBase;
begin
   contestObject := Make(aContest, aStation);
   try
      Result := contestObject.BonusPoints(Totals(0), aView);
   finally
      contestObject.Free;
   end;
end;

function Combine(aContest: ContestType; const aStation: TStationContext;
                 const aTotals: TScoreTotals): longint;
var
   contestObject: TContestBase;
begin
   contestObject := Make(aContest, aStation);
   try
      Result := contestObject.CombineScore(aTotals);
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE BASE
   --------------------------------------------------------------------------- *)

procedure TContestTotalsTests.Test_BaseIsPointsTimesMultipliers;
var
   t: TScoreTotals;
begin
   BeginTest('Test_BaseIsPointsTimesMultipliers');

   (* CQ WW has a class with no formula of its own, so it is the base's. *)
   t := Totals(10);
   t.QTCPoints := 2;
   t.Mults[AllBands, Both, rmDomestic] := 3;
   t.Mults[AllBands, Both, rmDX] := 2;
   t.Mults[AllBands, Both, rmZone] := 4;
   t.Mults[AllBands, Both, rmPrefix] := 1;
   CheckEquals(12 * 10, Combine(CQWWCW, NoStation, t),
               'points (QTCs included) times every kind of multiplier, all bands');

   (* A SINGLE-BAND ENTRY counts its band's multipliers, not the all-band
      row. *)
   t.ScoredBand := Band20;
   t.Mults[Band20, Both, rmDX] := 5;
   CheckEquals(12 * 5, Combine(CQWWCW, NoStation, t), 'a single-band entry counts its band');

   (* A CLASSLESS CONTEST, through the plain base. *)
   t := Totals(7);
   t.Mults[AllBands, Both, rmDX] := 3;
   CheckEquals(21, Combine(DUMMYCONTEST, NoStation, t), 'the plain base, classless');
end;

procedure TContestTotalsTests.Test_NoMultipliersScoresThePoints;
var
   t: TScoreTotals;
   station: TStationContext;
begin
   BeginTest('Test_NoMultipliersScoresThePoints');

   t := Totals(10);
   t.QTCPoints := 1;
   t.Mults[AllBands, Both, rmDX] := 9;
   t.QSOs[Band20, CW] := 1;
   t.SessionCountsMultipliers := False;
   CheckEquals(11, Combine(CQWWCW, NoStation, t), 'a session with no multiplier scores its points');

   (* THE TEMPLATE RUNS FIRST, FOR EVERY CONTEST: Winter Field Day's own
      formula would multiply, and the session says there are no multipliers. *)
   station := NoStation;
   station.MyPower := cpQRP;
   CheckEquals(11, Combine(WINTERFIELDDAY, station, t), 'no contest skips the template');

   (* FISTS SCORES ITS POINTS ALONE -- its own CombineWithMultipliers since
      M11 S7; CombineScore tested the session's FISTS exchange shape. *)
   t.SessionCountsMultipliers := True;
   CheckEquals(11, Combine(FISTS, NoStation, t), 'FISTS scores its points');
end;

(* ---------------------------------------------------------------------------
   THE FORMULAS THAT MOVED
   --------------------------------------------------------------------------- *)

procedure TContestTotalsTests.Test_FieldDayFormulas;
var
   t: TScoreTotals;
   station: TStationContext;
begin
   BeginTest('Test_FieldDayFormulas');

   t := Totals(10);
   t.Mults[AllBands, Both, rmDomestic] := 7;
   CheckEquals(10, Combine(ARRLFIELDDAY, NoStation, t), 'ARRL Field Day: the points alone');

   (* WINTER FIELD DAY: one multiplier per band and mode with a QSO -- 20 m CW
      and phone, 40 m digital, 2 m phone: four. The sheet's multipliers do not
      enter it. *)
   t.QSOs[Band20, CW] := 3;
   t.QSOs[Band20, Phone] := 1;
   t.QSOs[Band40, Digital] := 2;
   t.QSOs[Band2, Phone] := 1;
   t.QSOs[AllBands, Both] := 7;
   station := NoStation;
   station.MyPower := cpHIGH;
   CheckEquals(40, Combine(WINTERFIELDDAY, station, t), 'Winter Field Day, high power');
   station.MyPower := cpLOW;
   CheckEquals(80, Combine(WINTERFIELDDAY, station, t), 'Winter Field Day, low power doubles');
   station.MyPower := cpQRP;
   CheckEquals(200, Combine(WINTERFIELDDAY, station, t), 'Winter Field Day, QRP five times');
end;

procedure TContestTotalsTests.Test_WAEWeightsItsMultipliers;
var
   t: TScoreTotals;
   european: TStationContext;
   elsewhere: TStationContext;
begin
   BeginTest('Test_WAEWeightsItsMultipliers');

   (* THE ENTRANT DECIDES WHICH MULTIPLIER IS WEIGHTED -- M11 S4. Until then
      the class read the session's DX kind (SessionDXMult =
      CQEuropeanCountries, which DescribeSession stated for an entrant
      outside Europe); it asks its station now. The kind, and the totals'
      field that carried it, went at M11 S4 part 2. *)
   european := NoStation;
   european.MyContinent := Europe;
   elsewhere := NoStation;
   elsewhere.MyContinent := NorthAmerica;

   t := Totals(10);
   t.Mults[Band80, Both, rmPrefix] := 1;
   t.Mults[Band40, Both, rmPrefix] := 1;
   t.Mults[Band20, Both, rmPrefix] := 1;
   t.Mults[Band15, Both, rmPrefix] := 1;
   t.Mults[Band10, Both, rmPrefix] := 1;
   t.Mults[AllBands, Both, rmPrefix] := 5;
   t.Mults[Band80, Both, rmDX] := 2;
   t.Mults[AllBands, Both, rmDX] := 2;
   (* A EUROPEAN ENTRANT: 4 + 3 + 2 + 2 + 2 = 13 prefixes' worth. *)
   CheckEquals(130, Combine(DARCWAEDCCW, european, t), 'WAE prefixes, weighted by band');
   CheckEquals(130, Combine(DARCWAEDCSSB, european, t), 'the SSB running, the same');

   (* AN ENTRANT OUTSIDE EUROPE counts European countries. *)
   CheckEquals(10 * 8, Combine(DARCWAEDCCW, elsewhere, t), 'European countries, four on 80 m');
   CheckEquals(10 * 8, Combine(DARCWAEDCSSB, elsewhere, t), 'the SSB running, the same');

   (* A single-band entry: the general case on its band. *)
   t.ScoredBand := Band80;
   CheckEquals(10 * 3, Combine(DARCWAEDCCW, elsewhere, t), 'a single-band entry is not weighted');
end;

procedure TContestTotalsTests.Test_RussianCupsAddPerMultiplier;
var
   t: TScoreTotals;
begin
   BeginTest('Test_RussianCupsAddPerMultiplier');

   t := Totals(10);
   t.QTCPoints := 1;
   t.Mults[AllBands, Both, rmDomestic] := 2;
   t.Mults[AllBands, Both, rmDX] := 1;
   CheckEquals(11 + 100 * 3, Combine(CUPRFCW, NoStation, t), 'RF Cup CW: + 100 a multiplier');
   CheckEquals(11 + 100 * 3, Combine(CUPRFSSB, NoStation, t), 'RF Cup SSB');
   CheckEquals(11 + 100 * 3, Combine(CUPRFDIG, NoStation, t), 'RF Cup digital');
   CheckEquals(11 + 300 * 3, Combine(ALRS_UA1DZ_CUP, NoStation, t), 'ALRS UA1DZ Cup: + 300');
   CheckEquals(11 + 50 * 3, Combine(RFCHAMPIONSHIPCW, NoStation, t), 'RF Championship CW: + 50');
   CheckEquals(11 + 50 * 3, Combine(RFCHAMPIONSHIPSSB, NoStation, t), 'RF Championship SSB');
   CheckEquals(11 + 10 * 3, Combine(UKRAINECHAMPIONSHIP, NoStation, t), 'Ukraine Championship: + 10');
   CheckEquals(11 + 1000 * 3, Combine(OZHCRVHF, NoStation, t), 'OZHCR VHF: + 1000');
end;

(* RSGB 1.8 MHz's "POINTS TIMES ONE" -- LOGEDIT.TotalScore's arm until
   2026-10-14, its class's formula since (design Q33). The 7 a new
   multiplier earns is already in the points, so the final score is the
   points and the QTCs, whatever the sheet counts and whichever band a
   single-band entry scores. *)
procedure TContestTotalsTests.Test_RSGB18ScoresItsPointsAlone;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
begin
   BeginTest('Test_RSGB18ScoresItsPointsAlone');

   t := Totals(41);
   t.QTCPoints := 2;
   t.Mults[AllBands, Both, rmDomestic] := 5;
   t.Mults[AllBands, Both, rmDX] := 7;
   CheckEquals(43, Combine(RSGB18, NoStation, t), 'the points and QTCs, not times the multipliers');

   t.ScoredBand := Band160;
   t.Mults[Band160, Both, rmDX] := 3;
   CheckEquals(43, Combine(RSGB18, NoStation, t), 'a single-band entry: the points too');

   t := Totals(41);
   t.Mults[AllBands, Both, rmDX] := 7;
   t.SessionCountsMultipliers := False;
   CheckEquals(41, Combine(RSGB18, NoStation, t), 'a session counting no multiplier: the points');

   (* THE FINAL SCORE ADDS NO BONUS -- it declares no bonus station. *)
   view := TLoggedQSOList.Create;
   try
      view.Add(LoggedQSO('G3ABC', Band160, CW));
      t := Totals(41);
      t.Mults[AllBands, Both, rmDX] := 7;
      CheckEquals(41, Final(RSGB18, NoStation, t, view), 'the final score is the points');
   finally
      view.Free;
   end;
end;

procedure TContestTotalsTests.Test_UralCupPaysPrefixesAsPoints;
var
   t: TScoreTotals;
begin
   BeginTest('Test_UralCupPaysPrefixesAsPoints');

   t := Totals(10);
   t.Mults[AllBands, Both, rmDomestic] := 3;
   t.Mults[AllBands, Both, rmPrefix] := 4;
   (* (3 + 4 - 4) x 10, then 10 x 4 prefixes. *)
   CheckEquals(30 + 40, Combine(CUPURAL, NoStation, t), 'prefixes are points, not multipliers');

   (* A SINGLE-BAND ENTRY keeps its band's prefixes in the sum, and the ten
      per prefix is always the all-band count -- as TotalScore did. *)
   t.ScoredBand := Band20;
   t.Mults[Band20, Both, rmDomestic] := 1;
   t.Mults[Band20, Both, rmPrefix] := 2;
   CheckEquals(30 + 40, Combine(CUPURAL, NoStation, t), 'a single-band entry');
end;

(* ---------------------------------------------------------------------------
   THE BONUSES
   --------------------------------------------------------------------------- *)

procedure TContestTotalsTests.Test_FinalScoreIsFormulaPlusBonus;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
begin
   BeginTest('Test_FinalScoreIsFormulaPlusBonus');

   view := TLoggedQSOList.Create;
   try
      view.Add(LoggedQSO('W0MA', Band20, CW));
      t := Totals(10);
      t.Mults[AllBands, Both, rmDomestic] := 3;
      (* AFTER the multiplication, never inside it. *)
      CheckEquals(30 + 100, Final(MOQSOPARTY, NoStation, t, view), 'Missouri: 10 x 3, then + 100');

      (* A contest with no bonus adds nothing, whatever the view holds. *)
      CheckEquals(30, Final(CQWWCW, NoStation, t, view), 'no bonus station, no bonus');
   finally
      view.Free;
   end;
end;

procedure TContestTotalsTests.Test_MissouriBonusStations;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_MissouriBonusStations');

   view := TLoggedQSOList.Create;
   try
      CheckEquals(0, Bonus(MOQSOPARTY, NoStation, view), 'an empty log');

      view.Add(LoggedQSO('K0AAA', Band20, CW));
      CheckEquals(0, Bonus(MOQSOPARTY, NoStation, view), 'no bonus station worked');

      view.Add(LoggedQSO('W0MA', Band40, Phone));
      CheckEquals(100, Bonus(MOQSOPARTY, NoStation, view), 'W0MA: 100');

      (* ONCE, whatever the band or mode. *)
      view.Add(LoggedQSO('W0MA', Band20, CW));
      view.Add(LoggedQSO('W0MA', Band80, Digital));
      CheckEquals(100, Bonus(MOQSOPARTY, NoStation, view), 'W0MA is paid once');

      (* A DUPE COUNTS, as the log's loader counted it. *)
      view.Add(AsDupe(LoggedQSO('K0GQ', Band20, CW)));
      CheckEquals(200, Bonus(MOQSOPARTY, NoStation, view), 'K0GQ, as a dupe, still pays');

      (* EXACT CALLS: a portable is another call. *)
      FreeAndNil(view);
      view := TLoggedQSOList.Create;
      view.Add(LoggedQSO('W0MA/P', Band20, CW));
      CheckEquals(0, Bonus(MOQSOPARTY, NoStation, view), 'W0MA/P is not W0MA');
   finally
      view.Free;
   end;
end;

(* Q32 (NY4I, 2026-10-15; built 2026-10-17): MISSOURI'S PEAK-HOUR BONUS IS
   COUNTED OVER THE WHOLE LOG, from each QSO's OWN logged time and band -- one
   point per valid 80 or 40 m contact logged 1400 to 1959 UTC, on either day,
   up to 250. It replaced a live-entry-only tally (TalliesLiveQSO, deleted)
   that a reopened log lost, so the same view always scores the same bonus:
   there is no session state left for it to depend on. *)
procedure TContestTotalsTests.Test_MissouriPeakHourBonus;
var
   view: TLoggedQSOList;
   inState: TStationContext;
   outOfState: TStationContext;
   t: TScoreTotals;
   i: integer;

   function At(const aCall: string; aBand: BandType; aMode: ModeType;
               aDay, aHour, aMinute: byte): ContestExchange;
   begin
      Result := LoggedQSO(aCall, aBand, aMode);
      Result.tSysTime.qtYear := 26;
      Result.tSysTime.qtMonth := 4;
      Result.tSysTime.qtDay := aDay;
      Result.tSysTime.qtHour := aHour;
      Result.tSysTime.qtMinute := aMinute;
      Result.QTHString := 'StL';
      Result.DomesticQTH := 'StL';
   end;

   function OneQSO(const aStation: TStationContext; const aQso: ContestExchange): longint;
   begin
      FreeAndNil(view);
      view := TLoggedQSOList.Create;
      view.Add(aQso);
      Result := Bonus(MOQSOPARTY, aStation, view);
   end;

begin
   BeginTest('Test_MissouriPeakHourBonus');

   inState := NoStation;
   inState.InHostState := True;
   inState.MyState := 'StL';
   outOfState := NoStation;
   outOfState.MyState := 'KS';

   view := TLoggedQSOList.Create;
   try
      (* THE WINDOW'S EDGES, FROM THE LOGGED TIME. *)
      CheckEquals(1, OneQSO(inState, At('K0ABC', Band80, CW, 4, 14, 0)), '80 m at 1400 counts');
      CheckEquals(1, OneQSO(inState, At('K0ABC', Band40, CW, 4, 19, 59)), '40 m at 1959 counts');
      CheckEquals(0, OneQSO(inState, At('K0ABC', Band40, CW, 4, 13, 59)), '40 m at 1359 does not');
      CheckEquals(0, OneQSO(inState, At('K0ABC', Band80, CW, 4, 20, 0)), '80 m at 2000 does not');
      CheckEquals(0, OneQSO(inState, At('K0ABC', Band20, CW, 4, 15, 0)), '20 m at 1500 does not');
      CheckEquals(0, OneQSO(inState, At('K0ABC', Band160, CW, 4, 15, 0)), '160 m at 1500 does not');

      (* BOTH DAYS, EVERY MODE. *)
      CheckEquals(1, OneQSO(inState, At('K0ABC', Band40, Phone, 5, 16, 30)), 'Sunday, phone');
      CheckEquals(1, OneQSO(inState, At('K0ABC', Band80, Digital, 5, 19, 0)), 'Sunday, digital');

      (* VALID CONTACTS ONLY: a dupe earns nothing, and neither does an
         out-of-state entrant's QSO with a station the host table does not
         know (Q107 -- it scores 0, so it is not a valid contact). *)
      CheckEquals(0, OneQSO(inState, AsDupe(At('K0ABC', Band40, CW, 4, 15, 0))), 'a dupe does not');
      CheckEquals(0, OneQSO(outOfState, At('K0ABC', Band40, CW, 4, 15, 0)),
                  'out of state, a QSO the host table does not credit');
      CheckEquals(1, OneQSO(WithHostAreaTable(outOfState), At('K0ABC', Band40, CW, 4, 15, 0)),
                  'out of state, a Missouri station');

      (* A COUNT OVER THE LOG, CAPPED AT 250, BESIDE THE BONUS STATIONS. *)
      FreeAndNil(view);
      view := TLoggedQSOList.Create;
      for i := 1 to 249 do
         begin
         view.Add(At('K0ABC', Band40, CW, 4, 14 + (i mod 6), i mod 60));
         end;
      CheckEquals(249, Bonus(MOQSOPARTY, inState, view), '249 peak-hour contacts');
      view.Add(At('K0ABD', Band80, CW, 5, 15, 0));
      CheckEquals(250, Bonus(MOQSOPARTY, inState, view), 'up to 250');
      view.Add(At('K0ABE', Band80, CW, 5, 15, 1));
      CheckEquals(250, Bonus(MOQSOPARTY, inState, view), 'and no further');
      view.Add(At('W0MA', Band20, CW, 5, 21, 0));
      CheckEquals(350, Bonus(MOQSOPARTY, inState, view), 'W0MA''s 100 is added beside it');

      (* THE SAME LOG GIVES THE SAME BONUS THROUGH THE FINAL SCORE, whatever
         the session counted -- there is nothing kept outside the view. *)
      t := Totals(10);
      t.SessionCountsMultipliers := False;
      CheckEquals(10 + 350, Final(MOQSOPARTY, inState, t, view),
                  'the final score: points plus the bonus');

      (* NO OTHER CONTEST PAYS IT. *)
      FreeAndNil(view);
      view := TLoggedQSOList.Create;
      view.Add(At('K0ABC', Band40, CW, 4, 15, 0));
      CheckEquals(0, Bonus(CQWWCW, inState, view), 'CQ WW has no peak-hour bonus');
   finally
      view.Free;
   end;
end;

procedure TContestTotalsTests.Test_NCSweepNeedsFiveRareCounties;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_NCSweepNeedsFiveRareCounties');

   view := TLoggedQSOList.Create;
   try
      view.Add(WithCounty(LoggedQSO('N4A', Band20, CW), 'CAB'));
      view.Add(WithCounty(LoggedQSO('N4B', Band20, CW), 'GRM'));
      view.Add(WithCounty(LoggedQSO('N4C', Band40, Phone), 'VAN'));
      view.Add(WithCounty(LoggedQSO('N4D', Band40, Phone), 'MAC'));
      (* The same county twice is still one county. *)
      view.Add(WithCounty(LoggedQSO('N4E', Band80, CW), 'MAC'));
      (* GRA is a county, and not a rare one -- Graham is GRM. *)
      view.Add(WithCounty(LoggedQSO('N4F', Band80, CW), 'GRA'));
      (* A dupe does not count. *)
      view.Add(AsDupe(WithCounty(LoggedQSO('N4G', Band20, CW), 'DAV')));
      CheckEquals(0, Bonus(NCQSOPARTY, NoStation, view), 'four rare counties: no sweep');

      view.Add(WithCounty(LoggedQSO('N4H', Band20, Digital), 'DAV'));
      CheckEquals(500, Bonus(NCQSOPARTY, NoStation, view), 'five: the sweep');

      view.Add(WithCounty(LoggedQSO('N4I', Band20, CW), 'CUR'));
      view.Add(WithCounty(LoggedQSO('N4J', Band20, CW), 'PAM'));
      view.Add(WithCounty(LoggedQSO('N4K', Band20, CW), 'ALL'));
      view.Add(WithCounty(LoggedQSO('N4L', Band20, CW), 'PER'));
      view.Add(WithCounty(LoggedQSO('N4M', Band20, CW), 'CAS'));
      CheckEquals(500, Bonus(NCQSOPARTY, NoStation, view), 'all ten: still 500, once');
   finally
      view.Free;
   end;
end;

procedure TContestTotalsTests.Test_SalmonRunW7DXOncePerMode;
var
   view: TLoggedQSOList;
   station: TStationContext;
begin
   BeginTest('Test_SalmonRunW7DXOncePerMode');

   station := NoStation;
   station.MyCategoryMode := cmMIXED;
   view := TLoggedQSOList.Create;
   try
      CheckEquals(0, Bonus(SALMONRUN, station, view), 'no W7DX');

      view.Add(LoggedQSO('W7DX', Band20, CW));
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'CW: 500');

      (* "not 500 points for each QSO on each different band" *)
      view.Add(LoggedQSO('W7DX', Band40, CW));
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'a second CW band adds nothing');

      view.Add(LoggedQSO('W7DX', Band40, Phone));
      CheckEquals(1000, Bonus(SALMONRUN, station, view), 'CW and phone: 1000');

      view.Add(LoggedQSO('W7DX', Band20, Phone));
      CheckEquals(1000, Bonus(SALMONRUN, station, view), 'the maximum is 1000');
   finally
      view.Free;
   end;

   view := TLoggedQSOList.Create;
   try
      (* FM IS PHONE, digital is no Salmon Run mode, a dupe is not a QSO. *)
      view.Add(LoggedQSO('W7DX', Band2, FM));
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'FM pays the phone bonus');
      view.Add(LoggedQSO('W7DX', Band20, Digital));
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'digital pays nothing');
      view.Add(AsDupe(LoggedQSO('W7DX', Band20, CW)));
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'a dupe pays nothing');
   finally
      view.Free;
   end;
end;

procedure TContestTotalsTests.Test_SalmonRunSingleModeEntry;
var
   view: TLoggedQSOList;
   station: TStationContext;
begin
   BeginTest('Test_SalmonRunSingleModeEntry');

   view := TLoggedQSOList.Create;
   try
      view.Add(LoggedQSO('W7DX', Band20, CW));
      view.Add(LoggedQSO('W7DX', Band20, Phone));

      station := NoStation;
      station.MyCategoryMode := cmCW;
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'a CW entry claims once');
      station.MyCategoryMode := cmSSB;
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'an SSB entry claims once');
      station.MyCategoryMode := cmFM;
      CheckEquals(500, Bonus(SALMONRUN, station, view), 'an FM entry is a phone entry');
      station.MyCategoryMode := cmDIGITAL;
      CheckEquals(0, Bonus(SALMONRUN, station, view), 'a digital entry has no Salmon Run mode');
   finally
      view.Free;
   end;

   (* THE OTHER MODE'S CONTACT IS NOT CREDITED to a single-mode entry. *)
   view := TLoggedQSOList.Create;
   try
      view.Add(LoggedQSO('W7DX', Band20, Phone));
      station := NoStation;
      station.MyCategoryMode := cmCW;
      CheckEquals(0, Bonus(SALMONRUN, station, view), 'a CW entry is not paid for phone');
   finally
      view.Free;
   end;
end;

type
   (* ONE DECLARED BONUS STATION, K1BON, 10 points, at the scope the test
      names -- the base's payment rule with nothing of a contest's on it. *)
   TScopedBonusContest = class(TContestBase)
   private
      FScope: TBonusStationScope;
   protected
      function GetBonusStations: TBonusStationList; override;
   public
      constructor CreateScoped(aScope: TBonusStationScope);
   end;

constructor TScopedBonusContest.CreateScoped(aScope: TBonusStationScope);
begin
   inherited Create(NoContest);
   FScope := aScope;
end;

function TScopedBonusContest.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'K1BON';
   Result[0].Points := 10;
   Result[0].Scope := FScope;
end;

(* THE THREE SCOPES OVER ONE LOG (#88, 2026-10-26: bsOncePerBandAndMode was
   added for British Columbia's VA7ODX). bsOnce and bsOncePerMode are the
   two the base had -- Missouri's and the Salmon Run's -- and must pay
   exactly what they paid before; the third pays each (band, mode) pair
   once. The base's CountsTowardBonus takes every QSO, dupes included, so
   the dupe on 15 m is a pair of its own; FM is phone. *)
procedure TContestTotalsTests.Test_BonusStationScopes;
var
   view: TLoggedQSOList;
   t: TScoreTotals;

   function PaidAt(aScope: TBonusStationScope): longint;
   var
      contestObject: TScopedBonusContest;
   begin
      contestObject := TScopedBonusContest.CreateScoped(aScope);
      try
         Result := contestObject.BonusPoints(t, view);
      finally
         contestObject.Free;
      end;
   end;

begin
   BeginTest('Test_BonusStationScopes');
   t := Totals(0);
   view := TLoggedQSOList.Create;
   try
      CheckEquals(0, PaidAt(bsOnce), 'an empty log pays nothing once');
      CheckEquals(0, PaidAt(bsOncePerMode), 'nor per mode');
      CheckEquals(0, PaidAt(bsOncePerBandAndMode), 'nor per band and mode');

      view.Add(LoggedQSO('K1BON', Band20, CW));
      view.Add(LoggedQSO('K1BON', Band20, CW));
      view.Add(LoggedQSO('K1BON', Band40, CW));
      view.Add(LoggedQSO('K1BON', Band20, Phone));
      view.Add(LoggedQSO('K1BON', Band20, FM));
      view.Add(LoggedQSO('K1BON', Band20, Digital));
      view.Add(AsDupe(LoggedQSO('K1BON', Band15, CW)));
      view.Add(LoggedQSO('K1BONX', Band10, CW));
      view.Add(LoggedQSO('W1AW', Band10, Phone));

      CheckEquals(10, PaidAt(bsOnce), 'once: 10, however often it was worked');
      CheckEquals(30, PaidAt(bsOncePerMode), 'per mode: CW, phone (FM is phone), digital');
      (* 20 CW, 40 CW, 15 CW (a dupe), 20 phone (and FM), 20 digital. *)
      CheckEquals(50, PaidAt(bsOncePerBandAndMode),
                  'per band and mode: five pairs, 20 m CW and 20 m phone once each');
   finally
      view.Free;
   end;
end;

procedure TContestTotalsTests.Test_IdahoDormantCountyNeedsTenQSOs;
var
   view: TLoggedQSOList;
   station: TStationContext;
   i: integer;
begin
   BeginTest('Test_IdahoDormantCountyNeedsTenQSOs');

   station := NoStation;
   station.InHostState := True;
   station.MyState := 'BUT';
   view := TLoggedQSOList.Create;
   try
      (* A 2026 LOG -- the year has a table (Q35); the year rule itself is
         Test_IdahoPaysTheTableOfTheLogsYear's. *)
      for i := 1 to 9 do
         begin
         view.Add(InYear(LoggedQSO('K' + IntToStr(i) + 'AAA', Band20, CW), 2026));
         end;
      (* NOT VALID: a dupe, and a QSO on a band Idaho does not use. *)
      view.Add(InYear(AsDupe(LoggedQSO('K1AAA', Band20, CW)), 2026));
      view.Add(InYear(LoggedQSO('K0ZZZ', Band30, CW), 2026));
      CheckEquals(0, Bonus(IDAHOQSOPARTY, station, view), 'nine valid QSOs: no bonus');

      view.Add(InYear(LoggedQSO('K0AAA', Band40, Phone), 2026));
      CheckEquals(1000, Bonus(IDAHOQSOPARTY, station, view), 'ten from Butte: 1000');

      station.MyState := 'was';
      CheckEquals(500, Bonus(IDAHOQSOPARTY, station, view), 'Washington: 500');

      station.MyState := 'ADA';
      CheckEquals(0, Bonus(IDAHOQSOPARTY, station, view), 'Ada is not dormant');

      station.MyState := 'BUT';
      station.InHostState := False;
      CheckEquals(0, Bonus(IDAHOQSOPARTY, station, view), 'an out-of-state station activates nothing');
   finally
      view.Free;
   end;
end;

(* THE LOG'S CONTEST YEAR -- uContestBase.LogContestYear (Q35): the start
   time when the log records one, else the EARLIEST dated QSO, else 0. *)
procedure TContestTotalsTests.Test_LogContestYearReadsTheLog;
var
   view: TLoggedQSOList;
   t: TScoreTotals;
begin
   BeginTest('Test_LogContestYearReadsTheLog');

   t := Totals(0);
   view := TLoggedQSOList.Create;
   try
      CheckEquals(0, LogContestYear(t, view), 'an empty log with no start has no year');
      CheckEquals(0, LogContestYear(t, nil), 'nor does no view at all');

      (* tree.pas's "no time": a zero month and day. *)
      view.Add(LoggedQSO('K1AAA', Band20, CW));
      CheckEquals(0, LogContestYear(t, view), 'an undated QSO says nothing about the year');

      (* OUT OF LOG ORDER: the older QSO is added second. *)
      view.Add(OnDay(LoggedQSO('K2AAA', Band20, CW), 2027, 1, 2));
      view.Add(OnDay(LoggedQSO('K3AAA', Band20, CW), 2026, 12, 31));
      CheckEquals(2026, LogContestYear(t, view), 'the EARLIEST dated QSO, not the first in the list');

      t.LogStartTime := EncodeDate(2025, 3, 8) + EncodeTime(14, 0, 0, 0);
      CheckEquals(2025, LogContestYear(t, view), 'a recorded start time outranks every QSO date');
   finally
      view.Free;
   end;
end;

(* A 2026 LOG PAYS THE 2026 TABLE -- by the QSOs' dates, the only source of
   the year until Q99 writes start_time. Butte 1000, Washington 500, and Ada
   (in no table) nothing. *)
procedure TContestTotalsTests.Test_IdahoPaysTheTableOfTheLogsYear;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_IdahoPaysTheTableOfTheLogsYear');

   view := TLoggedQSOList.Create;
   try
      AddIdahoQSOs(view, 10, 2026);
      CheckEquals(1000, IdahoBonus(IdahoEntrant('BUT'), Totals(0), view), '2026, Butte: 1000');
      CheckEquals(500, IdahoBonus(IdahoEntrant('WAS'), Totals(0), view), '2026, Washington: 500');
      CheckEquals(0, IdahoBonus(IdahoEntrant('ADA'), Totals(0), view), '2026, Ada is not dormant');
   finally
      view.Free;
   end;
end;

(* A YEAR WITH NO TABLE PAYS NO COUNTY BONUS AND SAYS SO (Q35: "no silent
   zero"). One Error in the Idaho unit's log naming the year and the county,
   written ONCE per year however often the score is asked; a log too short to
   earn a bonus is not reported; a log with no year at all is reported as
   such. *)
procedure TContestTotalsTests.Test_IdahoYearWithNoTablePaysNothingAndSaysSo;
var
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
   idaho: TContestBase;
   view: TLoggedQSOList;
   i: integer;
begin
   BeginTest('Test_IdahoYearWithNoTablePaysNothingAndSaysSo');

   capture := TCaptureAppender.Create('capture');
   keep := capture;
   lg := TLogLogger.GetLogger('uContestIdahoQP');
   savedLevel := lg.Level;
   lg.Level := Log4D.Error;
   lg.AddAppender(keep);
   view := TLoggedQSOList.Create;
   idaho := Make(IDAHOQSOPARTY, IdahoEntrant('BUT'));
   try
      (* NINE QSOs: no list could pay, so nothing is reported. *)
      AddIdahoQSOs(view, 9, 2031);
      CheckEquals(0, idaho.BonusPoints(Totals(0), view), 'nine QSOs in 2031: no bonus');
      CheckEquals(0, capture.Lines.Count, 'and nothing to report below ten');

      view.Clear;
      AddIdahoQSOs(view, 10, 2031);
      CheckFalse(TContestIdahoQP.HasDormantCountyTable(2031), 'the fixture year has no table');
      CheckEquals(0, idaho.BonusPoints(Totals(0), view), '2031 has no table: no county bonus');
      CheckEquals(1, capture.Lines.Count, 'and it is REPORTED');
      CheckTrue(Pos('2031', capture.Lines.Text) > 0, 'naming the year: ' + capture.Lines.Text);
      CheckTrue(Pos('BUT', capture.Lines.Text) > 0, 'and the county: ' + capture.Lines.Text);
      CheckTrue(Pos('NOT in the score', capture.Lines.Text) > 0,
                'and saying the score leaves it out: ' + capture.Lines.Text);

      CheckEquals(0, idaho.BonusPoints(Totals(0), view), 'asked again');
      CheckEquals(1, capture.Lines.Count, 'reported once per year, not once per score');

      (* NO YEAR AT ALL: ten undated QSOs and no start time. *)
      view.Clear;
      for i := 0 to 9 do
         begin
         view.Add(LoggedQSO('K' + IntToStr(i) + 'AAA', Band20, CW));
         end;
      CheckEquals(0, idaho.BonusPoints(Totals(0), view), 'a log with no year: no county bonus');
      CheckEquals(2, capture.Lines.Count, 'and that is reported too');
      CheckTrue(Pos('no contest year', capture.Lines[1]) > 0, 'as no year: ' + capture.Lines[1]);
   finally
      lg.RemoveAppender(keep);
      lg.Level := savedLevel;
      keep := nil;
      idaho.Free;
      view.Free;
   end;
end;

(* THE LOG'S START TIME OUTRANKS ITS QSOs' DATES (Q35) -- end to end
   through the bonus. QSOs dated 2031 in a log that says it started in 2026
   are paid the 2026 list; QSOs dated 2026 in a log that says 2031 are not. *)
procedure TContestTotalsTests.Test_IdahoStartTimeOutranksTheFirstQSO;
var
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
   view: TLoggedQSOList;
   t: TScoreTotals;
begin
   BeginTest('Test_IdahoStartTimeOutranksTheFirstQSO');

   (* Captured only to keep the expected 2031 report out of the run's log. *)
   capture := TCaptureAppender.Create('capture');
   keep := capture;
   lg := TLogLogger.GetLogger('uContestIdahoQP');
   savedLevel := lg.Level;
   lg.Level := Log4D.Error;
   lg.AddAppender(keep);
   view := TLoggedQSOList.Create;
   try
      AddIdahoQSOs(view, 10, 2031);
      t := Totals(0);
      t.LogStartTime := EncodeDate(2026, 3, 14) + EncodeTime(19, 0, 0, 0);
      CheckEquals(1000, IdahoBonus(IdahoEntrant('BUT'), t, view),
                  'a 2026 start pays the 2026 list, whatever the QSOs say');

      view.Clear;
      AddIdahoQSOs(view, 10, 2026);
      t.LogStartTime := EncodeDate(2031, 3, 8);
      CheckEquals(0, IdahoBonus(IdahoEntrant('BUT'), t, view),
                  'a 2031 start is 2031, which has no table, though the QSOs are 2026');
      CheckTrue(Pos('2031', capture.Lines.Text) > 0, 'and reports 2031: ' + capture.Lines.Text);
   finally
      lg.RemoveAppender(keep);
      lg.Level := savedLevel;
      keep := nil;
      view.Free;
   end;
end;

(* THE YEARLY REMINDER -- Q35, DELIBERATELY ON THE CLOCK. This is the ONE
   place the current date is read, and it is a test, not a rule: on the first
   run of a year with no Idaho table this FAILS, until the sponsor's table for
   that year (https://www.idahoqsoparty.org/idaho_rovers.htm) is added to
   uContestIdahoQP as a new table beside the old ones. Do not "fix" it by
   registering an old table for a new year without the sponsor's word --
   that pays a list nobody confirmed. *)
procedure TContestTotalsTests.Test_IdahoHasATableForTheCurrentYear;
begin
   BeginTest('Test_IdahoHasATableForTheCurrentYear');

   CheckTrue(TContestIdahoQP.HasDormantCountyTable(2026), 'the 2026 table is registered');
   CheckFalse(TContestIdahoQP.HasDormantCountyTable(2025),
              'and it is not claimed for an earlier contest');
   CheckTrue(TContestIdahoQP.HasDormantCountyTable(CurrentYear),
             Format('YEARLY REMINDER: uContestIdahoQP has no dormant-county bonus table for %d. ' +
                    'Add the sponsor''s table for that contest (idaho_rovers.htm).',
                    [CurrentYear]));
end;

procedure TContestTotalsTests.Test_QSOCountsTowardTotals;
var
   qso: ContestExchange;
begin
   BeginTest('Test_QSOCountsTowardTotals');

   qso := LoggedQSO('W1AW', Band20, CW);
   CheckTrue(QSOCountsTowardTotals(nil, qso), 'a QSO counts');
   qso.ceDupe := True;
   CheckTrue(QSOCountsTowardTotals(nil, qso), 'a dupe counts -- the loader counts it');

   qso := LoggedQSO('W1AW', Band20, CW);
   qso.ceQSO_Deleted := True;
   CheckFalse(QSOCountsTowardTotals(nil, qso), 'deleted');
   qso := LoggedQSO('W1AW', Band20, CW);
   qso.ceXQSO := True;
   CheckFalse(QSOCountsTowardTotals(nil, qso), 'an X-QSO');
   qso := LoggedQSO('W1AW', NoBand, CW);
   CheckFalse(QSOCountsTowardTotals(nil, qso), 'no band');
   qso := LoggedQSO('W1AW', Band20, NoMode);
   CheckFalse(QSOCountsTowardTotals(nil, qso), 'no mode');
   qso := LoggedQSO('W1AW', Band20, CW);
   qso.ceRecordKind := rkQTCS;
   CheckFalse(QSOCountsTowardTotals(nil, qso), 'a QTC record');
end;

(* THE RECORDS THE SUMMARY-SHEET TEST HANDS TallySummaryTotals, in order --
   PostUnit.TSummaryRecordReader is a plain function, so its state is here. *)
var
   GSummaryRecords: array of ContestExchange;
   GSummaryNext: integer;

function NextSummaryRecord(out aQso: ContestExchange): boolean;
begin
   Result := GSummaryNext <= High(GSummaryRecords);
   if Result then
      begin
      aQso := GSummaryRecords[GSummaryNext];
      Inc(GSummaryNext);
      end
   else
      begin
      FillChar(aQso, SizeOf(ContestExchange), 0);
      end;
end;

(* THE SUMMARY SHEET COUNTS WHAT THE TOTALS COUNT (Q51, NY4I: "x-qso never
   counts as worked"; CONTEST_OWNERSHIP_DESIGN.md 8.2v). It tested deleted
   and the record kind, then band and mode for the valid column, and never
   ceXQSO, so a flagged X-QSO was counted in both columns. Now its filter is
   QSOCountsTowardTotals itself: the raw column counts exactly the records
   that predicate accepts (dupes included), the valid column those of them
   that are not dupes, and an X-QSO adds to neither, nor to the points. *)
procedure TContestTotalsTests.Test_SummarySheetCountsWhatTheTotalsCount;
var
   i: integer;
   counted: integer;
   savedContest: TContestHandle;
begin
   BeginTest('Test_SummarySheetCountsWhatTheTotalsCount');

   SetLength(GSummaryRecords, 6);
   GSummaryRecords[0] := LoggedQSO('W1AW', Band20, CW);
   GSummaryRecords[0].QSOPoints := 2;
   GSummaryRecords[1] := AsDupe(LoggedQSO('W1AW', Band20, CW));
   (* The X-QSO carries points and a flag, as a stored record can: neither
      may reach the sheet. *)
   GSummaryRecords[2] := LoggedQSO('K1ABC', Band20, CW);
   GSummaryRecords[2].ceXQSO := True;
   GSummaryRecords[2].QSOPoints := 3;
   GSummaryRecords[2].DXMult := True;
   GSummaryRecords[3] := LoggedQSO('K2ABC', Band20, CW);
   GSummaryRecords[3].ceQSO_Deleted := True;
   GSummaryRecords[4] := LoggedQSO('K3ABC', NoBand, CW);
   (* An X-QSO on another band: no row may appear for it at all. *)
   GSummaryRecords[5] := LoggedQSO('K4ABC', Band40, Phone);
   GSummaryRecords[5].ceXQSO := True;
   GSummaryRecords[5].QSOPoints := 1;

   counted := 0;
   for i := Low(GSummaryRecords) to High(GSummaryRecords) do
      begin
      if QSOCountsTowardTotals(nil, GSummaryRecords[i]) then
         begin
         Inc(counted);
         end;
      end;

   (* A NAMED CONTEST, so the operating-time break it reads is a known one;
      the counts asserted here do not depend on it. *)
   savedContest := Contest;
   try
      Contest := ContestHandleOf(CQWWCW);
      GSummaryNext := 0;
      TallySummaryTotals(@NextSummaryRecord);
   finally
      Contest := savedContest;
   end;

   CheckEquals(counted, RawQSOTotals[AllBands, Both],
               'the raw column is exactly what QSOCountsTowardTotals accepts');
   CheckEquals(2, RawQSOTotals[Band20, CW], 'raw 20 m CW: the QSO and its dupe, not the X-QSO');
   CheckEquals(1, PostQSOTotals[Band20, CW], 'valid 20 m CW: the QSO alone');
   CheckEquals(2, QSOPointTotals[Band20, CW], 'points 20 m CW: the QSO''s, never the X-QSO''s');
   CheckEquals(0, RawQSOTotals[Band40, Phone], 'an X-QSO alone on a band makes no row');
   CheckEquals(2, QSOPointTotals[AllBands, Both], 'all points: the QSO''s alone, no X-QSO''s');
   CheckEquals(0, RawQSOTotals[NoBand, CW], 'a record with no band counts nowhere');

   SetLength(GSummaryRecords, 0);
end;

(* A RESCORED X-QSO KEEPS NO SCORING (Q51; 8.2v's finding): the rescore's
   X-QSO arm (MainUnit.tUpdateLog) zeroed the points and the dupe and left
   the stored multiplier flags set, so a reader of DXMult/ZoneMult could
   report a multiplier for it. ClearXQSOScoring is that arm. The record keeps
   what it was worked with -- only its credit goes. *)
procedure TContestTotalsTests.Test_RescoredXQSOKeepsNoScoring;
var
   qso: ContestExchange;
begin
   BeginTest('Test_RescoredXQSOKeepsNoScoring');

   qso := LoggedQSO('W1AW', Band20, CW);
   qso.ceXQSO := True;
   qso.QSOPoints := 3;
   qso.ceDupe := True;
   qso.DomesticMult := True;
   qso.DXMult := True;
   qso.PrefixMult := True;
   qso.ZoneMult := True;
   qso.DomesticQTH := 'CT';
   qso.DomMultQTH := 'CT';
   qso.Zone := 5;

   ClearXQSOScoring(qso);

   CheckEquals(0, qso.QSOPoints, 'no points');
   CheckFalse(qso.ceDupe, 'no dupe mark');
   CheckFalse(qso.DomesticMult, 'no domestic multiplier');
   CheckFalse(qso.DXMult, 'no DX multiplier');
   CheckFalse(qso.PrefixMult, 'no prefix multiplier');
   CheckFalse(qso.ZoneMult, 'no zone multiplier');
   CheckTrue(qso.ceXQSO, 'still an X-QSO');
   CheckEquals('CT', string(qso.DomesticQTH), 'the QTH it was worked with stays');
   CheckEquals('CT', string(qso.DomMultQTH), 'the multiplier QTH it sent stays');
   CheckEquals(5, qso.Zone, 'the zone it sent stays');
   CheckEquals('W1AW', string(qso.Callsign), 'the call stays');
end;

(* THE APPLICATION'S VIEW KEEPS WHAT THE LOADER COUNTS, AND RESETS WITH THE
   TOTALS. Read through a contest, which is the only way a rule sees it: the
   Missouri class pays W0MA only while a counted W0MA contact is in the view.
   (Not through ContestFinalScore, which asks ActiveContest and so the
   program's settings.) *)
procedure TContestTotalsTests.Test_ApplicationViewIsTheLoadersSet;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_ApplicationViewIsTheLoadersSet');

   contestObject := Make(MOQSOPARTY, NoStation);
   try
      ResetLoggedQSOs;
      qso := LoggedQSO('W0MA', Band20, CW);
      qso.ceXQSO := True;
      AddLoggedQSO(qso);
      qso := LoggedQSO('W0MA', Band20, CW);
      qso.ceQSO_Deleted := True;
      AddLoggedQSO(qso);
      CheckEquals(0, LoggedQSOView.Count, 'an X-QSO and a deleted QSO are not kept');
      CheckEquals(0, contestObject.BonusPoints(Totals(0), LoggedQSOView), 'so no bonus');

      AddLoggedQSO(LoggedQSO('W0MA', Band20, CW));
      CheckEquals(1, LoggedQSOView.Count, 'a counted QSO is kept');
      CheckEquals(100, contestObject.BonusPoints(Totals(0), LoggedQSOView), 'and pays');

      ResetLoggedQSOs;
      CheckEquals(0, LoggedQSOView.Count, 'the reset empties it');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE NEW CLASSES' PER-QSO RULES -- spot checks; the matrix holds them
   exactly against the arms they replaced.
   --------------------------------------------------------------------------- *)

procedure TContestTotalsTests.Test_NewClassesScoreTheirArms;
var
   contestObject: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
begin
   BeginTest('Test_NewClassesScoreTheirArms');

   (* WAE: a European station scores 1 outside Europe, never on 160 m. *)
   station := NoStation;
   station.MyContinent := Europe;
   contestObject := Make(DARCWAEDCCW, station);
   try
      qso := LoggedQSO('W1AW', Band20, CW);
      qso.QTH.Continent := NorthAmerica;
      contestObject.ScoreQSO(qso);
      CheckEquals(1, qso.QSOPoints, 'WAE: Europe to North America');
      qso := LoggedQSO('W1AW', Band160, CW);
      qso.QTH.Continent := NorthAmerica;
      contestObject.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'WAE: never on 160 m');
      qso := LoggedQSO('DL1AAA', Band20, CW);
      qso.QTH.Continent := Europe;
      contestObject.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'WAE: Europe to Europe');
   finally
      contestObject.Free;
   end;

   (* RF Cup without both grids: 1. *)
   contestObject := Make(CUPRFCW, NoStation);
   try
      qso := LoggedQSO('UA3AAA', Band20, CW);
      contestObject.ScoreQSO(qso);
      CheckEquals(1, qso.QSOPoints, 'RF Cup: no grids, 1 point');
   finally
      contestObject.Free;
   end;

   (* RF Championship: the table by the two zones, and the oblast set. *)
   station := NoStation;
   station.MyState := '3';
   contestObject := Make(RFCHAMPIONSHIPCW, station);
   try
      qso := LoggedQSO('UA3AAA', Band20, CW);
      qso.QTH.CountryID := 'UA';
      qso.Zone := 5;
      contestObject.ScoreQSO(qso);
      CheckEquals(14, qso.QSOPoints, 'RF Championship: zone 3 to zone 5');
      qso := LoggedQSO('DL1AAA', Band20, CW);
      qso.QTH.CountryID := 'DL';
      qso.Zone := 5;
      contestObject.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'RF Championship: a non-Russian station');
   finally
      contestObject.Free;
   end;

   (* OZHCR: no grid of ours, no points. *)
   contestObject := Make(OZHCRVHF, NoStation);
   try
      qso := LoggedQSO('OZ1AAA', Band2, CW);
      contestObject.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'OZHCR: no grid of ours');
   finally
      contestObject.Free;
   end;
end;

procedure TContestTotalsTests.Test_OnlyBonusContestsDeclareStations;
var
   c: ContestType;
   contestObject: TContestBase;
   declaring: string;
begin
   BeginTest('Test_OnlyBonusContestsDeclareStations');

   (* THE LIST IS CLOSED: a contest that gains a bonus station joins it here,
      in the commit that gives it one, with its sponsor's rule. *)
   declaring := '';
   for c := Low(ContestType) to High(ContestType) do
      begin
      if ContestClassFor(c) = nil then
         begin
         Continue;
         end;
      contestObject := Make(c, NoStation);
      try
         if Length(contestObject.BonusStations) > 0 then
            begin
            declaring := declaring + ' ' + ContestTypeSA[c];
            end;
      finally
         contestObject.Free;
      end;
      end;
   (* BCQP joined at #88 (2026-10-26): "Any QSO with the Orca DXCC
      station, VA7ODX, will be worth an additional 20 points." *)
   CheckEquals(' MISSOURI QSO PARTY SALMON RUN BCQP', declaring,
               'the contests that declare bonus stations');
end;

procedure TContestTotalsTests.RunAllTests;
begin
   Test_BaseIsPointsTimesMultipliers;
   Test_NoMultipliersScoresThePoints;
   Test_FieldDayFormulas;
   Test_WAEWeightsItsMultipliers;
   Test_RussianCupsAddPerMultiplier;
   Test_UralCupPaysPrefixesAsPoints;
   Test_RSGB18ScoresItsPointsAlone;
   Test_FinalScoreIsFormulaPlusBonus;
   Test_MissouriBonusStations;
   Test_MissouriPeakHourBonus;
   Test_NCSweepNeedsFiveRareCounties;
   Test_SalmonRunW7DXOncePerMode;
   Test_SalmonRunSingleModeEntry;
   Test_BonusStationScopes;
   Test_IdahoDormantCountyNeedsTenQSOs;
   Test_LogContestYearReadsTheLog;
   Test_IdahoPaysTheTableOfTheLogsYear;
   Test_IdahoYearWithNoTablePaysNothingAndSaysSo;
   Test_IdahoStartTimeOutranksTheFirstQSO;
   Test_IdahoHasATableForTheCurrentYear;
   Test_QSOCountsTowardTotals;
   Test_SummarySheetCountsWhatTheTotalsCount;
   Test_RescoredXQSOKeepsNoScoring;
   Test_ApplicationViewIsTheLoadersSet;
   Test_NewClassesScoreTheirArms;
   Test_OnlyBonusContestsDeclareStations;
end;

end.
