(* THE ATLANTIC CANADA QSO PARTY -- issue #116 (2026-11-18). The sponsor's
   rules (docs/ContestRules/QSOParties/AtlanticCanada/ACQP-Rules-B-V26.0.1.pdf,
   V 26.0.1, 2026-05-01, and acqp-rules.md, its text). Each test names the
   rule it holds; the class header says where each landed.

   THE CODES ARE NOT THE SPONSOR'S TABLE: the PDF gives only the counts (NS 18,
   NB 15, PE 3, NL 11) and the shape ("5-letter province + county/division
   code"). The codes are DXLog's (AC-QSO-PARTY-Counties.txt says so), so
   Test_CountyFile holds the .dom to the SPONSOR'S counts and shape and to the
   docs list, and Test_ADIFStateIsTheCodesProvince holds each county's ADIF
   STATE to the province its code names -- not to a sponsor table, which we
   do not have.

   THE SECOND MULTI-PROVINCE PARTY (HostState 'NB NS PE NL'), and the first
   whose in-region province multiplier is per band AND mode, kept on the
   prefix sheet: Test_RealEngineInRegion is the discriminating test. *)
unit uTestContestAtlanticCanadaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestAtlanticCanadaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_CountyFile;
      procedure Test_InRegionFile;
      procedure Test_BandsModesAndPoints;
      procedure Test_MultiplierAnswers;
      procedure Test_ProvinceKey;
      procedure Test_ScoreAndBonus;
      procedure Test_ADIFStateIsTheCodesProvince;
      procedure Test_RealEngineOutOfRegion;
      procedure Test_RealEngineInRegion;
      procedure Test_TheCountyLineDrainRefreshesTheKey;
      procedure Test_ExportColumns;
      procedure Test_NewContestSaysCounty;
   end;

implementation

uses
   SysUtils, Classes, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestAtlanticCanadaQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uTestShippedDom, uMults,
   LogStuff, uPendingCounties, uADIF, uContestSchedule, uAppPaths,
   uDomFileKeys, uCabrillo, uNewContestHostArea, uAppStrings,
   (* TryLegacyContestOf -- a by-id contest has no legacy member. *)
   uTestRegisteredContests,
   (* SourceText -- the county-line drain is read, not driven. *)
   uTestAutomaticXQSO;

const
   (* THE RULES' BONUS STATIONS, as the PDF spells them (page 3). *)
   BONUS_CALLS: array[0..9] of string = (
      'VE1RAC', 'VE9RAC', 'VY2RAC', 'VO1RAC', 'VO2RAC',
      'VE0CNM', 'VE0MMA', 'VO1ACQ', 'VE9ACQ', 'VA1ACQ');

function PartyHandle: TContestHandle;
begin
   if not FindContestById(AC_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('AC-QSO-PARTY is not registered');
      end;
end;

(* A station whose received code is aQTH, resolved to aMult (the in-region
   province, or the county itself out of region), on aBand in aMode. *)
function ACQSO(const aCall, aQTH, aMult: string; aBand: BandType; aMode: ModeType;
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
   Result.DomMultQTH := ShortString(aMult);
   Result.QTH.CountryID := 'VE';
end;

function StationAt(aInRegion: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInRegion;
   if aInRegion then
      begin
      Result.MyState := 'NSHRM';
      Result.MyCountry := 'VE';
      end
   else
      begin
      Result.MyState := 'PA';
      Result.MyCountry := 'K';
      end;
end;

function DocsCountyFile: string;
begin
   Result := ShippedDomDir + '..' + PathDelim + '..' + PathDelim + '..' + PathDelim +
             'docs' + PathDelim + 'ContestRules' + PathDelim + 'QSOParties' + PathDelim +
             'AtlanticCanada' + PathDelim + 'AC-QSO-PARTY-Counties.txt';
end;

(* THE DOCS LIST'S CODES, IN ITS ORDER -- the lines that start with a
   five-letter code. *)
procedure ReadDocsCodes(aCodes: TStrings);
var
   lines: TStringList;
   i: integer;
   line: string;
   code: string;
   j: integer;
   isCode: boolean;
begin
   aCodes.Clear;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(DocsCountyFile));
      for i := 0 to lines.Count - 1 do
         begin
         line := string(lines[i]);
         if (Length(line) < 7) or (line[6] <> ' ') then
            begin
            Continue;
            end;
         code := Copy(line, 1, 5);
         isCode := True;
         for j := 1 to 5 do
            begin
            if (code[j] < 'A') or (code[j] > 'Z') then
               begin
               isCode := False;
               end;
            end;
         if isCode then
            begin
            aCodes.Add(AnsiString(code));
            end;
         end;
   finally
      lines.Free;
   end;
end;

procedure TContestAtlanticCanadaQPTests.Test_Identity;
var
   party: TContestBase;
   legacy: integer;
   member: ContestType;
   s: TContestSchedule;
   err: string;
begin
   BeginTest('Test_ACQPIdentity');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestAtlanticCanadaQP, 'the registered class');
   CheckTrue(TContestAtlanticCanadaQP.ClassParent = TContestStateQSOPartyBase,
             'directly on the state-party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckFalse(TryLegacyContestOf(party, member), 'no legacy member');
   CheckEquals('AC-QSO-PARTY', party.CabrilloName, 'the rules'' Cabrillo example');
   CheckEquals('AC-QSO-PARTY', party.ADIFContestId, 'no ADIF enumeration value: the Cabrillo name');
   CheckEquals('Atlantic Canada QSO Party', party.DisplayName, 'display');
   CheckEquals('Atlantic Canada QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('NB NS PE NL', party.HostState, 'the four Atlantic provinces');
   CheckEquals('NB/NS/PE/NL', party.QSOPartyArea, 'the New Contest box''s words');
   CheckEquals('', party.SubmissionEmail, '"We will only accept logs uploaded via" the site');
   CheckEquals(0, party.WA7BNMId, 'no WA7BNM id recorded');
   CheckEquals('acqp_cty', party.DomesticFileName, 'the county file');
   CheckEquals('acqp', party.InStateDomesticFileName, 'the in-region file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand],
             '"once per band/mode"; multipliers per band (the province''s mode is its key)');
   CheckTrue((party as TContestStateQSOPartyBase).CountyLineCountiesMax = CountyLineCountiesUnlimited,
             '"a separate QSO ... for each county/division", no maximum');
   CheckTrue(party.DupeKeyIncludesReceivedQTH,
             '"Mobiles/portables that change counties/divisions are considered new stations"');
   CheckTrue(party.StripsRoverCountyFromCall and party.SplitsRoverCallOnExport,
             'the party base''s rover rules');
   CheckTrue(party.IsUSQSOParty, 'set-up runs the party head for it');
   CheckFalse(party.WritesADIFCounty, 'no ADIF CNTY: ADIF has no Canadian counties');

   (* "First Sunday of June each year", "1400Z Sunday until 0100Z Monday". *)
   CheckEquals('1st Sunday of June at 14:00 UTC for 11h', party.Schedule, 'the schedule');
   CheckTrue(TryParseContestSchedule(party.Schedule, s, err), 'it parses (' + err + ')');
end;

(* THE COUNTY FILE: the SPONSOR'S counts ("NS- 18", "NB- 15", "PE-3", "NL-11
   Divisions", 47) and shape (a five-letter province + county code, each
   mapped to the province its first two letters name), and exactly the docs
   list's codes in its order. *)
procedure TContestAtlanticCanadaQPTests.Test_CountyFile;
var
   lines, codes: TStringList;
   i: integer;
   key: string;
   seen: integer;
   nl, pe, nb, ns: integer;
   province: string;
   expected: string;
begin
   BeginTest('Test_ACQPCountyFile');
   lines := TStringList.Create;
   codes := TStringList.Create;
   try
      ReadDocsCodes(codes);
      CheckEquals(47, codes.Count, 'the docs list: 47 codes');
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'acqp_cty.dom'));
      seen := 0;
      nl := 0;
      pe := 0;
      nb := 0;
      ns := 0;
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Pos('INCLUDE', UpperCase(TrimLeft(string(lines[i])))) <> 1,
                   'the county file includes nothing');
         key := DomFileLineKey(string(lines[i]));
         if key = '' then
            begin
            CheckTrue(Pos('=', string(lines[i])) = 0, 'no "=" outside an entry: ' + string(lines[i]));
            Continue;
            end;
         CheckEquals(5, Length(key), 'a five-letter code: ' + key);
         province := Copy(key, 1, 2);
         if province = 'NL' then
            begin
            Inc(nl);
            end
         else if province = 'PE' then
            begin
            Inc(pe);
            end
         else if province = 'NB' then
            begin
            Inc(nb);
            end
         else if province = 'NS' then
            begin
            Inc(ns);
            end
         else
            begin
            CheckTrue(False, 'a code of no Atlantic province: ' + key);
            end;
         (* 'NSANP > Ns = NSANP,^Annapolis County' *)
         expected := key + ' > ' + province[1] + LowerCase(province[2]) + ' = ' + key + ',^';
         CheckEquals(expected, Copy(string(lines[i]), 1, Length(expected)), 'its own province: ' + key);
         if seen < codes.Count then
            begin
            CheckEquals(string(codes[seen]), key, 'the docs list''s order');
            end;
         Inc(seen);
         end;
      CheckEquals(47, seen, '"a maximum of 47 multipliers (Counties/Divisions)"');
      CheckEquals(11, nl, '"Newfoundland (NL-11 Divisions)"');
      CheckEquals(3, pe, '"Prince Edward Island (PE-3)"');
      CheckEquals(15, nb, '"New Brunswick (NB- 15)"');
      CheckEquals(18, ns, '"Nova Scotia (NS- 18)"');
   finally
      codes.Free;
      lines.Free;
   end;
end;

(* THE IN-REGION LIST: the counties first, each counting as its province; DC
   as Maryland; the 50 states; the other 9 provinces and territories; NB, NS,
   PE and NL as no received exchange. *)
procedure TContestAtlanticCanadaQPTests.Test_InRegionFile;
var
   lines: TStringList;
   i: integer;
begin
   BeginTest('Test_ACQPInRegionFile');
   CheckEquals('NS', InStateMultiplierOf(PartyHandle, 'NSHRM'), 'a Nova Scotia county counts as NS');
   CheckEquals('NB', InStateMultiplierOf(PartyHandle, 'NBYOR'), 'a New Brunswick one as NB');
   CheckEquals('PE', InStateMultiplierOf(PartyHandle, 'PEQNS'), 'a PEI one as PE');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NLASJ'), 'a Newfoundland division as NL');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), '"count DC as MD"');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('CT', InStateMultiplierOf(PartyHandle, 'CT'), 'a state');
   CheckEquals('AK', InStateMultiplierOf(PartyHandle, 'AK'), 'Alaska is a state');
   CheckEquals('HI', InStateMultiplierOf(PartyHandle, 'HI'), 'Hawaii is a state');
   CheckEquals('ON', InStateMultiplierOf(PartyHandle, 'ON'), 'a province');
   CheckEquals('QC', InStateMultiplierOf(PartyHandle, 'QC'), 'Quebec');
   CheckEquals('AB', InStateMultiplierOf(PartyHandle, 'AB'), 'Alberta');
   CheckEquals('YT', InStateMultiplierOf(PartyHandle, 'YT'), 'a territory');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'NS'), 'an Atlantic station sends its code, not NS');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'NB'), 'nor NB');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'PE'), 'nor PE');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'NL'), 'nor NL');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'VE1'), 'no call-area alias');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), '"DX stations do not count as multipliers"');

   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'acqp.dom'));
      CheckTrue(lines.IndexOf('INCLUDE FILE acqp_cty.dom') >= 0, 'includes the counties');
      CheckTrue(lines.IndexOf('INCLUDE FILE acqp_cty.dom') < lines.IndexOf('Dc > Md = DC'),
                'counties first');
      CheckTrue(lines.IndexOf('Dc > Md = DC') < lines.IndexOf('INCLUDE FILE s50.dom'),
                'DC folded before the states');
      CheckTrue(lines.IndexOf('INCLUDE FILE p13.dom') < 0, 'no P13: its call-area aliases');
      CheckTrue(lines.IndexOf('INCLUDE FILE p12.dom') < 0, 'no P12');
      CheckTrue(lines.IndexOf('INCLUDE FILE dc.dom') < 0, 'DC is no multiplier of its own');
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE', string(lines[i])) = 1 then
            begin
            Break;
            end;
         CheckTrue(Pos('=', string(lines[i])) = 0, 'no "=" in the header: ' + string(lines[i]));
         end;
   finally
      lines.Free;
   end;
end;

procedure TContestAtlanticCanadaQPTests.Test_BandsModesAndPoints;
var
   party: TContestBase;
   inRegion: boolean;
   band: BandType;
   mode: ModeType;
   qso: ContestExchange;
   expected: integer;
begin
   BeginTest('Test_ACQPBandsModesAndPoints');
   for inRegion := False to True do
      begin
      party := Make(PartyHandle, StationAt(inRegion));
      try
         (* "Bands: 80-40-20-15-10m only." *)
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in [Band80, Band40, Band20, Band15, Band10]),
                      'the rules'' five bands');
            end;
         (* "SSB, CW, or Mixed modes. No digital modes."; "one point per QSO
            regardless of mode"; FM is phone. *)
         for mode := Low(ModeType) to High(ModeType) do
            begin
            expected := 0;
            if mode in [CW, Phone, FM] then
               begin
               expected := 1;
               end;
            qso := ACQSO('VE1AAA', 'NSHRM', 'Ns', Band20, mode, eNoMode);
            party.ScoreQSO(qso);
            CheckEquals(expected, Integer(qso.QSOPoints), 'CW, phone and FM 1; nothing else');
            CheckTrue(party.UsesMode(mode, eNoMode) = (mode in [CW, Phone, FM]),
                      'CW and phone only');
            end;
         CheckFalse(party.UsesMode(Digital, eRTTY), 'no RTTY');
         CheckFalse(party.UsesMode(Digital, eFT8), 'no FT8');
         qso := ACQSO('VE1AAA', 'NSHRM', 'Ns', Band160, CW, eCW);
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), '160 m scores nothing');
         CheckEquals('CW', party.CabrilloModeString(CW, eCW), 'CW');
         CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), 'PH');
         CheckEquals('PH', party.CabrilloModeString(FM, eFM), 'FM is written PH');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestAtlanticCanadaQPTests.Test_MultiplierAnswers;
var
   party: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_ACQPMultiplierAnswers');
   (* OUT OF REGION: counties, nothing else. *)
   party := Make(PartyHandle, StationAt(False));
   try
      CheckFalse(party.HasDXMultiplier, 'no DX multiplier');
      CheckFalse(party.HasZoneMultiplier, 'no zones');
      CheckFalse(party.HasPrefixMultiplier, 'out of region: no province key');
      CheckTrue(party.HasDomesticMultiplier, 'counties and divisions');
      CheckTrue(party.CountsAsMultiplier(ACQSO('VE1AAA', 'NSHRM', 'NSHRM', Band20, CW, eCW), rmDomestic),
                'a county counts');
   finally
      party.Free;
   end;

   (* IN REGION: states and provinces on the domestic sheet, the Atlantic
      province on the prefix sheet and NOT the domestic one. *)
   party := Make(PartyHandle, StationAt(True));
   try
      CheckFalse(party.HasDXMultiplier, '"DX stations do not count as multipliers"');
      CheckFalse(party.HasZoneMultiplier, 'no zones');
      CheckTrue(party.HasPrefixMultiplier, 'in region: the province key');
      CheckTrue(party.HasDomesticMultiplier, 'states and provinces');
      CheckFalse(party.CountsAsMultiplier(ACQSO('VE1AAA', 'NSHRM', 'Ns', Band20, CW, eCW), rmDomestic),
                 'an Atlantic province is not counted on the domestic sheet too');
      CheckTrue(party.CountsAsMultiplier(ACQSO('VE1AAA', 'NSHRM', 'Ns', Band20, CW, eCW), rmPrefix),
                'it is the prefix sheet''s');
      CheckTrue(party.CountsAsMultiplier(ACQSO('VE3AA', 'ON', 'On', Band20, CW, eCW), rmDomestic),
                'Ontario is a domestic multiplier');
   finally
      party.Free;
   end;

   (* THE HOST-AREA RULE -- judged by the SHIPPED county file. *)
   LoadCountyTable('acqp_cty.dom', True);
   station := NoStation;
   station.IsDomesticQTH := @CountyFileKnowsQTH;
   party := Make(PartyHandle, station);
   try
      CheckFalse(party.CreditsWorkedStation(ACQSO('W1AW', 'CT', 'CT', Band20, CW, eCW)),
                 'out of region a QSO with CT is not credited');
      CheckFalse(party.CreditsWorkedStation(ACQSO('VE3AA', 'ON', 'ON', Band20, CW, eCW)),
                 'nor one with ON');
      CheckTrue(party.CreditsWorkedStation(ACQSO('VE1AAA', 'NSHRM', 'NSHRM', Band20, CW, eCW)),
                'a Nova Scotia county is');
      CheckTrue(party.CreditsWorkedStation(ACQSO('VO1AAA', 'NLASJ', 'NLASJ', Band20, CW, eCW)),
                'a Newfoundland division');
   finally
      party.Free;
      FreeCountyTable;
   end;
end;

(* THE PROVINCE KEY: province + mode, FM as phone; nothing for a QSO that is
   no Atlantic county; False out of region (the prefix walk's invariant). *)
procedure TContestAtlanticCanadaQPTests.Test_ProvinceKey;
var
   party: TContestBase;
   key: PrefixMultiplierString;
begin
   BeginTest('Test_ACQPProvinceKey');
   party := Make(PartyHandle, StationAt(True));
   try
      CheckTrue(party.PrefixMultiplierKey(ACQSO('VE1AAA', 'NSHRM', 'Ns', Band20, CW, eCW), key), 'in region');
      CheckEquals('NSCW', string(key), 'Nova Scotia on CW');
      CheckTrue(party.PrefixMultiplierKey(ACQSO('VE9AAA', 'NBYOR', 'Nb', Band20, Phone, eUSB), key), 'phone');
      CheckEquals('NBPH', string(key), 'New Brunswick on phone');
      CheckTrue(party.PrefixMultiplierKey(ACQSO('VY2AAA', 'PEQNS', 'Pe', Band20, FM, eFM), key), 'FM');
      CheckEquals('PEPH', string(key), 'FM is phone');
      CheckTrue(party.PrefixMultiplierKey(ACQSO('VO2AAA', 'NLLGB', 'Nl', Band20, CW, eCW), key), 'NL');
      CheckEquals('NLCW', string(key), 'a Labrador division is NL');
      CheckTrue(party.PrefixMultiplierKey(ACQSO('VE3AA', 'ON', 'On', Band20, CW, eCW), key), 'Ontario');
      CheckEquals('', string(key), 'Ontario earns no province key');
      CheckTrue(party.PrefixMultiplierKey(ACQSO('DL1AAA', 'DX', '', Band20, CW, eCW), key), 'DX');
      CheckEquals('', string(key), 'DX earns none');
   finally
      party.Free;
   end;

   party := Make(PartyHandle, StationAt(False));
   try
      CheckFalse(party.PrefixMultiplierKey(ACQSO('VE1AAA', 'NSHRM', 'Ns', Band20, CW, eCW), key),
                 'out of region: no key, as there is no prefix multiplier');
   finally
      party.Free;
   end;
end;

(* "Score = (QSO x mults) + Bonus", with the bonus stations "5 Bonus points
   once per band and mode". The bonus is ADDED, never multiplied (DXLog adds
   it to the points before the multiplier); VE0CNM is the PDF's spelling. *)
procedure TContestAtlanticCanadaQPTests.Test_ScoreAndBonus;
var
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   stations: TBonusStationList;
   i: integer;
   qso: ContestExchange;
begin
   BeginTest('Test_ACQPScoreAndBonus');
   party := Make(PartyHandle, StationAt(True));
   view := TLoggedQSOList.Create;
   try
      stations := party.BonusStations;
      CheckEquals(10, Length(stations), 'the rules'' ten bonus calls');
      for i := 0 to High(stations) do
         begin
         CheckEquals(BONUS_CALLS[i], stations[i].Call, 'bonus call ' + IntToStr(i));
         CheckEquals(5, Integer(stations[i].Points), '"5 Bonus points"');
         CheckTrue(stations[i].Scope = bsOncePerBandAndMode, '"once per band and mode"');
         end;

      view.Add(ACQSO('VE1RAC', 'NSHRM', 'Ns', Band20, CW, eCW));      (* 5 *)
      qso := ACQSO('VE1RAC', 'NSHRM', 'Ns', Band20, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);                                                  (* a dupe: 0 *)
      view.Add(ACQSO('VE1RAC', 'NSHRM', 'Ns', Band20, Phone, eUSB));  (* the other mode: 5 *)
      view.Add(ACQSO('VE1RAC', 'NSHRM', 'Ns', Band40, CW, eCW));      (* another band: 5 *)
      view.Add(ACQSO('VE0CNM', 'NSHRM', 'Ns', Band15, FM, eFM));      (* FM is phone: 5 *)
      view.Add(ACQSO('VE0CMN', 'NSHRM', 'Ns', Band15, CW, eCW));      (* DXLog's spelling: 0 *)
      view.Add(ACQSO('VE1RAC', 'NSHRM', 'Ns', Band160, CW, eCW));     (* off-band X-QSO: 0 *)

      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 100;
      totals.Mults[AllBands, Both, rmDomestic] := 10;
      totals.Mults[AllBands, Both, rmPrefix] := 3;
      CheckEquals(1300, party.CombineScore(totals), 'points x (domestic + province) multipliers');
      CheckEquals(20, party.BonusPoints(totals, view), 'four bonus band-modes x 5');
      CheckEquals(1320, party.FinalScore(totals, view), '(QSO x mults) + Bonus');
   finally
      view.Free;
      party.Free;
   end;
end;

(* EVERY COUNTY'S ADIF STATE IS THE PROVINCE ITS CODE NAMES -- the
   multi-province base change: asked of the identity, as GetADIFStateForQSO
   asks, with the export reading the tree's dom folder. *)
procedure TContestAtlanticCanadaQPTests.Test_ADIFStateIsTheCodesProvince;
var
   codes: TStringList;
   i: integer;
   savedDomDir: string;
   rx: ContestExchange;
   text: string;
begin
   BeginTest('Test_ACQPADIFStateIsTheCodesProvince');
   codes := TStringList.Create;
   savedDomDir := ShippedDomDirOverride;
   try
      ShippedDomDirOverride := ShippedDomDir;
      ReadDocsCodes(codes);
      CheckEquals(47, codes.Count, 'the list');
      for i := 0 to codes.Count - 1 do
         begin
         CheckEquals(Copy(string(codes[i]), 1, 2),
                     GetADIFStateForQSO(ACQSO('VE1AAA', string(codes[i]), string(codes[i]), Band20, CW, eCW)),
                     'county ' + string(codes[i]));
         end;
      CheckEquals('', GetADIFStateForQSO(ACQSO('VE1AAA', 'NSXYZ', 'NSXYZ', Band20, CW, eCW)),
                  'a code the file does not hold: no province invented');

      (* Anyone else: a state or province as itself, DX nothing. *)
      rx := ACQSO('W1AW', 'Ct', 'Ct', Band20, CW, eCW);
      rx.QTH.CountryID := 'K';
      CheckEquals('CT', GetADIFStateForQSO(rx), 'a Connecticut station');
      rx := ACQSO('VE3AA', 'On', 'On', Band20, CW, eCW);
      CheckEquals('ON', GetADIFStateForQSO(rx), 'an Ontario station');
      rx := ACQSO('DL1AAA', '', '', Band20, CW, eCW);
      rx.QTHString := 'DX';
      rx.QTH.CountryID := 'DL';
      CheckEquals('', GetADIFStateForQSO(rx), 'DX: no STATE');

      (* THE RECORD ITSELF. *)
      rx := ACQSO('VO1AA', 'NLASJ', 'NLASJ', Band20, CW, eCW);
      text := EmitADIFRecord(rx);
      CheckTrue(Pos('<CONTEST_ID:12>AC-QSO-PARTY', text) > 0, 'CONTEST_ID: ' + text);
      CheckTrue(Pos('<STATE:2>NL', text) > 0, 'Avalon is in Newfoundland and Labrador: ' + text);
      CheckTrue(Pos('<CNTY', text) = 0, 'and the body writes no CNTY: ' + text);
   finally
      ShippedDomDirOverride := savedDomDir;
      codes.Free;
   end;
end;

procedure TContestAtlanticCanadaQPTests.Test_RealEngineOutOfRegion;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_ACQPRealEngineOutOfRegion');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(47, mo.DomList.Count, 'out of region: the 47 counties and divisions');
      CheckTrue(Settings.Mult.ByBand, 'multipliers per band');
      CheckFalse(Settings.Mult.ByMode, 'not per mode');

      engine.Enter('VE1AAA', '599 NSHRM', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a county accepted and credited');
      CheckFalse(rx.PrefixMult, 'and no province key out of region');
      CheckEquals('', string(rx.Prefix), 'no key at all');
      CheckEquals(1, Integer(rx.QSOPoints), 'CW 1');
      CheckEquals('599 NSHRM  ', PartyReceivedCabrilloColumn(PartyHandle, rx),
                  'the received column, through the writer');
      dupe := engine.Enter('VE1AAA', '59 NSHRM', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, '"once per band/mode": phone is the other mode');
      CheckFalse(rx.DomesticMult, 'NSHRM again on 20 m: one multiplier per band, not per mode');
      dupe := engine.Enter('VE1AAA', '599 NSHRM', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'once per band and mode');
      dupe := engine.Enter('VE1AAA', '599 NSHRM', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'another band');
      CheckTrue(rx.DomesticMult, 'NSHRM per band');
      dupe := engine.Enter('VE1AAA', '599 NSLUN', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'a mobile in a new county is a new station');
      CheckTrue(rx.DomesticMult, 'and Lunenburg a new county');
      engine.Enter('VO1ZZ', '599 NLASJ', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a Newfoundland division');
      engine.Enter('VY2ZZ', '59 PEPRN', Band10, FM, eFM, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a PEI county on 10 m FM');
      CheckEquals(1, Integer(rx.QSOPoints), 'FM is phone: 1');

      (* A MOBILE SIGNING ITS COUNTY IN THE CALL: the county is its own
         multiplier out of region, as for any other QSO. *)
      engine.Enter('VE1RV/NSDIG', '599 NSDIG', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a mobile signing /NSDIG: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Digby, from the call');
      CheckFalse(rx.PrefixMult, 'and no province key out of region');

      (* Out of region, only Atlantic Canada stations count. *)
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'out of region, CT is refused');
      engine.Enter('VE3AA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'and ON');
      engine.Enter('VE1BAD', '599 NS', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'NS is no county');
      engine.Enter('VE1BAD', '599 NSXYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'nor NSXYZ');

      (* Q98: off-mode and off-band QSOs are LOGGED as X-QSOs. *)
      engine.Enter('VE1RY', '599 NSDIG', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'an RTTY QSO is logged: ' + string(ExchangeErrorMessage));
      CheckTrue(LoggedQSOIsXQSO(rx), '"No digital modes": RTTY is an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      engine.Enter('VE1OFF', '599 NSPIC', Band160, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 160 m QSO is logged');
      CheckTrue(LoggedQSOIsXQSO(rx), '160 m is not a contest band');

      (* COUNTY LINES: a QSO for each county, no maximum. *)
      ClearPendingCounties;
      engine.Enter('VE1LN', '599 NSCMB/NBWES/NSCOL', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a county junction: ' + string(ExchangeErrorMessage));
      CheckEquals(2, PendingCountiesCount, 'each further county its own QSO');
      ClearPendingCounties;
   finally
      engine.Free;
   end;
end;

(* THE DISCRIMINATING TEST: in region, the Atlantic province once per band
   AND MODE, every other multiplier once per band. *)
procedure TContestAtlanticCanadaQPTests.Test_RealEngineInRegion;
var
   engine: TQSOPartyEngine;
   accepted: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_ACQPRealEngineInRegion');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      (* 50 states and 13 provinces and territories -- the four Atlantic
         ones listed, though only the prefix sheet counts them. *)
      CheckEquals(63, mo.DomList.Count, 'in region: 50 states and 13 provinces');
      CheckTrue(Settings.Mult.ByBand and not Settings.Mult.ByMode, 'per band');

      engine.Enter('VE1AAA', '599 NSHRM', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a Nova Scotia station: ' + string(ExchangeErrorMessage));
      CheckEquals('NSCW', string(rx.Prefix), 'its province key');
      CheckTrue(rx.PrefixMult, 'the first Nova Scotia station on 20 m CW: the NS multiplier');
      CheckFalse(rx.DomesticMult, 'and not a domestic multiplier too');
      CheckEquals(1, Integer(rx.QSOPoints), '1 point');
      CheckEquals('599 NSHRM  ', PartyReceivedCabrilloColumn(PartyHandle, rx),
                  'the received column, through the writer');
      engine.Enter('VE1BBB', '59 NSANP', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'another on phone');
      CheckEquals('NSPH', string(rx.Prefix), 'the phone key');
      CheckTrue(rx.PrefixMult, '"each band and mode": NS again on 20 m phone');
      engine.Enter('VE1CCC', '599 NSLUN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a third');
      CheckFalse(rx.PrefixMult, 'NS on 20 m CW already counted');
      engine.Enter('VE1CCC', '599 NSLUN', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.PrefixMult, 'NS again on 40 m CW');
      engine.Enter('VE9AAA', '599 NBYOR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.PrefixMult, 'New Brunswick');
      engine.Enter('VO1AAA', '599 NLASJ', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.PrefixMult, 'Newfoundland and Labrador');
      engine.Enter('VY2AAA', '59 PEQNS', Band20, FM, eFM, accepted, rx);
      CheckTrue(accepted and rx.PrefixMult, 'PEI on FM');
      CheckEquals('PEPH', string(rx.Prefix), 'FM is phone');

      (* A MOBILE SIGNING ITS COUNTY IN THE CALL: in region it earns the
         province, never the county. *)
      engine.Enter('VE1RV/NSDIG', '599 NSDIG', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a mobile signing /NSDIG: ' + string(ExchangeErrorMessage));
      CheckEquals('NSCW', string(rx.Prefix), 'its province key, from the call''s county');
      CheckTrue(rx.PrefixMult, 'NS on 15 m CW');
      CheckFalse(rx.DomesticMult, 'and Digby is no domestic multiplier in region');

      (* EVERY OTHER MULTIPLIER, ONCE PER BAND. *)
      engine.Enter('VE3AA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Ontario on CW');
      CheckFalse(rx.PrefixMult, 'and no province key');
      engine.Enter('VE3AB', '59 ON', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'Ontario on phone');
      CheckFalse(rx.DomesticMult, '"63 mults/band": Ontario not again on 20 m');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a state');
      engine.Enter('W3AA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '"count DC as MD"');
      engine.Enter('W3AB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Maryland');
      CheckFalse(rx.DomesticMult, 'already counted through DC');
      engine.Enter('KL7AA', '599 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Alaska is a state');
      engine.Enter('VE1ZZZ', '599 NS', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'an Atlantic station sends its five-letter code, not NS');

      (* "DX stations do not count as multipliers." *)
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a DX station: ' + string(ExchangeErrorMessage));
      CheckEquals(1, Integer(rx.QSOPoints), '1 point');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckFalse(rx.DXMult, 'no DX multiplier');
      CheckFalse(rx.PrefixMult, 'no province');
      CheckEquals('599 DX     ', PartyReceivedCabrilloColumn(PartyHandle, rx),
                  'the received column is DX');
   finally
      engine.Free;
   end;
end;

(* A COUNTY LINE ACROSS A PROVINCE BORDER (Cumberland NS / Westmorland NB)
   logs one QSO per county; the engine's drain copies the first leg and
   re-resolves its QTH, and must re-ask the prefix key too, or the NB leg
   carries the NS key. The drain cannot be driven headless (it reads the
   live window's record), so this reads it, as uTestAutomaticXQSO does. *)
procedure TContestAtlanticCanadaQPTests.Test_TheCountyLineDrainRefreshesTheKey;
var
   text: string;
   body: string;
   p: integer;
   e: integer;
begin
   BeginTest('Test_ACQPTheCountyLineDrainRefreshesTheKey');
   text := SourceText('MainUnit.pas');
   (* ISSUE 348: the drain is the leg builder of one submission now
      (MainUnit.TEntryLegs.BuildLeg); the county leg is built the same way. *)
   p := Pos('procedure TEntryLegs.BuildLeg(', text);
   CheckTrue(p > 0, 'the leg builder (was DrainPendingMultiQSORefs) is found');
   e := Pos('function LocateCallStrippingRoverCounty(', text);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);
   CheckTrue(Pos('FoundDomesticQTH(TempRX);', body) > 0, 'the drain re-resolves the QTH');
   CheckTrue(Pos('SetPrefix(TempRX);', body) > Pos('FoundDomesticQTH(TempRX);', body),
             'and then asks the prefix key again');
end;

(* THE RULES' OWN EXAMPLE LINES -- "QSO: 3799 CW 2024-06-06 1211 VE1RGO 599
   NSANP VE3YT 599 ON" and "... VE1RGO 59 NSLUN VE7RAC 59 BC"; and, through
   the formatter only, "VE1RPX 59 NLKGS", whose NLKGS is no division. *)
procedure TContestAtlanticCanadaQPTests.Test_ExportColumns;
const
   EXAMPLE_ON = 'QSO: 3799 CW 2024-06-06 1211 VE1RGO 599 NSANP VE3YT 599 ON';
   EXAMPLE_BC = 'QSO: 21305 PH 1999-06-06 1321 VE1RGO 59 NSLUN VE7RAC 59 BC';
   EXAMPLE_NL = 'QSO: 14258 PH 1999-06-06 1215 VE1RGO 59 NSDIG VE1RPX 59 NLKGS';
var
   party, stationed: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   line: string;
   station: TStationContext;

   function Words(const aText: string): string;
   var
      i: integer;
   begin
      Result := '';
      for i := 1 to Length(aText) do
         begin
         if (aText[i] <> ' ') or
            ((Result <> '') and (Result[Length(Result)] <> ' ')) then
            begin
            Result := Result + aText[i];
            end;
         end;
      Result := Trim(Result);
   end;

begin
   BeginTest('Test_ACQPExportColumns');
   party := ContestIdentity(PartyHandle);
   ctx := Default(TCabrilloQSOContext);
   my := Default(TMyStationExchange);

   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';
   my.MyState := 'NSANP';
   rx := ACQSO('VE3YT', 'On', 'On', Band80, CW, eCW);
   rx.QTH.CountryID := 'VE';
   ctx.HisQTH := 'ON';
   line := 'QSO: 3799 ' + party.CabrilloModeString(CW, eCW) + ' 2024-06-06 1211 VE1RGO ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + ' VE3YT ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals(EXAMPLE_ON, Words(line), 'the rules'' first example line');

   ctx.RSTSent := '59';
   ctx.RSTReceived := '59';
   my.MyState := 'NSLUN';
   rx := ACQSO('VE7RAC', 'Bc', 'Bc', Band15, Phone, eUSB);
   ctx.HisQTH := 'BC';
   line := 'QSO: 21305 ' + party.CabrilloModeString(Phone, eUSB) + ' 1999-06-06 1321 VE1RGO ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + ' VE7RAC ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals(EXAMPLE_BC, Words(line), 'the rules'' British Columbia line');

   my.MyState := 'NSDIG';
   rx := ACQSO('VE1RPX', 'NLKGS', 'NLKGS', Band20, Phone, eUSB);
   ctx.HisQTH := 'NLKGS';
   line := 'QSO: 14258 PH 1999-06-06 1215 VE1RGO ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + ' VE1RPX ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals(EXAMPLE_NL, Words(line), 'the rules'' NLKGS line, formatted only');

   (* A DX ENTRANT SENDS DX -- "All other non-VE/W stations send RS(T) and
      "DX."". *)
   ctx.RSTSent := '599';
   my.MyState := '';
   rx := ACQSO('VE1AAA', 'NSHRM', 'NSHRM', Band20, CW, eCW);
   CheckEquals('599 DX     ', party.FormatCabrilloSentExchange(my, rx, ctx), 'Cabrillo: DX');
   CheckEquals('599 DX     ', party.FormatADIFSentExchange(my, rx), 'and in STX_STRING');
   station := StationAt(False);
   station.MyState := '';
   station.MyCountry := 'DL';
   stationed := Make(PartyHandle, station);
   try
      CheckEquals(' 5NN DX', stationed.CQExchangeDefault(station), 'the CQ exchange: DX');
   finally
      stationed.Free;
   end;
   CheckEquals(' 5NN NSHRM', party.CQExchangeDefault(StationAt(True)), 'an Atlantic station its code');
   CheckEquals(' 5NN PA', party.CQExchangeDefault(StationAt(False)), 'anyone else its state');

   (* AN FM QSO GOES AS PH. *)
   rx := ACQSO('VY2AAA', 'PEQNS', 'PEQNS', Band10, FM, eFM);
   line := string(BuildSingleQsoCabrilloLine(rx));
   CheckTrue(Pos(' PH ', line) > 0, 'FM is written PH: ' + line);
end;

(* THE NEW CONTEST DIALOG: its own prompt, the county box, and outside the
   region a state, a province or DX -- never NB, NS, PE or NL. *)
procedure TContestAtlanticCanadaQPTests.Test_NewContestSaysCounty;
var
   area: TNewContestHostArea;
   prompts: TNewContestPrompts;
begin
   BeginTest('Test_ACQPNewContestSaysCounty');
   CheckTrue(ContestIdentity(PartyHandle).DescribeNewContestHostArea(area), 'the "I am in" box');
   CheckEquals('NB/NS/PE/NL', area.Area, 'the area');
   CheckEquals('NB NS PE NL', area.HostStates, 'its four provinces');
   CheckEquals('acqp_cty', area.PlacesFile, 'the counties are the list');
   CheckTrue(HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'NS') <> '',
             'outside the region NS is refused');
   CheckTrue(HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'NL') <> '',
             'and NL');
   CheckEquals('', HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'ON'),
               'a province is accepted');
   CheckEquals('', HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'DX'),
               'and DX');

   prompts := TNewContestPrompts.Create;
   try
      ContestIdentity(PartyHandle).DescribeNewContestPrompts(prompts);
      CheckEquals(1, prompts.ChoiceCount, 'one prompt');
      CheckEquals(SNewContestACQPCountyOrLocation, prompts.Choice(0).Text, 'its own words');
      CheckTrue(prompts.Choice(0).Field = ncfMyState, 'for MY STATE');
   finally
      prompts.Free;
   end;
end;

procedure TContestAtlanticCanadaQPTests.RunAllTests;
begin
   Test_Identity;
   Test_CountyFile;
   Test_InRegionFile;
   Test_BandsModesAndPoints;
   Test_MultiplierAnswers;
   Test_ProvinceKey;
   Test_ScoreAndBonus;
   Test_ADIFStateIsTheCodesProvince;
   Test_RealEngineOutOfRegion;
   Test_RealEngineInRegion;
   Test_TheCountyLineDrainRefreshesTheKey;
   Test_ExportColumns;
   Test_NewContestSaysCounty;
end;

end.
