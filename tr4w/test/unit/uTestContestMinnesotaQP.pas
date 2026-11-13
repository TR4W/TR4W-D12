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

(* THE MINNESOTA QSO PARTY'S 2027 RULES -- issue #193 (from TR4W/TR4W#1082).
  The rules are docs/ContestRules/QSOParties/Minnesota/ (the sponsor's PDF,
  dated June 8, 2026, and MN-QSO-PARTY-Rules.txt). Each test quotes the rule
  it holds.

  WHAT IS PINNED
    * its bands and modes, and its points in every mode through ScoreQSO
      (CW 3, Phone 2, FM is Phone, digital an automatic X-QSO);
    * its flags: multipliers once per mode, not per band;
    * the Minnesota entrant's multipliers (the shipped minnesota.dom through
      the real loader): every county counts as MN, the 50 states with MN, DC,
      the 13 provinces and territories -- 64 domestic -- and ONE DX
      multiplier, 'DX', for every country but K, VE, KH6 and KL;
    * the out-of-state entrant's: the 87 counties, each its own;
    * in-state detection: a county typed in any case is in Minnesota;
    * a county line of two, and a rover's new county is a new station;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet): each
      multiplier once on CW and once on Phone, FM as Phone, for a Minnesota
      entrant and for an out-of-state one. *)
unit uTestContestMinnesotaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestMinnesotaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_MinnesotaBandsAndModes;
      procedure Test_MinnesotaPoints;
      procedure Test_MinnesotaFlags;
      procedure Test_MinnesotaInStateMultipliers;
      procedure Test_MinnesotaOutOfStateMultipliersAreTheCounties;
      procedure Test_MinnesotaInStateDXMultiplierIsOne;
      procedure Test_MinnesotaInStateDetectionIgnoresCase;
      procedure Test_MinnesotaCountyLineIsTwoCounties;
      procedure Test_MinnesotaRoverInANewCountyIsANewStation;
      procedure Test_MinnesotaRealEngine;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uContestStateQSOPartyBase,
   (* MN_DX_MULTIPLIER_KEY -- the one DX multiplier's key. *)
   uContestMinnesotaQP,
   uDomFileKeys,
   uTR4WStrings,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   (* A shipped .dom through the real loader, its INCLUDEs followed. *)
   uTestShippedDom,
   (* The party questions every party test asks one way. *)
   uTestQSOPartyRules,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

const
   (* "10 Canadian provinces, 3 Canadian Territories" -- the keys
      minnesota.dom gives them. *)
   CANADIAN_KEYS: array[0..12] of string = (
      'NS', 'QC', 'ON', 'MB', 'SK', 'AB', 'BC', 'NT', 'NB', 'NL', 'NU', 'YT', 'PE');

function MinnesotaHandle: TContestHandle;
begin
   Result := ContestHandleOf(MINNQSOPARTY);
end;

function MakeMinnesota(const aStation: TStationContext): TContestBase;
begin
   Result := Make(MinnesotaHandle, aStation);
end;

(* A Minnesota station (Dakota County, the rules' W0AA/DAK example) or a Texas
   one. The table knows every QTH (uTestContestObjects.WithHostAreaTable): a
   test about POINTS states that every QSO it scores is with a host-area
   station. *)
function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'DAK';
      end
   else
      begin
      Result.MyState := 'TX';
      end;
   Result.MyCountry := 'K';
end;

function MinnesotaQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                      const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K0XYZ';
   Result.Name := 'BOB';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := ShortString(aQTH);
end;

(* The points ScoreQSO gives -- the ONE public scoring entry. *)
function PointsFor(aStation: TStationContext; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType; const aQTH: string): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := MakeMinnesota(aStation);
   try
      qso := MinnesotaQso(aBand, aMode, aExtMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   BANDS, MODES, POINTS, FLAGS
   --------------------------------------------------------------------------- *)

(* "HF: 160m - 10m (excluding WARC bands)." "Phone (SSB, DSB, FM, AM all
   count as Phone) / CW - only". An off-band or off-mode QSO is an automatic
   X-QSO (Q98): logged, 0 points, no multiplier. Asked of the station-less
   identity, as every X-QSO reader asks it. *)
procedure TContestMinnesotaQPTests.Test_MinnesotaBandsAndModes;
var
   identity: TContestBase;
   b: BandType;
   ext: ExtendedModeType;
   expected: boolean;
begin
   BeginTest('Test_MinnesotaBandsAndModes');
   identity := ContestIdentity(MinnesotaHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band160, Band80, Band40, Band20, Band15, Band10];
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when on the rules'' list');
      end;
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'DAK'), '30 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'DAK'), '17 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band6, Phone, eUSB, 'DAK'), '6 m scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band2, FM, eFM, 'DAK'), '2 m scores nothing');

   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eLSB), 'LSB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited ("FM ... count as Phone")');
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'digital submode ' + IntToStr(Ord(ext)) + ' is no mode of the contest ("CW - only")');
      CheckTrue(QSOIsXQSO(identity, MinnesotaQso(Band20, Digital, ext, 'DAK')),
                'so a digital QSO is an X-QSO, submode ' + IntToStr(Ord(ext)));
      end;
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not credited');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eRTTY, 'DAK'), 'RTTY scores nothing');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Digital, eFT8, 'TX'), 'nor FT8, in state');
end;

(* NEW 2027: "Phone QSO's equal 2 points each. CW QSO's equal 3 QSO points
   each." The same for every entrant. FM is Phone. *)
procedure TContestMinnesotaQPTests.Test_MinnesotaPoints;
begin
   BeginTest('Test_MinnesotaPoints');
   CheckEquals(3, PointsFor(StationAt(False), Band20, CW, eCW, 'DAK'), 'outside MN, CW 3');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Phone, eUSB, 'DAK'), 'outside MN, SSB 2');
   CheckEquals(2, PointsFor(StationAt(False), Band80, Phone, eLSB, 'HEN'), 'outside MN, LSB 2');
   CheckEquals(2, PointsFor(StationAt(False), Band10, FM, eFM, 'HEN'), 'outside MN, FM is phone: 2');
   CheckEquals(3, PointsFor(StationAt(True), Band40, CW, eCW, 'TX'), 'in MN, CW with Texas 3');
   CheckEquals(2, PointsFor(StationAt(True), Band40, Phone, eLSB, 'ON'), 'in MN, SSB with Ontario 2');
   CheckEquals(3, PointsFor(StationAt(True), Band160, CW, eCW, 'SCO'),
               'in MN, CW with another MN county 3 ("QSO''s still count")');
   CheckEquals(2, PointsFor(StationAt(True), Band15, Phone, eUSB, 'DX'),
               'in MN, a DX station scores ("may work DXCC countries for points")');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'TX'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'TX'), 'nor this one');
end;

(* "Work stations once per band & mode." NEW 2027: "Multipliers count by mode
   - once for CW and once for SSB" -- by mode, not by band. HF only. *)
procedure TContestMinnesotaQPTests.Test_MinnesotaFlags;
var
   identity: TContestBase;
begin
   BeginTest('Test_MinnesotaFlags');
   identity := ContestIdentity(MinnesotaHandle);
   CheckTrue(identity.QSOByBand, 'a station is worked once per band');
   CheckTrue(identity.QSOByMode, 'and once per mode');
   CheckTrue(identity.MultByMode, 'a multiplier counts once per mode (2027)');
   CheckFalse(identity.MultByBand, 'not once per band');
   CheckFalse(identity.VHFBandsEnabled, 'HF only');
   CheckTrue(identity.RTCCapable, 'Real Time Contesting stays');
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* NEW 2027: "In state county multipliers no longer count for MN stations
   while QSO's still count." "Multipliers for Minnesota Stations: 50 states
   (includes Minnesota), 1 District of Columbia, 10 Canadian provinces, 3
   Canadian Territories, and 1 DX; 65 per mode". The shipped minnesota.dom
   through the real loader: 64 domestic multipliers; the DX one is the
   class's (Test_MinnesotaInStateDXMultiplierIsOne). *)
procedure TContestMinnesotaQPTests.Test_MinnesotaInStateMultipliers;
var
   h: TContestHandle;
   i: integer;
begin
   BeginTest('Test_MinnesotaInStateMultipliers');
   h := MinnesotaHandle;

   CheckEquals('MN', InStateMultiplierOf(h, 'DAK'), 'Dakota County counts as Minnesota');
   CheckEquals('MN', InStateMultiplierOf(h, 'AIT'), 'and Aitkin');
   CheckEquals('MN', InStateMultiplierOf(h, 'WSH'), 'and Washington County');
   CheckEquals('MN', InStateMultiplierOf(h, 'CARL'), 'and a county''s second spelling');
   CheckEquals('MN', InStateMultiplierOf(h, 'MN'), '"50 states (includes Minnesota)"');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DAK'), rmDomestic),
             'and a Minnesota entrant counts it');
   CheckEquals('WA', InStateMultiplierOf(h, 'WA'), 'Washington the state is WA');
   CheckEquals('TX', InStateMultiplierOf(h, 'TX'), 'Texas is a state');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), 'Alaska is');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');
   CheckEquals('DC', InStateMultiplierOf(h, 'DC'), '"1 District of Columbia", on its own');
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana, not Labrador');
   for i := Low(CANADIAN_KEYS) to High(CANADIAN_KEYS) do
      begin
      CheckEquals(CANADIAN_KEYS[i], InStateMultiplierOf(h, CANADIAN_KEYS[i]),
                  CANADIAN_KEYS[i] + ' is its own multiplier');
      end;
   CheckEquals('DX', InStateMultiplierOf(h, 'DX'), '"and 1 DX"');

   (* "65 per mode". *)
   LoadCountyTable('minnesota.dom', False);
   try
      CheckEquals(65, mo.DomList.Count,
                  'minnesota.dom is 50 states (with MN), DC, 13 provinces and territories and DX');
   finally
      FreeCountyTable;
   end;
end;

(* "Multipliers for W/VE and DX (outside Minnesota): MN counties: 87 per
   mode". The shipped county file as an out-of-state session loads it (each
   county its own multiplier), and nothing else in it. *)
procedure TContestMinnesotaQPTests.Test_MinnesotaOutOfStateMultipliersAreTheCounties;
begin
   BeginTest('Test_MinnesotaOutOfStateMultipliersAreTheCounties');
   LoadCountyTable('minnesota_cty.dom', True);
   try
      CheckEquals(87, mo.DomList.Count, 'the county file is 87 multipliers');
      CheckEquals('DAK', MultiplierOf(CountyTable, 'DAK'), 'Dakota County is its own multiplier');
      CheckEquals('CRL', MultiplierOf(CountyTable, 'CARL'), 'Carlton, by its second spelling');
      CheckEquals('WSH', MultiplierOf(CountyTable, 'WSH'), 'Washington County');
      CheckEquals('', MultiplierOf(CountyTable, 'MN'), 'MN alone is no county');
      CheckEquals('', MultiplierOf(CountyTable, 'TX'), 'nor is a state');
      CheckTrue(CountyFileKnowsQTH('dak'), 'a county in lower case is a Minnesota station');
      CheckFalse(CountyFileKnowsQTH('WI'), 'Wisconsin is not');
   finally
      FreeCountyTable;
   end;
   CheckTrue(CountsForEntrant(MinnesotaHandle, False, 'DAK', rmDomestic),
             'outside MN a county counts');
end;

(* "Minnesota stations may work DXCC countries for points and receive 1
   multiplier for working a DX station." ONE DOMESTIC multiplier,
   MN_DX_MULTIPLIER_KEY, written by ScoreQSO as the QSO's DomMultQTH for every
   located country but the USA, Canada, Hawaii and Alaska (states and
   provinces here); nothing outside Minnesota, where the multipliers are "MN
   counties". The DX KIND is not used: the sheet would count it per country. *)
procedure TContestMinnesotaQPTests.Test_MinnesotaInStateDXMultiplierIsOne;

   function KeyAfterScoring(aInState: boolean; const aCountryID: string): string;
   var
      contestObject: TContestBase;
      qso: ContestExchange;
   begin
      contestObject := MakeMinnesota(StationAt(aInState));
      try
         qso := MinnesotaQso(Band20, CW, eCW, 'DX');
         qso.QTH.CountryID := ShortString(aCountryID);
         qso.DomMultQTH := 'KEPT';
         contestObject.ScoreQSO(qso);
         Result := string(qso.DomMultQTH);
      finally
         contestObject.Free;
      end;
   end;

var
   contestObject: TContestBase;
begin
   BeginTest('Test_MinnesotaInStateDXMultiplierIsOne');
   CheckEquals('DX', MN_DX_MULTIPLIER_KEY, 'the key is DX');
   CheckEquals(MN_DX_MULTIPLIER_KEY, KeyAfterScoring(True, 'DL'), 'in MN, Germany counts as DX');
   CheckEquals(MN_DX_MULTIPLIER_KEY, KeyAfterScoring(True, 'JA'),
               'and Japan as the SAME multiplier: one, whichever country');
   CheckEquals(MN_DX_MULTIPLIER_KEY, KeyAfterScoring(True, 'KP4'),
               'Puerto Rico is DX ("DX for non-W/VE")');
   CheckEquals('KEPT', KeyAfterScoring(True, 'K'), 'a US station keeps its own key');
   CheckEquals('KEPT', KeyAfterScoring(True, 'VE'), 'and a Canadian');
   CheckEquals('KEPT', KeyAfterScoring(True, 'KH6'), 'and Hawaii (a state)');
   CheckEquals('KEPT', KeyAfterScoring(True, 'KL'), 'and Alaska (a state)');
   CheckEquals('KEPT', KeyAfterScoring(True, ''), 'a call never located is left alone');
   CheckEquals('KEPT', KeyAfterScoring(False, 'DL'), 'outside MN nothing is written');

   (* NOT THE DX KIND, at any station. *)
   contestObject := MakeMinnesota(StationAt(True));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'in MN there is no DX-kind multiplier');
   finally
      contestObject.Free;
   end;

   (* minnesota.dom lists the same spelling, so the remaining-multiplier list
      crosses it off; a typed DX resolves to it too. *)
   CheckEquals(MN_DX_MULTIPLIER_KEY, InStateMultiplierOf(MinnesotaHandle, 'DX'),
               'minnesota.dom''s DX entry is the class''s key');
end;

(* "MN Stations: First name & county (three letter designator)." The session
   is set up in state when MY STATE is a county the county file declares, in
   any case -- the operator types DAK, the file says Dak. The key is read
   before the '>' the 2027 file adds. *)
procedure TContestMinnesotaQPTests.Test_MinnesotaInStateDetectionIgnoresCase;
var
   countyFile: string;
begin
   BeginTest('Test_MinnesotaInStateDetectionIgnoresCase');
   countyFile := ShippedDomDir + ContestIdentity(MinnesotaHandle).DomesticFileName + '.dom';
   CheckTrue(DomFileOnDiskDeclaresKey(countyFile, 'DAK'), 'DAK is a Minnesota county');
   CheckTrue(DomFileOnDiskDeclaresKey(countyFile, 'dak'), 'in any case');
   CheckTrue(DomFileOnDiskDeclaresKey(countyFile, 'Wsh'), 'Washington County');
   CheckFalse(DomFileOnDiskDeclaresKey(countyFile, 'MN'), 'MN is no county: an MN station sends its county');
   CheckFalse(DomFileOnDiskDeclaresKey(countyFile, 'TX'), 'Texas is out of state');
end;

(* NEW 2027: "Rovers may operate simultaneously from up to 2 counties." *)
procedure TContestMinnesotaQPTests.Test_MinnesotaCountyLineIsTwoCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_MinnesotaCountyLineIsTwoCounties');
   contestObject := MakeMinnesota(NoStation);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(2, party.CountyLineCountiesMax, 'up to two counties');
      CheckTrue(party.CountyLineAllowed, 'a county line is allowed');
      CheckTrue(party.ValidateQTHCount(2, msg), 'two counties are taken');
      CheckEquals('', msg, 'silently');
      CheckFalse(party.ValidateQTHCount(3, msg), 'three are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');
   finally
      contestObject.Free;
   end;
end;

(* "MN mobiles and rovers may be worked once per band & mode from each
   county" -- through the dupe path LogContact takes. *)
procedure TContestMinnesotaQPTests.Test_MinnesotaRoverInANewCountyIsANewStation;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_MinnesotaRoverInANewCountyIsANewStation');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(MinnesotaHandle)),
             'the received county is part of the dupe key');
   RoverDupeAnswers(MinnesotaHandle, 'W0AA/DAK', 'DAK', 'SCO', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'W0AA/DAK from Scott after Dakota, 20 m CW: a new station');
   CheckTrue(sameCountyIsDupe, 'and from Dakota again: a dupe');
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First a Dakota
   County entrant with the shipped minnesota.dom, then a Texas entrant with
   the shipped minnesota_cty.dom.
   --------------------------------------------------------------------------- *)

procedure TContestMinnesotaQPTests.Test_MinnesotaRealEngine;
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
   ctyPath: string;
   h: TContestHandle;
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   i: integer;

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what LogContact
      does with the record it accepts -- the dupe question, the dupe's zero
      points, the sheets. Returns whether it was a dupe. *)


   (* THE SESSION AS FoundContest SETS IT UP: K, VE, KH6 and KL domestic
      (Add_KVEKH6KL, every party); the file for this entrant; the class's
      flags as ApplyContestTraits writes them. *)
   procedure SetUpSession(aInState: boolean; const aFileName: string);
   begin
      DomQTHTable.Free;
      DomQTHTable := TDomQTHTable.Create;
      MultipliersIsCounties := not aInState;
      LoadShippedDomFollowingIncludes(DomQTHTable, aFileName, True, 0);
      StationInHostState := aInState;
      Contest := h;
      ReleaseActiveContest;
      ActiveContest(Contest);
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;
      CallsignsList.Free;
      CallsignsList := TCallsignsList.Create;
      QualifiedDupes.Free;
      QualifiedDupes := TQualifiedDupeSheet.Create;
   end;

begin
   BeginTest('Test_MinnesotaRealEngine');
   h := MinnesotaHandle;
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
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   DomQTHTable := nil;
   CallsignsList := nil;
   QualifiedDupes := nil;
   try
      DomesticCountries.Clear;
      Add_KVEKH6KL;

      (* A DAKOTA COUNTY ENTRANT. *)
      SetUpSession(True, 'minnesota.dom');

      (* "In state county multipliers no longer count for MN stations while
         QSO's still count": a county is the MN multiplier. *)
      dupe := EnterPartyQSO('W0AAA', 'BOB SCO', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'BOB SCO is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals(3, Integer(rx.QSOPoints), '"CW QSO''s equal 3 QSO points each"');
      CheckEquals('MN', UpperCase(string(rx.DomMultQTH)), 'Scott County counts as MN');
      CheckEquals('Mn', string(rx.DomMultQTH), 'spelt as minnesota.dom''s key, Mn');
      CheckTrue(rx.DomesticMult, 'MN is a new multiplier on CW');

      dupe := EnterPartyQSO('K0BBB', 'JIM HEN', Band40, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'JIM HEN is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MN', UpperCase(string(rx.DomMultQTH)), 'Hennepin counts as MN');
      CheckFalse(rx.DomesticMult, 'and is no new multiplier: one MN per mode, not a county');

      (* "Multipliers count by mode - once for CW and once for SSB." *)
      dupe := EnterPartyQSO('W0AAA', 'BOB SCO', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'on SSB too: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), '"Phone QSO''s equal 2 points each"');
      CheckTrue(rx.DomesticMult, 'MN is a new multiplier on Phone');

      (* "SSB, DSB, FM, AM all count as Phone". *)
      dupe := EnterPartyQSO('K0CCC', 'SUE OLM', Band10, FM, eFM, accepted, rx);
      CheckTrue(accepted, 'FM is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'FM scores as Phone');
      CheckFalse(rx.DomesticMult, 'and MN on FM is no new multiplier: FM is Phone');

      dupe := EnterPartyQSO('W5AAA', 'TOM TX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'TOM TX is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Texas is a new multiplier on CW');
      dupe := EnterPartyQSO('W5AAA', 'TOM TX', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'Texas on 40 m CW is not a dupe');
      CheckFalse(rx.DomesticMult, 'but no new multiplier on another band');
      dupe := EnterPartyQSO('W5AAA', 'TOM TX', Band40, Phone, eLSB, accepted, rx);
      CheckTrue(rx.DomesticMult, 'Texas is a new multiplier on Phone');

      (* "receive 1 multiplier for working a DX station". *)
      dupe := EnterPartyQSO('DL1AAA', 'HANS DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a DX station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(3, Integer(rx.QSOPoints), 'for 3 points');
      CheckEquals(MN_DX_MULTIPLIER_KEY, string(rx.DomMultQTH), 'its multiplier is DX, spelt exactly');
      CheckTrue(rx.DomesticMult, 'and DX is a new multiplier on CW');
      CheckFalse(rx.DXMult, 'and no DX-kind multiplier beside it: counted once');
      dupe := EnterPartyQSO('JA1AAA', 'TARO DX', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a Japanese station is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(rx.DomesticMult, 'Japan is no new multiplier: one DX multiplier per mode');
      CheckFalse(rx.DXMult, 'nor a DX-kind one');
      dupe := EnterPartyQSO('JA1AAA', 'TARO DX', Band15, Phone, eUSB, accepted, rx);
      CheckTrue(rx.DomesticMult, 'DX is a new multiplier on Phone');
      CheckFalse(rx.DXMult, 'and still no DX-kind one');

      (* THE RESCORE (RecomputeQSOScoring) of a row that carries the key
         credits it; a row with none gets the key written back by its first
         rescore (SetMultFlags runs before the points there) and is credited
         from the next -- the lag the class header records. *)
      mo.ClearAllMults;
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'PY2AAA';
      rx.Name := 'JOAO';
      rx.QTHString := 'DX';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      ctyLocateCallStripRover(rx.Callsign, rx.QTH);
      rx.DomMultQTH := MN_DX_MULTIPLIER_KEY;
      RecomputeQSOScoring(rx);
      CheckEquals(3, Integer(rx.QSOPoints), 'rescored: 3 points');
      CheckTrue(rx.DomesticMult, 'rescored: a stored DX key is a multiplier');
      mo.ClearAllMults;
      rx.DomMultQTH := '';
      RecomputeQSOScoring(rx);
      CheckEquals(MN_DX_MULTIPLIER_KEY, string(rx.DomMultQTH), 'the first rescore writes the key back');
      RecomputeQSOScoring(rx);
      CheckTrue(rx.DomesticMult, 'and the next credits it');

      (* Digital is no mode of the contest: logged, an X-QSO, nothing earned. *)
      dupe := EnterPartyQSO('W9DIG', 'AL WI', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'an RTTY QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');

      (* A TEXAS ENTRANT: "MN counties: 87 per mode". *)
      SetUpSession(False, 'minnesota_cty.dom');

      dupe := EnterPartyQSO('W0AAA', 'BOB DAK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'BOB DAK is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores 3');
      CheckEquals('DAK', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Dakota is a new multiplier on CW');
      dupe := EnterPartyQSO('K0BBB', 'JIM SCO', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'Scott is another: each county counts outside MN');
      dupe := EnterPartyQSO('W0AAA', 'BOB DAK', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'Dakota on 40 m CW is not a dupe');
      CheckFalse(rx.DomesticMult, 'but no new multiplier on another band');
      dupe := EnterPartyQSO('W0AAA', 'BOB DAK', Band40, Phone, eLSB, accepted, rx);
      CheckEquals(2, Integer(rx.QSOPoints), 'Phone scores 2');
      CheckTrue(rx.DomesticMult, 'Dakota is a new multiplier on Phone');
      dupe := EnterPartyQSO('W0AAA', 'BOB DAK', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Dakota again on 20 m CW IS a dupe');
   finally
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
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
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure TContestMinnesotaQPTests.RunAllTests;
begin
   Test_MinnesotaBandsAndModes;
   Test_MinnesotaPoints;
   Test_MinnesotaFlags;
   Test_MinnesotaInStateMultipliers;
   Test_MinnesotaOutOfStateMultipliersAreTheCounties;
   Test_MinnesotaInStateDXMultiplierIsOne;
   Test_MinnesotaInStateDetectionIgnoresCase;
   Test_MinnesotaCountyLineIsTwoCounties;
   Test_MinnesotaRoverInANewCountyIsANewStation;
   Test_MinnesotaRealEngine;
end;

end.
