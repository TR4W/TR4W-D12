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
      procedure Test_EveryCountyHasItsSection;
      procedure Test_InStateCountyAlsoEarnsItsSection;
      procedure Test_DXIsTheSingleDXMultiplier;
      procedure Test_OutsideStationEntersASection;
      procedure Test_NoRoverOrSubmissionBonusIsComputed;
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
   uTestQSOPartyRules,
   (* PennsylvaniaSectionOfCounty -- the county-to-section crosswalk. *)
   uContestPennsylvaniaQP,
   (* HostAreaOutsideSectionRefusal -- the New Contest dialog's rule. *)
   uNewContestHostArea;

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

(* THE CROSSWALK COVERS THE COUNTY FILE. Every pa_cty.dom key has a section,
   EPA or WPA, and the split is the ARRL's (tr4w/tools/trmaster/
   arrl-sections-counties.json: 34 EPA, 33 WPA). A few known each way. A
   section, a state or DX has none. *)
procedure TContestPennsylvaniaQPTests.Test_EveryCountyHasItsSection;
var
   keys: TStringList;
   i: integer;
   section: string;
   epa, wpa: integer;
begin
   BeginTest('Test_EveryCountyHasItsSection');
   keys := TStringList.Create;
   try
      ShippedCountyKeys('pa_cty.dom', keys);
      CheckEquals(67, keys.Count, 'the sponsor''s 67 counties');
      epa := 0;
      wpa := 0;
      for i := 0 to keys.Count - 1 do
         begin
         section := PennsylvaniaSectionOfCounty(keys[i]);
         CheckTrue((section = 'EPA') or (section = 'WPA'),
                   keys[i] + ' has a section: ' + section);
         if section = 'EPA' then
            begin
            Inc(epa);
            end
         else if section = 'WPA' then
            begin
            Inc(wpa);
            end;
         end;
      CheckEquals(34, epa, 'EPA counties');
      CheckEquals(33, wpa, 'WPA counties');
   finally
      keys.Free;
   end;

   CheckEquals('WPA', PennsylvaniaSectionOfCounty('ALL'), 'Allegheny (Pittsburgh)');
   CheckEquals('WPA', PennsylvaniaSectionOfCounty('ERI'), 'Erie');
   CheckEquals('WPA', PennsylvaniaSectionOfCounty('CEN'), 'Centre');
   CheckEquals('EPA', PennsylvaniaSectionOfCounty('PHI'), 'Philadelphia');
   CheckEquals('EPA', PennsylvaniaSectionOfCounty('DAU'), 'Dauphin (Harrisburg)');
   CheckEquals('EPA', PennsylvaniaSectionOfCounty('NHA'), 'Northampton');
   CheckEquals('EPA', PennsylvaniaSectionOfCounty(' bux '), 'in any case, trimmed');
   CheckEquals('', PennsylvaniaSectionOfCounty('NTX'), 'a section is no county');
   CheckEquals('', PennsylvaniaSectionOfCounty('EPA'), 'nor is EPA itself');
   CheckEquals('', PennsylvaniaSectionOfCounty('PA'), 'nor the state');
   CheckEquals('', PennsylvaniaSectionOfCounty('DX'), 'nor DX');
   CheckEquals('', PennsylvaniaSectionOfCounty(''), 'nor nothing');
end;

(* "For in-state stations, the first EPA and WPA county worked will count
   both the county and the section multiplier in the score" (NY4I,
   2026-11-20). The section is the #317 second domestic key, for an in-state
   entrant only, and it is a key of the in-state file (arrlsect.dom's EPA and
   WPa; the sheet compares without case). *)
procedure TContestPennsylvaniaQPTests.Test_InStateCountyAlsoEarnsItsSection;
var
   station: TStationContext;
   party: TContestBase;
   qso: ContestExchange;
   key: string;
begin
   BeginTest('Test_InStateCountyAlsoEarnsItsSection');
   CheckTrue(SameText('EPA', InStateMultiplierOf(PAQSOPARTY, 'EPA')),
             'EPA is an in-state multiplier key');
   CheckTrue(SameText('WPA', InStateMultiplierOf(PAQSOPARTY, 'WPA')),
             'WPA is an in-state multiplier key');

   station := WithHostAreaTable(NoStation);
   station.InHostState := True;
   party := Make(PAQSOPARTY, station);
   try
      qso := Default(ContestExchange);
      qso.DomesticQTH := 'ALL';
      CheckTrue(party.AdditionalDomesticMultiplierKey(qso, key), 'a county earns a second key');
      CheckEquals('WPA', key, 'Allegheny earns WPA');
      qso.DomesticQTH := 'BUX';
      CheckTrue(party.AdditionalDomesticMultiplierKey(qso, key), 'Bucks too');
      CheckEquals('EPA', key, 'Bucks earns EPA');
      qso.DomesticQTH := '';
      qso.DomMultQTH := 'ERI';
      CheckTrue(party.AdditionalDomesticMultiplierKey(qso, key), 'a rover row');
      CheckEquals('WPA', key, 'the credited key, no DomesticQTH');
      qso.DomMultQTH := '';
      qso.QTHString := 'ERI';
      CheckFalse(party.AdditionalDomesticMultiplierKey(qso, key),
                 'the typed QTH alone is not the credited key');
      qso.DomesticQTH := 'NTX';
      CheckFalse(party.AdditionalDomesticMultiplierKey(qso, key),
                 'a section worked earns only itself');
      CheckEquals('', key, 'and no key');
      qso.DomesticQTH := 'DX';
      CheckFalse(party.AdditionalDomesticMultiplierKey(qso, key), 'DX earns only DX');
   finally
      party.Free;
   end;

   station.InHostState := False;
   party := Make(PAQSOPARTY, station);
   try
      qso := Default(ContestExchange);
      qso.DomesticQTH := 'ALL';
      CheckFalse(party.AdditionalDomesticMultiplierKey(qso, key),
                 'an out-of-state entrant counts the county alone (10.b)');
   finally
      party.Free;
   end;
end;

(* "Likewise, the first DXCC station worked counts as the single DX
   multiplier." pa.dom's one 'dx' key -- no DXCC list, no DX sheet. *)
procedure TContestPennsylvaniaQPTests.Test_DXIsTheSingleDXMultiplier;
begin
   BeginTest('Test_DXIsTheSingleDXMultiplier');
   CheckEquals('DX', InStateMultiplierOf(PAQSOPARTY, 'DX'), 'one DX key');
   CheckFalse(PAIdentity.HasDXMultiplier, 'no per-country DX multiplier');
   CheckFalse(cfMultByMode in PAIdentity.Flags, 'once, not once per mode');
end;

(* A STATION OUTSIDE PA SENDS ITS ARRL OR RAC SECTION (NY4I, 2026-11-20:
   "Rather than an op in Florida sending FL to the PA station, I would send
   WCF"). The New Contest dialog's outside row takes a section or DX, and
   refuses a state that is no section and anything naming PA. *)
procedure TContestPennsylvaniaQPTests.Test_OutsideStationEntersASection;
var
   area: TNewContestHostArea;
begin
   BeginTest('Test_OutsideStationEntersASection');
   CheckTrue(PAIdentity.DescribeNewContestHostArea(area), 'PA offers the box');
   CheckTrue(area.OutsideTakesSection, 'outside, a section');
   CheckEquals('PA EPA WPA', area.HostStates, 'PA and its two sections are inside');
   CheckEquals('pa_cty', area.PlacesFile, 'inside, its counties');

   CheckEquals('', HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'WCF'),
               'a Florida station sends WCF');
   CheckEquals('', HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'wcf'),
               'in any case');
   CheckEquals('', HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'ONE'),
               'a RAC section');
   CheckEquals('', HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'OH'),
               'a state that IS its section');
   CheckEquals('', HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'DX'),
               'DX');
   CheckEquals('', HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, ''),
               'an empty row is the dialog''s own rule');
   CheckTrue(HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'FL') <> '',
             'FL is no section: send WCF, NFL or SFL');
   CheckTrue(HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'EPA') <> '',
             'EPA is inside PA');
   CheckTrue(HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'pa') <> '',
             'PA is inside PA');
   CheckTrue(HostAreaOutsideSectionRefusal(nil, area.Area, area.HostStates, 'XYZ') <> '',
             'anything else is refused');

   (* Every other party keeps the state-or-province row. *)
   CheckTrue(ContestIdentity(FLORIDAQSOPARTY).DescribeNewContestHostArea(area), 'Florida offers the box');
   CheckFalse(area.OutsideTakesSection, 'and takes a state outside');
end;

(* "Rover Bonus -- That is not something we could know ... That just like
   the electronic submission is something the user needs to add at log
   submission time" (NY4I, 2026-11-20). A log with rover calls, many
   counties and no bonus station scores points x multipliers and nothing
   more. *)
procedure TContestPennsylvaniaQPTests.Test_NoRoverOrSubmissionBonusIsComputed;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_NoRoverOrSubmissionBonusIsComputed');
   view := TLoggedQSOList.Create;
   try
      AddBonusQSO(view, 'W3AAA/ALL', Band20, CW);
      AddBonusQSO(view, 'W3AAA/BUX', Band20, CW);
      AddBonusQSO(view, 'W3AAA/ERI', Band40, Phone);
      AddBonusQSO(view, 'N3BBB', Band80, CW);
      CheckEquals(150 * 7, FinalFor(cpHIGH, 2026, view), 'no rover or e-submission bonus');
      CheckEquals(150 * 7 * 2, FinalFor(cpQRP, 2026, view), 'QRP doubles, and adds nothing else');
   finally
      view.Free;
   end;
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
   Test_EveryCountyHasItsSection;
   Test_InStateCountyAlsoEarnsItsSection;
   Test_DXIsTheSingleDXMultiplier;
   Test_OutsideStationEntersASection;
   Test_NoRoverOrSubmissionBonusIsComputed;
end;

end.
