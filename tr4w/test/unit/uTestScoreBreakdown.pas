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
 *)
unit uTestScoreBreakdown;

{$I ..\..\src\tr4w.inc}

(* THE <breakdown> OF THE ONLINE-SCORING POST (uScoreBreakdown).

   RTC 2026, NY4I, 2026-11-01: eight QSOs on 20 m CW and eight grids, and the
   post carried the multiplier count under four rows -- 20/CW, 20/ALL,
   total/CW, total/ALL. The scorer reported 16 raw multipliers. These pin
   DXLog's shape, which the scorer accepts: one mode="ALL" row per band for
   the QSOs, the points and each multiplier, then ONE total/ALL summary; no
   per-mode rows; each multiplier labelled by the contest, a grid as
   gridsquare. *)

interface

uses
   uTR4WTestFramework;

type
   TScoreBreakdownTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_RTCOneBandCWLogIsOneAllModesBandRowAndOneSummary;
      procedure Test_NoRowNamesAModeOrAModeTotal;
      procedure Test_TwoBandsGiveOneRowEachAndOneSummary;
      procedure Test_AGridWorkedInTwoModesOnABandCountsOnce;
      procedure Test_WRTCPostsItsMultipliersOnEveryAllModesRow;
      procedure Test_AnEmptyLogPostsTheQSOSummaryAlone;
      procedure Test_TheScoreIsRebuiltOnAChangeAtMostEveryMinInterval;
      procedure Test_TheScoreIsRebuiltOnTheHeartbeatWithNoChange;
      procedure Test_TheQthGridIsTheStationsSixCharactersWhenItIsTheSameSquare;
   end;

implementation

uses
   SysUtils,
   VC,
   uMults,
   uContestBase,
   uScoreBreakdown,
   uTestContestObjects;

(* The totals the engine keeps for aCount QSOs, each a new multiplier and
   aPoints points, on aBand in aMode: the band, the AllBands row, and the
   Both column of each -- uMults and postunit increment all four. *)
procedure AddWork(var aTotals: TBreakdownTotals; aBand: BandType; aMode: ModeType;
                  aCount: integer; aPoints: integer; aKind: RemainingMultiplierType);
begin
   aTotals.QSOs[aBand, aMode] := aTotals.QSOs[aBand, aMode] + aCount;
   aTotals.QSOs[aBand, Both] := aTotals.QSOs[aBand, Both] + aCount;
   aTotals.QSOs[AllBands, aMode] := aTotals.QSOs[AllBands, aMode] + aCount;
   aTotals.QSOs[AllBands, Both] := aTotals.QSOs[AllBands, Both] + aCount;

   aTotals.Points[aBand, aMode] := aTotals.Points[aBand, aMode] + aPoints;
   aTotals.Points[aBand, Both] := aTotals.Points[aBand, Both] + aPoints;
   aTotals.Points[AllBands, aMode] := aTotals.Points[AllBands, aMode] + aPoints;
   aTotals.Points[AllBands, Both] := aTotals.Points[AllBands, Both] + aPoints;

   aTotals.Mults[aBand, aMode, aKind] := aTotals.Mults[aBand, aMode, aKind] + aCount;
   aTotals.Mults[aBand, Both, aKind] := aTotals.Mults[aBand, Both, aKind] + aCount;
   aTotals.Mults[AllBands, aMode, aKind] := aTotals.Mults[AllBands, aMode, aKind] + aCount;
   aTotals.Mults[AllBands, Both, aKind] := aTotals.Mults[AllBands, Both, aKind] + aCount;
end;

(* THE RTC LOG THAT WAS POSTED: 8 QSOs, 8 grids, 11 points, 20 m CW. *)
function RTCLogTotals: TBreakdownTotals;
begin
   Result := Default(TBreakdownTotals);
   AddWork(Result, Band20, CW, 8, 11, rmDomestic);
end;

function BreakdownFor(aContest: ContestType; const aTotals: TBreakdownTotals): string;
var
   obj: TContestBase;
begin
   obj := Make(aContest);
   try
      Result := string(BuildBreakdownXml(aTotals, obj));
   finally
      obj.Free;
      end;
end;

procedure TScoreBreakdownTests.Test_RTCOneBandCWLogIsOneAllModesBandRowAndOneSummary;
const
   EXPECTED =
      '<qso band="20" mode="ALL">8</qso>' +
      '<point band="20" mode="ALL">11</point>' +
      '<mult band="20" mode="ALL" type="gridsquare">8</mult>' +
      '<qso band="total" mode="ALL">8</qso>' +
      '<point band="total" mode="ALL">11</point>' +
      '<mult band="total" mode="ALL" type="gridsquare">8</mult>';
begin
   BeginTest('Test_RTCOneBandCWLogIsOneAllModesBandRowAndOneSummary');
   CheckEquals(EXPECTED, BreakdownFor(RTC, RTCLogTotals),
               'the RTC log: one all-modes row of each kind for 20 m and one summary');
end;

procedure TScoreBreakdownTests.Test_NoRowNamesAModeOrAModeTotal;
var
   xml: string;
begin
   BeginTest('Test_NoRowNamesAModeOrAModeTotal');
   xml := BreakdownFor(RTC, RTCLogTotals);
   CheckEquals(0, Pos('mode="CW"', xml),
               'no per-mode row -- the scorer summed it beside the band row');
   CheckEquals(0, Pos('band="total" mode="CW"', xml),
               'no total for one mode -- the scorer summed it as another 8');
   CheckEquals(0, Pos('type="state"', xml), 'a grid is not a state');
   CheckEquals(2 * Length('type="gridsquare"'),
               Length(xml) - Length(StringReplace(xml, 'type="gridsquare"', '', [rfReplaceAll])),
               'two multiplier rows only: the 20 m row and the summary');
end;

procedure TScoreBreakdownTests.Test_TwoBandsGiveOneRowEachAndOneSummary;
var
   totals: TBreakdownTotals;
   xml: string;
begin
   BeginTest('Test_TwoBandsGiveOneRowEachAndOneSummary');
   totals := Default(TBreakdownTotals);
   AddWork(totals, Band20, CW, 3, 6, rmDomestic);
   AddWork(totals, Band40, Phone, 2, 4, rmDomestic);
   xml := BreakdownFor(RTC, totals);
   CheckTrue(Pos('<qso band="20" mode="ALL">3</qso>', xml) > 0, '20 m qsos: ' + xml);
   CheckTrue(Pos('<qso band="40" mode="ALL">2</qso>', xml) > 0, '40 m qsos: ' + xml);
   CheckEquals(0, Pos('band="80"', xml), 'a band with no QSOs posts nothing');
   CheckTrue(Pos('<qso band="total" mode="ALL">5</qso>', xml) > 0, 'the qsos summed once: ' + xml);
   CheckTrue(Pos('<mult band="total" mode="ALL" type="gridsquare">5</mult>', xml) > 0,
             'the multipliers from the all-bands, all-modes slot: ' + xml);
end;

(* THE REASON FOR THE SHAPE: a grid worked on 20 m CW and again on 20 m phone
   is one multiplier on 20 m (RTC counts by band, not by mode). The CW slot and
   the phone slot each say 1, the Both slot says 1; adding the first two gives
   the wrong 2. The row must be the Both slot's. *)
procedure TScoreBreakdownTests.Test_AGridWorkedInTwoModesOnABandCountsOnce;
var
   totals: TBreakdownTotals;
   xml: string;
begin
   BeginTest('Test_AGridWorkedInTwoModesOnABandCountsOnce');
   totals := Default(TBreakdownTotals);
   AddWork(totals, Band20, CW, 1, 1, rmDomestic);
   (* The phone QSO is a second QSO in the same grid: a new multiplier in the
      phone column, none on the band or in total. *)
   totals.QSOs[Band20, Phone] := 1;
   totals.QSOs[Band20, Both] := 2;
   totals.QSOs[AllBands, Phone] := 1;
   totals.QSOs[AllBands, Both] := 2;
   totals.Points[Band20, Phone] := 1;
   totals.Points[Band20, Both] := 2;
   totals.Points[AllBands, Phone] := 1;
   totals.Points[AllBands, Both] := 2;
   totals.Mults[Band20, Phone, rmDomestic] := 1;
   xml := BreakdownFor(RTC, totals);
   CheckTrue(Pos('<mult band="20" mode="ALL" type="gridsquare">1</mult>', xml) > 0,
             'one multiplier on 20 m: ' + xml);
   CheckEquals(0, Pos('mode="CW"', xml), 'no CW row: ' + xml);
   CheckEquals(0, Pos('mode="PH"', xml), 'no phone row: ' + xml);
   CheckEquals(Length('<mult band="20"'),
               Length(xml) - Length(StringReplace(xml, '<mult band="20"', '', [rfReplaceAll])),
               'exactly one multiplier row for 20 m');
end;

procedure TScoreBreakdownTests.Test_WRTCPostsItsMultipliersOnEveryAllModesRow;
var
   totals: TBreakdownTotals;
   xml: string;
begin
   BeginTest('Test_WRTCPostsItsMultipliersOnEveryAllModesRow');
   totals := Default(TBreakdownTotals);
   AddWork(totals, Band20, CW, 4, 8, rmDomestic);
   xml := BreakdownFor(WRTC, totals);
   CheckTrue(Pos('<mult band="20" mode="ALL" type="HQ">4</mult>', xml) > 0,
             'HQ on the band row, the all-modes row WRTC labels: ' + xml);
   CheckTrue(Pos('<mult band="total" mode="ALL" type="HQ">4</mult>', xml) > 0,
             'HQ on the summary: ' + xml);
end;

procedure TScoreBreakdownTests.Test_AnEmptyLogPostsTheQSOSummaryAlone;
begin
   BeginTest('Test_AnEmptyLogPostsTheQSOSummaryAlone');
   CheckEquals('<qso band="total" mode="ALL">0</qso>',
               BreakdownFor(RTC, Default(TBreakdownTotals)),
               'what a log with nothing in it has always posted');
end;

(* WHEN THE POSTED SCORE IS REBUILT.  The rebuild re-reads the whole log, so a
   burst of QSOs must not rebuild per QSO; a QSO logged after a quiet spell must
   still be in the next post, not wait for the heartbeat. *)
procedure TScoreBreakdownTests.Test_TheScoreIsRebuiltOnAChangeAtMostEveryMinInterval;
begin
   BeginTest('Test_TheScoreIsRebuiltOnAChangeAtMostEveryMinInterval');
   CheckFalse(ScoreRebuildDue(True, 0), 'the instant after a rebuild');
   CheckFalse(ScoreRebuildDue(True, SCORE_REBUILD_MIN_MS - 1), 'a burst coalesces');
   CheckTrue(ScoreRebuildDue(True, SCORE_REBUILD_MIN_MS), 'the first tick past the minimum');
   CheckTrue(ScoreRebuildDue(True, 10 * 60 * 1000), 'the first change after a quiet spell');
end;

procedure TScoreBreakdownTests.Test_TheScoreIsRebuiltOnTheHeartbeatWithNoChange;
begin
   BeginTest('Test_TheScoreIsRebuiltOnTheHeartbeatWithNoChange');
   CheckFalse(ScoreRebuildDue(False, SCORE_REBUILD_MIN_MS), 'no change, no rebuild');
   CheckFalse(ScoreRebuildDue(False, SCORE_REBUILD_HEARTBEAT_MS - 1), 'just short of the heartbeat');
   CheckTrue(ScoreRebuildDue(False, SCORE_REBUILD_HEARTBEAT_MS), 'the heartbeat');
   CheckTrue(ScoreRebuildDue(False, High(Int64)), 'never built is long ago');
end;

(* RTC 2026-11-01: MY GRID EL88pa saved, the contest's four-character EL88
   resolved, grid4 posted. The station's six characters win when they are the
   contest's square. *)
procedure TScoreBreakdownTests.Test_TheQthGridIsTheStationsSixCharactersWhenItIsTheSameSquare;
begin
   BeginTest('Test_TheQthGridIsTheStationsSixCharactersWhenItIsTheSameSquare');
   CheckEquals('EL88pa', QthGrid('EL88pa', 'EL88'), 'the RTC case');
   CheckEquals('EL88pa', QthGrid('EL88pa', 'el88'), 'case does not matter');
   CheckEquals('EL88pa', QthGrid('EL88pa', ''), 'the contest stated none');
   CheckEquals('EL88', QthGrid('EL88', 'EL88'), 'a four-character station grid');
   CheckEquals('EL88', QthGrid('', 'EL88'), 'no station grid');
   CheckEquals('FN20', QthGrid('EL88pa', 'FN20'), 'a different square is not the station');
   CheckEquals('', QthGrid('', ''), 'neither');
   CheckEquals('EL88pa', QthGrid('  EL88pa ', ' EL88 '), 'blanks are trimmed');
end;

procedure TScoreBreakdownTests.RunAllTests;
begin
   Test_RTCOneBandCWLogIsOneAllModesBandRowAndOneSummary;
   Test_NoRowNamesAModeOrAModeTotal;
   Test_TwoBandsGiveOneRowEachAndOneSummary;
   Test_AGridWorkedInTwoModesOnABandCountsOnce;
   Test_WRTCPostsItsMultipliersOnEveryAllModesRow;
   Test_AnEmptyLogPostsTheQSOSummaryAlone;
   Test_TheScoreIsRebuiltOnAChangeAtMostEveryMinInterval;
   Test_TheScoreIsRebuiltOnTheHeartbeatWithNoChange;
   Test_TheQthGridIsTheStationsSixCharactersWhenItIsTheSameSquare;
end;

end.
