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
      procedure Test_VirginiaPointsAndModes;
      procedure Test_VirginiaBands;
      procedure Test_VirginiaCountyLineIsOneQSO;
      procedure Test_VirginiaRealEngineDX;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uContestStateQSOPartyBase,
   uTestContestObjects,
   uTestQSOPartyEngine,
   uTestQSOPartyRules;

(* "QSO's count 1 point per Phone, 2 points per CW, 2 points per digital
   mode (RTTY, PSK31,etc.)". FM is phone. Every mode is credited. *)
procedure TContestVirginiaQPTests.Test_VirginiaPointsAndModes;
var
   identity: TContestBase;
   inState: boolean;
begin
   BeginTest('Test_VirginiaPointsAndModes');
   identity := ContestIdentity(VAQP);
   for inState := False to True do
      begin
      CheckEquals(1, PartyPoints(VAQP, inState, Band20, Phone, eSSB), 'phone is 1');
      CheckEquals(1, PartyPoints(VAQP, inState, Band2, FM, eFM), 'FM is phone: 1');
      CheckEquals(2, PartyPoints(VAQP, inState, Band20, CW, eCW), 'CW is 2');
      CheckEquals(2, PartyPoints(VAQP, inState, Band20, Digital, eRTTY), 'RTTY is 2');
      CheckEquals(2, PartyPoints(VAQP, inState, Band20, Digital, eFT8), 'FT8 is a digital mode: 2');
      end;
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eSSB), 'phone credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eFT8), 'digital credited');
end;

(* "160 meters and up, except no WARC band QSO's permitted." *)
procedure TContestVirginiaQPTests.Test_VirginiaBands;
var
   identity: TContestBase;
   b: BandType;
begin
   BeginTest('Test_VirginiaBands');
   identity := ContestIdentity(VAQP);
   CheckTrue(identity.VHFBandsEnabled, 'the VHF bands can be reached');
   for b := Low(BandType) to High(BandType) do
      begin
      if not (b in [AllBands, NoBand]) then
         begin
         CheckTrue(identity.UsesBand(b) = not (b in [Band30, Band17, Band12]),
                   'band ' + IntToStr(Ord(b)) + ' is credited exactly when it is not WARC');
         end;
      end;
   CheckEquals(0, PartyPoints(VAQP, True, Band12, CW, eCW), '12 m scores 0');
   CheckEquals(2, PartyPoints(VAQP, True, Band6, CW, eCW), '6 m scores');
end;

(* "Stations on County or Independent City lines count as one QSO and one
   County/Independent City multiplier." *)
procedure TContestVirginiaQPTests.Test_VirginiaCountyLineIsOneQSO;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_VirginiaCountyLineIsOneQSO');
   contestObject := Make(VAQP);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(0, party.CountyLineCountiesMax, 'no county line');
      CheckTrue(party.ValidateQTHCount(1, msg), 'one county');
      CheckFalse(party.ValidateQTHCount(2, msg), 'two are refused');
   finally
      contestObject.Free;
   end;
end;

(* "Virginia ... multipliers are ... DX entities. No extra DX multiplier for
   U.S. (including Alaska and Hawaii), Virginia, and Canada." In state only;
   the received column of a DX station is DX ("State, Province or "DX" for
   others"). *)
procedure TContestVirginiaQPTests.Test_VirginiaRealEngineDX;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_VirginiaRealEngineDX');
   engine := TQSOPartyEngine.Create(ContestHandleOf(VAQP));
   try
      engine.Activate(True);
      engine.Enter('DL1AAA', '12 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a Virginia entrant logs a DX country');
      CheckTrue(rx.DXMult, 'its entity is a DXCC multiplier');
      CheckEquals('0012 DX', Trim(PartyReceivedCabrilloColumn(ContestHandleOf(VAQP), rx)),
                  'and the received column says DX');
      engine.Enter('KL7AA', '13 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Alaska is a state');
      CheckFalse(rx.DXMult, 'and no DX entity');
      engine.Activate(False);
      engine.Enter('DL1AAA', '14 DL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'an entrant outside Virginia cannot work DX');
   finally
      engine.Free;
   end;
end;

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
   Test_VirginiaPointsAndModes;
   Test_VirginiaBands;
   Test_VirginiaCountyLineIsOneQSO;
   Test_VirginiaRealEngineDX;
end;

end.
