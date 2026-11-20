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
      procedure Test_BandsAndModesAreTheSponsors;
      procedure Test_TheThirteenProvincesAndDX;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
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

(* "CW and SSB on 80, 40, 20, 15 and 10 meters." / "All categories are
   all-band (80m-10m)" / "All categories are mixed-mode (CW,SSB)": five
   bands, CW, and phone as SSB. No digital mode, no 160 m, no WARC, no 6 m. *)
procedure TContestMichiganQPTests.Test_BandsAndModesAreTheSponsors;
var
   identity: TContestBase;
   band: BandType;
begin
   BeginTest('Test_MichiganBandsAndModesAreTheSponsors');
   identity := ContestIdentity(ContestHandleOf(MICHQSOPARTY));
   for band := Low(BandType) to High(BandType) do
      begin
      CheckTrue(identity.UsesBand(band) = (band in [Band80, Band40, Band20, Band15, Band10]),
                'only 80, 40, 20, 15 and 10 m, band ' + IntToStr(Ord(band)));
      end;
   CheckTrue(identity.UsesMode(CW, eCW), 'CW');
   CheckTrue(identity.UsesMode(CW, eNoMode), 'CW, submode unknown');
   CheckTrue(identity.UsesMode(Phone, eUSB), 'SSB');
   CheckTrue(identity.UsesMode(Phone, eNoMode), 'phone with no submode is not proven off-mode');
   CheckFalse(identity.UsesMode(Phone, eAM), 'AM is not SSB');
   CheckFalse(identity.UsesMode(FM, eFM), 'FM is not SSB');
   CheckFalse(identity.UsesMode(Digital, eRTTY), 'no digital: RTTY');
   CheckFalse(identity.UsesMode(Digital, eFT8), 'no digital: FT8');
   CheckFalse(identity.UsesMode(Digital, eNoMode), 'no digital: unknown submode');
end;

(* "For Michigan stations, multipliers are ... 13 Canadian provinces (NL, NB,
   NS, PE, QC, ON, MB, SK, AB, BC, NT, YT, NU), and "DX"." The in-state file
   gives each province ONE multiplier under the sponsor's own two letters,
   whatever alias was typed: the sponsor's NL, PE and NU were unknown to it,
   and Labrador (VO2, LAB) was a second multiplier beside Newfoundland. *)
procedure TContestMichiganQPTests.Test_TheThirteenProvincesAndDX;
const
   PROVINCES: array[0..12] of string = ('NL', 'NB', 'NS', 'PE', 'QC', 'ON', 'MB',
                                       'SK', 'AB', 'BC', 'NT', 'YT', 'NU');
var
   i: integer;
begin
   BeginTest('Test_MichiganTheThirteenProvincesAndDX');
   for i := Low(PROVINCES) to High(PROVINCES) do
      begin
      CheckEquals(PROVINCES[i], UpperCase(InStateMultiplierOf(MICHQSOPARTY, PROVINCES[i])),
                  'the sponsor''s own ' + PROVINCES[i] + ' is its multiplier');
      end;
   CheckEquals('NL', UpperCase(InStateMultiplierOf(MICHQSOPARTY, 'LAB')),
               'Labrador is Newfoundland and Labrador, not a 14th province');
   CheckEquals('NL', UpperCase(InStateMultiplierOf(MICHQSOPARTY, 'VO2')), 'VO2 too');
   CheckEquals('NL', UpperCase(InStateMultiplierOf(MICHQSOPARTY, 'NF')), 'NF too');
   CheckEquals('NT', UpperCase(InStateMultiplierOf(MICHQSOPARTY, 'VE8')), 'a call prefix still resolves');
   CheckEquals('DX', UpperCase(InStateMultiplierOf(MICHQSOPARTY, 'DX')), 'the one DX multiplier');
end;

procedure TContestMichiganQPTests.RunAllTests;
begin
   Test_MichiganIsNoStateMultiplierInState;
   Test_BandsAndModesAreTheSponsors;
   Test_TheThirteenProvincesAndDX;
end;

end.
