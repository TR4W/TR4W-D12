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

(* THE FLORIDA QSO PARTY'S 2026 RULES (#88 round 2, checked 2026-10-26). The
  sponsor's texts are docs/ContestRules/QSOParties/Florida/; each test quotes
  the rule it holds.

    * points: CW 2, phone 1 -- FM is no FQP mode (NY4I, 2026-11-20);
    * "No digital QSOs are allowed" -- an automatic X-QSO;
    * "No 160 or 80 meters, WARC or VHF bands" -- 40, 20, 15 and 10 m;
    * the power multiplier after points x multipliers: HIGH, LOW and QRP
      score an identical log 1:2:3;
    * the DXCC multiplier leaves out KH6 and KL7, which send a state;
    * florida.dom, the in-state file, through the real loader: the 50 states
      with Florida, DC, the 13 provinces (NS, NB and PE apart; NT, NL and NU
      known), each county counted as Florida, and no 'DX' entry. *)
unit uTestContestFloridaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestFloridaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_FloridaSentExchange;
      procedure Test_FloridaPoints;
      procedure Test_FloridaBands;
      procedure Test_FloridaDigitalIsAnXQSO;
      procedure Test_FloridaPowerMultiplier;
      procedure Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska;
      procedure Test_FloridaInStateFileIsTheSponsorsModel;
      procedure Test_FloridaCabrilloFollowsTheFQPSpecification;
      procedure Test_FloridaSpecialOneByOneHasNoMultipliers;
      procedure Test_FloridaRoverLegsAreNewStationsAndSendTheirCounty;
      procedure Test_FloridaMobileAndMaritimeRealEngine;
   end;

implementation

uses
   (* cpHIGH / cpLOW / cpQRP. Before VC, so VC's names win where they
      overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uMults,
   uCallsigns,
   uCTYDAT,
   uPendingCounties,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uContestStateQSOPartyBase,
   uContestFloridaQP,
   (* CategoryValuesFor, OverlayValuesWith, CabrilloHeaderTagLine. *)
   uCbrSum,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit,
   uTestContestObjects,
   uTestShippedDom;

(* A Florida entrant (Lee County) or one in Kansas; outside the state the
   host-area table knows every QTH, so a points test is not about that
   rule. *)
function Entrant(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'LEE';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

function FloridaQso(aBand: BandType; aMode: ModeType;
                    aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K4ABC';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'LEE';
   Result.DomesticQTH := 'Lee';
end;

(* What ScoreQSO gives -- the one public scoring entry. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(FLORIDAQSOPARTY, Entrant(aInState));
   try
      qso := FloridaQso(aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "Each complete non-duplicate Phone contact is worth 1 point per band. Each
   complete non-duplicate CW contact is worth 2 points per band." FM is no
   FQP mode (NY4I, 2026-11-20: "just SSB and CW"), an X-QSO scoring 0.
   Inside Florida and outside it alike. *)
procedure TContestFloridaQPTests.Test_FloridaPoints;
var
   inState: boolean;
   who: string;
begin
   BeginTest('Test_FloridaPoints');
   for inState := False to True do
      begin
      if inState then
         begin
         who := 'in FL';
         end
      else
         begin
         who := 'outside FL';
         end;
      CheckEquals(2, PointsFor(inState, Band20, CW, eCW), who + ': CW is 2');
      CheckEquals(1, PointsFor(inState, Band20, Phone, eSSB), who + ': phone is 1');
      CheckEquals(0, PointsFor(inState, Band10, FM, eFM), who + ': FM is no FQP mode, 0');
      CheckEquals(0, PointsFor(inState, Band20, Both, eNoMode), who + ': no mode a contact is made in');
      CheckEquals(0, PointsFor(inState, Band20, NoMode, eNoMode), who + ': nor this one');
      end;
end;

(* "No 160 or 80 meters, WARC or VHF bands." Every BandType, both ways. *)
procedure TContestFloridaQPTests.Test_FloridaBands;
const
   SPONSOR_BANDS = [Band40, Band20, Band15, Band10];
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_FloridaBands');
   identity := ContestIdentity(FLORIDAQSOPARTY);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in SPONSOR_BANDS;
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor allows it');
      qso := FloridaQso(b, CW, eCW);
      (* NoBand is a record that names no band, never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not expected) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      if expected then
         begin
         CheckEquals(2, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' CW scores 2');
         end
      else
         begin
         CheckEquals(0, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' scores 0');
         end;
      end;
end;

(* "No digital QSOs are allowed in the FQP." No digital submode is credited;
   CW and phone are, whatever the submode; FM is not ("FM is not valid in
   FQP--just SSB and CW", NY4I, 2026-11-20). *)
procedure TContestFloridaQPTests.Test_FloridaDigitalIsAnXQSO;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   qso: ContestExchange;
begin
   BeginTest('Test_FloridaDigitalIsAnXQSO');
   identity := ContestIdentity(FLORIDAQSOPARTY);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'no digital submode is credited, ext ' + IntToStr(Ord(ext)));
      qso := FloridaQso(Band20, Digital, ext);
      CheckTrue(QSOIsXQSO(identity, qso), 'a digital QSO is an X-QSO, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, CW, ext), 'CW is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, Phone, ext), 'phone is credited, ext ' + IntToStr(Ord(ext)));
      CheckFalse(ContestCreditsMode(identity, FM, ext), 'FM is not credited, ext ' + IntToStr(Ord(ext)));
      qso := FloridaQso(Band10, FM, ext);
      CheckTrue(QSOIsXQSO(identity, qso), 'an FM QSO is an X-QSO, ext ' + IntToStr(Ord(ext)));
      end;
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not credited');
   CheckEquals(0, PointsFor(True, Band20, Digital, eRTTY), 'in FL, an RTTY QSO scores 0');
   CheckEquals(0, PointsFor(False, Band20, Digital, eNoMode), 'outside FL, a digital QSO scores 0');
end;

(* "If all QSOs were made using 5 watts output or less, use a Power
   Multiplier of 3. ... greater 5 watts and less than 100 watts ... 2. ...
   more than 100 watts ... no Power Multiplier." "Calculate the Power
   Multiplier after you have calculated your QSO Points times Multiplier."
   "If no power is indicated ... it will default to High Power." *)
procedure TContestFloridaQPTests.Test_FloridaPowerMultiplier;
var
   view: TLoggedQSOList;
   t: TScoreTotals;
   unstated: TContestBase;

   function ScoreAt(aPower: tCategoryPower): longint;
   var
      station: TStationContext;
      contestObject: TContestBase;
   begin
      station := Entrant(True);
      station.MyPower := aPower;
      contestObject := Make(FLORIDAQSOPARTY, station);
      try
         Result := contestObject.FinalScore(t, view);
      finally
         contestObject.Free;
      end;
   end;

begin
   BeginTest('Test_FloridaPowerMultiplier');
   CheckEquals(1, FloridaPowerMultiplier(cpHIGH), 'HIGH: x1');
   CheckEquals(2, FloridaPowerMultiplier(cpLOW), 'LOW: x2');
   CheckEquals(3, FloridaPowerMultiplier(cpQRP), 'QRP: x3');

   t := Default(TScoreTotals);
   t.QSOPoints := 150;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 40;
   t.Mults[AllBands, Both, rmDX] := 7;
   view := TLoggedQSOList.Create;
   try
      CheckEquals(150 * 47, ScoreAt(cpHIGH), 'HIGH: points x multipliers');
      CheckEquals(150 * 47 * 2, ScoreAt(cpLOW), 'LOW: then x2');
      CheckEquals(150 * 47 * 3, ScoreAt(cpQRP), 'QRP: then x3');
      CheckEquals(ScoreAt(cpHIGH) * 2, ScoreAt(cpLOW), 'HIGH:LOW is 1:2');
      CheckEquals(ScoreAt(cpHIGH) * 3, ScoreAt(cpQRP), 'HIGH:QRP is 1:3');
      (* NO POWER STATED: a station that sets none holds the zero value,
         cpHIGH -- "it will default to High Power". *)
      unstated := Make(FLORIDAQSOPARTY, Entrant(True));
      try
         CheckEquals(150 * 47, unstated.FinalScore(t, view), 'no power stated: HIGH');
      finally
         unstated.Free;
      end;
   finally
      view.Free;
   end;
end;

(* "DXCC Countries (outside the US and Canada)" and "US (including KH6/KL7)
   operators send State": Hawaii and Alaska are the states HI and AK, never
   also a DXCC multiplier. Asked of the class directly -- the engine's
   domestic-country list happens to keep KH6 and KL away from the key today,
   and the rule must not depend on that. *)
procedure TContestFloridaQPTests.Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska;
var
   contestObject: TContestBase;

   function KeyOf(const aCountry: string; out aKey: DXMultiplierString): boolean;
   var
      qso: ContestExchange;
   begin
      qso := FloridaQso(Band20, CW, eCW);
      qso.QTH.CountryID := ShortString(aCountry);
      Result := contestObject.DXMultiplierKey(qso, aKey);
   end;

var
   key: DXMultiplierString;
begin
   BeginTest('Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska');
   contestObject := Make(FLORIDAQSOPARTY, Entrant(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'Florida counts DXCC countries');
      CheckFalse(KeyOf('K', key), 'the USA is not a DXCC multiplier');
      CheckFalse(KeyOf('VE', key), 'nor Canada');
      CheckFalse(KeyOf('KH6', key), 'nor Hawaii: it sends HI');
      CheckFalse(KeyOf('KL', key), 'nor Alaska: it sends AK');
      CheckTrue(KeyOf('KP4', key), 'Puerto Rico is: "DX (including KP4, etc.)"');
      CheckEquals('KP4', string(key), 'keyed by its DXCC country');
      CheckTrue(KeyOf('DL', key), 'Germany is');
      CheckEquals('DL', string(key), 'keyed by its DXCC country');
   finally
      contestObject.Free;
   end;
end;

(* "For Florida entrants: 50 States (including Florida); District of Columbia
   (DC); 13 Canadian Provinces NS (VE1), NB (VE1, VE9), NL (VO1, VO2), PE
   (VY2), QC (VE2), ON (VE3), MB (VE4), SK (VE5), AB (VE6), BC (VE7), NT
   (VE8), NU (VY0), YT (VY1); DXCC Countries ...; There is no in-state County
   multiplier." florida.dom, through the real loader with its INCLUDEs: each
   county counts as Florida, and nothing in it is 'DX' -- the DXCC country is
   the DX multiplier, so a 'DX' domestic entry would count a DX station twice
   (the import path looked one up). *)
procedure TContestFloridaQPTests.Test_FloridaInStateFileIsTheSponsorsModel;
const
   STATES = 'AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI ' +
            'MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT ' +
            'VT VA WA WV WI WY';
   PROVINCES = 'NS NB NL PE QC ON MB SK AB BC NT NU YT';
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
   words: TStringList;
   seen: TStringList;
   counties: TStringList;
   i: integer;
   key: string;
begin
   BeginTest('Test_FloridaInStateFileIsTheSponsorsModel');
   CheckEquals('florida', ContestIdentity(FLORIDAQSOPARTY).InStateDomesticFileName,
               'florida.dom is the in-state file');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   words := TStringList.Create;
   seen := TStringList.Create;
   counties := TStringList.Create;
   try
      CheckEquals('S50.DOM P13.DOM',
                  LoadShippedDomFollowingIncludes(table, 'florida.dom', True, 0),
                  'florida.dom includes the 50 states and the 13 provinces');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      words.Delimiter := ' ';
      words.DelimitedText := STATES;
      CheckEquals(50, words.Count, 'the sponsor lists 50 states');
      for i := 0 to words.Count - 1 do
         begin
         CheckEquals(words[i], MultiplierOf(table, words[i]), 'state ' + words[i]);
         seen.Add(MultiplierOf(table, words[i]));
         end;
      CheckEquals('DC', MultiplierOf(table, 'DC'), 'DC is its own multiplier');
      seen.Add('DC');

      words.DelimitedText := PROVINCES;
      CheckEquals(13, words.Count, 'the sponsor lists 13 provinces and territories');
      for i := 0 to words.Count - 1 do
         begin
         CheckEquals(words[i], MultiplierOf(table, words[i]), 'province ' + words[i]);
         seen.Add(MultiplierOf(table, words[i]));
         end;
      CheckEquals(64, seen.Count, '50 states, DC and 13 provinces: 64 distinct multipliers');
      CheckEquals('NB', MultiplierOf(table, 'VE9'), 'VE9 is New Brunswick');
      CheckEquals('NL', MultiplierOf(table, 'VO2'), 'VO2 is Newfoundland and Labrador');
      CheckEquals('NU', MultiplierOf(table, 'VY0'), 'VY0 is Nunavut');

      (* EVERY COUNTY OF THE OUT-OF-STATE FILE COUNTS AS FLORIDA HERE. *)
      counties.LoadFromFile(ShippedDomDir + 'florida_cty.dom');
      for i := counties.Count - 1 downto 0 do
         begin
         if Pos('=', counties[i]) = 0 then
            begin
            counties.Delete(i);
            end;
         end;
      CheckEquals(67, counties.Count, 'the 67 counties');
      for i := 0 to counties.Count - 1 do
         begin
         key := UpperCase(Trim(Copy(counties[i], Pos('=', counties[i]) + 1, MaxInt)));
         (* THE ALIAS, not its ^display name (the county names since
            2026-11-20): 'ALC,^Alachua' is the alias ALC. *)
         if Pos(',', key) > 0 then
            begin
            key := Trim(Copy(key, 1, Pos(',', key) - 1));
            end;
         CheckEquals('FL', MultiplierOf(table, key), 'county ' + key + ' counts as Florida');
         end;

      CheckEquals('', MultiplierOf(table, 'DX'), 'no DX domestic entry');
   finally
      counties.Free;
      seen.Free;
      words.Free;
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* "Florida operators send county ... US (including KH6/KL7) operators send
   State. Canadian operators send province ... DX (including KP4, etc.)
   operators send DXCC prefix." A DX entrant has no MY STATE and sends its
   own country, in the CQ exchange, the Cabrillo sent column and the ADIF
   STX_STRING; anyone else sends what it stated. *)
procedure TContestFloridaQPTests.Test_FloridaSentExchange;
var
   contestObject: TContestBase;
   station: TStationContext;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
begin
   BeginTest('Test_FloridaSentExchange');
   qso := FloridaQso(Band20, CW, eCW);
   qso.RSTSent := 599;
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';
   ctx.HisQTH := 'LEE';

   (* A DX ENTRANT: KP4 sends its prefix. *)
   station := Entrant(False);
   station.MyState := '';
   station.MyCountry := 'KP4';
   contestObject := Make(FLORIDAQSOPARTY, station);
   try
      my := Default(TMyStationExchange);
      my.MyState := '';
      CheckEquals(' 5NN KP4', contestObject.CQExchangeDefault(station),
                  'CQ exchange: the DXCC prefix');
      CheckEquals('599 KP4    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'Cabrillo sent: RST and the prefix');
      CheckEquals('599 KP4    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and the prefix');
   finally
      contestObject.Free;
   end;

   (* A FLORIDA ENTRANT sends its county; one in Kansas its state. *)
   station := Entrant(True);
   station.MyCountry := 'K';
   contestObject := Make(FLORIDAQSOPARTY, station);
   try
      my := Default(TMyStationExchange);
      my.MyState := 'LEE';
      CheckEquals(' 5NN LEE', contestObject.CQExchangeDefault(station), 'a Florida entrant: the county');
      CheckEquals('599 LEE    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'Cabrillo sent: RST and the county');
   finally
      contestObject.Free;
   end;
   station := Entrant(False);
   station.MyCountry := 'K';
   contestObject := Make(FLORIDAQSOPARTY, station);
   try
      CheckEquals(' 5NN KS', contestObject.CQExchangeDefault(station), 'a Kansas entrant: the state');
   finally
      contestObject.Free;
   end;
end;

(* THE FQP CABRILLO SPECIFICATION (Cabrillo-Specification-V3-FQP-1.md):
   "CONTEST: FCG-FQP"; "CATEGORY-OPERATOR: SINGLE-OP MULTI-OP CHECKLOG";
   "CATEGORY-TRANSMITTER: ... ONE UNLIMITED"; "CATEGORY-ASSISTED: ASSISTED
   NON-ASSISTED"; "CATEGORY-MODE: SSB CW MIXED"; "CATEGORY-POWER: HIGH LOW
   QRP"; "CATEGORY-STATION: FIXED MOBILE EXPEDITION SCHOOL";
   "CATEGORY-OVERLAY: DRIVER NO-DRIVER NOVICE-TECH ROOKIE YOUTH YL SWL"; the
   QSO example "QSO: 14045 CW ..." / "QSO: 14275 PH ...". Each value must be
   offered by the Cabrillo summary window. The standard overlay list holds
   ROOKIE, YOUTH, NOVICE-TECH and YL; the class adds DRIVER, NO-DRIVER, SWL.
   NOT BUILT: a list of CATEGORY-STATION restricted to the four the FQP
   names (the standard list offers more), and OPERATORS' "@host". *)
function ListHas(const aValues: TArray<string>; const aWord: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to High(aValues) do
      begin
      if aValues[i] = aWord then
         begin
         Result := True;
         end;
      end;
end;

procedure TContestFloridaQPTests.Test_FloridaCabrilloFollowsTheFQPSpecification;
const
   OPERATOR_VALUES: array[0..2] of string = ('SINGLE-OP', 'MULTI-OP', 'CHECKLOG');
   TRANSMITTER_VALUES: array[0..1] of string = ('ONE', 'UNLIMITED');
   ASSISTED_VALUES: array[0..1] of string = ('ASSISTED', 'NON-ASSISTED');
   MODE_VALUES: array[0..2] of string = ('SSB', 'CW', 'MIXED');
   POWER_VALUES: array[0..2] of string = ('HIGH', 'LOW', 'QRP');
   STATION_VALUES: array[0..3] of string = ('FIXED', 'MOBILE', 'EXPEDITION', 'SCHOOL');
   OVERLAY_VALUES: array[0..6] of string = ('DRIVER', 'NO-DRIVER', 'NOVICE-TECH',
                                            'ROOKIE', 'YOUTH', 'YL', 'SWL');
var
   identity: TContestBase;
   offered: TArray<string>;
   i: integer;
begin
   BeginTest('Test_FloridaCabrilloFollowsTheFQPSpecification');
   identity := ContestIdentity(FLORIDAQSOPARTY);
   CheckEquals('FCG-FQP', identity.CabrilloName, 'CONTEST: FCG-FQP');

   for i := Low(OPERATOR_VALUES) to High(OPERATOR_VALUES) do
      begin
      CheckTrue(ListHas(CategoryValuesFor(ctCategoryOperator), OPERATOR_VALUES[i]),
                'CATEGORY-OPERATOR offers ' + OPERATOR_VALUES[i]);
      end;
   for i := Low(TRANSMITTER_VALUES) to High(TRANSMITTER_VALUES) do
      begin
      CheckTrue(ListHas(CategoryValuesFor(ctCategoryTransmitter), TRANSMITTER_VALUES[i]),
                'CATEGORY-TRANSMITTER offers ' + TRANSMITTER_VALUES[i]);
      end;
   for i := Low(ASSISTED_VALUES) to High(ASSISTED_VALUES) do
      begin
      CheckTrue(ListHas(CategoryValuesFor(ctCategoryAssisted), ASSISTED_VALUES[i]),
                'CATEGORY-ASSISTED offers ' + ASSISTED_VALUES[i]);
      end;
   for i := Low(MODE_VALUES) to High(MODE_VALUES) do
      begin
      CheckTrue(ListHas(CategoryValuesFor(ctCategoryMode), MODE_VALUES[i]),
                'CATEGORY-MODE offers ' + MODE_VALUES[i]);
      end;
   for i := Low(POWER_VALUES) to High(POWER_VALUES) do
      begin
      CheckTrue(ListHas(CategoryValuesFor(ctCategoryPower), POWER_VALUES[i]),
                'CATEGORY-POWER offers ' + POWER_VALUES[i]);
      end;
   for i := Low(STATION_VALUES) to High(STATION_VALUES) do
      begin
      CheckTrue(ListHas(CategoryValuesFor(ctCategoryStation), STATION_VALUES[i]),
                'CATEGORY-STATION offers ' + STATION_VALUES[i]);
      end;

   (* THE OVERLAYS, as the Cabrillo summary window composes them. *)
   offered := OverlayValuesWith(OverlayCategory, identity.CabrilloOverlayCategories);
   for i := Low(OVERLAY_VALUES) to High(OVERLAY_VALUES) do
      begin
      CheckTrue(ListHas(offered, OVERLAY_VALUES[i]),
                'CATEGORY-OVERLAY offers ' + OVERLAY_VALUES[i]);
      end;
   CheckEquals(3, Length(identity.CabrilloOverlayCategories),
               'the class adds only the three the standard list lacks');
   CheckEquals('CATEGORY-OVERLAY: NO-DRIVER' + #13#10,
               CabrilloHeaderTagLine(ctCategoryOverlay, 'NO-DRIVER'),
               'the header line');
   CheckEquals('CATEGORY-STATION: MOBILE' + #13#10,
               CabrilloHeaderTagLine(ctCategoryStation, 'MOBILE'), 'CATEGORY-STATION');
   CheckEquals('CLUB: Florida Contest Group' + #13#10,
               CabrilloHeaderTagLine(ctClub, 'Florida Contest Group'), 'CLUB');

   (* "QSO: 14045 CW ..." and "QSO: 14275 PH ...". (An FM QSO is an X-QSO
      since 2026-11-20 and is still written FM; the specification names no
      FM.) *)
   CheckEquals('CW', identity.CabrilloModeString(CW, eCW), 'CW');
   CheckEquals('PH', identity.CabrilloModeString(Phone, eSSB), 'phone');
end;

(* "Special 1x1 callsign Florida QSO Party Spelling Bee stations - The final
   score is based on total QSOs. No multipliers." and "Special 1x1 stations
   have no multiplier". The QSO points alone: no geographic multiplier and
   no power multiplier (a reading, on the report). Recognised by the call. *)
procedure TContestFloridaQPTests.Test_FloridaSpecialOneByOneHasNoMultipliers;
var
   view: TLoggedQSOList;
   t: TScoreTotals;

   function ScoreFor(const aCall: string; aPower: tCategoryPower): longint;
   var
      station: TStationContext;
      contestObject: TContestBase;
   begin
      station := Entrant(True);
      station.MyCall := aCall;
      station.MyPower := aPower;
      contestObject := Make(FLORIDAQSOPARTY, station);
      try
         Result := contestObject.FinalScore(t, view);
      finally
         contestObject.Free;
      end;
   end;

begin
   BeginTest('Test_FloridaSpecialOneByOneHasNoMultipliers');
   CheckTrue(FloridaIsOneByOneCall('W4F'), 'W4F is a 1x1');
   CheckTrue(FloridaIsOneByOneCall('K4Q'), 'K4Q is a 1x1');
   CheckTrue(FloridaIsOneByOneCall('N4A'), 'N4A is a 1x1');
   CheckFalse(FloridaIsOneByOneCall('W4FQ'), 'W4FQ is not');
   CheckFalse(FloridaIsOneByOneCall('WA4F'), 'WA4F is not');
   CheckFalse(FloridaIsOneByOneCall('W44'), 'W44 is not');
   CheckFalse(FloridaIsOneByOneCall(''), 'no call is not');

   t := Default(TScoreTotals);
   t.QSOPoints := 150;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 40;
   t.Mults[AllBands, Both, rmDX] := 7;
   view := TLoggedQSOList.Create;
   try
      CheckEquals(150, ScoreFor('W4F', cpHIGH), 'a 1x1 scores its QSO points');
      CheckEquals(150, ScoreFor('W4F', cpQRP), 'with no power multiplier either');
      CheckEquals(150, ScoreFor('w4f', cpLOW), 'whatever the case of the call');
      CheckEquals(150 * 47 * 3, ScoreFor('W4AB', cpQRP), 'any other call: points x mults x power');
   finally
      view.Free;
   end;
end;

(* "Florida Mobiles and Expeditions that move to a new county are considered to
   be a new station and may be contacted again for QSO Point credit."
   "Mobiles and Expeditions may be worked in each county in which they
   operate." "Florida stations on a county line (maximum of two counties)".
   The party base's rover machinery, held for Florida: the dupe key carries
   the county the worked station sent and the county OUR rover sent from, the
   sent column follows each QSO's own county, two counties are a county line,
   and one Cabrillo is written (the FQP specification has no per-county
   file). A fixed station's key is what it always was. *)
procedure TContestFloridaQPTests.Test_FloridaRoverLegsAreNewStationsAndSendTheirCounty;
var
   identity: TContestBase;
   party: TContestStateQSOPartyBase;
   qso: ContestExchange;
   station: TStationContext;
   contestObject: TContestBase;
   my: TMyStationExchange;
   legMy: TMyStationExchange;
   ctx: TCabrilloQSOContext;
begin
   BeginTest('Test_FloridaRoverLegsAreNewStationsAndSendTheirCounty');
   identity := ContestIdentity(FLORIDAQSOPARTY);
   CheckTrue(identity.StripsRoverCountyFromCall, 'a /county suffix is a rover');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH,
             'the worked mobile in a new county is a new station');
   CheckTrue(identity.DupeKeyIncludesSentQTH,
             'and our own mobile from a new county is a new station');
   CheckFalse(identity.SplitsCabrilloByActivation,
              'one Cabrillo: the FQP specification has no per-county file');
   party := TContestStateQSOPartyBase(identity);
   CheckEquals(2, party.CountyLineCountiesMax, 'a county line is two counties');
   CheckTrue(party.CountyLineAllowed, 'and is allowed');

   qso := FloridaQso(Band20, CW, eCW);
   qso.Callsign := 'K4MOB';
   qso.QTHString := 'LEE';
   qso.DomesticQTH := 'Lee';
   CheckEquals('LEE', identity.DupeKeyQualifier(qso), 'a fixed station: the received county');
   qso.QTHString := 'CLR';
   qso.DomesticQTH := 'Clr';
   CheckEquals('CLR', identity.DupeKeyQualifier(qso), 'the same mobile in CLR is a new key');
   qso.ceRoverQTH := 'LEE';
   CheckEquals('CLR'#2'LEE', identity.DupeKeyQualifier(qso),
               'our rover in LEE: the place joins the key');
   qso.ceRoverQTH := 'CLR';
   CheckEquals('CLR'#2'CLR', identity.DupeKeyQualifier(qso),
               'and in CLR it is another');

   (* THE SENT COUNTY FOLLOWS THE LEG. *)
   station := Entrant(True);
   station.MyCountry := 'K';
   contestObject := Make(FLORIDAQSOPARTY, station);
   try
      my := Default(TMyStationExchange);
      my.MyState := 'FL';
      legMy := MyStationExchangeWithRoverPlace(my, 'CLR');
      qso := FloridaQso(Band20, CW, eCW);
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'LEE';
      CheckEquals('599 CLR    ', contestObject.FormatCabrilloSentExchange(legMy, qso, ctx),
                  'Cabrillo sent: the leg''s county');
      CheckEquals('599 CLR    ', contestObject.FormatADIFSentExchange(legMy, qso),
                  'ADIF STX_STRING: the leg''s county');
      legMy := MyStationExchangeWithRoverPlace(my, '');
      CheckEquals('599 FL     ', contestObject.FormatCabrilloSentExchange(legMy, qso, ctx),
                  'no leg: what the station sends, as before');
   finally
      contestObject.Free;
   end;
end;

function EnterFloridaLeg(const aCall, aExch: string; aBand: BandType;
                         aMode: ModeType; const aPlace: string;
                         out aAccepted: boolean;
                         var aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   ActiveMode := aMode;
   CallWindowString := CallString(aCall);
   ExchangeErrorMessage := '';
   aAccepted := ParametersOkay(CallString(aCall), Str40(aExch), aBand, aMode,
                               14025000, aRX);
   aRX.ceRecordKind := rkQSO;
   aRX.ceContest := Contest;
   (* THE PLACE A ROVER SENT IT FROM, as LogContact stamps it from the rover
      state, before the dupe question. *)
   aRX.ceRoverQTH := ShortString(aPlace);
   StampOffContest(aRX);
   Result := False;
   if aAccepted then
      begin
      Result := VisibleLog.QSOIsADupe(aRX);
      if Result then
         begin
         aRX.ceDupe := True;
         aRX.QSOPoints := 0;
         end;
      Sheet.SetMultFlags(aRX);
      Sheet.AddQSOToSheets(@aRX, False);
      AddQSOToDupeSheets(aRX, False);
      end;
end;

(* A FLORIDA MOBILE, THROUGH THE REAL ENGINE (ParametersOkay and the sheets,
   the in-state florida.dom): "Mobile and Expedition scores are based on
   cumulative QSOs and multipliers counted once overall" -- each county is a
   new station for a QSO (so 2 points again), a multiplier earned in the
   first county is not earned again in the second. A county's mobile is a
   new station for the one working it; a maritime mobile sends its ITU
   region. *)
procedure TContestFloridaQPTests.Test_FloridaMobileAndMaritimeRealEngine;
var
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedInHostState: boolean;
   savedCounties: boolean;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   savedRefusalDomDir: string;
   savedMyCountry: string;
   savedDomesticFilename: string;
   ctyPath: string;
   h: TContestHandle;
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   i: integer;
begin
   BeginTest('Test_FloridaMobileAndMaritimeRealEngine');
   h := ContestHandleOf(FLORIDAQSOPARTY);
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedInHostState := StationInHostState;
   savedCounties := MultipliersIsCounties;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedRefusalDomDir := DomesticQTHRefusalDomDir;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      (* A FLORIDA STATION, AS FoundContest SETS IT UP: in the host state, so
         florida.dom (the states, DC, the provinces; each county counts as
         Florida) and DXCC countries; K, VE, KH6 and KL domestic. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := False;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'florida.dom', True, 0);
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := True;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'florida.dom';
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      (* OUR MOBILE, FIRST COUNTY: LEE. *)
      dupe := EnterFloridaLeg('W1AW', '599 CT', Band20, CW, 'LEE', accepted, rx);
      CheckTrue(accepted, 'LEE: 599 CT is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'LEE: not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'LEE: CW is 2');
      CheckTrue(rx.DomesticMult, 'LEE: Connecticut is a new multiplier');

      (* MOVED TO CLRLIER: a new station, so the same QSO scores again; the
         multiplier is counted once overall. *)
      dupe := EnterFloridaLeg('W1AW', '599 CT', Band20, CW, 'CLR', accepted, rx);
      CheckTrue(accepted, 'CLR: 599 CT is taken');
      CheckFalse(dupe, 'CLR: W1AW again from a new county is NOT a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'CLR: and scores 2 -- cumulative QSOs');
      CheckFalse(rx.DomesticMult, 'CLR: Connecticut is not earned twice');

      dupe := EnterFloridaLeg('W1AW', '599 CT', Band20, CW, 'LEE', accepted, rx);
      CheckTrue(dupe, 'LEE again: a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'scoring 0');

      (* THE WORKED MOBILE: K4MOB in LEE, then in CLR, the same band and mode. *)
      dupe := EnterFloridaLeg('K4MOB', '599 LEE', Band15, CW, '', accepted, rx);
      CheckTrue(accepted, 'K4MOB in LEE is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'K4MOB in LEE: new');
      CheckEquals(2, Integer(rx.QSOPoints), 'K4MOB in LEE: 2');
      dupe := EnterFloridaLeg('K4MOB', '599 CLR', Band15, CW, '', accepted, rx);
      CheckTrue(accepted, 'K4MOB in CLR is taken');
      CheckFalse(dupe, 'K4MOB in CLR: a new station, workable again');
      CheckEquals(2, Integer(rx.QSOPoints), 'K4MOB in CLR: 2 again');
      dupe := EnterFloridaLeg('K4MOB', '599 CLR', Band15, CW, '', accepted, rx);
      CheckTrue(dupe, 'K4MOB in CLR again: a dupe');

      (* A MARITIME MOBILE sends its ITU region ("599 R2"): taken as a QSO that
         scores. THE REGION AS A MULTIPLIER IS NOT BUILT (the class header
         says why), so nothing is asserted about a multiplier here. *)
      dupe := EnterFloridaLeg('K1ABC/MM', '599 R2', Band20, CW, '', accepted, rx);
      CheckTrue(accepted, '/MM 599 R2 is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'a CW /MM QSO scores 2');
      CheckFalse(rx.DXMult, 'and the country of its call earns no DX multiplier');

      (* A DXCC COUNTRY IS STILL A DX MULTIPLIER. *)
      dupe := EnterFloridaLeg('DL1AAA', '599 DL', Band20, CW, '', accepted, rx);
      CheckTrue(accepted, 'a DX station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DXMult, 'Germany is a DX multiplier');
   finally
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
      ClearPendingCounties;
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      MultipliersIsCounties := savedCounties;
      StationInHostState := savedInHostState;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      Settings.Contest.DomesticFilename := savedDomesticFilename;
      Settings.My.DeriveCountry(savedMyCountry);
      DomesticQTHRefusalDomDir := savedRefusalDomDir;
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure TContestFloridaQPTests.RunAllTests;
begin
   Test_FloridaSentExchange;
   Test_FloridaPoints;
   Test_FloridaBands;
   Test_FloridaDigitalIsAnXQSO;
   Test_FloridaPowerMultiplier;
   Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska;
   Test_FloridaInStateFileIsTheSponsorsModel;
   Test_FloridaCabrilloFollowsTheFQPSpecification;
   Test_FloridaSpecialOneByOneHasNoMultipliers;
   Test_FloridaRoverLegsAreNewStationsAndSendTheirCounty;
   Test_FloridaMobileAndMaritimeRealEngine;
end;

end.
