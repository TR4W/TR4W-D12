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

(* THE TENNESSEE QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  Tennessee/TN-QSO-PARTY-Rules.txt; the test quotes the rule it holds:
  Tennessee is not one of a Tennessee entrant's state multipliers. *)
unit uTestContestTennesseeQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestTennesseeQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TennesseeIsNoStateMultiplierInState;
   end;

implementation

uses
   SysUtils,
   VC,
   uTestQSOPartyRules;

(* "Tennessee Stations - Multipliers accumulate on a per band basis.
   Multipliers are: Tennessee counties (95 max/band) U.S. states (49
   max/band - do not count Tennessee as a state, District of Columbia
   counts as Maryland)"
   tennessee.dom includes the shared S50.DOM, so it gives TN the
   multiplier TN; a Tennessee entrant's QSO with it earns none.
   Another state and a county still count, and outside Tennessee the
   rule is not asked. *)
procedure TContestTennesseeQPTests.Test_TennesseeIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_TennesseeIsNoStateMultiplierInState');
   host := InStateMultiplierOf(TENNESSEEQSOPARTY, 'TN');
   CheckEquals('TN', host, 'tennessee.dom gives TN the multiplier TN (S50.DOM)');
   CheckFalse(CountsForEntrant(TENNESSEEQSOPARTY, True, host, rmDomestic),
              'in state: Tennessee is no multiplier');
   CheckFalse(CountsForEntrant(TENNESSEEQSOPARTY, True, 'Tn', rmDomestic),
              'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(TENNESSEEQSOPARTY, True, InStateMultiplierOf(TENNESSEEQSOPARTY, 'KY'), rmDomestic),
             'KY is');
   CheckTrue(CountsForEntrant(TENNESSEEQSOPARTY, True, InStateMultiplierOf(TENNESSEEQSOPARTY, 'ANDE'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(TENNESSEEQSOPARTY, False, host, rmDomestic),
             'outside Tennessee the rule is not asked');
end;

procedure TContestTennesseeQPTests.RunAllTests;
begin
   Test_TennesseeIsNoStateMultiplierInState;
end;

end.
