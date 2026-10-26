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

(* THE OHIO QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  Ohio/OH-QSO-PARTY-Rules.txt; the test quotes the rule it holds:
  Ohio is not one of a Ohio entrant's state multipliers. *)
unit uTestContestOhioQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestOhioQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OhioIsNoStateMultiplierInState;
   end;

implementation

uses
   SysUtils,
   VC,
   uTestQSOPartyRules;

(* "For OHIO STATIONS - multipliers are the 49 American States (excluding
   Ohio), 1 Washington DC, 11 Canadian Provinces (NL, PE, NS, NB,VE2-7, NT),
   88 Ohio Counties and 1 DX."
   ohio.dom includes the shared S50.DOM, so it gives OH the
   multiplier OH; a Ohio entrant's QSO with it earns none.
   Another state and a county still count, and outside Ohio the
   rule is not asked. *)
procedure TContestOhioQPTests.Test_OhioIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_OhioIsNoStateMultiplierInState');
   host := InStateMultiplierOf(OHIOQSOPARTY, 'OH');
   CheckEquals('OH', host, 'ohio.dom gives OH the multiplier OH (S50.DOM)');
   CheckFalse(CountsForEntrant(OHIOQSOPARTY, True, host, rmDomestic),
              'in state: Ohio is no multiplier');
   CheckFalse(CountsForEntrant(OHIOQSOPARTY, True, 'Oh', rmDomestic),
              'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(OHIOQSOPARTY, True, InStateMultiplierOf(OHIOQSOPARTY, 'MI'), rmDomestic),
             'MI is');
   CheckTrue(CountsForEntrant(OHIOQSOPARTY, True, InStateMultiplierOf(OHIOQSOPARTY, 'ADAM'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(OHIOQSOPARTY, False, host, rmDomestic),
             'outside Ohio the rule is not asked');
end;

procedure TContestOhioQPTests.RunAllTests;
begin
   Test_OhioIsNoStateMultiplierInState;
end;

end.
