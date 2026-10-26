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

(* THE VIRGINIA QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  Virginia/VA-QSO-PARTY-Rules.txt; the test quotes the rule it holds:
  Virginia is not one of a Virginia entrant's state multipliers. *)
unit uTestContestVirginiaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestVirginiaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_VirginiaIsNoStateMultiplierInState;
   end;

implementation

uses
   SysUtils,
   VC,
   uTestQSOPartyRules;

(* "Virginia Mobile, Rover, Expedition, and Fixed Station multipliers are
   the total number of Virginia counties, Virginia Independent cities, U.
   S. States (except Virginia), Canadian Provinces, and DX entities."
   va.dom includes the shared S50.DOM, so it gives VA the
   multiplier VA; a Virginia entrant's QSO with it earns none.
   Another state and a county still count, and outside Virginia the
   rule is not asked. *)
procedure TContestVirginiaQPTests.Test_VirginiaIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_VirginiaIsNoStateMultiplierInState');
   host := InStateMultiplierOf(VAQP, 'VA');
   CheckEquals('VA', host, 'va.dom gives VA the multiplier VA (S50.DOM)');
   CheckFalse(CountsForEntrant(VAQP, True, host, rmDomestic),
              'in state: Virginia is no multiplier');
   CheckFalse(CountsForEntrant(VAQP, True, 'Va', rmDomestic),
              'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(VAQP, True, InStateMultiplierOf(VAQP, 'NC'), rmDomestic),
             'NC is');
   CheckTrue(CountsForEntrant(VAQP, True, InStateMultiplierOf(VAQP, 'ACC'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(VAQP, False, host, rmDomestic),
             'outside Virginia the rule is not asked');
end;

procedure TContestVirginiaQPTests.RunAllTests;
begin
   Test_VirginiaIsNoStateMultiplierInState;
end;

end.
