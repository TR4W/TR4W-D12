(* THE CANADIAN PRAIRIES QSO PARTY -- issue #117 (2026-11-18). The sponsor's
   rules (docs/ContestRules/QSOParties/CanadianPrairies/cpqp-rules.md, "Last
   Update: March 8, 2026") and district table (canadian-prairies-districts.md,
   65 districts -- NY4I's ruling on the issue). Each test names the rule it
   holds; the class header says where each landed.

   THE FIRST PARTY WHOSE HOST IS SEVERAL PROVINCES: HostState 'AB SK MB', and
   the ADIF STATE of a district is its own province, read from cpqp_cty.dom's
   '>' targets by the party base. Test_ADIFStateIsTheDistrictsProvince holds
   that against the SPONSOR'S table, not the .dom it is read from. *)
unit uTestContestCanadianPrairiesQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestCanadianPrairiesQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_DistrictFileIsTheSponsorsTable;
      procedure Test_InAreaFile;
      procedure Test_BandsModesAndPoints;
      procedure Test_MultiplierAnswers;
      procedure Test_Score;
      procedure Test_ADIFStateIsTheDistrictsProvince;
      procedure Test_RealEngineOutOfArea;
      procedure Test_RealEngineInArea;
      procedure Test_ExportColumns;
      procedure Test_NewContestSaysDistrict;
   end;

implementation

uses
   SysUtils, Classes, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestCanadianPrairiesQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uTestShippedDom, uMults,
   LogStuff, uPendingCounties, uADIF, uContestSchedule, uAppPaths,
   uDomFileKeys, uCabrillo, uNewContestHostArea, uAppStrings,
   (* TryLegacyContestOf -- a by-id contest has no legacy member. *)
   uTestRegisteredContests;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(CP_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('CP-QSO-PARTY is not registered');
      end;
end;

(* A station whose received QTH is aQTH (DomesticQTH resolved, as the parse
   leaves it), on aBand in aMode. *)
function CPQSO(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
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
   Result.QTH.CountryID := 'VE';
end;

function StationAt(aInArea: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInArea;
   if aInArea then
      begin
      Result.MyState := 'RGQ';
      Result.MyCountry := 'VE';
      end
   else
      begin
      Result.MyState := 'PA';
      Result.MyCountry := 'K';
      end;
end;

(* THE SPONSOR'S DISTRICT TABLE, as KEY=PROVINCE (AB, SK, MB) and, in
   aNames, KEY=NAME -- read from the saved markdown, its three sections. *)
procedure ReadSponsorTable(aProvinces, aNames: TStrings);
var
   lines: TStringList;
   i: integer;
   line: string;
   province: string;
   cells: string;
   code: string;
   name: string;
   p: integer;
begin
   aProvinces.Clear;
   aNames.Clear;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + '..' + PathDelim + '..' + PathDelim +
         '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
         'QSOParties' + PathDelim + 'CanadianPrairies' + PathDelim +
         'canadian-prairies-districts.md'));
      province := '';
      for i := 0 to lines.Count - 1 do
         begin
         line := string(lines[i]);
         if Pos('## ', line) = 1 then
            begin
            province := '';
            if Pos('## Alberta', line) = 1 then
               begin
               province := 'AB';
               end
            else if Pos('## Saskatchewan', line) = 1 then
               begin
               province := 'SK';
               end
            else if Pos('## Manitoba', line) = 1 then
               begin
               province := 'MB';
               end;
            Continue;
            end;
         (* '| AIR | Airdrie-Cochrane |' -- a three-letter code row. *)
         if (province = '') or (Pos('| ', line) <> 1) then
            begin
            Continue;
            end;
         cells := Copy(line, 3, Length(line));
         p := Pos(' | ', cells);
         if p <> 4 then
            begin
            Continue;
            end;
         code := Copy(cells, 1, 3);
         if (code = 'Abb') or (code[1] < 'A') or (code[1] > 'Z') then
            begin
            Continue;
            end;
         name := Trim(Copy(cells, p + 3, Length(cells)));
         if (name <> '') and (name[Length(name)] = '|') then
            begin
            name := Trim(Copy(name, 1, Length(name) - 1));
            end;
         aProvinces.Add(AnsiString(code + '=' + province));
         aNames.Add(AnsiString(code + '=' + name));
         end;
   finally
      lines.Free;
   end;
end;

procedure TContestCanadianPrairiesQPTests.Test_Identity;
var
   party: TContestBase;
   legacy: integer;
   member: ContestType;
   s: TContestSchedule;
   err: string;
begin
   BeginTest('Test_CPQPIdentity');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestCanadianPrairiesQP, 'the registered class');
   CheckTrue(TContestCanadianPrairiesQP.ClassParent = TContestStateQSOPartyBase,
             'directly on the state-party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckFalse(TryLegacyContestOf(party, member), 'no legacy member');
   CheckEquals('CP-QSO-PARTY', party.CabrilloName, 'DXLog''s Cabrillo name');
   CheckEquals('CP-QSO-PARTY', party.ADIFContestId, 'no ADIF enumeration value: the Cabrillo name');
   CheckEquals('Canadian Prairies QSO Party', party.DisplayName, 'display');
   CheckEquals('Canadian Prairies QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('AB SK MB', party.HostState, 'the three prairie provinces');
   CheckEquals('AB/SK/MB', party.QSOPartyArea, 'the New Contest box''s words');
   CheckEquals('', party.SubmissionEmail, 'note 15: logs are uploaded, not e-mailed');
   CheckEquals(717, party.WA7BNMId, 'issue 117''s research');
   CheckEquals('cpqp_cty', party.DomesticFileName, 'the district file');
   CheckEquals('cpqp', party.InStateDomesticFileName, 'the in-area file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand],
             'note 3 once per band and mode; multipliers "on each of the four bands"');
   CheckTrue((party as TContestStateQSOPartyBase).CountyLineCountiesMax = CountyLineCountiesUnlimited,
             'note 12: a QSO for each FED worked, no maximum');
   CheckTrue(party.DupeKeyIncludesReceivedQTH,
             'note 11: a rover in a new FED is a new station (the base''s received-QTH key)');
   CheckTrue(party.StripsRoverCountyFromCall and party.SplitsRoverCallOnExport,
             'the party base''s rover rules');
   CheckTrue(party.IsUSQSOParty, 'set-up runs the party head for it');
   CheckFalse(party.WritesADIFCounty, 'no ADIF CNTY: ADIF has no Canadian counties');

   (* "Begins 1700 UTC - May 9, 2026 Ends: 0300 UTC - May 10, 2025" -- the
      sponsor states the 2026 date only; NY4I ruled (issue 117, 2026-11-22) it
      recurs on the 2nd Saturday of May, which May 9, 2026 is. *)
   CheckEquals('2nd Saturday of May at 17:00 UTC for 10h', party.Schedule, 'the schedule');
   CheckTrue(TryParseContestSchedule(party.Schedule, s, err), 'it parses (' + err + ')');
end;

(* THE DISTRICT FILE IS THE SPONSOR'S TABLE: 65 lines, each code, its name
   and its province, in the table's order, and nothing else. *)
procedure TContestCanadianPrairiesQPTests.Test_DistrictFileIsTheSponsorsTable;
var
   provinces, names, lines: TStringList;
   i: integer;
   key: string;
   seen: integer;
   abCount, skCount, mbCount: integer;
   expected: string;
begin
   BeginTest('Test_CPQPDistrictFileIsTheSponsorsTable');
   provinces := TStringList.Create;
   names := TStringList.Create;
   lines := TStringList.Create;
   try
      ReadSponsorTable(provinces, names);
      CheckEquals(65, provinces.Count, 'the sponsor''s table: "Total 65" (NY4I: 65, not the prose''s 62)');
      abCount := 0;
      skCount := 0;
      mbCount := 0;
      for i := 0 to provinces.Count - 1 do
         begin
         if provinces.ValueFromIndex[i] = 'AB' then
            begin
            Inc(abCount);
            end
         else if provinces.ValueFromIndex[i] = 'SK' then
            begin
            Inc(skCount);
            end
         else if provinces.ValueFromIndex[i] = 'MB' then
            begin
            Inc(mbCount);
            end;
         end;
      CheckEquals(37, abCount, 'Alberta 37');
      CheckEquals(14, skCount, 'Saskatchewan 14');
      CheckEquals(14, mbCount, 'Manitoba 14');

      lines.LoadFromFile(AnsiString(ShippedDomDir + 'cpqp_cty.dom'));
      seen := 0;
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Pos('INCLUDE', UpperCase(TrimLeft(string(lines[i])))) <> 1,
                   'the district file includes nothing');
         key := DomFileLineKey(string(lines[i]));
         if key = '' then
            begin
            CheckTrue(Pos('=', string(lines[i])) = 0, 'no "=" outside an entry: ' + string(lines[i]));
            Continue;
            end;
         CheckTrue(seen < provinces.Count, 'no more lines than districts');
         if seen >= provinces.Count then
            begin
            Break;
            end;
         (* 'AIR > Ab = AIR,^Airdrie-Cochrane' -- the table's order. *)
         expected := string(provinces.Names[seen]) + ' > ' +
                     Copy(string(provinces.ValueFromIndex[seen]), 1, 1) +
                     LowerCase(Copy(string(provinces.ValueFromIndex[seen]), 2, 1)) +
                     ' = ' + string(provinces.Names[seen]) + ',^' +
                     string(names.ValueFromIndex[seen]);
         CheckEquals(expected, string(lines[i]), 'district ' + string(provinces.Names[seen]));
         Inc(seen);
         end;
      CheckEquals(65, seen, 'the 65 districts');
   finally
      lines.Free;
      names.Free;
      provinces.Free;
   end;
end;

(* THE IN-AREA LIST: districts first, each counting as its province; DC as
   Maryland; the 50 states; the other 10 provinces and territories; AB, SK
   and MB as no received exchange. *)
procedure TContestCanadianPrairiesQPTests.Test_InAreaFile;
var
   lines: TStringList;
   i: integer;
begin
   BeginTest('Test_CPQPInAreaFile');
   CheckEquals('AB', InStateMultiplierOf(PartyHandle, 'AIR'), 'an Alberta district counts as Alberta');
   CheckEquals('SK', InStateMultiplierOf(PartyHandle, 'RGQ'), 'a Saskatchewan district as Saskatchewan');
   CheckEquals('MB', InStateMultiplierOf(PartyHandle, 'WPC'), 'a Manitoba district as Manitoba');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), '"DC counts as MD"');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('CT', InStateMultiplierOf(PartyHandle, 'CT'), 'a state');
   CheckEquals('AK', InStateMultiplierOf(PartyHandle, 'AK'), 'Alaska is a state');
   CheckEquals('HI', InStateMultiplierOf(PartyHandle, 'HI'), 'Hawaii is a state');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'), 'LA is Louisiana (no p13 here)');
   CheckEquals('BC', InStateMultiplierOf(PartyHandle, 'BC'), 'a province');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), 'NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NF'), 'NF is NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'LB'), 'LB is NL');
   CheckEquals('YT', InStateMultiplierOf(PartyHandle, 'YT'), 'a territory');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'AB'), 'a prairie station sends its district, not AB');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'SK'), 'nor SK');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'MB'), 'nor MB');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'VE3'), 'no call-area alias');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX is no multiplier');

   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'cpqp.dom'));
      CheckTrue(lines.IndexOf('INCLUDE FILE cpqp_cty.dom') >= 0, 'includes the districts');
      CheckTrue(lines.IndexOf('INCLUDE FILE cpqp_cty.dom') < lines.IndexOf('Dc > Md = DC'),
                'districts first');
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

procedure TContestCanadianPrairiesQPTests.Test_BandsModesAndPoints;
var
   party: TContestBase;
   inArea: boolean;
   band: BandType;
   mode: ModeType;
   qso: ContestExchange;
   expected: integer;
begin
   BeginTest('Test_CPQPBandsModesAndPoints');
   for inArea := False to True do
      begin
      party := Make(PartyHandle, StationAt(inArea));
      try
         (* "BANDS: 10, 15, 20 and 40 meters". *)
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in [Band40, Band20, Band15, Band10]),
                      'the rules'' four bands');
            end;
         (* "MODES: CW, Phone"; 1 point "for each complete non-duplicate CW or
            SSB contact"; FM is phone. *)
         for mode := Low(ModeType) to High(ModeType) do
            begin
            expected := 0;
            if mode in [CW, Phone, FM] then
               begin
               expected := 1;
               end;
            qso := CPQSO('VE6AAA', 'AIR', Band20, mode, eNoMode);
            party.ScoreQSO(qso);
            CheckEquals(expected, Integer(qso.QSOPoints), 'CW, phone and FM 1; nothing else');
            CheckTrue(party.UsesMode(mode, eNoMode) = (mode in [CW, Phone, FM]),
                      'CW and phone only');
            end;
         CheckFalse(party.UsesMode(Digital, eRTTY), 'no RTTY');
         CheckFalse(party.UsesMode(Digital, eFT8), 'no FT8');
         qso := CPQSO('VE6AAA', 'AIR', Band80, CW, eCW);
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), '80 m scores nothing');
         CheckEquals('CW', party.CabrilloModeString(CW, eCW), 'CW');
         CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), 'PH');
         CheckEquals('PH', party.CabrilloModeString(FM, eFM), 'FM is written PH');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestCanadianPrairiesQPTests.Test_MultiplierAnswers;
var
   party: TContestBase;
   inArea: boolean;
   station: TStationContext;
begin
   BeginTest('Test_CPQPMultiplierAnswers');
   for inArea := False to True do
      begin
      party := Make(PartyHandle, StationAt(inArea));
      try
         (* DX stations "count for QSO credit (1 point each) but not as a
            multiplier". *)
         CheckFalse(party.HasDXMultiplier, 'no DX multiplier');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         CheckFalse(party.HasPrefixMultiplier, 'no prefixes');
         CheckTrue(party.HasDomesticMultiplier, 'districts, or states and provinces');
         CheckTrue(party.CountsAsMultiplier(CPQSO('VE6AAA', 'AIR', Band20, CW, eCW), rmDomestic),
                   'a district counts, own province included');
      finally
         party.Free;
      end;
      end;

   (* THE HOST-AREA RULE ("Contacts between non VE/VA 4, 5 and 6 stations do
      not count") -- judged by the SHIPPED district file. *)
   LoadCountyTable('cpqp_cty.dom', True);
   station := NoStation;
   station.IsDomesticQTH := @CountyFileKnowsQTH;
   party := Make(PartyHandle, station);
   try
      CheckFalse(party.CreditsWorkedStation(CPQSO('W1AW', 'CT', Band20, CW, eCW)),
                 'outside the prairies a QSO with CT is not credited');
      CheckFalse(party.CreditsWorkedStation(CPQSO('VE3AA', 'ON', Band20, CW, eCW)),
                 'nor one with ON');
      CheckTrue(party.CreditsWorkedStation(CPQSO('VE6AAA', 'AIR', Band20, CW, eCW)),
                'an Alberta district is');
      CheckTrue(party.CreditsWorkedStation(CPQSO('VE5AAA', 'RGW', Band20, CW, eCW)),
                'a Saskatchewan one');
      CheckTrue(party.CreditsWorkedStation(CPQSO('VE4AAA', 'WPC', Band20, CW, eCW)),
                'a Manitoba one');
   finally
      party.Free;
      FreeCountyTable;
   end;
end;

(* "Final Score = QSO Points x # Multipliers"; the rules' example: 50 CW and
   100 SSB QSOs with 24 multipliers is 3,600. No bonus. *)
procedure TContestCanadianPrairiesQPTests.Test_Score;
var
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;
begin
   BeginTest('Test_CPQPScore');
   party := Make(PartyHandle, StationAt(True));
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 150;
      totals.Mults[AllBands, Both, rmDomestic] := 24;
      CheckEquals(3600, party.CombineScore(totals), 'the rules'' example: (50+100) * 24');
      view.Add(CPQSO('VE6AAA', 'AIR', Band20, CW, eCW));
      CheckEquals(0, party.BonusPoints(totals, view), 'no bonus');
      CheckEquals(3600, party.FinalScore(totals, view), 'the final score');
   finally
      view.Free;
      party.Free;
   end;
end;

(* EVERY DISTRICT'S ADIF STATE IS ITS PROVINCE IN THE SPONSOR'S TABLE -- the
   multi-province base change (issue 117): asked of the identity, as
   GetADIFStateForQSO asks, with the export reading the tree's dom folder. *)
procedure TContestCanadianPrairiesQPTests.Test_ADIFStateIsTheDistrictsProvince;
var
   provinces, names: TStringList;
   i: integer;
   savedDomDir: string;
   rx: ContestExchange;
   text: string;
begin
   BeginTest('Test_CPQPADIFStateIsTheDistrictsProvince');
   provinces := TStringList.Create;
   names := TStringList.Create;
   savedDomDir := ShippedDomDirOverride;
   try
      ShippedDomDirOverride := ShippedDomDir;
      ReadSponsorTable(provinces, names);
      CheckEquals(65, provinces.Count, 'the table');
      for i := 0 to provinces.Count - 1 do
         begin
         CheckEquals(string(provinces.ValueFromIndex[i]),
                     GetADIFStateForQSO(CPQSO('VE6AAA', string(provinces.Names[i]), Band20, CW, eCW)),
                     'district ' + string(provinces.Names[i]));
         end;
      CheckEquals('', GetADIFStateForQSO(CPQSO('VE6AAA', 'XYZ', Band20, CW, eCW)),
                  'a district the file does not hold: no province invented');

      (* Anyone else: a state or province as itself, DX nothing. *)
      rx := CPQSO('W1AW', 'Ct', Band20, CW, eCW);
      rx.QTH.CountryID := 'K';
      CheckEquals('CT', GetADIFStateForQSO(rx), 'a Connecticut station');
      rx := CPQSO('VE3AA', 'On', Band20, CW, eCW);
      CheckEquals('ON', GetADIFStateForQSO(rx), 'an Ontario station');
      rx := CPQSO('DL1AAA', '', Band20, CW, eCW);
      rx.QTHString := 'DX';
      rx.QTH.CountryID := 'DL';
      CheckEquals('', GetADIFStateForQSO(rx), 'DX: no STATE');

      (* THE RECORD ITSELF. *)
      rx := CPQSO('VE5AAA', 'RGW', Band20, CW, eCW);
      text := EmitADIFRecord(rx);
      CheckTrue(Pos('<CONTEST_ID:12>CP-QSO-PARTY', text) > 0, 'CONTEST_ID: ' + text);
      CheckTrue(Pos('<STATE:2>SK', text) > 0, 'Regina Wascana is in Saskatchewan: ' + text);
      CheckTrue(Pos('<CNTY', text) = 0, 'and the body writes no CNTY: ' + text);
   finally
      ShippedDomDirOverride := savedDomDir;
      names.Free;
      provinces.Free;
   end;
end;

procedure TContestCanadianPrairiesQPTests.Test_RealEngineOutOfArea;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_CPQPRealEngineOutOfArea');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(65, mo.DomList.Count, 'outside the prairies: the 65 districts');
      CheckTrue(Settings.Mult.ByBand, 'multipliers per band');
      CheckFalse(Settings.Mult.ByMode, 'not per mode');

      engine.Enter('VE6AAA', '599 AIR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a district accepted and credited');
      CheckEquals(1, Integer(rx.QSOPoints), 'CW 1');
      dupe := engine.Enter('VE6AAA', '59 AIR', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'note 3: phone is the other mode');
      CheckFalse(rx.DomesticMult, 'AIR again on 20 m: one multiplier per band, not per mode');
      CheckEquals(1, Integer(rx.QSOPoints), 'phone 1');
      dupe := engine.Enter('VE6AAA', '599 AIR', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'note 3: once per band and mode');
      dupe := engine.Enter('VE6AAA', '599 AIR', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'another band');
      CheckTrue(rx.DomesticMult, 'AIR per band');
      dupe := engine.Enter('VE6AAA', '599 BOW', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'note 11: a rover in a new FED is a new station');
      CheckTrue(rx.DomesticMult, 'and Bow River a new district');
      engine.Enter('VE5ZZ', '599 RGW', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a Saskatchewan district');
      engine.Enter('VE4ZZ', '59 WPC', Band10, FM, eFM, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a Manitoba district on 10 m FM');
      CheckEquals(1, Integer(rx.QSOPoints), 'FM is phone: 1');

      (* "Contacts between non VE/VA 4, 5 and 6 stations do not count". *)
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside the prairies, CT is refused');
      engine.Enter('VE3AA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'and ON');
      engine.Enter('VE6BAD', '599 XYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'not a district');

      (* Q98: off-mode and off-band QSOs are LOGGED as X-QSOs. *)
      engine.Enter('VE6RY', '599 RED', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'an RTTY QSO is logged: ' + string(ExchangeErrorMessage));
      CheckTrue(LoggedQSOIsXQSO(rx), '"MODES: CW, Phone": RTTY is an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      engine.Enter('VE6OFF', '599 YEL', Band80, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'an 80 m QSO is logged');
      CheckTrue(LoggedQSOIsXQSO(rx), '80 m is not a contest band');

      (* DISTRICT LINES: note 12, a QSO for each FED, no maximum. *)
      ClearPendingCounties;
      engine.Enter('VE6LN', '599 CCE/CCO/CET', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a district junction: ' + string(ExchangeErrorMessage));
      CheckEquals(2, PendingCountiesCount, 'each further FED its own QSO');
      ClearPendingCounties;
   finally
      engine.Free;
   end;
end;

procedure TContestCanadianPrairiesQPTests.Test_RealEngineInArea;
var
   engine: TQSOPartyEngine;
   accepted: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_CPQPRealEngineInArea');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      (* "Count U.S. states (50), Canadian areas (13)" -- "a maximum of 63
         multipliers on each of the four bands". *)
      CheckEquals(63, mo.DomList.Count, 'in the prairies: 50 states and 13 provinces');
      CheckTrue(Settings.Mult.ByBand and not Settings.Mult.ByMode, 'per band');

      engine.Enter('VE6AAA', '599 AIR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'the first Alberta station: the Alberta multiplier');
      CheckEquals(1, Integer(rx.QSOPoints), '1 point');
      engine.Enter('VE6BBB', '599 BOW', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'another Alberta district');
      CheckFalse(rx.DomesticMult, 'Alberta once per band');
      engine.Enter('VE6BBB', '599 BOW', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'Alberta again on 40 m');
      engine.Enter('VE5AAA', '599 RGW', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Saskatchewan -- own province included');
      engine.Enter('VE4AAA', '599 WPC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Manitoba');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a state');
      engine.Enter('W3AA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '"DC counts as MD"');
      engine.Enter('W3AB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Maryland');
      CheckFalse(rx.DomesticMult, 'already counted through DC');
      engine.Enter('VE3AA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a province');
      engine.Enter('VO1AA', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'NF is NL');
      engine.Enter('KL7AA', '599 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Alaska is a state');
      engine.Enter('VE6CCC', '599 AB', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a prairie station sends its district, not AB');

      (* "Stations outside the USA and Canada should be logged as DX. These
         stations count for QSO credit (1 point each) but not as a
         multiplier." *)
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a DX station: ' + string(ExchangeErrorMessage));
      CheckEquals(1, Integer(rx.QSOPoints), '1 point');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckFalse(rx.DXMult, 'and no DX multiplier');
      CheckEquals('599 DX     ', PartyReceivedCabrilloColumn(PartyHandle, rx),
                  'the received column is DX');
   finally
      engine.Free;
   end;
end;

(* THE RULES' OWN EXAMPLE LINE (note 12): "QSO: 14184 PH 2023-05-24 0046
   VE5CPU 59 RGQ VE5SF 59 RGW" -- RST and district sent, RST and district
   received. Compared word for word (the sponsor's spacing is irregular). *)
procedure TContestCanadianPrairiesQPTests.Test_ExportColumns;
const
   EXAMPLE = 'QSO: 14184 PH 2023-05-24 0046 VE5CPU 59 RGQ VE5SF 59 RGW';
   EXAMPLE_OUT = 'QSO: 14184 PH 2023-05-24 0046 VE5CPU 59 RGQ N0JDP 59 SD';
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
   BeginTest('Test_CPQPExportColumns');
   party := ContestIdentity(PartyHandle);
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '59';
   ctx.RSTReceived := '59';

   rx := CPQSO('VE5SF', 'RGW', Band20, Phone, eUSB);
   my := Default(TMyStationExchange);
   my.MyState := 'RGQ';
   ctx.HisQTH := 'RGW';
   line := 'QSO: 14184 ' + party.CabrilloModeString(Phone, eUSB) + ' 2023-05-24 0046 VE5CPU ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + ' VE5SF ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals(EXAMPLE, Words(line), 'the rules'' example line');

   rx := CPQSO('N0JDP', 'Sd', Band20, Phone, eUSB);
   rx.QTH.CountryID := 'K';
   ctx.HisQTH := 'SD';
   line := 'QSO: 14184 PH 2023-05-24 0046 VE5CPU ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + ' N0JDP ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals(EXAMPLE_OUT, Words(line), 'its next line: a South Dakota station');

   (* A DX ENTRANT SENDS DX -- "or "DX"". *)
   ctx.RSTSent := '599';
   my.MyState := '';
   rx := CPQSO('VE6AAA', 'AIR', Band20, CW, eCW);
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
   CheckEquals(' 5NN RGQ', party.CQExchangeDefault(StationAt(True)), 'a prairie station its district');
   CheckEquals(' 5NN PA', party.CQExchangeDefault(StationAt(False)), 'anyone else its state');

   (* AN FM QSO GOES AS PH. *)
   rx := CPQSO('VE4AAA', 'WPC', Band10, FM, eFM);
   line := string(BuildSingleQsoCabrilloLine(rx));
   CheckTrue(Pos(' PH ', line) > 0, 'FM is written PH: ' + line);
end;

(* THE NEW CONTEST DIALOG SAYS DISTRICT, and outside the prairies takes a
   state, a province or DX -- never AB, SK or MB. *)
procedure TContestCanadianPrairiesQPTests.Test_NewContestSaysDistrict;
var
   area: TNewContestHostArea;
   prompts: TNewContestPrompts;
begin
   BeginTest('Test_CPQPNewContestSaysDistrict');
   CheckTrue(ContestIdentity(PartyHandle).DescribeNewContestHostArea(area), 'the "I am in" box');
   CheckEquals('AB/SK/MB', area.Area, 'the area');
   CheckEquals('AB SK MB', area.HostStates, 'its three provinces');
   CheckEquals(SNewContestHostAreaDistrictLabel, area.PlaceLabel, 'the row reads MY DISTRICT');
   CheckEquals(SNewContestHostAreaInsideDistrictNotice, area.InsideNotice, 'choose your district');
   CheckEquals('cpqp_cty', area.PlacesFile, 'the districts are the list');
   CheckTrue(HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'AB') <> '',
             'outside the prairies AB is refused');
   CheckTrue(HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'MB') <> '',
             'and MB');
   CheckEquals('', HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'ON'),
               'a province is accepted');
   CheckEquals('', HostAreaOutsideRefusal(nil, area.Area, area.HostStates, 'DX'),
               'and DX');

   prompts := TNewContestPrompts.Create;
   try
      ContestIdentity(PartyHandle).DescribeNewContestPrompts(prompts);
      CheckEquals(1, prompts.ChoiceCount, 'one prompt');
      CheckEquals(SNewContestCPQPDistrictOrLocation, prompts.Choice(0).Text, 'its own words');
      CheckTrue(prompts.Choice(0).Field = ncfMyState, 'for MY STATE');
   finally
      prompts.Free;
   end;
end;

procedure TContestCanadianPrairiesQPTests.RunAllTests;
begin
   Test_Identity;
   Test_DistrictFileIsTheSponsorsTable;
   Test_InAreaFile;
   Test_BandsModesAndPoints;
   Test_MultiplierAnswers;
   Test_Score;
   Test_ADIFStateIsTheDistrictsProvince;
   Test_RealEngineOutOfArea;
   Test_RealEngineInArea;
   Test_ExportColumns;
   Test_NewContestSaysDistrict;
end;

end.
