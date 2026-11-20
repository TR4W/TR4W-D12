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

  KH6 and KL7 are states, not DX (2026-11-20: "Alaska and Hawaii count as
  states"; the key is pinned in uTestDXMultiplierKey). The W7DX bonus is
  pinned in uTestContestTotals and, off the contest bands, here. *)
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
      procedure Test_SalmonRunBands;
      procedure Test_SalmonRunW7DXNeedsAContestBand;
      procedure Test_SalmonRunRealEngineDX;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestQSOPartyEngine,
   uTestQSOPartyRules;

(* "Contest Bands: 160, 80, 40, 20, 15, 10, and 6 meters. No contacts on 60,
   30, 17, or 12 meters are allowed." *)
procedure TContestWashingtonSalmonRunTests.Test_SalmonRunBands;
var
   identity: TContestBase;
   b: BandType;
begin
   BeginTest('Test_SalmonRunBands');
   identity := ContestIdentity(SALMONRUN);
   CheckTrue(identity.VHFBandsEnabled, '6 m can be reached');
   for b := Low(BandType) to High(BandType) do
      begin
      if not (b in [AllBands, NoBand]) then
         begin
         CheckTrue(identity.UsesBand(b) = (b in [Band160, Band80, Band40, Band20, Band15, Band10, Band6]),
                   'band ' + IntToStr(Ord(b)) + ' is credited exactly on the contest bands');
         end;
      end;
   CheckEquals(3, PartyPoints(SALMONRUN, True, Band6, CW, eCW), '6 m CW scores');
   CheckEquals(0, PartyPoints(SALMONRUN, True, Band30, CW, eCW), '30 m scores nothing');
   CheckEquals(0, PartyPoints(SALMONRUN, True, Band2, CW, eCW), '2 m scores nothing');
end;

(* "A QSO with ... W7DX, will add a 500-point bonus for each mode": a QSO on
   a band the contest does not allow is no QSO at all. *)
procedure TContestWashingtonSalmonRunTests.Test_SalmonRunW7DXNeedsAContestBand;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
begin
   BeginTest('Test_SalmonRunW7DXNeedsAContestBand');
   t := Default(TScoreTotals);
   view := TLoggedQSOList.Create;
   contestObject := Make(SALMONRUN, WithHostAreaTable(NoStation));
   try
      view.Add(PartyQso('W7DX', Band30, CW, eCW));
      CheckEquals(0, contestObject.BonusPoints(t, view), 'a 30 m W7DX QSO pays nothing');
      view.Add(PartyQso('W7DX', Band20, CW, eCW));
      CheckEquals(500, contestObject.BonusPoints(t, view), 'a 20 m CW one pays 500');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* "Up to 10 DXCC entities other than US and VE": a Washington entrant's DX
   station sends its prefix, which is its received column; Alaska and Hawaii
   "count as states", not as DX entities. *)
procedure TContestWashingtonSalmonRunTests.Test_SalmonRunRealEngineDX;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_SalmonRunRealEngineDX');
   engine := TQSOPartyEngine.Create(ContestHandleOf(SALMONRUN));
   try
      engine.Activate(True);
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a Washington entrant logs a DX country');
      CheckTrue(rx.DXMult, 'its entity is a DXCC multiplier');
      CheckEquals('599 DL     ', PartyReceivedCabrilloColumn(ContestHandleOf(SALMONRUN), rx),
                  'the received column is the country');
      engine.Enter('KH6AA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Hawaii is a state');
      CheckFalse(rx.DXMult, 'and no DX entity');
   finally
      engine.Free;
   end;
end;

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
   Test_SalmonRunBands;
   Test_SalmonRunW7DXNeedsAContestBand;
   Test_SalmonRunRealEngineDX;
end;

end.
