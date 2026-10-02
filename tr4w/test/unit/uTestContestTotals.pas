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
      the points alone for a session with no multiplier or the FISTS
      exchange -- a template no contest can skip; a bonus only from declared
      stations.
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
      procedure Test_FinalScoreIsFormulaPlusBonus;
      procedure Test_MissouriBonusStations;
      procedure Test_MissouriLiveTally;
      procedure Test_NCSweepNeedsFiveRareCounties;
      procedure Test_SalmonRunW7DXOncePerMode;
      procedure Test_SalmonRunSingleModeEntry;
      procedure Test_IdahoDormantCountyNeedsTenQSOs;
      procedure Test_QSOCountsTowardTotals;
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
   uTestContestObjects;

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
   Result.SessionExchange := RSTQSONumberExchange;
   Result.SessionDXMult := ARRLDXCC;
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

   t.SessionCountsMultipliers := True;
   t.SessionExchange := RSTQTHNameAndFistsNumberOrPowerExchange;
   CheckEquals(11, Combine(CQWWCW, NoStation, t), 'the FISTS exchange scores its points');
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
begin
   BeginTest('Test_WAEWeightsItsMultipliers');

   t := Totals(10);
   t.Mults[Band80, Both, rmPrefix] := 1;
   t.Mults[Band40, Both, rmPrefix] := 1;
   t.Mults[Band20, Both, rmPrefix] := 1;
   t.Mults[Band15, Both, rmPrefix] := 1;
   t.Mults[Band10, Both, rmPrefix] := 1;
   t.Mults[AllBands, Both, rmPrefix] := 5;
   t.Mults[Band80, Both, rmDX] := 2;
   t.Mults[AllBands, Both, rmDX] := 2;
   t.SessionDXMult := ARRLDXCC;
   (* 4 + 3 + 2 + 2 + 2 = 13 prefixes' worth. *)
   CheckEquals(130, Combine(DARCWAEDCCW, NoStation, t), 'WAE prefixes, weighted by band');
   CheckEquals(130, Combine(DARCWAEDCSSB, NoStation, t), 'the SSB running, the same');

   (* A NON-EUROPEAN STATION'S SESSION counts European countries. *)
   t.SessionDXMult := CQEuropeanCountries;
   CheckEquals(10 * 8, Combine(DARCWAEDCCW, NoStation, t), 'European countries, four on 80 m');

   (* A single-band entry: the general case on its band. *)
   t.ScoredBand := Band80;
   CheckEquals(10 * 3, Combine(DARCWAEDCCW, NoStation, t), 'a single-band entry is not weighted');
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

procedure TContestTotalsTests.Test_MissouriLiveTally;
var
   contestObject: TContestBase;
   qso: ContestExchange;
   t: TScoreTotals;
   view: TLoggedQSOList;

   function TalliesAt(aBand: BandType; aHour, aMinute: byte): boolean;
   begin
      qso := LoggedQSO('K0AAA', aBand, CW);
      qso.tSysTime.qtHour := aHour;
      qso.tSysTime.qtMinute := aMinute;
      Result := contestObject.TalliesLiveQSO(qso);
   end;

begin
   BeginTest('Test_MissouriLiveTally');

   contestObject := Make(MOQSOPARTY, NoStation);
   view := TLoggedQSOList.Create;
   try
      CheckTrue(TalliesAt(Band80, 14, 0), '80 m at 1400');
      CheckTrue(TalliesAt(Band40, 19, 59), '40 m at 1959');
      CheckFalse(TalliesAt(Band40, 13, 59), '40 m at 1359');
      CheckFalse(TalliesAt(Band80, 20, 0), '80 m at 2000');
      CheckFalse(TalliesAt(Band20, 15, 0), '20 m at 1500');

      t := Totals(0);
      t.LiveSessionTally := 249;
      CheckEquals(249, contestObject.BonusPoints(t, view), 'the tally is paid');
      t.LiveSessionTally := 250;
      CheckEquals(250, contestObject.BonusPoints(t, view), 'up to 250');
      t.LiveSessionTally := 251;
      CheckEquals(250, contestObject.BonusPoints(t, view), 'and no further');
   finally
      view.Free;
      contestObject.Free;
   end;

   (* NO OTHER CONTEST TALLIES ANYTHING. *)
   contestObject := Make(CQWWCW, NoStation);
   try
      CheckFalse(TalliesAt(Band80, 15, 0), 'CQ WW keeps no live tally');
   finally
      contestObject.Free;
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
      for i := 1 to 9 do
         begin
         view.Add(LoggedQSO('K' + IntToStr(i) + 'AAA', Band20, CW));
         end;
      (* NOT VALID: a dupe, and a QSO on a band Idaho does not use. *)
      view.Add(AsDupe(LoggedQSO('K1AAA', Band20, CW)));
      view.Add(LoggedQSO('K0ZZZ', Band30, CW));
      CheckEquals(0, Bonus(IDAHOQSOPARTY, station, view), 'nine valid QSOs: no bonus');

      view.Add(LoggedQSO('K0AAA', Band40, Phone));
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

procedure TContestTotalsTests.Test_QSOCountsTowardTotals;
var
   qso: ContestExchange;
begin
   BeginTest('Test_QSOCountsTowardTotals');

   qso := LoggedQSO('W1AW', Band20, CW);
   CheckTrue(QSOCountsTowardTotals(qso), 'a QSO counts');
   qso.ceDupe := True;
   CheckTrue(QSOCountsTowardTotals(qso), 'a dupe counts -- the loader counts it');

   qso := LoggedQSO('W1AW', Band20, CW);
   qso.ceQSO_Deleted := True;
   CheckFalse(QSOCountsTowardTotals(qso), 'deleted');
   qso := LoggedQSO('W1AW', Band20, CW);
   qso.ceXQSO := True;
   CheckFalse(QSOCountsTowardTotals(qso), 'an X-QSO');
   qso := LoggedQSO('W1AW', NoBand, CW);
   CheckFalse(QSOCountsTowardTotals(qso), 'no band');
   qso := LoggedQSO('W1AW', Band20, NoMode);
   CheckFalse(QSOCountsTowardTotals(qso), 'no mode');
   qso := LoggedQSO('W1AW', Band20, CW);
   qso.ceRecordKind := rkQTCS;
   CheckFalse(QSOCountsTowardTotals(qso), 'a QTC record');
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
   CheckEquals(' MISSOURI QSO PARTY SALMON RUN', declaring, 'the contests that declare bonus stations');
end;

procedure TContestTotalsTests.RunAllTests;
begin
   Test_BaseIsPointsTimesMultipliers;
   Test_NoMultipliersScoresThePoints;
   Test_FieldDayFormulas;
   Test_WAEWeightsItsMultipliers;
   Test_RussianCupsAddPerMultiplier;
   Test_UralCupPaysPrefixesAsPoints;
   Test_FinalScoreIsFormulaPlusBonus;
   Test_MissouriBonusStations;
   Test_MissouriLiveTally;
   Test_NCSweepNeedsFiveRareCounties;
   Test_SalmonRunW7DXOncePerMode;
   Test_SalmonRunSingleModeEntry;
   Test_IdahoDormantCountyNeedsTenQSOs;
   Test_QSOCountsTowardTotals;
   Test_ApplicationViewIsTheLoadersSet;
   Test_NewClassesScoreTheirArms;
   Test_OnlyBonusContestsDeclareStations;
end;

end.
