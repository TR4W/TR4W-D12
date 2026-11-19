(* Hawaii QSO Party, issue 118: the sponsor's rules as NY4I saved them in
   docs/ContestRules/QSOParties/Hawaii/hawaii-qso-party-rules.md, his
   rulings of 2026-11-17, cross-checked against DXLog.net HIQP.txt and
   HIQPHI.txt. Every ruling the class header records is pinned here, through
   ScoreQSO, the class's own answers, the shipped .dom files and the real
   engine (TQSOPartyEngine) for BOTH entrants -- in Hawaii and out of it. *)
unit uTestContestHawaiiQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestHawaiiQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_Schedule;
      procedure Test_BandsModesAndPoints;
      procedure Test_MultiplierAnswersByEntrant;
      procedure Test_DistrictFileAndInStateFile;
      procedure Test_HostAreaGridAndBlank;
      procedure Test_Score;
      procedure Test_RealEngineOutOfState;
      procedure Test_RealEngineInState;
      procedure Test_ExportColumns;
      procedure Test_ADIFImport;
      procedure Test_OffBandAndOffModeExports;
      procedure Test_NewContestSaysDistrict;
   end;

implementation

uses
   SysUtils, DateUtils, Classes, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestHawaiiQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uTestShippedDom, uMults, LogEdit,
   LogStuff, uPendingCounties, PostUnit, MainUnit, uTR4WStrings, uADIF,
   uCabrillo, uContestSchedule, uNewContestHostArea, uAppStrings, uQsoMyFacts,
   (* ActiveContest -- the object that holds the session's station, which
      the ADIF export asks. *)
   uContestFactory;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(HI_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('HI-QSO-PARTY is not registered');
      end;
end;

(* A Hawaii station in district aQTH (DomesticQTH resolved, as the parse
   leaves it), on aBand in aMode. *)
function HIQSO(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := PartyHandle;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.RSTSent := 599;
   Result.RSTReceived := 599;
   Result.QTHString := ShortString(aQTH);
   Result.DomesticQTH := ShortString(aQTH);
   Result.DomMultQTH := ShortString(aQTH);
   Result.QTH.CountryID := 'KH6';
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 8;
   Result.tSysTime.qtDay := 22;
   Result.tSysTime.qtHour := 16;
end;

(* A GRID QSO: Digital, the grid as the received QTH, no domestic key. *)
function GridQSO(const aCall, aGrid, aCountry: string; aExt: ExtendedModeType): ContestExchange;
begin
   Result := HIQSO(aCall, aGrid, Band20, Digital, aExt);
   Result.DomesticQTH := '';
   Result.DomMultQTH := '';
   Result.QTH.CountryID := ShortString(aCountry);
   Result.RSTReceived := -10;
end;

function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'HON';
      end
   else
      begin
      Result.MyState := 'CA';
      end;
   Result.MyCountry := 'K';
end;

(* THE SSB SUBMODES -- "Only SSB counts as phone" (NY4I); eNoMode and eData
   are "some submode" (Q98 S1). *)
function IsSSB(aMode: ModeType; aExt: ExtendedModeType): boolean;
begin
   Result := (aMode = Phone) and (aExt in [eNoMode, eData, eSSB, eUSB, eLSB]);
end;

procedure TContestHawaiiQPTests.Test_Identity;
var
   party: TContestBase;
   legacy: integer;
   msg: string;
   key: string;
   qso: ContestExchange;
const
   (* NY4I's reverse lookup, district -> ADIF Hawaii county. *)
   COUNTY_OF: array[0..13, 0..1] of string = (
      ('HON', 'Honolulu'), ('LHN', 'Honolulu'), ('PRL', 'Honolulu'), ('WHN', 'Honolulu'),
      ('KAU', 'Kauai'), ('NII', 'Kauai'),
      ('LNI', 'Maui'), ('MAU', 'Maui'), ('MOL', 'Maui'),
      ('KAL', 'Kalawao'),
      ('HIL', 'Hawaii'), ('KOH', 'Hawaii'), ('KON', 'Hawaii'), ('VOL', 'Hawaii'));
   (* ADIF's CNTY enumeration for HI (the vendored validator's adiftags.py). *)
   ADIF_HI_COUNTIES = ' HAWAII HONOLULU KALAWAO KAUAI MAUI ';
var
   i: integer;
begin
   BeginTest('Test_HawaiiIdentity');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestHawaiiQP, 'the id resolves to the Hawaii class');
   CheckTrue(TContestHawaiiQP.ClassParent = TContestStateQSOPartyBase,
      'directly on the state-party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'registered by id: no frozen enum member');

   (* CABRILLO and ADIF are two identities, checked apart. *)
   CheckEquals('HI-QSO-PARTY', party.CabrilloName,
      'Cabrillo CONTEST: is DXLog''s CABRILLO_CONTEST_NAME');
   CheckEquals('HI-QSO-PARTY', party.ADIFContestId,
      'ADIF CONTEST_ID is the Contest_ID enumeration''s HI-QSO-PARTY');
   CheckEquals('Hawaii QSO Party', party.DisplayName, 'display name');
   CheckEquals('Hawaii QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals(0, party.WA7BNMId, 'WA7BNM not looked up');
   CheckEquals('', party.SubmissionEmail, 'logs are uploaded at hqp.contesting.com');

   CheckEquals('HI', party.HostState, 'host');
   CheckTrue(party.IsUSQSOParty, 'a US QSO party');
   CheckEquals('hawaiiqp_cty', party.DomesticFileName, 'district file (hawaii.dom is s50''s)');
   CheckEquals('hawaiiqp', party.InStateDomesticFileName, 'in-state file');
   CheckTrue(party.ExchangeKind = RSTDomesticOrDXQTHExchange, 'RST + district/state/province/DX');
   CheckTrue(party.InitialExchangeKind = NoInitialExchange, 'no initial exchange');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand],
      '"three times per band ... CW, SSB, digital"; districts "per band" outside');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, 'a mobile in a new district is a new station');
   CheckTrue(party.StripsRoverCountyFromCall and party.SplitsRoverCallOnExport,
      'the QSO-party rover rules, inherited');
   CheckTrue(party.ExchangeCarriesDomesticQTH, 'the exchange carries a QTH');

   (* DISTRICT LINES: two -- "AH7RF/KOH/KON ... TWO contacts". *)
   CheckTrue(party.ValidateQTHCount(2, msg), 'a line of two districts');
   CheckEquals('', msg, 'nothing to say');
   CheckFalse(party.ValidateQTHCount(3, msg), 'three are refused');
   CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');

   (* ADIF CNTY: the district's county (NY4I), every name ADIF's. *)
   CheckTrue(party.WritesADIFCounty, 'CNTY is written');
   for i := 0 to High(COUNTY_OF) do
      begin
      qso := HIQSO('KH6AA', COUNTY_OF[i, 0], Band20, CW, eCW);
      key := party.ADIFCountyName(qso, 'the district''s own name');
      CheckEquals(COUNTY_OF[i, 1], key, COUNTY_OF[i, 0] + ' lies in ' + COUNTY_OF[i, 1]);
      CheckTrue(Pos(' ' + UpperCase(key) + ' ', ADIF_HI_COUNTIES) > 0,
         key + ' is in ADIF''s CNTY enumeration for HI');
      end;
   qso := HIQSO('W1AW', 'CT', Band20, CW, eCW);
   CheckEquals('', party.ADIFCountyName(qso, 'Connecticut'), 'a state has no Hawaii county');
end;

(* WHEN IT RUNS -- NY4I: Sat Aug 22 2026 1600Z to Mon Aug 24 0400Z (the
   pasted Aug 21 was a typo), and Sat Aug 21 2027; 36 h from 1600Z. The
   class's RETURNED string, parsed and resolved against explicit instants. *)
procedure TContestHawaiiQPTests.Test_Schedule;
var
   schedule: TContestSchedule;
   err: string;
   key: TDateTime;
begin
   BeginTest('Test_HawaiiSchedule');
   CheckTrue(TryParseContestSchedule(ContestIdentity(PartyHandle).Schedule, schedule, err),
      'the schedule parses (' + err + ')');
   CheckTrue(TryScheduleSortKey(schedule, EncodeDateTime(2026, 8, 1, 0, 0, 0, 0), key), 'a 2026 period');
   CheckTrue(key = EncodeDateTime(2026, 8, 22, 16, 0, 0, 0), 'starts Sat Aug 22 2026 at 1600Z');
   CheckTrue(TryScheduleSortKey(schedule, EncodeDateTime(2026, 8, 24, 3, 59, 0, 0), key), 'running');
   CheckTrue(key = EncodeDateTime(2026, 8, 24, 3, 59, 0, 0), 'still on the air at Mon 0359Z');
   CheckTrue(TryScheduleSortKey(schedule, EncodeDateTime(2026, 8, 24, 4, 0, 0, 0), key), 'next');
   CheckTrue(key = EncodeDateTime(2027, 8, 21, 16, 0, 0, 0), 'ends Mon Aug 24 0400Z; next Sat Aug 21 2027');
   (* MORE YEARS, computed independently (the Saturday before the 4th Sunday
      of August, Python's calendar). *)
   CheckTrue(TryScheduleSortKey(schedule, EncodeDateTime(2024, 1, 1, 0, 0, 0, 0), key), '2024');
   CheckTrue(key = EncodeDateTime(2024, 8, 24, 16, 0, 0, 0), 'Sat Aug 24 2024');
   CheckTrue(TryScheduleSortKey(schedule, EncodeDateTime(2025, 1, 1, 0, 0, 0, 0), key), '2025');
   CheckTrue(key = EncodeDateTime(2025, 8, 23, 16, 0, 0, 0), 'Sat Aug 23 2025');
   CheckTrue(TryScheduleSortKey(schedule, EncodeDateTime(2028, 1, 1, 0, 0, 0, 0), key), '2028');
   CheckTrue(key = EncodeDateTime(2028, 8, 26, 16, 0, 0, 0), 'Sat Aug 26 2028');
   CheckTrue(TryScheduleSortKey(schedule, EncodeDateTime(2030, 1, 1, 0, 0, 0, 0), key), '2030');
   CheckTrue(key = EncodeDateTime(2030, 8, 24, 16, 0, 0, 0), 'Sat Aug 24 2030');
end;

procedure TContestHawaiiQPTests.Test_BandsModesAndPoints;
var
   party: TContestBase;
   inHost: boolean;
   band: BandType;
   mode: ModeType;
   ext: ExtendedModeType;
   qso: ContestExchange;
   expected: integer;
begin
   BeginTest('Test_HawaiiBandsModesAndPoints');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         (* "only on the 10, 15, 20, 40, 80, and 160 meter bands". *)
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) =
               (band in [Band160, Band80, Band40, Band20, Band15, Band10]),
               'the six bands only');
            qso := HIQSO('KH6AA', 'HON', band, CW, eCW);
            party.ScoreQSO(qso);
            if band in [Band160, Band80, Band40, Band20, Band15, Band10] then
               begin
               CheckEquals(3, Integer(qso.QSOPoints), 'CW 3 on a contest band');
               end
            else
               begin
               CheckEquals(0, Integer(qso.QSOPoints), 'off-band scores 0 (an X-QSO)');
               end;
            end;

         (* "SSB: 2 points CW: 3 points digital: 3 points"; every digital
            submode is digital; FM and AM are not SSB (NY4I). *)
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode in [CW, Digital] then
                  begin
                  expected := 3;
                  end;
               if IsSSB(mode, ext) then
                  begin
                  expected := 2;
                  end;
               qso := HIQSO('KH6AA', 'HON', Band20, mode, ext);
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'SSB 2, CW and digital 3, FM 0');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0),
                  'CW, SSB and every digital submode');
               end;
            end;
         CheckFalse(party.UsesMode(FM, eFM), 'FM is not phone here');
         CheckFalse(party.UsesMode(Phone, eAM), 'nor is AM');

         (* CABRILLO MODES (NY4I): CW, PH, and DG for every digital submode. *)
         CheckEquals('CW', party.CabrilloModeString(CW, eCW), 'CW');
         CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), 'SSB is PH');
         CheckEquals('DG', party.CabrilloModeString(Digital, eRTTY), 'RTTY is DG');
         CheckEquals('DG', party.CabrilloModeString(Digital, eFT8), 'FT8 is DG');
         CheckEquals('DG', party.CabrilloModeString(Digital, eNoMode), 'any digital is DG');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestHawaiiQPTests.Test_MultiplierAnswersByEntrant;
var
   party: TContestBase;
   session: TSessionDefaults;
   qso: ContestExchange;
   key: DXMultiplierString;
   domKey: string;
   kind: RemainingMultiplierType;
begin
   BeginTest('Test_HawaiiMultiplierAnswersByEntrant');
   (* OUTSIDE HAWAII: districts per band, no DX multiplier. *)
   party := Make(PartyHandle, StationAt(False));
   session := TSessionDefaults.Create;
   try
      party.DescribeSession(StationAt(False), session);
      CheckTrue(session.IsStated(svMultByBand) and session.MultByBand,
         '"14 Hawai''i districts per band" outside');
      CheckFalse(party.HasDXMultiplier, 'no DX multiplier outside Hawaii');
      qso := HIQSO('DL1AAA', 'DX', Band20, CW, eCW);
      qso.QTH.CountryID := 'DL';
      CheckFalse(party.DXMultiplierKey(qso, key), 'no DX key outside');
      CheckTrue(party.CountryMode = CQCountryMode, 'no list counted outside');
      CheckFalse(party.HasZoneMultiplier, 'no zones');
      CheckFalse(party.HasPrefixMultiplier, 'no prefixes');
   finally
      session.Free;
      party.Free;
   end;

   (* IN HAWAII: once only, DXCC but K, VE, KH6, KL, on the ARRL list. *)
   party := Make(PartyHandle, StationAt(True));
   session := TSessionDefaults.Create;
   try
      party.DescribeSession(StationAt(True), session);
      CheckTrue(session.IsStated(svMultByBand) and not session.MultByBand,
         '"ONCE ONLY - NOT PER BAND" in Hawaii');
      CheckTrue(party.HasDXMultiplier, 'DXCC entities in Hawaii');
      CheckTrue(party.CountryMode = ARRLCountryMode, 'the ARRL DXCC list');
      qso := HIQSO('DL1AAA', 'DX', Band20, CW, eCW);
      qso.QTH.CountryID := 'DL';
      CheckTrue(party.DXMultiplierKey(qso, key), 'a DL station is a DXCC multiplier');
      CheckEquals('DL', string(key), 'keyed by its entity');
      qso.QTH.CountryID := 'KP4';
      CheckTrue(party.DXMultiplierKey(qso, key), 'Puerto Rico is a DXCC entity of its own');
      qso.QTH.CountryID := 'KH6';
      CheckFalse(party.DXMultiplierKey(qso, key), 'Hawaii is districts, not DXCC');
      qso.QTH.CountryID := 'KL';
      CheckFalse(party.DXMultiplierKey(qso, key), 'Alaska is a state');
      qso.QTH.CountryID := 'K';
      CheckFalse(party.DXMultiplierKey(qso, key), 'the USA is states');
      qso.QTH.CountryID := 'VE';
      CheckFalse(party.DXMultiplierKey(qso, key), 'Canada is provinces');

      (* A DISTRICT DOES NOT ALSO EARN HI -- no second domestic key. *)
      qso := HIQSO('KH6AA', 'HON', Band20, CW, eCW);
      CheckFalse(party.AdditionalDomesticMultiplierKey(qso, domKey),
         'a district is its own multiplier and earns no HI');
      CheckTrue(party.CountsAsMultiplier(qso, rmDomestic), 'HI-to-HI earns the district');

      (* A GRID QSO EARNS NO MULTIPLIER OF ANY KIND -- the sponsor decides. *)
      qso := GridQSO('DL1FT', 'JO62', 'DL', eFT8);
      for kind := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
         begin
         CheckFalse(party.CountsAsMultiplier(qso, kind), 'a grid QSO counts no multiplier');
         end;
      qso := HIQSO('W1AW', 'CN87', Band20, CW, eCW);
      CheckTrue(party.CountsAsMultiplier(qso, rmDomestic),
         'a grid shape on CW is no grid QSO (and is refused when typed)');
   finally
      session.Free;
      party.Free;
   end;
end;

procedure TContestHawaiiQPTests.Test_DistrictFileAndInStateFile;
var
   lines: TStringList;
   includes: string;
   i: integer;
   line: string;
   inHeader: boolean;
begin
   BeginTest('Test_HawaiiDistrictFileAndInStateFile');
   (* THE 14 DISTRICTS, each its own multiplier, against the transcription. *)
   CheckEquals('', CountyFileDifference('Hawaii', 'hawaiiqp_cty.dom',
      'HI-QSO-PARTY-Districts.txt', 14), 'the 14 district codes and names');

   (* hawaiiqp.dom AS TEXT: no '=' in the header, and the include list. *)
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'hawaiiqp.dom'));
      includes := '';
      inHeader := True;
      for i := 0 to lines.Count - 1 do
         begin
         line := Trim(string(lines[i]));
         if Pos('INCLUDE', UpperCase(line)) = 1 then
            begin
            inHeader := False;
            includes := includes + line + '|';
            end
         else if inHeader then
            begin
            CheckEquals(0, Pos('=', line), 'no = in the header: ' + line);
            end;
         end;
      CheckEquals('INCLUDE FILE hawaiiqp_cty.dom|INCLUDE FILE s48.dom|' +
         'INCLUDE FILE alaska.dom|INCLUDE FILE dc.dom|INCLUDE FILE p13.dom|',
         includes, 'districts first; 49 states (no HI); DC; s48 before p13');
   finally
      lines.Free;
   end;

   (* THROUGH THE REAL LOADER, AS A HAWAII STATION READS IT. *)
   CheckEquals('HON', InStateMultiplierOf(PartyHandle, 'HON'), 'a district is its own multiplier');
   CheckEquals('PRL', InStateMultiplierOf(PartyHandle, 'PRL'), 'Pearl Harbor Area');
   CheckEquals('VOL', InStateMultiplierOf(PartyHandle, 'VOL'), 'Volcano Park');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'HI'), 'HI is no multiplier: a HI station sends its district');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'KH6'), 'nor its call area');
   CheckEquals('CA', InStateMultiplierOf(PartyHandle, 'CA'), 'a state');
   CheckEquals('AK', InStateMultiplierOf(PartyHandle, 'AK'), 'Alaska is a state');
   CheckEquals('DC', InStateMultiplierOf(PartyHandle, 'DC'), '"US states (including DC)": DC on its own');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland is not DC');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'), 'LA stays Louisiana (s48 before p13)');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), 'Newfoundland and Labrador');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NF'), 'NF is logged as NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'LB'), 'LB is logged as NL');
   CheckEquals('ON', InStateMultiplierOf(PartyHandle, 'ON'), 'a province');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX is the DXCC multiplier, not an entry');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'JOH'),
      'another party''s county (KS Johnson) is no QTH: the operator enters the STATE');

   (* AS AN OUT-OF-STATE STATION READS THE DISTRICT FILE. *)
   LoadCountyTable('hawaiiqp_cty.dom', True);
   try
      CheckEquals(14, mo.DomList.Count, 'outside Hawaii: 14 district multipliers');
      CheckEquals('KAU', MultiplierOf(CountyTable, 'KAU'), 'Kauai counts as Kauai');
      CheckEquals('', MultiplierOf(CountyTable, 'HI'), 'no state in the district file');
   finally
      FreeCountyTable;
   end;
end;

procedure TContestHawaiiQPTests.Test_HostAreaGridAndBlank;
var
   party: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
begin
   BeginTest('Test_HawaiiHostAreaGridAndBlank');
   (* THE SHIPPED DISTRICT FILE is the host-area table -- WithHostAreaTable
      knows every QTH and could not fail this. *)
   LoadCountyTable('hawaiiqp_cty.dom', True);
   try
      station := StationAt(False);
      station.IsDomesticQTH := @CountyFileKnowsQTH;
      party := Make(PartyHandle, station);
      try
         qso := HIQSO('KH6AA', 'HON', Band20, CW, eCW);
         party.ScoreQSO(qso);
         CheckEquals(3, Integer(qso.QSOPoints), 'a Honolulu station: 3 points');
         qso := HIQSO('W1AW', 'CT', Band20, CW, eCW);
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), 'a Connecticut station: no credit outside Hawaii');
         CheckFalse(party.CreditsWorkedStation(qso), 'refused by the host-area rule');

         (* GRID SQUARES (NY4I): a Hawaii station's FT8 grid earns its points. *)
         qso := GridQSO('KH6FT', 'BL11', 'KH6', eFT8);
         party.ScoreQSO(qso);
         CheckEquals(3, Integer(qso.QSOPoints), 'a Hawaii FT8 QSO logged with a grid: 3 points');
         CheckTrue(party.CreditsWorkedStation(qso), 'and it is credited');
         qso := GridQSO('KH6FT', 'ZZ00', 'KH6', eFT4);
         party.ScoreQSO(qso);
         CheckEquals(3, Integer(qso.QSOPoints), 'the fake ZZ00 is accepted too');
         qso := GridQSO('W6FT', 'CM87', 'K', eFT8);
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), 'outside Hawaii a grid QSO with a W6 is no credit');

         (* BLANK SCORES ZERO. *)
         qso := HIQSO('KH6BL', '', Band20, CW, eCW);
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), 'a blank received QTH scores zero');
      finally
         party.Free;
      end;

      station := StationAt(True);
      station.IsDomesticQTH := @CountyFileKnowsQTH;
      party := Make(PartyHandle, station);
      try
         qso := HIQSO('W1AW', 'CT', Band20, CW, eCW);
         party.ScoreQSO(qso);
         CheckEquals(3, Integer(qso.QSOPoints), 'in Hawaii every station is valid');
         qso := GridQSO('W6FT', 'CM87', 'K', eFT8);
         party.ScoreQSO(qso);
         CheckEquals(3, Integer(qso.QSOPoints), 'in Hawaii a W6''s FT8 grid QSO earns 3');
         qso := HIQSO('DL1BL', '', Band20, CW, eCW);
         qso.QTH.CountryID := 'DL';
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), 'a blank received QTH scores zero in Hawaii too');
      finally
         party.Free;
      end;
   finally
      FreeCountyTable;
   end;
end;

procedure TContestHawaiiQPTests.Test_Score;
var
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   station: TStationContext;
begin
   BeginTest('Test_HawaiiScore');
   station := StationAt(True);
   party := Make(PartyHandle, station);
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 30;
      totals.Mults[AllBands, Both, rmDomestic] := 5;
      totals.Mults[AllBands, Both, rmDX] := 2;
      view.Add(HIQSO('KH6AA', 'HON', Band20, CW, eCW));
      CheckEquals(210, party.FinalScore(totals, view),
         '"QSO points times the number of earned multipliers": no cap, no bonus');
      station.MyPower := cpQRP;
      party.SetStation(station);
      CheckEquals(210, party.FinalScore(totals, view), 'no power factor');
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestHawaiiQPTests.Test_RealEngineOutOfState;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
   text: string;
begin
   BeginTest('Test_HawaiiRealEngineOutOfState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(14, mo.DomList.Count, 'outside Hawaii: the 14 districts');
      CheckTrue(Settings.Mult.ByBand, 'multipliers per band outside (DescribeSession)');
      CheckTrue(Settings.Qso.ByBand and Settings.Qso.ByMode, 'dupes per band and mode');

      engine.Enter('KH6AA', '599 HON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a district accepted and credited');
      CheckEquals(3, Integer(rx.QSOPoints), 'CW 3');
      dupe := engine.Enter('KH6AA', '59 HON', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'another mode is a new QSO');
      CheckFalse(rx.DomesticMult, 'a district per band, NOT per mode');
      CheckEquals(2, Integer(rx.QSOPoints), 'SSB 2');
      engine.Enter('KH6AA', '599 HON', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, '"14 Hawai''i districts per band": new again on 40 m');
      dupe := engine.Enter('KH6AA', '599 HON', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'the same district, band and mode is a dupe');

      (* "THREE TIMES PER BAND. ONCE EACH ON CW, SSB, DIGITAL (digital is any
         binary mode including RTTY, FT8, FT4, Winlink P2P, etc.)". *)
      dupe := engine.Enter('KH6BB', '599 KON', Band15, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'one: CW');
      dupe := engine.Enter('KH6BB', '59 KON', Band15, Phone, eLSB, accepted, rx);
      CheckFalse(dupe, 'two: SSB');
      dupe := engine.Enter('KH6BB', '599 KON', Band15, Digital, eRTTY, accepted, rx);
      CheckFalse(dupe, 'three: digital (RTTY)');
      CheckEquals(3, Integer(rx.QSOPoints), 'digital 3');
      dupe := engine.Enter('KH6BB', '599 KON', Band15, Digital, eFT8, accepted, rx);
      CheckTrue(dupe, 'FT8 after RTTY: one digital mode');
      dupe := engine.Enter('KH6BB', '599 KON', Band15, Digital, eFT4, accepted, rx);
      CheckTrue(dupe, 'FT4 too');
      dupe := engine.Enter('KH6BB', '599 KON', Band15, Digital, eData, accepted, rx);
      CheckTrue(dupe, 'a data mode (Winlink P2P) too');
      dupe := engine.Enter('KH6BB', '599 KON', Band15, Digital, ePSK31, accepted, rx);
      CheckTrue(dupe, 'PSK31 too');
      dupe := engine.Enter('KH6BB', '59 KON', Band15, Phone, eUSB, accepted, rx);
      CheckTrue(dupe, 'USB after LSB: one SSB mode');
      engine.Enter('KH6BB', '59 KON', Band15, FM, eFM, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'FM is no contest mode: a fourth QSO is an X-QSO, not a slot');
      dupe := engine.Enter('KH6BB', '599 KON', Band10, Digital, eFT8, accepted, rx);
      CheckFalse(dupe, 'another band opens three more');

      engine.Enter('KH6MOB', '599 KOH', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a mobile in Kohala');
      dupe := engine.Enter('KH6MOB', '599 KON', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'a mobile in a new district is a new station');
      engine.Enter('KH6RV/VOL', '599 VOL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a district-suffixed rover call');

      (* THE HOST-AREA RULE, typed. *)
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside Hawaii, work Hawaii stations only');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'nor a DX station');
      engine.Enter('KH6BAD', '599 XYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'not a Hawaii district');

      (* GRID SQUARES, typed (NY4I): points, no multiplier, no X-QSO. *)
      engine.Enter('KH6FT', 'BL11', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'a Hawaii station''s FT8 grid is taken');
      CheckEquals('BL11', string(rx.QTHString), 'the grid is the received QTH');
      CheckEquals(3, Integer(rx.QSOPoints), 'digital 3');
      CheckFalse(rx.DomesticMult, 'the sponsor decides its multiplier: none here');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and it is no X-QSO');
      engine.Enter('KH6FU', '-10 BL01', Band20, Digital, eFT4, accepted, rx);
      CheckTrue(accepted, 'a report and a grid');
      CheckEquals(-10, Integer(rx.RSTReceived), 'the signed report is the received report');
      engine.Enter('KH6FV', 'zz00', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'the fake ZZ00, in lower case');
      engine.Enter('W6FT', 'CM87', Band20, Digital, eFT8, accepted, rx);
      CheckFalse(accepted, 'outside Hawaii a W6''s grid is refused');
      engine.Enter('KH6CW', '599 BL11', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a grid is for a digital QSO: refused on CW');

      (* DISTRICT LINES: "AH7RF/KOH/KON ... Log such contacts as TWO
         contacts" -- two districts, the second its own QSO. *)
      ClearPendingCounties;
      engine.Enter('KH6LN', '599 KOH/KON', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a line of two districts');
      CheckEquals('KOH', string(rx.QTHString), 'the first district is this QSO');
      CheckTrue(rx.DomesticMult, 'and earns its multiplier');
      CheckEquals(3, Integer(rx.QSOPoints), 'and its points');
      CheckEquals(1, PendingCountiesCount, 'the second district is its own QSO, queued');
      ClearPendingCounties;
      accepted := True;
      engine.Enter('KH6LN', '599 HON/WHN/PRL', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'three districts are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
         'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;

      (* OFF-BAND: an automatic X-QSO. *)
      engine.Enter('KH6OFF', '599 HIL', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), '30 m is no contest band: an automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'and it earns no district');
      engine.Enter('KH6OFF', '599 HIL', Band6, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'nor is 6 m');
      engine.Enter('KH6OFF', '599 HIL', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '10 m counts, and the X-QSOs marked nothing');

      (* THE EXPORTS OF THAT QSO, as the writers build them. *)
      CheckEquals('599 HIL    ', PartyReceivedCabrilloColumn(PartyHandle, rx),
         'a district received');
      CheckEquals('599 HIL', ContestIdentity(PartyHandle).FormatADIFReceivedExchange(rx, True),
         'and its SRX_STRING');
      text := EmitADIFRecord(rx, ActiveContest(Contest));
      CheckTrue(Pos('<STATE:2>HI', text) > 0, 'a district is in Hawaii: ' + text);
      CheckTrue(Pos('<CONTEST_ID:12>HI-QSO-PARTY', text) > 0, 'CONTEST_ID: ' + text);
      text := EmitContestSpecificTailForExport(rx, NotCapturedMyFacts, '');
      CheckTrue(Pos('<CNTY:9>HI,Hawaii', text) > 0,
         'CNTY: Hilo lies in Hawaii County (PostUnit''s block): ' + text);
   finally
      engine.Free;
   end;
end;

procedure TContestHawaiiQPTests.Test_RealEngineInState;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
   text: string;
begin
   BeginTest('Test_HawaiiRealEngineInState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckFalse(Settings.Mult.ByBand, '"ONCE ONLY - NOT PER BAND" (DescribeSession)');
      CheckFalse(Settings.Mult.ByMode, 'and not per mode');

      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'in Hawaii every station counts: a state');
      CheckEquals(3, Integer(rx.QSOPoints), 'CW 3');
      dupe := engine.Enter('W1AW', '599 CT', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'another band is a new QSO');
      CheckFalse(rx.DomesticMult, 'but CT counts once only');
      engine.Enter('W1AW', '59 CT', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(rx.DomesticMult, 'once only, not per mode');
      CheckEquals(2, Integer(rx.QSOPoints), 'SSB 2');
      text := EmitContestSpecificTailForExport(rx, NotCapturedMyFacts, '');
      CheckTrue(Pos('<CNTY:', text) = 0, 'a state is no Hawaii district: no CNTY: ' + text);

      (* HAWAII TO HAWAII: valid, and the district counts. *)
      engine.Enter('KH6AA', '599 HON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a Hawaii station earns its district');
      CheckFalse(rx.DXMult, 'and no DXCC');
      CheckEquals(3, Integer(rx.QSOPoints), 'HI-to-HI CW 3');
      text := EmitContestSpecificTailForExport(rx, NotCapturedMyFacts, '');
      CheckTrue(Pos('<CNTY:11>HI,Honolulu', text) > 0,
         'a worked Hawaii district''s county, in Hawaii too: ' + text);
      engine.Enter('KH6AB', '599 HON', Band40, Digital, eFT8, accepted, rx);
      CheckFalse(rx.DomesticMult, 'the district once only');
      CheckEquals(3, Integer(rx.QSOPoints), 'HI-to-HI digital 3');
      engine.Enter('KH6AC', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'HI is no QTH: a Hawaii station sends its district');
      engine.Enter('W0KS', '599 JOH', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a Kansas county is refused: the operator enters KS');

      (* DXCC: once only, the entity from the call. *)
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a DX station sends DX');
      CheckTrue(rx.DXMult, 'its entity is a DXCC multiplier');
      CheckFalse(rx.DomesticMult, '"DX" is no domestic multiplier');
      CheckEquals(3, Integer(rx.QSOPoints), 'DX CW 3');
      CheckEquals('599 DX     ', PartyReceivedCabrilloColumn(PartyHandle, rx),
         'a DX station''s received column is DX');
      CheckEquals('599 DX', ContestIdentity(PartyHandle).FormatADIFReceivedExchange(rx, True),
         'and its SRX_STRING');
      text := EmitADIFRecord(rx, ActiveContest(Contest));
      CheckTrue(Pos('<STATE:', text) = 0, 'a DX station has no ADIF STATE: ' + text);
      engine.Enter('DL1AAA', '599 DX', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DXMult, 'DL once only, not per band');
      engine.Enter('KP4AA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DXMult, 'Puerto Rico is a DXCC entity');
      engine.Enter('KL7AA', '599 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Alaska is a state');
      CheckFalse(rx.DXMult, 'not a DXCC multiplier');

      (* DC ON ITS OWN; NF AND LB ARE NL EVERYWHERE. *)
      engine.Enter('W3AA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '"including DC"');
      engine.Enter('W3AB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Maryland is another multiplier');
      engine.Enter('VO1AA', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'NF accepted and credited');
      CheckEquals('NL', UpperCase(string(rx.DomesticQTH)), 'NF is logged as NL');
      CheckEquals('NL', string(rx.QTHString), 'and the received QTH reads NL');
      CheckEquals('599 NL     ', PartyReceivedCabrilloColumn(PartyHandle, rx),
         'Cabrillo NL');
      text := EmitADIFRecord(rx, ActiveContest(Contest));
      CheckTrue(Pos('<STATE:2>NL', text) > 0, 'ADIF STATE NL: ' + text);
      CheckEquals('599 NL', ContestIdentity(PartyHandle).FormatADIFReceivedExchange(rx, True),
         'SRX_STRING NL');
      engine.Enter('VO2AA', '599 LB', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'LB accepted');
      CheckFalse(rx.DomesticMult, 'LB is the same NL multiplier');
      CheckEquals('599 NL     ', PartyReceivedCabrilloColumn(PartyHandle, rx), 'LB exported as NL');
      CheckEquals('599 NL', ContestIdentity(PartyHandle).FormatADIFReceivedExchange(rx, True),
         'LB SRX_STRING NL');

      (* GRID SQUARES IN HAWAII: any station, points, no multiplier. *)
      engine.Enter('W6FT', '-12 CM87', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'a W6''s FT8 grid is taken in Hawaii');
      CheckEquals(3, Integer(rx.QSOPoints), 'digital 3');
      CheckFalse(rx.DomesticMult, 'no state multiplier from a grid');
      engine.Enter('DL1FT', 'JO62', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'a DL''s FT8 grid is taken');
      CheckFalse(rx.DXMult, 'no DXCC multiplier from a grid QSO');
      CheckEquals('JO62', string(rx.QTHString), 'the grid kept as the received QTH');
      engine.Enter('DL1FT', 'JO62', Band40, Digital, eFT8, accepted, rx);
      CheckFalse(rx.DXMult, 'nor on another band');
      text := EmitADIFRecord(rx, ActiveContest(Contest));
      CheckTrue(Pos('<STATE:', text) = 0, 'a grid QSO has no ADIF STATE: ' + text);
      engine.Enter('JA1FT', '599 DX', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(rx.DXMult, 'a digital QSO that sends DX still earns its DXCC entity');

      (* BLANK SCORES ZERO: a DX station that sent only its report. *)
      engine.Enter('DL3BL', '599', Band20, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'a blank received QTH is an automatic X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores zero');

      (* OFF-BAND IS AN X-QSO; FM AND AM ARE NOT SSB. *)
      engine.Enter('W7OFF', '599 OR', Band17, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), '17 m: an automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'and OR is not credited');
      engine.Enter('W7FM', '59 WA', Band10, FM, eFM, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'FM: an automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'and WA is not credited');
      engine.Enter('W7OFF', '599 OR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'OR on 20 m is still new');
   finally
      engine.Free;
   end;
end;

procedure TContestHawaiiQPTests.Test_ExportColumns;
var
   party: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   line: string;
   station: TStationContext;
   text: string;
begin
   BeginTest('Test_HawaiiExportColumns');
   party := ContestIdentity(PartyHandle);
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';

   (* AN OUT-OF-STATE ENTRANT (CA) WORKS HONOLULU -- DXLog's CABRILLO_LINE:
      freq mode date time mycall sent call received. *)
   rx := HIQSO('KH6AA', 'HON', Band20, CW, eCW);
   my := Default(TMyStationExchange);
   my.MyState := 'CA';
   ctx.HisQTH := 'HON';
   line := 'QSO: 14000 CW 2026-08-22 1600 W6AAA ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'KH6AA ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14000 CW 2026-08-22 1600 W6AAA 599 CA     KH6AA 599 HON    ',
      line, 'RST + state sent, RST + district received');
   CheckEquals('599 CA     ', party.FormatADIFSentExchange(my, rx), 'ADIF STX_STRING');

   (* A DX ENTRANT SENDS DX -- MY STATE empty, or the dialog's DX. *)
   my.MyState := '';
   CheckEquals('599 DX     ', party.FormatCabrilloSentExchange(my, rx, ctx), 'DX sent, MY STATE empty');
   CheckEquals('599 DX     ', party.FormatADIFSentExchange(my, rx), 'and in STX_STRING');
   my.MyState := 'DX';
   CheckEquals('599 DX     ', party.FormatCabrilloSentExchange(my, rx, ctx), 'DX sent, MY STATE DX');
   CheckEquals('599 DX     ', party.FormatADIFSentExchange(my, rx), 'and in STX_STRING');

   (* A HAWAII ENTRANT SENDS ITS DISTRICT. *)
   my.MyState := 'KON';
   rx := HIQSO('W1AW', 'CT', Band20, CW, eCW);
   rx.QTH.CountryID := 'K';
   ctx.HisQTH := 'CT';
   line := 'QSO: 14000 CW 2026-08-22 1600 KH6AAA ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'W1AW ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14000 CW 2026-08-22 1600 KH6AAA 599 KON    W1AW 599 CT     ',
      line, 'RST + district sent, RST + state received');
   CheckEquals('599 KON    ', party.FormatADIFSentExchange(my, rx), 'ADIF STX_STRING');

   (* THE SPONSOR'S GRID EXAMPLE: "QSO: 14080 DG 2020-08-22 0528 KH6TU -04
      MAU W6OAT -10 CN87" -- the grid in the received QTH column, DG. *)
   my.MyState := 'MAU';
   rx := GridQSO('W6OAT', 'CN87', 'K', eFT8);
   ctx.RSTSent := '-04';
   ctx.RSTReceived := '-10';
   ctx.HisQTH := '';
   line := 'QSO: 14080 ' + party.CabrilloModeString(rx.Mode, rx.ExtMode) +
      ' 2020-08-22 0528 KH6TU ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'W6OAT ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14080 DG 2020-08-22 0528 KH6TU -04 MAU    W6OAT -10 CN87   ',
      line, 'the sponsor''s grid line, column for column');
   CheckEquals('-10 CN87', party.FormatADIFReceivedExchange(rx, True), 'SRX_STRING: report and grid');
   (* WSJT-X's hand-off copies the grid into DomesticQTH; still a grid QSO. *)
   rx.DomesticQTH := 'CN87';
   CheckEquals('-10 CN87   ', party.FormatCabrilloReceivedExchange(my, rx, ctx),
      'the grid column also with the hand-off''s DomesticQTH');
   CheckEquals('', party.ADIFCountyState(rx), 'a grid is no Hawaii county');
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<STATE:', text) = 0, 'no STATE for a grid QSO: ' + text);

   (* THE CQ EXCHANGE. *)
   station := StationAt(True);
   station.MyState := 'KON';
   CheckEquals(' 5NN KON', party.CQExchangeDefault(station), 'a Hawaii station sends its district');
   station := StationAt(False);
   CheckEquals(' 5NN CA', party.CQExchangeDefault(station), 'a mainland station its state');
   station.MyState := '';
   CheckEquals(' 5NN DX', party.CQExchangeDefault(station), 'a DX station DX');
   station.MyState := 'DX';
   CheckEquals(' 5NN DX', party.CQExchangeDefault(station), 'also when MY STATE says DX');

   (* THE ADIF RECORD: CONTEST_ID and STATE HI for a district QSO. *)
   rx := HIQSO('KH6AA', 'HON', Band20, CW, eCW);
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<CONTEST_ID:12>HI-QSO-PARTY', text) > 0, 'ADIF CONTEST_ID: ' + text);
   CheckTrue(Pos('<STATE:2>HI', text) > 0, 'a district is in Hawaii: ' + text);
   CheckTrue(Pos('CLAIMEDQSO', text) = 0, 'an in-band QSO carries no X-QSO marker: ' + text);
end;

(* A WSJT-X OR ADIF QSO: the GRIDSQUARE is a Digital QSO's received grid;
   NF is NL. Through the class's own import seam. *)
procedure TContestHawaiiQPTests.Test_ADIFImport;
var
   temps: TADIFRecordTemps;
   exch: ContestExchange;
   session: TADIFImportSession;
begin
   BeginTest('Test_HawaiiADIFImport');
   temps := Default(TADIFRecordTemps);
   temps.GridSquare := 'bl11hh';
   exch := Default(ContestExchange);
   exch.ceContest := PartyHandle;
   exch.Mode := Digital;
   exch.ExtMode := eFT8;
   ContestIdentity(PartyHandle).ApplyADIFImport(temps, NeutralADIFImportSession, exch);
   CheckEquals('BL11', string(exch.QTHString), 'a Digital QSO''s GRIDSQUARE, four characters');
   CheckEquals('', string(exch.DomesticQTH), 'no domestic key');

   exch := Default(ContestExchange);
   exch.ceContest := PartyHandle;
   exch.Mode := CW;
   ContestIdentity(PartyHandle).ApplyADIFImport(temps, NeutralADIFImportSession, exch);
   CheckEquals('', string(exch.QTHString), 'a CW QSO''s GRIDSQUARE is no received QTH');

   (* A RECORD WHOSE QTH TAG SAYS NF (the importer captures the tag into
      QTHString before the contest interprets it). A domestic-multiplier
      session with no lookup keeps an explicit tag as written; the class
      then reads NF as NL. *)
   temps := Default(TADIFRecordTemps);
   temps.SRX_String := '599 NF';
   exch := Default(ContestExchange);
   exch.ceContest := PartyHandle;
   exch.Mode := CW;
   exch.RSTReceived := 599;
   exch.QTHString := 'NF';
   session := NeutralADIFImportSession;
   session.DoingDomesticMults := True;
   ContestIdentity(PartyHandle).ApplyADIFImport(temps, session, exch);
   CheckEquals('NL', string(exch.QTHString), 'an imported NF reads NL');
end;

procedure TContestHawaiiQPTests.Test_OffBandAndOffModeExports;
var
   rx: ContestExchange;
   text: string;
   line: string;
begin
   BeginTest('Test_HawaiiOffBandAndOffModeExports');
   (* OFF-BAND AND OFF-MODE, THROUGH THE EXPORTERS: X-QSO: and
      APP_TR4W_CLAIMEDQSO 0. *)
   (* EACH RECORD IS STAMPED AS IT IS LOGGED (log schema 10): the exporters
      read the stored answer and work no rule out. *)
   rx := HIQSO('KH6AA', 'HON', Band30, CW, eCW);
   CheckTrue(LoggedQSOIsXQSO(rx), '30 m is an automatic X-QSO');
   StampOffContest(rx);
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0, 'an off-band QSO is not claimed: ' + text);
   line := string(BuildSingleQsoCabrilloLine(rx));
   CheckTrue(Pos('X-QSO: ', line) = 1, 'an off-band QSO goes as an X-QSO: line: ' + line);

   rx := HIQSO('KH6AA', 'HON', Band20, FM, eFM);
   CheckTrue(LoggedQSOIsXQSO(rx), 'FM is an automatic X-QSO');
   StampOffContest(rx);
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0, 'an FM QSO is not claimed: ' + text);
   line := string(BuildSingleQsoCabrilloLine(rx));
   CheckTrue(Pos('X-QSO: ', line) = 1, 'and goes as an X-QSO: line: ' + line);

   (* EVERY DIGITAL MODE IS A CONTEST MODE: FT8 on 20 m is a QSO, DG. *)
   rx := HIQSO('KH6AA', 'HON', Band20, Digital, eFT8);
   CheckFalse(LoggedQSOIsXQSO(rx), 'FT8 is a digital mode: no X-QSO');
   StampOffContest(rx);
   line := string(BuildSingleQsoCabrilloLine(rx));
   CheckTrue(Pos('QSO: ', line) = 1, 'a QSO: line: ' + line);
   CheckTrue(Pos(' DG ', line) > 0, 'its mode column is DG: ' + line);
end;

(* THE NEW CONTEST DIALOG SAYS DISTRICT (NY4I), and our own QTH is never a
   grid: outside Hawaii the dialog takes a state, a province or DX only. *)
procedure TContestHawaiiQPTests.Test_NewContestSaysDistrict;
var
   area: TNewContestHostArea;
begin
   BeginTest('Test_HawaiiNewContestSaysDistrict');
   CheckTrue(ContestIdentity(PartyHandle).DescribeNewContestHostArea(area), 'the "I am in HI" box');
   CheckEquals(SNewContestHostAreaDistrictLabel, area.PlaceLabel, 'the row reads MY DISTRICT');
   CheckEquals(SNewContestHostAreaInsideDistrictNotice, area.InsideNotice, 'choose your district');
   CheckEquals('hawaiiqp_cty', area.PlacesFile, 'the districts are the list');
   CheckTrue(HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'BL11') <> '',
      'a grid is refused as our own QTH outside Hawaii');
   CheckTrue(HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'ZZ00') <> '',
      'the fake grid too');
   CheckEquals('', HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'CA'),
      'a state is accepted');
end;

procedure TContestHawaiiQPTests.RunAllTests;
begin
   Test_Identity;
   Test_Schedule;
   Test_BandsModesAndPoints;
   Test_MultiplierAnswersByEntrant;
   Test_DistrictFileAndInStateFile;
   Test_HostAreaGridAndBlank;
   Test_Score;
   Test_RealEngineOutOfState;
   Test_RealEngineInState;
   Test_ExportColumns;
   Test_ADIFImport;
   Test_OffBandAndOffModeExports;
   Test_NewContestSaysDistrict;
end;

end.
