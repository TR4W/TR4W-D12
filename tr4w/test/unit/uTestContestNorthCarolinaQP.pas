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

(* THE NORTH CAROLINA QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  NorthCarolina/NC-QSO-PARTY-Rules.txt; the test quotes the rule it holds.

  An NC entrant's multipliers are DATA, in nc.dom, read here through the
  real loader with its INCLUDEs. Until #88 round 3 that file wrote INCLUDE
  without FILE, which the loader skipped, so no US state and no province
  of P13 was a multiplier -- the frozen matrix showed "CT not in nc.dom". *)
unit uTestContestNorthCarolinaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNorthCarolinaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestRegistry,
   uTestQSOPartyRules;

(* "NC participants: Work 100 North Carolina Counties, 49 US States (not NC)
   plus DC, 13 Canadian Provinces/Territories (AB, BC, MB, NB, NL, NS, NT, NU,
   ON, PE, QC, SK, and YT), plus one DX." *)
procedure TContestNorthCarolinaQPTests.Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX;
const
   PROVINCES: array[0..12] of string =
      ('AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT');
var
   i: integer;
begin
   BeginTest('Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX');
   CheckEquals('nc', ContestIdentity(NCQSOPARTY).InStateDomesticFileName, 'nc.dom is the in-state file');

   (* "49 US States (not NC)" *)
   CheckEquals('CT', InStateMultiplierOf(NCQSOPARTY, 'CT'), 'Connecticut is a multiplier');
   CheckEquals('GA', InStateMultiplierOf(NCQSOPARTY, 'GA'), 'Georgia is a multiplier');
   CheckEquals('AK', InStateMultiplierOf(NCQSOPARTY, 'AK'), 'Alaska is');
   CheckEquals('HI', InStateMultiplierOf(NCQSOPARTY, 'HI'), 'Hawaii is');
   CheckEquals('LA', InStateMultiplierOf(NCQSOPARTY, 'LA'), 'LA is Louisiana, not Labrador');
   CheckEquals('', InStateMultiplierOf(NCQSOPARTY, 'NC'), 'North Carolina is NOT a multiplier');

   (* "plus DC" -- its own, not Maryland. *)
   CheckEquals('DC', InStateMultiplierOf(NCQSOPARTY, 'DC'), 'DC is its own multiplier');
   CheckEquals('MD', InStateMultiplierOf(NCQSOPARTY, 'MD'), 'and Maryland is Maryland');

   (* THE 13, EACH ITS OWN -- the old file merged NS, NB and PE into one and
      had no NU. *)
   for i := Low(PROVINCES) to High(PROVINCES) do
      begin
      CheckEquals(PROVINCES[i], InStateMultiplierOf(NCQSOPARTY, PROVINCES[i]),
                  PROVINCES[i] + ' is its own multiplier');
      end;
   CheckEquals('NL', InStateMultiplierOf(NCQSOPARTY, 'NF'), 'the old NF still means Newfoundland and Labrador');

   (* "plus one DX" and the 100 counties. *)
   CheckEquals('DX', InStateMultiplierOf(NCQSOPARTY, 'DX'), 'all DX is one multiplier');
   CheckEquals('ALA', InStateMultiplierOf(NCQSOPARTY, 'ALA'), 'Alamance County is a multiplier');
   CheckEquals('WAK', InStateMultiplierOf(NCQSOPARTY, 'WAK'), 'Wake County is');
end;

procedure TContestNorthCarolinaQPTests.RunAllTests;
begin
   Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX;
end;

end.
