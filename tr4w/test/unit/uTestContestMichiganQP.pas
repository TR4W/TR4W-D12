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

(* THE MICHIGAN QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  Michigan/MI-QSO-PARTY-Rules.txt; the test quotes the rule it holds:
  Michigan is not one of a Michigan entrant's state multipliers. *)
unit uTestContestMichiganQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestMichiganQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_MichiganIsNoStateMultiplierInState;
   end;

implementation

uses
   SysUtils,
   VC,
   uTestQSOPartyRules;

(* "For Michigan stations, multipliers are the 83 Michigan counties, 49
   American states (excluding Michigan) + 1 District of Columbia, 13
   Canadian provinces ... and "DX" (a non-W/VE station)."
   michigan.dom includes the shared S51.DOM, so it gives MI the
   multiplier MI; a Michigan entrant's QSO with it earns none.
   Another state and a county still count, and outside Michigan the
   rule is not asked. *)
procedure TContestMichiganQPTests.Test_MichiganIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_MichiganIsNoStateMultiplierInState');
   host := InStateMultiplierOf(MICHQSOPARTY, 'MI');
   CheckEquals('MI', host, 'michigan.dom gives MI the multiplier MI (S51.DOM)');
   CheckFalse(CountsForEntrant(MICHQSOPARTY, True, host, rmDomestic),
              'in state: Michigan is no multiplier');
   CheckFalse(CountsForEntrant(MICHQSOPARTY, True, 'Mi', rmDomestic),
              'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(MICHQSOPARTY, True, InStateMultiplierOf(MICHQSOPARTY, 'OH'), rmDomestic),
             'OH is');
   CheckTrue(CountsForEntrant(MICHQSOPARTY, True, InStateMultiplierOf(MICHQSOPARTY, 'OAKL'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(MICHQSOPARTY, False, host, rmDomestic),
             'outside Michigan the rule is not asked');
   CheckEquals('DC', InStateMultiplierOf(MICHQSOPARTY, 'DC'),
               'the District of Columbia is its own multiplier (S51.DOM includes DC.DOM)');
end;

procedure TContestMichiganQPTests.RunAllTests;
begin
   Test_MichiganIsNoStateMultiplierInState;
end;

end.
