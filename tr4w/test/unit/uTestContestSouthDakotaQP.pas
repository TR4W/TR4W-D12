(* THE SOUTH DAKOTA QSO PARTY -- issue #129 (2026-11-18). The sponsor's rules
   (docs/ContestRules/QSOParties/SouthDakota) and NY4I's rulings on the split
   score: (CW/phone points x counties, states, provinces and DXCC) + (digital
   points x four-character grids worked digitally) + the W0OJY bonus. The
   engine half of the split, TScoreTotals.DigitalQSOPoints, is pinned in its
   own right by uTestDigitalQSOPoints. Each test names the rule it holds; the
   class header says where each landed. *)
unit uTestContestSouthDakotaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestSouthDakotaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_CountyFileAndInStateFile;
      procedure Test_BandsModesAndPoints;
      procedure Test_MultiplierAnswers;
      procedure Test_SplitScoreAndBonus;
      procedure Test_RealEngineOutOfState;
      procedure Test_RealEngineInState;
      procedure Test_ExportColumns;
      procedure Test_ADIFImport;
   end;

implementation

uses
   SysUtils, Classes, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestSouthDakotaQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uTestShippedDom, uMults, LogEdit,
   LogStuff, uPendingCounties, PostUnit, MainUnit, uADIF, uAppStrings,
   uContestSchedule,
   (* TryLegacyContestOf -- a by-id contest has no legacy member. *)
   uTestRegisteredContests,
   (* ActiveContest -- the object that holds the session's station, which
      the ADIF export asks. *)
   uContestFactory;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(SD_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('SD-QSO-PARTY is not registered');
      end;
end;

(* A South Dakota station in county aQTH (DomesticQTH resolved, as the parse
   leaves it), on aBand in aMode. *)
function SDQSO(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
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
   Result.QTH.CountryID := 'K';
end;

(* A GRID QSO: Digital, the grid as the received QTH, no domestic key. *)
function GridQSO(const aCall, aGrid: string; aBand: BandType): ContestExchange;
begin
   Result := SDQSO(aCall, aGrid, aBand, Digital, eFT8);
   Result.DomesticQTH := '';
   Result.DomMultQTH := '';
   Result.RSTReceived := -10;
end;

function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'MINN';
      end
   else
      begin
      Result.MyState := 'PA';
      end;
   Result.MyCountry := 'K';
end;

procedure TContestSouthDakotaQPTests.Test_Identity;
var
   party: TContestBase;
   legacy: integer;
   member: ContestType;
   s: TContestSchedule;
   err: string;
begin
   BeginTest('Test_SouthDakotaIdentity');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestSouthDakotaQP, 'the registered class');
   CheckTrue(TContestSouthDakotaQP.ClassParent = TContestStateQSOPartyBase,
             'directly on the state-party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckFalse(TryLegacyContestOf(party, member), 'no legacy member');
   CheckEquals('SD-QSO-PARTY', party.CabrilloName, 'DXLog''s Cabrillo name');
   CheckEquals('SD-QSO-PARTY', party.ADIFContestId, 'the ADIF Contest_ID');
   CheckEquals('South Dakota QSO Party', party.DisplayName, 'display');
   CheckEquals('South Dakota QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('SD', party.HostState, 'host');
   CheckEquals('w0ej@arrl.net', party.SubmissionEmail, '"sent via email to Bill Nixon at w0ej@arrl.net"');
   CheckEquals(0, party.WA7BNMId, 'not looked up');
   CheckEquals('southdakota_cty', party.DomesticFileName, 'the county file');
   CheckEquals('southdakota', party.InStateDomesticFileName, 'the in-state file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
             '"once per mode per band"; multipliers once overall; 6 m to 70 cm');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, '"a new contact each time they change counties"');
   CheckTrue(party.StripsRoverCountyFromCall and party.SplitsRoverCallOnExport,
             'the party base''s rover rules');
   CheckEquals(STotalsGridMults, party.TotalsDisplay.PrefixMultsCaption,
               'the prefix row counts grids');

   (* "1 PM CDT Saturday to 1 PM CDT Sunday. GMT is 1800z ... the 2nd full
      weekend of October": 2027 is October 9-10. *)
   CheckEquals('2nd full weekend of October at 18:00 UTC for 24h', party.Schedule, 'the schedule');
   CheckTrue(TryParseContestSchedule(party.Schedule, s, err), 'it parses (' + err + ')');
end;

procedure TContestSouthDakotaQPTests.Test_CountyFileAndInStateFile;
var
   lines: TStringList;
   i: integer;
begin
   BeginTest('Test_SouthDakotaCountyFileAndInStateFile');
   CheckEquals('', CountyFileDifference('SouthDakota', 'southdakota_cty.dom',
      'SD-QSO-PARTY-Counties.txt', 66), 'all 66 sponsor county codes and names');

   (* THE IN-STATE LIST: counties first, DC as Maryland, the states, the 13
      provinces, NF and LB as NL. *)
   CheckEquals('MINN', InStateMultiplierOf(PartyHandle, 'MINN'), 'a county is its own multiplier');
   CheckEquals('OGLA', InStateMultiplierOf(PartyHandle, 'OGLA'), 'Oglala Lakota');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'DC counts as Maryland (a decision)');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('CT', InStateMultiplierOf(PartyHandle, 'CT'), 'a state');
   CheckEquals('SD', InStateMultiplierOf(PartyHandle, 'SD'), 'SD stays a state (a decision)');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'), 'LA is Louisiana, s50 before p13');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NF'), 'NF is NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'LB'), 'LB is NL');
   CheckEquals('NS', InStateMultiplierOf(PartyHandle, 'NS'), 'a province');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX is the DXCC multiplier, not an entry');

   (* THE FILES AS TEXT: the in-state include list, and no "=" in either
      header. *)
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'southdakota.dom'));
      CheckTrue(lines.IndexOf('INCLUDE FILE southdakota_cty.dom') >= 0, 'includes the counties');
      CheckTrue(lines.IndexOf('INCLUDE FILE southdakota_cty.dom') <
                lines.IndexOf('INCLUDE FILE s50.dom'), 'counties first');
      CheckTrue(lines.IndexOf('Dc > Md = DC') < lines.IndexOf('INCLUDE FILE s50.dom'),
                'DC folded before the states');
      CheckTrue(lines.IndexOf('INCLUDE FILE p13.dom') >= 0, 'the provinces');
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE', string(lines[i])) = 1 then
            begin
            Break;
            end;
         CheckTrue(Pos('=', string(lines[i])) = 0, 'no "=" in the header: ' + string(lines[i]));
         end;
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'southdakota_cty.dom'));
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Pos('INCLUDE', UpperCase(TrimLeft(string(lines[i])))) <> 1,
                   'the county file includes nothing');
         end;
   finally
      lines.Free;
   end;
end;

procedure TContestSouthDakotaQPTests.Test_BandsModesAndPoints;
var
   party: TContestBase;
   inHost: boolean;
   band: BandType;
   mode: ModeType;
   ext: ExtendedModeType;
   qso: ContestExchange;
   expected: integer;
begin
   BeginTest('Test_SouthDakotaBandsModesAndPoints');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         (* "160m thru 70cm (no WARC bands)", the suggested frequencies'
            list -- 222 MHz included, which DXLog omits. *)
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2,
                Band222, Band432]), 'the rules'' bands');
            end;
         (* "Phone and digital contacts are worth 1 point. CW contacts are
            worth 2 points." -- DXLog's digital 2 is not the rules'. *)
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode = CW then
                  begin
                  expected := 2;
                  end;
               if mode in [Phone, FM, Digital] then
                  begin
                  expected := 1;
                  end;
               if mode = Digital then
                  begin
                  qso := GridQSO('N0SD', 'EN13', Band20);
                  qso.ExtMode := ext;
                  end
               else
                  begin
                  qso := SDQSO('N0SD', 'MINN', Band20, mode, ext);
                  end;
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'CW 2, phone/FM 1, digital 1');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0), 'every submode of the four');
               end;
            end;
         CheckEquals('CW', party.CabrilloModeString(CW, eCW), 'CW');
         CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), 'PH');
         CheckEquals('FM', party.CabrilloModeString(FM, eFM), 'FM');
         CheckEquals('DG', party.CabrilloModeString(Digital, eFT8), 'FT8 is DG');
         CheckEquals('DG', party.CabrilloModeString(Digital, eRTTY), 'every digital submode is DG');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestSouthDakotaQPTests.Test_MultiplierAnswers;
var
   party: TContestBase;
   inHost: boolean;
   key: PrefixMultiplierString;
   dxKey: DXMultiplierString;
   qso: ContestExchange;
   kind: RemainingMultiplierType;
   station: TStationContext;
begin
   BeginTest('Test_SouthDakotaMultiplierAnswers');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         CheckTrue(party.HasDXMultiplier = inHost, 'DXCC for a South Dakota entrant only');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         CheckTrue(party.HasPrefixMultiplier, 'the grids, everywhere');
         if inHost then
            begin
            CheckTrue(party.CountryMode = ARRLCountryMode, 'DXCC is the ARRL list');
            end;

         (* THE GRID KEY: four characters of a Maidenhead square in Digital;
            '' (an answer) for anything else. *)
         CheckTrue(party.PrefixMultiplierKey(GridQSO('N0SD', 'EN13', Band20), key), 'answers');
         CheckEquals('EN13', string(key), 'the grid');
         qso := GridQSO('N0SD', 'en13ab', Band20);
         CheckTrue(party.PrefixMultiplierKey(qso, key), 'answers');
         CheckEquals('EN13', string(key), 'a six-character grid is its four-character square');
         CheckTrue(party.PrefixMultiplierKey(GridQSO('N0SD', 'ZZ00', Band20), key), 'answers');
         CheckEquals('', string(key), 'ZZ00 is no Maidenhead square');
         CheckTrue(party.PrefixMultiplierKey(SDQSO('N0SD', 'EN13', Band20, CW, eCW), key), 'answers');
         CheckEquals('', string(key), 'a CW QSO has no grid key');
         CheckTrue(party.PrefixMultiplierKey(SDQSO('N0SD', 'MINN', Band20, Digital, eRTTY), key), 'answers');
         CheckEquals('', string(key), 'a digital QSO with a county has no grid key');

         (* A DIGITAL QSO EARNS ONLY ITS GRID; ANY OTHER NEVER ONE. *)
         for kind := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
            begin
            CheckTrue(party.CountsAsMultiplier(GridQSO('N0SD', 'EN13', Band20), kind) =
                      (kind = rmPrefix), 'digital: the grid only');
            CheckTrue(party.CountsAsMultiplier(SDQSO('N0SD', 'MINN', Band20, CW, eCW), kind) =
                      (kind <> rmPrefix), 'CW: never a grid');
            end;

         (* NO HOST-AREA TEST FOR A DIGITAL QSO (NY4I). *)
         qso := GridQSO('W1AW', 'FN31', Band20);
         CheckTrue(party.CreditsWorkedStation(qso), 'a digital QSO is credited');

         (* DXCC: every entity but K, VE, KH6, KL, in state. *)
         qso := SDQSO('DL1AAA', 'DL', Band20, CW, eCW);
         qso.QTH.CountryID := 'DL';
         party.DXMultiplierKey(qso, dxKey);
         if inHost then
            begin
            CheckEquals('DL', string(dxKey), 'Germany is a DXCC multiplier in state');
            end;
      finally
         party.Free;
      end;
      end;

   (* A CW QSO KEEPS THE HOST-AREA RULE -- judged by the SHIPPED county file
      (WithHostAreaTable knows every QTH, so it cannot show a refusal). *)
   LoadCountyTable('southdakota_cty.dom', True);
   station := NoStation;
   station.IsDomesticQTH := @CountyFileKnowsQTH;
   party := Make(PartyHandle, station);
   try
      CheckFalse(party.CreditsWorkedStation(SDQSO('W1AW', 'CT', Band20, CW, eCW)),
                 'outside South Dakota a CW QSO with CT is not credited');
      CheckTrue(party.CreditsWorkedStation(SDQSO('N0SD', 'MINN', Band20, CW, eCW)),
                'a county is');
      CheckTrue(party.CreditsWorkedStation(GridQSO('W1AW', 'FN31', Band20)),
                'a digital QSO is, whoever it was with');
   finally
      party.Free;
      FreeCountyTable;
   end;
end;

(* (CW/PHONE POINTS x GEOGRAPHIC) + (DIGITAL POINTS x GRIDS) + W0OJY. *)
procedure TContestSouthDakotaQPTests.Test_SplitScoreAndBonus;
var
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('Test_SouthDakotaSplitScoreAndBonus');
   party := Make(PartyHandle, StationAt(True));
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 30;
      totals.DigitalQSOPoints := 10;
      totals.Mults[AllBands, Both, rmDomestic] := 5;
      totals.Mults[AllBands, Both, rmDX] := 2;
      totals.Mults[AllBands, Both, rmPrefix] := 4;
      CheckEquals(20 * 7 + 10 * 4, party.CombineScore(totals),
                  '(20 CW/phone points x 7 counties, states and DXCC) + (10 digital points x 4 grids)');
      totals.DigitalQSOPoints := 0;
      totals.Mults[AllBands, Both, rmPrefix] := 0;
      CheckEquals(30 * 7, party.CombineScore(totals), 'no digital: the sponsor''s points x multipliers');
      (* The sponsor's own example: "50 contacts SSB x 20 counties = 1,000
         points + 100 bonus = 1,100 points grand total". *)
      totals.QSOPoints := 50;
      totals.Mults[AllBands, Both, rmDomestic] := 20;
      totals.Mults[AllBands, Both, rmDX] := 0;
      view.Add(SDQSO('W0OJY', 'YANK', Band20, Phone, eUSB));
      CheckEquals(1100, party.FinalScore(totals, view), 'the rules'' example');
      view.Add(SDQSO('W0OJY', 'YANK', Band40, CW, eCW));
      view.Add(SDQSO('W0OJY/YANK', 'YANK', Band40, Digital, eFT8));
      CheckEquals(100, party.BonusPoints(totals, view), '"may only be used once", whatever the mode');

      view.Free;
      view := TLoggedQSOList.Create;
      qso := SDQSO('W0OJY', 'YANK', Band20, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso.ceDupe := False;
      qso.ceXQSO := True;
      view.Add(qso);
      CheckEquals(0, party.BonusPoints(totals, view), 'a dupe or X-QSO earns no bonus');
      view.Add(SDQSO('W0OJY/YANK', 'YANK', Band20, CW, eCW));
      CheckEquals(100, party.BonusPoints(totals, view), 'a county-suffixed W0OJY pays');

      (* Points alone when the session counts no multiplier. *)
      totals.SessionCountsMultipliers := False;
      CheckEquals(50, party.CombineScore(totals), 'the base''s points-alone rule');
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestSouthDakotaQPTests.Test_RealEngineOutOfState;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_SouthDakotaRealEngineOutOfState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(66, mo.DomList.Count, 'outside South Dakota: the 66 counties');
      CheckFalse(Settings.Mult.ByBand or Settings.Mult.ByMode, 'multipliers once overall');

      engine.Enter('N0SD', '599 MINN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a county accepted and credited');
      CheckEquals(2, Integer(rx.QSOPoints), 'CW 2');
      CheckFalse(rx.PrefixMult, 'a CW QSO earns no grid');
      dupe := engine.Enter('N0SD', '59 MINN', Band40, Phone, eLSB, accepted, rx);
      CheckFalse(dupe, 'another band and mode');
      CheckFalse(rx.DomesticMult, '"counties may only be used ONCE as a multiplier"');
      CheckEquals(1, Integer(rx.QSOPoints), 'phone 1');
      dupe := engine.Enter('N0SD', '599 MINN', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, '"worked only once per mode per band"');
      dupe := engine.Enter('N0SD', '599 PENN', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'a mobile in a new county is a new contact');
      engine.Enter('N0SD', '59 YANK', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'FM on 2 m');
      CheckEquals(1, Integer(rx.QSOPoints), 'FM 1');

      (* THE HOST-AREA RULE, typed, for CW and phone. *)
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside South Dakota, work South Dakota stations only');
      engine.Enter('N0BAD', '599 XYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'not a county');
      engine.Enter('N0CW', '599 EN13', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a grid is for a digital QSO: refused on CW');

      (* THE GRIDS (NY4I): a digital QSO's only multiplier. *)
      engine.Enter('N0FT', '-10 EN13', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'report and grid taken');
      CheckEquals('EN13', string(rx.QTHString), 'the grid is the received QTH');
      CheckEquals(-10, Integer(rx.RSTReceived), 'the signed report');
      CheckEquals('EN13', string(rx.Prefix), 'the grid key, set at the parse');
      CheckTrue(rx.PrefixMult, 'a new grid');
      CheckFalse(rx.DomesticMult, 'no county from a digital QSO');
      CheckEquals(1, Integer(rx.QSOPoints), 'digital 1');
      CheckFalse(LoggedQSOIsXQSO(rx), 'not an X-QSO');
      engine.Enter('N0FU', 'EN13', Band40, Digital, eFT4, accepted, rx);
      CheckTrue(accepted, 'a grid alone');
      CheckFalse(rx.PrefixMult, 'the same grid, once overall');
      engine.Enter('W1FT', '-05 FN31', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'no host-area test for a digital QSO (NY4I)');
      CheckTrue(rx.PrefixMult, 'its grid counts');
      dupe := engine.Enter('N0FT', '-12 EN13', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(dupe, 'the same station, grid, band and mode is a dupe');

      (* A DIGITAL QSO WITH A COUNTY: points, no multiplier, and the county is
         still new on CW. *)
      engine.Enter('N0RT', '599 HAND', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'an RTTY county taken');
      CheckFalse(rx.DomesticMult or rx.PrefixMult, 'no county and no grid');
      CheckEquals(1, Integer(rx.QSOPoints), 'digital 1');
      engine.Enter('N0RT', '599 HAND', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'the digital QSO marked no county');

      (* OFF-BAND: an automatic X-QSO. *)
      engine.Enter('N0OFF', '599 BUTT', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), '30 m is a WARC band: an automatic X-QSO');
      engine.Enter('N0OFF', '599 BUTT', Band222, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '1.25 m counts, and the X-QSO marked nothing');

      (* COUNTY LINES: no maximum stated. *)
      ClearPendingCounties;
      engine.Enter('N0LN', '599 AURO/BEAD/BENN', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a three-county line');
      CheckEquals(2, PendingCountiesCount, 'each further county its own QSO');
      ClearPendingCounties;

      (* THE RESCORE KEEPS THE GRID KEY -- RecomputeQSOScoring asks
         PrefixMultiplierKey of the stored record. *)
      rx := GridQSO('N0RS', 'EN14', Band20);
      rx.Prefix := '';
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals('EN14', string(rx.Prefix), 'the stored grid re-keyed');
      CheckEquals(1, Integer(rx.QSOPoints), 'and rescored');
      rx.Mode := CW;
      rx.ExtMode := eCW;
      RecomputeQSOScoring(rx);
      CheckEquals('', string(rx.Prefix), 'a mode edit drops a stale grid');
   finally
      engine.Free;
   end;
end;

procedure TContestSouthDakotaQPTests.Test_RealEngineInState;
var
   engine: TQSOPartyEngine;
   accepted: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_SouthDakotaRealEngineInState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckFalse(Settings.Mult.ByBand or Settings.Mult.ByMode, 'multipliers once overall');

      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '"Stations inside South Dakota work everyone": a state');
      engine.Enter('W1AW', '599 CT', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'CT once');
      engine.Enter('N0SD', '599 MINN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a South Dakota county is a multiplier in state too');
      engine.Enter('VE4AA', '599 MB', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a province');
      engine.Enter('W3AA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DC accepted, as Maryland');
      engine.Enter('W3AB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Maryland already counted through DC');

      (* "DXCC country": a DX station sends its prefix; its entity counts. *)
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a DX station sends its country');
      CheckTrue(rx.DXMult, 'its entity is a DXCC multiplier');
      CheckFalse(rx.DomesticMult, 'and no domestic one');
      CheckEquals(2, Integer(rx.QSOPoints), 'DX CW 2');
      CheckEquals('599 DL     ', PartyReceivedCabrilloColumn(PartyHandle, rx),
                  'the received column is its country');
      engine.Enter('DL1AAA', '599 DL', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DXMult, 'DL once overall');
      engine.Enter('KL7AA', '599 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Alaska is a state');
      CheckFalse(rx.DXMult, 'not a DXCC multiplier');

      (* A DIGITAL QSO EARNS ITS GRID, NOT THE ENTITY (NY4I: DX may work
         digital; digital contacts multiply by grids). *)
      engine.Enter('JA1FT', '-15 PM95', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'a JA''s FT8 grid');
      CheckTrue(rx.PrefixMult, 'its grid counts');
      CheckFalse(rx.DXMult, 'its entity does not, from a digital QSO');
      engine.Enter('JA1FT', '599 JA', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DXMult, 'JA is still new for CW/phone');
   finally
      engine.Free;
   end;
end;

procedure TContestSouthDakotaQPTests.Test_ExportColumns;
var
   party, stationed: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   line: string;
   station: TStationContext;
   text: string;
begin
   BeginTest('Test_SouthDakotaExportColumns');
   party := ContestIdentity(PartyHandle);
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';

   (* AN OUT-OF-STATE ENTRANT (PA) WORKS MINNEHAHA -- the standard line. *)
   rx := SDQSO('N0SD', 'MINN', Band20, CW, eCW);
   my := Default(TMyStationExchange);
   my.MyState := 'PA';
   ctx.HisQTH := 'MINN';
   line := 'QSO: 14000 CW 2027-10-09 1800 W3AAA ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'N0SD ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14000 CW 2027-10-09 1800 W3AAA 599 PA     N0SD 599 MINN   ',
      line, 'RST + state sent, RST + county received');
   CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, rx), 'ADIF STX_STRING');

   (* A DX ENTRANT SENDS ITS COUNTRY -- the station's, through SentLocation. *)
   station := StationAt(False);
   station.MyState := '';
   station.MyCountry := 'DL';
   stationed := Make(PartyHandle, station);
   try
      my.MyState := '';
      CheckEquals('599 DL     ', stationed.FormatCabrilloSentExchange(my, rx, ctx),
                  '"DXCC country" sent');
      CheckEquals('599 DL     ', stationed.FormatADIFSentExchange(my, rx), 'and in STX_STRING');
      CheckEquals(' 5NN DL', stationed.CQExchangeDefault(station), 'and in the CQ exchange');
   finally
      stationed.Free;
   end;
   station := StationAt(True);
   CheckEquals(' 5NN MINN', party.CQExchangeDefault(station), 'a South Dakota station its county');

   (* A GRID QSO: DG, the grid in the received column (Hawaii's sponsor
      form), the county this station sends. *)
   my.MyState := 'MINN';
   rx := GridQSO('W1FT', 'FN31', Band20);
   ctx.RSTSent := '-04';
   ctx.RSTReceived := '-10';
   ctx.HisQTH := '';
   line := 'QSO: 14074 ' + party.CabrilloModeString(rx.Mode, rx.ExtMode) +
      ' 2027-10-09 1800 N0SD ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'W1FT ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14074 DG 2027-10-09 1800 N0SD -04 MINN   W1FT -10 FN31   ',
      line, 'a grid QSO''s line');
   CheckEquals('-10 FN31', party.FormatADIFReceivedExchange(rx, True), 'SRX_STRING: report and grid');
   rx.DomesticQTH := 'FN31';
   CheckEquals('', party.ADIFCountyState(rx), 'a grid is no county, even in DomesticQTH');
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<STATE:', text) = 0, 'no STATE for a grid QSO: ' + text);
   CheckTrue(Pos('<CONTEST_ID:12>SD-QSO-PARTY', text) > 0, 'CONTEST_ID: ' + text);

   (* A COUNTY QSO: STATE SD. *)
   rx := SDQSO('N0SD', 'MINN', Band20, CW, eCW);
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<STATE:2>SD', text) > 0, 'a county is in South Dakota: ' + text);
end;

(* A WSJT-X OR ADIF QSO: a Digital QSO's GRIDSQUARE is its grid, over any
   other QTH; a CW QSO's is nothing. *)
procedure TContestSouthDakotaQPTests.Test_ADIFImport;
var
   temps: TADIFRecordTemps;
   exch: ContestExchange;
begin
   BeginTest('Test_SouthDakotaADIFImport');
   temps := Default(TADIFRecordTemps);
   temps.GridSquare := 'en13ab';
   exch := Default(ContestExchange);
   exch.ceContest := PartyHandle;
   exch.Mode := Digital;
   exch.ExtMode := eFT8;
   exch.QTHString := 'SD';
   ContestIdentity(PartyHandle).ApplyADIFImport(temps, NeutralADIFImportSession, exch);
   CheckEquals('EN13', string(exch.QTHString), 'the GRIDSQUARE, four characters, over the STATE');
   CheckEquals('', string(exch.DomesticQTH), 'no domestic key');

   exch := Default(ContestExchange);
   exch.ceContest := PartyHandle;
   exch.Mode := CW;
   ContestIdentity(PartyHandle).ApplyADIFImport(temps, NeutralADIFImportSession, exch);
   CheckEquals('', string(exch.QTHString), 'a CW QSO''s GRIDSQUARE is no received QTH');

   temps.GridSquare := 'ZZ00';
   exch := Default(ContestExchange);
   exch.ceContest := PartyHandle;
   exch.Mode := Digital;
   ContestIdentity(PartyHandle).ApplyADIFImport(temps, NeutralADIFImportSession, exch);
   CheckEquals('', string(exch.QTHString), 'ZZ00 is no grid');
end;

procedure TContestSouthDakotaQPTests.RunAllTests;
begin
   Test_Identity;
   Test_CountyFileAndInStateFile;
   Test_BandsModesAndPoints;
   Test_MultiplierAnswers;
   Test_SplitScoreAndBonus;
   Test_RealEngineOutOfState;
   Test_RealEngineInState;
   Test_ExportColumns;
   Test_ADIFImport;
end;

end.
