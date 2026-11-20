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

(* THE PENNSYLVANIA QSO PARTY'S 2026 RULES (revision 09/20/26). The
  sponsor's text is docs/ContestRules/QSOParties/Pennslyvania/PAQSO_Rules.md
  (converted from PAQSO_Rules.pdf); each test quotes the rule it holds. *)
unit uTestContestPennsylvaniaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestPennsylvaniaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_InStateFileTakesSectionsNotStates;
      procedure Test_OutOfStateFileHoldsOnlyCounties;
      procedure Test_BandsAndModes;
      procedure Test_Points;
      procedure Test_QRPDoublesThePoints;
      procedure Test_BonusStationIsA2026Rule;
      procedure Test_AdifStateOfASection;
      procedure Test_DXEntrantSendsDX;
   end;

implementation

uses
   (* cpQRP. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestQSOPartyRules;

function PAIdentity: TContestBase;
begin
   Result := ContestIdentity(ContestHandleOf(PAQSOPARTY));
end;

(* "5.a. Sequential serial number plus PA county, ARRL section, Canadian
   section, or DX." An in-state station may log all of them; the shared
   S50.DOM and P13.DOM the file used to include know states and provinces
   (TX, ON), which are not the sponsor's abbreviations. *)
procedure TContestPennsylvaniaQPTests.Test_InStateFileTakesSectionsNotStates;
var
   i: integer;
const
   ACCEPTED: array[0 .. 15] of string =
      ('ADA', 'YOR', 'NTX', 'STX', 'WTX', 'WNY', 'NNJ', 'NFL', 'MDC', 'EPA',
       'WCF', 'ONS', 'GH', 'ONE', 'TER', 'DX');
   REFUSED: array[0 .. 3] of string = ('TX', 'ON', 'FL', 'NJ');
begin
   BeginTest('Test_InStateFileTakesSectionsNotStates');
   for i := Low(ACCEPTED) to High(ACCEPTED) do
      begin
      CheckTrue(InStateMultiplierOf(PAQSOPARTY, ACCEPTED[i]) <> '',
                ACCEPTED[i] + ' is a county, a section or DX');
      end;
   for i := Low(REFUSED) to High(REFUSED) do
      begin
      CheckEquals('', InStateMultiplierOf(PAQSOPARTY, REFUSED[i]),
                  REFUSED[i] + ' is a state or province, not an abbreviation of rule 5.b');
      end;
   CheckTrue(CountsForEntrant(PAQSOPARTY, True, InStateMultiplierOf(PAQSOPARTY, 'NTX'), rmDomestic),
             'a section counts for an in-state entrant (10.a)');
   CheckTrue(CountsForEntrant(PAQSOPARTY, True, InStateMultiplierOf(PAQSOPARTY, 'DX'), rmDomestic),
             'DX counts (10.a: plus 1 DX)');
end;

(* "10.b. Out-of-State Multipliers: 67 PA Counties." *)
procedure TContestPennsylvaniaQPTests.Test_OutOfStateFileHoldsOnlyCounties;
begin
   BeginTest('Test_OutOfStateFileHoldsOnlyCounties');
   LoadCountyTable('pa_cty.dom', True);
   try
      CheckTrue(CountyFileKnowsQTH('ADA'), 'a county');
      CheckTrue(CountyFileKnowsQTH('WYO'), 'the last county');
      CheckFalse(CountyFileKnowsQTH('NTX'), 'a section is no county');
      CheckFalse(CountyFileKnowsQTH('DX'), 'nor is DX');
   finally
      FreeCountyTable;
   end;
end;

(* "3.b. QSOs are not permitted on the WARC bands (12m, 17m, 30m, or 60m)."
   "6.a CW ... 6.c Phone: SSB, FM, AM, etc." No digital mode is named. *)
procedure TContestPennsylvaniaQPTests.Test_BandsAndModes;
var
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_BandsAndModes');
   for b := Low(BandType) to High(BandType) do
      begin
      expected := (b in [Band160..Band24G]) and not (b in [Band30, Band17, Band12]);
      CheckTrue(PAIdentity.UsesBand(b) = expected, 'band ' + IntToStr(Ord(b)));
      end;
   CheckTrue(PAIdentity.UsesBand(Band6), '6 m is credited');
   CheckTrue(PAIdentity.UsesBand(Band2), '2 m is credited');
   CheckTrue(PAIdentity.UsesMode(CW, eCW), 'CW');
   CheckTrue(PAIdentity.UsesMode(Phone, eUSB), 'SSB');
   CheckTrue(PAIdentity.UsesMode(FM, eFM), 'FM');
   CheckFalse(PAIdentity.UsesMode(Digital, eNoMode), 'digital is not a rule mode');
   CheckFalse(PAIdentity.UsesMode(Digital, eFT8), 'FT8 is not');
   CheckTrue(cfVHFBandsEnabled in PAIdentity.Flags, 'VHF bands are reachable');
   CheckFalse(cfMultByBand in PAIdentity.Flags, 'multipliers count once, not once per band');
end;

function ScoredPoints(aBand: BandType; aMode: ModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
   station: TStationContext;
begin
   station := WithHostAreaTable(NoStation);
   contestObject := Make(PAQSOPARTY, station);
   try
      qso := Default(ContestExchange);
      qso.Band := aBand;
      qso.Mode := aMode;
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "6.a. CW: 2 points/QSO ... 6.c. Phone: 1 point/QSO". *)
procedure TContestPennsylvaniaQPTests.Test_Points;
begin
   BeginTest('Test_Points');
   CheckEquals(2, ScoredPoints(Band20, CW), 'CW');
   CheckEquals(1, ScoredPoints(Band20, Phone), 'Phone');
   CheckEquals(1, ScoredPoints(Band6, FM), 'FM is phone');
   CheckEquals(0, ScoredPoints(Band20, Digital), 'digital is an X-QSO');
   CheckEquals(0, ScoredPoints(Band17, CW), 'WARC is off-band');
end;

function FinalFor(aPower: tCategoryPower; aYear: integer; aView: TLoggedQSOView): longint;
var
   totals: TScoreTotals;
   contestObject: TContestBase;
   station: TStationContext;
begin
   totals := Default(TScoreTotals);
   totals.QSOPoints := 150;
   totals.ScoredBand := AllBands;
   totals.SessionCountsMultipliers := True;
   totals.Mults[AllBands, Both, rmDomestic] := 7;
   totals.LogStartTime := EncodeDate(aYear, 10, 10);
   station := WithHostAreaTable(NoStation);
   station.MyPower := aPower;
   contestObject := Make(PAQSOPARTY, station);
   try
      Result := contestObject.FinalScore(totals, aView);
   finally
      contestObject.Free;
   end;
end;

(* "10.d. QRP Operation Multiplier: Multiply QSO Points times 2." No other
   power category changes the score (LOW and HIGH are plain). *)
procedure TContestPennsylvaniaQPTests.Test_QRPDoublesThePoints;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_QRPDoublesThePoints');
   view := TLoggedQSOList.Create;
   try
      CheckEquals(150 * 7, FinalFor(cpHIGH, 2026, view), 'HIGH');
      CheckEquals(150 * 7, FinalFor(cpLOW, 2026, view), 'LOW');
      CheckEquals(150 * 7 * 2, FinalFor(cpQRP, 2026, view), 'QRP');
   finally
      view.Free;
   end;
end;

procedure AddBonusQSO(aView: TLoggedQSOList; const aCall: string;
                      aBand: BandType; aMode: ModeType);
var
   qso: ContestExchange;
begin
   qso := Default(ContestExchange);
   qso.Callsign := CallString(aCall);
   qso.Band := aBand;
   qso.Mode := aMode;
   aView.Add(qso);
end;

(* "11.c. Valid QSOs with the bonus station are worth 200 points ...
   11.d. The Bonus Station(s) for the 2026 PA QSO Party is ... K3ZMC". The
   bonus is the 2026 rules year's: a 2027 log pays none. *)
procedure TContestPennsylvaniaQPTests.Test_BonusStationIsA2026Rule;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_BonusStationIsA2026Rule');
   view := TLoggedQSOList.Create;
   try
      AddBonusQSO(view, 'K3ZMC', Band20, CW);
      AddBonusQSO(view, 'K3ZMC', Band20, CW);
      AddBonusQSO(view, 'K3ZMC', Band20, Phone);
      AddBonusQSO(view, 'K3ZMC', Band40, CW);
      AddBonusQSO(view, 'K3ZMC', Band30, CW);
      AddBonusQSO(view, 'W3AAA', Band20, CW);
      CheckEquals(150 * 7 + 3 * 200, FinalFor(cpHIGH, 2026, view),
                  '20 CW, 20 phone and 40 CW; a repeat and a WARC QSO earn nothing');
      CheckEquals(150 * 7, FinalFor(cpHIGH, 2027, view), '2027: no bonus station is stated');
   finally
      view.Free;
   end;
end;

(* A section is no county: its ADIF STATE is its one state, and it is never
   taken for a PA county (the file holds sections as well as counties). *)
procedure TContestPennsylvaniaQPTests.Test_AdifStateOfASection;
var
   contestObject: TContestBase;
   qso: ContestExchange;
   keys: TStringList;
   i: integer;
begin
   BeginTest('Test_AdifStateOfASection');
   contestObject := Make(PAQSOPARTY, WithHostAreaTable(NoStation));
   keys := TStringList.Create;
   try
      (* No county abbreviation may be taken for an ADIF section code. *)
      ShippedCountyKeys('pa_cty.dom', keys);
      CheckEquals(67, keys.Count, 'the sponsor''s 67 counties');
      for i := 0 to keys.Count - 1 do
         begin
         qso := Default(ContestExchange);
         qso.QTHString := ShortString(keys[i]);
         qso.DomesticQTH := ShortString(keys[i]);
         CheckEquals('PA', contestObject.ADIFCountyState(qso),
                     keys[i] + ' is a PA county');
         end;

      qso := Default(ContestExchange);
      qso.QTH.CountryID := 'K';
      qso.QTHString := 'NTX';
      qso.DomesticQTH := 'NTX';
      CheckEquals('', contestObject.ADIFCountyState(qso), 'NTX is no PA county');
      CheckEquals('TX', contestObject.ADIFWorkedStationState(qso), 'NTX is in Texas');
      qso.QTH.CountryID := 'DL';
      CheckEquals('', contestObject.ADIFWorkedStationState(qso), 'not a subdivision of Germany');
      qso.QTH.CountryID := 'K';
      qso.QTHString := 'ADA';
      qso.DomesticQTH := 'ADA';
      CheckEquals('PA', contestObject.ADIFCountyState(qso), 'ADA is a PA county');
      CheckEquals('PA', contestObject.ADIFWorkedStationState(qso), 'its state is PA');
      qso.QTHString := 'MDC';
      qso.DomesticQTH := 'MDC';
      CheckEquals('', contestObject.ADIFWorkedStationState(qso), 'MDC spans two states');
   finally
      keys.Free;
      contestObject.Free;
   end;
end;

(* "5.a ... or DX": a DX entrant, with no MY STATE, sends DX in both
   exports; a station with one sends it. *)
procedure TContestPennsylvaniaQPTests.Test_DXEntrantSendsDX;
var
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
begin
   BeginTest('Test_DXEntrantSendsDX');
   my := Default(TMyStationExchange);
   qso := Default(ContestExchange);
   ctx := Default(TCabrilloQSOContext);
   qso.NumberSent := 12;
   CheckEquals('12   DX    ', PAIdentity.FormatCabrilloSentExchange(my, qso, ctx), 'Cabrillo, no MY STATE');
   CheckEquals('DX   12    ', PAIdentity.FormatADIFSentExchange(my, qso), 'ADIF, no MY STATE');
   my.MyState := 'NTX';
   CheckEquals('12   NTX   ', PAIdentity.FormatCabrilloSentExchange(my, qso, ctx), 'Cabrillo, a section');
end;

procedure TContestPennsylvaniaQPTests.RunAllTests;
begin
   Test_InStateFileTakesSectionsNotStates;
   Test_OutOfStateFileHoldsOnlyCounties;
   Test_BandsAndModes;
   Test_Points;
   Test_QRPDoublesThePoints;
   Test_BonusStationIsA2026Rule;
   Test_AdifStateOfASection;
   Test_DXEntrantSendsDX;
end;

end.
