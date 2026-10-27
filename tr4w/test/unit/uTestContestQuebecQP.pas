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

(* THE QUEBEC QSO PARTY -- added 2026-10-26 (#128), registered by its id
  (QC-QSO-PARTY). The rules are docs/ContestRules/QSOParties/Quebec/ (the
  sponsor's English and French texts, QC-QSO-PARTY-Rules-EN.txt and
  QC-QSO-PARTY-Rules-FR.txt); NY4I's decisions are on #128. Each test below
  quotes the rule it holds. Written from ADDING_A_CONTEST.md Part A5 in
  uTestContestGeorgiaQP's shape; nothing is assumed from another party's
  rules.

  WHAT IS PINNED
    * its identity: the id, no legacy number, refused on multi-op, the
      names, the files, the flags, the party base and what it inherits (and
      the CNTY it does not write), its own prompt;
    * its bands (no 160 m) and its points in every mode through ScoreQSO;
    * the in-province entrant's multipliers (the shipped quebec.dom through
      the real loader): the 17 regions, the 50 states and DC, the 12 other
      provinces and territories with NF and LB TWO and NT/NWT ONE, and ONE
      DX; QC, VE2 and NL none of them; QUE being Capitale-Nationale;
    * the out-of-province entrant's multipliers and the host-area rule,
      against the shipped quebec_cty.dom;
    * region lines of two, the final score's formula, no bonus (#133), no
      power multiplier;
    * a DX entrant sends "DX" (not its country);
    * the two .dom files against the rules' Appendix I (in both languages)
      and Appendix II;
    * the dupe rules and the mobile's new region;
    * ADIF STATE NL for NF and LB, no CNTY;
    * the Cabrillo columns the rules name;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet): an
      out-of-province entrant, then an in-province one. *)
unit uTestContestQuebecQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestQuebecQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_QuebecIdentity;
      procedure Test_QuebecBands;
      procedure Test_QuebecPoints;
      procedure Test_QuebecNoDigital;
      procedure Test_QuebecInProvinceMultipliers;
      procedure Test_QuebecQUEIsCapitaleNationale;
      procedure Test_QuebecOneDXMultiplierIsDomestic;
      procedure Test_QuebecOutOfProvinceWorksOnlyQuebec;
      procedure Test_QuebecRegionLineIsTwoRegions;
      procedure Test_QuebecDupes;
      procedure Test_QuebecScoreIsPointsTimesMultipliers;
      procedure Test_QuebecRegionFileIsAppendixI;
      procedure Test_QuebecInProvinceFileIsAppendixII;
      procedure Test_QuebecADIFStateAndNoCounty;
      procedure Test_QuebecNewContestPrompt;
      procedure Test_QuebecCabrilloColumns;
      procedure Test_QuebecRealEngine;
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
   uContestQuebecQP,
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
   (* The party questions every party test asks one way, and the shipped
      county file as the host-area table (LoadCountyTable). *)
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
   (* Appendix I, in its order: "1- Bas Saint-Laurent BSA" ... "17-
      Centre-du-Quebec CDQ". *)
   APPENDIX_I_REGIONS: array[0..16] of string = (
      'BSA', 'SLS', 'QUE', 'MAU', 'ETE', 'MTL', 'OTS', 'ATE', 'CND',
      'NDQ', 'GIM', 'CAS', 'LVL', 'LDE', 'LNS', 'MEE', 'CDQ');

   (* Appendix II's Canadian abbreviations other than Quebec, as the
      in-province file keys them: NF and LB TWO, NWT one with NT. *)
   OTHER_PROVINCES: array[0..12] of string = (
      'NF', 'LB', 'PE', 'NB', 'NS', 'ON', 'MB', 'SK', 'AB', 'BC', 'NT', 'YT', 'NU');

   QC_COUNTY_FILE = 'quebec_cty.dom';

function QuebecHandle: TContestHandle;
begin
   if not FindContestById(QC_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('QC-QSO-PARTY is not registered');
      end;
end;

function MakeQuebec(const aStation: TStationContext): TContestBase;
begin
   Result := Make(QuebecHandle, aStation);
end;

(* A Montreal station or a New York one. The table knows every QTH
   (uTestContestObjects.WithHostAreaTable): a test about POINTS states that
   every QSO it scores is with a host-area station. The host-area rule
   itself is Test_QuebecOutOfProvinceWorksOnlyQuebec's, against the real
   region file. *)
function StationAt(aInProvince: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInProvince;
   if aInProvince then
      begin
      Result.MyState := 'MTL';
      Result.MyCountry := 'VE';
      end
   else
      begin
      Result.MyState := 'NY';
      Result.MyCountry := 'K';
      end;
end;

(* A DX ENTRANT: no MY STATE, and the country FCONTEST derives from MY CALL. *)
function DXStation(const aCountry: string): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := False;
   Result.MyState := '';
   Result.MyCountry := CallString(aCountry);
end;

(* An out-of-province entrant whose session table is the shipped region
   file (LoadCountyTable first). *)
function OutOfProvinceStation: TStationContext;
begin
   Result := NoStation;
   Result.IsDomesticQTH := @CountyFileKnowsQTH;
   Result.InHostState := False;
   Result.MyState := 'NY';
   Result.MyCountry := 'K';
end;

function QuebecQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                   const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'VE2XYZ';
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
   contestObject := MakeQuebec(aStation);
   try
      qso := QuebecQso(aBand, aMode, aExtMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* A rules text beside the class: docs/ContestRules/QSOParties/Quebec/. *)
procedure LoadRulesText(const aFileName: string; aLines: TStringList);
begin
   aLines.LoadFromFile(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
                       '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
                       'QSOParties' + PathDelim + 'Quebec' + PathDelim + aFileName);
end;

(* APPENDIX I AS THE RULES PRINT IT: a numbered region name ("6- Montreal",
   "6- Montréal") and, on the next line, its code. Codes in order. *)
procedure ReadAppendixICodes(const aFileName: string; aCodes: TStringList);
var
   lines: TStringList;
   i: integer;
   dash: integer;
begin
   lines := TStringList.Create;
   try
      LoadRulesText(aFileName, lines);
      for i := 0 to lines.Count - 2 do
         begin
         dash := Pos('- ', lines[i]);
         if (dash >= 2) and
            (dash <= 3) and
            (StrToIntDef(Copy(lines[i], 1, dash - 1), 0) > 0) then
            begin
            aCodes.Add(Trim(lines[i + 1]));
            end;
         end;
   finally
      lines.Free;
   end;
end;

(* APPENDIX II AS THE ENGLISH RULES PRINT IT: after "Appendix II", each
   abbreviation alone on its line, under its province's name. *)
procedure ReadAppendixIIAbbreviations(aCodes: TStringList);
var
   lines: TStringList;
   i: integer;
   inAppendix: boolean;
   line: string;
   j: integer;
   allLetters: boolean;
begin
   lines := TStringList.Create;
   try
      LoadRulesText('QC-QSO-PARTY-Rules-EN.txt', lines);
      inAppendix := False;
      for i := 0 to lines.Count - 1 do
         begin
         line := Trim(lines[i]);
         if Pos('Appendix II:', line) = 1 then
            begin
            inAppendix := True;
            Continue;
            end;
         if (not inAppendix) or
            (Length(line) < 2) or
            (Length(line) > 3) then
            begin
            Continue;
            end;
         allLetters := True;
         for j := 1 to Length(line) do
            begin
            if not CharInSet(line[j], ['A'..'Z']) then
               begin
               allLetters := False;
               end;
            end;
         if allLetters then
            begin
            aCodes.Add(line);
            end;
         end;
   finally
      lines.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestQuebecQPTests.Test_QuebecIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   member: ContestType;
   legacy: integer;
   inProvince: boolean;
begin
   BeginTest('Test_QuebecIdentity');
   CheckEquals('QC-QSO-PARTY', QC_QSO_PARTY_CONTEST_ID, 'the id constant');
   CheckTrue(FindContestById('QC-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestQuebecQP, 'to its class');
   CheckTrue(TContestQuebecQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly: one host province, its regions, '
             + '"Non-VE2 stations obtain points for contacts for VE2 stations only"');
   CheckEquals('QC-QSO-PARTY', ContestId(h), 'the stored id');

   identity := ContestIdentity(h);
   CheckFalse(TryLegacyContestOf(identity, member), 'a new contest has no ContestType member');
   CheckTrue(member = DUMMYCONTEST, 'so the walk names none');
   CheckFalse(ContestLegacyNumber(h, legacy), 'and no legacy number');
   CheckFalse(ContestCanUseMultiOp(h), 'and is refused on the multi-op network');

   CheckEquals('Quebec QSO Party', identity.DisplayName, 'display name');
   CheckEquals('Quebec QSO Party', identity.FriendlyName, 'friendly name');
   (* The sponsor states no CONTEST: value; WA7BNM 53 and ADIF 3.1.7 say
      QC-QSO-PARTY. *)
   CheckEquals('QC-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('QC-QSO-PARTY', identity.CabrilloContestName('2026 QCQP VE2XYZ', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('QC-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('QC-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the Quebec QSO Party');
   (* "Upcoming dates are listed on
      https://www.contestcalendar.com/contestdetails.php?ref=53". *)
   CheckEquals(53, identity.WA7BNMId, 'WA7BNM ref 53');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   (* "Log entries shall be submitted in Cabrillo format at
      https://quebecqsoparty.org/soumission-qso-qso-download/". *)
   CheckEquals('', identity.SubmissionEmail, 'no submission e-mail');
   CheckEquals('QC', identity.HostState, 'host province, the ADIF code');
   CheckEquals('QC', identity.QSOPartyArea, 'its area');
   CheckEquals('quebec_cty', identity.DomesticFileName, 'the region file');
   CheckEquals('quebec', identity.InStateDomesticFileName, 'the in-province file');
   CheckTrue(identity.IsUSQSOParty, 'set up as a party (BC''s and Ontario''s precedent)');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');
   CheckFalse(identity.RequiresCabrilloLocation, 'LOCATION is not asked for');

   (* "A station can be contacted twice per band, once on phone and once on
      CW"; "one multiplier point ... on each frequency band ... No additional
      multipliers are given for working multiple modes"; "All amateur bands
      between 80 et 2 m". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand, cfVHFBandsEnabled],
             'dupes per band and mode, multipliers per band, 6 m and 2 m on');
   CheckTrue(identity.QSOByBand, 'a station may be worked again on another band');
   CheckTrue(identity.QSOByMode, 'and again in another mode');
   CheckTrue(identity.MultByBand, 'a multiplier counts again on each band');
   CheckFalse(identity.MultByMode, 'but NOT again per mode');
   CheckTrue(identity.VHFBandsEnabled, '6 m and 2 m');

   (* "VE2 stations: Must send a signal report and their administrative
      region abbreviation"; "Non-VE2 stations: Must send a signal report and
      their province, US state or DX for other entities"; "Other DXCC
      entities must be logged as DX" -- every QTH from the table. *)
   CheckEquals(Ord(RSTDomesticQTHExchange), Ord(identity.ExchangeKind),
               'RST and a code from the domestic file, DX included');
   CheckEquals(Ord(NoInitialExchange), Ord(identity.InitialExchangeKind), 'no initial exchange');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a domestic QTH');
   CheckTrue(ContestUsesDomesticFile(identity), 'looked up in the domestic file');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the domestic QTH is the multiplier');

   (* WHAT THE PARTY BASE GIVES IT, pinned here so a base change is seen. *)
   CheckTrue(identity.StripsRoverCountyFromCall, 'a mobile''s /region is stripped live ("VE2xxx/MTL")');
   CheckTrue(identity.SplitsRoverCallOnExport, 'and split on ADIF export');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH,
             'a worked mobile in a new region is a new QSO');
   (* NY4I: ADIF county not written -- ADIF defines no Canadian CNTY. *)
   CheckFalse(identity.WritesADIFCounty, 'CNTY is NOT written');
   CheckEquals(2, (identity as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '"deux zones" -- a region line is two regions');

   (* NO DX, ZONE OR PREFIX MULTIPLIER OF THE ENGINE'S KINDS for any
      entrant: the one DX multiplier is quebec.dom's Dx entry. *)
   for inProvince := False to True do
      begin
      contestObject := MakeQuebec(StationAt(inProvince));
      try
         CheckFalse(contestObject.HasDXMultiplier, 'no engine DX multiplier');
         CheckFalse(contestObject.HasZoneMultiplier, 'no zone multiplier');
         CheckFalse(contestObject.HasPrefixMultiplier, 'no prefix multiplier');
      finally
         contestObject.Free;
      end;
      end;

   contestObject := MakeQuebec(StationAt(True));
   try
      CheckEquals(' 5NN MTL', contestObject.CQExchangeDefault(StationAt(True)),
                  'in Quebec, the CQ exchange sends the region code');
      CheckEquals(' 5NN NY', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside Quebec, the state');
      (* "province, US state or DX for other entities" -- DX, not a prefix. *)
      CheckEquals(' 5NN DX', contestObject.CQExchangeDefault(DXStation('DL')),
                  'a DX entrant with no MY STATE sends DX');
   finally
      contestObject.Free;
   end;
end;

(* "Frequencies: All amateur bands between 80 et 2 m, excepted WARC bands."
   -- 80, 40, 20, 15, 10, 6 and 2 m. NO 160 m (NY4I: DXLog lists it,
   wrongly). An off-band QSO is an automatic X-QSO: logged, 0 points, no
   multiplier. *)
procedure TContestQuebecQPTests.Test_QuebecBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_QuebecBands');
   identity := ContestIdentity(QuebecHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band80, Band40, Band20, Band15, Band10, Band6, Band2];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when on the rules'' list');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(0, PointsFor(StationAt(False), Band160, CW, eCW, 'MTL'), '160 m scores NOTHING');
   CheckTrue(QSOIsXQSO(identity, QuebecQso(Band160, CW, eCW, 'MTL')), 'a 160 m QSO is an X-QSO');
   CheckEquals(2, PointsFor(StationAt(False), Band80, CW, eCW, 'MTL'), '80 m scores');
   CheckEquals(2, PointsFor(StationAt(False), Band10, CW, eCW, 'MTL'), '10 m scores');
   CheckEquals(1, PointsFor(StationAt(False), Band6, Phone, eUSB, 'MTL'), '6 m scores');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'MTL'), '2 m scores');
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'MTL'), '30 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'MTL'), '17 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band12, CW, eCW, 'MTL'), '12 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band222, FM, eFM, 'MTL'), '222 MHz is above 2 m');
   CheckEquals(0, PointsFor(StationAt(False), Band432, FM, eFM, 'MTL'), '70 cm scores nothing');
end;

(* "1 point per QSO on phone on each frequency band / 2 points per QSO on CW
   on each frequency band." Phone is "SSB or FM". The same for both
   entrants and for a DX station worked from Quebec ("The VE2 stations
   obtain points for contacts with all stations"). *)
procedure TContestQuebecQPTests.Test_QuebecPoints;
begin
   BeginTest('Test_QuebecPoints');
   CheckEquals(2, PointsFor(StationAt(False), Band20, CW, eCW, 'MTL'), 'outside, CW 2');
   CheckEquals(1, PointsFor(StationAt(False), Band20, Phone, eUSB, 'MTL'), 'outside, SSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band40, Phone, eLSB, 'OTS'), 'outside, LSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'OTS'), 'outside, FM is phone: 1');
   CheckEquals(2, PointsFor(StationAt(True), Band40, CW, eCW, 'NY'), 'in Quebec, CW with New York');
   CheckEquals(1, PointsFor(StationAt(True), Band40, Phone, eLSB, 'ON'), 'in Quebec, SSB with Ontario');
   CheckEquals(2, PointsFor(StationAt(True), Band15, CW, eCW, 'DX'),
               'in Quebec, a DX station scores ("contacts with all stations")');
   CheckEquals(2, PointsFor(DXStation('DL'), Band20, CW, eCW, 'MTL'), 'a DX entrant, CW 2');
   CheckEquals(1, PointsFor(DXStation('DL'), Band20, Phone, eUSB, 'MTL'), 'a DX entrant, SSB 1');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'NY'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'NY'), 'nor this one');
end;

(* "Modes: Phone (SSB or FM) and Morse code (CW)." Every digital submode is
   an automatic X-QSO (Q98, QSOIsXQSO); CW, phone and FM are credited. Every
   ExtendedModeType is walked, asked of the station-less identity as every
   X-QSO reader asks it. *)
procedure TContestQuebecQPTests.Test_QuebecNoDigital;
var
   identity: TContestBase;
   qso: ContestExchange;
   ext: ExtendedModeType;
begin
   BeginTest('Test_QuebecNoDigital');
   identity := ContestIdentity(QuebecHandle);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'digital submode ' + IntToStr(Ord(ext)) + ' is not credited');
      qso := QuebecQso(Band20, Digital, ext, 'MTL');
      CheckTrue(QSOIsXQSO(identity, qso), 'digital submode ' + IntToStr(Ord(ext)) + ' is an X-QSO');
      end;
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eLSB), 'LSB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited');
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not credited');
   CheckTrue(ContestCreditsModeKey(identity, CW), 'the CW key is');
   CheckTrue(ContestCreditsModeKey(identity, Phone), 'the Phone key is');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eFT8, 'MTL'), 'FT8 scores 0');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Digital, eRTTY, 'NY'), 'RTTY scores 0');
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* "For all stations, one multiplier point is given for each first contact
   made in each administrative region." "Additionally, a VE2 station is given
   one multiplier point for each first contact with a province or Canadian
   territory, US state or DX ... Only one DX multiplier is given for entities
   worked outside of Canada or USA." "the Province of Quebec (QC) is not a
   valid territory entry." "Hawaii HI (KH6), Alaska AK (KL7) and District of
   Columbia DC shall be included in the continental states but KP2 and KP4
   are excluded." The shipped quebec.dom through the real loader
   (InStateMultiplierOf follows its INCLUDEs), and the class's own
   CountsAsMultiplier (CountsForEntrant, the seam SetMultFlags asks). NY4I:
   NF and LB are TWO, NT and NWT ONE, DC its own. *)
procedure TContestQuebecQPTests.Test_QuebecInProvinceMultipliers;
var
   h: TContestHandle;
   i: integer;
begin
   BeginTest('Test_QuebecInProvinceMultipliers');
   h := QuebecHandle;

   for i := Low(APPENDIX_I_REGIONS) to High(APPENDIX_I_REGIONS) do
      begin
      CheckEquals(APPENDIX_I_REGIONS[i], InStateMultiplierOf(h, APPENDIX_I_REGIONS[i]),
                  APPENDIX_I_REGIONS[i] + ' is its own multiplier in Quebec too ("for all stations")');
      end;
   CheckEquals('', InStateMultiplierOf(h, 'QC'), 'QC is no multiplier: "not a valid territory entry"');
   CheckEquals('', InStateMultiplierOf(h, 'VE2'), 'nor VE2');
   CheckEquals('', InStateMultiplierOf(h, 'PQ'), 'nor PQ');

   CheckEquals('NY', InStateMultiplierOf(h, 'NY'), 'New York is a state');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), 'Alaska is');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');
   CheckEquals('DC', InStateMultiplierOf(h, 'DC'), 'DC is its own multiplier');
   CheckEquals('MD', InStateMultiplierOf(h, 'MD'), 'and Maryland its own');
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana');
   CheckEquals('', InStateMultiplierOf(h, 'KP4'), '"KP2 and KP4 are excluded": logged as DX');
   CheckEquals('', InStateMultiplierOf(h, 'PR'), 'nor PR');

   for i := Low(OTHER_PROVINCES) to High(OTHER_PROVINCES) do
      begin
      CheckEquals(OTHER_PROVINCES[i], InStateMultiplierOf(h, OTHER_PROVINCES[i]),
                  OTHER_PROVINCES[i] + ' is its own province or territory multiplier');
      end;
   CheckEquals('NF', InStateMultiplierOf(h, 'NF'), 'Newfoundland is NF');
   CheckEquals('LB', InStateMultiplierOf(h, 'LB'), 'and Labrador a SECOND multiplier, LB');
   CheckEquals('', InStateMultiplierOf(h, 'NL'), 'NL names neither, so it is no entry');
   CheckEquals('NT', InStateMultiplierOf(h, 'NWT'), 'NWT is the Northwest Territories, NT');
   CheckEquals('', InStateMultiplierOf(h, 'VE8'), 'no call-area alias was added');

   (* "Other DXCC entities must be logged as DX": ONE multiplier. *)
   CheckEquals('DX', InStateMultiplierOf(h, 'DX'), 'DX is the one DX multiplier');
   CheckEquals('', InStateMultiplierOf(h, 'DL'), 'a DX country is no entry');

   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NY'), rmDomestic), 'New York counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'MTL'), rmDomestic), 'a region counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DX'), rmDomestic), 'DX counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'LB'), rmDomestic), 'Labrador counts');
   CheckTrue(CountsForEntrant(h, False, InStateMultiplierOf(h, 'MTL'), rmDomestic),
             'outside Quebec a region counts (the host-area rule is a separate question)');
end;

(* NY4I on #128: "P12/P13 give Quebec the alias QUE, which is also the
   Capitale-Nationale region code, and VE2, which would break the rover
   strip. Quebec gets its own province rows." Through the real loader and
   the shipped files: QUE is Capitale-Nationale, neither P12 nor P13 is
   included, and VE2 is known to neither table -- so the rover strip leaves
   "W2ABC/VE2" (the rules' outsider operating in Quebec) whole. *)
procedure TContestQuebecQPTests.Test_QuebecQUEIsCapitaleNationale;
var
   h: TContestHandle;
   table: TDomQTHTable;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   includes: string;
begin
   BeginTest('Test_QuebecQUEIsCapitaleNationale');
   h := QuebecHandle;
   CheckEquals('QUE', InStateMultiplierOf(h, 'QUE'), 'QUE is Capitale-Nationale in Quebec');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      includes := LoadShippedDomFollowingIncludes(table, 'quebec.dom', True, 0);
      CheckEquals('QUE', MultiplierOf(table, 'QUE'), 'the loaded table: QUE is its own region');
      CheckEquals('QUE', QTHOf(table, 'QUE'), 'and its QTH is Capitale-Nationale''s');
      CheckEquals('', MultiplierOf(table, 'VE2'), 'VE2 is no QTH: the rover strip keeps /VE2');
      CheckEquals(0, Pos('P12.DOM', includes), 'P12.DOM is not included');
      CheckEquals(0, Pos('P13.DOM', includes), 'P13.DOM is not included');
      CheckEquals(0, Pos('P14', includes), 'nor P14');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;

   (* And outside Quebec, where the region file alone is the table. *)
   LoadCountyTable(QC_COUNTY_FILE, True);
   try
      CheckEquals('QUE', MultiplierOf(CountyTable, 'QUE'), 'outside Quebec QUE is Capitale-Nationale');
      CheckTrue(CountyFileKnowsQTH('QUE'), 'a Quebec station');
      CheckFalse(CountyFileKnowsQTH('VE2'), 'VE2 is no region');
      CheckFalse(CountyFileKnowsQTH('QC'), 'nor QC');
   finally
      FreeCountyTable;
   end;
end;

(* "Only one DX multiplier is given for entities worked outside of Canada or
   USA" -- per band (NY4I). It is quebec.dom's Dx entry, a DOMESTIC
   multiplier, so the engine's DX multiplier is off for every entrant and no
   DX key is ever given. Per band is the real engine's. *)
procedure TContestQuebecQPTests.Test_QuebecOneDXMultiplierIsDomestic;
var
   contestObject: TContestBase;
   qso: ContestExchange;
   key: DXMultiplierString;
   inProvince: boolean;
begin
   BeginTest('Test_QuebecOneDXMultiplierIsDomestic');
   for inProvince := False to True do
      begin
      contestObject := MakeQuebec(StationAt(inProvince));
      try
         CheckFalse(ContestHasDXMultiplier(contestObject), 'no engine DX multiplier');
         qso := QuebecQso(Band20, CW, eCW, 'DX');
         qso.QTH.CountryID := 'DL';
         CheckFalse(ContestDXMultiplierKey(contestObject, qso, key), 'so no DX key for Germany');
         CheckEquals('', string(key), 'and none written');
      finally
         contestObject.Free;
      end;
      end;
   CheckEquals('DX', InStateMultiplierOf(QuebecHandle, 'DX'), 'the DX multiplier is the Dx entry');
   CheckTrue(CountsForEntrant(QuebecHandle, True, 'DX', rmDomestic), 'counted as a domestic one');
end;

(* "Non-VE2 stations obtain points for contacts for VE2 stations only."
   "Non-VE2 stations ... must log the received signal report as well as the
   administrative region (see Appendix I) of the VE2 station." Q107: an
   out-of-province entrant's QSO with a station the session's table (the
   shipped quebec_cty.dom, through the real loader) does not know is refused
   when typed, and is an X-QSO when logged any other way. *)
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

function ParseOutOfProvince(const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := MakeQuebec(OutOfProvinceStation);
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestQuebecQPTests.Test_QuebecOutOfProvinceWorksOnlyQuebec;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
   i: integer;
begin
   BeginTest('Test_QuebecOutOfProvinceWorksOnlyQuebec');
   LoadCountyTable(QC_COUNTY_FILE, True);
   try
      (* EVERY ONE OF THE 17 REGIONS is its own multiplier and a station this
         entrant may work. *)
      CheckEquals(17, mo.DomList.Count, 'the region file is 17 multipliers');
      for i := Low(APPENDIX_I_REGIONS) to High(APPENDIX_I_REGIONS) do
         begin
         CheckEquals(APPENDIX_I_REGIONS[i], MultiplierOf(CountyTable, APPENDIX_I_REGIONS[i]),
                     APPENDIX_I_REGIONS[i] + ' is its own multiplier');
         CheckTrue(CountyFileKnowsQTH(APPENDIX_I_REGIONS[i]), APPENDIX_I_REGIONS[i] + ' is a Quebec station');
         end;

      (* TYPED: a region is taken; anything else is refused with the party's
         reason. *)
      CheckTrue(ParseOutOfProvince('MTL', msg), 'outside Quebec, a Montreal station');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(ParseOutOfProvince('ots', msg), 'Outaouais, typed in lower case');
      CheckFalse(ParseOutOfProvince('NY', msg), 'outside Quebec, a New York station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['QC']), msg, 'with the reason');
      CheckFalse(ParseOutOfProvince('ON', msg), 'an Ontario station: refused');
      CheckFalse(ParseOutOfProvince('QC', msg),
                 'QC alone is no region: "Logging QSOs with VE2 stations must use the Quebec administrative region"');
      CheckFalse(ParseOutOfProvince('VE2', msg), 'nor VE2');
      CheckFalse(ParseOutOfProvince('DX', msg), 'a DX station: refused');

      (* LOGGED: the same rule scores 0 and earns no multiplier. *)
      CheckEquals(2, PointsFor(OutOfProvinceStation, Band20, CW, eCW, 'LVL'), 'logged: a region scores');
      CheckEquals(0, PointsFor(OutOfProvinceStation, Band20, CW, eCW, 'NY'), 'logged: New York scores 0');
      CheckEquals(0, PointsFor(OutOfProvinceStation, Band20, CW, eCW, 'DX'), 'logged: DX scores 0');
      CheckEquals(0, PointsFor(OutOfProvinceStation, Band20, CW, eCW, 'QC'), 'logged: QC scores 0');
      CheckEquals(0, PointsFor(OutOfProvinceStation, Band20, CW, eCW, ''), 'logged: no QTH scores 0');

      contestObject := MakeQuebec(OutOfProvinceStation);
      try
         qso := QuebecQso(Band20, CW, eCW, 'NY');
         CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                    'and earns no multiplier (the predicate SetMultFlags asks)');
         CheckTrue(QSOIsXQSO(contestObject, qso), 'an automatic X-QSO, judged with the entrant (Q119)');
         qso := QuebecQso(Band20, CW, eCW, 'MTL');
         CheckTrue(ContestCreditsWorkedStation(contestObject, qso), 'a region is credited');
         CheckFalse(QSOIsXQSO(contestObject, qso), 'and is no X-QSO');
      finally
         contestObject.Free;
      end;
   finally
      FreeCountyTable;
   end;
end;

(* French: "Une station mobile sur une limite entre deux zones de
   multiplicateurs doit effectuer un contact independant" (two zones);
   English: "on a boundary between 2 or more administrative regions". NY4I:
   built as 2 (the question stays open on #128). The engine half (one QSO
   per region, one queued) is the real-engine test's. *)
procedure TContestQuebecQPTests.Test_QuebecRegionLineIsTwoRegions;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_QuebecRegionLineIsTwoRegions');
   contestObject := MakeQuebec(NoStation);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(2, party.CountyLineCountiesMax, 'two regions');
      CheckTrue(party.CountyLineAllowed, 'a region line is allowed');
      CheckTrue(party.ValidateQTHCount(1, msg), 'one region');
      CheckTrue(party.ValidateQTHCount(2, msg), 'a line of two');
      CheckEquals('', msg, 'nothing to say');
      CheckFalse(party.ValidateQTHCount(3, msg), 'three are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');
   finally
      contestObject.Free;
   end;
end;

(* "A station can be contacted twice per band, once on phone and once on
   CW." "Only one QSO per station for each band and each mode can provide
   points." A worked mobile in a new region is a new QSO (the party base's
   received-QTH dupe key; the rules' "VE2xxx/MTL ... anticipate their moves
   to a new multiplier area"). Through the dupe path LogContact takes
   (uTestQSOPartyRules.RoverDupeAnswers). Phone and FM are one dupe mode --
   the engine's (DupeSlot), pinned in the real-engine test. *)
procedure TContestQuebecQPTests.Test_QuebecDupes;
var
   newRegionIsDupe: boolean;
   sameRegionIsDupe: boolean;
begin
   BeginTest('Test_QuebecDupes');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(QuebecHandle)),
             'the received region is part of the dupe key');
   CheckTrue(ContestDupeModeOf(ContestIdentity(QuebecHandle), CW) = CW, 'CW is its own dupe mode');
   CheckTrue(ContestDupeModeOf(ContestIdentity(QuebecHandle), Phone) = Phone, 'and phone its own');
   RoverDupeAnswers(QuebecHandle, 'VE2ABC', 'MTL', 'LVL', newRegionIsDupe, sameRegionIsDupe);
   CheckFalse(newRegionIsDupe, 'VE2ABC from Laval after Montreal, 20 m CW: a new station');
   CheckTrue(sameRegionIsDupe, 'VE2ABC from Montreal again, 20 m CW: a dupe');
   RoverDupeAnswers(QuebecHandle, 'VE2ABC/M', 'QUE', 'CAS', newRegionIsDupe, sameRegionIsDupe);
   CheckFalse(newRegionIsDupe, 'a /M call from Chaudiere-Appalaches after Quebec City: a new station');
   CheckTrue(sameRegionIsDupe, 'and from Capitale-Nationale again: a dupe');
end;

(* "QSO-score = (Total of the QSO points) * (Total of the multiplier
   points)." "Starting in 2026, there is no bonus station(s)." No power
   multiplier: QRP, Low and High score alike (the x1 / x2 of "Awards per
   club" is the club award's).

   NOT BUILT, #133: the mobile's "total of the multiplication points made in
   each administrative region activated" and "300 bonus points for each
   Quebec administrative region activated". The score is points x
   multipliers only -- pinned so the day #133 lands is seen here. *)
procedure TContestQuebecQPTests.Test_QuebecScoreIsPointsTimesMultipliers;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
begin
   BeginTest('Test_QuebecScoreIsPointsTimesMultipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 500;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 82;

   station := StationAt(True);
   station.MyPower := cpQRP;
   view := TLoggedQSOList.Create;
   contestObject := MakeQuebec(station);
   try
      CheckEquals(41000, contestObject.FinalScore(t, view), 'points x multipliers, QRP');
      station.MyPower := cpLOW;
      contestObject.SetStation(station);
      CheckEquals(41000, contestObject.FinalScore(t, view), 'LOW the same');
      station.MyPower := cpHIGH;
      contestObject.SetStation(station);
      CheckEquals(41000, contestObject.FinalScore(t, view), 'HIGH the same');

      (* A LOG OF REAL QSOs PAYS NO BONUS -- not even with a club or old
         bonus-looking call in it. *)
      qso := QuebecQso(Band20, CW, eCW, 'MTL');
      qso.Callsign := 'VE2CRO';
      view.Add(qso);
      qso.Callsign := 'VE2QQP';
      qso.Band := Band40;
      view.Add(qso);
      CheckEquals(0, contestObject.BonusPoints(t, view), 'no bonus: "there is no bonus station(s)"');
      CheckEquals(41000, contestObject.FinalScore(t, view), 'and the score is still points x multipliers');

      contestObject.SetStation(StationAt(False));
      t.QSOPoints := 120;
      t.Mults[AllBands, Both, rmDomestic] := 30;
      CheckEquals(120 * 30, contestObject.FinalScore(t, view), 'outside Quebec, points x regions');

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

(* quebec_cty.dom IS APPENDIX I: "List of Administrative Regions of Quebec",
   the 17 codes in the rules' order -- the English and the French texts
   agree, code for code -- each once, each its OWN multiplier ("For all
   stations, one multiplier point ... in each administrative region", so no
   line maps a region to the province), and nothing else: no INCLUDE, so an
   out-of-province entrant's table holds only regions (the host-area rule
   reads it). *)
procedure TContestQuebecQPTests.Test_QuebecRegionFileIsAppendixI;
var
   english: TStringList;
   french: TStringList;
   lines: TStringList;
   keys: TStringList;
   i: integer;
   key: string;
   line: string;
   inHeader: boolean;
begin
   BeginTest('Test_QuebecRegionFileIsAppendixI');
   english := TStringList.Create;
   french := TStringList.Create;
   lines := TStringList.Create;
   keys := TStringList.Create;
   try
      ReadAppendixICodes('QC-QSO-PARTY-Rules-EN.txt', english);
      ReadAppendixICodes('QC-QSO-PARTY-Rules-FR.txt', french);
      CheckEquals(17, english.Count, 'the English Appendix I lists 17 regions');
      CheckEquals(english.Text, french.Text, 'and the French lists the same codes in the same order');
      for i := Low(APPENDIX_I_REGIONS) to High(APPENDIX_I_REGIONS) do
         begin
         if i < english.Count then
            begin
            CheckEquals(english[i], APPENDIX_I_REGIONS[i], 'this test''s list is Appendix I, row ' + IntToStr(i + 1));
            end;
         end;

      lines.LoadFromFile(ShippedDomDir + QC_COUNTY_FILE);
      inHeader := True;
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         CheckTrue((DomIncludeName(line) = '') and
                   (Pos('INCLUDE', UpperCase(TrimLeft(line))) <> 1),
                   'the region file includes nothing, line ' + IntToStr(i + 1));
         key := DomFileLineKey(line);
         if key = '' then
            begin
            if inHeader then
               begin
               CheckEquals(0, Pos('=', line),
                           'quebec_cty.dom header line ' + IntToStr(i + 1) + ' would be read as an entry');
               end;
            Continue;
            end;
         inHeader := False;
         keys.Add(key);
         CheckEquals(1, Pos(key + ' = ' + key + ',^', line),
                     'its own multiplier and its own alias only: ' + line);
         end;
      CheckEquals(english.Text, keys.Text, 'quebec_cty.dom is Appendix I, in its order, and nothing else');
   finally
      keys.Free;
      lines.Free;
      french.Free;
      english.Free;
   end;

   (* AS A QUEBEC STATION READS IT (MultipliersIsCounties False): still 17
      multipliers, not one. *)
   LoadCountyTable(QC_COUNTY_FILE, False);
   try
      CheckEquals(17, mo.DomList.Count, 'in Quebec, the 17 regions are 17 multipliers');
      CheckEquals('MTL', MultiplierOf(CountyTable, 'MTL'), 'Montreal counts as Montreal');
      CheckEquals('', MultiplierOf(CountyTable, 'QC'), 'no province is in the region file');
      CheckEquals('', MultiplierOf(CountyTable, 'NY'), 'nor a state');
   finally
      FreeCountyTable;
   end;
end;

(* quebec.dom, read as text: the header holds no '=' (the loader has no
   comment syntax); the region file FIRST, then S51.DOM (the 50 states and
   DC), each INCLUDE spelt so the loader follows it; then its own rows --
   Appendix II's 12 provinces and territories other than Quebec, NF and LB
   apart, NWT folded into NT, and DX. Every Appendix II abbreviation is
   known to the loaded table. Then through the real loader: 17 regions + 51
   + 13 + DX = 82 domestic multipliers. *)
procedure TContestQuebecQPTests.Test_QuebecInProvinceFileIsAppendixII;
var
   lines: TStringList;
   appendix: TStringList;
   includes: string;
   included: string;
   keys: string;
   inHeader: boolean;
   i: integer;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   BeginTest('Test_QuebecInProvinceFileIsAppendixII');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'quebec.dom');
      includes := '';
      keys := '';
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
                       'quebec.dom line ' + IntToStr(i + 1)
                       + ' is an INCLUDE the loader would not follow');
            if inHeader then
               begin
               CheckEquals(0, Pos('=', lines[i]),
                           'quebec.dom header line ' + IntToStr(i + 1)
                           + ' would be read as an entry');
               end
            else if DomFileLineKey(lines[i]) <> '' then
               begin
               keys := keys + UpperCase(DomFileLineKey(lines[i])) + ' ';
               end;
            end;
         end;
      CheckEquals('QUEBEC_CTY.DOM S51.DOM ', includes, 'the regions first, then the states and DC');
      CheckEquals('NF LB PE NB NS ON MB SK AB BC NT YT NU DX ', keys,
                  'its own entries: the 12 other provinces and territories (NF and LB two) and DX');
   finally
      lines.Free;
   end;

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   appendix := TStringList.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'quebec.dom', True, 0);
      CheckEquals(82, mo.DomList.Count,
                  '17 regions, 50 states and DC, 13 provinces and territories, and DX');

      (* APPENDIX II, as the English rules print it. *)
      ReadAppendixIIAbbreviations(appendix);
      CheckEquals('NF LB PE NB NS ON MB SK AB BC NT YT NU NWT',
                  Trim(StringReplace(appendix.Text, sLineBreak, ' ', [rfReplaceAll])),
                  'Appendix II''s abbreviations, read from the rules');
      for i := 0 to appendix.Count - 1 do
         begin
         CheckTrue(MultiplierOf(table, appendix[i]) <> '',
                   appendix[i] + ' (Appendix II) is a multiplier in Quebec');
         end;
      CheckEquals(MultiplierOf(table, 'NT'), MultiplierOf(table, 'NWT'), 'NT and NWT are one');
      CheckTrue(MultiplierOf(table, 'NF') <> MultiplierOf(table, 'LB'), 'NF and LB are two');
      CheckEquals('', MultiplierOf(table, 'QC'), 'Quebec is not one');
   finally
      appendix.Free;
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* ---------------------------------------------------------------------------
   EXPORT AND SET-UP
   --------------------------------------------------------------------------- *)

(* ADIF STATE is the worked station's (Q76/Q89, the party base's): QC for a
   region, the station's own province or state otherwise, none for DX --
   and NL for NF and LB (NY4I: "NF and LB export ADIF STATE NL"; ADIF has
   no NF or LB). CNTY is not written (NY4I). *)
procedure TContestQuebecQPTests.Test_QuebecADIFStateAndNoCounty;
var
   identity: TContestBase;

   function StateOf(const aQTH: string; const aKey: string; const aCountry: string): string;
   var
      qso: ContestExchange;
   begin
      qso := QuebecQso(Band20, CW, eCW, aQTH);
      qso.DomesticQTH := ShortString(aKey);
      qso.QTH.CountryID := ShortString(aCountry);
      Result := identity.ADIFWorkedStationState(qso);
   end;

begin
   BeginTest('Test_QuebecADIFStateAndNoCounty');
   identity := ContestIdentity(QuebecHandle);
   CheckEquals('QC', StateOf('MTL', 'MTL', 'VE'), 'a Montreal station is in QC');
   CheckEquals('QC', StateOf('QUE', 'QUE', 'VE'), 'and a Capitale-Nationale one');
   CheckEquals('NL', StateOf('NF', 'Nf', 'VE'), 'Newfoundland is NL');
   CheckEquals('NL', StateOf('LB', 'Lb', 'VE'), 'and Labrador is NL');
   CheckEquals('NL', StateOf('LB', '', 'VE'), 'also when only the typed QTH is in the record');
   CheckEquals('NT', StateOf('NWT', 'Nt', 'VE'), 'NWT is NT');
   CheckEquals('ON', StateOf('ON', 'On', 'VE'), 'an Ontario station is in ON');
   CheckEquals('NY', StateOf('NY', 'NY', 'K'), 'a New York station is in NY');
   CheckEquals('', StateOf('DX', 'Dx', 'DL'), 'a DX station has no STATE');
   CheckEquals('', StateOf('KP4', '', 'KP4'), 'nor does a typed three-letter DX QTH (issue #134)');
   CheckEquals('QC', StateOf('OTS', 'OTS', 'VE'), 'while a region the table resolved still does');
   CheckFalse(identity.WritesADIFCounty, 'and no CNTY is written');
end;

(* NY4I: "A translatable region prompt replaces the US 'county in state'
   wording." The shared prompt would read "Enter your county if you are in
   QC state"; Quebec's names the region code. *)
procedure TContestQuebecQPTests.Test_QuebecNewContestPrompt;
var
   prompts: TNewContestPrompts;
   step: TNewContestPrompt;
begin
   BeginTest('Test_QuebecNewContestPrompt');
   prompts := TNewContestPrompts.Create;
   try
      ContestIdentity(QuebecHandle).DescribeNewContestPrompts(prompts);
      CheckEquals(1, prompts.ChoiceCount, 'one step when the contest is chosen');
      CheckEquals(0, prompts.InsideCount, 'and none on an "I am in" box');
      if prompts.ChoiceCount = 1 then
         begin
         step := prompts.Choice(0);
         CheckTrue(step.Kind = npkFieldWithComment, 'a row with a comment');
         CheckTrue(step.Field = ncfMyState, 'the MY STATE row');
         CheckEquals(SNewContestQuebecQPRegionOrLocation, step.Text, 'in Quebec''s own words');
         CheckTrue(Pos('administrative region code', step.Text) > 0, 'naming the region code');
         CheckTrue(Pos('DX is sent', step.Text) > 0, 'and saying a DX entrant sends DX');
         CheckEquals(0, Pos(' state. ', step.Text), 'and not "QC state"');
         end;
   finally
      prompts.Free;
   end;
end;

(* THE CABRILLO COLUMNS. The rules give no example line; they name the
   fields: a VE2 station "Must send a signal report and their administrative
   region abbreviation" and logs "the received signal report as well as the
   province, US state or DX"; a non-VE2 station sends "a signal report and
   their province, US state or DX" and logs the region. So: RST and the sent
   QTH, then RST and the received QTH, in the standard QSO line. The French
   text's sample exchange is the first case pinned: VE2CRO "You are
   Five-Nine from region Oscar Tango Sierra", KA1BCD "please take my Four
   Nine from New-York, November Yankee". A DX entrant sends DX. *)
procedure TContestQuebecQPTests.Test_QuebecCabrilloColumns;
var
   contestObject: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
begin
   BeginTest('Test_QuebecCabrilloColumns');
   CheckEquals('QC-QSO-PARTY', ContestIdentity(QuebecHandle).CabrilloContestName('', ''),
               'CONTEST: QC-QSO-PARTY');

   (* VE2CRO IN THE OUTAOUAIS WORKS KA1BCD IN NEW YORK -- the rules' sample. *)
   contestObject := MakeQuebec(StationAt(True));
   try
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      CheckEquals('FM', contestObject.CabrilloModeString(FM, eFM), 'FM is FM');
      CheckEquals('CW', contestObject.CabrilloModeString(CW, eCW), 'CW is CW');
      my := Default(TMyStationExchange);
      my.MyState := 'OTS';
      qso := QuebecQso(Band20, Phone, eUSB, 'NY');
      qso.RSTSent := 59;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '59';
      ctx.RSTReceived := '49';
      ctx.HisQTH := 'NY';
      CheckEquals('59  OTS    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent: "Five-Nine from region Oscar Tango Sierra"');
      CheckEquals('49  NY     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: "Four Nine from New-York, November Yankee"');
      CheckEquals('59  OTS    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my region');

      (* "Other DXCC entities must be logged as DX": typed or not. *)
      qso := QuebecQso(Band20, CW, eCW, 'DX');
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'DX';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a DX station''s column is DX');
      qso := QuebecQso(Band20, CW, eCW, '');
      ctx.HisQTH := '';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'nothing typed: DX');
   finally
      contestObject.Free;
   end;

   (* A NEW YORK ENTRANT WORKS MONTREAL. *)
   contestObject := MakeQuebec(StationAt(False));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'NY';
      qso := QuebecQso(Band40, CW, eCW, 'MTL');
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'MTL';
      CheckEquals('599 NY     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent: RST and my state');
      CheckEquals('599 MTL    ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RST and the region code');
   finally
      contestObject.Free;
   end;

   (* A DX ENTRANT: MY STATE is empty and it sends DX -- "Non-VE2 stations:
      Must send a signal report and their province, US state or DX for other
      entities". NOT its prefix. The ADIF STX_STRING says DX too, as the
      Cabrillo column does (Georgia's, NC's and Missouri's answer for the same
      rule, 2026-10-27): it is the information transmitted. *)
   contestObject := MakeQuebec(DXStation('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := '';
      qso := QuebecQso(Band20, CW, eCW, 'MTL');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'MTL';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent: RST and DX');
      CheckEquals('599 DX     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and DX, what was sent');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First a New
   York entrant with the shipped quebec_cty.dom, then a Montreal entrant with
   the shipped quebec.dom (its INCLUDEs followed by uTestShippedDom, since
   the test binary has no dom folder).
   --------------------------------------------------------------------------- *)

procedure TContestQuebecQPTests.Test_QuebecRealEngine;
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
      dupe's zero points, the sheets. Returns whether it was a dupe. *)
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
   BeginTest('Test_QuebecRealEngine');
   h := QuebecHandle;
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
      (* AS FoundContest SETS IT UP FOR A NEW YORK STATION: not in Quebec,
         so the region file with each region its own multiplier; K, VE, KH6
         and KL are domestic countries (Add_KVEKH6KL, as for every party);
         and the class's flags, as ApplyContestTraits writes them, so a
         wrong flag is seen here as a wrong dupe or multiplier. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + QC_COUNTY_FILE),
                'quebec_cty.dom loads');
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := False;
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* MONTREAL, CW. *)
      dupe := Enter('VE2MTL', '599 MTL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 MTL is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('MTL', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the region');
      CheckTrue(rx.DomesticMult, 'Montreal is a new multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), '"2 points per QSO on CW"');

      (* "on each frequency band worked on these regions". *)
      dupe := Enter('VE2MTL', '599 MTL', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'and Montreal IS a new multiplier on another band');

      (* "once on phone and once on CW" -- per band; "No additional
         multipliers are given for working multiple modes". *)
      dupe := Enter('VE2MTL', '59 MTL', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 MTL on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), '"1 point per QSO on phone"');
      CheckFalse(rx.DomesticMult, 'but no new multiplier in another mode on the same band');

      dupe := Enter('VE2MTL', '599 MTL', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Montreal again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* "Phone (SSB or FM)": FM after SSB on one band is the same mode, so a
         dupe (the engine's DupeSlot). *)
      dupe := Enter('VE2VHF', '59 OTS', Band2, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '2 m SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), '2 m phone scores 1');
      dupe := Enter('VE2VHF', '59 OTS', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted, '2 m FM is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'the same station on 2 m FM after SSB IS a dupe: FM is phone');

      (* "VE2xxx/MTL": a mobile's /region comes off for the lookup;
         "W2ABC/VE2" keeps its /VE2 (no table knows VE2) and is located as
         Canada. *)
      dupe := Enter('VE2MOB/LVL', '599 LVL', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'VE2MOB/LVL is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.QTH.CountryID = 'VE', 'and is located as Canada, the /LVL stripped');
      CheckEquals(2, Integer(rx.QSOPoints), 'for 2 points');
      dupe := Enter('W2ABC/VE2', '599 GIM', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'W2ABC/VE2 is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.QTH.CountryID = 'VE', 'and is located as Canada, by its /VE2');
      CheckEquals(2, Integer(rx.QSOPoints), 'for 2 points');

      (* A worked mobile in a new region: a new QSO. *)
      dupe := Enter('VE2MTL', '599 LNS', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same call from the Laurentides on 20 m CW: a new station');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores');
      CheckTrue(rx.DomesticMult, 'the Laurentides are a new multiplier');

      (* NO DIGITAL: logged, an automatic X-QSO, nothing earned. *)
      dupe := Enter('VE2FT', '599 ETE', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'an FT8 QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');
      dupe := Enter('VE2FT', '599 ETE', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'so Estrie on 20 m CW is still a new multiplier');

      (* NO 160 m, NO WARC: logged, automatic X-QSOs. *)
      dupe := Enter('VE2TOP', '599 MAU', Band160, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 160 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO ("between 80 et 2 m")');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and Mauricie is no multiplier from it');
      dupe := Enter('VE2WRC', '599 MAU', Band30, CW, eCW, accepted, rx);
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'a 30 m QSO is an X-QSO ("excepted WARC bands")');
      CheckFalse(rx.DomesticMult, 'and earns nothing');

      (* "Non-VE2 stations obtain points for contacts for VE2 stations only."
         Every call goes to the domestic parser (RSTDomesticQTHExchange),
         which refuses a QTH the region file does not know, naming the
         host-area reason when the in-province file knows it. *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := QC_COUNTY_FILE;

      accepted := True;
      Enter('W2NY', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a New York station is refused');
      CheckEquals('Improper domestic QTH!! (NY: work QC stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      accepted := True;
      Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals('Improper domestic QTH!! (DX: work QC stations only)',
                  string(ExchangeErrorMessage),
                  'with the host-area reason');

      accepted := True;
      Enter('VE2ABC', '599 QC', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'QC is refused: "not a valid territory entry"');
      CheckEquals('Improper domestic QTH!! (QC not in quebec_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the region file');

      accepted := True;
      Enter('VE2ABC', '599 MTX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a misspelt region is refused');

      (* REGION LINES OF TWO: the first region is this QSO, the second is
         queued; three are refused, nothing queued. *)
      ClearPendingCounties;
      dupe := Enter('VE2LINE', '599 MTL/LVL', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a two-region line is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('MTL', UpperCase(string(rx.QTHString)), 'the first region is this QSO');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckEquals(1, PendingCountiesCount, 'one more region is queued');
      CheckEquals('LVL', UpperCase(DequeuePendingCounty), 'Laval, as its own QSO');
      ClearPendingCounties;

      accepted := True;
      Enter('VE2LINE', '599 MTL/LVL/LNS', Band10, Phone, eUSB, accepted, rx);
      CheckFalse(accepted, 'three regions are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
                  'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;

      (* Q119: THE SAME REFUSED QSO, ARRIVING LOGGED, is an automatic X-QSO
         for this entrant. *)
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W2NY';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Frequency := 14025000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'NY';
      rx.tSysTime.qtYear := 26;
      rx.tSysTime.qtMonth := 4;
      rx.tSysTime.qtDay := 19;
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of province, a logged W2NY NY is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      rx.QTHString := 'MTL';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of province, a logged Montreal QSO is not');

      (* NOW A MONTREAL ENTRANT: in Quebec, quebec.dom (the regions, the
         states and DC, the provinces, DX), each region its own multiplier. *)
      MultipliersIsCounties := False;
      DomQTHTable.Free;
      DomQTHTable := TDomQTHTable.Create;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'quebec.dom', True, 0);
      StationInHostState := True;
      Settings.My.DeriveCountry('VE');
      Settings.Contest.DomesticFilename := 'quebec.dom';
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      dupe := Enter('W2AAA', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in Quebec, 599 NY is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'New York is a new multiplier');
      dupe := Enter('W2AAA', '59 NY', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'New York on 20 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores 1');
      CheckFalse(rx.DomesticMult, 'nor a new multiplier: per band, not per mode');
      dupe := Enter('W2AAA', '599 NY', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'but New York on 40 m IS a new multiplier');

      dupe := Enter('VE2QUE', '599 QUE', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 QUE is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('QUE', UpperCase(string(rx.DomMultQTH)), 'QUE is Capitale-Nationale, not Quebec');
      CheckTrue(rx.DomesticMult, 'a new multiplier');

      accepted := True;
      Enter('VE2ABC', '599 QC', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'QC is refused in Quebec too: "not a valid territory entry"');
      accepted := True;
      Enter('VE2ABC', '599 VE2', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'and VE2');

      dupe := Enter('VO1AAA', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NF is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NF', UpperCase(string(rx.DomMultQTH)), 'NF is Newfoundland');
      CheckTrue(rx.DomesticMult, 'a new multiplier');
      dupe := Enter('VO2AAA', '599 LB', Band20, CW, eCW, accepted, rx);
      CheckEquals('LB', UpperCase(string(rx.DomMultQTH)), 'LB is Labrador');
      CheckTrue(rx.DomesticMult, 'ANOTHER multiplier: NF and LB are two');
      accepted := True;
      Enter('VO1BBB', '599 NL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'NL names neither, so it is refused');

      dupe := Enter('VE8AAA', '599 NT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NT is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'the Northwest Territories are a new multiplier');
      dupe := Enter('VE8BBB', '599 NWT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NWT is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NT', UpperCase(string(rx.DomMultQTH)), 'NWT is NT');
      CheckFalse(rx.DomesticMult, 'so no new multiplier: one territory');

      dupe := Enter('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 DC is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('DC', UpperCase(string(rx.DomMultQTH)), 'District of Columbia');
      CheckTrue(rx.DomesticMult, 'a new multiplier');
      dupe := Enter('W3MD', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'Maryland');
      CheckTrue(rx.DomesticMult, 'is ANOTHER multiplier: DC is its own');

      dupe := Enter('KH6AAA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 HI is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Hawaii is a state multiplier');
      CheckFalse(rx.DXMult, 'and not a DX one');

      (* "Other DXCC entities must be logged as DX." "Only one DX multiplier
         is given for entities worked outside of Canada or USA" -- per band
         (NY4I). *)
      dupe := Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in Quebec, a DX station sending DX is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'for 2 points');
      CheckEquals('DX', UpperCase(string(rx.DomMultQTH)), 'the multiplier is DX');
      CheckTrue(rx.DomesticMult, 'and DX is a new multiplier');
      CheckFalse(rx.DXMult, 'a domestic one, not the engine''s DX kind');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and in province it is no X-QSO');
      dupe := Enter('JA1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Japan sending DX is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(rx.DomesticMult, 'but Japan on 20 m is NO new multiplier: only one DX');
      dupe := Enter('KP4AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Puerto Rico sending DX is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(rx.DomesticMult, '"KP2 and KP4 are excluded" -- the same one DX');
      dupe := Enter('DL2BBB', '599 DX', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'but DX on 40 m is: per band');
      accepted := True;
      Enter('DL3CCC', '599 DL', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station logged as DL is refused: "must be logged as DX"');

      dupe := Enter('VE3AAA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 ON is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Ontario is a province multiplier');

      dupe := Enter('VE2MTL', '599 MTL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in Quebec, 599 MTL is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MTL', UpperCase(string(rx.DomMultQTH)), 'Montreal counts as Montreal, not QC');
      CheckTrue(rx.DomesticMult, 'and is a new multiplier ("For all stations")');

      dupe := Enter('VE2TOP', '599 MAU', Band160, CW, eCW, accepted, rx);
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'in Quebec too, 160 m is an X-QSO');
      CheckFalse(rx.DomesticMult, 'and earns nothing');
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

procedure TContestQuebecQPTests.RunAllTests;
begin
   Test_QuebecIdentity;
   Test_QuebecBands;
   Test_QuebecPoints;
   Test_QuebecNoDigital;
   Test_QuebecInProvinceMultipliers;
   Test_QuebecQUEIsCapitaleNationale;
   Test_QuebecOneDXMultiplierIsDomestic;
   Test_QuebecOutOfProvinceWorksOnlyQuebec;
   Test_QuebecRegionLineIsTwoRegions;
   Test_QuebecDupes;
   Test_QuebecScoreIsPointsTimesMultipliers;
   Test_QuebecRegionFileIsAppendixI;
   Test_QuebecInProvinceFileIsAppendixII;
   Test_QuebecADIFStateAndNoCounty;
   Test_QuebecNewContestPrompt;
   Test_QuebecCabrilloColumns;
   Test_QuebecRealEngine;
end;

end.
