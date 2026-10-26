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

(* THE TEXAS QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  Texas/TX-QSO-PARTY-Rules.txt; the test quotes the rule it holds:
  Texas is not one of a Texas entrant's state multipliers. *)
unit uTestContestTexasQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestTexasQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TexasIsNoStateMultiplierInState;
   end;

implementation

uses
   SysUtils,
   VC,
   uTestQSOPartyRules;

(* "Your multipliers are the number of states worked (not including Texas)
   plus the number of Texas counties worked plus each Canadian province
   worked (13 total) plus each DXCC country worked excluding USA, Canada,
   Alaska and Hawaii."
   texas.dom includes the shared S50.DOM, so it gives TX the
   multiplier TX; a Texas entrant's QSO with it earns none.
   Another state and a county still count, and outside Texas the
   rule is not asked. *)
procedure TContestTexasQPTests.Test_TexasIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_TexasIsNoStateMultiplierInState');
   host := InStateMultiplierOf(TEXASQSOPARTY, 'TX');
   CheckEquals('TX', host, 'texas.dom gives TX the multiplier TX (S50.DOM)');
   CheckFalse(CountsForEntrant(TEXASQSOPARTY, True, host, rmDomestic),
              'in state: Texas is no multiplier');
   CheckFalse(CountsForEntrant(TEXASQSOPARTY, True, 'Tx', rmDomestic),
              'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(TEXASQSOPARTY, True, InStateMultiplierOf(TEXASQSOPARTY, 'OK'), rmDomestic),
             'OK is');
   CheckTrue(CountsForEntrant(TEXASQSOPARTY, True, InStateMultiplierOf(TEXASQSOPARTY, 'ANDE'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(TEXASQSOPARTY, False, host, rmDomestic),
             'outside Texas the rule is not asked');
end;

procedure TContestTexasQPTests.RunAllTests;
begin
   Test_TexasIsNoStateMultiplierInState;
end;

end.
