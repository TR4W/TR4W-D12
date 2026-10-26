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

(* THE WASHINGTON STATE SALMON RUN'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  Washington/WA-SALMON-RUN-Rules.txt; each test quotes the rule it holds.

    * at most 10 DXCC multipliers, and only the DX kind is capped;
    * Washington is not one of a Washington entrant's 49 states.

  KH6 and KL7 are not pinned here: they count as a state AND as DX today,
  and the sponsor's "Alaska and Hawaii count as states" is not yet ruled
  on (#88). The W7DX bonus is pinned in uTestContestTotals. *)
unit uTestContestWashingtonSalmonRun;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestWashingtonSalmonRunTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_SalmonRunScoresAtMostTenDXMultipliers;
      procedure Test_SalmonRunWashingtonIsNoStateMultiplierInState;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uTestContestObjects,
   uTestQSOPartyRules;

(* "Up to 10 DXCC entities other than US and VE can be worked for multiplier
   credit." 9, 10 and 11 DX score 9, 10 and 10; the counties, states and
   provinces beside them all score. *)
procedure TContestWashingtonSalmonRunTests.Test_SalmonRunScoresAtMostTenDXMultipliers;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
   station: TStationContext;

   function ScoreAt(aDomestic: integer; aDX: integer): longint;
   begin
      t.Mults[AllBands, Both, rmDomestic] := aDomestic;
      t.Mults[AllBands, Both, rmDX] := aDX;
      Result := contestObject.FinalScore(t, view);
   end;

begin
   BeginTest('Test_SalmonRunScoresAtMostTenDXMultipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 200;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   station := WithHostAreaTable(NoStation);
   station.InHostState := True;
   station.MyState := 'KIN';
   view := TLoggedQSOList.Create;
   contestObject := Make(SALMONRUN, station);
   try
      CheckEquals(200 * (50 + 9), ScoreAt(50, 9), '9 DX: all scored');
      CheckEquals(200 * (50 + 10), ScoreAt(50, 10), '10 DX: all scored');
      CheckEquals(200 * (50 + 10), ScoreAt(50, 11), '11 DX: 10 scored');
      CheckEquals(200 * (101 + 10), ScoreAt(101, 25), 'counties, states and provinces are not capped');
      CheckEquals(0, ScoreAt(0, 0), 'no multiplier, no score');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* "US States less WA (49) -- District of Columbia counts as MD, Alaska and
   Hawaii count as states." washington.dom includes the shared S50.DOM, so
   it gives WA the multiplier WA; a Washington entrant's QSO with it earns
   none. Oregon and a county still count, and outside Washington the rule
   is not asked. *)
procedure TContestWashingtonSalmonRunTests.Test_SalmonRunWashingtonIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_SalmonRunWashingtonIsNoStateMultiplierInState');
   host := InStateMultiplierOf(SALMONRUN, 'WA');
   CheckEquals('WA', host, 'washington.dom gives WA the multiplier WA (S50.DOM)');
   CheckFalse(CountsForEntrant(SALMONRUN, True, host, rmDomestic), 'in state: Washington is no multiplier');
   CheckFalse(CountsForEntrant(SALMONRUN, True, 'Wa', rmDomestic), 'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(SALMONRUN, True, InStateMultiplierOf(SALMONRUN, 'OR'), rmDomestic),
             'Oregon is');
   CheckTrue(CountsForEntrant(SALMONRUN, True, InStateMultiplierOf(SALMONRUN, 'ADA'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(SALMONRUN, False, host, rmDomestic), 'outside Washington the rule is not asked');
end;

procedure TContestWashingtonSalmonRunTests.RunAllTests;
begin
   Test_SalmonRunScoresAtMostTenDXMultipliers;
   Test_SalmonRunWashingtonIsNoStateMultiplierInState;
end;

end.
