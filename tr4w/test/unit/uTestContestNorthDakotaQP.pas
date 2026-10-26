(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

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

(* THE NORTH DAKOTA QSO PARTY -- added 2026-10-26, registered by its id
  (ND-QSO-PARTY). The rules are docs/ContestRules/QSOParties/NorthDakota/
  2026_nd_qsp_party_rules.pdf ("2026 ND QSO Party Rules", revised January
  2026); each test below quotes the rule it holds. Written from
  ADDING_A_CONTEST.md Part A5, copying uTestContestGeorgiaQP; nothing is
  assumed from Georgia's rules.

  WHAT IS PINNED
    * its identity: the id, no legacy number, refused on multi-op, the
      names, the files, the flags, the party base and what it inherits;
    * its bands, and its points in every mode through ScoreQSO; only RTTY
      and PSK count as digital -- every other digital submode is an
      automatic X-QSO;
    * the in-state entrant's multipliers (the shipped northdakota.dom
      through the real loader): counties, 49 states + DC, the Canadian
      provinces and territories; North Dakota and DX are none;
    * the out-of-state entrant's multipliers and the host-area rule,
      against the shipped northdakota_cty.dom;
    * a two-county line, the final score's formula, no power multiplier;
    * a DX entrant sends its own country (NY4I, 2026-10-26);
    * the two .dom files against the rules' county table and multiplier
      total;
    * the dupe rules and the mobile's new county;
    * the Cabrillo columns for an in-state and an out-of-state entrant;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet):
      an out-of-state entrant, then an in-state one. *)
unit uTestContestNorthDakotaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNorthDakotaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NorthDakotaIdentity;
      procedure Test_NorthDakotaBands;
      procedure Test_NorthDakotaPoints;
      procedure Test_NorthDakotaOnlyRTTYAndPSKAreDigital;
      procedure Test_NorthDakotaInStateMultipliers;
      procedure Test_NorthDakotaOutOfStateWorksOnlyNorthDakota;
      procedure Test_NorthDakotaCountyLineIsTwoCounties;
      procedure Test_NorthDakotaDupes;
      procedure Test_NorthDakotaScoreIsPointsTimesMultipliers;
      procedure Test_NorthDakotaCountyFileIsTheRulesTable;
      procedure Test_NorthDakotaInStateFileIsTheRulesMultipliers;
      procedure Test_NorthDakotaCabrilloColumns;
      procedure Test_NorthDakotaRealEngine;
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
   uContestNorthDakotaQP,
   uDomFileKeys,
   uAppStrings,
   uTR4WStrings,
   uPendingCounties,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   uTestExchangeParserStub,
   (* TryLegacyContestOf -- the frozen enum, reached only through it. *)
   uTestRegisteredContests,
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
   (* BuildSingleQsoCabrilloLine -- the X-QSO: prefix, Q119. *)
   uCabrillo,
   MainUnit;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

const
   (* "North Dakota County Abbreviations (53)" -- the rules' table, page 5,
      in its order, as ABBREVIATION=Name. *)
   RULES_COUNTIES: array[0..52] of string = (
      'ADM=Adams', 'BRN=Barnes', 'BSN=Benson', 'BLL=Billings',
      'BOT=Bottineau', 'BOW=Bowman', 'BRK=Burke', 'BUR=Burleigh',
      'CSS=Cass', 'CAV=Cavalier', 'DIK=Dickey', 'DIV=Divide',
      'DUN=Dunn', 'EDY=Eddy', 'EMN=Emmons', 'FOS=Foster',
      'GNV=Golden Valley', 'GFK=Grand Forks', 'GNT=Grant', 'GRG=Griggs',
      'HET=Hettinger', 'KDR=Kidder', 'LMR=La Moure', 'LOG=Logan',
      'MCH=McHenry', 'MCI=McIntosh', 'MCK=McKenzie', 'MCL=McLean',
      'MCR=Mercer', 'MTN=Morton', 'MRL=Mountrail', 'NEL=Nelson',
      'OLR=Oliver', 'PBA=Pembina', 'PRC=Pierce', 'RMY=Ramsey',
      'RSM=Ransom', 'REN=Renville', 'RLD=Richland', 'ROL=Rolette',
      'SGT=Sargent', 'SRN=Sheridan', 'SIX=Sioux', 'SLP=Slope',
      'STK=Stark', 'STL=Steele', 'STN=Stutsman', 'TWR=Towner',
      'TRL=Traill', 'WLH=Walsh', 'WRD=Ward', 'WLS=Wells',
      'WLM=Williams');

   (* "Canadian Abbreviations (13) AB Alberta, BC British Columbia, LB
      Labrador, MB Manitoba, NB New Brunswick, NF Newfoundland, NS Nova
      Scotia, NT Northwest Territory, ON Ontario, PE Prince Edward Is., QC
      Quebec, SK Saskatchewan, YT Yukon Territory" -- every one the rules
      list is accepted. *)
   RULES_CANADIAN: array[0..12] of string = (
      'AB', 'BC', 'LB', 'MB', 'NB', 'NF', 'NS', 'NT', 'ON', 'PE', 'QC', 'SK', 'YT');

function NorthDakotaHandle: TContestHandle;
begin
   if not FindContestById(ND_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('ND-QSO-PARTY is not registered');
      end;
end;

function MakeNorthDakota(const aStation: TStationContext): TContestBase;
begin
   Result := ContestClassFor(NorthDakotaHandle).Create(NorthDakotaHandle);
   Result.SetStation(aStation);
end;

(* A North Dakota station (Cass County) or a Minnesota one. The table knows
   every QTH (uTestContestObjects.WithHostAreaTable): a test about POINTS
   states that every QSO it scores is with a host-area station. The
   host-area rule itself is Test_NorthDakotaOutOfStateWorksOnlyNorthDakota's,
   against the real county file. *)
function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'CSS';
      end
   else
      begin
      Result.MyState := 'MN';
      end;
end;

(* A DX ENTRANT: no MY STATE, and the country FCONTEST derives from MY CALL
   (Settings.My.Country, which CurrentStation hands every contest object --
   the exporters' ActiveContest included). *)
function DXStation(const aCountry: string): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := False;
   Result.MyState := '';
   Result.MyCountry := CallString(aCountry);
end;

function NorthDakotaQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                        const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K0XYZ';
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
   contestObject := MakeNorthDakota(aStation);
   try
      qso := NorthDakotaQso(aBand, aMode, aExtMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE SHIPPED COUNTY FILE, THROUGH THE REAL LOADER, as an out-of-state
   entrant's session loads it (MultipliersIsCounties True) -- with a
   multiplier sheet of its own, so the load touches nothing another test
   reads. GCountyTable is the table CountyFileKnowsQTH asks, the
   TDomesticQTHTest the host-area rule is handed. *)
var
   GCountyTable: TDomQTHTable;
   GSavedSheet: TMultsObject;
   GSavedCounties: boolean;

procedure LoadCountyTable(aCountiesAreMultipliers: boolean);
begin
   GSavedSheet := mo;
   GSavedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := aCountiesAreMultipliers;
   GCountyTable := TDomQTHTable.Create;
   LoadShippedDomFollowingIncludes(GCountyTable, 'northdakota_cty.dom', True, 0);
end;

procedure FreeCountyTable;
begin
   GCountyTable.Free;
   GCountyTable := nil;
   mo.Free;
   mo := GSavedSheet;
   MultipliersIsCounties := GSavedCounties;
end;

(* FindAlias is the table's exact lookup; its keys are stored upper-cased. *)
function CountyFileKnowsQTH(const aQTH: string): boolean;
var
   entry: TDomQTHEntry;
begin
   Result := (GCountyTable <> nil) and
             GCountyTable.FindAlias(UpperCase(Trim(aQTH)), entry);
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestNorthDakotaQPTests.Test_NorthDakotaIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   member: ContestType;
   legacy: integer;
begin
   BeginTest('Test_NorthDakotaIdentity');
   CheckEquals('ND-QSO-PARTY', ND_QSO_PARTY_CONTEST_ID, 'the id constant');
   CheckTrue(FindContestById('ND-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestNorthDakotaQP, 'to its class');
   CheckTrue(TContestNorthDakotaQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly: one host state, its counties, '
             + '"Contacts with only ND Stations count" for everyone outside it');
   CheckEquals('ND-QSO-PARTY', ContestId(h), 'the stored id');

   identity := ContestIdentity(h);
   CheckFalse(TryLegacyContestOf(identity, member), 'a new contest has no ContestType member');
   CheckTrue(member = DUMMYCONTEST, 'so the walk names none');
   CheckFalse(ContestLegacyNumber(h, legacy), 'and no legacy number');
   CheckFalse(ContestCanUseMultiOp(h), 'and is refused on the multi-op network');

   CheckEquals('North Dakota QSO Party', identity.DisplayName, 'display name');
   CheckEquals('North Dakota QSO Party', identity.FriendlyName, 'friendly name');
   (* The rules state no CONTEST: name; the class writes the ADIF
      Contest_ID. *)
   CheckEquals('ND-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('ND-QSO-PARTY', identity.CabrilloContestName('2026 NDQP NY4I', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('ND-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('ND-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the North Dakota QSO Party');
   CheckEquals(468, identity.WA7BNMId, 'WA7BNM ref 468 (NY4I''s value)');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   (* "submit their log Cabrillo file via email ... Email your results to
      fettigrd@gmail.com"; nancyyoshida50@gmail.com is the paper route. *)
   CheckEquals('fettigrd@gmail.com', identity.SubmissionEmail, 'the Cabrillo log address');
   CheckEquals('ND', identity.HostState, 'host state');
   CheckEquals('ND', identity.QSOPartyArea, 'the New Contest prompt names North Dakota');
   CheckEquals('northdakota_cty', identity.DomesticFileName, 'the county file');
   CheckEquals('northdakota', identity.InStateDomesticFileName, 'the in-state file');
   CheckTrue(identity.IsUSQSOParty, 'a US QSO party');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');

   (* "Stations may be worked once per band and mode"; "Multipliers count
      once overall, not once per band or mode"; "6 & 2 meters". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
             'dupes per band and mode, multipliers once overall, 6 m and 2 m on');
   CheckTrue(identity.QSOByBand, 'a station may be worked again on another band');
   CheckTrue(identity.QSOByMode, 'and again in another mode');
   CheckFalse(identity.MultByBand, 'a multiplier is NOT counted again per band');
   CheckFalse(identity.MultByMode, 'nor again per mode');
   CheckTrue(identity.VHFBandsEnabled, '6 m and 2 m');

   (* "ND stations give RST and County. U.S. and Canadian stations give RST
      and State, Province or Territories DX Stations give RST and DX
      country." *)
   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(identity.ExchangeKind),
               'RST and a county, state, province or DX country');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a domestic QTH');
   CheckTrue(ContestUsesDomesticFile(identity), 'looked up in the domestic file');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the domestic QTH is the multiplier');

   (* WHAT THE PARTY BASE GIVES IT, pinned here so a base change is seen. *)
   CheckTrue(identity.StripsRoverCountyFromCall, 'a mobile''s /county is stripped live');
   CheckTrue(identity.SplitsRoverCallOnExport, 'and split on ADIF export');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH,
             '"Mobile ND stations that change counties are considered to be a new '
             + 'station in each new county"');
   CheckTrue(identity.WritesADIFCounty, 'CNTY is written');
   CheckEquals(2, (identity as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '"each county must be worked in a separate contact": a two-county line, '
               + 'one QSO per county (NY4I, 2026-10-26)');

   (* "North Dakota stations may work DXCC countries for points only - no
      multipliers"; outside North Dakota "Contacts with only ND Stations
      count". No zone or prefix multiplier is named for anyone. *)
   contestObject := MakeNorthDakota(StationAt(True));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'in ND: no DX multiplier');
      CheckFalse(contestObject.HasZoneMultiplier, 'in ND: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'in ND: no prefix multiplier');
      CheckEquals(' 5NN CSS', contestObject.CQExchangeDefault(StationAt(True)),
                  'in ND, the CQ exchange sends the county ("ND stations give RST and County")');
   finally
      contestObject.Free;
   end;
   contestObject := MakeNorthDakota(StationAt(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside ND: no DX multiplier');
      CheckFalse(contestObject.HasZoneMultiplier, 'outside ND: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'outside ND: no prefix multiplier');
      CheckEquals(' 5NN MN', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside ND, the state ("U.S. and Canadian stations give RST and State")');
      (* "DX Stations give RST and DX country" -- their own country prefix
         (NY4I, 2026-10-26). *)
      CheckEquals(' 5NN DL', contestObject.CQExchangeDefault(DXStation('DL')),
                  'a DX entrant with no MY STATE sends its country');
   finally
      contestObject.Free;
   end;
end;

(* "Bands: 160 through 10 meters, 6 & 2 meters, (Excluding the WARC
   Bands)" -- 160, 80, 40, 20, 15, 10, 6 and 2 m, nothing else. An off-band
   QSO is an automatic X-QSO: logged, 0 points, no multiplier. *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_NorthDakotaBands');
   identity := ContestIdentity(NorthDakotaHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when on the rules'' list');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(1, PointsFor(StationAt(False), Band160, CW, eCW, 'CSS'), '160 m CW scores');
   CheckEquals(1, PointsFor(StationAt(False), Band10, CW, eCW, 'CSS'), '10 m CW scores');
   CheckEquals(1, PointsFor(StationAt(False), Band6, Phone, eUSB, 'CSS'), '6 m scores');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'CSS'), '2 m scores');
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'CSS'), '30 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'CSS'), '17 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band12, CW, eCW, 'CSS'), '12 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band222, FM, eFM, 'CSS'), '222 MHz scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band432, FM, eFM, 'CSS'), '70 cm scores nothing');
end;

(* "Scoring: All contacts count as 1 point per non-duplicated phone, CW or
   Digital contact on each band." "Phone= (SSB/FM both counts as Phone);
   CW= (CW counts as CW) and Digital = (RTTY/PSK)". "CW, Digital or Phone
   contacts will all count one point." Inside North Dakota and outside it
   alike; in ND, "DXCC countries" score too. *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaPoints;
begin
   BeginTest('Test_NorthDakotaPoints');
   CheckEquals(1, PointsFor(StationAt(False), Band20, CW, eCW, 'CSS'), 'outside ND, CW');
   CheckEquals(1, PointsFor(StationAt(False), Band20, Phone, eUSB, 'CSS'), 'outside ND, SSB');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'BUR'), 'outside ND, FM is phone');
   CheckEquals(1, PointsFor(StationAt(False), Band20, Digital, eRTTY, 'CSS'), 'outside ND, RTTY');
   CheckEquals(1, PointsFor(StationAt(False), Band40, Digital, ePSK31, 'CSS'), 'outside ND, PSK');
   CheckEquals(1, PointsFor(StationAt(True), Band40, CW, eCW, 'MN'), 'in ND, CW with Minnesota');
   CheckEquals(1, PointsFor(StationAt(True), Band40, Phone, eLSB, 'ON'), 'in ND, SSB with Ontario');
   CheckEquals(1, PointsFor(StationAt(True), Band20, Digital, eRTTY, 'BUR'), 'in ND, RTTY with Burleigh');
   CheckEquals(1, PointsFor(StationAt(True), Band15, CW, eCW, 'DL'),
               'in ND, a DX station is a point ("for points only")');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'MN'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'MN'), 'nor this one');
end;

(* "Digital = (RTTY/PSK), NO FT8" -- NY4I, 2026-10-26: ONLY RTTY and PSK
   count as digital. Every other digital submode (FT8, FT4, JT65, JS8,
   MFSK, ...) is an automatic X-QSO (Q98, QSOIsXQSO): logged, 0 points, no
   multiplier. eNoMode and eData mean "some submode of Digital" (an old
   record, a generic data mode) and are credited; reversed RTTY and PSK
   are still RTTY and PSK. Every ExtendedModeType is walked, so a submode
   added to VC is judged here. Asked of the station-less identity, as
   every X-QSO reader asks it. *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaOnlyRTTYAndPSKAreDigital;
const
   RTTY_AND_PSK = [eNoMode, eData, eRTTY, eRTTY_R, ePSK31, ePSK63, ePSK_R];
var
   identity: TContestBase;
   contestObject: TContestBase;
   qso: ContestExchange;
   ext: ExtendedModeType;
begin
   BeginTest('Test_NorthDakotaOnlyRTTYAndPSKAreDigital');
   identity := ContestIdentity(NorthDakotaHandle);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckTrue(ContestCreditsMode(identity, Digital, ext) = (ext in RTTY_AND_PSK),
                'digital submode ' + IntToStr(Ord(ext)) + ' credited exactly when RTTY or PSK');
      qso := NorthDakotaQso(Band20, Digital, ext, 'CSS');
      CheckTrue(QSOIsXQSO(identity, qso) = not (ext in RTTY_AND_PSK),
                'digital submode ' + IntToStr(Ord(ext)) + ' is an X-QSO exactly when not RTTY or PSK');
      end;
   CheckFalse(ContestCreditsMode(identity, Digital, eFT8), 'FT8 is not credited ("NO FT8")');
   CheckFalse(ContestCreditsMode(identity, Digital, eFT4), 'nor FT4');
   CheckFalse(ContestCreditsMode(identity, Digital, eJT65), 'nor JT65');
   CheckFalse(ContestCreditsMode(identity, Digital, eJS8), 'nor JS8');
   CheckFalse(ContestCreditsMode(identity, Digital, eMFSK), 'nor MFSK');
   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY), 'RTTY is');
   CheckTrue(ContestCreditsMode(identity, Digital, ePSK31), 'PSK31 is');
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eLSB), 'LSB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited');

   (* The readers that know only a ModeType key: the dupe sheet and the
      need-multiplier hint. Digital is a mode of this contest. *)
   CheckTrue(ContestCreditsModeKey(identity, Digital), 'the Digital key is credited');
   CheckTrue(ContestCreditsModeKey(identity, CW), 'the CW key is');
   CheckTrue(ContestCreditsModeKey(identity, Phone), 'the Phone key is');

   qso := NorthDakotaQso(Band20, Digital, eFT8, 'CSS');
   CheckTrue(QSOIsXQSO(identity, qso), 'an FT8 QSO is an X-QSO');
   qso := NorthDakotaQso(Band20, Digital, eFT4, 'CSS');
   CheckTrue(QSOIsXQSO(identity, qso), 'an FT4 QSO is an X-QSO');
   qso := NorthDakotaQso(Band20, Digital, eRTTY, 'CSS');
   CheckFalse(QSOIsXQSO(identity, qso), 'an RTTY QSO is not');
   qso := NorthDakotaQso(Band20, CW, eCW, 'CSS');
   CheckFalse(QSOIsXQSO(identity, qso), 'nor a CW QSO');

   (* THE OUTCOME, through ScoreQSO and the multiplier question SetMultFlags
      asks first (QSOIsXQSO) -- for the station-carrying object too. *)
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eFT8, 'CSS'), 'outside ND, FT8 scores 0');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Digital, eFT4, 'MN'), 'in ND, FT4 scores 0');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eJT65, 'CSS'), 'JT65 scores 0');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eJS8, 'CSS'), 'JS8 scores 0');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eMFSK, 'CSS'), 'MFSK scores 0');
   CheckEquals(1, PointsFor(StationAt(False), Band20, Digital, eRTTY, 'CSS'), 'RTTY scores 1');
   CheckEquals(1, PointsFor(StationAt(True), Band40, Digital, ePSK31, 'MN'), 'PSK31 scores 1');
   contestObject := MakeNorthDakota(StationAt(True));
   try
      qso := NorthDakotaQso(Band20, Digital, eFT8, 'MN');
      CheckTrue(QSOIsXQSO(contestObject, qso),
                'an in-state FT8 QSO is an X-QSO, so SetMultFlags gives it no multiplier');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* "Multipliers: ND stations multiply points by the sum of ND Counties (53),
   states/provinces (49 states excluding North Dakota + DC, + 10 Canadian
   provinces + 3 Canadian Territories = 63 W/VE multipliers total)". "All
   Canadian Provinces & Territories count as multipliers for ND stations."
   "North Dakota stations may work DXCC countries for points only - no
   multipliers."

   The shipped northdakota.dom through the real loader (InStateMultiplierOf
   follows its INCLUDEs), and the class's own CountsAsMultiplier
   (CountsForEntrant, the seam SetMultFlags asks).

   THE RULES' CANADIAN LIST AND ITS SUM DISAGREE: the list names LB and NF
   separately and omits Nunavut, while "10 Canadian provinces + 3 Canadian
   Territories" is Newfoundland and Labrador once and Nunavut counted. The
   class follows the sum (P13.DOM and the file's own Nl line): NL, NF and LB
   are ONE multiplier and
   NU is one -- pinned here, and reported as a sponsor question. *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaInStateMultipliers;
var
   h: TContestHandle;
   host: string;
   i: integer;
begin
   BeginTest('Test_NorthDakotaInStateMultipliers');
   h := NorthDakotaHandle;

   CheckEquals('CSS', InStateMultiplierOf(h, 'CSS'), 'Cass County is its own multiplier');
   CheckEquals('WLM', InStateMultiplierOf(h, 'WLM'), 'and Williams, the table''s last');
   CheckEquals('MN', InStateMultiplierOf(h, 'MN'), 'Minnesota is a multiplier');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), 'Alaska is');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');
   CheckEquals('DC', InStateMultiplierOf(h, 'DC'), '"+ DC": its own multiplier');
   CheckEquals('ON', InStateMultiplierOf(h, 'ON'), 'Ontario is');
   CheckEquals('NU', InStateMultiplierOf(h, 'NU'), 'Nunavut is ("3 Canadian Territories")');
   (* NEWFOUNDLAND AND LABRADOR: the standard NL, and the rules' own NF and
      LB, are ONE multiplier. NL was refused for an ND entrant until
      2026-10-26 -- S50P13DC.DOM's Newfoundland entry knew NF, LB and LAB
      but not NL. *)
   CheckEquals('NL', InStateMultiplierOf(h, 'NL'), 'Newfoundland and Labrador, as NL, is');
   CheckEquals('NL', InStateMultiplierOf(h, 'NF'), 'NF is the SAME multiplier');
   CheckEquals('NL', InStateMultiplierOf(h, 'LB'), 'and so is LB');
   (* P13.DOM also spells Newfoundland LA. S50.DOM is included first and the
      first alias added wins, so LA stays Louisiana. *)
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana, not Labrador');
   for i := Low(RULES_CANADIAN) to High(RULES_CANADIAN) do
      begin
      CheckTrue(InStateMultiplierOf(h, RULES_CANADIAN[i]) <> '',
                'the rules'' Canadian abbreviation ' + RULES_CANADIAN[i] + ' is known');
      end;

   (* "49 states excluding North Dakota": the shared file gives ND its
      multiplier, and the class refuses it for an in-state entrant. *)
   host := InStateMultiplierOf(h, 'ND');
   CheckEquals('ND', host, 'northdakota.dom gives ND the multiplier ND (S50.DOM)');
   CheckFalse(CountsForEntrant(h, True, host, rmDomestic), 'in state: North Dakota is no multiplier');
   CheckFalse(CountsForEntrant(h, True, 'Nd', rmDomestic), 'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'MN'), rmDomestic), 'Minnesota counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'CSS'), rmDomestic), 'a county counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DC'), rmDomestic), 'DC counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NU'), rmDomestic), 'Nunavut counts');
   CheckTrue(CountsForEntrant(h, False, host, rmDomestic),
             'outside ND the in-state rule is not asked (the host-area rule is)');

   (* "DXCC countries for points only - no multipliers": the in-state file
      knows no DX entry, so a DX QSO has no domestic multiplier, and the
      contest has no DX multiplier at all. *)
   CheckEquals('', InStateMultiplierOf(h, 'DX'), 'DX is no multiplier');
   CheckEquals('', InStateMultiplierOf(h, 'DL'), 'nor a DX country');
end;

(* "Contacts with only ND Stations count." -- "Outside North Dakota
   stations and DX stations are the 53 ND counties." Q107: an out-of-state
   entrant's QSO with a station the session's table (the shipped
   northdakota_cty.dom, through the real loader) does not know is refused
   when typed, and scores 0 with no multiplier when logged any other way. *)
var
   GShapeSetsQTH: string;

function StubParseShape(const aHelper: string; const aText: string;
                        var aExch: ContestExchange): boolean;
begin
   aExch.QTHString := ShortString(GShapeSetsQTH);
   Result := True;
end;

function ParseSession: TReceivedExchangeSession;
begin
   Result := Default(TReceivedExchangeSession);
   Result.Parsers := StubExchangeParsers(@StubParseShape);
   Result.IsDomesticQTH := @CountyFileKnowsQTH;
   Result.CallWindowHasCall := True;
end;

function OutOfStateStation: TStationContext;
begin
   Result := NoStation;
   Result.IsDomesticQTH := @CountyFileKnowsQTH;
   Result.InHostState := False;
   Result.MyState := 'MN';
end;

function ParseOutOfState(const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := MakeNorthDakota(OutOfStateStation);
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestNorthDakotaQPTests.Test_NorthDakotaOutOfStateWorksOnlyNorthDakota;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
   i: integer;
   code: string;
begin
   BeginTest('Test_NorthDakotaOutOfStateWorksOnlyNorthDakota');
   LoadCountyTable(True);
   try
      (* EVERY ONE OF THE 53 COUNTIES is its own multiplier and a station
         this entrant may work. *)
      CheckEquals(53, mo.DomList.Count, 'the county file is 53 multipliers');
      for i := Low(RULES_COUNTIES) to High(RULES_COUNTIES) do
         begin
         code := Copy(RULES_COUNTIES[i], 1, 3);
         CheckEquals(code, MultiplierOf(GCountyTable, code), code + ' is its own multiplier');
         CheckTrue(CountyFileKnowsQTH(code), code + ' is a North Dakota station');
         end;

      (* TYPED: a county is taken; anything else is refused with the
         party's reason. *)
      CheckTrue(ParseOutOfState('CSS', msg), 'outside ND, a Cass County station');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(ParseOutOfState('wlm', msg), 'Williams, typed in lower case');
      CheckFalse(ParseOutOfState('MN', msg), 'outside ND, a Minnesota station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['ND']), msg, 'with the reason');
      CheckFalse(ParseOutOfState('ON', msg), 'an Ontario station: refused');
      CheckFalse(ParseOutOfState('ND', msg),
                 'ND alone is no county: "ND stations give RST and County"');
      CheckFalse(ParseOutOfState('DX', msg), 'a DX station: refused');

      (* LOGGED: the same rule scores 0 and earns no multiplier. *)
      CheckEquals(1, PointsFor(OutOfStateStation, Band20, CW, eCW, 'BUR'), 'logged: a county scores');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'MN'), 'logged: Minnesota scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'DL'), 'logged: DX scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, ''), 'logged: no QTH scores 0');

      contestObject := MakeNorthDakota(OutOfStateStation);
      try
         qso := NorthDakotaQso(Band20, CW, eCW, 'MN');
         CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                    'and earns no multiplier (the predicate SetMultFlags asks)');
         CheckTrue(QSOIsXQSO(contestObject, qso),
                   'an automatic X-QSO, judged with the entrant (Q119)');
         qso := NorthDakotaQso(Band20, CW, eCW, 'CSS');
         CheckTrue(ContestCreditsWorkedStation(contestObject, qso), 'a county is credited');
         CheckFalse(QSOIsXQSO(contestObject, qso), 'and is no X-QSO');
      finally
         contestObject.Free;
      end;
   finally
      FreeCountyTable;
   end;
end;

(* "Mobile stations may park on a county line but each county must be worked
   in a separate contact." NY4I's reading (2026-10-26): a county-line entry
   (CSS/BUR) already logs ONE QSO PER COUNTY -- that is the separate contact
   -- and a line joins two counties. So one or two pass and three are
   refused. The engine half (two QSOs from one entry) is the real-engine
   test's. *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaCountyLineIsTwoCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_NorthDakotaCountyLineIsTwoCounties');
   contestObject := MakeNorthDakota(NoStation);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(2, party.CountyLineCountiesMax, 'two counties on a line');
      CheckTrue(party.CountyLineAllowed, 'a county line is allowed');
      CheckTrue(party.ValidateQTHCount(1, msg), 'one county');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(party.ValidateQTHCount(2, msg), 'a line of two');
      CheckEquals('', msg, 'nothing to say');
      CheckFalse(party.ValidateQTHCount(3, msg), 'three are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');
   finally
      contestObject.Free;
   end;
end;

(* "Stations may be worked once per band and mode, and once per
   band/mode/county for ND stations." "Mobile ND stations that change
   counties are considered to be a new station in each new county." Through
   the dupe path LogContact takes (uTestQSOPartyRules.RoverDupeAnswers):
   the same call from a new county on the same band and mode is a new QSO;
   from the first county again it is a dupe. The band and mode halves are
   the real engine's, below. *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaDupes;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_NorthDakotaDupes');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(NorthDakotaHandle)),
             'the received county is part of the dupe key');
   RoverDupeAnswers(NorthDakotaHandle, 'K0ND', 'CSS', 'BUR', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'K0ND from Burleigh after Cass, 20 m CW: a new station');
   CheckTrue(sameCountyIsDupe, 'K0ND from Cass again, 20 m CW: a dupe');
   RoverDupeAnswers(NorthDakotaHandle, 'K0ND/M', 'WRD', 'MCH', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'a /M call from McHenry after Ward: a new station');
   CheckTrue(sameCountyIsDupe, 'and from Ward again: a dupe');
end;

(* The rules' final score: "Final Total = Contact Total X Multiplier Total"
   (the summary sheet). "There are no power limitations in this contest,
   within legal limit" -- no power multiplier: QRP, LOW and HIGH score
   alike. The rules' in-state maximum is "116 Total Multipliers". *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaScoreIsPointsTimesMultipliers;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_NorthDakotaScoreIsPointsTimesMultipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 150;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 116;

   station := StationAt(True);
   station.MyPower := cpQRP;
   view := TLoggedQSOList.Create;
   contestObject := MakeNorthDakota(station);
   try
      CheckEquals(150 * 116, contestObject.FinalScore(t, view), 'points x multipliers, QRP');
      station.MyPower := cpLOW;
      contestObject.SetStation(station);
      CheckEquals(150 * 116, contestObject.FinalScore(t, view), 'LOW the same');
      station.MyPower := cpHIGH;
      contestObject.SetStation(station);
      CheckEquals(150 * 116, contestObject.FinalScore(t, view), 'HIGH the same');

      (* Outside North Dakota: "# of North Dakota counties worked (max. 53)
         ... Final Total= Contact Total X Multiplier Total". *)
      contestObject.SetStation(StationAt(False));
      t.QSOPoints := 40;
      t.Mults[AllBands, Both, rmDomestic] := 53;
      CheckEquals(40 * 53, contestObject.FinalScore(t, view), 'outside ND, points x counties');

      t.Mults[AllBands, Both, rmDomestic] := 0;
      CheckEquals(0, contestObject.FinalScore(t, view), 'no multiplier, no score');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   DATA
   --------------------------------------------------------------------------- *)

(* northdakota_cty.dom IS THE RULES' TABLE: the 53 counties of "North Dakota
   County Abbreviations (53)", each abbreviation once, each named as the
   rules name it, each its OWN multiplier -- "the sum of ND Counties (53)"
   for an ND station, "the 53 ND counties" for everyone else, so no line
   maps a county to the state -- and nothing else: no INCLUDE, so an
   out-of-state entrant's table holds only counties (the host-area rule
   reads it). *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaCountyFileIsTheRulesTable;
var
   rulesTable: TStringList;
   lines: TStringList;
   seen: TStringList;
   i: integer;
   key: string;
   line: string;
begin
   BeginTest('Test_NorthDakotaCountyFileIsTheRulesTable');
   rulesTable := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      for i := Low(RULES_COUNTIES) to High(RULES_COUNTIES) do
         begin
         rulesTable.Add(RULES_COUNTIES[i]);
         end;
      CheckEquals(53, rulesTable.Count, 'the rules list 53 counties');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      lines.LoadFromFile(ShippedDomDir + 'northdakota_cty.dom');
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         CheckTrue(Pos('INCLUDE', UpperCase(line)) = 0,
                   'the county file includes nothing, line ' + IntToStr(i + 1));
         key := DomFileLineKey(line);
         if key = '' then
            begin
            Continue;
            end;
         CheckTrue(seen.IndexOf(key) < 0, 'each county once: ' + key);
         seen.Add(key);
         CheckTrue(rulesTable.IndexOfName(key) >= 0, key + ' is in the rules'' table');
         CheckEquals(key + ' = ' + key + ',^' + rulesTable.Values[key], line,
                     'its own multiplier, its own alias, the rules'' name: ' + line);
         end;
      CheckEquals(53, seen.Count, 'northdakota_cty.dom holds the 53 counties and nothing else');
   finally
      seen.Free;
      lines.Free;
      rulesTable.Free;
   end;

   (* AS AN ND STATION READS IT (MultipliersIsCounties False): still 53
      multipliers, not one -- "the sum of ND Counties (53)". *)
   LoadCountyTable(False);
   try
      CheckEquals(53, mo.DomList.Count, 'in state, the 53 counties are 53 multipliers');
      CheckEquals('CSS', MultiplierOf(GCountyTable, 'CSS'), 'Cass counts as Cass');
      CheckEquals('', MultiplierOf(GCountyTable, 'ND'), 'no state is in the county file');
      CheckEquals('', MultiplierOf(GCountyTable, 'MN'), 'nor Minnesota');
   finally
      FreeCountyTable;
   end;
end;

(* northdakota.dom, read as text: the header holds no '=' (the loader has no
   comment syntax, so a header line holding '=' would be a multiplier); the
   counties first, then S50.DOM, DC.DOM and P13.DOM -- S50 BEFORE P13,
   because P13 also spells Newfoundland LA and the first alias added wins;
   each INCLUDE spelt so the loader follows it; and ONE entry of its own,
   Nl = NF,LB, so the rules' NF and LB are the standard NL.
   Then loaded through the real loader: 53 counties + 50 states + DC + 13
   provinces and territories = 117 multipliers (the Nl line adds aliases to
   P13's Nl, not a multiplier), North Dakota among them, which the class
   refuses -- the rules' "116 Total Multipliers". *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaInStateFileIsTheRulesMultipliers;
var
   lines: TStringList;
   includes: string;
   included: string;
   entries: string;
   inHeader: boolean;
   i: integer;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   BeginTest('Test_NorthDakotaInStateFileIsTheRulesMultipliers');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'northdakota.dom');
      includes := '';
      entries := '';
      inHeader := True;
      for i := 0 to lines.Count - 1 do
         begin
         included := DomIncludeName(lines[i]);
         if included <> '' then
            begin
            inHeader := False;
            includes := includes + UpperCase(included) + ' ';
            end
         else
            begin
            CheckFalse(Pos('INCLUDE', UpperCase(TrimLeft(lines[i]))) = 1,
                       'northdakota.dom line ' + IntToStr(i + 1)
                       + ' is an INCLUDE the loader would not follow');
            if inHeader then
               begin
               CheckEquals(0, Pos('=', lines[i]),
                           'northdakota.dom header line ' + IntToStr(i + 1)
                           + ' would be read as an entry');
               end
            else if Pos('=', lines[i]) > 0 then
               begin
               entries := entries + Trim(lines[i]) + '|';
               end;
            end;
         end;
      CheckEquals('NORTHDAKOTA_CTY.DOM S50.DOM DC.DOM P13.DOM ', includes,
                  'the counties first, then the states, DC, and the provinces after the states');
      CheckEquals('Nl = NF,LB|', entries, 'one entry of its own: NF and LB are NL');
   finally
      lines.Free;
   end;

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'northdakota.dom', True, 0);
      CheckEquals(117, mo.DomList.Count,
                  '53 counties, 50 states, DC and 13 provinces and territories');
      CheckEquals('ND', MultiplierOf(table, 'ND'), 'North Dakota is one of them');
      CheckFalse(CountsForEntrant(NorthDakotaHandle, True, MultiplierOf(table, 'ND'), rmDomestic),
                 'and the class refuses it: 117 - 1 = the rules'' 116');
      CheckEquals('CSS', MultiplierOf(table, 'CSS'),
                  'the counties are loaded first, so a county keeps its own code');
      CheckEquals('NL', MultiplierOf(table, 'NL'), 'NL is Newfoundland and Labrador');
      CheckEquals('NL', MultiplierOf(table, 'NF'), 'and NF is the same multiplier');
      CheckEquals('NL', MultiplierOf(table, 'LB'), 'and LB');
      CheckEquals('LA', MultiplierOf(table, 'LA'), 'LA is Louisiana');
      CheckEquals('DC', MultiplierOf(table, 'DC'), 'DC is its own multiplier');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* ---------------------------------------------------------------------------
   EXPORT
   --------------------------------------------------------------------------- *)

(* THE RULES GIVE NO CABRILLO EXAMPLE. They say what a log holds: "UTC, the
   call of the station worked, the band and mode, RST sent and received,
   and the state, province, ND county, or DX country". So the QSO line is
   the standard one with RST and QTH each way: an ND station sends its
   county ("ND stations give RST and County"), anyone else its state or
   province; "DX Stations give RST and DX country". The first part is laid
   out as PostUnit lays every contest's (copied from Georgia's test). *)
procedure TContestNorthDakotaQPTests.Test_NorthDakotaCabrilloColumns;
var
   contestObject: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
   firstPart: string;
   sent: string;
   received: string;
   line: string;

   function Words(const aText: string): string;
   var
      list: TStringList;
   begin
      list := TStringList.Create;
      try
         list.Delimiter := ' ';
         list.StrictDelimiter := False;
         list.DelimitedText := Trim(aText);
         Result := list.CommaText;
      finally
         list.Free;
      end;
   end;

begin
   BeginTest('Test_NorthDakotaCabrilloColumns');
   CheckEquals('ND-QSO-PARTY', ContestIdentity(NorthDakotaHandle).CabrilloContestName('', ''),
               'CONTEST: ND-QSO-PARTY');

   (* AN IN-STATE ENTRANT IN CASS COUNTY WORKS MINNESOTA. *)
   contestObject := MakeNorthDakota(StationAt(True));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'CSS';
      qso := NorthDakotaQso(Band20, CW, eCW, 'MN');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'MN';

      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['14000', contestObject.CabrilloModeString(CW, eCW),
                           2026, 4, 11, 18, 5, 'K0ND']);
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 CSS    ', sent, 'sent: RST and my county');
      CheckEquals('599 MN     ', received, 'received: RST and the state received');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W0AAA', received, '']);
      CheckEquals(Words('QSO: 14000 CW 2026-04-11 1805 K0ND 599 CSS W0AAA 599 MN'), Words(line),
                  'the in-state line, word for word: ' + line);
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');
      CheckEquals('599 CSS    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my county');

      (* A CANADIAN STATION, phone. *)
      ctx.RSTSent := '59';
      ctx.RSTReceived := '59';
      ctx.HisQTH := 'ON';
      qso := NorthDakotaQso(Band20, Phone, eUSB, 'ON');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      CheckEquals('59  CSS    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent on phone: RS and my county');
      CheckEquals('59  ON     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RS and the province');

      (* "DX Stations give RST and DX country": the country as typed; with
         no QTH typed, the DX QTH the call resolved to, else DX. *)
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'DL';
      qso := NorthDakotaQso(Band20, CW, eCW, 'DL');
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a DX station''s column is the country it sent');
      qso := NorthDakotaQso(Band20, CW, eCW, '');
      qso.DXQTH := 'DL';
      ctx.HisQTH := '';
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'nothing typed: the DX QTH');
      qso.DXQTH := '';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'nothing known: DX');
   finally
      contestObject.Free;
   end;

   (* AN OUT-OF-STATE ENTRANT IN MINNESOTA WORKS CASS COUNTY. *)
   contestObject := MakeNorthDakota(StationAt(False));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'MN';
      qso := NorthDakotaQso(Band40, CW, eCW, 'CSS');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'CSS';

      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['7000', contestObject.CabrilloModeString(CW, eCW),
                           2026, 4, 11, 19, 30, 'W0AAA']);
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 MN     ', sent, 'sent: RST and my state');
      CheckEquals('599 CSS    ', received, 'received: RST and the county');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'K0ND', received, '']);
      CheckEquals(Words('QSO: 7000 CW 2026-04-11 1930 W0AAA 599 MN K0ND 599 CSS'), Words(line),
                  'the out-of-state line, word for word: ' + line);
      CheckEquals('599 MN     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my state');

      (* A STATED LOCATION IS NEVER REPLACED BY THE COUNTRY: this
         Minnesota station's country is K. *)
      contestObject.SetStation(DXStation('K'));
      CheckEquals('599 MN     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'a stated MY STATE is sent as stated, whatever the country');
   finally
      contestObject.Free;
   end;

   (* A DX ENTRANT: "DX Stations give RST and DX country" -- its own
      country prefix (NY4I, 2026-10-26). MY STATE is empty, so the class
      sends Station.MyCountry. At export the object is ActiveContest's,
      stamped with CurrentStation, whose MyCountry is Settings.My.Country
      (FCONTEST derives it from MY CALL unless MY COUNTRY is stated). *)
   contestObject := MakeNorthDakota(DXStation('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := '';
      qso := NorthDakotaQso(Band20, CW, eCW, 'CSS');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'CSS';

      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['14000', contestObject.CabrilloModeString(CW, eCW),
                           2026, 4, 11, 20, 15, 'DL1AAA']);
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 DL     ', sent, 'sent: RST and my country');
      CheckEquals('599 CSS    ', received, 'received: RST and the county');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'K0ND', received, '']);
      CheckEquals(Words('QSO: 14000 CW 2026-04-11 2015 DL1AAA 599 DL K0ND 599 CSS'), Words(line),
                  'the DX entrant''s line, word for word: ' + line);
      CheckEquals('599 DL     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my country');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First a
   Minnesota entrant with the shipped northdakota_cty.dom, then a Cass
   County entrant with the shipped northdakota.dom (its INCLUDEs followed by
   uTestShippedDom, since the test binary has no dom folder).
   --------------------------------------------------------------------------- *)

procedure TContestNorthDakotaQPTests.Test_NorthDakotaRealEngine;
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

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what
      LogContact does with the record it accepts -- the dupe question, the
      dupe's zero points, the sheets. The submode is the record's, as the
      radio or WSJT-X would leave it. Returns whether it was a dupe. *)
   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  aMode: ModeType; aExtMode: ExtendedModeType;
                  out aAccepted: boolean; var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
      aRX.ExtMode := aExtMode;
      ActiveMode := aMode;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      aAccepted := ParametersOkay(CallString(aCall), Str40(aExch), aBand, aMode,
                                  14025000, aRX);
      aRX.ceRecordKind := rkQSO;
      aRX.ceContest := Contest;
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

begin
   BeginTest('Test_NorthDakotaRealEngine');
   h := NorthDakotaHandle;
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
      (* AS FoundContest SETS IT UP FOR A MINNESOTA STATION: not in North
         Dakota, so the county file with each county its own multiplier; K,
         VE, KH6 and KL are domestic countries (Add_KVEKH6KL, as for every
         party -- so a US call reaches the domestic parser); and the
         class's flags, as ApplyContestTraits writes them, so a wrong flag
         is seen here as a wrong dupe or multiplier. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'northdakota_cty.dom'),
                'northdakota_cty.dom loads');
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := False;
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* CASS COUNTY, CW. *)
      dupe := Enter('K0CSS', '599 CSS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 CSS is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('CSS', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Cass is a new multiplier');
      CheckEquals(1, Integer(rx.QSOPoints), '"1 point per non-duplicated ... contact"');

      (* "Multipliers count once overall, not once per band or mode." "You
         are allowed to make a Phone, CW and a Digital contact with the same
         station on the same band in each mode." *)
      dupe := Enter('K0CSS', '599 CSS', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores 1');
      CheckFalse(rx.DomesticMult, 'but Cass is NOT a new multiplier on another band');

      dupe := Enter('K0CSS', '59 CSS', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 CSS on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), 'SSB scores 1');
      CheckFalse(rx.DomesticMult, 'nor in another mode');

      dupe := Enter('K0CSS', '599 CSS', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'RTTY is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m RTTY is not a dupe');
      CheckFalse(QSOIsXQSO(ContestIdentity(h), rx), 'RTTY is no X-QSO');
      CheckEquals(1, Integer(rx.QSOPoints), 'RTTY scores 1');
      CheckFalse(rx.DomesticMult, 'and is no new multiplier');

      dupe := Enter('K0CSS', '599 CSS', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Cass again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* "SSB/FM both counts as Phone": FM after SSB on one band is the same
         mode, so a dupe. *)
      dupe := Enter('K0VHF', '59 BUR', Band2, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '2 m SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      dupe := Enter('K0VHF', '59 BUR', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted, '2 m FM is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'the same station on 2 m FM after SSB IS a dupe: FM is phone');

      (* "Mobile ND stations that change counties are considered to be a new
         station in each new county." *)
      dupe := Enter('K0CSS', '599 RMY', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same call from Ramsey on 20 m CW: a new station');
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores');
      CheckTrue(rx.DomesticMult, 'Ramsey is a new multiplier');

      (* "NO FT8": logged, an automatic X-QSO, nothing earned -- Ward stays
         unworked until a credited QSO with it. *)
      dupe := Enter('K0FT', '599 WRD', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'an FT8 QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');
      dupe := Enter('K0FT', '599 WRD', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'so Ward on 40 m CW is still a new multiplier');

      (* "Contacts with only ND Stations count." A US call goes to the
         domestic parser, which refuses a QTH the county file does not know,
         naming the host-area reason when the in-state file knows it
         (DomesticQTHRefusalDomDir: the tree's dom folder, as FoundContest
         leaves it for this station). *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'northdakota_cty.dom';

      accepted := True;
      Enter('W0MN', '599 MN', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a Minnesota station is refused');
      CheckEquals('Improper domestic QTH!! (MN: work ND stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      accepted := True;
      Enter('K0ABC', '599 BUX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a misspelt county is refused');
      CheckEquals('Improper domestic QTH!! (BUX not in northdakota_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the county file');

      accepted := True;
      Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['ND']), string(ExchangeErrorMessage),
                  'with the host-area reason');

      (* "Mobile stations may park on a county line but each county must be
         worked in a separate contact" -- NY4I, 2026-10-26: CSS/BUR is taken
         and logs ONE QSO PER COUNTY. The first county is this QSO; the
         second is queued, and TryLogContact's drain writes it as its own
         QSO. Three counties are refused before anything is queued. *)
      ClearPendingCounties;
      dupe := Enter('K0LINE', '599 CSS/BUR', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a county line of two is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('CSS', UpperCase(string(rx.QTHString)), 'the first county is this QSO');
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores 1');
      CheckEquals(1, PendingCountiesCount, 'one more county is queued');
      CheckEquals('BUR', UpperCase(DequeuePendingCounty), 'Burleigh, as its own QSO');
      ClearPendingCounties;
      accepted := True;
      Enter('K0LINE', '599 CSS/BUR/MTN', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'three counties are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
                  'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;

      (* Q119: THE SAME REFUSED QSO, ARRIVING LOGGED (an import, a peer, an
         edit), is an automatic X-QSO for this entrant. *)
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W0MN';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Frequency := 14025000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'MN';
      rx.tSysTime.qtYear := 26;
      rx.tSysTime.qtMonth := 4;
      rx.tSysTime.qtDay := 11;
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of state, a logged W0MN MN is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx),
                 'and it counts toward no total');
      rx.QTHString := 'CSS';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of state, a logged Cass QSO is not');

      (* NOW A CASS COUNTY ENTRANT: in North Dakota, northdakota.dom (the
         counties, the states, DC and the provinces), each county its own
         multiplier. *)
      MultipliersIsCounties := False;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'northdakota.dom', True, 0);
      StationInHostState := True;
      Settings.Contest.DomesticFilename := 'northdakota.dom';
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      dupe := Enter('W0AAA', '599 MN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in ND, 599 MN is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores 1');
      CheckTrue(rx.DomesticMult, 'Minnesota is a new multiplier');
      dupe := Enter('W0AAA', '59 MN', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'Minnesota on 40 m SSB is not a dupe');
      CheckFalse(rx.DomesticMult, 'nor a new multiplier: once overall');

      dupe := Enter('K0BBB', '599 CSS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'another Cass station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'and Cass is a new multiplier: "the sum of ND Counties (53)"');

      dupe := Enter('K0CCC', '599 ND', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 ND is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('ND', UpperCase(string(rx.DomMultQTH)), 'its multiplier would be ND');
      CheckEquals(1, Integer(rx.QSOPoints), 'and it scores 1');
      CheckFalse(rx.DomesticMult, '"49 states excluding North Dakota": no multiplier');

      dupe := Enter('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, '"+ DC": a new multiplier');

      dupe := Enter('W5LA', '599 LA', Band20, CW, eCW, accepted, rx);
      CheckEquals('LA', UpperCase(string(rx.DomMultQTH)), 'LA is Louisiana');
      CheckTrue(rx.DomesticMult, 'Louisiana is a new multiplier');

      dupe := Enter('VE3AAA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 ON is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Ontario is a new multiplier');

      dupe := Enter('VY0AAA', '599 NU', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NU is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Nunavut is a new multiplier');

      (* THE STANDARD NL -- refused for an ND entrant until 2026-10-26. *)
      dupe := Enter('VO1AAA', '599 NL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NL is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'NL is Newfoundland and Labrador');
      CheckTrue(rx.DomesticMult, 'Newfoundland and Labrador is a new multiplier');
      dupe := Enter('VO1BBB', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NF is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'NF is the same');
      CheckFalse(rx.DomesticMult, 'so no new multiplier');
      dupe := Enter('VO2AAA', '599 LB', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 LB is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'Labrador is Newfoundland and Labrador');
      CheckFalse(rx.DomesticMult, 'so no new multiplier');

      (* "North Dakota stations may work DXCC countries for points only - no
         multipliers." *)
      dupe := Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in ND, a DX station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(1, Integer(rx.QSOPoints), 'for a point');
      CheckFalse(rx.DomesticMult, 'and no domestic multiplier');
      CheckFalse(rx.DXMult, 'and no DX multiplier');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and in state it is no X-QSO');
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

procedure TContestNorthDakotaQPTests.RunAllTests;
begin
   Test_NorthDakotaIdentity;
   Test_NorthDakotaBands;
   Test_NorthDakotaPoints;
   Test_NorthDakotaOnlyRTTYAndPSKAreDigital;
   Test_NorthDakotaInStateMultipliers;
   Test_NorthDakotaOutOfStateWorksOnlyNorthDakota;
   Test_NorthDakotaCountyLineIsTwoCounties;
   Test_NorthDakotaDupes;
   Test_NorthDakotaScoreIsPointsTimesMultipliers;
   Test_NorthDakotaCountyFileIsTheRulesTable;
   Test_NorthDakotaInStateFileIsTheRulesMultipliers;
   Test_NorthDakotaCabrilloColumns;
   Test_NorthDakotaRealEngine;
end;

end.
