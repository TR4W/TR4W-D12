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

(* THE ONTARIO QSO PARTY -- added 2026-10-26 (#127), registered by its id
  (ON-QSO-PARTY). The rules are docs/ContestRules/QSOParties/Ontario/
  (ON-QSO-PARTY-Rules.txt, the 2026 rules; ON-QSO-PARTY-Multipliers.txt, the
  sponsor's multiplier list; ON-QSO-PARTY-Setup.txt); NY4I's decisions are on
  #127. Each test below quotes the rule it holds. Written from
  ADDING_A_CONTEST.md Part A5 in uTestContestGeorgiaQP's shape; nothing is
  assumed from another party's rules.

  WHAT IS PINNED
    * its identity: the id, no legacy number, refused on multi-op, the
      names, the files, the flags, the party base and what it inherits (and
      the CNTY it does not write), LOCATION required, its own prompt;
    * its bands, and its points in every mode through ScoreQSO -- 2, and 10
      INSTEAD for the five club stations, matched exactly after the rover
      strip;
    * the in-province entrant's multipliers (the shipped ontario.dom through
      the real loader): the 50 codes, the 50 states, DC on its own, the 12
      other provinces and territories (NF and LB one), MAN being Manitoulin;
    * the in-province DX multiplier (DXCC but K, VE, KH6 and KL) and none
      outside Ontario;
    * the out-of-province entrant's multipliers and the host-area rule,
      against the shipped ontario_cty.dom;
    * county lines with no maximum, the final score's formula, no bonus
      (#133), no power multiplier;
    * a DX entrant sends its own prefix (the party base's SentLocation);
    * the two .dom files against the sponsor's multiplier list;
    * the dupe rules and the rover's new county;
    * the Cabrillo columns the rules name;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet):
      an out-of-province entrant, then an in-province one. *)
unit uTestContestOntarioQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestOntarioQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OntarioIdentity;
      procedure Test_OntarioBands;
      procedure Test_OntarioPoints;
      procedure Test_OntarioClubStationsScoreTen;
      procedure Test_OntarioNoDigital;
      procedure Test_OntarioInProvinceMultipliers;
      procedure Test_OntarioMANIsManitoulin;
      procedure Test_OntarioInProvinceDXMultiplier;
      procedure Test_OntarioOutOfProvinceWorksOnlyOntario;
      procedure Test_OntarioCountyLinesHaveNoMaximum;
      procedure Test_OntarioDupes;
      procedure Test_OntarioScoreIsPointsTimesMultipliers;
      procedure Test_OntarioCountyFileIsTheSponsorsList;
      procedure Test_OntarioInProvinceFileIsTheRulesMultipliers;
      procedure Test_OntarioADIFStateAndNoCounty;
      procedure Test_OntarioNewContestPrompt;
      procedure Test_OntarioCabrilloColumns;
      procedure Test_OntarioRealEngine;
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
   uContestOntarioQP,
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
   (* "each Canadian province/territory" other than Ontario, as the
      in-province file keys them -- the ADIF Canadian codes. NF and LB are
      Newfoundland and Labrador's other spellings (NY4I: one "province"). *)
   OTHER_PROVINCES: array[0..11] of string = (
      'NS', 'QC', 'MB', 'SK', 'AB', 'BC', 'NT', 'NB', 'NU', 'YT', 'PE', 'NL');

function OntarioHandle: TContestHandle;
begin
   if not FindContestById(ON_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('ON-QSO-PARTY is not registered');
      end;
end;

function MakeOntario(const aStation: TStationContext): TContestBase;
begin
   Result := Make(OntarioHandle, aStation);
end;

(* A Toronto station or a New York one. The table knows every QTH
   (uTestContestObjects.WithHostAreaTable): a test about POINTS states that
   every QSO it scores is with a host-area station. The host-area rule
   itself is Test_OntarioOutOfProvinceWorksOnlyOntario's, against the real
   county file. *)
function StationAt(aInProvince: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInProvince;
   if aInProvince then
      begin
      Result.MyState := 'TOR';
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

function OntarioQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                    const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'VE3XYZ';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := ShortString(aQTH);
end;

(* The points ScoreQSO gives -- the ONE public scoring entry. *)
function PointsForCall(aStation: TStationContext; const aCall: string; aBand: BandType;
                       aMode: ModeType; aExtMode: ExtendedModeType; const aQTH: string): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := MakeOntario(aStation);
   try
      qso := OntarioQso(aBand, aMode, aExtMode, aQTH);
      qso.Callsign := CallString(aCall);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

function PointsFor(aStation: TStationContext; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType; const aQTH: string): integer;
begin
   Result := PointsForCall(aStation, 'VE3XYZ', aBand, aMode, aExtMode, aQTH);
end;

(* THE SPONSOR'S MULTIPLIER LIST as committed beside the rules:
   ON-QSO-PARTY-Multipliers.txt, one multiplier a line after the '====' rule,
   "CODE SECTION Name" (the section padded to three). Filled as CODE=Name;
   aSections (when not nil) as CODE=SECTION. *)
procedure ReadSponsorMultiplierList(aMultipliers: TStringList; aSections: TStringList);
var
   lines: TStringList;
   path: string;
   line: string;
   i: integer;
   inTable: boolean;
begin
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
           'QSOParties' + PathDelim + 'Ontario' + PathDelim + 'ON-QSO-PARTY-Multipliers.txt';
   lines := TStringList.Create;
   try
      lines.LoadFromFile(path);
      inTable := False;
      for i := 0 to lines.Count - 1 do
         begin
         line := TrimRight(lines[i]);
         if Pos('=====', line) = 1 then
            begin
            inTable := True;
            Continue;
            end;
         if (not inTable) or (line = '') then
            begin
            Continue;
            end;
         aMultipliers.Add(Copy(line, 1, 3) + '=' + Copy(line, 9, Length(line) - 8));
         if aSections <> nil then
            begin
            aSections.Add(Copy(line, 1, 3) + '=' + Trim(Copy(line, 5, 3)));
            end;
         end;
   finally
      lines.Free;
   end;
end;

(* An out-of-province entrant whose session table is the shipped county
   file (LoadCountyTable first). *)
function OutOfProvinceStation: TStationContext;
begin
   Result := NoStation;
   Result.IsDomesticQTH := @CountyFileKnowsQTH;
   Result.InHostState := False;
   Result.MyState := 'NY';
   Result.MyCountry := 'K';
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestOntarioQPTests.Test_OntarioIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   member: ContestType;
   legacy: integer;
begin
   BeginTest('Test_OntarioIdentity');
   CheckEquals('ON-QSO-PARTY', ON_QSO_PARTY_CONTEST_ID, 'the id constant');
   CheckTrue(FindContestById('ON-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestOntarioQP, 'to its class');
   CheckTrue(TContestOntarioQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly: one host province, its counties, '
             + '"Non-Ontario stations work Ontario stations only"');
   CheckEquals('ON-QSO-PARTY', ContestId(h), 'the stored id');

   identity := ContestIdentity(h);
   CheckFalse(TryLegacyContestOf(identity, member), 'a new contest has no ContestType member');
   CheckTrue(member = DUMMYCONTEST, 'so the walk names none');
   CheckFalse(ContestLegacyNumber(h, legacy), 'and no legacy number');
   CheckFalse(ContestCanUseMultiOp(h), 'and is refused on the multi-op network');

   CheckEquals('Ontario QSO Party', identity.DisplayName, 'display name');
   CheckEquals('Ontario QSO Party', identity.FriendlyName, 'friendly name');
   (* The sponsor states no CONTEST: value; WA7BNM 357 and ADIF say
      ON-QSO-PARTY. *)
   CheckEquals('ON-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('ON-QSO-PARTY', identity.CabrilloContestName('2026 OQP VE3XYZ', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('ON-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('ON-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the Ontario QSO Party');
   CheckEquals(357, identity.WA7BNMId, 'WA7BNM ref 357');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   (* "Entries should be submitted via the online web page". *)
   CheckEquals('', identity.SubmissionEmail, 'no submission e-mail');
   CheckEquals('ON', identity.HostState, 'host province, the ADIF code');
   CheckEquals('ON', identity.QSOPartyArea, 'its area');
   CheckEquals('ontario_cty', identity.DomesticFileName, 'the county file');
   CheckEquals('ontario', identity.InStateDomesticFileName, 'the in-province file');
   CheckTrue(identity.IsUSQSOParty, 'set up as a party (BC''s precedent)');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');

   (* "You may work a station TWICE per band: once on phone and once on CW";
      "1 multiplier point for each Ontario county worked on each band";
      "All Bands 160-2 meters". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand, cfVHFBandsEnabled],
             'dupes per band and mode, multipliers per band, 6 m and 2 m on');
   CheckTrue(identity.QSOByBand, 'a station may be worked again on another band');
   CheckTrue(identity.QSOByMode, 'and again in another mode');
   CheckTrue(identity.MultByBand, 'a multiplier counts again on each band');
   CheckFalse(identity.MultByMode, 'but NOT again per mode');
   CheckTrue(identity.VHFBandsEnabled, '6 m and 2 m');

   (* "Ontario stations send signal report and their county abbreviation";
      "Non-Ontario stations send signal report and province, state, or DXCC
      country or abbreviation". *)
   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(identity.ExchangeKind),
               'RST and a county, state, province or DXCC country');
   CheckEquals(Ord(NoInitialExchange), Ord(identity.InitialExchangeKind), 'no initial exchange');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a domestic QTH');
   CheckTrue(ContestUsesDomesticFile(identity), 'looked up in the domestic file');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the domestic QTH is the multiplier');

   (* "please fill in the ARRL-SECTION: field. This field determines how
      your log is scored as in-Province or Out-of-Province" (NY4I:
      required). *)
   CheckTrue(identity.RequiresCabrilloLocation, 'no Cabrillo file without a LOCATION');

   (* WHAT THE PARTY BASE GIVES IT, pinned here so a base change is seen. *)
   CheckTrue(identity.StripsRoverCountyFromCall, 'a rover''s /county is stripped live');
   CheckTrue(identity.SplitsRoverCallOnExport,
             'and split on ADIF export ("using your CALL without /QTH appended")');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH,
             '"Mobile/Rover stations may be worked again when they change multiplier areas"');
   (* NY4I: ADIF county not written -- ADIF defines no Canadian CNTY. *)
   CheckFalse(identity.WritesADIFCounty, 'CNTY is NOT written');
   CheckEquals(CountyLineCountiesUnlimited,
               (identity as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '"a county line or junction between 2 or more counties": no maximum');

   (* "Ontario stations also claim 1 multiplier point for each ... DXCC
      country"; outside Ontario, only the counties. *)
   contestObject := MakeOntario(StationAt(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'in Ontario: DXCC countries are multipliers');
      CheckTrue(ContestCountryMode(contestObject) = ARRLCountryMode, 'on the DXCC (ARRL) list');
      CheckFalse(contestObject.HasZoneMultiplier, 'in Ontario: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'in Ontario: no prefix multiplier');
      CheckEquals(' 5NN TOR', contestObject.CQExchangeDefault(StationAt(True)),
                  'in Ontario, the CQ exchange sends the county code');
   finally
      contestObject.Free;
   end;
   contestObject := MakeOntario(StationAt(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside Ontario: no DX multiplier');
      CheckTrue(ContestCountryMode(contestObject) = CQCountryMode, 'and the CQ list');
      CheckFalse(contestObject.HasZoneMultiplier, 'outside Ontario: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'outside Ontario: no prefix multiplier');
      CheckEquals(' 5NN NY', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside Ontario, the state');
      (* "Non-Ontario stations send signal report and province, state, or
         DXCC country" -- a DX entrant its own prefix (NY4I). *)
      CheckEquals(' 5NN DL', contestObject.CQExchangeDefault(DXStation('DL')),
                  'a DX entrant with no MY STATE sends its prefix');
   finally
      contestObject.Free;
   end;
end;

(* "Frequencies: All Bands 160-2 meters with the exception of the WARC
   bands." -- 160, 80, 40, 20, 15, 10, 6 and 2 m. An off-band QSO is an
   automatic X-QSO: logged, 0 points, no multiplier. *)
procedure TContestOntarioQPTests.Test_OntarioBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_OntarioBands');
   identity := ContestIdentity(OntarioHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when on the rules'' list');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(2, PointsFor(StationAt(False), Band160, CW, eCW, 'TOR'), '160 m scores');
   CheckEquals(2, PointsFor(StationAt(False), Band10, CW, eCW, 'TOR'), '10 m scores');
   CheckEquals(2, PointsFor(StationAt(False), Band6, Phone, eUSB, 'TOR'), '6 m scores');
   CheckEquals(2, PointsFor(StationAt(False), Band2, FM, eFM, 'TOR'), '2 m scores');
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'TOR'), '30 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'TOR'), '17 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band12, CW, eCW, 'TOR'), '12 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band222, FM, eFM, 'TOR'), '222 MHz is above 2 m');
   CheckEquals(0, PointsFor(StationAt(False), Band432, FM, eFM, 'TOR'), '70 cm scores nothing');
end;

(* "Score 2 QSO points for each station worked on phone per band. Score 2
   QSO points for each station worked on CW per band." FM is phone. The same
   for both entrants and for a DX station worked from Ontario ("Ontario
   stations work everyone"). *)
procedure TContestOntarioQPTests.Test_OntarioPoints;
begin
   BeginTest('Test_OntarioPoints');
   CheckEquals(2, PointsFor(StationAt(False), Band20, CW, eCW, 'TOR'), 'outside, CW 2');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Phone, eUSB, 'TOR'), 'outside, SSB 2 ("now count as 2")');
   CheckEquals(2, PointsFor(StationAt(False), Band40, Phone, eLSB, 'OTT'), 'outside, LSB 2');
   CheckEquals(2, PointsFor(StationAt(False), Band2, FM, eFM, 'OTT'), 'outside, FM is phone: 2');
   CheckEquals(2, PointsFor(StationAt(True), Band40, CW, eCW, 'NY'), 'in Ontario, CW with New York');
   CheckEquals(2, PointsFor(StationAt(True), Band40, Phone, eLSB, 'QC'), 'in Ontario, SSB with Quebec');
   CheckEquals(2, PointsFor(StationAt(True), Band15, CW, eCW, 'DL'),
               'in Ontario, a DX station scores ("Ontario stations work everyone")');
   CheckEquals(2, PointsFor(DXStation('DL'), Band20, CW, eCW, 'TOR'), 'a DX entrant, CW 2');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'NY'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'NY'), 'nor this one');
end;

(* "Score 10 QSO points for each contact made with CCO club stations VA3CCO &
   VE3CCO, ODXA club station VE3ODX, and RAC stations VE3RHQ and VA3RAC."
   NY4I: 10 INSTEAD of 2 (not 12), in every mode and band, for every entrant;
   the call matched EXACTLY after the rover strip -- a /suffix the session's
   domestic table knows comes off, any other stays. The table here is the
   shipped county file (an out-of-province session's). *)
procedure TContestOntarioQPTests.Test_OntarioClubStationsScoreTen;
var
   i: integer;
begin
   BeginTest('Test_OntarioClubStationsScoreTen');
   LoadCountyTable('ontario_cty.dom', True);
   try
      for i := Low(ON_CLUB_STATIONS) to High(ON_CLUB_STATIONS) do
         begin
         CheckEquals(10, PointsForCall(OutOfProvinceStation, ON_CLUB_STATIONS[i], Band20, CW, eCW, 'TOR'),
                     ON_CLUB_STATIONS[i] + ' on CW scores 10, not 2 and not 12');
         CheckEquals(10, PointsForCall(OutOfProvinceStation, ON_CLUB_STATIONS[i], Band40, Phone, eLSB, 'TOR'),
                     ON_CLUB_STATIONS[i] + ' on phone scores 10');
         CheckEquals(10, PointsForCall(StationAt(True), ON_CLUB_STATIONS[i], Band2, FM, eFM, 'OTT'),
                     ON_CLUB_STATIONS[i] + ' on 2 m FM from Ontario scores 10');
         end;
      CheckEquals(5, Length(ON_CLUB_STATIONS), 'the rules name five stations');
      CheckEquals(10, PointsForCall(OutOfProvinceStation, 've3cco', Band20, CW, eCW, 'TOR'),
                  'the call in lower case (an import) is the same call');

      (* AFTER THE ROVER STRIP. *)
      CheckEquals(10, PointsForCall(OutOfProvinceStation, 'VE3CCO/TOR', Band20, CW, eCW, 'TOR'),
                  'VE3CCO/TOR is VE3CCO roving in Toronto: 10');
      CheckEquals(10, PointsForCall(OutOfProvinceStation, 'VE3RHQ/OTT', Band20, Phone, eUSB, 'OTT'),
                  'VE3RHQ/OTT: 10');
      CheckEquals(2, PointsForCall(OutOfProvinceStation, 'VE3CCO/M', Band20, CW, eCW, 'TOR'),
                  'VE3CCO/M: M is no county, so the rover strip leaves it -- 2');
      CheckEquals(2, PointsForCall(OutOfProvinceStation, 'VE3CCO/XYZ', Band20, CW, eCW, 'TOR'),
                  'nor an unknown suffix -- 2');

      (* EXACTLY -- D7's OQPQSOPointMethod paid any call containing 3CCO. *)
      CheckEquals(2, PointsForCall(OutOfProvinceStation, 'VE3CCOX', Band20, CW, eCW, 'TOR'),
                  'VE3CCOX is not VE3CCO');
      CheckEquals(2, PointsForCall(OutOfProvinceStation, 'VA3ODX', Band20, CW, eCW, 'TOR'),
                  'VA3ODX is not VE3ODX');
      CheckEquals(2, PointsForCall(OutOfProvinceStation, 'VE3RAC', Band20, CW, eCW, 'TOR'),
                  'VE3RAC is not VA3RAC');
      CheckEquals(2, PointsForCall(OutOfProvinceStation, 'VE2CCO', Band20, CW, eCW, 'TOR'),
                  'VE2CCO is not VE3CCO');

      (* A CLUB STATION IS STILL HELD TO THE OTHER RULES. *)
      CheckEquals(0, PointsForCall(OutOfProvinceStation, 'VE3CCO', Band30, CW, eCW, 'TOR'),
                  'off-band: 0');
      CheckEquals(0, PointsForCall(OutOfProvinceStation, 'VE3CCO', Band20, Digital, eRTTY, 'TOR'),
                  'digital: 0');
      CheckEquals(0, PointsForCall(OutOfProvinceStation, 'VE3CCO', Band20, CW, eCW, 'NY'),
                  'outside Ontario, a club station that sent no county is no Ontario station: 0');
   finally
      FreeCountyTable;
   end;
end;

(* No digital mode is named: "You may work a station TWICE per band: once on
   phone and once on CW". Every digital submode is an automatic X-QSO (Q98,
   QSOIsXQSO); CW, phone and FM are credited. Every ExtendedModeType is
   walked, asked of the station-less identity as every X-QSO reader asks
   it. *)
procedure TContestOntarioQPTests.Test_OntarioNoDigital;
var
   identity: TContestBase;
   qso: ContestExchange;
   ext: ExtendedModeType;
begin
   BeginTest('Test_OntarioNoDigital');
   identity := ContestIdentity(OntarioHandle);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'digital submode ' + IntToStr(Ord(ext)) + ' is not credited');
      qso := OntarioQso(Band20, Digital, ext, 'TOR');
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
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eFT8, 'TOR'), 'FT8 scores 0');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Digital, eRTTY, 'NY'), 'RTTY scores 0');
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* "All Stations claim 1 multiplier point for each Ontario county worked on
   each band." "Ontario stations also claim 1 multiplier point for each
   Canadian province/territory, U.S. state (plus District of Columbia) and
   DXCC country worked on each band." The shipped ontario.dom through the
   real loader (InStateMultiplierOf follows its INCLUDEs), and the class's
   own CountsAsMultiplier (CountsForEntrant, the seam SetMultFlags asks).
   NY4I: DC is its OWN multiplier; Newfoundland and Labrador is one
   "province"; Ontario is not a province multiplier (an Ontario station
   sends its county). *)
procedure TContestOntarioQPTests.Test_OntarioInProvinceMultipliers;
var
   h: TContestHandle;
   i: integer;
begin
   BeginTest('Test_OntarioInProvinceMultipliers');
   h := OntarioHandle;

   CheckEquals('TOR', InStateMultiplierOf(h, 'TOR'), 'Toronto is its own multiplier, not ON');
   CheckEquals('ALG', InStateMultiplierOf(h, 'ALG'), 'and Algoma');
   CheckEquals('YRK', InStateMultiplierOf(h, 'YRK'), 'and York');
   CheckEquals('', InStateMultiplierOf(h, 'ON'), 'ON is no multiplier: an Ontario station sends a county');
   CheckEquals('', InStateMultiplierOf(h, 'VE3'), 'nor VE3');
   CheckEquals('', InStateMultiplierOf(h, 'ONT'), 'nor ONT');

   CheckEquals('NY', InStateMultiplierOf(h, 'NY'), 'New York is a state');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), 'Alaska is');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');
   (* "U.S. state (plus District of Columbia)". *)
   CheckEquals('DC', InStateMultiplierOf(h, 'DC'), 'DC is its own multiplier');
   CheckEquals('MD', InStateMultiplierOf(h, 'MD'), 'and Maryland its own');

   for i := Low(OTHER_PROVINCES) to High(OTHER_PROVINCES) do
      begin
      CheckEquals(OTHER_PROVINCES[i], InStateMultiplierOf(h, OTHER_PROVINCES[i]),
                  OTHER_PROVINCES[i] + ' is its own province multiplier');
      end;
   CheckEquals('NL', InStateMultiplierOf(h, 'NF'), 'NF is Newfoundland and Labrador');
   CheckEquals('NL', InStateMultiplierOf(h, 'LB'), 'and so is LB: one "province/territory"');
   CheckEquals('NL', InStateMultiplierOf(h, 'LAB'), 'and LAB');
   CheckEquals('NL', InStateMultiplierOf(h, 'VO2'), 'and VO2');
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana, not Labrador');
   CheckEquals('QC', InStateMultiplierOf(h, 'PQ'), 'PQ is Quebec');

   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NY'), rmDomestic), 'New York counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'TOR'), rmDomestic), 'a county counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DC'), rmDomestic), 'DC counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NU'), rmDomestic), 'Nunavut counts');
   CheckTrue(CountsForEntrant(h, False, InStateMultiplierOf(h, 'TOR'), rmDomestic),
             'outside Ontario a county counts (the host-area rule is a separate question)');

   (* DXCC countries are the DX multiplier (Test_OntarioInProvinceDXMultiplier),
      not entries in the in-province file. *)
   CheckEquals('', InStateMultiplierOf(h, 'DX'), 'DX is no domestic multiplier');
   CheckEquals('', InStateMultiplierOf(h, 'DL'), 'nor a DX country');
end;

(* NY4I on #127: "MAN is Manitoulin AND Manitoba's alias in P12/P13. Load the
   county file first and write the province rows inline in ontario.dom (no
   P13 include)." The first alias added wins, so MAN must resolve to
   Manitoulin District for an Ontario entrant -- and it would not if the
   province rows came from P12/P13 before the counties, or if P13 were
   included at all (both spell Manitoba MAN). Through the real loader and
   the shipped files. *)
procedure TContestOntarioQPTests.Test_OntarioMANIsManitoulin;
var
   h: TContestHandle;
   table: TDomQTHTable;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   includes: string;
begin
   BeginTest('Test_OntarioMANIsManitoulin');
   h := OntarioHandle;
   CheckEquals('MAN', InStateMultiplierOf(h, 'MAN'), 'MAN is Manitoulin District in Ontario');
   CheckEquals('MB', InStateMultiplierOf(h, 'MB'), 'MB is Manitoba');
   CheckEquals('MB', InStateMultiplierOf(h, 'VE4'), 'and so is VE4');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      includes := LoadShippedDomFollowingIncludes(table, 'ontario.dom', True, 0);
      CheckEquals('MAN', MultiplierOf(table, 'MAN'), 'the loaded table: MAN is Manitoulin');
      CheckEquals('MAN', QTHOf(table, 'MAN'), 'and its QTH is Manitoulin''s');
      CheckEquals(0, Pos('P12.DOM', includes), 'P12.DOM is not included');
      CheckEquals(0, Pos('P13.DOM', includes), 'P13.DOM is not included');
      CheckEquals(0, Pos('S50P13', includes), 'nor S50P13');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;

   (* And outside Ontario, where the county file alone is the table. *)
   LoadCountyTable('ontario_cty.dom', True);
   try
      CheckEquals('MAN', MultiplierOf(CountyTable, 'MAN'), 'outside Ontario MAN is Manitoulin');
      CheckTrue(CountyFileKnowsQTH('MAN'), 'an Ontario station');
      CheckFalse(CountyFileKnowsQTH('MB'), 'Manitoba is not');
   finally
      FreeCountyTable;
   end;
end;

(* "Ontario stations also claim 1 multiplier point for each ... DXCC country
   worked on each band." NY4I: DXCC other than K, VE, KH6 and KL (those are
   states and provinces here). The key is the worked station's DXCC country.
   None outside Ontario. Asked through the nil-safe seams LOGEDIT asks. *)
procedure TContestOntarioQPTests.Test_OntarioInProvinceDXMultiplier;
var
   contestObject: TContestBase;

   function KeyFor(const aCountryID: string; out aKey: string): boolean;
   var
      qso: ContestExchange;
      key: DXMultiplierString;
   begin
      qso := OntarioQso(Band20, CW, eCW, aCountryID);
      qso.QTH.CountryID := ShortString(aCountryID);
      Result := ContestDXMultiplierKey(contestObject, qso, key);
      aKey := string(key);
   end;

var
   key: string;
begin
   BeginTest('Test_OntarioInProvinceDXMultiplier');
   contestObject := MakeOntario(StationAt(True));
   try
      CheckTrue(ContestHasDXMultiplier(contestObject), 'in Ontario there is a DX multiplier');
      CheckTrue(KeyFor('DL', key), 'Germany is a DX multiplier');
      CheckEquals('DL', key, 'keyed by its DXCC country');
      CheckTrue(KeyFor('G', key), 'England is');
      CheckEquals('G', key, 'keyed G');
      CheckTrue(KeyFor('KP4', key), 'Puerto Rico is DXCC, not a state');
      CheckTrue(KeyFor('XE', key), 'and Mexico');
      CheckFalse(KeyFor('K', key), 'no key for the USA (a state multiplier)');
      CheckEquals('', key, 'and none written');
      CheckFalse(KeyFor('VE', key), 'nor Canada (a province)');
      CheckFalse(KeyFor('KH6', key), 'nor Hawaii (a state)');
      CheckFalse(KeyFor('KL', key), 'nor Alaska (a state)');
   finally
      contestObject.Free;
   end;

   contestObject := MakeOntario(StationAt(False));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'outside Ontario there is no DX multiplier');
      CheckFalse(KeyFor('DL', key), 'so no key for Germany');
   finally
      contestObject.Free;
   end;

   contestObject := MakeOntario(DXStation('DL'));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'a DX entrant has none either');
      CheckFalse(KeyFor('JA', key), 'so no key for Japan');
   finally
      contestObject.Free;
   end;
end;

(* "Non-Ontario stations work Ontario stations only." "Non-Ontario stations
   must log received signal report and county abbreviation as per the
   Ontario County list." Q107: an out-of-province entrant's QSO with a
   station the session's table (the shipped ontario_cty.dom, through the
   real loader) does not know is refused when typed, and is an X-QSO when
   logged any other way. *)
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
   contestObject := MakeOntario(OutOfProvinceStation);
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestOntarioQPTests.Test_OntarioOutOfProvinceWorksOnlyOntario;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
   list: TStringList;
   i: integer;
   code: string;
begin
   BeginTest('Test_OntarioOutOfProvinceWorksOnlyOntario');
   list := TStringList.Create;
   LoadCountyTable('ontario_cty.dom', True);
   try
      (* EVERY ONE OF THE SPONSOR'S 50 MULTIPLIERS is its own multiplier and
         a station this entrant may work. *)
      ReadSponsorMultiplierList(list, nil);
      CheckEquals(50, list.Count, 'the sponsor''s list has 50 multipliers');
      CheckEquals(50, mo.DomList.Count, 'the county file is 50 multipliers');
      for i := 0 to list.Count - 1 do
         begin
         code := list.Names[i];
         CheckEquals(code, MultiplierOf(CountyTable, code), code + ' is its own multiplier');
         CheckTrue(CountyFileKnowsQTH(code), code + ' is an Ontario station');
         end;

      (* TYPED: a county is taken; anything else is refused with the
         party's reason. *)
      CheckTrue(ParseOutOfProvince('TOR', msg), 'outside Ontario, a Toronto station');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(ParseOutOfProvince('sdg', msg), 'Stormont, Dundas & Glengarry, typed in lower case');
      CheckFalse(ParseOutOfProvince('NY', msg), 'outside Ontario, a New York station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['ON']), msg, 'with the reason');
      CheckFalse(ParseOutOfProvince('QC', msg), 'a Quebec station: refused');
      CheckFalse(ParseOutOfProvince('ON', msg),
                 'ON alone is no county: "county abbreviation as per the Ontario County list"');
      CheckFalse(ParseOutOfProvince('DL', msg), 'a DX station: refused');

      (* LOGGED: the same rule scores 0 and earns no multiplier. *)
      CheckEquals(2, PointsFor(OutOfProvinceStation, Band20, CW, eCW, 'OTT'), 'logged: a county scores');
      CheckEquals(0, PointsFor(OutOfProvinceStation, Band20, CW, eCW, 'NY'), 'logged: New York scores 0');
      CheckEquals(0, PointsFor(OutOfProvinceStation, Band20, CW, eCW, 'DL'), 'logged: DX scores 0');
      CheckEquals(0, PointsFor(OutOfProvinceStation, Band20, CW, eCW, ''), 'logged: no QTH scores 0');

      contestObject := MakeOntario(OutOfProvinceStation);
      try
         qso := OntarioQso(Band20, CW, eCW, 'NY');
         CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                    'and earns no multiplier (the predicate SetMultFlags asks)');
         CheckTrue(QSOIsXQSO(contestObject, qso), 'an automatic X-QSO, judged with the entrant (Q119)');
         qso := OntarioQso(Band20, CW, eCW, 'TOR');
         CheckTrue(ContestCreditsWorkedStation(contestObject, qso), 'a county is credited');
         CheckFalse(QSOIsXQSO(contestObject, qso), 'and is no X-QSO');
      finally
         contestObject.Free;
      end;
   finally
      FreeCountyTable;
      list.Free;
   end;
end;

(* "If a mobile or a rover station is on a county line or junction between 2
   or more counties (within 250 meters of a county line), a separate QSO and
   complete exchange must be made and logged for each county worked"; the
   fixed county-line station the same. No maximum (NY4I: unlimited). The
   engine half (one QSO per county) is the real-engine test's. *)
procedure TContestOntarioQPTests.Test_OntarioCountyLinesHaveNoMaximum;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
   n: integer;
begin
   BeginTest('Test_OntarioCountyLinesHaveNoMaximum');
   contestObject := MakeOntario(NoStation);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(CountyLineCountiesUnlimited, party.CountyLineCountiesMax, 'no maximum');
      CheckTrue(party.CountyLineAllowed, 'a county line is allowed');
      for n := 1 to 8 do
         begin
         CheckTrue(party.ValidateQTHCount(n, msg), IntToStr(n) + ' counties are taken');
         CheckEquals('', msg, 'nothing to say about ' + IntToStr(n));
         end;
      CheckTrue(party.ValidateQTHCount(50, msg), 'even all 50');
   finally
      contestObject.Free;
   end;
end;

(* "You may work a station TWICE per band: once on phone and once on CW."
   "Mobile/Rover stations may be worked again when they change multiplier
   areas." Through the dupe path LogContact takes
   (uTestQSOPartyRules.RoverDupeAnswers): the same call from a new county on
   the same band and mode is a new QSO; from the first county again it is a
   dupe. Phone and FM are one dupe mode -- the engine's (DupeSlot), pinned
   in the real-engine test. *)
procedure TContestOntarioQPTests.Test_OntarioDupes;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_OntarioDupes');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(OntarioHandle)),
             'the received county is part of the dupe key');
   CheckTrue(ContestDupeModeOf(ContestIdentity(OntarioHandle), CW) = CW, 'CW is its own dupe mode');
   CheckTrue(ContestDupeModeOf(ContestIdentity(OntarioHandle), Phone) = Phone, 'and phone its own');
   RoverDupeAnswers(OntarioHandle, 'VE3ABC', 'TOR', 'YRK', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'VE3ABC from York after Toronto, 20 m CW: a new station');
   CheckTrue(sameCountyIsDupe, 'VE3ABC from Toronto again, 20 m CW: a dupe');
   RoverDupeAnswers(OntarioHandle, 'VE3ABC/M', 'MAN', 'SUD', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'a /M call from Sudbury after Manitoulin: a new station');
   CheckTrue(sameCountyIsDupe, 'and from Manitoulin again: a dupe');
end;

(* "Total Score = Total QSO points x total multiplier points." For an
   Ontario entrant the multipliers are the domestic ones (counties, states,
   DC, provinces) PLUS the DXCC countries; for anyone else the counties. No
   power multiplier: QRP, LOW and HIGH score alike.

   NOT BUILT, #133: the rover's "sum of multipliers worked from each
   different Ontario multiplier location" and the "300 bonus points for each
   Ontario multiplier activated". The score is points x multipliers only --
   pinned so the day #133 lands is seen here. *)
procedure TContestOntarioQPTests.Test_OntarioScoreIsPointsTimesMultipliers;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_OntarioScoreIsPointsTimesMultipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 1000;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 60;
   t.Mults[AllBands, Both, rmDX] := 9;

   station := StationAt(True);
   station.MyPower := cpQRP;
   view := TLoggedQSOList.Create;
   contestObject := MakeOntario(station);
   try
      CheckEquals(69000, contestObject.FinalScore(t, view),
                  'points x (domestic + DX multipliers), QRP');
      station.MyPower := cpLOW;
      contestObject.SetStation(station);
      CheckEquals(69000, contestObject.FinalScore(t, view), 'LOW the same');
      station.MyPower := cpHIGH;
      contestObject.SetStation(station);
      CheckEquals(69000, contestObject.FinalScore(t, view), 'HIGH the same');
      CheckEquals(0, contestObject.BonusPoints(t, view), 'no bonus: the rover bonus is #133');

      contestObject.SetStation(StationAt(False));
      t.QSOPoints := 168;
      t.Mults[AllBands, Both, rmDomestic] := 30;
      t.Mults[AllBands, Both, rmDX] := 0;
      CheckEquals(168 * 30, contestObject.FinalScore(t, view), 'outside Ontario, points x counties');

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

(* ontario_cty.dom IS THE SPONSOR'S LIST (ON-QSO-PARTY-Multipliers.txt, from
   "OQP Ontario Multiplier List - Effective 01Jan2023"): the 50 codes, each
   once, each named as the sponsor names it, each its OWN multiplier ("each
   Ontario county" for every entrant, so no line maps a code to the
   province) -- and nothing else: no INCLUDE, so an out-of-province
   entrant's table holds only counties (the host-area rule reads it). *)
procedure TContestOntarioQPTests.Test_OntarioCountyFileIsTheSponsorsList;
var
   sponsorList: TStringList;
   sections: TStringList;
   lines: TStringList;
   seen: TStringList;
   i: integer;
   key: string;
   line: string;
begin
   BeginTest('Test_OntarioCountyFileIsTheSponsorsList');
   sponsorList := TStringList.Create;
   sections := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      ReadSponsorMultiplierList(sponsorList, sections);
      CheckEquals(50, sponsorList.Count, 'the sponsor lists 50 multipliers');
      (* Every code carries one of the four Ontario ARRL sections ("In
         Ontario you are one of: ONN, ONS, ONE, or GH"). *)
      for i := 0 to sections.Count - 1 do
         begin
         CheckTrue(Pos(',' + sections.ValueFromIndex[i] + ',', ',ONN,ONS,ONE,GH,') > 0,
                   sections.Names[i] + ' is in an Ontario section');
         end;

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      lines.LoadFromFile(ShippedDomDir + 'ontario_cty.dom');
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         CheckTrue((DomIncludeName(line) = '') and
                   (Pos('INCLUDE', UpperCase(TrimLeft(line))) <> 1),
                   'the county file includes nothing, line ' + IntToStr(i + 1));
         key := DomFileLineKey(line);
         if key = '' then
            begin
            Continue;
            end;
         CheckTrue(seen.IndexOf(key) < 0, 'each code once: ' + key);
         seen.Add(key);
         CheckTrue(sponsorList.IndexOfName(key) >= 0, key + ' is in the sponsor''s list');
         CheckEquals(key + ' = ' + key + ',^' + sponsorList.Values[key], line,
                     'its own multiplier, its own alias, the sponsor''s name: ' + line);
         end;
      CheckEquals(50, seen.Count, 'ontario_cty.dom holds the 50 codes and nothing else');
   finally
      seen.Free;
      lines.Free;
      sections.Free;
      sponsorList.Free;
   end;

   (* AS AN ONTARIO STATION READS IT (MultipliersIsCounties False): still 50
      multipliers, not one. *)
   LoadCountyTable('ontario_cty.dom', False);
   try
      CheckEquals(50, mo.DomList.Count, 'in Ontario, the 50 codes are 50 multipliers');
      CheckEquals('TOR', MultiplierOf(CountyTable, 'TOR'), 'Toronto counts as Toronto');
      CheckEquals('', MultiplierOf(CountyTable, 'ON'), 'no province is in the county file');
      CheckEquals('', MultiplierOf(CountyTable, 'NY'), 'nor a state');
   finally
      FreeCountyTable;
   end;
end;

(* ontario.dom, read as text: the header holds no '=' (the loader has no
   comment syntax); the county file FIRST (MAN is Manitoulin), then S50.DOM
   and DC.DOM -- DC its own multiplier -- each INCLUDE spelt so the loader
   follows it; then the 12 other provinces and territories written in the
   file, Ontario not among them, NF and LB as Newfoundland and Labrador's.
   Then through the real loader: 50 codes + 50 states + DC + 12 provinces
   and territories = 113 domestic multipliers. *)
procedure TContestOntarioQPTests.Test_OntarioInProvinceFileIsTheRulesMultipliers;
var
   lines: TStringList;
   includes: string;
   included: string;
   keys: string;
   inHeader: boolean;
   i: integer;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   BeginTest('Test_OntarioInProvinceFileIsTheRulesMultipliers');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'ontario.dom');
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
                       'ontario.dom line ' + IntToStr(i + 1)
                       + ' is an INCLUDE the loader would not follow');
            if inHeader then
               begin
               CheckEquals(0, Pos('=', lines[i]),
                           'ontario.dom header line ' + IntToStr(i + 1)
                           + ' would be read as an entry');
               end
            else if DomFileLineKey(lines[i]) <> '' then
               begin
               keys := keys + UpperCase(DomFileLineKey(lines[i])) + ' ';
               end;
            end;
         end;
      CheckEquals('ONTARIO_CTY.DOM S50.DOM DC.DOM ', includes,
                  'the counties first, then the states, then DC');
      CheckEquals('NS QC MB SK AB BC NT NB NU YT PE NL ', keys,
                  'its own entries: the 12 provinces and territories other than Ontario');
   finally
      lines.Free;
   end;

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'ontario.dom', True, 0);
      CheckEquals(113, mo.DomList.Count,
                  '50 codes, 50 states, DC and 12 provinces and territories');
      CheckEquals('TOR', MultiplierOf(table, 'TOR'), 'a county keeps its own code');
      CheckEquals('DC', MultiplierOf(table, 'DC'), 'DC is DC');
      CheckEquals('NL', MultiplierOf(table, 'NF'), 'NF is NL');
      CheckEquals('LA', MultiplierOf(table, 'LA'), 'LA is Louisiana');
      CheckEquals('', MultiplierOf(table, 'ON'), 'Ontario is not one');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* ---------------------------------------------------------------------------
   EXPORT AND SET-UP
   --------------------------------------------------------------------------- *)

(* ADIF STATE is the worked station's (Q76/Q89, the party base's): ON for an
   Ontario code, the station's own province or state otherwise, none for DX.
   CNTY is not written (NY4I). *)
procedure TContestOntarioQPTests.Test_OntarioADIFStateAndNoCounty;
var
   identity: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_OntarioADIFStateAndNoCounty');
   identity := ContestIdentity(OntarioHandle);
   qso := OntarioQso(Band20, CW, eCW, 'TOR');
   qso.DomesticQTH := 'TOR';
   qso.QTH.CountryID := 'VE';
   CheckEquals('ON', identity.ADIFWorkedStationState(qso), 'a Toronto station is in ON');
   qso := OntarioQso(Band20, CW, eCW, 'QC');
   qso.DomesticQTH := 'Qc';
   qso.QTH.CountryID := 'VE';
   CheckEquals('QC', identity.ADIFWorkedStationState(qso), 'a Quebec station is in QC');
   qso := OntarioQso(Band20, CW, eCW, 'NY');
   qso.DomesticQTH := 'NY';
   qso.QTH.CountryID := 'K';
   CheckEquals('NY', identity.ADIFWorkedStationState(qso), 'a New York station is in NY');
   qso := OntarioQso(Band20, CW, eCW, 'DL');
   qso.QTH.CountryID := 'DL';
   CheckEquals('', identity.ADIFWorkedStationState(qso), 'a DX station has no STATE');   CheckFalse(identity.WritesADIFCounty, 'and no CNTY is written');
end;

(* NY4I: "Its own province prompt". The shared prompt would read "Enter your
   county if you in ON state"; Ontario's names the county code. *)
procedure TContestOntarioQPTests.Test_OntarioNewContestPrompt;
var
   prompts: TNewContestPrompts;
   step: TNewContestPrompt;
begin
   BeginTest('Test_OntarioNewContestPrompt');
   prompts := TNewContestPrompts.Create;
   try
      ContestIdentity(OntarioHandle).DescribeNewContestPrompts(prompts);
      CheckEquals(1, prompts.ChoiceCount, 'one step when the contest is chosen');
      CheckEquals(0, prompts.InsideCount, 'and none on an "I am in" box');
      if prompts.ChoiceCount = 1 then
         begin
         step := prompts.Choice(0);
         CheckTrue(step.Kind = npkFieldWithComment, 'a row with a comment');
         CheckTrue(step.Field = ncfMyState, 'the MY STATE row');
         CheckEquals(SNewContestOntarioQPCountyOrLocation, step.Text, 'in Ontario''s own words');
         CheckTrue(Pos('county code', step.Text) > 0, 'naming the county code');
         CheckEquals(0, Pos(' state. ', step.Text), 'and not "ON state"');
         end;
   finally
      prompts.Free;
   end;
end;

(* THE CABRILLO COLUMNS. The rules give no example line; they name the
   fields: "The exchange for OQP requires the sent and received QTH, not a
   serial number", the received "signal report and county, province, state,
   or DXCC country abbreviation", the sent "signal report and their county
   abbreviation" (Ontario) or "province, state, or DXCC country" (outside).
   So: RST and the sent QTH, then RST and the received QTH, in the standard
   QSO line. A DX entrant sends its own prefix (NY4I). *)
procedure TContestOntarioQPTests.Test_OntarioCabrilloColumns;
var
   contestObject: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
begin
   BeginTest('Test_OntarioCabrilloColumns');
   CheckEquals('ON-QSO-PARTY', ContestIdentity(OntarioHandle).CabrilloContestName('', ''),
               'CONTEST: ON-QSO-PARTY');

   (* A TORONTO STATION WORKS NEW YORK, THEN OTTAWA, THEN A DX STATION. *)
   contestObject := MakeOntario(StationAt(True));
   try
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');
      my := Default(TMyStationExchange);
      my.MyState := 'TOR';
      qso := OntarioQso(Band40, CW, eCW, 'NY');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'NY';
      CheckEquals('599 TOR    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent: RST and my county code');
      CheckEquals('599 NY     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RST and the state');
      CheckEquals('599 TOR    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my county code');

      ctx.RSTSent := '59';
      ctx.RSTReceived := '59';
      ctx.HisQTH := 'OTT';
      qso := OntarioQso(Band20, Phone, eUSB, 'OTT');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      CheckEquals('FM', contestObject.CabrilloModeString(FM, eFM), 'FM is FM');
      CheckEquals('59  TOR    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent on phone: RS and my county');
      CheckEquals('59  OTT    ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RS and the county');

      (* "DXCC country abbreviation (the abbreviation "DX" is also
         acceptable": what the station sent; nothing typed, its DX QTH. *)
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'DL';
      qso := OntarioQso(Band20, CW, eCW, 'DL');
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a DX station''s column is the prefix it sent');
      qso := OntarioQso(Band20, CW, eCW, '');
      qso.DXQTH := 'DL';
      ctx.HisQTH := '';
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'nothing typed: the DX QTH');
   finally
      contestObject.Free;
   end;

   (* A NEW YORK ENTRANT WORKS TORONTO. *)
   contestObject := MakeOntario(StationAt(False));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'NY';
      qso := OntarioQso(Band40, CW, eCW, 'TOR');
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'TOR';
      CheckEquals('599 NY     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent: RST and my state');
      CheckEquals('599 TOR    ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RST and the county code');
   finally
      contestObject.Free;
   end;

   (* A DX ENTRANT: MY STATE is empty, so the party base's SentLocation sends
      Station.MyCountry (NY4I). *)
   contestObject := MakeOntario(DXStation('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := '';
      qso := OntarioQso(Band20, CW, eCW, 'TOR');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'TOR';
      CheckEquals('599 DL     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent: RST and my prefix');
      CheckEquals('599 DL     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my prefix');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First a New
   York entrant with the shipped ontario_cty.dom, then a Toronto entrant with
   the shipped ontario.dom (its INCLUDEs followed by uTestShippedDom, since
   the test binary has no dom folder).
   --------------------------------------------------------------------------- *)

procedure TContestOntarioQPTests.Test_OntarioRealEngine;
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
   BeginTest('Test_OntarioRealEngine');
   h := OntarioHandle;
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
      (* AS FoundContest SETS IT UP FOR A NEW YORK STATION: not in Ontario,
         so the county file with each code its own multiplier; K, VE, KH6 and
         KL are domestic countries (Add_KVEKH6KL, as for every party); and
         the class's flags, as ApplyContestTraits writes them, so a wrong
         flag is seen here as a wrong dupe or multiplier. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'ontario_cty.dom'),
                'ontario_cty.dom loads');
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := False;
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* TORONTO, CW. *)
      dupe := Enter('VE3TOR', '599 TOR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 TOR is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('TOR', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Toronto is a new multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), '"2 QSO points for each station worked on CW"');

      (* "1 multiplier point for each Ontario county worked on each band". *)
      dupe := Enter('VE3TOR', '599 TOR', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'and Toronto IS a new multiplier on another band');

      (* "once on phone and once on CW" -- per band. *)
      dupe := Enter('VE3TOR', '59 TOR', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 TOR on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), '"2 QSO points for each station worked on phone"');
      CheckFalse(rx.DomesticMult, 'but no new multiplier in another mode on the same band');

      dupe := Enter('VE3TOR', '599 TOR', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Toronto again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* FM is phone: FM after SSB on one band is the same mode, so a dupe
         (the engine's DupeSlot -- "You may work a station TWICE per band"). *)
      dupe := Enter('VE3VHF', '59 OTT', Band2, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '2 m SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), '2 m phone scores 2');
      dupe := Enter('VE3VHF', '59 OTT', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted, '2 m FM is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'the same station on 2 m FM after SSB IS a dupe: FM is phone');

      (* THE CLUB STATIONS, the second through the engine's rover strip. *)
      dupe := Enter('VE3CCO', '599 TOR', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'VE3CCO is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(10, Integer(rx.QSOPoints), 'VE3CCO scores 10');
      dupe := Enter('VE3RHQ/OTT', '599 OTT', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'VE3RHQ/OTT is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(10, Integer(rx.QSOPoints), 'VE3RHQ roving in Ottawa scores 10');
      CheckTrue(rx.QTH.CountryID = 'VE', 'and is located as Canada, the /OTT stripped');

      (* "Mobile/Rover stations may be worked again when they change
         multiplier areas." *)
      dupe := Enter('VE3TOR', '599 YRK', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same call from York on 20 m CW: a new station');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores');
      CheckTrue(rx.DomesticMult, 'York is a new multiplier');

      (* NO DIGITAL: logged, an automatic X-QSO, nothing earned. *)
      dupe := Enter('VE3FT', '599 WAT', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'an FT8 QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');
      dupe := Enter('VE3FT', '599 WAT', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'so Waterloo on 20 m CW is still a new multiplier');

      (* NO WARC: 30 m is logged, an automatic X-QSO. *)
      dupe := Enter('VE3WRC', '599 GRY', Band30, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 30 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO ("with the exception of the WARC bands")');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and Grey is no multiplier from it');

      (* "Non-Ontario stations work Ontario stations only." A US call goes to
         the domestic parser, which refuses a QTH the county file does not
         know, naming the host-area reason when the in-province file knows
         it. *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'ontario_cty.dom';

      accepted := True;
      Enter('W2NY', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a New York station is refused');
      CheckEquals('Improper domestic QTH!! (NY: work ON stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      accepted := True;
      Enter('VE3ABC', '599 TOX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a misspelt county is refused');
      CheckEquals('Improper domestic QTH!! (TOX not in ontario_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the county file');

      accepted := True;
      Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['ON']), string(ExchangeErrorMessage),
                  'with the host-area reason');

      (* COUNTY LINES, NO MAXIMUM: "a separate QSO and complete exchange must
         be made and logged for each county worked". Five counties at a
         junction: the first is this QSO, four are queued. *)
      ClearPendingCounties;
      dupe := Enter('VE3LINE', '599 TOR/YRK/PEL/DUR/HTN', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a five-county junction is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('TOR', UpperCase(string(rx.QTHString)), 'the first county is this QSO');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckEquals(4, PendingCountiesCount, 'four more counties are queued');
      CheckEquals('YRK', UpperCase(DequeuePendingCounty), 'York, as its own QSO');
      CheckEquals('PEL', UpperCase(DequeuePendingCounty), 'Peel');
      CheckEquals('DUR', UpperCase(DequeuePendingCounty), 'Durham');
      CheckEquals('HTN', UpperCase(DequeuePendingCounty), 'Halton');
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
      rx.tSysTime.qtDay := 18;
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of province, a logged W2NY NY is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      rx.QTHString := 'TOR';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of province, a logged Toronto QSO is not');

      (* NOW A TORONTO ENTRANT: in Ontario, ontario.dom (the codes, the
         states, DC, the provinces), each code its own multiplier; and DXCC
         countries. *)
      MultipliersIsCounties := False;
      DomQTHTable.Free;
      DomQTHTable := TDomQTHTable.Create;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'ontario.dom', True, 0);
      StationInHostState := True;
      Settings.My.DeriveCountry('VE');
      Settings.Contest.DomesticFilename := 'ontario.dom';
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      dupe := Enter('W2AAA', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in Ontario, 599 NY is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'New York is a new multiplier');
      dupe := Enter('W2AAA', '59 NY', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'New York on 20 m SSB is not a dupe');
      CheckFalse(rx.DomesticMult, 'nor a new multiplier: per band, not per mode');
      dupe := Enter('W2AAA', '599 NY', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'but New York on 40 m IS a new multiplier');

      dupe := Enter('VE3MAN', '599 MAN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 MAN is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MAN', UpperCase(string(rx.DomMultQTH)), 'MAN is Manitoulin, not Manitoba');
      CheckTrue(rx.DomesticMult, 'a new multiplier');
      dupe := Enter('VE4AAA', '599 MB', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 MB is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MB', UpperCase(string(rx.DomMultQTH)), 'MB is Manitoba');
      CheckTrue(rx.DomesticMult, 'and is another multiplier');

      accepted := True;
      Enter('VE3ONT', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'ON is refused: an Ontario station sends its county');

      dupe := Enter('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 DC is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('DC', UpperCase(string(rx.DomMultQTH)), '"plus District of Columbia"');
      CheckTrue(rx.DomesticMult, 'a new multiplier');
      dupe := Enter('W3MD', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'Maryland');
      CheckTrue(rx.DomesticMult, 'is ANOTHER multiplier: DC is its own');

      dupe := Enter('VO1AAA', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NF is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'NF is Newfoundland and Labrador');
      CheckTrue(rx.DomesticMult, 'a new multiplier');
      dupe := Enter('VO2AAA', '599 LB', Band20, CW, eCW, accepted, rx);
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'LB is the same province');
      CheckFalse(rx.DomesticMult, 'so no new multiplier');

      dupe := Enter('KH6AAA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 HI is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Hawaii is a state multiplier');
      CheckFalse(rx.DXMult, 'and not a DX one');

      (* "and DXCC country worked on each band". *)
      dupe := Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in Ontario, a DX station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'for 2 points');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckTrue(rx.DXMult, 'and Germany is a new DX multiplier');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and in province it is no X-QSO');
      dupe := Enter('DL2BBB', '59 DL', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(rx.DXMult, 'Germany on 20 m SSB is no new multiplier');
      dupe := Enter('DL2BBB', '599 DL', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DXMult, 'but Germany on 40 m is: "on each band"');

      dupe := Enter('VA3CCO', '599 TOR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'VA3CCO from Ontario is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(10, Integer(rx.QSOPoints), 'and scores 10 for an Ontario entrant too');
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

procedure TContestOntarioQPTests.RunAllTests;
begin
   Test_OntarioIdentity;
   Test_OntarioBands;
   Test_OntarioPoints;
   Test_OntarioClubStationsScoreTen;
   Test_OntarioNoDigital;
   Test_OntarioInProvinceMultipliers;
   Test_OntarioMANIsManitoulin;
   Test_OntarioInProvinceDXMultiplier;
   Test_OntarioOutOfProvinceWorksOnlyOntario;
   Test_OntarioCountyLinesHaveNoMaximum;
   Test_OntarioDupes;
   Test_OntarioScoreIsPointsTimesMultipliers;
   Test_OntarioCountyFileIsTheSponsorsList;
   Test_OntarioInProvinceFileIsTheRulesMultipliers;
   Test_OntarioADIFStateAndNoCounty;
   Test_OntarioNewContestPrompt;
   Test_OntarioCabrilloColumns;
   Test_OntarioRealEngine;
end;

end.
