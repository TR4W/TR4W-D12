(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* THE 7TH CALL AREA QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  SeventhCallArea/7QP-Rules.txt; each test quotes the rule it holds.

    * at most 10 DX multipliers, and only the DX kind is capped;
    * a mobile's bare call in a new county is a new QSO, the same county
      again is a dupe;
    * the states are "50" -- a 7th-area state is a multiplier for a
      7th-area entrant (the host-state rule of the single-state parties is
      not the 7QP's). *)
unit uTestContestSevenQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestSevenQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_SevenQPScoresAtMostTenDXMultipliers;
      procedure Test_SevenQPMobileInANewCountyIsANewQSO;
      procedure Test_SevenQPCountsItsOwnStates;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestQSOPartyRules;

function Entrant(aInArea: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInArea;
   if aInArea then
      begin
      Result.MyState := 'Azaph';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

(* "7th-area stations multiply total QSO points by the total of states (50),
   provinces (13) and other DXCC entities (maximum of 10) worked." The cap
   is on the DX entities alone: 9, 10 and 11 DX score 9, 10 and 10, and the
   states and provinces beside them all score. *)
procedure TContestSevenQPTests.Test_SevenQPScoresAtMostTenDXMultipliers;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;

   function ScoreAt(aDomestic: integer; aDX: integer): longint;
   begin
      t.Mults[AllBands, Both, rmDomestic] := aDomestic;
      t.Mults[AllBands, Both, rmDX] := aDX;
      Result := contestObject.FinalScore(t, view);
   end;

begin
   BeginTest('Test_SevenQPScoresAtMostTenDXMultipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 300;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   view := TLoggedQSOList.Create;
   contestObject := Make(SEVENQP, Entrant(True));
   try
      CheckEquals(300 * (40 + 9), ScoreAt(40, 9), '9 DX: all scored');
      CheckEquals(300 * (40 + 10), ScoreAt(40, 10), '10 DX: all scored');
      CheckEquals(300 * (40 + 10), ScoreAt(40, 11), '11 DX: 10 scored');
      CheckEquals(300 * (40 + 10), ScoreAt(40, 30), '30 DX: 10 scored');
      CheckEquals(300 * (63 + 10), ScoreAt(63, 11), 'the 63 states and provinces are not capped');
      CheckEquals(300 * 10, ScoreAt(0, 12), 'DX alone: 10');
      CheckEquals(0, ScoreAt(0, 0), 'no multiplier, no score');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* "7th-area mobiles (and those participating in other concurrent QSO
   parties or contests) may be worked again as they enter new counties."
   The mobile signs its BARE call, so only the county it sends tells its
   QSOs apart -- through the dupe path LogContact takes. Until #88 round 3
   the 7QP's dupe key was the call alone, and the new county was a dupe. *)
procedure TContestSevenQPTests.Test_SevenQPMobileInANewCountyIsANewQSO;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_SevenQPMobileInANewCountyIsANewQSO');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(SEVENQP)),
             'the received county is part of the 7QP dupe key');
   RoverDupeAnswers(SEVENQP, 'W7XYZ', 'Azaph', 'Azcno', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'the mobile from a new county, same band and mode, is NOT a dupe');
   CheckTrue(sameCountyIsDupe, 'the first county again IS a dupe');
end;

(* "the total of states (50)" -- a 7th-area entrant counts Arizona as it
   counts Kansas. seven.dom maps a county to its state (Azaph > Az). *)
procedure TContestSevenQPTests.Test_SevenQPCountsItsOwnStates;
begin
   BeginTest('Test_SevenQPCountsItsOwnStates');
   CheckEquals('AZ', InStateMultiplierOf(SEVENQP, 'AZAPH'), 'an Arizona county counts as Arizona');
   CheckTrue(CountsForEntrant(SEVENQP, True, 'Az', rmDomestic), 'and Arizona is a multiplier in the area');
   CheckTrue(CountsForEntrant(SEVENQP, True, 'Ks', rmDomestic), 'as Kansas is');
end;

procedure TContestSevenQPTests.RunAllTests;
begin
   Test_SevenQPScoresAtMostTenDXMultipliers;
   Test_SevenQPMobileInANewCountyIsANewQSO;
   Test_SevenQPCountsItsOwnStates;
end;

end.
