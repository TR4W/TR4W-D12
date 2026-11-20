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
      procedure Test_TexasPoints;
      procedure Test_TexasBandsAndModes;
      procedure Test_TexasRealEngineDXColumn;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestQSOPartyEngine,
   uTestQSOPartyRules;

(* "Count two (2) points per phone QSO ... Count three (3) points per CW and
   other digital mode QSOs." FM is a voice mode. *)
procedure TContestTexasQPTests.Test_TexasPoints;
var
   inState: boolean;
begin
   BeginTest('Test_TexasPoints');
   for inState := False to True do
      begin
      CheckEquals(3, PartyPoints(TEXASQSOPARTY, inState, Band20, CW, eCW), 'CW is 3');
      CheckEquals(3, PartyPoints(TEXASQSOPARTY, inState, Band40, Digital, eRTTY), 'RTTY is 3');
      CheckEquals(3, PartyPoints(TEXASQSOPARTY, inState, Band40, Digital, eJT65), 'JT65 is 3');
      CheckEquals(2, PartyPoints(TEXASQSOPARTY, inState, Band20, Phone, eSSB), 'phone is 2');
      CheckEquals(2, PartyPoints(TEXASQSOPARTY, inState, Band2, FM, eFM), 'FM is voice: 2');
      end;
end;

(* "Operation on all Amateur bands is permitted, except on 60 meters, 30
   meters, 17 meters and 12 meters." "Digital modes must be capable of
   sending and receiving the full contest exchange" -- every digital submode
   but FT8, FT4 and FT2 (NY4I, issues 88 and 122). *)
procedure TContestTexasQPTests.Test_TexasBandsAndModes;
var
   identity: TContestBase;
   b: BandType;
   ext: ExtendedModeType;
begin
   BeginTest('Test_TexasBandsAndModes');
   identity := ContestIdentity(TEXASQSOPARTY);
   CheckTrue(identity.VHFBandsEnabled, 'the VHF bands can be reached');
   for b := Low(BandType) to High(BandType) do
      begin
      if not (b in [AllBands, NoBand]) then
         begin
         CheckTrue(identity.UsesBand(b) = not (b in [Band30, Band17, Band12]),
                   'band ' + IntToStr(Ord(b)) + ' is credited exactly when it is not WARC');
         end;
      end;
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckTrue(ContestCreditsMode(identity, Digital, ext) = not (ext in [eFT8, eFT4, eFT2]),
                'digital submode ' + IntToStr(Ord(ext)) + ' credited unless an FT mode');
      end;
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited');
   CheckEquals(0, PartyPoints(TEXASQSOPARTY, True, Band20, Digital, eFT8), 'an FT8 QSO scores 0');
   CheckEquals(0, PartyPoints(TEXASQSOPARTY, True, Band17, CW, eCW), '17 m scores 0');
end;

(* A Texas entrant's DX station sends its prefix; the received Cabrillo
   column is that entity. CabrilloReceivedRSTQTHOrDXQTH printed an empty
   column for it (HisQTH is empty unless LITERAL DOMESTIC QTH). *)
procedure TContestTexasQPTests.Test_TexasRealEngineDXColumn;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_TexasRealEngineDXColumn');
   engine := TQSOPartyEngine.Create(ContestHandleOf(TEXASQSOPARTY));
   try
      engine.Activate(True);
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a Texas entrant logs a DX country');
      CheckEquals('599 DL     ', PartyReceivedCabrilloColumn(ContestHandleOf(TEXASQSOPARTY), rx),
                  'the received column is the country');
   finally
      engine.Free;
   end;
end;

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
   Test_TexasPoints;
   Test_TexasBandsAndModes;
   Test_TexasRealEngineDXColumn;
end;

end.
