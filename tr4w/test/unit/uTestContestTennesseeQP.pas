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
      procedure Test_TennesseePointsAreThreeInEveryMode;
      procedure Test_TennesseeBands;
      procedure Test_TennesseeCountyLineIsTwo;
      procedure Test_TennesseeK4TCGBonus;
      procedure Test_TennesseeRealEngineTakesDXInStateOnly;
      procedure Test_TennesseeRefusesTheFTModes;
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

(* "3 points per QSO regardless of mode." *)
procedure TContestTennesseeQPTests.Test_TennesseePointsAreThreeInEveryMode;
var
   inState: boolean;
begin
   BeginTest('Test_TennesseePointsAreThreeInEveryMode');
   for inState := False to True do
      begin
      CheckEquals(3, PartyPoints(TENNESSEEQSOPARTY, inState, Band20, CW, eCW), 'CW is 3');
      CheckEquals(3, PartyPoints(TENNESSEEQSOPARTY, inState, Band20, Phone, eSSB), 'phone is 3');
      CheckEquals(3, PartyPoints(TENNESSEEQSOPARTY, inState, Band2, FM, eFM), 'FM is 3');
      CheckEquals(3, PartyPoints(TENNESSEEQSOPARTY, inState, Band40, Digital, eRTTY), 'digital is 3');
      end;
end;

(* "All amateur bands are valid, with the exception of 60, 30, 17 and 12
   meters." *)
procedure TContestTennesseeQPTests.Test_TennesseeBands;
var
   identity: TContestBase;
   b: BandType;
begin
   BeginTest('Test_TennesseeBands');
   identity := ContestIdentity(TENNESSEEQSOPARTY);
   CheckTrue(identity.VHFBandsEnabled, 'the VHF bands can be reached');
   for b := Low(BandType) to High(BandType) do
      begin
      if not (b in [AllBands, NoBand]) then
         begin
         CheckTrue(identity.UsesBand(b) = not (b in [Band30, Band17, Band12]),
                   'band ' + IntToStr(Ord(b)) + ' is credited exactly when it is not WARC');
         end;
      end;
   CheckEquals(3, PartyPoints(TENNESSEEQSOPARTY, True, Band6, CW, eCW), '6 m scores');
   CheckEquals(0, PartyPoints(TENNESSEEQSOPARTY, True, Band30, CW, eCW), '30 m scores nothing');
end;

(* "Three and four county lines may not be run simultaneously" -- two. *)
procedure TContestTennesseeQPTests.Test_TennesseeCountyLineIsTwo;
var
   contestObject: TContestBase;
   msg: string;
begin
   BeginTest('Test_TennesseeCountyLineIsTwo');
   contestObject := Make(TENNESSEEQSOPARTY);
   try
      CheckEquals(2, (contestObject as TContestStateQSOPartyBase).CountyLineCountiesMax, 'two counties');
      CheckTrue((contestObject as TContestStateQSOPartyBase).ValidateQTHCount(2, msg), 'a county line');
      CheckFalse((contestObject as TContestStateQSOPartyBase).ValidateQTHCount(3, msg), 'not a three-county point');
   finally
      contestObject.Free;
   end;
end;

(* "All entrants may claim 100 bonus points for each QSO (one per band/mode)
   with TCG headquarters station K4TCG ... added after the geographic
   multiplier." Dupes and X-QSOs pay nothing; another call is not K4TCG. *)
procedure TContestTennesseeQPTests.Test_TennesseeK4TCGBonus;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
   dupe: ContestExchange;
begin
   BeginTest('Test_TennesseeK4TCGBonus');
   t := Default(TScoreTotals);
   view := TLoggedQSOList.Create;
   contestObject := Make(TENNESSEEQSOPARTY, WithHostAreaTable(NoStation));
   try
      CheckEquals(0, contestObject.BonusPoints(t, view), 'an empty log');
      view.Add(PartyQso('K4TCG', Band20, CW, eCW));
      CheckEquals(100, contestObject.BonusPoints(t, view), '20 m CW: 100');
      view.Add(PartyQso('K4TCG', Band20, CW, eCW));
      CheckEquals(100, contestObject.BonusPoints(t, view), '20 m CW again: still 100');
      view.Add(PartyQso('K4TCG', Band20, Phone, eUSB));
      CheckEquals(200, contestObject.BonusPoints(t, view), '20 m phone: 200');
      view.Add(PartyQso('K4TCG', Band40, CW, eCW));
      CheckEquals(300, contestObject.BonusPoints(t, view), '40 m CW: 300');
      view.Add(PartyQso('K4TCG', Band30, CW, eCW));
      CheckEquals(300, contestObject.BonusPoints(t, view), 'a WARC QSO is an X-QSO: nothing');
      dupe := PartyQso('K4TCG', Band15, CW, eCW);
      dupe.ceDupe := True;
      view.Add(dupe);
      CheckEquals(300, contestObject.BonusPoints(t, view), 'a dupe pays nothing');
      view.Add(PartyQso('K4TCGX', Band10, CW, eCW));
      CheckEquals(300, contestObject.BonusPoints(t, view), 'another call pays nothing');
      t.QSOPoints := 90;
      t.ScoredBand := AllBands;
      t.SessionCountsMultipliers := True;
      t.Mults[AllBands, Both, rmDomestic] := 10;
      CheckEquals(90 * 10 + 300, contestObject.FinalScore(t, view), 'the bonus is added last');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* "RS(T) and Tennessee County, U.S. state, Canadian province/territory, or
   DXCC entity"; "DXCC entities (... less USA, Canada, Alaska & Hawaii)" are
   a Tennessee entrant's multipliers, and "Stations outside of Tennessee work
   only Tennessee stations". The typed "599 DL" goes through the real engine. *)
procedure TContestTennesseeQPTests.Test_TennesseeRealEngineTakesDXInStateOnly;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_TennesseeRealEngineTakesDXInStateOnly');
   engine := TQSOPartyEngine.Create(ContestHandleOf(TENNESSEEQSOPARTY));
   try
      engine.Activate(True);
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a Tennessee entrant logs a DX country');
      CheckTrue(rx.DXMult, 'its entity is a DXCC multiplier');
      CheckEquals(3, Integer(rx.QSOPoints), 'for 3 points');
      CheckEquals('599 DL     ', PartyReceivedCabrilloColumn(ContestHandleOf(TENNESSEEQSOPARTY), rx),
                  'and the received column is the country, not empty');
      engine.Enter('KL7AA', '599 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Alaska is a state');
      CheckFalse(rx.DXMult, 'and no DX entity');
      engine.Activate(False);
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'an entrant outside Tennessee cannot work DX');
   finally
      engine.Free;
   end;
end;

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

(* "Phone-SSB, FM (no repeater QSOs) / CW / Digital (Any digital mode that
   supports the required exchange)" -- NY4I, 2026-11-20: "That phrase about
   supporting the exchange means FT8, FT4 nor FT2 are allowed." Every mode
   and submode is walked; an FT QSO is an automatic X-QSO and scores
   nothing, any other digital QSO scores its 3. *)
procedure TContestTennesseeQPTests.Test_TennesseeRefusesTheFTModes;
var
   identity: TContestBase;
   mode: ModeType;
   ext: ExtendedModeType;
   credited: boolean;
   qso: ContestExchange;
   inState: boolean;
begin
   BeginTest('Test_TennesseeRefusesTheFTModes');
   identity := ContestIdentity(TENNESSEEQSOPARTY);
   for mode := Low(ModeType) to High(ModeType) do
      begin
      for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
         begin
         credited := (mode in [CW, Phone, FM]) or
                     ((mode = Digital) and not (ext in [eFT8, eFT4, eFT2]));
         CheckTrue(identity.UsesMode(mode, ext) = credited,
                   ModeStringArray[mode] + '/' + ExtendedModeStringArray[ext] +
                   ': CW, phone, FM and every digital mode but FT8/FT4/FT2');
         end;
      end;
   qso := Default(ContestExchange);
   qso.ceRecordKind := rkQSO;
   qso.Band := Band20;
   qso.Mode := Digital;
   qso.ExtMode := eFT8;
   CheckTrue(QSOIsXQSO(identity, qso), 'FT8 is an X-QSO');
   qso.ExtMode := eFT2;
   CheckTrue(QSOIsXQSO(identity, qso), 'FT2 is');
   qso.ExtMode := eJS8;
   CheckFalse(QSOIsXQSO(identity, qso), 'JS8 is not');
   for inState := False to True do
      begin
      CheckEquals(0, PartyPoints(TENNESSEEQSOPARTY, inState, Band20, Digital, eFT8), 'FT8 scores nothing');
      CheckEquals(0, PartyPoints(TENNESSEEQSOPARTY, inState, Band20, Digital, eFT4), 'FT4 scores nothing');
      CheckEquals(3, PartyPoints(TENNESSEEQSOPARTY, inState, Band20, Digital, ePSK31), 'PSK31 is 3');
      end;
end;

procedure TContestTennesseeQPTests.RunAllTests;
begin
   Test_TennesseeRefusesTheFTModes;
   Test_TennesseeIsNoStateMultiplierInState;
   Test_TennesseePointsAreThreeInEveryMode;
   Test_TennesseeBands;
   Test_TennesseeCountyLineIsTwo;
   Test_TennesseeK4TCGBonus;
   Test_TennesseeRealEngineTakesDXInStateOnly;
end;

end.
